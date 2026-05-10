---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M033"
name: "Friendly-tester pass artifacts + validate-report.sh + report fixtures (FR-19 / SC-15 gate)"
depends_on: []
---

## Prerequisites

- `tests/m033-acceptance/` directory does NOT yet exist — verified by `[ ! -d tests/m033-acceptance ]`. T04 creates `tests/m033-acceptance/friendly-tester-pass/` and `tests/m033-acceptance/friendly-tester-pass/fixtures/`.
- `tools/verify/` exists.
- The FR-19 / US-8 / SC-15 / SC-8 spec entries are documented in the M033 spec body (planning payload). This task plan re-states the contract inline.
- The launch sequencing amendment ([`.orchestrator/proposals/launch-sequencing-amendment-2026-05-03.md`](../../../../../proposals/launch-sequencing-amendment-2026-05-03.md)) names the friendly-tester pass as the load-bearing change between published and amended sequences — not consumed at execution time but informs the protocol artifact's framing.

## Description

T04 ships the friendly-tester pass artifact set that gates milestone close per CON-2 / SC-15. The artifact set is curatorial + mechanical: (a) a markdown protocol document an outsider tester reads to walk each of the four init branches in 30 minutes, (b) a markdown report template the tester (or a recording maintainer) fills out, (c) a bash validator that reads the filled report and exits 0 iff `friction_blockers: 0` AND `eligible_testers >= 1`, and (d) two test fixtures (pass + fail) that exercise the validator's mechanical gate. The validator's correctness is what makes SC-15 a real mechanical gate rather than an advisory commitment.

**Validator parsing approach.** The validator parses YAML frontmatter via `grep`/`sed`/`awk` only (no jq, no python — MEM001 / Bash 3.2 compatibility). Frontmatter fields are simple scalars (`friction_blockers: <int>`, `eligible_testers: <int>`) and a YAML list (`tester_attestations:` — the validator reads each `tester_id:` + `not_familiar_with_orchestrator:` pair via two-line scan).

**The validator does NOT enforce SC-15's escalation path** (the `M033_SKIP_FRIENDLY_TESTER_PASS=1` signed-attestation). That gate lives in `validate-milestone.sh` ([M032](../../../../../milestones/M032/index.md) / [M030](../../../../../milestones/M030/index.md) closed pattern) — `validate-report.sh` is purely the per-report shape verifier.

## Steps

1. **Create the directory structure:**

   ```bash
   mkdir -p tests/m033-acceptance/friendly-tester-pass/fixtures
   ```

2. **Author `tests/m033-acceptance/friendly-tester-pass/protocol.md`** (≥100 lines). Required sections (verifier asserts each):

   - `# M033 Friendly-Tester Pass Protocol` (H1)
   - `## Purpose` — names FR-19 / US-8 / SC-15 / CON-2; explains the cold-start UX rationale (synthetic fixtures are weak signal; warm-body walkthroughs are the only adequate evidence for first-impression UX).
   - `## Tester Eligibility` — the checklist with the `not_familiar_with_orchestrator: yes/no` self-attestation field. Must explicitly exclude orchestrator maintainers and contributors (per Edge Case `Friendly-tester pass run by a tester who is too close`). The checklist enumerates: (a) has not contributed to orchestrator, (b) has not read the M033 spec, (c) has not been briefed on the four init branches.
   - `## Pre-Conditions (Per Branch)` — for each of the four branches (`greenfield-empty`, `greenfield-with-materials`, `existing-codebase`, `migrating`), document the fixture project shape the tester walks against. For `greenfield-empty`: empty project directory. For `greenfield-with-materials`: tester is asked to provide 3+ markdown materials they've drafted before, OR is given the synthetic PBJ fixture as fallback. For `existing-codebase`: tester provides their own real codebase. For `migrating`: tester provides a `.specify/` or `.gsd/` shaped project, OR walks against a synthetic fixture if no candidate available.
   - `## 30-Minute Walkthrough Script (Per Branch)` — four sub-sections, one per branch. Each script lists: (a) the literal invocation lines (`bash scripts/lifecycle/start.sh --project-dir <fixture>`), (b) what the tester should observe at each step, (c) what to capture if the observation deviates from expectation.
   - `## Friction Capture Template` — three categories per branch: `where they got stuck`, `where they re-read`, `where they bounced`. Include guidance on classifying friction as `blocker` (cannot proceed without help) vs `warning` (annoying but recoverable).
   - `## Reporting` — points the tester at `report-template.md` and the `validate-report.sh` mechanical gate; explains that `friction_blockers > 0` blocks milestone close (SC-15) but `friction_warnings > 0` is acceptable.

   Required content tokens (verifier asserts via `grep -q`): `tester-eligibility`, `not_familiar_with_orchestrator`, `greenfield-empty`, `greenfield-with-materials`, `existing-codebase`, `migrating`, `30-minute`, `friction`, `validate-report.sh`, `report-template.md`.

3. **Author `tests/m033-acceptance/friendly-tester-pass/report-template.md`** (≥40 lines). Required structure:

   ```markdown
   ---
   schema_version: "1.0"
   type: friendly-tester-report
   report_date: "YYYY-MM-DD"
   eligible_testers: 0
   friction_blockers: 0
   friction_warnings: 0
   tester_attestations:
     - tester_id: "T1"
       not_familiar_with_orchestrator: "yes"
   tested_branches:
     - greenfield-empty
     - greenfield-with-materials
     - existing-codebase
     - migrating
   ---

   # M033 Friendly-Tester Report

   ## Tester(s)
   - T1 — <self-described background>

   ## Branch: greenfield-empty
   ### Friction (Blockers)
   <list one per blocker, or "(none)">
   ### Friction (Warnings)
   <list one per warning, or "(none)">
   ### Notes
   <free-form observations>

   ## Branch: greenfield-with-materials
   ### Friction (Blockers)
   ### Friction (Warnings)
   ### Notes

   ## Branch: existing-codebase
   ### Friction (Blockers)
   ### Friction (Warnings)
   ### Notes

   ## Branch: migrating
   ### Friction (Blockers)
   ### Friction (Warnings)
   ### Notes

   ## Aggregate
   - Eligible testers: <int>
   - Total friction blockers: <int>
   - Total friction warnings: <int>
   ```

   Required content tokens: `friction_blockers:`, `friction_warnings:`, `eligible_testers:`, `tester_attestations:`, `tested_branches:`, `report_date:`.

4. **Author `tests/m033-acceptance/friendly-tester-pass/validate-report.sh`** (≥70 lines, executable, `chmod +x`, bash 3.2 compatible). The script:

   ```bash
   #!/usr/bin/env bash
   set -e -u -o pipefail

   REPORT="${1:-}"

   if [ -z "$REPORT" ]; then
     echo "usage: validate-report.sh <report.md>" >&2
     exit 2
   fi

   if [ ! -f "$REPORT" ]; then
     echo "friendly-tester pass not run — milestone close blocked" >&2
     echo "  expected report at: $REPORT" >&2
     exit 1
   fi

   # Extract frontmatter scalars via grep/sed (no jq).
   blockers=$(awk '/^friction_blockers: /{print $2; exit}' "$REPORT" | tr -d ' "')
   eligible=$(awk '/^eligible_testers: /{print $2; exit}' "$REPORT" | tr -d ' "')
   warnings=$(awk '/^friction_warnings: /{print $2; exit}' "$REPORT" | tr -d ' "')

   blockers="${blockers:-0}"
   eligible="${eligible:-0}"
   warnings="${warnings:-0}"

   # Count eligible attestations (not_familiar_with_orchestrator: yes)
   eligible_attest=$(awk '/not_familiar_with_orchestrator: "?yes"?/{n++} END{print n+0}' "$REPORT")

   # Tester is eligible iff their attestation says "yes"
   actual_eligible="$eligible_attest"

   fail=0

   if [ "$blockers" -gt 0 ]; then
     echo "FAIL: friction_blockers=$blockers (must be 0 for SC-15)" >&2
     # Echo blocker descriptions from body (lines under "### Friction (Blockers)" through next ###)
     awk '/^### Friction \(Blockers\)/{flag=1; next} /^###|^## /{flag=0} flag && /^- /{print "  blocker: " $0}' "$REPORT" >&2
     fail=1
   fi

   if [ "$actual_eligible" -lt 1 ]; then
     echo "FAIL: no eligible testers — recruit ≥1 outsider per SC-15" >&2
     fail=1
   fi

   if [ "$fail" -eq 1 ]; then
     exit 1
   fi

   echo "PASS: friction_blockers=0 eligible_testers=$actual_eligible warnings=$warnings"
   exit 0
   ```

   Required content tokens (verifier asserts): `friction_blockers`, `eligible_testers`, `not_familiar_with_orchestrator`, `milestone close blocked`.

5. **Author `tests/m033-acceptance/friendly-tester-pass/fixtures/report-pass.md`** (≥15 lines). A minimal report shaped to pass `validate-report.sh`:

   ```markdown
   ---
   schema_version: "1.0"
   type: friendly-tester-report
   report_date: "2026-05-04"
   eligible_testers: 1
   friction_blockers: 0
   friction_warnings: 1
   tester_attestations:
     - tester_id: "T1"
       not_familiar_with_orchestrator: "yes"
   tested_branches:
     - greenfield-empty
   ---

   # Friendly Tester Report (Pass Fixture)

   ## Branch: greenfield-empty
   ### Friction (Blockers)
   (none)
   ### Friction (Warnings)
   - Took 5 seconds to find the --branch flag in the help text.
   ```

6. **Author `tests/m033-acceptance/friendly-tester-pass/fixtures/report-fail.md`** (≥15 lines). A minimal report shaped to fail `validate-report.sh` (one blocker):

   ```markdown
   ---
   schema_version: "1.0"
   type: friendly-tester-report
   report_date: "2026-05-04"
   eligible_testers: 1
   friction_blockers: 1
   friction_warnings: 0
   tester_attestations:
     - tester_id: "T1"
       not_familiar_with_orchestrator: "yes"
   tested_branches:
     - existing-codebase
   ---

   # Friendly Tester Report (Fail Fixture)

   ## Branch: existing-codebase
   ### Friction (Blockers)
   - Could not figure out which --branch flag corresponds to "I have an existing codebase but no specs."
   ### Friction (Warnings)
   (none)
   ```

7. **Author `tools/verify/m033-p01-friendly-tester-protocol-shape.sh`** (≥25 lines, executable). Asserts `protocol.md` exists; required content tokens present; required section headers present (`## Purpose`, `## Tester Eligibility`, `## Pre-Conditions (Per Branch)`, `## 30-Minute Walkthrough Script (Per Branch)`, `## Friction Capture Template`, `## Reporting`). Emits PASS/SUMMARY.

8. **Author `tools/verify/m033-p01-report-template-shape.sh`** (≥25 lines, executable). Asserts `report-template.md` exists; YAML frontmatter contains `friction_blockers:`, `friction_warnings:`, `eligible_testers:`, `tester_attestations:`, `tested_branches:`, `report_date:`. Emits PASS/SUMMARY.

9. **Author `tools/verify/m033-p01-validate-report-sh-contract.sh`** (≥30 lines, executable). Asserts `validate-report.sh` exists, is executable, contains required tokens (`friction_blockers`, `eligible_testers`, `not_familiar_with_orchestrator`, `milestone close blocked`). Emits PASS/SUMMARY.

10. **Author `tools/verify/m033-p01-validate-report-fixtures-shape.sh`** (≥25 lines, executable). Asserts both fixture files exist; runs `validate-report.sh fixtures/report-pass.md` and asserts exit 0; runs `validate-report.sh fixtures/report-fail.md` and asserts exit non-zero AND stderr contains `friction_blockers=1`. Emits PASS/SUMMARY.

## Must-Haves

This task addresses these P01 phase truths:
- `tests/m033-acceptance/friendly-tester-pass/protocol.md` exists (FR-19).
- `tests/m033-acceptance/friendly-tester-pass/report-template.md` exists with required frontmatter.
- `validate-report.sh` exists, is executable, implements the SC-15 mechanical gate.
- `fixtures/report-pass.md` and `fixtures/report-fail.md` exist and exercise the validator branches.

This task creates these P01 phase artifacts:
- Protocol & template: `tests/m033-acceptance/friendly-tester-pass/protocol.md`, `tests/m033-acceptance/friendly-tester-pass/report-template.md`.
- Validator: `tests/m033-acceptance/friendly-tester-pass/validate-report.sh`.
- Fixtures: `tests/m033-acceptance/friendly-tester-pass/fixtures/report-pass.md`, `tests/m033-acceptance/friendly-tester-pass/fixtures/report-fail.md`.
- Shape verifiers: `tools/verify/m033-p01-friendly-tester-protocol-shape.sh`, `tools/verify/m033-p01-report-template-shape.sh`, `tools/verify/m033-p01-validate-report-sh-contract.sh`, `tools/verify/m033-p01-validate-report-fixtures-shape.sh`.

## Verification

```bash
bash tools/verify/m033-p01-friendly-tester-protocol-shape.sh
```

```bash
bash tools/verify/m033-p01-report-template-shape.sh
```

```bash
bash tools/verify/m033-p01-validate-report-sh-contract.sh
```

```bash
bash tools/verify/m033-p01-validate-report-fixtures-shape.sh
```

## Inputs

### From Previous Tasks

None — T04 has no upstream task dependencies.

### From Disk (Pre-existing)

- `tests/` directory — T04 creates `tests/m033-acceptance/friendly-tester-pass/` under it.
- `tools/verify/` — T04 creates four new verifier scripts under it.
- The M033 spec FR-19 / US-8 / SC-15 / SC-8 entries — restated inline in this task plan.
- [`.orchestrator/proposals/launch-sequencing-amendment-2026-05-03.md`](../../../../../proposals/launch-sequencing-amendment-2026-05-03.md) — informational context for the protocol's framing; no executable consumption.

## Constraints

- The validator MUST use only bash 3.2 + `awk` + `grep` + `sed` — no jq, no python (MEM001).
- The validator's stderr diagnostic on missing report file MUST contain the literal substring `friendly-tester pass not run — milestone close blocked` per US-8 AS-5.
- The validator MUST NOT enforce the `M033_SKIP_FRIENDLY_TESTER_PASS=1` escalation — that is `validate-milestone.sh`'s job, fired at milestone close.
- The protocol document is markdown documentation, not executable. It does not run any commands; it instructs a human to.
- The fixtures' frontmatter scalar values (`friction_blockers: 0` for pass, `friction_blockers: 1` for fail) are load-bearing — the validator's behavior pivots on these. The fixtures are NOT placeholders; they are the verifier inputs.
- This task creates no `commands/` files, no `scripts/lifecycle/` files, no `references/` files. Scope is acceptance-test artifacts only.
- Verifier scripts use single-script-file shape per AD-19.

## Expected Output

After T04 completes:
- `tests/m033-acceptance/friendly-tester-pass/{protocol,report-template,fixtures/report-pass,fixtures/report-fail}.md` exist.
- `tests/m033-acceptance/friendly-tester-pass/validate-report.sh` exists, is executable, and exits 0 against `fixtures/report-pass.md` and non-zero against `fixtures/report-fail.md`.
- All four T04 verifiers exist and exit 0.
- A summary file at [`.orchestrator/milestones/M033/phases/P01/tasks/T04-friendly-tester-pass-artifacts-SUMMARY.md`](../../../../../milestones/M033/phases/P01/tasks/T04-friendly-tester-pass-artifacts-SUMMARY.md) documents the deliverables and the SC-15 gate contract.

## Notes

Expected verifier output: each verifier emits PASS lines per assertion + a `SUMMARY: m033-p01-<name>.sh pass=N fail=0` line. The `validate-report-fixtures-shape.sh` verifier additionally captures stderr from the fail-case validator invocation and asserts the `friction_blockers=1` substring appears.
