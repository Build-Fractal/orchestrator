---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P05"
milestone: "M006"
name: "Update scripts/AGENTS.md — coding conventions, testing patterns, checklists"
depends_on: []
---

## Prerequisites

- Access to the full codebase at the project root.
- P01 reference doc exists: `references/architecture.md`.
- No prior tasks required — T01 is independent.

## Description

Rewrite the existing `scripts/AGENTS.md` from its current directory-listing
format (48 lines) into a comprehensive contributor guide. The audience is
"contributors" (DC-2). The document serves as the entry point for anyone
modifying scripts in this extension and must be self-contained enough to
onboard a developer without reading source code.

The guide must follow progressive disclosure (DC-1): title, disclosure
statement, audience label, `## Overview`, then sections from conventions to
checklists. All cross-links use relative paths (DC-3). Every documented
pattern must be verified against real codebase examples (DC-4).

## Steps

### Step 1 — Read source materials for accuracy

Read the following to ensure all documented conventions are real:

- `scripts/AGENTS.md` — current content (to preserve useful structure)
- `.specify/memory/constitution.md` — all 13 principles for compliance checklist
- `ANTIPATTERNS.md` — 3 registered antipatterns (AP-001, AP-002, AP-003)
- `tests/AGENTS.md` — existing test conventions
- `references/architecture.md` — subsystem map, file layout
- `scripts/lib/events.sh` — emit_event signature and event type registry
- `scripts/lib/errors.sh` — emit_result signature and error taxonomy
- `scripts/lib/hooks.sh` — hook lifecycle patterns
- `scripts/lib/run-context.sh` — run context initialization pattern
- 2-3 scripts from `scripts/lifecycle/` and `scripts/knowledge/` — verify
  double-sourcing guard pattern, set -eu usage, structured output format
- `tests/test-s01-structure.sh` — test suite pattern reference

### Step 2 — Write the updated `scripts/AGENTS.md`

Rewrite the file with this structure:

```markdown
# Contributor Guide — scripts/

> Progressive disclosure reference for contributing to speckit-orchestrator scripts.
> Self-contained — read this document to understand coding conventions, testing
> patterns, and compliance requirements without reading source code.

> Audience: contributors

## Overview

[What these scripts do, how they're organized, entry points for new
contributors. Brief subsystem map referencing architecture.md.]

---

## Directory Layout

[Updated directory listing from the current AGENTS.md, keeping the organized
structure but updating to reflect current file count and subsystem names.]

---

## Coding Conventions

### Bash 3.2 Compatibility

[Explain NFR-200. Prohibited constructs: declare -A (associative arrays),
process substitution as redirect target (done < <(...)), nameref (declare -n).
Allowed alternatives: parallel indexed arrays, temp-file pattern, pipe pattern.
Reference AP-001.]

### Portable sed In-Place Editing

[Explain the sed_i helper pattern. Reference AP-002. Show the helper function
and explain when to use it.]

### Double-Sourcing Guards

[Explain NFR-203 / AP-003. Show the guard pattern:
  [ -n "${_LIBNAME_SOURCED:-}" ] && return 0
  _LIBNAME_SOURCED=1
Every sourced library file must include this. LIBNAME derived from filename.]

### Structured Output Protocol

[Explain: scripts emit prefixed lines to stdout (PASS:, FAIL:, LOCK:, EVENT:,
RESULT:). Errors to stderr. Exit 0 success, 1 failure.]

### Event Emission

[Explain: engine-managed scripts source scripts/lib/events.sh and call
emit_event <TYPE> [key=value ...]. List the canonical event types. Reference
Principle II.]

### Result Protocol

[Explain: scripts source scripts/lib/errors.sh and call emit_result <status>
[error_kind] [detail] as the final output. A script without a RESULT line is
a silent failure. List the 6 error kinds.]

### Atomic Writes

[Explain: state changes must be atomic. Pattern: write to temp file, then
mv to final location. Never leave partial state on disk. Reference
Principle VI.]

### Extension Registration

[Every script must be registered in extension.yml under provides.scripts
with executable: true.]

---

## Testing Patterns

### Suite Structure

[Explain: 8 test suites in tests/, numbered test-s01 through test-s08.
Each suite is standalone. Fixtures in tests/fixtures/.]

### pass()/fail() Functions

[Show the pass/fail pattern with parallel indexed arrays (Bash 3.2 compatible).
Structured PASS:/FAIL: output with summary count. Exit 0 = all pass, exit 1 =
any failure.]

### Fixture Conventions

[Named by scenario (state-*, verify-*, dispatch-*, etc.). Minimal file trees
that trigger specific states. Reference tests/AGENTS.md for details.]

### Verification Scripts

[M006 verification scripts pattern: scripts/verify/m006-p##-*.sh. Single-file
invocation (AD-19), set -eu, file existence check, grep patterns, PASS/FAIL
output.]

---

## Constitution v2.0 Compliance Checklist

[Bulleted checklist — one item per principle (I-XIII). Each item states what
the principle requires in the context of script development. This is a quick-
reference checklist; for full examples see constitution-walkthrough.md.]

---

## PR Review Checklist

[Numbered checklist for reviewing script PRs:
1. Bash 3.2 compatibility (no declare -A, no process substitution redirects)
2. Double-sourcing guards on all library files
3. Structured output (PASS/FAIL/EVENT/RESULT prefixes)
4. Event emission for engine-managed scripts
5. Result protocol compliance
6. Atomic writes for state changes
7. Extension registration in extension.yml
8. Tests added/updated
9. Constitution compliance (reference specific principles)
10. No dead infrastructure (Principle VIII)
11. Cross-links use relative paths]

---

## Anti-Patterns

[Reference ANTIPATTERNS.md and summarize the 3 registered antipatterns:
AP-001 (platform-specific Bash syntax), AP-002 (non-portable sed -i),
AP-003 (missing double-sourcing guards). For each: one-line summary,
remedy, and link to the full entry.]

---

## Cross-References

[Links to:
- references/constitution-walkthrough.md (full principle walkthrough)
- references/architecture.md (system architecture)
- ANTIPATTERNS.md (antipattern register)
- tests/AGENTS.md (test conventions)]
```

### Step 3 — Verify-as-you-write (DC-4)

For every convention documented:
- Confirm at least one real script in the codebase follows the pattern.
- Cite the file path as an inline example.

For every anti-pattern referenced:
- Confirm the ANTIPATTERNS.md entry ID exists.

For every cross-link:
- Confirm the target file exists relative to `scripts/`.

### Step 4 — Check for convention violations

While documenting each convention, scan 3-5 scripts to verify they follow
the pattern. If any violations are found:
- Fix the violation in the offending script.
- Commit the fix with a message referencing `(found via scripts/AGENTS.md)` per DC-5.
- Note the fix in the AGENTS.md anti-patterns section or inline.

## Must-Haves

- [ ] `scripts/AGENTS.md` exists and is 250+ lines
- [ ] File opens with progressive disclosure statement and audience label "contributors"
- [ ] Contains `## Overview` section
- [ ] Documents Bash 3.2 compatibility (mentions `declare -A`, process substitution, AP-001)
- [ ] Documents double-sourcing guards (shows guard pattern, mentions AP-003)
- [ ] Documents event emission (mentions `emit_event`, lists event types)
- [ ] Documents result protocol (mentions `emit_result`, lists error kinds)
- [ ] Documents atomic writes pattern
- [ ] Documents testing patterns (mentions `pass()`, `fail()`, `PASS:`, `FAIL:`)
- [ ] Includes constitution v2.0 compliance checklist (all 13 principles)
- [ ] Includes PR review checklist (10+ items)
- [ ] References ANTIPATTERNS.md
- [ ] All cross-links use relative paths and resolve to existing files

## Verification

After writing the file, run:

```
bash scripts/verify/m006-p05-agents-header.sh
bash scripts/verify/m006-p05-agents-bash32.sh
bash scripts/verify/m006-p05-agents-guards.sh
bash scripts/verify/m006-p05-agents-events.sh
bash scripts/verify/m006-p05-agents-testing.sh
bash scripts/verify/m006-p05-agents-checklists.sh
```

All must exit 0. If verification scripts do not yet exist (T03 has not
run), verify manually by grepping the file for required patterns.

## Inputs

### From Previous Tasks

None — T01 is independent.

### From Disk (Pre-existing)

- `scripts/AGENTS.md` — current content (48 lines, directory listing format)
- `.specify/memory/constitution.md` — 13 principles, v2.0 (318 lines)
- `ANTIPATTERNS.md` — 3 registered antipatterns (83 lines)
- `tests/AGENTS.md` — test conventions (37 lines)
- `references/architecture.md` — subsystem map, file layout (378 lines)
- `scripts/lib/events.sh` — emit_event, event type registry
- `scripts/lib/errors.sh` — emit_result, error taxonomy
- `scripts/lib/hooks.sh` — hook lifecycle patterns
- `scripts/lib/run-context.sh` — run context initialization
- `scripts/lifecycle/*.sh` — example scripts for convention verification
- `scripts/knowledge/*.sh` — example scripts for convention verification
- `tests/test-s01-structure.sh` — test pattern reference

## Constraints

- **DC-1**: Progressive disclosure format — `## Overview` immediately after title,
  `##`/`###` structure, ASCII diagrams OK, no inline HTML.
- **DC-2**: Audience label: `contributors`.
- **DC-3**: All cross-links use relative paths from `scripts/` directory.
- **DC-4**: Verify-as-you-write — every convention confirmed against real code.
- **DC-5**: Bug fix commits reference `scripts/AGENTS.md`.
- **DC-6**: Bash 3.2 / POSIX compatibility for any code fixes.

## Expected Output

After completing this task:

1. `scripts/AGENTS.md` exists with 250+ lines.
2. The document covers coding conventions, testing patterns, compliance
   checklist, PR review checklist, and anti-patterns.
3. All conventions are verified against real codebase examples.
4. All cross-links resolve to existing files.
5. If any convention violations were found and fixed, each fix is committed
   with a message referencing `(found via scripts/AGENTS.md)`.
