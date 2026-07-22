# Dependencies

## Build Dependencies

| Dependency | Version | Purpose |
|-----------|---------|---------|
| `aws-cdk-lib` | 2.256.1 | AWS CDK constructs library |
| `constructs` | 10.4.2 | CDK constructs base |
| `exec-maven-plugin` | 3.1.0 | Run CDK app via Maven |

## Runtime Dependencies

| Tool | Version | Required For |
|------|---------|-------------|
| Java | 21 | Compile and run CDK app |
| Maven | 3+ | Build system |
| AWS CDK CLI | latest | Synth, deploy, destroy |
| AWS CLI | v2 | `sts get-caller-identity` in scripts |
| Node.js | 18+ | CDK CLI runtime |

## AWS Services Used

| Service | Usage | Cost |
|---------|-------|------|
| VPC | Network isolation | Free (base) |
| Internet Gateway | Public internet access | Free |
| NAT Gateway | Private subnet egress (optional) | ~$32/mo + data |
| Elastic IP | NAT Gateway (if enabled) | Free when attached |
| S3 Gateway Endpoint | Free S3 access from VPC | Free |
| ECR | Pull-through cache storage | Per-GB storage |
| CloudWatch Logs | VPC flow logs | Per-GB ingested |
| SSM Parameter Store | Output discovery | Free (standard tier) |
| EC2 Launch Templates | Instance configuration | Free |
| CloudFormation | Stack deployment | Free |

## Pre-commit Hooks

| Hook | Source | Purpose |
|------|--------|---------|
| `trailing-whitespace` | pre-commit-hooks v5.0.0 | Remove trailing whitespace |
| `end-of-file-fixer` | pre-commit-hooks v5.0.0 | Ensure files end with newline |
| `check-merge-conflict` | pre-commit-hooks v5.0.0 | Prevent merge conflict markers |

## CI/CD Dependencies

| Tool | Version | Purpose |
|------|---------|---------|
| `actions/checkout` | v7 | Git checkout |
| `actions/setup-java` | v5 | Java (Corretto) + Maven cache setup |
| `softprops/action-gh-release` | v3 | GitHub Release creation |
