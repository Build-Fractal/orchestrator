#!/usr/bin/env bash
# tools/verify/papercut-decisions-dual-shape.sh — papercut-sweep-post-M035 PC-2
#
# Asserts scripts/knowledge/append-decision.sh's highest-D###-id scanner
# recognizes all three DECISIONS.md row shapes:
#
#   1. Table-row shape:      `| D### | ... |`
#   2. Heading shape:        `### D### — title`
#   3. Anchor heading shape: `### D### — title { #dr-code-NNN }`
#
# Plus: D-RN-N anchor cohort lines (which use a different anchor namespace)
# must NOT be treated as part of the D### numeric sequence.
#
# Bash 3.2 / AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

APPEND="$PROJECT_ROOT/scripts/knowledge/append-decision.sh"
pass=0
fail=0
TMP_PFX="/tmp/papercut-pc2-$$"

# Helper: write a synthetic DECISIONS.md and assert next-id.
assert_next_id() {
  case_label="$1"
  body_path="$2"
  expected_next="$3"
  out="$($APPEND "$body_path" "M999/P99/T99" "test" "test" "test" "test" 2>&1)" || true
  appended_id="$(echo "$out" | sed -nE 's/^DECISION: (D[0-9]+) appended$/\1/p')"
  if [ "$appended_id" = "$expected_next" ]; then
    printf 'PASS: %s -> next=%s\n' "$case_label" "$appended_id"
    pass=$((pass + 1))
  else
    printf 'FAIL: %s -> next=%s (expected %s)\n' "$case_label" "$appended_id" "$expected_next"
    printf '----- output -----\n%s\n' "$out" >&2
    fail=$((fail + 1))
  fi
}

# Case A — table-row shape only, highest=D003 -> next=D004
fA="${TMP_PFX}-tableA.md"
cat > "$fA" <<'EOF'
# DECISIONS

| # | When | Scope | Decision | Choice | Rationale | Revisable? |
|---|------|-------|----------|--------|-----------|------------|
| D001 | M001/P01 | arch | foo | bar | baz | Yes |
| D002 | M001/P02 | arch | foo | bar | baz | Yes |
| D003 | M001/P03 | arch | foo | bar | baz | Yes |
EOF
assert_next_id "table-row only (max D003)" "$fA" "D004"

# Case B — heading-shape only, highest=D014 -> next=D015
fB="${TMP_PFX}-headingB.md"
cat > "$fB" <<'EOF'
# DECISIONS

### D004 — first decision

text

### D012 — middle decision

text

### D014 — latest decision

text
EOF
assert_next_id "heading-shape only (max D014)" "$fB" "D015"

# Case C — anchor heading shape only, highest=D029 -> next=D030
# (this also exercises D-RN-N being IGNORED — the cohort uses dr-code-NNN
# anchors with D-RN-N labels, not D### labels.)
fC="${TMP_PFX}-anchorC.md"
cat > "$fC" <<'EOF'
# DECISIONS

### D029 — anchor decision { #dr-code-029 }

text

### D-RN-1 — namespaced rename decision { #dr-code-029 }

text — D-RN labels are NOT counted as part of the D### sequence.
EOF
assert_next_id "anchor heading + D-RN ignored (max D029)" "$fC" "D030"

# Case D — mixed all three shapes, highest=D029 -> next=D030
fD="${TMP_PFX}-mixedD.md"
cat > "$fD" <<'EOF'
# DECISIONS

| # | When | Scope | Decision | Choice | Rationale | Revisable? |
|---|------|-------|----------|--------|-----------|------------|
| D001 | M001/P01 | arch | foo | bar | baz | Yes |
| D003 | M001/P03 | arch | foo | bar | baz | Yes |

### D014 — heading decision

text

### D029 — anchor decision { #dr-code-029 }

text
EOF
assert_next_id "mixed (table+heading+anchor, max D029)" "$fD" "D030"

# Case E — empty file (no D###), next=D001
fE="${TMP_PFX}-emptyE.md"
cat > "$fE" <<'EOF'
# DECISIONS
EOF
assert_next_id "empty (no D###)" "$fE" "D001"

# Cleanup
rm -f "${TMP_PFX}"-*.md

printf 'BATTERY: pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
