---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M013"
goal: "Ship the M013 Minimal Slice: sidecar config scaffold + pending-sentinel semantics, `orchestrator:github status` subcommand, UAT Bug Issue template, additive-emit pass in `rebuild-index.sh` (flat `{chunk_id, title, phase_id}` list pinned to existing `SPEC-*` frontmatter), `knowledge/spec/defect/SPEC-DEFECT-NNN.md` schema + `scripts/integrations/uat-ingest.sh`, and a `references/github-integration.md` skeleton — closing the dogfood UAT→defect-knowledge loop without any remote `gh` writes."
demo_sentence: "A developer runs `bash scripts/integrations/github-status.sh` on a fresh clone and it reports `STATUS: absent`; after `bash scripts/knowledge/rebuild-index.sh` the repo-root `KNOWLEDGE-INDEX.md` gains a `## Spec Chunks` section listing `SPEC-US-001`, `SPEC-AC-001`, … with titles; a maintainer drops a valid UAT bug fixture (referencing `SPEC-US-001`) under `tests/fixtures/m013-p01/uat-bug-issues/` and runs `bash scripts/integrations/uat-ingest.sh --source tests/fixtures/m013-p01/uat-bug-issues/`, producing `knowledge/spec/defect/SPEC-DEFECT-001.md` with frontmatter edges `{chunk: SPEC-US-001, phase: <empty>, tests: []}` and `status: open`; a second fixture with an unknown chunk ID produces `SPEC-DEFECT-002.md` flagged `chunk-lookup-failed` (never silently dropped); `bash scripts/verify/m013-p01-phase-suite.sh` exits 0 across all seven gates."
risk: "medium"
depends_on: []
---

## Must-Haves

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     Every Check command is a single-invocation script-file shape — no inline
     compound bash, no plain subshells, no $() containing pipes, no process
     substitution. All M013/P01 verification logic lives inside the
     scripts/verify/m013-p01-*.sh files; the Check commands here invoke them. -->

### Truths

- `.orchestrator/integrations/github.json` is written on first `status` invocation against a repo without a sidecar only if `--init-pending` is passed; otherwise `status` reports `absent`. When present with any top-level field holding the literal `pending` sentinel, `status` reports `pending-operator-complete` — per FR-6 this is an operator-handoff state, not graceful degradation.
  - Check: `bash scripts/verify/m013-p01-sidecar-schema.sh`

- `scripts/integrations/github-status.sh` prints exactly one of three lines to stdout (`STATUS: absent`, `STATUS: pending-operator-complete`, `STATUS: configured`) and reports `last_sync`, `cache_items`, and `sync_mode` when configured. It makes zero `gh` subprocess calls (this phase is scaffolding — no remote reads) and exits 0 on `absent`/`configured`, exits 1 on any malformed JSON or schema mismatch.
  - Check: `bash scripts/verify/m013-p01-github-status.sh`

- `commands/github-status.md` follows the MEM012 command-file structure (YAML frontmatter with `description`, Title, Prerequisites, Core Workflow, Output, Idempotency, Error Handling, Referenced Scripts) and names `scripts/integrations/github-status.sh` in its Referenced Scripts section.
  - Check: `bash scripts/verify/m013-p01-github-status-command.sh`

- `.github/ISSUE_TEMPLATE/uat-bug.yml` is a valid GitHub Issue Forms YAML document with required `Spec Chunk ID` input (`id: spec_chunk_id`, `type: input`, `validations.required: true`) and a `How to find your Spec Chunk ID` markdown block pointing to the repo-root `KNOWLEDGE-INDEX.md` Spec Chunks section.
  - Check: `bash scripts/verify/m013-p01-uat-template.sh`

- `bash scripts/knowledge/rebuild-index.sh` now emits a `## Spec Chunks` section in repo-root `KNOWLEDGE-INDEX.md` containing one line per existing `knowledge/spec/**/SPEC-*.md` file in the format `<chunk_id> | <title> | <phase_id>` where `chunk_id` is taken verbatim from the file's `id:` frontmatter field, `title` from the first `# ` heading or `name` frontmatter, and `phase_id` from a `phase_id:` frontmatter field when present (empty string otherwise). The existing `| id | scope_tags | category | ... |` pipe-table section above remains byte-identical for existing consumers (additive-only — FR-9 + D014 pressure-test ruling).
  - Check: `bash scripts/verify/m013-p01-rebuild-index-additive.sh`

- `knowledge/spec/defect/` exists as a directory and contains `README.md` documenting the `SPEC-DEFECT-NNN.md` schema: required frontmatter fields `id`, `scope_tags`, `category: spec/defect`, `status` (enum: `open`, `chunk-lookup-failed`, `triaged`, `closed`), `chunk` (existing `SPEC-*` id or empty), `phase` (orchestrator `M###-P##` id or empty), `tests` (YAML list), `github_issue_number` (integer or null), `created_at`. Schema is forward-compatible with [M020](../../../../milestones/M020/index.md) (Knowledge-Layer Boundary) — no review-state lifecycle, no query-surface, no clustering authored here.
  - Check: `bash scripts/verify/m013-p01-defect-schema.sh`

- `scripts/integrations/uat-ingest.sh` reads UAT-bug Issue fixtures from a `--source <dir>` path (each file a markdown or JSON payload carrying `spec_chunk_id`, `title`, `body`, `issue_number` fields), resolves each `spec_chunk_id` against the Spec Chunks section of `KNOWLEDGE-INDEX.md`, and writes one `knowledge/spec/defect/SPEC-DEFECT-NNN.md` per input fixture. Valid chunk IDs produce `status: open` with `chunk: <id>`. Unknown chunk IDs produce `status: chunk-lookup-failed` with `chunk: ""` — never silently dropped (FR-10, D014 ruling on unknown-chunk flagging). `NNN` is the next free integer (`ls` existing + 1). Re-running with the same fixtures is idempotent: `issue_number` match → skip + increment `skipped=` counter.
  - Check: `bash scripts/verify/m013-p01-uat-ingest.sh`

- `references/github-integration.md` exists as a skeleton documenting: the sidecar config shape (`schema_version`, `repo_slug`, `project_v2_id`, `sync_mode` enum `manual|on-transition|cron`, `items.<orchestrator-id>` per-item cache fields), the `<!-- orchestrator-id: <id> -->` marker format with one example, the pending-sentinel semantics (inherit from M012/P04 `DEPLOY-RECORD.md` pattern), and the UAT ingestion contract (input fixture shape → `SPEC-DEFECT-NNN.md` output). Follows the `references/` README-cross-linked doc pattern (MEM009 documentation-as-verification).
  - Check: `bash scripts/verify/m013-p01-reference-skeleton.sh`

- Every P01-touched and P01-created `.sh` file is Bash 3.2 compatible (no `declare -A`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`) and passes `scripts/verify/anti-pattern-lint.sh` (Constitution IX, Constitution XV, SC-6).
  - Check: `bash scripts/verify/m013-p01-bash32-compat.sh`

- `bash scripts/verify/m013-p01-phase-suite.sh` orchestrates all nine P01 gates (sidecar-schema, github-status, github-status-command, uat-template, rebuild-index-additive, defect-schema, uat-ingest, reference-skeleton, bash32-compat) and exits 0 on green, non-zero with a per-gate breakdown otherwise.
  - Check: `bash scripts/verify/m013-p01-phase-suite.sh`

### Artifacts

- `.orchestrator/integrations/github.json` (min 10 lines, contains "schema_version") — written only on explicit init-pending invocation; initial shape is a `pending`-sentinel block per FR-6
- `.github/ISSUE_TEMPLATE/uat-bug.yml` (min 30 lines, contains "spec_chunk_id")
- `commands/github-status.md` (min 40 lines, contains "github-status.sh")
- `scripts/integrations/github-status.sh` (min 60 lines, contains "pending-operator-complete")
- `scripts/integrations/uat-ingest.sh` (min 100 lines, contains "chunk-lookup-failed")
- `scripts/knowledge/rebuild-index.sh` (min 120 lines, contains "Spec Chunks") — modify-in-place; the additive-emit section appended to the existing scanner
- `knowledge/spec/defect/README.md` (min 40 lines, contains "SPEC-DEFECT-NNN")
- `references/github-integration.md` (min 60 lines, contains "orchestrator-id") — skeleton only; P02+P03 extend
- `scripts/verify/m013-p01-sidecar-schema.sh` (min 30 lines, contains "pending")
- `scripts/verify/m013-p01-github-status.sh` (min 30 lines, contains "STATUS: absent")
- `scripts/verify/m013-p01-github-status-command.sh` (min 20 lines, contains "Referenced Scripts")
- `scripts/verify/m013-p01-uat-template.sh` (min 20 lines, contains "spec_chunk_id")
- `scripts/verify/m013-p01-rebuild-index-additive.sh` (min 40 lines, contains "Spec Chunks")
- `scripts/verify/m013-p01-defect-schema.sh` (min 30 lines, contains "chunk-lookup-failed")
- `scripts/verify/m013-p01-uat-ingest.sh` (min 50 lines, contains "SPEC-DEFECT")
- `scripts/verify/m013-p01-reference-skeleton.sh` (min 20 lines, contains "orchestrator-id")
- `scripts/verify/m013-p01-bash32-compat.sh` (min 30 lines, contains "declare -A")
- `scripts/verify/m013-p01-phase-suite.sh` (min 40 lines, contains "m013-p01")
- `tests/fixtures/m013-p01/` (directory with `uat-bug-issues/` subdir containing at least one valid-chunk fixture and one unknown-chunk fixture, plus a `knowledge-index-expected.md` snapshot for the additive-emit gate)

### Key Links

- `commands/github-status.md` → `scripts/integrations/github-status.sh` (Referenced Scripts section names the script by path, per MEM012)
- `scripts/integrations/github-status.sh` → `.orchestrator/integrations/github.json` (reads the sidecar path)
- `scripts/integrations/uat-ingest.sh` → `knowledge/spec/defect/` (writes `SPEC-DEFECT-NNN.md` into this directory)
- `scripts/integrations/uat-ingest.sh` → `KNOWLEDGE-INDEX.md` (resolves `spec_chunk_id` against the Spec Chunks section)
- `.github/ISSUE_TEMPLATE/uat-bug.yml` → `KNOWLEDGE-INDEX.md` (template's "How to find your Spec Chunk ID" block points here)
- `references/github-integration.md` → `.orchestrator/integrations/github.json` (docs the sidecar schema)
- `references/github-integration.md` → `.github/ISSUE_TEMPLATE/uat-bug.yml` (docs the UAT template + autocomplete source)
- `references/github-integration.md` → `scripts/integrations/uat-ingest.sh` (docs the ingestion contract)
- `references/README.md` → `references/github-integration.md` (new entry in the references index per MEM009)
- `scripts/verify/m013-p01-phase-suite.sh` → `scripts/verify/m013-p01-sidecar-schema.sh` (orchestrated gate)
- `scripts/verify/m013-p01-phase-suite.sh` → `scripts/verify/m013-p01-github-status.sh` (orchestrated gate)
- `scripts/verify/m013-p01-phase-suite.sh` → `scripts/verify/m013-p01-github-status-command.sh` (orchestrated gate)
- `scripts/verify/m013-p01-phase-suite.sh` → `scripts/verify/m013-p01-uat-template.sh` (orchestrated gate)
- `scripts/verify/m013-p01-phase-suite.sh` → `scripts/verify/m013-p01-rebuild-index-additive.sh` (orchestrated gate)
- `scripts/verify/m013-p01-phase-suite.sh` → `scripts/verify/m013-p01-defect-schema.sh` (orchestrated gate)
- `scripts/verify/m013-p01-phase-suite.sh` → `scripts/verify/m013-p01-uat-ingest.sh` (orchestrated gate)
- `scripts/verify/m013-p01-phase-suite.sh` → `scripts/verify/m013-p01-reference-skeleton.sh` (orchestrated gate)
- `scripts/verify/m013-p01-phase-suite.sh` → `scripts/verify/m013-p01-bash32-compat.sh` (orchestrated gate)

## Tasks

### T01: Sidecar schema + `.orchestrator/integrations/github.json` scaffolding + pending-sentinel semantics

See `tasks/T01-PLAN.md`.

### T02: `scripts/integrations/github-status.sh` + `commands/github-status.md`

See `tasks/T02-PLAN.md`.

### T03: `.github/ISSUE_TEMPLATE/uat-bug.yml` UAT Bug Issue Form + autocomplete-source pointer

See `tasks/T03-PLAN.md`.

### T04: `scripts/knowledge/rebuild-index.sh` additive-emit pass — flat `{chunk_id, title, phase_id}` Spec Chunks section

See `tasks/T04-PLAN.md`.

### T05: `knowledge/spec/defect/` schema + `scripts/integrations/uat-ingest.sh`

See `tasks/T05-PLAN.md`.

### T06: `references/github-integration.md` skeleton

See `tasks/T06-PLAN.md`.

### T07: Phase verification suite — nine gates + phase-suite orchestrator

See `tasks/T07-PLAN.md`.

## Task Dependencies

```
T01 ──► T02 ──┐
              │
T03 ──────────┤
              │
T04 ──► T05 ──┤
              │
T06 ──────────┴──► T07
```

T01 establishes the sidecar schema contract (consumed by T02 via the `status` reader, and by T06 via the docs). T02 ships the `status` subcommand and its command markdown. T03 is independent — the UAT template references the Spec Chunks section in `KNOWLEDGE-INDEX.md` by filename only (the section is produced by T04, but the template file itself does not `source` or parse T04's output). T04 widens `rebuild-index.sh` additively — this must run before T05 because `uat-ingest.sh` resolves chunk IDs against the Spec Chunks section. T05 ships the defect schema README + ingestion script. T06 authors the references skeleton referencing all of T01/T02/T03/T04/T05 artifacts. T07 closes the suite: one gate per produced artifact plus the bash-3.2 compat + phase-suite orchestrator. Dispatch may execute T01/T03/T04/T06 in parallel subject to their individual dependencies; T02 depends on T01, T05 depends on T04, T07 depends on all predecessors.

## Files Likely Touched

- `.orchestrator/integrations/` (create — directory)
- `.orchestrator/integrations/github.json` (create — optional; written only on explicit `--init-pending`; git-tracked template OR gitignored depending on T01 decision — see T01 constraints)
- `.github/ISSUE_TEMPLATE/` (create — directory)
- `.github/ISSUE_TEMPLATE/uat-bug.yml` (create)
- `commands/github-status.md` (create)
- `scripts/integrations/` (create — directory)
- `scripts/integrations/github-status.sh` (create)
- `scripts/integrations/uat-ingest.sh` (create)
- `scripts/knowledge/rebuild-index.sh` (modify — append additive Spec Chunks emit pass; existing pipe-table section stays byte-identical)
- `knowledge/spec/defect/` (create — directory)
- `knowledge/spec/defect/README.md` (create)
- `references/github-integration.md` (create)
- `references/README.md` (modify — add entry linking to `github-integration.md`)
- `scripts/verify/m013-p01-sidecar-schema.sh` (create)
- `scripts/verify/m013-p01-github-status.sh` (create)
- `scripts/verify/m013-p01-github-status-command.sh` (create)
- `scripts/verify/m013-p01-uat-template.sh` (create)
- `scripts/verify/m013-p01-rebuild-index-additive.sh` (create)
- `scripts/verify/m013-p01-defect-schema.sh` (create)
- `scripts/verify/m013-p01-uat-ingest.sh` (create)
- `scripts/verify/m013-p01-reference-skeleton.sh` (create)
- `scripts/verify/m013-p01-bash32-compat.sh` (create)
- `scripts/verify/m013-p01-phase-suite.sh` (create)
- `tests/fixtures/m013-p01/` (create — directory tree)
- `tests/fixtures/m013-p01/uat-bug-issues/valid-chunk.json` (create — fixture: well-formed UAT bug referencing `SPEC-US-001`)
- `tests/fixtures/m013-p01/uat-bug-issues/unknown-chunk.json` (create — fixture: UAT bug referencing `SPEC-NOEXIST-999`)
- `tests/fixtures/m013-p01/knowledge-index-expected.md` (create — snapshot for the rebuild-index additive gate)
