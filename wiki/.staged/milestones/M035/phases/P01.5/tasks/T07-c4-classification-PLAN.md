---
schema_version: "1.0"
type: task-plan
task: "T07"
phase: "P01.5"
milestone: "M035"
name: "C4 — `spec-kit` standalone per-line judgment classification pass"
depends_on: ["T06"]
---

## Prerequisites

Files that MUST exist on disk at task entry:

- T01..T06 outputs landed: D-RN block + allowlist + tag (T01); spec dir
  rename (T02); operator paths (T03); C1 lowercase-hyphenated (T04);
  C2/C3 prose (T05); C5 cohort finish (T06). The cumulative state is
  that every match for `spec-kit-orchestrator`, `Spec-Kit Orchestrator`,
  `spec-kit orchestrator`, and `speckit.orchestrator` (operational
  surfaces) has been resolved.
- T07 picks up the residue: `spec-kit` standalone references
  (NOT bound to `-orchestrator` or `.orchestrator`). Per RENAME-PLAN
  § 3 mapping table line 52: many of these refer to the upstream
  spec-kit framework (the Anthropic project this orchestrator originally
  migrated FROM); those MUST survive. Some may refer to this project
  via shorthand and need rename to `orchestrator`.

Pre-existing decisions consumed:

- RENAME-PLAN.md § 3 C4 mapping: per-line judgment, eyeball-not-sed.
- RENAME-PLAN.md § 4 classification protocol: tag each match
  `[C4-rename]` / `[UPSTREAM]` / `[REVIEW]` in a classification log.

## Description

Run a per-line judgment pass over every `spec-kit` standalone reference
in the repo (excluding the historical allowlist), classifying each as
`[C4-rename]` (refers to this project; rewrite to `orchestrator`),
`[UPSTREAM]` (refers to the upstream spec-kit framework; preserve), or
`[REVIEW]` (context unclear; HALT for operator review). Persist the
classification log to
`.orchestrator/milestones/M035/phases/P01.5/c4-classification.txt` so
the consolidate-time SUMMARY can reference it and so future audits can
re-run the pass against the same baseline.

This is the highest-judgment task in the phase — the RENAME-PLAN.md
explicitly warns that global `sed` would silently corrupt this surface.
The dispatched agent reads each match, evaluates context, and emits
the classification verdict. Rewrites apply ONLY to `[C4-rename]`
matches and ONLY after the full classification log is captured.

## Steps

1. **Inventory the C4 surface at task execution time**:

   ```bash
   git grep -niE '\bspec-kit\b|\bspec kit\b' \
     | grep -vE 'spec-kit-orchestrator|speckit\.orchestrator|Spec-Kit Orchestrator|spec-kit orchestrator|spec kit orchestrator' \
     | grep -vE '^(references/RENAME-PLAN\.md|docs/migrating-from-speckit\.md|\.orchestrator/proposals/papercut-sweep-pre-[M030](../../../../../milestones/M030/index.md)\.md|\.orchestrator/milestones/M008/archive/|\.orchestrator/milestones/M0[0-9][0-9]/M0[0-9][0-9]-SUMMARY\.md|\.orchestrator/milestones/M0[0-9][0-9]/M0[0-9][0-9]-BODY\.txt|CHANGELOG\.md|\.orchestrator/DECISIONS\.md|\.orchestrator/milestones/M035/phases/P01\.5/|\.orchestrator/KNOWLEDGE\.md|specs/001-orchestrator/conversus-):' \
     > /tmp/m035-p015-c4-inventory.txt
   ```

   The double exclusion strips out (a) compound matches already handled
   by earlier tasks (T02..T06), and (b) historical-allowlist files.
   What remains is the standalone `spec-kit` surface T07 owns.

2. **Author the classification log**. For each line in
   `/tmp/m035-p015-c4-inventory.txt`, the agent reads ±5 lines of context
   from the source file and emits one line in
   `.orchestrator/milestones/M035/phases/P01.5/c4-classification.txt`:

   ```text
   <file>:<line>:<verdict>:<rationale>
   ```

   Where `<verdict>` is one of `C4-rename | UPSTREAM | REVIEW`. Examples:

   ```text
   docs/getting-started.md:42:UPSTREAM:references upstream spec-kit framework migration history
   commands/auto.md:11:C4-rename:short-form reference to this project; rewrite to orchestrator
   templates/recipe-foo.yml:7:REVIEW:ambiguous — surrounding paragraph could read either way
   ```

   The classification log is the load-bearing artifact — it captures
   the per-line judgment for future audits and is referenced from the
   M035 P01.5 phase SUMMARY at consolidate-time.

3. **HALT on `[REVIEW]` non-empty**. After step 2, count the `REVIEW`
   verdicts:

   ```bash
   review_count=$(grep -cE ':REVIEW:' \
     "$REPO_ROOT/.orchestrator/milestones/M035/phases/P01.5/c4-classification.txt")
   ```

   If `review_count > 0`, the dispatched agent emits:

   ```
   HALT: T07/C4 classification surfaced $review_count REVIEW entries —
   operator must decide rename vs preserve before T07 proceeds. See
   .orchestrator/milestones/M035/phases/P01.5/c4-classification.txt.
   ```

   The auto-loop pauses. Operator reviews each REVIEW entry in the log,
   updates the verdict to `C4-rename` or `UPSTREAM` (manual edit), and
   resumes. The classification log's REVIEW count must reach 0 before
   step 4.

4. **Apply `[C4-rename]` rewrites**. For each line tagged `C4-rename`
   in the log, run a per-file Edit (per AD-19 / CON-3, no compound
   chains). Rewrite the standalone `spec-kit` token to `orchestrator`,
   preserving sentence flow.

5. **Verify zero `[C4-rename]` residue**: re-run the inventory grep
   and assert any remaining matches in non-historical files are
   `[UPSTREAM]`-classified (cross-reference to the log).

6. **Author `tools/verify/m035-p015-c4-classification.sh`**:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p015-c4-classification.sh
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   LOG="$REPO_ROOT/.orchestrator/milestones/M035/phases/P01.5/c4-classification.txt"
   fail=0

   # Log file must exist.
   if [ ! -f "$LOG" ]; then
     echo "FAIL: c4-classification.txt missing at $LOG" >&2
     exit 1
   fi

   # Zero REVIEW verdicts (operator resolved them all).
   review_count=$(grep -cE ':REVIEW:' "$LOG" 2>/dev/null || echo 0)
   if [ "$review_count" != "0" ]; then
     echo "FAIL: c4-classification.txt still has $review_count REVIEW entries" >&2
     fail=1
   fi

   # Every C4-rename verdict line corresponds to a no-longer-present
   # match in its named file (rewrite was applied).
   while IFS= read -r line; do
     case "$line" in
       *":C4-rename:"*)
         file=$(echo "$line" | awk -F: '{print $1}')
         lineno=$(echo "$line" | awk -F: '{print $2}')
         # The file should still exist; the line should no longer
         # contain a standalone spec-kit token. (Strict check: the
         # token was rewritten. Loose check would be too noisy.)
         if [ -f "$REPO_ROOT/$file" ]; then
           if sed -n "${lineno}p" "$REPO_ROOT/$file" | grep -qE '\bspec-kit\b'; then
             echo "FAIL: $file:$lineno still has spec-kit token after C4-rename verdict" >&2
             fail=1
           fi
         fi
         ;;
     esac
   done < "$LOG"

   if [ "$fail" -eq 0 ]; then echo "PASS: m035-p015-c4-classification"; exit 0; fi
   exit 1
   ```

## Must-Haves

- The classification log exists at
  `.orchestrator/milestones/M035/phases/P01.5/c4-classification.txt`,
  has zero `REVIEW` verdicts, and every `C4-rename` verdict has had
  its source line rewritten
  - Check: `bash tools/verify/m035-p015-c4-classification.sh`

## Verification

```bash
bash tools/verify/m035-p015-c4-classification.sh
```

## Inputs

### From Previous Tasks

- T01..T06: cumulative rename state — every compound match handled.
  T07's surface is the standalone `spec-kit` residue.

### From Disk (Pre-existing)

- All `*.md` / `*.yml` / `*.yaml` / `*.json` / `*.sh` files in the
  repo (T07 scope is broader than just markdown — `spec-kit` could
  appear in shell-script comments, JSON metadata, etc.).
- `references/RENAME-PLAN.md` § 3 C4 mapping + § 4 classification
  protocol — runbook source.

## Constraints

- **CON-3 (AP-009-shape-guard-honored)**: per-file Edit calls; no
  compound chains.
- **AD-19 (single-script-file Check shape)**: verifier is one script.
- **No mechanical sed**: `[C4-rename]` verdicts are applied per-line
  via individual Edit calls. The risk of mechanical replacement
  corrupting `[UPSTREAM]` references is high; the per-line discipline
  is the safety mechanism.
- **HALT discipline**: if any `REVIEW` verdict surfaces, the agent
  pauses and waits for operator decision. The auto-loop's pause is
  documented in the task plan's HALT signal.

## Notes

- **Plan-phase verifier-availability cross-check (rule 2)**: T07
  authors `m035-p015-c4-classification.sh` in step 6.
- **Plan-phase classifier-shape pre-validation (rule 3)**: NOT a
  runtime classifier — the "classification" is a static log of
  per-line operator judgments. The verifier asserts the log shape and
  the post-rewrite state, both via grep.
- **Plan-phase real-DB rule (rule 5)**: not applicable.
- **Why T07 is sequenced LAST**: this task's `[REVIEW]` HALT signal
  is the human-judgment escape hatch for the entire P01.5 sweep.
  Sequencing it last means every prior mechanical sweep has settled
  before the per-line judgment pass runs — and means any T01..T06
  oversight surfaces in T07's classification log rather than slipping
  through to T08's acceptance gate.

## Expected Output

After T07 completes:

- `.orchestrator/milestones/M035/phases/P01.5/c4-classification.txt`
  exists on disk with zero `REVIEW` verdicts.
- Every `C4-rename` line has had its source token rewritten from
  `spec-kit` to `orchestrator`.
- Every `UPSTREAM` line is preserved verbatim (the classification log
  is the audit trail justifying the preservation).
- One verifier script exists under `tools/verify/`.
