---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P05"
milestone: "M008"
name: "cursor.sh — Cursor runtime adapter (best-effort)"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete.

Target script path: `scripts/dispatch/adapters/runtime/cursor.sh` (create).

## Description

Create the Cursor runtime adapter. Cursor's skill/command model is less standardized than Claude Code or Codex CLI, so this adapter is best-effort:

- Cursor uses project-local `.cursor/rules/` for rule-based customization, NOT a user-level `~/.cursor/` skill directory.
- `--register` writes `.cursor/rules/orchestrator-<cmd>.md` files into the CURRENT PROJECT directory (not HOME).
- `--probe` checks for `$PWD/.cursor/` OR Cursor-specific env vars.
- `--hook-config` emits a marker that documents Cursor's limited hook support (rules-based, no lifecycle hooks).

## Steps

1. Create `scripts/dispatch/adapters/runtime/cursor.sh` with `#!/usr/bin/env bash` and `set -u`.
2. Parse `--probe | --register [--dry-run] | --hook-config`. Accept an optional `--project-dir <path>` (defaults to `$PWD`) for hermetic testing.
3. --probe mode:
   - Check `-d "$PROJECT_DIR/.cursor"`, or env vars `CURSOR_TRACE_ID`, `CURSOR_SESSION_ID`, `CURSOR_USER`.
   - Emit `available=true` / `reason=<signal>` or `available=false` / `reason=no-cursor-signals`.
   - Exit 0.
4. --register mode:
   - PROJECT_DIR guard: fail if `PROJECT_DIR` is empty or `/`.
   - Target directory: `$PROJECT_DIR/.cursor/rules/`.
   - Also guard that HOME is not `/` (defensive parity with T02/T03 even though Cursor doesn't write to HOME).
   - If `--dry-run`: emit `would_write=$PROJECT_DIR/.cursor/rules/orchestrator-<basename>.md` per `commands/*.md`.
   - Else: `mkdir -p "$PROJECT_DIR/.cursor/rules"` and copy each command to `orchestrator-<basename>.md`. Emit `registered=true count=<N>`.
5. --hook-config mode:
   - Emit a minimal fragment:
     ```
     # cursor hook-config
     runtime = "cursor"
     hooks_supported = "false"
     hook_count = "0"
     note = "Cursor uses rule-based integration; no lifecycle hooks."
     ```
6. `chmod +x scripts/dispatch/adapters/runtime/cursor.sh`.

## Must-Haves

- Script exists, executable, Bash 3.2 compatible.
- `--probe` emits `available=`, `reason=` key=value and exits 0.
- `--register --dry-run` emits `would_write=` lines, writes nothing.
- `--register --project-dir <mktemp>` creates `<tmp>/.cursor/rules/orchestrator-*.md` files.
- Guards reject empty or `/` PROJECT_DIR.
- `--hook-config` output contains `runtime = "cursor"` and `hooks_supported = "false"`.

## Verification

```
bash scripts/verify/m008-p05-runtime-adapter-interface.sh
bash scripts/verify/m008-p05-runtime-adapter-dry-run.sh
bash scripts/verify/m008-p05-runtime-adapter-home-guard.sh
bash scripts/verify/m008-p05-cursor-register-hermetic.sh
```

Expected: `PASS: ...` and exit 0.

## Inputs

### From Previous Tasks

- `scripts/dispatch/detect-runtime.sh` (from T01) — reference for Cursor env var names.

### From Disk (Pre-existing)

- `commands/*.md` — orchestrator commands.

## Constraints

- Writes to `$PROJECT_DIR/.cursor/rules/` — use a hermetic `PROJECT_DIR=$(mktemp -d)` in verification, never the live project root.
- Bash 3.2 compatible.
- No `jq`/`python3` runtime dependencies.
- Best-effort implementation: Cursor hooks are not simulated; the adapter only advertises rule installation.

## Expected Output

- `scripts/dispatch/adapters/runtime/cursor.sh` exists, executable.
- `PROJECT_DIR=$(mktemp -d) bash scripts/dispatch/adapters/runtime/cursor.sh --register --project-dir "$PROJECT_DIR"` creates `<tmp>/.cursor/rules/orchestrator-<cmd>.md` files.
- All four T04 verify scripts pass.
