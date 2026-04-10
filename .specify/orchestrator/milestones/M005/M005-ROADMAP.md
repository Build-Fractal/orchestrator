---
schema_version: "1.0"
type: roadmap
milestone: "M005"
feature_ref: "005-hardening-integration-prep"
feature_spec: null
vision: "Harden the M004 engine architecture with content-hash idempotency, cost transparency, pure transform extraction, and formalized interfaces — establishing the concrete integration seam for Conversus deliberation gates and future execution providers."
tier: "C"
created_at: "2026-04-10T23:00:00Z"
updated_at: "2026-04-10T23:00:00Z"
---

## Phases

- [ ] **P01**: Content-Hash Idempotency — "Knowledge entries include a `content_hash: sha256:...` field in frontmatter; rebuild-index.sh uses hashes to detect actual changes; dispatch results recorded as `outcome: unchanged` when agent output hash matches prior dispatch — enabling stagnation signal without re-reading full content."
  - Risk: medium
  - Depends: none
  - Boundary Map:
    - Produces:
      - Updated knowledge entry frontmatter schema — adds `content_hash` field
      - Updated `scripts/knowledge/create-entry.sh` — computes and writes content_hash
      - Updated `scripts/knowledge/update-entry.sh` — recomputes hash on content change
      - Updated `scripts/knowledge/rebuild-index.sh` — detects changed vs unchanged entries via hash comparison
      - Hash utility function in `scripts/lib/hash.sh` — `compute_content_hash` (SHA-256 of body, formatted as `sha256:{hex}`), double-sourcing guard
      - Updated `scripts/lifecycle/record-result.sh` — records `outcome: unchanged` when output hash matches prior
    - Consumes:
      - Existing knowledge scripts (from M002)
      - `scripts/lib/errors.sh` (from M004 P02) — emit_result on completion

- [ ] **P02**: Cost Transparency — "Execution-log.jsonl entries include `cost_source` field (estimated/reported/unknown); aggregate-metrics.sh distinguishes unknown costs from zero costs; telemetry dashboard-ready output groups by cost accuracy."
  - Risk: low
  - Depends: none
  - Boundary Map:
    - Produces:
      - Updated `scripts/telemetry/record-telemetry.sh` — adds `cost_source` field to JSONL entries
      - Updated `scripts/telemetry/aggregate-metrics.sh` — groups by cost_source, reports estimated vs reported accuracy
      - Updated execution-log.jsonl schema documentation — null = unknown, 0 = free, cost_source enum
    - Consumes:
      - Existing telemetry scripts (from M002)
      - `scripts/lib/errors.sh` (from M004 P02)

- [ ] **P03**: Pure Transform Extraction — "Core payload transforms (section assembly, manifest building, compression steps) extracted into sourced lib/ functions that take stdin and return stdout with no file I/O — independently testable via pipe chains."
  - Risk: medium
  - Depends: none (operates on M004 P05 refactored scripts)
  - Boundary Map:
    - Produces:
      - `scripts/lib/payload-transforms.sh` — pure functions: `assemble_section`, `drop_by_priority`, `summarize_section`, `drop_lowest_confidence`, double-sourcing guard
      - `scripts/lib/manifest-builder.sh` — pure functions: `build_manifest_header`, `compute_section_tokens`, `format_manifest_row`, double-sourcing guard
      - Refactored `scripts/dispatch/build-context.sh` — delegates to lib functions for transforms
      - Refactored `scripts/dispatch/compress-payload.sh` — delegates to lib functions for compression steps
    - Consumes:
      - Refactored dispatch scripts (from M004 P05)
      - `scripts/lib/recipe-parser.sh` (from M004 P04)

- [ ] **P04**: Agent Instruction Schema — "A template at `templates/instruction-schema.md` defines required sections (Context, Task, Constraints, Verification, Output Format) and optional sections (Prior Art, Related Knowledge); a conformance check in run-doctor.sh verifies instruction files match the schema."
  - Risk: medium
  - Depends: none
  - Boundary Map:
    - Produces:
      - `templates/instruction-schema.md` — declared schema with required and optional section headings, field descriptions, examples
      - `scripts/diagnostics/check-instructions.sh` — static conformance check: greps instruction files for required section headings, reports missing sections
      - Updated `scripts/diagnostics/run-doctor.sh` — runs instruction conformance check
      - At least 2 existing task plan templates updated to conform (progressive migration start)
    - Consumes: nothing (standalone, references constitution Principle XIII)

- [ ] **P05**: Gate Verdict Protocol and Provider Convention — "Hook scripts can return structured verdicts (PASS/BLOCK/WARN/NEEDS_REVIEW) via a documented protocol; execution providers follow a documented shell convention (arguments, env vars, output path); run-doctor.sh validates provider scripts against the convention."
  - Risk: medium
  - Depends: P01 (hash utility), P02 (cost source)
  - Boundary Map:
    - Produces:
      - `scripts/lib/verdicts.sh` — verdict protocol functions: `emit_verdict`, `parse_verdict`, verdict constants (PASS, BLOCK, WARN, NEEDS_REVIEW), double-sourcing guard
      - Updated `scripts/lib/hooks.sh` — parses hook stdout for VERDICT lines, maps to block/warn/continue behavior
      - `references/provider-convention.md` — documented shell interface for execution providers (required args, env vars, output format, exit codes)
      - `scripts/diagnostics/check-providers.sh` — validates provider scripts against convention (checks for required argument handling, output path usage)
      - Updated `scripts/diagnostics/run-doctor.sh` — runs provider conformance check
    - Consumes:
      - `scripts/lib/hooks.sh` (from M004 P02)
      - `scripts/lib/hash.sh` (from P01) — providers may report content hashes
      - Cost source enum (from P02) — providers report cost_source alongside cost

- [ ] **P06**: Conformance Test Kit Expansion — "run-doctor.sh performs full constitution v2.0 compliance checking: verifies all 13 principles are referenced in active phase plans, all engine-path scripts emit events, all recipes have valid structure, all knowledge entries have content hashes, all JSONL entries have run_id — producing a scored health report."
  - Risk: low
  - Depends: P01, P02, P03, P04, P05
  - Boundary Map:
    - Produces:
      - Updated `scripts/diagnostics/check-constitution.sh` — full v2.0 principle coverage check across plans
      - Updated `scripts/diagnostics/check-events.sh` — verifies emit_event presence in all engine-path scripts
      - `scripts/diagnostics/check-hashes.sh` — verifies all knowledge entries have valid content_hash fields
      - `scripts/diagnostics/check-run-ids.sh` — verifies recent JSONL entries include run_id field
      - Updated `scripts/diagnostics/run-doctor.sh` — aggregates all checks into scored health report (checks passed / total checks)
      - Updated `extension.yml` — registers new diagnostic scripts
    - Consumes: all prior phases' outputs for validation

## Dependency Graph

```
P01 (Hashes) ──────────────────→ P05 (Verdicts & Providers)
P02 (Cost) ────────────────────→ P05
P03 (Pure Transforms)               │
P04 (Instruction Schema)            │
                                     ▼
P01, P02, P03, P04, P05 ──────→ P06 (Conformance)
```

P01, P02, P03, P04 are all independent — can execute concurrently.
P05 depends on P01 and P02.
P06 depends on all prior phases.

## Execution Order

1. **P01** (Hashes), **P02** (Cost), **P03** (Pure Transforms), **P04** (Instruction Schema) — all independent, can execute concurrently or in any order. All medium or low risk.
2. **P05** (Verdicts & Providers) — depends on P01 and P02. Medium risk.
3. **P06** (Conformance Expansion) — depends on all prior phases. Low risk. Executes last.

## Validation

- **No conflicting producers**: PASS — P01 touches knowledge scripts + hash lib. P02 touches telemetry scripts. P03 touches dispatch lib functions. P04 produces instruction schema + check. P05 produces verdict lib + provider convention. P06 produces diagnostic checks. No overlaps.

- **All consumed items have producers**: PASS — P05 consumes P01 hash lib and P02 cost source. P06 consumes all prior outputs. All satisfied.

- **DAG is acyclic**: PASS — {P01, P02, P03, P04} → {P05} → {P06}. No cycles.
