---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P00"
milestone: "M036"
name: "Scope-tag namespace extension + chunk-frontmatter validator + phase-suite gate"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 completed: `references/reference-taxonomy.md`, `references/reference-frontmatter-contract.md`, `references/reference-source-types.yaml` exist; their three shape verifiers exist under `tools/verify/`.
- T02 completed: `references/reference-edge-types.md`, `scripts/dispatch/adapters/format/registry.tsv` exist; their two shape verifiers exist under `tools/verify/`.
- `references/file-formats.md` exists with a `### Scope Tags` table at line ~649 (current state: three rows — `project`, `milestone:M001`, `phase:M001/P02`).
- `references/spec-management.md` exists (currently has no scope-tag content; receives a forward cross-reference paragraph).
- `tools/verify/` exists with the five T01+T02 verifier scripts.

## Description

Land the three remaining P00 deliverables and prove the foundation gates the demo sentence promises:

1. **Additive scope-tag namespace extension** — append a fourth row `[source:<cite_id>]` to `references/file-formats.md` `### Scope Tags` table (the actual SSOT) and add a one-paragraph cross-reference in `references/spec-management.md` (the roadmap's literal target). Verifiers: `p00-scope-tag-extension.sh` + `p00-spec-management-crossref.sh`.

2. **Chunk-frontmatter validator library** — `tools/verify/lib/p00-validate-chunk-frontmatter.sh` reads stdin (a YAML frontmatter block) and rejects any chunk whose `category` is outside the four-category taxonomy or whose `tier` (when present) is outside `{0, 1, 2}`. This is the harness that proves the demo sentence's "fail validation if they declare a category outside the taxonomy or a tier outside {0, 1, 2}" property — without it, the SSOT files are documentation alone. Validator: `p00-taxonomy-rejects-unknown.sh` (negative test) drives the library against three synthetic stdin fixtures.

3. **Phase-suite aggregator** — `tools/verify/m036-p00-phase-suite.sh` invokes all eight P00 gates (three from T01 + two from T02 + three new in T03) in order, exits 0 iff every sub-gate passes, and emits the `SUMMARY: m036-p00-phase-suite.sh pass=N fail=M` line. This is the must-have aggregator that `scripts/verify/check-must-haves.sh` and `auto-loop.sh --step=V` resolve against.

T03 is the close-out task. After T03 succeeds, P00 transitions from `executing` to `phase-complete`.

## Steps

1. **Append the `[source:<cite_id>]` row to `references/file-formats.md` `### Scope Tags` table.** Locate the table at line ~649 (search for `### Scope Tags`). The table is a 3-row markdown table:

   ```markdown
   | Scope | Applies to |
   |-------|------------|
   | `project` | Entire project, all milestones |
   | `milestone:M001` | Specific milestone |
   | `phase:M001/P02` | Specific phase |
   ```

   Append a fourth row. The exact insertion (immediately after the `phase:M001/P02` row, preserving the trailing pipe alignment):

   ```markdown
   | `source:<cite_id>` | Specific reference-corpus source (M036 — see `references/reference-frontmatter-contract.md`) |
   ```

   Do NOT modify the existing three rows (CON-1: existing namespaces preserved verbatim).

2. **Append a cross-reference paragraph to `references/spec-management.md`.** The spec-management.md file currently has no scope-tag content; append a new section (or insert alongside an existing thematically appropriate section) containing this content:

   ```markdown
   ## Scope-Tag Grammar Cross-Reference

   The orchestrator's scope-tag grammar (`[project]`, `[milestone:M###]`,
   `[phase:M###/P##]`, `[source:<cite_id>]`) is declared in
   `references/file-formats.md` `### Scope Tags`. Spec-management
   workflows consume scope tags via `scripts/dispatch/scope-filter.sh`.

   The `[source:<cite_id>]` namespace is M036-introduced
   (reference-corpus ingest, spec
   `specs/033-reference-corpus-ingest/spec.md`). Operator-asserted —
   the orchestrator does not factually verify that a chunk tagged
   `[source:cms-pbj-2024-q3]` actually derives from that source (see
   spec #Q-7).
   ```

   The shape verifier (step 4) greps for the `[source:` token and the `file-formats.md` filename in this file.

3. **Author `tools/verify/lib/p00-validate-chunk-frontmatter.sh`.** This is a library helper invoked from T03's negative-test verifier (and reused by P04's ingest classifier in a future phase). Bash 3.2-compatible. Behavior:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/lib/p00-validate-chunk-frontmatter.sh — M036 P00 T03
   # chunk-frontmatter validator. Reads a YAML frontmatter block from
   # stdin (or a file path argument) and rejects entries whose category
   # is outside the M036 taxonomy or whose tier is outside {0, 1, 2}.
   #
   # Authoritative SSOT: references/reference-taxonomy.md (categories),
   #                    references/reference-source-types.yaml (tier enum).
   # The taxonomy values are duplicated here as a hardcoded list ONLY
   # for the validator's tight loop — adding a category requires updating
   # both this file and the SSOT in lockstep, gated by the M036 D-row
   # convention. The shape verifier (p00-taxonomy-shape.sh) catches the
   # SSOT side; this validator catches the validator side.
   #
   # Usage:
   #   bash tools/verify/lib/p00-validate-chunk-frontmatter.sh < frontmatter.yaml
   #   bash tools/verify/lib/p00-validate-chunk-frontmatter.sh path/to/frontmatter.yaml
   #
   # Exit: 0 if valid, 1 if any rejection. Emits ACCEPT: / REJECT: lines
   # to stdout. Errors to stderr.
   set -eu
   if [ $# -ge 1 ] && [ -f "$1" ]; then
     INPUT="$1"
     CATEGORY=$(grep -E '^category:' "$INPUT" | head -n 1 | sed -E 's/^category:[[:space:]]*//' | sed -E 's/[[:space:]]*$//')
     TIER=$(grep -E '^tier:' "$INPUT" | head -n 1 | sed -E 's/^tier:[[:space:]]*//' | sed -E 's/[[:space:]]*$//')
   else
     # Read stdin into a temp file (avoid $() with pipe).
     TMP=$(mktemp)
     cat > "$TMP"
     CATEGORY=$(grep -E '^category:' "$TMP" | head -n 1 | sed -E 's/^category:[[:space:]]*//' | sed -E 's/[[:space:]]*$//')
     TIER=$(grep -E '^tier:' "$TMP" | head -n 1 | sed -E 's/^tier:[[:space:]]*//' | sed -E 's/[[:space:]]*$//')
     rm -f "$TMP"
   fi
   reject=0
   # Category check — must be one of the four taxonomy values when present.
   if [ -n "${CATEGORY:-}" ]; then
     case "$CATEGORY" in
       cms-rule|training-material|glossary|regulatory-doc)
         echo "ACCEPT: category=$CATEGORY"
         ;;
       *)
         echo "REJECT: category=$CATEGORY (not in taxonomy: cms-rule|training-material|glossary|regulatory-doc)"
         reject=1
         ;;
     esac
   fi
   # Tier check — must be 0, 1, or 2 when present.
   if [ -n "${TIER:-}" ]; then
     case "$TIER" in
       0|1|2)
         echo "ACCEPT: tier=$TIER"
         ;;
       *)
         echo "REJECT: tier=$TIER (not in {0, 1, 2})"
         reject=1
         ;;
     esac
   fi
   if [ "$reject" -gt 0 ]; then exit 1; fi
   exit 0
   ```

   The validator reads at most one `category:` and one `tier:` line; downstream phases may extend it to validate the full FR-2 field set. T03 ships only the taxonomy + tier check — the load-bearing pair the demo sentence calls out.

   Note on cat-with-pipe avoidance: `$(grep ... | head ... | sed ...)` chains a substitution containing pipes. Per AD-19, `$()` containing pipes triggers the harness shape-guard. The validator file is invoked via `bash tools/verify/lib/...sh` (single-script-file shape), so the harness inspects only the *invocation*, not the script's internals — substitution-with-pipes inside the script body does not trigger the heuristic. Confirmed by classifier trace: the literal command `bash tools/verify/lib/p00-validate-chunk-frontmatter.sh` classifies as `single-script-file` (verdict from `scripts/verify/lib/shape-classifier.sh::classify_command` — script-file invocation form, no inline compound shell, no `$()` pipe in the invocation itself).

4. **Author `tools/verify/p00-scope-tag-extension.sh`.** Shape-checks the `references/file-formats.md` modification:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/p00-scope-tag-extension.sh — M036 P00 T03 gate for
   # the [source:<cite_id>] namespace addition to file-formats.md
   # ### Scope Tags table.
   set -eu
   FILE="${1:-references/file-formats.md}"
   pass=0; fail=0
   if [ ! -f "$FILE" ]; then
     echo "FAIL: $FILE missing"
     echo "SUMMARY: p00-scope-tag-extension.sh pass=0 fail=1"
     exit 1
   fi
   for token in '### Scope Tags' '`source:<cite_id>`' 'reference-frontmatter-contract'; do
     if grep -qF "$token" "$FILE"; then
       pass=$((pass + 1))
     else
       fail=$((fail + 1))
       echo "FAIL: $FILE missing token: $token"
     fi
   done
   # Pre-existing namespaces preserved (CON-1).
   for token in '`project`' '`milestone:M001`' '`phase:M001/P02`'; do
     if grep -qF "$token" "$FILE"; then
       pass=$((pass + 1))
     else
       fail=$((fail + 1))
       echo "FAIL: $FILE missing pre-existing token: $token"
     fi
   done
   echo "SUMMARY: p00-scope-tag-extension.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

5. **Author `tools/verify/p00-spec-management-crossref.sh`.** Shape-checks the spec-management.md modification:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/p00-spec-management-crossref.sh — M036 P00 T03 gate
   # for the cross-reference paragraph added to spec-management.md.
   set -eu
   FILE="${1:-references/spec-management.md}"
   pass=0; fail=0
   if [ ! -f "$FILE" ]; then
     echo "FAIL: $FILE missing"
     echo "SUMMARY: p00-spec-management-crossref.sh pass=0 fail=1"
     exit 1
   fi
   for token in 'file-formats.md' 'source:<cite_id>' 'M036'; do
     if grep -qF "$token" "$FILE"; then
       pass=$((pass + 1))
     else
       fail=$((fail + 1))
       echo "FAIL: $FILE missing token: $token"
     fi
   done
   echo "SUMMARY: p00-spec-management-crossref.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

6. **Author `tools/verify/p00-taxonomy-rejects-unknown.sh`.** Negative-test driver. Behavior:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/p00-taxonomy-rejects-unknown.sh — M036 P00 T03 negative
   # test for the chunk-frontmatter validator. Asserts the validator
   # rejects out-of-taxonomy categories AND out-of-{0,1,2} tiers, and
   # accepts in-policy combinations.
   set -eu
   VALIDATOR="${1:-tools/verify/lib/p00-validate-chunk-frontmatter.sh}"
   pass=0; fail=0
   if [ ! -f "$VALIDATOR" ]; then
     echo "FAIL: $VALIDATOR missing"
     echo "SUMMARY: p00-taxonomy-rejects-unknown.sh pass=0 fail=1"
     exit 1
   fi
   TMPDIR=$(mktemp -d)
   trap 'rm -rf "$TMPDIR"' EXIT
   # Fixture A — out-of-taxonomy category, must reject (validator exits 1).
   cat > "$TMPDIR/a.yaml" <<'EOF'
   category: blog-post
   tier: 1
   EOF
   if bash "$VALIDATOR" "$TMPDIR/a.yaml" >/dev/null 2>&1; then
     fail=$((fail + 1))
     echo "FAIL: validator accepted out-of-taxonomy category=blog-post (expected reject)"
   else
     pass=$((pass + 1))
   fi
   # Fixture B — out-of-enum tier, must reject (validator exits 1).
   cat > "$TMPDIR/b.yaml" <<'EOF'
   category: cms-rule
   tier: 5
   EOF
   if bash "$VALIDATOR" "$TMPDIR/b.yaml" >/dev/null 2>&1; then
     fail=$((fail + 1))
     echo "FAIL: validator accepted out-of-enum tier=5 (expected reject)"
   else
     pass=$((pass + 1))
   fi
   # Fixture C — in-policy, must accept (validator exits 0).
   cat > "$TMPDIR/c.yaml" <<'EOF'
   category: cms-rule
   tier: 2
   EOF
   if bash "$VALIDATOR" "$TMPDIR/c.yaml" >/dev/null 2>&1; then
     pass=$((pass + 1))
   else
     fail=$((fail + 1))
     echo "FAIL: validator rejected in-policy category=cms-rule tier=2 (expected accept)"
   fi
   echo "SUMMARY: p00-taxonomy-rejects-unknown.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

   Three fixtures, three assertions: reject `blog-post` category, reject `tier: 5`, accept `cms-rule + tier: 2`. The harness writes fixture YAML files to a temp directory and invokes the validator with each as a path argument (avoiding heredoc-feeding-pipe shapes that AD-19 forbids).

7. **Author `tools/verify/m036-p00-phase-suite.sh`.** Aggregator gate. Behavior:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m036-p00-phase-suite.sh — M036 P00 phase-suite aggregator.
   # Invokes the eight P00 sub-gates in order. Exits 0 iff every sub-gate
   # passes. Single-script-file shape per AD-19.
   set -eu
   ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
   pass=0; fail=0
   run() {
     local gate="$1"
     if bash "$ROOT/tools/verify/$gate" >/dev/null 2>&1; then
       echo "PASS: $gate"
       pass=$((pass + 1))
     else
       echo "FAIL: $gate"
       fail=$((fail + 1))
     fi
   }
   run p00-taxonomy-shape.sh
   run p00-frontmatter-contract-shape.sh
   run p00-source-types-shape.sh
   run p00-edge-types-shape.sh
   run p00-adapter-registry-shape.sh
   run p00-scope-tag-extension.sh
   run p00-spec-management-crossref.sh
   run p00-taxonomy-rejects-unknown.sh
   echo "SUMMARY: m036-p00-phase-suite.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

   Eight sub-gates total: three from T01, two from T02, three from T03. The `run` helper is a single function invocation per gate — no compound chains. Output is one `PASS: <gate>` or `FAIL: <gate>` line per sub-gate plus the aggregator `SUMMARY:` line.

8. **Self-check.** Run the full phase suite from repo root:

   ```bash
   bash tools/verify/m036-p00-phase-suite.sh
   ```

   Exits 0 with `SUMMARY: m036-p00-phase-suite.sh pass=8 fail=0`.

## Must-Haves

This task satisfies these phase truths:

- "`references/file-formats.md` `### Scope Tags` table contains a fourth row `[source:<cite_id>]` with pre-existing rows preserved" — T03 modifies; `p00-scope-tag-extension.sh` gates.
- "`references/spec-management.md` contains a cross-reference paragraph pointing to file-formats.md and naming `[source:<cite_id>]`" — T03 modifies; `p00-spec-management-crossref.sh` gates.
- "Taxonomy and tier-policy validators reject out-of-taxonomy categories and out-of-{0,1,2} tiers" — T03 authors `tools/verify/lib/p00-validate-chunk-frontmatter.sh` + `p00-taxonomy-rejects-unknown.sh`; the negative-test driver gates.
- "`bash tools/verify/m036-p00-phase-suite.sh` invokes all eight P00 gates in order, exits 0 iff every sub-gate passes" — T03 authors the aggregator.

## Verification

```bash
bash tools/verify/p00-scope-tag-extension.sh
bash tools/verify/p00-spec-management-crossref.sh
bash tools/verify/p00-taxonomy-rejects-unknown.sh
bash tools/verify/m036-p00-phase-suite.sh
```

Each verifier uses single-script-file shape per AD-19. The phase-suite aggregator is the load-bearing close-out gate; it must exit 0 with `SUMMARY: m036-p00-phase-suite.sh pass=8 fail=0`.

## Inputs

### From Previous Tasks

- T01 outputs (`references/reference-taxonomy.md`, `references/reference-frontmatter-contract.md`, `references/reference-source-types.yaml`) and verifiers (`p00-taxonomy-shape.sh`, `p00-frontmatter-contract-shape.sh`, `p00-source-types-shape.sh`). Key API: each verifier exits 0 with `SUMMARY: <name> pass=N fail=0` against the artifact at its default path. Key types: shell exit codes (0/1) and the `SUMMARY:` stdout line.
- T02 outputs (`references/reference-edge-types.md`, `scripts/dispatch/adapters/format/registry.tsv`) and verifiers (`p00-edge-types-shape.sh`, `p00-adapter-registry-shape.sh`). Same API contract.

### From Disk (Pre-existing)

- `references/file-formats.md` — line 649 declares the `### Scope Tags` table. T03 appends a fourth row. The pre-existing three rows (`project`, `milestone:M001`, `phase:M001/P02`) are preserved verbatim.
- `references/spec-management.md` — currently has no scope-tag content. T03 appends a cross-reference paragraph.
- `specs/033-reference-corpus-ingest/spec.md` — FR-1 (taxonomy enum), FR-6 (`[source:...]` namespace), #Q-7 (operator-asserted note for the cross-reference paragraph). Authoritative content source.
- `scripts/verify/lib/shape-classifier.sh` — used at plan-authoring time to classify the validator-library invocation form; not invoked at execution time.

## Constraints

- **CON-1 (no-regression)**: pre-existing scope-tag namespaces (`project`, `milestone:M001`, `phase:M001/P02`) are preserved verbatim in `file-formats.md`. The `p00-scope-tag-extension.sh` verifier asserts both the new row's presence AND the pre-existing rows' presence — a regression that drops a pre-existing row would fail the verifier.
- **CON-5 (no-spec-chunk-schema-change)**: T03 adds the `[source:<cite_id>]` namespace additively. Existing spec / memory / reference chunk frontmatter remains valid without modification.
- **Bash 3.2 compatibility**: same as T01/T02 — no `mapfile`, `declare -A`, process substitution, no `$()` containing pipes. Per the AD-19 note in step 3: substitutions-with-pipes *inside* a script body do not trigger the harness heuristic because the harness inspects only the invocation form. The validator script's internal `grep | head | sed` pipeline is fine; the *Verification* invocations in this plan use single-script-file shape.
- **Single-script-file Truth Check shape (AD-19)**: every command in the `## Verification` section above is a single `bash tools/verify/<name>.sh` invocation. No inline compound bash, no plain subshells, no `$(...)` containing pipes at the invocation layer.
- **Plan-time discipline rule 3 (classifier-shape pre-validation)**: the validator-library invocation form `bash tools/verify/lib/p00-validate-chunk-frontmatter.sh` was classified at plan-authoring time as `single-script-file` (verdict from `scripts/verify/lib/shape-classifier.sh::classify_command` — see step 3 note). The verdict is recorded; the validator's internal pipeline does not surface to the classifier because the classifier inspects invocations, not script bodies.
- **Plan-time discipline rule 2 (verifier-availability cross-check)**: every verifier T03's Verification section names is co-authored within T03's Steps. No cross-task verifier dependencies. T01 and T02 verifiers (referenced by the phase-suite aggregator) were authored in their respective tasks per plan-time discipline.
- **Plan-time discipline rule 4 (`run-probe.sh` scope discipline)**: T03 does NOT use `scripts/util/run-probe.sh` for any verifier invocation. All verifiers are repo-resident under `tools/verify/` and invoked directly via `bash tools/verify/<name>.sh`.

## Expected Output

- `references/file-formats.md` — modified, fourth row appended to the `### Scope Tags` table; pre-existing rows preserved.
- `references/spec-management.md` — modified, new cross-reference paragraph appended.
- `tools/verify/lib/p00-validate-chunk-frontmatter.sh` — created, validator library exits 1 on out-of-policy frontmatter, exits 0 on in-policy.
- `tools/verify/p00-scope-tag-extension.sh` — created, exits 0.
- `tools/verify/p00-spec-management-crossref.sh` — created, exits 0.
- `tools/verify/p00-taxonomy-rejects-unknown.sh` — created, exits 0 (validator correctly rejects two negative fixtures + accepts the in-policy fixture).
- `tools/verify/m036-p00-phase-suite.sh` — created, exits 0 with `SUMMARY: m036-p00-phase-suite.sh pass=8 fail=0`.

## Notes

Expected verifier output examples (for human readers, not for `auto-loop --step=V` evaluation):

- `bash tools/verify/p00-scope-tag-extension.sh` → stdout ends with `SUMMARY: p00-scope-tag-extension.sh pass=6 fail=0`, exit 0.
- `bash tools/verify/p00-spec-management-crossref.sh` → stdout ends with `SUMMARY: p00-spec-management-crossref.sh pass=3 fail=0`, exit 0.
- `bash tools/verify/p00-taxonomy-rejects-unknown.sh` → stdout ends with `SUMMARY: p00-taxonomy-rejects-unknown.sh pass=3 fail=0`, exit 0.
- `bash tools/verify/m036-p00-phase-suite.sh` → stdout has 8 `PASS: <gate>` lines followed by `SUMMARY: m036-p00-phase-suite.sh pass=8 fail=0`, exit 0.

After the phase-suite gate passes, P00 is complete. P01 (Tier 1 live adapters) becomes the next dispatchable phase — it will replace the four `status=stub` rows in `scripts/dispatch/adapters/format/registry.tsv` with `status=live` and author `markdown.sh`, `pdf.sh`, `docx.sh`, `xlsx.sh`. P05 (graph schema extension) also becomes dispatchable — it will refactor `scripts/knowledge/traverse-graph.sh` to read the edge-type list from `references/reference-edge-types.md` instead of hardcoding `relates_to` / `supersedes`.

Per the planner-template Section-Discipline rule, expected output stays under `## Notes` — everything in `## Verification` is eval'd as a command by `auto-loop.sh --step=V`.
