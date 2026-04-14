#!/usr/bin/env bash
# Verifies that only the runtime adapter scripts themselves reference
# $HOME/.claude, $HOME/.codex write paths — no other P05 code writes to
# the real developer HOME.
set -u

adapters_dir="scripts/dispatch/adapters/runtime"

# Search every P05-authored file outside the adapters directory for
# literal write-target references to the real HOME config dirs.
hits="$(grep -rlE '\$HOME/\.(claude|codex|cursor)' \
  scripts/dispatch/detect-runtime.sh \
  scripts/dispatch/adapters/format/ \
  scripts/verify/m008-p05-detect-runtime-output-shape.sh \
  scripts/verify/m008-p05-detect-runtime-signal-coverage.sh \
  scripts/verify/m008-p05-detect-runtime-unknown-path.sh \
  scripts/verify/m008-p05-format-adapter-interface.sh \
  scripts/verify/m008-p05-native-round-trip.sh \
  scripts/verify/m008-p05-speckit-one-directional.sh \
  2>/dev/null || true)"

if [[ -n "$hits" ]]; then
  echo "FAIL: non-adapter P05 files reference \$HOME/.claude|codex|cursor write paths:"
  echo "$hits"
  exit 1
fi

# Adapters may reference these paths (they are the ones doing the writes)
# but MUST guard on HOME=/ or empty HOME — check each adapter for a guard.
for a in "$adapters_dir/claude-code.sh" "$adapters_dir/codex.sh"; do
  if [[ -f "$a" ]]; then
    if ! grep -qE 'HOME.*(=|"")/"|HOME.*-z|unsafe HOME|HOME.*empty' "$a"; then
      echo "FAIL: $a lacks a HOME guard clause"
      exit 1
    fi
  fi
done

echo "PASS: no P05 code outside adapters writes to real \$HOME; adapters include HOME guards"
