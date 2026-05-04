#!/usr/bin/env bash
# tools/verify/m032-p01-mode-handler-symlink.sh -- M032 P01 FR-3 + NG-9 verifier.
#
# Exercises both branches of scripts/lifecycle/install-asset-mode.sh
# against a mktemp -d-staged fixture:
#   - copy mode produces a regular file tree.
#   - symlink mode under M032_FORCE_WINDOWS=1 exits 3 with
#     'POSIX-only in v1' on stderr.
#   - symlink mode without the env var produces a symlink ([ -L <dst> ]).
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
HANDLER="$PROJECT_ROOT/scripts/lifecycle/install-asset-mode.sh"
WITH_ENV="$PROJECT_ROOT/scripts/util/with-env.sh"

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

# Stage a fixture with a small src/ tree.
FIXTURE="$( mktemp -d -t m032-p01-mode-handler.XXXXXX )"
trap 'rm -rf "$FIXTURE"' EXIT

mkdir -p "$FIXTURE/src/sub"
printf 'hello\n' > "$FIXTURE/src/file-a.txt"
printf 'world\n' > "$FIXTURE/src/sub/file-b.txt"

PROJECT_DIR="$FIXTURE/project"
mkdir -p "$PROJECT_DIR"

# 1. copy mode produces regular file tree.
DST_COPY="$PROJECT_DIR/copy-target"
out_copy="$( mktemp -t m032-p01-copy-out.XXXXXX )"
err_copy="$( mktemp -t m032-p01-copy-err.XXXXXX )"
bash "$HANDLER" "$FIXTURE/src" "$DST_COPY" copy "$PROJECT_DIR" >"$out_copy" 2>"$err_copy"
rc_copy=$?
if [ "$rc_copy" -eq 0 ]; then
    check "copy mode exit 0" 0
else
    printf 'FAIL: copy mode exit %s (stderr: %s)\n' "$rc_copy" "$(cat "$err_copy")"
    fail=$((fail + 1))
fi
if [ -f "$DST_COPY/file-a.txt" ] && [ -f "$DST_COPY/sub/file-b.txt" ]; then
    check "copy mode reproduces file tree" 0
else
    check "copy mode reproduces file tree" 1
fi
if [ ! -L "$DST_COPY/file-a.txt" ]; then
    check "copy mode produces regular files (not symlinks)" 0
else
    check "copy mode produces regular files (not symlinks)" 1
fi
if grep -q 'staged_mode=copy' "$out_copy"; then
    check "copy mode emits staged_mode=copy" 0
else
    check "copy mode emits staged_mode=copy" 1
fi
rm -f "$out_copy" "$err_copy"

# 2. symlink mode under M032_FORCE_WINDOWS=1 exits 3.
DST_WIN="$PROJECT_DIR/symlink-windows-target"
out_win="$( mktemp -t m032-p01-win-out.XXXXXX )"
err_win="$( mktemp -t m032-p01-win-err.XXXXXX )"
# Use with-env wrapper per AP-008 / AP-007.
bash "$WITH_ENV" M032_FORCE_WINDOWS=1 -- bash "$HANDLER" "$FIXTURE/src" "$DST_WIN" symlink "$PROJECT_DIR" >"$out_win" 2>"$err_win"
rc_win=$?
if [ "$rc_win" -eq 3 ]; then
    check "symlink+windows exit 3" 0
else
    printf 'FAIL: symlink+windows exit %s (expected 3)\n' "$rc_win"
    fail=$((fail + 1))
fi
if grep -q 'POSIX-only in v1' "$err_win"; then
    check "symlink+windows stderr contains POSIX-only in v1" 0
else
    check "symlink+windows stderr contains POSIX-only in v1" 1
fi
if [ ! -e "$DST_WIN" ] && [ ! -L "$DST_WIN" ]; then
    check "symlink+windows wrote nothing under target" 0
else
    check "symlink+windows wrote nothing under target" 1
fi
rm -f "$out_win" "$err_win"

# 3. symlink mode without the env var produces a symlink.
DST_SYM="$PROJECT_DIR/symlink-target"
out_sym="$( mktemp -t m032-p01-sym-out.XXXXXX )"
err_sym="$( mktemp -t m032-p01-sym-err.XXXXXX )"
bash "$HANDLER" "$FIXTURE/src" "$DST_SYM" symlink "$PROJECT_DIR" >"$out_sym" 2>"$err_sym"
rc_sym=$?
if [ "$rc_sym" -eq 0 ]; then
    check "symlink mode exit 0" 0
else
    printf 'FAIL: symlink mode exit %s (stderr: %s)\n' "$rc_sym" "$(cat "$err_sym")"
    fail=$((fail + 1))
fi
if [ -L "$DST_SYM" ]; then
    check "symlink mode produces a symlink" 0
else
    check "symlink mode produces a symlink" 1
fi
if grep -q 'staged_mode=symlink' "$out_sym"; then
    check "symlink mode emits staged_mode=symlink" 0
else
    check "symlink mode emits staged_mode=symlink" 1
fi
rm -f "$out_sym" "$err_sym"

# 4. Unknown mode exits 2.
DST_BAD="$PROJECT_DIR/bad-target"
err_bad="$( mktemp -t m032-p01-bad-err.XXXXXX )"
bash "$HANDLER" "$FIXTURE/src" "$DST_BAD" weirdmode "$PROJECT_DIR" 2>"$err_bad"
rc_bad=$?
if [ "$rc_bad" -eq 2 ]; then
    check "unknown mode exit 2" 0
else
    printf 'FAIL: unknown mode exit %s (expected 2)\n' "$rc_bad"
    fail=$((fail + 1))
fi
if grep -q "unknown mode 'weirdmode'" "$err_bad"; then
    check "unknown mode stderr names mode" 0
else
    check "unknown mode stderr names mode" 1
fi
rm -f "$err_bad"

printf 'SUMMARY: m032-p01-mode-handler-symlink.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
