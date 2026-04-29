---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M028"
name: "Hook self-location via BASH_SOURCE (Finding A core)"
depends_on: []
---

## Prerequisites

- `scripts/hooks/pre-bash-shape-guard.sh` exists at the M021 baseline shape (PreToolUse hook for the `Bash` tool, sources `scripts/verify/lib/shape-classifier.sh`, defines an inline `reject_lookup` function, exits 0 / 0+stdout / 2 per the `(a) passthrough / (b) rewrite / (c) reject` protocol). Confirm the file is present with `bash scripts/util/run-probe.sh scripts/hooks/pre-bash-shape-guard.sh`. The file's current resolution block (lines 38–44 at the time of the M028 spec authoring) reads:

    ```
    REPO_ROOT="${CLAUDE_PROJECT_DIR:-}"
    if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT" ]; then
      REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    fi
    CLASSIFIER="${REPO_ROOT}/scripts/verify/lib/shape-classifier.sh"
    ```

    This task replaces the project-relative-first / self-relative-fallback shape with a pure self-relative resolution that is location-stable in the runtime-stable hooks dir P02 ships into (`~/.claude/orchestrator-hooks/`).

- `scripts/verify/lib/shape-classifier.sh` exists (M021/P03 deliverable). The hook will continue to source it; T01 does not modify the classifier.

- `scripts/util/run-probe.sh` exists (M021 deliverable). Used to invoke other scripts under the harness shape-guard.

- `scripts/verify/m028/` directory exists (P01 created it). T01 adds two new verifiers under it.

- The pre-existing M021 self-conformance contract (no compound chain > 2 connectors anywhere in the hook body — AP-009) MUST be preserved by every line T01 introduces. CON-3 is hard-gated from day one.

## Description

Refactor `scripts/hooks/pre-bash-shape-guard.sh` so its classifier and reject_lookup-data paths are resolved purely from `${BASH_SOURCE[0]}` — never from `$CLAUDE_PROJECT_DIR`. After T03's installer ships the hook to `~/.claude/orchestrator-hooks/pre-bash-shape-guard.sh`, the hook will sit alongside `shape-classifier.sh` in the same dir; T01's resolution must locate the classifier as a sibling of the hook (`<hook-dir>/shape-classifier.sh`), with a one-step parent-fallback for in-tree development (where the hook lives at `scripts/hooks/` and the classifier lives at `scripts/verify/lib/`).

The two-location strategy:
1. Compute `HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"` (resolves symlinks via `pwd -P`).
2. If `${HOOK_DIR}/shape-classifier.sh` exists, set `CLASSIFIER` to that. (Runtime-stable installed location.)
3. Else if `${HOOK_DIR}/../verify/lib/shape-classifier.sh` exists, set `CLASSIFIER` to that. (In-tree development location: hook at `scripts/hooks/`, classifier at `scripts/verify/lib/`.)
4. Else exit 0 (passthrough). The hook NEVER hard-fails on missing classifier — fails-open is the safe default for a pre-tool hook (matches M021 baseline behavior); the install-roundtrip gate (T05) is responsible for proving the classifier was actually staged.

Author the refactor under the AP-009 self-conformance constraint: every line must lint clean against the M021 classifier output. The check is "no compound chain exceeding 2 connectors" — count `&&`, `||`, `;`, `|` connectors per line and keep each line ≤ 2.

Land two new verifiers under `scripts/verify/m028/`:
- `p02-hook-self-locate.sh` — asserts the hook body contains the `BASH_SOURCE[0]` self-resolve pattern AND contains zero references to `CLAUDE_PROJECT_DIR` inside the resolution block (lines after `# Locate repo root + classifier` up to the next `# ---` section divider). The verifier reads the file with `grep -n` / `sed -n` only.
- `p02-hook-self-conformance.sh` — sources `scripts/verify/lib/shape-classifier.sh`, reads `scripts/hooks/pre-bash-shape-guard.sh` line-by-line skipping comments and blank lines, and asserts `classify_command` returns ALLOW for every line. Single-script-file shape per AD-19; no inline compound bash, no `( ... )` plain subshell, no `$(...)` containing a pipe.

## Steps

1. Read `scripts/hooks/pre-bash-shape-guard.sh` end to end to confirm the current resolution block (around lines 35–44) and understand the surrounding hook protocol. Note the file uses `set -u` and is bash 3.2 safe.

2. Replace the resolution block (between the `# Locate repo root + classifier` divider and the `# Read stdin (Claude Code's hook JSON)` divider) with the self-relative two-location pattern. Verbatim shape (note: each line ≤ 2 connectors; the `if/else if` is multi-line not chained):

    ```bash
    # -----------------------------------------------------------------------------
    # Locate classifier — self-relative via BASH_SOURCE (Finding A fix, M028/P02/T01)
    #
    # The hook resolves the classifier from its own on-disk location, NOT from
    # $CLAUDE_PROJECT_DIR. This makes the hook portable: it fires correctly in any
    # consumer project where Claude Code launches with the project as
    # $CLAUDE_PROJECT_DIR, because the hook lives at the runtime-stable
    # ~/.claude/orchestrator-hooks/ dir (M028/P02 installer) and resolves its
    # sibling classifier from there. The in-tree development location (hook at
    # scripts/hooks/, classifier at scripts/verify/lib/) is supported via a
    # one-step parent-fallback. On both miss, fail open (exit 0) — never hard-fail
    # the hook on a missing classifier; that is the install-roundtrip gate's job.
    # -----------------------------------------------------------------------------

    HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    CLASSIFIER=""

    if [ -f "${HOOK_DIR}/shape-classifier.sh" ]; then
      CLASSIFIER="${HOOK_DIR}/shape-classifier.sh"
    elif [ -f "${HOOK_DIR}/../verify/lib/shape-classifier.sh" ]; then
      CLASSIFIER="${HOOK_DIR}/../verify/lib/shape-classifier.sh"
    fi

    if [ -z "$CLASSIFIER" ] || [ ! -f "$CLASSIFIER" ]; then
      exit 0
    fi
    ```

    Notes for the implementer:
    - `pwd -P` resolves symlinks (Edge-Cases item: hook self-location through symlinks).
    - The `HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"` line contains one `&&` connector — within the AP-009 ≤ 2 budget.
    - `[ -z "$CLASSIFIER" ] || [ ! -f "$CLASSIFIER" ]` contains one `||` connector — within budget.
    - Every other line uses single-statement `if`/`elif`/`fi` blocks; no inline-`if`-then-fi-on-one-line.
    - DO NOT use `$(...)` containing a pipe anywhere in this block.
    - DO NOT use a plain `( ... )` subshell.
    - The block introduces no `bash -c '...'` invocations.

3. Verify by reading the modified file that NO line in the resolution block (or anywhere else in the file) references `CLAUDE_PROJECT_DIR`. The variable is being intentionally retired from the hook's logic. (It may still be set by Claude Code in the runtime environment; the hook simply does not consult it.)

4. Author `scripts/verify/m028/p02-hook-self-locate.sh`. Single-file flat shape, bash 3.2 safe, ≥ 10 lines. The script:
    - `set -u`, no `set -e` (we want to read every check independently).
    - Locates the hook at `scripts/hooks/pre-bash-shape-guard.sh` relative to the script's `cd $(dirname $0)/../../..` parent.
    - Asserts the file contains the literal substring `BASH_SOURCE` (via `grep -q "BASH_SOURCE" "$hook"`).
    - Asserts the file does NOT contain the literal substring `CLAUDE_PROJECT_DIR` (via `grep -q "CLAUDE_PROJECT_DIR" "$hook"` returning non-zero — invert with `if grep ... ; then echo FAIL; exit 1; fi`).
    - Asserts the file contains the literal substring `pwd -P` (symlink resolution proof).
    - On all-pass, emits `PASS: hook self-location via BASH_SOURCE confirmed; CLAUDE_PROJECT_DIR retired; pwd -P symlink resolution present` to stdout and exits 0.
    - On any FAIL, emits a `FAIL:` diagnostic to stderr naming the missing/extra substring and exits 1.

5. Author `scripts/verify/m028/p02-hook-self-conformance.sh`. Single-file flat shape, bash 3.2 safe, ≥ 10 lines. The script:
    - `set -u`, no `set -e`.
    - Resolves repo root via `cd $(dirname $0)/../../..` and `pwd -P`.
    - Sources the M021 classifier: `. "${REPO_ROOT}/scripts/verify/lib/shape-classifier.sh"`. The classifier exposes `classify_command "<cmd>"` (M021/P03 API).
    - Reads `scripts/hooks/pre-bash-shape-guard.sh` line-by-line via a plain `while IFS= read -r line; do ... done < "$hook"` loop. **Note**: this is a top-level `while` loop in script body — that is allowed; the AD-19 shape rule prohibits inline `while` blocks embedded inside a single command, not script-level loop bodies. The loop is the script's primary control flow and does not violate AD-19.
    - For each line, skip if blank or starts with `#` (comment). Otherwise call `classify_command "$line"` and capture the verdict via plain command-substitution (no pipe inside the substitution): `verdict=$(classify_command "$line")`.
    - If the verdict starts with `REJECT`, emit `FAIL: line $LINENO classified $verdict` to stderr and exit 1.
    - On clean pass through the file, emit `PASS: pre-bash-shape-guard.sh self-conforms to AP-009 (no compound chain > 2)` to stdout and exit 0.
    - The verifier is the P02 day-one floor for CON-3; FR-21's `finding-G-self-conformance.sh` (P03 deliverable) is the M028-classifier-aware companion that lints the same file against the AP-009 rule under the extended classifier.

6. Run both verifiers via `bash scripts/util/run-probe.sh scripts/verify/m028/p02-hook-self-locate.sh` and `bash scripts/util/run-probe.sh scripts/verify/m028/p02-hook-self-conformance.sh`. Confirm both exit 0 with `PASS:` lines. If either fails, iterate on the hook body — do not weaken the verifier to make it pass.

7. Confirm the hook still passes the existing M021 `tests/run-prompt-corpus-replay.sh` if that harness is invocable in the working tree (no regression — the change is only to path resolution). If the M021 harness is not invocable here for procedural reasons, document the deferral in the task summary; FR-22's strict-superset gate (P03 deliverable) is the binding regression check.

## Must-Haves

This task addresses the phase Truths:
- "The PreToolUse shape-guard hook resolves its classifier and reject_lookup paths via `$(dirname "${BASH_SOURCE[0]}")` (with symlink resolution) and never references `$CLAUDE_PROJECT_DIR`."
- "The shape-guard hook self-conforms to its own classifier output under AP-009."

It produces the verifiers `scripts/verify/m028/p02-hook-self-locate.sh` and `scripts/verify/m028/p02-hook-self-conformance.sh` that gate those Truths.

## Verification

```bash
bash scripts/util/run-probe.sh scripts/verify/m028/p02-hook-self-locate.sh
```

```bash
bash scripts/util/run-probe.sh scripts/verify/m028/p02-hook-self-conformance.sh
```

## Notes

Expected output for the self-locate verifier is a single line `PASS: hook self-location via BASH_SOURCE confirmed; CLAUDE_PROJECT_DIR retired; pwd -P symlink resolution present`.

Expected output for the self-conformance verifier is a single line `PASS: pre-bash-shape-guard.sh self-conforms to AP-009 (no compound chain > 2)`.

If the self-conformance verifier reports `FAIL: line $LINENO classified REJECT: <ap-id> — <reason>`, the offending line in the hook body has too many connectors — split it into two statements. The classifier's verdict is authoritative; the hook author conforms.

The retirement of `CLAUDE_PROJECT_DIR` from the hook's logic is intentional per Finding A's root-cause analysis: the variable was the project-relative path that didn't exist in consumer projects, causing the hook to fall through to passthrough silently.

## Inputs

### From Previous Tasks

None within P02. Reads P01's deliverables only as background context.

### From Disk (Pre-existing)

- `scripts/hooks/pre-bash-shape-guard.sh` — M021/P05 hook. T01 modifies the classifier-resolution block; preserves all other logic (`reject_lookup`, stdin-read, `tool_name` extraction, classify+rewrite+reject decision tree, exit-code protocol).
- `scripts/verify/lib/shape-classifier.sh` — M021/P03 classifier library. T01 sources it from the new self-conformance verifier. Key API: `classify_command "<cmd>"` writes verdict to stdout (`ALLOW` on pass; `REJECT: <ap-id> — <reason>` on reject); returns 0 on ALLOW, non-zero on REJECT.
- `scripts/util/run-probe.sh` — shape-safe wrapper for invoking scripts under the harness shape-guard. T01's verification step uses it.

## Constraints

- **AD-19 single-script-file shape (CON-1)**: both new verifiers are flat single-file scripts under `scripts/verify/m028/`. No nested helper dirs. No inline compound bash, no plain `( ... )` subshells, no `$(...)` containing a pipe, no process substitution.
- **bash 3.2 + POSIX sh (CON-2)**: every line of the modified hook block AND the new verifiers runs on bash 3.2. No associative arrays. No `mapfile` / `readarray`. No unguarded `<<<` here-strings.
- **Shape-guard self-conformance (CON-3 + FR-21)**: every line T01 introduces into the hook body lints clean under the M021 classifier. The `p02-hook-self-conformance.sh` verifier gates this at the P02 day-one floor. Hard gate, no soft-warning grace.
- **No new runtime deps (CON-6)**: the resolution block uses only `cd`, `dirname`, `pwd -P`, `[ -f ... ]`, `[ -z ... ]`, plain string assignment. No `jq`, `node`, `python3`.
- **Non-Goal: no M021 surface revision**: T01 modifies only the classifier-resolution block of `pre-bash-shape-guard.sh`. It does NOT touch `scripts/verify/lib/shape-classifier.sh`, the existing `reject_lookup` function inside the hook, or `tests/fixtures/m021-prompt-corpus.txt`. M021's verification artifacts stay immutable.
- **Symlink resolution**: `pwd -P` resolves symlinks; do not use `pwd` alone or `realpath` (the latter is non-POSIX on some macOS variants without the GNU coreutils install).
