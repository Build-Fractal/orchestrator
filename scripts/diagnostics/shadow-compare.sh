#!/usr/bin/env bash
# scripts/diagnostics/shadow-compare.sh — M030/P02/T03
#
# Adaptive-model-selection shadow-mode aggregator (FR-8 + D-A1 + D-A3).
#
# Reads a JSONL corpus of dispatch_usage records (produced by
# scripts/dispatch/dispatch-interface.sh under M030_SHADOW_MODE=1 +
# CLAUDECODE=1). Tabulates per-class evidence (count) + classifier-
# confidence stability (rolling variance N=20 records; see references/model-routing.md
# ## Classifier-Confidence Stability Metric)
# and emits a single closed-enum flip_recommendation= verdict line:
#
#   ready                — all 3 classes meet count + variance thresholds.
#   partially_ready      — >=2 classes stable AND under-threshold class's
#                          routing-table default is `smart` (D-A3 safety).
#   block                — corpus has records but verdict logic failed.
#   evidence_insufficient — total corpus count == 0 (FR-8 floor).
#
# Inputs:
#   --corpus <path>   read JSONL records from <path> instead of default glob.
#   (default)         glob .orchestrator/milestones/M*/execution-log.jsonl
#                     and concatenate into a single stream.
#
# Output (stdout):
#   class=mechanical count=<N> variance=<F> stable=<true|false>
#   class=standard count=<N> variance=<F> stable=<true|false>
#   class=novel count=<N> variance=<F> stable=<true|false>
#   flip_recommendation=<ready|partially_ready|block|evidence_insufficient>
#   [ if partially_ready: ]
#   withheld_classes=<comma-separated>
#
# Bash 3.2 compatible. AD-19 carve-out: this script is a dispatch-
# diagnostic SSOT (MEM004 emitter-internal pattern); awk/pipes/$()
# permitted in its body. The verifiers that GATE it follow strict
# AD-19 (single-script-file shape, no inline compound chains).
#
# CON-3 (symbolic-tier closure): class -> tier mapping is read from
# templates/model-routing.yml routing: section via awk section-walker
# (P01 pattern). Tier names {fast, balanced, smart} appear as constants
# in routing logic but no concrete model IDs are embedded.

set -u

# Stability thresholds — sourced from references/model-routing.md
# (## Classifier-Confidence Stability Metric section). Edit there
# (not here) to adjust the calibration gate.
VARIANCE_MAX=0.10        # references/model-routing.md (variance threshold)
ROLLING_WINDOW=20         # references/model-routing.md (N=20 rolling window)
CLASS_COVERAGE_MIN=50     # references/model-routing.md (per-class coverage minimum)

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ROUTING_TABLE="$REPO_ROOT/templates/model-routing.yml"

CORPUS_PATH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --corpus)
      shift
      CORPUS_PATH="${1:-}"
      ;;
    *)
      printf 'shadow-compare.sh: unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift || true
done

# ---------- Stage corpus into a tmp-file for processing ----------
TMP_CORPUS="/tmp/shadow-compare-corpus-$$.jsonl"
trap 'rm -f "$TMP_CORPUS" 2>/dev/null' EXIT

if [ -n "$CORPUS_PATH" ]; then
  if [ ! -f "$CORPUS_PATH" ]; then
    printf 'shadow-compare.sh: corpus path not found: %s\n' "$CORPUS_PATH" >&2
    exit 2
  fi
  cat "$CORPUS_PATH" > "$TMP_CORPUS"
else
  : > "$TMP_CORPUS"
  # Default glob: every milestone's execution-log.jsonl, if present.
  # Use find (not shell glob) to tolerate missing dirs / no matches.
  found_any=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    cat "$f" >> "$TMP_CORPUS"
    found_any=1
  done < <(find "$REPO_ROOT/.orchestrator/milestones" -maxdepth 2 -name 'execution-log.jsonl' -type f 2>/dev/null)
  # found_any unused — empty TMP_CORPUS naturally drives evidence_insufficient.
fi

# ---------- Build inverse routing map: tier -> class ----------
# Symbolic-tier closure (CON-3): read templates/model-routing.yml routing:
# section via awk section-walker. Output lines: "<class> <tier>".
ROUTING_MAP="$(awk '
  BEGIN { in_routing = 0; class_name = "" }
  /^routing:/                       { in_routing = 1; next }
  /^resolution:/                    { exit }
  in_routing && /^  [a-z_]+:$/      {
    name = $1; gsub(/:$/, "", name)
    class_name = name
    next
  }
  in_routing && class_name != "" && /^    claude-code:/ {
    val = $2; gsub(/[",]/, "", val)
    print class_name, val
  }
' "$ROUTING_TABLE")"

# Lookup helpers (no associative arrays — Bash 3.2 safe).
class_for_tier() {
  # echo class for given tier; empty if no match.
  printf '%s\n' "$ROUTING_MAP" | awk -v t="$1" '$2 == t { print $1; exit }'
}

tier_for_class() {
  printf '%s\n' "$ROUTING_MAP" | awk -v c="$1" '$1 == c { print $2; exit }'
}

# ---------- Aggregate per-class count + rolling-window variance ----------
# Read TMP_CORPUS; for each class, list its records' classifier_confidence
# values in chronological order (records already in append order). Take
# the last N=20 entries; map {high=1.0, medium=0.5, low=0.0}; compute
# variance via awk.
#
# Implementation: awk single-pass over TMP_CORPUS, keying by class
# (resolved via reverse-routing of model_routed). Emit per-class CSV
# of confidence values.

# Stage routing map to a tmp file so awk can read it (avoids macOS awk
# limitation with multi-line -v values).
TMP_RMAP="/tmp/shadow-compare-rmap-$$.txt"
trap 'rm -f "$TMP_CORPUS" "$TMP_RMAP" 2>/dev/null' EXIT
printf '%s\n' "$ROUTING_MAP" > "$TMP_RMAP"

PER_CLASS_DATA="$(awk -v rmap_file="$TMP_RMAP" '
  BEGIN {
    while ((getline line < rmap_file) > 0) {
      if (line == "") continue
      split(line, parts, " ")
      tier_to_class[parts[2]] = parts[1]
    }
    close(rmap_file)
  }
  {
    # Extract model_routed value from the JSON line via regex.
    line = $0
    if (match(line, /"model_routed":"[^"]*"/)) {
      mr = substr(line, RSTART, RLENGTH)
      gsub(/"model_routed":"/, "", mr)
      gsub(/"$/, "", mr)
    } else {
      mr = ""
    }
    if (mr == "" || !(mr in tier_to_class)) {
      next
    }
    class_name = tier_to_class[mr]

    # Extract classifier_confidence value.
    if (match(line, /"classifier_confidence":"[^"]*"/)) {
      cc = substr(line, RSTART, RLENGTH)
      gsub(/"classifier_confidence":"/, "", cc)
      gsub(/"$/, "", cc)
    } else {
      cc = ""
    }

    # Accumulate per-class arrays of confidence values (preserve order).
    cnt[class_name]++
    confs[class_name, cnt[class_name]] = cc
  }
  END {
    classes[1] = "mechanical"
    classes[2] = "standard"
    classes[3] = "novel"
    for (i = 1; i <= 3; i++) {
      c = classes[i]
      total = (c in cnt) ? cnt[c] : 0
      # Take last 20 (window) for variance computation — references/model-routing.md.
      window = 20  # references/model-routing.md (rolling window N=20)
      start = (total > window) ? (total - window + 1) : 1
      n = 0; sum = 0
      for (j = start; j <= total; j++) {
        v = confs[c, j]
        if (v == "high")        score = 1.0
        else if (v == "medium") score = 0.5
        else if (v == "low")    score = 0.0
        else                    continue
        n++
        vals[n] = score
        sum += score
      }
      if (n == 0) {
        var = 0.0
      } else {
        mean = sum / n
        sq = 0
        for (j = 1; j <= n; j++) {
          d = vals[j] - mean
          sq += d * d
        }
        var = sq / n
      }
      # Reset vals[] for next class.
      delete vals
      printf "%s|%d|%.6f\n", c, total, var
    }
  }
' "$TMP_CORPUS")"

# ---------- Emit per-class lines + decide verdict ----------
total_count=0
stable_count=0
unstable_classes=""
withheld_classes=""

for class in mechanical standard novel; do
  row="$(printf '%s\n' "$PER_CLASS_DATA" | awk -F'|' -v c="$class" '$1 == c { print; exit }')"
  if [ -z "$row" ]; then
    # Should not happen — awk END always emits all 3 classes.
    count=0
    variance="0.000000"
  else
    count="$(printf '%s\n' "$row" | awk -F'|' '{ print $2 }')"
    variance="$(printf '%s\n' "$row" | awk -F'|' '{ print $3 }')"
  fi
  total_count=$((total_count + 10#$count))

  # Stable iff count >= 50 (class coverage min, references/model-routing.md)
  # AND variance < 0.10 (references/model-routing.md).
  stable="false"
  is_stable="$(awk -v ct="$count" -v vr="$variance" -v cmin="$CLASS_COVERAGE_MIN" -v vmax="$VARIANCE_MAX" '
    BEGIN { if (ct + 0 >= cmin + 0 && vr + 0 < vmax + 0) print "true"; else print "false" }
  ')"
  if [ "$is_stable" = "true" ]; then
    stable="true"
    stable_count=$((stable_count + 1))
  else
    if [ -z "$unstable_classes" ]; then
      unstable_classes="$class"
    else
      unstable_classes="${unstable_classes},${class}"
    fi
  fi

  printf 'class=%s count=%d variance=%s stable=%s\n' "$class" "$count" "$variance" "$stable"
done

# ---------- Verdict logic (D-A1 + D-A3) ----------
if [ "$total_count" -eq 0 ]; then
  printf 'flip_recommendation=evidence_insufficient\n'
  exit 0
fi

if [ "$stable_count" -eq 3 ]; then
  printf 'flip_recommendation=ready\n'
  exit 0
fi

if [ "$stable_count" -ge 2 ]; then
  # D-A3 safety: every under-threshold class's routing-table default
  # MUST be `smart` (the conservative tier). If so -> partially_ready.
  safety_ok=1
  IFS=',' read -r u1 u2 u3 <<EOF
$unstable_classes
EOF
  for u in "$u1" "$u2" "$u3"; do
    [ -z "$u" ] && continue
    default_tier="$(tier_for_class "$u")"
    if [ "$default_tier" != "smart" ]; then
      safety_ok=0
      break
    fi
  done
  if [ "$safety_ok" -eq 1 ]; then
    printf 'flip_recommendation=partially_ready\n'
    printf 'withheld_classes=%s\n' "$unstable_classes"
    exit 0
  fi
fi

printf 'flip_recommendation=block\n'
exit 0
