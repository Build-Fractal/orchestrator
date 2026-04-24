#!/usr/bin/env bash
# scripts/dispatch/lib/section-handlers.sh — Per-source-type section assembly
[ -n "${_SECTION_HANDLERS_SOURCED:-}" ] && return 0
_SECTION_HANDLERS_SOURCED=1
#
# Pure section-assembly library for recipe-driven build-context.sh. Every
# handler is a function that takes common orchestrator coordinates and prints
# the assembled section body to stdout. Handlers do NOT emit events, do NOT
# call emit_result, and do NOT read YAML — they are pure mechanics. The caller
# (build-context.sh) parses the recipe via scripts/lib/recipe-parser.sh and
# dispatches each section to the right handler here.
#
# Functions (all Bash 3.2 compatible):
#
#   handle_computed        <orch_root> <milestone> <phase> <task> <section_name>
#   handle_phase_summaries <orch_root> <milestone> <phase> <task>
#   handle_phase_plan      <orch_root> <milestone> <phase> <task>
#   handle_task_plan       <orch_root> <milestone> <phase> <task>
#   handle_template        <orch_root> <milestone> <phase> <task> <section_name>
#   handle_knowledge       <orch_root> <milestone> <phase> <task> [<included_ids_file>]
#   handle_decisions       <orch_root> <milestone> <phase> <task>
#   handle_file            <orch_root> <milestone> <phase> <task> <source_filename>
#   dispatch_section_handler <source> <section_name> <orch_root> <milestone> <phase> <task> [<included_ids_file>]
#
# Resolution rules shared by all handlers:
#   - <orch_root> may be either .orchestrator OR a fixture milestone dir
#     (the caller has already normalized this). Handlers derive the milestone
#     directory as: "${orch_root}/milestones/${milestone}" if that exists, else
#     they fall back to treating <orch_root> as the milestone dir.
#
# Constitution: Principle X (Templating Over Inference), Principle XI (Single
# Source of Truth). AP-001 compliance: no process substitution in while loops.

# --- Sibling path anchors ---
_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SH_DISPATCH_DIR="$(cd "${_SH_DIR}/.." && pwd)"
_SH_PROJECT_ROOT="$(cd "${_SH_DISPATCH_DIR}/.." && pwd)"

_SH_SCOPE_FILTER="${_SH_DISPATCH_DIR}/scope-filter.sh"
_SH_TRAVERSE_GRAPH="${_SH_PROJECT_ROOT}/knowledge/traverse-graph.sh"
_SH_RESOLVE_ENTRIES="${_SH_PROJECT_ROOT}/knowledge/resolve-entries.sh"
_SH_INCREMENT_HITS="${_SH_PROJECT_ROOT}/knowledge/increment-hits.sh"
_SH_READ_ROADMAP="${_SH_PROJECT_ROOT}/state/read-roadmap.sh"
_SH_READ_CONFIG="${_SH_PROJECT_ROOT}/state/read-config.sh"

# _sh_resolve_milestone_dir <orch_root> <milestone>
# Prints the milestone directory path. Supports both .orchestrator
# layout and fixture layout where orch_root IS the milestone dir.
_sh_resolve_milestone_dir() {
  local orch_root="$1"
  local milestone="$2"
  if [ -d "${orch_root}/milestones/${milestone}" ]; then
    printf '%s\n' "${orch_root}/milestones/${milestone}"
  elif [ -d "${orch_root}/phases" ]; then
    printf '%s\n' "${orch_root}"
  else
    return 1
  fi
}

# handle_computed <orch_root> <milestone> <phase> <task> <section_name>
# Returns a computed block. Currently only "state" is supported: prints the
# State Context block with milestone/phase/task/tier fields.
handle_computed() {
  local orch_root="$1" milestone="$2" phase="$3" task="$4" section_name="$5"
  local ms_dir
  ms_dir="$(_sh_resolve_milestone_dir "$orch_root" "$milestone")" || return 1

  case "$section_name" in
    state|State|STATE)
      local roadmap="${ms_dir}/${milestone}-ROADMAP.md"
      local tier="unknown"
      if [ -f "$roadmap" ] && [ -x "$_SH_READ_ROADMAP" ]; then
        tier="$(bash "$_SH_READ_ROADMAP" "$roadmap" tier 2>/dev/null || echo unknown)"
      fi
      printf '## State Context\n\n'
      printf -- '- **Current State**: executing\n'
      printf -- '- **Milestone**: %s\n' "$milestone"
      printf -- '- **Phase**: %s\n' "$phase"
      if [ "$task" != "PHASE_PLAN" ]; then
        printf -- '- **Task**: %s\n' "$task"
      fi
      printf -- '- **Tier**: %s\n' "$tier"
      ;;
    *)
      printf 'section-handlers: unknown computed section: %s\n' "$section_name" >&2
      return 1
      ;;
  esac
}

# handle_phase_summaries <orch_root> <milestone> <phase> <task>
# Concatenates upstream phase summaries. Upstream phases are read from the
# roadmap "depends" field for the current phase. Prints "## Upstream Context"
# header followed by "### <PhaseID> Summary" blocks with the summary body.
handle_phase_summaries() {
  local orch_root="$1" milestone="$2" phase="$3"
  local ms_dir
  ms_dir="$(_sh_resolve_milestone_dir "$orch_root" "$milestone")" || return 1
  local roadmap="${ms_dir}/${milestone}-ROADMAP.md"
  printf '## Upstream Context\n\n'
  if [ ! -f "$roadmap" ] || [ ! -x "$_SH_READ_ROADMAP" ]; then
    printf 'No upstream summaries available.\n'
    return 0
  fi
  local phase_data depends
  phase_data="$(bash "$_SH_READ_ROADMAP" "$roadmap" phase "$phase" 2>/dev/null || true)"
  depends="none"
  if [ -n "$phase_data" ]; then
    depends="$(printf '%s' "$phase_data" | awk '{print $4}')"
  fi
  if [ -z "$depends" ] || [ "$depends" = "none" ]; then
    printf 'No upstream summaries available.\n'
    return 0
  fi
  local dep_list_file any_printed
  dep_list_file="$(mktemp)"
  printf '%s' "$depends" | tr ',' '\n' > "$dep_list_file"
  any_printed=0
  local dep
  while IFS= read -r dep; do
    dep="$(printf '%s' "$dep" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -z "$dep" ] && continue
    local summary_file="${ms_dir}/phases/${dep}/${dep}-SUMMARY.md"
    if [ -f "$summary_file" ]; then
      printf '### %s Summary\n' "$dep"
      cat "$summary_file"
      printf '\n'
      any_printed=1
    fi
  done < "$dep_list_file"
  rm -f "$dep_list_file"
  if [ "$any_printed" -eq 0 ]; then
    printf 'No upstream summaries available.\n'
  fi
}

# handle_phase_plan <orch_root> <milestone> <phase> <task>
# Returns the "## Scope" block containing Goal, Demo, and Must-Haves excerpt
# from the phase plan file.
handle_phase_plan() {
  local orch_root="$1" milestone="$2" phase="$3"
  local ms_dir
  ms_dir="$(_sh_resolve_milestone_dir "$orch_root" "$milestone")" || return 1
  local phase_plan="${ms_dir}/phases/${phase}/${phase}-PLAN.md"
  printf '## Scope\n\n'
  if [ ! -f "$phase_plan" ]; then
    printf 'Phase plan not found.\n'
    return 0
  fi
  local goal_line demo_line must_haves
  goal_line="$(grep -E '^## Goal' "$phase_plan" -A 2 2>/dev/null | tail -n +2 | head -2 || true)"
  demo_line="$(grep -E '^## Demo' "$phase_plan" -A 2 2>/dev/null | tail -n +2 | head -2 || true)"
  must_haves="$(sed -n '/^## Must-Haves/,/^## [^M]/p' "$phase_plan" | head -20 || true)"
  printf '### Goal\n%s\n\n### Demo\n%s\n\n### Must-Haves\n%s\n' \
    "$goal_line" "$demo_line" "$must_haves"
}

# handle_task_plan <orch_root> <milestone> <phase> <task>
# Returns the "## Task Plan" block containing the full task plan file body.
handle_task_plan() {
  local orch_root="$1" milestone="$2" phase="$3" task="$4"
  local ms_dir
  ms_dir="$(_sh_resolve_milestone_dir "$orch_root" "$milestone")" || return 1
  local task_plan="${ms_dir}/phases/${phase}/tasks/${task}-PLAN.md"
  printf '## Task Plan\n\n'
  if [ ! -f "$task_plan" ]; then
    printf 'Task plan not found: %s\n' "$task_plan"
    return 0
  fi
  cat "$task_plan"
}

# handle_template <orch_root> <milestone> <phase> <task> <section_name>
# Returns a templated block. Currently only "constraints" is supported.
# Caller must set SH_VERIFICATION_CRITERIA, SH_DURATION_BUDGET,
# SH_DISPATCH_BUDGET, SH_BUDGET_ENFORCEMENT env vars before invocation.
handle_template() {
  local section_name="$5"
  case "$section_name" in
    constraints|Constraints|CONSTRAINTS)
      printf '## Constraints\n\n'
      printf -- '- **Verification Criteria**: %s\n' "${SH_VERIFICATION_CRITERIA:-See phase plan must-haves}"
      printf -- '- **Duration Budget**: %s\n' "${SH_DURATION_BUDGET:-2h}"
      printf -- '- **Dispatch Budget**: %s\n' "${SH_DISPATCH_BUDGET:-3}"
      printf -- '- **Budget Enforcement**: %s\n' "${SH_BUDGET_ENFORCEMENT:-warn}"
      printf '\n### Prohibited inline bash patterns\n\n'
      printf 'The following patterns trigger Claude Code safety prompts and MUST NOT\n'
      printf 'appear in Bash tool calls. See AP-004 in ANTIPATTERNS.md for details.\n\n'
      printf -- '- **Command substitution**: Do not use $(cmd) or backtick substitution.\n'
      printf -- '  Use --output-file flags or omit dynamic values (e.g., omit --completed_at).\n'
      printf -- '- **Brace expansion**: Do not use {a,b} patterns.\n'
      printf -- '  Pass explicit arguments instead.\n'
      printf -- '- **Compound chains**: Do not chain commands with && || ; or pipes.\n'
      printf -- '  Use wrapper scripts (e.g., bash scripts/verify/run-suite.sh).\n'
      printf '\n### Allowed invocation shapes\n\n'
      printf 'When an inline bash shape would otherwise trigger a safety prompt, use one\n'
      printf 'of these canonical wrappers instead:\n\n'
      printf -- '- `bash scripts/util/with-env.sh KEY=VALUE [KEY=VALUE ...] -- <command> [args ...]`\n'
      printf '  -- Replaces `KEY=VALUE bash cmd` inline-assignment prefixes.\n'
      printf -- '- `bash scripts/util/read-range.sh <file> <M> <N>`\n'
      printf '  -- Replaces `sed -n '"'"'M,Np'"'"' <file>` line-range reads.\n'
      printf -- '- `bash scripts/util/run-probe.sh <path-to-staged-probe.sh>`\n'
      printf '  -- Replaces `cat > /tmp/x.sh <<EOF ... EOF ; bash /tmp/x.sh` heredoc-and-execute.\n\n'
      printf 'A pre-Bash hook (`scripts/hooks/pre-bash-shape-guard.sh`) auto-rewrites six\n'
      printf 'common deviations from these shapes and hard-rejects four others with a\n'
      printf 'wrapper-pointing diagnostic. See ANTIPATTERNS.md AP-005..AP-009.\n'
      printf '\n### Branch Discipline\n\n'
      printf 'You inherit the git branch the dispatcher is sitting on. Commit your work\n'
      printf 'on that branch.\n\n'
      printf -- '- Do NOT `git checkout`, `git switch`, `git branch`, `git merge`, or\n'
      printf '  `git rebase` to a different branch unless your task plan explicitly\n'
      printf '  requires it.\n'
      printf -- '- Do NOT create a new branch as a side-effect of "isolating" your work\n'
      printf '  — git worktrees handle that at the dispatcher layer when configured.\n'
      printf -- '- If you genuinely believe a side-branch is required (e.g. the task plan\n'
      printf '  calls for a hotfix branch), STOP and report rather than acting\n'
      printf '  unilaterally. The dispatcher will tell you whether to proceed.\n\n'
      printf 'This rule exists because branch switches inside a dispatched task are\n'
      printf 'invisible to the dispatcher audit trail and have caused mid-loop\n'
      printf 'confusion (commits landing on a branch the operator did not expect,\n'
      printf 'then being merged opaquely).\n'
      ;;
    *)
      printf 'section-handlers: unknown template section: %s\n' "$section_name" >&2
      return 1
      ;;
  esac
}

# handle_knowledge <orch_root> <milestone> <phase> <task> [<included_ids_file>]
# Runs the index pipeline to emit a "## Knowledge" section. If the 5th
# argument is a writable file path, all resolved MEM IDs are written to it
# (one per line) so the caller can increment hit counts after emission.
handle_knowledge() {
  local orch_root="$1" milestone="$2" phase="$3"
  local included_ids_file="${5:-}"
  local ms_dir
  ms_dir="$(_sh_resolve_milestone_dir "$orch_root" "$milestone")" || return 1

  # Locate the knowledge index
  local knowledge_index=""
  if [ -f "${_SH_PROJECT_ROOT}/../KNOWLEDGE-INDEX.md" ]; then
    knowledge_index="${_SH_PROJECT_ROOT}/../KNOWLEDGE-INDEX.md"
  elif [ -f "${ms_dir}/KNOWLEDGE-INDEX.md" ]; then
    knowledge_index="${ms_dir}/KNOWLEDGE-INDEX.md"
  fi

  printf '## Knowledge\n\n'

  if [ -z "$knowledge_index" ]; then
    _sh_emit_flat_knowledge "$ms_dir" "$milestone" "$phase"
    return 0
  fi

  # If the index exists but has zero data rows (only header/comments), fall
  # back to the flat KNOWLEDGE.md so accumulated knowledge still gets injected.
  local _data_rows
  _data_rows="$(grep -c '^MEM' "$knowledge_index" 2>/dev/null || true)"
  if [ "${_data_rows:-0}" -eq 0 ]; then
    _sh_emit_flat_knowledge "$ms_dir" "$milestone" "$phase"
    return 0
  fi

  # Read phase depends for scope-filter
  local roadmap="${ms_dir}/${milestone}-ROADMAP.md"
  local depends="none"
  if [ -f "$roadmap" ] && [ -x "$_SH_READ_ROADMAP" ]; then
    local phase_data
    phase_data="$(bash "$_SH_READ_ROADMAP" "$roadmap" phase "$phase" 2>/dev/null || true)"
    if [ -n "$phase_data" ]; then
      depends="$(printf '%s' "$phase_data" | awk '{print $4}')"
    fi
  fi

  local dep_flag=""
  if [ "$depends" != "none" ] && [ -n "$depends" ]; then
    dep_flag="--depends $depends"
  fi

  # Check if graph database is available for enhanced filtering
  local graph_flag=""
  local db_file="${_SH_PROJECT_ROOT}/../knowledge.db"
  if [ -f "$db_file" ]; then
    graph_flag="--graph"
  fi

  # Step 1: scope-filter
  local filtered_file matched_file
  filtered_file="$(mktemp)"
  matched_file="$(mktemp)"
  bash "$_SH_SCOPE_FILTER" "$knowledge_index" "${milestone}/${phase}" \
    --type knowledge $dep_flag $graph_flag > "$filtered_file" 2>/dev/null || true

  if [ ! -s "$filtered_file" ]; then
    printf 'No knowledge entries in scope.\n'
    rm -f "$filtered_file" "$matched_file"
    return 0
  fi

  # Step 2: extract MEM IDs from filtered lines
  local line eid
  while IFS= read -r line; do
    eid="$(printf '%s' "$line" | grep -oE '^MEM[0-9]+' || true)"
    [ -n "$eid" ] && printf '%s\n' "$eid" >> "$matched_file"
  done < "$filtered_file"
  rm -f "$filtered_file"

  if [ ! -s "$matched_file" ]; then
    printf 'No knowledge entries in scope.\n'
    rm -f "$matched_file"
    return 0
  fi

  # Step 3: traverse graph 1-hop for each matched ID
  local all_ids_file related_file
  all_ids_file="$(mktemp)"
  related_file="$(mktemp)"
  cat "$matched_file" > "$all_ids_file"
  while IFS= read -r eid; do
    [ -z "$eid" ] && continue
    bash "$_SH_TRAVERSE_GRAPH" --id "$eid" --hops 2 --max-entries 10 \
      >> "$related_file" 2>/dev/null || true
  done < "$matched_file"
  cat "$related_file" >> "$all_ids_file"
  rm -f "$related_file" "$matched_file"

  # Step 4: deduplicate
  local sorted_file
  sorted_file="$(mktemp)"
  sort -u "$all_ids_file" > "$sorted_file"
  rm -f "$all_ids_file"

  # Forward IDs to caller if requested
  if [ -n "$included_ids_file" ]; then
    cp "$sorted_file" "$included_ids_file"
  fi

  # Step 5: resolve
  local resolved
  resolved="$(cat "$sorted_file" | bash "$_SH_RESOLVE_ENTRIES" 2>/dev/null || true)"
  local entry_count
  entry_count="$(grep -c 'MEM' "$sorted_file" 2>/dev/null || echo 0)"
  rm -f "$sorted_file"

  if [ -z "$resolved" ]; then
    printf 'No knowledge entries in scope.\n'
  else
    printf '<!-- %s knowledge entries resolved from index -->\n\n' "$entry_count"
    printf '%s\n' "$resolved"
  fi
}

# Internal: flat KNOWLEDGE.md fallback when no index is present.
_sh_emit_flat_knowledge() {
  local ms_dir="$1" milestone="$2" phase="$3"
  local knowledge_file="${ms_dir}/KNOWLEDGE.md"
  if [ ! -f "$knowledge_file" ]; then
    printf 'No knowledge entries in scope.\n'
    return 0
  fi
  local roadmap="${ms_dir}/${milestone}-ROADMAP.md"
  local depends="none"
  if [ -f "$roadmap" ] && [ -x "$_SH_READ_ROADMAP" ]; then
    local phase_data
    phase_data="$(bash "$_SH_READ_ROADMAP" "$roadmap" phase "$phase" 2>/dev/null || true)"
    if [ -n "$phase_data" ]; then
      depends="$(printf '%s' "$phase_data" | awk '{print $4}')"
    fi
  fi
  local dep_flag=""
  if [ "$depends" != "none" ] && [ -n "$depends" ]; then
    dep_flag="--depends $depends"
  fi
  local entries
  entries="$(bash "$_SH_SCOPE_FILTER" "$knowledge_file" "${milestone}/${phase}" \
    --type knowledge $dep_flag 2>/dev/null || true)"
  if [ -z "$entries" ]; then
    printf 'No knowledge entries in scope.\n'
  else
    printf '%s\n' "$entries"
  fi
}

# handle_decisions <orch_root> <milestone> <phase> <task>
# Scope-filters DECISIONS.md and emits the "## Decisions" block.
handle_decisions() {
  local orch_root="$1" milestone="$2" phase="$3"
  local ms_dir
  ms_dir="$(_sh_resolve_milestone_dir "$orch_root" "$milestone")" || return 1
  printf '## Decisions\n\n'
  local decisions_file="${ms_dir}/DECISIONS.md"
  if [ ! -f "$decisions_file" ]; then
    printf 'No decision entries in scope.\n'
    return 0
  fi
  local roadmap="${ms_dir}/${milestone}-ROADMAP.md"
  local depends="none"
  if [ -f "$roadmap" ] && [ -x "$_SH_READ_ROADMAP" ]; then
    local phase_data
    phase_data="$(bash "$_SH_READ_ROADMAP" "$roadmap" phase "$phase" 2>/dev/null || true)"
    if [ -n "$phase_data" ]; then
      depends="$(printf '%s' "$phase_data" | awk '{print $4}')"
    fi
  fi
  local dep_flag=""
  if [ "$depends" != "none" ] && [ -n "$depends" ]; then
    dep_flag="--depends $depends"
  fi
  local entries
  entries="$(bash "$_SH_SCOPE_FILTER" "$decisions_file" "${milestone}/${phase}" \
    --type decisions $dep_flag 2>/dev/null || true)"
  if [ -z "$entries" ]; then
    printf 'No decision entries in scope.\n'
  else
    printf '%s\n' "$entries"
  fi
}

# handle_spec_context <orch_root> <milestone> <phase> <task>
# Emits a "## Spec Context" block containing resolved spec chunk bodies,
# scope-filtered by the task plan's frontmatter spec/* scope_tags. If the
# task plan has NO spec/* scope_tags, this handler emits nothing (empty
# output) so the caller can omit the section entirely.
handle_spec_context() {
  local orch_root="$1" milestone="$2" phase="$3" task="$4"
  local ms_dir
  ms_dir="$(_sh_resolve_milestone_dir "$orch_root" "$milestone")" || return 0

  # Only meaningful for task dispatch, not phase planning
  if [ "$task" = "PHASE_PLAN" ]; then
    return 0
  fi

  local task_plan="${ms_dir}/phases/${phase}/tasks/${task}-PLAN.md"
  if [ ! -f "$task_plan" ]; then
    return 0
  fi

  # Extract the scope_tags line from the YAML frontmatter and tokenize
  # spec/* entries. Task-plan frontmatter format (P03 convention):
  #   scope_tags: [spec/requirement/SPEC-FR-003, project]
  # We accept both bracket-list and comma lists.
  local tags_line
  tags_line="$(awk '/^---$/{c++; next} c==1 && /^scope_tags:/{print; exit}' "$task_plan" 2>/dev/null || true)"
  if [ -z "$tags_line" ]; then
    return 0
  fi

  # Strip 'scope_tags:' prefix, brackets, quotes; normalize separators to spaces
  local raw_tags
  raw_tags="$(printf '%s' "$tags_line" \
    | sed 's/^scope_tags:[[:space:]]*//' \
    | sed 's/^\[//; s/\]$//' \
    | tr ',' ' ' \
    | tr -d '"' \
    | tr -s ' ')"

  # Keep only spec/* tokens
  local spec_tags="" tok
  for tok in $raw_tags; do
    case "$tok" in
      spec/*) spec_tags="${spec_tags}${tok},";;
    esac
  done

  # Strip trailing comma
  spec_tags="$(printf '%s' "$spec_tags" | sed 's/,$//')"

  if [ -z "$spec_tags" ]; then
    return 0
  fi

  # Determine the knowledge root. Caller passes orch_root which is typically
  # either `<proj>/.orchestrator` (standalone layout) or `<milestone-dir>`
  # (fixture layout). The knowledge tree lives at `<proj>/knowledge`.
  # Resolution strategy:
  #   1. If orch_root is named `.orchestrator`, knowledge root is its parent.
  #   2. Else if orch_root has a sibling `knowledge/`, use that.
  #   3. Else fall back to PROJECT_ROOT env var or _SH_PROJECT_ROOT's parent.
  local _root=""
  case "$(basename "$orch_root")" in
    .orchestrator)
      _root="$(dirname "$orch_root")"
      ;;
  esac
  if [ -z "$_root" ] || [ ! -d "$_root/knowledge" ]; then
    if [ -d "$(dirname "$orch_root")/knowledge" ]; then
      _root="$(dirname "$orch_root")"
    fi
  fi
  if [ -z "$_root" ] || [ ! -d "$_root/knowledge" ]; then
    if [ -n "${PROJECT_ROOT:-}" ] && [ -d "${PROJECT_ROOT}/knowledge" ]; then
      _root="$PROJECT_ROOT"
    else
      _root="${_SH_PROJECT_ROOT}/.."
    fi
  fi

  # Resolve IDs via T01's scope-filter spec-scope-tags mode. We export
  # PROJECT_ROOT for the subprocess because build-context.sh (our typical
  # caller) clobbers PROJECT_ROOT at startup; scope-filter's non-goal gate
  # and liveness fallback rely on PROJECT_ROOT pointing at the correct
  # knowledge root.
  local ids_file
  ids_file="$(mktemp)"
  PROJECT_ROOT="$_root" bash "$_SH_SCOPE_FILTER" --spec-scope-tags "$spec_tags" \
    > "$ids_file" 2>/dev/null || true

  if [ ! -s "$ids_file" ]; then
    rm -f "$ids_file"
    return 0
  fi

  local resolved_file id_count resolved_file_any
  resolved_file="$(mktemp)"
  resolved_file_any=0
  id_count=0
  local entry_id f match_file
  while IFS= read -r entry_id; do
    entry_id="$(printf '%s' "$entry_id" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -z "$entry_id" ] && continue
    match_file=""
    # One-level scan first
    for f in "$_root"/knowledge/*/"${entry_id}.md"; do
      if [ -f "$f" ]; then
        case "$f" in
          */archive/*) continue ;;
        esac
        match_file="$f"
        break
      fi
    done
    # Two-level scan fallback (spec/<cat>/<id>.md)
    if [ -z "$match_file" ]; then
      for f in "$_root"/knowledge/*/*/"${entry_id}.md"; do
        if [ -f "$f" ]; then
          case "$f" in
            */archive/*) continue ;;
          esac
          match_file="$f"
          break
        fi
      done
    fi
    if [ -n "$match_file" ]; then
      if [ "$resolved_file_any" -eq 1 ]; then
        printf '\n' >> "$resolved_file"
      fi
      cat "$match_file" >> "$resolved_file"
      resolved_file_any=1
      id_count=$((id_count + 1))
    fi
  done < "$ids_file"
  rm -f "$ids_file"

  if [ "$resolved_file_any" -eq 0 ]; then
    rm -f "$resolved_file"
    return 0
  fi

  printf '## Spec Context\n\n'
  printf '<!-- %s spec chunks resolved from task scope_tags -->\n\n' "$id_count"
  cat "$resolved_file"
  printf '\n'
  rm -f "$resolved_file"
}

# handle_file <orch_root> <milestone> <phase> <task> <source_filename>
# Generic filename dispatcher. Routes KNOWLEDGE.md / DECISIONS.md to their
# dedicated handlers; falls back to a raw cat for anything else at the
# milestone-dir root.
handle_file() {
  local orch_root="$1" milestone="$2" phase="$3" task="$4" source_filename="$5"
  case "$source_filename" in
    KNOWLEDGE.md|knowledge.md)
      handle_knowledge "$orch_root" "$milestone" "$phase" "$task"
      ;;
    DECISIONS.md|decisions.md)
      handle_decisions "$orch_root" "$milestone" "$phase" "$task"
      ;;
    *)
      local ms_dir
      ms_dir="$(_sh_resolve_milestone_dir "$orch_root" "$milestone")" || return 1
      local f="${ms_dir}/${source_filename}"
      if [ -f "$f" ]; then
        cat "$f"
      else
        printf 'section-handlers: file not found: %s\n' "$f" >&2
        return 1
      fi
      ;;
  esac
}

# dispatch_section_handler <source> <section_name> <orch_root> <milestone> <phase> <task> [<included_ids_file>]
# Routes a recipe section to its handler by source value:
#   source: computed        → handle_computed
#   source: phase_summaries → handle_phase_summaries
#   source: phase_plan      → handle_phase_plan
#   source: task_plan       → handle_task_plan
#   source: template        → handle_template
#   source: KNOWLEDGE.md    → handle_knowledge (forwards included_ids_file)
#   source: <anything>.md   → handle_file (which further routes DECISIONS)
dispatch_section_handler() {
  local source="$1" section_name="$2"
  local orch_root="$3" milestone="$4" phase="$5" task="$6"
  local included_ids_file="${7:-}"
  case "$source" in
    computed)
      handle_computed "$orch_root" "$milestone" "$phase" "$task" "$section_name"
      ;;
    phase_summaries)
      handle_phase_summaries "$orch_root" "$milestone" "$phase" "$task"
      ;;
    phase_plan)
      handle_phase_plan "$orch_root" "$milestone" "$phase" "$task"
      ;;
    task_plan)
      handle_task_plan "$orch_root" "$milestone" "$phase" "$task"
      ;;
    template)
      handle_template "$orch_root" "$milestone" "$phase" "$task" "$section_name"
      ;;
    spec_context)
      handle_spec_context "$orch_root" "$milestone" "$phase" "$task"
      ;;
    *.md)
      if [ "$source" = "KNOWLEDGE.md" ] || [ "$source" = "knowledge.md" ]; then
        handle_knowledge "$orch_root" "$milestone" "$phase" "$task" "$included_ids_file"
      else
        handle_file "$orch_root" "$milestone" "$phase" "$task" "$source"
      fi
      ;;
    *)
      printf 'section-handlers: unknown source type: %s (section=%s)\n' \
        "$source" "$section_name" >&2
      return 1
      ;;
  esac
}
