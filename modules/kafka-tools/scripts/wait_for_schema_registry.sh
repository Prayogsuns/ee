#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Missing pod name or namespace name"
    echo "Example: $0 pod_name namespace_name"
    exit 1
fi

POD_NAME="$1"
NAMESPACE="${2:-kafka}"
TIMEOUT=300
T=0
IS_READY="false"

echo "Waiting for Schema Registry pod to be ready"

while [[ "$IS_READY" == "false" && $T -le $TIMEOUT ]]; do
  sleep 5
  T=$((T+5))
  IS_READY="true"
  for i in {0..2}; do 
    STATUS="$(kubectl get po ${POD_NAME}-${i} --namespace=${NAMESPACE} -o json | jq -r '.status.containerStatuses[0].ready')"
    if [ "$STATUS" != "true" ]; then
        IS_READY="false"
    fi
  done
done

if [ $T -gt $TIMEOUT ]; then
    echo "Timeout (${TIMEOUT}s): Schema Registry not ready."
    exit 1
fi

sleep 30