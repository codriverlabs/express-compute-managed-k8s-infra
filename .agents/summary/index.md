# Documentation Index

> **For AI Assistants:** This file is your primary entry point. Read this first to understand the project and determine which files contain the details you need.

## Project Summary

This repository deploys shared AWS infrastructure for the Express Compute platform using a single AWS CDK stack (Java 21). It provisions a VPC, EC2 launch templates (spot + on-demand × arm64 + x86_64), ECR pull-through cache rules, an S3 gateway endpoint, and VPC flow logs. All resource IDs are published to SSM Parameter Store for consumption by tenant provisioning systems.

**Key design decisions:**
- Uses exclusively L1 (Cfn*) constructs for full control over CloudFormation output
- Region-agnostic synthesized template — region is a runtime CloudFormation parameter
- NAT gateway is conditional (disabled by default) to minimize cost
- Spot launch templates use persistent spot + hibernation for graceful interruption handling

## Documentation Map

| File | Purpose | Consult when... |
|------|---------|----------------|
| [codebase_info.md](codebase_info.md) | Tech stack, versions, build commands | You need to know how to build, deploy, or what versions are used |
| [architecture.md](architecture.md) | System design, resource relationships | You need to understand how components fit together |
| [components.md](components.md) | Detailed breakdown of each infrastructure component | You need specifics about VPC, LTs, ECR, or flow logs |
| [interfaces.md](interfaces.md) | SSM parameters, CloudFormation parameters, script interfaces | You need to know inputs/outputs or how consumers interact |
| [data_models.md](data_models.md) | Internal records, configuration structures | You need to understand code-level data structures |
| [workflows.md](workflows.md) | Deploy, destroy, release, and update workflows | You need to understand operational processes |
| [dependencies.md](dependencies.md) | External dependencies and their roles | You need to know what libraries are used and why |
| [review_notes.md](review_notes.md) | Documentation gaps and recommendations | You want to improve or extend this documentation |

## Quick Reference

- **Entry point:** `EcpManagedK8sInfraApp.java` → `ExpressComputeManagedK8sInfraStack.java`
- **Deploy:** `./setup-shared-infra.sh [region] [project]`
- **Destroy:** `./delete-shared-infra.sh [region] [project]`
- **Stack name:** `ExpressComputeManagedK8sInfraStack`
- **SSM namespace:** `/express-compute/infra/`

## How to Use This Documentation

1. **Start here** — this index gives you enough context to answer most high-level questions
2. **Drill into specific files** when you need implementation details
3. **Check interfaces.md** when the question is about inputs, outputs, or integration with other systems
4. **Check workflows.md** when the question is about operational procedures
