# Documentation Index

## How to Use This Documentation

This index is the primary entry point for AI assistants. Each section below describes what a file contains and when to consult it. In most cases, reading this index plus one or two targeted files is sufficient to answer questions about the codebase.

## File Summary

| File | Purpose | Consult When |
|------|---------|--------------|
| `codebase_info.md` | Project overview, tech stack, directory structure, naming conventions | Getting oriented; understanding what files exist and what they're called |
| `architecture.md` | System design, deployment paths, networking, IAM design, Karpenter-on-EKS-D specifics | Architecture questions; understanding how components relate; Karpenter configuration |
| `components.md` | Detailed description of every script, Terraform module, and Helm chart | Understanding what a specific script does; script execution order; entry points |
| `interfaces.md` | AWS APIs, Kubernetes endpoints, script arguments, env vars, persistent state file paths, Helm chart values | Finding script parameters; understanding what AWS permissions are needed; state file locations |
| `data_models.md` | Terraform variables, Kubernetes resource schemas, IAM policy structure, security group rules | Terraform variable reference; NodePool/EC2NodeClass schema; IAM policy details |
| `workflows.md` | Step-by-step sequence diagrams for all major operations | Understanding end-to-end flows; troubleshooting a specific phase |
| `dependencies.md` | All external dependencies: AWS services, Helm charts, container images, Terraform providers | Dependency versions; image registries; external URLs |
| `review_notes.md` | Consistency issues and documentation gaps | Understanding known limitations |

## Quick Reference

**"How do I deploy a new workstation?"** → `workflows.md` §3, `components.md` §deploy.sh

**"What IAM permissions does Karpenter need?"** → `data_models.md` §IAM Role Policy Structure

**"Why does the NodePool use `amiFamily: Custom`?"** → `architecture.md` §Karpenter on EKS-D

**"What scripts run at EC2 boot?"** → `components.md` §workstation-boot.sh, `workflows.md` §3

**"What env vars does deploy.sh accept?"** → `interfaces.md` §deploy.sh Environment Variables

**"Where is cluster state stored on the EC2?"** → `interfaces.md` §Persistent State Files

**"What's the script execution order?"** → `components.md` §Script Execution Order

**"How does worker node authentication work?"** → `architecture.md` §IAM Design, `components.md` §05b-install-aws-iam-authenticator.sh

**"What Helm charts are pre-pulled into the AMI?"** → `dependencies.md` §Helm Charts, `components.md` §install.sh
