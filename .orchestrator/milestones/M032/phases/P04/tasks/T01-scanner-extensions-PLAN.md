---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M032"
name: "FR-17 + FR-18 + FR-19 scanner extensions on wiki-scan-sources.sh + wiki-generate-nav.sh + SC-8 acceptance"
depends_on: []
---

## Prerequisites

- P02 closed (FR-15 `--include-glossary` flag is the precedent T01's
  `--include-proposals` flag follows). Verified by:
  - `[ -f scripts/wiki/wiki-scan-sources.sh ]`
  - `grep -q -- '--include-glossary' scripts/wiki/wiki-scan-sources.sh`
- P03 closed (FR-14 `# >>> auto-nav` / `# >>> custom-nav` region split
  is the structural surface T01's nav-section additions emit inside).
  Verified by:
  - `[ -f scripts/wiki/wiki-generate-nav.sh ]`
  - `grep -q '# >>> auto-nav' scripts/wiki/wiki-generate-nav.sh`
- `.orchestrator/proposals/` directory exists with ≥ 1 `*.md` entry on
  the orchestrator's own repo (current count: 25 entries — verified by
  `ls .orchestrator/proposals/*.md | wc -l` returning a positive
  integer at planning time).

## Description

T01 lands the additive scanner enumerations (FR-17 + FR-18 + FR-19) and
their nav-generator counterparts that surface the proposals tree, the
consumer-configurable `extra_dirs:` paths, and the flat-knowledge files
in the rendered wiki. Three production-side amendments + one acceptance
script + three verifier scripts.

### Scanner amendments (`scripts/wiki/wiki-scan-sources.sh`)

The scanner today emits records under category prefixes `top:*`,
`milestone:M###`, `archive:M###`, and `knowledge:patterns|conventions|lessons`.
T01 adds three new family prefixes:

1. **`proposals:<basename>`** — one record per `.orchestrator/proposals/*.md`
   entry (excluding `README.md` per the existing `should_exclude()`
   check). The rel-path is `proposals/<file>` (under `.orchestrator/`).
   The title field carries the document's first H1 heading (extracted
   via the existing `extract_title()` helper) appended with a `[stage]`
   badge derived from the YAML frontmatter `stage:` field. If the
   frontmatter is absent or the `stage:` field is missing, the badge
   renders as `[unknown]` (no exclusion per US-7 AS-1). The badge values
   are `stub | brief | specified | active | closed | unknown` — the
   first five enumerated by FR-17, the sixth a synthesized fallback.

2. **`extra:<dirname>`** — when `<PROJECT_ROOT>/.orchestrator/config.yml`
   declares a `wiki.extra_dirs:` YAML list (e.g. `wiki: { extra_dirs:
   [specs/, decisions/] }` or block-style equivalent), the scanner walks
   each declared path relative to the project root and emits records.
   The `<dirname>` is the path with the trailing slash stripped and
   path separators replaced with `-` (e.g. `specs/v1/` → `specs-v1`).
   Empty-or-absent `wiki.extra_dirs:` config produces zero `extra:*`
   records (no false-positive section per FR-18). The scanner uses
   pure shell (`grep`/`sed`/`awk` — no jq/python3 hard dependency per
   MEM001), parsing the YAML list either inline-form (`[a, b, c]`) or
   block-form (`- a\n  - b`).

3. **`knowledge-flat`** — `.orchestrator/knowledge/*.md` flat files
   (no category subdir). The rel-path is `knowledge/<file>` (under
   `.orchestrator/`). The existing `knowledge:patterns|conventions|lessons`
   categorized emission is unchanged. Today's orchestrator tree contains
   only a `reference/` subdir at `.orchestrator/knowledge/reference/`
   and zero flat `*.md` files, so the additive surface is a no-op
   against the current orchestrator tree but exercises against fixtures.

The new `--include-proposals` flag follows the FR-15 `--include-glossary`
convention (default-on; opt out via `--no-include-proposals` or
`--include-proposals=false`). FR-18 (`extra_dirs`) is data-driven from
the consumer config — no flag needed. FR-19 (`knowledge-flat`) is
unconditional — it fires whenever flat `*.md` files exist under the
flat path (zero such files today on this repo means zero records emitted,
which is the intended no-op behavior).

### Nav-generator amendments (`scripts/wiki/wiki-generate-nav.sh`)

The nav generator today emits sections inside the `# >>> auto-nav`
region (P03/T03 FR-14 surface). T01 adds three new section emissions
inside `# >>> auto-nav`:

1. **Proposals section** — section label `Proposals` (per #Q-5 resolution
   at clarify); placed after the existing top-level sections and before
   the milestones section. The section index page is a one-line
   introduction-paragraph emitted by the stub generator (T01 also
   amends `scripts/wiki/wiki-generate-stubs.sh` to handle the new
   `proposals:*` category records — wiring a case-arm routing stubs to
   `wiki/docs/proposals/<basename>.md` — per the P02/T03 trio pattern
   "top-level scanner record + nav-generator HAS_* flag + stub-generator
   case-arm"). The introduction paragraph reads (literal, no
   placeholders): `Project proposals at various stages of formalization
   (stub → brief → specified → active → closed). Cross-company
   contributors comment on stage 1–3 entries via Giscus.`. Entries
   sort by `proposals:<basename>` ascending under the section.

2. **Extra-dirs sections** — one nav section per declared `extra_dirs:`
   entry, labeled `Title-Case(<dirname>)` (e.g. `extra:specs` →
   `Specs`). Sections are emitted in declaration order. Empty
   `wiki.extra_dirs:` config produces zero sections (no false-positive).

3. **Knowledge — Flat section** — sibling to the existing
   `Knowledge — Patterns` / `Knowledge — Conventions` /
   `Knowledge — Lessons` sections (these are not modified). Appended
   after the categorized sections. When zero `knowledge-flat` records
   are emitted by the scanner, the section is suppressed (no empty
   header).

All three new sections emit inside `# >>> auto-nav` and the custom-nav
region (`# >>> custom-nav` ... `# <<< custom-nav end`) is byte-preserved
per FR-14 (US-5 AS-1 — verified by SC-6 which P03/T03 already ships).

### `--with-wiki` no-op note

T01 does NOT touch `scripts/lifecycle/wiki-init.sh`. The `--with-wiki`
no-op repair lives in T02 to keep T01's scope focused on scanner +
nav-generator surfaces.

## Steps

1. **Author `scripts/wiki/wiki-scan-sources.sh`** amendments. The
   structural pattern is the existing FR-15 glossary block (lines
   207–209). Add three new emission blocks after the existing
   knowledge categorized emission (around line 260):

   - **Proposals block**: gate on `INCLUDE_PROPOSALS=1` (default 1; flip
     by `--no-include-proposals` / `--include-proposals=false`). For
     each `*.md` under `.orchestrator/proposals/` (excluding `README.md`
     via `should_exclude()`), parse the frontmatter `stage:` field
     (regex `^stage:[[:space:]]*['\"]?\\([a-z]*\\)['\"]?[[:space:]]*$`
     between `^---$` lines), default to `unknown` if missing, and emit
     `proposals:<basename>|proposals/<file>|<title> [stage]`.

   - **Extra-dirs block**: read `<ROOT>/.orchestrator/config.yml` (if
     present) for the `wiki.extra_dirs:` YAML list. Parse inline form
     (`wiki.extra_dirs: [specs/, decisions/]`) and block form
     (`wiki:\n  extra_dirs:\n    - specs/\n    - decisions/`). For each
     declared path, walk it (`find <abs-dir> -type f -name '*.md'` with
     `LC_ALL=C sort`) and emit `extra:<dirname>|<rel>|<title>` records.

   - **Knowledge-flat block**: `find <ROOT>/.orchestrator/knowledge -maxdepth 1
     -type f -name '*.md' | LC_ALL=C sort` (note: `-maxdepth 1` keeps
     this strictly to FLAT files; subdirs like `reference/` and
     `patterns/`/`conventions/`/`lessons/` are out of scope for FR-19).
     Emit `knowledge-flat|knowledge/<file>|<title>` per record.

   Argument parsing: extend the case statement (around line 35) to
   recognize `--include-proposals`, `--include-proposals=true`,
   `--include-proposals=false`, `--no-include-proposals` per the
   FR-15 precedent.

2. **Author `scripts/wiki/wiki-generate-nav.sh`** amendments. The
   generator today reads scanner records via stdin or via direct
   invocation (`$SCAN_SOURCES`); each emit pattern is a function
   keyed on category. Add:

   - **`HAS_PROPOSALS` discovery flag**: set to 1 if any record's
     category prefix matches `^proposals:`.
   - **`HAS_EXTRA_<dirname>` discovery flags** (one per distinct
     `extra:<dirname>` prefix observed).
   - **`HAS_KNOWLEDGE_FLAT` discovery flag**: set to 1 if any record's
     category equals `knowledge-flat`.

   For each flag, emit the corresponding nav section inside the
   `# >>> auto-nav` block. The section emission helpers are the
   existing `emit_leaf` and `emit_section` (or equivalent — match the
   existing function naming convention in the script).

3. **Author `scripts/wiki/wiki-generate-stubs.sh`** amendment to
   handle the new `proposals:*` and `knowledge-flat` categories per
   the P02/T03 stub-generator case-arm pattern. The case statement
   adds:

   ```sh
   proposals:*) STUB_PATH="$ROOT/wiki/docs/proposals/${BASENAME}.md" ;;
   knowledge-flat) STUB_PATH="$ROOT/wiki/docs/knowledge/${BASENAME}.md" ;;
   extra:*) STUB_PATH="$ROOT/wiki/docs/${EXTRA_SECTION}/${BASENAME}.md" ;;
   ```

   (The `EXTRA_SECTION` slot is derived from the `extra:<dirname>`
   prefix.) Stub generation is best-effort — if the script does not
   today have a generic case-arm pattern, T01 may instead write a
   minimal stub block per category; the must-haves verifier confirms
   stub paths are emitted, not exact stub-script line counts.

4. **Author `tests/m032-acceptance/p0X-scanner-extensions.sh`** (SC-8).
   Single-script-file shape per AD-19; bash 3.2 compatible per MEM001.
   The script:

   ```bash
   #!/usr/bin/env bash
   # SC-8 — verifies FR-17 + FR-18 + FR-19 scanner extensions.
   set -uo pipefail
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   FIXTURE="/tmp/m032-p04-sc8-fixture-$$"
   trap 'rm -rf "$FIXTURE"' EXIT INT TERM
   pass=0; fail=0
   say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
   say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }
   # ... four assertion groups: FR-17 against $PROJECT_ROOT,
   # FR-18-present against $FIXTURE with config, FR-18-absent
   # against $FIXTURE without config, FR-19 against $FIXTURE.
   printf 'RESULT: SC-8 pass=%d fail=%d\n' "$pass" "$fail"
   [ "$fail" -eq 0 ]
   ```

   Fixture setup creates `<FIXTURE>/.orchestrator/config.yml` with
   `wiki:\n  extra_dirs:\n    - specs/\n    - decisions/`, plus
   `<FIXTURE>/specs/foo.md` + `<FIXTURE>/decisions/bar.md` +
   `<FIXTURE>/.orchestrator/knowledge/baz.md` flat-knowledge file +
   minimal `<FIXTURE>/.orchestrator/proposals/sample.md` with
   frontmatter `stage: brief`.

5. **Author the three verifier scripts** under `tools/verify/`:

   - `m032-p04-scanner-extensions.sh` — asserts the scanner emits the
     three new category prefixes against orchestrator + fixture.
   - `m032-p04-nav-extensions.sh` — asserts the generator emits the
     `Proposals` + `Knowledge — Flat` + per-`extra_dirs` sections
     inside `# >>> auto-nav` against orchestrator + fixture.
   - `m032-p04-acceptance-shape-sc8.sh` — asserts the SC-8 script
     exists, is executable, contains the FR-17/18/19 token surface
     and the trap-EXIT cleanup pattern (per M032 patterns-established).

6. **Make all new scripts executable**:
   `chmod +x scripts/wiki/wiki-decorate-codes.sh
   tests/m032-acceptance/p0X-scanner-extensions.sh
   tools/verify/m032-p04-scanner-extensions.sh
   tools/verify/m032-p04-nav-extensions.sh
   tools/verify/m032-p04-acceptance-shape-sc8.sh`
   (Note: wiki-decorate-codes.sh is T02's deliverable; the chmod above
   lists T01-only deliverables.)

7. **Run T01 verifiers locally** to confirm green:
   - `bash tools/verify/m032-p04-scanner-extensions.sh`
   - `bash tools/verify/m032-p04-nav-extensions.sh`
   - `bash tools/verify/m032-p04-acceptance-shape-sc8.sh`
   - `bash tests/m032-acceptance/p0X-scanner-extensions.sh`

8. **Run sibling-phase regression check** to confirm P02/P03 verifiers
   remain green:
   - `bash tools/verify/m032-p02-phase-suite.sh`
   - `bash tools/verify/m032-p03-phase-suite.sh`

   Both should remain at their P02/P03 close numbers. If any verifier
   regresses, in-flight repair within T01 per the P03 patterns-established
   convention (verifier-contract drift caused by sibling-phase task
   landings is repaired in the same task that surfaces it).

## Must-Haves

- `scripts/wiki/wiki-scan-sources.sh` emits `proposals:<basename>` records for `.orchestrator/proposals/*.md` with `stage:` badge derivation; emits `extra:<dirname>` records when `wiki.extra_dirs:` config declared; emits `knowledge-flat` records for `.orchestrator/knowledge/*.md` flat files
- `scripts/wiki/wiki-generate-nav.sh` renders `Proposals` + per-`extra_dirs` + `Knowledge — Flat` sections inside the `# >>> auto-nav` region, byte-preserving the `# >>> custom-nav` region per FR-14
- `scripts/wiki/wiki-generate-stubs.sh` (or equivalent stub-routing surface) handles the new categories per the P02/T03 case-arm pattern
- `tests/m032-acceptance/p0X-scanner-extensions.sh` exists and exercises FR-17 + FR-18-present + FR-18-absent + FR-19 against orchestrator + temp-dir fixture with trap-EXIT cleanup
- `tools/verify/m032-p04-scanner-extensions.sh` + `m032-p04-nav-extensions.sh` + `m032-p04-acceptance-shape-sc8.sh` ship green
- P02 + P03 phase-suites remain green post-T01

## Verification

```bash
bash tools/verify/m032-p04-scanner-extensions.sh
```

```bash
bash tools/verify/m032-p04-nav-extensions.sh
```

```bash
bash tools/verify/m032-p04-acceptance-shape-sc8.sh
```

```bash
bash tests/m032-acceptance/p0X-scanner-extensions.sh
```

```bash
bash tools/verify/m032-p02-phase-suite.sh
```

```bash
bash tools/verify/m032-p03-phase-suite.sh
```

## Notes

Expected output: each verifier's final line is `SUMMARY: <name>.sh
pass=N fail=0` (or equivalent `RESULT:` envelope) and exits 0. The
P02/P03 sibling phase-suites should remain at their close-time
green counts (P02: 12/12; P03: 10/10).

Verifier-contract-over-verifier-skeleton latitude: this plan describes
the required behavioral surface. If at execution time the existing
scanner / nav-generator / stub-generator code shape diverges from the
sketch (function names, helper conventions, etc.), the executing agent
SHOULD ship the contract intent — emit the three new category families;
render the three new sections; route stubs for the new categories —
rather than the literal sketch. The patterns-established for this
repair convention are P03/T01 (deferred-stub workflow assertion) and
P03/T03 (manual-empty-then-regenerate self-application). If the
on-disk reality conflicts with this plan's structural assumptions
(e.g., the stub generator's case statement does not exist as sketched),
document the deviation in T01-SUMMARY.md following the M032/P03/T03
precedent.

Bash 3.2 gotchas (per MEM001): no `declare -A` for the proposals/extra
mapping — use parallel scalars or temp-file-per-record patterns. The
`grep -c` under `set -uo pipefail` requires `|| true` fallback per the
P02/T03 patterns-established gotcha.

`should_exclude()` reuse: every new emission family (proposals, extra,
knowledge-flat) participates in the existing exclusion check (no
`*PLANNING-PAYLOAD*`, no `*VERIFICATION*`, no `AGENTS.md`/`README.md`).

Path discipline (AD-19): all verifier scripts under `tools/verify/`
with `m032-p04-*` prefix. The acceptance script under
`tests/m032-acceptance/` with `p0X-` prefix per the spec-text continuity
(the `p0X-` prefix is the spec's portable shape — it does not imply a
specific phase placement).

## Inputs

### From Previous Tasks

(None — T01 has zero upstream task dependencies inside P04.)

### From Disk (Pre-existing)

- `scripts/wiki/wiki-scan-sources.sh` — existing scanner; T01 amends
  additively. Key surface: `emit_record()` helper takes 3 args
  (category, rel-path, abs-path); scope walked via `scan_tree()` for
  M### subdirs and explicit blocks for `top:*` records;
  `should_exclude()` filters out `AGENTS.md`/`README.md`/`*PLANNING-PAYLOAD*`/`*VERIFICATION*`;
  `extract_title()` reads first H1 from a markdown file;
  `--include-glossary` flag established at lines 35–60 follows the
  same default-on opt-out pattern T01's `--include-proposals` follows.
- `scripts/wiki/wiki-generate-nav.sh` — existing generator with
  P03/T03 FR-14 region split. Section emission inside `# >>> auto-nav`;
  `# >>> custom-nav` byte-preserved verbatim. T01 emits new sections
  inside auto-nav region only.
- `scripts/wiki/wiki-generate-stubs.sh` — existing stub generator
  amended in P02/T03 with the `top:glossary` case-arm. T01 extends
  with `proposals:*`, `knowledge-flat`, `extra:*` case-arms per the
  P02/T03 trio pattern.
- `.orchestrator/proposals/` — 25 markdown entries on the orchestrator
  repo; the FR-17 surface enumerates these.
- `.orchestrator/knowledge/` — contains `reference/` subdir only; zero
  flat `*.md` files; FR-19 surface is no-op against today's tree but
  exercises against fixture.
- `tools/verify/fixtures/m032-p03-baseline-ref.txt` — pattern reference
  for the SC-13 / scope-guard baseline-ref shape T05 follows.

## Constraints

- Single-script-file shape for verifier `Check:` commands per AD-19.
- bash 3.2 compatibility (per MEM001) — no `declare -A`, no process
  substitution, no compound-chain-gt2; use parallel scalars or temp
  files for accumulators.
- Verifier scripts MUST live under `tools/verify/` with `m032-p04-*`
  prefix (slug-bearing per AD-19).
- Acceptance scripts MUST live under `tests/m032-acceptance/`.
- Scanner amendments are STRICTLY ADDITIVE — T01 does not modify any
  existing emission or any existing flag's semantics. Existing FR-15
  glossary emission, existing `top:*` / `milestone:*` / `archive:*` /
  `knowledge:*` emissions all remain byte-identical post-T01.
- Nav-generator amendments emit ONLY inside the `# >>> auto-nav`
  region. The `# >>> custom-nav` region is byte-preserved (FR-14
  invariant).
- T01 does NOT touch `scripts/lifecycle/wiki-init.sh` (T02 owns the
  `--with-wiki` no-op repair).
- T01 does NOT touch `wiki/glossary.md`, `wiki/mkdocs.yml`,
  `wiki/overrides/partials/comments.html`, or any P01/P02/P03
  exclusive surface (per the P04 scope-guard denylist T05 ships).

## Expected Output

After T01 completes:

- `scripts/wiki/wiki-scan-sources.sh` emits proposals + extra + flat-
  knowledge records when run against orchestrator + fixture.
- `scripts/wiki/wiki-generate-nav.sh` renders three new sections inside
  auto-nav region.
- `scripts/wiki/wiki-generate-stubs.sh` routes stubs for the new
  category families.
- `tests/m032-acceptance/p0X-scanner-extensions.sh` exits 0 against
  orchestrator + fixture (four assertion groups all green).
- Three new verifier scripts under `tools/verify/m032-p04-*` are
  present, executable, and exit 0.
- P02 + P03 phase-suites remain green at their close numbers.
