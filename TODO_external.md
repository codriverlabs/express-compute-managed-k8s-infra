# TODO — AMI Setup Script Fixes

Findings from live cluster inspection on 2026-06-01 (tenant `karolpiatek`, instance `i-05a94caaca89dd201`).

---

## 1. EBS CSI Controller — CrashLoopBackOff

**Root cause:** The EBS CSI controller pod cannot reach IMDS (`169.254.169.254`) from inside its network namespace. It falls back to the Kubernetes API (`10.96.0.1:443`) which also times out. Without instance metadata it cannot determine the AWS region and crashes.

**Fix in `13-install-ebs-csi.sh`:** Pass `AWS_REGION` explicitly via Helm so the controller skips IMDS lookup:

```bash
helm upgrade --install aws-ebs-csi-driver "$CHART" \
  --namespace kube-system \
  --set controller.serviceAccount.create=true \
  --set controller.k8sTagClusterId="$CLUSTER_NAME" \
  --set controller.replicaCount=1 \
  --set controller.extraEnv[0].name=AWS_REGION \
  --set controller.extraEnv[0].value="$AWS_REGION" \
  --set node.tolerateAllTaints=true \
  --wait
```

---

## 2. CloudWatch Agent — CrashLoopBackOff

Two separate issues:

### 2a. Kubelet TLS — missing IP SAN

**Root cause:** The kubelet serving certificate does not include the node's private IP as a SAN. The CloudWatch agent connects to `https://<node-ip>:10250/pods` and TLS verification fails:

```
x509: cannot validate certificate for 10.0.x.x because it doesn't contain any IP SANs
```

**Fix in `07-install-eks-d.sh`:** Enable `serverTLSBootstrap` in the kubeadm KubeletConfiguration so kubelet auto-provisions a certificate with correct SANs:

```yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
serverTLSBootstrap: true
rotateCertificates: true
```

### 2b. `aws-auth` ConfigMap not found

**Root cause:** The CloudWatch agent's EKS detection looks for `kube-system/aws-auth`, which doesn't exist on EKS-D. Non-fatal warning but may cause crash depending on chart version.

**Fix in `16-install-cloudwatch.sh`:** Verify `kubelet_https_verify: false` is correctly scoped in the JSON config for the installed chart version. Check if the chart supports a `clusterType=ec2` flag to skip EKS-specific checks.

---

## 3. Verification After Fix

```bash
# EBS CSI
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver
kubectl logs -n kube-system -l app=ebs-csi-controller --tail=10

# CloudWatch
kubectl get pods -n amazon-cloudwatch
kubectl logs -n amazon-cloudwatch -l app.kubernetes.io/name=cloudwatch-agent --tail=10

# Test EBS volume provisioning
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: gp3
  resources:
    requests:
      storage: 1Gi
EOF
kubectl get pvc test-pvc
```
