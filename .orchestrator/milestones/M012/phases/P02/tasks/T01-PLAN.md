---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M012"
name: "Link-rewriting config + wiki-scan extension for knowledge/ source tree"
depends_on: []
---

## Prerequisites

- P01 complete — `wiki/` skeleton exists:
  - `wiki/mkdocs.yml` with `include-markdown` plugin under `plugins:`, `markdown_extensions:` list, and a marker-bounded nav block (between `# >>> M012-P01 nav` / `# <<< M012-P01 nav end`).
  - `wiki/docs/` populated with one stub per in-scope `.orchestrator/**.md` plus section index files.
  - `scripts/wiki/wiki-scan-sources.sh` emits `<category>|<rel-path>|<title>` records for `.orchestrator/**.md` paths only; categories are `top:constitution`, `top:decisions`, `top:knowledge`, `top:milestone-summary`, `milestone:M###`, `archive:M###`.
  - `scripts/wiki/wiki-generate-stubs.sh` consumes scanner stdout, writes stubs under `wiki/docs/`, plus section index files.
  - `scripts/wiki/wiki-generate-nav.sh` consumes scanner stdout, splices a `nav:` block into `wiki/mkdocs.yml` between the M012-P01 markers.
- `knowledge/` tree exists at repo root with three subdirectories (`patterns/`, `conventions/`, `lessons/`) each containing per-entry `MEM###.md` files (bash 3.2 safe to enumerate with `find knowledge -type f -name 'MEM*.md'`). Verify with `ls knowledge/patterns/ knowledge/conventions/ knowledge/lessons/` before starting.
- No prior P02 work exists — `.orchestrator/milestones/M012/phases/P02/tasks/` contains this plan only.

## Description

Two load-bearing config/extension changes that every other P02 task depends on:

**Change 1 — Assert link-rewriting on include-plugin.** P01 already sets `rewrite_relative_urls: true` on the include-markdown plugin (per P01 patterns established). T01 makes that setting explicit and load-bearing so the M012/P02 link-rewrite gate can assert it. Without this option, relative links inside an included `.orchestrator/**.md` body resolve against the canonical source file's directory (wrong) instead of against the stub's rendered route (right). Also verify the `markdown_extensions:` list includes an anchor-generating extension so MEM headings in the rendered KNOWLEDGE.md get per-heading anchor ids like `#mem-0001`.

**Change 2 — Extend `wiki-scan-sources.sh` with `knowledge/**/MEM*.md` enumeration.** P01 only scans `.orchestrator/**.md`. P02 needs the scanner to also emit records for the per-entry knowledge files so T02's extended stub generator has source records to iterate. Category scheme: `knowledge:patterns`, `knowledge:conventions`, `knowledge:lessons`. Record format unchanged: `<category>|<rel-path>|<title>`, where `<rel-path>` is the path relative to repo root (e.g., `knowledge/patterns/MEM001.md`) — NOT relative to `.orchestrator/` because these files live outside that tree.

The scanner keeps its existing `.orchestrator/**.md` emission completely intact. The new records are emitted after all existing records so downstream generators see a stable order: existing `.orchestrator/` records first (lexical), then `knowledge/patterns` (lexical MEM id), then `knowledge/conventions`, then `knowledge/lessons`. Downstream generators iterate once, single-pass.

## Steps

1. **Verify P01 state** — run the following once and record baseline output:

   ```bash
   bash scripts/verify/m012-p01-phase-suite.sh
   ```

   Must exit 0 (9/9 gates PASS). If any gate fails, stop — P01 must be green before T01 runs.

2. **Open `wiki/mkdocs.yml`** and locate the `plugins:` block. Find the `include-markdown` entry. P01 already added `rewrite_relative_urls: true` underneath it; assert that the exact string `rewrite_relative_urls: true` appears (spelling: underscore separators, lowercase `true`). If not present, add it as a sub-key under the plugin's options block:

   ```yaml
   plugins:
     - search
     - include-markdown:
         rewrite_relative_urls: true
         heading_offset: 0
   ```

   The include-plugin's `rewrite_relative_urls` option causes relative links inside the *included* markdown body (e.g., a link in `.orchestrator/DECISIONS.md` that reads `[M011 summary](milestones/M011/M011-SUMMARY.md)`) to be rewritten so they resolve against the *including* stub's URL instead of the canonical source path. This is the single load-bearing setting for cross-link navigation; the rest of the plugin config is already correct from P01.

3. **Confirm `markdown_extensions:` includes heading anchor generation.** The default MkDocs Material theme already auto-generates heading anchors via the `toc` extension, but the anchor style depends on the `slugify` function. The default produces `#mem-0001`-style anchors from `# MEM-0001: …` headings (lowercase, hyphenated). If `markdown_extensions:` does not already list `toc`, add it. Also confirm `pymdownx.superfences` or equivalent is present (P01 already ships with `pymdown-extensions` pinned in `wiki/requirements.txt`).

   Expected block shape:

   ```yaml
   markdown_extensions:
     - toc:
         permalink: true
     - admonition
     - pymdownx.superfences
     - pymdownx.details
   ```

   The `permalink: true` sub-option is what makes MEM-heading anchors discoverable (adds a clickable `¶` next to each heading on the rendered page). Without it the anchor still works programmatically but is not surfaced to readers. P02 uses both facets.

4. **Open `scripts/wiki/wiki-scan-sources.sh`.** Review the existing emitter loop (it writes one record per in-scope `.orchestrator/**.md` path). Locate the point where the scanner has finished emitting all `.orchestrator/` records and is about to exit. Add a new emission block *after* the `.orchestrator/` block but *before* the final exit.

5. **Extend the scanner** to emit `knowledge/**/MEM*.md` records. Add (Bash 3.2 safe, no `mapfile`, no `declare -A`, no process substitution):

   ```bash
   # ---- knowledge/ tree enumeration (added in M012/P02/T01) --------------------
   if [ -d "$ROOT/knowledge" ]; then
     for cat in patterns conventions lessons; do
       catdir="$ROOT/knowledge/$cat"
       [ -d "$catdir" ] || continue
       # Collect entry files in lexical order; no mapfile (bash 3.2).
       tmplist="/tmp/wiki-scan-knowledge.$cat.$$"
       find "$catdir" -maxdepth 1 -type f -name 'MEM*.md' | LC_ALL=C sort > "$tmplist"
       while IFS= read -r mempath; do
         [ -n "$mempath" ] || continue
         rel="${mempath#$ROOT/}"
         # Extract the first H1 (expected shape: "# MEMxxx: title" or similar).
         title=$(grep -m1 -E '^# ' "$mempath" | sed -e 's/^# //' -e 's/|/ /g')
         [ -n "$title" ] || title="$(basename "$mempath" .md)"
         printf '%s|%s|%s\n' "knowledge:$cat" "$rel" "$title"
       done < "$tmplist"
       rm -f "$tmplist"
     done
   fi
   ```

   Key invariants:

   - `<rel-path>` is relative to repo root, matching the existing `.orchestrator/**.md` convention (every existing record's rel-path is also repo-root relative, e.g., `.orchestrator/KNOWLEDGE.md`).
   - Category string uses single-colon prefix (`knowledge:patterns`) — consistent with `milestone:M###` and `archive:M###`.
   - Title sanitization: pipe character in titles (unlikely but possible) is replaced with a space to preserve the 3-field invariant (MEM008 / P01 T02 title-sanitization pattern).
   - Fallback title = basename sans `.md` — prevents empty third-field records when an entry lacks an H1.
   - PID-suffixed temp file in `/tmp` (not inside `ROOT`) avoids the `|`-while subshell variable-loss that bites pipes in Bash 3.2 (T02 P01 pattern).
   - `maxdepth 1` — only direct children, no nested enumeration.

6. **Confirm scanner output order** — run the scanner once and inspect:

   ```bash
   bash scripts/wiki/wiki-scan-sources.sh > /tmp/m012-p02-scan.out
   ```

   Verify with:

   ```bash
   bash scripts/verify/m012-p02-link-rewrite-config.sh
   ```

   (this gate is authored in T05, but its assertion on scanner records can be pre-checked via `grep -E '^knowledge:(patterns|conventions|lessons)\|' /tmp/m012-p02-scan.out | wc -l` should equal the total count of `knowledge/**/MEM*.md` files on disk).

   Also spot-check: the last `archive:M###` record (if any) appears strictly before the first `knowledge:patterns` record. The first `knowledge:patterns` record's rel-path is `knowledge/patterns/MEM001.md` (lexical MEM id order).

7. **Run existing P01 verification** — the P01 suite must STILL pass after the extension, since P01 gates only assert `.orchestrator/` records and the new records are additive:

   ```bash
   bash scripts/verify/m012-p01-phase-suite.sh
   ```

   Expect `9/9 gates passed`. If any gate fails, the extension is interfering with existing records — audit the scanner change.

8. **Do NOT yet run the stub generator or nav generator**. T02 teaches them to consume the new records; running them against the new scanner output now would either silently ignore the knowledge records (if the generators don't recognize the category prefix) or fail with an unknown-category error (depending on P01's current behavior). Either way it is T02's work, not T01's.

## Must-Haves

- `wiki/mkdocs.yml` explicitly declares `rewrite_relative_urls: true` on the `include-markdown` plugin block.
- `wiki/mkdocs.yml` explicitly declares `toc:` (with `permalink: true` sub-option) in `markdown_extensions:`.
- `scripts/wiki/wiki-scan-sources.sh` emits one `knowledge:<category>|<rel-path>|<title>` record per `knowledge/**/MEM*.md` file, in lexical order by category (patterns, conventions, lessons) and by filename within each category.
- The scanner's existing `.orchestrator/` emission is unchanged (byte-identical count and ordering on the same input tree).
- Knowledge records appear AFTER every `.orchestrator/` record in scanner output.
- Scanner remains Bash 3.2 compatible (no `declare -A`, no `mapfile`, no process substitution, no `&>`).
- `bash scripts/verify/m012-p01-phase-suite.sh` still exits 0 after T01 changes.

## Verification

- `bash scripts/wiki/wiki-scan-sources.sh` — stdout includes lines with `knowledge:patterns|knowledge/patterns/MEM001.md|…` style records; line count equals `.orchestrator/**.md` count plus `knowledge/**/MEM*.md` count.
- `bash scripts/verify/m012-p01-phase-suite.sh` — still exits 0 (P01 suite unchanged by additive scanner extension).
- `bash scripts/verify/m012-p02-link-rewrite-config.sh` — authored in T05; at T01 completion this script does not yet exist, so this specific assertion is deferred. Instead, manually confirm the two `wiki/mkdocs.yml` settings via `grep -F 'rewrite_relative_urls: true' wiki/mkdocs.yml` (must emit one line) and `grep -E '^\s+- toc' wiki/mkdocs.yml` (must emit one line).
- Manual: inspect scanner stdout for no empty third-field records (no `knowledge:patterns|knowledge/patterns/MEM001.md|` with trailing empty title).

## Inputs

### From Previous Tasks

- No P02 predecessors. All inputs are from P01 (complete) and the pre-existing repo.

### From Disk (Pre-existing)

- `wiki/mkdocs.yml` — P01 output; has `include-markdown` plugin declared, P01-marker-bounded nav block. T01 asserts/adjusts two settings inside it. Shape: MkDocs YAML with `site_name`, `theme`, `plugins`, `markdown_extensions`, and `nav` top-level keys.
- `scripts/wiki/wiki-scan-sources.sh` — P01 output. Existing contract: reads `$ROOT` (env or `--root`), enumerates `.orchestrator/**.md` with exclusion policy, prints `<category>|<rel-path>|<title>` records to stdout. T01 extends the emission loop; existing behavior preserved.
- `knowledge/patterns/MEM001.md` through `knowledge/patterns/MEM011.md`, `knowledge/conventions/MEM012.md` through `MEM020.md`, `knowledge/lessons/MEM021.md` through `MEM025.md` — per-entry MEM files with YAML frontmatter + `# MEM###: <Title>` H1. Body contents are the consolidated knowledge entries; P02 never duplicates them (AD-3 SSOT).
- `.orchestrator/memory/constitution.md` — Principle VIII (Bash 3.2 compat) applies to the scanner extension.
- `.orchestrator/milestones/M012/M012-CONTEXT.md` — AD-1 (cross-refs only), AD-3 (include plugin SSOT) apply.

## Constraints

- **Bash 3.2** — the scanner runs on macOS default shell. No `declare -A`, no `mapfile`/`readarray`, no `<(…)`, no `&>`, no `${var^^}`. MEM001.
- **Additive only** — T01 MUST NOT change the existing `.orchestrator/` emission. Any byte-level diff in `.orchestrator/` records against the P01-green baseline fails P01's suite.
- **Single source of truth (AD-3, Constitution VI)** — T01 does not copy `knowledge/**/MEM*.md` content anywhere. The scanner only emits paths + one-line titles. Content stays in its canonical file.
- **No speculative complexity (Constitution XIV)** — T01 adds exactly the two settings and the one emission block needed. It does NOT:
  - Add a new scanner flag (no `--include-knowledge` toggle; the emission is unconditional when `knowledge/` exists).
  - Touch `wiki-generate-stubs.sh` or `wiki-generate-nav.sh` (that is T02's work; doing it here would straddle tasks).
  - Introduce a YAML-parsing lib (the two `mkdocs.yml` settings are asserted via direct `grep` in T05's gate).
- **MEM004 carve-out** — the scanner is verification-adjacent tooling; pipes, `awk`, `find | sort`, temp files are permitted inside the script. The AD-19 shape constraint applies to Truth `Check:` commands (which invoke `scripts/verify/m012-p02-*.sh`), not to the internals of the scripts themselves.
- **Surgical precision (Constitution XV)** — touch exactly `wiki/mkdocs.yml` and `scripts/wiki/wiki-scan-sources.sh`. Nothing else.

## Expected Output

After T01 completes:

1. `wiki/mkdocs.yml` contains (observable via grep):
   - `rewrite_relative_urls: true` — one line.
   - `- toc:` followed by `permalink: true` — one block.

2. `bash scripts/wiki/wiki-scan-sources.sh` emits, in addition to its P01 output:
   - One line per `knowledge/patterns/MEM*.md` file, category `knowledge:patterns`.
   - One line per `knowledge/conventions/MEM*.md` file, category `knowledge:conventions`.
   - One line per `knowledge/lessons/MEM*.md` file, category `knowledge:lessons`.
   - Order: all `.orchestrator/` records first (unchanged from P01), then `knowledge:patterns`, then `knowledge:conventions`, then `knowledge:lessons`; within each category, records are in `LC_ALL=C sort` lexical order.

3. `bash scripts/verify/m012-p01-phase-suite.sh` — still exits 0 (9/9 gates PASS).

4. Stubs under `wiki/docs/` are unchanged. `wiki/mkdocs.yml`'s nav block between M012-P01 markers is unchanged. T02 will rebuild both in the next task.
