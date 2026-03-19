# Review Summary — Iteration 2

## Process
- 6 iteration_1 meta-reviews evaluated whether revised positions genuinely addressed concerns or just softened language
- 3 UTILIZATION.iteration_2.md documents captured cumulative positions
- Focus shifted from finding contradictions to evaluating quality of concessions

## Iteration 1 Meta-Review Findings

### Resolution Quality
| Reviewer | Reviewed | Fully Resolved | Partially Resolved | Unresolved |
|----------|----------|---------------|--------------------|-----------|
| APM on spec-kit | 2/3 | 0/3 | 1/3 |
| APM on gh-aw | 2/3 | 1/3 (moot — APM withdrew own rec) | 0/3 |
| spec-kit on APM | 2/3 | 1/3 | 0/3 |
| spec-kit on gh-aw | 2/3 | 1/3 | 0/3 |
| gh-aw on APM | 2/3 | 1/3 | 0/3 |
| gh-aw on spec-kit | 2/2 | 0/2 | 0/2 |

**Assessment**: 12 of 17 original dangerous contradictions fully resolved. 5 partially resolved (narrowed to coordination/timing). 0 unresolved.

## 10 Locked Consensus Points

| # | Agreement |
|---|-----------|
| 1 | Working tree is canonical for all agent-consumable artifacts |
| 2 | spec-kit config system is the single authority for orchestrator settings |
| 3 | Verification logic owned by the spec, not any single tool |
| 4 | Namespaced commands (`speckit.orchestrator.*`), not preset overrides |
| 5 | Single-directory state tree (not scattered across features) |
| 6 | P7 needs a full CI integration design section, not one paragraph |
| 7 | Single-job execution model is a real platform constraint in CI |
| 8 | APM hybrid package at P8 is the distribution integration point |
| 9 | TaskOps maps to Tier B's CI execution path |
| 10 | Dispatch goes behind an abstract interface, not coupled to any tool |

## 3 Remaining Disputes

### Dispute 1: State Path
`.specify/orchestrator/` vs `.specify/extensions/orchestrator/`
- **Nature**: Coordination (crossed-wires from iteration 1 — both tools moved toward each other and passed in transit)
- **spec-kit**: Offers either path; prefers `.specify/orchestrator/`
- **APM**: Needs a discoverable path; prefers convention alignment
- **gh-aw**: Needs a single predictable path for static cache keys

### Dispute 2: APM Discovery Timeline
When does APM get access to orchestrator artifacts?
- **APM**: Wants discovery from P1 (context management is core value)
- **spec-kit**: Proposes tiered — no APM P1-P6, compiler reads `.specify/` at P7, full integrator at P8
- **gh-aw**: Neutral; supports whatever doesn't add CI overhead

### Dispute 3: Pluggable Adapter Ownership
Who builds the storage adapter, and when?
- **Nature**: Organizational, derivative of Dispute 2
- **APM**: Proposes `SpeckitOrchestratorIntegrator` that reads from `.specify/` unilaterally
- **spec-kit**: Wants adapter deferred to P8
- **gh-aw**: Offers to contribute `cache-memory` adapter spec as its part

## Key Self-Assessments

### APM — "Lessons Learned"
- Build-time tools must not be prescribed for runtime problems
- Seeing every problem as an APM primitive problem is tunnel vision
- APM's value is distribution + static context layer

### spec-kit — "Lessons Learned"
- Evaluating purely from one tool's lens makes orchestrator less accessible
- Most prescriptive recommendations were rightly rejected
- Extension self-containment must coexist with multi-tool integration

### gh-aw — "Lessons Learned"
- CI-native bias needs checking against working-tree-first assumptions
- gh-aw primitives belong behind adapter layers
- Platform constraints (single-job) are facts, not philosophy
