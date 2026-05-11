# Proposal: Adoption Measurement — make demand visible

**Captured**: 2026-05-11
**Shape**: Decision artifact + small-PR implementation. Decides telemetry posture (load-bearing for everything downstream), picks KPIs, builds the signal layer. ~1 week implementation once decisions land.
**Predecessors**: M027 (cost+quality observability — established the JSONL emitter + dashboard pattern this proposal extends), M013 (GitHub sidecar — same opt-in-with-explicit-toggle shape)
**Source**: 2026-05-11 zoom-out on adoption backlog. The post-launch queue is demand-driven (M040 / M034 / M009 / M010 trigger conditions all written as "ships when demand arrives"); none of those triggers are observable today outside direct conversation with the three internal dogfood projects.

## Status

**RFC capture only.** Implementation phases (P01–P03) listed below; promotion gates on telemetry-posture decision (Option A / B / C) which Brett owns.

## TL;DR

The post-launch queue assumes demand signals will arrive. They won't be visible without a measurement layer. **Demand-driven sequencing without measurement collapses to internal-dogfood-driven sequencing**, which optimizes for the three projects that talk to you most.

This proposal captures the decision space (telemetry posture) and implementation work (public-signal dashboard, optional self-report command, optional opt-in telemetry endpoint) to make adoption signals measurable.

## Why now (not demand-driven)

Same logic as `distribution-surface`: measurement is the channel through which demand signals arrive. Deferring measurement until demand justifies it is the funnel collapsed to zero. Engineering milestones get sequenced by signal; without signal, sequencing defaults to whichever dogfood project is loudest this week.

## The load-bearing decision: telemetry posture

Three options. The choice constrains everything downstream.

### Option A — Zero telemetry, public-signal only

**Tracks**: npm download counts, GitHub stars/forks/watchers, issue volume + topic clusters.

**Pros**: Trust-clean. No opt-in friction. No privacy surface to manage. Constitution-aligned (no new data leaves the user's machine).

**Cons**: Signals are lagging and noisy. Install count != active use. No per-user funnel visibility. Issue topic clustering requires manual triage labor.

### Option B — Opt-in telemetry, anonymized

**Mechanism**: `orchestrator:init` prompts: "share anonymous usage data? (recommended / declined)" with a clear `docs/data-policy.md` linked. Disabled by default unless prompt is opted in.

**Reports**: install event, first-command event, weekly active-project ping, tier distribution. Strict anonymization — **no file paths, no project names, no command arguments, no error messages**.

**Pros**: Real funnel visibility. Demand signals become measurable. Time-to-first-success becomes a tracked metric.

**Cons**: Opt-in friction at init. Requires hosted endpoint + data-flow doc + privacy story + ongoing infra maintenance. Trust risk if the implementation ever diverges from the declared policy.

### Option C — Hybrid: public signals + optional self-report

**Mechanism**: Track public signals (Option A). Provide `orchestrator:report-usage` command that emits an anonymized JSON blob users **paste into a GitHub issue or Discussion** if they choose. Zero automatic transmission; zero hosted endpoint.

**Pros**: Trust-clean (no automatic data exfiltration). Ships fast (no infra). Signal still possible from engaged users.

**Cons**: Self-report sample is biased toward engaged users — early signals overweight power users, underweight churn.

### Recommendation

**Ship C as v1; promote to B as fast-follow if C signal proves thin.**

C is the smallest viable cut and trust-clean. If after 60 days post-launch C produces fewer than ~20 self-reports, the signal is too thin and B's hosted endpoint becomes worth the cost. C → B promotion path is well-defined; B → C demotion (if telemetry gets contentious) is also well-defined.

A is too signal-poor to support the post-launch queue's demand-driven posture.

## KPIs to track (regardless of posture)

- **Install count** — npm + brew + curl-bash totals, reconciled weekly. Available in all postures.
- **Active project count** — projects that ran a command in the last 14 days. Available in B; estimable from self-report in C; unavailable in A.
- **Time-to-first-success** — minutes from install to first verifier pass. Available in B only.
- **Tier distribution** — A/B+/C ratio. Adoption skewing toward small-task entry or full-milestone? Available in B; estimable from self-report in C.
- **Runtime distribution** — `claude-code` / `codex-cli` / `cursor` split. Triggers M009 prioritization. Available in B; estimable from self-report in C.
- **Issue topic clustering** — manual GitHub triage with declared labels (`bug`, `feature-request`, `docs`, `question`, `confusion`). Available in all postures; labor cost in all postures.
- **GitHub star/fork/watcher trend** — lagging vanity metric but cheap. Available in all postures.

## Trigger conditions made measurable

The existing demand-driven proposals reference trigger conditions that are essentially unmeasurable today. With this proposal in place:

- **M040 fire** = ≥2 of {"weekly-synthesis ad-hoc count" ≥3 (issue topic cluster), "lost track of decisions" issue cluster present from non-internal consumer, M034/M038 queue-entry, "inbox-shaped friction" issue cluster ≥5}
- **M034 fire** = issue topic cluster `review-gate-friction` from a non-LakeLedger-aligned issuer
- **M009 fire** = `init.runtime != claude-code` count > 0 (Option B); or runtime field in any self-report (Option C)
- **M010 fire** = customer conversation. Hardest to make measurable; stays demand-conversation-driven.
- **wiki-ux-deep fire** = `confusion` issue cluster mentions wiki navigation ≥10

## Implementation phases

### P01 — Public-signal dashboard (~2 days, no decisions blocked)

Scrape npm + brew + GH stats into `.orchestrator/distribution/metrics-dashboard.md` weekly. Reuse M027's JSONL pattern.

Sources:
- `npm view <pkg> --json` for download counts
- `gh api repos/<owner>/<repo>` for stars/forks/watchers/issue count
- `gh api repos/<owner>/<repo>/issues?labels=...` for topic clusters

Output: weekly snapshot + 90-day rolling trend in markdown table form. Ships under all postures.

### P02 — Self-report command (~3 days, Option C only)

`orchestrator:report-usage` command:
- Scans `.orchestrator/execution-log.jsonl` for the last 30 days
- Produces anonymized JSON blob (install date, runtime, tier distribution by count, # milestones closed, # phases run, # paper-cuts)
- Pretty-prints with a copy-paste prompt: "paste this into our GitHub Discussion if you'd like to share"
- **Zero automatic transmission**; user is in full control

Privacy review: walk through the JSON blob in `docs/data-policy.md` line by line, declare what each field captures and why.

### P03 — Opt-in telemetry endpoint (conditional, ~1 week, Option B promotion)

Only ships if C signal proves thin (~20 self-reports in 60 days threshold).

Adds:
- Hosted endpoint (Cloudflare Worker or Vercel function — see #Q-1)
- `init` prompt for opt-in (see #Q-3 for phrasing)
- `docs/data-policy.md` declared policy
- `commands/telemetry.md` — `enable` / `disable` / `status` / `flush` subcommands
- Data-retention enforcement (see #Q-2)

## Out of scope

- Mixpanel / Amplitude / Segment integration (overkill at current scale; introduces third-party data flow)
- Per-user identification (anonymized only, always)
- Marketing-attribution tracking (no UTM, no referrer capture)
- Performance telemetry (separate concern; ship later if M027 surfaces insufficient)
- A/B testing infrastructure (premature)

## Open questions

- **#Q-1 hosting for telemetry endpoint (P03 only)** — Cloudflare Workers (cheap, fast, region-distributed), Vercel function (simpler deploy), custom (most control, most maintenance). Recommendation: Cloudflare Workers.
- **#Q-2 data retention** — 90 days (privacy-conservative), 1 year (allows quarterly retrospectives), indefinite (allows long-term trends). Recommendation: 90 days for raw events, indefinite for weekly aggregates.
- **#Q-3 init-prompt phrasing** — Honest framing matters. Draft: "Help improve orchestrator? Share anonymous usage data — install date, runtime, tier distribution. No file paths, no project names, no code. Off by default. ([y]es / [N]o / [w]hat's collected?)" Needs editorial pass.
- **#Q-4 dashboard publicity** — Publish dashboard publicly (transparency, builds trust) or keep internal (avoids vanity-metric culture among maintainers)? Recommendation: weekly aggregates public; raw weekly snapshot internal.
- **#Q-5 self-report bias mitigation** — How do we know C's self-report sample is representative? Recommendation: flag the bias explicitly in every dashboard view ("based on self-reports from N users; biased toward engaged users"). Honesty over polish.

## Trigger condition

Adoption-measurement fires **now**, not demand-driven. P01 (public dashboard) ships within 2 weeks of M035 close. P02 (self-report command) ships within 4 weeks. P03 (telemetry endpoint) ships conditionally at 60-day evaluation gate.

## Blast radius

- New `.orchestrator/distribution/metrics-dashboard.md` artifact + weekly refresh job
- Option C: new `commands/report-usage.md` + `scripts/diagnostics/report-usage.sh` + `docs/data-policy.md`
- Option B (conditional): new hosted endpoint, new init prompt, new `commands/telemetry.md`, expanded `docs/data-policy.md`
- No changes to existing dispatch / verify / orchestration paths
- Constitution review: does the orchestrator's "State On Disk Is Truth" principle have a telemetry corollary? Probably yes — telemetry events should also land in `.orchestrator/execution-log.jsonl` before transmission, providing the user a local audit trail of what was sent.

## Relationship to adjacent proposals

- **distribution-surface** (sibling RFC, captured same day): distribution drives signal; this proposal reads it. Pair to ship.
- **community-infrastructure** (sibling RFC, captured same day): issue volume + topic clustering is both a community-triage activity (community-infrastructure) and a measurement signal (this proposal). Triage labels declared here should align with topic-cluster needs.
- **M027** (closed): cost+quality observability is *internal* — operator sees their own cost. This proposal is *external* — maintainer sees adoption signal. Pattern reuse only; no conflict.
- **M040** (existing): M040's brief surfaces *project-internal* signals to the operator. This proposal surfaces *cross-project* signals to the maintainer. Compose; different audiences.

## Promotion path

P01 ships unconditionally as a small PR. P02 ships once Option C is decided (Brett's call). P03 evaluated at 60 days post-launch.

If telemetry becomes contentious (community pushback, principle conflict), the proposal can downshift to A (public-signal only) without losing the public-dashboard work from P01.
