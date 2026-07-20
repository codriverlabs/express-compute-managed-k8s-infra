# Workflows

## Deploy Workflow

```mermaid
sequenceDiagram
    participant User
    participant Script as setup-shared-infra.sh
    participant CDK as CDK CLI
    participant Maven
    participant AWS as AWS CloudFormation

    User->>Script: ./setup-shared-infra.sh [region] [project]
    Script->>CDK: cdk bootstrap
    CDK-->>Script: ✓ bootstrap complete
    Script->>Maven: mvn compile
    Maven-->>Script: ✓ build complete
    Script->>CDK: cdk synth EcpManagedK8sInfraStack
    CDK->>Maven: mvn compile exec:java
    Maven-->>CDK: ✓ template generated
    CDK-->>Script: ✓ synth complete
    Script->>CDK: cdk deploy --require-approval never
    CDK->>AWS: CreateChangeSet / ExecuteChangeSet
    AWS-->>CDK: Stack deployed
    CDK-->>Script: ✓ deploy complete
```

## Destroy Workflow

```mermaid
sequenceDiagram
    participant User
    participant Script as delete-shared-infra.sh
    participant CDK as CDK CLI
    participant AWS as AWS CloudFormation

    User->>Script: ./delete-shared-infra.sh [region] [project]
    Script->>CDK: cdk destroy --force
    CDK->>AWS: DeleteStack
    AWS-->>CDK: Stack deleted
    CDK-->>Script: ✓ destroy complete
```

## Release Workflow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub Actions
    participant Maven
    participant CDK as CDK CLI
    participant Release as GitHub Release

    Dev->>GH: Push tag v*
    GH->>GH: Checkout + setup Java 21
    GH->>GH: Install CDK CLI
    GH->>CDK: cdk synth (triggers Maven compile)
    CDK->>Maven: mvn compile exec:java
    Maven-->>CDK: ✓
    CDK-->>GH: cdk.out generated
    GH->>GH: tar czf (README + scripts + infra/)
    GH->>GH: sha256sum → checksums.sha256
    GH->>Release: Create release with assets
```

## Consumer Integration Pattern

```mermaid
sequenceDiagram
    participant Tenant as Tenant Provisioner
    participant SSM as SSM Parameter Store
    participant EC2 as EC2 API

    Tenant->>SSM: GetParameter(/express-compute/infra/network/vpc-id)
    SSM-->>Tenant: vpc-12345
    Tenant->>SSM: GetParameter(/express-compute/infra/launch-template/arm64/spot)
    SSM-->>Tenant: lt-abc123
    Tenant->>EC2: RunInstances(LaunchTemplate=lt-abc123, ImageId=ami-xxx)
    EC2-->>Tenant: Instance launched
```
