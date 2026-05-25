#!/usr/bin/env bash
# tools/verify/m041-p05-gate-noninteractive-degrades.sh
# FR-9: without --yes in a non-interactive context, file-issue.sh degrades to
# stdout-only — no GitHub write, report printed, exit 0 (no deadlock).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

bash scripts/diagnostics/triage-issue.sh --symptom "gate degrade test" \
  > "$tmpdir/report.md" 2>/dev/null

stderr_file="$tmpdir/stderr.txt"
# No --yes, non-interactive stdin (< /dev/null): must degrade, not write
out="$(GH_MOCK_DIR="$tmpdir" bash scripts/diagnostics/file-issue.sh \
  --triage-report "$tmpdir/report.md" < /dev/null 2>"$stderr_file")"
rc=$?

if [ "$rc" -ne 0 ]; then
  echo "FAIL: degrade path exited $rc (expected 0 — must not deadlock or error)"
  exit 1
fi
if [ -f "$tmpdir/issue-create-request.json" ]; then
  echo "FAIL: a GitHub write occurred without --yes in non-interactive mode"
  exit 1
fi
case "$out" in
  *"## Symptom"*) : ;;
  *) echo "FAIL: triage report not printed to stdout on degrade"; exit 1 ;;
esac
if ! grep -qF "non-interactive without --yes" "$stderr_file"; then
  echo "FAIL: degrade diagnostic not emitted to stderr"
  exit 1
fi
echo "PASS: non-interactive without --yes degrades to stdout-only (no write)"
