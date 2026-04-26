#!/usr/bin/env bash
# tests/fixtures/m027-p00/perf-10mb.jsonl.gen.sh
#
# Synthesize a deterministic >=10 MB JSONL fixture of M019 Tier 1 unit_close
# records for the M027/P00 perf-bound verifier (CON-12 / SC-13).
#
# Usage:
#   bash perf-10mb.jsonl.gen.sh [output-path]
#
# Default output path: tests/fixtures/m027-p00/perf-10mb.jsonl (relative to
# the repo root, computed from this script's location).
#
# Contract:
#   - Bash 3.2 compatible. No declare -A, no <<<, no mapfile, no process
#     substitution. MEM004 carve-out: this is fixture-emitter-internal.
#   - Deterministic: byte-identical across invocations with the same args
#     (no $RANDOM, no $$, no live timestamps).
#   - Fast: completes in well under 1 s on a 2024-era laptop.
#   - Emits exactly one stdout line: the resolved output path.
#   - Output JSONL contains only valid M019 unit_close records (record_type,
#     ts, milestone, phase, task, granularity, source, estimated_cost_usd,
#     pricing_version, verification_pass_rate, deviation_count, retry_count
#     all present). Milestone is M999 so no real-data collisions (CON-1).
#
# Implementation strategy:
#   - Build a single in-memory chunk of ~1000 records in one printf call,
#     then append the chunk N times to the output file. This avoids the
#     per-record fork/exec overhead that dominates a naive while-loop.
#   - Determinism is preserved because the chunk is byte-identical across
#     invocations and is appended a fixed number of times for a given target.

set -u

script_dir=$(cd "$(dirname "$0")" && pwd)
default_out="$script_dir/perf-10mb.jsonl"

out="${1:-$default_out}"

# Target size: 10 MB (10 * 1024 * 1024 = 10485760 bytes).
target=10485760

# Build a chunk of CHUNK_RECS records into a temp buffer. We'll then append
# the chunk repeatedly to reach >= target bytes.
chunk_recs=100
chunk_file="${out}.chunk.tmp"

: > "$chunk_file"

# Build the chunk via a single printf invocation by assembling the format
# string and the argument list. To stay bash 3.2 compatible we use a
# positional-array build-up loop, then expand "${args[@]}" once.
fmt=""
i=0
# Pre-build args via an indexed array.
args=()
while [ "$i" -lt "$chunk_recs" ]; do
  task_n=$((i % 100))
  phase_n=$(((i / 100) % 10))
  sec=$((i % 60))
  minute=$(((i / 60) % 60))
  hour=$(((i / 3600) % 24))
  day=$((1 + (i / 86400) % 28))
  # Compose the record line via printf into a per-iteration variable.
  # We do one printf per record into the chunk file directly — slow per
  # record, but only chunk_recs iterations total (1000), not 100k+.
  task_s=$(printf 'T%03d' "$task_n")
  phase_s=$(printf 'P%02d' "$phase_n")
  ts_s=$(printf '2026-01-%02dT%02d:%02d:%02dZ' "$day" "$hour" "$minute" "$sec")
  printf '{"record_type":"unit_close","ts":"%s","milestone":"M999","phase":"%s","task":"%s","granularity":"task","source":"estimate","estimated_cost_usd":0.01,"pricing_version":"v1","payload_tokens_estimate":1000,"verification_pass_rate":1.0,"deviation_count":0,"retry_count":0}\n' \
    "$ts_s" "$phase_s" "$task_s" >> "$chunk_file"
  i=$((i + 1))
done

# Measure the chunk size.
chunk_bytes=$(wc -c < "$chunk_file" | tr -d ' \n\t')

# Compute how many chunk-copies we need to clear the target.
# ceil(target / chunk_bytes).
copies=$(( (target + chunk_bytes - 1) / chunk_bytes ))

# Truncate the output, then append the chunk `copies` times.
: > "$out"
n=0
while [ "$n" -lt "$copies" ]; do
  cat "$chunk_file" >> "$out"
  n=$((n + 1))
done

rm -f "$chunk_file"

printf '%s\n' "$out"
