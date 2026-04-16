---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M015"
name: "Fix the preflight → generate-permissions argument-passing bug"
depends_on: ["T02"]
---

## Prerequisites

- The bug: `scripts/lifecycle/evaluate-preflight.sh` line 74 invokes `bash "$GENERATE" "$PROJECT_ROOT" --tier "$TIER"`. This passes `$PROJECT_ROOT` as a positional argument. But `scripts/lifecycle/generate-permissions.sh` only accepts flag arguments — its argument loop is `--project-root | --defaults | --tier | *) error`. The positional `$PROJECT_ROOT` falls into the `*)` case and the script exits with `generate-permissions.sh: unknown option: <path>`. Preflight catches the non-zero exit and reports `permissions=error`.
- Discovered during M015 evaluate (2026-04-15). The pre-existing `.claude/settings.json` is intact because preflight's `2>/dev/null` swallowed the error and `write-permissions.sh` was never reached.
- This task fixes the call site in `evaluate-preflight.sh`, not the argument handler in `generate-permissions.sh`. The handler in `generate-permissions.sh` is correct as documented; the call site is wrong.

## Description

Change the `evaluate-preflight.sh` call site to use the documented `--project-root` flag form. Verify by re-running preflight against this project and confirming the result transitions from `permissions=error` to `permissions=generated` (or `permissions=merged`, depending on AD-13 user-settings detection).

## Steps

1. Edit `scripts/lifecycle/evaluate-preflight.sh` line 74. Change:

   ```
   if bash "$GENERATE" "$PROJECT_ROOT" --tier "$TIER" > "$canon_file" 2>/dev/null; then
   ```

   to:

   ```
   if bash "$GENERATE" --project-root "$PROJECT_ROOT" --tier "$TIER" > "$canon_file" 2>/dev/null; then
   ```

   This is a 1-token insertion (`--project-root` before `"$PROJECT_ROOT"`).

2. Create `scripts/verify/m015-p01-preflight-permissions-ok.sh` with this exact content:

   ```bash
   #!/usr/bin/env bash
   set -eu
   out=$(bash scripts/lifecycle/evaluate-preflight.sh . B 2>&1) || true
   echo "$out" | grep -E 'permissions=(generated|merged)' >/dev/null || {
     echo "FAIL: preflight did not report permissions=generated or merged"
     echo "Got: $out"
     exit 1
   }
   echo "PASS: preflight reports permissions=generated or merged"
   ```

3. Make the verify script executable.

## Must-Haves

- `evaluate-preflight.sh` calls `generate-permissions.sh` using the `--project-root` flag form.
- A fresh run of `bash scripts/lifecycle/evaluate-preflight.sh . B` reports `permissions=generated` or `permissions=merged` (per AD-13 user-settings handling), not `permissions=error`.
- The pre-existing `.claude/settings.json` either remains intact (if merge applies) or is regenerated correctly (if no `_generated_by` marker exists).

## Verification

```
bash scripts/verify/m015-p01-preflight-permissions-ok.sh
```

Must print a `PASS:` line and exit 0.

## Inputs

### From Previous Tasks

None functionally — T03 fixes a bug independent of the deletions in T01 and T02. It is sequenced after T02 only to keep the linear chain simple.

### From Disk (Pre-existing)

- `scripts/lifecycle/evaluate-preflight.sh` — modify line 74 (the only line being changed)
- `scripts/lifecycle/generate-permissions.sh` — read for argument-handling reference; do not modify
- `scripts/lifecycle/write-permissions.sh` — invoked by preflight downstream; do not modify
- `.claude/settings.json` — may be modified by the merge path; that is the intended behavior per AD-13

## Constraints

- Modify only line 74 of `evaluate-preflight.sh`. No other refactor in this task.
- Do not modify `generate-permissions.sh`. Its argument handler is the documented contract; the call site is the bug.
- If the verify script reveals the merge path produces a `.claude/settings.json` that breaks existing behavior, surface that as a deviation. It is not expected; this is a 1-token fix to a clearly broken call site.

## Expected Output

After this task:
- `git diff scripts/lifecycle/evaluate-preflight.sh` shows a 1-token insertion on line 74.
- `git status` shows a new file `scripts/verify/m015-p01-preflight-permissions-ok.sh`.
- The verify script prints `PASS:` and exits 0.
- The pre-existing `permissions=error` outcome from M015 evaluate is no longer reproducible.
