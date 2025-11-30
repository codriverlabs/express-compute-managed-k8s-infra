#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_WORKSPACE="${SCRIPT_DIR}/test_workspace"

if [ ! -d "$TEST_WORKSPACE" ]; then
  echo "Error: Test workspace not found at ${TEST_WORKSPACE}"
  echo "Run ./setup-test-workspace.sh first"
  exit 1
fi

echo "=========================================="
echo "Copying Changes from Test Workspace"
echo "=========================================="
echo ""

read -p "This will overwrite production files. Continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Cancelled"
  exit 0
fi

echo "Copying infrastructure..."
cp -r "${TEST_WORKSPACE}/infrastructure/"* "${SCRIPT_DIR}/infrastructure/"

echo "Copying eks-d-setup..."
cp -r "${TEST_WORKSPACE}/eks-d-setup/"* "${SCRIPT_DIR}/eks-d-setup/"

echo "Copying node-pools..."
cp -r "${TEST_WORKSPACE}/node-pools/"* "${SCRIPT_DIR}/node-pools/"

echo "Copying karpenter-config..."
cp -r "${TEST_WORKSPACE}/karpenter-config/"* "${SCRIPT_DIR}/karpenter-config/" 2>/dev/null || true

echo "Copying monitoring..."
cp -r "${TEST_WORKSPACE}/monitoring/"* "${SCRIPT_DIR}/monitoring/" 2>/dev/null || true

echo ""
echo "=========================================="
echo "✓ Changes Copied to Production"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Review changes: git status"
echo "2. Test in production (if needed)"
echo "3. Commit: git add -A && git commit -m 'Your message'"
echo "4. Push: git push"
