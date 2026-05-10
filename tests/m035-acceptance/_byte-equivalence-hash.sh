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

# Stage exclusion paths into a tmp file. Each non-empty line of
# EXCLUSION_LIST is treated as a literal path-prefix relative to
# STAGED. Trailing-slash semantics fall out of literal prefix match
# (e.g. `tests/` matches `tests/foo.sh`).
#
# Note (papercut-sweep-post-M035 PC-3): the previous form used a
# `sed -E 's/[][.^$*+?(){}|\\]/\\&/g'` regex-escape pass to build a
# grep -vE alternation, which BSD sed on macOS rejected with
# "unbalanced brackets" -- the EXCLUSION_LIST mechanism silently
# no-op'd locally. Rewritten as literal prefix matching via awk's
# index() to remove the regex-escape requirement entirely.
EXCL_FILE="$(mktemp)"
printf '%s\n' "${EXCLUSION_LIST:-}" > "$EXCL_FILE"

# Find all files relative to STAGED, sort for determinism, exclude
# any path that starts (after stripping leading `./`) with one of
# the EXCLUSION_LIST entries. Hash each file's content + path, then
# fold the per-file lines into a single digest.
( cd "$STAGED" && find . -type f -print | LC_ALL=C sort ) \
  | awk -v ef="$EXCL_FILE" '
      BEGIN {
        n = 0
        while ((getline line < ef) > 0) {
          if (length(line) > 0) excl[++n] = line
        }
        close(ef)
      }
      {
        rel = $0
        sub(/^\.\//, "", rel)
        for (i = 1; i <= n; i++) {
          if (index(rel, excl[i]) == 1) next
        }
        print $0
      }
    ' \
  | while IFS= read -r relpath; do
      shasum -a 256 "$STAGED/$relpath" | awk -v p="$relpath" '{print $1, p}'
    done \
  | shasum -a 256 \
  | awk '{print $1}'

rm -f "$EXCL_FILE"
