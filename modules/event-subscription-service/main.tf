locals {
  env-vars = jsonencode(var.env-vars)
}

resource "helm_release" "event-subscription-service" {
  name  = "event-subscription-service"

  chart = "${path.module}/charts/event-subscription-service"
  max_history = var.max-history

  set {
    name  = "enabled"
    value = var.enabled
  }

  set {
    name  = "serviceName"
    value = var.svc-name
	type = "string"
  }

  set {
    name  = "internalSvcPort"
    value = var.internal-svc-port
	type = "string"
  }

  set {
    name  = "httpPort"
    value = var.http-port
	type = "string"
  }

  set {
    name  = "serviceVersion"
    value = var.svc-version
	type = "string"
  }

  set {
    name  = "replicas"
    value = var.replicas
	type = "string"
  }

  set {
    name  = "dependencyAnnotation"
    value = jsonencode(join(" ", var.manual_depends_on))
	type = "string"
  }

  set {
    name  = "containerImage"
    value = var.container-image
	type = "string"
  }

  values = [<<EOF
envVars: ${local.env-vars}
EOF  
}

resource "null_resource" "reset-pods" {
  depends_on = [helm_release.event-subscription-service]

  triggers = {
    env-var-names  = join(",", keys(var.env-vars))
    env-var-values = join(",", values(var.env-vars))
  }

  provisioner "local-exec" {
    command = "for p in $(kubectl get po | awk '/^${var.svc-name}/ {print $1}'); do kubectl delete po $p; done"
  }
}

data "external" "k8s-svc" {
  program = ["/bin/bash", "${path.root}/scripts/get_k8s_resource_data.sh"]

  query = {
    resource_type = "service"
    resource_name = var.svc-name
  }

}


// Application Load Balancer
resource "aws_lb" "alb" {
  name               = "${var.svc-name}-lb"
  internal           = false
  load_balancer_type = "application"
  idle_timeout       = 3600                                                                            # Allow idle connections for an hour
  subnets            = sort(split(" ", data.external.cluster-info.result["cluster-subnets"]))
  security_groups    = [data.aws_security_group.node-sg.id, aws_security_group.ess-ws-sg.id]
}

resource "aws_lb_target_group" "alb-target" {
  name     = "${var.svc-name}-tg"
  port     = data.external.k8s-svc.result["nodeports"][0]
  protocol = "HTTP"
  vpc_id   = data.external.cluster-info.result["vpc_id"]

  health_check {
    protocol = "HTTP"
    path     = "/health"
    port     = data.external.k8s-svc.result["nodeports"][1]
  }
}

locals {
  ess-listeners = [var.external-svc-port, var.internal-svc-port]
}

resource "aws_lb_listener" "alb-listener" {
  count      = 2
  depends_on = [aws_acm_certificate_validation.ess-cert]

  load_balancer_arn = aws_lb.alb.arn
  port              = element(local.ess-listeners, count.index)
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-1-2017-01"
  certificate_arn   = aws_acm_certificate.ess-cert.arn

  default_action {
    target_group_arn = aws_lb_target_group.alb-target.arn
    type             = "forward"
  }
}

resource "aws_security_group" "ess-ws-sg" {
  name        = "ess-external-access"
  description = "Allow TLS traffic for ESS Load Balancer"
  vpc_id      = data.external.cluster-info.result["vpc_id"]
}

resource "aws_security_group_rule" "allow-alb-ws" {
  type              = "ingress"
  from_port         = var.internal-svc-port
  to_port           = var.internal-svc-port
  protocol          = "TCP"
  security_group_id = aws_security_group.ess-ws-sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "ESS Internal"
}

resource "aws_security_group_rule" "allow-alb-ws2" {
  type              = "ingress"
  from_port         = var.external-svc-port
  to_port           = var.external-svc-port
  protocol          = "TCP"
  security_group_id = aws_security_group.ess-ws-sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "ESS External"
}

resource "aws_security_group_rule" "allow-ess-ws" {
  type              = "ingress"
  from_port         = data.external.k8s-svc.result["nodeports"][0]
  to_port           = data.external.k8s-svc.result["nodeports"][0]
  protocol          = "TCP"
  security_group_id = data.aws_security_group.node-sg.id
  cidr_blocks       = sort(split(" ", data.external.cluster-info.result["cluster-cidrs"]))
  description       = "event-subscription-service WebSocket"
}

resource "aws_security_group_rule" "allow-ess-http" {
  type              = "ingress"
  from_port         = data.external.k8s-svc.result["nodeports"][1]
  to_port           = data.external.k8s-svc.result["nodeports"][1]
  protocol          = "TCP"
  security_group_id = data.aws_security_group.node-sg.id
  cidr_blocks       = sort(split(" ", data.external.cluster-info.result["cluster-cidrs"]))
  description       = "event-subscription-service HTTP"
}

resource "aws_autoscaling_attachment" "asg-alb-attachment" {
  autoscaling_group_name = data.aws_autoscaling_groups.node-asg.names[0]
  alb_target_group_arn   = aws_lb_target_group.alb-target.id
}

// ESS Domain name
locals {
  domain-name = "events.${var.zone-domain}"
}

resource "aws_acm_certificate" "ess-cert" {
  domain_name       = local.domain-name
  validation_method = "DNS"
}

resource "aws_route53_record" "dns-validation" {
  name    = aws_acm_certificate.ess-cert.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.ess-cert.domain_validation_options.0.resource_record_type
  zone_id = data.aws_route53_zone.cluster-zone.id
  records = [aws_acm_certificate.ess-cert.domain_validation_options.0.resource_record_value]
  ttl     = "60"
}

resource "aws_acm_certificate_validation" "ess-cert" {
  certificate_arn         = aws_acm_certificate.ess-cert.arn
  validation_record_fqdns = [aws_route53_record.dns-validation.fqdn]
}

resource "aws_route53_record" "domain" {
  zone_id = data.aws_route53_zone.cluster-zone.id
  name    = local.domain-name
  type    = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = false
  }
}

