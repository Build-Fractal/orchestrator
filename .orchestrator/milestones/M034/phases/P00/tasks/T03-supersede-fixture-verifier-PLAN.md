---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P00"
milestone: "M034"
name: "Decide #Q-1 supersede semantics, capture fixture, author the phase verifier"
depends_on: ["T02"]
---

## Prerequisites

- `.orchestrator/milestones/M034/M034-P00-ADDENDUM.md` exists with `## PC-1` (T01) and `## PC-2` (T02) sections. Confirm before appending.
- `specs/044-interactive-review-gates/spec.md` exists (FR-1 schema, #Q-1, Edge Cases supersede note).
- M036's supersede-chain prior art is referenced by #Q-1; the lakeledger M066/P01 source artifacts are in an EXTERNAL repo not present here, so the fixture is authored as a synthetic representative (documented as such).

## Description

Closes P00 by: (a) recording the #Q-1 supersede-semantics decision; (b) capturing a representative decision-packet fixture with the multi-field entry structure P01's schema must support; (c) authoring `tools/verify/m034-p00-addendum.sh`, the project-owned phase verifier that asserts the addendum + fixture are complete. Per plan-time rule 2, this verifier is co-authored in-phase (it is the Truth-Check target for P00-PLAN.md).

## Steps

1. Decide #Q-1: supersede-in-place vs append-with-supersede-chain (mirroring M036's supersede mechanism) for packet re-runs of an already-packeted artifact. Record the decision + rationale. Recommended: append-with-supersede-chain (auditable history, consistent with M036), but the decision must be explicit. Append a `## #Q-1 — packet supersede semantics` section to `M034-P00-ADDENDUM.md`.
2. Create `.orchestrator/milestones/M034/fixtures/decisions-packet-baseline.md` — a representative packet with frontmatter (`schema_version`, `type: decision-packet`) and ~8 entries, each carrying all FR-1 fields (`id`, `summary`, `picked_value`, `rationale`, `alternatives_considered`, `concrete_impact`, `severity`, `type`). Include at least one `severity: warn` entry and one `type: boundary_translation` entry so P01/P02 fixtures have coverage. Add a header comment noting it is synthetic-representative-of-lakeledger-M066/P01 (external source unavailable in this repo).
3. Author `tools/verify/m034-p00-addendum.sh` (bash 3.2, single-file, AD-19-clean). It MUST:
   - assert `M034-P00-ADDENDUM.md` exists and contains the section markers `## PC-1`, `## PC-2`, `## #Q-1`;
   - assert the PC-2 section contains `local-agent.sh` and `RISK-5` (evidence the real backend was inspected and the escalation decided);
   - assert the addendum contains `stdin` (PC-1 wire-format committed) and `supersede` (#Q-1 decided);
   - assert `fixtures/decisions-packet-baseline.md` exists, has ≥30 lines, and contains `alternatives_considered` and `boundary_translation`;
   - print `PASS: M034 P00 addendum complete` and exit 0 on success; print `FAIL: <reason>` and exit 1 on any miss.
   - Use only simple sequential `grep -q`/`test` guards with early `exit 1` — no compound chains, subshells, or `$(...)`-with-pipe (AD-19).
4. Run `bash tools/verify/m034-p00-addendum.sh` and confirm `PASS`.

## Must-Haves

- #Q-1 decision recorded with rationale; representative fixture exists with full multi-field entries incl. a `warn` and a `boundary_translation` entry; the phase verifier passes.

## Verification

`bash tools/verify/m034-p00-addendum.sh`

## Notes

Expected output: `PASS: M034 P00 addendum complete`. This is the phase-close verifier cited by every Truth in `P00-PLAN.md`. Authoring it here (rule 2 option a) is required because P00's deliverable IS the addendum — there is no upstream verifier to inherit. The fixture is deliberately synthetic: lakeledger is an external repo; a representative packet that exercises the full field-set is the in-repo substitute and is documented as such in its header.

## Inputs

### From Previous Tasks
- `.orchestrator/milestones/M034/M034-P00-ADDENDUM.md` (from T01 + T02)
  - Key API: markdown file with `## PC-1` and `## PC-2` sections; T03 APPENDS `## #Q-1`.

### From Disk (Pre-existing)
- `specs/044-interactive-review-gates/spec.md` — FR-1 field set (for the fixture), #Q-1 + Edge Cases supersede note, the M036 supersede-chain reference.

## Constraints

- `tools/verify/m034-p00-addendum.sh` is PROJECT-OWNED → `tools/verify/` (slug-bearing `m034-p00-*`), NOT `scripts/verify/` (rule: framework dirs are bulk-staged + gitignored downstream). Milestone-prefixed filename (rule: avoid clobber).
- Verifier MUST be AD-19-clean (sequential simple guards, no compound shapes) — it runs under `auto-loop --step=V`.
- Append-only to the addendum; fixture and verifier are new creates (confirmed no collision at plan time).

## Expected Output

Three deliverables: the `## #Q-1` addendum section; `.orchestrator/milestones/M034/fixtures/decisions-packet-baseline.md`; and `tools/verify/m034-p00-addendum.sh` (passing). P00 is then complete and verifiable.
