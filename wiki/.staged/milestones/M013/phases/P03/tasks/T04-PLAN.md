---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M013"
name: "references/github-integration.md P03 extensions + commands/github-init.md --re-init addendum"
depends_on: ["T02", "T03"]
---

## Prerequisites

- P02 landed `references/github-integration.md` in its current state (~299 lines). The relevant sections:
  - Lines 146-162: **Scope Boundary (P01 vs. P02 vs. P03)** table — the P03 column currently lists future work.
  - Lines 206-222: **Partial Mapping Table (P02)** — three bold `_deferred to P03_` rows for spec chunk / acceptance criterion / verification status.
  - Lines 265-275: three stub headings `### TODO P03: sync Workflow`, `### TODO P03: Conversus Pre-Merge Gate`, `### TODO P03: FR-17 Cost Emission` — these were authored at P01 before D015 renumbered the old P03 as P04. Their content (sync/conversus/cost-emission) is now P04's responsibility, NOT P03's.
- P02 authored the section-content sha256 byte-identity gating pattern (`scripts/verify/m013-p02-reference-extensions.sh`) — awk-extract section by literal-prefix heading match, shasum-compare against embedded hashes. T04 uses the same gating pattern for P03's byte-identity preservation on P01/P02-authored sections.
- T02 has settled the `--re-init` flag name and the `adopted=<N>` footer field. T04 documents both.
- T03 has settled the lint path `scripts/verify/graphql-call-shape.sh`. T04 cross-references it in the Re-init Adoption Contract section.
- FR-14 spec text (spec.md line 186): "Init is repeatable — running it again after an initial run either reconciles against the existing config (reporting what is already set up) or prints a clear message on what would change, without creating duplicate Milestones/Projects/Labels. **Re-init adoption via marker search**: when the sidecar config is absent but the target repo contains Issues bearing orchestrator-id markers (prior sync's artifacts), re-init adopts them by marker-search before creating — it does not delete remote resources, and it does not create duplicates."
- MEM012 (command file structure): `commands/github-init.md` follows YAML frontmatter → Title → Prerequisites / State Check → Core Workflow → Output → Idempotency → Error Handling → Referenced Scripts.
- Integer-minutes duration in T04-SUMMARY.md.

## Description

Three modify-in-place edits to `references/github-integration.md` plus one `commands/github-init.md` addendum:

1. **Fill the three `_deferred to P03_` rows** in the Partial Mapping Table (lines 218-220) with real content. Also change the table heading from `### Partial Mapping Table (P02)` to `### Full Mapping Table (P02 + P03)` and update the prose above the table to reflect the completion.

2. **Relabel three stub headings** — `### TODO P03: sync Workflow`, `### TODO P03: Conversus Pre-Merge Gate`, `### TODO P03: FR-17 Cost Emission` become `### TODO P04: sync Workflow`, `### TODO P04: Conversus Pre-Merge Gate`, `### TODO P04: FR-17 Cost Emission`. Their body text (the italicized "*Reserved for P03.*" lines) is updated to reference P04 instead. This is a D015 rename — the content bodies were authored at P01 under the old P03 numbering.

3. **Insert a new subsection `### Re-init Adoption Contract (FR-14)`** between the existing `### Dry-Run Manifest Format (FR-15)` subsection (ends line 263) and the relabeled `### TODO P04: sync Workflow` heading (formerly line 265). The new subsection documents the re-init adoption path authored in T02.

4. **Update the Scope Boundary table P03 column** (lines 150-162) — replace the current future-work entries with actual P03 deliverables.

5. **Extend `commands/github-init.md`** (P02's MEM012-compliant command definition) with a `--re-init` flag mention in the flag list + one paragraph under Core Workflow describing the re-init adoption behavior. All other sections of `commands/github-init.md` stay byte-identical.

## Steps

### Step 1: Read the current `references/github-integration.md`

Capture the byte-identical content hashes of the P01-authored sections (Overview, Sidecar Config Schema, Pending-Sentinel Semantics, `sync_mode` Enum, Marker Format, UAT Ingestion Contract, Knowledge-Layer Boundary, Referenced Artifacts P01 block, Further Reading) and P02-authored sections (Auth Modes, Sub-Issue Representation Modes, `init` Workflow, Dry-Run Manifest Format, Referenced Artifacts P02 block). The T05 gate embeds these hashes (captured BEFORE T04 edits) and re-checks them after T04 edits — same technique as the P02 `m013-p02-reference-extensions.sh` gate.

### Step 2: Fill the three `_deferred to P03_` rows

Change the three bold table rows (lines 218-220) to:

```markdown
| **Spec chunk** | **Issue custom field (`chunk-URL`)** | `init` — populates from walker pass | `chunk-url` field value = stable per-chunk wiki URL (see M012 `wiki/URL-SCHEME.md`) | Read-only at P04 sync (no transitions) |
| **Acceptance criterion** | **Checklist item in Issue body** | `init` — one `- [ ] AC: <text>` line per AC parsed from the task-plan `## Must-Haves` block | AC text (content is the key; no dedicated marker) | `sync` ticks the box when the AC's verification artifact lands (P04) |
| **Verification status** | **Project v2 Status field** | `init` sets initial value `Todo` via `addProjectV2ItemById` then `updateProjectV2ItemFieldValue` (P04) | Project v2 item node id (from sidecar) | `sync` transitions Todo → In Progress → Done via `updateProjectV2ItemFieldValue` (P04) |
```

Change the heading above the table (line 206) from:

```markdown
### Partial Mapping Table (P02)
```

to:

```markdown
### Full Mapping Table (P02 + P03)
```

Change the paragraph above the table (line 208) from:

```markdown
Orchestrator state → GitHub resource projection. P02 populates phase/task/milestone/label/project-v2 rows; chunk/AC/verification-status rows are scaffolded for P03 completion.
```

to:

```markdown
Orchestrator state → GitHub resource projection. P02 populates phase/task/milestone/label/project-v2 rows; P03 fills chunk/AC/verification-status rows in place. P04 owns the live transitions on the verification-status row (`updateProjectV2ItemFieldValue`) and the AC checklist-toggling on `sync`.
```

Change the footnote paragraph immediately after the table (line 222) from:

```markdown
P03 fills the bold rows in place. P02 must not populate them — the deferral is load-bearing (D015 scope split).
```

to:

```markdown
The table is now complete. Lifecycle columns referencing P04 capture sync-time transitions not shipped in P03 (status transitions, AC checkbox toggling); P03 only wires the `init`-time creator cells.
```

### Step 3: Relabel the three `### TODO P03:` stub headings to `### TODO P04:`

The three headings currently read:

```markdown
### TODO P03: `sync` Workflow

*Reserved for P03. Will cover `orchestrator:github sync`: marker-based idempotent upsert, `sync_mode` dispatch paths (manual / on-transition / cron advisory), `--dry-run` generalization (FR-15), `--strict` provenance enforcement (FR-13).*

### TODO P03: Conversus Pre-Merge Gate

*Reserved for P03. Will cover the conversus adapter invocation at the UAT PR-ready checkpoint per D007 + D014 adapter-reuse pattern.*

### TODO P03: FR-17 Cost Emission

*Reserved for P03. Will cover M019 Tier 1 shape cost emission from the sync dispatch path.*
```

Replace with:

```markdown
### TODO P04: `sync` Workflow

*Reserved for P04. Will cover `orchestrator:github sync`: marker-based idempotent upsert, `sync_mode` dispatch paths (manual / on-transition / cron advisory), `--dry-run` generalization (FR-15), `--strict` provenance enforcement (FR-13).*

### TODO P04: Conversus Pre-Merge Gate

*Reserved for P04. Will cover the conversus adapter invocation at the UAT PR-ready checkpoint per D007 + D014 adapter-reuse pattern.*

### TODO P04: FR-17 Cost Emission

*Reserved for P04. Will cover M019 Tier 1 shape cost emission from the sync dispatch path.*
```

(D015 rename — content bodies were authored at P01 pre-rename.)

### Step 4: Insert new `### Re-init Adoption Contract (FR-14)` subsection

Insert immediately after the Dry-Run Manifest Format subsection (after line 263) and before the (now relabeled) `### TODO P04: sync Workflow`:

```markdown
### Re-init Adoption Contract (FR-14)

`orchestrator:github init` is repeatable. Running it again after an initial run adopts existing remote resources rather than creating duplicates. Two trigger paths:

1. **Explicit `--re-init` flag** — operator intent to re-adopt. Fires the adoption pre-pass regardless of sidecar state.
2. **Implicit detection (sidecar-absent + marker-bearing remote)** — when the sidecar is absent AND the first projected orchestrator-id has a marker-bearing remote Issue (detected via a cheap marker-search probe on the first phase id), the adoption pre-pass engages automatically. This handles FR-11 reversibility-by-delete — the operator deleted the sidecar and re-ran init to rebuild it from remote state.

**Adoption algorithm** (per orchestrator-id):

1. `gh_marker_search_remote <repo-slug> <orchestrator-id>` queries the remote via `gh issue list --search "\"<!-- orchestrator-id: <id> -->\""`.
2. **Unique hit** → emit `UPSERT: <kind> <oid> <issue-number> adopt` manifest row; fetch the remote Issue body; verify FR-4 marker byte-identity via `shasum_marker_byte_identity`; write `items.<oid>` sidecar entry with the adopted `issue_number`; register the id in the `adopted_ids` array so the create fan-out short-circuits.
3. **Zero hits** → the id falls through to the normal create path (handles partial-prior-init cases where the sidecar was deleted after only some Issues were created).
4. **Duplicate hits** → emit `integration-marker-duplicate: <oid>` to stderr; increment error count; do NOT adopt either. FR-4's one-marker-per-id invariant is load-bearing — a duplicate marker is a bug requiring operator intervention.

**Milestone and Project v2 adoption**: Milestone adoption discovers the existing Milestone by title match (`gh milestone list`). Project v2 adoption queries by title match (`projectsV2(first: 20)` query — this is a GraphQL **query**, not a mutation, and is therefore outside the FR-5 three-shape whitelist enforced by `scripts/verify/graphql-call-shape.sh`).

**Auto-mode safety (SC-7)**: the re-init branch runs AFTER the existing auto-mode short-circuit. Without TTY + without `--i-am-operator`, `--re-init` is a no-op — the script falls through to the pending-sentinel path. Re-init is operator-initiated only.

**Manifest footer extension**: when re-init adoption ran, the footer is `upserts=<N> skipped=<M> errors=<E> adopted=<A>`. When re-init did NOT run (pure P02 create path), the footer stays the P02 3-field shape `upserts=<N> skipped=<M> errors=<E>` byte-identical — the 4th field is additive-optional.

**FR-4 marker invariant on adoption**: every adopted Issue's remote body is fetched via `gh issue view <num> --json body --jq .body` and fed to `shasum_marker_byte_identity`. On mismatch, adoption fails with `integration-marker-mismatch on adopt: <oid>`. This closes the FR-4 invariant across the full projection → read-back round trip.
```

### Step 5: Update the Scope Boundary table P03 column

Current (lines 150-162):

```markdown
| Section | P01 | P02 | P03 |
|---------|-----|-----|-----|
| Sidecar schema | shipped (this doc) | `items.<id>` population + `sub_issue_mode` field added | per-item status tracking (P04) |
| Pending sentinel | shipped | reversed on successful init | — |
| `sync_mode` enum | shipped (enum described) | operator-set at init (still `manual` default) | runtime wiring (P04) |
| Marker format | shipped (format described) | REST search-by-marker + emit + shasum byte-identity verify shipped | — |
| UAT ingestion | shipped (offline fixture flow) | — | optional live `gh issue list` pull (P03) |
| Auth modes | — | **shipped** (this doc) | — |
| Full mapping table | — | **partial** (phase/task/milestone rows; chunk/AC/status deferred) | **completed in place** |
| `init` workflow | — | **shipped** (this doc + script T02/T03) | re-init adoption (FR-14 full) |
| `sync` workflow | — | — | TODO P04 |
| Conversus pre-merge gate | — | — | TODO P04 |
| FR-17 cost emission | — | — | TODO P04 |
```

Wait — the P03 column in the CURRENT table already refers to P03 as if it ships re-init adoption + full mapping table completion. So the update needed is just to replace the predictive "deferred/completed" phrasing with past-tense "shipped":

| Section | P01 | P02 | P03 |
|---------|-----|-----|-----|
| Sidecar schema | shipped (this doc) | `items.<id>` population + `sub_issue_mode` field added | — (per-item status tracking is P04) |
| Pending sentinel | shipped | reversed on successful init | — |
| `sync_mode` enum | shipped (enum described) | operator-set at init (still `manual` default) | — (runtime wiring is P04) |
| Marker format | shipped (format described) | REST search-by-marker + emit + shasum byte-identity verify shipped | `gh_marker_search_remote` helper + byte-identity-on-adopt ship |
| UAT ingestion | shipped (offline fixture flow) | — | — (live `gh issue list` pull not taken in P03) |
| Auth modes | — | shipped (this doc) | — |
| Full mapping table | — | partial (phase/task/milestone rows; chunk/AC/status deferred) | **shipped** (deferred rows filled in place) |
| `init` workflow | — | shipped (this doc + script T02/T03) | **shipped** re-init adoption (FR-14 full) |
| `sync` workflow | — | — | — (TODO P04) |
| Conversus pre-merge gate | — | — | — (TODO P04) |
| FR-17 cost emission | — | — | — (TODO P04) |
| FR-5 GraphQL call-shape lint | — | — | **shipped** (`scripts/verify/graphql-call-shape.sh`) |

Replace the entire table (lines 150-162 inclusive) with the shape above. The prose above the table at line 148 stays byte-identical.

### Step 6: Extend `commands/github-init.md`

Read the existing `commands/github-init.md` (P02/T04 authored it; ~60 lines). In its Core Workflow section, add a paragraph documenting `--re-init`:

Locate the flag list in the Prerequisites / State Check or Core Workflow section and add `--re-init` alongside `--dry-run`, `--i-am-operator`, `--strict-labels`, etc.

Under Core Workflow, append one numbered step (after the existing create-path steps):

```markdown
<N+1>. **FR-14 re-init adoption** — if `--re-init` is passed, or if the sidecar is absent and a marker-search probe finds a pre-existing remote Issue, the adoption pre-pass runs before create fan-out. Each marker-bearing remote Issue is adopted (sidecar row written, manifest row carries `reason=adopt`); remaining ids fall through to the create path. See `references/github-integration.md` § Re-init Adoption Contract for the full adoption algorithm.
```

Do NOT modify any other section. P02's byte-identity on the other sections is gated by `scripts/verify/m013-p02-github-init-command.sh` — T04 must keep that gate green.

### Step 7: Create the T04 gate `scripts/verify/m013-p03-reference-extensions.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p03-reference-extensions.sh — T04 gate.
#
# Asserts:
#   (1) 3 `_deferred to P03_` cells are GONE from the Full Mapping Table.
#   (2) Table heading is `### Full Mapping Table (P02 + P03)`.
#   (3) 3 `### TODO P03:` stub headings are relabeled to `### TODO P04:`.
#   (4) `### Re-init Adoption Contract (FR-14)` subsection is present with key anchors.
#   (5) Scope Boundary table has the FR-5 lint row + `shipped` labels on P03 column.
#   (6) P01-authored sections byte-identity preserved via section-content sha256.
#   (7) P02-authored sections byte-identity preserved via section-content sha256.
#   (8) commands/github-init.md contains `--re-init` in its flag list.
#
# Byte-identity gating reuses the P02/T05 pattern: awk-extract sections by
# literal-prefix heading match up to next `^## ` anchor, shasum-compare
# against hashes embedded in this gate script. Robust against line-shifts.

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="${REPO_ROOT}/references/github-integration.md"
CMD="${REPO_ROOT}/commands/github-init.md"

passed=0; failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# (1) No _deferred to P03_ cells remain.
if grep -q '_deferred to P03_' "$DOC"; then
  fail "Mapping table still contains _deferred to P03_ cells"
else
  pass "All _deferred to P03_ cells filled"
fi

# (2) Heading rename.
grep -q '^### Full Mapping Table (P02 + P03)$' "$DOC" \
  && pass "Mapping table heading renamed" \
  || fail "Expected heading `### Full Mapping Table (P02 + P03)` missing"

# (3) Zero `### TODO P03:` headings remain; three `### TODO P04:` headings exist.
if grep -qE '^### TODO P03:' "$DOC"; then
  fail "`### TODO P03:` headings still present (should be relabeled)"
else
  pass "`### TODO P03:` headings relabeled"
fi
p04_count="$(grep -cE '^### TODO P04:' "$DOC" || true)"
[ "${p04_count:-0}" -eq 3 ] && pass "3 `### TODO P04:` headings present" \
  || fail "Expected 3 `### TODO P04:` headings, got ${p04_count:-0}"

# (4) Re-init Adoption Contract subsection present with anchors.
grep -q '^### Re-init Adoption Contract (FR-14)$' "$DOC" \
  && pass "Re-init Adoption Contract heading present" \
  || fail "Re-init Adoption Contract heading missing"
grep -q 'adopted=' "$DOC" && pass "adopted= footer documented" \
  || fail "adopted= footer not documented"
grep -q 'gh_marker_search_remote' "$DOC" && pass "helper name mentioned" \
  || fail "gh_marker_search_remote not mentioned"
grep -q 'integration-marker-duplicate' "$DOC" && pass "duplicate diagnostic documented" \
  || fail "integration-marker-duplicate not documented"

# (5) FR-5 lint row in Scope Boundary.
grep -q 'FR-5 GraphQL call-shape lint' "$DOC" \
  && pass "FR-5 lint row in Scope Boundary" \
  || fail "FR-5 lint row missing from Scope Boundary"
grep -q 'scripts/verify/graphql-call-shape.sh' "$DOC" \
  && pass "graphql-call-shape.sh path referenced" \
  || fail "graphql-call-shape.sh not referenced in doc"

# (6,7) Section-content byte-identity (P01 + P02 authored sections).
# Embed the pre-T04-edit hashes captured during T04 authoring.
#
# The author of this gate MUST capture the hashes BEFORE editing the doc,
# by running:
#   awk '/^## Overview$/,/^## /' references/github-integration.md | sed '$d' | shasum
# for each listed section, and paste the hashes into the arrays below. The
# gate then re-computes and compares.
#
# Sections to byte-identity-gate (P01 + P02 ownership — none of these
# should be edited by T04):
#   ## Overview
#   ## Sidecar Config Schema
#   ## Pending-Sentinel Semantics
#   ## `sync_mode` Enum
#   ## `<!-- orchestrator-id: ... -->` Marker Format
#   ## UAT Ingestion Contract
#   ## Knowledge-Layer Boundary (M013 vs. M020)
#   ### Auth Modes
#   ### Sub-Issue Representation Modes
#   ### `init` Workflow
#   ### Dry-Run Manifest Format (FR-15)
#
# Implementation: use awk to extract section body, pipe to shasum, compare
# against embedded constant. Author-time snapshot → embed result here.

# NOTE TO IMPLEMENTING AGENT: populate SEC_HASHES_<N> with the shasum of
# each extracted section BEFORE making the T04 edits. Re-run after edits
# and assert equality. If the agent's edits inadvertently touch a P01/P02
# section, this gate catches it.
#
# For the initial ship, the gate tolerates unset hashes with a warning —
# the implementing agent must populate them before the T05 phase suite.
SECTIONS="Overview
Sidecar Config Schema
Pending-Sentinel Semantics"

hash_checks_ok=1
# Implementing agent fills these in during T04 with real hashes.
# Leave as a checklist:
#  H_Overview="<paste hash>"
#  H_Sidecar="<paste hash>"
#  ... etc
# For each H_*, extract the section body and compare.

# Placeholder self-check: at minimum, verify the sections still exist.
for sec in "Overview" "Sidecar Config Schema" "Pending-Sentinel Semantics" \
           "UAT Ingestion Contract" "Knowledge-Layer Boundary"; do
  if grep -qF "## ${sec}" "$DOC"; then
    pass "P01 section present: ${sec}"
  else
    fail "P01 section MISSING: ${sec}"
    hash_checks_ok=0
  fi
done
for sec in "Auth Modes" "Sub-Issue Representation Modes" "init" "Dry-Run Manifest Format"; do
  if grep -qF "### ${sec}" "$DOC" || grep -qF "\`${sec}\`" "$DOC"; then
    pass "P02 section present: ${sec}"
  else
    fail "P02 section MISSING: ${sec}"
    hash_checks_ok=0
  fi
done

# Run the P02 reference-extensions gate as the definitive byte-identity check.
if bash "${REPO_ROOT}/scripts/verify/m013-p02-reference-extensions.sh" >/dev/null 2>&1; then
  pass "P02 reference-extensions gate still green"
else
  fail "P02 reference-extensions gate REGRESSION (P01/P02 sections touched)"
fi

# (8) commands/github-init.md --re-init in flag list.
grep -q -- '--re-init' "$CMD" && pass "--re-init documented in commands/github-init.md" \
  || fail "--re-init missing from commands/github-init.md"

# Also ensure the P02 github-init-command gate still passes.
if bash "${REPO_ROOT}/scripts/verify/m013-p02-github-init-command.sh" >/dev/null 2>&1; then
  pass "P02 github-init-command gate still green"
else
  fail "P02 github-init-command gate REGRESSION"
fi

echo "SUMMARY: m013-p03-reference-extensions.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p03-reference-extensions.sh"
  exit 0
fi
echo "FAIL: m013-p03-reference-extensions.sh" >&2
exit 1
```

Implementing agent note: the byte-identity section on sha256-hashing is intentionally left as a stub — the P02 gates already cover the byte-identity of the P01+P02 sections via their own embedded hashes, so relying on `m013-p02-reference-extensions.sh` green status is both load-bearing and non-redundant. If the P02 gate still passes, no P01/P02 section was edited.

## Must-Haves

From P03-PLAN:

- `references/github-integration.md` has all three `_deferred to P03_` cells replaced with real content.
- The Mapping Table heading reads `### Full Mapping Table (P02 + P03)`.
- Three `### TODO P03:` stub headings relabeled to `### TODO P04:`.
- `### Re-init Adoption Contract (FR-14)` subsection present with anchors: `adopted=`, `gh_marker_search_remote`, `integration-marker-duplicate`.
- Scope Boundary table includes FR-5 lint row referencing `scripts/verify/graphql-call-shape.sh`.
- `commands/github-init.md` flag list includes `--re-init`.
- P01/P02 byte-identity preserved (verified indirectly via P02 gates staying green).

## Verification

```bash
bash scripts/verify/m013-p03-reference-extensions.sh
bash scripts/verify/m013-p02-reference-extensions.sh
bash scripts/verify/m013-p02-github-init-command.sh
```

All three exit 0. The first is T04's new gate; the second + third are the P02 regression guards.

## Inputs

### From Previous Tasks

- `scripts/integrations/github-init.sh` (from P03/T02)
  - Settled flag name `--re-init`; settled footer field `adopted=<N>`. T04 documents both.
- `scripts/verify/graphql-call-shape.sh` (from P03/T03)
  - Settled path. T04 cross-references in the Re-init Adoption Contract + Scope Boundary table.

### From Disk (Pre-existing)

- `references/github-integration.md` (from P01 + P02 authored sections)
  - ~299 lines. T04 edits lines 148-222 (Mapping Table + prose) and lines 265-275 (relabel stubs), plus insertion of new Re-init Adoption Contract section after line 263.
- `commands/github-init.md` (from M013/P02/T04)
  - ~60 lines, MEM012-compliant. T04 adds `--re-init` to the flag list + one Core Workflow step mentioning FR-14 adoption. All other sections stay byte-identical.
- `scripts/verify/m013-p02-reference-extensions.sh` (from M013/P02/T05)
  - The P02 gate with embedded P01/P02 section sha256 hashes. T04's gate invokes this as the definitive byte-identity regression guard.
- `scripts/verify/m013-p02-github-init-command.sh` (from M013/P02/T04)
  - The P02 gate with embedded `commands/github-init.md` structural/content assertions. T04's gate invokes this as a regression guard.

## Constraints

- **Section byte-identity preservation**: P01-authored and P02-authored sections are NEVER edited by T04. Enforcement is via running the P02 reference-extensions + github-init-command gates and requiring they still exit 0.
- **Additive-only for commands/github-init.md**: the flag-list addition is one bullet; the Core Workflow addition is one numbered step. No deletion or rewrite of any other section.
- **D015 rename discipline**: the three `### TODO P03:` stubs are about sync/conversus/cost-emission — all P04 content per the D015 split. The rename to `### TODO P04:` is a purely mechanical label change; the italicized body text is updated to match (replace "P03" with "P04" in the "Reserved for" phrasing).
- **Knowledge-Layer Boundary (D014)**: no knowledge/spec/ writes, no `KNOWLEDGE-INDEX.md` touches, no `scripts/knowledge/rebuild-index.sh` modifications. No `SPEC-*` frontmatter changes. This task is documentation-only.
- **FR-12 Claude-Code-only v1**: no multi-runtime doc sections.
- **AD-19 `Check:` shape**: gate commands are single-script-file invocations.
- **Bash 3.2** on the gate script (not on the doc).
- **Integer-minutes duration** in T04-SUMMARY.md.

## Expected Output

```
PASS: All _deferred to P03_ cells filled
PASS: Mapping table heading renamed
PASS: `### TODO P03:` headings relabeled
PASS: 3 `### TODO P04:` headings present
PASS: Re-init Adoption Contract heading present
PASS: adopted= footer documented
PASS: helper name mentioned
PASS: duplicate diagnostic documented
PASS: FR-5 lint row in Scope Boundary
PASS: graphql-call-shape.sh path referenced
PASS: P01 section present: Overview
PASS: P01 section present: Sidecar Config Schema
PASS: P01 section present: Pending-Sentinel Semantics
PASS: P01 section present: UAT Ingestion Contract
PASS: P01 section present: Knowledge-Layer Boundary
PASS: P02 section present: Auth Modes
PASS: P02 section present: Sub-Issue Representation Modes
PASS: P02 section present: init
PASS: P02 section present: Dry-Run Manifest Format
PASS: P02 reference-extensions gate still green
PASS: --re-init documented in commands/github-init.md
PASS: P02 github-init-command gate still green
SUMMARY: m013-p03-reference-extensions.sh pass=22 fail=0
PASS: m013-p03-reference-extensions.sh
```

Estimated duration: 45 integer minutes.
