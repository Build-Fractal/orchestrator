#!/usr/bin/env bash
# tools/verify/m032-p01-fixture-shape.sh -- M032 P01 T04 fixture shape verifier.
#
# Asserts the committed `tests/fixtures/m032-fresh-project-fixture/` carries
# the three required artifacts (.gitignore / .git-init-marker / README.md)
# with the documented contents.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
FIXTURE="$PROJECT_ROOT/tests/fixtures/m032-fresh-project-fixture"

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

# 1. .gitignore exists.
if [ -f "$FIXTURE/.gitignore" ]; then
    check ".gitignore exists" 0
else
    check ".gitignore exists" 1
fi

# 2. .gitignore lists each of the four runtime dirs (trailing-slash form).
for d in commands scripts references templates .orchestrator; do
    if grep -qE "^${d}/$" "$FIXTURE/.gitignore"; then
        check ".gitignore lists ${d}/" 0
    else
        check ".gitignore lists ${d}/" 1
    fi
done

# 3. .git-init-marker exists and references the canonical fixture remote.
if [ -f "$FIXTURE/.git-init-marker" ]; then
    check ".git-init-marker exists" 0
else
    check ".git-init-marker exists" 1
fi

if grep -q 'fixture-owner/m032-fresh-project-fixture' "$FIXTURE/.git-init-marker" 2>/dev/null; then
    check ".git-init-marker references fixture-owner/m032-fresh-project-fixture remote" 0
else
    check ".git-init-marker references fixture-owner/m032-fresh-project-fixture remote" 1
fi

# 4. README.md exists.
if [ -f "$FIXTURE/README.md" ]; then
    check "README.md exists" 0
else
    check "README.md exists" 1
fi

# 5. README.md references the four runtime dirs by name.
readme_missing_dir=0
for d in commands scripts references templates; do
    if ! grep -q "$d" "$FIXTURE/README.md" 2>/dev/null; then
        readme_missing_dir=1
        break
    fi
done
check "README.md references all four runtime dirs (commands/, scripts/, references/, templates/)" "$readme_missing_dir"

# 6. README.md documents the bootstrap procedure.
if grep -q 'git init' "$FIXTURE/README.md" 2>/dev/null; then
    check "README.md documents git init bootstrap procedure" 0
else
    check "README.md documents git init bootstrap procedure" 1
fi

printf 'SUMMARY: m032-p01-fixture-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
