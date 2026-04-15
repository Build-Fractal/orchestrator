---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P05"
milestone: "M004"
name: "Refactor select-model.sh — Fallback Chains and Retry Primitive"
depends_on: [T01]
---

## Description

Rewrite `scripts/dispatch/select-model.sh` to read fallback chains from `templates/routing.yaml` via `scripts/lib/recipe-parser.sh`'s `parse_recipe_fallback` function, and add two new CLI flags that expose the retry primitive the engine will eventually consume:

- `--list-fallback` — prints the comma-separated fallback chain for the selected tier.
- `--next-fallback <current-model-id>` — prints the next model in the chain after `<current-model-id>`, or exits 1 if the current model is the last in the chain.

The existing default invocation (`select-model.sh <tier> --routing-config <file>` → prints `<model-id> <context-budget>` on one line) is preserved unchanged. The built-in hardcoded defaults (heavy→opus / standard→sonnet / light→haiku) are preserved as the fallback behavior when no routing config is provided or the file is missing.

This implements FR-213 (routing with fallback chains) and US10 (Model Routing with Fallback Chains). P05 exposes the primitive; the actual engine retry loop is a later phase.

## Cross-Cutting Constraints (verbatim from P05-PLAN.md)

1. **Bash 3.2** — no `declare -A`, no `readarray`, no `mapfile`, no `<(…)` as a redirect target in while read loops.
2. **Sibling library sourcing** — `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`.
3. **No inline `date`** — use `orch_now` after sourcing run-context.sh.
4. **`emit_result` on exit** — source errors.sh and emit exactly one RESULT line to stderr (stdout is for model-id output).
5. **Standalone mode still works** — if `ORCH_RUN_ID` is unset, `init_run_context` is called. If routing.yaml is missing, fall back to built-in defaults.
6. **P06-deferred items — do NOT touch.**
7. **Every verification command must be runnable from repo root.**
8. **No `jq`.**
9. **Engine compatibility** — `scripts/engine/run.sh` line ~185 invokes `bash scripts/dispatch/select-model.sh standard --routing-config templates/routing.yaml`. This shape must keep working unchanged. The new flags are additive.
10. **Literal-audit-marker pattern** — pair single-word `emit_event` values with a `printf 'EVENT-AUDIT:...'` line.

## Steps

### Step 1: Baseline — capture pre-refactor output for all three tiers

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml \
  > /tmp/t04-heavy-golden.txt 2>/dev/null
bash scripts/dispatch/select-model.sh standard --routing-config templates/routing.yaml \
  > /tmp/t04-standard-golden.txt 2>/dev/null
bash scripts/dispatch/select-model.sh light --routing-config templates/routing.yaml \
  > /tmp/t04-light-golden.txt 2>/dev/null

cat /tmp/t04-heavy-golden.txt
# Expected: claude-opus-4-6 200000
cat /tmp/t04-standard-golden.txt
# Expected: claude-sonnet-4-6 150000
cat /tmp/t04-light-golden.txt
# Expected: claude-haiku-4-5 80000
```

### Step 2: Rewrite the script top

```bash
#!/usr/bin/env bash
# scripts/dispatch/select-model.sh — Routing with fallback chain support
# Maps a complexity tier to a model ID + context budget using routing.yaml,
# with optional fallback-chain lookups for retry-on-failure.
#
# Usage:
#   select-model.sh <tier> [--routing-config <file>]          # default: print "model-id budget"
#   select-model.sh <tier> [--routing-config <file>] --list-fallback
#   select-model.sh <tier> [--routing-config <file>] --next-fallback <current-model-id>
#
# Output to stdout:
#   default:         "<model-id> <context-budget>"
#   --list-fallback: "<model1>,<model2>,..." (empty string if no fallback)
#   --next-fallback: "<next-model-id>" (or exit 1 when chain exhausted)
#
# Bash 3.2 compatible. Standalone-capable. No jq.
# Constitution: Principle X (Templating Over Inference).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

. "$PROJECT_ROOT/scripts/lib/errors.sh"
. "$PROJECT_ROOT/scripts/lib/events.sh"
. "$PROJECT_ROOT/scripts/lib/run-context.sh"
. "$PROJECT_ROOT/scripts/lib/recipe-parser.sh"

_SM_RESULT_EMITTED=0
_sm_final_result() {
  local rc=$?
  if [ "$_SM_RESULT_EMITTED" -eq 0 ]; then
    if [ "$rc" -eq 0 ]; then
      emit_result ok "" "model selection ok" >&2
    else
      emit_result error DISPATCH "select-model rc=$rc" >&2
    fi
    _SM_RESULT_EMITTED=1
  fi
}
trap _sm_final_result EXIT
```

### Step 3: Argument parsing

```bash
COMPLEXITY=""
ROUTING_CONFIG=""
MODE="default"
CURRENT_MODEL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --routing-config) ROUTING_CONFIG="$2"; shift 2 ;;
    --list-fallback)  MODE="list_fallback"; shift ;;
    --next-fallback)
      MODE="next_fallback"
      CURRENT_MODEL="${2:-}"
      if [ -z "$CURRENT_MODEL" ]; then
        printf 'select-model.sh: --next-fallback requires an argument\n' >&2
        exit 1
      fi
      shift 2 ;;
    -*) printf 'select-model.sh: unknown option %s\n' "$1" >&2; exit 1 ;;
    *)  [ -z "$COMPLEXITY" ] && COMPLEXITY="$1"; shift ;;
  esac
done

if [ -z "$COMPLEXITY" ]; then
  printf 'Usage: select-model.sh <tier> [--routing-config <file>] [--list-fallback | --next-fallback <model-id>]\n' >&2
  exit 1
fi

case "$COMPLEXITY" in
  heavy|standard|light) ;;
  *)
    printf 'select-model.sh: invalid tier %s\n' "$COMPLEXITY" >&2
    exit 1 ;;
esac

if [ -z "${ORCH_RUN_ID:-}" ]; then
  init_run_context
fi

emit_event DISPATCH_START stage=select_model tier="$COMPLEXITY" mode="$MODE" >&2
printf 'EVENT-AUDIT:DISPATCH_START stage="select_model"\n' >&2
```

### Step 4: Default-mode built-in map (fallback when routing-config is missing)

```bash
_sm_default_model() {
  case "$1" in
    heavy)    printf 'claude-opus-4-6 200000\n' ;;
    standard) printf 'claude-sonnet-4-6 150000\n' ;;
    light)    printf 'claude-haiku-4-5 80000\n' ;;
  esac
}

_sm_default_fallback() {
  case "$1" in
    heavy)    printf 'claude-sonnet-4-6,claude-haiku-4-5\n' ;;
    standard) printf 'claude-haiku-4-5\n' ;;
    light)    printf '\n' ;;
  esac
}
```

### Step 5: Default-mode: print model-id and budget

This branch MUST produce byte-identical output to the pre-refactor script for all three tiers when given the default `templates/routing.yaml`. Port the existing YAML parser inline — or equivalently, call `read_recipe_field` from recipe-parser.sh:

```bash
if [ "$MODE" = "default" ]; then
  if [ -z "$ROUTING_CONFIG" ] || [ ! -f "$ROUTING_CONFIG" ]; then
    _sm_default_model "$COMPLEXITY"
    exit 0
  fi
  # Read models.<tier>.id and models.<tier>.context_budget via recipe-parser
  model_id="$(read_recipe_field "$ROUTING_CONFIG" "models.${COMPLEXITY}.id" 2>/dev/null || true)"
  budget="$(read_recipe_field "$ROUTING_CONFIG" "models.${COMPLEXITY}.context_budget" 2>/dev/null || true)"
  if [ -z "$model_id" ] || [ -z "$budget" ]; then
    _sm_default_model "$COMPLEXITY"
    exit 0
  fi
  printf '%s %s\n' "$model_id" "$budget"
  exit 0
fi
```

**Verify parity before proceeding** — run the default-mode tests from Step 1 against the refactored script and confirm byte-identical output.

### Step 6: `--list-fallback` mode

```bash
if [ "$MODE" = "list_fallback" ]; then
  if [ -z "$ROUTING_CONFIG" ] || [ ! -f "$ROUTING_CONFIG" ]; then
    _sm_default_fallback "$COMPLEXITY"
    exit 0
  fi
  chain="$(parse_recipe_fallback "$ROUTING_CONFIG" "$COMPLEXITY" 2>/dev/null || true)"
  if [ -z "$chain" ]; then
    printf '\n'
  else
    printf '%s\n' "$chain"
  fi
  exit 0
fi
```

### Step 7: `--next-fallback <current>` mode

```bash
if [ "$MODE" = "next_fallback" ]; then
  # Build the full chain as: primary,<fallback-chain>
  if [ -z "$ROUTING_CONFIG" ] || [ ! -f "$ROUTING_CONFIG" ]; then
    primary="$(_sm_default_model "$COMPLEXITY" | awk '{print $1}')"
    chain="$(_sm_default_fallback "$COMPLEXITY")"
  else
    primary="$(read_recipe_field "$ROUTING_CONFIG" "models.${COMPLEXITY}.id" 2>/dev/null || true)"
    chain="$(parse_recipe_fallback "$ROUTING_CONFIG" "$COMPLEXITY" 2>/dev/null || true)"
    if [ -z "$primary" ]; then
      primary="$(_sm_default_model "$COMPLEXITY" | awk '{print $1}')"
      chain="$(_sm_default_fallback "$COMPLEXITY")"
    fi
  fi

  if [ -n "$chain" ]; then
    full_chain="${primary},${chain}"
  else
    full_chain="$primary"
  fi

  # Split and find next-after-current
  found=0
  next=""
  OLDIFS="$IFS"
  IFS=','
  set -- $full_chain
  IFS="$OLDIFS"
  for m in "$@"; do
    if [ "$found" -eq 1 ]; then
      next="$m"
      break
    fi
    if [ "$m" = "$CURRENT_MODEL" ]; then
      found=1
    fi
  done

  if [ "$found" -eq 0 ]; then
    emit_event SAFETY_WARNING reason=current_model_not_in_chain current="$CURRENT_MODEL" >&2
    printf 'EVENT-AUDIT:SAFETY_WARNING reason="current_model_not_in_chain"\n' >&2
    exit 1
  fi

  if [ -z "$next" ]; then
    # Chain exhausted — no fallback remaining
    emit_event DISPATCH_FALLBACK tier="$COMPLEXITY" from="$CURRENT_MODEL" to="" exhausted=1 >&2
    printf 'EVENT-AUDIT:DISPATCH_FALLBACK exhausted=1\n' >&2
    exit 1
  fi

  emit_event DISPATCH_FALLBACK tier="$COMPLEXITY" from="$CURRENT_MODEL" to="$next" >&2
  printf 'EVENT-AUDIT:DISPATCH_FALLBACK from="%s"\n' "$CURRENT_MODEL" >&2
  printf '%s\n' "$next"
  exit 0
fi
```

### Step 8: Test all three modes

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Default mode — parity with golden
bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml 2>/dev/null \
  | diff - /tmp/t04-heavy-golden.txt && echo "PASS: heavy parity"
bash scripts/dispatch/select-model.sh standard --routing-config templates/routing.yaml 2>/dev/null \
  | diff - /tmp/t04-standard-golden.txt && echo "PASS: standard parity"
bash scripts/dispatch/select-model.sh light --routing-config templates/routing.yaml 2>/dev/null \
  | diff - /tmp/t04-light-golden.txt && echo "PASS: light parity"

# --list-fallback
bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml --list-fallback 2>/dev/null
# Expected: claude-sonnet-4-6,claude-haiku-4-5

bash scripts/dispatch/select-model.sh standard --routing-config templates/routing.yaml --list-fallback 2>/dev/null
# Expected: claude-haiku-4-5

bash scripts/dispatch/select-model.sh light --routing-config templates/routing.yaml --list-fallback 2>/dev/null
# Expected: empty string (just a newline)

# --next-fallback
bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml \
  --next-fallback claude-opus-4-6 2>/dev/null
# Expected: claude-sonnet-4-6

bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml \
  --next-fallback claude-sonnet-4-6 2>/dev/null
# Expected: claude-haiku-4-5

bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml \
  --next-fallback claude-haiku-4-5 2>/dev/null
# Expected: empty stdout, exit 1 (chain exhausted)
echo "exit=$?"

# Missing routing config — falls back to built-ins
bash scripts/dispatch/select-model.sh heavy 2>/dev/null
# Expected: claude-opus-4-6 200000
```

### Step 9: Verify RESULT emission

```bash
bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml 2>&1 >/dev/null \
  | grep -c '^RESULT:' | grep -q '^1$' && echo "PASS: RESULT"
```

## Must-Haves

### Truths

- `scripts/dispatch/select-model.sh` sources `recipe-parser.sh`
  - Check: `grep -q 'recipe-parser.sh' scripts/dispatch/select-model.sh`
- `scripts/dispatch/select-model.sh` calls `parse_recipe_fallback`
  - Check: `grep -q 'parse_recipe_fallback' scripts/dispatch/select-model.sh`
- `scripts/dispatch/select-model.sh` implements `--list-fallback`
  - Check: `grep -q '\-\-list-fallback' scripts/dispatch/select-model.sh`
- `scripts/dispatch/select-model.sh` implements `--next-fallback`
  - Check: `grep -q '\-\-next-fallback' scripts/dispatch/select-model.sh`
- `scripts/dispatch/select-model.sh` sources errors.sh and calls emit_result
  - Check: `grep -q 'scripts/lib/errors.sh' scripts/dispatch/select-model.sh && grep -q 'emit_result' scripts/dispatch/select-model.sh`
- Bash 3.2 compat
  - Check: `! grep -qE 'declare -A|readarray|mapfile' scripts/dispatch/select-model.sh`
- No inline `date`
  - Check: `! grep -nE '\$\(date\b|^[[:space:]]*date[[:space:]]+-u' scripts/dispatch/select-model.sh`
- Default-mode output parity for `heavy` tier
  - Check: `bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml 2>/dev/null | grep -q '^claude-opus-4-6 200000$'`
- Default-mode output parity for `standard` tier
  - Check: `bash scripts/dispatch/select-model.sh standard --routing-config templates/routing.yaml 2>/dev/null | grep -q '^claude-sonnet-4-6 150000$'`
- Default-mode output parity for `light` tier
  - Check: `bash scripts/dispatch/select-model.sh light --routing-config templates/routing.yaml 2>/dev/null | grep -q '^claude-haiku-4-5 80000$'`
- `--list-fallback` returns expected chain for heavy
  - Check: `bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml --list-fallback 2>/dev/null | grep -q '^claude-sonnet-4-6,claude-haiku-4-5$'`
- `--next-fallback claude-opus-4-6` for heavy returns `claude-sonnet-4-6`
  - Check: `bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml --next-fallback claude-opus-4-6 2>/dev/null | grep -q '^claude-sonnet-4-6$'`
- `--next-fallback` on the last model in the chain exits non-zero
  - Check: `! bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml --next-fallback claude-haiku-4-5 2>/dev/null`
- Missing routing-config falls back to built-in defaults
  - Check: `bash scripts/dispatch/select-model.sh heavy 2>/dev/null | grep -q '^claude-opus-4-6 200000$'`
- Exactly one RESULT line on stderr
  - Check: `bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml 2>&1 >/dev/null | grep -c '^RESULT:' | grep -q '^1$'`

### Artifacts

- `scripts/dispatch/select-model.sh` (min 120 lines, contains "parse_recipe_fallback")

### Key Links

- `scripts/dispatch/select-model.sh` → `scripts/lib/recipe-parser.sh`
- `scripts/dispatch/select-model.sh` → `scripts/lib/errors.sh`
- `scripts/dispatch/select-model.sh` → `templates/routing.yaml`

## Verification

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "=== T04 Verification ==="

test -f scripts/dispatch/select-model.sh && echo "PASS: file" || echo "FAIL"
test -x scripts/dispatch/select-model.sh && echo "PASS: executable" || echo "FAIL"
lines=$(wc -l < scripts/dispatch/select-model.sh | tr -d ' ')
test "$lines" -ge 120 && echo "PASS: $lines lines" || echo "FAIL"

for lib in errors.sh events.sh run-context.sh recipe-parser.sh; do
  grep -q "scripts/lib/$lib" scripts/dispatch/select-model.sh \
    && echo "PASS: sources $lib" || echo "FAIL"
done

grep -q 'parse_recipe_fallback' scripts/dispatch/select-model.sh && echo "PASS: parse_recipe_fallback" || echo "FAIL"
grep -q '\-\-list-fallback' scripts/dispatch/select-model.sh && echo "PASS: --list-fallback" || echo "FAIL"
grep -q '\-\-next-fallback' scripts/dispatch/select-model.sh && echo "PASS: --next-fallback" || echo "FAIL"
grep -q 'emit_result' scripts/dispatch/select-model.sh && echo "PASS: emit_result" || echo "FAIL"

! grep -qE 'declare -A|readarray|mapfile' scripts/dispatch/select-model.sh && echo "PASS: Bash 3.2" || echo "FAIL"
! grep -nE '\$\(date\b|^[[:space:]]*date[[:space:]]+-u' scripts/dispatch/select-model.sh && echo "PASS: no inline date" || echo "FAIL"

# Default-mode parity
for tier in heavy:claude-opus-4-6:200000 standard:claude-sonnet-4-6:150000 light:claude-haiku-4-5:80000; do
  t=$(echo "$tier" | cut -d: -f1)
  m=$(echo "$tier" | cut -d: -f2)
  b=$(echo "$tier" | cut -d: -f3)
  actual=$(bash scripts/dispatch/select-model.sh "$t" --routing-config templates/routing.yaml 2>/dev/null)
  if [ "$actual" = "$m $b" ]; then echo "PASS: $t → $m $b"; else echo "FAIL: $t got '$actual'"; fi
done

# --list-fallback
bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml --list-fallback 2>/dev/null \
  | grep -q '^claude-sonnet-4-6,claude-haiku-4-5$' && echo "PASS: list-fallback heavy" || echo "FAIL"

# --next-fallback
bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml --next-fallback claude-opus-4-6 2>/dev/null \
  | grep -q '^claude-sonnet-4-6$' && echo "PASS: next-fallback opus→sonnet" || echo "FAIL"

! bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml --next-fallback claude-haiku-4-5 2>/dev/null \
  && echo "PASS: chain exhausted returns non-zero" || echo "FAIL"

# RESULT
bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml 2>&1 >/dev/null \
  | grep -c '^RESULT:' | grep -q '^1$' && echo "PASS: RESULT" || echo "FAIL"
```

## Inputs

### From Previous Tasks

- `scripts/dispatch/lib/section-handlers.sh` (from T01) — NOT sourced by this script. T04 only inherits T01's lib-sourcing pattern style.

### From Disk (Pre-existing)

- `scripts/dispatch/select-model.sh` — the pre-refactor script. Lines 40–52 (built-in default map) are ported into `_sm_default_model`. Lines 56–99 (YAML parser) are replaced by calls to `read_recipe_field`.
- `scripts/lib/recipe-parser.sh` — provides:
  - `read_recipe_field <file> <dotted.path>` — e.g., `models.heavy.id` → `claude-opus-4-6`.
  - `parse_recipe_fallback <file> <tier>` — returns the comma-separated fallback chain for the tier, or empty string.
- `scripts/lib/errors.sh` — `emit_result`. Error kind for model selection failures is `DISPATCH`.
- `scripts/lib/events.sh` — `emit_event`. Registered types: `DISPATCH_START`, `DISPATCH_FALLBACK`, `SAFETY_WARNING`.
- `templates/routing.yaml` — default routing config. Contains `models.{heavy,standard,light}.{id,context_budget,fallback}`. The fallback values are: heavy=`claude-sonnet-4-6,claude-haiku-4-5`, standard=`claude-haiku-4-5`, light=`""`.
- `scripts/engine/run.sh` line ~185 — invokes `bash scripts/dispatch/select-model.sh standard --routing-config templates/routing.yaml`. This invocation must continue to print `claude-sonnet-4-6 150000`.

## Expected Output

- `scripts/dispatch/select-model.sh` rewritten (~150–200 lines).
- Sources errors.sh, events.sh, run-context.sh, recipe-parser.sh.
- Three modes: default (unchanged shape), `--list-fallback`, `--next-fallback <current>`.
- Default mode output is byte-identical to the pre-refactor script for all three tiers when given `templates/routing.yaml`.
- Fallback to built-in defaults when routing-config is missing/unreadable.
- Emits exactly one RESULT line on stderr per run.
- `scripts/engine/run.sh` unchanged.
