# TODO

## Karpenter EC2NodeClass — DescribeCluster CIDR Bug

### Problem
Karpenter v1.10 always calls `eks:DescribeCluster` to detect the service CIDR when
`amiFamily: AL2023` is used, regardless of `eksControlPlane=false`. On EKS-D there
is no EKS cluster, so this call returns 404 and the EC2NodeClass stays `NotReady`.

Root cause: `pkg/providers/launchtemplate/launchtemplate.go::ResolveClusterCIDR()`
only skips the call if `ClusterCIDR` is already populated. There is no way to
pre-seed it via Helm values in v1.10. Not fixed in v1.11.1 either.

### Workaround (to implement)
Use `amiFamily: Custom` instead of `AL2023`. The `Custom` family skips the CIDR
detection code path entirely. The nodeadm MIME multipart userdata in the EC2NodeClass
already handles all AL2023 bootstrap (cluster join, kubelet config), so `Custom`
is functionally equivalent.

**Plan:**
1. Change `amiFamily: AL2023` → `amiFamily: Custom` in `node-pools/chart/templates/ec2nodeclass.yaml`
   (already done in last commit, needs testing)
2. Verify EC2NodeClass becomes `Ready`
3. Deploy test workload to trigger Karpenter node provisioning
4. Verify worker node joins cluster and authenticates via aws-iam-authenticator

### Instance Resize
Change `instance_type` in `terraform/terraform.tfvars` from `m6g.large` (2 vCPU)
to `c6g.xlarge` (4 vCPU, cheaper than m6g.xlarge) before next full reinstall.
