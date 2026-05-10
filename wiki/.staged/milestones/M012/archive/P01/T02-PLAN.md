---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M012"
name: "wiki-scan-sources.sh — in-scope artifact enumerator with exclusion policy"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `wiki/` skeleton and `scripts/wiki/wiki-serve.sh` exist.
- `.orchestrator/` tree is populated with real artifacts (constitution, DECISIONS.md, KNOWLEDGE.md, milestone-summary.md, multiple `milestones/M###/` directories, `archive/` directory).
- No stubs generated yet; no nav block exists in `wiki/mkdocs.yml`.

## Description

Ship `scripts/wiki/wiki-scan-sources.sh` — the single source of truth for "what counts as in-scope" for the wiki. Both T03 (stub generator) and T04 (nav generator) consume its output. This is the enforcement point for the exclusion policy (FR-8 + M012-ROADMAP Boundary Map + AD-4).

Output contract (printed to stdout, one record per line):

```
<category>|<relative-path-under-dot-orchestrator>|<display-title>
```

Where `<category>` is one of:

- `top:constitution` — `.orchestrator/memory/constitution.md`
- `top:decisions` — [`.orchestrator/DECISIONS.md`](../../../../decisions.md)
- `top:knowledge` — [`.orchestrator/KNOWLEDGE.md`](../../../../knowledge.md)
- `top:milestone-summary` — `.orchestrator/milestone-summary.md`
- `milestone:<M###>` — every `.md` file under `.orchestrator/milestones/<M###>/` (including `phases/**/*.md` and `tasks/**/*.md`)
- `archive:<M###>` — every `.md` file under `.orchestrator/archive/<M###>/**`

Exclusion policy (lines that MUST NOT appear in scan output):

- Any path under `.orchestrator/scratch/`.
- Any path under `.orchestrator/tmp/`.
- Any path under `.orchestrator/config/`.
- Any non-`.md` file (`*.jsonl`, `*.txt`, `*.json`, `*.yml`, `*.yaml`, `VALIDATED` markers, lock files, etc.).
- `P##-PLANNING-PAYLOAD.md` — these are planning scratch, not durable artifacts. Exclude to keep the nav readable.
- `P##-VERIFICATION.md` — verification reports are machine output; exclude to keep the nav focused on plans/summaries. (Planning decision: reports land in execution-log analyses, not in the wiki body.)
- Any `.md` under `.orchestrator/milestones/M###/` or `.orchestrator/archive/` whose file-basename is `AGENTS.md` or `README.md` (if any appear — documentation internal to the orchestrator, not a milestone artifact).

`<display-title>`: derived from the first `# ` H1 line in the file, stripping Markdown. If no H1 exists, fall back to the basename without `.md` extension.

The scanner is read-only. Never writes to disk. Emits one line per in-scope artifact plus a trailing `SUMMARY: <N>` line on stderr for observability.

## Steps

1. **Create `scripts/wiki/wiki-scan-sources.sh`** with Bash 3.2 + pipes/awk/find permitted (MEM004 carve-out: this is emitter-internal, not agent-facing content).

   Shape:

   ```bash
   #!/usr/bin/env bash
   # scripts/wiki/wiki-scan-sources.sh — M012/P01 in-scope artifact enumerator.
   #
   # Prints one record per in-scope .orchestrator/**.md file to stdout:
   #   <category>|<relative-path-under-dot-orchestrator>|<display-title>
   #
   # Category enum:
   #   top:constitution
   #   top:decisions
   #   top:knowledge
   #   top:milestone-summary
   #   milestone:M###
   #   archive:M###
   #
   # Exclusion policy (hard-coded; see M012-ROADMAP Boundary Map + FR-8):
   #   .orchestrator/scratch/**         — transient
   #   .orchestrator/tmp/**             — transient
   #   .orchestrator/config/**          — config, not artifact
   #   any non-.md file                 — wiki is markdown-only
   #   P##-PLANNING-PAYLOAD.md          — planning scratch
   #   P##-VERIFICATION.md              — machine output
   #   AGENTS.md / README.md under milestone/archive trees
   #
   # Usage: bash scripts/wiki/wiki-scan-sources.sh [--root PROJECT_ROOT]
   # Exit 0 on success; 1 on unresolvable PROJECT_ROOT.
   # Bash 3.2 compatible.
   ```

2. **Resolve PROJECT_ROOT**: default to `$(cd "$(dirname "$0")/../.." && pwd)`; override with `--root <path>`.

3. **Scan order** (emit in this order so nav generators can assemble a stable list):
   1. `top:constitution` — check `$ROOT/.orchestrator/memory/constitution.md`; emit if present.
   2. `top:decisions` — check `$ROOT/.orchestrator/DECISIONS.md`; emit if present.
   3. `top:knowledge` — check `$ROOT/.orchestrator/KNOWLEDGE.md`; emit if present.
   4. `top:milestone-summary` — check `$ROOT/.orchestrator/milestone-summary.md`; emit if present.
   5. Milestones — iterate `$ROOT/.orchestrator/milestones/M*/` directories in lexical order; within each, emit the top-level `.md` files (alphabetical) then `phases/P*/` (lexical) with each phase's `.md` files then `phases/P*/tasks/T*/` `.md` files.
   6. Archive — iterate `$ROOT/.orchestrator/archive/M*/` directories in lexical order; same pattern as milestones.

4. **Find-then-filter** implementation:

   ```bash
   # Example filter: list every .md under a directory, apply exclusions.
   # Uses `find ... -type f -name '*.md'` then awk-based filtering.
   #
   # Exclusion enforcement MUST match the full relative path prefix, not
   # just the basename — so `.orchestrator/milestones/M001/scratch/foo.md`
   # would NOT be excluded (because scratch is only excluded at the top
   # level), but `.orchestrator/scratch/foo.md` would.
   ```

   Use `find "$dir" -type f -name '*.md'` piped into `sort` and then an awk filter:

   ```bash
   find "$ROOT/.orchestrator/milestones" -type f -name '*.md' 2>/dev/null \
     | sort \
     | awk -v ROOT_LEN=$((${#ROOT}+1)) '
         {
           rel = substr($0, ROOT_LEN+1)  # strip ROOT + "/"
           base = rel
           sub(/.*\//, "", base)
           if (base == "AGENTS.md") next
           if (base == "README.md") next
           if (base ~ /P[0-9]+-PLANNING-PAYLOAD\.md$/) next
           if (base ~ /P[0-9]+-VERIFICATION\.md$/) next
           print rel
         }'
   ```

   Apply the top-level exclusion check via a separate guard:

   ```bash
   # For scratch/tmp/config: reject paths whose first segment under
   # .orchestrator/ matches any of these three.
   # Implemented with a `case` match on the relative path.
   ```

5. **Title extraction**: for each selected file, read the first line that begins with `# ` (H1) and strip the leading `# `. If no such line exists, fall back to the basename without `.md`. Use `grep -m 1 '^# '` with a safe default:

   ```bash
   title=$(grep -m 1 '^# ' "$path" 2>/dev/null | sed 's/^# //' | head -n 1)
   if [ -z "$title" ]; then
     base=$(basename "$path" .md)
     title="$base"
   fi
   ```

6. **Milestone / archive category derivation**: extract the `M###` directory name by stripping the `.orchestrator/milestones/` or `.orchestrator/archive/` prefix and taking the first path segment. Example: [`.orchestrator/milestones/M011/phases/P02/P02-PLAN.md`](../../../../milestones/M011/phases/P02/P02-PLAN.md) → `milestone:[M011](../../../../milestones/M011/index.md)`.

7. **Emit** one line per file with `printf '%s|%s|%s\n' "$category" "$rel" "$title"`. Record count on stderr at end: `printf 'SUMMARY: %d in-scope artifacts\n' "$count" >&2`.

8. **Smoke-run** (manual, do not embed as a Check): `bash scripts/wiki/wiki-scan-sources.sh | head -n 20` — verify output shape and that M012's own `.md` files appear. `bash scripts/wiki/wiki-scan-sources.sh | grep '\.orchestrator/scratch'` must emit nothing.

## Must-Haves

- `scripts/wiki/wiki-scan-sources.sh` exists and is executable.
- Output schema is three pipe-separated fields: `<category>|<rel-path>|<title>`.
- No line in output contains `.orchestrator/scratch/`, `.orchestrator/tmp/`, or `.orchestrator/config/`.
- No line in output ends in anything other than `.md`.
- No line in output references `PLANNING-PAYLOAD`, `VERIFICATION`, `AGENTS.md`, or a basename `README.md` inside milestone / archive trees.
- Top-level artifacts emit before milestone artifacts; milestone artifacts emit before archive artifacts; within each group, lexical order.
- Bash 3.2 compatible — no `declare -A`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`.
- Pure read-only (no writes under `$ROOT`).

## Verification

- `bash scripts/verify/m012-p01-exclusion-policy.sh` (ships in T05) — invokes the scanner, asserts no excluded path appears and no non-`.md` appears.
- `bash scripts/verify/m012-p01-bash32-compat.sh` (ships in T05) — scans this script for bash-3.2-incompatible constructs.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P01` — confirms artifact path + pattern after T05 seeds.

Manual smoke check during this task (run once; do NOT embed as a Check):

1. `bash scripts/wiki/wiki-scan-sources.sh | wc -l` — record the count. Expect well north of 50 for a populated repo.
2. `bash scripts/wiki/wiki-scan-sources.sh | awk -F'|' '{print $1}' | sort -u` — expect the seven category prefixes.
3. `bash scripts/wiki/wiki-scan-sources.sh | awk -F'|' '$3 == ""'` — expect no lines (every record must have a non-empty title).

## Inputs

### From Previous Tasks

- T01: `wiki/` skeleton exists so downstream scripts (T03, T04) have a stable target to write into. This task does not touch `wiki/` itself.

### From Disk (Pre-existing)

- `.orchestrator/memory/constitution.md`
- [`.orchestrator/DECISIONS.md`](../../../../decisions.md)
- [`.orchestrator/KNOWLEDGE.md`](../../../../knowledge.md)
- `.orchestrator/milestone-summary.md`
- `.orchestrator/milestones/M###/` — many, each with `M###-*.md`, `phases/P##/P##-*.md`, `phases/P##/tasks/T##-*.md`.
- `.orchestrator/archive/M###/` — historical milestones.
- `.orchestrator/scratch/`, `.orchestrator/tmp/`, `.orchestrator/config/` — must be scanned but excluded.

## Constraints

- **Bash 3.2** — per MEM001. macOS baseline.
- **MEM004 carve-out** — this is a helper library, not agent-facing content; pipes, `$()`, `awk`, and `find` are permitted.
- **Read-only** — the scanner never writes under `$ROOT`. Any attempt to write fails review.
- **Stable output order** — top-level artifacts first, then milestones (lexical by `M###`), then archive (lexical by `M###`). Within a milestone: top-level `M###-*.md` (alphabetical), then phases (lexical), then tasks (lexical).
- **Title extraction is best-effort** — fall back to basename without `.md` on H1 miss. Never fail the scan on title extraction.
- **Single-script-file `Check:` shape (AD-19)** — T05's exclusion-policy Check is a single `bash scripts/verify/m012-p01-exclusion-policy.sh` invocation.
- **No network, no external dependencies** — `find`, `grep`, `sed`, `awk`, `sort` only (all in Bash 3.2 baseline).

## Expected Output

- `scripts/wiki/wiki-scan-sources.sh` — executable, Bash 3.2 compliant, 60+ lines.
- Running it prints lines in `<category>|<rel-path>|<title>` shape, zero excluded paths, stable lexical order within categories.
- Running it with `--root /tmp/empty` (or an empty directory) emits zero stdout lines and `SUMMARY: 0 in-scope artifacts` on stderr.
- Returns exit 0 on success, exit 1 only if `--root` points at a non-existent directory or the `.orchestrator/` subdir is missing.
