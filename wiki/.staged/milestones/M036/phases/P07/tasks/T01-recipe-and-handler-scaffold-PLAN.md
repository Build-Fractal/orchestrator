---
schema_version: "1.0"
type: task-plan
id: "T01"
parent: "P07"
milestone: "M036"
parallelizable: false
---

# T01 — Recipe extension + handle_reference scaffold + shape verifiers

## Goal

Land the dispatch-recipe declaration for the new `reference:` section and the empty-stub `handle_reference` section-handler in `scripts/dispatch/lib/section-handlers.sh`, plus a dispatcher case-branch routing `source: reference` to it. T01's stub returns empty stdout for every input — payload behavior is unchanged from pre-T01 (CON-1 preserved). T02 fills the body with the budget governor + relevance ranker.

## Context (zero-context summary)

The orchestrator's dispatch context-builder lives at `scripts/dispatch/build-context.sh`. It reads a YAML recipe (default `templates/context-recipe.yaml`) declaring named sections (`knowledge`, `decisions`, `scope`, `upstream`, `task_plan`, `state`, `constraints`, `spec_context`). For each section, it calls `dispatch_section_handler` defined in `scripts/dispatch/lib/section-handlers.sh`. The dispatcher routes by the `source:` field — e.g. `source: spec_context` routes to `handle_spec_context()`. This task adds a parallel `source: reference` slot and an empty-stub handler.

`handle_reference` will eventually (T02) read the task-plan's `topic_tags` + `applies_to_field` frontmatter, intersect against ingested `knowledge/reference/**/REF-*.md` chunks (P04), apply a token-budget governor (T02) and emit a `## Reference` markdown body. T01 stubs the body to return empty so the dispatcher routing wires up without changing payload shape.

The omit-empty-section discipline already exists in `build-context.sh` for `spec_context` — when the handler returns empty stdout the section is dropped entirely (no manifest row, no header). T01 piggybacks on that exact mechanism by returning empty.

## Inputs

Files this task reads (no edits):

- `templates/context-recipe.yaml` (existing) — YAML recipe declaring sections. Schema: top-level `sections:` map with per-section `source` / `priority` / `order` / `filter` / `cache_hint`. T01 amends additively.
- `scripts/dispatch/lib/section-handlers.sh` (existing) — defines `handle_spec_context()` (line ~480) as the canonical pattern to mirror. Defines `dispatch_section_handler()` (line ~660) as the source-router. `handle_spec_context` reads `task_plan` frontmatter `scope_tags`, filters spec/* tokens, calls `scope-filter.sh`, emits `## Spec Context` markdown body.
- `scripts/dispatch/build-context.sh` (existing) — calls `dispatch_section_handler` (line ~1983) and applies omit-empty-section gating for `spec_context` at line ~1995. T01 does NOT edit this file (T03 will).

API surface T02 will consume from T01's deliverables:

- `handle_reference(orch_root, milestone, phase, task)` — function signature mirrors `handle_spec_context`. Returns 0 always. Stdout: empty in T01; `## Reference` markdown body in T02.
- `dispatch_section_handler` recognizes `source: reference` and routes to `handle_reference`.

## Files Touched

- `templates/context-recipe.yaml` (modify) — add new `reference:` section block + new top-level `reference:` recipe block declaring `default_token_budget: 4000`.
- `scripts/dispatch/lib/section-handlers.sh` (modify) — add `handle_reference()` empty-stub function + add `reference)` case-arm to `dispatch_section_handler()`.
- `tools/verify/m036-p07-recipe-shape.sh` (create)
- `tools/verify/m036-p07-handler-shape.sh` (create)

## Steps

1. **Amend `templates/context-recipe.yaml`**. Insert the following block under the `sections:` map immediately after the existing `spec_context:` block (preserve current indentation — 2 spaces for keys, 4 for sub-keys):

   ```yaml
     reference:
       source: reference
       priority: optional
       order: 45
       filter: scope
       cache_hint: semi-static
   ```

   Then append a new top-level block AFTER the `manifest:` block at the end of the file (separated by a blank line):

   ```yaml
   # --- Reference Chunk Injection (M036/P07) ---
   # Token budget for the reference: section. Per-task override via the
   # task plan's frontmatter field `reference_token_budget`. Per FR-8,
   # chunk-level dropping is mandatory (no mid-chunk truncation); per FR-8's
   # at-least-one-chunk invariant, when budget < smallest matched chunk
   # exactly one chunk is still emitted (with a stderr warning).

   reference:
     default_token_budget: 4000
   ```

2. **Author `handle_reference` in `scripts/dispatch/lib/section-handlers.sh`**. Insert the following function definition immediately AFTER `handle_spec_context()` ends (search for the closing `}` of `handle_spec_context` — typically before the dispatcher's section-divider comment block). Verbatim body (T01 stub — empty body returns nothing on stdout):

   ```bash
   # handle_reference <orch_root> <milestone> <phase> <task>
   # Emits the `## Reference` section for dispatch payloads. Reads the
   # task-plan's frontmatter `topic_tags` + `applies_to_field` + optional
   # `reference_token_budget`, intersects against ingested
   # knowledge/reference/**/REF-*.md chunks, ranks via reference_rank
   # (reference-relevance.sh), governs by reference_apply_budget
   # (reference-budget.sh), and emits the survivors inline.
   #
   # T01 stubs the body — returns empty stdout. T02 fills the body with
   # the budget governor + relevance ranker invocations. T03 wires the
   # dispatcher in build-context.sh.
   #
   # Empty stdout is honored by build-context.sh's omit-empty-section
   # discipline (carried from handle_spec_context — see build-context.sh
   # line ~1995). When stdout is empty the entire `## Reference` header,
   # manifest row, and section body are dropped — preserving CON-1 /
   # SC-7 byte-identical pre-feature payloads.
   handle_reference() {
     local orch_root="$1" milestone="$2" phase="$3" task="$4"
     # T01 stub: return empty. T02 will fill the body.
     return 0
   }
   ```

3. **Add the `reference)` case-arm to `dispatch_section_handler()`** in the same file (`scripts/dispatch/lib/section-handlers.sh`). The existing case statement starts at the `case "$source" in` line near `dispatch_section_handler()` (line ~664). Insert the `reference)` arm immediately AFTER the existing `spec_context)` arm and BEFORE the `*.md)` arm. Verbatim:

   ```bash
       reference)
         handle_reference "$orch_root" "$milestone" "$phase" "$task"
         ;;
   ```

4. **Author `tools/verify/m036-p07-recipe-shape.sh`**. Single-script-file shape per AD-19; Bash 3.2; `set -eu`; `grep -qF -e` for leading-dash safety; structured PASS/FAIL/SUMMARY stdout per MEM001. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p07-recipe-shape.sh — M036 P07 T01 recipe-shape
   # verifier. Asserts templates/context-recipe.yaml declares the new
   # reference: section block + default_token_budget per the M036/P07
   # plan. Single-script-file shape (AD-19). Bash 3.2 / POSIX-sh.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   F="$ROOT/templates/context-recipe.yaml"
   pass=0
   fail=0

   check() {
     local label="$1" pattern="$2"
     if grep -qF -e "$pattern" "$F"; then
       echo "PASS: $label"
       pass=$((pass + 1))
     else
       echo "FAIL: $label (missing token: $pattern)"
       fail=$((fail + 1))
     fi
   }

   if [ ! -f "$F" ]; then
     echo "FAIL: $F not found"
     echo "SUMMARY: m036-p07-recipe-shape.sh pass=0 fail=1"
     exit 1
   fi

   check "reference-section-key"       "reference:"
   check "reference-section-source"    "source: reference"
   check "reference-section-priority"  "priority: optional"
   check "reference-section-order"     "order: 45"
   check "reference-block-budget"      "default_token_budget: 4000"

   echo "SUMMARY: m036-p07-recipe-shape.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then
     exit 1
   fi
   exit 0
   ```

   Make executable: `chmod +x tools/verify/m036-p07-recipe-shape.sh`.

5. **Author `tools/verify/m036-p07-handler-shape.sh`**. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p07-handler-shape.sh — M036 P07 T01 handler-shape
   # verifier. Asserts scripts/dispatch/lib/section-handlers.sh defines
   # handle_reference() and the dispatcher routes source: reference to it.
   # Single-script-file shape (AD-19). Bash 3.2 / POSIX-sh.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   F="$ROOT/scripts/dispatch/lib/section-handlers.sh"
   pass=0
   fail=0

   check() {
     local label="$1" pattern="$2"
     if grep -qF -e "$pattern" "$F"; then
       echo "PASS: $label"
       pass=$((pass + 1))
     else
       echo "FAIL: $label (missing token: $pattern)"
       fail=$((fail + 1))
     fi
   }

   if [ ! -f "$F" ]; then
     echo "FAIL: $F not found"
     echo "SUMMARY: m036-p07-handler-shape.sh pass=0 fail=1"
     exit 1
   fi

   check "handle-reference-defn"   "handle_reference()"
   check "dispatcher-case-arm"     "reference)"
   check "dispatcher-invocation"   'handle_reference "$orch_root"'
   check "stub-comment-T01"        "T01 stub"

   echo "SUMMARY: m036-p07-handler-shape.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then
     exit 1
   fi
   exit 0
   ```

   Make executable: `chmod +x tools/verify/m036-p07-handler-shape.sh`.

## Must-Haves (subset of phase must-haves T01 addresses)

- The default context recipe declares a `reference:` section with `source: reference`, `priority: optional`, `order: 45`, `filter: scope`, `cache_hint: semi-static`, and a top-level `reference:` block declaring `default_token_budget: 4000`.
- `scripts/dispatch/lib/section-handlers.sh` defines `handle_reference()` and the dispatcher routes `source: reference` to it.

## Verification

```bash
bash tools/verify/m036-p07-recipe-shape.sh
bash tools/verify/m036-p07-handler-shape.sh
```

## Notes

Expected output (per verifier): five `PASS:` lines + one `SUMMARY: m036-p07-recipe-shape.sh pass=5 fail=0` for recipe-shape; four `PASS:` lines + one `SUMMARY: m036-p07-handler-shape.sh pass=4 fail=0` for handler-shape. Each verifier exits 0 on full pass.

T01's empty-stub handler ensures the new `reference:` section's `priority: optional` + omit-empty-section gating combine to drop the section entirely from every payload — so T01 lands without changing any existing payload byte-for-byte. T03 will capture the pre-feature baseline AFTER T01+T02 land but BEFORE T03's dispatcher map edits — that ordering is correct because the omit-empty section gating means T01+T02 produce zero payload delta on no-scope task plans, while T03's display-order / name / priority / volatility map edits are the only changes that COULD perturb the payload shape (manifest table ordering). The SC-7 baseline must therefore be captured immediately before T03's map edits, not before T01.
