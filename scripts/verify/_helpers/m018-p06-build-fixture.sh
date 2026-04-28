#!/usr/bin/env bash
# scripts/verify/_helpers/m018-p06-build-fixture.sh
#
# Stages a hermetic fixture orch_root for the M018/P06 verifiers under the
# given root path. Mirrors the M018/P05 helper shape one helper per phase
# under scripts/verify/_helpers/.
#
# Layout (canonical mode — milestones/<M>/ — so metrics-rollup.sh can
# resolve --milestone <M>):
#
#   <root>/
#     milestones/<M>/execution-log.jsonl   <- copied from a fixture log
#     config.yml                            <- minimal compression block
#
# The script emits the milestone id on stdout. Callers point production
# scripts at the staged log via ORCHESTRATOR_ROOT=<root> --milestone <M>.
#
# Slugs:
#   tier3-fired   — tier3 fired with savings on T01/T02/T04, no-savings
#                   on T03/T05, plus a tier3_skipped event and a pre-P06
#                   payload_breakdown row for CON-5 back-compat. Default.
#                   Milestone id: M018F.
#   tier3-failed  — tier3 LLM call failed (non-zero exit or preservation
#                   breach) — failure-passthrough scenario. Two tasks,
#                   two tier3_failed events, two unit_close pass rows.
#                   Milestone id: M018G.
#
# Usage:  m018-p06-build-fixture.sh <root> [<slug>]
#
# Bash 3.2 (MEM001), AD-19 / AP-009 compliant.

set -eu

if [ $# -lt 1 ]; then
  printf 'Usage: m018-p06-build-fixture.sh <root> [<slug>]\n' >&2
  exit 1
fi

ROOT="$1"
SLUG="${2:-tier3-fired}"

if [ ! -d "$ROOT" ]; then
  printf 'm018-p06-build-fixture.sh: root not found: %s\n' "$ROOT" >&2
  exit 1
fi

case "$SLUG" in
  tier3-fired|tier3-failed) : ;;
  *)
    printf 'm018-p06-build-fixture.sh: unknown slug: %s (expected tier3-fired or tier3-failed)\n' "$SLUG" >&2
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Map slug -> source fixture dir + staged milestone id. The milestone id
# matches the records embedded in the fixture log so metrics-rollup.sh /
# check-anomalies.sh / compression-eval.sh can scope to it cleanly.
case "$SLUG" in
  tier3-fired)
    SRC_DIR="$REPO_ROOT/tests/fixtures/m018-p06-tier3-fired-log"
    MS_ID="M018F"
    ;;
  tier3-failed)
    SRC_DIR="$REPO_ROOT/tests/fixtures/m018-p06-tier3-failed-log"
    MS_ID="M018G"
    ;;
esac

if [ ! -f "$SRC_DIR/execution-log.jsonl" ]; then
  printf 'm018-p06-build-fixture.sh: source fixture missing: %s/execution-log.jsonl\n' "$SRC_DIR" >&2
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
  tier3:
    enabled: true
    intensity_floor: standard
EOF

printf '%s\n' "$MS_ID"
exit 0
