# Lab & Environment Requirements: May 2026 Speaking Engagements

**Prepared by:** Michael Forrester
**Last Updated:** April 14, 2026

---

## Event Summary

| Event | Date | Format | Duration | Lab Required? |
|---|---|---|---|---|
| SREday Austin | May 12, 2026 | Talk | 30 min | No |
| LLMday Austin | May 13, 2026 | Talk | 30 min | No |
| KCD Texas | May 15, 2026 | Workshop | 90 min (2 hr lab window) | Yes |

---

## SREday Austin — "The Day an AI Agent Deleted My Cluster"

**Format:** Presentation (no audience labs)

**Speaker requirements:**
- HDMI/USB-C projector connection
- Presenter laptop with slide deck and pre-recorded terminal sessions
- No internet dependency (all demos are pre-recorded incident footage)

**No lab environment needed.** This is a narrative talk walking through a real incident with the Eight Guardrails Framework as the resolution. All technical content is shown via slides and recordings.

---

## LLMday Austin — "Your MLOps Pipeline is your Agentic AI Guardrail"

**Format:** Presentation (no audience labs)

**Speaker requirements:**
- HDMI/USB-C projector connection
- Presenter laptop with slide deck
- Optional: pre-recorded terminal session showing guardrail hooks firing against a live agent session

**No lab environment needed.** This talk covers the same incident as SREday but reframed for an AI/ML audience with SDLC guardrail focus. Slide-driven with optional recorded demo segments.

---

## KCD Texas — "The 90-Minute IDP" Workshop

**Format:** Hands-on workshop with live audience participation
**Scheduled Duration:** 90 minutes
**Required Lab Window:** Minimum 2 hours (attendees need buffer for setup and continued exploration after session ends)

### Cluster Environment (Per Attendee)

Each participant needs access to a pre-provisioned Kubernetes lab environment.

| Resource | Specification |
|---|---|
| Kubernetes version | 1.34 (latest stable on EKS as of May 2026) |
| Cluster type | Managed Kubernetes (EKS, GKE, AKS, or equivalent) |
| Node count | 3 nodes (1 control plane, 2 workers) |
| Node sizing | Minimum 4 vCPU, 8 GB RAM per node |
| kubectl | Pre-installed and configured |
| Helm | v3.x pre-installed |
| Git | Pre-installed |
| Internet access | Required (Helm chart pulls, container image pulls) |
| Cluster lifetime | 2-hour live workshop window; up to 15 attendees retain access for ~1 additional hour after the session |
| Attendee tooling | Claude Code + kubectl + AWS CLI installed on attendee's own laptop (no web terminal) |

### Technologies Deployed During Workshop

These are installed live during the session by Claude Code. They do not need to be pre-installed, but the cluster must have enough resources to run all of them simultaneously.

| Technology | Category | Approximate Resource Footprint |
|---|---|---|
| ArgoCD | GitOps delivery | ~500 MB RAM |
| Kyverno | Policy enforcement | ~256 MB RAM |
| Prometheus (kube-prometheus-stack) | Metrics | ~1 GB RAM |
| Grafana | Dashboards | ~256 MB RAM |
| Backstage | Developer portal | ~1 GB RAM |
| Sample application | Demo workload | ~128 MB RAM |

**Total estimated footprint:** ~3.2 GB RAM across the stack, plus Kubernetes system components. The 8 GB per node spec (24 GB total) provides adequate headroom.

### Attendee Prerequisites

This workshop is hands-on for every attendee, not observe-the-presenter. Attendees should arrive with:

- A laptop with terminal access, kubectl, and the AWS CLI installed
- **Claude Code installed and authenticated** on the laptop (each attendee runs Claude Code against their own pre-provisioned EKS cluster — required, not optional)
- Familiarity with basic Kubernetes concepts (pods, deployments, services, namespaces)

### Speaker/Presenter Environment

The presenter runs a separate, identical lab environment with:
- Claude Code installed with `--dangerously-skip-permissions` flag enabled
- Pre-cloned workshop Git repository (this repo) containing the student playbook, the GitOps source under `gitops/`, and the scorecard template
- Two visible terminal windows (one for Claude Code, one for kubectl/port-forwards)
- Browser tabs pre-opened for ArgoCD (port 8080), Grafana (port 3000), Backstage (port 7007)
- Pre-recorded backup of a complete successful build run (contingency if the live demo fails or a cluster issue blocks the room)

### Workshop Git Repository

The workshop's public Git repository (this repository) contains:
- `README.md` and `CLAUDE.md` — repo overview and project context
- `kcd-tx-attendee-playbook.md` — the 90-minute student walkthrough (covers 4 most-demonstrative phases out of the spec's 7, with copy-paste prompts and verification commands)
- `scorecard/SCORECARD-TEMPLATE.md` — scorecard each student updates via `/score-component` in their Claude (Claude writes the rows; no hand-editing)
- `assets/` — Mermaid sources and rendered SVG diagrams (cluster topology, GitOps flow, access model, teardown checklist)
- Post-workshop links to the full 10-hour production build spec at [github.com/peopleforrester/kubeauto-ai-day](https://github.com/peopleforrester/kubeauto-ai-day)

### Lab Platform Notes

This workshop has been designed for pre-provisioned managed Kubernetes clusters. Any Kubernetes lab platform that meets the specifications above will work. The key requirements are:

1. **Session persistence** for at least 2 hours (attendees need time beyond the 90-minute session)
2. **Internet egress** for pulling Helm charts and container images from public registries
3. **Sufficient memory** to run the full CNCF stack simultaneously (~3.2 GB application workload + Kubernetes overhead)
4. **Web-accessible terminal** so attendees don't need to install local tools beyond a browser

### Timing Breakdown

| Segment | Duration | Lab Activity |
|---|---|---|
| Welcome + Framing | 8 min | None (slides) |
| Lab Setup | 7 min | Attendees log in, clone repo, extend timer |
| The Spec | 3 min | Show CLAUDE.md structure (slides/screen share) |
| Phase 1: ArgoCD Build | 17 min | Claude Code building live; attendees follow along |
| Phase 1: Scoring + Discussion | 10 min | Attendees evaluate their own scorecard |
| Phase 2: Kyverno Build | 15 min | Live build continues |
| Phase 3: Observability Build | 12 min | Live build continues |
| Phase 4: Backstage Build | 10 min | Live build continues |
| Scoring + Discussion | 12 min | Full scorecard review, audience comparison |
| What Replaces Implementation | 7 min | Discussion (no lab) |
| Close + Repo + QR Codes | 5 min | Attendees get takeaway links |

**Post-session:** Up to 15 attendees retain cluster access for approximately 1 additional hour to continue building independently. The remaining clusters are torn down at session end.

---

## Contact

For questions about lab provisioning or environment requirements:
Michael Forrester
github.com/peopleforester
