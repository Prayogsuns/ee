output "node-port" {
  depends_on = [helm_release.event-subscription-service]
  value      = data.external.k8s-svc.result["nodeports"][0]
}

output "ess-endpoint" {
  depends_on = [aws_acm_certificate_validation.ess-cert, aws_route53_record.domain]
  value      = local.domain-name
}

