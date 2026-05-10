---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P07"
milestone: "M005"
name: "Agent-host writer + drift detector"
depends_on: ["T02"]
---

## Description

Implement the two scripts that sit on either side of T02's generator:

1. **`scripts/lifecycle/write-permissions.sh`** — takes a canonical JSON
   permissions envelope (stdin or `--input <file>`), detects the target
   agent host via `detect-capabilities.sh`, and writes the host-specific
   settings file (for Claude Code: `.claude/settings.json`). Implements the
   AD-13 additive-merge semantics when the target exists and is
   user-authored; does a preserving overwrite when the target is
   orchestrator-generated.

2. **`scripts/diagnostics/check-permissions.sh`** — runs the generator,
   compares its output against the current `.claude/settings.json`, and
   emits `DOCTOR:PERMISSIONS status=<ok|drift|missing> gaps=N stale=N` per
   AD-12. Consumed by P06's `run-doctor.sh` aggregation.

Architectural decisions that constrain this task:
- **AD-9**  Two-step design: generator is read-only; writer owns all disk
  writes. `check-permissions.sh` is read-only (calls the generator but does
  not persist anything).
- **AD-12** Drift severity is binary: `ok | drift | missing`. No
  intermediate warning tier. The doctor signal for auto mode pre-flight is
  unambiguous.
- **AD-13** Merge for user-authored targets is **additive only**:
  - `permissions.allow`: union with orchestrator-generated patterns,
    deduplicate. Never removes user entries.
  - `permissions.deny`: add missing baseline deny patterns if absent, but
    never remove user entries.
  - `defaultMode`: leave user's value untouched. Never overwrite.
  - `_generated_by` / `_generated_at` / `_autonomy_mode` markers: **not
    added to user-authored files** (adding would flip the file's status to
    orchestrator-generated on the next pre-flight and allow a future
    overwrite — that's a subtle regression AD-13 forbids).
- **AD-16** Canonical format is Claude-Code-shaped. The Claude Code writer
  is a passthrough — it parses the stdin envelope, strips the three
  underscore-prefixed top-level keys into the output file body alongside
  `permissions`, and writes. No field translation.
- **AD-18** `_generated_at` is metadata only, not a drift signal. The
  drift detector **excludes** `_generated_at` from comparison.

## Steps

### Step 1 — Create `scripts/lifecycle/write-permissions.sh`

Interface specification:

```
Usage: write-permissions.sh [--input <file>] [--host claude_code|cursor|copilot] [--project-root <path>]

  --input        Path to canonical JSON envelope. Default: read from stdin.
  --host         Target agent host. Default: auto-detect via detect-capabilities.sh.
  --project-root Directory to write into. Default: current working directory.

Exit codes:
  0  target file written (or already up-to-date — merge produced no changes)
  1  unrecoverable error (invalid input JSON, no detectable host, IO failure)

Stdout: one EVENT:WRITE line and a final RESULT: line.
```

Structural skeleton — agent must fill in the JSON parse/merge details.
Bash 3.2, no jq. The canonical envelope from T02 is already valid JSON
with predictable shape (AD-16); we can parse it with sed/awk by relying
on its layout rather than implementing a general parser.

```bash
#!/usr/bin/env bash
# scripts/lifecycle/write-permissions.sh — Agent-host translator for canonical permissions.
#
# AD-9 writer half. AD-13 additive merge for user-authored files. Reads the
# canonical JSON envelope (T02 generator output) and writes the host-specific
# settings file (Claude Code today; other hosts pluggable).
#
# Bash 3.2, no jq. Relies on canonical format being well-shaped (AD-16).
#
# CRITICAL: AD-13 additive merge only. Never remove user-authored entries.

set -eu

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
INPUT_FILE=""
HOST=""

while [ $# -gt 0 ]; do
  case "$1" in
    --input) INPUT_FILE="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --project-root) PROJECT_ROOT="$2"; shift 2 ;;
    *) echo "write-permissions.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

. "$PROJECT_ROOT/scripts/lib/errors.sh"
. "$PROJECT_ROOT/scripts/lib/events.sh"

# --- Read canonical input ---
if [ -z "$INPUT_FILE" ]; then
  INPUT_FILE="$(mktemp -t p07-input.XXXXXX)"
  cat > "$INPUT_FILE"
  trap 'rm -f "$INPUT_FILE"' EXIT
fi

if [ ! -s "$INPUT_FILE" ]; then
  emit_result error IO "input file is empty: $INPUT_FILE"
  exit 1
fi

# --- Host detection ---
if [ -z "$HOST" ]; then
  caps="$(bash "$PROJECT_ROOT/scripts/dispatch/detect-capabilities.sh" 2>/dev/null || true)"
  case "$caps" in
    *host_claude_code=true*) HOST="claude_code" ;;
    *host_cursor=true*) HOST="cursor" ;;
    *host_copilot=true*) HOST="copilot" ;;
    *) HOST="claude_code" ;;  # First-host default: Claude Code (AD-16)
  esac
fi

case "$HOST" in
  claude_code) TARGET="$PROJECT_ROOT/.claude/settings.json" ;;
  cursor) TARGET="$PROJECT_ROOT/.cursor/settings.json" ;;
  copilot) TARGET="$PROJECT_ROOT/.github/copilot/settings.json" ;;
  *)
    emit_result error CONFIG "unknown host: $HOST"
    exit 1
    ;;
esac

# Cursor and copilot hosts are pluggable stubs (per M005 scope: YAGNI until
# a user needs them). Ship them refusing to write with a clear message.
if [ "$HOST" != "claude_code" ]; then
  emit_result error DISPATCH "host '$HOST' is a pluggable stub — only claude_code ships in v0.1"
  exit 1
fi

mkdir -p "$(dirname "$TARGET")"

# --- Determine write mode: overwrite vs additive merge ---
# If target exists and contains the _generated_by marker → orchestrator-generated → overwrite.
# If target exists and does NOT contain the marker → user-authored → additive merge (AD-13).
# If target does not exist → fresh write.
MODE="fresh"
if [ -f "$TARGET" ]; then
  if grep -q '"_generated_by"[[:space:]]*:[[:space:]]*"speckit-orchestrator"' "$TARGET"; then
    MODE="overwrite"
  else
    MODE="merge"
  fi
fi

case "$MODE" in
  fresh|overwrite)
    # Claude Code's shape IS the canonical shape — passthrough.
    cp "$INPUT_FILE" "$TARGET"
    emit_event HOOK_COMPLETE script=write-permissions.sh mode="$MODE" host="$HOST" target="$TARGET"
    emit_result ok "" "wrote $TARGET in mode=$MODE"
    ;;
  merge)
    # AD-13: additive merge. Must preserve every entry already in $TARGET.
    # Extract user-authored allow/deny arrays using sed (AD-16 shape is
    # stable). Append any generator-produced pattern that isn't already
    # present. Leave defaultMode untouched. Do NOT add _generated_by markers.
    merge_additive "$INPUT_FILE" "$TARGET"
    emit_event HOOK_COMPLETE script=write-permissions.sh mode=merge host="$HOST" target="$TARGET"
    emit_result ok "" "merged into user-authored $TARGET (AD-13 additive only)"
    ;;
esac
```

**Additive merge function**: the non-trivial piece. Extract allow/deny
arrays from both files (the canonical envelope produced by T02 has a
fixed line-based layout, which lets us parse without a general JSON
parser):

```bash
merge_additive() {
  local new_file="$1"
  local current="$2"

  # Extract allow array entries from canonical envelope: lines inside
  # "allow": [ ... ] at 6-space indent.
  extract_array() {
    local file="$1"
    local key="$2"
    awk -v k="\"$key\":" '
      $0 ~ k "[[:space:]]*\\[" { in_block=1; next }
      in_block && /^[[:space:]]*\]/ { in_block=0; next }
      in_block && /^[[:space:]]*"[^"]*"/ {
        match($0, /"[^"]*"/)
        print substr($0, RSTART+1, RLENGTH-2)
      }
    ' "$file"
  }

  local new_allow new_deny cur_allow cur_deny
  new_allow="$(extract_array "$new_file" "allow")"
  new_deny="$(extract_array "$new_file" "deny")"
  cur_allow="$(extract_array "$current" "allow")"
  cur_deny="$(extract_array "$current" "deny")"

  # Append new entries that aren't already in the current set. Preserve
  # the current set's order (AD-13: never reorder user-authored entries).
  merged_allow="$cur_allow"
  merged_deny="$cur_deny"
  local pattern
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    printf '%s\n' "$cur_allow" | grep -Fxq "$pattern" || merged_allow="$(printf '%s\n%s' "$merged_allow" "$pattern")"
  done <<EOF
$new_allow
EOF
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    printf '%s\n' "$cur_deny" | grep -Fxq "$pattern" || merged_deny="$(printf '%s\n%s' "$merged_deny" "$pattern")"
  done <<EOF
$new_deny
EOF

  # Rewrite the target file with merged arrays. Preserve everything outside
  # the allow/deny blocks (including defaultMode, comments, markers).
  # Simplest approach: write a new file from scratch with the current
  # envelope's defaultMode and markers, but merged arrays.
  local tmp
  tmp="$(mktemp -t p07-merge.XXXXXX)"

  # Extract current defaultMode (leave untouched per AD-13)
  local cur_default_mode
  cur_default_mode="$(sed -n 's/.*"defaultMode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$current" | head -1)"
  [ -z "$cur_default_mode" ] && cur_default_mode="default"

  # AD-13: do NOT add _generated_by markers to user-authored files. Only
  # emit a stripped-down permissions object.
  printf '{\n' > "$tmp"
  printf '  "permissions": {\n' >> "$tmp"
  printf '    "defaultMode": "%s",\n' "$cur_default_mode" >> "$tmp"
  printf '    "deny": [\n' >> "$tmp"
  write_array "$merged_deny" "      " >> "$tmp"
  printf '\n    ],\n' >> "$tmp"
  printf '    "allow": [\n' >> "$tmp"
  write_array "$merged_allow" "      " >> "$tmp"
  printf '\n    ]\n' >> "$tmp"
  printf '  }\n' >> "$tmp"
  printf '}\n' >> "$tmp"

  mv "$tmp" "$current"
}

write_array() {
  local list="$1"
  local indent="$2"
  local sep=""
  local entry
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    printf '%s%s"%s"' "$sep" "$indent" "$entry"
    sep=$',\n'
  done <<EOF
$list
EOF
}
```

**Caveat about the merge**: this implementation replaces the entire
user-authored file's structure with a generator-shaped one that happens
to preserve defaultMode + allow + deny. Any *other* top-level fields the
user had (e.g., `hooks`, `mcpServers`, `statusLine`) would be **lost**.
Since this is v0.1 and the spec says only `permissions` is in scope, this
is acceptable but must be documented in a comment at the top of the merge
function:

```
# SCOPE: v0.1 merge only covers the permissions block. Other top-level
# Claude Code settings.json fields (hooks, mcpServers, statusLine) are
# NOT preserved by this merge. When merging into a user-authored file
# containing those fields, the writer fails safely (see Step 2 guard
# below) instead of silently dropping them.
```

And add a pre-merge guard:

```bash
# AD-13 safety: refuse to merge into files with top-level fields beyond
# permissions — we would silently destroy them otherwise.
if grep -qE '^\s*"(hooks|mcpServers|statusLine|statusLineConfig)"' "$current"; then
  emit_result error IO "user-authored $current contains unsupported top-level fields — refusing merge (v0.1 only handles 'permissions')"
  exit 1
fi
```

Place this guard **before** the `case "$MODE" in merge)` branch invokes
`merge_additive`.

### Step 2 — Create `scripts/diagnostics/check-permissions.sh`

Interface specification:

```
Usage: check-permissions.sh [--project-root <path>] [--target <path>]

  --project-root   Directory to check. Default: current working directory.
  --target         Path to settings file. Default: .claude/settings.json.

Exit codes:
  0  status=ok (no drift, no missing patterns, baseline deny intact)
  1  status=drift (gaps>0 or stale>0)
  2  status=missing (target file does not exist)

Stdout: exactly one line of the form:
  DOCTOR:PERMISSIONS status=<ok|drift|missing> gaps=<N> stale=<N>

  gaps   = patterns the generator would emit that are MISSING from the target
  stale  = patterns in the target's allow list that reference deleted scripts
           (generator wouldn't emit them either)

Also prints human-readable detail to stdout after the DOCTOR: line (one
line per gap/stale entry) unless --quiet is passed.
```

Implementation skeleton:

```bash
#!/usr/bin/env bash
# scripts/diagnostics/check-permissions.sh — Permission drift detector.
#
# AD-12: binary drift severity (ok | drift | missing).
# AD-18: _generated_at is metadata, NOT a drift signal. Excluded from
#         comparison.
# Consumed by scripts/diagnostics/run-doctor.sh (M005 P06 aggregation).

set -eu

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    --project-root) PROJECT_ROOT="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    *) echo "check-permissions.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

. "$PROJECT_ROOT/scripts/lib/errors.sh"
. "$PROJECT_ROOT/scripts/lib/events.sh"

[ -z "$TARGET" ] && TARGET="$PROJECT_ROOT/.claude/settings.json"

# --- Handle missing target ---
if [ ! -f "$TARGET" ]; then
  printf 'DOCTOR:PERMISSIONS status=missing gaps=0 stale=0\n'
  echo "Target $TARGET does not exist. Run generate-permissions.sh | write-permissions.sh"
  emit_result ok "" "target missing"
  exit 2
fi

# --- Run the generator, capture its output ---
EXPECTED="$(mktemp -t p07-expected.XXXXXX)"
trap 'rm -f "$EXPECTED"' EXIT
if ! bash "$PROJECT_ROOT/scripts/lifecycle/generate-permissions.sh" --project-root "$PROJECT_ROOT" > "$EXPECTED" 2>/dev/null; then
  emit_result error DISPATCH "generate-permissions.sh failed"
  exit 1
fi

# --- Extract allow/deny from both files ---
extract_array() {
  local file="$1"
  local key="$2"
  awk -v k="\"$key\":" '
    $0 ~ k "[[:space:]]*\\[" { in_block=1; next }
    in_block && /^[[:space:]]*\]/ { in_block=0; next }
    in_block && /^[[:space:]]*"[^"]*"/ {
      match($0, /"[^"]*"/)
      print substr($0, RSTART+1, RLENGTH-2)
    }
  ' "$file"
}

EXPECTED_ALLOW="$(extract_array "$EXPECTED" "allow")"
EXPECTED_DENY="$(extract_array "$EXPECTED" "deny")"
CURRENT_ALLOW="$(extract_array "$TARGET" "allow")"
CURRENT_DENY="$(extract_array "$TARGET" "deny")"

# --- Count gaps: patterns in expected that are missing from current ---
gaps=0
missing_entries=""
while IFS= read -r pattern; do
  [ -z "$pattern" ] && continue
  if ! printf '%s\n' "$CURRENT_ALLOW" | grep -Fxq "$pattern"; then
    gaps=$((gaps + 1))
    missing_entries="${missing_entries}  MISSING: $pattern
"
  fi
done <<EOF
$EXPECTED_ALLOW
EOF

# --- Count stale: patterns in current-allow that reference deleted scripts ---
# "Stale" means the pattern refers to scripts/<something>.sh but that
# script no longer exists. This is the only class of stale we detect in
# v0.1 — other forms of stale (removed package.json scripts, removed
# Makefile targets) are out of scope.
stale=0
stale_entries=""
while IFS= read -r pattern; do
  [ -z "$pattern" ] && continue
  # Look for script path references: Bash(bash scripts/<path>.sh)
  script_path="$(printf '%s' "$pattern" | sed -n 's/.*bash \(scripts\/[^ )]*\.sh\).*/\1/p')"
  if [ -n "$script_path" ] && [ ! -f "$PROJECT_ROOT/$script_path" ]; then
    stale=$((stale + 1))
    stale_entries="${stale_entries}  STALE: $pattern (references deleted $script_path)
"
  fi
done <<EOF
$CURRENT_ALLOW
EOF

# --- Baseline deny gaps ---
# Every entry in expected deny that is missing from current deny counts
# as a baseline-deny gap. This is additive to `gaps` so run-doctor.sh
# catches holes in the user-authored deny list.
while IFS= read -r pattern; do
  [ -z "$pattern" ] && continue
  if ! printf '%s\n' "$CURRENT_DENY" | grep -Fxq "$pattern"; then
    gaps=$((gaps + 1))
    missing_entries="${missing_entries}  MISSING DENY: $pattern
"
  fi
done <<EOF
$EXPECTED_DENY
EOF

# --- Emit structured result (AD-12: ok|drift|missing closed enum) ---
if [ "$gaps" -eq 0 ] && [ "$stale" -eq 0 ]; then
  status=ok
else
  status=drift
fi

printf 'DOCTOR:PERMISSIONS status=%s gaps=%d stale=%d\n' "$status" "$gaps" "$stale"
if [ "$gaps" -gt 0 ] || [ "$stale" -gt 0 ]; then
  printf '%s' "$missing_entries"
  printf '%s' "$stale_entries"
fi

emit_result ok "" "drift check: status=$status gaps=$gaps stale=$stale"

if [ "$status" = "drift" ]; then
  exit 1
fi
exit 0
```

### Step 3 — Make both executable and smoke-test

```bash
chmod +x scripts/lifecycle/write-permissions.sh
chmod +x scripts/diagnostics/check-permissions.sh

# Generate + write smoke test
bash scripts/lifecycle/generate-permissions.sh --tier C \
  | bash scripts/lifecycle/write-permissions.sh

# Drift check smoke test (after generate → write, drift should be zero)
bash scripts/diagnostics/check-permissions.sh
# Expected: DOCTOR:PERMISSIONS status=ok gaps=0 stale=0
```

**Important re: the smoke test pipe**: the `cmd1 | cmd2` shape above is a
simple two-command pipeline which is fine — the harness heuristic fires
on `$(...)` containing pipes, process substitution `<(...)`, and
compound `;`-chained statements. A plain pipe between two commands is
benign. Per AD-19, if a developer runs this interactively and the
heuristic fires anyway, fall back to staging via a tmp file:

```bash
bash scripts/lifecycle/generate-permissions.sh --tier C > /tmp/p07-canon.json
bash scripts/lifecycle/write-permissions.sh --input /tmp/p07-canon.json
```

**Safety note on smoke test**: running this against the current repo will
overwrite `.claude/settings.json` (the current file has the
`_generated_by` marker, so the writer classifies it as orchestrator-
generated and overwrites). That is expected and desired. Back up first
if you want to preserve the current exact bytes:

```bash
cp .claude/settings.json /tmp/p07-backup-settings.json
```

## Must-Haves

This task addresses:

- **Truths**: "Writer embeds `_generated_by`", "Writer respects
  user-authored files: merge is additive only, never removes",
  "Drift detector emits DOCTOR:PERMISSIONS...", "Drift detector status
  set is closed enum ok|drift|missing".
- **Artifacts**: `scripts/lifecycle/write-permissions.sh`,
  `scripts/diagnostics/check-permissions.sh`.
- **Key Links**:
  - `scripts/lifecycle/write-permissions.sh` → `scripts/lifecycle/generate-permissions.sh`
  - `scripts/diagnostics/check-permissions.sh` → `scripts/lifecycle/generate-permissions.sh`

## Verification

```bash
# Both scripts exist and are executable
test -x scripts/lifecycle/write-permissions.sh
test -x scripts/diagnostics/check-permissions.sh

# Writer has AD-13 additive-merge marker (verified by p07-merge-additive.sh)
bash scripts/verify/p07-merge-additive.sh

# Drift check emits the structured line against this repo
bash scripts/diagnostics/check-permissions.sh > /tmp/p07-doctor.out
grep -q '^DOCTOR:PERMISSIONS status=' /tmp/p07-doctor.out
grep -qE 'status=(ok|drift|missing)' /tmp/p07-doctor.out

# Idempotency — regenerate, rewrite, recheck → status=ok
bash scripts/lifecycle/generate-permissions.sh --tier C > /tmp/p07-canon.json
bash scripts/lifecycle/write-permissions.sh --input /tmp/p07-canon.json
bash scripts/diagnostics/check-permissions.sh > /tmp/p07-after.out
grep -q 'status=ok' /tmp/p07-after.out

# Phase must-haves
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M005/phases/P07
```

### Files Touched By This Task

- `scripts/lifecycle/write-permissions.sh` (create)
- `scripts/diagnostics/check-permissions.sh` (create)

## Inputs

### From Previous Tasks

- **T02 generator** (`scripts/lifecycle/generate-permissions.sh`):
  - **Invocation**: `bash scripts/lifecycle/generate-permissions.sh [--tier A|B|C] [--project-root <path>]`
  - **Stdout shape** (AD-16 canonical envelope):
    ```json
    {
      "_generated_by": "speckit-orchestrator",
      "_generated_at": "<ISO-8601>",
      "_autonomy_mode": "<minimal|standard|full>",
      "permissions": {
        "defaultMode": "<default|acceptEdits>",
        "deny": ["...", "..."],
        "allow": ["...", "..."]
      }
    }
    ```
  - **Determinism**: two runs with identical project state produce
    byte-identical stdout except for the `_generated_at` field.
  - **Stderr**: `EVENT:` lines and a final `RESULT:` line. Consumers MUST
    discard stderr when piping the canonical envelope.
- **T02's extension of `scripts/dispatch/detect-capabilities.sh`**:
  - Text output now includes `host_claude_code=<true|false>`,
    `host_cursor=<true|false>`, `host_copilot=<true|false>`. Used by the
    writer to pick which target file to write.

### From Disk (Pre-existing)

- `scripts/lib/errors.sh` — `emit_result <ok|error> <kind> <detail>`.
- `scripts/lib/events.sh` — `emit_event <TYPE> key=val ...`. Writer emits
  `HOOK_COMPLETE` (fits the canonical registry for write operations).
- `scripts/dispatch/detect-capabilities.sh` — host marker detection
  fields. Does NOT detect `.gsd/` per AD-10.

## Expected Output

After completing this task:

1. `scripts/lifecycle/write-permissions.sh` exists, sources errors.sh +
   events.sh, implements the AD-13 additive merge in a function named
   `merge_additive`, contains the word "additive" in a comment, and checks
   for the `_generated_by` marker to distinguish user-authored targets
   from orchestrator-generated ones.
2. `scripts/diagnostics/check-permissions.sh` exists and emits a single
   `DOCTOR:PERMISSIONS status=<ok|drift|missing> gaps=N stale=N` line on
   stdout.
3. The status enum is a closed set (ok|drift|missing) — no intermediate
   warning tier (AD-12).
4. `_generated_at` is not included in the drift comparison (AD-18).
5. Running the full pipeline against this repo —
   `generate-permissions.sh` → `write-permissions.sh` →
   `check-permissions.sh` — produces `status=ok gaps=0 stale=0`.
6. `bash scripts/verify/p07-merge-additive.sh` passes.
7. Tier 1 must-haves for T01+T02+T03 all pass; T04/T05 items still FAIL
   until those tasks run.
