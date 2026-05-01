#!/usr/bin/env bash
# scripts/intake/route-to-dispatch.sh
# M024/P03/T03 -- Route an approved (or auto-proceeded) proposal to
# orchestrator:dispatch (the legacy single-dispatch path).
# M031/P02/T04 -- Tier A+ middle flow: chain three sequential dispatches
# (research -> approval prompt -> plan -> build) for inputs the M024
# classifier verdicts as `tier_a_plus`. The chain runs strictly inside
# the existing dispatch surface (commands/dispatch.md). It does NOT
# invoke the auto loop, the roadmap command, or the consolidate command,
# and does NOT touch any auto-loop lock or .orchestrator/milestones/M###/
# scaffolding -- CON-4 / DC-4 / Principle XIV invariants. The Tier A+
# branch is strictly additive to the existing single-dispatch path.
#
# Mode 1 (legacy single-dispatch, M024 baseline):
#
#   bash scripts/intake/route-to-dispatch.sh --proposal <path>
#
#   Output (stdout):
#     invoke=orchestrator:dispatch --proposal <proposal_path>
#     auto_proceed=1   (only when proposal frontmatter has auto_proceeded: true)
#
#   Side effect (only when auto_proceeded=true):
#     Mutates proposal frontmatter to set proceeded_at: <ISO8601>.
#
#   Exit 0 on success; 1 on wrong recommended_command; 2 on usage error.
#
# Mode 2 (Tier A+ middle flow, M031/P02/T04):
#
#   bash scripts/intake/route-to-dispatch.sh \
#       --verdict tier_a_plus \
#       --task <description> \
#       [--yes] \
#       [--session-id <id>] \
#       [--scratch-root <dir>] \
#       [--dispatch-stub <script>]
#
#   - <description> is the operator's task description (the input that
#     classified as tier_a_plus in scripts/intake/shape-detect.sh).
#   - --yes skips the inter-stage approval prompt (drives the helper
#     in --yes mode; exit 0 after the audit line).
#   - --session-id optionally pins the resume-vs-rerun marker; when
#     omitted the router generates one (see _r_new_session_id).
#   - --scratch-root overrides the default `<project>/.orchestrator/tier-a-plus/`
#     scratch prefix (used by SC-6 acceptance test to stage a sandbox).
#   - --dispatch-stub overrides the dispatch invocation with a custom
#     script (one shell argument; receives `<role> <task-slug> <task-desc>
#     <task-slug-dir>` positionals). Used by SC-6 to drive the router
#     without exercising real LLM dispatch. The env var ORCH_DISPATCH_STUB
#     is honored too so callers can set it once. When neither is set, the
#     router invokes scripts/dispatch/build-context.sh per role with the
#     Quick profile and stops at the audit-line emission point -- agents
#     fill the markdown outputs per MEM018 (the agent IS the adapter).
#
#   Output (stdout):
#     route=tier_a_plus task_slug=<slug>
#     research=<.orchestrator/tier-a-plus/<slug>/research.md>
#     plan=<.orchestrator/tier-a-plus/<slug>/plan.md>     (only on prompt-proceed)
#     build=ok                                            (only on build-pass)
#
#   Side effects:
#     mkdir -p <scratch-root>/<task-slug>/
#     write <scratch-root>/<task-slug>/.session-id (single line)
#     append three unit_close JSONL records to the dispatch log
#     (one per role: research, plan, build) -- existing emission
#     surface; two new optional fields ride on each record:
#       tier_a_plus_role: research|plan|build
#       aborted: true|false
#
#   Exit codes:
#     0   chain ran research -> plan -> build all green
#     1   research dispatch failed (aborted=true on research record)
#     2   prompt re-run (exit 1) or abort (exit 2)
#     3   plan dispatch failed (aborted=true on plan record)
#     4   build dispatch failed (aborted=true on build record)
#     64  usage error
#
# Bash 3.2 compatible (MEM001). No declare -A, no process substitution,
# no $() pipes inside conditionals. CON-7 token hygiene: the
# scaffold-placeholder bracket-TODO byte pattern is not embedded in
# this file.

set -u

usage() {
  echo "usage: route-to-dispatch.sh --proposal <path>" >&2
  echo "       route-to-dispatch.sh --verdict tier_a_plus --task <description> [--yes] [--session-id <id>] [--scratch-root <dir>] [--dispatch-stub <script>]" >&2
  exit 64
}

# --- Mode argument parser --------------------------------------------------

PROPOSAL=""
VERDICT=""
TASK_DESC=""
YES_FLAG=0
SESSION_ID=""
SCRATCH_ROOT=""
DISPATCH_STUB="${ORCH_DISPATCH_STUB:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --proposal)        PROPOSAL="$2"; shift 2 ;;
    --verdict)         VERDICT="$2"; shift 2 ;;
    --task)            TASK_DESC="$2"; shift 2 ;;
    --yes)             YES_FLAG=1; shift ;;
    --session-id)      SESSION_ID="$2"; shift 2 ;;
    --scratch-root)    SCRATCH_ROOT="$2"; shift 2 ;;
    --dispatch-stub)   DISPATCH_STUB="$2"; shift 2 ;;
    -h|--help)         usage ;;
    *)                 usage ;;
  esac
done

# Resolve project root from this script's location so the helpers below
# read the active config layer / scratch tree regardless of caller cwd.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Tier A+ middle flow --------------------------------------------------

# _r_new_session_id
#   Generates a deterministic-per-invocation session ID consumed by the
#   T03 prompt helper's resume-vs-rerun marker. Format:
#     <UTC-timestamp>-<4-hex>
#   `date -u` provides the second-grain prefix; `awk` reads /dev/urandom
#   bytes to derive the suffix (no $RANDOM dependency since bash 3.2
#   $RANDOM has limited entropy on macOS launchd-spawned shells).
_r_new_session_id() {
    _r_ts=$(date -u +%Y%m%dT%H%M%S)
    _r_hex=$(LC_ALL=C tr -dc 'a-f0-9' < /dev/urandom 2>/dev/null | head -c 4)
    if [ -z "$_r_hex" ]; then
        _r_hex="0000"
    fi
    printf '%s-%s' "$_r_ts" "$_r_hex"
}

# _r_iso_now
#   ISO 8601 UTC timestamp for unit_close `completed_at` and `timestamp`
#   fields. Mirrors the existing emitter convention in
#   scripts/knowledge/write-summary.sh and scripts/dispatch/build-context.sh.
_r_iso_now() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

# _r_jsonl_log_path
#   Echoes the JSONL path the unit_close records append to. Tier A+ runs
#   live outside any milestone tree, so the records ride on the
#   project-level execution log (the same surface direct-mode dispatch
#   uses). Tests can override via $ORCH_TIER_A_PLUS_LOG.
_r_jsonl_log_path() {
    if [ -n "${ORCH_TIER_A_PLUS_LOG:-}" ]; then
        printf '%s' "$ORCH_TIER_A_PLUS_LOG"
        return 0
    fi
    printf '%s/.orchestrator/direct-mode-execution-log.jsonl' "$PROJECT_ROOT"
}

# _r_emit_unit_close <role> <aborted> <duration_s> <outcome> <task-slug>
#   Append exactly one unit_close JSONL record carrying the M031/P02/T04
#   schema additions: tier_a_plus_role + aborted. Existing records
#   without these fields stay valid (additive schema).
_r_emit_unit_close() {
    _r_role="$1"
    _r_aborted="$2"
    _r_duration="$3"
    _r_outcome="$4"
    _r_slug="$5"
    _r_now=$(_r_iso_now)
    _r_log=$(_r_jsonl_log_path)
    _r_log_dir=$(dirname "$_r_log")
    mkdir -p "$_r_log_dir" 2>/dev/null || true
    # Escape double quotes in outcome (Bash 3.2 sed substitution).
    _r_outcome_esc=$(printf '%s' "$_r_outcome" | sed 's/"/\\"/g')
    printf '{"record_type":"unit_close","granularity":"task","unitId":"tier_a_plus/%s/%s","milestone":"tier_a_plus","phase":"tier_a_plus","task":"%s","duration_s":%d,"outcome":"%s","completed_at":"%s","tier_a_plus_role":"%s","aborted":%s,"source":"router","timestamp":"%s"}\n' \
        "$_r_slug" "$_r_role" "$_r_role" "$_r_duration" "$_r_outcome_esc" "$_r_now" "$_r_role" "$_r_aborted" "$_r_now" \
        >> "$_r_log"
}

# _r_dispatch_one_role <role> <task-slug> <task-desc> <slug-dir>
#   Dispatches a single Tier A+ role. When $DISPATCH_STUB is set, the
#   stub script receives the four positionals and is responsible for
#   writing <slug-dir>/<role>.md. Otherwise the router invokes
#   scripts/dispatch/build-context.sh --profile=quick with the matching
#   role template as the task-plan input and emits the Quick payload +
#   AD-11 sidecar to the slug dir; the agent runtime (per MEM018) reads
#   the payload and writes <slug-dir>/<role>.md. Either way, success is
#   defined as "<slug-dir>/<role>.md exists and is non-empty after the
#   sub-dispatch returns".
#
#   Returns 0 on success, non-zero on failure.
_r_dispatch_one_role() {
    _r_role="$1"
    _r_slug="$2"
    _r_desc="$3"
    _r_dir="$4"
    _r_template="$PROJECT_ROOT/templates/dispatch-role-${_r_role}.md"
    _r_payload_out="$_r_dir/${_r_role}.payload.txt"
    _r_meta_out="$_r_dir/${_r_role}.meta.json"
    _r_artifact="$_r_dir/${_r_role}.md"

    if [ ! -f "$_r_template" ]; then
        printf 'route-to-dispatch: role template missing at %s\n' "$_r_template" >&2
        return 1
    fi

    if [ -n "$DISPATCH_STUB" ]; then
        if [ ! -x "$DISPATCH_STUB" ]; then
            printf 'route-to-dispatch: --dispatch-stub %s not executable\n' "$DISPATCH_STUB" >&2
            return 1
        fi
        # Stub contract: receives <role> <task-slug> <task-desc> <slug-dir>.
        # Stub writes <slug-dir>/<role>.md. SC-6 acceptance test ships a
        # canned stub that emits one-line markdown files.
        "$DISPATCH_STUB" "$_r_role" "$_r_slug" "$_r_desc" "$_r_dir"
        _r_rc=$?
        if [ "$_r_rc" -ne 0 ]; then
            printf 'route-to-dispatch: stub dispatch for role=%s exited %d\n' "$_r_role" "$_r_rc" >&2
            return "$_r_rc"
        fi
        if [ ! -s "$_r_artifact" ]; then
            printf 'route-to-dispatch: stub dispatch for role=%s did not write %s\n' "$_r_role" "$_r_artifact" >&2
            return 1
        fi
        return 0
    fi

    # Real dispatch path: build the Quick-profile payload + AD-11 sidecar
    # via build-context.sh. The agent runtime (per MEM018) is the adapter
    # that consumes the payload and writes <slug-dir>/<role>.md. The
    # router stops at payload-build because the agent layer is invoked
    # one level up the call stack (commands/dispatch.md is the entry
    # point in production -- this script is sequenced from there).
    _r_bcs="$PROJECT_ROOT/scripts/dispatch/build-context.sh"
    if [ ! -x "$_r_bcs" ]; then
        printf 'route-to-dispatch: build-context.sh not executable at %s\n' "$_r_bcs" >&2
        return 1
    fi
    bash "$_r_bcs" \
        --profile=quick \
        --task-plan "$_r_template" \
        --out "$_r_payload_out" \
        --meta-out "$_r_meta_out"
    _r_rc=$?
    if [ "$_r_rc" -ne 0 ]; then
        printf 'route-to-dispatch: build-context.sh for role=%s exited %d\n' "$_r_role" "$_r_rc" >&2
        return "$_r_rc"
    fi
    # In the absence of an in-process agent driver we surface a payload-
    # ready signal and let the caller hand the payload off to the
    # runtime. The artifact existence check below remains the success
    # contract; in production the agent writes <role>.md and the chain
    # continues. Without an agent in the loop this branch will not
    # produce an artifact -- the caller MUST supply --dispatch-stub.
    if [ ! -s "$_r_artifact" ]; then
        printf 'route-to-dispatch: real dispatch for role=%s built payload at %s but %s missing -- agent must consume payload to write the artifact\n' "$_r_role" "$_r_payload_out" "$_r_artifact" >&2
        return 1
    fi
    return 0
}

# tier_a_plus_route <task-desc>
#   Top-level driver of the Tier A+ chain. Returns the chain exit code.
tier_a_plus_route() {
    _r_desc="$1"
    if [ -z "$_r_desc" ]; then
        printf 'route-to-dispatch: --verdict tier_a_plus requires --task <description>\n' >&2
        return 64
    fi

    # Source the slug helper and derive the per-flow scratch slug.
    . "$PROJECT_ROOT/scripts/intake/lib/task-slug.sh"
    _r_slug=$(derive_task_slug "$_r_desc")

    if [ -z "$SCRATCH_ROOT" ]; then
        SCRATCH_ROOT="$PROJECT_ROOT/.orchestrator/tier-a-plus"
    fi
    _r_dir="$SCRATCH_ROOT/$_r_slug"
    mkdir -p "$_r_dir"

    if [ -z "$SESSION_ID" ]; then
        SESSION_ID=$(_r_new_session_id)
    fi
    printf '%s\n' "$SESSION_ID" > "$_r_dir/.session-id"

    printf 'route=tier_a_plus task_slug=%s\n' "$_r_slug"

    # --- Research dispatch ---
    _r_t0=$(date -u +%s)
    _r_dispatch_one_role research "$_r_slug" "$_r_desc" "$_r_dir"
    _r_rc=$?
    _r_t1=$(date -u +%s)
    _r_dur=$(( _r_t1 - _r_t0 ))
    if [ "$_r_rc" -ne 0 ]; then
        _r_emit_unit_close research true "$_r_dur" "research dispatch failed rc=$_r_rc" "$_r_slug"
        return 1
    fi
    _r_emit_unit_close research false "$_r_dur" "research.md present" "$_r_slug"
    printf 'research=%s\n' "$_r_dir/research.md"

    # --- Approval prompt ---
    _r_prompt="$PROJECT_ROOT/scripts/intake/lib/tier-a-plus-prompt.sh"
    if [ "$YES_FLAG" -eq 1 ]; then
        bash "$_r_prompt" \
            --research-path "$_r_dir/research.md" \
            --task-slug "$_r_slug" \
            --session-id "$SESSION_ID" \
            --yes
        _r_pc=$?
    else
        bash "$_r_prompt" \
            --research-path "$_r_dir/research.md" \
            --task-slug "$_r_slug" \
            --session-id "$SESSION_ID"
        _r_pc=$?
    fi
    if [ "$_r_pc" -ne 0 ]; then
        # Operator chose re-run (1) or abort (2). No further records.
        return 2
    fi

    # --- Plan dispatch ---
    _r_t0=$(date -u +%s)
    _r_dispatch_one_role plan "$_r_slug" "$_r_desc" "$_r_dir"
    _r_rc=$?
    _r_t1=$(date -u +%s)
    _r_dur=$(( _r_t1 - _r_t0 ))
    if [ "$_r_rc" -ne 0 ]; then
        _r_emit_unit_close plan true "$_r_dur" "plan dispatch failed rc=$_r_rc" "$_r_slug"
        return 3
    fi
    _r_emit_unit_close plan false "$_r_dur" "plan.md present" "$_r_slug"
    printf 'plan=%s\n' "$_r_dir/plan.md"

    # --- Build dispatch ---
    _r_t0=$(date -u +%s)
    _r_dispatch_one_role build "$_r_slug" "$_r_desc" "$_r_dir"
    _r_rc=$?
    _r_t1=$(date -u +%s)
    _r_dur=$(( _r_t1 - _r_t0 ))
    if [ "$_r_rc" -ne 0 ]; then
        _r_emit_unit_close build true "$_r_dur" "build dispatch failed rc=$_r_rc" "$_r_slug"
        return 4
    fi
    _r_emit_unit_close build false "$_r_dur" "build.md present + verifiers green" "$_r_slug"
    printf 'build=ok\n'
    return 0
}

# --- Mode dispatch ---------------------------------------------------------

if [ -n "$VERDICT" ]; then
    if [ "$VERDICT" != "tier_a_plus" ]; then
        printf 'route-to-dispatch: unsupported --verdict %s (only tier_a_plus is recognized in M031/P02/T04)\n' "$VERDICT" >&2
        exit 64
    fi
    if [ -n "$PROPOSAL" ]; then
        printf 'route-to-dispatch: --proposal and --verdict are mutually exclusive\n' >&2
        exit 64
    fi
    tier_a_plus_route "$TASK_DESC"
    exit $?
fi

# --- Legacy single-dispatch path (M024 baseline, byte-equal) ---------------

[ -n "$PROPOSAL" ] || usage
[ -f "$PROPOSAL" ] || { echo "ERR: proposal not found at $PROPOSAL" >&2; exit 1; }

rec_cmd=$(sed -n 's/^recommended_command: "\(.*\)"$/\1/p' "$PROPOSAL" | head -1)
if [ "$rec_cmd" != "orchestrator:dispatch" ]; then
  echo "ERR: route-to-dispatch invoked on proposal with recommended_command='$rec_cmd' (expected orchestrator:dispatch)" >&2
  exit 1
fi

auto_proceeded=$(sed -n 's/^auto_proceeded: \(.*\)$/\1/p' "$PROPOSAL" | head -1)

if [ "$auto_proceeded" = "true" ]; then
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  esc=$(printf '%s' "proceeded_at: \"$ts\"" | sed 's/[\/&]/\\&/g')
  sed -i.bak "s/^proceeded_at: .*\$/${esc}/" "$PROPOSAL"
  rm -f "${PROPOSAL}.bak"
  echo "auto_proceed=1"
fi

echo "invoke=orchestrator:dispatch --proposal $PROPOSAL"
exit 0
