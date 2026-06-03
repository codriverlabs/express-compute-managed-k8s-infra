# Interfaces

## SSM Parameter Store (output interface)

Resources published to SSM after deployment. These are the contract between this repo and consuming services (Lambda provisioner, Karpenter, etc.).

| SSM Path | Value | Consumer |
|----------|-------|---------|
| `/eks-d-xpress/infra/network/vpc-id` | VPC ID | Tenant provisioner |
| `/eks-d-xpress/infra/launch-template/arm64/spot` | LT ID | Karpenter / Lambda |
| `/eks-d-xpress/infra/launch-template/arm64/ondemand` | LT ID | Karpenter / Lambda |
| `/eks-d-xpress/infra/launch-template/x86_64/spot` | LT ID | Karpenter / Lambda |
| `/eks-d-xpress/infra/launch-template/x86_64/ondemand` | LT ID | Karpenter / Lambda |

## CDK Context (input interface)

All tunable parameters are CDK context keys, passed via `--context` or defined in `infra/cdk.json`:

| Key | Type | Default |
|-----|------|---------|
| `projectName` | String | `eks-dx-infra` |
| `instanceTypeArm64` | String | `m7g.large` |
| `instanceTypeX86_64` | String | `m7i.large` |
| `diskSizeGb` | int | `20` |
| `enableNatGateway` | boolean | `false` |

## Shell Script Interface

Both scripts accept positional args:
```
setup-shared-infra.sh [region] [projectName]   # defaults: us-east-1, eks-dx-infra
delete-shared-infra.sh [region] [projectName]
```

## ECR Pull-Through Cache (upstream registries)

| ECR prefix | Upstream |
|-----------|----------|
| `public-ecr/` | `public.ecr.aws` |
| `registry-k8s-io/` | `registry.k8s.io` |
