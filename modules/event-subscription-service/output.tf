output "node-port" {
  depends_on = [kubernetes_service.k8-svc]
  value      = kubernetes_service.k8-svc.spec.0.port.0.node_port
}

output "ess-endpoint" {
  depends_on = [aws_acm_certificate_validation.ess-cert, aws_route53_record.domain]
  value      = local.domain-name
}

