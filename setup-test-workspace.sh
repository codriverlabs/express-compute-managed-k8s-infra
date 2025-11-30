#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_WORKSPACE="${SCRIPT_DIR}/test_workspace"

echo "=========================================="
echo "Setting Up Test Workspace"
echo "=========================================="
echo ""

# Remove existing test workspace if it exists
if [ -d "$TEST_WORKSPACE" ]; then
  echo "Removing existing test workspace..."
  rm -rf "$TEST_WORKSPACE"
fi

# Create test workspace
echo "Creating test workspace..."
mkdir -p "$TEST_WORKSPACE"

# Copy all necessary files
echo "Copying files to test workspace..."
cp -r "${SCRIPT_DIR}/infrastructure" "$TEST_WORKSPACE/"
cp -r "${SCRIPT_DIR}/eks-d-setup" "$TEST_WORKSPACE/"
cp -r "${SCRIPT_DIR}/node-pools" "$TEST_WORKSPACE/"
cp -r "${SCRIPT_DIR}/karpenter-config" "$TEST_WORKSPACE/"
cp -r "${SCRIPT_DIR}/monitoring" "$TEST_WORKSPACE/"

# Copy documentation
cp "${SCRIPT_DIR}/README.md" "$TEST_WORKSPACE/"
cp "${SCRIPT_DIR}/DEPLOYMENT_GUIDE.md" "$TEST_WORKSPACE/" 2>/dev/null || true
cp "${SCRIPT_DIR}/cost-estimation.md" "$TEST_WORKSPACE/" 2>/dev/null || true

echo ""
echo "=========================================="
echo "✓ Test Workspace Ready"
echo "=========================================="
echo ""
echo "Location: ${TEST_WORKSPACE}"
echo ""
echo "Next steps:"
echo "1. cd ${TEST_WORKSPACE}/infrastructure"
echo "2. Make your changes and test"
echo "3. If successful, copy changes back:"
echo "   ./copy-from-test-workspace.sh"
echo ""
echo "To start over:"
echo "   ./setup-test-workspace.sh"
