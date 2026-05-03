---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P05"
milestone: "M036"
name: "Traverser extension (traverse-graph.sh recognizes new edge types)"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped the schema + indexer extension. The `edges` table CHECK enum accepts the 5-element edge-type set; `rebuild-index.sh` populates the new edges from frontmatter.
- `references/reference-edge-types.md` exists and is the SSOT for edge directionality. Verified at plan-authoring time.
- `scripts/knowledge/traverse-graph.sh` exists. The recursive CTE at lines ~260-285 hardcodes `edge_type = 'relates_to'` in three places (forward branch, reverse branch, recursive descent).

## Description

Extend `scripts/knowledge/traverse-graph.sh` to walk the three new edge types additively, while preserving byte-identical default behavior for invocations that don't request the extension (CON-5).

Two design decisions, anchored in the P00 SSOT directionality declarations:

1. **Default behavior is unchanged.** Without `--edge-types`, the CTE walks `relates_to` (bidirectional) exactly as today. The `--provenance` mode walks `supersedes` exactly as today.

2. **Opt-in extension via `--edge-types <comma-list>`.** When the flag is present, the CTE walks the specified edges. Directionality follows the SSOT:
   - `relates_to` — bidirectional (existing semantics).
   - `supersedes` — directional (newer → older).
   - `cites` — directional (citer → cited).
   - `derived_from` — directional (downstream → upstream).
   - `applies_to_field` — directional (chunk → field-name).

   Directional edges walk only the forward direction by default. A separate `--reverse` flag walks targets-first (needed for the SSOT acceptance scenario "BFS runs from the cms-rule chunk in reverse, training chunk reachable via derived_from").

3. **Edge label in output.** When walking typed edges (anything other than the default `relates_to`-only mode), each result line is suffixed with `|<edge_type>` so consumers (and the SC-4 test) can grep the label. Default-mode output is unchanged (CON-5 baseline).

The fixture-driven Truth Check that drives this (boundary map demo): `bash scripts/knowledge/traverse-graph.sh --id SPEC-requirement-FR-7 --edge-types cites --max-depth 1` returns `REF-cms-rule-§483-20|cites` on stdout.

## Steps

1. **Add argument parsing** for `--edge-types <comma-list>` and `--reverse` to the existing `while [ $# -gt 0 ]` block (lines 30-57). Default `edge_types=""` (sentinel for "use legacy relates_to-only path"). Default `reverse=false`.

2. **Branch the CTE construction.** When `edge_types` is empty, leave the existing CTE at lines 260-285 unchanged (CON-5 byte-equality). When non-empty:
   - Parse the comma-list into a SQL `IN` clause: `edge_type IN ('cites', 'derived_from', ...)`. Escape each token via `sed "s/'/''/g"` for safety (matches the existing `safe_id` pattern at line 74).
   - Build a CTE that walks only forward direction by default; add reverse direction when `--reverse` is set. The forward CTE shape mirrors the existing one but with the typed-edge `IN` clause and without the second `UNION` branch (since most new types are directional):
     ```sql
     WITH RECURSIVE reachable(id, edge_type, depth) AS (
       SELECT target_id, edge_type, 1 FROM edges
         WHERE source_id = '${safe_id}' AND edge_type IN (${types_clause})
       UNION ALL
       SELECT e2.target_id, e2.edge_type, r.depth + 1
         FROM edges e2 JOIN reachable r ON e2.source_id = r.id
         WHERE r.depth < ${max_depth} AND e2.edge_type IN (${types_clause})
           AND e2.target_id != '${safe_id}'
     )
     SELECT e.id || '|' || r.edge_type
     FROM entries e JOIN reachable r ON e.id = r.id
     WHERE e.id != '${safe_id}'
     GROUP BY e.id, r.edge_type
     LIMIT ${max_entries};
     ```
   - When `--reverse` is set, swap `source_id`/`target_id` in the WHERE clauses (BFS walks from the target backward).
   - When `--ranked` AND `--edge-types` are both present, render the existing ranked output PLUS the edge-type suffix: `e.id || '|' || e.confidence || '|' || MIN(r.depth) || '|' || printf('%.6f', e.confidence * (1.0 / MIN(r.depth))) || '|' || r.edge_type`.

3. **applies_to_field special case.** The `target_id` of an `applies_to_field` edge is a field-name string (e.g., `staff_count`), not a chunk ID. The current CTE joins `edges r` to `entries e ON e.id = r.id`, which would silently drop applies_to_field edges (no entry row exists for `staff_count`). To preserve the demo behavior, when `applies_to_field` is in the edge-types list, replace the inner `JOIN entries` with a `LEFT JOIN entries` and emit the `target_id` directly with a `|<field-name>|applies_to_field` shape when the join misses. Add a short comment block at the join site explaining the asymmetry, citing `references/reference-edge-types.md` directionality table.

4. **Author `tools/verify/m036-p05-traverse-cites.sh`** — single-script-file verifier. Stages a mktemp `knowledge/` tree under `PROJECT_ROOT=$tmpdir`; writes a fixture spec chunk (`SPEC-FR-7.md` with `cites: [REF-cms-rule-483-20]`) and a fixture reference chunk (`REF-cms-rule-483-20.md` with no outgoing edges); runs `bash scripts/knowledge/rebuild-index.sh` to build the staged DB; runs `bash scripts/knowledge/traverse-graph.sh --id SPEC-FR-7 --edge-types cites --max-depth 1`; asserts stdout contains the literal substring `REF-cms-rule-483-20|cites`.

5. **Author `tools/verify/m036-p05-traverse-relates-to-baseline.sh`** — CON-5 regression guard. Stages a fixture corpus under `PROJECT_ROOT=$tmpdir` containing only pre-P05 edge fields (`relates_to: [MEM002]`, `supersedes: ""`); rebuilds the index; runs `bash scripts/knowledge/traverse-graph.sh --id MEM001` (default mode, no `--edge-types`); diffs the output against a checked-in baseline file at `tests/fixtures/m036-p05-baseline/traverse-relates-to.expected.txt`. Any diff exits 1 with a `FAIL: CON-5 regression` message naming the differing line.

   The fixture corpus and baseline file are co-authored by this task (under `tests/fixtures/m036-p05-baseline/`). Two MEM entries (`MEM001`, `MEM002`) with `relates_to: [MEM002]` on MEM001. Baseline file content is whatever `traverse-graph.sh` emits today for that input — captured by running the unmodified traverser once before T02's edits and saving its stdout verbatim.

   Critical sequencing: capture the baseline BEFORE editing `traverse-graph.sh`. The verifier's contract is "post-edit output equals pre-edit output for default-mode invocations." Baseline-after-edit defeats the guard.

## Must-Haves

Truths from the phase plan addressed by this task:

- "`traverse-graph.sh` walks `cites` edges and emits the edge label in `--ranked` / labeled output" — covered by step 4.
- "`traverse-graph.sh` default invocation (no `--edge-types` flag) is byte-identical to pre-P05 for a relates_to fixture (CON-5 regression guard)" — covered by step 5.

## Verification

```bash
bash tools/verify/m036-p05-traverse-cites.sh
```

```bash
bash tools/verify/m036-p05-traverse-relates-to-baseline.sh
```

## Inputs

### From Previous Tasks

- `scripts/knowledge/lib/graph-db.sh` (modified by T01) — Key API: `db_init`, `db_insert_edge` accept the widened CHECK enum.
- `scripts/knowledge/rebuild-index.sh` (modified by T01) — emits `cites`/`derived_from`/`applies_to_field` edges into the staged DB on rebuild.

### From Disk (Pre-existing)

- `scripts/knowledge/traverse-graph.sh` — the file to modify. Key behavior:
  - `--id <entry>` is required.
  - `--max-depth` / `--hops` set CTE depth (default 1).
  - `--max-entries` truncates results (default 5).
  - `--ranked` switches output to `id|confidence|depth|score`.
  - `--provenance` walks supersedes chain (untouched by T02).
  - Default output is one related ID per line.
  - Returns exit 0 always (no related entries is valid).
- `references/reference-edge-types.md` — SSOT for directionality decisions. Each new edge's directionality is declared in its `Directionality:` field.
- `scripts/knowledge/lib/graph-db.sh` — `db_query(db_path, sql)` wraps `sqlite3` with heredoc input.

## Constraints

- **CON-5 byte-equality for default mode** — no `--edge-types` flag means no behavior change. The verifier `m036-p05-traverse-relates-to-baseline.sh` enforces this mechanically. The CTE construction MUST remain in a separate code path from the legacy CTE — do not "unify" the two by injecting `IN ('relates_to')` into the legacy path. SQL string equality at the CTE-source level is the contract.
- **Bash 3.2 / POSIX-sh** — comma-list parsing uses `IFS=','` `for` loop wrapped in subshell or with explicit `IFS` save/restore (matches the existing `--depends` parsing pattern at lines 119-128 of `scope-filter.sh`). No `read -ra` for the SQL `IN` clause construction (must build a single string with quoted tokens).
- **applies_to_field is non-uniform** — its target is a field name, not a chunk ID. The LEFT JOIN handling is required; otherwise the SC-4 demo fails for applies_to_field edges. Document this in code with an inline comment.
- **No edges-table writes from the traverser** — traverse-graph.sh is read-only against the DB. Any test fixture that needs edges in the table must call `rebuild-index.sh` (which T01 owns) to populate them.
- **Single-script-file Truth Check shape (AD-19)** — both Verification commands are single `bash <path>` invocations. The verifiers internally use heredocs and `$(...)` freely (those are fine inside script bodies; AD-19 only constrains the inline Truth Check command surface).

## Expected Output

`m036-p05-traverse-cites.sh` prints `PASS: m036-p05-traverse-cites (cites edge surfaced with label)` on success.

`m036-p05-traverse-relates-to-baseline.sh` prints `PASS: m036-p05-traverse-relates-to-baseline (CON-5 byte-identical)` on success. On failure it prints `FAIL: CON-5 regression at line <N>: expected '<exp>' got '<got>'` to stderr.

After T02 lands, the demo invocation from the phase plan's `demo_sentence` works end-to-end against a fixture corpus: a spec chunk declaring `cites: [REF-...]` is reachable from the traverser at depth 1 with the `cites` label preserved.
