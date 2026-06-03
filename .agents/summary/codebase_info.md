# Codebase Info

## Identity
- **Repo**: eks-d-xpress-infra
- **Purpose**: Shared AWS infrastructure for the EKS-DX platform — VPC, EC2 launch templates, ECR pull-through cache
- **Language**: Java 21 (CDK), Bash
- **CDK version**: 2.256.1
- **Stack**: `EksDxSharedInfraStack`

## Active Directory Structure

```
eks-d-xpress-infra/
├── setup-shared-infra.sh         # CDK deploy: bootstrap → mvn compile → cdk deploy
├── delete-shared-infra.sh        # CDK destroy
├── infra/
│   ├── cdk.json                  # CDK app command + default context values
│   ├── pom.xml                   # Maven build (Java 21, aws-cdk-lib 2.256.1)
│   └── src/main/java/cloud/plasticity/eksdx/
│       ├── EksDxApp.java         # CDK App entry point
│       └── SharedInfraStack.java # All shared infra resources
└── archived/                     # Legacy scripts (Terraform, eks-d-setup, ami-builder) — do not use
```

## Technology Stack
| Layer | Technology |
|-------|-----------|
| IaC | AWS CDK v2 (Java) |
| Build | Maven 3, Java 21 |
| AWS services | EC2 (VPC, subnets, IGW, NAT, LTs), ECR, SSM, CloudWatch Logs |
| Shell wrapper | Bash (`set -euo pipefail`) |
