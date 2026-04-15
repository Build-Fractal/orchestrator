---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P05"
milestone: "M008"
name: "codex.sh — Codex CLI runtime adapter"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `scripts/dispatch/detect-runtime.sh` exists.
- `scripts/state/resolve-root.sh` (from P04) exists.

Target script path: `scripts/dispatch/adapters/runtime/codex.sh` (create).

## Description

Create the Codex CLI runtime adapter mirroring the T02 (claude-code) interface:

- `--probe` → emits `available=true|false` and `reason=<text>`. Available iff `codex` binary is on PATH OR `$HOME/.codex/` directory exists OR `$CODEX_HOME` env is set.
- `--register [--dry-run]` → creates (or lists) `$HOME/.codex/skills/orchestrator-<cmd>.md` files per Codex CLI skill format.
- `--hook-config` → emits a TOML-shaped config.toml fragment describing Codex hook registrations.

Filename-registered (drop-in at `scripts/dispatch/adapters/runtime/codex.sh` = auto-registered per P02 pattern).

## Steps

1. Create `scripts/dispatch/adapters/runtime/codex.sh` with `#!/usr/bin/env bash` and `set -u`.
2. Parse `--probe | --register [--dry-run] | --hook-config` following the same while-case skeleton as T02.
3. --probe mode:
   - Check for `codex` binary: `command -v codex >/dev/null 2>&1` → binary-present.
   - Check `-d "$HOME/.codex"` → dir-present.
   - Check `-n "${CODEX_HOME:-}"` → env-set.
   - `available=true` if any signal; `reason=<which-signal>`. Else `available=false` / `reason=no-codex-signals`.
   - Exit 0 always.
4. --register mode:
   - HOME guard: fail if `HOME` unset or `/`.
   - Target directory: `$HOME/.codex/skills/`.
   - If `--dry-run`: emit `would_write=$HOME/.codex/skills/orchestrator-<basename>.md` per command in `commands/*.md` (excluding README.md).
   - Else: `mkdir -p "$HOME/.codex/skills"` and copy each command to `orchestrator-<basename>.md`. Emit `registered=true count=<N>`.
5. --hook-config mode:
   - Emit a TOML-shaped fragment on stdout, minimally:
     ```
     [orchestrator]
     runtime = "codex"
     hook_count = <N>
     target_file = "$HOME/.codex/config.toml"
     ```
6. `chmod +x scripts/dispatch/adapters/runtime/codex.sh`.

## Must-Haves

- Script exists, executable, Bash 3.2 compatible.
- `--probe` emits `available=`, `reason=` key=value and exits 0.
- `--register --dry-run` emits `would_write=` lines, writes nothing.
- `--register` with hermetic HOME fixture creates `$HOME/.codex/skills/orchestrator-*.md` files.
- HOME guard rejects `HOME=/` and empty HOME.
- `--hook-config` emits a fragment containing `runtime = "codex"`.

## Verification

```
bash scripts/verify/m008-p05-runtime-adapter-interface.sh
bash scripts/verify/m008-p05-runtime-adapter-dry-run.sh
bash scripts/verify/m008-p05-runtime-adapter-home-guard.sh
bash scripts/verify/m008-p05-codex-register-hermetic.sh
```

Expected: `PASS: ...` and exit 0 for each.

## Inputs

### From Previous Tasks

- `scripts/dispatch/detect-runtime.sh` (from T01) — reference for Codex CLI env/marker probes.

### From Disk (Pre-existing)

- `scripts/dispatch/adapters/backend/local-codex.sh` (from P02) — reference for the Codex backend probe pattern (`command -v codex`, env checks).
- `commands/*.md` — orchestrator commands.

## Constraints

- NEVER write to real `$HOME/.codex/` during verification; hermetic HOME fixtures only.
- Do not invoke `codex` binary for any purpose in this script.
- Bash 3.2 compatible.
- No `jq` / `python3` runtime dependencies.

## Expected Output

After T03 completes:
- `scripts/dispatch/adapters/runtime/codex.sh` exists and is executable.
- `HOME=$(mktemp -d) bash scripts/dispatch/adapters/runtime/codex.sh --register` creates one `$HOME/.codex/skills/orchestrator-<cmd>.md` per orchestrator command.
- All four T03 verify scripts pass.
