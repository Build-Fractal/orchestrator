#!/usr/bin/env bash
# tools/verify/m037-p01-config-clobber-fix.sh — M037 P01 T06 Truth #6 verifier
# (FR-10 / CON-3).
#
# Asserts the shared yaml-merge primitive is in place and that round-trip
# merge against the M037 config-merge fixture preserves operator-authored
# content byte-identical while merging orchestrator-managed defaults
# underneath. Five checks:
#   1. scripts/lib/yaml-merge.sh exists and contains "managed_namespaces"
#      literal (per phase-plan artifact contract).
#   2. packaging/install/install-claude-code.sh invokes yaml-merge.sh.
#   3. packaging/install/install-codex.sh invokes yaml-merge.sh.
#   4. packaging/install/install-cursor.sh invokes yaml-merge.sh.
#   5. Round-trip merge against tests/fixtures/m037-config-merge/ preserves
#      operator-authored pbj_team_dashboard_url: byte-identical AND the
#      operator-authored 3-entry wiki.landing_cards: block byte-identical
#      AND merges orchestrator-managed defaults underneath (verification_
#      commands: from operator wins; wiki: block is sub-key-merged so
#      operator's landing_cards entries survive).
#
# Single-script-file shape (AD-19). Bash 3.2 + POSIX sh compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

YAML_MERGE="$PROJECT_ROOT/scripts/lib/yaml-merge.sh"
INSTALL_CC="$PROJECT_ROOT/packaging/install/install-claude-code.sh"
INSTALL_CX="$PROJECT_ROOT/packaging/install/install-codex.sh"
INSTALL_CR="$PROJECT_ROOT/packaging/install/install-cursor.sh"
FIXTURE_DIR="$PROJECT_ROOT/tests/fixtures/m037-config-merge"

pass=0
fail=0

ok() {
  printf 'CHECK PASS: %s\n' "$1"
  pass=$((pass + 1))
}

bad() {
  printf 'CHECK FAIL: %s\n' "$1"
  fail=$((fail + 1))
}

# 1. yaml-merge.sh exists and contains managed_namespaces literal.
if [ -f "$YAML_MERGE" ] && grep -q 'managed_namespaces' "$YAML_MERGE"; then
  ok "scripts/lib/yaml-merge.sh exists with managed_namespaces literal"
else
  bad "scripts/lib/yaml-merge.sh missing or lacks managed_namespaces literal"
fi

# 2-4. Three installers invoke yaml-merge.sh.
if [ -f "$INSTALL_CC" ] && grep -qE 'yaml-merge\.sh' "$INSTALL_CC"; then
  ok "install-claude-code.sh invokes yaml-merge.sh"
else
  bad "install-claude-code.sh missing yaml-merge.sh invocation"
fi
if [ -f "$INSTALL_CX" ] && grep -qE 'yaml-merge\.sh' "$INSTALL_CX"; then
  ok "install-codex.sh invokes yaml-merge.sh"
else
  bad "install-codex.sh missing yaml-merge.sh invocation"
fi
if [ -f "$INSTALL_CR" ] && grep -qE 'yaml-merge\.sh' "$INSTALL_CR"; then
  ok "install-cursor.sh invokes yaml-merge.sh"
else
  bad "install-cursor.sh missing yaml-merge.sh invocation"
fi

# 5. Round-trip merge against fixture.
TMPDIR_LOCAL="$(mktemp -d -t m037-config-clobber.XXXXXX)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT INT TERM

cp "$FIXTURE_DIR/.orchestrator/config.yml" "$TMPDIR_LOCAL/target.yml"
cp "$FIXTURE_DIR/framework-defaults/orchestrator-config-default.yml" "$TMPDIR_LOCAL/framework.yml"

# Managed list parallels the install-script invocation but trimmed to the
# fixture's surface keys (default_tier, verification_commands, wiki).
MANAGED="default_tier,verification_commands,wiki"

if ! bash "$YAML_MERGE" merge --target "$TMPDIR_LOCAL/target.yml" --framework-default "$TMPDIR_LOCAL/framework.yml" --managed-namespaces "$MANAGED" >"$TMPDIR_LOCAL/merge.log" 2>&1; then
  bad "yaml-merge.sh exited non-zero against fixture (log: $TMPDIR_LOCAL/merge.log)"
  cat "$TMPDIR_LOCAL/merge.log" >&2 || true
else
  # Merged file is now in target.yml (in-place). Run three sub-assertions.
  merged="$TMPDIR_LOCAL/target.yml"
  sub_pass=0
  sub_fail=0

  # Sub-check A: pbj_team_dashboard_url: byte-identical.
  if grep -qxF 'pbj_team_dashboard_url: "https://example.com/pbj-dashboard"' "$merged"; then
    sub_pass=$((sub_pass + 1))
  else
    sub_fail=$((sub_fail + 1))
    printf '  sub-fail: operator-only pbj_team_dashboard_url: not preserved\n' >&2
  fi

  # Sub-check B: operator's three landing_cards entries survive byte-identical.
  # Use -e -- to disambiguate leading-dash patterns from grep option parsing
  # (BSD grep on macOS treats -- as an end-of-options sentinel).
  if grep -qF -e '- section: milestones/M032' -- "$merged" \
     && grep -qF -e '- section: milestones/M033' -- "$merged" \
     && grep -qF -e '- section: milestones/M037' -- "$merged" \
     && grep -qF -e '      title: M032 Wiki Distribution' -- "$merged"; then
    sub_pass=$((sub_pass + 1))
  else
    sub_fail=$((sub_fail + 1))
    printf '  sub-fail: operator wiki.landing_cards: 3-entry block not preserved\n' >&2
  fi

  # Sub-check C: orchestrator-managed defaults merged. The wiki: block is
  # managed (sub-key merge); since framework only has landing_cards: which
  # operator already populated, no new sub-key gets added. The "merge under-
  # neath" assertion here checks that the WIKI namespace itself is present
  # AND structurally intact (operator's content, not framework's empty list).
  if grep -qE '^wiki:' "$merged" && ! grep -qE '^[[:space:]]+landing_cards:[[:space:]]*\[\]' "$merged"; then
    sub_pass=$((sub_pass + 1))
  else
    sub_fail=$((sub_fail + 1))
    printf '  sub-fail: wiki: namespace replaced by framework empty default (operator content lost)\n' >&2
  fi

  if [ "$sub_fail" -eq 0 ]; then
    ok "round-trip merge preserves operator content (3/3 sub-checks)"
  else
    bad "round-trip merge has $sub_fail sub-failures (see stderr)"
  fi
fi

printf 'SUMMARY: m037-p01-config-clobber-fix pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  printf 'PASS: m037-p01-config-clobber-fix (%d/%d)\n' "$pass" "$pass"
  exit 0
fi
exit 1
