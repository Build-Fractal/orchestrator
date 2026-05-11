#!/usr/bin/env bash
# tools/verify/papercut-yaml-merge-list-replace.sh — papercut-sweep-post-M035 PC-7
#
# Asserts scripts/lib/yaml-merge.sh supports an opt-in --replace-list-keys
# flag that overrides the default operator-wins-byte-identical semantics at
# sub-key granularity inside managed top-level keys.
#
# Cases:
#   1. Back-compat: flag absent -> target's list_sub preserved byte-identical.
#   2. Replace: --replace-list-keys=list_sub -> framework's list_sub propagates.
#   3. Scalar sub-key under the same managed top-level remains operator-wins
#      (replace flag scoped to named sub-keys only).
#   4. Replace flag has NO effect on unmanaged top-level keys (operator-wins
#      at the top-level still holds; replace flag only acts inside a managed
#      block).
#   5. Empty --replace-list-keys value behaves identically to flag absent.
#
# Bash 3.2 / AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

MERGE="$PROJECT_ROOT/scripts/lib/yaml-merge.sh"
WORK="$(mktemp -d -t papercut-pc7.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT INT TERM

pass=0
fail=0

assert_eq() {
  case_label="$1"
  expected="$2"
  actual="$3"
  if [ "$expected" = "$actual" ]; then
    printf 'PASS: %s\n' "$case_label"
    pass=$((pass + 1))
  else
    printf 'FAIL: %s\n' "$case_label"
    printf '----- expected -----\n%s\n' "$expected" >&2
    printf '----- actual -----\n%s\n' "$actual" >&2
    fail=$((fail + 1))
  fi
}

# ---------- Fixture A: managed top-level with scalar + list sub-keys ----------
cat > "$WORK/fw-a.yml" <<'EOF'
managed_key:
  scalar_sub: framework_value
  list_sub:
    - fw_a
    - fw_b
unmanaged_top:
  list_sub:
    - fw_unmanaged
EOF

cat > "$WORK/tg-a.yml" <<'EOF'
managed_key:
  scalar_sub: operator_value
  list_sub:
    - op_x
    - op_y
unmanaged_top:
  list_sub:
    - op_unmanaged
EOF

# Case 1: back-compat (no --replace-list-keys)
expected_1='managed_key:
  scalar_sub: operator_value
  list_sub:
    - op_x
    - op_y
unmanaged_top:
  list_sub:
    - op_unmanaged'
actual_1="$(bash "$MERGE" merge \
  --target "$WORK/tg-a.yml" \
  --framework-default "$WORK/fw-a.yml" \
  --managed-namespaces managed_key \
  --dry-run)"
assert_eq "back-compat: flag absent -> operator's list_sub preserved" "$expected_1" "$actual_1"

# Case 2: --replace-list-keys=list_sub -> framework wins for list_sub only;
# scalar_sub still operator-wins.
expected_2='managed_key:
  scalar_sub: operator_value
  list_sub:
    - fw_a
    - fw_b
unmanaged_top:
  list_sub:
    - op_unmanaged'
actual_2="$(bash "$MERGE" merge \
  --target "$WORK/tg-a.yml" \
  --framework-default "$WORK/fw-a.yml" \
  --managed-namespaces managed_key \
  --replace-list-keys list_sub \
  --dry-run)"
assert_eq "replace: --replace-list-keys=list_sub -> framework's list propagates" "$expected_2" "$actual_2"

# Case 3: scalar sub-key remains operator-wins (already covered by case 2
# scalar_sub assertion, but verify explicitly that --replace-list-keys=scalar_sub
# can also force framework's scalar through).
expected_3='managed_key:
  scalar_sub: framework_value
  list_sub:
    - op_x
    - op_y
unmanaged_top:
  list_sub:
    - op_unmanaged'
actual_3="$(bash "$MERGE" merge \
  --target "$WORK/tg-a.yml" \
  --framework-default "$WORK/fw-a.yml" \
  --managed-namespaces managed_key \
  --replace-list-keys scalar_sub \
  --dry-run)"
assert_eq "replace: --replace-list-keys=scalar_sub -> framework scalar propagates" "$expected_3" "$actual_3"

# Case 4: --replace-list-keys naming an unmanaged top-level's sub-key has no
# effect (the flag only acts inside MANAGED blocks).
expected_4='managed_key:
  scalar_sub: operator_value
  list_sub:
    - op_x
    - op_y
unmanaged_top:
  list_sub:
    - op_unmanaged'
actual_4="$(bash "$MERGE" merge \
  --target "$WORK/tg-a.yml" \
  --framework-default "$WORK/fw-a.yml" \
  --managed-namespaces managed_key \
  --replace-list-keys list_sub_NEVER_MATCHES \
  --dry-run)"
assert_eq "no-match: unknown sub-key name in replace list is no-op" "$expected_4" "$actual_4"

# Case 5: --replace-list-keys with EMPTY value matches case 1 (back-compat).
actual_5="$(bash "$MERGE" merge \
  --target "$WORK/tg-a.yml" \
  --framework-default "$WORK/fw-a.yml" \
  --managed-namespaces managed_key \
  --replace-list-keys "" \
  --dry-run)"
assert_eq "empty-flag: --replace-list-keys='' matches flag-absent" "$expected_1" "$actual_5"

# Case 6: --replace-list-keys with sub-key under UNMANAGED top-level - flag
# is bounded by the managed-namespaces wrapper. Verify operator's unmanaged
# block stays byte-identical even if a sub-key name in it matches the flag.
expected_6='managed_key:
  scalar_sub: operator_value
  list_sub:
    - fw_a
    - fw_b
unmanaged_top:
  list_sub:
    - op_unmanaged'
actual_6="$(bash "$MERGE" merge \
  --target "$WORK/tg-a.yml" \
  --framework-default "$WORK/fw-a.yml" \
  --managed-namespaces managed_key \
  --replace-list-keys list_sub \
  --dry-run)"
assert_eq "scope: flag does not bleed into unmanaged top-level block" "$expected_6" "$actual_6"

printf 'BATTERY: pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
