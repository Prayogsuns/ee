data "aws_autoscaling_groups" "node-asg" {
  filter {
    name   = "auto-scaling-group"
    values = ["nodes.${data.external.cluster-info.result["cluster-name"]}"]
  }
}

data "external" "cluster-info" {
  program = ["${path.root}/scripts/get-cluster-info.sh"]
}

data "aws_instances" "nodes" {
  filter {
    name   = "instance.group-name"
    values = ["nodes.${data.external.cluster-info.result["cluster-name"]}"]
  }
}

data "aws_security_group" "node-sg" {
  name = "nodes.${data.external.cluster-info.result["cluster-name"]}"
}

data "aws_route53_zone" "cluster-zone" {
  name         = "${var.zone-domain}."
  private_zone = false
}

variable "svc-name" {
  type = string
}

variable "container-image" {
  type    = string
  default = "digitaldispatch/event-subscription-service"
}

variable "replicas" {
  type    = string
  default = 3
}

variable "svc-version" {
  type    = string
  default = "latest"
}

variable "internal-svc-port" {
  type = string
}

variable "external-svc-port" {
  type = string
}

variable "http-port" {
  type = string
}

variable "zone-domain" {
  type = string
}

variable "manual_depends_on" {
  type    = list
  default = []
}

// Environment Variables
variable "kafka-url" {
  type = string
}

variable "sso-service-host" {
  type = string
}

variable "sso-service-port" {
  type = string
}

variable "env-vars" {
  type = map
}

variable "max-history" {
  type    = string
  default = 3
}
