# Knowledge Base Index

## Overview
This directory contains comprehensive documentation for the ECP Single-Node EKS-D project. AI assistants can use this index to locate relevant information about the codebase.

## File Summary

| File | Purpose | When to Use |
|------|---------|-------------|
| `codebase_info.md` | Project overview, structure, tech stack | Understanding the project at a high level |
| `architecture.md` | System architecture, diagrams, data flow | Understanding how components interact |
| `components.md` | Core components and their responsibilities | Finding specific component details |
| `interfaces.md` | APIs, scripts, deployment interfaces | Understanding how to deploy/use components |
| `data_models.md` | Templates, specs, configurations | Understanding configuration formats |
| `workflows.md` | Deployment and operational workflows | Following step-by-step procedures |
| `dependencies.md` | External dependencies and versions | Understanding requirements |
| `review_notes.md` | Documentation review findings | Identifying gaps or issues |

## Quick Reference

### Key Directories
- `infrastructure/` - CloudFormation templates and deployment scripts
- `eks-d-setup/` - EKS-D installation scripts (numbered sequence)
- `karpenter-config/` - Karpenter deployment
- `node-pools/` - NodePool definitions

### Key Scripts
- `infrastructure/deploy-vpc.sh` - Deploy shared VPC
- `infrastructure/deploy-developer.sh` - Deploy developer EC2 stack
- `eks-d-setup/install-all.sh` - Install all EKS-D components
- `node-pools/configure-nodepools.sh` - Configure Karpenter NodePools

### Common Tasks
| Task | Documentation |
|------|---------------|
| Deploy new environment | `workflows.md` |
| Configure Karpenter | `interfaces.md`, `components.md` |
| Understand networking | `architecture.md` |
| Modify NodePool | `data_models.md` |

## Usage for AI Assistants

When helping with this codebase:
1. Start with `codebase_info.md` for context
2. Use `architecture.md` to understand component relationships
3. Reference `interfaces.md` for deployment commands
4. Check `workflows.md` for step-by-step procedures

The documentation uses Mermaid diagrams for visual representations - these render properly in markdown viewers.

## Metadata
- **Generated**: 2026-04-12
- **Project**: ECP Single-Node EKS-D with Karpenter
- **Type**: Infrastructure-as-Code (Bash + CloudFormation + Kubernetes)
