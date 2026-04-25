---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M014"
name: "templates/spec-template.md Section Contract SSOT + templates/spec-scaffolder-prompt.md CC LLM prompt"
depends_on: []
---

## Prerequisites

No upstream task dependencies. Pre-existing disk state:

- `templates/` directory exists at repo root with existing templates (`phase-plan.md`, `task-plan.md`, etc.).
- `specs/023-github-native-integration/spec.md` is the most recent hand-authored spec and a reference for frontmatter + section ordering — read as a precedent, do not copy.
- `specs/024-spec-management-extended/spec.md` is the current milestone's own spec and the primary precedent for the Section Contract (it carries every section FR-2 mandates in the required order). Treat its section skeleton as the authoritative reference; treat its content as prose to replace with placeholders.
- No `templates/spec-template.md` exists yet.

## Description

Ship the Section Contract SSOT — the single-source-of-truth template that `scripts/specify/specify.sh` (T05) will copy into `specs/<NNN>-<slug>/spec.md` at scaffold time, and from which `scripts/verify/spec-shape-lint.sh` (T02) will derive its required-section list. This file is load-bearing for every downstream task in P01 and for every future orchestrator-authored spec.

Also ship `templates/spec-scaffolder-prompt.md`, the CC LLM round-trip prompt that FR-3 documents as the mechanism by which a Claude Code runtime will populate first-pass prose for Problem Statement and at least one User Story stub. P01 does NOT invoke the LLM — it ships the prompt template so the surface exists; invocation lands in a later M014 phase (see `RUNTIME-ASSUMPTIONS.md` FR-3 entry authored by T04).

## Steps

### Step 1: Create `templates/spec-template.md`

Write the file with YAML frontmatter, then the FR-2 Section Contract sections in order, each containing at least one bracketed `<TODO: ...>` placeholder that `spec-shape-lint.sh` (T02) can detect. Use the `{{placeholder}}` syntax for values the scaffolder fills in (per MEM013 template convention).

Verbatim template body:

```markdown
---
schema_version: "1.0"
type: feature-spec
feature_slug: "{{feature_slug}}"
created_at: "{{created_at}}"
status: "Draft"
milestone: "{{milestone}}"
---

# Feature Specification: {{feature_title}}

**Feature Branch**: `{{feature_slug}}`
**Created**: {{created_at}}
**Status**: Draft
**Milestone**: {{milestone}}
**Input**: User description: "{{description}}"

## Problem Statement

<TODO: Describe the problem this feature solves in 2-4 paragraphs. Include: (a) the current-state gap in one sentence; (b) three concrete pain-points that follow from the gap; (c) the minimum surface that fixes all three; (d) what this feature explicitly does not attempt (scope discipline).>

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

<TODO: Name the smallest coherent subset of user stories whose shipment closes the dogfood loop. Every subsequent phase's scope is defended on top of this slice. See M014/spec.md:27-36 for a worked example.>

### User Story 1 — <TODO: short-title> (Priority: P1)

<TODO: One-paragraph user-facing scenario: who, what action, what outcome, why it matters.>

**Why this priority**: <TODO: Defend the priority ranking relative to the other user stories in this spec.>

**Independent Test**: <TODO: Describe the minimum test harness that verifies this story end-to-end without depending on any other story in this spec.>

**Acceptance Scenarios**:

1. **Given** <TODO: pre-condition>, **When** <TODO: action>, **Then** <TODO: observable outcome>.

---

## Edge Cases

- <TODO: Edge case 1 — describe an off-happy-path scenario and the defined behavior.>

---

## Functional Requirements

- **FR-1 (<TODO: short-name>)**: <TODO: Requirement prose. Cite the user story or success criterion it satisfies.>

## Success Criteria

- **SC-1**: <TODO: Mechanically-verifiable criterion — name the command, the expected exit code, and the observable artifact.>

## Non-Goals

- <TODO: Non-goal 1 — explicit scope boundary with one-sentence rationale.>

## Constraints

- **CON-1 (<TODO: short-name>)**: <TODO: Constraint prose.>

### Knowledge-Layer Boundary (<TODO: this-milestone> vs. <TODO: owning-knowledge-milestone>)

<TODO: Name the milestones on both sides of the boundary and the exact knowledge-tree write-sites this milestone claims vs. delegates.>

## Assumptions

- <TODO: Assumption 1 — a pre-condition that holds outside this milestone's scope.>

## Constitution Check

Compliance with `.orchestrator/memory/constitution.md` for each principle materially touched:

- **Principle <TODO: roman-numeral>**: <TODO: How this spec honors the principle.>

## Open Questions (defer to planning)

- **#Q-1 <TODO: question-short-name>**: <TODO: Open question body + who answers it at plan-phase time.>

## Dependencies

- <TODO: Upstream dependency 1 — milestone or external tool the spec consumes.>

## Downstream Consumers (informational, not binding)

- <TODO: Downstream consumer 1 — future milestone or surface that consumes this spec's output.>
```

**Invariants enforced by T02's linter** (author must preserve):
- Every required top-level heading appears exactly once, in the order shown.
- Every required subsection (`### Minimal Slice ...`, `### User Story N ...`, `### Knowledge-Layer Boundary ...`) appears under its correct parent.
- Every `<TODO: ...>` placeholder is a bracketed block starting with `<TODO:` and ending with `>`.

### Step 2: Create `templates/spec-scaffolder-prompt.md`

This is the FR-3 CC LLM round-trip prompt. Ship the template so the surface exists; invocation is deferred to a later M014 phase (P04 or later). The prompt body:

```markdown
---
schema_version: "1.0"
type: scaffolder-prompt
intended_runtime: "claude-code"
---

# Spec Scaffolder Prompt

You are populating first-pass prose for a new orchestrator feature spec. You will receive:

- `{{description}}` — the operator's natural-language description of the feature.
- `{{template_body}}` — the Section Contract template (`templates/spec-template.md`).
- `{{slug}}` — the kebab-case short-name for the feature.
- `{{milestone}}` — the milestone ID (e.g. `M014`) or `<TODO: bind to milestone>` if unbound.

## Your Task

Produce a spec markdown file that matches `{{template_body}}`'s section structure exactly, with the following sections populated from `{{description}}`:

1. **Frontmatter**: fill `{{feature_slug}}`, `{{created_at}}`, `{{milestone}}`, `{{feature_title}}`, `{{description}}` from the inputs. Leave `status: Draft` unchanged.
2. **Problem Statement**: 2-4 paragraphs derived from `{{description}}`. Name (a) the gap, (b) 3 pain points, (c) the minimum surface, (d) explicit non-attempts.
3. **User Story 1**: one-paragraph scenario derived from `{{description}}`. If the description names more than one distinct user, draft up to 3 user stories.
4. **Open Questions**: list every question `{{description}}` implicitly defers; mark each `(defer to planning)`.

**Leave all other sections as bracketed `<TODO: ...>` placeholders.** The operator authors the rest by hand. Your job is first-pass skeleton-plus-seed-prose; not full spec authorship.

## Output Format

Emit the markdown body only (no fences, no preamble, no explanation). The output must pass `scripts/verify/spec-shape-lint.sh` against the template.

## Runtime Assumptions

This prompt is intended for Claude Code runtime. Under Codex CLI or Cursor, the scaffolder falls back to skeleton-only (no LLM round-trip) per CON-2. See `RUNTIME-ASSUMPTIONS.md` FR-3.
```

### Step 3: Create `tests/fixtures/m014-p01/expected-section-headings.txt`

Write one line per required heading in order; this is the ground-truth fixture T06's FR-18 byte-compat test consumes:

```
# Feature Specification: {{feature_title}}
## Problem Statement
## User Scenarios & Testing *(mandatory)*
### Minimal Slice (Phase 1 Load-Bearing Scope)
### User Story 1 — <TODO: short-title> (Priority: P1)
## Edge Cases
## Functional Requirements
## Success Criteria
## Non-Goals
## Constraints
### Knowledge-Layer Boundary (<TODO: this-milestone> vs. <TODO: owning-knowledge-milestone>)
## Assumptions
## Constitution Check
## Open Questions (defer to planning)
## Dependencies
## Downstream Consumers (informational, not binding)
```

### Step 4: Create `tests/fixtures/m014-p01/specify-fixture-prose.txt`

Short (≤50-word) deterministic fixture prose that T06's FR-18 fixture test will pass as `--description`. Short enough that skeleton-only scaffold is exercised (avoiding LLM round-trip flake in CI):

```
Add an opt-in exporter that ships merged-PR diffs to a Slack channel for async review. Operator configures channel via env var; diffs post with one thread per PR; orchestrator stays idempotent across retries.
```

### Step 5: Create `scripts/verify/m014-p01-template-ssot.sh`

The T07 verification gate for this task. Verbatim body:

```bash
#!/usr/bin/env bash
# scripts/verify/m014-p01-template-ssot.sh — verify templates/spec-template.md Section Contract shape.
# Exit 0 if all required sections present in order; exit 1 otherwise.
# Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEMPLATE="${PROJECT_ROOT}/templates/spec-template.md"
EXPECTED="${PROJECT_ROOT}/tests/fixtures/m014-p01/expected-section-headings.txt"

if [ ! -f "$TEMPLATE" ]; then
  echo "FAIL: templates/spec-template.md missing" >&2
  exit 1
fi
if [ ! -f "$EXPECTED" ]; then
  echo "FAIL: tests/fixtures/m014-p01/expected-section-headings.txt missing" >&2
  exit 1
fi

# Extract headings from template (lines starting with # optionally followed by space).
ACTUAL_FILE="$(mktemp)"
grep -E '^#+[[:space:]]' "$TEMPLATE" > "$ACTUAL_FILE"

# Compare with expected heading list. Use diff for shape-clean comparison.
if diff -q "$EXPECTED" "$ACTUAL_FILE" >/dev/null 2>&1; then
  rm -f "$ACTUAL_FILE"
  echo "PASS: templates/spec-template.md section headings match expected"
  exit 0
fi

echo "FAIL: section headings diverge from expected:" >&2
diff "$EXPECTED" "$ACTUAL_FILE" >&2 || true
rm -f "$ACTUAL_FILE"
exit 1
```

Make executable: `chmod +x scripts/verify/m014-p01-template-ssot.sh`.

## Must-Haves

- `templates/spec-template.md` exists with every FR-2 Section Contract heading in order
- `templates/spec-scaffolder-prompt.md` exists with `{{description}}`, `{{template_body}}`, `{{slug}}`, `{{milestone}}` placeholders
- `tests/fixtures/m014-p01/expected-section-headings.txt` lists every required heading on its own line in required order
- `tests/fixtures/m014-p01/specify-fixture-prose.txt` is ≤50 words, deterministic
- `scripts/verify/m014-p01-template-ssot.sh` is executable and exits 0 when run against the authored template

## Verification

Run the gate verifier:

```
bash scripts/verify/m014-p01-template-ssot.sh
```

Expected stdout: `PASS: templates/spec-template.md section headings match expected`
Expected exit: 0

Run the anti-pattern linter against the new shell script:

```
bash scripts/verify/anti-pattern-lint.sh --fixture scripts/verify/m014-p01-template-ssot.sh
```

Expected exit: 0

## Inputs

### From Previous Tasks

None — T01 has no predecessors.

### From Disk (Pre-existing)

- `specs/024-spec-management-extended/spec.md` — precedent for Section Contract order (read-only reference)
- `templates/phase-plan.md`, `templates/task-plan.md` — template-convention precedent (read-only reference)
- `scripts/verify/anti-pattern-lint.sh` — Bash 3.2 + anti-pattern compliance verifier (invoked for lint)

## Constraints

- Template frontmatter uses `{{placeholder}}` double-brace syntax per MEM013; no hardcoded milestone/phase IDs.
- Every section body contains at least one `<TODO: ...>` bracketed block (T02's linter uses this to detect skeleton vs. authored).
- Bash 3.2 compatible: no `declare -A`, no `mapfile`, no `${var,,}`, no process substitution, no `&>`.
- `scripts/verify/anti-pattern-lint.sh` must pass against the new shell script.
- No emoji, no trailing whitespace in the template body (simplifies fixture byte-matching downstream).

## Expected Output

Three files committed:

1. `templates/spec-template.md` — Section Contract SSOT (~120 lines)
2. `templates/spec-scaffolder-prompt.md` — FR-3 CC LLM prompt (~50 lines)
3. `tests/fixtures/m014-p01/expected-section-headings.txt` — ground-truth heading list (16 lines)
4. `tests/fixtures/m014-p01/specify-fixture-prose.txt` — fixture prose (1 paragraph)
5. `scripts/verify/m014-p01-template-ssot.sh` — gate verifier (~30 lines, executable)

Running `bash scripts/verify/m014-p01-template-ssot.sh` exits 0 with `PASS: ...` stdout.
