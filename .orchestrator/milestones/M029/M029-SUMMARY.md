---
schema_version: "1.0"
type: milestone-summary
id: "M029"
parent: "037-roadmap-visibility-cli-ux"
milestone: "M029"
provides:
  - "M029 (roadmap visibility & CLI UX) closes the orchestrator's invocation-context + tree-rendering + auto-chain onboarding surfaces. P01 foundation: scripts/state/detect-invocation-context.sh AD-1 single-resolve env block + references/status-headline-shape.md FR-2 + references/status-json-schema.md FR-3 + commands/status.md headline block + scripts/diagnostics/render-status-json.sh AD-2 unconditional ANSI strip + commands/context.md FR-4 read-only single-screen runtime profile skill. P02 at-rest tree: scripts/diagnostics/render-position.sh ~470-line tree renderer engine FR-5 four-glyph alphabet + commands/where.md skill + references/cross-milestone-feature-shape.md AD-6 contract + scripts/diagnostics/summarize-milestone.sh AD-4 SC-8 oracle wrapper + SC-5/6/13/14 fixtures + AD-9 sentinel-file mechanism + FR-6 silent pre-M019 cost-column suppression. P03 live + preflight + auto-chain: --live branch on render-position.sh FR-7 + #Q-G9 p95 ≤ 1.0s methodology via measure-live-tail-latency.sh three-tier nanosecond-clock portability shim + ▽ saved Nk canonical compact-form FR-8 #Q-G8 gated by AD-5 display_thresholds.compression_savings_pct config knob + commands/auto.md ## Preflight Summary FR-9 AD-3 four-priority non-interactive policy AD-4 oracle wrapper + commands/start.md --auto-chain flag + scripts/lifecycle/start.sh chain-driver passthrough FR-10 #Q-3 leave-marker-absent failure semantics AUTO_CHAIN_STAGE_STUB fixture-only escape hatch + SC-7/8/9/10 fixtures + AD-4 Spec Amendment Record on specs/037-roadmap-visibility-cli-ux/spec.md + SC-11 milestone-grain run-acceptance-battery.sh BATTERY: pass=14 fail=0 + SC-12 validate-milestone-pass.sh VALIDATE: PASS hook + closure ceremony M029-VALIDATED + M029-SUMMARY.md + milestone-grain unit_close JSONL record. Three phases all green; acceptance battery pass=14 fail=0; validate-milestone.sh M029 reports VALIDATE: PASS — 101/101 checks passed."
requires:
  - "M013, M018, M019, M020, M027, M032, M033"
affects:
  - "M035 (consumes --format=json schema); external-tool-adapters (post-launch — GitHub/Trello/Notion/Linear projection); M036b (post-launch wiki projection + scale UX)"
key_files:
  - "scripts/state/detect-invocation-context.sh,scripts/diagnostics/render-position.sh,scripts/diagnostics/render-status-json.sh,scripts/diagnostics/summarize-milestone.sh,scripts/lifecycle/start.sh,scripts/state/read-config.sh,commands/where.md,commands/context.md,commands/status.md,commands/auto.md,commands/start.md,references/status-headline-shape.md,references/status-json-schema.md,references/cross-milestone-feature-shape.md,references/file-formats.md,templates/orchestrator-config-default.yml,specs/037-roadmap-visibility-cli-ux/spec.md,tests/m029-acceptance/run-acceptance-battery.sh,tests/m029-acceptance/p01-acceptance-battery.sh,tests/m029-acceptance/p02-acceptance-battery.sh,tests/m029-acceptance/p03-acceptance-battery.sh,tests/m029-acceptance/measure-live-tail-latency.sh,tests/m029-acceptance/sentinel-harness.sh,tests/m029-acceptance/timestamp-strip.sh,tests/m029-acceptance/fixtures/,tools/verify/m029-p01-phase-suite.sh,tools/verify/m029-p02-phase-suite.sh,tools/verify/m029-p03-phase-suite.sh,tools/verify/m029-p03-run-acceptance-battery-shape.sh,tools/verify/m029-p03-validate-milestone-pass.sh,tools/verify/m029-p03-closure-ceremony-shape.sh,.orchestrator/milestones/M029/M029-VALIDATED,.orchestrator/milestones/M029/M029-SUMMARY.md,.orchestrator/milestones/M029/execution-log.jsonl"
key_decisions:
  - "AD-1 single-resolve invocation context (TTY/CI/runtime/non_interactive resolved once via detect-invocation-context.sh three-line env block); AD-2 unconditional ANSI strip in JSON sections (render-status-json.sh single ANSI-strip site); AD-3 four-priority non-interactive policy (auto_proceed:true default + --no-confirm override + standard/full intensity gate + leave-marker-absent failure semantics); AD-4 SC-8 oracle wrapper amendment (predictive-surface.sh → summarize-milestone.sh per CON-3 knowledge-layer-boundary; M029 owns its own helper; Spec Amendment Record entry on specs/037-roadmap-visibility-cli-ux/spec.md); AD-5 display_thresholds.compression_savings_pct:5.0 heuristic-default + FR-8 review trigger (re-evaluate post-10-milestone median savings ≥ 3%); AD-6 cross-milestone milestones: frontmatter list + reverse-lookup advisory; AD-7 schema_version:1.0 from day 1; AD-8 knowledge-layer-boundary discipline (no M020 schema change; unit_close consumes existing M019 emitter); AD-9 sentinel-file mechanism for SC-14; scope tightening 2026-05-05 (cut FR-11 GitHub fold-in + FR-12 --refresh-github; defer to demand-driven post-launch external-tool-adapters); #Q-1 full-re-render; #Q-3 leave-marker-absent failure semantics; #Q-5 collapsed-by-default + --expand-all + active-always-expanded; #Q-G8 canonical compact-form ▽ saved Nk invariant; #Q-G9 p95 ≤ 1.0s live-tail latency methodology; CON-1/FR-14 read-only with documented closure-ceremony write sites; CON-3 silent FR-6 cost-column suppression; CON-4/FR-11 no-GitHub-API anti-coupling; CON-7/AD-8 read-only-consumer discipline; AD-19 straight-line bash; MEM001 Bash 3.2 compatibility; MEM004 carve-out for awk/sed/grep pipes inside renderer body"
patterns_established:
  - "Renderer-engine + LLM-instruction-skill split (P01 commands/context.md + render-status-json.sh extended verbatim to P02 commands/where.md + render-position.sh); Principle-III paired design contract gate verifier shape (P01 headline-shape-contract + json-schema-contract extended to P02 cross-milestone-shape-contract); AD-19 straight-line bash with separate grep -F invocation per assertion; negative-assertion verifier discipline; AD-1 single-resolve discipline; AD-6 frontmatter parsing via two awk helpers; #Q-G8 canonical compact-form ▽ saved Nk invariant extended from P02 to P03; verifier-contract-over-verifier-skeleton + in-flight-repair (M032 lineage extended — write-summary.sh emits record_type:unit_close not plan-stated event:unit_close; P01-SUMMARY directory references repaired with trailing-slash convention); three-tier nanosecond-clock portability shim; AUTO_CHAIN_STAGE_STUB fixture-only escape hatch; contract-surface assertion model for skill-documented surfaces; four-key fixed-order summarize-milestone output as AD-4 SC-8 oracle interface; milestone-grain run-acceptance-battery.sh chains per-phase batteries + emits BATTERY: pass=N fail=M canonical line + invokes SC-12 validator hook with mid-author WARN: skip branch; display_thresholds: top-level config block convention"
drill_down_paths:
  - ".orchestrator/milestones/M029/phases/P01/P01-SUMMARY.md,.orchestrator/milestones/M029/phases/P02/P02-SUMMARY.md,.orchestrator/milestones/M029/phases/P03/P03-SUMMARY.md,.orchestrator/milestones/M029/M029-CONTEXT.md,.orchestrator/milestones/M029/M029-EVALUATION.md,.orchestrator/milestones/M029/M029-ROADMAP.md,specs/037-roadmap-visibility-cli-ux/spec.md"
duration: "525m"
verification_result: "pass"
completed_at: "2026-05-06T05:05:50Z"
observability_surfaces:
  - "orchestrator:where; orchestrator:status (FR-2 headline block + FR-3 --format=json); orchestrator:context; orchestrator:auto preflight (FR-9 ## Preflight Summary block); orchestrator:start --auto-chain; ▽ saved Nk savings marker; BATTERY: pass=14 fail=0; VALIDATE: PASS — N/N checks passed; milestone-grain unit_close JSONL record"
---

M029 (roadmap visibility & CLI UX) closes the orchestrator's invocation-context + tree-rendering + auto-chain onboarding surfaces — three phases, 14 SCs, full acceptance battery PASS, all phase-suites green, validate-milestone.sh M029 reports VALIDATE: PASS — 101/101 checks passed. Scope tightened 2026-05-05 to wiki-is-the-view (FR-11 GitHub fold-in line + FR-12 --refresh-github both cut from v1; deferred to demand-driven post-launch external-tool-adapters).

**Three phases, all green** (P01–P03, ~525m total wall clock when summed across phase summaries; every phase verification_result=pass; acceptance battery `pass=14 fail=0`).

## Phase Rollup

- **P01 (foundation)** — `scripts/state/detect-invocation-context.sh` (AD-1 single-resolve env block: TTY / CI / runtime / non_interactive); `references/status-headline-shape.md` + `references/status-json-schema.md` (Principle-III paired design contracts; AD-7 `schema_version: "1.0"` from day 1); `commands/status.md` headline block additive (FR-2 — five fields, three-line packing, SC-2 regex); `commands/status.md --format=json` wiring + `scripts/diagnostics/render-status-json.sh` (FR-3, AD-2 unconditional ANSI strip, degraded-state envelope on corrupt JSONL); `commands/context.md` read-only single-screen runtime profile skill (FR-4). Six tasks, fourteen-gate phase suite PASS at close-time.

- **P02 (at-rest tree)** — `scripts/diagnostics/render-position.sh` at-rest tree renderer engine (~470 lines; FR-5 four-glyph alphabet `✓ ▶ ◇ ✗` over feature → milestone → phase → task; per-row cost column gated by FR-6 `dispatch_usage` detection probe under CON-3 silent suppression for pre-M019 milestones); `commands/where.md` 10-section LLM-instruction skill (renderer-engine + skill split); `references/cross-milestone-feature-shape.md` AD-6 contract (exactly-one-of `milestone:` singular vs `milestones:` list + reverse-lookup advisory); `scripts/diagnostics/summarize-milestone.sh` AD-4 SC-8 oracle wrapper (sourceable + CLI dual-shape per MEM004; fixed-order four-key block `phase_count` / `phases_complete` / `tasks_remaining` / `intensity`); SC-5 / SC-6 / SC-13 / SC-14 fixtures + acceptance + AD-9 sentinel-file mechanism; `commands/where.md` declares CON-1/FR-14 read-only + CON-4/FR-11 no-GitHub-API. Five tasks, thirteen-gate phase suite PASS.

- **P03 (live + preflight + auto-chain)** — `--live` branch on `render-position.sh` (FR-7, #Q-1 full-re-render on every appended `dispatch_usage` record, #Q-G9 `p95 ≤ 1.0s` measurement methodology via `measure-live-tail-latency.sh` with three-tier nanosecond-clock portability shim); canonical compact-form `▽ saved Nk` marker (FR-8, #Q-G8 — verbose-suffix forms forbidden) gated by AD-5 `display_thresholds.compression_savings_pct: 5.0` config knob (templates/orchestrator-config-default.yml + scripts/state/read-config.sh VALID_KEYS extension + references/file-formats.md docs + FR-8 review trigger); `commands/auto.md ## Preflight Summary` section (FR-9, AD-3 four-priority non-interactive policy, AD-4 oracle wrapper); `commands/start.md --auto-chain` flag + `scripts/lifecycle/start.sh` chain-driver passthrough (FR-10, #Q-3 leave-marker-absent failure semantics, AUTO_CHAIN_STAGE_STUB fixture-only escape hatch); `tests/m029-acceptance/measure-live-tail-latency.sh` harness; SC-7 / SC-8 / SC-9 / SC-10 fixtures + acceptance scripts; AD-4 Spec Amendment Record entry on `specs/037-roadmap-visibility-cli-ux/spec.md`; SC-11 milestone-grain `run-acceptance-battery.sh` chaining all three per-phase batteries + emitting `BATTERY: pass=14 fail=0`; SC-12 `m029-p03-validate-milestone-pass.sh` hook asserting `validate-milestone.sh M029 VALIDATE: PASS` exit 0; closure ceremony (this `M029-SUMMARY.md` + `M029-VALIDATED` marker + milestone-grain `unit_close` JSONL record auto-emitted by `write-summary.sh milestone`). Six tasks, thirteen-gate phase suite PASS at close-time.

## Cross-Phase Inheritance (Patterns Repeated Verbatim — Effectively M029-Stable Utilities)

- **Renderer-engine + LLM-instruction-skill split** — Established at P01 (`commands/context.md` skill + render-status-json.sh engine), extended verbatim to P02 (`commands/where.md` skill + render-position.sh engine). Production rendering happens in the engine; the skill instructs the agent to invoke the engine and pass output through unchanged. The contract-surface assertion model from P03 is the natural extension to skill-only surfaces (auto.md preflight + start.md --auto-chain) where there is no companion engine.

- **Principle-III paired design contract gate verifier shape** — P01's `m029-p01-headline-shape-contract.sh` + `m029-p01-json-schema-contract.sh` extended to P02's `m029-p02-cross-milestone-shape-contract.sh`; same shape (linear grep -F per assertion + parallel pass/fail counters MEM001/MEM002 bash 3.2 safe). Contract upstream of code per Principle III.

- **AD-19 straight-line bash with separate `grep -F` invocation per assertion** — Used end-to-end across P01/P02/P03 verifiers. No `$(cmd | grep)` pipes in public surface; verifier captures stdout to `/tmp/<slug>.$$` trap-cleaned then runs separate `grep` / `case` against the file. MEM001 Bash 3.2 (no `declare -A`, no `<<<` herestring, parallel indexed accumulators).

- **Negative-assertion verifier discipline** — Verifier code names forbidden tokens in assertion strings (`via tier1 cache reuse`, `/integrations/github`, verbose `▽ Nk saved` form) while the deliverable body must paraphrase semantically. Verifier code is not deliverable text. P01 precedent extended through P02 + P03.

- **AD-1 single-resolve discipline** — `detect-invocation-context.sh` emits a three-line env block; every downstream surface (status headline, render-status-json, render-position, where skill, auto preflight) reads it once via capture-to-tempfile-then-grep-line pattern. No surface re-derives TTY / CI / runtime.

- **AD-6 frontmatter parsing via two awk helpers** (`_rp_yaml_scalar` singular + `_rp_yaml_inline_list` plural `[..]`) — Extended from cross-milestone-feature-shape contract (P02) into render-position.sh and the reverse-lookup advisory pattern.

- **#Q-G8 canonical compact-form `▽ saved Nk` invariant** — P02 declares the form in commands/where.md legend (renderer never emits); P03 implements the emit site in `--live` mode. Verbose-suffix forms (`via tier1 cache reuse`) forbidden in P03 deliverables; mechanically asserted by `m029-p03-render-position-live-shape.sh`.

- **Verifier-contract-over-verifier-skeleton + in-flight-repair** (M032 lineage extended) — When plan-stated expectation conflicts with on-disk reality, ship the contract by manually preparing inputs the contract expects or by adopting the actual-emitter shape. T06 closure: write-summary.sh emits `record_type:"unit_close"` not the plan-stated `event:"unit_close"`; closure verifier asserts on actual emitter shape. P01-SUMMARY directory references repaired (trailing-slash convention) in T06 alongside the closure ceremony.

- **Three-tier nanosecond-clock portability shim** — `date +%s%N` Linux / `gdate +%s%N` macOS coreutils / fallback POSIX `date +%s` * 1e9 with synthetic nanosecond. Codified in `measure-live-tail-latency.sh` for the #Q-G9 p95 latency methodology.

- **AUTO_CHAIN_STAGE_STUB fixture-only escape hatch** — M026/MEM030 stub-envelope convention extended to `start.sh` for fixture acceptance scripts that need to stub the chain stage to a no-op or fail-mode without invoking the full plan-phase loop.

- **Contract-surface assertion model for skill-documented surfaces** — auto.md `## Preflight Summary` + start.md `--auto-chain` are LLM-instruction surfaces (no companion engine); shape verifiers assert canonical H2 anchors + flag mention + oracle invocation, not behavioural CLI output (the LLM consumes the doc; the doc-shape is the contract).

## Verification at Close

- **Acceptance battery** (`tests/m029-acceptance/run-acceptance-battery.sh`): `BATTERY: pass=14 fail=0` (4 P01 SCs + 4 P02 SCs + 4 P03 SCs + SC-11 self + SC-12 milestone-validator hook).
- **`validate-milestone.sh M029`**: `VALIDATE: PASS — 101/101 checks passed`.
- **Per-phase phase-suite**: P01 13/14 PASS at re-run (snapshot-at-close pattern: scope-guard FAIL on later-phase mutations is well-understood, not a regression — see CLAUDE.md operator note + T05-SUMMARY); P02 13/13 PASS at close-time; P03 13/13 PASS at close-time. Canonical "phase is done" signal is the close-time phase-suite, not at re-evaluation. Authoritative cross-phase signal is `validate-milestone.sh M029`.
- **Per-phase acceptance battery**: P01 4/4 PASS, P02 4/4 PASS, P03 4/4 PASS.
- **Closure ceremony**: `M029-VALIDATED` marker on disk; `M029-SUMMARY.md` (this file) with canonical 16-field frontmatter; milestone-grain `unit_close` JSONL record on `.orchestrator/milestones/M029/execution-log.jsonl` with `record_type:"unit_close"` + `granularity:"milestone"` + `unitId:"M029"`. Closure-ceremony shape verifier `m029-p03-closure-ceremony-shape.sh` asserts all four artifacts plus SC-12 verifier exit 0.

## What Was Deferred (explicit non-goals)

- **GitHub fold-in line in `where` headline** (FR-11 cut 2026-05-05 — wiki-is-the-view scope tightening). M013 sidecar stays readable by `orchestrator:github-status` / `-sync`; deeper GitHub Projects v2 / Issues / dashboard surface area defers to demand-driven `external-tool-adapters` post-launch.
- **`--refresh-github` flag** (FR-12 cut 2026-05-05).
- **Web UI / persistent dashboard** — wiki (M032) is the long-form view.
- **Watcher daemon for `--live`** — foreground only (P03 `--live` is interactive single-process tail-on-jsonl).
- **Spec 033 `milestones:` frontmatter migration** — defers to M036b planning entry (post-launch wiki projection + operator-facing scale UX).

## Key Decisions

- **AD-1 single-resolve invocation context** — `detect-invocation-context.sh` resolves TTY / CI / runtime / non_interactive once; downstream surfaces read the three-line env block.
- **AD-2 unconditional ANSI strip in JSON sections** — `render-status-json.sh` is the SINGLE ANSI-strip site for JSON output.
- **AD-3 four-priority non-interactive policy** — `auto_proceed: true` default + `--no-confirm` override + standard/full intensity gate + #Q-3 leave-marker-absent failure semantics.
- **AD-4 SC-8 oracle wrapper amendment** — Amended from `predictive-surface.sh --milestone` to `summarize-milestone.sh --milestone` because M027 is closed under CON-3 knowledge-layer-boundary; M029 owns its own milestone summary helper. Spec Amendment Record entry on `specs/037-roadmap-visibility-cli-ux/spec.md`.
- **AD-5 `display_thresholds.compression_savings_pct: 5.0` config knob** — Heuristic-default with FR-8 review trigger ("Tune after first 10 milestones of M019 Tier 1 + M018 Tier 2 telemetry. Review trigger: re-evaluate threshold once `metrics-rollup.sh --scope milestone` shows median savings ≥ 3% across closed milestones.").
- **AD-6 cross-milestone `milestones:` frontmatter list + reverse-lookup advisory** — exactly-one-of `milestone:` singular vs `milestones:` list with stderr WARN + prefer-plural on both-present; reverse-lookup against `M*-EVALUATION.md feature_ref:`.
- **AD-7 `schema_version: "1.0"` from day 1** — All M029 design contracts (status-headline-shape, status-json-schema, cross-milestone-feature-shape) carry the schema_version field.
- **AD-8 knowledge-layer-boundary discipline** — No M020 schema change; the `unit_close` event consumes the existing M019 emitter (write-summary.sh `record_type:"unit_close"`); no new event type.
- **AD-9 sentinel-file mechanism** — `find -newer` SC-14 readonly contract + #Q-G6 enumerated timestamp-strip pattern set (TS / RECENCY / EPOCH).
- **Scope tightening 2026-05-05** — FR-11 GitHub fold-in cut + FR-12 --refresh-github cut, deferred to post-launch external-tool-adapters; rationale in brief at `.orchestrator/proposals/M029-roadmap-visibility-and-cli-ux.md` § "Scope tightening — wiki-is-the-view".

## Patterns Established

(Detailed in the Cross-Phase Inheritance section above.) Summary: Principle-III paired design contract gate verifier shape; AD-19 straight-line bash with separate grep -F per assertion; negative-assertion verifier discipline; canonical compact-form ▽ saved Nk invariant; four-key fixed-order summarize-milestone output as AD-4 SC-8 oracle interface; AUTO_CHAIN_STAGE_STUB fixture-only escape hatch; contract-surface assertion model for skill-documented surfaces; three-tier nanosecond-clock portability shim; verifier-contract-over-verifier-skeleton + in-flight-repair (M032 lineage extended).

## Post-Close Handoff

- **M035 P00+P01 next**: dev-ergonomic prep before launch (`--mode=symlink` install + `orchestrator:status` version-drift warning) + multi-consumer-project freshness today; M035 P02–P06 IS the launch event (npm + homebrew + curl-pipe-bash publishing pipelines, GH release automation, install-script integrity, `orchestrator:update` first-class command). Operator note: invoke as `orchestrator:auto milestone=M035` to bypass the M036b deferred-state paper-cut.
- **M036b post-launch (P08–P09)**: wiki projection (P08, blocked by M032 closure — already closed 2026-05-05) + operator-facing scale UX for the reference-corpus pipeline (REVIEW queue, change-over-time queries, supersede chain at scale). Demand-driven.
- **`external-tool-adapters` post-launch**: consumes M029's `--format=json` schema (`render-status-json.sh` → `references/status-json-schema.md` AD-7 schema_version: "1.0") for GitHub / Trello / Notion / Linear projection.
- **Friendly-tester pass against M033's four init branches** before 2026-05-12 deadline per launch-sequencing-amendment Q-1 (greenfield-empty / greenfield-with-materials / existing-codebase / migrating). Protocol at `tests/m033-acceptance/friendly-tester-pass/protocol.md`. Not blocking M029 closure.
- **M036a P03 live-LLM smoke test** before 2026-05-08 — single real LLM extraction end-to-end (not stub) against a representative PBJ fixture. Cheap insurance against pilot-day regression on the only mock-only path. M036a itself is closed.

## Acceptance Evidence

- `tests/m029-acceptance/run-acceptance-battery.sh` emits `BATTERY: pass=14 fail=0` (4 P01 + 4 P02 + 4 P03 + SC-11 self + SC-12 validator hook).
- `bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M029` emits `VALIDATE: PASS — 101/101 checks passed`.
- `M029-VALIDATED` marker on disk at `.orchestrator/milestones/M029/M029-VALIDATED`.
- Milestone-grain `unit_close` JSONL record on `.orchestrator/milestones/M029/execution-log.jsonl`.
- `bash tools/verify/m029-p03-closure-ceremony-shape.sh` exits 0 with full pass.
