#!/bin/bash
set -e

echo "Updating system packages..."
sudo dnf update -y

echo "✓ Base system updated"
