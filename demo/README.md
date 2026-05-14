# Demo scripts

Terminal-based scripts to verify each workshop component is running in the cluster currently set in your kubeconfig. Each script:

- Prints a context card so the audience sees exactly which cluster you're hitting
- Echoes every `kubectl` command before running it
- Emits one of four badges per check: ![ACCESS], ![DENY], ![SUCCESS], ![FAILURE] — plus ![INFO], ![WARN], ![PENDING] for narration
- Uses your **current** `kubectl` context — no hardcoded cluster, no `--context=` flags

## Usage

```bash
# Make sure your kubectl context points at the cluster you want to demo
kubectl config current-context

# Run any script from the repo root
bash demo/03-kyverno-admission.sh
```

For a non-interactive run (skip the "press ENTER" pauses):

```bash
NO_PAUSE=1 bash demo/03-kyverno-admission.sh
```

## Script index

| # | Script | Verifies | Phase |
|---|---|---|---|
| 01 | [`01-cluster-foundation.sh`](01-cluster-foundation.sh) | nodes Ready, expected namespaces, metrics-server | 1 |
| 02 | [`02-argocd-state.sh`](02-argocd-state.sh) | ArgoCD core pods, app-of-apps + all child Applications | 2 |
| 03 | [`03-kyverno-admission.sh`](03-kyverno-admission.sh) | 3 ClusterPolicies, bad pod DENIED, good pod ACCESS | 3 |
| 04 | [`04-falco-runtime.sh`](04-falco-runtime.sh) | DaemonSet on every node, custom rules loaded, alert on shell-spawn | 3 |
| 05 | [`05-falcosidekick.sh`](05-falcosidekick.sh) | alert forwarder Running, Prometheus metrics endpoint, talon output wired | 3 |
| 06 | [`06-falco-talon.sh`](06-falco-talon.sh) | end-to-end response: exec → alert → terminate → k8s event | 3 |
| 07 | [`07-external-secrets.sh`](07-external-secrets.sh) | ESO pod Running, ClusterSecretStore status (honest IRSA gap) | 3 |
| 08 | [`08-rbac.sh`](08-rbac.sh) | workshop ClusterRoles + RoleBindings | 3 |
| 09 | [`09-network-policies.sh`](09-network-policies.sh) | default-deny + per-namespace allows; cross-NS traffic blocked | 3 |
| 10 | [`10-prometheus-grafana.sh`](10-prometheus-grafana.sh) | Prometheus + Grafana Running, ArgoCD scrape targets up | 4 |
| 11 | [`11-otel-collector.sh`](11-otel-collector.sh) | OTel DaemonSet on every node, OTLP receiver listening | 4 |
| 12 | [`12-loki-tempo.sh`](12-loki-tempo.sh) | Loki + Tempo + Promtail Running, sample-app logs ingesting | 4 |
| 13 | [`13-backstage.sh`](13-backstage.sh) | Pod Running, port 7007 reachable, catalog API responds | 5 |
| 14 | [`14-cert-manager.sh`](14-cert-manager.sh) | cert-manager pods, ClusterIssuers registered | 7 |
| 15 | [`15-sample-app.sh`](15-sample-app.sh) | Flask + OTel pod, /, /health, /ready endpoints | 5 |
| 16 | [`16-party-apps.sh`](16-party-apps.sh) | 5 themed nginx workloads (hedgehog, unicorn, spider, wombat, mantis-shrimp) | 5 |
| 17 | [`17-ecom-apps.sh`](17-ecom-apps.sh) | ecom-api + ecom-frontend + ecom-worker | 5 |
| 18 | [`18-load-generator.sh`](18-load-generator.sh) | load-generator pod Running | 5 |

## Badge legend

| Badge | Meaning |
|---|---|
| ![ACCESS] | request was allowed / pod was admitted / call succeeded |
| ![DENY]   | request was rejected by policy / RBAC / network rule (this is usually the *win*) |
| ![SUCCESS] | check passed |
| ![FAILURE] | check failed — investigate |
| ![INFO]   | informational, no pass/fail signal |
| ![WARN]   | something to watch, but not blocking |
| ![PENDING] | resource exists but not yet Ready |

[ACCESS]: # "green background"
[DENY]:   # "red background"
[SUCCESS]: # "green background"
[FAILURE]: # "red background"
[INFO]:   # "blue background"
[WARN]:   # "yellow background"
[PENDING]: # "yellow background"

## Convention all scripts follow

- `set -euo pipefail` at the top so any unchecked failure aborts the demo cleanly
- Source `_lib.sh` for color/badge functions; never duplicate the ANSI codes
- Show the context card on first action so the audience never wonders which cluster
- Use `narrate "$@"` to echo + execute a command — every `kubectl` is visible
- Score with a badge at the end so the audience sees a clear pass/fail summary
- No script ever modifies `~/.kube/config` or switches context — it uses what's set
- No script requires `--context=` or `--kubeconfig=` flags — it inherits the environment

## When something fails on the projector

The badge tells you instantly. If you see ![FAILURE], read the kubectl output above it — the script narrated the command so the audience already saw it run.
