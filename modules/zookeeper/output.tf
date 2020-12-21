data "external" "res-uid" {
  program = ["/bin/bash", "${path.root}/scripts/get_k8s_resource_uid.sh"]

  query = {
    resource_type = "statefulset"
    resource_name = var.zookeeper-statefulset-name
    namespace     = var.namespace
  }

}

output "zookeeper-uid" {
  depends_on = [helm_release.zookeeper]
  value      = data.external.res-uid.result["uid"]
}

output "pod-name" {
  depends_on = [helm_release.zookeeper]
  value      = var.zookeeper-statefulset-name
}

output "zookeeper-client-svc-name" {
  depends_on = [helm_release.zookeeper]
  value      = var.zookeeper-client-svc-name
}

output "zookeeper-headless-svc-name" {
  depends_on = [helm_release.zookeeper]
  value      = var.zookeeper-headless-svc-name
}

