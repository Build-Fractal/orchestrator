#!/usr/bin/env bash
# scripts/lifecycle/install-asset-mode.sh -- M032 P01 FR-3 + NG-9.
#
# Per-mode handler invoked once per read-project-assets.sh tuple by the
# installer in T02 + T03. Dispatches on `mode`:
#
#   copy    -- reproduces today's `cp -R "$src/." "$dst/"` byte-identically.
#   symlink -- POSIX `ln -s` to a resolved managed runtime root.
#
# Windows fail-closed (NG-9): when M032_FORCE_WINDOWS=1 OR `ln -s` is not
# available, the symlink branch exits 3 with "POSIX-only in v1" on stderr
# and writes nothing under <PROJECT_DIR>/<target>.
#
# Output (stdout): one line per successful invocation.
#   copy:    staged_mode=copy src=<src> dst=<dst>
#   symlink: staged_mode=symlink src=<src> dst=<dst> link_target=<resolved>
#
# Exit codes:
#   0 = success
#   2 = invalid input (unknown mode)
#   3 = POSIX-only fail-closed (Windows symlink request)
#
# IMPORTANT: This script does NOT pre-check for collisions. The installer
# is expected to invoke install-collision-check.sh BEFORE this script.
#
# Usage:
#   bash scripts/lifecycle/install-asset-mode.sh <src-abs> <dst-abs> <mode> <project-dir-abs>
#
# Bash 3.2 compatible (no declare -A per K001 / MEM001).

set -u

if [ "$#" -lt 4 ]; then
    echo "FAIL: install-asset-mode.sh requires 4 args: <src-abs> <dst-abs> <mode> <project-dir-abs>" >&2
    exit 2
fi

SRC="$1"
DST="$2"
MODE="$3"
PROJECT_DIR="$4"

case "$MODE" in
    copy)
        mkdir -p "$DST"
        cp -R "$SRC/." "$DST/"
        printf 'staged_mode=copy src=%s dst=%s\n' "$SRC" "$DST"
        exit 0
        ;;
    symlink)
        # Windows fail-closed (NG-9).
        if [ "${M032_FORCE_WINDOWS:-0}" = "1" ] || ! command -v ln >/dev/null 2>&1; then
            echo "FAIL: mode: symlink is POSIX-only in v1 (NG-9)" >&2
            exit 3
        fi
        # Resolve runtime root: prefer ~/.claude/orchestrator-runtime/<version>/
        # (highest-versioned subdir if multiple exist), else fall back to
        # <PROJECT_DIR>/.orchestrator/runtime-cache/ (Assumption A-1).
        runtime_root="${HOME}/.claude/orchestrator-runtime"
        resolved_runtime=""
        if [ -d "$runtime_root" ]; then
            # Pick highest-versioned subdir via lexicographic sort (v1
            # constraint: version slugs are sortable strings).
            picked=""
            # Enumerate immediate subdirs, sort, pick last.
            picked="$(
                find "$runtime_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
                    | sort \
                    | tail -n 1
            )"
            if [ -n "$picked" ]; then
                resolved_runtime="$picked"
            fi
        fi
        if [ -z "$resolved_runtime" ]; then
            # Fallback per Assumption A-1.
            resolved_runtime="${PROJECT_DIR}/.orchestrator/runtime-cache"
            mkdir -p "$resolved_runtime"
        fi
        # Compute basename of source (strip trailing slash).
        src_no_slash="${SRC%/}"
        src_base="${src_no_slash##*/}"
        link_target="${resolved_runtime}/${src_base}"
        # Idempotency: second invocation overwrites the symlink.
        mkdir -p "$(dirname "$DST")"
        rm -rf "$DST"
        ln -s "$link_target" "$DST"
        printf 'staged_mode=symlink src=%s dst=%s link_target=%s\n' "$SRC" "$DST" "$link_target"
        exit 0
        ;;
    *)
        printf "FAIL: install-asset-mode.sh: unknown mode '%s'\n" "$MODE" >&2
        exit 2
        ;;
esac
