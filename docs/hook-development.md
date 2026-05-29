# Hook Development Guide

**Hooks are optional external scripts that intercept the dispatch pipeline at four lifecycle points and emit a verdict that tells the engine to continue, warn, or block.**

> Audience: users (advanced, opt-in)

## TL;DR

- **Hooks are 100% optional.** The orchestrator runs fine with zero hooks. Add them only when you want a custom quality gate or automation that the built-in [4-tier verification ladder](../references/verification-ladder.md) (static checks → command execution → behavioral review → human review) does not already cover.
- **Mental model:** lifecycle interception with verdict-based blocking. The engine pauses at a lifecycle point, runs your script against a read-only snapshot, reads the `VERDICT:` line your script prints, and acts on it.
- **Hooks are observers, not actors.** They read a frozen snapshot and report; they never modify engine state. Violating that triggers an unconditional `HOOK_VIOLATION`.
- A hook is just a Bash script registered in a `hooks.yaml` file under one of four points: `PRE_DISPATCH`, `POST_DISPATCH`, `POST_VERIFY`, `PRE_ADVANCE`.

> **The shipped `templates/hooks.yaml` is a template, not a working configuration.** It registers six example hooks (`scripts/verify/guards/check-payload.sh`, `check-budget.sh`, `check-output.sh`, `check-phase-complete.sh`, `check-budget-advance.sh`, and `scripts/knowledge/trigger-consolidation.sh`) whose scripts are **not** included in the repository. Every one of them ships `enabled: false`, so a fresh install is quiet by default — the loader skips disabled hooks entirely and never reaches the missing-script check. The entries are copy-paste templates that document the registration shape. To activate one, author the matching script and flip its entry to `enabled: true`. See [Writing your first hook](#writing-your-first-hook).

## Why hooks exist

The engine already enforces quality mechanically. Hooks let *you* add project-specific gates the framework cannot know about — for example:

| Use case | Lifecycle point | Verdict it emits |
|----------|-----------------|------------------|
| Budget enforcement (block when cumulative cost exceeds a ceiling) | `PRE_DISPATCH` / `PRE_ADVANCE` | `BLOCK` |
| Payload validation (reject tasks too small/large or missing sections) | `PRE_DISPATCH` | `BLOCK` |
| Output quality checks (warn on short or malformed summaries) | `POST_DISPATCH` / `POST_VERIFY` | `WARN` / `NEEDS_REVIEW` |
| External approval gates before a phase transition | `PRE_ADVANCE` | `PASS` / `BLOCK` |
| Notifications / telemetry after dispatch completes | `POST_DISPATCH` | `PASS` |

## Prerequisites / assumes you know

- You have the orchestrator installed and have run at least one milestone. If not, start with [Getting Started](getting-started.md).
- You are comfortable writing a small Bash script and reading a `tar` archive.
- This is an **advanced opt-in extension** — skip it entirely if the built-in verification ladder meets your needs.

## Section index

- [Hook lifecycle points](#hook-lifecycle-points) — when each fires, what data is available, blocking behavior
- [Verdict protocol](#verdict-protocol) — exact line format and severity levels
- [Writing your first hook](#writing-your-first-hook) — four-step walkthrough
- [Key rules (and why)](#key-rules-and-why) — the invariants every hook must hold
- [Worked example: budget gate](#worked-example-budget-gate)
- [Worked example: quality check](#worked-example-quality-check)
- [Snapshot protocol](#snapshot-protocol) — what `$ORCH_HOOK_SNAPSHOT` is and how to read it
- [block_on_fail semantics](#block_on_fail-semantics)
- [Testing and debugging](#testing-and-debugging)
- [See also](#see-also)

---

## Hook lifecycle points

The engine fires hooks at four points in the task dispatch pipeline. It iterates over all enabled hooks **in declaration order** at each point. Each point exposes different data in the snapshot and has different blocking behavior — choose the earliest point that has the data your check needs.

### Data availability by lifecycle point

Use this table to pick the point where the data you need is present:

| Data in snapshot | PRE_DISPATCH | POST_DISPATCH | POST_VERIFY | PRE_ADVANCE |
|------------------|:------------:|:-------------:|:-----------:|:-----------:|
| Phase plan | yes | yes | yes | yes |
| Task payload | yes | yes | yes | yes |
| Agent output | no | yes | yes | yes |
| Verification result | no | no | yes | yes |
| All task results | no | no | no | yes |

> A hook checking task output will find nothing at `PRE_DISPATCH` (the agent has not run yet). Move it to `POST_DISPATCH` or later.

### PRE_DISPATCH

| | |
|---|---|
| **When** | After context assembly completes, before agent dispatch. Fires once per task, including during dry-run sessions. |
| **What you see** | Phase directory at the moment assembly finishes: task payload, phase plan, prior task results. |
| **Blocking** | A `VERDICT:BLOCK` (or non-zero exit with `block_on_fail: true`) skips the task. The engine records it blocked with `reason="hook_pre_dispatch"` and moves on; the phase continues. |
| **Best for** | Payload validation, budget pre-checks, external approval gates. |

### POST_DISPATCH

| | |
|---|---|
| **When** | After the agent returns output and the result is recorded to the execution log. |
| **What you see** | Phase directory with the recorded result included. |
| **Blocking** | **Non-blocking.** A failure emits a `SAFETY_WARNING`; the task and phase continue regardless. |
| **Best for** | Output-quality reporting, notification triggers, telemetry. |

### POST_VERIFY

| | |
|---|---|
| **When** | After the verification stage (`check-must-haves.sh`) completes, before the result is recorded. |
| **What you see** | Phase directory. The verification result is in engine internal state but not yet on the execution log. |
| **Blocking** | A `VERDICT:BLOCK` blocks the task; recorded with `reason="hook_post_verify"`; engine moves to the next task. |
| **Best for** | Phase-completeness checks, summary-quality gates, cross-task consistency. |

### PRE_ADVANCE

| | |
|---|---|
| **When** | After all tasks in a phase are processed, before the engine advances phase/task state. Last gate before a phase transition. |
| **What you see** | Phase directory with all task results recorded. |
| **Blocking** | A failure is a **hard stop** — the engine exits with code `6` and does not advance. The last completed task's checkpoint is preserved on disk, so [crash recovery](../references/state-machine.md) works normally on the next run. |
| **Best for** | Final budget enforcement, knowledge-consolidation triggers, external approval gates for phase transitions. |

---

## Verdict protocol

A **verdict** is the hook's structured outcome: the engine reads it from a line your script prints to stdout. The format is exact:

```
VERDICT:<verdict> reason=<reason>
```

The reason value may be quoted or unquoted:

```
VERDICT:PASS reason=ok
VERDICT:BLOCK reason="budget exceeded by 150 cents"
```

If a hook emits multiple verdict lines, the engine uses the **most severe** one.

### Severity levels

| Verdict | Severity | Blocks? | Meaning |
|---------|:--------:|---------|---------|
| `PASS` | 0 (lowest) | no | Checks succeeded; pipeline continues. |
| `WARN` | 1 | **never** — ignores `block_on_fail` | Non-critical issue; logged for visibility, pipeline continues. |
| `NEEDS_REVIEW` | 2 | no | Warrants human attention; pipeline continues. Review the execution log after the run. |
| `BLOCK` | 3 (highest) | yes (unless `ORCH_FORCE`) | Critical issue; triggers the lifecycle point's blocking behavior. With `ORCH_FORCE` set, downgraded to a warning with `forced=1`. |

The valid verdict values are exactly: `PASS`, `WARN`, `NEEDS_REVIEW`, `BLOCK`. Any other value is silently dropped by the parser.

### Verdict lines take precedence over exit code

When a hook **prints a `VERDICT:` line**, that verdict is authoritative — the exit code is ignored for pass/block purposes (this is why hooks should always `exit 0`; see [Key rules](#key-rules-and-why)).

When a hook prints **no** `VERDICT:` line, the engine falls back to exit-code semantics:

| Exit | `block_on_fail` | Result |
|------|-----------------|--------|
| `0` | any | treated as `PASS` |
| non-zero | `true` (default) | blocking failure |
| non-zero | `false` | warning; pipeline continues |

Always prefer explicit verdict lines: exit-code-only runs leave no reason string in the event log and are harder to debug.

---

## Writing your first hook

This walkthrough creates a hook from scratch and registers it. Hook scripts can live anywhere in your repo; `scripts/verify/guards/` is the conventional location.

> **Before you start: the default `templates/hooks.yaml` ships its examples disabled.** The shipped file registers six example hooks under `scripts/verify/guards/` (`check-payload.sh`, `check-budget.sh`, `check-output.sh`, `check-phase-complete.sh`, `check-budget-advance.sh`) and `scripts/knowledge/trigger-consolidation.sh` — all with `enabled: false`. **None of these scripts ship with the repository**; they document the registration shape only. Because every example is disabled, the default file produces no events on a fresh install — the loader skips disabled hooks before it would otherwise check for a missing script. To activate one, write the referenced script (this walkthrough shows how) and flip its entry to `enabled: true`, or register your own hook as shown below.

### Step 1: Create the script

```bash
mkdir -p scripts/verify/guards
```

A minimal hook extracts the snapshot, runs a check, and emits a verdict:

```bash
#!/usr/bin/env bash
# scripts/verify/guards/check-example.sh
# Example hook: blocks if a required marker file is missing.

set -euo pipefail

SNAPSHOT="$ORCH_HOOK_SNAPSHOT"

# $ORCH_HOOK_SNAPSHOT is a tar archive (a file, not a directory).
# Extract it to a temp dir — never read or write the archive in place.
tmp_dir="$(mktemp -d)"
tar -xf "$SNAPSHOT" -C "$tmp_dir" 2>/dev/null || true

if [ ! -f "$tmp_dir/MARKER.md" ]; then
  printf 'VERDICT:BLOCK reason="required MARKER.md not found"\n'
  rm -rf "$tmp_dir"
  exit 0
fi

printf 'VERDICT:PASS reason="MARKER.md present"\n'
rm -rf "$tmp_dir"
exit 0
```

Make it executable:

```bash
chmod +x scripts/verify/guards/check-example.sh
```

### Step 2: Register in hooks.yaml

Register the hook under the appropriate lifecycle point. The default `templates/hooks.yaml` ships with example entries that point at scripts the repository does **not** include, but they are all `enabled: false`, so they stay inert and emit nothing — you can author your hook right beside them and just set its own entry to `enabled: true`. To activate one of the bundled examples instead, write its missing script first, then flip that entry to `enabled: true`. You can also create a milestone-/phase-level override `hooks.yaml` that registers only your own hooks:

```yaml
PRE_DISPATCH:
  example_check:
    name: Example Marker Check
    script: scripts/verify/guards/check-example.sh
    enabled: true
    block_on_fail: true
    description: Block dispatch if MARKER.md is missing from phase directory
```

Hook fields:

| Field | Required | Description |
|-------|:--------:|-------------|
| `name` | yes | Human-readable label shown in events and logs |
| `script` | yes | Path to the script, relative to repo root |
| `enabled` | no | Set to `false`, `0`, or `no` to skip this hook |
| `block_on_fail` | no | Whether a non-zero exit blocks the pipeline (default: `true`) |
| `description` | no | Documents the hook's purpose |

### Step 3: Use the verdict helper (optional)

Source `scripts/lib/verdicts.sh` for the `emit_verdict` function, which handles quoting and validates the verdict value:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../../lib/verdicts.sh"

emit_verdict PASS "all checks passed"
emit_verdict BLOCK "budget exceeded by 150 cents"
```

If you pass an invalid verdict value, `emit_verdict` downgrades to `WARN` and includes the original value in the reason — preventing silent misconfigurations.

### Step 4: Verify and test

Run the hook in isolation, then end-to-end in dry-run mode — see [Testing and debugging](#testing-and-debugging).

### Checklist

- [ ] Script is executable (`chmod +x`).
- [ ] Snapshot is extracted to a `mktemp -d`, never read/written in place.
- [ ] Every code path emits a `VERDICT:` line and exits `0`.
- [ ] Temp directory is removed before every `exit`.
- [ ] Registered under the lifecycle point that actually has the data ([availability table](#data-availability-by-lifecycle-point)).

---

## Key rules (and why)

Every hook must hold these invariants. Each rule has a concrete reason:

1. **Never modify `$ORCH_HOOK_SNAPSHOT`.** The engine compares the snapshot's mtime and permissions after your hook finishes. Any change emits a `HOOK_VIOLATION` that is **never downgraded**, even under `ORCH_FORCE` — because a hook that mutates state can no longer be trusted as an observer.
2. **Never write to the phase directory or engine state.** Hooks are observers, not actors. *Why:* the engine's crash-recovery and audit guarantees depend on hooks being side-effect-free; a hook that writes state breaks resumability.
3. **Always `exit 0` when emitting verdict lines.** The verdict line is authoritative ([verdicts take precedence over exit code](#verdict-lines-take-precedence-over-exit-code)). A non-zero exit *on top of* a verdict line creates an ambiguous double signal — the engine can read it as both "blocked by verdict" and "failed by exit code." Exiting `0` keeps the verdict the single source of truth.
4. **Keep execution under the timeout (default 30s).** Hooks run synchronously inside the dispatch pipeline, so a slow hook stalls the whole run. Raise it with `export ORCH_HOOK_TIMEOUT_SEC=60` only when the work genuinely needs it.
5. **Clean up temporary files.** Extract to a `mktemp -d` directory and `rm -rf` it before every exit — otherwise long runs leak temp dirs.

---

## Worked example: budget gate

Blocks dispatch when cumulative cost in the execution log exceeds a configurable ceiling. Register at `PRE_DISPATCH` to stop costly tasks from starting, or at `PRE_ADVANCE` to stop phase transitions when the budget is exhausted.

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

Register it:

```yaml
PRE_DISPATCH:
  budget_gate:
    name: Budget Gate
    script: scripts/verify/guards/check-budget-gate.sh
    enabled: true
    block_on_fail: true
    description: Block dispatch if cumulative cost exceeds ORCH_BUDGET_CEILING_CENTS
```

Set the ceiling before running the engine:

```bash
export ORCH_BUDGET_CEILING_CENTS=10000
```

---

## Worked example: quality check

Checks whether task summaries meet minimum quality criteria — expected headings and a minimum line count. Register at `POST_VERIFY` to catch issues after verification but before results are finalized.

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

  if [ "$line_count" -lt "$MIN_LINES" ]; then
    worst_verdict="WARN"
    worst_reason="$filename has $line_count lines (minimum: $MIN_LINES)"
  fi

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

Register it:

```yaml
POST_VERIFY:
  quality_check:
    name: Quality Check
    script: scripts/verify/guards/check-quality.sh
    enabled: true
    block_on_fail: false
    description: Warn if task summaries are too short or missing expected sections
```

`block_on_fail` is `false` here because the hook reports via `WARN` / `NEEDS_REVIEW`, not `BLOCK`. For hard enforcement, change the verdicts to `BLOCK` and set `block_on_fail: true`.

---

## Snapshot protocol

`$ORCH_HOOK_SNAPSHOT` is the environment variable that points at the frozen state your hook may read. It is **a tar archive file** — not a directory — created by the engine with `tar -cf` from the phase directory and made read-only (`chmod 444`).

To inspect it, extract to a temp directory:

```bash
tmp_dir="$(mktemp -d)"
tar -xf "$ORCH_HOOK_SNAPSHOT" -C "$tmp_dir"
# ... read files under $tmp_dir ...
rm -rf "$tmp_dir"
```

Why a frozen tar archive:

- **Immutability is enforced.** The engine checks the archive's mtime and permissions after your hook returns; any change triggers an unconditional `HOOK_VIOLATION` ([rule 1](#key-rules-and-why)).
- **Isolation.** Reading from an extracted copy guarantees your hook cannot accidentally mutate live engine state.

Never `tar -xf` back into the snapshot path, redirect output to `$ORCH_HOOK_SNAPSHOT`, or run a command that changes its permissions — all three trip the violation check.

---

## block_on_fail semantics

`block_on_fail` controls only the **exit-code fallback path** — it has no effect when your hook prints a `VERDICT:` line.

| Situation | `block_on_fail` | Outcome |
|-----------|-----------------|---------|
| Hook prints `VERDICT:BLOCK` | any value | Blocks (per lifecycle point) — `block_on_fail` ignored |
| Hook prints `VERDICT:WARN` / `NEEDS_REVIEW` | any value | Never blocks — `block_on_fail` ignored |
| Hook prints **no** verdict, exits non-zero | `true` (default) | Blocks |
| Hook prints **no** verdict, exits non-zero | `false` | Warning only; pipeline continues |
| Hook prints **no** verdict, exits `0` | any value | Treated as `PASS` |

`block_on_fail` is configured **per hook** in `hooks.yaml` (defaulting from the `hook_defaults:` block, which ships as `block_on_fail: true`). Set it `false` for advisory hooks whose non-zero exits should never halt a run.

---

## Testing and debugging

### Run in dry-run mode

The fastest end-to-end test. Dry-run fires `PRE_DISPATCH` hooks but skips actual agent dispatch:

```bash
ORCH_DRY_RUN=1 bash scripts/engine/run.sh M001 P01
```

Watch for these events:

| Event | Means |
|-------|-------|
| `HOOK_START hook="your_hook_key"` | Hook was found and started |
| `HOOK_COMPLETE` | Hook passed |
| `HOOK_WARNING` | Hook emitted `WARN` |
| `HOOK_BLOCKED` | Hook emitted `BLOCK` |
| `HOOK_VIOLATION` | Snapshot was modified (always a bug in your hook) |

### Test in isolation

Build a fake snapshot from a real phase directory and run the hook directly — no engine needed:

```bash
phase_dir=".orchestrator/milestones/M001/phases/P01"
snapshot="$(mktemp)"
(cd "$phase_dir" && tar -cf - .) > "$snapshot"
chmod 444 "$snapshot"

ORCH_HOOK_SNAPSHOT="$snapshot" bash scripts/verify/guards/check-budget-gate.sh

rm -f "$snapshot"
```

Substitute any directory as the snapshot source to exercise different scenarios.

### Verify verdict output

The format must be exact. Common mistakes:

| Bad | Problem |
|-----|---------|
| `VERDICT: PASS` | Extra space after colon — not parsed |
| `VERDICT:PASS all good` | Missing `reason=` — reason is empty |
| `VERDICT:FAIL` | Not in the closed set (`PASS`/`WARN`/`NEEDS_REVIEW`/`BLOCK`) — ignored |

### Check snapshot integrity

After running, the snapshot file should still be `444` with its original mtime. If your hook extracts the tar to a `mktemp -d` (the recommended pattern), the snapshot is never touched.

### Troubleshooting symptoms

| Symptom | Cause / fix |
|---------|-------------|
| **No `HOOK_START` event** | Hook disabled (`enabled: false/0/no`); or `hooks.yaml` not found (resolution order: explicit path arg → `ORCH_HOOKS_YAML_DEFAULT` → `templates/hooks.yaml` → `SAFETY_WARNING reason=hooks_yaml_missing`); or `scripts/lib/recipe-parser.sh` missing (`SAFETY_WARNING reason=recipe_parser_unavailable`); or registered under the wrong lifecycle point. |
| **Hook killed / non-zero exit (timeout)** | Default timeout 30s (SIGTERM, 1s grace, SIGKILL). Raise with `export ORCH_HOOK_TIMEOUT_SEC=60` if legitimately slow. |
| **Missing verdict** | Hook exited `0` with no `VERDICT:` line; treated as bare-exit pass. Not an error, but you lose reason strings — add `VERDICT:PASS reason="..."`. |
| **`HOOK_VIOLATION reason="snapshot_modified"`** | Hook wrote to the snapshot. Never downgraded. Causes: redirecting output to `$ORCH_HOOK_SNAPSHOT`, extracting the tar back into the snapshot path, or a subcommand that chmods its arguments. Fix: always extract to a fresh `mktemp -d`. |
| **`BLOCK` downgraded to warning** | `ORCH_FORCE` is set; BLOCK becomes a warning with `forced=1`. Unset it in your environment or the engine invocation. |
| **Hook fires but lacks data** | Wrong lifecycle point — see the [data-availability table](#data-availability-by-lifecycle-point). Move the hook later (e.g. `PRE_DISPATCH` → `POST_VERIFY`). |

### Diagnosing a hanging hook

A hook that "hangs" is almost always waiting on blocking I/O. Pin down which:

1. **Run it in isolation under a timeout** and inspect what it was doing when killed:
   ```bash
   ORCH_HOOK_SNAPSHOT="$snapshot" timeout 10 bash -x scripts/verify/guards/check-example.sh
   ```
   `bash -x` traces each command; the last line before the hang is the culprit.
2. **Common blocking sources, in order of likelihood:**
   - **Reading stdin** — a bare `read` or a command like `cat` with no argument waits forever. Redirect from `/dev/null` if a tool insists on stdin: `some-cmd < /dev/null`.
   - **Network calls** — `curl`/`wget` with no `--max-time`. Add `curl --max-time 5 ...`.
   - **Missing files** — `find` over a huge tree or a `while read` against a file that never closes.
3. **Confirm it is I/O** by checking open descriptors while it hangs (in another terminal):
   ```bash
   lsof -p "$(pgrep -f check-example.sh)"
   ```
   A socket in `ESTABLISHED`/`SYN_SENT` means a network call; a `0u` pointing at a TTY means it is waiting on stdin.

---

## See also

- [Getting Started](getting-started.md) — install the orchestrator and run your first milestone
- [Recipe Authoring Guide](recipe-authoring.md) — control what context dispatched tasks receive
- [Hooks Reference](../references/hooks.md) — complete field reference, resolution rules, parsing details
- [Events Reference](../references/events.md) — `HOOK_START` / `HOOK_COMPLETE` / `HOOK_BLOCKED` and other hook events
- [State Machine Reference](../references/state-machine.md) — phase/task transitions hooks can gate
- [Verification Ladder Reference](../references/verification-ladder.md) — the 4-tier system `POST_VERIFY` hooks extend
- [File Formats Reference](../references/file-formats.md) — structure of execution logs, phase plans, and other files hooks inspect
- Source: [`scripts/lib/hooks.sh`](../scripts/lib/hooks.sh) — `run_hooks` implementation
- Source: [`scripts/lib/verdicts.sh`](../scripts/lib/verdicts.sh) — verdict protocol implementation
- Source: [`templates/hooks.yaml`](../templates/hooks.yaml) — example hook configuration; registers example hooks (all `enabled: false`) whose scripts are not shipped (see the notes under [TL;DR](#tldr) and [Writing your first hook](#writing-your-first-hook))
