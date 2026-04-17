---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P06"
milestone: "M011"
name: "commands/ingest.md + evaluate.md cross-link + doc-shape verify scripts"
depends_on: []
---

## Prerequisites

- P03 is complete: `scripts/knowledge/ingest-spec.sh` exists (see `/Users/brettkellgren/Sites/lakeledger/spec-kit-orchestrator/scripts/knowledge/ingest-spec.sh`, 837 lines). It accepts `--spec-path <path>`, `--slug <slug>`, and `--scope-tags <tags>`. It emits `CREATED:`, `SKIPPED:`, `SUPERSEDED:`, `REMOVED:`, and `REVIEW:` prefixed lines to stdout, exits 0 on success / 1 on failure, and is Bash 3.2 compatible. It calls `rebuild-index.sh` once at the end.
- P05 is complete: `scripts/state/spec-metrics.sh` emits `spec_chunks_present=true|false` and seven other `key=value` lines. `commands/evaluate.md` (199 lines) already has a "Chunks-first path" branch that calls `spec-metrics.sh`, and `commands/roadmap.md` (169 lines) already documents the chunks-first decomposition.
- The existing command file convention (MEM012) is followed by every file in `commands/`: YAML frontmatter (`description:`), `# speckit.orchestrator.<name>` title, Prerequisites section, one or more workflow sections (numbered steps or named headings), Output section, Idempotency section, Error Handling section, Reference Files section.
- No `commands/ingest.md` currently exists. `commands/evaluate.md` does not currently reference the ingest command by name.

## Description

T01 delivers the user-facing `orchestrator:ingest` command document and the small cross-link from `commands/evaluate.md` so users discover ingest before running evaluate on an un-chunked spec. T01 also delivers four doc-shape verify scripts that lock the structure down so subsequent edits cannot silently drop required content.

Two artifact edits:

1. **Create `commands/ingest.md`** — a new user-facing command that wraps `scripts/knowledge/ingest-spec.sh`. Documents the three flags (`--spec-path`, `--slug`, `--milestone`), the spec-slug → milestone mapping written into `<milestone-dir>/M###-EVALUATION.md`, and re-ingest semantics (SKIPPED/SUPERSEDED/REMOVED output from P03, plus `--force` gate).

2. **Edit `commands/evaluate.md`** — insert a one-sentence mention of `orchestrator:ingest` in the Chunks-first path callout so users discover the upstream ingest step. This is a pure-additive edit; no deletions.

Four verify scripts codify the doc shape:

- `m011-p06-ingest-doc-structure.sh` — ingest.md contains required section headings and flag names.
- `m011-p06-ingest-doc-conventions.sh` — ingest.md matches the shared MEM012 command-file shape (frontmatter + standard sections).
- `m011-p06-ingest-doc-reingest-contract.sh` — ingest.md names SKIPPED/SUPERSEDED/REMOVED and mentions `--force`.
- `m011-p06-evaluate-doc-mentions-ingest.sh` — evaluate.md references `orchestrator:ingest` at least once.

No production code changes beyond the two markdown files.

## Steps

### Step 1: Create `commands/ingest.md`

Write a new file at `/Users/brettkellgren/Sites/lakeledger/spec-kit-orchestrator/commands/ingest.md` with the shape below (min 120 lines). The exact wording may be adjusted, but every pattern the verify scripts check must be present literally (see the Must-Haves + verify-script lists).

Required content anchors:

- **YAML frontmatter**: `description: "Use when ingesting a markdown spec into the orchestrator's knowledge system. Chunks the spec into spec/story, spec/requirement, spec/acceptance, spec/constraint, spec/nfr, and spec/non-goal entries, then rebuilds the knowledge index so downstream commands (evaluate, roadmap, plan-phase, dispatch) can read spec-chunk metrics and graph edges instead of re-parsing the raw spec."`
- **Title**: `# speckit.orchestrator.ingest`
- **Prerequisites** section explaining the required spec file must exist and be markdown.
- **Usage** section with the canonical invocation shape:

  ```bash
  bash scripts/knowledge/ingest-spec.sh --spec-path <path-to-spec.md> --slug <feature-slug>
  ```

  And the three user-facing flags this command documents:
  - `--spec-path <path>` — required; absolute or repo-relative path to the markdown spec.
  - `--slug <slug>` — required; kebab-case identifier (e.g., `016-autonomous-hardening`); used as `scope_tags: "[spec:<slug>]"` when `--scope-tags` is not supplied.
  - `--milestone <M###>` — optional; records the spec slug → milestone mapping in `<milestone-dir>/M###-EVALUATION.md` via a `spec_slug:` field append. When omitted, no evaluation-file edit happens.

- **Workflow** section (numbered steps): (1) validate spec-path exists and is readable; (2) invoke `ingest-spec.sh`; (3) capture the CREATED/SKIPPED/SUPERSEDED/REMOVED counts from stdout; (4) if `--milestone M###` is supplied and `<milestone-dir>/M###-EVALUATION.md` exists, append or update a `spec_slug: <slug>` line in the evaluation file frontmatter; (5) rebuild the knowledge index (ingest-spec.sh already does this internally — documented here so users understand the whole-system effect); (6) report chunk counts and suggest the next command (`orchestrator:evaluate` or `orchestrator:roadmap`).

- **Re-ingest / Idempotency** section. Quote the P03 behavior verbatim: re-running `orchestrator:ingest` on the same spec emits `SKIPPED:` for unchanged chunks, `SUPERSEDED:` when content changes (old chunk gets `superseded_by:` and a new versioned chunk is created), and `REMOVED:` for chunks whose source section disappeared. Require `--force` (or interactive confirmation) when re-ingesting so users do not inadvertently supersede chunks during draft iteration. The re-ingest section MUST contain the literal substrings `SKIPPED:`, `SUPERSEDED:`, `REMOVED:`, and `--force`.

- **Error Handling** section covering missing spec file, unreadable spec file, missing slug, and failure from `ingest-spec.sh` (non-zero exit).

- **Reference Files** section listing (at minimum):
  - `scripts/knowledge/ingest-spec.sh`
  - `scripts/knowledge/rebuild-index.sh`
  - `scripts/state/spec-metrics.sh`
  - `scripts/dispatch/scope-filter.sh`
  - `knowledge/spec/` (directory where chunks land)

### Step 2: Edit `commands/evaluate.md`

Add a single sentence to the "Chunks-first path" block in `commands/evaluate.md` (around line 42–48) naming the ingest command. Example insertion (wording may be tuned, but `orchestrator:ingest` must appear verbatim):

```
   **Chunks-first path** (when a spec has been ingested via `orchestrator:ingest`):
```

The existing line already contains this phrasing — T01 only needs to confirm it (no edit required if the literal `orchestrator:ingest` already appears). If the literal string is absent, add a parenthetical "(run `orchestrator:ingest` to produce these chunks)" after the first mention of spec chunks in the Chunks-first section.

Do NOT modify any Reference Files bullet, any other section, or any line outside the Chunks-first block. The `m011-p06-commands-preserve-references.sh` regression (T03) will fail if any prior Reference File bullet disappears.

### Step 3: Write `scripts/verify/m011-p06-ingest-doc-structure.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m011-p06-ingest-doc-structure.sh
# Assert commands/ingest.md contains every required flag name,
# section heading, and user-facing entry-point identifier.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO/commands/ingest.md"

fail=0

if [ ! -f "$DOC" ]; then
  printf 'FAIL[exists]: %s not found\n' "$DOC"
  exit 1
fi

REQUIRED="
orchestrator:ingest
--spec-path
--slug
--milestone
scripts/knowledge/ingest-spec.sh
"

for p in $REQUIRED; do
  if ! grep -Fq "$p" "$DOC"; then
    printf 'FAIL[structure]: commands/ingest.md missing required token: %s\n' "$p"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: commands/ingest.md contains required structural tokens"
```

`chmod +x`.

### Step 4: Write `scripts/verify/m011-p06-ingest-doc-conventions.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m011-p06-ingest-doc-conventions.sh
# Assert commands/ingest.md follows the shared command-file conventions
# (MEM012): frontmatter description, title, Prerequisites, Reference Files.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO/commands/ingest.md"

fail=0

# Frontmatter must exist as the first non-empty line block.
if ! head -1 "$DOC" | grep -Fxq "---"; then
  printf 'FAIL[frontmatter]: commands/ingest.md missing leading --- fence\n'
  fail=1
fi

# Required section headings (case-sensitive).
HEADINGS="
# speckit.orchestrator.ingest
## Prerequisites
## Reference Files
"

# Using awk so multi-line heading content match is unambiguous.
check_heading() {
  local h="$1"
  if ! grep -Fxq "$h" "$DOC"; then
    printf 'FAIL[heading]: commands/ingest.md missing heading: %s\n' "$h"
    fail=1
  fi
}

check_heading "# speckit.orchestrator.ingest"
check_heading "## Prerequisites"
check_heading "## Reference Files"

# description: field in frontmatter.
if ! grep -q '^description:' "$DOC"; then
  printf 'FAIL[description]: commands/ingest.md frontmatter missing description: field\n'
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: commands/ingest.md follows MEM012 conventions"
```

`chmod +x`.

### Step 5: Write `scripts/verify/m011-p06-ingest-doc-reingest-contract.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m011-p06-ingest-doc-reingest-contract.sh
# Assert commands/ingest.md documents the P03 re-ingest contract:
# SKIPPED:, SUPERSEDED:, REMOVED: output prefixes + --force gate.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO/commands/ingest.md"

fail=0

REQUIRED="
SKIPPED:
SUPERSEDED:
REMOVED:
--force
"

for tok in $REQUIRED; do
  if ! grep -Fq "$tok" "$DOC"; then
    printf 'FAIL[reingest]: commands/ingest.md missing re-ingest token: %s\n' "$tok"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "PASS: commands/ingest.md documents the P03 re-ingest contract"
```

`chmod +x`.

### Step 6: Write `scripts/verify/m011-p06-evaluate-doc-mentions-ingest.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m011-p06-evaluate-doc-mentions-ingest.sh
# Assert commands/evaluate.md references orchestrator:ingest at least once.

set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO/commands/evaluate.md"

if ! grep -Fq "orchestrator:ingest" "$DOC"; then
  printf 'FAIL[evaluate-mentions-ingest]: commands/evaluate.md does not reference orchestrator:ingest\n'
  exit 1
fi

echo "PASS: commands/evaluate.md references orchestrator:ingest"
```

`chmod +x`.

### Step 7: Run the four new verify scripts

```
bash scripts/verify/m011-p06-ingest-doc-structure.sh
bash scripts/verify/m011-p06-ingest-doc-conventions.sh
bash scripts/verify/m011-p06-ingest-doc-reingest-contract.sh
bash scripts/verify/m011-p06-evaluate-doc-mentions-ingest.sh
```

All four must print `PASS:` and exit 0.

## Must-Haves

- `commands/ingest.md` exists with the documented structure (frontmatter, title, Prerequisites, Usage, Workflow, Re-ingest / Idempotency, Error Handling, Reference Files).
- `commands/ingest.md` names the three user-facing flags (`--spec-path`, `--slug`, `--milestone`) and the wrapped script (`scripts/knowledge/ingest-spec.sh`).
- `commands/ingest.md` documents the re-ingest contract: `SKIPPED:`, `SUPERSEDED:`, `REMOVED:`, and `--force`.
- `commands/evaluate.md` references `orchestrator:ingest` at least once.
- Four verify scripts created, executable, each printing `PASS:` and exiting 0.

## Verification

```
bash scripts/verify/m011-p06-ingest-doc-structure.sh
bash scripts/verify/m011-p06-ingest-doc-conventions.sh
bash scripts/verify/m011-p06-ingest-doc-reingest-contract.sh
bash scripts/verify/m011-p06-evaluate-doc-mentions-ingest.sh
```

Each must print a `PASS:` line and exit 0.

## Inputs

### From Previous Tasks

None — T01 has no in-phase dependencies.

### From Disk (Pre-existing)

- `scripts/knowledge/ingest-spec.sh` — the production script `commands/ingest.md` wraps. Key API: `ingest-spec.sh --spec-path <path> --slug <slug> [--scope-tags <tags>]`. Emits `CREATED:`, `SKIPPED:`, `SUPERSEDED:`, `REMOVED:`, `REVIEW:` prefix lines to stdout. Exits 0 on success, 1 on failure. Calls `rebuild-index.sh` once internally at the end.
- `scripts/knowledge/rebuild-index.sh` — invoked internally by ingest-spec.sh; documented in ingest.md's Reference Files block.
- `scripts/state/spec-metrics.sh` — post-ingest verification helper (from P05); documented in ingest.md's Reference Files block.
- `scripts/dispatch/scope-filter.sh` — consumes spec chunks via `--category spec/<cat> --graph` (from P04); documented in ingest.md's Reference Files block.
- `commands/evaluate.md` — existing file edited to reference `orchestrator:ingest`.
- `commands/doctor.md`, `commands/dispatch.md` (and any other `commands/*.md`) — reference pattern for the MEM012 shared command-file conventions.

## Constraints

- Bash 3.2 compatible for all four verify scripts (no `declare -A`, no `<(...)`, no `mapfile`, no `readarray`).
- AD-19 / AP-004 discipline for phase-plan `Check:` commands — single-script-file shape only (already satisfied).
- Do NOT modify `scripts/knowledge/ingest-spec.sh` in this task. Ingest semantics were finalized in P03.
- Do NOT modify `commands/roadmap.md` in this task — T01's scope is evaluate.md + ingest.md only.
- Do NOT delete or reorder any Reference File bullet in `commands/evaluate.md`. The T03 `m011-p06-commands-preserve-references.sh` regression will catch this.
- Do NOT introduce a runtime dependency on `jq` or `python3` in the verify scripts.
- The verify scripts must accept any minor wording variation in `commands/ingest.md` as long as the listed tokens are present. Lock down content, not prose.

## Expected Output

- `commands/ingest.md` (create, ~120–180 lines).
- `commands/evaluate.md` (modify, ensure `orchestrator:ingest` appears at least once).
- `scripts/verify/m011-p06-ingest-doc-structure.sh` (create, ~25 lines, executable).
- `scripts/verify/m011-p06-ingest-doc-conventions.sh` (create, ~40 lines, executable).
- `scripts/verify/m011-p06-ingest-doc-reingest-contract.sh` (create, ~25 lines, executable).
- `scripts/verify/m011-p06-evaluate-doc-mentions-ingest.sh` (create, ~20 lines, executable).
- All four verify scripts print `PASS:` and exit 0 when invoked from the repo root.

Write the task summary via:

```
bash scripts/knowledge/write-summary.sh \
  --milestone M011 --phase P06 --task T01 \
  --provides "commands/ingest.md new user-facing command wrapping ingest-spec.sh, commands/evaluate.md cross-link to orchestrator:ingest, four m011-p06-*.sh doc-shape verify scripts (structure, conventions, reingest-contract, evaluate-mentions-ingest)" \
  --requires "P03 ingest-spec.sh, P05 commands/evaluate.md chunks-first branch, MEM012 command-file conventions" \
  --affects "T02 e2e pipeline invokes ingest-spec.sh which is the subject of ingest.md, T03 preserved-references regression guards evaluate.md, end users discover ingest before running evaluate" \
  --key-files "commands/ingest.md, commands/evaluate.md, scripts/verify/m011-p06-ingest-doc-structure.sh, scripts/verify/m011-p06-ingest-doc-conventions.sh, scripts/verify/m011-p06-ingest-doc-reingest-contract.sh, scripts/verify/m011-p06-evaluate-doc-mentions-ingest.sh" \
  --verification-result pass \
  --body="T01 delivers the user-facing orchestrator:ingest command document, the minimal evaluate.md cross-link so users discover ingest before running evaluate, and four doc-shape verify scripts codifying structure, MEM012 conventions, re-ingest semantics, and evaluate.md cross-linkage. No production code changes."
```
