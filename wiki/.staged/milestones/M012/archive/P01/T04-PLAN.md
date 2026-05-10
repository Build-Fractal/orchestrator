---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M012"
name: "wiki-generate-nav.sh — Constitution / Decisions / Knowledge / Milestone Summary / Milestones / Archive nav assembly"
depends_on: ["T03"]
---

## Prerequisites

- T01 complete: `wiki/mkdocs.yml` has no `nav:` key (intentionally absent from T01).
- T02 complete: `scripts/wiki/wiki-scan-sources.sh` emits the in-scope list.
- T03 complete: every in-scope artifact has a stub under `wiki/docs/**` with predictable path layout.

## Description

Generate the MkDocs `nav:` block and splice it into `wiki/mkdocs.yml`. The final top-level nav order is:

```
nav:
  - Home: index.md
  - Constitution: constitution.md
  - Decisions: decisions.md
  - Knowledge: knowledge.md
  - Milestone Summary: milestone-summary.md
  - Milestones:
    - milestones/index.md
    - M001:
      - milestones/M001/index.md
      - M001 Context: milestones/M001/M001-CONTEXT.md
      - M001 Evaluation: milestones/M001/M001-EVALUATION.md
      - M001 Roadmap: milestones/M001/M001-ROADMAP.md
      - M001 Summary: milestones/M001/M001-SUMMARY.md
      - P01:
        - milestones/M001/phases/P01/index.md
        - P01 Plan: milestones/M001/phases/P01/P01-PLAN.md
        - P01 Summary: milestones/M001/phases/P01/P01-SUMMARY.md
        - T01 Plan: milestones/M001/phases/P01/tasks/T01-PLAN.md
        - T01 Summary: milestones/M001/phases/P01/tasks/T01-SUMMARY.md
        - ...
    - M002:
      ...
  - Archive:
    - archive/index.md
    - M###:
      - ...
```

This matches AD-6 (phase/task nesting as expandable nav) and M012-ROADMAP's Boundary Map ("Nav structure: Constitution, Decisions, Knowledge, Milestone Summary, Milestones expandable per-milestone, Archive labeled").

The nav block is injected into `wiki/mkdocs.yml` between two marker comments, so the generator can safely replace the block on subsequent runs without disturbing surrounding config. If the markers are absent, the generator appends them at the end of the file.

## Steps

1. **Create `scripts/wiki/wiki-generate-nav.sh`** — Bash 3.2, MEM004 carve-out.

   Shape:

   ```bash
   #!/usr/bin/env bash
   # scripts/wiki/wiki-generate-nav.sh — M012/P01 nav block generator.
   #
   # Consumes scripts/wiki/wiki-scan-sources.sh output and writes a MkDocs
   # nav: block into wiki/mkdocs.yml between these two marker lines:
   #   # >>> M012-P01 nav (auto-generated — do not edit by hand)
   #   # <<< M012-P01 nav end
   #
   # On first run, the markers are appended at the end of wiki/mkdocs.yml
   # with the nav block between them. On subsequent runs, the content
   # between the existing markers is replaced atomically.
   #
   # Nav order (top level):
   #   Home, Constitution, Decisions, Knowledge, Milestone Summary,
   #   Milestones (expandable per-milestone), Archive (labeled).
   #
   # Usage: bash scripts/wiki/wiki-generate-nav.sh [--dry-run] [--root PROJECT_ROOT]
   # Exit 0 on success; 1 on scanner failure; 2 on config write error.
   # Bash 3.2 compatible.
   ```

2. **Resolve PROJECT_ROOT** (same pattern as T02/T03).

3. **Read scanner output once** into an ordered stream. Use a temp file or a single pipe; do not embed scanner calls inside `$()` in Checks (AD-19), but internal script use of `$()` is fine (MEM004 carve-out).

   ```bash
   SCAN_OUT="$(mktemp -t m012p01navXXXXXX)"
   trap 'rm -f "$SCAN_OUT"' EXIT
   bash "$ROOT/scripts/wiki/wiki-scan-sources.sh" --root "$ROOT" > "$SCAN_OUT"
   ```

4. **Map scanner path → nav path under `wiki/docs/`** (mirror of T03's target-path mapping):

   - `top:constitution` → `constitution.md`
   - `top:decisions` → `decisions.md`
   - `top:knowledge` → `knowledge.md`
   - `top:milestone-summary` → `milestone-summary.md`
   - `milestone:<M###>` + rel `...milestones/M###/<rest>` → `milestones/M###/<rest>`
   - `archive:<M###>` + rel `...archive/M###/<rest>` → `archive/M###/<rest>`

5. **Build the nav tree**. Walk the scanner stream and group by milestone, by phase, by task. Bash 3.2 has no associative arrays; use the parallel-indexed-array pattern (MEM001): one array of milestone IDs encountered in order, and per-milestone arrays of stub nav paths, built on the fly.

   Pragmatic implementation: rather than building nested arrays, emit the YAML in a single stream-friendly pass. Because the scanner output is already lexically sorted (top → milestones lexical → archive lexical, nested phases/tasks lexical), a stateful while-read loop can emit the right indentation at group transitions:

   ```bash
   prev_milestone=""
   prev_phase=""
   prev_group=""   # "top" | "milestone" | "archive"
   while IFS='|' read -r category rel title; do
     # Derive nav path + milestone id + phase id from category/rel.
     # Compare to prev_* state; emit section headers + indentation when
     # group, milestone, or phase changes.
     # Print the bullet line with 2 * depth spaces.
   done < "$SCAN_OUT"
   ```

   Emit entries with consistent 2-space YAML indentation. Titles with special YAML characters (`:`, `#`, `"`) are double-quoted and internal `"` is escaped `\"`. Use `printf '%s\n'` for every line — no pipes, no `$(…)` with pipes inside the stream.

6. **Nav title derivation** (keep consistent with AD-6 and the Boundary Map):

   - Top-level: fixed labels `Home`, `Constitution`, `Decisions`, `Knowledge`, `Milestone Summary`, `Milestones`, `Archive`.
   - Per-milestone group label: the `M###` id (e.g., `M001`, [`M011`](../../../../milestones/M011/index.md)). (Short labels keep the sidebar readable.)
   - Per-artifact label under a milestone: strip the `M###-` prefix and title-case the remainder. Examples: `M011-CONTEXT.md` → `Context`, `M011-EVALUATION.md` → `Evaluation`, `M011-ROADMAP.md` → `Roadmap`, `M011-SUMMARY.md` → `Summary`.
   - Per-phase group label: `P##` (e.g., `P01`).
   - Per-phase-artifact label: strip `P##-` prefix and title-case. `P01-PLAN.md` → `Plan`, `P01-SUMMARY.md` → `Summary`.
   - Per-task label: strip numeric prefix, keep the kind. `T01-PLAN.md` → `T01 Plan`, `T01-SUMMARY.md` → `T01 Summary`. (Task bullets stay identifiable at a glance.)
   - Section-index `index.md` entries: use a visually light label. `Overview` is acceptable for milestones/archive index pages; per-milestone/per-phase index pages can reuse the group label or be collapsed per MkDocs Material's `navigation.indexes` feature (already enabled in T01).

7. **Marker-based atomic replacement** in `wiki/mkdocs.yml`:

   ```bash
   MARKER_START="# >>> M012-P01 nav (auto-generated — do not edit by hand)"
   MARKER_END="# <<< M012-P01 nav end"

   if ! grep -qF "$MARKER_START" "$CONFIG"; then
     # First run: append markers (with an empty block between) at EOF.
     {
       printf '\n%s\n' "$MARKER_START"
       printf '%s\n' "$MARKER_END"
     } >> "$CONFIG"
   fi

   # Extract pre-block, nav-block, post-block into temp files.
   # Replace middle with newly assembled nav YAML.
   # Write atomically via mv over a temp file.
   ```

   Use `awk` with a state machine to split on markers — much cleaner than `sed -i` (which differs between GNU and BSD):

   ```bash
   TMP_PRE=$(mktemp)
   TMP_POST=$(mktemp)
   awk -v s="$MARKER_START" -v e="$MARKER_END" \
       -v pre="$TMP_PRE" -v post="$TMP_POST" '
     BEGIN { state = "pre" }
     {
       if (state == "pre") {
         if ($0 == s) { print s > pre; state = "in"; next }
         print > pre; next
       }
       if (state == "in") {
         if ($0 == e) { state = "post"; print e > post; next }
         next
       }
       # state == "post"
       print > post
     }' "$CONFIG"

   TMP_FINAL=$(mktemp)
   cat "$TMP_PRE" > "$TMP_FINAL"
   # Append freshly assembled nav between markers.
   assemble_nav_block >> "$TMP_FINAL"
   cat "$TMP_POST" >> "$TMP_FINAL"

   mv "$TMP_FINAL" "$CONFIG"
   rm -f "$TMP_PRE" "$TMP_POST"
   ```

   The marker lines themselves are emitted by `assemble_nav_block` so the final file keeps its start + body + end in one contiguous region. Dry-run mode prints the assembled nav block to stdout instead of writing the config.

8. **Final block shape** (what `assemble_nav_block` writes to stdout):

   ```yaml
   # >>> M012-P01 nav (auto-generated — do not edit by hand)
   nav:
     - Home: index.md
     - Constitution: constitution.md
     - Decisions: decisions.md
     - Knowledge: knowledge.md
     - Milestone Summary: milestone-summary.md
     - Milestones:
       - Overview: milestones/index.md
       - M001:
         - Overview: milestones/M001/index.md
         - Context: milestones/M001/M001-CONTEXT.md
         ...
         - P01:
           - Overview: milestones/M001/phases/P01/index.md
           - Plan: milestones/M001/phases/P01/P01-PLAN.md
           ...
     - Archive:
       - Overview: archive/index.md
       - M###:
         ...
   # <<< M012-P01 nav end
   ```

9. **Idempotency**: running twice in a row without scanner output changing produces a byte-identical `wiki/mkdocs.yml`.

10. **Smoke check** after writing (manual; do NOT embed as a Check): `head -n 120 wiki/mkdocs.yml` — confirm markers + `nav:` + expected top-level entries. If `mkdocs` installed: `bash scripts/wiki/wiki-serve.sh --probe` — strict build must succeed.

## Must-Haves

- `scripts/wiki/wiki-generate-nav.sh` exists, is executable, Bash 3.2 compliant.
- After running the generator once, `wiki/mkdocs.yml` contains a `nav:` block between the marker comments.
- Top-level nav includes (in order): `Home`, `Constitution`, `Decisions`, `Knowledge`, `Milestone Summary`, `Milestones`, `Archive`.
- Every in-scope milestone (every `.orchestrator/milestones/M###/` under scanner output) appears as an expandable group under `Milestones`.
- Every in-scope archived milestone appears under `Archive`.
- Every scanner record maps to exactly one nav entry (no orphaned stubs, no missing entries).
- Running the generator twice produces byte-identical `wiki/mkdocs.yml` (idempotency).
- No copied or symlinked artifact appears; every `nav:` leaf points at a stub under `wiki/docs/`.

## Verification

- `bash scripts/verify/m012-p01-nav-structure.sh` (T05) — asserts the seven top-level nav labels appear in order; asserts `Archive:` appears exactly once; asserts every scanner entry has a matching nav line.
- `bash scripts/verify/m012-p01-include-plugin.sh` (T05) — indirectly validated (stubs referenced by nav exist).
- `bash scripts/verify/m012-p01-bash32-compat.sh` (T05) — scans this script.
- `bash scripts/verify/m012-p01-serve-smoke.sh` (T05) — strict mkdocs build exits 0 (probe mode).

Manual smoke check during this task (run once; do NOT embed as a Check):

1. `bash scripts/wiki/wiki-generate-nav.sh --dry-run | head -n 60` — sanity-check the assembled block.
2. `bash scripts/wiki/wiki-generate-nav.sh` — write to `wiki/mkdocs.yml`.
3. `diff <(bash scripts/wiki/wiki-generate-nav.sh --dry-run) <(bash scripts/wiki/wiki-generate-nav.sh --dry-run)` — empty diff (deterministic).
4. `grep -c '^nav:' wiki/mkdocs.yml` — exactly 1.

## Inputs

### From Previous Tasks

- **T01**: `wiki/mkdocs.yml` base — no existing `nav:` key; `plugins:` block declares `include-markdown`.
- **T02**: `scripts/wiki/wiki-scan-sources.sh` — emits `<category>|<rel-path>|<title>` per in-scope artifact, stable lexical order.
- **T03**: `wiki/docs/**` stubs — one per scanner record; section indexes (`milestones/index.md`, `archive/index.md`, per-milestone/per-phase `index.md`).

### Scanner Output Contract (reproduced for zero-context execution)

- Line format: `<category>|<rel-path>|<title>`.
- Category enum: `top:constitution`, `top:decisions`, `top:knowledge`, `top:milestone-summary`, `milestone:<M###>`, `archive:<M###>`.
- Stable lexical ordering as detailed in T02.

### From Disk (Pre-existing)

- `wiki/docs/**/*.md` — stubs + section indexes produced by T03. The nav generator checks their existence (via path-reconstruction) but does not read their bodies.

## Constraints

- **Bash 3.2** — per MEM001. macOS baseline. No `declare -A`; use parallel indexed arrays if any cross-iteration state is needed.
- **MEM004 carve-out** — helper-internal; pipes, `$()`, awk, heredocs permitted.
- **Atomic write** — write to a temp file under the config's directory, then `mv` over `wiki/mkdocs.yml`. Partial writes on crash are forbidden.
- **Marker discipline** — the entire auto-generated nav region lives between the two marker comments and nowhere else. Never rewrite content outside markers.
- **Deterministic output** — same scanner output → byte-identical nav block.
- **YAML escaping** — titles with `:`, `#`, `"` are double-quoted; internal `"` becomes `\"`. Titles with newlines are forbidden (shouldn't happen — scanner emits single-line titles).
- **Single-script-file `Check:` shape (AD-19)** — all T05 Checks remain single-invocation.

## Expected Output

- `scripts/wiki/wiki-generate-nav.sh` — executable, Bash 3.2 compliant, ≥ 60 lines, supports `--dry-run` and `--root`.
- `wiki/mkdocs.yml` contains a `nav:` block bounded by the two marker comments, with the seven top-level sections in fixed order and every in-scope artifact reachable under the correct section.
- Running the generator twice is a no-op (byte-identical output).
- If `mkdocs` is on PATH, `bash scripts/wiki/wiki-serve.sh --probe` exits 0.
