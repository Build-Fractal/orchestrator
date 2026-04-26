#!/usr/bin/env bash
# tests/test-revision-version-preservation.sh
# M024/P06/T04 — Two consecutive revises + idempotent no-op.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"
REVISE="$ROOT/scripts/intake/revise.sh"

[ -x "$EMIT" ]   || { echo "FAIL: $EMIT not executable"; exit 1; }
[ -x "$REVISE" ] || { echo "FAIL: $REVISE not executable"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

para="We should redesign the status command output to include a last-seen timestamp, a cache layer with five-second TTL, and a no-cache flag for callers needing fresh data, plus verbose mode and structured output."
emit_out=$(bash "$EMIT" --input "$para" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
proposal_dir=$(dirname "$proposal")

# Snapshot v0 content + sha.
sha_v0=$(shasum -a 256 "$proposal" | cut -d' ' -f1)

# First revise.
bash "$REVISE" --proposal "$proposal" --axis scope_tier --value C >/dev/null
sha_v1=$(shasum -a 256 "$proposal_dir/proposal-v1.md" | cut -d' ' -f1)
[ "$sha_v0" = "$sha_v1" ] || { echo "FAIL: proposal-v1.md not byte-identical to original emit"; exit 1; }

# Snapshot post-first-revise content.
sha_post1=$(shasum -a 256 "$proposal" | cut -d' ' -f1)

# Second revise.
bash "$REVISE" --proposal "$proposal" --axis scope_tier --value A >/dev/null
sha_v2=$(shasum -a 256 "$proposal_dir/proposal-v2.md" | cut -d' ' -f1)
[ "$sha_post1" = "$sha_v2" ] || { echo "FAIL: proposal-v2.md not byte-identical to post-first-revise content"; exit 1; }

# v1 must NOT have been mutated by the second revise.
sha_v1_after=$(shasum -a 256 "$proposal_dir/proposal-v1.md" | cut -d' ' -f1)
[ "$sha_v1" = "$sha_v1_after" ] || { echo "FAIL: proposal-v1.md mutated by second revise"; exit 1; }

# Third revise with same value as current — must be idempotent no-op.
idem_out=$(bash "$REVISE" --proposal "$proposal" --axis scope_tier --value A)
echo "$idem_out" | grep -q '^revised=false reason=identical-axes' || { echo "FAIL: idempotent revise did not emit identical-axes (got: $idem_out)"; exit 1; }
[ ! -f "$proposal_dir/proposal-v3.md" ] || { echo "FAIL: idempotent revise produced an unexpected v3 archive"; exit 1; }

echo "PASS: version preservation — v1+v2 byte-stable; idempotent no-op on third revise"
exit 0
