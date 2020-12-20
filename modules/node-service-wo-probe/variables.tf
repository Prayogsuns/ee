variable "enabled" {
  type = string
}

variable "svc-name" {
  type = string
}

variable "svc-port" {
  type = string
}

variable "replicas" {
  type = string
}

variable "container-image" {
  type = string
}

variable "svc-version" {
  type = string
}

variable "manual_depends_on" {
  type    = list
  default = ["None"]
}

variable "env-vars" {
  type = map
}

variable "health-check-config" {
  type = any
}

variable "max-history" {
  type    = string
  default = 3
}
