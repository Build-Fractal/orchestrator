---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P06"
milestone: "M002"
provides:
  - "classify-complexity.sh custom routing-config keyword reading, extension.yml registration for classify-complexity.sh and select-model.sh, routing.yaml documentation in references/file-formats.md"
requires:
  - "scripts/dispatch/classify-complexity.sh, scripts/dispatch/select-model.sh, templates/routing.yaml, extension.yml, references/file-formats.md, scripts/lib/recipe-parser.sh"
affects:
  - "extension.yml provides.scripts section, references/file-formats.md routing section, scripts/dispatch/classify-complexity.sh custom pattern support"
key_files:
  - "scripts/dispatch/classify-complexity.sh, extension.yml, references/file-formats.md, scripts/dispatch/select-model.sh, templates/routing.yaml"
key_decisions:
  - "classify-complexity.sh enhanced to read classification patterns from routing config via recipe-parser when --routing-config is provided; custom patterns replace built-in keywords rather than supplement to avoid double-counting; select-model.sh passed audit with no changes needed; SIGPIPE workaround at lines 124-128 is correct and properly scoped"
patterns_established:
  - "Custom keyword classification via routing config comma-separated patterns parsed by recipe-parser; routing scripts registered in extension.yml after detect-capabilities.sh maintaining dispatch script grouping"
drill_down_paths:
  - "scripts/dispatch/classify-complexity.sh, scripts/dispatch/select-model.sh, templates/routing.yaml, references/file-formats.md"
duration: "420"
verification_result: "pass"
completed_at: "2026-04-13T16:23:56Z"
---

Audited, hardened, registered, and documented the model routing scripts. Enhanced classify-complexity.sh to read custom classification keywords from routing.yaml via recipe-parser when --routing-config flag is provided (previously the flag was accepted but not used). select-model.sh passed audit without changes: all modes (default, list-fallback, next-fallback) work correctly, SIGPIPE workaround is properly scoped. templates/routing.yaml validated as parseable by recipe-parser for all required fields. Registered both routing scripts in extension.yml under provides.scripts after detect-capabilities.sh. Added comprehensive routing.yaml documentation section to references/file-formats.md with schema, field descriptions, parsing rules, and resolution order. All 9 verification scripts pass.
