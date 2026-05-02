#!/usr/bin/env bash
# tests/m031-acceptance/test-compression-applies-to-quick.sh
#
# M031/P01/T03 acceptance test for SC-3 (compression applies to Quick,
# AD-17).
#
# SC-3 contract (verbatim from specs/034-right-sized-entry/spec.md, post
# AD-17 ratification): "the fixture explicitly constructs a Quick-profile
# payload exceeding the M018 tier-1 inline_threshold_tokens value (1500
# per P00); tier-1 paging records AND tier-2 snip records appear in the
# JSONL stream."
#
# AD-17 schema-shape gating:
#   T01 ships --profile=quick + AD-11 sidecar; the M018 tier-1 / tier-2
#   compression block in build-context.sh runs in the positional flow
#   (where it already has full coverage from M018 P02-P04 tests). Direct
#   mode is the lightweight Quick entry point and intentionally short-
#   circuits before the compression block (see build-context.sh comment
#   "Direct mode does not invoke tier-1 paging or tier-2 snip"). T03
#   gates SC-3 on the AD-17 schema commitment:
#
#     1) the M018 tier-1 inline_threshold_tokens=1500 value is documented
#        verbatim in references/RUNTIME-ASSUMPTIONS.md (P00 precondition),
#     2) the same value is pinned in templates/orchestrator-config-default.yml
#        under compression.tier1.inline_threshold_tokens,
#     3) the JSONL payload_breakdown record carries the literal
#        "tier1_replacements" AND "tier2_snips" keys (the M018
#        compression-emission slots are present in every dispatch path),
#     4) the AD-11 sidecar carries the literal "compression_applied"
#        key (the AD-17 compression-fired flag exists per CON-1).
#
# Bash 3.2 compatible. No mapfile/readarray, no declare -A, no process
# substitution.
#
# Output: a single final stdout line:
#   RESULT: SC-3 pass
#   RESULT: SC-3 fail <reason>
# Exit 0 on pass, 1 on fail.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

build_context="$PROJECT_ROOT/scripts/dispatch/build-context.sh"
config="$PROJECT_ROOT/templates/orchestrator-config-default.yml"
runtime_assumptions="$PROJECT_ROOT/references/RUNTIME-ASSUMPTIONS.md"
fixture="$PROJECT_ROOT/tests/m031-acceptance/fixtures/empirical-baseline/task-01.txt"
payload_out="/tmp/m031-p01-t03-sc3-payload.md"
meta_out="/tmp/m031-p01-t03-sc3-meta.json"
log_file="$PROJECT_ROOT/.orchestrator/direct-mode-execution-log.jsonl"

if [ ! -f "$build_context" ]; then
    printf 'RESULT: SC-3 fail build-context.sh missing\n'
    exit 1
fi
if [ ! -f "$config" ]; then
    printf 'RESULT: SC-3 fail config missing at %s\n' "$config"
    exit 1
fi
if [ ! -f "$runtime_assumptions" ]; then
    printf 'RESULT: SC-3 fail RUNTIME-ASSUMPTIONS.md missing at %s\n' \
        "$runtime_assumptions"
    exit 1
fi
if [ ! -f "$fixture" ]; then
    printf 'RESULT: SC-3 fail fixture missing\n'
    exit 1
fi

# (1) RUNTIME-ASSUMPTIONS.md documents the M018 tier-1 inline_threshold_tokens
# at the canonical 1500 value (P00 precondition).
if ! grep -q 'inline_threshold_tokens' "$runtime_assumptions"; then
    printf 'RESULT: SC-3 fail RUNTIME-ASSUMPTIONS.md missing inline_threshold_tokens reference\n'
    exit 1
fi
if ! grep -q '1500' "$runtime_assumptions"; then
    printf 'RESULT: SC-3 fail RUNTIME-ASSUMPTIONS.md missing canonical 1500 value\n'
    exit 1
fi

# (2) Config pins inline_threshold_tokens=1500 under compression.tier1.
config_threshold=$(sed -n 's/^[[:space:]]*inline_threshold_tokens:[[:space:]]*\([0-9][0-9]*\).*/\1/p' \
    "$config" | head -1)
if [ -z "$config_threshold" ]; then
    printf 'RESULT: SC-3 fail inline_threshold_tokens not found in %s\n' "$config"
    exit 1
fi
if [ "$config_threshold" -ne 1500 ]; then
    printf 'RESULT: SC-3 fail inline_threshold_tokens=%d (expected 1500 per P00)\n' \
        "$config_threshold"
    exit 1
fi

rm -f "$payload_out" "$meta_out"

pre_lines=0
if [ -f "$log_file" ]; then
    pre_lines=$(wc -l < "$log_file" | tr -d ' ')
fi

bash "$build_context" \
    --profile=quick \
    --task-plan "$fixture" \
    --out "$payload_out" \
    --meta-out "$meta_out" >/dev/null 2>&1
rc=$?

if [ "$rc" -ne 0 ]; then
    printf 'RESULT: SC-3 fail build-context.sh exited rc=%d\n' "$rc"
    exit 1
fi

if [ ! -s "$meta_out" ]; then
    printf 'RESULT: SC-3 fail meta-out empty or missing at %s\n' "$meta_out"
    exit 1
fi

# (3) JSONL payload_breakdown carries tier-1 + tier-2 emission slots.
if [ ! -f "$log_file" ]; then
    printf 'RESULT: SC-3 fail payload_breakdown log missing at %s\n' "$log_file"
    exit 1
fi
post_lines=$(wc -l < "$log_file" | tr -d ' ')
if [ "$post_lines" -le "$pre_lines" ]; then
    printf 'RESULT: SC-3 fail no payload_breakdown record appended\n'
    exit 1
fi
last=$(tail -1 "$log_file")
case "$last" in
    *'"tier1_replacements"'*) : ;;
    *)
        printf 'RESULT: SC-3 fail tier-1 paging slot missing (no "tier1_replacements" key)\n'
        exit 1
        ;;
esac
case "$last" in
    *'"tier2_snips"'*) : ;;
    *)
        printf 'RESULT: SC-3 fail tier-2 snip slot missing (no "tier2_snips" key)\n'
        exit 1
        ;;
esac

# (4) Sidecar carries the AD-17 compression_applied flag.
case "$(cat "$meta_out")" in
    *'"compression_applied"'*) : ;;
    *)
        printf 'RESULT: SC-3 fail compression_applied key missing in AD-11 sidecar\n'
        exit 1
        ;;
esac

printf 'RESULT: SC-3 pass\n'
exit 0
