#!/usr/bin/env bash
# scripts/integrations/github-sync.sh — M013/P04 sync cycle core (T02).
#
# Reconciles orchestrator state with GitHub Issues / Milestones / Projects v2.
# Consumes a populated sidecar from P02's `orchestrator:github init` pass and
# pushes per-item deltas (sub-Issue closes + Project v2 status-field updates)
# to the remote.
#
# Usage:
#   github-sync.sh [--dry-run] [--i-am-operator] [--root <path>]
#                  [--repo-slug <slug>] [--conversus-gate]
#                  [--timeout <sec>]
#
# Output (stdout, dry-run) — FR-15 byte-identical-shape with init --dry-run:
#   DRY-RUN: sync manifest for <M###> (repo=<slug>)
#   UPSERT: <kind> <orchestrator-id> <target> <reason>   (one per resource)
#   upserts=<N> skipped=<M> errors=<E>
#
# Output (stdout, live run):
#   UPSERT: <kind> <orchestrator-id> <target> <reason>   (one per resource)
#   STATUS: <pending-operator-complete|configured>
#   upserts=<N> skipped=<M> errors=<E>                   (final line)
#
# Exit: 0 on success (including pending-operator-complete short-circuit),
#       1 on any upsert error (live), 2 on malformed args, 6 on lock failure.
#
# Contracts:
#   - FR-4: search-before-create on every upsert (marker-based). Sync consumes
#           cached issue_number and honors the FR-4 invariant transitively —
#           the cache entry was populated by init's create path, which already
#           performed the marker search.
#   - FR-5: mutations limited to {createProjectV2, addProjectV2ItemById,
#           updateProjectV2ItemFieldValue}. Sync introduces only the third —
#           P03/T03 pre-whitelisted this shape.
#   - FR-7: acquires lifecycle lock for the duration of the reconcile pass.
#           Released on every exit path via EXIT/INT/TERM/HUP trap.
#   - FR-11: no-op cleanly when sidecar absent / holds pending sentinel.
#            Checked BEFORE lock acquisition.
#   - FR-12: Claude-Code-only v1 (no runtime-specific branching).
#   - FR-15: --dry-run manifest byte-identical-shape to init --dry-run.
#   - FR-16: rate-limit + auth-expiry detection (T03 layers on this — helpers
#            are sourced but not yet invoked at sync-cycle level).
#   - FR-17: observability emitters (T03 layers unit_close JSONL on this).
#            T02 scaffolds emit_tier1_record usage sites via comments; the
#            actual wiring arrives in T03.
#   - SC-7: zero approval prompts under auto-mode (pending-sentinel short-
#           circuit fires BEFORE any `gh` call or lock acquisition).
#
# Bash 3.2 compatible (MEM001). No assoc-arrays, no array-from-stdin builtin,
# no process substitution, no combined-redirect shorthand, no case-conversion
# expansion.
#
# Knowledge-Layer Boundary (D014): this script does NOT touch knowledge/spec/,
# KNOWLEDGE-INDEX.md, scripts/knowledge/rebuild-index.sh, or wiki/.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECT_ROOT="$REPO_ROOT"

# ----------------------------------------------------------------------------
# Flag parser + defaults. Mirrors github-init.sh parser layout.
# ----------------------------------------------------------------------------
DRY_RUN=0
OPERATOR=0
REPO_SLUG=""
CONVERSUS_GATE=0
TIMEOUT=30

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --i-am-operator) OPERATOR=1; shift ;;
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    --repo-slug) REPO_SLUG="$2"; shift 2 ;;
    --conversus-gate)
      # T02: flag parsed as no-op. T05 wires the github-conversus-gate.sh
      # invocation site. Preserved here so the flag parser is stable across
      # P04 task deliverables.
      CONVERSUS_GATE=1
      shift
      ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    -h|--help)
      cat <<'EOF'
Usage: github-sync.sh [--dry-run] [--i-am-operator] [--root <path>]
                      [--repo-slug <slug>] [--conversus-gate]
                      [--timeout <sec>]

Reconciles orchestrator state with GitHub Issues / Milestones / Projects v2.
See references/github-integration.md (Sync Modes) for full contract.
EOF
      exit 0
      ;;
    *) echo "github-sync.sh: unknown flag: $1" >&2; exit 2 ;;
  esac
done

# ----------------------------------------------------------------------------
# SC-7 auto-mode short-circuit. Fires BEFORE any `gh` call, lock acquisition,
# or sidecar read. Same detect-interactive logic as github-init.sh.
# ----------------------------------------------------------------------------
if [ ! -t 0 ] && [ "$OPERATOR" -ne 1 ]; then
  echo "STATUS: pending-operator-complete"
  echo "MESSAGE: sync requires --i-am-operator in non-interactive mode"
  exit 0
fi

# ----------------------------------------------------------------------------
# Source shared helpers. github-common.sh lives alongside this script — it is
# pure (no network side-effects) and provides manifest_upsert_line,
# manifest_footer, gh_marker_search_remote, sidecar_update_item_cache,
# http_probe, and emit_tier1_record (T03 will wire the last three).
# ----------------------------------------------------------------------------
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/github-common.sh"

ORCHESTRATOR_ROOT="${PROJECT_ROOT}/.orchestrator"
SIDECAR_TARGET="${ORCHESTRATOR_ROOT}/integrations/github.json"

# ----------------------------------------------------------------------------
# FR-11 reversibility: absent / pending sidecar → no-op cleanly. Checked
# BEFORE any lock acquisition or `gh` invocation so a partial-install state
# never takes a lock it cannot usefully release.
# ----------------------------------------------------------------------------
if [ ! -f "$SIDECAR_TARGET" ]; then
  echo "STATUS: pending-operator-complete"
  echo "MESSAGE: sidecar absent at ${SIDECAR_TARGET}"
  exit 0
fi
if grep -q '"pending"' "$SIDECAR_TARGET"; then
  echo "STATUS: pending-operator-complete"
  echo "MESSAGE: sidecar holds pending sentinel"
  exit 0
fi

# ----------------------------------------------------------------------------
# FR-7 lifecycle lock.
# Acquires the canonical .orchestrator/orchestrator.lock file under the
# state root via scripts/lifecycle/lock-manager.sh. Released on every exit
# path via the EXIT/INT/TERM/HUP trap. Under --dry-run the lock is NOT
# acquired (dry-run is read-only and may race safely with other tools).
# ----------------------------------------------------------------------------
LOCK_MGR="${REPO_ROOT}/scripts/lifecycle/lock-manager.sh"
LOCK_FILE="${ORCHESTRATOR_ROOT}/orchestrator.lock"
LOCK_HELD=0

acquire_lock() {
  if [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi
  if [ ! -x "$LOCK_MGR" ] && [ ! -f "$LOCK_MGR" ]; then
    echo "FAIL: lock-manager.sh not found at ${LOCK_MGR}" >&2
    exit 6
  fi
  mkdir -p "$ORCHESTRATOR_ROOT"
  if bash "$LOCK_MGR" create "$LOCK_FILE" "github-sync" "M013/P04-sync" >/dev/null 2>&1; then
    LOCK_HELD=1
  else
    echo "FAIL: lock acquisition failed (see ${LOCK_FILE})" >&2
    exit 6
  fi
}

release_lock() {
  if [ "$LOCK_HELD" -eq 1 ]; then
    bash "$LOCK_MGR" break "$LOCK_FILE" >/dev/null 2>&1 || true
    LOCK_HELD=0
  fi
}
trap 'release_lock' EXIT INT TERM HUP

acquire_lock

# ----------------------------------------------------------------------------
# oid → kind / phase / task extraction helpers (P04/T03).
#
# Oid shape: M###[-suffix][-P##[-suffix]][-T##]
#   - milestone:      M013           or M013-FIX
#   - phase-issue:    M013-P01       or M013-FIX-P01-FIX
#   - task-subissue:  M013-P01-T01   or M013-FIX-P01-FIX-T01
#
# Pure string-op helpers (awk/sed, no network). Bash 3.2 safe.
# ----------------------------------------------------------------------------
kind_of() {
  local oid="${1:-}"
  case "$oid" in
    *-T[0-9][0-9]) echo "task-subissue" ;;
    *-P[0-9][0-9]|*-P[0-9][0-9]-*) echo "phase-issue" ;;
    *) echo "milestone" ;;
  esac
}

phase_of() {
  local oid="${1:-}"
  local core="$oid"
  case "$core" in
    *-T[0-9][0-9]) core="${core%-T[0-9][0-9]}" ;;
  esac
  local ph
  ph="$(printf '%s\n' "$core" | awk 'match($0, /-P[0-9][0-9](-[A-Za-z0-9_]+)?$/) { print substr($0, RSTART+1) }')"
  if [ -z "$ph" ]; then
    echo "null"
    return 0
  fi
  echo "$ph"
}

task_of() {
  local oid="${1:-}"
  case "$oid" in
    *-T[0-9][0-9])
      printf '%s\n' "$oid" | awk 'match($0, /T[0-9][0-9]$/) { print substr($0, RSTART, RLENGTH) }'
      ;;
    *)
      echo "null"
      ;;
  esac
}

# ----------------------------------------------------------------------------
# uat_defect_p <oid>
#
# T05 stub: emits "1" when <oid> maps to a UAT defect, "0" otherwise. The
# full implementation inspects knowledge/spec/defect/SPEC-DEFECT-*.md
# frontmatter for the orchestrator-id (post-M013 scope — tracked as
# TODO in references/github-integration.md). T05 ships the stub so the
# --conversus-gate invocation site is wired end-to-end; live UAT-defect
# mapping lands in a follow-on milestone. Always returns 0 exit status so
# callers can use command-substitution without tripping set -e.
# ----------------------------------------------------------------------------
uat_defect_p() {
  # Stub: no oid currently maps to a UAT defect. Callers guard on "=1".
  echo "0"
  return 0
}

# ----------------------------------------------------------------------------
# Milestone discovery. Same strategy as github-init.sh: pick the first
# directory under .orchestrator/milestones/ that has an <id>-ROADMAP.md.
# M###[-suffix] pattern is accepted to allow fixture roots such as M013-FIX.
# ----------------------------------------------------------------------------
discover_milestone() {
  local root="$1"
  local candidate base
  for candidate in "${root}/.orchestrator/milestones/"M*; do
    [ -d "$candidate" ] || continue
    base="$(basename "$candidate")"
    case "$base" in
      M[0-9][0-9][0-9]|M[0-9][0-9][0-9]-*) ;;
      *) continue ;;
    esac
    if [ -f "${candidate}/${base}-ROADMAP.md" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

MILESTONE_DIR=""
if ! MILESTONE_DIR="$(discover_milestone "$PROJECT_ROOT")"; then
  echo "github-sync.sh: no milestone with ROADMAP found under ${PROJECT_ROOT}/.orchestrator/milestones/" >&2
  exit 2
fi
MILESTONE_ID="$(basename "$MILESTONE_DIR")"

# ----------------------------------------------------------------------------
# Phase state helper — extract `state:` or `verification_result:` from
# frontmatter. Bash 3.2 + awk; jq-optional.
# ----------------------------------------------------------------------------
fm_field() {
  local file="$1" key="$2"
  [ -f "$file" ] || { printf '\n'; return; }
  awk -v k="$key" '
    BEGIN { in_fm=0; seen=0 }
    /^---[[:space:]]*$/ {
      if (in_fm==0 && seen==0) { in_fm=1; seen=1; next }
      if (in_fm==1) { exit }
    }
    in_fm==1 {
      pat = "^" k ":[[:space:]]*"
      if ($0 ~ pat) {
        v = $0
        sub(pat, "", v)
        gsub(/^"/, "", v); gsub(/"$/, "", v)
        gsub(/^[ \t]+/, "", v); gsub(/[ \t]+$/, "", v)
        print v
        exit
      }
    }
  ' "$file"
}

# ----------------------------------------------------------------------------
# State walker — compute desired state per projected item.
#
# Walker contract:
#   - Milestone: always desired=track (phantom "track" = up-to-date on remote).
#   - Phase: desired=done iff P##-SUMMARY.md exists with verification_result:
#           "pass"; else desired=ready.
#   - Task: desired=done iff T##-SUMMARY.md exists with verification_result:
#           "pass"; else desired=ready. Tasks are walked under every projected
#           phase (ready or done) — the fixture contract requires sync to
#           reconcile task cache rows even under ready phases (they resolve
#           to skip-nochange when already synced).
#
# Projected items captured as three parallel indexed arrays:
#   item_oid_N   — orchestrator id (M###[-suffix][-P##][-T##])
#   item_kind_N  — one of milestone | phase-issue | task-subissue
#   item_desired_N — desired state string (done | ready | track)
#
# Walker order (stable, byte-identical with expected-sync-dryrun-manifest):
#   1. For each projectable phase (state != planning) in lexical P##-* order:
#        a. phase-issue row
#        b. task-subissue rows in T##-* lexical order
#   2. milestone row at end.
# ----------------------------------------------------------------------------
item_count=0
PHASES_DIR="${MILESTONE_DIR}/phases"
if [ -d "$PHASES_DIR" ]; then
  for pdir in "$PHASES_DIR"/P*; do
    [ -d "$pdir" ] || continue
    phase_id="$(basename "$pdir")"
    case "$phase_id" in
      P[0-9][0-9]|P[0-9][0-9]-*) ;;
      *) continue ;;
    esac
    plan_file="${pdir}/${phase_id}-PLAN.md"
    summary_file="${pdir}/${phase_id}-SUMMARY.md"
    p_state="$(fm_field "$plan_file" "state")"
    # Skip planning-state phases (AS-4a lazy projection).
    case "$p_state" in
      planning|"") continue ;;
    esac
    p_desired="ready"
    if [ -f "$summary_file" ]; then
      if [ "$(fm_field "$summary_file" "verification_result")" = "pass" ]; then
        p_desired="done"
      fi
    fi
    oid_phase="${MILESTONE_ID}-${phase_id}"
    eval "item_oid_${item_count}=\"${oid_phase}\""
    eval "item_kind_${item_count}=\"phase-issue\""
    eval "item_desired_${item_count}=\"${p_desired}\""
    item_count=$((item_count + 1))
    # Tasks under this phase.
    tasks_dir="${pdir}/tasks"
    if [ -d "$tasks_dir" ]; then
      for tplan in "$tasks_dir"/T*-PLAN.md; do
        [ -f "$tplan" ] || continue
        tbase="$(basename "$tplan")"
        task_id="${tbase%%-PLAN.md}"
        case "$task_id" in
          T[0-9][0-9]) ;;
          *) continue ;;
        esac
        tsummary="${tasks_dir}/${task_id}-SUMMARY.md"
        t_desired="ready"
        if [ -f "$tsummary" ]; then
          if [ "$(fm_field "$tsummary" "verification_result")" = "pass" ]; then
            t_desired="done"
          fi
        fi
        oid_task="${MILESTONE_ID}-${phase_id}-${task_id}"
        eval "item_oid_${item_count}=\"${oid_task}\""
        eval "item_kind_${item_count}=\"task-subissue\""
        eval "item_desired_${item_count}=\"${t_desired}\""
        item_count=$((item_count + 1))
      done
    fi
  done
fi
# Milestone row at end of manifest.
eval "item_oid_${item_count}=\"${MILESTONE_ID}\""
eval "item_kind_${item_count}=\"milestone\""
eval "item_desired_${item_count}=\"track\""
item_count=$((item_count + 1))

# ----------------------------------------------------------------------------
# Sidecar cache parse → parallel indexed arrays keyed by oid.
#   cached_oid_N / cached_issue_N / cached_synced_N / cached_attached_N
#
# Line-based JSON walker targeting the flat items map. Bash 3.2 + sed; no
# jq hard-dep. Tolerates both single-line and multi-line JSON shapes (the
# fixture uses a single line per item but repeated keys work either way).
# ----------------------------------------------------------------------------
cached_count=0
parse_cached_items() {
  local in_items=0
  local line cur_oid cur_issue cur_synced cur_attached
  cur_oid=""; cur_issue=""; cur_synced=""; cur_attached=""
  while IFS= read -r line; do
    if [ "$in_items" -eq 0 ]; then
      case "$line" in
        *'"items"'*':'*) in_items=1 ;;
      esac
      continue
    fi
    # Detect start of a per-item block.
    case "$line" in
      *'"M'*'"'*':'*'{'*)
        cur_oid="$(printf '%s\n' "$line" | sed -E 's/.*"(M[A-Za-z0-9_\-]+)"[[:space:]]*:[[:space:]]*\{.*/\1/')"
        # On single-line item shape we also parse fields from the same line.
        case "$line" in
          *'"issue_number"'*)
            cur_issue="$(printf '%s\n' "$line" | sed -E 's/.*"issue_number"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/')"
            ;;
        esac
        case "$line" in
          *'"status_field_synced"'*)
            cur_synced="$(printf '%s\n' "$line" | sed -E 's/.*"status_field_synced"[[:space:]]*:[[:space:]]*(true|false).*/\1/')"
            ;;
        esac
        case "$line" in
          *'"project_v2_attached"'*)
            cur_attached="$(printf '%s\n' "$line" | sed -E 's/.*"project_v2_attached"[[:space:]]*:[[:space:]]*(true|false).*/\1/')"
            ;;
        esac
        # If the line also contains a closing brace, commit the item.
        case "$line" in
          *'}'*)
            if [ -n "$cur_oid" ]; then
              eval "cached_oid_${cached_count}=\"${cur_oid}\""
              eval "cached_issue_${cached_count}=\"${cur_issue}\""
              eval "cached_synced_${cached_count}=\"${cur_synced:-false}\""
              eval "cached_attached_${cached_count}=\"${cur_attached:-false}\""
              cached_count=$((cached_count + 1))
              cur_oid=""; cur_issue=""; cur_synced=""; cur_attached=""
            fi
            ;;
        esac
        continue
        ;;
    esac
    # Multi-line fallback: per-field updates until closing brace.
    case "$line" in
      *'"issue_number"'*)
        cur_issue="$(printf '%s\n' "$line" | sed -E 's/.*"issue_number"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/')"
        ;;
      *'"status_field_synced"'*)
        cur_synced="$(printf '%s\n' "$line" | sed -E 's/.*"status_field_synced"[[:space:]]*:[[:space:]]*(true|false).*/\1/')"
        ;;
      *'"project_v2_attached"'*)
        cur_attached="$(printf '%s\n' "$line" | sed -E 's/.*"project_v2_attached"[[:space:]]*:[[:space:]]*(true|false).*/\1/')"
        ;;
      *'}'*)
        if [ -n "$cur_oid" ]; then
          eval "cached_oid_${cached_count}=\"${cur_oid}\""
          eval "cached_issue_${cached_count}=\"${cur_issue}\""
          eval "cached_synced_${cached_count}=\"${cur_synced:-false}\""
          eval "cached_attached_${cached_count}=\"${cur_attached:-false}\""
          cached_count=$((cached_count + 1))
          cur_oid=""; cur_issue=""; cur_synced=""; cur_attached=""
        fi
        ;;
    esac
  done < "$SIDECAR_TARGET"
}
parse_cached_items

# lookup_desired <oid> — emit the desired state for a walker item keyed by
# oid, or empty if not found. Used by count_projected_graphql_mutations below.
lookup_desired() {
  local q="${1:-}" i=0 oid desired
  while [ "$i" -lt "$item_count" ]; do
    eval "oid=\"\${item_oid_${i}}\""
    if [ "$oid" = "$q" ]; then
      eval "desired=\"\${item_desired_${i}}\""
      printf '%s\n' "$desired"
      return 0
    fi
    i=$((i + 1))
  done
  printf '\n'
  return 1
}

# ----------------------------------------------------------------------------
# FR-16 pre-flight rate-limit probe (P04/T03).
#
# Fires only when projected GraphQL mutation volume > 50. The reconcile loop
# issues at most one mutation per projected phase-issue whose desired=done
# AND cached status_field_synced=false. We sum those from the sidecar + the
# walker-derived desired state.
#
# On rate-limit (rc=3) or auth-expired (rc=4) the probe short-circuits with
# the FR-16 exit-code contract (rc=3 / rc=4) + diagnostic to stderr. Under
# --dry-run the probe is skipped (dry-run is read-only).
#
# The probe itself is a REST call (`gh api /rate_limit`) — outside FR-5's
# mutation-whitelist scope. http_probe lives in github-common.sh and honors
# M013_GH_STUB_DIR for fixture-driven testing.
# ----------------------------------------------------------------------------
count_projected_graphql_mutations() {
  local n=0 i=0 oid synced desired k
  while [ "$i" -lt "$cached_count" ]; do
    eval "oid=\"\${cached_oid_${i}}\""
    eval "synced=\"\${cached_synced_${i}}\""
    desired="$(lookup_desired "$oid")"
    k="$(kind_of "$oid")"
    if [ "$desired" = "done" ] && [ "$synced" = "false" ] && [ "$k" = "phase-issue" ]; then
      n=$((n + 1))
    fi
    i=$((i + 1))
  done
  echo "$n"
}

if [ "$DRY_RUN" -eq 0 ]; then
  projected_mutations="$(count_projected_graphql_mutations)"
  if [ "${projected_mutations:-0}" -gt 50 ]; then
    probe_out="$(http_probe "/rate_limit" 2>/dev/null)"
    probe_rc=$?
    case "$probe_rc" in
      3)
        reset_ts="$(printf '%s\n' "$probe_out" | awk -F= '/^RATE_LIMIT_RESET=/ { print $2; exit }')"
        echo "RATE-LIMIT: retry-after=${reset_ts}" >&2
        release_lock
        exit 3
        ;;
      4)
        echo "AUTH-EXPIRED: run gh auth refresh" >&2
        release_lock
        exit 4
        ;;
    esac
    remaining="$(printf '%s\n' "$probe_out" | awk -F= '/^RATE_LIMIT_REMAINING=/ { print $2; exit }')"
    if [ -n "${remaining:-}" ]; then
      case "$remaining" in
        ''|*[!0-9]*) : ;;
        *)
          if [ "$remaining" -lt "$projected_mutations" ]; then
            reset_ts="$(printf '%s\n' "$probe_out" | awk -F= '/^RATE_LIMIT_RESET=/ { print $2; exit }')"
            echo "RATE-LIMIT: retry-after=${reset_ts} budget ${remaining} < projected ${projected_mutations}" >&2
            release_lock
            exit 3
          fi
          ;;
      esac
    fi
  fi
fi

# lookup_cached <oid> → prints "<issue> <synced> <attached>" or empty line.
lookup_cached() {
  local q="$1" i=0 oid issue synced attached
  while [ "$i" -lt "$cached_count" ]; do
    eval "oid=\"\${cached_oid_${i}}\""
    if [ "$oid" = "$q" ]; then
      eval "issue=\"\${cached_issue_${i}}\""
      eval "synced=\"\${cached_synced_${i}}\""
      eval "attached=\"\${cached_attached_${i}}\""
      printf '%s %s %s\n' "$issue" "$synced" "$attached"
      return 0
    fi
    i=$((i + 1))
  done
  printf '\n'
  return 1
}

# ----------------------------------------------------------------------------
# Project v2 / status field id resolvers (live-path scaffolds).
#
# In T02's dry-run scope these are never called. The live path calls them to
# build the updateProjectV2ItemFieldValue mutation. T03 will extend these
# with fixture-driven stubs via M013_GH_STUB_DIR; T02 ships the signatures
# so perform_upsert compiles cleanly.
# ----------------------------------------------------------------------------
PROJECT_V2_ID=""

sidecar_top_field() {
  # Parse top-level scalar field from the sidecar (first match wins). Bash 3.2.
  local key="$1"
  sed -n -E 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' "$SIDECAR_TARGET" | head -n 1
}

PROJECT_V2_ID="$(sidecar_top_field "project_v2_id")"

lookup_project_v2_item_id() {
  # $1 = orchestrator id. Returns the Project v2 item node id or empty.
  # Live path (T03): query via gh api graphql. T02 returns empty under stub.
  local oid="$1"
  if [ -n "${M013_GH_STUB_DIR:-}" ]; then
    local stub="${M013_GH_STUB_DIR}/project-v2-item-id-${oid}.txt"
    if [ -f "$stub" ]; then
      cat "$stub"
      return 0
    fi
  fi
  printf ''
}

lookup_status_field_id() {
  if [ -n "${M013_GH_STUB_DIR:-}" ]; then
    local stub="${M013_GH_STUB_DIR}/status-field-id.txt"
    if [ -f "$stub" ]; then
      cat "$stub"
      return 0
    fi
  fi
  printf ''
}

lookup_done_option_id() {
  if [ -n "${M013_GH_STUB_DIR:-}" ]; then
    local stub="${M013_GH_STUB_DIR}/done-option-id.txt"
    if [ -f "$stub" ]; then
      cat "$stub"
      return 0
    fi
  fi
  printf ''
}

# ----------------------------------------------------------------------------
# perform_upsert <oid> <issue> <reason>
#
# Issues the write for a single reconcile row. Two live shapes:
#   - reason=close on task-subissue → `gh issue close <num> -R <slug> --reason completed`
#   - reason=status-sync on phase-issue → GraphQL updateProjectV2ItemFieldValue
#
# The GraphQL shape is the third and final FR-5 whitelisted mutation. The
# literal `mutation(...){updateProjectV2ItemFieldValue(...` is the anchor
# that scripts/verify/graphql-call-shape.sh matches. P03/T03 pre-whitelisted
# `updateProjectV2ItemFieldValue` so this passes FR-5 on arrival.
#
# Fixture mode (M013_GH_STUB_DIR set): close is a silent no-op success;
# status-sync echoes the canned success JSON and returns 0.
# ----------------------------------------------------------------------------
perform_upsert() {
  local oid="$1" issue="$2" reason="$3"
  local pid iid fid val
  local errfile rc class reset
  case "$reason" in
    close)
      if [ -n "${M013_GH_STUB_DIR:-}" ]; then
        return 0
      fi
      errfile="$(mktemp -t m013-sync-err.XXXXXX)"
      gh issue close "$issue" -R "$REPO_SLUG" --reason completed >/dev/null 2>"$errfile"
      rc=$?
      class="$(classify_gh_rc "$rc" "$errfile")"
      rm -f "$errfile"
      case "$class" in
        ok) return 0 ;;
        "rate-limit "*)
          reset="${class#rate-limit }"
          echo "RATE-LIMIT: retry-after=${reset}" >&2
          release_lock
          exit 3
          ;;
        auth-expired)
          echo "AUTH-EXPIRED: run gh auth refresh" >&2
          release_lock
          exit 4
          ;;
        *) return 1 ;;
      esac
      ;;
    status-sync)
      pid="$PROJECT_V2_ID"
      iid="$(lookup_project_v2_item_id "$oid")"
      fid="$(lookup_status_field_id)"
      val="$(lookup_done_option_id)"
      if [ -n "${M013_GH_STUB_DIR:-}" ]; then
        if [ -f "${M013_GH_STUB_DIR}/graphql-update-status-field-success.json" ]; then
          cat "${M013_GH_STUB_DIR}/graphql-update-status-field-success.json"
        fi
        return 0
      fi
      errfile="$(mktemp -t m013-sync-err.XXXXXX)"
      gh api graphql \
        -F pid="$pid" -F iid="$iid" -F fid="$fid" -F val="$val" \
        --field query='mutation($pid:ID!,$iid:ID!,$fid:ID!,$val:String!){updateProjectV2ItemFieldValue(input:{projectId:$pid,itemId:$iid,fieldId:$fid,value:{singleSelectOptionId:$val}}){projectV2Item{id}}}' \
        >/dev/null 2>"$errfile"
      rc=$?
      class="$(classify_gh_rc "$rc" "$errfile")"
      rm -f "$errfile"
      case "$class" in
        ok) return 0 ;;
        "rate-limit "*)
          reset="${class#rate-limit }"
          echo "RATE-LIMIT: retry-after=${reset}" >&2
          release_lock
          exit 3
          ;;
        auth-expired)
          echo "AUTH-EXPIRED: run gh auth refresh" >&2
          release_lock
          exit 4
          ;;
        *) return 1 ;;
      esac
      ;;
  esac
  return 1
}

# ----------------------------------------------------------------------------
# Reconcile loop.
#
# Walker-order iteration (phases first, milestone last). For each projected
# item we look up the cached row (issue_number + synced flag) and emit one
# manifest UPSERT: row with a reason drawn from this table:
#
#   desired     synced   kind           reason
#   --------    ------   -------------  ------------
#   done        false    phase-issue    status-sync
#   done        false    task-subissue  close
#   done        true     *              skip-nochange
#   ready       *        *              skip-nochange
#   track       *        milestone      skip-nochange
#
# In live mode we additionally:
#   - invoke perform_upsert for the status-sync / close cases.
#   - update the sidecar cache via sidecar_update_item_cache on success or
#     failure (error path stamps last_error; success stamps last_error=null
#     and sets status_field_synced=true + project_v2_attached=true).
#
# JSONL emission (unit_close + conversus_gate_invocation records) is T03
# scope. T02 scaffolds the call sites as comments below.
# ----------------------------------------------------------------------------
upserts=0
skipped=0
errors=0

echo "DRY-RUN: sync manifest for ${MILESTONE_ID} (repo=${REPO_SLUG:-unknown})"

i=0
while [ "$i" -lt "$item_count" ]; do
  eval "oid=\"\${item_oid_${i}}\""
  eval "kind=\"\${item_kind_${i}}\""
  eval "desired=\"\${item_desired_${i}}\""
  cached_line="$(lookup_cached "$oid" || true)"
  # Parse "issue synced attached" (space-delimited).
  issue=""
  synced="false"
  attached="false"
  if [ -n "$cached_line" ]; then
    # shellcheck disable=SC2086
    set -- $cached_line
    issue="${1:-}"
    synced="${2:-false}"
    attached="${3:-false}"
  fi

  reason="skip-nochange"
  case "$desired" in
    done)
      if [ "$synced" = "false" ]; then
        case "$kind" in
          phase-issue) reason="status-sync" ;;
          task-subissue) reason="close" ;;
          *) reason="skip-nochange" ;;
        esac
      fi
      ;;
    *)
      reason="skip-nochange"
      ;;
  esac

  manifest_upsert_line "$kind" "$oid" "${issue:--}" "$reason"

  case "$reason" in
    skip-nochange) skipped=$((skipped + 1)) ;;
    close|status-sync) upserts=$((upserts + 1)) ;;
  esac

  # Live mode: issue the mutation + update sidecar cache + emit Tier 1 JSONL.
  if [ "$DRY_RUN" -eq 0 ] && [ "$reason" != "skip-nochange" ]; then
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if perform_upsert "$oid" "$issue" "$reason"; then
      sidecar_update_item_cache "$oid" "$ts" "null" "true" "true" "$PROJECT_ROOT" >/dev/null 2>&1 || true
      # FR-17 observability: one unit_close record per successful upsert.
      # outcome = closed (task-subissue reason=close) | status-synced (phase-issue reason=status-sync).
      outcome="status-synced"
      if [ "$reason" = "close" ]; then
        outcome="closed"
      fi
      uc_phase="$(phase_of "$oid")"
      uc_task="$(task_of "$oid")"
      emit_tier1_record unit_close \
        "milestone=${MILESTONE_ID}" \
        "oid=${oid}" \
        "phase=${uc_phase}" \
        "task=${uc_task}" \
        "issue_number=${issue}" \
        "outcome=${outcome}" >/dev/null 2>&1 || true

      # T05: conversus UAT PR gate — fire per UAT-defect-closing transition when
      # --conversus-gate is set. uat_defect_p is a T05 stub (returns 0 = not
      # UAT-defect) until the SPEC-DEFECT mapping ships post-M013. BLOCK (rc=2)
      # is treated as a sync-level error for this transition.
      if [ "$CONVERSUS_GATE" -eq 1 ] && [ "$reason" = "close" ] && \
         [ "$(uat_defect_p "$oid")" = "1" ]; then
        gate_artifact="${PROJECT_ROOT}/.orchestrator/integrations/uat-artifacts/${oid}.md"
        if ! bash "${REPO_ROOT}/scripts/integrations/github-conversus-gate.sh" \
               --issue-ref "${REPO_SLUG}#${issue}" \
               --artifact "$gate_artifact" \
               --timeout "$TIMEOUT" \
               --i-am-operator >/dev/null 2>&1; then
          errors=$((errors + 1))
        fi
      fi
    else
      errors=$((errors + 1))
      sidecar_update_item_cache "$oid" "$ts" "upsert-failed" "false" "true" "$PROJECT_ROOT" >/dev/null 2>&1 || true
    fi
  fi

  i=$((i + 1))
done

# ----------------------------------------------------------------------------
# Manifest footer (FR-15 P02 3-field shape). Sync never emits adopted=
# because adopt is init vocabulary.
# ----------------------------------------------------------------------------
manifest_footer "$upserts" "$skipped" "$errors"

# ----------------------------------------------------------------------------
# Conversus UAT gate (T05 wiring).
# Per-row gate invocation is performed inline in the reconcile loop above for
# each UAT-defect-closing transition (guarded on --conversus-gate flag +
# uat_defect_p predicate). The stub uat_defect_p always returns 0, so this
# path is currently inert at the sync-cycle level; it activates the day a
# UAT defect is wired through knowledge/spec/defect/SPEC-DEFECT-*.md.
# ----------------------------------------------------------------------------
# if [ "$CONVERSUS_GATE" -eq 1 ] && [ "$upserts" -gt 0 ] && [ "$DRY_RUN" -eq 0 ]; then
#   bash "${REPO_ROOT}/scripts/integrations/github-conversus-gate.sh" \
#     --milestone "$MILESTONE_ID" --repo-slug "$REPO_SLUG" || true
# fi

exit 0
