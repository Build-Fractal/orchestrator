---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P06"
milestone: "M008"
name: "Per-runtime installers — Claude Code, Codex, Cursor"
depends_on: ["T02"]
---

## Prerequisites

- T02 produced `packaging/bundle/` with manifest, skills, hooks, config, README.
- P05 runtime adapters exist with uniform `--probe`, `--register [--dry-run]`, and `--hook-config` interface:
  - `scripts/dispatch/adapters/runtime/claude-code.sh` — writes to `$HOME/.claude/commands/orchestrator-*.md`, JSON hooks fragment for `settings.json`. HOME guard refuses empty or `/`.
  - `scripts/dispatch/adapters/runtime/codex.sh` — writes to `$HOME/.codex/skills/`, TOML hooks fragment. HOME guard.
  - `scripts/dispatch/adapters/runtime/cursor.sh` — writes to `<--project-dir>/.cursor/rules/`. `--project-dir` flag required.

## Description

Write three installer scripts. Each one is the single-command install entrypoint for its runtime. The installer:

1. Invokes the corresponding P05 runtime adapter's `--probe` to confirm the runtime is available.
2. Delegates skill registration to the adapter's `--register` (with `--dry-run` pass-through).
3. Captures the adapter's `--hook-config` output and writes it to the runtime-specific config location (or emits `would_write=` under `--dry-run`).
4. Stages `packaging/bundle/config/orchestrator.default.yml` into the project's orchestrator state root (resolved via `scripts/state/resolve-root.sh`), skipping if a config already exists unless `--force`.
5. Prints a final `SUMMARY:` line with counts (`skills_installed=`, `hooks_wired=`, `config_written=`).

All installer tests during P06 execution MUST use hermetic `HOME=$(mktemp -d)` (claude-code, codex) or `--project-dir $(mktemp -d)` (cursor). No installer may touch the real developer HOME during P06.

## Steps

### Shared installer contract

Each installer supports these flags:

```
--project-dir PATH   # path to project root (required for cursor, optional for others — default: $PWD)
--dry-run            # no writes; emit `would_write=<path>` lines
--force              # overwrite existing skills and config
--verbose            # extra debug output on stderr
```

Exit codes:
- 0 — success
- 1 — generic failure (with `FAIL:` line on stderr)
- 2 — unsafe environment (e.g., empty `$HOME` on claude-code/codex)
- 3 — runtime not available (probe returned `available=false`)

### 1. `packaging/install/install-claude-code.sh`

Pseudocode outline (Bash 3.2):

```bash
#!/usr/bin/env bash
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ADAPTER="$REPO_ROOT/scripts/dispatch/adapters/runtime/claude-code.sh"
BUNDLE="$REPO_ROOT/packaging/bundle"

PROJECT_DIR="$PWD"
DRY_RUN=0
FORCE=0
VERBOSE=0

# arg parse (while-case) — set the four flags

# HOME guard — refuse empty or root HOME
if [ -z "${HOME:-}" ] || [ "$HOME" = "/" ]; then
  echo "FAIL: unsafe HOME (empty or '/')" >&2
  exit 2
fi

# 1. Probe
probe_out="$(bash "$ADAPTER" --probe)"
echo "$probe_out" | grep -q '^available=true' || {
  echo "FAIL: claude-code not available ($probe_out)" >&2
  exit 3
}

# 2. Register skills (delegate to adapter)
register_args="--register"
[ $DRY_RUN -eq 1 ] && register_args="$register_args --dry-run"
bash "$ADAPTER" $register_args   # adapter emits `would_write=` or `registered=true count=N`

# 3. Wire hooks: capture hook-config JSON, write/merge into $HOME/.claude/settings.json
hook_json="$(bash "$ADAPTER" --hook-config)"
target="$HOME/.claude/settings.json"
if [ $DRY_RUN -eq 1 ]; then
  echo "would_write=$target"
else
  mkdir -p "$HOME/.claude"
  # Merge strategy: if settings.json exists and --force not set, skip with SKIP: line.
  # Otherwise write hook_json as-is (simple initial implementation; full merge is T-TBD).
  if [ -e "$target" ] && [ $FORCE -eq 0 ]; then
    echo "SKIP: $target exists (use --force to overwrite)"
  else
    printf '%s\n' "$hook_json" > "$target"
    echo "wrote=$target"
  fi
fi

# 4. Stage config
state_root="$(bash "$REPO_ROOT/scripts/state/resolve-root.sh" --project-dir "$PROJECT_DIR" 2>/dev/null || echo "$PROJECT_DIR/.orchestrator")"
cfg_target="$state_root/config.yml"
if [ $DRY_RUN -eq 1 ]; then
  echo "would_write=$cfg_target"
elif [ -e "$cfg_target" ] && [ $FORCE -eq 0 ]; then
  echo "SKIP: $cfg_target exists (use --force to overwrite)"
else
  mkdir -p "$state_root"
  cp "$BUNDLE/config/orchestrator.default.yml" "$cfg_target"
  echo "wrote=$cfg_target"
fi

# 5. Summary
echo "SUMMARY: skills_installed=<N> hooks_wired=<0|1> config_written=<0|1>"
```

Key behaviors:
- All real writes are gated behind `--dry-run=0`.
- HOME guard matches the P05 adapter (refuse empty or `/`).
- Skill count comes from the adapter's `registered=true count=<N>` line.

### 2. `packaging/install/install-codex.sh`

Same structure as claude-code, but:
- `ADAPTER="$REPO_ROOT/scripts/dispatch/adapters/runtime/codex.sh"`
- Hook target: `$HOME/.codex/config.toml` (TOML, appended; the adapter's `--hook-config` emits TOML-shaped text).
- Skills land under `$HOME/.codex/skills/`.
- HOME guard identical.

### 3. `packaging/install/install-cursor.sh`

Same structure, but:
- `ADAPTER="$REPO_ROOT/scripts/dispatch/adapters/runtime/cursor.sh"`
- `--project-dir PATH` is **required**, not optional. If missing, exit 1 with `FAIL: --project-dir is required for cursor`.
- Skills land under `<project-dir>/.cursor/rules/`.
- Hook wiring is a no-op on cursor (it has no hook system in the same sense); the installer emits `hooks_wired=0` with a comment in the SUMMARY line.
- Delegates `--register --project-dir "$PROJECT_DIR"` to the adapter.

### 4. Verification scripts

Each installer gets one hermetic verification script. All three scripts follow the same pattern — set up a mktemp HOME + mktemp project-dir, invoke the installer with `--dry-run`, assert output contains `would_write=` lines pointing under the hermetic paths, then invoke without `--dry-run` and assert `SUMMARY:` line plus expected files exist.

- `scripts/verify/m008-p06-install-claude-code-hermetic.sh`
- `scripts/verify/m008-p06-install-codex-hermetic.sh`
- `scripts/verify/m008-p06-install-cursor-hermetic.sh`

Example (claude-code):

```bash
#!/usr/bin/env bash
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_HOME="$(mktemp -d)"
FIXTURE_PROJ="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"' EXIT

HOME="$FIXTURE_HOME" bash "$REPO_ROOT/packaging/install/install-claude-code.sh" \
  --project-dir "$FIXTURE_PROJ" --dry-run > /tmp/p06-install-cc.out 2>&1

grep -q '^would_write=' /tmp/p06-install-cc.out || {
  echo "FAIL: dry-run did not emit would_write= lines" >&2
  cat /tmp/p06-install-cc.out >&2
  exit 1
}

HOME="$FIXTURE_HOME" bash "$REPO_ROOT/packaging/install/install-claude-code.sh" \
  --project-dir "$FIXTURE_PROJ" > /tmp/p06-install-cc.out 2>&1 || {
  echo "FAIL: real install exited non-zero" >&2
  cat /tmp/p06-install-cc.out >&2
  exit 1
}

grep -q '^SUMMARY:' /tmp/p06-install-cc.out || {
  echo "FAIL: no SUMMARY line from installer" >&2
  exit 1
}

test -d "$FIXTURE_HOME/.claude/commands" || {
  echo "FAIL: skills dir not created under hermetic HOME" >&2
  exit 1
}

echo "PASS: claude-code installer hermetic test"
```

Codex/Cursor variants follow the same shape, with the appropriate adapter paths asserted.

### 5. Installer interface check

`scripts/verify/m008-p06-installer-interface.sh` verifies each of the three installers:
- Contains a `--dry-run` flag parser.
- Contains a `--force` flag parser.
- Exits 2 when invoked with `HOME=/` or empty (claude-code/codex only).
- Cursor exits 1 when `--project-dir` is omitted.
- All emit a final `SUMMARY:` line under `--dry-run`.

## Must-Haves

Addresses:

- All three installer scripts exist and run hermetically.
- Installer interface (flags, exit codes, summary line) is consistent.
- Key links: all three installers reference the corresponding P05 runtime adapter.

## Verification

```
bash scripts/verify/m008-p06-install-claude-code-hermetic.sh
bash scripts/verify/m008-p06-install-codex-hermetic.sh
bash scripts/verify/m008-p06-install-cursor-hermetic.sh
bash scripts/verify/m008-p06-installer-interface.sh
```

Each must emit a `PASS:` line and exit 0.

## Inputs

### From Previous Tasks

- `packaging/bundle/config/orchestrator.default.yml` (from T02) — staged into the project state root during install.
- `packaging/bundle/manifest.yml` (from T02) — informational; installer references `version:` in its SUMMARY line.
- `packaging/skills/orchestrator-*.md` (from T01) — already under `$HOME/.claude/commands/` after the P05 adapter's `--register` runs.

### From Disk (Pre-existing)

- `scripts/dispatch/adapters/runtime/claude-code.sh` (P05):
  - Key API: `--probe` → stdout `available=true|false runtime=claude-code reason=<text>`, exit 0.
  - Key API: `--register [--dry-run]` → writes 12 skills under `$HOME/.claude/commands/orchestrator-*.md`, emits `would_write=<path>` or `registered=true count=<N>`.
  - Key API: `--hook-config` → JSON fragment on stdout.
  - Behavior: refuses empty or `/` `$HOME`, exits 2.
- `scripts/dispatch/adapters/runtime/codex.sh` (P05):
  - Same interface as claude-code, writes to `$HOME/.codex/skills/`, hook output is TOML.
- `scripts/dispatch/adapters/runtime/cursor.sh` (P05):
  - Same interface, but `--register --project-dir PATH` is required. Writes to `<project-dir>/.cursor/rules/`.
- `scripts/state/resolve-root.sh` (P04):
  - Key API: outputs the resolved state root path (`.orchestrator/` by default, or overridden via `ORCHESTRATOR_ROOT` env or config file). Optional `--project-dir PATH` and `--verbose`.

## Constraints

- Hermetic-only: every test MUST use `mktemp -d` for HOME and project-dir. No real-HOME writes during P06.
- `--dry-run` must emit `would_write=` lines and exit 0 without touching disk.
- Installers must NOT re-implement adapter logic — always delegate to the P05 adapter.
- Bash 3.2 compat — no `declare -A`, no `mapfile`, no `${var,,}`.
- No python, no jq. TOML and JSON output from adapters are passed through as opaque text — the installer does not parse them.
- Exit codes: 0 success, 1 generic, 2 unsafe env, 3 runtime-not-available.

## Expected Output

- `packaging/install/install-claude-code.sh` (40+ lines, contains `--dry-run`)
- `packaging/install/install-codex.sh` (40+ lines, contains `--dry-run`)
- `packaging/install/install-cursor.sh` (40+ lines, contains `--project-dir`)
- `scripts/verify/m008-p06-install-claude-code-hermetic.sh`
- `scripts/verify/m008-p06-install-codex-hermetic.sh`
- `scripts/verify/m008-p06-install-cursor-hermetic.sh`
- `scripts/verify/m008-p06-installer-interface.sh`

All installer scripts mode 0755.
