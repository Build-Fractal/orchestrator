# M018/P02 fixture — knowledge-aware status filter

Mixed-status knowledge entries for the M018/P02 filter verifier. This fixture
exercises the FR-3 status filter wired into `scripts/dispatch/build-context.sh`
via `scripts/lib/knowledge-filter.sh`.

## Contents

- `knowledge-stream.md` — multi-entry markdown stream in the shape produced
  by `scripts/knowledge/resolve-entries.sh` (one frontmatter block per entry,
  followed by markdown body). Entries:

  | ID     | status         | expected disposition |
  |--------|----------------|----------------------|
  | MEM900 | stable         | RETAIN               |
  | MEM901 | superseded     | DROP (default list)  |
  | MEM902 | (none)         | RETAIN (fail-open)   |
  | MEM903 | experimental   | DROP (default list)  |
  | MEM904 | graduated      | RETAIN               |

  Concretely: MEM901's frontmatter carries `status: superseded`; MEM903's
  frontmatter carries `status: experimental`. With the default drop-list
  both are removed from the resolved knowledge stream before payload
  assembly.

  With the default config (`drop_list: ["superseded", "experimental"]`), the
  filter drops MEM901 + MEM903 and retains MEM900, MEM902, MEM904 — a 2/5
  drop ratio that matches the P00 modeling assumption (mean_drop=0.30, see
  `.orchestrator/scratch/m018-section-distribution-output.json`
  `.model_assumptions.filter`).

- `KNOWLEDGE.md` — same content packaged as a project-style flat
  KNOWLEDGE.md so the build-context.sh planning branch can resolve it via
  `_bc_gather_knowledge_flat` for end-to-end smoke tests.

## Usage

The companion verifier scripts (T04 ships them) stage this stream into a
temp project root, run `kf_filter_stream` against it, and assert:

1. With the default drop-list, MEM901 + MEM903 are absent from the filtered
   stream and the stats file reports `dropped_count=2`.
2. MEM902 (missing `status:`) is RETAINED — fail-open per FR-3 + grammar
   contract `## Tier: filter` failure semantics.
3. With `compression.enabled: false` (or the
   `ORCH_OVERRIDE_COMPRESSION_ENABLED=false` env override), the stream is
   passed through byte-identically — diff against
   `tests/fixtures/m018-p02-baseline-payload.golden.txt` returns empty.

## Not committed: token-count goldens

The `dropped_tokens` field is the int-quartile of dropped-entry char count.
Because frontmatter shape may evolve, we do NOT golden the token count —
verifiers assert `dropped_tokens > 0`, not an exact value.
