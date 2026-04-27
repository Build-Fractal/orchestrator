#!/usr/bin/env bash
# scripts/diagnostics/m018-section-distribution.sh
#
# M018/P00/T02 — Section-distribution probe with per-tier savings_ceiling estimator.
#
# Read-only. Scans .orchestrator/milestones/*/execution-log.jsonl for
# payload_breakdown records and emits:
#   1. Per-section size distribution (mean, p50, p95, max, n) for the eight
#      canonical sections (Knowledge, Task Plan, Upstream Context,
#      First-Turn Completeness, Scope, Constraints, State Context, Decisions).
#   2. Per-tier achievable-savings ceilings with 80% bootstrap CIs (10th and
#      90th percentile) for the four compression tiers (filter, T1, T2, T3).
#   3. An aggregate-tier savings_ceiling band (low/mean/high) with non-overlap
#      adjustment: filter+T1 don't double-count tool-result tokens; T3 is
#      applied to the budget remaining AFTER T2's snip on overlapping sections.
#
# Output is dual-format:
#   --format text  (default)  human-readable tables
#   --format json             machine-readable, consumed by T03 SC-9 calibrator
#
# Determinism: bootstrap resampling uses an LCG seeded by --seed (default 42),
# so re-runs against identical input produce byte-identical output.
#
# Per-tier modeling assumptions (encoded as named constants below; emitted in
# JSON under model_assumptions so T03's SC-9 amendment can cite them verbatim):
#   filter (FR-3): drops ~30% of Knowledge tokens, Beta(2,5) prior on
#     superseded/experimental fraction.
#   T1     (FR-5): drops ~50% of tool-result tokens, conditioned on
#     ~30% prevalence inside Task Plan + Upstream Context.
#   T2     (FR-6): head-drops ~40% of the EXCESS over the 1500-tok tail
#     threshold on any section that exceeds it (preserves the last 1500 tok
#     verbatim; drops up to 40% of what came before).
#   T3     (FR-7): summarizes ~60% of the EXCESS above the per-section budget
#     (2000 tok) on Knowledge + Task Plan + Upstream Context; Standard+
#     intensity assumed.
#
# Usage:
#   bash scripts/diagnostics/m018-section-distribution.sh [--format text|json]
#                                                          [--bootstrap-iterations N]
#                                                          [--seed S]

set -euo pipefail

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
FORMAT="text"
BOOTSTRAP_ITER=1000
SEED=42

while [ $# -gt 0 ]; do
  case "$1" in
    --format)
      FORMAT="${2:-text}"
      shift 2
      ;;
    --format=*)
      FORMAT="${1#--format=}"
      shift
      ;;
    --bootstrap-iterations)
      BOOTSTRAP_ITER="${2:-1000}"
      shift 2
      ;;
    --bootstrap-iterations=*)
      BOOTSTRAP_ITER="${1#--bootstrap-iterations=}"
      shift
      ;;
    --seed)
      SEED="${2:-42}"
      shift 2
      ;;
    --seed=*)
      SEED="${1#--seed=}"
      shift
      ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

case "$FORMAT" in
  text|json) ;;
  *)
    echo "ERROR: --format must be text or json (got: $FORMAT)" >&2
    exit 2
    ;;
esac

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required" >&2
  exit 2
fi

# -----------------------------------------------------------------------------
# Modeling constants (per-tier compression assumptions; reviewable + emitted)
# -----------------------------------------------------------------------------
# Filter: applies to Knowledge section.
FILTER_TARGET_SECTION="Knowledge"
FILTER_MEAN_DROP=0.30              # ~30% mean drop per FR-3
FILTER_BETA_ALPHA=2                # Beta(2, 5) prior — moderate uncertainty
FILTER_BETA_BETA=5

# T1 microcompact: applies to tool-result tokens embedded in Task Plan + Upstream Context.
T1_TARGET_SECTIONS="Task Plan,Upstream Context"
T1_TOOLRESULT_PREVALENCE=0.30      # ~30% of those sections are tool-result tokens
T1_TOOLRESULT_DROP=0.50            # ~50% drop on the tool-result subset

# T2 snip: head-drops on any section above tail-threshold.
T2_HEAD_DROP=0.40                  # ~40% of section dropped (head)
T2_TAIL_THRESHOLD=1500             # only fires on sections > 1500 tok

# T3 auto-compact: applies to Knowledge + Task Plan + Upstream Context, Standard+.
T3_TARGET_SECTIONS="Knowledge,Task Plan,Upstream Context"
T3_SUMMARIZE_RATIO=0.40            # ~40% reduction (i.e. ~60% retention) of
                                   # excess-over-budget; conservative reading
                                   # of "60% summarization" so the aggregate
                                   # ceiling stays operationally defensible.
T3_BUDGET_THRESHOLD=2000           # per-section budget threshold

# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------
ROOT=".orchestrator/milestones"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PB_FILE="$TMP/payload_breakdowns.jsonl"
SECTIONS_TSV="$TMP/sections.tsv"          # one row per (record_idx, section, tokens)
WIDE_TSV="$TMP/sections_wide.tsv"         # one row per record, columns are sections
JSON_OUT="$TMP/output.json"

: > "$PB_FILE"

for log in "$ROOT"/*/execution-log.jsonl; do
  [ -r "$log" ] || continue
  grep -h '"record_type":"payload_breakdown"' "$log" >> "$PB_FILE" || true
done

PB_COUNT=$(wc -l < "$PB_FILE" | tr -d ' ')

if [ "$PB_COUNT" -eq 0 ]; then
  echo "ERROR: no payload_breakdown records found under $ROOT/*/execution-log.jsonl" >&2
  exit 1
fi

# Eight canonical sections, fixed order (used everywhere):
SECTIONS_ORDERED="Knowledge|Task Plan|Upstream Context|First-Turn Completeness|Scope|Constraints|State Context|Decisions"

# -----------------------------------------------------------------------------
# Build wide TSV: one record per row, eight section-token columns (in order).
# -----------------------------------------------------------------------------
jq -r --arg order "$SECTIONS_ORDERED" '
  ($order | split("|")) as $sec
  | .section_tokens as $st
  | [ $sec[] | ($st[.] // 0) ] | @tsv
' "$PB_FILE" > "$WIDE_TSV"

# -----------------------------------------------------------------------------
# Per-section distribution stats via awk on the wide TSV.
# Output columns: section\tn\tmean\tp50\tp95\tmax
# -----------------------------------------------------------------------------
PER_SECTION_TSV="$TMP/per_section.tsv"

awk -v secs="$SECTIONS_ORDERED" '
  BEGIN {
    nsec = split(secs, sname, "|")
    for (i = 1; i <= nsec; i++) ncol[i] = 0
  }
  {
    for (i = 1; i <= nsec; i++) {
      v = $i + 0
      ncol[i]++
      vals[i, ncol[i]] = v
    }
  }
  END {
    for (i = 1; i <= nsec; i++) {
      n = ncol[i]
      # Bubble-free sort: insertion sort over the row (small N, fine for 200ish)
      for (a = 2; a <= n; a++) {
        key = vals[i, a]
        b = a - 1
        while (b >= 1 && vals[i, b] > key) {
          vals[i, b+1] = vals[i, b]
          b--
        }
        vals[i, b+1] = key
      }
      sum = 0
      maxv = 0
      for (a = 1; a <= n; a++) {
        sum += vals[i, a]
        if (vals[i, a] > maxv) maxv = vals[i, a]
      }
      mean = (n > 0) ? sum / n : 0
      p50_idx = int(n * 0.50); if (p50_idx < 1) p50_idx = 1
      p95_idx = int(n * 0.95); if (p95_idx < 1) p95_idx = 1
      p50 = vals[i, p50_idx]
      p95 = vals[i, p95_idx]
      printf "%s\t%d\t%.2f\t%d\t%d\t%d\n", sname[i], n, mean, p50, p95, maxv
    }
  }
' "$WIDE_TSV" > "$PER_SECTION_TSV"

# Compute total mean payload tokens (sum of section means) for pct conversion:
MEAN_TOTAL_PAYLOAD=$(awk -F'\t' '{s += $3} END {printf "%.2f", s}' "$PER_SECTION_TSV")

# -----------------------------------------------------------------------------
# Bootstrap helper: implemented in awk, deterministic via LCG seeded by SEED.
# Reads the wide TSV. For each tier, on each iteration:
#   1. Resample N records with replacement (LCG-driven indices).
#   2. Apply tier model to compute per-iteration tier savings (sum across the
#      resampled population), divided by population size to get a per-record
#      savings figure; aggregate over the population to get total.
#   3. Collect savings_pct = total_savings / total_payload_in_resample.
# Across all iterations: emit low_pct (10th pct), mean_pct, high_pct (90th pct)
# and the corresponding token figures (low_tok, mean_tok, high_tok) computed as
# the resample's mean total payload * pct/100.
# Tier IDs: 1=filter 2=T1 3=T2 4=T3 5=aggregate
# -----------------------------------------------------------------------------
TIER_TSV="$TMP/per_tier.tsv"

awk \
  -v secs="$SECTIONS_ORDERED" \
  -v iter="$BOOTSTRAP_ITER" \
  -v seed="$SEED" \
  -v f_drop="$FILTER_MEAN_DROP" \
  -v f_alpha="$FILTER_BETA_ALPHA" \
  -v f_beta="$FILTER_BETA_BETA" \
  -v t1_targets="$T1_TARGET_SECTIONS" \
  -v t1_prev="$T1_TOOLRESULT_PREVALENCE" \
  -v t1_drop="$T1_TOOLRESULT_DROP" \
  -v t2_drop="$T2_HEAD_DROP" \
  -v t2_thresh="$T2_TAIL_THRESHOLD" \
  -v t3_targets="$T3_TARGET_SECTIONS" \
  -v t3_ratio="$T3_SUMMARIZE_RATIO" \
  -v t3_budget="$T3_BUDGET_THRESHOLD" \
'
  function lcg_next() {
    # 32-bit LCG (Numerical Recipes constants), modulo 2^31 to stay in int range.
    rng_state = (rng_state * 1103515245 + 12345) % 2147483648
    return rng_state
  }
  function rand_unit() {
    return lcg_next() / 2147483648.0
  }
  function rand_index(n) {
    return int(rand_unit() * n) + 1
  }
  function beta_sample(a, b,    s, i, x, y) {
    # Sum-of-uniforms approximation suffices for Beta(2,5) variance; we use
    # the Johnk algorithm with rejection for correctness.
    while (1) {
      x = rand_unit()
      y = rand_unit()
      if (x == 0 || y == 0) continue
      # Power transform: x^(1/a), y^(1/b)
      x = exp(log(x) / a)
      y = exp(log(y) / b)
      if (x + y <= 1.0 && x + y > 0) return x / (x + y)
    }
  }
  function in_csv(target, csv,    n, i, parts) {
    n = split(csv, parts, ",")
    for (i = 1; i <= n; i++) {
      if (parts[i] == target) return 1
    }
    return 0
  }
  BEGIN {
    nsec = split(secs, sname, "|")
    for (i = 1; i <= nsec; i++) idx[sname[i]] = i
    rng_state = seed + 0
    if (rng_state <= 0) rng_state = 42
    nrec = 0
  }
  {
    nrec++
    for (i = 1; i <= nsec; i++) {
      data[nrec, i] = $i + 0
    }
  }
  END {
    if (nrec == 0) {
      print "ERROR: empty wide TSV" > "/dev/stderr"
      exit 1
    }

    # Pre-compute target-section indices for each tier.
    f_idx_knowledge = idx["Knowledge"]
    n_t1_targets = split(t1_targets, t1_arr, ",")
    n_t3_targets = split(t3_targets, t3_arr, ",")

    # Storage for per-iteration percent results (one array per tier 1..5).
    for (it = 1; it <= iter; it++) {
      # Resample indices
      total_payload_iter = 0
      f_save = 0
      t1_save = 0
      t2_save = 0
      t3_save = 0
      agg_save = 0

      for (k = 1; k <= nrec; k++) {
        r = rand_index(nrec)

        # Per-record section view
        for (j = 1; j <= nsec; j++) row[j] = data[r, j]

        # Total payload for this record
        rec_total = 0
        for (j = 1; j <= nsec; j++) rec_total += row[j]
        total_payload_iter += rec_total

        # --- Filter tier (Knowledge ~ Beta(alpha,beta) drop, mean f_drop) ---
        beta_factor = beta_sample(f_alpha, f_beta)
        f_this = row[f_idx_knowledge] * beta_factor
        f_save += f_this

        # --- T1 microcompact: tool-result tokens inside T1 targets ---
        t1_this = 0
        for (m = 1; m <= n_t1_targets; m++) {
          target = t1_arr[m]
          if (target in idx) {
            t1_this += row[idx[target]] * t1_prev * t1_drop
          }
        }
        t1_save += t1_this

        # --- T2 snip: head-drop on EXCESS over tail threshold ---
        # Preserves the last t2_thresh tokens (tail) verbatim; drops up to
        # t2_drop fraction of (section_size - t2_thresh).
        t2_this = 0
        for (j = 1; j <= nsec; j++) {
          if (row[j] > t2_thresh) {
            excess = row[j] - t2_thresh
            t2_this += excess * t2_drop
          }
        }
        t2_save += t2_this

        # --- T3 auto-compact: summarize EXCESS above budget on K+TP+UC ---
        # T3 only fires when section is over budget; summarizes the excess
        # over t3_budget by t3_ratio (so net savings = excess * t3_ratio).
        # When T2 already fired on the section, T3 sees the post-T2 excess.
        t3_this = 0
        for (m = 1; m <= n_t3_targets; m++) {
          target = t3_arr[m]
          if (!(target in idx)) continue
          j = idx[target]
          sec_v = row[j]
          if (sec_v > t3_budget) {
            excess = sec_v - t3_budget
            # If T2 fired on this section, the excess is already partly trimmed.
            if (sec_v > t2_thresh) {
              t2_excess = sec_v - t2_thresh
              t2_taken  = t2_excess * t2_drop
              # Reduce T3-eligible excess by what T2 already removed (capped).
              residual_excess = excess - t2_taken
              if (residual_excess < 0) residual_excess = 0
              t3_this += residual_excess * t3_ratio
            } else {
              t3_this += excess * t3_ratio
            }
          }
        }
        t3_save += t3_this

        # --- Aggregate (non-overlap-adjusted) ---
        # Pipeline ordering (Standard+ intensity assumed):
        #   1. Filter on Knowledge (drops superseded/experimental entries).
        #   2. T1 on tool-result subset of Task Plan + Upstream Context.
        #   3. T3 SUPERSEDES T2 on overlapping K+TP+UC sections (T3 is the
        #      heavier hammer for the same problem; do not stack).
        #      T2 fires only on sections > 1500 that T3 does NOT touch.
        # We track "remaining tokens" per section and accumulate deltas to
        # avoid double-counting any single token.
        for (j = 1; j <= nsec; j++) {
          rem[j] = row[j]
          t3_fired[j] = 0
        }

        # 1. Filter on Knowledge
        kj = f_idx_knowledge
        delta = rem[kj] * beta_factor
        rem[kj] = rem[kj] - delta
        agg_delta = delta

        # 2. T1 on Task Plan + Upstream Context (tool-result subset only)
        for (m = 1; m <= n_t1_targets; m++) {
          target = t1_arr[m]
          if (target in idx) {
            j = idx[target]
            delta = rem[j] * t1_prev * t1_drop
            rem[j] = rem[j] - delta
            agg_delta += delta
          }
        }

        # 3. T3 on K+TP+UC: 40% reduction of EXCESS over t3_budget on the
        #    remainder after filter+T1. Mark sections as T3-fired so T2 skips.
        for (m = 1; m <= n_t3_targets; m++) {
          target = t3_arr[m]
          if (!(target in idx)) continue
          j = idx[target]
          if (rem[j] > t3_budget) {
            excess = rem[j] - t3_budget
            delta = excess * t3_ratio
            if (delta > rem[j]) delta = rem[j]
            rem[j] = rem[j] - delta
            agg_delta += delta
            t3_fired[j] = 1
          }
        }

        # 4. T2 on remaining sections > t2_thresh that T3 did NOT fire on.
        #    Drops 40% of the section (whole-section ratio per FR-7 reading).
        for (j = 1; j <= nsec; j++) {
          if (t3_fired[j]) continue
          if (row[j] > t2_thresh && rem[j] > 0) {
            delta = rem[j] * t2_drop
            if (delta > rem[j]) delta = rem[j]
            rem[j] = rem[j] - delta
            agg_delta += delta
          }
        }

        agg_save += agg_delta
      }

      # Per-iteration savings as pct of the resample total payload.
      if (total_payload_iter > 0) {
        pct1 = 100.0 * f_save  / total_payload_iter
        pct2 = 100.0 * t1_save / total_payload_iter
        pct3 = 100.0 * t2_save / total_payload_iter
        pct4 = 100.0 * t3_save / total_payload_iter
        pct5 = 100.0 * agg_save / total_payload_iter
      } else {
        pct1 = 0; pct2 = 0; pct3 = 0; pct4 = 0; pct5 = 0
      }

      r1[it] = pct1
      r2[it] = pct2
      r3[it] = pct3
      r4[it] = pct4
      r5[it] = pct5

      tot[it] = total_payload_iter / nrec   # mean payload per record this iter
    }

    # Sort each tier vector and emit low(p10) / mean / high(p90).
    nt = iter
    p10_idx = int(nt * 0.10); if (p10_idx < 1) p10_idx = 1
    p90_idx = int(nt * 0.90); if (p90_idx < 1) p90_idx = 1

    emit("filter",    r1, nt, p10_idx, p90_idx, tot)
    emit("tier1",     r2, nt, p10_idx, p90_idx, tot)
    emit("tier2",     r3, nt, p10_idx, p90_idx, tot)
    emit("tier3",     r4, nt, p10_idx, p90_idx, tot)
    emit("aggregate", r5, nt, p10_idx, p90_idx, tot)
  }
  function emit(label, vec, n, p10i, p90i, totvec,    a, b, key, sum, mean_pct, low_pct, high_pct, mean_tot) {
    # Insertion sort vec[]
    for (a = 2; a <= n; a++) {
      key = vec[a]
      b = a - 1
      while (b >= 1 && vec[b] > key) {
        vec[b+1] = vec[b]
        b--
      }
      vec[b+1] = key
    }
    sum = 0
    for (a = 1; a <= n; a++) sum += vec[a]
    mean_pct = (n > 0) ? sum / n : 0
    low_pct  = vec[p10i]
    high_pct = vec[p90i]

    # Mean total payload across iterations (for token conversion)
    sum = 0
    for (a = 1; a <= n; a++) sum += totvec[a]
    mean_tot = (n > 0) ? sum / n : 0

    low_tok  = mean_tot * low_pct  / 100.0
    mean_tok = mean_tot * mean_pct / 100.0
    high_tok = mean_tot * high_pct / 100.0

    printf "%s\t%.4f\t%.4f\t%.4f\t%.2f\t%.2f\t%.2f\n", \
      label, low_pct, mean_pct, high_pct, low_tok, mean_tok, high_tok
  }
' "$WIDE_TSV" > "$TIER_TSV"

# -----------------------------------------------------------------------------
# JSON assembly via jq.
# -----------------------------------------------------------------------------
build_per_section_json() {
  jq -R -s --arg none "" '
    split("\n")
    | map(select(length > 0))
    | map(split("\t"))
    | map({
        section: .[0],
        n: (.[1] | tonumber),
        mean: (.[2] | tonumber),
        p50: (.[3] | tonumber),
        p95: (.[4] | tonumber),
        max: (.[5] | tonumber)
      })
  ' "$PER_SECTION_TSV"
}

build_per_tier_json() {
  jq -R -s '
    split("\n")
    | map(select(length > 0))
    | map(split("\t"))
    | map({
        tier: .[0],
        low_pct: (.[1] | tonumber),
        mean_pct: (.[2] | tonumber),
        high_pct: (.[3] | tonumber),
        low_tokens: (.[4] | tonumber),
        mean_tokens: (.[5] | tonumber),
        high_tokens: (.[6] | tonumber)
      })
  ' "$TIER_TSV"
}

PER_SECTION_JSON=$(build_per_section_json)
ALL_TIERS_JSON=$(build_per_tier_json)

# Split out aggregate from per-tier list:
PER_TIER_JSON=$(printf '%s' "$ALL_TIERS_JSON" | jq '[ .[] | select(.tier != "aggregate") ]')
AGG_JSON=$(printf '%s' "$ALL_TIERS_JSON" | jq '[ .[] | select(.tier == "aggregate") ] | .[0]')

# Per-tier object form (keyed by tier name, for verifier convenience).
PER_TIER_OBJ_JSON=$(printf '%s' "$PER_TIER_JSON" | jq 'map({key: .tier, value: .}) | from_entries')

MODEL_JSON=$(jq -n \
  --arg ftarget "$FILTER_TARGET_SECTION" \
  --arg fdrop "$FILTER_MEAN_DROP" \
  --arg falpha "$FILTER_BETA_ALPHA" \
  --arg fbeta "$FILTER_BETA_BETA" \
  --arg t1tgt "$T1_TARGET_SECTIONS" \
  --arg t1prev "$T1_TOOLRESULT_PREVALENCE" \
  --arg t1drop "$T1_TOOLRESULT_DROP" \
  --arg t2drop "$T2_HEAD_DROP" \
  --arg t2thresh "$T2_TAIL_THRESHOLD" \
  --arg t3tgt "$T3_TARGET_SECTIONS" \
  --arg t3ratio "$T3_SUMMARIZE_RATIO" \
  --arg t3budget "$T3_BUDGET_THRESHOLD" \
  '{
    filter: {
      target_section: $ftarget,
      mean_drop: ($fdrop | tonumber),
      prior: { distribution: "Beta", alpha: ($falpha | tonumber), beta: ($fbeta | tonumber) },
      reference: "FR-3"
    },
    tier1: {
      target_sections: ($t1tgt | split(",")),
      toolresult_prevalence: ($t1prev | tonumber),
      toolresult_drop: ($t1drop | tonumber),
      reference: "FR-5"
    },
    tier2: {
      head_drop: ($t2drop | tonumber),
      tail_threshold_tokens: ($t2thresh | tonumber),
      reference: "FR-6"
    },
    tier3: {
      target_sections: ($t3tgt | split(",")),
      summarize_ratio: ($t3ratio | tonumber),
      budget_threshold_tokens: ($t3budget | tonumber),
      reference: "FR-7",
      intensity_gated: "Standard+"
    }
  }')

jq -n \
  --arg pb "$PB_COUNT" \
  --arg iter "$BOOTSTRAP_ITER" \
  --arg seed "$SEED" \
  --argjson per_section "$PER_SECTION_JSON" \
  --argjson per_tier_list "$PER_TIER_JSON" \
  --argjson per_tier "$PER_TIER_OBJ_JSON" \
  --argjson aggregate "$AGG_JSON" \
  --argjson model "$MODEL_JSON" \
  '{
    schema_version: "1.0",
    type: "m018_section_distribution",
    records_analyzed: ($pb | tonumber),
    bootstrap_iterations: ($iter | tonumber),
    seed: ($seed | tonumber),
    per_section: $per_section,
    per_tier_list: $per_tier_list,
    per_tier: $per_tier,
    aggregate_ceiling: $aggregate,
    savings_ceiling: $aggregate,
    model_assumptions: $model
  }' > "$JSON_OUT"

# -----------------------------------------------------------------------------
# Emit
# -----------------------------------------------------------------------------
if [ "$FORMAT" = "json" ]; then
  cat "$JSON_OUT"
  exit 0
fi

# text format
echo "=== M018 Section Distribution Probe ==="
echo "Records analyzed: payload_breakdown=$PB_COUNT"
echo "Bootstrap iterations: $BOOTSTRAP_ITER  seed: $SEED"
echo ""

echo "=== Per-section distribution (tokens) ==="
printf "  %-26s %5s %10s %10s %10s %10s\n" "section" "n" "mean" "p50" "p95" "max"
printf "  %-26s %5s %10s %10s %10s %10s\n" "--------------------------" "-----" "----------" "----------" "----------" "----------"
awk -F'\t' '{ printf "  %-26s %5d %10.0f %10d %10d %10d\n", $1, $2, $3, $4, $5, $6 }' "$PER_SECTION_TSV"
echo ""
printf "  Mean total payload (sum of section means): %.0f tok\n" "$MEAN_TOTAL_PAYLOAD"
echo ""

echo "=== Per-tier achievable savings (80% CI: low=p10, high=p90) ==="
printf "  %-12s %10s %10s %10s %10s %10s %10s\n" "tier" "low_tok" "mean_tok" "high_tok" "low_pct" "mean_pct" "high_pct"
printf "  %-12s %10s %10s %10s %10s %10s %10s\n" "------------" "----------" "----------" "----------" "----------" "----------" "----------"
awk -F'\t' '$1 != "aggregate" { printf "  %-12s %10.0f %10.0f %10.0f %9.2f%% %9.2f%% %9.2f%%\n", $1, $5, $6, $7, $2, $3, $4 }' "$TIER_TSV"
echo ""

echo "=== Aggregate savings_ceiling (non-overlap-adjusted) ==="
awk -F'\t' '$1 == "aggregate" { printf "  low_pct=%.2f%%  mean_pct=%.2f%%  high_pct=%.2f%%\n", $2, $3, $4
                                printf "  low_tok=%.0f  mean_tok=%.0f  high_tok=%.0f\n", $5, $6, $7 }' "$TIER_TSV"
echo "  (Standard+ intensity assumed for T3; Quick caps at filter+tier1+tier2.)"
echo ""

echo "Probe complete."
