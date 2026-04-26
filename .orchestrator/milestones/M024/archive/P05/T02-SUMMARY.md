---
schema_version: "1.0"
type: task-summary
id: T02
parent: M024/P05
task: T02
phase: P05
milestone: M024
outcome: success
verification_result: pass
provides:
  - "scripts/intake/qa-loop.sh (line-mode bounded loop, structural 5-turn cap via head -n 5, case-insensitive enough short-circuit, transcript emission, key=value stdout contract); scripts/verify/m024-p05-qa-loop-script.sh; scripts/verify/m024-p05-qa-loop-cap.sh; scripts/verify/m024-p05-qa-loop-shortcircuit.sh"
requires:
  - "from:M024/P05/T01 what:templates/intake-qa-questions.md (read-by-number Q<N> ordering)"
affects:
  - "P05/T03 (proposal-emit empty branch consumes qa-loop); P06; P07"
key_files:
  - "scripts/intake/qa-loop.sh,scripts/verify/m024-p05-qa-loop-script.sh,scripts/verify/m024-p05-qa-loop-cap.sh,scripts/verify/m024-p05-qa-loop-shortcircuit.sh"
key_decisions:
  - "Line-mode only (no interactive TTY) — deferred behind dogfood need; structural 5-turn cap via head -n 5 enforces FR-5 by shape not branch; case-insensitive whitespace-trimmed enough short-circuit; bash 3.2 portability (no declare -A, no process substitution)"
patterns_established:
  - "Two-line key=value stdout contract for intake helper scripts; trap-cleaned mktemp scratch; AD-19 single-script-file Check shape on all three verifies"
---

# T02 Summary — qa-loop.sh bounded line-mode loop

## What Was Built

Authored `scripts/intake/qa-loop.sh` — the pure-shell, line-mode bounded Q&A
loop that drives the empty-input branch of `orchestrator:evaluate`. The script
reads questions from T01's static template (`templates/intake-qa-questions.md`),
consumes answers from a `--answers-from <file>` argument (one answer per line),
and writes a transcript in the embedding-ready shape that T03's emitter will
splice under `## Q&A` in the proposal body.

Three load-bearing invariants:

- **FR-5 5-turn cap**: enforced **structurally** via `head -n 5` on the
  answers file before the loop runs. An answers file with seven lines
  produces a transcript with exactly five `### Q<N>` blocks; the 6th and
  7th lines are dropped on the floor and never reach the transcript.
- **`enough` short-circuit**: case-insensitive (`tr '[:upper:]' '[:lower:]'`)
  and whitespace-trimmed (`sed 's/^[[:space:]]*//; s/[[:space:]]*$//'`).
  When matched, the loop exits after the prior turn; subsequent answer
  lines are discarded. Stdout reports `qa_short_circuited=true`.
- **Transcript format**: one `### Q<N>` heading + one prose answer line +
  one blank line per turn. Heading numbers are 1-indexed and match the
  pinned Q1–Q5 order in the questions template. The format is verbatim
  what T03's emitter will embed under `## Q&A` — no post-processing.

Stdout contract (two key=value lines, parseable by the caller):

```
qa_short_circuited=<true|false>
qa_turns=<count>
```

The script also validates the questions file ships with `### Q1`–`### Q5`
headings before processing — a missing heading exits 1 with a stderr message.

**Line-mode only.** Interactive (TTY-prompt) mode is deferred per the plan;
line-mode is sufficient for SC-3 and FR-5 in tests, and a future task can add
a TTY surface without breaking the line-mode contract.

## Files Created

- `scripts/intake/qa-loop.sh` — bounded Q&A loop (executable, bash 3.2 portable).
- `scripts/verify/m024-p05-qa-loop-script.sh` — happy path: 5 answers in -> 5 `### Q<N>` blocks out, `qa_short_circuited=false`, `qa_turns=5`.
- `scripts/verify/m024-p05-qa-loop-cap.sh` — cap enforcement: 7 answers in -> 5 blocks out, sixth/seventh answers do not leak.
- `scripts/verify/m024-p05-qa-loop-shortcircuit.sh` — `enough` after turn 2 -> `qa_short_circuited=true`, 2-block transcript; case-insensitivity probe (`ENOUGH`) also short-circuits.

## Files NOT Touched (out of scope for T02)

T03's emitter modifications (`scripts/intake/proposal-emit.sh` --qa-answers-from
flag + empty_qa branch + Q&A embedding), `commands/evaluate.md` updates, and
the integration verifies (`m024-p05-proposal-emit-empty-qa.sh`,
`m024-p05-empty-qa-full.sh`, `m024-p05-empty-qa-shortcircuit.sh`,
`m024-p05-write-confinement.sh`, `m024-p05-evaluate-md.sh`,
`m024-p05-suite.sh`) are intentionally left for T03+. T02 writes only to
`scripts/intake/qa-loop.sh` and the three verifies above per SB-3.

## Key Decisions / Patterns

- **Structural cap (head -n 5) over in-loop counter** — a one-shot truncation
  before the loop runs is the simplest shape that earns FR-5. Future TTY-mode
  work can wire an in-loop counter without changing the line-mode contract.
- **AD-19 single-script-file shape preserved** — every external invocation in
  the verifies is a top-level command; no inline compound bash, no plain
  subshells, no `$(... | ...)` containing pipes.
- **bash 3.2 portability** — the script uses `[ ]` only (no `[[ ]]`),
  `case` for arg parsing (no `getopts` long-flag tricks), `sed -n 'Np'` for
  line addressing, and `tr` + `sed` for case-fold + whitespace-trim. No
  `declare -A`, no process substitution.
- **Trap-cleaned tempfile** — `mktemp` + `trap 'rm -f "$work"' EXIT` keeps
  the cap-enforcement scratch off `.orchestrator/` and outside SB-3's
  write-confinement domain.

## Verification

```
$ bash scripts/verify/m024-p05-qa-loop-script.sh
PASS: qa-loop.sh — five answers -> five ### Q<N> blocks; qa_short_circuited=false; qa_turns=5

$ bash scripts/verify/m024-p05-qa-loop-cap.sh
PASS: qa-loop.sh — 7-line answers truncated to 5 turns; qa_short_circuited=false

$ bash scripts/verify/m024-p05-qa-loop-shortcircuit.sh
PASS: qa-loop.sh — enough (case-insensitive) short-circuits at turn 2; qa_short_circuited=true
```

All three exit 0.
