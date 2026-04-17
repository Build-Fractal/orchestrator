#!/usr/bin/env bash
# scripts/verify/m021-p02-linter-scope.sh — Gate for anti-pattern-lint.sh
# scope-boundary enforcement and <!-- agent-facing --> marker opt-in.
#
# Asserts:
#   - A specs-style fixture WITHOUT the marker is NOT flagged when present
#     inside a simulated specs/ root during the linter's default sweep.
#   - The same fixture WITH the marker IS flagged in the default sweep.
#   - The live repo's specs/, references/, docs/ trees — none of which should
#     carry the marker today — produce zero new violations under the current
#     linter (baseline preservation).
#   - references/engine.md documents the <!-- agent-facing --> convention.
#
# Exit: 0 on all assertions pass, 1 otherwise.
# Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINTER="${REPO_ROOT}/scripts/verify/anti-pattern-lint.sh"
FIX_DIR="${REPO_ROOT}/tests/fixtures/m021-p02"
ENGINE_DOC="${REPO_ROOT}/references/engine.md"

fail_count=0
_tmp=""

cleanup() {
  if [ -n "$_tmp" ] && [ -d "$_tmp" ]; then
    rm -rf "$_tmp"
  fi
}
trap cleanup EXIT

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; fail_count=$((fail_count + 1)); }

# --- Assertion 1: fixture content is Class A when scanned via --fixture.
out="$(bash "$LINTER" --fixture "$FIX_DIR/scope-excluded-spec.md" 2>&1 || true)"
if printf '%s' "$out" | grep -q '\[AP-004\]'; then
  pass "fixture content is Class A when scanned via --fixture"
else
  fail "fixture content failed to trip Class A via --fixture"
fi

# --- Assertion 2: scope-excluded fixture is NOT picked up by the default
#     sweep because tests/fixtures/ is not in the default scan roots AND
#     there is no marker.
out="$(bash "$LINTER" 2>&1 || true)"
if printf '%s' "$out" | grep -q 'scope-excluded-spec.md'; then
  fail "default sweep unexpectedly picked up scope-excluded-spec.md"
else
  pass "default sweep correctly skips tests/fixtures/ (unmarked)"
fi

# --- Assertion 3: marker-gated discovery works on synthetic specs/ tree.
_tmp="$(mktemp -d)"
mkdir -p "$_tmp/specs" "$_tmp/references" "$_tmp/docs"
mkdir -p "$_tmp/commands" "$_tmp/templates" "$_tmp/scripts/dispatch/lib" "$_tmp/.orchestrator/milestones"
cp "$FIX_DIR/scope-opted-in-spec.md" "$_tmp/specs/opted-in.md"
cp "$FIX_DIR/scope-opted-in-spec.md" "$_tmp/references/opted-in.md"
cp "$FIX_DIR/scope-opted-in-spec.md" "$_tmp/docs/opted-in.md"

# Copy the linter into the tempdir so its PROJECT_ROOT resolution lands
# on the tempdir.
mkdir -p "$_tmp/scripts/verify"
cp "$LINTER" "$_tmp/scripts/verify/anti-pattern-lint.sh"
out="$(bash "$_tmp/scripts/verify/anti-pattern-lint.sh" 2>&1 || true)"

if printf '%s' "$out" | grep -q 'specs/opted-in.md'; then
  pass "marker opts specs/ file into default sweep"
else
  fail "marker failed to opt specs/ file into default sweep"
fi

if printf '%s' "$out" | grep -q 'references/opted-in.md'; then
  pass "marker opts references/ file into default sweep"
else
  fail "marker failed to opt references/ file into default sweep"
fi

if printf '%s' "$out" | grep -q 'docs/opted-in.md'; then
  pass "marker opts docs/ file into default sweep"
else
  fail "marker failed to opt docs/ file into default sweep"
fi

# --- Assertion 4: unmarked specs-style file in the synthetic tree is NOT
#     flagged. Replace the marked fixture with the excluded (unmarked)
#     variant and rerun.
cp "$FIX_DIR/scope-excluded-spec.md" "$_tmp/specs/opted-in.md"
cp "$FIX_DIR/scope-excluded-spec.md" "$_tmp/references/opted-in.md"
cp "$FIX_DIR/scope-excluded-spec.md" "$_tmp/docs/opted-in.md"
out="$(bash "$_tmp/scripts/verify/anti-pattern-lint.sh" 2>&1 || true)"

if printf '%s' "$out" | grep -qE 'specs/opted-in.md|references/opted-in.md|docs/opted-in.md'; then
  fail "unmarked files unexpectedly appeared in sweep output"
else
  pass "unmarked files correctly excluded from default sweep"
fi

rm -rf "$_tmp"
_tmp=""

# --- Assertion 5: live repo tree produces zero linter violations.
out="$(bash "$LINTER" 2>&1 || true)"
if printf '%s' "$out" | grep -q '^LINT PASS'; then
  pass "live repo sweep reports LINT PASS"
else
  fail "live repo sweep produced violations"
  printf '%s\n' "$out"
fi

# --- Assertion 6: references/engine.md documents the marker convention.
if grep -q 'agent-facing' "$ENGINE_DOC"; then
  pass "references/engine.md mentions 'agent-facing'"
else
  fail "references/engine.md does not document the agent-facing marker"
fi

if grep -qF '<!-- agent-facing -->' "$ENGINE_DOC"; then
  pass "references/engine.md contains literal marker example"
else
  fail "references/engine.md missing literal <!-- agent-facing --> example"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p02-linter-scope.sh"
  exit 0
fi
echo "FAIL: m021-p02-linter-scope.sh ($fail_count failures)"
exit 1
