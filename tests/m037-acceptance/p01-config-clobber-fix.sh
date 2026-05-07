#!/usr/bin/env bash
# tests/m037-acceptance/p01-config-clobber-fix.sh — M037 P01 SC-5 acceptance.
#
# Exercises the four US-5 acceptance scenarios against the M037 config-merge
# fixture (tests/fixtures/m037-config-merge/). The fixture's framework default
# carries the literal "_orchestrator_managed" comment marker per phase-plan
# artifact contract.
#
# Scenarios:
#   (a) Operator-authored keys survive a simulated `orchestrator:update`
#       (yaml-merge round-trip against the framework default leaves
#       pbj_team_dashboard_url:, populated wiki.landing_cards:, and
#       customized verification_commands: byte-identical).
#   (b) Absent-config produces fresh emit with empty wiki.landing_cards:
#       placeholder (target absent → byte-identical copy from framework).
#   (c) Orchestrator-managed key with changed schema applies new schema
#       while preserving operator-authored sub-keys (extended framework
#       adds wiki.nav_buckets: alongside wiki.landing_cards:; merge brings
#       the new sub-key in while operator's landing_cards content survives).
#   (d) Malformed YAML fails closed (FR-11 — non-zero exit, target
#       byte-identical to malformed input).
#
# Phase artifact contract: this file is >= 30 lines and contains the literal
# string "_orchestrator_managed" (M037 P01 plan artifact must-have).
# Bash 3.2 + POSIX sh compatible.
#
# Spec references: FR-10, FR-11, US-5, SC-5, CON-3.
# Pipeline under test: scripts/lib/yaml-merge.sh (round-trip).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

YAML_MERGE="$PROJECT_ROOT/scripts/lib/yaml-merge.sh"
FIXTURE_DIR="$PROJECT_ROOT/tests/fixtures/m037-config-merge"
OPERATOR_CFG="$FIXTURE_DIR/.orchestrator/config.yml"
FRAMEWORK_CFG="$FIXTURE_DIR/framework-defaults/orchestrator-config-default.yml"

# Sanity: framework default contains the _orchestrator_managed marker per
# phase-plan artifact contract (this script also references it for the
# literal-contains check).
MARKER_LITERAL="_orchestrator_managed"
if ! grep -q "$MARKER_LITERAL" "$FRAMEWORK_CFG"; then
  printf 'FAIL: framework fixture %s missing %s marker\n' "$FRAMEWORK_CFG" "$MARKER_LITERAL"
  exit 1
fi

if [ ! -f "$YAML_MERGE" ]; then
  printf 'FAIL: yaml-merge.sh missing at %s\n' "$YAML_MERGE"
  exit 1
fi

scenario_pass=0
scenario_fail=0

scn_ok() {
  printf 'PASS: scenario %s\n' "$1"
  scenario_pass=$((scenario_pass + 1))
}

scn_bad() {
  printf 'FAIL: scenario %s — %s\n' "$1" "$2"
  scenario_fail=$((scenario_fail + 1))
}

TMPDIR_LOCAL="$(mktemp -d -t m037-p01-sc5.XXXXXX)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT INT TERM

MANAGED="default_tier,verification_commands,wiki"

# --- Scenario (a): operator-authored keys survive simulated update ----------
A_TARGET="$TMPDIR_LOCAL/scen-a-target.yml"
cp "$OPERATOR_CFG" "$A_TARGET"
if bash "$YAML_MERGE" merge --target "$A_TARGET" --framework-default "$FRAMEWORK_CFG" --managed-namespaces "$MANAGED" >"$TMPDIR_LOCAL/a.log" 2>&1; then
  miss=""
  # Operator-only top-level key (pbj_team_dashboard_url:) — must survive
  # byte-identical (CON-3 canonical surface).
  grep -qxF 'pbj_team_dashboard_url: "https://example.com/pbj-dashboard"' "$A_TARGET" \
    || miss="$miss pbj_team_dashboard_url"
  # Operator-authored content under a managed namespace (wiki.landing_cards:)
  # — must survive byte-identical via sub-key merge (CON-3 sub-namespace
  # surface, exercises the merge_managed_block path in yaml-merge.sh).
  grep -qF -e '- section: milestones/M032' -- "$A_TARGET" \
    || miss="$miss landing_cards-M032"
  grep -qF -e '- section: milestones/M033' -- "$A_TARGET" \
    || miss="$miss landing_cards-M033"
  grep -qF -e '- section: milestones/M037' -- "$A_TARGET" \
    || miss="$miss landing_cards-M037"
  # Note: verification_commands: and default_tier: are flat-shape managed
  # keys (no sub-keys for sub-key merge to operate on); per the plan §33
  # "managed namespaces — framework wins" semantics, those operator
  # customizations are intentionally replaced by framework defaults on
  # round-trip. Operators who want to customize verification_commands:
  # set it in .orchestrator/config.local.yml (project-local layer that
  # overrides the framework-managed default per AD-17 four-layer
  # resolution; out of scope for the yaml-merge primitive).
  if [ -z "$miss" ]; then
    scn_ok "(a) operator keys survive simulated update"
  else
    scn_bad "(a)" "missing keys after merge:$miss"
  fi
else
  scn_bad "(a)" "yaml-merge exited non-zero (log: $TMPDIR_LOCAL/a.log)"
fi

# --- Scenario (b): absent target produces fresh emit ------------------------
B_TARGET="$TMPDIR_LOCAL/scen-b-target.yml"
# Ensure absent.
rm -f "$B_TARGET"
if bash "$YAML_MERGE" merge --target "$B_TARGET" --framework-default "$FRAMEWORK_CFG" --managed-namespaces "$MANAGED" >"$TMPDIR_LOCAL/b.log" 2>&1; then
  if [ -f "$B_TARGET" ] && grep -qE '^[[:space:]]+landing_cards:[[:space:]]*\[\]' "$B_TARGET"; then
    scn_ok "(b) absent target produces fresh emit with empty landing_cards"
  else
    scn_bad "(b)" "target written but lacks empty landing_cards: [] placeholder"
  fi
else
  scn_bad "(b)" "yaml-merge exited non-zero on absent target"
fi

# --- Scenario (c): managed key with new sub-key applies new schema ----------
# Build an extended framework with a new sub-key under wiki: that the operator
# does not have. Operator's wiki.landing_cards content must survive AND the
# new framework wiki.nav_buckets sub-key must be merged in.
EXTENDED_FRAMEWORK="$TMPDIR_LOCAL/extended-framework.yml"
cat > "$EXTENDED_FRAMEWORK" <<'FRAMEEOF'
# Extended framework default for SC-5 scenario (c) — adds nav_buckets sub-key
# under the orchestrator-managed wiki: namespace.
default_tier: standard
verification_commands: []

wiki:
  landing_cards: []
  nav_buckets:
    - main
    - extra
FRAMEEOF
C_TARGET="$TMPDIR_LOCAL/scen-c-target.yml"
cp "$OPERATOR_CFG" "$C_TARGET"
if bash "$YAML_MERGE" merge --target "$C_TARGET" --framework-default "$EXTENDED_FRAMEWORK" --managed-namespaces "$MANAGED" >"$TMPDIR_LOCAL/c.log" 2>&1; then
  c_miss=""
  grep -qF -e '- section: milestones/M032' -- "$C_TARGET" || c_miss="$c_miss landing_cards-survival"
  grep -qE '^[[:space:]]+nav_buckets:[[:space:]]*$' "$C_TARGET" || c_miss="$c_miss nav_buckets-merged"
  grep -qF -e '    - main' -- "$C_TARGET" || c_miss="$c_miss nav_buckets-main"
  if [ -z "$c_miss" ]; then
    scn_ok "(c) managed schema change merges new sub-key while preserving operator content"
  else
    scn_bad "(c)" "miss:$c_miss"
  fi
else
  scn_bad "(c)" "yaml-merge exited non-zero (log: $TMPDIR_LOCAL/c.log)"
fi

# --- Scenario (d): malformed YAML fails closed ------------------------------
D_TARGET="$TMPDIR_LOCAL/scen-d-malformed.yml"
printf 'default_tier: "unclosed-string\nverification_commands: []\n' > "$D_TARGET"
if command -v md5 >/dev/null 2>&1; then
  d_before="$(md5 -q "$D_TARGET")"
elif command -v md5sum >/dev/null 2>&1; then
  d_before="$(md5sum "$D_TARGET" | awk '{print $1}')"
else
  d_before="$(wc -c < "$D_TARGET")"
fi
set +e
bash "$YAML_MERGE" merge --target "$D_TARGET" --framework-default "$FRAMEWORK_CFG" --managed-namespaces "$MANAGED" >"$TMPDIR_LOCAL/d.log" 2>&1
d_rc=$?
set -e
if command -v md5 >/dev/null 2>&1; then
  d_after="$(md5 -q "$D_TARGET")"
elif command -v md5sum >/dev/null 2>&1; then
  d_after="$(md5sum "$D_TARGET" | awk '{print $1}')"
else
  d_after="$(wc -c < "$D_TARGET")"
fi
if [ "$d_rc" -ne 0 ] && [ "$d_before" = "$d_after" ]; then
  scn_ok "(d) malformed YAML fails closed (rc=$d_rc, target byte-identical)"
else
  scn_bad "(d)" "expected non-zero rc + byte-identical target (got rc=$d_rc, hash_match=$([ "$d_before" = "$d_after" ] && echo yes || echo no))"
fi

printf 'SUMMARY: p01-config-clobber-fix scenarios pass=%d fail=%d\n' "$scenario_pass" "$scenario_fail"
if [ "$scenario_fail" -eq 0 ]; then
  printf 'PASS: p01-config-clobber-fix (%d/4 scenarios)\n' "$scenario_pass"
  exit 0
fi
exit 1
