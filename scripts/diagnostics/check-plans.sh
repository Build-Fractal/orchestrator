#!/usr/bin/env bash
# scripts/diagnostics/check-plans.sh — AD-19 task plan shape lint.
#
# Scans task plan Check: commands and inline ```bash verification blocks
# for patterns that trip the Claude Code harness obfuscation heuristic.
# Advisory only — reports warnings, does not block.
#
# Per AD-19, the harness safety heuristic sits above the allow list and
# cannot be disabled. Task plan verification must use single-script-file
# invocations to avoid interactive prompts during auto mode.
#
# Usage: check-plans.sh [--root <project-root>] [--target <file>]
#
# Output: DOCTOR:PLANS status=<ok|warn> heuristic_risk=N trigger=<class>
#
# Bash 3.2 compatible.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    *) echo "check-plans.sh: unknown option: $1" >&2; exit 0 ;;
  esac
done

# --- Collect files to scan ---
file_list=""

if [ -n "$TARGET" ]; then
  case "$TARGET" in
    /*) file_list="$TARGET" ;;
    *)  file_list="$PROJECT_ROOT/$TARGET" ;;
  esac
  if [ ! -f "$file_list" ]; then
    printf 'DOCTOR:PLANS status=ok heuristic_risk=0 trigger=none\n'
    exit 0
  fi
else
  # Find all *-PLAN.md files under milestones
  milestones_dir="$PROJECT_ROOT/.orchestrator/milestones"
  if [ -d "$milestones_dir" ]; then
    for f in "$milestones_dir"/*/phases/*/tasks/*-PLAN.md; do
      [ -f "$f" ] && file_list="${file_list}${file_list:+
}$f"
    done
  fi
  # Also scan canary template files
  for tmpl in "$PROJECT_ROOT/templates/phase-plan.md" "$PROJECT_ROOT/templates/task-plan.md"; do
    [ -f "$tmpl" ] && file_list="${file_list}${file_list:+
}$tmpl"
  done
fi

if [ -z "$file_list" ]; then
  printf 'DOCTOR:PLANS status=ok heuristic_risk=0 trigger=none\n'
  exit 0
fi

# --- Trigger pattern definitions ---
# Each entry: class|pattern
# Using | as delimiter within the pattern list (patterns use grep -E)
TRIGGER_CLASSES="bash-c
chain
heredoc
subshell-source
subshell-pipe
cmdsub-pipe
procsub
redirect-in-cmdsub
compound-semi
inline-loop"

# Returns pattern for a given trigger class
get_pattern() {
  case "$1" in
    bash-c)            printf '%s' "bash -c '" ;;
    chain)             printf '%s' '&& bash|&& \. |\|\| bash|\|\| \. ' ;;
    heredoc)           printf '%s' '<<[^'"'"']*\$[({]' ;;
    subshell-source)   printf '%s' '\( *\. ' ;;
    subshell-pipe)     printf '%s' '\([^)]*\|[^)]*\)' ;;
    cmdsub-pipe)       printf '%s' '\$\([^)]*\|[^)]*\)' ;;
    procsub)           printf '%s' '<\(|>\(' ;;
    redirect-in-cmdsub) printf '%s' '\$\([^)]*<[^)]*\)' ;;
    compound-semi)     printf '%s' ';.*;[ 	]*[a-z]' ;;
    inline-loop)       printf '%s' '\bfor |\bwhile |; *do\b|; *then\b|\bif ' ;;
  esac
}

# --- Extract checkable lines from a file ---
# Outputs: line_number|line_content
extract_checkable_lines() {
  local file="$1"
  local in_verification=0
  local in_bash_block=0
  local line_num=0

  while IFS= read -r line || [ -n "$line" ]; do
    line_num=$((line_num + 1))

    # Track whether we're in a ## Verification section
    case "$line" in
      "## Verification"*) in_verification=1 ;;
      "## "*)
        case "$line" in
          "## Verification"*) ;;
          *) in_verification=0; in_bash_block=0 ;;
        esac
        ;;
    esac

    # Check: commands (anywhere in file — they appear in Must-Haves too)
    case "$line" in
      *"- Check:"*)
        printf '%d|%s\n' "$line_num" "$line"
        continue
        ;;
    esac

    # Bash fenced blocks within Verification sections
    if [ "$in_verification" -eq 1 ]; then
      case "$line" in
        '```bash'*) in_bash_block=1; continue ;;
        '```')
          if [ "$in_bash_block" -eq 1 ]; then
            in_bash_block=0
          fi
          continue
          ;;
      esac
      if [ "$in_bash_block" -eq 1 ]; then
        printf '%d|%s\n' "$line_num" "$line"
      fi
    fi
  done < "$file"
}

# --- Main scan ---
heuristic_risk=0
warnings=""

# Track counts per trigger class using simple counters (Bash 3.2 — no assoc arrays)
count_bash_c=0
count_chain=0
count_heredoc=0
count_subshell_source=0
count_subshell_pipe=0
count_cmdsub_pipe=0
count_procsub=0
count_redirect_in_cmdsub=0
count_compound_semi=0
count_inline_loop=0

increment_count() {
  case "$1" in
    bash-c)            count_bash_c=$((count_bash_c + 1)) ;;
    chain)             count_chain=$((count_chain + 1)) ;;
    heredoc)           count_heredoc=$((count_heredoc + 1)) ;;
    subshell-source)   count_subshell_source=$((count_subshell_source + 1)) ;;
    subshell-pipe)     count_subshell_pipe=$((count_subshell_pipe + 1)) ;;
    cmdsub-pipe)       count_cmdsub_pipe=$((count_cmdsub_pipe + 1)) ;;
    procsub)           count_procsub=$((count_procsub + 1)) ;;
    redirect-in-cmdsub) count_redirect_in_cmdsub=$((count_redirect_in_cmdsub + 1)) ;;
    compound-semi)     count_compound_semi=$((count_compound_semi + 1)) ;;
    inline-loop)       count_inline_loop=$((count_inline_loop + 1)) ;;
  esac
}

IFS='
'
for file in $file_list; do
  IFS=' '
  [ -f "$file" ] || continue

  rel_path="${file#"$PROJECT_ROOT"/}"
  checkable="$(extract_checkable_lines "$file")"

  [ -z "$checkable" ] && continue

  IFS='
'
  for entry in $checkable; do
    IFS=' '
    line_num="${entry%%|*}"
    line_content="${entry#*|}"

    # Skip comment lines and template placeholders
    case "$line_content" in
      *"<!--"*) continue ;;
      *"{{"*"}}"*) continue ;;
    esac

    # Test each trigger pattern
    IFS='
'
    for tclass in $TRIGGER_CLASSES; do
      IFS=' '
      pattern="$(get_pattern "$tclass")"
      if printf '%s\n' "$line_content" | grep -qE "$pattern" 2>/dev/null; then
        heuristic_risk=$((heuristic_risk + 1))
        increment_count "$tclass"
        warnings="${warnings}  WARNING: ${rel_path}:${line_num} [${tclass}] ${line_content}
"
        break  # One trigger per line (report most specific match)
      fi
    done
    IFS='
'
  done
  IFS='
'
done
IFS=' '

# --- Determine most common trigger ---
most_common_class="none"
most_common_count=0

check_max() {
  local cls="$1" cnt="$2"
  if [ "$cnt" -gt "$most_common_count" ]; then
    most_common_count=$cnt
    most_common_class=$cls
  fi
}

check_max "bash-c" "$count_bash_c"
check_max "chain" "$count_chain"
check_max "heredoc" "$count_heredoc"
check_max "subshell-source" "$count_subshell_source"
check_max "subshell-pipe" "$count_subshell_pipe"
check_max "cmdsub-pipe" "$count_cmdsub_pipe"
check_max "procsub" "$count_procsub"
check_max "redirect-in-cmdsub" "$count_redirect_in_cmdsub"
check_max "compound-semi" "$count_compound_semi"
check_max "inline-loop" "$count_inline_loop"

# --- Output ---
if [ "$heuristic_risk" -eq 0 ]; then
  printf 'DOCTOR:PLANS status=ok heuristic_risk=0 trigger=none\n'
else
  printf 'DOCTOR:PLANS status=warn heuristic_risk=%d trigger=%s\n' "$heuristic_risk" "$most_common_class"
  printf '%s' "$warnings"
fi

exit 0
