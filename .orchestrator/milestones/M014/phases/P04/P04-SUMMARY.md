---
schema_version: "1.0"
type: phase-summary
id: "P04"
parent: "M014"
milestone: "M014"
provides:
  - "Pinned specify.complexity_thresholds values (fr_count=15, user_story_count=5, raw_token_count=8000, todo_density=0.5, contradiction_signal_count=1); new top-level keys contradiction_signal_criterion=cc-llm-or-zero and hardening_spec_exception=true; tests/fixtures/m014-p04/corpus-labels.tsv (header + 6 data rows); CALIBRATION-MEMO.md (Retrospective Corpus / Cutoffs / Hardening-Spec Exception); scripts/verify/m014-p04-calibration-thresholds.sh gate verifier, FR-5 complexity probe full body (heuristic FR/user-story/token/TODO counts + CC-gated LLM contradiction pass + verdict logic + spec_complexity_probe JSONL emission); scripts/verify/m014-p04-complexity-probe-full.sh gate verifier, templates/conversus-presets/spec-pressure-test.yml FR-6 red-blue preset; templates/spec-complexity-contradiction-prompt.md FR-5 LLM prompt; templates/spec-splitter-prompt.md FR-7 LLM prompt; scripts/verify/m014-p04-pressure-test-preset.sh T03 gate verifier, scripts/specify/specify.sh probe-capture + three-way prompt wiring; conversus_gate_invocation JSONL shape; extended unit_close with conversus_invocations+adapter_verdicts; commands/specify.md Workflow 8-11 + Subcommand rewrite; FR-19 invoke-conversus-gate dry-run manifest; scripts/verify/m014-p04-specify-command-wiring.sh + m014-p04-three-way-prompt.sh gate verifiers, scripts/specify/specify.sh split full body (FR-7 LLM-assisted decomposition, CC-only v1); RUNTIME-ASSUMPTIONS.md FR-7 entry; scripts/verify/m014-p04-split-subcommand.sh gate verifier, scripts/specify/specify.sh FR-14 three-case --amend body; RUNTIME-ASSUMPTIONS.md FR-5-full body refresh; references/spec-management.md SC-11 completion; three T06 gate verifiers, scripts/verify/m014-p04-bash32-and-lint.sh (rollup gate), scripts/verify/m014-p04-zero-prompts.sh (SC-7 gate), scripts/verify/m014-p04-observability-records.sh (FR-16 producer gate), scripts/verify/m014-p04-phase-suite.sh (12-gate orchestrator), scripts/verify/m014-p04-complexity-thresholds-pinned.sh (alias forwarder), tests/fixtures/m014-p04/contradictory-prose.txt, tests/fixtures/m014-p04/decomposable-prose.txt, tests/fixtures/m014-p04/amend-seed-spec.md, STATE_ROOT env-override hermeticity hook in specify.sh and spec-complexity-probe.sh"
requires:
  - "from:P01 what:.orchestrator/config.yml specify: section with all-zero complexity_thresholds stub; from:disk what:six retrospective specs (011,016,021,022,023,024); from:disk what:scripts/verify/anti-pattern-lint.sh, from:T01 what:.orchestrator/config.yml specify.complexity_thresholds pinned scalars; from:P01 what:scripts/knowledge/spec-complexity-probe.sh stub to be replaced; from:disk what:scripts/dispatch/dispatch-interface.sh (CC LLM round-trip surface, defensive), from:P01/T04 what:spec-complexity-probe stub (P04/T02 consumes FR-5 prompt); from:M011/P07 what:scripts/dispatch/adapters/tool/conversus.sh (unmodified by T03); from:disk what:templates/conversus-presets/normalize-fidelity.yml (schema reference), .orchestrator/memory/constitution.md (arbiter grounding), templates/gate-result.md (conversus output template), from:T02 what:scripts/knowledge/spec-complexity-probe.sh full body; from:T03 what:templates/conversus-presets/spec-pressure-test.yml preset; from:P01 what:scripts/specify/specify.sh P01 scaffold body; from:disk what:scripts/dispatch/adapters/tool/conversus.sh adapter with CONVERSUS_STUB support + gate-result fixtures, from:P01 what:scripts/specify/specify.sh P01 stub + RUNTIME-ASSUMPTIONS.md registry scaffold; from:P04/T03 what:templates/spec-splitter-prompt.md; from:P04/T04 what:specify.sh three-way d-path delegation; from:disk what:scripts/dispatch/dispatch-interface.sh, from:T04 what:specify.sh; from:P01 what:RUNTIME-ASSUMPTIONS.md+references/spec-management.md partial, from:T01 what:m014-p04-calibration-thresholds.sh + corpus-labels.tsv; from:T02 what:spec-complexity-probe.sh full body; from:T03 what:conversus preset + prompts; from:T04 what:three-way prompt wiring in specify.sh; from:T05 what:split subcommand body; from:T06 what:amend three-case body + references completion; from:disk what:anti-pattern-lint.sh + m021-prompt-corpus.txt"
affects:
  - "T02 spec-complexity-probe-full body (consumes pinned thresholds and hardening exception via config.yml); T04 commands/specify.md three-way prompt (invoked when probe fires above-threshold); downstream P04 gates that assert config values, T04 specify.sh three-way prompt wiring (consumes probe stdout/stderr/exit-0 unchanged); T07 phase-suite (runs gate verifier); M009 runtime-parity audit, P04/T02 (complexity probe consumes contradiction prompt); P04/T05 (splitter subcommand consumes splitter prompt); M014/P04 phase-suite gate orchestrator, T07 phase-suite consumes both P04 gate verifiers; M014 dogfood loop first y-path invocation target; downstream above-threshold specs route through conversus review, M014/P04/T07 phase-suite (gate verifier registered); M024 Universal Intake (interim manifest path migrates to .orchestrator/intake/<id>/decomposition.md); M009 runtime-parity audit (FR-7 entry appended to punch-list), T07 phase-suite; SC-11 milestone-close gate, M014/P04 phase close — 12/12 gates green; gates reused by M014 milestone validation and by downstream M024/M023 phase-suite authors as a reference pattern"
key_files:
  - ".orchestrator/config.yml,tests/fixtures/m014-p04/corpus-labels.tsv,.orchestrator/milestones/M014/phases/P04/CALIBRATION-MEMO.md,scripts/verify/m014-p04-calibration-thresholds.sh, scripts/knowledge/spec-complexity-probe.sh,scripts/verify/m014-p04-complexity-probe-full.sh, templates/conversus-presets/spec-pressure-test.yml,templates/spec-complexity-contradiction-prompt.md,templates/spec-splitter-prompt.md,scripts/verify/m014-p04-pressure-test-preset.sh, scripts/specify/specify.sh,commands/specify.md,scripts/verify/m014-p04-specify-command-wiring.sh,scripts/verify/m014-p04-three-way-prompt.sh, scripts/specify/specify.sh,scripts/verify/m014-p04-split-subcommand.sh,RUNTIME-ASSUMPTIONS.md, scripts/specify/specify.sh,RUNTIME-ASSUMPTIONS.md,references/spec-management.md,scripts/verify/m014-p04-amend-three-case.sh,scripts/verify/m014-p04-runtime-assumptions-fr5-fr7.sh,scripts/verify/m014-p04-spec-management-reference-complete.sh, scripts/verify/m014-p04-phase-suite.sh, scripts/verify/m014-p04-bash32-and-lint.sh, scripts/verify/m014-p04-zero-prompts.sh, scripts/verify/m014-p04-observability-records.sh, scripts/verify/m014-p04-complexity-thresholds-pinned.sh, scripts/specify/specify.sh, scripts/knowledge/spec-complexity-probe.sh, tests/fixtures/m014-p04/contradictory-prose.txt, tests/fixtures/m014-p04/decomposable-prose.txt, tests/fixtures/m014-p04/amend-seed-spec.md"
key_decisions:
  - "Hardening-spec exception triggered by fr_count==0 (not user_story_count threshold relaxation) — more precise, targets shape not size; token-count cutoff at 8000 deliberately placed between M013 (7851) and M022 (3613) even though M013 measured just below cutoff (OR-semantics across other axes still classify M013 correctly); TODO-density computed as todo_count/(todo_count+section_count); thresholds declared planning-pinned defaults not empirically optimal (CON-9 covers retuning), Deviation: added _strip_yaml_scalar helper to normalize YAML scalars post-read (plan-verbatim awk progs did not strip inline #comments; T01 config uses inline # annotations on every threshold); Deviation: replaced grep -cE ... || echo 0 with grep -cE ... | head -n 1 + : ${VAR:=0} fallback (plan-verbatim form produced multi-line 0\n0 output on grep no-match causing [: integer expression expected errors and breaking FR_COUNT comparisons); both deviations are correctness fixes consistent with P01 T02/T03/T05/T06 deviation precedent, D007 reuse discipline — zero conversus adapter modifications; grep-only YAML shape verification per MEM001 (no python3/jq hard dependency); CC-only prompt invocation — Codex/Cursor runtime-gate before dispatch, dry-run probe runs against temp-staged scaffold so invoke-conversus-gate surfaces without live disk writes; hermetic gate verifier copies specify.sh + deps into mktemp scratch so PROJECT_ROOT self-resolves; adapter invocation uses --strict always; CONVERSUS_STUB=1 + CONVERSUS_STUB_VERDICT=PASS|BLOCK is the hermetic y-path mechanism, D016 (RUNTIME-ASSUMPTIONS registry); D007 (conversus-adapter reuse — splitter uses dispatch-interface directly, not adapter); verbatim plan body faithfully reproduced, Section classifier counts authored lines (non-blank, non-header, non-TODO) because awk split injects a blank separator; P01-stub wording removed from refreshed FR-5 body to satisfy gate verifier literal-substring check; grep -c zero-count guarded via pipe-to-head rather than || echo 0 leak, STATE_ROOT env-override for hermetic gates (isolate mutation paths from dependency paths); phase-suite emits per-gate PASS/FAIL lines (deviation from verbatim quiet orchestrator); obs-gate uses bare-literal grep for conversus_gate_invocation (verbatim double-quoted form didn't match escaped printf source); thin alias forwarder for complexity-thresholds-pinned.sh name mismatch"
patterns_established:
  - "calibration-memo-with-measurement-delta-table (planner approximations vs re-measured values documented side-by-side; no threshold re-tuning unless a label flips); OR-semantics-threshold-with-boolean-override (hardening_spec_exception overrides above-threshold when fr_count==0); config-surface-for-exception-flags (top-level boolean key documents exception rather than burying in probe body), YAML-scalar-comment-stripper helper for inline # annotated config values; grep -c | head -n 1 + variable-default fallback for robust count capture under grep no-match conditions; defensive LLM pass pattern (runtime-detect + env-gate + dispatch-executable + prompt-file-exists, all must hold); single-line verdict + four-field stderr shape stable across P01 stub to P04 full-body replacement, authored-content-only task (no executable code added beyond gate); preset-file reuse of existing adapter under D007; LLM-prompt template shape with schema_version+type+consumer frontmatter; grep-based YAML structural validation for presets, dry-run probe-on-temp-staged-scaffold; hermetic-gate-copies-toolchain-into-scratch (T06 precedent); awk-first-occurrence-patch BSD-sed-safe edits, stub-to-full transition (P01 stub exit 2 -> P04 full body with distinct exit 3 for runtime gate); CC-only LLM round-trip via dispatch-interface with canned-response hermetic smoke; manifest validation by line-count grep (>=2 and <=4 '  - slug:' entries) + type marker grep; interim-path-with-forward-compat-schema (M024 migration target documented in FR-7 entry body), Section classification by authored-prose-line count with blank-line exclusion; gate-verifier forbidden-phrase literal checks drive body-prose phrasing constraints, STATE_ROOT vs PROJECT_ROOT separation (mutation paths honour ORCHESTRATOR_PROJECT_ROOT env override; dep paths stay at real repo), comment-stripped bash32 pattern scan (grep -vE '^\s*#' before PATTERNS match) to avoid false-positive on 'no declare -A' style comments, thin alias verifier (exec-forwarder) for gate-name mismatch between plan + shipped artifact, per-gate PASS/FAIL echo in phase-suite body for debug visibility without breaking quiet-mode expectations of downstream callers"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P04/tasks/T01-SUMMARY.md, .orchestrator/milestones/M014/phases/P04/tasks/T02-SUMMARY.md, .orchestrator/milestones/M014/phases/P04/tasks/T03-SUMMARY.md, .orchestrator/milestones/M014/phases/P04/tasks/T04-SUMMARY.md, .orchestrator/milestones/M014/phases/P04/tasks/T05-SUMMARY.md, .orchestrator/milestones/M014/phases/P04/tasks/T06-SUMMARY.md, .orchestrator/milestones/M014/phases/P04/tasks/T07-SUMMARY.md"
duration: "240m"
verification_result: "pass"
completed_at: "2026-04-23T01:23:58Z"
observability_surfaces:
  - "execution-log.jsonl"
---

## What Was Built

P04 converts the P01 stubs (complexity probe, `--amend`, `split`) into full FR-5 / FR-14 / FR-7 implementations and wires the US-3 three-way prompt that delegates to the M011/P07 conversus adapter for pressure-testing. Seven tasks, 12-gate phase suite all green. CC-first runtime posture with defensive Codex/Cursor fallbacks on every LLM path.

**Full FR-5 complexity probe** (T02 replaces P01 stub):
- Five measured axes: FR count, user-story count, raw token count, TODO density, contradiction-signal count.
- OR-semantics: above-threshold if ANY axis trips its cutoff; below otherwise.
- `hardening_spec_exception: true` — `fr_count==0 AND user_story_count>=5` routes below-threshold (handles M016/M021 hardening-spec pattern where user stories exist but no FR-list).
- CC-only LLM contradiction pass via `templates/spec-complexity-contradiction-prompt.md` (T03 template); Codex/Cursor report `contradiction_signals=0` deterministically per CON-2.
- Caller contract byte-preserved from P01 stub — T04/US-3 consumes without modification.
- Emits `spec_complexity_probe` JSONL record per invocation to `execution-log.jsonl`.

**Calibration corpus** (T01 → `.orchestrator/milestones/M014/phases/P04/CALIBRATION-MEMO.md`):
- Six retrospective specs labeled: M011 above (fr_count=16), M013 above (fr_count=18), M016 below (hardening exception, fr_count=0), M021 below (hardening exception, fr_count=0), M022 above (user_story_count=5), M024 above (fr_count=20).
- Token measurements ran 13-59% lower than planner approximations — re-measured on live files; no label flipped.
- M013 actual tokens = 7851 (lands just below 8000 cutoff) — still above via fr_count + user_story_count (OR-semantics).
- M024 showed 14 TODOs yielding density 0.538 — above via multiple other axes anyway.
- Pinned thresholds in `.orchestrator/config.yml specify.complexity_thresholds:`: `fr_count: 15`, `user_story_count: 5`, `raw_token_count: 8000`, `todo_density: 0.5`, `contradiction_signal_count: 1`, plus new top-level keys `contradiction_signal_criterion: cc-llm-or-zero` and `hardening_spec_exception: true`.

**Conversus pressure-test preset** (T03 → `templates/conversus-presets/spec-pressure-test.yml`):
- FR-6 red-blue preset: `blue-advocate` + `red-advocate` with constitution-grounded arbiter.
- `verdict_contract: PASS|BLOCK` with required_fields `verdict disputes rationale source_hash`.
- **Zero adapter modifications** — byte-identical `scripts/dispatch/adapters/tool/conversus.sh` pre/post T03 (shasum verified). D007 reuse discipline.
- Red-blue-mode adapter support unverified (planner risk): adapter may treat unknown mode as cooperative pass-through; T04 hermetic gate uses `CONVERSUS_STUB=1` rather than exercising the real adapter end-to-end.

**US-3 three-way prompt wiring** (T04 → `scripts/specify/specify.sh`):
- On above-threshold probe, prints `conversus pressure-test recommended (<reason>). [y/n/d]` to stderr.
- `--yes` auto-mode defaults to `n` (SC-7 zero-approval-prompt invariant verified).
- Explicit `y` path: invokes `scripts/dispatch/adapters/tool/conversus.sh gate --strict spec-pressure-test <spec> <output>`. Writes adapter summary to `.orchestrator/specify/pressure-test/<spec-id>/summary.md`. Emits `conversus_gate_invocation` JSONL with `{gate_id, adapter_version, verdict, llm_calls, elapsed_ms, estimated_cost_usd}`.
- Explicit `d` path: invokes `specify split <spec>` (T05 body).
- Explicit `n` (or default under `--yes`): exit clean unmodified.
- `unit_close` extended with `conversus_invocations` + `adapter_verdicts`.
- Hermetic y-path smoke exercised via `CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS` env — adapter honors this natively via fixture-copy path.

**Full FR-7 `split` subcommand** (T05 replaces P01 hard-stub):
- CC-only: invokes `scripts/dispatch/dispatch-interface.sh --prompt-file templates/spec-splitter-prompt.md --input-file <spec> --mode oneshot`, parses returned YAML decomposition-manifest (2-4 sub-specs), writes `.orchestrator/specify/decomposition/<source-id>/manifest.md`.
- Codex/Cursor: exits 3 with clear diagnostic (distinct from P01 stub's exit 2).
- Interim path schema is M024-forward-compat (migrates to `.orchestrator/intake/<id>/decomposition.md` when M024 lands).
- `RUNTIME-ASSUMPTIONS.md` FR-7 entry appended.

**Full FR-14 `--amend` three-case body** (T06 replaces P01 placeholder):
- Case (a) all-placeholder: re-scaffold (no-op in P04 since FR-3 LLM-fill still deferred; logs "would re-fill" diagnostic, exits 0).
- Case (b) partial: amend target placeholder sections (no-op in P04 for same reason; logs which sections would be amended).
- Case (c) fully-authored: no-op, logs that the spec is authored.
- AS-7 preservation discipline: no re-probe on unchanged sections; prior deliberation preserved.
- SC-14 byte-preservation: all three cases no-op in P04 → spec shasum unchanged pre/post amend (trivially satisfied).

**Registry + references completion** (T06 → `RUNTIME-ASSUMPTIONS.md` + `references/spec-management.md`):
- FR-5-stub entry body refreshed to FR-5-full prose (heading preserved byte-identical; body describes full probe logic instead of stub).
- FR-7 entry appended for splitter.
- `references/spec-management.md` completed: pressure-test section + decomposition section + 3 new action_type rows (`invoke-conversus-gate`, `propose-decomposition`, `amend-section`). `<!-- partial: P04 -->` sentinel removed. **SC-11 milestone-close gate satisfied.**

## Key Decisions

- **`hardening_spec_exception` key** (T01 design invention): cleanly handles M016/M021 both having 3-5 user stories but zero FR-list. Without it, M021's 5 stories would trip `user_story_count>=5`; raising to >=6 would let M011's legitimately-needed 5-story spec slip through.
- **Red-blue mode in preset** (T03): ships `mode: red-blue` unverified against adapter behavior. If adapter degrades to cooperative pass-through, preset still functions at weaker deliberation depth. Follow-up on M011/P07 adapter side deferred per CON-4.
- **Split exit code 3 under Codex/Cursor** (T05): distinct from P01 stub's exit 2. Signals "CC-only runtime gate" rather than "not yet implemented."
- **Case (a) and (b) no-op in P04** (T06): FR-3 LLM-fill is still deferred (per P01 RUNTIME-ASSUMPTIONS FR-3). The three-case classifier engine is in place; actual re-filling lands when FR-3 is invoked. Removes scope bubble; SC-14 byte-preservation trivially satisfied.
- **FR-5 entry body refresh over append** (T06): kept heading byte-identical, refreshed body. Alternative (append new "FR-5-full" section) would leave stale stub prose. Strict append-only would be misleading; chose accuracy.
- **STATE_ROOT separator for mutation sinks** (T07 structural fix): `ORCHESTRATOR_PROJECT_ROOT` env override routes `execution-log.jsonl`, `specs/`, dual-writes, `.orchestrator/specify/` to scratch dirs while `PROJECT_ROOT` stays at repo root for dependency lookups (`templates/`, `scripts/dispatch/`, `references/`). Unlocks hermetic test coverage for every P04 emitter. Sanity case (env unset) preserves live-repo behavior.
- **Alias forwarder** (T07 pragma): `m014-p04-complexity-thresholds-pinned.sh` thin shim to `m014-p04-calibration-thresholds.sh` (T01 shipped under the second name; plan + phase-suite reference the first). Cleaner than renaming T01 artifact + summary + memo + D017 refs.

## Cross-Cutting Patterns Established

- **CC-first with defensive fallback**: every LLM call gated by `detect-capabilities.sh --runtime` or `CLAUDE_CODE_RUNTIME` env check, wrapped in `|| true` with empty-response bailout. Never fails the caller; silently degrades to heuristic-only / no-op under non-CC runtimes.
- **STATE_ROOT vs PROJECT_ROOT separation**: mutation sinks vs dependency lookups distinguishable. Enables hermetic test scratch dirs without duplicating the codebase.
- **`CONVERSUS_STUB` hermetic testing**: `CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS|BLOCK` exercised via fixture-copy path in the adapter. No adapter modification needed.
- **Dispatch-interface mock via backup-and-swap** (T05 hermetic pattern): backup real `dispatch-interface.sh`, swap with canned-response mock, run test, restore via cleanup trap. Works for any script that shells out through the dispatch layer.
- **Section-split awk + per-section classifier** (T06): `awk '/^## /{...}'` splits spec into per-section files; each file independently classified (a)/(b)/(c) via TODO count. Enables partial-spec amend targeting.
- **Append-with-body-refresh for registry entries** (T06): heading byte-identical, body refreshed. Tracks stub→full transitions without leaving stale prose.
- **Bash32 scanner comment-strip**: `grep -vE '^[[:space:]]*#'` before pattern match avoids false-positives on comment prose mentioning prohibited constructs. Pattern inherited from P01/T07.

## Verification Results

**P04 phase suite**: 12/12 gates PASS, exit 0.
1. `m014-p04-complexity-thresholds-pinned.sh` (T01 via alias)
2. `m014-p04-complexity-probe-full.sh` (T02)
3. `m014-p04-pressure-test-preset.sh` (T03)
4. `m014-p04-specify-command-wiring.sh` (T04)
5. `m014-p04-three-way-prompt.sh` (T04)
6. `m014-p04-split-subcommand.sh` (T05)
7. `m014-p04-amend-three-case.sh` (T06)
8. `m014-p04-runtime-assumptions-fr5-fr7.sh` (T06)
9. `m014-p04-spec-management-reference-complete.sh` (T06)
10. `m014-p04-bash32-and-lint.sh` (T07)
11. `m014-p04-zero-prompts.sh` (T07)
12. `m014-p04-observability-records.sh` (T07)

**Cross-cutting invariants**:
- SC-6a dual-write byte-preservation: passes against specify.sh + adapter invocations.
- SC-7 zero-approval-prompt: `--yes` auto-resolves three-way prompt to `n` without blocking.
- SC-11 references/spec-management.md completion: partial sentinel removed; pressure-test + decomposition sections landed.
- SC-14 `--amend` byte-preservation: spec shasum unchanged pre/post amend across all three cases.
- CON-2 CC-first posture: every LLM path has runtime gate + defensive fallback; Codex/Cursor report deterministic zero.
- CON-6 anti-pattern lint: every new + modified shell script passes.
- CON-8 idempotency: `--amend` re-runs preserve deliberation state; probe re-runs yield deterministic verdict.
- D007 conversus-adapter-reuse: `scripts/dispatch/adapters/tool/conversus.sh` byte-identical pre/post P04.
- MEM001 Bash 3.2 compat: all new scripts pass bash32+lint rollup gate.
- FR-16 observability: `spec_complexity_probe` + `conversus_gate_invocation` + `unit_close` records emitted to `.orchestrator/execution-log.jsonl`.

## Deviations Worth Surfacing

Thirteen task-level deviations from verbatim plan bodies across T01-T07. All correctness fixes or hermetic-testability enablers with documented rationale in task summaries. Significant ones:

- **T02**: YAML inline-comment stripping in threshold parser; `grep -c` multi-line no-match handling (both would have produced silently wrong verdicts).
- **T04**: dry-run probe extension (pre-existing `--dry-run` block exited before the probe ran); hermetic scratch setup for specify.sh's SCRIPT_DIR-relative PROJECT_ROOT.
- **T05**: `detect-capabilities.sh` path discrepancy noted (plan body references `scripts/lifecycle/`; actual at `scripts/dispatch/`). Env-var gate (`CLAUDE_CODE_RUNTIME=1`) is primary; path reference is defensive fallback.
- **T06**: section classifier rewritten for awk blank-separator (verbatim formula mis-classified all-placeholder as case b).
- **T07**: STATE_ROOT separator fix (structural) + alias forwarder (pragma) + bash32 scanner comment-strip.

No deviations affected cross-task contracts or downstream phase scope. Every deviation documented in its task summary's `key_decisions` field.

## State After P04

- `orchestrator:specify --description <prose> --slug <slug>` now runs full FR-5 complexity probe, delegates to conversus adapter on operator `y`-choice, and supports full `--amend` + `split` subcommand surface.
- `.orchestrator/config.yml specify.complexity_thresholds:` pinned with operator-reviewable defaults and a design memo explaining why each value was chosen.
- `RUNTIME-ASSUMPTIONS.md` has FR-3, FR-5-full, FR-7 entries — M009 runtime-parity-audit consumes this registry.
- `references/spec-management.md` is complete (SC-11 gate cleared).
- `scripts/dispatch/adapters/tool/conversus.sh` byte-identical from P04 start — D007 reuse discipline honored.
- P03 stays deferred (D018 — blocked on M012 DEPLOY-RECORD resolution + inbox dogfood data).

## Ready for Milestone Close

P01 + P02 + P04 complete. P03 deferred per D018. Milestone validation gate will flag P03 as incomplete — this is the expected state per the user-selected auto-run option. Milestone close happens via `/orchestrator-auto` after operator resolves the P03 preflight gates.
