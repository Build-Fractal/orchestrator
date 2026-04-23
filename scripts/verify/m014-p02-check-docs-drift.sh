#!/usr/bin/env bash
# Gate: verify check-docs.sh --check drift detects the three drift kinds.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CHECK="${PROJECT_ROOT}/scripts/diagnostics/check-docs.sh"

if [ ! -f "$CHECK" ]; then echo "FAIL: check-docs.sh missing" >&2; exit 1; fi

# Shape checks.
if ! grep -q -- '--check' "$CHECK"; then echo "FAIL: --check flag not documented" >&2; exit 1; fi
if ! grep -q 'DOCTOR:DRIFT' "$CHECK"; then echo "FAIL: DOCTOR:DRIFT output line missing" >&2; exit 1; fi
if ! grep -q 'byte_divergence' "$CHECK"; then echo "FAIL: byte_divergence kind missing" >&2; exit 1; fi
if ! grep -q 'missing_region' "$CHECK"; then echo "FAIL: missing_region kind missing" >&2; exit 1; fi
if ! grep -q 'unmatched_marker' "$CHECK"; then echo "FAIL: unmatched_marker kind missing" >&2; exit 1; fi

# Hermetic scenario 1: clean state (both files empty of markers) => status=ok regions=0.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

cat > "$SCRATCH/CLAUDE.md" <<'EOF'
# plain CLAUDE.md
No markers here.
EOF
cat > "$SCRATCH/AGENTS.md" <<'EOF'
# plain AGENTS.md
No markers here.
EOF

OUT="$(bash "$CHECK" --check drift --root "$SCRATCH" 2>/dev/null)"
if ! echo "$OUT" | grep -q 'DOCTOR:DRIFT status=ok regions=0 divergences=0'; then
  echo "FAIL: clean scratch did not report status=ok" >&2
  echo "  got: $OUT" >&2
  exit 1
fi

# Scenario 2: matching regions => status=ok regions=1 divergences=0.
cat > "$SCRATCH/CLAUDE.md" <<'EOF'
# CLAUDE.md
# >>> orchestrator:recent-changes >>>
- entry-1: identical
# <<< orchestrator:recent-changes <<<
EOF
cat > "$SCRATCH/AGENTS.md" <<'EOF'
# AGENTS.md
# >>> orchestrator:recent-changes >>>
- entry-1: identical
# <<< orchestrator:recent-changes <<<
EOF

OUT="$(bash "$CHECK" --check drift --root "$SCRATCH" 2>/dev/null)"
if ! echo "$OUT" | grep -q 'DOCTOR:DRIFT status=ok regions=1 divergences=0'; then
  echo "FAIL: matching regions did not report status=ok" >&2
  echo "  got: $OUT" >&2
  exit 1
fi

# Scenario 3: byte divergence => status=warn divergences>=1.
cat > "$SCRATCH/AGENTS.md" <<'EOF'
# AGENTS.md
# >>> orchestrator:recent-changes >>>
- entry-1: DIFFERENT
# <<< orchestrator:recent-changes <<<
EOF

OUT="$(bash "$CHECK" --check drift --root "$SCRATCH" 2>/dev/null)"
if ! echo "$OUT" | grep -qE 'DOCTOR:DRIFT status=warn regions=1 divergences=[1-9]'; then
  echo "FAIL: byte divergence scenario did not report status=warn" >&2
  echo "  got: $OUT" >&2
  exit 1
fi

# Scenario 4: missing region in one file.
cat > "$SCRATCH/AGENTS.md" <<'EOF'
# AGENTS.md
# no markers present
EOF

OUT="$(bash "$CHECK" --check drift --root "$SCRATCH" 2>/dev/null)"
if ! echo "$OUT" | grep -qE 'DOCTOR:DRIFT status=warn regions=1 divergences=[1-9]'; then
  echo "FAIL: missing region scenario did not report status=warn" >&2
  echo "  got: $OUT" >&2
  exit 1
fi

# Scenario 4b: unmatched_marker (open without close).
cat > "$SCRATCH/CLAUDE.md" <<'EOF'
# CLAUDE.md
# >>> orchestrator:broken-region >>>
- unclosed entry
EOF
cat > "$SCRATCH/AGENTS.md" <<'EOF'
# AGENTS.md
# no markers
EOF

ERR="$(bash "$CHECK" --check drift --root "$SCRATCH" 2>&1 >/dev/null)"
if ! echo "$ERR" | grep -q 'unmatched_marker region=broken-region file=CLAUDE.md'; then
  echo "FAIL: unmatched_marker finding not emitted on stderr" >&2
  echo "  got: $ERR" >&2
  exit 1
fi

# Scenario 5: absent file => status=skip.
rm -f "$SCRATCH/AGENTS.md"
OUT="$(bash "$CHECK" --check drift --root "$SCRATCH" 2>/dev/null)"
if ! echo "$OUT" | grep -q 'DOCTOR:DRIFT status=skip'; then
  echo "FAIL: absent-file scenario did not report status=skip" >&2
  echo "  got: $OUT" >&2
  exit 1
fi

# Verify default invocation still runs the M006 docs pass.
OUT="$(bash "$CHECK" --root "$PROJECT_ROOT" 2>/dev/null || true)"
if ! echo "$OUT" | grep -q 'DOCTOR:DOCS'; then
  echo "FAIL: default (docs) mode was disabled by drift patch" >&2
  exit 1
fi

echo "PASS: check-docs.sh --check drift detects all three finding kinds"
exit 0
