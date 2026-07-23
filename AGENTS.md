# AGENTS.md - AI Assistant Guide

## Project Overview
**Express Compute Infra** — Shared AWS infrastructure for the Express Compute platform for express Kubernetes deployments. First release includes eks-d-xpress. Deploys a single CDK stack (`ExpressComputeManagedK8sInfraStack`) that provisions the VPC, EC2 launch templates, ECR pull-through cache, and S3 endpoint used by all Express Compute tenants. Tenant control plane provisioning lives in a separate project.

## Directory Overview

```
express-compute-infra/
├── setup-shared-infra.sh         # Deploy: CDK bootstrap → mvn compile → cdk deploy
├── delete-shared-infra.sh        # Destroy: cdk destroy --force
├── infra/
│   ├── cdk.json                  # CDK app command + CloudFormation parameter defaults
│   ├── pom.xml                   # Maven build (Java 21, aws-cdk-lib 2.256.1)
│   └── src/main/java/ai/codriverlabs/ecp/
│       ├── EcpManagedK8sInfraApp.java         # CDK App entry point
│       └── ExpressComputeManagedK8sInfraStack.java  # All shared infra resources
└── archived/                     # Legacy Terraform + eks-d-setup scripts — do not use
```

## Key Entry Points

| Task | Command |
|------|---------|
| Deploy shared infra | `./setup-shared-infra.sh [region] [projectName] [arm64Type] [x86Type] [diskSizeGb] [enableNat]` |
| Destroy shared infra | `./delete-shared-infra.sh [region] [projectName]` |

Both default to `region=us-east-1`, `projectName=ecp-managed-k8s-infra`.

## What the Stack Creates

- **VPC** `10.0.0.0/16` with IGW, NAT subnet `10.0.0.0/24`, public + private route tables
- **S3 Gateway Endpoint** — free, attached to both route tables; keeps ECR pulls off NAT
- **ECR Pull-Through Cache** — `public-ecr/` → `public.ecr.aws`, `registry-k8s-io/` → `registry.k8s.io`, `quay-io/` → `quay.io`
- **VPC Flow Logs** → CloudWatch `/aws/vpc/<region>/<project>-flow-logs` (1-week retention)
- **4 Launch Templates** (spot + ondemand) × (arm64 + x86_64): no AMI ID, IMDS v2, encrypted EBS, spot uses hibernation
- **SSM Parameters**: VPC ID + 4 LT IDs published for consuming services

## SSM Output Paths

| Path | Value |
|------|-------|
| `/express-compute/infra/network/vpc-id` | VPC ID |
| `/express-compute/infra/network/nat-gateway-enabled` | `true` or `false` |
| `/express-compute/infra/launch-template/{arch}/{spot\|ondemand}` | Launch template ID |

## CloudFormation Parameters (`cdk.json`)

Configuration is via CloudFormation Parameters (CfnParameter), not CDK context. Defaults in `cdk.json`:

| Parameter | Default | Override via |
|-----------|---------|-------------|
| `ProjectName` | `ecp-managed-k8s-infra` | `--parameters` flag or script arg 2 |
| `InstanceTypeArm64` | `c6g.xlarge` | script arg 3 |
| `InstanceTypeX86` | `m7i.large` | script arg 4 |
| `DiskSizeGb` | `20` | script arg 5 |
| `EnableNatGateway` | `false` | script arg 6 |
| `Region` | (from script) | script arg 1 |

## Repo-Specific Patterns

### CDK project is in `infra/`, not `cdk/`
Both shell scripts `cd` into `"$(dirname "$0")/infra"`.

### CloudFormation Parameters, not CDK Context
The stack uses `CfnParameter` + `CfnCondition` for all runtime configuration. The `parameters` key in `cdk.json` maps to these. Do not use `getNode().tryGetContext()`.

### NAT Gateway disabled by default
`EnableNatGateway: false` in `cdk.json`. The S3 gateway endpoint handles the primary egress cost driver. Set to `true` and redeploy if worker nodes need outbound internet beyond S3/ECR.

### Launch templates have no AMI ID
`imageId` is absent from all launch templates by design. The tenant provisioner passes the AMI as a `RunInstances` override. Do not add `imageId` to the templates.

### Spot launch templates require hibernation-capable instances
Spot LTs configure `instanceInterruptionBehavior: hibernate`. Not all instance types support hibernation — verify before changing instance types.

### Maven compiles before CDK synth
The CDK app command in `cdk.json` is `mvn -e -q compile exec:java`. `cdk synth` and `cdk deploy` both trigger a Maven compile. The shell script also runs `mvn clean compile` explicitly for error visibility.

### Region-agnostic synthesis
The CDK app omits region from `Environment.builder()` so the synthesized template can deploy to any region. Region is passed as a CfnParameter at deploy time.

### ECR pull-through cache is for local builds
The cache rules (`public-ecr/`, `registry-k8s-io/`, `quay-io/`) are used for local development builds. Public AMIs are released using official public repositories. Secrets Manager credentials for upstream registries are not mandatory.

### No test suite
There are no CDK assertion tests (`src/test/` does not exist). Changes to `ExpressComputeManagedK8sInfraStack.java` should be validated with `cdk synth` and diff review before deploy.

### Pre-commit hooks
Configured via `.pre-commit-config.yaml`: trailing-whitespace, end-of-file-fixer, check-merge-conflict (pre-commit-hooks v5.0.0).

### CI/CD — tag-triggered GitHub release
`.github/workflows/release.yml` triggers on `v*` tags, builds with Java 21 (Corretto), runs `cdk synth`, packages a tarball + checksums, and creates a GitHub release.

## Custom Instructions
<!-- This section is for human and agent-maintained operational knowledge.
     Add repo-specific conventions, gotchas, and workflow rules here.
     This section is preserved exactly as-is when re-running codebase-summary. -->
