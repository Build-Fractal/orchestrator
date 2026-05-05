#!/usr/bin/env bash
# tools/verify/m032-p01-install-cc-byte-identical.sh -- M032 P01 T02 verifier.
#
# Asserts:
#   1. install-claude-code.sh no longer contains RUNTIME_DIRS= (FR-2).
#   2. install-claude-code.sh dispatches via read-project-assets.sh (new path).
#   3. install-claude-code.sh dispatches via install-collision-check.sh (FR-22).
#   4. install-claude-code.sh dispatches via install-asset-mode.sh (FR-3).
#   5. tools/verify/fixtures/m032-pre-m032-golden.txt exists, is non-empty,
#      and references all four runtime dirs (commands/, scripts/, references/,
#      templates/).
#   6. Post-migration `--dry-run` produces a `would_write=` set whose per-dir
#      counts equal the golden's per-dir counts (CON-4 byte-identical at
#      mode: copy). This is a count-comparison gate, not a literal `diff` of
#      the file trees — the count check catches drift cheaply; a full file-
#      tree `diff -r` would be the deeper check if drift is suspected.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
INSTALLER="$PROJECT_ROOT/packaging/install/install-claude-code.sh"
GOLDEN="$PROJECT_ROOT/tools/verify/fixtures/m032-pre-m032-golden.txt"

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

# 1. installer exists.
if [ -f "$INSTALLER" ]; then
    check "install-claude-code.sh exists" 0
else
    check "install-claude-code.sh exists" 1
    printf 'SUMMARY: m032-p01-install-cc-byte-identical.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. RUNTIME_DIRS= fully removed (FR-2).
if grep -q 'RUNTIME_DIRS=' "$INSTALLER"; then
    check "RUNTIME_DIRS= removed from install-claude-code.sh (FR-2)" 1
else
    check "RUNTIME_DIRS= removed from install-claude-code.sh (FR-2)" 0
fi

# 3. read-project-assets.sh dispatch present.
if grep -q 'read-project-assets.sh' "$INSTALLER"; then
    check "install-claude-code.sh dispatches via read-project-assets.sh" 0
else
    check "install-claude-code.sh dispatches via read-project-assets.sh" 1
fi

# 4. install-collision-check.sh dispatch present (FR-22).
if grep -q 'install-collision-check.sh' "$INSTALLER"; then
    check "install-claude-code.sh dispatches via install-collision-check.sh (FR-22)" 0
else
    check "install-claude-code.sh dispatches via install-collision-check.sh (FR-22)" 1
fi

# 5. install-asset-mode.sh dispatch present (FR-3).
if grep -q 'install-asset-mode.sh' "$INSTALLER"; then
    check "install-claude-code.sh dispatches via install-asset-mode.sh (FR-3)" 0
else
    check "install-claude-code.sh dispatches via install-asset-mode.sh (FR-3)" 1
fi

# 6. Golden file exists and is non-empty.
if [ -s "$GOLDEN" ]; then
    check "m032-pre-m032-golden.txt exists and is non-empty" 0
else
    check "m032-pre-m032-golden.txt exists and is non-empty" 1
fi

# 7. Golden references all four runtime dirs.
golden_ok=0
for dir in commands scripts references templates; do
    if ! grep -qE "^${dir}/ file_count=" "$GOLDEN"; then
        golden_ok=1
        break
    fi
done
check "golden references all four runtime dirs (commands/, scripts/, references/, templates/)" "$golden_ok"

# 8. Post-migration dry-run per-dir counts equal golden counts.
tmp_fixture="/tmp/m032-bi-check-$$"
rm -rf "$tmp_fixture"
mkdir -p "$tmp_fixture"
dry_out="/tmp/m032-bi-stdout-$$.txt"
bash "$INSTALLER" --dry-run --project-dir "$tmp_fixture" > "$dry_out" 2>&1
dry_rc=$?
if [ "$dry_rc" -ne 0 ]; then
    check "installer --dry-run succeeds against fresh fixture" 1
    cat "$dry_out" >&2
else
    check "installer --dry-run succeeds against fresh fixture" 0
    count_fail=0
    for dir in commands scripts references templates; do
        cnt=$(grep -c "^would_write=${tmp_fixture}/${dir}/" "$dry_out")
        expected=$(grep -E "^${dir}/ file_count=" "$GOLDEN" | sed 's/.*file_count=//')
        if [ "$cnt" != "$expected" ]; then
            printf 'DIFF: %s/ post=%s expected=%s\n' "$dir" "$cnt" "$expected" >&2
            count_fail=1
        fi
    done
    check "post-migration dry-run per-dir counts == golden (CON-4 byte-identical at mode: copy)" "$count_fail"
fi
rm -rf "$tmp_fixture" "$dry_out"

printf 'SUMMARY: m032-p01-install-cc-byte-identical.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
