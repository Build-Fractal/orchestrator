#!/usr/bin/env bash
# scripts/verify/m011-p07-gate-pass-block.sh
# Asserts the three decision arms for the fidelity gate in the ingest
# pipeline:
#   PASS  -> adapter exit 0, gate-result verdict: "PASS"
#   BLOCK -> adapter exit 2, gate-result verdict: "BLOCK"
#   BLOCK + --force -> a shim simulating commands/ingest.md Step 5 catches
#                      the exit 2, appends a FORCE: audit-trail line to
#                      .ingest-log.jsonl, and exits 0.
#
# Bash 3.2 compatible; sandboxed under mktemp -d.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ADAPTER="$REPO/scripts/dispatch/adapters/tool/conversus.sh"
ARTIFACT="$REPO/tests/fixtures/normalized-stub.md"

fail=0

# --- PASS case ---
PASS_OUT="$TMP/gate-pass.md"
set +e
CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS bash "$ADAPTER" gate normalize-fidelity "$ARTIFACT" "$PASS_OUT" >/dev/null 2>&1
PASS_RC=$?
set -e
if [ "$PASS_RC" -ne 0 ]; then
  printf 'FAIL[pass-case]: adapter exit=%s (expected 0)\n' "$PASS_RC"
  fail=1
fi
if [ ! -f "$PASS_OUT" ]; then
  printf 'FAIL[pass-case]: gate-result.md missing\n'
  fail=1
elif ! grep -Fq -- 'verdict: "PASS"' "$PASS_OUT"; then
  printf 'FAIL[pass-case]: gate-result missing verdict: "PASS"\n'
  fail=1
fi

# --- BLOCK case ---
BLOCK_OUT="$TMP/gate-block.md"
set +e
CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=BLOCK bash "$ADAPTER" gate normalize-fidelity "$ARTIFACT" "$BLOCK_OUT" >/dev/null 2>&1
BLOCK_RC=$?
set -e
if [ "$BLOCK_RC" -ne 2 ]; then
  printf 'FAIL[block-case]: adapter exit=%s (expected 2)\n' "$BLOCK_RC"
  fail=1
fi
if [ ! -f "$BLOCK_OUT" ]; then
  printf 'FAIL[block-case]: gate-result.md missing\n'
  fail=1
elif ! grep -Fq -- 'verdict: "BLOCK"' "$BLOCK_OUT"; then
  printf 'FAIL[block-case]: gate-result missing verdict: "BLOCK"\n'
  fail=1
fi

# --- BLOCK + --force shim case ---
# Write an in-sandbox shim script that mirrors commands/ingest.md Step 5
# logic: invoke the adapter (BLOCK), catch exit 2, log a FORCE: line,
# exit 0.
SHIM="$TMP/ingest-shim.sh"
LOG_FILE="$TMP/.ingest-log.jsonl"
cat > "$SHIM" <<'SHIM_EOF'
#!/usr/bin/env bash
set -u
ADAPTER="$1"
ARTIFACT="$2"
OUT="$3"
LOG="$4"
FORCE_FLAG=""
if [ "${5:-}" = "--force" ]; then
  FORCE_FLAG="1"
fi
set +e
CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=BLOCK bash "$ADAPTER" gate normalize-fidelity "$ARTIFACT" "$OUT" >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" -eq 2 ] && [ -n "$FORCE_FLAG" ]; then
  TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'FORCE: gate BLOCK bypassed by --force at %s\n' "$TS" >> "$LOG"
  exit 0
fi
exit "$RC"
SHIM_EOF
chmod +x "$SHIM"

SHIM_OUT="$TMP/gate-shim.md"
set +e
bash "$SHIM" "$ADAPTER" "$ARTIFACT" "$SHIM_OUT" "$LOG_FILE" --force
SHIM_RC=$?
set -e
if [ "$SHIM_RC" -ne 0 ]; then
  printf 'FAIL[force-case]: shim exit=%s (expected 0 with --force on BLOCK)\n' "$SHIM_RC"
  fail=1
fi
if [ ! -f "$LOG_FILE" ]; then
  printf 'FAIL[force-case]: .ingest-log.jsonl missing\n'
  fail=1
elif ! grep -Fq -- 'FORCE:' "$LOG_FILE"; then
  printf 'FAIL[force-case]: log file missing FORCE: token\n'
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: conversus gate PASS / BLOCK / BLOCK+--force decision arms verified"
exit 0
