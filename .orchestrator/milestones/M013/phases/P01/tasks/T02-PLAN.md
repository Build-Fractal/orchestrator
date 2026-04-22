---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M013"
name: "scripts/integrations/github-status.sh + commands/github-status.md"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `templates/github-integration-sidecar.json` exists, `scripts/integrations/sidecar-init-pending.sh` exists, `scripts/integrations/` directory exists.
- Read convention: commands file structure from MEM012 — `description` frontmatter, Title, Prerequisites/State Check, Core Workflow, Output, Idempotency, Error Handling, Referenced Scripts sections. See `commands/status.md` or `commands/verify.md` for reference.
- Read convention: scripts emit prefixed lines to stdout (`STATUS:`, `PASS:`, `FAIL:`, etc.) — MEM001.

## Description

Ship the read-only `orchestrator:github status` subcommand. Both the markdown command definition (`commands/github-status.md`) and its implementing script (`scripts/integrations/github-status.sh`). The script is a pure file-reader — no `gh` subprocess calls, no network — and reports one of three `STATUS:` lines to stdout:

- `STATUS: absent` — `.orchestrator/integrations/github.json` does not exist.
- `STATUS: pending-operator-complete` — file exists but at least one top-level string field has the literal value `"pending"` (per FR-6 pending-sentinel semantics).
- `STATUS: configured` — file exists and no `pending` sentinel is present.

For `configured`, the script also prints `LAST_SYNC: <iso-8601-or-never>`, `CACHE_ITEMS: <integer>`, `SYNC_MODE: <manual|on-transition|cron>`, and `REPO_SLUG: <owner/repo>`. For `pending-operator-complete`, it prints which top-level fields are still pending. For `absent`, the script also supports `--init-pending` which delegates to `scripts/integrations/sidecar-init-pending.sh` (from T01) and then re-reports status.

Exit codes:
- 0: `STATUS:` successfully reported (absent / pending / configured all exit 0 — this is a read command, not a gate).
- 1: malformed JSON OR schema mismatch (field missing that FR-6 requires).
- 2: invalid command-line argument.

This command is invoked standalone by the maintainer and is also the primary state-read used by `orchestrator:github init` (P02) and `sync` (P03) to decide whether to proceed.

## Steps

### Step 1: Create `scripts/integrations/github-status.sh`

```bash
#!/usr/bin/env bash
# scripts/integrations/github-status.sh — Read-only sidecar config reporter.
#
# Usage:
#   github-status.sh [--root <project-root>] [--init-pending]
#
# Output (stdout):
#   STATUS: absent|pending-operator-complete|configured
#   REPO_SLUG: <value>              (configured only)
#   SYNC_MODE: <value>              (configured only)
#   LAST_SYNC: <iso-8601|never>     (configured only)
#   CACHE_ITEMS: <integer>          (configured only)
#   PENDING_FIELDS: <csv>           (pending-operator-complete only)
#
# Exit: 0 on successful report, 1 on malformed JSON / schema mismatch,
#       2 on invalid CLI argument.
#
# Bash 3.2 compatible. No gh subprocess calls (P01 scope).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INIT_PENDING=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    --init-pending) INIT_PENDING=1; shift ;;
    -h|--help)
      echo "usage: github-status.sh [--root <dir>] [--init-pending]"
      exit 0
      ;;
    *) echo "github-status.sh: unknown flag: $1" >&2; exit 2 ;;
  esac
done

SIDECAR="${PROJECT_ROOT}/.orchestrator/integrations/github.json"

# --init-pending: bootstrap pending sentinel via T01 helper.
if [ "$INIT_PENDING" -eq 1 ] && [ ! -f "$SIDECAR" ]; then
  bash "${PROJECT_ROOT}/scripts/integrations/sidecar-init-pending.sh" --root "$PROJECT_ROOT"
fi

# Absent branch.
if [ ! -f "$SIDECAR" ]; then
  echo "STATUS: absent"
  exit 0
fi

# Helper: extract a top-level JSON string or integer field by grep.
# Bash 3.2, no jq hard dep. For the fields we need (schema_version,
# repo_slug, project_v2_id, sync_mode, items) grep/sed is sufficient
# since the file is line-oriented JSON written by our own helper.
extract_field() {
  # $1 = field name; $2 = default
  local f="$1"; local default="$2"; local line
  line=$(grep -E "^[[:space:]]*\"${f}\"[[:space:]]*:" "$SIDECAR" | head -1 || true)
  if [ -z "$line" ]; then
    printf '%s' "$default"
    return
  fi
  # Strip everything up to the colon, then trim quotes/comma/whitespace.
  printf '%s' "$line" | sed -E 's/^[^:]*:[[:space:]]*//' | sed -E 's/[,[:space:]]+$//' | sed -E 's/^"//' | sed -E 's/"$//'
}

repo_slug=$(extract_field repo_slug "")
project_v2_id=$(extract_field project_v2_id "")
sync_mode=$(extract_field sync_mode "")
last_sync=$(extract_field last_sync "never")

# Schema check: required top-level fields per FR-6.
missing=""
for f in schema_version repo_slug project_v2_id sync_mode recommended_cron custom_field_mappings items; do
  if ! grep -qE "^[[:space:]]*\"${f}\"[[:space:]]*:" "$SIDECAR"; then
    missing="${missing}${missing:+,}${f}"
  fi
done
if [ -n "$missing" ]; then
  echo "STATUS: schema-mismatch" >&2
  echo "MISSING_FIELDS: ${missing}" >&2
  exit 1
fi

# Pending-sentinel detection.
pending_fields=""
for f in repo_slug project_v2_id sync_mode; do
  v=$(extract_field "$f" "")
  if [ "$v" = "pending" ]; then
    pending_fields="${pending_fields}${pending_fields:+,}${f}"
  fi
done

if [ -n "$pending_fields" ]; then
  echo "STATUS: pending-operator-complete"
  echo "PENDING_FIELDS: ${pending_fields}"
  exit 0
fi

# Configured branch.
# Count items: look for lines matching '    "M###-...": {' under items.
cache_items=$(grep -cE '^[[:space:]]{4,}"M[0-9]+-P[0-9]+' "$SIDECAR" || true)
# grep -c always prints a number; ensure non-empty.
[ -z "$cache_items" ] && cache_items=0

echo "STATUS: configured"
echo "REPO_SLUG: ${repo_slug}"
echo "SYNC_MODE: ${sync_mode}"
echo "LAST_SYNC: ${last_sync}"
echo "CACHE_ITEMS: ${cache_items}"
exit 0
```

### Step 2: Create `commands/github-status.md`

Follow MEM012 structure. Base on `commands/status.md` and `commands/doctor.md` as reference.

```markdown
---
description: "Use when reporting GitHub integration sidecar state — absent, pending-operator-complete, or configured. Read-only; makes no GitHub API calls."
---

# speckit.orchestrator.github-status

Report the current state of the M013 GitHub integration sidecar config at `.orchestrator/integrations/github.json`. This command is read-only — it never writes to GitHub and never writes to orchestrator state (except optionally when `--init-pending` is passed, which delegates to the pending-sentinel bootstrap helper).

## Prerequisites / State Check

No orchestrator state requirements. Runs in any orchestrator state.

## Core Workflow

1. **Invoke the status script**: `bash scripts/integrations/github-status.sh [--init-pending]`
2. **Interpret the STATUS line**:
   - `STATUS: absent` — sidecar file does not exist. Integration is off. Run `bash scripts/integrations/github-status.sh --init-pending` to bootstrap a pending-sentinel config, or run `orchestrator:github init` (P02) to configure fully.
   - `STATUS: pending-operator-complete` — sidecar exists but fields carry the `pending` sentinel. The `PENDING_FIELDS:` line names them. The operator must complete these fields (typically by running `orchestrator:github init` on first live session).
   - `STATUS: configured` — sidecar is populated. The `REPO_SLUG:`, `SYNC_MODE:`, `LAST_SYNC:`, and `CACHE_ITEMS:` lines report current state.
3. **Report to developer**: print the script's stdout verbatim, then a short plain-English gloss.

## Output

Verbatim script output followed by a one-line summary. Example configured output:

```
STATUS: configured
REPO_SLUG: Build-Fractal/spec-kit-orchestrator
SYNC_MODE: manual
LAST_SYNC: 2026-04-25T14:22:10Z
CACHE_ITEMS: 17

GitHub integration is configured; 17 cached items; last sync ~2h ago; manual sync mode.
```

## Idempotency

Fully idempotent: running multiple times without arguments produces identical output. With `--init-pending`, the second invocation will find the sidecar already present and leave it unchanged (the underlying helper refuses to clobber).

## Error Handling

- `exit 1 STATUS: schema-mismatch` — the sidecar file exists but is missing FR-6 required fields. Operator must delete and re-init.
- `exit 2` — invalid CLI flag. Check the `--help` output.

## Referenced Scripts

- `scripts/integrations/github-status.sh` — the implementation (read-only reporter).
- `scripts/integrations/sidecar-init-pending.sh` — invoked on `--init-pending` (from T01).
- `templates/github-integration-sidecar.json` — the schema source referenced when computing required-field set.

## Referenced Templates

- `templates/github-integration-sidecar.json` (M013/P01/T01).
```

### Step 3: Create `scripts/verify/m013-p01-github-status.sh`

Gate asserts:
1. Script exists and is executable via `bash`.
2. `STATUS: absent` reported when no sidecar in a fresh tempdir.
3. `STATUS: pending-operator-complete` reported after `--init-pending` in a fresh tempdir.
4. `STATUS: configured` reported after the tempdir sidecar is hand-edited to replace every `"pending"` with a concrete value.
5. Exit code 1 when the sidecar file has a missing required field.
6. Exit code 2 on unknown flag.
7. The script makes zero `gh` subprocess calls (verify by `grep -c '\bgh ' scripts/integrations/github-status.sh` → must return 0).

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p01-github-status.sh
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/scripts/integrations/github-status.sh"
TEMPLATE="${REPO_ROOT}/templates/github-integration-sidecar.json"

fail_count=0
assert_eq() {
  if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 (expected=$2 actual=$3)"; fail_count=$((fail_count + 1)); fi
}
assert_ok() {
  if [ "$1" -eq 0 ]; then echo "PASS: $2"; else echo "FAIL: $2"; fail_count=$((fail_count + 1)); fi
}

# 1. Script present
[ -f "$SCRIPT" ]; assert_ok $? "github-status.sh present"

# 2. Absent in a fresh tempdir
TMP="$(mktemp -d)"
out=$(bash "$SCRIPT" --root "$TMP" 2>/dev/null | head -1)
assert_eq "absent status on empty tempdir" "STATUS: absent" "$out"

# 3. Pending after --init-pending
mkdir -p "${TMP}/templates" "${TMP}/scripts/integrations"
cp "$TEMPLATE" "${TMP}/templates/"
cp "${REPO_ROOT}/scripts/integrations/sidecar-init-pending.sh" "${TMP}/scripts/integrations/"
bash "$SCRIPT" --root "$TMP" --init-pending >/dev/null 2>&1
out=$(bash "$SCRIPT" --root "$TMP" 2>/dev/null | head -1)
assert_eq "pending-operator-complete after --init-pending" "STATUS: pending-operator-complete" "$out"

# 4. Configured after sed-replacing pending values
SIDECAR="${TMP}/.orchestrator/integrations/github.json"
sed -i.bak 's/"repo_slug": "pending"/"repo_slug": "owner\/repo"/' "$SIDECAR"
sed -i.bak 's/"project_v2_id": "pending"/"project_v2_id": "PVT_abc123"/' "$SIDECAR"
rm -f "${SIDECAR}.bak"
out=$(bash "$SCRIPT" --root "$TMP" 2>/dev/null | head -1)
assert_eq "configured after completing pending fields" "STATUS: configured" "$out"

# 5. Schema mismatch on doctored file (remove schema_version line)
grep -v '"schema_version"' "$SIDECAR" > "${SIDECAR}.tmp" && mv "${SIDECAR}.tmp" "$SIDECAR"
bash "$SCRIPT" --root "$TMP" >/dev/null 2>&1
rc=$?
assert_eq "schema-mismatch exits 1" "1" "$rc"

# 6. Unknown flag exits 2
bash "$SCRIPT" --unknown-flag >/dev/null 2>&1
rc=$?
assert_eq "unknown flag exits 2" "2" "$rc"

# 7. Zero gh subprocess invocations
count=$(grep -c '^[[:space:]]*gh ' "$SCRIPT" || true)
assert_eq "zero direct gh subprocess calls" "0" "$count"

rm -rf "$TMP"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m013-p01-github-status.sh"
  exit 0
fi
echo "FAIL: m013-p01-github-status.sh ($fail_count failures)"
exit 1
```

### Step 4: Create `scripts/verify/m013-p01-github-status-command.sh`

Short gate: the markdown command file follows MEM012 structure.

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p01-github-status-command.sh
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CMD="${REPO_ROOT}/commands/github-status.md"

fail_count=0
assert_ok() { if [ "$1" -eq 0 ]; then echo "PASS: $2"; else echo "FAIL: $2"; fail_count=$((fail_count + 1)); fi; }

[ -f "$CMD" ]; assert_ok $? "command markdown exists"
grep -q "^description:" "$CMD"; assert_ok $? "has description frontmatter field"
grep -q "^## Prerequisites" "$CMD"; assert_ok $? "has Prerequisites section"
grep -q "^## Core Workflow" "$CMD"; assert_ok $? "has Core Workflow section"
grep -q "^## Output" "$CMD"; assert_ok $? "has Output section"
grep -q "^## Idempotency" "$CMD"; assert_ok $? "has Idempotency section"
grep -q "^## Error Handling" "$CMD"; assert_ok $? "has Error Handling section"
grep -q "^## Referenced Scripts" "$CMD"; assert_ok $? "has Referenced Scripts section"
grep -q "scripts/integrations/github-status.sh" "$CMD"; assert_ok $? "references github-status.sh by path"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m013-p01-github-status-command.sh"
  exit 0
fi
echo "FAIL: m013-p01-github-status-command.sh ($fail_count failures)"
exit 1
```

## Must-Haves

- `scripts/integrations/github-status.sh` distinguishes `absent` / `pending-operator-complete` / `configured` strictly by reading the sidecar file — no network calls.
- `commands/github-status.md` follows MEM012 structure and names the script in Referenced Scripts.
- Both verify gates pass.

## Verification

- `bash scripts/verify/m013-p01-github-status.sh`
- `bash scripts/verify/m013-p01-github-status-command.sh`

## Inputs

### From Previous Tasks

- `templates/github-integration-sidecar.json` (from T01)
  - Key API: JSON file with top-level fields `schema_version, repo_slug, project_v2_id, sync_mode, recommended_cron, custom_field_mappings, items`. Every string field that is not yet operator-completed holds the literal value `"pending"`.
- `scripts/integrations/sidecar-init-pending.sh` (from T01)
  - Key API: `bash sidecar-init-pending.sh [--root <dir>]` — writes `.orchestrator/integrations/github.json` derived from the template, stripping `_schema_docs`. Exits 0 on write, 2 on clobber-refuse.

### From Disk (Pre-existing)

- `commands/status.md`, `commands/verify.md` — reference for command-markdown structure (MEM012).
- `scripts/util/json-field.sh` — optional; current script uses plain `grep`/`sed` for simplicity.

## Constraints

- Bash 3.2 compatible (no `declare -A`, etc.).
- Zero `gh` subprocess invocations in `github-status.sh` — P01 is the scaffold; gh wiring is P02. The gate script enforces this mechanically.
- Single-script-file shape (AD-19) for all `Check:` commands — the gates above are self-contained scripts with no command-substitution-with-pipes at the outer level.
- Script output must be greppable: one `STATUS:` line as the first line of stdout, additional context lines prefixed with uppercase tags (`REPO_SLUG:`, `CACHE_ITEMS:`, etc.) per MEM001.
- Exit 0 is correct for `absent`, `pending-operator-complete`, and `configured` alike — this is a reporter, not a gate. Exit 1 only on malformed state, exit 2 only on invalid args.

## Expected Output

- `scripts/integrations/github-status.sh` created.
- `commands/github-status.md` created.
- `scripts/verify/m013-p01-github-status.sh` created.
- `scripts/verify/m013-p01-github-status-command.sh` created.
- `bash scripts/verify/m013-p01-github-status.sh` → `PASS: m013-p01-github-status.sh`, exit 0.
- `bash scripts/verify/m013-p01-github-status-command.sh` → `PASS: m013-p01-github-status-command.sh`, exit 0.
