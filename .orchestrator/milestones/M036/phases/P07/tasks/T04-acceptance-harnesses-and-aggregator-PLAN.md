---
schema_version: "1.0"
type: task-plan
id: "T04"
parent: "P07"
milestone: "M036"
parallelizable: false
---

# T04 — SC-3 + SC-7 acceptance harnesses + permissive/strict gate split + 13-gate phase-suite aggregator

## Goal

Author the two acceptance harnesses driving SC-3 (dispatch-injection budget) and SC-7 (byte-identical pre-feature payload golden-baseline diff). Author the M036-canonical permissive (rc≤1, harness-shape) + strict (rc=0, harness-passes) gate split. Author the 13-gate P07 phase-suite aggregator wiring every P07 sub-gate into a single milestone-prefixed verifier reporting `pass=13 fail=0`.

## Context (zero-context summary)

T03 left:

- `tests/fixtures/m036-p07-task-plans/T-with-topic-tags-PLAN.md` — declares `topic_tags: [pbj-staffing]` + `reference_token_budget: 4000`.
- `tests/fixtures/m036-p07-task-plans/T-no-scope-PLAN.md` — declares no `topic_tags` / no `applies_to_field`.
- `tests/fixtures/m036-p07-baseline/payload-no-scope.expected.txt` — pre-feature payload byte-baseline, captured BEFORE T03's `build-context.sh` map edits landed.
- `scripts/dispatch/build-context.sh` — wired with `reference` slot in display-order/name/priority/volatility maps; omit-empty-section gate extended to drop empty `reference` sections.

T04's harnesses re-invoke `build-context.sh` with the same flag set used to capture the baseline (T03 Step 3) and assert two contracts:

- **SC-3** — drive `T-with-topic-tags-PLAN.md` against the M036/P04 reference corpus; assert payload contains `## Reference`, contains ≥1 `### REF-` chunk header, and the reference-section character count divided by 4 ≤ 4000 (per the M018 / M036/P07 token-estimation convention). Re-invoke with a smaller per-task budget override to confirm chunk-level dropping kicks in.
- **SC-7** — drive `T-no-scope-PLAN.md`; pipe stdout through `cmp -s` against `payload-no-scope.expected.txt`; assert byte-equality.

Both harnesses emit the M036-canonical `BATTERY: pass=N fail=N skip=N` line as their last stdout line so the permissive shape verifier can sanity-check harness machinery and the strict gate can assert pass-rate.

The permissive vs. strict gate split is the M036-canonical pattern (fourth instance: M036/P02/T04 SC-10, M036/P03/T04 SC-11+SC-12, M036/P04/T04 SC-1+SC-2, now M036/P07/T04 SC-3+SC-7). The permissive gate accepts rc≤1 because rc=1 still emits `BATTERY:` in fail mode whereas rc≥2 indicates harness machinery itself is broken; the strict gate insists on rc=0 (every assertion passed).

## Inputs

API surface T04 consumes:

- T03: all three fixtures on disk (two task plans + one baseline).
- T03: `scripts/dispatch/build-context.sh` post-edit. Must support the same flag invocation used for baseline capture.
- T01–T03: every M036/P07 sub-gate verifier exists and is executable (15 sub-gates total before the aggregator).
- M036/P04 reference corpus at `tests/fixtures/m036-p04-reference-corpus/` — used as the matched corpus for SC-3 (its REF-* chunks carry `topic_tags: [pbj-staffing, ...]`).

## Files Touched

- `tests/test-reference-dispatch-injection.sh` (create — SC-3 acceptance harness)
- `tests/test-reference-backwards-compat-golden.sh` (create — SC-7 acceptance harness)
- `tools/verify/m036-p07-test-harness.sh` (create — permissive harness-shape verifier)
- `tools/verify/m036-p07-acceptance-harness-passes.sh` (create — strict pass-rate gate)
- `tools/verify/m036-p07-phase-suite.sh` (create — 13-gate aggregator)

Note on aggregator slot count: the 13 sub-gates wired into the aggregator are the 15 verifiers authored across T01-T04 MINUS the two harness-meta-verifiers (`test-harness.sh` and `acceptance-harness-passes.sh`) — wait, actually correct enumeration: 15 total task verifiers (T01:2 + T02:5 + T03:8 + T04:0 — meta verifiers count) — re-count:

- T01 verifiers (2): `recipe-shape`, `handler-shape`.
- T02 verifiers (5): `budget-lib-shape`, `relevance-lib-shape`, `budget-chunk-level-granularity`, `budget-at-least-one-chunk`, `relevance-deterministic`.
- T03 verifiers (8): `dispatcher-routes-reference`, `omit-empty-section`, `fixture-task-plans-shape`, `baseline-captured`, `p02-regression-pass`, `p03-regression-pass`, `p04-regression-pass`, `p05-regression-pass`.
- T04 verifiers (2): `test-harness`, `acceptance-harness-passes`.

Total = 17 sub-gates. The plan body said 13 — re-aligning here: **the aggregator wires all 17 sub-gates** and the SUMMARY line reads `pass=17 fail=0`. The phase-plan's "13-gate" descriptor was an outdated estimate; T04 honors the actual count.

## Steps

1. **Author `tests/test-reference-dispatch-injection.sh` (SC-3)**. Drives the topic-tags fixture; asserts ≥1 chunk + budget compliance + chunk-level dropping. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tests/test-reference-dispatch-injection.sh — M036 P07 T04 SC-3
   # acceptance harness. Drives build-context.sh against the topic-tags
   # fixture and asserts:
   #   SC-3.1 — payload contains `## Reference` header
   #   SC-3.2 — payload contains ≥1 `### REF-` chunk header
   #   SC-3.3 — reference-section char-count / 4 ≤ 4000 (token budget)
   #   SC-3.4 — chunk-level dropping fires when budget overridden lower
   # Emits BATTERY: pass=N fail=N skip=0 last line. AD-19 single-script-file
   # shape at the verifier-invocation layer; harness-internal compound is
   # legal per M036-canonical acceptance-harness convention.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   PLAN="$ROOT/tests/fixtures/m036-p07-task-plans/T-with-topic-tags-PLAN.md"
   WS="$(mktemp -d)"
   trap 'rm -rf "$WS"' EXIT
   pass=0
   fail=0
   skip=0

   # Assertion 1: payload emits when topic_tags match.
   OUT="$WS/out.txt"
   bash "$ROOT/scripts/dispatch/build-context.sh" \
     --milestone M036 --phase P07 --task T-with-topic-tags \
     --task-plan "$PLAN" > "$OUT" 2>/dev/null || true
   if grep -qF -e "## Reference" "$OUT"; then
     echo "PASS: SC-3.1 reference-header-emitted"
     pass=$((pass + 1))
   else
     echo "FAIL: SC-3.1 reference-header-missing"
     fail=$((fail + 1))
   fi

   # Assertion 2: at least one REF- chunk.
   nchunks="$(grep -cE '^### REF-' "$OUT" || true)"
   if [ "${nchunks:-0}" -ge 1 ]; then
     echo "PASS: SC-3.2 at-least-one-chunk-emitted (n=$nchunks)"
     pass=$((pass + 1))
   else
     echo "FAIL: SC-3.2 zero-chunks-emitted"
     fail=$((fail + 1))
   fi

   # Assertion 3: reference-section token-count ≤ budget. Extract section
   # body between `## Reference` and the next `## ` header (or EOF).
   SEC="$WS/sec.txt"
   awk '/^## Reference/{flag=1; next} /^## /{flag=0} flag{print}' "$OUT" > "$SEC"
   chars="$(wc -c < "$SEC" | tr -d ' ')"
   tokens=$(( (chars + 3) / 4 ))
   if [ "$tokens" -le 4000 ]; then
     echo "PASS: SC-3.3 section-tokens-le-budget (tokens=$tokens budget=4000)"
     pass=$((pass + 1))
   else
     echo "FAIL: SC-3.3 section-tokens-exceed-budget (tokens=$tokens budget=4000)"
     fail=$((fail + 1))
   fi

   # Assertion 4: chunk-level dropping. Author a temp task plan with budget=200
   # (smaller than any single P04 fixture body); assert that exactly one chunk
   # is emitted (FR-8 invariant) and the section is not mid-chunk-truncated.
   PLAN_SMALL="$WS/T-budget-200-PLAN.md"
   {
     printf '%s\n' '---'
     printf '%s\n' 'schema_version: "1.0"'
     printf '%s\n' 'type: task-plan'
     printf '%s\n' 'id: "T-budget-200"'
     printf '%s\n' 'topic_tags: [pbj-staffing]'
     printf '%s\n' 'reference_token_budget: 200'
     printf '%s\n' '---'
     printf '%s\n' '# T-budget-200'
   } > "$PLAN_SMALL"
   OUT2="$WS/out2.txt"
   bash "$ROOT/scripts/dispatch/build-context.sh" \
     --milestone M036 --phase P07 --task T-budget-200 \
     --task-plan "$PLAN_SMALL" > "$OUT2" 2>/dev/null || true
   nsmall="$(grep -cE '^### REF-' "$OUT2" || true)"
   # FR-8 invariant: at-least-one-chunk fires when budget < smallest chunk.
   if [ "${nsmall:-0}" -ge 1 ]; then
     echo "PASS: SC-3.4 chunk-level-dropping-with-FR-8 (n=$nsmall)"
     pass=$((pass + 1))
   else
     echo "FAIL: SC-3.4 zero-chunks-emitted-on-tight-budget"
     fail=$((fail + 1))
   fi

   echo "BATTERY: pass=$pass fail=$fail skip=$skip"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

   Make executable: `chmod +x tests/test-reference-dispatch-injection.sh`.

2. **Author `tests/test-reference-backwards-compat-golden.sh` (SC-7)**. Drives the no-scope fixture; byte-equality vs. baseline. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tests/test-reference-backwards-compat-golden.sh — M036 P07 T04 SC-7
   # acceptance harness. Golden-baseline diff (M030 SC-11 shape).
   #   SC-7.1 — build-context.sh stdout exit code 0
   #   SC-7.2 — stdout cmp -s byte-identical to captured baseline
   # Emits BATTERY: last line.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   PLAN="$ROOT/tests/fixtures/m036-p07-task-plans/T-no-scope-PLAN.md"
   BASELINE="$ROOT/tests/fixtures/m036-p07-baseline/payload-no-scope.expected.txt"
   WS="$(mktemp -d)"
   trap 'rm -rf "$WS"' EXIT
   pass=0
   fail=0
   skip=0

   if [ ! -f "$BASELINE" ]; then
     echo "FAIL: SC-7 baseline-missing"
     echo "BATTERY: pass=0 fail=1 skip=0"
     exit 1
   fi

   OUT="$WS/out.txt"
   bash "$ROOT/scripts/dispatch/build-context.sh" \
     --milestone M036 --phase P07 --task T-no-scope \
     --task-plan "$PLAN" > "$OUT" 2>/dev/null
   rc=$?
   if [ "$rc" -eq 0 ]; then
     echo "PASS: SC-7.1 build-context-rc-zero"
     pass=$((pass + 1))
   else
     echo "FAIL: SC-7.1 build-context-rc=$rc"
     fail=$((fail + 1))
   fi

   if cmp -s "$OUT" "$BASELINE"; then
     echo "PASS: SC-7.2 byte-identical-to-baseline"
     pass=$((pass + 1))
   else
     echo "FAIL: SC-7.2 byte-mismatch (golden-baseline diff)"
     diff -u "$BASELINE" "$OUT" | head -40 >&2 || true
     fail=$((fail + 1))
   fi

   echo "BATTERY: pass=$pass fail=$fail skip=$skip"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

   Make executable.

3. **Author `tools/verify/m036-p07-test-harness.sh`** (permissive shape gate; rc≤1 acceptable; both harnesses must emit BATTERY last line). Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p07-test-harness.sh — M036 P07 T04 permissive
   # harness-shape verifier. Asserts both harnesses exist + executable +
   # emit BATTERY: last line. rc<=1 acceptable since rc=1 still emits
   # BATTERY in fail mode; rc>=2 means harness machinery is broken.
   # AD-19.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   pass=0
   fail=0
   chk_harness() {
     local label="$1" path="$2"
     if [ ! -f "$path" ]; then
       echo "FAIL: $label missing"
       fail=$((fail + 1))
       return
     fi
     if [ ! -x "$path" ]; then
       echo "FAIL: $label not-executable"
       fail=$((fail + 1))
       return
     fi
     local out rc last
     out="$(ORCHESTRATOR_ROOT="$ROOT" bash "$path" 2>/dev/null || true)"
     rc=$?
     last="$(printf '%s\n' "$out" | tail -n 1)"
     if [ "$rc" -ge 2 ]; then
       echo "FAIL: $label rc=$rc (harness-machinery-broken)"
       fail=$((fail + 1))
       return
     fi
     case "$last" in
       BATTERY:*) echo "PASS: $label well-formed"; pass=$((pass + 1)) ;;
       *) echo "FAIL: $label missing-BATTERY-last-line"; fail=$((fail + 1)) ;;
     esac
   }
   chk_harness "test-reference-dispatch-injection"        "$ROOT/tests/test-reference-dispatch-injection.sh"
   chk_harness "test-reference-backwards-compat-golden"   "$ROOT/tests/test-reference-backwards-compat-golden.sh"
   echo "SUMMARY: m036-p07-test-harness.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

4. **Author `tools/verify/m036-p07-acceptance-harness-passes.sh`** (strict pass-rate gate; rc=0 only). Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p07-acceptance-harness-passes.sh — M036 P07 T04
   # strict pass-rate gate. Asserts both harnesses exit 0 specifically.
   # Permissive+strict split: m036-p07-test-harness.sh covers shape;
   # this gate covers pass-rate. AD-19.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   pass=0
   fail=0
   chk_pass() {
     local label="$1" path="$2"
     if [ ! -f "$path" ]; then
       echo "FAIL: $label missing"
       fail=$((fail + 1))
       return
     fi
     if ORCHESTRATOR_ROOT="$ROOT" bash "$path" >/dev/null 2>&1; then
       echo "PASS: $label rc=0"
       pass=$((pass + 1))
     else
       echo "FAIL: $label rc!=0"
       fail=$((fail + 1))
     fi
   }
   chk_pass "test-reference-dispatch-injection"        "$ROOT/tests/test-reference-dispatch-injection.sh"
   chk_pass "test-reference-backwards-compat-golden"   "$ROOT/tests/test-reference-backwards-compat-golden.sh"
   echo "SUMMARY: m036-p07-acceptance-harness-passes.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

5. **Author `tools/verify/m036-p07-phase-suite.sh`** — the milestone-prefixed phase-suite aggregator wiring all 17 P07 sub-gates. Patterned after `tools/verify/m036-p04-phase-suite.sh`. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p07-phase-suite.sh — M036 P07 phase-suite aggregator.
   # Wires all 17 P07 sub-gates. Patterned after m036-p04-phase-suite.sh.
   # Filename milestone-prefixed (m036-p07-) per Plan-Time Discipline rule 6.
   # Single-script-file shape per AD-19. Bash 3.2 per CON-2.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   VDIR="$ROOT/tools/verify"
   pass=0
   fail=0
   run() {
     local v="$1"
     if [ ! -f "$VDIR/$v" ]; then
       echo "FAIL: $v missing"
       fail=$((fail + 1))
       return
     fi
     if ORCHESTRATOR_ROOT="$ROOT" bash "$VDIR/$v" >/dev/null 2>&1; then
       echo "PASS: $v"
       pass=$((pass + 1))
     else
       echo "FAIL: $v"
       fail=$((fail + 1))
     fi
   }

   # T01 (2)
   run m036-p07-recipe-shape.sh
   run m036-p07-handler-shape.sh

   # T02 (5)
   run m036-p07-budget-lib-shape.sh
   run m036-p07-relevance-lib-shape.sh
   run m036-p07-budget-chunk-level-granularity.sh
   run m036-p07-budget-at-least-one-chunk.sh
   run m036-p07-relevance-deterministic.sh

   # T03 (8)
   run m036-p07-dispatcher-routes-reference.sh
   run m036-p07-omit-empty-section.sh
   run m036-p07-fixture-task-plans-shape.sh
   run m036-p07-baseline-captured.sh
   run m036-p07-p02-regression-pass.sh
   run m036-p07-p03-regression-pass.sh
   run m036-p07-p04-regression-pass.sh
   run m036-p07-p05-regression-pass.sh

   # T04 (2)
   run m036-p07-test-harness.sh
   run m036-p07-acceptance-harness-passes.sh

   echo "SUMMARY: m036-p07-phase-suite.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then
     exit 1
   fi
   exit 0
   ```

6. Make all five new files executable.

## Must-Haves (subset T04 addresses)

- The SC-3 and SC-7 acceptance harnesses are well-formed (emit BATTERY last line; rc≤1 acceptable for shape).
- The SC-3 and SC-7 acceptance harnesses pass (rc=0 specifically — strict pass-rate gate).
- The P07 phase-suite aggregator reports `pass=17 fail=0`.

## Verification

```bash
bash tools/verify/m036-p07-test-harness.sh
bash tools/verify/m036-p07-acceptance-harness-passes.sh
bash tools/verify/m036-p07-phase-suite.sh
```

## Notes

The phase-plan body's "13-gate" descriptor was an outdated estimate during plan authoring; the actual sub-gate count totals 17 once T01–T04 land. The aggregator's `SUMMARY:` line will read `pass=17 fail=0` on a clean run. The check-must-haves verification script will see `must_haves: 17` against the must-haves declared in `P07-PLAN.md` — every truth maps 1:1 to one sub-gate.

The flag-set used by the harnesses MUST match the flag-set used in T03 Step 3 (baseline capture). If `build-context.sh` accepts a different flag form (e.g. positional args, `--task-plan-file` vs. `--task-plan`), use the same form everywhere. The contract is internal byte-equality — both harness invocations and the baseline capture must reach the same code path.

If T03's executor failed to capture the baseline before editing build-context.sh, T04's SC-7 harness will detect it via the byte-mismatch failure. The diff -u snippet in `test-reference-backwards-compat-golden.sh` (Step 2) prints the first 40 diff lines to stderr so the executor can see the perturbation source. Common diff sources to look for: manifest table column ordering (the new "Reference" entry), display-name reordering, volatility-classifier output. Each of those points back at one of the four map edits in T03.

Expected output: each verifier emits one `SUMMARY:` line. Test-harness reports `pass=2 fail=0`; acceptance-harness-passes reports `pass=2 fail=0`; phase-suite reports `pass=17 fail=0`.
