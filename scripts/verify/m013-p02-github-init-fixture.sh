#!/usr/bin/env bash
# scripts/verify/m013-p02-github-init-fixture.sh
#
# Runs scripts/integrations/github-init.sh --dry-run against the
# tests/fixtures/m013-p02/ fixture tree and asserts byte-identical match
# against the record body of tests/fixtures/m013-p02/expected-manifest.txt.
#
# The expected-manifest.txt header lines (those beginning with `#`) are
# treated as a human-readable preface; they are stripped before comparison.
# The walker output itself is a bare record stream — planning-state phase
# P03 must NOT appear (US-1 AS-4a).
#
# Exits 0 on PASS, 1 on FAIL. Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE_ROOT="${REPO_ROOT}/tests/fixtures/m013-p02/orchestrator-state"
EXPECTED="${REPO_ROOT}/tests/fixtures/m013-p02/expected-manifest.txt"
INIT_SH="${REPO_ROOT}/scripts/integrations/github-init.sh"

fail_count=0
pass_count=0

_pass() { echo "PASS: $1"; pass_count=$((pass_count + 1)); }
_fail() { echo "FAIL: $1" >&2; fail_count=$((fail_count + 1)); }

# Preflight: the init script must exist.
if [ ! -f "$INIT_SH" ]; then
  _fail "scripts/integrations/github-init.sh is missing"
  echo "FAIL: m013-p02-github-init-fixture.sh" >&2
  exit 1
fi
_pass "github-init.sh present at scripts/integrations/github-init.sh"

# github-init.sh must pass bash -n syntax check (Bash 3.2 parse).
if bash -n "$INIT_SH" 2>/dev/null; then
  _pass "bash -n github-init.sh (syntactic parse)"
else
  _fail "bash -n github-init.sh reported a parse error"
fi

# Script must contain 'pending-operator-complete' sentinel literal and be >=200 lines.
line_count="$(wc -l < "$INIT_SH" | awk '{print $1}')"
if [ "$line_count" -ge 200 ] && grep -q 'pending-operator-complete' "$INIT_SH" 2>/dev/null; then
  _pass "github-init.sh >=200 lines and contains 'pending-operator-complete'"
else
  _fail "github-init.sh must be >=200 lines and contain pending-operator-complete (have ${line_count} lines)"
fi

# --help support: exit 0 with usage-looking output.
HELP_OUT="$(mktemp -t m013-p02-help.XXXXXX)"
bash "$INIT_SH" --help > "$HELP_OUT" 2>&1
help_rc=$?
if [ "$help_rc" -eq 0 ] && grep -q 'Usage:' "$HELP_OUT" 2>/dev/null; then
  _pass "github-init.sh --help exits 0 with usage text"
else
  _fail "github-init.sh --help expected exit 0 + 'Usage:' line, got rc=${help_rc}"
fi
rm -f "$HELP_OUT"

# Unknown flag -> exit 2.
UNK_OUT="$(mktemp -t m013-p02-unk.XXXXXX)"
bash "$INIT_SH" --nonexistent-flag > "$UNK_OUT" 2>&1
unk_rc=$?
if [ "$unk_rc" -eq 2 ]; then
  _pass "github-init.sh unknown flag exits 2"
else
  _fail "github-init.sh unknown flag expected exit 2, got ${unk_rc}"
fi
rm -f "$UNK_OUT"

# Preflight: expected-manifest.txt must exist.
if [ ! -f "$EXPECTED" ]; then
  _fail "expected-manifest.txt is missing"
  echo "FAIL: m013-p02-github-init-fixture.sh" >&2
  exit 1
fi
_pass "expected-manifest.txt present at tests/fixtures/m013-p02/expected-manifest.txt"

# Run the dry-run; stdout carries the manifest, stderr carries the summary.
ACTUAL_FILE="$(mktemp -t m013-p02-actual.XXXXXX)"
# --i-am-operator required to bypass auto-mode (no-TTY); --dry-run prevents
# any `gh` invocation regardless.
bash "$INIT_SH" --dry-run --i-am-operator --root "$FIXTURE_ROOT" \
  > "$ACTUAL_FILE" 2>/dev/null
rc=$?
if [ "$rc" -ne 0 ]; then
  _fail "github-init.sh --dry-run exited ${rc} (expected 0)"
fi

# Strip comment lines (^#) and blank lines from expected-manifest.txt to get
# the record body.
EXPECTED_BODY="$(mktemp -t m013-p02-expected.XXXXXX)"
grep -vE '^[[:space:]]*(#|$)' "$EXPECTED" > "$EXPECTED_BODY" || true

# Byte-identical compare.
if diff -u "$EXPECTED_BODY" "$ACTUAL_FILE" >/dev/null 2>&1; then
  _pass "github-init.sh fixture-driven dry-run matches expected-manifest.txt byte-identical"
else
  _fail "dry-run manifest does not match expected-manifest.txt"
  echo "--- diff (expected vs actual) ---" >&2
  diff -u "$EXPECTED_BODY" "$ACTUAL_FILE" >&2 || true
  echo "--- end diff ---" >&2
fi

# Planning-state phase P03 must NOT appear.
if grep -q "M013-P03" "$ACTUAL_FILE" 2>/dev/null; then
  _fail "planning-state phase P03 leaked into manifest (AS-4a violation)"
else
  _pass "planning-state phase P03 correctly absent from manifest (AS-4a)"
fi

# Summary metrics: 14 lines expected for the FR-15 pinned manifest format:
#   1 MANIFEST: header + 12 UPSERT: lines (1 milestone + 1 project-v2 +
#   4 labels + 1 phase-issue + 2 task-subissues + 3 project-v2-items) +
#   1 upserts= footer.
actual_count="$(wc -l < "$ACTUAL_FILE" | awk '{print $1}')"
if [ "$actual_count" = "14" ]; then
  _pass "manifest line count = 14 (header + 12 UPSERT + footer)"
else
  _fail "manifest line count expected 14, got ${actual_count}"
fi

# Shape: exactly one MANIFEST: header, one upserts=... footer, and UPSERT: lines in between.
manifest_header_count="$(grep -c '^MANIFEST: ' "$ACTUAL_FILE" 2>/dev/null || echo 0)"
footer_count="$(grep -c '^upserts=' "$ACTUAL_FILE" 2>/dev/null || echo 0)"
first_line="$(head -n 1 "$ACTUAL_FILE" 2>/dev/null)"
last_line="$(tail -n 1 "$ACTUAL_FILE" 2>/dev/null)"
case "$first_line" in
  MANIFEST:*) header_first=1 ;;
  *) header_first=0 ;;
esac
case "$last_line" in
  upserts=*) footer_last=1 ;;
  *) footer_last=0 ;;
esac
if [ "$manifest_header_count" = "1" ] && [ "$footer_count" = "1" ] \
    && [ "$header_first" = "1" ] && [ "$footer_last" = "1" ]; then
  _pass "manifest shape: one MANIFEST: header (first), UPSERT: lines, upserts= footer (last)"
else
  _fail "manifest shape violated (header_count=${manifest_header_count} footer_count=${footer_count} header_first=${header_first} footer_last=${footer_last})"
fi

rm -f "$ACTUAL_FILE" "$EXPECTED_BODY"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m013-p02-github-init-fixture.sh ${pass_count}/${pass_count} assertions"
  exit 0
fi
echo "FAIL: m013-p02-github-init-fixture.sh (${fail_count} failures, ${pass_count} passes)" >&2
exit 1
