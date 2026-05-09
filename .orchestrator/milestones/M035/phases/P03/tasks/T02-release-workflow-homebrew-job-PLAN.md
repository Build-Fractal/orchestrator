---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M035"
name: "Extend .github/workflows/release.yml with homebrew-publish job (CON-6 secret-scoped)"
depends_on: ["T01"]
---

## Prerequisites

- `packaging/homebrew/orchestrator.rb.tmpl` exists (T01).
- `packaging/homebrew/render-formula.sh` exists, executable (T01).
- `.github/workflows/release.yml` exists with `pr-validate` +
  `npm-publish` jobs (P02 T04 + P05 T03 final shape).
- `.orchestrator/DECISIONS.md` contains D007 (T01).

## Description

Append a third job, `homebrew-publish`, to
`.github/workflows/release.yml`. The job runs only on `v*` tag-push
events (CON-6, identical job-condition predicate to `npm-publish`),
runs *after* `npm-publish` (`needs: npm-publish` so the tarball is
on the GitHub release before the formula references it), reads the
SHA-256 from the just-uploaded `SHA256SUMS`, renders the formula via
T01's render script, clones the
`Build-Fractal/homebrew-orchestrator` tap repo using
`secrets.HOMEBREW_TAP_TOKEN`, writes
`Formula/orchestrator.rb`, commits, and pushes.

Also extend the `pr-validate` job with a CON-6 negative-assertion step
(`HOMEBREW_TAP_TOKEN` MUST NOT be visible to PR builds) — same shape
as P02 T04's `NPM_TOKEN` negative assertion.

Append D008 to `.orchestrator/DECISIONS.md`.

## Steps

1. **Read the current `.github/workflows/release.yml`** to confirm the
   `npm-publish` job's exact name + final-step name (the new job's
   `needs:` references `npm-publish` and the agent should sanity-check
   that no breaking-change has shifted the name).

2. **Append the `homebrew-publish` job** under the `jobs:` block, after
   the `npm-publish` job's final `Confirm publish succeeded` step. The
   YAML must be inserted at the correct indentation (2 spaces under
   `jobs:`). Exact YAML content to insert:

   ```yaml
     # -----------------------------------------------------------------
     # homebrew-publish — CON-6: tag-push only, never PR. Runs after
     # npm-publish so the tarball is uploaded to the GitHub release
     # before this job reads its SHA-256. Renders the formula from
     # packaging/homebrew/orchestrator.rb.tmpl, pushes to
     # Build-Fractal/homebrew-orchestrator (D007 + D008).
     # -----------------------------------------------------------------
     homebrew-publish:
       name: homebrew-publish (tag-push only)
       runs-on: ubuntu-latest
       needs: npm-publish
       if: ${{ startsWith(github.ref, 'refs/tags/v') && github.event_name == 'push' }}
       permissions:
         contents: read
       steps:
         - name: Checkout (canonical repo)
           uses: actions/checkout@v4

         - name: Resolve version + tarball URL
           id: resolve
           run: |
             TAG="${GITHUB_REF#refs/tags/v}"
             echo "version=$TAG" >> "$GITHUB_OUTPUT"
             URL="https://github.com/${{ github.repository }}/releases/download/v${TAG}/build-fractal-orchestrator-${TAG}.tgz"
             echo "url=$URL" >> "$GITHUB_OUTPUT"
             echo "tarball=build-fractal-orchestrator-${TAG}.tgz" >> "$GITHUB_OUTPUT"

         - name: Download SHA256SUMS from release
           env:
             GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
           run: |
             TAG="${{ steps.resolve.outputs.version }}"
             gh release download "v$TAG" \
               --repo "${{ github.repository }}" \
               --pattern SHA256SUMS \
               --dir release-artifacts/

         - name: Extract tarball SHA-256
           id: sha256
           run: |
             TAR="${{ steps.resolve.outputs.tarball }}"
             # SHA256SUMS lines are "<hex>  <filename>"; awk extracts
             # the hex for the matching filename. Bash 4+ permitted
             # in CI scripts per CON-2.
             DIGEST=$(awk -v t="$TAR" '$2 == "./" t || $2 == t { print $1 }' release-artifacts/SHA256SUMS)
             if [ -z "$DIGEST" ]; then
               echo "FAIL: could not find SHA-256 for $TAR in SHA256SUMS" >&2
               exit 1
             fi
             echo "digest=$DIGEST" >> "$GITHUB_OUTPUT"

         - name: Render formula
           run: |
             mkdir -p rendered
             bash packaging/homebrew/render-formula.sh \
               --version "${{ steps.resolve.outputs.version }}" \
               --url "${{ steps.resolve.outputs.url }}" \
               --sha256 "${{ steps.sha256.outputs.digest }}" \
               > rendered/orchestrator.rb
             head -5 rendered/orchestrator.rb

         - name: Clone tap repo
           env:
             HOMEBREW_TAP_TOKEN: ${{ secrets.HOMEBREW_TAP_TOKEN }}
           run: |
             # D008: PAT scoped to Build-Fractal/homebrew-orchestrator
             # contents:write only. The clone URL embeds the token via
             # the x-access-token user — GitHub's documented PAT-as-
             # password convention for HTTPS git operations.
             if [ -z "$HOMEBREW_TAP_TOKEN" ]; then
               echo "FAIL: HOMEBREW_TAP_TOKEN secret missing — see references/installation.md § Releasing via Homebrew (MOS-2)" >&2
               exit 1
             fi
             git clone "https://x-access-token:${HOMEBREW_TAP_TOKEN}@github.com/Build-Fractal/homebrew-orchestrator.git" tap-clone
             cd tap-clone
             git config user.name "github-actions[bot]"
             git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

         - name: Write formula and push
           working-directory: tap-clone
           run: |
             TAG="${{ steps.resolve.outputs.version }}"
             mkdir -p Formula
             cp ../rendered/orchestrator.rb Formula/orchestrator.rb
             git add Formula/orchestrator.rb
             # Allow no-op commits to be a no-op (re-running the job
             # for the same tag should not error).
             if git diff --staged --quiet; then
               echo "no-op: Formula/orchestrator.rb unchanged for v$TAG"
               exit 0
             fi
             git commit -m "formula: bump to v$TAG"
             git push origin HEAD:main
   ```

3. **Extend the `pr-validate` job with the CON-6 negative-assertion
   step** for `HOMEBREW_TAP_TOKEN`. Insert the following step *after*
   the existing `CON-6 — assert no NPM_TOKEN access` step in the
   `pr-validate` job:

   ```yaml
         - name: CON-6 — assert no HOMEBREW_TAP_TOKEN access
           run: |
             if [ -n "${HOMEBREW_TAP_TOKEN:-}" ]; then
               echo "FAIL: HOMEBREW_TAP_TOKEN visible to pr-validate job — CON-6 violated" >&2
               exit 1
             fi
             echo "PASS: HOMEBREW_TAP_TOKEN not visible to pr-validate (CON-6)"
   ```

4. **Append D008 to `.orchestrator/DECISIONS.md`** (immediately after
   D007). Exact insertion:

   ```markdown
   ### D008 — Tap-push mechanism: `secrets.HOMEBREW_TAP_TOKEN` PAT (contents:write only)

   - **Decided at**: M035 P03 plan-phase (2026-05-09).
   - **Decision**: The `homebrew-publish` job in
     `.github/workflows/release.yml` writes to
     `Build-Fractal/homebrew-orchestrator` using a Personal Access
     Token stored as `secrets.HOMEBREW_TAP_TOKEN`. The PAT MUST be
     scoped to
     `Build-Fractal/homebrew-orchestrator:contents:write` only — no
     other scope, no other repo.
   - **Rationale**:
     1. **Symmetry with `secrets.NPM_TOKEN` precedent** (P02 D001 /
        D002). Operator already manages PATs for the npm channel;
        adding one more under the same review cadence is lower
        friction than introducing GitHub App ownership semantics.
     2. **CON-6 job-condition gating identical to npm.** PAT is only
        visible inside the `homebrew-publish` job, which gates on the
        same `startsWith(github.ref, 'refs/tags/v') &&
        github.event_name == 'push'` predicate as `npm-publish`.
        PR-build exfiltration vector closed by the SC-14 assertion
        shape; `pr-validate` carries an explicit negative-assertion
        step asserting `HOMEBREW_TAP_TOKEN` is empty in PR context.
     3. **GitHub App migration is a clean fast-follow** if rotation
        friction surfaces — `homebrew-orchestrator` is the only repo
        the PAT writes to, so swapping the auth principal is a
        one-secret rotation with no formula changes.
   - **Bound to**: FR-9 / CON-6 / SC-14 / MOS-2.
   ```

5. **Author
   `tools/verify/m035-p03-release-workflow-homebrew-job.sh`.** Verifier
   asserts the workflow's `homebrew-publish` job structural shape:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p03-release-workflow-homebrew-job.sh
   set -u

   pass=0
   fail=0
   WF=".github/workflows/release.yml"

   if [ ! -f "$WF" ]; then
     echo "FAIL: $WF missing"
     echo "BATTERY: pass=0 fail=1"
     exit 1
   fi
   pass=$((pass + 1))

   for needle in \
     'homebrew-publish:' \
     'needs: npm-publish' \
     "startsWith(github.ref, 'refs/tags/v')" \
     'secrets.HOMEBREW_TAP_TOKEN' \
     'Build-Fractal/homebrew-orchestrator' \
     'render-formula.sh' \
     'Formula/orchestrator.rb' \
     'formula: bump to v'; do
     if grep -qF "$needle" "$WF"; then
       pass=$((pass + 1))
     else
       echo "FAIL: $WF missing pattern: $needle"
       fail=$((fail + 1))
     fi
   done

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   Make executable:

   ```bash
   chmod +x tools/verify/m035-p03-release-workflow-homebrew-job.sh
   ```

6. **Author `tools/verify/m035-p03-release-workflow-con6-homebrew.sh`.**
   Verifier asserts CON-6 negative-assertion step exists in
   `pr-validate`:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p03-release-workflow-con6-homebrew.sh
   set -u

   pass=0
   fail=0
   WF=".github/workflows/release.yml"

   if [ ! -f "$WF" ]; then
     echo "FAIL: $WF missing"
     echo "BATTERY: pass=0 fail=1"
     exit 1
   fi
   pass=$((pass + 1))

   if grep -qF 'CON-6 — assert no HOMEBREW_TAP_TOKEN access' "$WF"; then
     pass=$((pass + 1))
   else
     echo "FAIL: pr-validate missing CON-6 HOMEBREW_TAP_TOKEN negative-assertion step"
     fail=$((fail + 1))
   fi

   if grep -qF 'HOMEBREW_TAP_TOKEN visible to pr-validate job' "$WF"; then
     pass=$((pass + 1))
   else
     echo "FAIL: CON-6 negative-assertion missing FAIL message"
     fail=$((fail + 1))
   fi

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   Make executable:

   ```bash
   chmod +x tools/verify/m035-p03-release-workflow-con6-homebrew.sh
   ```

7. **Lint the YAML structure** by piping through `python3 -c 'import
   yaml,sys; yaml.safe_load(sys.stdin.read())'` (no external `yamllint`
   dependency). The workflow MUST parse without error.

8. **Run all four verifiers** (T01's two + T02's two) locally.

## Must-Haves

- Truth: workflow contains `homebrew-publish` job with `needs:
  npm-publish` + tag-push-only condition + the full step chain
  (verified by `m035-p03-release-workflow-homebrew-job.sh`).
- Truth: `pr-validate` carries CON-6 negative-assertion for
  `HOMEBREW_TAP_TOKEN` (verified by
  `m035-p03-release-workflow-con6-homebrew.sh`).
- Artifact: `.orchestrator/DECISIONS.md` contains D008.

## Verification

```bash
bash tools/verify/m035-p03-release-workflow-homebrew-job.sh
bash tools/verify/m035-p03-release-workflow-con6-homebrew.sh
grep -qE '^### D008' .orchestrator/DECISIONS.md
python3 -c 'import yaml,sys; yaml.safe_load(open(".github/workflows/release.yml").read())'
```

## Notes

Expected output: each shape verifier emits `BATTERY: pass=N fail=0`.
The `python3` YAML parse is silent on success.

Real-world tap-push validation: this job's end-to-end behavior is
exercised by P04's SC-14 dry-run-tag CI invocation. T02's verifiers
are static-shape checks; the live tap-push only fires on a real `v*`
tag-push against the canonical repo (CON-6).

## Inputs

### From Previous Tasks

- `packaging/homebrew/orchestrator.rb.tmpl` (from T01)
  - Key API: read by `render-formula.sh` via `$SCRIPT_DIR/orchestrator.rb.tmpl`.
  - Key behavior: contains `__VERSION__` / `__URL__` / `__SHA256__`
    tokens that get substituted at render time.
- `packaging/homebrew/render-formula.sh` (from T01)
  - Key API: `bash packaging/homebrew/render-formula.sh --version
    <X.Y.Z> --url <https-url> --sha256 <64-hex>` → rendered formula on
    stdout, exit 0 on success.

### From Disk (Pre-existing)

- `.github/workflows/release.yml` — extended additively. The existing
  `pr-validate` and `npm-publish` jobs are NOT modified beyond adding
  one negative-assertion step inside `pr-validate`.
- `.orchestrator/DECISIONS.md` — D008 appended after D007.

## Constraints

- Bash 4+ permitted in CI scripts per CON-2 (workflow steps run on
  `ubuntu-latest` per D001). Bash 3.2 still required for installer
  + render scripts (T01 already covered).
- The `homebrew-publish` job MUST gate on the same predicate as
  `npm-publish`: `startsWith(github.ref, 'refs/tags/v') &&
  github.event_name == 'push'`. Diverging predicates would break
  CON-6 symmetry and introduce a per-channel attack surface.
- The PAT secret name MUST be exactly `HOMEBREW_TAP_TOKEN` (matches
  D008 + the operator runbook in T04). Operator MOS-2 references the
  same name.

## Expected Output

- `.github/workflows/release.yml` extended (≥320 lines after T02; was
  ≥260 lines after P05 T03).
- `.orchestrator/DECISIONS.md` extended with the D008 row.
- `tools/verify/m035-p03-release-workflow-homebrew-job.sh` (≥35
  lines, emits `BATTERY: pass=N fail=0`).
- `tools/verify/m035-p03-release-workflow-con6-homebrew.sh` (≥25
  lines, emits `BATTERY: pass=N fail=0`).
