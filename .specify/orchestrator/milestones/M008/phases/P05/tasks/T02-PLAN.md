---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P05"
milestone: "M008"
name: "claude-code.sh — Claude Code runtime adapter"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `scripts/dispatch/detect-runtime.sh` exists and can return `runtime=claude-code` for Claude Code environments.
- `scripts/state/resolve-root.sh` (from P04) exists and emits the resolved state root.

Target script path: `scripts/dispatch/adapters/runtime/claude-code.sh` (create; directory must be created if absent).

## Description

Create the Claude Code runtime adapter following the uniform runtime-adapter interface:

- `--probe` → emits `available=true|false` and `reason=<text>` key=value lines on stdout. Available iff `CLAUDECODE=1` OR `$HOME/.claude` directory exists.
- `--register [--dry-run]` → creates (or lists) `$HOME/.claude/commands/orchestrator-<cmd>.md` files, one per orchestrator command discovered under the repo's `commands/` directory.
- `--hook-config` → emits a JSON-shaped settings.json fragment to stdout describing the hook registrations for orchestrator lifecycle events.

The adapter is filename-registered (any file at `scripts/dispatch/adapters/runtime/*.sh` is a runtime adapter per the P02 pattern). No central registry edits.

## Steps

1. Create the directory `scripts/dispatch/adapters/runtime/` if it does not exist (use `mkdir -p`).
2. Create `scripts/dispatch/adapters/runtime/claude-code.sh` with `#!/usr/bin/env bash` and `set -u`.
3. Implement argument parsing via a while-case loop (matching the P02 adapter style in `scripts/dispatch/adapters/backend/local-agent.sh`):
   - `--probe` → sets `MODE=probe`
   - `--register` → sets `MODE=register`
   - `--dry-run` → sets `DRY_RUN=1`
   - `--hook-config` → sets `MODE=hook-config`
4. --probe mode:
   - If `CLAUDECODE=1` or `-d "$HOME/.claude"`, emit `available=true` + `reason=<which-signal>`.
   - Else emit `available=false` + `reason=no-claude-code-signals`.
   - Always exit 0.
5. --register mode:
   - HOME guard: if `HOME` is unset or equals `/`, emit `FAIL: unsafe HOME` on stderr, exit 2.
   - Resolve command list: iterate files matching `commands/*.md` in the repo root (one per orchestrator command). Excluding `commands/README.md` per MEM008.
   - Target directory: `$HOME/.claude/commands/`.
   - If `--dry-run`: for each source command file, emit `would_write=$HOME/.claude/commands/orchestrator-<basename>.md` to stdout. Write nothing.
   - Else: `mkdir -p "$HOME/.claude/commands"` and for each command, copy into `orchestrator-<basename>.md`. Emit `registered=true count=<N>`.
6. --hook-config mode:
   - Emit a JSON object on stdout describing orchestrator hook registrations. Minimum keys: `runtime="claude-code"`, `hook_count=<N>`, `target_file=$HOME/.claude/settings.json`. Use a heredoc with simple `{ "runtime": "claude-code", ... }` output — no `jq` dependency.
7. `chmod +x scripts/dispatch/adapters/runtime/claude-code.sh`.

The adapter MUST NOT be invoked with `--register` (non-dry-run) during P05 execution or verification. Verification uses `HOME=$(mktemp -d)` fixtures exclusively.

## Must-Haves

- Script exists, executable, Bash 3.2 compatible.
- `--probe` emits `available=`, `reason=` key=value lines and exits 0.
- `--register --dry-run` emits `would_write=` lines and writes nothing.
- `--register` with `HOME=$(mktemp -d)` creates `$HOME/.claude/commands/orchestrator-*.md` files.
- `--register` with `HOME=` or `HOME=/` exits non-zero with FAIL message.
- `--hook-config` emits a JSON-shaped fragment including `"runtime": "claude-code"`.

## Verification

```
bash scripts/verify/m008-p05-runtime-adapter-interface.sh
bash scripts/verify/m008-p05-runtime-adapter-dry-run.sh
bash scripts/verify/m008-p05-runtime-adapter-home-guard.sh
bash scripts/verify/m008-p05-claude-code-register-hermetic.sh
```

Expected: `PASS: ...` output for each, exit 0.

## Inputs

### From Previous Tasks

- `scripts/dispatch/detect-runtime.sh` (from T01)
  - Key API: runs as `bash scripts/dispatch/detect-runtime.sh [--verbose] [--force <name>]`
  - Key types: stdout key=value lines `runtime=<name>`, `confidence=<level>`
  - Behavioral contract: always exits 0 on valid inputs; `runtime=claude-code` when Claude Code env/marker detected.

### From Disk (Pre-existing)

- `scripts/dispatch/adapters/backend/local-agent.sh` (from P02) — reference for adapter arg-parsing skeleton and structured stdout conventions (copy the while-case pattern).
- `scripts/state/resolve-root.sh` (from P04) — used implicitly; not sourced directly in T02.
- `commands/*.md` — list of orchestrator commands whose skill files will be installed into `$HOME/.claude/commands/`.

## Constraints

- NEVER write to the real `$HOME/.claude/` during verification — all tests use `HOME=$(mktemp -d)`.
- NEVER invoke `claude-code.sh --register` (non-dry-run) from within P05 orchestrator execution — only verification tests invoke it, and only with hermetic HOME.
- Bash 3.2 compatible — no associative arrays, no `readarray`/`mapfile`, no `|&`.
- No runtime dependencies on `jq` or `python3`.
- File copy must be done by reading/writing bytes (`cp` is acceptable on macOS/Linux baseline).

## Expected Output

After T02 completes:
- `scripts/dispatch/adapters/runtime/claude-code.sh` exists and is executable.
- Running `HOME=$(mktemp -d) bash scripts/dispatch/adapters/runtime/claude-code.sh --register` creates one `$HOME/.claude/commands/orchestrator-<cmd>.md` file per orchestrator command.
- All four T02 verify scripts pass.
