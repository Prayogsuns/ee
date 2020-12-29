data "external" "res-uid" {
  program = ["/bin/bash", "${path.root}/scripts/get_k8s_resource_data.sh"]

  query = {
    resource_type = "statefulset"
    resource_name = ${local.zookeeper-statefulset-name}
    namespace     = var.namespace
	query_type    = "uid"
  }

}

output "zookeeper-uid" {
  depends_on = [helm_release.zookeeper]
  value      = data.external.res-uid.result["uid"]
}

output "pod-name" {
  depends_on = [helm_release.zookeeper]
  value      = ${local.zookeeper-statefulset-name}
}

output "zookeeper-client-svc-name" {
  depends_on = [helm_release.zookeeper]
  value      = ${local.zookeeper-client-svc-name}
}

output "zookeeper-headless-svc-name" {
  depends_on = [helm_release.zookeeper]
  value      = ${local.zookeeper-headless-svc-name}
}

