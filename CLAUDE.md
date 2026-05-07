# Project Notes

This repository holds the workshop materials and provisioning automation for **"The 90-Minute IDP"** at **KCD Texas 2026 (May 15, 2026)**. ~60 attendees, each with their own pre-provisioned EKS cluster. The workshop has a hard date — correctness and timely readiness matter more than refactoring.

## Layout

- `kcd-texas-student-playbook.md` — student-facing 90-minute walkthrough (4 phases, prompts, verification commands, scorecard). Modeled on `kubeauto-ai-day/spec/BUILD-SPEC.md` but condensed for workshop pacing per `assets/kubeauto-reference-analysis.md`. Prompts say "current stable GA chart" rather than pinning chart versions — Helm resolves on workshop day. Two corrections that were *not* version drift: the ArgoCD reconciliation timeout lives at `configs.cm."timeout.reconciliation"` (not `configs.params`), and the Backstage Helm chart has no `appVersion` — image tag is set in `backstage.image.tag` (the kubeauto reference's "Backstage 1.9.1" was a bogus number, fix-forward).
- `kcd-texas-lab-setup-guide.md` — engineer-facing provisioning guide (the canonical "how it all works" doc)
- `kcd-texas-provisioning-README.md` — cluster-provisioning detail (Terraform + EKS)
- `lab-requirements-may-2026-events.md` — lab requirements for May 2026 events
- `scripts/` — student IAM lifecycle scripts at the repo root: `create-permissions-boundary.sh`, `create-student-users.sh`, `delete-student-users.sh`
- `assets/` — Mermaid sources (`.mmd`) and rendered SVGs for the four core diagrams
- `scorecard/SCORECARD-TEMPLATE.md` — blank student scorecard. Per-phase columns (AI time, corrections, toil reduced, integration, tour/DIY, notes) match the playbook's per-phase scorecard slot 1:1. Wrap-up reflection covers manual-time estimate, toil-shifted question, **usability rating** (added per May 7 review — captures whether the platform is shippable, not just installed), where AI helped/struggled, and a takeaway. Opt-in submission to `scorecard.md` in each student's workshop repo.
- `scorecard/PRESENTER-SCORECARD.md` — live on-stage scorecard for the presenter. **Three** dimensions per row (Install, Integration, Usability), broken into six rows across the four phases. The audience watches this fill in real time on the projector while filling in their own student scorecard alongside. Includes a kubeauto baseline for comparison and a "closing storyline" prompt for the talk's payoff. Source-of-truth artifact for follow-on talks comparing workshop vs. overnight-build conditions.
- `gitops/` — the GitOps source ArgoCD watches on each student cluster.
  - `gitops/bootstrap/app-of-apps.yaml` — root Application; students `kubectl apply` this in Phase 1 after Helm-installing ArgoCD. It points at `gitops/apps/` in this repo on `main`, so all 60 student clusters share the same canonical manifests.
  - `gitops/apps/` — four child Applications (Kyverno, kyverno-policies, kube-prometheus-stack, Backstage), each with sync-wave annotations matching the kubeauto reference build's ordering.
  - `gitops/manifests/kyverno-policies/` — three ClusterPolicy YAMLs (require-labels, require-resource-limits, disallow-privileged), all enforced on the `apps` namespace only.
  - **Workshop model:** Students do not push to git during the workshop. They clone this repo read-only, then Claude Code walks them through the pre-committed manifests and verifies each component installed correctly.
  - **Repo visibility:** the workshop repo must be readable by each ArgoCD instance. If left private, post-provision-setup needs to seed each ArgoCD with a read-only credential; if made public, no credentials are needed.
- `kcd-texas-provisioning/` — cluster-provisioning sources: Terraform modules under `terraform/` (`main.tf`, `vpc.tf`, `eks.tf`, `variables.tf`, `outputs.tf`), batch provisioning/teardown scripts (`batch-provision.sh`, `batch-teardown.sh`, `post-provision-setup.sh`, `teardown.sh`), and `iam-policy-workshop-provisioner.json`. These are **different** scripts from those in the root `scripts/` directory — root `scripts/` handles student IAM, `kcd-texas-provisioning/` handles cluster creation.

## Branch Workflow

Default branch is `staging`. All work goes to `staging` first; promote to `main` only after verification.

## Architecture Notes

- Single AWS account, all students share it.
- Each student gets a temporary IAM user with a permissions boundary that allowlists EKS and supporting services. Everything else is blocked by omission — no explicit denies needed.
- One presenter cluster + 3 spares on top of the student count.
- Cluster spec: 3× t3.xlarge nodes, latest stable EKS, pre-created namespaces (`argocd`, `kyverno`, `monitoring`, `backstage`, `apps`, `sample-app`), and pre-pulled images for the workshop tools.
