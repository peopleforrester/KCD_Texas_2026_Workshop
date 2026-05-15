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
Phase 1 — Foundation. The cluster is pre-provisioned; this phase asserts
its health and brings up the two prerequisites the rest of the build
relies on (the 9 workshop namespaces, and metrics-server).

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
  3. kubectl get ns                            (only kube-system + default + kube-public +
                                                kube-node-lease — workshop namespaces get
                                                created in STEP 2 below)
  4. kubectl -n kube-system get deploy metrics-server
       IF CLUSTER_TYPE=eks: expect this to ALREADY EXIST — EKS provisions
         metrics-server as a managed addon. We will not re-install it.
       IF CLUSTER_TYPE=kubeadm: expect "deployments.apps metrics-server not
         found" — kubeadm clusters do not pre-install it. STEP 3 fixes that.

STEP 2 — apply the 9 workshop namespaces:

  kubectl apply -f gitops/manifests/namespaces/

  These 9 namespaces (argocd, apps, kyverno, monitoring, backstage, security,
  platform, cert-manager, falco) are foundational — the rest of the build
  deploys workloads INTO them. Phase 2's `namespaces` ArgoCD Application
  points at the same path on `main` and will adopt these existing namespaces
  idempotently. We apply them here so Phase 1's gate has something to grade
  AND so anything Phase 2 creates lands in a namespace that already exists.

STEP 3 — ensure metrics-server is installed (cluster-type branched):

  IF CLUSTER_TYPE=eks:
    The EKS-managed metrics-server addon is already installed (it ships with
    the cluster). DO NOT apply the upstream components.yaml — it collides
    with the addon on immutable Deployment selector fields and silently
    clobbers the Service+APIService wiring. Just verify the existing
    deployment reports Available:

      kubectl -n kube-system get deploy metrics-server
      kubectl wait -n kube-system --for=condition=Available deploy/metrics-server --timeout=60s

  IF CLUSTER_TYPE=kubeadm:
    KodeKloud's kubeadm clusters do NOT pre-install metrics-server. Install
    it from upstream and apply the kubelet-insecure-tls patch (kubeadm's
    self-signed kubelet certs reject metrics-server's default TLS verify):

      kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
      kubectl patch -n kube-system deploy metrics-server --type=json \
        -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
      kubectl wait -n kube-system --for=condition=Available deploy/metrics-server --timeout=120s

  Then on both:
      kubectl top nodes   (verifies the metrics API is reachable end-to-end)

STEP 4 — run the gate:
  pytest tests/test_phase_01_foundation.py -v

When all tests pass, emit:
<promise>PHASE_1_DONE</promise>
```

## Namespace structure (9 namespaces created in Phase 1 STEP 2)

Phase 1 applies these from `gitops/manifests/namespaces/`. Phase 2's `namespaces` ArgoCD Application points at the same path on `main` and adopts the existing namespaces (Application reports `Synced + Healthy` without recreating anything).

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
- **`kubectl top nodes` returns `Metrics API not available` (EKS).** Almost always caused by applying the upstream `metrics-server/components.yaml` against an EKS cluster that already has the managed addon installed. The upstream Deployment's selector labels differ from the addon's, the apply silently rejects the Deployment update (selector is immutable), and the same apply rewrites the `metrics-server` Service spec with a selector that no longer matches the addon pods — endpoints empty, APIService fails. Fix: STEP 3 in the prompt is explicit about NOT applying components.yaml on EKS. If the collision has already happened, recovery requires either `aws eks update-addon --resolve-conflicts OVERWRITE` (requires addon-manage IAM) or manually recreating the Service with the addon's two-label selector (`app.kubernetes.io/instance=metrics-server, app.kubernetes.io/name=metrics-server`).
- **Node count < 3.** Possible node scaling issue. Less than 3 nodes will tight-pack the workshop stack but the test gate accepts ≥ 2.
- **Cluster type detection failed (`Unknown context`).** Run `kubectl config current-context` manually; if it returns something unexpected (e.g., a personal cluster), the attendee is on the wrong context. Switch back to the workshop-provisioned one.
- **`falco` namespace shown as empty when you `kubectl get pods -n falco`.** This is correct — it's a leader-election Lease holder, not a workload home. See namespace table above.
- **Phase 2's `namespaces` Application shows `OutOfSync` after Phase 1 STEP 2.** Shouldn't happen — ArgoCD does adopt existing namespaces created via `kubectl apply` at the same path it reads from `main`. If it does happen, check that the namespaces are labeled identically to what `gitops/manifests/namespaces/namespaces.yaml` declares on `main`. Drift here usually means staging has labels main doesn't.

## What students see on their cluster

Same end state — 3 Ready nodes, `kubectl top` works, `.cluster-type` written, `<promise>PHASE_1_DONE</promise>` emitted. The path differs only in what the cluster-type detection prints in step 0. Half the room will see `CLUSTER_TYPE=eks`, half will see `CLUSTER_TYPE=kubeadm`. From here on out, both halves run the same spec with the marker file driving the per-component branching where it matters.

## Score on the live scorecard

**Components covered:** VPC + Networking, EKS Cluster (or kubeadm equivalent), IAM/Pod Identity (EKS) / no-cloud-auth (kubeadm), Namespace Structure deferred to Phase 2 (4 of 27)

For these four:
- **Install: 10/10** — infrastructure existed Healthy. No AI involvement on this phase except the cluster-type detection, namespace bootstrap, and (on kubeadm) the metrics-server install.
- **Integration: not applicable** — assessed in later phases as components actually use IRSA, the namespace structure, etc.
- **Usability: not applicable** — assessed in later phases when students/operators interact with the underlying infrastructure.

Foundation is the "free 4 components." Real scorecard variance starts at Phase 2 — and the cluster-type-driven Phase 3/7 variance lands the talk's biggest data point.
