#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Missing pod name or namespace name"
    echo "Example: $0 pod_name namespace_name"
    exit 1
fi

POD_NAMES=($(kubectl get po --namespace=$2 | awk '/'"$1"'/ { print $1 }'))
NAMESPACE="$2"
CONNECTOR_SET=$3
TIMEOUT=300
T=0

echo "Checking that Kafka is ready"
IS_READY="false"

while [[ "$IS_READY" != "true" && $T -le $TIMEOUT ]]; do
    IS_READY="true"
    for pod in ${POD_NAMES[@]}; do
        STATUS="$(kubectl get po $pod --namespace=${NAMESPACE} -o json | jq -r '.status.containerStatuses[0].ready')"
        if [ "$STATUS" != "true" ]; then
            echo "status of $pod: $STATUS"
            IS_READY="false"
        fi
    done
    sleep 5
    T=$((T+5))
done

case "$CONNECTOR_SET" in
    a5)
        STREAMS_TO_START="avlm-route avlm-trip message"
        ;;
    *)
        # Start all of them
        STREAMS_TO_START=""
        ;;
esac

kubectl exec ${POD_NAMES[0]} --namespace=$NAMESPACE -- bash -c "export JMX_PORT=9999; /opt/dds/scripts/start-connectors.sh $STREAMS_TO_START" || echo "Connectors already created"
