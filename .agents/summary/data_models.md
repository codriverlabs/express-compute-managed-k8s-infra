# Data Models

## Networking record
```java
private record Networking(String vpcId, String publicRtId, String privateRtId) {}
```
Internal transfer object passed between `createNetworking()`, `createFlowLogs()`, `createS3Endpoint()`, and `createNetworkSsmParams()`.

## LtConfig record
```java
private record LtConfig(String arch, boolean spot) {
    String key()   // → "spot-arm64" | "ondemand-arm64" | "spot-x86_64" | "ondemand-x86_64"
    String mode()  // → "spot" | "ondemand"
    String instanceType(String arm64Type, String x86Type)
}
```
Drives the 4-combination launch template matrix.

## VPC Layout

| Resource | CIDR / AZ |
|----------|-----------|
| VPC | `10.0.0.0/16` |
| NAT subnet (public) | `10.0.0.0/24`, AZ[0] |

Private subnets are created by the tenant provisioner in the consuming project; this stack only creates the shared NAT/public subnet and route tables.

## Launch Template EBS Volumes

| Device | Type | Size | Encrypted | Delete on term |
|--------|------|------|-----------|----------------|
| `/dev/xvda` (root) | gp3 | `diskSizeGb` (default 20 GiB) | yes | yes |
| `/dev/sdf` (data) | gp3 | 20 GiB (fixed) | yes | yes |

## Resource Tags (applied to all resources)

| Key | Value |
|-----|-------|
| `Name` | `<projectName>-<resource>` |
| `Project` | `<projectName>` |
| `ManagedBy` | `CDK` |

Instance/volume tags additionally include:
| Key | Value |
|-----|-------|
| `Platform` | `eks-d-xpress` |
| `Arch` | `arm64` or `x86_64` |
| `ManagedBy` | `Karpenter` (instance), `CDK` (volume) |
| `Mode` | `spot` or `on-demand` |
