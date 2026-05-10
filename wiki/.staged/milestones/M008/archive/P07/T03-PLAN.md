---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P07"
milestone: "M008"
name: "init-project.sh — top-level init entry point"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 produced `scripts/lifecycle/detect-project.sh` emitting key=value lines (language, framework, ci_system, tools_detected, project_type, has_git, has_tests).
- T02 produced `templates/project-instruction.md` (with `<!-- BEGIN CUSTOM -->` / `<!-- END CUSTOM -->` markers on their own lines) and `commands/init.md`.
- P01 provides `scripts/dispatch/detect-capabilities.sh --profile` emitting `cap_execution`, `cap_graph`, `cap_mcp`, `cap_ci`, `cap_subagent`, `cap_score`.
- P05 provides `scripts/dispatch/detect-runtime.sh` emitting `runtime=` + `confidence=`.
- P06 provides `packaging/install/install-<runtime>.sh` with shared flag contract (`--project-dir`, `--dry-run`, `--force`, `--verbose`) and exit codes 0/1/2/3.
- P04 provides `scripts/state/resolve-root.sh` — resolves state root via ORCHESTRATOR_ROOT → config → `.orchestrator/` → `.specify/orchestrator/` → default.

## Description

Create `scripts/lifecycle/init-project.sh`, the top-level `orchestrator:init` entry-point script. It orchestrates detection → probe → generate → verify, producing:

1. `<state_root>/config.yml` — project configuration.
2. A runtime-specific project instruction file (`CLAUDE.md` / `AGENTS.md` / `.cursor/rules/orchestrator.md`).
3. Skills registered via the matching P06 installer.

The script is purely a coordinator — it reads outputs from detect/probe scripts, renders the T02 template, writes config, and delegates installation to P06 installers. It does NOT re-implement any detection or registration logic.

Target wall-clock: under 2 minutes per SC-005.

## Steps

### 1. Script skeleton

Create `scripts/lifecycle/init-project.sh`, mode 0755, Bash 3.2 compatible.

```bash
#!/usr/bin/env bash
# scripts/lifecycle/init-project.sh — orchestrator:init entry point.
#
# Pipeline: detect (runtime + project) → probe (capabilities) → generate
# (config + instruction file) → verify (delegate installer).
#
# Usage:
#   init-project.sh [--project-dir PATH] [--runtime NAME] [--dry-run] [--force] [--verbose]
#
# Exit: 0 success, 1 generic failure, 2 unsafe env, 3 runtime unavailable,
#       4 already initialized (delegated to reinit-handler.sh).
# Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT_DIR="$PWD"
RUNTIME="auto"
DRY_RUN=0
FORCE=0
VERBOSE=0
```

### 2. Arg parsing

```bash
while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    --runtime)     RUNTIME="$2";     shift 2 ;;
    --dry-run)     DRY_RUN=1;        shift ;;
    --force)       FORCE=1;          shift ;;
    --verbose)     VERBOSE=1;        shift ;;
    -h|--help)     sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "FAIL: unknown argument '$1'" >&2; exit 1 ;;
  esac
done

[ -d "$PROJECT_DIR" ] || { echo "FAIL: not a directory: $PROJECT_DIR" >&2; exit 1; }
```

### 3. Runtime detection (when `--runtime auto`)

```bash
if [ "$RUNTIME" = "auto" ]; then
  RUNTIME_OUT="$(bash "$REPO_ROOT/scripts/dispatch/detect-runtime.sh" 2>/dev/null || true)"
  RUNTIME="$(echo "$RUNTIME_OUT" | grep '^runtime=' | head -1 | cut -d= -f2)"
  RUNTIME_CONFIDENCE="$(echo "$RUNTIME_OUT" | grep '^confidence=' | head -1 | cut -d= -f2)"
fi

case "$RUNTIME" in
  claude-code|codex|cursor) ;;
  unknown|"")
    echo "FAIL: could not auto-detect runtime. Supported: claude-code, codex, cursor." >&2
    echo "Re-run with --runtime <name> to override." >&2
    exit 3 ;;
  *)
    echo "FAIL: unsupported runtime '$RUNTIME'" >&2
    exit 3 ;;
esac
```

### 4. HOME guard (claude-code/codex only)

```bash
case "$RUNTIME" in
  claude-code|codex)
    if [ -z "${HOME:-}" ] || [ "$HOME" = "/" ]; then
      echo "FAIL: unsafe HOME (empty or '/') for runtime $RUNTIME" >&2
      exit 2
    fi ;;
esac
```

### 5. Resolve state root

The existing `scripts/state/resolve-root.sh` works on `$PWD`, so `cd` into the project-dir before invoking it. (Do not modify resolve-root.sh in this task.)

```bash
STATE_ROOT_ABS="$(cd "$PROJECT_DIR" && bash "$REPO_ROOT/scripts/state/resolve-root.sh" --absolute 2>/dev/null)"
[ -n "$STATE_ROOT_ABS" ] || STATE_ROOT_ABS="$PROJECT_DIR/.orchestrator"
CONFIG_FILE="$STATE_ROOT_ABS/config.yml"
```

### 6. Reinit delegation

```bash
if [ -f "$CONFIG_FILE" ] && [ $FORCE -eq 0 ]; then
  echo "REINIT: existing config at $CONFIG_FILE" >&2
  if [ -x "$REPO_ROOT/scripts/lifecycle/reinit-handler.sh" ]; then
    # Delegate, propagate --dry-run/--verbose.
    reinit_args="--project-dir \"$PROJECT_DIR\" --state-root \"$STATE_ROOT_ABS\" --runtime \"$RUNTIME\""
    [ $DRY_RUN -eq 1 ] && reinit_args="$reinit_args --dry-run"
    [ $VERBOSE -eq 1 ] && reinit_args="$reinit_args --verbose"
    # eval used intentionally to preserve quoted paths; args come only from script state, not user input.
    eval "bash \"$REPO_ROOT/scripts/lifecycle/reinit-handler.sh\" $reinit_args"
    rc=$?
    exit $rc
  else
    echo "FAIL: existing config detected but reinit-handler.sh missing. Use --force to overwrite." >&2
    exit 1
  fi
fi
```

### 7. Project detection

```bash
PROJECT_OUT="$(bash "$REPO_ROOT/scripts/lifecycle/detect-project.sh" --project-dir "$PROJECT_DIR")"
get() { echo "$PROJECT_OUT" | grep "^$1=" | head -1 | cut -d= -f2- ; }
PROJECT_TYPE="$(get project_type)"
LANGUAGE="$(get language)"
LANGUAGES_ALL="$(get languages_all)"
FRAMEWORK="$(get framework)"
FRAMEWORKS_ALL="$(get frameworks_all)"
CI_SYSTEM="$(get ci_system)"
TOOLS_DETECTED="$(get tools_detected)"
HAS_GIT="$(get has_git)"
HAS_TESTS="$(get has_tests)"
```

### 8. Capability probe

```bash
CAP_OUT="$(bash "$REPO_ROOT/scripts/dispatch/detect-capabilities.sh" --profile 2>/dev/null)"
cap() { echo "$CAP_OUT" | grep "^$1=" | head -1 | cut -d= -f2- ; }
CAP_EXECUTION="$(cap cap_execution)"
CAP_GRAPH="$(cap cap_graph)"
CAP_MCP="$(cap cap_mcp)"
CAP_CI="$(cap cap_ci)"
CAP_SUBAGENT="$(cap cap_subagent)"
CAP_SCORE="$(cap cap_score)"
[ -z "$CAP_SCORE" ] && CAP_SCORE=0
```

### 9. Default intensity from capability score

```bash
RECOMMENDED_INTENSITY="standard"
if [ "$CAP_SCORE" -le 1 ] 2>/dev/null; then
  RECOMMENDED_INTENSITY="quick"
elif [ "$CAP_SCORE" -ge 4 ] 2>/dev/null; then
  RECOMMENDED_INTENSITY="full"
fi
```

### 10. Compute instruction file path per runtime

```bash
case "$RUNTIME" in
  claude-code) INSTRUCTION_FILE="$PROJECT_DIR/CLAUDE.md" ;;
  codex)       INSTRUCTION_FILE="$PROJECT_DIR/AGENTS.md" ;;
  cursor)      INSTRUCTION_FILE="$PROJECT_DIR/.cursor/rules/orchestrator.md" ;;
esac

PROJECT_NAME="$(basename "$PROJECT_DIR")"
INITIALIZED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

### 11. Dry-run short-circuit

```bash
if [ $DRY_RUN -eq 1 ]; then
  echo "would_write=$CONFIG_FILE"
  echo "would_write=$INSTRUCTION_FILE"
  echo "would_invoke=$REPO_ROOT/packaging/install/install-$RUNTIME.sh --project-dir $PROJECT_DIR --dry-run"
  echo "SUMMARY: project_type=$PROJECT_TYPE runtime=$RUNTIME instruction_file=$INSTRUCTION_FILE config_file=$CONFIG_FILE cap_score=$CAP_SCORE recommended_intensity=$RECOMMENDED_INTENSITY next_step=run_orchestrator_evaluate"
  exit 0
fi
```

### 12. Render template (sed-based placeholder substitution)

Use a helper that reads the template and substitutes placeholders with collected values. Bash 3.2 safe — simple `sed` with fixed delimiters (use `|` since paths contain `/`).

Create a small helper file inline (or emit a one-off temp file) that performs the substitution:

```bash
render_template() {
  local tpl="$1"
  sed \
    -e "s|{{project_name}}|$PROJECT_NAME|g" \
    -e "s|{{project_type}}|$PROJECT_TYPE|g" \
    -e "s|{{language}}|$LANGUAGE|g" \
    -e "s|{{languages_all}}|$LANGUAGES_ALL|g" \
    -e "s|{{framework}}|$FRAMEWORK|g" \
    -e "s|{{frameworks_all}}|$FRAMEWORKS_ALL|g" \
    -e "s|{{ci_system}}|$CI_SYSTEM|g" \
    -e "s|{{tools_detected}}|$TOOLS_DETECTED|g" \
    -e "s|{{has_git}}|$HAS_GIT|g" \
    -e "s|{{has_tests}}|$HAS_TESTS|g" \
    -e "s|{{cap_execution}}|$CAP_EXECUTION|g" \
    -e "s|{{cap_graph}}|$CAP_GRAPH|g" \
    -e "s|{{cap_mcp}}|$CAP_MCP|g" \
    -e "s|{{cap_ci}}|$CAP_CI|g" \
    -e "s|{{cap_subagent}}|$CAP_SUBAGENT|g" \
    -e "s|{{cap_score}}|$CAP_SCORE|g" \
    -e "s|{{runtime}}|$RUNTIME|g" \
    -e "s|{{runtime_confidence}}|${RUNTIME_CONFIDENCE:-unknown}|g" \
    -e "s|{{instruction_file_path}}|$INSTRUCTION_FILE|g" \
    -e "s|{{state_root}}|$STATE_ROOT_ABS|g" \
    -e "s|{{recommended_intensity}}|$RECOMMENDED_INTENSITY|g" \
    -e "s|{{initialized_at}}|$INITIALIZED_AT|g" \
    "$tpl"
}
```

Caveat: values should not contain `|`. All values are sourced from controlled detectors that never emit `|`. Document this assumption in a comment.

### 13. Write instruction file

```bash
mkdir -p "$(dirname "$INSTRUCTION_FILE")"
render_template "$REPO_ROOT/templates/project-instruction.md" > "$INSTRUCTION_FILE"
[ $VERBOSE -eq 1 ] && echo "wrote=$INSTRUCTION_FILE" >&2
```

### 14. Write config.yml

```bash
mkdir -p "$STATE_ROOT_ABS"
cat > "$CONFIG_FILE" <<EOF
# Generated by orchestrator:init on $INITIALIZED_AT
schema_version: "1.0"
state_root: "$STATE_ROOT_ABS"
runtime: "$RUNTIME"
default_intensity: "$RECOMMENDED_INTENSITY"
initialized_at: "$INITIALIZED_AT"
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
[ $VERBOSE -eq 1 ] && echo "wrote=$CONFIG_FILE" >&2
```

### 15. Delegate installer

```bash
INSTALLER="$REPO_ROOT/packaging/install/install-$RUNTIME.sh"
if [ ! -x "$INSTALLER" ]; then
  echo "FAIL: installer not found at $INSTALLER" >&2
  exit 1
fi

install_args="--project-dir \"$PROJECT_DIR\""
[ $VERBOSE -eq 1 ] && install_args="$install_args --verbose"

INSTALL_OUT="$(eval "bash \"$INSTALLER\" $install_args" 2>&1)"
INSTALL_RC=$?
[ $VERBOSE -eq 1 ] && printf '%s\n' "$INSTALL_OUT" >&2

SKILLS_INSTALLED="$(echo "$INSTALL_OUT" | grep 'skills_installed=' | head -1 | sed 's/.*skills_installed=\([0-9]*\).*/\1/')"
[ -z "$SKILLS_INSTALLED" ] && SKILLS_INSTALLED=0
```

### 16. Summary

```bash
echo "SUMMARY: project_type=$PROJECT_TYPE runtime=$RUNTIME instruction_file=$INSTRUCTION_FILE config_file=$CONFIG_FILE cap_score=$CAP_SCORE recommended_intensity=$RECOMMENDED_INTENSITY skills_installed=$SKILLS_INSTALLED next_step=run_orchestrator_evaluate"
exit 0
```

### 17. Verification scripts

**`scripts/verify/m008-p07-init-interface.sh`** — flag and exit-code surface check (static):

```bash
#!/usr/bin/env bash
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/lifecycle/init-project.sh"

test -x "$SCRIPT" || { echo "FAIL: not executable: $SCRIPT" >&2; exit 1; }

for flag in "\-\-project-dir" "\-\-runtime" "\-\-dry-run" "\-\-force" "\-\-verbose"; do
  grep -qE "$flag" "$SCRIPT" || { echo "FAIL: missing flag parser for $flag" >&2; exit 1; }
done

# Exit codes 0/1/2/3/4 referenced
for rc in "exit 1" "exit 2" "exit 3"; do
  grep -qF "$rc" "$SCRIPT" || { echo "FAIL: missing '$rc' in script" >&2; exit 1; }
done

echo "PASS: init-project.sh interface surface"
```

**`scripts/verify/m008-p07-init-dry-run-hermetic.sh`**:

```bash
#!/usr/bin/env bash
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_HOME="$(mktemp -d)"
FIXTURE_PROJ="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"' EXIT

# Fake a Node project so detect-project has something interesting to report.
echo '{"name":"fixture"}' > "$FIXTURE_PROJ/package.json"

HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
  --project-dir "$FIXTURE_PROJ" --runtime claude-code --dry-run \
  > /tmp/p07-init-dry.out 2>&1
rc=$?

if [ $rc -ne 0 ]; then
  echo "FAIL: dry-run exited $rc" >&2
  cat /tmp/p07-init-dry.out >&2
  exit 1
fi

grep -q '^would_write=' /tmp/p07-init-dry.out || { echo "FAIL: no would_write= lines" >&2; exit 1; }
grep -q '^SUMMARY:' /tmp/p07-init-dry.out || { echo "FAIL: no SUMMARY: line" >&2; exit 1; }
grep -q 'CLAUDE.md' /tmp/p07-init-dry.out || { echo "FAIL: CLAUDE.md path not in dry-run output" >&2; exit 1; }

# Assert no writes happened.
test -f "$FIXTURE_PROJ/CLAUDE.md" && { echo "FAIL: dry-run wrote CLAUDE.md" >&2; exit 1; }
test -f "$FIXTURE_PROJ/.orchestrator/config.yml" && { echo "FAIL: dry-run wrote config.yml" >&2; exit 1; }

echo "PASS: init-project.sh --dry-run hermetic"
```

**`scripts/verify/m008-p07-init-e2e-hermetic.sh`**:

```bash
#!/usr/bin/env bash
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_HOME="$(mktemp -d)"
FIXTURE_PROJ="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"' EXIT

echo '{"name":"fixture"}' > "$FIXTURE_PROJ/package.json"

HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
  --project-dir "$FIXTURE_PROJ" --runtime claude-code \
  > /tmp/p07-init-e2e.out 2>&1
rc=$?

if [ $rc -ne 0 ]; then
  echo "FAIL: init exited $rc" >&2
  cat /tmp/p07-init-e2e.out >&2
  exit 1
fi

test -f "$FIXTURE_PROJ/CLAUDE.md" || { echo "FAIL: CLAUDE.md not created" >&2; exit 1; }
test -f "$FIXTURE_PROJ/.orchestrator/config.yml" || { echo "FAIL: config.yml not created" >&2; exit 1; }

grep -q 'schema_version:' "$FIXTURE_PROJ/.orchestrator/config.yml" || { echo "FAIL: config missing schema_version" >&2; exit 1; }
grep -q 'runtime:' "$FIXTURE_PROJ/.orchestrator/config.yml" || { echo "FAIL: config missing runtime" >&2; exit 1; }
grep -q 'state_root:' "$FIXTURE_PROJ/.orchestrator/config.yml" || { echo "FAIL: config missing state_root" >&2; exit 1; }
grep -q 'capabilities:' "$FIXTURE_PROJ/.orchestrator/config.yml" || { echo "FAIL: config missing capabilities" >&2; exit 1; }

# Placeholders must have been substituted.
grep -q '{{' "$FIXTURE_PROJ/CLAUDE.md" && { echo "FAIL: CLAUDE.md still contains {{placeholders}}" >&2; exit 1; }
grep -q '^## Project Overview' "$FIXTURE_PROJ/CLAUDE.md" || { echo "FAIL: CLAUDE.md missing Project Overview section" >&2; exit 1; }

# Skills should be under hermetic HOME (delegated by install-claude-code.sh).
test -d "$FIXTURE_HOME/.claude/commands" || { echo "FAIL: skills dir not created under hermetic HOME" >&2; exit 1; }

grep -q '^SUMMARY:' /tmp/p07-init-e2e.out || { echo "FAIL: no SUMMARY line" >&2; exit 1; }

echo "PASS: init-project.sh e2e hermetic (claude-code)"
```

**`scripts/verify/m008-p07-instruction-file-routing.sh`** — verifies the runtime → path mapping via dry-run:

```bash
#!/usr/bin/env bash
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

check_route() {
  # $1 = runtime, $2 = expected relative instruction path
  FIXTURE_HOME="$(mktemp -d)"
  FIXTURE_PROJ="$(mktemp -d)"
  HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
    --project-dir "$FIXTURE_PROJ" --runtime "$1" --dry-run > /tmp/p07-route.out 2>&1 || {
      rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"
      echo "FAIL: dry-run failed for runtime $1" >&2
      cat /tmp/p07-route.out >&2
      exit 1
    }
  if ! grep -qF "$FIXTURE_PROJ/$2" /tmp/p07-route.out; then
    rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"
    echo "FAIL: $1 did not route to $2" >&2
    cat /tmp/p07-route.out >&2
    exit 1
  fi
  rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"
}

check_route "claude-code" "CLAUDE.md"
check_route "codex"       "AGENTS.md"
check_route "cursor"      ".cursor/rules/orchestrator.md"

echo "PASS: instruction-file routing (claude-code/codex/cursor)"
```

## Must-Haves

Addresses:

- `scripts/lifecycle/init-project.sh` exists, supports all five documented flags, covers all five exit codes.
- Dry-run is hermetic, no-writes, emits `would_write=` + `SUMMARY:`.
- Real run writes `<state_root>/config.yml` + runtime-specific instruction file with all placeholders substituted.
- Instruction file routing matches runtime (CLAUDE.md / AGENTS.md / .cursor/rules/orchestrator.md).
- Key links: references detect-project, detect-capabilities, detect-runtime, resolve-root, installers, reinit-handler.

## Verification

```
bash scripts/verify/m008-p07-init-interface.sh
bash scripts/verify/m008-p07-init-dry-run-hermetic.sh
bash scripts/verify/m008-p07-init-e2e-hermetic.sh
bash scripts/verify/m008-p07-instruction-file-routing.sh
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M008/phases/P07
```

Each must emit `PASS:` and exit 0.

## Inputs

### From Previous Tasks

- `scripts/lifecycle/detect-project.sh` (from T01)
  - Key API: `detect-project.sh --project-dir PATH` → stdout key=value (`language=`, `framework=`, `ci_system=`, `tools_detected=`, `project_type=`, `has_git=`, `has_tests=`, `languages_all=`, `frameworks_all=`), exit 0.
- `templates/project-instruction.md` (from T02)
  - Key placeholders: `{{project_name}}`, `{{project_type}}`, `{{language}}`, `{{framework}}`, `{{ci_system}}`, `{{runtime}}`, `{{runtime_confidence}}`, `{{cap_score}}`, `{{cap_execution}}`, `{{cap_graph}}`, `{{cap_mcp}}`, `{{cap_ci}}`, `{{cap_subagent}}`, `{{state_root}}`, `{{recommended_intensity}}`, `{{initialized_at}}`, `{{instruction_file_path}}`.
  - Structure: HTML custom-block markers on their own lines.
- `commands/init.md` (from T02) — user-facing command doc; init-project.sh must match its documented interface.

### From Disk (Pre-existing)

- `scripts/dispatch/detect-runtime.sh` (P05):
  - Key API: stdout `runtime=<claude-code|codex|cursor|unknown>` + `confidence=<high|medium|low>`, exit 0.
- `scripts/dispatch/detect-capabilities.sh` (P01):
  - Key API: `--profile` flag emits `cap_execution=`, `cap_graph=true|false`, `cap_mcp=true|false`, `cap_ci=true|false`, `cap_subagent=true|false`, `cap_score=<0-5>`.
- `scripts/state/resolve-root.sh` (P04):
  - Key API: `--absolute` emits absolute state-root path on stdout, operates on `$PWD`, exit 0. No `--project-dir` flag — wrap invocation in `cd`.
- `packaging/install/install-claude-code.sh` | `install-codex.sh` | `install-cursor.sh` (P06):
  - Key API: `--project-dir PATH --dry-run --force --verbose`; stdout includes `skills_installed=<N>` and a `SUMMARY:` line; exit codes 0 success, 1 generic, 2 unsafe env, 3 unavailable.
  - HOME guard on claude-code/codex refuses empty or `/` HOME (matches init's own guard — we check first, installer re-checks).

## Constraints

- Bash 3.2 only — no `declare -A`, no `mapfile`, no `${var,,}`.
- No python, no jq. YAML config is written with `cat <<EOF` (simple, not merged).
- Init must NOT re-implement detection or registration — every detection/registration step delegates.
- `--dry-run` must cause zero writes and exit 0 with `SUMMARY:` line.
- When existing config detected without `--force`, delegate to reinit-handler (exit with reinit's exit code).
- All tests hermetic: every verification script uses `mktemp -d` for HOME and project-dir.
- Placeholder substitution uses sed with `|` delimiter — values must not contain `|` (controlled detectors never emit it).
- `eval` is used only to pass controlled flag strings built from script-internal state, never user input. Document this in a script comment.

## Expected Output

- `scripts/lifecycle/init-project.sh` (80+ lines, contains `--dry-run`, mode 0755)
- `scripts/verify/m008-p07-init-interface.sh` (mode 0755)
- `scripts/verify/m008-p07-init-dry-run-hermetic.sh` (mode 0755)
- `scripts/verify/m008-p07-init-e2e-hermetic.sh` (mode 0755)
- `scripts/verify/m008-p07-instruction-file-routing.sh` (mode 0755)
