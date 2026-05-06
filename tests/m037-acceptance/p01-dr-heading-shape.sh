#!/usr/bin/env bash
# p01-dr-heading-shape.sh — M037/P01 acceptance test for the DR-### heading-shape
# pivot of `.orchestrator/DECISIONS.md` (SC-3 from spec 038).
#
# Two checks:
#   1. The framework-owned shape-lint verifier passes against this repo's
#      DECISIONS.md (no legacy table rows, every heading matches the
#      `^### .+ \{ #(dr|bg|an|mem|q)-[a-z0-9-]+ \}$` regex, anchors unique).
#   2. Every inbound `#dr-code-NNN` (or `#dNNN`-shape, if any survived rewrite)
#      permalink reference cited from a Markdown file outside
#      `.orchestrator/milestones/M037/` resolves to a `{ #<anchor> }`
#      declaration in DECISIONS.md.
#
# Constraints:
#   - bash 3.2 + POSIX sh (MEM001).
#   - No process substitution, no `$()` with pipes (AP-008/AP-009).
#   - Min 20 lines per the T03 plan.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DECISIONS_PATH="$REPO_ROOT/.orchestrator/DECISIONS.md"
VERIFIER="$REPO_ROOT/scripts/verify/decisions-shape-lint.sh"

# Step 1: shape-lint must pass.
if ! bash "$VERIFIER" "$DECISIONS_PATH"; then
    printf 'FAIL: p01-dr-heading-shape: decisions-shape-lint returned non-zero\n' >&2
    exit 1
fi

# Step 2: extract every declared anchor from DECISIONS.md headings.
anchors_file="$(mktemp -t p01-dr-heading-shape-anchors.XXXXXX)"
inbound_file="$(mktemp -t p01-dr-heading-shape-inbound.XXXXXX)"
trap 'rm -f "$anchors_file" "$inbound_file"' EXIT

grep -E '^### .+ \{ #[a-z0-9-]+ \}$' "$DECISIONS_PATH" \
    | sed -n 's/^### .* { #\([a-z0-9-]\{1,\}\) }$/\1/p' \
    > "$anchors_file"

declared_count=$(wc -l < "$anchors_file" | tr -d ' ')

# Step 3: scan inbound permalink references across the repo.
# Look for both legacy `#dNNN` (lowercase) and new `#dr-code-NNN` shapes
# inside markdown files, excluding anything under .orchestrator/milestones/M037/
# (own-task plans cite the shapes for documentation, not as live permalinks).
inbound_resolved=0
inbound_broken=0

# Use grep -RnE; pipe through grep -v for the M037 exclusion.
# Two-stage chain (grep | grep) is permitted; no $() inside.
grep -RnE '#dr-code-[0-9]+|#d[0-9]+\b' \
    --include='*.md' \
    "$REPO_ROOT" 2>/dev/null \
    | grep -v '/.orchestrator/milestones/M037/' \
    | grep -v '/.orchestrator/DECISIONS.md:' \
    > "$inbound_file" || true

while IFS= read -r match_line; do
    [ -z "$match_line" ] && continue
    # match_line shape: <file>:<lineno>:<line-content>
    # Extract every anchor token in the line content.
    file_part=$(printf '%s\n' "$match_line" | sed 's/:[0-9][0-9]*:.*$//')
    rest=$(printf '%s\n' "$match_line" | sed 's/^[^:]*:\([0-9][0-9]*\):/\1__SEP__/')
    line_no=$(printf '%s\n' "$rest" | sed 's/__SEP__.*$//')
    body=$(printf '%s\n' "$rest" | sed 's/^[0-9][0-9]*__SEP__//')

    # Pull every #anchor token of either shape from the body.
    tokens=$(printf '%s\n' "$body" | grep -oE '#dr-code-[0-9]+|#d[0-9]+\b' || true)

    for tok in $tokens; do
        # Normalize legacy `#d001` -> `dr-code-001` for lookup; new shape strips `#`.
        case "$tok" in
            '#dr-code-'*)
                anchor="${tok#\#}"
                ;;
            '#d'*)
                num="${tok#\#d}"
                # Zero-pad to 3 digits.
                while [ "${#num}" -lt 3 ]; do
                    num="0$num"
                done
                anchor="dr-code-$num"
                ;;
            *)
                continue
                ;;
        esac

        if grep -Fxq "$anchor" "$anchors_file"; then
            inbound_resolved=$((inbound_resolved + 1))
        else
            printf 'FAIL: broken inbound permalink %s:%s -> #%s\n' \
                "$file_part" "$line_no" "$anchor" >&2
            inbound_broken=$((inbound_broken + 1))
        fi
    done
done < "$inbound_file"

if [ "$inbound_broken" -gt 0 ]; then
    printf 'FAIL: p01-dr-heading-shape (%d entries declared, %d inbound broken)\n' \
        "$declared_count" "$inbound_broken" >&2
    exit 1
fi

printf 'PASS: p01-dr-heading-shape (%d entries, %d inbound permalinks resolved)\n' \
    "$declared_count" "$inbound_resolved"
exit 0
