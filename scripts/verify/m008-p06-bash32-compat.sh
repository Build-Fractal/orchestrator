#!/usr/bin/env bash
# Verifies all P06 shell scripts are Bash 3.2 compatible.
# macOS ships Bash 3.2; the orchestrator targets this baseline (MEM001).
#
# Pattern mirrors scripts/verify/m008-p05-bash32-compat.sh — comment-aware
# scan (grep -vE '^[[:space:]]*#') so documented mentions of forbidden
# constructs do not trigger false positives (P05 lesson, MEM004).
#
# Forbidden constructs (Bash 4+):
#   declare -A          associative arrays
#   mapfile / readarray builtins
#   ${var,,}            lowercase expansion
#   ${var^^}            uppercase expansion
#   |&                  shorthand for 2>&1 |
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Target files — authored under P06. Listed one-per-line in FILES; the loop
# below iterates word-splits so blank entries are skipped naturally.
FILES="
$REPO_ROOT/packaging/skills/generate-skills.sh
$REPO_ROOT/packaging/bundle/build-bundle.sh
$REPO_ROOT/packaging/install/install-claude-code.sh
$REPO_ROOT/packaging/install/install-codex.sh
$REPO_ROOT/packaging/install/install-cursor.sh
$REPO_ROOT/scripts/lifecycle/check-update.sh
"

# Also include every scripts/verify/m008-p06-*.sh (includes this scanner and
# the e2e script). Glob expansion is safe: missing matches are filtered by
# the [ -f "$f" ] guard below.
for g in "$REPO_ROOT/scripts/verify/m008-p06-"*.sh; do
  FILES="$FILES
$g"
done

# Also include the scripts/packaging/generate-skills.sh that the forwarder
# at packaging/skills/generate-skills.sh execs into — authored under P06.
if [ -f "$REPO_ROOT/scripts/packaging/generate-skills.sh" ]; then
  FILES="$FILES
$REPO_ROOT/scripts/packaging/generate-skills.sh"
fi

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

  # Forbidden: lowercase/uppercase parameter expansion (Bash 4+)
  if grep -qE '\$\{[a-zA-Z_][a-zA-Z_0-9]*,,\}' "$stripped_tmp"; then
    echo "FAIL: $f uses forbidden bash 4+ construct: lowercase parameter expansion" >&2
    FAIL=1
  fi

  if grep -qE '\$\{[a-zA-Z_][a-zA-Z_0-9]*\^\^\}' "$stripped_tmp"; then
    echo "FAIL: $f uses forbidden bash 4+ construct: uppercase parameter expansion" >&2
    FAIL=1
  fi

  # Forbidden: pipe-stderr shorthand (Bash 4+ shortcut for 2>&1 followed
  # by a pipe). We build the pattern from fragments so the literal two-char
  # sequence never appears verbatim on a non-comment line in this scanner.
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
  echo "FAIL: no P06 shell scripts found to scan" >&2
  exit 1
fi

if [ $FAIL -eq 0 ]; then
  echo "PASS: all P06 shell scripts bash 3.2 compatible"
  exit 0
fi

exit 1
