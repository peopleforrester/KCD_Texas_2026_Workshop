# KCD Texas 2026 — Lab Setup Guide for Engineers

**Event:** KCD Texas 2026 — May 15, 2026
**Workshop:** "The 90-Minute IDP" (90 min session, 2-hour lab window)
**Registered Students:** ~60
**Contact:** Michael Forrester

---

## Summary

Each student gets their own pre-provisioned EKS cluster. Students use Claude Code (an AI coding tool) on their laptops to build a complete Internal Developer Platform on top of their cluster during the workshop — ArgoCD, Kyverno, Prometheus, Grafana, Backstage, the works. Students have full admin access inside their clusters. They should be able to do anything they want in Kubernetes.

AWS-side, students are restricted to only the services needed to operate their EKS cluster. An SCP on a Workshop OU allowlists EKS and supporting services. Everything else (ML, storage, serverless, etc.) is blocked by omission — no explicit denies needed.

**What you're building:**
- 63 EKS clusters (60 students + 3 spares), pre-provisioned and ready before students arrive
- 1 presenter cluster (for Michael)
- Temporary IAM users with access scoped via SCP to EKS-related services only
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
| **By April 24** | Create Workshop OU and attach SCP |
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

## 2. AWS Organizations and SCP Setup

### Create the Workshop OU

```
Organization Root
└── Workshop OU  ← SCP attached here
    └── (workshop account or accounts)
```

All student IAM users live in accounts under this OU. The SCP is the security boundary — it allowlists only the AWS services students need to operate their EKS clusters. Everything not on the list is denied by default.

### Service Control Policy

This is an **allowlist**. Only the services listed here are available to accounts in the Workshop OU. No explicit denies — anything not listed is automatically blocked.

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

### Alternative: Permissions Boundary (Single Account)

If you're running all students in one shared account instead of separate accounts per student, apply the same policy as an IAM **permissions boundary** instead of an SCP:

```bash
aws iam create-policy \
  --policy-name kcd-texas-student-boundary \
  --policy-document file://scp-policy.json

# Attach to each student user at creation time:
aws iam create-user \
  --user-name kcd-texas-student-NN \
  --permissions-boundary arn:aws:iam::ACCOUNT_ID:policy/kcd-texas-student-boundary
```

One managed policy, attached as a boundary to all student users. Same effect as the SCP.

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

Students can only do what both the SCP **and** their IAM policy allow. The SCP sets the outer boundary for the whole OU. The IAM policy scopes each student to their own cluster.

### Kubernetes Access: system:masters

Map each student's IAM user to `system:masters` in the cluster's `aws-auth` ConfigMap:

```yaml
mapUsers: |
  - userarn: arn:aws:iam::ACCOUNT_ID:user/kcd-texas-student-NN
    username: kcd-texas-student-NN
    groups:
      - system:masters
```

Full cluster admin. No Kubernetes-side restrictions. Students can create namespaces, install CRDs, modify RBAC, deploy anything — it's their cluster.

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

The post-provision script also pre-pulls the main container images onto all nodes so Helm installs during the workshop don't block on image downloads:

- ArgoCD (quay.io/argoproj/argocd)
- Kyverno (ghcr.io/kyverno/kyverno)
- Prometheus (quay.io/prometheus/prometheus)
- Grafana (docker.io/grafana/grafana)
- Backstage (backstage base image)

This reduces first-install time from minutes to seconds.

### Provisioning Steps

The provisioning package (`kcd-texas-provisioning-package.zip`) contains Terraform configs and scripts. See `kcd-texas-provisioning-README.md` for full details. The Terraform variables should already specify t3.xlarge — verify in `variables.tf`.

**Test first (1 cluster):**
```bash
cd terraform/
terraform init
terraform apply -var="cluster_name=kcd-texas-test-01" -var="region=us-east-2"
cd ..
./post-provision-setup.sh kcd-texas-test-01 us-east-2
kubectl get nodes   # 3 Ready nodes, t3.xlarge each
./teardown.sh kcd-texas-test-01 us-east-2
```

**Batch provision (64 clusters) — do this 2-3 hours before the workshop:**
```bash
./batch-provision.sh 64 us-east-2
```

Creates 64 clusters in parallel via Terraform workspaces, runs post-provision setup on each.

**Create student IAM users — after clusters are up:**
```bash
./create-student-iam-users.sh 64 us-east-2
```

For each student: creates IAM user, attaches scoped policy, creates access key, patches aws-auth ConfigMap with `system:masters`, writes connection card to `attendee-configs/`.

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

### Delete IAM Users

```bash
for i in $(seq -w 1 64); do
  USER="kcd-texas-student-$i"
  for KEY in $(aws iam list-access-keys --user-name $USER --query 'AccessKeyMetadata[*].AccessKeyId' --output text 2>/dev/null); do
    aws iam delete-access-key --user-name $USER --access-key-id $KEY
  done
  for POLICY in $(aws iam list-user-policies --user-name $USER --query 'PolicyNames[*]' --output text 2>/dev/null); do
    aws iam delete-user-policy --user-name $USER --policy-name $POLICY
  done
  aws iam delete-user --user-name $USER 2>/dev/null
done
```

### Clean Up OU

If using the multi-account model, close the student accounts and delete the Workshop OU. If using a single shared account, remove the permissions boundary policy after deleting all student users.

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
