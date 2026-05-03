---
schema_version: "1.0"
type: task-plan
id: "T02"
parent: "P07"
milestone: "M036"
parallelizable: false
---

# T02 — Token-budget governor + relevance ranker + behavioral verifiers

## Goal

Author two pure-lib MEM004 helpers under `scripts/dispatch/lib/` — `reference-budget.sh` (chunk-level token-budget governor with at-least-one-chunk invariant per FR-3 / FR-7 / FR-8) and `reference-relevance.sh` (deterministic four-key relevance ranker resolving Open Question #Q-2). Wire both into the body of `handle_reference` (in `scripts/dispatch/lib/section-handlers.sh`, stubbed by T01) so it now actually pulls + ranks + budget-governs ingested REF-* chunks and emits a `## Reference` markdown body when matches exist.

## Context (zero-context summary)

T01 left `handle_reference()` with an empty body — it returns 0 with no stdout. T02 fills the body. The function reads:

- The task plan's frontmatter: `topic_tags: [...]`, `applies_to_field: [...]`, optional `reference_token_budget: <int>`.
- The recipe's `default_token_budget` (4000) when the task plan does not override.
- Ingested REF-* chunks discovered via `KNOWLEDGE-INDEX.md` (registered by P04's extended `rebuild-index.sh`). Each chunk lives at `knowledge/reference/<category>/REF-*.md` and carries frontmatter `topic_tags: [...]`, `applies_to_field: [...]`, `published: <YYYY-MM-DD>`, `chunk_id: REF-<cat>-<id>`.

The function then:

1. Intersects task-plan scope (`topic_tags ∪ applies_to_field`) against each REF-*'s scope. A chunk matches if at least one task-plan `topic_tag` appears in chunk's `topic_tags` OR at least one task-plan `applies_to_field` appears in chunk's `applies_to_field`.
2. Calls `reference_rank` to sort matches by the four-key tie-break.
3. Calls `reference_apply_budget` to drop chunks at chunk-level granularity until total tokens ≤ budget.
4. For each surviving chunk, emits `### <chunk_id>` + provenance line + chunk body.

If no scope declared OR no matches: emits empty stdout (T01's empty-section discipline persists).

The token estimator is the same character-count / 4 helper already used elsewhere in `build-context.sh` (M018 compression-tier). For chunk-level token estimation, count chunk-file body characters (excluding frontmatter), divide by 4. Conservative; matches existing convention.

## Inputs

API surface this task consumes (from upstream tasks / phases):

- T01: `handle_reference(orch_root, milestone, phase, task)` exists in `section-handlers.sh` with empty body. T02 fills the body in-place.
- T01: `templates/context-recipe.yaml` declares `default_token_budget: 4000` under top-level `reference:` block.
- P04: `tests/fixtures/m036-p04-reference-corpus/cms-rule/REF-cms-rule-fixture-01.md` exists; carries `topic_tags: [pbj-staffing, cms-section-483-20]`, `applies_to_field: [staff_count, census]`, `chunk_id: REF-cms-rule-fixture-01`. Five other valid REF-* fixtures in sibling category directories share the same fixture pattern.
- P04: `KNOWLEDGE-INDEX.md` lists every REF-* chunk after `bash scripts/knowledge/rebuild-index.sh` runs (rebuild-index.sh's `case` block was widened to `MEM*|SPEC-*|REF-*` in P04).
- P05: `scripts/dispatch/scope-filter.sh --tag '[source:<cite_id>]'` is available for explicit operator-asserted source scoping but is NOT the primary match path (see P07-PLAN.md cross-task ordering nuance #2). The primary match is direct `topic_tags ∪ applies_to_field` intersection inside `handle_reference`.

## Files Touched

- `scripts/dispatch/lib/reference-budget.sh` (create)
- `scripts/dispatch/lib/reference-relevance.sh` (create)
- `scripts/dispatch/lib/section-handlers.sh` (modify — fill `handle_reference` body)
- `tools/verify/m036-p07-budget-lib-shape.sh` (create)
- `tools/verify/m036-p07-relevance-lib-shape.sh` (create)
- `tools/verify/m036-p07-budget-chunk-level-granularity.sh` (create)
- `tools/verify/m036-p07-budget-at-least-one-chunk.sh` (create)
- `tools/verify/m036-p07-relevance-deterministic.sh` (create)

## Steps

1. **Author `scripts/dispatch/lib/reference-budget.sh`**. Pure-lib MEM004 — function definitions only, no top-level execution. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # scripts/dispatch/lib/reference-budget.sh — M036 P07 T02 token-budget
   # governor. Pure-lib MEM004 — function definitions only, no top-level
   # execution; sourceable from anywhere. Bash 3.2 / POSIX-sh.
   #
   # Exposes:
   #   reference_apply_budget <chunk_list_file> <budget_tokens>
   #     stdin:  none
   #     args:   chunk_list_file — path to a file with one record per line,
   #                 format: "<chunk_id>|<token_count>|<chunk_path>"
   #             budget_tokens — integer max tokens (chunk-level granularity)
   #     stdout: surviving chunk records (same format as input), in the same
   #             order as the input. Total of token_count column ≤ budget_tokens.
   #     stderr: "WARNING: smallest chunk exceeds budget; emitting one chunk"
   #             when at-least-one-chunk invariant fires.
   #     exit:   0 always (caller treats stdout=empty as no-matches)
   #
   # FR-3 + FR-7: chunk-level granularity — chunks are dropped whole, never
   #              mid-chunk truncated.
   # FR-8: at-least-one-chunk invariant — when budget < smallest matched
   #              chunk size, exactly one chunk is still emitted (with stderr
   #              warning). Choosing the first chunk in input order is correct
   #              because input is already ranked by reference_rank.

   reference_apply_budget() {
     local list_file="$1" budget="$2"
     local total=0
     local emitted=0
     local chunk_id token_count chunk_path

     # Pass 1: emit chunks while running total stays under budget.
     while IFS='|' read -r chunk_id token_count chunk_path; do
       [ -z "$chunk_id" ] && continue
       local next=$((total + token_count))
       if [ "$next" -le "$budget" ]; then
         printf '%s|%s|%s\n' "$chunk_id" "$token_count" "$chunk_path"
         total="$next"
         emitted=$((emitted + 1))
       fi
     done < "$list_file"

     # Pass 2: at-least-one-chunk invariant. If pass 1 emitted nothing
     # (every chunk individually exceeded budget), emit the first chunk
     # in input order with a stderr warning.
     if [ "$emitted" -eq 0 ]; then
       local first_line
       first_line="$(head -n 1 "$list_file" 2>/dev/null || true)"
       if [ -n "$first_line" ]; then
         printf 'WARNING: smallest chunk exceeds budget; emitting one chunk\n' >&2
         printf '%s\n' "$first_line"
       fi
     fi
     return 0
   }
   ```

   Make executable: `chmod +x scripts/dispatch/lib/reference-budget.sh`.

2. **Author `scripts/dispatch/lib/reference-relevance.sh`**. Pure-lib MEM004. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # scripts/dispatch/lib/reference-relevance.sh — M036 P07 T02 relevance
   # ranker. Pure-lib MEM004; sourceable. Bash 3.2 / POSIX-sh.
   #
   # Resolves Open Question #Q-2 (relevance-ordering-signal) from the
   # M036/033-reference-corpus-ingest spec with a deterministic hybrid
   # four-key tie-break. Decision is captured here at the implementation
   # site (matches M036's key_decisions: none posture across P02/P03/P04/P05
   # — reusable conventions, not architectural commitments).
   #
   # Sort keys (descending priority):
   #   1. topic-tag overlap count (higher = more relevant)
   #   2. applies_to_field overlap count (higher = more relevant)
   #   3. published date (newer wins; ISO YYYY-MM-DD lex-sortable)
   #   4. chunk_id lexicographic (deterministic tie-break)
   #
   # Exposes:
   #   reference_rank <candidate_list_file> <task_topic_tags> <task_applies_to_field>
   #     args:   candidate_list_file — path to file, one record per line:
   #                 "<chunk_id>|<chunk_path>|<chunk_topic_tags_csv>|<chunk_applies_to_field_csv>|<published_iso>"
   #             task_topic_tags — comma-separated list of task-plan topic_tags
   #             task_applies_to_field — comma-separated list of task-plan applies_to_field
   #     stdout: ranked records, same format as input, sorted descending by
   #             the four keys. Deterministic byte-for-byte across invocations.
   #     exit:   0 always

   _ref_overlap_count() {
     # _ref_overlap_count <chunk_csv> <task_csv>
     # Emits integer count of tokens present in both CSVs. Comma-separated
     # input. Empty inputs return 0.
     local chunk="$1" task="$2"
     local count=0 t c
     [ -z "$chunk" ] || [ -z "$task" ] && { echo 0; return 0; }
     local IFS_save="$IFS"
     IFS=','
     for t in $task; do
       t="$(printf '%s' "$t" | sed 's/^ *//; s/ *$//')"
       [ -z "$t" ] && continue
       for c in $chunk; do
         c="$(printf '%s' "$c" | sed 's/^ *//; s/ *$//')"
         [ "$c" = "$t" ] && count=$((count + 1))
       done
     done
     IFS="$IFS_save"
     echo "$count"
   }

   reference_rank() {
     local cand_file="$1" task_topics="$2" task_fields="$3"
     local sortkey_file
     sortkey_file="$(mktemp)"
     local chunk_id chunk_path chunk_topics chunk_fields published
     local topic_overlap field_overlap

     while IFS='|' read -r chunk_id chunk_path chunk_topics chunk_fields published; do
       [ -z "$chunk_id" ] && continue
       topic_overlap="$(_ref_overlap_count "$chunk_topics" "$task_topics")"
       field_overlap="$(_ref_overlap_count "$chunk_fields" "$task_fields")"
       # Sort key: pad ints with zeros for lex sort; reverse for descending.
       # Format: <topic_pad>|<field_pad>|<published_neg>|<chunk_id>|<original-record>
       # We use sort -t'|' -k1,1nr -k2,2nr -k3,3r -k4,4 for descending intent.
       printf '%d|%d|%s|%s|%s|%s|%s|%s|%s\n' \
         "$topic_overlap" "$field_overlap" "$published" "$chunk_id" \
         "$chunk_id" "$chunk_path" "$chunk_topics" "$chunk_fields" "$published" \
         >> "$sortkey_file"
     done < "$cand_file"

     # Sort: -k1nr (topic desc) -k2nr (field desc) -k3r (published desc lex)
     # -k4 (chunk_id ascending lex). Then strip the four sort-key prefix fields.
     sort -t'|' -k1,1nr -k2,2nr -k3,3r -k4,4 "$sortkey_file" \
       | awk -F'|' 'BEGIN{OFS="|"} {print $5,$6,$7,$8,$9}'
     rm -f "$sortkey_file"
     return 0
   }
   ```

   Make executable: `chmod +x scripts/dispatch/lib/reference-relevance.sh`.

3. **Fill the body of `handle_reference` in `scripts/dispatch/lib/section-handlers.sh`**. Replace the T01 stub body (`# T01 stub: return empty. T02 will fill the body.\n  return 0`) with the following body. The function signature line and surrounding comment remain unchanged. Verbatim body:

   ```bash
     local orch_root="$1" milestone="$2" phase="$3" task="$4"
     local ms_dir
     ms_dir="$(_sh_resolve_milestone_dir "$orch_root" "$milestone")" || return 0

     # Only meaningful for task dispatch, not phase planning.
     if [ "$task" = "PHASE_PLAN" ]; then
       return 0
     fi

     local task_plan="${ms_dir}/phases/${phase}/tasks/${task}-PLAN.md"
     if [ ! -f "$task_plan" ]; then
       return 0
     fi

     # Resolve project root (where knowledge/ lives).
     local proj_root=""
     case "$(basename "$orch_root")" in
       .orchestrator) proj_root="$(dirname "$orch_root")" ;;
     esac
     if [ -z "$proj_root" ] || [ ! -d "$proj_root/knowledge" ]; then
       if [ -d "$(dirname "$orch_root")/knowledge" ]; then
         proj_root="$(dirname "$orch_root")"
       fi
     fi
     if [ -z "$proj_root" ] || [ ! -d "$proj_root/knowledge" ]; then
       if [ -n "${PROJECT_ROOT:-}" ] && [ -d "${PROJECT_ROOT}/knowledge" ]; then
         proj_root="$PROJECT_ROOT"
       else
         return 0
       fi
     fi

     # Source the budget governor + relevance ranker libs.
     local lib_dir="$proj_root/scripts/dispatch/lib"
     if [ ! -f "$lib_dir/reference-budget.sh" ] || [ ! -f "$lib_dir/reference-relevance.sh" ]; then
       return 0
     fi
     # shellcheck disable=SC1090
     . "$lib_dir/reference-budget.sh"
     # shellcheck disable=SC1090
     . "$lib_dir/reference-relevance.sh"

     # Extract task-plan scope from frontmatter.
     local task_topics task_fields task_budget
     task_topics="$(awk '/^---$/{c++; next} c==1 && /^topic_tags:/{print; exit}' "$task_plan" 2>/dev/null \
       | sed 's/^topic_tags:[[:space:]]*//; s/^\[//; s/\]$//; s/"//g; s/,/ /g; s/  */ /g; s/^ *//; s/ *$//' \
       | tr ' ' ',' \
       | sed 's/^,//; s/,$//')"
     task_fields="$(awk '/^---$/{c++; next} c==1 && /^applies_to_field:/{print; exit}' "$task_plan" 2>/dev/null \
       | sed 's/^applies_to_field:[[:space:]]*//; s/^\[//; s/\]$//; s/"//g; s/,/ /g; s/  */ /g; s/^ *//; s/ *$//' \
       | tr ' ' ',' \
       | sed 's/^,//; s/,$//')"
     task_budget="$(awk '/^---$/{c++; next} c==1 && /^reference_token_budget:/{print; exit}' "$task_plan" 2>/dev/null \
       | sed 's/^reference_token_budget:[[:space:]]*//')"

     # No scope → CON-1 / SC-7 path: emit empty stdout, omit-empty kicks in.
     if [ -z "$task_topics" ] && [ -z "$task_fields" ]; then
       return 0
     fi

     # Default budget from recipe (resolved by build-context.sh and exported
     # as REFERENCE_DEFAULT_BUDGET when known; fallback to 4000).
     if [ -z "$task_budget" ]; then
       task_budget="${REFERENCE_DEFAULT_BUDGET:-4000}"
     fi

     # Enumerate REF-* chunks from KNOWLEDGE-INDEX.md (registered by P04).
     local idx="$proj_root/KNOWLEDGE-INDEX.md"
     if [ ! -f "$idx" ]; then
       return 0
     fi

     local cand_file
     cand_file="$(mktemp)"
     local ref_file ref_id ref_topics ref_fields ref_published
     # Discover REF-* chunks by walking knowledge/reference/**.
     find "$proj_root/knowledge/reference" -type f -name 'REF-*.md' 2>/dev/null \
       | while IFS= read -r ref_file; do
         ref_id="$(awk '/^---$/{c++; next} c==1 && /^chunk_id:/{print; exit}' "$ref_file" 2>/dev/null \
           | sed 's/^chunk_id:[[:space:]]*//; s/"//g; s/^ *//; s/ *$//')"
         [ -z "$ref_id" ] && continue
         ref_topics="$(awk '/^---$/{c++; next} c==1 && /^topic_tags:/{print; exit}' "$ref_file" 2>/dev/null \
           | sed 's/^topic_tags:[[:space:]]*//; s/^\[//; s/\]$//; s/"//g; s/,/ /g; s/  */ /g; s/^ *//; s/ *$//' \
           | tr ' ' ',' | sed 's/^,//; s/,$//')"
         ref_fields="$(awk '/^---$/{c++; next} c==1 && /^applies_to_field:/{print; exit}' "$ref_file" 2>/dev/null \
           | sed 's/^applies_to_field:[[:space:]]*//; s/^\[//; s/\]$//; s/"//g; s/,/ /g; s/  */ /g; s/^ *//; s/ *$//' \
           | tr ' ' ',' | sed 's/^,//; s/,$//')"
         ref_published="$(awk '/^---$/{c++; next} c==1 && /^published:/{print; exit}' "$ref_file" 2>/dev/null \
           | sed 's/^published:[[:space:]]*//; s/"//g; s/^ *//; s/ *$//')"
         [ -z "$ref_published" ] && ref_published="0000-00-00"
         # Match: at least one task topic appears in chunk topics OR at
         # least one task field appears in chunk fields.
         local topic_hit=0 field_hit=0
         topic_hit="$(_ref_overlap_count "$ref_topics" "$task_topics")"
         field_hit="$(_ref_overlap_count "$ref_fields" "$task_fields")"
         if [ "$topic_hit" -gt 0 ] || [ "$field_hit" -gt 0 ]; then
           printf '%s|%s|%s|%s|%s\n' "$ref_id" "$ref_file" "$ref_topics" "$ref_fields" "$ref_published" \
             >> "$cand_file"
         fi
       done

     if [ ! -s "$cand_file" ]; then
       rm -f "$cand_file"
       return 0
     fi

     # Rank, then build a budget-list (chunk_id|token_count|chunk_path).
     local ranked_file ranked_id ranked_path
     ranked_file="$(mktemp)"
     reference_rank "$cand_file" "$task_topics" "$task_fields" > "$ranked_file"
     rm -f "$cand_file"

     local budget_list
     budget_list="$(mktemp)"
     while IFS='|' read -r ranked_id ranked_path _ _ _; do
       [ -z "$ranked_id" ] && continue
       # Token estimate: body chars / 4 (M018 convention).
       local body_chars body_tokens
       body_chars="$(awk '/^---$/{c++; next} c>=2{print}' "$ranked_path" 2>/dev/null | wc -c | tr -d ' ')"
       body_tokens=$(( (body_chars + 3) / 4 ))
       printf '%s|%d|%s\n' "$ranked_id" "$body_tokens" "$ranked_path" >> "$budget_list"
     done < "$ranked_file"
     rm -f "$ranked_file"

     local survived_file
     survived_file="$(mktemp)"
     reference_apply_budget "$budget_list" "$task_budget" > "$survived_file"
     rm -f "$budget_list"

     if [ ! -s "$survived_file" ]; then
       rm -f "$survived_file"
       return 0
     fi

     # Emit the section.
     printf '## Reference\n\n'
     local s_id s_tok s_path
     while IFS='|' read -r s_id s_tok s_path; do
       [ -z "$s_id" ] && continue
       printf '### %s\n\n' "$s_id"
       printf '_source: %s | tokens (estimated): %s_\n\n' "$s_path" "$s_tok"
       awk '/^---$/{c++; next} c>=2{print}' "$s_path"
       printf '\n'
     done < "$survived_file"
     rm -f "$survived_file"
     return 0
   ```

4. **Author `tools/verify/m036-p07-budget-lib-shape.sh`**. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p07-budget-lib-shape.sh — M036 P07 T02 budget-lib
   # token-presence verifier. Asserts reference-budget.sh defines
   # reference_apply_budget with chunk-level granularity and at-least-
   # one-chunk invariant. AD-19 single-script-file shape.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   F="$ROOT/scripts/dispatch/lib/reference-budget.sh"
   pass=0
   fail=0
   check() {
     local label="$1" pat="$2"
     if grep -qF -e "$pat" "$F"; then
       echo "PASS: $label"
       pass=$((pass + 1))
     else
       echo "FAIL: $label (missing: $pat)"
       fail=$((fail + 1))
     fi
   }
   if [ ! -f "$F" ]; then
     echo "FAIL: $F not found"
     echo "SUMMARY: m036-p07-budget-lib-shape.sh pass=0 fail=1"
     exit 1
   fi
   check "fn-defn"               "reference_apply_budget()"
   check "chunk-level-comment"   "chunk-level granularity"
   check "at-least-one-comment"  "at-least-one-chunk invariant"
   check "stderr-warning"        "WARNING: smallest chunk exceeds budget"
   check "MEM004-pure-lib"       "Pure-lib MEM004"
   echo "SUMMARY: m036-p07-budget-lib-shape.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

5. **Author `tools/verify/m036-p07-relevance-lib-shape.sh`**. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p07-relevance-lib-shape.sh — M036 P07 T02
   # relevance-lib token-presence verifier. AD-19.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   F="$ROOT/scripts/dispatch/lib/reference-relevance.sh"
   pass=0
   fail=0
   check() {
     local label="$1" pat="$2"
     if grep -qF -e "$pat" "$F"; then
       echo "PASS: $label"
       pass=$((pass + 1))
     else
       echo "FAIL: $label (missing: $pat)"
       fail=$((fail + 1))
     fi
   }
   if [ ! -f "$F" ]; then
     echo "FAIL: $F not found"
     echo "SUMMARY: m036-p07-relevance-lib-shape.sh pass=0 fail=1"
     exit 1
   fi
   check "fn-defn"             "reference_rank()"
   check "key-1-topic-overlap" "topic-tag overlap"
   check "key-2-field-overlap" "applies_to_field overlap"
   check "key-3-published"     "published date"
   check "key-4-chunk-id-lex"  "chunk_id lexicographic"
   check "Q2-resolution"       "Open Question #Q-2"
   echo "SUMMARY: m036-p07-relevance-lib-shape.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

6. **Author `tools/verify/m036-p07-budget-chunk-level-granularity.sh`**. Behavioral verifier — stages a fixture chunk-list, asserts no mid-chunk truncation. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p07-budget-chunk-level-granularity.sh — M036 P07 T02
   # FR-3 + FR-7 chunk-level granularity behavioral verifier. AD-19.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   LIB="$ROOT/scripts/dispatch/lib/reference-budget.sh"
   if [ ! -f "$LIB" ]; then
     echo "FAIL: $LIB not found"
     echo "SUMMARY: m036-p07-budget-chunk-level-granularity.sh pass=0 fail=1"
     exit 1
   fi
   # shellcheck disable=SC1090
   . "$LIB"
   WS="$(mktemp -d)"
   trap 'rm -rf "$WS"' EXIT
   IN="$WS/in.txt"
   OUT="$WS/out.txt"
   # Six chunks at 2000 tokens each = 12000 tokens; budget = 4000.
   # Expected: first two chunks survive (4000 total); last four dropped.
   {
     printf 'CHUNK-A|2000|/path/A\n'
     printf 'CHUNK-B|2000|/path/B\n'
     printf 'CHUNK-C|2000|/path/C\n'
     printf 'CHUNK-D|2000|/path/D\n'
     printf 'CHUNK-E|2000|/path/E\n'
     printf 'CHUNK-F|2000|/path/F\n'
   } > "$IN"
   reference_apply_budget "$IN" 4000 > "$OUT"
   pass=0
   fail=0
   # Assertion 1: total tokens ≤ budget.
   total="$(awk -F'|' '{ s += $2 } END { print s+0 }' "$OUT")"
   if [ "$total" -le 4000 ]; then
     echo "PASS: total-tokens-le-budget (total=$total budget=4000)"
     pass=$((pass + 1))
   else
     echo "FAIL: total-tokens-exceed-budget (total=$total budget=4000)"
     fail=$((fail + 1))
   fi
   # Assertion 2: every emitted line has the full token-count of its source
   # (no mid-chunk truncation — chunk-level granularity).
   if awk -F'|' '$2 != 2000 { exit 1 }' "$OUT"; then
     echo "PASS: no-mid-chunk-truncation"
     pass=$((pass + 1))
   else
     echo "FAIL: mid-chunk-truncation-detected"
     fail=$((fail + 1))
   fi
   # Assertion 3: at least one chunk emitted.
   emitted="$(wc -l < "$OUT" | tr -d ' ')"
   if [ "$emitted" -ge 1 ]; then
     echo "PASS: at-least-one-chunk-emitted (emitted=$emitted)"
     pass=$((pass + 1))
   else
     echo "FAIL: zero-chunks-emitted"
     fail=$((fail + 1))
   fi
   echo "SUMMARY: m036-p07-budget-chunk-level-granularity.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

7. **Author `tools/verify/m036-p07-budget-at-least-one-chunk.sh`**. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p07-budget-at-least-one-chunk.sh — M036 P07 T02
   # FR-8 at-least-one-chunk invariant behavioral verifier. AD-19.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   LIB="$ROOT/scripts/dispatch/lib/reference-budget.sh"
   if [ ! -f "$LIB" ]; then
     echo "FAIL: $LIB not found"
     echo "SUMMARY: m036-p07-budget-at-least-one-chunk.sh pass=0 fail=1"
     exit 1
   fi
   # shellcheck disable=SC1090
   . "$LIB"
   WS="$(mktemp -d)"
   trap 'rm -rf "$WS"' EXIT
   IN="$WS/in.txt"
   OUT="$WS/out.txt"
   ERR="$WS/err.txt"
   # Single chunk at 500 tokens; budget = 10. Smallest chunk exceeds
   # budget, so FR-8 invariant fires: emit one chunk + stderr warning.
   printf 'CHUNK-X|500|/path/X\n' > "$IN"
   reference_apply_budget "$IN" 10 > "$OUT" 2> "$ERR"
   pass=0
   fail=0
   emitted="$(wc -l < "$OUT" | tr -d ' ')"
   if [ "$emitted" -eq 1 ]; then
     echo "PASS: exactly-one-chunk-emitted"
     pass=$((pass + 1))
   else
     echo "FAIL: emitted=$emitted (expected 1)"
     fail=$((fail + 1))
   fi
   if grep -qF -e "WARNING: smallest chunk exceeds budget" "$ERR"; then
     echo "PASS: stderr-warning-emitted"
     pass=$((pass + 1))
   else
     echo "FAIL: stderr-warning-missing"
     fail=$((fail + 1))
   fi
   echo "SUMMARY: m036-p07-budget-at-least-one-chunk.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

8. **Author `tools/verify/m036-p07-relevance-deterministic.sh`**. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p07-relevance-deterministic.sh — M036 P07 T02
   # determinism + tie-break verifier. AD-19.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   LIB="$ROOT/scripts/dispatch/lib/reference-relevance.sh"
   if [ ! -f "$LIB" ]; then
     echo "FAIL: $LIB not found"
     echo "SUMMARY: m036-p07-relevance-deterministic.sh pass=0 fail=1"
     exit 1
   fi
   # shellcheck disable=SC1090
   . "$LIB"
   WS="$(mktemp -d)"
   trap 'rm -rf "$WS"' EXIT
   IN="$WS/in.txt"
   O1="$WS/out1.txt"
   O2="$WS/out2.txt"
   # 4 candidates; task topics = "pbj-staffing"; task fields = "staff_count".
   # Expected order:
   #   REF-A — topic match (1) + field match (1) + 2026-01 → highest
   #   REF-B — topic match (1) + field match (0) + 2025-06 → second
   #   REF-C — topic match (0) + field match (1) + 2025-01 → third
   #   REF-D — same as REF-C scores but lex chunk_id breaks tie below it
   {
     printf 'REF-A|/p/A|pbj-staffing,other|staff_count|2026-01-01\n'
     printf 'REF-B|/p/B|pbj-staffing|other|2025-06-01\n'
     printf 'REF-D|/p/D|other|staff_count|2025-01-01\n'
     printf 'REF-C|/p/C|other|staff_count|2025-01-01\n'
   } > "$IN"
   reference_rank "$IN" "pbj-staffing" "staff_count" > "$O1"
   reference_rank "$IN" "pbj-staffing" "staff_count" > "$O2"
   pass=0
   fail=0
   if cmp -s "$O1" "$O2"; then
     echo "PASS: deterministic-byte-equality"
     pass=$((pass + 1))
   else
     echo "FAIL: nondeterministic-output"
     fail=$((fail + 1))
   fi
   first="$(head -n 1 "$O1" | cut -d'|' -f1)"
   if [ "$first" = "REF-A" ]; then
     echo "PASS: highest-rank-is-REF-A"
     pass=$((pass + 1))
   else
     echo "FAIL: highest-rank-was-$first-expected-REF-A"
     fail=$((fail + 1))
   fi
   second="$(sed -n '2p' "$O1" | cut -d'|' -f1)"
   if [ "$second" = "REF-B" ]; then
     echo "PASS: second-rank-is-REF-B"
     pass=$((pass + 1))
   else
     echo "FAIL: second-rank-was-$second-expected-REF-B"
     fail=$((fail + 1))
   fi
   third="$(sed -n '3p' "$O1" | cut -d'|' -f1)"
   fourth="$(sed -n '4p' "$O1" | cut -d'|' -f1)"
   if [ "$third" = "REF-C" ] && [ "$fourth" = "REF-D" ]; then
     echo "PASS: chunk-id-lex-tie-break-C-before-D"
     pass=$((pass + 1))
   else
     echo "FAIL: tie-break-third=$third-fourth=$fourth-expected-C-then-D"
     fail=$((fail + 1))
   fi
   echo "SUMMARY: m036-p07-relevance-deterministic.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

9. Make all five new verifier scripts executable.

## Must-Haves (subset T02 addresses)

- `scripts/dispatch/lib/reference-budget.sh` defines `reference_apply_budget()` with chunk-level granularity (no mid-chunk truncation) and the at-least-one-chunk invariant.
- `scripts/dispatch/lib/reference-relevance.sh` defines `reference_rank()` with the documented hybrid four-key sort.
- The token-budget governor drops chunks at chunk-level granularity (FR-3, FR-7) — no chunk_id is emitted partially when total exceeds budget.
- The token-budget governor satisfies FR-8 at-least-one-chunk invariant.
- `reference_rank` is deterministic and the four-key tie-break order is honored.

## Verification

```bash
bash tools/verify/m036-p07-budget-lib-shape.sh
bash tools/verify/m036-p07-relevance-lib-shape.sh
bash tools/verify/m036-p07-budget-chunk-level-granularity.sh
bash tools/verify/m036-p07-budget-at-least-one-chunk.sh
bash tools/verify/m036-p07-relevance-deterministic.sh
```

## Notes

T02 wires the live body of `handle_reference` but no task plan in the orchestrator's repo today declares `topic_tags` or `applies_to_field`, so the production dispatch path remains unchanged in practice. The only paths that exercise the new body are:

- T03's omit-empty-section verifier (drives a fixture task plan with non-matching topic_tags).
- T04's SC-3 acceptance harness (drives the topic-tags fixture against the P04 reference corpus).
- T04's SC-7 acceptance harness (drives the no-scope fixture; expects empty section).

CON-1 is preserved across T02 because: (a) no task plan in the repo declares `topic_tags`/`applies_to_field`; (b) for any plan that does, T01's recipe addition with `priority: optional` + omit-empty-section gating ensures the section is dropped when the body returns empty; (c) the body returns empty when no matches exist OR no scope declared.

Expected verifier output: each emits one `SUMMARY:` line; budget-chunk-level-granularity reports `pass=3 fail=0`; budget-at-least-one-chunk reports `pass=2 fail=0`; relevance-deterministic reports `pass=4 fail=0`; the two shape verifiers report `pass=5 fail=0` and `pass=6 fail=0` respectively.
