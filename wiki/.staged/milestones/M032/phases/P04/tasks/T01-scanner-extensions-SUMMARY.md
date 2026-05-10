---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P04"
milestone: "M032"
provides:
  - "FR-17 proposals:<basename> scanner enumeration with [stage] badge derivation from frontmatter (stub|brief|specified|active|closed|unknown fallback per US-7 AS-1) gated on --include-proposals/--no-include-proposals (default-on per FR-15 precedent); FR-18 extra:<dirname> scanner enumeration data-driven from <ROOT>/.orchestrator/config.yml wiki.extra_dirs: list (inline + block YAML forms parsed via shell awk no jq/python3 dep per MEM001) with empty-config zero-record contract; FR-19 knowledge-flat scanner enumeration of .orchestrator/knowledge/*.md flat files (-maxdepth 1 keeps subdirs out of scope); nav-generator amendments adding Proposals section (after Milestone Summary before Milestones) + per-extra_dirs Title-Case sections + Knowledge — Flat section all inside # >>> auto-nav region byte-preserving # >>> custom-nav region per FR-14; stub-generator case-arms for proposals:* (-> wiki/docs/proposals/<basename>.md) + knowledge-flat (-> wiki/docs/knowledge/<basename>.md) + extra:* (-> wiki/docs/<dn>/<basename>.md); SC-8 acceptance script tests/m032-acceptance/p0X-scanner-extensions.sh exercising FR-17 against orchestrator + FR-18-present against fixture + FR-18-absent against fixture + FR-19 against fixture (9/9 PASS); three project-owned verifiers tools/verify/m032-p04-scanner-extensions.sh (16/16 PASS) + tools/verify/m032-p04-nav-extensions.sh (13/13 PASS) + tools/verify/m032-p04-acceptance-shape-sc8.sh (14/14 PASS)"
requires:
  - "P02,P03"
affects:
  - "P04/T02,P04/T03,P04/T05,M033,M036b"
key_files:
  - "scripts/wiki/wiki-scan-sources.sh,scripts/wiki/wiki-generate-nav.sh,scripts/wiki/wiki-generate-stubs.sh,tests/m032-acceptance/p0X-scanner-extensions.sh,tools/verify/m032-p04-scanner-extensions.sh,tools/verify/m032-p04-nav-extensions.sh,tools/verify/m032-p04-acceptance-shape-sc8.sh"
key_decisions:
  - "FR-17,FR-18,FR-19,FR-14,FR-15,SC-8,US-7-AS-1,AD-19,MEM001,MEM013"
patterns_established:
  - "strict-additive scanner amendment (zero modification to existing top:*/milestone:*/archive:*/knowledge:* emissions; new families add new category prefixes only); default-on opt-out flag pattern --include-proposals/--no-include-proposals/--include-proposals=false mirrors FR-15 --include-glossary precedent established in P02; data-driven config-walked enumeration (FR-18 reads .orchestrator/config.yml wiki.extra_dirs: YAML list; empty/absent produces zero records — no false-positive section); pure-shell YAML parser dispatching inline-list and block-list forms via awk state machines (no jq/python3 hard dep per MEM001); -maxdepth 1 boundary discipline for FR-19 flat-knowledge enumeration (subdirs reference/patterns/conventions/lessons explicitly out of scope); top-level scanner record + nav-generator HAS_* flag + stub-generator case-arm trio extended from P02/T03 to three new families simultaneously (Proposals + extra-dirs + Knowledge — Flat); per-extra-dir accumulator file pattern as bash 3.2 substitute for declare -A (TMP_EXTRA_DNS /tmp accumulator with awk de-dup preserving first-seen order); side-effect-free verifier via backup-and-trap-restore (cp wiki/mkdocs.yml to TMP/mkdocs.yml.bak before regenerate; restore in trap EXIT INT TERM) — pattern from P02/T03 m032-p02-glossary-scanner-and-nav.sh extended to FR-17/18/19 surface; bundle-equivalent script-staging in test fixtures (cp scripts/wiki/* into FIXTURE/scripts/wiki/ so navgen which path-binds $ROOT/scripts/wiki/wiki-scan-sources.sh runs hermetically against fixture-only data); awk YAML frontmatter scanner with single-quote-double-quote-stripping for stage value extraction (handles --- delimited frontmatter and bare unquoted values); RESULT envelope (RESULT: SC-8 pass=N fail=M) instead of SUMMARY envelope to match plan-time sketch shape"
drill_down_paths:
  - ".orchestrator/milestones/M032/phases/P04/tasks/T01-scanner-extensions-PLAN.md,.orchestrator/milestones/M032/phases/P04/tasks/T01-scanner-extensions-PAYLOAD.md"
duration: "120m"
verification_result: "pass"
completed_at: "2026-05-05T04:02:25Z"
---

## What Shipped

T01 lands the additive scanner enumerations (FR-17 + FR-18 + FR-19) on
`scripts/wiki/wiki-scan-sources.sh`, the nav-generator counterparts on
`scripts/wiki/wiki-generate-nav.sh`, the stub-generator routing on
`scripts/wiki/wiki-generate-stubs.sh`, the SC-8 acceptance script, and the
three project-owned verifiers under `tools/verify/m032-p04-*`. All six
production-side amendments + verifier scripts ship as a single atomic unit:
the scanner emits new records, the nav generator surfaces them as nav
sections, and the stub generator routes their stubs to the correct
`wiki/docs/<path>.md` slots — splitting the trio across tasks would create
a window where the scanner emits records the nav generator silently drops.

### Surfaces shipped

1. **Scanner amendments (`scripts/wiki/wiki-scan-sources.sh`)**:
   - `--include-proposals` flag (default-on per FR-15 precedent;
     opt-out via `--no-include-proposals` or `--include-proposals=false`)
   - `proposals:<basename>` records for `.orchestrator/proposals/*.md`
     (excluding `README.md` via existing `should_exclude()`; title field
     is `<H1> [stage]` with stage derived from YAML frontmatter; missing
     frontmatter renders `[unknown]` per US-7 AS-1)
   - `extra:<dirname>` records when `<ROOT>/.orchestrator/config.yml`
     declares `wiki.extra_dirs:` (inline form `[a, b]` and block form
     `- a\n - b` both parsed via awk state machines; path separators
     replaced with `-` in dirname per spec; `find -type f -name '*.md'`
     under each declared dir, `LC_ALL=C sort`)
   - `knowledge-flat` records for `.orchestrator/knowledge/*.md` flat
     files (`-maxdepth 1` boundary keeps subdirs `reference/`,
     `patterns/`, `conventions/`, `lessons/` out of scope)

2. **Nav-generator amendments (`scripts/wiki/wiki-generate-nav.sh`)**:
   - `HAS_PROPOSALS` discovery flag + `Proposals` section emitted after
     Milestone Summary, before Milestones, inside `# >>> auto-nav` region
   - Per-extra-dir `HAS_EXTRA_<dn>` accumulator (`/tmp/wiki-nav-extra-dns-$$.list`
     as bash 3.2 substitute for `declare -A`) + Title-Case section labels
     per declared dir (declaration order preserved via awk de-dup)
   - `HAS_KNOWLEDGE_FLAT` discovery flag + `Knowledge — Flat` section
     suppressed when zero records (no empty-header pollution)
   - `# >>> custom-nav` region byte-preserved per FR-14 (verified
     end-to-end via sentinel-injection round-trip in nav-extensions
     verifier)

3. **Stub-generator amendments (`scripts/wiki/wiki-generate-stubs.sh`)**:
   - `proposals:*` case-arm routes `proposals/<basename>.md` stubs;
     canonical via `build_canonical()` (`.orchestrator/`-prefixed)
   - `knowledge-flat` case-arm routes `knowledge/<basename>.md` stubs;
     canonical via `build_canonical()`
   - `extra:*` case-arm routes `<dn>/<basename>.md` stubs; canonical
     via `build_canonical_repo_rel()` (canonical lives at repo root,
     not under `.orchestrator/`)

4. **SC-8 acceptance** (`tests/m032-acceptance/p0X-scanner-extensions.sh`):
   nine assertion groups across orchestrator + temp fixture (FR-17 against
   orchestrator + opt-out, FR-18-present against fixture-with-config,
   FR-18-absent against fixture-without-config, FR-19 against fixture
   with flat knowledge file, FR-17 fixture with `stage: brief` frontmatter
   asserts `[brief]` badge surfaces). Trap-EXIT cleanup pattern.

5. **Three project-owned verifiers** under `tools/verify/m032-p04-*`:
   - `m032-p04-scanner-extensions.sh` (16/16 PASS) — flag plumbing,
     additivity invariants for top:*/milestone:*/knowledge:* emissions,
     orchestrator-tree FR-17 surface, fixture FR-18+FR-19 surface,
     fixture-no-config FR-18-absent contract.
   - `m032-p04-nav-extensions.sh` (13/13 PASS) — orchestrator
     regenerate (Proposals section landing, custom-nav preservation,
     Knowledge — Flat suppression at zero records), fixture regenerate
     (Proposals + Specs Title-Case section + Knowledge — Flat all under
     auto-nav), custom-nav byte-preservation across regenerate via
     sentinel injection, stub-generator case-arm shape inspection.
     Side-effect-free against orchestrator working tree
     (backup-and-trap-restore pattern from P02/T03 extended).
   - `m032-p04-acceptance-shape-sc8.sh` (14/14 PASS) — SC-8 token
     surface (SC-8/FR-17/FR-18/FR-19/proposals:/extra:/knowledge-flat
     /no-include-proposals/wiki.extra_dirs/[brief]), trap-EXIT shape,
     FR-18-absent fixture coverage, RESULT envelope.

## Verification Results

- `bash tools/verify/m032-p04-scanner-extensions.sh` → **16/16 PASS**
- `bash tools/verify/m032-p04-nav-extensions.sh` → **13/13 PASS**
- `bash tools/verify/m032-p04-acceptance-shape-sc8.sh` → **14/14 PASS**
- `bash tests/m032-acceptance/p0X-scanner-extensions.sh` →
  **RESULT: SC-8 pass=9 fail=0**
- Sibling-phase regression: P02 phase-suite **12/12 PASS** unchanged;
  P03 phase-suite **10/10 PASS** unchanged.

## Key Decisions

- **FR-17 (proposals enumeration)**: default-on `--include-proposals`
  flag follows the FR-15 `--include-glossary` precedent rather than
  default-off, so the orchestrator's 24 in-tree proposals automatically
  surface in any project's wiki regenerate without operator action.
  US-7 AS-1 fallback (`[unknown]` when `stage:` missing) avoids
  exclusion-by-omission.
- **FR-18 (data-driven extra_dirs)**: no flag — purely consumer-driven
  via `<ROOT>/.orchestrator/config.yml` `wiki.extra_dirs:`. The
  empty/absent-config contract (zero records, no false-positive
  section) avoids the [M013](../../../../../milestones/M013/index.md) path-B failure mode (always-emit produces
  empty sections in repos that don't use the surface).
- **FR-19 (`-maxdepth 1` boundary)**: the FR-19 contract is FLAT files
  only — the existing `knowledge:patterns|conventions|lessons` family
  already covers categorized knowledge. Pinning `-maxdepth 1` prevents
  the new family from double-counting MEM entries or scanning the
  M036a `reference/` subtree.
- **Strict additivity**: scanner before/after diff against orchestrator
  tree shows ONLY new `proposals:*` records added (zero `extra:*` /
  `knowledge-flat` because the orchestrator has no `wiki.extra_dirs:`
  config and no flat knowledge files). Existing emissions byte-identical.

## Patterns Established

- **Strict-additive scanner amendment**: amendments add new category
  prefixes; existing emissions remain byte-identical. Verified by
  before/after diff in the verifier (additivity invariants for
  top:constitution, top:glossary, knowledge:patterns).
- **Default-on opt-out flag pattern** (`--include-proposals` /
  `--no-include-proposals` / `--include-proposals=false`): mirrors
  FR-15 `--include-glossary` precedent; replicable for any future
  default-on family extension.
- **Data-driven config-walked enumeration**: FR-18 reads
  `.orchestrator/config.yml` `wiki.extra_dirs:` YAML list; empty/absent
  produces zero records — no false-positive section. Inline-list and
  block-list YAML forms both supported via awk state machines (no
  jq/python3 hard dep per MEM001).
- **`-maxdepth 1` boundary discipline** for flat-only enumeration
  family: prevents the FR-19 surface from invading sibling subdirs
  (`reference/`, M036a-territory) that other families already own.
- **Top-level scanner record + nav-generator HAS_* flag +
  stub-generator case-arm trio** extended from P02/T03 to three new
  families simultaneously (Proposals + extra-dirs + Knowledge — Flat).
  Replicable for future top-level wiki source families.
- **Per-extra-dir accumulator file pattern** as bash 3.2 substitute
  for `declare -A`: `/tmp/wiki-nav-extra-dns-$$.list` with awk de-dup
  preserving first-seen order. Mirrors the P02/T03 `_klist`
  per-category list pattern.
- **Side-effect-free verifier via backup-and-trap-restore**: backup
  `wiki/mkdocs.yml` to `TMP/mkdocs.yml.bak` before regenerate; restore
  in trap `EXIT INT TERM`. Pattern from P02/T03
  `m032-p02-glossary-scanner-and-nav.sh` extended.
- **Bundle-equivalent script-staging in test fixtures**: `cp
  scripts/wiki/wiki-{scan-sources,generate-nav,generate-stubs}.sh`
  into `$FIXTURE/scripts/wiki/` so the nav generator (which
  path-binds `$ROOT/scripts/wiki/wiki-scan-sources.sh`) runs
  hermetically against fixture-only data. Mirrors what
  `packaging/install/install-claude-code.sh` does at install time.
- **awk YAML frontmatter scanner** with single-quote +
  double-quote stripping for `stage:` value extraction. Handles
  `---`-delimited frontmatter, bare unquoted values, single-quoted,
  and double-quoted variants in one pass.
- **`RESULT:` envelope** (`RESULT: SC-8 pass=N fail=M`) instead of
  `SUMMARY:` envelope per the plan-time sketch shape — distinguishes
  acceptance scripts from verifier scripts at a glance in CI logs.

## Affects Downstream

- **P04/T02 (`--with-wiki` no-op + FR-20 build-time decorator)** —
  T02 picks up the same nav-generator + stub-generator surface for
  any decorator-emit additions; T01's stub-generator case-arms are
  the integration points if a decorator emits new top-level wiki
  sources.
- **P04/T03 (SC-11 doctor-no-warnings + self-application)** — the
  SC-11 acceptance must run against an orchestrator-local mkdocs
  build that includes the new Proposals section; T01's
  self-application path is what T03 verifies.
- **P04/T05 (phase-suite + scope-guard)** — the `m032-p04-phase-suite.sh`
  aggregator chains all four T01 verifiers (scanner-extensions +
  nav-extensions + acceptance-shape-sc8 + the SC-8 acceptance script
  itself); the `m032-p04-scope-guard.sh` allowlist must include the
  six T01-touched paths.
- **[M033](../../../../../milestones/M033/index.md) (project onboarding experience)** — projects starting from
  `orchestrator:start --with-wiki` will see Proposals section
  populated automatically when the project's `.orchestrator/proposals/`
  has any entries; the FR-18 `wiki.extra_dirs:` opens the door for
  M033 to recommend `specs/` and `decisions/` as opt-in extra dirs.
- **M036b (post-launch wiki projection)** — the FR-17 stage-badge
  derivation provides the seed for an operator-facing
  REVIEW-queue / change-over-time / supersede-chain UX in the wiki
  layer.
