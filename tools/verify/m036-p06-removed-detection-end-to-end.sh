#!/usr/bin/env bash
# tools/verify/m036-p06-removed-detection-end-to-end.sh -- M036 P06 T02.
# Behavioral verifier: stages a prior-manifest naming a chunk-id that
# is NOT present in the workspace reference root, runs ingest with
# --detect-removals --prior-manifest, asserts stdout contains the
# REMOVED: <chunk-id> line.
#
# AD-19 single-script-file shape. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
WS="$(mktemp -d "${TMPDIR:-/tmp}/m036-p06-removed.XXXXXX")"
trap 'rm -rf "$WS"' EXIT
DRV="$ROOT/scripts/knowledge/ingest-reference.sh"
pass=0
fail=0

# Empty reference root.
mkdir -p "$WS/ref/cms-rule"

# Prior-manifest naming a chunk-id that does not exist.
cat > "$WS/prior.manifest" <<'EOF'
REF-cms-rule-removed-fixture
EOF

ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --reference-root "$WS/ref" --no-index-rebuild \
  --detect-removals --prior-manifest "$WS/prior.manifest" \
  >"$WS/ingest.stdout" 2>"$WS/ingest.stderr" || {
    echo "FAIL: ingest driver failed (rc=$?)"
    cat "$WS/ingest.stderr" >&2
    echo "SUMMARY: m036-p06-removed-detection-end-to-end.sh pass=0 fail=1"
    exit 1
  }

if grep -qF -e "REMOVED: REF-cms-rule-removed-fixture" "$WS/ingest.stdout"; then
  echo "PASS: REMOVED-line-emitted"
  pass=$((pass + 1))
else
  echo "FAIL: REMOVED-line-not-emitted"
  fail=$((fail + 1))
fi

if grep -qF -e "SUMMARY:" "$WS/ingest.stdout"; then
  echo "PASS: SUMMARY-line-still-emitted"
  pass=$((pass + 1))
else
  echo "FAIL: SUMMARY-line-missing"
  fail=$((fail + 1))
fi

# Negative: with --detect-removals omitted, no REMOVED: line.
ORCHESTRATOR_ROOT="$ROOT" \
bash "$DRV" --reference-root "$WS/ref" --no-index-rebuild \
  >"$WS/ingest2.stdout" 2>"$WS/ingest2.stderr" || true

if grep -qF -e "REMOVED:" "$WS/ingest2.stdout"; then
  echo "FAIL: REMOVED-line-emitted-without-flag"
  fail=$((fail + 1))
else
  echo "PASS: removal-detection-is-opt-in"
  pass=$((pass + 1))
fi

echo "SUMMARY: m036-p06-removed-detection-end-to-end.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
