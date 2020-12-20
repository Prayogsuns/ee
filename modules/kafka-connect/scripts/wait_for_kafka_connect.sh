#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Missing pod name or namespace name"
    echo "Example: $0 pod_name namespace_name"
    exit 1
fi

POD_NAMES=($(kubectl get po --namespace=$2 | awk '/'"$1"'/ { print $1 }'))
NAMESPACE="$2"
IS_READY="false"
TIMEOUT=300
T=0

echo "Waiting for Kafka Connect to be ready"
while [[ "$IS_READY" == "false" && $T -le $TIMEOUT ]]; do
  sleep 5
  T=$((T+5))
  IS_READY="true"
  for p in ${POD_NAMES[@]}; do 
    STATUS="$(kubectl get po $p --namespace=${NAMESPACE} -o json | jq -r '.status.containerStatuses[0].ready')"
    if [ "$STATUS" != "true" ]; then
        IS_READY="false"
    fi
  done
done

if [ $T -gt $TIMEOUT ]; then
  echo "Timeout (${TIMEOUT}s): Kafka Connect initailization failed"
  exit 1
fi

sleep 30