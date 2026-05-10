---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M024"
goal: "Fast-path auto-proceed — Tier A + Quick + no-conversus + no-design proposals auto-proceed without an approval prompt; everything else continues to halt at the P03 gate."
demo_sentence: "An operator pasting a trivial Tier A input (e.g. 'fix typo in commands/status.md') into `orchestrator:evaluate` sees `auto_proceeded: true` recorded in the emitted proposal frontmatter and the dispatch route fires immediately, while a Tier B paragraph still halts at the approve / revise / cancel prompt as it does today."
risk: "medium"
depends_on: ["P01", "P03"]
---

## Conditions Of The Fast-Path (FR-3, NG-6)

The four-condition gate is the **only** auto-bypass path in M024. It fires when **all** of:

1. `scope_tier == "A"`
2. `intensity == "Quick"`
3. `conversus_gate == "none"`
4. `design_gate == "none"`

…and `evaluate.auto_proceed` resolves to `true` (config default; project can disable globally per AD-1 / #Q-7).

If any single condition is violated, the proposal is emitted with `auto_proceeded: false` and the operator must use the P03 approval-gate (`approve | revise | cancel`). NG-6 — there is no other auto-proceed path; the operator cannot configure "always auto-approve."

## Boundary

- **Produces**: a four-condition check entry-point on `scripts/intake/approval-gate.sh` (extends — does not replace — the P03 gate); `evaluate.auto_proceed` config key exposed via `templates/orchestrator-config-default.yml` + `scripts/state/read-config.sh`; emit-time wiring in `scripts/intake/proposal-emit.sh` that sets `auto_proceeded: true` on eligible proposals; two phase-level tests (`tests/test-fast-path-auto-proceed.sh`, `tests/test-fast-path-condition-violation.sh`) and the P04 suite runner.
- **Consumes**: P01 proposal schema (frontmatter axes + `auto_proceeded` boolean); P03 approval-gate (the bypass path the gate is bypassing); P03 `route-to-dispatch.sh` `auto_proceed=1` plumbing (already wired — P04 only flips the upstream flag); spec FR-3, NG-6, #Q-7; AD-19 single-script-file shape.

## M024/P04 → P05/P07 Forward Wiring (informational)

- **P05 (Q&A)**: emits proposals via the same `proposal-emit.sh` invocation. The fast-path check fires unchanged on Q&A-derived proposals; the spec edge case requires `qa_short_circuited: true` proposals to carry `low_confidence: true` so the fast-path guard rejects them — this is enforced by treating `low_confidence: true` as a fifth disqualifying condition in the check.
- **P07 (design-gate)**: when P07 wires the design-gate axis classifier, any proposal it flips to `design_gate != "none"` will automatically fall out of the fast-path because condition 4 is enforced by reading the rendered proposal's `design_gate` value. P07 needs no further changes.

## Must-Haves

### Truths

- `scripts/intake/approval-gate.sh` supports a new `--mode check-fast-path --proposal <path>` invocation that reads the named proposal, evaluates the four conditions (plus the `low_confidence` guard), and emits exactly two stdout key=value lines: `fast_path_eligible=true|false` and `reason=<all-conditions-met|tier-not-A|intensity-not-Quick|conversus-gated|design-gated|low-confidence>`. Exits 0 in both eligible and ineligible cases (the verdict is the value, not the exit code); non-zero exit reserved for usage / I/O errors.
  - Check: `bash scripts/verify/m024-p04-fast-path-check.sh`
- `scripts/state/read-config.sh` accepts `auto_proceed` as a valid config key, returns the value resolved through the existing four-layer precedence (env > local > project > defaults), and falls through to `null` when no layer declares it. The default that ships in `templates/orchestrator-config-default.yml` is `true` (AD-1 default-on per FR-3).
  - Check: `bash scripts/verify/m024-p04-config-auto-proceed-key.sh`
- `templates/orchestrator-config-default.yml` documents the `evaluate.auto_proceed` key inline (commented description naming the four conditions and pointing at FR-3 / NG-6) and ships `auto_proceed: true` as the default.
  - Check: `bash scripts/verify/m024-p04-config-template.sh`
- `scripts/intake/proposal-emit.sh`, after axis resolution, invokes `approval-gate.sh --mode check-fast-path` against an in-flight rendering of the proposal, and — when the verdict is `fast_path_eligible=true` AND `read-config.sh auto_proceed` returns `true` (or `null` — default is `true` per FR-3) — sets `auto_proceeded: true` in the emitted proposal frontmatter. When either condition fails (verdict `false` OR config explicitly set to `false`), `auto_proceeded` stays at the P01 default `false` and the operator path is unchanged.
  - Check: `bash scripts/verify/m024-p04-proposal-emit-fast-path.sh`
- A Tier-A-eligible input ("fix typo in commands/status.md") emits a proposal with `auto_proceeded: true` and the four matching axis values, AND a Tier-B paragraph emits a proposal with `auto_proceeded: false` and at least one condition violation. Both invariants asserted in a single end-to-end test.
  - Check: `bash scripts/verify/m024-p04-fast-path-auto-proceed.sh`
- A condition-violation matrix test exercises five inputs (one per disqualifying condition: Tier-B paragraph, Quick-but-conversus-gated, Quick-but-design-gated, Standard-intensity, low-confidence) and asserts each lands `auto_proceeded: false` with a `reason=` that names the failing condition.
  - Check: `bash scripts/verify/m024-p04-fast-path-condition-violation.sh`
- Operator can disable the fast-path globally via `evaluate.auto_proceed: false` in `orchestrator-config.yml`; with that override in effect, even a four-condition-eligible input lands `auto_proceeded: false` and routes through the approval gate.
  - Check: `bash scripts/verify/m024-p04-config-disable.sh`
- All P04-introduced shell scripts respect SB-3 write-confinement: writes target only `.orchestrator/intake/<id>/` (proposal frontmatter mutations) and `/tmp` (test scratch). The fast-path check itself is read-only.
  - Check: `bash scripts/verify/m024-p04-write-confinement.sh`
- The P04 phase suite (all five P04 verifies + the two phase-level tests) exits 0 on a clean checkout.
  - Check: `bash scripts/verify/m024-p04-suite.sh`

### Artifacts

- scripts/intake/approval-gate.sh (min 140 lines, contains "check-fast-path")
- scripts/intake/proposal-emit.sh (min 270 lines, contains "FAST_PATH_AXES_DONE")
- scripts/state/read-config.sh (min 150 lines, contains "auto_proceed")
- templates/orchestrator-config-default.yml (min 35 lines, contains "auto_proceed")
- tests/test-fast-path-auto-proceed.sh (min 50 lines, contains "auto_proceeded")
- tests/test-fast-path-condition-violation.sh (min 70 lines, contains "tier-not-A")
- scripts/verify/m024-p04-fast-path-check.sh (min 35 lines, contains "fast_path_eligible")
- scripts/verify/m024-p04-config-auto-proceed-key.sh (min 25 lines, contains "auto_proceed")
- scripts/verify/m024-p04-config-template.sh (min 20 lines, contains "auto_proceed")
- scripts/verify/m024-p04-proposal-emit-fast-path.sh (min 35 lines, contains "auto_proceeded")
- scripts/verify/m024-p04-fast-path-auto-proceed.sh (min 35 lines, contains "auto_proceeded")
- scripts/verify/m024-p04-fast-path-condition-violation.sh (min 50 lines, contains "tier-not-A")
- scripts/verify/m024-p04-config-disable.sh (min 30 lines, contains "auto_proceed")
- scripts/verify/m024-p04-write-confinement.sh (min 20 lines, contains "intake")
- scripts/verify/m024-p04-suite.sh (min 15 lines, contains "test-fast-path")

### Key Links

- scripts/intake/approval-gate.sh → templates/intake-proposal.md (the four-condition check reads the same frontmatter keys the gate's verbs already mutate)
- scripts/intake/proposal-emit.sh → scripts/intake/approval-gate.sh (emitter calls the check-fast-path mode after axis resolution to decide `auto_proceeded`)
- scripts/intake/proposal-emit.sh → scripts/state/read-config.sh (emitter resolves the `auto_proceed` config key before honoring the fast-path)
- templates/orchestrator-config-default.yml → scripts/state/read-config.sh (defaults file consumed by read-config layer 4)
- tests/test-fast-path-auto-proceed.sh → scripts/intake/proposal-emit.sh (test invokes emitter on a Tier-A input)
- tests/test-fast-path-condition-violation.sh → scripts/intake/approval-gate.sh (test invokes the check-fast-path mode directly across the five disqualifying axes)

## Tasks

### T01: `auto_proceed` config key — defaults file + read-config.sh valid-keys

See `tasks/T01-PLAN.md`. Adds `auto_proceed` to the `VALID_KEYS` list in `scripts/state/read-config.sh` so the existing four-layer resolver accepts it. Updates `templates/orchestrator-config-default.yml` to ship `auto_proceed: true` with an inline comment block naming the four fast-path conditions and pointing at FR-3 / NG-6 / #Q-7. No new resolver code — the existing `read_yaml_value` shape handles the key as-is. Pure config plumbing, AD-1 commit (project-config-only knob — no CLI flag).

### T02: `--mode check-fast-path` on `scripts/intake/approval-gate.sh`

See `tasks/T02-PLAN.md`. Extends `scripts/intake/approval-gate.sh` with a fifth invocation mode (alongside the existing `approve | cancel | revise` verbs): `--mode check-fast-path --proposal <path>`. The mode reads the named proposal's frontmatter, evaluates the four conditions (`scope_tier=A`, `intensity=Quick`, `conversus_gate=none`, `design_gate=none`) plus the `low_confidence!=true` guard, and emits exactly two stdout key=value lines (`fast_path_eligible=true|false` and `reason=<token>`). The check is **read-only** — no frontmatter mutation. Exit 0 in both eligible and ineligible cases (the verdict is the value, not the exit code); exit 1 reserved for I/O errors; exit 2 reserved for usage errors. Reuses the existing `read_fm` / `read_fm_bare` helpers; AD-19 single-script-file shape preserved.

### T03: Wire fast-path into `scripts/intake/proposal-emit.sh`

See `tasks/T03-PLAN.md`. After axis resolution (paragraph + spec deep classifiers already wired in P02/P03) but **before** the final render of the in-flight proposal, the emitter:

1. Resolves `auto_proceed` via `bash scripts/state/read-config.sh auto_proceed --defaults templates/orchestrator-config-default.yml --project orchestrator-config.yml --local orchestrator-config.local.yml`. Treats `null` as `true` (default-on per FR-3).
2. Renders an interim copy of the proposal to a tmp path with the axes filled in (so the check has a real frontmatter to inspect).
3. Invokes `bash scripts/intake/approval-gate.sh --mode check-fast-path --proposal <tmp>` and parses the `fast_path_eligible=` line.
4. If both signals say eligible, sets the local `auto_proceeded` shell var to `"true"` before the final swap loop runs (so the rendered proposal carries the truthy value). Otherwise leaves it at the P01 default `"false"`.
5. Adds a `FAST_PATH_AXES_DONE` flag (mirroring P03's `PARA_AXES_DONE` and P02's `SPEC_AXES_DONE` patterns) so future-phase rationale loops can short-circuit the fast-path-set axes if needed.

The wiring is invoke-time per the validated convention (no plan-phase-time probe); the check re-runs every emit. SB-3 write-confinement preserved — the check is read-only, the only writes the emitter performs target `.orchestrator/intake/<id>/` as before.

### T04: Phase tests + suite

See `tasks/T04-PLAN.md`. Authors three new verify scripts (`m024-p04-fast-path-auto-proceed.sh`, `m024-p04-fast-path-condition-violation.sh`, `m024-p04-config-disable.sh`) and two phase-level tests (`tests/test-fast-path-auto-proceed.sh`, `tests/test-fast-path-condition-violation.sh`). Authors three additional per-T01–T03 verifies (`m024-p04-config-auto-proceed-key.sh`, `m024-p04-config-template.sh`, `m024-p04-fast-path-check.sh`, `m024-p04-proposal-emit-fast-path.sh`) — these are partly shipped from T01–T03 but the T04 step authors any that the upstream task did not ship. Authors `m024-p04-write-confinement.sh` and the suite runner `m024-p04-suite.sh` (MEM002 parallel-array tracking, structured `PASS:`/`FAIL:` summary). The condition-violation test exercises five disqualifying axes (Tier B, conversus-gated, design-gated, Standard intensity, low-confidence) — one input per condition — to prove the regression fence holds.

## Task Dependencies

```
T01 → T02    (T02's check reads no config — but T03 needs T01's key, and T03 needs T02's check; we still order T01 before T02 because T02's verify exercises the check on a real config-resolved emit)
T01 → T03
T02 → T03
T01 + T02 + T03 → T04
```

T01 (config key) is purely additive plumbing — no behavior change yet. T02 (check-fast-path mode) is also purely additive — adds a read-only verdict mode without altering existing verb behavior. T03 (emit wiring) is the load-bearing change that flips `auto_proceeded: true` on eligible proposals. T04 (tests + suite) exercises the full path end-to-end and proves the regression fence: non-degenerate inputs still hit the approval gate.

## Files Likely Touched

- scripts/intake/approval-gate.sh (modify — add --mode check-fast-path)
- scripts/intake/proposal-emit.sh (modify — wire fast-path between axis resolution and final render)
- scripts/state/read-config.sh (modify — add auto_proceed to VALID_KEYS)
- templates/orchestrator-config-default.yml (modify — ship auto_proceed: true with inline doc)
- tests/test-fast-path-auto-proceed.sh (create)
- tests/test-fast-path-condition-violation.sh (create)
- scripts/verify/m024-p04-fast-path-check.sh (create)
- scripts/verify/m024-p04-config-auto-proceed-key.sh (create)
- scripts/verify/m024-p04-config-template.sh (create)
- scripts/verify/m024-p04-proposal-emit-fast-path.sh (create)
- scripts/verify/m024-p04-fast-path-auto-proceed.sh (create)
- scripts/verify/m024-p04-fast-path-condition-violation.sh (create)
- scripts/verify/m024-p04-config-disable.sh (create)
- scripts/verify/m024-p04-write-confinement.sh (create)
- scripts/verify/m024-p04-suite.sh (create)
