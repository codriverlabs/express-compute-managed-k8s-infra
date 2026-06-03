# Components

## SharedInfraStack (`infra/src/main/java/.../SharedInfraStack.java`)

Single CDK stack that owns all shared resources. Broken into private methods by concern:

| Method | Resources created |
|--------|------------------|
| `createNetworking()` | VPC, IGW, NAT subnet, public RT, private RT, optional NAT GW + EIP |
| `createFlowLogs()` | CloudWatch log group (`/aws/vpc/<region>/<project>-flow-logs`), IAM role, CfnFlowLog |
| `createEcrPullThroughCache()` | Two `CfnPullThroughCacheRule`: `public-ecr` → `public.ecr.aws`, `registry-k8s-io` → `registry.k8s.io` |
| `createS3Endpoint()` | S3 gateway `CfnVPCEndpoint` attached to both route tables |
| `createLaunchTemplates()` | 4 `CfnLaunchTemplate` + 4 SSM params (one per arch/mode combo) |
| `createNetworkSsmParams()` | SSM param: `/eks-d-xpress/infra/network/vpc-id` |

### LtConfig record
Internal `record LtConfig(String arch, boolean spot)` drives the 4-LT matrix. Each config produces:
- Launch template name: `<projectName>-<spot|ondemand>-<arch>`
- Two EBS volumes: root (`/dev/xvda`, configurable size) + data (`/dev/sdf`, 20 GiB fixed)
- SSM param at `/eks-d-xpress/infra/launch-template/<arch>/<spot|ondemand>`

## EksDxApp (`EksDxApp.java`)
Minimal CDK App entry point. Reads `CDK_DEFAULT_ACCOUNT` / `CDK_DEFAULT_REGION` from environment (set by `setup-shared-infra.sh` before `cdk deploy`).

## setup-shared-infra.sh
Orchestration wrapper:
1. Calls `aws sts get-caller-identity` to resolve account ID
2. Runs `cdk bootstrap` (idempotent)
3. Runs `mvn -e -q compile` inside `infra/`
4. `cdk synth EksDxSharedInfraStack`
5. `cdk deploy EksDxSharedInfraStack --require-approval never`

The script references `cdk/` path but the actual CDK directory is now `infra/` — see review_notes.md.

## delete-shared-infra.sh
Thin wrapper: sets env vars, runs `cdk destroy EksDxSharedInfraStack --force`.
