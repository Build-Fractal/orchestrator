---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M008"
name: "Refactor commands/*.md -- add Intensity Behavior sections"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `scripts/engine/intensity-gate.sh` exists and emits `execute_substeps=<csv>` / `skip_substeps=<csv>` for each stage and intensity.
- Existing command docs (MEM012 structure preserved): `commands/discuss.md`, `commands/plan-phase.md`, `commands/dispatch.md`, `commands/verify.md`, `commands/auto.md`.

## Description

Append a new `## Intensity Behavior` section to each of the five pipeline command docs. The section:

1. States the stage name used when invoking the gate.
2. Documents the substeps per intensity level.
3. Instructs the agent interpreting the command to call `scripts/engine/intensity-gate.sh` at entry and branch on `execute_substeps` / `skip_substeps`.

**MINIMAL REFACTOR**. Do not rewrite any existing workflow text. Do not reorder sections. Do not modify YAML frontmatter. Do not delete anything. We are attaching a new section; the rest of the document stays intact. This preserves MEM012 (command file structure) and ensures that a fresh agent reading the doc still sees the original prescriptions and degrades gracefully if the gate is missing.

Placement: insert `## Intensity Behavior` as the second section of each doc, immediately after the title/header (first paragraph after the `# speckit.orchestrator.*` heading) and before the first existing `##` section. This makes intensity a front-of-mind concern rather than an afterthought.

## Steps

### Step 1 — Edit commands/discuss.md

Insert the following new section after the title paragraph (before the first `## Prerequisites` heading):

```markdown
## Intensity Behavior

This command is an intensity-aware stage. At entry, call:

```bash
bash scripts/engine/intensity-gate.sh --stage discuss --intensity-metadata <path-to-metadata>
```

Parse the `execute_substeps=` and `skip_substeps=` output and branch:

| Intensity | execute_substeps | Behavior |
|-----------|------------------|----------|
| Quick     | none             | Skip discussion entirely. Do not create a context draft. Report "Discussion skipped at Quick intensity" and exit. |
| Standard  | optional         | Discussion is optional. If `M###-EVALUATION.md` lists `discuss_required: true`, proceed. Otherwise, prompt the developer: "Discussion is optional at Standard intensity. Proceed or skip?" |
| Full      | required         | Discussion is a hard gate. Proceed with the full question generation and context-draft workflow described below. |

If the gate is missing or returns an unknown value, default to Full (fail-safe: when in doubt, discuss more not less).
```

Use the Edit tool with `old_string` set to the existing line immediately preceding `## Prerequisites` (the line after the intro paragraph) and `new_string` set to that same line followed by the section above. This guarantees surgical placement.

### Step 2 — Edit commands/plan-phase.md

Insert after the title/intro paragraph, before `## Phase Selection`:

```markdown
## Intensity Behavior

This command is an intensity-aware stage. At entry, call:

```bash
bash scripts/engine/intensity-gate.sh --stage plan-phase --intensity-metadata <path-to-metadata>
```

Parse the `execute_substeps=` and `skip_substeps=` output and branch:

| Intensity | execute_substeps        | Behavior |
|-----------|-------------------------|----------|
| Quick     | single-task             | Create ONE task plan. No boundary map. No full decomposition. Must-haves list is minimal (one truth, one artifact). |
| Standard  | basic-decomp,boundary-map | Create 2-4 task plans. Include a basic Boundary Map showing Produces/Consumes. Must-haves cover core behaviors. |
| Full      | full-decomp,boundary-map  | Full decomposition (1-7 tasks per FR-005). Complete Boundary Map. Full Must-Haves section with Truths, Artifacts, Key Links. Zero-context task plans per FR-011. |

The existing planning workflow below describes the Full behavior. At Quick/Standard, apply the reductions above to the same workflow; do not invent a different workflow.
```

### Step 3 — Edit commands/dispatch.md

Insert after the title/intro paragraph, before the first existing `##` section:

```markdown
## Intensity Behavior

This command is an intensity-aware stage. At entry, call:

```bash
bash scripts/engine/intensity-gate.sh --stage dispatch --intensity-metadata <path-to-metadata>
```

Parse the `execute_substeps=` and `skip_substeps=` output and branch:

| Intensity | execute_substeps              | Behavior |
|-----------|-------------------------------|----------|
| Quick     | sequential                    | Skip payload assembly (`build-context.sh`). Invoke `dispatch-interface.sh` with a minimal payload containing only the task plan. Run tasks sequentially — no parallel fan-out. |
| Standard  | standard-payload              | Full payload assembly (task plan + upstream summaries + scope-filtered knowledge). Standard dispatch semantics. |
| Full      | full-context,knowledge-inject | Full payload + graph-traversed knowledge (`traverse-graph.sh`) + explicit provenance chain (`check-graph-health`). Inject full context for high-risk tasks. |

The `--intensity-metadata` argument is already a first-class parameter of `dispatch-interface.sh` (P02). Forward it through unchanged.
```

### Step 4 — Edit commands/verify.md

Insert after the title/intro paragraph, before the first existing `##` section:

```markdown
## Intensity Behavior

This command is an intensity-aware stage. At entry, call:

```bash
bash scripts/engine/intensity-gate.sh --stage verify --intensity-metadata <path-to-metadata>
```

Parse the `execute_substeps=` and `skip_substeps=` output and branch:

| Intensity | execute_substeps          | Behavior |
|-----------|---------------------------|----------|
| Quick     | tier1                     | Run Tier 1 (static checks: file existence, content patterns) only. Skip Tier 2-4. |
| Standard  | tier1,tier2               | Run Tier 1 + Tier 2 (command execution: configured tests/lint). Skip Tier 3-4. |
| Full      | tier1,tier2,tier3,tier4   | Run all four tiers: Tier 1 (static) + Tier 2 (commands) + Tier 3 (behavioral spec-compliance review) + Tier 4 (human UAT). |

Higher tiers are strictly additive — a Tier 2 failure is reported even if Tier 1 passes. The verification report records which tiers ran and which were skipped by intensity policy.
```

### Step 5 — Edit commands/auto.md

Insert after the title/intro paragraph, before the first existing `##` section:

```markdown
## Intensity Behavior

This command is an intensity-aware stage. At entry of every loop iteration, call:

```bash
bash scripts/engine/intensity-gate.sh --stage auto --intensity-metadata <path-to-metadata>
```

Parse the `execute_substeps=` and `skip_substeps=` output and branch:

| Intensity | execute_substeps                      | Behavior |
|-----------|---------------------------------------|----------|
| Quick     | dispatch,no-pause                     | Dispatch the next task and advance immediately after verification. No pause gates between tasks. Auto mode runs end-to-end without interruption. |
| Standard  | dispatch,standard-pause               | Dispatch + standard pause gates (pause on verification failure; pause on budget threshold; pause on explicit `pause_requested` file). |
| Full      | dispatch,strict-pause,human-review    | Dispatch + strict pause gates + human review gate. After each task summary, write a `pending_review` flag; auto loop waits until a human clears it before proceeding to the next task. High-risk stance for platform-level work. |

Intensity can be overridden mid-run via `bash scripts/engine/intensity-override.sh --metadata-file <path> --new-intensity <level>`. The next auto iteration reads the new value and scales accordingly; completed iterations are preserved.
```

### Step 6 — Create scripts/verify/m008-p03-commands-intensity-section.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# Verifies each pipeline command doc contains the Intensity Behavior
# section and references scripts/engine/intensity-gate.sh.
set -u

cmds="commands/discuss.md commands/plan-phase.md commands/dispatch.md commands/verify.md commands/auto.md"

for c in $cmds; do
  test -f "$c" || { echo "FAIL: $c missing"; exit 1; }
  grep -q '^## Intensity Behavior' "$c" || { echo "FAIL: $c missing '## Intensity Behavior' section"; exit 1; }
  grep -q 'scripts/engine/intensity-gate.sh' "$c" || { echo "FAIL: $c missing reference to intensity-gate.sh"; exit 1; }
  grep -q 'execute_substeps' "$c" || { echo "FAIL: $c does not document execute_substeps semantics"; exit 1; }
done

# Per-stage name check: each doc should reference --stage <its-own-name>
grep -q -- '--stage discuss'    commands/discuss.md    || { echo "FAIL: discuss.md missing --stage discuss"; exit 1; }
grep -q -- '--stage plan-phase' commands/plan-phase.md || { echo "FAIL: plan-phase.md missing --stage plan-phase"; exit 1; }
grep -q -- '--stage dispatch'   commands/dispatch.md   || { echo "FAIL: dispatch.md missing --stage dispatch"; exit 1; }
grep -q -- '--stage verify'     commands/verify.md     || { echo "FAIL: verify.md missing --stage verify"; exit 1; }
grep -q -- '--stage auto'       commands/auto.md       || { echo "FAIL: auto.md missing --stage auto"; exit 1; }

echo "PASS: all 5 pipeline commands contain Intensity Behavior sections referencing intensity-gate.sh"
```

### Step 7 — Make verify script executable

```bash
chmod +x scripts/verify/m008-p03-commands-intensity-section.sh
```

## Must-Haves

From the phase plan, this task addresses:

- **Truths**: commands-intensity-section truth ("each doc contains Intensity Behavior section that describes per-level substeps and references intensity-gate.sh").
- **Artifacts**: `commands/discuss.md`, `commands/plan-phase.md`, `commands/dispatch.md`, `commands/verify.md`, `commands/auto.md` (modified; verified by min-line count + contained strings), `scripts/verify/m008-p03-commands-intensity-section.sh`.

## Verification

```bash
bash scripts/verify/m008-p03-commands-intensity-section.sh
```

Prints `PASS:` and exits 0.

Additionally: `git diff commands/` should show additions only (no deletions) in each of the five files. If there are deletions, the refactor is not minimal and must be redone.

### Files Touched By This Task

- `commands/discuss.md` (modify — additive only)
- `commands/plan-phase.md` (modify — additive only)
- `commands/dispatch.md` (modify — additive only)
- `commands/verify.md` (modify — additive only)
- `commands/auto.md` (modify — additive only)
- `scripts/verify/m008-p03-commands-intensity-section.sh` (create)

## Inputs

### From Previous Tasks

- `scripts/engine/intensity-gate.sh` (from T01)
  - Key API: invoked as `bash scripts/engine/intensity-gate.sh --stage <name> --intensity-metadata <path>`. Emits `execute_substeps=<csv>` and `skip_substeps=<csv>` on stdout. Exit 0 success, non-zero on invalid inputs.
  - Stage names: `discuss`, `plan-phase`, `dispatch`, `verify`, `auto`, `research`, `knowledge`. Each of the five refactored docs invokes the gate with the stage name matching its own filename (except `auto`).
  - Substep vocabulary: see matrix tables inserted into each command doc.

### From Disk (Pre-existing)

- `commands/discuss.md` — existing 157-line command doc (MEM012 structure).
- `commands/plan-phase.md` — existing 237-line command doc.
- `commands/dispatch.md` — existing 143-line command doc.
- `commands/verify.md` — existing 149-line command doc.
- `commands/auto.md` — existing 531-line command doc.

## Constraints

- **Additive only.** The edit to each command doc inserts a new `## Intensity Behavior` section. It does NOT delete, reorder, or rewrite any existing content. `git diff` should show only additions in each of the five files. Any deletions are a bug.
- Placement: insert after the title/intro paragraph, before the first existing `##` section. This makes intensity a first-class concern at read time.
- YAML frontmatter: MUST NOT be modified. The `description:` field stays as-is.
- MEM012 structure preserved: the canonical section order (title -> prereq/state-check -> workflow -> output -> idempotency -> error handling -> referenced scripts) is extended, not replaced. The new section lives between the title and the prereq section.
- Every inserted section references `scripts/engine/intensity-gate.sh` and uses the stage name documented in T01's matrix (discuss, plan-phase, dispatch, verify, auto). The verify script enforces this.
- Tables use standard markdown pipe syntax. No HTML.
- The `discuss` section's Quick row must read `execute_substeps: none` to match T01's matrix; `Full` row must read `required`. Same pattern for other stages. Any mismatch between the doc table and T01's gate output is a bug.

## Expected Output

After completing this task:

1. All five command docs contain a `## Intensity Behavior` section placed after the title and before the first existing `##` section.
2. Each section contains a 3-row table (Quick/Standard/Full) describing substep behavior.
3. Each section references `scripts/engine/intensity-gate.sh` and the stage name matching its own command.
4. `bash scripts/verify/m008-p03-commands-intensity-section.sh` prints `PASS:` and exits 0.
5. `git diff commands/` shows additions only (no deletions) in each of the five files.
6. Line counts increase by roughly 20-30 lines per file (no other changes).
