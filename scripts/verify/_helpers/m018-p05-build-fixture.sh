#!/usr/bin/env bash
# scripts/verify/_helpers/m018-p05-build-fixture.sh
#
# Stages a hermetic fixture orch_root for the M018/P05 verifiers under the
# given root path. Mirrors the M018/P03 + M018/P04 helper shape one helper
# per phase under scripts/verify/_helpers/.
#
# Layout (canonical mode — milestones/<M>/ — so metrics-rollup.sh can
# resolve --milestone <M>):
#
#   <root>/
#     milestones/M018F/execution-log.jsonl   <- copied from a fixture log
#     config.yml                              <- minimal compression block
#
# The script-level CLI sets ORCHESTRATOR_ROOT to <root> and emits the
# milestone id ("M018F") on stdout. Callers source the staged log via
# `--milestone M018F` against `metrics-rollup.sh` / `efficiency-footer.sh`
# / `check-anomalies.sh` / `compression-eval.sh`, all of which honor
# ORCHESTRATOR_ROOT.
#
# Slugs:
#   savings    — savings-bearing log (multi-task payload_breakdown +
#                unit_close records with non-zero savings fields). Default.
#   no-savings — pre-P05 records (no savings fields) for the suppression
#                / quiet-mode contracts.
#
# Usage:  m018-p05-build-fixture.sh <root> [<slug>]
#
# Bash 3.2 (MEM001), AD-19 / AP-009 compliant.

set -eu

if [ $# -lt 1 ]; then
  printf 'Usage: m018-p05-build-fixture.sh <root> [<slug>]\n' >&2
  exit 1
fi

ROOT="$1"
SLUG="${2:-savings}"

if [ ! -d "$ROOT" ]; then
  printf 'm018-p05-build-fixture.sh: root not found: %s\n' "$ROOT" >&2
  exit 1
fi

case "$SLUG" in
  savings|no-savings) : ;;
  *)
    printf 'm018-p05-build-fixture.sh: unknown slug: %s (expected savings or no-savings)\n' "$SLUG" >&2
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Map slug -> source fixture dir + staged milestone id.
# The milestone id matches the records embedded in the fixture log so
# metrics-rollup.sh / check-anomalies.sh can scope to it cleanly.
case "$SLUG" in
  savings)
    SRC_DIR="$REPO_ROOT/tests/fixtures/m018-p05-savings-log"
    MS_ID="M018F"
    ;;
  no-savings)
    SRC_DIR="$REPO_ROOT/tests/fixtures/m018-p05-no-savings-log"
    MS_ID="M018L"
    ;;
esac

if [ ! -f "$SRC_DIR/execution-log.jsonl" ]; then
  printf 'm018-p05-build-fixture.sh: source fixture missing: %s/execution-log.jsonl\n' "$SRC_DIR" >&2
  exit 1
fi

# Idempotent: clean prior staging.
rm -rf "$ROOT/milestones" 2>/dev/null || true
mkdir -p "$ROOT/milestones/$MS_ID"

cp "$SRC_DIR/execution-log.jsonl" "$ROOT/milestones/$MS_ID/execution-log.jsonl"

# Minimal config so read-config.sh resolves cleanly under ORCHESTRATOR_ROOT.
cat > "$ROOT/config.yml" <<'EOF'
context_verbosity: standard
duration_budget: 2h
dispatch_budget: 3
budget_enforcement: warn
compression:
  enabled: true
  efficiency_footer:
    enabled: true
  regression_floor: 0.347
EOF

printf '%s\n' "$MS_ID"
exit 0
