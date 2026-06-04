# Components

## SharedInfraStack (`SharedInfraStack.java`)

The single CDK stack. All infrastructure is created in the constructor, sequenced as:

```
createNetworking() → createFlowLogs() → createEcrPullThroughCache()
→ createS3Endpoint() → createLaunchTemplates() → createNetworkSsmParams()
```

### Private methods

| Method | Responsibility |
|--------|---------------|
| `createNetworking(boolean)` | VPC, IGW, NAT subnet, public + private route tables, optional NAT gateway + EIP |
| `createFlowLogs(String vpcId)` | CloudWatch log group, IAM role, `CfnFlowLog` for ALL traffic |
| `createEcrPullThroughCache()` | Two `CfnPullThroughCacheRule`: `public-ecr` and `registry-k8s-io` |
| `createS3Endpoint(...)` | S3 gateway `CfnVPCEndpoint` associated with both route tables |
| `createLaunchTemplates()` | Iterates 4 `LtConfig` records; creates `CfnLaunchTemplate` + SSM param per config |
| `createNetworkSsmParams(Networking)` | SSM param for VPC ID |

### Internal records

- **`Networking(vpcId, publicRtId, privateRtId)`** — carries IDs between `createNetworking` and its callers
- **`LtConfig(arch, spot)`** — encapsulates per-launch-template variation; derives name, mode, instance type

## Launch Template Matrix

| CDK construct ID | LT name suffix | Instance type (default) |
|-----------------|---------------|------------------------|
| `Lt-spot-arm64` | `spot-arm64` | m7g.large |
| `Lt-ondemand-arm64` | `ondemand-arm64` | m7g.large |
| `Lt-spot-x86_64` | `spot-x86_64` | m7i.large |
| `Lt-ondemand-x86_64` | `ondemand-x86_64` | m7i.large |

All templates share: IMDS v2 required (`httpTokens=required`, hop limit 2), two encrypted gp3 EBS volumes (`/dev/xvda` configurable size, `/dev/sdf` fixed 20 GiB), instance + volume tags. Spot templates additionally set `marketType=spot`, `instanceInterruptionBehavior=hibernate`, `hibernationOptions.configured=true`.

## EksDxApp (`EksDxApp.java`)

CDK `App` entry point. Instantiates `SharedInfraStack` with account/region from `CDK_DEFAULT_ACCOUNT` / `CDK_DEFAULT_REGION` environment variables. No multi-environment branching.
