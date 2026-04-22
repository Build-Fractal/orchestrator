---
schema_version: "1.0"
type: task-plan
task: "T06"
phase: "P01"
milestone: "M013"
name: "references/github-integration.md skeleton"
depends_on: ["T01", "T02", "T03", "T04", "T05"]
---

## Prerequisites

- T01 complete: `templates/github-integration-sidecar.json` exists.
- T02 complete: `scripts/integrations/github-status.sh` + `commands/github-status.md` exist.
- T03 complete: `.github/ISSUE_TEMPLATE/uat-bug.yml` exists.
- T04 complete: `rebuild-index.sh` emits `## Spec Chunks` section.
- T05 complete: `knowledge/spec/defect/README.md` + `scripts/integrations/uat-ingest.sh` exist.

Documentation convention: reference docs live in `references/` at repo root. Each is a standalone markdown file. A line is added to `references/README.md` to index the new doc. See `references/state-machine.md`, `references/file-formats.md` for shape reference (MEM009 Documentation-as-Verification, MEM010 Cross-Link Validation).

## Description

Author the initial skeleton of `references/github-integration.md` — the canonical reference document for M013's GitHub integration. P01 scope is the **skeleton only**: it covers what P01 ships. P02 and P03 extend the doc with sections on `init`/`sync`, marker format details, auth modes, sync modes, and conversus gate wiring. This task's deliverable stops at the P01 scope boundary and is explicitly marked as such in the doc body.

Skeleton sections (P01 scope):

1. **Overview** — one paragraph: what M013 is, opt-in projection, reversible by delete.
2. **Sidecar Config Schema** — documents `.orchestrator/integrations/github.json` top-level fields and per-item cache shape (from T01's `templates/github-integration-sidecar.json`).
3. **Pending-Sentinel Semantics** — documents the `"pending"` literal, how `github-status.sh` reports it, the M012/P04 `DEPLOY-RECORD.md` pattern this inherits, and the FR-11 reversibility-by-delete contract.
4. **`sync_mode` Enum** — `manual` / `on-transition` / `cron` with one-paragraph semantics for each (P01 describes the enum; runtime wiring is P03).
5. **`<!-- orchestrator-id: ... -->` Marker Format** — the literal marker shape, the `M###-P##[-T##]` ID format, and the idempotency contract (planning-level documentation — implementation is P02).
6. **UAT Ingestion Contract** — input fixture shape (the JSON fields T05 reads), output file shape (`SPEC-DEFECT-NNN.md` per T05's README), status enum, unknown-chunk flagging behavior.
7. **Knowledge-Layer Boundary (M013 vs. M020)** — restate the D014 / D013 ruling: `chunk_id` is pinned to existing `SPEC-*` frontmatter, no new ID format, no review-state/query-surface/clustering here. Links to `.orchestrator/DECISIONS.md` D013 and D014.
8. **Scope Boundary (P01 vs. P02 vs. P03)** — explicit table showing which sections of this doc P01 populates, and placeholder headers (with "TODO P02" / "TODO P03" notes) for future sections (full mapping table, `init` workflow, `sync` workflow, auth modes, conversus gate).

## Steps

### Step 1: Create `references/github-integration.md`

Write the skeleton per the section list above. Keep each section tight — this is a forward-compatible scaffold, not a full spec clone. Link every code path to its shipping artifact.

Outline content (fill out in implementation — exact prose is a judgment call, but every section listed above must be present with non-empty content):

```markdown
# GitHub Native Integration — Reference

**Milestone**: M013 (see `.orchestrator/milestones/M013/`)
**Spec**: `specs/023-github-native-integration/spec.md`
**Status**: P01 skeleton — P02 and P03 extend.

## Overview

M013 projects orchestrator state (milestones, phases, tasks, spec chunks, verification status) onto GitHub Issues, Milestones, and Projects v2 as an **opt-in** side surface. Orchestrator state on disk at `.orchestrator/` remains authoritative. GitHub is a projection, not a peer (Constitution XIV + `.orchestrator/DECISIONS.md` D007). The integration is **reversible**: deleting `.orchestrator/integrations/github.json` returns the orchestrator to pre-integration behavior (FR-11).

This reference is scoped to what M013 ships. P01 (this milestone phase) ships the scaffolding: sidecar schema, pending-sentinel semantics, UAT Bug Issue template, `orchestrator:github status` subcommand, an additive-emit pass in `scripts/knowledge/rebuild-index.sh`, and the `knowledge/spec/defect/SPEC-DEFECT-NNN.md` schema with its ingestion script. P02 and P03 add `init`, `sync`, auth modes, marker-based idempotency in practice, and the conversus pre-merge gate. Sections labeled "TODO P02" or "TODO P03" below are stubs reserved for those phases.

## Sidecar Config Schema

… (document every FR-6 top-level field with type, semantics, and example. Reference `templates/github-integration-sidecar.json`.) …

## Pending-Sentinel Semantics

… (the `"pending"` literal; what `github-status.sh` reports; the M012/P04 `DEPLOY-RECORD.md` first-deploy pattern this inherits; M007 no-dual-code-path discipline.) …

## `sync_mode` Enum

- **`manual`** (default) — …
- **`on-transition`** — …
- **`cron`** — …

## `<!-- orchestrator-id: ... -->` Marker Format

… (shape, format of IDs `M###-P##[-T##]`, idempotency contract; TODO P02 for REST search-by-marker implementation details.) …

## UAT Ingestion Contract

### Input Fixture Shape

… (JSON fields from T05; field-by-field table) …

### Output File Shape

… (reference `knowledge/spec/defect/README.md`; link-by-path) …

### Status Enum

… (four values; transitions) …

### Unknown Chunk Flagging

… (FR-10 + D014: never silently dropped) …

## Knowledge-Layer Boundary (M013 vs. M020)

… (restate D014 / D013 rulings; link to both DECISIONS entries; `chunk_id` pinning rule.) …

## Scope Boundary (P01 vs. P02 vs. P03)

| Section | P01 | P02 | P03 |
|---------|-----|-----|-----|
| Sidecar schema | ✓ (this doc) | extend `items` population | extend per-item status tracking |
| Pending sentinel | ✓ | reversed on successful init | — |
| `sync_mode` enum | ✓ (enum described) | operator selection at init | runtime wiring (hook, cron line) |
| Marker format | ✓ (format described) | REST search-by-marker impl | — |
| UAT ingestion | ✓ (offline fixture flow) | — | optional live `gh issue list` pull |
| Auth modes | — | TODO P02 | — |
| Full mapping table | — | TODO P02 | — |
| `init` workflow | — | TODO P02 | — |
| `sync` workflow | — | — | TODO P03 |
| Conversus gate | — | — | TODO P03 |
| FR-17 emission | — | — | TODO P03 |

## Referenced Artifacts (P01)

- `.orchestrator/integrations/github.json` — sidecar config (operator-owned, gitignored).
- `templates/github-integration-sidecar.json` — canonical schema template.
- `scripts/integrations/sidecar-init-pending.sh` — bootstrap helper.
- `scripts/integrations/github-status.sh` — read-only reporter.
- `commands/github-status.md` — subcommand definition.
- `.github/ISSUE_TEMPLATE/uat-bug.yml` — UAT Bug Issue Form.
- `scripts/knowledge/rebuild-index.sh` — widened with the `## Spec Chunks` section emit.
- `knowledge/spec/defect/README.md` — `SPEC-DEFECT-NNN` schema contract.
- `scripts/integrations/uat-ingest.sh` — fixture-driven ingester.

## Further Reading

- `specs/023-github-native-integration/spec.md` — feature specification.
- `.orchestrator/DECISIONS.md` — D007 (projection-not-peer), D013 (M020 promotion), D014 (conversus pressure-test rulings).
- `.orchestrator/memory/constitution.md` — Principles XIV (No Speculative Complexity) and XV (Surgical Precision) pinning the scope discipline here.
```

### Step 2: Update `references/README.md`

Add one entry to the index naming the new file with a one-line gloss. Keep alphabetical ordering consistent with existing entries.

Example addition:

```markdown
- [github-integration.md](github-integration.md) — M013 GitHub native integration: sidecar schema, UAT ingestion contract, marker format, `sync_mode` enum, Knowledge-Layer Boundary.
```

### Step 3: Create `scripts/verify/m013-p01-reference-skeleton.sh`

Gate asserts:
1. `references/github-integration.md` exists.
2. Contains each mandatory section heading: `## Overview`, `## Sidecar Config Schema`, `## Pending-Sentinel Semantics`, `` ## `sync_mode` Enum ``, `` ## `<!-- orchestrator-id: ... -->` Marker Format ``, `## UAT Ingestion Contract`, `## Knowledge-Layer Boundary (M013 vs. M020)`, `## Scope Boundary (P01 vs. P02 vs. P03)`.
3. References every P01 artifact path (grep for each path literal).
4. `references/README.md` contains an entry linking to `github-integration.md`.

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p01-reference-skeleton.sh
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="${REPO_ROOT}/references/github-integration.md"
README="${REPO_ROOT}/references/README.md"

fail_count=0
assert_ok() { if [ "$1" -eq 0 ]; then echo "PASS: $2"; else echo "FAIL: $2"; fail_count=$((fail_count + 1)); fi; }

[ -f "$DOC" ]; assert_ok $? "references/github-integration.md exists"

grep -q '^## Overview' "$DOC"; assert_ok $? "has Overview section"
grep -q '^## Sidecar Config Schema' "$DOC"; assert_ok $? "has Sidecar Config Schema section"
grep -q 'Pending-Sentinel Semantics' "$DOC"; assert_ok $? "has Pending-Sentinel Semantics section"
grep -q 'sync_mode' "$DOC"; assert_ok $? "has sync_mode Enum section"
grep -q 'orchestrator-id' "$DOC"; assert_ok $? "has orchestrator-id Marker Format section"
grep -q 'UAT Ingestion Contract' "$DOC"; assert_ok $? "has UAT Ingestion Contract section"
grep -q 'Knowledge-Layer Boundary' "$DOC"; assert_ok $? "has Knowledge-Layer Boundary section"
grep -q 'Scope Boundary' "$DOC"; assert_ok $? "has Scope Boundary section"

# Referenced artifact paths
for path in \
  ".orchestrator/integrations/github.json" \
  "templates/github-integration-sidecar.json" \
  "scripts/integrations/github-status.sh" \
  "commands/github-status.md" \
  ".github/ISSUE_TEMPLATE/uat-bug.yml" \
  "scripts/knowledge/rebuild-index.sh" \
  "knowledge/spec/defect/README.md" \
  "scripts/integrations/uat-ingest.sh"
do
  grep -qF "$path" "$DOC"; assert_ok $? "references path: ${path}"
done

# README index entry
[ -f "$README" ] && grep -q "github-integration.md" "$README"
assert_ok $? "references/README.md indexes github-integration.md"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m013-p01-reference-skeleton.sh"
  exit 0
fi
echo "FAIL: m013-p01-reference-skeleton.sh ($fail_count failures)"
exit 1
```

## Must-Haves

- `references/github-integration.md` exists with all eight required section headings.
- Every P01 shipping artifact is referenced by path.
- `references/README.md` gains a new entry linking to the doc.
- Scope Boundary table explicitly marks which sections P02/P03 extend (TODO markers for future phases).
- Verifier passes.

## Verification

- `bash scripts/verify/m013-p01-reference-skeleton.sh`

## Inputs

### From Previous Tasks

- `templates/github-integration-sidecar.json` (T01): source of the sidecar schema documented in § Sidecar Config Schema.
- `scripts/integrations/github-status.sh` + `commands/github-status.md` (T02): referenced in the Overview and in Referenced Artifacts list.
- `.github/ISSUE_TEMPLATE/uat-bug.yml` (T03): referenced in § UAT Ingestion Contract (Input Fixture Shape cross-links to the template's `spec_chunk_id` field).
- `scripts/knowledge/rebuild-index.sh` widening (T04): referenced in § UAT Ingestion Contract (chunk-ID resolution source).
- `knowledge/spec/defect/README.md` + `scripts/integrations/uat-ingest.sh` (T05): linked from § UAT Ingestion Contract. This doc does NOT duplicate the schema — it points at the schema README by path.

### From Disk (Pre-existing)

- `references/README.md` — the references index; append one line.
- `references/state-machine.md`, `references/file-formats.md` — reference examples of doc shape (MEM009).
- `.orchestrator/DECISIONS.md` — link source for D007 / D013 / D014.
- `specs/023-github-native-integration/spec.md` — link target for the feature spec.

## Constraints

- **P01 scope boundary**: sections covering `init`, `sync`, auth modes, full mapping table, and conversus gate wiring are scaffold stubs (TODO P02 / TODO P03) — do NOT flesh them out here. Overreach will be rejected by the verify gate (future tasks add those sections).
- **No duplicated schema content**: for `SPEC-DEFECT-NNN.md` schema, link to `knowledge/spec/defect/README.md` rather than restating the field table. For sidecar schema, describe fields inline (no other authoritative source yet).
- **Cross-references resolve**: every artifact path mentioned must exist on disk at the time of verify (this is why T06 depends on T01..T05). MEM010 Cross-Link Validation.
- **Bash 3.2** for the verify gate.
- **Single-script-file shape (AD-19)** for the verify gate.
- **MEM009 Documentation-as-Verification**: the presence of the doc is itself the verification that P01's conceptual scope is documented — the verifier checks structural completeness, not prose quality.

## Expected Output

- `references/github-integration.md` created (min 60 lines, 8 section headings, all artifact paths referenced).
- `references/README.md` updated (one new index entry).
- `scripts/verify/m013-p01-reference-skeleton.sh` created.
- `bash scripts/verify/m013-p01-reference-skeleton.sh` → `PASS: m013-p01-reference-skeleton.sh`, exit 0.
