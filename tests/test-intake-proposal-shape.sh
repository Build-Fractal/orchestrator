#!/usr/bin/env bash
# tests/test-intake-proposal-shape.sh — SC-7 frontmatter-completeness for M024/P01.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"

pass_count=0
fail_count=0
fail_messages=""
pass() { pass_count=$((pass_count + 1)); }
fail() { fail_count=$((fail_count + 1)); fail_messages="$fail_messages
  - $1"; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

REQUIRED_KEYS="schema_version type intake_id created_at input_shape input_hash shape_classification scope_tier decomposition design_gate conversus_gate intensity recommended_command auto_proceeded proceeded_at approved_at cancelled_at pending_approval design_skipped design_authored_manually qa_short_circuited low_confidence feature_slug milestone status"
REQUIRED_HEADINGS="Axis_1_Input_Shape Axis_2_Scope_Tier Axis_3_Decomposition Axis_4_Design_Gate Axis_5_Conversus_Gate Axis_6_Intensity"

check_one() {
  local label="$1"; local out="$2"; local path
  path=$(echo "$out" | sed -n 's/^proposal_path=//p')
  if [ -z "$path" ] || [ ! -f "$path" ]; then
    fail "$label: emitter did not produce a file (out=$out)"
    return
  fi
  for k in $REQUIRED_KEYS; do
    if ! grep -q "^${k}:" "$path"; then
      fail "$label: missing frontmatter key '$k'"; return
    fi
  done
  for h in $REQUIRED_HEADINGS; do
    # Convert e.g. Axis_1_Input_Shape → "Axis 1 — Input Shape".
    pretty=$(echo "$h" | sed -E 's/^Axis_([0-9]+)_(.*)$/Axis \1 — \2/' | tr '_' ' ')
    if ! grep -qF "$pretty" "$path"; then
      fail "$label: missing axis heading '$pretty'"; return
    fi
  done
  if grep -q '{{[a-z_]*}}' "$path"; then
    fail "$label: unsubstituted placeholders remain in $path"; return
  fi
  pass
}

# Case A — paragraph.
out_a=$(bash "$EMIT" --input "We should add a last seen timestamp to the status command output and cache it briefly so repeated calls do not hammer the filesystem." --intake-root "$tmp/a")
check_one "paragraph" "$out_a"

# Case B — idea.
out_b=$(bash "$EMIT" --input "fix typo in status doc" --intake-root "$tmp/b")
check_one "idea" "$out_b"

# Case C — spec-path. Use this milestone's own spec.
out_c=$(bash "$EMIT" --spec-path "$ROOT/specs/028-universal-intake-routing/spec.md" --intake-root "$tmp/c")
check_one "spec-path" "$out_c"

if [ "$fail_count" -gt 0 ]; then
  echo "FAIL: $fail_count case(s):$fail_messages"
  echo "(passed: $pass_count)"
  exit 1
fi

echo "PASS: test-intake-proposal-shape.sh — paragraph, idea, spec-path ($pass_count cases)"
exit 0
