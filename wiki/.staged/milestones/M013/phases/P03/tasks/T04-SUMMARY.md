---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P03"
milestone: "M013"
provides:
  - "references/github-integration.md P03 extensions (Full Mapping Table, Re-init Adoption Contract FR-14, Scope Boundary P03 column, TODO P04 relabel); commands/github-init.md --re-init addendum; scripts/verify/m013-p03-reference-extensions.sh gate"
requires:
  - "T02 (--re-init flag + adopted= footer settled); T03 (scripts/verify/graphql-call-shape.sh path settled); P02 github-integration.md + github-init.md authored artifacts"
affects:
  - "references/github-integration.md; commands/github-init.md; scripts/verify/m013-p03-reference-extensions.sh (new); scripts/verify/m013-p02-reference-extensions.sh (relaxed assertion-3)"
key_files:
  - "references/github-integration.md;commands/github-init.md;scripts/verify/m013-p03-reference-extensions.sh;scripts/verify/m013-p02-reference-extensions.sh"
key_decisions:
  - "Relaxed P02 reference-extensions gate assertion-3 to accept both pre-T04 and post-T04 mapping-table shapes rather than freezing P02 gate + duplicating hashes; kept sha256 byte-identity block on P01 sections untouched (load-bearing invariant preserved). Did NOT re-embed section sha256 hashes in new P03 gate (plan explicitly flagged this as acceptable — P02 gate is single source of byte-identity truth per AD-19)."
patterns_established:
  - "Gate-evolution-on-legitimate-advancement: when a later phase legitimately completes what an earlier phase scaffolded as 'deferred', the earlier phase's presence-of-deferral assertion evolves to accept both shapes rather than fracturing the suite; byte-identity hashes on content NOT being advanced stay pinned as the load-bearing invariant."
drill_down_paths:
  - "none"
duration: "40"
verification_result: "pass"
completed_at: "2026-04-22T00:58:03Z"
---

## What shipped

Documentation-only closing task for M013/P03. Filled the three partial-mapping-table rows that P02 scaffolded as `_deferred to P03_` with real projection content, renamed the heading to `### Full Mapping Table (P02 + P03)`, and carried the prose above/below the table from "partial — deferred" language to "now complete — P04 owns live transitions" framing.

Relabeled the three `### TODO P03:` stub headings (`sync` Workflow, Conversus Pre-Merge Gate, FR-17 Cost Emission) to `### TODO P04:` per D015 renumbering — the original bodies were authored at P01 pre-rename; content ownership always lived with P04.

Inserted a new `### Re-init Adoption Contract (FR-14)` subsection between the existing Dry-Run Manifest Format subsection and the first TODO P04 heading. The contract documents:

- Two trigger paths (explicit `--re-init`; implicit sidecar-absent + marker-bearing-remote detection).
- Per-orchestrator-id adoption algorithm grounded in the `gh_marker_search_remote` helper from T02 — unique-hit adopts, zero-hits falls through to create, duplicate-hits errors.
- Milestone and Project v2 adoption (title-match; the `projectsV2(first: 20)` GraphQL **query** is outside the FR-5 three-shape whitelist by design).
- Auto-mode safety (SC-7): re-init is operator-initiated only; runs AFTER the auto-mode short-circuit.
- Manifest footer extension: additive-optional `adopted=<A>` field when re-init fired; pure P02 create path footer stays 3-field byte-identical.
- FR-4 marker invariant on adoption: every adopted Issue's remote body is re-verified via `shasum_marker_byte_identity` on the read-back.

Updated the Scope Boundary table P03 column: replaced predictive "deferred/completed" language with past-tense "shipped" for the rows P03 delivered (Full mapping table, `init` workflow re-init adoption, Marker format `gh_marker_search_remote` helper); added a new `FR-5 GraphQL call-shape lint` row referencing `scripts/verify/graphql-call-shape.sh` from T03.

Extended `commands/github-init.md` with one new Core Workflow step (8) documenting `--re-init` adoption behavior and the additive-optional `adopted=<A>` footer field. The step names all current flags (`--dry-run`, `--i-am-operator`, `--strict-labels`, `--re-init`, `--root`, `--repo-slug`) so the command surface is discoverable. No other section of the command doc was touched.

## Byte-identity discipline

P01-authored sections (Overview, Sidecar Config Schema, Pending-Sentinel Semantics, `sync_mode` Enum, Marker Format, UAT Ingestion Contract, Knowledge-Layer Boundary, Further Reading) and the P02-authored byte-identity-hashed section blocks were NOT touched by T04. The P02 reference-extensions gate — which embeds sha256 hashes for those sections — remains green, proving the byte-identity discipline held.

The P02 gate's assertion-3 (mapping-table shape) was minimally relaxed to accept either the pre-T04 `### Partial Mapping Table` heading with 3 `_deferred to P03_` cells OR the post-T04 `### Full Mapping Table (P02 + P03)` heading with the canonical three bold rows (Spec chunk / Acceptance criterion / Verification status) populated. This was necessary: P02's original assertion was a "P02-must-leave-these-deferred" gate, but the P02 phase suite is run continuously; T04 legitimately completes what P02 scaffolded, so the gate had to evolve from "cells must be deferred" to "cells must be present + populated or deferred". The P01 byte-identity sha256 block remained unchanged.

## Gate authored

`scripts/verify/m013-p03-reference-extensions.sh` — 13 PASS lines. Asserts (1) no `_deferred to P03_` cells remain, (2) heading is `### Full Mapping Table (P02 + P03)`, (3a/b) zero `### TODO P03:` + exactly three `### TODO P04:` headings, (4) Re-init Adoption Contract subsection with `adopted=` + `gh_marker_search_remote` + `integration-marker-duplicate` anchors, (5) FR-5 lint row in Scope Boundary referencing `scripts/verify/graphql-call-shape.sh`, (6/7) P01+P02 byte-identity via the P02 reference-extensions gate still exiting 0 (AD-19 single-source — hashes embedded in one place), (8) `--re-init` present in `commands/github-init.md`.

## Decisions

- **P02 reference-extensions gate relaxation (rather than duplication).** T04 extended the P02 gate's assertion-3 to accept both pre-T04 and post-T04 mapping table shapes. Alternative was to keep the P02 gate frozen and let it fail, but that would break `m013-p02-phase-suite.sh` which T04 is required to keep 8/8 green. The sha256 byte-identity block on P01 sections — the actual load-bearing invariant — is untouched.

- **Byte-identity hashes NOT re-embedded in the new P03 gate.** The plan's Step 7 flagged this as acceptable: "the byte-identity section on sha256-hashing is intentionally left as a stub — the P02 gates already cover the byte-identity of the P01+P02 sections via their own embedded hashes, so relying on `m013-p02-reference-extensions.sh` green status is both load-bearing and non-redundant." Honored.

## Verification

- `bash scripts/verify/m013-p03-reference-extensions.sh` — 13/13 PASS.
- `bash scripts/verify/m013-p02-phase-suite.sh` — 8/8 PASS (including the P02 reference-extensions gate and the P02 github-init-command gate).
- `bash scripts/verify/graphql-call-shape.sh` — exit 0 (lint stable, unchanged).
- All prior P03 gates (T01/T02/T03) re-run green: `m013-p03-re-init-adoption.sh` 6/6, `m013-p03-github-common-readopt.sh` 5/5, `m013-p03-re-init-auto-mode.sh` 2/2, `m013-p03-re-init-fixture.sh` 14/14, `m013-p03-graphql-call-shape-selftest.sh` 5/5.

## Scope discipline

Knowledge-Layer Boundary (D014) respected: no `SPEC-*` schema changes, no `KNOWLEDGE-INDEX.md` touches, no `scripts/knowledge/rebuild-index.sh` modifications. FR-12 Claude-Code-only v1 — no multi-runtime doc sections were added. Additive-extension pattern preserved on `commands/github-init.md` (one numbered Core Workflow step appended; no deletions or rewrites of other sections).
