# Workflows

## Deploy Shared Infrastructure

```mermaid
sequenceDiagram
    participant Dev
    participant Script as setup-shared-infra.sh
    participant CDK as cdk CLI
    participant Maven as mvn
    participant AWS

    Dev->>Script: ./setup-shared-infra.sh [region] [projectName]
    Script->>AWS: sts get-caller-identity (resolve account)
    Script->>CDK: cdk bootstrap aws://<account>/<region>
    CDK-->>Script: bootstrap complete (idempotent)
    Script->>Maven: mvn compile -f infra/pom.xml
    Maven-->>Script: classes compiled
    Script->>CDK: cdk synth EksDxSharedInfraStack
    CDK-->>Script: template written to infra/cdk.out/
    Script->>CDK: cdk deploy EksDxSharedInfraStack --require-approval never
    CDK->>AWS: CreateChangeSet + ExecuteChangeSet
    AWS-->>CDK: stack outputs
    CDK-->>Dev: deploy complete
```

## Destroy Shared Infrastructure

```mermaid
sequenceDiagram
    participant Dev
    participant Script as delete-shared-infra.sh
    participant CDK as cdk CLI
    participant AWS

    Dev->>Script: ./delete-shared-infra.sh [region] [projectName]
    Script->>CDK: cdk destroy EksDxSharedInfraStack --force
    CDK->>AWS: DeleteStack
    AWS-->>Dev: stack deleted
```

## CDK Synth / Resource Creation Order

```mermaid
graph TD
    A[createNetworking] --> B[createFlowLogs]
    A --> C[createS3Endpoint]
    A --> D[createNetworkSsmParams]
    E[createEcrPullThroughCache] -->|independent| F[done]
    G[createLaunchTemplates] -->|independent| H[SSM LT params]
    A --> I[VPC ready]
    I --> E
    I --> G
```

Resources with no VPC dependency (`createEcrPullThroughCache`, `createLaunchTemplates`) are synthesized independently. CDK handles CloudFormation dependency ordering automatically.

## Updating Context Values

To change instance types or disk size without modifying `cdk.json`:
```bash
./setup-shared-infra.sh us-east-1 eks-dx-infra \
  # CDK --context flags can be appended by editing setup-shared-infra.sh
  # or by modifying infra/cdk.json defaults
```

To enable NAT Gateway:
```bash
# Edit infra/cdk.json: "enableNatGateway": true
# Then re-run setup-shared-infra.sh
```
