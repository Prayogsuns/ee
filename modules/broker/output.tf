data "external" "res-uid" {
  program = ["/bin/bash", "${path.root}/scripts/get_k8s_resource_uid.sh"]

  query = {
    resource_type = "statefulset"
    resource_name = ${local.stateful-set-name}
    namespace     = var.namespace
  }

}

output "broker-uid" {
  depends_on = [helm_release.broker]
  value      = data.external.res-uid.result["uid"]
}

output "create-topics-id" {
  depends_on = [null_resource.create-topics]
  value      = null_resource.create-topics.id
}

output "broker-pod-name" {
  depends_on = [helm_release.broker]
  value      = "kafka-${lower(replace(var.broker-version, ".", "-"))}"
}

output "broker-client-svc-name" {
  depends_on = [helm_release.broker]
  value      = ${local.broker-client-svc-name}
}

output "broker-headless-svc-name" {
  depends_on = [helm_release.broker]
  value      = ${local.broker-headless-svc-name}
}

