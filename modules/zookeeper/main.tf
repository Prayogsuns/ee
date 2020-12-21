resource "helm_release" "zookeeper-storageclass" {
  name  = ${var.zookeeper-storageclass-name}-storageclass

  chart = "${path.module}/charts/storageclass"
  max_history = var.max-history

  set {
    name  = "zookeeperStorageClassName"
    value = var.zookeeper-storageclass-name
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
  depends_on = [helm_release.zookeeper-storageclass]

  triggers = {
    storage-size = var.zookeeper-storage-size
    namespace    = var.namespace
  }

  provisioner "local-exec" {
    command = "/bin/bash -c \"${path.module}/scripts/modify_volume.sh ${var.zookeeper-storageclass-name} ${var.namespace} ${var.zookeeper-storage-size}\""
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/destroy_zookeeper_volumes.sh kafka-zookeeper ${self.triggers.namespace}"
  }

}

// Config
data "template_file" "zookeeper-properties" {
  template = "${file("${path.module}/artifacts/zookeeper.properties")}"

  vars = {
    client-port       = var.client-port
    peer-port         = var.peer-port
    leader-elect-port = var.leader-elect-port

    zookeeper-pod-name          = "zoo"
    zookeeper-headless-svc-name = "zoo.${var.namespace}"
  }
}

locals {
  data = {
      "init.sh"              = "${file("${path.module}/artifacts/zookeeper-init.sh")}"
      "zookeeper.properties" = data.template_file.zookeeper-properties.rendered
      "log4j.properties"     = "${file("${path.module}/artifacts/zookeeper-log4j.properties")}"
    }
}
locals {
  data-config = jsonencode(${local.data})
}

resource "helm_release" "zookeeper" {
  depends_on = [
    helm_release.zookeeper-storageclass,
    null_resource.storage-size,
  ]

  name  = "zookeeper"

  chart = "${path.module}/charts/zookeeper"
  max_history = var.max-history

  set {
    name  = "zookeeperStorageClassName"
    value = var.zookeeper-storageclass-name
	type = "string"
  }

  set {
    name  = "zookeeperStorageSize"
    value = var.zookeeper-storage-size
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
    name  = "zookeeperConfigName"
    value = var.zookeeper-configmap-name
	type = "string"
  }

  set {
    name  = "clientPort"
    value = var.client-port
	type = "string"
  }

  set {
    name  = "peerPort"
    value = var.peer-port
    type = "string"
  }

  set {
    name  = "leaderElectPort"
	value = var.leader-elect-port
    type = "string"
  }

  set {
    name  = "statefulSetZookeeperName"
    value = var.zookeeper-statefulset-name
    type = "string"
  }

  set {
    name  = "zookeeperHeadlessServiceName"
    value = var.zookeeper-headless-svc-name
    type = "string"
  }

  set {
    name  = "zookeeperServiceName"
    value = var.zookeeper-client-svc-name
    type = "string"
  }
  
  values = [<<EOF
data: ${local.data-config}
EOF
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/wait_for_zookeeper.sh ${var.zookeeper-statefulset-name} ${var.namespace}"
  }
}
