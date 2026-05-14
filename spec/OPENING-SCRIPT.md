# Opening Script — "The 90-Minute IDP"

Two pieces here: the **60-second slide-1 opener** that bridges the abstract to what we're actually doing, and the **5-minute pre-build framing** that sets up the methodology + the scorecard before the first `kubectl` command.

---

## The 60-second opener (slide 1)

Read this approximately verbatim. ~165 words, ~70 seconds at conversational pace.

> The abstract for this talk says I've already built this IDP end-to-end with Claude Code — ArgoCD, Kyverno, Falco, OpenTelemetry, Backstage, the whole stack. That's true. It's at `github.com/peopleforrester/kubeauto-ai-day`. Seven phases, twenty-seven components, about ten hours over one overnight session. Scored on three dimensions: Install, Integration, Usability. Go read the scorecard.
>
> We're **not** redoing that today. Sixty of us in 90 minutes can't replicate a ten-hour build — that's not the point.
>
> What we *are* doing is teaching the methodology I used to build it. **Spec-driven development with Claude Code.** I write a spec. I hand it to Claude. Claude generates the platform. I verify with test gates. I score what Claude did. I move on.
>
> Today I drive Claude live on this projector, building a piece of the same IDP — real CNCF projects, ArgoCD, Kyverno, Prometheus, Backstage. You build alongside me on your own EKS cluster, with your own Claude Code, with the credentials you got from the landing page when you walked in.
>
> How far we get is how far we get. The live scorecard tells you where AI saved toil and where it just shifted it.
>
> Implementation layer is supposedly disappearing. Let's see what's left.

---

## The 5-minute pre-build framing (slides 2–4)

After the opener, before any prompts get pasted. Three quick slides.

### Slide 2 — "What spec-driven development with Claude actually is"

> Three artifacts make this work. Show them on the slide.
>
> 1. **The spec** — `spec/BUILD-SPEC.md`. What I want Claude to build. Phases, target manifests, completion criteria. Plain Markdown. ~90 lines. I'll show it to you in a second.
> 2. **The skills** — `.claude/skills/*.md`. Current-version patterns Claude needs in order to not generate something deprecated or wrong. One per CNCF project — argocd-patterns.md, kyverno-policies.md, kube-prometheus-stack.md, backstage-templates.md. Claude Code auto-loads these when I run `claude` from the repo root.
> 3. **The test gates** — kubectl commands that prove a phase actually worked. Not pytest, not Cypress, not synthetic tests — just `kubectl get pods`, `kubectl run`, `curl localhost:7007`. The boring kind. The reliable kind.
>
> That's it. Spec + skills + gates. Plus a scorecard. Same pattern you can use on Monday for whatever you're trying to build.

### Slide 3 — "The scorecard, three dimensions"

> Every component gets scored on three things — independently.
>
> - **Install** — did Claude generate a manifest that, after applying, brought the component up healthy? First try, no rewrites? That's a 10. Three correction cycles, image registry workaround, manual chart-version archaeology? That's a 4.
> - **Integration** — does it work *with* the other components? Sync waves right, webhooks scoped right, Grafana actually scraping ArgoCD, Backstage actually reachable? A 10 here is rare. AI is good at install; integration is where humans still earn their salary.
> - **Usability** — could a developer on your team drive this on Monday morning? Clear UI, sensible defaults, the right things are discoverable? Or is it installed-but-useless?
>
> Plus correction cycles (count) and AI wall-clock time (minutes). Scoring honestly is the entire point. Inflated scores undermine the data; the variance between phases is the talk.
>
> The scorecard fills in real-time on the right half of the projector while my terminal runs on the left. You score your own on the card we gave you with your connection info.

### Slide 4 — "Today's scope, honestly"

> Seven phases, 27 components, in order. We do them until we run out of time. Phase 2 is the only "build" phase — it fans out to all 21 platform Applications in parallel. The other phases are score-and-narrate.
>
> 1. **Foundation** — assert the cluster you got is healthy. ~30 seconds.
> 2. **GitOps Bootstrap** — Helm-install ArgoCD, apply app-of-apps. ArgoCD then reconciles 21 Applications in sync-wave order. ~5 minutes wall-time for everything to reach Healthy.
> 3. **Security Stack** — Kyverno + 3 policies, Falco + custom rules + Falcosidekick + FalcoTalon auto-response, ESO, RBAC, NetworkPolicies. We watch admission deny a bad pod live.
> 4. **Observability** — Prometheus + Grafana + OTel + Loki + Promtail + Tempo + ArgoCD ServiceMonitors. We port-forward Grafana on the projector.
> 5. **Developer Portal** — Backstage. Most likely to faceplant. If we run out of time before we get here, I'll play a pre-recorded run during the closing five minutes — that's the "AI Ate My Implementation" moment from the talk title.
> 6. **End-to-End Integration** — drift detection, admission events, audit trail across components.
> 7. **Hardening** — cert-manager + ClusterIssuers, ResourceQuotas, PDBs.
>
> If we land Phase 2, you've watched 21 components install themselves via GitOps in parallel and you've got real scorecard data. If we land all seven, you've watched AI eat most of an IDP. Both are wins. We're not running this clock to "complete." We're running it to *demonstrate*.

---

## After slide 4

Switch to terminal. The first thing on screen is `cat spec/BUILD-SPEC.md` so the audience sees the artifact they just heard about. Then:

> "I'm going to paste this spec into Claude in a second. Before I do that — open your laptops. The three setup commands from your landing-page card: `aws configure`, `aws eks update-kubeconfig`, `kubectl get nodes`. If `kubectl get nodes` doesn't show three Ready nodes, raise your hand now — there are no TAs today, just me, so the setup window is the only time I can help individuals. I'd rather start two minutes late with everyone connected than on time with a third of the room behind."

Pause 3–5 minutes for stragglers. Walk between the rows. Hand spare-cluster credentials to anyone whose setup doesn't land. Then begin Phase 1.

---

## Closing script (last 5 minutes)

For when the clock runs short and you need to wrap. Read this approximately verbatim — ~140 words, ~60 seconds.

> Here's where we are. (Point at the live scorecard.) We did N phases in 75 minutes. Average Install: X. Average Integration: Y. Average Usability: Z.
>
> Look at those three numbers. They don't move together. AI installed things fine. AI struggled with integration. AI was worst at usability. That's the pattern — and it's the same pattern I saw in the overnight build at kubeauto-ai-day, just scaled down.
>
> The implementation layer didn't disappear. It compressed. AI handles the YAML and Helm values faster than I can. What's left is sync wave ordering, namespace exclusions, policy collisions, image config that doesn't match the chart, and the judgment calls that turn a pile of CNCF tools into a platform someone can actually use Monday morning. That's the engineering work that didn't go anywhere.
>
> Your scorecard goes home with you. The methodology — spec, skills, gates, three dimensions, honest scoring — goes home with you. The platform doesn't. We're tearing down the clusters in an hour. Thanks for being part of this.

QR codes: workshop repo, kubeauto reference, agentic-covenants framework, scorecard submission link.

---

## Performance notes for rehearsal

- The opener is the hardest 60 seconds of the workshop. Practice it standalone, out loud, three times before the day. The bridge from "I built this end-to-end" to "we're not redoing that" is the rhetorical pivot that buys you scope honesty without undermining authority.
- The scorecard slide is more important than it looks. If the audience doesn't understand the three dimensions in 90 seconds, they can't follow the scoring narrative for the next hour. Use real examples from kubeauto — "ArgoCD installed in 4 minutes, Integration was a 9, Backstage Install was a 7 because I had to swap the image."
- "How far we get is how far we get" — say this **out loud, explicitly, at least three times** during the workshop. Once in the opener, once after Phase 1 lands, once if Phase 3 starts running long. Audiences in a 90-minute room start internally panicking about completion. Naming the non-completion model out loud frees them.
- For the closing: don't read scores you don't actually have. If Phase 3 didn't finish, don't make up a kube-prometheus-stack score. Say "we didn't get to Phase 3 today — here's what the kubeauto reference scored for it." Honest wins.
