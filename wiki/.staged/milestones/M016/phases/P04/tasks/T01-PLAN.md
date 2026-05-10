---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M016"
name: "Promote safe tool wildcards to project-level settings.json"
depends_on: []
---

## Prerequisites

P01-P03 are complete. The project-level `.claude/settings.json` exists with orchestrator script wildcards but is missing common Unix tool wildcards that subagents invoke during autonomous execution. The `.claude/settings.local.json` has accumulated one-off entries from [M015](../../../../../milestones/M015/index.md) and earlier runs, some of which represent genuine tool needs that should be in the project-level file.

## Description

Promote safe tool wildcard entries from `settings.local.json` to the project-level `settings.json` so that a fresh clone with no local settings can run `orchestrator:auto` without approval prompts for common Unix tools. The entries to promote are the Class B allow-list gaps identified in the spec: `sed`, `awk`, `/usr/bin/sed`, `grep`, `wc`, `chmod`, `mkdir`, `touch`, `cat`, `head`, `tail`, `mv`, `cp`, and `find`.

This addresses SC-6: "settings.json (not settings.local.json) contains the allow-list entries needed for the auto path under project defaults."

## Steps

### Step 1: Read the current settings.json

Read `.claude/settings.json` to understand the current allow list. The file has YAML-like metadata at the top (`_generated_by`, `_generated_at`, `_autonomy_mode`) and a `permissions` object with `defaultMode`, `deny`, and `allow` arrays.

The current allow list already covers:
- `Read`, `Write`, `Edit`, `Glob`, `Grep`, `Agent`, etc.
- `Bash(bash scripts/*)` and variants for orchestrator scripts
- Variable assignment patterns (`Bash(output=*)`, `Bash(result=*)`, etc.)
- Flow control patterns (`Bash(for *)`, `Bash(if *)`, etc.)
- `Bash(test *)`, `Bash([ *)`, `Bash([[ *)`

What is MISSING: wildcards for common Unix tools that subagents need during autonomous execution (observed in M015 and M016 runs).

### Step 2: Add safe tool wildcards to the allow list

Add the following entries to the `allow` array in `.claude/settings.json`, after the existing `Bash(test *)` entry:

```json
      "Bash(sed *)",
      "Bash(/usr/bin/sed *)",
      "Bash(awk *)",
      "Bash(grep *)",
      "Bash(wc *)",
      "Bash(chmod *)",
      "Bash(mkdir *)",
      "Bash(touch *)",
      "Bash(cat *)",
      "Bash(head *)",
      "Bash(tail *)",
      "Bash(mv *)",
      "Bash(cp *)",
      "Bash(find *)",
      "Bash(sort *)",
      "Bash(uniq *)",
      "Bash(tr *)",
      "Bash(cut *)",
      "Bash(diff *)",
      "Bash(mktemp *)",
      "Bash(mktemp)",
      "Bash(date *)",
      "Bash(date)",
      "Bash(wc -l *)",
      "Bash(ls *)",
      "Bash(ls)"
```

These are the standard Unix tools that subagents invoke during verify scripts, file manipulation, and general task execution. They are safe for autonomous execution -- none perform destructive operations that aren't already covered by the deny list (e.g., `rm -rf /` is denied).

### Step 3: Update the _generated_at timestamp

Update the `_generated_at` field to the current date to record when the settings were last modified. Use the ISO 8601 format already in the file.

### Step 4: Validate the JSON is well-formed

After editing, validate that the file is well-formed JSON. A quick way is to check that `cat .claude/settings.json | python3 -c "import sys,json;json.load(sys.stdin)"` exits 0, or simply use the Read tool to visually verify the structure. Given the constraint that we avoid command substitution, simply re-read the file after editing and verify the structure visually.

### Step 5: Run the anti-pattern lint to ensure settings changes don't affect scan results

Run the anti-pattern lint from P03 to verify that the full agent-facing surface is still clean:

```
bash scripts/verify/anti-pattern-lint.sh
```

Expected: exit 0 (no violations). The settings.json file is not scanned by the linter (it only scans `commands/*.md` and `templates/*.md`), but this confirms nothing else was inadvertently changed.

## Must-Haves

- `.claude/settings.json` allow list contains wildcard entries for `sed`, `awk`, `grep`, `wc`, `chmod`, `mkdir`, `touch`, `cat`, `head`, `tail`, `mv`, `cp`, and `find`
- `.claude/settings.json` allow list contains `/usr/bin/sed *` entry for macOS path resolution
- The anti-pattern lint passes on the full agent-facing surface after changes

## Verification

```
bash scripts/verify/anti-pattern-lint.sh
```

Expected: exit 0. The linter confirms the agent-facing surface is still clean. Settings.json verification scripts are created in T03.

## Inputs

### From Previous Tasks

None (T01 is the first task in P04).

### From Disk (Pre-existing)

- `.claude/settings.json` -- project-level settings file with current allow/deny lists. Structure: `{ "_generated_by": "...", "permissions": { "defaultMode": "acceptEdits", "deny": [...], "allow": [...] } }`. The `allow` array currently has ~50 entries covering orchestrator scripts, variable assignments, and flow control. Missing: Unix tool wildcards.
- `.claude/settings.local.json` -- user-local settings with accumulated one-off entries from prior runs. Contains entries like `"Bash(/usr/bin/sed *)"`, `"Bash(awk '{print $1}')"`, `"Bash(grep *)"`, `"Bash(chmod +x *)"` that were accepted during M015. These are the source of truth for what needs promotion.
- `scripts/verify/anti-pattern-lint.sh` -- from P03. Linter for Class A patterns in agent-facing content. API: `bash scripts/verify/anti-pattern-lint.sh` (scans `commands/*.md`, `templates/*.md`). Exit 0 if clean, 1 with diagnostics if violations found.

## Constraints

- The `settings.json` file must remain valid JSON after editing.
- Do not remove any existing entries from the allow or deny lists.
- Do not modify `settings.local.json` -- it is user-specific and outside project scope.
- Wildcard entries use the `Bash(<tool> *)` format, matching the existing convention in the file.

## Expected Output

- `.claude/settings.json` modified with ~25 new allow-list entries for common Unix tools.
- Anti-pattern lint still passes (exit 0).
- No other files modified.
