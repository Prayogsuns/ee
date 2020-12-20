data "template_file" "kafka-rest-properties" {
  template = file("${path.module}/artifacts/kafka-rest.properties")

  vars = {
    rest-proxy-port     = var.rest-proxy-port
    bootstrap-servers   = "${var.broker-client-svc-name}.${var.namespace}:${var.broker-port}"
    schema-registry-url = "http://${kubernetes_service.schema-registry.metadata.0.name}.${var.namespace}:${var.schema-registry-port}"
  }
}

resource "kubernetes_config_map" "kafka-tools" {
  metadata {
    name      = "kafka-tools-config"
    namespace = var.namespace
  }

  data = {
    "kafka-rest.properties" = data.template_file.kafka-rest-properties.rendered
    "log4j.properties"      = file("${path.module}/artifacts/avro-log4j.properties")
  }
}

# Headless service for internal access
resource "kubernetes_service" "schema-registry" {
  metadata {
    name      = "kafka-schema-registry"
    namespace = var.namespace
  }

  spec {
    port {
      port = var.schema-registry-port
    }

    cluster_ip = "None"

    selector = {
      app = "schema-registry"
    }
  }
}

# Nodeport service for external access
resource "kubernetes_service" "schema-registry-external" {
  metadata {
    name      = "kafka-schema-registry-external"
    namespace = var.namespace
  }

  spec {
    type = "NodePort"

    port {
      port = var.schema-registry-port
      target_port = var.schema-registry-port
      protocol = "TCP"
    }

    selector = {
      app = "schema-registry"
    }
  }
}

resource "kubernetes_stateful_set" "schema-registry" {
  metadata {
    name      = "kafka-schema-registry"
    namespace = var.namespace

    annotations = {
      dependency = join(",", var.schema-registry-depends-on)
    }
  }

  spec {
    replicas              = 3
    pod_management_policy = "Parallel"

    service_name = kubernetes_service.schema-registry.metadata.0.name

    selector {
      match_labels = {
        app = "schema-registry"
      }
    }

    update_strategy {
      type = "RollingUpdate"
    }

    template {
      metadata {
        labels = {
          app = "schema-registry"
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
                    values   = ["schema-registry"]
                  }
                }

                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }

        container {
          name  = "kafka-schema-registry"
          image = "confluentinc/cp-schema-registry:5.1.2"

          port {
            container_port = var.schema-registry-port
          }

          env {
            name  = "SCHEMA_REGISTRY_KAFKASTORE_CONNECTION_URL"
            value = "${join(",", formatlist("%s-%s.%s.%s:%s", var.zookeeper-pod-name, list("0","1","2"), var.zookeeper-headless-svc-name, var.namespace, var.zookeeper-client-port))}/kafka"
          }

          env {
            name  = "SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS"
            value = join(",", formatlist("PLAINTEXT://%s-%s.%s.%s:%s", var.broker-pod-name, list("0","1","2"), var.broker-headless-svc-name, var.namespace, var.broker-port))
          }

          env {
            name  = "SCHEMA_REGISTRY_KAFKASTORE_TIMEOUT_MS"
            value = "10000"
          }

          env {
            name  = "SCHEMA_REGISTRY_LISTENERS"
            value = "http://0.0.0.0:${var.schema-registry-port}"
          }

          env {
            name = "POD_NAME"

            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          env {
            name  = "SCHEMA_REGISTRY_HOST_NAME"
            value = "$(POD_NAME).${kubernetes_service.schema-registry.metadata.0.name}.${var.namespace}"
          }

          readiness_probe {
            tcp_socket {
              port = var.schema-registry-port
            }
          }

          liveness_probe {
            period_seconds        = 30
            initial_delay_seconds = 30

            http_get {
              path = "/"
              port = var.schema-registry-port
            }
          }

          resources {
            requests {
              cpu    = "100m"
              memory = "256Mi"
            }

            limits {
              cpu    = "300m"
              memory = "1Gi"
            }
          }
        }
      }
    }
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/wait_for_schema_registry.sh ${kubernetes_stateful_set.schema-registry.metadata.0.name} ${var.namespace}"
  }
}

// Schema Registry UI
resource "kubernetes_service" "schema-registry-ui" {
  count = var.enable-ui == "true" ? 1 : 0

  metadata {
    name      = "schema-registry-ui"
    namespace = var.namespace
  }

  spec {
    type = "NodePort"

    port {
      port = "8000"
    }

    selector = {
      app = "schema-registry-ui"
    }
  }
}

resource "kubernetes_deployment" "schema-registry-ui" {
  count      = var.enable-ui == "true" ? 1 : 0
  depends_on = [kubernetes_stateful_set.schema-registry]

  metadata {
    name      = "schema-registry-ui"
    namespace = var.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "schema-registry-ui"
      }
    }

    template {
      metadata {
        labels = {
          app = "schema-registry-ui"
        }
      }

      spec {
        container {
          name  = "schema-registry-ui"
          image = "landoop/schema-registry-ui:0.9.5"

          port {
            name           = "ui-port"
            container_port = "8000"
          }

          env {
            name  = "SCHEMAREGISTRY_URL"
            value = "http://${kubernetes_service.schema-registry.metadata.0.name}.${var.namespace}:${var.schema-registry-port}"
          }

          env {
            name  = "PROXY"
            value = "true"
          }

          resources {
            requests {
              cpu = "10m"
            }

            limits {
              cpu    = "100m"
              memory = "256Mi"
            }
          }

          readiness_probe {
            tcp_socket {
              port = 8000
            }
          }
        }
      }
    }
  }
}

resource "aws_security_group_rule" "allow-schema-registry-ui" {
  count = var.enable-ui == "true" ? 1 : 0

  type              = "ingress"
  from_port         = kubernetes_service.schema-registry-ui[count.index].spec.0.port.0.node_port
  to_port           = kubernetes_service.schema-registry-ui[count.index].spec.0.port.0.node_port
  protocol          = "TCP"
  security_group_id = data.aws_security_group.node-sg.id
  cidr_blocks       = ["0.0.0.0/0"]                                                      # Allow to be publicly available for now for debugging issues
  description       = "Schema Registry UI"
}

// Kafka REST Proxy
resource "kubernetes_service" "rest-proxy" {
  metadata {
    name      = "rest-proxy"
    namespace = var.namespace
  }

  spec {
    port {
      port = var.rest-proxy-port
    }

    selector = {
      app = "rest-proxy"
    }
  }
}

resource "kubernetes_deployment" "rest-proxy" {
  depends_on = [
    kubernetes_config_map.kafka-tools,
    kubernetes_stateful_set.schema-registry,
  ]

  metadata {
    name      = "rest-proxy"
    namespace = var.namespace

    annotations = {
      dependency = join(",", var.rest-proxy-depends-on)
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "rest-proxy"
      }
    }

    template {
      metadata {
        labels = {
          app = "rest-proxy"
        }
      }

      spec {
        container {
          name  = "rest-proxy"
          image = "confluentinc/cp-kafka-rest:5.1.2"

          command = [
            "kafka-rest-start",
            "/etc/kafka-rest/kafka-rest.properties",
          ]

          port {
            container_port = var.rest-proxy-port
          }

          env {
            name  = "KAFKA_REST_LOG4J_OPTS"
            value = "-Dlog4j.configuration=file:/etc/kafka-rest/log4j.properties"
          }

          env {
            name  = "KAFKA_REST_HOST_NAME"
            value = "${kubernetes_service.rest-proxy.metadata.0.name}.${var.namespace}"
          }

          readiness_probe {
            http_get {
              path = "/"
              port = var.rest-proxy-port
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/kafka-rest"
          }
        }

        volume {
          name = "config"

          config_map {
            name = kubernetes_config_map.kafka-tools.metadata.0.name
          }
        }
      }
    }
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/wait_for_rest_proxy.sh ${kubernetes_deployment.rest-proxy.metadata.0.name} ${var.namespace}"
  }
}

// Topics UI
resource "kubernetes_service" "topics-ui" {
  count = var.enable-ui == "true" ? 1 : 0

  metadata {
    name      = "topics-ui"
    namespace = var.namespace
  }

  spec {
    type = "NodePort"

    port {
      port = "8000"
    }

    selector = {
      app = "topics-ui"
    }
  }
}

resource "kubernetes_deployment" "topics-ui" {
  count      = var.enable-ui == "true" ? 1 : 0
  depends_on = [kubernetes_deployment.rest-proxy]

  metadata {
    name      = "topics-ui"
    namespace = var.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "topics-ui"
      }
    }

    template {
      metadata {
        labels = {
          app = "topics-ui"
        }
      }

      spec {
        container {
          name  = "kafka-connect"
          image = "landoop/kafka-topics-ui:0.9.4"

          port {
            name           = "topics-ui"
            container_port = "8000"
          }

          env {
            name  = "KAFKA_REST_PROXY_URL"
            value = "http://${kubernetes_service.rest-proxy.metadata.0.name}.${var.namespace}:${var.rest-proxy-port}"
          }

          env {
            name  = "PROXY"
            value = "true"
          }

          resources {
            requests {
              cpu = "10m"
            }

            limits {
              cpu    = "100m"
              memory = "256Mi"
            }
          }

          readiness_probe {
            tcp_socket {
              port = 8000
            }
          }
        }
      }
    }
  }
}

resource "aws_security_group_rule" "allow-topics-ui" {
  count = var.enable-ui == "true" ? 1 : 0

  type              = "ingress"
  from_port         = kubernetes_service.topics-ui[count.index].spec.0.port.0.node_port
  to_port           = kubernetes_service.topics-ui[count.index].spec.0.port.0.node_port
  protocol          = "TCP"
  security_group_id = data.aws_security_group.node-sg.id
  cidr_blocks       = ["0.0.0.0/0"]                                             # Allow to be publicly available for now for debugging issues
  description       = "Topics UI"
}

