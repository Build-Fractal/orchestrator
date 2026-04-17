#!/usr/bin/env bash
# scripts/verify/lib/shape-classifier.sh -- Shape classifier for the
# M021 10-pattern rewrite/reject matrix. Sourced by
# scripts/hooks/pre-bash-shape-guard.sh and
# scripts/verify/m021-p03-hook-integration.sh.
#
# Public API:
#   classify_command <cmd-string>
#     Prints exactly one line:
#       allow
#       rewrite:<result-command>
#       reject:<pattern-class>
#
# The 10-entry matrix is closed on M011/P05-P07 evidence (AD-2).
# No speculative additions (constitution XIV).
#
# Bash 3.2 compatible. No process substitution. No associative arrays.
# No bash-4 parameter expansions (${var,,}, ${var^^}, ${!prefix*}).
#
# Pattern-class labels (verbatim, contractually stable):
#   Rewrites: trailing-rc-echo, sed-n-range, cat-heredoc-exec,
#             cd-and-bash, var-inline-bash, redirect-cmd-sub
#   Rejects:  nested-cmd-sub, compound-chain-gt2,
#             heredoc-with-expansion, quoted-brace

[ -n "${_SHAPE_CLASSIFIER_SOURCED:-}" ] && return 0
_SHAPE_CLASSIFIER_SOURCED=1

# -----------------------------------------------------------------------------
# Private helpers (_sc_*)
# -----------------------------------------------------------------------------

# _sc_count_top_level_stages <cmd>
#   Prints the integer count of top-level stages joined by `&&`, `||`, `|`,
#   or `;`. Scans character-by-character tracking single/double quote state
#   and $(...) / backtick depth so nested operators do not inflate the count.
#   Minimum value is 1 for a non-empty command.
_sc_count_top_level_stages() {
  local s="$1"
  local i=0
  local n=${#s}
  local ch prev
  local in_sq=0 in_dq=0
  local paren=0 backtick=0
  local stages=1

  while [ "$i" -lt "$n" ]; do
    ch="${s:$i:1}"
    if [ "$i" -gt 0 ]; then
      prev="${s:$((i-1)):1}"
    else
      prev=""
    fi

    # Escape sequence outside single quotes: skip next char.
    if [ "$in_sq" -eq 0 ] && [ "$ch" = '\' ]; then
      i=$((i + 2))
      continue
    fi

    if [ "$in_sq" -eq 1 ]; then
      if [ "$ch" = "'" ]; then in_sq=0; fi
      i=$((i + 1))
      continue
    fi

    if [ "$in_dq" -eq 1 ]; then
      if [ "$ch" = '"' ]; then in_dq=0; fi
      # Inside "..." we still track $( ... ) depth so operators inside it
      # aren't counted as top-level. But typically ops inside "..." are
      # literal; we don't count them. Continue.
      i=$((i + 1))
      continue
    fi

    case "$ch" in
      "'") in_sq=1 ;;
      '"') in_dq=1 ;;
      '`') if [ "$backtick" -eq 0 ]; then backtick=1; else backtick=0; fi ;;
      '$')
        # Check for $( opening
        local nxt="${s:$((i+1)):1}"
        if [ "$nxt" = "(" ]; then
          paren=$((paren + 1))
          i=$((i + 2))
          continue
        fi
        ;;
      ')')
        if [ "$paren" -gt 0 ]; then
          paren=$((paren - 1))
        fi
        ;;
      '(')
        # Non-$( paren: treat as depth bump too (subshell syntax)
        paren=$((paren + 1))
        ;;
      '&')
        if [ "$paren" -eq 0 ] && [ "$backtick" -eq 0 ]; then
          local nxt2="${s:$((i+1)):1}"
          if [ "$nxt2" = "&" ]; then
            stages=$((stages + 1))
            i=$((i + 2))
            continue
          fi
        fi
        ;;
      '|')
        if [ "$paren" -eq 0 ] && [ "$backtick" -eq 0 ]; then
          local nxt3="${s:$((i+1)):1}"
          if [ "$nxt3" = "|" ]; then
            stages=$((stages + 1))
            i=$((i + 2))
            continue
          fi
          # Single pipe
          stages=$((stages + 1))
        fi
        ;;
      ';')
        if [ "$paren" -eq 0 ] && [ "$backtick" -eq 0 ]; then
          stages=$((stages + 1))
        fi
        ;;
    esac

    i=$((i + 1))
  done

  printf '%s\n' "$stages"
}

# _sc_has_nested_cmd_sub <cmd>
#   Returns 0 if the command has $( ... $( ... ) ... ) nesting at any depth.
#   Scans with quote-awareness: content inside single quotes is ignored;
#   content inside double quotes is still scanned because $(...) expands there.
_sc_has_nested_cmd_sub() {
  local s="$1"
  local i=0
  local n=${#s}
  local ch
  local in_sq=0
  local depth=0
  local max_depth=0

  while [ "$i" -lt "$n" ]; do
    ch="${s:$i:1}"

    if [ "$in_sq" -eq 0 ] && [ "$ch" = '\' ]; then
      i=$((i + 2))
      continue
    fi

    if [ "$in_sq" -eq 1 ]; then
      if [ "$ch" = "'" ]; then in_sq=0; fi
      i=$((i + 1))
      continue
    fi

    case "$ch" in
      "'") in_sq=1 ;;
      '$')
        local nxt="${s:$((i+1)):1}"
        if [ "$nxt" = "(" ]; then
          depth=$((depth + 1))
          if [ "$depth" -gt "$max_depth" ]; then
            max_depth=$depth
          fi
          i=$((i + 2))
          continue
        fi
        ;;
      ')')
        if [ "$depth" -gt 0 ]; then
          depth=$((depth - 1))
        fi
        ;;
    esac

    i=$((i + 1))
  done

  if [ "$max_depth" -ge 2 ]; then
    return 0
  fi
  return 1
}

# _sc_has_unquoted_heredoc_expansion <cmd>
#   Returns 0 if the command has a `<<WORD` heredoc (WORD unquoted) whose
#   body (following text in the same command string) contains $VAR, ${VAR},
#   or $(...). Quoted openers (`<<'EOF'` or `<<"EOF"`) suppress expansion
#   and do NOT trigger.
_sc_has_unquoted_heredoc_expansion() {
  local s="$1"
  # Find any `<<` followed by an unquoted word.
  # Bash 3.2 [[ =~ ]] with assembled ERE.
  local dq='"'
  local sq="'"
  # Unquoted heredoc: <<-?WORD where WORD starts with an identifier char
  # (not a quote). Capture in $BASH_REMATCH.
  local ere_unq='<<-?[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)'
  if [[ ! "$s" =~ $ere_unq ]]; then
    return 1
  fi
  # Reject if the opener is actually quoted: look for `<<'X` or `<<"X`
  # (with optional dash).
  local ere_quoted='<<-?[[:space:]]*('"$sq"'|'"$dq"')'
  if [[ "$s" =~ $ere_quoted ]]; then
    # There could be multiple heredocs; but for the reject rule we only
    # care whether an unquoted one with expansion exists. If ANY heredoc
    # opener is quoted we still need to see if an unquoted one exists too.
    # Strategy: iterate manually.
    local i=0
    local n=${#s}
    local found_unquoted=0
    while [ "$i" -lt "$n" ]; do
      if [ "${s:$i:2}" = "<<" ]; then
        local j=$((i + 2))
        # Optional dash
        if [ "${s:$j:1}" = "-" ]; then j=$((j + 1)); fi
        # Skip whitespace
        while [ "$j" -lt "$n" ] && [ "${s:$j:1}" = " " ]; do j=$((j + 1)); done
        local c="${s:$j:1}"
        case "$c" in
          "'"|'"') : ;; # quoted opener, skip
          [A-Za-z_])
            found_unquoted=1
            break
            ;;
        esac
        i=$((i + 2))
      else
        i=$((i + 1))
      fi
    done
    if [ "$found_unquoted" -eq 0 ]; then
      return 1
    fi
  fi
  # Look for expansion anywhere in the string: $VAR, ${VAR}, or $(.
  # $VAR matches $ followed by identifier char.
  if [[ "$s" =~ \$[A-Za-z_] ]]; then
    return 0
  fi
  if [[ "$s" =~ \$\{ ]]; then
    return 0
  fi
  if [[ "$s" =~ \$\( ]]; then
    return 0
  fi
  return 1
}

# _sc_has_quoted_brace <cmd>
#   Returns 0 if a literal `{` appears inside a double-quoted string and
#   is NOT part of a `${...}` parameter expansion.
_sc_has_quoted_brace() {
  local s="$1"
  local i=0
  local n=${#s}
  local ch prev2
  local in_sq=0 in_dq=0

  while [ "$i" -lt "$n" ]; do
    ch="${s:$i:1}"

    if [ "$in_sq" -eq 0 ] && [ "$in_dq" -eq 0 ] && [ "$ch" = '\' ]; then
      i=$((i + 2))
      continue
    fi

    if [ "$in_dq" -eq 1 ] && [ "$ch" = '\' ]; then
      # Escape inside double quotes
      i=$((i + 2))
      continue
    fi

    if [ "$in_sq" -eq 1 ]; then
      if [ "$ch" = "'" ]; then in_sq=0; fi
      i=$((i + 1))
      continue
    fi

    if [ "$in_dq" -eq 1 ]; then
      if [ "$ch" = '"' ]; then
        in_dq=0
        i=$((i + 1))
        continue
      fi
      if [ "$ch" = '{' ]; then
        # Check preceding char; if it was '$', this is ${...} — allowed.
        if [ "$i" -gt 0 ]; then
          prev2="${s:$((i-1)):1}"
          if [ "$prev2" = '$' ]; then
            i=$((i + 1))
            continue
          fi
        fi
        return 0
      fi
      i=$((i + 1))
      continue
    fi

    case "$ch" in
      "'") in_sq=1 ;;
      '"') in_dq=1 ;;
    esac
    i=$((i + 1))
  done

  return 1
}

# _sc_extract_sed_n_args <cmd>
#   If cmd matches `sed -n 'M,Np' <file>` shape (optionally prefixed with
#   `bash -c` etc — but we only match exact leading sed form), prints
#   "<file>\t<M>\t<N>" and returns 0. Otherwise returns 1.
_sc_extract_sed_n_args() {
  local s="$1"
  # Match: sed -n <quote>M,Np<quote> <file>
  # Use =~ with capture groups.
  local ere="^[[:space:]]*sed[[:space:]]+-n[[:space:]]+['\"]([0-9]+),([0-9]+)p['\"][[:space:]]+([^[:space:]]+)[[:space:]]*$"
  if [[ "$s" =~ $ere ]]; then
    local m="${BASH_REMATCH[1]}"
    local n="${BASH_REMATCH[2]}"
    local f="${BASH_REMATCH[3]}"
    printf '%s\t%s\t%s\n' "$f" "$m" "$n"
    return 0
  fi
  return 1
}

# _sc_strip_trailing_rc_echo <cmd>
#   If cmd ends with `; echo "RC=$?"` or `; echo RC=$?` (quoted or not,
#   with optional whitespace), prints the prefix with the trailing clause
#   removed and returns 0. Otherwise returns 1.
_sc_strip_trailing_rc_echo() {
  local s="$1"
  # Regex: capture everything up to `; echo [<qt>]RC=$?[<qt>]` at end.
  local ere='^(.+)[[:space:]]*;[[:space:]]*echo[[:space:]]+"?RC=\$\?"?[[:space:]]*$'
  if [[ "$s" =~ $ere ]]; then
    local prefix="${BASH_REMATCH[1]}"
    # Trim trailing whitespace from prefix
    # Parameter expansion with extglob-free pattern
    while [ -n "$prefix" ] && [ "${prefix: -1}" = " " ]; do
      prefix="${prefix%?}"
    done
    printf '%s\n' "$prefix"
    return 0
  fi
  return 1
}

# _sc_extract_var_inline_bash <cmd>
#   If cmd matches `K1=v1 [K2=v2 ...] bash Z args...`, prints
#   "K1=v1 K2=v2 -- bash Z args..." and returns 0.
_sc_extract_var_inline_bash() {
  local s="$1"
  # Leading assignments followed by `bash `.
  # Assignment token: [A-Za-z_][A-Za-z0-9_]*=<value-no-space>
  local rest="$s"
  # Trim leading whitespace
  while [ -n "$rest" ] && [ "${rest:0:1}" = " " ]; do
    rest="${rest:1}"
  done

  local assigns=""
  local consumed=0
  while :; do
    # Match leading `KEY=value ` (value must be a single space-free token)
    local ere='^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*)[[:space:]]+(.*)$'
    if [[ "$rest" =~ $ere ]]; then
      local token="${BASH_REMATCH[1]}"
      local tail="${BASH_REMATCH[2]}"
      # Check if tail starts with `bash ` (command, not another assignment)
      # But first, see if token is ALSO the last assignment before the command.
      # Peek at tail: if tail starts with `bash `, we stop consuming.
      if [[ "$tail" =~ ^bash[[:space:]] ]]; then
        if [ -z "$assigns" ]; then
          assigns="$token"
        else
          assigns="$assigns $token"
        fi
        consumed=1
        # Output: <assigns> -- <tail>
        printf '%s -- %s\n' "$assigns" "$tail"
        return 0
      fi
      # Otherwise, token is an assignment and tail contains more;
      # but only consume token if tail still looks like it leads to bash.
      # Heuristic: if tail has the form KEY=value..., keep consuming.
      if [[ "$tail" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
        if [ -z "$assigns" ]; then
          assigns="$token"
        else
          assigns="$assigns $token"
        fi
        rest="$tail"
        continue
      fi
      # Tail doesn't match — abort.
      return 1
    fi
    break
  done
  return 1
}

# _sc_extract_cd_and_bash <cmd>
#   If cmd is `cd X && bash Y args...`, prints `bash Y args...` and returns 0.
_sc_extract_cd_and_bash() {
  local s="$1"
  local ere='^[[:space:]]*cd[[:space:]]+[^[:space:]]+[[:space:]]*&&[[:space:]]*(bash[[:space:]]+.+)$'
  if [[ "$s" =~ $ere ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

# _sc_extract_cat_heredoc_exec <cmd>
#   If cmd is `cat > <tmp-path> <<EOF ... EOF ; bash <tmp-path>` (approximate
#   shape — we detect leading `cat >` redirect to a path, then a heredoc,
#   then `; bash <same-path>`), prints `<tmp-path>` and returns 0.
_sc_extract_cat_heredoc_exec() {
  local s="$1"
  # Leading shape: cat > <path> <<...
  local ere_head='^[[:space:]]*cat[[:space:]]+>[[:space:]]*([^[:space:]]+)[[:space:]]+<<'
  if [[ ! "$s" =~ $ere_head ]]; then
    return 1
  fi
  local path="${BASH_REMATCH[1]}"
  # Trailing shape: `; bash <path>` or `; bash <path> args`
  # Escape path's regex metacharacters — but path is typically /tmp/x.sh;
  # the `.` is the main concern. We'll do a literal substring check.
  # Look for the substring `bash <path>` at/near the end.
  local needle="bash $path"
  case "$s" in
    *"$needle"*)
      printf '%s\n' "$path"
      return 0
      ;;
  esac
  return 1
}

# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------

classify_command() {
  local cmd="$1"

  # --- Reject checks (run first; rejects dominate rewrites) ---

  if _sc_has_nested_cmd_sub "$cmd"; then
    printf '%s\n' 'reject:nested-cmd-sub'
    return 0
  fi

  local stages
  stages="$(_sc_count_top_level_stages "$cmd")"
  if [ "${stages:-1}" -gt 2 ]; then
    printf '%s\n' 'reject:compound-chain-gt2'
    return 0
  fi

  if _sc_has_unquoted_heredoc_expansion "$cmd"; then
    printf '%s\n' 'reject:heredoc-with-expansion'
    return 0
  fi

  if _sc_has_quoted_brace "$cmd"; then
    printf '%s\n' 'reject:quoted-brace'
    return 0
  fi

  # --- Rewrite checks ---

  # 3: cat-heredoc-exec
  local heredoc_tmp
  if heredoc_tmp="$(_sc_extract_cat_heredoc_exec "$cmd")"; then
    printf 'rewrite:bash scripts/util/run-probe.sh %s\n' "$heredoc_tmp"
    return 0
  fi

  # 1: trailing-rc-echo
  local stripped
  if stripped="$(_sc_strip_trailing_rc_echo "$cmd")"; then
    printf 'rewrite:%s\n' "$stripped"
    return 0
  fi

  # 2: sed-n-range
  local sed_args
  if sed_args="$(_sc_extract_sed_n_args "$cmd")"; then
    local _f _m _n
    _f="${sed_args%%$'\t'*}"
    local _rest="${sed_args#*$'\t'}"
    _m="${_rest%%$'\t'*}"
    _n="${_rest#*$'\t'}"
    printf 'rewrite:bash scripts/util/read-range.sh %s %s %s\n' "$_f" "$_m" "$_n"
    return 0
  fi

  # 4: cd-and-bash
  local cd_rewrite
  if cd_rewrite="$(_sc_extract_cd_and_bash "$cmd")"; then
    printf 'rewrite:%s\n' "$cd_rewrite"
    return 0
  fi

  # 5: var-inline-bash
  local var_rewrite
  if var_rewrite="$(_sc_extract_var_inline_bash "$cmd")"; then
    printf 'rewrite:bash scripts/util/with-env.sh %s\n' "$var_rewrite"
    return 0
  fi

  # 6: redirect-cmd-sub -- <cmd> > "$(inner)" or variants with >> or 2>&1>
  # ERE: a redirect operator followed by optional whitespace, optional
  # double quote, then $(.
  if [[ "$cmd" =~ (\>\>|2\>\&1\>|\>)[[:space:]]*\"?\$\( ]]; then
    printf '%s\n' 'rewrite:bash scripts/util/read-range.sh'
    return 0
  fi

  # Fall-through.
  printf '%s\n' 'allow'
}
