# KubeAuto AI Day Reference Repo Analysis

> **STATUS: SUPERSEDED.** This document was written on 2026-04-24 as a
> pre-design analysis when the KCD Texas workshop was scoped to 4 phases.
> The workshop was extended on 2026-05-14 to the **full 7 phases / 27
> components** matching the kubeauto reference. The current spec is at
> `spec/BUILD-SPEC.md` and `spec/phases/phase-0[1-7]-*.md`. The body
> below remains as a historical record of the earlier design rationale.

Source: `github.com/peopleforrester/kubeauto-ai-day`

Analysis date: 2026-04-24. Purpose: inform diagram creation for the KCD Texas
2026 condensed 4-phase workshop (90 minutes, students build on pre-provisioned
EKS clusters using Claude Code).

---

## 1. Overall Architecture

The reference IDP is a 7-phase, 27-component platform on EKS. Everything after
Phase 2 is deployed as an ArgoCD Application via the app-of-apps pattern. No
`kubectl apply` after GitOps bootstrap.

### Component Stack

| Layer | Component | Version (deployed) | CNCF Status |
|-------|-----------|-------------------|-------------|
| Infrastructure | EKS | 1.34 | Graduated |
| GitOps | ArgoCD | 3.3.0 (chart 9.4.2) | Graduated |
| Policy | Kyverno | 1.17.0 (chart 3.7.0) | Incubating |
| Runtime Security | Falco (eBPF) | 0.43.0 (chart 8.0.0) | Graduated |
| Secret Mgmt | ESO + AWS SM | 1.3.2 | Sandbox |
| Metrics | Prometheus | 3.9.1 (kube-prom-stack 82.1.0) | Graduated |
| Dashboards | Grafana | 12.3.3 (via kube-prom-stack) | Ecosystem |
| Telemetry | OTel Collector | 0.145.0 | Incubating |
| Portal | Backstage | 1.9.1 (chart 2.6.3) | Incubating |
| TLS | cert-manager | 1.19.3 | Ecosystem |
| Load Balancer | AWS LB Controller | 2.x (chart 1.11.0) | Ecosystem |

### Namespace Layout

| Namespace | Contents | Kyverno Enforcement |
|-----------|----------|-------------------|
| `argocd` | ArgoCD server, repo-server, app controller | Excluded |
| `security` | Kyverno, Falco, Falcosidekick, ESO | Excluded |
| `monitoring` | Prometheus, Grafana, OTel Collector | Excluded |
| `backstage` | Backstage portal | Excluded |
| `apps` | User workloads, sample app | **Enforced** (6 policies) |
| `platform` | ResourceQuotas, PDBs, RBAC resources | Excluded |
| `cert-manager` | cert-manager controller | Excluded |
| `kyverno` | Kyverno CRDs (separate from security) | Excluded |

The `apps` namespace has PSS `baseline` enforce + `restricted` warn labels,
default-deny NetworkPolicy, and a ResourceQuota (10 pods, 4 CPU, 8Gi memory).

---

## 2. Phase Structure (Reference: 7 Phases)

| Phase | Name | Budget | Components | Commits |
|-------|------|--------|------------|---------|
| 1 | Foundation | 60 min | VPC, EKS, IAM, Namespaces | 2 |
| 2 | GitOps | 90 min | ArgoCD, App-of-Apps, Sync Waves | 2 |
| 3 | Security | 120 min | Kyverno (6 policies), Falco, ESO, RBAC, NetworkPolicies | 5 |
| 4 | Observability | 90 min | Prometheus+Grafana, OTel, Dashboards, Alerts | 4 |
| 5 | Portal | 90 min | Backstage, Catalog, Templates | 2 |
| 6 | Integration | 60 min | E2E tests, Demo runbook | 2 |
| 7 | Hardening | 60 min | TLS, OIDC, Quotas, PDBs, Security docs | 4 |

Total AI build time (actual): **3 hours 10 minutes** for all 27 components.

### Mapping to KCD Texas 4-Phase Workshop

| KCD Phase | Reference Phases | What to keep | What to cut |
|-----------|-----------------|--------------|-------------|
| **Phase 1: GitOps** | Ref 2 | ArgoCD install, app-of-apps, sync waves, namespace app | Terraform (pre-provisioned), VPC/IAM (done), ApplicationSets |
| **Phase 2: Policy** | Ref 3 (partial) | Kyverno install, 3-4 policies (labels, limits, privileged, registries) | Falco, ESO, Falcosidekick, RBAC, NetworkPolicies |
| **Phase 3: Observability** | Ref 4 (partial) | Prometheus+Grafana via kube-prom-stack, 1 dashboard | OTel Collector, alerts, sample app instrumentation |
| **Phase 4: Portal** | Ref 5 (partial) | Backstage install, static catalog, 1 template | Second template, plugin wiring, TechDocs |

What's pre-provisioned for students (eliminates Ref Phases 1, 6, 7):
- EKS cluster (3x t3.xlarge) with VPC, IAM, kubeconfig
- Namespaces pre-created with PSS labels
- AWS LB Controller already running
- GitHub repo cloned with skeleton structure

---

## 3. Existing Diagrams and Visual Aids

### In-Repo ASCII Diagrams (docs/ARCHITECTURE.md)

1. **VPC/EKS Architecture** -- ASCII box diagram showing:
   - 3 AZs with public/private subnets
   - NAT gateway, ALB in public
   - EKS cluster with 2x m7i.xlarge nodes
   - 8 namespaces inside the cluster
   - AWS Secrets Manager + IAM external services
   - GitHub as GitOps source

2. **GitOps Pipeline Flow** -- Arrow diagram:
   ```
   Developer -> git push -> GitHub -> ArgoCD polls (30s) -> App-of-Apps root
   -> Sync waves: -10 (namespaces) -> -5 (CRDs) -> 0+ (apps)
   ```

3. **Security Data Flow** -- Arrow diagram:
   ```
   Pod attempt -> Kyverno admission -> Allow/Deny
   Runtime -> Falco eBPF -> Falcosidekick -> Prometheus -> Grafana
   ```

4. **Observability Data Flow** -- Arrow diagram:
   ```
   App metrics -> Prometheus scrape
   OTel Collector -> remote write -> Prometheus TSDB -> Grafana
   ```

5. **Secret Flow** -- Arrow diagram:
   ```
   AWS Secrets Manager -> ClusterSecretStore (IRSA) -> ExternalSecret
   -> K8s Secret -> Pod
   ```

### Sync Wave Ordering Table

| Wave | Components |
|------|-----------|
| -10 | Namespaces |
| -5 | Kyverno (CRD provider) |
| -4 | Kyverno policies, RBAC, NetworkPolicies, ESO operator |
| -3 | Falco, ESO resources |
| -2 | Falcosidekick |
| 1 | Prometheus (kube-prom-stack), cert-manager |
| 2 | OTel Collector, cert-manager issuers |
| 3 | Grafana dashboards, resource quotas, Loki, Tempo |
| 4 | Promtail |
| 5 | Sample app, Backstage resources |
| 6 | Backstage |
| 7 | Demo apps (Unicorn Party, E-commerce) |
| 8 | Load generator |

### Collateral Files

- `slides/kubeauto-ai-day-presentation-v17-clean-notes.pptx` (PowerPoint)
- `collateral/kubeauto-ai-day-presentation-v12.pptx` (earlier version)
- `collateral/qr-codes/` -- 5 QR code PNGs (argocd, backstage, ecom, repo, unicorn)
- `collateral/slide-outline.md` -- presentation structure
- `collateral/demo-runbook.md` -- live demo script

---

## 4. ArgoCD App-of-Apps Structure

Root application: `gitops/bootstrap/app-of-apps.yaml`
- Points to `gitops/apps/` directory on `staging` branch
- Automated sync with prune + selfHeal
- Retry: 5 attempts with exponential backoff

### 30 ArgoCD Application Manifests (gitops/apps/)

Core platform:
- `namespaces.yaml`, `rbac.yaml`, `network-policies.yaml`, `resource-quotas.yaml`

Security:
- `kyverno.yaml`, `kyverno-policies.yaml`, `falco.yaml`, `falcosidekick.yaml`
- `external-secrets.yaml`, `eso-resources.yaml`

Observability:
- `prometheus.yaml`, `grafana-dashboards.yaml`, `otel-collector.yaml`
- `loki.yaml`, `tempo.yaml`, `promtail.yaml`

Portal:
- `backstage.yaml`, `backstage-resources.yaml`

TLS:
- `cert-manager.yaml`, `cert-manager-issuers.yaml`

Workloads:
- `sample-app.yaml`, `load-generator.yaml`
- `unicorn-party.yaml`, `hedgehog-party.yaml`, `spider-party.yaml`
- `mantis-shrimp-party.yaml`, `wombat-party.yaml`
- `ecom-api.yaml`, `ecom-frontend.yaml`, `ecom-worker.yaml`

---

## 5. How Claude Code Builds It

### CLAUDE.md Key Rules

1. Read `spec/BUILD-SPEC.md` for full plan
2. Write tests first, implement until they pass
3. Everything after Phase 2 must be ArgoCD Application
4. No secrets in Git -- ESO only
5. No `kubectl apply` after ArgoCD is running
6. Update scorecard after each component (honest scores)
7. Commit per working component, not per file

### Claude Code Custom Commands

| Command | Purpose |
|---------|---------|
| `/build-phase N` | Execute phase N: read spec, write tests, implement, score, commit |
| `/score-component` | Update scorecard for a component |
| `/validate-phase` | Run phase validation tests |

### Claude Code Skills (`.claude/skills/`)

| Skill | Purpose |
|-------|---------|
| `argocd-patterns.md` | App-of-apps, sync waves, Helm chart version mappings |
| `kyverno-policies.md` | Policy authoring, enforce vs audit, namespace exclusions |
| `falco-rules.md` | Custom rule patterns, EKS-specific syscalls |
| `backstage-templates.md` | Software template skeleton, catalog wiring |
| `otel-wiring.md` | Collector config, receiver/exporter patterns |
| `eks-hardening.md` | Security groups, Pod Identity, PSS |

### Claude Code Hooks (`.claude/hooks/`)

| Hook | Type | Purpose |
|------|------|---------|
| `cc-pretool-guard.sh` | PreToolUse | Block `kubectl apply` in prod NS after Phase 2 |
| `cc-posttool-audit.sh` | PostToolUse | Remind to verify after apply/upgrade |
| `cc-stop-deterministic.sh` | Stop | Block exit without phase completion promise |
| `check-image-allowlist.sh` | PreToolUse | Validate image references |
| `check-namespace-scope.sh` | PreToolUse | Block cross-phase namespace operations |
| `commit-msg-validate.sh` | Git | Conventional commit format |
| `pre-push-tests.sh` | Git | Full test suite must pass |

### Ralph Wiggum / Smart Ralph Pattern

Each phase runs as a separate Claude Code loop with max iterations:
```
Phase 1: 15 iterations    Phase 5: 20 iterations
Phase 2: 20 iterations    Phase 6: 15 iterations
Phase 3: 30 iterations    Phase 7: 15 iterations
Phase 4: 20 iterations
```

Stop hook blocks exit unless `<promise>PHASEX_DONE</promise>` is present. The
overnight batch script (`overnight-build.sh`) chains all 7 phases sequentially,
running the test suite as a gate between each phase.

---

## 6. Component Connections (Data Flow Summary)

### ArgoCD as Control Plane

ArgoCD is the central orchestrator. It polls GitHub every 30s and reconciles
all 27+ Applications. Sync waves enforce dependency ordering (namespaces first,
CRDs next, then applications).

```
GitHub repo (staging branch)
    |
    v
ArgoCD (argocd namespace)
    |
    +---> Namespaces (wave -10)
    +---> Kyverno CRDs (wave -5)
    +---> Kyverno Policies + RBAC + NetworkPolicies (wave -4)
    +---> Falco + ESO (wave -3/-2)
    +---> Prometheus + cert-manager (wave 1)
    +---> OTel + cert-manager issuers (wave 2)
    +---> Grafana dashboards + Loki + Tempo (wave 3)
    +---> Backstage (wave 5-6)
    +---> Workloads (wave 7-8)
```

### Kyverno as Admission Gatekeeper

Kyverno sits as a validating admission webhook. Policies enforce in `apps`
namespace only (system namespaces excluded). Six ClusterPolicies:

1. `require-labels` -- pods must have app, team labels
2. `restrict-image-registries` -- ECR + approved CNCF only
3. `require-resource-limits` -- CPU and memory limits required
4. `disallow-privileged` -- no privileged containers
5. `require-probes` -- liveness + readiness probes required
6. `require-networkpolicy` -- namespace must have a NetworkPolicy (audit mode)

### Prometheus Scrapes Everything

Prometheus (via kube-prometheus-stack) scrapes:
- kubelet, node-exporter, kube-state-metrics (built-in)
- ArgoCD metrics endpoint
- Kyverno metrics endpoint
- Falcosidekick Prometheus metrics
- OTel Collector remote write receiver

### Grafana Visualizes

Pre-provisioned dashboard: `platform-overview` with 8 panels.
Additional dashboards for ArgoCD sync status, Kyverno violations, Falco alerts.
Dashboards provisioned via ConfigMap sidecar.

### Backstage Catalogs and Templates

Static file catalog (ConfigMap-mounted, no GitHub PAT needed).
Two software templates:
1. **Deploy a new service** -- creates namespace, deployment, service, NetworkPolicy, catalog-info.yaml, ArgoCD Application
2. **Create a new namespace** -- creates namespace with RBAC and NetworkPolicy

Template execution creates ArgoCD Applications, which then sync via GitOps.

---

## 7. Scorecard Results (Reference Build)

| Metric | Value |
|--------|-------|
| Total AI build time | 3h 10m (190 min) |
| Estimated manual time | 12h 5m (725 min) |
| Net toil reduction | 73.8% |
| Components scored | 27/27 |
| Zero-correction components | 11/27 (41%) |
| Average quality score | 8.0/10 |
| Components with partial toil shift | 5/27 (EKS, Kyverno Install, Falco Install, ESO, OTel) |
| Components where AI was slower | 0/27 |

### Hardest Components (most correction cycles)

| Component | Corrections | Issue |
|-----------|------------|-------|
| EKS Cluster | 3 | Module v21 variable renames, AWS provider 6.x, addon chicken-and-egg |
| Kyverno Install | 3 | Skill file webhook config wrong for chart 3.7.0, CRD annotation too large |
| OTel Collector | 3 | Chart 0.145 breaking change, wrong image variant, DaemonSet mode quirks |
| Falco Install | 2 | Skill file wrong chart version, removed macro in 0.42.x |
| ESO + Secrets Manager | 2 | API version v1 vs v1beta1, sync cache stale |
| E2E Integration | 2 | NetworkPolicy blocks egress, Falco non-interactive exec not logged |

### Easiest Components (zero corrections)

Namespaces, Kyverno Policies (all 6), Kyverno Interactions, RBAC,
NetworkPolicies, Grafana Dashboards, Alert Rules, Software Templates,
Backstage Wiring, Resource Quotas + PDBs, Documentation, ADRs.

---

## 8. Implications for KCD Texas 4-Phase Workshop

### What the Reference Build Tells Us

1. **Phase timing**: ArgoCD (8 min AI time) + Kyverno policies (5 min) +
   Prometheus+Grafana (8 min) + Backstage (10 min) = ~31 min of actual AI
   generation time. In a 90-min workshop with explanations, live coding,
   troubleshooting, this maps well to ~20 min per phase.

2. **Highest-risk phases for students**: Kyverno install (3 corrections in
   reference build), OTel Collector config. Consider using kube-prom-stack
   (includes Grafana) to simplify Phase 3. Skip OTel Collector entirely.

3. **Pre-provisioning eliminates Phase 1 entirely**: Students get working
   EKS + namespaces + kubeconfig. The reference build spent 37 min on this.

4. **Skill files are critical**: The reference build proves that components
   with skill files had fewer corrections. Students need skill files for
   ArgoCD chart versions, Kyverno namespace exclusions, and Backstage
   catalog wiring.

5. **Sync waves matter**: Students need the ordering table. Without it,
   ArgoCD tries to deploy apps before namespaces exist.

6. **Test-first works**: The `/build-phase` command forces test-then-implement.
   Workshop phases should include a "verify" step using simple kubectl checks.

### Recommended Diagram Set for KCD Texas

Based on the reference architecture, these diagrams would inform the workshop:

1. **Cluster Topology** (already exists as `cluster-topology.mvm`):
   Show 3x t3.xlarge nodes, 8 namespaces, what lives where.

2. **GitOps Flow**: Git push -> ArgoCD -> Sync waves -> Cluster. Show
   app-of-apps pattern with the 4 workshop apps (ArgoCD bootstrap, Kyverno,
   Prometheus, Backstage).

3. **Component Connection Map**: How the 4 phases connect:
   ArgoCD (manages) -> Kyverno (validates) -> Prometheus (scrapes) -> Grafana (shows)
   ArgoCD (manages) -> Backstage (catalogs) -> ArgoCD (deploys via templates)

4. **Phase Progression**: Linear 4-phase diagram showing what each phase
   produces and how it builds on the previous.

5. **Admission Flow**: Pod deploy attempt -> Kyverno -> Allow/Deny. Simple
   enough for a slide.

6. **Day-of Workflow** (already exists as `day-of-workflow.mmd`): Student
   experience from start to finish.

### Cost Estimate for Workshop

Reference cluster: ~$0.57/hr on m7i.xlarge x2.
Student clusters (t3.xlarge x3): ~$0.60/hr per cluster (EKS $0.10 + 3 x $0.1664/hr).
30 students x $0.60/hr x 4 hours = ~$72 total compute for the workshop.

### Key Files to Adapt from Reference

| Reference File | Workshop Adaptation |
|----------------|-------------------|
| `CLAUDE.md` | Simplify to 4 phases, add student guardrails |
| `.claude/skills/argocd-patterns.md` | Keep as-is, pin chart versions |
| `.claude/skills/kyverno-policies.md` | Keep, reduce to 3-4 policies |
| `.claude/commands/build-phase.md` | Adapt for 4 phases |
| `gitops/bootstrap/app-of-apps.yaml` | Template per student (different repo URL) |
| `gitops/namespaces/namespaces.yaml` | Pre-apply on clusters |
| `spec/BUILD-SPEC.md` | Rewrite as 4-phase workshop spec |
| `spec/SCORECARD.md` | Optional: simplified per-student scoring |
| Tests in `tests/` | Simplify to kubectl-based checks |
