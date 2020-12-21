locals {
  broker-storageclass-name = "kafka-broker"
}

resource "helm_release" "broker-storageclass" {
  name  = ${local.broker-storageclass-name}-storageclass

  chart = "${path.module}/charts/storageclass"
  max_history = var.max-history

  set {
    name  = "kafkaStorageClassName"
    value = ${local.broker-storageclass-name}
  }

}

/*
  Change when Kubernetes version updated to 1.11+
  For now, this will resize the volumes so that
    it fulfills the requested size for the PVC and
    reattach to the instance.
  It won't update the filesystem size that the pod sees
    since that would need to be done in the underlying host.
  An event engine reset will need to be done for now to update storage.
*/
resource "null_resource" "storage-size" {
  depends_on = [helm_release.broker-storageclass]

  triggers = {
    storage-size = var.broker-storage-size
    namespace = var.namespace
  }

  provisioner "local-exec" {
    command = "/bin/bash -c \"${path.module}/scripts/modify_volume.sh ${local.broker-storageclass-name} ${var.namespace} ${var.broker-storage-size}\""
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/destroy_broker_volumes.sh kafka-broker ${self.triggers.namespace}"
  }

}

// ----- KAFKA BROKER -----
data "template_file" "server-properties" {
  template = file("${path.module}/artifacts/server.properties")

  vars = {
    broker-port       = var.broker-port
    zookeeper-servers = "${join(",", formatlist("%s-%s.%s.%s:%s", var.zookeeper-pod-name, list("0","1","2"), var.zookeeper-svc-name, var.namespace, var.zookeeper-client-port))}/kafka"
    retention-period-hrs = var.retention-period-hrs
  }
}

data "template_file" "event-engine-yaml" {
  template = file("${path.module}/artifacts/event_engine.yaml")

  vars = {
    pod-name          = "kafka-${lower(replace(var.broker-version, ".", "-"))}"
    svc-dns           = "broker.${var.namespace}"
    broker-port       = var.broker-port
    zookeeper-servers = "${join(",", formatlist("%s-%s.%s.%s:%s", var.zookeeper-pod-name, list("0","1","2"), var.zookeeper-svc-name, var.namespace, var.zookeeper-client-port))}/kafka"
  }
}

locals {
  data = {
    "server.properties" = data.template_file.server-properties.rendered
    "event_engine.yaml" = data.template_file.event-engine-yaml.rendered
    "log4j.properties"  = file("${path.module}/artifacts/log4j.properties")
  }
}
locals {
  data-config                  = jsonencode(${local.data})
  
  stateful-set-name            = "kafka-${lower(replace(var.broker-version, ".", "-"))}"
  broker-configmap-name        = "broker-config"
  broker-headless-svc-name     = "broker"
  broker-client-svc-name       = "bootstrap"
}

resource "helm_release" "broker" {
  depends_on = [
    helm_release.broker-storageclass,
    null_resource.storage-size,
  ]

  name  = "broker"

  chart = "${path.module}/charts/broker"
  max_history = var.max-history

  set {
    name  = "kafkaStorageClassName"
    value = ${local.broker-storageclass-name}
	type = "string"
  }

  set {
    name  = "kafkaStorageSize"
    value = var.broker-storage-size
    type = "string"
  }

  set {
    name  = "kafkaStatefulSetName"
    value = ${local.stateful-set-name}
    type = "string"
  }

  set {
    name  = "clientServiceName"
    value = ${local.broker-client-svc-name}
    type = "string"
  }

  set {
    name  = "headlessServiceName"
    value = ${local.broker-headless-svc-name}
    type = "string"
  }

  set {
    name  = "dependencyAnnotation"
    value = "${join(",", var.manual_depends_on)},${null_resource.storage-size.id}"
	type = "string"
  }

  set {
    name  = "namespace"
    value = var.namespace
	type = "string"
  }

  set {
    name  = "kafkaConfigName"
    value = ${local.broker-configmap-name}
	type = "string"
  }

  set {
    name  = "brokerPort"
    value = var.broker-port
	type = "string"
  }

  set {
    name  = "brokerContainerImage"
    value = var.broker-container-image
    type = "string"
  }

  set {
    name  = "brokerVersion"
	value = var.broker-version
    type = "string"
  }

  set {
    name  = "env.ZOOKEEPER_SERVERS"
    value = "${join(",", formatlist("%s-%s.%s.%s:%s", var.zookeeper-pod-name, list("0","1","2"), var.zookeeper-svc-name, var.namespace, var.zookeeper-client-port))}/kafka"
    type = "string"
  }

  set {
    name  = "env.AVLM_ONLY_DEPLOYMENT"
    value = var.avlm_only_deployment
    type = "string"
  }

  values = [<<EOF
data: ${local.data-config}
EOF
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/wait_for_brokers.sh ${var.zookeeper-pod-name}-0 kafka-${lower(replace(var.broker-version, ".", "-"))} ${var.namespace}"
  }
}

resource "null_resource" "create-topics" {
  depends_on = [
    helm_release.broker,
  ]

  triggers = {
    broker-version = var.broker-version
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/create_topics.sh ${local.stateful-set-name}-0 ${var.namespace}"
  }
}
