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
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --project-root) PROJECT_ROOT="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    *) echo "check-permissions.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

. "$PROJECT_ROOT/scripts/lib/errors.sh"
. "$PROJECT_ROOT/scripts/lib/events.sh"

[ -z "$TARGET" ] && TARGET="$PROJECT_ROOT/.claude/settings.json"

# --- Handle missing target ---
if [ ! -f "$TARGET" ]; then
  printf 'DOCTOR:PERMISSIONS status=missing gaps=0 stale=0\n'
  if [ "$QUIET" -eq 0 ]; then
    echo "Target $TARGET does not exist. Run generate-permissions.sh | write-permissions.sh"
  fi
  emit_result ok "" "target missing" >&2
  exit 2
fi

# --- Run the generator, capture its output ---
EXPECTED="$(mktemp -t p07-expected.XXXXXX)"
trap 'rm -f "$EXPECTED"' EXIT
if ! bash "$PROJECT_ROOT/scripts/lifecycle/generate-permissions.sh" --project-root "$PROJECT_ROOT" > "$EXPECTED" 2>/dev/null; then
  emit_result error DISPATCH "generate-permissions.sh failed" >&2
  exit 1
fi

# --- Extract allow/deny from both files ---
# AD-18: _generated_at is metadata only — NOT a drift signal. We compare
# only the allow and deny arrays, plus defaultMode. _generated_at,
# _generated_by, and _autonomy_mode are excluded from comparison.
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
done <<ALLOW_EOF
$EXPECTED_ALLOW
ALLOW_EOF

# --- Count stale: patterns in current-allow that reference deleted scripts ---
# "Stale" means the pattern refers to scripts/<something>.sh but that
# script no longer exists. This is the only class of stale we detect in
# v0.1 -- other forms of stale (removed package.json scripts, removed
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
done <<STALE_EOF
$CURRENT_ALLOW
STALE_EOF

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
done <<DENY_EOF
$EXPECTED_DENY
DENY_EOF

# --- Emit structured result (AD-12: ok|drift|missing closed enum) ---
if [ "$gaps" -eq 0 ] && [ "$stale" -eq 0 ]; then
  status=ok
else
  status=drift
fi

printf 'DOCTOR:PERMISSIONS status=%s gaps=%d stale=%d\n' "$status" "$gaps" "$stale"
if [ "$QUIET" -eq 0 ]; then
  if [ "$gaps" -gt 0 ] || [ "$stale" -gt 0 ]; then
    printf '%s' "$missing_entries"
    printf '%s' "$stale_entries"
  fi
fi

emit_result ok "" "drift check: status=$status gaps=$gaps stale=$stale" >&2

if [ "$status" = "drift" ]; then
  exit 1
fi
exit 0
