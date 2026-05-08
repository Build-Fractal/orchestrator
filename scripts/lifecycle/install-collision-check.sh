#!/usr/bin/env bash
# scripts/lifecycle/install-collision-check.sh -- M032 P01 FR-22 + MIT-006.
#
# Dual-oracle hierarchy invoked once per read-project-assets.sh tuple
# BEFORE install-asset-mode.sh dispatches. Determines whether the
# proposed target path is safe to overwrite (framework-installed) or
# must be flagged as a collision (operator-owned).
#
# Oracle order (strict):
#   1. Tracking-file oracle (primary):
#      <project-dir>/.orchestrator/installed-files.txt -- if exists AND
#      target's relative form is in column 1, the path is
#      framework-installed. Caller may overwrite.
#   2. Bootstrapping oracle (MIT-006):
#      Applies when installed-files.txt is absent. If the proposed
#      relative target appears in the project-assets target list
#      (passed as arg 3), the path is treated as framework-installed
#      bootstrap. The caller is responsible for writing
#      installed-files.txt at the END of the install run.
#   3. Operator-owned oracle (tertiary):
#      If the target pre-exists AND is NOT in the tracking file AND is
#      NOT gitignored, the path is plausibly operator-owned. Emit a
#      collision diagnostic and fail closed (exit 4).
#
# installed-files.txt FILE FORMAT INVARIANT (FR-22):
#   Column 1: relative path (from project root). Tab-separated. No
#   spaces between the path and any future `mode:` token. Future
#   columns may carry mode metadata, but the LEFT-COLUMN
#   path-of-record is canonical and must remain tab-delimited.
#   The install-asset-mode.sh emit lines (staged_mode=...) use
#   `key=value` tokens (no `mode:` colon-token), so the writer in T02
#   never embeds spaces between path and any `mode:` literal.
#
# Output (stdout, on safe paths):
#   oracle=tracking-file result=framework-installed target=<rel>
#   oracle=bootstrapping  result=framework-installed target=<rel> mit=MIT-006
#   oracle=clean          result=ok target=<rel>
#
# Output on operator-owned hit (depends on --on-operator-owned):
#   fail mode (default, stderr, exit 4):
#     oracle=operator-owned result=collision target=<rel> manifest_entry=<rel>
#     staged-dirs-collision: project_assets entry <entry> collides with operator-owned <path>
#   skip mode (stdout, exit 5):
#     oracle=operator-owned result=skip-operator-owned target=<rel> manifest_entry=<rel>
#     staged-dirs-skip: project_assets entry <entry> preserves operator-owned <path>
#
# Exit codes:
#   0 = safe (framework-installed or clean)
#   2 = invalid input (missing args, project-dir not absolute)
#   4 = FR-22 collision detected (operator-owned, fail mode)
#   5 = operator-owned soft-skip (--on-operator-owned=skip)
#
# Usage:
#   bash scripts/lifecycle/install-collision-check.sh \
#     [--on-operator-owned=fail|skip] \
#     <target-abs-path> <project-dir-abs> <project-assets-target-list-newline-sep>
#
# --on-operator-owned (PBJ-2026-05-08 paper-cut, follow-on to 253eb748 deferred
# note): when oracle 3 hits, fail-closed (exit 4) keeps the SC-10 contract;
# skip mode emits skip-tokens and exits 5 so install-{claude-code,codex,cursor}.sh
# can preserve operator-owned content (the wiki/ re-install case in
# particular) and continue staging the next asset.
#
# Bash 3.2 compatible (no declare -A per K001 / MEM001).

set -u

ON_OPERATOR_OWNED="fail"

# Consume leading flags up to the first positional. Stop on first non-flag
# so positional args (notably the third — a newline-separated list) survive
# byte-identical. Bash 3.2 compatible (no arrays).
while [ $# -gt 0 ]; do
    case "$1" in
        --on-operator-owned=*) ON_OPERATOR_OWNED="${1#--on-operator-owned=}"; shift ;;
        --on-operator-owned)
            shift
            if [ $# -eq 0 ]; then
                echo "FAIL: --on-operator-owned requires an argument (fail|skip)" >&2
                exit 2
            fi
            ON_OPERATOR_OWNED="$1"; shift ;;
        --) shift; break ;;
        --*)
            echo "FAIL: install-collision-check.sh: unknown flag '$1'" >&2
            exit 2 ;;
        *) break ;;
    esac
done

case "$ON_OPERATOR_OWNED" in
    fail|skip) : ;;
    *)
        echo "FAIL: --on-operator-owned must be 'fail' or 'skip' (got '$ON_OPERATOR_OWNED')" >&2
        exit 2 ;;
esac

if [ "$#" -lt 3 ]; then
    echo "FAIL: install-collision-check.sh requires 3 args: <target-abs> <project-dir-abs> <project-assets-target-list>" >&2
    exit 2
fi

ABS_TARGET="$1"
PROJECT_DIR="$2"
PROJECT_ASSETS_LIST="$3"

# Compute relative target by stripping the project-dir prefix.
# Both inputs are expected absolute; if ABS_TARGET starts with
# PROJECT_DIR + "/", strip and use the suffix; else echo as-is.
case "$ABS_TARGET" in
    "$PROJECT_DIR"/*)
        REL_TARGET="${ABS_TARGET#$PROJECT_DIR/}"
        ;;
    *)
        REL_TARGET="$ABS_TARGET"
        ;;
esac

# Strip trailing slash for consistent comparison.
REL_TARGET="${REL_TARGET%/}"

TRACKING_FILE="${PROJECT_DIR}/.orchestrator/installed-files.txt"

# ---------- 1. Tracking-file oracle (primary) ----------
if [ -f "$TRACKING_FILE" ]; then
    # Read column 1 (tab-delimited), match against rel_target exactly.
    # Also tolerate trailing slash variant.
    if awk -F'\t' '{print $1}' "$TRACKING_FILE" | grep -Fxq "$REL_TARGET"; then
        printf 'oracle=tracking-file result=framework-installed target=%s\n' "$REL_TARGET"
        exit 0
    fi
    # Also try rel_target/ (trailing slash form) since project_assets
    # entries are dir-shaped.
    if awk -F'\t' '{print $1}' "$TRACKING_FILE" | grep -Fxq "$REL_TARGET/"; then
        printf 'oracle=tracking-file result=framework-installed target=%s\n' "$REL_TARGET"
        exit 0
    fi
fi

# ---------- 2. Bootstrapping oracle (MIT-006) ----------
# Applies when the tracking file is absent.
if [ ! -f "$TRACKING_FILE" ]; then
    # Match rel_target against the project-assets target list (newline-separated).
    # Tolerate trailing-slash variants on either side of the comparison.
    rel_with_slash="${REL_TARGET}/"
    while IFS= read -r entry; do
        if [ -z "$entry" ]; then
            continue
        fi
        # Strip trailing slash from entry for comparison.
        entry_no_slash="${entry%/}"
        if [ "$entry_no_slash" = "$REL_TARGET" ] || [ "$entry" = "$REL_TARGET" ] || [ "$entry" = "$rel_with_slash" ]; then
            printf 'oracle=bootstrapping result=framework-installed target=%s mit=MIT-006\n' "$REL_TARGET"
            exit 0
        fi
    done <<EOF
$PROJECT_ASSETS_LIST
EOF
fi

# ---------- 3. Operator-owned oracle (tertiary) ----------
if [ -e "$ABS_TARGET" ]; then
    # Check gitignore status. We only flag operator-owned if the path
    # is NOT gitignored (gitignored paths are operator-untracked junk
    # that we may safely co-opt; tracked or untracked-but-not-ignored
    # paths are plausibly operator-owned).
    git_check_rc=1
    if command -v git >/dev/null 2>&1; then
        if git -C "$PROJECT_DIR" check-ignore -- "$REL_TARGET" >/dev/null 2>&1; then
            git_check_rc=0
        fi
    fi
    if [ "$git_check_rc" -ne 0 ]; then
        # Path pre-exists, not in tracking file, not gitignored ->
        # plausibly operator-owned. Branch on caller's --on-operator-owned
        # policy: fail-closed (exit 4, default, preserves SC-10 contract)
        # or soft-skip (exit 5, emit skip-tokens to stdout, caller preserves
        # the operator-owned target and continues to the next asset).
        if [ "$ON_OPERATOR_OWNED" = "skip" ]; then
            printf 'oracle=operator-owned result=skip-operator-owned target=%s manifest_entry=%s\n' "$REL_TARGET" "$REL_TARGET"
            printf 'staged-dirs-skip: project_assets entry %s preserves operator-owned %s\n' "$REL_TARGET" "$REL_TARGET"
            exit 5
        fi
        printf 'oracle=operator-owned result=collision target=%s manifest_entry=%s\n' "$REL_TARGET" "$REL_TARGET" >&2
        printf 'staged-dirs-collision: project_assets entry %s collides with operator-owned %s\n' "$REL_TARGET" "$REL_TARGET" >&2
        exit 4
    fi
fi

# ---------- Otherwise: clean ----------
printf 'oracle=clean result=ok target=%s\n' "$REL_TARGET"
exit 0
