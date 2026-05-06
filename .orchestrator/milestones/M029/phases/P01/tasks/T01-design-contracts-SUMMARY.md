---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P01"
milestone: "M029"
provides:
  - "Principle III design contracts for FR-2 status headline + FR-3 status --format=json; gate verifiers that mechanically enforce field, regex, and key presence so downstream tasks (T03/T04) cannot drift from the contracts"
requires:
  - "from:none what:T01 is the P01 entry point; depends_on is empty per task plan"
affects:
  - "P01"
key_files:
  - "references/status-headline-shape.md,references/status-json-schema.md,tools/verify/m029-p01-headline-shape-contract.sh,tools/verify/m029-p01-json-schema-contract.sh"
key_decisions:
  - "AD-1 single-resolve invocation context discipline,AD-2 unconditional ANSI strip under --format=json,AD-7 schema_version 1.0 from day 1 + stability policy,Principle III design contracts upstream of code"
patterns_established:
  - "paired design contracts cross-checked by gate verifiers in both directions; verifiers assert field/regex/key presence rather than just file existence so downstream consumers cannot silently drift"
drill_down_paths:
  - ".orchestrator/milestones/M029/phases/P01/tasks/T01-design-contracts-PAYLOAD.md"
duration: "1h"
verification_result: "pass"
completed_at: "2026-05-05T22:38:34Z"
---

T01 ships the two Principle III design contracts gating every other M029/P01 task plus the two gate verifiers that enforce them mechanically.

Artifacts:
- references/status-headline-shape.md (180 lines) — canonical FR-2 design contract. Documents the five-field set in fixed order (milestone ID + name; phase index + percent; lock state; last-dispatch recency; last-verify result), the three-line packing convention with the '  |  ' separator, the M027 efficiency-footer embedding under efficiency_footer: true, the canonical SC-2 headline-regex block, the CON-5 suppression-matrix inheritance, and cross-references to the JSON schema companion + commands/status.md + the M027 helper.
- references/status-json-schema.md (256 lines) — canonical FR-3 design contract. Declares schema_version: "1.0" from day 1 per AD-7, documents the ten required top-level keys with types and headline-field mapping, the AD-2 unconditional ANSI strip rule (single strip site at scripts/diagnostics/render-status-json.sh), the degraded-state envelope with state: "degraded" + parse_errors[*] for corrupt JSONL streams, the exact ANSI strip primitive regex (\\x1b\\[[0-9;]*[mGKHF]), the versioning policy (minor bumps for additions; major bumps + deprecation cycles for removals or type changes), and downstream consumers (M035 packaging, post-launch external-tool-adapters).
- tools/verify/m029-p01-headline-shape-contract.sh (103 lines, executable) — gate verifier asserting all eight required headers, the headline-regex fenced-block token, the five field names, the FR-2 / SC-2 / CON-5 spec references, and the two cross-references. 20 PASS lines, fail=0.
- tools/verify/m029-p01-json-schema-contract.sh (144 lines, executable) — gate verifier asserting all eight required headers, schema_version + literal "1.0", every required top-level key, the AD-2 degraded-state keys (state, parse_errors, "degraded"), the AD-7 / AD-2 / FR-3 / SC-3 spec references, the two cross-references, and the ANSI CSI terminator class. 31 PASS lines, fail=0.

Verification (must-haves):
- bash tools/verify/m029-p01-headline-shape-contract.sh -> SUMMARY: pass=20 fail=0 (exit 0)
- bash tools/verify/m029-p01-json-schema-contract.sh -> SUMMARY: pass=31 fail=0 (exit 0)

Pairing invariant: the five headline fields documented in status-headline-shape.md appear as the corresponding top-level JSON keys in status-json-schema.md (milestone_id + milestone_name <-> field 1; phase_index + phase_count + phase_percent_complete <-> field 2; lock_state <-> field 3; last_dispatch_recency <-> field 4; last_verify_result <-> field 5). Both verifiers cross-check the companion contract is referenced. Drift between the two files is a contract violation.

Constraints upheld:
- Contracts contain no executable code (only documentation + fenced illustrative blocks).
- schema_version locked at "1.0" per AD-7.
- No new schema additions to M013 sidecar / M019 JSONL / M020 KNOWLEDGE.md / M027 surfaces (CON-7 / AD-8 boundary).
- Verifier shape uses single-script-file invocations per AD-19.
- Bash 3.2 compatible (no associative arrays; no compound subshells).

Downstream consumption: T03 reads field order + line packing + regex from status-headline-shape.md to render the headline. T04 reads top-level keys + ANSI strip rule + degraded-state envelope from status-json-schema.md to wire --format=json. T05 cross-references both contracts. T06's phase suite chains both gate verifiers as gate 1 + gate 2.
