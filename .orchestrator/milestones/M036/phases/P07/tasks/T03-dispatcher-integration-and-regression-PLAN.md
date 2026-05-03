---
schema_version: "1.0"
type: task-plan
id: "T03"
parent: "P07"
milestone: "M036"
parallelizable: false
---

# T03 — Dispatcher integration + fixture task-plans + baseline + cross-phase regressions

## Goal

Wire the new `reference` source into `scripts/dispatch/build-context.sh`'s display-order / display-name / display-priority / volatility maps so the dispatcher can route the recipe section authored in T01. CAPTURE the pre-feature payload baseline at `tests/fixtures/m036-p07-baseline/payload-no-scope.expected.txt` BEFORE editing build-context.sh — this is the load-bearing CON-1 / SC-7 sequencing nuance. Author the two synthetic task-plan fixtures driving SC-3 and SC-7. Author the four cross-phase regression verifiers (P02 selective + P03 + P04 + P05 full pass-through).

## Context (zero-context summary)

`scripts/dispatch/build-context.sh` is the dispatch context-builder (~2050 lines). It parses the recipe, sorts sections by a `_bc_display_order()` map (lines ~1787), names them via `_bc_display_name()` (lines ~1800), classifies their priority via `_bc_display_priority()` (lines ~1813), and classifies their volatility via `_bc_section_volatility_by_name()` (lines ~1955). It then dispatches each section through `dispatch_section_handler` from `scripts/dispatch/lib/section-handlers.sh`. T01 added a `reference)` arm to that dispatcher; T02 filled the handler body. T03's job is to make `build-context.sh` know about the new `reference` slot in the four small map functions — without those edits the section would default to `order 99` and the manifest's display would be wrong.

The omit-empty-section discipline already exists for `spec_context` at `build-context.sh` line ~1995 (`if [ "$s_source" = "spec_context" ] && [ ! -s "$staging_file" ]`). T03 extends this to `reference` so empty handler output drops the section entirely.

The pre-feature payload baseline is the byte-string that build-context.sh emits TODAY (post-T01+T02, but before any dispatcher map edits) when run against a no-scope task plan. Capturing the baseline immediately before the map edits and asserting byte-equality post-edit is the strongest possible CON-1 guard. Pattern carried verbatim from M036/P05 (`tests/fixtures/m036-p05-baseline/`).

The selective-gate-list cross-phase regression pattern is M036-canonical: P02's `m036-p02-tier-2-deferred-error.sh` semantics flipped at P03 close (P03 implemented the Tier 2 path P02 deferred), so any future regression check targeting the P02 phase-suite must explicitly enumerate 14 of 15 sub-gates and skip the flipped one. P03/P04/P05 phase-suites have no flipped sub-gates affecting P07 — full pass-through is correct.

## Inputs

API surface T03 consumes (from upstream):

- T01 + T02: `templates/context-recipe.yaml` declares the `reference:` section + `default_token_budget: 4000`. `scripts/dispatch/lib/section-handlers.sh::handle_reference` is wired with the live body. Both files are stable as of T02 close.
- P02 phase-suite: `tools/verify/m036-p02-phase-suite.sh` — 15 sub-gates wired; `m036-p02-tier-2-deferred-error.sh` semantics flipped at P03 close.
- P03 phase-suite: `tools/verify/m036-p03-phase-suite.sh` — 14 sub-gates wired; full pass-through expected.
- P04 phase-suite: `tools/verify/m036-p04-phase-suite.sh` — 13 sub-gates wired; full pass-through expected.
- P05 phase-suite: `tools/verify/m036-p05-phase-suite.sh` — 8 sub-gates wired including default-mode CON-5 byte-equality baselines for `traverse-graph.sh` + `scope-filter.sh`. P07 does NOT edit either script; full pass-through expected.

## Files Touched

- `tests/fixtures/m036-p07-task-plans/T-with-topic-tags-PLAN.md` (create)
- `tests/fixtures/m036-p07-task-plans/T-no-scope-PLAN.md` (create)
- `tests/fixtures/m036-p07-baseline/payload-no-scope.expected.txt` (create — captured BEFORE map edits)
- `scripts/dispatch/build-context.sh` (modify — four map-function arms + omit-empty-section gate)
- `tools/verify/m036-p07-dispatcher-routes-reference.sh` (create)
- `tools/verify/m036-p07-omit-empty-section.sh` (create)
- `tools/verify/m036-p07-fixture-task-plans-shape.sh` (create)
- `tools/verify/m036-p07-baseline-captured.sh` (create)
- `tools/verify/m036-p07-p02-regression-pass.sh` (create)
- `tools/verify/m036-p07-p03-regression-pass.sh` (create)
- `tools/verify/m036-p07-p04-regression-pass.sh` (create)
- `tools/verify/m036-p07-p05-regression-pass.sh` (create)

## Steps

1. **Author the fixture task plan with topic_tags** at `tests/fixtures/m036-p07-task-plans/T-with-topic-tags-PLAN.md`. Verbatim:

   ```markdown
   ---
   schema_version: "1.0"
   type: task-plan
   id: "T-with-topic-tags"
   parent: "P-fixture"
   milestone: "M-fixture"
   topic_tags: [pbj-staffing]
   reference_token_budget: 4000
   ---

   # T-with-topic-tags — synthetic SC-3 fixture task plan

   ## Goal

   Drive build-context.sh's reference-injection path. The matched corpus is
   the M036/P04 reference fixture corpus at
   `tests/fixtures/m036-p04-reference-corpus/` whose REF-* chunks carry
   `topic_tags: [pbj-staffing, ...]`.

   ## Verification

   `bash scripts/dispatch/build-context.sh` (driven by SC-3 harness).
   ```

2. **Author the no-scope fixture task plan** at `tests/fixtures/m036-p07-task-plans/T-no-scope-PLAN.md`. Verbatim:

   ```markdown
   ---
   schema_version: "1.0"
   type: task-plan
   id: "T-no-scope"
   parent: "P-fixture"
   milestone: "M-fixture"
   scope_tags: [project]
   ---

   # T-no-scope — synthetic SC-7 baseline fixture task plan

   ## Goal

   Trigger the CON-1 / SC-7 byte-identical pre-feature payload path. This
   plan declares NO topic_tags and NO applies_to_field, so handle_reference
   returns empty stdout, the omit-empty-section gate drops the section, and
   the payload should be byte-identical to the pre-feature baseline.

   ## Verification

   `bash scripts/dispatch/build-context.sh` (driven by SC-7 golden harness).
   ```

3. **CRITICAL — CAPTURE THE BASELINE BEFORE EDITING build-context.sh.** Run the dispatcher against the no-scope fixture and persist its exact byte output. Use the existing M036/P04 reference corpus root and the orchestrator's own milestone directory shape. Verbatim command:

   ```bash
   mkdir -p tests/fixtures/m036-p07-baseline
   bash scripts/dispatch/build-context.sh \
     --milestone M036 --phase P07 --task T-no-scope \
     --task-plan tests/fixtures/m036-p07-task-plans/T-no-scope-PLAN.md \
     > tests/fixtures/m036-p07-baseline/payload-no-scope.expected.txt
   ```

   If `build-context.sh`'s flag surface differs at the exact-flag level (the file is large and has evolved), use the equivalent invocation by inspecting `bash scripts/dispatch/build-context.sh --help` first. The contract is: drive the no-scope fixture through the dispatcher and persist the exact stdout.

   **DO NOT proceed past this step without the baseline file existing on disk.** The `m036-p07-baseline-captured.sh` verifier (Step 9) will fail otherwise, surfacing the missed sequencing immediately.

4. **Edit `scripts/dispatch/build-context.sh` — `_bc_display_order()`**. Find the function near line 1787. Insert the new arm between `spec_context)` and the wildcard `*)`:

   ```bash
       reference)   echo 4 ;;  # filtered — task-scoped reference chunks (M036/P07)
   ```

   Adjust the `spec_context)` arm's `echo 4` to remain (both at order 4 is acceptable — secondary sort is the sort -k1,1n stability of input order). Alternatively use `echo 5` for the new `reference` arm and bump downstream arms by 1; the simpler form (both at 4) preserves byte-equality of the no-scope payload because no-scope drops the reference section entirely, so the manifest never lists it.

   **Recommended verbatim**: insert the line above with `echo 4` to minimize delta from the captured baseline.

5. **Edit `_bc_display_name()`**. Find the function near line 1800. Insert:

   ```bash
       reference)    echo "Reference" ;;
   ```

6. **Edit `_bc_display_priority()`**. Find the function near line 1813. Update the existing `knowledge|decisions|spec_context)` arm to include `reference`:

   ```bash
       knowledge|decisions|spec_context|reference) echo "filtered" ;;
   ```

7. **Edit `_bc_section_volatility_by_name()`**. Find the function near line 1955. Update the `stable` arm to include `"Reference"`:

   ```bash
       Knowledge|Knowledge\ *|Decisions|Constraints|Scope|"Spec Context"|"Reference") echo "stable" ;;
   ```

8. **Extend the omit-empty-section gate at line ~1995**. Change:

   ```bash
     if [ "$s_source" = "spec_context" ] && [ ! -s "$staging_file" ]; then
   ```

   to:

   ```bash
     if { [ "$s_source" = "spec_context" ] || [ "$s_source" = "reference" ]; } && [ ! -s "$staging_file" ]; then
   ```

   This drops the empty `reference` section the same way `spec_context` is dropped. Critical for SC-7.

9. **Author `tools/verify/m036-p07-dispatcher-routes-reference.sh`**. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p07-dispatcher-routes-reference.sh — M036 P07 T03
   # asserts build-context.sh's display-order/name/priority/volatility maps
   # each contain a reference slot. AD-19 single-script-file shape.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   F="$ROOT/scripts/dispatch/build-context.sh"
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
     echo "SUMMARY: m036-p07-dispatcher-routes-reference.sh pass=0 fail=1"
     exit 1
   fi
   check "display-order-arm"      "reference)   echo 4"
   check "display-name-arm"       'reference)    echo "Reference"'
   check "display-priority-arm"   "spec_context|reference)"
   check "volatility-arm"         '"Reference") echo "stable"'
   check "omit-empty-extension"   '[ "$s_source" = "reference" ]'
   echo "SUMMARY: m036-p07-dispatcher-routes-reference.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

10. **Author `tools/verify/m036-p07-omit-empty-section.sh`**. Behavioral verifier — drives build-context.sh against a task plan with non-matching topic_tags; asserts no `## Reference` header in stdout. Verbatim:

    ```bash
    #!/usr/bin/env bash
    # tools/verify/m036-p07-omit-empty-section.sh — M036 P07 T03 behavioral
    # verifier asserting non-matching topic_tags produce zero `## Reference`
    # header in the dispatched payload (omit-empty-section discipline).
    # AD-19 single-script-file shape.
    set -eu
    ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
    WS="$(mktemp -d)"
    trap 'rm -rf "$WS"' EXIT
    PLAN="$WS/T-mismatch-PLAN.md"
    {
      printf '%s\n' '---'
      printf '%s\n' 'schema_version: "1.0"'
      printf '%s\n' 'type: task-plan'
      printf '%s\n' 'id: "T-mismatch"'
      printf '%s\n' 'topic_tags: [does-not-match-anything]'
      printf '%s\n' '---'
      printf '%s\n' '# T-mismatch'
    } > "$PLAN"
    OUT="$WS/out.txt"
    bash "$ROOT/scripts/dispatch/build-context.sh" \
      --milestone M036 --phase P07 --task T-mismatch \
      --task-plan "$PLAN" > "$OUT" 2>/dev/null || true
    pass=0
    fail=0
    if grep -qF -e "## Reference" "$OUT"; then
      echo "FAIL: reference-section-emitted-when-no-matches"
      fail=$((fail + 1))
    else
      echo "PASS: omit-empty-section-honored"
      pass=$((pass + 1))
    fi
    echo "SUMMARY: m036-p07-omit-empty-section.sh pass=$pass fail=$fail"
    if [ "$fail" -gt 0 ]; then exit 1; fi
    exit 0
    ```

11. **Author `tools/verify/m036-p07-fixture-task-plans-shape.sh`**. Verbatim:

    ```bash
    #!/usr/bin/env bash
    # tools/verify/m036-p07-fixture-task-plans-shape.sh — M036 P07 T03
    # token-presence verifier for the two synthetic fixture task plans.
    # AD-19.
    set -eu
    ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
    F1="$ROOT/tests/fixtures/m036-p07-task-plans/T-with-topic-tags-PLAN.md"
    F2="$ROOT/tests/fixtures/m036-p07-task-plans/T-no-scope-PLAN.md"
    pass=0
    fail=0
    chk() {
      local label="$1" file="$2" pat="$3"
      if [ -f "$file" ] && grep -qF -e "$pat" "$file"; then
        echo "PASS: $label"
        pass=$((pass + 1))
      else
        echo "FAIL: $label"
        fail=$((fail + 1))
      fi
    }
    chk "with-topic-tags-exists"        "$F1" "topic_tags: [pbj-staffing]"
    chk "with-topic-tags-budget"        "$F1" "reference_token_budget: 4000"
    chk "no-scope-exists"               "$F2" "scope_tags: [project]"
    chk "no-scope-no-topic-tags"        "$F2" "T-no-scope"
    if [ -f "$F2" ]; then
      if grep -qF -e "topic_tags:" "$F2"; then
        echo "FAIL: no-scope-fixture-must-not-declare-topic_tags"
        fail=$((fail + 1))
      else
        echo "PASS: no-scope-has-no-topic_tags"
        pass=$((pass + 1))
      fi
    fi
    echo "SUMMARY: m036-p07-fixture-task-plans-shape.sh pass=$pass fail=$fail"
    if [ "$fail" -gt 0 ]; then exit 1; fi
    exit 0
    ```

12. **Author `tools/verify/m036-p07-baseline-captured.sh`**. Verbatim:

    ```bash
    #!/usr/bin/env bash
    # tools/verify/m036-p07-baseline-captured.sh — M036 P07 T03 sanity
    # verifier asserting the SC-7 golden baseline file exists and is
    # non-empty. AD-19. Load-bearing CON-1/SC-7 sequencing guard.
    set -eu
    ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
    F="$ROOT/tests/fixtures/m036-p07-baseline/payload-no-scope.expected.txt"
    pass=0
    fail=0
    if [ ! -f "$F" ]; then
      echo "FAIL: baseline-file-missing ($F)"
      fail=$((fail + 1))
    elif [ ! -s "$F" ]; then
      echo "FAIL: baseline-file-empty"
      fail=$((fail + 1))
    else
      echo "PASS: baseline-exists-and-non-empty"
      pass=$((pass + 1))
      # Sanity: baseline should contain the canonical Manifest header
      # emitted by build-context.sh's manifest builder.
      if grep -qF -e "Manifest" "$F"; then
        echo "PASS: baseline-contains-Manifest-header"
        pass=$((pass + 1))
      else
        echo "FAIL: baseline-missing-Manifest-header"
        fail=$((fail + 1))
      fi
    fi
    echo "SUMMARY: m036-p07-baseline-captured.sh pass=$pass fail=$fail"
    if [ "$fail" -gt 0 ]; then exit 1; fi
    exit 0
    ```

13. **Author `tools/verify/m036-p07-p02-regression-pass.sh`** (selective gate list — exclude P03-flipped gate). Verbatim:

    ```bash
    #!/usr/bin/env bash
    # tools/verify/m036-p07-p02-regression-pass.sh — M036 P07 T03 cross-
    # phase regression. Re-runs 14 of the 15 P02 sub-gates excluding
    # m036-p02-tier-2-deferred-error.sh whose semantics intentionally
    # flipped at P03 close. Selective-gate-list pattern carried verbatim
    # from M036/P03/T03 + M036/P04/T04. AD-19.
    set -eu
    ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
    VDIR="$ROOT/tools/verify"
    pass=0
    fail=0
    run() {
      local g="$1"
      if [ ! -f "$VDIR/$g" ]; then
        echo "FAIL: $g missing"
        fail=$((fail + 1))
        return
      fi
      if ORCHESTRATOR_ROOT="$ROOT" bash "$VDIR/$g" >/dev/null 2>&1; then
        echo "PASS: $g"
        pass=$((pass + 1))
      else
        echo "FAIL: $g"
        fail=$((fail + 1))
      fi
    }
    # 14 of 15 P02 sub-gates (excluding m036-p02-tier-2-deferred-error.sh).
    run m036-p02-manifest-contract-shape.sh
    run m036-p02-fixture-manifest-shape.sh
    run m036-p02-fixture-corpus-shape.sh
    run m036-p02-extract-driver-shape.sh
    run m036-p02-binary-preservation.sh
    run m036-p02-content-hash.sh
    run m036-p02-size-cap-external-pointer.sh
    run m036-p02-extract-md.sh
    run m036-p02-extract-pdf-host-aware.sh
    run m036-p02-extract-docx-host-aware.sh
    run m036-p02-extract-command-shape.sh
    run m036-p02-summary-mode-stub-vs-operator.sh
    run m036-p02-idempotency.sh
    run m036-p02-test-harness.sh
    echo "SUMMARY: m036-p07-p02-regression-pass.sh pass=$pass fail=$fail"
    if [ "$fail" -gt 0 ]; then exit 1; fi
    exit 0
    ```

14. **Author `tools/verify/m036-p07-p03-regression-pass.sh`**. Verbatim:

    ```bash
    #!/usr/bin/env bash
    # tools/verify/m036-p07-p03-regression-pass.sh — M036 P07 T03 cross-
    # phase regression. Re-runs the M036/P03 phase-suite aggregator and
    # asserts pass=14 fail=0. Full pass-through (no semantics flips
    # affecting P07). AD-19.
    set -eu
    ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
    AGG="$ROOT/tools/verify/m036-p03-phase-suite.sh"
    pass=0
    fail=0
    if [ ! -f "$AGG" ]; then
      echo "FAIL: $AGG missing"
      echo "SUMMARY: m036-p07-p03-regression-pass.sh pass=0 fail=1"
      exit 1
    fi
    if ORCHESTRATOR_ROOT="$ROOT" bash "$AGG" >/dev/null 2>&1; then
      echo "PASS: m036-p03-phase-suite-passes"
      pass=$((pass + 1))
    else
      echo "FAIL: m036-p03-phase-suite-failed"
      fail=$((fail + 1))
    fi
    echo "SUMMARY: m036-p07-p03-regression-pass.sh pass=$pass fail=$fail"
    if [ "$fail" -gt 0 ]; then exit 1; fi
    exit 0
    ```

15. **Author `tools/verify/m036-p07-p04-regression-pass.sh`**. Same shape as Step 14 but pointing at `m036-p04-phase-suite.sh`. Verbatim:

    ```bash
    #!/usr/bin/env bash
    # tools/verify/m036-p07-p04-regression-pass.sh — M036 P07 T03 cross-
    # phase regression. Full pass-through of M036/P04 phase-suite. AD-19.
    set -eu
    ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
    AGG="$ROOT/tools/verify/m036-p04-phase-suite.sh"
    pass=0
    fail=0
    if [ ! -f "$AGG" ]; then
      echo "FAIL: $AGG missing"
      echo "SUMMARY: m036-p07-p04-regression-pass.sh pass=0 fail=1"
      exit 1
    fi
    if ORCHESTRATOR_ROOT="$ROOT" bash "$AGG" >/dev/null 2>&1; then
      echo "PASS: m036-p04-phase-suite-passes"
      pass=$((pass + 1))
    else
      echo "FAIL: m036-p04-phase-suite-failed"
      fail=$((fail + 1))
    fi
    echo "SUMMARY: m036-p07-p04-regression-pass.sh pass=$pass fail=$fail"
    if [ "$fail" -gt 0 ]; then exit 1; fi
    exit 0
    ```

16. **Author `tools/verify/m036-p07-p05-regression-pass.sh`**. Same shape, pointing at `m036-p05-phase-suite.sh`. Verbatim:

    ```bash
    #!/usr/bin/env bash
    # tools/verify/m036-p07-p05-regression-pass.sh — M036 P07 T03 cross-
    # phase regression. Full pass-through of M036/P05 phase-suite,
    # including the CON-5 default-mode byte-equality baselines for
    # traverse-graph.sh and scope-filter.sh which P07 consumes
    # unchanged. Load-bearing assertion that P07 did not perturb either
    # script. AD-19.
    set -eu
    ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
    AGG="$ROOT/tools/verify/m036-p05-phase-suite.sh"
    pass=0
    fail=0
    if [ ! -f "$AGG" ]; then
      echo "FAIL: $AGG missing"
      echo "SUMMARY: m036-p07-p05-regression-pass.sh pass=0 fail=1"
      exit 1
    fi
    if ORCHESTRATOR_ROOT="$ROOT" bash "$AGG" >/dev/null 2>&1; then
      echo "PASS: m036-p05-phase-suite-passes"
      pass=$((pass + 1))
    else
      echo "FAIL: m036-p05-phase-suite-failed"
      fail=$((fail + 1))
    fi
    echo "SUMMARY: m036-p07-p05-regression-pass.sh pass=$pass fail=$fail"
    if [ "$fail" -gt 0 ]; then exit 1; fi
    exit 0
    ```

17. Make all eight new verifier scripts executable.

## Must-Haves (subset T03 addresses)

- `scripts/dispatch/build-context.sh` recognizes the new `reference` source — display-order / name / priority / volatility maps each contain a `reference` slot.
- A task plan declaring `topic_tags` that match no chunks produces a payload with NO `## Reference` header.
- The two synthetic task-plan fixtures and the pre-feature payload baseline exist on disk.
- The pre-feature payload baseline file exists, is non-empty, and was captured before T03's dispatcher edits.
- M036/P02 phase-suite (selective 14 of 15 sub-gates) still passes.
- M036/P03 phase-suite (14 sub-gates) still passes.
- M036/P04 phase-suite (13 sub-gates) still passes.
- M036/P05 phase-suite (8 sub-gates) still passes.

## Verification

```bash
bash tools/verify/m036-p07-dispatcher-routes-reference.sh
bash tools/verify/m036-p07-omit-empty-section.sh
bash tools/verify/m036-p07-fixture-task-plans-shape.sh
bash tools/verify/m036-p07-baseline-captured.sh
bash tools/verify/m036-p07-p02-regression-pass.sh
bash tools/verify/m036-p07-p03-regression-pass.sh
bash tools/verify/m036-p07-p04-regression-pass.sh
bash tools/verify/m036-p07-p05-regression-pass.sh
```

## Notes

The most common implementation gotcha in T03 is **inverting the baseline-capture sequencing** — capturing the baseline AFTER editing the four map functions. If you do, the SC-7 byte-equality check in T04 becomes a tautology (compares the post-edit output against itself) and silently false-passes. The `m036-p07-baseline-captured.sh` verifier confirms the file *exists*, but cannot detect when-it-was-captured. The defense-in-depth here is that the M036/P05 plan made the same point and the pattern is M036-canonical — if T03's executor reads upstream summaries they will see the explicit ordering called out.

If `build-context.sh`'s flag surface differs slightly from `--milestone --phase --task --task-plan`, find the equivalent invocation. The contract is: the same flag set must be used in T03 Step 3 (baseline capture) AND in T04's SC-7 harness invocation. Both must see byte-identical recipe parsing, byte-identical state context, byte-identical knowledge filtering — only then does the byte-equality check assert the reference-section drop is the *only* change.

Expected verifier outputs: dispatcher-routes-reference reports `pass=5 fail=0`; omit-empty-section reports `pass=1 fail=0`; fixture-task-plans-shape reports `pass=5 fail=0`; baseline-captured reports `pass=2 fail=0`; each regression verifier reports `pass=N fail=0` (N=14 for P02-selective; N=1 each for P03/P04/P05).
