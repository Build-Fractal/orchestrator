---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P07"
milestone: "M030"
name: "M030 milestone close ceremony — P07-SUMMARY + phase-grain unit_close + M030-VALIDATED + M030-SUMMARY + milestone-grain unit_close + close commit"
depends_on: ["T03"]
---

## Prerequisites

- T01 + T02 + T03 deliverables on disk and green:
  - All four corpora at `tests/m030-acceptance/` (T01).
  - `tests/m030-acceptance/shadow-corpus-fixtures.sh` (T01).
  - `tests/m030-acceptance/run-acceptance-battery.sh` (T02).
  - All nine P07 verifiers at `tools/verify/p07-*.sh` (T01 ships 5; T02 ships 3; T03 ships the ledger gate + the phase-suite aggregator).
  - [`.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M030/M030-ACCEPTANCE-EVIDENCE.md) (T03).
- `bash tools/verify/p07-phase-suite.sh` exits 0 with `SUMMARY: p07-phase-suite.sh pass=9 fail=0`.
- `bash tests/m030-acceptance/run-acceptance-battery.sh` exits 0 with `BATTERY: pass=N fail=0`.
- All seven prior phase summaries exist at `.orchestrator/milestones/M030/phases/P0[0-6]/P0[0-6]-SUMMARY.md`.
- No `M030-VALIDATED` marker file yet at `.orchestrator/milestones/M030/M030-VALIDATED` (T04 creates it).
- No `M030-SUMMARY.md` yet at [`.orchestrator/milestones/M030/M030-SUMMARY.md`](../../../../../milestones/M030/M030-SUMMARY.md) (T04 creates it).
- `scripts/lifecycle/mark-complete.sh` exists and creates the `M###-VALIDATED` marker.
- `scripts/util/dual-write-runtime-md.sh` exists with `--append-entry` flag.
- `scripts/verify/validate-milestone.sh` exists and reports VALIDATE: lines.

Plan-time prerequisite-existence verification: every script + state path above is asserted via `[ -f <path> ]` at plan-authoring time. Confirmed during P07 plan authoring.

## Description

T04 is the milestone close ceremony. Structurally distinct from T01-T03 (which are phase-grain) — T04 ships the milestone-grain artifacts that make `M030` a closed milestone. Five deliverable groups:

1. **P07-SUMMARY.md** — phase-summary file for P07 itself, mirrors P02-P06 schema.
2. **Phase-grain `unit_close` for M030/P07** — appended to `.orchestrator/milestones/M030/execution-log.jsonl`.
3. **M030-VALIDATED marker** — created by `bash scripts/lifecycle/mark-complete.sh .orchestrator M030` after every P0[0-7]-SUMMARY.md exists. Per `scripts/lifecycle/mark-complete.sh` body, the marker carries the milestone ID + validation timestamp + phase_count=8 + per-phase complete/incomplete listing.
4. **M030-SUMMARY.md** — milestone-summary file authored by T04 mirroring [`.orchestrator/milestones/M028/M028-SUMMARY.md`](../../../../../milestones/M028/M028-SUMMARY.md) schema (frontmatter `type: milestone-summary` + body sections: brief intro, per-phase what-was-built, verification, key decisions, patterns established, roadmap impact, what's next).
5. **Milestone-grain `unit_close` for M030** — appended to `.orchestrator/milestones/M030/execution-log.jsonl` (the milestone's own log) AND optionally to `.orchestrator/execution-log.jsonl` if the orchestrator-grain log exists.
6. **Recent-changes dual-write** — TWO entries via `scripts/util/dual-write-runtime-md.sh --append-entry`: one for P07 close + one for M030 close (or one combined entry covering both).
7. **CLAUDE.md project-status update** — flips M030 from "in progress" to "Closed" in the forward-roadmap section; updates the recent-changes block via the dual-write helper.
8. **Close commit** — single atomic commit titled `M030: adaptive model selection (closed)`. Multi-line body authored via `git commit -F <message-file>`.
9. **Final validate-milestone.sh clean pass** — `bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M030` exits 0 with `VALIDATE: PASS — N/N checks passed`.

### Why T04 is structurally distinct from P02-P06 closes

P02-P06 closes shipped a single phase-close ceremony (P##-SUMMARY.md + phase-grain unit_close + dual-write + commit). M030's last phase is structurally different: P07 is BOTH the last phase AND the milestone. T04 fuses the two ceremonies into one atomic commit because:

- Splitting them creates a fragile two-commit close where the first commit (phase close) leaves the milestone in a half-closed state.
- The milestone-validate gate (`validate-milestone.sh`) wants every phase summary AND the M030-VALIDATED marker present simultaneously. The M030-VALIDATED marker can only be created AFTER P07-SUMMARY.md exists; the marker itself is the contract that flips the milestone from `validating` to `completed`.
- The recent-changes dual-write covers both the phase close and the milestone close in a single block (`M030/P07: <phase-close-text>` + `M030: closed` separate entries).

### M030-SUMMARY.md authoring

Schema mirrors [`.orchestrator/milestones/M028/M028-SUMMARY.md`](../../../../../milestones/M028/M028-SUMMARY.md). Frontmatter:

```yaml
---
schema_version: "1.0"
type: milestone-summary
id: "M030"
parent: "032-adaptive-model-selection"
milestone: "M030"
provides:
  - "<comma-separated list of every M030 deliverable, organized by phase: P00 fixture corpus + labels.yml; P01 classify-task.sh + model-routing.yml + cost_rates SSOT; P02 dispatch-interface shadow-mode + shadow-compare.sh 4-verdict; P03 overrides + kill switch + override_source enum; P04 live routing + escalation + flip-gate enforcement + escalation_cap; P05 metrics-rollup --by-model + efficiency-footer model_mix + doctor --config-check; P06 check-anomalies model_routing_regression + dispatch-interface character emit + anomalies.jsonl; P07 acceptance corpus + run-acceptance-battery.sh + M030-ACCEPTANCE-EVIDENCE.md ledger>"
requires:
  - "M027 cost-rollup JSONL stream (dispatch_usage, unit_close); M027 anomaly detection (check-anomalies.sh); M025 installer coexistence (.orchestrator/config.yml overlay convention); M028 autonomous-hardening v3 (hook portability for clean shadow-corpus signal in autonomous runs); A-1..A-6 spec assumptions"
affects:
  - "M031 (right-sized entry — Quick intensity now bypasses dispatch-interface model-routing layer; M031 must restore the routing layer access for Quick intensity); M027 cost-observability surfaces (M030 extends additively via FR-15/FR-16/FR-17/FR-18); every future M030+ milestone (default flip is shadow-mode; live routing is operator-opt-in via .orchestrator/config.yml model_routing.live: true); operator-facing cost reporting (model_mix: footer + by-model rollup are the canonical surfaces)"
key_files:
  - "scripts/dispatch/classify-task.sh,scripts/dispatch/dispatch-interface.sh,scripts/diagnostics/shadow-compare.sh,scripts/diagnostics/metrics-rollup.sh,scripts/diagnostics/efficiency-footer.sh,scripts/diagnostics/check-anomalies.sh,scripts/diagnostics/doctor.sh,templates/model-routing.yml,references/model-routing.md,references/observability.md,tests/fixtures/m030-classifier-corpus/labels.yml,tests/fixtures/m030-classifier-corpus/README.md,tests/fixtures/m030-p02/sc3a-roundtrip-corpus.jsonl,tests/fixtures/m030-p02/shadow-corpus-ready.jsonl,tests/fixtures/m030-p02/shadow-corpus-partially-ready.jsonl,tests/fixtures/m030-p02/shadow-corpus-block.jsonl,tests/fixtures/m030-p02/shadow-corpus-evidence-insufficient.jsonl,tests/fixtures/m030-p06/regression-mechanical.jsonl,tests/fixtures/m030-p06/regression-standard.jsonl,tests/fixtures/m030-p06/regression-novel.jsonl,tests/m030-acceptance/shadow-corpus-fixtures.sh,tests/m030-acceptance/corpus-50-per-class.jsonl,tests/m030-acceptance/corpus-2-class-only.jsonl,tests/m030-acceptance/run-acceptance-battery.sh,tools/verify/p07-phase-suite.sh,.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md,.orchestrator/milestones/M030/phases/P00/P00-SUMMARY.md,.orchestrator/milestones/M030/phases/P01/P01-SUMMARY.md,.orchestrator/milestones/M030/phases/P02/P02-SUMMARY.md,.orchestrator/milestones/M030/phases/P03/P03-SUMMARY.md,.orchestrator/milestones/M030/phases/P04/P04-SUMMARY.md,.orchestrator/milestones/M030/phases/P05/P05-SUMMARY.md,.orchestrator/milestones/M030/phases/P06/P06-SUMMARY.md,.orchestrator/milestones/M030/phases/P07/P07-SUMMARY.md"
key_decisions:
  - "<comma-separated synthesis of D-A1 through D-A9 (M030-CONTEXT.md), plus per-phase plan-time decisions: P01 classifier-confidence stability metric definition; P02 shadow-corpus path-resolution priority + 4-verdict closed-enum; P03 override-source enum closure + kill-switch precedence over min_tier; P04 escalation-cap + flip-gate programmatic enforcement; P05 cost_rates-absent fallback (warning + zero-savings) + ORCHESTRATOR_ROOT carve-out for footer fixtures; P06 #Q-4 threshold default (pass_rate 0.50 + min_class_sample 10) + env-only JSONL emit path; P07 4-task split (corpus + battery + ledger + close-ceremony) + structurally-distinct T04 ceremony fusing phase + milestone close>"
patterns_established:
  - "<comma-separated synthesis of patterns established across P00-P07: pre-implementation fixture corpus + version-controlled labels (P00); classifier-as-pure-bash + heuristic-table-as-SSOT (P01); 4-verdict closed-enum shadow-compare (P02); additive-jsonl-schema CON-2/FR-19 preserved across 6 schema extensions (P02-P06); pre-amendment golden-baseline + delegate-and-pass-through cross-phase wrappers (P05/T01 inverted P04/T01 pattern); ORCHESTRATOR_ROOT carve-out for fixture-routing without modifying the surface's resolver (P05/T01); additive-field-on-shadow-on-emit (P02/T02 + P04/T03 + P06/T02 lineage); env-var-seam-for-{shadow-mode,corpus-path,routing-table-path,anomaly-jsonl-path} convention; phase-suite straight-line aggregator (P02-P07 all share the no-loops-no-eval shape); plan-amendment-not-task-reopen pattern applied at every phase close for artifact-grep predicate divergences; structurally-distinct T04 ceremony fusing phase + milestone close (P07 only); idempotent corpus synthesizer + sha256-equality verifier (P05/T01 + P06/T01 + P07/T01); acceptance-battery as straight-line SC delegator (P07/T02); one-shot evidence ledger pattern at milestone close (P07/T03)>"
drill_down_paths:
  - ".orchestrator/milestones/M030/phases/P00/P00-SUMMARY.md, .orchestrator/milestones/M030/phases/P01/P01-SUMMARY.md, .orchestrator/milestones/M030/phases/P02/P02-SUMMARY.md, .orchestrator/milestones/M030/phases/P03/P03-SUMMARY.md, .orchestrator/milestones/M030/phases/P04/P04-SUMMARY.md, .orchestrator/milestones/M030/phases/P05/P05-SUMMARY.md, .orchestrator/milestones/M030/phases/P06/P06-SUMMARY.md, .orchestrator/milestones/M030/phases/P07/P07-SUMMARY.md, .orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md"
duration: "<sum of P00-P07 durations from per-phase summaries; report in minutes>"
verification_result: "pass"
completed_at: "<ISO8601-timestamp>"
observability_surfaces:
  - "metrics-rollup --by-model; efficiency-footer model_mix:; doctor --config-check; check-anomalies model_routing_regression; shadow-compare 4-verdict; M030-ACCEPTANCE-EVIDENCE.md ledger; classifier-confidence stability metric in shadow-compare per-class evidence lines"
---
```

Body sections (brief intro + 8 per-phase what-was-built paragraphs + verification + key decisions + patterns + roadmap impact + what's next):

```markdown
M030 (adaptive model selection) closed: a task-character classifier routes each dispatch to the cheapest single model that can do the job correctly, with a two-layer safety story — pre-flip classifier-calibration evidence (FR-7/FR-8 shadow corpus + 4-verdict shadow-compare) and post-flip regression-detection mesh (FR-10 verifier-fail escalation + FR-18 per-class anomaly detection + CON-4 operator kill switch). Eight phases (P00-P07) closed end-to-end across <duration> minutes; 14 success criteria (SC-1 through SC-11 inclusive of SC-2a/SC-3a/SC-7a) verified via the M030 acceptance battery (`tests/m030-acceptance/run-acceptance-battery.sh`); evidence captured at `.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md`.

P00 (Fixture corpus + ground-truth labels, <duration>m) shipped <P00-summary>...

P01 (Classifier + routing table + cost_rates, <duration>m) shipped <P01-summary>...

[... per-phase paragraphs for P00-P07 mirroring M028-SUMMARY.md body shape ...]

Verification result: 14/14 SCs pass via the M030 acceptance battery. Phase-suite green at every phase (P00-P07). validate-milestone.sh reports N/N checks passed.

Key decisions: <synthesis from frontmatter>.

Patterns established: <synthesis from frontmatter>.

Roadmap impact: M030 ships shadow-mode by default. Operators activate live routing via `.orchestrator/config.yml model_routing.live: true`; the FR-9 programmatic flip-gate refuses live routing if the shadow corpus is below threshold. The flip is per-project + reversible. Pre-launch CC-only posture preserved — Codex CLI + Cursor adapters resolve any symbolic tier to `inherit` per FR-6.

Real-app smoke test pending: M030 ships against synthetic acceptance corpora (`tests/m030-acceptance/corpus-50-per-class.jsonl` is hand-crafted with 50 records/class). Real shadow-mode dispatches against pre-launch milestones (M031-M035) are the n=1 in-the-wild validator. Operators activating live routing should run >=50 shadow-mode dispatches per class against their own milestone history before flipping `model_routing.live: true`. The FR-9 programmatic flip-gate enforces this: insufficient corpus = `shadow_gate_blocked` JSONL record, no adapter call.

What's next: M031 (right-sized entry) restores knowledge-graph + compression access for Quick intensity (today `commands/dispatch.md:21` skips `build-context.sh` — load-bearing leak that bypasses the M030 routing layer for Quick-intensity tasks). M031 + M030 compose as the thrift-and-ergonomics pair. M032 (wiki distribution + init integration) and M033 (project onboarding) follow.
```

### Phase-grain unit_close shape

Field set per the existing M030 P00-P06 records in `.orchestrator/milestones/M030/execution-log.jsonl`. Read the last few lines BEFORE authoring the append to confirm the exact field set; M030's shape may differ slightly from the canonical (the P06 SUMMARY notes "the exact field set follows the existing M030 pattern"). Probable shape:

```json
{"record_type":"unit_close","granularity":"phase","unitId":"M030/P07","milestone":"M030","phase":"P07","outcome":"pass","verification_pass_rate":1.00,"completed_at":"<ISO8601>","duration_s":<duration>}
```

### Milestone-grain unit_close shape

```json
{"record_type":"unit_close","granularity":"milestone","unitId":"M030","milestone":"M030","outcome":"pass","verification_pass_rate":1.00,"completed_at":"<ISO8601>","duration_s":<sum-of-phase-durations>,"phase_count":8}
```

The exact field set should mirror [M028](../../../../../milestones/M028/index.md)'s milestone-grain unit_close if one exists; check `.orchestrator/milestones/M028/execution-log.jsonl` for the precedent. If no precedent exists, use the shape above and document the new convention in the T04 SUMMARY.

### Close commit message

File at `.orchestrator/milestones/M030/phases/P07/COMMIT-MSG.txt` (temporary, deleted post-commit). Body:

```
M030: adaptive model selection (closed)

Closes M030 (adaptive model selection). Eight phases (P00-P07) shipped
end-to-end; 14 success criteria verified via the M030 acceptance battery
at tests/m030-acceptance/run-acceptance-battery.sh. Evidence ledger at
.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md.

P07 deliverables (the milestone-close gate):
- tests/m030-acceptance/shadow-corpus-fixtures.sh — idempotent
  acceptance-corpus synthesizer (4 corpora: 50-per-class for ready;
  zero for evidence_insufficient; 2-class-only for partially_ready;
  block for the fourth verdict).
- tests/m030-acceptance/run-acceptance-battery.sh — straight-line
  end-to-end SC runner over 22 verifier invocations covering all 14
  M030 SCs (SC-1 through SC-11 inclusive of SC-2a/SC-3a/SC-7a).
- .orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md —
  one-shot evidence ledger of the green-run state.
- 9 P07 verifiers under tools/verify/p07-* (5 corpus gates + 3
  cross-surface gates + 1 phase-suite aggregator).
- M030-VALIDATED marker via scripts/lifecycle/mark-complete.sh.
- M030-SUMMARY.md milestone-summary.

Acceptance battery green: BATTERY: pass=N fail=0.
Phase-suite green: SUMMARY: p07-phase-suite.sh pass=9 fail=0.
validate-milestone.sh clean: VALIDATE: PASS — N/N checks passed.

Real-app smoke test discipline (Plan-Time Discipline rule 5): M030
ships shadow-mode by default. Live routing requires operator-set
model_routing.live: true PLUS a real shadow corpus passing the FR-9
flip-gate. The acceptance battery verifies the gate logic at
acceptance scale; live activation is downstream operator decision.

Closes M030 per .orchestrator/milestones/M030/M030-ROADMAP.md
acceptance line 64 (P07 boundary-map produce: end-to-end shadow-corpus
+ flip-gate validation).
```

## Steps

1. **Confirm T01+T02+T03 deliverables green** by running each verifier in turn:

   ```bash
   bash tools/verify/p07-phase-suite.sh
   ```

   Expected: `SUMMARY: p07-phase-suite.sh pass=9 fail=0`, exit 0. If FAIL, halt T04 and re-open the failing T0N task.

2. **Run the full acceptance battery one final time** to capture the green-run timestamp + duration:

   ```bash
   start_ts="$(date +%s)"
   bash tests/m030-acceptance/run-acceptance-battery.sh
   end_ts="$(date +%s)"
   battery_duration=$((end_ts - start_ts))
   ```

   Expected: `BATTERY: pass=N fail=0` on the last line. Capture N for the SUMMARY.

3. **Author [`.orchestrator/milestones/M030/phases/P07/P07-SUMMARY.md`](../../../../../milestones/M030/phases/P07/P07-SUMMARY.md)** per the P02-P06 schema. Body covers T01-T04 deliverables + verification + patterns + roadmap impact (P07 closes M030).

4. **Append phase-grain unit_close to execution-log.jsonl**. First read the last few existing lines to confirm the field set:

   ```bash
   tail -5 .orchestrator/milestones/M030/execution-log.jsonl
   ```

   Then append:

   ```bash
   ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
   duration_s="<phase-duration-in-seconds>"
   printf '{"record_type":"unit_close","granularity":"phase","unitId":"M030/P07","milestone":"M030","phase":"P07","outcome":"pass","verification_pass_rate":1.00,"completed_at":"%s","duration_s":%s}\n' "$ts" "$duration_s" >> .orchestrator/milestones/M030/execution-log.jsonl
   ```

5. **Run `scripts/lifecycle/mark-complete.sh` to create the M030-VALIDATED marker**:

   ```bash
   bash scripts/lifecycle/mark-complete.sh .orchestrator M030
   ```

   Expected: prints VALIDATE: lines for each phase + writes `.orchestrator/milestones/M030/M030-VALIDATED` with phase_count=8 + per-phase complete listing.

   The script's preflight-clean-root.sh check rejects a dirty working tree. T04 has uncommitted P07-SUMMARY.md + execution-log.jsonl changes at this point; the preflight may flag them. Two options:
   - Stage the P07-SUMMARY.md + execution-log.jsonl FIRST via `git add`, then run mark-complete.sh — the preflight allowlists staged scratch/result-file paths but not staged spec-tree edits. If the preflight rejects, set `ORCHESTRATOR_ALLOW_DIRTY_MARK=1` per the script body's documented escape hatch.
   - Run mark-complete.sh BEFORE staging, so the dirty paths are still untracked and the preflight allowlists them. Order is captured in step sequencing — mark-complete.sh runs at this step (5) BEFORE the close commit at step 12.

   The script writes `M030-VALIDATED` directly; the file is then staged at step 11.

6. **Author [`.orchestrator/milestones/M030/M030-SUMMARY.md`](../../../../../milestones/M030/M030-SUMMARY.md)** per the M028-SUMMARY.md schema. Use the Write tool. Body sections per the Description's milestone-summary skeleton. Read each P00-P07 SUMMARY.md to populate the per-phase paragraphs.

7. **Append milestone-grain unit_close to execution-log.jsonl**. Confirm the granularity field shape first by reading the last lines (M030's log may already have phase-grain records but no milestone-grain — T04's append is the first):

   ```bash
   total_duration_s="<sum-of-P00-through-P07-duration-fields>"
   ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
   printf '{"record_type":"unit_close","granularity":"milestone","unitId":"M030","milestone":"M030","outcome":"pass","verification_pass_rate":1.00,"completed_at":"%s","duration_s":%s,"phase_count":8}\n' "$ts" "$total_duration_s" >> .orchestrator/milestones/M030/execution-log.jsonl
   ```

8. **Update CLAUDE.md project-status section** via the Edit tool. The current text in CLAUDE.md says:

   ```
   **In progress**: **M030 (adaptive model selection)** — phases P00–P05 complete...
   ```

   Edit to:

   ```
   **Closed**: ...M028 (autonomous hardening v3), **M030 (adaptive model selection, 2026-04-30)**.
   ```

   And remove the multi-paragraph "in progress" + "operator decision pending" stanza around M030 in both the Project Status section AND the Forward Roadmap section. The Forward Roadmap stanza ("M030-close → [M031](../../../../../milestones/M031/index.md) → [M032](../../../../../milestones/M032/index.md) → ...") becomes "M031 → M032 → ..." with the M030 reference removed from the active queue and folded into the Closed section.

9. **Dual-write the recent-changes fragment** for M030 close. Two entries via dual-write helper:

   ```bash
   bash scripts/util/dual-write-runtime-md.sh --append-entry "M030: closed — adaptive model selection (8 phases, 14 SCs, acceptance battery green). M031 (right-sized entry) is next."
   ```

   If the helper trims to a 1-entry bound, manually edit both `CLAUDE.md` and `AGENTS.md` recent-changes blocks to insert the new line at the top while preserving the prior P06 entry.

10. **Author the close commit message file** at `.orchestrator/milestones/M030/phases/P07/COMMIT-MSG.txt` using the Write tool. Body per the Description's close commit message.

11. **Stage all P07 + M030-close deliverables**:

    ```bash
    git add tests/m030-acceptance/ tools/verify/p07-corpus-synthesizer-idempotent.sh tools/verify/p07-corpus-50-per-class-ready.sh tools/verify/p07-corpus-zero-evidence-insufficient.sh tools/verify/p07-corpus-2-class-partially-ready.sh tools/verify/p07-corpus-block.sh tools/verify/p07-partial-flip-jsonl-fields.sh tools/verify/p07-cross-surface-coherence.sh tools/verify/p07-acceptance-battery-pass.sh tools/verify/p07-acceptance-evidence-ledger.sh tools/verify/p07-phase-suite.sh .orchestrator/milestones/M030/phases/P07/ [.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md](../../../../../milestones/M030/M030-ACCEPTANCE-EVIDENCE.md) [.orchestrator/milestones/M030/M030-SUMMARY.md](../../../../../milestones/M030/M030-SUMMARY.md) .orchestrator/milestones/M030/M030-VALIDATED .orchestrator/milestones/M030/execution-log.jsonl CLAUDE.md AGENTS.md
    ```

    Single `git add` invocation with all paths as positional args.

12. **Confirm staged diff**:

    ```bash
    git diff --cached --stat
    ```

    Expected: ~25-30 files staged. No `COMMIT-MSG.txt` in the staged diff (it's deleted post-commit).

13. **Author the close commit**:

    ```bash
    git commit -F .orchestrator/milestones/M030/phases/P07/COMMIT-MSG.txt
    ```

    Expected: clean commit, no pre-commit hook failure. Capture the commit SHA.

14. **Delete the temporary commit-message file**:

    ```bash
    rm .orchestrator/milestones/M030/phases/P07/COMMIT-MSG.txt
    ```

15. **Run the milestone validator one final time**:

    ```bash
    bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M030
    ```

    Expected: `VALIDATE: PASS — N/N checks passed`, exit 0. ALL phase summaries (P00-P07) present; ALL boundary-map produces resolve. If FAIL, the failure is one of:
    - **A phase summary boundary-map predicate** — apply the plan-amendment-not-task-reopen pattern from P02-P06 precedent.
    - **A missing key_files path in M030-SUMMARY.md** — Edit the M030-SUMMARY.md frontmatter `key_files` to remove the missing path (or add the path if the file should exist).
    - **A genuine missing deliverable** — halt and address before continuing.

16. **Run the full P07 phase-suite + acceptance battery one last time post-commit** to confirm everything is green:

    ```bash
    bash tools/verify/p07-phase-suite.sh
    bash tests/m030-acceptance/run-acceptance-battery.sh
    ```

    Expected: phase-suite `pass=9 fail=0`, battery `pass=N fail=0`, both exit 0.

## Must-Haves

T04 satisfies the milestone-close ceremony — outputs gate the milestone close, not just the phase close:

- `.orchestrator/milestones/M030/M030-VALIDATED` exists with phase_count=8 and per-phase complete listing.
- [`.orchestrator/milestones/M030/M030-SUMMARY.md`](../../../../../milestones/M030/M030-SUMMARY.md) exists with `type: milestone-summary` frontmatter.
- [`.orchestrator/milestones/M030/phases/P07/P07-SUMMARY.md`](../../../../../milestones/M030/phases/P07/P07-SUMMARY.md) exists with `type: phase-summary` frontmatter.
- Phase-grain `unit_close` for `M030/P07` and milestone-grain `unit_close` for `M030` both appended to `.orchestrator/milestones/M030/execution-log.jsonl`.
- `bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M030` reports `VALIDATE: PASS — N/N checks passed` and exits 0.
- CLAUDE.md project-status section flips M030 from "in progress" to "Closed".
- Single atomic close commit titled `M030: adaptive model selection (closed)`.

These are NOT phase-truths gated by `check-must-haves.sh` — they are milestone-close ceremony deliverables verified by `validate-milestone.sh` + the artifact predicates declared in P07-PLAN.md.

## Verification

```bash
bash tools/verify/p07-phase-suite.sh
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M030/phases/P07
bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M030
```

All three must exit 0 before T04 closes.

## Inputs

### From Previous Tasks (T01 + T02 + T03)

- All P07 deliverables under `tests/m030-acceptance/`, `tools/verify/p07-*`, and [`.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md`](../../../../../milestones/M030/M030-ACCEPTANCE-EVIDENCE.md).

### From Disk (Pre-existing)

- `scripts/lifecycle/mark-complete.sh` — Key API: `bash <path> <orchestrator-root> <milestone-id>`. Verifies all phases have summaries, then writes `M###-VALIDATED` marker with milestone ID + timestamp + phase listing. Idempotent. Honors `ORCHESTRATOR_ALLOW_DIRTY_MARK=1` for emergency unblock.
- `scripts/util/dual-write-runtime-md.sh` — Key API: `bash <path> --append-entry "<one-line-text>"`. Locates `>>> orchestrator:recent-changes >>>` sentinel block in both CLAUDE.md and AGENTS.md, prepends entry, optionally trims.
- `scripts/verify/validate-milestone.sh` — Key API: `bash <path> <milestone-dir>`. Reads each phase's P##-SUMMARY.md frontmatter + checks key_files existence + boundary-map produces vs consumes graph closure. Reports `VALIDATE: <pass>/<total>`.
- `scripts/verify/check-must-haves.sh` — Key API: `bash <path> <phase-dir>`. Reads phase plan Must-Haves + checks each truth/artifact/key-link.
- `git` — for staging + committing. T04 uses `git commit -F <file>`.
- `.orchestrator/milestones/M030/execution-log.jsonl` — append-only JSONL. T04 appends two records (phase-grain + milestone-grain unit_close).
- [`.orchestrator/milestones/M028/M028-SUMMARY.md`](../../../../../milestones/M028/M028-SUMMARY.md) — schema reference for the M030-SUMMARY.md authoring.
- `.orchestrator/milestones/M028/M028-VALIDATED` — schema reference for the marker file shape (mark-complete.sh creates it; T04 doesn't author it directly).
- `CLAUDE.md` — project-status + forward-roadmap sections; T04 edits both to flip M030 from in-progress to Closed.
- `AGENTS.md` — recent-changes block; dual-written by the helper.

## Constraints

- **Atomic commit discipline**: T04 ships ONE commit covering the phase close + milestone close. No interim commits. Reason: milestone close is a single state transition; splitting creates a fragile half-closed state.
- **AP-008 heredoc-with-expansion**: T04 uses `git commit -F <file>` — never inline `git commit -m "$(cat <<'EOF'...)"`.
- **AP-009 compound-chain-gt2**: every step uses straight-line shape. The `git add` invocation in step 11 is a single command with multiple positional args.
- **Bash 3.2 compatibility**: parallel scalars + `if`-statements throughout.
- **MEM004 emitter-internal carve-out**: does NOT apply to T04.
- **Plan-Time Discipline rule 1 (prerequisite-existence verification)**: T04's prerequisites name several scripts (`mark-complete.sh`, `dual-write-runtime-md.sh`, `validate-milestone.sh`, `check-must-haves.sh`) — verified at plan-authoring time.
- **Plan-Time Discipline rule 2 (verifier-availability cross-check)**: T04's `## Verification` section names `p07-phase-suite.sh` (T03 deliverable) + `check-must-haves.sh` + `validate-milestone.sh` (pre-existing). All resolve at T04 entry post-T03 close.
- **Plan-Time Discipline rule 4 (run-probe.sh scope)**: T04 invokes scripts directly. No `run-probe.sh` wrapping.
- **Project-owned-verifier-paths discipline (M032 Finding A)**: phase-suite aggregator at `tools/verify/p07-phase-suite.sh` (slug-bearing).
- **Real-app smoke test discipline (Plan-Time Discipline rule 5)**: M030 ships against synthetic acceptance corpora; the M030-SUMMARY.md body explicitly documents this in its "Real-app smoke test pending" callout AND the close commit body names the FR-9 programmatic flip-gate as the in-the-wild safety mechanism for operator-driven live activation. Live routing remains shadow-mode-default; the milestone close does NOT activate live routing in any operator's project.
- **Constitution Principle II (Evidence Before Claims)**: M030-SUMMARY.md provenance points to M030-ACCEPTANCE-EVIDENCE.md + the green-run BATTERY line as the empirical basis for the closure claim. The shadow-mode-default + FR-9 flip-gate posture honors Principle II's "no claims that cannot be mechanically verified" requirement — M030 doesn't claim cross-model equivalence pre-flip; it claims classifier-confidence calibration pre-flip + post-flip regression detection (FR-10/FR-18/CON-4).

## Expected Output

- [`.orchestrator/milestones/M030/phases/P07/P07-SUMMARY.md`](../../../../../milestones/M030/phases/P07/P07-SUMMARY.md) — phase-summary file.
- [`.orchestrator/milestones/M030/M030-SUMMARY.md`](../../../../../milestones/M030/M030-SUMMARY.md) — milestone-summary file.
- `.orchestrator/milestones/M030/M030-VALIDATED` — marker file authored by mark-complete.sh.
- `.orchestrator/milestones/M030/execution-log.jsonl` — appended with phase-grain + milestone-grain unit_close.
- `CLAUDE.md` — project-status section updated; M030 flipped from in-progress to Closed; recent-changes block updated.
- `AGENTS.md` — recent-changes block updated.
- One git commit: `M030: adaptive model selection (closed)` with multi-line body authored via `-F <file>`.
- `validate-milestone.sh` reports `VALIDATE: PASS — N/N checks passed`, exit 0.

## Notes

Expected output examples (kept under `## Notes` so `auto-loop --step=V` does not eval them):

- `bash tools/verify/p07-phase-suite.sh` (post-commit) → `SUMMARY: p07-phase-suite.sh pass=9 fail=0`, exit 0.
- `bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M030` (post-commit) → `VALIDATE: PASS — N/N checks passed`, exit 0.
- `bash scripts/lifecycle/mark-complete.sh .orchestrator M030` → emits `VALIDATE:` lines for each phase + creates `M030-VALIDATED` marker.
- `git log --oneline -1` (post-T04) → `<SHA> M030: adaptive model selection (closed)`.
- `bash tests/m030-acceptance/run-acceptance-battery.sh` (post-commit) → `BATTERY: pass=N fail=0` on the last line, exit 0.
- `cat .orchestrator/milestones/M030/M030-VALIDATED` →
  ```
  # Milestone Validation Marker

  milestone: M030
  validated_at: <ISO8601>
  phase_count: 8

  ## Phase Results

  P00: complete
  P01: complete
  P02: complete
  P03: complete
  P04: complete
  P05: complete
  P06: complete
  P07: complete
  ```

The plan-amendment-not-task-reopen pattern (P02-P06 precedent) applies most strongly at T04. The M030-SUMMARY.md key_files list is authored at step 6 against an aspirational shape; the `validate-milestone.sh` boundary-map check at step 15 may flag drift between the declared shape and what's on disk. AMEND M030-SUMMARY.md key_files directly when this happens — most failures are stale-frontmatter-vs-disk drift, not genuine missing deliverables. Do NOT re-open T01-T03 for predicate divergences.

If `mark-complete.sh` rejects the working tree as dirty at step 5, two acceptable paths:
1. Stage P07-SUMMARY.md + execution-log.jsonl FIRST via `git add` (so the working tree is clean modulo staged paths), then run mark-complete.sh.
2. Set `ORCHESTRATOR_ALLOW_DIRTY_MARK=1` per the script's documented escape hatch.

The first path is preferred (preserves the script's safety contract). If the staged paths still trip the preflight (because preflight checks the staging area too), the second path is the documented safety override.

If the milestone-grain unit_close field set diverges from any prior milestone's pattern (M028 may not have a milestone-grain unit_close — T04's append may be the first such record), document the new convention in T04's SUMMARY and add a one-line entry to `references/observability.md` describing the milestone-grain shape. This is a one-line documentation extension, NOT a new milestone-grain emitter contract.

The CLAUDE.md project-status edit at step 8 is the most error-prone manual step. Read the current CLAUDE.md "Project Status" section + "Forward Roadmap" section in full BEFORE authoring the edit. The Project Status section has a multi-paragraph "in progress" + "operator decision pending" stanza around M030 — the entire stanza must be removed AND M030 must be moved into the "Closed" list AND the Forward Roadmap "M030-close → M031" sequence must be amended to drop M030. Each is a separate Edit invocation. If the edits land wrong, revert via `git checkout HEAD -- CLAUDE.md` and re-author.

Real-app smoke test pending callout (Plan-Time Discipline rule 5): the M030-SUMMARY.md body MUST contain a "Real-app smoke test pending" paragraph. It documents that the synthetic acceptance corpora are not the same as in-the-wild dispatch evidence, and that operators must run >=50 shadow-mode dispatches per class against their own milestone history before activating live routing. The FR-9 programmatic flip-gate enforces this mechanically; the SUMMARY's prose makes the discipline explicit for human readers.
