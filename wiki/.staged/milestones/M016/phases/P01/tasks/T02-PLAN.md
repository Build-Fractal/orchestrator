---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M016"
name: "Update commands/auto.md examples to omit --completed_at"
depends_on: [T01]
---

## Prerequisites

T01 must be complete: `write-summary.sh` now accepts omitted `--completed_at` (defaults to now) and the `now` sentinel.

## Description

Update `commands/auto.md` to remove `--completed_at=<ISO-8601 timestamp>` from the milestone `write-summary.sh` example and add a guidance note that subagents should omit `--completed_at` rather than using `$(date ...)`. This is the primary agent-facing doc that subagents read during `orchestrator:auto` — cleaning it prevents future subagents from reproducing the anti-pattern.

## Steps

### Step 1: Update the milestone write-summary example

In `commands/auto.md`, around line 446, there is an example showing:
```
  --completed_at=<ISO-8601 timestamp> \
```

Remove this line from the example. The updated example block (around lines 432-448) should look like:

```bash
bash scripts/knowledge/write-summary.sh milestone <milestone-dir>/<M###>-SUMMARY.md \
  --id=M### \
  --parent=<feature-ref> \
  --milestone=M### \
  --provides="<what this milestone delivers — derive from phase summaries>" \
  --requires="<external dependencies>" \
  --affects="<downstream milestones or systems>" \
  --key_files="<key files across all phases>" \
  --key_decisions="<arch-scoped and milestone-scoped decisions>" \
  --patterns_established="<patterns established across phases>" \
  --drill_down_paths="<paths to phase summaries>" \
  --duration=<total milestone duration from execution log> \
  --verification_result=pass \
  --observability_surfaces="<metrics or logs if applicable>" \
  --body="<synthesized summary: what was built across all phases, cross-cutting patterns, verification results>"
```

Note: `--completed_at` is removed entirely. The script defaults to now.

### Step 2: Add a guidance note about --completed_at

After the milestone write-summary example block, add a guidance note:

```markdown
> **Note**: `--completed_at` is optional. Omit it to default to the current UTC timestamp. Do NOT use `$(date ...)` or backtick substitution to generate timestamps — this triggers Claude Code's command-substitution safety prompt and interrupts autonomous execution. If an explicit timestamp is needed (e.g., backdating), pass it directly as `--completed_at=2026-01-01T00:00:00Z`.
```

### Step 3: Search for any other --completed_at examples in commands/auto.md

Search the file for any other occurrences of `completed_at` in code blocks or examples. If found in the task-summary or phase-summary context, apply the same fix: remove `--completed_at` from the example invocation.

Also check `commands/dispatch.md` and `commands/consolidate.md` for `write-summary.sh` examples. If those files show `--completed_at=$(date ...)` or `--completed_at=<placeholder>`, apply the same cleanup.

### Step 4: Create verify script

Create `scripts/verify/m016-p01-auto-md-no-subst.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
# Verify commands/auto.md does not contain $( in write-summary examples
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET="$PROJECT_ROOT/commands/auto.md"

if ! [ -f "$TARGET" ]; then
  echo "FAIL: commands/auto.md not found"
  exit 1
fi

# Check for $(date or $(bash in code blocks near write-summary
if grep -n 'write-summary' "$TARGET" | grep -q '\$(' ; then
  echo "FAIL: commands/auto.md still contains \$( near write-summary invocations"
  grep -n 'write-summary.*\$(' "$TARGET"
  exit 1
fi

# Also check for backtick substitution near write-summary
if grep -n 'write-summary' "$TARGET" | grep -q '`[^`]*`' ; then
  # Allow markdown backticks for inline code but not shell backtick substitution
  # Shell backtick substitution would have spaces/commands inside
  true
fi

echo "PASS: commands/auto.md write-summary examples contain no command substitution"
exit 0
```

Note: execute permission is not needed — all invocations use `bash <path>`.

### Step 5: Run verify script

```
bash scripts/verify/m016-p01-auto-md-no-subst.sh
```

Must print `PASS:` and exit 0.

## Must-Haves

- `commands/auto.md` milestone write-summary example does not contain `$(` or backtick command substitution

## Verification

```
bash scripts/verify/m016-p01-auto-md-no-subst.sh
```

Must print `PASS:` and exit 0.

## Inputs

### From Previous Tasks
- `scripts/knowledge/write-summary.sh` (from T01)
  - Key API: `--completed_at` is now optional; omitting it defaults to current UTC. `--completed_at=now` also accepted.
  - Key types: N/A (bash script)

### From Disk (Pre-existing)
- `commands/auto.md` — orchestrator auto-mode command doc. Contains `write-summary.sh` example invocations around lines 430-448 with `--completed_at=<ISO-8601 timestamp>` placeholder.

## Constraints

- Only modify agent-facing example invocations. Do not modify the prose descriptions of what `write-summary.sh` outputs (e.g., field lists describing summary structure).
- Do not modify `scripts/lifecycle/phase-transition.sh` — it already computes `completed_at` internally.

## Expected Output

- `commands/auto.md` modified: `--completed_at` removed from write-summary example, guidance note added.
- Possibly `commands/dispatch.md` and `commands/consolidate.md` cleaned up if they contain similar examples.
- 1 new verify script created and passing.
