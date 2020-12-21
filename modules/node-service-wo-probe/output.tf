data "external" "k8s-svc" {
  program = ["/bin/bash", "${path.root}/scripts/get_k8s_resource_data.sh"]

  query = {
    resource_type = "service"
    resource_name = var.svc-name
  }

}

data "external" "k8s-deploy" {
  program = ["/bin/bash", "${path.root}/scripts/get_k8s_resource_uid.sh"]

  query = {
    resource_type = "deployment"
    resource_name = var.svc-name
  }

}

output "node-port" {
  depends_on = [helm_release.node-service-wo-probe]
  // value = join("", kubernetes_service.k8-svc.*.spec.0.port.0.node_port)
  value = data.external.k8s-svc.result["nodeport"]
}

output "deploy-uid" {
  depends_on = [helm_release.node-service-wo-probe]
  // value = join("", kubernetes_deployment.k8-deploy.*.metadata.0.uid)
  value = data.external.k8s-deploy.result["uid"]
}

