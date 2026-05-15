# Cluster Environments Skill

Use this skill **before Phase 1's first action**, every workshop run.

The KCD Texas 2026 workshop runs against **two different Kubernetes environments**, and a few components (ESO in Phase 3, cert-manager in Phase 7, metrics-server in Phase 1) need different configuration depending on which one the attendee is on. Detect at Phase 1, write a marker file, branch the rest of the build off it.

## The two environments side-by-side

| | **Path A — Accenture EKS** | **Path B — KodeKloud kubeadm** |
|---|---|---|
| Pre-provisioned for | Terminal-comfortable attendees | Browser-preferring attendees (majority by headcount) |
| Cluster count | 10 (`kcd-tx-attendee-1` through `kcd-tx-attendee-10`) | ~40 (per-attendee browser lab) |
| Where attendees claim credentials | https://bubbly-harmony-production-574d.up.railway.app/ | Course UI: https://learn.kodekloud.com/user/courses/the-90-minutes-idp |
| Kubernetes version | EKS 1.32.13 | kubeadm v1.36.0 |
| Region | AWS us-east-2 | n/a (browser lab) |
| Nodes | 3 × t3.xlarge | 3 × Ubuntu (kubeadm-managed) |
| CNI | AWS VPC CNI (NetworkPolicy support via VPC CNI) | Calico / Canal (NetworkPolicy enforced) |
| Container runtime | containerd | containerd |
| Identity / IRSA / Pod Identity | Available (AWS) | None |
| Cloud LoadBalancer Services | Yes (AWS NLB/ALB) | No |
| Public DNS for ACME | Possible via Route53 | No |
| metrics-server pre-installed | **Yes** (EKS managed addon) | No |
| Default `kubectl` context | `arn:aws:eks:us-east-2:...:cluster/kcd-tx-attendee-N` | `kubernetes-admin@kubernetes` |
| Attendee's terminal | Local laptop, after `aws eks update-kubeconfig` | Browser shell, pre-authenticated |

## Detection logic (run this in Phase 1, FIRST)

```bash
CTX="$(kubectl config current-context 2>/dev/null)"
case "${CTX}" in
    kubernetes-admin@kubernetes)
        CLUSTER_TYPE=kubeadm
        ;;
    *eks*|arn:aws:eks:*)
        CLUSTER_TYPE=eks
        ;;
    *)
        # Unknown context — fail loud rather than guess
        echo "ERROR: cluster context '${CTX}' didn't match a known environment"
        echo "Expected: 'kubernetes-admin@kubernetes' (KodeKloud) or an EKS ARN (Accenture)"
        exit 1
        ;;
esac
echo "${CLUSTER_TYPE}" > "${CLAUDE_PROJECT_DIR:-$(pwd)}/.cluster-type"
echo "CLUSTER_TYPE=${CLUSTER_TYPE}"
```

After this runs, **`.cluster-type` at the repo root is the canonical signal** for every subsequent phase. Every other phase (3, 7, and tests that branch) reads this file. The file holds exactly one word: `eks` or `kubeadm`.

## Per-component branching

### `metrics-server` (Phase 1)

Different *install state* on the two paths — they look like the same problem but they need opposite handling.

- **EKS:** metrics-server is **pre-installed as a managed addon**. Do not touch it. The Service+APIService have an EKS-specific selector (two labels: `app.kubernetes.io/instance` + `app.kubernetes.io/name`) and live behind a Cluster Security Group rule the addon installs at provisioning time. Re-applying the upstream `components.yaml` against an EKS cluster looks like an upgrade but actually collides on immutable Deployment selector fields, then silently rewrites the Service to a three-label selector that no longer matches the addon pods — endpoints empty, APIService fails. **Just verify the existing deployment is Available; never apply the upstream manifest.**
- **kubeadm (KodeKloud):** metrics-server is **not present**. Install it from upstream and patch in `--kubelet-insecure-tls` because the kubeadm self-signed kubelet certs reject metrics-server's default TLS verification.

```bash
if [[ "${CLUSTER_TYPE}" == "eks" ]]; then
    # EKS managed-addon path — verify only, do NOT apply.
    kubectl -n kube-system get deploy metrics-server
    kubectl wait -n kube-system --for=condition=Available \
        deploy/metrics-server --timeout=60s
else
    # kubeadm path — fresh install + the standard self-signed-kubelet patch.
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    kubectl patch -n kube-system deploy metrics-server --type=json \
        -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
    kubectl wait -n kube-system --for=condition=Available \
        deploy/metrics-server --timeout=120s
fi

# Both paths verify the metrics API end-to-end:
kubectl top nodes
```

Test gate (`tests/test_phase_01_foundation.py::test_metrics_server_installed`) only checks `Deployment.status.availableReplicas >= 1` and so passes even if `kubectl apply` collided and broke the Service routing. That's a real gap: the gate looks green but `kubectl top` fails. Skip the apply on EKS and you sidestep the trap entirely.

### External Secrets Operator (Phase 3)

The operator itself installs identically on both. What differs is the **backend store**.

**On EKS** (`CLUSTER_TYPE=eks`):
- `ClusterSecretStore` resource of `provider.aws.service: SecretsManager`, region `us-east-2`
- Auth via Pod Identity (the operator's ServiceAccount maps to an IAM role through `eks.amazonaws.com/role-arn`)
- Secret material lives in AWS Secrets Manager outside the cluster
- ESO syncs SM → Kubernetes Secret
- Status when working: `ClusterSecretStore Ready=True`, `ExternalSecret SecretSynced`
- Status when IRSA unwired (the workshop's honest case): `ClusterSecretStore Ready=False` with `InvalidIdentityToken: No OpenIDConnect provider found` — Install scores high, Integration scores low, that's the workshop's scorecard variance point

**On kubeadm** (`CLUSTER_TYPE=kubeadm`):
- `SecretStore` (namespaced) or `ClusterSecretStore` of `provider.kubernetes` — ESO's "Kubernetes backend" reads from a Secret in another namespace
- No cloud auth required
- The "source secret" is a regular Kubernetes `Secret` created at workshop time in the `platform` namespace
- ESO syncs source-namespace Secret → target-namespace Secret
- Still demonstrates ESO's core value (decoupling secret source from consumer, sync controller, versioning, refresh interval) — just without the cloud backend
- Status when working: `SecretStore Ready=True`, `ExternalSecret SecretSynced` — both pass

The workshop's `gitops/apps/eso-resources` Application currently ships the EKS variant. On kubeadm, Claude generates the Kubernetes-backend variant locally to `~/my-eso-resources.yaml` and applies it instead.

**Scorecard note:** the kubeadm path actually scores *higher* on ESO Integration because the secret sync succeeds end-to-end. EKS scores higher on Install but tanks Integration without IRSA. Same operator, two failure modes, two honest scorecard rows.

### cert-manager (Phase 7)

cert-manager installs identically on both. What differs is the **ClusterIssuer**.

**On EKS**:
- `ClusterIssuer` of `spec.acme.solvers[].dns01.route53` referencing Route53 hosted zone
- Needs IAM permissions for Route53 (workshop doesn't wire these; ClusterIssuer registers but cert orders never succeed)
- Honest scorecard: Install passes, Integration partial (issuer exists but won't mint real certs without DNS + IAM work)

**On kubeadm**:
- `ClusterIssuer` of `spec.selfSigned: {}` (or a CA-issuer with a self-signed CA generated at install time)
- No DNS dependency
- Can mint real certs against the cluster's own self-signed authority
- Status when working: `Certificate` resources reach `Ready=True` — full integration works
- Honest scorecard: Install passes, Integration passes; Usability is "OK for internal-cluster TLS, not for production-trusted external TLS" — but that's the same Usability ceiling self-signed has anywhere

The workshop's `gitops/apps/cert-manager-issuers` Application currently ships the ACME variant. On kubeadm, Claude generates a self-signed variant to `~/my-cluster-issuers.yaml` and applies it instead.

### LoadBalancer Services

**Don't depend on these working in either path.** EKS would provision an NLB, kubeadm has no cloud-controller-manager and the Service stays `Pending` forever. The workshop uses `kubectl port-forward` for every UI verification (Grafana, Backstage, etc.) on both paths. No code change needed — just don't generate `Service.type=LoadBalancer` manifests during the build.

### NetworkPolicies

**Behavior is identical on both** for the workshop's policies (`gitops/manifests/network-policies/`). VPC CNI enforces NetworkPolicies on EKS as of v1.14+ (we're on v1.21.1-eksbuild.8, well past that). Calico/Canal on kubeadm enforces them natively. The policies themselves are vanilla Kubernetes `NetworkPolicy` resources, no CNI-specific extensions.

## Why the differences matter for the scorecard

The KodeKloud and EKS paths score **differently by design** on Phase 3 (ESO) and Phase 7 (cert-manager). That divergence is **data, not a defect** — it's a live A/B of "same spec, different cluster substrates" running in the same room at the same time. The closing slide's "Install ≫ Integration ≫ Usability" thesis gets stronger when the audience sees the *same* spec hit different scorecard variance depending on what the cluster underneath happens to be.

**Don't try to "fix" KodeKloud to look like EKS, or vice versa.** Either path is a valid workshop run. The scorecard rows just tell different stories.

## What stays identical across both environments

- Phase 1 test gate (asserts cluster Health, namespaces, metrics-server)
- Phase 2 (GitOps bootstrap, app-of-apps, ArgoCD itself)
- Phase 4 (observability — Prometheus, Grafana, OTel, Loki, Tempo, Promtail)
- Phase 5 (Backstage)
- Phase 6 (Integration — drift detection, admission events, audit trail)
- The `<promise>PHASE_N_DONE</promise>` discipline
- The single-paste autonomous prompt
- The Kyverno policies + Falco rules + FalcoTalon auto-response demo (all behave identically on both CNIs)

## TL;DR

```
Phase 1 detects → writes .cluster-type → other phases read it.
Phases 1, 3, 7 branch behavior. Phases 2, 4, 5, 6 don't care.
EKS = AWS-backed integrations (might or might not work end-to-end without extra wiring).
kubeadm = self-contained alternatives (work end-to-end, just locally).
Scorecard variance between the two paths is the talk.
```
