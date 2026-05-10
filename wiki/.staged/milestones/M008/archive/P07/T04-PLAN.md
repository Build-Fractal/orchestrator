---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P07"
milestone: "M008"
name: "reinit-handler.sh — update / reset / abort with custom-block preservation"
depends_on: ["T03"]
---

## Prerequisites

- T03 produced `scripts/lifecycle/init-project.sh`. That script's flow checks for an existing `<state_root>/config.yml` and (when `--force` is NOT set) invokes `scripts/lifecycle/reinit-handler.sh`.
- T03 also documented the exact interface: `reinit-handler.sh --project-dir PATH --state-root PATH --runtime NAME [--dry-run] [--verbose]`.
- T02 produced `templates/project-instruction.md` with `<!-- BEGIN CUSTOM -->` and `<!-- END CUSTOM -->` markers on their own lines. Reinit MUST preserve the content between those markers.

## Description

Create `scripts/lifecycle/reinit-handler.sh`. When a project already has an orchestrator config, re-invoking `orchestrator:init` delegates here. The handler offers three modes:

- **update** (default): re-render auto-filled sections of the instruction file while preserving the user's custom block; merge newly detected capability values into the existing config, preserving user-edited top-level fields.
- **reset**: fully regenerate both files (equivalent to `init-project.sh --force`).
- **abort**: exit 0 with no changes.

Because unattended auto mode must not prompt, in non-interactive invocation the handler defaults to emitting `REINIT: existing config detected; use --mode update|reset|abort` and exits with code 4. When a mode is passed explicitly, it runs the chosen mode and exits 0.

## Steps

### 1. Script skeleton

Create `scripts/lifecycle/reinit-handler.sh`, mode 0755, Bash 3.2.

```bash
#!/usr/bin/env bash
# scripts/lifecycle/reinit-handler.sh — handle re-initialization of an
# already-configured project. Called by init-project.sh when existing
# <state_root>/config.yml is detected and --force is NOT set.
#
# Usage:
#   reinit-handler.sh --project-dir PATH --state-root PATH --runtime NAME
#                     [--mode update|reset|abort] [--dry-run] [--verbose]
#
# Default mode: update (preserve custom block + merge capabilities).
#
# Exit:
#   0 success (mode ran).
#   4 no mode specified (non-interactive default — caller must re-invoke with --mode).
#   1 generic failure.
# Bash 3.2 compatible.

set -u
```

### 2. Arg parsing

```bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT_DIR=""
STATE_ROOT=""
RUNTIME=""
MODE=""
DRY_RUN=0
VERBOSE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    --state-root)  STATE_ROOT="$2";  shift 2 ;;
    --runtime)     RUNTIME="$2";     shift 2 ;;
    --mode)        MODE="$2";        shift 2 ;;
    --dry-run)     DRY_RUN=1;        shift ;;
    --verbose)     VERBOSE=1;        shift ;;
    -h|--help)     sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "FAIL: unknown argument '$1'" >&2; exit 1 ;;
  esac
done

for req in PROJECT_DIR STATE_ROOT RUNTIME; do
  eval "v=\$$req"
  [ -n "$v" ] || { echo "FAIL: --${req,,} required" >&2; exit 1; }
done
```

Note: `${req,,}` is Bash 4+. Replace with a Bash 3.2 safe form:

```bash
for req in project-dir state-root runtime; do
  case "$req" in
    project-dir) v="$PROJECT_DIR" ;;
    state-root)  v="$STATE_ROOT" ;;
    runtime)     v="$RUNTIME" ;;
  esac
  [ -n "$v" ] || { echo "FAIL: --$req required" >&2; exit 1; }
done
```

### 3. Non-interactive default (no --mode)

```bash
CONFIG_FILE="$STATE_ROOT/config.yml"
case "$RUNTIME" in
  claude-code) INSTRUCTION_FILE="$PROJECT_DIR/CLAUDE.md" ;;
  codex)       INSTRUCTION_FILE="$PROJECT_DIR/AGENTS.md" ;;
  cursor)      INSTRUCTION_FILE="$PROJECT_DIR/.cursor/rules/orchestrator.md" ;;
  *) echo "FAIL: unknown runtime $RUNTIME" >&2; exit 1 ;;
esac

if [ -z "$MODE" ]; then
  echo "REINIT: existing config at $CONFIG_FILE"
  echo "REINIT: re-run with --mode update (preserve custom), --mode reset (overwrite), or --mode abort"
  exit 4
fi
```

### 4. Mode: abort

```bash
if [ "$MODE" = "abort" ]; then
  echo "SUMMARY: mode=abort runtime=$RUNTIME config_file=$CONFIG_FILE changes=0"
  exit 0
fi
```

### 5. Extract custom block from existing instruction file

```bash
extract_custom_block() {
  local file="$1"
  # Emit the lines strictly between BEGIN and END markers (exclusive).
  # awk is POSIX and Bash 3.2 friendly.
  awk '
    /^<!-- BEGIN CUSTOM -->$/ { inblock=1; next }
    /^<!-- END CUSTOM -->$/   { inblock=0; next }
    inblock == 1 { print }
  ' "$file"
}

CUSTOM_BLOCK=""
if [ -f "$INSTRUCTION_FILE" ]; then
  CUSTOM_BLOCK="$(extract_custom_block "$INSTRUCTION_FILE")"
fi
```

### 6. Re-run detection + probe (same calls T03 makes)

```bash
PROJECT_OUT="$(bash "$REPO_ROOT/scripts/lifecycle/detect-project.sh" --project-dir "$PROJECT_DIR")"
CAP_OUT="$(bash "$REPO_ROOT/scripts/dispatch/detect-capabilities.sh" --profile 2>/dev/null || true)"

get_p() { echo "$PROJECT_OUT" | grep "^$1=" | head -1 | cut -d= -f2- ; }
get_c() { echo "$CAP_OUT"    | grep "^$1=" | head -1 | cut -d= -f2- ; }

PROJECT_TYPE="$(get_p project_type)"
LANGUAGE="$(get_p language)"
# ... (repeat for all keys; same list as T03 Step 7 + 8)

CAP_EXECUTION="$(get_c cap_execution)"
CAP_SCORE="$(get_c cap_score)"
# ... (repeat for all cap_* keys)

RECOMMENDED_INTENSITY="standard"
if [ "${CAP_SCORE:-0}" -le 1 ] 2>/dev/null; then
  RECOMMENDED_INTENSITY="quick"
elif [ "${CAP_SCORE:-0}" -ge 4 ] 2>/dev/null; then
  RECOMMENDED_INTENSITY="full"
fi

INITIALIZED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
```

### 7. Dry-run short-circuit

```bash
if [ $DRY_RUN -eq 1 ]; then
  echo "would_write=$INSTRUCTION_FILE (mode=$MODE, custom_block_preserved=$([ -n "$CUSTOM_BLOCK" ] && echo true || echo false))"
  echo "would_write=$CONFIG_FILE (mode=$MODE)"
  echo "SUMMARY: mode=$MODE runtime=$RUNTIME instruction_file=$INSTRUCTION_FILE config_file=$CONFIG_FILE"
  exit 0
fi
```

### 8. Mode: reset (full overwrite — same as init --force behavior, but without re-delegating to init-project.sh)

```bash
if [ "$MODE" = "reset" ]; then
  # Call init-project.sh with --force to avoid duplicating render logic.
  # This recursion is safe because --force skips the "existing config" check
  # before reaching reinit-handler.
  init_args="--project-dir \"$PROJECT_DIR\" --runtime \"$RUNTIME\" --force"
  [ $VERBOSE -eq 1 ] && init_args="$init_args --verbose"
  eval "bash \"$REPO_ROOT/scripts/lifecycle/init-project.sh\" $init_args"
  exit $?
fi
```

### 9. Mode: update — render template, inject preserved custom block

```bash
if [ "$MODE" = "update" ]; then
  # Render the template (same sed substitutions as T03 — extract into a
  # shared helper for DRY, or duplicate and document the mirror).
  rendered="$(mktemp)"
  # (apply all sed -e "s|{{KEY}}|VALUE|g" substitutions, same set as T03)
  sed \
    -e "s|{{project_name}}|$PROJECT_NAME|g" \
    -e "s|{{project_type}}|$PROJECT_TYPE|g" \
    -e "s|{{language}}|$LANGUAGE|g" \
    ...
    "$REPO_ROOT/templates/project-instruction.md" > "$rendered"

  # If we have a preserved custom block, substitute it in between the markers.
  if [ -n "$CUSTOM_BLOCK" ]; then
    merged="$(mktemp)"
    awk -v repl="$CUSTOM_BLOCK" '
      /^<!-- BEGIN CUSTOM -->$/ { print; print repl; inblock=1; next }
      /^<!-- END CUSTOM -->$/   { inblock=0; print; next }
      inblock != 1              { print }
    ' "$rendered" > "$merged"
    mv "$merged" "$INSTRUCTION_FILE"
    rm -f "$rendered"
  else
    mv "$rendered" "$INSTRUCTION_FILE"
  fi
  [ $VERBOSE -eq 1 ] && echo "wrote=$INSTRUCTION_FILE" >&2
fi
```

Note: the awk substitution prints the BEGIN marker, then the preserved block, then suppresses all original in-block lines until the END marker, then prints the END marker.

### 10. Config merge (update mode)

Preserve user-edited top-level fields (`state_root`, any custom keys the user added). Re-write auto-detected sub-sections (`project:` and `capabilities:`) and bump `initialized_at`.

Implementation approach: parse the existing config with a simple key-at-depth awk/grep approach. For P07's scope, use a **whole-section replace** strategy:

1. Read the existing config.
2. Strip out existing `project:` and `capabilities:` blocks (lines starting with `project:` / `capabilities:` up to the next top-level key or EOF).
3. Append freshly detected `project:` + `capabilities:` blocks at the end.
4. Update the `initialized_at:` line in-place.

Implementation (Bash 3.2 + awk):

```bash
if [ "$MODE" = "update" ]; then
  merged_cfg="$(mktemp)"
  # Pass 1: strip project: and capabilities: blocks (awk state machine).
  awk '
    BEGIN { skip = 0 }
    /^(project|capabilities):/ { skip = 1; next }
    skip == 1 && /^[a-zA-Z_][a-zA-Z0-9_]*:/ { skip = 0 }
    skip == 1 { next }
    { print }
  ' "$CONFIG_FILE" > "$merged_cfg"

  # Pass 2: update initialized_at in place.
  sed -i.bak "s|^initialized_at:.*|initialized_at: \"$INITIALIZED_AT\"|" "$merged_cfg"
  rm -f "$merged_cfg.bak"

  # Pass 3: append fresh project: and capabilities: blocks.
  cat >> "$merged_cfg" <<EOF

project:
  type: "$PROJECT_TYPE"
  language: "$LANGUAGE"
  framework: "$FRAMEWORK"
  ci_system: "$CI_SYSTEM"
  tools_detected: "$TOOLS_DETECTED"
capabilities:
  execution: "$CAP_EXECUTION"
  graph: $CAP_GRAPH
  mcp: $CAP_MCP
  ci: $CAP_CI
  subagent: $CAP_SUBAGENT
  score: $CAP_SCORE
EOF

  mv "$merged_cfg" "$CONFIG_FILE"
  [ $VERBOSE -eq 1 ] && echo "wrote=$CONFIG_FILE" >&2

  echo "SUMMARY: mode=update runtime=$RUNTIME instruction_file=$INSTRUCTION_FILE config_file=$CONFIG_FILE custom_block_preserved=true"
  exit 0
fi

echo "FAIL: unknown mode '$MODE' (expected update|reset|abort)" >&2
exit 1
```

Note: `sed -i.bak` works on both GNU sed and BSD/macOS sed. The `.bak` suffix is required for BSD compatibility; we remove the backup file.

### 11. Verification scripts

**`scripts/verify/m008-p07-reinit-preserves-custom.sh`**:

```bash
#!/usr/bin/env bash
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_HOME="$(mktemp -d)"
FIXTURE_PROJ="$(mktemp -d)"
STATE_ROOT="$FIXTURE_PROJ/.orchestrator"
trap 'rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"' EXIT

echo '{"name":"fixture"}' > "$FIXTURE_PROJ/package.json"

# 1. Initial init.
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
  --project-dir "$FIXTURE_PROJ" --runtime claude-code > /dev/null 2>&1 || {
    echo "FAIL: initial init failed" >&2
    exit 1
  }

# 2. Inject a custom instruction block + add a user-edited top-level config field.
INSTR="$FIXTURE_PROJ/CLAUDE.md"
python3 - <<'PY' "$INSTR" 2>/dev/null || {
  # Fallback without python: use awk to inject the custom text.
  awk '
    /^<!-- BEGIN CUSTOM -->$/ { print; print "USER_MARK: this must survive reinit."; next }
    { print }
  ' "$INSTR" > "$INSTR.new" && mv "$INSTR.new" "$INSTR"
}
PY

# Ensure the USER_MARK is present.
grep -q 'USER_MARK: this must survive reinit.' "$INSTR" || {
  echo "FAIL: test setup — USER_MARK not injected" >&2
  exit 1
}

# 3. Add user-edited top-level config field.
echo 'user_custom_field: "must survive"' >> "$STATE_ROOT/config.yml"

# 4. Re-run init (no --force). Should delegate to reinit-handler with exit 4.
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
  --project-dir "$FIXTURE_PROJ" --runtime claude-code > /tmp/p07-reinit.out 2>&1
rc=$?

if [ $rc -ne 4 ]; then
  echo "FAIL: init without --force should exit 4 (delegated), got $rc" >&2
  cat /tmp/p07-reinit.out >&2
  exit 1
fi
grep -q '^REINIT:' /tmp/p07-reinit.out || { echo "FAIL: no REINIT: line" >&2; exit 1; }

# 5. Call reinit-handler directly in update mode.
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/reinit-handler.sh" \
  --project-dir "$FIXTURE_PROJ" --state-root "$STATE_ROOT" --runtime claude-code --mode update \
  > /tmp/p07-reinit-update.out 2>&1
rc=$?

if [ $rc -ne 0 ]; then
  echo "FAIL: reinit update exited $rc" >&2
  cat /tmp/p07-reinit-update.out >&2
  exit 1
fi

# 6. Assert the custom block and user_custom_field survived.
grep -q 'USER_MARK: this must survive reinit.' "$INSTR" || {
  echo "FAIL: custom block lost after reinit update" >&2
  exit 1
}
grep -q 'user_custom_field: "must survive"' "$STATE_ROOT/config.yml" || {
  echo "FAIL: user_custom_field lost after reinit update" >&2
  cat "$STATE_ROOT/config.yml" >&2
  exit 1
}

# 7. Assert the freshly detected capabilities block is present.
grep -q '^capabilities:' "$STATE_ROOT/config.yml" || {
  echo "FAIL: capabilities block missing after update" >&2
  exit 1
}

echo "PASS: reinit update preserves custom block + user config fields"
```

Note: the embedded `python3 - <<PY` is documented as a fallback guard — the primary path is the awk injection via the HEREDOC's bash fallback. If `python3` is unavailable, the `||` branch runs the awk edit. Alternative cleaner approach: skip python entirely and use only awk injection. Pick one during execution; for plan purposes, either is acceptable.

**`scripts/verify/m008-p07-reinit-delegation.sh`** — asserts init delegates correctly:

```bash
#!/usr/bin/env bash
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_HOME="$(mktemp -d)"
FIXTURE_PROJ="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"' EXIT

echo '{"name":"fixture"}' > "$FIXTURE_PROJ/package.json"

# Initial init.
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
  --project-dir "$FIXTURE_PROJ" --runtime claude-code > /dev/null 2>&1

# Second invocation without --force: must exit 4 and emit REINIT:.
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
  --project-dir "$FIXTURE_PROJ" --runtime claude-code > /tmp/p07-del.out 2>&1
rc=$?
[ $rc -eq 4 ] || { echo "FAIL: expected exit 4 on delegation, got $rc" >&2; cat /tmp/p07-del.out >&2; exit 1; }
grep -q '^REINIT:' /tmp/p07-del.out || { echo "FAIL: no REINIT line" >&2; exit 1; }

# --force path: must succeed and fully regenerate.
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
  --project-dir "$FIXTURE_PROJ" --runtime claude-code --force > /tmp/p07-del-force.out 2>&1
rc=$?
[ $rc -eq 0 ] || { echo "FAIL: --force init exited $rc" >&2; cat /tmp/p07-del-force.out >&2; exit 1; }
grep -q '^SUMMARY:' /tmp/p07-del-force.out || { echo "FAIL: no SUMMARY from --force init" >&2; exit 1; }

echo "PASS: reinit delegation (exit 4 default, 0 with --force)"
```

## Must-Haves

Addresses:

- `scripts/lifecycle/reinit-handler.sh` exists with `update`/`reset`/`abort` modes.
- Non-interactive default (no `--mode`) emits `REINIT:` and exits 4.
- `update` mode preserves the `<!-- BEGIN CUSTOM --> ... <!-- END CUSTOM -->` block verbatim.
- `update` mode preserves user-added top-level config fields while refreshing `project:` and `capabilities:` blocks.
- `reset` mode delegates back to `init-project.sh --force`.
- Init without `--force` in a configured project exits 4 with `REINIT:` line.

## Verification

```
bash scripts/verify/m008-p07-reinit-preserves-custom.sh
bash scripts/verify/m008-p07-reinit-delegation.sh
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M008/phases/P07
```

Each must emit `PASS:` and exit 0.

## Inputs

### From Previous Tasks

- `scripts/lifecycle/init-project.sh` (from T03)
  - Key API: `init-project.sh --project-dir PATH --runtime NAME [--force] [--dry-run]` — handler's `reset` mode delegates here with `--force`.
  - Key behavior: exit 4 on existing config without `--force`; the handler emits this exit when no `--mode` is provided.
- `templates/project-instruction.md` (from T02) — handler re-renders same placeholders.
- `scripts/lifecycle/detect-project.sh` (from T01) — handler re-runs detection during update.

### From Disk (Pre-existing)

- `scripts/dispatch/detect-capabilities.sh` (P01) — re-run during update mode.

## Constraints

- Bash 3.2 only — no `declare -A`, no `${var,,}`, no `mapfile`.
- `sed -i` must use BSD-compatible form: `sed -i.bak ... && rm -f file.bak`.
- awk is POSIX — no GNU extensions.
- Custom-block preservation is exact-line match on `<!-- BEGIN CUSTOM -->` / `<!-- END CUSTOM -->`. If the user mangles those markers, the handler treats the block as empty (lossy but predictable).
- User-edited top-level config fields are preserved by the awk strip-and-rewrite approach: only `project:` and `capabilities:` blocks are rewritten; all other top-level keys survive verbatim.
- All tests hermetic via `mktemp -d`.

## Expected Output

- `scripts/lifecycle/reinit-handler.sh` (50+ lines, contains `BEGIN CUSTOM`, mode 0755)
- `scripts/verify/m008-p07-reinit-preserves-custom.sh` (mode 0755)
- `scripts/verify/m008-p07-reinit-delegation.sh` (mode 0755)
