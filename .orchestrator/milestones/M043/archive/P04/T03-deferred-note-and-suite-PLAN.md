---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M043"
name: "Signed deferred note + verifiers + phase-suite"
depends_on: [T01, T02]
---

## Prerequisites

This task consumes T01's protocol + T02's validator and fixtures. Confirm they
exist on disk before authoring (Plan-Time Discipline rule 1):

- `tests/m043-acceptance/live-deploy/protocol.md` (T01).
- `tests/m043-acceptance/live-deploy/validate-evidence.sh` (T02, executable).
- `tests/m043-acceptance/live-deploy/fixtures/evidence-pass.md` (T02).
- `tests/m043-acceptance/live-deploy/fixtures/evidence-deferred.md` (T02).

FAIL this task if any is missing — T03's verifiers grep T01's protocol and drive
T02's validator, so both must be present first.

## Description

Close P04 by (1) authoring the **signed deferred-validation evidence note** that
forward-points the live pass so M043 closes at shippable scope (the SC-9 "or"
closing artifact), and (2) authoring the four project-owned verifiers + the
phase-suite aggregator that make the phase mechanically verifiable.

The deferred note is a **Deferred-Validation Acknowledgment**, matching house
precedent (M032 SC-5, M036 P03 acknowledgment block). It does NOT claim the live
deploy passed — its triad fields stay `"no"` and `*_unconfirmed`; it records that
the live pass is forward-pointed and names the operator who authorized closing at
shippable scope. SC-9 explicitly permits this path.

## Steps

1. Create `tests/m043-acceptance/live-deploy/evidence/` if absent.

2. Author the signed deferred-validation note at
   `tests/m043-acceptance/live-deploy/evidence/2026-06-04-deferred-validation.md`.
   Copy the T02 `evidence-template.md` frontmatter shape and set:

   ```markdown
   ---
   schema_version: "1.0"
   type: live-deploy-evidence
   report_date: "2026-06-04"
   redirect_verified: "no"
   ci_green: "no"
   giscus_working: "no"
   edit_scope_grants_read: "unconfirmed"
   error_envelopes_match: "unconfirmed"
   deferred_validation: "yes"
   signed_by: "Brett Kellgren"
   ---
   ```

   Body: a `# M043 Live-Deploy Evidence — Deferred-Validation Acknowledgment`
   heading, then a `## Deferred-Validation Acknowledgment` section stating:
   - M043 closes at shippable scope (US-1..US-3): P01 (target switch + Cloudflare
     deploy workflow + FR-3a health check), P02 (idempotent provisioner), and
     P03 (footgun warning + docs + giscus byte-stability) are all verify-pass.
   - The US-4 live pass requires a real Cloudflare account with Zero Trust
     enabled and is therefore a human-recruitment task per spec FR-13 / SC-9.
   - The pass is forward-pointed to
     `tests/m043-acceptance/live-deploy/protocol.md`; when a Cloudflare-equipped
     tester runs it, the filled note replaces this one under `evidence/<DATE>.md`
     and `validate-evidence.sh` re-runs.
   - The two `[unconfirmed-P04]` API assumptions carried from P00 (#Q-5
     Edit-scope-grants-read, #Q-6 error-envelope discriminators) remain
     doc-derived until the live pass confirms or corrects them; both are inside
     AD-1's / FR-9's sanctioned fallback sets, so neither blocks shippable-scope
     closure.
   - This acknowledgment is signed by the operator who authorized closing at
     shippable scope (`signed_by` above).

   The note MUST contain the strings `deferred_validation` (in frontmatter) and
   `protocol.md` (the forward-pointer Key Link).

   Confirm it validates: `bash tests/m043-acceptance/live-deploy/validate-evidence.sh
   tests/m043-acceptance/live-deploy/evidence/2026-06-04-deferred-validation.md`
   exits 0 with `PASS: deferred-validation note signed_by=...`.

3. Write `tools/verify/m043-p04-protocol-anchors.sh` — grep-asserts every
   required anchor in `tests/m043-acceptance/live-deploy/protocol.md`. Shape
   (Bash 3.2, single-file, `set -e -u -o pipefail`): a `fail=0` counter, one
   `grep -q "<anchor>" "$PROTO" || { echo "MISSING: <anchor>"; fail=1; }` per
   anchor, then a final `pass=N fail=M` summary line and `exit $fail`. Required
   anchors (verbatim strings): `cloudflareaccess.com`, `302`,
   `cloudflare-access-setup.sh`, `wiki-init.sh`, `#Q-5`, `#Q-6`, `giscus`,
   `green CI`. The script MUST contain the literal `cloudflareaccess.com` (its
   own artifact `contains` check).

4. Write `tools/verify/m043-p04-evidence-gate.sh` — drives the T02 validator
   against all three branches and asserts the exit codes:
   - pass fixture → exit 0;
   - deferred fixture → exit 0;
   - a guaranteed-absent path (e.g. `/tmp/m043-p04-nonexistent-$$.md`, never
     created) → exit 1.
   Shape: run each under an `if`/`else` capturing `$?`; increment `fail` on any
   mismatch; print `pass=N fail=M`; `exit $fail`. The script MUST contain the
   literal `validate-evidence.sh`. Path discipline (Plan-Time Discipline rule 4):
   invoke the validator directly via `bash tests/m043-acceptance/live-deploy/validate-evidence.sh`,
   NOT through `run-probe.sh` (it is a repo-resident script, not a staged probe).

5. Write `tools/verify/m043-p04-deferred-note.sh` — asserts a signed
   deferred-validation note exists under
   `tests/m043-acceptance/live-deploy/evidence/` and validates as the SC-9
   deferred path. Shape: glob `evidence/*.md`; for each, if its frontmatter
   `deferred_validation` is `yes` AND `validate-evidence.sh <note>` exits 0,
   count it; require `count >= 1`. Print `pass=N fail=M`; `exit` non-zero if
   no qualifying note found. The script MUST contain the literal `deferred`.

6. Write `tools/verify/m043-p04-phase-suite.sh` — the aggregator, mirroring
   `tools/verify/m043-p03-phase-suite.sh` (read it for the exact `run_gate`
   idiom). It runs the three verifiers above (protocol-anchors, evidence-gate,
   deferred-note), tallies pass/fail, and prints a final
   `SUMMARY: ... pass=N fail=M` line. It MUST NOT invoke itself (no recursion).
   The script MUST contain the literal `pass=`.

## Must-Haves

- `tools/verify/m043-p04-protocol-anchors.sh` (min 20 lines, contains
  "cloudflareaccess.com")
- `tools/verify/m043-p04-evidence-gate.sh` (min 20 lines, contains
  "validate-evidence.sh")
- `tools/verify/m043-p04-deferred-note.sh` (min 15 lines, contains "deferred")
- `tools/verify/m043-p04-phase-suite.sh` (min 20 lines, contains "pass=")
- the signed deferred-validation note (Truth: deferred-note gate passes)
- Key Link: `evidence-gate.sh` → `validate-evidence.sh`

## Verification

```bash
bash tools/verify/m043-p04-protocol-anchors.sh
bash tools/verify/m043-p04-evidence-gate.sh
bash tools/verify/m043-p04-deferred-note.sh
bash tools/verify/m043-p04-phase-suite.sh
```

## Inputs

### From Previous Tasks

- `tests/m043-acceptance/live-deploy/protocol.md` (from T01)
  - Key content: contains anchors `cloudflareaccess.com`, `302`,
    `cloudflare-access-setup.sh`, `wiki-init.sh`, `#Q-5`, `#Q-6`, `giscus`,
    `green CI` — the protocol-anchors verifier greps each.
- `tests/m043-acceptance/live-deploy/validate-evidence.sh` (from T02)
  - Key API: `validate-evidence.sh <note.md>` — exit 0 iff (triad all `yes`) OR
    (`deferred_validation: yes` AND `signed_by` non-empty); exit 1 on a missing
    note (prints `live-deploy validation not run -- milestone close blocked`);
    exit 2 on no argument.
- `tests/m043-acceptance/live-deploy/fixtures/evidence-pass.md` +
  `evidence-deferred.md` (from T02)
  - Key content: pass fixture has the triad all `"yes"`; deferred fixture has
    `deferred_validation: "yes"` + `signed_by` set. The evidence-gate verifier
    drives the validator against both.

### From Disk (Pre-existing)

- `tools/verify/m043-p03-phase-suite.sh` — the `run_gate` aggregator idiom +
  `SUMMARY: ... pass=N fail=M` line shape to mirror.
- `tests/m043-acceptance/live-deploy/evidence-template.md` (T02) — the
  frontmatter shape to copy for the deferred note.

## Constraints

- **Bash 3.2 / POSIX-sh** (MEM001) in all four verifiers: no `declare -A`, no
  process substitution `<(...)`, no jq/python.
- **Path discipline**: all four verifiers are project-owned, milestone-prefixed
  (`m043-p04-*`) and live under `tools/verify/` (Plan-Time Discipline naming +
  M032 Finding A). The phase-suite must not recurse into itself.
- **Honest deferred note**: the note's triad fields stay `"no"` /
  `"unconfirmed"`; `deferred_validation: "yes"`. It documents the deferral — it
  does NOT claim the live deploy passed (Constitution Principle II; Post-
  Completion reporting discipline).
- **No live network calls**: every verifier runs offline against on-disk
  fixtures + the deferred note; none contacts Cloudflare.

## Expected Output

The signed deferred note on disk plus four executable verifiers under
`tools/verify/`. All four `## Verification` commands exit 0; the phase-suite
prints `... pass=3 fail=0`. With the deferred note validating, P04 is at closeable
scope and M043 can close at shippable scope under the signed deferred-validation
acknowledgment.

## Notes

Expected phase-suite output: a final line of the form
`SUMMARY: m043-p04 pass=3 fail=0` (three aggregated gates: protocol-anchors,
evidence-gate, deferred-note). Each individual verifier prints its own
`pass=N fail=M` tally and exits 0 on success. The deferred-note validator line
prints `PASS: deferred-validation note signed_by=Brett Kellgren (SC-9
forward-pointed)`.

The deferred note is authored as a milestone artifact under house deferred-
validation precedent (M032/M036). It records the operator's authorization to
close at shippable scope — not a claim that the live pass ran. When a
Cloudflare-equipped tester later completes the protocol, their filled note lands
beside this one under `evidence/<DATE>.md` and `validate-evidence.sh` confirms the
completed-pass path; the deferred note is retained as the historical close
rationale.
