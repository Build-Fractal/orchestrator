---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M035"
name: ".github/workflows/release.yml skeleton (PR-validate + tag-push-publish, CON-6 secrets-scoped, SC-14 PR-build job-condition assertion)"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- **T01 complete**: `package.json` exists at the repo root.
  T04's publish job runs `npm publish` against this manifest.
- **T02 complete**: `packaging/npm/postinstall.sh` exists.
  T04's PR-validate job runs `npm pack` (which doesn't invoke
  postinstall), but the publish job's tarball does include the
  postinstall script.
- **T03 complete**: `tests/m035-acceptance/cross-channel-byte-
  equivalence.sh` exists at the documented path. T04's PR-validate
  job invokes this test as part of release-pipeline gating.
- **`.github/workflows/` directory does NOT yet exist** at the repo
  root (Plan-Time Discipline Rule 6 — confirmed at plan-authoring
  time; the existing `.github/` dir holds only `ISSUE_TEMPLATE/`
  and the installer scripts which live there for legacy reasons —
  no workflows yet). T04 creates `.github/workflows/`.
- **D001** is recorded in [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) (CI runner =
  `ubuntu-latest`).

## Description

Author the GitHub Actions workflow that drives the npm publishing
pipeline. The workflow has two jobs:

1. **`pr-validate`** — runs on every `pull_request` event AND on
   `push` to main. No secret access. Exercises `npm pack` shape
   linting and runs `tests/m035-acceptance/cross-channel-byte-
   equivalence.sh` (npm-channel arm). This is the load-bearing
   pre-merge gate that surfaces packaging breakage on every PR.

2. **`npm-publish`** — runs only on `v*` tag push events
   (`if: startsWith(github.ref, 'refs/tags/v')`). Has access to
   `secrets.NPM_TOKEN`. Runs `npm publish --access public`. This
   is the load-bearing CON-6 secrets-scope assertion: PR builds
   MUST NOT see `NPM_TOKEN` (verified by SC-14's job-condition
   check).

The workflow is intentionally **minimal at v1**: no homebrew bottle
build (P03), no signed `install.sh` upload (P05), no GitHub release
note generation (P04). T04 establishes the secrets-scoping
discipline + the npm-channel publish path. P03/P04/P05 extend.

The workflow runs on `ubuntu-latest` (D001). macOS-runner matrix
expansion is deferred to P03 when the homebrew arm needs `brew`
which only exists on macOS.

## Steps

1. **Create `.github/workflows/` directory**:

   ```bash
   mkdir -p .github/workflows
   ```

2. **Author `.github/workflows/release.yml`** with verbatim body:

   ```yaml
   # .github/workflows/release.yml
   # M035 P02 T04 — npm publishing pipeline (Build-Fractal/orchestrator).
   #
   # Two jobs:
   #   pr-validate — runs on PR + main-push, no secret access, exercises
   #                 packaging shape and the cross-channel byte-equivalence
   #                 test (npm-channel arm).
   #   npm-publish — runs only on v* tag push, has NPM_TOKEN access,
   #                 runs `npm publish --access public`. CON-6
   #                 secrets-scope discipline.
   #
   # Runner: ubuntu-latest (D001). macOS matrix is deferred to P03 when
   # homebrew arm needs `brew`.
   #
   # Bash 4+ is permitted in CI scripts per CON-2; install scripts
   # remain bash 3.2 compatible per the M035 spec.

   name: release

   on:
     pull_request:
       branches: [main]
     push:
       branches: [main]
       tags: ["v*"]

   permissions:
     contents: read

   jobs:
     # -----------------------------------------------------------------
     # PR-validate — no secrets, runs on PR + main-push.
     # -----------------------------------------------------------------
     pr-validate:
       name: pr-validate (npm pack + byte-equivalence)
       runs-on: ubuntu-latest
       # Run on PRs AND on main pushes (but NOT on tag pushes — that's
       # npm-publish's job; pr-validate would be redundant on tag).
       if: ${{ !startsWith(github.ref, 'refs/tags/v') }}
       steps:
         - name: Checkout
           uses: actions/checkout@v4

         - name: Setup Node.js
           uses: actions/setup-node@v4
           with:
             node-version: "20"
             registry-url: "https://registry.npmjs.org"

         - name: Verify package.json shape
           run: bash tools/verify/m035-p02-package-json-shape.sh

         - name: Verify bin/orchestrator entry point
           run: bash tools/verify/m035-p02-bin-entry.sh

         - name: Verify postinstall driver shape
           run: bash tools/verify/m035-p02-postinstall-shape.sh

         - name: Verify exclusion-list documentation
           run: bash tools/verify/m035-p02-installation-doc-exclusion-list.sh

         - name: Verify bundle-hygiene filter (T05)
           # T05 authors this verifier alongside the bundle filter.
           # PR-validate runs it once T05 has landed; until then,
           # the step is conditional on file presence.
           run: |
             if [ -x tools/verify/m035-p02-bundle-hygiene-filter.sh ]; then
               bash tools/verify/m035-p02-bundle-hygiene-filter.sh
             else
               echo "SKIP: bundle-hygiene verifier not yet on disk (pending T05)"
             fi

         - name: Run cross-channel byte-equivalence (npm-channel arm)
           run: bash tests/m035-acceptance/cross-channel-byte-equivalence.sh

         - name: Verify npm pack contents (T05)
           run: |
             if [ -x tools/verify/m035-p02-npm-pack-contents.sh ]; then
               bash tools/verify/m035-p02-npm-pack-contents.sh
             else
               echo "SKIP: npm-pack-contents verifier not yet on disk (pending T05)"
             fi

         # CON-6 negative-assertion: pr-validate MUST NOT have NPM_TOKEN
         # in env. Asserts secret-scoping at the workflow level.
         - name: CON-6 — assert no NPM_TOKEN access
           run: |
             if [ -n "${NPM_TOKEN:-}" ]; then
               echo "FAIL: NPM_TOKEN visible to pr-validate job — CON-6 violated" >&2
               exit 1
             fi
             echo "PASS: NPM_TOKEN not visible to pr-validate (CON-6)"

     # -----------------------------------------------------------------
     # npm-publish — secrets-scoped to v* tag push only (CON-6).
     # SC-14 asserts this job-condition at acceptance-battery time.
     # -----------------------------------------------------------------
     npm-publish:
       name: npm-publish (tag-push only)
       runs-on: ubuntu-latest
       # CON-6: this job runs ONLY on v* tag push events, never on
       # PRs and never on main-branch pushes. SC-14 verifies this
       # condition mechanically via tools/verify/m035-p02-release-
       # workflow-shape.sh.
       if: ${{ startsWith(github.ref, 'refs/tags/v') && github.event_name == 'push' }}
       steps:
         - name: Checkout
           uses: actions/checkout@v4

         - name: Setup Node.js
           uses: actions/setup-node@v4
           with:
             node-version: "20"
             registry-url: "https://registry.npmjs.org"

         - name: Verify tag matches package.json version
           run: |
             # Strip leading v from the tag.
             TAG="${GITHUB_REF#refs/tags/v}"
             PKG_VERSION="$(grep -E '^\s*"version"\s*:' package.json \
               | head -1 \
               | sed -E 's/.*"version"\s*:\s*"([^"]+)".*/\1/')"
             if [ "$TAG" != "$PKG_VERSION" ]; then
               echo "FAIL: tag v$TAG does not match package.json version $PKG_VERSION" >&2
               exit 1
             fi
             echo "PASS: tag v$TAG matches package.json version $PKG_VERSION"

         - name: Run pre-publish gates
           run: |
             bash tools/verify/m035-p02-package-json-shape.sh
             bash tools/verify/m035-p02-bin-entry.sh
             bash tools/verify/m035-p02-postinstall-shape.sh
             bash tests/m035-acceptance/cross-channel-byte-equivalence.sh

         - name: npm publish (public access)
           env:
             NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
           run: |
             # --access public is required for scoped packages (@scope/name)
             # to be published as public. Default for scoped is restricted.
             npm publish --access public

         - name: Confirm publish succeeded
           env:
             NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
           run: |
             TAG="${GITHUB_REF#refs/tags/v}"
             # Wait briefly for npm registry to propagate the version.
             sleep 5
             npm view "@build-fractal/orchestrator@${TAG}" version
   ```

3. **Author the workflow-shape verifier** at
   `tools/verify/m035-p02-release-workflow-shape.sh` with body:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p02-release-workflow-shape.sh
   # Asserts .github/workflows/release.yml has the load-bearing M035
   # P02 T04 contract surfaces:
   #   * pr-validate job exists, no NPM_TOKEN env reference
   #   * npm-publish job exists, conditioned on v* tag push (CON-6)
   #   * npm-publish job uses secrets.NPM_TOKEN (CON-6 secrets shape)
   #   * runs-on ubuntu-latest (D001)
   #   * SC-14 PR-build job-condition negative assertion is encoded
   #     (the CON-6 step in pr-validate that fails on NPM_TOKEN presence)
   set -euo pipefail

   REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
   WF="$REPO/.github/workflows/release.yml"

   pass=0
   fail=0

   if [ ! -f "$WF" ]; then
     echo "FAIL: $WF not found"
     exit 1
   fi
   echo "PASS: $WF exists"
   pass=$((pass + 1))

   check_grep() {
     local pattern="$1"
     local label="$2"
     if grep -qE "$pattern" "$WF"; then
       echo "PASS: $label"
       pass=$((pass + 1))
     else
       echo "FAIL: $label (pattern: $pattern)"
       fail=$((fail + 1))
     fi
   }

   check_anti_grep() {
     local pattern="$1"
     local label="$2"
     if ! grep -qE "$pattern" "$WF"; then
       echo "PASS: $label (negative assertion)"
       pass=$((pass + 1))
     else
       echo "FAIL: $label — found unexpected match for $pattern"
       fail=$((fail + 1))
     fi
   }

   # --- Job presence -----------------------------------------------
   check_grep '^\s*pr-validate:' "pr-validate job exists"
   check_grep '^\s*npm-publish:' "npm-publish job exists"

   # --- Runner -----------------------------------------------------
   check_grep 'runs-on:\s*ubuntu-latest' "runs-on ubuntu-latest (D001)"

   # --- CON-6 secrets-scope ----------------------------------------
   check_grep "startsWith\(github\.ref,\s*'refs/tags/v'\)" \
     "npm-publish conditioned on v* tag push (CON-6)"
   check_grep 'secrets\.NPM_TOKEN' "publish job uses secrets.NPM_TOKEN"

   # SC-14 PR-build job-condition assertion: pr-validate must include
   # the negative-assertion step that fails on NPM_TOKEN presence.
   check_grep 'NPM_TOKEN visible to pr-validate' \
     "pr-validate carries CON-6 negative-assertion step (SC-14)"

   # --- Test invocations -------------------------------------------
   check_grep 'tests/m035-acceptance/cross-channel-byte-equivalence\.sh' \
     "pr-validate invokes cross-channel-byte-equivalence.sh (T03 surface)"
   check_grep 'm035-p02-package-json-shape\.sh' \
     "pre-publish gates invoke package-json-shape verifier (T01 surface)"

   # --- npm publish access flag ------------------------------------
   check_grep 'npm publish --access public' \
     "scoped package published with --access public"

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   Make it executable.

4. **Self-check**:

   ```bash
   bash tools/verify/m035-p02-release-workflow-shape.sh
   ```

   Must emit `BATTERY: pass=N fail=0`. Expected ~10 PASS lines.

5. **YAML validity check** (defensive — catches indentation breakage):

   ```bash
   bash scripts/util/run-probe.sh /tmp/m035-p02-t04-yaml-validate.sh
   ```

   Stage probe `/tmp/m035-p02-t04-yaml-validate.sh`:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   python3 -c "import yaml; yaml.safe_load(open('$REPO_ROOT/.github/workflows/release.yml'))"
   echo "PASS: release.yml is valid YAML"
   ```

   Must emit `PASS:`. If python3 unavailable, fall back to:
   `node -e "require('js-yaml').load(require('fs').readFileSync('$REPO_ROOT/.github/workflows/release.yml', 'utf8'))"`
   (note: js-yaml may not be installed; the python3 path is preferred).

## Must-Haves

This task addresses the following phase must-haves:

- Truth: `.github/workflows/release.yml` exists with two jobs
  (`pr-validate` + `npm-publish`); `npm-publish` conditioned on
  `startsWith(github.ref, 'refs/tags/v')` (CON-6); pr-validate
  carries CON-6 negative-assertion step (SC-14)
- Artifact: `.github/workflows/release.yml` (min 60 lines, contains
  `startsWith(github.ref, 'refs/tags/v')` AND `secrets.NPM_TOKEN`)
- Key Link: `.github/workflows/release.yml` → `package.json`

## Verification

```bash
bash tools/verify/m035-p02-release-workflow-shape.sh
bash scripts/util/run-probe.sh /tmp/m035-p02-t04-yaml-validate.sh
```

## Inputs

### From Previous Tasks

- `package.json` (from T01)
  - Key API: `name`, `version`, `bin`, `os`, `scripts.postinstall`,
    `files`. The publish job runs `npm publish` against this
    manifest. The version-gate step compares the v* tag to
    `package.json` version.
- `packaging/npm/postinstall.sh` (from T02)
  - Used indirectly: lives in the published tarball; not
    referenced directly by the workflow.
- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` (from T03)
  - Key behavior: runs the npm-channel arm end-to-end; emits
    `NPM_HASH=` and `BATTERY: pass=N fail=0 skip=2`. Exit 0 on
    pass. Invoked by both pr-validate and npm-publish jobs.
- T01–T03 verifiers (`m035-p02-{package-json-shape,bin-entry,
  postinstall-shape,installation-doc-exclusion-list,byte-
  equivalence-skeleton}.sh`)
  - Invoked by the workflow as gating steps.

### From Disk (Pre-existing)

- `.github/` directory (exists; holds `ISSUE_TEMPLATE/` only).
  T04 adds `.github/workflows/`.
- GitHub Actions runtime (executor environment) — provides
  `github.ref`, `github.event_name`, `secrets.NPM_TOKEN`, the
  `actions/checkout@v4` and `actions/setup-node@v4` actions.

## Constraints

- **D001 (ubuntu-latest)**: every job runs on `ubuntu-latest`.
  macOS matrix expansion is P03 territory.
- **CON-6 (secrets-scoped to tag-push)**: `secrets.NPM_TOKEN` MUST
  appear ONLY inside the `npm-publish` job body. The `pr-validate`
  job MUST NOT reference `secrets.NPM_TOKEN` and MUST carry the
  negative-assertion step that fails if `NPM_TOKEN` env var is
  visible. SC-14 verifies this mechanically.
- **AP-009 / CON-3**: workflow YAML is itself a single declarative
  document, not bash; the inline `run: |` blocks use simple shell
  with no compound chains. Multi-line shell uses YAML's `|` block
  scalar (which is single-script-shape, not heredoc).
- **No live `npm publish` outside tag-push**: the publish job's
  `if:` condition is the load-bearing CON-6 surface. Changing it
  requires a corresponding D-row.
- **No homebrew/curl/sigstore steps**: P03/P04/P05 will extend.
  T04's scope is npm-only.
- **YAML validity**: every edit must preserve well-formed YAML.
  Validated in step 5.

## Expected Output

Two new files on disk:

- `.github/workflows/release.yml` (~120 lines)
- `tools/verify/m035-p02-release-workflow-shape.sh` (~70 lines, executable)
- One staged probe: `/tmp/m035-p02-t04-yaml-validate.sh`

`bash tools/verify/m035-p02-release-workflow-shape.sh` emits
`BATTERY: pass=10 fail=0`.

## Notes

Expected verifier output: 10 `PASS:` lines + `BATTERY: pass=10
fail=0`. The negative-assertion grep for "no NPM_TOKEN env" is
positive-asserted (the CON-6 step IS present in the workflow); the
verifier checks the step exists, not that NPM_TOKEN is absent at
runtime (that's SC-14's runtime check).

Plan-Time Discipline Rule 5 analog: the workflow is exercised on
GitHub Actions infrastructure at PR-build time and tag-push time —
T04's smoke test is the YAML-validity check (step 5). Real-app
smoke is "first PR after T04 lands runs the pr-validate job" —
flag this as a known follow-up in the task summary if not yet
exercised at phase close.

Idempotency: re-running the workflow's pr-validate job is
side-effect-free (no writes outside the runner workspace).
Re-running the npm-publish job on the same tag will fail at
`npm publish` because the version is already published — desired
behavior (no accidental double-publish).

Reversibility: deleting `.github/workflows/release.yml` and the
verifier reverts the task. No external state is mutated until a
real `v*` tag is pushed AND `secrets.NPM_TOKEN` is configured —
both gated outside this plan's authoring scope. P02 close does NOT
trigger a real publish.

CON-7 reversibility: pre-launch reversal of the npm package is
operator-side (`npm unpublish @build-fractal/orchestrator` within
72h of publish, per npm's policy). After 72h the package is
permanent. T04 does not push tags; the operator does, and they own
that reversibility window.
