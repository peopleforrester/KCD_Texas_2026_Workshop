# Security Policy

This repository contains the workshop materials and GitOps source for **"The 90-Minute IDP"** — the workshop shipped at KCD Texas 2026 on 2026-05-15. The live workshop infrastructure (60+ EKS clusters, attendee IAM users, distributed credentials) has been fully torn down. The repository is preserved as a public reference for the methodology, the spec, and the post-workshop scorecard.

## Reporting a vulnerability

If you find a security issue in the workshop's spec, GitOps manifests, scripts, Claude Code skill files, or anywhere else in this repository — including anything that could let a future replicator accidentally expose attendee credentials or compromise their cluster — please report it via **[GitHub private vulnerability reporting](https://github.com/peopleforrester/KCD_Texas_2026_Workshop/security/advisories/new)** rather than opening a public issue.

Responses are best-effort. This repository is maintained by a single person (Michael Forrester) in spare time between workshop runs. Expect a reply within ~5 business days.

## Scope

In scope:
- Anything under `spec/`, `gitops/`, `.claude/skills/`, `.claude/commands/`, `scripts/`, `kcd-texas-provisioning/`, or `tests/` that introduces a security regression
- Secrets that may have leaked into git history despite the gitleaks pre-commit hook
- Documentation that instructs users to perform an insecure action
- Kyverno policies, Falco rules, or RBAC manifests that don't enforce what their names imply

Out of scope (please report directly to the upstream project):
- The Railway-hosted credential distribution app (`../kcd-website/`) — sibling repository, separately maintained
- The reference build at [`github.com/peopleforrester/kubeauto-ai-day`](https://github.com/peopleforrester/kubeauto-ai-day)
- Issues in upstream charts (Kyverno, ArgoCD, cert-manager, Backstage, etc.) — report those to the relevant project

## What's already been hardened

- Pre-commit `gitleaks` scanning (`.pre-commit-config.yaml`)
- GitHub repository-side Dependabot alerts + Secret scanning
- AWS account IDs redacted from public docs (commit `9820d5d`)
- Kyverno `disallow-privileged` policy extended to cover `allowPrivilegeEscalation`, `hostNetwork`, `hostPID`, `hostIPC`, and dangerous capabilities (commit `9820d5d`)
- Falco "Unexpected Outbound Connection" rule fixed to filter on destination port rather than ephemeral source port (commit `9820d5d`)
- All workshop attendee access keys revoked post-event

## What's intentionally left alone

- The `demo-cluster-admin` ClusterRole in `gitops/manifests/rbac/cluster-roles.yaml` is a deliberate workshop counter-example demonstrating what **not** to do in production. It is not bound to any subject in the workshop's GitOps tree. Annotation explains the intent.
- The `gitops/apps/eso-resources` ArgoCD Application reports Degraded on EKS without IRSA wiring — this is the workshop's central scorecard variance point, not a regression.
- The `gitops/apps/cert-manager-issuers` ArgoCD Application reports Degraded on EKS without Route53 wiring — same pattern, intentional.
