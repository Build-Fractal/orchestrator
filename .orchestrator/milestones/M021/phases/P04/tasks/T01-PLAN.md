---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M021"
name: "Replay corpus fixture — tests/fixtures/m021-prompt-corpus.txt (20 verbatim M011/P05–P07 tool-call strings, each labelled with INPUT: and EXPECTED_OUTCOME: keyed to the classifier's output grammar)"
depends_on: []
---

## Prerequisites

No upstream M021/P04 tasks. Consumes only these P01–P03 outputs by name (no runtime dependency):

- `scripts/verify/lib/shape-classifier.sh` (P03/T01) — the shape classifier whose output grammar the corpus EXPECTED_OUTCOME values match. Classifier emits exactly one of `allow`, `rewrite:<result-command>`, or `reject:<pattern-class>`. Rewrite targets name P01 wrappers (`scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh`) verbatim. Reject pattern-classes are the six rewrite-class names (`trailing-rc-echo`, `sed-n-range`, `cat-heredoc-exec`, `cd-and-bash`, `var-inline-bash`, `redirect-cmd-sub`) when used as reject labels or the four hard-reject labels (`nested-cmd-sub`, `compound-chain-gt2`, `heredoc-with-expansion`, `quoted-brace`).
- `scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh` (P01) — wrapper paths that appear verbatim inside `rewrite:` EXPECTED_OUTCOME values.

No script is sourced or invoked during T01 execution. T01 writes one fixture file.

## Description

Author `tests/fixtures/m021-prompt-corpus.txt` — the permanent regression corpus of 20 verbatim Bash tool-call strings extracted from the M011/P05–P07 screenshots. Each entry captures both the original tool-call string (`INPUT:`) and the expected shape-classifier decision (`EXPECTED_OUTCOME:`) so `scripts/verify/replay-prompt-corpus.sh` (T02) can assert 20/20 "not would-prompt" under the hardened system.

The corpus is permanent (constitution VII — knowledge compounds) and becomes part of the standing verify ladder. Adding a 21st entry later requires fresh M011-class evidence plus a new milestone/phase justification (AD-5).

### Fixture format (exact grammar)

- Plain text, no YAML frontmatter.
- Optional top-of-file comment lines beginning with `#` (file-level header explaining provenance + grammar).
- 20 entries. Entries are separated by a line containing exactly `---` (three hyphens, no leading or trailing whitespace).
- Each entry consists of exactly these lines, in order, with no blank lines inside an entry:
  - `ID: <##>` — zero-padded 1..20 (e.g. `ID: 01`, `ID: 20`).
  - `SCREENSHOT: <M011/P05–P07 screenshot identifier>` — freeform text naming the phase + approximate position (e.g. `M011/P05 screenshot 3 of 7`). No line-number checks against this field — it is audit metadata.
  - `INPUT: <verbatim Bash tool-call string>` — the exact Bash command string Claude Code would receive. Must be on a single line. Newlines that appear in the original command (heredocs, multi-line inputs) are encoded as literal `\n` two-character sequences within the INPUT line and MUST be decoded by the T02 replay gate via `printf '%b'` before being passed to the classifier. This keeps the fixture grep-able and line-oriented.
  - `EXPECTED_OUTCOME: <allow | rewrite:<result-command> | reject:<pattern-class>>` — the classifier-output-grammar string. One of:
    - `allow`
    - `rewrite:<result-command>` where `<result-command>` matches verbatim the classifier's rewrite output (no trailing whitespace, no wrapping quotes).
    - `reject:<pattern-class>` where `<pattern-class>` is one of the ten pattern-class labels named in the classifier header.
- A final `---` separator terminates the last entry (keeps the parser's state machine simple — every entry ends with a separator line).
- Encoding: UTF-8, LF line endings.

### Grounding and provenance

Every INPUT string must come from one of the 20 M011/P05–P07 screenshots cited in the feature spec's "Problem Statement" and `M021-CONTEXT.md` AD-5. If a screenshot's exact call text is ambiguous (OCR artifact, truncation), use the closest reconstructable form and document the reconstruction in the SCREENSHOT field (e.g. `M011/P06 screenshot 2 — reconstructed from visible prefix`).

### Seed entries (minimum coverage)

The 20 entries must collectively cover every pattern-class the classifier emits, so the replay gate exercises the full matrix. Required coverage (by EXPECTED_OUTCOME):

- **Rewrites — one per pattern (6 entries minimum)**:
  - `rewrite:bash a.sh` (trailing-rc-echo) — `INPUT: bash a.sh ; echo "RC=$?"`
  - `rewrite:bash scripts/util/read-range.sh file.md 10 20` (sed-n-range) — `INPUT: sed -n '10,20p' file.md`
  - `rewrite:bash scripts/util/run-probe.sh /tmp/p.sh` (cat-heredoc-exec) — `INPUT: cat > /tmp/p.sh <<EOF\necho hi\nEOF\nbash /tmp/p.sh`
  - `rewrite:bash scripts/foo.sh a b` (cd-and-bash) — `INPUT: cd .orchestrator && bash scripts/foo.sh a b`
  - `rewrite:bash scripts/util/with-env.sh K=v -- bash scripts/foo.sh --flag` (var-inline-bash) — `INPUT: K=v bash scripts/foo.sh --flag`
  - `rewrite:bash scripts/util/read-range.sh` (redirect-cmd-sub) — `INPUT: bash x.sh > "$(mktemp)"`
- **Rejects — one per pattern (4 entries minimum)**:
  - `reject:nested-cmd-sub` — `INPUT: echo $(date $(hostname))`
  - `reject:compound-chain-gt2` — `INPUT: bash a.sh | bash b.sh | bash c.sh`
  - `reject:heredoc-with-expansion` — `INPUT: cat <<EOF\necho $HOME\nEOF`
  - `reject:quoted-brace` — `INPUT: awk "BEGIN{print 42}" /dev/null`
- **Allow — at least 4 entries**: real M011 tool-calls that shape-classifier passes through unchanged (no prompt in current system). Examples: `bash scripts/verify/run-suite.sh m011 P05`, `cat tmp/fixture.md`, `ls scripts/util/`, `bash a.sh && bash b.sh` (2-stage chain, under the threshold).
- **Remaining 6 entries**: additional variations drawn from the screenshot set that re-exercise already-covered pattern-classes with different payloads (e.g. a second `sed-n-range` entry with different line numbers, a second `var-inline-bash` entry with two KEY=VALUE pairs, a second compound-chain entry with `&&` instead of `|`). The intent is breadth-of-payload coverage inside fixed pattern-class coverage so the classifier's pattern-matching is exercised against realistic variation, not just one canonical input per class.

Total: 6 rewrites + 4 rejects + ≥4 allows + 6 additional = 20 entries.

## Steps

### Step 1: Extract the 20 verbatim tool-call strings from M011/P05–P07 screenshots

For each of the 20 screenshots cited in `.orchestrator/milestones/M021/M021-CONTEXT.md` AD-5 and the feature spec problem statement, transcribe the exact Bash tool-call string that Claude Code was about to dispatch. Where a call contains embedded newlines (heredocs, multi-line strings), encode them as literal `\n` inside the INPUT line.

If any screenshot is genuinely illegible, substitute a functionally-equivalent input drawn from the phase's bash history as recorded in `.orchestrator/milestones/M011/phases/P05/execution-log.jsonl` (or P06/P07 equivalents). Document any substitution in that entry's SCREENSHOT field with the note `— reconstructed from execution log`.

### Step 2: Assign EXPECTED_OUTCOME to each entry

For each entry, determine the classifier's expected decision by running `classify_command "<INPUT>"` mentally (or via a local sourced invocation) against the classifier library. Decisions are:

- Allow — the call does not match any of the 10 patterns.
- Rewrite — the call matches one of the 6 rewrite patterns; outcome is `rewrite:<canonical-result>` where `<canonical-result>` is the classifier's emitted rewrite target. Rewrite targets referencing P01 wrappers use the exact paths `scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh`.
- Reject — the call matches one of the 4 hard-reject patterns; outcome is `reject:<pattern-class>`.

Ties (input matches both a rewrite and a reject pattern) resolve per AD-2 / P03 classifier precedence: rejects dominate rewrites.

### Step 3: Write the fixture with a header block

File header (first 8 lines — verbatim structure; adjust only the extraction-date):

```
# tests/fixtures/m021-prompt-corpus.txt
# Permanent regression corpus for M021 SC-1.
# 20 verbatim Bash tool-call strings extracted from M011/P05–P07 screenshots.
# Each entry: ID / SCREENSHOT / INPUT / EXPECTED_OUTCOME.
# Entries separated by '---' lines. Newlines in INPUT encoded as literal '\n'.
# Grammar of EXPECTED_OUTCOME: allow | rewrite:<result> | reject:<pattern-class>
# Source: .orchestrator/milestones/M021/M021-CONTEXT.md AD-5.
# Do not reorder or renumber — replay-prompt-corpus.sh preserves ID→SCREENSHOT traceability.
```

Then 20 entries in the format described above. First entry (canonical form):

```
---
ID: 01
SCREENSHOT: M011/P05 screenshot 1 of 7 — bash probe heredoc
INPUT: cat > /tmp/m011-p05-probe.sh <<EOF\nexit 0\nEOF\nbash /tmp/m011-p05-probe.sh
EXPECTED_OUTCOME: rewrite:bash scripts/util/run-probe.sh /tmp/m011-p05-probe.sh
---
```

Continue through ID 20. Close the file with a final trailing `---` line so every entry is bounded on both sides.

### Step 4: Validate structure locally

Verify the fixture is well-formed before T02 consumes it. Run the T05 structural gate `bash scripts/verify/m021-p04-corpus-shape.sh` (authored in T05) to confirm:

- File exists at `tests/fixtures/m021-prompt-corpus.txt`.
- Entry count is exactly 20.
- Every entry has `ID:`, `SCREENSHOT:`, `INPUT:`, `EXPECTED_OUTCOME:` fields in order.
- EXPECTED_OUTCOME values are well-formed grammar (`allow` | `rewrite:...` | `reject:...`).
- Every reject EXPECTED_OUTCOME uses one of the 10 legal pattern-class labels.
- IDs are 01..20 with no duplicates and no gaps.

T01's own verification is asserting the file exists with the required content markers (see Verification below). T05 owns the deep structural gate.

### Step 5: Make the fixture read-only in convention

The file is a plain-text fixture; no `chmod +x` needed. Do not add a shebang line.

## Must-Haves

- `tests/fixtures/m021-prompt-corpus.txt` exists.
- File has the 8-line header block (comments starting with `#`) plus 20 `---`-separated entries.
- Every entry has `ID:`, `SCREENSHOT:`, `INPUT:`, `EXPECTED_OUTCOME:` lines in that order.
- IDs are `01`..`20` inclusive, zero-padded, no duplicates, no gaps.
- Coverage: ≥6 rewrites (one per rewrite pattern), ≥4 rejects (one per reject pattern), ≥4 allows.
- Every `rewrite:` EXPECTED_OUTCOME's result-command matches the classifier's canonical form; every `reject:` EXPECTED_OUTCOME uses one of the 10 legal pattern-class labels.
- File is ≥60 lines and ≤200 lines (envelope check — 20 entries × ~4 lines + separators + header ≈ 100 lines target).

## Verification

- `bash scripts/verify/m021-p04-corpus-shape.sh` exits 0 with `PASS: m021-p04-corpus-shape.sh`.
- `grep -c '^ID:' tests/fixtures/m021-prompt-corpus.txt` returns 20 — asserted inside the T05 structural gate, not run inline here.
- `bash scripts/verify/run-suite.sh m021 P04` includes `PASS: m021-p04-corpus-shape.sh` among its reported assertions.

## Inputs

### From Previous Tasks

None. T01 is the first task in P04.

### From Disk (Pre-existing)

- `.orchestrator/milestones/M021/M021-CONTEXT.md` — AD-2 (ten-pattern matrix), AD-3 (three-wrapper catalog), AD-5 (replay corpus is the authoritative regression gate), AD-9 (new AP-### entries for each Class B pattern). The 20-screenshot provenance is named here.
- `specs/021-autonomous-hardening-v2/spec.md` — feature spec Problem Statement + SC-1..SC-7 list; fixture is the authoritative SC-1 evidence.
- `scripts/verify/lib/shape-classifier.sh` — classifier library, read-only during T01. The corpus EXPECTED_OUTCOME values must match the classifier's output grammar; misalignment between corpus and classifier surfaces at T02 as FAIL lines.
- `scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh` — P01 wrapper paths that must appear verbatim in rewrite EXPECTED_OUTCOME values.
- `.orchestrator/milestones/M011/phases/P05/execution-log.jsonl` (and P06/P07 equivalents) — fallback source for any screenshot whose text is illegible.

## Constraints

- **Permanent**: the fixture is not a throwaway test file. Constitution VII — knowledge compounds. Any future change (adding entries, editing EXPECTED_OUTCOME values to match a classifier update) requires a logged decision entry.
- **Verbatim INPUT**: no paraphrasing. If a screenshot shows `bash /tmp/m011-p05-probe.sh`, the fixture records exactly `bash /tmp/m011-p05-probe.sh` — not `bash /tmp/probe.sh` or `bash \$ORCH_PROBE`.
- **Canonical rewrite text**: `rewrite:` outcomes must match the classifier's actual output byte-for-byte. If the classifier emits `rewrite:bash scripts/util/read-range.sh file.md 10 20`, the fixture records that exactly — including leading `bash`, spacing, and argument order.
- **No speculative entries**: the corpus has exactly 20 entries (AD-5). Future prompt triggers that surface in a later auto run require a new milestone entry, not an append to this fixture (AD-5 + constitution XIV).
- **Bash 3.2 parseability**: the fixture is not a script, but newline encoding (literal `\n` inside INPUT) must round-trip correctly through `printf '%b'` in the T02 replay gate on macOS default bash.

## Expected Output

- `tests/fixtures/m021-prompt-corpus.txt` exists, is UTF-8 encoded, LF line endings, 60–200 lines.
- `head -n 8 tests/fixtures/m021-prompt-corpus.txt` shows the 8-line comment header.
- `grep -c '^ID:' tests/fixtures/m021-prompt-corpus.txt` returns exactly `20`.
- `grep -c '^---$' tests/fixtures/m021-prompt-corpus.txt` returns exactly `21` (20 opening + 1 terminal separator).
- Every required pattern-class label appears at least once in the fixture's EXPECTED_OUTCOME lines.
- Subsequent T02 replay gate invocation confirms 20/20 classifier-output == EXPECTED_OUTCOME and `WOULD_PROMPT=0/20`.
