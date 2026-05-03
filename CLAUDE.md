# Project Notes

This repository holds the workshop materials and provisioning automation for **"The 90-Minute IDP"** at **KCD Texas 2026 (May 15, 2026)**. ~60 attendees, each with their own pre-provisioned EKS cluster. The workshop has a hard date — correctness and timely readiness matter more than refactoring.

## Layout

- `kcd-texas-lab-setup-guide.md` — engineer-facing provisioning guide (the canonical "how it all works" doc)
- `kcd-texas-provisioning-README.md` — cluster-provisioning detail (Terraform + EKS)
- `lab-requirements-may-2026-events.md` — lab requirements for May 2026 events
- `scripts/` — shell scripts: IAM permissions boundary + student-user create/delete
- `assets/` — Mermaid sources (`.mmd`) and rendered SVGs for the four core diagrams
- `kcd-texas-provisioning-package.zip` — see "Quirks" below

## Quirks

- **The zip is not a duplicate.** `kcd-texas-provisioning-package.zip` contains 11 source files (5 Terraform files: `main.tf`, `vpc.tf`, `eks.tf`, `variables.tf`, `outputs.tf`; 4 shell scripts: `batch-provision.sh`, `batch-teardown.sh`, `post-provision-setup.sh`, `teardown.sh`; an IAM policy JSON; and an inner `README.md`). These files are **only** in the zip — they are not separately tracked in the repo tree. Editing them requires extracting, modifying, and re-zipping. This is a known smell; the long-term fix is to extract `kcd-texas-provisioning/` into the tree and treat the zip as a build artifact.
- The `scripts/` directory at the repo root contains *different* scripts (student IAM lifecycle: `create-permissions-boundary.sh`, `create-student-users.sh`, `delete-student-users.sh`) — not the same files as those inside the zip.

## Branch Workflow

Default branch is `staging`. All work goes to `staging` first; promote to `main` only after verification.

## Architecture Notes

- Single AWS account, all students share it.
- Each student gets a temporary IAM user with a permissions boundary that allowlists EKS and supporting services. Everything else is blocked by omission — no explicit denies needed.
- One presenter cluster + 3 spares on top of the student count.
- Cluster spec: 3× t3.xlarge nodes, latest stable EKS, pre-created namespaces (`argocd`, `kyverno`, `monitoring`, `backstage`, `apps`, `sample-app`), and pre-pulled images for the workshop tools.
