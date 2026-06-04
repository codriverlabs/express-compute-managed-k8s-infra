# Dependencies

## Runtime (CDK app)

| Artifact | Version | Purpose |
|----------|---------|---------|
| `software.amazon.awscdk:aws-cdk-lib` | 2.256.1 | CDK constructs (EC2, ECR, SSM, IAM, Logs) |
| `software.constructs:constructs` | 10.4.2 | CDK construct base |

## Build toolchain

| Tool | Version | Role |
|------|---------|------|
| Java | 21 | Compiler target (`maven.compiler.release=21`) |
| Maven | 3.x | Build, dependency management, exec plugin |
| `org.codehaus.mojo:exec-maven-plugin` | 3.1.0 | Runs `EksDxApp.main()` during CDK synth |
| AWS CDK CLI | any compatible | `cdk bootstrap / synth / deploy / destroy` |

## AWS Services provisioned

| Service | Usage |
|---------|-------|
| EC2 (VPC, subnets, route tables, IGW, NAT GW, EIP, endpoints) | Networking |
| EC2 (Launch Templates) | Node template for tenant provisioner / Karpenter |
| ECR (Pull-Through Cache Rules) | Mirror public registries into account ECR |
| CloudWatch Logs | VPC flow log destination |
| IAM | Flow logs delivery role |
| SSM Parameter Store | Output contract for consumers |
| CloudFormation | Stack management (via CDK) |

## AWS Service interactions at deploy time

| Step | AWS API |
|------|---------|
| Bootstrap | `sts:GetCallerIdentity`, various CloudFormation/S3/IAM bootstrap calls |
| Deploy | `cloudformation:CreateChangeSet`, `cloudformation:ExecuteChangeSet` |
| Destroy | `cloudformation:DeleteStack` |
