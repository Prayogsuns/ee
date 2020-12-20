#!/bin/bash

if [ $# -lt 3 ]; then
    echo "Missing pod name or namespace name"
    echo "Usage: $0 zoo_pod_name kafka_pod_name namespace_name"
    exit 1
fi

ZOO_POD_NAME="$1"
KAFKA_POD_NAME="$2"
NAMESPACE="$3"
TIMEOUT=300
T=0

num_brokers_attached="kubectl exec $ZOO_POD_NAME --namespace=$NAMESPACE -- bash -c \"echo dump | nc localhost 2181 | grep broker | wc -l\" | sed 's/\\r//g'"
IS_READY="false"
echo "Waiting for all brokers to join Zookeeper cluster"

while [[ "$IS_READY" != "true" && $(eval $num_brokers_attached) -ne 3 && $T -le $TIMEOUT ]]; do
    sleep 1
    T=$(( $T + 1 ))
    IS_READY="true"
    for i in {0..2}; do 
        STATUS="$(kubectl get po ${KAFKA_POD_NAME}-${i} --namespace=${NAMESPACE} -o json | jq -r '.status.containerStatuses[0].ready')"
        if [ "$STATUS" != "true" ]; then
            IS_READY="false"
        fi
    done
done

if [ $T -gt $TIMEOUT ]; then
    echo "Timeout (${TIMEOUT}s)"
    kubectl exec $ZOO_POD_NAME --namespace=$NAMESPACE -- bash -c 'echo dump | nc localhost 2181'
    exit 1
fi

sleep 30