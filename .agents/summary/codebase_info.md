# Codebase Information

## Project Identity

- **Name:** Express Compute Managed K8s Infra
- **Group ID:** ai.codriverlabs
- **Artifact:** ecp-shared-infra-cdk
- **Version:** 1.0.0
- **License:** See LICENSE.md

## Technology Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Language | Java | 21 |
| IaC Framework | AWS CDK | 2.262.1 |
| Constructs lib | constructs | 10.7.1 |
| Build tool | Maven | 3.x |
| CI/CD | GitHub Actions | ubuntu-24.04 |
| Dependency mgmt | Dependabot | v2 |
| Pre-commit | pre-commit-hooks | v5.0.0 |

## Repository Statistics

| Metric | Value |
|--------|-------|
| Primary source files | 2 Java files |
| Shell scripts | 2 (deploy + destroy) |
| CI workflows | 1 (release) |
| Total managed resources (CloudFormation) | ~20 |

## Build & Deploy

- **CDK app command:** `mvn -e -q compile exec:java`
- **Deploy:** `./setup-shared-infra.sh [region] [projectName] [arm64Type] [x86Type] [diskGB] [natEnabled]`
- **Destroy:** `./delete-shared-infra.sh [region] [projectName]`
- **Release:** Push a `v*` tag → GitHub Actions builds tarball + checksums

## Configuration

Runtime parameters are defined in `infra/cdk.json` under `parameters` and passed as CloudFormation parameters at deploy time:

| Parameter | Default | Description |
|-----------|---------|-------------|
| ProjectName | ecp-managed-k8s-infra | Resource naming prefix |
| InstanceTypeArm64 | c6g.xlarge | ARM64 launch template instance type |
| InstanceTypeX86 | m7i.large | x86_64 launch template instance type |
| DiskSizeGb | 20 | Root EBS volume size (GiB) |
| EnableNatGateway | false | Conditional NAT gateway creation |
| Region | (deploy-time) | AWS region for the deployment |
