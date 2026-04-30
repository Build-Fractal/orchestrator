---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M030"
name: "P02 phase-suite + recent-changes dual-write + commit"
depends_on: ["T03"]
---

## Prerequisites

- All P02 verifiers from T01-T03 are on disk:
  - `tools/verify/p02-fixture-shape.sh` (T01)
  - `tools/verify/p02-additive-schema.sh` (T01)
  - `tools/verify/p02-shadow-emit.sh` (T02 + T03 amendment)
  - `tools/verify/p02-con3-closure.sh` (T02)
  - `tools/verify/p02-append-only.sh` (T02)
  - `tools/verify/p02-shadow-compare-verdicts.sh` (T03)
  - `tools/verify/p02-partial-flip-enum.sh` (T03)
  - `tools/verify/p02-stability-metric-traceability.sh` (T03)
  - `tools/verify/p02-sc3a-roundtrip.sh` (T03)
- All nine verifiers exit 0 against current working tree (T01-T03 close conditions).
- `scripts/dispatch/dispatch-interface.sh` is amended (T02 + T03 small follow-up Step 2) with shadow-mode hook + `classifier_confidence`/`model_routed`/`model_used`/`partial_flip_active`/`withheld_classes` fields under `M030_SHADOW_MODE=1` AND `CLAUDECODE=1`.
- `scripts/diagnostics/shadow-compare.sh` exists with 4-verdict output (T03).
- Five fixture JSONL files at `tests/fixtures/m030-p02/` (T01 + T03).
- `scripts/util/dual-write-runtime-md.sh` exists (pre-existing; verified during plan-authoring at `/Users/brettkellgren/Sites/spec-kit-orchestrator/scripts/util/dual-write-runtime-md.sh`).
- `tools/verify/p01-phase-suite.sh` exists as the reference shape for the straight-line aggregator pattern (P01/T04 close).

Plan-time prerequisite-existence verification: every path above is either a T01-T03 deliverable (asserted by their respective close conditions) or a pre-existing repo file (asserted during plan-authoring via direct `ls` inspection). `scripts/util/dual-write-runtime-md.sh` was confirmed present.

## Description

T04 closes P02. Three deliverables:

1. **`tools/verify/p02-phase-suite.sh`** — straight-line aggregator over all nine P02 sub-gates. Mirrors `p01-phase-suite.sh` shape: literal `bash <path>` invocations (no loops), `pass`/`fail` accumulators via `$?`, single-line `SUMMARY: p02-phase-suite.sh pass=N fail=M` before exit.

2. **CLAUDE.md / AGENTS.md recent-changes update** — append a one-line P02-close fragment via `scripts/util/dual-write-runtime-md.sh`. Fragment names the load-bearing facts: 4-verdict shadow-compare, SC-11 byte-equality preserved, SC-3a roundtrip green, CC-only short-circuit, stability metric 0.10/N=20/50 traced.

3. **Commit** — stage the phase-suite script + recent-changes updates and commit via `git commit -F <message-file>`.

### P02 phase-suite contract

`tools/verify/p02-phase-suite.sh` invokes nine sub-gates in this order:

1. `bash tools/verify/p02-fixture-shape.sh`
2. `bash tools/verify/p02-additive-schema.sh`
3. `bash tools/verify/p02-shadow-emit.sh`
4. `bash tools/verify/p02-con3-closure.sh`
5. `bash tools/verify/p02-append-only.sh`
6. `bash tools/verify/p02-shadow-compare-verdicts.sh`
7. `bash tools/verify/p02-partial-flip-enum.sh`
8. `bash tools/verify/p02-stability-metric-traceability.sh`
9. `bash tools/verify/p02-sc3a-roundtrip.sh`

Each invocation is a literal statement; `pass`/`fail` accumulators update via `pass=$((pass+1))` / `fail=$((fail+1))` per `$?`. No `for` loop over a script-name array (forbidden by AD-19; the literal-statement form is required). Final line: `SUMMARY: p02-phase-suite.sh pass=N fail=M`. Exit 0 iff all nine exit 0.

Use `set -uo pipefail` (NOT `-e`) so `$?` is captured even on sub-gate fail. Each sub-gate's own diagnostic is emitted to stdout/stderr by the sub-gate; the suite just accumulates and reports.

### Recent-changes dual-write

Per CON-6 dual-write invariant (CLAUDE.md `# >>> orchestrator:recent-changes >>>` region), append a one-line P02 close fragment via `scripts/util/dual-write-runtime-md.sh`. Recommended fragment:

```
M030 P02 close: dispatch-interface shadow hook (M030_SHADOW_MODE=1 + CLAUDECODE=1) + 5 additive JSONL fields + scripts/diagnostics/shadow-compare.sh 4-verdict (ready|partially_ready|block|evidence_insufficient) + SC-3a roundtrip green + SC-11 byte-equality preserved (CON-2/FR-19) + CON-3 closure + CON-6 append-only + stability metric 0.10/N=20/50 traced; phase-suite green pass=9 fail=0
```

The dual-write helper writes to both CLAUDE.md (Claude Code) and AGENTS.md (Codex CLI) when the latter is present; its idempotency rules prevent duplicate fragments.

## Steps

1. **Confirm all T01-T03 deliverables are on disk and green.** Run:

   ```bash
   bash tools/verify/p02-fixture-shape.sh
   bash tools/verify/p02-additive-schema.sh
   bash tools/verify/p02-shadow-emit.sh
   bash tools/verify/p02-con3-closure.sh
   bash tools/verify/p02-append-only.sh
   bash tools/verify/p02-shadow-compare-verdicts.sh
   bash tools/verify/p02-partial-flip-enum.sh
   bash tools/verify/p02-stability-metric-traceability.sh
   bash tools/verify/p02-sc3a-roundtrip.sh
   ```

   Expected: all nine exit 0. If any fails, T04 cannot close — the failing upstream task must be re-opened.

2. **Author `tools/verify/p02-phase-suite.sh`** per the contract above. Verbatim straight-line bash:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/p02-phase-suite.sh — M030 P02 phase-close gate.
   # Invokes all nine P02 sub-gates in order; exits 0 iff all pass.
   # Bash 3.2 compatible. Straight-line — no loops, no eval, no compound chains.
   # Modeled on p01-phase-suite.sh (P01/T04 reference shape).

   set -uo pipefail

   pass=0
   fail=0

   bash tools/verify/p02-fixture-shape.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p02-additive-schema.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p02-shadow-emit.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p02-con3-closure.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p02-append-only.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p02-shadow-compare-verdicts.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p02-partial-flip-enum.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p02-stability-metric-traceability.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   bash tools/verify/p02-sc3a-roundtrip.sh
   if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

   echo "SUMMARY: p02-phase-suite.sh pass=$pass fail=$fail"

   if [ "$fail" -eq 0 ]; then
     exit 0
   else
     exit 1
   fi
   ```

   Note: same shape as `p01-phase-suite.sh`. The set-flags choice (`-uo pipefail`, no `-e`) is load-bearing — `-e` would short-circuit on the first sub-gate failure and skip the SUMMARY emission; `-u` catches unset variables; `-o pipefail` is preserved as defensive even though no pipes are used in the suite body.

3. **Run the new T04 verifier as a self-check:**

   ```bash
   bash tools/verify/p02-phase-suite.sh
   ```

   Expected: `SUMMARY: p02-phase-suite.sh pass=9 fail=0`, exit 0. If any sub-gate exits non-zero, the suite reports `pass=N fail=M` with `M >= 1` and exits 1; the failing sub-gate's own stdout/stderr from its individual run will name the failure mode.

4. **Recent-changes dual-write.** Run the dual-write helper:

   ```bash
   bash scripts/util/dual-write-runtime-md.sh "M030 P02 close: dispatch-interface shadow hook (M030_SHADOW_MODE=1 + CLAUDECODE=1) + 5 additive JSONL fields + scripts/diagnostics/shadow-compare.sh 4-verdict (ready|partially_ready|block|evidence_insufficient) + SC-3a roundtrip green + SC-11 byte-equality preserved (CON-2/FR-19) + CON-3 closure + CON-6 append-only + stability metric 0.10/N=20/50 traced; phase-suite green pass=9 fail=0"
   ```

   Expected: the helper appends the fragment to both `CLAUDE.md` and `AGENTS.md` (if present) inside the `# >>> orchestrator:recent-changes >>>` region. If the helper has its own flag protocol (`--fragment <text>` or stdin-piped input), use that shape instead — read `scripts/util/dual-write-runtime-md.sh` head before invocation to determine the supported shape. The helper is idempotent — re-running with the same fragment is a no-op or an explicit duplicate-detection refusal.

5. **Verify recent-changes update.** Run:

   ```bash
   grep -F 'M030 P02 close' CLAUDE.md
   ```

   Expected: stdout contains the new fragment line. If `AGENTS.md` exists, run the same grep against it; expect the same fragment.

6. **Stage and commit.** Stage:
   - `tools/verify/p02-phase-suite.sh` (create)
   - `CLAUDE.md` (modify — recent-changes region)
   - `AGENTS.md` (modify if present — recent-changes region)

   Author commit message file via the Write tool to `/tmp/p02-t04-commit-msg.txt`. Recommended message body:

   ```
   M030/P02/T04: phase-suite + recent-changes dual-write

   - tools/verify/p02-phase-suite.sh: straight-line aggregator over the 9 P02
     sub-gates (fixture-shape, additive-schema, shadow-emit, con3-closure,
     append-only, shadow-compare-verdicts, partial-flip-enum, stability-
     metric-traceability, sc3a-roundtrip). Same shape as p01-phase-suite.sh.
   - CLAUDE.md / AGENTS.md: recent-changes fragment naming the P02 close
     contract (4-verdict shadow-compare, SC-11 byte-equality preserved,
     SC-3a roundtrip green, CC-only short-circuit, stability metric traced).

   Phase-suite green: pass=9 fail=0.
   ```

   Commit: `git commit -F /tmp/p02-t04-commit-msg.txt`.

   Do NOT use the inline-HEREDOC `git commit -m "$(cat <<'EOF' ... EOF)"` form — AP-008 (`heredoc-with-expansion`) blocks it. Author the message file via Write tool, then `-F` it.

7. **Final post-commit self-check:**

   ```bash
   bash tools/verify/p02-phase-suite.sh
   bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P02
   ```

   Expected:
   - `bash tools/verify/p02-phase-suite.sh` → `SUMMARY: p02-phase-suite.sh pass=9 fail=0`, exit 0.
   - `bash scripts/verify/check-must-haves.sh ...` → all phase truths + artifacts + key-links pass, exit 0.

   If `check-must-haves.sh` reports a missing artifact or a failing truth `Check:`, the corresponding upstream task may have an incomplete deliverable — re-open and fix. If the phase-suite is green but `check-must-haves.sh` fails, the gap is in artifact paths or `grep` patterns in the phase plan's must-haves block; those would be fixed by amending the phase plan in P02-PLAN.md (NOT by re-opening tasks).

## Must-Haves

This task satisfies the phase truth:

- "`bash tools/verify/p02-phase-suite.sh` invokes all nine P02 sub-gates in literal sequence (no loops, no eval), exits 0 iff every sub-gate passes, and emits `SUMMARY: p02-phase-suite.sh pass=N fail=M` on a single line before exit." — `tools/verify/p02-phase-suite.sh` is itself the gate; its own self-check is `bash tools/verify/p02-phase-suite.sh`.

T04 closes the phase: when the suite exits 0 with `pass=9 fail=0`, P02 is ready for `orchestrator:verify` to write `P02-SUMMARY.md` and advance the milestone to P03.

## Verification

```bash
bash tools/verify/p02-phase-suite.sh
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P02
```

Each verifier uses single-script-file shape per AD-19. The phase-suite is the canonical phase-close gate; if it exits 0 with `pass=9 fail=0`, P02 is ready for `orchestrator:verify`. `check-must-haves.sh` is the framework-owned final gate that runs all phase Truth `Check:` commands + Artifact existence + Key Link presence.

## Inputs

### From Previous Tasks

- `tools/verify/p02-fixture-shape.sh`, `tools/verify/p02-additive-schema.sh` (T01)
  - Key API: each is `bash <path>` → exit 0 with `SUMMARY: <name> pass=N fail=0`.
- `tools/verify/p02-shadow-emit.sh`, `tools/verify/p02-con3-closure.sh`, `tools/verify/p02-append-only.sh` (T02)
  - Key API: each is `bash <path>` → exit 0 with `SUMMARY: <name> pass=N fail=0`.
- `tools/verify/p02-shadow-compare-verdicts.sh`, `tools/verify/p02-partial-flip-enum.sh`, `tools/verify/p02-stability-metric-traceability.sh`, `tools/verify/p02-sc3a-roundtrip.sh` (T03)
  - Key API: each is `bash <path>` → exit 0 with `SUMMARY: <name> pass=N fail=0`.

### From Disk (Pre-existing)

- `scripts/util/dual-write-runtime-md.sh` — recent-changes dual-write helper. Idempotent.
- `tools/verify/p01-phase-suite.sh` — reference pattern for the straight-line phase-suite shape.
- `CLAUDE.md` — recent-changes region target for the P02-close fragment.
- `AGENTS.md` (if present) — Codex CLI runtime instructions; recent-changes region dual-write target.

## Constraints

- **AD-19 single-script-file shape**: all verifier `Check:` invocations are `bash <single-path>.sh`. The phase-suite itself is a series of literal `bash <path>` statements — NO `for` loop over a script-name array (forbidden by AD-19).
- **Bash 3.2 compatibility**: no `declare -A`, no `mapfile`, no `readarray`, no `pipefail` reliance for capturing exit codes (use `$?` directly after each invocation, the same pattern as `p01-phase-suite.sh`).
- **CON-2/FR-19/SC-11 (additive-only schema)**: not directly amended in T04. The phase-suite gates the SC-11 verifier (`p02-additive-schema.sh`); failure here surfaces as a phase-suite fail, not a T04-specific issue.
- **CON-3 (symbolic-tier closure)**: gated by `p02-con3-closure.sh` in the suite. T04 itself introduces no model-ID literals (it adds only the phase-suite script and a recent-changes fragment).
- **CON-6 (append-only shadow corpus)**: gated by `p02-append-only.sh` in the suite. Recent-changes dual-write is a CLAUDE.md/AGENTS.md edit, NOT a JSONL append — the CON-6 invariant applies to shadow corpus files only.
- **AP-008 (heredoc-with-expansion)**: forbids `git commit -m "$(cat <<'EOF' ... EOF)"`. T04 uses `git commit -F <message-file>` exclusively per CLAUDE.md commit-authoring guidance.
- **Plan-Time Discipline rule 5 (real-DB verification)**: T04 does NOT introduce SQL — N/A.

## Expected Output

- `tools/verify/p02-phase-suite.sh` — straight-line aggregator over the nine P02 sub-gates.
- `CLAUDE.md` — recent-changes region updated with P02-close fragment.
- `AGENTS.md` — same fragment dual-written (if AGENTS.md is present).
- `bash tools/verify/p02-phase-suite.sh` exits 0 with `SUMMARY: p02-phase-suite.sh pass=9 fail=0`.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P02` exits 0 with all phase truths + artifacts + key-links passing.
- New commit on the working branch with subject `M030/P02/T04: phase-suite + recent-changes dual-write` (or similar).

## Notes

Expected verifier output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p02-phase-suite.sh` → nine sub-gate SUMMARY lines (one per gate), then `SUMMARY: p02-phase-suite.sh pass=9 fail=0`, exit 0.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P02` → all 10 Truth checks pass, all 18 Artifact checks pass, all 9 Key Link checks pass, `PASS: <count> truths, <count> artifacts, <count> key-links`, exit 0.

When P02's phase-suite green and the framework `check-must-haves.sh` green, P02 is ready for `orchestrator:verify` to write `P02-SUMMARY.md` and advance the milestone to P03. Downstream P03 (Operator overrides + kill switch) consumes:

- `scripts/dispatch/dispatch-interface.sh` — for the override-resolution path that overlays on top of T02's classifier hook (FR-4/FR-11/FR-12/FR-13/FR-14).
- The JSONL schema additions T02+T03 shipped (`classifier_confidence`, `model_routed`, `model_used`, `partial_flip_active`, `withheld_classes`) — for `override_source` co-emission.
- The CON-6 append-only invariant T02 locked in via `p02-append-only.sh` — P03's override path must respect the same invariant.

The decision to author `classifier_confidence` in T03 (not T02) keeps T02's amendment maximally surgical; the trade-off is one small follow-up edit in T03 Step 2. An alternative ordering — author `classifier_confidence` in T02 alongside the other four shadow fields — would have collapsed the two amendments into one; it was deferred to T03 because T03 is the consumer (variance computation needs the field) and the classifier-confidence field has no purpose in T02's contract on its own. Either ordering is correct; the chosen one prioritizes T02's amendment minimality.

The `CLAUDE.md` `# >>> orchestrator:recent-changes >>>` region is the single source of truth for "what changed recently across all milestones"; the dual-write to `AGENTS.md` keeps Codex CLI's runtime instructions in sync per CON-6 dual-write invariant. Both files are tracked in git; the commit captures both.
