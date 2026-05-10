---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M020"
goal: "Land knowledge-layer schema foundation: status: vocabulary, atomic frontmatter helper, minimum-viable graduate.sh, Jaccard helper + threshold/feature-vector validation against the live tree."
demo_sentence: "Running `bash scripts/knowledge/graduate.sh --rationale 'test' <entry-id>` flips an entry's `status:` from `candidate` to `graduated`, and `bash scripts/knowledge/lib/jaccard.sh validate knowledge/` writes a validation report at `.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md` confirming the 0.7 threshold + CON-5 feature vector against the live knowledge tree."
risk: "high"
depends_on: []
---

## Phase Summary

P01 is the foundation phase of M020 (Knowledge-Layer Maturation). It owns the
schema vocabulary (`status:` field), the atomic frontmatter helper that all
later phases (P03 graduate-workflow, P05 jaccard-clustering) consume, the
minimum-viable single-entry graduate flip, the Jaccard similarity helper used
by P05, and a validation report against the live `knowledge/**/MEM*.md` tree
that confirms (or adjusts) the 0.7 default threshold + CON-5 feature vector.

P01 explicitly does NOT own:
- cluster-aware graduate (`--cluster <id>` semantics, decision-history append,
  back-references) — that lands in P03
- query surface (`scripts/knowledge/query.sh`) — P02
- jaccard clustering integration into `consolidate` — P05
- preferences layer — P06
- JSONL observability emissions — emitted from P03/P05 mutation paths, not P01
- bulk migration of pre-M020 entries — explicitly out of scope per FR-10
  (incremental on-touch migration is the contract; P01 only establishes the
  convention)

## Schema-Evolution Authority (Cross-Cutting)

The `status:` field addition is a knowledge-schema evolution per FR-9. M020
holds exclusive schema authority over `knowledge/spec/**` and
`knowledge/**/MEM*.md` frontmatter. P01 lands the schema-evolution gate via:

1. A D-row in [`.orchestrator/DECISIONS.md`](../../../../decisions.md) (next available: **D024**)
   authorising the `status:` field + `decision_history:` + `archived_into:`
   vocabulary that P03 will fill in.
2. A schema-evolution note: [`knowledge/conventions/MEM031.md`](../../../../knowledge/conventions/MEM031.md) documenting the
   `status:` field vocabulary, default semantics for pre-M020 entries
   (treated as `graduated`), and the closed enum `{candidate, graduated,
   archived}`.

Both land in T01 before any helper code or graduate.sh writes touch the
schema.

## Must-Haves

### Truths

- `scripts/knowledge/graduate.sh` accepts `--rationale <text>` and a single
  entry-ID positional argument and flips the entry's `status:` frontmatter
  field from `candidate` to `graduated`.
  - Check: `bash scripts/verify/m020-p01-graduate-single-entry.sh`

- `scripts/knowledge/lib/frontmatter.sh` exposes `fm_read_status` /
  `fm_write_status` / `fm_append_decision_history` / `fm_write_archived_into`
  functions that perform atomic writes (write-to-tempfile + `mv`).
  - Check: `bash scripts/verify/m020-p01-frontmatter-helper-contract.sh`

- `scripts/knowledge/lib/jaccard.sh` exposes a `pairwise_jaccard <file-a>
  <file-b>` subcommand that computes Jaccard similarity on the CON-5 feature
  vector (frontmatter `title` + `topic` + `tags[]` + first-paragraph words
  capped at 50 tokens) and emits `similarity=<0.0-1.0>` on stdout.
  - Check: `bash scripts/verify/m020-p01-jaccard-pairwise-contract.sh`

- `scripts/knowledge/lib/jaccard.sh validate <knowledge-root>` walks the live
  tree, computes pairwise similarities, and writes
  [`.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md`](../../../../milestones/M020/phases/P01/jaccard-validation-report.md) with
  threshold-recommendation + cluster-density observations.
  - Check: `bash scripts/verify/m020-p01-jaccard-validation-report.sh`

- [`knowledge/conventions/MEM031.md`](../../../../knowledge/conventions/MEM031.md) documents the `status:` vocabulary as a
  closed enum `{candidate, graduated, archived}` with pre-M020 default
  `graduated`.
  - Check: `bash scripts/verify/m020-p01-mem031-vocabulary.sh`

- A new D-row D024 in [`.orchestrator/DECISIONS.md`](../../../../decisions.md) authorises the `status:`
  field + paired `decision_history:` + `archived_into:` vocabulary as M020
  schema evolution.
  - Check: `bash scripts/verify/m020-p01-d024-row.sh`

- The graduate.sh write path is side-effect-bounded: it writes only the
  target entry file (no index rewrites, no neighbouring-entry mutation in
  the single-entry path). P03 will extend with cluster + decision_history.
  - Check: `bash scripts/verify/m020-p01-graduate-side-effect-scope.sh`

- `knowledge/**/MEM*.md` migration is incremental (FR-10): the helper treats
  missing `status:` as `graduated` and writes the field on next touch. P01
  does NOT bulk-rewrite the tree.
  - Check: `bash scripts/verify/m020-p01-migration-incremental.sh`

### Artifacts

- `scripts/knowledge/graduate.sh` (min 60 lines, contains "--rationale")
- `scripts/knowledge/lib/frontmatter.sh` (min 80 lines, contains "fm_write_status")
- `scripts/knowledge/lib/jaccard.sh` (min 100 lines, contains "pairwise_jaccard")
- [`knowledge/conventions/MEM031.md`](../../../../knowledge/conventions/MEM031.md) (min 25 lines, contains "status:")
- [`.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md`](../../../../milestones/M020/phases/P01/jaccard-validation-report.md) (min 30 lines, contains "threshold")
- [`.orchestrator/DECISIONS.md`](../../../../decisions.md) (modify, contains "D024")

### Key Links

- `scripts/knowledge/graduate.sh` → `scripts/knowledge/lib/frontmatter.sh` (sources the helper for atomic writes)
- `scripts/knowledge/lib/jaccard.sh` → [`knowledge/conventions/MEM031.md`](../../../../knowledge/conventions/MEM031.md) (validation report references the schema-evolution note)
- [`knowledge/conventions/MEM031.md`](../../../../knowledge/conventions/MEM031.md) → [`.orchestrator/DECISIONS.md`](../../../../decisions.md) (cites D024 as authorising decision)

## Boundary Map

### Produces

- `scripts/knowledge/graduate.sh` (minimum-viable per A-1: `--rationale <text>` flag, single-entry candidate→graduated flip, atomic frontmatter write via `lib/frontmatter.sh`)
- `scripts/knowledge/lib/jaccard.sh` (pairwise Jaccard similarity helper consumed by P05; CON-5 feature vector; `validate` subcommand for the demo-sentence report)
- `scripts/knowledge/lib/frontmatter.sh` (atomic frontmatter read/write helper used by P03/P05; covers `status:`, `decision_history:`, `archived_into:` field vocabulary)
- `knowledge/**/MEM*.md` `status:` field per FR-1 + FR-10 — convention established; bulk migration NOT performed; entries gain field on next touch
- [`.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md`](../../../../milestones/M020/phases/P01/jaccard-validation-report.md) (threshold + feature-vector validation against live tree; may adjust 0.7 default)
- [`knowledge/conventions/MEM031.md`](../../../../knowledge/conventions/MEM031.md) (schema-evolution note documenting the `status:` field vocabulary)
- [`.orchestrator/DECISIONS.md`](../../../../decisions.md) D024 (schema-authority decision row)
- `scripts/verify/m020-p01-*.sh` (the eight `Check:` script files invoked by the must-haves above)

### Consumes

- existing `knowledge/**/MEM*.md` tree (read-only validation in T05)
- `.orchestrator/memory/constitution.md` (Principle VI + Principle XV gates for schema evolution)
- `scripts/knowledge/lib/detail-utils.sh` (existing `fm_field` reader; `lib/frontmatter.sh` may layer on top, not duplicate)
- `scripts/knowledge/lib/index-utils.sh` (existing `get_project_root`)

## Tasks

### T01: Schema-evolution gate — D024 + MEM031

Land the schema-authority gate BEFORE any code touches the schema. Adds a
D-row D024 to [`.orchestrator/DECISIONS.md`](../../../../decisions.md) and creates
[`knowledge/conventions/MEM031.md`](../../../../knowledge/conventions/MEM031.md) documenting the `status:` field vocabulary.

See `tasks/T01-schema-evolution-gate-PLAN.md`.

### T02: Atomic frontmatter helper

Create `scripts/knowledge/lib/frontmatter.sh` exposing atomic read/write
functions for `status:`, `decision_history:`, and `archived_into:` fields.
Atomic = write-to-tempfile + `mv` (single inode-replace op). Bash 3.2 safe.

See `tasks/T02-frontmatter-helper-PLAN.md`.

### T03: Minimum-viable graduate.sh

Create `scripts/knowledge/graduate.sh` accepting `--rationale <text>` and a
single positional entry-ID. Flips `status:` `candidate` → `graduated` via the
T02 helper. Idempotent (no-op + diagnostic on already-graduated entries).
Single-entry only — `--cluster` semantics are P03's scope.

See `tasks/T03-graduate-script-PLAN.md`.

### T04: Jaccard helper

Create `scripts/knowledge/lib/jaccard.sh` exposing `pairwise_jaccard <a>
<b>` (CON-5 feature vector: `title` + `topic` + `tags[]` + first-paragraph
words capped at 50) and a `validate <knowledge-root>` subcommand stub that
T05 fills in.

See `tasks/T04-jaccard-helper-PLAN.md`.

### T05: Validation report + demo verification

Run `bash scripts/knowledge/lib/jaccard.sh validate knowledge/` against the
live tree, write the report to
[`.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md`](../../../../milestones/M020/phases/P01/jaccard-validation-report.md), and
confirm the demo sentence end-to-end (graduate.sh flip on a fixture entry +
report exists).

See `tasks/T05-jaccard-validation-PLAN.md`.

## Task Dependencies

```
T01 (schema-evolution gate) → T02 (frontmatter helper) → T03 (graduate.sh)
                                                             ↓
                              T04 (jaccard helper) ──────→ T05 (validation report + demo)
```

T01 must land first (schema-authority gate). T02 unblocks T03 (graduate
sources the helper). T04 can run in parallel with T02/T03 (independent
file). T05 consumes T03 + T04.

## Risk Notes

- **Schema-authority slip**: highest risk. If T02 or T03 lands fields not
  enumerated in T01's MEM031 vocabulary, the schema-authority invariant
  (FR-9) is violated and downstream milestones ([M024](../../../../milestones/M024/index.md), [M019](../../../../milestones/M019/index.md) Tier 2+3) inherit
  a non-deterministic contract. Mitigation: T01 lands first; T02/T03's
  `Check:` scripts assert no foreign fields appear in modified frontmatter.

- **Atomic-write correctness**: `lib/frontmatter.sh` must write-to-tempfile
  + `mv` to preserve crash-safety (CON-4 byte-equivalence for unrelated
  fields). A naive `sed -i` mid-write that crashes leaves the file
  half-written. Mitigation: T02 contract test exercises a deliberate-fail
  midway and asserts the original file is unchanged.

- **Jaccard threshold regression**: the spec assumes 0.7 (A-5). Live-tree
  validation in T05 may reveal 0.7 is too tight (no clusters surface) or
  too loose (everything clusters). The report MUST recommend a threshold
  even if it is the default 0.7; a "no-recommendation" report fails the
  demo sentence.

- **Bash 3.2 + AD-19 shape compliance**: every `Check:` command in this
  plan is a single-script-file invocation per AD-19. No inline
  `$(grep | wc)`, no `( source && fn )`, no `bash -c`-with-pipe.

- **Read-only-during-dispatch invariant** (cross-cutting): graduate.sh and
  the frontmatter helper are operator-invoked, never dispatch-invoked. P01
  does NOT add any dispatch-callable surfaces (that's P02's query.sh).

## Verification Commands

Phase-level mechanical verification at completion:

```bash
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M020/phases/P01
bash scripts/verify/m020-p01-graduate-single-entry.sh
bash scripts/verify/m020-p01-frontmatter-helper-contract.sh
bash scripts/verify/m020-p01-jaccard-pairwise-contract.sh
bash scripts/verify/m020-p01-jaccard-validation-report.sh
bash scripts/verify/m020-p01-mem031-vocabulary.sh
bash scripts/verify/m020-p01-d024-row.sh
bash scripts/verify/m020-p01-graduate-side-effect-scope.sh
bash scripts/verify/m020-p01-migration-incremental.sh
```

The demo-sentence verification is bundled into
`scripts/verify/m020-p01-jaccard-validation-report.sh` (it asserts both the
report exists at the expected path AND the report content names the
threshold + feature vector). The graduate-flip half of the demo sentence is
covered by `m020-p01-graduate-single-entry.sh`.

## Files Likely Touched

- scripts/knowledge/graduate.sh (create)
- scripts/knowledge/lib/frontmatter.sh (create)
- scripts/knowledge/lib/jaccard.sh (create)
- [knowledge/conventions/MEM031.md](../../../../knowledge/conventions/MEM031.md) (create)
- [.orchestrator/DECISIONS.md](../../../../decisions.md) (modify — append D024 row)
- [.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md](../../../../milestones/M020/phases/P01/jaccard-validation-report.md) (create)
- scripts/verify/m020-p01-graduate-single-entry.sh (create)
- scripts/verify/m020-p01-frontmatter-helper-contract.sh (create)
- scripts/verify/m020-p01-jaccard-pairwise-contract.sh (create)
- scripts/verify/m020-p01-jaccard-validation-report.sh (create)
- scripts/verify/m020-p01-mem031-vocabulary.sh (create)
- scripts/verify/m020-p01-d024-row.sh (create)
- scripts/verify/m020-p01-graduate-side-effect-scope.sh (create)
- scripts/verify/m020-p01-migration-incremental.sh (create)
- KNOWLEDGE-INDEX.md (modify — register MEM031)
- tests/fixtures/m020-p01/ (create — fixture knowledge tree for graduate-flip and migration-incremental checks)
