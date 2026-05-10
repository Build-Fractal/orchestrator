---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M029"
goal: "Land the load-bearing M029 foundation: the AD-1 single-resolve invocation-context resolver, the two Principle-III design contracts (`references/status-headline-shape.md`, `references/status-json-schema.md` carrying `schema_version: \"1.0\"` from day 1 per AD-7), the `orchestrator:status` headline block embedding the M027 efficiency-footer (FR-2), the `--format=json` renderer with unconditionally-ANSI-stripped `sections` (FR-3, AD-2), and the new read-only `orchestrator:context` skill (FR-4) — together with SC-1/SC-2/SC-3/SC-4 fixtures + acceptance scripts + the `m029-p01-*` phase-suite."
demo_sentence: "A developer runs `bash scripts/state/detect-invocation-context.sh --tty=true --ci=false` and observes `renderer=tui exit_code_scheme=interactive` (SC-1 case 1), then re-runs with `--tty=false --ci=true` and observes `renderer=plain` (SC-1 case 2); runs `orchestrator:status` against the SC-2 fixture milestone and observes stdout whose first 3 non-blank lines match the regex documented in `references/status-headline-shape.md` and whose body below the headline is byte-identical to pre-M029 status output (SC-2); runs `orchestrator:status --format=json` against the same fixture and observes a JSON object whose top-level `schema_version` field is `\"1.0\"` and which validates against every required key documented in `references/status-json-schema.md` via `jq -e` (SC-3); runs `orchestrator:context` and observes ≤24 lines of stdout listing the documented field set (SC-4); runs `bash tests/m029-acceptance/p01-acceptance-battery.sh` and observes exit 0 with `BATTERY: pass=N fail=0`; runs `bash tools/verify/m029-p01-phase-suite.sh` and observes `SUMMARY: m029-p01-phase-suite.sh pass=N fail=0`."
risk: "high"
depends_on: []
---

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Project-owned slug-bearing verifiers live under tools/verify/.
     Verifier scripts are co-authored alongside their corresponding
     artifact within the SAME task (plan-time discipline rule 2).
     Namespacing: `m029-p01-*` prefix avoids collision with the
     existing phase-only `p01-phase-suite.sh` ([M030](../../../../milestones/M030/index.md) era) per the
     milestone-slug-required convention. -->

### Truths

- `references/status-headline-shape.md` exists and is the canonical Principle-III design contract for the FR-2 headline. The document carries: (a) an H1 (`# Status Headline Shape`); (b) `## Purpose` naming FR-2 / SC-2 / `commands/status.md` as consumers; (c) `## Field Set` listing exactly five headline fields in fixed order — milestone ID + name, phase index + percent complete, lock state, last-dispatch recency, last-verify result; (d) `## Embedded Footer` documenting that the [M027](../../../../milestones/M027/index.md) `scripts/diagnostics/efficiency-footer.sh` block follows the five-field block verbatim under `efficiency_footer: true` and disappears under `efficiency_footer: false` per CON-5 suppression-matrix inheritance; (e) `## Regex` carrying the canonical SC-2 regex that asserts the first three non-blank lines match a documented field-shape pattern; (f) `## Cross-References` naming `references/status-json-schema.md`, `commands/status.md`, M027 surfaces. Per Principle III, this contract MUST be on disk before any FR-2 implementation work begins.
  - Check: `bash tools/verify/m029-p01-headline-shape-contract.sh`

- `references/status-json-schema.md` exists and is the canonical Principle-III design contract for the FR-3 JSON output. The document carries: (a) an H1 (`# Status JSON Schema`); (b) `## schema_version` declaring `1.0` as the day-1 value per AD-7 with the documented stability policy ("non-breaking field additions under minor bumps; field removals or type changes require a major bump and a deprecation cycle"); (c) `## Top-Level Keys` enumerating the required keys — `schema_version`, `milestone_id`, `milestone_name`, `phase_index`, `phase_count`, `phase_percent_complete`, `lock_state`, `last_dispatch_recency`, `last_verify_result`, `sections`, plus an optional `state` key set to `"degraded"` when the JSONL stream parses with errors; (d) `## sections` documenting the ANSI-strip rule per AD-2 (every string in `sections` is ANSI-stripped unconditionally regardless of TTY); (e) `## Edge Cases` covering the corrupt-JSONL stream → `state: "degraded"` + `parse_errors: [...]` shape from the spec's Edge Cases section; (f) `## Cross-References` naming `references/status-headline-shape.md`, `commands/status.md`, `scripts/diagnostics/render-status-json.sh`, [M035](../../../../milestones/M035/index.md) packaging, post-launch `external-tool-adapters`. Per Principle III + AD-7, this contract MUST be on disk before any FR-3 implementation work begins.
  - Check: `bash tools/verify/m029-p01-json-schema-contract.sh`

- `scripts/state/detect-invocation-context.sh` exists, is executable, accepts `--tty=<true|false>` and `--ci=<true|false>` test-injection flags (used by SC-1; production callers omit these and rely on real `[ -t 1 ]` + env-var probing), and emits an env-block on stdout in `key=value` lines with exactly three fields per AD-1: `renderer ∈ {tui, json, plain}`, `exit_code_scheme ∈ {interactive, governance}`, `default_provider` (passthrough from existing config; resolved via the standard 4-layer fallback). Resolution rules: TTY=true + no CI vars → `renderer=tui exit_code_scheme=interactive`; TTY=false → `renderer=plain exit_code_scheme=governance`; `--format=json` invocation context (passed via `--format=json` flag) → `renderer=json exit_code_scheme=governance`. Exit 0 on success. Read-only — never writes to disk. AD-1 single-resolve discipline: every M029 surface (`status` headline, `--format=json`, `where`, `context`, live-tail, preflight) reads this script's emitted env block at command entry; no surface re-derives. The script MUST refuse unknown flags with exit non-zero and a usage diagnostic on stderr.
  - Check: `bash tools/verify/m029-p01-invocation-context-resolver-shape.sh`

- The SC-1 acceptance script `tests/m029-acceptance/p01-sc1-resolver.sh` exists, is executable, and exits 0. The script: (a) runs `bash scripts/state/detect-invocation-context.sh --tty=true --ci=false` and asserts stdout contains `renderer=tui` AND `exit_code_scheme=interactive`; (b) runs the same script with `--tty=false --ci=true` and asserts stdout contains `renderer=plain`; (c) runs with `--format=json` (or equivalent JSON-context input flag) and asserts stdout contains `renderer=json`; (d) runs with an unknown flag and asserts non-zero exit + a stderr diagnostic naming the unknown flag. The script captures all stdout/stderr to temp files under `mktemp -d` and cleans up on exit.
  - Check: `bash tools/verify/m029-p01-sc1-shape.sh`

- `commands/status.md` is modified additively to prepend a 3-line headline block above the existing flat sections (FR-2). The headline rendering: (a) reads the resolver's env block at command entry per AD-1; (b) emits exactly the five documented fields as the first three non-blank lines (milestone ID + name on line 1; phase index + percent complete + lock state on line 2; last-dispatch recency + last-verify result on line 3 — exact line packing documented in `references/status-headline-shape.md`); (c) follows the headline with the M027 `scripts/diagnostics/efficiency-footer.sh --milestone <active-milestone-id>` line verbatim under `efficiency_footer: true` (CON-5 suppression-matrix inheritance — the existing `## Efficiency Footer` section in `commands/status.md` is the surface, the headline embeds the footer line by reusing the same helper); (d) follows with a blank line; (e) emits the existing flat sections byte-identical to today's render (Progress Overview, Blockers, Execution History, Telemetry Metrics, Efficiency Footer, Next Action). The flat-section invariant is load-bearing for the spec's "byte-identical scrapers do not break" promise. The headline rendering is gated on `--format=json` being absent — when `--format=json` is present, the JSON renderer (T04) takes over and the headline+flat-sections markdown path is skipped.
  - Check: `bash tools/verify/m029-p01-status-headline-shape.sh`

- The SC-2 acceptance script `tests/m029-acceptance/p01-sc2-headline.sh` exists, is executable, and exits 0. The script: (a) sets up a fixture milestone under `mktemp -d` in `executing` state with at least one completed phase and one in-flight phase, with a populated `execution-log.jsonl` carrying ≥1 `dispatch_usage` record so the M027 efficiency-footer has Tier 1 data to roll up; (b) runs `orchestrator:status` against the fixture (invoked as `bash <status-driver-script-path> --orchestrator-root <fixture-root>` per the existing status invocation convention — the headline-block path runs); (c) asserts the first three non-blank lines of stdout match the SC-2 regex documented in `references/status-headline-shape.md`; (d) re-runs against the same fixture with the M027 `efficiency_footer: false` config knob set and asserts the headline block is present but the footer line disappears (CON-5 suppression-matrix inheritance — no other field changes); (e) asserts the body below the headline is byte-identical to a "pre-M029" baseline rendering (captured via a separate helper that reads the same fixture but skips the headline block). Cleanup `rm -rf` mandatory.
  - Check: `bash tools/verify/m029-p01-sc2-shape.sh`

- `scripts/diagnostics/render-status-json.sh` exists, is executable, and is the single ANSI-strip site per AD-2. Behavior: (a) reads the resolver's env block at entry per AD-1 — the renderer is always invoked under `renderer=json` context (the `--format=json` flag drives the resolver into the json branch); (b) builds the JSON object documented in `references/status-json-schema.md` with all required top-level keys, populating `schema_version: "1.0"` from a single source-of-truth constant in the script; (c) populates the `sections` map by capturing the rendered string of each existing flat section (Progress Overview, Blockers, Execution History, Telemetry Metrics, Efficiency Footer, Next Action) and applying ANSI-strip to each value unconditionally — `sed 's/\x1b\[[0-9;]*[mGKHF]//g'` (or equivalent) is the strip primitive; (d) emits the JSON object to stdout via `jq -n` or equivalent — never via raw printf string concatenation, so quote escaping is mechanically correct; (e) on corrupt `execution-log.jsonl`, emits a JSON object with `state: "degraded"` and a `parse_errors` list per the spec's Edge Cases entry, and never crashes the renderer; (f) read-only — never writes to `.orchestrator/`. The ANSI-strip is the ONLY strip site; the existing markdown emitters in `commands/status.md` continue to emit ANSI for the legacy flat-section path.
  - Check: `bash tools/verify/m029-p01-render-status-json-shape.sh`

- `commands/status.md` is modified additively (in the same file as the headline block T03 lands) to add `--format=json` flag wiring: (a) when invoked with `--format=json`, the headline+flat-sections markdown path is skipped and `scripts/diagnostics/render-status-json.sh` is invoked, its stdout becomes the command's stdout; (b) when invoked without `--format=json`, behavior is unchanged from T03 (headline block + flat sections); (c) the `--format=` flag is documented in `commands/status.md` body. The single source of truth for the schema is `references/status-json-schema.md`; the commands/status.md surface only mentions `--format=json` exists — it does not duplicate schema content.
  - Check: `bash tools/verify/m029-p01-status-format-json-wiring.sh`

- The SC-3 acceptance script `tests/m029-acceptance/p01-sc3-format-json.sh` exists, is executable, and exits 0. The script: (a) sets up the same fixture milestone shape as SC-2; (b) runs `orchestrator:status --format=json` against the fixture; (c) asserts stdout is parseable JSON via `jq empty`; (d) runs `jq -e '.schema_version == "1.0"'` against stdout and asserts exit 0; (e) runs `jq -e` for each required key documented in `references/status-json-schema.md` (`milestone_id`, `milestone_name`, `phase_index`, `phase_count`, `phase_percent_complete`, `lock_state`, `last_dispatch_recency`, `last_verify_result`, `sections`) and asserts each exits 0; (f) asserts every string value under `.sections` contains no ANSI escape sequence (greps for `\x1b\[` and asserts no match — the AD-2 unconditional-strip invariant); (g) runs the same against a fixture with deliberately-corrupted `execution-log.jsonl` and asserts `state == "degraded"` with a non-empty `parse_errors` array. Cleanup mandatory.
  - Check: `bash tools/verify/m029-p01-sc3-shape.sh`

- `commands/context.md` exists in the canonical command-document shape (YAML frontmatter with `description:`; H1 title; Purpose; Output Format; Idempotency; Read-Only; Reference Files per the existing `commands/*.md` convention — see `commands/zoom-out.md` for a similar read-only debug skill). The `description:` advertises `orchestrator:context` as a read-only single-screen runtime profile printer. The Output Format section documents the FR-4 field set: resolved root, runtime (CC/Codex/Cursor), capability profile, intensity defaults (Quick/Standard/Full thresholds), active milestone, lock state. The skill is read-only — no I/O writes. The rendered output MUST fit in a single screen ≤24 lines on 80×24 (SC-4). The skill body invokes existing scripts only — no new scripts are produced for `orchestrator:context` in P01: it composes `scripts/state/resolve-root.sh`, `scripts/state/find-active-milestone.sh`, the resolver from T02, plus inline reads of the lock-manager state at `.orchestrator/global/lock.json` (or wherever resolve-root says lock-manager state lives). When no active milestone exists, the active-milestone line renders as `active milestone: none` rather than empty.
  - Check: `bash tools/verify/m029-p01-context-skill-shape.sh`

- The SC-4 acceptance script `tests/m029-acceptance/p01-sc4-context.sh` exists, is executable, and exits 0. The script: (a) sets up a minimal fixture under `mktemp -d` with a `.orchestrator/` tree resolvable by `scripts/state/resolve-root.sh`; (b) runs `orchestrator:context` against the fixture; (c) asserts stdout has ≤24 lines; (d) asserts each documented field (resolved root, runtime, capability profile, intensity defaults, active milestone, lock state) appears as a labeled line; (e) asserts no file under `.orchestrator/` was modified during the run (read-only invariant; pre-cursor to SC-14 — uses a sentinel file written before the run, mtime compared after).
  - Check: `bash tools/verify/m029-p01-sc4-shape.sh`

- `tests/m029-acceptance/p01-acceptance-battery.sh` exists, is executable, chains the four SC scripts (`p01-sc1-resolver.sh`, `p01-sc2-headline.sh`, `p01-sc3-format-json.sh`, `p01-sc4-context.sh`) in dependency order, exits 0 iff every sub-script exits 0, and emits a single line `BATTERY: p01-acceptance pass=N fail=M` before exit. This is the P01 slice of the SC-11 milestone-grain battery — P02 and P03 will extend it (SC-5..SC-10, SC-13, SC-14) and the milestone-close acceptance battery `tests/m029-acceptance/run-acceptance-battery.sh` will assemble all 14 SCs. P01 ships only its own slice.
  - Check: `bash tools/verify/m029-p01-acceptance-battery-shape.sh`

- `tools/verify/m029-p01-phase-suite.sh` exists, is executable, invokes every P01 verifier (in dependency order: design contracts → resolver → SC-1 → headline → SC-2 → render-status-json → format-json wiring → SC-3 → context skill → SC-4 → acceptance battery → scope-guard) and exits 0 iff every sub-gate passes. Emits a single line `SUMMARY: m029-p01-phase-suite.sh pass=N fail=M` before exit. The suite is the P01 close gate.
  - Check: `bash tools/verify/m029-p01-phase-suite.sh`

- The SC-13-precursor / scope-guard invariant holds for the P01 diff: P01 modifies/creates only files declared in this phase's "Files Likely Touched" list. None of `scripts/diagnostics/render-position.sh`, `scripts/diagnostics/summarize-milestone.sh`, `commands/where.md`, `commands/auto.md`, `commands/start.md`, [M013](../../../../milestones/M013/index.md) sidecar files, [M019](../../../../milestones/M019/index.md) emitter scripts, [M020](../../../../milestones/M020/index.md) KNOWLEDGE.md, M027 surfaces (`metrics-rollup.sh`, `efficiency-footer.sh`, `predictive-surface.sh`), or any P02/P03 deliverable is touched. The scope-guard greps the staged diff for any out-of-claim path.
  - Check: `bash tools/verify/m029-p01-scope-guard.sh`

- The CON-1 / FR-14 read-only invariant holds for every P01 surface (resolver, status headline, --format=json, context). No P01 surface writes to `.orchestrator/` at runtime. Verified mechanically by running each surface against a fixture and asserting via the AD-9 sentinel-file mechanism precursor (write `.orchestrator/.m029-p01-sentinel` before the run; assert no file under `.orchestrator/` has mtime newer than the sentinel after, excluding the sentinel itself). The full SC-14 sentinel-file mechanism lands in P02 (per AD-9, the production SC-14 fixture mechanism is a P02 deliverable); P01 ships only the precursor invariant check inside its own scope-guard verifier.
  - Check: `bash tools/verify/m029-p01-readonly-invariant.sh`

### Artifacts

- `references/status-headline-shape.md` (min 60 lines, contains "FR-2", contains "milestone", contains "phase_index", contains "lock_state", contains "last_dispatch", contains "last_verify", contains "Efficiency", contains "regex", contains "CON-5") — create
- `references/status-json-schema.md` (min 70 lines, contains "schema_version", contains "1.0", contains "AD-7", contains "AD-2", contains "milestone_id", contains "phase_index", contains "phase_percent_complete", contains "lock_state", contains "last_dispatch_recency", contains "last_verify_result", contains "sections", contains "degraded", contains "parse_errors") — create
- `scripts/state/detect-invocation-context.sh` (min 80 lines, contains "--tty", contains "--ci", contains "--format=json", contains "renderer=tui", contains "renderer=plain", contains "renderer=json", contains "exit_code_scheme=interactive", contains "exit_code_scheme=governance", contains "default_provider", contains "AD-1") — create
- `scripts/diagnostics/render-status-json.sh` (min 100 lines, contains "schema_version", contains "1.0", contains "AD-2", contains "sections", contains "degraded", contains "parse_errors", contains "metrics-rollup.sh", contains "efficiency-footer.sh") — create
- `commands/status.md` (modify; post-modification min 200 lines, contains "Headline Block", contains "FR-2", contains "--format=json", contains "FR-3", contains "references/status-headline-shape.md", contains "references/status-json-schema.md", contains "scripts/state/detect-invocation-context.sh", contains "scripts/diagnostics/render-status-json.sh") — modify
- `commands/context.md` (min 60 lines, contains "orchestrator:context", contains "FR-4", contains "single-screen", contains "resolved root", contains "runtime", contains "capability profile", contains "intensity defaults", contains "active milestone", contains "lock state", contains "scripts/state/detect-invocation-context.sh") — create
- `tests/m029-acceptance/p01-sc1-resolver.sh` (min 50 lines, contains "SC-1", contains "renderer=tui", contains "renderer=plain", contains "renderer=json", contains "exit_code_scheme=interactive", contains "exit_code_scheme=governance") — create
- `tests/m029-acceptance/p01-sc2-headline.sh` (min 70 lines, contains "SC-2", contains "FR-2", contains "efficiency_footer", contains "byte-identical") — create
- `tests/m029-acceptance/p01-sc3-format-json.sh` (min 80 lines, contains "SC-3", contains "FR-3", contains "schema_version", contains "1.0", contains "jq -e", contains "ANSI") — create
- `tests/m029-acceptance/p01-sc4-context.sh` (min 50 lines, contains "SC-4", contains "FR-4", contains "≤24", contains "active milestone") — create
- `tests/m029-acceptance/p01-acceptance-battery.sh` (min 30 lines, contains "BATTERY:", contains "p01-sc1-resolver", contains "p01-sc2-headline", contains "p01-sc3-format-json", contains "p01-sc4-context") — create
- `tests/m029-acceptance/fixtures/status-headline-executing.fixture/` (directory; contains a fixture milestone tree with `.orchestrator/milestones/M999/M999-ROADMAP.md`, `execution-log.jsonl` carrying ≥1 dispatch_usage record, and `phases/P01/P01-SUMMARY.md` to give the headline a populated state) — create
- `tests/m029-acceptance/fixtures/status-json-executing.fixture/` (directory; same shape as status-headline-executing.fixture, used by SC-3) — create
- `tests/m029-acceptance/fixtures/status-json-degraded.fixture/` (directory; same shape but with deliberately-corrupted JSONL records to drive the AD-2 `state: "degraded"` path) — create
- `tools/verify/m029-p01-headline-shape-contract.sh` (min 25 lines, contains "references/status-headline-shape.md", contains "FR-2", contains "regex") — create
- `tools/verify/m029-p01-json-schema-contract.sh` (min 25 lines, contains "references/status-json-schema.md", contains "schema_version", contains "1.0", contains "AD-7") — create
- `tools/verify/m029-p01-invocation-context-resolver-shape.sh` (min 35 lines, contains "scripts/state/detect-invocation-context.sh", contains "renderer", contains "exit_code_scheme", contains "default_provider", contains "AD-1") — create
- `tools/verify/m029-p01-sc1-shape.sh` (min 25 lines, contains "p01-sc1-resolver.sh", contains "SC-1") — create
- `tools/verify/m029-p01-status-headline-shape.sh` (min 30 lines, contains "commands/status.md", contains "Headline Block", contains "FR-2", contains "efficiency-footer.sh") — create
- `tools/verify/m029-p01-sc2-shape.sh` (min 25 lines, contains "p01-sc2-headline.sh", contains "SC-2") — create
- `tools/verify/m029-p01-render-status-json-shape.sh` (min 30 lines, contains "scripts/diagnostics/render-status-json.sh", contains "schema_version", contains "AD-2", contains "ANSI") — create
- `tools/verify/m029-p01-status-format-json-wiring.sh` (min 25 lines, contains "commands/status.md", contains "--format=json", contains "render-status-json.sh") — create
- `tools/verify/m029-p01-sc3-shape.sh` (min 25 lines, contains "p01-sc3-format-json.sh", contains "SC-3") — create
- `tools/verify/m029-p01-context-skill-shape.sh` (min 30 lines, contains "commands/context.md", contains "FR-4", contains "single-screen", contains "active milestone") — create
- `tools/verify/m029-p01-sc4-shape.sh` (min 25 lines, contains "p01-sc4-context.sh", contains "SC-4") — create
- `tools/verify/m029-p01-acceptance-battery-shape.sh` (min 25 lines, contains "p01-acceptance-battery.sh", contains "BATTERY:") — create
- `tools/verify/m029-p01-readonly-invariant.sh` (min 35 lines, contains "FR-14", contains "CON-1", contains "sentinel", contains "mtime") — create
- `tools/verify/m029-p01-scope-guard.sh` (min 50 lines, contains "render-position.sh", contains "summarize-milestone.sh", contains "commands/where.md", contains "metrics-rollup.sh", contains "efficiency-footer.sh", contains "predictive-surface.sh", contains "KNOWLEDGE.md") — create
- `tools/verify/m029-p01-phase-suite.sh` (min 80 lines, contains "SUMMARY:", contains "m029-p01-headline-shape-contract", contains "m029-p01-json-schema-contract", contains "m029-p01-invocation-context-resolver-shape", contains "m029-p01-status-headline-shape", contains "m029-p01-render-status-json-shape", contains "m029-p01-context-skill-shape", contains "m029-p01-acceptance-battery-shape", contains "m029-p01-readonly-invariant", contains "m029-p01-scope-guard", contains "m029-p01-phase-suite") — create

### Key Links

- `commands/status.md` → `references/status-headline-shape.md` (FR-2 surface points at the design contract for shape detail)
- `commands/status.md` → `references/status-json-schema.md` (FR-3 surface points at the JSON schema contract)
- `commands/status.md` → `scripts/state/detect-invocation-context.sh` (AD-1 single-resolve — status reads resolver at command entry)
- `commands/status.md` → `scripts/diagnostics/render-status-json.sh` (FR-3 — status delegates JSON rendering to the renderer)
- `commands/status.md` → `scripts/diagnostics/efficiency-footer.sh` (FR-2 — headline embeds the M027 footer line; CON-5 suppression-matrix inheritance)
- `commands/context.md` → `scripts/state/detect-invocation-context.sh` (FR-4 — context skill reads resolver to display runtime profile)
- `commands/context.md` → `scripts/state/resolve-root.sh` (FR-4 — context skill displays resolved root)
- `commands/context.md` → `scripts/state/find-active-milestone.sh` (FR-4 — context skill displays active milestone line)
- `references/status-json-schema.md` → `references/status-headline-shape.md` (cross-reference: JSON schema names the headline contract)
- `references/status-headline-shape.md` → `references/status-json-schema.md` (cross-reference: headline contract names the JSON schema)
- `scripts/diagnostics/render-status-json.sh` → `references/status-json-schema.md` (header comment names the SSOT)
- `scripts/diagnostics/render-status-json.sh` → `scripts/state/detect-invocation-context.sh` (renderer reads resolver per AD-1)
- `scripts/state/detect-invocation-context.sh` → `references/status-json-schema.md` (header comment names the schema as a downstream consumer of `renderer=json`)
- `tests/m029-acceptance/p01-acceptance-battery.sh` → `tests/m029-acceptance/p01-sc1-resolver.sh` (battery chains SC-1)
- `tests/m029-acceptance/p01-acceptance-battery.sh` → `tests/m029-acceptance/p01-sc2-headline.sh` (battery chains SC-2)
- `tests/m029-acceptance/p01-acceptance-battery.sh` → `tests/m029-acceptance/p01-sc3-format-json.sh` (battery chains SC-3)
- `tests/m029-acceptance/p01-acceptance-battery.sh` → `tests/m029-acceptance/p01-sc4-context.sh` (battery chains SC-4)
- `tools/verify/m029-p01-phase-suite.sh` → `tools/verify/m029-p01-headline-shape-contract.sh` (suite chains the design-contract gate)
- `tools/verify/m029-p01-phase-suite.sh` → `tools/verify/m029-p01-json-schema-contract.sh` (suite chains the JSON-schema-contract gate)
- `tools/verify/m029-p01-phase-suite.sh` → `tools/verify/m029-p01-acceptance-battery-shape.sh` (suite chains the acceptance-battery shape verifier)
- `tools/verify/m029-p01-phase-suite.sh` → `tools/verify/m029-p01-scope-guard.sh` (suite chains the scope-guard)

## Tasks

### T01: Design contracts — `references/status-headline-shape.md` + `references/status-json-schema.md` (Principle III gate)

See `tasks/T01-design-contracts-PLAN.md`.

### T02: Invocation-context resolver + SC-1 fixture/script + verifier (AD-1 single-resolve)

See `tasks/T02-invocation-context-resolver-PLAN.md`.

### T03: `orchestrator:status` headline block + SC-2 fixture/script + verifier (FR-2)

See `tasks/T03-status-headline-block-PLAN.md`.

### T04: JSON renderer + `--format=json` wiring + SC-3 fixture/script + verifier (FR-3, AD-2, AD-7)

See `tasks/T04-status-json-format-PLAN.md`.

### T05: `orchestrator:context` skill + SC-4 fixture/script + verifier (FR-4)

See `tasks/T05-context-skill-PLAN.md`.

### T06: P01 acceptance battery + phase-suite + scope-guard + read-only invariant verifier

See `tasks/T06-acceptance-and-phase-suite-PLAN.md`.

## Task Dependencies

```
T01 ──┬──► T03 ──► T04 ──┬──► T06
      │                  │
      ├──► T02 ──────────┤
      │                  │
      └──► T05 ──────────┘
```

T01 (design contracts) ships first and is load-bearing for T03 (headline implementation reads the FR-2 shape contract), T04 (JSON renderer reads the schema contract), and T05 (context skill cross-references both contracts). Per Principle III + the SC-2/SC-3 design-contract clauses + AD-7, the contracts MUST be on disk before any FR-2/FR-3 implementation work begins.

T02 (resolver) has no design-contract code dependency — it ships its own behavioral contract — so it can land in parallel with T01 once T01's contracts inform what `renderer ∈ {tui, json, plain}` means downstream. Conservative serial choice: T02 runs after T01 to keep the AD-1 single-resolve discipline grounded in the shape both contracts expect.

T03 (headline block) modifies `commands/status.md` and depends on T01 (shape contract) + T02 (resolver). T04 (`--format=json` wiring + JSON renderer) also modifies `commands/status.md`, so it MUST run after T03 to avoid concurrent-edit conflict on a single file. T04 also depends on T01 (schema contract) + T02 (resolver).

T05 (context skill) is independent of T03/T04 — it creates a brand-new `commands/context.md` and reuses only T02's resolver. Could run in parallel with T03/T04, but the executor schedules one task at a time so it lands after T04 in the serial chain.

T06 (acceptance battery + phase-suite + scope-guard) depends on T01..T05 because it chains every SC script and asserts every artifact exists.

## Files Likely Touched

- `references/status-headline-shape.md` (create)
- `references/status-json-schema.md` (create)
- `scripts/state/detect-invocation-context.sh` (create)
- `scripts/diagnostics/render-status-json.sh` (create)
- `commands/status.md` (modify)
- `commands/context.md` (create)
- `tests/m029-acceptance/p01-sc1-resolver.sh` (create)
- `tests/m029-acceptance/p01-sc2-headline.sh` (create)
- `tests/m029-acceptance/p01-sc3-format-json.sh` (create)
- `tests/m029-acceptance/p01-sc4-context.sh` (create)
- `tests/m029-acceptance/p01-acceptance-battery.sh` (create)
- `tests/m029-acceptance/fixtures/status-headline-executing.fixture/M999-ROADMAP.md` (create)
- `tests/m029-acceptance/fixtures/status-headline-executing.fixture/execution-log.jsonl` (create)
- `tests/m029-acceptance/fixtures/status-headline-executing.fixture/phases/P01/P01-SUMMARY.md` (create)
- `tests/m029-acceptance/fixtures/status-json-executing.fixture/M999-ROADMAP.md` (create)
- `tests/m029-acceptance/fixtures/status-json-executing.fixture/execution-log.jsonl` (create)
- `tests/m029-acceptance/fixtures/status-json-executing.fixture/phases/P01/P01-SUMMARY.md` (create)
- `tests/m029-acceptance/fixtures/status-json-degraded.fixture/M999-ROADMAP.md` (create)
- `tests/m029-acceptance/fixtures/status-json-degraded.fixture/execution-log.jsonl` (create)
- `tools/verify/m029-p01-headline-shape-contract.sh` (create)
- `tools/verify/m029-p01-json-schema-contract.sh` (create)
- `tools/verify/m029-p01-invocation-context-resolver-shape.sh` (create)
- `tools/verify/m029-p01-sc1-shape.sh` (create)
- `tools/verify/m029-p01-status-headline-shape.sh` (create)
- `tools/verify/m029-p01-sc2-shape.sh` (create)
- `tools/verify/m029-p01-render-status-json-shape.sh` (create)
- `tools/verify/m029-p01-status-format-json-wiring.sh` (create)
- `tools/verify/m029-p01-sc3-shape.sh` (create)
- `tools/verify/m029-p01-context-skill-shape.sh` (create)
- `tools/verify/m029-p01-sc4-shape.sh` (create)
- `tools/verify/m029-p01-acceptance-battery-shape.sh` (create)
- `tools/verify/m029-p01-readonly-invariant.sh` (create)
- `tools/verify/m029-p01-scope-guard.sh` (create)
- `tools/verify/m029-p01-phase-suite.sh` (create)
