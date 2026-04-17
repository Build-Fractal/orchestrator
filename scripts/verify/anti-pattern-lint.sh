#!/usr/bin/env bash
# scripts/verify/anti-pattern-lint.sh — Detect Class A + Class B anti-patterns in agent-facing content
# Scans agent-facing markdown + task-PAYLOAD + dispatch/lib content for patterns that trigger
# Claude Code safety prompts.
#
# Class A (M016, AP-004): $(…) command substitution, backtick command substitution, {a,b} brace expansion.
# Class B (M021/P02, AP-005..AP-009):
#   - AP-005 simple-expansion: $VAR or $? in tool-call lines
#   - AP-006 redirect-cmd-sub: $(...) after a redirection operator
#   - AP-007 quoted-brace: literal { inside double-quoted string (not ${VAR})
#   - AP-008 heredoc-expansion: $VAR or $(...) inside unquoted heredoc body
#   - AP-009 task-plan-compound: for/if/while one-liners, cd X && Y, a; b chains
#     inside bash fences of .orchestrator/milestones/**/tasks/*-PAYLOAD.md
#
# Usage: anti-pattern-lint.sh [--fixture <file>]
#   Default: scans commands/*.md, templates/*.md, scripts/dispatch/lib/**/*.sh,
#            .orchestrator/milestones/**/tasks/*-PAYLOAD.md, and any file under
#            specs/, references/, docs/ containing the marker `<!-- agent-facing -->`.
#   --fixture <file>: scan only the specified file (for testing)
#
# Self-excludes its own source. Excludes ANTIPATTERNS.md.
# See AP-004..AP-009 in ANTIPATTERNS.md for the canonical pattern catalog.
#
# Exit: 0 if clean, 1 if violations found.
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Parse arguments ---
FIXTURE_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --fixture)
      if [ $# -lt 2 ]; then
        echo "anti-pattern-lint.sh: --fixture requires a file argument" >&2
        exit 1
      fi
      FIXTURE_FILE="$2"
      shift 2
      ;;
    *)
      echo "anti-pattern-lint.sh: unknown option $1" >&2
      exit 1
      ;;
  esac
done

# --- Self-exclusion paths ---
SELF_PATH="${SCRIPT_DIR}/anti-pattern-lint.sh"
ANTIPATTERNS_PATH="${PROJECT_ROOT}/ANTIPATTERNS.md"

# --- Build file list ---
_file_list="$(mktemp)"
_violation_out="$(mktemp)"
trap 'rm -f "$_file_list" "$_violation_out"' EXIT

if [ -n "$FIXTURE_FILE" ]; then
  printf '%s\n' "$FIXTURE_FILE" > "$_file_list"
else
  # Discover agent-facing markdown files (M016 scope)
  find "$PROJECT_ROOT/commands" -name '*.md' -type f 2>/dev/null >> "$_file_list" || true
  find "$PROJECT_ROOT/templates" -name '*.md' -type f 2>/dev/null >> "$_file_list" || true
  # M021/P02 scope widening: dispatch adapter libs + task-PAYLOAD dispatch prompts
  if [ -d "$PROJECT_ROOT/scripts/dispatch/lib" ]; then
    find "$PROJECT_ROOT/scripts/dispatch/lib" -name '*.sh' -type f 2>/dev/null >> "$_file_list" || true
  fi
  if [ -d "$PROJECT_ROOT/.orchestrator/milestones" ]; then
    # Only scan ACTIVE task PAYLOADs. A PAYLOAD is active when:
    #   - its milestone is unclosed (no MXXX-SUMMARY.md + MXXX-VALIDATED), AND
    #   - its sibling TNN-SUMMARY.md does not exist (task not yet completed).
    # Historical PAYLOADs are immutable dispatch-record artifacts — re-linting
    # them produces no actionable output (the work already shipped) and
    # creates thousands of findings on prose/script-source that was never
    # a live tool-call site. The linter's role is to prevent future Claude
    # Code safety-prompts on fresh dispatches; completed dispatches can't
    # be re-dispatched. See M021/P02/T01 SUMMARY for the follow-up note.
    for _m_dir in "$PROJECT_ROOT/.orchestrator/milestones"/M*; do
      [ -d "$_m_dir" ] || continue
      _m_id="$(basename "$_m_dir")"
      if [ -f "$_m_dir/${_m_id}-SUMMARY.md" ] && [ -f "$_m_dir/${_m_id}-VALIDATED" ]; then
        continue
      fi
      # Walk this milestone's PAYLOADs, skip those whose task has a SUMMARY.
      find "$_m_dir" -path '*/tasks/*-PAYLOAD.md' -type f 2>/dev/null | while IFS= read -r _pay; do
        _summary="${_pay%-PAYLOAD.md}-SUMMARY.md"
        [ -f "$_summary" ] && continue
        printf '%s\n' "$_pay"
      done >> "$_file_list"
    done
  fi
  # Marker-gated opt-in for specs/ references/ docs/
  for _opt_root in specs references docs; do
    _root_abs="$PROJECT_ROOT/$_opt_root"
    [ -d "$_root_abs" ] || continue
    find "$_root_abs" -name '*.md' -type f 2>/dev/null | while IFS= read -r _cand; do
      if grep -q '<!-- agent-facing -->' "$_cand" 2>/dev/null; then
        printf '%s\n' "$_cand"
      fi
    done >> "$_file_list"
  done
fi

# --- Scan each file ---
violation_count=0

while IFS= read -r file; do
  [ -z "$file" ] && continue
  [ ! -f "$file" ] && continue

  # Resolve to absolute path for comparison
  _dir="$(cd "$(dirname "$file")" && pwd)"
  _base="$(basename "$file")"
  real_file="${_dir}/${_base}"

  # Self-exclusion
  if [ "$real_file" = "$SELF_PATH" ]; then
    continue
  fi
  # ANTIPATTERNS.md exclusion
  if [ "$real_file" = "$ANTIPATTERNS_PATH" ]; then
    continue
  fi

  # Compute display path (relative to project root when possible)
  short_file="${real_file#${PROJECT_ROOT}/}"

  # Per-file scope flag: is this a task-PAYLOAD file?
  case "$real_file" in
    *"/tasks/"*"-PAYLOAD.md") is_task_payload=1 ;;
    *) is_task_payload=0 ;;
  esac

  # Per-file heredoc state (reset at start of each file)
  in_heredoc=0
  heredoc_quoted=0
  heredoc_terminator=""

  # Scan inside code blocks only
  in_code_block=0
  line_num=0
  _suppress_next=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Track fenced code block boundaries
    # A line starting with ``` (possibly followed by a language tag) toggles state
    case "$line" in
      '```'*)
        if [ "$in_code_block" -eq 0 ]; then
          in_code_block=1
        else
          in_code_block=0
        fi
        _suppress_next=0
        # Reset heredoc state at fence boundaries so an unterminated heredoc
        # inside one fence doesn't leak into the next.
        in_heredoc=0
        heredoc_quoted=0
        heredoc_terminator=""
        continue
        ;;
    esac

    # Only scan inside code blocks
    [ "$in_code_block" -eq 0 ] && continue

    # Skip lines with suppression markers
    case "$line" in
      *'# FORBIDDEN'*)
        # A FORBIDDEN comment suppresses this line and all following lines
        # until the next # comment/heading or blank line
        _suppress_next=1
        continue
        ;;
      *'# lint-ignore'*)
        continue
        ;;
    esac

    # If inside a FORBIDDEN-suppressed region, check if we should exit it
    if [ "$_suppress_next" -eq 1 ]; then
      # End suppression on blank lines or new # comment/heading lines
      case "$line" in
        '#'*)
          # New heading or comment — check if it is itself FORBIDDEN
          case "$line" in
            *'# FORBIDDEN'*) continue ;;  # stay suppressed
          esac
          _suppress_next=0
          # This line is the new heading itself — don't scan it, let it
          # be evaluated on next iteration by falling through
          continue
          ;;
        '')
          _suppress_next=0
          continue
          ;;
        *)
          # Still in the suppressed region (content lines after FORBIDDEN)
          continue
          ;;
      esac
    fi

    # --- Heredoc state tracking (Class B / AP-008) ---
    # Must run BEFORE Class A checks so that quoted-heredoc bodies don't
    # trigger Class A $(...) matches on non-expanding literal text.
    #
    # Perf note: all regex tests below use Bash 3.2's built-in `[[ =~ ]]`
    # rather than `printf | grep`, avoiding one fork+exec per line per
    # detector. On a 1700-line PAYLOAD that saves ~10k subprocess launches.
    if [ "$in_heredoc" -eq 0 ]; then
      # Detect a heredoc opener: <<EOF, <<-EOF, <<"EOF", <<'EOF'.
      # Use variable-assembled regex so both quote variants match
      # regardless of shell string-escape interpretation.
      _hd_dq='"'
      _hd_sq="'"
      _hd_id_re='[A-Za-z_][A-Za-z_0-9]*'
      _hd_quote=""
      _hd_term=""
      _hd_re_dq="<<-?${_hd_dq}(${_hd_id_re})${_hd_dq}"
      _hd_re_sq="<<-?${_hd_sq}(${_hd_id_re})${_hd_sq}"
      _hd_re_un="<<-?(${_hd_id_re})"
      if [[ "$line" =~ $_hd_re_dq ]]; then
        _hd_quote='"'
        _hd_term="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ $_hd_re_sq ]]; then
        _hd_quote="'"
        _hd_term="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ $_hd_re_un ]]; then
        _hd_quote=""
        _hd_term="${BASH_REMATCH[1]}"
      fi
      if [ -n "$_hd_term" ]; then
        heredoc_terminator="$_hd_term"
        in_heredoc=1
        if [ -n "$_hd_quote" ]; then
          heredoc_quoted=1
        else
          heredoc_quoted=0
        fi
      fi
    else
      # Inside heredoc body. The terminator may appear alone or with leading
      # whitespace (for <<- variants that allow tab indentation).
      _trimmed_line="${line#"${line%%[![:space:]]*}"}"
      if [ "$line" = "$heredoc_terminator" ] || [ "$_trimmed_line" = "$heredoc_terminator" ]; then
        in_heredoc=0
        heredoc_quoted=0
        heredoc_terminator=""
        continue
      fi
      # Flag $VAR or $(...) inside an UNQUOTED heredoc body.
      if [ "$heredoc_quoted" -eq 0 ]; then
        if [[ "$line" =~ \$\( ]] || [[ "$line" =~ \$[A-Za-z_?] ]]; then
          violation_count=$((violation_count + 1))
          printf '%s:%d: heredoc-expansion $VAR or $(...) inside unquoted heredoc body  [AP-008]\n' "$short_file" "$line_num" >> "$_violation_out"
          printf '  Hint: Stage the probe body to a file and invoke via bash scripts/util/run-probe.sh. See AP-008 in ANTIPATTERNS.md.\n' >> "$_violation_out"
        fi
      fi
      # Skip other detectors on heredoc body lines — they would double-flag.
      continue
    fi

    # --- Check 1: Command substitution $(...) ---
    # Match literal $( which indicates command substitution. Arithmetic $((…))
    # is also flagged intentionally — wrappers should handle those too.
    case "$line" in
      *'$('*)
        violation_count=$((violation_count + 1))
        printf '%s:%d: command substitution $(...)  [AP-004]\n' "$short_file" "$line_num" >> "$_violation_out"
        printf '  Hint: Use --output-file or a wrapper script. See AP-004 in ANTIPATTERNS.md.\n' >> "$_violation_out"
        ;;
    esac

    # --- Check 2: Backtick command substitution ---
    # Flag assignment-context backtick substitution: =`…`.
    if [[ "$line" =~ =\`[^\`]+\` ]]; then
      violation_count=$((violation_count + 1))
      printf '%s:%d: backtick command substitution  [AP-004]\n' "$short_file" "$line_num" >> "$_violation_out"
      printf '  Hint: Use a wrapper script or --output-file pattern. See AP-004 in ANTIPATTERNS.md.\n' >> "$_violation_out"
    fi

    # --- Check 3: Brace expansion {word,word} ---
    # Match {word,word} but NOT ${var} parameter expansion.
    if [[ "$line" =~ \{[A-Za-z0-9_./-]+,[A-Za-z0-9_./-]+ ]]; then
      # Mask ${...} so only bare braces remain, then re-test.
      _stripped="${line//\$\{/__PEXP__}"
      if [[ "$_stripped" =~ \{[A-Za-z0-9_./-]+,[A-Za-z0-9_./-]+ ]]; then
        violation_count=$((violation_count + 1))
        printf '%s:%d: brace expansion {a,b}  [AP-004]\n' "$short_file" "$line_num" >> "$_violation_out"
        printf '  Hint: Use explicit arguments or a wrapper script. See AP-004 in ANTIPATTERNS.md.\n' >> "$_violation_out"
      fi
    fi

    # --- Check B1: simple-expansion (AP-005) ---
    # Flag $VAR or $? in any code-block line. Mask ${...} parameter-expansion
    # forms first so only bare $VAR / $? remain.
    _sline="${line//\$\{/__PEXP__}"
    if [[ "$_sline" =~ (^|[^_A-Za-z0-9])\$([A-Za-z_][A-Za-z_0-9]*|\?) ]]; then
      violation_count=$((violation_count + 1))
      printf '%s:%d: simple-expansion $VAR or $? in tool-call line  [AP-005]\n' "$short_file" "$line_num" >> "$_violation_out"
      printf '  Hint: Replace inline env prefix with bash scripts/util/with-env.sh. See AP-005 in ANTIPATTERNS.md.\n' >> "$_violation_out"
    fi

    # --- Check B2: redirect-cmd-sub (AP-006) ---
    # Flag $(...) appearing after a redirection operator (>, >>, 2>, &>) with
    # optional whitespace and optional leading double-quote.
    if [[ "$line" =~ (\>|\>\>|2\>|\&\>)[[:space:]]*\"?\$\( ]]; then
      violation_count=$((violation_count + 1))
      printf '%s:%d: redirect-cmd-sub $(...) in redirect target  [AP-006]\n' "$short_file" "$line_num" >> "$_violation_out"
      printf '  Hint: Write to a fixed file path; use bash scripts/util/read-range.sh to read it back. See AP-006 in ANTIPATTERNS.md.\n' >> "$_violation_out"
    fi

    # --- Check B3: quoted-brace (AP-007) ---
    # Flag literal { inside a double-quoted string. First strip ${...} forms.
    # Bash 3.2 ${var//pattern/replacement} handles this without a subshell.
    # We need to strip any ${...} (with inner content), not just ${.
    _qline="$line"
    while [[ "$_qline" == *'${'*'}'* ]]; do
      # Remove one ${...} occurrence per iteration. Greedy removal of the
      # innermost would need regex; for perf we remove the shortest from-left.
      _qline_before="$_qline"
      _qline="${_qline/\$\{*\}/}"
      # Safety: break if substitution did nothing (avoid infinite loop).
      [ "$_qline" = "$_qline_before" ] && break
    done
    if [[ "$_qline" =~ \"[^\"]*\{[^\"]*\" ]]; then
      violation_count=$((violation_count + 1))
      printf '%s:%d: quoted-brace {...} inside double-quoted string  [AP-007]\n' "$short_file" "$line_num" >> "$_violation_out"
      printf '  Hint: Extract awk/shell into a standalone script; use bash scripts/util/read-range.sh for line ranges. See AP-007 in ANTIPATTERNS.md.\n' >> "$_violation_out"
    fi

    # --- Check B5: task-plan-compound (AP-009) ---
    # Only fires inside task-PAYLOAD files.
    if [ "$is_task_payload" -eq 1 ]; then
      # Pattern a: inline for-loop (for X; do Y)
      if [[ "$line" =~ (^|[^A-Za-z0-9_])for[[:space:]].*\;[[:space:]]*do[[:space:]] ]]; then
        violation_count=$((violation_count + 1))
        printf '%s:%d: task-plan-compound inline for ... do loop  [AP-009]\n' "$short_file" "$line_num" >> "$_violation_out"
        printf '  Hint: Extract into a script file; or call bash scripts/util/run-probe.sh <staged>. See AP-009 in ANTIPATTERNS.md.\n' >> "$_violation_out"
      fi
      # Pattern b: inline if-then one-liner (if X; then Y)
      if [[ "$line" =~ (^|[^A-Za-z0-9_])if[[:space:]].*\;[[:space:]]*then[[:space:]] ]]; then
        violation_count=$((violation_count + 1))
        printf '%s:%d: task-plan-compound inline if ... then one-liner  [AP-009]\n' "$short_file" "$line_num" >> "$_violation_out"
        printf '  Hint: Extract into a script file. See AP-009 in ANTIPATTERNS.md.\n' >> "$_violation_out"
      fi
      # Pattern c: cd X && Y chain
      if [[ "$line" =~ (^|[^A-Za-z0-9_])cd[[:space:]][^\&]+\&\& ]]; then
        violation_count=$((violation_count + 1))
        printf '%s:%d: task-plan-compound cd X && Y chain  [AP-009]\n' "$short_file" "$line_num" >> "$_violation_out"
        printf '  Hint: Invoke the target script with an absolute path. See AP-009 in ANTIPATTERNS.md.\n' >> "$_violation_out"
      fi
      # Pattern d: semicolon chain a; b (non-trailing ; followed by more command text)
      if [[ "$line" =~ [^\;[:space:]]\;[[:space:]]*[A-Za-z_] ]]; then
        violation_count=$((violation_count + 1))
        printf '%s:%d: task-plan-compound semicolon chain a; b  [AP-009]\n' "$short_file" "$line_num" >> "$_violation_out"
        printf '  Hint: Split into separate bash fences or call bash scripts/util/run-probe.sh. See AP-009 in ANTIPATTERNS.md.\n' >> "$_violation_out"
      fi
    fi

  done < "$file"

done < "$_file_list"

# --- Report results ---
if [ "$violation_count" -gt 0 ]; then
  printf 'LINT FAIL: %d violation(s) found in agent-facing content\n\n' "$violation_count"
  cat "$_violation_out"
  printf '\nSee AP-004..AP-009 in ANTIPATTERNS.md for the full Class A + Class B pattern catalog.\n'
  exit 1
else
  printf 'LINT PASS: no Class A or Class B anti-patterns found in agent-facing content\n'
  exit 0
fi
