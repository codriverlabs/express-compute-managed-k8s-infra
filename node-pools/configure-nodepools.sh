#!/bin/bash

set -e

# Get values from Terraform outputs or environment
CLUSTER_NAME=${CLUSTER_NAME:-$(kubectl config current-context)}
INSTANCE_PROFILE_NAME=${INSTANCE_PROFILE_NAME:-""}

if [ -z "$INSTANCE_PROFILE_NAME" ]; then
    echo "Error: INSTANCE_PROFILE_NAME not set"
    echo "Get it from Terraform output: terraform output worker_node_instance_profile"
    exit 1
fi

echo "Configuring NodePools for cluster: ${CLUSTER_NAME}"
echo "Using instance profile: ${INSTANCE_PROFILE_NAME}"

# Replace placeholders in NodePool files
sed -i "s/REPLACE_WITH_CLUSTER_NAME/${CLUSTER_NAME}/g" spot-nodepool.yaml ondemand-nodepool.yaml
sed -i "s/REPLACE_WITH_INSTANCE_PROFILE_NAME/${INSTANCE_PROFILE_NAME}/g" spot-nodepool.yaml ondemand-nodepool.yaml

echo "NodePool configurations updated!"
echo "Apply with: kubectl apply -f spot-nodepool.yaml"
echo "Or: kubectl apply -f ondemand-nodepool.yaml"
