#!/usr/bin/env bash
# scripts/verify/m013-p02-dry-run-manifest.sh
#
# Pins the FR-15 `--dry-run` manifest format as a load-bearing contract.
# Asserts:
#   1. manifest_header / manifest_upsert_line / manifest_footer are defined
#      in scripts/integrations/github-common.sh with the exact printf shapes.
#   2. scripts/integrations/github-init.sh uses the helpers — no inline
#      MANIFEST: / UPSERT: / upserts= printfs or echos.
#   3. First dry-run against the T01 fixture tree matches
#      tests/fixtures/m013-p02/expected-manifest.txt byte-identical.
#   4. Second dry-run with a pre-populated sidecar matches
#      tests/fixtures/m013-p02/expected-manifest-noop.txt byte-identical.
#   5. Planning-state phase P03 seeded by T01 is absent from the manifest
#      (AS-4a lazy projection honored).
#
# Zero live `gh` calls. Bash 3.2 compatible. Exit 0 on PASS, 1 on FAIL.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="${REPO_ROOT}/scripts/integrations/github-common.sh"
INIT_SH="${REPO_ROOT}/scripts/integrations/github-init.sh"
FIXTURE_ROOT="${REPO_ROOT}/tests/fixtures/m013-p02/orchestrator-state"
EXPECTED_CREATE="${REPO_ROOT}/tests/fixtures/m013-p02/expected-manifest.txt"
EXPECTED_NOOP="${REPO_ROOT}/tests/fixtures/m013-p02/expected-manifest-noop.txt"

fail_count=0
pass_count=0
_pass() { echo "PASS: $1"; pass_count=$((pass_count + 1)); }
_fail() { echo "FAIL: $1" >&2; fail_count=$((fail_count + 1)); }

# --- Assertion 1: helpers defined in github-common.sh -------------------------
if [ ! -f "$LIB" ]; then
  _fail "github-common.sh missing at ${LIB}"
  echo "FAIL: m013-p02-dry-run-manifest.sh" >&2
  exit 1
fi

helpers_ok=1
for fn in manifest_header manifest_upsert_line manifest_footer; do
  if ! grep -Eq "^${fn}\(\)" "$LIB"; then
    helpers_ok=0
  fi
done
# Also verify the pinned printf format strings are present verbatim.
if ! grep -q "printf 'MANIFEST: %s %s %s" "$LIB"; then helpers_ok=0; fi
if ! grep -q "printf 'UPSERT: %s %s %s %s" "$LIB"; then helpers_ok=0; fi
if ! grep -q "printf 'upserts=%s skipped=%s errors=%s" "$LIB"; then helpers_ok=0; fi

if [ "$helpers_ok" -eq 1 ]; then
  _pass "manifest_header / manifest_upsert_line / manifest_footer defined in github-common.sh"
else
  _fail "manifest helpers missing or printf format strings drifted in github-common.sh"
fi

# --- Assertion 2: github-init.sh uses the helpers (no inline printfs) ---------
inline_ok=1
# Reject inline MANIFEST: / UPSERT: literals that bypass the helpers. The
# helpers themselves live in github-common.sh so github-init.sh must not
# contain raw `MANIFEST: ` or `UPSERT: ` echo/printf emissions.
if grep -Eq "(echo|printf)[^']*['\"]?(MANIFEST:|UPSERT:)" "$INIT_SH"; then
  inline_ok=0
fi
# Also reject inline upserts= footer printfs.
if grep -Eq "(echo|printf)[^']*['\"]?upserts=" "$INIT_SH"; then
  inline_ok=0
fi
# And require at least one call to each helper from github-init.sh.
for fn in manifest_header manifest_upsert_line manifest_footer; do
  if ! grep -q "${fn} " "$INIT_SH"; then
    inline_ok=0
  fi
done

if [ "$inline_ok" -eq 1 ]; then
  _pass "github-init.sh uses the manifest helpers (no inline MANIFEST: / UPSERT: printfs)"
else
  _fail "github-init.sh still contains inline MANIFEST: / UPSERT: / upserts= printfs or is missing helper calls"
fi

# --- Assertion 3: first dry-run matches expected-manifest.txt byte-identical --
if [ ! -f "$EXPECTED_CREATE" ]; then
  _fail "expected-manifest.txt missing at ${EXPECTED_CREATE}"
else
  ACTUAL_CREATE="$(mktemp -t m013-p02-manifest-create.XXXXXX)"
  # Sandbox the fixture orchestrator-state (so the sidecar lives in a temp
  # copy rather than leaking into the real repo). --i-am-operator bypasses
  # the auto-mode sentinel path; --dry-run makes zero gh calls.
  SANDBOX_CREATE="$(mktemp -d -t m013-p02-sb-create.XXXXXX)"
  mkdir -p "${SANDBOX_CREATE}/.orchestrator"
  cp -R "${FIXTURE_ROOT}/.orchestrator/"* "${SANDBOX_CREATE}/.orchestrator/" 2>/dev/null || true
  # Ensure there is NO sidecar present for the create-path assertion.
  rm -f "${SANDBOX_CREATE}/.orchestrator/integrations/github.json" 2>/dev/null || true

  bash "$INIT_SH" --dry-run --i-am-operator \
    --root "$SANDBOX_CREATE" --repo-slug test/test \
    > "$ACTUAL_CREATE" 2>/dev/null
  rc=$?

  if [ "$rc" -ne 0 ]; then
    _fail "first dry-run exited ${rc} (expected 0)"
  fi

  if diff -u "$EXPECTED_CREATE" "$ACTUAL_CREATE" >/dev/null 2>&1; then
    _pass "--dry-run output matches expected-manifest.txt byte-identical"
  else
    _fail "first dry-run manifest does not match expected-manifest.txt"
    echo "--- diff (expected vs actual) ---" >&2
    diff -u "$EXPECTED_CREATE" "$ACTUAL_CREATE" >&2 || true
    echo "--- end diff ---" >&2
  fi
fi

# --- Assertion 4: second dry-run with populated sidecar matches noop fixture --
if [ ! -f "$EXPECTED_NOOP" ]; then
  _fail "expected-manifest-noop.txt missing at ${EXPECTED_NOOP}"
else
  ACTUAL_NOOP="$(mktemp -t m013-p02-manifest-noop.XXXXXX)"
  SANDBOX_NOOP="$(mktemp -d -t m013-p02-sb-noop.XXXXXX)"
  mkdir -p "${SANDBOX_NOOP}/.orchestrator/integrations"
  cp -R "${FIXTURE_ROOT}/.orchestrator/"* "${SANDBOX_NOOP}/.orchestrator/" 2>/dev/null || true
  # Pre-populate the sidecar with configured repo_slug + project_v2_id so
  # the repo-level resources (milestone, project-v2, labels) resolve to
  # skip-existing-marker, and items entries so every phase/task Issue +
  # Project v2 item resolves to skip-existing-marker too.
  cat > "${SANDBOX_NOOP}/.orchestrator/integrations/github.json" <<'JSON_EOF'
{
  "schema_version": 1,
  "repo_slug": "test/test",
  "project_v2_id": "PVT_kwDOAbc123",
  "sync_mode": "manual",
  "recommended_cron": "*/15 * * * *",
  "custom_field_mappings": [],
  "items": {
    "M013-P02": {"issue_number": 101, "project_v2_attached": true, "status_field_synced": true, "last_attempt_at": "2026-04-21T17:00:00Z", "last_error": null, "schema_version": 1},
    "M013-P02-T01": {"issue_number": 102, "project_v2_attached": true, "status_field_synced": true, "last_attempt_at": "2026-04-21T17:00:00Z", "last_error": null, "schema_version": 1},
    "M013-P02-T02": {"issue_number": 103, "project_v2_attached": true, "status_field_synced": true, "last_attempt_at": "2026-04-21T17:00:00Z", "last_error": null, "schema_version": 1}
  }
}
JSON_EOF

  bash "$INIT_SH" --dry-run --i-am-operator \
    --root "$SANDBOX_NOOP" --repo-slug test/test \
    > "$ACTUAL_NOOP" 2>/dev/null
  rc=$?

  if [ "$rc" -ne 0 ]; then
    _fail "second dry-run exited ${rc} (expected 0)"
  fi

  if diff -u "$EXPECTED_NOOP" "$ACTUAL_NOOP" >/dev/null 2>&1; then
    _pass "second --dry-run with sidecar populated matches expected-manifest-noop.txt"
  else
    _fail "second dry-run manifest does not match expected-manifest-noop.txt"
    echo "--- diff (expected vs actual) ---" >&2
    diff -u "$EXPECTED_NOOP" "$ACTUAL_NOOP" >&2 || true
    echo "--- end diff ---" >&2
  fi
fi

# --- Assertion 5: planning-state phase P03 absent from manifest (AS-4a) -------
if [ -f "${ACTUAL_CREATE:-/nonexistent}" ]; then
  if grep -q "M013-P03" "$ACTUAL_CREATE" 2>/dev/null; then
    _fail "planning-state phase P03 leaked into manifest (AS-4a violation)"
  else
    _pass "Planning-state phase P03 absent from manifest (AS-4a lazy projection honored)"
  fi
else
  _fail "cannot verify AS-4a: first dry-run output file not produced"
fi

# Cleanup.
[ -n "${ACTUAL_CREATE:-}" ] && rm -f "$ACTUAL_CREATE" 2>/dev/null || true
[ -n "${ACTUAL_NOOP:-}" ] && rm -f "$ACTUAL_NOOP" 2>/dev/null || true
[ -n "${SANDBOX_CREATE:-}" ] && rm -rf "$SANDBOX_CREATE" 2>/dev/null || true
[ -n "${SANDBOX_NOOP:-}" ] && rm -rf "$SANDBOX_NOOP" 2>/dev/null || true

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m013-p02-dry-run-manifest.sh ${pass_count}/${pass_count} assertions"
  exit 0
fi
echo "FAIL: m013-p02-dry-run-manifest.sh (${fail_count} failures, ${pass_count} passes)" >&2
exit 1
