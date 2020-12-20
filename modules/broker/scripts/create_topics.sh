#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Missing pod name or namespace name"
    echo "Example: $0 pod_name namespace_name"
    exit 1
fi

POD_NAME="$1"
NAMESPACE="$2"
STATUS="$(kubectl get po ${POD_NAME} --namespace=${NAMESPACE} -o json | jq -r '.status.containerStatuses[0].ready')"
TIMEOUT=300
T=0

echo "Checking that Kafka is ready"

while [[ "$STATUS" != "true" && $T -le $TIMEOUT ]]; do
    sleep 5
    T=$((T+5))
    STATUS="$(kubectl get po ${POD_NAME} --namespace=${NAMESPACE} -o json | jq -r '.status.containerStatuses[0].ready')"
done

kubectl exec $POD_NAME --namespace=$NAMESPACE -- bash -c "export JMX_PORT=8888; /opt/dds/scripts/create-topics.sh" || echo "Topics already created"

