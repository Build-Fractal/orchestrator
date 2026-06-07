---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M034"
goal: "Ship the headline interactive review gate: the interactive_review lifecycle stage (renderer-routed via dispatch-interface.sh), the CC AskUserQuestion walkthrough writing REVIEW.md and populating SIGNOFF.md, the three auto-mode policies (defer/accept-with-audit/refuse-entry) with continue-file + orchestrator:resume round-trip, the headless QUESTIONS.md fallback, and the boundary_translation packet type."
demo_sentence: "An operator is walked through a *-DECISIONS.md packet in Claude Code; each response lands append-only in REVIEW.md and populates SIGNOFF.md; an autonomous run at the gate applies its declared policy (defer writes a continue-file and exits clean, resumable via orchestrator:resume) without ever deadlocking."
risk: "high"
depends_on: ["P01"]
---

## Phase Scope

P02 is the headline UX of M034 (US2, US3, US6). It builds the interactive
walkthrough on top of P01's standalone decision-packet layer (schema + writer +
reader + surfacing). P02 ships:

- **FR-5** — `scripts/lifecycle/interactive-review.sh`, the `interactive_review`
  lifecycle stage for phases declaring `review_gates: [...]`. Reads
  `*-DECISIONS.md`, selects the renderer via `dispatch-interface.sh` (CON-7),
  captures responses to `REVIEW.md`, populates `SIGNOFF.md` from the terminal
  entry. Carries `--test-responses` (PC-3), `--resume=<continue-file>` (PC-5),
  and the `ORCH_HEADLESS` probe (PC-4).
- **FR-6** — the CC `AskUserQuestion` renderer (Case A: the orchestrating agent
  issues `AskUserQuestion` per decision with concrete-impact framing and writes
  `REVIEW.md` directly).
- **FR-7** — `templates/review.md` + the append-only `REVIEW.md` audit (one
  block per gate visit, `*-REVIEW.md` co-located) + `SIGNOFF.md` population. The
  decision artifact is ALWAYS written regardless of policy (CON-5/SC-5).
- **FR-8** — auto-mode policies `defer | accept-with-audit | refuse-entry`
  (default `defer`).
- **FR-9** — headless `QUESTIONS.md` hand-off when no interactive primitive
  exists (PC-4 detection).
- **FR-13** — the `boundary_translation` packet type (`touches_persistence: true`
  normative for v1 per #Q-6; the planner heuristic is advisory-only).
- The `orchestrator:resume` `pending-review-continue` state-scan branch (PC-5).

P02 **verifies** the three P1 pre-planning conditions P01 forward-specified in
`M034-P01-ADDENDUM.md`: PC-3 (SC-3 simulation harness), PC-4 (headless
detection), PC-5 (continue-file + resume round-trip). These are P02 success
criteria — the code they govern is built here.

## Binding Plan-Time Decisions (recorded per Plan-Time Discipline)

These are load-bearing interpretations the executors must NOT re-decide. They
resolve the only open design seams the binding addenda leave to P02 plan-time.

- **D-P02-1 — renderer-probe seam = a thin `--probe-renderer` first-arg
  passthrough on `dispatch-interface.sh`.** PC-4 (M034-P01-ADDENDUM.md) binds
  "`interactive-review.sh` resolves the renderer context through a
  `dispatch-interface.sh` capability probe (CON-7 — never a direct primitive
  call)." The seam is implemented as a `--probe-renderer` first-arg passthrough
  added to `dispatch-interface.sh` (mirroring the existing `--query` passthrough
  at `dispatch-interface.sh:55`, which `exec`s out at the very top before any
  backend/shadow logic). The passthrough delegates to the existing
  `backend-registry.sh --probe <name>` roster (the dispatch layer's
  filename-routed adapter probe surface — `local-agent.sh` / `cursor-agent.sh`)
  and emits exactly one line `renderer=interactive-cc|interactive-cursor|headless`.
  This honors CON-7 literally (selection routed through `dispatch-interface.sh`,
  never a question primitive) while reusing `backend-registry.sh` and never
  touching the fragile M030 shadow logic. `interactive-review.sh` calls
  `dispatch-interface.sh --probe-renderer` and branches on the `renderer=` line.
  Precedence (PC-4): `ORCH_HEADLESS=1` → `headless` unconditionally (highest);
  else probe `local-agent` → `interactive-cc` when `available=true`; else probe
  `cursor-agent` → `interactive-cursor` when `available=true` (P03 wires the
  actual Cursor MCP renderer; P02 only routes to it); else `headless`.
- **D-P02-2 — SIGNOFF.md shape is P02-owned (`templates/signoff.md`, create).**
  The spec names `SIGNOFF.md` an "existing primitive," but grep shows no SIGNOFF
  template or generator anywhere in the framework — it is a downstream-project
  artifact convention, not an orchestrator-repo one. P02 therefore DEFINES the
  shape it populates as `templates/signoff.md` and `interactive-review.sh`
  writes a co-located `*-SIGNOFF.md` from `REVIEW.md`'s terminal entry. This is
  "populates SIGNOFF.md" (non-goal: replacing it) — the populate target's shape
  is what P02 ships.
- **D-P02-3 — REVIEW.md reviewed-marker line is `reviewed: <id>`.** P01's
  `read-decisions.sh::_is_reviewed` (read it: `read-decisions.sh:107-118`)
  counts an id reviewed iff the sibling `*-REVIEW.md` carries `reviewed: <id>`
  OR `- **id**: <id>` on its own line. Every REVIEW.md block P02 writes for an
  operator-touched decision (`accept`/`override`/`pushback`/`na`, and the
  `accept-with-audit` auto-accept) ends with a `reviewed: <id>` line — this is
  what drives the FR-4/SC-2 unreviewed-count to zero. `defer` writes NO REVIEW.md
  block (the decisions stay pending until resume), so the count stays > 0 until
  the round-trip completes.
- **D-P02-4 — action + policy enums live in the P01 CON-4 SSOT.** The walkthrough
  `action` enum (`accept override pushback na`) and the auto-mode `policy` enum
  (`defer accept-with-audit refuse-entry`, default `defer`) are added to
  `scripts/knowledge/lib/decisions-constants.sh` (the existing FR-1 named-constant
  SSOT) — not redeclared in `interactive-review.sh`. CON-4 / CON-8 (the policy
  enum value is `refuse-entry`, never `block`).
- **D-P02-5 — boundary_translation is explicit-only for v1 (#Q-6).** A
  `boundary_translation` entry is emitted only when a task carries
  `touches_persistence: true` (normative). The planner heuristic (SQL reads /
  migrations / ORM / format readers / protocol parsers) is documented as
  **advisory** in `references/interactive-review-renderer.md` and does NOT
  auto-fire in v1. `emit-boundary-translation.sh` takes the four FR-13 fields
  explicitly.

## Must-Haves

### Truths

- `dispatch-interface.sh --probe-renderer` resolves exactly one renderer state (`interactive-cc` / `interactive-cursor` / `headless`) by delegating to the `backend-registry.sh` probe roster, and `ORCH_HEADLESS=1` forces `headless` unconditionally (highest precedence) — the PC-4 detection mechanism, routed through `dispatch-interface.sh` per CON-7 (D-P02-1).
  - Check: `bash tools/verify/m034-p02-renderer-probe.sh`
- The action enum (`accept override pushback na`) and the policy enum (`defer accept-with-audit refuse-entry`, default `defer`) are defined in the P01 CON-4 SSOT (`decisions-constants.sh`) with validators, and the policy enum value is `refuse-entry` (never `block`) per CON-8 (D-P02-4).
  - Check: `bash tools/verify/m034-p02-renderer-probe.sh`
- `interactive-review.sh --test-responses=<fixture>` against a packet fixture appends exactly one `REVIEW.md` block per active packet decision in packet order, each recording the fixture's `action`; an `override` entry's `value` + `rationale` appear verbatim in its block; `SIGNOFF.md` is populated from `REVIEW.md`'s terminal entry; the run is hermetic (no human, no network) — SC-3/PC-3 (D-P02-3).
  - Check: `bash tools/verify/m034-p02-test-responses.sh`
- After a `--test-responses` run reviews every active decision, `read-decisions.sh unreviewed-count` on the packet returns 0 (the SC-2 zero-after half closes once the gate populates REVIEW.md).
  - Check: `bash tools/verify/m034-p02-test-responses.sh`
- Under `ORCH_HEADLESS=1`, policy `defer` writes a `pending_review` JSONL event + a `<gate_id>-CONTINUE.md` continue-file (PC-5 schema) and exits 0; `accept-with-audit` writes one `auto_accepted` JSONL per decision + populates REVIEW.md/SIGNOFF.md; `refuse-entry` refuses phase entry with a `refused_entry` JSONL event — and all three still write/keep the `*-DECISIONS.md` (always-write CON-5/SC-5) — SC-4 write-side.
  - Check: `bash tools/verify/m034-p02-auto-policies.sh`
- A headless run with no interactive primitive writes a `QUESTIONS.md` hand-off and applies the declared policy without hanging (watchdog never fires) — SC-5/FR-9.
  - Check: `bash tools/verify/m034-p02-auto-policies.sh`
- The full defer→resume round-trip: a `defer` gate under `ORCH_HEADLESS=1` writes the continue-file + `pending_review` JSONL and exits 0; a subsequent `interactive-review.sh --resume=<continue-file>` (the path `orchestrator:resume` routes to) re-enters at `last_review_md_block_index`, completes the remaining decisions WITHOUT re-writing the already-recorded blocks, and populates `SIGNOFF.md` — SC-4 round-trip/PC-5.
  - Check: `bash tools/verify/m034-p02-resume-roundtrip.sh`
- `commands/resume.md` carries a `pending-review-continue` state-scan branch that routes a `type: pending-review-continue` continue-file to `interactive-review.sh --resume`.
  - Check: `bash tools/verify/m034-p02-resume-roundtrip.sh`
- A `touches_persistence: true` fixture whose plan vocabulary diverges from a fixture schema emits a `type: boundary_translation` packet entry carrying all four FR-13 fields (source-vocab id, target-vocab id, transform site `file:line`, verification mechanism); the walkthrough surfaces it as a confirm-the-bridge decision; the `na` action records acknowledged-not-applicable in REVIEW.md — SC-8/FR-13.
  - Check: `bash tools/verify/m034-p02-boundary-translation.sh`
- The CC `AskUserQuestion` renderer surface exists: `interactive-review.sh` emits a render-descriptor on the `interactive-cc` path (Case A coordination boundary) and `references/interactive-review-renderer.md` instructs the orchestrating agent how to conduct the walkthrough and write REVIEW.md directly — FR-6.
  - Check: `bash tools/verify/m034-p02-phase-suite.sh`
- The phase-suite aggregator runs all five P02 slice verifiers and asserts the FR-6 renderer surface — green only when every slice passes.
  - Check: `bash tools/verify/m034-p02-phase-suite.sh`

### Artifacts

- scripts/lifecycle/interactive-review.sh (min 150 lines, contains "review_gates")
- templates/review.md (min 15 lines, contains "action")
- templates/signoff.md (min 10 lines, contains "approved_by")
- scripts/knowledge/emit-boundary-translation.sh (min 40 lines, contains "boundary_translation")
- references/interactive-review-renderer.md (min 30 lines, contains "AskUserQuestion")
- scripts/knowledge/lib/decisions-constants.sh (min 60 lines, contains "DECISIONS_POLICY_VALUES")
- scripts/dispatch/dispatch-interface.sh (min 200 lines, contains "probe-renderer")
- commands/resume.md (min 200 lines, contains "pending-review-continue")
- commands/auto.md (min 1 line, contains "ORCH_HEADLESS")
- tools/verify/m034-p02-renderer-probe.sh (min 20 lines, contains "probe-renderer")
- tools/verify/m034-p02-test-responses.sh (min 30 lines, contains "test-responses")
- tools/verify/m034-p02-auto-policies.sh (min 30 lines, contains "pending_review")
- tools/verify/m034-p02-resume-roundtrip.sh (min 30 lines, contains "last_review_md_block_index")
- tools/verify/m034-p02-boundary-translation.sh (min 20 lines, contains "boundary_translation")
- tools/verify/m034-p02-phase-suite.sh (min 15 lines, contains "m034-p02")

### Key Links

- scripts/lifecycle/interactive-review.sh → scripts/dispatch/dispatch-interface.sh (renderer-probe seam, CON-7 / D-P02-1)
- scripts/lifecycle/interactive-review.sh → scripts/knowledge/read-decisions.sh (reads the packet; drives the unreviewed-count to zero)
- scripts/lifecycle/interactive-review.sh → scripts/knowledge/lib/decisions-constants.sh (action + policy enum SSOT)
- scripts/knowledge/emit-boundary-translation.sh → scripts/knowledge/write-decisions.sh (pipes the boundary_translation entry)
- commands/resume.md → scripts/lifecycle/interactive-review.sh (the --resume re-entry target)

## Boundary Map

- **Produces**:
  - `scripts/lifecycle/interactive-review.sh` — the `interactive_review` stage (FR-5): renderer routing, REVIEW.md writer, SIGNOFF.md population, `--test-responses` (PC-3), `--resume` (PC-5), auto-mode policy paths (FR-8), headless QUESTIONS.md (FR-9).
  - `--probe-renderer` passthrough on `scripts/dispatch/dispatch-interface.sh` — the PC-4 renderer-detection seam (CON-7, D-P02-1).
  - `templates/review.md` — the REVIEW.md append-only block schema (FR-7).
  - `templates/signoff.md` — the SIGNOFF.md shape interactive-review.sh populates (D-P02-2).
  - `scripts/knowledge/emit-boundary-translation.sh` — the FR-13 boundary_translation producer.
  - `references/interactive-review-renderer.md` — the FR-6 CC AskUserQuestion walkthrough instruction surface (Case A).
  - action + policy enums in `scripts/knowledge/lib/decisions-constants.sh` (CON-4 SSOT extension).
  - `commands/resume.md` `pending-review-continue` branch (PC-5) + `commands/auto.md` `ORCH_HEADLESS` policy hook (FR-8).
  - `tools/verify/m034-p02-*.sh` — five slice verifiers + the phase-suite aggregator.
- **Consumes**:
  - P01 `scripts/knowledge/read-decisions.sh` (active-ids / unreviewed-count / `_is_reviewed` REVIEW.md contract), `write-decisions.sh` (the boundary_translation emit path), `lib/decisions-constants.sh` (the SSOT to extend), `templates/decisions-packet.md` (the packet block shape REVIEW.md mirrors).
  - P00/P01 `M034-P01-ADDENDUM.md` — PC-3 fixture format + `--test-responses` flag, PC-4 three-state detection + `ORCH_HEADLESS` precedence, PC-5 `<gate_id>-CONTINUE.md` schema + resume state-scan extension.
  - `scripts/dispatch/dispatch-interface.sh` + `backend-registry.sh` + `adapters/backend/{local-agent,cursor-agent}.sh` (the probe roster the renderer seam delegates to).
  - `scripts/lifecycle/auto-loop.sh` (CON-1 prior-art shape; the `--step`/`--output-file` flag-parse + JSONL-append patterns interactive-review.sh follows).
  - `templates/continue-file.md` (the generic continue-file convention the PC-5 `<gate_id>-CONTINUE.md` mirrors) + `commands/resume.md` (the M029 surface PC-5 extends).

## Tasks

### T01: SSOT enums + dispatch-interface --probe-renderer seam + REVIEW/SIGNOFF templates

Extend `scripts/knowledge/lib/decisions-constants.sh` with the `action` and
`policy` enums + validators (D-P02-4). Add the `--probe-renderer` first-arg
passthrough to `scripts/dispatch/dispatch-interface.sh` (D-P02-1) delegating to
`backend-registry.sh`. Author `templates/review.md` (REVIEW.md block schema,
D-P02-3) and `templates/signoff.md` (SIGNOFF shape, D-P02-2). Co-author
`tools/verify/m034-p02-renderer-probe.sh`. Full plan:
`tasks/T01-ssot-and-probe-seam-PLAN.md`.

### T02: interactive-review.sh stage spine + --test-responses (SC-3)

Author `scripts/lifecycle/interactive-review.sh`: bash 3.2 single-file, arg
parse (`--packet`/`--gate-id`/`--milestone`/`--phase`/`--policy`/
`--test-responses`/`--resume`), source the T01 SSOT + P01 `read-decisions.sh`,
resolve the renderer via `dispatch-interface.sh --probe-renderer`, and lay the
renderer-routing skeleton (interactive-cc branch stubbed for T06; headless
branch stubbed for T03). Implement the deterministic REVIEW.md block writer +
SIGNOFF.md population and the `--test-responses` hermetic path (PC-3/SC-3:
one block per decision in packet order, override value+rationale verbatim,
default-accept for ids absent from the fixture). Co-author
`tools/verify/m034-p02-test-responses.sh` (SC-3 + SC-2 zero-after). Full plan:
`tasks/T02-interactive-review-spine-PLAN.md`.

### T03: auto-mode policies + continue-file write + headless QUESTIONS.md (SC-4 write-side, SC-5)

Fill the headless branch of `interactive-review.sh`: read the declared policy
(`--policy` / gate frontmatter, default `defer`); `defer` → write
`<gate_id>-CONTINUE.md` (PC-5 schema) + a `pending_review` JSONL event + exit 0;
`accept-with-audit` → one `auto_accepted` JSONL per decision + REVIEW.md
(reviewed) + SIGNOFF; `refuse-entry` → `refused_entry` JSONL + refuse entry
(non-zero). When no interactive primitive exists, write a `QUESTIONS.md`
hand-off and apply the policy without hanging (FR-9). Preserve always-write
(CON-5/SC-5) on every path. Modify `commands/auto.md` to export
`ORCH_HEADLESS=1` before a gated phase and read the gate policy. Co-author
`tools/verify/m034-p02-auto-policies.sh` (SC-4 defer/accept/refuse + SC-5
headless). Full plan: `tasks/T03-auto-policies-and-headless-PLAN.md`.

### T04: PC-5 resume round-trip — interactive-review.sh --resume + commands/resume.md branch (SC-4 round-trip)

Add the `--resume=<continue-file>` re-entry to `interactive-review.sh`: read
`last_review_md_block_index` from the continue-file, re-enter at `index+1`,
complete the remaining decisions WITHOUT re-writing recorded blocks, populate
SIGNOFF, and remove the consumed continue-file. Modify `commands/resume.md` to
add the `pending-review-continue` state-scan branch that detects a
`type: pending-review-continue` continue-file and routes recovery to
`interactive-review.sh --resume`. Co-author
`tools/verify/m034-p02-resume-roundtrip.sh` (the full defer→resume→SIGNOFF
round-trip at the recorded position). Full plan:
`tasks/T04-resume-roundtrip-PLAN.md`.

### T05: boundary_translation packet type (FR-13, SC-8)

Author `scripts/knowledge/emit-boundary-translation.sh`: given the four FR-13
fields (source-vocab id, target-vocab id, transform site `file:line`,
verification mechanism), build a `{"decisions":[{...,"type":"boundary_translation"}]}`
document and pipe it to `write-decisions.sh` (explicit `touches_persistence`
path only — #Q-6/D-P02-5). Add the confirm-the-bridge framing for
`boundary_translation` entries in `interactive-review.sh`'s walkthrough and
ensure the `na` action records acknowledged-not-applicable in REVIEW.md.
Co-author `tools/verify/m034-p02-boundary-translation.sh` (SC-8: four fields +
surfaced-as-confirm + na records ack). Full plan:
`tasks/T05-boundary-translation-PLAN.md`.

### T06: CC AskUserQuestion renderer surface (FR-6) + phase-suite aggregator

Author `references/interactive-review-renderer.md` — how the orchestrating agent
conducts the `AskUserQuestion` walkthrough on the `interactive-cc` path and
writes `REVIEW.md` directly (Case A, per `M034-P00-ADDENDUM.md`), including the
advisory boundary_translation heuristic note (#Q-6). Fill the `interactive-cc`
branch of `interactive-review.sh` to emit the render-descriptor (Notes section
points the agent at the references doc, mirroring `local-agent.sh`'s
coordination-boundary pattern). Author the phase-suite aggregator
`tools/verify/m034-p02-phase-suite.sh` that runs the T01–T05 slice verifiers and
asserts the FR-6 surface. Full plan:
`tasks/T06-cc-renderer-and-suite-PLAN.md`.

## Task Dependencies

```
T01 ─▶ T02 ─▶ T03 ─▶ T04
              │
              ├─▶ T05
              │
T01..T05 ─────┴─▶ T06
```

T01 establishes the SSOT enums + the renderer-probe seam + REVIEW/SIGNOFF
templates that T02's spine consumes. T02 lays the stage spine + the deterministic
`--test-responses` path + the renderer-routing skeleton. T03 fills the headless
policy branch (continue-file + JSONL + QUESTIONS.md); T04 adds the `--resume`
re-entry (depends on T03's continue-file). T05 (boundary_translation) reads the
packet + na handling from T02. T06 fills the interactive-cc branch + authors the
FR-6 doc + the aggregator that calls every prior slice verifier, so it is last.

## Files Likely Touched

- scripts/lifecycle/interactive-review.sh (create)
- scripts/knowledge/emit-boundary-translation.sh (create)
- templates/review.md (create)
- templates/signoff.md (create)
- references/interactive-review-renderer.md (create)
- scripts/knowledge/lib/decisions-constants.sh (modify — add action + policy enums)
- scripts/knowledge/read-decisions.sh (modify — expose active-ids subcommand)
- scripts/dispatch/dispatch-interface.sh (modify — add --probe-renderer passthrough)
- commands/resume.md (modify — add pending-review-continue branch)
- commands/auto.md (modify — export ORCH_HEADLESS before gated phases + read policy)
- tools/verify/m034-p02-renderer-probe.sh (create)
- tools/verify/m034-p02-test-responses.sh (create)
- tools/verify/m034-p02-auto-policies.sh (create)
- tools/verify/m034-p02-resume-roundtrip.sh (create)
- tools/verify/m034-p02-boundary-translation.sh (create)
- tools/verify/m034-p02-phase-suite.sh (create)
