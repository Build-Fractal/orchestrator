# Knowledge

## K001: Project-wide Convention A [project]

All scripts must use structured output prefixes (PASS/FAIL/WARN/SKIP).

## K002: Project-wide Convention B [project]

Configuration follows 4-layer resolution: defaults < project < local < env.

## K003: Project-wide Convention C [project]

File-based state machine — all state derived from disk artifacts, never cached.

## K004: M001 Milestone Pattern [milestone:M001]

M001 uses Tier C orchestration with full phase decomposition and boundary maps.

## K005: M001 Context Budget [milestone:M001]

M001 dispatch payloads target < 15% context budget to leave room for agent reasoning.

## K006: M001 Verification Strategy [milestone:M001]

M001 uses all 4 verification tiers including human review gates for critical phases.

## K007: M002 Different Approach [milestone:M002]

M002 uses Tier B orchestration — simpler, sequential phases, no boundary maps required.

## K008: M002 Timeline [milestone:M002]

M002 targets completion by end of Q2 2026 with 3 phases.

## K009: M002 Testing Strategy [milestone:M002]

M002 will use integration tests only, no unit tests for scripts.

## K010: P03 Specific Validation [phase:M001/P03]

Phase P03 uses a specialized cross-milestone reference check not used in other phases.

## K011: P03 Boundary Edge Case [phase:M001/P03]

P03 boundary map includes produces items that span two directories.

## K012: P03 Risk Mitigation [phase:M001/P03]

P03 is classified high-risk due to cross-phase dependency complexity.
