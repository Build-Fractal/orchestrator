---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P07"
milestone: "M005"
name: "Project introspector — generate-permissions.sh"
depends_on: ["T01"]
---

## Description

Implement `scripts/lifecycle/generate-permissions.sh` — a pure, read-only
bash function from project state → canonical JSON permissions object on
stdout. Also extend `scripts/dispatch/detect-capabilities.sh` to report
which agent host marker directories are present (needed by T03's writer to
decide which host format to emit).

The generator is the workhorse of P07. It replaces the manually-curated
`templates/claude-settings.json` with project-introspected output that
includes every script from `extension.yml` + every toolchain command a
project actually uses, while always keeping the AD-20 temp-directory and
AD-21 env-prefix baselines and never emitting `bypassPermissions` (AD-7) or
GSD patterns (AD-10).

The generator **has zero hardcoded policy**. Every deny pattern, every
baseline allow pattern, every introspection rule comes from
`templates/autonomy-defaults.yaml` (produced by T01). Tests swap the file
to change behavior; the script does not change.

Architectural decisions that constrain this task:
- **AD-7**  Never `bypassPermissions`. Only the closed enum
  `{default, acceptEdits}` is emitted as `defaultMode`.
- **AD-9**  Generator is read-only. No file writes. No directory creation.
  Stdout is the only output.
- **AD-10** No GSD patterns, no `.gsd/` introspection. Agent host detection
  list is `{claude_code, cursor, copilot}` only.
- **AD-11** Graceful per-source fallback. Each introspection source is
  wrapped in `if [ -f <marker> ]; then ...`. Missing sources contribute
  nothing and the script continues.
- **AD-14** Reads `templates/autonomy-defaults.yaml` via
  `scripts/lib/recipe-parser.sh`. Does NOT write its own YAML parser.
- **AD-16** Output shape is:
  ```json
  {
    "_generated_by": "speckit-orchestrator",
    "_generated_at": "<ISO-8601>",
    "_autonomy_mode": "<minimal|standard|full>",
    "permissions": {
      "defaultMode": "<default|acceptEdits>",
      "allow": ["..."],
      "deny": ["..."]
    }
  }
  ```

## Steps

### Step 1 — Extend `scripts/dispatch/detect-capabilities.sh`

Add agent host marker detection. Do NOT detect `.gsd/` per AD-10. Insert
after the existing `runtime="local"` block and before the output section:

```bash
# Agent host marker directories — which host format the writer should emit.
# Per AD-10, .gsd/ is intentionally NOT detected.
host_claude_code=false
host_cursor=false
host_copilot=false
if [[ -d .claude ]]; then
  host_claude_code=true
fi
if [[ -d .cursor ]]; then
  host_cursor=true
fi
if [[ -d .github/copilot ]]; then
  host_copilot=true
fi
```

Then add the three keys to the text and JSON output sections. In text mode
append after the existing echo lines:

```bash
echo "host_claude_code=$host_claude_code"
echo "host_cursor=$host_cursor"
echo "host_copilot=$host_copilot"
```

And in JSON mode, add three keys inside the existing `cat <<EOF { ... } EOF`
block.

The test for this change is trivial — run `bash scripts/dispatch/detect-capabilities.sh`
from the project root and confirm `host_claude_code=true` appears in the
output (this repo has a `.claude/` directory).

### Step 2 — Create `scripts/lifecycle/generate-permissions.sh`

Interface specification:

```
Usage: generate-permissions.sh [--tier A|B|C] [--defaults <path>] [--project-root <path>]

  --tier           Override the tier (default: read from M###-EVALUATION.md,
                   or fall back to Tier C if not found).
  --defaults       Path to autonomy-defaults.yaml (default:
                   templates/autonomy-defaults.yaml relative to project root).
  --project-root   Directory to introspect (default: current working directory).

Exit codes:
  0  stdout contains a complete canonical JSON envelope
  1  unrecoverable error (defaults file missing; taxonomy violation)

Stdout: the AD-16 canonical envelope, pretty-printed with 2-space indent,
        deterministic key ordering (see Determinism below).
Stderr: EVENT: lines for each introspection source and a final RESULT: line.
```

Structural skeleton (agent must fill in the introspection functions —
these are the non-obvious bits):

```bash
#!/usr/bin/env bash
# scripts/lifecycle/generate-permissions.sh — Project-introspected autonomy permission generator.
#
# Reads templates/autonomy-defaults.yaml + project state, emits canonical
# JSON permissions envelope to stdout. AD-7, AD-9, AD-10, AD-11, AD-14, AD-16.
#
# Bash 3.2 compatible (NFR-200). No jq required. Idempotent: same project
# state → byte-identical stdout.

set -eu

# Resolve project root (default: current directory)
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
DEFAULTS_FILE=""
TIER=""

while [ $# -gt 0 ]; do
  case "$1" in
    --project-root) PROJECT_ROOT="$2"; shift 2 ;;
    --defaults) DEFAULTS_FILE="$2"; shift 2 ;;
    --tier) TIER="$2"; shift 2 ;;
    *) echo "generate-permissions.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

# Source shared libraries (from M004 P02, per AD-14 prerequisites)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$PROJECT_ROOT/scripts/lib"
. "$LIB_DIR/errors.sh"
. "$LIB_DIR/events.sh"
. "$LIB_DIR/recipe-parser.sh"

# Default defaults file
[ -z "$DEFAULTS_FILE" ] && DEFAULTS_FILE="$PROJECT_ROOT/templates/autonomy-defaults.yaml"

if [ ! -f "$DEFAULTS_FILE" ]; then
  emit_result error CONFIG "autonomy-defaults.yaml not found at $DEFAULTS_FILE" >&2
  exit 1
fi

# --- Tier resolution ---
# If not provided, scan milestones/*/M###-EVALUATION.md for `tier:` field.
# Fall back to C (most permissive baseline, matches current template).
resolve_tier() {
  if [ -n "$TIER" ]; then
    echo "$TIER"
    return 0
  fi
  local eval_file
  for eval_file in "$PROJECT_ROOT"/.specify/orchestrator/milestones/*/M*-EVALUATION.md; do
    [ -f "$eval_file" ] || continue
    local t
    t="$(sed -n 's/^tier:[[:space:]]*"\{0,1\}\([ABC]\)"\{0,1\}.*/\1/p' "$eval_file" | head -1)"
    if [ -n "$t" ]; then
      echo "$t"
      return 0
    fi
  done
  echo "C"
}
TIER_RESOLVED="$(resolve_tier)"

# --- Autonomy mode resolution ---
# tier_defaults.<TIER> from autonomy-defaults.yaml (AD-14).
AUTONOMY_MODE="$(read_recipe_field "$DEFAULTS_FILE" "tier_defaults.$TIER_RESOLVED")"
[ -z "$AUTONOMY_MODE" ] && AUTONOMY_MODE="full"

# --- Default mode resolution ---
DEFAULT_MODE="$(read_recipe_field "$DEFAULTS_FILE" "default_mode.$AUTONOMY_MODE")"
[ -z "$DEFAULT_MODE" ] && DEFAULT_MODE="acceptEdits"

# AD-7 guard: never bypassPermissions
case "$DEFAULT_MODE" in
  default|acceptEdits) ;;
  *)
    emit_result error CONFIG "invalid defaultMode '$DEFAULT_MODE' (AD-7 violation)" >&2
    exit 1
    ;;
esac

emit_event SESSION_START run_id="${ORCH_RUN_ID:-gen-$(date +%s)}" tier="$TIER_RESOLVED" mode="$AUTONOMY_MODE" >&2

# --- Read baseline allow/deny from YAML ---
# Parser does not yet support array extraction; we read the file directly
# for the baseline_allow and baseline_deny blocks. Each entry is a
# dash-prefixed quoted string at 2-space indent.
read_yaml_array() {
  local file="$1"
  local key="$2"
  local in_block=0
  while IFS= read -r line; do
    # Enter block
    if printf '%s' "$line" | grep -qE "^${key}:[[:space:]]*$"; then
      in_block=1
      continue
    fi
    if [ "$in_block" -eq 1 ]; then
      case "$line" in
        '  - '*)
          # Extract quoted value: '  - "Bash(...)"'
          printf '%s\n' "$line" | sed 's/^  - "\(.*\)"$/\1/'
          ;;
        '#'*|'')
          : ;;
        *)
          # Left the block
          in_block=0
          ;;
      esac
    fi
  done < "$file"
}

BASELINE_DENY="$(read_yaml_array "$DEFAULTS_FILE" "baseline_deny")"
BASELINE_ALLOW="$(read_yaml_array "$DEFAULTS_FILE" "baseline_allow")"

# --- Introspection sources ---
# Each function prints one or more allow-pattern strings to stdout (one per
# line). Missing sources print nothing. Per AD-11, any source that errors is
# skipped with an EVENT on stderr.

introspect_extension_yml() {
  local f="$PROJECT_ROOT/extension.yml"
  [ -f "$f" ] || { emit_event SAFETY_WARNING source=extension.yml reason=missing >&2; return 0; }
  # Already covered by baseline Bash(bash scripts/*) — emit nothing new.
  emit_event SESSION_START source=extension.yml entries=covered_by_baseline >&2
}

introspect_package_json() {
  local f="$PROJECT_ROOT/package.json"
  [ -f "$f" ] || return 0
  local count=0
  # Emit toolchain base patterns if package.json exists
  printf 'Bash(npm *)\n'
  printf 'Bash(npx *)\n'
  printf 'Bash(yarn *)\n'
  printf 'Bash(pnpm *)\n'
  printf 'Bash(bun *)\n'
  count=$((count + 5))
  # Extract script keys and emit Bash(npm run <key>) per FR-2
  # Scripts block in package.json: "scripts": { "build": "...", "test": "..." }
  # Parse the scripts block without jq: find the "scripts" key and extract
  # quoted keys between the following { and its matching }.
  awk '
    /"scripts"[[:space:]]*:[[:space:]]*\{/ { in_scripts = 1; next }
    in_scripts && /^[[:space:]]*\}/ { in_scripts = 0; next }
    in_scripts && /^[[:space:]]*"[^"]+"[[:space:]]*:/ {
      match($0, /"[^"]+"/)
      key = substr($0, RSTART+1, RLENGTH-2)
      printf "Bash(npm run %s)\n", key
      printf "Bash(yarn %s)\n", key
      printf "Bash(pnpm %s)\n", key
    }
  ' "$f"
  emit_event SESSION_START source=package.json scripts=discovered >&2
}

introspect_makefile() {
  local f="$PROJECT_ROOT/Makefile"
  [ -f "$f" ] || return 0
  printf 'Bash(make *)\n'
  # Extract target names: lines matching ^<name>:$ (not tab-indented)
  awk '
    /^[a-zA-Z_][a-zA-Z0-9_\-]*:([[:space:]]|$)/ {
      sub(/:.*/, "")
      printf "Bash(make %s)\n", $0
    }
  ' "$f"
  emit_event SESSION_START source=Makefile targets=discovered >&2
}

introspect_toolchains() {
  # TypeScript / JS — tsconfig.json present
  [ -f "$PROJECT_ROOT/tsconfig.json" ] && {
    printf 'Bash(tsc *)\n'
    printf 'Bash(tsc)\n'
    printf 'Bash(eslint *)\n'
    printf 'Bash(prettier *)\n'
    printf 'Bash(jest *)\n'
    printf 'Bash(vitest *)\n'
  }
  # Rust — Cargo.toml
  [ -f "$PROJECT_ROOT/Cargo.toml" ] && {
    printf 'Bash(cargo *)\n'
    printf 'Bash(rustc *)\n'
    printf 'Bash(rustup *)\n'
  }
  # Go — go.mod
  [ -f "$PROJECT_ROOT/go.mod" ] && {
    printf 'Bash(go *)\n'
    printf 'Bash(gofmt *)\n'
  }
  # Python — pyproject.toml or requirements.txt
  ([ -f "$PROJECT_ROOT/pyproject.toml" ] || [ -f "$PROJECT_ROOT/requirements.txt" ]) && {
    printf 'Bash(python *)\n'
    printf 'Bash(python3 *)\n'
    printf 'Bash(pip *)\n'
    printf 'Bash(pytest *)\n'
    printf 'Bash(mypy *)\n'
    printf 'Bash(ruff *)\n'
    printf 'Bash(black *)\n'
    printf 'Bash(poetry *)\n'
    printf 'Bash(uv *)\n'
  }
  # Ruby — Gemfile
  [ -f "$PROJECT_ROOT/Gemfile" ] && {
    printf 'Bash(bundle *)\n'
    printf 'Bash(rake *)\n'
    printf 'Bash(ruby *)\n'
  }
  # Docker Compose
  ([ -f "$PROJECT_ROOT/docker-compose.yml" ] || [ -f "$PROJECT_ROOT/docker-compose.yaml" ]) && {
    printf 'Bash(docker *)\n'
    printf 'Bash(docker-compose *)\n'
    printf 'Bash(docker compose *)\n'
  }
  # Supabase
  [ -f "$PROJECT_ROOT/supabase/config.toml" ] && {
    printf 'Bash(supabase *)\n'
  }
  emit_event SESSION_START source=toolchains scanned=complete >&2
}

# --- Collect all patterns ---
TMP_ALLOW="$(mktemp -t p07-allow.XXXXXX)"
TMP_DENY="$(mktemp -t p07-deny.XXXXXX)"
trap 'rm -f "$TMP_ALLOW" "$TMP_DENY"' EXIT

# Baseline first
printf '%s\n' "$BASELINE_ALLOW" > "$TMP_ALLOW"
printf '%s\n' "$BASELINE_DENY" > "$TMP_DENY"

# Introspection appends
introspect_extension_yml >> "$TMP_ALLOW"
introspect_package_json  >> "$TMP_ALLOW"
introspect_makefile      >> "$TMP_ALLOW"
introspect_toolchains    >> "$TMP_ALLOW"

# Deduplicate while preserving first-seen order (for determinism).
# Bash 3.2 compatible: use awk '!seen[$0]++'.
ALLOW_SORTED="$(awk '!seen[$0]++' "$TMP_ALLOW" | sed '/^$/d')"
DENY_SORTED="$(awk '!seen[$0]++' "$TMP_DENY" | sed '/^$/d')"

# --- AD-10 guard: refuse to emit GSD patterns ---
if printf '%s\n' "$ALLOW_SORTED" | grep -q "Skill(gsd"; then
  emit_result error CONFIG "AD-10 violation: Skill(gsd) pattern leaked into allow list" >&2
  exit 1
fi

# --- Emit canonical JSON envelope (AD-16) ---
GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '{\n'
printf '  "_generated_by": "speckit-orchestrator",\n'
printf '  "_generated_at": "%s",\n' "$GENERATED_AT"
printf '  "_autonomy_mode": "%s",\n' "$AUTONOMY_MODE"
printf '  "permissions": {\n'
printf '    "defaultMode": "%s",\n' "$DEFAULT_MODE"
printf '    "deny": [\n'
first=1
printf '%s\n' "$DENY_SORTED" | while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  if [ $first -eq 1 ]; then
    printf '      "%s"' "$entry"
    first=0
  else
    printf ',\n      "%s"' "$entry"
  fi
done
printf '\n    ],\n'
printf '    "allow": [\n'
first=1
printf '%s\n' "$ALLOW_SORTED" | while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  if [ $first -eq 1 ]; then
    printf '      "%s"' "$entry"
    first=0
  else
    printf ',\n      "%s"' "$entry"
  fi
done
printf '\n    ]\n'
printf '  }\n'
printf '}\n'

emit_result ok "" "generated permissions for tier=$TIER_RESOLVED mode=$AUTONOMY_MODE" >&2
```

**Determinism note**: the `first=1 / printf` pattern inside a `while read`
subshell does NOT actually carry `$first` back out of the loop in Bash 3.2
— the `|` creates a subshell. Use an explicit counter file or a plain
for-loop over the deduped list. Both approaches are correct; pick whichever
you verify works on macOS `/bin/bash` (version 3.2). A working pattern:

```bash
emit_json_array() {
  local list="$1"
  local indent="$2"
  local n=0
  local entry
  printf '%s' "$list" | while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    n=$((n + 1))
    if [ $n -eq 1 ]; then
      printf '%s"%s"' "$indent" "$entry"
    else
      printf ',\n%s"%s"' "$indent" "$entry"
    fi
  done
}
```

Note: even this pattern has the subshell issue. The **reliable** Bash 3.2
idiom is:

```bash
emit_json_array() {
  local list="$1"
  local indent="$2"
  local sep=""
  local entry
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    printf '%s%s"%s"' "$sep" "$indent" "$entry"
    sep=",\n"
  done <<EOF
$list
EOF
}
```

Here-docs are inherited by the current shell, not a subshell, so `sep`
mutation survives. Verify by running the generator twice and diffing:

```bash
bash scripts/lifecycle/generate-permissions.sh > /tmp/out1.json
bash scripts/lifecycle/generate-permissions.sh > /tmp/out2.json
diff /tmp/out1.json /tmp/out2.json
```

The only expected delta is `_generated_at`. If anything else differs, the
output is non-deterministic and must be fixed before T03 can compare
states.

### Step 3 — Make executable and smoke test

```bash
chmod +x scripts/lifecycle/generate-permissions.sh
bash scripts/lifecycle/generate-permissions.sh --tier C
```

Expected: a JSON envelope on stdout with `_generated_by`, `_autonomy_mode:
full`, `defaultMode: acceptEdits`, `allow` containing `/tmp/`, `ORCH_*=*`,
and `bash scripts/*` patterns; `deny` containing `rm -rf /` and
`git push --force *`. Stderr contains EVENT: lines and a final RESULT: line.

## Must-Haves

This task addresses the following phase must-haves:

- **Truths**: "Generator reads autonomy-defaults.yaml via the shared YAML
  parser", "Generator emits the canonical permissions envelope",
  "Generator output includes allow/deny under a permissions block",
  "Generator does NOT emit `Skill(gsd:*)`", "Generator does NOT emit
  `bypassPermissions`", "Generator is resilient: per-source fallback".
- **Artifacts**: `scripts/lifecycle/generate-permissions.sh`.
- **Key Links**:
  - `scripts/lifecycle/generate-permissions.sh` → `templates/autonomy-defaults.yaml`
  - `scripts/lifecycle/generate-permissions.sh` → `scripts/lib/recipe-parser.sh`
  - `scripts/lifecycle/generate-permissions.sh` → `scripts/lib/errors.sh`

## Verification

```bash
# Generator exists and is executable
test -x scripts/lifecycle/generate-permissions.sh

# Generator runs against this repo (always available since this is the repo)
bash scripts/lifecycle/generate-permissions.sh --tier C > /tmp/p07-out.json
test -s /tmp/p07-out.json

# Canonical envelope markers
grep -q '"_generated_by": "speckit-orchestrator"' /tmp/p07-out.json
grep -q '"_autonomy_mode": "full"' /tmp/p07-out.json
grep -q '"defaultMode":' /tmp/p07-out.json
grep -q '"allow":' /tmp/p07-out.json
grep -q '"deny":' /tmp/p07-out.json

# AD-20 baseline temp patterns present
grep -q '/tmp/' /tmp/p07-out.json
grep -q '/var/folders' /tmp/p07-out.json

# AD-21 env-prefix patterns present
grep -q 'ORCH_\*=\* bash scripts' /tmp/p07-out.json

# AD-10: no GSD patterns
bash scripts/verify/p07-no-gsd.sh

# AD-7: no bypass
bash scripts/verify/p07-no-bypass.sh

# Idempotency — two runs produce identical output except for _generated_at
bash scripts/lifecycle/generate-permissions.sh --tier C > /tmp/p07-a.json
bash scripts/lifecycle/generate-permissions.sh --tier C > /tmp/p07-b.json
diff <(grep -v _generated_at /tmp/p07-a.json) <(grep -v _generated_at /tmp/p07-b.json)
# Expected: no output. If diff shows anything, the generator is non-deterministic.

# Phase must-have verification for T02-scoped items
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M005/phases/P07
```

**Important re: AD-19**: each verification command above is a single
invocation. The `diff <(...)` line uses process substitution which **can**
trip the harness heuristic — if it does when you run it manually, fall
back to two separate `grep -v` writes to temp files and a plain `diff
/tmp/a /tmp/b`. The generator's *own* correctness does not depend on this
specific shape; it's just one way to verify determinism.

### Files Touched By This Task

- `scripts/lifecycle/generate-permissions.sh` (create)
- `scripts/dispatch/detect-capabilities.sh` (modify — add host_claude_code,
  host_cursor, host_copilot fields per AD-10)

## Inputs

### From Previous Tasks

- `templates/autonomy-defaults.yaml` (from T01)
  - Consumed via `scripts/lib/recipe-parser.sh`:
    - `read_recipe_field <file> "tier_defaults.A"` → `"minimal"`
    - `read_recipe_field <file> "tier_defaults.B"` → `"standard"`
    - `read_recipe_field <file> "tier_defaults.C"` → `"full"`
    - `read_recipe_field <file> "default_mode.minimal"` → `"default"`
    - `read_recipe_field <file> "default_mode.standard"` → `"acceptEdits"`
    - `read_recipe_field <file> "default_mode.full"` → `"acceptEdits"`
  - `baseline_deny` and `baseline_allow` arrays are read directly via the
    `read_yaml_array` helper defined in Step 2 (the recipe parser does not
    yet expose array extraction).
- `extension.yml` (registered scripts from T01) — the generator does not
  need to parse this file because the baseline already includes
  `Bash(bash scripts/*)` which covers every entry under `provides.scripts`.
  An `introspect_extension_yml` function exists only to emit an EVENT for
  observability.

### From Disk (Pre-existing)

- `scripts/lib/errors.sh` — `emit_result <ok|error> <kind> <detail>`. Used
  on every exit path. Writes a `RESULT:{"status":"...","error_kind":"...","detail":"..."}`
  line to stdout (or stderr when emitting after the JSON envelope). Kinds:
  `CONFIG`, `STATE`, `DISPATCH`, `VERIFY`, `BUDGET`, `IO`.
- `scripts/lib/events.sh` — `emit_event <TYPE> key=val ...`. Types used:
  `SESSION_START`, `SAFETY_WARNING`. Events go to stderr so they do not
  pollute the JSON stdout.
- `scripts/lib/recipe-parser.sh` — `read_recipe_field <file> <dotted.path>`.
  2-level paths (e.g., `tier_defaults.C`) use `_read_nested_field_2`. Path
  must match key structure exactly. Returns 1 if not found; caller should
  fall back.
- `scripts/dispatch/detect-capabilities.sh` — after Step 1, will include
  `host_claude_code=true|false` etc. in its text output. Not directly used
  by the generator (the generator always emits the canonical format);
  T03's writer uses this output to pick which host file to write.

## Expected Output

After completing this task:

1. `scripts/lifecycle/generate-permissions.sh` exists, is chmod +x, sources
   errors.sh/events.sh/recipe-parser.sh, and contains no hardcoded deny or
   allow patterns (every pattern originates from
   `templates/autonomy-defaults.yaml`).
2. `scripts/dispatch/detect-capabilities.sh` reports
   `host_claude_code=true` when `.claude/` exists, matching the current
   working tree.
3. `bash scripts/lifecycle/generate-permissions.sh --tier C > /tmp/out.json`
   produces a valid AD-16 canonical envelope whose `_autonomy_mode` matches
   the tier default (`full` for C).
4. Running the generator twice and comparing outputs (minus
   `_generated_at`) shows zero differences.
5. `bash scripts/verify/p07-no-gsd.sh` passes.
6. `bash scripts/verify/p07-no-bypass.sh` passes.
7. Tier 1 must-have verification: running
   `bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M005/phases/P07`
   shows PASS lines for every T01+T02 Truth/Artifact/Key Link. Items owned
   by T03/T04/T05 still FAIL until those tasks run.
