# Knowledge Index
<!-- Generated artifact — rebuild with: bash scripts/knowledge/rebuild-index.sh -->
<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->
SPEC-AC-001 | [project] | spec/acceptance | 0.90 | 2026-04-17 | verified:2026-04-17 | hits:0 | Given a planned phase with ≥4 tasks, When `orchestrator:auto` runs to completion
SPEC-AC-002 | [project] | spec/acceptance | 0.90 | 2026-04-17 | verified:2026-04-17 | hits:0 | Given a dispatched subagent writes a task summary, When it calls `write-summary.
SPEC-AC-003 | [project] | spec/acceptance | 0.90 | 2026-04-17 | verified:2026-04-17 | hits:0 | Given a dispatched subagent runs a phase's verify suite, When it tallies results
SPEC-AC-004 | [project] | spec/acceptance | 0.90 | 2026-04-17 | verified:2026-04-17 | hits:0 | Given a project cloned fresh into a new workspace, When the developer runs `orch
SPEC-AC-005 | [project] | spec/acceptance | 0.90 | 2026-04-17 | verified:2026-04-17 | hits:0 | Given a script or template file containing `$(…)`, backticks, or `{…,…}` brace e
SPEC-AC-006 | [project] | spec/acceptance | 0.90 | 2026-04-17 | verified:2026-04-17 | hits:0 | Given a dispatch payload is built for a subagent, When the payload is rendered, 
SPEC-AC-007 | [project] | spec/acceptance | 0.90 | 2026-04-17 | verified:2026-04-17 | hits:0 | Given a contributor runs the project's pre-commit checks, When a staged file con
SPEC-AC-008 | [project] | spec/acceptance | 0.90 | 2026-04-17 | verified:2026-04-17 | hits:0 | Given a phase directory containing ≥3 `*.sh` gate scripts, When the developer ru
SPEC-AC-009 | [project] | spec/acceptance | 0.90 | 2026-04-17 | verified:2026-04-17 | hits:0 | Given all gate scripts pass, When the wrapper runs, Then it exits 0.
SPEC-AC-010 | [project] | spec/acceptance | 0.90 | 2026-04-17 | verified:2026-04-17 | hits:0 | Given any gate script fails, When the wrapper runs, Then it exits non-zero with 
SPEC-CON-001 | [project] | spec/constraint | 0.90 | 2026-04-17 | verified:2026-04-17 | hits:0 | Must ship before M009 launch so autonomy is a credible launch claim.
SPEC-CON-002 | [project] | spec/constraint | 0.90 | 2026-04-17 | verified:2026-04-17 | hits:0 | Must not break existing callers of `write-summary.sh` — `--completed_at=<ISO>` c
SPEC-CON-003 | [project] | spec/constraint | 0.90 | 2026-04-17 | verified:2026-04-17 | hits:0 | Must remain Bash 3.2 compatible (constitution principle VIII).
SPEC-CON-004 | [project] | spec/constraint | 0.90 | 2026-04-17 | verified:2026-04-17 | hits:0 | No `declare -A`, no speculative abstraction for other scripts that don't current
SPEC-NG-001 | [project] | spec/non-goal | 0.90 | 2026-04-17 | verified:2026-04-17 | hits:0 | Expanding autonomy to operations that legitimately warrant human review (credent
SPEC-NG-002 | [project] | spec/non-goal | 0.90 | 2026-04-17 | verified:2026-04-17 | hits:0 | Hardening against *user-invoked* slash commands outside `orchestrator:auto` — in
SPEC-NG-003 | [project] | spec/non-goal | 0.90 | 2026-04-17 | verified:2026-04-17 | hits:0 | Rewriting non-autonomous scripts (one-off diagnostics, migration tools run manua
SPEC-US-001 | [project] | spec/story | 0.90 | 2026-04-17 | verified:2026-04-17 | hits:0 | Full Phase Runs To Completion Without Prompts
SPEC-US-002 | [project] | spec/story | 0.90 | 2026-04-17 | verified:2026-04-17 | hits:0 | Anti-Pattern Guardrails Prevent Regression
SPEC-US-003 | [project] | spec/story | 0.90 | 2026-04-17 | verified:2026-04-17 | hits:0 | Verify Suites Run Via A Single Wrapper
MEM001 | [project] | patterns | 0.95 | 2026-04-14 | verified:2026-04-14 | hits:208 | Shell Script Conventions
MEM002 | [project] | patterns | 0.95 | 2026-04-14 | verified:2026-04-14 | hits:208 | Test Conventions
MEM003 | [project] | patterns | 0.95 | 2026-04-14 | verified:2026-04-14 | hits:208 | State Machine Design
MEM004 | [project], [milestone:M005] | patterns | 0.90 | 2026-04-14 | verified:2026-04-14 | hits:208 | Pure Lib Extraction Pattern
MEM005 | [project], [milestone:M005] | patterns | 0.90 | 2026-04-14 | verified:2026-04-14 | hits:179 | Content-Hash Idempotency
MEM006 | [project], [milestone:M005] | patterns | 0.90 | 2026-04-14 | verified:2026-04-14 | hits:179 | Scored Health Reporting
MEM007 | [project], [milestone:M005] | patterns | 0.90 | 2026-04-14 | verified:2026-04-14 | hits:179 | Autonomy Permission Pipeline
MEM008 | [project], [milestone:M001] | patterns | 0.85 | 2026-04-14 | verified:2026-04-14 | hits:208 | Audit Remediation Patterns
MEM009 | [project], [milestone:M006] | patterns | 0.90 | 2026-04-14 | verified:2026-04-14 | hits:179 | Documentation-as-Verification
MEM010 | [project], [milestone:M006] | patterns | 0.90 | 2026-04-14 | verified:2026-04-14 | hits:179 | Cross-Link Validation Scripts
MEM011 | [project], [milestone:M002] | patterns | 0.90 | 2026-04-14 | verified:2026-04-14 | hits:179 | Validation-as-Task Pattern
MEM012 | [project] | conventions | 0.95 | 2026-04-14 | verified:2026-04-14 | hits:208 | Command File Structure
MEM013 | [project] | conventions | 0.95 | 2026-04-14 | verified:2026-04-14 | hits:208 | Template Convention
MEM014 | [project] | conventions | 0.95 | 2026-04-14 | verified:2026-04-14 | hits:208 | Interface Contracts
MEM015 | [project], [milestone:M005] | conventions | 0.90 | 2026-04-14 | verified:2026-04-14 | hits:179 | DOCTOR Structured Output Protocol
MEM016 | [project], [milestone:M005] | conventions | 0.85 | 2026-04-14 | verified:2026-04-14 | hits:179 | Cost Source Closed Enum
MEM017 | [project], [milestone:M005] | conventions | 0.90 | 2026-04-14 | verified:2026-04-14 | hits:179 | Gate Verdict Protocol
MEM018 | [project] | conventions | 0.90 | 2026-04-14 | verified:2026-04-14 | hits:208 | Runtime Adapter Interface
MEM019 | [project], [milestone:M002] | conventions | 0.95 | 2026-04-14 | verified:2026-04-14 | hits:179 | Three-Temperature Knowledge Architecture
MEM020 | [project], [milestone:M002] | conventions | 0.95 | 2026-04-14 | verified:2026-04-14 | hits:179 | Dispatched Agents Must Write Summaries
MEM021 | [project] | lessons | 0.95 | 2026-04-14 | verified:2026-04-14 | hits:208 | PID 1 macOS kill -0 Behavior
MEM022 | [project] | lessons | 0.95 | 2026-04-14 | verified:2026-04-14 | hits:208 | Lock Manager PID Subshell Issue
MEM023 | [project], [milestone:M004] | lessons | 0.95 | 2026-04-14 | verified:2026-04-14 | hits:179 | Backtick-in-Plan-Artifacts Breaks Must-Have Checks
MEM024 | [project], [milestone:M004] | lessons | 0.95 | 2026-04-14 | verified:2026-04-14 | hits:179 | Lib Path Resolution in Task Plans
MEM025 | [project], [milestone:M004] | lessons | 0.95 | 2026-04-14 | verified:2026-04-14 | hits:179 | Verification Script Grep Patterns
