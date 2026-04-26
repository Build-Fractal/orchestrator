#!/usr/bin/env bash
# scripts/verify/m024-p06-version-suffix.sh
# Verifies the version-suffix scheme across two consecutive revises.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
REVISE="$ROOT/scripts/intake/revise.sh"

[ -x "$EMIT" ]   || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$REVISE" ] || { echo "FAIL: $REVISE not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Initial emit.
para="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers needing fresh data, plus verbose mode."
emit_out=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter did not produce a proposal"; exit 1; }
proposal_dir=$(dirname "$proposal")

# Snapshot the initial content.
sha_v0=$(shasum -a 256 "$proposal" | cut -d' ' -f1)

# Revise once: scope_tier B → C.
bash "$REVISE" --proposal "$proposal" --axis scope_tier --value C >/dev/null

[ -f "$proposal_dir/proposal-v1.md" ] || { echo "FAIL: proposal-v1.md not created after first revise"; exit 1; }
sha_v1=$(shasum -a 256 "$proposal_dir/proposal-v1.md" | cut -d' ' -f1)
[ "$sha_v0" = "$sha_v1" ] || { echo "FAIL: proposal-v1.md content does not match pre-revise byte-for-byte"; exit 1; }

# Revise again: scope_tier C → A.
bash "$REVISE" --proposal "$proposal" --axis scope_tier --value A >/dev/null

[ -f "$proposal_dir/proposal-v2.md" ] || { echo "FAIL: proposal-v2.md not created after second revise"; exit 1; }

# proposal-v1.md MUST still exist and be byte-identical to its first snapshot.
[ -f "$proposal_dir/proposal-v1.md" ] || { echo "FAIL: proposal-v1.md disappeared after second revise"; exit 1; }
sha_v1_after=$(shasum -a 256 "$proposal_dir/proposal-v1.md" | cut -d' ' -f1)
[ "$sha_v1" = "$sha_v1_after" ] || { echo "FAIL: proposal-v1.md mutated by second revise (must be append-only history)"; exit 1; }

# proposal.md MUST be the latest (scope_tier=A).
grep -q '^scope_tier: "A"' "$proposal" || { echo "FAIL: proposal.md not the latest content (expected scope_tier=A)"; exit 1; }

# proposal-v2.md MUST contain the intermediate state (scope_tier=C).
grep -q '^scope_tier: "C"' "$proposal_dir/proposal-v2.md" || { echo "FAIL: proposal-v2.md does not capture intermediate scope_tier=C state"; exit 1; }

echo "PASS: version-suffix — v1 + v2 archived; v1 byte-stable across consecutive revises; proposal.md is latest"
exit 0
