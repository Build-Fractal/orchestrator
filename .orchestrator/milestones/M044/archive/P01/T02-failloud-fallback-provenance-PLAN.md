---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M044"
name: "Fail-loud consumer + index-free grep fallback + provenance header (FR-5)"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `build-context.sh` resolves the index path via `get_index_path` and sources `index-utils.sh`.
- `scripts/dispatch/lib/reference-budget.sh` exists and defines `reference_apply_budget <chunk_list_file> <budget_tokens>` (emits `<id>|<token_count>|<path>` lines while running total ≤ budget; at-least-one-chunk invariant; preserves input order).
- `build-context.sh:194-221` is the M031 Quick read; `:208` is the silent `head -5` fallback over the index.

## Description

FR-5: detect empty/missing/stale index and (a) emit a visible WARNING into the payload + stderr, (b) prefer a deterministic grep-over-raw-files fallback over the silent first-N, (c) stamp an always-on knowledge-provenance header. The fallback read is budget-bounded via the M036a governor. Stale detection uses **mtime** (#Q-2 P0 mechanism). Provenance header pins `provenance_version: 1` (#Q-4).

## Steps

1. Create `scripts/dispatch/lib/knowledge-provenance.sh` (pure-lib, function definitions only, bash 3.2, no top-level execution). Functions:
   - `kp_index_state <index_path> <knowledge_dir>` → echoes one of `missing` (index file absent), `empty` (present but zero `MEM[0-9]` lines), `stale` (present + non-empty but older mtime than the newest `knowledge/**/*.md`), `present` (otherwise). Use `find "$knowledge_dir" -name '*.md' -newer "$index_path"` for the stale comparison (bounded; first hit ⇒ stale). No wall-clock in any output.
   - `kp_index_age <index_path>` → echoes integer seconds since index mtime, or `none` if missing. (Derived from `stat`; this is a delta surfaced only in the header value, not an artifact-body timestamp — CON-3 compliant.)
   - `kp_grep_fallback <knowledge_dir> <touched_files_csv> <budget_tokens>` → deterministic `LC_ALL=C` grep over `knowledge/**/*.md` for MEM/REF entries matching the touched-file/scope terms (when CSV empty, fall back to all entries sorted by id); build a `<id>|<token_count>|<path>` list (token_count ≈ `wc -w`-based estimate, stable), pipe through `reference_apply_budget` to stay within budget; emit the resolved entry bodies in `LC_ALL=C sort` id order. Echo nothing if no matches (caller handles the degraded-empty case).
   - `kp_emit_header <source> <index_age> <entries_considered>` → prints the byte-stable block (fixed field order):
     ```
     knowledge_provenance:
       provenance_version: 1
       source: <source>
       index_age: <index_age>
       entries_considered: <entries_considered>
     ```
2. In `build-context.sh`, source the lib (guarded) alongside the T01 `index-utils.sh` source. Resolve the budget (`budget_tokens`) from the existing Quick-profile budget the consumer already computes; if none, use a named default constant `KP_FALLBACK_BUDGET_TOKENS=2000` (documented).
3. Compute `kp_index_state`. Branch:
   - `present` → existing index path; `source=index`.
   - `empty|missing|stale` → run `kp_grep_fallback`; `source=grep-fallback` (or `degraded` when the fallback returns empty); emit a `WARNING: knowledge index <state> — ran degraded via grep-over-raw fallback` to **stderr** AND prepend the same WARNING line into the `## Knowledge` payload section.
4. Replace the silent `head -5` (`:208`) so the no-touched-files branch is reached only when `source=index`; the degraded branches never silently emit first-N without a provenance flag.
5. Emit `kp_emit_header` into the payload **always** (even `source=index`) — directly under the `## Knowledge` header — with `entries_considered` = count of MEM ids the consumer evaluated.
6. Author the three T02 verifiers (see Verification).

## Must-Haves

- FR-5 / SC-5: degraded state ⇒ WARNING (payload + stderr) + grep fallback + provenance header; no silent first-N.
- SC-6 / CON-2 / CON-3: fallback deterministic (byte-identical on rerun) and within the M036a budget.
- DQ-4 / #Q-4: provenance header always present; `provenance_version: 1`.

## Verification

`bash tools/verify/m044-p01-t02-failloud-fallback.sh`
`bash tools/verify/m044-p01-t02-provenance-always.sh`
`bash tools/verify/m044-p01-t02-determinism-budget.sh`

## Inputs

### From Previous Tasks
- `scripts/dispatch/build-context.sh` (from T01)
  - Key API: sources `index-utils.sh`; `_M031_KNOWLEDGE_INDEX` resolved via `get_index_path`.

### From Disk (Pre-existing)
- `scripts/dispatch/lib/reference-budget.sh` — `reference_apply_budget <list_file> <budget>` (budget-bounded chunk selection, order-preserving, at-least-one-chunk).
- `knowledge/**/*.md` — raw corpus the grep fallback reads.

## Constraints

- CON-2: the fallback read is budget-bounded; **capture-write is not in this task** (read-only path). CON-3: `LC_ALL=C`, stable file order (`sort`), no wall-clock in the header/artifact bodies (`index_age` is a delta value only). Bash 3.2. The header field order is frozen (byte-contract). No new SQL (grep over files only).

## Expected Output

A degraded inject carries the WARNING + `source: grep-fallback` header + grep-resolved entries within budget; a healthy inject carries `source: index` + the same header shape. All three T02 verifiers emit `PASS:`. Rerun on identical inputs is byte-identical.

## Notes

- Expected verifier output is `PASS: ...` on stdout, exit 0. (This prose is intentionally outside `## Verification` per the M028/P01 fenced-block-eval finding.)
- Real-app smoke pending — confirm before phase close: run `build-context.sh --profile=quick` against the T05 empty-index fixture and eyeball the payload header + WARNING (no SQL in this path, so the real-DB rule is satisfied by the grep-only design; this callout covers the end-to-end payload shape).
