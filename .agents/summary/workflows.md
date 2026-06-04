# Workflows

## Deploy

```mermaid
sequenceDiagram
    actor Dev
    participant Script as setup-shared-infra.sh
    participant CDK as CDK CLI
    participant Maven as Maven
    participant AWS

    Dev->>Script: ./setup-shared-infra.sh [region] [project]
    Script->>AWS: aws sts get-caller-identity (resolve account)
    Script->>CDK: cdk bootstrap aws://<account>/<region>
    CDK-->>Script: bootstrap complete
    Script->>Maven: mvn compile -f infra/pom.xml
    Maven-->>Script: compiled
    Script->>CDK: cdk synth EksDxSharedInfraStack --context projectName=...
    CDK->>Maven: mvn compile exec:java (via cdk.json app command)
    CDK-->>Script: template synthesized
    Script->>CDK: cdk deploy EksDxSharedInfraStack --require-approval never
    CDK->>AWS: CloudFormation CreateChangeSet / ExecuteChangeSet
    AWS-->>CDK: stack outputs
    CDK-->>Dev: deploy complete
```

Note: `mvn compile` runs twice — once explicitly in the script for early error visibility, and again implicitly when CDK invokes the app command from `cdk.json`.

## Destroy

```mermaid
sequenceDiagram
    actor Dev
    participant Script as delete-shared-infra.sh
    participant CDK as CDK CLI
    participant AWS

    Dev->>Script: ./delete-shared-infra.sh [region] [project]
    Script->>AWS: aws sts get-caller-identity
    Script->>CDK: cdk destroy EksDxSharedInfraStack --force
    CDK->>AWS: CloudFormation DeleteStack
    AWS-->>Dev: stack deleted (incl. CloudWatch log group)
```

## Stack Construction Sequence

```mermaid
flowchart LR
    A[Read context] --> B[createNetworking]
    B --> C[createFlowLogs]
    B --> D[createEcrPullThroughCache]
    B --> E[createS3Endpoint]
    B --> F[createLaunchTemplates]
    B --> G[createNetworkSsmParams]
    F --> G
```

## Consumer Read Flow (tenant provisioner)

```mermaid
sequenceDiagram
    participant Tenant as Tenant provisioner
    participant SSM
    participant EC2

    Tenant->>SSM: GetParameter /eks-d-xpress/infra/network/vpc-id
    Tenant->>SSM: GetParameter /eks-d-xpress/infra/launch-template/{arch}/{mode}
    SSM-->>Tenant: VPC ID + LT ID
    Tenant->>EC2: RunInstances (LaunchTemplate override + AMI ID)
```
