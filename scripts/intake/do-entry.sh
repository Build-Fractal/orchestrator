#!/usr/bin/env bash
# scripts/intake/do-entry.sh
# M031/P03/T01 -- Universal `orchestrator:do <task>` entry driver.
#
# This is a one-shot driver. It inspects the M024 classifier output, picks
# one of four routing branches, optionally invokes one downstream script,
# emits one JSONL `unit_close` record on the low-confidence-prompt branch,
# and exits. There is no state machine, no lock file, no milestone
# scaffolding write -- CON-4 / DC-4 / NG-6 invariants. The agent runtime
# IS the adapter on the Tier A degenerate fast-path (MEM018): the entry
# script writes the dispatch payload + AD-11 sidecar to disk, emits the
# FR-12 `doing:` summary line, and returns control. Production execution
# requires the agent runtime to read the payload + execute. The
# `--dispatch-stub` test seam stands in for the agent runtime in test
# environments.
#
# # Key links (M031/P03):
#   shape-detect.sh                       (M024 classifier surface)
#   route-to-dispatch.sh                  (P02 Tier A+ middle flow)
#   build-context.sh                      (P01 direct-mode driver)
#   orchestrator-config-default.yml       (P00 pinned defaults)
#
# Four-branch routing table:
#
#   verdict / confidence            branch                  action
#   ----------------------------    -------------------     -----------------------------------------
#   tier_a_plus (any confidence)    tier-a-plus-handoff     exec route-to-dispatch.sh --verdict
#                                                           tier_a_plus --task <desc> [--yes]
#   idea (high) OR short            tier-a-degenerate       invoke build-context.sh --profile=quick
#   paragraph (high)                                        --task-plan <plan> --out <pl>
#                                                           --meta-out <sc>; emit `doing:` line
#                                                           to stderr; agent runtime takes over
#                                                           (MEM018)
#   fragment / spec / long          tier-bc-passthrough     emit `route=tier_bc passthrough=...`
#   paragraph (high)                                        line; exit 0; operator runs the named
#                                                           command in their next turn (NG-6)
#   any verdict, conf < floor       low-conf-prompt         render Tier A vs Tier B question;
#                                                           record `chosen_shape` in JSONL
#                                                           unit_close record
#
# Confidence-floor numeric mapping (A-2 closure):
#   The classifier emits `shape_classification=high|low` (an enum). The
#   entry_routing_confidence_floor knob is numeric (P00 default 0.7).
#   Map `high -> 1.0`, `low -> 0.5` and apply `numeric_confidence >= floor`.
#   `high` (1.0) clears 0.7; `low` (0.5) does not. This grounds the knob
#   in the active classifier surface without modifying M024 to emit a
#   numeric. Future demand can extend M024 to emit a numeric without
#   invalidating this entry -- the mapping is a forward-compatible adapter.
#
# CLI surface (production):
#   --task <description>            required. The task description.
#   --yes                           optional. Forwarded to the Tier A+ router
#                                   so the P02 approval prompt is skipped.
#
# CLI surface (test-only seams; mirror P02 prompt-helper bypass):
#   --config <path>                 override active config.yml lookup.
#   --dispatch-stub <script>        stand in for the agent runtime on the
#                                   Tier A degenerate fast-path; receives
#                                   positional args (branch, task, payload,
#                                   sidecar). Forwarded to route-to-dispatch.sh
#                                   on the Tier A+ branch.
#   --scratch-root <dir>            forwarded to route-to-dispatch.sh on the
#                                   Tier A+ branch.
#   --no-prompt-mode <A|B|C>        bypass the interactive `read` on the
#                                   low-confidence-prompt branch.
#
# Env-var overrides:
#   ORCH_DO_ENTRY_LOG               override the JSONL unit_close record
#                                   path. Default
#                                   .orchestrator/observability/dispatch-log.jsonl.
#                                   Mirrors P02's ORCH_TIER_A_PLUS_LOG pattern.
#
# Invariants:
#   - Bash 3.2 compatible (MEM001): no associative-array declarations
#     (the `declare` minus-A form is forbidden), no process substitution,
#     no `$()` containing pipes inside conditionals.
#   - AD-19 single-script-file Truth Check shape applies to verifier `Check:`
#     commands, not to this driver's internals.
#   - CON-7 / D020 hygiene: no scaffold-placeholder marker bracket-TODO byte
#     pattern in any prose, comment, or output.
#   - CON-3 / AD-2: this driver MUST NOT introduce a parallel routing
#     implementation -- it consumes shape-detect.sh's existing two-line
#     output contract verbatim.
#   - CON-4 / DC-4: no new state machines, no lock files, no milestone
#     scaffolding writes. The only persistent write is the JSONL unit_close
#     record on the low-confidence-prompt branch under the
#     .orchestrator/observability/ permissive carve-out.
#   - NG-6: one-shot per command. No REPL, no daemon, no resume.

set -u

usage() {
  cat >&2 <<'USAGE'
usage: do-entry.sh --task <description>
                   [--yes]
                   [--config <path>]
                   [--dispatch-stub <script>]
                   [--scratch-root <dir>]
                   [--no-prompt-mode <A|B|C>]

  --task             required: the task description (one shell argument).
  --yes              skip the Tier A+ approval prompt (forwarded to router).
  --config           test seam: override active config.yml lookup.
  --dispatch-stub    test seam: stand in for the agent runtime on the
                     Tier A degenerate fast-path; forwarded to router on
                     the Tier A+ branch.
  --scratch-root     test seam: forwarded to router on the Tier A+ branch.
  --no-prompt-mode   test seam: bypass interactive `read` on the
                     low-confidence-prompt branch.

Env:
  ORCH_DO_ENTRY_LOG  override JSONL unit_close record path.
USAGE
  exit 64
}

TASK=""
OPT_YES=0
OPT_CONFIG=""
OPT_DISPATCH_STUB=""
OPT_SCRATCH_ROOT=""
OPT_NO_PROMPT_MODE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --task)             TASK="$2"; shift 2 ;;
    --yes)              OPT_YES=1; shift ;;
    --config)           OPT_CONFIG="$2"; shift 2 ;;
    --dispatch-stub)    OPT_DISPATCH_STUB="$2"; shift 2 ;;
    --scratch-root)     OPT_SCRATCH_ROOT="$2"; shift 2 ;;
    --no-prompt-mode)   OPT_NO_PROMPT_MODE="$2"; shift 2 ;;
    -h|--help)          usage ;;
    *)                  printf 'do-entry: unknown flag: %s\n' "$1" >&2; usage ;;
  esac
done

if [ -z "$TASK" ]; then
  printf 'do-entry: --task <description> is required\n' >&2
  usage
fi

# --------------------------------------------------------------------------
# Active config resolution (4-layer precedence -- mirrors P02's
# tier_a_plus_prompt.sh knob resolution):
#   1. --config <path> when supplied AND file exists
#   2. .orchestrator/config.yml when present
#   3. templates/orchestrator-config-default.yml when present
#   4. hardcoded fallback 0.7
# --------------------------------------------------------------------------
resolve_floor() {
  local _f
  _f=""
  if [ -n "${OPT_CONFIG:-}" ] && [ -f "$OPT_CONFIG" ]; then
    _f=$(grep -E '^entry_routing_confidence_floor:' "$OPT_CONFIG" | head -1 | sed -E 's/^entry_routing_confidence_floor: *([0-9.]+).*$/\1/')
  fi
  if [ -z "${_f:-}" ] && [ -f .orchestrator/config.yml ]; then
    _f=$(grep -E '^entry_routing_confidence_floor:' .orchestrator/config.yml | head -1 | sed -E 's/^entry_routing_confidence_floor: *([0-9.]+).*$/\1/')
  fi
  if [ -z "${_f:-}" ] && [ -f templates/orchestrator-config-default.yml ]; then
    _f=$(grep -E '^entry_routing_confidence_floor:' templates/orchestrator-config-default.yml | head -1 | sed -E 's/^entry_routing_confidence_floor: *([0-9.]+).*$/\1/')
  fi
  printf '%s' "${_f:-0.7}"
}

FLOOR=$(resolve_floor)

# --------------------------------------------------------------------------
# Classifier invocation. Two-line stdout contract (M024 baseline):
#   input_shape=<idea|paragraph|tier_a_plus|fragment|spec|empty>
#   shape_classification=<high|low>
# --------------------------------------------------------------------------
tmp_classifier=$(mktemp -t do-entry-classifier.XXXXXX)
trap 'rm -f "$tmp_classifier"' EXIT

bash scripts/intake/shape-detect.sh --input "$TASK" > "$tmp_classifier"
verdict=$(grep -E '^input_shape=' "$tmp_classifier" | head -1 | sed 's/^input_shape=//')
conf=$(grep -E '^shape_classification=' "$tmp_classifier" | head -1 | sed 's/^shape_classification=//')

# Confidence enum -> numeric mapping (A-2 closure).
case "$conf" in
  high) conf_num="1.0" ;;
  low)  conf_num="0.5" ;;
  *)    conf_num="0.0" ;;
esac

# Floor comparison via awk (bash 3.2 has no floating-point arithmetic in [ ]).
passes_floor=$(awk -v c="$conf_num" -v f="$FLOOR" 'BEGIN { print (c+0 >= f+0) ? 1 : 0 }')

# --------------------------------------------------------------------------
# Branch helpers.
# --------------------------------------------------------------------------

run_tier_a_plus_handoff() {
  local _argv
  _argv="--verdict tier_a_plus --task \"$TASK\""
  if [ "${OPT_YES:-0}" -eq 1 ]; then
    _argv="$_argv --yes"
  fi
  if [ -n "${OPT_DISPATCH_STUB:-}" ]; then
    _argv="$_argv --dispatch-stub \"$OPT_DISPATCH_STUB\""
  fi
  if [ -n "${OPT_SCRATCH_ROOT:-}" ]; then
    _argv="$_argv --scratch-root \"$OPT_SCRATCH_ROOT\""
  fi
  # eval is acceptable here: the input is fully controlled by this script's
  # own argument parser. No operator-supplied unquoted strings reach it.
  eval "bash scripts/intake/route-to-dispatch.sh $_argv"
  return $?
}

run_tier_a_degenerate() {
  local _tmp_plan _tmp_payload _tmp_sidecar
  _tmp_plan=$(mktemp -t do-entry-plan.XXXXXX)
  _tmp_payload=$(mktemp -t do-entry-payload.XXXXXX)
  _tmp_sidecar=$(mktemp -t do-entry-sidecar.XXXXXX)
  printf -- '---\ntype: task-plan\nname: "%s"\n---\n\n%s\n' "$TASK" "$TASK" > "$_tmp_plan"

  bash scripts/dispatch/build-context.sh --profile=quick --task-plan "$_tmp_plan" --out "$_tmp_payload" --meta-out "$_tmp_sidecar"
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    printf 'do-entry: build-context.sh exited %d on tier_a_degenerate fast-path\n' "$rc" >&2
    rm -f "$_tmp_plan" "$_tmp_payload" "$_tmp_sidecar"
    return "$rc"
  fi

  # Parse mem_count + total_tokens from sidecar JSON via grep+sed (no jq dep).
  local _N _X
  _N=$(grep -oE '"mem_count":[ ]*[0-9]+' "$_tmp_sidecar" | head -1 | sed -E 's/.*: *([0-9]+).*/\1/')
  _X=$(grep -oE '"total_tokens":[ ]*[0-9]+' "$_tmp_sidecar" | head -1 | sed -E 's/.*: *([0-9]+).*/\1/')
  _N="${_N:-0}"
  _X="${_X:-0}"

  # FR-12 stderr summary line. Em-dash (U+2014) per spec.
  printf 'doing: %s — knowledge: %s MEMs / %s tokens\n' "$TASK" "$_N" "$_X" >&2

  # Optional test-stub invocation. Production: agent runtime takes over (MEM018).
  if [ -n "${OPT_DISPATCH_STUB:-}" ]; then
    bash "$OPT_DISPATCH_STUB" "tier_a_degenerate" "$TASK" "$_tmp_payload" "$_tmp_sidecar"
    local _rc2=$?
    rm -f "$_tmp_plan" "$_tmp_payload" "$_tmp_sidecar"
    return "$_rc2"
  fi

  # Production: leave the payload + sidecar on disk for the agent runtime
  # to consume. Cleanup is the runtime's job (MEM018).
  return 0
}

run_tier_bc_passthrough() {
  local _surface
  _surface="orchestrator:specify"
  case "$verdict" in
    spec|fragment) _surface="orchestrator:specify" ;;
    paragraph)     _surface="orchestrator:specify" ;;
    empty)         _surface="orchestrator:evaluate" ;;
    *)             _surface="orchestrator:specify" ;;
  esac
  printf 'route=tier_bc passthrough=%s\n' "$_surface" >&2
  printf 'do-entry: this task is too large for a single dispatch — invoke %s in your next turn.\n' "$_surface" >&2
  return 0
}

emit_unit_close_lowconf() {
  local _shape="$1"
  local _log="${ORCH_DO_ENTRY_LOG:-.orchestrator/observability/dispatch-log.jsonl}"
  local _ts
  _ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local _dir
  _dir=$(dirname "$_log")
  mkdir -p "$_dir" 2>/dev/null || true
  printf '{"record_type":"unit_close","granularity":"task","unitId":"do-entry/lowconf","milestone":"do-entry","phase":"lowconf","task":"%s","outcome":"prompted","completed_at":"%s","verdict":"%s","conf":"%s","chosen_shape":"%s","source":"do-entry","timestamp":"%s"}\n' "$TASK" "$_ts" "$verdict" "$conf" "$_shape" "$_ts" >> "$_log"
}

run_lowconf_prompt() {
  printf '\n' >&2
  printf 'Classifier confidence is below the entry_routing_confidence_floor (%s).\n' "$FLOOR" >&2
  printf '\n' >&2
  printf 'Is this a small task (Tier A — single dispatch with knowledge inject) or a larger task (Tier B — full SDD flow)?\n' >&2
  printf '  (A) Tier A — proceed to fast-path dispatch (Quick profile)\n' >&2
  printf '  (B) Tier B — pass through to orchestrator:specify\n' >&2
  printf '  (C) Cancel — abort this entry\n' >&2
  printf '\n' >&2

  local _resp
  if [ -n "${OPT_NO_PROMPT_MODE:-}" ]; then
    _resp="$OPT_NO_PROMPT_MODE"
  else
    # Interactive: 60s timeout; empty/EOF/timeout collapses to C cancel default.
    local _r
    _r=""
    if read -r -n 1 -t 60 _r; then
      _resp="$_r"
    else
      _resp="C"
    fi
  fi
  _resp=$(printf '%s' "$_resp" | tr 'a-z' 'A-Z')
  case "$_resp" in
    A|B|C) : ;;
    *)     _resp="C" ;;
  esac

  emit_unit_close_lowconf "$_resp"

  case "$_resp" in
    A) run_tier_a_degenerate; return $? ;;
    B) run_tier_bc_passthrough; return $? ;;
    C) printf 'do-entry: aborted by operator\n' >&2; return 2 ;;
  esac
}

# --------------------------------------------------------------------------
# Branch table (in order, first-match wins).
# --------------------------------------------------------------------------

# Branch 1: tier_a_plus verdict (regardless of confidence -- P02 router has
# its own approval prompt).
if [ "$verdict" = "tier_a_plus" ]; then
  run_tier_a_plus_handoff
  exit $?
fi

# Branch 2: low-confidence on a non-tier_a_plus verdict.
if [ "$passes_floor" -eq 0 ]; then
  run_lowconf_prompt
  exit $?
fi

# Branch 3: high-confidence Tier A degenerate (idea, or paragraph with
# word count <= 30).
if [ "$verdict" = "idea" ]; then
  run_tier_a_degenerate
  exit $?
fi
if [ "$verdict" = "paragraph" ]; then
  _wc=$(printf '%s' "$TASK" | wc -w | tr -d ' ')
  if [ "${_wc:-0}" -le 30 ]; then
    run_tier_a_degenerate
    exit $?
  fi
  # long paragraph -- falls through to Tier B/C below.
fi

# Branch 4: Tier B/C passthrough (fragment, spec, long paragraph, empty).
run_tier_bc_passthrough
exit $?
