# Review Notes

## Consistency Issues

### 1. NodePool YAML files use deprecated API version
~~`node-pools/spot-nodepool.yaml` and `node-pools/ondemand-nodepool.yaml` use `karpenter.sh/v1beta1` and `karpenter.k8s.aws/v1beta1`.~~

**Resolved**: Both files updated to `karpenter.sh/v1` / `karpenter.k8s.aws/v1`, `amiFamily: Custom` with nodeadm userData, and `WhenEmptyOrUnderutilized` consolidation policy. Header comment added to both files warning not to apply them directly.

### 2. AGENTS.md references outdated script names
The existing `AGENTS.md` references `deploy-developer.sh` (does not exist) and `infrastructure/` directory (does not exist). The actual scripts are `deploy.sh`, `bootstrap.sh`, etc. in the root directory.

**Recommendation**: Update AGENTS.md (done as part of this consolidation run).

### 3. Karpenter version mismatch
The existing `AGENTS.md` states "Karpenter v1.8.2" but the actual installed version is 1.10.0 (per `11-install-karpenter.sh`).

**Recommendation**: Updated in consolidated AGENTS.md.

## Completeness Gaps

### 1. `reset-cluster.sh` not documented
`eks-d-setup/reset-cluster.sh` exists but was not analyzed. It likely runs `kubeadm reset` to wipe the cluster for re-initialization.

### 2. `tag-vpc-amis.sh` behavior not fully analyzed
The script tags AL2023 AMIs for EKS version compatibility but the exact tagging logic was not read in detail.

### 3. No documentation for `terraform/vpc/main.tf`
The shared VPC Terraform module was not read. It provisions the VPC, IGW, NAT Gateway, and route tables but the exact CIDR ranges and subnet structure are not documented.

### 4. `eks-d-setup/install.sh` vs `install-all.sh`
There are two files: `install.sh` (103 LOC) and `install-all.sh` (99 LOC). Their relationship is unclear — `install.sh` may be an older version or a different entry point.

### 5. Metrics Server installation details
`12-install-metrics-server.sh` (226 LOC) is the largest setup script but was not analyzed in detail. It may include custom configuration for EKS-D compatibility.

### 6. `ami-builder/scripts/build-with-version.sh`
This script allows building an AMI with a specific EKS-D version but was not analyzed in detail.

## Language Support Limitations

All code is Bash and HCL — both fully supported. No gaps from language support limitations.
