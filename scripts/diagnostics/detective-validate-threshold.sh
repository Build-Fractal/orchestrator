#!/usr/bin/env bash
# scripts/diagnostics/detective-validate-threshold.sh
# #Q-1 / conversus RISK-06 corpus validation for the detective match threshold.
#
# Retrieves the issue corpus from the target repo and computes the
# false-positive rate of the keyword-overlap heuristic across distinct issue
# pairs (treating any two distinct issues as semantically unrelated — a
# conservative over-estimate of false positives). Reports a verdict against
# the spec's targets:
#   PASS      false-positive rate < 20%   — threshold is safe for --yes automation
#   WARN      20% <= rate <= 40%          — usable interactively; caution on --yes
#   ESCALATE  rate > 40%                  — switch detection mechanism (spec #Q-1)
#
# When the corpus is smaller than --min-corpus, emits "insufficient corpus"
# and exits 0 — the threshold stays unvalidated and the spec's --yes automation
# caution remains in force.
#
# Usage: detective-validate-threshold.sh [--repo owner/name] [--threshold N]
#                                        [--limit N] [--min-corpus N]
# Mock:  set GH_MOCK_DIR to read $GH_MOCK_DIR/issue-list-response.json offline.
# Exit:  0 always (advisory analysis tool). Requires jq for the computation;
#        without jq, emits a notice and exits 0.
# Bash 3.2 compatible (CON-3). No writes to .orchestrator/ (CON-2).
set -uo pipefail

repo=""
threshold=""
limit="20"
min_corpus="5"

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)        repo="$2"; shift 2 ;;
    --threshold)   threshold="$2"; shift 2 ;;
    --limit)       limit="$2"; shift 2 ;;
    --min-corpus)  min_corpus="$2"; shift 2 ;;
    -h|--help)     sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown argument '$1'" >&2; exit 1 ;;
  esac
done

# Resolve repo + threshold: flag > config (detective.*) > default.
_dvt_read_config="$(cd "$(dirname "$0")" && pwd)/../state/read-config.sh"
if [ -z "$repo" ]; then
  repo="$(bash "$_dvt_read_config" detective.repo 2>/dev/null || echo "null")"
  [ "$repo" = "null" ] || [ -z "$repo" ] && repo="Build-Fractal/orchestrator"
fi
if [ -z "$threshold" ]; then
  threshold="$(bash "$_dvt_read_config" detective.match_threshold 2>/dev/null || echo "null")"
  [ "$threshold" = "null" ] || [ -z "$threshold" ] && threshold="3"
fi

# --- Fetch corpus (mock or live) ---
raw_json=""
if [ -n "${GH_MOCK_DIR:-}" ]; then
  mock_file="$GH_MOCK_DIR/issue-list-response.json"
  [ -f "$mock_file" ] && raw_json="$(cat "$mock_file")" || raw_json="[]"
else
  if ! command -v gh >/dev/null 2>&1; then
    echo "VALIDATE: gh unavailable -- cannot retrieve corpus; threshold $threshold unvalidated" >&2
    echo "VALIDATE: insufficient corpus (n=0 floor=$min_corpus) -- --yes automation caution remains in force"
    exit 0
  fi
  raw_json="$(gh issue list --repo "$repo" --state all --limit "$limit" \
    --json number,title,body 2>/dev/null)" || raw_json="[]"
  [ -z "$raw_json" ] && raw_json="[]"
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "VALIDATE: jq required for corpus computation -- install jq and re-run" >&2
  exit 0
fi

corpus_n="$(echo "$raw_json" | jq 'length' 2>/dev/null || echo 0)"
if [ "$corpus_n" -lt "$min_corpus" ]; then
  echo "VALIDATE: insufficient corpus (n=$corpus_n floor=$min_corpus) -- threshold $threshold unvalidated; --yes automation caution remains in force (spec #Q-1)"
  exit 0
fi

# Pairwise false-positive computation: for each ordered distinct pair (i,j),
# count how many of issue i's keywords (>=3 chars, unique) appear in issue j's
# text. Flag the pair if the count meets the threshold. Distinct issues are
# treated as unrelated, so a flagged pair is a false positive.
result="$(echo "$raw_json" | jq -c --argjson th "$threshold" '
  def lc: ascii_downcase;
  [ .[] | {
      kw: (((.title // "") + " " + (.body // "")) | lc | [scan("[a-z]{3,}")] | unique),
      text: (((.title // "") + " " + (.body // "")) | lc)
    } ] as $issues |
  ($issues | length) as $n |
  [ range($n) as $i | range($n) as $j | select($i != $j) |
    ( [ $issues[$i].kw[] | select(. as $w | $issues[$j].text | contains($w)) ] | length ) as $score |
    if $score >= $th then 1 else 0 end
  ] as $flags |
  { n: $n, pairs: ($flags | length), fp: ($flags | add // 0) }
')"

n="$(echo "$result" | jq '.n')"
pairs="$(echo "$result" | jq '.pairs')"
fp="$(echo "$result" | jq '.fp')"

if [ "$pairs" -eq 0 ]; then
  echo "VALIDATE: insufficient corpus (n=$n floor=$min_corpus) -- no comparable pairs"
  exit 0
fi

# rate as integer percent (floor) + one-decimal via awk for the report
rate_pct="$(awk -v fp="$fp" -v p="$pairs" 'BEGIN { printf "%.1f", (fp / p) * 100 }')"
rate_int="$(awk -v fp="$fp" -v p="$pairs" 'BEGIN { printf "%d", (fp / p) * 100 }')"

verdict="PASS"
if [ "$rate_int" -gt 40 ]; then
  verdict="ESCALATE"
elif [ "$rate_int" -ge 20 ]; then
  verdict="WARN"
fi

echo "VALIDATE: threshold=$threshold corpus=$n pairs=$pairs false_positives=$fp false_positive_rate=${rate_pct}% verdict=$verdict"
if [ "$verdict" = "ESCALATE" ]; then
  echo "VALIDATE: rate exceeds 40% -- switch detection mechanism per spec #Q-1 (e.g. semantic-embedding similarity)" >&2
elif [ "$verdict" = "WARN" ]; then
  echo "VALIDATE: rate in 20-40% band -- usable interactively; keep the --yes automation caution" >&2
else
  echo "VALIDATE: rate below 20% -- threshold $threshold validated for automation at this corpus size" >&2
fi
exit 0
