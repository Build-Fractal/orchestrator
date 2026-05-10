---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P00"
milestone: "M036"
name: "Edge-type SSOT + adapter registry TSV seam + shape verifiers"
depends_on: ["T01"]
---

## Prerequisites

- T01 completed: `references/reference-taxonomy.md`, `references/reference-frontmatter-contract.md`, `references/reference-source-types.yaml` exist and pass their shape verifiers.
- `tools/verify/` directory exists (T01 created it).
- `scripts/dispatch/adapters/format/` directory exists ([M005](../../../../../milestones/M005/index.md) — currently contains `native.sh` and `speckit.sh`, both unrelated to reference extraction). T02 adds a new `registry.tsv` file alongside; it does NOT modify the existing two scripts.
- `specs/033-reference-corpus-ingest/spec.md` FR-5 (three new edge types) and FR-13 (live Tier 1 adapters — registry seam declared at P00, scripts authored at P01) are the binding contracts.

## Description

Author two SSOT seams that downstream phases extend:

1. `references/reference-edge-types.md` — declares the three new directional edge types (`cites`, `derived_from`, `applies_to_field`) plus the two pre-existing edges (`relates_to`, `supersedes`) for completeness. Read by P05 (graph traverser extension).
2. `scripts/dispatch/adapters/format/registry.tsv` — adapter dispatch table seam. P00 declares four rows (`markdown`, `pdf`, `docx`, `xlsx`) all at `status=stub` pointing at not-yet-authored scripts under `scripts/dispatch/adapters/format/<format>.sh`. P01 lands the live adapter scripts and flips the rows to `status=live`. Read by P02 (extract command).

Both files are pure declarative content. T02 also ships their structural shape verifiers (`p00-edge-types-shape.sh`, `p00-adapter-registry-shape.sh`).

T02 does NOT author the live adapter scripts (P01 deliverable). T02 does NOT modify the existing `native.sh` / `speckit.sh` adapters (those are unrelated to reference-format extraction; they handle backend dispatch shapes).

## Steps

1. **Author `references/reference-edge-types.md`.** Required structure:

   ```markdown
   ---
   schema_version: "1.0"
   type: reference-edge-types
   milestone: "M036"
   phase: "P00"
   created_at: "2026-05-01"
   ---

   # Reference Knowledge Graph Edge Types (M036 SSOT)

   The orchestrator's knowledge graph (`scripts/knowledge/traverse-graph.sh`)
   walks typed edges declared in chunk frontmatter. M036 introduces three
   new edge types alongside the two pre-existing edges. This file is the
   single source of truth (Principle XI) for the edge-type list and each
   edge's directionality.

   Consumers:
   - `scripts/knowledge/traverse-graph.sh` (P05) — additively extended to
     recognize the three new edge types alongside `relates_to` /
     `supersedes`.
   - `references/reference-frontmatter-contract.md` (P00 T01) — declares
     the chunk-frontmatter fields whose values these edges traverse.
   - `scripts/dispatch/scope-filter.sh` (P07) — uses `applies_to_field`
     edge to scope reference chunks for dispatch injection (FR-7).

   ## Edge Types

   ### cites (new in M036)
   **Directionality**: directional, from citing chunk → cited reference.
   **Frontmatter field**: `cites: [<chunk_id>, ...]`.
   **Semantics**: the source chunk asserts that its content cites or
   relies upon the target chunk's content. BFS traversal from a spec
   chunk to its `cites:` targets surfaces authoritative reference
   material in dispatch payloads.
   **Example**: `SPEC-requirement-FR-7` declares `cites: [REF-cms-rule-483-20]`.

   ### derived_from (new in M036)
   **Directionality**: directional, from downstream chunk → upstream
   source.
   **Frontmatter field**: `derived_from: [<chunk_id>, ...]`.
   **Semantics**: the source chunk's content is derived from
   (paraphrased, summarized, or extracted from) the target chunk.
   Reverse-BFS from a regulatory rule surfaces the training material
   derived from it.
   **Example**: `REF-training-pbj-circle-2024-08` declares
   `derived_from: [REF-cms-rule-483-20]`.

   ### applies_to_field (new in M036)
   **Directionality**: directional, from chunk → field-name.
   **Frontmatter field**: `applies_to_field: [<field-name>, ...]`.
   **Semantics**: the chunk's content authoritatively governs one or
   more named fields in the consumer project's domain model. Dispatch
   injection (FR-7) walks this edge to surface field-scoped reference
   excerpts when a task plan declares `applies_to_field: <name>`.
   **Note**: `applies_to_field` is BOTH a frontmatter field name AND
   an edge type — the field is interpreted as an edge by the graph
   layer.

   ### relates_to (pre-existing — M011/[M020](../../../../../milestones/M020/index.md))
   **Directionality**: bidirectional.
   **Frontmatter field**: `relates_to: [<chunk_id>, ...]`.
   **Semantics**: undirected affinity. Pre-existing; declared here for
   completeness. M036 does not modify `relates_to` semantics or the
   traversal layer's handling thereof (CON-5).

   ### supersedes (pre-existing — M011/M020)
   **Directionality**: directional, from newer chunk → older chunk.
   **Frontmatter field**: `supersedes: [<chunk_id>]` (typically singleton).
   **Semantics**: chain-walk to find the latest version. Pre-existing;
   M036 reuses this edge for the reference-corpus supersede chain
   (FR-10) without modification (CON-5).

   ## Adding a New Edge Type

   New edge types require an M036 (or follow-on milestone) D-row in
   [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) plus a coordinated update to:
   - this file (declaration);
   - `references/reference-frontmatter-contract.md` (frontmatter field
     declaration);
   - `scripts/knowledge/traverse-graph.sh` (traversal logic).

   No script shall hardcode the edge-type list (Principle XI).
   ```

   The shape verifier greps for the `## Edge Types` heading + each of
   the five edge-type names (`cites`, `derived_from`,
   `applies_to_field`, `relates_to`, `supersedes`).

2. **Author `scripts/dispatch/adapters/format/registry.tsv`.** Required structure (literal tab characters between fields — TSV, not space-delimited):

   ```tsv
   format	adapter_path	status	notes
   markdown	scripts/dispatch/adapters/format/markdown.sh	stub	P01 deliverable — passthrough adapter (Tier 1 for already-normalized content)
   pdf	scripts/dispatch/adapters/format/pdf.sh	stub	P01 deliverable — pdftotext -layout (poppler-utils host dependency)
   docx	scripts/dispatch/adapters/format/docx.sh	stub	P01 deliverable — pandoc plaintext (pandoc host dependency)
   xlsx	scripts/dispatch/adapters/format/xlsx.sh	stub	P01 deliverable — sheet-by-sheet CSV with header detection (xlsx2csv or python openpyxl shim)
   ```

   - Header line (first line): `format\tadapter_path\tstatus\tnotes`.
   - Four data rows, one per format, in order `markdown`, `pdf`, `docx`, `xlsx`.
   - Each `adapter_path` resolves to an as-yet-unauthored script under `scripts/dispatch/adapters/format/<format>.sh`. The shape verifier does NOT check that these files exist — P01 authors them.
   - All four `status` values are `stub` at T02 close. P01 flips them to `live` after authoring the scripts.
   - Use literal tab characters as separators (`\t`). Editors / clients pasting space-delimited content will fail the shape verifier's column-count check.

3. **Author `tools/verify/p00-edge-types-shape.sh`.** Bash 3.2-compatible. Behavior:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/p00-edge-types-shape.sh — M036 P00 T02 shape gate for
   # references/reference-edge-types.md. Asserts frontmatter + ## Edge
   # Types heading + each of the five edge types appears as a level-3
   # heading. Single-script-file shape per AD-19.
   set -eu
   FILE="${1:-references/reference-edge-types.md}"
   pass=0; fail=0
   if [ ! -f "$FILE" ]; then
     echo "FAIL: $FILE missing"
     echo "SUMMARY: p00-edge-types-shape.sh pass=0 fail=1"
     exit 1
   fi
   for token in 'schema_version' 'type: reference-edge-types' '## Edge Types' '### cites' '### derived_from' '### applies_to_field' '### relates_to' '### supersedes'; do
     if grep -qF "$token" "$FILE"; then
       pass=$((pass + 1))
     else
       fail=$((fail + 1))
       echo "FAIL: $FILE missing token: $token"
     fi
   done
   echo "SUMMARY: p00-edge-types-shape.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

4. **Author `tools/verify/p00-adapter-registry-shape.sh`.** Bash 3.2-compatible. Behavior:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/p00-adapter-registry-shape.sh — M036 P00 T02 shape gate
   # for scripts/dispatch/adapters/format/registry.tsv. Asserts header +
   # exactly four data rows for the four supported formats. Single-script-
   # file shape per AD-19.
   set -eu
   FILE="${1:-scripts/dispatch/adapters/format/registry.tsv}"
   pass=0; fail=0
   if [ ! -f "$FILE" ]; then
     echo "FAIL: $FILE missing"
     echo "SUMMARY: p00-adapter-registry-shape.sh pass=0 fail=1"
     exit 1
   fi
   # Header check — first line must contain the four column names.
   header=$(head -n 1 "$FILE")
   for col in 'format' 'adapter_path' 'status' 'notes'; do
     case "$header" in
       *"$col"*)
         pass=$((pass + 1))
         ;;
       *)
         fail=$((fail + 1))
         echo "FAIL: header missing column: $col"
         ;;
     esac
   done
   # Format row checks — one row per format, anchored at start of line.
   for fmt in 'markdown' 'pdf' 'docx' 'xlsx'; do
     if grep -q "^${fmt}	" "$FILE"; then
       pass=$((pass + 1))
     else
       fail=$((fail + 1))
       echo "FAIL: registry missing row for format: $fmt"
     fi
   done
   # Row count check — must be exactly 4 data rows (header + 4 = 5 lines minimum).
   line_count=$(wc -l < "$FILE")
   if [ "$line_count" -ge 5 ]; then
     pass=$((pass + 1))
   else
     fail=$((fail + 1))
     echo "FAIL: registry has fewer than 5 lines (header + 4 data rows)"
   fi
   echo "SUMMARY: p00-adapter-registry-shape.sh pass=$pass fail=$fail"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   exit 0
   ```

   Note the `^${fmt}\t` (tab-anchored) row check — uses the literal tab character in the regex by inserting a real `<TAB>` between `${fmt}` and the trailing quote. Editors that auto-convert tabs to spaces will break the verifier; the verifier's failure on space-delimited content is the contract that enforces TSV format.

5. **Self-check.** Run both T02 verifiers from repo root:

   ```bash
   bash tools/verify/p00-edge-types-shape.sh
   bash tools/verify/p00-adapter-registry-shape.sh
   ```

   Both exit 0 with `SUMMARY: <name> pass=N fail=0`.

## Must-Haves

This task satisfies these phase truths:

- "`references/reference-edge-types.md` exists with `## Edge Types` heading + five edges" — T02 authors; `p00-edge-types-shape.sh` gates.
- "`scripts/dispatch/adapters/format/registry.tsv` exists with header + four data rows (one per format) at `status=stub`" — T02 authors; `p00-adapter-registry-shape.sh` gates.

This task does NOT satisfy:

- The taxonomy / frontmatter contract / source-types truths (T01).
- The scope-tag extension truths (T03).
- The taxonomy-rejects-unknown negative-test truth (T03).
- The phase-suite aggregator truth (T03).

## Verification

```bash
bash tools/verify/p00-edge-types-shape.sh
bash tools/verify/p00-adapter-registry-shape.sh
```

Each verifier uses single-script-file shape per AD-19. Each emits `SUMMARY: <script> pass=N fail=0` on success and exits 0.

## Inputs

### From Previous Tasks

- `references/reference-frontmatter-contract.md` (from T01) — its `## Graph Edge Fields` section names the five edge types T02 declares directionality + semantics for. T02 keeps the edge name list in lockstep with the contract file (Principle XI). Key API: the contract file is read by humans; T02's edge-types file is read by humans + (via P05) by `traverse-graph.sh`. Key types: edge-name strings (`cites`, `derived_from`, `applies_to_field`, `relates_to`, `supersedes`).
- `references/reference-taxonomy.md` (from T01) — informationally referenced in the edge-types file's introduction; not load-bearing for T02's verifier.

### From Disk (Pre-existing)

- `scripts/dispatch/adapters/format/` — existing directory containing `native.sh` and `speckit.sh` (M005 backend-dispatch adapters, unrelated to reference-format extraction). T02 adds `registry.tsv` here without modifying the existing two scripts. The shape verifier's existence-check is path-relative to repo root, so the registry sits naturally alongside the existing adapters.
- `scripts/knowledge/traverse-graph.sh` — existing graph traverser (M020). Hardcodes `'relates_to'` and `'supersedes'` at lines ~263, ~270. P05 (later) refactors to read from the edge-types SSOT file T02 authors. T02 itself does NOT modify `traverse-graph.sh`.
- `specs/033-reference-corpus-ingest/spec.md` — FR-5 (three new edge types) + FR-13 (live Tier 1 adapter registration) authoritative source.

## Constraints

- **Bash 3.2 compatibility**: same as T01 — no `mapfile`, `declare -A`, process substitution, or `$()` containing pipes. Use `case` statements for substring matches; use `grep -q` with anchored patterns; use `wc -l < file` (input redirection inside `$(...)` is forbidden, but `wc -l < file` standalone is fine because the redirection target is not a `$()` substitution).
- **Single-script-file Truth Check shape (AD-19)**: each verifier is a standalone script invoked as `bash tools/verify/<name>.sh`.
- **TSV file MUST use literal tabs**: not spaces. The shape verifier's `^${fmt}\t` row-check enforces this; copy-pasting from a markdown table will break the verifier. Editors that auto-convert tabs to spaces (e.g., default VS Code with markdown context) need a `.editorconfig` override or manual tab-insertion. See the registry file's commit for tab-fidelity verification.
- **CON-5 (no-spec-chunk-schema-change)**: T02 declares the edge-type SSOT additively. The two pre-existing edges (`relates_to`, `supersedes`) are listed for completeness only; M036 does not modify their semantics or traversal handling. P05 will refactor `traverse-graph.sh` to read from this SSOT, but the existing edge-handling logic is preserved verbatim.
- **No live adapter scripts at T02 close**: all four registry rows are `status=stub`. P01 authors the live scripts and flips the status. Attempting to flip rows to `live` at T02 (without the underlying scripts) would mislead P02's extract command into trying to invoke missing files.
- **Verifier-availability cross-check (plan-time discipline rule 2)**: T02's verifiers (`p00-edge-types-shape.sh`, `p00-adapter-registry-shape.sh`) are co-authored alongside their target artifacts in this same task. No T02 verification command depends on a script authored by T03.

## Expected Output

- `references/reference-edge-types.md` — created, ≥30 lines, five `### <edge>` headings.
- `scripts/dispatch/adapters/format/registry.tsv` — created, 5 lines (header + 4 data rows), all data rows at `status=stub`.
- `tools/verify/p00-edge-types-shape.sh` — created, exits 0 against the new edge-types file.
- `tools/verify/p00-adapter-registry-shape.sh` — created, exits 0 against the new registry TSV.

## Notes

Expected verifier output examples (for human readers, not for `auto-loop --step=V` evaluation):

- `bash tools/verify/p00-edge-types-shape.sh` → stdout ends with `SUMMARY: p00-edge-types-shape.sh pass=8 fail=0`, exit 0.
- `bash tools/verify/p00-adapter-registry-shape.sh` → stdout ends with `SUMMARY: p00-adapter-registry-shape.sh pass=9 fail=0`, exit 0 (4 header columns + 4 format rows + 1 line-count check = 9).

Per the planner-template Section-Discipline rule, expected output stays under `## Notes` — everything in `## Verification` is eval'd as a command by `auto-loop.sh --step=V`.

The TSV's `status=stub` discipline means P00 is a clean-cut declarative phase: every artifact is read by downstream phases but no executable adapter logic is shipped. P01 will author the live adapter scripts and flip the four `stub` values to `live` in the same registry file (no additional rows). P00 phase close is gated by the seam being structurally sound, not by adapter functionality.
