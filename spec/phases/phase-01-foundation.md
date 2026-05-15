# Phase 1 — Foundation (assert pre-provisioned)

**Skill:** `.claude/skills/cluster-environments.md` (read this FIRST — Phase 1 starts with cluster-type detection)
**Ground truth:** the pre-provisioned cluster — either Accenture EKS or KodeKloud kubeadm
**Test gate:** `tests/test_phase_01_foundation.py` (passes on both cluster types)

---

## Goal

The KCD workshop cluster is pre-provisioned. Phase 1 confirms the foundation is healthy before we start deploying anything on top of it. **It also detects the cluster type** (Accenture EKS vs. KodeKloud kubeadm) and writes a marker file (`.cluster-type`) that the rest of the build reads to branch behavior in Phases 3 and 7.

This corresponds to kubeauto-ai-day's Phase 1 (VPC, EKS, IAM, Pod Identity, Namespaces) which builds the cluster from scratch via Terraform. In our workshop context that infrastructure already exists, so the four kubeauto Phase 1 components are scored as "infrastructure existed and was Healthy" rather than "AI generated Terraform that worked."

## Cluster type detection (always FIRST)

The workshop runs against two different environments. Read `.claude/skills/cluster-environments.md` before doing anything else, then detect:

```bash
CTX="$(kubectl config current-context 2>/dev/null)"
case "${CTX}" in
    kubernetes-admin@kubernetes)  CLUSTER_TYPE=kubeadm ;;
    *eks*|arn:aws:eks:*)          CLUSTER_TYPE=eks ;;
    *) echo "ERROR: unknown context '${CTX}'"; exit 1 ;;
esac
echo "${CLUSTER_TYPE}" > "${CLAUDE_PROJECT_DIR:-$(pwd)}/.cluster-type"
```

After this, every other phase reads `.cluster-type` to know which branch to follow.

## The prompt I paste to Claude

```
Phase 1 — Foundation. The cluster is pre-provisioned; no manifests to generate.

STEP 0 — CLUSTER TYPE DETECTION (do this before anything else):
  Read .claude/skills/cluster-environments.md.
  Run:
    CTX=$(kubectl config current-context)
    case "$CTX" in
      kubernetes-admin@kubernetes)  CLUSTER_TYPE=kubeadm ;;
      *eks*|arn:aws:eks:*)          CLUSTER_TYPE=eks ;;
      *) echo "Unknown context: $CTX"; exit 1 ;;
    esac
    echo "$CLUSTER_TYPE" > .cluster-type
  Announce out loud which environment we're in. The rest of the build reads
  .cluster-type to branch Phase 3 (ESO) and Phase 7 (cert-manager).

STEP 1 — walk me through what's in place:

  1. kubectl config current-context           (announce the cluster type detected above)
  2. kubectl get nodes -o wide                (expect 3 Ready nodes)
  3. kubectl get ns                            (workshop namespaces are created by
                                                gitops/apps/namespaces during Phase 2 —
                                                only kube-system + default exist here)
  4. kubectl -n kube-system get deploy metrics-server  (NEITHER environment pre-installs
                                                        metrics-server — we install it
                                                        in step 2 below)

STEP 2 — install metrics-server (both environments need it):

  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

  IF CLUSTER_TYPE=kubeadm, also apply the kubelet-insecure-tls patch
  (kubeadm self-signed kubelet certs require this):
    kubectl patch -n kube-system deploy metrics-server --type=json \
      -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

  Then: kubectl wait -n kube-system --for=condition=Available deploy/metrics-server --timeout=120s
  Then: kubectl top nodes   (verifies the install worked)

STEP 3 — run the gate:
  pytest tests/test_phase_01_foundation.py -v

When all tests pass, emit:
<promise>PHASE_1_DONE</promise>
```

## Namespace structure (9 namespaces created by `namespaces` Application in Phase 2)

These don't exist at Phase 1 yet on either cluster type. They're created at sync-wave -10 by `gitops/apps/namespaces` when Phase 2's app-of-apps bootstraps.

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

- **`kubectl get nodes` returns 401 (EKS only).** EKS Access Entry missing for the current AWS user. Pre-workshop preflight should have caught this; if surfaced here, swap to a spare cluster.
- **`kubectl get nodes` returns connection refused (kubeadm only).** Browser-shell session expired or the lab reset. Re-launch the KodeKloud lab.
- **`metrics-server` not Ready after 2 minutes (kubeadm).** Verify the `--kubelet-insecure-tls` patch was applied. Without it, metrics-server can't reach the kubelet metrics endpoint on self-signed certs.
- **Node count < 3.** Possible node scaling issue. Less than 3 nodes will tight-pack the workshop stack but the test gate accepts ≥ 2.
- **Cluster type detection failed (`Unknown context`).** Run `kubectl config current-context` manually; if it returns something unexpected (e.g., a personal cluster), the attendee is on the wrong context. Switch back to the workshop-provisioned one.
- **`falco` namespace shown as empty when you `kubectl get pods -n falco`.** This is correct — it's a leader-election Lease holder, not a workload home. See namespace table above.

## What students see on their cluster

Same end state — 3 Ready nodes, `kubectl top` works, `.cluster-type` written, `<promise>PHASE_1_DONE</promise>` emitted. The path differs only in what the cluster-type detection prints in step 0. Half the room will see `CLUSTER_TYPE=eks`, half will see `CLUSTER_TYPE=kubeadm`. From here on out, both halves run the same spec with the marker file driving the per-component branching where it matters.

## Score on the live scorecard

**Components covered:** VPC + Networking, EKS Cluster (or kubeadm equivalent), IAM/Pod Identity (EKS) / no-cloud-auth (kubeadm), Namespace Structure deferred to Phase 2 (4 of 27)

For these four:
- **Install: 10/10** — infrastructure existed Healthy. No AI involvement on this phase except the metrics-server install + cluster-type detection.
- **Integration: not applicable** — assessed in later phases as components actually use IRSA, the namespace structure, etc.
- **Usability: not applicable** — assessed in later phases when students/operators interact with the underlying infrastructure.

Foundation is the "free 4 components." Real scorecard variance starts at Phase 2 — and the cluster-type-driven Phase 3/7 variance lands the talk's biggest data point.
