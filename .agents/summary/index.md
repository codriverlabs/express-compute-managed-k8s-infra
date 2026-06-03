# Knowledge Base Index

## How to Use This Index

This is the primary context file for AI assistants. Read this file first — it contains enough metadata to determine which file to open for any specific question.

## Files

| File | What's inside | Use when you need to... |
|------|--------------|------------------------|
| `codebase_info.md` | Repo identity, active directory structure, tech stack | Understand what this repo does and how it's organized |
| `architecture.md` | CDK stack diagram, design decisions (NAT, IMDS, LT strategy), context defaults | Understand why things are built the way they are |
| `components.md` | `SharedInfraStack` method breakdown, `EksDxApp`, shell script responsibilities | Find which Java method or script creates a specific resource |
| `interfaces.md` | SSM params published, CDK context inputs, shell script args, ECR prefixes | Understand what this stack outputs for consumers |
| `data_models.md` | Java records (`Networking`, `LtConfig`), VPC CIDR layout, EBS volumes, resource tags | Understand data structures and resource configuration |
| `workflows.md` | Deploy/destroy sequence diagrams, CDK resource creation order | Understand deployment steps or debug a failed deploy |
| `dependencies.md` | Maven deps (CDK 2.256.1, Java 21), AWS services used, pre-commit hooks | Check versions or understand AWS service footprint |
| `review_notes.md` | Known bugs (wrong CDK dir path in shell scripts), completeness gaps | Find known issues before making changes |

## Quick Reference

**"How do I deploy?"** → `workflows.md`

**"What SSM params does this create?"** → `interfaces.md`

**"What does `createLaunchTemplates()` do?"** → `components.md` + `data_models.md`

**"Why is NAT Gateway disabled?"** → `architecture.md`

**"Are there any bugs?"** → `review_notes.md` (yes — shell scripts reference old `cdk/` path, should be `infra/`)
