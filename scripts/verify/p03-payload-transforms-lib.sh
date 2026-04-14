#!/usr/bin/env bash
set -eu
f="scripts/lib/payload-transforms.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '_PAYLOAD_TRANSFORMS_SOURCED' "$f" || { echo "FAIL: double-sourcing guard missing"; exit 1; }
grep -q 'assemble_section' "$f" || { echo "FAIL: assemble_section missing"; exit 1; }
grep -q 'drop_by_priority' "$f" || { echo "FAIL: drop_by_priority missing"; exit 1; }
grep -q 'summarize_section' "$f" || { echo "FAIL: summarize_section missing"; exit 1; }
grep -q 'drop_lowest_confidence' "$f" || { echo "FAIL: drop_lowest_confidence missing"; exit 1; }
grep -q 'estimate_tokens' "$f" || { echo "FAIL: estimate_tokens missing"; exit 1; }
grep -q 'raw_token_count' "$f" || { echo "FAIL: raw_token_count missing"; exit 1; }
echo "PASS: payload-transforms.sh exists with guard and all functions"
