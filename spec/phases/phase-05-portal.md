# Phase 5 — Developer Portal

**Skill:** `.claude/skills/backstage-templates.md`
**Ground truth:** `gitops/apps/{backstage,backstage-resources}.yaml`
**Test gate:** `tests/test_phase_05_portal.py`

---

## Goal

Backstage installed, its catalog populated, software templates registered, plugin wiring done. By end of phase the developer portal renders, the catalog has at least the seed entities, and the templates list contains at least one workshop template.

This is the most likely component to faceplant live — the Backstage Helm chart has no default image, and the upstream image's baked-in app-config initializes the Kubernetes plugin in a way that crashes the backend without a cluster-locator override. Both traps are documented in the skill file and pre-fixed in `gitops/apps/backstage.yaml`. If Claude generates an alternative manifest, the diff will be visible on the projector.

## The prompt I paste to Claude

```
Read .claude/skills/backstage-templates.md and spec/phases/phase-05-portal.md.

Phase 5 components are already reconciling from Phase 2's app-of-apps. Wait
for them to land:

  1. kubectl get pods -n backstage   (Pod Running 1/1; ~60-90s after sync)
  2. kubectl logs -n backstage -l app.kubernetes.io/name=backstage --tail=30
     (no CrashLoopBackOff; if any, surface the logs verbatim)

Port-forward and verify the catalog + templates:
  kubectl port-forward -n backstage svc/backstage 7007:7007 &
  curl -s http://localhost:7007/.backstage/health/v1/liveness
  curl -s http://localhost:7007/api/catalog/entities | python3 -c \
    "import sys,json; print(len(json.load(sys.stdin)))"

Then run: pytest tests/test_phase_05_portal.py -v

When the gate passes:
<promise>PHASE_5_DONE</promise>
```

## Known failure modes

- **`backstage.image.repository` / `tag` missing in values.** Chart has no default image. Pod fails to start. This is THE failure for this phase. Workshop ground truth pins `ghcr.io/backstage/backstage:1.30.2` — verify the diff retains it.
- **`Plugin 'kubernetes' startup failed; Kubernetes configuration is missing`** in logs (CrashLoopBackOff after 3 restarts). Upstream image's baked-in app-config initializes the K8s plugin which crashes without a cluster locator. Workshop ground truth includes `backstage.appConfig.kubernetes.clusterLocatorMethods: []` override. If Claude omits it, this is the visible failure. Live-validated on 2026-05-13.
- **`createServiceBuilder is not a function`** in logs. Wrong image — built against legacy backend. Don't try to fix live; pin to `1.30.2`.
- **`appConfig:` at values root instead of under `backstage:`.** Chart accesses `.Values.backstage.appConfig`. Root-level placement silently dropped. Watch the diff.
- **Backstage Resources Application OutOfSync.** Workshop's `backstage-resources` Application pulls from the kubeauto repo (catalog ConfigMaps, software templates). If the kubeauto staging branch is mid-update, this may sync slowly. Acceptable to score Phase 5 with backstage-resources at `Progressing`.

## Path A vs Path B

- **Path A (we have time):** Drive Phase 5 live like the previous phases. Watch the diff and the logs on the projector. If Backstage faceplants, name the failure mode and score Install accordingly.
- **Path B (we're short on time):** Skip live, play the pre-recorded Phase 5 segment from `assets/phase-04-backstage-recorded-run.mp4` (renamed for the new phase numbering — same content). Score from the recording.

## What students see on their cluster

Their Backstage reconciles from the same pre-committed manifest with the same image pin. Their port-forward brings up the same catalog. Whether the Pod actually reaches Running depends on cluster conditions; that data goes on their scorecard.

## Score on the live scorecard

**Components covered:** Backstage Install, Software Templates, Backstage Plugin Wiring (3 of 27)

- **Install:** Did Backstage Pod come up Running on first reconciliation? Was the image config correct in the manifest?
- **Integration:** Sync wave 5 firing after observability? backstage-resources providing catalog content? Is the K8s plugin initialized cleanly with the override?
- **Usability:** Can a developer find the catalog, understand the templates, ship a service Monday morning? **This score is usually low** because the workshop catalog is static-seed only. That gap is the closing slide.

Move to Phase 6 for integration testing.
