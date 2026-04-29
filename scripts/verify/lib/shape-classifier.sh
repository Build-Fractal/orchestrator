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
#             heredoc-with-expansion, quoted-brace,
#             cmd-sub-in-pattern, quoted-arg-newline-hash,
#             multiline-quoted-script, unquoted-brace-glob,
#             xargs-sh-c-compound-body
#
# Operator-facing remediation table for every reject class lives in
# ANTIPATTERNS.md (AP-006..AP-014); the hook diagnostics surface the
# matching AP-ID via reject_lookup in scripts/hooks/pre-bash-shape-guard.sh.

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

# -----------------------------------------------------------------------------
# Private detectors -- M028 extension (AP-010..AP-014)
# -----------------------------------------------------------------------------

# _sc_has_cmd_sub_in_pattern <cmd>
#   Returns 0 if the command's leading verb is grep / sed / awk and the
#   first quoted argument (regex pattern) contains a literal backtick byte.
#   The backtick reads as command-substitution attempt to Claude Code's
#   pre-shape parser regardless of the actual regex intent.
#   AP-010, FR-8, M028 Finding B #1 (Screenshot 4).
_sc_has_cmd_sub_in_pattern() {
  local s="$1"
  # Match: leading whitespace, then grep|sed|awk, then space, then optional
  # short-flag tokens (-x), then a single- or double-quoted argument whose
  # body contains at least one backtick.
  # Bash 3.2 ERE via [[ =~ ]]. Use POSIX char class [^[:space:]] for flags.
  local ere_sq="^[[:space:]]*(grep|sed|awk)([[:space:]]+-[^[:space:]]+)*[[:space:]]+'[^']*\`[^']*'"
  local ere_dq='^[[:space:]]*(grep|sed|awk)([[:space:]]+-[^[:space:]]+)*[[:space:]]+"[^"]*`[^"]*"'
  if [[ "$s" =~ $ere_sq ]]; then
    return 0
  fi
  if [[ "$s" =~ $ere_dq ]]; then
    return 0
  fi
  return 1
}

# _sc_has_quoted_arg_newline_hash <cmd>
#   Returns 0 if any double-quoted argument body contains a newline byte
#   immediately followed by a literal `#` byte. This trips Claude Code's
#   path-validation security heuristic.
#   AP-011, FR-9, M028 Finding B #2 (Screenshot 3).
_sc_has_quoted_arg_newline_hash() {
  local s="$1"
  local i=0
  local n=${#s}
  local ch nxt
  local in_sq=0 in_dq=0

  while [ "$i" -lt "$n" ]; do
    ch="${s:$i:1}"

    # Backslash escape outside single quotes: skip next char.
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
      if [ "$ch" = '"' ]; then
        in_dq=0
        i=$((i + 1))
        continue
      fi
      # Inside "..." -- check for newline + #
      if [ "$ch" = $'\n' ]; then
        nxt="${s:$((i+1)):1}"
        if [ "$nxt" = '#' ]; then
          return 0
        fi
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

# _sc_has_multiline_quoted_script <cmd>
#   Returns 0 if the command matches `(node|python|ruby|perl|sh|bash) -e/-c "<body>"`
#   and the quoted body contains a literal newline byte. Multi-line bodies
#   trip Claude Code's ansi_c_string parser fallthrough.
#   AP-012, FR-10, M028 Finding B #3 (Screenshot 5).
_sc_has_multiline_quoted_script() {
  local s="$1"
  # Locate the verb + flag pattern.
  local ere='^[[:space:]]*(node|python|python3|ruby|perl|sh|bash)[[:space:]]+(-e|-c)[[:space:]]+'
  if [[ ! "$s" =~ $ere ]]; then
    return 1
  fi
  # Walk past the verb + flag tokens then scan body bytes for newline.
  local i=0
  local n=${#s}
  local matched_verb=0 matched_flag=0
  local body_quote_char=""
  while [ "$i" -lt "$n" ]; do
    local ch="${s:$i:1}"
    if [ "$matched_verb" -eq 0 ]; then
      local rest="${s:$i}"
      if [[ "$rest" =~ ^[[:space:]]*(node|python3|python|ruby|perl|sh|bash)[[:space:]] ]]; then
        local verb="${BASH_REMATCH[1]}"
        # Skip leading whitespace before re-anchoring after verb.
        while [ "$i" -lt "$n" ] && [ "${s:$i:1}" = " " ]; do i=$((i + 1)); done
        # Advance past the verb.
        i=$(( i + ${#verb} ))
        # Skip whitespace after verb.
        while [ "$i" -lt "$n" ] && [ "${s:$i:1}" = " " ]; do i=$((i + 1)); done
        matched_verb=1
        continue
      fi
      i=$((i + 1))
      continue
    fi
    if [ "$matched_flag" -eq 0 ]; then
      # Expect -e or -c at i.
      if [ "${s:$i:2}" = "-e" ] || [ "${s:$i:2}" = "-c" ]; then
        i=$((i + 2))
        # Skip whitespace.
        while [ "$i" -lt "$n" ] && [ "${s:$i:1}" = " " ]; do i=$((i + 1)); done
        matched_flag=1
        continue
      fi
      return 1
    fi
    # i now at start of body. Body must start with " or '.
    if [ "$ch" = '"' ] || [ "$ch" = "'" ]; then
      body_quote_char="$ch"
      i=$((i + 1))
      # Scan body bytes.
      while [ "$i" -lt "$n" ]; do
        local bch="${s:$i:1}"
        # Backslash escape.
        if [ "$bch" = '\' ]; then
          i=$((i + 2))
          continue
        fi
        if [ "$bch" = "$body_quote_char" ]; then
          # End of body without finding newline.
          return 1
        fi
        if [ "$bch" = $'\n' ]; then
          return 0
        fi
        i=$((i + 1))
      done
      # Unterminated body -- treat as a candidate (the parser will trip too).
      return 0
    fi
    return 1
  done
  return 1
}

# _sc_has_unquoted_brace_glob <cmd>
#   Returns 0 if a `{...,...}` brace expansion appears outside both single
#   and double quotes. AP-007 catches the quoted case; this catches the
#   unquoted case.
#   AP-013, FR-11, M028 Finding B #4 (Screenshot 6).
_sc_has_unquoted_brace_glob() {
  local s="$1"
  local i=0
  local n=${#s}
  local ch
  local in_sq=0 in_dq=0
  local in_brace=0
  local brace_has_comma=0

  while [ "$i" -lt "$n" ]; do
    ch="${s:$i:1}"

    # Backslash escape.
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
      i=$((i + 1))
      continue
    fi

    case "$ch" in
      "'") in_sq=1 ;;
      '"') in_dq=1 ;;
      '{')
        # Skip ${...} parameter expansion (preceded by $).
        if [ "$i" -gt 0 ] && [ "${s:$((i-1)):1}" = '$' ]; then
          i=$((i + 1))
          continue
        fi
        in_brace=1
        brace_has_comma=0
        ;;
      ',')
        if [ "$in_brace" -eq 1 ]; then
          brace_has_comma=1
        fi
        ;;
      '}')
        if [ "$in_brace" -eq 1 ] && [ "$brace_has_comma" -eq 1 ]; then
          return 0
        fi
        in_brace=0
        brace_has_comma=0
        ;;
    esac
    i=$((i + 1))
  done

  return 1
}

# _sc_has_xargs_sh_c_compound_body <cmd>
#   Returns 0 if the command contains a `sh -c '<body>'` (or `bash -c '<body>'`)
#   token AND the combined connector count (top-level pipes/&&/||/; outside
#   the body PLUS in-body connectors) exceeds 2.
#
#   CON-5: body-descent is one level deep. If `<body>` itself contains another
#   `sh -c '<inner>'`, the inner is treated as opaque (its connectors are NOT
#   counted; the inner-sh-c token contributes 0 connectors).
#
#   AP-014, FR-12, M028 Finding G (operator screenshot 2026-04-28 22:25).
_sc_has_xargs_sh_c_compound_body() {
  local s="$1"
  # Locate `sh -c '` or `bash -c '` (single-quoted body).
  local ere="(sh|bash)[[:space:]]+-c[[:space:]]+'"
  if [[ ! "$s" =~ $ere ]]; then
    return 1
  fi

  # Walk character-by-character to find the body and extract it (one level).
  local i=0
  local n=${#s}
  local body=""
  local found=0
  while [ "$i" -lt "$n" ]; do
    local rest="${s:$i}"
    if [[ "$rest" =~ ^(sh|bash)[[:space:]]+-c[[:space:]]+\' ]]; then
      local prefix_len=$(( ${#BASH_REMATCH[0]} ))
      i=$((i + prefix_len))
      # Read body until closing single quote.
      while [ "$i" -lt "$n" ]; do
        local ch="${s:$i:1}"
        if [ "$ch" = "'" ]; then
          break
        fi
        body="${body}${ch}"
        i=$((i + 1))
      done
      found=1
      break
    fi
    i=$((i + 1))
  done

  if [ "$found" -eq 0 ]; then
    return 1
  fi

  # Strip any nested `sh -c '<inner>'` from body -- replace with placeholder.
  # CON-5: one-level-deep descent only.
  local clean_body=""
  local bi=0
  local bn=${#body}
  while [ "$bi" -lt "$bn" ]; do
    local brest="${body:$bi}"
    if [[ "$brest" =~ ^(sh|bash)[[:space:]]+-c[[:space:]]+\' ]]; then
      local plen=$(( ${#BASH_REMATCH[0]} ))
      bi=$((bi + plen))
      # Skip until next single quote.
      while [ "$bi" -lt "$bn" ] && [ "${body:$bi:1}" != "'" ]; do
        bi=$((bi + 1))
      done
      # Skip the closing quote.
      if [ "$bi" -lt "$bn" ]; then bi=$((bi + 1)); fi
      clean_body="${clean_body}OPAQUE"
      continue
    fi
    clean_body="${clean_body}${body:$bi:1}"
    bi=$((bi + 1))
  done

  # Count in-body connectors using the existing top-level stage counter.
  local body_stages
  body_stages="$(_sc_count_top_level_stages "$clean_body")"
  # Count top-level stages of the outer command.
  local outer_stages
  outer_stages="$(_sc_count_top_level_stages "$s")"
  # Combined connectors = (body_stages - 1) + (outer_stages - 1).
  local combined=$(( (body_stages - 1) + (outer_stages - 1) ))
  if [ "$combined" -gt 2 ]; then
    return 0
  fi
  return 1
}

# -----------------------------------------------------------------------------
# Rewrite extractors
# -----------------------------------------------------------------------------

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

  # AP-014 runs BEFORE the top-level-count check so the more specific
  # verdict takes precedence on the sh -c '<body>' shape. Load-bearing
  # for M028/SC-6 (CON-5 body-descent depth bound).
  if _sc_has_xargs_sh_c_compound_body "$cmd"; then
    printf '%s\n' 'reject:xargs-sh-c-compound-body'
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

  # AP-010..AP-013 run AFTER the existing M021 reject checks so the more
  # general rules (compound-chain-gt2, nested-cmd-sub, etc.) take
  # precedence on shapes those rules already catch. M028 Finding B four
  # sub-shapes.
  if _sc_has_cmd_sub_in_pattern "$cmd"; then
    printf '%s\n' 'reject:cmd-sub-in-pattern'
    return 0
  fi

  if _sc_has_quoted_arg_newline_hash "$cmd"; then
    printf '%s\n' 'reject:quoted-arg-newline-hash'
    return 0
  fi

  if _sc_has_multiline_quoted_script "$cmd"; then
    printf '%s\n' 'reject:multiline-quoted-script'
    return 0
  fi

  if _sc_has_unquoted_brace_glob "$cmd"; then
    printf '%s\n' 'reject:unquoted-brace-glob'
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
