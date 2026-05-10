---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M037"
name: "OUT-OF-SCOPE diagnostic-budget collapse in wiki-link-check.sh"
depends_on: ["T03"]
---

## Prerequisites

- `scripts/diagnostics/wiki-link-check.sh` exists (verified at plan-authoring time, ~345 lines, contains awk-based emitter that prints `OUT-OF-SCOPE: <page> -> <href> [<reason>]` lines at lines 246, 256, 289; final summary line at line 343 reports `out-of-scope` count).
- `scripts/wiki/wiki-deploy.sh` exists (verified at plan-authoring time; gate 3 invokes `bash scripts/diagnostics/wiki-link-check.sh --site wiki/site` at line 186).

## Description

Lands FR-22a per US-13 and SC-16. PBJ-central deploys emit 178 `OUT-OF-SCOPE: ... -> https://github.com/.../discussions [external]` lines (one per page, all pointing at the same giscus URL). Drowns the actionable signal — in-scope link checks, gate status, projection counts — in repetitive noise. Operator can't read past the OUT-OF-SCOPE wall to find diagnostic information. Source: `papercut-sweep-wiki-deploy-2026-05-07.md` finding #5.

Add OUT-OF-SCOPE diagnostic-budget collapse to `wiki-link-check.sh`:
- Collapse repeated OUT-OF-SCOPE patterns (same target URL across many source pages) above a 5-occurrence threshold to a single summary line: `OUT-OF-SCOPE: <N> pages -> <url> [external <descriptor>]`.
- Keep first 3-5 unique OUT-OF-SCOPE targets as full diagnostic lines (within the diagnostic-budget rule).
- `--verbose` flag disables collapsing for debugging.
- Honor zero-OUT-OF-SCOPE fixture: no false summary line emitted when there are no OUT-OF-SCOPE entries.

`wiki-deploy.sh` passes `--verbose` through to `wiki-link-check.sh` when invoked with its own `--verbose` flag.

## Steps

1. **Modify `scripts/diagnostics/wiki-link-check.sh`** to add the collapse logic. The existing awk-based emitter prints OUT-OF-SCOPE lines as it walks each page (lines 246, 256, 289). Replace the direct print with a buffered emit that's post-processed at end-of-walk:

   - Add a `--verbose` flag handler at the top of the script (alongside the existing `--site` / `--root` / `--strict` flags). Default: collapse enabled.
   - In the awk script, replace `print "OUT-OF-SCOPE: " page " -> " href " [external]"` (and the two sibling `print` lines for `[absolute-path]` and `[reason]`) with a buffered approach. One viable shape: emit OUT-OF-SCOPE lines to a temp file during the walk, then at end-of-walk post-process the temp file with a second awk script that:
     - Tallies occurrences per `<href>` target.
     - Emits up to N (= 5) unique targets as full per-page lines.
     - Emits remaining targets with >= 5 hits as one summary line each: `OUT-OF-SCOPE: <count> pages -> <href> [<reason>] (collapsed)`.
     - Emits remaining targets with < 5 hits per-occurrence (small-fanout case — diagnostic budget not exhausted).
     - With `--verbose`: skip the post-processing step entirely; emit the temp file contents verbatim.

   Implementation sketch (add to wiki-link-check.sh):

   ```bash
   # ---- FR-22a (M037/P02/T04) — OUT-OF-SCOPE diagnostic-budget collapse -----
   # Default: collapse repeats above threshold (5 occurrences per unique
   # target) to a single summary line. Honors --verbose to disable
   # collapsing for debugging. Zero-OOS fixture emits nothing.

   COLLAPSE=1
   for arg in "$@"; do
     case "$arg" in
       --verbose) COLLAPSE=0 ;;
     esac
   done

   # ... existing flag handling, awk walker, etc. ...
   #
   # Modify the awk walker to redirect OUT-OF-SCOPE prints to a temp file
   # rather than stdout. Pseudo-shape:
   #   OOS_TMP="/tmp/wiki-link-check-oos.$$"
   #   awk '...' > "$OOS_TMP"   # awk emits OUT-OF-SCOPE lines here only
   #
   # At end-of-walk, post-process:
   collapse_oos() {
     OOS_TMP="$1"
     [ -f "$OOS_TMP" ] || return 0
     if [ "$COLLAPSE" -eq 0 ]; then
       cat "$OOS_TMP"
       return 0
     fi
     # Group by href; tally occurrences. awk one-pass:
     awk '
       BEGIN { THRESHOLD = 5; BUDGET = 5 }
       # Match: OUT-OF-SCOPE: <page> -> <href> [<reason>]
       /^OUT-OF-SCOPE:/ {
         page=$2
         href=""
         reason=""
         for (i=4; i<=NF; i++) {
           if ($i == "->") continue
           if ($i ~ /^\[/) {
             reason=$i
             for (j=i+1; j<=NF; j++) reason=reason " " $j
             break
           }
           href = (href == "") ? $i : href " " $i
         }
         count[href]++
         reason_for[href]=reason
         if (count[href] == 1) {
           order[++n_unique] = href
         }
         lines[href] = lines[href] $0 "\n"
       }
       END {
         budget_used = 0
         for (k = 1; k <= n_unique; k++) {
           href = order[k]
           if (count[href] >= THRESHOLD) {
             # Always collapse high-fanout targets
             printf "OUT-OF-SCOPE: %d pages -> %s %s (collapsed)\n", \
               count[href], href, reason_for[href]
           } else if (budget_used < BUDGET) {
             # Small-fanout: emit per-occurrence within budget
             printf "%s", lines[href]
             budget_used++
           } else {
             # Budget exhausted; collapse remaining small-fanout
             printf "OUT-OF-SCOPE: %d pages -> %s %s (collapsed, budget)\n", \
               count[href], href, reason_for[href]
           }
         }
       }
     ' "$OOS_TMP"
   }

   # Wire into the existing flow:
   #   awk-walk | tee >(grep '^OUT-OF-SCOPE:' > "$OOS_TMP") | grep -v '^OUT-OF-SCOPE:'
   #   collapse_oos "$OOS_TMP"
   #   rm -f "$OOS_TMP"
   ```

   **Important**: the actual implementation MUST avoid process substitution `>(...)` and `<(...)` per AD-19 / harness shape rules — those trigger the safety heuristic. Instead, use a two-pass shape:
   - Pass 1: awk walker writes ALL output to a temp file (both OUT-OF-SCOPE and non-OUT-OF-SCOPE lines).
   - Pass 2: emit non-OUT-OF-SCOPE lines verbatim (`grep -v '^OUT-OF-SCOPE:' "$WALK_TMP"`).
   - Pass 3: extract OUT-OF-SCOPE lines (`grep '^OUT-OF-SCOPE:' "$WALK_TMP" > "$OOS_TMP"`) and call `collapse_oos`.

   Verify by running against the 178-page fixture (step 2) and the zero-OOS fixture (step 3).

2. **Build the 178-page synthetic fixture** for SC-16. The fixture lives at `tests/fixtures/m037-out-of-scope-collapse/` (path-collision check passed at plan-authoring time):

   - `tests/fixtures/m037-out-of-scope-collapse/178-pages-same-target/wiki/site/p001.html` through `p178.html`, each carrying a single `<a href="https://github.com/Test-Org/Test-Repo/discussions">` link.
   - `tests/fixtures/m037-out-of-scope-collapse/mixed-targets/wiki/site/`: 3 pages each linking to one URL (small-fanout), 175 pages each linking to another URL (high-fanout). Asserts the 3-hit URL emits per-occurrence and the 175-hit URL collapses.
   - `tests/fixtures/m037-out-of-scope-collapse/zero-oos/wiki/site/p001.html`: a single page with only in-scope links. Asserts no summary line emitted.

   Each fixture is shell-built at test runtime (cheaper than committing 178 .html files) — the test scaffold writes them to a `mktemp -d` temp dir.

3. **`wiki-deploy.sh` --verbose passthrough**. Modify `scripts/wiki/wiki-deploy.sh` to:
   - Accept its own `--verbose` flag (alongside existing `--dry-run`, `--skip-smoke`, etc.).
   - When `--verbose` is set, append `--verbose` to the gate-3 invocation: `bash scripts/diagnostics/wiki-link-check.sh --site wiki/site --verbose`.
   - Update the help block to document the new flag.

4. **Author `tests/m037-acceptance/p01-out-of-scope-collapse.sh`** (SC-16):
   - Builds the three fixtures via shell heredocs into `mktemp -d`.
   - For the 178-page fixture: runs `bash scripts/diagnostics/wiki-link-check.sh --site <fixture>/wiki/site` and asserts:
     - Exit code 0 (no in-scope FAILs).
     - stdout contains exactly ONE OUT-OF-SCOPE summary line of shape `OUT-OF-SCOPE: 178 pages -> <url> [<reason>] (collapsed)`.
     - stdout contains zero per-page OUT-OF-SCOPE lines for the same target.
   - For the same fixture with `--verbose`: asserts 178 separate OUT-OF-SCOPE lines emitted (per-occurrence restored).
   - For the mixed-targets fixture: asserts the 3-hit URL emits up to 3 per-occurrence lines (within budget); the 175-hit URL collapses.
   - For the zero-OOS fixture: asserts NO OUT-OF-SCOPE lines or summary lines emitted.
   - Emits `PASS: m037-p02-out-of-scope-collapse` on success.

5. **Author `tools/verify/m037-p02-out-of-scope-collapse.sh`**:
   - Greps `scripts/diagnostics/wiki-link-check.sh` for: `--verbose` (flag handler), `(collapsed)` (the literal collapse marker in the summary line shape), `THRESHOLD` (the awk variable name).
   - Greps `scripts/wiki/wiki-deploy.sh` for `--verbose` flag passthrough handling.
   - Invokes `bash tests/m037-acceptance/p01-out-of-scope-collapse.sh` and propagates exit code.
   - Emits `SUMMARY: m037-p02-out-of-scope-collapse pass=N fail=M` on completion.

## Must-Haves

- T12 (FR-22a OUT-OF-SCOPE collapse + --verbose flag) — phase plan.

## Verification

```bash
bash tools/verify/m037-p02-out-of-scope-collapse.sh
```

```bash
bash tests/m037-acceptance/p01-out-of-scope-collapse.sh
```

## Inputs

### From Previous Tasks

- T03 (M037/P02/T03) — private site_url. T04 does not consume T03 directly; ordering is dispatch-sequencing only (T04 is independent of T03 in surface area — different scripts).

### From Disk (Pre-existing)

- `scripts/diagnostics/wiki-link-check.sh` — extended with `--verbose` flag + collapse logic.
  - Existing API: emits `OUT-OF-SCOPE: <page> -> <href> [<reason>]` shape on lines 246/256/289; final summary `PASS: 0 broken in-scope links (<page-count>, <ok-count>, <oos-count>)` at line 343.
- `scripts/wiki/wiki-deploy.sh` — extended with `--verbose` flag passthrough.
- The fixture corpus is built at test runtime; no pre-existing fixture path consumed.

## Constraints

- AD-19: all `Check:` commands single-script-file shape. The verifier's internal logic uses bash + awk (allowed inside script files; the harness gates only inline harness-Bash invocations).
- NO process substitution `>(...)` `<(...)` in script additions — match the surrounding-code shape (the existing `wiki-link-check.sh` uses temp files + plain pipes, not process substitution).
- Bash 3.2 + POSIX sh in script additions.
- The collapse threshold (5 occurrences) and diagnostic budget (5 unique targets) are CONSTANTS in the awk script. Not exposed as flags in P02 — keep the surface minimal. P03 may revisit if PBJ feedback surfaces a need.
- Zero-OOS fixture invariant: NO summary line, NO per-occurrence lines emitted. The empty-input case must produce zero output from the collapse logic (silent-on-empty is the contract).
- The summary-line shape is `OUT-OF-SCOPE: <N> pages -> <url> <reason> (collapsed)` — preserve `<reason>` byte-identical from the source per-occurrence lines (e.g., `[external giscus]`, `[absolute-path]`, etc.). Some downstream consumers may grep for the reason marker; preserving it keeps behavior compatible.

## Expected Output

After T04 ships:
- A 178-page deploy emits ONE summary line `OUT-OF-SCOPE: 178 pages -> <url> [<reason>] (collapsed)` instead of 178 per-page lines.
- A mixed-fanout deploy preserves small-fanout per-occurrence lines (within budget) and collapses high-fanout repeats.
- `wiki-deploy.sh --verbose` (passthrough to wiki-link-check.sh) restores per-occurrence emission.
- Zero-OOS fixture emits no false summary lines.
- `bash tests/m037-acceptance/p01-out-of-scope-collapse.sh` exits 0; `bash tools/verify/m037-p02-out-of-scope-collapse.sh` reports `SUMMARY: m037-p02-out-of-scope-collapse pass=N fail=0`.

## Notes

- **Why the awk + temp-file shape**: the existing wiki-link-check.sh walker uses awk to emit lines as it walks each `.html` file. Reordering it to buffer + post-process keeps the awk surface intact and avoids restructuring the walker. The buffered shape costs one temp file write per deploy — negligible.

- **The `(collapsed)` marker** at the end of summary lines is added so downstream tooling (or operators) can grep-distinguish summary lines from raw OUT-OF-SCOPE lines without parsing the count field. Two distinct markers (`(collapsed)` for high-fanout above threshold; `(collapsed, budget)` for small-fanout above the diagnostic budget) preserve the diagnostic distinction.

- **Performance against 178+ pages**: the post-processing awk pass is O(n) over the OOS-line buffer; even at 10k entries it's microseconds. No performance concerns for PBJ-central scale.

- **Plan-Time Discipline rule 5** (real-DB verification): NOT APPLICABLE.

- **Why `THRESHOLD = 5` is the constant**: the spec says "first 3-5 unique OUT-OF-SCOPE targets as full lines" — picking the upper bound (5) preserves diagnostic context for slightly-higher-fanout cases. Keeping it constant in the awk script is appropriate; turn-it-into-a-flag is premature optimization.
