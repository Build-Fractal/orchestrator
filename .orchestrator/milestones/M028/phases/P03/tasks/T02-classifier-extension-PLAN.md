---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M028"
name: "Classifier Extension (5 New Pattern Detectors)"
depends_on: ["T01"]
---

## Prerequisites

- `scripts/verify/lib/shape-classifier.sh` exists (verified: `[ -f /Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/verify/lib/shape-classifier.sh ]` returns exit 0; current line count 533).
- The existing classifier exports `classify_command(cmd)` returning one of `allow`, `rewrite:<result>`, `reject:<class>` per the contract documented in the file header (lines 1..27).
- The existing private helpers (`_sc_count_top_level_stages`, `_sc_has_nested_cmd_sub`, `_sc_has_unquoted_heredoc_expansion`, `_sc_has_quoted_brace`, plus the rewrite extractors) are stable and must not change behavior.
- `bash --version` reports 3.2 or later (constitution principle IX; verified via macOS default shell baseline).
- `ANTIPATTERNS.md` carries entries AP-010..AP-014 (T01 deliverable; the classifier's reject-class labels must match the AP entry titles' `cmd-sub-in-pattern` / `quoted-arg-newline-hash` / `multiline-quoted-script` / `unquoted-brace-glob` / `xargs-sh-c-compound-body` substrings).

## Description

Extend the M021 shape classifier with five new private detectors and five new reject branches in `classify_command`, closing the gap between the in-the-wild screenshot shapes and the orchestrator's hook-rejection contract. The five detectors realize FR-8 through FR-12 of the M028 spec.

The classifier's existing 10-pattern matrix (rejects + rewrites) is preserved verbatim per CON-7 strict-superset. The new code is **additive**: five new helper functions, five new reject branches in `classify_command`, plus the file-header pattern-class-label list extended.

Critical correctness invariant (load-bearing for the spec's SC-6 / FR-12): **AP-014 (`xargs-sh-c-compound-body`) runs BEFORE the existing AP-009 top-level-count check** so the more specific verdict takes precedence on the SE-09 shape. Without this ordering, the verbatim Finding G screenshot still rejects but the verdict drifts from `xargs-sh-c-compound-body` back to `compound-chain-gt2`, and the corpus replay (T04 + T05) reports a verdict mismatch.

AP-010..AP-013 run AFTER the existing AP-009 / AP-008 / AP-007 reject checks so the existing M021 reject precedence is preserved on shapes those rules already catch (e.g. a backtick inside a regex inside a 3-stage pipeline still rejects as `compound-chain-gt2`, not as `cmd-sub-in-pattern` — the more general rule fires first; AP-010 only catches the shape when no other reject applies).

## Steps

1. **Read the existing classifier** at `scripts/verify/lib/shape-classifier.sh`, particularly:
   - Lines 1..27: file header comment listing the pattern-class labels — extend this list with the five new labels.
   - Lines 38..131: `_sc_count_top_level_stages` — model for character-by-character scanning with quote-state tracking. The new detectors follow the same pattern.
   - Lines 137..187: `_sc_has_nested_cmd_sub` — model for depth tracking inside `$(...)`.
   - Lines 256..314: `_sc_has_quoted_brace` — model for double-quote-state tracking.
   - Lines 453..532: `classify_command` — the dispatch function; add the new reject branches in the order documented below.

2. **Update the file-header pattern-class-label list** (lines 21..24). Add five new labels under "Rejects":

```
# Pattern-class labels (verbatim, contractually stable):
#   Rewrites: trailing-rc-echo, sed-n-range, cat-heredoc-exec,
#             cd-and-bash, var-inline-bash, redirect-cmd-sub
#   Rejects:  nested-cmd-sub, compound-chain-gt2,
#             heredoc-with-expansion, quoted-brace,
#             cmd-sub-in-pattern, quoted-arg-newline-hash,
#             multiline-quoted-script, unquoted-brace-glob,
#             xargs-sh-c-compound-body
```

3. **Add `_sc_has_cmd_sub_in_pattern <cmd>`** — detect literal backtick inside the first regex argument to grep / sed / awk. Insert after `_sc_has_quoted_brace` (lines 314) and before the rewrite extractors:

```bash
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
```

4. **Add `_sc_has_quoted_arg_newline_hash <cmd>`** — detect literal newline followed by `#` inside a double-quoted CLI argument:

```bash
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
      # Inside "..." — check for newline + #
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
```

5. **Add `_sc_has_multiline_quoted_script <cmd>`** — detect multi-line body inside `(node|python|ruby|perl|sh|bash) -e/-c "..."`:

```bash
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
  # Find the quoted body following the flag and scan its bytes for newline.
  # We walk past the verb + flag tokens character-by-character.
  local i=0
  local n=${#s}
  local matched_verb=0 matched_flag=0
  local in_sq=0 in_dq=0
  local body_quote_char=""
  while [ "$i" -lt "$n" ]; do
    local ch="${s:$i:1}"
    # Skip leading whitespace.
    if [ "$matched_verb" -eq 0 ]; then
      # Match the verb token (look for any of node/python/python3/ruby/perl/sh/bash).
      local rest="${s:$i}"
      if [[ "$rest" =~ ^[[:space:]]*(node|python3|python|ruby|perl|sh|bash)[[:space:]] ]]; then
        local verb="${BASH_REMATCH[1]}"
        # Advance past verb + trailing whitespace.
        local pos=$(( i + ${#verb} ))
        # Skip leading whitespace before verb match.
        while [ "$pos" -lt "$n" ] && [ "${s:$pos:1}" = " " ]; do pos=$((pos + 1)); done
        i=$pos
        # Re-check from i.
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
      # Unterminated body — treat as a candidate (the parser will trip too).
      return 0
    fi
    return 1
  done
  return 1
}
```

6. **Add `_sc_has_unquoted_brace_glob <cmd>`** — detect raw `{N,M,...}` outside any quoted region:

```bash
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
```

7. **Add `_sc_has_xargs_sh_c_compound_body <cmd>`** (CON-5, load-bearing) — detect compound chain inside `sh -c '<body>'` or `bash -c '<body>'`, sum with top-level pipe count:

```bash
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
  # Bash 3.2 ERE.
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
    # Look for `sh -c '` or `bash -c '` at position i.
    local rest="${s:$i}"
    if [[ "$rest" =~ ^(sh|bash)[[:space:]]+-c[[:space:]]+\' ]]; then
      # Advance past the opening quote.
      local prefix_len=$(( ${#BASH_REMATCH[0]} ))
      i=$((i + prefix_len))
      # Read body until closing single quote (single-quoted body — no
      # escape sequences in POSIX sh single quotes; the body ends at the
      # first unescaped single quote).
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

  # Strip any nested `sh -c '<inner>'` from body — replace with placeholder.
  # CON-5: one-level-deep descent only.
  # We walk the body and remove `sh -c '...'` substrings that themselves
  # appear; replace with `OPAQUE` (a token with no connectors).
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
  # The counter returns "stages" = connectors + 1 for the body-as-a-cmd-line.
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
```

8. **Update `classify_command`** (around line 453) to add the five new reject branches in the order documented below. Insert AP-014 BEFORE the existing `_sc_count_top_level_stages > 2` check (load-bearing precedence; load-bearing for SC-6); insert AP-010..AP-013 AFTER the existing four reject checks, in numerical order:

```bash
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

  # --- Rewrite checks (unchanged from M021) ---
  # ... (existing 6 rewrite extractors stay verbatim)
```

The 6 existing rewrite extractors (`_sc_extract_cat_heredoc_exec`, `_sc_strip_trailing_rc_echo`, `_sc_extract_sed_n_args`, `_sc_extract_cd_and_bash`, `_sc_extract_var_inline_bash`, plus the redirect-cmd-sub regex) are preserved verbatim.

9. **Run the M021 strict-superset regression check manually** before commit:

```bash
bash scripts/verify/replay-prompt-corpus.sh
```

This must report `WOULD_PROMPT=0/20` and `PASS: replay-prompt-corpus.sh` on all 20 M021 entries with the M028-extended classifier (CON-7 / SC-8). Any divergence is a regression and the new classifier must be debugged before T03 lands.

10. **Author the per-task verifier** at `scripts/verify/m028/p03-classifier-new-classes.sh` (chmod +x). The verifier sources `scripts/verify/lib/shape-classifier.sh`, calls `classify_command` against the five canonical SE-02..SE-05 + SE-09 verbatim commands plus the ID-27 nested-`sh -c` boundary case, and asserts the verdicts listed in Must-Haves. The verifier is a per-task deliverable so `auto-loop.sh --step=V` resolves at T02 time (per CLAUDE.md hotfix "Plan-time verifier-availability cross-check missing"); T05 still owns the cross-cutting replay harness + per-finding verifiers + roll-up.

   Reference shape: see `scripts/verify/m028/p03-antipatterns-entries.sh` for a single-script-file (AD-19) verifier with `set -u`, `SCRIPT_DIR`/`REPO_ROOT` self-location via `BASH_SOURCE`, and prefixed `PASS:` / `FAIL:` output. Bash 3.2 + POSIX-sh safe.

11. **Commit** via `git commit -F <message-file>` (the heredoc-with-expansion shape is rejected by the active hook per CLAUDE.md hotfix; use file form). Suggested message file body:

```
M028/P03/T02: classifier extension — 5 new pattern detectors

AP-010 cmd-sub-in-pattern: backtick inside grep/sed/awk regex argument
AP-011 quoted-arg-newline-hash: literal newline + # inside double-quoted CLI arg
AP-012 multiline-quoted-script: multi-line body inside node -e / python -c / similar
AP-013 unquoted-brace-glob: raw {N,M,...} brace expansion outside quotes
AP-014 xargs-sh-c-compound-body: combined top-level + sh -c body connectors > 2
                                  (CON-5: one-level-deep descent only)

AP-014 ordered before existing AP-009 top-level-count check so the more
specific verdict takes precedence on the SE-09 shape (load-bearing for
M028/SC-6). AP-010..AP-013 ordered after existing M021 rejects so prior
precedence is preserved on shapes those rules already catch.

CON-7 strict-superset: all 20 M021 corpus entries replay with identical
verdicts (verified via scripts/verify/replay-prompt-corpus.sh).
```

## Must-Haves

This task addresses the phase Truth: "The shape classifier emits the AP-010..AP-014 reject classes verbatim for the five canonical SE-02..SE-05 + SE-09 commands; the AP-014 verdict takes precedence over AP-009 for the `sh -c '<body>'` shape."

The per-task verifier `scripts/verify/m028/p03-classifier-new-classes.sh` (co-authored with this task — see Steps step 10) asserts:
- `classify_command` outputs `reject:cmd-sub-in-pattern` for the SE-02 verbatim command.
- `classify_command` outputs `reject:quoted-arg-newline-hash` for the SE-03 verbatim command.
- `classify_command` outputs `reject:multiline-quoted-script` for the SE-04 verbatim command.
- `classify_command` outputs `reject:unquoted-brace-glob` for the SE-05 verbatim command.
- `classify_command` outputs `reject:xargs-sh-c-compound-body` for the SE-09 verbatim command (NOT `reject:compound-chain-gt2`).
- `classify_command` outputs `reject:xargs-sh-c-compound-body` for the ID-27 boundary command (nested `sh -c` opaque-treatment).
- The existing M021 corpus 20 entries replay with verdicts unchanged (delegated assertion: T05's `p03-replay-harness-clean.sh` runs the full 27-entry harness which subsumes the M021 baseline).

## Verification

```bash
bash scripts/verify/m028/p03-classifier-new-classes.sh
```

```bash
bash scripts/verify/replay-prompt-corpus.sh
```

## Notes

`scripts/verify/check-must-haves.sh .orchestrator/milestones/M028/phases/P03` is a phase-level check; it runs at phase close, not per-task. Per-task `## Verification` invokes only task-scoped verifiers (matches P02 convention).

## Inputs

### From Previous Tasks

- `ANTIPATTERNS.md` (from T01) — the five new entries' titles use the substrings `cmd-sub-in-pattern`, `quoted-arg-newline-hash`, `multiline-quoted-script`, `unquoted-brace-glob`, `xargs-sh-c-compound-body`. The classifier's reject-class labels MUST match these substrings byte-for-byte (the hook's diagnostic-format invariant `REJECT: <class> — use ...` is consumed by the corpus replay's `grep -qF "REJECT: ${class}"` assertion in T05's harness).

### From Disk (Pre-existing)

- `scripts/verify/lib/shape-classifier.sh` — the existing classifier; T02 extends it.
- `tests/fixtures/m021-prompt-corpus.txt` — the 20 M021 entries; T02 must NOT change their verdicts (CON-7 / SC-8).
- `scripts/verify/replay-prompt-corpus.sh` — the M021 SC-1 historical regression harness (EXPECTED_TOTAL=20); T02 runs this to prove no M021 regression before commit.
- `.orchestrator/milestones/M028/phases/P01/classifier-audit.md` — verbatim SE-02..SE-09 commands; T02 runs each through the extended classifier as the spec-aligned positive-control verdict checks.

### Key API Surface (consumed by T03 + T04 + T05)

After T02:
- `classify_command "<cmd>"` — single-line stdout of `allow` / `rewrite:<result>` / `reject:<class>` where `<class>` ∈ `{nested-cmd-sub, compound-chain-gt2, heredoc-with-expansion, quoted-brace, cmd-sub-in-pattern, quoted-arg-newline-hash, multiline-quoted-script, unquoted-brace-glob, xargs-sh-c-compound-body}` (existing 4 + new 5 = 9 reject classes; plus 6 rewrite classes).
- The 5 new private detectors (`_sc_has_*`) are sourceable but not required by downstream tasks — the public contract is `classify_command`.

## Constraints

- **CON-1 (AD-19)**: This is a single-script extension to an existing flat file. No new helper directories.
- **CON-2 (bash 3.2 + POSIX sh)**: All new code uses bash 3.2 grammar — `[[ =~ ]]` ERE, character-by-character `${s:$i:1}` indexing, no `declare -A`, no process substitution. The body-extraction in `_sc_has_xargs_sh_c_compound_body` uses `${body}${ch}` string concatenation (bash 3.2 safe; no `+=`).
- **CON-5 (one-level-deep descent)**: The body-descent is one level only. The plan documents the inner-sh-c-opaque collapse explicitly.
- **CON-6 (no-new-runtime-deps)**: Pure bash. No `jq` / `node` / `python`.
- **CON-7 (no-M021-regression)**: All 20 M021 corpus entries replay with verdicts unchanged. The strict-superset invariant is the load-bearing M028 ↔ M021 contract.
- **AP-014 ordering invariant**: `_sc_has_xargs_sh_c_compound_body` MUST be called BEFORE `_sc_count_top_level_stages > 2` in `classify_command`. Otherwise SC-6 fails (verdict drifts from `xargs-sh-c-compound-body` to `compound-chain-gt2`).
- **Classifier-output stability**: `classify_command` continues to emit exactly one of `allow`, `rewrite:<result>`, `reject:<class>` on a single line. No new grammar.

## Expected Output

After running `bash scripts/verify/m028/p03-classifier-new-classes.sh`:

```
PASS: SE-02 (backtick in grep regex) -> reject:cmd-sub-in-pattern
PASS: SE-03 (newline+# in quoted arg) -> reject:quoted-arg-newline-hash
PASS: SE-04 (multi-line node -e body) -> reject:multiline-quoted-script
PASS: SE-05 (unquoted brace glob) -> reject:unquoted-brace-glob
PASS: SE-09 (verbatim Finding G) -> reject:xargs-sh-c-compound-body
PASS: SE-09 verdict precedence: AP-014 over AP-009 (CON-5)
PASS: ID-27 nested sh -c opaque-treatment (CON-5 one-level-deep)
PASS: M021 corpus regression (20/20 unchanged)
PASS: p03-classifier-new-classes.sh
```

After running `bash scripts/verify/replay-prompt-corpus.sh`:

```
PASS: entry 01 classifier: rewrite:bash scripts/util/run-probe.sh /tmp/m011-p05-probe.sh
PASS: entry 01 hook: rewrite emits updatedInput
... (20 entries)
PASS: corpus entry count: 20
WOULD_PROMPT=0/20
PASS: replay-prompt-corpus.sh
```

(Entry-by-entry pass list across all 20 M021 entries; the M028 classifier extension must not change any M021 verdict.)
