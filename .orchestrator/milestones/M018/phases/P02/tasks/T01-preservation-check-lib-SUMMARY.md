---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P02"
milestone: "M018"
provides:
  - "scripts/lib/preservation-check.sh (sourceable library); 3 exported functions (pres_check_section, pres_emit_violation, pres_density_pre_check); PRES_PATTERNS_REGEX/PRES_PATTERN_NAMES parallel indexed arrays (10-row cross-tier vocabulary pinned to grammar v1.0.1); selftest entry point"
requires:
  - "references/compression-grammar.md v1.0.1 (status: Reviewed); P01 closure (MIT-08/09/10 carryover)"
affects:
  - "P02/T02 (sources library when wiring filter caller); P03 (T1 microcompact sources for self-check); P04 (T2 snip sources for self-check); P06 (T3 auto-compact sources for self-check + density pre-check via MIT-08 deterministic-fallback-to-tier2-passthrough); P02/T04 (writes scripts/verify/m018-p02-preservation-check-api.sh that exercises this library)"
key_files:
  - "scripts/lib/preservation-check.sh"
key_decisions:
  - "Single indexed array PRES_PATTERNS_REGEX (not parallel arrays) for the regex list — flat list, simpler, still 3.2 safe; tier-arg defaults to tier2 (strict multiplicity) — tier3 callers must explicitly opt into at-least-once; pres_emit_violation is bail-safe (mkdir/append failure logs to stderr returns 0) so the dispatcher never crashes on emitter failure; pres_density_pre_check fails open on missing/empty file (preservation density of 0); grep -cE exit-code handling uses [ -z "$x "] && x=0 idiom (NOT || echo 0 which double-prints when grep exits 1 with stdout 0)"
patterns_established:
  - "Sourceable-library shape: shebang + comment block naming version+pinned-grammar+export surface, NO top-level set -eu, function declarations, selftest gated by ${BASH_SOURCE[0]:-$0} = $0 idiom; cross-tier vocabulary as parallel indexed arrays (PRES_PATTERNS_REGEX + PRES_PATTERN_NAMES) for bash 3.2 safety; integer math for percentage thresholds via *_x100 scaling (no floats in 3.2)"
drill_down_paths:
  - "scripts/lib/preservation-check.sh;references/compression-grammar.md (v1.0.1 lines 117-135 vocabulary, lines 368-378 FR-2 schema);.orchestrator/milestones/M018/phases/P01/conversus/gate-result.md (MIT-08/09/10 origin)"
duration: "35"
verification_result: "pass"
completed_at: "2026-04-27T22:53:14Z"
---

T01 ships the preservation-contract self-check library that P03/P04/P06 will source. The library is bash 3.2 sourceable, AP-009 shape compliant, and pins to grammar contract v1.0.1's Preserved-Pattern Vocabulary table verbatim (10 rows: YAML frontmatter delim, code fence 3+ backticks, absolute path, repo-relative script path, MEM ID, command name, URL, JSONL record, scaffold-TODO, in-band compression marker).

Three exported functions: pres_check_section is the regex-driven pattern walker — for each pattern row it counts grep -cE matches in pre and post files and asserts strict multiplicity for tier1/tier2 (default) or at-least-once for tier3 (per grammar contract semantics). Returns 0 PASS, 1 on first violation, with one VIOLATION: line to stderr per failed pattern (single-violation diagnostic per FR-2 fail-closed). pres_emit_violation appends tier_preservation_violation JSONL records to a caller-named log path; bail-safe (mkdir/append failure logs to stderr returns 0 so dispatcher never crashes). pres_density_pre_check computes preservation density as matches / (bytes/100) and returns 1 (refuse) when density exceeds the configured threshold — MIT-08 groundwork for tier3's deterministic-fallback-to-tier2-passthrough enforcement.

Verification: selftest passes (PASS: pres_check_section selftest, exit 0). 10-test out-of-band probe covers tier2/tier3 semantics, JSONL emission shape, density refuse + fail-open paths, sourceability, and parallel-array length parity — all 10 PASS. Phase-level check-must-haves.sh confirms scripts/lib/preservation-check.sh exists, has 238 lines (min 80), contains pres_check_section, and key-links to references/compression-grammar.md. Other phase truths fail by design — they are T02/T03/T04 deliverables.

Key shape detail: grep -cE always prints a count to stdout but exits 1 when count is 0. The naive idiom 'pre_count=$(grep -cE "$re" "$f" 2>/dev/null || echo 0)' double-prints '0\n0' when grep exits 1 with stdout 0, which then trips '[: integer expression expected' downstream. The library uses 'pre_count=$(grep -cE ... 2>/dev/null); if [ -z "$pre_count" ]; then pre_count=0; fi' instead — relies on the bash rule that 'local x=$(cmd)' does not propagate command-substitution exit codes. Future tier callers should follow this idiom when integrating.

T01 ships the API only; no callers are wired yet. T02 wires the filter caller; P03/P04/P06 wire tier callers; T04 ships scripts/verify/m018-p02-preservation-check-api.sh which exercises the library against fixtures.
