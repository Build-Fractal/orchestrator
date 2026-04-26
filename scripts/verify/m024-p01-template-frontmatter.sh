#!/usr/bin/env bash
# scripts/verify/m024-p01-template-frontmatter.sh
# Asserts templates/intake-proposal.md exists and contains every required frontmatter key + axis section heading.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE="$ROOT/templates/intake-proposal.md"

if [ ! -f "$TEMPLATE" ]; then
  echo "FAIL: $TEMPLATE not found"
  exit 1
fi

REQUIRED_KEYS="schema_version type feature_slug intake_id milestone status created_at input_shape input_hash shape_classification supplemental_input scope_tier decomposition design_gate conversus_gate intensity recommended_command auto_proceeded proceeded_at approved_at cancelled_at pending_approval design_skipped design_authored_manually qa_short_circuited low_confidence"

missing=""
for key in $REQUIRED_KEYS; do
  if ! grep -q "^${key}:" "$TEMPLATE"; then
    missing="$missing $key"
  fi
done

REQUIRED_HEADINGS="Axis_1_—_Input_Shape Axis_2_—_Scope_Tier Axis_3_—_Decomposition Axis_4_—_Design_Gate Axis_5_—_Conversus_Gate Axis_6_—_Intensity"

for h in $REQUIRED_HEADINGS; do
  pretty=$(echo "$h" | tr '_' ' ')
  if ! grep -qF "$pretty" "$TEMPLATE"; then
    missing="$missing heading:$h"
  fi
done

if [ -n "$missing" ]; then
  echo "FAIL: missing in $TEMPLATE —$missing"
  exit 1
fi

echo "PASS: templates/intake-proposal.md frontmatter + axis sections complete"
exit 0
