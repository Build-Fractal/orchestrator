---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M034"
goal: "Ship the standalone decision-packet layer: a versioned schema template, a stdin-JSON writer with append-with-supersede-chain, an optional conversus producer, and status/doctor unreviewed-decision surfacing — audit value before any walkthrough exists."
demo_sentence: "A task declaring decision_packet: true emits a schema-valid *-DECISIONS.md (optionally enriched from a conversus gate-result), and `status`/`doctor` report the unreviewed load-bearing decision count per phase."
risk: "medium"
depends_on: ["P00"]
---

## Phase Scope & PC-3/4/5 Split Decision

P01 ships the **schema + writer + producer + surfacing** slice of M034 — the
standalone audit value (US1, US5). It does **not** ship the interactive
walkthrough, `REVIEW.md` capture, `SIGNOFF.md` population, auto-mode policies,
or the headless fallback — those are P02 (US2/US3/US6).

**PC-3 / PC-4 / PC-5 split (recorded per the plan-time decision the prompt
requires).** These three P1 conditions "land where the defer path first ships."
The defer path, `REVIEW.md`, the headless fallback, and `orchestrator:resume`
re-entry are all **P02** deliverables. Therefore:

- PC-3 (SC-3 simulation harness), PC-4 (headless detection), PC-5 (continue-file
  schema + `orchestrator:resume` surface) are **SPECIFIED** in this phase's
  planning artifact `.orchestrator/milestones/M034/M034-P01-ADDENDUM.md` (a
  forward-design spec authored at plan-time so P02 starts zero-context-complete).
- They are **VERIFIED** in P02, where the code they govern is built. P01 carries
  no SC-3/SC-4/SC-5 verifier — those success criteria belong to P02.

This split is deliberate: PC-3/4/5 govern P02's surfaces, but resolving their
design now (while the full M034 context is in hand) prevents P02 from
re-deriving the harness shape, the probe mechanism, and the continue-file schema
from scratch. The addendum is the binding input P02 consumes.

## Must-Haves

### Truths

- The decision-packet schema template exists, is versioned, and documents the eight FR-1 entry fields plus the supersede-chain fields, sourcing every enum/threshold from the named-constants SSOT (FR-1, CON-4).
  - Check: `bash tools/verify/m034-p01-phase-suite.sh`
- The named-constants SSOT defines the severity enum + default, the type enum + default, and the FR-4 warn-finding threshold in exactly one file that the writer, reader, and surfacing all source (CON-4).
  - Check: `bash tools/verify/m034-p01-phase-suite.sh`
- `write-decisions.sh` reads a `{"decisions":[...]}` document on stdin, extracts each field with `jq -r` (never re-shell-interpreting bodies), accepts `--milestone`/`--artifact`/`--out` flags, and emits a schema-valid packet that round-trips the P00 baseline fixture's entry set unchanged (FR-2, FR-3, PC-1).
  - Check: `bash tools/verify/m034-p01-phase-suite.sh`
- `write-decisions.sh` surfaces a clear "jq required" error and exits non-zero when jq is absent (PC-1 packaging note / FR-12 strict posture).
  - Check: `bash tools/verify/m034-p01-phase-suite.sh`
- Re-emitting an unchanged entry is an idempotent no-op (matching content_hash); a changed entry appends a superseding entry carrying `supersedes:`, and the prior entry is marked `superseded_by:` — both remain in the file (#Q-1 append-with-supersede-chain).
  - Check: `bash tools/verify/m034-p01-phase-suite.sh`
- A `producer: conversus` mapping runs `conversus.sh gate --strict` and folds the resulting `gate-result.md` verdict + surviving disputes + rationale + deliberation link into packet entries; a missing/unauthed binary BLOCKs (exits non-zero) with a `pipx install conversus-oss` pointer and never silently SKIPs (FR-11, FR-12, AD-6).
  - Check: `bash tools/verify/m034-p01-phase-suite.sh`
- `status` (via `render-status-json.sh`) reports a per-phase `unreviewed_decisions` count read from the packet's active (non-superseded) entries; `doctor` carries an advisory "Unreviewed Decisions" check that flags when unreviewed warn-severity entries cross the named SSOT threshold (FR-4, SC-2).
  - Check: `bash tools/verify/m034-p01-phase-suite.sh`
- The PC-3/PC-4/PC-5 forward-design addendum exists and specifies the SC-3 simulation harness, the headless-detection mechanism, and the continue-file schema + `orchestrator:resume` surface for P02 to consume.
  - Check: `bash tools/verify/m034-p01-phase-suite.sh`

### Artifacts

- templates/decisions-packet.md (min 40 lines, contains "schema_version")
- scripts/knowledge/lib/decisions-constants.sh (min 15 lines, contains "DECISIONS_SEVERITY_DEFAULT")
- scripts/knowledge/write-decisions.sh (min 80 lines, contains "jq")
- scripts/knowledge/read-decisions.sh (min 30 lines, contains "superseded_by")
- scripts/knowledge/decisions-from-conversus.sh (min 50 lines, contains "conversus")
- scripts/diagnostics/check-decisions.sh (min 30 lines, contains "DOCTOR:")
- .orchestrator/milestones/M034/M034-P01-ADDENDUM.md (min 80 lines, contains "PC-3")
- tools/verify/m034-p01-schema-shape.sh (min 15 lines, contains "decisions-packet")
- tools/verify/m034-p01-writer.sh (min 20 lines, contains "supersede")
- tools/verify/m034-p01-producer.sh (min 20 lines, contains "CONVERSUS_STUB")
- tools/verify/m034-p01-surfacing.sh (min 20 lines, contains "unreviewed")
- tools/verify/m034-p01-phase-suite.sh (min 15 lines, contains "m034-p01")

### Key Links

- scripts/knowledge/write-decisions.sh → scripts/knowledge/lib/decisions-constants.sh (the writer sources the named-constants SSOT)
- scripts/knowledge/read-decisions.sh → scripts/knowledge/lib/decisions-constants.sh (the reader sources the same SSOT)
- scripts/knowledge/decisions-from-conversus.sh → scripts/dispatch/adapters/tool/conversus.sh (the producer invokes the conversus gate adapter)
- .orchestrator/milestones/M034/M034-P01-ADDENDUM.md → specs/044-interactive-review-gates/spec.md (the addendum cites the PC-3/PC-4/PC-5 conditions it resolves)

## Boundary Map

- **Produces**:
  - `templates/decisions-packet.md` — the versioned FR-1 schema (frontmatter `schema_version` + typed entry array; `severity ∈ {warn, block}` default `block`; `type ∈ {decision, boundary_translation}` default `decision`; supersede-chain fields documented).
  - `scripts/knowledge/lib/decisions-constants.sh` — CON-4 named-constants SSOT (enums, defaults, FR-4 warn-finding threshold).
  - `scripts/knowledge/write-decisions.sh` — the PC-1 stdin-JSON writer with #Q-1 append-with-supersede-chain.
  - `scripts/knowledge/read-decisions.sh` — active-entry / unreviewed-count reader (consumed by surfacing; forward-consumed by P02).
  - `scripts/knowledge/decisions-from-conversus.sh` — the FR-11/FR-12 conversus producer (gate-result → packet-entry JSON, strict-when-declared).
  - `scripts/diagnostics/check-decisions.sh` + `run-doctor.sh` wiring + `render-status-json.sh` `unreviewed_decisions` field — the FR-4 surfacing.
  - `.orchestrator/milestones/M034/M034-P01-ADDENDUM.md` — PC-3/PC-4/PC-5 forward-design spec for P02 (authored at plan-time by the planner; T05 asserts its presence).
  - `tools/verify/m034-p01-*.sh` — five project-owned slice verifiers + the phase-suite aggregator.
- **Consumes**:
  - P00 `M034-P00-ADDENDUM.md` — PC-1 stdin-JSON convention, #Q-1 supersede decision, PC-2 Case A determination.
  - P00 `fixtures/decisions-packet-baseline.md` — the SC-1 schema-coverage fixture the schema + writer must accept unchanged.
  - `scripts/knowledge/write-summary.sh` — prior-art single-file bash writer shape.
  - `scripts/knowledge/lib/extract-supersede.sh` — M036 supersede-chain prior art (#Q-1 mental model).
  - `scripts/dispatch/adapters/tool/conversus.sh` — existing `gate`/`parse-verdict` subcommands + `CONVERSUS_STUB` test mode.
  - `tests/fixtures/gate-result-block.md` / `gate-result-pass.md` — stub gate-result fixtures for SC-7 producer testing.
  - `scripts/diagnostics/render-status-json.sh` + `scripts/diagnostics/run-doctor.sh` — the FR-4 integration points (modify).

## Tasks

### T01: Named-constants SSOT + versioned schema template

Author `scripts/knowledge/lib/decisions-constants.sh` (the CON-4 SSOT) and
`templates/decisions-packet.md` (the FR-1 versioned schema). The template
documents the eight entry fields + the supersede-chain fields and sources its
enums/defaults from the SSOT. Co-author `tools/verify/m034-p01-schema-shape.sh`,
which asserts the template is schema-valid and that the P00 baseline fixture
validates against it unchanged. Full zero-context plan:
`tasks/T01-constants-and-schema-PLAN.md`.

### T02: write-decisions.sh — stdin-JSON writer with supersede chain

Author `scripts/knowledge/write-decisions.sh`: bash 3.2 single-file, reads
`{"decisions":[...]}` on stdin (jq -r per field), `--milestone`/`--artifact`/
`--out` flags, jq-required with a clear error if absent, applies severity/type
defaults from the SSOT, and implements #Q-1 append-with-supersede-chain via a
per-entry content_hash. Co-author `tools/verify/m034-p01-writer.sh` (round-trips
the baseline fixture's entry set; exercises the idempotent-no-op and
changed-entry-appends supersede cases; asserts the missing-jq error path). Full
zero-context plan: `tasks/T02-write-decisions-PLAN.md`.

### T03: conversus producer — gate-result → packet entries (strict-when-declared)

Author `scripts/knowledge/decisions-from-conversus.sh`: runs
`conversus.sh gate --strict <preset> <artifact> <out>`, maps the resulting
`gate-result.md` (verdict, surviving disputes, rationale, deliberation link)
into a `{"decisions":[...]}` document, and pipes it into `write-decisions.sh`.
A missing/unauthed binary BLOCKs (exit non-zero) with a
`pipx install conversus-oss` + `conversus login` pointer — never a silent SKIP.
Co-author `tools/verify/m034-p01-producer.sh` (drives the mapping under
`CONVERSUS_STUB=1` with both verdicts; asserts the missing-binary block path).
Full zero-context plan: `tasks/T03-conversus-producer-PLAN.md`.

### T04: status/doctor unreviewed-decision surfacing

Author `scripts/knowledge/read-decisions.sh` (counts active non-superseded
entries and unreviewed load-bearing decisions per phase), add an
`unreviewed_decisions` field to `render-status-json.sh`, author
`scripts/diagnostics/check-decisions.sh` (advisory doctor check emitting a
`DOCTOR: status=...` line that flags when unreviewed warn-severity entries cross
the SSOT threshold), and wire it into `run-doctor.sh`. Co-author
`tools/verify/m034-p01-surfacing.sh`. Full zero-context plan:
`tasks/T04-surfacing-PLAN.md`.

### T05: Phase-suite aggregator verifier

Author the phase-suite aggregator `tools/verify/m034-p01-phase-suite.sh` that
invokes the four slice verifiers from T01–T04 and asserts the PC-3/4/5 addendum
is present + well-formed. (The PC-3/4/5 forward-design addendum
`M034-P01-ADDENDUM.md` is **authored at plan-time by the planner**, not this
task — it resolves design questions requiring full-milestone context that
Principle V withholds from a fresh executor; T05 only asserts its presence.)
Full zero-context plan: `tasks/T05-addendum-and-suite-PLAN.md`.

## Task Dependencies

```
T01 ─▶ T02 ─▶ T03
        │
        └────▶ T04
T01,T02,T03,T04 ─▶ T05
```

T01 establishes the SSOT + schema both the writer (T02) and reader (T04)
consume. T03 (producer) pipes into the T02 writer, so it follows T02. T04
(surfacing) reads packets the T02 writer emits, so it follows T02 (independent
of T03). T05 authors the aggregator that calls T01–T04's slice verifiers, so it
is last. The addendum half of T05 is design-independent but co-located in the
final task for a single tail.

## Operator Onboarding (conversus-OSS prerequisite — STANDING ITEM)

A `producer: conversus` gate BLOCKs by design (FR-12) when the conversus binary
is absent/unauthed. The dogfooder must, before exercising any conversus-backed
gate:

1. `pipx install conversus-oss` (or clone to `~/Sites/conversus-oss`), then
2. `conversus login anthropic` — on OAuth, `CONVERSUS_PROVIDER=claude-code`
   auto-sets from `~/.conversus/auth.json`.

T03's strict-block error message carries this exact pointer so the runtime
surfaces it. This is a runtime precondition, not a P01 build dependency — P01's
producer verifier exercises the mapping under `CONVERSUS_STUB=1` (no real
binary needed for CI).

## Files Likely Touched

- scripts/knowledge/lib/decisions-constants.sh (create)
- templates/decisions-packet.md (create)
- scripts/knowledge/write-decisions.sh (create)
- scripts/knowledge/read-decisions.sh (create)
- scripts/knowledge/decisions-from-conversus.sh (create)
- scripts/diagnostics/check-decisions.sh (create)
- scripts/diagnostics/run-doctor.sh (modify — wire the advisory check)
- scripts/diagnostics/render-status-json.sh (modify — add unreviewed_decisions field)
- .orchestrator/milestones/M034/M034-P01-ADDENDUM.md (create — plan-time, already on disk)
- tools/verify/m034-p01-schema-shape.sh (create)
- tools/verify/m034-p01-writer.sh (create)
- tools/verify/m034-p01-producer.sh (create)
- tools/verify/m034-p01-surfacing.sh (create)
- tools/verify/m034-p01-phase-suite.sh (create)
