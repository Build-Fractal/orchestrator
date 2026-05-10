---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P07"
milestone: "M003"
name: "Dual-Root Idempotency Check"
depends_on: ["T01"]
---

## Prerequisites

- T01 has landed: `migrate.sh` now resolves `$target_root` via `resolve-root.sh` (or `--output`) and exports `MIGRATE_TARGET_ROOT`.
- `scripts/migrate/lib/idempotency.sh` exists with two functions:
  - `check_existing_state <target_root>` — emits `clean` or `has_state` to stdout. Currently probes only `$target/.specify/orchestrator`, `$target/knowledge/*.md`, `$target/DECISIONS.md`, `$target/KNOWLEDGE-INDEX.md`.
  - `enforce_conflict_policy <target_root> <abort|merge|force>` — exits 4 when state exists and policy is `abort`; emits a warning and returns 0 for `force`/`merge`.

After T01, `$target_root` may be (for example) `/repo/.orchestrator` rather than `/repo`. The current `check_existing_state` looks for `$target/.specify/orchestrator` — under the new semantics that becomes `/repo/.orchestrator/.specify/orchestrator`, which is wrong.

## Description

Update `check_existing_state` so it correctly detects pre-existing orchestrator state under the new `$target_root` semantics established by T01, and so it covers BOTH [M008](../../../../../milestones/M008/index.md) canonical roots:

1. The case where `$target_root` itself IS an orchestrator root (e.g. `/repo/.orchestrator` or `/repo/.specify/orchestrator`) — detected by orchestrator marker files directly under it.
2. The case where `$target_root` is a project root that contains either `.orchestrator/` or `.specify/orchestrator/` — preserve the legacy detection so users who pass `--output /path/to/repo` still get the right behavior.

## Steps

### Step 1: Replace the body of `check_existing_state`

Open `scripts/migrate/lib/idempotency.sh`. Replace the `check_existing_state` function with the version below. Keep the `enforce_conflict_policy` function unchanged.

```bash
# check_existing_state <target_root>
# Returns: "clean" | "has_state"
#
# Detects orchestrator state in two layouts:
#   (a) $target IS an orchestrator root — marker files directly under it
#   (b) $target is a project root containing .orchestrator/ or
#       .specify/orchestrator/ subdirectories (legacy / parent-dir mode)
check_existing_state() {
    local target="$1"

    # Layout (a): target is an orchestrator root
    if [ -f "$target/KNOWLEDGE-INDEX.md" ]; then
        echo "has_state"
        return
    fi
    if [ -f "$target/DECISIONS.md" ]; then
        echo "has_state"
        return
    fi
    if [ -d "$target/knowledge" ]; then
        # Any *.md directly under knowledge/ counts as state
        for f in "$target/knowledge"/*.md "$target/knowledge"/*/*.md; do
            if [ -f "$f" ]; then
                echo "has_state"
                return
            fi
        done
    fi
    if [ -d "$target/milestones" ]; then
        echo "has_state"
        return
    fi

    # Layout (b): target is a project root with orchestrator subdirs
    if [ -d "$target/.orchestrator" ] && [ -n "$(ls -A "$target/.orchestrator" 2>/dev/null)" ]; then
        echo "has_state"
        return
    fi
    if [ -d "$target/.specify/orchestrator" ] && [ -n "$(ls -A "$target/.specify/orchestrator" 2>/dev/null)" ]; then
        echo "has_state"
        return
    fi

    echo "clean"
}
```

Notes:
- The Bash 3.2-safe glob loop (`for f in "$target/knowledge"/*.md ...`) avoids `find` for parity with existing scripts.
- The `ls -A | -n` test is allowed because `$(...)` here contains no pipe and is the safe single-command form.

### Step 2: Update the conflict-policy error message

In `enforce_conflict_policy`, the current `abort` arm prints `Orchestrator state already exists at $target`. Keep that. No change.

### Step 3: Update the header comment block

At the top of `idempotency.sh`, update the docstring for `check_existing_state` to mention both layouts:

```
# check_existing_state <target_root>
#   Returns "clean" or "has_state".
#   Detects orchestrator state under $target_root in two layouts:
#     (a) $target_root IS an orchestrator root (KNOWLEDGE-INDEX.md, DECISIONS.md,
#         knowledge/, milestones/ directly under it)
#     (b) $target_root is a project root containing .orchestrator/ or
#         .specify/orchestrator/ subdirectories
```

## Must-Haves

This task addresses this phase truth:
- `lib/idempotency.sh` detects existing state at BOTH `.orchestrator/` and `.specify/orchestrator/` under the target, not just the legacy path.

## Verification

Manual scenarios (T05 will land an automated equivalent):

1. **Layout (a), `.orchestrator/` style**:
   ```
   tmp=$(mktemp -d); mkdir -p "$tmp/knowledge/pattern"; touch "$tmp/KNOWLEDGE-INDEX.md"
   bash scripts/migrate/migrate.sh --path . --output "$tmp"
   ```
   Expected: exit code 4, stderr line `ERROR: Orchestrator state already exists at $tmp`.

2. **Layout (b), `.specify/orchestrator/` style**:
   ```
   tmp=$(mktemp -d); mkdir -p "$tmp/.specify/orchestrator"; touch "$tmp/.specify/orchestrator/KNOWLEDGE-INDEX.md"
   bash scripts/migrate/migrate.sh --path . --output "$tmp"
   ```
   Expected: exit code 4, same error.

3. **Layout (b), `.orchestrator/` style under project root**:
   ```
   tmp=$(mktemp -d); mkdir -p "$tmp/.orchestrator"; touch "$tmp/.orchestrator/anything"
   bash scripts/migrate/migrate.sh --path . --output "$tmp"
   ```
   Expected: exit code 4, same error.

4. **Clean target**:
   ```
   tmp=$(mktemp -d); bash scripts/migrate/migrate.sh --path . --output "$tmp" --force
   ```
   Expected: migration proceeds (no exit 4 from idempotency).

## Inputs

### From Previous Tasks

- `scripts/migrate/migrate.sh` (from T01)
  - Key API: now exports `MIGRATE_TARGET_ROOT` and passes the resolved `$target_root` to `enforce_conflict_policy`.
  - Behavioral contract: `$target_root` is the absolute orchestrator state root when `--output` is given, otherwise resolver-derived.

### From Disk (Pre-existing)

- `scripts/migrate/lib/idempotency.sh` — modify `check_existing_state`. Do not change `enforce_conflict_policy` semantics (abort/merge/force flow stays identical).

## Constraints

- **Bash 3.2 only**. No `[[ ... =~ ]]` regex inside the function body, no associative arrays, no `mapfile`.
- **No new dependencies** — pure shell only.
- **Do not change `enforce_conflict_policy` exit codes or messages** beyond the docstring update.
- **Glob-loop safety**: when no files match, `for f in "$target/knowledge"/*.md` would yield the literal pattern under `set -u`/`set -e`. The `[ -f "$f" ]` guard handles that — verify the function still works when `knowledge/` exists but is empty.
- The legacy two-subdir probe (layout b) MUST be retained so users who pass a project-root-style `--output` keep getting accurate results.

## Expected Output

After this task, `bash scripts/migrate/migrate.sh --path . --output <dir>` (without `--force` or `--merge`) exits 4 whenever `<dir>` contains any of:
- `KNOWLEDGE-INDEX.md`, `DECISIONS.md`, `knowledge/*.md`, `knowledge/*/*.md`, or `milestones/` directly under it
- A non-empty `.orchestrator/` subdirectory
- A non-empty `.specify/orchestrator/` subdirectory

…and exits 0 otherwise (migration proceeds normally).
