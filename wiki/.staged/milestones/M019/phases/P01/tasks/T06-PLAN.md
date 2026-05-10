---
schema_version: "1.0"
type: task-plan
task: "T06"
phase: "P01"
milestone: "M019"
name: "Phase-suite orchestrator + fixture-rollup demo + bash32-compat + no-pre-p00-emission"
depends_on: ["T05"]
---

## Prerequisites

- T01–T05 complete. Five per-gate verify scripts are green. Fixtures under `tests/fixtures/m019-p01/` are populated. All three emitters are live. Pricing lib + schema validator are callable.
- P00 SUMMARY frozen at `completed_at: "2026-04-18T02:21:28Z"` — this is the epoch for the SC-12 ordering gate.

## Description

Close P01 by shipping the three remaining verify gates plus the orchestrator and a small fixture-rollup verification asset:

1. `scripts/verify/m019-p01-bash32-compat.sh` — bash 3.2 compat scan for every `.sh` file touched or created in P01.
2. `scripts/verify/m019-p01-no-pre-p00-emission.sh` — SC-12 hard ordering: asserts no emitter record exists in any post-[M011](../../../../../milestones/M011/index.md) milestone's `execution-log.jsonl` with a timestamp earlier than `2026-04-18T02:21:28Z` (P00 SUMMARY `completed_at`).
3. `scripts/verify/m019-p01-fixture-rollup.sh` — verification asset only: reads `tests/fixtures/m019-p01/post-m019-rollup-demo.jsonl`, prints granularity-keyed cost totals, demonstrates SC-7 greppability without shipping any `orchestrator:cost` command.
4. `scripts/verify/m019-p01-phase-suite.sh` — orchestrates the eight P01 gates in one invocation, reports `PASS: N / FAIL: 0` summary, exits 0 on green.

This is also the task that walks the full emitter path end-to-end on a real (not fixture) milestone to produce the first post-P00 records for [M012](../../../../../milestones/M012/index.md) dogfooding — but only after every gate is green.

## Steps

1. **Write `scripts/verify/m019-p01-bash32-compat.sh`** — mirror the P00 pattern at `scripts/verify/m019-p00-bash32-compat.sh`. Scope: every `.sh` file modified or created by P01. Explicit list (not globbed), each file scanned for:
   - `declare -A` (associative arrays — FAIL)
   - `mapfile` / `readarray` (FAIL)
   - `${var^^}` / `${var,,}` case-modify (FAIL)
   - `<(...)` / `>(...)` process substitution (FAIL)
   - `&>` compound redirect (FAIL)
   - `[[ ... ]] =~` inside single-line sourced libs (CAUTION — OK in functions, still allowed)

   Split-needle pattern per MEM021/P04 to avoid the scanner matching itself. File list:

   ```
   scripts/lib/pricing.sh
   scripts/dispatch/build-context.sh
   scripts/dispatch/dispatch-interface.sh
   scripts/knowledge/write-summary.sh
   scripts/verify/m019-schema.sh
   scripts/verify/m019-p01-emitter-presence.sh
   scripts/verify/m019-p01-pricing-degradation.sh
   scripts/verify/m019-p01-source-enum.sh
   scripts/verify/m019-p01-zero-token-growth.sh
   scripts/verify/m019-p01-fixture-rollup.sh
   scripts/verify/m019-p01-additive-compat.sh
   scripts/verify/m019-p01-no-pre-p00-emission.sh
   scripts/verify/m019-p01-bash32-compat.sh
   scripts/verify/m019-p01-phase-suite.sh
   scripts/dispatch/adapters/backend/stub.sh
   ```

   For each file: loop with `grep -nE`, count matches, report. Report `PASS: bash32-compat N files clean` on green. Exit 0.

2. **Write `scripts/verify/m019-p01-no-pre-p00-emission.sh`** — SC-12 enforcement:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m019-p01-no-pre-p00-emission.sh — SC-12 ordering guard.
   #
   # Asserts no M019 emitter record exists in any post-M011 milestone's
   # execution-log.jsonl with a timestamp earlier than P00 SUMMARY's
   # completed_at (the P00->P01 ordering epoch).
   #
   # Epoch: 2026-04-18T02:21:28Z (from M019/P00/P00-SUMMARY.md completed_at).
   # Post-M011 milestones: M012 and above (M011 and earlier are explicitly
   # exempted per D009 — pre-M019 records are unlogged-on-purpose).
   #
   # Scans .orchestrator/milestones/M{012..}/execution-log.jsonl. For each
   # record carrying record_type in {payload_breakdown, dispatch_usage,
   # unit_close}, extracts the timestamp field and compares to the epoch.
   # FAIL if any record predates the epoch.
   #
   # Bash 3.2. MEM004 carve-out — awk permitted.
   set -u
   P00_EPOCH="2026-04-18T02:21:28Z"
   REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
   # Enumerate milestone dirs where the numeric suffix > 011
   # ...
   ```

   Implementation:
   - Use `ls .orchestrator/milestones/` + a bash loop that strips the `M` prefix and compares as integers.
   - For each milestone `M###` where `### > 11`: if `execution-log.jsonl` exists, awk-scan for M019 record_types + timestamp < epoch (string comparison works on ISO-8601 UTC timestamps).
   - `grep -E '"record_type":"(payload_breakdown|dispatch_usage|unit_close)"'` to filter, then extract `timestamp` via `grep -oE '"timestamp":"[^"]+"'`, compare lexically.
   - Exit 1 with a FAIL line naming the offending file + timestamp on any violation.

3. **Write `scripts/verify/m019-p01-fixture-rollup.sh`** — verification asset only (NOT a command):

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m019-p01-fixture-rollup.sh — SC-7 greppability demo.
   #
   # Parses tests/fixtures/m019-p01/post-m019-rollup-demo.jsonl, groups
   # records by granularity, sums estimated_cost_usd, prints a table.
   # Demonstrates that a future rollup script (Tier 2) can consume the
   # records without schema changes.
   #
   # THIS SCRIPT IS VERIFICATION-ONLY. It is NOT orchestrator:cost. It is
   # NOT scripts/diagnostics/metrics-rollup.sh. It does not install any
   # user-facing surface. Its sole purpose is to demonstrate SC-7 by
   # succeeding against the fixture.
   #
   # On green: prints three lines of the form
   #   ROLLUP: granularity=task      records=N  total_usd=X.XX
   #   ROLLUP: granularity=phase     records=N  total_usd=X.XX
   #   ROLLUP: granularity=milestone records=N  total_usd=X.XX
   # Plus PASS: m019-p01-fixture-rollup.sh and exit 0.
   set -u
   FIX="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tests/fixtures/m019-p01/post-m019-rollup-demo.jsonl"
   awk -F'"' '
     /"record_type":"unit_close"/ {
       gran=""
       for (i=1;i<=NF;i++) if ($i=="granularity") { gran=$(i+2); break }
       # ... sum estimated_cost_usd, ignore null
     }
     END { /* emit ROLLUP lines */ }
   ' "$FIX"
   echo "PASS: m019-p01-fixture-rollup.sh"
   ```

   Scope guard: the script MUST NOT write to any file outside its own stdout. No `.orchestrator/metrics/*.jsonl` creation. No `commands/cost.md` creation. If any Tier 2/3 artifact appears, the M019 scope discipline is broken.

4. **Write `scripts/verify/m019-p01-phase-suite.sh`** — mirror the P00 orchestrator at `scripts/verify/m019-p00-phase-suite.sh`:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m019-p01-phase-suite.sh — P01 phase integration gate.
   #
   # Orchestrates the eight P01 verify gates:
   #   1. m019-schema.sh (against fixture + live logs)
   #   2. m019-p01-emitter-presence.sh
   #   3. m019-p01-pricing-degradation.sh
   #   4. m019-p01-source-enum.sh
   #   5. m019-p01-zero-token-growth.sh
   #   6. m019-p01-fixture-rollup.sh
   #   7. m019-p01-additive-compat.sh
   #   8. m019-p01-no-pre-p00-emission.sh
   #   9. m019-p01-bash32-compat.sh
   # Reports PASS: N / FAIL: 0 summary. Exit 0 on green.
   set -u
   REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
   GATES="
   scripts/verify/m019-p01-emitter-presence.sh
   scripts/verify/m019-p01-pricing-degradation.sh
   scripts/verify/m019-p01-source-enum.sh
   scripts/verify/m019-p01-zero-token-growth.sh
   scripts/verify/m019-p01-fixture-rollup.sh
   scripts/verify/m019-p01-additive-compat.sh
   scripts/verify/m019-p01-no-pre-p00-emission.sh
   scripts/verify/m019-p01-bash32-compat.sh
   "
   # ... identical loop-and-report shape to P00's phase-suite
   ```

   The schema validator runs indirectly through the emitter-presence + source-enum gates; no separate suite entry needed. (Add one if preferred — both gate counts are acceptable as long as every named script runs.)

5. **Mark all new scripts executable** via `chmod +x`.

6. **Dry-run the full suite** against the post-T05 code state:

   ```
   bash scripts/verify/m019-p01-phase-suite.sh
   ```

   Expected: PASS: 8 / FAIL: 0, exit 0.

## Must-Haves

- `scripts/verify/m019-p01-phase-suite.sh` exits 0 on green.
- `scripts/verify/m019-p01-no-pre-p00-emission.sh` correctly detects a synthetic violation: inject a record with `timestamp: "2026-04-17T12:00:00Z"` into a fixture M012 log -> FAIL; remove -> PASS.
- `scripts/verify/m019-p01-fixture-rollup.sh` prints per-granularity cost totals from the fixture and exits 0. It creates no files outside its own stdout.
- `scripts/verify/m019-p01-bash32-compat.sh` scans all 15 listed files clean.
- The phase-suite script mirrors the P00 pattern (same output shape, same exit discipline).

## Verification

- `bash scripts/verify/m019-p01-phase-suite.sh` — exit 0.
- `bash scripts/verify/m019-p01-bash32-compat.sh` — exit 0 against every P01 file.
- `bash scripts/verify/m019-p01-no-pre-p00-emission.sh` — exit 0 against the live milestones tree (no post-M011 pre-P00 records exist).
- `bash scripts/verify/m019-p01-fixture-rollup.sh` — exit 0, prints ROLLUP: lines.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M019/phases/P01` — every Truth Check passes.

Scope-discipline confirmation (one-time manual, not a Check):
- Confirm no new file under `commands/*.md` was created.
- Confirm no new file under `scripts/diagnostics/metrics-rollup.sh` or similar.
- Confirm no new file under `.orchestrator/metrics/*.jsonl`.
- Confirm `scripts/verify/m019-p01-fixture-rollup.sh` writes to stdout only.
- Confirm the fixture-rollup is referenced by the phase-suite but never registered as an orchestrator command.

## Inputs

### From Previous Tasks

- All T01–T05 outputs: pricing lib, schema validator, three emitters, five per-gate scripts, fixtures, stub adapter.
- `tests/fixtures/m019-p01/post-m019-rollup-demo.jsonl` — source for the fixture-rollup gate.
- `tests/fixtures/m019-p01/pre-m019-execution-log.jsonl` — negative case for additive-compat (already consumed by T05's additive-compat gate).

### From Disk (Pre-existing)

- `scripts/verify/m019-p00-phase-suite.sh` — template to mirror. 51 lines. Same shape: iterate gates, report `PASS: N / FAIL: 0`, exit 0 on green.
- `scripts/verify/m019-p00-bash32-compat.sh` — template for the P01 bash32-compat scan. Reuse the M021/P04 split-needle self-match avoidance pattern per P00/T05 summary.
- [`.orchestrator/milestones/M019/phases/P00/P00-SUMMARY.md`](../../../../../milestones/M019/phases/P00/P00-SUMMARY.md) — `completed_at: "2026-04-18T02:21:28Z"` is the SC-12 epoch.
- `.orchestrator/milestones/M###/execution-log.jsonl` — scanned by the no-pre-p00-emission gate. Should be empty for M012 and above at P01 ship time.

## Constraints

- **SC-12 — P00→P01 ordering hard gate.** The no-pre-p00-emission script is the enforcement. Any M019 emitter record in any post-M011 milestone log with a timestamp before `2026-04-18T02:21:28Z` fails the gate.
- **SC-7 — Fixture-rollup is a verification asset, not a shipping surface.** No new user-facing command, no rollup script. The script's only externally-visible effect is its stdout during verify runs.
- **SC-9 / C5 — Bash 3.2.** All new files + all P01-touched files clean. Use the split-needle self-match avoidance pattern from M021/P04 when scanning for forbidden tokens.
- **MEM004 carve-out applies** — verify scripts permit pipes / `$()` / awk internally.
- **No agent-facing content.** All P01 code is infrastructure. Anti-pattern linter (`scripts/verify/anti-pattern-lint.sh`) should continue to exit 0 unchanged.
- **Single-script-file Check shape (AD-19).** Every Check in the phase plan references a single `scripts/verify/m019-p01-<name>.sh` invocation — no inline compound bash, no subshells, no `$()` with pipes.
- **Phase-suite mirrors P00 shape exactly** — same reporting format (`PASS: N / FAIL: M (of total gates)` + trailing `PASS: m019-p01-phase-suite.sh`). Keeps the operator muscle memory consistent.

## Expected Output

- Four new executable verify scripts under `scripts/verify/m019-p01-*.sh`.
- `bash scripts/verify/m019-p01-phase-suite.sh` reports `PASS: 8 / FAIL: 0 (of 8 P01 gates)` and `PASS: m019-p01-phase-suite.sh`, exit 0.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M019/phases/P01` — every Truth Check passes.
- No new `commands/*.md`, no new `scripts/diagnostics/metrics-*.sh`, no new `.orchestrator/metrics/*.jsonl`. Tier 1 scope held.
- M019/P01 ready for `orchestrator:verify` → `orchestrator:consolidate` and M019 closure.
