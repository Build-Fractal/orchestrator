#!/usr/bin/env bash
# scripts/intake/auto-entry.sh
# M046/P03/T01 -- Unified classify-first entry driver behind
# `orchestrator:auto <arg>`.
#
# This is the single entry driver for the tier-sized autonomous entry. It
# GENERALIZES scripts/intake/do-entry.sh (M031/P03/T01): the entire
# four-branch one-shot routing table is MOVED here verbatim (not
# reimplemented), a Tier-C dir/empty front-route is added ahead of the
# classifier, and an auto-native `AUTO:BLOCK_AMBIGUITY` below-floor default
# is added while the legacy do-compat interactive low-confidence prompt is
# preserved behind `--ambiguity-mode prompt`.
#
# CON-2 (reuse-not-reimplement): this driver consumes shape-detect.sh,
# route-to-dispatch.sh, and build-context.sh BY PATH, byte-unchanged. It
# MUST NOT edit or re-implement any of them, and it MUST NOT touch
# scripts/engine/auto-loop.sh -- auto-entry only ROUTES; it never runs the
# loop itself. On a Tier-C (dir/empty) front-route it emits an `AUTO:ROUTE
# tier=c mode=loop` handoff line and returns control to commands/auto.md,
# which drives the unchanged loop flow (find-active-milestone.sh + the
# existing auto-loop). auto-entry writes no lock file and no milestone
# scaffolding.
#
# FR-2 / SC-2 (byte-parity): the high-confidence one-shot code path below
# is byte-for-byte the same logic do-entry.sh runs today. `do-entry.sh`
# (T02) becomes a thin shim forwarding into this driver, so the parity is
# structural. `--ambiguity-mode` is the ONLY behavioral fork, and it only
# affects the below-floor branch (never reached by the Tier-A SC-2 fixture).
#
# # Key links (M046/P03, reused byte-unchanged):
#   shape-detect.sh                       (M024 classifier surface)
#   route-to-dispatch.sh                  (M031/P02 Tier A+ middle flow)
#   build-context.sh                      (M031/P01 direct-mode driver)
#   orchestrator-config-default.yml       (M031/P00 pinned defaults)
#
# Front-route (before classifier), in order:
#
#   condition                       action
#   -----------------------------   ----------------------------------------
#   empty arg (no positional,       AUTO:ROUTE tier=c mode=loop target=active
#   no --task)                      exit 0; commands/auto.md resolves the
#                                   active milestone and runs the loop.
#   arg is an existing directory    AUTO:ROUTE tier=c mode=loop target=<arg>
#   ([ -d "$arg" ])                 exit 0; commands/auto.md runs the loop
#                                   against that milestone dir.
#   otherwise (task description)    fall through to the one-shot classify
#                                   path below.
#
# One-shot four-branch routing table (moved verbatim from do-entry.sh):
#
#   verdict / confidence            AUTO:ROUTE       action
#   ----------------------------    -------------    --------------------------
#   tier_a_plus (any confidence)    tier=a_plus      exec route-to-dispatch.sh
#                                                    --verdict tier_a_plus
#   idea (high) OR short            tier=a           invoke build-context.sh
#   paragraph (high)                                 --profile=quick; emit
#                                                    `doing:` line (MEM018)
#   fragment / spec / long          tier=b           emit tier_bc passthrough
#   paragraph (high)                                 line; exit 0 (NG-6)
#   any verdict, conf < floor       (none)           block: AUTO:BLOCK_AMBIGUITY
#                                                    and exit 0; prompt: legacy
#                                                    run_lowconf_prompt
#
# Confidence-floor numeric mapping (A-2 closure): the classifier emits
# `shape_classification=high|low`; the entry_routing_confidence_floor knob
# is numeric (default 0.7). Map `high -> 1.0`, `low -> 0.5` and apply
# `numeric_confidence >= floor`. Forward-compatible adapter (see do-entry.sh).
#
# CLI surface:
#   [<description>]                 optional positional task description.
#                                   When present and --task is absent, it is
#                                   treated as the task arg. Empty / absent
#                                   front-routes to the Tier-C loop.
#   --task <description>            the task description (mirrors do-entry.sh).
#   --yes                           forwarded to the Tier A+ router.
#   --config <path>                 override active config.yml lookup.
#   --dispatch-stub <script>        stand in for the agent runtime (Tier A
#                                   degenerate fast-path) / forwarded to the
#                                   router on the Tier A+ branch.
#   --scratch-root <dir>            forwarded to route-to-dispatch.sh.
#   --no-prompt-mode <A|B|C>        bypass the interactive `read` on the
#                                   low-confidence-prompt branch (prompt mode).
#   --ambiguity-mode <block|prompt> below-floor policy. Default `block`
#                                   (auto-native): emit AUTO:BLOCK_AMBIGUITY
#                                   and exit 0 without dispatching. `prompt`
#                                   (do-compat, passed by the do-shim): run
#                                   the legacy interactive low-conf prompt
#                                   exactly as do-entry.sh does today.
#
# Env-var overrides:
#   ORCH_DO_ENTRY_LOG               override the JSONL unit_close record path.
#                                   Default
#                                   .orchestrator/observability/dispatch-log.jsonl.
#                                   Same env var name + default as do-entry.sh
#                                   so the low-conf `unit_close` record is
#                                   byte-identical under either entry.
#
# Invariants:
#   - Bash 3.2 compatible (MEM001): no associative-array declarations (the
#     `declare` minus-A form is forbidden), no process substitution, no
#     `$()` containing pipes inside conditionals.
#   - CON-2 / FR-2: shape-detect.sh, route-to-dispatch.sh, build-context.sh
#     and auto-loop.sh are byte-unchanged. Reuse by path only. This driver
#     makes no reference to editing or re-implementing auto-loop.sh.
#   - CON-4 / DC-4 / NG-6: no new state machines, no lock files, no milestone
#     scaffolding writes, one-shot per command. The only persistent write is
#     the JSONL unit_close record on the low-confidence-prompt branch under
#     the .orchestrator/observability/ permissive carve-out (prompt mode).
#   - CON-7 / D020 hygiene: no scaffold-placeholder marker bracket-TODO byte
#     pattern in any prose, comment, or output.
#   - AD-19 single-script-file Truth Check shape applies to verifier `Check:`
#     commands, not to this driver's internals.

set -u

usage() {
  cat >&2 <<'USAGE'
usage: auto-entry.sh [<description>]
                    [--task <description>]
                    [--yes]
                    [--config <path>]
                    [--dispatch-stub <script>]
                    [--scratch-root <dir>]
                    [--no-prompt-mode <A|B|C>]
                    [--ambiguity-mode <block|prompt>]

  <description>      optional positional task description. Empty / absent
                     front-routes to the Tier-C loop (AUTO:ROUTE tier=c).
  --task             the task description (mirrors do-entry.sh).
  --yes              skip the Tier A+ approval prompt (forwarded to router).
  --config           test seam: override active config.yml lookup.
  --dispatch-stub    test seam: stand in for the agent runtime on the
                     Tier A degenerate fast-path; forwarded to router on
                     the Tier A+ branch.
  --scratch-root     test seam: forwarded to router on the Tier A+ branch.
  --no-prompt-mode   test seam: bypass interactive `read` on the
                     low-confidence-prompt branch (prompt mode).
  --ambiguity-mode   below-floor policy: block (default, auto-native) emits
                     AUTO:BLOCK_AMBIGUITY and exits; prompt (do-compat) runs
                     the legacy interactive low-confidence prompt.

Env:
  ORCH_DO_ENTRY_LOG  override JSONL unit_close record path.
USAGE
  exit 64
}

TASK=""
POSITIONAL=""
HAVE_POSITIONAL=0
OPT_YES=0
OPT_CONFIG=""
OPT_DISPATCH_STUB=""
OPT_SCRATCH_ROOT=""
OPT_NO_PROMPT_MODE=""
AMBIGUITY_MODE="block"

while [ $# -gt 0 ]; do
  case "$1" in
    --task)             TASK="$2"; shift 2 ;;
    --yes)              OPT_YES=1; shift ;;
    --config)           OPT_CONFIG="$2"; shift 2 ;;
    --dispatch-stub)    OPT_DISPATCH_STUB="$2"; shift 2 ;;
    --scratch-root)     OPT_SCRATCH_ROOT="$2"; shift 2 ;;
    --no-prompt-mode)   OPT_NO_PROMPT_MODE="$2"; shift 2 ;;
    --ambiguity-mode)   AMBIGUITY_MODE="$2"; shift 2 ;;
    -h|--help)          usage ;;
    --*)                printf 'auto-entry: unknown flag: %s\n' "$1" >&2; usage ;;
    *)
      # First bare positional is the task description; ignore later ones.
      if [ "$HAVE_POSITIONAL" -eq 0 ]; then
        POSITIONAL="$1"
        HAVE_POSITIONAL=1
      fi
      shift
      ;;
  esac
done

# --ambiguity-mode closed enum. Anything other than `prompt` is `block`.
case "$AMBIGUITY_MODE" in
  block|prompt) : ;;
  *)            AMBIGUITY_MODE="block" ;;
esac

# Resolve the task arg: --task wins; else the bare positional.
if [ -z "$TASK" ] && [ "$HAVE_POSITIONAL" -eq 1 ]; then
  TASK="$POSITIONAL"
fi

# --------------------------------------------------------------------------
# Front-route (BEFORE the classifier). auto-entry never runs the loop -- it
# emits an AUTO:ROUTE handoff line and returns control to commands/auto.md.
# --------------------------------------------------------------------------

# Empty arg -> loop against the active milestone.
if [ -z "$TASK" ]; then
  printf 'AUTO:ROUTE tier=c mode=loop target=active\n' >&2
  exit 0
fi

# Existing directory -> loop against that milestone dir.
if [ -d "$TASK" ]; then
  printf 'AUTO:ROUTE tier=c mode=loop target=%s\n' "$TASK" >&2
  exit 0
fi

# --------------------------------------------------------------------------
# Active config resolution (4-layer precedence -- moved verbatim from
# do-entry.sh):
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
tmp_classifier=$(mktemp -t auto-entry-classifier.XXXXXX)
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
# Branch helpers (moved verbatim from do-entry.sh -- byte-equivalent logic
# so SC-2 parity is structural).
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
  _tmp_plan=$(mktemp -t auto-entry-plan.XXXXXX)
  _tmp_payload=$(mktemp -t auto-entry-payload.XXXXXX)
  _tmp_sidecar=$(mktemp -t auto-entry-sidecar.XXXXXX)
  printf -- '---\ntype: task-plan\nname: "%s"\n---\n\n%s\n' "$TASK" "$TASK" > "$_tmp_plan"

  bash scripts/dispatch/build-context.sh --profile=quick --task-plan "$_tmp_plan" --out "$_tmp_payload" --meta-out "$_tmp_sidecar"
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    printf 'auto-entry: build-context.sh exited %d on tier_a_degenerate fast-path\n' "$rc" >&2
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
# Branch table (in order, first-match wins). Same order as do-entry.sh:
#   tier_a_plus -> below-floor -> idea/short-paragraph degenerate -> tier_bc.
# Each one-shot branch emits exactly one `AUTO:ROUTE tier=<t> mode=one-shot`
# line to stderr BEFORE the branch action. The below-floor branch emits no
# AUTO:ROUTE line -- it emits AUTO:BLOCK_AMBIGUITY (block) or runs the legacy
# low-conf prompt (prompt).
# --------------------------------------------------------------------------

# Branch 1: tier_a_plus verdict (regardless of confidence -- the router has
# its own approval prompt).
if [ "$verdict" = "tier_a_plus" ]; then
  printf 'AUTO:ROUTE tier=a_plus mode=one-shot\n' >&2
  run_tier_a_plus_handoff
  exit $?
fi

# Branch 2: low-confidence on a non-tier_a_plus verdict. The ONLY behavioral
# fork between auto (block) and the do-shim (prompt).
if [ "$passes_floor" -eq 0 ]; then
  if [ "$AMBIGUITY_MODE" = "prompt" ]; then
    run_lowconf_prompt
    exit $?
  fi
  # Default auto-native block: refuse below-floor ambiguity without dispatch.
  printf 'AUTO:BLOCK_AMBIGUITY verdict=%s conf=%s\n' "$verdict" "$conf" >&2
  exit 0
fi

# Branch 3: high-confidence Tier A degenerate (idea, or paragraph with
# word count <= 30).
if [ "$verdict" = "idea" ]; then
  printf 'AUTO:ROUTE tier=a mode=one-shot\n' >&2
  run_tier_a_degenerate
  exit $?
fi
if [ "$verdict" = "paragraph" ]; then
  _wc=$(printf '%s' "$TASK" | wc -w | tr -d ' ')
  if [ "${_wc:-0}" -le 30 ]; then
    printf 'AUTO:ROUTE tier=a mode=one-shot\n' >&2
    run_tier_a_degenerate
    exit $?
  fi
  # long paragraph -- falls through to Tier B/C below.
fi

# Branch 4: Tier B/C passthrough (fragment, spec, long paragraph, empty).
printf 'AUTO:ROUTE tier=b mode=one-shot\n' >&2
run_tier_bc_passthrough
exit $?
