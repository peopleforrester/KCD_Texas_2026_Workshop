# Phase 7 — Hardening

**Skill:** none (configuration-only, uses existing patterns)
**Ground truth:** `gitops/apps/{cert-manager,cert-manager-issuers,resource-quotas}.yaml`
**Test gate:** `tests/test_phase_07_hardening.py`

---

## Goal

Phase 7 confirms the production-hardening components that came along with Phase 2's app-of-apps reach Healthy:
- **cert-manager** — TLS certificate management operator
- **cert-manager-issuers** — ClusterIssuers (workshop uses self-signed; production would need real DNS-01 or HTTP-01)
- **ResourceQuotas + PDBs** — per-namespace resource caps and disruption budgets
- **(Optional) OIDC Authentication** — out of scope by default since it requires a real GitHub OAuth app
- **Documentation + ADRs** — already in the repo; scored as "did we keep them up to date"

## The prompt I paste to Claude

```
Read spec/phases/phase-07-hardening.md.

Phase 7 components are already reconciling from Phase 2's app-of-apps. Wait
for them to land, then verify:

  1. kubectl get pods -n cert-manager
     (cert-manager + cainjector + webhook — all Running)
  2. kubectl get clusterissuers
     (workshop's ClusterIssuers Ready)
  3. kubectl get resourcequota -A
     (resource quotas in apps + other workshop namespaces)
  4. kubectl get pdb -A
     (PodDisruptionBudgets for critical workloads)

Then run: pytest tests/test_phase_07_hardening.py -v

When the gate passes:
<promise>PHASE_7_DONE</promise>

And after that (or after I say "stop"):
<promise>ALL_PHASES_COMPLETE</promise>
```

## Known failure modes

- **cert-manager webhook not ready when ClusterIssuers apply (Wave 2).** Race condition: cert-manager's webhook needs ~30s after Pod Running. ClusterIssuers fail with "no endpoints available for service cert-manager-webhook". ArgoCD's retry policy with exponential backoff handles this — eventually syncs. Score Install based on first-attempt success; honest if it took 1-2 retries.
- **ClusterIssuers `Ready: False` with `no Order resources to satisfy`.** Expected on the workshop cluster — without real DNS or HTTP-01 wiring, the issuer can register but won't actually mint certificates. Honest scorecard: Install 9, Integration 3, Usability 5 ("you can see the issuer but can't actually order a cert here").
- **ResourceQuota blocks legitimate pods.** If the quota is set tight, new Pods may be Forbidden. Workshop quotas are generous (matching kubeauto's). Adjust if needed.

## OIDC Authentication (deferred unless pre-provisioned)

OIDC requires:
1. A GitHub OAuth App registered ahead of time
2. The Client ID + Secret loaded into a Kubernetes Secret accessible to ArgoCD's Dex connector
3. ArgoCD ConfigMap updated with the connector config
4. Backstage's auth.providers.github wired with the same credentials

For the workshop, none of those are pre-provisioned. OIDC is documented as "the path you'd take Monday morning" but not deployed live. Score it 0/0 with explanation.

## Documentation + ADRs

Already in this repo (README, CLAUDE.md, spec/, etc.) and in the kubeauto reference (ADR-001 through ADR-007). Phase 7 confirms they're consistent with what was actually deployed. Manual cross-check, not pytest.

## What students see on their cluster

Same components reconciling. Same ClusterIssuer-with-no-Order data. Same honest Integration scores.

## Score on the live scorecard

**Components covered:** TLS + cert-manager, Resource Quotas + PDBs, OIDC Auth (deferred), Documentation, Architecture Decision Records (4-5 of 27 depending on how Docs/ADRs count)

This is the "boring but important" phase. Cert-manager and resource quotas are infrastructure hygiene — they almost always install cleanly but their *integration* requires real DNS/secrets which AI couldn't materialize in 90 min.

**Final scorecard data:** After Phase 7's promise, total up Install + Integration + Usability across all 27 components. The closing slide reads the totals.

```
<promise>ALL_PHASES_COMPLETE</promise>
```
