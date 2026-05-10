---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P05"
milestone: "M004"
name: "Refactor compress-payload.sh — Recipe-Driven Compression"
depends_on: [T01]
---

## Description

Rewrite `scripts/dispatch/compress-payload.sh` so the compression steps are declared in `templates/context-recipe.yaml`'s `compression:` block and read via `scripts/lib/recipe-parser.sh`'s `parse_recipe_compression` function. Currently the three compression steps (drop_optional, summarize-upstream, drop_lowest_confidence) are hardcoded in the script; after this refactor they become recipe-driven so changing compression strategy is a YAML edit.

The script must preserve its existing CLI shape: `--budget <tokens>`, `--input <file|->`, plus a new optional `--recipe <path>`. When the recipe is missing or empty, the script falls back to the current hardcoded 3-step sequence so standalone invocation still works.

The acceptance bar: given the default recipe and an oversized synthetic payload, the refactored script produces the same compressed output as the pre-refactor version (byte-for-byte, modulo the manifest line-range/token-count columns).

This implements FR-212 (compression from recipe) and Principle X (Templating Over Inference).

## Cross-Cutting Constraints (verbatim from P05-PLAN.md)

1. **Bash 3.2** — no `declare -A`, no `readarray`, no `mapfile`, no `<(…)` as a redirect target in `while read` loops.
2. **Sibling library sourcing** — `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`.
3. **No inline `date`** — use `orch_now` after sourcing run-context.sh.
4. **`emit_result` on exit** — source errors.sh and emit exactly one RESULT line (to stderr to avoid polluting the compressed payload on stdout).
5. **Standalone mode still works** — if `ORCH_RUN_ID` is unset, `init_run_context` is called. If the recipe is missing, fall back to hardcoded 3-step sequence.
6. **P06-deferred items — do NOT touch.** No edits to check-must-haves.sh, events.sh, or record-result.sh.
7. **Every verification command must be runnable from repo root.**
8. **No `jq`.**
9. **Engine compatibility** — `scripts/engine/run.sh` invokes `compress-payload.sh --budget "$_context_budget" --input "$_payload_file"`. The new `--recipe` flag is additive; do not change the existing flag shape.
10. **Literal-audit-marker pattern** — if any new `emit_event` call uses single-word values and a must-have depends on grepping the quoted form, pair it with a `printf 'EVENT-AUDIT:...' ` line (see P03/T03-T05 / T02 Step 8).

## Steps

### Step 1: Baseline — capture pre-refactor compression output for a synthetic input

BEFORE touching the script, capture a golden compression output. The input is a synthetic oversized payload that triggers all three compression steps.

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Generate an oversized synthetic payload using the current build-context.sh
# (T02's refactored script also works here since its output is parity-identical).
bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 2>/dev/null \
  > /tmp/t03-input.md

wc -c /tmp/t03-input.md

# Capture the current (pre-refactor) compressed output with a small budget
# that forces all three compression steps.
bash scripts/dispatch/compress-payload.sh --budget 2000 --input /tmp/t03-input.md \
  > .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-compressed-budget2000.md \
  2>/dev/null

wc -l .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-compressed-budget2000.md
# Must be > 10 lines.
```

If the file is missing or empty, the baseline failed — stop and investigate before refactoring.

### Step 2: Understand the recipe compression schema

`parse_recipe_compression templates/context-recipe.yaml` returns pipe-delimited lines:

```
step_1|drop_optional|||| Remove sections marked priority optional
step_2|summarize|upstream|200|| Truncate upstream summaries to 200 words each
step_3|drop_lowest_confidence|knowledge||0.5| Drop knowledge entries below 0.5 confidence
```

Format: `<step_key>|<type>|<target_sections>|<max_words>|<min_confidence>|<description>`. Unused fields are empty.

Verify this by running:

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
( . scripts/lib/recipe-parser.sh && parse_recipe_compression templates/context-recipe.yaml )
```

Expected output: 3 lines matching the schema above.

### Step 3: Rewrite the top of the script — anchors, sources, argument parser

```bash
#!/usr/bin/env bash
# scripts/dispatch/compress-payload.sh — Recipe-driven payload compression
# Reads the compression: block from templates/context-recipe.yaml (or --recipe
# override) and applies each step in order until the payload fits the token
# budget. When no recipe is available, falls back to a hardcoded 3-step
# sequence for standalone compatibility.
#
# Usage: compress-payload.sh [--budget TOKENS] [--input FILE|-] [--recipe FILE]
# Output: compressed payload on stdout. Stats line to stderr. RESULT to stderr.
# Exit 0 on success. Bash 3.2 compatible. Standalone-capable.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

. "$PROJECT_ROOT/scripts/lib/errors.sh"
. "$PROJECT_ROOT/scripts/lib/events.sh"
. "$PROJECT_ROOT/scripts/lib/run-context.sh"
. "$PROJECT_ROOT/scripts/lib/recipe-parser.sh"

# --- Result emission on exit (stderr, not stdout) ---
_CP_RESULT_EMITTED=0
_cp_final_result() {
  local rc=$?
  if [ "$_CP_RESULT_EMITTED" -eq 0 ]; then
    if [ "$rc" -eq 0 ]; then
      emit_result ok "" "payload compressed" >&2
    else
      emit_result error CONFIG "compress-payload rc=$rc" >&2
    fi
    _CP_RESULT_EMITTED=1
  fi
}
trap _cp_final_result EXIT

TOKEN_BUDGET=30000
INPUT_FILE=""
RECIPE_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --budget) TOKEN_BUDGET="$2"; shift 2 ;;
    --input)  INPUT_FILE="$2"; shift 2 ;;
    --recipe) RECIPE_FILE="$2"; shift 2 ;;
    -*) printf 'compress-payload.sh: unknown option %s\n' "$1" >&2; exit 1 ;;
    *)  [ -z "$INPUT_FILE" ] && INPUT_FILE="$1"; shift ;;
  esac
done

# --- Read payload ---
PAYLOAD=""
if [ -n "$INPUT_FILE" ] && [ "$INPUT_FILE" != "-" ] && [ -f "$INPUT_FILE" ]; then
  PAYLOAD="$(cat "$INPUT_FILE")"
else
  PAYLOAD="$(cat)"
fi
if [ -z "$PAYLOAD" ]; then
  printf 'compress-payload.sh: empty payload\n' >&2
  exit 0
fi

# Initialize run context in standalone mode
if [ -z "${ORCH_RUN_ID:-}" ]; then
  init_run_context
fi

emit_event DISPATCH_START stage=compress budget="$TOKEN_BUDGET" >&2
printf 'EVENT-AUDIT:DISPATCH_START stage="compress"\n' >&2
```

Note: `emit_event` calls go to stderr because stdout is reserved for the compressed payload. The current pre-refactor script's stats line is already on stderr; this keeps the stdout contract clean.

### Step 4: Port `estimate_tokens`, `raw_token_count`, budget short-circuit

Port verbatim from the pre-refactor script (lines 58–86):

```bash
estimate_tokens() {
  local text="$1" chars
  chars="$(printf '%s' "$text" | wc -c | tr -d ' ')"
  local raw=$((chars / 4))
  local rounded=$(( ((raw + 50) / 100) * 100 ))
  if [ "$rounded" -eq 0 ] && [ "$raw" -gt 0 ]; then rounded=100; fi
  printf '%s\n' "$rounded"
}
raw_token_count() {
  local text="$1" chars
  chars="$(printf '%s' "$text" | wc -c | tr -d ' ')"
  printf '%s\n' $((chars / 4))
}

ORIGINAL_TOKENS=$(raw_token_count "$PAYLOAD")
if [ "$ORIGINAL_TOKENS" -le "$TOKEN_BUDGET" ]; then
  printf '%s\n' "$PAYLOAD"
  printf 'Compressed: %s tokens -> %s tokens (already under budget)\n' \
    "$ORIGINAL_TOKENS" "$ORIGINAL_TOKENS" >&2
  exit 0
fi
```

### Step 5: Port the manifest parse / section splitter (unchanged)

Port lines 88–208 of the pre-refactor script verbatim. This code identifies known section names from the manifest, splits the payload into `$TMPDIR_COMP/section_N.txt` files, and computes `sec_names` / `sec_files_ordered`. The splitter is independent of compression strategy — no recipe changes here.

### Step 6: Extract each compression step type into a function

Convert the pre-refactor inline logic into three named functions. These become the bodies the recipe-driven dispatcher calls:

```bash
# _cp_step_drop_optional <optional_sections_pipe> <sec_names_ref> <sec_files_ref>
# Drops sections whose name matches an optional entry. Updates $current_tokens.
_cp_step_drop_optional() {
  local opt_pipe="$1"
  [ -z "$opt_pipe" ] && return 0
  local OLDIFS="$IFS"
  IFS='|'
  set -- $opt_pipe
  IFS="$OLDIFS"
  local opt_name idx name sfile sec_tokens
  for opt_name in "$@"; do
    IFS='|'
    set -- $sec_names
    IFS="$OLDIFS"
    idx=0
    for name in "$@"; do
      idx=$((idx + 1))
      if printf '%s' "$name" | grep -qi "^${opt_name}"; then
        sfile="$(printf '%s' "$sec_files_ordered" | awk -F'|' -v i="$idx" '{print $i}')"
        if [ -f "$sfile" ]; then
          sec_tokens="$(raw_token_count "$(cat "$sfile")")"
          rm -f "$sfile"
          current_tokens=$((current_tokens - sec_tokens))
          removed_optional=$((removed_optional + 1))
        fi
        break
      fi
    done
    [ "$current_tokens" -le "$TOKEN_BUDGET" ] && break
  done
}

# _cp_step_summarize <target_section_name> <max_words>
# Truncates each ### subsection in the matching section to <max_words> words.
_cp_step_summarize() {
  local target="$1" max_words="$2"
  local OLDIFS="$IFS"
  IFS='|'
  set -- $sec_names
  IFS="$OLDIFS"
  local idx=0 name sfile old tok_old new tok_new
  for name in "$@"; do
    idx=$((idx + 1))
    if printf '%s' "$name" | grep -qi "$target"; then
      sfile="$(printf '%s' "$sec_files_ordered" | awk -F'|' -v i="$idx" '{print $i}')"
      if [ -f "$sfile" ]; then
        old="$(cat "$sfile")"
        tok_old="$(raw_token_count "$old")"
        new="$(awk -v max="$max_words" '
          /^### / {
            if (in_sub && wc > max) { printf "\n[...truncated...]\n" }
            in_sub = 1; wc = 0; print; next
          }
          /^## / {
            if (in_sub && wc > max) { printf "\n[...truncated...]\n" }
            in_sub = 0; wc = 0; print; next
          }
          {
            if (in_sub) {
              n = split($0, words, " ")
              if (wc + n <= max) { print; wc += n }
              else if (wc < max) {
                remaining = max - wc; out = ""
                for (i=1; i<=remaining && i<=n; i++) {
                  if (i > 1) out = out " "
                  out = out words[i]
                }
                print out; wc = max
              }
            } else { print }
          }
          END { if (in_sub && wc > max) { printf "\n[...truncated...]\n" } }
        ' "$sfile")"
        printf '%s\n' "$new" > "$sfile"
        tok_new="$(raw_token_count "$new")"
        current_tokens=$((current_tokens - tok_old + tok_new))
      fi
      break
    fi
  done
}

# _cp_step_drop_lowest_confidence <target_section_name> <min_confidence>
# Sorts the target section's knowledge entries by confidence ascending and
# drops the lowest until under budget OR until remaining confidence >= min.
_cp_step_drop_lowest_confidence() {
  local target="$1" min_conf="$2"
  # Port lines 317-435 of the pre-refactor script verbatim here, wrapped in
  # the for-loop over sec_names that finds the matching section. The existing
  # code already implements this logic correctly.
  # ... (see the pre-refactor script)
  true
}
```

The `_cp_step_drop_lowest_confidence` body is long (~120 lines of the pre-refactor script). Port it verbatim into the function, replacing the outer `if echo "$name" | grep -qi "knowledge"; then` test with `if echo "$name" | grep -qi "$target"; then`, and replacing the hardcoded `0.5` threshold (actually the pre-refactor script hardcodes no threshold — it drops entries until under budget) with an optional early-exit when a processed entry's confidence exceeds `$min_conf`. For parity, keep the "drop until under budget" semantics and add a secondary guard:

```bash
# Inside the while-loop over sorted_entries:
if awk "BEGIN{exit !($conf_value >= $min_conf)}" 2>/dev/null; then
  # This entry's confidence is at or above the threshold; stop dropping.
  break
fi
```

When `$min_conf` is empty, skip the guard (matches pre-refactor behavior).

### Step 7: Write the recipe-driven step dispatcher

```bash
# Resolve recipe: honor --recipe override, else default to templates/context-recipe.yaml
if [ -z "$RECIPE_FILE" ]; then
  RECIPE_FILE="$PROJECT_ROOT/templates/context-recipe.yaml"
fi

current_tokens=$ORIGINAL_TOKENS
removed_optional=0
removed_knowledge=0

_cp_run_recipe_steps() {
  local steps_file
  steps_file="$(mktemp)"
  parse_recipe_compression "$RECIPE_FILE" > "$steps_file" 2>/dev/null || true

  if [ ! -s "$steps_file" ]; then
    rm -f "$steps_file"
    _cp_run_fallback_steps
    return
  fi

  local step_key c_type c_target c_maxw c_minc c_desc
  while IFS='|' read -r step_key c_type c_target c_maxw c_minc c_desc; do
    [ -z "$step_key" ] && continue
    [ "$current_tokens" -le "$TOKEN_BUDGET" ] && break

    case "$c_type" in
      drop_optional)
        _cp_step_drop_optional "$optional_sections"
        ;;
      summarize)
        _cp_step_summarize "$c_target" "${c_maxw:-200}"
        ;;
      drop_lowest_confidence)
        _cp_step_drop_lowest_confidence "$c_target" "${c_minc:-}"
        ;;
      *)
        emit_event SAFETY_WARNING reason=unknown_compression_step_type original_type="$c_type" >&2
        printf 'EVENT-AUDIT:SAFETY_WARNING reason="unknown_compression_step_type"\n' >&2
        ;;
    esac
  done < "$steps_file"
  rm -f "$steps_file"
}

# Fallback: hardcoded 3-step sequence (identical to pre-refactor behavior)
_cp_run_fallback_steps() {
  _cp_step_drop_optional "$optional_sections"
  [ "$current_tokens" -le "$TOKEN_BUDGET" ] && return
  _cp_step_summarize "upstream" 200
  [ "$current_tokens" -le "$TOKEN_BUDGET" ] && return
  _cp_step_drop_lowest_confidence "knowledge" ""
}

_cp_run_recipe_steps
```

### Step 8: Port manifest rebuild / final payload assembly

Port lines 437–539 of the pre-refactor script verbatim. This builds the new manifest table from the surviving sections and concatenates the final compressed payload. No changes.

### Step 9: Port stats line emission

```bash
FINAL_TOKENS="$(raw_token_count "$COMPRESSED")"
printf 'Compressed: %s tokens -> %s tokens (removed: %s optional, %s knowledge entries)\n' \
  "$ORIGINAL_TOKENS" "$FINAL_TOKENS" "$removed_optional" "$removed_knowledge" >&2
```

### Step 10: Parity test against golden compressed fixture

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

bash scripts/dispatch/compress-payload.sh --budget 2000 --input /tmp/t03-input.md 2>/dev/null \
  > /tmp/t03-refactored.md

normalize() {
  sed -E \
    -e 's/\| ([0-9]+)-([0-9]+) \|/| LINES |/g' \
    -e 's/~[0-9]+/~TOKENS/g' \
    -e 's/\(([0-9]+) entries\)/(N entries)/g'
}

normalize < .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-compressed-budget2000.md \
  > /tmp/t03-gold-norm.md
normalize < /tmp/t03-refactored.md > /tmp/t03-ref-norm.md

diff -u /tmp/t03-gold-norm.md /tmp/t03-ref-norm.md
# Clean diff = PASS.
```

### Step 11: Verify standalone mode (recipe missing)

```bash
# Point --recipe at a non-existent file; the script should fall back to
# hardcoded steps and still produce valid compressed output.
bash scripts/dispatch/compress-payload.sh --budget 2000 --input /tmp/t03-input.md \
  --recipe /nonexistent/recipe.yaml 2>/dev/null | wc -l
# Output must be > 10 (valid compressed payload).
```

### Step 12: Verify unknown-step-type SAFETY_WARNING

Create a test recipe with a bogus step:

```bash
cat > /tmp/t03-bogus-recipe.yaml <<'YAML'
compression:
  steps:
    step_1:
      type: drop_optional
      description: drop optional
    step_2:
      type: made_up_step
      description: unknown
YAML

bash scripts/dispatch/compress-payload.sh --budget 2000 --input /tmp/t03-input.md \
  --recipe /tmp/t03-bogus-recipe.yaml 2>&1 >/dev/null \
  | grep -q 'SAFETY_WARNING' && echo "PASS: safety warning" || echo "FAIL"
```

## Must-Haves

### Truths

- `scripts/dispatch/compress-payload.sh` sources `recipe-parser.sh` and calls `parse_recipe_compression`
  - Check: `grep -q 'recipe-parser.sh' scripts/dispatch/compress-payload.sh && grep -q 'parse_recipe_compression' scripts/dispatch/compress-payload.sh`
- `scripts/dispatch/compress-payload.sh` accepts a `--recipe` argument
  - Check: `grep -q '\-\-recipe' scripts/dispatch/compress-payload.sh`
- `scripts/dispatch/compress-payload.sh` sources errors.sh and calls emit_result
  - Check: `grep -q 'scripts/lib/errors.sh' scripts/dispatch/compress-payload.sh && grep -q 'emit_result' scripts/dispatch/compress-payload.sh`
- `scripts/dispatch/compress-payload.sh` preserves the `--budget` and `--input` CLI shape (additive flags only)
  - Check: `grep -q '\-\-budget' scripts/dispatch/compress-payload.sh && grep -q '\-\-input' scripts/dispatch/compress-payload.sh`
- Bash 3.2 compat
  - Check: `! grep -qE 'declare -A|readarray|mapfile' scripts/dispatch/compress-payload.sh`
- No inline `date`
  - Check: `! grep -nE '\$\(date\b|^[[:space:]]*date[[:space:]]+-u' scripts/dispatch/compress-payload.sh`
- Parity holds against golden compressed fixture (within manifest line-range/token normalization)
  - Check: `bash scripts/dispatch/compress-payload.sh --budget 2000 --input /tmp/t03-input.md 2>/dev/null | sed -E 's/\| ([0-9]+)-([0-9]+) \|/| LINES |/g; s/~[0-9]+/~TOKENS/g; s/\(([0-9]+) entries\)/(N entries)/g' > /tmp/t03-ref.md && sed -E 's/\| ([0-9]+)-([0-9]+) \|/| LINES |/g; s/~[0-9]+/~TOKENS/g; s/\(([0-9]+) entries\)/(N entries)/g' < .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-compressed-budget2000.md > /tmp/t03-gold.md && diff -q /tmp/t03-gold.md /tmp/t03-ref.md`
- Fallback to hardcoded steps when recipe is missing
  - Check: `bash scripts/dispatch/compress-payload.sh --budget 2000 --input /tmp/t03-input.md --recipe /nonexistent/r.yaml 2>/dev/null | wc -l | awk '$1 > 10 {exit 0} {exit 1}'`
- Emits exactly one RESULT line on stderr
  - Check: `bash scripts/dispatch/compress-payload.sh --budget 2000 --input /tmp/t03-input.md 2>&1 >/dev/null | grep -c '^RESULT:' | grep -q '^1$'`
- Unknown step type emits a SAFETY_WARNING (inspect manually — covered by Step 12)

### Artifacts

- `scripts/dispatch/compress-payload.sh` (min 200 lines, contains "parse_recipe_compression")
- `.specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-compressed-budget2000.md` (min 10 lines, contains "Compressed" OR "Dispatch Context")

### Key Links

- `scripts/dispatch/compress-payload.sh` → `scripts/lib/recipe-parser.sh`
- `scripts/dispatch/compress-payload.sh` → `scripts/lib/errors.sh`
- `scripts/dispatch/compress-payload.sh` → `templates/context-recipe.yaml`

## Verification

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "=== T03 Verification ==="

test -f scripts/dispatch/compress-payload.sh && echo "PASS: file" || echo "FAIL"
test -x scripts/dispatch/compress-payload.sh && echo "PASS: executable" || echo "FAIL"
lines=$(wc -l < scripts/dispatch/compress-payload.sh | tr -d ' ')
test "$lines" -ge 200 && echo "PASS: $lines lines" || echo "FAIL"

grep -q 'recipe-parser.sh' scripts/dispatch/compress-payload.sh && echo "PASS: sources recipe-parser" || echo "FAIL"
grep -q 'parse_recipe_compression' scripts/dispatch/compress-payload.sh && echo "PASS: uses parse_recipe_compression" || echo "FAIL"
grep -q 'scripts/lib/errors.sh' scripts/dispatch/compress-payload.sh && echo "PASS: sources errors" || echo "FAIL"
grep -q 'emit_result' scripts/dispatch/compress-payload.sh && echo "PASS: emit_result" || echo "FAIL"
grep -q '\-\-recipe' scripts/dispatch/compress-payload.sh && echo "PASS: --recipe flag" || echo "FAIL"
grep -q '\-\-budget' scripts/dispatch/compress-payload.sh && echo "PASS: --budget preserved" || echo "FAIL"

! grep -qE 'declare -A|readarray|mapfile' scripts/dispatch/compress-payload.sh && echo "PASS: Bash 3.2" || echo "FAIL"
! grep -nE '\$\(date\b|^[[:space:]]*date[[:space:]]+-u' scripts/dispatch/compress-payload.sh && echo "PASS: no inline date" || echo "FAIL"

# Parity vs golden
bash scripts/dispatch/compress-payload.sh --budget 2000 --input /tmp/t03-input.md 2>/dev/null \
  | sed -E 's/\| ([0-9]+)-([0-9]+) \|/| LINES |/g; s/~[0-9]+/~TOKENS/g; s/\(([0-9]+) entries\)/(N entries)/g' \
  > /tmp/t03-refactored-norm.md
sed -E 's/\| ([0-9]+)-([0-9]+) \|/| LINES |/g; s/~[0-9]+/~TOKENS/g; s/\(([0-9]+) entries\)/(N entries)/g' \
  < .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-compressed-budget2000.md \
  > /tmp/t03-golden-norm.md
diff -q /tmp/t03-golden-norm.md /tmp/t03-refactored-norm.md \
  && echo "PASS: parity" || echo "FAIL: parity broken"

# Fallback
bash scripts/dispatch/compress-payload.sh --budget 2000 --input /tmp/t03-input.md \
  --recipe /nonexistent/r.yaml 2>/dev/null | wc -l | awk '$1 > 10 {exit 0} {exit 1}' \
  && echo "PASS: fallback" || echo "FAIL"

# RESULT on stderr
bash scripts/dispatch/compress-payload.sh --budget 2000 --input /tmp/t03-input.md 2>&1 >/dev/null \
  | grep -c '^RESULT:' | grep -q '^1$' && echo "PASS: RESULT" || echo "FAIL"
```

## Inputs

### From Previous Tasks

- `scripts/dispatch/lib/section-handlers.sh` (from T01) — not directly sourced by compress-payload.sh, but the section splitter in this script parses the manifest generated by T02's build-context.sh, which in turn dispatches via T01's handlers. The section names in the payload (Knowledge, Decisions, Scope, Upstream Context, Task Plan, State Context, Constraints) come from T02's display-name mapping.

### From Disk (Pre-existing)

- `scripts/dispatch/compress-payload.sh` — the pre-refactor script. Lines 24–56 (arg parsing and input reading) are ported with the `--recipe` addition. Lines 58–86 (token estimation, short-circuit) port verbatim. Lines 88–208 (manifest parse + section splitter) port verbatim. Lines 210–435 (the three compression steps) are refactored into the three `_cp_step_*` functions. Lines 437–542 (manifest rebuild + final assembly + stats line) port verbatim.
- `scripts/lib/recipe-parser.sh` — `parse_recipe_compression <file>` output format: `<step_key>|<type>|<target_sections>|<max_words>|<min_confidence>|<description>`. Known types: `drop_optional`, `summarize`, `drop_lowest_confidence`.
- `scripts/lib/errors.sh` — `emit_result <ok|error> [kind] [detail]`.
- `scripts/lib/events.sh` — `emit_event <TYPE> [key=value ...]`. `DISPATCH_START` and `SAFETY_WARNING` are valid types.
- `scripts/lib/run-context.sh` — `init_run_context`.
- `templates/context-recipe.yaml` — the default recipe. Its `compression:` block declares 3 graduated steps matching the pre-refactor hardcoded sequence, so the default-recipe output must match the pre-refactor output exactly.
- `scripts/engine/run.sh` line ~245 — invokes `compress-payload.sh --budget "$_context_budget" --input "$_payload_file"`. Must not break.

## Expected Output

- `scripts/dispatch/compress-payload.sh` rewritten (~250–300 lines).
- Sources errors.sh, events.sh, run-context.sh, recipe-parser.sh.
- New `--recipe <path>` flag, existing `--budget`/`--input` preserved.
- Three step functions (`_cp_step_drop_optional`, `_cp_step_summarize`, `_cp_step_drop_lowest_confidence`).
- Recipe-driven dispatcher (`_cp_run_recipe_steps`) with fallback (`_cp_run_fallback_steps`) when recipe is missing.
- Emits exactly one RESULT line on stderr per run.
- Parity holds: running the refactored script with `--budget 2000 --input /tmp/t03-input.md` against the golden fixture (after normalizing line-range/token-count/entry-count columns) produces a clean diff.
- `.specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-compressed-budget2000.md` exists, captured in Step 1.
- `scripts/engine/run.sh` unchanged.
