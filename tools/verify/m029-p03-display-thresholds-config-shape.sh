#!/usr/bin/env bash
# tools/verify/m029-p03-display-thresholds-config-shape.sh -- M029 P03 / T01
# display_thresholds config-block shape gate verifier.
#
# Asserts the AD-5 `display_thresholds:` block is wired across the three
# config surfaces:
#   - templates/orchestrator-config-default.yml carries the new top-level
#     block with `compression_savings_pct: 5.0` and the AD-5 / FR-8 review-
#     trigger annotation
#   - references/file-formats.md documents the block under
#     `## Configuration (orchestrator-config.yml)` with the AD-5 rationale
#     and the canonical compact-form `▽ saved Nk` cross-reference
#   - scripts/state/read-config.sh's VALID_KEYS string contains the dotted
#     form `display_thresholds.compression_savings_pct`
#
# Bash 3.2 compatible (MEM001). AD-19 single-script-file shape: straight-
# line bash, no inline compound chains, no plain subshells, no $() with
# pipes -- the verifier code itself does not use the MEM004 carve-out.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
TEMPLATE="$PROJECT_ROOT/templates/orchestrator-config-default.yml"
REFDOC="$PROJECT_ROOT/references/file-formats.md"
RDC="$PROJECT_ROOT/scripts/state/read-config.sh"

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

# 1. Template file exists.
if [ -f "$TEMPLATE" ]; then
    check "templates/orchestrator-config-default.yml exists" 0
else
    check "templates/orchestrator-config-default.yml exists" 1
fi

# 2. Template carries the top-level block at line start.
if grep -n -E '^display_thresholds:' "$TEMPLATE" >/dev/null 2>&1; then
    check "template top-level display_thresholds: block present" 0
else
    check "template top-level display_thresholds: block present" 1
fi

# 3. Template carries the canonical compression_savings_pct: 5.0 line.
if grep -F -q -- 'compression_savings_pct: 5.0' "$TEMPLATE"; then
    check "template compression_savings_pct: 5.0 line byte-stable" 0
else
    check "template compression_savings_pct: 5.0 line byte-stable" 1
fi

# 4. Template references AD-5 in the heuristic-default annotation.
if grep -F -q -- 'AD-5' "$TEMPLATE"; then
    check "template AD-5 annotation present" 0
else
    check "template AD-5 annotation present" 1
fi

# 5. Template references FR-8 in the heuristic-default annotation.
if grep -F -q -- 'FR-8' "$TEMPLATE"; then
    check "template FR-8 annotation present" 0
else
    check "template FR-8 annotation present" 1
fi

# 6. Template carries the review-trigger phrasing verbatim.
if grep -F -q -- 'Tune after first 10 milestones' "$TEMPLATE"; then
    check "template review-trigger phrasing 'Tune after first 10 milestones' present" 0
else
    check "template review-trigger phrasing 'Tune after first 10 milestones' present" 1
fi

# 7. references/file-formats.md exists.
if [ -f "$REFDOC" ]; then
    check "references/file-formats.md exists" 0
else
    check "references/file-formats.md exists" 1
fi

# 8. file-formats.md documents the block.
if grep -F -q -- 'display_thresholds:' "$REFDOC"; then
    check "file-formats.md documents display_thresholds: block" 0
else
    check "file-formats.md documents display_thresholds: block" 1
fi

# 9. file-formats.md names the dotted-form key.
if grep -F -q -- 'compression_savings_pct' "$REFDOC"; then
    check "file-formats.md names compression_savings_pct key" 0
else
    check "file-formats.md names compression_savings_pct key" 1
fi

# 10. file-formats.md cites AD-5 as the authoring decision.
if grep -F -q -- 'AD-5' "$REFDOC"; then
    check "file-formats.md cites AD-5" 0
else
    check "file-formats.md cites AD-5" 1
fi

# 11. file-formats.md carries the review-trigger phrasing verbatim.
if grep -F -q -- 'Tune after first 10 milestones' "$REFDOC"; then
    check "file-formats.md review-trigger 'Tune after first 10 milestones' present" 0
else
    check "file-formats.md review-trigger 'Tune after first 10 milestones' present" 1
fi

# 12. file-formats.md cross-references the canonical compact-form marker.
if grep -F -q -- '▽ saved Nk' "$REFDOC"; then
    check "file-formats.md cross-references canonical ▽ saved Nk marker" 0
else
    check "file-formats.md cross-references canonical ▽ saved Nk marker" 1
fi

# 13. read-config.sh exists.
if [ -f "$RDC" ]; then
    check "scripts/state/read-config.sh exists" 0
else
    check "scripts/state/read-config.sh exists" 1
fi

# 14. read-config.sh's VALID_KEYS string contains the dotted form.
if grep -F -q -- 'display_thresholds.compression_savings_pct' "$RDC"; then
    check "read-config.sh VALID_KEYS includes display_thresholds.compression_savings_pct" 0
else
    check "read-config.sh VALID_KEYS includes display_thresholds.compression_savings_pct" 1
fi

printf 'SUMMARY: m029-p03-display-thresholds-config-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
