#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Missing storage class name or namespace name"
    echo "Example: $0 storage_class_name namespace_name"
    exit 1
fi

PVC_NAMES=($(kubectl get pvc --namespace=$2 | awk '/'"$1"'/ { print $1 }'))
NAMESPACE="$2"

for pvc in ${PVC_NAMES[@]}; do
    echo "Deleting PVC $pvc"
    kubectl delete pvc $pvc --namespace=$NAMESPACE
done

TIMEOUT=300
T=0

for pvc in ${PVC_NAMES[@]}; do
    NUM_VOLUMES="$(aws ec2 describe-volumes --filter=Name=tag:kubernetes.io/created-for/pvc/name,Values=${pvc} | jq -r '.Volumes | length')"
    while [[ $NUM_VOLUMES -ne 0 && $T -le $TIMEOUT ]]; do
        sleep 1
        T=$((T+1))
        NUM_VOLUMES="$(aws ec2 describe-volumes --filter=Name=tag:kubernetes.io/created-for/pvc/name,Values=${pvc} | jq -r '.Volumes | length')"
    done

    if [ $T -gt $TIMEOUT ]; then
        VOLUME_ID="$(aws ec2 describe-volumes --filter=Name=tag:kubernetes.io/created-for/pvc/name,Values=${pvc} | jq -r '.Volumes[].VolumeId')"
        aws ec2 delete-volume --volume-id $VOLUME_ID
        if [[ $? -eq 0 && ! -z "$VOLUME_ID" ]]; then
            echo "Deleting volume $VOLUME_ID"

            TIMEOUT=300
            T=0
            NUM_VOLUMES="$(aws ec2 describe-volumes --filter=Name=tag:kubernetes.io/created-for/pvc/name,Values=${pvc} | jq -r '.Volumes | length')"
            while [[ $NUM_VOLUMES -ne 0 && $T -le $TIMEOUT ]]; do
                sleep 1
                T=$((T+1))
                NUM_VOLUMES="$(aws ec2 describe-volumes --filter=Name=tag:kubernetes.io/created-for/pvc/name,Values=${pvc} | jq -r '.Volumes | length')"
            done

            if [ $T -le $TIMEOUT ]; then
                echo "Timed out waiting for volume to become available"
            fi
        fi
    fi
done