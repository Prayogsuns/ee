variable "enabled" {
  type    = string
  default = "true"
}

variable "svc-name" {
  type = string
}

variable "container-image" {
  type    = string
  default = "digitaldispatch/event-engine-streams"
}

variable "replicas" {
  type    = string
  default = 1
}

variable "svc-version" {
  type    = string
  default = "latest"
}

variable "manual_depends_on" {
  type    = list
  default = []
}

// Environment Variables
variable "kafka-host" {
  type = string
}

variable "stream-name" {
  type = string
}

variable "kafka-port" {
  type    = string
  default = 9092
}

variable "schema-registry-port" {
  type    = string
  default = 8083
}

variable "schema-registry-url" {
  type = string
}

variable "legacy-args-env-value" {
  type        = string
  description = "ENV value for LEGACY_ARGS"

  default = "true"
}

variable "max-history" {
  type    = string
  default = 3
}
