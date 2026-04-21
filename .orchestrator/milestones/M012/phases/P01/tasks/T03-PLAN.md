---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M012"
name: "wiki-generate-stubs.sh — include-plugin stubs for every in-scope .orchestrator/**.md"
depends_on: ["T02"]
---

## Prerequisites

- T01 complete: `wiki/` + `wiki/mkdocs.yml` + `wiki/docs/index.md` exist; `include-markdown` is declared in `plugins:`.
- T02 complete: `scripts/wiki/wiki-scan-sources.sh` emits in-scope records in `<category>|<rel-path>|<title>` shape.

## Description

Generate one include-plugin stub under `wiki/docs/` per in-scope `.orchestrator/**.md` artifact. Each stub contains no body content — only a YAML frontmatter `title:` and an `include-markdown` directive pointing at the canonical path under `.orchestrator/`. This is the mechanism that enforces AD-3 (no copies, no symlinks): the file under `wiki/docs/` is ≤ ~10 lines of template; the real content lives at `.orchestrator/**.md` and is pulled at MkDocs build time.

Stub layout mirrors the category structure emitted by the scanner, flattened into navigable directories under `wiki/docs/`:

```
wiki/docs/
  index.md                       (from T01 — placeholder, not a stub)
  README.md                      (from T01 — authoring note)
  constitution.md                (top:constitution)
  decisions.md                   (top:decisions)
  knowledge.md                   (top:knowledge)
  milestone-summary.md           (top:milestone-summary)
  milestones/
    index.md                     (auto-generated section index; one-liner)
    M001/
      index.md                   (auto-generated per-milestone section index)
      M001-CONTEXT.md            (stub → .orchestrator/milestones/M001/M001-CONTEXT.md)
      M001-EVALUATION.md
      M001-ROADMAP.md
      M001-SUMMARY.md
      P01/
        index.md
        P01-PLAN.md
        P01-SUMMARY.md
        T01-PLAN.md
        T01-SUMMARY.md
        ...
  archive/
    index.md                     (auto-generated section index)
    M001/
      ...
```

The generator:

1. Calls `wiki-scan-sources.sh` for the authoritative in-scope list.
2. Wipes any existing stubs under `wiki/docs/` — but only the stubs (never `index.md` or `README.md` at the top).
3. Writes one stub per scanned record.
4. Generates section index pages (`milestones/index.md`, `archive/index.md`, `milestones/M###/index.md`, `milestones/M###/P##/index.md`) that list their children. These are one-screen lists; T04 consumes the directory layout for the mkdocs `nav:` block.

## Steps

1. **Create `scripts/wiki/wiki-generate-stubs.sh`** — Bash 3.2, MEM004 carve-out (pipes/awk/find permitted; it's a helper script, not agent-facing content).

   Shape:

   ```bash
   #!/usr/bin/env bash
   # scripts/wiki/wiki-generate-stubs.sh — M012/P01 stub generator.
   #
   # Reads scan output from scripts/wiki/wiki-scan-sources.sh and writes one
   # thin include-plugin stub per in-scope .orchestrator/**.md artifact under
   # wiki/docs/.
   #
   # Stubs are < 15 lines each. Body content stays at .orchestrator/**.md
   # (single source of truth, M012 AD-3).
   #
   # Idempotent: safe to re-run. Removes existing auto-generated stubs before
   # writing fresh ones. Never touches wiki/docs/index.md or wiki/docs/README.md.
   #
   # Usage: bash scripts/wiki/wiki-generate-stubs.sh [--dry-run] [--root PROJECT_ROOT]
   # Exit 0 on success; 1 on scanner failure; 2 on write error.
   # Bash 3.2 compatible.
   ```

2. **Resolve PROJECT_ROOT** (same pattern as T02): default `$(cd "$(dirname "$0")/../.." && pwd)`; `--root` override.

3. **Clean phase**: identify auto-generated stubs under `wiki/docs/` and remove them. Definition of "auto-generated": any `.md` file under `wiki/docs/` except `index.md` and `README.md` at the top level. Use:

   ```bash
   # Remove every .md under wiki/docs/ except the top-level index.md and README.md.
   find "$ROOT/wiki/docs" -mindepth 1 -type f -name '*.md' \
     ! -path "$ROOT/wiki/docs/index.md" \
     ! -path "$ROOT/wiki/docs/README.md" \
     -delete
   # Remove now-empty subdirectories.
   find "$ROOT/wiki/docs" -mindepth 1 -type d -empty -delete 2>/dev/null || true
   ```

4. **Map category → target path**:

   | Scanner category | Target stub path (under `wiki/docs/`) |
   |------------------|----------------------------------------|
   | `top:constitution` | `constitution.md` |
   | `top:decisions` | `decisions.md` |
   | `top:knowledge` | `knowledge.md` |
   | `top:milestone-summary` | `milestone-summary.md` |
   | `milestone:<M###>` | `milestones/<M###>/<mirror of rel-path after milestones/M###/>` |
   | `archive:<M###>` | `archive/<M###>/<mirror of rel-path after archive/M###/>` |

   Examples:
   - `milestone:M011 | .orchestrator/milestones/M011/M011-SUMMARY.md | M011 Summary`
     → `wiki/docs/milestones/M011/M011-SUMMARY.md`
   - `milestone:M011 | .orchestrator/milestones/M011/phases/P02/P02-PLAN.md | P02 Plan`
     → `wiki/docs/milestones/M011/phases/P02/P02-PLAN.md`
   - `milestone:M011 | .orchestrator/milestones/M011/phases/P02/tasks/T03-PLAN.md | T03 Plan`
     → `wiki/docs/milestones/M011/phases/P02/tasks/T03-PLAN.md`

   Preserve the nested `phases/P##/` and `tasks/T##-*` structure under each milestone. This keeps AD-6 (nested plan inclusion) working and makes nav paths predictable.

5. **Stub template** (write this exact body, with substitution, for every stub):

   ```markdown
   ---
   title: "{{title}}"
   ---

   <!-- Auto-generated by scripts/wiki/wiki-generate-stubs.sh. Do not hand-edit.
        Source of truth: {{canonical_path}} (M012 AD-3). -->

   {%
     include-markdown "{{canonical_path}}"
     heading-offset=0
     rewrite-relative-urls=true
   %}
   ```

   Where:
   - `{{title}}` is the scanner's third field (H1 or basename fallback).
   - `{{canonical_path}}` is an absolute-from-repo-root path: e.g., `../../../.orchestrator/milestones/M011/M011-SUMMARY.md`. Compute the relative path from the stub location back to `.orchestrator/` with pure Bash string counting (bash 3.2 safe: count slashes in the stub's relative path, emit that many `../`).

   Write via `printf '%s\n' ...` (heredocs are fine for literal content as long as they have no pipes / further redirects — AD-19 forbids `heredoc | pipe`, not plain heredoc to stdout / file). A single heredoc to a named file via `> "$path"` is acceptable.

   Helper function:

   ```bash
   write_stub() {
     local target="$1" canonical="$2" title="$3"
     mkdir -p "$(dirname "$target")"
     {
       printf -- '---\n'
       printf 'title: "%s"\n' "$title"
       printf -- '---\n\n'
       printf '<!-- Auto-generated by scripts/wiki/wiki-generate-stubs.sh. Do not hand-edit.\n'
       printf '     Source of truth: %s (M012 AD-3). -->\n\n' "$canonical"
       printf '{%%\n'
       printf '  include-markdown "%s"\n' "$canonical"
       printf '  heading-offset=0\n'
       printf '  rewrite-relative-urls=true\n'
       printf '%%}\n'
     } > "$target"
   }
   ```

6. **Section indexes** (auto-generated one-screen lists):

   - `wiki/docs/milestones/index.md`: lists every `milestones/M###/` directory created under the stubs tree with a one-line pointer.
   - `wiki/docs/archive/index.md`: same, for `archive/M###/`.
   - `wiki/docs/milestones/M###/index.md`: lists the milestone's top-level `M###-*.md` stubs plus its `phases/P##/` subdirectories.
   - `wiki/docs/milestones/M###/phases/P##/index.md`: lists the phase's top-level `P##-*.md` stubs plus its `tasks/` children.

   Index template:

   ```markdown
   ---
   title: "{{section_title}}"
   ---

   # {{section_title}}

   <!-- Auto-generated section index. Regenerated by wiki-generate-stubs.sh. -->

   {{body_lines}}
   ```

   Where `{{body_lines}}` is one bullet per child entry — `- [<child-title>](<child-relative-path>)`. Keep bullets in lexical order. T04's nav generator mirrors this ordering.

7. **Idempotency + `--dry-run` mode**: `--dry-run` prints every path that WOULD be written/removed (prefixed `WOULD-WRITE:` / `WOULD-REMOVE:`) and exits 0 without touching disk. Running without `--dry-run` twice in a row is a no-op on the second run if `.orchestrator/` has not changed.

8. **Progress + summary**: emit `STUB: <target-path>` per stub written (stderr), and `SUMMARY: wrote <N> stubs, <M> section indexes, removed <K> stale files` on stderr at end.

9. **Run the generator once after writing it** (manual smoke check; not a Check): `bash scripts/wiki/wiki-generate-stubs.sh` then `find wiki/docs -type f -name '*.md' | wc -l` — confirm the count matches the T02 scanner count + section indexes + 2 (index.md + README.md).

## Must-Haves

- `scripts/wiki/wiki-generate-stubs.sh` exists and is executable.
- Every stub file under `wiki/docs/` is ≤ 25 lines (short template body; no duplicated artifact content).
- Every stub under `wiki/docs/` (except `index.md` and `README.md` at top level and `index.md` section indexes) contains an `include-markdown` directive referencing a path under `.orchestrator/`.
- `wiki/docs/index.md` and `wiki/docs/README.md` are preserved untouched across generator runs.
- Running the generator twice in a row produces byte-identical `wiki/docs/` contents (idempotency).
- Bash 3.2 compatible.
- Stub count matches scanner line count (every in-scope artifact gets exactly one stub).

## Verification

- `bash scripts/verify/m012-p01-include-plugin.sh` (T05) — asserts every stub has an `include-markdown` directive and references an existing `.orchestrator/` path.
- `bash scripts/verify/m012-p01-ssot.sh` (T05) — asserts no stub's body reproduces source content; stubs are ≤ 25 lines; no duplicate content under `wiki/docs/`.
- `bash scripts/verify/m012-p01-exclusion-policy.sh` (T05) — asserts no stub references `scratch/`, `tmp/`, `config/`, or non-`.md` paths.
- `bash scripts/verify/m012-p01-bash32-compat.sh` (T05) — scans this script.

Manual smoke check during this task (run once; do NOT embed as a Check):

1. `bash scripts/wiki/wiki-generate-stubs.sh --dry-run | head -n 20` — sanity-check the planned writes.
2. `bash scripts/wiki/wiki-generate-stubs.sh` — writes stubs for real.
3. `bash scripts/wiki/wiki-generate-stubs.sh` (again) — expect `SUMMARY:` line showing 0 new writes (idempotent).
4. If `mkdocs` installed: `bash scripts/wiki/wiki-serve.sh --probe` — expect failure only on the absent `nav:` block (resolved by T04).
5. `grep -r '^# ' wiki/docs/milestones/M012/ | head` — confirm the milestone's own artifacts appear.

## Inputs

### From Previous Tasks

- **T01**: `wiki/` skeleton — `wiki/mkdocs.yml` with the include plugin declared; `wiki/docs/index.md` placeholder; `wiki/docs/README.md` authoring note.
- **T02**: `scripts/wiki/wiki-scan-sources.sh` — emits `<category>|<rel-path>|<title>` per in-scope artifact. Contract is stable; this script treats it as a black box.

### Scanner Output Contract (from T02 — reproduced for zero-context execution)

- Line format: `<category>|<rel-path>|<title>`.
- Category enum: `top:constitution`, `top:decisions`, `top:knowledge`, `top:milestone-summary`, `milestone:<M###>`, `archive:<M###>`.
- `<rel-path>`: relative path under the repo root (e.g., `.orchestrator/milestones/M011/M011-SUMMARY.md`).
- `<title>`: single-line string, never empty.
- Stable lexical ordering: top-level first; then milestones (lexical); then archive (lexical). Within each milestone, `M###-*.md` (alphabetical), then `phases/P##/P##-*.md`, then `phases/P##/tasks/T##-*.md`.

### From Disk (Pre-existing)

- `.orchestrator/**.md` — content referenced by stubs via the include plugin (not read by the generator itself).
- `wiki/mkdocs.yml` — generator does not modify it here; T04 handles nav injection.

## Constraints

- **Bash 3.2** — MEM001. macOS baseline.
- **MEM004 carve-out** — helper-script-internal; pipes, `$()`, awk, find, heredocs are permitted. AD-19 prohibits `heredoc | pipe`; heredocs writing to a single file via redirect are fine.
- **No copies, no symlinks** — AD-3. Stubs reference canonical paths via include-markdown. Verified by T05.
- **Idempotency** — second run after a first successful run must produce zero writes (or, if scanner output is unchanged, zero net diff). The "clean phase" is explicit for reproducibility.
- **Never touch `wiki/docs/index.md` or `wiki/docs/README.md`** — these are T01 / P04 territory. Hard-guard in the clean-phase `find` command.
- **Path traversal safety** — every stub target path is constructed relative to `wiki/docs/`. Never emit a stub whose canonical include path does not start with `../` (i.e., never reference something inside `wiki/`).
- **Single-script-file `Check:` shape (AD-19)** — T05 gates are single invocations; no compound bash inside Checks.

## Expected Output

- `scripts/wiki/wiki-generate-stubs.sh` — executable, Bash 3.2 compliant, ≥ 80 lines, supports `--dry-run` and `--root`.
- After running the generator once: `wiki/docs/` holds one stub per in-scope artifact plus section indexes, with every stub ≤ 25 lines, every stub referencing a canonical `.orchestrator/**.md` path via the include plugin.
- Running the generator twice leaves `wiki/docs/` byte-identical (idempotency).
