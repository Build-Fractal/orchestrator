---
schema_version: "1.0"
type: roadmap
milestone: "M005"
feature_ref: "005-hardening-integration-prep"
feature_spec: null
vision: "Harden the M004 engine architecture with content-hash idempotency, cost transparency, pure transform extraction, autonomy permission generation, and formalized interfaces — establishing the concrete integration seam for Conversus deliberation gates and future execution providers, and making Tier C auto mode genuinely unattended."
tier: "C"
created_at: "2026-04-10T23:00:00Z"
updated_at: "2026-04-10T23:55:00Z"
---

## Phases

- [x] **P01**: Content-Hash Idempotency — "Knowledge entries include a `content_hash: sha256:...` field in frontmatter; rebuild-index.sh uses hashes to detect actual changes; dispatch results recorded as `outcome: unchanged` when agent output hash matches prior dispatch — enabling stagnation signal without re-reading full content."
  - Risk: medium
  - Depends: none
  - Boundary Map:
    - Produces:
      - Updated knowledge entry frontmatter schema — adds `content_hash` field
      - Updated `scripts/knowledge/create-entry.sh` — computes and writes content_hash
      - Updated `scripts/knowledge/update-entry.sh` — recomputes hash on content change
      - Updated `scripts/knowledge/rebuild-index.sh` — detects changed vs unchanged entries via hash comparison
      - Hash utility function in `scripts/lib/hash.sh` — `compute_content_hash` (SHA-256 of body, formatted as `sha256:{hex}`), double-sourcing guard
      - Updated `scripts/lifecycle/record-result.sh` — records `outcome: unchanged` when output hash matches prior
    - Consumes:
      - Existing knowledge scripts (from [M002](../../milestones/M002/index.md))
      - `scripts/lib/errors.sh` (from [M004](../../milestones/M004/index.md) P02) — emit_result on completion

- [x] **P02**: Cost Transparency — "Execution-log.jsonl entries include `cost_source` field (estimated/reported/unknown); aggregate-metrics.sh distinguishes unknown costs from zero costs; telemetry dashboard-ready output groups by cost accuracy."
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces:
      - Updated `scripts/telemetry/record-telemetry.sh` — adds `cost_source` field to JSONL entries
      - Updated `scripts/telemetry/aggregate-metrics.sh` — groups by cost_source, reports estimated vs reported accuracy
      - Updated execution-log.jsonl schema documentation — null = unknown, 0 = free, cost_source enum
    - Consumes:
      - Existing telemetry scripts (from M002)
      - `scripts/lib/errors.sh` (from M004 P02)

- [x] **P03**: Pure Transform Extraction — "Core payload transforms (section assembly, manifest building, compression steps) extracted into sourced lib/ functions that take stdin and return stdout with no file I/O — independently testable via pipe chains."
  - Risk: medium
  - Depends: none (operates on M004 P05 refactored scripts)
  - Boundary Map:
    - Produces:
      - `scripts/lib/payload-transforms.sh` — pure functions: `assemble_section`, `drop_by_priority`, `summarize_section`, `drop_lowest_confidence`, double-sourcing guard
      - `scripts/lib/manifest-builder.sh` — pure functions: `build_manifest_header`, `compute_section_tokens`, `format_manifest_row`, double-sourcing guard
      - Refactored `scripts/dispatch/build-context.sh` — delegates to lib functions for transforms
      - Refactored `scripts/dispatch/compress-payload.sh` — delegates to lib functions for compression steps
    - Consumes:
      - Refactored dispatch scripts (from M004 P05)
      - `scripts/lib/recipe-parser.sh` (from M004 P04)

- [x] **P04**: Agent Instruction Schema — "A template at `templates/instruction-schema.md` defines required sections (Context, Task, Constraints, Verification, Output Format) and optional sections (Prior Art, Related Knowledge); a conformance check in run-doctor.sh verifies instruction files match the schema."
  - Risk: medium
  - Depends: none
  - Boundary Map:
    - Produces:
      - `templates/instruction-schema.md` — declared schema with required and optional section headings, field descriptions, examples
      - `scripts/diagnostics/check-instructions.sh` — static conformance check: greps instruction files for required section headings, reports missing sections
      - Updated `scripts/diagnostics/run-doctor.sh` — runs instruction conformance check
      - At least 2 existing task plan templates updated to conform (progressive migration start)
    - Consumes: nothing (standalone, references constitution Principle XIII)

- [x] **P05**: Gate Verdict Protocol and Provider Convention — "Hook scripts can return structured verdicts (PASS/BLOCK/WARN/NEEDS_REVIEW) via a documented protocol; execution providers follow a documented shell convention (arguments, env vars, output path); run-doctor.sh validates provider scripts against the convention."
  - Risk: medium
  - Depends: P01 (hash utility), P02 (cost source)
  - Boundary Map:
    - Produces:
      - `scripts/lib/verdicts.sh` — verdict protocol functions: `emit_verdict`, `parse_verdict`, verdict constants (PASS, BLOCK, WARN, NEEDS_REVIEW), double-sourcing guard
      - Updated `scripts/lib/hooks.sh` — parses hook stdout for VERDICT lines, maps to block/warn/continue behavior
      - `references/provider-convention.md` — documented shell interface for execution providers (required args, env vars, output format, exit codes)
      - `scripts/diagnostics/check-providers.sh` — validates provider scripts against convention (checks for required argument handling, output path usage)
      - Updated `scripts/diagnostics/run-doctor.sh` — runs provider conformance check
    - Consumes:
      - `scripts/lib/hooks.sh` (from M004 P02)
      - `scripts/lib/hash.sh` (from P01) — providers may report content hashes
      - Cost source enum (from P02) — providers report cost_source alongside cost

- [x] **P06**: Conformance Test Kit Expansion — "run-doctor.sh performs full constitution v2.0 compliance checking: verifies all 13 principles are referenced in active phase plans, all engine-path scripts emit events, all recipes have valid structure, all knowledge entries have content hashes, all JSONL entries have run_id, current autonomy permissions match introspected-generator output, and task plan `Check:` commands do not trip the harness obfuscation heuristic — producing a scored health report."
  - Risk: low
  - Depends: P01, P02, P03, P04, P05, P07
  - Boundary Map:
    - Produces:
      - Updated `scripts/diagnostics/check-constitution.sh` — full v2.0 principle coverage check across plans
      - Updated `scripts/diagnostics/check-events.sh` — verifies emit_event presence in all engine-path scripts
      - `scripts/diagnostics/check-hashes.sh` — verifies all knowledge entries have valid content_hash fields
      - `scripts/diagnostics/check-run-ids.sh` — verifies recent JSONL entries include run_id field
      - `scripts/diagnostics/check-plans.sh` — advisory lint over task plan `Check:` commands AND inline ```` ```bash ```` verification blocks (per AD-19, expanded trigger set). Flags the full AD-19 trigger list: `bash -c '` with embedded quoted character classes or escape sequences; `&&`/`||` chained compound bash invocations beyond a trivial two-token pair; heredocs containing bash expansion; **plain `(…)` subshells that source a library or contain pipes**; **command substitution `$(…)` containing pipes**; **process substitution `<(…)` / `>(…)`**; **`cmd <file` input redirection nested inside `$(…)`**; **compound `;`-separated statements with more than two commands**; **inline `for`/`while`/`if` blocks**. Emits `DOCTOR:PLANS status=<ok|warn> heuristic_risk=N trigger=<class>`. Advisory only — reports warnings but does not fail the doctor. Assumes P07's shape guidance (`commands/plan-phase.md` + templates) has landed so that any flagged shape represents author drift from the documented convention, not a pre-existing acceptable state.
      - Updated `scripts/diagnostics/run-doctor.sh` — aggregates all checks (including P07's permission drift check and the new task plan shape check) into scored health report (checks passed / total checks)
      - Updated `extension.yml` — registers new diagnostic scripts
    - Consumes:
      - All prior phases' outputs for validation
      - `scripts/diagnostics/check-permissions.sh` (from P07) — wired into the aggregated doctor report as the permission drift signal (FR-8)
      - Shape guidance in `commands/plan-phase.md` and the phase-plan / task-plan templates (from P07) — establishes the convention that `check-plans.sh` lints against

- [x] **P07**: Autonomy Permission Generator — "A developer runs `bash scripts/lifecycle/generate-permissions.sh` on a Node.js project with a Makefile and the script emits a canonical JSON permissions object to stdout that includes every script from extension.yml, every package.json script key, every Makefile target, the comprehensive deny list, and a tier-appropriate defaultMode — running twice with unchanged project state produces byte-identical output, and `bash scripts/diagnostics/check-permissions.sh` reports `DOCTOR:PERMISSIONS status=ok gaps=0 stale=0`."
  - Risk: medium
  - Depends: none within M005 (parallel track — independent of M005 P01-P04). Cross-milestone: consumes M004 P02 (errors.sh, events.sh) and M004 P04 (recipe-parser.sh) — cannot start until both are committed.
  - Boundary Map:
    - Produces:
      - `scripts/lifecycle/generate-permissions.sh` — project-introspecting permission generator (FR-2). Reads package.json scripts / yarn.lock / pnpm-lock.yaml, Makefile targets, `orchestrator-config.yml` verification_commands, `extension.yml` provides.scripts, toolchain config files (tsconfig.json, Cargo.toml, go.mod, pyproject.toml, Gemfile, .eslintrc*, .prettierrc*, jest.config*, vitest.config*, docker-compose.yml, supabase/config.toml), and agent host markers (.claude/, .cursor/, .github/copilot/). Emits canonical JSON permissions object to stdout per AD-16 format. Idempotent. No side effects (reads only; writing is P07's separate script). Bash 3.2 compatible. Works without jq. Always runs with graceful per-source fallback (AD-11) — no "minimal environment" mode. **Does not detect or emit GSD-specific patterns** (no `.gsd/` introspection, no `Skill(gsd:*)`, no GSD bash patterns — per AD-10).
      - `scripts/lifecycle/write-permissions.sh` — agent-host translator (FR-10). Reads canonical permissions from stdin or file, detects target host, writes `.claude/settings.json` for Claude Code (other hosts pluggable). Embeds `_generated_by: "speckit-orchestrator"`, `_generated_at` ISO-8601, and `_autonomy_mode` markers. When target file already exists without the `_generated_by` marker, merges generated allow patterns into the existing allow list rather than overwriting (user-authored respect, per FR-6).
      - `scripts/diagnostics/check-permissions.sh` — permission drift detector (FR-8). Compares the current `.claude/settings.json` to what `generate-permissions.sh` would produce. Reports missing patterns (scripts without allow entries), stale patterns (allow entries for deleted scripts), and deny-list gaps. Emits structured result: `DOCTOR:PERMISSIONS status=<ok|drift|missing> gaps=N stale=N`. Consumed by P06 run-doctor.sh aggregation.
      - `templates/autonomy-defaults.yaml` — declarative policy file (Principle X: Templating Over Inference). Declares tier-to-mode mapping (A→minimal, B→standard, C→full), baseline deny list, introspection rules (package.json key extraction patterns, toolchain config file markers, agent host marker directories), and compound-command / shell-builtin allow patterns. **Baseline also enumerates system-temp-directory allow patterns** (`/tmp/**` and macOS `/var/folders/**` reads/writes plus `Read(//tmp/**)`, `Read(//private/tmp/**)`, `Read(//var/folders/**)`, per AD-20) **and orchestrator env-prefix script-invocation allow patterns** (`ORCH_*=* bash scripts/*`, two-variable form, `.specify/*` equivalents, per AD-21) since these are orchestrator-invariant and always required for unattended execution regardless of project state. Consumed by generate-permissions.sh; no rules hardcoded in scripts.
      - Updated `templates/orchestrator-config-default.yml` — adds `autonomy:` section with `mode`, `generate_on_init`, `deny_patterns`, `extra_allow` keys (FR-1). Default values are tier-appropriate (Tier C gets `mode: full`, `generate_on_init: true`).
      - Updated `extension.yml` — registers three new scripts under `provides.scripts`; adds `autonomy` block to `config_schema` (FR-1 four-layer resolution: env > .local > project > defaults).
      - Updated `commands/auto.md` — rewrites Section "Permission Pre-Flight" per FR-6. Reads autonomy config. If `.claude/settings.json` exists and has the `_generated_by` marker, regenerates (catches toolchain changes between sessions). If exists but user-authored, merges orchestrator allow patterns into existing list without overwriting and warns on gaps. If absent, generates from introspection and writes. Validates completeness after write (every extension.yml script has a matching allow pattern). **Also adds a "Known Limitations: Harness Safety Heuristics" subsection** (per AD-19) that names the residual prompt class (inline compound bash, expansion-obfuscation shapes), explains that this sits *above* the allow list and cannot be disabled from `settings.json`, points developers to the script-file verification shape as the remedy, and cross-references the P06 `check-plans.sh` advisory lint for pre-flight detection.
      - Updated `commands/plan-phase.md` — Truths `Check:` guidance (per AD-19, full trigger enumeration) explicitly forbids: inline compound bash blocks; `bash -c '...' && bash -c '...'` chains; plain `(…)` subshells sourcing libraries or containing pipes; command substitution `$(…)` containing pipes; process substitution `<(…)` / `>(…)`; `cmd <file` input redirection inside `$(…)`; compound `;`-separated statements with more than two commands; inline `for`/`while`/`if` blocks. Directs authors to use single-script-file invocations (e.g., `bash scripts/verify/P##-T##-verify.sh` or the general-purpose `bash scripts/verify/task-verify.sh <phase-dir> <task-id>` if produced) for any multi-step verification. Includes a brief explanation of *why* (harness obfuscation heuristic) so downstream planners can judge edge cases rather than mechanically following the rule, and a cross-reference to the AD-19 observation log so the trigger list stays honest as the harness evolves.
      - Updated `templates/phase-plan.md` — Truths and Must-Haves examples exclusively show the script-file shape. No `&&`-chained `bash -c` blocks, no heredoc-embedded quoted regex. Any placeholder verification command in the template is a single simple invocation.
      - Updated `templates/task-plan.md` — Verification / Must-Haves section example uses the script-file shape. Template comments call out AD-19 as the source of the constraint.
      - Updated `commands/evaluate.md` — triggers permission generation during initial scaffold when `autonomy.generate_on_init` is true and tier default applies (FR-7).
      - Updated `references/installation.md` — documents autonomy configuration: the three modes, introspection sources, `deny_patterns` / `extra_allow` overrides, drift detection via doctor, and the harness-heuristic limitation (cross-references AD-19 and the task plan shape guidance).
    - Consumes:
      - `extension.yml` — canonical list of orchestrator scripts (Principle XI: Single Source of Truth). The introspector does NOT maintain a parallel script list.
      - `templates/claude-settings.json` — fallback template already shipped in MVP commit `50f7098`, with GSD patterns removed per AD-10. Used only as nuclear fallback when bash itself cannot execute (per AD-11). Generator output is a superset of this template.
      - `scripts/lib/errors.sh` (from M004 P02) — generate-permissions.sh, write-permissions.sh, and check-permissions.sh all emit structured `emit_result` lines on completion.
      - `scripts/lib/events.sh` (from M004 P02) — emit events during generation for debugging (`EVENT:introspection source=package.json entries=N`).
      - `scripts/lib/recipe-parser.sh` (from M004 P04) — YAML reader for `templates/autonomy-defaults.yaml`. Per AD-14, P07 reuses the existing parser rather than writing a narrower one. The policy file conforms to the same YAML schema constraints as `context-recipe.yaml` (max 2 levels of nesting, comma-separated inline arrays, jq-free).
      - `scripts/capabilities/detect-capabilities.sh` — extended for agent host detection (`.claude/`, `.cursor/`, `.github/copilot/`) so generator knows which host format to emit. Not extended for GSD detection (per AD-10).

## Dependency Graph

```
P01 (Hashes) ──────────────────→ P05 (Verdicts & Providers)
P02 (Cost) ────────────────────→ P05
P03 (Pure Transforms)               │
P04 (Instruction Schema)            │
P07 (Autonomy Generator)            │
                                     ▼
P01, P02, P03, P04, P05, P07 ──→ P06 (Conformance)
```

P01, P02, P03, P04, P07 are all independent — can execute concurrently.
P05 depends on P01 and P02.
P06 depends on all prior phases (including P07, which supplies the permission drift check).

## Execution Order

1. **P01** (Hashes), **P02** (Cost), **P03** (Pure Transforms), **P04** (Instruction Schema), **P07** (Autonomy Generator) — all independent, can execute concurrently or in any order. P01/P03/P07 are medium risk; P02/P04 are low risk.
2. **P05** (Verdicts & Providers) — depends on P01 and P02. Medium risk.
3. **P06** (Conformance Expansion) — depends on all prior phases including P07 (wires the permission drift check into the aggregated doctor report). Low risk. Executes last.

## Validation

- **No conflicting producers**: PASS — P01 touches knowledge scripts + hash lib. P02 touches telemetry scripts. P03 touches dispatch lib functions. P04 produces instruction schema + check. P05 produces verdict lib + provider convention. P06 produces constitution/event/hash/run-id diagnostic checks and aggregates all checks into the doctor. P07 produces the lifecycle generator, host translator, permission drift check, autonomy defaults template, and autonomy config schema. The only cross-phase touch is P07 `extension.yml` (adds autonomy schema + three scripts) and P06 `extension.yml` (registers new diagnostic scripts) — these are additive non-overlapping sections of the same file.

- **All consumed items have producers**: PASS — P05 consumes P01 hash lib and P02 cost source. P06 consumes all prior outputs plus `check-permissions.sh` from P07. P07 consumes `extension.yml` (existing), `templates/claude-settings.json` (MVP from commit `50f7098`), M004 P02 error/event libs, and existing `detect-capabilities.sh`. All satisfied.

- **DAG is acyclic**: PASS — {P01, P02, P03, P04, P07} → {P05} → {P06}. P07 is an additional independent leaf that feeds into P06 alongside the existing dependencies. No cycles introduced.
