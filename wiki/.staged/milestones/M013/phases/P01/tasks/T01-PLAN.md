---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M013"
name: "Sidecar schema + .orchestrator/integrations/github.json scaffolding + pending-sentinel semantics"
depends_on: []
---

## Prerequisites

No upstream task dependencies. Pre-existing disk state:

- `.orchestrator/` exists (repo-level orchestrator state root).
- `.orchestrator/integrations/` does NOT yet exist — this task creates it.
- `knowledge/spec/story/SPEC-US-001.md` and `knowledge/spec/acceptance/SPEC-AC-*.md` exist (used later by T04/T05, mentioned here for scope context only).
- M012/P04 established the `pending`-sentinel pattern for first-deploy operator handoff (see [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) D012 / the `DEPLOY-RECORD.md` convention). This task inherits that discipline for `github.json`: the sentinel string is the literal word `pending` (lowercase, unquoted in JSON string form: `"pending"`).

## Description

Produce the canonical *schema-contract* for `.orchestrator/integrations/github.json` — the sidecar config file that every M013 subcommand (`status`, `init` P02, `sync` P03) reads and writes. This task **does not ship `init`** (that is P02). It ships three things:

1. A schema-contract document embedded as JSON comments in a template file at `templates/github-integration-sidecar.json` (new) describing every top-level field and per-item field with its enum values and sentinel semantics.
2. An optional "pending-sentinel bootstrap" helper that `github-status.sh` (T02) calls when it detects `--init-pending` — writes a fresh `.orchestrator/integrations/github.json` populated entirely with the literal `"pending"` sentinel. This lives in `scripts/integrations/sidecar-init-pending.sh`.
3. A verifier (`scripts/verify/m013-p01-sidecar-schema.sh`) that asserts: the template document is valid JSON after comment stripping, every top-level field listed in FR-6 is present, the `sync_mode` enum is exactly `["manual", "on-transition", "cron"]`, and a sample `pending`-sentinel file passes a "pending detection" check.

Do NOT commit a populated `.orchestrator/integrations/github.json` to the repo. The path is reserved as operator-owned state. Add the path to `.gitignore` (already covered by the broader `.orchestrator/integrations/` entry if not present — check and add if missing).

## Steps

### Step 1: Create `templates/github-integration-sidecar.json`

Write the canonical shape (JSON with leading `//` comment lines stripped at parse time by a small helper). Since JSON does not permit comments, ship it as a JSON file with field documentation in a separate sibling markdown file, OR (simpler and preferred) embed a `"_schema_docs"` top-level object whose keys mirror every documented field and whose values are the one-line docstrings. Prefer the second form — it keeps the file parse-clean with `jq` (or the project's `scripts/util/json-field.sh`) without any stripping pass.

Template body:

```json
{
  "_schema_docs": {
    "schema_version": "integer — current cache schema version (FR-6). v1 shipped in M013/P01. Increment on any breaking per-item shape change.",
    "repo_slug": "string — 'owner/repo' for the target GitHub repo. 'pending' until operator completes init.",
    "project_v2_id": "string — GitHub Projects v2 node ID. 'pending' until init (P02) creates or attaches.",
    "sync_mode": "enum: manual|on-transition|cron — how sync is invoked.",
    "recommended_cron": "string — cron expression surfaced to the operator when sync_mode=cron. Advisory only; orchestrator does not install cron.",
    "custom_field_mappings": "array — optional operator-declared Project v2 custom-field name→orchestrator-source mappings.",
    "items": "object — per-item cache keyed by orchestrator-id (e.g. 'M013-P01', 'M013-P01-T01')."
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

Per-item shape (documented in comments in the reference doc T06 ships, not repeated inline here): `{issue_number: int, project_v2_attached: bool, status_field_synced: bool, last_attempt_at: iso8601-string, last_error: string|null, schema_version: int}`. For T01 the `items` object is empty `{}` — P02 populates it on first `init` run.

### Step 2: Create `scripts/integrations/sidecar-init-pending.sh`

Single-script helper that copies `templates/github-integration-sidecar.json` into `.orchestrator/integrations/github.json`, stripping the `_schema_docs` key before writing (so the live file is lean). Exits 0 on success, exits 2 if the target file already exists (refuses to clobber — operator must delete first per FR-11 reversibility semantics).

```bash
#!/usr/bin/env bash
# scripts/integrations/sidecar-init-pending.sh — write a pending-sentinel
# sidecar config to .orchestrator/integrations/github.json.
#
# Usage: sidecar-init-pending.sh [--root <project-root>]
#
# Exits 0 on successful write, 2 if the target already exists
# (refuses to clobber — delete to reset per FR-11).
# Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    *) echo "sidecar-init-pending.sh: unknown flag: $1" >&2; exit 2 ;;
  esac
done

TEMPLATE="${PROJECT_ROOT}/templates/github-integration-sidecar.json"
TARGET_DIR="${PROJECT_ROOT}/.orchestrator/integrations"
TARGET="${TARGET_DIR}/github.json"

if [ ! -f "$TEMPLATE" ]; then
  echo "sidecar-init-pending.sh: template missing at $TEMPLATE" >&2
  exit 1
fi

if [ -f "$TARGET" ]; then
  echo "sidecar-init-pending.sh: $TARGET already exists — delete first to reset" >&2
  exit 2
fi

mkdir -p "$TARGET_DIR"

# Strip the _schema_docs key. Use awk (no jq dependency per MEM001).
awk '
  BEGIN { skip=0; depth=0 }
  /"_schema_docs"[ \t]*:/ { skip=1; depth=0; next }
  skip==1 {
    # Count braces in this line
    n=gsub(/\{/, "&")
    m=gsub(/\}/, "&")
    depth = depth + n - m
    if (depth <= 0 && (index($0, "}") || index($0, "},"))) { skip=0 }
    next
  }
  { print }
' "$TEMPLATE" > "$TARGET"

echo "WROTE: $TARGET"
exit 0
```

### Step 3: Update `.gitignore`

Confirm `.orchestrator/integrations/` (or at least `.orchestrator/integrations/github.json`) is gitignored. If not present, append:

```
# M013 GitHub integration sidecar — operator-owned, never committed
.orchestrator/integrations/github.json
```

### Step 4: Create `scripts/verify/m013-p01-sidecar-schema.sh`

Self-contained gate. Asserts:

1. `templates/github-integration-sidecar.json` exists.
2. The template is parse-clean (round-trip through a minimal JSON validator — `python3 -c 'import json,sys;json.load(open(sys.argv[1]))'` is acceptable; if python3 is not present on the host, fall back to `jq . <file> >/dev/null` with a skip if neither is present — emit `SKIP:` but still exit 0 in that case, mirroring `references/verification-ladder.md` graceful-tool-absent semantics).
3. Every FR-6 top-level field is present: `schema_version`, `repo_slug`, `project_v2_id`, `sync_mode`, `recommended_cron`, `custom_field_mappings`, `items`.
4. `sync_mode` value in the template is one of `"manual"`, `"on-transition"`, `"cron"`.
5. Exercise `scripts/integrations/sidecar-init-pending.sh` into a temporary directory fixture; assert the resulting file contains `"schema_version": 1` and `"repo_slug": "pending"`; re-run and assert exit code 2 (clobber refusal).

Gate shape (Bash 3.2; single-script-file; emits `PASS:` / `FAIL:` lines):

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p01-sidecar-schema.sh
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATE="${REPO_ROOT}/templates/github-integration-sidecar.json"
HELPER="${REPO_ROOT}/scripts/integrations/sidecar-init-pending.sh"

fail_count=0
assert_ok() { if [ "$1" -eq 0 ]; then echo "PASS: $2"; else echo "FAIL: $2"; fail_count=$((fail_count + 1)); fi; }

# 1. Template exists
[ -f "$TEMPLATE" ]; assert_ok $? "template present"

# 2. JSON parse-clean (prefer python3, fall back to jq, else SKIP)
if command -v python3 >/dev/null 2>&1; then
  python3 -c "import json,sys;json.load(open('$TEMPLATE'))" >/dev/null 2>&1
  assert_ok $? "template is valid JSON (python3)"
elif command -v jq >/dev/null 2>&1; then
  jq . "$TEMPLATE" >/dev/null 2>&1
  assert_ok $? "template is valid JSON (jq)"
else
  echo "SKIP: JSON validator (no python3 or jq); gate passes"
fi

# 3. FR-6 fields present
for field in schema_version repo_slug project_v2_id sync_mode recommended_cron custom_field_mappings items; do
  grep -q "\"${field}\"" "$TEMPLATE"
  assert_ok $? "template has field: ${field}"
done

# 4. sync_mode enum membership (one of manual/on-transition/cron)
grep -E '"sync_mode"[ \t]*:[ \t]*"(manual|on-transition|cron)"' "$TEMPLATE" >/dev/null
assert_ok $? "sync_mode enum membership"

# 5. Helper behavior
TMPROOT="$(mktemp -d)"
mkdir -p "${TMPROOT}/templates" "${TMPROOT}/scripts/integrations"
cp "$TEMPLATE" "${TMPROOT}/templates/"
cp "$HELPER" "${TMPROOT}/scripts/integrations/"
bash "${TMPROOT}/scripts/integrations/sidecar-init-pending.sh" --root "$TMPROOT" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ]; assert_ok $? "sidecar-init-pending.sh exits 0 on fresh write"
[ -f "${TMPROOT}/.orchestrator/integrations/github.json" ]; assert_ok $? "github.json written"
grep -q '"repo_slug": "pending"' "${TMPROOT}/.orchestrator/integrations/github.json"
assert_ok $? "written file has pending sentinel"
bash "${TMPROOT}/scripts/integrations/sidecar-init-pending.sh" --root "$TMPROOT" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 2 ]; assert_ok $? "second invocation refuses with exit 2"
rm -rf "$TMPROOT"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m013-p01-sidecar-schema.sh"
  exit 0
fi
echo "FAIL: m013-p01-sidecar-schema.sh ($fail_count failures)"
exit 1
```

## Must-Haves

- `templates/github-integration-sidecar.json` exists and round-trips through a JSON validator.
- Every FR-6 top-level field present in the template with documented defaults (including `pending` for `repo_slug` + `project_v2_id`).
- `scripts/integrations/sidecar-init-pending.sh` writes the live sidecar on fresh run and refuses to clobber an existing file with exit 2.
- `scripts/verify/m013-p01-sidecar-schema.sh` passes all seven assertions.
- `.gitignore` protects `.orchestrator/integrations/github.json`.

## Verification

- `bash scripts/verify/m013-p01-sidecar-schema.sh`

## Inputs

### From Disk (Pre-existing)

- `scripts/util/json-field.sh` — optional helper for JSON field extraction (not required; raw grep acceptable for P01).
- `.gitignore` — existing; append a rule if `.orchestrator/integrations/github.json` is not yet covered.
- `templates/` — existing directory holding `phase-plan.md`, `task-plan.md`, etc. (MEM013 convention).

## Constraints

- Bash 3.2 compatible (Constitution IX, MEM001). No `declare -A`, no `mapfile`, no `${var,,}`.
- No jq hard dependency: JSON parse in the verify gate prefers `python3` and falls back to `jq` only if present; `SKIP:` when neither (graceful-absent-tool pattern from [M012](../../../../../milestones/M012/index.md)).
- No `gh` subprocess calls — this is schema scaffolding, zero remote work.
- `pending` is the literal sentinel. Any top-level string field whose value equals `"pending"` MUST cause downstream consumers (T02's `status` reader) to report `STATUS: pending-operator-complete` — per FR-6 and D014.
- Single-script-file shape (AD-19) for all `Check:` commands: no `( . file && fn )` subshells, no `$(cmd | filter)` in gate logic. The gate above uses plain `if`/`grep`/`assert_ok` calls — no compound-pipe command substitutions.
- Do NOT populate `items` — leave as empty `{}`. P02 owns population.
- Do NOT commit a populated `github.json` to git. The template is committed; the live file is ignored.

## Expected Output

- `templates/github-integration-sidecar.json` created.
- `scripts/integrations/sidecar-init-pending.sh` created.
- `.gitignore` updated (if needed).
- `scripts/verify/m013-p01-sidecar-schema.sh` created.
- `bash scripts/verify/m013-p01-sidecar-schema.sh` → final line `PASS: m013-p01-sidecar-schema.sh`, exit 0.
