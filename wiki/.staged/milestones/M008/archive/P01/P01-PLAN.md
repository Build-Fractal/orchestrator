---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M008"
goal: "Build the adaptive intensity engine that analyzes task descriptions and recommends Quick, Standard, or Full intensity"
demo_sentence: "A developer describes a task and the orchestrator recommends Quick, Standard, or Full intensity with reasoning, factoring in scope, risk signals, and detected environment capabilities."
risk: "high"
depends_on: []
---

<!--
  P01 -- Adaptive Intensity Engine
  =================================

  Context: the orchestrator currently applies the same heavyweight process to
  every task regardless of size. A typo fix gets the same ceremony as a platform
  build. The adaptive intensity engine evaluates task scope, risk, and complexity
  from a natural-language description and recommends an appropriate process
  intensity level (Quick, Standard, or Full).

  Architectural decisions:
    AD-03  Intensity engine runs as a dedicated evaluation step early in the
           pipeline, before any orchestration begins.
    AD-03  Intensity is not a mode switch -- each stage interprets intensity
           independently via metadata.
    OQ-01  Scope-dominant weighting with risk as an escalation signal.
    OQ-03  Context pressure thresholds: warn at 60%, decompose at 75%,
           refuse at 85%. Configurable and intensity-aware.

  Key design choices:
    - Pattern matching on natural-language descriptions for scope/risk signals
    - Parallel indexed arrays (Bash 3.2 safe -- no associative arrays)
    - Key=value structured output from all scripts
    - detect-capabilities.sh refactored with backward compatibility
    - Decision matrix: scope x risk x capabilities -> intensity level

  Cross-phase dependencies:
    - P03 consumes intensity metadata schema (templates/intensity-metadata.md)
    - P03 consumes intensity-recommend.sh for initial recommendation
    - P07 consumes detect-capabilities.sh for init-time probing
    - All downstream phases read intensity metadata as YAML frontmatter
-->

## Must-Haves

### Truths

- detect-capabilities.sh adds graph_db, mcp_servers, and ci_pipeline detection while preserving all existing output fields.
  - Check: `bash scripts/verify/m008-p01-capabilities-backward-compat.sh`
- detect-capabilities.sh supports a --profile flag that outputs a capability summary suitable for intensity recommendation.
  - Check: `bash scripts/verify/m008-p01-capabilities-profile.sh`
- intensity-analyze.sh accepts a task description and outputs scope, risk_level, complexity, risk_signals, and recommended_intensity as key=value pairs.
  - Check: `bash scripts/verify/m008-p01-analyze-output-format.sh`
- intensity-analyze.sh classifies a trivial single-file fix as scope=trivial with recommended_intensity=Quick.
  - Check: `bash scripts/verify/m008-p01-analyze-trivial.sh`
- intensity-analyze.sh classifies a multi-component feature as scope=moderate with recommended_intensity=Standard.
  - Check: `bash scripts/verify/m008-p01-analyze-moderate.sh`
- intensity-analyze.sh detects risk signals (auth, security, migration keywords) and escalates intensity.
  - Check: `bash scripts/verify/m008-p01-analyze-risk-escalation.sh`
- intensity-recommend.sh combines analyze output + capability profile and produces intensity, confidence, and reasoning as key=value pairs.
  - Check: `bash scripts/verify/m008-p01-recommend-output-format.sh`
- intensity-recommend.sh factors detected capabilities into its recommendation (richer environment -> higher confidence).
  - Check: `bash scripts/verify/m008-p01-recommend-capabilities.sh`
- templates/intensity-metadata.md exists with YAML frontmatter schema containing intensity, scope, risk_level, complexity, confidence, reasoning, overridden_by, original_intensity, and capabilities_used fields.
  - Check: `bash scripts/verify/m008-p01-metadata-template.sh`
- context-pressure.sh evaluates token estimates against configurable thresholds and outputs pressure level and recommended action.
  - Check: `bash scripts/verify/m008-p01-context-pressure.sh`
- All scripts are Bash 3.2 compatible (no associative arrays, no readarray, no |&).
  - Check: `bash scripts/verify/m008-p01-bash32-compat.sh`

### Artifacts

- scripts/dispatch/detect-capabilities.sh (min 140 lines, contains "graph_db" and "mcp_servers" and "ci_pipeline" and "--profile")
- scripts/engine/intensity-analyze.sh (min 120 lines, contains "scope=" and "risk_level=" and "recommended_intensity=")
- scripts/engine/intensity-recommend.sh (min 100 lines, contains "intensity=" and "confidence=" and "reasoning=")
- templates/intensity-metadata.md (min 20 lines, contains "schema_version" and "intensity" and "overridden_by")
- scripts/engine/context-pressure.sh (min 80 lines, contains "pressure=" and "action=")
- scripts/verify/m008-p01-capabilities-backward-compat.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p01-capabilities-profile.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p01-analyze-output-format.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p01-analyze-trivial.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p01-analyze-moderate.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p01-analyze-risk-escalation.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p01-recommend-output-format.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p01-recommend-capabilities.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p01-metadata-template.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p01-context-pressure.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p01-bash32-compat.sh (min 10 lines, contains "PASS")

### Key Links

- scripts/engine/intensity-analyze.sh -> scripts/engine/intensity-recommend.sh (analyze output consumed by recommender)
- scripts/dispatch/detect-capabilities.sh -> scripts/engine/intensity-recommend.sh (capability profile consumed by recommender)
- templates/intensity-metadata.md -> scripts/engine/intensity-recommend.sh (recommender populates the metadata schema)
- scripts/engine/context-pressure.sh -> scripts/engine/intensity-recommend.sh (pressure informs recommendation confidence)

## Tasks

### T01: Refactor detect-capabilities.sh -- add graph DB, MCP, CI detection + --profile flag

Extends `scripts/dispatch/detect-capabilities.sh` to detect three new
capabilities (graph_db, mcp_servers, ci_pipeline) and adds a `--profile` flag
that outputs a summary capability profile as key=value pairs. Preserves all
existing output fields and backward compatibility for both text and JSON
formats. Creates two verification scripts.

Full plan: `tasks/T01-PLAN.md`

### T02: Create intensity-analyze.sh -- scope/risk/complexity analyzer

Creates `scripts/engine/intensity-analyze.sh` that accepts a natural-language
task description via `--description` flag or stdin, analyzes it for scope
markers, risk signals, and complexity indicators using pattern matching, and
outputs structured key=value pairs: scope, risk_level, complexity, risk_signals,
recommended_intensity. Creates three verification scripts.

Full plan: `tasks/T02-PLAN.md`

### T03: Create intensity-recommend.sh -- recommendation engine

Creates `scripts/engine/intensity-recommend.sh` that combines the output from
`intensity-analyze.sh` and `detect-capabilities.sh --profile` to produce a
final intensity recommendation with confidence and reasoning. Implements the
decision matrix: scope x risk x capabilities -> intensity level. Creates two
verification scripts.

Full plan: `tasks/T03-PLAN.md`

### T04: Create intensity-metadata.md template + context-pressure.sh

Creates `templates/intensity-metadata.md` with the YAML frontmatter schema
that flows through all pipeline stages. Creates `scripts/engine/context-pressure.sh`
that evaluates estimated token counts against configurable thresholds and
outputs pressure level and recommended action. Creates two verification
scripts.

Full plan: `tasks/T04-PLAN.md`

### T05: Create Bash 3.2 compatibility check + integration smoke test

Creates the Bash 3.2 compatibility verification script that checks all new
scripts for prohibited constructs. Runs a full end-to-end integration test:
capability detection -> analysis -> recommendation -> metadata output. Verifies
all scripts work together as a pipeline.

Full plan: `tasks/T05-PLAN.md`

## Task Dependencies

```
T01 (detect-capabilities.sh refactor)
  |
  +---> T03 (intensity-recommend.sh -- needs capability profile)
  |       ^
  |       |
T02 (intensity-analyze.sh)
  |
  +---> T03

T04 (metadata template + context-pressure.sh) -- independent

T01 + T02 + T03 + T04
  |
  +---> T05 (integration test + bash32 compat)
```

T01 and T02 are independent and can execute concurrently.
T03 depends on both T01 and T02 (consumes their outputs).
T04 is fully independent of T01-T03.
T05 depends on all prior tasks completing.

## Files Likely Touched

- scripts/dispatch/detect-capabilities.sh (modify)
- scripts/engine/intensity-analyze.sh (create)
- scripts/engine/intensity-recommend.sh (create)
- templates/intensity-metadata.md (create)
- scripts/engine/context-pressure.sh (create)
- scripts/verify/m008-p01-capabilities-backward-compat.sh (create)
- scripts/verify/m008-p01-capabilities-profile.sh (create)
- scripts/verify/m008-p01-analyze-output-format.sh (create)
- scripts/verify/m008-p01-analyze-trivial.sh (create)
- scripts/verify/m008-p01-analyze-moderate.sh (create)
- scripts/verify/m008-p01-analyze-risk-escalation.sh (create)
- scripts/verify/m008-p01-recommend-output-format.sh (create)
- scripts/verify/m008-p01-recommend-capabilities.sh (create)
- scripts/verify/m008-p01-metadata-template.sh (create)
- scripts/verify/m008-p01-context-pressure.sh (create)
- scripts/verify/m008-p01-bash32-compat.sh (create)
