# Interfaces & Integration Points

## SSM Parameters (primary consumer interface)

All outputs are published to SSM; consumers never reference CloudFormation exports.

| SSM Path | Value | Published by |
|----------|-------|-------------|
| `/eks-d-xpress/infra/network/vpc-id` | VPC ID | `createNetworkSsmParams` |
| `/eks-d-xpress/infra/launch-template/arm64/spot` | LT ID | `createLaunchTemplates` |
| `/eks-d-xpress/infra/launch-template/arm64/ondemand` | LT ID | `createLaunchTemplates` |
| `/eks-d-xpress/infra/launch-template/x86_64/spot` | LT ID | `createLaunchTemplates` |
| `/eks-d-xpress/infra/launch-template/x86_64/ondemand` | LT ID | `createLaunchTemplates` |

## ECR Pull-Through Cache endpoints

| ECR prefix | Upstream registry | Used by |
|------------|-------------------|---------|
| `public-ecr/` | `public.ecr.aws` | Kubernetes system images |
| `registry-k8s-io/` | `registry.k8s.io` | Kubernetes system images |

Consumers pull from `<account>.dkr.ecr.<region>.amazonaws.com/public-ecr/...` and `registry-k8s-io/...`.

## CDK Context API

Consumers of the CDK app pass context via `--context` flags or `cdk.json`. All keys are read with `getNode().tryGetContext()`.

| Key | Type | Default |
|-----|------|---------|
| `projectName` | String | `eks-dx-infra` |
| `instanceTypeArm64` | String | `m7g.large` |
| `instanceTypeX86_64` | String | `m7i.large` |
| `diskSizeGb` | int | `20` |
| `enableNatGateway` | boolean | `false` |

## Deploy/Destroy Scripts

```
setup-shared-infra.sh  [region] [projectName]
delete-shared-infra.sh [region] [projectName]
```

Both scripts set `CDK_DEFAULT_REGION` and resolve `CDK_DEFAULT_ACCOUNT` via `aws sts get-caller-identity`. `setup-shared-infra.sh` also runs `cdk bootstrap` (idempotent) before deploy.

## CloudWatch Log Group

`/aws/vpc/<region>/<projectName>-flow-logs` — 1-week retention, destroyed on stack deletion.
