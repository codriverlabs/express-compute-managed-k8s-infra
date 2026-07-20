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

## CDK Context Model

Values read from CDK context at stack construction time:

```java
this.projectName       = (String) getNode().tryGetContext("projectName");
this.instanceTypeArm64 = (String) getNode().tryGetContext("instanceTypeArm64");
this.instanceTypeX86_64= (String) getNode().tryGetContext("instanceTypeX86_64");
this.diskSizeGb        = (int)    getNode().tryGetContext("diskSizeGb");
boolean enableNatGateway = Boolean.TRUE.equals(getNode().tryGetContext("enableNatGateway"));
```

## Tagging Model

All resources are tagged consistently:

| Tag | Applied To | Value |
|-----|-----------|-------|
| `Name` | All named resources | `{projectName}-{resource}` |
| `Project` | VPC, subnets, route tables, NAT | `{projectName}` |
| `ManagedBy` | All | `CDK` or `Karpenter` |
| `Platform` | LT instances/volumes | `express-compute` |
| `Arch` | LT instances | `arm64` or `x86_64` |
| `Mode` | Launch templates | `spot` or `on-demand` |
| `Type` | NAT subnet | `NAT` |

## EBS Volume Layout

Each launch template defines two block devices:

| Device | Type | Size | Encrypted | Purpose |
|--------|------|------|-----------|---------|
| `/dev/xvda` | gp3 | `diskSizeGb` (configurable) | Yes | Root volume |
| `/dev/sdf` | gp3 | 20 GiB (fixed) | Yes | Data volume |
