#!/usr/bin/env bash
# tools/verify/papercut-byte-equivalence-hash-bsd.sh — papercut-sweep-post-M035 PC-3
#
# Asserts tests/m035-acceptance/_byte-equivalence-hash.sh's EXCLUSION_LIST
# mechanism actually filters paths on both BSD (macOS) and GNU (Linux) sed.
#
# Pre-fix: the helper used `sed -E 's/[][.^$*+?(){}|\\]/\\&/g'` which BSD sed
# rejects with "unbalanced brackets", silently turning EXCLUSION_LIST into a
# no-op. Tests passed by accident because both channels hashed the same
# unfiltered tree.
#
# This verifier stages two STAGED dirs that differ ONLY in an excluded path.
# Their hashes must equal when the exclusion is honored, and differ when it
# isn't (sanity check).
#
# Bash 3.2 / AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HASHER="$PROJECT_ROOT/tests/m035-acceptance/_byte-equivalence-hash.sh"

pass=0
fail=0

TMPA="$(mktemp -d)"
TMPB="$(mktemp -d)"

# Both dirs share `keep.txt` (identical content) and `subdir/keep2.txt`.
# Only `differ.txt` differs between them — when EXCLUSION_LIST excludes
# `differ.txt`, the two hashes must be equal.
mkdir -p "$TMPA/subdir" "$TMPB/subdir"
printf 'shared content\n' > "$TMPA/keep.txt"
printf 'shared content\n' > "$TMPB/keep.txt"
printf 'identical sub\n' > "$TMPA/subdir/keep2.txt"
printf 'identical sub\n' > "$TMPB/subdir/keep2.txt"
printf 'A-only\n' > "$TMPA/differ.txt"
printf 'B-only\n' > "$TMPB/differ.txt"

# Sanity: without exclusion, hashes should differ.
hash_a_unfiltered="$(STAGED="$TMPA" EXCLUSION_LIST="" bash "$HASHER")"
hash_b_unfiltered="$(STAGED="$TMPB" EXCLUSION_LIST="" bash "$HASHER")"
if [ "$hash_a_unfiltered" != "$hash_b_unfiltered" ]; then
  printf 'PASS: sanity — unfiltered hashes differ when content differs\n'
  pass=$((pass + 1))
else
  printf 'FAIL: sanity — unfiltered hashes match unexpectedly (a=%s b=%s)\n' \
    "$hash_a_unfiltered" "$hash_b_unfiltered"
  fail=$((fail + 1))
fi

# With differ.txt excluded, hashes must be equal.
hash_a_filtered="$(STAGED="$TMPA" EXCLUSION_LIST="differ.txt" bash "$HASHER")"
hash_b_filtered="$(STAGED="$TMPB" EXCLUSION_LIST="differ.txt" bash "$HASHER")"
if [ "$hash_a_filtered" = "$hash_b_filtered" ]; then
  printf 'PASS: filtered hashes match when only differ.txt is excluded\n'
  pass=$((pass + 1))
else
  printf 'FAIL: filtered hashes differ — EXCLUSION_LIST not honored (a=%s b=%s)\n' \
    "$hash_a_filtered" "$hash_b_filtered"
  fail=$((fail + 1))
fi

# Test directory-prefix exclusion: stage divergent content under a subdir,
# exclude the subdir, hashes must match.
mkdir -p "$TMPA/excluded" "$TMPB/excluded"
printf 'A-version\n' > "$TMPA/excluded/file.txt"
printf 'B-version\n' > "$TMPB/excluded/file.txt"

hash_a_dir_excl="$(STAGED="$TMPA" EXCLUSION_LIST="excluded/
differ.txt" bash "$HASHER")"
hash_b_dir_excl="$(STAGED="$TMPB" EXCLUSION_LIST="excluded/
differ.txt" bash "$HASHER")"
if [ "$hash_a_dir_excl" = "$hash_b_dir_excl" ]; then
  printf 'PASS: directory-prefix exclusion (excluded/ + differ.txt)\n'
  pass=$((pass + 1))
else
  printf 'FAIL: directory-prefix exclusion did not match (a=%s b=%s)\n' \
    "$hash_a_dir_excl" "$hash_b_dir_excl"
  fail=$((fail + 1))
fi

# Test that exclusion does NOT match a path that doesn't start with the
# exclusion prefix (must remain prefix-anchored, not substring-anywhere).
# Stage `unrelated/foo.txt` — must still be hashed even though `foo.txt`
# also appears under `keep.txt` substring.
mkdir -p "$TMPA/unrelated" "$TMPB/unrelated"
printf 'A-only-content\n' > "$TMPA/unrelated/foo.txt"
printf 'B-only-content\n' > "$TMPB/unrelated/foo.txt"

# Excluding `foo.txt` (no slash, no prefix) MUST NOT exclude
# `unrelated/foo.txt` — because matching is anchored at start.
hash_a_anchored="$(STAGED="$TMPA" EXCLUSION_LIST="excluded/
differ.txt
foo.txt" bash "$HASHER")"
hash_b_anchored="$(STAGED="$TMPB" EXCLUSION_LIST="excluded/
differ.txt
foo.txt" bash "$HASHER")"
if [ "$hash_a_anchored" != "$hash_b_anchored" ]; then
  printf 'PASS: exclusion is start-anchored — `foo.txt` does not exclude `unrelated/foo.txt`\n'
  pass=$((pass + 1))
else
  printf 'FAIL: exclusion matched substring rather than prefix (a=%s b=%s)\n' \
    "$hash_a_anchored" "$hash_b_anchored"
  fail=$((fail + 1))
fi

# Cleanup
rm -rf "$TMPA" "$TMPB"

printf 'BATTERY: pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
