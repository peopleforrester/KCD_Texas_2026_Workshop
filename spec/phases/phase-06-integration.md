# Phase 6 — End-to-End Integration

**Skill:** none (cross-component, draws on all prior skills)
**Test gate:** `tests/test_phase_06_integration.py`

---

## Goal

Phases 1-5 each scored individual components. Phase 6 scores how the components work *together* — the integration surface that's often where AI-generated systems break down.

End-to-end flows verified in this phase:
1. **GitOps drift detection.** Manually edit a Deployment on the cluster; ArgoCD detects drift; auto-sync reverts within 30 seconds.
2. **Admission policy fires while metrics are scraped.** Deploy a non-compliant Pod; Kyverno blocks at admission; the rejection emits a Kubernetes Event; Prometheus picks up the event count; Grafana shows it on the platform-overview panel.
3. **Audit trail across components.** A real action (e.g., a shell exec in a Pod) shows up in: Falco rule fire → Falcosidekick → Prometheus alert metric → potential Grafana panel.
4. **Backstage discovers backend services.** The Catalog API returns at least 1 component entity from the seed/static catalog; the K8s plugin (with our empty-locator config) returns no clusters but doesn't crash the backend.

## The prompt I paste to Claude

```
Read spec/phases/phase-06-integration.md.

Phase 6 verifies cross-component behavior. Walk through the four flows:

1. GitOps drift detection
  - Edit the replicas count of an arbitrary Deployment in argocd namespace
    (e.g., argocd-redis): kubectl scale deploy/argocd-redis --replicas=2 -n argocd
  - Wait 30s, then: kubectl get deploy argocd-redis -n argocd
  - Expected: replicas reverted to 1 (ArgoCD selfHeal). Confirm via:
    kubectl get application argocd -n argocd -o jsonpath='{.status.sync.status}'

2. Admission policy with observability
  - kubectl run bad-pod --image=nginx -n apps --dry-run=server
  - Expect: denied by require-labels + require-resource-limits
  - kubectl get events -n apps --sort-by=.lastTimestamp | head -3
  - Should include FailedCreate / Forbidden events

3. Falco audit trail (only if Falco landed in Phase 3)
  - kubectl exec into any apps-ns pod with a shell:
    kubectl exec -it <pod> -n apps -- /bin/sh -c 'echo audit-test'
  - kubectl logs -n security -l app.kubernetes.io/name=falco --tail=5
  - Should show "Shell spawned in container" or similar

4. Backstage cross-cluster surface
  - kubectl port-forward -n backstage svc/backstage 7007:7007 &
  - curl -s http://localhost:7007/api/catalog/entities | jq 'length'
  - Should return >=1

Then run: pytest tests/test_phase_06_integration.py -v

When the gate passes:
<promise>PHASE_6_DONE</promise>
```

## Known failure modes

- **GitOps drift not reverted.** The Application's `syncPolicy.automated.selfHeal` is false. All our manifests have it true; if Claude generated a manifest without it, drift won't auto-revert. Manually fix and re-test.
- **No Kubernetes Events from admission denial.** Some Kyverno configurations suppress events. Workshop default emits them. If absent, check `webhooks.failurePolicy` and `policyReportPodResults` settings.
- **Falco rule doesn't fire.** Custom rule condition doesn't match the actual syscall pattern of the exec. Skill file shows the correct condition; if drift, fix in `gitops/manifests/falco-rules/` (sourced from kubeauto) and let ArgoCD reconcile.
- **Backstage Catalog empty.** `backstage-resources` Application hasn't finished syncing yet. Wait 60s and recheck.

## What students see on their cluster

Same flows. Each student can verify drift detection on their own argocd-redis. Same admission denials. Same Falco alerts (if Falco landed). Same Backstage catalog count.

## Score on the live scorecard

**Components covered:** E2E Integration (1 of 27 — though scoring this flows into all prior components' Integration dimension)

- **Install:** N/A (no new install in this phase)
- **Integration:** 7-10 if all 4 flows work; lower for each that doesn't
- **Usability:** Did integration tests produce clear pass/fail output? Could an operator interpret the logs?

This phase is the workshop's "AI didn't just install — it integrated" data point. Or, if things break, the "AI installed but the integrations don't actually work" honest counter-data.

Move to Phase 7.
