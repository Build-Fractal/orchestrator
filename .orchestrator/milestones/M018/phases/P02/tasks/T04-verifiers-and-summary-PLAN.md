---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M018"
name: "Phase verifiers + dual-write recent-changes + P02-SUMMARY"
depends_on: ["T03"]
---

## Prerequisites

- T01 has landed `scripts/lib/preservation-check.sh`.
- T02 has wired the knowledge filter into `scripts/dispatch/build-context.sh`, added the `compression:` block to `.orchestrator/config.yml` and `templates/config-defaults.yml`, created `tests/fixtures/m018-p02-knowledge-status/`, and captured the baseline golden at `tests/fixtures/m018-p02-baseline-payload.golden.txt`.
- T03 has added the aggregate-savings self-check + `compression.underperformance.*` config keys.
- All three upstream task summaries exist (T01-SUMMARY, T02-SUMMARY, T03-SUMMARY) so the P02-SUMMARY can synthesize from them.
- `scripts/util/dual-write-runtime-md.sh` exists and is the canonical mechanism for mirroring CLAUDE.md edits to AGENTS.md (per CLAUDE.md guidance + AGENTS.md dual-write convention from M014/P01 FR-12).

## Description

Ship every phase-truth verifier the P02-PLAN.md `## Truths` section names (six verifiers under `scripts/verify/m018-p02-*.sh`). Refresh the `orchestrator:recent-changes` block in `CLAUDE.md` to name M018/P02; mirror to `AGENTS.md` via the dual-write helper. Write `P02-SUMMARY.md` so the milestone state advances to ready-for-P03.

The verifier set:

1. **`m018-p02-filter-drops.sh`** — verifies the knowledge-aware filter drops drop-list-matching entries; retains missing-status entries (back-compat).
2. **`m018-p02-emitter-additivity.sh`** — verifies the `payload_filter` JSONL record is emitted; the `payload_breakdown` record carries `filter_dropped_tokens`; pre-M018 records remain valid JSON.
3. **`m018-p02-preservation-check-api.sh`** — verifies the T01 library is sourceable, exposes the three required functions, and the `selftest` entry point passes.
4. **`m018-p02-underperformance-emit.sh`** — verifies the underperformance self-check emits a `compression_underperformance` record on a synthetic underperforming log.
5. **`m018-p02-disable-flag-honored.sh`** — verifies `compression.enabled: false` short-circuits the filter; payload Knowledge bytes match the checked-in golden.
6. **`m018-p02-dual-write-recent.sh`** — verifies CLAUDE.md and AGENTS.md `recent-changes` blocks both name M018/P02.

Every verifier is single-script-file shape per AD-19 (no inline compound bash, no plain subshells, no `$(...|...)`), bash 3.2 compatible, exits 0 on PASS, 1 on FAIL with `FAIL:` diagnostics.

## Steps

1. **Author `scripts/verify/m018-p02-filter-drops.sh`**. Shape:

   - Shebang `#!/usr/bin/env bash`, `set -eu`.
   - Resolve `PROJECT_ROOT` (use the same idiom as the M018/P01 verifiers — `cd "$(dirname "$0")/../.."` then `pwd`).
   - Run `bash scripts/dispatch/build-context.sh --fixture tests/fixtures/m018-p02-knowledge-status` against the fixture; redirect stdout to a temp file.
   - Assert the output contains `MEM` IDs from the retained-status entries (2 stable + 1 missing-status = 3 retained MEMs).
   - Assert the output does NOT contain the MEM IDs from the drop-list-matching entries (1 superseded + 1 experimental).
   - The fixture's README documents which MEM IDs are which; the verifier hardcodes the expected retain/drop sets from the fixture (e.g., retain MEM801/802/805, drop MEM803/804).
   - PASS prints `PASS: m018-p02-filter-drops`; FAIL prints `FAIL: <reason>` and exits 1.
   - ~50–80 lines.

2. **Author `scripts/verify/m018-p02-emitter-additivity.sh`**. Shape:

   - Run `bash scripts/dispatch/build-context.sh --fixture tests/fixtures/m018-p02-knowledge-status` against the fixture (or against a fixture's milestone dir directly so `execution-log.jsonl` lands in a known place).
   - Assert the resulting execution log contains a line matching `"record_type":"payload_filter"`.
   - Assert the same log contains a line matching `"record_type":"payload_breakdown"` AND the same line contains `"filter_dropped_tokens"`.
   - Validate JSON-shape additivity: pipe both record types through `python3 -c 'import sys, json; [json.loads(l) for l in sys.stdin]'` if python3 is available; otherwise use a bash-only JSON-shape sniff (assert each line starts with `{` and ends with `}`).
   - Assert there is at least one *pre-M018* `payload_breakdown` record in the historical log under `.orchestrator/milestones/M018/execution-log.jsonl` that does NOT contain `filter_dropped_tokens` and is still well-formed JSON (CON-5 back-compat).
   - PASS / FAIL as above. ~60–90 lines.

3. **Author `scripts/verify/m018-p02-preservation-check-api.sh`**. Shape:

   - Source `scripts/lib/preservation-check.sh` in a child process (NOT in the verifier's own shell — the verifier must remain sourceable-test-isolated). Use `bash -c '. scripts/lib/preservation-check.sh; type pres_check_section pres_emit_violation pres_density_pre_check'`. (Note: this is a single `bash -c` invocation — single command, AP-009 safe; the embedded `. file ; type ...` is two statements separated by `;` which is one compound under the AP-009 limit of 2.)

     **Alternative AP-009-clean shape** (preferred): write a small helper script under `scripts/verify/_helpers/m018-p02-pres-probe.sh` that the verifier invokes as a single command. The helper sources the library and runs `type` checks. This is the cleanest shape — the verifier itself stays a single-script-file invocation.

   - Run `bash scripts/lib/preservation-check.sh selftest`; assert exit 0 + stdout contains `PASS: pres_check_section selftest`.
   - Assert the library file contains the literal `pres_check_section`, `pres_emit_violation`, `pres_density_pre_check` (function definitions).
   - Assert the file contains the `PRES_PATTERNS_REGEX` array declaration (`grep -q 'PRES_PATTERNS_REGEX=(`).
   - PASS / FAIL as above. ~40–60 lines.

4. **Author `scripts/verify/m018-p02-underperformance-emit.sh`**. Shape:

   - Construct a synthetic execution log under a temp dir with 30 `payload_breakdown` records each carrying low `filter_dropped_tokens` (e.g., 5 tokens against 100-token payload — well below the 34.7% floor).
   - Set `ORCH_ROOT` to the temp dir; invoke the underperformance function directly by sourcing build-context's helper logic OR by running build-context end-to-end against a fixture milestone whose log we pre-seed.

     **Recommended approach**: pre-seed `<tmp>/milestones/M999/execution-log.jsonl` with 30 records; run `build-context.sh` against the M999 fixture; assert a new line in `execution-log.jsonl` matches `"record_type":"compression_underperformance"`.

   - Assert the emitted record carries `running_mean_pct` < 34.7 and `floor_pct` = 34.7 and `sample_size` >= 10.
   - PASS / FAIL as above. ~70–100 lines.

5. **Author `scripts/verify/m018-p02-disable-flag-honored.sh`**. Shape:

   - Run `build-context.sh --fixture tests/fixtures/m018-p02-knowledge-status` once with `compression.enabled: true` (default) and capture the Knowledge section.
   - Run again with the disable flag — set via a temporary config override file or via an env var the build-context already honors. The simplest approach: write a temp `.orchestrator/config.yml` with `compression.enabled: false`, point `ORCH_ROOT` at the temp dir, and run.
   - Extract just the Knowledge section from the disabled-run output (`awk '/^## Knowledge/,/^## /'`); diff against `tests/fixtures/m018-p02-baseline-payload.golden.txt`.
   - Assert the diff is empty.
   - Assert the disabled-run's `execution-log.jsonl` contains NO `payload_filter` record.
   - PASS / FAIL as above. ~50–80 lines.

6. **Author `scripts/verify/m018-p02-dual-write-recent.sh`**. Shape:

   - Read CLAUDE.md and AGENTS.md.
   - Use `awk` to extract the `orchestrator:recent-changes` block (between `# >>> orchestrator:recent-changes >>>` and `# <<< orchestrator:recent-changes <<<`) from each.
   - Assert each block contains the literal `M018/P02`.
   - PASS / FAIL as above. ~25–40 lines.

7. **Refresh `CLAUDE.md`** `orchestrator:recent-changes` block. Read the current block; replace its single bullet with two bullets naming P01 close and P02 close. Final shape (the exact wording matches existing P01/P02 phrasing patterns):

   ```
   # >>> orchestrator:recent-changes >>>
   - 030-context-compression-layer / M018/P01: compression-grammar contract v1.0.1 Reviewed; conversus --strict gate PASS.
   - 030-context-compression-layer / M018/P02: knowledge-aware filter live in build-context.sh; preservation-check library shipped; payload_filter + filter_dropped_tokens emitters additive (CON-5); compression_underperformance self-check operational.
   # <<< orchestrator:recent-changes <<<
   ```

   Use `Edit` with `replace_all: false` and a sufficiently unique `old_string` to scope to the block.

8. **Run dual-write to mirror to AGENTS.md**:

   ```
   bash scripts/util/dual-write-runtime-md.sh
   ```

   This is the only mechanism for editing AGENTS.md. Never edit AGENTS.md directly. After the helper runs, AGENTS.md's `orchestrator:recent-changes` block matches CLAUDE.md's.

9. **Write `P02-SUMMARY.md`** at `.orchestrator/milestones/M018/phases/P02/P02-SUMMARY.md`. Use the existing P01-SUMMARY.md as a shape reference. Frontmatter (15-field base + `observability_surfaces`):

   ```yaml
   ---
   schema_version: "1.0"
   type: phase-summary
   id: P02
   parent: M018
   milestone: M018
   provides: "knowledge-aware injection filter live in scripts/dispatch/build-context.sh; preservation-contract self-check library scripts/lib/preservation-check.sh (sourceable: pres_check_section / pres_emit_violation / pres_density_pre_check); payload_filter JSONL record schema; payload_breakdown.filter_dropped_tokens additive field; compression_underperformance JSONL record (operational signal); compression.knowledge_filter.* + compression.underperformance.* config keys; six P02-private truth verifiers + tests/fixtures/m018-p02-knowledge-status fixture + golden baseline; CLAUDE.md/AGENTS.md recent-changes refresh"
   requires: "P01 grammar contract Reviewed; P00 SC-9 calibrated 34.7% floor; M020 status: field on knowledge entries (DEP-1)"
   affects: "P03 (T1 microcompact — sources scripts/lib/preservation-check.sh; reuses tier_preservation_violation + payload_breakdown schema); P04 (T2 snip — same lib + per-tier savings field); P05 (eval harness — reads compression_underperformance + payload_filter + future tier_preservation_violation records); P06 (T3 auto-compact — wires pres_density_pre_check before LLM call per MIT-08; tier-3-savings field additive)"
   key_files: "scripts/lib/preservation-check.sh;scripts/dispatch/build-context.sh;.orchestrator/config.yml;templates/config-defaults.yml;tests/fixtures/m018-p02-knowledge-status/;tests/fixtures/m018-p02-baseline-payload.golden.txt;scripts/verify/m018-p02-filter-drops.sh;scripts/verify/m018-p02-emitter-additivity.sh;scripts/verify/m018-p02-preservation-check-api.sh;scripts/verify/m018-p02-underperformance-emit.sh;scripts/verify/m018-p02-disable-flag-honored.sh;scripts/verify/m018-p02-dual-write-recent.sh"
   key_decisions: "Filter operates on whole-entry granularity per grammar contract (no interior preservation check); preservation-check library sourced defensively in build-context.sh so P03/P04/P06 inherit a working source path; filter is awk-driven for speed + AP-009 compliance; underperformance check is operational signal (never blocks dispatch); P02-stage logs may legitimately fall below the floor (tier1/2/3 not yet shipped) — handled via min_sample_size guard"
   patterns_established: "Sourceable lib pattern under scripts/lib/ for cross-tier reuse (T01); awk-driven entry-boundary detection in bash 3.2 stream filters (T02); additive JSONL emitter pattern with stats-file handoff between collector and emitter (T02); operational-signal JSONL records that never block dispatch (T03); fixture milestone + golden-payload diff pattern for compression-disabled regression (T02 + T04)"
   drill_down_paths: ".orchestrator/milestones/M018/phases/P02/tasks/T01-preservation-check-lib-SUMMARY.md;.orchestrator/milestones/M018/phases/P02/tasks/T02-knowledge-filter-SUMMARY.md;.orchestrator/milestones/M018/phases/P02/tasks/T03-underperformance-emitter-SUMMARY.md;.orchestrator/milestones/M018/phases/P02/tasks/T04-verifiers-and-summary-SUMMARY.md"
   duration: "<filled at close>"
   verification_result: pass
   observability_surfaces: "execution-log.jsonl: payload_filter record_type, payload_breakdown.filter_dropped_tokens additive field, compression_underperformance record_type"
   completed_at: "<filled at close>"
   ---
   ```

   Body sections:
   - `## Closure summary` — narrative paragraph naming what shipped and the dogfood inflection point.
   - `## Risk-mitigation traceability` — name MIT-08, MIT-09, MIT-10 each with the file/function that satisfies it.
   - `## Followups for downstream phases` — pointers per P03/P04/P05/P06 to the lib/emitter they will reuse.
   - `## Verification result` — `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P02/` exit 0; six P02-private verifiers all PASS.

10. **Run `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P02/`** as the final gate. Expect every truth's Check to pass, every artifact's existence + line count + grep pattern to pass, every key link to resolve.

## Must-Haves

This task addresses the phase truths:

- All six phase-truth Check commands resolve to a script under `scripts/verify/m018-p02-*.sh` and each script exits 0 on a successful M018 build.
- CLAUDE.md and AGENTS.md `recent-changes` blocks both name M018/P02. (Verified by `bash scripts/verify/m018-p02-dual-write-recent.sh`.)
- `.orchestrator/milestones/M018/phases/P02/P02-SUMMARY.md` exists with `verification_result: pass` and references all four task summaries.

## Verification

```
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P02/
```

Expected: every truth, artifact, and key link reports PASS. Exit 0. Phase state advances from `executing` to `verifying` on the next `derive-phase.sh` call.

## Inputs

### From Previous Tasks

- `scripts/lib/preservation-check.sh` (from T01)
  - Verified by `m018-p02-preservation-check-api.sh`. The verifier confirms the three function names, the `PRES_PATTERNS_REGEX` array, and the `selftest` entry point.

- `scripts/dispatch/build-context.sh` (modified by T02 + T03)
  - Verified by `m018-p02-filter-drops.sh`, `m018-p02-emitter-additivity.sh`, `m018-p02-disable-flag-honored.sh`, `m018-p02-underperformance-emit.sh` (collectively).

- `tests/fixtures/m018-p02-knowledge-status/` (created by T02)
  - Used as the test substrate for `m018-p02-filter-drops.sh` and `m018-p02-emitter-additivity.sh` and `m018-p02-disable-flag-honored.sh`. Documents which MEM IDs carry which `status:` values; the verifiers hardcode the expected retain/drop sets.

- `tests/fixtures/m018-p02-baseline-payload.golden.txt` (created by T02)
  - The byte-identical baseline `m018-p02-disable-flag-honored.sh` diffs against.

- `.orchestrator/config.yml` (modified by T02 + T03)
  - The `compression:` block T02 added and the `compression.underperformance:` block T03 extended both ship to disk under `.orchestrator/config.yml` and `templates/config-defaults.yml`.

### From Disk (Pre-existing)

- `scripts/util/dual-write-runtime-md.sh` — the canonical dual-write helper. T04 invokes it after editing CLAUDE.md.
- `scripts/verify/check-must-haves.sh` — the phase-level verifier; reads the phase plan's `## Must-Haves` section and runs every Check. T04's last action.
- `templates/phase-summary.md` — the schema source for the P02-SUMMARY frontmatter (15-field base + `observability_surfaces`).
- The existing P01-SUMMARY at `.orchestrator/milestones/M018/phases/P01/P01-SUMMARY.md` — shape reference; matches frontmatter / section ordering / risk-mitigation traceability layout.

## Constraints

- **AD-19 single-script-file shape on every verifier**. No inline `( . scripts/lib/foo.sh && fn )` subshells in any verifier. The preservation-check API probe uses a separate helper script under `scripts/verify/_helpers/` if needed (or `bash -c` with sequential statements).
- **AP-009 / pre-bash-shape-guard**. Compound chains > 2 are banned; verifiers use sequential statements + temp files.
- **Bash 3.2 compatibility (MEM001)**. No associative arrays, no `mapfile`, no `[[ =~ ]]` requiring extended flags.
- **AGENTS.md dual-write convention** — T04 edits CLAUDE.md directly, then runs `scripts/util/dual-write-runtime-md.sh`. NEVER edit AGENTS.md directly.
- **No new emitter schema in T04** — the emitter additions all landed in T02 + T03. T04 only verifies them.
- **No regression on the M018/P01 verifier set** — T04's verifiers must coexist with the six M018/P01 verifiers; the `check-must-haves.sh` invocation against the P02 phase dir reads the P02-PLAN.md only and does not interfere with P01's verifier names.

## Expected Output

- Six new files under `scripts/verify/m018-p02-*.sh`, all executable, all bash 3.2 compatible, all AD-19 / AP-009 compliant.
- `CLAUDE.md` updated `orchestrator:recent-changes` block.
- `AGENTS.md` mirrored via `dual-write-runtime-md.sh`.
- `.orchestrator/milestones/M018/phases/P02/P02-SUMMARY.md` written with frontmatter + closure-summary + risk-mitigation traceability + followups + verification-result sections.
- Final gate: `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P02/` exits 0 with PASS on every truth, artifact, and key link.
