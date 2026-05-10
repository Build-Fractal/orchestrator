---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P06"
milestone: "M030"
name: "P06 phase-suite aggregator + recent-changes dual-write + close commit"
depends_on: ["T02"]
---

## Prerequisites

- T01 + T02 deliverables on disk and green:
  - All five fixtures + golden baseline at `tests/fixtures/m030-p06/` (T01).
  - `tools/verify/p06-sc11-byte-equality.sh` (T01).
  - `tools/verify/p06-mechanical-regression.sh` + `p06-standard-regression.sh` + `p06-novel-regression.sh` + `p06-no-regression.sh` + `p06-below-min-sample.sh` + `p06-doctor-surfaces-anomaly.sh` + `p06-shadow-off-byte-equality.sh` (T02).
  - `scripts/dispatch/dispatch-interface.sh` amended with shadow-on `character` field (T02).
  - `scripts/diagnostics/check-anomalies.sh` amended with `_ca_model_routing_regression_check` + CLI integration (T02).
  - `references/model-routing.md` extended with `## Anomaly Records` section (T02).
- All eight T01+T02 verifiers exit 0 when invoked individually.
- `scripts/util/dual-write-runtime-md.sh` exists with `--append-entry` flag (M025/P02 deliverable; dual-writes a recent-changes fragment to BOTH `CLAUDE.md` and `AGENTS.md` so the framework + opt-in non-CC harnesses see the same fragment).
- The forward roadmap at `CLAUDE.md` is in its post-[M028](../../../../../milestones/M028/index.md) / post-P05 form. T03 appends a single-line P06-close fragment via dual-write.

Plan-time prerequisite-existence verification: every path above is asserted by T02 close.

## Description

T03 is a thin close. Three deliverable groups:

1. **Phase-suite aggregator** at `tools/verify/p06-phase-suite.sh` — straight-line invocation of all eight P06 sub-gates, mirroring the P02/P03/P04/P05 shape.
2. **Recent-changes dual-write** — appends a single-line P06-close fragment to BOTH `CLAUDE.md` and `AGENTS.md` recent-changes regions via `scripts/util/dual-write-runtime-md.sh --append-entry`.
3. **P06 close commit** — single atomic commit titled `M030/P06: anomaly-driven regression detection (model_routing_regression check + dispatch-interface character emit)`. Multi-line body authored via `git commit -F <message-file>` per the CLAUDE.md guidance (inline-HEREDOC with `$(cat <<EOF...EOF)` trips AP-008).

### Phase-suite aggregator shape

`tools/verify/p06-phase-suite.sh` is a straight-line aggregator over the eight P06 sub-gates. Same shape as `p05-phase-suite.sh`:

```bash
#!/usr/bin/env bash
# tools/verify/p06-phase-suite.sh — P06 phase-close gate aggregator.
# Straight-line invocation of all eight P06 sub-gates; no loops, no eval.
# Mirrors P02/P03/P04/P05 phase-suite shape.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0
fail=0

bash "$PROJECT_ROOT/tools/verify/p06-sc11-byte-equality.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p06-sc11-byte-equality.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p06-shadow-off-byte-equality.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p06-shadow-off-byte-equality.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p06-mechanical-regression.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p06-mechanical-regression.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p06-standard-regression.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p06-standard-regression.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p06-novel-regression.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p06-novel-regression.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p06-no-regression.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p06-no-regression.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p06-below-min-sample.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p06-below-min-sample.sh exited $rc"; fi

bash "$PROJECT_ROOT/tools/verify/p06-doctor-surfaces-anomaly.sh"
rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "GATE FAIL: p06-doctor-surfaces-anomaly.sh exited $rc"; fi

echo "SUMMARY: p06-phase-suite.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then exit 0; fi
exit 1
```

No loops, no `for`/`while` over a sub-gate list, no `eval`. Each sub-gate invocation is a literal `bash <path>` followed by `$?` capture and a counter update. AD-19 single-script-file shape preserved per sub-gate.

### Recent-changes dual-write fragment

The fragment text (one line; ≤120 chars after the prefix):

```
- M030/P06: anomaly-driven regression detection — model_routing_regression check + JSONL emit + dispatch-interface character emit.
```

The dual-write helper:

```bash
bash scripts/util/dual-write-runtime-md.sh --append-entry "M030/P06: anomaly-driven regression detection — model_routing_regression check + JSONL emit + dispatch-interface character emit."
```

The helper handles:
- Locating the `>>> orchestrator:recent-changes >>>` and `<<< orchestrator:recent-changes <<<` sentinel block in BOTH `CLAUDE.md` and `AGENTS.md`.
- Prepending the new entry to the top of the block (newest-first ordering, established by M025/P02).
- Trimming the block to its configured line bound (the helper enforces a default of N=1 entry; M030 has been shipping each phase-close as a single-entry top-of-block, with the previous entry being preserved on the second line — confirm at T03 author time by reading the current sentinel block in CLAUDE.md to see the pattern in use).

If the helper is shipping with a 1-entry bound and T03 wants to PRESERVE the prior P05 entry alongside the new P06 entry, the operator/T03 author may instead use the Edit tool to manually insert the P06 line into both `CLAUDE.md` and `AGENTS.md`'s sentinel blocks — same shape as P05/T03 used. The dual-write helper's exact behavior at T03 author time should be confirmed by reading its body before invoking; if the helper does prepend-and-trim-to-1, doing the dual-write manually is the safer path because the prior P05 entry is informative context.

### Close commit

The commit message file at `.orchestrator/milestones/M030/phases/P06/COMMIT-MSG.txt` (temporary file, deleted after commit). Multi-line body:

```
M030/P06: anomaly-driven regression detection (model_routing_regression check + dispatch-interface character emit)

Lands FR-18 — extends scripts/diagnostics/check-anomalies.sh with a
rolling-window per-class verifier-fail-rate check that emits a
model_routing_regression anomaly record (text + JSONL) when a class
crosses the configured threshold. Surfaces through orchestrator:doctor
via the existing M027 "Anomaly Detection" advisory invocation
(no run-doctor.sh amendment).

Adds `character` as an additive field on shadow-on dispatch_usage
records (additive — SC-11-preserving). The new check groups by this
field; pre-P06 records (no character field) are silently skipped.

Threshold defaults (#Q-4 plan-phase decision): pass_rate floor 0.50 +
min_class_sample 10. Both overridable via .orchestrator/config.yml
model_routing_regression.{pass_rate_threshold,min_class_sample}.
JSONL emit path defaults to .orchestrator/anomalies.jsonl (separate
file from execution-log.jsonl; preserves CON-6 dispatch-stream
invariant) and is overridable via M030_ANOMALIES_JSONL_PATH env.

Three tasks:
- T01 — fixtures (5 corpora + synthesizer) + pre-amendment golden +
        SC-11 byte-equality gate.
- T02 — dispatch-interface shadow-on character emit + check-anomalies
        rolling-window check + JSONL emit + 6 co-authored verifiers +
        references/model-routing.md ## Anomaly Records section.
- T03 — phase-suite aggregator + recent-changes dual-write + close.

Phase-suite green: p06-phase-suite.sh pass=8 fail=0 across all
sub-gates (sc11-byte-equality, shadow-off-byte-equality, mechanical-
regression, standard-regression, novel-regression, no-regression,
below-min-sample, doctor-surfaces-anomaly).

CON-2 / FR-19 / SC-11 byte-equality preserved through both surfaces:
- check-anomalies.sh: when no class crosses threshold, emits zero
  additional stdout and appends zero JSONL records.
- dispatch-interface.sh: shadow-off branch byte-untouched (P02's
  p02-additive-schema.sh re-confirms post-amendment).

CON-3 closure preserved: zero new hardcoded model IDs.

Closes M030/P06 per M030-ROADMAP.md acceptance line 57. P07
(end-to-end shadow-corpus + flip-gate validation, the milestone-close
gate) consumes P06's anomaly-record signal as part of the M030
acceptance battery.
```

The commit is authored via:

```bash
git add tests/fixtures/m030-p06/ \
        scripts/dispatch/dispatch-interface.sh \
        scripts/diagnostics/check-anomalies.sh \
        references/model-routing.md \
        tools/verify/p06-*.sh \
        CLAUDE.md AGENTS.md \
        .orchestrator/milestones/M030/phases/P06/

git commit -F .orchestrator/milestones/M030/phases/P06/COMMIT-MSG.txt

rm .orchestrator/milestones/M030/phases/P06/COMMIT-MSG.txt
```

`git add` is multi-line for readability; the actual invocation is one `git add` per line OR a single `git add` with all paths (per AD-19 single-script-file discipline, prefer `git add` per-path-set if any path-glob has a special character; here all globs are simple so a single multi-arg `git add` is fine). The harness's pre-bash-shape-guard accepts `git add A B C D` as a single command; the chain rejection only fires on `&&`/`;`/`|` compound shapes.

The `git commit -F <file>` form is mandatory — the inline-HEREDOC form `git commit -m "$(cat <<'EOF'...)"` trips AP-008.

### P06-SUMMARY.md authoring

T03 also authors [`.orchestrator/milestones/M030/phases/P06/P06-SUMMARY.md`](../../../../../milestones/M030/phases/P06/P06-SUMMARY.md) per the schema established by P02-P05 summaries. Frontmatter shape:

```yaml
---
schema_version: "1.0"
type: phase-summary
id: "P06"
parent: "M030"
milestone: "M030"
provides:
  - "tests/fixtures/m030-p06/synthesize-corpus.sh,tests/fixtures/m030-p06/regression-mechanical.jsonl,tests/fixtures/m030-p06/regression-standard.jsonl,tests/fixtures/m030-p06/regression-novel.jsonl,tests/fixtures/m030-p06/no-regression.jsonl,tests/fixtures/m030-p06/below-min-sample.jsonl,tests/fixtures/m030-p06/check-anomalies-pre-m030-baseline.txt,scripts/dispatch/dispatch-interface.sh shadow-on character field,scripts/diagnostics/check-anomalies.sh _ca_model_routing_regression_check function + CLI integration,references/model-routing.md ## Anomaly Records section,tools/verify/p06-sc11-byte-equality.sh,tools/verify/p06-shadow-off-byte-equality.sh,tools/verify/p06-mechanical-regression.sh,tools/verify/p06-standard-regression.sh,tools/verify/p06-novel-regression.sh,tools/verify/p06-no-regression.sh,tools/verify/p06-below-min-sample.sh,tools/verify/p06-doctor-surfaces-anomaly.sh,tools/verify/p06-phase-suite.sh straight-line aggregator over 8 P06 sub-gates,CLAUDE.md+AGENTS.md recent-changes P06-close fragment,P06 close commit"
requires:
  - "P02,P04"
affects:
  - "P07"
key_files:
  - "tests/fixtures/m030-p06/synthesize-corpus.sh,tests/fixtures/m030-p06/regression-mechanical.jsonl,tests/fixtures/m030-p06/regression-standard.jsonl,tests/fixtures/m030-p06/regression-novel.jsonl,tests/fixtures/m030-p06/no-regression.jsonl,tests/fixtures/m030-p06/below-min-sample.jsonl,tests/fixtures/m030-p06/check-anomalies-pre-m030-baseline.txt,scripts/dispatch/dispatch-interface.sh,scripts/diagnostics/check-anomalies.sh,references/model-routing.md,tools/verify/p06-sc11-byte-equality.sh,tools/verify/p06-shadow-off-byte-equality.sh,tools/verify/p06-mechanical-regression.sh,tools/verify/p06-standard-regression.sh,tools/verify/p06-novel-regression.sh,tools/verify/p06-no-regression.sh,tools/verify/p06-below-min-sample.sh,tools/verify/p06-doctor-surfaces-anomaly.sh,tools/verify/p06-phase-suite.sh,CLAUDE.md,AGENTS.md,.orchestrator/milestones/M030/phases/P06/P06-PLAN.md"
key_decisions:
  - "#Q-4 plan-phase decision: fixed pass-rate threshold (default 0.50) + min_class_sample floor (default 10); env-only JSONL emit path (M030_ANOMALIES_JSONL_PATH) instead of CLI flag to keep surface narrow,additive character field on shadow-on dispatch_usage records (additive — SC-11-preserving) chosen over fragile tier-to-class inverse routing-table lookup; D-A9 anomaly JSONL snapshot convention satisfied via append-only invariant on .orchestrator/anomalies.jsonl,phase-suite-shape-mirrors-p02-p03-p04-p05-straight-line-AD-19-no-loops"
patterns_established:
  - "additive-field-on-shadow-on-emit pattern (P02/T02 + P04/T03 lineage extended): single field appended to printf format string + arg list on shadow-on branch only; shadow-off branch byte-untouched; SC-11 contract via P02 p02-additive-schema.sh delegate-and-pass-through wrapper,env-var-seam-for-anomaly-jsonl-redirection (M030_ANOMALIES_JSONL_PATH; mirrors M030_SHADOW_MODE / M030_SHADOW_COMPARE_CORPUS / M030_ROUTING_TABLE_PATH precedents),append-only anomalies.jsonl emit via >> redirect with mkdir -p guard; CON-6 invariant extended from execution-log.jsonl to anomalies.jsonl,phase-suite-aggregator-extends-from-7-gates-P05-to-8-gates-P06-without-shape-change"
drill_down_paths:
  - ".orchestrator/milestones/M030/phases/P06/tasks/T01-fixtures-and-baseline-SUMMARY.md, .orchestrator/milestones/M030/phases/P06/tasks/T02-anomaly-check-and-emit-SUMMARY.md, .orchestrator/milestones/M030/phases/P06/tasks/T03-phase-suite-and-close-SUMMARY.md"
duration: "<actual-minutes>m"
verification_result: "pass"
completed_at: "<ISO8601>"
observability_surfaces:
  - "check-anomalies-model-routing-regression+anomalies.jsonl"
---

P06 closes the FR-18 anomaly-driven regression detection surface for M030: ...
```

Body shape mirrors P05-SUMMARY.md (sections: brief intro, "What was built" per task, "Verification", "Key decisions", "Patterns established", "Provides downstream", "Roadmap impact").

### Phase-grain unit_close JSONL append

T03 appends a phase-grain `unit_close` record to `.orchestrator/milestones/M030/execution-log.jsonl`:

```json
{"record_type":"unit_close","granularity":"phase","unitId":"M030/P06","milestone":"M030","phase":"P06","outcome":"pass","verification_pass_rate":1.00,"completed_at":"<ISO8601>","duration_s":<duration>}
```

The exact field set follows the existing M030 pattern in execution-log.jsonl (P00-P05 already have these records). Append via `>> .orchestrator/milestones/M030/execution-log.jsonl` (single-redirect-builtin shape; no compound chain).

## Steps

1. **Confirm T01+T02 deliverables are green** by running each verifier in turn:

   ```bash
   bash tools/verify/p06-sc11-byte-equality.sh
   bash tools/verify/p06-shadow-off-byte-equality.sh
   bash tools/verify/p06-mechanical-regression.sh
   bash tools/verify/p06-standard-regression.sh
   bash tools/verify/p06-novel-regression.sh
   bash tools/verify/p06-no-regression.sh
   bash tools/verify/p06-below-min-sample.sh
   bash tools/verify/p06-doctor-surfaces-anomaly.sh
   ```

   Expected: all eight exit 0 with `SUMMARY: <verifier-name> pass=N fail=0`. If any fail, halt T03 and re-open the relevant T01/T02 task.

2. **Author `tools/verify/p06-phase-suite.sh`** per the shape in the Description. Make executable.

3. **Self-check the phase-suite**:

   ```bash
   bash tools/verify/p06-phase-suite.sh
   ```

   Expected: exit 0 with `SUMMARY: p06-phase-suite.sh pass=8 fail=0`.

4. **Run `scripts/verify/check-must-haves.sh`** against the phase plan to confirm all truths + artifacts + key-links pass:

   ```bash
   bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P06
   ```

   Expected: all PASS. If any fail, the plan-amendment-not-task-reopen pattern from P02/T04, P03/T04, P04/T04, P05/T03 applies — most failures here are artifact-grep predicates that diverged between the plan declaration and the actual file content (e.g., a `contains "X"` predicate where the actual file uses "Y"). Amend the plan, NOT the deliverable, when the deliverable shape is correct and the predicate was the wrong shape.

5. **Author [`.orchestrator/milestones/M030/phases/P06/P06-SUMMARY.md`](../../../../../milestones/M030/phases/P06/P06-SUMMARY.md)** per the schema in the Description. Use the P05-SUMMARY.md as the structural template (frontmatter + body sections).

6. **Append the phase-grain unit_close record** to `.orchestrator/milestones/M030/execution-log.jsonl`. Build the JSON line via `printf` and append:

   ```bash
   ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
   duration_s="<measure or estimate>"
   printf '{"record_type":"unit_close","granularity":"phase","unitId":"M030/P06","milestone":"M030","phase":"P06","outcome":"pass","verification_pass_rate":1.00,"completed_at":"%s","duration_s":%s}\n' "$ts" "$duration_s" >> .orchestrator/milestones/M030/execution-log.jsonl
   ```

7. **Dual-write the recent-changes fragment** to BOTH `CLAUDE.md` and `AGENTS.md`:

   ```bash
   bash scripts/util/dual-write-runtime-md.sh --append-entry "M030/P06: anomaly-driven regression detection — model_routing_regression check + JSONL emit + dispatch-interface character emit."
   ```

   If the helper trims to a 1-entry bound and the operator wants to preserve the prior P05 entry, use the Edit tool to manually insert the P06 line into both files' sentinel blocks instead — see Description for context.

8. **Author the close commit message file** at `.orchestrator/milestones/M030/phases/P06/COMMIT-MSG.txt` using the Write tool. Body per the Description.

9. **Stage all P06 deliverables**:

   ```bash
   git add tests/fixtures/m030-p06/ scripts/dispatch/dispatch-interface.sh scripts/diagnostics/check-anomalies.sh references/model-routing.md tools/verify/p06-sc11-byte-equality.sh tools/verify/p06-shadow-off-byte-equality.sh tools/verify/p06-mechanical-regression.sh tools/verify/p06-standard-regression.sh tools/verify/p06-novel-regression.sh tools/verify/p06-no-regression.sh tools/verify/p06-below-min-sample.sh tools/verify/p06-doctor-surfaces-anomaly.sh tools/verify/p06-phase-suite.sh CLAUDE.md AGENTS.md .orchestrator/milestones/M030/phases/P06/ .orchestrator/milestones/M030/execution-log.jsonl
   ```

   (Single `git add` invocation with all paths as positional args — no compound chain.)

10. **Confirm staged diff is what you expect**:

    ```bash
    git diff --cached --stat
    ```

    Expected: ~20-25 files staged (see deliverable list); no unintended additions; no `.orchestrator/milestones/M030/phases/P06/COMMIT-MSG.txt` in the staged diff (it's a temporary file we delete after the commit).

11. **Author the commit**:

    ```bash
    git commit -F .orchestrator/milestones/M030/phases/P06/COMMIT-MSG.txt
    ```

    Expected: clean commit, no pre-commit hook failure. Capture the commit SHA.

12. **Delete the temporary commit-message file**:

    ```bash
    rm .orchestrator/milestones/M030/phases/P06/COMMIT-MSG.txt
    ```

    No `git rm` — the file was never committed.

13. **Run the phase-suite one final time** to confirm everything is green post-commit:

    ```bash
    bash tools/verify/p06-phase-suite.sh
    ```

    Expected: exit 0 with `SUMMARY: p06-phase-suite.sh pass=8 fail=0`.

14. **Run the milestone validator**:

    ```bash
    bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M030
    ```

    Expected: 145/146 passes (P06 SUMMARY now present; P07 SUMMARY still missing — which is the next phase). If 145/146 is NOT the result, investigate before reporting P06 close to the operator.

## Must-Haves

T03 satisfies the following phase truth:

- "`bash tools/verify/p06-phase-suite.sh` invokes all eight P06 sub-gates in literal sequence, exits 0 iff every sub-gate passes, and emits `SUMMARY: p06-phase-suite.sh pass=N fail=M` on a single line before exit." — gated by `bash tools/verify/p06-phase-suite.sh` (T03 deliverable).

The P06-SUMMARY.md, recent-changes dual-write, phase-grain unit_close, and close commit are NOT phase-truths gated by `check-must-haves.sh` — they are phase-close ceremony deliverables verified by `validate-milestone.sh` (which checks for the existence of `P06-SUMMARY.md` with valid frontmatter + key_files all on disk).

## Verification

```bash
bash tools/verify/p06-phase-suite.sh
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P06
bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M030
```

Single-script-file shape per AD-19. All three must exit 0 (or in the validate-milestone.sh case, report 145/146 with the only remaining failure being P07 summary missing) before T03 closes.

## Inputs

### From Previous Tasks (T01 + T02)

- All eight verifier scripts at `tools/verify/p06-*.sh` (T01 ships sc11-byte-equality; T02 ships the rest).
- Five fixture corpora at `tests/fixtures/m030-p06/` (T01).
- Pre-amendment golden at `tests/fixtures/m030-p06/check-anomalies-pre-m030-baseline.txt` (T01).
- Amended `scripts/dispatch/dispatch-interface.sh` (T02).
- Amended `scripts/diagnostics/check-anomalies.sh` (T02).
- Amended `references/model-routing.md` (T02).

### From Disk (Pre-existing)

- `scripts/util/dual-write-runtime-md.sh` — Key API: `bash <path> --append-entry "<one-line-text>"`. Locates the `>>> orchestrator:recent-changes >>>` and `<<< orchestrator:recent-changes <<<` sentinel block in both `CLAUDE.md` and `AGENTS.md`, prepends the entry, optionally trims to a configured bound. Used by T03 step 7.
- `scripts/verify/check-must-haves.sh` — Key API: `bash <path> <phase-dir>`. Reads the phase plan's Must-Haves section + checks each truth's `Check:` command + each artifact's existence + grep predicates + line-count floor + each key-link's source-file → target-basename grep. Exit 0 on all PASS.
- `scripts/verify/validate-milestone.sh` — Key API: `bash <path> <milestone-dir>`. Reads each phase's `P##-SUMMARY.md` frontmatter + checks key_files existence + boundary-map produces vs. consumes graph closure. Reports `VALIDATE: <pass>/<total>`. Used by T03 step 14.
- `git` — for staging + committing. T03 uses `git commit -F <file>` (multi-line body) or `git commit -m "..."` (single-line). NEVER `git commit -m "$(cat <<'EOF'...)"` (AP-008).
- `.orchestrator/milestones/M030/execution-log.jsonl` — append-only JSONL log. T03 appends a phase-grain `unit_close` record at step 6.

## Constraints

- **AD-19 single-script-file shape**: every verifier under `tools/verify/p06-*` is invoked as a single `bash <path>`. The phase-suite aggregator's body uses straight-line invocation (no loops over a sub-gate list).
- **AP-008 heredoc-with-expansion**: T03 uses `git commit -F <file>` to author the multi-line commit message — never the inline `git commit -m "$(cat <<'EOF'...EOF)"` form.
- **AP-009 compound-chain-gt2**: phase-suite aggregator + step commands use straight-line shape. The `git add` invocation in step 9 is a single command with multiple positional args (single-builtin-shape with N args is NOT a compound chain).
- **Bash 3.2 compatibility**: phase-suite uses parallel scalars + `if`-statements. No `declare -A`, no `mapfile`.
- **MEM004 emitter-internal carve-out**: does NOT apply to T03 (no emitter amendment in T03).
- **Plan-Time Discipline rule 2 (verifier-availability cross-check)**: every command in T03's `## Verification` section resolves to an existing-on-disk script post-T01+T02. Verified at plan-authoring time.
- **Plan-Time Discipline rule 4 (run-probe.sh scope)**: T03 invokes verifiers under `tools/verify/` and `scripts/verify/` directly via `bash <path>`. No `run-probe.sh` invocations.
- **Project-owned-verifier-paths discipline ([M032](../../../../../milestones/M032/index.md) Finding A)**: phase-suite aggregator lives under `tools/verify/` with slug-bearing filename `p06-phase-suite.sh`.
- **Commit message authoring discipline (CLAUDE.md guidance)**: `git commit -F <message-file>` only; no inline `$(cat <<'EOF'...EOF)` HEREDOC form.

## Expected Output

- `tools/verify/p06-phase-suite.sh` — straight-line aggregator over 8 sub-gates; exits 0 iff all pass; emits `SUMMARY: p06-phase-suite.sh pass=8 fail=0`.
- [`.orchestrator/milestones/M030/phases/P06/P06-SUMMARY.md`](../../../../../milestones/M030/phases/P06/P06-SUMMARY.md) — phase-summary file per the schema in the Description.
- `.orchestrator/milestones/M030/execution-log.jsonl` — appended with phase-grain `unit_close` record for M030/P06.
- `CLAUDE.md` + `AGENTS.md` — recent-changes sentinel block updated with P06-close fragment via dual-write helper.
- One git commit: `M030/P06: anomaly-driven regression detection (model_routing_regression check + dispatch-interface character emit)` with the multi-line body authored via `-F <file>`.
- `validate-milestone.sh` reports 145/146 (only P07 SUMMARY missing — the next phase).

## Notes

Expected output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p06-phase-suite.sh` → `SUMMARY: p06-phase-suite.sh pass=8 fail=0`, exit 0.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P06` → all truths + artifacts + key-links PASS, exit 0.
- `bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M030` → `VALIDATE: FAIL — 145/146 checks passed, 1 failed; Failures: - P07: summary missing`, exit 1. (The 1 failure is expected — P07 is the next phase. The validator exit-1 here is NOT a T03 blocker.)
- `git log --oneline -3` (post-T03) →
  ```
  <SHA> M030/P06: anomaly-driven regression detection (model_routing_regression check + dispatch-interface character emit)
  <SHA> docs: M028 close ack + M030 in-progress audit + fold in [M036](../../../../../milestones/M036/index.md) capture
  <SHA> M036 capture: reference-corpus ingest (spec + planning artifacts + brief)
  ```

The plan-amendment-not-task-reopen pattern (P02/T04 + P03/T04 + P04/T04 + P05/T03 precedent) applies if `check-must-haves.sh` reports a failure on an artifact-grep or key-link-direction predicate. Investigate first whether the predicate or the deliverable is wrong; if the deliverable is shaped correctly and the predicate was authored against an aspirational shape that diverged, amend the predicate in `P06-PLAN.md` directly and re-run `check-must-haves.sh`. If the deliverable IS wrong, re-open the relevant T01/T02 task.

If `dual-write-runtime-md.sh` doesn't exist or behaves differently than described, the operator may instead use the Edit tool to manually insert the P06 line into both `CLAUDE.md` and `AGENTS.md` sentinel blocks. The dual-write helper is the canonical mechanism but the manual fallback is acceptable — the goal is the same (a single recent-changes line in both files).

If the M030 execution-log.jsonl phase-grain unit_close append shape doesn't match the existing P00-P05 pattern (because those summaries used a different field set), ALIGN to the existing pattern by reading the last few lines of `.orchestrator/milestones/M030/execution-log.jsonl` before authoring the append. The M030 P00-P05 records ARE the schema reference; T03's append must be field-compatible.

If the close commit's message file path conflicts with anything (the `.orchestrator/milestones/M030/phases/P06/` directory doesn't exist at T03 entry — T01 + T02 may not have written into it directly), `mkdir -p .orchestrator/milestones/M030/phases/P06/` first, OR write the commit-message file to `/tmp/p06-commit-msg.txt` instead. The path is incidental; the commit body is the contract.

If the milestone validator at step 14 reports a failure other than "P07: summary missing" (e.g., one of P06's key_files predicates fails because the staging-format diverged from what's in P06-SUMMARY.md frontmatter), STOP and investigate. Do NOT push the commit upstream until the validator state is clean modulo the expected P07 deficit. The plan-amendment-not-task-reopen pattern applies again at this layer — most validator failures here are stale-frontmatter-vs-disk drift.
