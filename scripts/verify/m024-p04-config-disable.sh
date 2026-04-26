#!/usr/bin/env bash
# scripts/verify/m024-p04-config-disable.sh
# Verifies a Tier-A-eligible input lands auto_proceeded: false when the project
# config sets auto_proceed: false (operator opt-out per AD-1 / #Q-7).

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMIT="$ROOT/scripts/intake/proposal-emit.sh"

[ -x "$EMIT" ] || { echo "FAIL: $EMIT not executable"; exit 1; }

tmp="$(mktemp -d)"

# Write a project-local override at the repo root path the emitter will see.
# The emitter resolves config relative to $ROOT — we must write to the actual
# project file. To avoid clobbering the developer's config, swap it on entry
# and restore on exit.
project_cfg="$ROOT/orchestrator-config.yml"
backup=""
if [ -f "$project_cfg" ]; then
  backup="$(mktemp)"
  cp "$project_cfg" "$backup"
fi
echo "auto_proceed: false" > "$project_cfg"
restore() {
  if [ -n "$backup" ]; then
    mv "$backup" "$project_cfg"
  else
    rm -f "$project_cfg"
  fi
}
trap 'restore; rm -rf "$tmp"' EXIT

# Match the trivial fixture used by the auto-proceed test (rename TODO comment
# is verb-light enough to land Quick + Tier-A naturally — the auto-proceed
# test already proves it satisfies all four conditions when config is default).
trivial="rename TODO comment"
emit_out=$(bash "$EMIT" --input "$trivial" --intake-root "$tmp/intake")
proposal=$(echo "$emit_out" | sed -n 's/^proposal_path=//p')
[ -f "$proposal" ] || { echo "FAIL: emitter produced no proposal"; exit 1; }

grep -q '^auto_proceeded: false$' "$proposal" \
  || { echo "FAIL: auto_proceed=false config did not suppress fast-path"; exit 1; }

echo "PASS: m024-p04-config-disable — auto_proceed=false config suppresses fast-path on Tier-A input"
exit 0
