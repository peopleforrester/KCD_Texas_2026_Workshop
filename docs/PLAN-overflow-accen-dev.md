# Overflow plan — provision 40-60 additional clusters in `accen-dev` (account &lt;ACCT_PRESENTER&gt;)

**Status:** held — not executing unless triggered.
**Audience:** future Michael, future Claude, future operator.
**Authored:** 2026-05-15 during workshop day, on top of the 60-cluster baseline already live in the Accenture account (&lt;ACCT_ACCENTURE&gt;).

---

## Trigger

Use this plan when:

- Registration outpaces the 60-cluster Accenture baseline (>60 attendees register, or a follow-on event needs a fresh batch), **and**
- You want the additional capacity in an account *you control directly* (rather than asking Accenture to provision more in their account), **and**
- You're authenticated as `nwuser` via the `accen-dev` AWS CLI profile (account `&lt;ACCT_PRESENTER&gt;`).

## Account state (probed 2026-05-15, read-only)

The account is a near-greenfield. Nothing workshop-related lives there yet.

| Resource | State |
|---|---|
| **Identity** | `arn:aws:iam::&lt;ACCT_PRESENTER&gt;:user/nwuser` — admin |
| **Existing EKS clusters** | 0 across all probed regions (us-east-1, us-east-2, us-west-1, us-west-2, eu-west-1, eu-central-1, ap-southeast-1, ap-northeast-1) |
| **Existing IAM users** | 2 only: `aws-nuke` (cleanup tooling) and `nwuser`. **Zero conflicts with `kcd-tx-attendee-*` naming.** |
| **Existing IAM customer-managed policies** | 0 — `kcd-tx-attendee-boundary` does NOT exist. Has to be created by `scripts/create-permissions-boundary.sh` before any user creation. |
| **Existing VPCs in us-east-2** | 0 — including no default VPC. We start from nothing. |

## Service quotas (us-east-2, probed 2026-05-15)

All adjustable. Current values are AWS defaults except where noted.

| Quota | Code | Default value | Workshop need (40 clusters) | Workshop need (60 clusters) | Status |
|---|---|---|---|---|---|
| **EKS Clusters per region** | `eks/L-1194D53C` | **100** | 40 | 60 | ✅ fits both |
| **VPCs per region** | `vpc/L-F678F1CE` | **5** | 1 (shared) | 1 (shared) | ✅ with shared-VPC pattern (forced) |
| **NAT gateways per AZ** | `vpc/L-FE5A380F` | **5** | 1 shared | 1 shared | ✅ |
| **Internet gateways per region** | `vpc/L-A4707A72` | **5** | 1 | 1 | ✅ |
| **EC2-VPC Elastic IPs** | `ec2/L-0263D0A3` | **5** | 1 (NAT) | 1 (NAT) | ✅ |
| **Running On-Demand Standard vCPUs** | `ec2/L-1216C47A` | **512** | 480 (40 × 3 × 4) | 720 (60 × 3 × 4) | ✅ for 40 / ❌ for 60 |

**The vCPU quota is the only real blocker.** It dictates the practical ceiling:

- **40 clusters fits comfortably** within the default 512 vCPU quota (uses 480, leaves 32 vCPU headroom for the AWS provider's transient operations, system pods, etc.).
- **60 clusters does NOT fit** — needs a vCPU quota increase request to ~1000+ vCPUs before provisioning starts. AWS typically grants these within hours to a day for moderate increases.

## Naming + numbering decision

Michael said "attendee 61-100" *and* "new 60 clusters" — those don't match arithmetically. Two interpretations:

1. **40 clusters numbered `kcd-tx-attendee-61` through `kcd-tx-attendee-100`** — extends the Accenture-fleet namespace cleanly, single contiguous pool of `01..100`. Fits the default vCPU quota. **Recommended interpretation.**
2. **60 clusters numbered `kcd-tx-attendee-61` through `kcd-tx-attendee-120`** — needs vCPU quota increase first. Same naming scheme.

Either way the cluster naming convention stays `kcd-tx-attendee-NN`. The IAM user names match. The pool.csv rows append to the same single file the kcd-website seeds from. From the attendee's perspective the experience is identical to the Accenture-provisioned ones.

## Shared-VPC architecture (mandatory for accen-dev)

The existing Terraform in `kcd-texas-provisioning/terraform/` creates a VPC per cluster (via `module.vpc` in `vpc.tf`). On accen-dev with VPC quota of 5, that pattern dies at cluster #6.

**Required refactor before any provisioning in this account:**

1. Split `terraform/` into two modules:
   - `terraform/network/` — one VPC (e.g., `10.20.0.0/16`), three AZs, public + private subnets, one NAT, one EIP, security groups. Outputs `vpc_id`, public/private subnet ID lists.
   - `terraform/cluster/` — takes `vpc_id` + subnet IDs as input variables. Only creates the EKS cluster + node group. Re-runs cleanly per cluster via Terraform workspaces.

2. New top-level `main.tf` wires them. `batch-provision.sh` runs `network/` once, then loops `cluster/` for each attendee.

3. Estimated refactor effort: 30-60 minutes of focused work + a 1-cluster test (15-20 min wall time) before any batch run.

The refactor is **non-destructive** to the current `kcd-texas-provisioning/terraform/` — it can live in a sibling directory like `kcd-texas-provisioning/terraform-shared-vpc/` to leave the Accenture-tested code path intact.

## Pre-flight checklist (before any provisioning)

```
□ AWS_PROFILE=accen-dev aws sts get-caller-identity returns &lt;ACCT_PRESENTER&gt;/nwuser
□ Re-verify EKS Clusters quota: still 100, still adjustable
□ Re-verify vCPU quota:
    - if going for 40 clusters: must be ≥ 512  (default — likely OK)
    - if going for 60 clusters: file increase request to ≥ 1000
□ Shared-VPC Terraform refactor exists in kcd-texas-provisioning/terraform-shared-vpc/
□ Refactor has been tested against 1 cluster end-to-end (provision → verify → teardown)
□ scripts/create-permissions-boundary.sh ran successfully against accen-dev (creates
  kcd-tx-attendee-boundary in the new account)
□ scripts/batch-provision.sh patched to support START_INDEX argument (so the loop
  runs 61..N instead of 1..N — needed to align numbering with the existing Accenture
  fleet)
□ scripts/create-attendee-users.sh same patch
□ Pool.csv merge strategy decided:
    Option A: append accen-dev rows to the existing kcd-website/pool.csv,
              redeploy kcd-website (single registration UI, two underlying accounts)
    Option B: separate kcd-website instance for the accen-dev pool
              (cleaner isolation, two URLs to QR-code)
□ Teardown plan documented (which scripts to run after the workshop to clean accen-dev
  back to greenfield, since this is "your account" not Accenture's)
```

## Execution sequence (if all pre-flight ✓)

1. **Network module apply** (1 VPC, 1 NAT, 1 IGW, 1 EIP) — `terraform apply` in `terraform-shared-vpc/network/`. ~5 minutes.

2. **Permissions boundary** — `AWS_PROFILE=accen-dev bash scripts/create-permissions-boundary.sh`. Idempotent. <1 minute.

3. **Cluster provisioning** — `AWS_PROFILE=accen-dev bash kcd-texas-provisioning/batch-provision.sh 40 us-east-2 61` (40 clusters, starting at index 61). With parallel execution (`xargs -P 10`), ~40 minutes for 40 clusters.

   Sequential fallback if parallel fails: ~10 hours for 40 clusters. Don't use sequential for an emergency.

4. **IAM users** — `AWS_PROFILE=accen-dev bash scripts/create-attendee-users.sh 40 us-east-2 61`. Creates user, attaches boundary, attaches kubeconfig+EKS-on-own-cluster policy, creates access key, creates EKS Access Entry on the matching cluster with `AmazonEKSClusterAdminPolicy`, writes per-user connection card. ~3 minutes.

5. **Pool.csv aggregation** — concatenate the 40 per-attendee connection cards into a CSV. Append to `../kcd-website/pool.csv` (Option A) or write to a fresh CSV (Option B). 1 minute.

6. **Web app deploy** — push kcd-website (or restart Railway service after editing the volume's `/data/pool.db` to trigger re-seed). ~3 minutes.

7. **Sanity test** — pick one attendee's access keys from the new batch, run `aws eks update-kubeconfig --name kcd-tx-attendee-61 --region us-east-2 --profile <attendee-keys>` and `kubectl get nodes`. Verify 3 Ready. ~2 minutes.

**Total wall time go → live (assuming refactor + 1-cluster test already done):** ~55 minutes for 40 clusters, ~75 minutes for 60 (plus quota wait).

## Cost estimate

Per cluster on a shared-VPC pattern:
- EKS control plane: $0.10/hr
- 3× t3.xlarge nodes: $0.50/hr (3 × $0.1664)
- Shared NAT amortized: ~$0.001/hr per cluster (single NAT split 40 ways)
- Shared EIP amortized: ~$0.00 (covered by NAT EIP)
- **Per-cluster effective: ~$0.60/hr**

For 40 clusters × 3-hour workshop window: **~$72**.
For 60 clusters × 3-hour workshop window: **~$108**.

(Compare to per-cluster-VPC: ~$0.65/hr — about $0.05/hr/cluster savings from shared NAT, multiplied by N. For 40 clusters that's ~$6 for the 3-hour window. Not huge in absolute terms, but the bigger win is staying within the VPC quota without filing increases.)

## Risks (and how each fails-loud)

1. **vCPU quota of 512 if shooting for 60 clusters.** Cluster #43 or so will start failing because the node group's EC2 RunInstances calls get rejected. Fail mode: cluster CREATE_FAILED in Terraform output. **Mitigation:** file the vCPU increase BEFORE running batch-provision, or cap at 40.

2. **Terraform state pollution.** If the shared-VPC refactor is run by mistake against the original `terraform/` workspace (the per-cluster-VPC one), state files conflict. **Mitigation:** the refactor lives in a *separate directory* (`terraform-shared-vpc/`), never in the same one.

3. **Pool.csv contention with the live registration site.** If kcd-website is actively serving registrations on the Accenture pool and you append accen-dev rows mid-event, you need to (a) edit the file, (b) `rm /data/pool.db` on the Railway volume, (c) restart the service. The seed re-runs on empty DB. There's a 30-second registration gap during the restart. **Mitigation:** plan the deploy during a low-traffic window — ideally before the doors open.

4. **AWS-nuke is already installed in this account.** The IAM user `aws-nuke` exists. If anyone fires aws-nuke against this account post-workshop, it cleans **everything**, including the shared VPC if not protected by tag filters. **Mitigation:** add `Project=kcd-texas-2026-workshop` tags on all resources (already in the existing Terraform's default tags) and verify aws-nuke's config excludes that tag.

5. **Cross-account pool.csv with one kcd-website.** If using Option A (single CSV, both accounts) and an attendee gets credentials for an accen-dev cluster, their `aws eks update-kubeconfig` works the same way — but the AWS keys point at account &lt;ACCT_PRESENTER&gt;, not &lt;ACCT_ACCENTURE&gt;. From the attendee's perspective this is invisible. From the operator's perspective the cluster they're looking at is in a different console. **Mitigation:** none needed for the attendee; just be aware as an operator.

6. **Cluster `kcd-tx-attendee-61` and `-62` already have IAM users in the Accenture account.** Those users have no clusters there. If you provision `kcd-tx-attendee-61` in accen-dev, the user `kcd-tx-attendee-61` exists in *both* accounts — same name, different ARNs. The Access Entry on the new cluster points to the accen-dev user (different ARN), so no collision in practice. **Mitigation:** flag in the runbook so the operator doesn't get confused by `aws iam get-user --user-name kcd-tx-attendee-61` returning different results depending on which profile.

## Teardown after the workshop

```bash
# Accen-dev cleanup (your responsibility, not Accenture's)
AWS_PROFILE=accen-dev bash kcd-texas-provisioning/batch-teardown.sh 40 us-east-2 61
AWS_PROFILE=accen-dev bash scripts/delete-attendee-users.sh 40 us-east-2 61
# Then destroy the shared VPC:
cd kcd-texas-provisioning/terraform-shared-vpc/network && terraform destroy
# Optional: delete the permissions boundary policy if you want a fully clean slate.
```

Verify after teardown:

```bash
AWS_PROFILE=accen-dev aws eks list-clusters --region us-east-2  # → []
AWS_PROFILE=accen-dev aws ec2 describe-vpcs --region us-east-2  # → []
AWS_PROFILE=accen-dev aws iam list-users  # → just aws-nuke + nwuser
```

## When NOT to use this plan

- Attendance fits in 60 clusters → don't provision overflow.
- Late-add of 1-2 people → wire up the existing unused Accenture IAM users `kcd-tx-attendee-61` and `-62` instead. They already exist, have keys, just need Access Entries.
- Different region → redesign. This plan assumes us-east-2 throughout.

## One-line summary

> *If overflow into `accen-dev` is needed: refactor Terraform for shared-VPC, file a vCPU increase if going past 40 clusters, then reuse the existing scripts with a START_INDEX patch. Account is greenfield; only blocker at scale is the 512 vCPU default quota.*
