---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01.5"
milestone: "M035"
name: "D-RN-1..D-RN-7 decision block + pre-rename tag + legacy-namespace allowlist file"
depends_on: []
---

## Prerequisites

Files that MUST exist on disk at task entry (verified at plan-authoring
time, 2026-05-08):

- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) — exists; uses
  `### <Title> { #dr-code-NNN }` heading shape (decisions-shape-lint
  enforces, landed M037/P01/T04). Latest existing anchor is `#dr-code-NNN`
  (T01 author resolves the next-NNN at execution time by reading the
  file's tail).
- `references/RENAME-PLAN.md` — exists; provides [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }")..[D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }") source
  text in § 2 "Open decisions" and § 5 commit setup (pre-rename tag).
- `tests/m035-acceptance/` — exists (created at M035/P01); subdirectory
  `fixtures/` already on disk.
- `tools/verify/` — exists (M035/P00 + M035/P01 verifiers landed there).
- `git tag --list` works in `$REPO_ROOT` (the repo is a normal git
  checkout).

Pre-existing decisions consumed (from M035 discuss + roadmap):

- [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }") = `@build-fractal/orchestrator` (P00 collision-check confirmed
  available; recorded in P00 SUMMARY).
- [D-RN-2](../../../../../decisions.md#d-rn-2-github-repo-basename-build-fractalorchestrator-dr-code-030 "GitHub repo basename `Build-Fractal/orchestrator` { #dr-code-030 }") = `Build-Fractal/orchestrator` (off-tree).
- [D-RN-3](../../../../../decisions.md#d-rn-3-command-cohort-prefix-orchestratorcmd-dr-code-031 "Command-cohort prefix `orchestrator:<cmd>` { #dr-code-031 }") = `orchestrator:<cmd>` cohort prefix.
- [D-RN-4](../../../../../decisions.md#d-rn-4-homebrew-tap-build-fractalorchestrator-single-formula-dr-code-032 "Homebrew tap `build-fractal/orchestrator` (single-formula) { #dr-code-032 }") = `build-fractal/orchestrator` single-formula tap.
- [D-RN-5](../../../../../decisions.md#d-rn-5-local-clone-path-sitesorchestrator-dr-code-033 "Local clone path `~/Sites/orchestrator` { #dr-code-033 }") = `~/Sites/orchestrator`.
- [D-RN-6](../../../../../decisions.md#d-rn-6-migrate-claude-memory-dir-alongside-path-rename-dr-code-034 "Migrate Claude memory dir alongside path rename { #dr-code-034 }") = migrate Claude memory dir.
- [D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }") = pre-rename tag `v0.9.X-final-spec-kit-name`.

**Off-tree operator pre-condition**: the pre-rename git tag ([D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }"))
SHOULD be authored at this task's execution time via
`git tag v0.9.X-final-spec-kit-name`. The auto-loop dispatch may emit
the tag via a dispatched bash step; if the operator prefers manual
control, this task PAUSEs at step 5 with a documented advisory and
resumes after operator confirmation. The tag is reversible via
`git tag -d v0.9.X-final-spec-kit-name`.

## Description

Author the foundational pieces of P01.5: (a) the `[D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }")..[D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }")`
decision block in [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) so downstream phases
(P02 npm publish, P03 homebrew tap, P05 install-script signing) can
reference the rename decisions by anchor; (b) the pre-rename git tag
`v0.9.X-final-spec-kit-name` so post-rename archaeology has a clean
cutover marker; (c) the legacy-namespace allowlist file
`tests/m035-acceptance/legacy-namespace-allowlist.txt` enumerating the
5 historical/migration files SC-7 must skip.

This task lands NOTHING that touches in-tree prose or paths — those are
T02–T07's territory. T01 is the foundation reference set that T08's
acceptance verifiers consume.

## Steps

1. **Read [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) tail to resolve next NNN**.
   Read the file with `bash scripts/util/read-range.sh
   [.orchestrator/DECISIONS.md](../../../../../decisions.md) -1 -1` (or equivalent shape-guard-safe
   tail wrapper) to find the highest existing `#dr-code-NNN` anchor.
   Resolve `<NEXT_NNN>`, `<NEXT_NNN+1>`, ..., `<NEXT_NNN+6>` as the
   seven new anchors for [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }")..[D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }"). Cross-reference any milestone
   logs to ensure no NNN collision.

2. **Append [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }")..[D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }") decision block to
   [`.orchestrator/DECISIONS.md`](../../../../../decisions.md)**. Each decision gets its own heading
   per the existing dr-code-NNN convention. Body shape (per existing
   convention from `### Order of remaining milestones after [M015](../../../../../milestones/M015/index.md)
   { #dr-code-004 }`):

   ```markdown
   ---

   ### [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }") — npm package name `@build-fractal/orchestrator` { #dr-code-<NEXT_NNN> }

   <span class="md-tag md-tag-icon md-tag--decision">DR-CODE-<NEXT_NNN></span>
   {: .code-chip-row }

   - **When**: M035/P01.5 (pre-rename branch open)
   - **Scope**: rename
   - **Choice**: npm publish target is `@build-fractal/orchestrator`
     (scoped). The unscoped `orchestrator` is taken on npm; collision
     check ran at M035/P00 (recorded in P00 SUMMARY) and confirmed
     `@build-fractal/orchestrator` available. Determines repo basename,
     binary name, and CLI command-cohort prefix downstream ([D-RN-2](../../../../../decisions.md#d-rn-2-github-repo-basename-build-fractalorchestrator-dr-code-030 "GitHub repo basename `Build-Fractal/orchestrator` { #dr-code-030 }") through [D-RN-4](../../../../../decisions.md#d-rn-4-homebrew-tap-build-fractalorchestrator-single-formula-dr-code-032 "Homebrew tap `build-fractal/orchestrator` (single-formula) { #dr-code-032 }")).
   - **Revisable**: No — npm v1 tarball publication in P02 bakes the
     scope forever; revising would mean a deprecated package + forced
     rename.

   Resolved at M035/P00 collision-check; recorded here at P01.5 plan-phase
   per RENAME-PLAN.md § 2.
   ```

   Repeat the shape for [D-RN-2](../../../../../decisions.md#d-rn-2-github-repo-basename-build-fractalorchestrator-dr-code-030 "GitHub repo basename `Build-Fractal/orchestrator` { #dr-code-030 }")..[D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }") (one heading each, anchor
   `#dr-code-<NEXT_NNN+1>` through `#dr-code-<NEXT_NNN+6>`):

   - **[D-RN-2](../../../../../decisions.md#d-rn-2-github-repo-basename-build-fractalorchestrator-dr-code-030 "GitHub repo basename `Build-Fractal/orchestrator` { #dr-code-030 }")** — GitHub repo basename `Build-Fractal/orchestrator`
     (off-tree; GitHub auto-redirect handles legacy URL surface;
     timing: AFTER in-tree rename branch lands, BEFORE merge to main).
   - **[D-RN-3](../../../../../decisions.md#d-rn-3-command-cohort-prefix-orchestratorcmd-dr-code-031 "Command-cohort prefix `orchestrator:<cmd>` { #dr-code-031 }")** — Command-cohort prefix `orchestrator:<cmd>` (already
     canonical in `CLAUDE.md` and `commands/*.md`; T06 finishes the 4
     remaining operational template surfaces; legacy form preserved as
     documented historical reference in 5 allowlisted files).
   - **[D-RN-4](../../../../../decisions.md#d-rn-4-homebrew-tap-build-fractalorchestrator-single-formula-dr-code-032 "Homebrew tap `build-fractal/orchestrator` (single-formula) { #dr-code-032 }")** — Homebrew tap `build-fractal/orchestrator` single-formula
     tap (single-formula simplifies the M035/P03 plan; multi-formula
     deferred until a second tool earns the cost).
   - **[D-RN-5](../../../../../decisions.md#d-rn-5-local-clone-path-sitesorchestrator-dr-code-033 "Local clone path `~/Sites/orchestrator` { #dr-code-033 }")** — Local clone path `~/Sites/orchestrator` (operator
     off-tree filesystem rename; in-tree references rewritten in T03).
   - **[D-RN-6](../../../../../decisions.md#d-rn-6-migrate-claude-memory-dir-alongside-path-rename-dr-code-034 "Migrate Claude memory dir alongside path rename { #dr-code-034 }")** — Migrate Claude memory dir
     `~/.claude/projects/-Users-brettkellgren-Sites-spec-kit-orchestrator/`
     → `…-Sites-orchestrator/` (without migration, Claude memory entries
     become orphaned because Claude's project key is derived from the
     working-dir path).
   - **[D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }")** — Pre-rename version tag `v0.9.X-final-spec-kit-name`
     immediately before the rename branch lands (where `X` is the
     current `CHANGELOG.md` top-line patch number captured at task
     execution time; trivially reversible via `git tag -d`).

3. **Author `tests/m035-acceptance/legacy-namespace-allowlist.txt`**.
   Exactly 5 entries (one per line) per the M035 roadmap Boundary Map:

   ```text
   commands/migrate.md
   docs/migrating-from-speckit.md
   references/RENAME-PLAN.md
   scripts/verify/m015-p03-helpers/changelog-historical-snapshot.txt
   scripts/state/namespace-aliases.sh
   ```

   File is consumed by T08's `m035-p015-sc7.sh` via `grep -v -F -f
   tests/m035-acceptance/legacy-namespace-allowlist.txt`. Future drift
   (a 6th allowlisted file, a removed allowlist entry) MUST be a
   conscious decision — the verifier asserts exactly these 5 paths
   appear (line-equality), not a subset.

4. **Author `tools/verify/m035-p015-allowlist-shape.sh`**. Verifier
   asserts:
   - File `tests/m035-acceptance/legacy-namespace-allowlist.txt` exists.
   - Line count equals 5 (exact).
   - Each of the 5 expected paths appears verbatim (one path per line,
     no duplicates).
   - Each allowlisted path resolves to a file or directory on disk
     (so the allowlist cannot drift away from the actual files it
     names).

   Single-script-file shape per AD-19:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p015-allowlist-shape.sh
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   ALLOWLIST="$REPO_ROOT/tests/m035-acceptance/legacy-namespace-allowlist.txt"
   fail=0
   if [ ! -f "$ALLOWLIST" ]; then
     echo "FAIL: allowlist file missing at $ALLOWLIST" >&2
     exit 1
   fi
   line_count=$(wc -l < "$ALLOWLIST" | tr -d ' ')
   if [ "$line_count" != "5" ]; then
     echo "FAIL: expected exactly 5 allowlist entries, got $line_count" >&2
     fail=1
   fi
   for expected in \
     "commands/migrate.md" \
     "docs/migrating-from-speckit.md" \
     "references/RENAME-PLAN.md" \
     "scripts/verify/m015-p03-helpers/changelog-historical-snapshot.txt" \
     "scripts/state/namespace-aliases.sh"; do
     if ! grep -qxF "$expected" "$ALLOWLIST"; then
       echo "FAIL: allowlist missing required entry $expected" >&2
       fail=1
     fi
     if [ ! -e "$REPO_ROOT/$expected" ]; then
       echo "FAIL: allowlisted path does not exist on disk: $expected" >&2
       fail=1
     fi
   done
   if [ "$fail" -eq 0 ]; then
     echo "PASS: m035-p015-allowlist-shape"
     exit 0
   fi
   exit 1
   ```

5. **Author the pre-rename git tag (operator-executable, reversible)**.
   Read `CHANGELOG.md` top-line via `awk '/^## \[[0-9]/{print; exit}'`
   to extract `<X>` from `## [0.9.<X>]`. Run
   `git tag v0.9.<X>-final-spec-kit-name`. Document reversibility:
   `git tag -d v0.9.<X>-final-spec-kit-name` removes the tag locally;
   `git push --delete origin v0.9.<X>-final-spec-kit-name` removes from
   remote (NOT done by this task — the operator's choice). The auto-loop
   dispatch may execute the `git tag` step; if the operator wants
   manual control, the dispatched agent can PAUSE here with the
   advisory `PAUSE: pre-rename tag — run \`git tag <name>\` then resume`
   surfaced.

6. **Author `tools/verify/m035-p015-pre-rename-tag.sh`**. Verifier
   asserts:
   - `git tag --list 'v0.9.*-final-spec-kit-name'` returns at least one
     match (the verifier does NOT pin the patch number because it can
     drift between task author and execution).
   - The matched tag points to a commit on the current branch
     ancestor chain (the tag is on a real commit, not a dangling ref).

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p015-pre-rename-tag.sh
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   cd "$REPO_ROOT" || exit 1
   tag_match=$(git tag --list 'v0.9.*-final-spec-kit-name' | head -n 1)
   if [ -z "$tag_match" ]; then
     echo "FAIL: pre-rename tag v0.9.*-final-spec-kit-name not found" >&2
     exit 1
   fi
   if ! git rev-parse --verify "$tag_match" >/dev/null 2>&1; then
     echo "FAIL: tag $tag_match does not resolve to a commit" >&2
     exit 1
   fi
   echo "PASS: m035-p015-pre-rename-tag found=$tag_match"
   exit 0
   ```

7. **Author `tools/verify/m035-p015-decisions-block.sh`**. Verifier
   asserts the [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }")..[D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }") block landed in [`.orchestrator/DECISIONS.md`](../../../../../decisions.md):
   - Each of the 7 decision titles is present (greps for the
     `### D-RN-N — ` prefix; one match per N from 1 to 7).
   - Each title has an associated `{ #dr-code-NNN }` anchor (per the
     decisions-shape-lint convention).

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p015-decisions-block.sh
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   DECISIONS="$REPO_ROOT/.orchestrator/DECISIONS.md"
   fail=0
   for n in 1 2 3 4 5 6 7; do
     if ! grep -qE "^### D-RN-${n} — " "$DECISIONS"; then
       echo "FAIL: D-RN-${n} heading missing from DECISIONS.md" >&2
       fail=1
     fi
   done
   anchor_count=$(grep -cE '^### D-RN-[1-7] — .*\{ #dr-code-[0-9]+ \}' "$DECISIONS" || true)
   if [ "$anchor_count" != "7" ]; then
     echo "FAIL: expected 7 D-RN headings with #dr-code anchors, got $anchor_count" >&2
     fail=1
   fi
   if [ "$fail" -eq 0 ]; then echo "PASS: m035-p015-decisions-block"; exit 0; fi
   exit 1
   ```

## Must-Haves

The truths and `Check:` commands satisfied by this task are:

- The legacy-namespace allowlist file enumerates exactly the 5 expected paths
  - Check: `bash tools/verify/m035-p015-allowlist-shape.sh`
- [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }")..[D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }") are recorded in [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) with
  proper `#dr-code-NNN` anchors
  - Check: `bash tools/verify/m035-p015-decisions-block.sh`
- Pre-rename tag `v0.9.X-final-spec-kit-name` exists in local refs
  - Check: `bash tools/verify/m035-p015-pre-rename-tag.sh`

## Verification

```bash
bash tools/verify/m035-p015-allowlist-shape.sh
bash tools/verify/m035-p015-decisions-block.sh
bash tools/verify/m035-p015-pre-rename-tag.sh
```

## Inputs

### From Previous Tasks

(none — this is the foundation task in P01.5)

### From Disk (Pre-existing)

- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) — existing register (extended, not
  replaced; existing entries preserved verbatim).
- `references/RENAME-PLAN.md` — § 2 (Open decisions) is the source text
  the D-RN-N choice fields are derived from.
- `CHANGELOG.md` — top-line `## [X.Y.Z]` heading is the SemVer source
  for resolving `X` in the pre-rename tag.

## Constraints

- **CON-3 (AP-009-shape-guard-honored)**: every verifier uses an
  `if`-block for predicate checks (no inline `&&` chains). The
  `git tag` and `awk` invocations are simple commands.
- **AD-19 (single-script-file Check shape)**: every `Check:` command
  is `bash tools/verify/m035-p015-*.sh` — no compound chains.
- **Decisions-shape-lint contract** (M037/P01/T04): every new D-row
  uses the `### <Title> { #dr-code-NNN }` heading shape with the
  `<span class="md-tag md-tag-icon md-tag--decision">` chip line. The
  T01 author MUST run `bash scripts/verify/decisions-shape-lint.sh`
  after editing DECISIONS.md to confirm no shape regression.
- **Reversibility**: the pre-rename tag is locally reversible
  (`git tag -d`); the DECISIONS.md edits are git-revertable; the
  allowlist file is git-revertable. No off-tree state mutated by this
  task.

## Notes

- Expected verifier output: three `PASS:` lines plus tag identification.
- **Plan-phase verifier-availability cross-check (rule 2)**: this task
  authors all three verifiers in steps 4 / 6 / 7; their availability
  at verification time is satisfied by their authorship in this same task.
- **Plan-phase classifier-shape pre-validation (rule 3)**: every
  `Check:` is a single-script-file invocation — AD-19 compliant.
- **Plan-phase real-DB rule (rule 5)**: not applicable.
- **Decisions-shape-lint follow-up**: after appending the D-RN block,
  run `bash scripts/verify/decisions-shape-lint.sh` from this task's
  verifier shell. If the lint surfaces a shape regression, the D-RN
  block must be revised before the task is marked complete.
- **Operator advisory** for the pre-rename tag step: if the auto-loop
  dispatch does NOT have permission to author git tags in the
  `$REPO_ROOT`, the agent emits
  `PAUSE: [D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }") pre-rename tag — operator runs \`git tag
  v0.9.<X>-final-spec-kit-name\` then resumes`. The tag is reversible.

## Expected Output

After T01 completes:

- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) carries seven new `### D-RN-N — …`
  headings (anchored per dr-code convention) recording [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }")..[D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }").
- `tests/m035-acceptance/legacy-namespace-allowlist.txt` exists with
  exactly 5 lines naming the 5 historical/migration files.
- Pre-rename git tag `v0.9.<X>-final-spec-kit-name` exists in local
  refs and points to a real commit on the current ancestor chain.
- Three new verifier scripts exist under `tools/verify/`.
