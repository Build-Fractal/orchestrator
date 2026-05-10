---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M030"
name: "P04 phase-suite aggregator + recent-changes dual-write + commit"
depends_on: ["T03"]
---

## Prerequisites

- All T01/T02/T03 deliverables on disk and green:
  - `bash tools/verify/p04-additive-schema.sh` exits 0 (T01)
  - `bash tools/verify/p04-override-source-enum-extended.sh` exits 0 (T01 → T02 strict)
  - `bash tools/verify/p04-sc2a-shadow-gate-block.sh` exits 0 (T02)
  - `bash tools/verify/p04-sc3-live-mechanical.sh` exits 0 (T02)
  - `bash tools/verify/p04-partial-flip-routing.sh` exits 0 (T02)
  - `bash tools/verify/p04-con3-live-closure.sh` exits 0 (T02)
  - `bash tools/verify/p04-con4-live-killswitch.sh` exits 0 (T02)
  - `bash tools/verify/p04-sc4-escalation-sequence.sh` exits 0 (T03)
  - `bash tools/verify/p04-sc5-escalation-cap.sh` exits 0 (T03)
  - `bash tools/verify/p04-con5-no-fourth-record.sh` exits 0 (T03)
  - `bash tools/verify/p04-con6-prior-records-bit-identical.sh` exits 0 (T03)
  - `bash tools/verify/p04-escalation-fields-enum.sh` exits 0 (T03)
- scripts/util/dual-write-runtime-md.sh exists (M014/[M021](../../../../../milestones/M021/index.md) deliverable; per CLAUDE.md "recent-changes" convention).
- tools/verify/p03-phase-suite.sh exists and exits 0 (P03 close — pattern reference).
- tools/verify/p02-phase-suite.sh exists and exits 0 (P02 close — pattern reference).
- CLAUDE.md exists at repo root with the orchestrator:recent-changes region.
- AGENTS.md exists at repo root ([M014](../../../../../milestones/M014/index.md) dual-write target).

Plan-time prerequisite-existence verification: every path above is asserted by T01/T02/T03 close.

## Description

T04 closes P04 with three deliverables:

1. **`tools/verify/p04-phase-suite.sh`** — straight-line aggregator over all twelve P04 sub-gates. Same shape as `p02-phase-suite.sh` and `p03-phase-suite.sh`. Each sub-gate is invoked as a literal `bash <path>` statement; `pass`/`fail` accumulators update via `pass=$((pass+1))`/`fail=$((fail+1))` per `$?`. Final line: `SUMMARY: p04-phase-suite.sh pass=N fail=M`. Exit 0 iff `fail == 0`.

2. **CLAUDE.md + AGENTS.md recent-changes dual-write** — append a single P04-close entry to the orchestrator:recent-changes region of both files via `scripts/util/dual-write-runtime-md.sh --append-entry`. Single-line entry summarizing the P04 deliverables.

3. **Stage + commit P04 close** — single commit including the phase-suite verifier, the CLAUDE.md+AGENTS.md edits, and any plan-side amendments needed to satisfy `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P04`. Plan-amendments-not-task-reopen pattern (per P02/T04 + P03/T04 precedent) when the must-haves grep fails on artifact-grep or key-link-direction. Use `git commit -F /tmp/p04-t04-commit-msg.txt`.

After T04 commits, P04 is closed and the orchestrator state machine transitions to `summarized` for P04 (phase-summary still authored by `orchestrator:verify` + `orchestrator:consolidate` downstream).

### Phase-suite shape (load-bearing)

The aggregator is a straight-line script (no loops, no eval) per AD-19 + the P01/P02/P03 phase-suite pattern. Twelve literal sub-gate invocations; each captures `$?` immediately into a per-gate variable; pass/fail accumulators compute from those. Final SUMMARY line uses the canonical format.

```bash
#!/usr/bin/env bash
# tools/verify/p04-phase-suite.sh — Aggregator over P04 sub-gates.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0
fail=0

bash "$PROJECT_ROOT/tools/verify/p04-additive-schema.sh"
rc1=$?

bash "$PROJECT_ROOT/tools/verify/p04-override-source-enum-extended.sh"
rc2=$?

bash "$PROJECT_ROOT/tools/verify/p04-con3-live-closure.sh"
rc3=$?

bash "$PROJECT_ROOT/tools/verify/p04-sc2a-shadow-gate-block.sh"
rc4=$?

bash "$PROJECT_ROOT/tools/verify/p04-sc3-live-mechanical.sh"
rc5=$?

bash "$PROJECT_ROOT/tools/verify/p04-partial-flip-routing.sh"
rc6=$?

bash "$PROJECT_ROOT/tools/verify/p04-con4-live-killswitch.sh"
rc7=$?

bash "$PROJECT_ROOT/tools/verify/p04-sc4-escalation-sequence.sh"
rc8=$?

bash "$PROJECT_ROOT/tools/verify/p04-sc5-escalation-cap.sh"
rc9=$?

bash "$PROJECT_ROOT/tools/verify/p04-con5-no-fourth-record.sh"
rc10=$?

bash "$PROJECT_ROOT/tools/verify/p04-con6-prior-records-bit-identical.sh"
rc11=$?

bash "$PROJECT_ROOT/tools/verify/p04-escalation-fields-enum.sh"
rc12=$?

if [ "$rc1" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
if [ "$rc2" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
if [ "$rc3" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
if [ "$rc4" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
if [ "$rc5" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
if [ "$rc6" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
if [ "$rc7" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
if [ "$rc8" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
if [ "$rc9" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
if [ "$rc10" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
if [ "$rc11" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
if [ "$rc12" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

echo "SUMMARY: p04-phase-suite.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

Notes on shape:

- `set -uo pipefail` (NOT `set -e`) — `set -e` would abort on the first sub-gate failure before the SUMMARY line emitted; we want the suite to run all twelve gates regardless of individual failures so the SUMMARY pass/fail count is accurate.
- Each sub-gate captures `$?` into a uniquely-named variable (`rc1` through `rc12`) before the next invocation.
- Twelve separate `if [ "$rc<N>" -eq 0 ]; then ... fi` lines — straight-line shape per AD-19.
- The final exit branches on `fail`, not directly on `rc<N>`.

Sub-gate ordering (meaningful):

1. additive-schema (the fundamental SC-11 contract)
2. override-source-enum-extended (the schema gate)
3. con3-live-closure (the no-new-model-IDs invariant)
4. sc2a-shadow-gate-block (load-bearing live-flip-gate behavior)
5. sc3-live-mechanical (live-routed happy path)
6. partial-flip-routing (D-A3 partial-flip safety)
7. con4-live-killswitch (kill-switch supersedes live)
8. sc4-escalation-sequence (escalation happy path)
9. sc5-escalation-cap (CON-5 cap)
10. con5-no-fourth-record (CON-5 hard-cap defence-in-depth)
11. con6-prior-records-bit-identical (CON-6 append-only)
12. escalation-fields-enum (escalation_count + escalation_reason schema gate)

If a gate fails, the SUMMARY line names how many of the twelve passed, which makes the failure-class diagnosis fast.

### Plan-amendment-not-task-reopen pattern

When `scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P04` runs as part of the verify pipeline, it greps the phase plan's Artifacts and Key Links sections against the actual on-disk state. If a verifier passes but `check-must-haves.sh` fails on an artifact-grep mismatch (e.g., the artifact filename is on disk but the plan declares a slightly different "contains" pattern that doesn't appear), the resolution is a plan-side amendment — NOT a task re-open. Same precedent as P02/T04 and P03/T04.

T04 runs `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P04` after the phase-suite passes; if it fails, T04 amends `P04-PLAN.md` (specifically the Artifacts section's `contains "..."` predicates) to match the actual on-disk shape.

### CLAUDE.md / AGENTS.md dual-write

The orchestrator's recent-changes convention pins one entry per phase close. The entry is single-line, summarizes deliverables + verification signal, and is appended to the `>>> orchestrator:recent-changes >>>` region. Both CLAUDE.md and AGENTS.md mirror the same content; `dual-write-runtime-md.sh --append-entry` writes both in one invocation.

The entry shape (load-bearing):

```
M030 P04 close: dispatch-interface live-routing branch (FR-9 programmatic flip-gate via shadow-compare invocation per D-A2; per-class partial-flip authorization per D-A3; --model passing through to backend) + verifier-fail escalation loop (FR-10 fast→balanced→smart with CON-5 hard-cap=2 / 3 records max + escalation_cap_hit on cap) + 2 new JSONL fields (escalation_count, escalation_reason) + 1 new record_type (escalation_cap_hit) + sixth override_source value (shadow_gate_blocked) wired through; CON-4/D-A5 kill-switch supersedes live-mode (live: true is inactive warning); CON-6 append-only preserved (inode + head-2 hash); SC-11 byte-equality preserved; phase-suite green pass=12 fail=0
```

(Single line, no embedded newlines. The orchestrator's recent-changes region preserves entry order — newest first; `dual-write-runtime-md.sh` handles the placement automatically.)

## Steps

1. **Confirm T01/T02/T03 deliverables are on disk and green.** Run all twelve P04 sub-gates:

   ```bash
   bash tools/verify/p04-additive-schema.sh
   bash tools/verify/p04-override-source-enum-extended.sh
   bash tools/verify/p04-con3-live-closure.sh
   bash tools/verify/p04-sc2a-shadow-gate-block.sh
   bash tools/verify/p04-sc3-live-mechanical.sh
   bash tools/verify/p04-partial-flip-routing.sh
   bash tools/verify/p04-con4-live-killswitch.sh
   bash tools/verify/p04-sc4-escalation-sequence.sh
   bash tools/verify/p04-sc5-escalation-cap.sh
   bash tools/verify/p04-con5-no-fourth-record.sh
   bash tools/verify/p04-con6-prior-records-bit-identical.sh
   bash tools/verify/p04-escalation-fields-enum.sh
   ```

   Expected: all twelve exit 0. If any fail, the upstream task must be re-opened (T04 cannot proceed against red sub-gates).

2. **Author `tools/verify/p04-phase-suite.sh`** per the shape in the Description. Bash 3.2-compatible. Twelve literal sub-gate invocations + per-gate rc capture + pass/fail accumulators + SUMMARY line. Mark executable: `chmod +x tools/verify/p04-phase-suite.sh`.

3. **Run the phase-suite as a self-check:**

   ```bash
   bash tools/verify/p04-phase-suite.sh
   ```

   Expected: exit 0 with `SUMMARY: p04-phase-suite.sh pass=12 fail=0`. If any sub-gate fails inside the suite but passes when invoked directly, investigate the suite's environment.

4. **Run `scripts/verify/check-must-haves.sh` against P04.**

   ```bash
   bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P04
   ```

   Expected: exits 0 with truths/artifacts/key-links all PASS. If artifact-grep predicates fail, apply the plan-amendment-not-task-reopen pattern: amend `P04-PLAN.md` Artifacts section to match the on-disk shape (NOT amend the deliverable to match the plan).

5. **Dual-write the recent-changes entry to CLAUDE.md + AGENTS.md.**

   ```bash
   bash scripts/util/dual-write-runtime-md.sh --marker recent-changes --append-entry "M030 P04 close: dispatch-interface live-routing branch (FR-9 programmatic flip-gate via shadow-compare invocation per D-A2; per-class partial-flip authorization per D-A3; --model passing through to backend) + verifier-fail escalation loop (FR-10 fast→balanced→smart with CON-5 hard-cap=2 / 3 records max + escalation_cap_hit on cap) + 2 new JSONL fields (escalation_count, escalation_reason) + 1 new record_type (escalation_cap_hit) + sixth override_source value (shadow_gate_blocked) wired through; CON-4/D-A5 kill-switch supersedes live-mode (live: true is inactive warning); CON-6 append-only preserved (inode + head-2 hash); SC-11 byte-equality preserved; phase-suite green pass=12 fail=0"
   ```

   Expected: the script reports successful append to both CLAUDE.md and AGENTS.md.

6. **Stage all P04 deliverables.** Stage:

   - `tests/fixtures/m030-p04/` (entire directory tree: plans/, configs/, round-trip-stage/, the 3 shadow-corpus JSONL files, synthesize-corpora.sh)
   - `scripts/dispatch/adapters/backend/stub-fail-n.sh` (T01)
   - `scripts/dispatch/adapters/backend/stub-record-model.sh` (T01)
   - `tools/verify/p04-*.sh` (13 files: 12 sub-gates + phase-suite)
   - `scripts/dispatch/dispatch-interface.sh` (T02 + T03 amendments)
   - `references/model-routing.md` (T03 amendment)
   - `CLAUDE.md` (recent-changes update)
   - `AGENTS.md` (recent-changes update)
   - [`.orchestrator/milestones/M030/phases/P04/P04-PLAN.md`](../../../../../milestones/M030/phases/P04/P04-PLAN.md) + `tasks/T0[1-4]-*-PLAN.md` (the plan files this task plan was authored from)

   Use `git add <path>` per file; do NOT use `git add -A` or `git add .` to avoid accidental sensitive-file staging.

7. **Author the commit message file.** Write to `/tmp/p04-t04-commit-msg.txt` via the Write tool:

   ```
   M030/P04/T04: phase-suite + recent-changes dual-write + close

   T04 closes P04 with the straight-line phase-suite aggregator over all
   twelve P04 sub-gates (additive-schema + override-source-enum-extended +
   con3-live-closure + sc2a-shadow-gate-block + sc3-live-mechanical +
   partial-flip-routing + con4-live-killswitch + sc4-escalation-sequence +
   sc5-escalation-cap + con5-no-fourth-record + con6-prior-records-bit-identical
   + escalation-fields-enum). Pass=12 fail=0 against HEAD.

   The recent-changes dual-write (CLAUDE.md + AGENTS.md) appends the standard
   single-line P04-close entry summarizing the live-routing flip-gate enforcement
   (FR-9 / D-A2), per-class partial-flip authorization (D-A3), verifier-fail
   escalation loop (FR-10 with CON-5 hard-cap), 2 new JSONL fields plus 1 new
   record_type, and the kill-switch-supersedes-live (CON-4 / D-A5) compound case.

   This commit also includes any plan-side amendments T04 needed to satisfy
   check-must-haves.sh per the plan-amendment-not-task-reopen pattern (P02/T04
   + P03/T04 precedent) — amendments touch P04-PLAN.md artifact-grep predicates
   only, never the underlying deliverables.

   Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
   ```

8. **Commit with `git commit -F`:**

   ```bash
   git commit -F /tmp/p04-t04-commit-msg.txt
   ```

   Expected: clean commit; pre-commit hooks run + pass. If a pre-commit hook fails, investigate + fix + RE-STAGE + create a NEW commit (do NOT use `--amend` per the gitflow safety protocol).

9. **Post-commit verification.** Run:

   ```bash
   bash tools/verify/p04-phase-suite.sh
   bash scripts/state/derive-phase.sh .orchestrator/milestones/M030
   ```

   Expected: phase-suite re-runs green; `derive-phase.sh` reports the M030 state has advanced to `verified` for P04 (or `summarized` if `orchestrator:verify` has already run downstream).

## Must-Haves

This task satisfies the phase truth:

- "bash tools/verify/p04-phase-suite.sh invokes all eleven P04 sub-gates ... plus the escalation-fields-enum gate (twelve total) ... emits SUMMARY: p04-phase-suite.sh pass=N fail=M ..." — gated by the suite itself when invoked.

T04 also discharges the phase-close obligations: recent-changes dual-write, plan-side amendments per the must-haves grep, single coherent commit. None of these are individually mechanically gated by a Tier 1 verifier; they are gated holistically by the verify pipeline's `scripts/verify/check-must-haves.sh` + the state-machine transition from `executing` to `verified`.

## Verification

```bash
bash tools/verify/p04-phase-suite.sh
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P04
```

Each command uses single-script-file shape per AD-19. Both must exit 0 before T04 closes.

## Inputs

### From Previous Tasks

- tools/verify/p04-additive-schema.sh, p04-override-source-enum-extended.sh (from T01) — Key API: each `bash <path>` exits 0; `SUMMARY:` line emitted with pass-count.
- tools/verify/p04-sc2a-shadow-gate-block.sh, p04-sc3-live-mechanical.sh, p04-partial-flip-routing.sh, p04-con3-live-closure.sh, p04-con4-live-killswitch.sh (from T02) — Key API: same shape as T01 verifiers.
- tools/verify/p04-sc4-escalation-sequence.sh, p04-sc5-escalation-cap.sh, p04-con5-no-fourth-record.sh, p04-con6-prior-records-bit-identical.sh, p04-escalation-fields-enum.sh (from T03) — Key API: same shape.
- references/model-routing.md (post-T03) — operator reference doc with new `## Live Routing` section. T04 does not modify; included in the commit if it is unstaged at T04 entry.
- scripts/dispatch/dispatch-interface.sh (post-T03) — amended emitter. T04 does not modify; included in the commit.

### From Disk (Pre-existing)

- scripts/util/dual-write-runtime-md.sh — Key API: `bash <path> --marker recent-changes --append-entry "<message>"` appends a single-line entry to the orchestrator:recent-changes region of CLAUDE.md and (when present + dual_write_agents: true) AGENTS.md. M014/P01 FR-12 deliverable.
- scripts/verify/check-must-haves.sh — Key API: `bash <path> <phase-dir>` reads the phase plan's Truths / Artifacts / Key Links sections and verifies each against the on-disk state. Exit 0 iff all checks pass.
- scripts/state/derive-phase.sh — Key API: `bash <path> <milestone-dir>` reports the orchestrator-state-machine state for the milestone. Used post-commit to confirm the phase advanced to `verified`.
- CLAUDE.md, AGENTS.md — runtime-instruction files at repo root with the orchestrator:recent-changes region. Dual-write target.
- tools/verify/p02-phase-suite.sh, tools/verify/p03-phase-suite.sh — pattern reference. T04's `p04-phase-suite.sh` mirrors this shape (straight-line aggregator, no loops, twelve literal sub-gate invocations).

## Constraints

- **AD-19 single-script-file shape**: phase-suite is a single script invoking twelve sub-gate scripts. Aggregation logic is straight-line (no loops, no eval).
- **AP-008 heredoc-with-expansion (commit shape)**: commit message MUST be authored to a file via Write and committed with `git commit -F <file>`. Inline `git commit -m "$(cat <<'EOF' ... EOF)"` form is forbidden per CLAUDE.md commit-authoring guidance.
- **AP-009 compound-chain-gt2**: phase-suite uses single-line `bash <path>` invocations + per-gate rc capture. No `cmd1 | cmd2 | cmd3` or `cmd1 && cmd2 && cmd3` chains.
- **Plan-amendment-not-task-reopen**: when must-haves grep fails on artifact-grep, the resolution is a plan-side amendment (P04-PLAN.md), not a task re-open. Same precedent as P02/T04 + P03/T04.
- **Single commit for P04 close**: T04 produces ONE commit covering the phase-suite verifier + CLAUDE.md/AGENTS.md update + any plan-side amendments. Multiple commits during T04 are acceptable iff a pre-commit hook fails on the first attempt.
- **Bash 3.2 compatibility**: phase-suite uses no `declare -A`, no `mapfile`, no `readarray`. Per-gate rc capture uses unique variable names (`rc1`–`rc12`).
- **Plan-Time Discipline rule 5 (real-DB verification)**: T04 introduces no SQL — N/A.

## Expected Output

- `tools/verify/p04-phase-suite.sh` — green: 12 sub-gates pass; `SUMMARY: p04-phase-suite.sh pass=12 fail=0`.
- `CLAUDE.md` + `AGENTS.md` — both contain the new P04-close recent-changes entry (single line, summarizes deliverables + verification signal).
- One git commit covering the phase-suite verifier + CLAUDE.md/AGENTS.md update (+ optional plan-side amendments to P04-PLAN.md per must-haves grep). Commit message authored via `git commit -F /tmp/p04-t04-commit-msg.txt`.
- `bash tools/verify/p04-phase-suite.sh` exits 0 with `SUMMARY: p04-phase-suite.sh pass=12 fail=0`.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P04` exits 0 with all truths / artifacts / key-links PASS.
- `bash scripts/state/derive-phase.sh .orchestrator/milestones/M030` reports state has advanced to `verified` (or `summarized` if `orchestrator:verify` has run).

## Notes

Expected output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p04-phase-suite.sh` -> 12 sub-gates run; `SUMMARY: p04-phase-suite.sh pass=12 fail=0`, exit 0.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P04` -> truths/artifacts/key-links all PASS; exit 0.

The phase-suite shape is the same straight-line aggregator P01/P02/P03 used. The twelve sub-gates are arranged in a meaningful sequence: SC-11 byte-equality first (the fundamental contract), then enum-closure (the schema gate), then CON-3 closure (the no-new-model-IDs gate), then the four T02 scenario-specific gates (SC-2a + SC-3 + partial-flip + CON-4 live-killswitch), then the five T03 escalation gates (SC-4 + SC-5 + CON-5 + CON-6 + escalation-fields-enum). If a gate fails, the SUMMARY line names how many of the twelve passed, which makes the failure-class diagnosis fast.

If `dual-write-runtime-md.sh` reports an issue (e.g., `>>> orchestrator:recent-changes >>>` region missing from CLAUDE.md), the resolution is to manually authorize the region's existence first via `scripts/util/dual-write-runtime-md.sh --init-region` (per M014/M021 convention) and then re-run the append. This should not happen in P04 because the region exists per the recent-changes block visible at the top of CLAUDE.md (the P03 close entry is already present there).

If the post-commit `derive-phase.sh` reports a state other than `verified` or `summarized`, investigate which file is missing or unexpectedly present in `.orchestrator/milestones/M030/phases/P04/`. The state machine derives from disk — common causes are a missing T0N-SUMMARY.md (executing → not advanced) or a stale lock file. T04 does NOT author summaries; that is `orchestrator:verify` + `orchestrator:consolidate` downstream territory. The acceptable post-T04 state is `executing → verified` (verify ran inline) or `executing` itself (verify will run as a separate dispatch).

The single P04-close commit lands all P04 deliverables atomically. Downstream `orchestrator:verify` reads HEAD to verify the phase; HEAD is the post-T04 commit. If the verify dispatch finds gaps (e.g., a plan-side amendment was needed but not made), it surfaces via the verify-failure path, NOT via re-opening T04 — same plan-amendment-not-task-reopen pattern.

The `--marker recent-changes` flag on `dual-write-runtime-md.sh` is the M014/M021 convention for selecting the named region; older invocations may have used positional arguments. Per the P03/T04 commit message in the recent-changes block, the explicit `--marker` flag is the current canonical shape.
