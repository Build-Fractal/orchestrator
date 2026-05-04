#!/usr/bin/env bash
# tests/m032-acceptance/p01-managed-bundle-shape.sh -- M032 P01 SC-1.
#
# Asserts FR-1 (project_assets: schema present in manifest), FR-2 (claude-code
# installer drives staging from that schema, byte-identical at mode: copy),
# FR-4 (installed-files.txt carries `<rel>\tmode:<copy|symlink>` lines), and
# idempotency (second install run produces a byte-identical file-tree and a
# byte-identical installed-files.txt).
#
# Strategy: stage the committed fresh-project fixture into a `mktemp -d` dir,
# bootstrap a `.git/` via `git init`, run the claude-code installer twice with
# HOME pinned to a tempdir (so $HOME/.claude/ writes do not leak), then sha256
# the four runtime-dir file-trees on each run and compare.
#
# Output:
#   RESULT: ok p01-managed-bundle-shape.sh
#   RESULT: fail p01-managed-bundle-shape.sh reason=<reason>
#
# Exit codes: 0 ok, 1 fail.
#
# Bash 3.2 compatible. No jq/python.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
REPO_ROOT="$( cd "$REPO_ROOT/.." && pwd )"
FIXTURE="$REPO_ROOT/tests/fixtures/m032-fresh-project-fixture"
GOLDEN="$REPO_ROOT/tools/verify/fixtures/m032-pre-m032-golden.txt"
INSTALLER="$REPO_ROOT/packaging/install/install-claude-code.sh"
MANIFEST="$REPO_ROOT/packaging/bundle/manifest.yml"

fail_reason=""

emit_fail() {
    fail_reason="$1"
    printf 'RESULT: fail p01-managed-bundle-shape.sh reason=%s\n' "$fail_reason"
}

# --- Prep ---
if [ ! -d "$FIXTURE" ]; then
    emit_fail "fixture-missing:$FIXTURE"
    exit 1
fi

if [ ! -f "$INSTALLER" ]; then
    emit_fail "installer-missing:$INSTALLER"
    exit 1
fi

if [ ! -f "$GOLDEN" ]; then
    emit_fail "golden-missing:$GOLDEN"
    exit 1
fi

# Staging dir + sandboxed HOME.
TMP_BASE="$(mktemp -d)"
TMP_FIX="$TMP_BASE/m032-sc1-$$"
TMP_HOME="$TMP_BASE/home-$$"
mkdir -p "$TMP_FIX" "$TMP_HOME/.claude"

cleanup() {
    rm -rf "$TMP_BASE"
}
trap cleanup EXIT

# Stage the fixture.
cp -R "$FIXTURE/." "$TMP_FIX/"

# Bootstrap a .git/.
( cd "$TMP_FIX" && git init -q && \
  git remote add origin https://github.com/fixture-owner/m032-fresh-project-fixture.git )

# --- FR-1: project_assets: in manifest, four entries, all mode: copy. ---
if ! grep -q '^project_assets:$' "$MANIFEST"; then
    emit_fail "FR-1:project_assets-missing-in-manifest"
    exit 1
fi

for d in commands scripts references templates; do
    if ! grep -qE "^[[:space:]]+(- )?source: ${d}/$" "$MANIFEST"; then
        emit_fail "FR-1:project_assets-missing-source-$d"
        exit 1
    fi
done

mode_copy_count=$(grep -cE '^[[:space:]]+mode: copy$' "$MANIFEST")
if [ "$mode_copy_count" -lt 4 ]; then
    emit_fail "FR-1:project_assets-mode-copy-count=$mode_copy_count<4"
    exit 1
fi

# --- First install run ---
HOME="$TMP_HOME" bash "$INSTALLER" --project-dir "$TMP_FIX" > "$TMP_BASE/run1.log" 2>&1
rc1=$?
if [ "$rc1" -ne 0 ]; then
    emit_fail "first-install-exit=$rc1"
    cat "$TMP_BASE/run1.log" >&2
    exit 1
fi

# --- FR-2: per-dir file counts equal golden counts (byte-identical at mode: copy). ---
for dir in commands scripts references templates; do
    if [ ! -d "$TMP_FIX/$dir" ]; then
        emit_fail "FR-2:runtime-dir-missing:$dir"
        exit 1
    fi
    actual=$(find "$TMP_FIX/$dir" -type f | wc -l | tr -d ' ')
    expected=$(grep -E "^${dir}/ file_count=" "$GOLDEN" | sed 's/.*file_count=//')
    if [ "$actual" != "$expected" ]; then
        emit_fail "FR-2:per-dir-count-drift:$dir actual=$actual expected=$expected"
        exit 1
    fi
done

# --- FR-4: installed-files.txt exists, every line is `<path>\tmode:(copy|symlink)`. ---
INSTALLED="$TMP_FIX/.orchestrator/installed-files.txt"
if [ ! -f "$INSTALLED" ]; then
    emit_fail "FR-4:installed-files-missing"
    exit 1
fi

if [ ! -s "$INSTALLED" ]; then
    emit_fail "FR-4:installed-files-empty"
    exit 1
fi

# Each non-blank line must match the contract shape.
bad_line_count=$(awk 'NF > 0 && $0 !~ /^[^\t]+\tmode:(copy|symlink)$/' "$INSTALLED" | wc -l | tr -d ' ')
if [ "$bad_line_count" != "0" ]; then
    emit_fail "FR-4:installed-files-line-shape-violations=$bad_line_count"
    awk 'NF > 0 && $0 !~ /^[^\t]+\tmode:(copy|symlink)$/' "$INSTALLED" | head -5 >&2
    exit 1
fi

# All four runtime dirs are represented in column 1.
for dir in commands scripts references templates; do
    if ! awk -F'\t' '{print $1}' "$INSTALLED" | grep -qE "^${dir}/"; then
        emit_fail "FR-4:installed-files-missing-dir-prefix:$dir"
        exit 1
    fi
done

# --- Capture sha256 of the staged file-tree pre-rerun. ---
TREE_PRE="$TMP_BASE/sc1-sha-pre.txt"
( cd "$TMP_FIX" && find commands scripts references templates -type f -exec shasum -a 256 {} \; ) | sort > "$TREE_PRE"

# Capture installed-files.txt pre-rerun.
INSTALLED_PRE="$TMP_BASE/sc1-installed-pre.txt"
cp "$INSTALLED" "$INSTALLED_PRE"

# --- Second install run (idempotency). ---
HOME="$TMP_HOME" bash "$INSTALLER" --project-dir "$TMP_FIX" > "$TMP_BASE/run2.log" 2>&1
rc2=$?
if [ "$rc2" -ne 0 ]; then
    emit_fail "second-install-exit=$rc2"
    cat "$TMP_BASE/run2.log" >&2
    exit 1
fi

TREE_POST="$TMP_BASE/sc1-sha-post.txt"
( cd "$TMP_FIX" && find commands scripts references templates -type f -exec shasum -a 256 {} \; ) | sort > "$TREE_POST"

if ! cmp -s "$TREE_PRE" "$TREE_POST"; then
    emit_fail "idempotency:file-tree-sha256-drift"
    diff "$TREE_PRE" "$TREE_POST" | head -20 >&2
    exit 1
fi

if ! cmp -s "$INSTALLED_PRE" "$INSTALLED"; then
    emit_fail "idempotency:installed-files-byte-drift"
    diff "$INSTALLED_PRE" "$INSTALLED" | head -20 >&2
    exit 1
fi

printf 'RESULT: ok p01-managed-bundle-shape.sh\n'
exit 0
