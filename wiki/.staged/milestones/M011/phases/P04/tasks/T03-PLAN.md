---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M011"
name: "End-to-end demo-scenario verification + regression + Bash 3.2 compat"
depends_on: [T02]
---

## Prerequisites

T01 and T02 are complete. The following behaviors are on disk:

- `bash scripts/dispatch/scope-filter.sh --spec-scope-tags "spec/requirement/SPEC-FR-003"` emits SPEC-FR-003 plus its 1-hop `relates_to` neighbors, excludes non-goals by default, skips superseded tips.
- `scripts/dispatch/lib/section-handlers.sh` has a `handle_spec_context` handler. `dispatch_section_handler` routes `source: spec_context` to it.
- `scripts/dispatch/build-context.sh` supports recipe-driven `spec_context` sections with omit-empty behavior (no header emitted when no `spec/*` tags are present).
- `templates/context-recipe.yaml` contains a `spec_context:` section with `order: 35`, `priority: compressible`, `filter: scope`, `cache_hint: semi-static`.
- All T01 and T02 verify scripts pass.

No end-to-end demo-scenario verification or consolidated regression script exists yet.

## Description

This task delivers the **demo-scenario verification** for P04's roadmap sentence:

> A developer dispatches a task whose plan contains `scope_tags: [spec/requirement/SPEC-FR-003]`, and the context payload includes only the SPEC-FR-003 chunk plus its related acceptance criteria and constraints — not the full spec.

The demo-scenario script must reproduce this sentence literally: build a realistic fixture with a full spec (5+ requirements, 5+ acceptances, 2+ constraints, 1+ non-goal, and at least one superseded chain), invoke `build-context.sh` on a task plan scoped to one requirement, and assert the payload contains exactly the expected chunk set.

T03 also:
1. Tightens `scripts/verify/m011-p04-bash32-compat.sh` to cover every modified file across T01 and T02 (scope-filter.sh, build-context.sh, section-handlers.sh).
2. Confirms the full P04 verify suite passes: all 10 verify scripts print `PASS:`.

No code changes land in T03 — only verify-script additions / tightening. If the demo scenario fails, the fix is to iterate T01 or T02, not to patch T03.

## Steps

### Step 1: Write `scripts/verify/m011-p04-demo-scenario.sh`

Create a verify script that builds a rich fixture and reproduces the demo sentence:

1. `FIXTURE="$(mktemp -d)"` — sandbox root.
2. `mkdir -p "$FIXTURE/.orchestrator/milestones/M999/phases/P01/tasks"` and `mkdir -p "$FIXTURE/knowledge/spec/{requirement,acceptance,constraint,non-goal,story}"`.
3. Write minimal `$FIXTURE/.orchestrator/milestones/M999/M999-ROADMAP.md` with a single `P01` phase entry.
4. Write `$FIXTURE/.orchestrator/milestones/M999/phases/P01/P01-PLAN.md` — empty scaffold; required because `build-context.sh` asserts the phase plan exists in task-dispatch mode.
5. Write `$FIXTURE/.orchestrator/milestones/M999/phases/P01/tasks/T01-PLAN.md` with frontmatter containing `scope_tags: [spec/requirement/SPEC-FR-003]`. Body should be valid markdown (it does not matter what's in it — the task plan is only consumed for its frontmatter by `handle_spec_context`).
6. Write spec chunks. Each uses `create-entry.sh`-compatible frontmatter + body:
   - SPEC-FR-001, SPEC-FR-002 — unrelated requirements. No `relates_to` to SPEC-FR-003.
   - **SPEC-FR-003** — target. `relates_to: [SPEC-AC-007, SPEC-AC-008, SPEC-CON-001]`.
   - SPEC-FR-004 — unrelated.
   - SPEC-FR-005-v1 — superseded (has `superseded_by: "SPEC-FR-005-v2"`). Should be invisible in the payload even if referenced.
   - SPEC-FR-005-v2 — current version, unrelated.
   - SPEC-AC-006 — unrelated acceptance.
   - **SPEC-AC-007** — related to SPEC-FR-003 via `relates_to`. `category: spec/acceptance`.
   - **SPEC-AC-008** — related to SPEC-FR-003 via `relates_to`. `category: spec/acceptance`.
   - **SPEC-CON-001** — related to SPEC-FR-003 via `relates_to`. `category: spec/constraint`.
   - SPEC-CON-002 — unrelated.
   - SPEC-NG-001 — `category: spec/non-goal`. Must be excluded even if the graph traversal hits it.
   - SPEC-US-010 — unrelated story.
7. `PROJECT_ROOT=$FIXTURE bash scripts/knowledge/rebuild-index.sh` — build `knowledge.db`.
8. `PROJECT_ROOT=$FIXTURE bash scripts/dispatch/build-context.sh $FIXTURE/.orchestrator M999 P01 T01 > "$FIXTURE/payload.txt" 2>/dev/null`.
9. Assertions:
   - `payload.txt` contains `## Spec Context` — PASS contribution.
   - `payload.txt` contains `SPEC-FR-003` — PASS contribution.
   - `payload.txt` contains `SPEC-AC-007` — PASS contribution.
   - `payload.txt` contains `SPEC-AC-008` — PASS contribution.
   - `payload.txt` contains `SPEC-CON-001` — PASS contribution.
   - `payload.txt` does NOT contain `SPEC-FR-001` — PASS contribution (asserts exclusion).
   - `payload.txt` does NOT contain `SPEC-FR-002` — PASS contribution.
   - `payload.txt` does NOT contain `SPEC-FR-004` — PASS contribution.
   - `payload.txt` does NOT contain `SPEC-FR-005` — PASS contribution (covers both v1 and v2, since the tag is not in scope).
   - `payload.txt` does NOT contain `SPEC-AC-006` — PASS contribution.
   - `payload.txt` does NOT contain `SPEC-CON-002` — PASS contribution.
   - `payload.txt` does NOT contain `SPEC-NG-001` — PASS contribution (non-goal exclusion).
   - `payload.txt` does NOT contain `SPEC-US-010` — PASS contribution.
10. Emit `PASS:` + brief summary if all assertions held; else `FAIL:` + offending assertion.

Use a loop for the grep-present / grep-absent assertions to keep the script readable. Follow the P03/T03 fixture-and-assertion pattern in `scripts/verify/m011-p03-demo-scenario.sh`.

### Step 2: Tighten `scripts/verify/m011-p04-bash32-compat.sh`

T01 created the initial version scanning only `scope-filter.sh`. Expand to scan:
- `scripts/dispatch/scope-filter.sh`
- `scripts/dispatch/build-context.sh`
- `scripts/dispatch/lib/section-handlers.sh`

For each file, run `bash -n <file>` and grep for forbidden patterns:
- `declare -A` (associative array declaration)
- `mapfile` / `readarray`
- `<(` (process substitution)
- `\${!.*@}` / `\${!.*\[\*\]}` (indirect expansion on array keys)

The grep MUST be comment-aware: rule out lines whose first non-whitespace character is `#`. Use the pattern from `scripts/verify/m011-p03-bash32-compat.sh` as reference (it already handles comment exclusion).

Print `PASS:` if every file parses cleanly and contains no forbidden pattern; `FAIL:` otherwise with the offending file and line number.

### Step 3: Re-run full P04 verify suite

Add a small helper comment at the top of `m011-p04-demo-scenario.sh` documenting the expected full-suite command sequence for manual re-verification:

```
# Full P04 verify suite (all must PASS):
#   bash scripts/verify/m011-p04-bash32-compat.sh
#   bash scripts/verify/m011-p04-spec-scope-tag-resolve.sh
#   bash scripts/verify/m011-p04-spec-scope-tag-graph-neighbors.sh
#   bash scripts/verify/m011-p04-requirement-pulls-neighbors.sh
#   bash scripts/verify/m011-p04-spec-scope-excludes-non-goals.sh
#   bash scripts/verify/m011-p04-spec-scope-skips-superseded.sh
#   bash scripts/verify/m011-p04-dispatch-includes-spec-context.sh
#   bash scripts/verify/m011-p04-dispatch-omits-spec-context-when-unused.sh
#   bash scripts/verify/m011-p04-dispatch-excludes-out-of-scope.sh
#   bash scripts/verify/m011-p04-demo-scenario.sh
```

No orchestration script — the phase-level `check-must-haves.sh` run by the orchestrator already runs every `Check:` command from the phase plan individually.

## Must-Haves

- `scripts/verify/m011-p04-demo-scenario.sh` builds a fixture with at least 12 spec entries (including one superseded chain and one non-goal), invokes `build-context.sh` on a task plan scoped to `spec/requirement/SPEC-FR-003`, and asserts the full in-scope / out-of-scope partition
- `scripts/verify/m011-p04-bash32-compat.sh` scans `scope-filter.sh`, `build-context.sh`, AND `section-handlers.sh` for Bash 3.2 violations (expanded from T01's scope-filter-only version)
- The demo-scenario script prints `PASS:` when every assertion holds
- When T03 completes, every P04 verify script (10 total) prints `PASS:` and exits 0

## Verification

```
bash scripts/verify/m011-p04-demo-scenario.sh
bash scripts/verify/m011-p04-bash32-compat.sh
bash scripts/verify/m011-p04-spec-scope-tag-resolve.sh
bash scripts/verify/m011-p04-spec-scope-tag-graph-neighbors.sh
bash scripts/verify/m011-p04-requirement-pulls-neighbors.sh
bash scripts/verify/m011-p04-spec-scope-excludes-non-goals.sh
bash scripts/verify/m011-p04-spec-scope-skips-superseded.sh
bash scripts/verify/m011-p04-dispatch-includes-spec-context.sh
bash scripts/verify/m011-p04-dispatch-omits-spec-context-when-unused.sh
bash scripts/verify/m011-p04-dispatch-excludes-out-of-scope.sh
```

All 10 verify scripts must print `PASS:` and exit 0.

## Inputs

### From Previous Tasks

- `scripts/dispatch/scope-filter.sh` (from T01)
  - Key API: `scope-filter.sh --spec-scope-tags "<tag-list>"` emits one ID per line; respects `--include-non-goals`; skips superseded tips; exit 0 always
- `scripts/dispatch/build-context.sh` + `scripts/dispatch/lib/section-handlers.sh` (from T02)
  - Key API: `build-context.sh <orch_root> <milestone> <phase> <task>` emits dispatch payload to stdout; payload contains `## Spec Context` section iff task plan has `spec/*` scope_tags; omit-empty otherwise
  - `handle_spec_context` parses task-plan YAML frontmatter, extracts `spec/*` tags, resolves via scope-filter + resolve-entries, emits section body only on non-empty resolution
- `templates/context-recipe.yaml` (from T02)
  - Contains `spec_context:` section entry, order 35

### From Disk (Pre-existing)

- `scripts/knowledge/rebuild-index.sh` — `PROJECT_ROOT=<dir> bash rebuild-index.sh` scans `$PROJECT_ROOT/knowledge/*/*.md` + `$PROJECT_ROOT/knowledge/*/*/*.md` and rebuilds `$PROJECT_ROOT/knowledge.db`. Emits progress lines to stderr.
- `scripts/knowledge/create-entry.sh` — `create-entry.sh --id <ID> --category <cat> --scope-tags <tags> --source-unit <ref> --source-type <type> --description <str> --body <str> [--relates-to <id>]`. The fixture can use this helper for well-formed frontmatter, or write the markdown files directly (matching the P03/T03 pattern which writes files directly for speed).
- P03 verify scripts under `scripts/verify/m011-p03-*.sh` — reference for fixture-building, sandbox management, and `PASS:`/`FAIL:` structured-output conventions.

## Constraints

- Bash 3.2 compatible: no `declare -A`, no `mapfile`, no `readarray`, no `<(...)`. Parallel indexed arrays or temp files only.
- AD-19 `Check:` command shape in phase plan — single `bash scripts/verify/<name>.sh` invocations. The verify scripts' internal code can use any bash.
- Sandbox containment: every fixture is built inside `$(mktemp -d)`. Cleanup via EXIT trap in every verify script. Never write to the real project tree. Set `PROJECT_ROOT` before invoking rebuild-index.sh / build-context.sh so every script under test uses the sandbox knowledge tree.
- The `m011-p04-demo-scenario.sh` assertion list MUST include both present-checks (SPEC-FR-003, SPEC-AC-007, SPEC-AC-008, SPEC-CON-001) and absent-checks (SPEC-FR-001, SPEC-FR-002, SPEC-FR-004, SPEC-FR-005, SPEC-AC-006, SPEC-CON-002, SPEC-NG-001, SPEC-US-010). A present-only test would not catch "includes the full spec" regressions.
- The non-goal in the fixture (SPEC-NG-001) must also have a `relates_to: [SPEC-FR-003]` edge to exercise the AD-7 exclusion path — otherwise the test cannot distinguish "excluded by non-goal filter" from "not reachable via traversal".
- The demo script must tolerate both absent and present `sqlite3` binaries — if the DB cannot be built, fall back to the file-existence path T01's scope-filter supports. However, the standard path assumes `sqlite3` is available (same as every other M011 test); adding fallback is nice-to-have, not required.
- No modifications to any script under `scripts/dispatch/`, `scripts/knowledge/`, or `scripts/lib/`. T03 is pure verification.
- No modifications to `templates/context-recipe.yaml`. T02 owns that file.
- If the demo-scenario script surfaces a real bug, FIX IT IN T01 or T02 and re-run — do not paper over the bug in the verify script. T03's job is to catch the bug; T01 and T02 own the fix.
- Scope: T03 produces exactly two new/modified files — `m011-p04-demo-scenario.sh` (create) and `m011-p04-bash32-compat.sh` (modify).

## Expected Output

- `scripts/verify/m011-p04-demo-scenario.sh` (create, ~120 lines) — rich fixture + 13 assertions + `PASS:`/`FAIL:` emission.
- `scripts/verify/m011-p04-bash32-compat.sh` (modify) — tightened to scan `scope-filter.sh`, `build-context.sh`, and `section-handlers.sh` (from T01's initial scope-filter-only version).
- When T03 completes, running every `Check:` command from the phase plan individually prints `PASS:` and exits 0. `scripts/verify/check-must-haves.sh .orchestrator/milestones/M011/phases/P04` reports all truths hold.
