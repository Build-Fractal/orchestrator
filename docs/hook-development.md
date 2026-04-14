# Hook Development Guide

> User guide for writing, testing, and debugging lifecycle hooks.
> Self-contained — follow this guide to add custom quality gates and automation to your orchestrated projects.

> Audience: users

## Overview

Hooks are external scripts that the orchestrator engine runs at specific points during task dispatch. They observe engine state, enforce quality gates, and report structured verdicts -- without modifying engine state. Every hook receives a read-only snapshot of the current phase directory and returns a verdict that tells the engine whether to continue, warn, or block.

Hooks are useful for:

- **Budget enforcement** -- block dispatch or phase advancement when cumulative cost exceeds a ceiling.
- **Payload validation** -- reject tasks whose payloads are too small, too large, or missing required sections.
- **Quality checks** -- warn or block when outputs fail to meet code quality thresholds.
- **External approval gates** -- integrate with external systems before allowing phase transitions.
- **Notifications** -- trigger alerts or log telemetry after dispatch completes.

Hooks are configured in a `hooks.yaml` file and registered under one of the four lifecycle points. The engine iterates over all enabled hooks in declaration order at each point.

---

## Hook Lifecycle Points

The engine fires hooks at four points in the task dispatch pipeline. Each point has different data availability and different blocking behavior.

### PRE_DISPATCH

**When**: After context assembly completes, before the agent dispatch begins. Fires once per task, including during dry-run sessions.

**What you see**: The phase directory at the moment context assembly finishes. This includes the task payload, phase plan, and any prior task results.

**Blocking**: If any PRE_DISPATCH hook returns `VERDICT:BLOCK` (or a non-zero exit with `block_on_fail: true`), the task is skipped. The engine records the task as blocked with `reason="hook_pre_dispatch"` and moves to the next task. The phase continues.

**Best for**: Payload validation, budget pre-checks, external approval gates.

### POST_DISPATCH

**When**: After the agent returns output and the result has been recorded to the execution log.

**What you see**: The phase directory with the recorded result included.

**Blocking**: POST_DISPATCH is **non-blocking**. If a hook fails, the engine emits a `SAFETY_WARNING` but does not block the task or the phase. The task continues to completion.

**Best for**: Output quality reporting, notification triggers, telemetry collection.

### POST_VERIFY

**When**: After the verification stage (`check-must-haves.sh`) completes, before the result is recorded.

**What you see**: The phase directory. The verification result is available in the engine's internal state but not yet written to the execution log.

**Blocking**: If any POST_VERIFY hook returns `VERDICT:BLOCK`, the task is blocked. The engine records the task as blocked with `reason="hook_post_verify"` and moves to the next task.

**Best for**: Phase completeness checks, summary quality gates, cross-task consistency validation.

### PRE_ADVANCE

**When**: After all tasks in a phase have been processed, before the engine advances the phase/task state. This is the last gate before a phase transition.

**What you see**: The phase directory with all task results recorded.

**Blocking**: If any PRE_ADVANCE hook fails, the engine performs a **hard stop** -- it exits with code 6 and does not advance the phase. The checkpoint from the last completed task is preserved on disk, so crash recovery works normally on the next run.

**Best for**: Final budget enforcement, knowledge consolidation triggers, external approval gates for phase transitions.

---

## Verdict Protocol

Hooks communicate outcomes to the engine by printing **verdict lines** to stdout. The format is:

```
VERDICT:<verdict> reason=<reason>
```

The reason value can be quoted or unquoted:

```
VERDICT:PASS reason=ok
VERDICT:BLOCK reason="budget exceeded by 150 cents"
```

If a hook emits multiple verdict lines, the engine uses the **most severe** one.

### PASS

**Severity**: 0 (lowest). The hook's checks succeeded. The pipeline continues.

```
VERDICT:PASS reason="all payload checks passed"
```

### WARN

**Severity**: 1. A non-critical issue was detected. The pipeline always continues -- WARN verdicts never block, regardless of the `block_on_fail` setting. The issue is logged for visibility.

```
VERDICT:WARN reason="payload is under 500 chars, may lack context"
```

### NEEDS_REVIEW

**Severity**: 2. Something warrants human attention but does not require blocking. The pipeline continues. Review the execution log after the run completes.

```
VERDICT:NEEDS_REVIEW reason="summary section missing expected headings"
```

### BLOCK

**Severity**: 3 (highest). A critical issue was detected. The pipeline must not continue past this point.

If `ORCH_FORCE` is set, the block is downgraded to a warning with `forced=1` and the pipeline continues. Otherwise, the engine triggers the lifecycle point's blocking behavior.

```
VERDICT:BLOCK reason="cumulative cost exceeds budget ceiling"
```

### No Verdict Lines

If a hook does not print any `VERDICT:` lines, the engine falls back to exit code semantics:

- **Exit 0**: treated as PASS.
- **Non-zero exit with `block_on_fail: true`**: treated as a blocking failure.
- **Non-zero exit with `block_on_fail: false`**: emits a warning, pipeline continues.

Always prefer emitting explicit verdict lines. Exit-code-only semantics provide no reason string in the event log and make debugging harder.

---

## Writing Your First Hook

This walkthrough creates a hook from scratch and registers it in the hook configuration.

### Step 1: Create the Script

Create a new file. Hook scripts live anywhere in your repo, but `scripts/verify/guards/` is the conventional location.

```bash
mkdir -p scripts/verify/guards
```

Write the script. A minimal hook reads the snapshot, performs a check, and emits a verdict:

```bash
#!/usr/bin/env bash
# scripts/verify/guards/check-example.sh
# Example hook: blocks if a required marker file is missing.

set -euo pipefail

SNAPSHOT="$ORCH_HOOK_SNAPSHOT"

# Extract the snapshot (phase directory tar archive) to a temp directory
tmp_dir="$(mktemp -d)"
tar -xf "$SNAPSHOT" -C "$tmp_dir" 2>/dev/null || true

# Perform the check
if [ ! -f "$tmp_dir/MARKER.md" ]; then
  printf 'VERDICT:BLOCK reason="required MARKER.md not found"\n'
  rm -rf "$tmp_dir"
  exit 0
fi

printf 'VERDICT:PASS reason="MARKER.md present"\n'
rm -rf "$tmp_dir"
exit 0
```

Make the script executable:

```bash
chmod +x scripts/verify/guards/check-example.sh
```

### Step 2: Register in hooks.yaml

Open `templates/hooks.yaml` (or create a milestone/phase-level override) and add the hook under the appropriate lifecycle point:

```yaml
PRE_DISPATCH:
  example_check:
    name: Example Marker Check
    script: scripts/verify/guards/check-example.sh
    enabled: true
    block_on_fail: true
    description: Block dispatch if MARKER.md is missing from phase directory
```

The fields are:

| Field | Required | Description |
|-------|----------|-------------|
| `name` | yes | Human-readable label shown in events and logs |
| `script` | yes | Path to the script, relative to repo root |
| `enabled` | no | Set to `false`, `0`, or `no` to skip this hook |
| `block_on_fail` | no | Whether a non-zero exit blocks the pipeline (default: `true`) |
| `description` | no | Documents the hook's purpose |

### Step 3: Use the Verdict Helper (Optional)

If you source `scripts/lib/verdicts.sh`, you get access to the `emit_verdict` function, which handles quoting and validates the verdict value:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/verdicts.sh"

# emit_verdict validates the verdict and quotes the reason correctly
emit_verdict PASS "all checks passed"
emit_verdict BLOCK "budget exceeded by 150 cents"
```

If you pass an invalid verdict value to `emit_verdict`, it downgrades to WARN and includes the original value in the reason. This prevents silent misconfigurations.

### Step 4: Key Rules

Follow these rules in every hook:

1. **Never modify `$ORCH_HOOK_SNAPSHOT`**. The engine compares the snapshot's mtime and permissions after your hook finishes. If the snapshot was changed, the engine emits a `HOOK_VIOLATION` that is never downgraded, even under `ORCH_FORCE`.
2. **Never write to the phase directory or engine state**. Hooks are observers, not actors.
3. **Always exit 0** when emitting verdict lines. The verdict itself conveys pass/block semantics; a non-zero exit on top of a verdict line creates ambiguous signal.
4. **Keep execution under 30 seconds** (or the configured timeout). Long-running hooks block the entire dispatch pipeline.
5. **Clean up temporary files**. Extract the snapshot to a `mktemp -d` directory and `rm -rf` it before exiting.

---

## Example: Budget Gate Hook

This hook blocks dispatch if the cumulative cost recorded in the execution log exceeds a configurable budget ceiling. Register it at `PRE_DISPATCH` to prevent costly tasks from starting, or at `PRE_ADVANCE` to prevent phase transitions when the budget is exhausted.

```bash
#!/usr/bin/env bash
# scripts/verify/guards/check-budget-gate.sh
# Block if cumulative cost exceeds $ORCH_BUDGET_CEILING_CENTS.
#
# Reads: execution-log.jsonl from the snapshot
# Emits: VERDICT:PASS or VERDICT:BLOCK

set -euo pipefail

BUDGET_CEILING="${ORCH_BUDGET_CEILING_CENTS:-5000}"
SNAPSHOT="$ORCH_HOOK_SNAPSHOT"

tmp_dir="$(mktemp -d)"
tar -xf "$SNAPSHOT" -C "$tmp_dir" 2>/dev/null || true

# Find execution log
exec_log="$(find "$tmp_dir" -name 'execution-log.jsonl' -type f | head -1)"
if [ -z "$exec_log" ]; then
  printf 'VERDICT:PASS reason="no execution log found, skipping budget check"\n'
  rm -rf "$tmp_dir"
  exit 0
fi

# Sum cost_cents from all recorded entries
total_cost=0
while IFS= read -r line; do
  cost="$(printf '%s' "$line" | sed -n 's/.*"cost_cents":\([0-9]*\).*/\1/p')"
  if [ -n "$cost" ]; then
    total_cost=$(( total_cost + cost ))
  fi
done < "$exec_log"

rm -rf "$tmp_dir"

if [ "$total_cost" -gt "$BUDGET_CEILING" ]; then
  printf 'VERDICT:BLOCK reason="cumulative cost %d cents exceeds ceiling of %d cents"\n' \
    "$total_cost" "$BUDGET_CEILING"
  exit 0
fi

printf 'VERDICT:PASS reason="cumulative cost %d cents within ceiling of %d cents"\n' \
  "$total_cost" "$BUDGET_CEILING"
exit 0
```

Register it in `hooks.yaml`:

```yaml
PRE_DISPATCH:
  budget_gate:
    name: Budget Gate
    script: scripts/verify/guards/check-budget-gate.sh
    enabled: true
    block_on_fail: true
    description: Block dispatch if cumulative cost exceeds ORCH_BUDGET_CEILING_CENTS
```

To set the budget ceiling, export the environment variable before running the engine:

```bash
export ORCH_BUDGET_CEILING_CENTS=10000
```

---

## Example: Quality Check Hook

This hook checks whether task output files meet minimum quality criteria. It inspects summary files for expected headings and minimum line counts. Register it at `POST_VERIFY` to catch quality issues after verification but before results are finalized.

```bash
#!/usr/bin/env bash
# scripts/verify/guards/check-quality.sh
# Warn or block if task summaries are too short or missing expected sections.
#
# Reads: *-SUMMARY.md files from the snapshot
# Emits: VERDICT:PASS, VERDICT:WARN, or VERDICT:NEEDS_REVIEW

set -euo pipefail

MIN_LINES="${ORCH_QUALITY_MIN_LINES:-20}"
SNAPSHOT="$ORCH_HOOK_SNAPSHOT"

tmp_dir="$(mktemp -d)"
tar -xf "$SNAPSHOT" -C "$tmp_dir" 2>/dev/null || true

# Find summary files
summaries="$(find "$tmp_dir" -name '*-SUMMARY.md' -type f 2>/dev/null)"
if [ -z "$summaries" ]; then
  printf 'VERDICT:PASS reason="no summary files to check"\n'
  rm -rf "$tmp_dir"
  exit 0
fi

worst_verdict="PASS"
worst_reason="all summaries meet quality criteria"

while IFS= read -r summary; do
  filename="$(basename "$summary")"
  line_count="$(wc -l < "$summary" | tr -d ' ')"

  # Check minimum line count
  if [ "$line_count" -lt "$MIN_LINES" ]; then
    worst_verdict="WARN"
    worst_reason="$filename has $line_count lines (minimum: $MIN_LINES)"
  fi

  # Check for expected headings
  has_changes="$(grep -c '^## Changes' "$summary" 2>/dev/null || true)"
  has_decisions="$(grep -c '^## Decisions' "$summary" 2>/dev/null || true)"

  if [ "$has_changes" -eq 0 ] && [ "$has_decisions" -eq 0 ]; then
    worst_verdict="NEEDS_REVIEW"
    worst_reason="$filename missing both ## Changes and ## Decisions headings"
  fi
done <<< "$summaries"

rm -rf "$tmp_dir"

printf 'VERDICT:%s reason="%s"\n' "$worst_verdict" "$worst_reason"
exit 0
```

Register it in `hooks.yaml`:

```yaml
POST_VERIFY:
  quality_check:
    name: Quality Check
    script: scripts/verify/guards/check-quality.sh
    enabled: true
    block_on_fail: false
    description: Warn if task summaries are too short or missing expected sections
```

Note that `block_on_fail` is `false` here. This hook uses WARN and NEEDS_REVIEW verdicts for reporting, not BLOCK. If you want hard enforcement, change the verdicts to BLOCK and set `block_on_fail: true`.

---

## Testing Hooks

### Run in Dry-Run Mode

The fastest way to test a hook end-to-end is to run the engine in dry-run mode. Dry-run fires PRE_DISPATCH hooks but skips actual agent dispatch:

```bash
ORCH_DRY_RUN=1 bash scripts/engine/run.sh M001 P01
```

Look for these events in the output:

- `HOOK_START hook="your_hook_key"` -- confirms the hook was found and started.
- `HOOK_COMPLETE` -- the hook passed.
- `HOOK_WARNING` -- the hook emitted WARN.
- `HOOK_BLOCKED` -- the hook emitted BLOCK.
- `HOOK_VIOLATION` -- the snapshot was modified (always a bug in your hook).

### Test in Isolation

You can test a hook script directly by setting up the environment it expects:

```bash
# Create a fake snapshot from a real phase directory
phase_dir=".specify/orchestrator/milestones/M001/phases/P01"
snapshot="$(mktemp)"
(cd "$phase_dir" && tar -cf - .) > "$snapshot"
chmod 444 "$snapshot"

# Run the hook with the snapshot
ORCH_HOOK_SNAPSHOT="$snapshot" bash scripts/verify/guards/check-budget-gate.sh

# Clean up
rm -f "$snapshot"
```

This lets you iterate on your hook without running the full engine. You can substitute any directory as the snapshot source to test different scenarios.

### Verify Verdict Output

Check that your hook produces correctly formatted verdict lines. The format must be exact:

```
VERDICT:PASS reason=ok
VERDICT:BLOCK reason="some quoted reason"
```

Common formatting mistakes:

- Extra space after the colon: `VERDICT: PASS` -- this will not be parsed.
- Missing `reason=`: `VERDICT:PASS all good` -- the reason will be empty.
- Wrong verdict value: `VERDICT:FAIL` -- not in the closed set; will be ignored.

The valid verdict values are: `PASS`, `WARN`, `NEEDS_REVIEW`, `BLOCK`. Any other value is silently dropped by the parser.

### Check Snapshot Integrity

Verify your hook does not accidentally modify the snapshot. After running the hook, the snapshot file should still be read-only (`444` permissions) with its original mtime unchanged. If your hook extracts the tar to a temp directory (the recommended pattern), the snapshot itself is never touched.

---

## Debugging Hook Failures

### Hook Not Running

**Symptom**: No `HOOK_START` event for your hook.

**Check these**:

1. **Is the hook enabled?** Look for `enabled: false`, `enabled: 0`, or `enabled: no` in hooks.yaml.
2. **Is the hooks.yaml file found?** The engine resolves hooks.yaml in this order: explicit path argument, `ORCH_HOOKS_YAML_DEFAULT` env var, `templates/hooks.yaml`. If none exist, you will see `SAFETY_WARNING reason=hooks_yaml_missing`.
3. **Is the recipe parser available?** If `scripts/lib/recipe-parser.sh` is missing or broken, you will see `SAFETY_WARNING reason=recipe_parser_unavailable`.
4. **Is the hook under the correct lifecycle point?** A hook registered under `PRE_ADVANCE` will not fire during `PRE_DISPATCH`.

### Timeout

**Symptom**: Hook runs but gets killed, producing a non-zero exit code.

The default timeout is 30 seconds. The engine sends SIGTERM, waits 1 second, then sends SIGKILL. To debug:

1. Run the hook in isolation (see Testing Hooks above) and time it.
2. If the hook legitimately needs more time, increase the timeout: `export ORCH_HOOK_TIMEOUT_SEC=60` before running the engine.
3. If the hook is hanging, check for blocking I/O (waiting on stdin, network calls, missing files).

### Missing Verdict

**Symptom**: The hook exits 0 but no `VERDICT:` line appears in events. The engine treats it as a bare-exit-code pass.

This is not an error, but you lose structured reporting. Add an explicit `VERDICT:PASS reason="..."` line to get reason strings in the execution log.

### Snapshot Violation

**Symptom**: `HOOK_VIOLATION hook="your_hook" reason="snapshot_modified"` appears in events.

Your hook (or something it called) wrote to the snapshot file. This violation is **never downgraded**, even with `ORCH_FORCE`. Common causes:

1. Writing output to `$ORCH_HOOK_SNAPSHOT` instead of stdout.
2. Extracting the tar back into the snapshot path instead of a temp directory.
3. A subcommand that changes file permissions on its arguments.

Fix: always extract to a fresh `mktemp -d` directory, never touch the snapshot file itself.

### BLOCK Downgraded to Warning

**Symptom**: Your hook emits `VERDICT:BLOCK` but the pipeline continues anyway.

This happens when `ORCH_FORCE` is set. The engine downgrades BLOCK to a warning with `forced=1`. Check whether `ORCH_FORCE` is set in your environment or in the engine invocation.

### Wrong Lifecycle Point

**Symptom**: Hook fires but does not have the data it needs.

Each lifecycle point provides different data in the snapshot. For example, a hook checking task output will not find it at PRE_DISPATCH (the agent has not run yet). Move the hook to POST_DISPATCH or POST_VERIFY.

| Data Available | PRE_DISPATCH | POST_DISPATCH | POST_VERIFY | PRE_ADVANCE |
|----------------|:------------:|:-------------:|:-----------:|:-----------:|
| Phase plan | yes | yes | yes | yes |
| Task payload | yes | yes | yes | yes |
| Agent output | no | yes | yes | yes |
| Verification result | no | no | yes | yes |
| All task results | no | no | no | yes |

---

## Cross-References

- [Getting Started](getting-started.md) -- install the orchestrator and run your first milestone
- [Recipe Authoring Guide](recipe-authoring.md) -- control what context dispatched tasks receive
- [Hooks Reference](../references/hooks.md) -- complete reference with all fields, resolution rules, and parsing details
- [Events Reference](../references/events.md) -- event types emitted during hook lifecycle (HOOK_START, HOOK_COMPLETE, HOOK_BLOCKED)
- [State Machine Reference](../references/state-machine.md) -- phase and task state transitions that hooks can gate
- [Verification Ladder Reference](../references/verification-ladder.md) -- the 4-tier verification system that POST_VERIFY hooks extend
- [File Formats Reference](../references/file-formats.md) -- structure of execution logs, phase plans, and other files hooks may inspect
- Source: [`scripts/lib/hooks.sh`](../scripts/lib/hooks.sh) -- `run_hooks` implementation
- Source: [`scripts/lib/verdicts.sh`](../scripts/lib/verdicts.sh) -- verdict protocol implementation
- Source: [`templates/hooks.yaml`](../templates/hooks.yaml) -- default hook configuration
