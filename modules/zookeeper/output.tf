output "zookeeper-uid" {
  depends_on = [helm_release.zookeeper]
  value      = kubernetes_stateful_set.zookeeper.metadata.0.uid
}

output "pod-name" {
  depends_on = [helm_release.zookeeper]
  value      = "zoo"
}

output "zookeeper-client-svc-name" {
  depends_on = [helm_release.zookeeper]
  value      = "zookeeper"
}

output "zookeeper-headless-svc-name" {
  depends_on = [helm_release.zookeeper]
  value      = "zoo"
}

