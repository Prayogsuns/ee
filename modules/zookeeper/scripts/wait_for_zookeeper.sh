#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Missing pod name or namespace name"
    echo "Example: $0 pod_name namespace_name"
    exit 1
fi

POD_NAME="$1"
NAMESPACE="$2"
IS_READY="false"
TIMEOUT=300
T=0

while [[ "$IS_READY" == "false" && $T -le $TIMEOUT ]]; do
    sleep 5
    T=$((T+5))
    for i in {0..2}; do 
        STATUS="$(kubectl get po ${POD_NAME}-${i} --namespace=${NAMESPACE} -o json | jq -r '.status.containerStatuses[0].ready')"
        if [ "$STATUS" == "true" ]; then
            MODE="$(kubectl exec ${POD_NAME}-${i} --namespace=${NAMESPACE} -- bash -c "echo stats | nc localhost 2181 | grep Mode" 2>/dev/null | sed 's/.*:\s*//')" 
            if [ "$MODE" == "leader" ]; then
                IS_READY="true"
            fi
        fi
    done
done