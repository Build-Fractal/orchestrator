---
schema_version: "1.0"
type: task-summary
id: T04
parent: M024/P05
task: T04
phase: P05
milestone: M024
outcome: success
verification_result: pass
provides:
  - "tests/test-empty-qa-loop.sh; tests/test-qa-short-circuit.sh; scripts/verify/m024-p05-empty-qa-full.sh; scripts/verify/m024-p05-empty-qa-shortcircuit.sh; scripts/verify/m024-p05-write-confinement.sh; scripts/verify/m024-p05-evaluate-md.sh; scripts/verify/m024-p05-suite.sh; commands/evaluate.md Input Shapes table empty_qa row"
requires:
  - "from:M024/P05/T01 what:templates/intake-qa-questions.md; from:M024/P05/T02 what:scripts/intake/qa-loop.sh; from:M024/P05/T03 what:scripts/intake/proposal-emit.sh empty-qa branch + scripts/verify/m024-p05-proposal-emit-empty-qa.sh"
affects:
  - "P03 (loop-back to scripts/verify/m024-p03-evaluate-md.sh accept empty|empty_qa); P05 phase summary; M024 forward (suite is regression gate for P06/P07)"
key_files:
  - "tests/test-empty-qa-loop.sh,tests/test-qa-short-circuit.sh,scripts/verify/m024-p05-empty-qa-full.sh,scripts/verify/m024-p05-empty-qa-shortcircuit.sh,scripts/verify/m024-p05-write-confinement.sh,scripts/verify/m024-p05-evaluate-md.sh,scripts/verify/m024-p05-suite.sh,commands/evaluate.md,scripts/verify/m024-p03-evaluate-md.sh"
key_decisions:
  - "FR-15 loop-back-on-strict-superset applied to scripts/verify/m024-p03-evaluate-md.sh — accept empty or empty_qa with inline note; forward-only doc-shape rename made loop-back the conservative choice; write-confinement verify hardened with ^[0-9]+:[[:space:]]*# comment-line filter and 2>/dev/null stderr-redirect filter to remove false positives on commented file paths in proposal-emit.sh header"
patterns_established:
  - "MEM002 parallel-array suite-tracker preserved (pass_count/fail_count scalars, no declare -A); phase-test wrapper-as-verify (3-line exec wrapper) re-applied; FR-15 loop-back third application this milestone — pattern stable for cross-phase doc-shape supersedure"
---

# T04 Summary — Phase tests + suite + commands/evaluate.md row update

## What Was Built

Authored the two phase-level acceptance witnesses (`tests/test-empty-qa-loop.sh`,
`tests/test-qa-short-circuit.sh`), the four remaining per-claim verifies
(`m024-p05-empty-qa-full.sh`, `m024-p05-empty-qa-shortcircuit.sh`,
`m024-p05-write-confinement.sh`, `m024-p05-evaluate-md.sh`), the suite runner
(`m024-p05-suite.sh`), and updated the `commands/evaluate.md` Input Shapes
table empty-shape row (line 21) from the stale `\`empty\`` placeholder
(`P05+ wires Q&A`) to the canonical `\`empty_qa\`` row that names
`scripts/intake/qa-loop.sh` and the short-circuit -> low_confidence
guard chain.

The phase tests are the load-bearing acceptance witnesses for SC-3 (proposal
contains `input_shape: "empty_qa"` with the transcript embedded under
`## Q&A`) and the spec edge case "Q&A short-circuit on question N"
(`low_confidence: true` blocks the P04 fast-path, so `auto_proceeded: false`
on every short-circuit).

## Files Touched

### New files
- `tests/test-empty-qa-loop.sh` — phase test, happy path: 5 answers in,
  proposal with `input_shape: "empty_qa"`, `qa_short_circuited: false`,
  `low_confidence: false`, `auto_proceeded: false`, exactly 5 `### Q<N>`
  blocks under `## Q&A`.
- `tests/test-qa-short-circuit.sh` — phase test, short-circuit path:
  operator types `enough` after turn 2, proposal carries
  `qa_short_circuited: true`, `low_confidence: true`, `auto_proceeded: false`,
  Q1+Q2 only, no answers past `enough` leak.
- `scripts/verify/m024-p05-empty-qa-full.sh` — suite-runnable wrapper for
  `tests/test-empty-qa-loop.sh`.
- `scripts/verify/m024-p05-empty-qa-shortcircuit.sh` — suite-runnable wrapper
  for `tests/test-qa-short-circuit.sh`.
- `scripts/verify/m024-p05-write-confinement.sh` — SB-3 check on the two
  P05-introduced scripts (`scripts/intake/qa-loop.sh`,
  `scripts/intake/proposal-emit.sh`); asserts no unguarded absolute-path
  writes outside the allow-list (intake-root substitutions, mktemp scratch,
  TRANSCRIPT_OUT, /tmp/).
- `scripts/verify/m024-p05-evaluate-md.sh` — asserts `commands/evaluate.md`
  references `empty_qa` and `qa-loop`; asserts the stale
  `P05+ wires Q&A` placeholder is gone.
- `scripts/verify/m024-p05-suite.sh` — runs all nine P05 verifies (the four
  T01-T03 verifies + the five T04 verifies including the two phase-test
  wrappers); MEM002 parallel-array tracking with `pass_count` / `fail_count`
  and structured `PASS:` / `FAIL:` summary.

### Modified files
- `commands/evaluate.md` — single-row edit at line 21: replaced the
  `\`empty\`` placeholder row with the `\`empty_qa\`` canonical row.
- `scripts/verify/m024-p03-evaluate-md.sh` — **loop-back edit** (see
  Concerns below): the P03 verify's "all five shapes named in backticks"
  assertion previously checked for the literal token `\`empty\``. Since
  T04 supersedes the row to `\`empty_qa\``, the P03 verify needed an
  alias-aware check. Updated to accept either `\`empty\`` or `\`empty_qa\``,
  with an inline note documenting the M024/P05 supersedure.

## Key Decisions / Patterns

- **MEM002 parallel-array suite-tracker preserved verbatim** — the suite
  runner uses scalar `pass_count` / `fail_count` accumulators with a
  `failures` whitespace-list (no `declare -A`, bash 3.2 safe), exactly
  matching the P03/P04 suite shape.
- **AD-19 single-script-file shape preserved** — every external invocation
  in every new verify is a top-level command. No inline compound bash, no
  plain subshells, no `$(... | ...)` pipes inside command substitutions.
- **SB-3 write-confinement** — T04 writes only to the seven new files
  plus the one-row edit in `commands/evaluate.md` (and the loop-back edit
  in `scripts/verify/m024-p03-evaluate-md.sh`).
- **Write-confinement verify hardened** — the payload-template grep
  filter chain (`grep -nE '>...' | grep -vE '...' | grep -v '^#'`)
  has a known false-positive on commented file paths (e.g.
  `<id>/proposal.md` in a `#`-prefixed line). The shipped verify uses
  `^[0-9]+:[[:space:]]*#` to strip line-numbered comment matches and
  `2>/dev/null` to strip stderr-redirect false matches. Intent unchanged
  (no unguarded absolute writes).
- **FR-15 / loop-back-on-strict-superset** — the P03 verify update
  (alias-accept `empty_qa`) is the third in M024's running pattern of
  upstream loop-back edits when downstream phases supersede stub
  contracts. P01 -> T05 looped back to T01 / T04 to add `feature_slug` /
  `milestone` / `status`; T04 here loops back to P03's evaluate-md verify
  to track the `empty` -> `empty_qa` shape rename.

## Verification

```
$ bash scripts/verify/m024-p05-suite.sh
  ok: m024-p05-qa-questions-template.sh
  ok: m024-p05-qa-loop-script.sh
  ok: m024-p05-qa-loop-cap.sh
  ok: m024-p05-qa-loop-shortcircuit.sh
  ok: m024-p05-proposal-emit-empty-qa.sh
  ok: m024-p05-empty-qa-full.sh
  ok: m024-p05-empty-qa-shortcircuit.sh
  ok: m024-p05-write-confinement.sh
  ok: m024-p05-evaluate-md.sh

M024/P05 suite — pass=9 fail=0
PASS: M024/P05 suite — all 9 verifies green

$ bash scripts/verify/m024-p04-suite.sh
PASS: M024/P04 suite — fast-path + config + condition-violation + write-confinement

$ bash scripts/verify/m024-p03-suite.sh
PASS: M024/P03 suite — paragraph + approval-gate + route + evaluate-md
```

## Concerns

- **P03 verify loop-back edit (DONE_WITH_CONCERNS rationale)**: The task
  payload listed the SB-3 write-set as the seven new files plus the
  single-row edit in `commands/evaluate.md`. The payload also listed
  "P03 + P04 suites still pass on HEAD" as a postcondition. These two
  constraints conflicted because `scripts/verify/m024-p03-evaluate-md.sh`
  hard-asserts `\`empty\`` shape backticks in `commands/evaluate.md` —
  exactly the row T04 replaces with `\`empty_qa\``.

  Resolution chosen: minimal alias-aware loop-back to the P03 verify
  (accept either `\`empty\`` or `\`empty_qa\``). This preserves the
  P03 verify's intent (all five shapes named) while tracking the
  M024/P05 supersedure, and matches the M024 FR-15 loop-back pattern
  established in P01/T05. Net write-set widening: one upstream verify
  file edited beyond the payload's listed surfaces.

  Alternative considered and rejected: leaving the P03 verify failing
  on the modern doc state would have left M024 in a stuck-state where
  the most recent canonical evaluate.md row contradicted an earlier
  phase's frozen verify. The supersedure direction is forward-only —
  `empty` is now `empty_qa` in the doc — so the verify edit is the
  conservative choice.

## Acceptance Criteria — Status

- [x] `tests/test-empty-qa-loop.sh` exists, executable, exits 0 with
  `PASS: ...`, asserts `input_shape: "empty_qa"`, `qa_short_circuited: false`,
  `low_confidence: false`, `auto_proceeded: false`, and exactly 5
  `### Q<N>` blocks under `## Q&A`.
- [x] `tests/test-qa-short-circuit.sh` exists, executable, exits 0 with
  `PASS: ...`, asserts `input_shape: "empty_qa"`,
  `qa_short_circuited: true`, `low_confidence: true`,
  `auto_proceeded: false`, no `### Q3` leak, no post-`enough` answers
  in proposal body.
- [x] `scripts/verify/m024-p05-empty-qa-full.sh` and
  `scripts/verify/m024-p05-empty-qa-shortcircuit.sh` wrap the two phase
  tests; both exit 0.
- [x] `scripts/verify/m024-p05-write-confinement.sh` asserts no unguarded
  absolute-path writes in `qa-loop.sh` or `proposal-emit.sh`; exits 0.
- [x] `scripts/verify/m024-p05-evaluate-md.sh` asserts `commands/evaluate.md`
  references `empty_qa` and `qa-loop` and the stale `P05+ wires Q&A`
  placeholder is gone; exits 0.
- [x] `commands/evaluate.md` empty-shape row updated to name `empty_qa`
  and `scripts/intake/qa-loop.sh`. Other rows untouched (FR-6).
- [x] `scripts/verify/m024-p05-suite.sh` runs nine verifies, MEM002
  parallel-array tracking, `pass=9 fail=0`, exits 0 with
  `PASS: M024/P05 suite — all 9 verifies green`.
- [x] AD-19 single-script-file shape preserved across every new file.
- [x] SB-3 write-confinement: T04 writes only to the seven new files
  plus the one-row edit in `commands/evaluate.md` (plus the loop-back
  edit in `scripts/verify/m024-p03-evaluate-md.sh`; see Concerns).
- [x] Upstream regression: M024/P03 and M024/P04 suites both pass.
