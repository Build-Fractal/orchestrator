#!/usr/bin/env bash
# scripts/verify/m024-p01-proposal-emit.sh
# End-to-end emit: invoke against a paragraph and verify the resulting file
# contains all six axes + complete frontmatter.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"

if [ ! -x "$EMIT" ]; then
  echo "FAIL: $EMIT not executable"
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

paragraph="We should add a last seen timestamp to the status command output and cache it for about five seconds so repeated calls do not hammer the filesystem."

out=$(bash "$EMIT" --input "$paragraph" --intake-root "$tmp/intake" || echo "ERR")
proposal_path=$(echo "$out" | sed -n 's/^proposal_path=//p')
if [ -z "$proposal_path" ] || [ ! -f "$proposal_path" ]; then
  echo "FAIL: emitter did not produce a file (out: $out)"
  exit 1
fi

REQUIRED="schema_version type intake_id created_at input_shape input_hash shape_classification scope_tier decomposition design_gate conversus_gate intensity recommended_command auto_proceeded proceeded_at approved_at cancelled_at pending_approval design_skipped design_authored_manually qa_short_circuited low_confidence"

missing=""
for k in $REQUIRED; do
  if ! grep -q "^${k}:" "$proposal_path"; then
    missing="$missing $k"
  fi
done

# Six axis section headings.
for h in "Axis 1 — Input Shape" "Axis 2 — Scope Tier" "Axis 3 — Decomposition" "Axis 4 — Design Gate" "Axis 5 — Conversus Gate" "Axis 6 — Intensity"; do
  if ! grep -qF "$h" "$proposal_path"; then
    missing="$missing heading:$h"
  fi
done

# No unsubstituted placeholders.
if grep -q '{{[a-z_]*}}' "$proposal_path"; then
  missing="$missing unsubstituted-placeholders"
fi

if [ -n "$missing" ]; then
  echo "FAIL: proposal at $proposal_path missing —$missing"
  exit 1
fi

echo "PASS: proposal-emit.sh — frontmatter + six axis sections + no unsubstituted placeholders"
exit 0
