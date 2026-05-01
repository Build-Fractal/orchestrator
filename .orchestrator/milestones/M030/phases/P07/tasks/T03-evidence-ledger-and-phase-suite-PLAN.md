---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P07"
milestone: "M030"
name: "Acceptance-evidence ledger + evidence-ledger shape gate + phase-suite aggregator"
depends_on: ["T02"]
---

## Prerequisites

- T01 + T02 deliverables on disk and green:
  - All four corpora at `tests/m030-acceptance/` (T01).
  - `tests/m030-acceptance/shadow-corpus-fixtures.sh` synthesizer (T01).
  - All five T01 per-verdict gates at `tools/verify/p07-corpus-*.sh` + `p07-corpus-synthesizer-idempotent.sh` (T01).
  - `tests/m030-acceptance/run-acceptance-battery.sh` runner (T02).
  - `tools/verify/p07-partial-flip-jsonl-fields.sh`, `p07-cross-surface-coherence.sh`, `p07-acceptance-battery-pass.sh` (T02).

- All nine T01+T02 verifiers exit 0 when invoked individually:
  - `p07-corpus-synthesizer-idempotent.sh`, `p07-corpus-50-per-class-ready.sh`, `p07-corpus-zero-evidence-insufficient.sh`, `p07-corpus-2-class-partially-ready.sh`, `p07-corpus-block.sh`, `p07-partial-flip-jsonl-fields.sh`, `p07-cross-surface-coherence.sh`, `p07-acceptance-battery-pass.sh` (T03 also adds the ninth: `p07-acceptance-evidence-ledger.sh`).

- `tests/m030-acceptance/run-acceptance-battery.sh` exits 0 with `BATTERY: pass=N fail=0`.

Plan-time prerequisite-existence verification: every path above is asserted by T02 close; T03 captures the runner's output as the source-of-truth for the evidence ledger.

## Description

T03 ships the green-run evidence ledger plus the P07 phase-suite aggregator. Three deliverables:

1. **`.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md`** — a one-shot evidence ledger of the green acceptance-battery run. Frontmatter declares the run timestamp + the canonical `BATTERY: pass=N fail=0` summary; body has a `## Evidence` section with one row per SC carrying the verifier path + the canonical key-line from that verifier's stdout.

2. **`tools/verify/p07-acceptance-evidence-ledger.sh`** — verifier asserting the ledger exists with valid frontmatter shape AND that every cited verifier path resolves to an existing-on-disk script.

3. **`tools/verify/p07-phase-suite.sh`** — straight-line aggregator over the nine P07 sub-gates (T01's five + T02's three + T03's one).

### Evidence ledger shape

Frontmatter:

```yaml
---
schema_version: "1.0"
type: acceptance-evidence
milestone: "M030"
recorded_at: "<ISO8601-timestamp>"
battery_summary: "pass=N fail=0"
runner: "tests/m030-acceptance/run-acceptance-battery.sh"
---
```

Body:

```markdown
# M030 Acceptance Evidence

This file is the one-shot evidence ledger of the M030 acceptance-battery green run captured at `recorded_at`. The battery is the contract; this ledger is the audit trail. Re-running the battery later may produce drift (timestamps, JSONL records); this file freezes the green-run state at milestone close.

## Battery Summary

`BATTERY: pass=N fail=0` — emitted by `tests/m030-acceptance/run-acceptance-battery.sh` on `<recorded_at>`.

## Evidence

| SC | Verifier(s) | Canonical key line |
|----|-------------|--------------------|
| SC-1 | `tools/verify/p01-classifier-determinism.sh` + `tools/verify/p01-classifier-perf-and-network.sh` | `<canonical SUMMARY: line from each>` |
| SC-2 (ready) | `tools/verify/p07-corpus-50-per-class-ready.sh` | `flip_recommendation=ready` |
| SC-2 (evidence_insufficient) | `tools/verify/p07-corpus-zero-evidence-insufficient.sh` | `flip_recommendation=evidence_insufficient` |
| SC-2 (partially_ready) | `tools/verify/p07-corpus-2-class-partially-ready.sh` | `flip_recommendation=partially_ready` + flippable-classes line |
| SC-2 (block) | `tools/verify/p07-corpus-block.sh` | `flip_recommendation=block` |
| SC-2a | `tools/verify/p04-sc2a-shadow-gate-block.sh` | `<canonical SUMMARY: line>` |
| SC-3 | `tools/verify/p04-sc3-live-mechanical.sh` | `<canonical SUMMARY: line>` |
| SC-3a | `tools/verify/p02-sc3a-roundtrip.sh` | `<canonical SUMMARY: line>` |
| SC-4 | `tools/verify/p04-sc4-escalation-sequence.sh` | `<canonical SUMMARY: line>` |
| SC-5 | `tools/verify/p04-sc5-escalation-cap.sh` | `<canonical SUMMARY: line>` |
| SC-6 | `tools/verify/p03-sc6-frontmatter-override.sh` | `<canonical SUMMARY: line>` |
| SC-7 | `tools/verify/p03-sc7-kill-switch.sh` | `<canonical SUMMARY: line>` |
| SC-7a | `tools/verify/p03-sc7a-compound.sh` | `<canonical SUMMARY: line>` |
| SC-8 | `tools/verify/p05-by-model-cost-rates-present.sh` + `p05-by-model-cost-rates-absent.sh` + `p05-by-model-dispatch-counts.sh` | `<canonical lines>` |
| SC-9 | `tools/verify/p05-doctor-config-check.sh` | `<canonical SUMMARY: line>` |
| SC-10 | `tools/verify/p01-classifier-ground-truth.sh` | `<accuracy ratio line>` |
| SC-11 | `tools/verify/p05-sc11-rollup-byte-equality.sh` + `p05-sc11-footer-byte-equality.sh` + `tools/verify/p06-sc11-byte-equality.sh` | `<canonical SUMMARY: lines>` |

## Cross-Surface Coherence

The two phase-suite-only gates that don't appear in the spec.md SC list but verify roadmap-line-64 contracts:

- `tools/verify/p07-partial-flip-jsonl-fields.sh` — partial-flip JSONL field shape verified at acceptance scale.
- `tools/verify/p07-cross-surface-coherence.sh` — metrics-rollup + efficiency-footer + check-anomalies coherent output against the 150-record corpus.

## Provenance

- Battery runner SHA at recording time: `<git rev-parse HEAD:tests/m030-acceptance/run-acceptance-battery.sh>`.
- Corpus synthesizer SHA at recording time: `<git rev-parse HEAD:tests/m030-acceptance/shadow-corpus-fixtures.sh>`.
- Recording machine: `<uname -srm output, anonymized>` (ledger captures runtime context for audit).

## Re-running the Battery

```bash
bash tests/m030-acceptance/shadow-corpus-fixtures.sh
bash tests/m030-acceptance/run-acceptance-battery.sh
```

Idempotent corpus + replay-able battery. Re-running produces a fresh `BATTERY: pass=N fail=0` line; this ledger captures the milestone-close green run.
```

The `<canonical SUMMARY: line>` placeholders are filled at T03 author time by capturing each verifier's stdout. The ledger is a snapshot, not a dynamic report — T03 writes it once and commits.

### Phase-suite aggregator shape

`tools/verify/p07-phase-suite.sh` is a straight-line aggregator over the nine P07 sub-gates. Same shape as `p06-phase-suite.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/p07-phase-suite.sh — P07 phase-close gate aggregator.
# Straight-line invocation of all nine P07 sub-gates; no loops, no eval.
# Mirrors P02/P03/P04/P05/P06 phase-suite shape.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0
fail=0

bash "$PROJECT_ROOT/tools/verify/p07-corpus-synthesizer-idempotent.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p07-corpus-synthesizer-idempotent.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p07-corpus-50-per-class-ready.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p07-corpus-50-per-class-ready.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p07-corpus-zero-evidence-insufficient.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p07-corpus-zero-evidence-insufficient.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p07-corpus-2-class-partially-ready.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p07-corpus-2-class-partially-ready.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p07-corpus-block.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p07-corpus-block.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p07-partial-flip-jsonl-fields.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p07-partial-flip-jsonl-fields.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p07-cross-surface-coherence.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p07-cross-surface-coherence.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p07-acceptance-battery-pass.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p07-acceptance-battery-pass.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p07-acceptance-evidence-ledger.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p07-acceptance-evidence-ledger.sh exited $rc"; fi

printf 'SUMMARY: p07-phase-suite.sh pass=%s fail=%s\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

### Evidence-ledger shape gate

`tools/verify/p07-acceptance-evidence-ledger.sh` shape:

1. Asserts `.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md` exists.
2. Greps the frontmatter for required keys: `schema_version`, `type: acceptance-evidence`, `milestone: "M030"`, `recorded_at`, `battery_summary`, `runner`.
3. Greps the body for `## Evidence` table presence and for each of the 14 SC labels (`SC-1`, `SC-2`, `SC-2a`, `SC-3`, `SC-3a`, `SC-4`, `SC-5`, `SC-6`, `SC-7`, `SC-7a`, `SC-8`, `SC-9`, `SC-10`, `SC-11`).
4. Extracts every cited verifier path (lines matching `tools/verify/p[0-9]+-.*\.sh`) and asserts each path resolves to an existing-on-disk script.
5. Emits `SUMMARY: p07-acceptance-evidence-ledger.sh pass=N fail=M` and exits 0 iff `fail=0`.

## Steps

1. **Confirm T01+T02 deliverables green** by running each individually:

   ```bash
   bash tools/verify/p07-corpus-synthesizer-idempotent.sh
   bash tools/verify/p07-corpus-50-per-class-ready.sh
   bash tools/verify/p07-corpus-zero-evidence-insufficient.sh
   bash tools/verify/p07-corpus-2-class-partially-ready.sh
   bash tools/verify/p07-corpus-block.sh
   bash tools/verify/p07-partial-flip-jsonl-fields.sh
   bash tools/verify/p07-cross-surface-coherence.sh
   bash tools/verify/p07-acceptance-battery-pass.sh
   ```

   Expected: all eight exit 0 with `SUMMARY: <name> pass=N fail=0`. If any fail, halt T03 and re-open the relevant T01/T02 task.

2. **Run the full acceptance battery and capture stdout** for the evidence ledger:

   ```bash
   bash tests/m030-acceptance/run-acceptance-battery.sh > /tmp/p07-battery-output.txt
   ```

   Confirm the last line is `BATTERY: pass=N fail=0` (capture exact N for the ledger frontmatter).

3. **Capture per-verifier canonical SUMMARY lines** for the ledger body. For each verifier path in the SC battery, run:

   ```bash
   bash <verifier-path>
   ```

   And capture the `SUMMARY: <verifier-name> pass=N fail=0` line. These fill the `<canonical SUMMARY: line>` placeholders in the ledger table.

   Acceptable shortcut: extract from the captured `/tmp/p07-battery-output.txt` since the runner's `BATTERY-PASS:` lines preserve the verifier path. The exact stdout shape varies per verifier; the ledger captures whichever shape the verifier emits.

4. **Author `.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md`** per the shape in the Description. Use the Write tool. Fill in:
   - `recorded_at` = current ISO8601 timestamp.
   - `battery_summary` = the captured `pass=N fail=0` from step 2.
   - Each `<canonical SUMMARY: line>` from step 3.
   - `<git rev-parse HEAD:...>` placeholders filled via `git rev-parse HEAD:tests/m030-acceptance/run-acceptance-battery.sh` and `git rev-parse HEAD:tests/m030-acceptance/shadow-corpus-fixtures.sh`. (These will only resolve after T02 commits these files; if T03 is authored on the same branch as T02 before the close commit, use `git hash-object <path>` instead, which works on uncommitted blobs.)
   - `<uname -srm output>` = `uname -srm` (e.g., `Darwin 24.6.0 arm64`).

5. **Author `tools/verify/p07-acceptance-evidence-ledger.sh`** per the shape in the Description. Make executable.

6. **Self-check the evidence-ledger gate**:

   ```bash
   bash tools/verify/p07-acceptance-evidence-ledger.sh
   ```

   Expected: `SUMMARY: p07-acceptance-evidence-ledger.sh pass=N fail=0`, exit 0.

7. **Author `tools/verify/p07-phase-suite.sh`** per the shape in the Description. Make executable.

8. **Self-check the phase-suite**:

   ```bash
   bash tools/verify/p07-phase-suite.sh
   ```

   Expected: exit 0 with `SUMMARY: p07-phase-suite.sh pass=9 fail=0`.

9. **Run `scripts/verify/check-must-haves.sh`** against the phase plan to confirm all truths + artifacts + key-links pass:

   ```bash
   bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P07
   ```

   Expected: ALL truths PASS (the 10 truths declared in P07-PLAN.md). ALL artifacts PASS except the four T04-owned artifacts (M030-SUMMARY.md, M030-VALIDATED, P07-SUMMARY.md, the modified CLAUDE.md project-status update — though CLAUDE.md / AGENTS.md may already exist with content, the artifact predicate may PASS at T03 close depending on what the predicates assert). The plan-amendment-not-task-reopen pattern applies for any artifact-grep predicate that diverges between the plan declaration and the actual file content.

   Acceptable T03-close state: 9 truths PASS + most artifacts PASS + 4 artifacts FAIL (T04-owned). The 4 expected FAILs are M030-SUMMARY.md, M030-VALIDATED, P07-SUMMARY.md, and any T04-owned CLAUDE.md predicate. Document the expected FAILs in the T03 SUMMARY.

## Must-Haves

T03 satisfies the following P07 phase truths:

- The acceptance-evidence ledger exists with valid frontmatter + 14-SC body table + every cited verifier path resolving on-disk — gated by `bash tools/verify/p07-acceptance-evidence-ledger.sh`.
- The P07 phase-suite invokes all P07 sub-gates in literal sequence and exits 0 iff every sub-gate passes — gated by `bash tools/verify/p07-phase-suite.sh`.

## Verification

```bash
bash tools/verify/p07-acceptance-evidence-ledger.sh
bash tools/verify/p07-phase-suite.sh
```

Both must exit 0 before T03 closes.

## Inputs

### From Previous Tasks (T01 + T02)

- `tests/m030-acceptance/run-acceptance-battery.sh` (T02) — invoked at step 2 to capture the battery stdout. Key API: `bash <path>` emits 22 `BATTERY-PASS:` lines + a final `BATTERY: pass=N fail=0` summary line.
- All eight T01 + T02 verifier scripts at `tools/verify/p07-*.sh` (T01 ships five; T02 ships three) — invoked by the phase-suite aggregator. Key API: each is `bash <path>` exit 0 iff sub-gate passes.

### From Disk (Pre-existing)

- `scripts/verify/check-must-haves.sh` — Key API: `bash <path> <phase-dir>`. Reads phase plan's Must-Haves section + checks each truth's `Check:` command + each artifact's existence/grep/line-count + each key-link source→target grep. Exit 0 on all PASS. Used at step 9.
- `git` — for `rev-parse` + `hash-object` to capture the runner / synthesizer SHAs in the ledger.
- `uname` — for runtime context capture in the ledger.

## Constraints

- **AD-19 single-script-file shape**: `p07-phase-suite.sh` and `p07-acceptance-evidence-ledger.sh` use straight-line invocation; helper-function-carve-out applies to assertion bodies if any.
- **Bash 3.2 compatibility**: parallel scalars + `if`-statements throughout.
- **One-shot ledger discipline**: `M030-ACCEPTANCE-EVIDENCE.md` is authored ONCE at T03 and committed. It is NOT regenerated dynamically. Re-running the battery later produces a fresh BATTERY line but the ledger remains the milestone-close snapshot. Operators who want fresh evidence re-run the battery and read its stdout; they don't regenerate the ledger.
- **Project-owned-verifier-paths discipline (M032 Finding A)**: the two new verifiers live under `tools/verify/` (slug-bearing). The ledger lives under `.orchestrator/milestones/M030/` (state-tree, project-owned).
- **Plan-Time Discipline rule 2 (verifier-availability cross-check)**: every verifier the phase-suite invokes resolves to an existing-on-disk script post-T02. T01+T02 deliverables are confirmed at step 1 + step 7's self-check.

## Expected Output

- `.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md` — one-shot evidence ledger with frontmatter + 14-SC body table + provenance + re-run instructions.
- `tools/verify/p07-acceptance-evidence-ledger.sh` — gates the ledger's frontmatter + body shape + cited-verifier-existence.
- `tools/verify/p07-phase-suite.sh` — straight-line aggregator over 9 P07 sub-gates; exits 0 iff all pass; emits `SUMMARY: p07-phase-suite.sh pass=9 fail=0`.

All three deliverables ship green.

## Notes

Expected output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p07-phase-suite.sh` → `SUMMARY: p07-phase-suite.sh pass=9 fail=0`, exit 0.
- `bash tools/verify/p07-acceptance-evidence-ledger.sh` → `SUMMARY: p07-acceptance-evidence-ledger.sh pass=N fail=0`, exit 0.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P07` → most truths + artifacts PASS; the 4 T04-owned artifacts (M030-SUMMARY.md, M030-VALIDATED, P07-SUMMARY.md, and the T04 CLAUDE.md project-status update) FAIL because they don't exist yet — these FAILs are EXPECTED at T03 close and resolve when T04 lands.

If a per-verifier canonical SUMMARY line in the ledger drifts (because one of the upstream verifiers changes its emit shape), AMEND the ledger directly via Edit tool. The ledger is a snapshot of the green-run state — drift over time is expected; the milestone-close snapshot is what the ledger preserves. Re-runs of the battery may produce new lines; the ledger captures the ones from the green run that triggered M030 close.

If `git rev-parse HEAD:<path>` fails because T02 hasn't committed yet, use `git hash-object <path>` (works on the worktree blob without requiring a commit). Both produce deterministic SHA-1 hashes that uniquely identify the file content at recording time; either is acceptable as the provenance anchor.

The plan-amendment-not-task-reopen pattern (P02-P06 precedent) applies if `check-must-haves.sh` reports a failure on an artifact-grep or key-link predicate at step 9. Investigate first whether the predicate or the deliverable is wrong; if the deliverable is shaped correctly and the predicate was authored against an aspirational shape that diverged, amend the predicate in `P07-PLAN.md` directly and re-run `check-must-haves.sh`. If the deliverable IS wrong, re-open the relevant T01/T02 task — but T03 should NOT touch the deliverables it consumes.
