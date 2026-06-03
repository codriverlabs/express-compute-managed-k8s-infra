# Dependencies

## Runtime (Maven — `infra/pom.xml`)

| Dependency | Version | Purpose |
|-----------|---------|---------|
| `software.amazon.awscdk:aws-cdk-lib` | 2.256.1 | All CDK constructs (EC2, ECR, SSM, IAM, Logs) |
| `software.constructs:constructs` | 10.4.2 | CDK construct base classes |

Java compiler target: **21**.

## Build Tools

| Tool | Version | Notes |
|------|---------|-------|
| Maven | 3.x | `exec-maven-plugin` 3.1.0 runs `EksDxApp.main()` for CDK synth |
| CDK CLI | Any v2 | Must be installed separately (`npm i -g aws-cdk`) |

## AWS Services Used

| Service | Usage |
|---------|-------|
| EC2 | VPC, subnets, IGW, NAT GW, route tables, launch templates, VPC endpoints |
| ECR | Pull-through cache rules |
| SSM Parameter Store | Publishes VPC ID and LT IDs for consumers |
| CloudWatch Logs | VPC flow logs |
| IAM | Flow logs delivery role |
| STS | Account ID resolution in `setup-shared-infra.sh` |

## Pre-commit Hooks (`.pre-commit-config.yaml`)

| Hook | Purpose |
|------|---------|
| `trailing-whitespace` | Remove trailing whitespace |
| `end-of-file-fixer` | Ensure files end with newline |
| `check-merge-conflict` | Block committing merge conflict markers |
