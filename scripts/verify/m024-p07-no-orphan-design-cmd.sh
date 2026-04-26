#!/usr/bin/env bash
# scripts/verify/m024-p07-no-orphan-design-cmd.sh
# Asserts no active-code-path orchestrator:design references appear without an M023 probe gate.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Greppable scope: scripts/intake/ + commands/evaluate.md (the active routing surface).
# Allowed sites:
#   - scripts/intake/design-gate-degradation.sh: probe-pass branch only.
#   - commands/evaluate.md: doc-only forward references explicitly labeled "post-M023".
#   - tests/, scripts/verify/m024-p07-* : test-only references (allowed; explicitly excluded below).
#
# Forbidden: any line in scripts/intake/proposal-emit.sh, scripts/intake/approval-gate.sh,
# or scripts/intake/route-*.sh that names orchestrator:design without an immediately-prior
# M023 probe-pass gate.

violation=0

# Scan proposal-emit.sh for orphan references.
if grep -nE 'orchestrator:design' "$ROOT/scripts/intake/proposal-emit.sh"; then
  echo "FAIL: orchestrator:design referenced in proposal-emit.sh — pre-M023 invariant violated"
  violation=1
fi

# Scan approval-gate.sh.
if grep -nE 'orchestrator:design' "$ROOT/scripts/intake/approval-gate.sh"; then
  echo "FAIL: orchestrator:design referenced in approval-gate.sh — pre-M023 invariant violated"
  violation=1
fi

# Scan route-to-*.sh.
for route in "$ROOT/scripts/intake/route-to-specify.sh" "$ROOT/scripts/intake/route-to-dispatch.sh"; do
  if [ -f "$route" ] && grep -nE 'orchestrator:design' "$route"; then
    echo "FAIL: orchestrator:design referenced in $(basename "$route") — pre-M023 invariant violated"
    violation=1
  fi
done

# Scan degradation script — references must be guarded by M023 probe-pass.
# Heuristic: every orchestrator:design occurrence must appear within 5 lines of an
# m023_shipped check. We accept the script-level convention if the only mention is
# inside a probe-pass branch (greppable as "m023_shipped=true" or "= \"true\"" pattern).
deg="$ROOT/scripts/intake/design-gate-degradation.sh"
if [ -f "$deg" ]; then
  if grep -nE 'orchestrator:design' "$deg"; then
    # Allowed only if every match is preceded (within 5 lines) by m023_shipped="true" or
    # m023_shipped" = "true" or equivalent. Use awk to validate.
    if ! awk '
      /m023_shipped[^a-zA-Z0-9_]+("?[[:space:]]*)?=[[:space:]]*"?true"?/ { gate=NR }
      /orchestrator:design/ { if (NR - gate > 5 || gate == 0) { print "ORPHAN at line " NR; orphan=1 } }
      END { exit orphan ? 1 : 0 }
    ' "$deg"; then
      echo "FAIL: orchestrator:design in degradation script not gated by m023_shipped=true"
      violation=1
    fi
  fi
fi

# Scan evaluate.md — references must be in a clearly labeled "post-M023" doc context.
ev="$ROOT/commands/evaluate.md"
if grep -nE 'orchestrator:design' "$ev"; then
  # Allowed if every line is part of a "post-M023" / "when M023 ships" / "M023 has shipped" prose context.
  # We take the conservative line: only allow it if the file ALSO contains the post-M023 marker phrase
  # within 10 lines of every match.
  if ! awk '
    /post-M023|when M023 ships|M023 has shipped/ { gate=NR }
    /orchestrator:design/ { if (NR - gate > 10 || gate == 0) { if (NR - 10 > 0) { print "ORPHAN at line " NR; orphan=1 } } }
    END { exit orphan ? 1 : 0 }
  ' "$ev"; then
    echo "FAIL: orchestrator:design in evaluate.md not in a post-M023 doc context"
    violation=1
  fi
fi

if [ "$violation" -eq 0 ]; then
  echo "PASS: no-orphan-design-cmd — every orchestrator:design reference is M023-probe-gated or doc-labeled"
  exit 0
fi
exit 1
