data "external" "cluster-info" {
  program = ["${path.root}/scripts/get-cluster-info.sh"]
}

data "aws_security_group" "node-sg" {
  name = "nodes.${data.external.cluster-info.result["cluster-name"]}"
}

variable "namespace" {
  type = string
}

variable "schema-registry-port" {
  type    = string
  default = 8081
}

variable "rest-proxy-port" {
  type    = string
  default = 8082
}

variable "zookeeper-pod-name" {
  type    = string
  default = "zoo"
}

variable "zookeeper-headless-svc-name" {
  type    = string
  default = "zoo"
}

variable "zookeeper-client-port" {
  type    = string
  default = 2181
}

variable "broker-pod-name" {
  type = string
}

variable "broker-headless-svc-name" {
  type    = string
  default = "broker"
}

variable "broker-client-svc-name" {
  type    = string
  default = "bootstrap"
}

variable "broker-port" {
  type    = string
  default = 9092
}

variable "enable-ui" {
  type    = string
  default = "false"
}

variable "schema-registry-depends-on" {
  type    = list
  default = []
}

variable "rest-proxy-depends-on" {
  type    = list
  default = []
}

variable "max-history" {
  type    = string
  default = 3
}

