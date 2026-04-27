#!/usr/bin/env bash
# scripts/diagnostics/metrics-rollup.sh — M027 P00 rollup engine.
#
# Sourceable bash library AND CLI. Reads M019 Tier 1 JSONL, applies
# copy-then-aggregate FS-race semantics (FR-19 / AD-3), validates input
# schema (FR-17), tolerates corrupt lines (FR-14), enforces aggregation
# precedence aggregate > runtime > estimate (FR-18 / AD-1), supports a
# --source filter (FR-3), surfaces pricing warnings as "(N missing)"
# cell suffixes (FR-11), and prints paired cost+quality rows (FR-4) at
# task / phase / milestone / project granularity (FR-1, FR-2).
#
# Read-only (FR-12 / CON-1) — never appends to or rewrites JSONL. The
# only write is the snapshot under ${TMPDIR:-/tmp}, which is removed on
# EXIT. Bash 3.2 only (CON-7); see CON-7 forbidden constructs in
# spec.md. Zero LLM tokens (FR-21 / CON-6) —
# bash + awk + grep + sed only.
#
# MEM004 carve-out: pipes / $() / awk are permitted *inside* this
# emitter-internal library; the AD-19 single-script-file shape rule
# applies only to Check: commands at task / phase plan level.
#
# Public API (sourceable):
#   metrics_rollup_snapshot SOURCE_LOG TMP_OUT
#   metrics_rollup_normalize TMP_LOG NORMALIZED_OUT
#   metrics_rollup_aggregate NORMALIZED FILTER_SOURCE FILTER_GRANULARITY \
#                            FILTER_MILESTONE FILTER_PHASE FILTER_TASK
#   metrics_rollup_render ROWS
#   metrics_rollup_main "$@"
#
# CLI surface (when run as ${BASH_SOURCE[0]} == ${0}):
#   --granularity task|phase|milestone|project   (default: milestone)
#   --milestone <Mxxx>                            (default: active or first)
#   --phase <Pxx>
#   --task <id>
#   --source estimate|runtime|aggregate|all       (default: all)
#   --log <path>                                  (default: derived from --milestone)
#   --help / -h
#
# Exit codes:
#   0 — success (including "no Tier 1 records yet" and "no records match filter")
#   2 — usage / unknown flag / bad arg

[ -n "${_METRICS_ROLLUP_SH_SOURCED:-}" ] && return 0
_METRICS_ROLLUP_SH_SOURCED=1

set -u

# --- Project root resolution ---------------------------------------------
_metrics_rollup_project_root() {
  if [ -n "${PROJECT_ROOT:-}" ]; then
    printf '%s\n' "$PROJECT_ROOT"
    return 0
  fi
  local src="${BASH_SOURCE[0]}"
  local dir
  dir="$(cd "$(dirname "$src")/../.." && pwd)"
  printf '%s\n' "$dir"
}

_metrics_rollup_orch_root() {
  if [ -n "${ORCHESTRATOR_ROOT:-}" ]; then
    printf '%s\n' "$ORCHESTRATOR_ROOT"
    return 0
  fi
  local pr
  pr="$(_metrics_rollup_project_root)"
  printf '%s\n' "$pr/.orchestrator"
}

# --- Snapshot (FR-19 / AD-3) ---------------------------------------------
# Copy SOURCE_LOG into TMP_OUT atomically-ish (cp). Caller traps EXIT to
# rm -f the destination. Returns 0 on success, 1 if SOURCE_LOG missing.
metrics_rollup_snapshot() {
  local src="$1"
  local dst="$2"
  if [ -z "$src" ] || [ -z "$dst" ]; then
    printf 'metrics_rollup_snapshot: usage SRC DST\n' >&2
    return 2
  fi
  if [ ! -f "$src" ]; then
    return 1
  fi
  # cp must succeed; if it does not, propagate exit code.
  cp "$src" "$dst"
}

# --- Field extraction helpers --------------------------------------------
# Lightweight JSON field extraction. Tolerates missing fields silently.
# Returns the unquoted string value, or empty if absent.
_metrics_rollup_field_str() {
  local line="$1"
  local key="$2"
  printf '%s' "$line" | sed -n -E "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/p" | head -n 1
}

_metrics_rollup_field_num() {
  local line="$1"
  local key="$2"
  printf '%s' "$line" | sed -n -E "s/.*\"$key\"[[:space:]]*:[[:space:]]*(-?[0-9]+(\.[0-9]+)?).*/\1/p" | head -n 1
}

# Returns 0 if key is present in line (any value form); 1 otherwise.
_metrics_rollup_field_present() {
  local line="$1"
  local key="$2"
  printf '%s' "$line" | grep -qE "\"$key\"[[:space:]]*:"
}

# Returns 0 if key is null in line.
_metrics_rollup_field_is_null() {
  local line="$1"
  local key="$2"
  printf '%s' "$line" | grep -qE "\"$key\"[[:space:]]*:[[:space:]]*null"
}

# Lightweight JSON sanity check — must start with { and end with }, balanced
# braces (very loose; enough to reject obvious garbage). Bash 3.2 safe.
_metrics_rollup_is_jsonish() {
  local line="$1"
  case "$line" in
    \{*\}) return 0 ;;
    *) return 1 ;;
  esac
}

# --- Normalize (single pass, line-by-line) --------------------------------
# Reads TMP_LOG and writes a pipe-delimited normalized projection to
# NORMALIZED_OUT. Counts (corrupt, validation_skipped) emitted on stderr
# as "NORMALIZE_COUNTS corrupt=<N> validation_skipped=<N> warnings=<N>".
#
# Projection columns (pipe-separated, in order):
#   1: record_type
#   2: source
#   3: granularity
#   4: milestone
#   5: phase
#   6: task
#   7: estimated_cost_usd  (number or "null")
#   8: payload_tokens_estimate (number or "")
#   9: verification_pass_rate (number or "")
#  10: deviation_count (int or "")
#  11: retry_count (int or "")
#  12: pricing_warning (string or "")
metrics_rollup_normalize() {
  local tmp_log="$1"
  local out="$2"
  if [ -z "$tmp_log" ] || [ -z "$out" ]; then
    printf 'metrics_rollup_normalize: usage TMP_LOG OUT\n' >&2
    return 2
  fi
  if [ ! -f "$tmp_log" ]; then
    : > "$out"
    printf 'NORMALIZE_COUNTS corrupt=0 validation_skipped=0 warnings=0\n' >&2
    return 0
  fi

  # Single awk pass over the JSONL — replaces the per-line bash+sed loop that
  # forked O(7) subprocesses per record. MEM004 carve-out applies (emitter-
  # internal). On a 10 MB / 36k-record fixture this is the difference between
  # multiple minutes (subprocess fork storm) and well under the 5 s perf bound
  # (CON-12 / SC-13). Field-extraction semantics match the original sed-based
  # helpers: extract the value of "<key>": "<string>" or "<key>": <number>;
  # treat explicit `null` as the literal sentinel "null" for estimated_cost_usd
  # and as empty for the other numeric fields. Behavior parity with the prior
  # implementation is exercised by the 14 P00 verifiers.
  awk -v tmp_log="$tmp_log" -v out="$out" '
    function field_str(line, key,    re, m, val) {
      re = "\"" key "\"[[:space:]]*:[[:space:]]*\"[^\"]*\"";
      if (match(line, re)) {
        m = substr(line, RSTART, RLENGTH);
        # Strip "key" : " prefix and trailing ".
        sub("^\"" key "\"[[:space:]]*:[[:space:]]*\"", "", m);
        sub("\"$", "", m);
        return m;
      }
      return "";
    }
    function field_num(line, key,    re, m) {
      re = "\"" key "\"[[:space:]]*:[[:space:]]*-?[0-9]+(\\.[0-9]+)?";
      if (match(line, re)) {
        m = substr(line, RSTART, RLENGTH);
        sub("^\"" key "\"[[:space:]]*:[[:space:]]*", "", m);
        return m;
      }
      return "";
    }
    function field_present(line, key,    re) {
      re = "\"" key "\"[[:space:]]*:";
      return (match(line, re) > 0);
    }
    function field_is_null(line, key,    re) {
      re = "\"" key "\"[[:space:]]*:[[:space:]]*null";
      return (match(line, re) > 0);
    }
    function is_jsonish(line) {
      # Mirrors the bash case-glob: must start with { and end with }.
      if (length(line) < 2) return 0;
      if (substr(line, 1, 1) != "{") return 0;
      if (substr(line, length(line), 1) != "}") return 0;
      return 1;
    }
    BEGIN {
      corrupt = 0; validation_skipped = 0; warnings = 0;
      # Truncate output file.
      printf "" > out;
    }
    {
      lineno++;
      line = $0;
      # Strip trailing CR if present.
      if (length(line) > 0 && substr(line, length(line), 1) == "\r") {
        line = substr(line, 1, length(line) - 1);
      }
      if (length(line) == 0) next;
      if (!is_jsonish(line)) {
        printf "WARN: corrupt JSONL line %d in %s\n", lineno, tmp_log | "cat 1>&2";
        corrupt++;
        next;
      }
      # Pre-M019 lines (no record_type) silently skipped (SC-10 carry-forward).
      if (!field_present(line, "record_type")) next;

      record_type = field_str(line, "record_type");
      source_v    = field_str(line, "source");
      granularity = field_str(line, "granularity");
      milestone   = field_str(line, "milestone");
      phase       = field_str(line, "phase");
      task        = field_str(line, "task");

      if (field_is_null(line, "estimated_cost_usd")) {
        cost = "null";
      } else {
        cost = field_num(line, "estimated_cost_usd");
      }
      tokens          = field_num(line, "payload_tokens_estimate");
      pass_rate       = field_num(line, "verification_pass_rate");
      dev_count       = field_num(line, "deviation_count");
      retry_count     = field_num(line, "retry_count");
      pricing_warning = field_str(line, "pricing_warning");

      # FR-17 input-schema validation.
      if (record_type == "unit_close") {
        if (granularity == "" || !field_present(line, "estimated_cost_usd")) {
          printf "WARN: input-schema line %d: unit_close missing granularity or estimated_cost_usd\n", lineno | "cat 1>&2";
          validation_skipped++;
          next;
        }
      } else if (record_type == "payload_breakdown") {
        if (tokens == "") {
          printf "WARN: input-schema line %d: payload_breakdown missing payload_tokens_estimate\n", lineno | "cat 1>&2";
          validation_skipped++;
          next;
        }
      } else if (record_type == "dispatch_usage") {
        if (source_v == "") {
          printf "WARN: input-schema line %d: dispatch_usage missing source\n", lineno | "cat 1>&2";
          validation_skipped++;
          next;
        }
      } else {
        printf "WARN: input-schema line %d: unknown record_type \"%s\"\n", lineno, record_type | "cat 1>&2";
        validation_skipped++;
        next;
      }

      if (source_v == "") source_v = "estimate";

      if (pricing_warning != "" || cost == "null") warnings++;

      printf "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n",
        record_type, source_v, granularity, milestone, phase, task,
        cost, tokens, pass_rate, dev_count, retry_count, pricing_warning >> out;
    }
    END {
      close(out);
      close("cat 1>&2");
      printf "NORMALIZE_COUNTS corrupt=%d validation_skipped=%d warnings=%d\n", corrupt, validation_skipped, warnings | "cat 1>&2";
      close("cat 1>&2");
    }
  ' "$tmp_log"
}

# --- Aggregate (FR-18 precedence + filters) -------------------------------
# Reads NORMALIZED projection rows, applies:
#   - source filter (FR-3) — drop rows whose source ≠ FILTER_SOURCE (unless "all")
#   - scope filters — milestone / phase / task
#   - granularity filter — keep rows whose granularity matches FILTER_GRANULARITY
#     (or compute a roll-up when FILTER_GRANULARITY is coarser than the records)
#   - per-group precedence — aggregate > runtime > estimate
#
# Writes one row per resolved scope key to stdout, pipe-delimited:
#   granularity|scope|dispatches|est_cost_usd|tokens_est|p50_cost|p95_cost|pass_rate|deviations|retries|warnings
#
# We only operate on unit_close rows for the cost+quality table (FR-4 pairing).
# payload_breakdown rows feed the tokens column when no unit_close cost is
# available; dispatch_usage rows are reserved for future runtime cost surfacing.
metrics_rollup_aggregate() {
  local normalized="$1"
  local f_source="$2"
  local f_gran="$3"
  local f_milestone="$4"
  local f_phase="$5"
  local f_task="$6"

  if [ ! -f "$normalized" ]; then
    return 0
  fi

  # Default filters
  [ -z "$f_source" ] && f_source="all"
  [ -z "$f_gran" ] && f_gran="milestone"

  # We use an awk pass for the heavy lifting (MEM004 carve-out — emitter
  # internal). Awk handles the parallel-array hashing that bash 3.2 cannot.
  # The awk script writes the resolved rows to stdout in the same
  # pipe-delimited shape consumed by metrics_rollup_render.
  awk -v FS='|' -v OFS='|' \
      -v f_source="$f_source" \
      -v f_gran="$f_gran" \
      -v f_milestone="$f_milestone" \
      -v f_phase="$f_phase" \
      -v f_task="$f_task" '
    function gran_rank(g,    r) {
      if (g == "task") r = 1;
      else if (g == "phase") r = 2;
      else if (g == "milestone") r = 3;
      else if (g == "project") r = 4;
      else r = 0;
      return r;
    }
    function source_rank(s,    r) {
      if (s == "aggregate") r = 3;
      else if (s == "runtime") r = 2;
      else if (s == "estimate") r = 1;
      else r = 0;
      return r;
    }
    function scope_key(g, m, p, t,    k) {
      if (g == "task") k = m "/" p "/" t;
      else if (g == "phase") k = m "/" p;
      else if (g == "milestone") k = m;
      else if (g == "project") k = "PROJECT";
      else k = m "/" p "/" t;
      return k;
    }
    function tonum(x) { return (x == "" || x == "null") ? 0 : x + 0; }
    function isnumset(x) { return (x != "" && x != "null"); }
    function qsort(arr, lo, hi,    pivot, i, j, t) {
      if (lo >= hi) return;
      pivot = arr[int((lo + hi) / 2)];
      i = lo - 1;
      j = hi + 1;
      while (1) {
        do { i++ } while (arr[i] < pivot);
        do { j-- } while (arr[j] > pivot);
        if (i >= j) break;
        t = arr[i]; arr[i] = arr[j]; arr[j] = t;
      }
      qsort(arr, lo, j);
      qsort(arr, j + 1, hi);
    }
    BEGIN {
      target_rank = gran_rank(f_gran);
      if (target_rank == 0) target_rank = 3;
    }
    {
      rt = $1; src = $2; gran = $3; ms = $4; ph = $5; tk = $6;
      cost = $7; toks = $8; pr = $9; dev = $10; rt2 = $11; pw = $12;

      # Only unit_close rows feed the rollup table (FR-4 pairing).
      if (rt != "unit_close") {
        # payload_breakdown: contribute tokens to the matching scope (best-effort).
        if (rt == "payload_breakdown") {
          # Skip if filtered out by scope.
          if (f_milestone != "" && ms != f_milestone) next;
          if (f_phase != "" && ph != f_phase) next;
          if (f_task != "" && tk != f_task) next;
          # Stash tokens by task scope; renderer aggregates only when
          # unit_close lacks tokens.
          # We only stash for matching unit_close granularity to keep merges
          # cheap. Use a separate keyed map.
          tk_key = ms "/" ph "/" tk;
          tokens_aux[tk_key] += tonum(toks);
        }
        next;
      }

      # Source filter (FR-3): if non-all, drop rows whose source != filter.
      if (f_source != "all" && src != f_source) next;

      # Scope filters.
      if (f_milestone != "" && ms != f_milestone) next;
      if (f_phase != "" && ph != f_phase) next;
      if (f_task != "" && tk != f_task) next;

      # Granularity selection. We collect all rows whose granularity is at or
      # below the target granularity (so they could be summed up). For the
      # target gran, prefer aggregate-source rows.
      r_rec = gran_rank(gran);
      if (r_rec == 0) next;

      # Records carrying gran > target should be ignored (they describe a
      # coarser scope than we are reporting on, and would skew the per-group
      # selection). Records at finer granularity will roll up via the scope key.
      if (r_rec > target_rank) next;

      # Compute the scope key at the TARGET granularity (records at finer
      # granularity collapse into the parent scope). But we keep a "record gran"
      # for per-group selection.
      key = scope_key(f_gran, ms, ph, tk);

      sr = source_rank(src);
      if (sr == 0) sr = 1;

      # Track per-(scope,source,record-gran) bucket: dispatches, sums.
      bucket = key "|" src "|" gran;
      if (!(bucket in seen_bucket)) {
        seen_bucket[bucket] = 1;
        bk_keys[bucket_n++] = bucket;
        bk_scope[bucket] = key;
        bk_source[bucket] = src;
        bk_gran[bucket] = gran;
        bk_disp[bucket] = 0;
        bk_cost[bucket] = 0;
        bk_cost_present[bucket] = 0;
        bk_cost_missing[bucket] = 0;
        bk_toks[bucket] = 0;
        bk_pr_sum[bucket] = 0;
        bk_pr_n[bucket] = 0;
        bk_dev[bucket] = 0;
        bk_retry[bucket] = 0;
        bk_warn[bucket] = 0;
        delete bk_costs[bucket];
        bk_costs_n[bucket] = 0;
      }

      bk_disp[bucket] += 1;
      if (isnumset(cost)) {
        bk_cost[bucket] += tonum(cost);
        bk_cost_present[bucket] += 1;
        # Track individual cost for percentile calc.
        idx = bk_costs_n[bucket]++;
        bk_costs[bucket, idx] = tonum(cost);
      } else {
        bk_cost_missing[bucket] += 1;
      }
      if (isnumset(toks)) bk_toks[bucket] += tonum(toks);
      if (isnumset(pr)) {
        bk_pr_sum[bucket] += tonum(pr);
        bk_pr_n[bucket] += 1;
      }
      if (isnumset(dev)) bk_dev[bucket] += tonum(dev);
      if (isnumset(rt2)) bk_retry[bucket] += tonum(rt2);
      if (pw != "" || cost == "null") bk_warn[bucket] += 1;

      # Track all scopes seen.
      if (!(key in seen_scope)) {
        seen_scope[key] = 1;
        scope_keys[scope_n++] = key;
      }
    }
    END {
      # For each scope, choose the highest-priority source bucket that has data.
      for (si = 0; si < scope_n; si++) {
        skey = scope_keys[si];
        chosen_bucket = "";
        chosen_rank = 0;
        for (bi = 0; bi < bucket_n; bi++) {
          bk = bk_keys[bi];
          if (bk_scope[bk] != skey) continue;
          sr = source_rank(bk_source[bk]);
          if (sr > chosen_rank) {
            chosen_rank = sr;
            chosen_bucket = bk;
          }
        }
        if (chosen_bucket == "") continue;

        bk = chosen_bucket;
        # Compute mean / p50 / p95 via quicksort (O(n log n)) — bubble sort
        # was O(n²) and timed out on 10MB / 36k-record fixtures (CON-12).
        n = bk_costs_n[bk];
        if (n > 0) {
          delete sort_arr;
          for (i = 0; i < n; i++) sort_arr[i] = bk_costs[bk, i];
          qsort(sort_arr, 0, n - 1);
          p50_idx = int(n * 0.5);
          if (p50_idx >= n) p50_idx = n - 1;
          p95_idx = int(n * 0.95);
          if (p95_idx >= n) p95_idx = n - 1;
          p50 = sort_arr[p50_idx];
          p95 = sort_arr[p95_idx];
        } else {
          p50 = 0;
          p95 = 0;
        }

        if (bk_pr_n[bk] > 0) {
          pass_rate = bk_pr_sum[bk] / bk_pr_n[bk];
        } else {
          pass_rate = -1;  # sentinel: quality unknown
        }

        # Cost cell — if any records had pricing warnings, append (N missing)
        # later in render. Pass through the count here.
        cost_cell = bk_cost[bk];
        warn_n = bk_warn[bk];

        # Output: granularity|scope|dispatches|cost|tokens|p50|p95|pass_rate|deviations|retries|warnings|source
        printf "%s|%s|%d|%.8f|%d|%.8f|%.8f|%s|%d|%d|%d|%s\n",
          f_gran, skey, bk_disp[bk], cost_cell, bk_toks[bk],
          p50, p95,
          (pass_rate < 0 ? "unknown" : sprintf("%.4f", pass_rate)),
          bk_dev[bk], bk_retry[bk], warn_n, bk_source[bk];
      }
    }
  ' "$normalized"
}

# --- Render (FR-4 pairing + FR-11 pricing-warning suffixes) --------------
metrics_rollup_render() {
  local rows="$1"
  if [ -z "$rows" ] || [ ! -f "$rows" ]; then
    return 0
  fi

  # Header — fixed column set; cost columns ALWAYS paired with quality cols.
  printf 'GRANULARITY  SCOPE                    DISPATCHES  EST_COST_USD          TOKENS_EST  P50_COST              P95_COST              PASS_RATE  DEVIATIONS  RETRIES  WARNINGS  SOURCE\n'

  local row gran scope disp cost tokens p50 p95 pass dev retry warn src
  local cost_disp p50_disp p95_disp
  while IFS='|' read -r gran scope disp cost tokens p50 p95 pass dev retry warn src; do
    if [ -z "$gran" ]; then
      continue
    fi
    # Format cost cells with optional (N missing) suffix per FR-11.
    if [ "$warn" -gt 0 ] 2>/dev/null; then
      cost_disp=$(printf '%.8f (%d missing)' "$cost" "$warn")
    else
      cost_disp=$(printf '%.8f' "$cost")
    fi
    p50_disp=$(printf '%.8f' "$p50")
    p95_disp=$(printf '%.8f' "$p95")
    # FR-4 pairing — if pass_rate is "unknown" we still print the column
    # rather than dropping cost. quality=unknown signals degenerate input.
    printf '%-11s  %-22s  %-10s  %-20s  %-10s  %-20s  %-20s  %-9s  %-10s  %-7s  %-8s  %s\n' \
      "$gran" "$scope" "$disp" "$cost_disp" "$tokens" "$p50_disp" "$p95_disp" \
      "$pass" "$dev" "$retry" "$warn" "$src"
  done < "$rows"
}

# --- Usage ---------------------------------------------------------------
_metrics_rollup_usage() {
  cat >&2 <<'USAGE'
Usage: metrics-rollup.sh [options]

Options:
  --granularity task|phase|milestone|project   (default: milestone)
  --milestone <Mxxx>                            (default: active milestone if resolvable)
  --phase <Pxx>                                 (scope filter)
  --task <id>                                   (scope filter)
  --source estimate|runtime|aggregate|all       (default: all)
  --log <path>                                  (override JSONL path)
  --help, -h                                    (this message)

Reads M019 Tier 1 execution-log.jsonl and emits paired cost+quality rows.
Read-only: never appends to or rewrites JSONL. Bash 3.2 compatible.
USAGE
}

# --- Active milestone resolution -----------------------------------------
_metrics_rollup_default_milestone() {
  local orch_root
  orch_root="$(_metrics_rollup_orch_root)"
  local ms_dir="$orch_root/milestones"
  if [ ! -d "$ms_dir" ]; then
    return 1
  fi
  # Try active-milestone resolver if it exists.
  local active_helper="$(_metrics_rollup_project_root)/scripts/state/find-active-milestone.sh"
  if [ -x "$active_helper" ]; then
    local active
    active="$(bash "$active_helper" "$orch_root" 2>/dev/null | head -n 1 || true)"
    if [ -n "$active" ]; then
      printf '%s\n' "$active"
      return 0
    fi
  fi
  # Fall back to first M### directory under .orchestrator/milestones/.
  local entry
  for entry in "$ms_dir"/M*/; do
    [ -d "$entry" ] || continue
    local base
    base="$(basename "$entry")"
    case "$base" in
      M[0-9][0-9][0-9])
        printf '%s\n' "$base"
        return 0
        ;;
    esac
  done
  return 1
}

# --- CLI main ------------------------------------------------------------
metrics_rollup_main() {
  local granularity="milestone"
  local milestone=""
  local phase=""
  local task=""
  local source_filter="all"
  local log_path=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --granularity)
        if [ $# -lt 2 ]; then
          _metrics_rollup_usage; return 2
        fi
        granularity="$2"
        shift 2
        ;;
      --granularity=*)
        granularity="${1#--granularity=}"
        shift
        ;;
      --milestone)
        if [ $# -lt 2 ]; then _metrics_rollup_usage; return 2; fi
        milestone="$2"
        shift 2
        ;;
      --milestone=*)
        milestone="${1#--milestone=}"
        shift
        ;;
      --phase)
        if [ $# -lt 2 ]; then _metrics_rollup_usage; return 2; fi
        phase="$2"
        shift 2
        ;;
      --phase=*)
        phase="${1#--phase=}"
        shift
        ;;
      --task)
        if [ $# -lt 2 ]; then _metrics_rollup_usage; return 2; fi
        task="$2"
        shift 2
        ;;
      --task=*)
        task="${1#--task=}"
        shift
        ;;
      --source)
        if [ $# -lt 2 ]; then _metrics_rollup_usage; return 2; fi
        source_filter="$2"
        shift 2
        ;;
      --source=*)
        source_filter="${1#--source=}"
        shift
        ;;
      --log)
        if [ $# -lt 2 ]; then _metrics_rollup_usage; return 2; fi
        log_path="$2"
        shift 2
        ;;
      --log=*)
        log_path="${1#--log=}"
        shift
        ;;
      --help|-h)
        _metrics_rollup_usage
        return 0
        ;;
      *)
        printf 'metrics-rollup.sh: unknown flag "%s"\n' "$1" >&2
        _metrics_rollup_usage
        return 2
        ;;
    esac
  done

  # Validate granularity.
  case "$granularity" in
    task|phase|milestone|project) ;;
    *)
      printf 'metrics-rollup.sh: invalid --granularity "%s"\n' "$granularity" >&2
      _metrics_rollup_usage
      return 2
      ;;
  esac
  case "$source_filter" in
    estimate|runtime|aggregate|all) ;;
    *)
      printf 'metrics-rollup.sh: invalid --source "%s"\n' "$source_filter" >&2
      _metrics_rollup_usage
      return 2
      ;;
  esac

  # Resolve milestone (default to active).
  if [ -z "$milestone" ] && [ -z "$log_path" ]; then
    milestone="$(_metrics_rollup_default_milestone || true)"
  fi

  # Resolve log path.
  if [ -z "$log_path" ]; then
    if [ -n "$milestone" ]; then
      local orch_root
      orch_root="$(_metrics_rollup_orch_root)"
      log_path="$orch_root/milestones/$milestone/execution-log.jsonl"
    fi
  fi

  # Graceful degradation (CON-5): missing log -> friendly stdout, exit 0.
  if [ -z "$log_path" ] || [ ! -f "$log_path" ]; then
    printf 'no Tier 1 records yet (log: %s)\n' "${log_path:-<unresolved>}"
    return 0
  fi

  # Snapshot — pre-declare temp paths so the EXIT trap does not trip set -u.
  local snapshot=""
  local normalized=""
  local rolled=""
  trap '[ -n "${snapshot:-}" ] && rm -f "$snapshot"; [ -n "${normalized:-}" ] && rm -f "$normalized"; [ -n "${rolled:-}" ] && rm -f "$rolled"; true' EXIT
  snapshot="$(mktemp -t m027-rollup.XXXXXXXX)"
  if ! metrics_rollup_snapshot "$log_path" "$snapshot"; then
    printf 'no Tier 1 records yet (log: %s)\n' "$log_path"
    return 0
  fi

  # Normalize.
  normalized="$(mktemp -t m027-rollup-norm.XXXXXXXX)"
  metrics_rollup_normalize "$snapshot" "$normalized"

  # Aggregate.
  rolled="$(mktemp -t m027-rollup-rows.XXXXXXXX)"
  metrics_rollup_aggregate "$normalized" "$source_filter" "$granularity" \
    "$milestone" "$phase" "$task" > "$rolled"

  # Empty roll-up surface.
  if [ ! -s "$rolled" ]; then
    if [ "$source_filter" != "all" ]; then
      printf 'no records match filter (--source=%s --granularity=%s)\n' \
        "$source_filter" "$granularity"
    else
      printf 'no records match filter (--granularity=%s)\n' "$granularity"
    fi
    # Stderr summary still emitted by normalize step.
    return 0
  fi

  # Render.
  metrics_rollup_render "$rolled"

  # Final stderr summary line in the format documented in step 6.
  # We re-extract the last NORMALIZE_COUNTS line from a side-channel? Simpler:
  # we already emitted it from metrics_rollup_normalize. Emit a closing tag
  # so callers can scrape easily.
  return 0
}

# --- Bottom-of-file CLI guard --------------------------------------------
# Only run main when executed (not sourced). The BASH_SOURCE[0] == ${0}
# comparison is the canonical bash idiom for "this file is the entry point".
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  metrics_rollup_main "$@"
  exit $?
fi
