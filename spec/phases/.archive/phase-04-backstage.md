# Phase 4 — Backstage (or the pre-recorded fallback)

**Skill:** `.claude/skills/backstage-templates.md`
**Ground truth:** `gitops/apps/backstage.yaml`
**Test gate:** `tests/test_phase_04_backstage.py` (pytest — all must pass for promise)

---

## Two paths into this phase

**Path A — we have time** (~20+ minutes left after Phase 3 scores). Drive Phase 4 live like the previous phases.

**Path B — we don't have time** (~10 minutes or less left). Play the pre-recorded Phase 4 segment during the closing 5 minutes. Score it like the other phases on the live scorecard. "This is what happened when I tried this last night — Install N, Integration N, Usability N. Same pattern as the live phases: the chart installs fine, the platform integration is mediocre, the usability for a developer Monday morning is low."

Either path produces honest scorecard data. Both work.

## Critical context before either path

The Backstage Helm chart **has no default container image**. If Claude generates values without setting `backstage.image.repository` and `backstage.image.tag`, the Pod fails to start. This is the trap that defines the phase — it's the moment "AI ate my implementation" actually shows up in practice.

The workshop image is **`ghcr.io/backstage/backstage:1.30.2`** — the upstream Backstage project's last tagged release on its own GHCR path.  **One important catch**, validated on a live cluster on 2026-05-13: the upstream image's baked-in `app-config.yaml` initializes the Kubernetes plugin, which crashes at startup with `Plugin 'kubernetes' startup failed; caused by Error: Kubernetes configuration is missing` unless we provide a cluster locator.  The workshop ground truth at `gitops/apps/backstage.yaml` includes a `backstage.appConfig` override that sets `kubernetes.serviceLocatorMethod: multiTenant` and `clusterLocatorMethods: []` — the plugin initializes with zero clusters and Backstage boots cleanly.  Watch for this in the diff — if Claude generates the manifest without the appConfig override, the Pod CrashLoopBackOffs and that IS the talk's payoff for this phase.

Earlier tarball drafts of this spec pointed at `ghcr.io/roadiehq/community-backstage-image:1.50.4`.  Live verification (HTTP 404 against GHCR + Docker Hub repo abandoned since 2021-08-07) confirms that image does not exist anywhere.  Don't go back to it.

## Path A — the live build

### Goal

Generate the Backstage Application live, diff against ground truth, port-forward port 7007 on the projector, and see whether the catalog renders. Most likely to faceplant on stage of any of the four phases. That's the point.

### What the audience sees

- Phase 4's Backstage Application is already deploying via Phase 1's app-of-apps (sync wave 5)
- I have Claude generate an equivalent live, paying special attention to whether it includes the image config block
- Port-forward and a browser tab on the projector
- The room watches a real moment of "did AI build a working developer portal or not"

### The prompt I paste to Claude

```
Read .claude/skills/backstage-templates.md and spec/phases/phase-04-backstage.md.

First, walk me through gitops/apps/backstage.yaml and explain:
  1. Why does the Backstage chart have no default image?  What does it mean
     for a chart to be "infrastructure for an app you build"?
  2. What are backstage.image.registry / repository / tag doing in the ground
     truth?  What would happen if they were unset?
  3. The upstream image at ghcr.io/backstage/backstage:1.30.2 uses the current
     Backstage backend system (createBackend() from
     @backstage/backend-defaults).  What if I used an older image built
     against the legacy backend (createServiceBuilder())?  Would the chart
     start?
  4. The ground truth includes a backstage.appConfig override.  Why?  What
     would happen at Pod startup without the override?  (Hint: the upstream
     image's baked-in app-config initializes the Kubernetes plugin, which
     crashes on init without a cluster locator.)

Second, generate the Application:
  - File: ~/my-backstage.yaml
  - Name: backstage, sync wave 5
  - Chart: backstage from https://backstage.github.io/charts, version 2.7.0
  - Destination namespace: backstage
  - Values:
      backstage.image.registry: ghcr.io
      backstage.image.repository: backstage/backstage
      backstage.image.tag: "1.30.2"
      backstage.appConfig: (the kubernetes.clusterLocatorMethods: [] override,
        see ground truth for the full block)
      ingress.enabled: false
      service.type: ClusterIP
      service.ports.backend: 7007
  - syncOptions: CreateNamespace=true, ServerSideApply=true

Third, diff and walk through:
  diff ~/my-backstage.yaml gitops/apps/backstage.yaml

Pay special attention to the image config — if you omitted it, point that out
as a critical bug.

Then I'll port-forward and check the catalog.

When the gate below passes, output:
<promise>PHASE_4_DONE</promise>
```

### The test gate

```bash
# Gate 1: Backstage Pod Running (the failure-prone gate)
kubectl get pods -n backstage
# Expected: backstage-<hash> Pod, status Running, ~60-90s after Application syncs
# If CrashLoopBackOff:
kubectl logs -n backstage -l app.kubernetes.io/name=backstage --tail=80

# Gate 2: Port-forward
kubectl port-forward -n backstage svc/backstage 7007:7007 &

# Gate 3: Catalog API reachable
curl -s http://localhost:7007/api/catalog/entities | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(f'{len(d)} entities')"
# Expected: integer >= 1 (community image ships example entities)

# Gate 4: UI loads on the projector
# Browser: http://localhost:7007 → Catalog nav → at least one Component visible

# Gate 5: ArgoCD Application Healthy
kubectl get application backstage -n argocd
```

### Failure modes (the most likely on stage)

- **`backstage.image.repository` / `tag` missing in values.** Pod fails to start. This is THE failure for this phase. If Claude's generated manifest is missing the image config, point at it as the bug live and score Install accordingly.
- **`Plugin 'kubernetes' startup failed; Kubernetes configuration is missing`** in logs (CrashLoopBackOff after 3 restarts).  The upstream image's baked-in app-config initializes the Kubernetes plugin and it crashes without a cluster locator.  Look at the diff of `~/my-backstage.yaml` vs ground truth — Claude likely omitted the `backstage.appConfig` block with `kubernetes.clusterLocatorMethods: []`.  Live-validated on 2026-05-13; that's why the override is in the ground truth.
- **`createServiceBuilder is not a function`** in logs. Wrong image — built against legacy backend. Don't try to fix this on stage in 5 minutes; pin to `1.30.2` and move on.
- **`ERR_OSSL_EVP_UNSUPPORTED`** in logs. Node version / OpenSSL mismatch. Pin tag, don't debug live.
- **Catalog API returns 0 entities.** Static catalog wasn't mounted. Upstream image normally ships the catalog inline — if empty, check `kubectl describe pod` for volume mount errors.

## Path B — the pre-recorded fallback

If Phase 3 ran long, I have a recording at `assets/phase-04-backstage-recorded-run.mp4` (or wherever I stash it). Play it during the closing 5 minutes:

> "We ran out of time for Phase 4 live. Here's what happened when I ran it last night under no audience pressure. Watch — the chart installs in about 30 seconds. The Pod takes 90 seconds to come up. The catalog renders with example entities. Install 7, Integration 6, Usability 4. Why Usability 4? Because the catalog is static. A developer can browse it but can't ship anything through it. That's the gap that doesn't shrink with AI."

Score it on the live scorecard. The recording fills the same scorecard row as a live build would have.

## What students see on their cluster

Their Backstage Application is reconciling from the same pre-committed manifest with the same image pin. Their port-forward should bring up the same catalog. Whether their Pod actually reaches Running depends on cluster conditions — that's part of the data their scorecard captures.

## Score on the live scorecard

**Row: Backstage**
- Install — Did Claude generate a manifest with the image config? Did the Pod come up Running? Was the failure (if any) a known trap or novel?
- Integration — Did it play nicely with the rest? Sync wave 5 right? ArgoCD reconciled cleanly?
- Usability — Can a developer find your catalog, understand what's there, and ship a service through it Monday morning?

Usability for Backstage is almost always low on the workshop scorecard. The community image's catalog is static and read-only. That's not a workshop failing — it's the honest data. Production Backstage requires a custom-built image with your org's catalog providers, plugins, and templates. Building that is 30+ minutes of plumbing per provider; not a 90-minute workshop scope.

**That gap — installed-but-not-shippable — is the closing slide.**
