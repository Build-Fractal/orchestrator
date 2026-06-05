---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M043"
goal: "Ship the live / friendly-tester validation infrastructure for US-4 and forward-point the live pass under a signed deferred-validation note."
demo_sentence: "A documented live-deploy protocol exists for a recruited tester, a mechanical gate accepts either a completed live pass or a signed deferred note, and M043 closes at shippable scope under a signed deferred-validation acknowledgment."
risk: "low"
depends_on: [P01, P02, P03]
---

## Must-Haves

### Truths

- The live-deploy protocol exists and names the SC-9 triad (302→cloudflareaccess.com redirect, green CI run, working giscus comment) plus the two P00-forward-pointed live confirmations (#Q-5 Edit-scope-grants-read, #Q-6 error-envelope distinguishability).
  - Check: `bash tools/verify/m043-p04-protocol-anchors.sh`
- The `validate-evidence.sh` gate accepts both SC-9 paths and fails closed on a missing note: a completed-pass fixture exits 0, a signed-deferred fixture exits 0, and a non-existent note exits 1.
  - Check: `bash tools/verify/m043-p04-evidence-gate.sh`
- A signed deferred-validation evidence note exists and validates through the gate as the SC-9 deferred path (forward-points the live pass so M043 closes at shippable scope).
  - Check: `bash tools/verify/m043-p04-deferred-note.sh`
- The P04 phase-suite aggregates every P04 gate and reports zero failures.
  - Check: `bash tools/verify/m043-p04-phase-suite.sh`

### Artifacts

- tests/m043-acceptance/live-deploy/protocol.md (min 90 lines, contains "cloudflareaccess.com")
- tests/m043-acceptance/live-deploy/RECRUITMENT-KIT.md (min 40 lines, contains "Cloudflare")
- tests/m043-acceptance/live-deploy/evidence-template.md (min 30 lines, contains "deferred_validation")
- tests/m043-acceptance/live-deploy/validate-evidence.sh (min 40 lines, contains "milestone close blocked")
- tests/m043-acceptance/live-deploy/fixtures/evidence-pass.md (min 15 lines, contains "redirect_verified")
- tests/m043-acceptance/live-deploy/fixtures/evidence-deferred.md (min 15 lines, contains "deferred_validation")
- tools/verify/m043-p04-protocol-anchors.sh (min 20 lines, contains "cloudflareaccess.com")
- tools/verify/m043-p04-evidence-gate.sh (min 20 lines, contains "validate-evidence.sh")
- tools/verify/m043-p04-deferred-note.sh (min 15 lines, contains "deferred")
- tools/verify/m043-p04-phase-suite.sh (min 20 lines, contains "pass=")

### Key Links

- tests/m043-acceptance/live-deploy/protocol.md → scripts/wiki/cloudflare-access-setup.sh (the protocol drives the P02 provisioner)
- tests/m043-acceptance/live-deploy/protocol.md → scripts/lifecycle/wiki-init.sh (the protocol drives the P01 `--deploy cloudflare-access` path)
- tests/m043-acceptance/live-deploy/evidence-template.md → tests/m043-acceptance/live-deploy/protocol.md (the template captures the protocol's results)
- tools/verify/m043-p04-evidence-gate.sh → tests/m043-acceptance/live-deploy/validate-evidence.sh (the gate verifier drives the validator)

## Tasks

### T01: Live-deploy protocol + recruitment kit

See `tasks/T01-protocol-and-kit-PLAN.md`.

### T02: Evidence template + mechanical gate + fixtures

See `tasks/T02-evidence-gate-PLAN.md`.

### T03: Signed deferred note + verifiers + phase-suite

See `tasks/T03-deferred-note-and-suite-PLAN.md`.

## Task Dependencies

```
T01 ──┐
      ├──→ T03
T02 ──┘
```

T01 (protocol + kit) and T02 (evidence template + validator + fixtures) are
mutually independent — T01 owns the human-facing walkthrough docs, T02 owns the
machine-checkable capture form + gate. T03 consumes both: its verifiers grep the
T01 protocol anchors and drive the T02 validator against the T02 fixtures, and it
authors the signed deferred note that the T02 validator accepts. Execute T01 and
T02 in either order (or concurrently); T03 last.

## Files Likely Touched

- tests/m043-acceptance/live-deploy/protocol.md (create)
- tests/m043-acceptance/live-deploy/RECRUITMENT-KIT.md (create)
- tests/m043-acceptance/live-deploy/evidence-template.md (create)
- tests/m043-acceptance/live-deploy/validate-evidence.sh (create)
- tests/m043-acceptance/live-deploy/fixtures/evidence-pass.md (create)
- tests/m043-acceptance/live-deploy/fixtures/evidence-deferred.md (create)
- tests/m043-acceptance/live-deploy/evidence/2026-06-04-deferred-validation.md (create)
- tools/verify/m043-p04-protocol-anchors.sh (create)
- tools/verify/m043-p04-evidence-gate.sh (create)
- tools/verify/m043-p04-deferred-note.sh (create)
- tools/verify/m043-p04-phase-suite.sh (create)
