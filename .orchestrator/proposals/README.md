# Future-Milestone Proposals

Captured 2026-04-27, refreshed 2026-04-28 after a milestone-status reconciliation pass against `.orchestrator/milestone-summary.md`.

These docs are inputs for `orchestrator:specify` (and downstream `orchestrator:evaluate` / `orchestrator:roadmap`) when each milestone enters the planning queue. They are *not* themselves specs — they are briefs intended to give specify enough context to produce a tight spec without re-doing the analysis.

## Proposals

| ID | Title | Shape | Standalone? |
|---|---|---|---|
| `constitution-amendment-inclusion-criteria.md` | Inclusion-criteria gate + governance log + distribution-surface integrity | Constitution PR (~50 LOC + 1 new doc) | Yes — no milestone needed |
| `launch-sequencing-amendment-2026-05-03.md` | Risk-ranked launch sequencing: M031 → (M032 + M033 paired) → M029 → M035 P02–P06; adds friendly-tester pass on M033; M036a smoke test before pilot | Operational amendment, not a milestone | Yes — supersedes the headline-sequence line in CLAUDE.md |
| `M028-autonomous-hardening-v3.md` | Hook portability + 5 new shape classes (AP-014 `xargs-sh-c-compound-body` added 2026-04-28) + investigation-pattern wrappers (incl. `peek-files.sh`) + M025 hook-shim follow-up (bare command names, install dedup, `--repair`) | Milestone (5 phases) or 2 quick PRs | Some phases standalone |
| `M029-roadmap-visibility-and-cli-ux.md` | `orchestrator:where` tree + invocation-context resolver + headline status (embeds M027 surfaces) | Milestone (3 phases) | No — coherent feature |
| `M030-adaptive-model-selection.md` | Task-character classifier + model routing table + verifier-fail escalation; surface savings via M027 | Milestone (4 phases) or 2-3 quick PRs depending on classifier complexity | Yes — independent feature |
| `M031-right-sized-entry.md` | Knowledge + compression unconditional across all intensities; Tier A+ middle flow (research → plan → build); universal `orchestrator <task>` entry; evaluate.md drift reconciliation | Milestone (4 phases + optional P00 baseline) | No — coherent feature |
| `M032-wiki-distribution-and-init-integration.md` | Project-asset surface + wiki tooling + mkdocs/Giscus templating; `--with-<feature>` flag pattern; replaces existing unmanaged bulk-copy staging in `install-claude-code.sh:287-330` (1,157 files per consumer project today) with a managed `project_assets:` schema supporting `mode: copy\|symlink` | Milestone (3 phases + optional P00 baseline; P00 captured live during pbj-central bootstrap 2026-04-28) | No — pre-launch; M033 P05 invokes its `--with-wiki` gate |
| `M033-onboarding-experience.md` | `orchestrator:start` warm conversational front door — branches greenfield-empty / greenfield-with-materials / existing-codebase / migrating; orchestrator-native constitution authoring (zero spec-kit dep); codebase-knowledge ingestion; materials intake + drift reconciliation; greenfield ideation; CLAUDE.md custom-block authoring; integrates `--with-wiki` (M032) + `--with-github` (M013) gates | Milestone (5 phases + optional P00 baseline; P03 collapsible) | No — coherent feature; consumes M031/M032 infrastructure |
| `M034-interactive-review-gates.md` | First-class interactive-review stage between artifact authoring and SIGNOFF.md population — decision-packet schema + walkthrough consuming it; inherits `commands/comments.md` CON-5/SC-5 review-queue convention; `auto`-mode parity via `defer` / `accept-with-audit` / `block` policies | Milestone (2 phases + optional P00 lakeledger-replay baseline; P01 ships value standalone) | Post-launch — captured 2026-04-28 from lakeledger M066/P01 dogfooding |
| `M035-packaging-distribution.md` | Pre-launch dev ergonomics (P01 `--mode=symlink` install + `orchestrator:status` version-drift warning) + at-launch package-manager publishing (P02–P06: npm + homebrew + curl-pipe-bash + GH release automation + install integrity + `orchestrator:update` first-class command) | Milestone (6 phases + P00 fresh-machine baseline; P00+P01 pre-launch, P02–P06 ARE launch) | Pre-launch *and* at-launch — split scope; last milestone before launch event |
| `M036-reference-corpus-ingest.md` | New `reference/` chunk family + provenance frontmatter + 3 new edge types (`cites` / `derived_from` / `applies_to_field`) + `[source:...]` tag namespace + dispatch injection with token-budget governor; markdown floor as ingest contract; PDF/XLS adapters as stubs; wiki projection. Spec / evaluation / context / roadmap already authored 2026-04-30. | Milestone (7 phases — P00 foundation, P01/P02/P06 concurrent post-foundation, P03/P04/P05 third wave; critical path P00→P01→P02→P04 for 2026-05-15 PBJ validator pilot) | Post-launch — captured 2026-04-30 from PBJ Analyzer corpus needs; demand-driven (insert-ahead pressure if launch slips past pilot window) |
| `post-launch-wiki-ux-and-adapters.md` | Stub: knowledge graph as core; (1) wiki UX deep — code-to-title, scannable indexes, faceted search, graph chips, AI Q&A; (2) external tool adapter framework — Jira / Notion / Obsidian generalizing M013's GitHub pattern | Two demand-driven post-launch milestones | Post-launch — captured 2026-04-29 from pbj-central wiki deploy session; full briefs authored when arc enters queue |
| `gsd-2-adoption-scan-2026-05-04.md` | Scan of GSD v2.79 + v2.80; 14 adoption opportunities. Headline: `orchestrator:exec` / Context Mode primitive (subprocess-output context discipline). Plus paper-cut sweeps (`realpath` audit, description-as-trigger, prompt-cache regression test, `$HOME` write guard, M013 retry-boundary audit), M034 brief amendment (soft-warning verdict tier), delegation-policy table (constitution-adjacent), and post-launch follow-ups (lease-based locks, `--auto-chain` flag, project-shape classifier in `discuss`, spike→skill bridge) | Mixed: 1 milestone candidate + 4 paper-cut sweeps + 2 brief amendments + 4 deferred fast-follows | Mixed — see proposal §"Where each item lands" |
| `delegation-policy-table.md` | Per-tool background-safety policy: declarative GOOD/RISKY/NO table for every dispatchable orchestrator surface; default-deny on unknowns; test-pinned GOOD set. Makes Constitution Principle V (Fresh Context Per Unit) enforcement explicit instead of implicit in script structure. Sibling to constitution-amendment-inclusion-criteria; bundle into same standalone-amendment PR window | Single PR — references doc + YAML data file + lint + pin test (~1 day) | Yes — no milestone needed; bundle with constitution-amendment |
| `papercut-gsd2-scan-2026-05-04.md` | Bundled paper-cut sweep: 6 items from GSD-2 scan — `realpath` audit on state resolvers, command-description-as-trigger audit, doctor enrichment (orphan dirs / stale locks / retry exhaustion / index drift), Anthropic prompt-cache regression test, safety bundle (`$HOME` write guard / git-index-lock dispatch precondition / commit-subject sanitize / `--no-git` init audit), M013 GitHub-sync retry-boundary audit pass | Single bundled PR (~3 days); blocked on M033/P05 close | Yes — defensive hardening; blast radius scoped to file additions + targeted modifications |
| `orchestrator-exec-primitive.md` | Headline new primitive from GSD-2 scan: `orchestrator:exec` + `exec-search` + `exec-resume`. Subprocess output stays on disk (`.orchestrator/exec/`); model receives metadata + summary + search-key only. New axis of context discipline (output-side counterpart to M018's input-side compression). Manifest-lane integration (`exec_lane: capture \| stream`); M019 `exec_run` event type; M027 footer extension | Milestone-shaped (4–5 phases) | Post-launch fast-follow (provisional ID — pick from open band when slotted); demand-driven |
| `papercut-discuss-project-shape.md` | Project-shape classifier in `orchestrator:discuss` — emits `simple \| complex` verdict to the active context-draft; downstream discuss-stage invocations adapt cadence (simple = 1–2 plain-text rounds; complex = full grilling protocol with researched options). Composes with Tier A/B/C and Quick/Standard/Full axes; doesn't replace either | Single PR (~0.5–1 day) | Yes — independent post-M033 amendment |
| `papercut-m036b-deferred-state-vs-find-active.md` | M036b post-launch slice has unchecked roadmap phases (P08/P09) but is intentionally deferred until demand-signal arrives; `find-active-milestone.sh` returns `M036 planning C` and would auto-target M036b if `orchestrator:auto` is invoked without explicit `milestone=M029` during M029's pre-planning/discussing window. Recommended fix: Option A — write `M036-SUMMARY.md` for M036a's scope, drop P08/P09 roadmap entries with forward-pointing note. Workaround in the meantime: always pass `milestone=M029` explicitly. | Single PR (1–2 hours) | Yes — independent papercut, can run any time pre- or post-launch |
| `M040-ambient-feedback-loop.md` | Three cohesive surfaces — daily/weekly project brief (push, not pull), decision contradiction gate (on every `DECISIONS.md` write), frictionless capture inbox (`/orchestrator-capture`). Bundles ideas adapted from a personal-knowledge-system adoption pattern: *"a knowledge system without a return path is a graveyard with good folders."* Orchestrator's knowledge graph is rich but only fires during dispatch; M040 makes it ambient between dispatches. Composes with M034 (decision-packet shape) + M038 (brief as living-doc type) + M039 (wiki rendering surface). | Milestone-shaped (3 phases) | Post-launch — captured 2026-05-10 from README audit + ext'l knowledge-system adoption article; demand-driven |
| `papercut-doctor-knowledge-gap-surface.md` | New `doctor` check — `DOCTOR:KNOWLEDGE_GAP` — surfaces *negative space* in the knowledge graph (sections with `tasks_dispatched > 0 AND mem_count == 0`). Would have caught the M036a P03 live-LLM smoke gap + the M032 wiki readability gap at milestone-close time instead of retroactively at launch-sequencing-amendment time. ~50-100 lines of shell + one fixture test; no new commands; no schema changes. | Single PR (~0.5–1 day) | Yes — independent papercut, ships any time pre- or post-launch |
| `distribution-surface.md` | Standing workstream (not a milestone) for the marketing surface engineering doesn't own — landing page, launch announcements (Show HN / dev.to / podcasts), comparison pages (vs spec-kit / gsd / Aider+Cursor), case studies (PBJ / LakeLedger / bbt-crm), showcase wall, video demos. Weekly distribution-PR cadence; artifact source-of-truth under `.orchestrator/distribution/`. Captured 2026-05-11 from post-launch zoom-out — engineering launched 2026-05-09 with no analogous distribution event. | Standing workstream, weekly PRs | Yes — fires now, not demand-driven (distribution is the channel signal arrives through) |
| `adoption-measurement.md` | Decision artifact + ~1-week implementation that makes demand-driven sequencing measurable. Picks telemetry posture (recommend C: public signals + opt-in `orchestrator:report-usage` self-report; promote to B opt-in endpoint at 60-day gate if C signal thin). Builds public-signal dashboard, KPI definitions, trigger-condition oracles for M040/M034/M009/wiki-ux-deep. Captured 2026-05-11 — demand-driven backlog without measurement collapses to internal-dogfood-driven. | Decision + 3 implementation phases (P01 dashboard ~2d, P02 self-report ~3d, P03 conditional endpoint ~1w) | Yes — fires now, not demand-driven |
| `community-infrastructure.md` | Standing workstream (not a milestone) — CONTRIBUTING.md governance, CODE_OF_CONDUCT.md, GitHub Discussions enablement, triage SLA + label scheme, stale-issue automation, showcase submission flow, changelog-excerpt surface in `orchestrator:update`, contributor recognition. Smallest viable cut ~2 days bundled PR; larger follow-ups drip ~3 more days over 2 weeks. Captured 2026-05-11 — three-leg adoption stool with distribution + measurement. | Smallest viable cut + drip follow-ups | Yes — fires now; surface must exist before first outside contributor arrives |

## Reality check vs CLAUDE.md (2026-04-28)

`CLAUDE.md`'s "Forward Roadmap" paragraph is stale. Authoritative source is `.orchestrator/milestone-summary.md`. Several milestones listed there as "next up" or "in queue" are actually closed:

| Milestone | CLAUDE.md said | Actually |
|---|---|---|
| M014 (extended) | "next up" | Closed 2026-04-25 |
| M020 | in forward queue | Closed 2026-04-25 |
| M024 | in forward queue | Closed |
| M019 Tier 2+3 | in forward queue | Closed |
| M026 (in CLAUDE.md not yet listed) | — | Closed 2026-04-25 (Conversus-OSS Migration) |
| M027 (in CLAUDE.md not yet listed) | — | Closed 2026-04-27 (Cost+Quality Observability Surfaces) |

A separate small PR should refresh `CLAUDE.md` from `milestone-summary.md` to prevent future drift confusion. Out of scope for these proposal commits.

## Sequencing recommendation

Forward queue, after the staleness correction:

```
[constitution-amendment]    ← any time, single PR, no dependencies
M018  ← currently active (Context Compression Layer)
M028 (autonomous hardening v3)        ← stabilizes autonomous runs
M030 (adaptive model selection)       ← makes runs cheaper
M031 (right-sized entry)              ← restores knowledge promise + tightens UX
M032 (wiki distribution + init)       ← project-asset surface + `--with-<feature>` flag pattern (consumed by M033)
M033 (onboarding experience)          ← warm conversational front door; standalone constitution authoring; first-impression UX
M029 (roadmap visibility + CLI UX)    ← launch polish
M035 (packaging + distribution)       ← launch readiness; P00+P01 pre-launch dev-ergonomics, P02-P06 ARE launch event
─── launch (CC-only) ───
M009 (multi-runtime parity)           ← DEFERRED — when Codex/Cursor users arrive
M023 (design layer)                   ← DEFERRED — when UI-project users arrive
M034 (interactive review gates)       ← DEFERRED — when a 2nd consumer hits lakeledger-class friction
M010 (Managed Agents + Codex Cloud)   ← DEFERRED — aspirational, demand-driven
```

### Why M028 first (after M018 finishes)

The 7 auto-interruption screenshots from 2026-04-25/26 reveal the M021 shape guard fails-open in *consumer* projects (script path resolved via `$CLAUDE_PROJECT_DIR` lands outside the orchestrator repo). Any future autonomous-run-heavy milestone (M030's shadow mode, M023's design-agent dispatching, M009's runtime-parity audit) re-incurs the same prompt interruptions M021 already classified. Hook portability is the load-bearing fix.

The M018 close (2026-04-28) surfaced a sibling problem — Finding F in M028 — where the M025 runtime adapter emits bare command names (`orchestrator-post-verify`, `orchestrator-before-commit`) that aren't on PATH, and the merge helper has no install-side dedup so `~/.claude/settings.json` accumulates broken duplicates on every install rerun. Same hook-coexistence surface as Finding A; folded into P02. This raises M028's load-bearing-ness — its absence breaks Stop hooks even on the orchestrator's own repo, not just downstream consumers.

### Why M030 right after M028

M030 (adaptive model selection) needs M027's cost+quality observability for empirical validation — and M027 is already shipped. M030's shadow-mode validation phase needs autonomous runs to be uninterrupted (M028). Land M028 → land M030 → reap accumulated savings on every subsequent milestone (M023 design dispatching, M009 audits, M010 Managed Agents). Earlier M030 ships, more compounding savings.

### Why M031 right after M030

M031 closes a load-bearing gap — Quick intensity today skips the knowledge graph entirely (`commands/dispatch.md:21`), violating the orchestrator's core promise that every dispatch runs on knowledge-rich context. The smaller the task, the more the knowledge layer should bite, and today it's exactly inverted. M031 also adds a Tier A+ middle flow (research → plan → build, no ceremony) and a universal `orchestrator <task>` entry that lowers adoption friction for users with small tasks.

M031 composes with M030: M030 routes the dispatching agent to a cheap model; M031 ensures that cheap agent has knowledge access. Together they're the thrift-and-ergonomics pair — small tasks become both fast/cheap *and* knowledge-rich. Constitution amendment Change 5 (clarification of Principle I) lands with M031 to prevent re-derivation of the wrong "skip-to-save-tokens" logic in future work.

Earlier M031 ships, sooner adoption barrier drops. Best for launch.

### Why M032 promoted into pre-launch (revised 2026-04-28 post-M033 capture)

M032 was originally slotted as the first post-launch fast-follow, with manual bootstrap of pbj-central as P00 baseline. M033's capture changes that calculus: M033 P05 invokes M032's `--with-wiki` gate, and the launch first-impression depends on M033 producing a *complete* bootstrapped project including optional wiki. Shipping M033 without M032 means the wiki gate is a stub at launch — defeats the "first 30 minutes are warm" goal. Promoting M032 into pre-launch costs ~3-7 days but unlocks M033's full UX. P00 baseline still runs during pbj-central onboarding (now serving both M032 and M033 as paired empirical data).

### Why M033 right after M032

M033 consumes M032's `--with-<feature>` flag pattern + project-asset distribution. M033 also pairs structurally with M031: M031 makes small-task entry frictionless *post-bootstrap*; M033 makes first-time bootstrap warm *pre-task*. Together they bracket the user journey — M033 lands the user, M031 keeps them productive on small tasks. Either alone is half the adoption story.

M033's standalone-constitution-authoring (P02) is also the first content-authoring compliance test for Principle XVI (M032 was the asset-distribution test). Both ship under XVI.

### Why M029 closes pre-launch

M029 is launch-polish — `orchestrator:where` and the headline status block. It composes existing M027 cost surfaces into the work-hierarchy tree (no new infrastructure, just new rendering). It wants to ship *with* the launch experience, not before. M033's UX shifts (interactive branches, custom-block content) inform M029's `where` rendering so M033 ships first.

### Why M035 is the actual final pre-launch milestone (revised 2026-04-28)

M029 was previously framed as "the last thing pre-launch." Refreshed 2026-04-28: M035 is the actual launch-readiness milestone, with split scope. M035 P00 + P01 ship pre-launch as dev-ergonomics infrastructure (`--mode=symlink` install + `orchestrator:status` version-drift warning); they unblock multi-consumer-project freshness *today* for the small number of pre-launch dogfooders. M035 P02–P06 ARE the launch event — npm + homebrew + curl-pipe-bash publishing pipelines + GH release automation + install-script integrity + `orchestrator:update` first-class command. Until P02–P06 close, the install path is "clone + bash" (fine for early adopters, hostile for casual evaluators); once P02–P06 close, `npm install -g @spec-kit/orchestrator` (or equivalent) becomes canonical and orchestrator is broadly installable.

The roadmap gap (no explicit "ship to package managers" milestone in the prior queue) was surfaced 2026-04-28 during a roadmap-fit assessment session. M035 closes it.

### Why M009, M010, M023 all deferred post-launch (revised 2026-04-28)

Three deferrals, same logic: pre-launch dogfooding is CC-only, and these three milestones either expand the runtime story (M009 multi-runtime parity, M010 Managed Agents) or invest in capability that needs real-user signal to prioritize (M023 design layer). Building any of them pre-launch invests cycles in synthetic fixtures rather than user-driven priorities.

**M009 (multi-runtime parity audit)** — was originally a launch gate consuming `references/RUNTIME-ASSUMPTIONS.md`. M018/P07 has already seeded that registry with a compression-tier parity audit (CC / Codex CLI / Cursor byte-equality across zero-LLM tiers, plus T3 routing parity). The remaining audit work — broadening to non-compression assumptions accumulated across M013–M018 — defers until users with Codex CLI or Cursor projects actually arrive. Launch posture: CC-only with the multi-runtime claim *softened* in user-facing docs to "Claude Code today; Codex CLI / Cursor as fast-follows."

**M023 (design layer)** — high-value but the character of a fast-follow. Once real users arrive with real UI projects, M023's design-personality dispatch becomes immediately useful. Pre-launch we don't have those users.

**M010 (Managed Agents + Codex Cloud)** — net-new capability, not launch readiness. Anthropic's hosted Managed Agents runtime and Codex Cloud are aspirational backends. Demand-driven: ships when a customer-facing reason to ship it appears.

**M034 (interactive review gates)** — captured 2026-04-28 during lakeledger M066/P01 dogfooding. Operator hit a contract-defining SIGNOFF gate with 8 load-bearing decisions; static-file review surfaced 2-3 of the 8 as "hmm, do I agree?", an improvised conversational walkthrough surfaced 5-6 more because each came with concrete impact framing the artifact didn't carry. M034 codifies the walkthrough as a first-class lifecycle stage. Power-user workflow (Tier C contract-defining gates), not first-impression — slots post-launch alongside M009/M010/M023. Demand-signal-driven: ships when a second downstream consumer hits the same friction. n=1 today; defensible alternative pre-launch slot is "phase inside M031" but not recommended (grows M031's small-task scope materially).

**M032 (wiki distribution + init integration, promoted to pre-launch 2026-04-28)** — see "Why M032 promoted into pre-launch" above. M033's capture made M032 a launch-critical prerequisite rather than a fast-follow.

Cross-reference housekeeping (non-breaking):
- M030's `min_tier: novel` annotation for M023 design tasks becomes "if/when M023 ships."
- M031's Tier A+ middle flow does not depend on M023, M009, or M010.
- M029 sequencing simplifies: slots directly at end of pre-launch queue, no M009 dependency.
- The "CC-only at launch" framing should also flow into the README's Standalone Mode section in CLAUDE.md when next refreshed (currently still says "three runtimes"; that's now aspirational).

### Why constitution amendment any time

Doc-only, self-contained. The inclusion-criteria gate is forward-only (grandfathers I-XV). Cheapest, earliest land. No dependencies.

## Active-milestone safety note

M018 (Context Compression Layer) is currently executing under `orchestrator:auto` on branch `feat/m018-context-compression` (lock held). These proposal docs are isolated under `.orchestrator/proposals/` and do not touch:
- `.orchestrator/milestones/M018/**`
- `.orchestrator/orchestrator.lock`
- `.orchestrator/execution-log.jsonl`
- `knowledge/**` (M018 consolidation pass is rewriting these)
- Any file currently `M` in `git status`

The proposals can be committed at any time without affecting M018's autonomous run.

## Source material

- Session transcripts: 2026-04-27 (initial capture), 2026-04-28 (renumber + M030 add)
- Conversus reference: `~/Sites/conversus-oss` (CONSTITUTION.md, engine/cli/, docs/user-guide/)
- Auto-interruption screenshots: 7 screenshots dated 2026-04-25 to 2026-04-26 — patterns extracted into `M028-autonomous-hardening-v3.md` §3
- Existing infrastructure to extend:
  - M021 corpus (`tests/fixtures/m021-prompt-corpus.txt`), classifier (`scripts/verify/lib/shape-classifier.sh`), hook (`scripts/hooks/pre-bash-shape-guard.sh`), antipattern register (`ANTIPATTERNS.md` AP-001 through AP-009) — for M028
  - M027 cost surfaces (`scripts/diagnostics/efficiency-footer.sh`, `metrics-rollup.sh`, `scripts/dispatch/predictive-surface.sh`, `check-anomalies.sh`) — for M029 + M030
  - M013 GitHub sidecar (`.orchestrator/integrations/github.json`) — for M029
  - M019 Tier 1+2+3 JSONL emitters — for M030's routing decisions and M029's tree column
  - M020 knowledge layer (graph schema, indexer, traversal) — for M031's `--profile=quick` traversal contract
  - M024 intake (`scripts/intake/`, `commands/evaluate.md` input-shape table) — for M031's Tier A+ classifier extension and `orchestrator:do` routing
