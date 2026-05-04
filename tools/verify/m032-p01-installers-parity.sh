#!/usr/bin/env bash
# tools/verify/m032-p01-installers-parity.sh -- M032 P01 T03 verifier.
#
# Asserts the cross-installer parity invariant after the FR-2 migration
# lands in all three installers (claude-code + codex + cursor):
#
#   1. Literal token RUNTIME_DIRS= no longer appears in any of the three
#      installers (FR-2).
#   2. All three installers source read-project-assets.sh + dispatch through
#      install-collision-check.sh + install-asset-mode.sh.
#   3. The project-asset staging block (delimited by the canonical
#      `# --- 4.5 Stage runtime payload via project_assets:` comment header
#      and the closing `staged=$runtime_staged files manifest=$manifest_file`
#      echo) is BYTE-IDENTICAL across all three installers (CON-2 parity).
#   4. Dry-run installs of codex and cursor against fresh temp fixtures
#      produce per-runtime-dir `would_write=` line counts that match the
#      golden fixture (CON-4 byte-identical at mode: copy, mirroring T02's
#      verification of claude-code).
#
# Cursor's installer requires .cursor/ signals at the probe stage; the
# verifier seeds an empty .cursor/ directory in its temp fixture so the
# probe succeeds and the project-asset stage runs.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
INSTALL_DIR="$PROJECT_ROOT/packaging/install"
GOLDEN="$PROJECT_ROOT/tools/verify/fixtures/m032-pre-m032-golden.txt"

CC="$INSTALL_DIR/install-claude-code.sh"
CODEX="$INSTALL_DIR/install-codex.sh"
CURSOR="$INSTALL_DIR/install-cursor.sh"

pass=0
fail=0

check() {
    desc="$1"
    rc="$2"
    if [ "$rc" -eq 0 ]; then
        printf 'PASS: %s\n' "$desc"
        pass=$((pass + 1))
    else
        printf 'FAIL: %s\n' "$desc"
        fail=$((fail + 1))
    fi
}

# 0. all three installers exist.
for f in "$CC" "$CODEX" "$CURSOR"; do
    if [ -f "$f" ]; then
        check "installer exists: $(basename "$f")" 0
    else
        check "installer exists: $(basename "$f")" 1
        printf 'SUMMARY: m032-p01-installers-parity.sh pass=%d fail=%d\n' "$pass" "$fail"
        exit 1
    fi
done

# 1. RUNTIME_DIRS= absent from all three (FR-2 across all installers).
for f in "$CC" "$CODEX" "$CURSOR"; do
    if grep -q 'RUNTIME_DIRS=' "$f"; then
        check "RUNTIME_DIRS= removed from $(basename "$f") (FR-2)" 1
    else
        check "RUNTIME_DIRS= removed from $(basename "$f") (FR-2)" 0
    fi
done

# 2. all three dispatch via the three lifecycle helpers.
for helper in read-project-assets.sh install-collision-check.sh install-asset-mode.sh; do
    for f in "$CC" "$CODEX" "$CURSOR"; do
        if grep -q "$helper" "$f"; then
            check "$(basename "$f") dispatches via $helper" 0
        else
            check "$(basename "$f") dispatches via $helper" 1
        fi
    done
done

# 3. all three installers honor --asset-mode-override.
for f in "$CC" "$CODEX" "$CURSOR"; do
    if grep -q -- '--asset-mode-override' "$f"; then
        check "$(basename "$f") parses --asset-mode-override" 0
    else
        check "$(basename "$f") parses --asset-mode-override" 1
    fi
done

# 4. project-asset staging block is byte-identical across all three.
# Awk delimiters: from the canonical `# --- 4.5 Stage runtime payload via
# project_assets:` comment header through the closing `  echo "staged=...`
# line (indented by 2 spaces inside `if [ "$DRY_RUN" = "0" ]; then`).
extract_block() {
    awk '/^# --- 4.5 Stage runtime payload via project_assets:/{p=1}
         p;
         /^  echo "staged=\$runtime_staged files manifest=\$manifest_file"$/{p=0; exit}' \
        "$1"
}

cc_block="/tmp/m032-block-cc-$$.txt"
codex_block="/tmp/m032-block-codex-$$.txt"
cursor_block="/tmp/m032-block-cursor-$$.txt"
extract_block "$CC"     > "$cc_block"
extract_block "$CODEX"  > "$codex_block"
extract_block "$CURSOR" > "$cursor_block"

if diff -q "$cc_block" "$codex_block" > /dev/null 2>&1; then
    check "project-asset block byte-identical: install-claude-code.sh == install-codex.sh" 0
else
    check "project-asset block byte-identical: install-claude-code.sh == install-codex.sh" 1
    diff -u "$cc_block" "$codex_block" >&2
fi

if diff -q "$cc_block" "$cursor_block" > /dev/null 2>&1; then
    check "project-asset block byte-identical: install-claude-code.sh == install-cursor.sh" 0
else
    check "project-asset block byte-identical: install-claude-code.sh == install-cursor.sh" 1
    diff -u "$cc_block" "$cursor_block" >&2
fi

rm -f "$cc_block" "$codex_block" "$cursor_block"

# 5. golden fixture exists.
if [ -s "$GOLDEN" ]; then
    check "m032-pre-m032-golden.txt exists and is non-empty" 0
else
    check "m032-pre-m032-golden.txt exists and is non-empty" 1
fi

# 6. codex dry-run per-dir counts match golden (CON-4).
tmp_codex="/tmp/m032-codex-parity-$$"
rm -rf "$tmp_codex"
mkdir -p "$tmp_codex"
codex_dry="/tmp/m032-codex-dry-$$.txt"
bash "$CODEX" --dry-run --project-dir "$tmp_codex" > "$codex_dry" 2>&1
codex_rc=$?
if [ "$codex_rc" -ne 0 ]; then
    check "install-codex.sh --dry-run succeeds against fresh fixture" 1
    cat "$codex_dry" >&2
else
    check "install-codex.sh --dry-run succeeds against fresh fixture" 0
    count_fail=0
    for dir in commands scripts references templates; do
        cnt=$(grep -c "^would_write=${tmp_codex}/${dir}/" "$codex_dry")
        expected=$(grep -E "^${dir}/ file_count=" "$GOLDEN" | sed 's/.*file_count=//')
        if [ "$cnt" != "$expected" ]; then
            printf 'DIFF: codex %s/ post=%s expected=%s\n' "$dir" "$cnt" "$expected" >&2
            count_fail=1
        fi
    done
    check "codex dry-run per-dir counts == golden (CON-4)" "$count_fail"
fi
rm -rf "$tmp_codex" "$codex_dry"

# 7. cursor dry-run per-dir counts match golden (CON-4).
# Cursor's adapter probe requires `.cursor/` signals; seed an empty one
# so the probe passes and the project-asset stage runs.
tmp_cursor="/tmp/m032-cursor-parity-$$"
rm -rf "$tmp_cursor"
mkdir -p "$tmp_cursor/.cursor"
cursor_dry="/tmp/m032-cursor-dry-$$.txt"
bash "$CURSOR" --dry-run --project-dir "$tmp_cursor" > "$cursor_dry" 2>&1
cursor_rc=$?
if [ "$cursor_rc" -ne 0 ]; then
    check "install-cursor.sh --dry-run succeeds against fresh fixture" 1
    cat "$cursor_dry" >&2
else
    check "install-cursor.sh --dry-run succeeds against fresh fixture" 0
    count_fail=0
    for dir in commands scripts references templates; do
        cnt=$(grep -c "^would_write=${tmp_cursor}/${dir}/" "$cursor_dry")
        expected=$(grep -E "^${dir}/ file_count=" "$GOLDEN" | sed 's/.*file_count=//')
        if [ "$cnt" != "$expected" ]; then
            printf 'DIFF: cursor %s/ post=%s expected=%s\n' "$dir" "$cnt" "$expected" >&2
            count_fail=1
        fi
    done
    check "cursor dry-run per-dir counts == golden (CON-4)" "$count_fail"
fi
rm -rf "$tmp_cursor" "$cursor_dry"

printf 'SUMMARY: m032-p01-installers-parity.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
