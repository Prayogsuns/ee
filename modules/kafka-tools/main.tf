data "template_file" "kafka-rest-properties" {
  template = file("${path.module}/artifacts/kafka-rest.properties")

  vars = {
    rest-proxy-port     = var.rest-proxy-port
    bootstrap-servers   = "${var.broker-client-svc-name}.${var.namespace}:${var.broker-port}"
    schema-registry-url = "http://${kubernetes_service.schema-registry.metadata.0.name}.${var.namespace}:${var.schema-registry-port}"
  }
}

locals {
  data = {
    "kafka-rest.properties" = data.template_file.kafka-rest-properties.rendered
    "log4j.properties"      = file("${path.module}/artifacts/avro-log4j.properties")
  }
}
locals {
  data-config = jsonencode(${local.data})
}

resource "helm_release" "kafka-tools" {
  name  = "kafka-tools"

  chart = "${path.module}/charts/kafka-tools"
  max_history = var.max-history

  set {
    name  = "env"
    value = var.avlm_only_deployment
    type = "string"
  }

  values = [<<EOF
data: ${local.data-config}
EOF
  ]
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



