---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M013"
name: "scripts/integrations/github-init.sh — create-path implementation (preflights + lazy projection + sidecar population)"
depends_on: ["T01"]
---

## Prerequisites

- T01 has landed `scripts/integrations/github-common.sh` with function stubs and the `tests/fixtures/m013-p02/` fixture tree.
- `scripts/integrations/sidecar-init-pending.sh` (from P01/T01) — invoked under auto-mode to write the pending sentinel.
- `scripts/integrations/github-status.sh` (from P01/T02) — used to re-check status after init completes.
- `templates/github-integration-sidecar.json` (from P01/T01) — the canonical schema template; this task populates `repo_slug`, `project_v2_id`, `sub_issue_mode`, and `items.<id>` entries on a live run.
- FR-2 (auth preflight), FR-4 (marker invariant emit side + search-before-create), FR-6 (per-item cache schema), FR-14 (label-collision preflight + adopt-mode / `--strict-labels` refuse-mode — **adopt-mode only on create; re-init adoption from sidecar-absent + marker-bearing remote is P03**), US-1 AS-4a (lazy projection on Ready-state phases/tasks only), SC-7 (zero prompts under auto-mode).
- Bash 3.2 compatibility required (MEM001). No `declare -A`, no `mapfile`, no `<(...)`, no `&>`, no `${var^^}`.

## Description

Author `scripts/integrations/github-init.sh` — the US-1 create-path workhorse. The script:

1. **Parses flags**: `--dry-run`, `--i-am-operator` (gates live `gh` writes), `--strict-labels`, `--root <project-root>`, `--repo-slug <owner/name>` (optional override; else read from `gh repo view`), `-h`/`--help`.
2. **Auto-mode path**: if no TTY is attached AND sidecar is absent, invoke the P01 pending-sentinel helper and exit 0 with `STATUS: pending-operator-complete`. This is the SC-7 zero-prompts path.
3. **Preflights** (live run only; `--dry-run` uses fixture stubs):
   - `gh_auth_preflight` — enumerate scopes; fail fast on missing `project` / `repo` scopes.
   - `gh_subissue_rest_preflight` — probe sub-issue REST endpoint; set `sub_issue_mode` to `native` or `labeled-fallback`.
   - `gh_label_collision_preflight` — adopt existing labels by default; refuse with `integration-labels-collision` diagnostic on `--strict-labels` + non-matching color.
4. **Walks orchestrator state** (lazy per AS-4a): only phases marked Ready/Executing/Verifying are projected; Planning-state phases are NOT. Task filter: only tasks under projected phases with state Ready or later.
5. **Manifest build** (shared with `--dry-run`): for each projected resource emit one `UPSERT:` line. Format pinned by T03 contract — T02 produces manifest lines; T03 authors the format gate.
6. **Create phase**: for each resource with `UPSERT: ... create` reason, call the appropriate `gh` command, capture the returned Issue number / Project v2 node ID, and pass to `sidecar_upsert_item` (from T01). On `--dry-run`, skip the `gh` calls and write no sidecar updates.
7. **Marker emit + byte-identity verification**: every Issue body receives exactly one `<!-- orchestrator-id: <id> -->` marker via `emit_marker` (T01). After create, fetch the Issue body back and run `shasum_marker_byte_identity` (T01) to verify byte-identity with the emitted marker. On mismatch, exit non-zero with `integration-marker-mismatch: <id>` diagnostic.
8. **Search-before-create idempotency**: before creating any Issue for `<id>`, run `find_marker_in_body` (T01) over `gh issue list --search "<!-- orchestrator-id: <id> -->" --json number,body` results. On single match: upsert the sidecar entry, skip create. On duplicate match: surface `integration-marker-duplicate: <id>` and refuse to proceed for that id. On zero matches: proceed with create.
9. **Exit summary**: prints `upserts=<N> skipped=<M> errors=<E>` on the final stdout line; non-zero exit if `$E > 0`.

## Steps

### Step 1: Scaffold `scripts/integrations/github-init.sh` header + flag parsing

```bash
#!/usr/bin/env bash
# scripts/integrations/github-init.sh — M013/P02 create path: orchestrator → GitHub.
#
# Usage:
#   github-init.sh [--root <dir>] [--dry-run] [--i-am-operator]
#                  [--strict-labels] [--repo-slug <owner/name>]
#
# Output (stdout):
#   MANIFEST: <upserts> <skipped> <errors>           (first line on --dry-run)
#   UPSERT: <kind> <orchestrator-id> <target> <reason>  (one per resource)
#   STATUS: <absent|pending-operator-complete|configured>  (final line on auto-mode)
#   upserts=<N> skipped=<M> errors=<E>                 (final line on live run)
#
# Exit: 0 on success, 1 on any upsert error, 2 on malformed args, 3 on
#       integration-auth-failed / integration-labels-collision / integration-marker-duplicate.
#
# Bash 3.2 compatible. No declare -A, no mapfile. Auto-mode (no TTY) writes
# pending-sentinel via scripts/integrations/sidecar-init-pending.sh and exits 0
# with STATUS: pending-operator-complete — preserving SC-7 zero-prompts.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DRY_RUN=0
OPERATOR=0
STRICT_LABELS=0
REPO_SLUG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --i-am-operator) OPERATOR=1; shift ;;
    --strict-labels) STRICT_LABELS=1; shift ;;
    --repo-slug) REPO_SLUG="$2"; shift 2 ;;
    -h|--help)
      sed -n '3,12p' "$0"
      exit 0
      ;;
    *) echo "github-init.sh: unknown flag: $1" >&2; exit 2 ;;
  esac
done

# shellcheck disable=SC1091
. "${PROJECT_ROOT}/scripts/integrations/github-common.sh"
```

### Step 2: Auto-mode pending-sentinel path (SC-7)

```bash
# Auto-mode detection: no TTY on stdin means this is a non-interactive dispatch.
# Under auto mode, NEVER call `gh` for writes. Write pending sentinel and exit.
if [ ! -t 0 ] && [ "$OPERATOR" -ne 1 ]; then
  SIDECAR="$(sidecar_path "$PROJECT_ROOT")"
  if [ ! -f "$SIDECAR" ]; then
    bash "${PROJECT_ROOT}/scripts/integrations/sidecar-init-pending.sh" --root "$PROJECT_ROOT" >/dev/null
  fi
  echo "STATUS: pending-operator-complete"
  echo "HINT: run 'orchestrator:github init' interactively (or with --i-am-operator) to populate the sidecar."
  exit 0
fi
```

### Step 3: Preflights (live path) + stubbed path (dry-run)

Fill in T01's `gh_auth_preflight`, `gh_subissue_rest_preflight`, `gh_label_collision_preflight` with live `gh` invocations for the live path. Under `--dry-run`, substitute responses from `tests/fixtures/m013-p02/gh-stub-responses/` when the fixture override env var `M013_GH_STUB_DIR` is set (CI mode).

Auth preflight:

```bash
gh_auth_preflight() {
  if [ -n "${M013_GH_STUB_DIR:-}" ]; then
    cat "${M013_GH_STUB_DIR}/auth-status-green.txt"
    return 0
  fi
  if ! gh auth status 2>/dev/null | grep -q "Logged in to"; then
    echo "integration-auth-failed: gh auth status reports no session" >&2
    return 1
  fi
  # Scope enumeration: gh auth status --show-token is privileged; instead use
  # `gh api user --jq '.login'` and `gh api user -i` to read oauth scopes from response headers.
  # Required scopes: project, repo, read:org.
  if ! gh api user -i 2>/dev/null | grep -qi "X-Oauth-Scopes:.*project"; then
    echo "integration-auth-failed: missing scope project" >&2
    return 1
  fi
  return 0
}
```

Sub-issue REST preflight:

```bash
gh_subissue_rest_preflight() {
  local slug="$1"
  if [ -n "${M013_GH_STUB_DIR:-}" ]; then
    if grep -q '"documentation_url"' "${M013_GH_STUB_DIR}/subissue-rest-available.json"; then
      echo "SUBISSUE_MODE: native"; return 0
    fi
    echo "SUBISSUE_MODE: labeled-fallback"; return 0
  fi
  local code
  code=$(gh api "/repos/${slug}/issues/1/sub_issues" -i 2>/dev/null | head -1 | awk '{print $2}')
  if [ "$code" = "404" ] || [ "$code" = "501" ]; then
    echo "SUBISSUE_MODE: labeled-fallback"
  else
    echo "SUBISSUE_MODE: native"
  fi
  return 0
}
```

Label preflight: enumerate `phase`, `task`, `uat-bug`, `spec-gap`. Adopt if present. Refuse if `--strict-labels` AND any pre-existing has non-matching color/description.

### Step 4: State walker — lazy projection

Parse the roadmap file `${PROJECT_ROOT}/.orchestrator/milestones/M###/M###-ROADMAP.md` for the current in-flight milestone. For each phase:

- Phase state: derived from presence of `phases/P##/P##-SUMMARY.md` (Done), `phases/P##/P##-PLAN.md` + `phases/P##/tasks/` (Executing/Verifying), `phases/P##/P##-PLAN.md` without tasks (Ready), nothing (Planning). Use `scripts/state/derive-phase.sh` if applicable, else parse directly.
- Skip Planning-state phases (AS-4a).
- For each projected phase, iterate tasks under `phases/P##/tasks/` — skip tasks whose state is Planning.

Emit UPSERT lines to the manifest buffer:

```
UPSERT: milestone M013 <milestone-url> create
UPSERT: project-v2 M013 <project-v2-node-id> create
UPSERT: label - phase create
UPSERT: label - task create
UPSERT: label - uat-bug create
UPSERT: label - spec-gap create
UPSERT: phase-issue M013-P01 <issue-url> skip-existing-marker
UPSERT: phase-issue M013-P02 <issue-url> create
UPSERT: task-subissue M013-P02-T01 <issue-url> create
UPSERT: task-subissue M013-P02-T02 <issue-url> create
UPSERT: project-v2-item M013-P02 <project-item-id> create
UPSERT: project-v2-item M013-P02-T01 <project-item-id> create
```

(Format pinned by T03 — see T03-PLAN.md for the contract.)

### Step 5: Create phase (live only; dry-run skips)

Under live mode, for each UPSERT line with `create` reason:

- `gh milestone create` → returns milestone URL
- `gh api graphql -F name=... --field 'query=mutation{createProjectV2(...){projectV2{id}}}'` → one of the three FR-5 whitelisted shapes
- `gh label create` → per label
- `gh issue create --label phase --body "<!-- orchestrator-id: <id> -->\n\n<body>"` → per phase
- `gh issue create --label task` + (if `sub_issue_mode=native`) `gh api /repos/.../issues/<phase>/sub_issues -F sub_issue_id=<task>` ELSE labeled-fallback (`parent:<id>` label on phase issue, `child:<id>` label on task issue + reciprocal body link)
- `gh api graphql -F projectId=... -F contentId=... --field 'query=mutation{addProjectV2ItemById(...){item{id}}}'` → second FR-5 whitelisted shape

After each successful Issue create:

1. Fetch body back: `body_file=$(mktemp); gh issue view <num> --json body --jq .body > "$body_file"`
2. `shasum_marker_byte_identity "$body_file" "<id>"` — exit non-zero on mismatch.
3. `sidecar_upsert_item "<id>" <num> true true "$(date -u +%Y-%m-%dT%H:%M:%SZ)"`

### Step 6: Idempotency — marker search-before-create

Before step 5's create for each `<id>`, call:

```bash
# Search for the marker in the repo's open+closed issues. gh issue list caps at
# 1000; for M013 scope this is fine — caller's project sizes are bounded by
# orchestrator milestone count × phases × tasks.
matches=$(gh issue list --state all --search "\"<!-- orchestrator-id: $id -->\"" --json number --jq '. | length' 2>/dev/null || echo 0)
case "$matches" in
  0) reason="create" ;;
  1) reason="skip-existing-marker"
     # upsert the sidecar entry with the existing issue number
     ;;
  *) echo "integration-marker-duplicate: $id" >&2; errors=$((errors+1)); continue ;;
esac
```

### Step 7: Exit summary

On completion, print:

```bash
if [ "$DRY_RUN" -eq 1 ]; then
  # Header line first, then manifest body already printed.
  : # manifest format pinned in T03
fi
echo "upserts=$upserts skipped=$skipped errors=$errors"
[ "$errors" -gt 0 ] && exit 1
exit 0
```

## Must-Haves

- `scripts/integrations/github-init.sh` ≥200 lines, contains `pending-operator-complete`.
- All three preflight helpers in `github-common.sh` (stubbed at T01) are now populated with live + fixture-stub code paths.
- Auto-mode (no TTY, no `--i-am-operator`) writes pending-sentinel via P01 helper and exits 0 with `STATUS: pending-operator-complete` — zero `gh` calls.
- Live mode writes back `repo_slug`, `project_v2_id`, `sub_issue_mode`, and one `items.<orchestrator-id>` entry per created Issue.
- Planning-state phases are NOT projected; only Ready/Executing/Verifying phases/tasks are.
- Every Issue body contains exactly one `<!-- orchestrator-id: <id> -->` marker, verified byte-identical via `shasum` read-back.
- Re-running with unchanged state produces `upserts=0` via marker search-before-create.
- Bash 3.2 clean (`bash -n` passes; anti-pattern-lint green).

## Verification

```bash
bash scripts/verify/m013-p02-github-init-fixture.sh
```

Expected: `PASS: github-init.sh fixture-driven dry-run matches expected-manifest.txt byte-identical` and exit 0.

```bash
bash scripts/verify/m013-p02-github-init-preflight.sh
```

Expected: `PASS: auth/subissue/labels preflights emit FR-2 / AS-4a diagnostic shapes under stub responses` and exit 0.

```bash
bash scripts/verify/m013-p02-auto-mode-pending.sh
```

Expected: `PASS: auto-mode (no TTY) writes pending-sentinel sidecar and exits 0 with STATUS: pending-operator-complete, zero gh subprocess calls` and exit 0.

## Inputs

### From Previous Tasks

- `scripts/integrations/github-common.sh` (from T01)
  - Key API: `orchestrator_id_for`, `emit_marker`, `find_marker_in_body`, `shasum_marker_byte_identity`, `sidecar_path`, `sidecar_get_field`, `sidecar_set_top_field`, `sidecar_upsert_item`, `sidecar_item_exists`, `gh_auth_preflight`, `gh_subissue_rest_preflight`, `gh_label_collision_preflight` (last three T01-stubbed, T02 fills).
  - T02 consumes by sourcing the file at the top (line ~25).
- `tests/fixtures/m013-p02/orchestrator-state/` (from T01)
  - Seed layout used with `--root tests/fixtures/m013-p02/orchestrator-state/` under dry-run.
- `tests/fixtures/m013-p02/gh-stub-responses/*.{txt,json}` (from T01)
  - Consumed via `M013_GH_STUB_DIR` env var in preflights.

### From Disk (Pre-existing)

- `scripts/integrations/sidecar-init-pending.sh` (P01/T01) — auto-mode bootstrap.
- `scripts/integrations/github-status.sh` (P01/T02) — used in the `HINT:` line after auto-mode.
- `templates/github-integration-sidecar.json` (P01/T01) — canonical schema; `sub_issue_mode` field added by T06.
- `gh` CLI (external runtime dependency) — required for live runs.
- `scripts/verify/anti-pattern-lint.sh` (M016/[M021](../../../../../milestones/M021/index.md) invariant) — T07 gate consumes.

## Constraints

- **FR-12 Claude-Code-only v1**: no branching on runtime. This script is invoked identically across Claude Code / Codex / Cursor. Hook installation (P04) is the runtime-aware piece, not this create script.
- **SC-7 zero prompts under auto-mode**: never call `gh` for writes without a TTY AND `--i-am-operator`. The auto-mode path exits before any `gh` call.
- **Constitution XII (Hook Isolation)** + **Constitution IX (Bash 3.2)**: no wrappers that change child process env; exit non-zero on preflight failure — never fallback to graceful degradation ([M007](../../../../../milestones/M007/index.md) principle).
- **Knowledge-Layer Boundary (FR-9 + D014)**: do NOT modify any `knowledge/spec/**/SPEC-*.md` frontmatter. Do NOT extend `scripts/knowledge/rebuild-index.sh`. Do NOT touch `KNOWLEDGE-INDEX.md`.
- **FR-4 marker invariant**: every Issue body carries exactly one marker, verified by `shasum` byte-identity. A duplicate marker at any layer is a bug.
- **FR-5 three-shape GraphQL whitelist**: this script's GraphQL usage is limited to `createProjectV2`, `addProjectV2ItemById`, `updateProjectV2ItemFieldValue`. `updateProjectV2ItemFieldValue` is NOT called from init (P04 owns status transitions); only the first two fire in P02. The third is P04.
- **Re-init adoption NOT in scope**: P03 owns the sidecar-absent + marker-bearing remote adoption path. T02 only handles create + marker-search-before-create idempotency (the case where sidecar and remote agree).
- **No compound bash in `Check:` lines** — applies to plan/verify scripts, not to this implementation script's internals.

## Expected Output

Dry-run against the T01 fixture tree produces a manifest matching `tests/fixtures/m013-p02/expected-manifest.txt` byte-identical. Auto-mode produces the SC-7 pending-sentinel path. Live mode (not CI-exercised; verified at operator dogfood) populates the sidecar and creates marker-bearing Issues.

The T07 phase-suite gate reports:

```
PASS: github-init.sh present at scripts/integrations/github-init.sh
PASS: --dry-run against fixture tree matches expected-manifest.txt
PASS: preflight helpers emit expected diagnostic shapes under stub responses
PASS: auto-mode (no TTY) writes pending-sentinel and exits 0
PASS: bash -n github-init.sh (Bash 3.2 syntax check)
PASS: anti-pattern-lint clean on github-init.sh
```
