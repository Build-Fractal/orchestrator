---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P05"
milestone: "M004"
name: "Integration Parity Harness"
depends_on: [T02, T03, T04]
---

## Description

Create a self-contained parity-verification harness under `.specify/orchestrator/milestones/M004/phases/P05/fixtures/` that validates all three refactored dispatch scripts produce correct output end-to-end against the golden fixtures captured during T02 and T03. The harness is runnable from repo root (`bash .specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh`) and exits 0 iff every parity and event-emission check passes.

This task does NOT re-capture the golden fixtures (T02 Step 1 and T03 Step 1 already did that). T05 writes the harness that validates them, plus a short README explaining the normalization rules.

## Cross-Cutting Constraints (verbatim from P05-PLAN.md)

1. **Bash 3.2** — the harness itself must be Bash 3.2 compatible.
2. **Every verification command must be runnable from repo root.** The harness must `cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"` at the top so it works from any cwd.
3. **P06-deferred items — do NOT touch.** The harness must not try to fix check-must-haves.sh, events.sh, or record-result.sh. If any of those bugs show up as harness failures, report them as P06 scope candidates in the task summary, don't patch them.
4. **No `jq`.**
5. **No inline `date`** — the harness does not need timestamps.

## Steps

### Step 1: Confirm golden fixtures exist

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

FIX=.specify/orchestrator/milestones/M004/phases/P05/fixtures
test -f "$FIX/golden-payload-M004-P04-T04.md" && echo "ok: build-context golden"
test -f "$FIX/golden-compressed-budget2000.md" && echo "ok: compress golden"
```

Both must print `ok:`. If either is missing, T02 or T03 did not complete the baseline step — STOP and rerun the offending task.

### Step 2: Create `fixtures/run-parity.sh`

Write the following file to `.specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh`:

```bash
#!/usr/bin/env bash
# run-parity.sh — End-to-end parity verification for P05 refactored dispatch scripts.
# Runs from repo root. Exits 0 iff every check passes.
#
# Checks:
#   1. build-context.sh output against golden-payload-M004-P04-T04.md (normalized)
#   2. compress-payload.sh output against golden-compressed-budget2000.md (normalized)
#   3. select-model.sh default-mode output for all 3 tiers
#   4. select-model.sh --list-fallback for all 3 tiers
#   5. select-model.sh --next-fallback chain walk
#   6. Each refactored script emits at least one EVENT: line and exactly one RESULT: line
#
# Bash 3.2 compatible.

set -u

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || { printf 'run-parity.sh: cannot cd to repo root\n' >&2; exit 1; }

FIXTURES_DIR=".specify/orchestrator/milestones/M004/phases/P05/fixtures"
GOLDEN_PAYLOAD="$FIXTURES_DIR/golden-payload-M004-P04-T04.md"
GOLDEN_COMPRESS="$FIXTURES_DIR/golden-compressed-budget2000.md"

FAIL=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

# Normalization function: strip line-range, token counts, and entry counts
# from manifest table rows so parity does not care about those volatile columns.
normalize() {
  sed -E \
    -e 's/\| ([0-9]+)-([0-9]+) \|/| LINES |/g' \
    -e 's/~[0-9]+/~TOKENS/g' \
    -e 's/\(([0-9]+) entries\)/(N entries)/g'
}

# --- Check 1: build-context.sh parity ---
if [ -f "$GOLDEN_PAYLOAD" ]; then
  tmp_refactored="$(mktemp)"
  tmp_golden_norm="$(mktemp)"
  tmp_refactored_norm="$(mktemp)"
  if bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 \
       > "$tmp_refactored" 2>/dev/null; then
    normalize < "$GOLDEN_PAYLOAD" > "$tmp_golden_norm"
    normalize < "$tmp_refactored" > "$tmp_refactored_norm"
    if diff -q "$tmp_golden_norm" "$tmp_refactored_norm" >/dev/null 2>&1; then
      pass "build-context.sh parity (M004/P04/T04)"
    else
      fail "build-context.sh parity (M004/P04/T04)"
      printf '--- golden (normalized)\n+++ refactored (normalized)\n' >&2
      diff -u "$tmp_golden_norm" "$tmp_refactored_norm" | head -60 >&2
    fi
  else
    fail "build-context.sh failed to run"
  fi
  rm -f "$tmp_refactored" "$tmp_golden_norm" "$tmp_refactored_norm"
else
  fail "golden payload fixture missing at $GOLDEN_PAYLOAD"
fi

# --- Check 2: compress-payload.sh parity ---
if [ -f "$GOLDEN_COMPRESS" ]; then
  tmp_in="$(mktemp)"
  tmp_out="$(mktemp)"
  tmp_gold_norm="$(mktemp)"
  tmp_out_norm="$(mktemp)"
  if bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 \
       > "$tmp_in" 2>/dev/null; then
    if bash scripts/dispatch/compress-payload.sh --budget 2000 --input "$tmp_in" \
         > "$tmp_out" 2>/dev/null; then
      normalize < "$GOLDEN_COMPRESS" > "$tmp_gold_norm"
      normalize < "$tmp_out" > "$tmp_out_norm"
      if diff -q "$tmp_gold_norm" "$tmp_out_norm" >/dev/null 2>&1; then
        pass "compress-payload.sh parity (budget 2000)"
      else
        fail "compress-payload.sh parity (budget 2000)"
        diff -u "$tmp_gold_norm" "$tmp_out_norm" | head -60 >&2
      fi
    else
      fail "compress-payload.sh failed to run"
    fi
  else
    fail "build-context.sh failed to produce input for compress test"
  fi
  rm -f "$tmp_in" "$tmp_out" "$tmp_gold_norm" "$tmp_out_norm"
else
  fail "golden compressed fixture missing at $GOLDEN_COMPRESS"
fi

# --- Check 3: select-model.sh default-mode parity for all 3 tiers ---
check_model() {
  local tier="$1" expected="$2"
  local actual
  actual="$(bash scripts/dispatch/select-model.sh "$tier" \
             --routing-config templates/routing.yaml 2>/dev/null)"
  if [ "$actual" = "$expected" ]; then
    pass "select-model.sh $tier → $expected"
  else
    fail "select-model.sh $tier got '$actual' expected '$expected'"
  fi
}
check_model heavy    "claude-opus-4-6 200000"
check_model standard "claude-sonnet-4-6 150000"
check_model light    "claude-haiku-4-5 80000"

# --- Check 4: --list-fallback ---
check_list_fallback() {
  local tier="$1" expected="$2"
  local actual
  actual="$(bash scripts/dispatch/select-model.sh "$tier" \
             --routing-config templates/routing.yaml --list-fallback 2>/dev/null)"
  if [ "$actual" = "$expected" ]; then
    pass "select-model.sh $tier --list-fallback → '$expected'"
  else
    fail "select-model.sh $tier --list-fallback got '$actual' expected '$expected'"
  fi
}
check_list_fallback heavy    "claude-sonnet-4-6,claude-haiku-4-5"
check_list_fallback standard "claude-haiku-4-5"
check_list_fallback light    ""

# --- Check 5: --next-fallback chain walk ---
cur="claude-opus-4-6"
next="$(bash scripts/dispatch/select-model.sh heavy \
         --routing-config templates/routing.yaml --next-fallback "$cur" 2>/dev/null)"
if [ "$next" = "claude-sonnet-4-6" ]; then
  pass "next-fallback opus→sonnet"
else
  fail "next-fallback opus→(?) got '$next'"
fi

next2="$(bash scripts/dispatch/select-model.sh heavy \
          --routing-config templates/routing.yaml --next-fallback claude-sonnet-4-6 2>/dev/null)"
if [ "$next2" = "claude-haiku-4-5" ]; then
  pass "next-fallback sonnet→haiku"
else
  fail "next-fallback sonnet→(?) got '$next2'"
fi

if bash scripts/dispatch/select-model.sh heavy \
     --routing-config templates/routing.yaml --next-fallback claude-haiku-4-5 \
     >/dev/null 2>&1; then
  fail "next-fallback haiku should exit non-zero (chain exhausted)"
else
  pass "next-fallback chain exhausted exits non-zero"
fi

# --- Check 6: event + result emission ---
check_emissions() {
  local label="$1"
  shift
  local out
  out="$("$@" 2>&1 >/dev/null)"
  local ev_count rc_count
  ev_count="$(printf '%s\n' "$out" | grep -c '^EVENT:' || true)"
  rc_count="$(printf '%s\n' "$out" | grep -c '^RESULT:' || true)"
  if [ "$ev_count" -ge 1 ]; then
    pass "$label emits EVENT: lines ($ev_count)"
  else
    fail "$label emits no EVENT: lines"
  fi
  if [ "$rc_count" = "1" ]; then
    pass "$label emits exactly one RESULT: line"
  else
    fail "$label emits $rc_count RESULT: lines (expected 1)"
  fi
}

check_emissions "build-context.sh" \
  bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04

tmp_compress_in="$(mktemp)"
bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P04 T04 \
  > "$tmp_compress_in" 2>/dev/null
check_emissions "compress-payload.sh" \
  bash scripts/dispatch/compress-payload.sh --budget 2000 --input "$tmp_compress_in"
rm -f "$tmp_compress_in"

check_emissions "select-model.sh" \
  bash scripts/dispatch/select-model.sh heavy --routing-config templates/routing.yaml

# --- Summary ---
printf '\n=== P05 Parity Harness: %d failure(s) ===\n' "$FAIL"
exit "$FAIL"
```

### Step 3: Make the harness executable

```bash
chmod +x .specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh
```

### Step 4: Run the harness from repo root

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
bash .specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh
echo "harness-exit=$?"
```

Expected: all checks pass (`FAIL: 0 failure(s)`), exit 0.

If anything fails, the failure output will identify which script needs a fix. Iterate on T02/T03/T04 until the harness is clean.

### Step 5: Create a short fixtures README

Write `.specify/orchestrator/milestones/M004/phases/P05/fixtures/README.md`:

```markdown
# P05 Parity Fixtures

Golden outputs captured from the pre-refactor dispatch scripts (before T02/T03
ran) and the harness that validates the refactored scripts against them.

## Files

- `golden-payload-M004-P04-T04.md` — output of pre-refactor
  `build-context.sh .specify/orchestrator M004 P04 T04`. T02 parity target.
- `golden-compressed-budget2000.md` — output of pre-refactor
  `compress-payload.sh --budget 2000` fed with the golden payload above.
  T03 parity target.
- `run-parity.sh` — end-to-end parity + event-emission harness. Run from
  repo root: `bash .specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh`.

## Normalization Rules

Manifest table columns that legitimately vary between runs are stripped
before diff:

- `| <start>-<end> |` → `| LINES |` (line ranges shift with section growth)
- `~<N>` → `~TOKENS` (token estimates round to nearest 100)
- `(<N> entries)` → `(N entries)` (knowledge entry counts fluctuate)

Everything else MUST match byte-for-byte. If a check fails, the harness
prints a unified diff of the first 60 lines of divergence.

## Regeneration

The golden fixtures are intentionally checked in. Only regenerate them if
the expected output intentionally changes (e.g., the default recipe is
updated to add a new section). When regenerating, capture them from a
clean checkout of the pre-change commit, NOT from the post-change tree.
```

### Step 6: Verify everything from repo root

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "=== T05 Verification ==="

# Files
test -f .specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh && echo "PASS: harness file"
test -x .specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh && echo "PASS: harness executable"
test -f .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md && echo "PASS: golden payload"
test -f .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-compressed-budget2000.md && echo "PASS: golden compress"
test -f .specify/orchestrator/milestones/M004/phases/P05/fixtures/README.md && echo "PASS: README"

# Harness runs clean
bash .specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh && echo "PASS: parity harness clean" || echo "FAIL: parity harness"
```

## Must-Haves

### Truths

- Parity harness script exists and is executable
  - Check: `test -x .specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh`
- Golden payload fixture exists
  - Check: `test -f .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md`
- Golden compressed fixture exists
  - Check: `test -f .specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-compressed-budget2000.md`
- Fixtures README exists
  - Check: `test -f .specify/orchestrator/milestones/M004/phases/P05/fixtures/README.md`
- Parity harness exits 0 when run from repo root
  - Check: `bash .specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh`
- Harness is Bash 3.2 compatible
  - Check: `! grep -qE 'declare -A|readarray|mapfile' .specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh`

### Artifacts

- `.specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh` (min 40 lines, contains "diff")
- `.specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md` (min 20 lines, contains "Dispatch Context")
- `.specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-compressed-budget2000.md` (min 10 lines, contains "Dispatch Context" OR "Compressed")
- `.specify/orchestrator/milestones/M004/phases/P05/fixtures/README.md` (min 15 lines, contains "Normalization")

### Key Links

- `.specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh` → `scripts/dispatch/build-context.sh`
- `.specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh` → `scripts/dispatch/compress-payload.sh`
- `.specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh` → `scripts/dispatch/select-model.sh`

## Verification

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "=== T05 Verification ==="

FIX=.specify/orchestrator/milestones/M004/phases/P05/fixtures

# Harness file
test -f "$FIX/run-parity.sh" && echo "PASS: harness" || echo "FAIL"
test -x "$FIX/run-parity.sh" && echo "PASS: executable" || echo "FAIL"
lines=$(wc -l < "$FIX/run-parity.sh" | tr -d ' ')
test "$lines" -ge 40 && echo "PASS: $lines lines" || echo "FAIL"

# Golden fixtures
test -f "$FIX/golden-payload-M004-P04-T04.md" && echo "PASS: golden payload" || echo "FAIL"
test -f "$FIX/golden-compressed-budget2000.md" && echo "PASS: golden compressed" || echo "FAIL"
test -f "$FIX/README.md" && echo "PASS: README" || echo "FAIL"

# Bash 3.2 compat
! grep -qE 'declare -A|readarray|mapfile' "$FIX/run-parity.sh" && echo "PASS: Bash 3.2" || echo "FAIL"

# Harness runs clean
bash "$FIX/run-parity.sh" && echo "PASS: harness clean" || echo "FAIL: harness had failures"
```

## Inputs

### From Previous Tasks

- `scripts/dispatch/build-context.sh` (refactored in T02) — recipe-driven. Must produce output that matches `golden-payload-M004-P04-T04.md` modulo the manifest normalization columns.
- `scripts/dispatch/compress-payload.sh` (refactored in T03) — recipe-driven. Must produce output that matches `golden-compressed-budget2000.md` modulo the manifest normalization columns.
- `scripts/dispatch/select-model.sh` (refactored in T04) — adds `--list-fallback` and `--next-fallback` flags. Default-mode output must be byte-identical to pre-refactor for all 3 tiers.
- `.specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-payload-M004-P04-T04.md` (captured in T02 Step 1)
- `.specify/orchestrator/milestones/M004/phases/P05/fixtures/golden-compressed-budget2000.md` (captured in T03 Step 1)

### From Disk (Pre-existing)

- `templates/routing.yaml` — source of the expected fallback chains.
  - heavy primary: `claude-opus-4-6`, budget 200000, fallback `claude-sonnet-4-6,claude-haiku-4-5`
  - standard primary: `claude-sonnet-4-6`, budget 150000, fallback `claude-haiku-4-5`
  - light primary: `claude-haiku-4-5`, budget 80000, fallback `""`
- `templates/context-recipe.yaml` — the default recipe. The parity harness must NOT modify this file.
- `scripts/engine/run.sh` — NOT invoked by the harness. This harness validates individual dispatch scripts, not the engine coordinator.

## Expected Output

- `.specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh` — ~140-line Bash 3.2 harness that runs 6 check groups.
- `.specify/orchestrator/milestones/M004/phases/P05/fixtures/README.md` — short documentation of the normalization rules and regeneration procedure.
- All three golden fixtures present (two from upstream tasks, verified here).
- `bash .specify/orchestrator/milestones/M004/phases/P05/fixtures/run-parity.sh` exits 0 when run from repo root. Every check prints `PASS:`.
- No modifications to any file outside `.specify/orchestrator/milestones/M004/phases/P05/fixtures/`.
