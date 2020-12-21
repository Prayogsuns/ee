variable "namespace" {
  type        = string
  description = "Kubernetes namespace used for Kafka cluster"
}

data "aws_region" "current" {}

// Broker config
variable "broker-version" {
  type = string
}

variable "broker-container-image" {
  type    = string
  default = "digitaldispatch/event-engine"
}

variable "broker-port" {
  type    = string
  default = 9092
}

variable "broker-storage-size" {
  type        = string
  description = "EBS volume size (in GB) for each Kafka broker node"

  default = 25
}

variable "avlm_only_deployment" {
  type        = string
}

variable "zookeeper-svc-name" {
  type        = string
  description = "Kubernetes headless Service name (not DNS) for Zookeeper cluster"
  default     = "zoo"
}

variable "zookeeper-pod-name" {
  type    = string
  default = "zoo"
}

variable "zookeeper-client-port" {
  type    = string
  default = 2181
}

variable "manual_depends_on" {
  type    = list
  default = []
}
variable "retention-period-hrs" {
  type = string
}

variable "broker-storageclass-name" {
  type = string
  default = "kafka-broker"
}

variable "broker-configmap-name" {
  type = string
  default = "broker-config"
}

variable "broker-client-svc-name" {
  type = string
  default = "bootstrap"
}

variable "broker-headless-svc-name" {
  type = string
  default = "broker"
}

variable "max-history" {
  type = string
  default = 3
}
