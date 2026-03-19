# Review Summary — Iteration 1

## Process
- 3 tools (APM, spec-kit, gh-aw) each produced a UTILIZATION.md reviewing the speckit-orchestrator spec
- 6 cross-reviews identified dangerous contradictions between tool recommendations
- 3 synthesis documents (UTILIZATION.reviewed.md) captured each tool's revised position

## Original Recommendation Counts
| Tool | Original Recs | Withdrawn | Modified | Surviving |
|------|--------------|-----------|----------|-----------|
| APM | 9 | 3 (recs 1,5,9) | 3 (recs 2,3,6) | 3 (recs 4,7,8) |
| spec-kit | 10 | 3 (recs 2,3,4) | 4 (recs 1,6,8,9) | 3 (recs 5,7,10) |
| gh-aw | 10 | 0 | 5 (recs 1,2,3,5,6) | 5 (recs 4,7,8,9,10) |

## Dangerous Contradictions Identified (18 total across 6 cross-reviews)

| Reviewer | Reviewed | Dangerous | Tensions | Safe |
|----------|----------|-----------|----------|------|
| APM on spec-kit | 3 | 4 | 3 |
| APM on gh-aw | 3 | 3 | 4 |
| spec-kit on APM | 3 | 5 | 1 |
| spec-kit on gh-aw | 3 | 4 | 3 |
| gh-aw on APM | 3 | 4 | 2 |
| gh-aw on spec-kit | 2 | 4 | 4 |

## 3 Systemic Contradictions Identified

### 1. State Location
- spec-kit: `.specify/extensions/orchestrator/`
- APM: `.apm/context/` (or mirrored there)
- gh-aw: `cache-memory` / `repo-memory` (off-tree in CI)

### 2. Context Injection Model
- APM: `apm compile` with `applyTo` patterns (static, build-time)
- spec-kit: companion presets overriding core commands (template-time)
- gh-aw: JSON payloads via `dispatch-workflow` / `cache-memory` (runtime, per-dispatch)

### 3. Dynamic vs Static Dispatch
- APM assumes compilation can vary per dispatch
- spec-kit assumes a persistent workspace
- gh-aw assumes orchestrator state lives in its memory tools

## Key Concessions Made

### APM acknowledged:
- Build-time compilation model doesn't belong in dynamic dispatch loop
- Value is at distribution + static context, not runtime orchestration
- Withdrew recs 1, 5, 9 (dispatch payloads, applyTo scoping, mirror into .apm/)

### spec-kit acknowledged:
- Evaluating purely from one tool's lens makes orchestrator less accessible
- Most prescriptive recs (config format, state dirs, preset overrides) were unanimously rejected
- Withdrew recs 2, 3, 4

### gh-aw acknowledged:
- CI-native bias kept pulling state off the working tree
- Primitives belong behind adapter layers, not at architectural core
- Modified 5 recs to position gh-aw as transport/adapter, not canonical storage

## Emerging Consensus (not yet formally locked)
1. Working tree is canonical for all artifacts
2. spec-kit owns extension lifecycle and config
3. APM handles build-time context optimization as secondary consumer
4. gh-aw provides CI durability/transport layer
5. Each tool's primitives live behind adapter interfaces
