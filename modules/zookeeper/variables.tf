variable "namespace" {
  type = string
}

variable "zookeeper-storage-size" {
  type        = string
  description = "EBS Volume size (in GB) for Zookeeper nodes"

  default = 5
}

variable "client-port" {
  type    = string
  default = 2181
}

variable "peer-port" {
  type    = string
  default = 2888
}

variable "leader-elect-port" {
  type    = string
  default = 3888
}

variable "manual_depends_on" {
  type    = list
  default = []
}

variable "zookeeper-storageclass-name" {
  type = string
  default = "kafka-zookeeper"
}

variable "zookeeper-configmap-name" {
  type = string
  default = "zookeeper-config"
}

variable "zookeeper-statefulset-name" {
  type = string
  default = "zoo"
}

variable "max-history" {
  type = string
  default = 3
}
