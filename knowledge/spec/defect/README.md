# knowledge/spec/defect/ — UAT Defect Knowledge Entries

This directory holds `SPEC-DEFECT-NNN.md` files — structured records of UAT-filed defects linked back to the spec chunk whose acceptance criterion failed. Entries are produced by `scripts/integrations/uat-ingest.sh` (M013/P01) from UAT-bug Issue fixtures or (later, M013/P03) live GitHub Issues.

## Schema Contract

Every `SPEC-DEFECT-NNN.md` file MUST carry the following YAML frontmatter fields:

| Field | Type | Required | Semantics |
|-------|------|----------|-----------|
| `id` | string | yes | `SPEC-DEFECT-NNN` — pinned to the GitHub Issue number, zero-padded to 3 digits minimum. |
| `scope_tags` | string | yes | Standard orchestrator scope-tag list, e.g. `"[project]"` or `"[project], [milestone:M013]"`. |
| `category` | string | yes | Always the literal `spec/defect`. |
| `status` | enum | yes | One of: `open` (freshly ingested, valid chunk), `chunk-lookup-failed` (ingested but chunk ID did not match any `SPEC-*` in `KNOWLEDGE-INDEX.md`), `triaged` (human has assigned a triage bucket), `closed` (defect resolved). |
| `chunk` | string | yes | The `SPEC-*` chunk ID the defect is linked to. Empty string `""` when `status: chunk-lookup-failed`. |
| `phase` | string | yes | The orchestrator `M###-P##` id where the failing acceptance criterion lives. Filled during triage; empty on ingest. |
| `tests` | YAML list | yes | List of test file paths (or identifiers) that covered the failing acceptance criterion. Filled during triage; empty `[]` on ingest. |
| `github_issue_number` | integer \| null | yes | The originating GitHub Issue number. `null` if the defect is hand-authored. |
| `created_at` | ISO-8601 string | yes | When the original Issue was opened. |
| `ingested_at` | ISO-8601 string | yes | When this knowledge entry was written. |

## `status` Enum Transitions

```
            +---------------------+
            |  chunk-lookup-failed|  (terminal unless chunk is manually resolved)
            +---------------------+
                     |
                     v  (manual reconciliation)
  ingest --> open --> triaged --> closed
```

- `open` -> `triaged`: a maintainer assigns the defect to an orchestrator triage bucket (execution-error / spec-gap / spec-error) and records it in the body.
- `triaged` -> `closed`: the bucket action completes (re-dispatch, clarification phase merged, spec chunk superseded).
- `chunk-lookup-failed` -> `open`: a maintainer manually supplies the correct chunk ID in the `chunk:` field.

## M020 Forward-Compatibility

M013 deliberately ships the schema above without review-state lifecycle, query-surface affordances, or clustering metadata — all of which are M020 territory per `.orchestrator/DECISIONS.md` D013. M020 MAY add new optional frontmatter fields (e.g. `review_state:`, `cluster_id:`, `similarity_hash:`) in a forward-compatible additive manner. M013-era entries will continue to validate against M020's extended schema.

This boundary is the Knowledge-Layer Boundary ruling (D014): `SPEC-DEFECT-NNN` IDs are a new category the `spec/defect` subdir owns and does not widen the existing `SPEC-*` chunk ID format. The `chunk:` field references existing chunk IDs verbatim — no composite addressing.

## Relationship to `KNOWLEDGE-INDEX.md`

Entries are scanned and indexed by `scripts/knowledge/rebuild-index.sh` the same way other knowledge entries are. They appear in the existing pipe-table section with `category: spec/defect`. They do NOT appear in the `## Spec Chunks` section — that section is scoped to `SPEC-US-*`, `SPEC-AC-*`, `SPEC-NG-*`, `SPEC-CON-*` (the canonical spec-chunk categories).

## Ingestion

See `scripts/integrations/uat-ingest.sh`. Fixture input format and CLI are documented in `references/github-integration.md` (T06).
