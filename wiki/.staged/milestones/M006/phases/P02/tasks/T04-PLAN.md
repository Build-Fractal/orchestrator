---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M006"
name: "Create references/hooks.md — hook lifecycle and verdict protocol"
depends_on: []
---

## Prerequisites

- Access to the full codebase at the project root.
- No prior tasks required — T04 is independent.

## Description

Create a new reference document at `references/hooks.md` that documents
the hook lifecycle system, the verdict protocol, snapshot isolation, and
provides a walkthrough for writing a custom hook. A developer reading this
document should understand how to write, configure, and debug hooks without
reading source code.

The document must follow existing `references/` conventions (DC-1):
progressive disclosure statement, `## Overview` immediately after title,
`##`/`###` structure, ASCII diagrams where helpful, no inline HTML. It
must declare an audience label (DC-2) of `extenders, contributors`. All
cross-links must use relative paths (DC-3).

## Steps

### Step 1 — Read source scripts to map hook behavior

Read the following scripts:

- `scripts/lib/hooks.sh` — the hook lifecycle dispatcher. Note:
  - `run_hooks <lifecycle_point> <state_source> [hooks_yaml_path]` — main entry
  - Lifecycle points (line 148-154): PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE
  - Graceful degradation (lines 156-164): missing recipe-parser → SAFETY_WARNING + return 0;
    missing hooks.yaml → SAFETY_WARNING + return 0
  - Hook discovery (lines 166-173): parse_recipe_hooks from hooks.yaml
  - Hook enable/disable (lines 185-187): enabled field check
  - Snapshot creation (lines 49-61): _hooks_snapshot_create, chmod 444
  - Snapshot tampering detection (lines 63-71): _hooks_snapshot_unchanged (mtime + writable check)
  - HOOK_VIOLATION (lines 211-214): emitted when snapshot modified, never overridable
  - Timeout execution (lines 120-141): _hooks_exec_with_timeout, TERM then KILL
  - Verdict extraction (lines 87-118): _hooks_extract_verdict, most-severe-wins
  - Verdict handling (lines 228-247): BLOCK → blocked or force-downgrade, WARN → warning,
    PASS/NEEDS_REVIEW → complete
  - Exit code handling (lines 250-267): non-zero + block_on_fail → blocked or force-downgrade
  - ORCH_HOOK_SNAPSHOT env var: path to frozen snapshot passed to hook scripts

- `scripts/lib/verdicts.sh` — the verdict protocol. Note:
  - Verdict constants (lines 23-26): PASS, BLOCK, WARN, NEEDS_REVIEW
  - `orch_is_verdict` (lines 37-44): validation
  - `emit_verdict <verdict> <reason>` (lines 67-83): VERDICT: line format
  - `parse_verdict <line>` (lines 93-127): parses VERDICT: lines
  - Verdict line format: `VERDICT:<verdict> reason=<quoted_or_unquoted>`
  - Invalid verdict: downgrades to WARN with reason wrapping

- `templates/hooks.yaml` — the default hook configuration. Note:
  - hook_defaults: timeout (30), block_on_fail (true)
  - PRE_DISPATCH: payload_sanity, budget_precheck
  - POST_DISPATCH: output_sanity
  - POST_VERIFY: phase_completeness (block_on_fail: false)
  - PRE_ADVANCE: budget_enforcement, knowledge_trigger (enabled: false)
  - Each hook has: name, script, enabled, block_on_fail, description

- `scripts/engine/run.sh` — how the engine calls hooks:
  - PRE_DISPATCH (line 218): inside task loop, before build
  - POST_VERIFY (line 354): after verify, before record
  - POST_DISPATCH (line 376): after record, warn-only on failure
  - PRE_ADVANCE (line 403): after task loop, before phase completion

### Step 2 — Write `references/hooks.md`

Create the file with the following structure:

```markdown
# Hook Reference

> Progressive disclosure reference for the speckit-orchestrator hook system.
> Self-contained — read this document to understand hook lifecycle, the
> verdict protocol, snapshot isolation, and how to write custom hooks
> without reading source code.

> Audience: extenders, contributors

## Overview

[2-3 paragraph summary: what hooks are, why they exist, key design
 principles (isolation, frozen snapshots, verdict-based gating)]

---

## Lifecycle Points

[ASCII diagram of the 4 lifecycle points in the pipeline]

### PRE_DISPATCH
[When: after context build, before dispatch]
[Purpose: payload validation, budget check, external gates]
[Blocking behavior: blocks the current task]

### POST_DISPATCH
[When: after dispatch, before verification — NOTE: in engine, POST_DISPATCH
 actually fires AFTER record-result, not before verify]
[Purpose: output validation, response quality]
[Blocking behavior: warn-only in engine (does not block)]

### POST_VERIFY
[When: after verification, before result recording]
[Purpose: phase completeness, summary quality]
[Blocking behavior: blocks the current task]

### PRE_ADVANCE
[When: after all tasks complete, before phase advance]
[Purpose: final budget enforcement, knowledge consolidation]
[Blocking behavior: blocks phase completion (exit 6)]

---

## run_hooks Function

### Signature
[run_hooks <lifecycle_point> <state_source> [hooks_yaml_path]]

### Parameters
[lifecycle_point: PRE_DISPATCH|POST_DISPATCH|POST_VERIFY|PRE_ADVANCE]
[state_source: phase directory path for snapshot]
[hooks_yaml_path: defaults to templates/hooks.yaml]

### Return Value
[0 if all hooks pass, non-zero if any hook blocks]

---

## hooks.yaml Format

[Link to file-formats.md for full schema]
[Brief summary: lifecycle_point → hook_key → fields]
[Fields: name, script, enabled, block_on_fail, description]
[hook_defaults section for global timeout and block_on_fail]
[Override: place hooks.yaml in milestone or phase directory]

---

## Snapshot Isolation

[chmod 444 frozen state snapshot]
[$ORCH_HOOK_SNAPSHOT environment variable]
[Tampering detection: mtime comparison + writable check]
[HOOK_VIOLATION event on modification — never overridable, even with --force]
[Principle XII: Hook Isolation]

---

## Verdict Protocol

### Verdict Set
[PASS, BLOCK, WARN, NEEDS_REVIEW]

### emit_verdict
[emit_verdict <verdict> <reason>]
[VERDICT: line format: VERDICT:<verdict> reason=<value>]
[Invalid verdict: downgrades to WARN]

### parse_verdict
[parse_verdict <line>]
[Returns: tab-separated verdict and reason]

### Severity Ranking
[PASS (0) < WARN (1) < NEEDS_REVIEW (2) < BLOCK (3)]
[Most severe verdict wins when multiple VERDICT: lines present]

### Verdict Handling in run_hooks
[BLOCK: blocked (or force-downgraded to warning)]
[WARN: warning event, continues]
[PASS: complete event]
[NEEDS_REVIEW: complete event]

---

## Timeout Behavior

[Default: 30 seconds (configurable via ORCH_HOOK_TIMEOUT_SEC or hook_defaults)]
[SIGTERM after timeout, SIGKILL after SIGTERM+1s]
[Non-zero exit treated as hook failure]

---

## Force Override

[--force / ORCH_FORCE downgrades BLOCK verdicts to warnings]
[--force / ORCH_FORCE downgrades exit-code blocks to warnings]
[HOOK_VIOLATION is NEVER overridable — snapshot tampering always blocks]

---

## Graceful Degradation

[Missing recipe-parser.sh: SAFETY_WARNING, return 0]
[Missing hooks.yaml: SAFETY_WARNING, return 0]
[Missing hook script: SAFETY_WARNING, skip hook, continue]
[Snapshot creation failure: HOOK_BLOCKED event, overall_rc=1]

---

## Writing a Custom Hook

### Step 1: Create the hook script
[Basic script template with emit_verdict]

### Step 2: Register in hooks.yaml
[Add entry under lifecycle point with fields]

### Step 3: Testing
[How to test with --dry-run]
[How to verify snapshot isolation]

---

## Cross-References

[Links to engine.md, events.md, file-formats.md]
```

### Step 3 — Verify hook behavior against documentation

For each documented behavior:
- Verify the lifecycle point order by reading `scripts/engine/run.sh`.
- Verify the verdict handling by reading `scripts/lib/hooks.sh` lines 228-267.
- Verify timeout behavior by reading `_hooks_exec_with_timeout`.
- Verify snapshot isolation by reading `_hooks_snapshot_create` and
  `_hooks_snapshot_unchanged`.
- Note: POST_DISPATCH in the engine fires AFTER record-result (line 376),
  not before verification. Document this accurately.

### Step 4 — Add cross-links

Insert relative-path links to:
- `engine.md` — where hooks fire in the pipeline
- `events.md` — hook-related event types (HOOK_START, HOOK_COMPLETE, etc.)
- `file-formats.md` — hooks.yaml schema

## Must-Haves

- [ ] `references/hooks.md` exists and is >= 150 lines
- [ ] Opens with progressive disclosure statement and audience label
- [ ] Documents all 4 lifecycle points: PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE
- [ ] Documents run_hooks function signature and parameters
- [ ] Documents snapshot isolation: chmod 444, ORCH_HOOK_SNAPSHOT, tampering detection
- [ ] Documents verdict protocol: PASS, BLOCK, WARN, NEEDS_REVIEW
- [ ] Documents emit_verdict and parse_verdict functions
- [ ] Documents timeout behavior (default 30s, SIGTERM/SIGKILL)
- [ ] Documents force override behavior and HOOK_VIOLATION exception
- [ ] Documents graceful degradation (missing parser, missing YAML, missing script)
- [ ] Includes a walkthrough for writing a custom hook
- [ ] Cross-links to engine.md, events.md, file-formats.md using relative paths

## Verification

After writing the file, confirm:

```
test -f references/hooks.md
test "$(wc -l < references/hooks.md | tr -d ' ')" -ge 150
grep -q "## Overview" references/hooks.md
grep -qi "Audience:" references/hooks.md
grep -q "PRE_DISPATCH" references/hooks.md
grep -q "POST_DISPATCH" references/hooks.md
grep -q "POST_VERIFY" references/hooks.md
grep -q "PRE_ADVANCE" references/hooks.md
grep -q "VERDICT:" references/hooks.md
grep -q "snapshot" references/hooks.md
grep -q "HOOK_VIOLATION" references/hooks.md
grep -q "emit_verdict" references/hooks.md
grep -q "engine.md" references/hooks.md
grep -q "events.md" references/hooks.md
grep -q "file-formats.md" references/hooks.md
```

All must pass.

## Inputs

### From Previous Tasks

None — T04 is independent.

### From Disk (Pre-existing)

- `scripts/lib/hooks.sh` — hook lifecycle dispatcher (primary source)
- `scripts/lib/verdicts.sh` — verdict protocol (primary source)
- `templates/hooks.yaml` — default hook configuration
- `scripts/engine/run.sh` — engine hook call sites
- `scripts/lib/run-context.sh` — orch_is_forced for force-override context
- `references/file-formats.md` — cross-link target for hooks.yaml format

## Constraints

- **DC-1**: Progressive disclosure format, `## Overview`, `##`/`###`, ASCII diagrams, no HTML.
- **DC-2**: Audience label: `extenders, contributors`.
- **DC-3**: All cross-links use relative paths from `references/` directory.
- **DC-4**: Verify-as-you-write — every documented behavior confirmed by reading source.
- **DC-5**: Any bug fix commit references `references/hooks.md`.
- **DC-6**: Bash 3.2 / POSIX compatibility for any code fixes.

## Expected Output

After completing this task:

1. `references/hooks.md` exists with 150+ lines.
2. All 4 lifecycle points, verdict protocol, snapshot isolation, timeout, and
   graceful degradation are documented.
3. A custom hook walkthrough is included.
4. Cross-links to engine.md, events.md, file-formats.md are present.
5. If any hook behavior diverges from the documented protocol, each fix
   is committed referencing this doc.
