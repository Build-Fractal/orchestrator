# filter-mixed-status fixture (M018/P07/T01)

Exercises the knowledge-aware filter (US-2 / FR-3) — the only mutating
stage in the M018 compression pipeline that operates on a knowledge
tree with mixed `status:` field values.

## Knowledge tree

| Entry      | Category    | Status        | Filter outcome |
|------------|-------------|---------------|----------------|
| MEM-FXT-A  | conventions | graduated     | kept           |
| MEM-FXT-B  | conventions | experimental  | dropped        |
| MEM-FXT-C  | patterns    | superseded    | dropped        |
| MEM-FXT-D  | patterns    | graduated     | kept           |

## Config under test

`compression.knowledge_filter.drop_list: ["superseded", "experimental"]`.
Tier 1 + Tier 2 disabled. Tier 3 short-circuits via the runner's intensity
override (`Quick`).

## Byte-equality contract

The post-filter payload bytes are SHA-256-hashed under each runtime
(`ORCH_BACKEND` ∈ {`claude-code`, `codex`, `cursor`}). The three hashes
are byte-identical because the filter is deterministic bash code that
does not branch on `ORCH_BACKEND`.
