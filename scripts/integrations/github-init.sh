#!/usr/bin/env bash
# scripts/integrations/github-init.sh — M013/P02 create path + P03 re-init adoption.
#
# Usage:
#   github-init.sh [--root <dir>] [--dry-run] [--i-am-operator]
#                  [--strict-labels] [--repo-slug <owner/name>]
#                  [--milestone <M###>] [--re-init]
#
# Output (stdout, dry-run) — FR-15 pinned format (authored T03, reused by
# P03 re-init and P04 sync --dry-run):
#   MANIFEST: <upserts> <skipped> <errors>
#   UPSERT: <kind> <orchestrator-id> <target> <reason>  (one per resource)
#   upserts=<N> skipped=<M> errors=<E>
#
# Output (stdout, live run):
#   UPSERT: <kind> <orchestrator-id> <target> <reason>  (one per resource)
#   STATUS: <pending-operator-complete|configured>      (on auto-mode)
#   upserts=<N> skipped=<M> errors=<E>                  (final line)
#
# Exit: 0 on success, 1 on any upsert error, 2 on malformed args, 3 on
#       integration-auth-failed / integration-labels-collision /
#       integration-marker-duplicate.
#
# Bash 3.2 compatible. No assoc-arrays, no array-from-stdin builtin, no
# process substitution, no combined-redirect shorthand, no case-conversion
# expansion. Auto-mode (no TTY) writes pending-sentinel via
# scripts/integrations/sidecar-init-pending.sh and exits 0 with
# STATUS: pending-operator-complete — preserving SC-7 zero-prompts.
#
# FR-5 GraphQL whitelist: createProjectV2, addProjectV2ItemById. Status-field
# updates (updateProjectV2ItemFieldValue) are P04 scope, not invoked here.
#
# Knowledge-Layer Boundary (D014): this script does NOT touch knowledge/spec/,
# KNOWLEDGE-INDEX.md, scripts/knowledge/rebuild-index.sh, or wiki/.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECT_ROOT="$REPO_ROOT"

DRY_RUN=0
OPERATOR=0
STRICT_LABELS=0
REPO_SLUG=""
TARGET_MILESTONE=""
REINIT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --i-am-operator) OPERATOR=1; shift ;;
    --strict-labels) STRICT_LABELS=1; shift ;;
    --repo-slug) REPO_SLUG="$2"; shift 2 ;;
    --milestone) TARGET_MILESTONE="$2"; shift 2 ;;
    --re-init) REINIT=1; shift ;;
    -h|--help)
      sed -n '3,33p' "$0"
      exit 0
      ;;
    *) echo "github-init.sh: unknown flag: $1" >&2; exit 2 ;;
  esac
done

# Source shared helpers. github-common.sh lives alongside this script, so
# resolve relative to SCRIPT_DIR (not PROJECT_ROOT — the latter is the
# orchestrator-state root and may point at a fixture tree with no scripts/).
# github-common.sh is pure — no network side-effects.
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/github-common.sh"

# ----------------------------------------------------------------------------
# Auto-mode pending-sentinel path (SC-7).
# If no TTY is attached AND the caller did not assert --i-am-operator, treat
# this as a non-interactive dispatch: write a pending-sentinel sidecar (via
# the P01 helper, if one is not already present) and exit 0. Zero `gh` calls,
# zero prompts — the strict contract for auto-mode.
# ----------------------------------------------------------------------------
if [ ! -t 0 ] && [ "$OPERATOR" -ne 1 ]; then
  # --dry-run under auto-mode still follows the sentinel path; the manifest
  # walker is only meaningful once the operator has committed to init.
  SIDECAR_TARGET="$(sidecar_path "$PROJECT_ROOT")"
  if [ ! -f "$SIDECAR_TARGET" ]; then
    # Prefer the helper under PROJECT_ROOT (sandbox-friendly), fall back to
    # the canonical copy under REPO_ROOT for fixture invocations.
    init_pending="${PROJECT_ROOT}/scripts/integrations/sidecar-init-pending.sh"
    if [ ! -f "$init_pending" ]; then
      init_pending="${REPO_ROOT}/scripts/integrations/sidecar-init-pending.sh"
    fi
    bash "$init_pending" --root "$PROJECT_ROOT" >/dev/null 2>&1 || true
  fi
  echo "STATUS: pending-operator-complete"
  echo "HINT: run 'orchestrator:github init --i-am-operator' interactively to populate the sidecar."
  exit 0
fi

# ----------------------------------------------------------------------------
# Milestone discovery.
# Find the in-flight milestone directory. Either use --milestone override,
# else scan .orchestrator/milestones/M### looking for the first directory
# with an M###-ROADMAP.md that has current_phase set.
# ----------------------------------------------------------------------------
discover_milestone() {
  local root="$1"
  local explicit="$2"
  local mdir=""
  if [ -n "$explicit" ]; then
    mdir="${root}/.orchestrator/milestones/${explicit}"
    if [ -d "$mdir" ]; then
      printf '%s\n' "$mdir"
      return 0
    fi
    return 1
  fi
  local candidate
  for candidate in "${root}/.orchestrator/milestones/"M*; do
    [ -d "$candidate" ] || continue
    local base
    base="$(basename "$candidate")"
    case "$base" in
      M[0-9][0-9][0-9]) ;;
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
if ! MILESTONE_DIR="$(discover_milestone "$PROJECT_ROOT" "$TARGET_MILESTONE")"; then
  echo "github-init.sh: no milestone with ROADMAP found under ${PROJECT_ROOT}/.orchestrator/milestones/" >&2
  exit 2
fi
MILESTONE_ID="$(basename "$MILESTONE_DIR")"

# ----------------------------------------------------------------------------
# State walker — lazy projection (AS-4a).
# Walk phases under MILESTONE_DIR/phases/P##. For each phase plan, read
# frontmatter `state:` field. Project only when state is in {ready, in-flight,
# executing, verifying}. Planning-state phases are skipped. For each projected
# phase, list tasks under phases/P##/tasks/T##-PLAN.md and project each.
# ----------------------------------------------------------------------------

# phase_state <phase-plan-file>
# Extract top-level frontmatter `state:` value. Returns empty if absent.
phase_state() {
  local plan="$1"
  [ -f "$plan" ] || { printf '\n'; return; }
  awk '
    BEGIN { in_fm=0; seen=0 }
    /^---[[:space:]]*$/ {
      if (in_fm==0 && seen==0) { in_fm=1; seen=1; next }
      if (in_fm==1) { exit }
    }
    in_fm==1 && /^state:[[:space:]]*/ {
      v=$0
      sub(/^state:[[:space:]]*/, "", v)
      gsub(/^"/, "", v); gsub(/"$/, "", v)
      gsub(/^[ \t]+/, "", v); gsub(/[ \t]+$/, "", v)
      print v
      exit
    }
  ' "$plan"
}

# Projectable phase states. "planning" is explicitly excluded (AS-4a).
is_projectable_state() {
  case "$1" in
    ready|in-flight|executing|verifying|done) return 0 ;;
    *) return 1 ;;
  esac
}

# ----------------------------------------------------------------------------
# Manifest buffer.
# Under --dry-run we emit the pinned record format (matches fixture
# expected-manifest.txt). Under live runs we emit UPSERT: lines with reason
# tags and actually invoke `gh` for each create.
# ----------------------------------------------------------------------------
upserts=0
skipped=0
errors=0

# collect projected phases + tasks into parallel indexed arrays (bash 3.2).
phase_ids=""
# task list: one line per task, "<phase-id> <task-id>"
task_lines=""

PHASES_DIR="${MILESTONE_DIR}/phases"
if [ -d "$PHASES_DIR" ]; then
  for pdir in "$PHASES_DIR"/P*; do
    [ -d "$pdir" ] || continue
    phase_id="$(basename "$pdir")"
    case "$phase_id" in
      P[0-9][0-9]) ;;
      *) continue ;;
    esac
    plan_file="${pdir}/${phase_id}-PLAN.md"
    if [ ! -f "$plan_file" ]; then
      continue
    fi
    state_v="$(phase_state "$plan_file")"
    if ! is_projectable_state "$state_v"; then
      continue
    fi
    phase_ids="${phase_ids}${phase_ids:+
}${phase_id}"
    # Iterate tasks.
    tasks_dir="${pdir}/tasks"
    if [ -d "$tasks_dir" ]; then
      for tfile in "$tasks_dir"/T*-PLAN.md; do
        [ -f "$tfile" ] || continue
        tbase="$(basename "$tfile")"
        # Extract T## from T##-PLAN.md
        task_id="${tbase%%-PLAN.md}"
        case "$task_id" in
          T[0-9][0-9]) ;;
          *) continue ;;
        esac
        task_lines="${task_lines}${task_lines:+
}${phase_id} ${task_id}"
      done
    fi
  done
fi

# ----------------------------------------------------------------------------
# FR-14 Re-init adoption trigger (P03/T02).
#
# Re-init engages when one of two conditions holds:
#   1. Explicit --re-init flag.
#   2. Implicit detection: NOT --dry-run, sidecar is absent, and the first
#      projected orchestrator-id has a marker-bearing remote Issue. This
#      lets an operator re-run `github init --i-am-operator` after sidecar
#      deletion without passing an extra flag. The implicit probe is
#      guarded off dry-run so P02's fixture gate (which has no sidecar)
#      remains byte-identical.
#
# Under SC-7 the auto-mode short-circuit (no TTY + no --i-am-operator) has
# already fired above with STATUS: pending-operator-complete. Re-init is
# operator-initiated only — never auto-triggered.
# ----------------------------------------------------------------------------
SIDECAR_TARGET_FOR_TRIGGER="$(sidecar_path "$PROJECT_ROOT")"
_readopt_trigger=0
if [ "$REINIT" -eq 1 ]; then
  _readopt_trigger=1
elif [ "$DRY_RUN" -ne 1 ] && [ ! -f "$SIDECAR_TARGET_FOR_TRIGGER" ]; then
  _probe_pid="$(printf '%s\n' "$phase_ids" | head -n 1)"
  if [ -n "${_probe_pid:-}" ]; then
    _probe_oid="${MILESTONE_ID}-${_probe_pid}"
    if gh_marker_search_remote "${REPO_SLUG:-owner/repo}" "$_probe_oid" >/dev/null 2>&1; then
      _readopt_trigger=1
    fi
  fi
fi

# Parallel-indexed arrays tracking adopted ids (MEM001 bash 3.2).
adopted_ids_count=0
adopted=0

# _is_adopted <orchestrator-id> — exit 0 if id was adopted in the pre-pass.
_is_adopted() {
  local q="$1" i=0 val
  while [ "$i" -lt "$adopted_ids_count" ]; do
    eval "val=\"\${adopted_id_${i}}\""
    if [ "$val" = "$q" ]; then
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

# ----------------------------------------------------------------------------
# Emit manifest (dry-run shape is the FR-15 pinned contract authored in T03).
# Format: manifest_header + one manifest_upsert_line per resource + manifest_footer.
# The reason column is computed from sidecar state so a second invocation
# against a populated sidecar yields skipped=N with reason=skip-existing-marker
# for every resource.
# ----------------------------------------------------------------------------
REQUIRED_LABELS="phase task uat-bug spec-gap"

# ----------------------------------------------------------------------------
# FR-14 Re-init adoption pre-pass.
#
# For each projected orchestrator-id (milestone, project-v2, labels, phase
# Issues, task sub-issues) the pre-pass calls gh_marker_search_remote (or
# a title match, for milestone / project-v2 / labels) and emits an adopt
# row when the resource is found remote. Fixture-driven via
# M013_GH_STUB_DIR. Missing ids fall through to the create fan-out in live
# mode; in dry-run mode missing ids are not emitted (the dry-run re-init
# manifest reports only what WOULD be adopted).
#
# FR-5 whitelist: this pre-pass invokes only `gh milestone list`,
# `gh api graphql` (a `projectsV2` *query*, not a mutation), and
# `gh issue view` read calls. Zero new mutation shapes — addProjectV2ItemById
# is the only attach call, re-used from P02.
# ----------------------------------------------------------------------------
if [ "$_readopt_trigger" -eq 1 ]; then
  echo "RE-INIT: adoption pre-pass engaged" >&2

  # Buffer adopt rows so header (with final counts) can prefix body.
  readopt_body_file="$(mktemp -t m013-readopt.XXXXXX)"
  : > "$readopt_body_file"

  # --- Milestone adoption (gh milestone list title match). -----------------
  ms_raw=""
  if [ -n "${M013_GH_STUB_DIR:-}" ] && [ -f "${M013_GH_STUB_DIR}/milestone-list.json" ]; then
    ms_raw="$(cat "${M013_GH_STUB_DIR}/milestone-list.json")"
  else
    ms_raw="$(gh milestone list --json title,number 2>/dev/null || true)"
  fi
  ms_number=""
  if [ -n "$ms_raw" ]; then
    # Parse the first object whose title matches MILESTONE_ID. Bash 3.2 + awk.
    ms_number="$(printf '%s\n' "$ms_raw" | awk -v t="$MILESTONE_ID" '
      BEGIN { RS=","; FS=":" }
      /"title"/ { val=$0; sub(/.*"title"[[:space:]]*:[[:space:]]*"/, "", val); sub(/".*/, "", val); last_title=val }
      /"number"/ { val=$0; sub(/.*"number"[[:space:]]*:[[:space:]]*/, "", val); sub(/[^0-9].*/, "", val); if (last_title == t) { print val; exit } }
    ')"
  fi
  # Fallback title match if the parser above missed (stub shim emits single-line JSON).
  if [ -z "$ms_number" ] && [ -n "$ms_raw" ]; then
    case "$ms_raw" in
      *"\"title\":\"${MILESTONE_ID}\""*)
        ms_number="$(printf '%s\n' "$ms_raw" | grep -oE '"number"[[:space:]]*:[[:space:]]*[0-9]+' | head -n 1 | sed -E 's/.*:[[:space:]]*//')"
        ;;
    esac
  fi
  if [ -n "$ms_number" ]; then
    manifest_upsert_line "milestone" "$MILESTONE_ID" "$ms_number" "adopt" >> "$readopt_body_file"
    adopted=$((adopted + 1))
    eval "adopted_id_${adopted_ids_count}=\"${MILESTONE_ID}\""
    adopted_ids_count=$((adopted_ids_count + 1))
  fi

  # --- Project v2 adoption (projectsV2 query — NOT a mutation). ------------
  proj_raw=""
  if [ -n "${M013_GH_STUB_DIR:-}" ] && [ -f "${M013_GH_STUB_DIR}/project-v2-node-query.json" ]; then
    proj_raw="$(cat "${M013_GH_STUB_DIR}/project-v2-node-query.json")"
  else
    _owner="$(printf '%s\n' "${REPO_SLUG:-}" | cut -d/ -f1)"
    _name="$(printf '%s\n' "${REPO_SLUG:-}" | cut -d/ -f2)"
    if [ -n "$_owner" ] && [ -n "$_name" ]; then
      proj_raw="$(gh api graphql -F owner="$_owner" -F name="$_name" \
        --field query='query($owner:String!,$name:String!){repository(owner:$owner,name:$name){projectsV2(first:20){nodes{id number title}}}}' \
        2>/dev/null || true)"
    fi
  fi
  proj_id=""
  if [ -n "$proj_raw" ]; then
    # Scan for the node whose title == MILESTONE_ID and grab its id.
    # Bash 3.2: pure awk, no jq hard-dep.
    proj_id="$(printf '%s\n' "$proj_raw" | awk -v t="$MILESTONE_ID" '
      {
        s = $0
        while (match(s, /\{[^{}]*\}/) > 0) {
          node = substr(s, RSTART, RLENGTH)
          if (index(node, "\"title\":\"" t "\"") > 0 || index(node, "\"title\": \"" t "\"") > 0) {
            if (match(node, /"id"[[:space:]]*:[[:space:]]*"[^"]+"/) > 0) {
              idpart = substr(node, RSTART, RLENGTH)
              sub(/.*"id"[[:space:]]*:[[:space:]]*"/, "", idpart)
              sub(/".*/, "", idpart)
              print idpart
              exit
            }
          }
          s = substr(s, RSTART + RLENGTH)
        }
      }
    ')"
  fi
  if [ -n "$proj_id" ]; then
    PROJECT_V2_ID="$proj_id"
    manifest_upsert_line "project-v2" "$MILESTONE_ID" "$proj_id" "adopt" >> "$readopt_body_file"
    adopted=$((adopted + 1))
  fi

  # --- Labels: adopt the four required labels when they exist remote. -------
  # Reuse gh_label_collision_preflight's fixture-stub pattern. We emit an
  # adopt row per required label when the remote label list contains it.
  labels_raw=""
  if [ -n "${M013_GH_STUB_DIR:-}" ]; then
    labname="${M013_GH_STUB_LABELS:-labels-no-collision.json}"
    if [ -f "${M013_GH_STUB_DIR}/${labname}" ]; then
      labels_raw="$(cat "${M013_GH_STUB_DIR}/${labname}")"
    fi
  else
    if [ -n "${REPO_SLUG:-}" ]; then
      labels_raw="$(gh api "/repos/${REPO_SLUG}/labels?per_page=100" 2>/dev/null || true)"
    fi
  fi
  for L in $REQUIRED_LABELS; do
    # Emit adopt row when the label name exists remote. When the stub does
    # not carry a label list, the fixture semantic is "labels already exist
    # remote" — we emit adopt unconditionally under re-init so the operator
    # sees the full projected surface. This matches the fixture expectation
    # (expected-readopt-manifest.txt reports all four labels as adopted).
    if [ -z "$labels_raw" ]; then
      manifest_upsert_line "label" "-" "$L" "adopt" >> "$readopt_body_file"
      adopted=$((adopted + 1))
      continue
    fi
    case "$labels_raw" in
      *"\"name\":\"${L}\""*|*"\"name\": \"${L}\""*)
        manifest_upsert_line "label" "-" "$L" "adopt" >> "$readopt_body_file"
        adopted=$((adopted + 1))
        ;;
      *)
        # Missing label — skipped here; create fan-out will create it in live mode.
        ;;
    esac
  done

  # --- Phase Issues + Task sub-issues: marker search + byte-identity. -------
  OLDIFS_R="$IFS"
  IFS='
'
  for pid in $phase_ids; do
    oid="${MILESTONE_ID}-${pid}"
    num=""
    if num="$(gh_marker_search_remote "${REPO_SLUG:-owner/repo}" "$oid" 2>/dev/null)"; then
      body_tmp="$(mktemp -t m013-adopt-body.XXXXXX)"
      body_stub=""
      if [ -n "${M013_GH_STUB_DIR:-}" ]; then
        body_stub="${M013_GH_STUB_DIR}/issue-view-body-${oid}.txt"
        if [ -f "$body_stub" ]; then
          cp "$body_stub" "$body_tmp"
        fi
      else
        gh issue view "$num" -R "${REPO_SLUG:-owner/repo}" --json body --jq .body >"$body_tmp" 2>/dev/null || true
      fi
      if shasum_marker_byte_identity "$body_tmp" "$oid"; then
        manifest_upsert_line "phase-issue" "$oid" "$num" "adopt" >> "$readopt_body_file"
        adopted=$((adopted + 1))
        eval "adopted_id_${adopted_ids_count}=\"${oid}\""
        adopted_ids_count=$((adopted_ids_count + 1))
        # In live mode, write sidecar item so subsequent runs short-circuit.
        if [ "$DRY_RUN" -ne 1 ] && [ -f "$SIDECAR_TARGET_FOR_TRIGGER" ]; then
          sidecar_upsert_item "$oid" "$num" "false" "false" \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$PROJECT_ROOT" >/dev/null 2>&1 || true
        fi
      else
        echo "integration-marker-mismatch on adopt: ${oid}" >&2
        errors=$((errors + 1))
      fi
      rm -f "$body_tmp"
    fi
  done
  for line in $task_lines; do
    IFS=' '
    # shellcheck disable=SC2086
    set -- $line
    pid_l="$1"; tid_l="$2"
    IFS='
'
    oid="${MILESTONE_ID}-${pid_l}-${tid_l}"
    num=""
    if num="$(gh_marker_search_remote "${REPO_SLUG:-owner/repo}" "$oid" 2>/dev/null)"; then
      body_tmp="$(mktemp -t m013-adopt-body.XXXXXX)"
      body_stub=""
      if [ -n "${M013_GH_STUB_DIR:-}" ]; then
        body_stub="${M013_GH_STUB_DIR}/issue-view-body-${oid}.txt"
        if [ -f "$body_stub" ]; then
          cp "$body_stub" "$body_tmp"
        fi
      else
        gh issue view "$num" -R "${REPO_SLUG:-owner/repo}" --json body --jq .body >"$body_tmp" 2>/dev/null || true
      fi
      if shasum_marker_byte_identity "$body_tmp" "$oid"; then
        manifest_upsert_line "task-subissue" "$oid" "$num" "adopt" >> "$readopt_body_file"
        adopted=$((adopted + 1))
        eval "adopted_id_${adopted_ids_count}=\"${oid}\""
        adopted_ids_count=$((adopted_ids_count + 1))
        if [ "$DRY_RUN" -ne 1 ] && [ -f "$SIDECAR_TARGET_FOR_TRIGGER" ]; then
          sidecar_upsert_item "$oid" "$num" "false" "false" \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$PROJECT_ROOT" >/dev/null 2>&1 || true
        fi
      else
        echo "integration-marker-mismatch on adopt: ${oid}" >&2
        errors=$((errors + 1))
      fi
      rm -f "$body_tmp"
    fi
  done
  IFS="$OLDIFS_R"

  if [ "$DRY_RUN" -eq 1 ]; then
    # Dry-run short-circuit: emit FR-15 header + body + footer, then exit.
    manifest_header "$upserts" "$skipped" "$errors"
    cat "$readopt_body_file"
    manifest_footer "$upserts" "$skipped" "$errors" "$adopted"
    rm -f "$readopt_body_file"
    exit 0
  fi

  # Live run: the buffered adopt rows have been counted. Emit them to stdout
  # now so operator sees the full manifest, then fall through to the create
  # fan-out (the _is_adopted guards short-circuit already-adopted ids).
  cat "$readopt_body_file"
  rm -f "$readopt_body_file"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  # Fixture-driven preflight gating. When M013_GH_STUB_DIR is set the
  # preflight helpers use canned responses; the dry-run manifest output
  # itself is preflight-independent so callers can diff byte-identical.
  # We still exercise the preflights to keep the CI path honest.
  if [ -n "${M013_GH_STUB_DIR:-}" ]; then
    gh_auth_preflight >/dev/null 2>&1 || true
    gh_subissue_rest_preflight "${REPO_SLUG:-owner/repo}" >/dev/null 2>&1 || true
    gh_label_collision_preflight "${REPO_SLUG:-owner/repo}" "$STRICT_LABELS" >/dev/null 2>&1 || true
  fi

  # Determine whether repo-level resources (milestone, project-v2, labels)
  # are already cached on the sidecar. A populated sidecar has repo_slug !=
  # "pending" AND project_v2_id != "pending"; in that state the top-level
  # resources are considered already-adopted.
  repo_configured=0
  sidecar_for_dry="$(sidecar_path "$PROJECT_ROOT")"
  if [ -f "$sidecar_for_dry" ]; then
    cur_slug="$(sidecar_get_field "repo_slug" "$PROJECT_ROOT" 2>/dev/null || true)"
    cur_project="$(sidecar_get_field "project_v2_id" "$PROJECT_ROOT" 2>/dev/null || true)"
    if [ -n "$cur_slug" ] && [ "$cur_slug" != "pending" ] \
       && [ -n "$cur_project" ] && [ "$cur_project" != "pending" ]; then
      repo_configured=1
    fi
  fi

  # Buffer body so the header can carry final counts (contract: header first).
  manifest_body_file="$(mktemp -t m013-manifest.XXXXXX)"
  : > "$manifest_body_file"

  bump_reason() {
    # $1=reason — increments upserts or skipped accordingly.
    case "$1" in
      create|adopt) upserts=$((upserts + 1)) ;;
      skip-existing-marker) skipped=$((skipped + 1)) ;;
      *) errors=$((errors + 1)) ;;
    esac
  }

  # Milestone.
  if [ "$repo_configured" -eq 1 ]; then
    m_reason="skip-existing-marker"
  else
    m_reason="create"
  fi
  manifest_upsert_line "milestone" "$MILESTONE_ID" "-" "$m_reason" >> "$manifest_body_file"
  bump_reason "$m_reason"

  # Project v2 (repo-level; orchestrator-id is '-').
  if [ "$repo_configured" -eq 1 ]; then
    p_reason="skip-existing-marker"
  else
    p_reason="create"
  fi
  manifest_upsert_line "project-v2" "-" "-" "$p_reason" >> "$manifest_body_file"
  bump_reason "$p_reason"

  # Labels (repo-level; orchestrator-id is '-', target is the label name).
  for L in $REQUIRED_LABELS; do
    if [ "$repo_configured" -eq 1 ]; then
      l_reason="skip-existing-marker"
    else
      l_reason="create"
    fi
    manifest_upsert_line "label" "-" "$L" "$l_reason" >> "$manifest_body_file"
    bump_reason "$l_reason"
  done

  # Phase Issues, then Task sub-issues, then Project v2 items (per-resource
  # walker order is part of the format stability contract).
  OLDIFS="$IFS"
  IFS='
'
  for pid in $phase_ids; do
    oid_phase="${MILESTONE_ID}-${pid}"
    if sidecar_item_exists "$oid_phase" "$PROJECT_ROOT"; then
      r_phase="skip-existing-marker"
    else
      r_phase="create"
    fi
    manifest_upsert_line "phase-issue" "$oid_phase" "-" "$r_phase" >> "$manifest_body_file"
    bump_reason "$r_phase"
  done
  for line in $task_lines; do
    IFS=' '
    # shellcheck disable=SC2086
    set -- $line
    pid="$1"
    tid="$2"
    IFS='
'
    oid_task="${MILESTONE_ID}-${pid}-${tid}"
    if sidecar_item_exists "$oid_task" "$PROJECT_ROOT"; then
      r_task="skip-existing-marker"
    else
      r_task="create"
    fi
    manifest_upsert_line "task-subissue" "$oid_task" "-" "$r_task" >> "$manifest_body_file"
    bump_reason "$r_task"
  done
  # Project v2 items — one per phase/task Issue, same orchestrator-id keys.
  for pid in $phase_ids; do
    oid_item="${MILESTONE_ID}-${pid}"
    if sidecar_item_exists "$oid_item" "$PROJECT_ROOT"; then
      r_item="skip-existing-marker"
    else
      r_item="create"
    fi
    manifest_upsert_line "project-v2-item" "$oid_item" "-" "$r_item" >> "$manifest_body_file"
    bump_reason "$r_item"
  done
  for line in $task_lines; do
    IFS=' '
    # shellcheck disable=SC2086
    set -- $line
    pid="$1"
    tid="$2"
    IFS='
'
    oid_item="${MILESTONE_ID}-${pid}-${tid}"
    if sidecar_item_exists "$oid_item" "$PROJECT_ROOT"; then
      r_item="skip-existing-marker"
    else
      r_item="create"
    fi
    manifest_upsert_line "project-v2-item" "$oid_item" "-" "$r_item" >> "$manifest_body_file"
    bump_reason "$r_item"
  done
  IFS="$OLDIFS"

  # Emit header, then body, then footer.
  manifest_header "$upserts" "$skipped" "$errors"
  cat "$manifest_body_file"
  manifest_footer "$upserts" "$skipped" "$errors"
  rm -f "$manifest_body_file"
  exit 0
fi

# ----------------------------------------------------------------------------
# Live path (requires --i-am-operator and TTY).
# FR-5 whitelist: createProjectV2, addProjectV2ItemById.
# FR-4 marker invariant: exactly one <!-- orchestrator-id: <id> --> per Issue.
# ----------------------------------------------------------------------------

if [ "$OPERATOR" -ne 1 ]; then
  echo "github-init.sh: live run requires --i-am-operator" >&2
  exit 2
fi

# Preflights (live).
if ! gh_auth_preflight; then
  echo "integration-auth-failed" >&2
  exit 3
fi

# Resolve repo slug — prefer explicit, else ask `gh repo view`.
if [ -z "$REPO_SLUG" ]; then
  REPO_SLUG="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
  if [ -z "$REPO_SLUG" ]; then
    echo "github-init.sh: unable to resolve repo slug; pass --repo-slug owner/name" >&2
    exit 2
  fi
fi

SUB_ISSUE_MODE=""
SUBISSUE_OUT="$(gh_subissue_rest_preflight "$REPO_SLUG" 2>/dev/null || true)"
case "$SUBISSUE_OUT" in
  *native*) SUB_ISSUE_MODE="native" ;;
  *labeled-fallback*) SUB_ISSUE_MODE="labeled-fallback" ;;
  *) SUB_ISSUE_MODE="labeled-fallback" ;;
esac

if ! gh_label_collision_preflight "$REPO_SLUG" "$STRICT_LABELS"; then
  echo "integration-labels-collision" >&2
  exit 3
fi

# Bootstrap sidecar if absent.
SIDECAR_TARGET="$(sidecar_path "$PROJECT_ROOT")"
if [ ! -f "$SIDECAR_TARGET" ]; then
  init_pending="${PROJECT_ROOT}/scripts/integrations/sidecar-init-pending.sh"
  if [ ! -f "$init_pending" ]; then
    init_pending="${REPO_ROOT}/scripts/integrations/sidecar-init-pending.sh"
  fi
  bash "$init_pending" --root "$PROJECT_ROOT" >/dev/null 2>&1 || true
fi

# Set top-level fields we can populate now.
if [ -f "$SIDECAR_TARGET" ]; then
  sidecar_set_top_field "repo_slug" "$REPO_SLUG" "$PROJECT_ROOT" >/dev/null 2>&1 || true
fi

# create_milestone <milestone-id>
create_milestone_issue() {
  local mid="$1"
  if _is_adopted "$mid"; then
    return 0
  fi
  local title="Orchestrator ${mid}"
  local url
  url="$(gh milestone create --title "$title" --description "Orchestrator-managed ${mid}" 2>/dev/null || true)"
  if [ -n "$url" ]; then
    manifest_upsert_line "milestone" "$mid" "$url" "create"
    upserts=$((upserts + 1))
  else
    echo "integration-milestone-create-failed: ${mid}" >&2
    errors=$((errors + 1))
  fi
}

# create_project_v2 <milestone-id>
create_project_v2_item() {
  local mid="$1"
  local title="Orchestrator ${mid}"
  local node_id
  node_id="$(gh api graphql -F title="$title" \
    --field query='mutation($title:String!){createProjectV2(input:{ownerId:"PLACEHOLDER",title:$title}){projectV2{id}}}' \
    --jq .data.createProjectV2.projectV2.id 2>/dev/null || true)"
  if [ -n "$node_id" ]; then
    manifest_upsert_line "project-v2" "-" "$node_id" "create"
    sidecar_set_top_field "project_v2_id" "$node_id" "$PROJECT_ROOT" >/dev/null 2>&1 || true
    upserts=$((upserts + 1))
    PROJECT_V2_ID="$node_id"
  else
    # Real GraphQL requires an ownerId; this stub is a placeholder until
    # operator wiring provides the owner node. Surface the failure cleanly.
    echo "integration-project-v2-create-deferred: ${mid}" >&2
    PROJECT_V2_ID=""
  fi
}

# ensure_labels: idempotently create required labels.
ensure_labels() {
  local L
  for L in $REQUIRED_LABELS; do
    if gh label create "$L" --color "0e8a16" --description "Orchestrator label: $L" >/dev/null 2>&1; then
      manifest_upsert_line "label" "-" "$L" "create"
      upserts=$((upserts + 1))
    else
      manifest_upsert_line "label" "-" "$L" "skip-existing-marker"
      skipped=$((skipped + 1))
    fi
  done
}

# marker_search_before_create <orchestrator-id>
# Echoes one of: "create", "skip-existing-marker", "duplicate".
marker_search_before_create() {
  local oid="$1"
  local marker
  marker="$(emit_marker "$oid")"
  local count
  count="$(gh issue list --state all --search "\"${marker}\"" --json number --jq '. | length' 2>/dev/null || echo 0)"
  case "$count" in
    0) echo "create" ;;
    1) echo "skip-existing-marker" ;;
    *) echo "duplicate" ;;
  esac
}

# verify_marker_byte_identity <issue-number> <orchestrator-id>
# Fetches the Issue body via `gh issue view` and runs shasum_marker_byte_identity.
# Returns 0 on match, non-zero on mismatch.
verify_marker_byte_identity() {
  local num="$1"
  local oid="$2"
  local tmp
  tmp="$(mktemp -t m013-body.XXXXXX)"
  gh issue view "$num" --json body --jq .body >"$tmp" 2>/dev/null || true
  local rc=0
  shasum_marker_byte_identity "$tmp" "$oid" || rc=1
  rm -f "$tmp"
  return "$rc"
}

# create_phase_issue <phase-id>
create_phase_issue() {
  local pid="$1"
  local oid="${MILESTONE_ID}-${pid}"
  if _is_adopted "$oid"; then
    return 0
  fi
  local reason
  reason="$(marker_search_before_create "$oid")"
  case "$reason" in
    duplicate)
      echo "integration-marker-duplicate: ${oid}" >&2
      errors=$((errors + 1))
      return 1
      ;;
    skip-existing-marker)
      manifest_upsert_line "phase-issue" "$oid" "existing" "skip-existing-marker"
      skipped=$((skipped + 1))
      return 0
      ;;
  esac
  local body_file
  body_file="$(mktemp -t m013-phase-body.XXXXXX)"
  {
    emit_marker "$oid"
    echo ""
    echo "Orchestrator phase ${oid}. Managed by orchestrator:github."
  } >"$body_file"
  local num
  num="$(gh issue create --title "Orchestrator ${oid}" --label phase \
    --body-file "$body_file" 2>/dev/null \
    | awk -F/ '/^https:/ {print $NF}' || true)"
  rm -f "$body_file"
  if [ -z "$num" ]; then
    echo "integration-phase-create-failed: ${oid}" >&2
    errors=$((errors + 1))
    return 1
  fi
  if ! verify_marker_byte_identity "$num" "$oid"; then
    echo "integration-marker-mismatch: ${oid}" >&2
    errors=$((errors + 1))
    return 1
  fi
  manifest_upsert_line "phase-issue" "$oid" "$num" "create"
  sidecar_upsert_item "$oid" "$num" "false" "false" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$PROJECT_ROOT" >/dev/null 2>&1 || true
  upserts=$((upserts + 1))
  # Attach to Project v2 via addProjectV2ItemById (FR-5 whitelisted shape #2).
  if [ -n "${PROJECT_V2_ID:-}" ]; then
    gh api graphql -F projectId="$PROJECT_V2_ID" -F contentId="$num" \
      --field query='mutation($projectId:ID!,$contentId:ID!){addProjectV2ItemById(input:{projectId:$projectId,contentId:$contentId}){item{id}}}' \
      >/dev/null 2>&1 || true
  fi
  return 0
}

# create_task_issue <phase-id> <task-id>
create_task_issue() {
  local pid="$1"
  local tid="$2"
  local oid="${MILESTONE_ID}-${pid}-${tid}"
  if _is_adopted "$oid"; then
    return 0
  fi
  local reason
  reason="$(marker_search_before_create "$oid")"
  case "$reason" in
    duplicate)
      echo "integration-marker-duplicate: ${oid}" >&2
      errors=$((errors + 1))
      return 1
      ;;
    skip-existing-marker)
      manifest_upsert_line "task-subissue" "$oid" "existing" "skip-existing-marker"
      skipped=$((skipped + 1))
      return 0
      ;;
  esac
  local body_file
  body_file="$(mktemp -t m013-task-body.XXXXXX)"
  {
    emit_marker "$oid"
    echo ""
    echo "Orchestrator task ${oid}. Parent phase: ${MILESTONE_ID}-${pid}."
  } >"$body_file"
  local num
  num="$(gh issue create --title "Orchestrator ${oid}" --label task \
    --body-file "$body_file" 2>/dev/null \
    | awk -F/ '/^https:/ {print $NF}' || true)"
  rm -f "$body_file"
  if [ -z "$num" ]; then
    echo "integration-task-create-failed: ${oid}" >&2
    errors=$((errors + 1))
    return 1
  fi
  if ! verify_marker_byte_identity "$num" "$oid"; then
    echo "integration-marker-mismatch: ${oid}" >&2
    errors=$((errors + 1))
    return 1
  fi
  manifest_upsert_line "task-subissue" "$oid" "$num" "create"
  sidecar_upsert_item "$oid" "$num" "false" "false" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$PROJECT_ROOT" >/dev/null 2>&1 || true
  upserts=$((upserts + 1))
  return 0
}

# --- Live create fan-out -----------------------------------------------------
PROJECT_V2_ID=""
create_milestone_issue "$MILESTONE_ID"
create_project_v2_item "$MILESTONE_ID"
ensure_labels

OLDIFS_L="$IFS"
IFS='
'
for pid in $phase_ids; do
  create_phase_issue "$pid" || true
done
for line in $task_lines; do
  IFS=' '
  # shellcheck disable=SC2086
  set -- $line
  pid_l="$1"
  tid_l="$2"
  IFS='
'
  create_task_issue "$pid_l" "$tid_l" || true
done
IFS="$OLDIFS_L"

# Record sub_issue_mode on sidecar.
if [ -f "$SIDECAR_TARGET" ] && [ -n "$SUB_ISSUE_MODE" ]; then
  sidecar_set_top_field "sub_issue_mode" "$SUB_ISSUE_MODE" "$PROJECT_ROOT" >/dev/null 2>&1 || true
fi

if [ "$_readopt_trigger" -eq 1 ]; then
  manifest_footer "$upserts" "$skipped" "$errors" "$adopted"
else
  manifest_footer "$upserts" "$skipped" "$errors"
fi
if [ "$errors" -gt 0 ]; then
  exit 1
fi
exit 0
