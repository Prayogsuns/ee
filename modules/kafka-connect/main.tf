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

locals {
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
}
locals {
  data-config       = jsonencode(${local.data})
  stateful-set-name = "kafka-connect-${lower(replace(var.kafka-connect-version, ".", "-"))}"
}

resource "helm_release" "kafka-connect-configmap" {
  name  = "kafka-connect-configmap"

  chart = "${path.module}/charts/kafka-connect-configmap"
  max_history = var.max-history

  set {
    name  = "namespace"
    value = var.namespace
	type = "string"
  }

  set {
    name  = "kafkaConfigName"
    value = "kafka-connect-config-${lower(replace(var.kafka-connect-version, ".", "-"))}"
	type = "string"
  }
  
  values = [<<EOF
data: ${local.data-config}
EOF
  ]

  provisioner "local-exec" {
    command = "kubectl delete po --namespace=${var.namespace} ${join(" ", formatlist("%s-%s", "kafka-connect-${lower(replace(var.kafka-connect-version, ".", "-"))}", list("0","1","2")))} || echo \"Kafka Connect not deployed yet\""
  }
}

resource "helm_release" "kafka-connect" {
  name  = "kafka-connect"

  chart = "${path.module}/charts/kafka-connect"
  max_history = var.max-history

  set {
    name  = "namespace"
    value = var.namespace
	type = "string"
  }

  set {
    name  = "kafkaConfigName"
    value = "kafka-connect-config-${lower(replace(var.kafka-connect-version, ".", "-"))}"
	type = "string"
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/wait_for_kafka_connect.sh kafka-connect-${lower(replace(var.kafka-connect-version, ".", "-"))} ${var.namespace}"
  }
}

resource "null_resource" "start-connectors" {
  depends_on = [
    helm_release.kafka-connect,
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

resource "helm_release" "kafka-connect-ui" {
  count = var.enable-ui == "true" ? 1 : 0

  name  = "kafka-connect-ui"

  chart = "${path.module}/charts/kafka-connect-ui"
  max_history = var.max-history

  set {
    name  = "namespace"
    value = var.namespace
	type = "string"
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


