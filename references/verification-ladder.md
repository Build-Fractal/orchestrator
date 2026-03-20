# Verification Ladder Reference

> Progressive disclosure reference for the speckit-orchestrator verification protocol.
> Self-contained — read this document to understand how verification works at every level without cross-referencing the spec.

## Overview

The orchestrator uses a **4-tier verification ladder** that applies progressively more rigorous checks as confidence requirements increase. Each tier builds on the previous one. Verification is **runtime-agnostic and protocol-defined** — the ladder specifies *what* to check at each level, while the project's configuration determines *how* checks execute.

Verification runs at two boundaries:
1. **Per-task**: After each task dispatch completes (tiers 1–2)
2. **Per-phase**: After all tasks in a phase pass verification (tiers 1–4)

Results are recorded in summary frontmatter (`verification_result` field) and in the execution log (`execution-log.jsonl`).

---

## Tier 1 — Static Checks

**What it checks**: File existence, minimum line counts, and content pattern matching using grep-based inspection. No compilation, no runtime, no external dependencies.

**When it runs**: Always. Every task and phase verification starts with Tier 1. This tier has zero external requirements — it works on any system with a POSIX shell.

**Examples**:
- File exists: `[ -f scripts/state/derive-phase.sh ]`
- Minimum content: `[ $(wc -l < scripts/state/derive-phase.sh) -ge 40 ]`
- Content pattern: `grep -q 'pre-planning' scripts/state/derive-phase.sh`
- Export present: `grep -q 'derive_phase' scripts/state/derive-phase.sh`

**Configured via**: Must-haves in the phase plan — `artifacts` (file paths with `min_lines` and `contains` checks) and `key_links` (cross-file references).

**Failure behavior**: If any Tier 1 check fails, the task/phase is marked `fail`. No higher tiers run. The specific missing file or pattern is reported.

---

## Tier 2 — Command Execution

**What it checks**: Runs configured verification commands from `orchestrator-config.yml` — typically project test suites, linters, type checkers, or build commands.

**When it runs**: When `verification_commands` are configured in `orchestrator-config.yml`. Skipped if no commands are configured.

**Examples**:
```yaml
# orchestrator-config.yml
verification_commands:
  - npm test
  - npm run lint
  - npm run typecheck
```

**Requires**: Project runtime environment (Node.js, Python, etc.) must be available. Dependencies must be installed.

**Configured via**: `verification_commands` in `orchestrator-config.yml`. Commands run in the project root directory.

**Failure behavior**: Each command runs independently. If any command exits non-zero, the task/phase is marked `fail`. The specific command and its stderr/stdout are captured in the verification report.

**Per-task vs per-phase**: The same commands run at both boundaries. Per-task catches regressions early. Per-phase confirms the integrated result.

---

## Tier 3 — Behavioral Verification

**What it checks**: Integration tests, end-to-end checks, and runtime behavior validation. Tests that the system *works correctly* as a whole, not just that files exist and individual tests pass.

**When it runs**: For phases with behavioral must-haves — observable truths that require a running system to verify. Typically runs at phase boundaries, not per-task.

**Examples**:
- Integration test: Start the server, make API calls, verify responses
- End-to-end flow: Run the CLI command and verify its output matches expected format
- Runtime behavior: Dispatch a task and verify the summary file is produced correctly
- Cross-phase integration: Verify Phase 2's scripts correctly read Phase 1's output files

**Requires**: Running services, databases, or other infrastructure that the feature under test depends on.

**Configured via**: Must-haves `truths` in the phase plan — observable behaviors that must be true when the phase is done. The orchestrator generates behavioral verification steps from these truths.

**Failure behavior**: Behavioral failures at the phase boundary trigger the two-stage review (spec compliance first, then code quality). If the system is not behaving correctly, spec compliance review determines whether the implementation matches the spec before attempting fixes.

---

## Tier 4 — Human/UAT Review

**What it checks**: Manual review items that cannot be verified mechanically. Design quality, user experience, edge cases that require human judgment, and stakeholder acceptance.

**When it runs**: At milestone boundaries, or when automated verification is insufficient for specific must-haves. Always runs at the end of Tier C milestones during the `validating` state.

**Examples**:
- UX review: "Does the dashboard feel responsive and intuitive?"
- Design review: "Does the output format match the team's expectations?"
- Edge case review: "Test with a milestone that has 10 phases and verify performance"
- Stakeholder acceptance: "Demonstrate the autonomous dispatch flow end-to-end"

**Requires**: A human reviewer. The orchestrator flags items for review and blocks progression until the developer confirms.

**Configured via**: Phase plan must-haves that are explicitly marked for human review, or automatically triggered at milestone boundaries (Tier C `validating` state).

**Failure behavior**: Human review items are recorded as `pending` in the verification report. The orchestrator does not auto-advance past human review gates. The developer must explicitly mark items as `pass` or `fail`.

---

## Verification Execution Flow

### Per-Task Verification

```
Task completes
  → Tier 1: Static checks (file existence, content patterns)
  → Tier 2: Command execution (npm test, lint, etc.)
  → All pass? → Task summary written with verification_result: pass
  → Any fail? → Task marked failed, specific check reported
```

### Per-Phase Verification

```
All tasks in phase pass per-task verification
  → Tier 1: Static checks (all phase artifacts)
  → Tier 2: Command execution (full test suite)
  → Tier 3: Behavioral verification (integration/e2e)
  → Tier 4: Human review (if required by must-haves or milestone boundary)
  → Spec compliance review (FR-015)
  → Code quality review (FR-015)
  → All pass? → Phase summary written with verification_result: pass
  → Any fail? → Phase blocked, specific tier and check reported
```

---

## Recording Verification Results

### In Summary Frontmatter

Every task, phase, and milestone summary includes a `verification_result` field:

```yaml
verification_result: pass    # pass | fail | partial
```

- `pass` — All applicable tiers passed
- `fail` — One or more tiers failed
- `partial` — Some tiers passed, others were skipped or pending human review

### In Execution Log

Verification entries in `execution-log.jsonl` record detailed per-tier results:

```json
{
  "timestamp": "2026-03-19T15:00:00Z",
  "unitId": "M001/P01",
  "unitType": "verify-phase",
  "tier": "C",
  "duration": "30s",
  "outcome": "success",
  "verification": {
    "tier1_static": {"status": "pass", "checks": 5, "failures": 0},
    "tier2_command": {"status": "pass", "checklist": "P01-must-haves"},
    "tier3_behavioral": {"status": "skipped"},
    "tier4_human": {"status": "skipped"}
  }
}
```

Each tier reports: `pass`, `fail`, or `skipped`. Failed tiers include the specific check that failed.

---

## Tier Applicability by Orchestration Tier

| Verification Tier | Tier B | Tier C |
|-------------------|--------|--------|
| Tier 1 — Static Checks | ✅ Always | ✅ Always |
| Tier 2 — Command Execution | ✅ When configured | ✅ When configured |
| Tier 3 — Behavioral | ✅ When must-haves require it | ✅ When must-haves require it |
| Tier 4 — Human/UAT | ❌ Developer-driven | ✅ At milestone boundaries |

Tier A does not use the orchestrator verification ladder — standard spec-kit verification applies.
