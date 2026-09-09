# k3s-Xpress: Shared Infrastructure Changes

Changes required in `express-compute-managed-k8s-infra` to support k3s-Xpress.

---

## 1. What Needs to Change

The infra stack currently creates **4 launch templates** for EKS-D:
- `{project}-spot-arm64-{region}`
- `{project}-ondemand-arm64-{region}`
- `{project}-spot-x86_64-{region}`
- `{project}-ondemand-x86_64-{region}`

Each has:
- Root volume: `/dev/xvda` — 20 GB gp3 (configurable via `DiskSizeGb`)
- Data volume: `/dev/sdf` — 20 GB gp3 (etcd for EKS-D)

For k3s-Xpress, we need **4 additional launch templates** with:
- Root volume: `/dev/xvda` — **15 GB** gp3 (k3s is smaller)
- Data volume: `/dev/sdf` — **2 GB** gp3 (SQLite state, consistent layout with EKS-D)
- Smaller default instance types: `c6g.large` (arm64), `m7i.large` (x86_64)

---

## 2. CDK Stack Changes

### 2.1 New Parameters

```java
CfnParameter pK3sInstanceTypeArm64 = CfnParameter.Builder.create(this, "K3sInstanceTypeArm64")
        .type("String")
        .defaultValue("c6g.large")
        .description("k3s-Xpress ARM64 instance type")
        .build();

CfnParameter pK3sInstanceTypeX86 = CfnParameter.Builder.create(this, "K3sInstanceTypeX86")
        .type("String")
        .defaultValue("m7i.large")
        .description("k3s-Xpress x86_64 instance type")
        .build();

CfnParameter pK3sDiskSizeGb = CfnParameter.Builder.create(this, "K3sDiskSizeGb")
        .type("Number")
        .defaultValue(15)
        .description("k3s-Xpress root disk size in GiB")
        .build();

CfnParameter pK3sDataDiskSizeGb = CfnParameter.Builder.create(this, "K3sDataDiskSizeGb")
        .type("Number")
        .defaultValue(2)
        .description("k3s-Xpress data disk size in GiB (SQLite state)")
        .build();
```

### 2.2 New Launch Templates

Add a call to `createK3sLaunchTemplates()` alongside the existing EKS-D templates:

```java
// In constructor, after existing createLaunchTemplates():
createK3sLaunchTemplates(
    projectName,
    pK3sInstanceTypeArm64.getValueAsString(),
    pK3sInstanceTypeX86.getValueAsString(),
    pK3sDiskSizeGb.getValueAsNumber(),
    pK3sDataDiskSizeGb.getValueAsNumber(),
    region
);
```

```java
private void createK3sLaunchTemplates(String projectName, String instanceTypeArm64,
                                       String instanceTypeX86_64, Number rootDiskSizeGb,
                                       Number dataDiskSizeGb, String region) {
    List<LtConfig> configs = List.of(
            new LtConfig("arm64",  true),
            new LtConfig("arm64",  false),
            new LtConfig("x86_64", true),
            new LtConfig("x86_64", false)
    );

    for (LtConfig cfg : configs) {
        String ltName = projectName + "-k3s-" + cfg.key() + "-" + region;

        var ltDataBuilder = CfnLaunchTemplate.LaunchTemplateDataProperty.builder()
                .instanceType(cfg.instanceType(instanceTypeArm64, instanceTypeX86_64))
                .metadataOptions(CfnLaunchTemplate.MetadataOptionsProperty.builder()
                        .httpTokens("required")
                        .httpPutResponseHopLimit(2)
                        .build())
                .blockDeviceMappings(List.of(
                        // Root volume (smaller for k3s)
                        CfnLaunchTemplate.BlockDeviceMappingProperty.builder()
                                .deviceName("/dev/xvda")
                                .ebs(CfnLaunchTemplate.EbsProperty.builder()
                                        .volumeType("gp3")
                                        .volumeSize(rootDiskSizeGb)
                                        .deleteOnTermination(true)
                                        .encrypted(true)
                                        .build())
                                .build(),
                        // Data volume — SQLite state (consistent with EKS-D etcd volume)
                        CfnLaunchTemplate.BlockDeviceMappingProperty.builder()
                                .deviceName("/dev/sdf")
                                .ebs(CfnLaunchTemplate.EbsProperty.builder()
                                        .volumeType("gp3")
                                        .volumeSize(dataDiskSizeGb)
                                        .deleteOnTermination(true)
                                        .encrypted(true)
                                        .build())
                                .build()))
                .tagSpecifications(List.of(
                        CfnLaunchTemplate.TagSpecificationProperty.builder()
                                .resourceType("instance")
                                .tags(List.of(
                                        tag("Platform", "k3s-xpress"),
                                        tag("Distribution", "k3s"),
                                        tag("Arch", cfg.arch()),
                                        tag("ManagedBy", "Karpenter")))
                                .build(),
                        CfnLaunchTemplate.TagSpecificationProperty.builder()
                                .resourceType("volume")
                                .tags(List.of(
                                        tag("Platform", "k3s-xpress"),
                                        tag("ManagedBy", "CDK")))
                                .build()));

        if (cfg.spot()) {
            ltDataBuilder
                    .instanceMarketOptions(CfnLaunchTemplate.InstanceMarketOptionsProperty.builder()
                            .marketType("spot")
                            .spotOptions(CfnLaunchTemplate.SpotOptionsProperty.builder()
                                    .spotInstanceType("persistent")
                                    .instanceInterruptionBehavior("hibernate")
                                    .build())
                            .build())
                    .hibernationOptions(CfnLaunchTemplate.HibernationOptionsProperty.builder()
                            .configured(true)
                            .build());
        }

        CfnLaunchTemplate lt = CfnLaunchTemplate.Builder.create(this, "K3sLt-" + cfg.key())
                .launchTemplateName(ltName)
                .launchTemplateData(ltDataBuilder.build())
                .tagSpecifications(List.of(
                        CfnLaunchTemplate.LaunchTemplateTagSpecificationProperty.builder()
                                .resourceType("launch-template")
                                .tags(List.of(
                                        tag("Name", ltName),
                                        tag("Platform", "k3s-xpress"),
                                        tag("Distribution", "k3s"),
                                        tag("Arch", cfg.arch()),
                                        tag("Mode", cfg.spot() ? "spot" : "on-demand"),
                                        tag("ManagedBy", "CDK")))
                                .build()))
                .build();

        // SSM path: /express-compute/infra/launch-template/k3s/{arch}/{mode}
        StringParameter.Builder.create(this, "K3sSsmLt-" + cfg.key())
                .parameterName("/express-compute/infra/launch-template/k3s/"
                        + cfg.arch() + "/" + cfg.mode())
                .stringValue(lt.getRef())
                .description("k3s-Xpress launch template ID — " + cfg.key())
                .build();
    }
}
```

### 2.3 SSM Parameters Published (New)

| SSM Path | Value | Description |
|----------|-------|-------------|
| `/express-compute/infra/launch-template/k3s/arm64/spot` | Launch template ID | k3s ARM64 spot |
| `/express-compute/infra/launch-template/k3s/arm64/ondemand` | Launch template ID | k3s ARM64 on-demand |
| `/express-compute/infra/launch-template/k3s/x86_64/spot` | Launch template ID | k3s x86_64 spot |
| `/express-compute/infra/launch-template/k3s/x86_64/ondemand` | Launch template ID | k3s x86_64 on-demand |

Existing EKS-D parameters are unchanged.

---

## 3. setup-shared-infra.sh Changes

Add k3s parameters to the deploy command:

```bash
K3S_INSTANCE_TYPE_ARM64="${7:-c6g.large}"
K3S_INSTANCE_TYPE_X86="${8:-m7i.large}"
K3S_DISK_SIZE_GB="${9:-15}"
K3S_DATA_DISK_SIZE_GB="${10:-2}"

cdk deploy ExpressComputeManagedK8sInfraStack \
  # ... existing parameters ...
  --parameters ExpressComputeManagedK8sInfraStack:K3sInstanceTypeArm64="${K3S_INSTANCE_TYPE_ARM64}" \
  --parameters ExpressComputeManagedK8sInfraStack:K3sInstanceTypeX86="${K3S_INSTANCE_TYPE_X86}" \
  --parameters ExpressComputeManagedK8sInfraStack:K3sDiskSizeGb="${K3S_DISK_SIZE_GB}" \
  --parameters ExpressComputeManagedK8sInfraStack:K3sDataDiskSizeGb="${K3S_DATA_DISK_SIZE_GB}" \
  --require-approval never
```

---

## 4. k3s Boot Script Changes (in express-compute-platform)

The `setup-k3s-xpress.sh` needs a step to mount the data volume, mirroring
the EKS-D `05-prepare-etcd.sh`:

```bash
# Step 1b: Prepare data volume (same pattern as EKS-D etcd volume)
echo "Step 1b: Preparing k3s data volume..."
DATA_DEVICE="/dev/sdf"
# NVMe alias on Nitro instances
[ -b /dev/nvme1n1 ] && DATA_DEVICE="/dev/nvme1n1"

DATA_DIR="/var/lib/rancher/k3s/server/db"
sudo mkdir -p "${DATA_DIR}"

# Format only if not already formatted
if ! sudo blkid "${DATA_DEVICE}" &>/dev/null; then
  sudo mkfs.ext4 -L k3s-data "${DATA_DEVICE}"
fi

# Mount and persist
sudo mount "${DATA_DEVICE}" "${DATA_DIR}"
echo "LABEL=k3s-data ${DATA_DIR} ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
echo "✓ k3s data volume mounted at ${DATA_DIR}"
```

This ensures SQLite (`state.db`) lives on the dedicated EBS volume, surviving
root volume replacement. The DLM snapshot policy applies to this volume the
same way it does for EKS-D etcd.

---

## 5. Volume Comparison

| | EKS-D | k3s-Xpress |
|---|---|---|
| Root (`/dev/xvda`) | 20 GB gp3 | 15 GB gp3 |
| Data (`/dev/sdf`) | 20 GB gp3 (etcd WAL) | 2 GB gp3 (SQLite state.db) |
| Data mount point | `/var/lib/etcd` | `/var/lib/rancher/k3s/server/db` |
| DLM snapshots | ✓ | ✓ (same policy) |
| Monthly cost | ~$3.20 | ~$1.36 |

---

## 6. README.md Updates

Add k3s to the "What This Deploys" section:

```markdown
- **8 EC2 Launch Templates** — EKS-D (4) + k3s (4): (spot + on-demand) × (arm64 + x86_64)
```

Add k3s SSM outputs:

```markdown
| `/express-compute/infra/launch-template/k3s/{arch}/{spot\|ondemand}` | k3s launch template ID |
```

Add k3s parameters to the configuration table:

```markdown
| `k3sInstanceTypeArm64` | `c6g.large` | k3s ARM64 instance type |
| `k3sInstanceTypeX86_64` | `m7i.large` | k3s x86_64 instance type |
| `k3sDiskSizeGb` | `15` | k3s root EBS volume size in GiB |
| `k3sDataDiskSizeGb` | `2` | k3s data EBS volume size in GiB (SQLite) |
```
