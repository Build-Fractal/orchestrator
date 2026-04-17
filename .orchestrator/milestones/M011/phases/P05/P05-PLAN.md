---
schema_version: "1.0"
type: phase-plan
phase: "P05"
milestone: "M011"
goal: "Wire the evaluate and roadmap commands to ingested spec chunks: evaluate derives metrics from spec/* knowledge entries (with graceful fallback to raw spec regex when no chunks exist), and roadmap builds phase candidates from spec/story chunks with intensity-aware interaction (Quick directive / Standard semi-directive / Full collaborative) and story→story relates_to edges translated into phase depends_on."
demo_sentence: "A developer runs `orchestrator:evaluate` on a milestone whose spec has been ingested via `orchestrator:ingest`, and the story/AC/FR counts come from spec/* chunk counts — not regex on the raw spec. Then `orchestrator:roadmap` at Quick intensity produces a roadmap in a single directive pass where each phase corresponds to a spec/story chunk and depends_on edges trace story graph relationships."
risk: "medium"
depends_on: [P02, P04]
---

## Must-Haves

### Truths

<!-- Each truth has a single-script-file Check per AD-19.
     Verify scripts themselves may use any bash internally; the
     restriction applies only to these Check: commands. -->

- A new helper `scripts/state/spec-metrics.sh <orch_root>` counts ingested spec chunks by category and emits key=value lines (`spec_chunks_present=true|false`, `story_count=N`, `requirement_count=N`, `acceptance_count=N`, `constraint_count=N`, `nfr_count=N`, `non_goal_count=N`) to stdout. Returns `spec_chunks_present=false` with all counts `=0` when no `spec/*` entries exist.
  - Check: `bash scripts/verify/m011-p05-spec-metrics-counts.sh`
- `spec-metrics.sh` counts ONLY non-superseded tips (entries whose frontmatter `superseded_by:` is empty). Superseded-chain ancestors are excluded so a spec revised from 5 to 7 requirements reports `requirement_count=7`, not `12`.
  - Check: `bash scripts/verify/m011-p05-spec-metrics-skips-superseded.sh`
- `commands/evaluate.md` documents the "ingested spec chunk" detection path: evaluate calls `spec-metrics.sh`, and when `spec_chunks_present=true` it uses those counts for tier classification; otherwise it falls back to the existing regex-based raw-spec parsing. The document references `scripts/state/spec-metrics.sh` in its "Reference Files" block.
  - Check: `bash scripts/verify/m011-p05-evaluate-doc-references-metrics.sh`
- `commands/roadmap.md` documents spec-chunk-driven decomposition: when ingested `spec/story` chunks exist, roadmap enumerates them via `scope-filter.sh --category spec/story --graph` and produces one phase per story (or one phase per tightly-linked story cluster for multi-story phases). Story→story `relates_to` edges translate to phase `depends_on`. When no chunks exist, roadmap falls back to raw-spec parsing (existing behavior). The document references `scripts/dispatch/scope-filter.sh` and `scripts/knowledge/traverse-graph.sh` in "Reference Files".
  - Check: `bash scripts/verify/m011-p05-roadmap-doc-references-chunks.sh`
- `commands/roadmap.md` documents intensity-aware interaction: at Quick it produces the roadmap in one directive pass, at Standard it presents phase rationale for confirm/refine, at Full it delegates to the `discuss` Tier C collaborative loop. The doc calls `scripts/engine/intensity-gate.sh --stage roadmap` to resolve which behavior applies.
  - Check: `bash scripts/verify/m011-p05-roadmap-doc-references-intensity.sh`
- `scripts/engine/intensity-gate.sh` includes a `roadmap` stage row with `Quick=single-pass`, `Standard=basic-decomp,rationale`, `Full=basic-decomp,rationale,collaborative-loop` substeps (or equivalent named substeps). Calling `bash scripts/engine/intensity-gate.sh --stage roadmap --intensity Quick` emits `execute_substeps=<csv>` and `skip_substeps=<csv>` with no error.
  - Check: `bash scripts/verify/m011-p05-intensity-gate-roadmap-stage.sh`
- A new helper `scripts/knowledge/spec-story-graph.sh <orch_root>` emits one line per `spec/story` chunk as `<SPEC-STORY-ID>|<comma-sep depends-on SPEC-STORY-IDs>` by traversing `relates_to` edges between story entries. Stories that reference no other stories emit `<ID>|` (empty right side). Superseded story tips are skipped.
  - Check: `bash scripts/verify/m011-p05-spec-story-graph-emits-deps.sh`
- `spec-story-graph.sh` delegates to `scripts/knowledge/traverse-graph.sh` for edge traversal — no direct `knowledge.db` SQL beyond what the graph-db lib already exposes. The script sources `scripts/knowledge/lib/graph-db.sh` (or invokes traverse-graph) rather than reimplementing edge lookup.
  - Check: `bash scripts/verify/m011-p05-spec-story-graph-delegates.sh`
- End-to-end demo scenario: given a fixture with 3 ingested stories (US-001, US-002, US-003 where US-003 relates_to US-001), 8 requirements, 5 acceptances, 2 constraints, 1 non-goal, `spec-metrics.sh` reports `story_count=3 requirement_count=8 acceptance_count=5 constraint_count=2 non_goal_count=1` (non-goal counted but not used in tier classification), and `spec-story-graph.sh` emits exactly `US-003|US-001` (with US-001 and US-002 on empty-RHS lines).
  - Check: `bash scripts/verify/m011-p05-demo-scenario.sh`
- All new scripts pass `bash -n` under Bash 3.2 with no `declare -A`, `mapfile`, `readarray`, or `<(...)` usage.
  - Check: `bash scripts/verify/m011-p05-bash32-compat.sh`
- `commands/evaluate.md` and `commands/roadmap.md` pass `bash -n`-equivalent structural lint — they remain valid markdown with intact YAML frontmatter and do not remove any previously referenced script (backwards-compat: all previously listed Reference Files remain present).
  - Check: `bash scripts/verify/m011-p05-commands-preserve-references.sh`

### Artifacts

- `scripts/state/spec-metrics.sh` (min 40 lines, contains "spec_chunks_present")
- `scripts/knowledge/spec-story-graph.sh` (min 30 lines, contains "relates_to")
- `commands/evaluate.md` (min 180 lines, contains "spec-metrics.sh")
- `commands/roadmap.md` (min 140 lines, contains "spec/story")
- `scripts/engine/intensity-gate.sh` (min 50 lines, contains "roadmap")
- `scripts/verify/m011-p05-spec-metrics-counts.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p05-spec-metrics-skips-superseded.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p05-evaluate-doc-references-metrics.sh` (min 15 lines, contains "PASS")
- `scripts/verify/m011-p05-roadmap-doc-references-chunks.sh` (min 15 lines, contains "PASS")
- `scripts/verify/m011-p05-roadmap-doc-references-intensity.sh` (min 15 lines, contains "PASS")
- `scripts/verify/m011-p05-intensity-gate-roadmap-stage.sh` (min 15 lines, contains "PASS")
- `scripts/verify/m011-p05-spec-story-graph-emits-deps.sh` (min 25 lines, contains "PASS")
- `scripts/verify/m011-p05-spec-story-graph-delegates.sh` (min 15 lines, contains "PASS")
- `scripts/verify/m011-p05-demo-scenario.sh` (min 40 lines, contains "PASS")
- `scripts/verify/m011-p05-bash32-compat.sh` (min 10 lines, contains "PASS")
- `scripts/verify/m011-p05-commands-preserve-references.sh` (min 15 lines, contains "PASS")

### Key Links

- `commands/evaluate.md` → `scripts/state/spec-metrics.sh` (evaluate delegates metric counting to spec-metrics.sh when chunks are present)
- `commands/roadmap.md` → `scripts/dispatch/scope-filter.sh` (roadmap enumerates `spec/story` chunks via `scope-filter.sh --category spec/story --graph`)
- `commands/roadmap.md` → `scripts/knowledge/spec-story-graph.sh` (roadmap reads story-to-story dependency edges via spec-story-graph.sh)
- `commands/roadmap.md` → `scripts/engine/intensity-gate.sh` (roadmap gates interaction style via `intensity-gate.sh --stage roadmap`)
- `scripts/knowledge/spec-story-graph.sh` → `scripts/knowledge/traverse-graph.sh` (spec-story-graph.sh resolves `relates_to` edges via traverse-graph.sh rather than reimplementing SQL)
- `scripts/state/spec-metrics.sh` → `scripts/dispatch/scope-filter.sh` (spec-metrics uses `scope-filter.sh --category spec/<type> --graph` to enumerate chunks)

## Tasks

### T01: `spec-metrics.sh` + evaluate.md integration

See `tasks/T01-PLAN.md`.

### T02: `spec-story-graph.sh` + intensity-gate roadmap stage + roadmap.md integration

See `tasks/T02-PLAN.md`.

### T03: End-to-end demo-scenario + Bash 3.2 compat + command-reference-preservation regression

See `tasks/T03-PLAN.md`.

## Task Dependencies

```
T01 (no new deps beyond P02/P04)
T02 (no new deps beyond P02/P04; independent from T01)
T03 depends on T01 + T02
```

T01 delivers the evaluate-side wiring: a new `spec-metrics.sh` helper that counts ingested chunks by category (non-superseded tips only) plus edits to `commands/evaluate.md` documenting the chunks-first path with regex fallback. T02 delivers the roadmap-side wiring: a new `spec-story-graph.sh` helper that emits story-to-story `depends_on` edges via `traverse-graph.sh`, a new `roadmap` stage in `intensity-gate.sh` with Quick/Standard/Full substep rows, and edits to `commands/roadmap.md` describing chunks-first phase decomposition and intensity branching. T03 delivers the consolidated end-to-end demo and regression guards (Bash 3.2 compat across new scripts; evaluate/roadmap commands still reference their previously listed scripts).

T01 and T02 are independent and can run in parallel; T03 waits for both.

## Files Likely Touched

- `scripts/state/spec-metrics.sh` (create)
- `scripts/knowledge/spec-story-graph.sh` (create)
- `commands/evaluate.md` (modify)
- `commands/roadmap.md` (modify)
- `scripts/engine/intensity-gate.sh` (modify)
- `scripts/verify/m011-p05-spec-metrics-counts.sh` (create)
- `scripts/verify/m011-p05-spec-metrics-skips-superseded.sh` (create)
- `scripts/verify/m011-p05-evaluate-doc-references-metrics.sh` (create)
- `scripts/verify/m011-p05-roadmap-doc-references-chunks.sh` (create)
- `scripts/verify/m011-p05-roadmap-doc-references-intensity.sh` (create)
- `scripts/verify/m011-p05-intensity-gate-roadmap-stage.sh` (create)
- `scripts/verify/m011-p05-spec-story-graph-emits-deps.sh` (create)
- `scripts/verify/m011-p05-spec-story-graph-delegates.sh` (create)
- `scripts/verify/m011-p05-demo-scenario.sh` (create)
- `scripts/verify/m011-p05-bash32-compat.sh` (create)
- `scripts/verify/m011-p05-commands-preserve-references.sh` (create)
