#!/usr/bin/env bash
# tests/m036-acceptance/live-llm-smoke/run-smoke.sh
#
# M036a P03 live-LLM smoke harness. Runs the production Tier 2 pipeline
# (conversus fidelity gate -> promote/retain -> unit_close JSONL emit)
# against an in-session extracted structured Markdown file.
#
# The extraction step itself is performed by the orchestrating Claude
# Code session (Agent tool, in-process — bypasses the MEM018 constraint
# that prevents shell scripts from invoking the Agent tool directly).
# That extraction must be pre-staged at:
#   tests/fixtures/m036-live-llm-smoke/extracted-structured.md
# before this harness runs.
#
# NOT exercised in CI per CON-3. Operator-only.
#
# Bash 3.2. Exits 0 on success regardless of gate verdict (PASS or
# BLOCK are both meaningful smoke results); exits 1 only on harness
# error (missing inputs, conversus binary absent, etc).

set -eu

# --- Resolve repo root regardless of cwd ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

FIXTURE_DIR="$REPO_ROOT/tests/fixtures/m036-live-llm-smoke"
EXTRACTED="$FIXTURE_DIR/extracted-structured.md"
SOURCE_DOC="$FIXTURE_DIR/policy-data-retention.md"
RUN_DATE="$(date -u +%Y-%m-%d)"

CITE_ID="live-smoke-policy-01"
CATEGORY="regulatory"

# --- Preflight ---
if [ ! -f "$EXTRACTED" ]; then
  printf 'FAIL: extracted-structured.md missing at %s\n' "$EXTRACTED" >&2
  printf '  produce it via the Claude Code Agent tool against:\n' >&2
  printf '    %s\n' "$SOURCE_DOC" >&2
  printf '  using the prompt at:\n' >&2
  printf '    templates/extraction-prompts/tier-2-structured-md.md\n' >&2
  exit 1
fi

if ! command -v conversus >/dev/null 2>&1; then
  printf 'FAIL: conversus binary not on PATH\n' >&2
  printf '  install via: pipx install --force ~/Sites/conversus-oss\n' >&2
  exit 1
fi

# --- Workspace: tmp ORCHESTRATOR_ROOT to keep repo state clean ---
# The Tier 2 helpers expect ORCHESTRATOR_ROOT to contain both source
# (scripts/, templates/, tools/) and runtime state (.orchestrator/).
# Symlink the source dirs from the repo so the helpers find adapters
# and presets, while the runtime state lands in the tmp workspace.
#
# NOTE: workspace cleanup happens at the very end after deliberation
# transcripts are captured to the regression dir. Do NOT use a trap
# here — early traps would clean up before forensics capture.
WS="$(mktemp -d)"
ln -s "$REPO_ROOT/scripts" "$WS/scripts"
ln -s "$REPO_ROOT/templates" "$WS/templates"
ln -s "$REPO_ROOT/tools" "$WS/tools"
export ORCHESTRATOR_ROOT="$WS"
mkdir -p "$WS/.orchestrator/knowledge/reference/_extraction-log"
mkdir -p "$WS/.orchestrator/memory"
mkdir -p "$WS/knowledge/reference/$CATEGORY"
# Conversus arbiter resolves grounding_file relative to ORCHESTRATOR_ROOT.
ln -s "$REPO_ROOT/.orchestrator/memory/constitution.md" \
  "$WS/.orchestrator/memory/constitution.md"

CHUNK_DIR="$WS/knowledge/reference/$CATEGORY"
LOG_DIR="$WS/.orchestrator/knowledge/reference/_extraction-log"

# --- Stage the in-session extraction as a tmp .structured.md ---
TMP_STRUCTURED="$WS/tmp-extracted.structured.md"
cp "$EXTRACTED" "$TMP_STRUCTURED"

# --- Source production helpers ---
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/knowledge/lib/extract-tier-2-llm.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/knowledge/lib/extract-tier-2-gate.sh"

# --- Invoke production conversus fidelity gate (LIVE) ---
# CONVERSUS_PROVIDER=claude-code routes through OAuth (per memory note).
# Caller may have set this; if not, set it here.
: "${CONVERSUS_PROVIDER:=claude-code}"
export CONVERSUS_PROVIDER

GATE_OUT="$WS/gate-result.md"
printf 'SMOKE: invoking production conversus tier-2-fidelity gate (live)\n' >&2
printf 'SMOKE: structured-md = %s\n' "$TMP_STRUCTURED" >&2
printf 'SMOKE: gate-result   = %s\n' "$GATE_OUT" >&2

set +e
extract_tier_2_invoke_gate "$SOURCE_DOC" "$TMP_STRUCTURED" "$GATE_OUT"
verdict=$?
set -e

case "$verdict" in
  0) verdict_label="PASS" ;;
  2) verdict_label="BLOCK" ;;
  *)
    printf 'FAIL: gate adapter error (rc=%s)\n' "$verdict" >&2
    if [ -f "$GATE_OUT" ]; then
      printf '--- gate-result.md (partial) ---\n' >&2
      head -40 "$GATE_OUT" >&2
    fi
    exit 1
    ;;
esac

printf 'SMOKE: gate verdict = %s (rc=%s)\n' "$verdict_label" "$verdict" >&2

# --- Production promote-or-retain ---
extract_tier_2_promote_or_retain \
  "$verdict" \
  "$TMP_STRUCTURED" \
  "$CHUNK_DIR" \
  "$CITE_ID" \
  "$CATEGORY" \
  "$GATE_OUT" \
  "$LOG_DIR"

# --- Estimate metrics for unit_close emit ---
# This harness doesn't exercise a real shell-to-LLM bridge for
# extraction (that's deferred to the bridge proposal). For the
# unit_close record we approximate from char counts: tokens ~ bytes / 4.
SOURCE_BYTES="$(wc -c < "$SOURCE_DOC" | tr -d ' ')"
EXTRACTED_BYTES="$(wc -c < "$EXTRACTED" | tr -d ' ')"
TOKENS_IN="$(( SOURCE_BYTES / 4 + 400 ))"   # source + prompt overhead
TOKENS_OUT="$(( EXTRACTED_BYTES / 4 ))"
# Model attribution: the bulk of the work in this unit is the conversus
# fidelity-gate deliberation, not the orchestrating session's extraction
# step. Conversus does not yet persist a per-call model identifier to
# disk (engine/execution/providers/claude_code.py uses default alias
# "sonnet" but never serializes it to deliberation transcripts). Until
# upstream conversus surfaces model metadata, attribute the unit to the
# deliberation entity itself rather than to a specific model id.
# SMOKE_MODEL still wins if explicitly exported (operator escape hatch).
# See .orchestrator/proposals/papercut-m036a-p03-smoke-hardcoded-model.md.
MODEL="${SMOKE_MODEL:-conversus-deliberation}"
COST_USD="${SMOKE_COST_USD:-0.0}"           # bundled with harness session
case "$verdict" in
  0) QUALITY_SCORE="0.95" ;;
  2) QUALITY_SCORE="0.40" ;;
  *) QUALITY_SCORE="0.0" ;;
esac

extract_tier_2_emit_unit_close \
  "$CITE_ID" \
  "$MODEL" \
  "$TOKENS_IN" \
  "$TOKENS_OUT" \
  "$COST_USD" \
  "$QUALITY_SCORE"

# --- Capture artifacts to fixture-dir regression baseline ---
CAPTURE_DIR="$FIXTURE_DIR/regression-$RUN_DATE"
mkdir -p "$CAPTURE_DIR"

cp "$EXTRACTED" "$CAPTURE_DIR/extracted-structured.md"
cp "$GATE_OUT" "$CAPTURE_DIR/gate-result.md"

PROMOTED="$CHUNK_DIR/REF-${CATEGORY}-${CITE_ID}.structured.md"
if [ -f "$PROMOTED" ]; then
  cp "$PROMOTED" "$CAPTURE_DIR/promoted-structured.md"
fi

PASS_LOG="$LOG_DIR/${CITE_ID}.pass.md"
BLOCK_LOG="$LOG_DIR/${CITE_ID}.block.md"
if [ -f "$PASS_LOG" ]; then
  cp "$PASS_LOG" "$CAPTURE_DIR/${CITE_ID}.pass.md"
fi
if [ -f "$BLOCK_LOG" ]; then
  cp "$BLOCK_LOG" "$CAPTURE_DIR/${CITE_ID}.block.md"
fi

EXEC_LOG="$WS/.orchestrator/execution-log.jsonl"
if [ -f "$EXEC_LOG" ]; then
  cp "$EXEC_LOG" "$CAPTURE_DIR/execution-log.jsonl"
fi

# --- Capture conversus deliberation transcripts (load-bearing for
#     forensics — preserves the per-agent review/cross-review/revision/
#     dispute chains and the final synthesis + arbiter resolution). The
#     gate-result.md only summarises the verdict; the full chain lives
#     in the conversus output dir, which is the same as $WS. ---
DELIB_DIR="$CAPTURE_DIR/conversus-deliberation"
mkdir -p "$DELIB_DIR"
for sub in extractor-advocate fidelity-advocate summary arbiter; do
  if [ -d "$WS/$sub" ]; then
    cp -R "$WS/$sub" "$DELIB_DIR/"
  fi
done
if [ -f "$WS/conversus.yml" ]; then
  cp "$WS/conversus.yml" "$DELIB_DIR/conversus.yml"
fi

# --- Final summary ---
printf 'SMOKE: verdict=%s capture=%s\n' "$verdict_label" "$CAPTURE_DIR"
printf 'SMOKE: artifacts:\n'
ls -1 "$CAPTURE_DIR" | sed 's/^/  /'

# --- Cleanup last (forensics-safe) ---
rm -rf "$WS"

exit 0
