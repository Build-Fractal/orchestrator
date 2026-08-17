---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P03"
milestone: "M046"
provides:
  - "commands/auto.md Unified Tier-Sized Entry section documenting classify-first routing (AUTO:ROUTE/AUTO:BLOCK_AMBIGUITY), routing table, auto-entry.sh driver reference, and the --yes/--unattended D020 boundary"
requires:
  - "scripts/intake/auto-entry.sh (T01) AUTO:ROUTE/AUTO:BLOCK_AMBIGUITY stdout contract"
affects:
  - "P03 close (unified entry documented)"
key_files:
  - "commands/auto.md"
key_decisions:
  - "D020 --yes narrow-skip-confirm vs --unattended destructive-approval kept as separate authorities in the doc; FR-1 authoring placed additively above Preflight Summary leaving all loop/self-continue/P04 sections byte-intact"
patterns_established:
  - "MEM012 command-file structure preserved; additive-at-top documentation authoring (frontmatter description update + single new leading section) with zero edits to downstream sections"
drill_down_paths:
  - ".orchestrator/milestones/M046/phases/P03/"
duration: "300s"
verification_result: "pass"
completed_at: "2026-07-14T00:26:10Z"
---

Authored the FR-1 unified classify-first entry into commands/auto.md: updated the frontmatter description to reflect orchestrator:auto as the single tier-sizing door, and inserted a new '## Unified Tier-Sized Entry (M046 / FR-1)' section immediately after the title paragraph and before the existing Preflight Summary. The section documents that orchestrator:auto <arg> classifies via the M024 classifier (shape-detect.sh) through the driver scripts/intake/auto-entry.sh and routes: Tier A/A+/B description -> one-shot dispatch (former do behavior, reusing route-to-dispatch.sh + build-context.sh byte-unchanged per FR-2/CON-2); empty/existing milestone dir -> the Tier-C loop (M045 legacy parity FR-17); below the confidence floor -> AUTO:BLOCK_AMBIGUITY (deliberate exit-0 stop). Includes the routing table, a single-script invocation example, an --ambiguity-mode note, an orchestrator:do deprecation-shim pointer, and a '### --yes vs --unattended (FR-5 / D020)' subsection stating --yes only skips the single attended confirm (narrow, non-broadening) while --unattended is the sole destructive-approval authority with FR-13 fail-closed caps. Documentation-only: no runtime scripts touched. Diff is 66 insertions / 1 deletion (description-line replacement); all pre-existing sections (Preflight Summary, Intensity, Prerequisites, loop, Self-Continue, P04 Unattended envelope, Completion, etc.) verified byte-intact. All six task-plan verification greps exit 0.
