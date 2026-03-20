---
phase: P02
milestone: M001
status: in_progress
---

# P02: Core Implementation

## Goal

Core dispatch pipeline works end-to-end.

## Demo

A developer can dispatch a task and see the correct context payload assembled.

## Must-Haves

### Truths
- Dispatch payload stays under 20% of total artifacts

### Artifacts
- `scripts/dispatch/build-context.sh` (min 50 lines)
- `scripts/dispatch/scope-filter.sh` (min 40 lines)

## Tasks

- [ ] T01: Implement dispatch scripts
