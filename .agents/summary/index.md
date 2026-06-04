# Knowledge Base Index

This directory contains generated documentation for `eks-d-xpress-infra`. Use this file as the primary entry point — it contains enough metadata to determine which file to read for any question.

## For AI Assistants

- **Architecture questions** (what does this deploy, how is it structured?) → `architecture.md`
- **Component/code questions** (what does each method do, what are the launch template configs?) → `components.md`
- **Integration questions** (how do consumers read outputs, what SSM paths exist?) → `interfaces.md`
- **Data/configuration questions** (CDK context keys, EBS layout, tags) → `data_models.md`
- **Process questions** (how to deploy/destroy, construction order) → `workflows.md`
- **Dependency questions** (versions, AWS services used) → `dependencies.md`
- **Inconsistencies/gaps** → `review_notes.md`

## Table of Contents

| File | Summary |
|------|---------|
| `codebase_info.md` | Language, build tool, active file list, what's excluded |
| `architecture.md` | Stack overview diagram, networking layout, design principles (no AMI in LTs, SSM as contract, NAT optional) |
| `components.md` | Per-method breakdown of `SharedInfraStack`, launch template matrix, `LtConfig` record |
| `interfaces.md` | All 5 SSM output paths, ECR pull-through prefixes, CDK context keys, script signatures, CloudWatch log group name pattern |
| `data_models.md` | `Networking` and `LtConfig` records, EBS volume layout, EC2 tag schema |
| `workflows.md` | Deploy and destroy sequence diagrams, stack construction order, tenant read flow |
| `dependencies.md` | Maven deps + versions, toolchain requirements, AWS services touched |
| `review_notes.md` | Identified inconsistencies and documentation gaps |

## Key Facts

- One stack: `EksDxSharedInfraStack` in `infra/src/main/java/cloud/plasticity/eksdx/`
- Deploy: `./setup-shared-infra.sh [region] [projectName]`
- Destroy: `./delete-shared-infra.sh [region] [projectName]`
- Consumer contract: SSM paths under `/eks-d-xpress/infra/`
- `archived/` directory contains legacy scripts — not part of the active system
