#!/usr/bin/env bash
# scripts/lib/preservation-check.sh
#
# Preservation-contract self-check library (M018 P02 T01).
#
# Pinned to grammar contract: references/compression-grammar.md v1.0.1
# (status: Reviewed). Bumping the grammar requires an explicit edit to
# this library + verifier run.
#
# Export surface:
#   - PRES_PATTERNS_REGEX (parallel indexed array; see PRES_PATTERN_NAMES)
#   - PRES_PATTERN_NAMES  (parallel indexed array; index i names pattern i)
#   - pres_check_section <section_id> <pre_file> <post_file> [tier]
#   - pres_emit_violation <tier> <section> <pattern> <log_file>
#   - pres_density_pre_check <section_file> <max_density_pct>
#
# Shape rules (AP-009 / AD-19):
#   - No compound chains > 2.
#   - No $(...|...) (no pipes inside command substitutions).
#   - No plain subshells `( ... )`.
#   - No process substitution <(...).
#   - Iteration uses `while [ "$i" -lt "$N" ]; do ... ; i=$(( i + 1 )); done`.
#
# Sourceable: NO `set -eu` at file scope. The selftest entry point is
# gated by the `${BASH_SOURCE[0]:-$0}" = "$0"` idiom so sourcing is a
# pure function-declaration side-effect.
#
# Bash 3.2 compatible (MEM001): no `declare -A`, no `mapfile`/`readarray`,
# no extended-regex `[[ =~ ]]` features beyond what 3.2 ships. Uses
# parallel indexed arrays for the pattern vocabulary.

# ---------------------------------------------------------------------------
# Cross-tier preserved-pattern vocabulary (verbatim from grammar v1.0.1
# `## Preserved-Pattern Vocabulary` table). Index i in PRES_PATTERNS_REGEX
# corresponds to index i in PRES_PATTERN_NAMES.
# ---------------------------------------------------------------------------
PRES_PATTERNS_REGEX=(
  '^---$'
  '^`{3,}[a-zA-Z0-9_-]*$'
  '/[A-Za-z0-9_./-]+\.(sh|md|yml|yaml|jsonl?|py|txt)'
  'scripts/[A-Za-z0-9_./-]+\.sh'
  '\bMEM[0-9]{3}\b'
  'orchestrator:[a-z-]+'
  'https?://[^[:space:])]+'
  '^\{.*\}$'
  '&lt;TODO:[^&gt;]+&gt;'
  '<!-- compressed:tier[0-9]+ [^>]*-->'
)

PRES_PATTERN_NAMES=(
  'yaml-frontmatter-delim'
  'code-fence'
  'absolute-path'
  'repo-relative-script-path'
  'mem-id'
  'command-name'
  'url'
  'jsonl-record'
  'scaffold-todo'
  'compression-marker'
)

# ---------------------------------------------------------------------------
# pres_check_section <section_id> <pre_file> <post_file> [tier]
#
# Regex-driven pattern walker. For each row in the cross-tier vocabulary,
# counts matches in <pre_file> and <post_file>. Strict multiplicity for
# tier1/tier2 (default); at-least-once semantics for tier3.
#
# Returns 0 on PASS, 1 on first violation. Prints one VIOLATION: line to
# stderr per first failed pattern (single-violation diagnostic — caller
# is expected to bail on first failure per FR-2 fail-closed semantics).
# ---------------------------------------------------------------------------
pres_check_section() {
  local section_id="$1"
  local pre_file="$2"
  local post_file="$3"
  local tier="${4:-tier2}"

  if [ ! -f "$pre_file" ]; then
    printf 'pres_check_section: pre_file not found: %s\n' "$pre_file" >&2
    return 1
  fi
  if [ ! -f "$post_file" ]; then
    printf 'pres_check_section: post_file not found: %s\n' "$post_file" >&2
    return 1
  fi

  local pat_count="${#PRES_PATTERNS_REGEX[@]}"
  local i=0
  local regex name pre_count post_count
  while [ "$i" -lt "$pat_count" ]; do
    regex="${PRES_PATTERNS_REGEX[$i]}"
    name="${PRES_PATTERN_NAMES[$i]}"
    # `grep -c` always prints a count (0 when no matches) but exits 1 on
    # zero. Capture stdout only; ignore exit via trailing `; true`-style
    # shape using a wrapper. We use `grep ... ; printf` is not allowed
    # (compound chain). Instead: rely on the fact that `grep -c` writes
    # the count to stdout regardless of exit code; redirect stderr and
    # accept whatever exits — bash `local x=$(cmd)` does not propagate
    # the substitution's exit code (no `set -e` at file scope).
    pre_count=$(grep -cE "$regex" "$pre_file" 2>/dev/null)
    if [ -z "$pre_count" ]; then pre_count=0; fi
    post_count=$(grep -cE "$regex" "$post_file" 2>/dev/null)
    if [ -z "$post_count" ]; then post_count=0; fi
    case "$tier" in
      tier3)
        if [ "$pre_count" -gt 0 ] && [ "$post_count" -eq 0 ]; then
          printf 'VIOLATION: section=%s pattern=%s tier=%s pre=%d post=%d\n' \
            "$section_id" "$name" "$tier" "$pre_count" "$post_count" >&2
          return 1
        fi
        ;;
      *)
        if [ "$pre_count" -ne "$post_count" ]; then
          printf 'VIOLATION: section=%s pattern=%s tier=%s pre=%d post=%d\n' \
            "$section_id" "$name" "$tier" "$pre_count" "$post_count" >&2
          return 1
        fi
        ;;
    esac
    i=$(( i + 1 ))
  done
  return 0
}

# ---------------------------------------------------------------------------
# pres_emit_violation <tier> <section> <pattern> <log_file>
#
# Appends a single-line `tier_preservation_violation` JSONL record to
# <log_file>. Schema verbatim from grammar contract `## Failure Semantics
# (FR-2)` (line 371):
#
#   {"record_type":"tier_preservation_violation","tier":"<tier>",
#    "section":"<section>","pattern":"<regex>","timestamp":"<ISO8601 UTC>"}
#
# Bail-safe: directory-create or append failure logs to stderr and
# returns 0 (never crashes the dispatcher). Never reads or modifies any
# file other than <log_file>.
# ---------------------------------------------------------------------------
pres_emit_violation() {
  local tier="$1"
  local section="$2"
  local pattern="$3"
  local log_file="$4"

  local ts log_dir pattern_esc
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  log_dir=$(dirname "$log_file")
  if ! mkdir -p "$log_dir" 2>/dev/null; then
    printf 'preservation-check: emit skipped (mkdir failed on %s)\n' "$log_dir" >&2
    return 0
  fi

  # JSON-escape: backslash first, then double-quote.
  pattern_esc=$(printf '%s' "$pattern" | sed 's/\\/\\\\/g; s/"/\\"/g')

  printf '{"record_type":"tier_preservation_violation","tier":"%s","section":"%s","pattern":"%s","timestamp":"%s"}\n' \
    "$tier" "$section" "$pattern_esc" "$ts" \
    >> "$log_file" 2>/dev/null || true
  return 0
}

# ---------------------------------------------------------------------------
# pres_density_pre_check <section_file> <max_density_pct>
#
# MIT-08 groundwork. Computes coarse "preservation density" metric:
#   density_pct = (count of preserved-pattern matches) / (total bytes / 100)
#
# Returns 0 (proceed) when density is below <max_density_pct>; returns 1
# (refuse) when density exceeds threshold. Returns 0 on missing or empty
# file (fail-open — preservation density of an empty section is 0).
#
# Integer math throughout (bash 3.2 has no float):
#   density_x100 = matches * 10000 / total_bytes
#   threshold_x100 = max_density_pct * 100
#
# P02 ships only the API. P06 plumbs this in front of tier3's LLM call.
# ---------------------------------------------------------------------------
pres_density_pre_check() {
  local section_file="$1"
  local max_density_pct="$2"

  if [ ! -f "$section_file" ]; then
    return 0
  fi

  local total_bytes
  total_bytes=$(wc -c < "$section_file" 2>/dev/null | tr -d ' ')
  if [ -z "$total_bytes" ] || [ "$total_bytes" -eq 0 ]; then
    return 0
  fi

  local pat_count="${#PRES_PATTERNS_REGEX[@]}"
  local total_matches=0
  local i=0
  local regex m
  while [ "$i" -lt "$pat_count" ]; do
    regex="${PRES_PATTERNS_REGEX[$i]}"
    m=$(grep -cE "$regex" "$section_file" 2>/dev/null)
    if [ -z "$m" ]; then m=0; fi
    total_matches=$(( total_matches + m ))
    i=$(( i + 1 ))
  done

  local density_x100
  density_x100=$(( total_matches * 10000 / total_bytes ))
  local threshold_x100
  threshold_x100=$(( max_density_pct * 100 ))

  if [ "$density_x100" -gt "$threshold_x100" ]; then
    printf 'DENSITY-REFUSE: section=%s density_x100=%d threshold_x100=%d\n' \
      "$section_file" "$density_x100" "$threshold_x100" >&2
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Selftest entry point. Sourceable-safe: only runs when this script is
# invoked directly with the `selftest` argument. Sourcing this file (the
# normal P03/P04/P06 use case) is a pure function-declaration side-effect.
# ---------------------------------------------------------------------------
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ] && [ "${1:-}" = "selftest" ]; then
  tmp=$(mktemp -d)
  printf 'MEM020 says hello\n```\nfoo\n```\n' > "$tmp/pre.txt"
  printf 'MEM020 says hello\n```\nbar\n```\n' > "$tmp/post.txt"
  pres_check_section "test" "$tmp/pre.txt" "$tmp/post.txt" tier2
  rc=$?
  rm -rf "$tmp"
  if [ "$rc" -eq 0 ]; then
    printf 'PASS: pres_check_section selftest\n'
    exit 0
  else
    printf 'FAIL: pres_check_section selftest rc=%d\n' "$rc"
    exit 1
  fi
fi
