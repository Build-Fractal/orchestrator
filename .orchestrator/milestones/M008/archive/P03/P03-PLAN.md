---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M008"
goal: "Make every pipeline stage read intensity metadata and scale its depth and breadth to match, and let a developer override intensity mid-workflow without restarting"
demo_sentence: "A developer kicks off a task at Quick intensity, watches discussion/research/verification all skip to the minimum, runs intensity-override.sh to Full mid-workflow, and observes the remaining stages expand to full planning + four-tier verification — all while completed stage outputs remain untouched."
risk: "high"
depends_on: ["P01", "P02"]
---

<!--
  P03 -- Intensity-Aware Pipeline Scaling
  =======================================

  Context: P01 delivered the recommendation engine (intensity-analyze.sh,
  intensity-recommend.sh) plus the intensity-metadata.md schema. P02
  delivered the uniform dispatch interface that already accepts
  --intensity-metadata as a first-class argument. What's missing is the
  connective tissue: nothing in the pipeline actually reads the
  intensity metadata and scales behavior. P03 closes that gap.

  Architectural decisions:

  (1) Centralized matrix, distributed enforcement. The stage x intensity
      substep matrix lives in ONE script (intensity-gate.sh). Commands
      call that script and act on its output. This avoids the bug class
      where the matrix in one command doc drifts from the matrix in
      another. A single grep in intensity-gate.sh reveals the whole
      policy.

  (2) Gate output is key=value, matching the P01/P02 convention
      (MEM014 "Scripts -> Commands"). Two lines:
        execute_substeps=<csv>
        skip_substeps=<csv>
      Commands parse those and branch. No fancy JSON, no heredoc
      protocols. Bash 3.2 safe.

  (3) Override is additive, never destructive (FR-004). The override
      script rewrites only the intensity-metadata.md frontmatter —
      `intensity:`, `original_intensity:`, `overridden_by:`. It does NOT
      touch phase summaries, task plans, verification reports, or any
      output that represents completed work. The rule is: completed
      stages stay completed; only stages that have not yet run see the
      new intensity.

  (4) Intensity-aware knowledge is a thin wrapper, not a rewrite. At
      Quick it runs only write-summary.sh. At Standard it runs
      write-summary.sh + append-decision.sh. At Full it runs the full
      chain ending in rebuild-index.sh / graph update. This preserves
      the M007 knowledge pipeline untouched; intensity-knowledge.sh is
      the pipeline gate.

  (5) Minimal refactor of command docs (MEM012 structure). Each
      refactored command gets ONE new section: "Intensity Behavior".
      It lists the substeps per level and notes "call
      scripts/engine/intensity-gate.sh --stage <name> at entry; honor
      execute_substeps/skip_substeps output." We do NOT rewrite the
      workflow; we attach the awareness layer.

  Cross-phase dependencies:
  - Consumes P01 (templates/intensity-metadata.md schema,
    scripts/engine/intensity-recommend.sh) and P02
    (scripts/dispatch/dispatch-interface.sh already carries
    --intensity-metadata through to backends).
  - Produces hooks that P04 (State & Namespace Independence) must
    respect: the metadata file lives at a well-known path under the
    orchestrator state directory, and the override script must resolve
    it via that convention.
  - P05 (Runtime adapters) inherits this interface unchanged — every
    runtime invokes the same intensity-gate.sh / intensity-override.sh.

  The hardcoded matrix, exactly as documented in the payload:

     Stage      | Quick              | Standard                | Full
     ---------- | ------------------ | ----------------------- | ---------------------------
     discuss    | skip               | optional                | required
     research   | skip               | on-demand               | pre-planning
     plan-phase | single task        | 2-4 tasks, basic        | full decomposition, full map
     dispatch   | sequential         | standard payload        | full context + knowledge
     verify     | Tier 1 only        | Tier 1+2                | all 4 tiers
     knowledge  | summaries only     | summaries + decisions   | full pipeline
     auto       | no pause gates     | standard pause gates    | strict + human review

  Risk: HIGH. This phase refactors load-bearing command docs. A bug in
  the gate or a regression in any of the five commands breaks
  orchestrator behavior for all intensities. Mitigations:
  - All scripts Bash 3.2 verified by automated scan.
  - Integration test exercises all three intensity levels end-to-end
    plus the override path.
  - Command-doc changes are additive (new section only); the existing
    workflow text is untouched so that a fresh agent reading the doc
    still sees the original prescriptions and degrades gracefully if
    the gate is missing.
-->

## Must-Haves

### Truths

- scripts/engine/intensity-gate.sh accepts --stage <name> and either --intensity <Quick|Standard|Full> or --intensity-metadata <path>, and outputs execute_substeps= and skip_substeps= as key=value lines.
  - Check: `bash scripts/verify/m008-p03-gate-arguments.sh`
- scripts/engine/intensity-gate.sh hardcodes the documented stage x intensity matrix so that, for example, stage=discuss intensity=Quick yields skip_substeps containing "all" and stage=verify intensity=Full yields execute_substeps containing all four tiers.
  - Check: `bash scripts/verify/m008-p03-gate-matrix.sh`
- scripts/engine/intensity-gate.sh covers all seven pipeline stages (discuss, research, plan-phase, dispatch, verify, knowledge, auto) with distinct substep lists per intensity level.
  - Check: `bash scripts/verify/m008-p03-gate-stage-coverage.sh`
- scripts/engine/intensity-gate.sh rejects unknown stage names and unknown intensity levels with exit non-zero and an error message on stderr.
  - Check: `bash scripts/verify/m008-p03-gate-rejects-unknown.sh`
- scripts/engine/intensity-override.sh accepts --metadata-file <path> and --new-intensity <Quick|Standard|Full>, rewrites the metadata YAML frontmatter so intensity= becomes the new value, preserves the prior value as original_intensity=, and sets overridden_by=developer.
  - Check: `bash scripts/verify/m008-p03-override-rewrites-metadata.sh`
- scripts/engine/intensity-override.sh rejects override to the same current intensity with exit non-zero (no-op rejection) and rejects invalid intensity values.
  - Check: `bash scripts/verify/m008-p03-override-rejects-invalid.sh`
- scripts/engine/intensity-override.sh does not modify any file other than the metadata file (does not touch summaries, plans, verification reports, or knowledge files).
  - Check: `bash scripts/verify/m008-p03-override-scope-limited.sh`
- scripts/knowledge/intensity-knowledge.sh reads intensity from a metadata file, runs only scripts/knowledge/write-summary.sh at Quick, runs write-summary.sh + scripts/knowledge/append-decision.sh at Standard, and runs the full pipeline (summary + decision + append-knowledge + rebuild-index) at Full.
  - Check: `bash scripts/verify/m008-p03-knowledge-pipeline.sh`
- commands/discuss.md, commands/plan-phase.md, commands/dispatch.md, commands/verify.md, and commands/auto.md each contain an "Intensity Behavior" section that describes per-level substeps and references scripts/engine/intensity-gate.sh.
  - Check: `bash scripts/verify/m008-p03-commands-intensity-section.sh`
- All new scripts are Bash 3.2 compatible (no associative arrays, no readarray, no |&, no process substitution).
  - Check: `bash scripts/verify/m008-p03-bash32-compat.sh`
- End-to-end integration: a fixture metadata file at each of Quick, Standard, Full produces distinct intensity-gate.sh outputs for every stage, the override script transitions Quick -> Full correctly, and intensity-knowledge.sh dispatches the expected subset of knowledge scripts at each level.
  - Check: `bash scripts/verify/m008-p03-integration-e2e.sh`

### Artifacts

- scripts/engine/intensity-gate.sh (min 120 lines, contains "--stage" and "--intensity" and "execute_substeps=" and "skip_substeps=")
- scripts/engine/intensity-override.sh (min 80 lines, contains "--metadata-file" and "--new-intensity" and "original_intensity" and "overridden_by")
- scripts/knowledge/intensity-knowledge.sh (min 80 lines, contains "write-summary.sh" and "append-decision.sh" and "intensity")
- commands/discuss.md (min 157 lines, contains "Intensity Behavior" and "intensity-gate.sh")
- commands/plan-phase.md (min 237 lines, contains "Intensity Behavior" and "intensity-gate.sh")
- commands/dispatch.md (min 143 lines, contains "Intensity Behavior" and "intensity-gate.sh")
- commands/verify.md (min 149 lines, contains "Intensity Behavior" and "intensity-gate.sh")
- commands/auto.md (min 531 lines, contains "Intensity Behavior" and "intensity-gate.sh")
- scripts/verify/m008-p03-gate-arguments.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p03-gate-matrix.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p03-gate-stage-coverage.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p03-gate-rejects-unknown.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p03-override-rewrites-metadata.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p03-override-rejects-invalid.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p03-override-scope-limited.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p03-knowledge-pipeline.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p03-commands-intensity-section.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p03-bash32-compat.sh (min 10 lines, contains "PASS")
- scripts/verify/m008-p03-integration-e2e.sh (min 10 lines, contains "PASS")

### Key Links

- scripts/engine/intensity-gate.sh -> templates/intensity-metadata.md (gate reads intensity metadata when --intensity-metadata is supplied)
- scripts/engine/intensity-override.sh -> templates/intensity-metadata.md (override rewrites the metadata schema)
- scripts/knowledge/intensity-knowledge.sh -> scripts/knowledge/write-summary.sh (Quick/Standard/Full all run this)
- scripts/knowledge/intensity-knowledge.sh -> scripts/knowledge/append-decision.sh (Standard/Full run this)
- scripts/knowledge/intensity-knowledge.sh -> scripts/knowledge/append-knowledge.sh (Full runs this)
- commands/discuss.md -> scripts/engine/intensity-gate.sh (discuss calls the gate at entry)
- commands/plan-phase.md -> scripts/engine/intensity-gate.sh (plan-phase calls the gate at entry)
- commands/dispatch.md -> scripts/engine/intensity-gate.sh (dispatch calls the gate at entry)
- commands/verify.md -> scripts/engine/intensity-gate.sh (verify calls the gate at entry)
- commands/auto.md -> scripts/engine/intensity-gate.sh (auto calls the gate at entry for every iteration)

## Tasks

### T01: Create scripts/engine/intensity-gate.sh -- the stage-level matrix gate

Creates `scripts/engine/intensity-gate.sh`, the central stage x intensity matrix. Accepts `--stage <name>` and either `--intensity <level>` or `--intensity-metadata <path>`. Hardcodes a table covering all seven stages (discuss, research, plan-phase, dispatch, verify, knowledge, auto) and all three levels. Emits two key=value lines: `execute_substeps=<csv>` and `skip_substeps=<csv>`. Rejects unknown inputs with non-zero exit and stderr message. Creates four verification scripts (arguments, matrix, stage coverage, reject-unknown).

Full plan: `tasks/T01-PLAN.md`

### T02: Create scripts/engine/intensity-override.sh -- mid-workflow override

Creates `scripts/engine/intensity-override.sh`. Accepts `--metadata-file <path>` and `--new-intensity <Quick|Standard|Full>`. Rewrites only the YAML frontmatter in the metadata file: sets `intensity:` to the new value, copies the previous value into `original_intensity:`, and sets `overridden_by: "developer"`. Rejects same-level overrides and invalid levels. MUST NOT touch any other file. Creates three verification scripts (rewrites, rejects-invalid, scope-limited).

Full plan: `tasks/T02-PLAN.md`

### T03: Create scripts/knowledge/intensity-knowledge.sh -- intensity-aware knowledge gate

Creates `scripts/knowledge/intensity-knowledge.sh`. Reads intensity from a metadata file, then dispatches the appropriate subset of existing knowledge scripts: Quick runs write-summary.sh only; Standard runs write-summary.sh + append-decision.sh; Full runs write-summary.sh + append-decision.sh + append-knowledge.sh + rebuild-index.sh. Honors a `--dry-run` mode that logs what would run without executing. Creates one verification script (knowledge-pipeline).

Full plan: `tasks/T03-PLAN.md`

### T04: Refactor commands/*.md -- add Intensity Behavior sections

Adds a new "Intensity Behavior" section to each of the five command docs: `commands/discuss.md`, `commands/plan-phase.md`, `commands/dispatch.md`, `commands/verify.md`, `commands/auto.md`. Each section documents the substeps per intensity level and instructs the agent executing the command to call `scripts/engine/intensity-gate.sh --stage <name> --intensity-metadata <path>` at entry and branch on `execute_substeps`/`skip_substeps`. MINIMAL refactor — no workflow rewrites, no frontmatter changes, no deletions. Creates one verification script (commands-intensity-section).

Full plan: `tasks/T04-PLAN.md`

### T05: Integration test + Bash 3.2 compatibility check

Creates `scripts/verify/m008-p03-bash32-compat.sh` scanning the three new scripts for prohibited Bash 4+ constructs. Creates `scripts/verify/m008-p03-integration-e2e.sh` that builds fixture metadata files at each of Quick, Standard, Full, invokes `intensity-gate.sh` for every stage and asserts distinct outputs, invokes `intensity-override.sh` to transition Quick -> Full and asserts the rewrite, and invokes `intensity-knowledge.sh --dry-run` at each level and asserts the expected subset of knowledge scripts appears in its dry-run log.

Full plan: `tasks/T05-PLAN.md`

## Task Dependencies

```
T01 (intensity-gate.sh)
  |
  +-----> T04 (command doc refactor references the gate)
  |
T02 (intensity-override.sh) -- independent of T01
  |
T03 (intensity-knowledge.sh) -- independent of T01 and T02
  |
  +-----+
        |
        v
     T05 (integration + bash32) -- depends on T01, T02, T03
```

- T01, T02, T03 are independent and can run in parallel.
- T04 depends on T01 (command docs reference `scripts/engine/intensity-gate.sh`).
- T05 depends on T01, T02, T03 (integration exercises all three).

## Files Likely Touched

- scripts/engine/intensity-gate.sh (create)
- scripts/engine/intensity-override.sh (create)
- scripts/knowledge/intensity-knowledge.sh (create)
- commands/discuss.md (modify)
- commands/plan-phase.md (modify)
- commands/dispatch.md (modify)
- commands/verify.md (modify)
- commands/auto.md (modify)
- scripts/verify/m008-p03-gate-arguments.sh (create)
- scripts/verify/m008-p03-gate-matrix.sh (create)
- scripts/verify/m008-p03-gate-stage-coverage.sh (create)
- scripts/verify/m008-p03-gate-rejects-unknown.sh (create)
- scripts/verify/m008-p03-override-rewrites-metadata.sh (create)
- scripts/verify/m008-p03-override-rejects-invalid.sh (create)
- scripts/verify/m008-p03-override-scope-limited.sh (create)
- scripts/verify/m008-p03-knowledge-pipeline.sh (create)
- scripts/verify/m008-p03-commands-intensity-section.sh (create)
- scripts/verify/m008-p03-bash32-compat.sh (create)
- scripts/verify/m008-p03-integration-e2e.sh (create)
