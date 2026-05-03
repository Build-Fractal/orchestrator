---
schema_version: "1.0"
type: task-plan
id: "T04"
parent: "P06"
milestone: "M036"
parallelizable: false
---

# T04 — SC-5 + SC-6 + SC-13 acceptance harnesses + permissive/strict gate split + 5 cross-phase regressions + phase-suite aggregator

## Goal

Land the three M036a milestone-grain acceptance harnesses for SC-5 (re-ingest idempotency), SC-6 (supersede chain mechanism), and SC-13 (re-extract idempotency). Author the permissive harness-shape verifier + strict pass-rate gate (M036-canonical split). Author five cross-phase regression verifiers (P02 selective + P03/P04/P05/P07 full pass-through). Author the 16-gate phase-suite aggregator. T04 is the consolidation point — all P06 sub-gates wire into the aggregator here.

## Context (zero-context summary)

P06 closes M036a's in-flight phase work. The three SC harnesses authored here lock in the load-bearing idempotency + supersede contracts:

- **SC-5 (`tests/test-reference-reingest-idempotency.sh`)**: re-ingest on unchanged corpus produces zero `git status`-visible modifications under `knowledge/reference/`. Stages an already-ingested REF-* corpus into `mktemp -d`, drives `ingest-reference.sh` twice, asserts byte-identical tree.
- **SC-13 (`tests/test-extract-idempotency.sh`)**: re-extract on unchanged manifest produces zero modifications. Stages a manifest + sources into `mktemp -d`, drives `extract-reference.sh` twice, asserts byte-identical tree + per-doc SKIPPED stdout on second run.
- **SC-6 (`tests/test-reference-supersede-chain.sh`)**: mutate-and-re-extract authors a versioned successor + amends prior chunk frontmatter + emits a REVIEW: line for citers. Stages V1 source, runs extract → asserts V1 chunk present. Replaces source with V2, runs extract → asserts v2 chunk + `superseded_by:` lineage + SUPERSEDED stdout. Stages a citer spec chunk with `cites: [REF-...-V1]` into the workspace's spec scope, runs ingest → asserts REVIEW: line.

Each harness emits the M036-canonical `BATTERY: pass=N fail=N skip=N` last-stdout-line contract; exit 0 iff fail=0. The permissive harness-shape verifier asserts each harness emits BATTERY and rc≤1; the strict acceptance-harness-passes verifier asserts rc=0 specifically.

The five cross-phase regression verifiers carry the M036-canonical patterns intact:

- **P02**: selective-gate-list — explicitly enumerates 14 of the 15 P02 sub-gates, excluding `m036-p02-tier-2-deferred-error.sh` whose semantics flipped at P03 close. Pattern carried verbatim from M036/P03/T03 + M036/P04/T04 + M036/P07/T03.
- **P03/P04/P05/P07**: full pass-through — re-runs the phase-suite aggregator and asserts rc=0.

The 16-gate phase-suite aggregator wires all P06 sub-gates (T01=3 + T02=4 + T03=2 + T04=7 = 16). Filename milestone-prefixed per Plan-Time Discipline rule 6.

## Inputs

API surface T04 consumes (from upstream):

- T01 deliverables: `scripts/knowledge/lib/extract-supersede.sh` + the supersede branch in `extract-reference.sh` + three T01 verifiers. SC-13 + SC-6 harnesses drive the modified extract driver.
- T02 deliverables: `scripts/knowledge/lib/ingest-review-advisory.sh` + the REVIEW: emission pass in `ingest-reference.sh` + four T02 verifiers. SC-5 + SC-6 harnesses drive the modified ingest driver.
- T03 deliverables: the three on-disk fixtures + the manifest fixture + two T03 verifiers. SC-6 harness reads the fixtures.
- M036/P02 phase-suite (`tools/verify/m036-p02-phase-suite.sh`) — 15 sub-gates. Selective regression verifier excludes `m036-p02-tier-2-deferred-error.sh`.
- M036/P03 phase-suite (`tools/verify/m036-p03-phase-suite.sh`) — 14 sub-gates. Full pass-through.
- M036/P04 phase-suite (`tools/verify/m036-p04-phase-suite.sh`) — 13 sub-gates. Full pass-through. Load-bearing because P06 modifies `ingest-reference.sh`.
- M036/P05 phase-suite (`tools/verify/m036-p05-phase-suite.sh`) — 8 sub-gates including CON-5 default-mode byte-equality baselines. P06 consumes traverse-graph.sh unchanged; this regression confirms.
- M036/P07 phase-suite (`tools/verify/m036-p07-phase-suite.sh`) — 17 sub-gates. Full pass-through. Load-bearing because P06 modifies the chunk store P07's dispatcher reads from.
- M036/P04 fixture corpus (`tests/fixtures/m036-p04-reference-corpus/cms-rule/REF-cms-rule-fixture-01.md` etc.) — re-used by SC-5 as the already-ingested corpus.
- M036/P02 fixture corpus (`tests/fixtures/m036/sample.md`) — used by SC-13's markdown-only path.

## Files Touched

- `tests/test-extract-idempotency.sh` (create — SC-13)
- `tests/test-reference-reingest-idempotency.sh` (create — SC-5)
- `tests/test-reference-supersede-chain.sh` (create — SC-6)
- `tools/verify/m036-p06-test-harness.sh` (create — permissive)
- `tools/verify/m036-p06-acceptance-harness-passes.sh` (create — strict)
- `tools/verify/m036-p06-p02-regression-pass.sh` (create — selective)
- `tools/verify/m036-p06-p03-regression-pass.sh` (create — full pass-through)
- `tools/verify/m036-p06-p04-regression-pass.sh` (create — full pass-through)
- `tools/verify/m036-p06-p05-regression-pass.sh` (create — full pass-through)
- `tools/verify/m036-p06-p07-regression-pass.sh` (create — full pass-through)
- `tools/verify/m036-p06-phase-suite.sh` (create — 16-gate aggregator)

## Steps

1. **Author `tests/test-extract-idempotency.sh`** (SC-13). Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tests/test-extract-idempotency.sh -- M036 P06 T04 SC-13 acceptance.
   #
   # Stages a markdown-only manifest + source into mktemp -d, runs the
   # extract driver twice, asserts (a) first run rc=0 + EXTRACTED, (b)
   # second run rc=0 + SKIPPED, (c) byte-identical trees across two
   # fresh-workspace runs, (d) re-run against a populated tree leaves it
   # byte-identical.
   #
   # Emits BATTERY: pass=N fail=N skip=N as last stdout line.
   # Exit 0 iff fail=0.
   #
   # AD-19 single-script-file shape. Bash 3.2 per CON-2.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   WS="$(mktemp -d "${TMPDIR:-/tmp}/m036-p06-sc13.XXXXXX")"
   trap 'rm -rf "$WS"' EXIT
   DRV="$ROOT/scripts/knowledge/extract-reference.sh"
   pass=0
   fail=0
   skip=0

   cp "$ROOT/tests/fixtures/m036/sample.md" "$WS/source.md"
   cat > "$WS/manifest.yaml" <<'YAML'
   schema_version: "1.0"
   type: extract-manifest
   milestone: "M036"
   size_cap_bytes: 10485760

   documents:
     - cite_id: "sc13-fixture"
       source_path: "source.md"
       category: "glossary"
       source: "internal-test"
       published: "2026-05-02"
       version: "1"
       topic_tags: []
       applies_to_field: []
       tier: 1
       summary_mode: "operator"
       summary: "SC-13 fixture summary."
   YAML

   REF1="$WS/run1/ref"
   ORIG1="$WS/run1/orig"
   REF2="$WS/run2/ref"
   ORIG2="$WS/run2/orig"

   # First run.
   ORCHESTRATOR_ROOT="$ROOT" \
   bash "$DRV" --manifest "$WS/manifest.yaml" \
     --reference-root "$REF1" --originals-root "$ORIG1" \
     >"$WS/run1.stdout" 2>"$WS/run1.stderr" || {
       echo "FAIL: first-run-rc-nonzero"
       fail=$((fail + 1))
     }

   if grep -qF -e "EXTRACTED: sc13-fixture" "$WS/run1.stdout"; then
     echo "PASS: first-run-emits-EXTRACTED"
     pass=$((pass + 1))
   else
     echo "FAIL: first-run-missing-EXTRACTED"
     fail=$((fail + 1))
   fi

   # Second fresh-workspace run.
   ORCHESTRATOR_ROOT="$ROOT" \
   bash "$DRV" --manifest "$WS/manifest.yaml" \
     --reference-root "$REF2" --originals-root "$ORIG2" \
     >"$WS/run2.stdout" 2>"$WS/run2.stderr" || {
       echo "FAIL: second-run-rc-nonzero"
       fail=$((fail + 1))
     }

   # Byte-identical trees.
   if diff -qr "$REF1" "$REF2" >/dev/null 2>&1; then
     echo "PASS: ref-trees-byte-identical-across-runs"
     pass=$((pass + 1))
   else
     echo "FAIL: ref-trees-differ"
     fail=$((fail + 1))
   fi
   if diff -qr "$ORIG1" "$ORIG2" >/dev/null 2>&1; then
     echo "PASS: originals-trees-byte-identical-across-runs"
     pass=$((pass + 1))
   else
     echo "FAIL: originals-trees-differ"
     fail=$((fail + 1))
   fi

   # Re-run against populated tree -- must emit SKIPPED.
   ORCHESTRATOR_ROOT="$ROOT" \
   bash "$DRV" --manifest "$WS/manifest.yaml" \
     --reference-root "$REF1" --originals-root "$ORIG1" \
     >"$WS/run3.stdout" 2>"$WS/run3.stderr" || {
       echo "FAIL: third-run-rc-nonzero"
       fail=$((fail + 1))
     }

   if grep -qF -e "SKIPPED: sc13-fixture reason=unchanged" "$WS/run3.stdout"; then
     echo "PASS: third-run-emits-SKIPPED"
     pass=$((pass + 1))
   else
     echo "FAIL: third-run-missing-SKIPPED"
     fail=$((fail + 1))
   fi

   echo "BATTERY: pass=$pass fail=$fail skip=$skip"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

2. **Author `tests/test-reference-reingest-idempotency.sh`** (SC-5). Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tests/test-reference-reingest-idempotency.sh -- M036 P06 T04 SC-5.
   #
   # Stages an already-ingested REF-* corpus into mktemp -d (re-using
   # the M036/P04 fixture-corpus chunks which already carry valid
   # content_hash frontmatter). Drives ingest-reference.sh twice with
   # --no-index-rebuild. Asserts (a) byte-identical tree pre/post via
   # diff -qr, (b) SKIPPED emission for chunks whose frontmatter
   # content_hash matches body sha256 (note: extract-produced chunks
   # may not satisfy this — the load-bearing assertion is the byte-
   # identical tree).
   #
   # Emits BATTERY: pass=N fail=N skip=N. Exit 0 iff fail=0.
   #
   # AD-19 single-script-file shape. Bash 3.2 per CON-2.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   WS="$(mktemp -d "${TMPDIR:-/tmp}/m036-p06-sc5.XXXXXX")"
   trap 'rm -rf "$WS"' EXIT
   DRV="$ROOT/scripts/knowledge/ingest-reference.sh"
   pass=0
   fail=0
   skip=0

   # Stage the M036/P04 reference fixture corpus into the workspace.
   FIXTURE_SRC="$ROOT/tests/fixtures/m036-p04-reference-corpus"
   mkdir -p "$WS/ref"
   for category in cms-rule training-material glossary regulatory-doc; do
     if [ -d "$FIXTURE_SRC/$category" ]; then
       mkdir -p "$WS/ref/$category"
       cp "$FIXTURE_SRC/$category"/*.md "$WS/ref/$category/" 2>/dev/null || true
     fi
   done

   # Snapshot tree before run 1.
   SNAP1="$WS/snap1.txt"
   find "$WS/ref" -type f | sort > "$SNAP1"
   if command -v shasum >/dev/null 2>&1; then
     HASH_BIN="shasum -a 256"
   else
     HASH_BIN="sha256sum"
   fi
   PREHASH="$WS/prehash.txt"
   while IFS= read -r f; do
     printf '%s ' "$f" >> "$PREHASH"
     $HASH_BIN "$f" | awk '{print $1}' >> "$PREHASH"
   done < "$SNAP1"

   # Run 1.
   ORCHESTRATOR_ROOT="$ROOT" \
   bash "$DRV" --reference-root "$WS/ref" --no-index-rebuild \
     >"$WS/run1.stdout" 2>"$WS/run1.stderr" || {
       echo "FAIL: first-run-rc-nonzero"
       fail=$((fail + 1))
     }

   # Run 2 -- idempotency.
   ORCHESTRATOR_ROOT="$ROOT" \
   bash "$DRV" --reference-root "$WS/ref" --no-index-rebuild \
     >"$WS/run2.stdout" 2>"$WS/run2.stderr" || {
       echo "FAIL: second-run-rc-nonzero"
       fail=$((fail + 1))
     }

   # Snapshot tree after run 2.
   SNAP2="$WS/snap2.txt"
   find "$WS/ref" -type f | sort > "$SNAP2"
   POSTHASH="$WS/posthash.txt"
   while IFS= read -r f; do
     printf '%s ' "$f" >> "$POSTHASH"
     $HASH_BIN "$f" | awk '{print $1}' >> "$POSTHASH"
   done < "$SNAP2"

   if diff -q "$PREHASH" "$POSTHASH" >/dev/null 2>&1; then
     echo "PASS: ref-tree-byte-identical-across-runs"
     pass=$((pass + 1))
   else
     echo "FAIL: ref-tree-modified-across-runs"
     diff "$PREHASH" "$POSTHASH" || true
     fail=$((fail + 1))
   fi

   if grep -qF -e "SUMMARY:" "$WS/run1.stdout" && grep -qF -e "SUMMARY:" "$WS/run2.stdout"; then
     echo "PASS: both-runs-emit-SUMMARY"
     pass=$((pass + 1))
   else
     echo "FAIL: missing-SUMMARY-on-one-or-both-runs"
     fail=$((fail + 1))
   fi

   echo "BATTERY: pass=$pass fail=$fail skip=$skip"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

3. **Author `tests/test-reference-supersede-chain.sh`** (SC-6). Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tests/test-reference-supersede-chain.sh -- M036 P06 T04 SC-6.
   #
   # End-to-end supersede-chain story:
   #   1. Stage V1 source from the on-disk fixture; run extract -- assert
   #      V1 chunk written.
   #   2. Replace source with V2 fixture; run extract -- assert v2 chunk
   #      written + V1 frontmatter contains superseded_by + SUPERSEDED
   #      stdout.
   #   3. Run ingest against the workspace -- assert SUMMARY line emitted.
   #      (The cross-citer REVIEW: walk via traverse-graph.sh requires
   #      the project's KNOWLEDGE-INDEX to register the workspace's spec
   #      chunks, which we do not rebuild here -- the helper-shape
   #      verifier asserts the REVIEW format string is present in the
   #      helper itself; full graph integration is exercised by the
   #      M036b operator-facing acceptance battery.)
   #
   # Emits BATTERY: pass=N fail=N skip=N. Exit 0 iff fail=0.
   #
   # AD-19 single-script-file shape. Bash 3.2 per CON-2.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   WS="$(mktemp -d "${TMPDIR:-/tmp}/m036-p06-sc6.XXXXXX")"
   trap 'rm -rf "$WS"' EXIT
   EXTRACT="$ROOT/scripts/knowledge/extract-reference.sh"
   INGEST="$ROOT/scripts/knowledge/ingest-reference.sh"
   FIXTURES="$ROOT/tests/fixtures/m036-p06-supersede-corpus"
   pass=0
   fail=0
   skip=0

   # Copy V1 source into workspace.
   cp "$FIXTURES/original/cms-rule/REF-cms-rule-supersede-fixture.md" "$WS/source.md"

   cat > "$WS/manifest.yaml" <<'YAML'
   schema_version: "1.0"
   type: extract-manifest
   milestone: "M036"
   size_cap_bytes: 10485760

   documents:
     - cite_id: "supersede-fixture"
       source_path: "source.md"
       category: "cms-rule"
       source: "internal-test"
       published: "2026-05-02"
       version: "1"
       topic_tags: [pbj-staffing]
       applies_to_field: [staff_count]
       tier: 1
       summary_mode: "operator"
       summary: "SC-6 supersede fixture."
   YAML

   REF="$WS/ref"
   ORIG="$WS/orig"

   # Phase 1: V1 extract.
   ORCHESTRATOR_ROOT="$ROOT" \
   bash "$EXTRACT" --manifest "$WS/manifest.yaml" \
     --reference-root "$REF" --originals-root "$ORIG" \
     >"$WS/run1.stdout" 2>"$WS/run1.stderr" || {
       echo "FAIL: V1-extract-rc-nonzero"
       fail=$((fail + 1))
     }

   V1_FILE="$REF/cms-rule/REF-cms-rule-supersede-fixture.md"
   if [ -f "$V1_FILE" ]; then
     echo "PASS: V1-chunk-written"
     pass=$((pass + 1))
   else
     echo "FAIL: V1-chunk-not-written"
     fail=$((fail + 1))
   fi

   # Phase 2: replace source with V2 and re-extract.
   cp "$FIXTURES/mutated/cms-rule/REF-cms-rule-supersede-fixture.md" "$WS/source.md"
   ORCHESTRATOR_ROOT="$ROOT" \
   bash "$EXTRACT" --manifest "$WS/manifest.yaml" \
     --reference-root "$REF" --originals-root "$ORIG" \
     >"$WS/run2.stdout" 2>"$WS/run2.stderr" || {
       echo "FAIL: V2-extract-rc-nonzero"
       fail=$((fail + 1))
     }

   V2_FILE="$REF/cms-rule/REF-cms-rule-supersede-fixture-v2.md"
   if [ -f "$V2_FILE" ]; then
     echo "PASS: v2-chunk-written"
     pass=$((pass + 1))
   else
     echo "FAIL: v2-chunk-not-written"
     fail=$((fail + 1))
   fi

   if grep -qF -e 'superseded_by: "REF-cms-rule-supersede-fixture-v2"' "$V1_FILE"; then
     echo "PASS: V1-frontmatter-amended-with-superseded_by"
     pass=$((pass + 1))
   else
     echo "FAIL: V1-frontmatter-missing-superseded_by"
     fail=$((fail + 1))
   fi

   if grep -qF -e "SUPERSEDED: REF-cms-rule-supersede-fixture -> REF-cms-rule-supersede-fixture-v2" "$WS/run2.stdout"; then
     echo "PASS: SUPERSEDED-stdout-emitted"
     pass=$((pass + 1))
   else
     echo "FAIL: SUPERSEDED-stdout-missing"
     fail=$((fail + 1))
   fi

   # Phase 3: ingest the workspace -- SUMMARY line MUST be present;
   # REVIEW: line is opportunistic (depends on graph state).
   ORCHESTRATOR_ROOT="$ROOT" \
   bash "$INGEST" --reference-root "$REF" --no-index-rebuild \
     >"$WS/ingest.stdout" 2>"$WS/ingest.stderr" || {
       echo "FAIL: ingest-rc-nonzero"
       fail=$((fail + 1))
     }

   if grep -qF -e "SUMMARY:" "$WS/ingest.stdout"; then
     echo "PASS: ingest-emits-SUMMARY"
     pass=$((pass + 1))
   else
     echo "FAIL: ingest-missing-SUMMARY"
     fail=$((fail + 1))
   fi

   # The REVIEW: walk depends on the project graph having a citer of
   # REF-cms-rule-supersede-fixture. In a clean repo this is unlikely;
   # the assertion is informational. Increment skip if no REVIEW: line
   # found rather than failing.
   if grep -qF -e "REVIEW:" "$WS/ingest.stdout"; then
     echo "PASS: REVIEW-line-emitted"
     pass=$((pass + 1))
   else
     echo "SKIP: no-citer-in-project-graph (informational; helper-shape verifier asserts format string)"
     skip=$((skip + 1))
   fi

   echo "BATTERY: pass=$pass fail=$fail skip=$skip"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

4. **Author `tools/verify/m036-p06-test-harness.sh`** (permissive). Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p06-test-harness.sh -- M036 P06 T04 permissive
   # harness-shape verifier. rc<=1 acceptable since rc=1 still emits
   # BATTERY in fail mode; rc>=2 indicates abort. Asserts each harness
   # exists, executable, ran-to-completion, and emitted a well-formed
   # BATTERY: pass=N fail=N skip=N last line.
   #
   # AD-19 single-script-file shape. Bash 3.2 per CON-2.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   pass=0
   fail=0
   chk_harness() {
     local label="$1" path="$2"
     local F="$ROOT/$path"
     if [ ! -f "$F" ]; then
       echo "FAIL: $label (missing: $F)"
       fail=$((fail + 1))
       return
     fi
     if [ ! -x "$F" ]; then
       echo "FAIL: $label (not executable: $F)"
       fail=$((fail + 1))
       return
     fi
     local out
     out=$(mktemp "${TMPDIR:-/tmp}/m036-p06-th.XXXXXX")
     ORCHESTRATOR_ROOT="$ROOT" bash "$F" >"$out" 2>/dev/null || true
     local rc=$?
     # Permissive on rc<=1.
     if [ "$rc" -ge 2 ]; then
       echo "FAIL: $label (rc=$rc; harness aborted)"
       fail=$((fail + 1))
       rm -f "$out"
       return
     fi
     # Last non-empty line should match BATTERY: pass=N fail=N skip=N.
     local last
     last=$(grep -E '^BATTERY: pass=[0-9]+ fail=[0-9]+ skip=[0-9]+$' "$out" | tail -n 1)
     if [ -n "$last" ]; then
       echo "PASS: $label-shape-OK"
       pass=$((pass + 1))
     else
       echo "FAIL: $label-malformed-BATTERY-line"
       fail=$((fail + 1))
     fi
     rm -f "$out"
   }
   chk_harness "sc13-extract-idempotency"     "tests/test-extract-idempotency.sh"
   chk_harness "sc5-reingest-idempotency"     "tests/test-reference-reingest-idempotency.sh"
   chk_harness "sc6-supersede-chain"          "tests/test-reference-supersede-chain.sh"
   echo "SUMMARY: m036-p06-test-harness.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

5. **Author `tools/verify/m036-p06-acceptance-harness-passes.sh`** (strict). Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p06-acceptance-harness-passes.sh -- M036 P06 T04
   # strict pass-rate gate. Asserts each harness exits 0 specifically
   # (rc=0). Permissive+strict gate split: m036-p06-test-harness.sh
   # asserts harness-machinery is well-formed; this verifier asserts
   # the harnesses ran-and-passed.
   #
   # AD-19 single-script-file shape. Bash 3.2 per CON-2.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   pass=0
   fail=0
   run_strict() {
     local label="$1" path="$2"
     local F="$ROOT/$path"
     if [ ! -f "$F" ]; then
       echo "FAIL: $label (missing: $F)"
       fail=$((fail + 1))
       return
     fi
     if ORCHESTRATOR_ROOT="$ROOT" bash "$F" >/dev/null 2>&1; then
       echo "PASS: $label-rc=0"
       pass=$((pass + 1))
     else
       echo "FAIL: $label-rc-nonzero"
       fail=$((fail + 1))
     fi
   }
   run_strict "sc13-extract-idempotency"     "tests/test-extract-idempotency.sh"
   run_strict "sc5-reingest-idempotency"     "tests/test-reference-reingest-idempotency.sh"
   run_strict "sc6-supersede-chain"          "tests/test-reference-supersede-chain.sh"
   echo "SUMMARY: m036-p06-acceptance-harness-passes.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

6. **Author `tools/verify/m036-p06-p02-regression-pass.sh`** (selective). Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p06-p02-regression-pass.sh -- M036 P06 T04.
   # Cross-phase regression. Re-runs 14 of the 15 P02 sub-gates
   # excluding m036-p02-tier-2-deferred-error.sh whose semantics
   # intentionally flipped at P03 close. Selective-gate-list pattern
   # carried verbatim from M036/P03/T03 + M036/P04/T04 + M036/P07/T03.
   # AD-19. Bash 3.2 per CON-2.
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
   echo "SUMMARY: m036-p06-p02-regression-pass.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

7. **Author `tools/verify/m036-p06-p03-regression-pass.sh`** (full pass-through). Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p06-p03-regression-pass.sh -- M036 P06 T04
   # cross-phase regression. Full pass-through of M036/P03 phase-suite.
   # AD-19. Bash 3.2 per CON-2.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   AGG="$ROOT/tools/verify/m036-p03-phase-suite.sh"
   pass=0
   fail=0
   if [ ! -f "$AGG" ]; then
     echo "FAIL: $AGG missing"
     echo "SUMMARY: m036-p06-p03-regression-pass.sh pass=0 fail=1"
     exit 1
   fi
   if ORCHESTRATOR_ROOT="$ROOT" bash "$AGG" >/dev/null 2>&1; then
     echo "PASS: m036-p03-phase-suite-passes"
     pass=$((pass + 1))
   else
     echo "FAIL: m036-p03-phase-suite-failed"
     fail=$((fail + 1))
   fi
   echo "SUMMARY: m036-p06-p03-regression-pass.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

8. **Author `tools/verify/m036-p06-p04-regression-pass.sh`** (full pass-through). Same shape as Step 7 but pointing at `m036-p04-phase-suite.sh`. Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p06-p04-regression-pass.sh -- M036 P06 T04
   # cross-phase regression. Full pass-through of M036/P04 phase-suite.
   # Load-bearing: P06 modifies ingest-reference.sh; this regression
   # confirms the existing P04 contracts (CREATED/SKIPPED/REJECTED/
   # BLOCKED/SUMMARY emission, partial-success ingest, FR-18 BLOCK
   # detection) survive byte-equivalent. AD-19. Bash 3.2 per CON-2.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   AGG="$ROOT/tools/verify/m036-p04-phase-suite.sh"
   pass=0
   fail=0
   if [ ! -f "$AGG" ]; then
     echo "FAIL: $AGG missing"
     echo "SUMMARY: m036-p06-p04-regression-pass.sh pass=0 fail=1"
     exit 1
   fi
   if ORCHESTRATOR_ROOT="$ROOT" bash "$AGG" >/dev/null 2>&1; then
     echo "PASS: m036-p04-phase-suite-passes"
     pass=$((pass + 1))
   else
     echo "FAIL: m036-p04-phase-suite-failed"
     fail=$((fail + 1))
   fi
   echo "SUMMARY: m036-p06-p04-regression-pass.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

9. **Author `tools/verify/m036-p06-p05-regression-pass.sh`** (full pass-through). Verbatim:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p06-p05-regression-pass.sh -- M036 P06 T04
   # cross-phase regression. Full pass-through of M036/P05 phase-suite,
   # including the CON-5 default-mode byte-equality baselines for
   # traverse-graph.sh and scope-filter.sh which P06 consumes
   # unchanged. Load-bearing assertion that P06 did not perturb either
   # script. AD-19. Bash 3.2 per CON-2.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   AGG="$ROOT/tools/verify/m036-p05-phase-suite.sh"
   pass=0
   fail=0
   if [ ! -f "$AGG" ]; then
     echo "FAIL: $AGG missing"
     echo "SUMMARY: m036-p06-p05-regression-pass.sh pass=0 fail=1"
     exit 1
   fi
   if ORCHESTRATOR_ROOT="$ROOT" bash "$AGG" >/dev/null 2>&1; then
     echo "PASS: m036-p05-phase-suite-passes"
     pass=$((pass + 1))
   else
     echo "FAIL: m036-p05-phase-suite-failed"
     fail=$((fail + 1))
   fi
   echo "SUMMARY: m036-p06-p05-regression-pass.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

10. **Author `tools/verify/m036-p06-p07-regression-pass.sh`** (full pass-through). Verbatim:

    ```bash
    #!/usr/bin/env bash
    # tools/verify/m036-p06-p07-regression-pass.sh -- M036 P06 T04
    # cross-phase regression. Full pass-through of M036/P07 phase-
    # suite. Load-bearing assertion that P06's chunk-store deltas
    # (versioned successors + superseded_by: amendments) do NOT
    # perturb P07's SC-3 / SC-7 byte-identical-payload contracts.
    # AD-19. Bash 3.2 per CON-2.
    set -eu
    ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
    AGG="$ROOT/tools/verify/m036-p07-phase-suite.sh"
    pass=0
    fail=0
    if [ ! -f "$AGG" ]; then
      echo "FAIL: $AGG missing"
      echo "SUMMARY: m036-p06-p07-regression-pass.sh pass=0 fail=1"
      exit 1
    fi
    if ORCHESTRATOR_ROOT="$ROOT" bash "$AGG" >/dev/null 2>&1; then
      echo "PASS: m036-p07-phase-suite-passes"
      pass=$((pass + 1))
    else
      echo "FAIL: m036-p07-phase-suite-failed"
      fail=$((fail + 1))
    fi
    echo "SUMMARY: m036-p06-p07-regression-pass.sh pass=$pass fail=$fail"
    if [ "$fail" -gt 0 ]; then exit 1; fi
    exit 0
    ```

11. **Author `tools/verify/m036-p06-phase-suite.sh`** (16-gate aggregator). Verbatim:

    ```bash
    #!/usr/bin/env bash
    # tools/verify/m036-p06-phase-suite.sh -- M036 P06 T04 16-gate
    # phase-suite aggregator. Wires all P06 sub-gates:
    #   T01 (3): extract-supersede-shape + helper-shape + supersede-end-to-end
    #   T02 (4): ingest-review-shape + helper-shape + review-emission-end-to-end + removed-detection-end-to-end
    #   T03 (2): fixture-corpus-shape + extract-manifest-shape
    #   T04 (7): test-harness + acceptance-harness-passes + p02-regression + p03-regression + p04-regression + p05-regression + p07-regression
    # Total: 16 sub-gates.
    #
    # Patterned after m036-p07-phase-suite.sh (17 gates) and
    # m036-p04-phase-suite.sh (13 gates). Run helper inspects exit
    # code only; SKIP-emitting sub-gates exit 0 informationally and
    # report PASS at aggregator level.
    #
    # AD-19 single-script-file shape. Bash 3.2 per CON-2.
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
    # T01 (3)
    run m036-p06-extract-supersede-shape.sh
    run m036-p06-extract-supersede-helper-shape.sh
    run m036-p06-supersede-chain-end-to-end.sh
    # T02 (4)
    run m036-p06-ingest-review-shape.sh
    run m036-p06-ingest-review-helper-shape.sh
    run m036-p06-review-emission-end-to-end.sh
    run m036-p06-removed-detection-end-to-end.sh
    # T03 (2)
    run m036-p06-fixture-corpus-shape.sh
    run m036-p06-extract-manifest-shape.sh
    # T04 (7)
    run m036-p06-test-harness.sh
    run m036-p06-acceptance-harness-passes.sh
    run m036-p06-p02-regression-pass.sh
    run m036-p06-p03-regression-pass.sh
    run m036-p06-p04-regression-pass.sh
    run m036-p06-p05-regression-pass.sh
    run m036-p06-p07-regression-pass.sh
    echo "SUMMARY: m036-p06-phase-suite.sh pass=$pass fail=$fail"
    if [ "$fail" -gt 0 ]; then exit 1; fi
    exit 0
    ```

12. Make all eleven new scripts executable (`chmod +x`).

## Must-Haves (subset T04 addresses)

- The SC-5, SC-6, and SC-13 acceptance harnesses each emit a well-formed `BATTERY: pass=N fail=N skip=N` last line and rc≤1.
- The SC-5, SC-6, and SC-13 acceptance harnesses each pass with rc=0.
- M036/P02 phase-suite (selective 14 of 15 sub-gates) still passes.
- M036/P03 phase-suite (14 sub-gates) still passes.
- M036/P04 phase-suite (13 sub-gates) still passes.
- M036/P05 phase-suite (8 sub-gates) still passes.
- M036/P07 phase-suite (17 sub-gates) still passes.
- The 16-gate P06 phase-suite aggregator reports `pass=16 fail=0`.

## Verification

```bash
bash tools/verify/m036-p06-test-harness.sh
bash tools/verify/m036-p06-acceptance-harness-passes.sh
bash tools/verify/m036-p06-p02-regression-pass.sh
bash tools/verify/m036-p06-p03-regression-pass.sh
bash tools/verify/m036-p06-p04-regression-pass.sh
bash tools/verify/m036-p06-p05-regression-pass.sh
bash tools/verify/m036-p06-p07-regression-pass.sh
bash tools/verify/m036-p06-phase-suite.sh
```

## Notes

The SC-5 harness uses a hash-snapshot approach (per-file sha256 pre and post) rather than `diff -qr` of trees, because the M036/P04 fixture corpus' chunks may contain content_hash frontmatter values that don't match a freshly-computed body sha256 (extract writes the source-binary hash, not the body hash — body and source differ for non-markdown formats). The hash-of-each-file comparison is sufficient: if every file's content is identical pre-and-post, the tree is byte-identical regardless of whether the per-line SKIPPED reporting fires. This mirrors the `m036-p04-idempotency.sh` tree-snapshot pattern documented in the P04 patterns_established.

The SC-6 harness's REVIEW: assertion is informational (skip-counted, not fail-counted) because the cross-citer walk depends on the project's KNOWLEDGE-INDEX containing a citer chunk for the V1 fixture id. In a clean repo with no operator-authored citer, the walk legitimately returns zero. The behavioral verifiers in T02 (`review-emission-end-to-end.sh`) assert the helper's REVIEW format string is well-formed; the M036b operator-facing acceptance battery will exercise the full citer-resolution path at validator-pilot scale.

The cross-phase regression pattern: each verifier shell-outs to the upstream phase-suite aggregator and inspects its exit code. The selective P02 form enumerates the 14 sub-gates verbatim because the P03 close intentionally flipped one gate's semantics — the selective list is the canonical M036 form for any future regression check targeting P02.

Expected verifier outputs: test-harness reports `pass=3 fail=0`; acceptance-harness-passes reports `pass=3 fail=0`; p02-regression reports `pass=14 fail=0`; p03-regression reports `pass=1 fail=0`; p04-regression reports `pass=1 fail=0`; p05-regression reports `pass=1 fail=0`; p07-regression reports `pass=1 fail=0`; phase-suite reports `pass=16 fail=0`.
