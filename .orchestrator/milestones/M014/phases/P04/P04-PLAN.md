---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M014"
goal: "Ship FR-5 full complexity probe + FR-6 spec-pressure-test conversus preset + FR-7 LLM-assisted splitter + FR-14 three-case `--amend` semantics + US-3 three-way (y/n/d) prompt wiring, all landing on the P01 stubbed caller contract without breaking it and without modifying the M011/P07 conversus adapter. Complete `references/spec-management.md` (SC-11) and close out `RUNTIME-ASSUMPTIONS.md` FR-5-full + FR-7 entries (SC-15)."
demo_sentence: "A maintainer runs `bash scripts/specify/specify.sh --description '<40-FR, 6-user-story prose with explicit contradiction signals like: the command should both prompt interactively and never prompt>' --slug contradictory-test --yes` on a clean project; the scaffolded spec trips the pinned `fr_count` threshold (FR count ≥ 15 OR user_story_count ≥ 5 OR contradiction_signals ≥ 1) so `scripts/knowledge/spec-complexity-probe.sh` emits `probe=above-threshold reason=contradiction_signals>=1` on stdout with structured fields on stderr; `specify.sh` prints the three-way prompt `conversus pressure-test recommended (contradiction_signals>=1). [y/n/d]`; with `--yes`, default `n` is chosen silently so the scaffold completes; the maintainer then re-runs without `--yes`, answers `y`, and `scripts/dispatch/adapters/tool/conversus.sh gate --strict spec-pressure-test specs/<NNN>-contradictory-test/spec.md specs/<NNN>-contradictory-test/conversus/summary/final.md` is invoked with `CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=BLOCK` under test, `gate-result.md` lands at `specs/<NNN>-contradictory-test/conversus/summary/final.md` with `verdict: BLOCK`, a `conversus_gate_invocation` record with `{gate_id: 'spec-pressure-test', verdict: 'BLOCK', elapsed_ms, llm_calls, estimated_cost_usd}` appends to `.orchestrator/execution-log.jsonl`; a second run with `d` produces `.orchestrator/specify/decomposition/<source-id>/manifest.md` naming 2–N sub-specs; a third run against an existing spec with `--amend` applied to a mix of (a) all-placeholder, (b) partial-placeholder, (c) fully-authored sections preserves `shasum` of bytes in cases (b) + (c) and only re-probes changed sections; `bash scripts/verify/m014-p04-phase-suite.sh` exits 0 across all gates."
risk: "medium"
depends_on: ["P01"]
---

## Must-Haves

<!-- Every Check command is a single-invocation script-file shape per AD-19.
     No inline compound bash, no plain subshells, no $(…|…), no <(…).
     All P04 verification logic lives inside scripts/verify/m014-p04-*.sh. -->

### Truths

- `.orchestrator/config.yml` `specify.complexity_thresholds:` has calibration-pinned non-zero values that produce `below-threshold` for M016 + M021 (hardening specs — small, coherent, no contradictions) and `above-threshold` for M013, M011, and M024 per the T01 calibration memo (at least one retrospective label per category). The `contradiction_signal_count` threshold is `1` (any LLM-detected signal trips the probe under CC). A top-level `specify.contradiction_signal_criterion: cc-llm-or-zero` key documents the CC-runtime-gated source of the signal count. `.orchestrator/milestones/M014/phases/P04/CALIBRATION-MEMO.md` documents the retrospective labels, the numeric cutoffs, and the design rationale.
  - Check: `bash scripts/verify/m014-p04-complexity-thresholds-pinned.sh`

- `scripts/knowledge/spec-complexity-probe.sh <spec-path>` (body fully replaced; P01 stub bytes gone) emits exactly one line of the form `probe=below-threshold` **or** `probe=above-threshold reason=<single-criterion-name>` to stdout, and exactly four `key=value` lines to stderr (`fr_count=<N>`, `user_story_count=<N>`, `todo_count=<N>`, `contradiction_signals=<N>`). Heuristic counts (FR count via `grep -cE '^- \*\*FR-[0-9]+|^### FR-[0-9]+|^\*\*FR-[0-9]+'`, user-story count via `grep -cE '^### User (Story|Scenario)'`, `<TODO>` count via `grep -cE '<TODO'`) are runtime-agnostic. `contradiction_signals` is zero under Codex/Cursor and zero when `SPEC_COMPLEXITY_PROBE_LLM=0`; under Claude Code (detected by `CLAUDE_CODE_RUNTIME=1` env var or resolved from `scripts/lifecycle/detect-capabilities.sh`) the probe invokes an LLM pass via `scripts/dispatch/dispatch-interface.sh` against `templates/spec-complexity-contradiction-prompt.md` and counts returned signals. Exit 0 on success; 1 on missing/unreadable input. Emits one `spec_complexity_probe` JSONL record to `.orchestrator/execution-log.jsonl` with `{type: "spec_complexity_probe", spec_path, verdict, fr_count, user_story_count, todo_count, contradiction_signals, elapsed_ms, source: "runtime"}`.
  - Check: `bash scripts/verify/m014-p04-complexity-probe-full.sh`

- `templates/conversus-presets/spec-pressure-test.yml` is a valid conversus preset in the **red-blue** deliberation mode (charter-adversarial: blue argues the draft is shippable; red argues the draft has fatal ambiguity / contradiction / scope overreach). Preset YAML has `preset_name: spec-pressure-test`, `description:`, two `agents:` entries (`red-advocate`, `blue-advocate`) each with a distinct `system_prompt:` keyed to the orchestrator constitution (Principle II Evidence Before Claims, Principle III Design Before Code, Principle XV Surgical Precision), one `arbiter:` with `grounding_file: .orchestrator/memory/constitution.md` and `verdict_contract: PASS|BLOCK`, and an `output:` section naming `templates/gate-result.md` + required fields `verdict disputes rationale source_hash`. Consumed by `scripts/dispatch/adapters/tool/conversus.sh gate --strict spec-pressure-test <spec> <output>` **without any adapter modification** (D007 reuse discipline).
  - Check: `bash scripts/verify/m014-p04-pressure-test-preset.sh`

- `commands/specify.md` Workflow step 8 describes the three-way prompt flow: on `probe=above-threshold`, print a single-line prompt `conversus pressure-test recommended (<reason>). [y/n/d]`; in `--yes` mode, the default answer is `n` (silent), preserving the FR-15 zero-prompt discipline. The command doc also enumerates the `d` path (calls `split <path>`) and the `y` path (invokes `scripts/dispatch/adapters/tool/conversus.sh gate --strict spec-pressure-test <spec> <output>` with the output path `specs/<NNN>-<slug>/conversus/summary/final.md`). The doc's Subcommand surfaces block drops the `(P01 ships the surface; full semantics in later phases)` language for `--amend` and `split`, replacing it with the FR-14 three-case + FR-7 splitter descriptions.
  - Check: `bash scripts/verify/m014-p04-specify-command-wiring.sh`

- `scripts/specify/specify.sh` create-path wires the three-way prompt between steps 8 (probe invocation) and 9 (observability emission): captures `probe=` verdict on stdout of `scripts/knowledge/spec-complexity-probe.sh`; if `below-threshold`, proceeds silently; if `above-threshold`, prints the one-line prompt to stderr and reads one character from stdin (`y`/`n`/`d`). Under `--yes`, defaults to `n` silently. On `y`, invokes `scripts/dispatch/adapters/tool/conversus.sh gate --strict spec-pressure-test <spec-path> <out-path>`; records exit code (0 PASS → proceed; 0 SKIPPED → warn + proceed; 2 BLOCK → record + surface diagnostic + exit 0; 1 ERROR → surface diagnostic + exit 1). On `d`, invokes `bash scripts/specify/specify.sh split <spec-path>` and exits 0 with the manifest path on stdout. On `n`, proceeds silently. One `conversus_gate_invocation` JSONL record is appended per `y` path invocation with `{type: "conversus_gate_invocation", gate_id: "spec-pressure-test", adapter_version, verdict, llm_calls, elapsed_ms, estimated_cost_usd, source: "runtime"}` per FR-16 + M013/FR-17 shape. The top-level `unit_close` record gains two fields: `conversus_invocations=<N>` and `adapter_verdicts=<CSV>`.
  - Check: `bash scripts/verify/m014-p04-three-way-prompt.sh`

- `scripts/specify/specify.sh split <spec-path>` subcommand body (P01 hard-stub fully replaced) invokes an LLM-assisted splitter under Claude Code runtime via `scripts/dispatch/dispatch-interface.sh` against `templates/spec-splitter-prompt.md`. The splitter reads the source spec, proposes 2–N coherent sub-specs, and writes a manifest to `.orchestrator/specify/decomposition/<source-id>/manifest.md` (interim path per FR-7; schema write-forward-compatible with M024's `.orchestrator/intake/<id>/decomposition.md`). Manifest shape is YAML-frontmatter + body with each proposed sub-spec entry naming `slug`, `slice` (source-description slice), `inherited_user_stories`, and `rationale`. Under Codex/Cursor, the command prints `split: LLM-assisted splitter is Claude Code only in v1 (see RUNTIME-ASSUMPTIONS.md FR-7); fall back to manual spec decomposition` to stderr and exits 3 (distinct from P01's stub exit 2, which signaled "not yet implemented"). Exit 0 on CC-success; 1 on malformed LLM response or manifest-write failure; 3 on Codex/Cursor runtime. `--dry-run` emits a FR-19 JSONL manifest record (`action_type: "propose-decomposition"`) per proposed sub-spec and writes no disk artifact.
  - Check: `bash scripts/verify/m014-p04-split-subcommand.sh`

- `scripts/specify/specify.sh --amend <path>` subcommand body (P01 diagnostic-stub fully replaced) ships the FR-14 three-case semantics: for each top-level section (delimited by `^## ` headings, excluding frontmatter), classify as (a) all-placeholder — only `<TODO>` markers, zero authored prose bytes → re-run FR-3 LLM-fill under CC (skip under Codex/Cursor per RUNTIME-ASSUMPTIONS.md FR-3); (b) partial-placeholder — both `<TODO>` markers and authored prose present → leave both bytes unchanged, log a one-line diagnostic `amend: section '<name>' partial (case b) — operator must resolve manually`; (c) fully-authored — zero `<TODO>` markers → leave unchanged byte-identically. "Changed section" (US-3 AS-7 re-probe gate) is computed as: `<TODO>` count changed OR `shasum -a 256` of authored (non-placeholder) prose bytes changed. Re-probe fires only on changed sections, preserving prior deliberation state per CON-5 + CON-8. `--dry-run` emits a FR-19 JSONL manifest record per would-be-changed section (`action_type: "amend-section"` with the per-section case). SC-14 byte-preservation invariant: `shasum` of pre-amend bytes of cases (b) + (c) equals post-amend bytes.
  - Check: `bash scripts/verify/m014-p04-amend-three-case.sh`

- `RUNTIME-ASSUMPTIONS.md` contains the FR-5-full entry (replaces P01 FR-5 stub entry body while preserving the FR-5 heading and append-only discipline) and a new FR-7 entry (splitter). FR-5-full names the LLM round-trip via `scripts/dispatch/dispatch-interface.sh` + `templates/spec-complexity-contradiction-prompt.md` as the CC assumption; zero-signal heuristic-only pass as the Codex/Cursor fallback; M014/P04 as the introducing phase; M009 runtime-parity obligation to re-implement contradiction counting. FR-7 names LLM-assisted decomposition via `templates/spec-splitter-prompt.md` as the CC assumption; manual spec decomposition as the Codex/Cursor fallback (exit 3 loudly); M014/P04 as introducing phase; M009 obligation.
  - Check: `bash scripts/verify/m014-p04-runtime-assumptions-fr5-fr7.sh`

- `references/spec-management.md` completes its partial sections (the `<!-- partial: P04 completes with pressure-test + decomposition sections -->` sentinel is removed). Three new top-level sections land: `## Complexity Probe (FR-5)` documents the five heuristic + LLM fields, the pinned thresholds, the CC/Codex runtime split, and the `.orchestrator/config.yml` `specify.complexity_thresholds:` keys. `## Conversus Pressure-Test (US-3, FR-6)` documents the red-blue preset shape, the three-way prompt contract, adapter exit-code handling per M013/FR-13, and the `specs/<NNN>-<slug>/conversus/summary/final.md` output path. `## Decomposition Flow (FR-7)` documents the splitter path, the interim manifest path `.orchestrator/specify/decomposition/<source-id>/manifest.md` + M024 migration note, and the per-sub-spec manifest schema. `## --amend Three-Case Semantics (FR-14)` documents cases (a)/(b)/(c), the changed-section computation, and the SC-14 byte-preservation invariant. The `action_type` table gains three rows: `propose-decomposition` (emitted by `split`), `amend-section` (emitted by `--amend --dry-run`), `invoke-conversus-gate` (emitted by the `y` path `--dry-run`).
  - Check: `bash scripts/verify/m014-p04-spec-management-reference-complete.sh`

- Every new and modified shell script (`scripts/knowledge/spec-complexity-probe.sh`, `scripts/specify/specify.sh`, and every `scripts/verify/m014-p04-*.sh` gate verifier) is Bash 3.2 compatible (no `declare -A`, no `mapfile`, no `${var,,}`, no `<(...)`, no `&>`) and passes `scripts/verify/anti-pattern-lint.sh`.
  - Check: `bash scripts/verify/m014-p04-bash32-and-lint.sh`

- Running `bash scripts/specify/specify.sh --description '<prose>' --slug zero-prompt-p04 --yes --dry-run` against a scratch project emits zero Claude Code approval prompts (SC-7 inherits M016/M021 baseline via M021 prompt-corpus cross-check) and makes zero disk writes. `--yes` auto-selects `n` on the three-way prompt; `--amend --dry-run` and `split --dry-run` also produce no prompts. Verified against `tests/fixtures/m021-prompt-corpus.txt`.
  - Check: `bash scripts/verify/m014-p04-zero-prompts.sh`

- `.orchestrator/execution-log.jsonl` append semantics: one `spec_complexity_probe` record per probe invocation; one `conversus_gate_invocation` record per `y`-path adapter invocation; `unit_close` record gains `conversus_invocations=<N>` and `adapter_verdicts=<CSV>` fields. All fields match the FR-16 shape; records are valid JSONL (one JSON object per line, newline-terminated, no trailing commas). Append failures warn on stderr but do not fail the command (observability is best-effort per references/spec-management.md §Failure Semantics).
  - Check: `bash scripts/verify/m014-p04-observability-records.sh`

- `bash scripts/verify/m014-p04-phase-suite.sh` orchestrates all twelve P04 gates (complexity-thresholds-pinned, complexity-probe-full, pressure-test-preset, specify-command-wiring, three-way-prompt, split-subcommand, amend-three-case, runtime-assumptions-fr5-fr7, spec-management-reference-complete, bash32-and-lint, zero-prompts, observability-records) and exits 0 on green, non-zero with a per-gate breakdown otherwise.
  - Check: `bash scripts/verify/m014-p04-phase-suite.sh`

### Artifacts

- `scripts/knowledge/spec-complexity-probe.sh` (modify — body fully replaced; min 180 lines; contains `probe=above-threshold`) — FR-5 full probe
- `templates/conversus-presets/spec-pressure-test.yml` (create; min 40 lines; contains `red-advocate`) — FR-6 preset (red-blue mode)
- `templates/spec-complexity-contradiction-prompt.md` (create; min 40 lines; contains `contradiction_signal`) — CC LLM prompt body for probe's contradiction-count pass
- `templates/spec-splitter-prompt.md` (create; min 40 lines; contains `sub-spec`) — CC LLM prompt body for FR-7 splitter
- `commands/specify.md` (modify; contains `conversus pressure-test recommended`) — three-way prompt doc + FR-14 + FR-7 descriptions
- `scripts/specify/specify.sh` (modify — body extended; min 420 lines; contains `conversus_gate_invocation`) — three-way prompt wiring + FR-14 amend + FR-7 split
- `.orchestrator/config.yml` (modify — `specify.complexity_thresholds:` re-tuned from all-zero to calibration-pinned values; new `specify.contradiction_signal_criterion: cc-llm-or-zero` key)
- `.orchestrator/milestones/M014/phases/P04/CALIBRATION-MEMO.md` (create; min 120 lines; contains "retrospective labels") — T01 design memo per roadmap directive
- `RUNTIME-ASSUMPTIONS.md` (modify — FR-5 entry body replaced with FR-5-full; FR-7 entry appended)
- `references/spec-management.md` (modify — three new top-level sections; partial-sentinel removed; action_type table extended)
- `scripts/verify/m014-p04-complexity-thresholds-pinned.sh` (create; min 30 lines; contains `complexity_thresholds`)
- `scripts/verify/m014-p04-complexity-probe-full.sh` (create; min 80 lines; contains `above-threshold`)
- `scripts/verify/m014-p04-pressure-test-preset.sh` (create; min 30 lines; contains `red-advocate`)
- `scripts/verify/m014-p04-specify-command-wiring.sh` (create; min 30 lines; contains `conversus pressure-test recommended`)
- `scripts/verify/m014-p04-three-way-prompt.sh` (create; min 80 lines; contains `CONVERSUS_STUB`)
- `scripts/verify/m014-p04-split-subcommand.sh` (create; min 50 lines; contains `propose-decomposition`)
- `scripts/verify/m014-p04-amend-three-case.sh` (create; min 80 lines; contains `shasum`)
- `scripts/verify/m014-p04-runtime-assumptions-fr5-fr7.sh` (create; min 30 lines; contains `FR-7`)
- `scripts/verify/m014-p04-spec-management-reference-complete.sh` (create; min 30 lines; contains `Decomposition Flow`)
- `scripts/verify/m014-p04-bash32-and-lint.sh` (create; min 40 lines; contains `anti-pattern-lint`)
- `scripts/verify/m014-p04-zero-prompts.sh` (create; min 30 lines; contains `m021-prompt-corpus`)
- `scripts/verify/m014-p04-observability-records.sh` (create; min 50 lines; contains `conversus_gate_invocation`)
- `scripts/verify/m014-p04-phase-suite.sh` (create; min 40 lines; contains `m014-p04`)
- `tests/fixtures/m014-p04/` (create — directory)
- `tests/fixtures/m014-p04/contradictory-prose.txt` (create; min 40 lines) — fixture prose explicitly contradictory for end-to-end `y` path tests
- `tests/fixtures/m014-p04/decomposable-prose.txt` (create; min 60 lines) — fixture prose large enough to exercise `d` path splitter
- `tests/fixtures/m014-p04/amend-seed-spec.md` (create) — seed spec with a mix of (a)/(b)/(c) sections for FR-14 tests
- `tests/fixtures/m014-p04/corpus-labels.tsv` (create; min 6 lines) — retrospective labels for M011/M013/M016/M021/M022/M024 specs

### Key Links

- `commands/specify.md` → `scripts/knowledge/spec-complexity-probe.sh` (Workflow step 8 invokes probe)
- `commands/specify.md` → `scripts/dispatch/adapters/tool/conversus.sh` (Workflow `y` path invokes adapter with `--strict`)
- `commands/specify.md` → `templates/conversus-presets/spec-pressure-test.yml` (Workflow `y` path names preset)
- `commands/specify.md` → `.orchestrator/specify/decomposition/<source-id>/manifest.md` (Workflow `d` path output)
- `scripts/specify/specify.sh` → `scripts/knowledge/spec-complexity-probe.sh` (invokes at end-of-scaffold)
- `scripts/specify/specify.sh` → `scripts/dispatch/adapters/tool/conversus.sh` (invokes on `y` path)
- `scripts/specify/specify.sh` → `templates/spec-splitter-prompt.md` (invokes via dispatch-interface on `split`)
- `scripts/specify/specify.sh` → `.orchestrator/execution-log.jsonl` (appends unit_close + conversus_gate_invocation)
- `scripts/knowledge/spec-complexity-probe.sh` → `.orchestrator/config.yml` (reads `specify.complexity_thresholds:`)
- `scripts/knowledge/spec-complexity-probe.sh` → `templates/spec-complexity-contradiction-prompt.md` (CC LLM prompt)
- `scripts/knowledge/spec-complexity-probe.sh` → `.orchestrator/execution-log.jsonl` (appends spec_complexity_probe)
- `scripts/knowledge/spec-complexity-probe.sh` → `scripts/dispatch/dispatch-interface.sh` (CC LLM round-trip)
- `RUNTIME-ASSUMPTIONS.md` → `scripts/knowledge/spec-complexity-probe.sh` (FR-5-full entry cross-link)
- `RUNTIME-ASSUMPTIONS.md` → `scripts/specify/specify.sh` (FR-7 splitter entry cross-link)
- `RUNTIME-ASSUMPTIONS.md` → `templates/spec-splitter-prompt.md` (FR-7 CC prompt cross-link)
- `references/spec-management.md` → `templates/conversus-presets/spec-pressure-test.yml` (pressure-test section references preset)
- `references/spec-management.md` → `scripts/dispatch/adapters/tool/conversus.sh` (pressure-test section references adapter)
- `references/spec-management.md` → `.orchestrator/specify/decomposition/` (decomposition section references manifest path)
- `templates/conversus-presets/spec-pressure-test.yml` → `.orchestrator/memory/constitution.md` (arbiter grounding)
- `.orchestrator/milestones/M014/phases/P04/CALIBRATION-MEMO.md` → `.orchestrator/config.yml` (memo cites pinned threshold values)
- `scripts/verify/m014-p04-phase-suite.sh` → `scripts/verify/m014-p04-complexity-thresholds-pinned.sh` (orchestrated gate)
- `scripts/verify/m014-p04-phase-suite.sh` → `scripts/verify/m014-p04-complexity-probe-full.sh` (orchestrated gate)
- `scripts/verify/m014-p04-phase-suite.sh` → `scripts/verify/m014-p04-pressure-test-preset.sh` (orchestrated gate)
- `scripts/verify/m014-p04-phase-suite.sh` → `scripts/verify/m014-p04-specify-command-wiring.sh` (orchestrated gate)
- `scripts/verify/m014-p04-phase-suite.sh` → `scripts/verify/m014-p04-three-way-prompt.sh` (orchestrated gate)
- `scripts/verify/m014-p04-phase-suite.sh` → `scripts/verify/m014-p04-split-subcommand.sh` (orchestrated gate)
- `scripts/verify/m014-p04-phase-suite.sh` → `scripts/verify/m014-p04-amend-three-case.sh` (orchestrated gate)
- `scripts/verify/m014-p04-phase-suite.sh` → `scripts/verify/m014-p04-runtime-assumptions-fr5-fr7.sh` (orchestrated gate)
- `scripts/verify/m014-p04-phase-suite.sh` → `scripts/verify/m014-p04-spec-management-reference-complete.sh` (orchestrated gate)
- `scripts/verify/m014-p04-phase-suite.sh` → `scripts/verify/m014-p04-bash32-and-lint.sh` (orchestrated gate)
- `scripts/verify/m014-p04-phase-suite.sh` → `scripts/verify/m014-p04-zero-prompts.sh` (orchestrated gate)
- `scripts/verify/m014-p04-phase-suite.sh` → `scripts/verify/m014-p04-observability-records.sh` (orchestrated gate)

## Tasks

### T01: Calibration corpus + complexity-threshold pinning in `.orchestrator/config.yml` + `CALIBRATION-MEMO.md` design memo

See `tasks/T01-PLAN.md`.

### T02: Full FR-5 `scripts/knowledge/spec-complexity-probe.sh` body replacement (heuristic counts + runtime-gated LLM contradiction pass + verdict logic + observability emission)

See `tasks/T02-PLAN.md`.

### T03: `templates/conversus-presets/spec-pressure-test.yml` FR-6 red-blue preset + `templates/spec-complexity-contradiction-prompt.md` + `templates/spec-splitter-prompt.md` CC LLM prompt bodies

See `tasks/T03-PLAN.md`.

### T04: `scripts/specify/specify.sh` three-way (y/n/d) prompt wiring + conversus adapter invocation on `y` + `commands/specify.md` Workflow update

See `tasks/T04-PLAN.md`.

### T05: `scripts/specify/specify.sh split` full body (CC LLM splitter + manifest emission + interim path) + `RUNTIME-ASSUMPTIONS.md` FR-7 entry

See `tasks/T05-PLAN.md`.

### T06: `scripts/specify/specify.sh --amend` full FR-14 three-case body + AS-7 deliberation-preservation + `RUNTIME-ASSUMPTIONS.md` FR-5-full entry (replaces stub body) + `references/spec-management.md` completion (SC-11)

See `tasks/T06-PLAN.md`.

### T07: P04 phase verification suite — twelve gates + phase-suite orchestrator

See `tasks/T07-PLAN.md`.

## Task Dependencies

```
T01 ──► T02 ──┐
              │
T03 ──────────┤
              ├─► T04 ──┬─► T05 ──┐
              │         │         │
              │         └─► T06 ──┤
              │                   │
              └──────────────────►├─► T07
```

T01 ships the calibration corpus + memo + pinned thresholds — T02 depends on pinned thresholds to implement the verdict logic. T03 is independent (preset + prompt bodies); parallelizable with T01/T02. T04 depends on T02 (probe output shape) + T03 (preset file existence); wires the three-way prompt. T05 depends on T04 (subcommand dispatch structure) + T03 (splitter prompt); full `split` body. T06 depends on T04 (subcommand dispatch structure); full `--amend` body + RUNTIME-ASSUMPTIONS FR-5-full entry + references/spec-management completion (SC-11). T07 depends on all predecessors and orchestrates the gates. Dispatch may execute T01/T03 in parallel; T02 after T01; T04 after T02 + T03; T05 + T06 in parallel after T04; T07 after all.

## Files Likely Touched

- `scripts/knowledge/spec-complexity-probe.sh` (modify — body fully replaced)
- `templates/conversus-presets/spec-pressure-test.yml` (create)
- `templates/spec-complexity-contradiction-prompt.md` (create)
- `templates/spec-splitter-prompt.md` (create)
- `commands/specify.md` (modify — Workflow + Subcommand sections)
- `scripts/specify/specify.sh` (modify — extended body)
- `.orchestrator/config.yml` (modify — threshold values + `contradiction_signal_criterion` key)
- `.orchestrator/milestones/M014/phases/P04/CALIBRATION-MEMO.md` (create)
- `RUNTIME-ASSUMPTIONS.md` (modify — FR-5 body replaced; FR-7 appended)
- `references/spec-management.md` (modify — complete partial; add four sections; extend action_type table)
- `tests/fixtures/m014-p04/` (create — directory)
- `tests/fixtures/m014-p04/contradictory-prose.txt` (create)
- `tests/fixtures/m014-p04/decomposable-prose.txt` (create)
- `tests/fixtures/m014-p04/amend-seed-spec.md` (create)
- `tests/fixtures/m014-p04/corpus-labels.tsv` (create)
- `scripts/verify/m014-p04-complexity-thresholds-pinned.sh` (create)
- `scripts/verify/m014-p04-complexity-probe-full.sh` (create)
- `scripts/verify/m014-p04-pressure-test-preset.sh` (create)
- `scripts/verify/m014-p04-specify-command-wiring.sh` (create)
- `scripts/verify/m014-p04-three-way-prompt.sh` (create)
- `scripts/verify/m014-p04-split-subcommand.sh` (create)
- `scripts/verify/m014-p04-amend-three-case.sh` (create)
- `scripts/verify/m014-p04-runtime-assumptions-fr5-fr7.sh` (create)
- `scripts/verify/m014-p04-spec-management-reference-complete.sh` (create)
- `scripts/verify/m014-p04-bash32-and-lint.sh` (create)
- `scripts/verify/m014-p04-zero-prompts.sh` (create)
- `scripts/verify/m014-p04-observability-records.sh` (create)
- `scripts/verify/m014-p04-phase-suite.sh` (create)
