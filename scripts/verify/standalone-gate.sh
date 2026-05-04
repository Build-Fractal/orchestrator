#!/usr/bin/env bash
# standalone-gate.sh
#
# FR-6 / Principle XVI standalone gate. Scans the M033-shipped
# constitution-authoring surface for any case-insensitive `speckit`
# substring. Zero matches required — Principle XVI (Distribution Surface
# Integrity) demands the orchestrator's content-authoring surfaces ship
# free of spec-kit references so any downstream-project constitution
# authored by these surfaces is automatically standalone.
#
# Subcommand-dispatched: `constitution` is the v1 surface. Future
# subcommands (`ingest-codebase`, etc.) extend the gate without
# contract drift.
#
# The closed surface file set is the SSOT block below. Extending the
# surface requires editing the fenced block, not the consumer.
#
# Tolerance for partially-landed surfaces: a file enumerated in the
# surface that does not yet exist on disk emits `SKIP:` and is not
# counted as a failure. This preserves the ability to land verifier
# surfaces (T01) before consumer surfaces (T02). T05's SC-2 acceptance
# script asserts the gate emits zero SKIP lines after the full surface
# is in place.
#
# Note: scripts/verify/standalone-gate.sh itself is NOT in its own
# surface list — the gate scans authored surfaces, not its own
# implementation.
#
# Bash 3.2 compatible (MEM001). Single-script invocation shape (AD-19).

set -u

# >>> constitution-surface-files >>>
# commands/constitution.md
# scripts/lifecycle/constitution-author.sh
# templates/constitution-starters/web-saas.md
# templates/constitution-starters/cli-tool.md
# templates/constitution-starters/library.md
# references/constitution-starter-format.md
# scripts/verify/constitution-shape-lint.sh
# <<< constitution-surface-files <<<

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

subcommand="${1:-}"

if [ -z "$subcommand" ]; then
    echo "usage: standalone-gate.sh constitution" >&2
    exit 2
fi

case "$subcommand" in
    constitution)
        : # supported
        ;;
    *)
        echo "usage: standalone-gate.sh constitution" >&2
        echo "FAIL: unknown subcommand '$subcommand'" >&2
        exit 2
        ;;
esac

# Read the SSOT block via awk (bash 3.2 safe — no process substitution,
# no $(...) with pipes). Strip the leading "# " comment marker so each
# line is a bare relative path.
surface_block=$(awk '
    />>> constitution-surface-files >>>/ { in_block=1; next }
    /<<< constitution-surface-files <<</ { in_block=0; next }
    in_block { sub(/^# */, ""); print }
' "$0")

pass=0
skip=0
fail=0

IFS_BAK="$IFS"
IFS=$'\n'
for surface_file in $surface_block; do
    IFS="$IFS_BAK"
    # skip blank lines defensively
    if [ -z "$surface_file" ]; then
        IFS=$'\n'
        continue
    fi
    abs_path="$PROJECT_ROOT/$surface_file"
    if [ ! -f "$abs_path" ]; then
        skip=$((skip + 1))
        echo "SKIP: $surface_file not yet present (co-authored-but-not-yet-landed surface tolerated)"
        IFS=$'\n'
        continue
    fi
    # Scan for case-insensitive `speckit` substring.
    matches=$(grep -nFi 'speckit' "$abs_path")
    if [ -z "$matches" ]; then
        pass=$((pass + 1))
        echo "PASS: zero speckit references in $surface_file"
    else
        # Emit one FAIL line per match so callers see the line numbers.
        match_iter_ifs="$IFS"
        IFS=$'\n'
        for m in $matches; do
            IFS="$match_iter_ifs"
            lineno=${m%%:*}
            fail=$((fail + 1))
            echo "FAIL: speckit reference at $surface_file:$lineno" >&2
            IFS=$'\n'
        done
        IFS="$match_iter_ifs"
    fi
    IFS=$'\n'
done
IFS="$IFS_BAK"

if [ "$fail" -eq 0 ]; then
    echo "PASS: zero speckit references in M033-shipped constitution surface"
fi

echo "SUMMARY: standalone-gate.sh subcommand=$subcommand pass=$pass skip=$skip fail=$fail"

if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
