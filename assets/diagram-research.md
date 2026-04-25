# Infrastructure Diagram Best Practices: Research Findings

Research compiled for KCD Texas workshop diagram improvements. Covers AWS conventions,
Kubernetes topology diagrams, Mermaid-specific techniques, ops runbook visualization,
and common anti-patterns.

---

## 1. AWS Architecture Diagram Conventions

### Official AWS Guidelines

AWS publishes an [Architecture Icons](https://aws.amazon.com/architecture/icons/) package
updated quarterly (Q1/Q2/Q3). The icon set enforces a color-by-service-category system
that has become the de facto standard for cloud diagrams industry-wide.

**Service category colors** (from AWS icon sets and brand guidelines):

| Category                    | Color    | Approximate Hex |
|-----------------------------|----------|-----------------|
| Compute                     | Orange   | `#FF9900`       |
| Storage                     | Green    | `#3F8624`       |
| Database                    | Blue     | `#2E73B8`       |
| Networking & Content Delivery | Purple | `#8C4FFF`       |
| Security, Identity & Compliance | Red  | `#DD344C`       |
| Analytics                   | Purple   | `#8C4FFF`       |
| Management & Governance     | Pink     | `#E7157B`       |
| Application Integration     | Pink     | `#E7157B`       |

**Brand colors:**
- AWS Squid Ink (dark navy): `#232F3E`
- AWS Smile Orange: `#FF9900`
- Reference architecture title color: `#E47911`
- Detail rectangle background: `#EBECEE`

Sources: [AWS Architecture Icons](https://aws.amazon.com/architecture/icons/),
[AWS Brand Color Codes](https://brandpalettes.com/amazon-web-services-logo-colors/),
[Sam Green's Style Guide for AWS Architecture Diagrams](https://medium.com/@samjackgreen/style-guide-for-aws-architecture-diagrams-6fe7c1db8a7a)

### Grouping and Layout

- **Logical grouping boxes** represent AWS Cloud, Region, VPC, Availability Zone, and
  Subnet boundaries. Only include groupings that add clarity; if everything is in one
  region, omit the region box. ([naddison.com](https://www.naddison.com/blog/2025_04_20_how_to_create_good_aws_architecture_diagrams/))
- **Public subnets** use green backgrounds; **private subnets** use blue backgrounds.
  This is a widely adopted convention even outside AWS official docs.
  ([dev.to AWS Builders](https://dev.to/aws-builders/aws-architecture-diagrams-guidelines-595d))
- **Dashed/intermittent border lines** indicate logical groupings (e.g., a cluster of
  Lambda functions representing a service).
- **Return traffic** uses dashed arrows to distinguish from request flow (solid arrows).

### Labeling

- AWS reference diagrams use exactly two font sizes: **9px** for detail text and **14px**
  for larger labels (title and subtitle excepted).
- **Numbered callouts** work well when descriptions are long -- place numbers on the
  diagram and a legend below. Short labels can go directly on arrows.
- Icons should have constrained proportions to maintain visual consistency.

### Typography

- Use a clean sans-serif font (Amazon Ember is the brand font; Arial or Inter are
  acceptable substitutes).
- Limit to 2 font sizes plus the title. More than 3 sizes creates visual noise.

---

## 2. Kubernetes Cluster Topology Diagrams

### Official Kubernetes Diagram Guide

The Kubernetes project publishes a [Diagram Guide](https://kubernetes.io/docs/contribute/style/diagram-guide/)
that recommends:

- Use **Mermaid** for diagrams in documentation (rendered natively on kubernetes.io).
- The official K8s brand color is **`#326CE5`** (Kubernetes blue). Use it for K8s
  components in diagrams.
- For SVG diagrams, convert text to paths ("Convert text to paths" in SVG editors)
  to ensure consistent rendering across systems regardless of font availability.

### What Good K8s Diagrams Show

Well-regarded sources (learnk8s, CNCF, EKS Workshop) consistently structure K8s
diagrams around these layers:

1. **Control Plane** -- API Server, etcd, Controller Manager, Scheduler
2. **Worker Nodes** -- kubelet, kube-proxy, container runtime
3. **Networking** -- Services, Ingress, CNI plugin, network policies
4. **Workloads** -- Pods, Deployments, StatefulSets, DaemonSets

**Layout conventions:**
- Control plane at the top or left; worker nodes below or to the right.
- Use container/box nesting: Cluster > Node > Pod > Container.
- Show namespace boundaries when multiple namespaces are relevant.
- Traffic flow arrows between namespaces make gaps and inconsistencies visible.

**EKS-specific conventions:**
- Show the managed control plane as a distinct AWS-managed boundary (users do not
  operate its internals).
- EKS control planes span at least 2 AZs (3 etcd nodes across 3 AZs). Show this
  distribution when HA is the topic.

Sources: [Kubernetes Diagram Guide](https://kubernetes.io/docs/contribute/style/diagram-guide/),
[Groundcover K8s Architecture](https://www.groundcover.com/learn/kubernetes/kubernetes-architecture-diagram),
[Miro K8s Architecture Guide](https://miro.com/diagramming/what-is-kubernetes-architecture/)

---

## 3. Mermaid Diagram Best Practices

### Making Mermaid Diagrams Look Professional

Mermaid's defaults produce diagrams that look "like a CS homework assignment." The
following techniques significantly improve output quality.

#### Use the `base` Theme with Custom Variables

The `base` theme is the only fully customizable theme. Override its variables via
frontmatter or `%%init%%` directive:

```
%%{init: {
  "theme": "base",
  "themeVariables": {
    "primaryColor": "#326CE5",
    "primaryTextColor": "#FFFFFF",
    "primaryBorderColor": "#1A4D8F",
    "secondaryColor": "#E8F0FE",
    "tertiaryColor": "#F5F5F5",
    "lineColor": "#555555",
    "fontFamily": "Inter, Arial, sans-serif",
    "fontSize": "14px"
  }
}}%%
```

Key variables:
- `primaryColor` -- main node fill
- `primaryBorderColor` -- derived from primaryColor if not set (darkened 10%)
- `secondaryColor` -- secondary node fill
- `lineColor` -- arrow/connector color
- `fontFamily` -- set to a clean sans-serif; avoid the default generic font
- `fontSize` -- 13-14px is a good baseline for readability

Sources: [Mermaid Theme Configuration](https://mermaid.js.org/config/theming.html),
[Gordonby/MermaidTheming](https://github.com/Gordonby/MermaidTheming),
[lukilabs/beautiful-mermaid](https://github.com/lukilabs/beautiful-mermaid)

#### Node Styling with `classDef`

Define style classes and apply them to nodes for visual categorization:

```mermaid
classDef aws fill:#FF9900,stroke:#CC7A00,color:#FFF
classDef k8s fill:#326CE5,stroke:#1A4D8F,color:#FFF
classDef user fill:#E8E8E8,stroke:#999,color:#333
```

This creates consistent visual language: orange = AWS, blue = K8s, gray = external.

#### Subgraph Limitations and Workarounds

**Known issue:** If any node inside a subgraph links to a node outside the subgraph,
the subgraph's `direction` statement is ignored and it inherits the parent graph's
direction. ([mermaid-js/mermaid#2509](https://github.com/mermaid-js/mermaid/issues/2509))

**Workaround:** Design your graph so subgraph-internal links are self-contained, or
accept the parent direction and design accordingly.

**Known issue:** Changing default node shapes globally via `classDef` does not work
reliably. ([mermaid-js/mermaid#4765](https://github.com/mermaid-js/mermaid/issues/4765))

**Workaround:** Explicitly define shapes per node using bracket syntax (`[rect]`,
`(round)`, `{diamond}`, `([stadium])`, `[[subroutine]]`, `[(cylinder)]`).

#### Layout Tips

- **`LR` (left-to-right) is generally better than `TD` (top-down)** for infrastructure
  diagrams, because it reads like a data flow pipeline. Use `TD` for hierarchical
  relationships (org charts, tree structures).
- Keep subgraphs shallow (1-2 levels of nesting). Deep nesting causes layout engine
  issues.
- Mermaid's layout engine (dagre/elk) struggles with more than ~30-40 nodes. Break
  large diagrams into multiple smaller ones.
- Use invisible links (`~~~`) to nudge node positioning when the auto-layout produces
  awkward results.
- The `beautiful-mermaid` library provides 15 built-in professional themes and renders
  100+ diagrams in under 500ms with CSS custom properties.

#### What Mermaid Cannot Do Well

- Precise manual positioning of nodes (no x/y coordinates).
- Complex overlapping or crossing-free layouts for dense graphs.
- Rich iconography (no inline images in most renderers).
- Animations or interactivity beyond basic click handlers.

For these cases, export Mermaid to SVG and refine in a vector editor, or use
purpose-built tools (draw.io, Excalidraw, Lucidchart).

Sources: [Mermaid Flowchart Syntax](https://mermaid.js.org/syntax/flowchart.html),
[Obsibrain Mermaid Guide 2026](https://www.obsibrain.com/blog/mermaid-diagram-a-complete-guide-to-diagrams-as-code-in-2026),
[Canonical Starter Pack Mermaid Guide](https://canonical-starter-pack.readthedocs-hosted.com/stable/how-to/diagrams-as-code-mermaid/)

---

## 4. Flow/Process Diagrams for Ops Runbooks

### Structure for Day-of Workflows

SRE teams and ops practitioners consistently recommend these patterns for operational
flow diagrams:

**Use a DAG (Directed Acyclic Graph) structure.** Runbooks are inherently DAGs of
actions -- visualize them that way. Linear checklists work for simple procedures;
branch into decision diamonds when conditional logic exists.
([SolarWinds Runbook Template](https://www.solarwinds.com/sre-best-practices/runbook-template))

**Key components of effective ops flow diagrams:**

1. **Prerequisites block** at the top: tools needed, access required, preliminary checks.
2. **Numbered action steps** with clear, action-first language.
3. **Decision branches** for conditional paths ("If API returns 429, wait 60s and retry
   up to 3 times").
4. **Verification checkpoints** after critical steps: "Confirm service responds 200 on
   health endpoint."
5. **Rollback/abort paths** clearly marked (distinct color or dashed lines).
6. **Completion criteria** at the bottom: how to confirm the procedure succeeded.

**Visual conventions for ops diagrams:**

| Element           | Shape/Style                        | Purpose                    |
|-------------------|------------------------------------|----------------------------|
| Action step       | Rectangle                          | Something the operator does |
| Decision point    | Diamond                            | Conditional branch          |
| Verification step | Rectangle with double border       | Confirm expected state      |
| Start/End         | Stadium/rounded rectangle          | Entry and exit points       |
| Abort/Rollback    | Red-bordered rectangle             | Failure path                |
| External system   | Dashed border                      | System outside operator control |

**Color coding for ops flow:**
- Green: success path / happy path
- Yellow/amber: warning / manual verification needed
- Red: failure / abort / rollback
- Gray: informational / context notes

Sources: [Squadcast Runbook Template](https://www.squadcast.com/sre-best-practices/runbook-template),
[Rootly Incident Response Runbooks](https://rootly.com/incident-response/runbooks),
[SRE School Runbooks Tutorial](https://sreschool.com/blog/comprehensive-tutorial-on-runbooks-in-site-reliability-engineering/),
[OneUpTime Effective Runbooks](https://oneuptime.com/blog/post/2026-02-02-effective-runbooks/view)

### Teardown Checklists Specifically

For teardown/cleanup procedures (relevant to workshop environments):

- **Reverse order of provisioning** is the default structure. Show this explicitly
  in the diagram flow.
- **Dependency awareness:** Resources that depend on others must be torn down first.
  Visualize dependencies with arrows so the order is unambiguous.
- **Verification at each step:** After deleting/stopping each resource, verify it is
  actually gone before proceeding.
- **Cost/risk callouts:** Flag steps where skipping cleanup incurs ongoing charges
  or leaves security exposure.

---

## 5. What Makes Infrastructure Diagrams Bad

### The 14 Common Anti-Patterns

Compiled from the Ilograph blog series and broader industry sources:

#### From Ilograph "7 Common Mistakes" and "7 More Common Mistakes"

1. **Unlabeled arrows.** An unlabeled arrow says "these are related" but not how.
   Always label with protocol, action, or data type.
   ([Ilograph](https://www.ilograph.com/blog/posts/diagram-mistakes/))

2. **Mixed abstraction levels.** Linking individual Lambda functions directly to
   "DynamoDB" (the service) mixes low-level and high-level resources. Pick one level
   of abstraction per diagram.

3. **Misleading composition.** Placing resources inside a boundary box implies
   containment. If Resource A is shown inside VPC B but is not actually in that VPC,
   the diagram actively lies.

4. **Ambiguous arrow direction.** Arrows should consistently represent either data flow
   or dependency direction. Mixing both in the same diagram confuses readers.

5. **Disconnected resources.** Every resource on the diagram should connect to at least
   one other resource. Orphaned boxes suggest the diagram is incomplete or the resource
   is irrelevant.

6. **Poorly labeled resources.** Labeling by type ("Lambda Function") instead of by
   name/purpose ("Order Processor") forces readers to look elsewhere for context.

7. **"Master diagrams."** Trying to show the entire system in one diagram. The result
   is always overwhelming. Break into multiple perspective-specific diagrams.
   ([Ilograph](https://www.ilograph.com/blog/posts/more-common-diagram-mistakes/))

8. **Fan traps.** When a shared intermediary (like a message broker) absorbs the
   relationship detail between producers and consumers, the specific communication
   paths are lost. Show the actual message routing, not just "everything goes through
   Kafka."

#### From Broader Industry Sources

9. **Rainbow colors.** Using a different color for every box with no semantic meaning.
   Colors must encode information (service category, environment, team ownership).
   Random colors are noise.

10. **Tiny text.** Diagrams designed at one zoom level and presented at another. Test
    readability at the size the audience will actually see it (projected on screen,
    printed on paper, embedded in a doc).

11. **No visual hierarchy.** When every element has the same size, border weight, and
    color, nothing stands out. Use size, color saturation, and border weight to
    indicate importance.

12. **Unclear flow direction.** Mixing left-to-right with top-to-bottom with
    bottom-to-top in the same diagram. Pick one primary direction and stick to it.

13. **Missing legend/key.** If the diagram uses any visual encoding (colors, line
    styles, shapes), include a legend. Do not assume the reader knows your conventions.

14. **Stale diagrams.** A diagram that does not match the current system is worse than
    no diagram, because it builds false confidence. Include a "last updated" date or
    tie diagram generation to infrastructure-as-code.

Sources: [Ilograph: 7 Common Mistakes](https://www.ilograph.com/blog/posts/diagram-mistakes/),
[Ilograph: 7 More Common Mistakes](https://www.ilograph.com/blog/posts/more-common-diagram-mistakes/),
[Ilograph: Avoid Fan Traps](https://www.ilograph.com/blog/posts/avoid-fan-traps-in-system-diagrams/),
[vFunction Architecture Diagram Guide](https://vfunction.com/blog/architecture-diagram-guide/)

---

## 6. Layout Principles Summary

### Flow Direction

| Diagram Type             | Recommended Direction | Rationale                          |
|--------------------------|----------------------|------------------------------------|
| Data/request flow        | Left-to-right (LR)  | Reads like a pipeline              |
| Hierarchy/composition    | Top-to-bottom (TD)   | Reads like an org chart            |
| Timeline/sequence        | Top-to-bottom (TD)   | Reads like a sequence of events    |
| Checklist/procedure      | Top-to-bottom (TD)   | Reads like a task list             |
| Network topology         | Left-to-right (LR)   | External -> edge -> internal       |

### Whitespace

- Generous padding inside grouping boxes (at least 20px).
- Consistent spacing between elements of the same type.
- Empty space is information -- it signals "these things are not closely related."
- Crowded diagrams signal that the diagram needs to be split, not compressed.

### Grouping

- Use nesting to show containment (VPC contains Subnets, Node contains Pods).
- Use proximity to show relationship (related services placed near each other).
- Use color to show category (all compute services the same hue).
- Maximum 3 levels of nesting before readability degrades.

### The C4 Model Principle

The [C4 Model](https://c4model.com/) recommends four zoom levels:

1. **System Context** -- the system as a black box, showing external actors.
2. **Container** -- the major runtime units (services, databases, queues).
3. **Component** -- internal structure of a single container.
4. **Code** -- class/function level (rarely needed in architecture docs).

Each level is a separate diagram. This avoids the "master diagram" anti-pattern
and ensures each diagram serves a specific audience.

Sources: [C4 Model](https://c4model.com/),
[Eugene Pavliy: Doing Proper C4 Diagrams](https://medium.com/@epavliy/doing-proper-c4-diagrams-is-easy-8cca06fdaea6)

---

## 7. Color Palette Recommendations

### For Workshop/Conference Materials

A constrained palette keeps diagrams professional and accessible:

**Primary palette (3-4 colors max for most diagrams):**

| Role                  | Hex       | Usage                                |
|-----------------------|-----------|--------------------------------------|
| K8s / Primary         | `#326CE5` | Kubernetes components, primary nodes |
| AWS / Cloud           | `#FF9900` | AWS services, cloud infrastructure   |
| Neutral / Background  | `#F5F5F5` | Grouping box fills, subgraph bg      |
| Dark text / borders   | `#232F3E` | Text, borders, arrows               |

**Extended palette (when more categories are needed):**

| Role                  | Hex       | Usage                                |
|-----------------------|-----------|--------------------------------------|
| Success / Healthy     | `#1B9E3E` | Verification steps, healthy state    |
| Warning / Attention   | `#F5A623` | Manual steps, warnings               |
| Error / Abort         | `#D13438` | Failure paths, teardown              |
| Muted secondary       | `#E8F0FE` | Secondary fills, less important nodes|
| Border / Connector    | `#555555` | Lines, arrows, subtle borders        |

**Rules of thumb:**
- Maximum 5-6 colors in any single diagram.
- Use saturation to indicate importance (saturated = primary, desaturated = secondary).
- Test for color-blind accessibility: avoid red/green as the only differentiator.
  Add shapes, patterns, or labels as redundant encoding.
- White/light backgrounds for diagrams that will be projected (dark backgrounds
  only if the presentation theme demands it).

---

## 8. Mermaid-Specific Checklist for This Project

Based on the existing `.mmd` files in this assets directory, here is a practical
checklist for making the KCD Texas diagrams professional:

- [ ] Add `%%init%%` frontmatter with custom theme variables (use the K8s blue / AWS
      orange palette above).
- [ ] Set `fontFamily` to `"Inter, Arial, sans-serif"` for clean rendering.
- [ ] Label every arrow with the action, protocol, or data it represents.
- [ ] Use `classDef` to create semantic style classes (aws, k8s, user, danger).
- [ ] Keep each diagram under 30 nodes; split if larger.
- [ ] Use stadium shapes `([text])` for start/end nodes in flowcharts.
- [ ] Use `TD` direction for checklists/teardown flows, `LR` for topology/data flows.
- [ ] Add subgraph titles that describe the boundary (e.g., "EKS Cluster", "VPC",
      "Control Plane") not just generic labels.
- [ ] Test rendering at the size the audience will see (projected slides, not a
      maximized browser window).
- [ ] After finalizing, export to SVG and convert text to paths for portable rendering.

---

## Sources

### AWS Architecture Diagrams
- [AWS Architecture Icons](https://aws.amazon.com/architecture/icons/)
- [AWS Reference Architecture Diagrams](https://aws.amazon.com/architecture/reference-architecture-diagrams/)
- [How to Create Good AWS Architecture Diagrams (naddison.com)](https://www.naddison.com/blog/2025_04_20_how_to_create_good_aws_architecture_diagrams/)
- [AWS Architecture Diagrams Guidelines (dev.to)](https://dev.to/aws-builders/aws-architecture-diagrams-guidelines-595d)
- [Style Guide for AWS Architecture Diagrams (Sam Green, Medium)](https://medium.com/@samjackgreen/style-guide-for-aws-architecture-diagrams-6fe7c1db8a7a)
- [AWS Brand Color Codes](https://brandpalettes.com/amazon-web-services-logo-colors/)

### Kubernetes Diagrams
- [Kubernetes Official Diagram Guide](https://kubernetes.io/docs/contribute/style/diagram-guide/)
- [Kubernetes Architecture Diagram (Groundcover)](https://www.groundcover.com/learn/kubernetes/kubernetes-architecture-diagram)
- [Kubernetes Architecture Diagrams Guide (Miro)](https://miro.com/diagramming/what-is-kubernetes-architecture/)

### Mermaid
- [Mermaid Theme Configuration](https://mermaid.js.org/config/theming.html)
- [Mermaid Flowchart Syntax](https://mermaid.js.org/syntax/flowchart.html)
- [beautiful-mermaid (GitHub)](https://github.com/lukilabs/beautiful-mermaid)
- [MermaidTheming (GitHub)](https://github.com/Gordonby/MermaidTheming)
- [Mermaid Diagram Guide 2026 (Obsibrain)](https://www.obsibrain.com/blog/mermaid-diagram-a-complete-guide-to-diagrams-as-code-in-2026)
- [Subgraph direction issue #2509](https://github.com/mermaid-js/mermaid/issues/2509)
- [Default node shape issue #4765](https://github.com/mermaid-js/mermaid/issues/4765)

### Ops Runbooks and Process Diagrams
- [SolarWinds Runbook Template](https://www.solarwinds.com/sre-best-practices/runbook-template)
- [Squadcast Runbook Template](https://www.squadcast.com/sre-best-practices/runbook-template)
- [SRE School Runbooks Tutorial](https://sreschool.com/blog/comprehensive-tutorial-on-runbooks-in-site-reliability-engineering/)
- [Rootly Incident Response Runbooks](https://rootly.com/incident-response/runbooks)
- [OneUpTime Effective Runbooks](https://oneuptime.com/blog/post/2026-02-02-effective-runbooks/view)

### Diagram Anti-Patterns
- [Ilograph: 7 Common Mistakes in Architecture Diagrams](https://www.ilograph.com/blog/posts/diagram-mistakes/)
- [Ilograph: 7 More Common Mistakes](https://www.ilograph.com/blog/posts/more-common-diagram-mistakes/)
- [Ilograph: Avoid Fan Traps](https://www.ilograph.com/blog/posts/avoid-fan-traps-in-system-diagrams/)
- [vFunction Architecture Diagram Guide](https://vfunction.com/blog/architecture-diagram-guide/)

### Architecture Modeling
- [C4 Model](https://c4model.com/)
- [C4 Model Diagrams](https://c4model.com/diagrams)
- [Doing Proper C4 Diagrams (Medium)](https://medium.com/@epavliy/doing-proper-c4-diagrams-is-easy-8cca06fdaea6)
