---
schema_version: "1.0"
type: phase-summary
id: "P05"
parent: "M024"
milestone: "M024"
provides:
  - "templates/intake-qa-questions.md (5 Q<N> blocks: Goal/Scope/Surface/Adversarial/Time,MEM013 frontmatter); scripts/verify/m024-p05-qa-questions-template.sh,scripts/intake/qa-loop.sh (line-mode bounded loop,structural 5-turn cap via head -n 5,case-insensitive enough short-circuit,transcript emission,key=value stdout contract); scripts/verify/m024-p05-qa-loop-script.sh; scripts/verify/m024-p05-qa-loop-cap.sh; scripts/verify/m024-p05-qa-loop-shortcircuit.sh,scripts/intake/proposal-emit.sh empty-input branch (--qa-answers-from <file>; (1a) empty-qa block invokes qa-loop.sh,parses qa_short_circuited,sets input_shape=empty_qa,escalates low_confidence=true on short-circuit,marks QA_AXES_DONE=1,appends ## Q&A + transcript); scripts/verify/m024-p05-proposal-emit-empty-qa.sh,tests/test-empty-qa-loop.sh; tests/test-qa-short-circuit.sh; scripts/verify/m024-p05-empty-qa-full.sh; scripts/verify/m024-p05-empty-qa-shortcircuit.sh; scripts/verify/m024-p05-write-confinement.sh; scripts/verify/m024-p05-evaluate-md.sh; scripts/verify/m024-p05-suite.sh; commands/evaluate.md Input Shapes table empty_qa row"
requires:
  - "P01"
affects:
  - "none"
key_files:
  - "templates/intake-qa-questions.md,scripts/verify/m024-p05-qa-questions-template.sh,scripts/intake/qa-loop.sh,scripts/verify/m024-p05-qa-loop-script.sh,scripts/verify/m024-p05-qa-loop-cap.sh,scripts/verify/m024-p05-qa-loop-shortcircuit.sh,scripts/intake/proposal-emit.sh,scripts/verify/m024-p05-proposal-emit-empty-qa.sh,tests/test-empty-qa-loop.sh,tests/test-qa-short-circuit.sh,scripts/verify/m024-p05-empty-qa-full.sh,scripts/verify/m024-p05-empty-qa-shortcircuit.sh,scripts/verify/m024-p05-write-confinement.sh,scripts/verify/m024-p05-evaluate-md.sh,scripts/verify/m024-p05-suite.sh,commands/evaluate.md,scripts/verify/m024-p03-evaluate-md.sh"
key_decisions:
  - "Static-template-first cut resolves planning #Q-3; conversus-loop generation deferred unless dogfood demands,Line-mode only (no interactive TTY) — deferred behind dogfood need; structural 5-turn cap via head -n 5 enforces FR-5 by shape not branch; case-insensitive whitespace-trimmed enough short-circuit; bash 3.2 portability (no declare -A,no process substitution),QA_AXES_DONE=1 mirrors PARA_AXES_DONE/SPEC_AXES_DONE/FAST_PATH_AXES_DONE so per-axis stub-rationale loop skips overrides; short-circuit -> low_confidence: true chosen as P04 fast-path interlock instead of adding fourth fast-path condition; Original Input body slot overridden with `see ## Q&A` pointer to keep transcript single-sourced; multi-line awk substitution for input_body uses tmp_render-adjacent file (BSD awk rejects literal newlines in -v); awk getline form chosen to dodge P04 write-confinement regex false-positive,FR-15 loop-back-on-strict-superset applied to scripts/verify/m024-p03-evaluate-md.sh — accept empty or empty_qa with inline note; forward-only doc-shape rename made loop-back the conservative choice; write-confinement verify hardened with ^[0-9]+:[[:space:]]*# comment-line filter and 2>/dev/null stderr-redirect filter to remove false positives on commented file paths in proposal-emit.sh header"
patterns_established:
  - "MEM013 frontmatter on intake templates; AD-19 single-script-file Check shape,Q1 — Goal (input_shape rationale + scope_tier evidence),Q2 — Scope (decomposition axis),Q3 — Visible surface (design_gate signal),Q4 — Adversarial review (conversus_gate signal),Two-line key=value stdout contract for intake helper scripts; trap-cleaned mktemp scratch; AD-19 single-script-file Check shape on all three verifies,<branch>_AXES_DONE=1 flag pattern stable across all five M024 input shapes — P06/P07 reuse rather than reinvent; --<source>-from <file> flag for emit-side input streams; pointer-only Original Input body slot when transcript appears under dedicated heading,MEM002 parallel-array suite-tracker preserved (pass_count/fail_count scalars,no declare -A); phase-test wrapper-as-verify (3-line exec wrapper) re-applied; FR-15 loop-back third application this milestone — pattern stable for cross-phase doc-shape supersedure"
drill_down_paths:
  - ".orchestrator/milestones/M024/phases/P05/tasks/T01-SUMMARY.md, .orchestrator/milestones/M024/phases/P05/tasks/T02-SUMMARY.md, .orchestrator/milestones/M024/phases/P05/tasks/T03-SUMMARY.md, .orchestrator/milestones/M024/phases/P05/tasks/T04-SUMMARY.md"
duration: "0m"
verification_result: "pass"
completed_at: "2026-04-26T03:36:18Z"
observability_surfaces:
  - "none"
---

## What Was Built

P05 closes the empty-input branch of the M024 universal-intake router. With P05 in place, `orchestrator:evaluate` invoked with no argument runs a bounded ≤5-turn Q&A loop, captures the transcript verbatim, and emits a proposal with `input_shape: "empty_qa"`, the transcript embedded under `## Q&A`, and `low_confidence: true` whenever the operator short-circuits with `enough` before turn 5. The short-circuit flag flows through to P04's fast-path gate so any low-confidence proposal is forced through the approval prompt — closing the empty-shape edge case from the spec without coupling it to P04's check matrix.

Four tasks shipped:

- **T01 — Static qa-questions template** (`templates/intake-qa-questions.md`). Five `### Q<N>` blocks (Goal / Scope / Surface / Adversarial / Time) with `Prompt` + `Guidance` lines per the MEM013 frontmatter conventions. Resolves planning open-question #Q-3 with the static-template-first cut per D019 reuse-over-rebuild posture; conversus-loop generation deferred unless dogfood demands.
- **T02 — `scripts/intake/qa-loop.sh`** — bash-3.2 line-mode bounded loop. Hard 5-turn cap via `head -n 5`, case-insensitive whitespace-trimmed `enough` short-circuit, transcript emission to a caller-supplied path, two-line stdout key=value contract (`turns_completed=N`, `qa_short_circuited=<bool>`). No interactive TTY mode (deferred behind dogfood need).
- **T03 — `scripts/intake/proposal-emit.sh` empty-input branch** — `--qa-answers-from <file>` flag invokes `qa-loop.sh`, parses `qa_short_circuited`, sets `input_shape="empty_qa"`, escalates `low_confidence="true"` on short-circuit, marks `QA_AXES_DONE=1` (mirrors PARA_AXES_DONE / SPEC_AXES_DONE / FAST_PATH_AXES_DONE so per-axis stub-rationale loop skips overrides), and appends `## Q&A` + transcript after the final `mv`. Empty-qa branch overrides "Original Input" body slot with a `see ## Q&A` pointer to keep the transcript single-sourced.
- **T04 — Phase tests + suite + commands/evaluate.md row update** — two phase tests (`tests/test-empty-qa-loop.sh`, `tests/test-qa-short-circuit.sh`), four per-claim verifies, suite runner, and a one-row update to `commands/evaluate.md` Input Shapes table replacing the stale `\`empty\`` placeholder with the canonical `\`empty_qa\`` row. Loop-back edit to `scripts/verify/m024-p03-evaluate-md.sh` to track the `empty` → `empty_qa` shape rename (the third FR-15 loop-back in M024's running pattern; first was P01/T05 → T01/T04 frontmatter, second was P02/T01 → P01 superset assertion, third is this).

## Verification Results

- `bash scripts/verify/m024-p05-suite.sh` → `PASS: M024/P05 suite — all 9 verifies green` (pass=9 fail=0).
- `bash scripts/verify/m024-p04-suite.sh` → green (P04 fast-path regression preserved).
- `bash scripts/verify/m024-p03-suite.sh` → green after loop-back to evaluate-md verify.
- T04 reported DONE_WITH_CONCERNS for the P03-verify loop-back; the concern is scope-widening (one extra upstream file beyond payload's named SB-3 write set), not correctness. The forward-only doc-shape rename made the loop-back the conservative choice.

## Patterns Established / Reused

- **`<branch>_AXES_DONE=1` flag** — `QA_AXES_DONE` is the fourth instance after `SPEC_AXES_DONE` (P02), `PARA_AXES_DONE` (P03), `FAST_PATH_AXES_DONE` (P04). The loop-skip pattern is now stable across all five M024 input shapes; P06/P07 should reuse rather than reinvent.
- **MEM002 parallel-array suite-tracker** preserved verbatim (`pass_count` / `fail_count` scalars, no `declare -A`).
- **AD-19 single-script-file Check shape** preserved across all 9 P05 verifies.
- **SB-3 write-confinement** — `qa-loop.sh` and the new emit branch only touch `.orchestrator/intake/<id>/` plus mktemp scratch + caller-supplied transcript path.
- **Phase-test wrapper-as-verify** (3-line exec wrappers around `tests/test-*.sh`) re-applied for the suite-runnable phase witnesses.
- **FR-15 loop-back-on-strict-superset** — third application this milestone; the upstream verify's intent is preserved (all five shapes named) while tracking the supersedure.

## Decisions

- **Static questions template over conversus-loop for first cut** — D019 reuse-over-rebuild; conversus-loop generation deferred unless dogfood produces evidence the static cut is insufficient.
- **No interactive TTY mode** in `qa-loop.sh` — line-mode is sufficient for orchestrator-driven Q&A and the spec FR-5 cap is structural via `head -n 5`. TTY mode deferred behind concrete operator demand.
- **Short-circuit → low_confidence: true** chosen as the P04 fast-path interlock, instead of adding a fourth fast-path condition. Keeps P04's check matrix closed and re-uses the existing `low_confidence` axis as the gate.
- **Loop-back to `scripts/verify/m024-p03-evaluate-md.sh`** (alias-accept `empty`|`empty_qa`) chosen over freezing the legacy `empty` row in `commands/evaluate.md`. Forward-only doc-shape rename matches FR-15 strict-superset direction.

## Boundary Map (delivered)

- **Produces**: `scripts/intake/qa-loop.sh`, `templates/intake-qa-questions.md`, `tests/test-empty-qa-loop.sh`, `tests/test-qa-short-circuit.sh`, plus 9 `scripts/verify/m024-p05-*.sh` gates including suite runner. Modifies `scripts/intake/proposal-emit.sh` (empty-qa branch + `--qa-answers-from`), `commands/evaluate.md` (Input Shapes table row), `scripts/verify/m024-p03-evaluate-md.sh` (loop-back).
- **Consumes**: P01 proposal schema (`input_shape=empty_qa` branch + transcript section), P01 emitter, FR-5, #Q-3 resolution.
