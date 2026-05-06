#!/usr/bin/env bash
# decisions-shape-lint.sh — framework-owned shape-lint verifier for DECISIONS.md
#
# Enforces the M037/P01/T03 heading-shape contract per spec 038 FR-7:
#
#   - Every `### ` heading MUST match: ^### .+ \{ #(dr|bg|an|mem|q)-[a-z0-9-]+ \}$
#   - Zero legacy 7-column-table rows (^| Dnnn |) may remain.
#   - Every `{ #<anchor> }` declared on a heading line MUST be unique within the file.
#
# Usage:
#   bash scripts/verify/decisions-shape-lint.sh [path]
#
# Default path: .orchestrator/DECISIONS.md (relative to CWD).
#
# Exit codes:
#   0 — file matches the heading-shape contract
#   1 — at least one violation (heading mismatch, legacy table row, duplicate anchor)
#   2 — argument or filesystem error (missing file, unreadable)
#
# Constraints:
#   - bash 3.2 + POSIX sh (MEM001).
#   - No process substitution `<(...)`, no `$()` containing pipes (AP-008/AP-009).
#   - Single-script-file shape per AD-19 (M037 architecture-decisions).

set -u

target="${1:-.orchestrator/DECISIONS.md}"

if [ ! -f "$target" ]; then
    printf 'FAIL: decisions-shape-lint: file not found: %s\n' "$target" >&2
    exit 2
fi

heading_count=0
legacy_count=0
fail_count=0
anchors_file="$(mktemp -t decisions-shape-lint-anchors.XXXXXX)"
trap 'rm -f "$anchors_file"' EXIT

lineno=0
while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))

    # Detect legacy 7-column-table rows (must be zero after migration).
    case "$line" in
        '| D'[0-9]*' |'*)
            printf 'FAIL: %s:%d: legacy 7-column-table row remains: %s\n' \
                "$target" "$lineno" "$line" >&2
            legacy_count=$((legacy_count + 1))
            fail_count=$((fail_count + 1))
            continue
            ;;
    esac

    # Only inspect ### headings.
    case "$line" in
        '### '*)
            heading_count=$((heading_count + 1))
            ;;
        *)
            continue
            ;;
    esac

    # Required shape: ### <text> { #<prefix>-<rest> }
    # Allowed prefixes: dr | bg | an | mem | q  (M037 authoring-conventions).
    if printf '%s\n' "$line" | grep -Eq '^### .+ \{ #(dr|bg|an|mem|q)-[a-z0-9-]+ \}$'; then
        # Extract anchor (text inside `{ #...  }`) for uniqueness check.
        anchor=$(printf '%s\n' "$line" | sed -n 's/^### .* { #\([a-z0-9-]\{1,\}\) }$/\1/p')
        if [ -n "$anchor" ]; then
            if grep -Fxq "$anchor" "$anchors_file"; then
                printf 'FAIL: %s:%d: duplicate anchor: #%s\n' \
                    "$target" "$lineno" "$anchor" >&2
                fail_count=$((fail_count + 1))
            else
                printf '%s\n' "$anchor" >> "$anchors_file"
            fi
        fi
    else
        printf 'FAIL: %s:%d: heading does not match required shape: %s\n' \
            "$target" "$lineno" "$line" >&2
        fail_count=$((fail_count + 1))
    fi
done < "$target"

if [ "$fail_count" -gt 0 ]; then
    printf 'FAIL: decisions-shape-lint %s (%d heading(s), %d violation(s), %d legacy row(s))\n' \
        "$target" "$heading_count" "$fail_count" "$legacy_count" >&2
    exit 1
fi

printf 'PASS: decisions-shape-lint %s (%d entries, all anchors unique)\n' \
    "$target" "$heading_count"
exit 0
