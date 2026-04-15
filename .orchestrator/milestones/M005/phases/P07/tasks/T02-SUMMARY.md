---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P07"
milestone: "M005"
provides:
  - "scripts/lifecycle/generate-permissions.sh core permission generator, detect-capabilities.sh agent host markers"
requires:
  - "from:P07/T01 what:autonomy-defaults.yaml,extension.yml"
affects:
  - "T03,T04,P06"
key_files:
  - "scripts/lifecycle/generate-permissions.sh,scripts/dispatch/detect-capabilities.sh"
key_decisions:
  - "AD-10,AD-7,AD-11,AD-14,AD-16,AD-20,AD-21"
patterns_established:
  - "per-source fallback introspection, canonical JSON envelope with provenance markers, recipe-parser.sh reuse for YAML policy"
drill_down_paths:
  - ".specify/orchestrator/milestones/M005/phases/P07/tasks/T02-PLAN.md"
duration: "295s"
verification_result: "pass"
completed_at: "2026-04-12T16:22:38Z"
---

Created generate-permissions.sh (289 lines). Introspects package.json scripts, Makefile targets, extension.yml scripts, toolchain configs, and agent host markers. Emits canonical AD-16 JSON envelope with _generated_by/_generated_at/_autonomy_mode provenance. Sources recipe-parser.sh for autonomy-defaults.yaml, errors.sh and events.sh for structured output. Idempotent (two runs produce byte-identical output minus timestamp). Bash 3.2 compatible, no jq dependency. Extended detect-capabilities.sh with .claude/.cursor/.github/copilot host detection.
