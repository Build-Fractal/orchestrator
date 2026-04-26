#!/usr/bin/env bash
# scripts/verify/m024-p06-approval-gate-revise-wired.sh
# Verifies the approval-gate revise verb is wired to revise.sh (default)
# and that --no-apply preserves the legacy P03 stdout shape.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
GATE="$ROOT/scripts/intake/approval-gate.sh"

[ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$GATE" ] || { echo "FAIL: $GATE not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

para="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers needing fresh data, plus verbose mode."
emit_out=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }

# Default (no --no-apply): wired to revise.sh, emits revised_to=<path>.
out=$(bash "$GATE" --proposal "$proposal" --verb revise --axis scope_tier --value C)
echo "$out" | grep -q '^revised_to=' || { echo "FAIL: wired revise did not emit revised_to (got: $out)"; exit 1; }
new_path=$(echo "$out" | sed -n 's/^revised_to=//p')
[ -f "$new_path" ] || { echo "FAIL: wired revise pointed at non-existent file: $new_path"; exit 1; }
[ -f "$(dirname "$proposal")/proposal-v1.md" ] || { echo "FAIL: wired revise did not archive proposal-v1.md"; exit 1; }

# --no-apply: legacy P03 stdout shape, no archive.
emit_out2=$(bash "$EMIT" --input "Add a verbose flag to the status command." --intake-root "$tmp/intake2")
proposal2=$(echo "$emit_out2" | sed -n 's/^proposal_path=//p')
out2=$(bash "$GATE" --proposal "$proposal2" --verb revise --axis scope_tier --value C --no-apply)
echo "$out2" | grep -qx 'revision_pending=true axis=scope_tier value=C' || {
  echo "FAIL: --no-apply did not emit legacy P03 shape (got: $out2)"
  exit 1
}
[ ! -f "$(dirname "$proposal2")/proposal-v1.md" ] || {
  echo "FAIL: --no-apply produced an unexpected archive file"
  exit 1
}

echo "PASS: approval-gate revise verb — wired to revise.sh by default; --no-apply preserves P03 surface"
exit 0
