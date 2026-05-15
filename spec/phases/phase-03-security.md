# Phase 3 — Security Stack

**Skills:** `.claude/skills/kyverno-policies.md`, `.claude/skills/falco-rules.md`
**Ground truth:** `gitops/apps/{kyverno,kyverno-policies,falco,falcosidekick,external-secrets,eso-resources,rbac,network-policies}.yaml`
**Test gate:** `tests/test_phase_03_security.py`

---

## Goal

Phase 2 already kicked off reconciliation of the Phase 3 components. Phase 3's job is to wait for them to land and verify:
- Kyverno admission controller running, 3 ClusterPolicies enforcing, bad pods rejected
- Falco DaemonSet on every node with custom eBPF rules
- Falcosidekick forwarding alerts to Prometheus
- External Secrets Operator pod Running (Integration scores low because IRSA isn't wired in the Accenture context — that's the honest data)
- RBAC ClusterRoles + RoleBindings applied
- NetworkPolicies in `apps` namespace (default-deny + scoped allows)

## The prompt I paste to Claude

```
Read .claude/skills/kyverno-policies.md and .claude/skills/falco-rules.md
and spec/phases/phase-03-security.md.

Phase 3 components are already reconciling from Phase 2's app-of-apps. Wait
for them to reach Healthy, then verify:

  1. kubectl get pods -n kyverno    (4 controllers Running)
  2. kubectl get clusterpolicies    (3 policies Ready, Enforce mode)
  3. kubectl get pods -n security   (Falco DaemonSet + Falcosidekick)
  4. kubectl get pods -n platform   (External Secrets Operator)
  5. kubectl get networkpolicies -n apps  (default-deny + allows)

Manual admission test — bad pod must be rejected:
  kubectl run test-bad --image=nginx -n apps --restart=Never --dry-run=server
  (expect: denied by require-labels AND require-resource-limits)

Manual Falco test — exec into a pod must trigger an alert:
  kubectl exec -it <any pod in apps> -- /bin/sh -c 'echo test'
  kubectl logs -n security -l app.kubernetes.io/name=falco --tail=10 \
    | grep -i 'shell spawned'

Then run: pytest tests/test_phase_03_security.py -v

When the gate passes:
<promise>PHASE_3_DONE</promise>
```

## Cluster-aware ESO configuration

Read `.cluster-type` (written by Phase 1). The ExternalSecrets Operator itself installs identically on both environments. The **backend store** differs:

### IF `CLUSTER_TYPE=eks`
- The shipped `gitops/apps/eso-resources` applies as-is:
  - `ClusterSecretStore` of `provider.aws.service: SecretsManager`, region `us-east-2`
  - Auth via Pod Identity (the operator's ServiceAccount maps to an IAM role through the `eks.amazonaws.com/role-arn` annotation)
  - Secret material lives in AWS Secrets Manager outside the cluster
- Expected on workshop clusters where IRSA isn't pre-wired: `ClusterSecretStore` reports `Ready=False` with `InvalidIdentityToken: No OpenIDConnect provider found in your account`. **This is honest scorecard data, not a workshop bug.** Install passes (Pod Running), Integration scores ~2/10.

### IF `CLUSTER_TYPE=kubeadm`
- Generate a Kubernetes-backend variant locally to `~/my-eso-resources.yaml` and apply it (do NOT push to gitops/):
  - `ClusterSecretStore` (or namespaced `SecretStore`) of `provider.kubernetes`
  - No cloud auth required — ESO reads from a regular Kubernetes Secret in the `platform` namespace
  - Pre-create the source Secret manually as part of the demo (`kubectl create secret generic workshop-source -n platform --from-literal=...`)
- Expected: `SecretStore Ready=True`, `ExternalSecret SecretSynced=True`, target Secret materializes in the consuming namespace. **Full end-to-end ESO flow works** — kubeadm path scores higher on Integration than EKS does, because the local-Kubernetes backend has no missing IRSA prereq.

### Why both are valid workshop runs

ESO's value proposition is "decouple where secrets live from who consumes them." That's demonstrated on both paths — just with a different backend store. The kubeadm path proves the *pattern* end-to-end; the EKS path proves the *production-shape* up to the IRSA gap. The scorecard divergence is the talk's central A/B.

Read `.claude/skills/cluster-environments.md` for the full side-by-side.

## Cluster-aware cert-manager configuration

cert-manager itself is Phase 7's concern. See `spec/phases/phase-07-hardening.md` for the EKS-vs-kubeadm ClusterIssuer branching (ACME/Route53 on EKS, self-signed on kubeadm).

## Known failure modes

## Known failure modes

- **Kyverno controllers `CrashLoopBackOff`.** Usually the webhook fails to register because the chart's `webhooks.namespaceSelector` was generated as a list-of-lists instead of a map. Skill file lists the correct shape.
- **`kyverno-policies` OutOfSync forever.** Kyverno's admission webhook injects 4 default fields into every ClusterPolicy. Fixed by `ignoreDifferences` on the kyverno-policies Application (see gitops/apps/kyverno-policies.yaml). Without it, the Phase 3 gate's "all Synced" assertion fails.
- **Falco fails to load eBPF driver.** EKS nodes need a recent enough kernel. Workshop uses Bottlerocket/AL2023 which works; older AMIs may need a different driver. Skill file pins `modern_ebpf`.
- **Falco custom rules don't fire on `kubectl exec`.** Common cause: rule's `condition` filter excludes the process tree. Skill file shows the correct `proc.pname in (runc:[2:INIT], cri-o, containerd-shim)` filter.
- **ESO Pod Running but ExternalSecret status `SecretSyncError`.** Expected on Accenture: the `eks.amazonaws.com/role-arn` annotation in `gitops/apps/external-secrets.yaml` is a `PLACEHOLDER` because there's no IRSA role provisioned. Score Install 8 (ESO Pod healthy), Integration 2 (can't actually pull secrets). This is exactly the kind of variance the workshop is built to expose.
- **FalcoTalon spams `namespaces "falco" not found`.** Talon's leader-election controller hardcodes the `falco` namespace for its coordination Lease, even though the Pods themselves run in `security`. The workshop creates an empty `falco` namespace specifically to hold this Lease (see `gitops/manifests/namespaces/namespaces.yaml`). If you see this error after the workshop spec applies cleanly, the namespaces Application didn't sync — check `kubectl get application namespaces -n argocd`. Discovered during live validation on 2026-05-14.

## What students see on their cluster

Same set of pods, same rejection messages, same Falco alerts. ESO will fail the same way (no IRSA on Accenture clusters in general).

## Score on the live scorecard

**Components covered:** Kyverno Install, Kyverno Policies, Kyverno Policy Interactions, Falco Install, Falco Custom Rules, ESO + Secrets Manager, RBAC, NetworkPolicies (8 of 27 — the biggest single phase)

This phase is where the workshop's central thesis lives: AI installed all 8 components, but the *Integration* score depends on infrastructure prerequisites (IRSA roles, cluster CNI capabilities) that AI couldn't provision in 90 min. Phase 3 produces the largest Install-Integration variance — narrate this on the projector as it happens.

Move to Phase 4 once the security stack is Healthy.
