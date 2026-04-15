---
schema_version: "1.0"
type: phase-plan
phase: "P05"
milestone: "M004"
goal: "Refactor build-context.sh, compress-payload.sh, and select-model.sh to be driven by templates/context-recipe.yaml and templates/routing.yaml — all via scripts/lib/recipe-parser.sh — while preserving identical default-recipe output"
demo_sentence: "build-context.sh reads context-recipe.yaml to determine which sections to assemble and in what order; compress-payload.sh reads the compression block to determine graduated steps; select-model.sh reads fallback chains from routing.yaml — all three scripts produce identical output to their pre-refactor versions when given the default recipe."
risk: "high"
depends_on: [P02, P03, P04]
---

## Goal

Move section selection, section ordering, compression strategy, and model fallback policy out of three dispatch scripts and into YAML recipes that already ship with P04. After this phase, changing which sections appear in a dispatch payload (or in what order, or at what priority), changing the compression strategy, or changing a model fallback chain is a one-line edit in `templates/context-recipe.yaml` / `templates/routing.yaml` — not a code change. The three scripts become recipe interpreters that delegate per-section work to handler functions in a new sibling library, `scripts/dispatch/lib/section-handlers.sh`.

This phase implements the mechanical side of Principle X (Templating Over Inference) and Principle XIII (Agent Instruction Schema). It does NOT change the default payload produced for any existing task — the acceptance bar is byte-for-byte parity (modulo a narrow manifest-header whitelist) between pre-refactor output and post-refactor output when the default recipe is used.

## Demo

From repo root, a developer can:

1. Capture a golden payload with the pre-refactor scripts:
   ```bash
   git stash   # or checkout the pre-P05 commit
   bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 \
     > /tmp/p05-golden.md 2>/dev/null
   git stash pop
   ```
2. Run the refactored scripts:
   ```bash
   bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 \
     > /tmp/p05-refactored.md 2>/dev/null
   ```
3. Diff the two — the only permitted differences are within the `## Manifest` table token/line-count columns (and even those must agree when the recipe is unchanged). Content sections must match character-for-character.

And:

```bash
# Adding a new section to the recipe makes it appear without any script edit.
cp templates/context-recipe.yaml /tmp/recipe-test.yaml
printf '  test_section:\n    source: template\n    priority: optional\n    order: 99\n    filter: none\n    cache_hint: static\n' >> /tmp/recipe-test.yaml
# (future: phase/task override path; M004/P05 establishes the interpreter)
```

```bash
# The new fallback chain is honored by select-model.sh
bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml
# → claude-opus-4-6 200000
bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml --list-fallback
# → claude-sonnet-4-6,claude-haiku-4-5
```

## Must-Haves

### Truths

- `scripts/dispatch/lib/section-handlers.sh` exists and has a double-sourcing guard on line 3 or 4
  - Check: `head -5 scripts/dispatch/lib/section-handlers.sh | grep -q '_SECTION_HANDLERS_SOURCED'`
- `scripts/dispatch/lib/section-handlers.sh` defines a handler function for every source type used by the default recipe (`computed`, `file`, `phase_summaries`, `phase_plan`, `template`, plus the knowledge/decisions `source: KNOWLEDGE.md` / `DECISIONS.md` filename dispatch)
  - Check: `for fn in handle_computed handle_file handle_phase_summaries handle_phase_plan handle_template handle_knowledge handle_decisions; do grep -q "^${fn}()" scripts/dispatch/lib/section-handlers.sh || exit 1; done`
- `scripts/dispatch/build-context.sh` sources `scripts/lib/recipe-parser.sh` and calls `parse_recipe_sections` at runtime (no hardcoded section list)
  - Check: `grep -q 'recipe-parser.sh' scripts/dispatch/build-context.sh && grep -q 'parse_recipe_sections' scripts/dispatch/build-context.sh`
- `scripts/dispatch/build-context.sh` sources `scripts/dispatch/lib/section-handlers.sh` and dispatches each section to its handler by source type
  - Check: `grep -q 'section-handlers.sh' scripts/dispatch/build-context.sh`
- `scripts/dispatch/build-context.sh` sources `scripts/lib/errors.sh`, `scripts/lib/events.sh`, and `scripts/lib/run-context.sh` and calls `emit_result` on exit
  - Check: `grep -q 'scripts/lib/errors.sh' scripts/dispatch/build-context.sh && grep -q 'scripts/lib/events.sh' scripts/dispatch/build-context.sh && grep -q 'scripts/lib/run-context.sh' scripts/dispatch/build-context.sh && grep -q 'emit_result' scripts/dispatch/build-context.sh`
- `scripts/dispatch/build-context.sh` no longer hardcodes any of the 7 section names as literal `SEC_*` string constants (they must be read from the recipe)
  - Check: `test "$(grep -c '^  SEC_KNOWLEDGE=' scripts/dispatch/build-context.sh)" -eq 0`
- `scripts/dispatch/compress-payload.sh` sources `scripts/lib/recipe-parser.sh` and calls `parse_recipe_compression` to determine compression steps
  - Check: `grep -q 'recipe-parser.sh' scripts/dispatch/compress-payload.sh && grep -q 'parse_recipe_compression' scripts/dispatch/compress-payload.sh`
- `scripts/dispatch/compress-payload.sh` accepts a `--recipe <path>` argument to override the default recipe
  - Check: `grep -q '\-\-recipe' scripts/dispatch/compress-payload.sh`
- `scripts/dispatch/compress-payload.sh` sources `scripts/lib/errors.sh` / `events.sh` / `run-context.sh` and emits a final RESULT line
  - Check: `grep -q 'scripts/lib/errors.sh' scripts/dispatch/compress-payload.sh && grep -q 'emit_result' scripts/dispatch/compress-payload.sh`
- `scripts/dispatch/select-model.sh` sources `scripts/lib/recipe-parser.sh` and uses `parse_recipe_fallback` to read the fallback chain
  - Check: `grep -q 'recipe-parser.sh' scripts/dispatch/select-model.sh && grep -q 'parse_recipe_fallback' scripts/dispatch/select-model.sh`
- `scripts/dispatch/select-model.sh` supports a `--list-fallback` flag that prints the comma-separated fallback chain for the selected tier
  - Check: `grep -q '\-\-list-fallback' scripts/dispatch/select-model.sh`
- `scripts/dispatch/select-model.sh` supports a `--next-fallback <current-model>` flag that returns the next model in the chain (or exits non-zero when the chain is exhausted) — the retry-on-fallback primitive the engine will consume
  - Check: `grep -q '\-\-next-fallback' scripts/dispatch/select-model.sh`
- `scripts/dispatch/select-model.sh` sources `scripts/lib/errors.sh` and emits a final RESULT line
  - Check: `grep -q 'scripts/lib/errors.sh' scripts/dispatch/select-model.sh && grep -q 'emit_result' scripts/dispatch/select-model.sh`
- All new and refactored scripts are Bash 3.2 compatible (no associative arrays, no readarray/mapfile)
  - Check: `! grep -qE 'declare -A|readarray|mapfile' scripts/dispatch/lib/section-handlers.sh scripts/dispatch/build-context.sh scripts/dispatch/compress-payload.sh scripts/dispatch/select-model.sh`
- No inline `date` calls in the refactored scripts (Principle IX — use `orch_now`)
  - Check: `! grep -nE '\$\(date\b|` + "`" + `date\b|^[[:space:]]*date[[:space:]]+(-u|\+)' scripts/dispatch/build-context.sh scripts/dispatch/compress-payload.sh scripts/dispatch/select-model.sh`
- Parity fixture exists: a golden pre-refactor payload and a shell harness that regenerates the post-refactor payload and diffs the two
  - Check: `test -f scripts/dispatch/lib/section-handlers.sh && test -f .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md`
- Parity holds: refactored `build-context.sh` output matches the golden fixture outside the manifest token-count columns
  - Check: `bash .specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh && echo PASS`
- Engine `scripts/engine/run.sh` still invokes the three dispatch scripts with its existing argument shape (no engine rewrite)
  - Check: `grep -q 'scripts/dispatch/build-context.sh .specify/orchestrator "$ENGINE_MILESTONE"' scripts/engine/run.sh && grep -q 'scripts/dispatch/compress-payload.sh --budget' scripts/engine/run.sh && grep -q 'scripts/dispatch/select-model.sh' scripts/engine/run.sh`

### Artifacts

- `scripts/dispatch/lib/section-handlers.sh` (min 200 lines, contains "_SECTION_HANDLERS_SOURCED")
- `scripts/dispatch/build-context.sh` (min 200 lines, contains "parse_recipe_sections")
- `scripts/dispatch/compress-payload.sh` (min 200 lines, contains "parse_recipe_compression")
- `scripts/dispatch/select-model.sh` (min 120 lines, contains "parse_recipe_fallback")
- `.specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md` (min 20 lines, contains "Dispatch Context")
- `.specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh` (min 20 lines, contains "diff")

### Key Links

- `scripts/dispatch/build-context.sh` → `scripts/lib/recipe-parser.sh`
- `scripts/dispatch/build-context.sh` → `scripts/dispatch/lib/section-handlers.sh`
- `scripts/dispatch/build-context.sh` → `scripts/lib/errors.sh`
- `scripts/dispatch/build-context.sh` → `scripts/lib/events.sh`
- `scripts/dispatch/build-context.sh` → `scripts/lib/run-context.sh`
- `scripts/dispatch/build-context.sh` → `templates/context-recipe.yaml`
- `scripts/dispatch/compress-payload.sh` → `scripts/lib/recipe-parser.sh`
- `scripts/dispatch/compress-payload.sh` → `templates/context-recipe.yaml`
- `scripts/dispatch/compress-payload.sh` → `scripts/lib/errors.sh`
- `scripts/dispatch/select-model.sh` → `scripts/lib/recipe-parser.sh`
- `scripts/dispatch/select-model.sh` → `templates/routing.yaml`
- `scripts/dispatch/select-model.sh` → `scripts/lib/errors.sh`
- `scripts/dispatch/lib/section-handlers.sh` → `scripts/knowledge/traverse-graph.sh`
- `scripts/dispatch/lib/section-handlers.sh` → `scripts/knowledge/resolve-entries.sh`
- `scripts/dispatch/lib/section-handlers.sh` → `scripts/dispatch/scope-filter.sh`

## Cross-Cutting Constraints (apply to every task)

Every task in this phase MUST comply with the following. These are repeated in each task plan so that a fresh agent executing one task in isolation cannot miss them:

1. **Bash 3.2** — no associative arrays (`declare -A`), no `readarray`, no `mapfile`, no process substitution (`<(…)`) as a redirect target in `while read` loops. Use `mktemp` temp files per AP-001 when iterating derived data.
2. **Double-sourcing guard on lines 3–4** — every new library file must follow the pattern used by P02/T01–T05: shebang on line 1, one-line comment on line 2, guard (`[ -n "${_LIBNAME_SOURCED:-}" ] && return 0` / `_LIBNAME_SOURCED=1`) on lines 3–4. The guard must pass a `head -5` grep check.
3. **Sibling library sourcing** — compute sibling paths via `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` then `. "$SCRIPT_DIR/../lib/<name>.sh"`. Do not hardcode absolute paths.
4. **No inline `date`** — after sourcing `run-context.sh`, call `orch_now` instead of `date -u ...`. The inline-date audit in check-must-haves catches `date -u` and `$(date ...)` both.
5. **`emit_result` on exit** — every refactored script must source `scripts/lib/errors.sh` and call `emit_result ok ""  "<summary>"` on its normal exit path and `emit_result error <KIND> "<detail>"` on error paths. Use a `trap … EXIT` or a wrapper function to guarantee emission.
6. **Standalone mode still works** — if `ORCH_RUN_ID` is unset, the refactored scripts must still produce correct output. The engine integration path sets `ORCH_RUN_ID`; ad-hoc CLI invocation does not. Check with `( unset ORCH_RUN_ID; bash scripts/dispatch/<script>.sh ... )`.
7. **`scripts/engine/run.sh` is NOT rewritten** — P05 must not modify `run.sh`. It must continue to invoke `build-context.sh .specify/orchestrator "$ENGINE_MILESTONE" "$ENGINE_PHASE" "$task_id"`, `compress-payload.sh --budget N --input FILE`, and `select-model.sh standard --routing-config templates/routing.yaml` with exactly those shapes. Any new flags added to the dispatch scripts must be optional.
8. **P06-deferred items — do NOT touch.** The following are out of scope for P05 and owned by P06:
   - `scripts/verify/check-must-haves.sh` PROJECT_ROOT detection bug (walks up to milestone dir instead of repo root).
   - `scripts/lib/events.sh` `_orch_events_quote` single-word-value quoting gap.
   - `scripts/lifecycle/record-result.sh` missing `run_id` threading.
   P05 must inherit the P03 workarounds: run verification from repo root (so PROJECT_ROOT=$(pwd) is correct), and if any `emit_event` value used in a must-have grep is a single-word value, pair it with a literal-audit-marker `printf` line the way P03/T03–T05 did. If you discover a new bug in a lib or engine script while refactoring, surface it in the task summary as a P06 scope candidate; DO NOT fix it.
9. **Every verification command must be runnable from repo root.** The check-must-haves PROJECT_ROOT bug means relative paths only resolve correctly when cwd is the repo root. Each task's Check commands MUST assume `$(pwd)` is the repo root.
10. **No `jq`.** The dispatch path must remain grep/sed/awk-only. `scripts/lib/recipe-parser.sh` is the only YAML reader — do not re-implement YAML parsing inline.

## Tasks

### T01: Section Handlers Library — `scripts/dispatch/lib/section-handlers.sh`

Extract every section-assembly code path currently embedded in `build-context.sh` into a sibling library as pure handler functions. Each handler takes an `<orch_root> <milestone> <phase> <task>` argument set plus optional per-handler arguments and prints the assembled section body to stdout. The library also includes a dispatch helper `dispatch_section_handler <source_type> <section_name> ...` that routes a recipe section to the right handler by source type or filename. No recipe parsing in this library — it is pure section assembly.

Handlers to implement (one function each, all sourced together):

- `handle_computed <orch_root> <milestone> <phase> <task> <section_name>` — returns the State Context block (Current State / Milestone / Phase / Task / Tier). Used by the `state` section.
- `handle_phase_summaries <orch_root> <milestone> <phase> <task>` — returns concatenated upstream phase summaries (the current `gather_upstream_summaries` logic). Used by the `upstream` section.
- `handle_phase_plan <orch_root> <milestone> <phase> <task>` — returns phase plan excerpt (Goal / Demo / Must-Haves). Used by the `scope` section.
- `handle_task_plan <orch_root> <milestone> <phase> <task>` — returns task plan content via `cat $PHASE_DIR/tasks/<task>-PLAN.md`.
- `handle_template <orch_root> <milestone> <phase> <task> <section_name>` — returns a templated constraints block from config defaults (verification criteria, duration budget, dispatch budget, budget enforcement). Used by the `constraints` section.
- `handle_knowledge <orch_root> <milestone> <phase> <task>` — wraps the existing index pipeline (scope-filter → traverse-graph → resolve-entries → increment-hits). Must preserve the included-IDs temp file contract for hit counting.
- `handle_decisions <orch_root> <milestone> <phase> <task>` — wraps the existing scope-filter call for DECISIONS.md.
- `handle_file <orch_root> <milestone> <phase> <task> <source_filename>` — generic file reader for `source: <filename>.md` recipe entries (e.g., `source: KNOWLEDGE.md` dispatches to `handle_knowledge`, `source: DECISIONS.md` to `handle_decisions`, arbitrary `source: FOO.md` to a raw `cat`).

Keep every handler Bash 3.2 and pure: no emit_event, no emit_result. The caller (`build-context.sh`) owns event emission and result reporting.

### T02: Refactor `build-context.sh` — Recipe Interpreter

Rewrite `scripts/dispatch/build-context.sh` so its top-level logic is:

1. Parse args (unchanged shape: `<orch_root> <milestone> <phase> <task> [--config-defaults <f>] [--recipe <f>]`).
2. Source `scripts/lib/errors.sh`, `scripts/lib/events.sh`, `scripts/lib/run-context.sh`, `scripts/lib/recipe-parser.sh`, and `scripts/dispatch/lib/section-handlers.sh`.
3. If `ORCH_RUN_ID` is unset, call `init_run_context "$MILESTONE_ID" "$PHASE_ID"`. Otherwise inherit the engine's run context.
4. Resolve the recipe via `resolve_recipe "$ORCH_ROOT" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" context-recipe.yaml`, falling back to the project-root default (`templates/context-recipe.yaml`). Honor `--recipe <path>` override.
5. Call `parse_recipe_sections <recipe>` and iterate the resulting pipe-delimited lines.
6. For each section, dispatch to the appropriate handler in `section-handlers.sh` by source type. Collect section bodies into `$TMPDIR_BUILD/s<idx>.txt` files (same pattern as current code).
7. Assemble the manifest table from the iterated sections (names, priorities, line counts, token estimates) — same manifest format as the pre-refactor output.
8. Concatenate frontmatter + title + manifest + sections and print to stdout.
9. Emit `emit_event SESSION_START` (when not already set by the engine) and `emit_result ok "" "context assembled: N sections"` on success.

Preserve:
- The `PHASE_PLAN` / planning-payload branch (it is a different assembly path and is out of scope for this phase — keep its code path intact by detecting `TASK_ID=PHASE_PLAN` before recipe iteration and dispatching to a separate `assemble_planning_payload` helper, which keeps the current planning payload logic verbatim for now and sources its own sections. Optionally the planning-payload path can grow its own recipe in a later phase; P05 only refactors the task-dispatch path.).
- Exactly the same section order as the current default (knowledge → decisions → scope → upstream → task_plan → state → constraints for task dispatch). The recipe's `order:` fields produce this order when sorted ascending.
- The stderr "Context payload: X bytes (Y% of total artifacts)" line.
- The included-entry-IDs temp file + `increment-hits.sh` loop at end of file.

Do not modify the `PHASE_PLAN` / planning-payload output at all. The only invariant that matters is that task-dispatch output is unchanged for the default recipe.

### T03: Refactor `compress-payload.sh` — Recipe-Driven Compression

Rewrite `scripts/dispatch/compress-payload.sh` so compression steps are read from the recipe instead of hardcoded. Add a `--recipe <path>` option (defaults to `templates/context-recipe.yaml`). Steps are parsed via `parse_recipe_compression <recipe>` which returns pipe-delimited lines `<step_key>|<type>|<target_sections>|<max_words>|<min_confidence>|<description>`.

Implement per-step-type dispatch:

- `type: drop_optional` → identical to the current step 1 (iterate sections with priority=optional, drop them).
- `type: summarize` + `target_sections: <name>` + `max_words: N` → identical to the current step 2 (truncate each ### subsection in matching sections to N words, inserting `[...truncated...]`).
- `type: drop_lowest_confidence` + `target_sections: knowledge` + `min_confidence: F` → identical to the current step 3 (sort knowledge entries by confidence ascending, drop lowest until under budget OR confidence ≥ F, whichever comes first).
- Any step with an unknown `type` emits a `SAFETY_WARNING reason=unknown_compression_step_type original_type=<type>` via `emit_event` and is skipped.

Also:
- Source errors.sh / events.sh / run-context.sh.
- Emit `emit_event DISPATCH_START stage=compress` at start and `emit_result ok "" "compressed: X→Y tokens"` on success.
- Honor the existing `--budget` and `--input` arguments unchanged (the engine invokes the script with these).
- Preserve the existing "Compressed: X tokens -> Y tokens ..." stderr stats line.
- When the recipe is missing or empty, fall back to the current hardcoded step sequence (so compress-payload.sh still works if the recipe file is missing — standalone mode).

### T04: Refactor `select-model.sh` — Fallback Chains and Retry-on-Fallback

Rewrite `scripts/dispatch/select-model.sh` to read fallback chains from `routing.yaml` via `scripts/lib/recipe-parser.sh`'s `parse_recipe_fallback` function. Add two new flags:

- `--list-fallback` — prints the comma-separated fallback chain for the selected tier (or empty string if no fallback). Does not print the model line.
- `--next-fallback <current-model-id>` — prints the next model in the chain after `<current-model-id>`, or exits 1 if the current model is the last in the chain. Example: `select-model.sh heavy --routing-config templates/routing.yaml --next-fallback claude-opus-4-6` → `claude-sonnet-4-6`.

Preserve the default invocation shape used by the engine: `select-model.sh <tier> --routing-config <file>` → prints `<model-id> <context-budget>` on a single line. Preserve the built-in defaults when no routing config is provided or the file is missing.

Also:
- Source errors.sh / events.sh / run-context.sh.
- Emit `emit_event DISPATCH_START stage=select_model tier=<tier>` at start.
- Emit `emit_event DISPATCH_FALLBACK tier=<tier> from=<cur> to=<next>` when `--next-fallback` returns a new model.
- Emit `emit_result ok "" "selected <model-id> budget=<budget>"` on success, `emit_result error DISPATCH "fallback chain exhausted"` when `--next-fallback` cannot advance.

Note: The engine does NOT need to be rewired to consume `--next-fallback` in this phase. That is the engine's job and will happen when `run.sh` grows retry logic in a later phase. P05 only exposes the retry primitive from `select-model.sh`.

### T05: Integration Parity Verification

Create a self-contained parity harness under `.specify/orchestrator/milestones/M004/phases/P05/fixtures/`:

1. `fixtures/golden-payload-M004-P04-T04.md` — a pre-refactor golden payload captured from `bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04` BEFORE T02 runs. T05 writes this file as part of the task (the agent captures it from git stash / from the current disk before touching anything, or copies the already-generated payload). This fixture is checked into the repo.
2. `fixtures/run-parity.sh` — a shell script that, when run from repo root, regenerates the post-refactor payload, normalizes both payloads (strips the manifest token-count columns and timestamp fields that legitimately vary), and diffs them. Exits 0 if they match modulo normalized columns, 1 otherwise. Must also verify:
   - Sourcing `build-context.sh` successfully emits at least one `EVENT:` line and exactly one `RESULT:` line.
   - `compress-payload.sh` with the default recipe produces the same output as the pre-refactor version for a synthetic oversized input fixture.
   - `select-model.sh heavy --routing-config templates/routing.yaml` still produces `claude-opus-4-6 200000` and `--list-fallback` produces `claude-sonnet-4-6,claude-haiku-4-5`.

The parity harness is also the check target for the phase-level parity truth. It must pass when run from repo root. The harness is NOT executed by check-must-haves.sh — the phase-level grep-style Check command runs `bash .specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh` directly.

## Task Dependencies

```
T01 → T02
T01 → T03   (section handlers used by build-context AND for snapshotting section bodies during compression tests)
T01 → T04   (select-model does not directly use section-handlers but T04 inherits the lib-sourcing pattern T01 establishes)
T02 + T03 + T04 → T05
```

T01 must run first (it creates the library every other task consumes, even T04 which copies its lib-sourcing pattern). T02, T03, T04 can run in parallel after T01. T05 runs last and depends on all three refactors being complete.

Practical execution order the engine will dispatch: `T01 → T02 → T03 → T04 → T05` (sequential — the dependency graph permits parallel T02/T03/T04 but the risk profile of this phase makes sequential execution safer, and the engine does not currently dispatch in parallel anyway).

## Files Likely Touched

- `scripts/dispatch/lib/section-handlers.sh` (create)
- `scripts/dispatch/build-context.sh` (modify — rewrite)
- `scripts/dispatch/compress-payload.sh` (modify — rewrite)
- `scripts/dispatch/select-model.sh` (modify — rewrite)
- `.specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md` (create)
- `.specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh` (create)

No changes to `scripts/engine/run.sh`, no changes to templates, no changes to `scripts/lib/*.sh` (which are P02's output), no changes to any knowledge script, no changes to check-must-haves.sh / events.sh / record-result.sh (those are P06's scope).
