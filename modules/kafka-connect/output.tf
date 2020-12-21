data "external" "kafka-connect" {
  program = ["/bin/bash", "${path.root}/scripts/get_k8s_resource_uid.sh"]

  query = {
    resource_type = "statefulset"
    resource_name = ${local.stateful-set-name}
    namespace     = var.namespace
  }

}

output "kafka-connect-uid" {
  depends_on = [helm_release.kafka-connect]
  value      = data.external.kafka-connect.result["uid"]
}

output "start-connectors-id" {
  depends_on = [null_resource.start-connectors]
  value      = null_resource.start-connectors.id
}

output "kafka-connect-pod-name" {
  depends_on = [helm_release.kafka-connect]
  value      = ${local.stateful-set-name}
}

output "kafka-connect-svc-name" {
  depends_on = [helm_release.kafka-connect]
  value      = ${local.kafka-connect-service-name}
}

