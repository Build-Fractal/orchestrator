#!/usr/bin/env bash
# scripts/diagnostics/check-dead-infra.sh -- Dead-infrastructure linter for config knobs.
#
# Catches the "fully defined, fully typed, fully dead" pattern: a config knob
# declared in templates/orchestrator-config-default.yml that no script,
# command, or reference doc actually reads. Ported from
# linter/dead_infra.py in the sister project conversus-oss (Tier 2
# Principle XII -- No Dead Infrastructure).
#
# A knob is alive when at least one of these holds:
#   1. The leaf-key name appears (as a literal) in scripts/, commands/,
#      or references/, in a non-template file.
#   2. The line immediately preceding the knob in the YAML carries a
#      `# consumer: <code> -- <why>` annotation (explicit attribution for
#      knobs read indirectly, e.g. via dynamic key lookup).
#
# Knobs with leaf names in the GENERIC_LEAF_SKIPLIST (enabled, mode, ...)
# are exempt: those keys appear under several blocks and would produce
# noisy matches. Use a consumer: annotation to track them if needed.
#
# Usage:
#   scripts/diagnostics/check-dead-infra.sh             # quiet pass/fail
#   scripts/diagnostics/check-dead-infra.sh --verbose   # per-leaf trace
#
# Exit codes:
#   0  no dead knobs
#   1  one or more dead knobs found
#   2  configuration error (template missing or unreadable)
#
# Bash 3.2 / POSIX awk. No jq, no python, no associative arrays.

set -u

ROOT="${ORCHESTRATOR_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
TEMPLATE="$ROOT/templates/orchestrator-config-default.yml"
SEARCH_DIRS="scripts commands references"

VERBOSE=0
case "${1:-}" in
  -v|--verbose) VERBOSE=1 ;;
  -h|--help)
    sed -n '2,30p' "$0"
    exit 0
    ;;
  "") : ;;
  *)
    echo "FAIL: unknown argument '$1'" >&2
    exit 2
    ;;
esac

if [ ! -f "$TEMPLATE" ]; then
  echo "ERROR: template not found at $TEMPLATE" >&2
  exit 2
fi

# Generic leaf names that appear under several parent blocks. Use a
# `# consumer:` annotation to track these explicitly when needed.
GENERIC_LEAF_SKIPLIST=" enabled mode version "

# --- enumerate (qualified-path, leaf, line-number, has-consumer-annotation) ---
# Two passes via awk reading the template twice. Pass 1 collects every key
# line with its indent + value-shape. Pass 2 prints `path TAB leaf TAB lineno
# TAB consumer_flag` for each leaf (a key whose immediate descendant is not
# another `key:` line at deeper indent).
#
# `consumer_flag` is 1 when the immediately preceding non-blank line is a
# comment of the shape `# consumer: ...`; else 0.

enumerate_leaves() {
  awk '
    function is_blank(s) { return s ~ /^[[:space:]]*$/ }
    function is_comment(s) { return s ~ /^[[:space:]]*#/ }
    function strip_inline_comment(s,    p) {
      p = index(s, "#")
      if (p > 0) s = substr(s, 1, p - 1)
      sub(/[[:space:]]+$/, "", s)
      return s
    }

    FNR == NR {
      lines[NR] = $0
      total = NR
      next
    }

    {
      # second pass: classify each line we previously captured
      line = lines[FNR]
      if (is_blank(line) || is_comment(line)) next
      # detect a key line: optional indent, then key, then `:`
      if (line !~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*:/) next

      # extract indent and key
      match(line, /^[ ]*/)
      indent = RLENGTH
      rest = substr(line, indent + 1)
      cpos = index(rest, ":")
      key  = substr(rest, 1, cpos - 1)
      tail = substr(rest, cpos + 1)
      tail = strip_inline_comment(tail)
      sub(/^[[:space:]]+/, "", tail)

      # determine path: pop stack to current indent, then push this key
      while (top > 0 && stack_indent[top] >= indent) top--
      top++
      stack_indent[top] = indent
      stack_key[top]    = key

      # build path
      path = ""
      for (i = 1; i <= top; i++) {
        if (i == 1) path = stack_key[i]
        else        path = path "." stack_key[i]
      }

      # is this line a sub-map header? sub-map = tail is empty AND the
      # next non-blank, non-comment line has deeper indent AND starts
      # with a key (vs. a list-item dash).
      is_submap = 0
      if (tail == "") {
        j = FNR + 1
        while (j <= total) {
          nxt = lines[j]
          if (is_blank(nxt) || is_comment(nxt)) { j++; continue }
          match(nxt, /^[ ]*/)
          nxt_indent = RLENGTH
          if (nxt_indent <= indent) break
          # deeper-indent line: if it is a key, this is a sub-map; if
          # it starts with `-`, this is a block-list scalar leaf.
          stripped = substr(nxt, nxt_indent + 1)
          if (stripped ~ /^[A-Za-z_][A-Za-z0-9_]*:/) is_submap = 1
          break
        }
      }

      if (is_submap) next  # not a leaf

      # consumer-annotation lookback: walk backward over blank/comment
      # lines; if the nearest non-blank comment matches `# consumer:`,
      # mark consumed.
      consumer_flag = 0
      k = FNR - 1
      while (k >= 1) {
        prev = lines[k]
        if (is_blank(prev)) { k--; continue }
        if (is_comment(prev)) {
          if (prev ~ /^[[:space:]]*#[[:space:]]*consumer:/) consumer_flag = 1
          break
        }
        break
      }

      printf "%s\t%s\t%d\t%d\n", path, key, FNR, consumer_flag
    }
  ' "$TEMPLATE" "$TEMPLATE"
}

# --- check a single leaf for at least one reader in SEARCH_DIRS ---
# Returns 0 if a reader is found, 1 if dead.
has_reader() {
  _leaf="$1"
  # word-boundary match against the leaf-key literal. Skip the template
  # itself; matches inside it are by definition not readers.
  # macOS BSD grep supports `-w` and `-r`. Excluding the template by basename.
  _hits=$(grep -rwln --include='*.sh' --include='*.md' --include='*.py' \
            --include='*.yml' --include='*.yaml' \
            "$_leaf" $SEARCH_DIRS 2>/dev/null \
            | grep -v "templates/orchestrator-config-default.yml" \
            | head -n 1)
  [ -n "$_hits" ]
}

# --- run enumeration + readership check ---

dead_count=0
total_leaves=0
exempt_generic=0
exempt_consumer=0

# Buffer dead-knob report lines.
DEAD_REPORT="$(mktemp -t check-dead-infra.XXXXXX)"
trap 'rm -f "$DEAD_REPORT"' EXIT

while IFS="$(printf '\t')" read -r path leaf lineno consumer_flag; do
  [ -z "$path" ] && continue
  total_leaves=$((total_leaves + 1))

  # generic-leaf skip
  case "$GENERIC_LEAF_SKIPLIST" in
    *" $leaf "*)
      exempt_generic=$((exempt_generic + 1))
      [ "$VERBOSE" = "1" ] && echo "  - ${path} (line ${lineno}): SKIP generic leaf '${leaf}'"
      continue
      ;;
  esac

  # consumer-annotation exemption
  if [ "$consumer_flag" = "1" ]; then
    exempt_consumer=$((exempt_consumer + 1))
    [ "$VERBOSE" = "1" ] && echo "  ~ ${path} (line ${lineno}): consumer-annotated"
    continue
  fi

  if has_reader "$leaf"; then
    [ "$VERBOSE" = "1" ] && echo "  + ${path} (line ${lineno}): reader found for '${leaf}'"
  else
    dead_count=$((dead_count + 1))
    echo "  - ${path} (line ${lineno}): no reader for '${leaf}' and no \`# consumer:\` annotation" >> "$DEAD_REPORT"
  fi
done <<EOF
$(enumerate_leaves)
EOF

if [ "$VERBOSE" = "1" ]; then
  echo ""
  echo "Scanned ${total_leaves} leaf knob(s); ${exempt_generic} generic-skip, ${exempt_consumer} consumer-annotated."
fi

if [ "$dead_count" -eq 0 ]; then
  echo "OK: 0 dead knob(s) in $(basename "$TEMPLATE") (${total_leaves} leaves scanned)"
  exit 0
fi

echo "FAIL: ${dead_count} dead knob(s) in $(basename "$TEMPLATE"):" >&2
cat "$DEAD_REPORT" >&2
echo "" >&2
echo "Fix: either reference the knob's leaf-key name from scripts/, commands/," >&2
echo "or references/, or add a \`# consumer: <code> -- <why>\` comment on the" >&2
echo "line immediately above the knob to record explicit attribution." >&2
exit 1
