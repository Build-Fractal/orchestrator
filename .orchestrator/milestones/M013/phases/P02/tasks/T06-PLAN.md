---
schema_version: "1.0"
type: task-plan
task: "T06"
phase: "P02"
milestone: "M013"
name: "templates/github-integration-sidecar.json schema extension — sub_issue_mode field"
depends_on: []
---

## Prerequisites

- `templates/github-integration-sidecar.json` (from P01/T01) is the canonical sidecar schema. It has a `_schema_docs` block describing each top-level field inline.
- P01's `scripts/integrations/sidecar-init-pending.sh` strips the `_schema_docs` block at bootstrap time using an AWK brace-depth tracker. Adding a new field to `_schema_docs` must not break that stripper.
- P02 introduces `sub_issue_mode: native | labeled-fallback | pending` — T02/T03 populate it on live run; T05 documents it in the reference doc.
- P01's `scripts/integrations/github-status.sh` grep-scans top-level fields for schema validation and pending-sentinel detection (it iterates `schema_version repo_slug project_v2_id sync_mode recommended_cron custom_field_mappings items`). Adding `sub_issue_mode` as a pending-able field means extending `github-status.sh`'s validation list — this task covers that.

## Description

Extend the sidecar schema with a new top-level field `sub_issue_mode` supporting three values (`native`, `labeled-fallback`, `pending` — the pending-sentinel value at bootstrap). Update:

1. `templates/github-integration-sidecar.json` — add the field + its `_schema_docs` entry.
2. `scripts/integrations/github-status.sh` — add `sub_issue_mode` to the required-fields list AND to the pending-sentinel detection list.

The pending-sentinel bootstrap helper `sidecar-init-pending.sh` needs no code change — it strips `_schema_docs` generically and passes the rest through.

## Steps

### Step 1: Update `templates/github-integration-sidecar.json`

Current (from P01/T01):

```json
{
  "_schema_docs": {
    "schema_version": "integer — current cache schema version (FR-6). v1 shipped in M013/P01. Increment on any breaking per-item shape change.",
    "repo_slug": "string — 'owner/repo' for the target GitHub repo. 'pending' until operator completes init.",
    "project_v2_id": "string — GitHub Projects v2 node ID. 'pending' until init (P02) creates or attaches.",
    "sync_mode": "enum: manual|on-transition|cron — how sync is invoked.",
    "recommended_cron": "string — cron expression surfaced to the operator when sync_mode=cron. Advisory only; orchestrator does not install cron.",
    "custom_field_mappings": "array — optional operator-declared Project v2 custom-field name→orchestrator-source mappings.",
    "items": "object — per-item cache keyed by orchestrator-id (e.g. 'M013-P01', 'M013-P01-T01'). Per-item shape: {issue_number: int, project_v2_attached: bool, status_field_synced: bool, last_attempt_at: iso8601-string, last_error: string|null, schema_version: int}. Populated by P02 on first init; empty {} at P01 scaffold."
  },
  "schema_version": 1,
  "repo_slug": "pending",
  "project_v2_id": "pending",
  "sync_mode": "manual",
  "recommended_cron": "*/15 * * * *",
  "custom_field_mappings": [],
  "items": {}
}
```

Add the `sub_issue_mode` field (placed alphabetically-adjacent to `sync_mode` in `_schema_docs`, and inserted in the data section between `custom_field_mappings` and `items`):

```json
{
  "_schema_docs": {
    "schema_version": "integer — current cache schema version (FR-6). v1 shipped in M013/P01. Increment on any breaking per-item shape change.",
    "repo_slug": "string — 'owner/repo' for the target GitHub repo. 'pending' until operator completes init.",
    "project_v2_id": "string — GitHub Projects v2 node ID. 'pending' until init (P02) creates or attaches.",
    "sync_mode": "enum: manual|on-transition|cron — how sync is invoked.",
    "sub_issue_mode": "enum: native|labeled-fallback|pending — GitHub sub-issue REST availability mode recorded by P02 init preflight. 'pending' until init probes /repos/:slug/issues/1/sub_issues. 'native' = GitHub sub-issue REST used. 'labeled-fallback' = parent:<phase-id> / child:<task-id> labels + reciprocal body links used. See references/github-integration.md § Sub-Issue Representation Modes.",
    "recommended_cron": "string — cron expression surfaced to the operator when sync_mode=cron. Advisory only; orchestrator does not install cron.",
    "custom_field_mappings": "array — optional operator-declared Project v2 custom-field name→orchestrator-source mappings.",
    "items": "object — per-item cache keyed by orchestrator-id (e.g. 'M013-P01', 'M013-P01-T01'). Per-item shape: {issue_number: int, project_v2_attached: bool, status_field_synced: bool, last_attempt_at: iso8601-string, last_error: string|null, schema_version: int}. Populated by P02 on first init; empty {} at P01 scaffold."
  },
  "schema_version": 1,
  "repo_slug": "pending",
  "project_v2_id": "pending",
  "sync_mode": "manual",
  "sub_issue_mode": "pending",
  "recommended_cron": "*/15 * * * *",
  "custom_field_mappings": [],
  "items": {}
}
```

### Step 2: Update `scripts/integrations/github-status.sh`

Two edits in the existing script:

**Edit A** — add `sub_issue_mode` to the schema-required fields list. Current code at approx L80:

```bash
for f in schema_version repo_slug project_v2_id sync_mode recommended_cron custom_field_mappings items; do
```

Change to:

```bash
for f in schema_version repo_slug project_v2_id sync_mode sub_issue_mode recommended_cron custom_field_mappings items; do
```

**Edit B** — add `sub_issue_mode` to the pending-sentinel detection list. Current code at approx L93:

```bash
for f in repo_slug project_v2_id sync_mode; do
```

Change to:

```bash
for f in repo_slug project_v2_id sync_mode sub_issue_mode; do
```

**Edit C (cosmetic; optional)** — add a `SUB_ISSUE_MODE: <value>` line to the `configured` output block after `SYNC_MODE:`. If adding:

```bash
sub_issue_mode=$(extract_field sub_issue_mode "")
...
echo "SUB_ISSUE_MODE: ${sub_issue_mode}"
```

Edit C is permitted but optional — the P01 output contract doesn't require this line. If added, update P01/T02's `commands/github-status.md` output example block (strictly additive — doesn't change P01 contract behavior). If not added, skip this edit and let `SUB_ISSUE_MODE` emerge as a P04 `github-sync.sh` output line instead.

### Step 3: Verify the template is valid JSON

```bash
python3 -c "import json, sys; json.load(open('templates/github-integration-sidecar.json'))"
```

(Expected: exit 0, no output.)

### Step 4: Verify the pending-sentinel bootstrap still strips `_schema_docs` cleanly

```bash
bash scripts/integrations/sidecar-init-pending.sh --root /tmp/m013-p02-t06-test
python3 -c "import json, sys; json.load(open('/tmp/m013-p02-t06-test/.orchestrator/integrations/github.json'))"
python3 -c "import json; d=json.load(open('/tmp/m013-p02-t06-test/.orchestrator/integrations/github.json')); assert '_schema_docs' not in d and d['sub_issue_mode']=='pending'"
```

(Expected: exit 0; the bootstrapped sidecar contains `sub_issue_mode: pending` and no `_schema_docs` block.)

### Step 5: Verify `github-status.sh` reports `pending-operator-complete` because of the new field

After step 4's bootstrap, run:

```bash
bash scripts/integrations/github-status.sh --root /tmp/m013-p02-t06-test
```

Expected stdout:
```
STATUS: pending-operator-complete
PENDING_FIELDS: repo_slug,project_v2_id,sync_mode,sub_issue_mode
```

(Or — if P01's `sync_mode: manual` default is still considered non-pending — the list may be `repo_slug,project_v2_id,sub_issue_mode`. Both are acceptable; document whichever emerges.)

## Must-Haves

- `templates/github-integration-sidecar.json` ≥18 lines, contains `sub_issue_mode`.
- The template parses as valid JSON.
- `scripts/integrations/github-status.sh` required-fields list includes `sub_issue_mode`.
- `scripts/integrations/github-status.sh` pending-sentinel detection list includes `sub_issue_mode`.
- `scripts/integrations/sidecar-init-pending.sh` works unchanged — the AWK `_schema_docs` stripper still produces valid JSON after T06's template edits.

## Verification

T06 does not ship its own dedicated gate — its correctness rolls into the T01 `m013-p02-github-common.sh` gate (which exercises sidecar read/write against a fresh pending-sentinel sidecar) and the T02 `m013-p02-auto-mode-pending.sh` gate (which exercises the full pending-sentinel path including the new field).

An optional spot-check:

```bash
bash scripts/verify/m013-p02-github-common.sh
```

Should still PASS 13/13 assertions (plus ≥1 new assertion about `sub_issue_mode` recognition).

## Inputs

### From Previous Tasks

None — T06 has no explicit task dependency. Execute in parallel with T04 and T05 after T01.

### From Disk (Pre-existing)

- `templates/github-integration-sidecar.json` (from P01/T01) — target file; extended in place.
- `scripts/integrations/sidecar-init-pending.sh` (from P01/T01) — no code change; just verified still-compatible.
- `scripts/integrations/github-status.sh` (from P01/T02) — two-line list edit.
- `commands/github-status.md` (from P01/T02) — optionally update the example output block if Edit C is taken.

## Constraints

- **Schema compatibility**: the template must remain valid JSON after edit. The `_schema_docs` block must remain strippable by `sidecar-init-pending.sh`'s AWK logic (no lines longer than ~500 chars; no embedded `{` or `}` inside values — escape if needed).
- **P01 callers must keep working**: `github-status.sh` with an older sidecar (pre-T06, no `sub_issue_mode` field) would report `schema-mismatch` after Edit A. **Acceptable risk**: the repo's committed template is the SSOT; any existing operator sidecar would have been pending-sentinel-bootstrapped from that template and would be re-bootstrapped via `delete + --init-pending` per the FR-11 reversibility contract. Document this migration note at the top of `references/github-integration.md` if P02 is the first version shipped to operators (coordinate with T05).
- **Bash 3.2 compat**: the `github-status.sh` edits are scalar list additions — no shell compat concern.
- **No behavioral changes beyond the new field**: T06 must not re-number exit codes, change STATUS line format, or alter `extract_field` helper contract. Purely additive.
- **Knowledge-Layer Boundary**: no SPEC-* changes, no knowledge-tree writes.
- **AD-19**: verify script invocations use single-script-file shape.

## Expected Output

Template parses as JSON. Pending-sentinel bootstrap includes `sub_issue_mode: pending`. `github-status.sh` lists `sub_issue_mode` in `PENDING_FIELDS:` on absent init, and in `REQUIRED_FIELDS` checks on schema validation. The T07 phase-suite reports no regression on the P01 gates (sidecar-schema, github-status, github-status-command) because those gates were authored against the P01 template AND must continue to PASS — if they fail because of the new field, surface in T07 as an orchestrator coordination issue and arbitrate: either (a) update P01 gates to accept `sub_issue_mode` (simple find-and-add) or (b) scope P01 gates to accept either shape (union).

Operator flagging worth noting: the T07 gate `m013-p02-auto-mode-pending.sh` will likely need the P01 gates' assertion list updated to include `sub_issue_mode` — T07 covers this as part of its phase-suite assembly.
