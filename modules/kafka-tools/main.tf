locals {
  kafka-config-name                                  = "kafka-tools-config"
  schema-registry-service-name                       = "kafka-schema-registry"
  schema-registry-external-service-name              = "kafka-schema-registry-external"
  kafka-schema-registry-statefulset-name             = "kafka-schema-registry"
  kafka-schema-registry-statefulset-container-name   = "kafka-schema-registry"
  schema-registry-ui-service-name                    = "schema-registry-ui"
  schema-registry-ui-deployment-name                 = "schema-registry-ui"
  schema-registry-ui-deployment-container-name       = "schema-registry-ui"
  rest-proxy-service-name                            = "rest-proxy"
  rest-proxy-deployment-name                         = "rest-proxy"
  topics-ui-service-name                             = "topics-ui"
  topics-ui-deployment-name                          = "topics-ui"
  topics-ui-deployment-container-name                = "kafka-connect"
  
}

data "template_file" "kafka-rest-properties" {
  template = file("${path.module}/artifacts/kafka-rest.properties")

  vars = {
    rest-proxy-port     = var.rest-proxy-port
    bootstrap-servers   = "${var.broker-client-svc-name}.${var.namespace}:${var.broker-port}"
    schema-registry-url = "http://${local.schema-registry-service-name}.${var.namespace}:${var.schema-registry-port}"
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
    name  = "namespace"
    value = var.namespace
    type = "string"
  }

  set {
    name  = "kafkaConfigName"
    value = ${local.kafka-config-name}
    type = "string"
  }

  set {
    name  = "schemaRegistryServiceName"
    value = ${local.schema-registry-service-name}
    type = "string"
  }

  set {
    name  = "schemaRegistryServicePort"
    value = var.schema-registry-port
    type = "string"
  }

  set {
    name  = "schemaRegistryExternalServiceName"
    value = ${local.schema-registry-external-service-name}
    type = "string"
  }

  set {
    name  = "kafkaSchemaRegistryStatefulSetName"
    value = ${local.kafka-schema-registry-statefulset-name}
    type = "string"
  }

  set {
    name  = "kafkaSchemaRegistryStatefulSet.dependencyAnnotation"
    value = jsonencode(join(",", var.schema-registry-depends-on))
    type = "string"
  }

  set {
    name  = "kafkaSchemaRegistryStatefulSetContainerName"
    value = ${local.kafka-schema-registry-statefulset-container-name}
    type = "string"
  }

  set {
    name  = "env.SCHEMA_REGISTRY_KAFKASTORE_CONNECTION_URL"
    value = "${join(",", formatlist("%s-%s.%s.%s:%s", var.zookeeper-pod-name, list("0","1","2"), var.zookeeper-headless-svc-name, var.namespace, var.zookeeper-client-port))}/kafka"
    type = "string"
  }

  set {
    name  = "env.SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS"
    value = join(",", formatlist("PLAINTEXT://%s-%s.%s.%s:%s", var.broker-pod-name, list("0","1","2"), var.broker-headless-svc-name, var.namespace, var.broker-port))
    type = "string"
  }

  values = [<<EOF
data: ${local.data-config}
EOF
  ]
  
  provisioner "local-exec" {
    command = "${path.module}/scripts/wait_for_schema_registry.sh ${local.kafka-schema-registry-statefulset-name} ${var.namespace}"
  }  
}

resource "helm_release" "kafka-tools-schema-registry-ui" {
  count      = var.enable-ui == "true" ? 1 : 0
  depends_on = [helm_release.kafka-tools]

  name  = "kafka-tools-schema-registry-ui"

  chart = "${path.module}/charts/kafka-tools-schema-registry-ui"
  max_history = var.max-history

  set {
    name  = "namespace"
    value = var.namespace
    type = "string"
  }

  set {
    name  = "schemaRegistryServiceName"
    value = ${local.schema-registry-service-name}
    type = "string"
  }

  set {
    name  = "schemaRegistryServicePort"
    value = var.schema-registry-port
    type = "string"
  }

  set {
    name  = "enableUi"
    value = var.enable-ui
  }

  set {
    name  = "schemaRegistryUiServiceName"
    value = ${local.schema-registry-ui-service-name}
    type = "string"
  }

  set {
    name  = "schemaRegistryUiDeploymentName"
    value = ${local.schema-registry-ui-deployment-name}
    type = "string"
  }

  set {
    name  = "schemaRegistryUiDeploymentContainerName"
    value = ${local.schema-registry-ui-deployment-container-name}
    type = "string"
  }
}

data "external" "schema-registry-ui" {
  program = ["/bin/bash", "${path.root}/scripts/get_k8s_resource_data.sh"]

  query = {
    resource_type = "service"
    resource_name = ${local.schema-registry-ui-service-name}
    namespace     = var.namespace
  }

}

resource "aws_security_group_rule" "allow-schema-registry-ui" {
  count = var.enable-ui == "true" ? 1 : 0

  type              = "ingress"
  from_port         = data.external.schema-registry-ui.result["nodeport"]
  to_port           = data.external.schema-registry-ui.result["nodeport"]
  protocol          = "TCP"
  security_group_id = data.aws_security_group.node-sg.id
  cidr_blocks       = ["0.0.0.0/0"]                                                      # Allow to be publicly available for now for debugging issues
  description       = "Schema Registry UI"
}

resource "helm_release" "kafka-tools-rest-proxy" {
  depends_on = [
    helm_release.kafka-tools
  ]

  name  = "kafka-tools-rest-proxy"

  chart = "${path.module}/charts/kafka-tools-rest-proxy"
  max_history = var.max-history

  set {
    name  = "namespace"
    value = var.namespace
    type = "string"
  }

  set {
    name  = "kafkaConfigName"
    value = ${local.kafka-config-name}
    type = "string"
  }

  set {
    name  = "restProxyServiceName"
    value = ${local.rest-proxy-service-name}
	type  = "string"
  }

  set {
    name  = "restProxyDeploymentName"
    value = ${local.rest-proxy-deployment-name}
    type = "string"
  }

  set {
    name  = "restProxyDeployment.dependencyAnnotation"
    value = jsonencode(join(",", var.rest-proxy-depends-on))
    type = "string"
  }

  set {
    name  = "restProxyPort"
    value = var.rest-proxy-port
    type = "string"
  }
  
  provisioner "local-exec" {
    command = "${path.module}/scripts/wait_for_rest_proxy.sh ${local.rest-proxy-deployment-name} ${var.namespace}"
  }  
}

resource "helm_release" "kafka-tools-topics-ui" {
  count = var.enable-ui == "true" ? 1 : 0
  depends_on = [helm_release.kafka-tools-rest-proxy]
  
  name  = "kafka-tools-topics-ui"

  chart = "${path.module}/charts/kafka-tools-topics-ui"
  max_history = var.max-history

  set {
    name  = "namespace"
    value = var.namespace
    type = "string"
  }

  set {
    name  = "enableUi"
    value = var.enable-ui
  }

  set {
    name  = "restProxyServiceName"
    value = ${local.rest-proxy-service-name}
	type  = "string"
  }

  set {
    name  = "restProxyPort"
    value = var.rest-proxy-port
    type = "string"
  }

  set {
    name  = "topicsUiServiceName"
    value = ${local.topics-ui-service-name}
	type  = "string"
  }

  set {
    name  = "topicsUiDeploymentName"
    value = ${local.topics-ui-deployment-name}
    type = "string"
  }

  set {
    name  = "topicsUiDeploymentContainerName"
    value = ${local.topics-ui-deployment-container-name}
    type = "string"
  }
}

data "external" "topics-ui" {
  program = ["/bin/bash", "${path.root}/scripts/get_k8s_resource_data.sh"]

  query = {
    resource_type = "service"
    resource_name = ${local.topics-ui-service-name}
    namespace     = var.namespace
  }

}

resource "aws_security_group_rule" "allow-topics-ui" {
  count = var.enable-ui == "true" ? 1 : 0

  type              = "ingress"
  from_port         = data.external.topics-ui.result["nodeport"]
  to_port           = data.external.topics-ui.result["nodeport"]
  protocol          = "TCP"
  security_group_id = data.aws_security_group.node-sg.id
  cidr_blocks       = ["0.0.0.0/0"]                                             # Allow to be publicly available for now for debugging issues
  description       = "Topics UI"
}

