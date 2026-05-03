# Project Notes

This repository holds the workshop materials and provisioning automation for **"The 90-Minute IDP"** at **KCD Texas 2026 (May 15, 2026)**. ~60 attendees, each with their own pre-provisioned EKS cluster. The workshop has a hard date — correctness and timely readiness matter more than refactoring.

## Layout

- `kcd-texas-lab-setup-guide.md` — engineer-facing provisioning guide (the canonical "how it all works" doc)
- `kcd-texas-provisioning-README.md` — cluster-provisioning detail (Terraform + EKS)
- `lab-requirements-may-2026-events.md` — lab requirements for May 2026 events
- `scripts/` — student IAM lifecycle scripts at the repo root: `create-permissions-boundary.sh`, `create-student-users.sh`, `delete-student-users.sh`
- `assets/` — Mermaid sources (`.mmd`) and rendered SVGs for the four core diagrams
- `kcd-texas-provisioning/` — cluster-provisioning sources: Terraform modules under `terraform/` (`main.tf`, `vpc.tf`, `eks.tf`, `variables.tf`, `outputs.tf`), batch provisioning/teardown scripts (`batch-provision.sh`, `batch-teardown.sh`, `post-provision-setup.sh`, `teardown.sh`), and `iam-policy-workshop-provisioner.json`. These are **different** scripts from those in the root `scripts/` directory — root `scripts/` handles student IAM, `kcd-texas-provisioning/` handles cluster creation.

## Branch Workflow

Default branch is `staging`. All work goes to `staging` first; promote to `main` only after verification.

## Architecture Notes

- Single AWS account, all students share it.
- Each student gets a temporary IAM user with a permissions boundary that allowlists EKS and supporting services. Everything else is blocked by omission — no explicit denies needed.
- One presenter cluster + 3 spares on top of the student count.
- Cluster spec: 3× t3.xlarge nodes, latest stable EKS, pre-created namespaces (`argocd`, `kyverno`, `monitoring`, `backstage`, `apps`, `sample-app`), and pre-pulled images for the workshop tools.
