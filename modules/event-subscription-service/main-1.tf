resource "kubernetes_service" "k8-svc" {
  metadata {
    name = var.svc-name
  }

  spec {
    type = "NodePort"

    port {
      name        = "ess-ws-port"
      port        = var.internal-svc-port
      target_port = var.internal-svc-port
      protocol    = "TCP"
    }

    port {
      name        = "ess-http-port"
      port        = var.http-port
      target_port = var.http-port
      protocol    = "TCP"
    }

    selector = {
      service = var.svc-name
    }
  }
}

resource "kubernetes_deployment" "k8-deploy" {
  metadata {
    name = var.svc-name

    annotations = {
      dependency = join(" ", var.manual_depends_on)
    }
  }

  spec {
    selector {
      match_labels = {
        service = var.svc-name
      }
    }

    replicas = var.replicas

    template {
      metadata {
        labels = {
          service = var.svc-name
        }
      }

      spec {
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100

              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "service"
                    operator = "In"
                    values   = [var.svc-name]
                  }
                }

                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }

        container {
          name  = "${var.svc-name}-container"
          image = "${var.container-image}:${var.svc-version}"

          port {
            container_port = var.internal-svc-port
          }

          port {
            container_port = var.http-port
          }

          liveness_probe {
            initial_delay_seconds = 5
            period_seconds        = 30
            success_threshold     = 1
            timeout_seconds       = 10

            tcp_socket {
              port = var.internal-svc-port
            }
          }

          readiness_probe {
            initial_delay_seconds = 5
            period_seconds        = 30
            success_threshold     = 1
            timeout_seconds       = 10

            tcp_socket {
              port = var.internal-svc-port
            }
          }

          env_from {
            config_map_ref {
              name     = kubernetes_config_map.env-vars.metadata.0.name
              optional = false
            }
          }

          resources {
            requests {
              cpu    = "100m"
              memory = "1Gi"
            }

            limits {
              cpu    = "500m"
              memory = "2Gi"
            }
          }
        }

        image_pull_secrets {
          name = "dockercreds"
        }
      }
    }
  }
}

resource "kubernetes_config_map" "env-vars" {
  metadata {
    name = "${var.svc-name}-env-vars"
  }

  data = var.env-vars
}

resource "null_resource" "reset-pods" {
  depends_on = [kubernetes_config_map.env-vars, kubernetes_deployment.k8-deploy]

  triggers = {
    env-var-names  = join(",", keys(var.env-vars))
    env-var-values = join(",", values(var.env-vars))
  }

  provisioner "local-exec" {
    command = "for p in $(kubectl get po | awk '/^${var.svc-name}/ {print $1}'); do kubectl delete po $p; done"
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
  port     = kubernetes_service.k8-svc.spec.0.port.0.node_port
  protocol = "HTTP"
  vpc_id   = data.external.cluster-info.result["vpc_id"]

  health_check {
    protocol = "HTTP"
    path     = "/health"
    port     = kubernetes_service.k8-svc.spec.0.port.1.node_port
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
  from_port         = kubernetes_service.k8-svc.spec.0.port.0.node_port
  to_port           = kubernetes_service.k8-svc.spec.0.port.0.node_port
  protocol          = "TCP"
  security_group_id = data.aws_security_group.node-sg.id
  cidr_blocks       = sort(split(" ", data.external.cluster-info.result["cluster-cidrs"]))
  description       = "event-subscription-service WebSocket"
}

resource "aws_security_group_rule" "allow-ess-http" {
  type              = "ingress"
  from_port         = kubernetes_service.k8-svc.spec.0.port.1.node_port
  to_port           = kubernetes_service.k8-svc.spec.0.port.1.node_port
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

