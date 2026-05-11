# KCD Texas 2026 — Lab Setup Guide for Engineers

**Event:** KCD Texas 2026 — May 15, 2026
**Workshop:** "The 90-Minute IDP" (90 min session, 2-hour lab window)
**Registered Students:** ~60
**Contact:** Michael Forrester

---

## Summary

Each student gets their own pre-provisioned EKS cluster. Students use Claude Code (an AI coding tool) on their laptops to build a complete Internal Developer Platform on top of their cluster during the workshop — ArgoCD, Kyverno, Prometheus, Grafana, Backstage, the works. Students have full admin access inside their clusters. They should be able to do anything they want in Kubernetes.

AWS-side, students are restricted to only the services needed to operate their EKS cluster. A **permissions boundary** attached to each student IAM user allowlists EKS and supporting services. Everything else (ML, storage, serverless, etc.) is blocked by omission — no explicit denies needed. All students share a single AWS account.

**What you're building:**
- 63 EKS clusters (60 students + 3 spares), pre-provisioned and ready before students arrive
- 1 presenter cluster (for Michael)
- Temporary IAM users with access scoped via permissions boundary to EKS-related services only
- Base cluster setup: namespaces created, images pre-pulled, ready for immediate use

**Cluster Spec (per student):**
- 3 nodes, t3.xlarge (4 vCPU, 16 GB RAM) each
- EKS latest stable
- Pre-created namespaces: `argocd`, `kyverno`, `monitoring`, `backstage`, `apps`, `sample-app`
- Pre-pulled images for ArgoCD, Kyverno, Prometheus, Grafana, Backstage

**Cost:** ~$0.60/hr per cluster × 64 clusters × 3 hours = **~$122**

---

## Timeline

| When | What |
|------|------|
| **By April 24** | Submit AWS service limit increases (takes up to 5 business days) |
| **By April 24** | Create permissions boundary policy (run `scripts/create-permissions-boundary.sh`) |
| **By May 1** | Test: provision 1 cluster, create 1 IAM user, verify student can connect with full admin |
| **By May 8** | Test: batch provision 3 clusters, validate student access end-to-end, destroy |
| **May 14 evening or May 15 morning** | Provision all 64 clusters + create IAM users |
| **May 15, 10:00 AM** | Validate all clusters, distribute connection cards |
| **May 15, 12:30 PM (or when Michael says go)** | Destroy everything |

---

## 1. AWS Service Limit Increases

Submit **now**. Go to AWS Console > Service Quotas. Request for **us-east-2**.

| Service | Quota | Default | Request |
|---------|-------|---------|---------|
| VPC | VPCs per region | 5 | 70 |
| EC2 | Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) vCPUs | 64 | 780 |
| VPC | Elastic IPs per region | 5 | 70 |
| VPC | NAT Gateways per Availability Zone | 5 | 70 |
| EKS | Clusters per region | 100 | 70 (default is fine) |

If any request is denied or delayed, escalate through AWS support. Without these limits, batch provisioning will fail partway through.

---

## 2. Permissions Boundary Setup

All 60 student IAM users live in a single shared AWS account. A **permissions boundary** (an IAM managed policy) is attached to every student user at creation time. It allowlists only the AWS services students need to operate their EKS clusters. Everything not on the list is denied by default.

### Create the Permissions Boundary

Run the script once:

```bash
./scripts/create-permissions-boundary.sh
```

This creates the `kcd-texas-student-boundary` managed policy with the following allowlist:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowEKSFullAccess",
            "Effect": "Allow",
            "Action": [
                "eks:DescribeCluster",
                "eks:ListClusters",
                "eks:ListNodegroups",
                "eks:DescribeNodegroup",
                "eks:AccessKubernetesApi",
                "eks:ListFargateProfiles",
                "eks:DescribeUpdate",
                "eks:ListUpdates",
                "eks:ListAddons",
                "eks:DescribeAddon"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowEC2Describe",
            "Effect": "Allow",
            "Action": [
                "ec2:Describe*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowEC2ForLoadBalancersAndSecurityGroups",
            "Effect": "Allow",
            "Action": [
                "ec2:CreateSecurityGroup",
                "ec2:DeleteSecurityGroup",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:AuthorizeSecurityGroupEgress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupEgress",
                "ec2:CreateTags",
                "ec2:DeleteTags"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowElasticLoadBalancing",
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowECRImagePull",
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchGetImage",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchCheckLayerAvailability"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowECRPublic",
            "Effect": "Allow",
            "Action": [
                "ecr-public:GetAuthorizationToken",
                "ecr-public:BatchCheckLayerAvailability",
                "ecr-public:GetRepositoryCatalogData",
                "ecr-public:GetRegistryCatalogData"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowSTS",
            "Effect": "Allow",
            "Action": [
                "sts:GetCallerIdentity",
                "sts:AssumeRole",
                "sts:GetServiceBearerToken"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowAutoScalingDescribe",
            "Effect": "Allow",
            "Action": [
                "autoscaling:Describe*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowCloudWatchReadOnly",
            "Effect": "Allow",
            "Action": [
                "cloudwatch:GetMetricData",
                "cloudwatch:ListMetrics",
                "cloudwatch:GetMetricStatistics",
                "logs:DescribeLogGroups",
                "logs:GetLogEvents",
                "logs:FilterLogEvents"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowIAMReadAndPassRole",
            "Effect": "Allow",
            "Action": [
                "iam:GetRole",
                "iam:ListRoles",
                "iam:PassRole",
                "iam:GetOpenIDConnectProvider"
            ],
            "Resource": "*"
        }
    ]
}
```

**What this allows:**
- **EKS:** Full read access to cluster info + Kubernetes API proxy (students need this for kubectl)
- **EC2:** Read-only describe (see nodes, instances) + security group and tag operations (Kubernetes LoadBalancer services and ingress controllers create these)
- **ELB:** Full access (Kubernetes Service type LoadBalancer and AWS Load Balancer Controller create ALBs/NLBs)
- **ECR:** Image pulls from private and public registries (Helm charts pull container images)
- **STS:** Authentication (how kubectl gets tokens for EKS)
- **Auto Scaling:** Read-only (see node group scaling)
- **CloudWatch:** Read-only metrics and logs (cluster logging, if enabled)
- **IAM:** Read roles + PassRole (needed for IRSA/pod identity if any components use it)

**What this blocks** (by omission — not listed, therefore denied):
- Launching EC2 instances (no GPU/ML abuse, no spinning up machines)
- Creating VPCs, subnets, NAT gateways (infrastructure is pre-provisioned)
- All ML/AI services (SageMaker, Bedrock, etc.)
- All storage services (S3, DynamoDB, RDS)
- All serverless (Lambda, Glue, Athena)
- CloudFormation
- IAM user/role/policy creation (no privilege escalation)
- Organizations, billing, account management

The boundary is a single managed policy, attached to all student users at creation time. The `create-student-users.sh` script handles this automatically.

---

## 3. Student Access

Each student gets a temporary IAM user with an access key pair. Students run `aws configure` on their laptops, then `aws eks update-kubeconfig` to connect kubectl. They get `system:masters` inside Kubernetes — full unrestricted cluster admin.

### Per-Student IAM Policy

The SCP (or boundary) is the ceiling. Each student also needs an IAM policy that grants them access to their specific cluster:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "EKSFullAccessOwnCluster",
            "Effect": "Allow",
            "Action": "eks:*",
            "Resource": "arn:aws:eks:us-east-2:ACCOUNT_ID:cluster/kcd-texas-student-NN"
        },
        {
            "Sid": "EKSList",
            "Effect": "Allow",
            "Action": "eks:ListClusters",
            "Resource": "*"
        },
        {
            "Sid": "SupportingServices",
            "Effect": "Allow",
            "Action": [
                "sts:GetCallerIdentity",
                "ec2:Describe*",
                "ecr:GetAuthorizationToken",
                "ecr:BatchGetImage",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchCheckLayerAvailability",
                "ecr-public:GetAuthorizationToken",
                "elasticloadbalancing:Describe*",
                "autoscaling:Describe*"
            ],
            "Resource": "*"
        }
    ]
}
```

Students can only do what both the **permissions boundary** and their IAM policy allow. The boundary sets the outer ceiling for every student user. The inline IAM policy scopes each student to their own cluster.

### Kubernetes Access: EKS Access Entries

Grant each student cluster-admin via the **EKS Access Entries API** (the modern, AWS-recommended path; we don't touch `aws-auth`). The Terraform sets `authentication_mode = "API"` on each cluster so Access Entries are the only auth mechanism. The provisioning script then runs two AWS API calls per student:

```bash
aws eks create-access-entry \
  --cluster-name kcd-texas-student-NN \
  --principal-arn arn:aws:iam::ACCOUNT_ID:user/kcd-texas-student-NN \
  --type STANDARD \
  --username kcd-texas-student-NN

aws eks associate-access-policy \
  --cluster-name kcd-texas-student-NN \
  --principal-arn arn:aws:iam::ACCOUNT_ID:user/kcd-texas-student-NN \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

`AmazonEKSClusterAdminPolicy` is the AWS-managed access policy that maps to `system:masters` in the cluster. Full cluster admin — students can create namespaces, install CRDs, modify RBAC, deploy anything. It's their cluster.

The API-based path is idempotent (DescribeAccessEntry → CreateAccessEntry), works without kubectl access from the provisioner laptop, and doesn't depend on patching a YAML-as-string field in a ConfigMap. `scripts/create-student-users.sh` runs these calls automatically for each student.

### Connection Card

Each student receives (printed or digital):

```
KCD Texas 2026 — Your Lab Cluster

Cluster:          kcd-texas-student-NN
Region:           us-east-2
AWS Access Key:   AKIAxxxxxxxxxxxx
AWS Secret Key:   xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

Commands:
  aws configure          (keys above, region: us-east-2, format: json)
  aws eks update-kubeconfig --name kcd-texas-student-NN --region us-east-2
  kubectl get nodes      (should show 3 Ready nodes)
```

---

## 4. Cluster Provisioning

Clusters are **pre-provisioned before students arrive**. Students walk in, connect, and start building immediately. No waiting for cluster creation.

### Base Cluster Spec

Based on the [kubeauto-ai-day](https://github.com/peopleforrester/kubeauto-ai-day) reference build:

| Setting | Value |
|---------|-------|
| EKS version | Latest stable |
| Region | us-east-2 |
| Node count | 3 |
| Instance type | t3.xlarge (4 vCPU, 16 GB RAM) or equivalent |
| Node AMI | Amazon Linux 2023 (EKS optimized) |
| VPC | 1 per cluster, 3 private subnets, 3 public subnets, 1 NAT gateway |

### Pre-Created Namespaces

The post-provision setup script creates these namespaces on each cluster:

| Namespace | Purpose |
|-----------|---------|
| `argocd` | GitOps delivery (ArgoCD) |
| `kyverno` | Policy enforcement (Kyverno) |
| `monitoring` | Observability (Prometheus, Grafana) |
| `backstage` | Developer portal (Backstage) |
| `apps` | Application deployments |
| `sample-app` | Demo workload |

### Pre-Pulled Container Images

The post-provision script deploys an `image-prepull` DaemonSet that pulls (then exits) the main workshop container images onto every node so Helm installs during the workshop don't block on image downloads. Tags are pinned to match what `gitops/apps/*.yaml` actually deploys — the two must move together:

| Component | Image tag pre-pulled | Tracks |
|---|---|---|
| ArgoCD | `quay.io/argoproj/argocd:v3.3.9` | Chart `argo-cd 9.5.x` (installed in Phase 1) |
| Kyverno admission controller | `ghcr.io/kyverno/kyverno:v1.18.0` | `gitops/apps/kyverno.yaml` (chart `3.8.0`) |
| Kyverno cleanup controller | `ghcr.io/kyverno/cleanup-controller:v1.18.0` | Same |
| Prometheus | `quay.io/prometheus/prometheus:v3.11.3` | `gitops/apps/kube-prometheus-stack.yaml` (chart `84.5.0`) |
| Grafana | `docker.io/grafana/grafana:12.3.0` | Same |
| Prometheus operator | `quay.io/prometheus-operator/prometheus-operator:v0.90.1` | Same |
| Backstage | `roadiehq/community-backstage-image:1.50.4` | `gitops/apps/backstage.yaml` (chart `2.7.0`) |

Alertmanager is disabled in `gitops/apps/kube-prometheus-stack.yaml` and not pre-pulled. `node-exporter` and `kube-state-metrics` (~50 MB each) are also not pre-pulled — they pull at install time and add ~30 seconds to Phase 3 on first run.

This reduces first-install time from minutes to seconds for the components that matter (ArgoCD ~700 MB, Backstage ~600 MB, Grafana ~400 MB).

### Provisioning Steps

The provisioning sources live under [`kcd-texas-provisioning/`](kcd-texas-provisioning/) — Terraform modules under `terraform/`, plus the batch scripts (`batch-provision.sh`, `batch-teardown.sh`, `post-provision-setup.sh`, `teardown.sh`) and the IAM policy JSON at the directory root. See `kcd-texas-provisioning-README.md` for full details. The Terraform variables specify `t3.xlarge` by default — verify in `kcd-texas-provisioning/terraform/variables.tf`.

**Test first (1 cluster):**
```bash
cd kcd-texas-provisioning/terraform
terraform init
terraform apply -var="cluster_name=kcd-texas-test-01" -var="region=us-east-2"
cd ..
./post-provision-setup.sh kcd-texas-test-01 us-east-2
kubectl get nodes   # 3 Ready nodes, t3.xlarge each
./teardown.sh kcd-texas-test-01 us-east-2
```

**Batch provision (64 clusters) — do this 2-3 hours before the workshop:**
```bash
cd kcd-texas-provisioning
./batch-provision.sh 64 us-east-2
```

Creates 64 clusters in parallel via Terraform workspaces, runs post-provision setup on each.

**Create student IAM users — after clusters are up:**
```bash
./scripts/create-student-users.sh 64 us-east-2
```

For each student: creates IAM user with permissions boundary, attaches cluster-scoped inline policy, creates access key, patches aws-auth ConfigMap with `system:masters`, writes connection card to `attendee-configs/`.

**Presenter cluster:**
```bash
terraform apply -var="cluster_name=kcd-texas-presenter" -var="region=us-east-2"
./post-provision-setup.sh kcd-texas-presenter us-east-2
```

---

## 5. Validation

Before the workshop starts, verify every cluster:

```bash
for i in $(seq -w 1 64); do
  CLUSTER="kcd-texas-student-$i"
  aws eks update-kubeconfig --name $CLUSTER --region us-east-2

  NODE_COUNT=$(kubectl get nodes --no-headers | grep -c Ready)
  NS_COUNT=$(kubectl get ns argocd kyverno monitoring backstage apps sample-app --no-headers 2>/dev/null | wc -l)

  if [ "$NODE_COUNT" -eq 3 ] && [ "$NS_COUNT" -eq 6 ]; then
    echo "$CLUSTER: OK"
  else
    echo "$CLUSTER: PROBLEM — nodes=$NODE_COUNT, namespaces=$NS_COUNT"
  fi
done
```

All 64 clusters should show 3 Ready nodes and 6 workshop namespaces.

---

## 6. Teardown

**Do this immediately after Michael gives the all-clear.** Every hour costs ~$38 (64 × ~$0.60).

### Destroy Clusters

```bash
./batch-teardown.sh 64 us-east-2
./teardown.sh kcd-texas-presenter us-east-2
```

### Delete IAM Users and Permissions Boundary

```bash
./scripts/delete-student-users.sh 64 --delete-boundary
```

Deletes all student access keys, inline policies, IAM users, and the permissions boundary policy in one pass.

### Verify Nothing Is Left Running

```bash
# No workshop clusters
aws eks list-clusters --region us-east-2 --query 'clusters[?starts_with(@, `kcd-texas`)]'

# No running instances
aws ec2 describe-instances --region us-east-2 \
  --filters "Name=tag:Name,Values=kcd-texas-*" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].InstanceId'

# No orphaned NAT Gateways
aws ec2 describe-nat-gateways --region us-east-2 --filter "Name=state,Values=available"

# No orphaned Elastic IPs
aws ec2 describe-addresses --region us-east-2 --query 'Addresses[?AssociationId==null]'

# No remaining IAM users
aws iam list-users --query 'Users[?starts_with(UserName, `kcd-texas-student`)].UserName' --output text
```

Every check should return empty. If anything is left, delete it manually.

---

## Cost Summary

| Item | Count | Rate | Duration | Cost |
|------|------:|-----:|---------:|-----:|
| Student clusters | 63 | ~$0.60/hr | 3 hrs | ~$113 |
| Presenter cluster | 1 | ~$0.60/hr | 3 hrs | ~$1.80 |
| Spare clusters | 3 | ~$0.60/hr | 3 hrs | ~$5.40 |
| Test provisioning (prep) | 1-3 | ~$0.60/hr | 1 hr | ~$1.80 |
| **Total** | | | | **~$122** |

If provisioning the night before, add ~$307 for 8 hours overnight (64 × $0.60 × 8).

Costs are approximate. t3.xlarge in us-east-2 is ~$0.166/hr per instance × 3 nodes = ~$0.50/hr plus EKS control plane at $0.10/hr.

---

## Contact

- **Infrastructure questions:** Michael Forrester
- **Workshop content:** Michael Forrester
- **Cost approval:** Route through your project lead
