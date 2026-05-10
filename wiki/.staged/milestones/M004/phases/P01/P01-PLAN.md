---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M004"
goal: "Update constitution to v2.0.0 with 6 new principles and create ANTIPATTERNS.md register"
demo_sentence: "The constitution contains 13 principles (7 original + 6 new), an amended Principle II requiring structured events, and an ANTIPATTERNS.md exists at the root with at least 2 entries referencing real observed incidents from M001-M003."
risk: "low"
depends_on: []
---

## Must-Haves

### Truths

- The constitution contains exactly 13 numbered principles (I through XIII)
  - Check: `test "$(grep -c '^### [IVXLC]*\.' .specify/memory/constitution.md)" -ge 13`
- Principle II text includes requirement for structured event emission from engine-managed scripts
  - Check: `grep -q 'structured event' .specify/memory/constitution.md`
- Constitution version string is 2.0.0
  - Check: `grep -q 'Version.*2\.0\.0' .specify/memory/constitution.md`
- Sync Impact Report exists as an HTML comment in the constitution file
  - Check: `grep -q 'Sync Impact Report' .specify/memory/constitution.md`
- ANTIPATTERNS.md has at least 2 antipattern entries with real incident references
  - Check: `test "$(grep -c '^## AP-' ANTIPATTERNS.md)" -ge 2`
- Antipattern entries reference specific milestones (M001, [M002](../../../../milestones/M002/index.md), or [M003](../../../../milestones/M003/index.md)) as evidence
  - Check: `grep -q 'M00[123]' ANTIPATTERNS.md`

### Artifacts

- `.specify/memory/constitution.md` (min 280 lines, contains "2.0.0")
- `ANTIPATTERNS.md` (min 40 lines, contains "AP-")

### Key Links

- `ANTIPATTERNS.md` → `.specify/memory/constitution.md` (antipatterns reference constitutional principles)

## Tasks

### T01: Constitution v2.0.0

Update `.specify/memory/constitution.md` to add 6 new principles (VIII-XIII), amend Principle II, bump version to 2.0.0, and write a Sync Impact Report in the existing HTML comment block.

### T02: Antipattern Register

Create `ANTIPATTERNS.md` at the orchestrator root with at least 2 entries referencing real observed incidents from M001-M003 audit findings and lessons learned.

## Task Dependencies

T01 → T02

T02 references constitutional principles by number, so T01 must complete first.

## Files Likely Touched

- `.specify/memory/constitution.md` (modify)
- `ANTIPATTERNS.md` (create)
