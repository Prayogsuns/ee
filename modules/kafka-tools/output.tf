data "external" "schema-registry-uid" {
  program = ["/bin/bash", "${path.root}/scripts/get_k8s_resource_uid.sh"]

  query = {
    resource_type = "statefulset"
    resource_name = ${local.kafka-schema-registry-statefulset-name}
    namespace     = var.namespace
  }

}

data "external" "rest-proxy-uid" {
  program = ["/bin/bash", "${path.root}/scripts/get_k8s_resource_uid.sh"]

  query = {
    resource_type = "deployment"
    resource_name = ${local.rest-proxy-deployment-name}
    namespace     = var.namespace
  }

}

output "schema-registry-uid" {
  depends_on = [helm_release.kafka-tools]
  value      = data.external.schema-registry-uid.result["uid"]
}

output "rest-proxy-uid" {
  depends_on = [helm_release.kafka-tools-rest-proxy]
  value      = data.external.rest-proxy-uid.result["uid"]
}

output "schema-registry-pod-name" {
  depends_on = [helm_release.kafka-tools]
  value      = ${local.kafka-schema-registry-statefulset-name}
}

output "schema-registry-svc-name" {
  depends_on = [helm_release.kafka-tools]
  value      = ${local.schema-registry-service-name}
}

output "rest-proxy-svc-name" {
  depends_on = [helm_release.kafka-tools-rest-proxy]
  value      = ${local.rest-proxy-service-name}
}

