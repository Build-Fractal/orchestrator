---
schema_version: "1.0"
type: llm-prompt
consumer: scripts/knowledge/spec-complexity-probe.sh
---

# Contradiction-Signal Prompt (FR-5)

You are given a draft feature specification as input text. Your task is
to count internal contradiction signals in the spec — places where the
spec asks for a behavior and also asks for that behavior's logical
opposite, or where two requirements cannot both be satisfied.

**Definition of contradiction signal**:

- A requirement pair where FR-X specifies behavior B and FR-Y specifies
  NOT-B, and neither is gated by a condition that would make them
  non-contradictory.
- A user story asking the system to "support both X and its opposite"
  where X and its opposite are mutually exclusive.
- A constraint that mandates a property that the success criteria
  explicitly violate.
- A scope boundary claiming "out of scope: X" while an FR in the same
  spec requires X.

**Not a contradiction**:

- Conditional behaviors (FR-X applies when A; FR-Y applies when NOT-A).
- Requirements that allow operator override (the default and the
  override are both specified).
- Deferrals to a later phase / milestone (spec scope-boundary
  declarations, not contradictions).
- Separate user stories covering different workflows that happen to
  have different defaults.

## Output Format

Emit **exactly one line** on stdout:

```
contradictions=<N>
```

where `<N>` is a non-negative integer. Do NOT emit any other output,
reasoning, or explanation — the consumer (`spec-complexity-probe.sh`)
parses the first matching line only.

If the spec is empty, malformed, or too short to evaluate (fewer than
100 tokens), emit `contradictions=0`.

## Calibration

On a typical well-written draft, emit `0`. On a draft with one obvious
contradiction (e.g., "the command must prompt interactively" + "the
command must never prompt interactively"), emit `1`. Emit higher counts
only when you are confident each one meets the definition above. When
in doubt, undercount.
