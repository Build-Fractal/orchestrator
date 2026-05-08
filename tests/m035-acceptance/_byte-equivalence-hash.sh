#!/usr/bin/env bash
# tests/m035-acceptance/_byte-equivalence-hash.sh
# Helper: hash STAGED dir applying EXCLUSION_LIST regex globs.
# Inputs (env): STAGED=<dir>, EXCLUSION_LIST=<newline-sep paths>
# Output (stdout): SHA-256 hex digest (single line, no trailing newline)
#
# Bash 3.2 compatible.

set -u

if [ -z "${STAGED:-}" ]; then
  echo "FAIL: STAGED env var empty" >&2
  exit 1
fi
if [ ! -d "$STAGED" ]; then
  echo "FAIL: STAGED dir not found: $STAGED" >&2
  exit 1
fi

# Build a grep -vE exclusion regex. Each line of EXCLUSION_LIST
# becomes an alternation. Treat trailing slash as directory match
# (matched as a path-prefix). Anchor at start-of-relative-path
# inside the calling test (we emit ^\./(<alt>) form there).
EXCL_RE=""
while IFS= read -r p; do
  [ -z "$p" ] && continue
  # Escape regex metacharacters in path. Note: forward-slash does
  # not need escaping in grep -E, but . [ ] ^ $ * + ? ( ) { } | \ do.
  esc="$(printf '%s' "$p" | sed -E 's/[][.^$*+?(){}|\\]/\\&/g')"
  if [ -z "$EXCL_RE" ]; then
    EXCL_RE="$esc"
  else
    EXCL_RE="$EXCL_RE|$esc"
  fi
done <<EOF_EXCL
${EXCLUSION_LIST:-}
EOF_EXCL

# Defensive: if EXCL_RE is empty, match nothing (empty alternation
# would otherwise match every line).
if [ -z "$EXCL_RE" ]; then
  EXCL_RE='__never_matches_anything__'
fi

# Find all files relative to STAGED, sort for determinism, exclude
# the EXCL_RE patterns, hash each file's content + path, then
# combine. Hash output is content-hash + relpath; the outer shasum
# folds the per-file lines into a single digest.
( cd "$STAGED" && find . -type f -print | LC_ALL=C sort ) \
  | grep -vE "^\./($EXCL_RE)" \
  | while IFS= read -r relpath; do
      shasum -a 256 "$STAGED/$relpath" | awk -v p="$relpath" '{print $1, p}'
    done \
  | shasum -a 256 \
  | awk '{print $1}'
