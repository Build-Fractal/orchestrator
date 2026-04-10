---
schema_version: "1.0"
type: context-draft
milestone: "M005"
status: draft
created_at: "2026-04-10T23:00:00Z"
finalized_at: null
---

## Architectural Decisions

### AD-1: Content hashing uses same sha256 prefix format as index-pipeline

Content hashes on knowledge entries and dispatch outputs use `sha256:{64-hex}` format (matching index-pipeline convention, Constitution Principle XI: Single Source of Truth). Never bare hex. Hash computed from body content only (excludes frontmatter).

### AD-2: Cost source is a closed enum, not a free string

Three cost source values: `estimated` (chars/4 heuristic), `reported` (from provider response), `unknown` (no data available). `null` cost in JSONL means unknown, `0` means actually free. This distinction is load-bearing for Conversus gate cost decisions.

### AD-3: Gate verdict schema is provider-agnostic

The verdict schema (`PASS`, `BLOCK`, `WARN`, `NEEDS_REVIEW`) is not Conversus-specific. Any hook at PRE_DISPATCH or POST_DISPATCH can return a verdict. Conversus will use the same protocol. This means non-Conversus gates (simple quality checks, budget gates) speak the same language.

### AD-4: Agent instruction schema is a template, not code

The instruction schema is a markdown template with required sections and optional sections. Enforcement is via conformance check (static grep for section headings), not runtime parsing. This keeps it Bash 3.2 compatible and avoids building a template engine.

### AD-5: Pure transforms are sourced libraries, not standalone scripts

Extracted pure transforms (payload section assembly, manifest building, compression logic) live in `scripts/lib/` as sourced functions, not in `scripts/dispatch/` as standalone scripts. They take stdin/arguments, return stdout. No file I/O inside the function — callers handle I/O.

### AD-6: Provider abstraction is a shell convention, not a protocol

Unlike Conversus (Python Protocol class) or index-pipeline (runtime-checkable Protocol), the orchestrator's provider abstraction is a documented shell convention: a provider script must accept specific arguments, set specific environment variables on exit, and write output to a specified path. Conformance is checked by the diagnostics doctor, not by a type system.

## Scope Boundaries

### In Scope

- Content-hash fields on knowledge entry frontmatter + dispatch output metadata
- Hash-based change detection for knowledge rebuild and dispatch result recording
- Cost source enum (estimated/reported/unknown) in execution-log.jsonl schema
- Null vs zero cost distinction in telemetry recording and aggregation
- Pure transform extraction from build-context.sh and compress-payload.sh into lib/ functions
- Agent instruction schema template with required/optional sections
- Instruction schema conformance check in run-doctor.sh
- Gate verdict protocol (PASS/BLOCK/WARN/NEEDS_REVIEW) for hook responses
- Provider abstraction convention (documented interface for execution providers)
- Provider conformance check in run-doctor.sh
- Conformance test kit expansion (constitution v2.0 compliance checking, recipe validation, event emission verification)

### Out of Scope

- Actual Conversus integration (M006+)
- Building a Conversus gate hook script (M006+)
- Multi-provider dispatch within a single phase (orchestrator dispatches one task at a time)
- Token-accurate counting (remains chars/4 heuristic; provider-reported tokens improve cost_source accuracy)
- Migrating all existing agent instructions to new schema (progressive, not big-bang)
