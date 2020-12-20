// DynamoDB IAM policies
resource "aws_iam_user" "kafka" {
  name = "kafka-cluster-dynamodb"
}

resource "aws_iam_user_policy" "kafka" {
  name = "kafka-cluster-dynamodb"
  user = aws_iam_user.kafka.name

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchGetItem",
                "dynamodb:ListTables",
                "dynamodb:ListBackups",
                "dynamodb:Scan",
                "dynamodb:ListTagsOfResource",
                "dynamodb:Query",
                "dynamodb:DescribeStream",
                "dynamodb:DescribeTimeToLive",
                "dynamodb:ListStreams",
                "dynamodb:DescribeGlobalTableSettings",
                "dynamodb:DescribeReservedCapacityOfferings",
                "dynamodb:ListGlobalTables",
                "dynamodb:DescribeTable",
                "dynamodb:GetShardIterator",
                "dynamodb:DescribeGlobalTable",
                "dynamodb:DescribeReservedCapacity",
                "dynamodb:GetItem",
                "dynamodb:DescribeContinuousBackups",
                "dynamodb:DescribeBackup",
                "dynamodb:DescribeLimits",
                "dynamodb:GetRecords"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_access_key" "kafka" {
  user = aws_iam_user.kafka.name
}

// Config
data "template_file" "connect-distributed-properties" {
  template = file("${path.module}/artifacts/connect-distributed.properties")

  vars = {
    kafka-servers      = join(",", formatlist("%s-%s.%s.%s:%s", var.broker-pod-name, list("0","1","2"), var.broker-headless-svc-name, var.namespace, var.broker-port))
    kafka-connect-port = var.kafka-connect-port
  }
}

resource "kubernetes_config_map" "kafka-connect" {
  metadata {
    name      = "kafka-connect-config-${lower(replace(var.kafka-connect-version, ".", "-"))}"
    namespace = var.namespace
  }

  data = {
    "connect-distributed.properties" = data.template_file.connect-distributed-properties.rendered
    "log4j.properties"               = file("${path.module}/artifacts/log4j.properties")

    "event-engine.json" = <<CONFIG
{
    "postgres": {
        "host": "${var.main-rds-endpoint}",
        "port": "${var.main-rds-port}",
        "user": "${var.rds-user}",
        "pwd": "${var.rds-pass}",
        "riders": {
            "db": "${var.rds-db-names["rms-service"]}"
        },
        "booking": {
            "db": "${var.rds-db-names["booking-service"]}"
        },
        "scheduling": {
            "db": "${var.rds-db-names["scheduling-service"]}"
        },
        "dispatch": {
            "db": "${var.rds-db-names["dispatch-service"]}"
        },
        "avlm": {
            "db": "${var.rds-db-names["avlm-server"]}"
        },
        "sso": {
            "host": "${var.sso-rds-endpoint}",
            "port": "${var.sso-rds-port}",
            "db": "${var.rds-db-names["sso-service"]}"
        }
    },
    "dynamodb": {
        "aws_region": "${data.aws_region.current.name}",
        "aws_key": "${aws_iam_access_key.kafka.id}",
        "aws_secret": "${aws_iam_access_key.kafka.secret}",
        "avl": {
            "tablename": "${var.dynamodb-table-names["avl"]}",
            "topicname": "${var.dynamodb-topic-names["avl"]}"
        },
        "eta_polyline": {
            "tablename": "${var.dynamodb-table-names["eta-polyline"]}",
            "topicname": "${var.dynamodb-topic-names["eta-polyline"]}"
        },
        "eta_route": {
            "tablename": "${var.dynamodb-table-names["eta-route"]}",
            "topicname": "${var.dynamodb-topic-names["eta-route"]}"
        },
        "alerts": {
            "tablename": "${var.dynamodb-table-names["alerts"]}",
            "topicname": "${var.dynamodb-topic-names["alerts"]}"
        }
    }
}
CONFIG
  }

  provisioner "local-exec" {
    command = "kubectl delete po --namespace=${var.namespace} ${join(" ", formatlist("%s-%s", "kafka-connect-${lower(replace(var.kafka-connect-version, ".", "-"))}", list("0","1","2")))} || echo \"Kafka Connect not deployed yet\""
  }
}

// Kafka Connect
resource "kubernetes_service" "kafka-connect" {
  metadata {
    name      = "kafka-connect"
    namespace = var.namespace
  }

  spec {
    port {
      port = var.kafka-connect-port
    }

    cluster_ip = "None"

    selector = {
      app = "kafka-connect-${lower(replace(var.kafka-connect-version, ".", "-"))}"
    }
  }
}

resource "kubernetes_stateful_set" "kafka-connect" {
  depends_on = [kubernetes_config_map.kafka-connect]

  metadata {
    name      = "kafka-connect-${lower(replace(var.kafka-connect-version, ".", "-"))}"
    namespace = var.namespace

    annotations = {
      dependency = join(",", var.manual_depends_on)
    }
  }

  spec {
    replicas              = 3
    pod_management_policy = "Parallel"

    selector {
      match_labels = {
        app = "kafka-connect-${lower(replace(var.kafka-connect-version, ".", "-"))}"
      }
    }

    update_strategy {
      type = "RollingUpdate"
    }

    service_name = kubernetes_service.kafka-connect.metadata.0.name

    template {
      metadata {
        labels = {
          app = "kafka-connect-${lower(replace(var.kafka-connect-version, ".", "-"))}"
        }
      }

      spec {
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100

              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "app"
                    operator = "In"
                    values   = ["kafka-connect-${lower(replace(var.kafka-connect-version, ".", "-"))}"]
                  }
                }

                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }

        init_container {
          name    = "init"
          image   = "${var.container-image}:k8s-${var.kafka-connect-version}"
          command = ["/bin/bash", "/opt/dds/scripts/kafka-k8s-init.sh"]

          env {
            name = "POD_NAME"

            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          env {
            name  = "KAFKA_CONNECT_SVC_DNS"
            value = "${kubernetes_service.kafka-connect.metadata.0.name}.${var.namespace}"
          }

          env {
            name  = "KAFKA_PORT"
            value = var.broker-port
          }

          volume_mount {
            name       = "configmap"
            mount_path = "/opt/dds/scripts/config"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/kafka"
          }
        }

        container {
          name    = "kafka-connect"
          image   = "${var.container-image}:k8s-${var.kafka-connect-version}"
          command = ["connect-distributed.sh", "/etc/kafka/connect-distributed.properties"]

          port {
            name           = "kafka-connect"
            container_port = var.kafka-connect-port
          }

          port {
            name           = "jmx"
            container_port = 5555
          }

          env {
            name  = "CLASSPATH"
            value = "/connectors/*"
          }

          env {
            name  = "KAFKA_LOG4J_OPTS"
            value = "-Dlog4j.configuration=file:/etc/kafka/log4j.properties"
          }

          env {
            name  = "JMX_PORT"
            value = 5555
          }

          env {
            name  = "KAFKA_HEAP_OPTS"
            value = "-Xmx1G -Xms1G"
          }

          env {
            name  = "KAFKA_CONNECT_URL"
            value = "http://localhost:${var.kafka-connect-port}"
          }

          env {
            name  = "KAFKA_SCHEMA_REGISTRY_URL"
            value = join(",", formatlist("http://%s-%s.%s.%s:%s", var.schema-registry-pod-name, list("0","1","2"), var.schema-registry-svc-name, var.namespace, var.schema-registry-port))
          }

          env {
            name  = "AVLM_ONLY_DEPLOYMENT"
            value = var.avlm_only_deployment 
          }

          resources {
            requests {
              cpu    = "50m"
              memory = "1Gi"
            }

            limits {
              cpu    = "500m"
              memory = "1500Mi"
            }
          }

          readiness_probe {
            success_threshold = 1
            period_seconds    = 15

            tcp_socket {
              port = var.kafka-connect-port
            }
          }

          liveness_probe {
            initial_delay_seconds = 30
            timeout_seconds       = 120 # Rebalancing takes a max of 2 minutes
            period_seconds        = 30

            http_get {
              path = "/"
              port = var.kafka-connect-port
            }
          }

          lifecycle {
            pre_stop {
              exec {
                command = ["sh", "-ce", "kill -s TERM 1; while $(kill -0 1 2>/dev/null); do sleep 1; done"]
              }
            }
          }

          volume_mount {
            name       = "configmap"
            mount_path = "/opt/dds/scripts/config"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/kafka"
          }
        }

        volume {
          name = "configmap"

          config_map {
            name = kubernetes_config_map.kafka-connect.metadata.0.name
          }
        }

        volume {
          name      = "config"
          //empty_dir = {}
        }

        image_pull_secrets {
          name = "dockercreds"
        }
      }
    }
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/wait_for_kafka_connect.sh kafka-connect-${lower(replace(var.kafka-connect-version, ".", "-"))} ${var.namespace}"
  }
}

resource "null_resource" "start-connectors" {
  depends_on = [
    kubernetes_stateful_set.kafka-connect,
  ]

  triggers = {
    kafka-connect-version = var.kafka-connect-version
  }

  provisioner "local-exec" {
    // start_connectors.sh <kafka-connect pod name> <k8 namespace> <connector set>
    // connector set = all or a5
    command = "${path.module}/scripts/start_connectors.sh kafka-connect-${lower(replace(var.kafka-connect-version, ".", "-"))} ${var.namespace} ${var.connector-set}"
  }
}

// Kafka Connect UI
resource "kubernetes_service" "connect-ui" {
  count = var.enable-ui == "true" ? 1 : 0

  metadata {
    name      = "connect-ui"
    namespace = var.namespace
  }

  spec {
    type = "NodePort"

    port {
      port = "8000"
    }

    selector = {
      app = "connect-ui"
    }
  }
}

resource "kubernetes_deployment" "connect-ui" {
  count      = var.enable-ui == "true" ? 1 : 0
  depends_on = [kubernetes_stateful_set.kafka-connect]

  metadata {
    name      = "connect-ui"
    namespace = var.namespace

    annotations = {
      dependency = join(",", var.manual_depends_on)
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "connect-ui"
      }
    }

    template {
      metadata {
        labels = {
          app = "connect-ui"
        }
      }

      spec {
        container {
          name  = "kafka-connect"
          image = "landoop/kafka-connect-ui:0.9.7"

          port {
            name           = "connect-ui"
            container_port = "8000"
          }

          env {
            name  = "CONNECT_URL"
            value = join(",", formatlist("http://%s-%s.%s.%s:%s", kubernetes_stateful_set.kafka-connect.metadata.0.name, list("0","1","2"), kubernetes_service.kafka-connect.metadata.0.name, var.namespace, var.kafka-connect-port))
          }

          readiness_probe {
            tcp_socket {
              port = 8000
            }
          }
        }

        image_pull_secrets {
          name = "dockercreds"
        }
      }
    }
  }
}

resource "aws_security_group_rule" "allow-ui" {
  count = var.enable-ui == "true" ? 1 : 0

  type              = "ingress"
  from_port         = kubernetes_service.connect-ui[count.index].spec.0.port.0.node_port
  to_port           = kubernetes_service.connect-ui[count.index].spec.0.port.0.node_port
  protocol          = "TCP"
  security_group_id = data.aws_security_group.node-sg.id
  cidr_blocks       = ["0.0.0.0/0"]                                              # Allow to be publicly available for now for debugging issues
  description       = "Connect UI"
}

