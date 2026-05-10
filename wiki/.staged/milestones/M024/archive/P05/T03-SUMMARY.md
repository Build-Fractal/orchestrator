---
schema_version: "1.0"
type: task-summary
id: T03
parent: M024/P05
task: T03
phase: P05
milestone: M024
outcome: success
verification_result: pass
provides:
  - "scripts/intake/proposal-emit.sh empty-input branch (--qa-answers-from <file>; (1a) empty-qa block invokes qa-loop.sh, parses qa_short_circuited, sets input_shape=empty_qa, escalates low_confidence=true on short-circuit, marks QA_AXES_DONE=1, appends ## Q&A + transcript); scripts/verify/m024-p05-proposal-emit-empty-qa.sh"
requires:
  - "from:M024/P05/T02 what:scripts/intake/qa-loop.sh (key=value stdout contract); from:M024/P01 what:proposal emitter + frontmatter contract; from:M024/P04 what:fast-path low_confidence interlock (so short-circuit blocks fast-path)"
affects:
  - "P05/T04 (phase tests verify the empty-qa frontmatter + ## Q&A body); P06; P07"
key_files:
  - "scripts/intake/proposal-emit.sh,scripts/verify/m024-p05-proposal-emit-empty-qa.sh"
key_decisions:
  - "QA_AXES_DONE=1 mirrors PARA_AXES_DONE/SPEC_AXES_DONE/FAST_PATH_AXES_DONE so per-axis stub-rationale loop skips overrides; short-circuit -> low_confidence: true chosen as P04 fast-path interlock instead of adding fourth fast-path condition; Original Input body slot overridden with `see ## Q&A` pointer to keep transcript single-sourced; multi-line awk substitution for input_body uses tmp_render-adjacent file (BSD awk rejects literal newlines in -v); awk getline form chosen to dodge P04 write-confinement regex false-positive"
patterns_established:
  - "<branch>_AXES_DONE=1 flag pattern stable across all five M024 input shapes — P06/P07 reuse rather than reinvent; --<source>-from <file> flag for emit-side input streams; pointer-only Original Input body slot when transcript appears under dedicated heading"
---

# T03 Summary — Wire qa-loop into proposal-emit.sh (empty-input branch)

## What Was Built

Extended `scripts/intake/proposal-emit.sh` to consume T01's questions template
and T02's `qa-loop.sh` on the empty-input branch. When the emitter is invoked
with neither `--input` nor `--spec-path` AND with the new
`--qa-answers-from <file>` flag, it:

1. Invokes `qa-loop.sh --answers-from <file> --transcript-out <tmp>` and parses
   `qa_short_circuited=<bool>` from stdout.
2. Reads the transcript into a shell variable for embedding.
3. Overrides the shape-detect output with `input_shape="empty_qa"`.
4. Synthesizes `INPUT="$qa_transcript"` so the existing
   `intake-id-allocate.sh` slug logic and the `input_hash` computation both
   stay deterministic on the same answers file (no new id-allocate code path).
5. Propagates `qa_short_circuited` to frontmatter.
6. Escalates `low_confidence="true"` whenever `qa_short_circuited="true"` so
   the P04 fast-path guard fires (one of the five disqualifying conditions).
7. Marks `QA_AXES_DONE=1` immediately after the new empty-qa axis-rationale
   swaps; this mirrors P04's `FAST_PATH_AXES_DONE`, P03's `PARA_AXES_DONE`,
   and P02's `SPEC_AXES_DONE`. The pre-existing per-axis stub-rationale loop
   honors `QA_AXES_DONE` to skip `input_shape`, `scope_tier`, and
   `decomposition` so the empty-qa rationale slots survive.
8. Appends a `## Q&A` heading + the verbatim transcript to the rendered
   proposal body after the final `mv` to `$out_path`. Embedding is
   markdown-pasted (no `{{placeholder}}` substitution), keeping the
   contract simple and TTY-mode-friendly for future work.

The wiring preserves byte-compat for paragraph / idea / fragment / spec
invocations — verified by re-running the M024/P03 and M024/P04 phase suites
on the modified script (all green). The only behavioral change off the
empty-qa branch is that `qa_short_circuited` is now defaulted via
`${qa_short_circuited:-false}` so the (1a) branch's value can leak through;
all other branches still emit `qa_short_circuited: false`.

### Multi-line input_body fix (incidental)

The pre-existing `awk -v body="$input_body"` substitution rejected the
multi-line transcript value on BSD awk (literal newlines forbidden in `-v`).
T03 swapped the substitution shape to read the body from a tmp_render-adjacent
`.body-src` file using awk's `getline ... < file` form. The
`getline ... == 1` comparison (over the more idiomatic `> 0`) avoids a false
positive in the M024/P04 write-confinement grep regex
(`[[:space:]]>([^&/]|/[^d])`). The empty-qa branch also overrides the
"Original Input" body slot with a pointer to the `## Q&A` section so the
transcript is not duplicated (otherwise `^### Q` count would be 10, not 5).

## Files Touched

- `scripts/intake/proposal-emit.sh` — modified: new `--qa-answers-from`
  flag, (1a) empty-qa branch, `low_confidence` escalation,
  `QA_AXES_DONE=1` block + per-axis-loop guard, `## Q&A` append after `mv`,
  multi-line awk substitution shape, empty-qa input_body override.
- `scripts/verify/m024-p05-proposal-emit-empty-qa.sh` — created: end-to-end
  verify (5 answers in -> `input_shape: "empty_qa"`,
  `qa_short_circuited: false`, `low_confidence: false`, exactly 5 `### Q<N>`
  blocks under `## Q&A`).

## Files NOT Touched (out of scope for T03)

T04's phase-suite verifies (`m024-p05-empty-qa-full.sh`,
`m024-p05-empty-qa-shortcircuit.sh`, `m024-p05-write-confinement.sh`,
`m024-p05-evaluate-md.sh`, `m024-p05-suite.sh`) and `commands/evaluate.md`
empty-shape row updates are deferred to T04 per the phase plan.

## Key Decisions / Patterns

- **`QA_AXES_DONE` mirrors the existing axes-done flag pattern** — the
  per-axis stub-rationale loop now skips `input_shape`, `scope_tier`, and
  `decomposition` whenever any of the three axes-done flags is set
  (`PARA_AXES_DONE`, `SPEC_AXES_DONE`, `QA_AXES_DONE`). This preserves the
  empty-qa rationale strings (Q&A-derived) instead of clobbering them with
  the P01 stub `"P01 stub — deep classifier ships in a later phase."`.
- **Synthesize `INPUT="$qa_transcript"` solely for downstream slug + hash
  reuse** — this avoids duplicating intake-id-allocate logic. Both the
  3-digit counter and the slug-from-input path produce sensible
  `<NNN>-<short-slug>` ids without any new code path. The "Original Input"
  body slot is overridden separately so the transcript only appears once
  (under `## Q&A`).
- **`## Q&A` appended after `mv "$tmp_render" "$out_path"`** — keeps the
  transcript markdown-pasted, no template placeholder; future TTY mode
  does not change the embedding contract.
- **`getline ... < file == 1` over `> 0`** — avoids a false positive in
  the M024/P04 write-confinement regex while remaining portable across
  BSD awk and gawk.
- **AD-19 / SB-3 preserved** — writes confined to `scripts/intake/`,
  `scripts/verify/`, `.orchestrator/intake/<id>/`, and tmp_render-adjacent
  scratch under mktemp's tempdir. No inline compound bash in the new
  verify; no `[[ ]]` introduced.

## Verification

```
$ bash scripts/verify/m024-p05-proposal-emit-empty-qa.sh
PASS: proposal-emit.sh — empty + 5 answers → input_shape: empty_qa; ## Q&A with 5 blocks; low_confidence false

$ bash scripts/verify/m024-p03-suite.sh
PASS: M024/P03 suite — paragraph + approval-gate + route + evaluate-md

$ bash scripts/verify/m024-p04-suite.sh
PASS: M024/P04 suite — fast-path + config + condition-violation + write-confinement

$ bash scripts/verify/m024-p02-suite.sh
PASS: M024/P02 suite — backcompat + manifest-read + fixture-vs-live + rationale + confinement

$ bash scripts/verify/m024-p01-suite.sh
PASS: M024/P01 suite — proposal-shape + manifest-superset
```

Smoke test for the short-circuit case (covered formally by T04's
`m024-p05-empty-qa-shortcircuit.sh`):

```
input_shape:        "empty_qa"
qa_short_circuited: true
low_confidence:     true
auto_proceeded:     false
### Q count:        1   (operator typed ENOUGH after Q1)
## Q&A heading:     1
```

All assertions hold; the P04 fast-path correctly refuses to flip
`auto_proceeded` because `low_confidence` is now true on short-circuit.

## Acceptance Criteria — Status

- [x] `--qa-answers-from <file>` flag accepted; `--input` / `--spec-path` /
  `--intake-root` invocations unchanged.
- [x] Empty + qa-answers-from -> `input_shape: "empty_qa"`.
- [x] Proposal body contains `## Q&A` heading + transcript content.
- [x] 5-answer run -> 5 `### Q<N>` blocks, `qa_short_circuited: false`,
  `low_confidence: false`.
- [x] Short-circuit run -> `qa_short_circuited: true`, `low_confidence: true`,
  `auto_proceeded: false` (fast-path blocked).
- [x] `QA_AXES_DONE=1` prevents stub-rationale loop from clobbering
  empty-qa rationale slots.
- [x] Backward-compat: P01 / P02 / P03 / P04 phase suites all green.
- [x] AD-19 single-script-file shape in new verify; no inline compound bash.
- [x] SB-3 write-confinement: P04's confinement check passes (verified end-to-end).
