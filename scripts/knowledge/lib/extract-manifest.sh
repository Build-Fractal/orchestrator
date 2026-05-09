#!/usr/bin/env bash
# scripts/knowledge/lib/extract-manifest.sh -- pure manifest parser.
# Sourced by scripts/knowledge/extract-reference.sh.
# No top-level I/O; functions take args + emit to stdout.
# Bash 3.2 / POSIX-sh per CON-2; no associative arrays, no jq required.

# extract_manifest_top_field <manifest-path> <field-name>
#   Echoes the value of a top-level scalar field (e.g., size_cap_bytes).
#   Empty stdout if absent.
extract_manifest_top_field() {
  local m="$1"
  local f="$2"
  grep -E "^${f}:" "$m" | head -n 1 | sed -E "s/^${f}:[[:space:]]*//" | sed -E 's/[[:space:]]*$//' | sed -E 's/^"//' | sed -E 's/"$//'
}

# extract_manifest_doc_count <manifest-path>
#   Echoes the count of YAML list entries under `documents:`.
extract_manifest_doc_count() {
  local m="$1"
  grep -cE '^[[:space:]]+-[[:space:]]+cite_id:' "$m"
}

# extract_manifest_doc_field <manifest-path> <doc-index-1based> <field-name>
#   Echoes the value of <field-name> within the Nth document record.
#   Implementation: awk that tracks the doc index and prints the requested
#   field within the matching record. Single-script-file invocation shape
#   (this is internal pipeline; classifier inspects only the *invocation*
#   of extract-reference.sh, not its helper bodies).
#
#   Supports three scalar shapes:
#     1. Inline:           field: "value"  /  field: value
#     2. Block literal:    field: |        (newlines preserved verbatim)
#                            line one
#                            line two
#     3. Block folded:     field: >        (consecutive lines folded to
#                            line one         spaces; blank line → newline)
#                            line two
#
#   Block scalars are dedented to the field-key column. Continuation lines
#   are slurped while their leading whitespace exceeds the field-key
#   column; the first line at-or-before that column terminates the block.
#   Blank lines inside a block do NOT terminate it.
#
#   YAML features intentionally NOT supported (deferred until needed):
#     - Chomping indicators (|-, |+, >-, >+)  : tail-newline always clipped
#       implicitly because $(...) strips trailing newlines on the caller side.
#     - Explicit indentation indicators (|2, >4)
#     - Quoted block-scalar contents
#   These are rare in operator-authored manifests; if they appear, callers
#   will see the raw indicator characters and can promote to single-line
#   form.
extract_manifest_doc_field() {
  local m="$1"
  local idx="$2"
  local field="$3"
  awk -v idx="$idx" -v field="$field" '
    function leading_ws(s,    i, c) {
      i = 0
      while (i < length(s)) {
        c = substr(s, i + 1, 1)
        if (c != " " && c != "\t") break
        i++
      }
      return i
    }
    function dedent(s, n,    i, c) {
      i = 0
      while (i < n && i < length(s)) {
        c = substr(s, i + 1, 1)
        if (c != " " && c != "\t") break
        i++
      }
      return substr(s, i + 1)
    }
    BEGIN { current = 0; in_block = 0; buf = ""; style = ""; field_indent = 0; block_indent = -1; prev_blank = 0 }
    {
      # Inside a block scalar, the in_block branch handles every line
      # until the block terminates; do not let the cite_id increment or
      # the field-match rule fire while slurping.
      if (in_block) {
        if ($0 ~ /^[[:space:]]*$/) {
          if (style == "literal") {
            buf = buf "\n"
          } else {
            # folded: blank line → paragraph break (newline). Use
            # prev_blank so we collapse any run of blanks into a single
            # paragraph break on the next non-empty line.
            prev_blank = 1
          }
          next
        }
        ind = leading_ws($0)
        if (ind <= field_indent) {
          # Block terminated by an at-or-shallower-indent non-empty line.
          # Clear in_block before exiting so the END action does not
          # double-print buf — POSIX awk runs END after `exit`.
          print buf
          in_block = 0
          exit
        }
        # YAML rule: block-content indent is determined by the first
        # non-empty line of the block. Subsequent lines dedent by that
        # same column count.
        if (block_indent < 0) block_indent = ind
        content = dedent($0, block_indent)
        if (style == "literal") {
          if (buf == "") buf = content
          else buf = buf "\n" content
        } else {
          if (buf == "") {
            buf = content
          } else if (prev_blank) {
            buf = buf "\n" content
            prev_blank = 0
          } else {
            buf = buf " " content
          }
        }
        next
      }
      if ($0 ~ /^[[:space:]]+-[[:space:]]+cite_id:/) { current++ }
      if (current == idx) {
        if (match($0, "^[[:space:]]+(-[[:space:]]+)?" field ":")) {
          line = $0
          ind = leading_ws(line)
          rest = substr(line, RLENGTH + 1)
          sub("^[[:space:]]*", "", rest)
          sub("[[:space:]]+$", "", rest)
          if (rest == "|" || rest == ">") {
            style = (rest == "|") ? "literal" : "folded"
            field_indent = ind
            block_indent = -1
            in_block = 1
            buf = ""
            prev_blank = 0
            next
          }
          # Inline scalar branch — preserve original shape.
          sub("^[[:space:]]*-?[[:space:]]*" field ":[[:space:]]*", "", line)
          sub("[[:space:]]+$", "", line)
          sub("^\"", "", line); sub("\"$", "", line)
          print line
          exit
        }
      }
    }
    END { if (in_block) print buf }
  ' "$m"
}

# extract_manifest_doc_list_field <manifest-path> <doc-index-1based> <field-name>
#   Echoes a YAML inline-list ("[a, b, c]") reconstructed from either inline
#   (`field: [a, b]`) or block (`field:\n  - a\n  - b`) form within the
#   doc record at index <idx>. Empty / missing list -> "[]". Output is
#   safe to embed directly in printf-emitted frontmatter (inline form is
#   valid YAML and grep-detectable by classify-reference.sh).
#
#   This is the list-aware sibling of extract_manifest_doc_field, which
#   only handles scalar values and would mangle inline-list syntax.
extract_manifest_doc_list_field() {
  local m="$1"
  local idx="$2"
  local field="$3"
  awk -v idx="$idx" -v field="$field" '
    BEGIN { current=0; in_block=0; items=""; printed=0 }
    /^[[:space:]]+-[[:space:]]+cite_id:/ { current++; in_block=0 }
    current==idx {
      # Inline form: field: [a, b, c]
      if (match($0, "^[[:space:]]+(-[[:space:]]+)?" field ":[[:space:]]*\\[")) {
        line=$0
        sub(".*\\[", "", line)
        sub("\\].*", "", line)
        print "[" line "]"
        printed=1
        exit
      }
      # Block-list start: field:  (with nothing else on the line)
      if (match($0, "^[[:space:]]+(-[[:space:]]+)?" field ":[[:space:]]*$")) {
        in_block=1
        next
      }
      # Inside a block list, accumulate items until the next field key.
      if (in_block) {
        if ($0 ~ /^[[:space:]]+-[[:space:]]+/) {
          v=$0
          sub("^[[:space:]]+-[[:space:]]+", "", v)
          sub("[[:space:]]+$","", v)
          items = (items=="" ? v : items ", " v)
        } else if ($0 ~ /^[[:space:]]+[A-Za-z_]+:/) {
          print "[" items "]"
          printed=1
          exit
        }
      }
    }
    END { if (!printed) { if (in_block) print "[" items "]"; else print "[]" } }
  ' "$m"
}

# extract_manifest_resolve_tier <category> <source-types-yaml-path>
#   Echoes the default tier for a category from the source-types SSOT.
extract_manifest_resolve_tier() {
  local cat="$1"
  local yaml="$2"
  awk -v cat="$cat" '
    $0 ~ "^  " cat ":" { found=1; next }
    found && /^    default_tier:/ {
      line=$0
      sub("^[[:space:]]*default_tier:[[:space:]]*", "", line)
      sub("[[:space:]]+$", "", line)
      print line
      exit
    }
  ' "$yaml"
}
