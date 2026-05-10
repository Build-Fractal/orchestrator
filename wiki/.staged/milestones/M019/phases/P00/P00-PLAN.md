---
schema_version: "1.0"
type: phase-plan
phase: "P00"
milestone: "M019"
goal: "Adapt dispatch-facing payload structure, templates, intensity-gate prompts, and the settings.json writer for Opus 4.7 documented behavioral defaults (L1–L5 + AD-7 additive-merge fix + one-shot pricing.yml populate) so that the P01 Tier 1 emitter records a post-4.7 baseline on every M012–M014 dogfood dispatch, not a pre/post-4.7 discontinuity."
demo_sentence: "A developer runs `bash scripts/dispatch/build-context.sh <orch_root> M019 P00 T01` on a fixture task and the rendered payload contains an explicit first-turn completeness block (intent + constraints + acceptance criteria + file paths) sourced from existing plan artifacts, stable sections (knowledge, decisions, constraints) appear before volatile sections (state, task_plan, git status) which are wrapped in a `<dispatch-volatile>` marker, no `thinking_budget:` reference exists anywhere in `templates/` or `scripts/engine/intensity-gate.sh`, an explicit parallel-fan-out directive appears when a recipe declares parallelizable subtasks, `bash scripts/verify/m019-p00-payload-shape.sh` exits 0, `bash scripts/verify/m019-p00-evaluate-preflight-additivity.sh` exits 0 (proves M021 hook + widened allow-list survive a fresh `evaluate-preflight.sh` re-run byte-identically), `bash scripts/verify/m019-p00-no-regression.sh` reports PASS across `tests/test-s01.sh`..`tests/test-s07.sh` + `scripts/verify/anti-pattern-lint.sh` + `scripts/verify/run-suite.sh m021 P04`, and `bash scripts/verify/m019-p00-phase-suite.sh` reports PASS: 4 / FAIL: 0."
risk: "high"
depends_on: []
---

## Must-Haves

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     All Check: commands use single-invocation script-file shape. No inline
     compound bash, no plain subshells, no $(...) with pipes. -->

### Truths

- `scripts/dispatch/build-context.sh` emits a first-turn completeness block (L1) assembled from existing plan artifacts — intent, constraints, acceptance criteria, and file paths for the task — at a known section position in every dispatch-prompt payload (task branch, not planning branch). The block content is derived from the already-included task-plan + phase-plan content; no new agent-facing prose added. The first-turn block header text is `## First-Turn Completeness` and contains four labelled subsections: `### Intent`, `### Constraints`, `### Acceptance Criteria`, `### Files To Touch`.
  - Check: `bash scripts/verify/m019-p00-payload-shape.sh`
- `scripts/dispatch/build-context.sh` orders sections stable-before-volatile (L2/AD-5). The assembled payload places stable sections (`## Knowledge`, `## Decisions`, `## Constraints`) before volatile sections (`## State Context`, `## Task Plan`, `## Upstream Context`, and the new `## First-Turn Completeness` block which is also volatile because it embeds task-specific content). Volatile sections are wrapped between a `<dispatch-volatile>` opening marker and a `</dispatch-volatile>` closing marker emitted as literal string lines in the payload body (not XML elements inside a section — standalone marker lines).
  - Check: `bash scripts/verify/m019-p00-payload-shape.sh`
- `scripts/dispatch/build-context.sh` emits an explicit parallel-fan-out directive (L4) when the resolved recipe (`templates/context-recipe.yaml` or overrides) declares one or more sections with a `parallel_fan_out: true` field OR when the task plan contains the literal marker `parallelizable: true` in its YAML frontmatter. The directive text is a known-literal block headed `## Parallel Fan-Out` that reads: "When this task requires reading multiple files or fanning out across items, spawn multiple subagents in the same turn rather than issuing serial tool calls." When no parallelizable signal is present, the directive block is omitted entirely (no empty section).
  - Check: `bash scripts/verify/m019-p00-payload-shape.sh`
- No file under `templates/` and no line in `scripts/engine/intensity-gate.sh` contains the literal strings `thinking_budget` or `thinking budget` (L3/AD-6). A grep sweep of `templates/**/*.md`, `templates/**/*.yaml`, `templates/**/*.yml`, and `scripts/engine/intensity-gate.sh` returns zero matches.
  - Check: `bash scripts/verify/m019-p00-payload-shape.sh`
- `templates/dispatch-prompt.md` has been rewritten so every expressive-guidance instruction uses a positive-example form ("Do X") rather than a negative prohibition form ("Don't do X") (L5). Constitution XV anti-pattern prohibitions (negative by design) are not touched. Specifically, any line matching the regex `^[[:space:]]*-?[[:space:]]*(Don't|Do not|Never|Avoid)[[:space:]]` in `templates/dispatch-prompt.md` either (a) is part of a clearly-labelled constitutional anti-pattern section containing the literal string `Constitution XV` or `anti-pattern`, or (b) has been rewritten to a positive form. The verify gate enumerates exceptions from a whitelist file `templates/.p00-negative-guidance-retained.txt` (one path:line_number per retained exception, with human-readable rationale — all retained negatives must be listed there and each must be constitutional-anti-pattern-class).
  - Check: `bash scripts/verify/m019-p00-payload-shape.sh`
- `scripts/lifecycle/write-permissions.sh` preserves user-authored content beyond its generated section when the `_generated_by: speckit-orchestrator` marker is present on re-run (AD-7 additive-merge fix). The writer's generated content is delimited by a `// generated:start` / `// generated:end` sentinel-comment pair embedded as string keys inside the JSON envelope (the sentinels are JSON-syntax-safe — they appear as `"_generated_start": "...sentinel..."` and `"_generated_end": "..."` entries, NOT as JavaScript-style comments). On re-run against a target file containing both the generated sentinel block AND additional user-authored top-level keys (`hooks`, `mcpServers`, `statusLine`) or additional allow-list entries outside the sentinel range, the writer replaces only the sentinel-delimited block and leaves the user additions byte-identical. A fixture `.claude/settings.json` preloaded with the [M021](../../../../milestones/M021/index.md) `PreToolUse` hook registration + widened allow-list survives a fresh `scripts/lifecycle/evaluate-preflight.sh .` run with both the hook object and every extra allow-list entry byte-identical to pre-run (diff exit 0 on those ranges).
  - Check: `bash scripts/verify/m019-p00-evaluate-preflight-additivity.sh`
- `.orchestrator/config/pricing.yml` exists and lists per-model input/output rates (USD per million tokens) for Opus 4.7, Sonnet 4.6, and Haiku 4.5, a `last_updated: 2026-04-17` frontmatter value (ISO 8601 date), and a top-level schema comment naming the resolver contract (`ORCH_PRICING_FILE` env override honored; stale threshold 90 days). File is parseable by grep/sed/awk (no jq required, per MEM001). The file is committed to the repo (AD-2 in-repo default with env override).
  - Check: `bash scripts/verify/m019-p00-payload-shape.sh`
- All pre-existing test suites pass unchanged against adapted templates and adapted `build-context.sh` / `intensity-gate.sh` / `write-permissions.sh` (SC-13 regression guard). Specifically: `tests/test-s01.sh` through `tests/test-s07.sh` each report PASS; `scripts/verify/anti-pattern-lint.sh` exits 0; `scripts/verify/run-suite.sh m021 P04` exits 0. If any one suite fails, this truth is violated — adaptation is not allowed to silently change behavior.
  - Check: `bash scripts/verify/m019-p00-no-regression.sh`
- Every new or modified `.sh` file authored in P00 (listed in Files Likely Touched) parses clean with `bash -n` and contains no forbidden Bash-4 constructs: `declare -A`, `mapfile`, `readarray`, `${var,,}`, `${var^^}`, `${!prefix*}`, process substitution `<(`, process substitution `>(`. Enforced per Constitution VIII + MEM001.
  - Check: `bash scripts/verify/m019-p00-bash32-compat.sh`
- `bash scripts/verify/m019-p00-phase-suite.sh` reports PASS across all four P00 gate scripts (`m019-p00-payload-shape.sh`, `m019-p00-evaluate-preflight-additivity.sh`, `m019-p00-no-regression.sh`, `m019-p00-bash32-compat.sh`). The phase suite is the single invocation P01's `m019-p01-no-pre-p00-emission.sh` consults to determine P00's `completed_at` epoch.
  - Check: `bash scripts/verify/m019-p00-phase-suite.sh`

### Artifacts

- `scripts/dispatch/build-context.sh` (modify, min 850 lines, contains `First-Turn Completeness`, `<dispatch-volatile>`, `</dispatch-volatile>`, `Parallel Fan-Out`, `parallel_fan_out`)
- `templates/dispatch-prompt.md` (modify, min 60 lines, contains `First-Turn Completeness`, `dispatch-volatile`, positive-example rewrites; no `Don't` outside constitutional-anti-pattern sections)
- `templates/.p00-negative-guidance-retained.txt` (create, min 1 line, contains retained-negative exception whitelist)
- `scripts/engine/intensity-gate.sh` (modify, min 160 lines, contains `adaptive`; must not contain `thinking_budget` or `thinking budget`)
- `scripts/lifecycle/write-permissions.sh` (modify, min 210 lines, contains `_generated_start`, `_generated_end`, `additive`, `AD-7`)
- `.orchestrator/config/pricing.yml` (create, min 30 lines, contains `last_updated:`, `opus`, `sonnet`, `haiku`, `input`, `output`, `ORCH_PRICING_FILE`)
- `scripts/verify/m019-p00-payload-shape.sh` (create, min 180 lines, contains `First-Turn Completeness`, `dispatch-volatile`, `Parallel Fan-Out`, `thinking_budget`, `pricing.yml`, `.p00-negative-guidance-retained.txt`)
- `scripts/verify/m019-p00-evaluate-preflight-additivity.sh` (create, min 100 lines, contains `PreToolUse`, `pre-bash-shape-guard.sh`, `_generated_start`, `_generated_end`, `byte-identical`)
- `scripts/verify/m019-p00-no-regression.sh` (create, min 80 lines, contains `test-s01.sh`, `test-s07.sh`, `anti-pattern-lint.sh`, `run-suite.sh m021 P04`)
- `scripts/verify/m019-p00-bash32-compat.sh` (create, min 60 lines, contains `bash -n`, `declare -A`, `mapfile`, `<(`)
- `scripts/verify/m019-p00-phase-suite.sh` (create, min 50 lines, contains `m019-p00-payload-shape.sh`, `m019-p00-evaluate-preflight-additivity.sh`, `m019-p00-no-regression.sh`, `m019-p00-bash32-compat.sh`, `PASS: 4`)

### Key Links

- `scripts/dispatch/build-context.sh` → `templates/dispatch-prompt.md` (consumes template)
- `scripts/dispatch/build-context.sh` → `templates/context-recipe.yaml` (consumes recipe; reads `parallel_fan_out` field)
- `scripts/lifecycle/write-permissions.sh` → `scripts/lifecycle/evaluate-preflight.sh` (consumer re-runs writer)
- `scripts/verify/m019-p00-payload-shape.sh` → `scripts/dispatch/build-context.sh` (invokes on fixture to assert shape)
- `scripts/verify/m019-p00-payload-shape.sh` → `templates/.p00-negative-guidance-retained.txt` (reads exception whitelist)
- `scripts/verify/m019-p00-payload-shape.sh` → `.orchestrator/config/pricing.yml` (asserts file exists + required keys)
- `scripts/verify/m019-p00-evaluate-preflight-additivity.sh` → `scripts/lifecycle/evaluate-preflight.sh` (drives re-run)
- `scripts/verify/m019-p00-evaluate-preflight-additivity.sh` → `scripts/hooks/pre-bash-shape-guard.sh` (fixture preloads hook registration)
- `scripts/verify/m019-p00-no-regression.sh` → `tests/test-s01.sh`, `tests/test-s07.sh` (invokes full suite)
- `scripts/verify/m019-p00-no-regression.sh` → `scripts/verify/anti-pattern-lint.sh` (invokes linter)
- `scripts/verify/m019-p00-no-regression.sh` → `scripts/verify/run-suite.sh` (invokes M021 P04 suite)
- `scripts/verify/m019-p00-phase-suite.sh` → all four P00 gates (orchestrates)

## Tasks

### T01: Payload structure adaptation (L1 + L2 + L4 in build-context.sh + payload-shape gate)

See `tasks/T01-PLAN.md`.

### T02: Template + intensity-gate sweep (L3 + L5)

See `tasks/T02-PLAN.md`.

### T03: write-permissions.sh additive-merge fix (AD-7) + evaluate-preflight-additivity gate

See `tasks/T03-PLAN.md`.

### T04: .orchestrator/config/pricing.yml populate

See `tasks/T04-PLAN.md`.

### T05: Phase verify-suite (no-regression + bash32-compat + phase-suite)

See `tasks/T05-PLAN.md`.

## Task Dependencies

```
T01 → T05
T02 → T05
T03 → T05
T04 → T05
```

T01 (payload adaptation in `build-context.sh`) and T02 (template sweep) are coupled via the template file `templates/dispatch-prompt.md` — T01 adds the new `## First-Turn Completeness`, `<dispatch-volatile>` markers, and `## Parallel Fan-Out` directives to the emitted payload (mostly in `build-context.sh`, with template shape declared in `dispatch-prompt.md`). T02 handles the L3 (thinking_budget removal) and L5 (positive-examples) rewrites of `dispatch-prompt.md` and the `intensity-gate.sh` thinking-nudge pass. Both touch `templates/dispatch-prompt.md` — T01 owns the new-section additions, T02 owns the rewrite of pre-existing expressive guidance. They must land in dependency order T01 → T02 to avoid merge conflict on the same file (orchestrator enforces serial dispatch per AD-1; this note documents the file-level seam).

T03 (write-permissions additive-merge + preflight-additivity gate) and T04 (pricing.yml populate) are independent of T01/T02 — disjoint files. They may run in any order after T01 and T02 begin; serial dispatch resolves ordering mechanically.

T05 (regression + bash32-compat + phase-suite gates) depends on ALL four prior tasks because its assertions consult every P00 artifact. T05 is the final gate — its PASS is P00's `completed_at` epoch for P01's no-pre-p00-emission gate (SC-12).

Actual dispatch order (serial): T01 → T02 → T03 → T04 → T05.

## Files Likely Touched

- `scripts/dispatch/build-context.sh` (modify — L1 first-turn block, L2 stable/volatile ordering + `<dispatch-volatile>` markers, L4 parallel-fan-out directive)
- `templates/dispatch-prompt.md` (modify — add shape markers for new sections T01 emits; rewrite expressive guidance positively T02)
- `templates/.p00-negative-guidance-retained.txt` (create — exception whitelist for retained negatives)
- `scripts/engine/intensity-gate.sh` (modify — sweep-confirm no `thinking_budget`; any thinking-rate guidance becomes adaptive prompt nudge)
- `scripts/lifecycle/write-permissions.sh` (modify — AD-7 additive-merge with `_generated_start`/`_generated_end` sentinels)
- `.orchestrator/config/pricing.yml` (create — Anthropic Opus 4.7 / Sonnet 4.6 / Haiku 4.5 rates with `last_updated`)
- `scripts/verify/m019-p00-payload-shape.sh` (create — L1–L5 invariants + pricing.yml existence)
- `scripts/verify/m019-p00-evaluate-preflight-additivity.sh` (create — AD-7 byte-identical preservation check)
- `scripts/verify/m019-p00-no-regression.sh` (create — wraps test-s01..s07 + anti-pattern-lint + m021 P04 suite)
- `scripts/verify/m019-p00-bash32-compat.sh` (create — scans all P00-touched/created .sh files)
- `scripts/verify/m019-p00-phase-suite.sh` (create — orchestrates the four P00 gate scripts)

## Boundary Assertion

- **Produces exactly**: adaptation in 3 existing scripts (`build-context.sh`, `intensity-gate.sh`, `write-permissions.sh`), rewrite of 1 template (`dispatch-prompt.md`), 1 new pricing config (`pricing.yml`), 1 new whitelist (`.p00-negative-guidance-retained.txt`), 5 new verify scripts (`m019-p00-*.sh`). No other files modified.
- **Does not touch**: `commands/*.md` user-facing command docs, `references/*.md`, `docs/*.md`, `README.md`, `.orchestrator/memory/constitution.md`, `knowledge/**/MEM*.md`, Constitution XV anti-pattern prohibitions (which remain negative by design), any [M011](../../../../milestones/M011/index.md) already-dispatched payloads (no backfill per D009), the P01 Tier 1 emitter code (P01 ships that).
- **Consumes**: existing pre-adaptation `scripts/dispatch/build-context.sh` structure, existing `scripts/engine/intensity-gate.sh` prompts, existing template set, existing `tests/test-s01.sh`..`tests/test-s07.sh`, M021 `scripts/hooks/pre-bash-shape-guard.sh` + widened `.claude/settings.json` allow-list, M021 `scripts/verify/anti-pattern-lint.sh` gate, `.orchestrator/scratch/articles-synthesis-2026-04-17.md` as L1–L5 source material.
- **Scope of enforcement (linter)**: P00-authored verify script internals run through the M021 P03 hook via the permission system, but the MEM004 + AP-004 carve-out applies — verify-script internals may use `$()`, pipes, subshells, heredocs freely. Enforcement applies to inline agent tool-call sites, not verification-script internals. The Truth `Check:` commands themselves, however, are single-script-file shape per AD-19.
- **No SUMMARY in P00 scope**: `P00-SUMMARY.md` is produced by the standard phase-close workflow after T05 gates PASS — not by any P00 task directly.
- **No drift into Tier 2/3 surfaces**: No `orchestrator:cost` command, no rollup script, no efficiency footer, no anomaly checks, no backend-actuals adapters, no UI. Any task-level proposal to add these fails the must-haves.
