---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M011"
goal: "Wire dispatch to scope-filter spec chunks: a task plan with spec/* scope_tags produces a dispatch payload whose Spec Context section contains only the targeted SPEC-* chunks plus their related acceptance criteria and constraints, not the full spec"
demo_sentence: "A developer dispatches a task whose plan contains `scope_tags: [spec/requirement/SPEC-FR-003]`, and the context payload includes only the SPEC-FR-003 chunk plus its related acceptance criteria and constraints — not the full spec."
risk: "medium"
depends_on: [P01]
---

## Must-Haves

### Truths

<!-- Each truth has a single-script-file Check per AD-19.
     Verify scripts themselves may use any bash internally; the
     restriction applies only to these Check: commands. -->

- `scope-filter.sh` accepts a `--spec-scope-tags "<tag-list>"` argument that resolves `spec/<cat>/SPEC-<XX>-<NNN>` tags to SPEC- entry IDs via knowledge.db (or direct file fallback) and emits one ID per line to stdout
  - Check: `bash scripts/verify/m011-p04-spec-scope-tag-resolve.sh`
- When `--spec-scope-tags` is supplied, `scope-filter.sh` extends the returned ID set with 1-hop `relates_to` graph neighbors by invoking `traverse-graph.sh --id <id> --hops 1` for every matched spec ID
  - Check: `bash scripts/verify/m011-p04-spec-scope-tag-graph-neighbors.sh`
- A `spec/requirement/SPEC-FR-XXX` scope tag resolves to the requirement chunk plus every `spec/acceptance` chunk whose `relates_to` includes that requirement, plus every `spec/constraint` chunk whose `relates_to` includes that requirement
  - Check: `bash scripts/verify/m011-p04-requirement-pulls-neighbors.sh`
- `scope-filter.sh --spec-scope-tags` respects the P01 non-goal exclusion (AD-7): `spec/non-goal` entries are NOT emitted unless `--include-non-goals` is passed
  - Check: `bash scripts/verify/m011-p04-spec-scope-excludes-non-goals.sh`
- `scope-filter.sh --spec-scope-tags` ignores graph chains' superseded tips — if `SPEC-FR-003` has been superseded by `SPEC-FR-003-v2`, only the current (non-superseded) chunk is emitted
  - Check: `bash scripts/verify/m011-p04-spec-scope-skips-superseded.sh`
- When a task plan's YAML frontmatter contains a `scope_tags:` list that includes a `spec/*` entry, `build-context.sh` emits a dedicated `## Spec Context` section whose body contains the full content of the resolved chunks (via `resolve-entries.sh`) and only those chunks
  - Check: `bash scripts/verify/m011-p04-dispatch-includes-spec-context.sh`
- When a task plan's `scope_tags` contains NO `spec/*` entries, `build-context.sh` does NOT emit a `## Spec Context` section (no noise for tasks that do not target spec chunks)
  - Check: `bash scripts/verify/m011-p04-dispatch-omits-spec-context-when-unused.sh`
- The `## Spec Context` section excludes chunks outside the resolved scope — given a fixture spec with SPEC-FR-001, SPEC-FR-002, SPEC-FR-003 and a task plan scoped only to `spec/requirement/SPEC-FR-003`, the payload body contains `SPEC-FR-003` and its neighbor IDs but does NOT contain `SPEC-FR-001` or `SPEC-FR-002` text
  - Check: `bash scripts/verify/m011-p04-dispatch-excludes-out-of-scope.sh`
- The end-to-end demo scenario (task plan with `scope_tags: [spec/requirement/SPEC-FR-003]`) produces a payload containing SPEC-FR-003, its related acceptance IDs, and its related constraint IDs, and omits every unrelated SPEC-FR-*
  - Check: `bash scripts/verify/m011-p04-demo-scenario.sh`
- `scope-filter.sh` and `build-context.sh` pass `bash -n` under Bash 3.2 with no `declare -A` / `mapfile` / `readarray` usage
  - Check: `bash scripts/verify/m011-p04-bash32-compat.sh`

### Artifacts

- `scripts/dispatch/scope-filter.sh` (min 500 lines, contains "spec-scope-tags")
- `scripts/dispatch/build-context.sh` (min 850 lines, contains "Spec Context")
- `scripts/dispatch/lib/section-handlers.sh` (min 470 lines, contains "handle_spec_context")
- `templates/context-recipe.yaml` (min 90 lines, contains "spec_context")
- `scripts/verify/m011-p04-spec-scope-tag-resolve.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p04-spec-scope-tag-graph-neighbors.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p04-requirement-pulls-neighbors.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p04-spec-scope-excludes-non-goals.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p04-spec-scope-skips-superseded.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p04-dispatch-includes-spec-context.sh` (min 25 lines, contains "PASS")
- `scripts/verify/m011-p04-dispatch-omits-spec-context-when-unused.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p04-dispatch-excludes-out-of-scope.sh` (min 25 lines, contains "PASS")
- `scripts/verify/m011-p04-demo-scenario.sh` (min 30 lines, contains "PASS")
- `scripts/verify/m011-p04-bash32-compat.sh` (min 5 lines, contains "PASS")

### Key Links

- `scripts/dispatch/scope-filter.sh` → `scripts/knowledge/traverse-graph.sh` (invokes `traverse-graph.sh --id <spec-id> --hops 1` for `relates_to` neighbor expansion)
- `scripts/dispatch/scope-filter.sh` → `scripts/knowledge/lib/graph-db.sh` (reuses existing SQLite helpers for spec-ID → entry lookup)
- `scripts/dispatch/build-context.sh` → `scripts/dispatch/scope-filter.sh` (invokes `scope-filter.sh --spec-scope-tags "<tags>"` during spec-context assembly)
- `scripts/dispatch/build-context.sh` → `scripts/knowledge/resolve-entries.sh` (pipes resolved SPEC- IDs to `resolve-entries.sh` to materialize chunk bodies)
- `scripts/dispatch/lib/section-handlers.sh` → `scripts/dispatch/scope-filter.sh` (new `handle_spec_context` handler delegates resolution to scope-filter)
- `templates/context-recipe.yaml` → `scripts/dispatch/lib/section-handlers.sh` (new `spec_context` section entry with source `spec_context` routes to `handle_spec_context`)

## Tasks

### T01: Extend scope-filter.sh with spec scope-tag resolution + graph-neighbor expansion

See `tasks/T01-PLAN.md`.

### T02: Wire build-context.sh to emit Spec Context section from task-plan scope_tags

See `tasks/T02-PLAN.md`.

### T03: End-to-end demo-scenario verification + regression + Bash 3.2 compat

See `tasks/T03-PLAN.md`.

## Task Dependencies

```
T01 (no new deps beyond P01)
T02 depends on T01
T03 depends on T02
```

Linear chain: T01 → T02 → T03. T01 teaches `scope-filter.sh` to resolve `spec/*/SPEC-XXX-NNN` scope tags into the SPEC- entry ID set plus graph neighbors (returning one ID per line). T02 adds a `handle_spec_context` handler to `section-handlers.sh`, registers a `spec_context` section in the default recipe, and wires `build-context.sh` to (a) parse task-plan `scope_tags:` YAML for `spec/*` entries, (b) call the new handler which invokes T01's resolver, (c) resolve IDs to full chunk bodies via `resolve-entries.sh`, and (d) emit a `## Spec Context` block only when spec tags are present. T03 adds the end-to-end demo-scenario test plus regression guards (non-goal exclusion, superseded-tip skip, unrelated-chunks-absent, Bash 3.2 compat).

## Files Likely Touched

- `scripts/dispatch/scope-filter.sh` (modify)
- `scripts/dispatch/build-context.sh` (modify)
- `scripts/dispatch/lib/section-handlers.sh` (modify)
- `templates/context-recipe.yaml` (modify)
- `scripts/verify/m011-p04-spec-scope-tag-resolve.sh` (create)
- `scripts/verify/m011-p04-spec-scope-tag-graph-neighbors.sh` (create)
- `scripts/verify/m011-p04-requirement-pulls-neighbors.sh` (create)
- `scripts/verify/m011-p04-spec-scope-excludes-non-goals.sh` (create)
- `scripts/verify/m011-p04-spec-scope-skips-superseded.sh` (create)
- `scripts/verify/m011-p04-dispatch-includes-spec-context.sh` (create)
- `scripts/verify/m011-p04-dispatch-omits-spec-context-when-unused.sh` (create)
- `scripts/verify/m011-p04-dispatch-excludes-out-of-scope.sh` (create)
- `scripts/verify/m011-p04-demo-scenario.sh` (create)
- `scripts/verify/m011-p04-bash32-compat.sh` (create)
