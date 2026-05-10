---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P05"
milestone: "M030"
name: "P05 phase-suite aggregator + recent-changes dual-write + commit"
depends_on: ["T02"]
---

## Prerequisites

- All T01/T02 deliverables on disk and green:
  - `bash tools/verify/p05-sc11-rollup-byte-equality.sh` exits 0 (T01)
  - `bash tools/verify/p05-sc11-footer-byte-equality.sh` exits 0 (T01)
  - `bash tools/verify/p05-doctor-config-check.sh` exits 0 (T01)
  - `bash tools/verify/p05-by-model-dispatch-counts.sh` exits 0 (T02)
  - `bash tools/verify/p05-by-model-cost-rates-present.sh` exits 0 (T02)
  - `bash tools/verify/p05-by-model-cost-rates-absent.sh` exits 0 (T02)
  - `bash tools/verify/p05-model-mix-footer-line.sh` exits 0 (T02)
- `scripts/util/dual-write-runtime-md.sh` exists (M014/[M021](../../../../../milestones/M021/index.md) deliverable; per CLAUDE.md "recent-changes" convention).
- `tools/verify/p04-phase-suite.sh` exists and exits 0 (P04 close — pattern reference).
- `tools/verify/p03-phase-suite.sh` exists and exits 0 (P03 close — pattern reference).
- `tools/verify/p02-phase-suite.sh` exists and exits 0 (P02 close — pattern reference).
- `CLAUDE.md` exists at repo root with the orchestrator:recent-changes region.
- `AGENTS.md` exists at repo root ([M014](../../../../../milestones/M014/index.md) dual-write target).

Plan-time prerequisite-existence verification: every path above is asserted by T01/T02 close.

## Description

T03 closes P05 with three deliverables:

1. **`tools/verify/p05-phase-suite.sh`** — straight-line aggregator over all seven P05 sub-gates. Same shape as `p02-phase-suite.sh` / `p03-phase-suite.sh` / `p04-phase-suite.sh`. Each sub-gate is invoked as a literal `bash <path>` statement; `pass`/`fail` accumulators update via `pass=$((pass+1))`/`fail=$((fail+1))` per `$?`. Final line: `SUMMARY: p05-phase-suite.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

2. **CLAUDE.md + AGENTS.md recent-changes dual-write** — append a single P05-close entry to the orchestrator:recent-changes region of both files via `scripts/util/dual-write-runtime-md.sh --append-entry`. Single-line entry summarizing the P05 deliverables.

3. **Stage + commit P05 close** — single commit including the phase-suite verifier, the CLAUDE.md+AGENTS.md edits, and any plan-side amendments needed to satisfy `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P05`. Plan-amendments-not-task-reopen pattern (per P02/T04 + P03/T04 + P04/T04 precedent) when the must-haves grep fails on artifact-grep or key-link-direction. Use `git commit -F /tmp/p05-t03-commit-msg.txt`.

After T03 commits, P05 is closed and the orchestrator state machine transitions to `summarized` for P05 (phase-summary still authored by `orchestrator:verify` + `orchestrator:consolidate` downstream).

### Phase-suite shape (load-bearing)

The aggregator is a straight-line script (no loops, no eval) per AD-19 + the P01-P04 phase-suite pattern. Seven literal sub-gate invocations; each captures `$?` immediately into a per-gate variable; pass/fail accumulators compute from those. Final SUMMARY line uses the canonical format.

```bash
#!/usr/bin/env bash
# tools/verify/p05-phase-suite.sh — Aggregator over P05 sub-gates.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0
fail=0

bash "$PROJECT_ROOT/tools/verify/p05-sc11-rollup-byte-equality.sh"
rc1=$?

bash "$PROJECT_ROOT/tools/verify/p05-sc11-footer-byte-equality.sh"
rc2=$?

bash "$PROJECT_ROOT/tools/verify/p05-doctor-config-check.sh"
rc3=$?

bash "$PROJECT_ROOT/tools/verify/p05-by-model-dispatch-counts.sh"
rc4=$?

bash "$PROJECT_ROOT/tools/verify/p05-by-model-cost-rates-present.sh"
rc5=$?

bash "$PROJECT_ROOT/tools/verify/p05-by-model-cost-rates-absent.sh"
rc6=$?

bash "$PROJECT_ROOT/tools/verify/p05-model-mix-footer-line.sh"
rc7=$?

if [ "$rc1" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
if [ "$rc2" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
if [ "$rc3" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
if [ "$rc4" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
if [ "$rc5" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
if [ "$rc6" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
if [ "$rc7" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

echo "SUMMARY: p05-phase-suite.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

Notes on shape:

- `set -uo pipefail` (NOT `set -e`) — `set -e` would abort on the first sub-gate failure before the SUMMARY line emitted; we want the suite to run all seven gates regardless of individual failures so the SUMMARY pass/fail count is accurate.
- Each sub-gate captures `$?` into a uniquely-named variable (`rc1`–`rc7`) before the next invocation.
- Seven separate `if [ "$rc<N>" -eq 0 ]; then ... fi` lines — straight-line shape per AD-19.
- The final exit branches on `fail`, not directly on `rc<N>`.

Sub-gate ordering (meaningful):

1. sc11-rollup-byte-equality (the fundamental SC-11 contract for the rollup surface)
2. sc11-footer-byte-equality (the fundamental SC-11 contract for the footer surface)
3. doctor-config-check (SC-9 contract via P01-inherited wrapper)
4. by-model-dispatch-counts (SC-8 first sentence — per-tier dispatch-count line)
5. by-model-cost-rates-present (SC-8 second sentence — aggregated cost + counterfactual when cost_rates: present)
6. by-model-cost-rates-absent (SC-8 third sentence — warning + zero-savings when cost_rates: absent)
7. model-mix-footer-line (FR-16 — model_mix: line on efficiency-footer)

If a gate fails, the SUMMARY line names how many of the seven passed, which makes the failure-class diagnosis fast.

### Plan-amendment-not-task-reopen pattern

When `scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P05` runs as part of the verify pipeline, it greps the phase plan's Artifacts and Key Links sections against the actual on-disk state. If a verifier passes but `check-must-haves.sh` fails on an artifact-grep mismatch (e.g., the artifact filename is on disk but the plan declares a slightly different "contains" pattern that doesn't appear), the resolution is a plan-side amendment — NOT a task re-open. Same precedent as P02/T04, P03/T04, P04/T04.

T03 runs `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P05` after the phase-suite passes; if it fails, T03 amends `P05-PLAN.md` (specifically the Artifacts section's `contains "..."` predicates) to match the actual on-disk shape.

### CLAUDE.md / AGENTS.md dual-write

The orchestrator's recent-changes convention pins one entry per phase close. The entry is single-line, summarizes deliverables + verification signal, and is appended to the `>>> orchestrator:recent-changes >>>` region. Both CLAUDE.md and AGENTS.md mirror the same content; `dual-write-runtime-md.sh --append-entry` writes both in one invocation.

The entry shape (load-bearing):

```
M030 P05 close: M027 surface integration — metrics-rollup.sh --by-model flag (FR-15/SC-8 — per-tier dispatch counts + aggregated cost + all-smart counterfactual when cost_rates: present; cost rates not configured warning + zero-savings when absent) + efficiency-footer.sh model_mix: line (FR-16 — fast=N balanced=M smart=K, suppressed when corpus has zero shadow-on records) + doctor --config-check inheritor wrapper (FR-17/SC-9 — P01/T04 surface re-confirmed) + references/model-routing.md ## Cost Rollup Surfaces section; CON-2/FR-19/SC-11 byte-equality preserved (golden-baseline diff against pre-M030 fixture); phase-suite green pass=7 fail=0
```

(Single line, no embedded newlines. The orchestrator's recent-changes region preserves entry order — newest first; `dual-write-runtime-md.sh` handles the placement automatically.)

## Steps

1. **Confirm T01/T02 deliverables are on disk and green.** Run all seven P05 sub-gates:

   ```bash
   bash tools/verify/p05-sc11-rollup-byte-equality.sh
   bash tools/verify/p05-sc11-footer-byte-equality.sh
   bash tools/verify/p05-doctor-config-check.sh
   bash tools/verify/p05-by-model-dispatch-counts.sh
   bash tools/verify/p05-by-model-cost-rates-present.sh
   bash tools/verify/p05-by-model-cost-rates-absent.sh
   bash tools/verify/p05-model-mix-footer-line.sh
   ```

   Expected: all seven exit 0. If any fail, the upstream task must be re-opened (T03 cannot proceed against red sub-gates).

2. **Author `tools/verify/p05-phase-suite.sh`** per the shape in the Description. Bash 3.2-compatible. Seven literal sub-gate invocations + per-gate rc capture + pass/fail accumulators + SUMMARY line. Mark executable: `chmod +x tools/verify/p05-phase-suite.sh`.

3. **Run the phase-suite as a self-check:**

   ```bash
   bash tools/verify/p05-phase-suite.sh
   ```

   Expected: exit 0 with `SUMMARY: p05-phase-suite.sh pass=7 fail=0`. If any sub-gate fails inside the suite but passes when invoked directly, investigate the suite's environment.

4. **Run `scripts/verify/check-must-haves.sh` against P05.**

   ```bash
   bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P05
   ```

   Expected: exits 0 with truths/artifacts/key-links all PASS. If artifact-grep predicates fail, apply the plan-amendment-not-task-reopen pattern: amend `P05-PLAN.md` Artifacts section to match the on-disk shape (NOT amend the deliverable to match the plan).

5. **Dual-write the recent-changes entry to CLAUDE.md + AGENTS.md.**

   ```bash
   bash scripts/util/dual-write-runtime-md.sh --marker recent-changes --append-entry "M030 P05 close: [M027](../../../../../milestones/M027/index.md) surface integration — metrics-rollup.sh --by-model flag (FR-15/SC-8 — per-tier dispatch counts + aggregated cost + all-smart counterfactual when cost_rates: present; cost rates not configured warning + zero-savings when absent) + efficiency-footer.sh model_mix: line (FR-16 — fast=N balanced=M smart=K, suppressed when corpus has zero shadow-on records) + doctor --config-check inheritor wrapper (FR-17/SC-9 — P01/T04 surface re-confirmed) + references/model-routing.md ## Cost Rollup Surfaces section; CON-2/FR-19/SC-11 byte-equality preserved (golden-baseline diff against pre-M030 fixture); phase-suite green pass=7 fail=0"
   ```

   Expected: the script reports successful append to both CLAUDE.md and AGENTS.md.

6. **Stage all P05 deliverables.** Stage:

   - `tests/fixtures/m030-p05/` (entire directory tree: `live-routed-corpus.jsonl`, `no-cost-rates-routing.yml`, `rollup-pre-m030-baseline.txt`, `footer-pre-m030-baseline.txt`, `synthesize-corpus.sh`)
   - `tools/verify/p05-*.sh` (8 files: 7 sub-gates + phase-suite)
   - `scripts/diagnostics/metrics-rollup.sh` (T02 amendment)
   - `scripts/diagnostics/efficiency-footer.sh` (T02 amendment)
   - `references/model-routing.md` (T02 amendment)
   - `CLAUDE.md` (recent-changes update)
   - `AGENTS.md` (recent-changes update)
   - [`.orchestrator/milestones/M030/phases/P05/P05-PLAN.md`](../../../../../milestones/M030/phases/P05/P05-PLAN.md) + `tasks/T0[1-3]-*-PLAN.md` (the plan files this task plan was authored from)
   - `tools/verify/p01-routing-table-shape.sh` if T01 amended it to make `cost_rates:` optional

   Use `git add <path>` per file; do NOT use `git add -A` or `git add .` to avoid accidental sensitive-file staging.

7. **Author the commit message file.** Write to `/tmp/p05-t03-commit-msg.txt` via the Write tool:

   ```
   M030/P05/T03: phase-suite + recent-changes dual-write + close

   T03 closes P05 with the straight-line phase-suite aggregator over all
   seven P05 sub-gates (sc11-rollup-byte-equality + sc11-footer-byte-equality
   + doctor-config-check + by-model-dispatch-counts + by-model-cost-rates-present
   + by-model-cost-rates-absent + model-mix-footer-line). Pass=7 fail=0
   against HEAD.

   The recent-changes dual-write (CLAUDE.md + AGENTS.md) appends the standard
   single-line P05-close entry summarizing the M027 surface integration:
   metrics-rollup --by-model flag (FR-15 / SC-8) with cost_rates-present and
   cost_rates-absent branches, efficiency-footer model_mix: line (FR-16) with
   suppression preserving SC-11 byte-equality on pre-M030 corpora, doctor
   --config-check inheritor wrapper (FR-17 / SC-9) re-confirming P01/T04
   surface, and references/model-routing.md ## Cost Rollup Surfaces section
   documenting the operator-facing shape and the cost_rates: update obligation.

   This commit also includes any plan-side amendments T03 needed to satisfy
   check-must-haves.sh per the plan-amendment-not-task-reopen pattern (P02/T04
   + P03/T04 + P04/T04 precedent) — amendments touch P05-PLAN.md artifact-grep
   predicates only, never the underlying deliverables.

   Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
   ```

8. **Commit with `git commit -F`:**

   ```bash
   git commit -F /tmp/p05-t03-commit-msg.txt
   ```

   Expected: clean commit; pre-commit hooks run + pass. If a pre-commit hook fails, investigate + fix + RE-STAGE + create a NEW commit (do NOT use `--amend` per the gitflow safety protocol).

9. **Post-commit verification.** Run:

   ```bash
   bash tools/verify/p05-phase-suite.sh
   bash scripts/state/derive-phase.sh .orchestrator/milestones/M030
   ```

   Expected: phase-suite re-runs green; `derive-phase.sh` reports the M030 state has advanced to `verified` for P05 (or `summarized` if `orchestrator:verify` has already run downstream).

## Must-Haves

This task satisfies the phase truth:

- "`bash tools/verify/p05-phase-suite.sh` invokes all seven P05 sub-gates ... emits `SUMMARY: p05-phase-suite.sh pass=N fail=M` ..." — gated by the suite itself when invoked.

T03 also discharges the phase-close obligations: recent-changes dual-write, plan-side amendments per the must-haves grep, single coherent commit. None of these are individually mechanically gated by a Tier 1 verifier; they are gated holistically by the verify pipeline's `scripts/verify/check-must-haves.sh` + the state-machine transition from `executing` to `verified`.

## Verification

```bash
bash tools/verify/p05-phase-suite.sh
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P05
```

Each command uses single-script-file shape per AD-19. Both must exit 0 before T03 closes.

## Inputs

### From Previous Tasks

- `tools/verify/p05-sc11-rollup-byte-equality.sh`, `p05-sc11-footer-byte-equality.sh`, `p05-doctor-config-check.sh` (from T01) — Key API: each `bash <path>` exits 0; `SUMMARY:` line emitted with pass-count.
- `tools/verify/p05-by-model-dispatch-counts.sh`, `p05-by-model-cost-rates-present.sh`, `p05-by-model-cost-rates-absent.sh`, `p05-model-mix-footer-line.sh` (from T02) — Key API: same shape as T01 verifiers.
- `scripts/diagnostics/metrics-rollup.sh` (post-T02) — amended with `--by-model` flag. T03 does not modify; included in the commit.
- `scripts/diagnostics/efficiency-footer.sh` (post-T02) — amended with `model_mix:` line block. T03 does not modify; included in the commit.
- `references/model-routing.md` (post-T02) — extended with `## Cost Rollup Surfaces` section. T03 does not modify; included in the commit.
- `tests/fixtures/m030-p05/*` (from T01) — fixture corpus + cost-rates-absent routing-table + golden baselines + synthesizer. Included in the commit.

### From Disk (Pre-existing)

- `scripts/util/dual-write-runtime-md.sh` — Key API: `bash <path> --marker recent-changes --append-entry "<message>"` appends a single-line entry to the orchestrator:recent-changes region of CLAUDE.md and (when present + dual_write_agents: true) AGENTS.md. M014/P01 FR-12 deliverable.
- `scripts/verify/check-must-haves.sh` — Key API: `bash <path> <phase-dir>` reads the phase plan's Truths / Artifacts / Key Links sections and verifies each against the on-disk state. Exit 0 iff all checks pass.
- `scripts/state/derive-phase.sh` — Key API: `bash <path> <milestone-dir>` reports the orchestrator-state-machine state for the milestone. Used post-commit to confirm the phase advanced to `verified`.
- `CLAUDE.md`, `AGENTS.md` — runtime-instruction files at repo root with the orchestrator:recent-changes region. Dual-write target.
- `tools/verify/p02-phase-suite.sh`, `p03-phase-suite.sh`, `p04-phase-suite.sh` — pattern reference. T03's `p05-phase-suite.sh` mirrors this shape (straight-line aggregator, no loops, seven literal sub-gate invocations).

## Constraints

- **AD-19 single-script-file shape**: phase-suite is a single script invoking seven sub-gate scripts. Aggregation logic is straight-line (no loops, no eval).
- **AP-008 heredoc-with-expansion (commit shape)**: commit message MUST be authored to a file via Write and committed with `git commit -F <file>`. Inline `git commit -m "$(cat <<'EOF' ... EOF)"` form is forbidden per CLAUDE.md commit-authoring guidance.
- **AP-009 compound-chain-gt2**: phase-suite uses single-line `bash <path>` invocations + per-gate rc capture. No `cmd1 | cmd2 | cmd3` or `cmd1 && cmd2 && cmd3` chains.
- **Plan-amendment-not-task-reopen**: when must-haves grep fails on artifact-grep, the resolution is a plan-side amendment (P05-PLAN.md), not a task re-open. Same precedent as P02/T04 + P03/T04 + P04/T04.
- **Single commit for P05 close**: T03 produces ONE commit covering the phase-suite verifier + CLAUDE.md/AGENTS.md update + any plan-side amendments. Multiple commits during T03 are acceptable iff a pre-commit hook fails on the first attempt.
- **Bash 3.2 compatibility**: phase-suite uses no `declare -A`, no `mapfile`, no `readarray`. Per-gate rc capture uses unique variable names (`rc1`–`rc7`).
- **Plan-Time Discipline rule 5 (real-DB verification)**: T03 introduces no SQL — N/A.

## Expected Output

- `tools/verify/p05-phase-suite.sh` — green: 7 sub-gates pass; `SUMMARY: p05-phase-suite.sh pass=7 fail=0`.
- `CLAUDE.md` + `AGENTS.md` — both contain the new P05-close recent-changes entry (single line, summarizes deliverables + verification signal).
- One git commit covering the phase-suite verifier + CLAUDE.md/AGENTS.md update (+ optional plan-side amendments to P05-PLAN.md per must-haves grep). Commit message authored via `git commit -F /tmp/p05-t03-commit-msg.txt`.
- `bash tools/verify/p05-phase-suite.sh` exits 0 with `SUMMARY: p05-phase-suite.sh pass=7 fail=0`.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P05` exits 0 with all truths / artifacts / key-links PASS.
- `bash scripts/state/derive-phase.sh .orchestrator/milestones/M030` reports state has advanced to `verified` (or `summarized` if `orchestrator:verify` has run).

## Notes

Expected output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p05-phase-suite.sh` → 7 sub-gates run; `SUMMARY: p05-phase-suite.sh pass=7 fail=0`, exit 0.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P05` → truths/artifacts/key-links all PASS; exit 0.

The phase-suite shape is the same straight-line aggregator P01-P04 used. The seven sub-gates are arranged in a meaningful sequence: SC-11 byte-equality (rollup + footer) first as the fundamental contracts, then the SC-9 doctor inheritor, then the four T02 scenario-specific gates (SC-8 × 3 + FR-16). If a gate fails, the SUMMARY line names how many of the seven passed, which makes the failure-class diagnosis fast.

If `dual-write-runtime-md.sh` reports an issue (e.g., `>>> orchestrator:recent-changes >>>` region missing from CLAUDE.md), the resolution is to manually authorize the region's existence first via `scripts/util/dual-write-runtime-md.sh --init-region` (per M014/M021 convention) and then re-run the append. This should not happen in P05 because the region exists per the recent-changes block visible at the top of CLAUDE.md (the P04 close entry is already present there).

If the post-commit `derive-phase.sh` reports a state other than `verified` or `summarized`, investigate which file is missing or unexpectedly present in `.orchestrator/milestones/M030/phases/P05/`. The state machine derives from disk — common causes are a missing T0N-SUMMARY.md (executing → not advanced) or a stale lock file. T03 does NOT author summaries; that is `orchestrator:verify` + `orchestrator:consolidate` downstream territory. The acceptable post-T03 state is `executing → verified` (verify ran inline) or `executing` itself (verify will run as a separate dispatch).

The single P05-close commit lands all P05 deliverables atomically. Downstream `orchestrator:verify` reads HEAD to verify the phase; HEAD is the post-T03 commit. If the verify dispatch finds gaps (e.g., a plan-side amendment was needed but not made), it surfaces via the verify-failure path, NOT via re-opening T03 — same plan-amendment-not-task-reopen pattern.

The `--marker recent-changes` flag on `dual-write-runtime-md.sh` is the M014/M021 convention for selecting the named region; older invocations may have used positional arguments. Per the P03/T04 + P04/T04 commit messages in the recent-changes block, the explicit `--marker` flag is the current canonical shape.
