---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M024"
goal: "Paragraph intake + approval gate + M024→M014 route-to-specify (and route-to-dispatch for trivial inputs)"
demo_sentence: "An operator pasting a paragraph into `orchestrator:evaluate` gets a proposal plus an approve/revise/cancel prompt; on `approve` the orchestrator invokes `orchestrator:specify` for non-trivial paragraphs and `orchestrator:dispatch` for trivial ones, with approval state recorded in the proposal frontmatter."
risk: "high"
depends_on: ["P01"]
---

## M014/extended Shipping Probe (Cross-Cutting #DQ-2)

Probe at plan-phase time:

```
test -f scripts/specify/specify.sh
grep -q "Pass.1" commands/specify.md
```

Both succeed (specify.sh present at 573 lines; commands/specify.md ships the three-pass contract per D019 with an explicit "Pass 1 (scaffold) is implemented" marker on line 11). **Disposition**: M014/extended **has shipped**, so P03 routes live to `orchestrator:specify` via the M024→M014 handshake direction. No "M014 not yet shipped" stub branch is needed; the handshake is wired against the live `commands/specify.md` entry point per AD-4 direction `b` (read-only consumption).

If the probe ever fails on a future re-plan (e.g. a regenerated worktree without M014 staged), the route-to-specify task MUST instead emit a clearly-marked stub message naming `commands/specify.md` as the unshipped target and exit non-zero — see spec #DQ-2 option `b`.

## Must-Haves

### Truths

- The proposal emitter, when given a paragraph-shaped input, populates the four classifiable axes with non-stub values (scope_tier ∈ {A,B,C}, decomposition ∈ {single-task, single-phase, milestone-with-phases, multi-milestone}, recommended_command ∈ {orchestrator:dispatch, orchestrator:specify}, design_gate from existing signal — none for non-design inputs in P03 scope, conversus_gate=none until P04 wires it). The P01-stub rationale string `P01 stub — deep classifier ships in a later phase.` no longer appears in `scope_tier` / `decomposition` / `recommended_command` rationale slots when input_shape=paragraph.
  - Check: `bash scripts/verify/m024-p03-paragraph-classify.sh`
- The approval-gate script, given a proposal path and an `approve` decision, mutates the proposal frontmatter in-place: sets `approved_at: <ISO8601>`, sets `pending_approval: false`, and emits a `recommended_command_invoke=<command>` line to stdout for the caller to dispatch.
  - Check: `bash scripts/verify/m024-p03-approval-gate.sh`
- The approval-gate script honors `cancel` (sets `cancelled_at`, leaves no further state changes) and `revise` (exits with a marker for the caller to re-emit; revision body lands in P05 — P03 only validates the gate routes the verb correctly).
  - Check: `bash scripts/verify/m024-p03-approval-gate-verbs.sh`
- The route-to-specify script, given a proposal whose `recommended_command=orchestrator:specify`, emits a deterministic invocation contract — one stdout line `invoke=orchestrator:specify --input-from <proposal_path>` — and validates the M014 entry point by re-running the cross-cutting probe (`test -f scripts/specify/specify.sh`) before emitting, exiting non-zero with the unshipped-stub message if the probe fails.
  - Check: `bash scripts/verify/m024-p03-route-to-specify.sh`
- The route-to-dispatch script, given a proposal whose `recommended_command=orchestrator:dispatch`, emits one stdout line `invoke=orchestrator:dispatch --proposal <proposal_path>` and (when `auto_proceeded=true` is recorded by the upstream fast-path branch) records `proceeded_at: <ISO8601>` and emits `auto_proceed=1` to stdout.
  - Check: `bash scripts/verify/m024-p03-route-to-dispatch.sh`
- `commands/evaluate.md` documents all five input shapes (idea / paragraph / fragment / spec / empty) in a single "Input Shapes" section, naming the recommended downstream command per shape; the legacy spec-on-disk path remains the canonical pre-M024 entry-point with a back-reference to the new "Input Shapes" section per FR-6.
  - Check: `bash scripts/verify/m024-p03-evaluate-md.sh`
- The two phase-level tests (`tests/test-paragraph-intake.sh` and `tests/test-approval-gate.sh`) plus the P03 suite all exit 0 on a clean checkout.
  - Check: `bash scripts/verify/m024-p03-suite.sh`
- All P03-introduced shell scripts respect SB-3 write-confinement: writes target only `.orchestrator/intake/<id>/` (proposal frontmatter mutations) and `/tmp` (test scratch).
  - Check: `bash scripts/verify/m024-p03-write-confinement.sh`

### Artifacts

- scripts/intake/paragraph-classify.sh (min 80 lines, contains "paragraph")
- scripts/intake/approval-gate.sh (min 80 lines, contains "approved_at")
- scripts/intake/route-to-specify.sh (min 40 lines, contains "orchestrator:specify")
- scripts/intake/route-to-dispatch.sh (min 30 lines, contains "orchestrator:dispatch")
- commands/evaluate.md (min 200 lines, contains "Input Shapes")
- tests/test-paragraph-intake.sh (min 60 lines, contains "paragraph")
- tests/test-approval-gate.sh (min 60 lines, contains "approved_at")
- scripts/verify/m024-p03-paragraph-classify.sh (min 25 lines, contains "paragraph")
- scripts/verify/m024-p03-approval-gate.sh (min 25 lines, contains "approved_at")
- scripts/verify/m024-p03-approval-gate-verbs.sh (min 25 lines, contains "cancel")
- scripts/verify/m024-p03-route-to-specify.sh (min 25 lines, contains "orchestrator:specify")
- scripts/verify/m024-p03-route-to-dispatch.sh (min 25 lines, contains "orchestrator:dispatch")
- scripts/verify/m024-p03-evaluate-md.sh (min 20 lines, contains "Input Shapes")
- scripts/verify/m024-p03-write-confinement.sh (min 20 lines, contains "intake")
- scripts/verify/m024-p03-suite.sh (min 15 lines, contains "test-paragraph")

### Key Links

- scripts/intake/paragraph-classify.sh → scripts/intake/proposal-emit.sh (classifier consumed by emitter when input_shape=paragraph)
- scripts/intake/approval-gate.sh → templates/intake-proposal.md (mutates frontmatter keys defined in the template)
- scripts/intake/route-to-specify.sh → commands/specify.md (M024→M014 handshake target — read-only reference per AD-4 direction `b`)
- scripts/intake/route-to-dispatch.sh → commands/dispatch.md (M024→dispatch handoff target)
- commands/evaluate.md → scripts/intake/proposal-emit.sh (evaluate.md documents emitter as the proposal authoring path)
- commands/evaluate.md → scripts/intake/approval-gate.sh (evaluate.md documents the approval gate)
- tests/test-paragraph-intake.sh → scripts/intake/proposal-emit.sh (test invokes emitter with paragraph input)
- tests/test-approval-gate.sh → scripts/intake/approval-gate.sh (test exercises the gate verbs)

## Tasks

### T01: Paragraph classifier — replace P01 stubs for paragraph branch

See `tasks/T01-PLAN.md`. Authors `scripts/intake/paragraph-classify.sh` — a pure classifier that, given a paragraph-shaped input, emits four `key=value` stdout lines (`scope_tier`, `decomposition`, `recommended_command`, plus per-axis rationale strings citing word-count and structural-marker evidence). Wires the classifier into `scripts/intake/proposal-emit.sh` so paragraph-shaped inputs no longer carry the P01-stub rationale. Heuristics: word-count buckets (≤30 → Tier A + single-task + dispatch; 31–80 → Tier B + single-phase + specify; structural FR-bullet count ≥3 OR the paragraph mentions "milestone" / "phases" / "roadmap" → Tier C + milestone-with-phases + specify). `design_gate` and `conversus_gate` remain at P01 stubs in this phase (P04 wires conversus, P07 wires design per the roadmap). Pure shell, AD-19 single-script-file shape.

### T02: Approval gate — verbs + frontmatter mutation

See `tasks/T02-PLAN.md`. Authors `scripts/intake/approval-gate.sh` — given a proposal path and one of `approve | cancel | revise <axis>=<value>`, mutates the proposal frontmatter in-place using the same `sed -i.bak` idiom T04 of P01 established. `approve` sets `approved_at: <ISO8601>` and `pending_approval: false`, then emits `recommended_command_invoke=<command>` to stdout. `cancel` sets `cancelled_at: <ISO8601>` and `pending_approval: false`, no further stdout. `revise` is a thin pass-through in P03 (full revision body lands in P05) that exits 0 with `revision_pending=true` to stdout — the gate verifies the verb is recognized and the proposal is left untouched. SB-3: writes only the named proposal file; never escapes `.orchestrator/intake/<id>/`.

### T03: Routes — specify (M024→M014) + dispatch (trivial)

See `tasks/T03-PLAN.md`. Authors two single-purpose route scripts. `scripts/intake/route-to-specify.sh` re-runs the M014/extended shipping probe at invoke time (`test -f scripts/specify/specify.sh`) and emits one stdout line `invoke=orchestrator:specify --input-from <proposal_path>`; if the probe fails, it emits a clearly-marked stub message naming `commands/specify.md` and exits non-zero per #DQ-2 option `b`. `scripts/intake/route-to-dispatch.sh` reads the proposal frontmatter, validates `recommended_command=orchestrator:dispatch`, and emits `invoke=orchestrator:dispatch --proposal <proposal_path>`. When `auto_proceeded=true` is set (degenerate-fast-path enabled by upstream — wired in P06), the dispatch route additionally writes `proceeded_at: <ISO8601>` to the proposal and emits `auto_proceed=1`. Pure shell; no conversus, no knowledge writes.

### T04: `commands/evaluate.md` rewrite + two phase tests + suite

See `tasks/T04-PLAN.md`. Rewrites `commands/evaluate.md` to add a top-level "Input Shapes" section covering all five shapes (idea / paragraph / fragment / spec / empty) with a row per shape naming: how the shape is detected (back-reference to `scripts/intake/shape-detect.sh`), the recommended downstream command, and whether the approval gate fires or the fast-path auto-proceeds. The legacy spec-on-disk path keeps its existing prose as the canonical pre-M024 entry-point with a top-of-section note pointing to the new "Input Shapes" section per FR-6 (byte-compatibility on the legacy path). Authors `tests/test-paragraph-intake.sh` (invokes the emitter with a paragraph, asserts non-stub axis values for the three classifiable axes via grep) and `tests/test-approval-gate.sh` (invokes the gate with `approve`, then `cancel`, then `revise tier=C`, asserting frontmatter mutation in each case). Authors `scripts/verify/m024-p03-suite.sh` invoking both phase tests + every per-task verify. MEM002 conventions: parallel arrays, structured `PASS:`/`FAIL:` summary.

## Task Dependencies

```
T01 → T02    (T02 mutates proposals T01 generates with non-stub axes)
T02 → T03    (T03 routes consume the gate's stdout-emitted invoke line)
T01 + T02 + T03 → T04
```

T01 (classifier) replaces P01 stubs and is the schema-deepening step every later task depends on. T02 (gate) consumes a proposal whose axes are populated. T03 (routes) consume the gate's invoke decision. T04 (docs + tests + suite) exercises the full path end-to-end.

## Files Likely Touched

- scripts/intake/paragraph-classify.sh (create)
- scripts/intake/proposal-emit.sh (modify — wire classifier on paragraph branch)
- scripts/intake/approval-gate.sh (create)
- scripts/intake/route-to-specify.sh (create)
- scripts/intake/route-to-dispatch.sh (create)
- commands/evaluate.md (modify — add "Input Shapes" section)
- tests/test-paragraph-intake.sh (create)
- tests/test-approval-gate.sh (create)
- scripts/verify/m024-p03-paragraph-classify.sh (create)
- scripts/verify/m024-p03-approval-gate.sh (create)
- scripts/verify/m024-p03-approval-gate-verbs.sh (create)
- scripts/verify/m024-p03-route-to-specify.sh (create)
- scripts/verify/m024-p03-route-to-dispatch.sh (create)
- scripts/verify/m024-p03-evaluate-md.sh (create)
- scripts/verify/m024-p03-write-confinement.sh (create)
- scripts/verify/m024-p03-suite.sh (create)
