#!/usr/bin/env bash
# scripts/verify/m026-p02-edition-detection-contract.sh
#
# M026/P02/T01 gate: verify the conversus adapter's `check` subcommand
# emits the edition= and reason= lines per the T01 detection contract:
#
#   - Stub branch emits edition=unknown reason=stub.
#   - CONVERSUS_EDITION=oss (with stub) emits edition=oss reason=env-override.
#   - CONVERSUS_EDITION=paid (with stub) emits edition=paid reason=env-override.
#   - CONVERSUS_EDITION=foo (with stub) emits a stderr warning and falls through.
#   - When the real OSS venv is resolvable via PATH/command-v, edition=oss
#     reason=metadata-probe (operator state per M026/P01 OLLAMA-PROBE.md).
#   - Line ordering is stable: available= first, conversus_path= second,
#     edition= third, reason= fourth.
#
# Bash 3.2 compatible. Single-script-file shape (AD-19).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ADAPTER="${REPO_ROOT}/scripts/dispatch/adapters/tool/conversus.sh"

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1" >&2; failed=$((failed + 1)); }

if [ ! -f "$ADAPTER" ]; then
  fail "adapter missing: $ADAPTER"
  echo "FAIL: m026-p02-edition-detection-contract.sh" >&2
  exit 1
fi

SCRATCH="$(mktemp -d -t m026-p02-edition.XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT

# -----------------------------------------------------------------------
# 1. Stub branch: edition=unknown reason=stub.
# -----------------------------------------------------------------------
STUB_OUT="${SCRATCH}/stub.out"
STUB_ERR="${SCRATCH}/stub.err"
CONVERSUS_STUB=1 bash "$ADAPTER" check >"$STUB_OUT" 2>"$STUB_ERR"
rc=$?
if [ $rc -ne 0 ]; then
  fail "stub-branch check rc=$rc (expected 0)"
fi
if grep -qE '^edition=unknown$' "$STUB_OUT"; then
  pass "stub: edition=unknown emitted"
else
  fail "stub: edition=unknown missing"
fi
if grep -qE '^reason=stub$' "$STUB_OUT"; then
  pass "stub: reason=stub emitted"
else
  fail "stub: reason=stub missing"
fi

# -----------------------------------------------------------------------
# 2. CONVERSUS_EDITION=oss override (with stub).
# -----------------------------------------------------------------------
OSS_OUT="${SCRATCH}/oss.out"
CONVERSUS_STUB=1 CONVERSUS_EDITION=oss bash "$ADAPTER" check >"$OSS_OUT" 2>&1
if grep -qE '^edition=oss$' "$OSS_OUT"; then
  pass "env-override oss: edition=oss emitted"
else
  fail "env-override oss: edition=oss missing"
fi
if grep -qE '^reason=env-override$' "$OSS_OUT"; then
  pass "env-override oss: reason=env-override emitted"
else
  fail "env-override oss: reason=env-override missing"
fi

# -----------------------------------------------------------------------
# 3. CONVERSUS_EDITION=paid override (with stub).
# -----------------------------------------------------------------------
PAID_OUT="${SCRATCH}/paid.out"
CONVERSUS_STUB=1 CONVERSUS_EDITION=paid bash "$ADAPTER" check >"$PAID_OUT" 2>&1
if grep -qE '^edition=paid$' "$PAID_OUT"; then
  pass "env-override paid: edition=paid emitted"
else
  fail "env-override paid: edition=paid missing"
fi
if grep -qE '^reason=env-override$' "$PAID_OUT"; then
  pass "env-override paid: reason=env-override emitted"
else
  fail "env-override paid: reason=env-override missing"
fi

# -----------------------------------------------------------------------
# 4. CONVERSUS_EDITION=foo: stderr warning + fall-through.
# -----------------------------------------------------------------------
FOO_OUT="${SCRATCH}/foo.out"
FOO_ERR="${SCRATCH}/foo.err"
CONVERSUS_STUB=1 CONVERSUS_EDITION=foo bash "$ADAPTER" check >"$FOO_OUT" 2>"$FOO_ERR"
if grep -qE 'CONVERSUS_EDITION=foo.*not oss.paid' "$FOO_ERR"; then
  pass "invalid edition: stderr warning emitted"
else
  fail "invalid edition: stderr warning missing (stderr=$(head -n 1 "$FOO_ERR" 2>/dev/null))"
fi
# fall-through under stub reaches stub short-circuit, not metadata-probe.
if grep -qE '^reason=(stub|metadata-probe|metadata-probe-failed)$' "$FOO_OUT"; then
  pass "invalid edition: fell through to non-env-override reason"
else
  fail "invalid edition: did not fall through past env-override"
fi
if grep -qE '^edition=foo$' "$FOO_OUT"; then
  fail "invalid edition: leaked invalid value to stdout"
else
  pass "invalid edition: invalid value did not leak to stdout"
fi
# Warning must NOT appear on stdout.
if grep -qE '^warn:' "$FOO_OUT"; then
  fail "invalid edition: warning leaked to stdout (DC-5 violation)"
else
  pass "invalid edition: warning confined to stderr (DC-5 ok)"
fi

# -----------------------------------------------------------------------
# 5. Line ordering is stable: available= first, conversus_path= second,
#    edition= third, reason= fourth.
# -----------------------------------------------------------------------
ORDER_OUT="${SCRATCH}/order.out"
CONVERSUS_STUB=1 bash "$ADAPTER" check >"$ORDER_OUT" 2>&1
line1="$(sed -n '1p' "$ORDER_OUT")"
line2="$(sed -n '2p' "$ORDER_OUT")"
line3="$(sed -n '3p' "$ORDER_OUT")"
line4="$(sed -n '4p' "$ORDER_OUT")"
case "$line1" in
  available=*) pass "ordering: line 1 is available=" ;;
  *) fail "ordering: line 1 expected 'available=*', got '$line1'" ;;
esac
case "$line2" in
  conversus_path=*) pass "ordering: line 2 is conversus_path=" ;;
  *) fail "ordering: line 2 expected 'conversus_path=*', got '$line2'" ;;
esac
case "$line3" in
  edition=*) pass "ordering: line 3 is edition=" ;;
  *) fail "ordering: line 3 expected 'edition=*', got '$line3'" ;;
esac
case "$line4" in
  reason=*) pass "ordering: line 4 is reason=" ;;
  *) fail "ordering: line 4 expected 'reason=*', got '$line4'" ;;
esac

# -----------------------------------------------------------------------
# 6. Real OSS venv path (when resolvable via command -v). Under M026/P01
#    operator state, OSS is installed and conversus is on PATH.
# -----------------------------------------------------------------------
if command -v conversus >/dev/null 2>&1; then
  REAL_OUT="${SCRATCH}/real.out"
  bash "$ADAPTER" check >"$REAL_OUT" 2>&1
  # Edition should be oss OR paid OR unknown; reason should be
  # metadata-probe (OSS installed) OR metadata-probe-failed.
  if grep -qE '^edition=(oss|paid|unknown)$' "$REAL_OUT"; then
    pass "real-binary: edition= is oss|paid|unknown"
  else
    fail "real-binary: edition= not in {oss,paid,unknown}"
  fi
  if grep -qE '^reason=(metadata-probe|metadata-probe-failed|command-v)$' "$REAL_OUT"; then
    pass "real-binary: reason= is a resolver tag"
  else
    fail "real-binary: reason= not in {metadata-probe,metadata-probe-failed,command-v}"
  fi
  # Under current operator state (M026/P01 OLLAMA-PROBE.md), OSS is
  # installed — metadata-probe should resolve to oss.
  VENV_PY="$HOME/.local/pipx/venvs/conversus/bin/python"
  if [ -x "$VENV_PY" ]; then
    HOME_LINE="$("$VENV_PY" -m pip show conversus 2>/dev/null | grep -E '^Home-page:' | head -n 1)"
    case "$HOME_LINE" in
      *conversus-oss*)
        if grep -qE '^edition=oss$' "$REAL_OUT"; then
          pass "real-binary OSS-installed: edition=oss confirmed"
        else
          fail "real-binary OSS-installed: expected edition=oss, got $(grep -E '^edition=' "$REAL_OUT")"
        fi
        if grep -qE '^reason=metadata-probe$' "$REAL_OUT"; then
          pass "real-binary OSS-installed: reason=metadata-probe confirmed"
        else
          fail "real-binary OSS-installed: expected reason=metadata-probe"
        fi
        ;;
      *)
        echo "SKIP: real-binary venv Home-page not OSS — edition-specific check bypassed"
        ;;
    esac
  else
    echo "SKIP: real-binary venv python not executable — edition-specific check bypassed"
  fi
else
  echo "SKIP: conversus not on PATH — real-binary section bypassed"
fi

echo "SUMMARY: m026-p02-edition-detection-contract.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m026-p02-edition-detection-contract.sh"
  exit 0
fi
echo "FAIL: m026-p02-edition-detection-contract.sh" >&2
exit 1
