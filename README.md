# KCD Texas 2026 — Workshop Lab

Workshop materials and provisioning automation for **"The 90-Minute IDP"** at KCD Texas 2026 (May 15, 2026).

Each of ~60 attendees gets their own pre-provisioned Amazon EKS cluster. Attendees build an Internal Developer Platform (ArgoCD, Kyverno, Prometheus, Grafana, Backstage) on top during a 90-minute session inside a 2-hour lab window. Attendees have full admin inside their cluster; an IAM permissions boundary keeps them inside EKS-related AWS services at the account level.

## Documents

| File | Purpose |
|---|---|
| [`kcd-texas-student-playbook.md`](kcd-texas-student-playbook.md) | Student-facing 90-minute walkthrough — what to paste into Claude Code, how to verify each phase, and the per-phase scorecard slot |
| [`scorecard/SCORECARD-TEMPLATE.md`](scorecard/SCORECARD-TEMPLATE.md) | Blank scorecard each student fills in during the workshop (4-row phase table + wrap-up reflection). Submission is opt-in. |
| [`gitops/`](gitops/) | The GitOps source for the workshop. ArgoCD on every student cluster points at this directory; child Applications under `gitops/apps/` install Kyverno, Prometheus + Grafana, and Backstage. |
| [`kcd-texas-lab-setup-guide.md`](kcd-texas-lab-setup-guide.md) | Engineer-facing setup guide — how the labs are provisioned end-to-end |
| [`kcd-texas-provisioning-README.md`](kcd-texas-provisioning-README.md) | Detailed cluster-provisioning guide (Terraform + EKS, cost breakdown) |
| [`lab-requirements-may-2026-events.md`](lab-requirements-may-2026-events.md) | Lab requirements for the May 2026 events |
| [`assets/`](assets/) | Mermaid sources and rendered SVG diagrams (access model, cluster topology, day-of workflow, teardown checklist) |
| [`scripts/`](scripts/) | Shell scripts for the IAM permissions boundary and student-user lifecycle |
| [`kcd-texas-provisioning/`](kcd-texas-provisioning/) | Terraform modules and provisioning scripts that create the per-attendee EKS clusters |

## Repo Layout

```
.
├── assets/                                # Diagrams (.mmd sources + .svg renders)
├── gitops/                                # GitOps source: ArgoCD on each cluster watches this tree
│   ├── bootstrap/
│   │   └── app-of-apps.yaml               # Root Application that watches gitops/apps/
│   ├── apps/                              # Child Applications: Kyverno, Prom, Backstage, etc.
│   └── manifests/                         # Custom resources (Kyverno policies, etc.)
├── scorecard/                             # Workshop scorecard template
│   └── SCORECARD-TEMPLATE.md
├── scripts/                               # Student IAM provisioning scripts
├── kcd-texas-provisioning/                # Terraform + provisioning scripts
│   ├── terraform/                         # main.tf, vpc.tf, eks.tf, variables.tf, outputs.tf
│   ├── batch-provision.sh
│   ├── batch-teardown.sh
│   ├── post-provision-setup.sh
│   ├── teardown.sh
│   └── iam-policy-workshop-provisioner.json
├── kcd-texas-lab-setup-guide.md           # Engineer-facing setup guide
├── kcd-texas-provisioning-README.md       # Cluster provisioning detail
└── lab-requirements-may-2026-events.md
```

## Workflow

Working branch is `staging`. Changes land on `staging` first; promote to `main` only after verification.

```bash
git checkout staging
git pull origin staging
# ... make changes ...
git push origin staging
```

## Contact

Michael Forrester — provisioning lead.
