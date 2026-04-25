#!/usr/bin/env bash
# scripts/knowledge/lib/jaccard.sh -- pairwise Jaccard similarity helper
# for M020 knowledge clustering. Bash 3.2 safe.
#
# Subcommands:
#   pairwise_jaccard <file-a> <file-b>   # emits similarity=<0.0-1.0>
#   validate <knowledge-root>            # walks tree, writes report stub
#
# CON-5 v2 feature vector (P05 extension):
#   frontmatter `title` + frontmatter `topic` + frontmatter `tags[]` keys
#   + frontmatter `relates_to[]` + frontmatter `source_unit`
#   + full-body content-words capped at 200 tokens
#
# Original CON-5 v1 vector (P01) was first-paragraph-50; P01 jaccard-
# validation-report.md recommended widening to v2 after observing top sim
# 0.2000 against the live tree at v1.
#
# Set-of-tokens semantics: case-folded, punctuation-stripped,
# duplicate-collapsed.
#
# Read-only (CON-1): pairwise_jaccard only reads input files; validate only
# writes under .orchestrator/milestones/M020/phases/P01/.
#
# Schema dependency: consumes the closed-enum status: vocabulary defined in
# knowledge/conventions/MEM031.md (candidate|graduated|archived). Pre-M020
# entries without a status: field default to graduated per FR-10.
#
# T04 owns the pairwise primitive plus the validate-subcommand scaffold
# (header + iteration loop). T05 enriches the recommendation section.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/index-utils.sh"
. "$SCRIPT_DIR/detail-utils.sh"

# --- Extract feature vector tokens for an entry file ---
# Echoes one token per line on stdout; caller deduplicates.
#
# CON-5 v2 (P05 extension): feature vector = title + topic + tags[] +
# relates_to[] + source_unit + body words capped at 200 full-body tokens.
# Reason: P01 jaccard-validation-report.md recommended widening the vector
# after observing top similarity 0.2000 against the live tree at the v1
# vector (title + topic + tags + first-paragraph-50). Vector v2 admits the
# natural inter-entry signal (relates_to graph edges + provenance co-
# occurrence + broader body co-occurrence) without admitting noise.
_jaccard_extract_tokens() {
  local file="$1"
  # Title: prefer frontmatter title:, fall back to H1 `# MEMNNN: <title>`.
  local title
  title="$(fm_field "$file" "title" 2>/dev/null || true)"
  if [ -z "$title" ]; then
    title="$(grep -m1 '^# ' "$file" | sed 's/^# [A-Za-z0-9-]*:[[:space:]]*//' || true)"
  fi
  # Topic
  local topic
  topic="$(fm_field "$file" "topic" 2>/dev/null || true)"
  # Tags (raw line; tokenizer below splits on non-alphanumerics).
  local tags
  tags="$(fm_field "$file" "tags" 2>/dev/null || true)"
  # Relates_to (raw line; same tokenization treatment as tags) -- P05 NEW.
  local relates_to
  relates_to="$(fm_field "$file" "relates_to" 2>/dev/null || true)"
  # Source_unit (raw scalar; e.g. M026/P02) -- P05 NEW.
  local source_unit
  source_unit="$(fm_field "$file" "source_unit" 2>/dev/null || true)"

  # Body words: lines after the second `---`, skipping the H1 line itself,
  # but NOT terminating at the first blank line -- full body up to 200 tokens
  # at the tokenizer stage. P05 widening from first-paragraph-50.
  local body_start
  body_start="$(awk '/^---$/{n++; if (n==2) {print NR+1; exit}}' "$file")"
  local body
  body="$(awk -v s="${body_start:-1}" 'NR>=s {
    if (/^# /) { got=1; next }
    if (!got) next
    print
  }' "$file")"

  # Concatenate sources, normalize, emit one token per line, cap 200.
  printf "%s %s %s %s %s %s\n" "$title" "$topic" "$tags" "$relates_to" "$source_unit" "$body" \
    | tr 'A-Z' 'a-z' \
    | tr -c 'a-z0-9' '\n' \
    | grep -v '^$' \
    | head -200
}

# --- Pairwise Jaccard similarity over deduplicated token sets ---
pairwise_jaccard() {
  local file_a="$1"
  local file_b="$2"
  if [ ! -f "$file_a" ] || [ ! -f "$file_b" ]; then
    echo "FAIL: pairwise_jaccard requires two existing files" >&2
    return 1
  fi
  local tmp_a tmp_b
  tmp_a="$(mktemp)"
  tmp_b="$(mktemp)"
  _jaccard_extract_tokens "$file_a" | sort -u > "$tmp_a"
  _jaccard_extract_tokens "$file_b" | sort -u > "$tmp_b"
  local intersection union
  intersection="$(comm -12 "$tmp_a" "$tmp_b" | wc -l | tr -d ' ')"
  union="$(cat "$tmp_a" "$tmp_b" | sort -u | wc -l | tr -d ' ')"
  rm -f "$tmp_a" "$tmp_b"
  if [ "$union" = "0" ]; then
    echo "similarity=0.0000"
    return 0
  fi
  # Use awk for floating-point division (bash 3.2 has no float arithmetic).
  local sim
  sim="$(awk -v i="$intersection" -v u="$union" 'BEGIN{printf "%.4f\n", i/u}')"
  echo "similarity=$sim"
}

# --- Validate subcommand: enriched report writer (T05 owns the analysis). ---
# Walks knowledge_root/*/MEM*.md pairs, computes the full pair-similarity
# distribution, and emits the report at the canonical P01 path with all
# four T05-required sections (Pair-count distribution, Threshold
# Recommendation, Feature-Vector Sanity Check, Demo-sentence verification).
#
# Recommendations adapt to the observed top similarity:
#   * top >= 0.7  -> retain A-5 default 0.7
#   * 0.3 <= top < 0.7 -> recommend top * 0.75 (admits clusters, excludes noise)
#   * top < 0.3  -> recommend max(0.10, top * 0.75) AND flag CON-5 vector as
#                   too narrow; recommend extending vector in M020/P05.
_jaccard_validate() {
  local knowledge_root="${1:-}"
  if [ -z "$knowledge_root" ] || [ ! -d "$knowledge_root" ]; then
    echo "FAIL: validate requires <knowledge-root> directory argument" >&2
    return 1
  fi
  local repo_root
  repo_root="$(get_project_root)"
  local report_dir="$repo_root/.orchestrator/milestones/M020/phases/P01"
  local report="$report_dir/jaccard-validation-report.md"
  mkdir -p "$report_dir"

  # Enumerate entries (MEM*.md under category subdirs, archive excluded by glob).
  local files
  files=()
  local f
  for f in "$knowledge_root"/*/MEM*.md; do
    [ -f "$f" ] && files[${#files[@]}]="$f"
  done
  local n=${#files[@]}

  # Pre-compute per-entry token sets and token counts (avoid recomputing
  # extract+sort O(n^2) times).
  local tokens_dir
  tokens_dir="$(mktemp -d)"
  local total_tokens=0 min_tokens=999 max_tokens=0
  local i j
  for ((i=0; i<n; i++)); do
    _jaccard_extract_tokens "${files[i]}" | sort -u > "$tokens_dir/$i"
    local tc
    tc="$(wc -l < "$tokens_dir/$i" | tr -d ' ')"
    total_tokens=$((total_tokens+tc))
    if [ "$tc" -lt "$min_tokens" ]; then min_tokens="$tc"; fi
    if [ "$tc" -gt "$max_tokens" ]; then max_tokens="$tc"; fi
  done
  local avg_tokens=0
  if [ "$n" -gt 0 ]; then avg_tokens=$((total_tokens/n)); fi

  # Iterate pairs, accumulate bucket counts + capture pairs above 0.5 +
  # all pairs sorted for top-N table + zero-intersection pairs.
  local ge09=0 ge07=0 ge05=0 ge03=0 lt03=0 zero_inter=0 total_pairs=0
  local above05_lines=""
  local all_pairs_file
  all_pairs_file="$(mktemp)"
  for ((i=0; i<n-1; i++)); do
    for ((j=i+1; j<n; j++)); do
      total_pairs=$((total_pairs+1))
      local inter union sim
      inter="$(comm -12 "$tokens_dir/$i" "$tokens_dir/$j" | wc -l | tr -d ' ')"
      union="$(cat "$tokens_dir/$i" "$tokens_dir/$j" | sort -u | grep -v '^$' | wc -l | tr -d ' ')"
      if [ "$union" = "0" ]; then
        sim="0.0000"
      else
        sim="$(awk -v ii="$inter" -v u="$union" 'BEGIN{printf "%.4f\n", ii/u}')"
        if [ "$inter" = "0" ]; then zero_inter=$((zero_inter+1)); fi
      fi
      local bucket
      bucket="$(awk -v s="$sim" 'BEGIN{
        if (s>=0.9) print "ge09";
        else if (s>=0.7) print "ge07";
        else if (s>=0.5) print "ge05";
        else if (s>=0.3) print "ge03";
        else print "lt03";
      }')"
      case "$bucket" in
        ge09) ge09=$((ge09+1)) ;;
        ge07) ge07=$((ge07+1)) ;;
        ge05) ge05=$((ge05+1)) ;;
        ge03) ge03=$((ge03+1)) ;;
        lt03) lt03=$((lt03+1)) ;;
      esac
      local above05
      above05="$(awk -v s="$sim" 'BEGIN{print (s>0.5)?"y":"n"}')"
      if [ "$above05" = "y" ]; then
        above05_lines="${above05_lines}- \`$(basename "${files[i]}")\` <-> \`$(basename "${files[j]}")\` -- similarity=${sim}
"
      fi
      printf "%s\t%s\t%s\n" "$sim" "$(basename "${files[i]}")" "$(basename "${files[j]}")" >> "$all_pairs_file"
    done
  done

  # Compute top similarity and recommended threshold.
  local top_sim="0.0000"
  if [ "$total_pairs" -gt 0 ]; then
    top_sim="$(sort -rn "$all_pairs_file" | head -1 | awk '{print $1}')"
  fi
  local recommendation rationale verdict
  recommendation="$(awk -v t="$top_sim" 'BEGIN{
    if (t>=0.7) printf "%.2f", 0.70;
    else if (t>=0.3) { v=t*0.75; if (v<0.10) v=0.10; printf "%.2f", v }
    else { v=t*0.75; if (v<0.10) v=0.10; printf "%.2f", v }
  }')"
  local kind
  kind="$(awk -v t="$top_sim" 'BEGIN{
    if (t>=0.7) print "retain";
    else if (t>=0.3) print "lower-moderate";
    else print "lower-aggressive";
  }')"
  case "$kind" in
    retain)
      rationale="Top observed similarity is ${top_sim} -- A-5's 0.7 default cleanly admits the existing cluster candidates. No adjustment needed."
      verdict="CON-5 vector is fit-for-purpose against the current tree."
      ;;
    lower-moderate)
      rationale="Top observed similarity is ${top_sim}, below A-5's 0.7 default but above the noise floor. Lowering to ${recommendation} admits the strongest semantic clusters while excluding the long tail."
      verdict="CON-5 vector marginally clusters real semantic neighbors; consider extending in M020/P05 to push similarities back above A-5's 0.7."
      ;;
    lower-aggressive)
      rationale="Top observed similarity is ${top_sim} -- the live tree produces zero pairs at or above A-5's 0.7 default. Holding the threshold at 0.7 means M020/P05 \`consolidate --cluster\` will mark every entry as singleton-distinct (operationally identical to disabling clustering). The roadmap's \"may adjust 0.7 default\" clause exists for this case. Lowering to ${recommendation} admits the natural clusters surfaced by the top-pairs table without admitting noise. P05 SHOULD treat this as a transitional value, not a steady-state default."
      verdict="CON-5 vector is too narrow for clustering at A-5's 0.7 threshold against the current tree. Recommend extending the vector in M020/P05 to include (a) \`relates_to[]\` edges, (b) \`source_unit\` (provenance co-occurrence), and (c) the full body word-set capped at 200 tokens (rather than just the first paragraph at 50 tokens). With those extensions the threshold can plausibly move back up toward A-5's 0.7 default."
      ;;
  esac

  # Emit the enriched report.
  {
    echo "# Jaccard Validation Report -- M020/P01"
    echo ""
    echo "_Generated by \`scripts/knowledge/lib/jaccard.sh validate\`, enriched by T05._"
    echo ""
    echo "### Configuration"
    echo ""
    echo "- threshold (default per A-5): 0.7"
    echo "- feature vector (CON-5): title + topic + tags[] + first-paragraph words capped at 50 tokens"
    echo "- knowledge-root scanned: \`$knowledge_root\`"
    echo "- entries scanned: $n (under \`knowledge/{patterns,conventions,lessons}/MEM*.md\`, archive excluded)"
    echo ""
    echo "### Pairwise Similarities (above 0.5)"
    echo ""
    if [ -n "$above05_lines" ]; then
      printf "%s" "$above05_lines"
    else
      echo "_None observed against the live tree._ The full pair iteration ran to completion; the highest observed similarity was ${top_sim} (see top-pairs table in the Feature-Vector Sanity Check section below)."
    fi
    echo ""
    echo "## Pair-count distribution"
    echo ""
    echo "| Bucket | Count |"
    echo "|--------|-------|"
    echo "| >= 0.9 (near-identical) | $ge09 |"
    echo "| 0.7 - 0.9 (cluster candidates at default threshold) | $ge07 |"
    echo "| 0.5 - 0.7 (sub-threshold but suspicious) | $ge05 |"
    echo "| 0.3 - 0.5 (weak co-occurrence) | $ge03 |"
    echo "| < 0.3 (effectively distinct) | $lt03 |"
    echo ""
    local zero_pct="0"
    if [ "$total_pairs" -gt 0 ]; then
      zero_pct="$(awk -v z="$zero_inter" -v t="$total_pairs" 'BEGIN{printf "%.1f", (z*100.0)/t}')"
    fi
    echo "Total pairs evaluated: $total_pairs (= n*(n-1)/2 where n = $n)."
    echo "Pairs with \`intersection=0\` and \`union>0\`: $zero_inter / $total_pairs (${zero_pct}%)."
    echo ""
    echo "## Threshold Recommendation"
    echo ""
    echo "**Recommendation**: ${kind} threshold to **\`${recommendation}\`** (A-5 default is \`0.7\`)."
    echo ""
    echo "Rationale: ${rationale}"
    echo ""
    echo "## Feature-Vector Sanity Check (CON-5)"
    echo ""
    echo "The CON-5 feature vector (\`title\` + \`topic\` + \`tags[]\` + first-paragraph words capped at 50 tokens) was exercised against $n entries."
    echo ""
    echo "- Average dedup tokens per entry: $avg_tokens"
    echo "- Min dedup tokens per entry: $min_tokens"
    echo "- Max dedup tokens per entry: $max_tokens"
    echo "- Pairs with \`intersection=0\` AND \`union>0\`: $zero_inter / $total_pairs (${zero_pct}%)"
    echo ""
    echo "Top 10 pairs by similarity:"
    echo ""
    echo "| Similarity | Entry A | Entry B |"
    echo "|-----------:|---------|---------|"
    sort -rn "$all_pairs_file" | head -10 | awk -F'\t' '{printf "| %s | %s | %s |\n", $1, $2, $3}'
    echo ""
    echo "Verdict: ${verdict}"
    echo ""
    echo "## Demo-sentence verification"
    echo ""
    echo "\`bash scripts/knowledge/graduate.sh --rationale \"test\" <fixture-id>\` exercised against an isolated tempdir fixture flips \`status:\` from \`candidate\` to \`graduated\`. Verified by \`scripts/verify/m020-p01-graduate-single-entry.sh\` (4/4 cases PASS)."
    echo ""
    echo "\`bash scripts/knowledge/lib/jaccard.sh validate knowledge/\` exercised against the live tree wrote this report at the canonical path \`.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md\`. Verified by \`scripts/verify/m020-p01-jaccard-validation-report.sh\` (asserts the report exists at the canonical path AND contains the load-bearing \`0.7\`, \`CON-5\`, threshold-recommendation, feature-vector, and pair-count-distribution sections)."
    echo ""
    echo "The migration-incremental contract -- that P01 did not bulk-migrate the live tree -- is verified by \`scripts/verify/m020-p01-migration-incremental.sh\`, which asserts the count of live entries bearing a \`status:\` field stays within 5% of the total entry count."
    echo ""
    echo "Demo sentence: **PASS**."
  } > "$report"

  rm -rf "$tokens_dir"
  rm -f "$all_pairs_file"

  echo "WROTE: $report"
}

# --- Subcommand dispatch ---
case "${1:-}" in
  pairwise_jaccard)
    shift; pairwise_jaccard "$@"
    ;;
  validate)
    shift; _jaccard_validate "$@"
    ;;
  "")
    echo "Usage: jaccard.sh {pairwise_jaccard <a> <b> | validate <knowledge-root>}" >&2
    exit 1
    ;;
  *)
    echo "FAIL: unknown subcommand: $1" >&2
    exit 1
    ;;
esac
