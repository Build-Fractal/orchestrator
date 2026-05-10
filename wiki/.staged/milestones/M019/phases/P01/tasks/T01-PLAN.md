---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M019"
name: "pricing.sh helper + m019-schema.sh validator"
depends_on: []
---

## Prerequisites

- P00 is green: `scripts/verify/m019-p00-phase-suite.sh` passed on `completed_at: "2026-04-18T02:21:28Z"`.
- `.orchestrator/config/pricing.yml` ships from P00/T04 with `schema_version: "1.0"`, `last_updated: "2026-04-17"`, top-level `models:` map keyed by model id (each carrying `provider`, `input_per_million_usd`, `output_per_million_usd`), and top-level `aliases:` map.
- No emitter code yet; this task builds the foundational library + validator that T02, T03, T04 all consume.

## Description

Create the two foundation units every downstream task needs:

1. `scripts/lib/pricing.sh` — sourceable bash-3.2 library that resolves model rates from `.orchestrator/config/pricing.yml`, honors `ORCH_PRICING_FILE`, computes staleness age (days since `last_updated`), computes `estimated_cost_usd` from `input_tokens + output_tokens`, and signals missing / stale states so the caller can write `estimated_cost_usd: null` + a `pricing_warning` field (never aborts). AD-1 char-quartile token estimate (`chars / 4`) is a sibling helper on the same file since the payload emitter and the dispatch emitter both need it.

2. `scripts/verify/m019-schema.sh` — pure-bash JSONL schema validator that enforces:
   - `record_type` enum: `payload_breakdown`, `dispatch_usage`, `unit_close`.
   - `source` enum: `estimate`, `runtime` (SC-4).
   - `granularity` enum on `unit_close`: `task`, `phase`, `milestone`.
   - Mandatory cost + quality pairing on every `unit_close` record (Goodhart guard, C2).
   - Additivity: pre-M019 records (no `record_type` field) still validate (SC-10).

The library is intentionally bash-3.2 compatible but is emitter-internal (not agent-facing content), so MEM004 carves out pipes / `$()` / `awk` where needed. No `declare -A`. No `mapfile`. No `<(...)`.

## Steps

1. **Create `scripts/lib/pricing.sh`** with the following sourceable functions. The file is sourced, never executed directly; it prints nothing at load time.

   ```bash
   #!/usr/bin/env bash
   # scripts/lib/pricing.sh — M019/P01 pricing + token-estimate helpers.
   #
   # Sourceable library (no load-time output). All functions are idempotent
   # and side-effect-free except for stderr warnings on degradation paths.
   #
   # Resolver contract:
   #   pricing_file_path           -> prints resolved path (ORCH_PRICING_FILE override
   #                                  wins, else .orchestrator/config/pricing.yml)
   #   pricing_file_present        -> exit 0 if resolvable + readable, 1 otherwise
   #   pricing_last_updated        -> prints "YYYY-MM-DD" from last_updated, empty on miss
   #   pricing_stale_days          -> prints integer days since last_updated, or "" if N/A
   #   pricing_is_stale            -> exit 0 if file missing or age>90 days, 1 otherwise
   #   pricing_lookup_rates MODEL  -> prints "INPUT_USD_PER_M OUTPUT_USD_PER_M" or "" on miss
   #   pricing_resolve_alias MODEL -> prints concrete model id (resolves aliases.* -> models.*)
   #   pricing_estimate_cost_usd INPUT_TOKENS OUTPUT_TOKENS MODEL
   #                               -> prints numeric dollar estimate (8-decimal precision)
   #                                  OR prints empty string and exits 0 on pricing miss
   #   chars_to_tokens_quartile CHARCOUNT
   #                               -> prints int(chars/4), AD-1 token estimate method
   #                                  (token_estimate_method: "char-quartile")
   #   pricing_warning_reason      -> prints "missing" | "stale:<N>d" | "no-rate:<MODEL>"
   #                                  after a failed pricing_estimate_cost_usd; empty otherwise
   #
   # Bash 3.2 compatible. No declare -A. Parallel indexed-array lookups.
   # Emitter-internal (MEM004 carve-out): pipes/$()/awk permitted.
   ```

   Implementation rules:

   - `pricing_file_path`: `printf '%s\n' "${ORCH_PRICING_FILE:-$PROJECT_ROOT/.orchestrator/config/pricing.yml}"`. The sourcing script is expected to have `PROJECT_ROOT` set; if unset, compute it from `${BASH_SOURCE[0]}` parent-parent.
   - `pricing_last_updated`: parse with `grep -E '^last_updated:' | head -n 1 | sed -E 's/^last_updated:[[:space:]]*"?([^"]*)"?.*/\1/'`. Accept quoted or unquoted YAML scalars.
   - `pricing_stale_days`: compute `(now_epoch - last_updated_epoch) / 86400`. Use `date -u -j -f "%Y-%m-%d" "$d" +%s` on macOS (BSD date) with a GNU-date fallback (`date -u -d "$d" +%s`). macOS is the mandated baseline per MEM001.
   - `pricing_is_stale`: exit 0 (stale) if file missing or age > 90 days.
   - `pricing_resolve_alias`: read the `aliases:` block. If `MODEL` appears as an alias key, print its value; else echo `MODEL` unchanged.
   - `pricing_lookup_rates`: walk the `models:` block. For the resolved model id, extract `input_per_million_usd` and `output_per_million_usd` via `awk -v m="$model" '...'`. Print `"$in $out"` or empty string on miss.
   - `pricing_estimate_cost_usd`:
     - If `pricing_is_stale` returns 0 -> set `_PRICING_WARNING_REASON=missing` (or `stale:<N>d`) and print empty.
     - Resolve alias, look up rates. On miss -> `_PRICING_WARNING_REASON=no-rate:<MODEL>`, print empty.
     - Otherwise compute `(in_tok * in_rate + out_tok * out_rate) / 1000000` via `awk 'BEGIN { printf "%.8f", ... }'`. Print the value.
   - `chars_to_tokens_quartile`: `printf '%d\n' $(( ${1:-0} / 4 ))`. No floating point; AD-1 says `chars / 4`.
   - `pricing_warning_reason`: print `${_PRICING_WARNING_REASON:-}`.

   The warning-reason channel is a module-scoped variable (`_PRICING_WARNING_REASON`), set by `pricing_estimate_cost_usd` and read by the emitter. No `declare -g`; a plain top-level assignment after the function is fine (bash 3.2 compatible).

2. **Create `scripts/verify/m019-schema.sh`** — pure-bash JSONL schema validator.

   Shape (single-script-file invocation, bash 3.2):

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m019-schema.sh — M019 JSONL schema validator.
   #
   # Usage: m019-schema.sh <execution-log.jsonl>
   #
   # Enforces (M019/P01):
   #   - Valid JSONL (one JSON object per non-empty line).
   #   - If a line has `"record_type"`, its value must be one of:
   #       payload_breakdown | dispatch_usage | unit_close
   #   - If a line has `"source"`, value must be: estimate | runtime (SC-4).
   #   - unit_close records: `"granularity"` must be task|phase|milestone,
   #     AND the record must contain both a cost block (estimated_cost_usd AND
   #     pricing_version keys present, even if null) AND a quality block
   #     (verification_pass_rate, deviation_count, retry_count all present).
   #   - Pre-M019 records (no `record_type` field) are NOT rejected (SC-10
   #     additivity).
   #
   # Emits one line per violation on stderr in the form:
   #   FAIL: <file>:<lineno> <reason>
   # Emits "PASS: m019-schema.sh <N> records validated" on stdout on green.
   # Exit 0 on all-pass, 1 on any failure.
   #
   # Bash 3.2 compatible (MEM004 carve-out: awk/grep permitted).
   ```

   Implementation:

   - Loop `while IFS= read -r line; do ...; done < "$file"` (no `<(...)`).
   - Skip empty lines; increment `lineno`.
   - Use `grep -oE '"record_type"[[:space:]]*:[[:space:]]*"[^"]+"'` to extract the record_type value; same shape for `source`, `granularity`.
   - For each present field, test membership against a space-separated whitelist with `case` or a loop — bash 3.2 safe.
   - For `unit_close`, additionally require every one of the six cost+quality keys appear in the line. Missing any -> emit FAIL with the missing key name.
   - No `record_type`? This is a pre-M019 record — skip strict enums, still parse as JSON enough to confirm the line ends with `}`.
   - Invalid JSON (no leading `{`, no trailing `}`) -> FAIL with reason `not-json`.

3. **Source the pricing lib from build-context.sh and dispatch-interface.sh in T02 / T03.** Not this task — this task just ships the lib.

## Must-Haves

- `scripts/lib/pricing.sh` exists and is sourceable.
- `pricing_estimate_cost_usd` returns empty + sets `_PRICING_WARNING_REASON` on missing / stale / no-rate paths; never aborts the caller.
- `chars_to_tokens_quartile 4000` prints `1000`.
- `scripts/verify/m019-schema.sh` validates the shipped P00 fixtures (if any) and a synthetic good / bad fixture set (handled by T05).
- Both files are bash 3.2 compatible — no `declare -A`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`.

## Verification

- `bash scripts/verify/m019-p01-source-enum.sh` (ships in T05) — asserts schema accepts both `estimate` and `runtime`, rejects others.
- `bash scripts/verify/m019-p01-bash32-compat.sh` (ships in T06) — confirms bash 3.2 compliance of both new files.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M019/phases/P01` — confirms artifact paths + patterns.

Manual smoke check during this task (run once by hand; do NOT embed as a Check):
1. Create a throwaway script that sources `scripts/lib/pricing.sh`, calls `pricing_estimate_cost_usd 1000 500 claude-opus-4-7`, and prints the result. Expected: a value near `0.05250000`.
2. Rename `.orchestrator/config/pricing.yml` aside, re-run. Expected: empty output, `pricing_warning_reason` prints `missing`.
3. Restore.

## Inputs

### From Previous Tasks

None — T01 is the first task of P01.

### From Disk (Pre-existing)

- `.orchestrator/config/pricing.yml` (from M019/P00/T04) — source of rates and `last_updated` timestamp. Schema:
  - `schema_version: "1.0"`, `last_updated: YYYY-MM-DD`.
  - `models:` map, each entry has `provider`, `input_per_million_usd`, `output_per_million_usd`.
  - `aliases:` map of handle -> concrete model id.
- `scripts/lib/errors.sh`, `scripts/lib/run-context.sh` — existing lib patterns to mirror (sourceable, no load-time output, Bash 3.2 style).
- `.orchestrator/memory/constitution.md` — Principle VIII (Bash 3.2), Principle XV (no speculative complexity; Tier 1 ships no rollup, no CLI command).
- [`.orchestrator/milestones/M019/M019-CONTEXT.md`](../../../../../milestones/M019/M019-CONTEXT.md) — AD-1 (char-quartile), AD-2 (pricing path + override), AD-4 (three record types + source enum + granularity enum).

## Constraints

- **Bash 3.2** — no `declare -A`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`. macOS baseline per MEM001.
- **Zero agent-facing content** — this task only ships library code and a validator. No templates. No prompt text. The anti-pattern linter does NOT need to be retightened here.
- **MEM004 carve-out applies** — both files are verification-script-internal; pipes, `$()`, and awk are permitted inside the scripts.
- **No Tier 2/3 surface** — no `orchestrator:cost` command, no rollup script, no `.orchestrator/metrics/*.jsonl` aggregate. The `pricing.sh` functions are the foundation; T02/T03/T04 consume them; nothing more.
- **Never abort** — `pricing_estimate_cost_usd` must return success exit 0 even on missing-file / stale / no-rate; it signals degradation only via the empty-string return and `_PRICING_WARNING_REASON`.
- **Single-script-file Check shape (AD-19)** — every `Check:` entry in the phase plan references `scripts/verify/m019-p01-*.sh` or an equivalent single-invocation script.

## Expected Output

- `scripts/lib/pricing.sh` — sourceable, 80+ lines, all functions documented in the file header.
- `scripts/verify/m019-schema.sh` — executable, 80+ lines, accepts a JSONL path, emits `PASS:` on green and per-line `FAIL:` on violations.
- `bash scripts/verify/m019-schema.sh /dev/null` -> `PASS: m019-schema.sh 0 records validated`, exit 0.
- Sourcing `scripts/lib/pricing.sh` in a shell and calling `pricing_file_path` returns the canonical path under `.orchestrator/config/pricing.yml`.
