# Spec 005: Hardening & Integration Preparation

## Summary

Harden the M004 engine architecture with content-hash idempotency, cost transparency, pure transform extraction, agent instruction schema, and formalized gate verdict protocol — establishing the concrete integration seam for Conversus deliberation gates and future execution providers.

## Motivation

M004 delivers the engine, shared libraries, YAML recipes, and hook system. M005 refines these with patterns identified from Conversus (cost transparency, gate verdicts) and index-pipeline (content hashing, pure transforms, conformance testing) that didn't fit in M004's scope. These refinements are prerequisite to Conversus integration — the verdict protocol defines how gates communicate, the cost source tracking enables gate cost decisions, and the instruction schema ensures dispatched agent prompts are structurally consistent for analysis.

## Status

Spec stub — full user stories and functional requirements to be written during M005 discuss phase. Roadmap and context already drafted at `.specify/orchestrator/milestones/M005/`.

## Planned Scope

See `M005-ROADMAP.md` for phase breakdown:
- P01: Content-Hash Idempotency
- P02: Cost Transparency
- P03: Pure Transform Extraction
- P04: Agent Instruction Schema
- P05: Gate Verdict Protocol and Provider Convention
- P06: Conformance Test Kit Expansion
