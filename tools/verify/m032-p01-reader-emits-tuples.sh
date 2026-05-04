#!/usr/bin/env bash
# tools/verify/m032-p01-reader-emits-tuples.sh -- M032 P01 FR-2 verifier.
#
# Asserts scripts/lifecycle/read-project-assets.sh emits exactly four
# tab-separated `source=...\ttarget=...\tmode=copy` lines for the
# repo bundle manifest.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
READER="$PROJECT_ROOT/scripts/lifecycle/read-project-assets.sh"
BUNDLE="$PROJECT_ROOT/packaging/bundle/"

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

# 1. Reader exists and is executable.
if [ -x "$READER" ]; then
    check "read-project-assets.sh exists and is executable" 0
else
    check "read-project-assets.sh exists and is executable" 1
fi

# 2. Reader exits 0 against repo bundle manifest.
out_file="$( mktemp -t m032-p01-reader.XXXXXX )"
trap 'rm -f "$out_file"' EXIT

bash "$READER" "$BUNDLE" > "$out_file"
rc=$?
if [ "$rc" -eq 0 ]; then
    check "reader exit code 0" 0
else
    printf 'FAIL: reader exit code %s\n' "$rc"
    fail=$((fail + 1))
fi

# 3. Exactly four output lines.
line_count=$(awk 'END {print NR}' "$out_file")
if [ "$line_count" -eq 4 ]; then
    check "reader emits 4 lines" 0
else
    printf 'FAIL: expected 4 lines, got %s\n' "$line_count"
    fail=$((fail + 1))
fi

# 4. Each line matches the tuple shape.
line_idx=0
while IFS= read -r line; do
    line_idx=$((line_idx + 1))
    # Use printf to embed tab as a literal for grep -E.
    if printf '%s\n' "$line" | grep -qE '^source=[^	]+	target=[^	]+	mode=copy$'; then
        check "line ${line_idx} shape" 0
    else
        printf 'FAIL: line %s shape mismatch: %s\n' "$line_idx" "$line"
        fail=$((fail + 1))
    fi
done < "$out_file"

# 5. Verify the four expected sources.
for src in 'commands/' 'scripts/' 'references/' 'templates/'; do
    if grep -qE "^source=${src}	" "$out_file"; then
        check "tuple for source=${src}" 0
    else
        check "tuple for source=${src}" 1
    fi
done

printf 'SUMMARY: m032-p01-reader-emits-tuples.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
