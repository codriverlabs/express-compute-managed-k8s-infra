#!/bin/bash
# Generates cloudformation-parameters.json with your current public IP pre-filled.
# Usage: ./generate-parameters.sh <team-member-name> <key-pair-name> [instance-type]

set -e

NAME="${1:?Usage: $0 <team-member-name> <key-pair-name> [instance-type]}"
KEY="${2:?Usage: $0 <team-member-name> <key-pair-name> [instance-type]}"
INSTANCE_TYPE="${3:-t3.medium}"

MY_IP=$(curl -sf https://checkip.amazonaws.com) || { echo "Error: Could not detect public IP. Set it manually in cloudformation-parameters.json"; exit 1; }
CIDR="${MY_IP}/32"

cat > cloudformation-parameters.json << EOF
[
  { "ParameterKey": "TeamMemberName",           "ParameterValue": "${NAME}" },
  { "ParameterKey": "ClusterName",              "ParameterValue": "" },
  { "ParameterKey": "ControlPlaneInstanceType", "ParameterValue": "${INSTANCE_TYPE}" },
  { "ParameterKey": "KeyPairName",              "ParameterValue": "${KEY}" },
  { "ParameterKey": "SSHCidrBlock",             "ParameterValue": "${CIDR}" },
  { "ParameterKey": "APIServerCidrBlock",       "ParameterValue": "${CIDR}" }
]
EOF

echo "Generated cloudformation-parameters.json"
echo "  TeamMemberName: ${NAME}"
echo "  KeyPairName:    ${KEY}"
echo "  AllowedCIDR:    ${CIDR}  (auto-detected)"
