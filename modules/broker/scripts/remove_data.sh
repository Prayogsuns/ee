#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Missing pod name or namespace name"
    echo "Usage: $0 pod_name namespace_name [log_dir]"
    exit 1
fi

POD_NAME=$1
NAMESPACE="$2"
LOG_DIR="${3:-/var/lib/kafka/data/topics}"

echo "Removing data from $LOG_DIR"
for i in {0..2}; do
    kubectl exec ${POD_NAME}-${i} --namespace=$NAMESPACE -- bash -c "rm -rf ${LOG_DIR}/*"
    kubectl delete po ${POD_NAME}-${i} --namespace=$NAMESPACE
done
echo "Done"