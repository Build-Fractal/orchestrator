---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M028"
name: "Corpus Extension (7 New Verbatim Entries)"
depends_on: ["T01", "T02"]
---

## Prerequisites

- `tests/fixtures/m021-prompt-corpus.txt` exists (verified: line count 100, entry count 20 via `grep -c '^ID: '`).
- The existing 20 entries (IDs 01..20) are unchanged byte-for-byte. `tail -n 1 tests/fixtures/m021-prompt-corpus.txt` returns `---` (the file ends with a separator line; new entries land after this terminator with their own `---` separators).
- `ANTIPATTERNS.md` carries entries AP-010..AP-014 (T01 deliverable; the corpus comments cite the AP-IDs).
- `scripts/verify/lib/shape-classifier.sh` emits the five new reject classes (T02 deliverable; the corpus expected verdicts MUST match what the M028-extended classifier actually returns).

## Description

Append seven verbatim entries to `tests/fixtures/m021-prompt-corpus.txt` — one per AP-010..AP-014 (5 entries IDs 21..25), one negative-control regression entry (ID 26), and one AP-014 boundary case (ID 27) — using the existing corpus grammar (`ID:` / `SCREENSHOT:` / `INPUT:` / `EXPECTED_OUTCOME:` / `---` separator). The 20 pre-existing [M021](../../../../../milestones/M021/index.md) entries are NOT modified (CON-8 append-only; CON-7 / SC-8 strict-superset).

Newline bytes inside `INPUT:` are encoded as the literal two-byte `\n` sequence (`\` + `n`), matching the existing convention from IDs 01 and 15 (heredoc bodies). The replay harness's `printf '%b'` decode (line 76 of `scripts/verify/replay-prompt-corpus.sh`, preserved in T05's `tests/run-prompt-corpus-replay.sh`) converts `\n` → real newline before classification.

Unicode box-drawing bytes in ID-25 round-trip as literal UTF-8 (3 bytes per `═` / U+2550). The corpus is UTF-8 throughout per the spec Edge Cases.

## Steps

1. **Read the existing corpus** at `tests/fixtures/m021-prompt-corpus.txt` to confirm its file shape: `# ...` header (8 lines) + 20 `---`-delimited entries. The last line is `---` (a terminating separator after entry 20).

2. **Append the 7 new entries to the end of the file**. Each entry is a 4-line block followed by a `---` separator. New entries land after the existing terminating `---`, in numerical order:

```
---
ID: 21
SCREENSHOT: M028 Finding B #1 (Screenshot 4, 2026-04-26) — backtick inside grep regex
INPUT: grep '^- `bash scripts/util/' commands/dispatch.md
EXPECTED_OUTCOME: reject:cmd-sub-in-pattern
---
ID: 22
SCREENSHOT: M028 Finding B #2 (Screenshot 3, 2026-04-25) — newline + # inside quoted CLI arg
INPUT: bash scripts/state/auto-state.sh set --last-action "T01 done\n# trailing comment"
EXPECTED_OUTCOME: reject:quoted-arg-newline-hash
---
ID: 23
SCREENSHOT: M028 Finding B #3 (Screenshot 5, 2026-04-26) — multi-line node -e body
INPUT: node -e "const x = 1;\nconsole.log(x);\n"
EXPECTED_OUTCOME: reject:multiline-quoted-script
---
ID: 24
SCREENSHOT: M028 Finding B #4 (Screenshot 6, 2026-04-26) — unquoted brace glob
INPUT: ls .orchestrator/milestones/M0{2,3,4,5}/M*-SUMMARY.md
EXPECTED_OUTCOME: reject:unquoted-brace-glob
---
ID: 25
SCREENSHOT: M028 Finding G (operator screenshot 2026-04-28 22:25) — verbatim xargs sh -c body
INPUT: find .orchestrator -name "T*-SUMMARY.md" -not -path "*/M066/*" 2>/dev/null | head -3 | xargs -I{} sh -c 'echo "═══ {} ═══"; head -20 "{}"'
EXPECTED_OUTCOME: reject:xargs-sh-c-compound-body
---
ID: 26
SCREENSHOT: M028 P03 negative-control — benign verifier-suite invocation must remain allow under both M021 and M028
INPUT: bash scripts/verify/run-suite.sh M028 P03
EXPECTED_OUTCOME: allow
---
ID: 27
SCREENSHOT: M028 AP-014 boundary case — one-level-deep descent (CON-5; nested sh -c opaque)
INPUT: find . | xargs -I{} sh -c 'sh -c "echo nested"; head {}'
EXPECTED_OUTCOME: reject:xargs-sh-c-compound-body
---
```

3. **Verify byte-fidelity for the special bytes**:
   - ID-21: literal backtick `` ` `` byte inside the grep regex argument (UTF-8 0x60).
   - IDs 22 + 23: literal two-byte `\n` sequence (`\` 0x5C followed by `n` 0x6E). The replay harness decodes via `printf '%b'`.
   - ID-25: U+2550 `═` written as literal UTF-8 three-byte sequence (0xE2 0x95 0x90); appears 4 times (at positions in `"═══ {} ═══"` echo string).
   - ID-25 + ID-27: single-quoted `sh -c '...'` body is preserved as a single quoted segment; the embedded double quotes inside the single-quoted body do NOT close the outer quote.

4. **Pre-validate every new entry's expected verdict** (per CLAUDE.md plan-time classifier-shape pre-validation discipline). For each new entry, run the verbatim INPUT through the M028-extended classifier (T02 deliverable):

```bash
bash -c '. scripts/verify/lib/shape-classifier.sh; classify_command "<verbatim INPUT decoded>"'
```

The actual output must match the EXPECTED_OUTCOME line byte-for-byte. If any entry fails, the corpus is wrong (re-author the entry) OR the classifier is wrong (return to T02). The plan-author already empirically captured the pre-T02 baseline for the five AP-anchored entries (recorded in P03-PLAN.md "Plan-time discoveries") — after T02 those verdicts must shift to the AP-NNN classes documented above.

5. **Verify the 20 M021 entries are untouched**. Run:

```bash
bash scripts/verify/replay-prompt-corpus.sh
```

This M021/SC-1 historical harness hardcodes EXPECTED_TOTAL=20; it parses the corpus and stops at entry 20. After T04, the harness still finds 20 valid M021 entries with their original verdicts (the awk parser at `scripts/verify/replay-prompt-corpus.sh:53..66` reads ID/INPUT/EXPECTED across `---` blocks; new entries 21..27 are simply consumed and emitted to the per-entry tab-record file, but the EXPECTED_TOTAL=20 assertion at line 147 fires only if the entry count differs from 20 — and the harness counts ALL entries seen, so post-T04 it will report `entry_count: 27`. THIS IS A KNOWN DRIFT — see Notes).

6. **Resolve the M021 historical harness drift via T05**. The existing `scripts/verify/replay-prompt-corpus.sh` is the M021/SC-1 historical artifact; after the corpus extends to 27, the M021-only assertion `entry_count == 20` becomes false. T05 ships the new `tests/run-prompt-corpus-replay.sh` with EXPECTED_TOTAL=27 as the M028-aligned harness. The historical harness either (a) stays as-is and is documented as "expected to fail with `entry_count expected 20 got 27` post-T04 — replaced by `tests/run-prompt-corpus-replay.sh`" OR (b) gets a one-line patch to upper-bound the iteration at 20 entries (read first 20, then break). T05's plan documents the exact resolution. T04's responsibility is to ship the 7 new entries; the M021 harness drift is T05's resolution surface.

7. **Author the per-task verifier** at `scripts/verify/m028/p03-corpus-shape.sh` (chmod +x). The verifier asserts the corpus shape contracts listed in Must-Haves: total entry count = 27, IDs 01..20 byte-identical to the pre-T04 baseline (use a pinned `EXPECTED_OUTCOME:` list per ID in a comment block), IDs 21..27 carry the EXPECTED_OUTCOME values the spec mandates. Per-task deliverable so `auto-loop.sh --step=V` resolves at T04 time (per CLAUDE.md hotfix "Plan-time verifier-availability cross-check missing"). The classifier-verdict assertion (every entry's EXPECTED_OUTCOME matches actual classifier output) stays in T05's replay harness — that is the cross-cutting contract.

   Reference shape: `scripts/verify/m028/p03-antipatterns-entries.sh` — single-script-file (AD-19), `set -u`, BASH_SOURCE self-location, prefixed `PASS:`/`FAIL:` output. Bash 3.2 + POSIX-sh safe.

8. **Commit** via `git commit -F <message-file>`. Suggested message:

```
M028/P03/T04: corpus extension — 7 new verbatim entries

IDs 21..25: AP-anchored evidence — one per new reject class
  21 cmd-sub-in-pattern    (SE-02 verbatim, FR-8)
  22 quoted-arg-newline-hash (SE-03 verbatim, FR-9)
  23 multiline-quoted-script (SE-04 verbatim, FR-10)
  24 unquoted-brace-glob   (SE-05 verbatim, FR-11)
  25 xargs-sh-c-compound-body (SE-09 verbatim, FR-12)
ID 26: negative-control regression (must remain allow under
       both M021 and M028 classifiers)
ID 27: AP-014 boundary case (CON-5 one-level-deep descent;
       nested sh -c opaque-treatment)

20 pre-existing M021 entries preserved byte-for-byte (CON-8).
M021 SC-1 historical harness drift documented in T05 plan.
```

## Must-Haves

This task addresses the phase Truth: "The corpus fixture `tests/fixtures/m021-prompt-corpus.txt` carries 27 entries (20 pre-existing M021 entries unchanged + 7 new M028 entries appended verbatim)."

The per-task verifier `scripts/verify/m028/p03-corpus-shape.sh` (co-authored with this task — see Steps step 7) asserts:
- `grep -c '^ID: ' tests/fixtures/m021-prompt-corpus.txt` returns 27.
- IDs 01..20 are present and their `EXPECTED_OUTCOME:` lines are byte-identical to the pre-T04 baseline (the verifier ships a pinned-byte expected list in a comment block).
- ID 21 has `EXPECTED_OUTCOME: reject:cmd-sub-in-pattern`.
- ID 22 has `EXPECTED_OUTCOME: reject:quoted-arg-newline-hash`.
- ID 23 has `EXPECTED_OUTCOME: reject:multiline-quoted-script`.
- ID 24 has `EXPECTED_OUTCOME: reject:unquoted-brace-glob`.
- ID 25 has `EXPECTED_OUTCOME: reject:xargs-sh-c-compound-body`.
- ID 26 has `EXPECTED_OUTCOME: allow`.
- ID 27 has `EXPECTED_OUTCOME: reject:xargs-sh-c-compound-body`.
- The classifier produces the expected verdict on each new entry (delegated to T05's `p03-replay-harness-clean.sh`).

## Verification

```bash
bash scripts/verify/m028/p03-corpus-shape.sh
```

## Notes

`scripts/verify/check-must-haves.sh .orchestrator/milestones/M028/phases/P03` is a phase-level check; it runs at phase close, not per-task. Per-task `## Verification` invokes only task-scoped verifiers (matches P02 convention).

## Inputs

### From Previous Tasks

- `ANTIPATTERNS.md` (from T01) — corpus SCREENSHOT comments cite AP-IDs but do not require the entries to exist for this task's append; cross-references are evergreen.
- `scripts/verify/lib/shape-classifier.sh` (from T02) — the corpus EXPECTED_OUTCOME values MUST match the M028-extended classifier's actual output. Pre-validate at append time per Step 4.

### Key API Surface (from T02)

- `classify_command "<cmd-decoded>"` — single-line stdout of the verdict; verifier expectations are pinned against this output.

### From Disk (Pre-existing)

- `tests/fixtures/m021-prompt-corpus.txt` — the existing 20-entry corpus; T04 appends only.
- `scripts/verify/replay-prompt-corpus.sh` — M021/SC-1 historical harness (EXPECTED_TOTAL=20); T04 documents the post-append drift in the commit message.
- [`.orchestrator/milestones/M028/phases/P01/classifier-audit.md`](../../../../../milestones/M028/phases/P01/classifier-audit.md) — verbatim SE-02..SE-09 commands; T04's INPUT lines are byte-identical to the audit captures.
- `.orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md` "Corpus Staging List" section — names the 5 AP-anchored candidates by source-event ID; T04 lands them as IDs 21..25 and additionally ships ID 26 (negative-control) and ID 27 (boundary-case) per the FR-13 reconciliation rubric.

## Constraints

- **CON-1 (AD-19)**: T04 modifies a single fixture file. No new scripts.
- **CON-7 (no-M021-regression)**: The 20 pre-existing M021 entries are preserved byte-for-byte. The verifier `p03-corpus-shape.sh` includes a per-line byte assertion against a pinned baseline.
- **CON-8 (corpus-shape)**: Single permanent `tests/fixtures/m021-prompt-corpus.txt`; appended-to, never split. Pre-resolved decision per #Q-3.
- **Verbatim byte-fidelity**: New entry INPUT lines are byte-identical to the source-event verbatim commands captured in `classifier-audit.md` (P01/T01). Backticks, braces, newlines (`\n` literal), and `═` (UTF-8) round-trip through the corpus without escaping that changes their classification.
- **Append-only ordering**: Entries 21..27 appear in numerical order at the end of the file, after the existing terminating `---`.
- **Comment annotations**: Each new SCREENSHOT line cites the source (Finding letter + screenshot number + date OR the regression-control / boundary-case rationale). The annotation is human-readable; the parser does not consume it.

## Expected Output

After running `bash scripts/verify/m028/p03-corpus-shape.sh`:

```
PASS: corpus entry count = 27
PASS: IDs 01..20 byte-identical to pre-T04 baseline
PASS: ID 21 EXPECTED_OUTCOME: reject:cmd-sub-in-pattern
PASS: ID 22 EXPECTED_OUTCOME: reject:quoted-arg-newline-hash
PASS: ID 23 EXPECTED_OUTCOME: reject:multiline-quoted-script
PASS: ID 24 EXPECTED_OUTCOME: reject:unquoted-brace-glob
PASS: ID 25 EXPECTED_OUTCOME: reject:xargs-sh-c-compound-body
PASS: ID 26 EXPECTED_OUTCOME: allow
PASS: ID 27 EXPECTED_OUTCOME: reject:xargs-sh-c-compound-body
PASS: ID 25 verbatim INPUT contains UTF-8 box-drawing bytes
PASS: file ends with terminating ---
PASS: p03-corpus-shape.sh
```

## Notes

- **M021 historical harness (`scripts/verify/replay-prompt-corpus.sh`) drift**: After T04 appends 7 entries, this harness's hardcoded `EXPECTED_TOTAL=20` causes its `corpus entry count` assertion to fail (`expected 20 got 27`). The M021 SC-1 contract is "all 20 M021 entries replay clean against the classifier" — that contract is preserved (the entries are unchanged; their verdicts are unchanged). The harness's count assertion is an implementation choice that conflicts with the corpus growth. T05 (`tests/run-prompt-corpus-replay.sh` with EXPECTED_TOTAL=27) is the M028-aligned harness; T05's plan documents whether the M021 historical harness is patched (one-line: change to `EXPECTED_TOTAL=27` for parity) or upper-bound-iterated (read first 20 entries only, preserving the M021 baseline assertion semantics). The plan-author recommendation: T05 patches the M021 historical harness's `EXPECTED_TOTAL` to `27` AND extends its assertion list to the 7 new entries — this collapses two harnesses into one. The new `tests/run-prompt-corpus-replay.sh` becomes a thin shim that delegates to `scripts/verify/replay-prompt-corpus.sh`. T05's plan formalizes this.
- **No new file ordering invariant**: Entries appear in numerical order. The corpus reader (`awk` parser at `scripts/verify/replay-prompt-corpus.sh:53..66`) does not depend on order — but humans reviewing the corpus expect ID order, so T04 honors it.
- **Entry separator convention**: Every entry begins after a `---` line and ends with a `---` line. Between IDs 27 and EOF there is a single trailing `---` matching the existing post-ID-20 shape.
