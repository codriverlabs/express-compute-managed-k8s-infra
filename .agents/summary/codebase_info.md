# Codebase Information

## Project Identity

- **Name**: Express Compute Infra
- **Group**: `ai.codriverlabs`
- **Artifact**: `ecp-shared-infra-cdk`
- **Version**: 1.0.0

## Technology Stack

| Layer | Technology |
|-------|-----------|
| IaC | AWS CDK (Java) |
| Language | Java 21 |
| Build | Maven 3 |
| CDK Lib | 2.256.1 |
| Constructs | 10.4.2 |
| CI/CD | GitHub Actions |
| Pre-commit | trailing-whitespace, end-of-file-fixer, check-merge-conflict |

## Languages

| Language | Files | Purpose |
|----------|-------|---------|
| Java | 2 | CDK stack definition |
| Bash | 2 | Deploy/destroy scripts |
| YAML | 2 | GitHub Actions, pre-commit config |
| JSON | 1 | CDK config (`cdk.json`) |

## Source Layout

```
infra/src/main/java/ai/codriverlabs/ecp/
├── EcpManagedK8sInfraApp.java        — CDK App entry point
└── EcpManagedK8sInfraStack.java      — All infrastructure resources
```

## CDK Stack: `EcpManagedK8sInfraStack`

Single stack deploying shared VPC infrastructure for the Express Compute platform. Uses L1 (Cfn*) constructs for most resources due to needing fine-grained control over VPC layout and launch template options.

## Key Design Decisions

1. **Single stack** — all shared infra in one deployable unit
2. **CloudFormation Parameters** — runtime-configurable values passed via `--parameters` at deploy time (not CDK context)
3. **L1 constructs** — direct CloudFormation mappings for VPC, LTs, ECR cache rules
4. **No AMI in launch templates** — decouples AMI updates from infra deployments
5. **NAT gateway optional** — S3 gateway endpoint handles primary egress cost; NAT conditionally created via `CfnCondition`
6. **SSM parameter store** — output discovery mechanism for consuming services
7. **Spot + hibernation** — cost optimization with graceful interruption handling
8. **Region-agnostic synth** — region omitted from CDK Environment; passed as CfnParameter at deploy time
