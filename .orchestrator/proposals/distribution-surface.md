# Proposal: Distribution Surface — the launch event nobody attended

**Captured**: 2026-05-11
**Shape**: Standing workstream, not a milestone. Weekly-cadence distribution PRs producing small artifact bundles. Tracked in a new `.orchestrator/distribution/` source-of-truth directory.
**Predecessors**: M035 (closed 2026-05-09 — package-manager install paths live so demos can point at canonical install commands), M035 P07 (adoption-surface-polish — README warmth needs to land before external traffic arrives)
**Source**: 2026-05-11 zoom-out on the adoption backlog. The engineering launch shipped 2026-05-09. Nobody outside PBJ / LakeLedger / bbt-crm knows. The adoption queue optimizes for retention; distribution is uncovered.

## Status

**RFC capture only.** No implementation deferred to specify pass — this captures the thesis + scope so the gap doesn't stay invisible. Promotion path: small artifact PRs land directly (landing page, comparison pages); the larger campaign-shaped items (Show HN, podcast pitches) gate on Brett's go-no-go per artifact.

## TL;DR

Engineering launched. The install path works. There is no distribution surface. The adoption backlog (M040 / M034 / M009 / wiki-UX-deep) is *retention work* assuming a population of users; today's population is three internal dogfood projects. Without distribution, the retention work optimizes for a constituency that already exists rather than one that could.

This proposal captures the distribution surface — landing page, launch announcements, comparison pages, case studies, video demos — as a **standing workstream distinct from engineering milestones**. The cadence and shape are different from milestone work; bundling them under the milestone state machine is the wrong fit.

## Why now (not demand-driven)

Distribution is the rare workstream that **must not be demand-driven**. Demand-driven distribution means "wait for people to find you before telling them you exist," which is the funnel collapsed to zero. Engineering milestones are demand-driven because real-user signal sequences them. Distribution items are *the channel through which that signal arrives*.

The launch event already happened from an engineering standpoint. From a distribution standpoint, nothing has happened yet. The window to make the launch visible is narrow — install metrics + GitHub stars have a strong recency bias around the announcement moment.

## Scope

### 1. Landing page

Distinct from README. README is reference prose ("here's everything you can do"); landing page is marketing prose ("here's why you'd care").

Shape: single page, hero + value prop + mental model diagram + social proof + install CTA. ~300 words of copy + 1 diagram.

Hosting: GitHub Pages on a subdomain, dedicated domain (`orchestrator.dev`?), or marketing surface mirroring claude.ai's pattern. See #Q-1.

### 2. Launch announcement strategy

One-shot launch event, but reusable for v1.0 and major milestones thereafter.

Channels:
- **Show HN** — single submission, peak time (Tue/Wed 9am PT)
- **dev.to / Hashnode** — longer-form post: "We built a multi-context orchestrator. Here's what we learned."
- **/r/programming**, **/r/ClaudeAI** — link posts
- **Twitter / Bluesky** — thread with screenshots, asciinemas (handoff to M035 P07 #3)
- **Podcast pitches** — CoRecursive, Dev Tools FM, JS Party, Software Engineering Daily

### 3. Comparison pages

Strangers Google "orchestrator vs X" before installing. Today: zero results that are ours.

Pages (~800 words each):
- vs **spec-kit** (the parent project)
- vs **gsd** (the predecessor)
- vs **Aider / Continue / Cursor** (the AI-coding-tool category)
- vs **Linear + Cursor stack** (the "we glued it together" alternative)
- vs **claude-code-router / multi-agent frameworks** (the orchestration-frameworks category)

Tone decision pending (see #Q-3).

### 4. Case studies

PBJ, LakeLedger, bbt-crm are real dogfood. Their stories are the most credible adoption artifact available.

Shape per case study (~1200 words): problem framing → why orchestrator → what shipped → concrete outcomes (time saved, quality signal, friction surface). Each draft reviewed by the downstream consumer before publishing.

### 5. Showcase wall

"Who's using this" — logo grid + one-line use case per logo. Opt-in submission via PR (handoff to `community-infrastructure` proposal for the submission flow).

### 6. Video demos for sharing

Distinct from M035 P07's asciinemas (which embed in README and run silently in <30s). These are narrated longer-form artifacts:

- ~2 min YouTube-shaped "what is the orchestrator" demo
- ~5 min "watch a Tier C milestone run autonomously" demo
- Optional ~10 min "deep dive into the knowledge layer" demo

## Out of scope

- README polish (M035 P07 owns)
- Asciinemas embedded in README (M035 P07 owns)
- Conference talks / CFP submissions (deferred until v1.0)
- Paid acquisition / ad spend
- SEO optimization beyond "title + meta description on each artifact"

## Cadence — the structural decision

**Distribution is not a milestone.** A milestone is a coherent set of engineering changes that ship as a unit. Distribution is a continuous workstream:

- Landing page lands once (then iterates)
- Comparison pages drip over weeks
- Case studies land when a downstream consumer closes a noteworthy milestone
- Video demos refresh when major surfaces change (M040 ships → re-record the deep-dive)

Recommended shape: **standing workstream + small artifact PRs**. Track artifact source-of-truth in `.orchestrator/distribution/`. Published forms (landing-page HTML, video files, blog posts) live in their hosting locations (Pages, YouTube, etc.) with `.orchestrator/distribution/` holding markdown sources + metadata sidecars.

Cadence target: **one distribution PR per week** averaged across artifacts. No milestone state-machine; no `validate-milestone.sh`; no plan-phase ceremony.

## Open questions

- **#Q-1 landing page hosting** — GitHub Pages subdomain (free, fast), dedicated domain (`orchestrator.dev`, needs DNS + maintenance), or claude.ai-style standalone marketing surface (heaviest, most polished)? Recommendation: GitHub Pages on `orchestrator.github.io` initially; promote to dedicated domain when audience justifies it.
- **#Q-2 launch event timing** — Wait for `v1.0` tag, or fire on first publicly-installable `v0.9.x` tag? Recommendation: fire on `v0.9.4` once M035 P07 + this proposal's #1 (landing page) are live. Don't wait for `v1.0`; the install path is the launch gate, and it shipped.
- **#Q-3 comparison-page tone** — Direct ("here's where we win") or comparative ("here's where each tool fits")? Recommendation: comparative. Direct comparisons age poorly and invite reciprocal sniping. The orchestrator's pitch is "we fit a niche" not "we beat alternatives."
- **#Q-4 case-study consent** — Each downstream consumer reviews their case study before publishing. SLA? Recommendation: 2-week review window; ship as draft to private wiki if consumer hasn't reviewed by then.
- **#Q-5 showcase opt-in** — Explicit ask each project, or implicit-from-public-repo-list? Recommendation: explicit always. Consent matters; orchestrator's reputation lives downstream of how we treat consumer trust.

## Blast radius

- New `.orchestrator/distribution/` directory (artifact source-of-truth)
- New `site/` or external hosting (per #Q-1)
- No changes to existing engineering surface
- No changes to dispatch / verify / orchestration paths
- Possible new top-level `marketing/` or `site/` directory depending on landing-page hosting choice

## Relationship to adjacent proposals

- **M035 P07** (adoption-surface-polish): P07 polishes the README + asciinemas (first-impression). This proposal builds the surface *beyond* the README (strangers who haven't clicked into the repo yet). Parallel, not blocking. Asciinemas from P07 are embeddable assets for this proposal's social-media work.
- **adoption-measurement** (sibling RFC, captured same day): without measurement, distribution work optimizes for vanity metrics (stars, downloads) rather than retention. Pair to ship — measurement reads what distribution drives.
- **community-infrastructure** (sibling RFC, captured same day): distribution drives traffic, community holds the audience. Three-leg adoption stool. The showcase-wall submission flow handoffs to community.
- **post-launch-wiki-ux-and-adapters** (existing proposal): wiki UX deep is *internal* user-facing polish; this proposal is *external* first-impression polish. Compose, don't conflict.

## Promotion path

This proposal is not a milestone candidate. Promotion is per-artifact:

1. Landing page → directly land as a PR when copy + hosting decided (#Q-1, #Q-2)
2. Comparison pages → individual PRs, ~one per week
3. Case studies → land as downstream consumer reviews complete
4. Launch posts → single coordinated push when #1 lands and v0.9.4 tagged
5. Video demos → land when M035 P07 asciinemas are finalized (reuse the recording setup)

If distribution work shows it warrants milestone-grain ceremony (e.g., a coordinated marketing-campaign milestone for v1.0), revisit then.
