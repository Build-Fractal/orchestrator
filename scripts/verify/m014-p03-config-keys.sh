#!/usr/bin/env bash
# scripts/verify/m014-p03-config-keys.sh
# Gate: M014/P03/T05 — .orchestrator/config.yml carries the comments: section
# with auto_apply_threshold (per-class scalars), reply_on_apply, fetch_schedule.
# AD-19 single-script-file shape; CON-6 / MEM001 Bash 3.2.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG="${PROJECT_ROOT}/.orchestrator/config.yml"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$CONFIG" ] || fail "config.yml missing at $CONFIG"

# Top-level comments: parent.
grep -qE '^comments:[[:space:]]*$' "$CONFIG" \
  || fail "comments: top-level section missing"

# Required sub-keys (any indented depth under the comments: parent).
grep -qE '^[[:space:]]+auto_apply_threshold:' "$CONFIG" \
  || fail "comments.auto_apply_threshold key missing"
grep -qE '^[[:space:]]+reply_on_apply:' "$CONFIG" \
  || fail "comments.reply_on_apply key missing"
grep -qE '^[[:space:]]+fetch_schedule:' "$CONFIG" \
  || fail "comments.fetch_schedule key missing"

# Per-class scalars under auto_apply_threshold.
grep -qE '^[[:space:]]+uat-bug:[[:space:]]*[0-9.]+' "$CONFIG" \
  || fail "comments.auto_apply_threshold.uat-bug scalar missing"
grep -qE '^[[:space:]]+decision-append:[[:space:]]*[0-9.]+' "$CONFIG" \
  || fail "comments.auto_apply_threshold.decision-append scalar missing"
grep -qE '^[[:space:]]+spec-amendment:[[:space:]]*[0-9.]+' "$CONFIG" \
  || fail "comments.auto_apply_threshold.spec-amendment scalar missing"
grep -qE '^[[:space:]]+ambiguous:[[:space:]]*[0-9.]+' "$CONFIG" \
  || fail "comments.auto_apply_threshold.ambiguous scalar missing"

# CON-5/SC-5 invariant — spec-amendment threshold pinned at 1.0.
grep -qE '^[[:space:]]+spec-amendment:[[:space:]]*1\.0' "$CONFIG" \
  || fail "comments.auto_apply_threshold.spec-amendment must be 1.0 (CON-5/SC-5)"

# reply_on_apply default false; fetch_schedule default manual.
grep -qE '^[[:space:]]+reply_on_apply:[[:space:]]*false' "$CONFIG" \
  || fail "comments.reply_on_apply must default false (OQ #C-8)"
grep -qE '^[[:space:]]+fetch_schedule:[[:space:]]*manual' "$CONFIG" \
  || fail "comments.fetch_schedule must default manual (OQ #C-2)"

echo "PASS: $(basename "$0")"
exit 0
