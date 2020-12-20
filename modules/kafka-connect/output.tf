output "kafka-connect-uid" {
  depends_on = [kubernetes_stateful_set.kafka-connect]
  value      = kubernetes_stateful_set.kafka-connect.metadata.0.uid
}

output "start-connectors-id" {
  depends_on = [null_resource.start-connectors]
  value      = null_resource.start-connectors.id
}

output "kafka-connect-pod-name" {
  depends_on = [kubernetes_stateful_set.kafka-connect]
  value      = kubernetes_stateful_set.kafka-connect.metadata.0.name
}

output "kafka-connect-svc-name" {
  depends_on = [kubernetes_service.kafka-connect]
  value      = kubernetes_service.kafka-connect.metadata.0.name
}

