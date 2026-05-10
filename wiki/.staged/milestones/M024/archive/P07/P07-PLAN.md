---
schema_version: "1.0"
type: phase-plan
phase: "P07"
milestone: "M024"
goal: "Pre-M023 design-gate graceful degradation — replace the P01 `design_gate=none` stub with a real classifier, probe for M023 shipping at invoke-time, and on a pre-M023 checkout emit the FR-7 byte-pinned `\"design walkthrough lands in M023; author DESIGN.md manually or skip\"` message with two operator branches (`manual` halts and re-enters on next evaluate; `skip` records `design_skipped: true` and proceeds). No `orchestrator:design` reference may appear in any pre-M023 `recommended_command` slot."
demo_sentence: "An operator who pastes a UI-tagged paragraph (`\"redesign the proposal viewer with split panes and live diff\"`) on this checkout (M023 not shipped) sees a proposal whose `design_gate: \"walkthrough\"` is paired with the exact stderr line `design walkthrough lands in M023; author DESIGN.md manually or skip`, plus a prompt offering `manual` and `skip`; choosing `skip` flips `design_skipped: true` and the proposal proceeds; choosing `manual` halts and the proposal records `design_authored_manually: true` only after the operator authors a `DESIGN.md` and re-runs evaluate."
risk: "low"
depends_on: ["P01", "P03"]
---

## Resolution Of Pre-M023 Design-Gate Branch (FR-7, US-6, AD-5)

P07 closes M024 by removing the last P01 stub axis (`design_gate="none"`) and wiring the FR-7 graceful-degradation contract. Three resolutions land here:

1. **Classifier shape** — design-gate is the only axis where the *correct* default depends on input semantics, not on tier. A Tier A paragraph that asks for a UI redesign still wants a design walkthrough; a Tier C paragraph that adds a backend script does not. P07 ships a small lexical classifier (`scripts/intake/design-gate-classify.sh`) that runs alongside the P03 paragraph and P02 spec deep classifiers and emits `design_gate=<none|walkthrough>`. The rule table is intentionally narrow: presence of any of `{ui, UI, render, design, layout, screen, view, panel, viewer, dashboard, interface, visual, theme}` tokens flips to `walkthrough`; everything else stays `none`. This is a v1 heuristic — D016's M023 spec will tighten it. Until M023 ships, false positives are visible (operator can `revise design_gate=none`), false negatives are silent (operator can `revise design_gate=walkthrough` if they disagree). The asymmetry is acceptable because pre-M023 the only consequence of `walkthrough` is the manual/skip branch — no agent burns context on a wrong call.

2. **M023-shipping probe** — invoke-time, not plan-phase-time. The probe checks for the canonical M023 surface signature: `commands/design.md` exists AND carries a `Pass.<N>` marker (mirrors P03/T03's [M014](../../../../milestones/M014/index.md) probe shape per #DQ-2 option `b`). When probe succeeds, the recommended_command for design-gated proposals points at `orchestrator:design`; when probe fails, the FR-7 manual/skip branches fire. Plan-phase-time checks would be wrong — a developer pulling main mid-M024 may have shipped M023 between plan and dispatch.

3. **No `orchestrator:design` orphan references** — the pre-M023 invariant is grep-stable. P07's `scripts/verify/m024-p07-no-orphan-design-cmd.sh` greps every emitted proposal frontmatter and every line of `commands/evaluate.md` for `orchestrator:design` and asserts: either the M023 probe currently passes, or no such reference appears in any active code path. This is the test-only backcompat shim pattern from P06/T03 — a hidden flag rather than a behavioral fork: `M023_SHIPPED_PROBE_OVERRIDE=stub` in the environment short-circuits the probe to "not shipped" so the test suite can exercise the pre-M023 path on a future post-M023 checkout without removing the gate.

## Pinned Message (FR-7 byte-stability)

The exact string emitted to stderr (and embedded in the proposal body when applicable) is:

```
design walkthrough lands in M023; author DESIGN.md manually or skip
```

No leading/trailing whitespace, no Markdown wrappers, no variant punctuation. SC-5 verifies via `grep -F` on stdout/stderr; any drift breaks the test. The string is duplicated verbatim in three sites — `scripts/intake/design-gate-degradation.sh` (the emitter), `scripts/verify/m024-p07-pinned-message.sh` (the verifier), and `commands/evaluate.md` line 33 (the operator-facing doc). These three duplications are the FR-7 contract surface; future M023 work may de-duplicate (move the string into a shared lib) only if it ships an update to all three sites in the same commit.

## Boundary

- **Produces**:
  - `scripts/intake/design-gate-classify.sh` — pure decision emitter. Given an input string (paragraph/idea/fragment) OR a spec path, scans for design-domain tokens and emits `design_gate=<none|walkthrough>` + `design_gate_confidence=<low|high>` to stdout. Writes nothing.
  - `scripts/intake/design-gate-degradation.sh` — invoke-time M023-shipping probe + branch dispatcher. Reads `--proposal <path>`; if `design_gate=walkthrough` and M023 is not shipped (probe), emits the FR-7 pinned message to stderr and returns the recommended branch (`manual` or `skip` based on `--branch <verb>` argument). Mutates the proposal frontmatter for the chosen branch (`design_skipped: true` or `design_authored_manually: true`); pure stdout for the recommendation when `--branch` is absent (probe-only mode).
  - `scripts/intake/proposal-emit.sh` (modify) — wires the design-gate classifier into the paragraph and spec branches; sets `DESIGN_AXES_DONE=1` so the rationale loop skips the design-gate slot when the deep classifier ran. Also guards the `recommended_command` slot: when `design_gate=walkthrough` AND the M023 probe fails, the slot stays at the tier-derived value (`orchestrator:dispatch` / `orchestrator:specify`) rather than pointing at `orchestrator:design`.
  - `scripts/intake/approval-gate.sh` (modify) — extends the verb table with `manual` and `skip` verbs that fire only when the proposal carries `design_gate: "walkthrough"` AND the M023 probe failed at invoke time. Both verbs delegate to `scripts/intake/design-gate-degradation.sh`. Verbs on a non-design-gated proposal exit 2 with an actionable error.
  - `commands/evaluate.md` (modify) — updates the Pre-M023 design-gate degradation section (lines 31–33) from "lands when P07 ships" to "wired in P07"; adds the manual/skip verbs to the verb table; pins the FR-7 message in the documentation.
  - `tests/test-design-gate-degradation.sh` — phase-level test. Forces a UI-tagged paragraph through evaluate, asserts the FR-7 pinned message lands on stderr via `grep -F`, and that both `manual` and `skip` are offered in the prompt.
  - `tests/test-design-gate-skip.sh` — phase-level test. Exercises the `skip` branch end-to-end; asserts `design_skipped: true` in frontmatter and the recommended downstream proceeds.
  - `tests/test-design-gate-manual.sh` — phase-level test. Exercises the `manual` branch end-to-end; first invocation halts with `pending_design_authored_manually: true`; operator authors a `DESIGN.md`; second invocation flips `design_authored_manually: true` and proceeds.
  - `scripts/verify/m024-p07-design-gate-classify.sh`, `scripts/verify/m024-p07-degradation-script.sh`, `scripts/verify/m024-p07-pinned-message.sh`, `scripts/verify/m024-p07-m023-probe.sh`, `scripts/verify/m024-p07-skip-branch.sh`, `scripts/verify/m024-p07-manual-branch.sh`, `scripts/verify/m024-p07-no-orphan-design-cmd.sh`, `scripts/verify/m024-p07-approval-gate-design-verbs.sh`, `scripts/verify/m024-p07-write-confinement.sh`, `scripts/verify/m024-p07-evaluate-md.sh`, `scripts/verify/m024-p07-suite.sh` — eleven per-claim verifies plus the suite runner.
- **Consumes**:
  - P01 proposal schema (`templates/intake-proposal.md` 25-key frontmatter — `design_gate`, `design_skipped`, `design_authored_manually` already present).
  - P01 `scripts/intake/proposal-emit.sh` (the design-gate classifier hooks in alongside paragraph/spec deep classifiers; the `recommended_command` guard slot lives in this file).
  - P03 `scripts/intake/approval-gate.sh` (the manual/skip verbs slot into the existing verb table; idempotency guard preserved).
  - P03 invoke-time probe pattern (re-used verbatim — re-run probe at every invocation, not at plan-phase time).
  - P06 `scripts/intake/revise.sh` — when an operator revises `design_gate` from `none` to `walkthrough`, P06 already preserves the override; P07's degradation handler runs on the next emit. No P06 changes needed.
  - Spec FR-7 (the byte-pinned message), US-6 (manual/skip branches), AD-5 (M023 not shipped at plan-phase entry per A5), the existing constitutional III audit-trail invariant (every dispatch is provably preceded by approval OR fast-path OR an explicit design-skip).

## M024/P07 → Future M023 Wiring (informational)

When M023 ships:

1. The invoke-time probe at `scripts/intake/design-gate-degradation.sh` will succeed (`commands/design.md` exists with `Pass.<N>` marker).
2. The `recommended_command` slot for design-gated proposals will flip from the tier-derived fallback to `orchestrator:design`.
3. The FR-7 pinned message will no longer fire on the happy path; it remains as the fallback when the operator opts out via `manual` / `skip` (which become "user opted out" rather than "M023 not yet shipped" branches).
4. The `M023_SHIPPED_PROBE_OVERRIDE=stub` test-only escape preserves the pre-M023 path for regression tests.

P07 ships none of this M023 infrastructure — it ships the substrate. The `commands/design.md` command lives in M023 per D016 sequencing.

## Must-Haves

### Truths

- `scripts/intake/design-gate-classify.sh` is executable, accepts `--input <text>` OR `--spec-path <path>`, and emits `design_gate=<none|walkthrough>` plus `design_gate_confidence=<low|high>` as key=value stdout lines. The classifier scans for design-domain tokens (`ui`, `UI`, `render`, `design`, `layout`, `screen`, `view`, `panel`, `viewer`, `dashboard`, `interface`, `visual`, `theme`) using whole-word matching (POSIX `grep -wE`) so substrings like `redesign` count but `serendipity` does not.
  - Check: `bash scripts/verify/m024-p07-design-gate-classify.sh`
- `scripts/intake/design-gate-degradation.sh` is executable, accepts `--proposal <path>` plus optional `--branch <manual|skip>`, runs an invoke-time M023-shipping probe (file existence + `Pass.<N>` marker in `commands/design.md`), and on probe failure for a `design_gate=walkthrough` proposal emits the exact byte-pinned FR-7 message `design walkthrough lands in M023; author DESIGN.md manually or skip` to stderr.
  - Check: `bash scripts/verify/m024-p07-degradation-script.sh`
- The FR-7 message string appears verbatim (byte-exact) in the three pinned sites — `scripts/intake/design-gate-degradation.sh`, `commands/evaluate.md`, `scripts/verify/m024-p07-pinned-message.sh` — and any diff (whitespace, punctuation, capitalization) breaks the verifier.
  - Check: `bash scripts/verify/m024-p07-pinned-message.sh`
- The M023-shipping probe respects the `M023_SHIPPED_PROBE_OVERRIDE` env var (closed enum: `stub` forces probe-fails; `live` forces probe-uses-real-disk; absent means real disk). On a fresh checkout the real-disk probe fails (no `commands/design.md`); with the override set to `live` and a synthetic `commands/design.md` present in tmp, the probe succeeds.
  - Check: `bash scripts/verify/m024-p07-m023-probe.sh`
- The `skip` branch handler mutates the proposal frontmatter to set `design_skipped: true` and `pending_approval: false`, records `proceeded_at: <ISO8601>`, and exits 0 with stdout `branch=skip design_skipped=true`. The proposal stays at its existing `<id>`; no version-suffix archive (skip is not a revision).
  - Check: `bash scripts/verify/m024-p07-skip-branch.sh`
- The `manual` branch handler exits 0 on first invocation with stdout `branch=manual halt=true design_authored_manually=false design_md_path=<expected-absolute-path>`; mutates the proposal to set `pending_design_authored_manually: true` (a P07-introduced transient frontmatter flag — added under D024 / MEM031 schema-authority handshake). On a follow-up invocation where `<DESIGN.md>` now exists at the expected path, exits 0 with `branch=manual halt=false design_authored_manually=true` and mutates the proposal to flip `design_authored_manually: true` + `pending_approval: true` (operator must still approve before downstream runs).
  - Check: `bash scripts/verify/m024-p07-manual-branch.sh`
- No active code path ever names `orchestrator:design` as a `recommended_command` value when the M023 probe fails. `proposal-emit.sh`'s recommended_command guard keeps the slot at the tier-derived fallback (`orchestrator:dispatch` for Tier A, `orchestrator:specify` for Tier B/C). Verifier greps every proposal-emit code path AND every line of `commands/evaluate.md` for the literal `orchestrator:design` and asserts each match is either inside an explicit M023-probe-pass branch or a doc-only forward-reference clearly labeled as such.
  - Check: `bash scripts/verify/m024-p07-no-orphan-design-cmd.sh`
- `scripts/intake/approval-gate.sh` accepts `manual` and `skip` verbs; both verbs are valid only when the proposal frontmatter carries `design_gate: "walkthrough"` AND the invoke-time M023 probe failed. Verbs on a non-design-gated proposal exit 2 with `ERR: 'manual'/'skip' verb requires design_gate=walkthrough on a pre-M023 checkout`.
  - Check: `bash scripts/verify/m024-p07-approval-gate-design-verbs.sh`
- All P07-introduced shell scripts respect SB-3 write-confinement: writes target only `.orchestrator/intake/<id>/` (proposal mutations) and `/tmp` (test scratch). The classifier and probe scripts write nothing.
  - Check: `bash scripts/verify/m024-p07-write-confinement.sh`
- `commands/evaluate.md` Pre-M023 section reads "wired in P07" (not "lands when P07 ships"), and the verb table includes `manual` and `skip` rows naming the FR-7 contract.
  - Check: `bash scripts/verify/m024-p07-evaluate-md.sh`
- The P07 phase suite (the three phase-level tests + every per-task verify) exits 0 on a clean checkout.
  - Check: `bash scripts/verify/m024-p07-suite.sh`

### Artifacts

- scripts/intake/design-gate-classify.sh (min 60 lines, contains "walkthrough")
- scripts/intake/design-gate-degradation.sh (min 100 lines, contains "design walkthrough lands in M023")
- scripts/intake/proposal-emit.sh (min 420 lines, contains "DESIGN_AXES_DONE")
- scripts/intake/approval-gate.sh (min 200 lines, contains "manual")
- commands/evaluate.md (min 200 lines, contains "wired in P07")
- tests/test-design-gate-degradation.sh (min 50 lines, contains "design walkthrough lands in M023")
- tests/test-design-gate-skip.sh (min 50 lines, contains "design_skipped")
- tests/test-design-gate-manual.sh (min 50 lines, contains "design_authored_manually")
- scripts/verify/m024-p07-design-gate-classify.sh (min 30 lines, contains "walkthrough")
- scripts/verify/m024-p07-degradation-script.sh (min 30 lines, contains "design walkthrough lands in M023")
- scripts/verify/m024-p07-pinned-message.sh (min 25 lines, contains "design walkthrough lands in M023; author DESIGN.md manually or skip")
- scripts/verify/m024-p07-m023-probe.sh (min 30 lines, contains "M023_SHIPPED_PROBE_OVERRIDE")
- scripts/verify/m024-p07-skip-branch.sh (min 30 lines, contains "design_skipped")
- scripts/verify/m024-p07-manual-branch.sh (min 30 lines, contains "design_authored_manually")
- scripts/verify/m024-p07-no-orphan-design-cmd.sh (min 30 lines, contains "orchestrator:design")
- scripts/verify/m024-p07-approval-gate-design-verbs.sh (min 30 lines, contains "manual")
- scripts/verify/m024-p07-write-confinement.sh (min 20 lines, contains "intake")
- scripts/verify/m024-p07-evaluate-md.sh (min 20 lines, contains "wired in P07")
- scripts/verify/m024-p07-suite.sh (min 15 lines, contains "test-design-gate-degradation")

### Key Links

- scripts/intake/design-gate-degradation.sh → scripts/intake/design-gate-classify.sh (degradation runs after classifier; consumes the classifier verdict via the proposal frontmatter)
- scripts/intake/proposal-emit.sh → scripts/intake/design-gate-classify.sh (emitter invokes the classifier in the paragraph and spec branches)
- scripts/intake/proposal-emit.sh → scripts/intake/design-gate-degradation.sh (emitter invokes the probe-only mode of the degradation script post-axis-resolution to decide the recommended_command slot for design-gated proposals)
- scripts/intake/approval-gate.sh → scripts/intake/design-gate-degradation.sh (manual/skip verbs delegate to the degradation script with `--branch <verb>`)
- commands/evaluate.md → scripts/intake/design-gate-degradation.sh (verb table references the degradation script)
- tests/test-design-gate-degradation.sh → scripts/intake/design-gate-degradation.sh (end-to-end test exercises the script)
- tests/test-design-gate-skip.sh → scripts/intake/design-gate-degradation.sh (test exercises the skip branch)
- tests/test-design-gate-manual.sh → scripts/intake/design-gate-degradation.sh (test exercises the manual branch)

## Tasks

### T01: `scripts/intake/design-gate-classify.sh` — pure design-gate classifier

See `tasks/T01-PLAN.md`. Authors `scripts/intake/design-gate-classify.sh` — a pure decision emitter (no file writes) that, given `--input <text>` OR `--spec-path <path>`, scans for design-domain tokens and emits `design_gate=<none|walkthrough>` + `design_gate_confidence=<low|high>` to stdout. Whole-word token matching via POSIX `grep -wE` (not substring); confidence is `high` when ≥2 distinct tokens hit, `low` when exactly 1 token hits or the input is short (<8 words). Authors `scripts/verify/m024-p07-design-gate-classify.sh` exercising the rule table on canonical inputs (UI redesign paragraph → walkthrough+high; backend script paragraph → none; single-token short input → walkthrough+low). AD-19 single-script-file shape; bash 3.2 portable.

### T02: `scripts/intake/design-gate-degradation.sh` — M023 probe + branch handler + pinned message

See `tasks/T02-PLAN.md`. Authors `scripts/intake/design-gate-degradation.sh` — invoke-time M023-shipping probe, FR-7 pinned-message emission, and manual/skip branch handlers. Two modes:

- **Probe-only mode** (no `--branch`): runs the M023 probe and emits `m023_shipped=<true|false>` + `recommended_command=<orchestrator:design|orchestrator:dispatch|orchestrator:specify>` to stdout. Used by proposal-emit.sh to decide the recommended_command slot at emit time.
- **Branch mode** (`--branch manual|skip`): runs the probe; on probe-fail for a `design_gate=walkthrough` proposal, emits the FR-7 pinned message to stderr and dispatches the named branch handler. On `--branch skip`, mutates frontmatter (`design_skipped: true`, `pending_approval: false`, `proceeded_at: <ISO8601>`). On `--branch manual`, two sub-cases — first invocation: mutate `pending_design_authored_manually: true`, emit `branch=manual halt=true`. Follow-up invocation (DESIGN.md now exists at the expected path inside the spec dir): mutate `design_authored_manually: true`, `pending_design_authored_manually: false`, `pending_approval: true`, emit `branch=manual halt=false`.

Authors `scripts/verify/m024-p07-degradation-script.sh`, `scripts/verify/m024-p07-pinned-message.sh`, `scripts/verify/m024-p07-m023-probe.sh`. The `M023_SHIPPED_PROBE_OVERRIDE` env-var escape is wired here (closed enum: `stub` forces probe-fails for testing on a future post-M023 checkout; `live` is the explicit affirmative; absent means real disk). AD-19 single-script-file shape.

### T03: Wire classifier + probe into `proposal-emit.sh`; add `manual`/`skip` verbs to `approval-gate.sh`

See `tasks/T03-PLAN.md`. Three artifacts modified:

1. `scripts/intake/proposal-emit.sh` — adds the design-gate classifier invocation after the paragraph/spec deep classifiers run; sets `DESIGN_AXES_DONE=1` so the rationale-loop skips the slot when the classifier ran. Adds the recommended_command guard: invoke `bash scripts/intake/design-gate-degradation.sh --proposal <tmp> --probe-only`; if `m023_shipped=false` AND `design_gate=walkthrough`, force the recommended_command slot to the tier-derived fallback rather than `orchestrator:design`. Wires `design_gate_revise` (already present from P06) so a revised `walkthrough` flows through the same guard.

2. `scripts/intake/approval-gate.sh` — extends the verb table with `manual` and `skip`. Both verbs:
   - Validate the proposal carries `design_gate: "walkthrough"` (else exit 2 with `ERR: 'manual'/'skip' verb requires design_gate=walkthrough on a pre-M023 checkout`).
   - Validate the M023 probe currently fails (else exit 2 with `ERR: M023 has shipped — use 'approve' to invoke orchestrator:design`).
   - Delegate to `bash scripts/intake/design-gate-degradation.sh --proposal "$PROPOSAL" --branch <verb>` and forward stdout.
   - Exit 0 on success, 1 on degradation-script failure, 2 on validation failure (preserves P03 verb-handler exit-code shape).

3. `templates/intake-proposal.md` — adds the new transient frontmatter key `pending_design_authored_manually: false` (D024 schema-authority handshake honored: P07 introduces ONE new key; the [M020](../../../../milestones/M020/index.md) D-row entry is added in T04).

Authors `scripts/verify/m024-p07-skip-branch.sh`, `scripts/verify/m024-p07-manual-branch.sh`, `scripts/verify/m024-p07-approval-gate-design-verbs.sh`. AD-19 single-script-file shape.

### T04: Phase tests + suite + write-confinement + no-orphan check + evaluate.md update + D-row entry

See `tasks/T04-PLAN.md`. Five artifacts ship:

- `tests/test-design-gate-degradation.sh` — phase-level: paragraph with UI tokens → assert FR-7 message via `grep -F` on stderr; assert verb table offers manual + skip; assert recommended_command stays at the tier fallback (no `orchestrator:design` in pre-M023 frontmatter).
- `tests/test-design-gate-skip.sh` — exercises the skip branch end-to-end.
- `tests/test-design-gate-manual.sh` — exercises the manual branch end-to-end (first invoke halts; author DESIGN.md; second invoke flips and proceeds).
- `scripts/verify/m024-p07-no-orphan-design-cmd.sh` — greps the codebase for active-code-path `orchestrator:design` references and asserts each is either probe-gated or doc-labeled.
- `scripts/verify/m024-p07-write-confinement.sh` and `scripts/verify/m024-p07-evaluate-md.sh` (per the per-claim pattern). Authors the suite runner `scripts/verify/m024-p07-suite.sh` (MEM002 parallel-array tracker; structured PASS:/FAIL: summary; runs the three phase tests + every per-task verify). Updates `commands/evaluate.md` lines 31–33 to "wired in P07", adds `manual` and `skip` rows to the approval verb table, pins the FR-7 message verbatim. Appends a single-line D-row to [`.orchestrator/DECISIONS.md`](../../../../decisions.md) documenting the `pending_design_authored_manually` schema addition under MEM031 / D024 authority handshake.

## Task Dependencies

```
T01 → T03         (proposal-emit.sh invokes design-gate-classify.sh)
T02 → T03         (proposal-emit.sh invokes design-gate-degradation.sh in probe-only mode; approval-gate.sh delegates verbs to it)
T01 + T02 + T03 → T04
```

T01 (classifier) and T02 (probe + branches) are independent — both are pure decision emitters with no inter-script calls. T03 is the load-bearing wiring (proposal-emit.sh + approval-gate.sh + template). T04 exercises the full path including the no-orphan invariant and the operator-facing doc update.

## Files Likely Touched

- scripts/intake/design-gate-classify.sh (create)
- scripts/intake/design-gate-degradation.sh (create)
- scripts/intake/proposal-emit.sh (modify — wire classifier; recommended_command guard; DESIGN_AXES_DONE flag)
- scripts/intake/approval-gate.sh (modify — add manual/skip verbs)
- templates/intake-proposal.md (modify — add pending_design_authored_manually transient key)
- commands/evaluate.md (modify — flip "lands when P07 ships" to "wired in P07"; add manual/skip rows to verb table)
- [.orchestrator/DECISIONS.md](../../../../decisions.md) (modify — append D-row for the new transient frontmatter key under MEM031 / D024 schema-authority handshake)
- tests/test-design-gate-degradation.sh (create)
- tests/test-design-gate-skip.sh (create)
- tests/test-design-gate-manual.sh (create)
- scripts/verify/m024-p07-design-gate-classify.sh (create)
- scripts/verify/m024-p07-degradation-script.sh (create)
- scripts/verify/m024-p07-pinned-message.sh (create)
- scripts/verify/m024-p07-m023-probe.sh (create)
- scripts/verify/m024-p07-skip-branch.sh (create)
- scripts/verify/m024-p07-manual-branch.sh (create)
- scripts/verify/m024-p07-no-orphan-design-cmd.sh (create)
- scripts/verify/m024-p07-approval-gate-design-verbs.sh (create)
- scripts/verify/m024-p07-write-confinement.sh (create)
- scripts/verify/m024-p07-evaluate-md.sh (create)
- scripts/verify/m024-p07-suite.sh (create)
