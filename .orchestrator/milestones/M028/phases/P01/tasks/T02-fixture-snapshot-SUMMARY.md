---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P01"
milestone: "M028"
provides:
  - "canonical M028 pre-repair fixture (sanitized operator M018-close ~/.claude/settings.json backup) at tests/fixtures/m028-pre-repair-snapshot.json; deterministic sanitizer scripts/verify/m028/p01-fixture-sanitize.sh; must-have verifier scripts/verify/m028/p01-fixture-sanitized.sh"
requires:
  - "from:disk what:~/.claude/settings.json.bak-m018-cleanup-2026-04-28 (operator M018-close backup carrying 5 unflagged Stop duplicates + 7 unflagged PreToolUse Bash duplicates per Finding F); from:M025 what:_orchestrator_managed flag convention (MEM027 merge-not-overwrite)"
affects:
  - "P02 (--repair verifier consumes the fixture as install-roundtrip input); P05 cross-project replay (fixture available as control input)"
key_files:
  - "tests/fixtures/m028-pre-repair-snapshot.json;scripts/verify/m028/p01-fixture-sanitize.sh;scripts/verify/m028/p01-fixture-sanitized.sh"
key_decisions:
  - "partial-flag fixture shape (5 unflagged + 1 flagged Stop entries; 7 unflagged + 1 flagged PreToolUse Bash entries) preserves Finding F regression evidence while satisfying _orchestrator_managed anchor must-have; token-redaction regex restricted to a 32+ char alphanumeric (plus underscore and hyphen) class drops + / = from char class to prevent path-segment false positives; sanitization implemented in two stages -- sed for path/email/token bytes, python3 for structural flag injection -- both deterministic"
patterns_established:
  - "two-stage deterministic sanitization (BSD-portable sed -E for byte-level redactions then python3 json mutation for structural injection); partial-flag fixture realism (mixing pre-M025 unflagged residue with post-M025 flagged entries reflects real downstream user systems); separate -sanitize (transformer, runs once at fixture creation) and -sanitized (verifier, runs at every phase verification) script naming"
drill_down_paths:
  - "tests/fixtures/m028-pre-repair-snapshot.json;scripts/verify/m028/p01-fixture-sanitize.sh;scripts/verify/m028/p01-fixture-sanitized.sh"
duration: "30"
verification_result: "pass"
completed_at: "2026-04-29T14:09:18Z"
---

Captured the operator's M018-close ~/.claude/settings.json.bak-m018-cleanup-2026-04-28 as the canonical M028 pre-repair fixture at tests/fixtures/m028-pre-repair-snapshot.json (173 lines, valid JSON). The fixture preserves the Finding F regression shape verbatim -- 5 unflagged Stop wrappers naming orchestrator-post-verify and 7 unflagged PreToolUse Bash wrappers naming orchestrator-before-commit -- and adds one M025-flagged entry per array (1 Stop + 1 PreToolUse, both carrying _orchestrator_managed: true) to model the realistic partial-flag shape downstream P02 --repair verifiers will encounter. Sanitization runs through scripts/verify/m028/p01-fixture-sanitize.sh in two deterministic stages: BSD-portable sed -E redacts the operator local path prefix to /Users/<USER>/, the standalone token brettkellgren to <USER>, the operator email to <USER>@<DOMAIN>, and any 32+ char alphanumeric (plus underscore and hyphen) run to <REDACTED-TOKEN>; then python3 mutates the parsed JSON to append the two flagged entries. Determinism verified by running the sanitizer twice and diffing -- byte-identical. The token regex char class deliberately excludes plus, slash, and equals so filesystem path segments like claude/hooks/gsd-context-monitor are not falsely redacted. The must-have verifier scripts/verify/m028/p01-fixture-sanitized.sh asserts six invariants (file present, parseable JSON, zero leaks for the operator local path prefix, the standalone brettkellgren token, and the operator email, plus _orchestrator_managed anchor present) and exits 0 with PASS: m028-pre-repair-snapshot.json sanitized and shape-valid. The .raw intermediate is deleted at task close. Both scripts conform to AD-19 single-script-file shape and bash 3.2 + POSIX-sh discipline.
