data "external" "cluster-info" {
  program = ["${path.root}/scripts/get-cluster-info.sh"]
}

data "aws_security_group" "node-sg" {
  name = "nodes.${data.external.cluster-info.result["cluster-name"]}"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace used for Kafka cluster"
}

data "aws_region" "current" {}

// EE config
variable "main-rds-endpoint" {
  type = string
}

variable "main-rds-port" {
  type    = string
  default = 5432
}

variable "sso-rds-endpoint" {
  type = string
}

variable "sso-rds-port" {
  type    = string
  default = 5432
}

variable "rds-user" {
  type = string
}

variable "rds-pass" {
  type = string
}

variable "rds-db-names" {
  type = map

  default = {
    rms-service        = "riders"
    booking-service    = "booking"
    scheduling-service = "scheduling"
    dispatch-service   = "transitdispatch"
    avlm-server        = "avlm"
    sso-service        = "sso"
  }
}

variable "dynamodb-table-names" {
  type = map

  default = {
    avl          = "site-stage-avl"
    eta-polyline = "site-stage-eta-polyline"
    eta-route    = "site-stage-eta-route"
    alerts       = "site-stage-Alerts"
  }
}

variable "dynamodb-topic-names" {
  type = map
}

// End EE config

// Kafka Connect config
variable "kafka-connect-version" {
  type = string
}

variable "container-image" {
  type    = string
  default = "digitaldispatch/event-engine"
}

variable "kafka-connect-port" {
  type    = string
  default = 8083
}

variable "broker-headless-svc-name" {
  type        = string
  description = "Kubernetes headless Service name (not DNS) for Kafka broker cluster"
  default     = "broker"
}

variable "broker-pod-name" {
  type    = string
  default = "kafka"
}

variable "broker-port" {
  type    = string
  default = 9092
}

variable "schema-registry-pod-name" {
  type    = string
  default = "kafka-schema-registry"
}

variable "schema-registry-svc-name" {
  type    = string
  default = "kafka-schema-registry"
}

variable "schema-registry-port" {
  type    = string
  default = "8081"
}

variable "enable-ui" {
  type    = string
  default = "false"
}

variable "connector-set" {
  type    = string
  default = "all"
}

variable "manual_depends_on" {
  type    = list
  default = []
}

variable "avlm_only_deployment" {
  type =string
}

variable "max-history" {
  type = string
  default = 3
}
