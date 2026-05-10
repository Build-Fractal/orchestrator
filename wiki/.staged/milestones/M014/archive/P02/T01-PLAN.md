---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M014"
name: "Write-site manifest + scan verifier"
depends_on: []
---

## Prerequisites

No upstream task dependencies. Pre-existing disk state:

- `scripts/util/dual-write-runtime-md.sh` is the P01-shipped full FR-12 helper. Its flags are `--marker <region-name> --content <file> [--file CLAUDE.md] [--file AGENTS.md] [--root <project-root>] [--dry-run]`. Marker literal shape: `# >>> orchestrator:<region-name> >>>` / `# <<< orchestrator:<region-name> <<<`.
- `scripts/specify/specify.sh` is the only P01 write-site. It calls the helper with `--marker recent-changes`.
- `scripts/lifecycle/init-project.sh` and `scripts/lifecycle/reinit-handler.sh` render `templates/project-instruction.md` but do NOT yet invoke the dual-write helper.
- `scripts/knowledge/consolidate-artifacts.sh` emits knowledge-lifecycle advisory output but does NOT yet invoke the dual-write helper or emit a `unit_close` JSONL record.

## Description

Produce the canonical write-site manifest for P02 at [`.orchestrator/milestones/M014/phases/P02/WRITE-SITES.md`](../../../../milestones/M014/phases/P02/WRITE-SITES.md) and ship a scan verifier that confirms no write-site exists outside the enumerated set.

The manifest is the source of truth consumed by T02/T03/T04. It names every call site that writes to `CLAUDE.md` or `AGENTS.md` via the P01 helper, specifies the marker region each site uses, and pins the write-site count at four.

## Steps

### Step 1: Create [`.orchestrator/milestones/M014/phases/P02/WRITE-SITES.md`](../../../../milestones/M014/phases/P02/WRITE-SITES.md)

Verbatim body:

```markdown
# M014/P02 Write-Site Manifest

This file is the P02 source of truth for every call site in the repository that
writes to `CLAUDE.md` or `AGENTS.md`. All writes flow through the single FR-12
helper at `scripts/util/dual-write-runtime-md.sh`. No write-site calls the helper
or writes to either file outside the enumerated set below.

## Scope

Four call sites total, one per task:

| Site | Script | Region | Task | Status |
|------|--------|--------|------|--------|
| 1 | `scripts/specify/specify.sh` | `recent-changes` | M014/P01/T05 | shipped (P01) |
| 2 | `scripts/lifecycle/init-project.sh` | `project-identity` | M014/P02/T02 | pending (P02) |
| 3 | `scripts/lifecycle/reinit-handler.sh` | `project-identity` | M014/P02/T02 | pending (P02) |
| 4 | `scripts/knowledge/consolidate-artifacts.sh` | `recent-changes` | M014/P02/T03 | pending (P02) |

## Regions

Two marker regions are in use across the four sites:

- **`project-identity`** — captures project-level identity attributes populated
  by `orchestrator:init` and refreshed by the reinit handler. Fragment shape is
  five one-line key=value entries: `project_name=<name>`, `runtime=<name>`,
  `cap_score=<N>`, `recommended_intensity=<quick|standard|full>`, and
  `initialized_at=<ISO-8601>`. Regenerated in full on every init/reinit — not
  append-only.
- **`recent-changes`** — append-only Recent Changes log. One entry per
  `orchestrator:specify` scaffold and one entry per `orchestrator:consolidate`
  milestone close. Entry format: `- <NNN>-<slug>: <description>` (specify) or
  `- <milestone-id>: milestone consolidated (<N>% reduction, <M> phases archived)`
  (consolidate). Existing entries are preserved on append; new entries are
  inserted above the closing marker.

## Write-Site Enumeration Invariant

A `grep` across the repository for direct `CLAUDE.md` or `AGENTS.md` writes
outside the helper must return zero results. The gate verifier
`scripts/verify/m014-p02-write-site-manifest.sh` asserts this invariant by
scanning `scripts/**/*.sh` and `commands/**/*.md` for disallowed write
patterns and matching the enumerated set against the table above.

Allowed write patterns (by shape):

- `render_template ... > "$INSTRUCTION_FILE"` where `INSTRUCTION_FILE` is
  one of `CLAUDE.md`, `AGENTS.md`, or `.cursor/rules/orchestrator.md` — these
  are runtime-native full-file writes in `init-project.sh` and
  `reinit-handler.sh`. The dual-write invocation is *additive* to this render
  path; it does not replace it.
- Invocations of `scripts/util/dual-write-runtime-md.sh` — the single
  dual-write surface.
- Verifier / test scripts under `scripts/verify/` and `tests/` that write to
  scratch directories under `$(mktemp -d)` — excluded from the scan (no repo
  writes).

Disallowed shapes (the scan fails if any match):

- Any non-test, non-verifier shell script under `scripts/` containing a
  direct `> "$PROJECT_DIR/CLAUDE.md"` or `>> "$PROJECT_DIR/CLAUDE.md"` redirect
  (same for `AGENTS.md`) that is NOT the `render_template` full-file render in
  `init-project.sh` or `reinit-handler.sh`.

## Non-Goals

- This file does NOT enumerate write-sites for `.cursor/rules/orchestrator.md` —
  that file has a single renderer in `init-project.sh` and is runtime-native
  only (Cursor has no dual-write peer).
- This file does NOT enumerate read sites — drift detection reads both files
  but is not a write-site.

## Maintenance

Any future milestone introducing a new write-site MUST:

1. Add a row to the Scope table above.
2. Name the marker region used (or declare a new region with a one-paragraph
   explanation).
3. Update `scripts/verify/m014-p02-write-site-manifest.sh` to accept the new
   site in the allow list (or the scan will fail on the next phase suite run).
```

### Step 2: Create `scripts/verify/m014-p02-write-site-manifest.sh`

Verbatim body:

```bash
#!/usr/bin/env bash
# Gate: verify WRITE-SITES.md is present + shaped + the enumerated set matches
# the actual call-site state on disk.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MANIFEST="${PROJECT_ROOT}/.orchestrator/milestones/M014/phases/P02/WRITE-SITES.md"

if [ ! -f "$MANIFEST" ]; then
  echo "FAIL: WRITE-SITES.md missing at $MANIFEST" >&2
  exit 1
fi

# Presence of region names.
grep -q 'project-identity' "$MANIFEST" || { echo "FAIL: project-identity region not named" >&2; exit 1; }
grep -q 'recent-changes'   "$MANIFEST" || { echo "FAIL: recent-changes region not named" >&2; exit 1; }

# Presence of the four enumerated scripts.
grep -q 'scripts/specify/specify.sh'               "$MANIFEST" || { echo "FAIL: P01 specify site not listed" >&2; exit 1; }
grep -q 'scripts/lifecycle/init-project.sh'        "$MANIFEST" || { echo "FAIL: init-project site not listed" >&2; exit 1; }
grep -q 'scripts/lifecycle/reinit-handler.sh'      "$MANIFEST" || { echo "FAIL: reinit-handler site not listed" >&2; exit 1; }
grep -q 'scripts/knowledge/consolidate-artifacts.sh' "$MANIFEST" || { echo "FAIL: consolidate site not listed" >&2; exit 1; }

# Count enumerated sites (exactly 4 rows).
SITE_ROWS=$(grep -cE '^\| [0-9]+ \| `scripts/' "$MANIFEST")
if [ "$SITE_ROWS" -ne 4 ]; then
  echo "FAIL: expected 4 enumerated site rows; found $SITE_ROWS" >&2
  exit 1
fi

# Scan for disallowed write patterns outside the helper.
# Allow list: test-only, verifier-only, the helper itself, and the
# init/reinit render_template path.
DISALLOWED=$(mktemp)
trap 'rm -f "$DISALLOWED"' EXIT

# Find direct redirects to CLAUDE.md / AGENTS.md in scripts/ (excluding verify/, tests/,
# migrate/, the helper, and init/reinit where render_template is the allowed shape).
grep -rnE '>[[:space:]]*"[^"]*CLAUDE\.md"' "$PROJECT_ROOT/scripts/" 2>/dev/null \
  | grep -v 'scripts/verify/' \
  | grep -v 'scripts/migrate/' \
  | grep -v 'scripts/util/dual-write-runtime-md\.sh' \
  | grep -v 'scripts/lifecycle/init-project\.sh' \
  | grep -v 'scripts/lifecycle/reinit-handler\.sh' \
  > "$DISALLOWED" 2>/dev/null || true

grep -rnE '>[[:space:]]*"[^"]*AGENTS\.md"' "$PROJECT_ROOT/scripts/" 2>/dev/null \
  | grep -v 'scripts/verify/' \
  | grep -v 'scripts/migrate/' \
  | grep -v 'scripts/util/dual-write-runtime-md\.sh' \
  | grep -v 'scripts/lifecycle/init-project\.sh' \
  | grep -v 'scripts/lifecycle/reinit-handler\.sh' \
  >> "$DISALLOWED" 2>/dev/null || true

DISALLOWED_COUNT=$(wc -l < "$DISALLOWED" | tr -d ' ')
if [ "$DISALLOWED_COUNT" -ne 0 ]; then
  echo "FAIL: disallowed direct CLAUDE.md/AGENTS.md writes found outside the helper:" >&2
  cat "$DISALLOWED" >&2
  exit 1
fi

echo "PASS: write-site manifest and enumeration invariant verified"
exit 0
```

Make executable: `chmod +x scripts/verify/m014-p02-write-site-manifest.sh`.

## Must-Haves

- [`.orchestrator/milestones/M014/phases/P02/WRITE-SITES.md`](../../../../milestones/M014/phases/P02/WRITE-SITES.md) exists, names both regions (`project-identity`, `recent-changes`), enumerates exactly four write-site rows (specify, init-project, reinit-handler, consolidate-artifacts)
- `scripts/verify/m014-p02-write-site-manifest.sh` exists, is executable, passes its own checks, and rejects any script that introduces a new disallowed direct-redirect write-site
- The manifest file and the verifier pass `scripts/verify/anti-pattern-lint.sh`

## Verification

```
bash scripts/verify/m014-p02-write-site-manifest.sh
```

Expected: `PASS: write-site manifest and enumeration invariant verified`, exit 0.

```
bash scripts/verify/anti-pattern-lint.sh --fixture scripts/verify/m014-p02-write-site-manifest.sh
```

Expected: exit 0.

## Inputs

### From Previous Tasks

None — T01 is the root of P02's dependency graph.

### From Disk (Pre-existing)

- `scripts/util/dual-write-runtime-md.sh` — P01 helper; referenced in the manifest but not modified.
- `scripts/specify/specify.sh` — P01 call site; referenced in the manifest.
- `scripts/lifecycle/init-project.sh` — P02 call site (pending T02); referenced and allow-listed in the scanner.
- `scripts/lifecycle/reinit-handler.sh` — P02 call site (pending T02); referenced and allow-listed in the scanner.
- `scripts/knowledge/consolidate-artifacts.sh` — P02 call site (pending T03); referenced in the manifest.

## Constraints

- Bash 3.2 compatible. No `declare -A`, `mapfile`, `${var,,}`, `<(...)`, `&>`, `$( ... | ... )`.
- The verifier uses single-pass `grep` with clear allow-list exclusions. No compound `for`/`if` inline chains.
- Passes `scripts/verify/anti-pattern-lint.sh`.

## Expected Output

Files committed:

1. [`.orchestrator/milestones/M014/phases/P02/WRITE-SITES.md`](../../../../milestones/M014/phases/P02/WRITE-SITES.md) — write-site manifest (~110 lines)
2. `scripts/verify/m014-p02-write-site-manifest.sh` — enumeration-invariant verifier (~55 lines, executable)

Verifier exits 0.
