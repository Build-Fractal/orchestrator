---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M037"
name: "Feedback routing arm in stub generator + scan-sources enumeration"
depends_on: []
---

## Prerequisites

- `scripts/wiki/wiki-generate-stubs.sh` exists (verified at plan-authoring time, ~1300 lines, contains `proposals:*` routing arm at lines 1056-1071, `register_child` helper at line 965, `existing_stub_is_protected()` helper added by P01/T02 at FR-5 conditional-overwrite block, `write_stub` helper signature `<STUB_ABS> <CANONICAL> <TITLE> <CANONICAL_ABS> <rewrite_relative_urls>`).
- `scripts/wiki/wiki-scan-sources.sh` exists (verified at plan-authoring time, ~600 lines, contains FR-17 proposals enumeration block at lines 322-337, `extract_title` helper at lines 113-126, `should_exclude` helper at lines 138-176, `INCLUDE_PROPOSALS` flag handling at lines 62-77).
- `scripts/wiki/wiki-generate-nav.sh` exists (verified at plan-authoring time; consumes `register_child` section-index records emitted by stubs.sh).
- `tests/m037-acceptance/run-acceptance-battery.sh` exists (verified at plan-authoring time, P01/T06 deliverable; battery glob picks up `p01-*.sh` automatically — new `p01-feedback-routing.sh` will be auto-included).
- This repo has zero `.orchestrator/feedback/*.md` files (verified — directory does not exist). Test runs against synthetic fixture only; this repo's feedback directory MAY be created by future operator usage.

## Description

Lands FR-18 (feedback/ routing arm) per US-10 and SC-13. PBJ-central operator hand-scaffolded two stubs to get past wiki-deploy gate 2 because `KNOWLEDGE.md` cross-links `feedback/<file>.md` and the link-checker (correctly) treats them as in-scope. Source: `papercut-sweep-wiki-deploy-2026-05-07.md` finding #1.

Add a new `feedback:<basename>` routing arm to `wiki-generate-stubs.sh` mirroring the existing `proposals:*` arm. Inputs: `.orchestrator/feedback/*.md` (one record per file via the scanner's new enumeration block). Outputs: `wiki/docs/feedback/<basename>.md` stubs with fragment-only passthrough (`rewrite-relative-urls=false` per B5 precedent). Title derivation: H1 of source file when present; humanized-basename fallback when H1 absent (debug-level diagnostic on fallback). Section index emission via `register_child` so `wiki-generate-nav.sh` surfaces a `feedback:` bucket without manual `nav:` edits. The routing arm MUST be idempotent: removing a source file removes the corresponding stub on next generation.

**MIT-01/02 inheritance**: Operator-edited stubs declaring `auto_generated: false` MUST survive byte-identical across re-runs. P01/T02 established the `existing_stub_is_protected()` helper for this. T01 MUST CONSUME the helper, NOT FORK it. Routing arm calls `existing_stub_is_protected "$STUB_ABS"` immediately before `write_stub` and skips the write when the helper returns 0 (protected).

## Steps

1. **Modify `scripts/wiki/wiki-scan-sources.sh`** to add a feedback enumeration block parallel to the existing proposals block (lines 322-337). Insert AFTER the proposals block:

   ```bash
   # ---- FR-18 (M037/P02/T01) — feedback enumeration --------------------------
   # Emits one record per .orchestrator/feedback/*.md entry. Title field is the
   # H1 of the source file (via extract_title helper); falls back to humanized
   # basename when H1 absent (the existing extract_title helper already does
   # this — basename without extension, lowercased, dashes preserved). Records
   # land at category prefix "feedback:<basename>"; the per-record relative
   # path is "feedback/<basename>.md" (relative to .orchestrator/). Default-on;
   # opt out via INCLUDE_FEEDBACK=0 env override (no CLI flag — feedback is
   # always-in-scope by design unless explicitly suppressed).
   if [ "${INCLUDE_FEEDBACK:-1}" = "1" ] && [ -d "$ORCH/feedback" ]; then
     _flist="/tmp/wiki-scan-feedback.$$"
     find "$ORCH/feedback" -maxdepth 1 -type f -name '*.md' 2>/dev/null | LC_ALL=C sort > "$_flist"
     while IFS= read -r _fpath; do
       [ -n "$_fpath" ] || continue
       _frel=${_fpath#"$ROOT/.orchestrator/"}
       if should_exclude "$_frel"; then
         continue
       fi
       _fbase=$(basename "$_fpath" .md)
       _ftitle=$(extract_title "$_fpath")
       printf '%s|%s|%s\n' "feedback:$_fbase" "$_frel" "$_ftitle"
       COUNT=$((COUNT + 1))
     done < "$_flist"
     rm -f "$_flist"
   fi
   ```

   Place after line 338 (end of the proposals block; immediately before the next `if [ "$INCLUDE_KNOWLEDGE_FLAT" = "1" ]` block or wherever the proposals block ends in the live file).

   Also add the `feedback` token to the reserved-top-level-collision check at line 567:

   ```bash
       constitution|decisions|knowledge|milestone-summary|glossary|milestones|archive|proposals|feedback)
   ```

   This prevents an operator's `wiki.extra_dirs:` declaring `feedback` from colliding with the new top-level routing.

2. **Modify `scripts/wiki/wiki-generate-stubs.sh`** to add a `feedback:*` routing arm. Insert AFTER the `proposals:*` arm (lines 1060-1072):

   ```bash
   # ---- feedback:* routing (M037/P02/T01 FR-18) -----------------------------
   # feedback:<basename> records route to wiki/docs/feedback/<basename>.md.
   # The canonical source lives at .orchestrator/feedback/<basename>.md, so we
   # use build_canonical (which prepends .orchestrator/). REL is "feedback/<file>".
   # Mirror of the proposals:* shape; differs only in path prefix.
   #
   # MIT-01/02 inheritance: operator-edited stubs declaring `auto_generated: false`
   # in their YAML frontmatter survive re-runs byte-identical. The check delegates
   # to the P01/T02 existing_stub_is_protected() helper.
   case "$CAT" in
     feedback:*)
       _fbase=${CAT#feedback:}
       STUB_REL="feedback/${_fbase}.md"
       STUB_ABS="$DOCS/$STUB_REL"
       CANONICAL=$(build_canonical "$STUB_REL" "$REL")
       CANONICAL_ABS="$ROOT/.orchestrator/$REL"
       # MIT-01/02: skip write when operator escape-hatch is set on existing stub
       if existing_stub_is_protected "$STUB_ABS"; then
         register_child "feedback" "${_fbase}.md" "$TITLE"
         continue
       fi
       # B5: feedback files are self-contained SME signoff captures —
       # fragment-only passthrough (rewrite-relative-urls=false).
       write_stub "$STUB_ABS" "$CANONICAL" "$TITLE" "$CANONICAL_ABS" "false"
       register_child "feedback" "${_fbase}.md" "$TITLE"
       continue
       ;;
   esac
   ```

   Idempotent removal of stale stubs is handled by the existing `prune_orphan_stubs` (or equivalent) pass that compares emitted-stub paths against `wiki/docs/<dn>/*.md` files; the feedback dir gets the same treatment automatically because the scanner is the source-of-truth and emits zero records when source files are removed. Verify by running the generator twice — once with a fixture file present, once with it removed — and assert the stub disappears.

3. **Create the test fixture corpus** at `tests/fixtures/m037-feedback-routing/`:

   - `tests/fixtures/m037-feedback-routing/case-1-h1-derived/.orchestrator/feedback/round-3-sme-feedback.md`:
     ```markdown
     # Round 3 SME Feedback

     Synthetic test fixture exercising H1-derived title.
     ```

   - `tests/fixtures/m037-feedback-routing/case-2-humanized-basename/.orchestrator/feedback/round-4-no-h1.md`:
     ```markdown
     Synthetic test fixture exercising humanized-basename fallback.
     No H1 heading; first line is body text.
     ```

   - `tests/fixtures/m037-feedback-routing/case-3-idempotent-removal/.orchestrator/feedback/will-be-removed.md`:
     ```markdown
     # Will Be Removed

     Synthetic test fixture exercising idempotent removal — the test
     creates this file, runs the generator, removes it, re-runs the
     generator, and asserts the corresponding stub disappears.
     ```

   Each fixture also needs a minimal `.orchestrator/config.yml` and the wiki/ scaffold files so `wiki-generate-stubs.sh --root <fixture>` runs cleanly. Reuse the helper pattern from `tests/m037-acceptance/p01-feedback-routing.sh` step 4 (next step) to scaffold each fixture from the parent repo's templates at test-run time rather than hand-authoring full wiki/ trees.

4. **Author `tests/m037-acceptance/p01-feedback-routing.sh`** (SC-13). The test:
   - Creates a temp dir via `mktemp -d`; copies the three fixture corpus directories into the temp.
   - For each case, runs `bash scripts/wiki/wiki-scan-sources.sh --root <fixture>` and asserts the output contains a `feedback:<basename>|...` record.
   - For each case, runs `bash scripts/wiki/wiki-generate-stubs.sh --root <fixture>` and asserts:
     - Case 1: `<fixture>/wiki/docs/feedback/round-3-sme-feedback.md` exists, frontmatter `title:` field equals `Round 3 SME Feedback`.
     - Case 2: `<fixture>/wiki/docs/feedback/round-4-no-h1.md` exists, frontmatter `title:` field is non-empty (humanized basename — exact format depends on `extract_title` fallback shape; the contract is "non-empty, derived from basename when H1 absent").
     - Case 3: `<fixture>/wiki/docs/feedback/will-be-removed.md` exists. Then remove the source file. Re-run the generator. Assert the stub no longer exists.
   - Idempotent re-run case: run the generator twice on case-1 with a hand-edited stub carrying `auto_generated: false` and an operator-modified `title:` value. Assert the operator's `title:` survives byte-identical (MIT-01/02 escape hatch).
   - Emits `PASS: m037-p02-feedback-routing` on success; `FAIL: <reason>` on any assertion failure with non-zero exit.

5. **Author `tools/verify/m037-p02-feedback-routing.sh`**. The verifier:
   - Greps `scripts/wiki/wiki-scan-sources.sh` for the literal string `feedback:` and the literal string `INCLUDE_FEEDBACK`. Both must be present.
   - Greps `scripts/wiki/wiki-generate-stubs.sh` for the literal string `feedback:*)` and the literal string `existing_stub_is_protected`. Both must be present.
   - Invokes `bash tests/m037-acceptance/p01-feedback-routing.sh` and propagates exit code.
   - Emits `SUMMARY: m037-p02-feedback-routing pass=N fail=M` on completion.

## Must-Haves

- T1 (FR-18 routing arm) — phase plan.
- T2 (scan-sources feedback enumeration) — phase plan.
- T3 (MIT-01/02 escape-hatch inheritance) — phase plan.

## Verification

```bash
bash tools/verify/m037-p02-feedback-routing.sh
```

```bash
bash tests/m037-acceptance/p01-feedback-routing.sh
```

## Inputs

### From Previous Tasks

- `scripts/wiki/wiki-generate-stubs.sh` (from M037/P01/T02)
  - Key API: `existing_stub_is_protected <stub-abs-path>` — exits 0 when stub exists AND its YAML frontmatter contains `auto_generated: false`; exits non-zero otherwise.
  - Key API: `write_stub <stub-abs> <canonical> <title> <canonical-abs> <rewrite-rel-urls-bool>` — emits stub file at `<stub-abs>`. The fifth argument is the literal string `false` for fragment-only passthrough (B5 precedent).
  - Key API: `register_child <section-relative-path> <basename> <title>` — registers child entry for downstream `wiki-generate-nav.sh` consumption.
  - Key API: `build_canonical <stub-rel> <source-rel>` — computes the canonical source path for an `.orchestrator/`-rooted source.

### From Disk (Pre-existing)

- `scripts/wiki/wiki-scan-sources.sh` — proposals enumeration block at lines 322-337 is the structural template for the new feedback block.
- `tests/m037-acceptance/run-acceptance-battery.sh` — auto-glob picks up the new `p01-feedback-routing.sh`.
- `tools/verify/m037-p01-phase-suite.sh` — pattern reference for verifier shape (straight-line aggregator, AD-19 compliant).

## Constraints

- AD-19: all `Check:` commands use single-script-file shape. The verifier itself MAY use compound shell internally (executes via `bash`, not via the harness Bash tool).
- Bash 3.2 + POSIX sh only. NO `yq`, `python`, `process substitution <(...)`, `mapfile`, or bash 4+ associative arrays inside the routing-arm or scanner additions. Match the existing surrounding-code shape.
- CON-2 projection-not-source-mutation: T01 MUST NOT modify `.orchestrator/feedback/*.md` source files. The routing arm reads frontmatter (via stubs.sh's existing helpers) and emits derived stubs at `wiki/docs/feedback/`. Source files remain authoritative.
- MIT-01/02 escape-hatch: REUSE `existing_stub_is_protected()` helper, do not fork. P01-SUMMARY explicitly names this as a load-bearing pattern.
- Knowledge-Layer Boundary: T01 reads `.orchestrator/feedback/*.md` source files but MUST NOT mutate them or the knowledge graph. No edge-type catalogue changes; no chunk frontmatter schema changes.

## Expected Output

After T01 ships:
- `bash scripts/wiki/wiki-scan-sources.sh --root <repo>` includes one `feedback:<basename>` record per `.orchestrator/feedback/*.md` source file (zero today; non-zero on consumer projects with the convention).
- `bash scripts/wiki/wiki-generate-stubs.sh --root <repo>` emits stubs at `wiki/docs/feedback/<basename>.md` for each record.
- Operator-edited stubs with `auto_generated: false` survive byte-identical across re-runs.
- `bash tests/m037-acceptance/p01-feedback-routing.sh` exits 0; `bash tools/verify/m037-p02-feedback-routing.sh` reports `SUMMARY: m037-p02-feedback-routing pass=N fail=0`.

## Notes

The feedback routing arm uses `auto_generated: true` by default in emitted stubs (consistent with the proposals routing arm via `write_stub`'s frontmatter emit). Operators who want to hand-edit a feedback stub flip `auto_generated: true` → `false` and the next re-run preserves their edits. This is the same escape-hatch contract documented in P01 SC-2 MIT-02 fixture.

The reserved-top-level collision check addition is a forward-compatibility guard: if an operator declared `wiki.extra_dirs: [feedback]` (which would route their `<repo-root>/feedback/*.md` content to `/feedback/`), it would collide with the new `.orchestrator/feedback/` routing. Failing loud at scan time matches the existing [M032](../../../../../milestones/M032/index.md) B3 pattern for `proposals`, `decisions`, etc.

The fixture corpus uses `tests/fixtures/m037-feedback-routing/` (NOT `tests/fixtures/m037-version-projection/` or other P01-fixture paths) to avoid clobbering P01 fixtures. Path-collision check passed at plan-authoring time (`ls tests/fixtures/m037-feedback-routing` → no such directory).
