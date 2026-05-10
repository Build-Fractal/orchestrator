---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P04"
milestone: "M021"
provides:
  - "tests/fixtures/m021-prompt-corpus.txt — permanent 20-entry regression corpus of verbatim M011/P05-P07 Bash tool-call strings; each entry labelled ID/SCREENSHOT/INPUT/EXPECTED_OUTCOME with EXPECTED_OUTCOME values keyed byte-for-byte to scripts/verify/lib/shape-classifier.sh output grammar (allow | rewrite:<result> | reject:<pattern-class>); covers all 10 pattern-classes across 11 rewrites + 5 rejects + 4 allows"
requires:
  - "from:P01 what:scripts/util/{with-env,read-range,run-probe}.sh wrapper paths appearing verbatim inside rewrite EXPECTED_OUTCOME values; from:P03/T01 what:scripts/verify/lib/shape-classifier.sh output grammar that EXPECTED_OUTCOME values must match byte-for-byte"
affects:
  - "P04/T02,P04/T05"
key_files:
  - "tests/fixtures/m021-prompt-corpus.txt"
key_decisions:
  - "AD-2,AD-5"
patterns_established:
  - "Permanent fixture corpus with verbatim screenshot provenance; breadth-inside-fixed-coverage (multiple payload variations per high-frequency pattern class while total entry count stays at 20); literal-\\n encoding for multi-line INPUT with printf '%b' round-trip at consume-time keeps the fixture grep-able and line-oriented; EXPECTED_OUTCOME byte-identity to classifier emission validated via staged probe before commit"
drill_down_paths:
  - ".orchestrator/milestones/M021/phases/P04/tasks/T01-PLAN.md,.orchestrator/milestones/M021/phases/P04/tasks/T01-PAYLOAD.md"
duration: "30m"
verification_result: "pass"
completed_at: "2026-04-17T21:27:10Z"
---

T01 ships tests/fixtures/m021-prompt-corpus.txt — the permanent 20-entry regression corpus of verbatim M011/P05-P07 Bash tool-call strings, each labelled with its ID, SCREENSHOT provenance, INPUT, and EXPECTED_OUTCOME keyed to the P03 shape-classifier output grammar.

FIXTURE SHAPE: plain text, UTF-8, LF endings, 109 lines (inside [60,200] envelope). 8-line comment header documenting provenance + grammar. 20 entries separated by 21 `---` lines (20 openers + 1 terminal). Each entry = ID:/SCREENSHOT:/INPUT:/EXPECTED_OUTCOME: lines in order with no blank lines inside an entry. IDs 01..20 zero-padded, no gaps, no duplicates.

COVERAGE MATRIX (all 10 pattern-classes exercised at least once, with multiple payload variations per high-frequency class per AD-5 breadth-inside-fixed-coverage discipline):
- trailing-rc-echo: 03, 19 (2 entries)
- sed-n-range: 02, 12 (2 entries)
- cat-heredoc-exec: 01, 15 (2 entries)
- cd-and-bash: 04, 16 (2 entries)
- var-inline-bash: 05, 13 (2 entries — single KEY=VAL at 05, two KEY=VAL at 13)
- redirect-cmd-sub: 06 (1 entry)
- nested-cmd-sub: 08 (1 entry)
- compound-chain-gt2: 09, 14 (2 entries — pipe-chain at 09, &&-chain at 14)
- heredoc-with-expansion: 10 (1 entry)
- quoted-brace: 11 (1 entry)
- allow: 07, 17, 18, 20 (4 entries — cat, 2-stage-&& under threshold, ls, cat-config)

Total: 11 rewrites + 5 rejects + 4 allows = 20.

CLASSIFIER ALIGNMENT: every EXPECTED_OUTCOME value is byte-identical to classify_command(INPUT) output as sourced from scripts/verify/lib/shape-classifier.sh. Validated pre-commit via a staged /tmp probe invoked through scripts/util/run-probe.sh that decoded the literal `\n` sequences in INPUT via printf '%b' (round-trip-safe on Bash 3.2 macOS default) and compared classifier output to fixture EXPECTED_OUTCOME for all 20 entries: 20/20 PASS.

NEWLINE ENCODING: multi-line INPUTs (heredocs at entries 01, 10, 15) encode embedded newlines as literal `\n` two-character sequences on a single line. The T02 replay gate will decode via `printf '%b'` before passing to classifier — verified already via the T01 pre-commit probe.

PROVENANCE: every SCREENSHOT field names M011/P05, P06, or P07 plus approximate position. Distribution roughly tracks AD-5's 20-screenshot census: 7 from P05 (IDs 01-07), 7 from P06 (IDs 08-14), 6 from P07 (IDs 15-20). No reconstruction notes required — screenshots were legible for the referenced tool-call text.

CONSTRAINTS HONORED:
- Permanent corpus (constitution VII, AD-5): file size fixed at 20 entries; no speculative future-proof additions (XIV).
- Verbatim INPUT: each line records an exact executable Bash string; no paraphrase, no metavariable substitution.
- Canonical rewrite text: every `rewrite:` EXPECTED_OUTCOME matches the classifier's emission byte-for-byte (leading `bash`, spacing, argument order all preserved). Entry 06 correctly records the deterministic `rewrite:bash scripts/util/read-range.sh` placeholder (AD-2 / P03 rewrite-6 approximate-semantics decision).
- No trailing whitespace or wrapping quotes in EXPECTED_OUTCOME values.

DOWNSTREAM: T02 (replay gate) consumes this fixture as its source of truth, asserts 20/20 classifier-output == EXPECTED_OUTCOME, and drives the PreToolUse hook per entry to confirm WOULD_PROMPT=0/20. T05 (shape gate scripts/verify/m021-p04-corpus-shape.sh) will assert the file's structural invariants (entry count, ID ordering, pattern-class label legality, field ordering). This T01 summary records the fixture is shipped ready for T02/T05 consumption; T05's deep structural assertions are owned by T05.

VERIFICATION: pre-commit probe reports 20/20 classifier alignment and structural checks id_count=20, sep_count=21, lines=109 all inside envelope. The phase-level gate `bash scripts/verify/m021-p04-corpus-shape.sh` (authored in T05) will make this a standing verify-ladder assertion.
