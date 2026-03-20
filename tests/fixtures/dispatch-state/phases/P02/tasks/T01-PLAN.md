---
task: T01
phase: P02
milestone: M001
---

# T01: Implement dispatch scripts

## Description

Build the dispatch scripts that assemble context payloads for task execution.

## Steps

1. Implement scope-filter.sh
2. Implement detect-capabilities.sh
3. Implement build-context.sh

## Must-Haves

- scope-filter.sh filters knowledge and decisions by scope
- detect-capabilities.sh reports runtime capabilities
- build-context.sh assembles complete dispatch payload

## Verification

- All scripts exit 0 on valid input
- All scripts exit non-zero on missing arguments
