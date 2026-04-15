# Contributor Guide

> Progressive disclosure reference for contributing to spec-kit-orchestrator scripts.
> Self-contained -- read this document to understand coding conventions, testing patterns,
> and compliance requirements without cross-referencing other docs.

> Audience: contributors

## Overview

This guide covers everything needed to write, modify, and review scripts in the
`scripts/` directory. It targets both human contributors and AI agents executing
tasks. The project is a spec-kit extension composed of markdown commands and bash
helper scripts. All scripts live under `scripts/` organized by concern:

- `state/` -- read-only state derivation (no side effects)
- `dispatch/` -- context assembly for task dispatch
- `verify/` -- mechanical verification with structured PASS/FAIL output
- `knowledge/` -- knowledge artifact generation (append-only where applicable)
- `lifecycle/` -- orchestration lifecycle management (creates/modifies files)
- `telemetry/` -- metrics recording and aggregation
- `lib/` -- shared libraries sourced by other scripts

Scripts live under `scripts/` organized by concern. New scripts must be
referenced by a command, a hook, or another script — dangling scripts are
dead infrastructure (Principle VIII).

---

## Coding Conventions

### Bash 3.2 Compatibility

macOS ships Bash 3.2. All scripts MUST work on Bash 3.2. The following
constructs are banned:

| Banned construct | Bash version | Alternative |
|---|---|---|
| `declare -A` (associative arrays) | 4.0+ | Use parallel indexed arrays |
| `${var,,}` / `${var^^}` (case transform) | 4.0+ | Use `tr '[:upper:]' '[:lower:]'` |
| `|&` (pipe stderr) | 4.0+ | Use `2>&1 \|` |
| `<(command)` as redirect target | 4.0+ (reliable) | Use temp file + `while read < "$tmp"` |
| `readarray` / `mapfile` | 4.0+ | Use `while IFS= read -r` loop |
| `${!prefix@}` (indirect expansion) | 4.0+ | Use `eval` carefully or restructure |
| `coproc` | 4.0+ | Not needed in this project |

Parallel indexed arrays example (instead of associative arrays):

```bash
# WRONG (Bash 4+)
declare -A config
config[key]="value"

# RIGHT (Bash 3.2)
CONFIG_KEYS=(key1 key2 key3)
CONFIG_VALS=(val1 val2 val3)
# Iterate with index
i=0
for key in "${CONFIG_KEYS[@]}"; do
  val="${CONFIG_VALS[$i]}"
  i=$((i + 1))
done
```

### Portable sed In-Place Editing

BSD sed (macOS) and GNU sed (Linux) handle `-i` differently. Never use
`sed -i` or `sed -i.bak` directly. Use a portable helper:

```bash
sed_i() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}
```

Better: source the shared helper if one exists in `scripts/lib/`.

### Double-Sourcing Guards

Every library file in `scripts/lib/` MUST have a double-sourcing guard at the
top, immediately after the header comment. This prevents re-initialization when
multiple scripts source the same library.

```bash
#!/usr/bin/env bash
# scripts/lib/example.sh -- Description of the library.
[ -n "${_EXAMPLE_SOURCED:-}" ] && return 0
_EXAMPLE_SOURCED=1

# ... library code ...
```

The guard variable MUST follow the pattern `_LIBNAME_SOURCED` where LIBNAME is
derived from the filename (e.g., `_ERRORS_SOURCED` for `errors.sh`,
`_STALENESS_SOURCED` for `staleness.sh`). See AP-003 in `../ANTIPATTERNS.md`
for the incident that led to this requirement.

### Error and Event Emission

Engine-managed scripts MUST emit structured events and a final result. This is
a constitution requirement (Principle II). A script that runs to completion
without emitting a RESULT line is treated as a silent failure.

**emit_result protocol** (from `scripts/lib/errors.sh`):

Called exactly once per script at completion. Prints a single `RESULT:` line.

```bash
source "$LIB_DIR/errors.sh"

# Success
emit_result ok "" "phase advanced to P03"

# Failure with error taxonomy
emit_result error CONFIG "routing.yaml missing required field models.heavy.id"
emit_result error DISPATCH "all models in fallback chain exhausted"
emit_result error STATE "milestone directory does not exist"
```

The error taxonomy is a closed set of six kinds:

- `CONFIG` -- configuration errors (missing fields, invalid YAML)
- `STATE` -- state derivation errors (missing directories, invalid state)
- `DISPATCH` -- dispatch pipeline errors (model exhaustion, payload issues)
- `VERIFY` -- verification errors (check failures)
- `BUDGET` -- budget exhaustion (dispatch count, duration)
- `IO` -- file system I/O errors

**emit_event protocol** (from `scripts/lib/events.sh`):

Prints `EVENT:` lines throughout execution for observability. Each event
includes a timestamp, run ID, and key-value pairs.

```bash
source "$LIB_DIR/events.sh"

emit_event SESSION_START run_id="$ORCH_RUN_ID" milestone=M004
emit_event TASK_START task=T02 phase=P02
emit_event GUARD_BLOCKED guard=payload_sanity reason="empty payload"
```

Canonical event types: `SESSION_START`, `SESSION_END`, `PHASE_START`,
`PHASE_COMPLETE`, `TASK_START`, `TASK_COMPLETE`, `DISPATCH_START`,
`DISPATCH_FALLBACK`, `VERIFY_START`, `VERIFY_COMPLETE`, `GUARD_BLOCKED`,
`GUARD_WARNING`, `SAFETY_WARNING`, `HOOK_START`, `HOOK_COMPLETE`,
`HOOK_BLOCKED`, `HOOK_VIOLATION`, `CHECKPOINT_WRITE`, `CHECKPOINT_RESUME`.

Unknown event types are emitted but also trigger a companion `SAFETY_WARNING`
so the drift is observable.

### Atomic Writes

Any script that writes to a file other agents or scripts might read MUST use
the temp-file-then-rename pattern to avoid partial reads:

```bash
_tmp="$(mktemp)"
# Write content to temp file
printf '%s\n' "$content" > "$_tmp"
# Atomic move into place
mv "$_tmp" "$target_file"
```

This is especially important for:
- Execution logs (JSONL append-only files)
- Lock files
- State files read by `derive-phase.sh`

For append operations (JSONL logs), use `>>` with a single `printf` call to
minimize the window where the file is being written.

### Script Structure

Every script follows this structure:

```bash
#!/usr/bin/env bash
# scripts/<dir>/<name>.sh -- One-line description
# Multi-line description of behavior, usage, arguments.
#
# Usage: <name>.sh <required-args> [optional-args]
#
# Bash 3.2 compatible (NFR-200).

set -euo pipefail

# --- Resolve paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Source libraries ---
. "$SCRIPT_DIR/../lib/errors.sh"
. "$SCRIPT_DIR/../lib/events.sh"

# --- Argument validation ---
if [ $# -lt 1 ]; then
  echo "<name>.sh: missing required argument" >&2
  echo "Usage: <name>.sh <arg>" >&2
  exit 1
fi

# --- Functions ---
do_work() {
  local input="$1"
  # ...
}

# --- Main logic ---
do_work "$1"
emit_result ok "" "completed successfully"
```

Key conventions:
- Always use `#!/usr/bin/env bash` as the shebang
- Always set `set -euo pipefail` (strict mode)
- Resolve `SCRIPT_DIR` and `PROJECT_ROOT` using `cd + pwd` (not readlink)
- Source libraries relative to `SCRIPT_DIR`
- Validate arguments before doing any work
- Output structured lines to stdout (e.g., `PASS:`, `RESULT:`, `RECORD:`)
- Output diagnostics and metrics to stderr
- Exit 0 for success, exit 1 for failure

### Structured Output Prefixes

Scripts communicate with the engine and other scripts through prefixed stdout
lines. Common prefixes:

- `PASS:` / `FAIL:` -- verification results (used by `verify/` scripts)
- `RESULT:{...}` -- final script result as JSON (emitted by `emit_result`)
- `EVENT:TYPE ...` -- lifecycle events (emitted by `emit_event`)
- `RECORD:APPENDED` -- log entry written
- `LOCK:` -- lock file operations
- `CONSOLIDATE:` -- consolidation operations

Never mix free-form text with structured output on stdout. Use stderr for
human-readable diagnostics.

---

## Testing Patterns

### Test File Naming

Tests are organized as numbered suites in `tests/`:

```
tests/test-s01-structure.sh      -- Structural invariants
tests/test-s02-state-machine.sh  -- State machine contracts
tests/test-s03-design-artifacts.sh
tests/test-s04-core-commands.sh
tests/test-s05-autonomous-mode.sh
tests/test-s06-knowledge-lifecycle.sh
tests/test-s07-integration.sh
tests/test-s08-auto-safety.sh
```

### Assertion Pattern

Every test suite uses the same pass/fail counting pattern:

```bash
#!/usr/bin/env bash
set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=0

pass() {
  TOTAL=$((TOTAL + 1))
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "PASS: $1"
}

fail() {
  TOTAL=$((TOTAL + 1))
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "FAIL: $1"
}

# ... test sections ...

echo ""
echo "=== Results: $PASS_COUNT/$TOTAL passed ==="
[ "$FAIL_COUNT" -eq 0 ] && exit 0 || exit 1
```

### Fixture Directories

Test fixtures live in `tests/fixtures/`. Each fixture simulates a specific
disk state. For example, state derivation tests use fixture directories that
represent each of the 10 canonical states:

```
tests/fixtures/state-pre-planning/
tests/fixtures/state-discussing/
tests/fixtures/state-executing/
...
```

### Writing Tests

When adding new functionality:

1. Add assertions to the appropriate existing test suite (match by concern).
2. If the feature introduces a new concern, create a new suite as
   `test-s##-<name>.sh` with the next sequential number.
3. Use fixture directories for any test that needs disk state.
4. Test both the happy path AND error paths (missing arguments, invalid state).
5. Prefer testing script output (structured prefixed lines) over testing
   internal state.

### Running Tests

```bash
# Run a single suite
bash tests/test-s01-structure.sh

# Run all suites
for t in tests/test-s*.sh; do bash "$t"; done
```

---

## Constitution v2.0 Compliance Checklist

When writing or reviewing scripts, verify compliance with each applicable
principle. Not every principle applies to every script -- use judgment on which
are relevant, but explicitly consider each one.

### I. Context Minimization

Scripts receive only what they need and produce only what is needed. Check:
- Does the script read files outside its stated scope?
- Does the output contain unnecessary data that inflates downstream context?

### II. Evidence Before Claims

Scripts emit structured evidence of their outcomes. Check:
- Does the script call `emit_result` exactly once before exiting?
- Does the script emit `emit_event` calls at significant lifecycle points?
- Would a silent failure (no RESULT line) be detectable?

### III. Design Before Code

New scripts require a design step in the task plan. Check:
- Was the script's interface (arguments, output, exit codes) designed before
  implementation?
- Is the script documented in its header comment?

### IV. Plans Assume Zero Context

Script documentation must be self-contained. Check:
- Does the header comment include usage, arguments, and output format?
- Could an agent with no codebase knowledge use this script from its header?

### V. Fresh Context Per Unit

Scripts must not carry state between invocations. Check:
- Does the script rely on any in-memory state from a prior run?
- Are all inputs passed as arguments or read from disk?

### VI. State On Disk Is Truth

All state is derived from files, never cached in memory. Check:
- Does the script write its results to disk before claiming completion?
- Can `derive-phase.sh` detect the script's effect from disk alone?

### VII. Knowledge Compounds

Scripts that generate knowledge must produce structured, discoverable output.
Check:
- Do knowledge-producing scripts write to the correct location in the hierarchy?
- Are outputs in the expected format (YAML frontmatter, markdown body)?

### VIII. No Dead Infrastructure

Every script must be reachable from a live code path. Check:
- Is the script referenced by at least one command or other script?
- If removing the script, does anything break?

### IX. Reproducibility Over Convenience

Identical inputs must produce identical outputs. Check:
- Does the script use `$ORCH_STARTED_AT` instead of inline `date` calls?
- Are there any sources of non-determinism (random IDs without seed control)?

### X. Templating Over Inference

Policy is declared in templates, mechanics in scripts. Check:
- Does the script hard-code any policy that should be in a YAML config?
- If behavior changes require editing this script instead of a template, the
  boundary is wrong.

### XI. Single Source of Truth

No duplicated state or configuration. Check:
- Does the script derive state (via `derive-phase.sh`) rather than caching it?
- Does it read configuration from one authoritative location?

### XII. Hook Isolation

Hook scripts operate in a sandbox. Check (if the script is a hook):
- Does the hook modify engine state or write to orchestrator directories?
- Does the hook respect the timeout (`$ORCH_HOOK_TIMEOUT_SEC`, default 30s)?
- Does it only read from the `$ORCH_HOOK_SNAPSHOT` path?

### XIII. Agent Instruction Schema

Dispatch instructions follow a declared schema. Check:
- Do context-assembly scripts follow the recipe declared in
  `context-recipe.yaml`?
- Would changing instruction format require a script change (bad) or a recipe
  change (good)?

---

## PR Review Checklist

Before merging any script change, verify:

- [ ] **Bash 3.2 compatible** -- no banned constructs (see table above)
- [ ] **Double-sourcing guard** -- present on all library files in `lib/`
- [ ] **Portable sed** -- uses `sed_i` helper, never raw `sed -i`
- [ ] **Structured output** -- `emit_result` called exactly once; output uses
      correct prefixes
- [ ] **Error paths** -- invalid arguments produce stderr message + exit 1
- [ ] **Header comment** -- includes usage, arguments, output format, exit codes
- [ ] **Tests exist** -- new functionality has assertions in the appropriate
      test suite
- [ ] **Tests pass** -- `bash tests/test-s##-<name>.sh` exits 0
- [ ] **No dead infrastructure** -- every new file is referenced from a live
      code path
- [ ] **Atomic writes** -- files read by other scripts use temp+mv pattern
- [ ] **No inline date** -- uses `$ORCH_STARTED_AT` for timestamps
- [ ] **Constitution check** -- applicable principles reviewed (see checklist
      above)

---

## Anti-Patterns

These are documented incidents from real development. Each references a
specific antipattern ID from the project antipattern register
(`../ANTIPATTERNS.md`).

### AP-001: Platform-Specific Bash Syntax

Using `done < <(command)` (process substitution as redirect target). Works on
Bash 4+ but fails on macOS Bash 3.2. Use the temp file pattern instead:

```bash
# WRONG
while IFS= read -r line; do
  process "$line"
done < <(find . -name "*.md")

# RIGHT
_tmp="$(mktemp)"
find . -name "*.md" > "$_tmp"
while IFS= read -r line; do
  process "$line"
done < "$_tmp"
rm -f "$_tmp"
```

### AP-002: Non-Portable sed -i

Using `sed -i.bak` creates junk `.bak` files on macOS. Always use a portable
`sed_i` helper function. See the Coding Conventions section above.

### AP-003: Missing Double-Sourcing Guards

Library files without `[ -n "${_LIBNAME_SOURCED:-}" ] && return 0` cause
re-initialization when sourced transitively by multiple scripts. Every library
in `scripts/lib/` MUST have this guard.

### Inline Loops in Emitted Commands

When a script or command file emits bash commands for an agent to execute, do
not embed for-loops, if-chains, or compound statements inline. The harness AST
parser blocks these patterns. Instead, write a wrapper script and invoke it.

### Silent Failures

A script that exits 0 without emitting a `RESULT:` line is a silent failure.
The engine cannot distinguish "succeeded" from "forgot to report." Always call
`emit_result` before exiting, even on error paths.

### Hardcoded Policy in Scripts

Embedding tier thresholds, model IDs, or routing rules directly in script
logic violates Principle X. These belong in YAML configuration files
(`routing.yaml`, `context-recipe.yaml`, `hooks.yaml`). Scripts implement
mechanics; templates declare policy.

### Cached State Variables

Reading state once and caching it in a variable for later use violates
Principle XI. Always re-derive state from disk via `derive-phase.sh` when you
need the current state. Stale cached state is the source of subtle bugs.

---

## Cross-References

- `../ANTIPATTERNS.md` -- full antipattern register with evidence
- `../.orchestrator/memory/constitution.md` -- constitution v2.0 (13 principles)
- `../references/constitution-walkthrough.md` -- principle-by-principle walkthrough with codebase examples
- `../tests/` -- test suites and fixtures
- `../references/architecture.md` -- system architecture, engine pipeline, subsystem map
- `../references/file-formats.md` -- structured output format definitions
- `lib/errors.sh` -- `emit_result` implementation and error taxonomy
- `lib/events.sh` -- `emit_event` implementation and event type registry
