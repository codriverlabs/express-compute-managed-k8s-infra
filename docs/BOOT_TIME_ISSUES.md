# Boot Time Issues — 2026-05-22

Analysis of cold boot via `eks-dx-boot.service` on fresh tenant provision.
Total time: **180s (killed by systemd timeout)** — should be ~90s.

## Timeline

| Time | Duration | Step |
|------|----------|------|
| +0s | 3s | IMDS check + etcd + iam-authenticator |
| +3s | **10s** | **Downloading EKS-D binaries (kubeadm, kubelet, kubectl)** |
| +13s | 26s | kubeadm init (certs, static pods, control plane healthy) |
| +39s | **65s** | **VPC CNI install + aws-node pod readiness** |
| +104s | 12s | Cloud controller manager helm + CCM wait timeout |
| +116s | 11s | CCM node initialization |
| +127s | 4s | EBS CSI helm install |
| +131s | **0s** | **EBS CSI node wait — instant failure (wrong label selector)** |
| +131s | **30s** | **Metrics server wait timeout** |
| +161s | 19s | Karpenter + CloudWatch (killed at 180s) |

## Issues

### 1. EBS CSI node pod wait uses wrong label selector (instant failure)

**File:** `eks-d-setup/10-install-ebs-csi.sh`

**Current:** `app.kubernetes.io/component=node`  
**Actual pod label:** `app.kubernetes.io/component=csi-driver`

The EBS CSI Helm chart (v2.60.1) labels both controller and node pods with `component=csi-driver`. The wait command finds zero matching pods and fails immediately with "no matching resources found".

**Fix:** Change selector to `app=ebs-csi-node` (stable label set by the chart on the DaemonSet pods).

### 2. EKS-D binaries downloaded at boot instead of pre-baked (10s wasted)

**File:** `eks-d-setup/06-install-eks-d.sh` (lines 46-55)

kubeadm, kubelet, and kubectl are downloaded from `distro.eks.amazonaws.com` on every boot. These are ~130MB total and take 10s even on fast network.

**Fix:** Pre-install binaries during AMI build (in `ami-builder/scripts/install.sh`), skip download if already present at `/usr/local/bin/`.

### 3. VPC CNI aws-node pod takes 60s on cold boot

**Duration:** 65s (15:32:37 → 15:33:41)

On warm reset this is instant. On cold boot, containerd needs to set up overlayfs snapshots from cold page cache. The `aws-node` init container also needs IMDS/ENI to be fully configured.

**Mitigation:** This is largely unavoidable on cold boot. Could reduce by pre-unpacking the aws-node image layers during AMI build (`ctr images unpack`), but gains are marginal.

### 4. Metrics server wait times out (30s wasted)

The metrics-server deployment takes >30s to become ready on cold boot because it depends on the API server aggregation layer being fully initialized. The 30s timeout is too short.

**Fix:** Increase timeout to 60s, or remove the wait entirely (metrics-server is non-critical for cluster readiness).

### 5. SystemD timeout too short (180s)

Even without the above issues, cold boot legitimately takes ~160-180s due to sequential helm installs and pod scheduling. The 180s `TimeoutStartSec` leaves no margin.

**Fix:** Increase to 300s (5 min) to accommodate cold boot variance.

## Priority

1. **EBS CSI label fix** — trivial, eliminates false failure
2. **Pre-bake binaries** — saves 10s, eliminates network dependency at boot
3. **Increase systemd timeout** — prevents premature kill
4. **Metrics server timeout** — saves 30s of unnecessary waiting
5. **CNI cold start** — investigate but likely unavoidable
