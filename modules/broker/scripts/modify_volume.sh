#!/bin/bash

if [ $# -ne 3 ]; then
    echo "Usage: $0 storage_class_name namespace_name volume_size"
    exit 1
fi

PVC_NAMES=($(kubectl get pvc --namespace=$2 | awk '/'"$1"'/ { print $1 }'))
NAMESPACE="$2"
VOLUME_SIZE="$3"

# Begin size increase for all volumes
declare -A VOLUME_MODIFY_TIMES
for pvc in ${PVC_NAMES[@]}; do
    VOLUME_ID="$(aws ec2 describe-volumes --filter=Name=tag:kubernetes.io/created-for/pvc/name,Values=${pvc} | jq -r '.Volumes[0].VolumeId')"
    if [ $? -ne 0 ]; then
        echo "Error: Couldn't get volume ID for storage class $1"
        exit 1
    fi

    CURR_SIZE="$(aws ec2 describe-volumes --volume-ids $VOLUME_ID | jq -r '.Volumes[0].Size')"
    if [ $CURR_SIZE -eq $VOLUME_SIZE ]; then
        echo "No change to volume required"
        exit 0
    fi

    echo "Modifying volume $VOLUME_ID size to $VOLUME_SIZE"
    VOLUME_MODIFY_INFO="$(aws ec2 modify-volume --volume-id $VOLUME_ID --size $VOLUME_SIZE)"
    if [ $? -ne 0 ]; then
        echo "Error: Unable to modify volume $VOLUME_ID to size $VOLUME_SIZE"
        exit 1
    fi

    # Store start time so that we can use it to get the progress on the modification
    START_TIME="$(echo $VOLUME_MODIFY_INFO | jq -r '.VolumeModification.StartTime')"
    VOLUME_MODIFY_TIMES["$VOLUME_ID"]="$START_TIME"
    if [ "$START_TIME" == "null" ]; then
        echo "Error validating start time"
        echo "$START_TIME ${VOLUME_MODIFY_TIMES["$VOLUME_ID"]}"
        exit 1
    fi
done

# Wait for the volumes to finish being modified
TIMEOUT=1800 #30 minutes
for pvc in ${PVC_NAMES[@]}; do
    VOLUME_ID="$(aws ec2 describe-volumes --filter=Name=tag:kubernetes.io/created-for/pvc/name,Values=${pvc} | jq -r '.Volumes[0].VolumeId')"
    VOLUME_PROGRESS="$(aws ec2 describe-volumes-modifications --volume-ids $VOLUME_ID | jq -r --arg start_time ${VOLUME_MODIFY_TIMES["$VOLUME_ID"]} '.VolumesModifications[] | select(.StartTime == $start_time) | .Progress')"

    T=0
    while [[ $VOLUME_PROGRESS -ne 100 && $T -lt $TIMEOUT ]]; do
        sleep 10
        T=$((T+10))
        VOLUME_PROGRESS="$(aws ec2 describe-volumes-modifications --volume-ids $VOLUME_ID | jq -r --arg start_time ${VOLUME_MODIFY_TIMES["$VOLUME_ID"]} '.VolumesModifications[] | select(.StartTime == $start_time) | .Progress')"
        echo "Current progress ($pvc): $VOLUME_PROGRESS"
    done

    if [ $T -ge $TIMEOUT ]; then
        echo "Timed out waiting for volume modifications to $VOLUME_ID to finish."
        echo "Current progress: $VOLUME_PROGRESS"
        exit
    fi
done