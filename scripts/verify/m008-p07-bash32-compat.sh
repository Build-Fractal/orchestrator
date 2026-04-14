#!/usr/bin/env bash
# scripts/verify/m008-p07-bash32-compat.sh
# Comment-aware Bash 3.2 compatibility scan for P07 shell scripts.
#
# Mirrors scripts/verify/m008-p06-bash32-compat.sh (P05/P06 pattern):
# strip whole-line comments before matching forbidden constructs so
# documented mentions of Bash 4+ features do not trigger false positives
# (MEM001, MEM004).
#
# Forbidden constructs (Bash 4+):
#   declare -A          associative arrays
#   mapfile / readarray builtins
#   ${var,,}            lowercase parameter expansion
#   ${var^^}            uppercase parameter expansion
#   |&                  pipe-stderr shorthand (shortcut for 2>&1 |)
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Target files — authored under P07. One per line; blank entries skip.
FILES="
$REPO_ROOT/scripts/lifecycle/detect-project.sh
$REPO_ROOT/scripts/lifecycle/init-project.sh
$REPO_ROOT/scripts/lifecycle/reinit-handler.sh
"

# Also include every scripts/verify/m008-p07-*.sh (includes this scanner and
# the e2e script). Glob expansion is safe: missing matches filter via [ -f ].
for g in "$REPO_ROOT/scripts/verify/m008-p07-"*.sh; do
  FILES="$FILES
$g"
done

FAIL=0
CHECKED=0

for f in $FILES; do
  [ -f "$f" ] || continue
  CHECKED=$(( CHECKED + 1 ))

  # Comment-aware scan: exclude lines whose first non-whitespace char is '#'
  # so documentation of forbidden constructs does not trip the scanner.
  # AD-19: capture grep output via a tmpfile, never `$(cmd | pipe)`.
  stripped_tmp="$(mktemp)"
  grep -vE '^[[:space:]]*#' "$f" > "$stripped_tmp" 2>/dev/null || true

  # Forbidden: declare -A (associative arrays, Bash 4+)
  if grep -qE '^[[:space:]]*declare[[:space:]]+-A' "$stripped_tmp"; then
    echo "FAIL: $f uses forbidden bash 4+ construct: declare -A" >&2
    FAIL=1
  fi

  # Forbidden: mapfile / readarray (Bash 4+)
  if grep -qE '^[[:space:]]*(mapfile|readarray)([[:space:]]|$)' "$stripped_tmp"; then
    echo "FAIL: $f uses forbidden bash 4+ construct: mapfile/readarray" >&2
    FAIL=1
  fi

  # Forbidden: lowercase parameter expansion (Bash 4+)
  if grep -qE '\$\{[a-zA-Z_][a-zA-Z_0-9]*,,\}' "$stripped_tmp"; then
    echo "FAIL: $f uses forbidden bash 4+ construct: lowercase parameter expansion" >&2
    FAIL=1
  fi

  # Forbidden: uppercase parameter expansion (Bash 4+)
  if grep -qE '\$\{[a-zA-Z_][a-zA-Z_0-9]*\^\^\}' "$stripped_tmp"; then
    echo "FAIL: $f uses forbidden bash 4+ construct: uppercase parameter expansion" >&2
    FAIL=1
  fi

  # Forbidden: pipe-stderr shorthand. Build pattern from fragments so the
  # literal two-char sequence never appears verbatim on a non-comment line
  # in this scanner itself.
  PIPE_CH='|'
  AMP_CH='&'
  PIPEAMP_PATTERN="[^${PIPE_CH}]\\${PIPE_CH}${AMP_CH}[^${PIPE_CH}]"
  if grep -qE "$PIPEAMP_PATTERN" "$stripped_tmp"; then
    echo "FAIL: $f uses forbidden bash 4+ construct: pipe-stderr shorthand" >&2
    FAIL=1
  fi

  rm -f "$stripped_tmp"
done

if [ "$CHECKED" -eq 0 ]; then
  echo "FAIL: no P07 shell scripts found to scan" >&2
  exit 1
fi

if [ $FAIL -eq 0 ]; then
  echo "PASS: all P07 shell scripts bash 3.2 compatible (checked=$CHECKED)"
  exit 0
fi

exit 1
