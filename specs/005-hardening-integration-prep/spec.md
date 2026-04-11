# Spec 005: Hardening & Integration Preparation

## Summary

Harden the M004 engine architecture with content-hash idempotency, cost transparency, pure transform extraction, agent instruction schema, formalized gate verdict protocol, and introspection-based autonomy permission generation — establishing the concrete integration seam for Conversus deliberation gates and future execution providers, and making Tier C auto mode genuinely unattended.

## Motivation

M004 delivers the engine, shared libraries, YAML recipes, and hook system. M005 refines these with patterns identified from Conversus (cost transparency, gate verdicts), index-pipeline (content hashing, pure transforms, conformance testing), and real-world Tier C usage (autonomy permission gaps that cause "Do you want to proceed?" prompts to interrupt unattended auto mode). These refinements are prerequisite to Conversus integration — the verdict protocol defines how gates communicate, the cost source tracking enables gate cost decisions, and the instruction schema ensures dispatched agent prompts are structurally consistent for analysis. The autonomy generator closes the gap between M001's autonomy promise and the developer experience of babysitting every bash command.

## Status

Spec stub — full user stories and functional requirements to be written during M005 discuss phase. Roadmap and context already drafted at `.specify/orchestrator/milestones/M005/`. Autonomy feature (FR-1 through FR-10) is split across: the MVP template shipped in commit `50f7098` (covers FR-3/FR-4/FR-5/FR-9, minus GSD patterns per AD-10), and P07 which implements the remaining FR-1/FR-2/FR-6/FR-7/FR-8/FR-10. Architectural decisions AD-7 through AD-18 in `M005-CONTEXT.md` capture the design rationale; the original feature prompt has been consumed and retired.

## Planned Scope

See `M005-ROADMAP.md` for phase breakdown:
- P01: Content-Hash Idempotency
- P02: Cost Transparency
- P03: Pure Transform Extraction
- P04: Agent Instruction Schema
- P05: Gate Verdict Protocol and Provider Convention
- P06: Conformance Test Kit Expansion
- P07: Autonomy Permission Generator
