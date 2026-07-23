# Data Models

## Internal Records

### `Networking`

Lightweight carrier for VPC resource IDs returned by `createNetworking()`.

```java
private record Networking(String vpcId, String publicRtId, String privateRtId) {}
```

### `LtConfig`

Configuration tuple for launch template generation. Drives the 4-template cross-product.

```java
private record LtConfig(String arch, boolean spot) {
    String key()          // e.g., "spot-arm64"
    String mode()         // "spot" or "ondemand"
    String instanceType(String arm64Type, String x86Type)
}
```

## CloudFormation Parameter Model

Values read at stack construction via `CfnParameter`:

```java
CfnParameter pProjectName      = CfnParameter.Builder.create(this, "ProjectName").type("String").build();
CfnParameter pInstanceTypeArm64= CfnParameter.Builder.create(this, "InstanceTypeArm64").type("String").build();
CfnParameter pInstanceTypeX86  = CfnParameter.Builder.create(this, "InstanceTypeX86").type("String").build();
CfnParameter pDiskSizeGb       = CfnParameter.Builder.create(this, "DiskSizeGb").type("Number").build();
CfnParameter pEnableNatGateway = CfnParameter.Builder.create(this, "EnableNatGateway")
        .type("String").allowedValues(List.of("true", "false")).build();
CfnParameter pRegion           = CfnParameter.Builder.create(this, "Region").type("String").build();
```

The `EnableNatGateway` parameter drives a `CfnCondition` that gates NAT Gateway + EIP creation.

## Tagging Model

All resources are tagged consistently:

| Tag | Applied To | Value |
|-----|-----------|-------|
| `Name` | All named resources | `{projectName}-{resource}` |
| `Project` | VPC, subnets, route tables, NAT | `{projectName}` |
| `ManagedBy` | All | `CDK` or `Karpenter` |
| `Platform` | LT instances/volumes | `express-compute` |
| `Arch` | LT instances, launch templates | `arm64` or `x86_64` |
| `Mode` | Launch templates | `spot` or `on-demand` |
| `Type` | NAT subnet | `NAT` |

## EBS Volume Layout

Each launch template defines two block devices:

| Device | Type | Size | Encrypted | Purpose |
|--------|------|------|-----------|---------|
| `/dev/xvda` | gp3 | `DiskSizeGb` (configurable) | Yes | Root volume |
| `/dev/sdf` | gp3 | 20 GiB (fixed) | Yes | Data volume |
