---
schema_version: "1.0"
type: dispatch-role
role: research
---

# Dispatch Role -- Research (Tier A+ middle flow)

This template is consumed by the Tier A+ router (M031 P02 T04). It
declares the prescriptive output shape, the dispatch-payload requirements,
and the constraints that govern the research-role dispatch on a Tier A+
input. The router writes a per-task dispatch payload that injects this
template's body alongside the user's task description plus the
Quick-profile knowledge graph (P01 contract).

## Goal

Investigate the user request and produce a `research.md` documenting
findings, surface gaps, decisions to make, and a recommended approach.
Do NOT modify any source file.

## Output Shape

The research dispatch produces a single markdown file at
`.orchestrator/tier-a-plus/<task-slug>/research.md`. The file MUST
contain the following sections, in order:

- `## Findings` -- N bullet points, N >= 3. Each bullet documents a
  concrete observation grounded in the codebase (cite file paths or
  symbol names). The findings collectively explain the current state of
  the surface the user wants to modify.
- `## Open Questions` -- zero or more bullet points naming decisions
  the operator (or the downstream `plan` role) must answer before the
  build can ship. Each question is concrete and answerable.
- `## Recommended Approach` -- one paragraph stating the recommended
  approach. The body MUST be self-contained: an operator reading only
  this paragraph and the codebase MUST be able to decide whether to
  proceed to the `plan` role without re-reading any external file.

The research.md MUST NOT reference external markdown documents the
operator has to follow to understand the recommendation. Every cited
file path is a code path (script, template, JSONL, fixture), not a
prose document.

## Dispatch Payload Requirements

- The research dispatch is built via
  `bash scripts/dispatch/build-context.sh --profile=quick` (P01
  contract). The Quick-profile knowledge inject MUST fire on this
  dispatch -- the AD-14 single-window guarantee from M031 P01 means the
  payload includes the resolved knowledge entries plus the compression
  flags from the AD-11 sidecar.
- The dispatch invocation MUST include `--meta-out <path>` so the AD-11
  five-key sidecar (`mem_count`, `total_tokens`, `profile`,
  `compression_applied`, `snip_applied`) is captured alongside the
  payload. The router writes the sidecar under
  `.orchestrator/tier-a-plus/<task-slug>/research.meta.json`.

## Constraints

- **Read-only**: the research role MUST NOT edit any source file. No
  writes outside `.orchestrator/tier-a-plus/<task-slug>/research.md`
  (and its sibling sidecar). Source-file edits land in the build role.
- **Plain prose**: no scaffold-placeholder bracket-TODO byte pattern
  appears in the research.md body. The role template paraphrases or
  escapes the pattern when it must be discussed.
- **D020 token hygiene** (CON-7): comments and prose are sized to fit
  inside the operator-facing summary surface; the prompt summary
  truncates output at the configured `tier_a_plus_prompt_summary_lines`
  knob declared in `templates/orchestrator-config-default.yml`
  (default 8) per AD-20.
- **Length cap**: target output <= 200 lines. The Quick-profile knowledge
  inject + the cap let the downstream `plan` dispatch fit the research
  body in-payload without re-running build-context.sh against the
  research file.

## Inputs

The research dispatch payload includes:

- The user's original task description (the input that classified as
  `tier_a_plus` in `scripts/intake/shape-detect.sh`).
- The Quick-profile knowledge inject (resolved by build-context.sh).
- The fixture grounding at
  `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` (an
  architectural reference; the research role may cite its heuristic
  rationale).

## Notes

- The output filename `research.md` is fixed by the AD-10 path
  convention. Downstream `plan` and `build` dispatches read the file
  by literal name; do not rename or relocate it.
- The role template is consumed verbatim by the router; it is not
  rendered through a placeholder substitution layer. Any literal
  substring change is a normative change to the dispatch contract.
