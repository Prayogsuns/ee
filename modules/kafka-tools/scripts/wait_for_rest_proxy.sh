#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Missing pod name or namespace name"
    echo "Example: $0 pod_name namespace_name"
    exit 1
fi

POD_NAME="$(kubectl get po --namespace=$2 | awk '/'"$1"'/ { print $1; exit }')"
NAMESPACE="${2:-kafka}"
STATUS="$(kubectl get po ${POD_NAME} --namespace=${NAMESPACE} -o json | jq -r '.status.containerStatuses[0].ready')"
TIMEOUT=300
T=0

echo "Waiting for REST Proxy pod to be ready"

while [[ "$STATUS" != "true" && $T -le $TIMEOUT ]]; do
    sleep 5
    T=$((T+5))
    STATUS="$(kubectl get po ${POD_NAME} --namespace=${NAMESPACE} -o json | jq -r '.status.containerStatuses[0].ready')"
done

if [ $T -gt $TIMEOUT ]; then
    echo "Timeout (${TIMEOUT}s): Schema Registry not ready."
    exit 1
fi