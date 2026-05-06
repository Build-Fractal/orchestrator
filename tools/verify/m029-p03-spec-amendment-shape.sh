#!/usr/bin/env bash
# tools/verify/m029-p03-spec-amendment-shape.sh -- M029 P03 spec amendment record shape verifier.
#
# Asserts the AD-4 spec amendment record entry is present in
# specs/037-roadmap-visibility-cli-ux/spec.md and carries every load-bearing
# token that downstream readers (acceptance scripts, future maintainers,
# release-notes generators) depend on.
#
# Load-bearing tokens (each asserted via a separate grep -F invocation per
# AD-19 straight-line discipline):
#   - `Spec Amendment Record`         -- canonical H2 section title
#   - `AD-4`                          -- the discuss-time decision identifier
#   - `summarize-milestone.sh`        -- the P02-owned oracle-wrapper input helper
#   - `predictive-surface.sh`         -- the M027 surface re-stated SC-8 invokes
#   - `cost_standard_usd`             -- the byte-identity contract field
#   - `--no-predict`                  -- the suppression-flag clarification
#   - `byte-identity`                 -- the byte-for-byte invariant phrasing
#
# Bash 3.2 / MEM001. AD-19 straight-line bash.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPEC="$PROJECT_ROOT/specs/037-roadmap-visibility-cli-ux/spec.md"

pass=0
fail=0

ok() {
    printf 'PASS: %s\n' "$1"
    pass=$((pass + 1))
}

bad() {
    printf 'FAIL: %s\n' "$1"
    fail=$((fail + 1))
}

# 1. Spec file exists.
if [ -f "$SPEC" ]; then
    ok "specs/037-roadmap-visibility-cli-ux/spec.md exists"
else
    bad "specs/037-roadmap-visibility-cli-ux/spec.md missing"
    printf 'SUMMARY: m029-p03-spec-amendment-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. Amendment-record H2 section title present.
if grep -F -q -e 'Spec Amendment Record' "$SPEC"; then
    ok "spec carries 'Spec Amendment Record' section title"
else
    bad "spec missing 'Spec Amendment Record' section title"
fi

# 3. AD-4 discuss-time decision id present.
if grep -F -q -e 'AD-4' "$SPEC"; then
    ok "spec carries AD-4 reference"
else
    bad "spec missing AD-4 reference"
fi

# 4. summarize-milestone.sh oracle-wrapper helper named.
if grep -F -q -e 'summarize-milestone.sh' "$SPEC"; then
    ok "spec names summarize-milestone.sh oracle-wrapper input helper"
else
    bad "spec missing summarize-milestone.sh reference"
fi

# 5. predictive-surface.sh M027 surface named.
if grep -F -q -e 'predictive-surface.sh' "$SPEC"; then
    ok "spec names predictive-surface.sh M027 surface"
else
    bad "spec missing predictive-surface.sh reference"
fi

# 6. cost_standard_usd byte-identity field present.
if grep -F -q -e 'cost_standard_usd' "$SPEC"; then
    ok "spec carries cost_standard_usd byte-identity field token"
else
    bad "spec missing cost_standard_usd token"
fi

# 7. --no-predict suppression-flag clarification present.
# Note: a literal hyphen-leading needle requires `-e` separator so grep does
# not parse the pattern as a flag. Do NOT add `--` after `-e`; on BSD grep
# the trailing `--` is parsed as a flag itself.
NEEDLE_NO_PREDICT='--no-predict'
if grep -F -q -e "$NEEDLE_NO_PREDICT" "$SPEC"; then
    ok "spec carries --no-predict suppression-flag clarification"
else
    bad "spec missing --no-predict clarification"
fi

# 8. byte-identity invariant phrasing present.
if grep -F -q -e 'byte-identity' "$SPEC"; then
    ok "spec carries byte-identity invariant phrasing"
else
    bad "spec missing byte-identity phrasing"
fi

printf 'SUMMARY: m029-p03-spec-amendment-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
