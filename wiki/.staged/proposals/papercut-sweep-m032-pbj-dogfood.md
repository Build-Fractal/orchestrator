# Paper-cut Sweep — [M032](../milestones/M032/index.md) wiki tooling, PBJ-central dogfood

**Status:** Active — patches landing this commit.
**Authored:** 2026-05-06.
**Surfaced by:** PBJ-central-mono-repo's `orchestrator:wiki-init` standup
attempt against the M036-closed reference corpus (145 chunks ingested,
Track A wiki standup attempted). Five distinct M012/M032 wiki-tooling
issues + one separate-domain extraction gap surfaced.

## Why a paper-cut sweep, not a new milestone

M032 (wiki distribution + init integration) closed 2026-05-05 with a
documented Deferred-Validation Acknowledgment block (SC-5 fixture-
completeness skip). These five issues are post-close paper-cuts surfaced
by the first non-orchestrator-internal consumer to drive M012/M032 wiki
tooling end-to-end. Precedent: `papercut-sweep/pre-[M030](../milestones/M030/index.md)` branch
(see `papercut-sweep-pre-M030.md`). All fixes are localized to
`scripts/wiki/` plus regression fixtures under `tests/m032-acceptance/`.

## Bugs in scope (B1–B4)

### B1 — `extra:*` stub generator skips `index.md` emission

**Location:** `scripts/wiki/wiki-generate-stubs.sh:464-475`.
**Symptom:** `wiki-generate-nav.sh:448` emits
`Overview: <XDN>/index.md` for every declared `wiki.extra_dirs` entry,
but the stub generator's `extra:*` case-arm only writes per-chunk stubs
and `continue`s out before reaching the `register_child` machinery
(line 484+ in the post-write registration block, and the post-loop
`write_section_index_for` emitter at line 750+). Result: every extra-dir
section's Overview link 404s and `mkdocs build --strict` fails.
Hand-authored `index.md` workarounds get wiped by the stale-file pruner
on next regen.

**Fix:** After `write_stub` at line 472, add
`register_child "${_xdn}" "${_xbase}.md" "$TITLE"`. The existing
`write_section_index_for` emitter (line 723) handles the index emission;
`section_title_for` falls back to `basename` for unknown sections, which
is usable, and B4's label-override extends it cleanly.

**Regression fixture:** `tests/m032-acceptance/p0X-pbj-b1-extra-dir-index.sh`
— synthetic config with `extra_dirs: [foo/]`, run stubs, assert
`wiki/docs/foo/index.md` exists and is non-empty.

### B2 — Legacy-nav migration leaks duplicate `nav:` key

**Location:** `scripts/wiki/wiki-generate-nav.sh:838-850`
(`extract_between_markers`), called from branch 3b at line 860.

**Symptom:** When a project upgrades from the M012-P01 baseline (`# >>>
M012-P01 nav` markers) to the FR-14/MIT-005 region split (auto-nav +
custom-nav), the migration extracts content between legacy markers
verbatim. The M012-P01 baseline emitted a literal `nav:` header line
inside those markers; the migration dumps it into the custom-nav region
as-is. Result: post-migration `mkdocs.yml` has two top-level `nav:` YAML
keys; YAML last-key-wins means custom-nav silently overrides the
freshly-regenerated auto-nav. mkdocs builds without error but operator-
visible regen looks broken.

**Fix:** Strip top-level `nav:` lines (and bare comment lines containing
the M012-P01 marker text) when extracting. The custom-nav region's
contract is "list items merged into auto-nav" — it must not redeclare
`nav:`.

**Regression fixture:** `tests/m032-acceptance/p0X-pbj-b2-legacy-nav-leak.sh`
— synthetic mkdocs.yml with M012-P01-shaped legacy block containing
`nav:`, run nav generator, assert exactly one `^nav:` line in result.

### B3 — `extra_dir` basename collides with `top:*` scanner record URL

**Symptom:** Adding `decisions/` to `wiki.extra_dirs` projects to
`wiki/docs/decisions/<chunk>.md`. The scanner separately emits
`top:decisions` → `wiki/docs/decisions.md` for [`.orchestrator/DECISIONS.md`](../decisions.md).
With `use_directory_urls: true` (mkdocs default), both URLs resolve to
`/decisions/`. mkdocs picks the directory's `index.md` and the
consolidated DECISIONS log becomes unreachable.

**Fix:** Detect collision in `wiki-scan-sources.sh` after parsing
`extra_dirs`, against the hardcoded set of top-level scanner basenames
(`constitution`, `decisions`, `knowledge`, `milestone-summary`,
`project`, plus the structural `milestones`, `archive`, `proposals`,
`specs`). Fail loud with a diagnostic naming both records and the
URL collision. Operators can rename the extra_dir or drop the offending
config.

**Regression fixture:** `tests/m032-acceptance/p0X-pbj-b3-top-extra-collision.sh`
— synthetic config with `extra_dirs: [decisions/]`, expect non-zero
exit + diagnostic on stderr.

### B4 — `extra_dirs` label-override config

**Location:** `scripts/wiki/wiki-generate-nav.sh:444-446` (Title-Case
projection); also `wiki-generate-stubs.sh:section_title_for`.

**Symptom:** Default label projection is `${first-letter-uppercase}${rest}`
of the dirname-record. For `decisions/` → "Decisions"; for
`knowledge/reference/cms-rule/` → "Knowledge-reference-cms-rule".
Readable but ugly; doesn't carry domain meaning.

**Fix:** Extend `wiki.extra_dirs` config schema to accept either bare
strings (current shape) or maps:

```yaml
wiki:
  extra_dirs:
    - knowledge/reference/cms-rule/        # bare-string form (legacy)
    - path: knowledge/reference/training/   # map form (new)
      label: "Reference — Training"
```

Scanner emits an additional `extra-label:<dirname-record>|<label>` record
when a map form is parsed; nav generator and stubs `section_title_for`
both consult this record before falling back to the Title-Case default.

No regression fixture needed (config/UX surface; visual inspection +
existing scanner battery covers shape).

## Out of scope (deferred)

### B5 — Cross-link rewrite warnings (deferred, separate brief)

Pre-existing across every consumer project. Hypothesis from PBJ report:
include-markdown's `rewrite-relative-urls=true` doesn't handle
`../../.orchestrator/...` upward-traversal patterns that orchestrator
authors naturally write. Three candidate fixes (sibling-file projection,
absolute repo-root paths in canonical docs, sed-pass post-projection)
all require validation before patching. PBJ report explicitly says
"validate before patching." Captured at
[`.orchestrator/proposals/m032-cross-link-rewrite-warnings.md`](../proposals/m032-cross-link-rewrite-warnings.md) (separate
brief authored alongside this sweep).

### B6 — Tier 1 extraction skipped SimplePBJ DOCX (M030/[M036](../milestones/M036/index.md) lineage)

50+ SimplePBJ training-material chunks in pbj-central's M036 corpus
have only metadata `.md` (frontmatter + body=`|`); no `.text.md` Tier 1
sibling. Real CMS audit-letter DOCX chunks in the same dir DO have
`.text.md` siblings. Some structural pattern in SimplePBJ DOCX files
(embedded media, tables, complex styles) likely defeats the deterministic
Tier 1 extractor. Belongs to `extract-reference.sh` lineage, not wiki
domain. Tracked at [`.orchestrator/proposals/m036-tier-1-docx-extraction-gap.md`](../proposals/m036-tier-1-docx-extraction-gap.md)
for M030/M036 follow-up. **Not blocking [M035](../milestones/M035/index.md) launch.**

## Verification plan

1. New `tests/m032-acceptance/p0X-pbj-b1-*.sh`, `p0X-pbj-b2-*.sh`,
   `p0X-pbj-b3-*.sh` regression fixtures — each PASS standalone.
2. Add the three to `tests/m032-acceptance/run-acceptance-battery.sh`.
3. Re-run `tests/m032-acceptance/run-acceptance-battery.sh` — `pass=N+3
   fail=0` with prior skip preserved.
4. Re-run `bash tools/verify/validate-milestone.sh M032` — expect
   122/122 PASS unchanged (this sweep doesn't touch M032 closure
   invariants).
5. Smoke-test `bash scripts/wiki/wiki-generate-stubs.sh && bash
   scripts/wiki/wiki-generate-nav.sh` against the orchestrator's own
   config (no extra_dirs declared) — confirm zero behavior change in
   the no-config-extras path.

## Return prompt to PBJ-central agent

After commit, write a prompt the consumer-side agent reads:
1. Which fixes landed (B1-B4 by ID, this commit-sha).
2. `orchestrator:update` to refresh tooling.
3. Re-run order: `bash scripts/wiki/wiki-generate-stubs.sh` →
   `bash scripts/wiki/wiki-generate-nav.sh` → restart `mkdocs serve`.
4. Manual workarounds to remove (`git rm
   wiki/docs/knowledge-reference-*/index.md` if B1 fix renders them
   unnecessary).
5. B4 config addition for nicer labels.
6. B5 + B6 explicitly out of scope, tracking briefs at
   [`.orchestrator/proposals/m032-cross-link-rewrite-warnings.md`](../proposals/m032-cross-link-rewrite-warnings.md) and
   [`.orchestrator/proposals/m036-tier-1-docx-extraction-gap.md`](../proposals/m036-tier-1-docx-extraction-gap.md).
