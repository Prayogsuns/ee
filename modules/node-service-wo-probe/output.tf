output "node-port" {
  value = join("", kubernetes_service.k8-svc.*.spec.0.port.0.node_port)
}

output "deploy-uid" {
  value = join("", kubernetes_deployment.k8-deploy.*.metadata.0.uid)
}

