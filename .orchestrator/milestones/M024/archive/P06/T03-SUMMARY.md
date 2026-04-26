---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P06"
milestone: "M024"
provides:
  - "scripts/intake/approval-gate.sh: --no-apply test-only flag + wired revise verb (calls scripts/intake/revise.sh, emits revised_to=<path>); scripts/verify/m024-p06-version-suffix.sh; scripts/verify/m024-p06-rederive-rationale.sh; scripts/verify/m024-p06-approval-gate-revise-wired.sh"
requires:
  - "T01 (scripts/intake/axis-rederive.sh); T02 (scripts/intake/revise.sh + proposal-emit.sh --axes-from + REVISE_AXES_DONE branch); P03 (scripts/intake/approval-gate.sh base + closed-enum axis validator)"
affects:
  - "scripts/verify/m024-p03-approval-gate-verbs.sh (one-line --no-apply delta to keep P03 surface assertion green); tests/test-approval-gate.sh (one-line --no-apply delta on the revise pass-through assertion); scripts/intake/proposal-emit.sh (paragraph branch + per-axis loop now respect REVISE_AXES_DONE so revised axes carry the placeholder for revise.sh post-process — see Concerns)"
key_files:
  - "scripts/intake/approval-gate.sh, scripts/intake/proposal-emit.sh, scripts/verify/m024-p06-version-suffix.sh, scripts/verify/m024-p06-rederive-rationale.sh, scripts/verify/m024-p06-approval-gate-revise-wired.sh, scripts/verify/m024-p03-approval-gate-verbs.sh, tests/test-approval-gate.sh"
key_decisions:
  - "REVISE_AXES_DONE precedence raised above PARA/SPEC/QA in proposal-emit's per-axis loop AND inside the paragraph branch (T02 had emitted the placeholder only inside the for-loop, but the paragraph branch unconditionally swapped scope_tier/decomposition rationales BEFORE the loop ran, masking the placeholder and making revise.sh's post-process sed find nothing on paragraph re-emits — flagged as Concern, fix scoped to P06 named write-set per task plan Files To Touch)"
patterns_established:
  - "Test-only --no-apply backcompat shim — when wiring a previously-stubbed verb to its real implementation, add a hidden flag (deliberately NOT documented in commands/*.md per T03 constraints) that preserves the prior stdout shape so prior-phase verifies pass with a one-line delta rather than a behavioral fork. Ergonomic alternative to versioning the script."
drill_down_paths:
  - ".orchestrator/milestones/M024/phases/P06/tasks/T03-PAYLOAD.md, .orchestrator/milestones/M024/phases/P06/tasks/T03-PLAN.md"
duration: "12m"
verification_result: "pass-with-concerns"
completed_at: "2026-04-26T04:26:20Z"
---

## Summary

T03 wires the `revise` verb in `scripts/intake/approval-gate.sh` to call T02's `scripts/intake/revise.sh`, replacing the P03 surface-only `revision_pending=true axis=<a> value=<v>` line with `revised_to=<new-proposal-path>`. The legacy P03 stdout shape is preserved verbatim under a test-only `--no-apply` flag; one-line deltas land in `scripts/verify/m024-p03-approval-gate-verbs.sh` and `tests/test-approval-gate.sh` to add `--no-apply` to their revise assertions.

Three new verifies ship: `m024-p06-version-suffix.sh` (v1 + v2 archived, v1 byte-stable across consecutive revises), `m024-p06-rederive-rationale.sh` (touched-axis body Rationale slots cite the version-pointer, untouched axes preserved verbatim), and `m024-p06-approval-gate-revise-wired.sh` (wired path emits `revised_to=`, `--no-apply` preserves P03 surface).

## What was built

- **`scripts/intake/approval-gate.sh`** — added `NO_APPLY` parser; updated `usage` text to describe wired behavior and the `--no-apply` test-only flag; replaced `revise)` case body with the wired path. Closed-enum axis validation runs BEFORE the `--no-apply` check so unsupported axes still exit 2 in either mode.
- **`scripts/verify/m024-p06-version-suffix.sh`** — emits a paragraph proposal, revises twice with different `scope_tier` values, asserts `proposal-v1.md` is byte-stable across the second revise and `proposal-v2.md` captures the intermediate state.
- **`scripts/verify/m024-p06-rederive-rationale.sh`** — emits + revises a proposal, extracts body Rationale slots via `awk`-driven section walker (proposal stores rationale as `**Rationale**: <text>` body lines, NOT YAML frontmatter `rationale_<axis>:` keys — the payload's regex template was based on a different template structure; corrected here to match the actual template at `templates/intake-proposal.md`).
- **`scripts/verify/m024-p06-approval-gate-revise-wired.sh`** — exercises both the wired path (asserts `revised_to=<path>`, asserts archive at `proposal-v1.md`) and the `--no-apply` path (asserts legacy stdout shape, asserts no archive created).
- **One-line deltas** — `scripts/verify/m024-p03-approval-gate-verbs.sh` line 31 and `tests/test-approval-gate.sh` line 55: appended `--no-apply` to the revise invocation so the P03 stdout assertion still matches.

## Concerns (DONE_WITH_CONCERNS)

**Scope-widening edit to `scripts/intake/proposal-emit.sh`** beyond the task plan's literal Steps section. The payload's Steps only directed me to edit `approval-gate.sh` and the P03 verify file. However, on running the new `m024-p06-rederive-rationale.sh` verify, I observed that revising `scope_tier` on a paragraph proposal left the body Rationale slot stuck at the deep-classifier text (`paragraph 30 words, 0 FR-bullets, 0 milestone-markers — Tier A single-task`), not the placeholder `Operator revision via revise.sh — see prior version for original rationale.` that revise.sh post-processes into a version-pointer.

Root cause: T02's REVISE_AXES_DONE branch in `proposal-emit.sh`'s per-axis loop was correctly placed, but the paragraph branch (lines 364–371 originally) unconditionally swapped `rationale_scope_tier` and `rationale_decomposition` BEFORE the loop ran, so the for-loop's `continue` for paragraph-axes-done meant the REVISE branch was never reached for those two axes. The placeholder was never inserted, so revise.sh's post-process sed had nothing to substitute.

Fix applied (named in the payload's "Files To Touch" list, line 1492 — proposal-emit.sh "modify"):
1. Wrapped the paragraph branch's two scope_tier/decomposition swaps in guards that skip when REVISE_AXES_DONE=1 AND the axis is in REVISE_AXES_KEYS.
2. Hoisted the REVISE_AXES_DONE branch in the per-axis loop ABOVE the PARA/SPEC/QA gates so revised axes always reach the placeholder path regardless of which input branch ran.

Net behavioral change: revising a previously-paragraph-classified scope_tier or decomposition now yields the `operator revision (revise.sh) — see proposal-v<N>.md` rationale per FR-13, instead of stale deep-classifier text. The scope-widening flag is raised because this is strictly a T02 contract repair; T03 only surfaces it via the new verify.

This mirrors P05/T04's pattern of flagging scope-widening as a Concern when a downstream verify exposes an upstream gap. No prior-phase test regressed (P01/P02/P03/P04/P05 suites all green after the change).

## Verification

```
bash scripts/verify/m024-p06-version-suffix.sh
bash scripts/verify/m024-p06-rederive-rationale.sh
bash scripts/verify/m024-p06-approval-gate-revise-wired.sh
bash scripts/verify/m024-p06-axis-rederive.sh
bash scripts/verify/m024-p06-revise-script.sh
bash scripts/verify/m024-p06-axes-from-flag.sh
bash scripts/verify/m024-p01-suite.sh
bash scripts/verify/m024-p02-suite.sh
bash scripts/verify/m024-p03-suite.sh
bash scripts/verify/m024-p04-suite.sh
bash scripts/verify/m024-p05-suite.sh
```

All PASS. Notable lines:
- `PASS: version-suffix — v1 + v2 archived; v1 byte-stable across consecutive revises; proposal.md is latest`
- `PASS: rederive-rationale — touched axes pointer-rationale; untouched axes preserved; placeholder substituted`
- `PASS: approval-gate revise verb — wired to revise.sh by default; --no-apply preserves P03 surface`
- `PASS: M024/P03 suite — paragraph + approval-gate + route + evaluate-md` (after the one-line `--no-apply` deltas)

## Downstream notes

- **T04 (commands/evaluate.md doc update)** must NOT mention `--no-apply` per T03 constraints — it is a test-only backcompat shim. Reference only the wired full-re-emit behavior and `scripts/intake/revise.sh`.
- The proposal-emit precedence reordering means any future input branch (P07 design-gate, etc.) that wants its rationale slot honored on a fresh emit must NOT set its `<branch>_AXES_DONE=1` flag for axes the operator has explicitly revised. Pattern: REVISE wins highest precedence in the per-axis rationale loop.
- The rederive-rationale verify uses an `awk`-driven body-section walker rather than line-anchored grep because rationales live in body text under `### Axis N — <Name>` headers, not in YAML frontmatter. Future verifies inspecting per-axis rationale text should reuse this `rationale_for "<Axis Name>"` helper shape.
