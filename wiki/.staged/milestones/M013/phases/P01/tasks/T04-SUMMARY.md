---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P01"
milestone: "M013"
provides:
  - "rebuild-index.sh additive-emit pass; flat Spec Chunks section in KNOWLEDGE-INDEX.md (chunk_id pipe title pipe phase_id); emit_spec_chunks_section helper in lib/index-utils.sh"
requires:
  - "none"
affects:
  - "scripts/knowledge/rebuild-index.sh, scripts/knowledge/lib/index-utils.sh, KNOWLEDGE-INDEX.md"
key_files:
  - "scripts/knowledge/rebuild-index.sh,scripts/knowledge/lib/index-utils.sh,scripts/verify/m013-p01-rebuild-index-additive.sh,KNOWLEDGE-INDEX.md"
key_decisions:
  - "D014 Knowledge-Layer Boundary: chunk_id pinned to existing SPEC-* frontmatter id field; no new ID format; phase_id verbatim or empty string; additive-only append after write_full_index"
patterns_established:
  - "additive-emit boundary: new section appended after write_full_index with existing MEM* pipe-table rows byte-identical; pipefail-safe optional-frontmatter grep via subshell-grouped grep-or-true wrap so absent fields do not fail the pipeline under set -euo pipefail"
drill_down_paths:
  - ".orchestrator/milestones/M013/phases/P01/tasks/T04-PLAN.md"
duration: "25m"
verification_result: "pass"
completed_at: "2026-04-21T18:08:21Z"
---

T04 adds an additive-only emit pass to scripts/knowledge/rebuild-index.sh that produces a flat Spec Chunks section in KNOWLEDGE-INDEX.md with one line per knowledge/spec/SPEC-*.md file in the format chunk_id pipe title pipe phase_id. Implementation added emit_spec_chunks_section to scripts/knowledge/lib/index-utils.sh (MEM004 Pure Lib Extraction). The helper scans knowledge/spec subtree (skipping archive), sorts lexicographically by chunk_id, and appends to the target index path; no-op when knowledge/spec is absent. Wired into scripts/knowledge/rebuild-index.sh immediately after write_full_index and before the SQLite atomic move; the existing MEM/SPEC pipe-table body is untouched. chunk_id is sourced verbatim from the SPEC-* id frontmatter field; title is the first heading with any SPEC-XX-NNN prefix stripped and truncated to 80 chars; phase_id is verbatim from frontmatter when present, empty string otherwise (currently empty for all 20 SPEC-* files — none carry phase_id yet). Pipefail-safe pattern: grep lookups for optional frontmatter are wrapped as a grep-or-true subshell group so absent fields do not fail the pipeline under set -euo pipefail. Gate scripts/verify/m013-p01-rebuild-index-additive.sh asserts the rebuilder exits 0, pre-existing MEM* pipe-table rows remain, Spec Chunks heading is present, at least one flat-format row in the section, every on-disk SPEC-* id appears as a row, and re-running produces a byte-identical index (idempotent). All 8 PASS, exit 0. Non-negotiables honored: additive-only (existing rows byte-identical); Bash 3.2 compatible (no declare -A, no process substitution); single-script-file shape per AD-19; chunk_id pinned to existing frontmatter per D014 Knowledge-Layer Boundary (no new ID format, no composite addressing); M013 does not author chunk-schema evolution — that stays with [M020](../../../../../milestones/M020/index.md).
