resource "helm_release" "streams" {
  count = var.enabled == "true" ? 1 : 0

  name  = "streams"

  chart = "${path.module}/charts/streams"
  max_history = var.max-history

  set {
    name  = "deploymentName"
    value = ${var.svc-name}-${lower(var.svc-version)}
	type = "string"
  }

  set {
    name  = "replicas"
    value = var.replicas
    type = "string"
  }

  set {
    name  = "dependencyAnnotation"
    value = jsonencode(join(" ", var.manual_depends_on))
	type = "string"
  }
  
  set {
    name  = "serviceName"
    value = var.svc-name
	type = "string"
  }

  set {
    name  = "containerImage"
    value = var.container-image
	type = "string"
  }

  set {
    name  = "serviceVersion"
    value = var.svc-version
	type = "string"
  }

  set {
    name  = "kafkaHost"
    value = var.kafka-port
	type = "string"
  }

  set {
    name  = "schemaRegistryUrl"
    value = var.schema-registry-url
	type = "string"
  }

  set {
    name  = "streamName"
    value = var.stream-name
	type = "string"
  }

  set {
    name  = "legacyArgsEnvValue"
    value = var.legacy-args-env-value
	type = "string"
  }
}
