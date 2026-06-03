#!/usr/bin/env bash
# build-control-plane-ami.sh
#
# Thin wrapper — delegates the AMI build to the eks-d-xpress distribution repo.
# The actual packer config, boot scripts, and component versions live there.
#
# Usage:
#   ./build-control-plane-ami.sh                   # interactive
#   AWS_REGION=us-east-1 KUBERNETES_VERSION=1.35 AMI_VERSION=1.0.0 ./build-control-plane-ami.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Locate eks-d-xpress repo (sibling directory by default) ──────────────────
EKS_D_XPRESS_DIR="${EKS_D_XPRESS_DIR:-${SCRIPT_DIR}/../eks-d-xpress}"

if [ ! -d "$EKS_D_XPRESS_DIR/ami-builder" ]; then
  echo "==> eks-d-xpress not found at ${EKS_D_XPRESS_DIR} — cloning..."
  git clone git@github.com:plasticity-of-cloud/eks-d-xpress.git "$EKS_D_XPRESS_DIR"
fi

echo "==> Delegating AMI build to eks-d-xpress (${EKS_D_XPRESS_DIR})"
exec env \
  AWS_REGION="${AWS_REGION:-}" \
  KUBERNETES_VERSION="${KUBERNETES_VERSION:-}" \
  AMI_VERSION="${AMI_VERSION:-$(date +%Y%m%d-%H%M)}" \
  ARCH="${ARCH:-both}" \
  bash "${EKS_D_XPRESS_DIR}/ami-builder/build.sh"
