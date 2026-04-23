---
schema_version: "1.0"
type: feature-spec
feature_slug: amend-seed
created_at: 2026-04-22
milestone: M014
---

# Feature Specification: Amend Seed

## Summary

This seed spec exercises the FR-14 amend three-case semantics: case (a) new-section insertion,
case (b) within-section append, and case (c) in-place placeholder replacement.

## User Stories

- **US-1** As an operator, I can amend a seed spec with new bracketed requirements.
- **US-2** As an orchestrator, I can round-trip an amend operation without breaking byte shape.

## Functional Requirements

- **FR-1** The amend command accepts a single `<path>` positional argument.
- **FR-2** The amend command honors `--yes` and `--dry-run` flags.
- **FR-3** The amend command preserves bytes outside the edited region (SC-6a invariant).

## Acceptance Criteria

- **AC-1** Running `specify.sh --amend <seed>` with `--dry-run` emits exactly one FR-19 manifest record.
- **AC-2** Running `specify.sh --amend <seed>` with `--yes` writes a unit_close JSONL record.

## Constraints

- **CON-1** Bash 3.2 compatibility.
- **CON-2** Claude Code only for LLM round-trip.

## Non-Goals

- **NG-1** Full decomposition (that's `split`).

<TODO: fill in rationale for case (c) placeholder semantics>
<TODO: document byte-shape invariant boundary>
