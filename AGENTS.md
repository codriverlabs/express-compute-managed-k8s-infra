# AGENTS.md - AI Assistant Guide

## Project Overview
**EKS-D-Xpress Infra** — Shared AWS infrastructure for the EKS-DX platform. Deploys a single CDK stack (`EksDxSharedInfraStack`) that provisions the VPC, EC2 launch templates, ECR pull-through cache, and S3 endpoint used by all EKS-DX tenants. Tenant control plane provisioning lives in a separate project.

## Directory Overview

```
eks-d-xpress-infra/
├── setup-shared-infra.sh         # Deploy: CDK bootstrap → mvn compile → cdk deploy
├── delete-shared-infra.sh        # Destroy: cdk destroy --force
├── infra/
│   ├── cdk.json                  # CDK app command + default context values
│   ├── pom.xml                   # Maven build (Java 21, aws-cdk-lib 2.256.1)
│   └── src/main/java/cloud/plasticity/eksdx/
│       ├── EksDxApp.java         # CDK App entry point
│       └── SharedInfraStack.java # All shared infra: VPC, LTs, ECR, S3 endpoint, flow logs
└── archived/                     # Legacy Terraform + eks-d-setup scripts — do not use
```

## Key Entry Points

| Task | Command |
|------|---------|
| Deploy shared infra | `./setup-shared-infra.sh [region] [projectName]` |
| Destroy shared infra | `./delete-shared-infra.sh [region] [projectName]` |

Both default to `region=us-east-1`, `projectName=eks-dx-infra`.

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
| `/eks-d-xpress/infra/network/vpc-id` | VPC ID |
| `/eks-d-xpress/infra/network/nat-gateway-enabled` | `true` or `false` |
| `/eks-d-xpress/infra/launch-template/{arch}/{spot\|ondemand}` | Launch template ID |

## CDK Context Defaults (`infra/cdk.json`)

| Key | Default | Override via |
|-----|---------|-------------|
| `projectName` | `eks-dx-infra` | `--context` or `cdk.json` |
| `instanceTypeArm64` | `c6g.xlarge` | same |
| `instanceTypeX86_64` | `m7i.large` | same |
| `diskSizeGb` | `20` | same (root volume `/dev/xvda`; `/dev/sdf` is fixed at 20 GiB) |
| `enableNatGateway` | `false` | same |

## Repo-Specific Patterns

### CDK project is in `infra/`, not `cdk/`
`setup-shared-infra.sh` and `delete-shared-infra.sh` both `cd` into `"$(dirname "$0")/infra"`.

### NAT Gateway disabled by default
`enableNatGateway: false` in `cdk.json`. The S3 gateway endpoint handles the primary egress cost driver. Set to `true` and redeploy if worker nodes need outbound internet beyond S3/ECR.

### Launch templates have no AMI ID
`imageId` is absent from all launch templates by design. The tenant provisioner passes the AMI as a `RunInstances` override. Do not add `imageId` to the templates — it would couple AMI updates to shared infra deployments.

### Spot launch templates require hibernation-capable instances
Spot LTs configure `instanceInterruptionBehavior: hibernate`. Not all instance types support hibernation — verify before changing `instanceTypeArm64` / `instanceTypeX86_64`.

### Maven compiles before CDK synth
The CDK app command in `cdk.json` is `mvn -e -q compile exec:java`. `cdk synth` and `cdk deploy` both trigger a Maven compile. The shell script also runs `mvn compile` explicitly for error visibility.

### ECR pull-through cache credentials
`registry.k8s.io` pull-through cache may require an upstream registry credential in AWS Secrets Manager depending on account configuration. Verify before first deploy to a new account.

### No test suite
There are no CDK assertion tests (`src/test/` does not exist). Changes to `SharedInfraStack.java` should be validated with `cdk synth` and diff review before deploy.

## Custom Instructions
<!-- This section is for human and agent-maintained operational knowledge.
     Add repo-specific conventions, gotchas, and workflow rules here.
     This section is preserved exactly as-is when re-running codebase-summary. -->
