locals {
  env-vars = jsonencode(var.env-vars)
}

resource "helm_release" "node-service-wo-probe" {
  count = var.enabled == "true" ? 1 : 0

  name  = "node-service-wo-probe"

  chart = "${path.module}/charts/node-service-wo-probe"
  max_history = var.max-history

  set {
    name  = "enabled"
    value = var.enabled
  }

  set {
    name  = "serviceName"
    value = var.svc-name
	type = "string"
  }

  set {
    name  = "servicePort"
    value = var.svc-port
	type = "string"
  }

  set {
    name  = "serviceVersion"
    value = var.svc-version
	type = "string"
  }

  set {
    name  = "replicas"
    value = var.replicas
	type = "string"
  }

  set {
    name  = "dependencyAnnotation"
    value = join(" ", var.manual_depends_on)
	type = "string"
  }

  set {
    name  = "containerImage"
    value = var.container-image
	type = "string"
  }

  values = [<<EOF
envVars: ${local.env-vars}
EOF  
}

resource "null_resource" "reset-pods" {
  count      = var.enabled == "true" ? 1 : 0
  depends_on = [helm_release.node-service-wo-probe]

  triggers = {
    env-var-names  = join(",", keys(var.env-vars))
    env-var-values = join(",", values(var.env-vars))
  }

  provisioner "local-exec" {
    command = "for p in $(kubectl get po | awk '/^${var.svc-name}/ {print $1}'); do kubectl delete po $p; done"
  }
}

