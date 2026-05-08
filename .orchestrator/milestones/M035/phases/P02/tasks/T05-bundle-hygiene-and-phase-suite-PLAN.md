---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P02"
milestone: "M035"
name: "Bundle-hygiene pre-publish filter (#Q-9 absorption) + npm pack contents verifier + phase-suite aggregator"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- **T01–T04 complete**: `package.json`, `bin/orchestrator`,
  `packaging/npm/postinstall.sh`, `tests/m035-acceptance/cross-
  channel-byte-equivalence.sh`, `.github/workflows/release.yml`,
  and the four task-grain verifiers all exist on disk. T05's
  phase-suite aggregator runs all four prior verifiers in sequence.
- **`packaging/bundle/build-bundle.sh` exists** (M032 surface).
  T05 modifies it by inserting the pre-publish filter. The
  existing modes (default + `--check`) are preserved.
- **`packaging/bundle/manifest.yml` exists** (M032 surface). T05
  appends a comment-block documenting the filter convention.
- **Bundle-hygiene proposal at `.orchestrator/proposals/m035-bundle-
  hygiene-pre-publish-filter.md`** documents the design (read for
  context; do not modify).

## Description

Implement the bundle-hygiene pre-publish filter (#Q-9 absorption)
and ship the phase-suite aggregator that closes P02.

The filter has two rules (per the bundle-hygiene proposal):

1. **Pattern exclusion**: any file under `scripts/verify/`,
   `tools/verify/`, or `templates/conversus-presets/` whose
   basename matches glob `m[0-9]*-p[0-9]*-*` is excluded from the
   bundle. This is the bulk rule — kills 791 milestone-internal
   verifiers in one pass.

2. **Magic-comment opt-out**: any file with a `# bundle: dogfood-
   only` header line (within the first 10 lines) OR a `bundle:
   dogfood-only` frontmatter key (in YAML/MD frontmatter) is
   excluded. Self-documenting; catches the long-tail.

The filter applies to **bundle assembly** (`build-bundle.sh`) AND
to **npm publish content** (verified post-pack by the
`m035-p02-npm-pack-contents.sh` verifier T05 also authors). The
two surfaces enforce the same contract from different angles:
build-bundle.sh prevents dogfood content from being staged into
the install bundle; the npm-pack verifier asserts the staged
tarball doesn't include dogfood content.

T05 also authors:

- `tools/verify/m035-p02-bundle-hygiene-filter.sh` — verifies
  `build-bundle.sh` carries the filter logic.
- `tools/verify/m035-p02-npm-pack-contents.sh` — runs `npm pack`
  and asserts the resulting tarball excludes dogfood content.
- `tools/verify/m035-p02-phase-suite.sh` — phase-suite aggregator
  that runs every M035 P02 verifier in sequence and emits
  `BATTERY: pass=N fail=N`.

## Steps

1. **Read the existing `packaging/bundle/build-bundle.sh`** to
   identify the file-copy / file-staging step where the filter
   should be inserted. The current behavior is whole-directory
   `cp -R` (or equivalent loop). Locate the function or block
   that copies files from source dirs into the bundle staging
   area. Without modifying the file yet, identify:

   - The variable holding the source directory list (e.g.
     `SRC_DIRS`, `BUNDLE_SRCS`).
   - The file-iteration loop or `cp -R` call.

2. **Modify `packaging/bundle/build-bundle.sh`** to add the
   pre-publish filter. Insert a `should_exclude_from_bundle()`
   function and integrate it into the file-copy loop. The
   function (verbatim):

   ```bash
   # M035 P02 T05 — Bundle-hygiene pre-publish filter (#Q-9 absorption).
   # Two rules (per .orchestrator/proposals/m035-bundle-hygiene-pre-
   # publish-filter.md):
   #   1. Pattern exclusion: files matching m[0-9]*-p[0-9]*-* under
   #      scripts/verify/, tools/verify/, templates/conversus-presets/.
   #   2. Magic-comment opt-out: # bundle: dogfood-only header line
   #      (within first 10 lines) OR bundle: dogfood-only frontmatter key.
   should_exclude_from_bundle() {
     local file="$1"
     local rel="${file#$REPO_ROOT/}"
     local base
     base="$(basename "$file")"

     # Rule 1: pattern exclusion under specific directories.
     case "$rel" in
       scripts/verify/m[0-9]*-p[0-9]*-*|\
       tools/verify/m[0-9]*-p[0-9]*-*|\
       templates/conversus-presets/m[0-9]*-p[0-9]*-*)
         return 0  # excluded
         ;;
     esac

     # Also handle non-prefixed paths if file is referenced relative
     # to a source dir (fallback for bash 3.2 case-glob nuances).
     case "$base" in
       m[0-9]*-p[0-9]*-*)
         case "$rel" in
           scripts/verify/*|tools/verify/*|templates/conversus-presets/*)
             return 0
             ;;
         esac
         ;;
     esac

     # Rule 2: magic-comment opt-out (header line or YAML frontmatter).
     if [ -f "$file" ]; then
       if head -10 "$file" 2>/dev/null | grep -qE '^[[:space:]]*#?[[:space:]]*bundle:[[:space:]]*dogfood-only' ; then
         return 0  # excluded
       fi
     fi

     return 1  # not excluded
   }
   ```

   Then integrate into the file-copy loop. The integration shape
   depends on the current loop structure; the canonical pattern
   is:

   ```bash
   # Before file-copy:
   if should_exclude_from_bundle "$src_file"; then
     [ "${VERBOSE:-0}" = "1" ] && echo "excluded=$src_file" >&2
     continue
   fi
   # ... existing copy logic ...
   ```

   If `build-bundle.sh` uses `cp -R` over whole directories
   (current shape per the proposal), the integration must
   convert the `cp -R` to a `find ... | while read` loop applying
   the filter, OR run a post-copy filter pass that removes
   excluded files from the staged dir. The post-copy approach is
   simpler for bash 3.2; use it unless the existing build-bundle.sh
   already iterates files individually.

   Post-copy approach (simpler, recommended):

   ```bash
   # After whole-directory copy completes:
   apply_bundle_hygiene_filter() {
     local stage_dir="$1"
     # Pattern exclusion under three subdirs.
     for subdir in scripts/verify tools/verify templates/conversus-presets; do
       [ -d "$stage_dir/$subdir" ] || continue
       find "$stage_dir/$subdir" -type f -name 'm[0-9]*-p[0-9]*-*' \
         -exec rm -f {} +
     done
     # Magic-comment exclusion: scan all staged files (limited to
     # bundle-relevant dirs to keep it fast).
     find "$stage_dir/scripts" "$stage_dir/templates" "$stage_dir/references" \
          "$stage_dir/commands" \
          -type f \( -name '*.sh' -o -name '*.md' -o -name '*.yml' \
                     -o -name '*.yaml' \) 2>/dev/null \
       | while IFS= read -r f; do
           if head -10 "$f" 2>/dev/null \
                | grep -qE '^[[:space:]]*#?[[:space:]]*bundle:[[:space:]]*dogfood-only'; then
             rm -f "$f"
             [ "${VERBOSE:-0}" = "1" ] && echo "excluded=$f" >&2
           fi
         done
   }
   ```

   Invoke `apply_bundle_hygiene_filter "$STAGE_DIR"` after the
   whole-directory copy step and before any subsequent
   `--check`-mode verification.

3. **Append a comment-block to `packaging/bundle/manifest.yml`**
   documenting the filter convention. Find a stable insertion
   point near the top (after the `schema_version` line). Insert
   verbatim:

   ```yaml
   # ─── Bundle hygiene contract (M035 P02 T05) ──────────────────────
   # Pre-publish filter rules (build-bundle.sh apply_bundle_hygiene_filter):
   #   1. Pattern exclusion: files matching basename glob
   #      `m[0-9]*-p[0-9]*-*` under any of:
   #        scripts/verify/
   #        tools/verify/
   #        templates/conversus-presets/
   #      are excluded from the staged bundle. This kills the bulk
   #      milestone-internal verifier corpus in one rule.
   #   2. Magic-comment opt-out: any file whose first 10 lines
   #      contain a header line matching:
   #        `^\s*#?\s*bundle:\s*dogfood-only`
   #      is excluded. Self-documenting; tag dogfood-only artifacts
   #      explicitly when authoring.
   # Verified by tools/verify/m035-p02-bundle-hygiene-filter.sh and
   # tools/verify/m035-p02-npm-pack-contents.sh. See proposal at
   # .orchestrator/proposals/m035-bundle-hygiene-pre-publish-filter.md.
   ```

4. **Author the bundle-hygiene-filter verifier** at
   `tools/verify/m035-p02-bundle-hygiene-filter.sh` with body:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p02-bundle-hygiene-filter.sh
   # Asserts packaging/bundle/build-bundle.sh carries the M035 P02 T05
   # pre-publish filter logic (#Q-9 absorption).
   set -euo pipefail

   REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
   BUNDLE_SH="$REPO/packaging/bundle/build-bundle.sh"
   MANIFEST="$REPO/packaging/bundle/manifest.yml"

   pass=0
   fail=0

   for f in "$BUNDLE_SH" "$MANIFEST"; do
     if [ ! -f "$f" ]; then
       echo "FAIL: $f not found"
       fail=$((fail + 1))
     else
       echo "PASS: $f exists"
       pass=$((pass + 1))
     fi
   done

   check_grep() {
     local file="$1" pattern="$2" label="$3"
     if grep -qE "$pattern" "$file"; then
       echo "PASS: $label"
       pass=$((pass + 1))
     else
       echo "FAIL: $label (file=$file pattern=$pattern)"
       fail=$((fail + 1))
     fi
   }

   # build-bundle.sh contract surfaces:
   check_grep "$BUNDLE_SH" 'm\[0-9\]\*-p\[0-9\]\*-\*' \
     "build-bundle.sh carries pattern-exclusion glob (rule 1)"
   check_grep "$BUNDLE_SH" 'bundle:[[:space:]]*dogfood-only' \
     "build-bundle.sh carries magic-comment exclusion (rule 2)"
   check_grep "$BUNDLE_SH" 'apply_bundle_hygiene_filter|should_exclude_from_bundle' \
     "build-bundle.sh defines a hygiene filter function"
   check_grep "$BUNDLE_SH" 'scripts/verify' \
     "build-bundle.sh names scripts/verify in pattern exclusion"
   check_grep "$BUNDLE_SH" 'tools/verify' \
     "build-bundle.sh names tools/verify in pattern exclusion"
   check_grep "$BUNDLE_SH" 'templates/conversus-presets' \
     "build-bundle.sh names templates/conversus-presets in pattern exclusion"

   # manifest.yml contract surface:
   check_grep "$MANIFEST" 'Bundle hygiene contract' \
     "manifest.yml documents bundle-hygiene contract block"
   check_grep "$MANIFEST" 'm035-p02-bundle-hygiene-filter\.sh' \
     "manifest.yml references the verifier"

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   Make it executable.

5. **Author the npm-pack-contents verifier** at
   `tools/verify/m035-p02-npm-pack-contents.sh`. This runs `npm
   pack`, extracts the resulting tarball, and asserts the
   contents:

   - INCLUDE: `bin/orchestrator`, `package.json`,
     `packaging/install/install-claude-code.sh`,
     `packaging/npm/postinstall.sh`, `commands/`, `scripts/` (with
     dogfood content excluded), `templates/`, `references/`.
   - EXCLUDE: `m[0-9]*-p[0-9]*-*` files under `scripts/verify/`
     and `tools/verify/`, `.orchestrator/`, `specs/`, `tests/`,
     `tools/`, `docs/`, `wiki/`, `node_modules/`, `.git/`,
     `.github/`, `.planning/`.

   Body:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p02-npm-pack-contents.sh
   # Runs `npm pack` and asserts the staged tarball contents conform
   # to the M035 P02 T05 bundle-hygiene contract.
   set -euo pipefail

   REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"

   if ! command -v npm >/dev/null 2>&1; then
     echo "SKIP: npm not on PATH — npm-pack-contents check deferred to CI"
     echo "BATTERY: pass=0 fail=0 skip=1"
     exit 0
   fi

   FIXTURE="$(mktemp -d 2>/dev/null || mktemp -d -t m035p02t05)"
   trap 'rm -rf "$FIXTURE" 2>/dev/null || true' EXIT

   ( cd "$REPO" && npm pack --pack-destination "$FIXTURE" \
       >"$FIXTURE/pack.log" 2>&1 ) || {
     echo "FAIL: npm pack failed (see $FIXTURE/pack.log)"
     exit 1
   }

   TARBALL="$(find "$FIXTURE" -name 'build-fractal-orchestrator-*.tgz' \
     -type f | head -1)"
   if [ -z "$TARBALL" ]; then
     echo "FAIL: npm pack produced no matching tarball"
     exit 1
   fi

   # Extract tarball into a probe dir for content listing.
   PROBE="$FIXTURE/extracted"
   mkdir -p "$PROBE"
   tar -xzf "$TARBALL" -C "$PROBE"
   # npm tarballs extract to a `package/` root.
   PKG_ROOT="$PROBE/package"
   if [ ! -d "$PKG_ROOT" ]; then
     echo "FAIL: tarball lacks expected package/ root"
     exit 1
   fi

   pass=0
   fail=0

   check_present() {
     local rel="$1"
     if [ -e "$PKG_ROOT/$rel" ]; then
       echo "PASS: tarball INCLUDES $rel"
       pass=$((pass + 1))
     else
       echo "FAIL: tarball MISSING $rel"
       fail=$((fail + 1))
     fi
   }

   check_absent() {
     local rel="$1"
     if [ ! -e "$PKG_ROOT/$rel" ]; then
       echo "PASS: tarball EXCLUDES $rel"
       pass=$((pass + 1))
     else
       echo "FAIL: tarball UNEXPECTEDLY INCLUDES $rel"
       fail=$((fail + 1))
     fi
   }

   # Required-present surfaces:
   check_present "package.json"
   check_present "bin/orchestrator"
   check_present "packaging/install/install-claude-code.sh"
   check_present "packaging/npm/postinstall.sh"
   check_present "commands"
   check_present "scripts"
   check_present "templates"
   check_present "references"

   # Required-absent surfaces (whole-dir exclusion via files: whitelist):
   check_absent ".orchestrator"
   check_absent "specs"
   check_absent "tests"
   check_absent "tools"
   check_absent "docs"
   check_absent "wiki"
   check_absent ".git"
   check_absent ".github"
   check_absent ".planning"
   check_absent "node_modules"

   # Bundle-hygiene rule 1: no m[0-9]*-p[0-9]*-* files under
   # scripts/verify/ or tools/verify/ inside the tarball.
   if [ -d "$PKG_ROOT/scripts/verify" ]; then
     COUNT=$(find "$PKG_ROOT/scripts/verify" -type f -name 'm[0-9]*-p[0-9]*-*' 2>/dev/null | wc -l | tr -d ' ')
     if [ "$COUNT" = "0" ]; then
       echo "PASS: tarball scripts/verify/ has no m[0-9]*-p[0-9]*-* dogfood verifiers"
       pass=$((pass + 1))
     else
       echo "FAIL: tarball scripts/verify/ contains $COUNT dogfood verifiers"
       fail=$((fail + 1))
     fi
   fi

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   Make it executable.

6. **Author the phase-suite aggregator** at
   `tools/verify/m035-p02-phase-suite.sh`. This runs every M035 P02
   verifier in sequence and emits a BATTERY summary line. Body:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p02-phase-suite.sh
   # M035 P02 phase-suite aggregator. Runs every per-task verifier
   # in sequence and emits BATTERY: pass=N fail=N.
   #
   # Mirrors the M030/M032/M029/M037/M035-P01.5 phase-suite
   # convention so consolidate-time grep aggregation is consistent
   # across milestone batteries.
   set -u

   REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
   cd "$REPO"

   VERIFIERS=(
     "tools/verify/m035-p02-package-json-shape.sh"
     "tools/verify/m035-p02-bin-entry.sh"
     "tools/verify/m035-p02-postinstall-shape.sh"
     "tools/verify/m035-p02-installation-doc-exclusion-list.sh"
     "tools/verify/m035-p02-byte-equivalence-skeleton.sh"
     "tools/verify/m035-p02-release-workflow-shape.sh"
     "tools/verify/m035-p02-bundle-hygiene-filter.sh"
     "tools/verify/m035-p02-npm-pack-contents.sh"
   )

   pass=0
   fail=0

   for v in "${VERIFIERS[@]}"; do
     if [ ! -x "$v" ]; then
       echo "FAIL: $v missing or not executable"
       fail=$((fail + 1))
       continue
     fi
     if bash "$v" >/dev/null 2>"$REPO/.m035-p02-phase-suite-$$.err"; then
       echo "PASS: $v"
       pass=$((pass + 1))
     else
       echo "FAIL: $v (stderr below)"
       cat "$REPO/.m035-p02-phase-suite-$$.err" >&2 || true
       fail=$((fail + 1))
     fi
   done
   rm -f "$REPO/.m035-p02-phase-suite-$$.err" 2>/dev/null || true

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   Make it executable.

7. **Self-check the phase-suite**:

   ```bash
   bash tools/verify/m035-p02-phase-suite.sh
   ```

   Must emit `BATTERY: pass=8 fail=0`. If any verifier fails, fix
   the underlying artifact (do not weaken the verifier). The
   phase-suite is the load-bearing P02-close gate.

8. **Sanity-check `build-bundle.sh` still runs**:

   ```bash
   bash scripts/util/run-probe.sh /tmp/m035-p02-t05-build-bundle-smoke.sh
   ```

   Stage probe `/tmp/m035-p02-t05-build-bundle-smoke.sh`:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   cd "$REPO_ROOT"
   bash packaging/bundle/build-bundle.sh --check 2>&1 | tail -20
   echo "PASS: build-bundle.sh --check ran without error"
   ```

   Must exit 0 with `PASS:`. The `--check` mode validates the
   bundle without actually rebuilding; if T05's filter integration
   broke something, this surfaces it.

## Must-Haves

This task addresses the following phase must-haves:

- Truth: `packaging/bundle/build-bundle.sh` honors a pre-publish
  filter (pattern exclusion + magic-comment) — #Q-9 absorption
- Truth: `npm pack` produces a tarball that includes `bin/`,
  `packaging/install/`, `commands/`, etc. AND excludes `.orchestrator/`,
  `specs/`, `tests/`, `tools/`, `docs/`, dogfood-only `m[0-9]*-p[0-9]*-*`
  verifiers
- Truth: `tools/verify/m035-p02-phase-suite.sh` exists and runs
  every per-task verifier emitting `BATTERY: pass=N fail=0`
- Artifact: `packaging/bundle/build-bundle.sh` (modified — contains
  `bundle: dogfood-only` AND `m[0-9]*-p[0-9]*-*`)
- Artifact: `tools/verify/m035-p02-phase-suite.sh` (min 30 lines,
  contains `BATTERY:`)
- Key Link: `packaging/bundle/build-bundle.sh` → `packaging/bundle/manifest.yml`

## Verification

```bash
bash tools/verify/m035-p02-bundle-hygiene-filter.sh
bash tools/verify/m035-p02-npm-pack-contents.sh
bash tools/verify/m035-p02-phase-suite.sh
bash scripts/util/run-probe.sh /tmp/m035-p02-t05-build-bundle-smoke.sh
```

## Inputs

### From Previous Tasks

- `package.json` (from T01)
  - Key API: `files` whitelist controls npm tarball inclusion at
    the directory level. T05's npm-pack-contents verifier checks
    that the resulting tarball respects this whitelist.
- `bin/orchestrator` (from T01) — must be present in tarball.
- `packaging/npm/postinstall.sh` (from T02) — must be present in
  tarball.
- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` (from
  T03) — already covered by T03 verifier; phase-suite re-runs.
- `.github/workflows/release.yml` (from T04) — already covered
  by T04 verifier; phase-suite re-runs.
- T01–T04 task-grain verifiers (`m035-p02-{package-json-shape,bin-
  entry,postinstall-shape,installation-doc-exclusion-list,byte-
  equivalence-skeleton,release-workflow-shape}.sh`) — invoked by
  the phase-suite aggregator.

### From Disk (Pre-existing)

- `packaging/bundle/build-bundle.sh` — M032 surface; T05 modifies
  it. Existing `--check` mode and default-mode behavior preserved.
- `packaging/bundle/manifest.yml` — M032 surface; T05 appends a
  comment block.
- `.orchestrator/proposals/m035-bundle-hygiene-pre-publish-filter.md`
  — design reference (read-only).
- `npm` on PATH (executor environment requirement for the
  npm-pack-contents verifier; SKIP path is acceptable in
  non-CI environments).

## Constraints

- **AP-009 / CON-3**: every verifier and the integrated filter
  function use single-script-shape. The build-bundle.sh integration
  uses a `find ... -exec` pattern (single command) plus a `find ...
  | while read` pipeline (which is permitted because the inner
  body is a single grep+rm, not a compound chain).
- **#Q-9 fold-in scope**: T05 ships **rules** (pattern exclusion +
  magic-comment) and the **verifiers**. T05 does NOT do the
  proposed audit pass to retroactively tag every existing dogfood
  artifact with `# bundle: dogfood-only` headers — that's a
  separate operator follow-up captured in the phase summary's
  "deferred audit" section if it surfaces. The pattern rule alone
  catches the bulk (791 verifiers).
- **Plan-Time Discipline Rule 6 (path-collision check)**: T05's
  three new verifier paths and the phase-suite path were checked
  at plan-authoring time and confirmed absent. The phase-suite
  filename `m035-p02-phase-suite.sh` follows the milestone-prefixed
  naming convention (CLAUDE.md "Naming convention — milestone slug
  REQUIRED for per-phase verifiers").
- **CON-7 (M025 reversibility)**: bundle-hygiene filter applies to
  bundle ASSEMBLY, not to installed-bundle uninstall. The M025
  manifest schema and reversibility-gate are unchanged.
- **No retroactive dogfood tagging**: T05 does not edit any
  existing file to add `# bundle: dogfood-only` headers. Future
  authors add the tag when authoring new dogfood-only artifacts.
- **`build-bundle.sh --check` must keep passing**: T05's
  integration must NOT break the existing `--check` mode (existing
  test surface). Step 8 verifies.

## Expected Output

Three new files + two modified files:

- `tools/verify/m035-p02-bundle-hygiene-filter.sh` (~50 lines, executable)
- `tools/verify/m035-p02-npm-pack-contents.sh` (~80 lines, executable)
- `tools/verify/m035-p02-phase-suite.sh` (~50 lines, executable)
- `packaging/bundle/build-bundle.sh` (modified — adds
  `apply_bundle_hygiene_filter` function ~25 lines + integration
  call)
- `packaging/bundle/manifest.yml` (modified — bundle-hygiene
  contract comment block ~15 lines added)
- One staged probe: `/tmp/m035-p02-t05-build-bundle-smoke.sh`

`bash tools/verify/m035-p02-phase-suite.sh` emits `BATTERY: pass=8
fail=0` (8 task-grain verifiers all green). This is the load-
bearing P02 phase-close gate.

## Notes

Expected verifier output: phase-suite emits 8 `PASS:` lines (one
per task-grain verifier) + `BATTERY: pass=8 fail=0`.

Plan-Time Discipline Rule 5 analog (real-bundle verification): the
npm-pack-contents verifier runs actual `npm pack` against the
modified bundle. This IS the real-bundle smoke test. There is no
mock-only equivalent; if the filter logic is wrong, the tarball
contents are wrong, and the verifier fails.

Idempotency: re-running the phase-suite is side-effect-free.
Re-running the npm-pack-contents verifier produces a fresh tarball
each invocation in `mktemp -d`. The build-bundle.sh modification
is text-edit-idempotent (re-running step 2 with the same diff is
a no-op).

Reversibility: deleting the three new verifiers and reverting the
two modified files unwinds the task. The bundle-hygiene filter is
added at one point in build-bundle.sh; reverting that single
function definition + invocation restores M032's behavior.

Bundle-hygiene proposal Q1/Q2/Q3/Q4 disposition (per
`.orchestrator/proposals/m035-bundle-hygiene-pre-publish-filter.md`):

- **Q1 (magic-comment scope)**: applies to the four bundle-relevant
  dirs (commands/ scripts/ templates/ references/). Encoded in
  step 2's `find` invocation.
- **Q2 (wiki/ filtering)**: NOT in T05 scope; wiki/ is M032's
  surface and was not flagged in the proposal as needing filtering.
  T05 does not add wiki/ to the filter pass. Future audit can.
- **Q3 (tools/verify/ in project_assets)**: confirmed NOT in
  manifest.yml `project_assets:` (T05 step 1 reading confirmed).
  But tools/verify/ IS in the `package.json files:` whitelist as a
  side effect of being a top-level dir — wait, no: `package.json
  files:` does NOT list `tools/`. The whole-dir exclusion in T01's
  `files:` array handles tools/. The pattern-exclusion rule still
  applies to tools/verify/ as a defense-in-depth measure for any
  other distribution channel that includes tools/ (homebrew may).
- **Q4 (filter on every build vs release-only)**: T05 runs filter
  on every build. Cheap, no drift accumulation between releases.
  Encoded by integrating into build-bundle.sh's default mode.
