---
schema_version: "1.0"
type: phase-plan
phase: "P06"
milestone: "M002"
goal: "Validate, register, and integrate model routing scripts (classify-complexity.sh, select-model.sh) and routing.yaml — ensuring automatic complexity classification, explicit override, extension.yml registration, routing format documentation in file-formats.md, and integration with dispatch and auto commands"
demo_sentence: "A developer configures routing.yaml with model tiers, dispatches tasks of varying complexity, and each task routes to the correct model based on automatic classification from task plan metadata or explicit complexity frontmatter override."
risk: "low"
depends_on: ["P05"]
---

## Must-Haves

### Truths

- classify-complexity.sh reads a task plan file and outputs one of heavy, standard, or light based on keyword signal matching
  - Check: `bash scripts/verify/m002-p06-classify-outputs-tier.sh`
- classify-complexity.sh respects explicit `complexity:` frontmatter override in task plan YAML header
  - Check: `bash scripts/verify/m002-p06-classify-explicit-override.sh`
- classify-complexity.sh accepts optional `--routing-config` flag to use custom classification keywords from routing.yaml
  - Check: `bash scripts/verify/m002-p06-classify-routing-config.sh`
- select-model.sh maps a complexity tier to a model ID and context budget from routing.yaml, with built-in defaults when no config exists
  - Check: `bash scripts/verify/m002-p06-select-model-output.sh`
- select-model.sh supports fallback chain via --list-fallback and --next-fallback modes
  - Check: `bash scripts/verify/m002-p06-select-model-fallback.sh`
- templates/routing.yaml defines model tiers (heavy/standard/light) with id, context_budget, fallback, plus classification patterns, history_weight, and budget_ceiling_usd
  - Check: `bash scripts/verify/m002-p06-routing-template-format.sh`
- references/file-formats.md documents the routing.yaml format with schema, parsing rules, and field descriptions
  - Check: `bash scripts/verify/m002-p06-fileformats-routing-section.sh`
- extension.yml registers classify-complexity.sh and select-model.sh as executable scripts
  - Check: `bash scripts/verify/m002-p06-extension-registration.sh`
- All routing scripts are Bash 3.2 compatible (no associative arrays, no readarray, no mapfile)
  - Check: `bash scripts/verify/m002-p06-bash32-compat.sh`

### Artifacts

- scripts/dispatch/classify-complexity.sh (min 30 lines, contains "complexity")
- scripts/dispatch/select-model.sh (min 80 lines, contains "select")
- templates/routing.yaml (min 15 lines, contains "models")
- scripts/verify/m002-p06-classify-outputs-tier.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p06-classify-explicit-override.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p06-classify-routing-config.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p06-select-model-output.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p06-select-model-fallback.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p06-routing-template-format.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p06-fileformats-routing-section.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p06-extension-registration.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p06-bash32-compat.sh (min 3 lines, contains "PASS")

### Key Links

- scripts/dispatch/classify-complexity.sh -> templates/routing.yaml (reads classification patterns from routing config)
- scripts/dispatch/select-model.sh -> templates/routing.yaml (reads model tiers from routing config)
- scripts/dispatch/select-model.sh -> scripts/lib/recipe-parser.sh (uses read_recipe_field and parse_recipe_fallback)
- references/file-formats.md -> templates/routing.yaml (documents routing.yaml format)
- extension.yml -> scripts/dispatch/classify-complexity.sh (registered as executable script)
- extension.yml -> scripts/dispatch/select-model.sh (registered as executable script)

## Tasks

### T01: Verification Scripts for All Must-Haves

Create all 9 verification scripts that mechanically check the P06 must-haves. These scripts exercise the existing classify-complexity.sh, select-model.sh, templates/routing.yaml, and check for extension.yml registration and file-formats.md documentation.

### T02: Audit and Harden Routing Scripts

Review classify-complexity.sh and select-model.sh against FR-116/FR-117 requirements. Validate templates/routing.yaml format against the spec. Fix any gaps, register both scripts in extension.yml, and document the routing.yaml format in references/file-formats.md.

### T03: End-to-End Routing Verification

Create synthetic task plans of varying complexity, run classify-complexity.sh and select-model.sh against them, and verify all 9 verification scripts pass. Prove the full routing pipeline: task plan -> complexity classification -> model selection.

## Task Dependencies

T01 -> T02 -> T03

T01 writes the verification scripts that define the acceptance bar. T02 audits and hardens the scripts to pass those checks, plus registers and documents them. T03 runs the integration test proving everything works end-to-end.

## Files Likely Touched

- scripts/verify/m002-p06-classify-outputs-tier.sh (create)
- scripts/verify/m002-p06-classify-explicit-override.sh (create)
- scripts/verify/m002-p06-classify-routing-config.sh (create)
- scripts/verify/m002-p06-select-model-output.sh (create)
- scripts/verify/m002-p06-select-model-fallback.sh (create)
- scripts/verify/m002-p06-routing-template-format.sh (create)
- scripts/verify/m002-p06-fileformats-routing-section.sh (create)
- scripts/verify/m002-p06-extension-registration.sh (create)
- scripts/verify/m002-p06-bash32-compat.sh (create)
- scripts/dispatch/classify-complexity.sh (modify)
- scripts/dispatch/select-model.sh (modify)
- templates/routing.yaml (modify)
- extension.yml (modify)
- references/file-formats.md (modify)
