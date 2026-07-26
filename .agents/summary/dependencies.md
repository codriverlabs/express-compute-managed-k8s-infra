# Dependencies

## Runtime Dependencies (Maven)

| Dependency | Version | Purpose |
|-----------|---------|---------|
| `software.amazon.awscdk:aws-cdk-lib` | 2.262.1 | AWS CDK core library — all L1/L2/L3 constructs |
| `software.constructs:constructs` | 10.7.1 | Constructs programming model (CDK foundation) |

## Build Dependencies

| Tool | Version/Constraint | Purpose |
|------|-------------------|---------|
| Java | 21 (release target) | Language runtime |
| Maven | 3.x | Build and dependency management |
| `org.codehaus.mojo:exec-maven-plugin` | 3.6.3 | Runs CDK app via `mvn exec:java` |

## CLI Tools (Deploy-time)

| Tool | Purpose |
|------|---------|
| AWS CDK CLI (`cdk`) | Synthesize and deploy CloudFormation |
| AWS CLI (`aws`) | Get caller identity, interact with AWS APIs |
| npm | Install CDK CLI globally |

## CI/CD Dependencies (GitHub Actions)

| Action | Version | Purpose |
|--------|---------|---------|
| `actions/checkout` | v7 | Clone repository |
| `actions/setup-java` | v5 | Install Corretto 21 with Maven cache |
| `softprops/action-gh-release` | v3 | Create GitHub release with artifacts |

## Development Tools

| Tool | Version | Purpose |
|------|---------|---------|
| pre-commit | — | Git hook framework |
| `pre-commit-hooks` | v5.0.0 | trailing-whitespace, end-of-file-fixer, check-merge-conflict |
| Dependabot | v2 | Automated dependency update PRs (weekly, Monday) |

## Dependency Update Strategy

- **Dependabot** monitors Maven and GitHub Actions dependencies weekly
- Max 5 open PRs per ecosystem to avoid PR fatigue
- Labels: `dependencies` + `java` (Maven) or `dependencies` + `ci` (Actions)

## AWS Service Dependencies (Runtime)

This stack creates resources in the following AWS services:

| Service | Resources Created |
|---------|------------------|
| EC2 | VPC, Subnets, Route Tables, IGW, NAT Gateway, EIP, Launch Templates, Flow Logs |
| ECR | Pull-Through Cache Rules (3) |
| CloudWatch Logs | Log Group (flow logs) |
| IAM | Role (flow logs) |
| SSM Parameter Store | StringParameters (6) |
| S3 (via endpoint) | Gateway Endpoint (no bucket created) |
