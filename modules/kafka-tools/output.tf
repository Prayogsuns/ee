output "schema-registry-uid" {
  depends_on = [kubernetes_stateful_set.schema-registry]
  value      = kubernetes_stateful_set.schema-registry.metadata.0.uid
}

output "rest-proxy-uid" {
  depends_on = [kubernetes_deployment.rest-proxy]
  value      = kubernetes_deployment.rest-proxy.metadata.0.uid
}

output "schema-registry-pod-name" {
  depends_on = [kubernetes_stateful_set.schema-registry]
  value      = kubernetes_stateful_set.schema-registry.metadata.0.name
}

output "schema-registry-svc-name" {
  depends_on = [kubernetes_service.schema-registry]
  value      = kubernetes_service.schema-registry.metadata.0.name
}

output "rest-proxy-svc-name" {
  depends_on = [kubernetes_service.rest-proxy]
  value      = kubernetes_service.rest-proxy.metadata.0.name
}

