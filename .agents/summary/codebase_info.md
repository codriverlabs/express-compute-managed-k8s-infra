# Codebase Info

- **Project**: eks-d-xpress-infra
- **Purpose**: Shared AWS infrastructure for the EKS-DX platform (single CDK stack)
- **Language**: Java 21
- **Build**: Maven 3 + AWS CDK CLI
- **CDK version**: aws-cdk-lib 2.256.1
- **constructs**: 10.4.2
- **CDK app entry**: `cloud.plasticity.eksdx.EksDxApp`
- **Stack name**: `EksDxSharedInfraStack`

## Active Source Files

```
infra/
├── cdk.json                                          # CDK app command + context defaults
├── pom.xml                                           # Maven build descriptor
└── src/main/java/cloud/plasticity/eksdx/
    ├── EksDxApp.java                                 # CDK App entry point
    └── SharedInfraStack.java                         # All infra: VPC, LTs, ECR, S3 endpoint, flow logs
setup-shared-infra.sh                                 # Deploy wrapper
delete-shared-infra.sh                                # Destroy wrapper
```

## Excluded

`archived/` — legacy Terraform and bash provisioning scripts; not part of the active system.
