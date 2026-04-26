#!/usr/bin/env bash
# scripts/verify/m024-p07-design-gate-classify.sh
# Verifies the design-gate classifier rule table.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLF="$ROOT/scripts/intake/design-gate-classify.sh"

[ -x "$CLF" ] || { echo "FAIL: $CLF not executable"; exit 1; }

# Case 1 — UI redesign paragraph (3 tokens: redesign matches "design", "ui", "viewer") -> walkthrough+high
out=$(bash "$CLF" --input "We should redesign the proposal viewer with split panes and a live diff layout")
echo "$out" | grep -qx "design_gate=walkthrough" || { echo "FAIL: case 1 design_gate (got: $out)"; exit 1; }
echo "$out" | grep -qx "design_gate_confidence=high" || { echo "FAIL: case 1 confidence high (got: $out)"; exit 1; }

# Case 2 — Backend script paragraph -> none+high
out=$(bash "$CLF" --input "Cache the result of orchestrator:status for five seconds and add a no-cache flag")
echo "$out" | grep -qx "design_gate=none" || { echo "FAIL: case 2 design_gate=none (got: $out)"; exit 1; }
echo "$out" | grep -qx "design_gate_confidence=high" || { echo "FAIL: case 2 confidence high (got: $out)"; exit 1; }

# Case 3 — Single-token short input -> walkthrough+low
out=$(bash "$CLF" --input "tweak the screen")
echo "$out" | grep -qx "design_gate=walkthrough" || { echo "FAIL: case 3 walkthrough (got: $out)"; exit 1; }
echo "$out" | grep -qx "design_gate_confidence=low" || { echo "FAIL: case 3 low (got: $out)"; exit 1; }

# Case 4 — Substring 'serendipity' (contains 'design' substring? no — but matches 'pity'? no) -> none
out=$(bash "$CLF" --input "serendipity strikes when the moon aligns with caching policy")
echo "$out" | grep -qx "design_gate=none" || { echo "FAIL: case 4 substring should not trigger (got: $out)"; exit 1; }

# Case 5 — Spec-path mode on a UI-tagged synthetic spec.
tmp_spec=$(mktemp)
trap 'rm -f "$tmp_spec"' EXIT
cat >"$tmp_spec" <<'SPEC'
# Feature Spec: Dashboard layout

We need a new dashboard with a split-pane viewer and theme support.
SPEC
out=$(bash "$CLF" --spec-path "$tmp_spec")
echo "$out" | grep -qx "design_gate=walkthrough" || { echo "FAIL: case 5 spec-path walkthrough (got: $out)"; exit 1; }

# Case 6 — Missing spec exits 1.
if bash "$CLF" --spec-path /nonexistent/path/spec.md >/dev/null 2>&1; then
  echo "FAIL: missing spec should exit non-zero"
  exit 1
fi

# Case 7 — Both --input and --spec-path supplied -> exit 2.
if bash "$CLF" --input "x" --spec-path "$tmp_spec" >/dev/null 2>&1; then
  echo "FAIL: both --input and --spec-path should exit 2"
  exit 1
fi

# Case 8 — Neither supplied -> exit 2.
if bash "$CLF" >/dev/null 2>&1; then
  echo "FAIL: missing args should exit 2"
  exit 1
fi

# Case 9 — Stdout shape: exactly two lines, no extra noise.
out=$(bash "$CLF" --input "redesign the dashboard")
line_count=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
[ "$line_count" = "2" ] || { echo "FAIL: stdout should be exactly 2 lines (got: $line_count lines)"; exit 1; }

echo "PASS: design-gate-classify — token table covers UI tokens; substring matches rejected; usage validation works"
exit 0
