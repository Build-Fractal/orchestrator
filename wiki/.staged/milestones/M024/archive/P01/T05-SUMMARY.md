---
schema_version: "1.0"
type: task-summary
id: T05
parent: M024/P01
task: T05
phase: P01
milestone: M024
outcome: success
verification_result: pass
---

# T05 — Phase tests + manifest superset (with T01/T04 loop-back)

## Files Created (Half A)

- `tests/fixtures/m014-interim-manifest-keys.txt` — 6-key [M014](../../../../milestones/M014/index.md) interim manifest fixture (`schema_version`, `type`, `feature_slug`, `created_at`, `status`, `milestone`).
- `tests/test-intake-proposal-shape.sh` — SC-7 frontmatter + axis-headings completeness test, three cases (paragraph, idea, spec-path). Executable.
- `tests/test-intake-manifest-superset.sh` — SC-8 / FR-15 / DC-5 strict-superset test against the M014 fixture. Executable.
- `scripts/verify/m024-p01-suite.sh` — runs both phase-level tests as a single gate.

## Files Modified for Loop-Back (Half B)

These three files belong to T01/T04 and were edited per Step 7 of the payload to honor the strict-superset commitment:

- `templates/intake-proposal.md` (T01 deliverable) — added three keys to the frontmatter:
  - `feature_slug: "{{feature_slug}}"` (after `type:`)
  - `milestone: "{{milestone}}"` (after `intake_id:`)
  - `status: "{{status}}"` (after `milestone:`) — the third addition was required because the M014 fixture pins `status` and the strict-superset assertion would otherwise fail. Adding `status` to the proposal preserved the strict-superset commitment per FR-15 and avoided weakening DC-5.
- `scripts/intake/proposal-emit.sh` (T04 deliverable) — added computation + substitution for all three new keys:
  - `feature_slug`: when `--spec-path` was supplied, `basename "$(dirname "$SPEC_PATH")"`; otherwise the intake-id slug with the `<NNN>-` counter prefix stripped.
  - `milestone`: parsed from `.orchestrator/milestone-summary.md` if present (matches both `^**Active milestone**:` and `^**Out-of-band active milestone**:` shapes); otherwise emits `null`. (For the current repo, the active marker is `Out-of-band active milestone` so [`M026`](../../../../milestones/M026/index.md) is emitted.)
  - `status`: pinned to `"pending"` at emit time.
- `scripts/verify/m024-p01-template-frontmatter.sh` (T01 deliverable) — `REQUIRED_KEYS` extended to include `feature_slug`, `milestone`, and `status`.

## Deviations From Verbatim Payload

Two small fixes were necessary for the suite to actually pass; both preserve the payload's intent:

1. The verbatim heading-pretty regex (`sed 's/_/ /; s/_/ — /'`) only replaces the first two underscores in `Axis_1_Input_Shape`, leaving `Axis 1 — Input_Shape` (broken). Replaced with `sed -E 's/^Axis_([0-9]+)_(.*)$/Axis \1 — \2/' | tr '_' ' '` which produces the correct `Axis 1 — Input Shape` heading the proposal template emits.
2. The fixture lists `status` as an M014 key, but the payload's loop-back instructions only enumerated `feature_slug` and `milestone`. Added `status` to the proposal, the emitter, and the T01 verify script so the fixture-driven strict-superset test passes without weakening the assertion.

## Verification Results

```
$ bash scripts/verify/m024-p01-template-frontmatter.sh
PASS: templates/intake-proposal.md frontmatter + axis sections complete

$ bash scripts/verify/m024-p01-proposal-emit.sh
PASS: proposal-emit.sh — frontmatter + six axis sections + no unsubstituted placeholders

$ bash scripts/verify/m024-p01-suite.sh
PASS: test-intake-proposal-shape.sh — paragraph, idea, spec-path (3 cases)
PASS: test-intake-manifest-superset.sh — proposal contains all 6 M014 manifest keys + 20 M024-specific keys
PASS: M024/P01 suite — proposal-shape + manifest-superset
```

All gate checks green. T01 and T04 verify scripts continue to pass after the loop-back edits.
