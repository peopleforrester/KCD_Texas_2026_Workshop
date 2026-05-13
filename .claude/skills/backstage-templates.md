# Backstage Skill

Use this skill **before generating the Backstage Application.** The Backstage Helm chart is unusual in a critical way: **it has no default container image.** Without an explicit image, the Pod won't start. This is the #1 way Phase 4 of the workshop faceplants.

## Critical version pins

| Thing | Workshop value |
|---|---|
| Helm chart | `backstage/backstage` |
| Chart version | `2.7.0` |
| Image (workshop) | `ghcr.io/backstage/backstage:1.30.2` |
| Image config path | `backstage.image.registry` + `repository` + `tag` (nested under `backstage:`) |
| App-config override | `backstage.appConfig` (nested under `backstage:`) — required so Kubernetes plugin init does not crash |
| Service port | `7007` (NOT 3000 — that's old tutorials) |
| Backend system | current `createBackend()` from `@backstage/backend-defaults` |

## The two traps

**Trap 1: chart has no default image.** Most Helm charts ship with a `appVersion` that becomes the default image tag. Backstage's chart explicitly does not — Backstage is *"infrastructure for an app you build"*, meaning the chart assumes you've built and pushed your own image containing your custom plugins, catalog, and config. If you don't set `backstage.image.*`, the Pod has no container to run.

**Trap 2: the upstream image's baked-in `app-config.yaml` initializes the Kubernetes plugin and crashes without a cluster locator.** This is the bug we caught on a live cluster on 2026-05-13. Logs look like:

```
ForwardedError: Plugin 'kubernetes' startup failed; caused by
  Error: Kubernetes configuration is missing
    at KubernetesBuilder.build (.../plugin-kubernetes-backend.../1576:15)
```

The fix is a `backstage.appConfig` override that sets a minimal-but-valid Kubernetes config (`serviceLocatorMethod: multiTenant` + empty `clusterLocatorMethods: []`). The plugin initializes with zero clusters to query, the backend starts.

## What we use, and why this image specifically

`ghcr.io/backstage/backstage:1.30.2` is the last tagged release on the Backstage project's own GHCR image path. The Backstage project stopped tagging this image after 1.30 in favor of users building their own. The image works fine for demo / workshop purposes — it boots, shows a small example catalog, and demonstrates what a developer portal *is*.

Earlier drafts of this workshop pointed at `roadiehq/community-backstage-image:1.50.4`. **That image does not exist** at any registry — verified via HTTP 404 against GHCR and the Docker Hub repo being abandoned since 2021-08-07. Don't go back to it; use the upstream image.

## Pattern 1 — Workshop Application values (matches `gitops/apps/backstage.yaml`)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: backstage
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "5"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    chart: backstage
    repoURL: https://backstage.github.io/charts
    targetRevision: "2.7.0"
    helm:
      valuesObject:
        backstage:
          image:
            # CRITICAL: chart has no default image; you MUST set these.
            registry: ghcr.io
            repository: backstage/backstage
            tag: "1.30.2"
          # CRITICAL: the upstream image's baked-in app-config initializes
          # the Kubernetes plugin, which crashes without a cluster locator.
          # Override with a minimal-but-valid config to satisfy plugin init.
          appConfig:
            app:
              title: KCD Texas 2026 Workshop IDP
              baseUrl: http://localhost:7007
            backend:
              baseUrl: http://localhost:7007
              listen: { port: 7007 }
              csp:
                connect-src: ["'self'", "http:", "https:"]
              cors:
                origin: http://localhost:7007
                methods: [GET, HEAD, PATCH, POST, PUT, DELETE]
                credentials: true
              database:
                client: better-sqlite3
                connection: ":memory:"
            organization:
              name: KCD Texas Workshop
            auth:
              providers: {}                  # guest mode
            kubernetes:
              serviceLocatorMethod:
                type: multiTenant
              clusterLocatorMethods: []      # zero clusters; plugin inits cleanly
            catalog:
              rules:
                - allow: [Component, System, API, Resource, Location, Template, User, Group]
              locations: []
            techdocs:
              builder: local
              publisher:
                type: local
        ingress:
          enabled: false                     # Workshop: port-forward only
        service:
          type: ClusterIP
          ports:
            backend: 7007                    # Default Backstage backend port (NOT 3000)
  destination:
    server: https://kubernetes.default.svc
    namespace: backstage
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

Notes on the values structure:
- **`backstage.image.*`** and **`backstage.appConfig`** are nested under `backstage:`, not at the top level. The chart's values schema puts the workload config inside `backstage:` and the service/ingress at top level. Get this nesting wrong and Helm silently ignores your override. *(Live-discovered bug: a previous version of `gitops/apps/backstage.yaml` had `appConfig` at the root; the chart accesses `.Values.backstage.appConfig`, so the override was being silently dropped. Watch for this in the diff if Claude generates a flat structure.)*
- **`image.registry: ghcr.io`** is explicit. The chart defaults to `ghcr.io` if unset, but explicit is clearer.

## Pattern 2 — Why this image specifically

The Backstage backend was rewritten in late 2023. Two systems exist:

- **Legacy backend** — `createServiceBuilder()` from `@backstage/backend-common`. Used by Backstage <1.10.
- **Current backend** — `createBackend()` from `@backstage/backend-defaults`. Used by Backstage 1.10+.

Chart 2.x **only runs the current backend system.** If you swap in an older custom image (e.g., one built against Backstage 1.5), the Pod crashes with:

```
TypeError: createServiceBuilder is not a function
```

`ghcr.io/backstage/backstage:1.30.2` is built with the current system. Safe.

## Pattern 3 — Why the Kubernetes plugin gets a minimal config (not disabled)

The upstream image's baked-in app-config initializes the Kubernetes plugin at startup. The plugin's `build()` requires a `clusterLocatorMethods` value — without it, the plugin throws and the entire backend crashes.

You cannot simply *disable* the plugin from outside the image (no env var, no override flag). What you CAN do is provide an `appConfig` override that the chart mounts at `/app/app-config-extra.yaml` and Backstage reads in addition to the baked-in config. The override at `backstage.appConfig.kubernetes` is what satisfies the plugin's init: zero clusters configured, plugin starts with nothing to query, backend boots cleanly.

For the scorecard: **Usability for Phase 4 will reflect that the catalog is read-only and the Kubernetes plugin shows nothing.** That's honest. Production Backstage requires a workshop-specific image with your org's catalog providers, plugins, and templates pre-baked. Building that is 30+ minutes of plumbing per provider; not a 90-minute workshop scope.

## Pattern 4 — Why no ingress, no auth, no Postgres

- **No ingress:** workshop uses `kubectl port-forward`. No TLS, no DNS, no cert-manager. Workshop concession.
- **No auth providers:** the `auth.providers: {}` override is guest mode. Production needs OAuth (GitHub, Google, etc.); workshop guests are fine.
- **No PostgreSQL:** the chart's `postgresql.enabled` defaults to false. Backstage uses its built-in SQLite (in-memory for the workshop). Workshop sidesteps the database complexity.

If Claude generates `postgresql.enabled: true`, the install still works but adds a second pod and a secret. Workshop default is `false`.

## Common failure modes

| What you see | Cause | Fix |
|---|---|---|
| Pod in `CrashLoopBackOff`, logs show `Plugin 'kubernetes' startup failed; Kubernetes configuration is missing` | Missing `backstage.appConfig.kubernetes` override | Apply the appConfig block from Pattern 1 |
| Pod in `CrashLoopBackOff`, image errors in logs | Missing `backstage.image.repository` / `tag` | Set both; chart has no default |
| Pod logs show `createServiceBuilder is not a function` | Custom image built against legacy backend | Use `ghcr.io/backstage/backstage:1.30.2`; don't debug legacy backends live |
| Pod logs show `ERR_OSSL_EVP_UNSUPPORTED` | Node version / OpenSSL mismatch in image | Pin tag `1.30.2`; later versions may have this |
| Pod Running but `curl` returns connection refused | `backend.listen.host: 127.0.0.1` (chart default) | The appConfig in Pattern 1 sets `listen: { port: 7007 }` which binds to all interfaces |
| Catalog shows empty / `No entities` | The `catalog.locations: []` override produces an empty catalog | Expected with the workshop's minimal appConfig. To populate, mount a static catalog ConfigMap and add a `type: file` location |
| Pod stuck `ImagePullBackOff` | Image registry pull issue | `kubectl describe pod -n backstage <pod>` — usually node-level, not workshop |
| `appConfig` override silently ignored | `appConfig:` at values root instead of under `backstage:` | Re-nest. Chart accesses `.Values.backstage.appConfig`. |

## Verify commands

```bash
# Pod Running (most common failure point — check logs if not)
kubectl get pods -n backstage
# Expected: backstage-<hash> Pod, Running, ~60-90s after Application syncs

# If CrashLoopBackOff:
kubectl logs -n backstage -l app.kubernetes.io/name=backstage --tail=80

# Port-forward
kubectl port-forward -n backstage svc/backstage 7007:7007 &

# Health probe
curl -s http://localhost:7007/.backstage/health/v1/liveness
# Expected: {"status":"ok"}

# Catalog API
curl -s http://localhost:7007/api/catalog/entities | python3 -c "import sys,json; print(len(json.load(sys.stdin)))"
# Expected: integer >= 0  (will be 0 with empty catalog.locations; that's fine)

# UI
# Browser: http://localhost:7007  — Catalog page renders (likely empty)
```

## What NOT to generate

- A values block without `backstage.image.*` — chart has no default; the #1 failure
- `image:` at the top level of values (instead of nested under `backstage:`) — wrong path
- `appConfig:` at the top level of values (instead of nested under `backstage:`) — silently dropped
- A values block without the `backstage.appConfig.kubernetes` override — the Pod will CrashLoopBackOff on plugin init
- `service.ports.backend: 3000` — old tutorials; current image listens on 7007
- `catalog.providers.github:` — requires real GitHub token, out of workshop scope
- `auth.providers.github:` — OAuth out of workshop scope; the appConfig uses guest mode
- `ingress.enabled: true` — workshop uses port-forward
- `postgresql.enabled: true` — adds a second pod and a secret; SQLite is fine for 90 min

## The talk's payoff lives in this phase

Phase 4 is the most likely component to fail in front of an audience. **That's the talk.** If your Backstage Pod is in CrashLoopBackOff at minute 20 and you haven't recovered, write down exactly what the logs said. A 3/10 Install score with *"Pod stuck in CrashLoopBackOff with `Plugin 'kubernetes' startup failed` because Claude omitted the appConfig kubernetes override"* is **more valuable** to the workshop's central claim than a working Backstage with a perfect 9/10.

"AI didn't just speed up implementation. It ate most of it. But here's what it choked on." Point at your scorecard.
