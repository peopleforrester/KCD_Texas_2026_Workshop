# KCD Texas 2026 Workshop - Cluster Provisioning Guide

**Event:** KCD Texas 2026
**Date:** May 15, 2026
**Workshop:** "The 90-Minute IDP" (90-minute hands-on workshop, 2-hour lab window)
**Provisioning Lead:** Michael Forrester

---

## What This Package Does

This package provisions Amazon EKS (Elastic Kubernetes Service) clusters for a conference workshop. Each attendee gets their own isolated Kubernetes cluster. The workshop installs software onto these clusters live during the session.

You do not need to know Kubernetes to provision these clusters. The Terraform scripts handle everything. This guide walks through every step.

---

## What Gets Created Per Cluster

Each `terraform apply` creates:

| AWS Resource | Purpose | Cost (~) |
|---|---|---|
| 1 VPC | Network isolation | Free |
| 3 private subnets | Worker nodes | Free |
| 3 public subnets | Load balancers | Free |
| 1 NAT Gateway | Outbound internet for private subnets | $0.045/hr + data |
| 1 Elastic IP | NAT Gateway | $0.005/hr |
| 1 EKS Cluster | Kubernetes control plane | $0.10/hr |
| 3 t3.xlarge EC2 instances | Worker nodes (4 vCPU, 16 GB RAM each) | $0.22/hr each |
| IAM roles | Cluster and node permissions | Free |
| Security groups | Network access rules | Free |

**Total per cluster: ~$0.82/hr**

### Cost Estimates by Attendee Count

| Attendees | 2-hour window | 3-hour window (with buffer) |
|---|---|---|
| 20 | ~$33 | ~$49 |
| 30 | ~$49 | ~$74 |
| 50 | ~$82 | ~$123 |

**These clusters must be destroyed immediately after the workshop.**

---

## Prerequisites

Install the following on the machine that will run provisioning (your laptop or a CI runner):

### 1. AWS CLI v2

```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify
aws --version
# Should show aws-cli/2.x.x or later
```

### 2. Terraform

```bash
# macOS
brew install terraform

# Linux
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Verify
terraform --version
# Should show v1.5.0 or later
```

### 3. kubectl

```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Verify
kubectl version --client
```

### 4. Helm

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify
helm version
```

### 5. jq (used by teardown scripts)

```bash
# macOS
brew install jq

# Linux
sudo apt-get install -y jq
```

---

## IAM Setup

### Step 1: Create the Provisioner IAM Policy

1. Open the AWS Console and go to **IAM > Policies > Create Policy**
2. Click the **JSON** tab
3. Paste the contents of `iam-policy-workshop-provisioner.json` from this package
4. Name the policy: `kcd-texas-workshop-provisioner`
5. Add a description: "Least-privilege policy for provisioning KCD Texas 2026 workshop EKS clusters"
6. Click **Create Policy**

### Step 2: Attach the Policy

Attach the `kcd-texas-workshop-provisioner` policy to whichever IAM entity will run the Terraform:

- If using an **IAM user**: Go to the user > Permissions > Add permissions > Attach policy
- If using an **IAM role** (recommended for CI): Attach the policy to the role
- If using **SSO/Identity Center**: Add the policy to the relevant permission set

### Step 3: Configure AWS CLI

```bash
# If using IAM user credentials
aws configure
# Enter Access Key ID, Secret Access Key, region (us-east-2), output (json)

# If using SSO
aws sso login --profile your-profile-name

# Verify access
aws sts get-caller-identity
# Should show your account ID and IAM entity
```

---

## Provisioning a Single Cluster (Test First)

Before batch provisioning, test with one cluster.

### Step 1: Initialize Terraform

```bash
cd terraform/
terraform init
```

This downloads the required AWS provider and modules. You only need to run this once.

### Step 2: Preview What Will Be Created

```bash
terraform plan -var="cluster_name=kcd-texas-test-01" -var="region=us-east-2"
```

Review the output. It should show ~30-40 resources to create. No resources should be destroyed.

### Step 3: Create the Cluster

```bash
terraform apply -var="cluster_name=kcd-texas-test-01" -var="region=us-east-2"
```

Type `yes` when prompted. This takes approximately **12-18 minutes**. The EKS cluster creation itself is the slowest part (~10 minutes).

### Step 4: Run Post-Provision Setup

```bash
cd ..
chmod +x post-provision-setup.sh
./post-provision-setup.sh kcd-texas-test-01 us-east-2
```

This script will:

1. Configure kubectl to talk to the new cluster
2. Verify all 3 nodes are healthy
3. Install Helm (if not already installed)
4. Create the workshop namespaces (argocd, kyverno, monitoring, backstage, apps, sample-app)
5. Pre-pull container images so the workshop runs faster
6. Print a summary with connection info

### Step 5: Verify

```bash
kubectl get nodes
# Should show 3 nodes in Ready state

kubectl get namespaces
# Should show the 6 workshop namespaces plus kube-system, default, etc.
```

### Step 6: Destroy the Test Cluster

```bash
chmod +x teardown.sh
./teardown.sh kcd-texas-test-01 us-east-2
```

---

## Batch Provisioning (Workshop Day)

### Timing

Provision clusters **the morning of the workshop** or **the evening before**. Each cluster costs ~$0.82/hr, so provisioning the night before a 30-cluster workshop adds ~$200 in overnight costs. Morning-of is cheaper but riskier if something fails.

Recommendation: Provision 2-3 hours before the workshop starts. The 12-18 minute per-cluster creation time runs in parallel via Terraform workspaces.

### Run Batch Provisioning

```bash
chmod +x batch-provision.sh
./batch-provision.sh 30 us-east-2
```

Replace `30` with the actual attendee count. Add 2-3 extra clusters as spares.

This will:

1. Create a Terraform workspace per attendee
2. Run `terraform apply` for each cluster
3. Run post-provision setup for each cluster
4. Generate a connection card (text file) per attendee in the `attendee-configs/` directory

### Distribute Connection Info

After provisioning completes, the `attendee-configs/` directory contains one file per attendee:

```
attendee-configs/
  kcd-texas-attendee-01-connection.txt
  kcd-texas-attendee-02-connection.txt
  ...
```

Each file contains the cluster name, region, endpoint, and the kubectl command to connect. Distribute these to attendees via printed cards, email, or a shared doc.

**Important:** Attendees need AWS CLI credentials configured to run `aws eks update-kubeconfig`. If attendees don't have their own AWS credentials, you'll need to provide temporary credentials or a pre-configured kubeconfig file. Talk to Michael Forrester about attendee access strategy before the event.

### Post-Workshop: Destroy Everything

```bash
chmod +x batch-teardown.sh
./batch-teardown.sh 30 us-east-2
```

**Do this immediately after the workshop ends.** Every hour the clusters run costs money.

---

## Troubleshooting

### Terraform init fails with "provider not found"

Your machine can't reach the Terraform registry. Check your internet connection and any corporate proxy settings.

### Terraform apply fails with "UnauthorizedOperation"

The IAM policy doesn't have sufficient permissions. Check that `iam-policy-workshop-provisioner.json` is attached to your IAM entity. Run `aws sts get-caller-identity` to verify you're using the right account.

### EKS cluster creation times out

EKS clusters take 10-15 minutes to create. If it times out, check the EKS console in your AWS account. The cluster may still be creating. Run `terraform apply` again and it will pick up where it left off.

### Nodes show NotReady

Wait 2-3 minutes after cluster creation. Nodes need time to join and become Ready. If nodes stay NotReady for more than 5 minutes, check the EC2 console for the node instances and verify their security group allows communication with the EKS control plane.

### Terraform destroy fails with "DependencyViolation"

Kubernetes LoadBalancer services create AWS ELBs outside of Terraform's knowledge. The teardown script handles this by deleting LoadBalancer services first, but if it fails, manually check for orphaned ELBs in the EC2 > Load Balancers console and delete them before re-running destroy.

### "You have exceeded the maximum number of VPCs" error

Default AWS account limit is 5 VPCs per region. For batch provisioning 30+ clusters, you need a service limit increase. Submit an AWS support ticket for "VPC > VPCs per Region" at least 1 week before the workshop. Request the number of attendees + 5 spare. Also request increases for:

- Elastic IPs per region (1 per cluster)
- NAT Gateways per AZ (1 per cluster)
- EC2 running instances (3 per cluster, t3.xlarge)
- EKS clusters per region (default is 100, probably fine)

---

## Service Limit Increases Required

**Submit these at least 1 week before the workshop.** Go to AWS Console > Service Quotas.

| Service | Quota | Default | Needed (30 attendees) | Needed (50 attendees) |
|---|---|---|---|---|
| VPC | VPCs per region | 5 | 35 | 55 |
| EC2 | Running On-Demand Standard instances (vCPUs) | 64 | 360 (3 nodes x 4 vCPU x 30) | 600 |
| VPC | Elastic IPs per region | 5 | 35 | 55 |
| VPC | NAT Gateways per AZ | 5 | 35 | 55 |
| EKS | Clusters per region | 100 | 35 | 55 |

---

## File Inventory

```
kcd-texas-provisioning/
  README.md                             ← This file
  iam-policy-workshop-provisioner.json  ← IAM policy (least-privilege)
  post-provision-setup.sh               ← Runs after each cluster is created
  teardown.sh                           ← Destroys a single cluster
  batch-provision.sh                    ← Creates N clusters for N attendees
  batch-teardown.sh                     ← Destroys all attendee clusters
  terraform/
    main.tf                             ← Provider config
    variables.tf                        ← Configurable parameters
    vpc.tf                              ← VPC, subnets, NAT gateway
    eks.tf                              ← EKS cluster and node group
    outputs.tf                          ← Connection info outputs
```

---

## Contact

Questions about this package: Michael Forrester
Questions about the workshop content: Michael Forrester
Questions about cost approval: Route through your project lead

**The single most important thing:** Destroy the clusters after the workshop.
