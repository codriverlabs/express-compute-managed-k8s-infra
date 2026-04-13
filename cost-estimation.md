# ECP Single-Node EKS-D Cost Estimation

## Monthly Cost Breakdown (per team member)

### Control Plane (Always Running)
| Component | Instance Type | Hours/Month | On-Demand Price | With Savings Plan | Monthly Cost |
|-----------|---------------|-------------|-----------------|-------------------|--------------|
| Control Plane | t3.medium | 744 | $0.0416/hr | $0.0270/hr (35% off) | ~$20.09 |
| Control Plane | t3.large | 744 | $0.0832/hr | $0.0541/hr (35% off) | ~$40.25 |

### Storage (Always Running)
| Component | Size | Type | Monthly Cost |
|-----------|------|------|--------------|
| Root Volume | 50 GB | gp3 | ~$4.00 |
| etcd Volume | 20 GB | gp3 | ~$1.60 |
| **Total Storage** | | | **~$5.60** |

### Worker Nodes (Spot - Pay Only When Running)
| Workload | Instance Type | Spot Price | Hours Used | Monthly Cost |
|----------|---------------|------------|------------|--------------|
| Development | t3.medium | ~$0.0125/hr | 40 hrs | ~$0.50 |
| Testing | m5.large | ~$0.0288/hr | 80 hrs | ~$2.30 |
| Load Testing | c5.xlarge | ~$0.0510/hr | 20 hrs | ~$1.02 |

### Networking
| Component | Monthly Cost |
|-----------|--------------|
| NAT Gateway | ~$32.40 |
| Data Transfer | ~$2-5 |
| **Total Networking** | **~$35** |

## Total Monthly Cost Estimates

### Conservative Estimate (t3.medium control plane)
- **Control Plane**: $20.09
- **Storage**: $5.60
- **Networking**: $35.00
- **Worker Nodes**: $5-15 (depending on usage)
- **Total**: **$65-75/month per team member**

### Recommended Setup (t3.large control plane)
- **Control Plane**: $40.25
- **Storage**: $5.60
- **Networking**: $35.00
- **Worker Nodes**: $10-25 (moderate usage)
- **Total**: **$90-105/month per team member**

## Cost Optimization Strategies

### 1. Compute Savings Plans
```bash
# 1-year commitment examples
t3.medium: $0.0416 → $0.0270 (35% savings)
t3.large:  $0.0832 → $0.0541 (35% savings)
```

### 2. Spot Instance Savings
```bash
# Typical spot discounts
t3.medium: $0.0416 → $0.0125 (70% savings)
m5.large:  $0.0960 → $0.0288 (70% savings)
c5.xlarge: $0.1700 → $0.0510 (70% savings)
```

### 3. Shared Infrastructure
- **Shared NAT Gateway**: Split $32.40 across team members
- **Shared VPC**: Reduce networking costs per person
- **Resource Tagging**: Track individual usage

### 4. Auto-Scaling Configuration
```yaml
# Aggressive scale-down for cost savings
disruption:
  consolidateAfter: 30s    # Quick consolidation
  expireAfter: 2160h       # 90-day max lifetime

limits:
  cpu: 100                 # Limit max resources
  memory: 100Gi
```

## Team Cost Scenarios

### 5-Person Team
| Scenario | Individual Cost | Team Total | Shared Savings |
|----------|----------------|------------|----------------|
| Conservative | $65/month | $325/month | $160/month with shared VPC |
| Recommended | $90/month | $450/month | $275/month with shared VPC |

### 10-Person Team
| Scenario | Individual Cost | Team Total | Shared Savings |
|----------|----------------|------------|----------------|
| Conservative | $65/month | $650/month | $325/month with shared VPC |
| Recommended | $90/month | $900/month | $550/month with shared VPC |

## Comparison with Alternatives

## Comparison with Alternatives

### vs. Managed EKS
| Component | EKS-D (per cluster) | Managed EKS | Savings |
|-----------|-------------------|-------------|---------|
| Control Plane | $20-40/month | $73/month | $33-53/month |
| Worker Nodes | Same (Spot) | Same (Spot) | $0 |
| **Total Savings** | | | **45-70% on control plane** |

### Key Advantages Over Managed EKS
- **Cost**: 45-70% cheaper on control plane
- **Isolation**: Dedicated cluster per team member - no resource contention
- **Full Karpenter**: Complete Karpenter v1 integration with NodePools
- **No API Limits**: No EKS API server throttling
- **Complete Control**: Customize control plane, etcd, scheduler settings
- **Use Case 1 - CI/CD**: Instant isolated clusters per PR/branch for integration testing
- **Use Case 2 - Development**: Safe environment for CRD/operator development without affecting shared clusters

### When Managed EKS Makes Sense
- Need cross-team shared cluster
- Want AWS-managed upgrades
- Prefer less operational overhead

### When EKS-D Makes Sense
- Individual team environments needed
- Cost optimization priority
- Learning Kubernetes internals
- CI/CD pipeline testing
- CRD/operator development

### vs. Local Development
| Component | EKS-D | Local (Docker Desktop) | Trade-offs |
|-----------|-------|----------------------|------------|
| Cost | $65-90/month | $0 | Cloud integration vs. free |
| AWS Integration | Full | Limited | Native vs. simulated |
| Scalability | Unlimited | Limited by laptop | Real vs. constrained |

## Budget Planning

### Monthly Budget per Team Member
- **Minimum**: $65/month (basic development)
- **Recommended**: $90/month (full testing)
- **Maximum**: $150/month (heavy load testing)

### Annual Budget (10-person team)
- **Conservative**: $7,800/year
- **Recommended**: $10,800/year
- **With Shared Infrastructure**: $6,600/year

## Cost Monitoring

### CloudWatch Billing Alerts
```bash
# Set up billing alerts for each team member
aws cloudwatch put-metric-alarm \
  --alarm-name "EKS-D-Monthly-Cost-Alert" \
  --alarm-description "Alert when monthly cost exceeds $100" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --threshold 100 \
  --comparison-operator GreaterThanThreshold
```

### Cost Allocation Tags
```hcl
# In Terraform resources
tags = {
  Team        = "ECP"
  Owner       = var.team_member_name
  Environment = "development"
  Project     = "eks-d-cluster"
}
```

## Use Cases

### 1. Instant EKS Cluster for CI/CD
- Spin up isolated EKS-D clusters per PR/branch for integration testing
- Each developer gets dedicated test environment without waiting for shared cluster
- Parallel test execution - no queueing or resource contention
- Teardown when done - pay only for actual test runtime

### 2. EKS Development (CRD/Operator Development)
- Deploy and test cluster-wide resources (CRDs, webhooks, operators)
- No pollution of shared development clusters
- Safe experimentation with admission controllers, API servers
- Direct access to control plane for debugging etcd, scheduler, controller-manager

## ROI Analysis

### Development Velocity
- **Setup Time**: 2-3 hours vs. days for manual setup
- **Consistency**: Identical environments across team
- **AWS Integration**: Native vs. simulated locally

### Learning Value
- **Kubernetes Operations**: Real cluster management
- **AWS Services**: Hands-on experience with EC2, VPC, IAM
- **Cost Optimization**: Spot instances, Savings Plans

### Production Readiness
- **Skills Transfer**: Direct application to production
- **Architecture Patterns**: Scalable, cloud-native designs
- **Operational Experience**: Monitoring, troubleshooting, scaling
