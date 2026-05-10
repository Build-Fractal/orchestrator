---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M032"
name: "Glossary surface — wiki/glossary.md path convention + wiki-scan-sources.sh --include-glossary + wiki-generate-nav.sh Glossary-as-second-entry (FR-15)"
depends_on: ["T01"]
---

## Prerequisites

- T01 has landed `scripts/lifecycle/wiki-init.sh` with the FR-15 path-convention stub authoring at the consumer side. Verified by `[ -x scripts/lifecycle/wiki-init.sh ]` and `grep -q 'wiki/glossary.md' scripts/lifecycle/wiki-init.sh`.
- `scripts/wiki/wiki-scan-sources.sh` exists at the orchestrator-repo root as the canonical scanner. Verified by `[ -x scripts/wiki/wiki-scan-sources.sh ]`.
- `scripts/wiki/wiki-generate-nav.sh` exists at the orchestrator-repo root as the canonical nav generator. Verified by `[ -x scripts/wiki/wiki-generate-nav.sh ]` and `grep -q '# >>> M012-P01 nav' scripts/wiki/wiki-generate-nav.sh`. The pre-M032 nav generator writes the entire `nav:` block between `# >>> M012-P01 nav` and `# <<< M012-P01 nav end` markers in `wiki/mkdocs.yml`.
- `wiki/` exists as a directory at the orchestrator-repo root containing the dogfood wiki tooling.
- `wiki/mkdocs.yml` exists with the `# >>> M012-P01 nav (auto-generated — do not edit by hand)` marker at line 69 and `# <<< M012-P01 nav end` marker at line 1726 (per the pre-M032 state).
- T03 entry: `wiki/glossary.md` does NOT exist at the orchestrator-repo root. The pre-M032 `wiki-scan-sources.sh` does NOT carry an `--include-glossary` flag; pre-M032 `wiki-generate-nav.sh` does NOT enumerate the glossary path.

## Description

T03 lands the [M033](../../../../../milestones/M033/index.md) grilling-protocol surface CON-6 mandates. The glossary surface has three parts:

1. **The path convention**: `wiki/glossary.md` is THE canonical project-glossary location. The format invariant per US-6: alphabetized term entries, `### TERM` heading style, one-line definition immediately under the heading, at most a two-line elaboration paragraph below the definition. T03 authors the orchestrator-repo-level `wiki/glossary.md` with at least three example entries demonstrating the format.

2. **The scanner extension**: `scripts/wiki/wiki-scan-sources.sh` gains an additive `--include-glossary` flag. When the flag is on (default-on per FR-15), the scanner emits `wiki/glossary.md` as the SECOND top-level source entry (after Constitution). When the flag is off (`--include-glossary=false`), the scanner emits the pre-M032 source list unchanged. Pre-M032 invocations without the flag default to ON per FR-15 — the additive default is "include glossary unless explicitly opted out."

3. **The nav generator extension**: `scripts/wiki/wiki-generate-nav.sh` consumes the scanner output and places the Glossary nav entry as the second top-level entry in the regenerated `nav:` block. The placement is additive only — T03 does NOT split the existing `# >>> M012-P01 nav` markers into auto-nav / custom-nav regions (that's P03's deliverable per FR-14).

The path-convention stub in `wiki-init.sh` (T01 deliverable) authors a CONSUMER-SIDE `<PROJECT_DIR>/wiki/glossary.md` when one is absent. T03 authors the ORCHESTRATOR-REPO-LEVEL `wiki/glossary.md` separately because (a) the orchestrator repo is itself a project that benefits from a populated glossary, and (b) the FR-6 self-application loop in T01 invokes `wiki-init.sh --project-dir .` against the orchestrator repo, which would author a STUB at `wiki/glossary.md` if absent — T03's authoring of the orchestrator-repo-level file pre-empts that stub-author and ships a populated glossary instead.

## Steps

1. **Read the pre-M032 `scripts/wiki/wiki-scan-sources.sh`** to identify (a) the source-emission loop, (b) the location where Constitution is emitted as the first top-level source. Plan the `--include-glossary` flag handling and the glossary-emission insertion point immediately after Constitution.

2. **Read the pre-M032 `scripts/wiki/wiki-generate-nav.sh`** to identify (a) the line where the nav block is assembled (line 270 per the pre-T03 state — `printf 'nav:\n' >> "$NAV_BODY"`), (b) the marker lines (`MARKER_START=...` at line 98, `MARKER_END=...` at line 99). Plan the Glossary placement immediately after the Constitution nav entry.

3. **Author `wiki/glossary.md`** at the orchestrator-repo root with at least three example entries demonstrating the US-6 format invariant. Required content (verbatim — agents MAY add additional alphabetically-sorted entries but MUST NOT remove or reorder these three):

```markdown
# Glossary

Project glossary for orchestrator — alphabetized term entries with
one-line definitions and at most a two-line elaboration. M033's grilling
protocol writes inline into this file as terms resolve.

Format invariant (per US-6 / M032/P02/T03):

- Heading style: `### TERM` (level-3 heading, term name capitalized).
- One-line definition immediately under the heading.
- At most a two-line elaboration paragraph below the definition.
- Entries alphabetized at file scope.

---

### Constitution

The seven governing principles authored at `.orchestrator/memory/constitution.md` that gate every orchestrator decision.

The constitution is amended via the formal amendment process documented in `.orchestrator/proposals/constitution-amendment-inclusion-criteria.md`; principles are added only when they fail the inclusion-criteria gate.

### Knowledge Graph

The on-disk record of patterns, conventions, lessons, and decisions accumulated across milestones, projected into the wiki via `scripts/wiki/wiki-scan-sources.sh`.

The graph is the orchestrator's product core; wiki / Jira / Notion projections are views (per `project_knowledge_graph_vision.md`). Cross-company comment / scan / AI-Q&A is the engagement loop.

### Milestone

A multi-phase delivery unit closed by a `M###-VALIDATED` marker file plus a `M###-SUMMARY.md` plus an `unit_close` JSONL record per the M030/M031 close discipline.

Milestones decompose into phases (typically P00–P0N); phases decompose into tasks (T01–T0N). Each task is one fresh-context dispatch.
```

The three entries are alphabetized (Constitution, Knowledge Graph, Milestone) and demonstrate the format. M033's grilling protocol will append further entries inline as terms resolve in greenfield-with-materials and existing-codebase branches.

4. **Amend `scripts/wiki/wiki-scan-sources.sh`** to add the `--include-glossary` flag. The amendment is additive — the pre-M032 source-emission logic is preserved. Required structure:

```bash
# In the argument-parsing block, add:
INCLUDE_GLOSSARY=1   # default-on per FR-15

# In the case statement, add:
    --include-glossary) INCLUDE_GLOSSARY=1; shift ;;
    --include-glossary=true) INCLUDE_GLOSSARY=1; shift ;;
    --include-glossary=false) INCLUDE_GLOSSARY=0; shift ;;
    --no-include-glossary) INCLUDE_GLOSSARY=0; shift ;;

# After the Constitution emission (find the line that emits the Constitution
# source as the first top-level source — emission shape is scanner-specific;
# the canonical pattern in scripts/wiki/wiki-scan-sources.sh prints a path
# preceded by a section/depth marker), insert the glossary emission:

if [ "$INCLUDE_GLOSSARY" = "1" ] && [ -f "$ROOT/wiki/glossary.md" ]; then
  # Emit the glossary path in the same shape as Constitution (scanner-specific
  # — match the pre-M032 emission convention exactly: same field separators,
  # same section markers, same depth indentation). FR-15.
  printf 'wiki/glossary.md\n'
fi
```

The exact emission shape MUST match the scanner's pre-M032 convention (path-only or path+section+depth — read the pre-M032 emission for Constitution and replicate the form for the glossary). The emission MUST appear AFTER Constitution and BEFORE the next top-level source.

5. **Amend `scripts/wiki/wiki-generate-nav.sh`** to place Glossary as the second top-level nav entry. The nav generator consumes the scanner output and writes the `nav:` block between the `# >>> M012-P01 nav` markers in `wiki/mkdocs.yml`. The amendment is additive — the pre-M032 marker shape is preserved (region split into auto-nav / custom-nav is P03's deliverable per FR-14).

Required structure:

```bash
# After the Constitution nav entry is emitted into $NAV_BODY (find the line
# that emits the Constitution top-level entry — emission shape is generator-
# specific; the canonical pattern is `printf '  - Constitution: <path>\n'` or
# similar), insert the glossary emission:

if [ -f "$ROOT/wiki/glossary.md" ]; then
  printf '  - Glossary: glossary.md\n' >> "$NAV_BODY"
fi
```

The path emitted is `glossary.md` (relative to `wiki/docs/` per the mkdocs `docs_dir: docs` setting in `wiki/mkdocs.yml:14`). If the pre-M032 nav generator uses a different path convention for top-level entries (check via grep for the Constitution emission), match the same shape.

Important: the emission goes AFTER Constitution and BEFORE the next top-level entry. The exact line position depends on the pre-M032 generator structure — the post-Constitution / pre-everything-else slot is the FR-15 contract.

6. **Run the FR-6 self-application loop's complement against the new scanner+nav surface**. After the `wiki-scan-sources.sh` and `wiki-generate-nav.sh` amendments, regenerate the orchestrator's own nav by running:

```bash
bash scripts/wiki/wiki-generate-nav.sh --root .
```

Confirm the regenerated `wiki/mkdocs.yml` carries `- Glossary: glossary.md` as the second top-level nav entry under `# >>> M012-P01 nav`. The orchestrator-repo's `wiki-serve.sh` continues to render the wiki at `:8000` with the Glossary nav entry rendered correctly.

7. **Author the two T03 verifiers** under `tools/verify/`:

   **`m032-p02-glossary-format-invariant.sh`** — asserts (a) `wiki/glossary.md` exists at the orchestrator-repo root, (b) the file contains at least three `### TERM` headings, (c) each `### TERM` is followed within 2 lines by non-empty content (the one-line definition), (d) entries are alphabetized at file scope (use `awk` to extract `### .*` lines and verify sort order). Single-script-file shape:

```bash
#!/usr/bin/env bash
set -eu
G="wiki/glossary.md"
[ -f "$G" ] || { echo "FAIL: $G missing"; exit 1; }
# At least three ### TERM headings
HC="$(grep -c '^### ' "$G")"
[ "$HC" -ge 3 ] || { echo "FAIL: $G has only $HC ### TERM headings; need >= 3"; exit 1; }
# Alphabetized: extract terms, compare to sorted version
TERMS_TMP="$(mktemp)"
SORTED_TMP="$(mktemp)"
trap 'rm -f "$TERMS_TMP" "$SORTED_TMP"' EXIT
grep '^### ' "$G" | sed 's/^### //' > "$TERMS_TMP"
sort "$TERMS_TMP" > "$SORTED_TMP"
if ! diff -q "$TERMS_TMP" "$SORTED_TMP" >/dev/null; then
  echo "FAIL: $G entries not alphabetized"; exit 1
fi
# Format invariant: each ### heading has non-empty content within 2 lines below
awk '/^### /{h=NR; next} h && NR<=h+2 && NF>0 {h=0} END {if(h) {print "FAIL: glossary heading at line "h" has no body within 2 lines"; exit 1}}' "$G" || exit 1
echo "PASS: m032-p02-glossary-format-invariant"
```

   **`m032-p02-glossary-scanner-and-nav.sh`** — asserts (a) `bash scripts/wiki/wiki-scan-sources.sh --root . --include-glossary` emits a line containing `wiki/glossary.md`; (b) `bash scripts/wiki/wiki-scan-sources.sh --root . --no-include-glossary` does NOT emit a line containing `wiki/glossary.md`; (c) `bash scripts/wiki/wiki-generate-nav.sh --root .` regenerates `wiki/mkdocs.yml` with `- Glossary: glossary.md` (or scanner-shape-matched equivalent) as the second top-level nav entry under `# >>> M012-P01 nav`. Use `awk` to find the line numbers of `# >>> M012-P01 nav`, the first nav entry under it, and assert the Glossary entry is the second one.

Single-script-file shape per AD-19. Skeleton:

```bash
#!/usr/bin/env bash
set -eu
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# (a) include-glossary on (default + explicit)
bash scripts/wiki/wiki-scan-sources.sh --root . --include-glossary > "$TMP/sources-on.txt" 2>/dev/null
grep -q 'wiki/glossary.md' "$TMP/sources-on.txt" || { echo "FAIL: --include-glossary did not emit wiki/glossary.md"; exit 1; }

# (b) include-glossary off
bash scripts/wiki/wiki-scan-sources.sh --root . --no-include-glossary > "$TMP/sources-off.txt" 2>/dev/null
if grep -q 'wiki/glossary.md' "$TMP/sources-off.txt"; then
  echo "FAIL: --no-include-glossary still emitted wiki/glossary.md"; exit 1
fi

# (c) nav generator placement — back up mkdocs.yml, regenerate, inspect, restore.
cp wiki/mkdocs.yml "$TMP/mkdocs.yml.bak"
bash scripts/wiki/wiki-generate-nav.sh --root . >/dev/null 2>&1
# Find the marker line and the entry just after it
MARKER_LINE="$(grep -n '^# >>> M012-P01 nav' wiki/mkdocs.yml | head -1 | cut -d: -f1)"
[ -n "$MARKER_LINE" ] || { echo "FAIL: marker not found"; cp "$TMP/mkdocs.yml.bak" wiki/mkdocs.yml; exit 1; }
# The first nav entry should be Constitution; the second should be Glossary.
SECOND_ENTRY="$(awk -v start="$MARKER_LINE" 'NR>start && /^  - / {count++; if(count==2){print; exit}}' wiki/mkdocs.yml)"
echo "$SECOND_ENTRY" | grep -q 'Glossary' || { echo "FAIL: Glossary not the second top-level nav entry; got: $SECOND_ENTRY"; cp "$TMP/mkdocs.yml.bak" wiki/mkdocs.yml; exit 1; }

# Restore mkdocs.yml (verifier should not leave the orchestrator's wiki regenerated as a side effect)
cp "$TMP/mkdocs.yml.bak" wiki/mkdocs.yml

echo "PASS: m032-p02-glossary-scanner-and-nav"
```

8. **Run both T03 verifiers locally** to confirm exit 0 from each.

## Must-Haves

- `wiki/glossary.md` exists at the orchestrator-repo root with at least three `### TERM` headings, alphabetized at file scope, each with a one-line definition and at-most-two-line elaboration per the US-6 format invariant.
- `scripts/wiki/wiki-scan-sources.sh` carries an additive `--include-glossary` flag (default-on, with `--no-include-glossary` / `--include-glossary=false` for opt-out) that emits `wiki/glossary.md` as the second top-level source after Constitution.
- `scripts/wiki/wiki-generate-nav.sh` consumes the scanner output and places `- Glossary: glossary.md` (or scanner-shape-matched equivalent) as the second top-level nav entry under the existing `# >>> M012-P01 nav` markers in `wiki/mkdocs.yml`. The marker shape itself is preserved (no region split into auto-nav / custom-nav — that's P03).
- The orchestrator's own `wiki/mkdocs.yml` after a fresh `bash scripts/wiki/wiki-generate-nav.sh --root .` carries the Glossary entry as the second top-level nav entry.
- Both T03 verifiers under `tools/verify/m032-p02-{glossary-format-invariant,glossary-scanner-and-nav}.sh` exist, are executable, and exit 0 against the T03-landed surface.

## Verification

```bash
bash tools/verify/m032-p02-glossary-format-invariant.sh
bash tools/verify/m032-p02-glossary-scanner-and-nav.sh
```

## Inputs

### From Previous Tasks

- `scripts/lifecycle/wiki-init.sh` (from T01) — authors the consumer-side `<PROJECT_DIR>/wiki/glossary.md` stub when absent. T03's orchestrator-repo-level `wiki/glossary.md` is authored independently and pre-empts the stub author when the FR-6 self-application loop runs `wiki-init.sh --project-dir .` against the orchestrator. Key API: T01's `wiki-init.sh` authors a stub at `<PROJECT_DIR>/wiki/glossary.md` if and only if no file exists there.

### From Disk (Pre-existing)

- `scripts/wiki/wiki-scan-sources.sh` — pre-M032 source scanner. Carries the existing argument-parsing loop and the source-emission loop for top-level sources (Constitution, Decisions, Knowledge, Milestones, etc.). T03 amends additively with the `--include-glossary` flag and the glossary emission.
- `scripts/wiki/wiki-generate-nav.sh` — pre-M032 nav generator. Carries the marker-line constants (`MARKER_START=# >>> M012-P01 nav (auto-generated — do not edit by hand)` at line 98; `MARKER_END=# <<< M012-P01 nav end` at line 99) and the `printf 'nav:\n' >> "$NAV_BODY"` block at line 270. T03 amends additively with the Glossary emission immediately after Constitution.
- `wiki/mkdocs.yml` — orchestrator-repo dogfood wiki config with the `# >>> M012-P01 nav` marker at line 69 and `# <<< M012-P01 nav end` marker at line 1726. T03 does NOT directly modify this file; the regenerated nav block is written by `wiki-generate-nav.sh` invocation.
- `wiki/docs/` — pre-M032 docs directory (mkdocs `docs_dir: docs` per `wiki/mkdocs.yml:14`). The Glossary nav entry's path (`glossary.md`) is relative to this directory.

## Constraints

- T03 MUST NOT split the existing `# >>> M012-P01 nav` markers into auto-nav / custom-nav regions — that's P03's deliverable per FR-14. The marker shape is preserved verbatim.
- T03 MUST NOT modify `wiki/mkdocs.yml` directly — the nav block is regenerated via `wiki-generate-nav.sh` invocation. Any direct sed against `mkdocs.yml`'s nav block belongs in `wiki-generate-nav.sh`, not in T03's commit body.
- The `--include-glossary` flag MUST be default-on per FR-15. Operators who want pre-M032 behavior MUST explicitly pass `--no-include-glossary` or `--include-glossary=false`.
- The Glossary entry MUST be the SECOND top-level nav entry, after Constitution. If the pre-M032 nav generator emits Constitution as something other than the first top-level entry, the placement convention adapts — but the contract is "after Constitution, before everything else," which the verifier asserts via `awk` on the regenerated `mkdocs.yml`.
- Bash 3.2 compatibility per MEM001 in both the scanner and nav-generator amendments.
- Single-script-file shape per AD-19 in both T03 verifiers — `awk` extraction is fine, `grep`/`sed` chains within `$()` are fine, but `$()` containing a pipe is forbidden. The scanner-shape-matched glossary emission MUST mirror the pre-M032 Constitution emission exactly so the nav generator's downstream consumption logic doesn't need amendment.

## Expected Output

After T03 completes:

- `wiki/glossary.md` is a new file at the orchestrator-repo root with at least three alphabetized `### TERM` entries.
- `scripts/wiki/wiki-scan-sources.sh` carries the `--include-glossary` flag (default-on) and emits `wiki/glossary.md` as the second top-level source after Constitution when on.
- `scripts/wiki/wiki-generate-nav.sh` places `- Glossary: glossary.md` (or scanner-shape-matched equivalent) as the second top-level nav entry under `# >>> M012-P01 nav` in regenerated `wiki/mkdocs.yml`.
- The orchestrator's wiki at `:8000` continues to render with Glossary as the second top-level nav entry.
- Both T03 verifiers exit 0.

## Notes

- Expected verifier outputs: `PASS: m032-p02-glossary-format-invariant` and `PASS: m032-p02-glossary-scanner-and-nav` to stdout on exit 0.
- Plan-time discipline rule 2 (verifier-availability cross-check): both verifiers cited in `## Verification` are co-authored within this task in step 7.
- Plan-time discipline rule 6 (path-collision check): `wiki/glossary.md`, `tools/verify/m032-p02-glossary-format-invariant.sh`, and `tools/verify/m032-p02-glossary-scanner-and-nav.sh` do NOT exist on disk at plan-authoring time (verified — `wiki/glossary.md: No such file or directory` confirmed). `scripts/wiki/wiki-scan-sources.sh` and `scripts/wiki/wiki-generate-nav.sh` are explicitly modified, not created.
- The verifier `m032-p02-glossary-scanner-and-nav.sh` MUST restore `wiki/mkdocs.yml` to its pre-verifier state at the end (after the regeneration probe) — running the verifier should be side-effect-free against the orchestrator's own working tree. Use `cp wiki/mkdocs.yml $TMP/mkdocs.yml.bak` before regeneration and `cp $TMP/mkdocs.yml.bak wiki/mkdocs.yml` at the end. The orchestrator's wiki regenerated nav from T03's surface IS the orchestrator's resting state — but the verifier should not commit that as a side effect of running.
- The path-convention contract: `wiki/glossary.md` (NOT `wiki/docs/glossary.md` or `glossary.md` at the project root). `wiki/docs/` is the mkdocs `docs_dir`; the nav generator references the path relative to `docs_dir`, but the file itself lives at `wiki/glossary.md`. The mkdocs include-markdown plugin (per `wiki/mkdocs.yml:34-36`) bridges this — the nav entry `glossary.md` is rendered by including the file from `wiki/glossary.md` via the docs/ stub generated by `wiki-generate-stubs.sh`. T03 does NOT need to amend `wiki-generate-stubs.sh` — the stub generator is path-agnostic and picks up new sources automatically when the scanner emits them.
