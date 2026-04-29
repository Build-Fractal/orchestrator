---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M028"
name: "Classifier replay audit of all M028 source events"
depends_on: []
---

## Prerequisites

- `scripts/verify/lib/shape-classifier.sh` exists and exposes a `classify_command` function (M021/P03 deliverable). Confirm with `bash scripts/util/run-probe.sh scripts/verify/lib/shape-classifier.sh`. The function takes a single argument (the command line) and emits one of: `ALLOW`, `REJECT: <ap-id> — <reason>`, or a remediation hint.
- `tests/fixtures/m021-prompt-corpus.txt` exists (M021/P04 deliverable). It is the existing 21-entry replay corpus; T01 reads it for shape reference but does not modify it.
- The M028 spec at `specs/031-autonomous-hardening-v3/spec.md` is on-disk and contains the verbatim source-event commands under Findings A through G.
- `scripts/verify/m028/` directory does not exist yet — T01 creates it.

## Description

Replay every M028 source event through the existing M021 classifier and produce a structured audit table. The audit is the input that T03 attributes to root causes and uses to recommend the collapse decision; it is also the staging note that P03 will consume when authoring the corpus extension.

A "source event" is a verbatim Bash command (or a Stop-hook event) that triggered an interruption in `orchestrator:auto`. The full set is enumerated in `specs/031-autonomous-hardening-v3/spec.md` under the per-finding evidence sections. The implementing agent must enumerate them by reading the spec — the spec's source-evidence list is canonical, not this task plan. Expect 7 to 9 events depending on whether redundant compound-shell variants from Finding C are kept separate or collapsed.

For each source event, record:
1. Source citation (which Finding, which screenshot number or "operator-reported Stop-hook")
2. Verbatim command (byte-for-byte; no escaping that changes classification)
3. Existing-classifier verdict from `classify_command` against the M021 classifier (verbatim output)
4. Observed actual behavior in the wild (did the hook fire? did the command prompt? did Claude Code's `command not found` surface? — extracted from the spec's narrative under each Finding)

Output format is markdown with one section per source event. The classifier output is captured verbatim as a fenced block. Do not interpret the verdict in T01 — interpretation is T03's job.

## Steps

1. Read `specs/031-autonomous-hardening-v3/spec.md` end-to-end. Extract every verbatim command quoted under Findings A, B, C, D, E, F, G — both the bullet-list "verbatim from screenshot" entries and any commands embedded in acceptance scenarios. Record source-event metadata (which Finding, which screenshot number or operator-report, observed-in-the-wild behavior).

2. For every Bash command source event (i.e., excluding the Finding F Stop-hook event which is not a Bash classification target), run the existing classifier and capture stdout/stderr verbatim:

   ```bash
   bash scripts/util/run-probe.sh scripts/verify/m028/p01-classify-one.sh "<verbatim command>"
   ```

   Author `scripts/verify/m028/p01-classify-one.sh` as a one-shot shim that sources `scripts/verify/lib/shape-classifier.sh` and calls `classify_command "$1"`. Single-script-file shape per AD-19. **Important**: this shim is throwaway — delete it at the end of T01 or leave it in place; either is fine, but it must not be referenced by any later task.

   For the Finding F Stop-hook event, do not run the classifier — instead record the event's observed behavior (`orchestrator-post-verify: command not found`) and note "not a Bash classification target — adapter+installer issue".

3. Compose `classifier-audit.md` with one section per source event. The structure is fixed (so T03 can parse it):

   ```markdown
   ## SE-NN: <one-line label>

   - **Source**: Finding <X>, screenshot <N> (or "operator-reported Stop-hook")
   - **Cited at**: `specs/031-autonomous-hardening-v3/spec.md:<line-number>`
   - **Observed behavior in the wild**: <one or two sentences>

   ### Verbatim command

   ```
   <byte-for-byte command>
   ```

   ### Existing-classifier verdict

   ```
   <verbatim stdout from classify_command>
   ```
   ```

   The audit document opens with a one-paragraph preface naming the M021 classifier version (the bash file modification date or git SHA of `scripts/verify/lib/shape-classifier.sh` — `git log -1 --format=%h scripts/verify/lib/shape-classifier.sh`) so future readers can reproduce.

4. Author `scripts/verify/m028/p01-replay-coverage.sh`. Single-script-file shape, bash 3.2 + POSIX-sh-safe. The script:
   - Verifies `.orchestrator/milestones/M028/phases/P01/classifier-audit.md` exists.
   - Counts `## SE-` section headings in the audit; emits `PASS` if count ≥ 7 (the spec's minimum source-event count), else `FAIL: classifier-audit.md has <N> source events, expected ≥ 7`.
   - Verifies the audit contains the literal substring `AP-009` (anchor that the M021 classifier output was actually captured — every compound-shell verdict cites AP-009).
   - Exits 0 on PASS, exits 1 on any FAIL with a one-line diagnostic to stderr.

5. Run `bash scripts/util/run-probe.sh scripts/verify/m028/p01-replay-coverage.sh`. Confirm `PASS`. If FAIL, iterate on the audit content — do not edit the verifier to make it pass.

## Must-Haves

This task addresses the Truth: "The classifier-replay audit covers every source event from the M028 spec." It also produces the verifier `scripts/verify/m028/p01-replay-coverage.sh` referenced by the phase-plan must-haves.

## Verification

```bash
bash scripts/verify/m028/p01-replay-coverage.sh
```

## Notes

Expected verifier output is a single line of the form `PASS: classifier-audit.md has <N> source events, AP-009 anchor present` where N is the count the audit lands at. The verifier asserts N ≥ 7, not an exact number.

## Inputs

### From Previous Tasks

None.

### From Disk (Pre-existing)

- `specs/031-autonomous-hardening-v3/spec.md` — canonical source-event list under Findings A through G. T01 reads the verbatim command quotes and the per-finding "Evidence" / "Verbatim from screenshot" subsections.
- `scripts/verify/lib/shape-classifier.sh` — the M021 classifier library. T01 sources it via the throwaway shim `scripts/verify/m028/p01-classify-one.sh`. Key API: `classify_command "<command>"` writes verdict to stdout, returns 0 on ALLOW, returns non-zero on REJECT.
- `scripts/util/run-probe.sh` — shape-safe wrapper for invoking other scripts; required because the harness shape-guard rejects the host's bare `bash <script>` invocation in some contexts. T01's verification step uses it.

## Constraints

- **AD-19 single-script-file shape**: `scripts/verify/m028/p01-replay-coverage.sh` and the throwaway `p01-classify-one.sh` shim must be flat single-file scripts. No nested helper dirs, no compound-chain bodies, no inline `bash -c '...'` chains, no plain subshells.
- **bash 3.2 + POSIX sh (CON-2)**: every line of `p01-replay-coverage.sh` runs on bash 3.2 — no associative arrays, no `mapfile`/`readarray`, no unguarded `<<<` here-strings.
- **Verbatim byte-fidelity**: the audit's "Verbatim command" blocks must round-trip the source bytes exactly — backticks, braces, newlines, `═══` Unicode box-drawing — without any escaping that would alter classifier-output reproduction. The fenced block must use 4-backtick fences if the body contains a 3-backtick fence.
- **No interpretation in T01**: the audit records facts (what the classifier said, what was observed in the wild) but does not assign root-cause attribution. T03 owns interpretation.
- **Read-only against M021 surface**: T01 does not modify `scripts/verify/lib/shape-classifier.sh`, `scripts/hooks/pre-bash-shape-guard.sh`, or `tests/fixtures/m021-prompt-corpus.txt`. M021's verification artifacts stay immutable per the M028 spec's Non-Goals.

## Expected Output

- `.orchestrator/milestones/M028/phases/P01/classifier-audit.md` — markdown, ≥ 7 source-event sections, ≥ 30 lines total, contains the literal substring `AP-009`.
- `scripts/verify/m028/p01-replay-coverage.sh` — flat bash script, ≥ 10 lines, references `classifier-audit.md`.
- `scripts/verify/m028/p01-classify-one.sh` — throwaway shim used during T01's authoring. May remain in tree (no consumer); may be deleted at task close.
- Standard task summary at `.orchestrator/milestones/M028/phases/P01/tasks/T01-classifier-replay-audit-SUMMARY.md` written via `scripts/state/write-summary.sh` (or whichever path the dispatch system uses) on task close.
