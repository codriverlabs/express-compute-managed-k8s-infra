# TODO

## AMI Builder

- [ ] Filter out non-essential images from CloudWatch Observability chart during pre-pull
      (skip `windows`, `nvidia`, `neuron`, `dcgm-exporter`, `kubekins-e2e`)
- [ ] Restart containerd after writing ECR `hosts.toml` credentials so they are picked up
      before image pulls begin
- [ ] Remove debug output from ECR credential wait loop (`STS attempt N: ...`)

## End-to-End Validation

- [ ] Deploy workstation with `./deploy.sh` and verify cluster comes up correctly
- [ ] Verify Karpenter provisions worker nodes
- [ ] Verify EBS CSI, VPC CNI, CoreDNS all healthy
- [ ] Build x86_64 AMI (`ARCH=x86_64 ./build.sh`) and validate

## Cost / Infra

- [ ] Verify ECR pull-through cache is actually used during image pulls
      (check CloudWatch metrics on ECR pull-through cache hits)
- [ ] Add Dependabot config for `.tool-versions` packer version bumps
