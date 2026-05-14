# Phase 1 — Foundation (assert pre-provisioned)

**Skill:** none (no manifests generated; this is an assertion-only phase)
**Ground truth:** the Accenture-provisioned EKS cluster
**Test gate:** `tests/test_phase_01_foundation.py`

---

## Goal

The KCD workshop cluster is pre-provisioned (Accenture-supplied EKS 1.32). Phase 1 confirms the foundation is healthy before we start deploying anything on top of it. No manifests are generated; this is a pytest-gate-only phase.

This corresponds to kubeauto-ai-day's Phase 1 (VPC, EKS, IAM, Pod Identity, Namespaces) which builds the cluster from scratch via Terraform. In our workshop context that infrastructure already exists, so the four kubeauto Phase 1 components are scored as "infrastructure existed and was Healthy" rather than "AI generated Terraform that worked."

## The prompt I paste to Claude

```
Phase 1 — Foundation. The cluster is pre-provisioned; no manifests to generate.

Walk me through what's already in place and run the gate:

  1. kubectl get nodes -o wide  (expect 3 Ready nodes, K8s 1.32.13-eks)
  2. kubectl get ns | grep -E 'argocd|apps|kyverno|monitoring|backstage|security|platform|cert-manager|falco'
  3. kubectl -n kube-system get deploy metrics-server
     (workshop pre-installs metrics-server; confirms kubectl top works)
  4. kubectl top nodes
  5. aws eks describe-cluster --name <cluster> --query 'cluster.identity.oidc.issuer'
     (confirms IRSA/Pod-Identity backend is configured)

Then run: pytest tests/test_phase_01_foundation.py -v

When all tests pass, emit:
<promise>PHASE_1_DONE</promise>
```

## Namespace structure (9 namespaces created by `namespaces` Application)

| Namespace | Purpose |
|---|---|
| `argocd` | ArgoCD core + all child Applications metadata |
| `apps` | Workshop demo workloads — Kyverno enforces here |
| `kyverno` | Kyverno admission controller + policy reports |
| `monitoring` | Prometheus, Grafana, OTel, Loki, Tempo, Promtail |
| `backstage` | Backstage Pod + catalog/RBAC ConfigMaps |
| `security` | Falco DaemonSet, Falcosidekick, **FalcoTalon** |
| `platform` | External Secrets Operator |
| `cert-manager` | cert-manager operator + webhook + cainjector |
| `falco` | **Empty — exists solely so FalcoTalon's leader-election Lease has a home.** Chart hardcodes this namespace name; without it, Talon spams `namespaces "falco" not found` warnings on every reconciliation. Discovered during live validation on 2026-05-14. |

## Known failure modes

- **`kubectl get nodes` returns 401.** EKS Access Entry missing for the current AWS user. Pre-workshop preflight should have caught this; if surfaced here, swap to a spare cluster.
- **`metrics-server` not installed.** The workshop preflight installs it; if missing, install from the upstream URL and rerun. Documented in `PROJECT_STATE.md`.
- **Node count < 3.** Possible node scaling issue. Check ASG. Less than 3 nodes will tight-pack the workshop stack but it'll still fit (~10% utilization headroom).
- **`falco` namespace shown as empty when you `kubectl get pods -n falco`.** This is correct — it's a leader-election Lease holder, not a workload home. See namespace table above.

## What students see on their cluster

Same — their pre-provisioned cluster, three commands, green output. This phase scores high across the room because the infrastructure was vetted by Accenture before the doors opened.

## Score on the live scorecard

**Components covered:** VPC + Networking, EKS Cluster, IAM/Pod Identity, Namespace Structure (4 of 27)

For these four:
- **Install: 10/10** — infrastructure existed Healthy. No AI involvement, no scorecard variance.
- **Integration: not applicable** — assessed in later phases as components actually use IRSA, the namespace structure, etc.
- **Usability: not applicable** — assessed in later phases when students/operators interact with the underlying infrastructure.

Foundation is the "free 4 components." Real scorecard variance starts at Phase 2.
