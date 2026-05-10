---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P05"
milestone: "M035"
name: "Sigstore (cosign keyless) signing + SHA-256 checksums in `.github/workflows/release.yml` (FR-11 + D004)"
depends_on: []
---

## Prerequisites

- **`.github/workflows/release.yml`** exists with the P02 T04 skeleton:
  two-job split (`pr-validate` + `npm-publish`), workflow-level
  `permissions: contents: read`, `npm-publish` gated on
  `if: ${{ startsWith(github.ref, 'refs/tags/v') && github.event_name
  == 'push' }}` (CON-6). T03 extends the `npm-publish` job.
- **`package.json`** declares `"name": "@build-fractal/orchestrator"`
  ([D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }")). T03 reads this name to construct the release-artifact path
  patterns.
- **GitHub Actions OIDC support** is available on the canonical repo
  (`Build-Fractal/orchestrator`). T03 does NOT verify this at plan-
  authoring time — it is a property of the GitHub org/repo
  configuration, not of the workflow file. T05 acceptance test runs
  against the workflow shape, not against a real OIDC issuance.
- **`scripts/lib/errors.sh`** exports `emit_result`. Used by the
  verifier.
- No signing block exists in `.github/workflows/release.yml` at plan-
  authoring time.

## Description

Extend `.github/workflows/release.yml`'s `npm-publish` job with a
sigstore (cosign keyless) signing pass and a SHA-256 checksum
generation pass that run AFTER `npm publish` succeeds and BEFORE the
final `Confirm publish succeeded` step. The signing pass produces, for
each release artifact:

- `<artifact>.sig` — the detached cosign signature blob.
- `<artifact>.pem` — the OIDC certificate cosign issued.

Plus a single `SHA256SUMS` file at the release-asset root covering all
release artifacts (one line per artifact: `<sha256>  <basename>`).

All signature artifacts and the `SHA256SUMS` file are uploaded to the
GitHub release via `gh release upload`. The `gh release create` call
is added to the same job (P02 T04 deferred GH-release creation to a
later phase; T03 lands it now).

T03 ALSO ships an explicit `permissions: id-token: write` override at
the `npm-publish` job level. The workflow-level
`permissions: contents: read` from P02 T04 stays unchanged
(least-privilege at the workflow level; the job that needs OIDC opts
in explicitly).

**The signing pass is currently scoped to the npm tarball** (the only
release artifact P02 produces). When P03 (homebrew bottle), P04 (curl-
pipe-bash `install.sh`), and any future channel artifacts land, they
extend the signing block by adding artifact paths to the loop variable.
T03 ships the signing block in a shape that handles "every artifact in
the artifacts directory" via a glob, so future phases need NOT modify
the signing block — they only need to drop their artifact into the
shared release-staging directory.

**SHA256SUMS is the tooling-free fallback path**: operators without
`cosign` installed verify integrity with `shasum -a 256 -c SHA256SUMS`
against the unpacked artifact set. SC-11 asserts both surfaces
(cosign-verify-blob AND shasum-verify) succeed.

## Steps

1. **Read the current `.github/workflows/release.yml` in full** (152
   lines). Identify the `npm-publish` job's existing steps:
   1. Checkout
   2. Setup Node.js
   3. Verify tag matches package.json version
   4. Run pre-publish gates
   5. npm publish (public access)
   6. Confirm publish succeeded

   T03 adds new steps between (5) and (6):
   - 5a. Setup cosign
   - 5b. Stage release artifacts
   - 5c. Generate SHA256SUMS
   - 5d. Sign artifacts with cosign keyless
   - 5e. Create GitHub release + upload artifacts

2. **Add the `permissions: id-token: write` override** at the
   `npm-publish` job level. Insert after the `runs-on: ubuntu-latest`
   line (or after the `name:` line — read the existing structure to
   match). The block:

   ```yaml
   permissions:
     contents: write   # gh release create needs this
     id-token: write   # cosign keyless OIDC
   ```

   The workflow-level `permissions: contents: read` is overridden by
   this job-level block. Other jobs (`pr-validate`) inherit the
   workflow-level read-only permission unchanged.

3. **Insert step 5a — Setup cosign**:

   ```yaml
         - name: Setup cosign
           uses: sigstore/cosign-installer@v3.5.0
           with:
             cosign-release: 'v2.2.4'
   ```

   Pin both the action version AND the cosign release version for
   reproducibility (Constitution Principle XVI: dependency immutability
   at release time).

4. **Insert step 5b — Stage release artifacts**:

   ```yaml
         - name: Stage release artifacts
           run: |
             mkdir -p release-artifacts
             # npm tarball
             TAG="${GITHUB_REF#refs/tags/v}"
             # @build-fractal/orchestrator -> build-fractal-orchestrator
             # npm pack produces build-fractal-orchestrator-<version>.tgz
             npm pack
             mv build-fractal-orchestrator-"$TAG".tgz release-artifacts/
             # P03 hook: homebrew bottle would land here
             # P04 hook: install.sh would land here
             ls -la release-artifacts/
   ```

   The `npm pack` invocation re-creates the tarball locally rather than
   re-downloading from the registry — this is the same artifact npm
   publish uploaded a moment ago, byte-identical.

5. **Insert step 5c — Generate SHA256SUMS**:

   ```yaml
         - name: Generate SHA256SUMS
           working-directory: release-artifacts
           run: |
             # shasum -a 256 emits "<hex>  <filename>" lines
             # We sort by filename for deterministic output
             find . -maxdepth 1 -type f ! -name SHA256SUMS \
               -exec shasum -a 256 {} \; \
               | LC_ALL=C sort -k 2 \
               > SHA256SUMS
             cat SHA256SUMS
   ```

   The `LC_ALL=C sort` ensures locale-independent reproducible output
   (the same convention used by P02 T03's byte-equivalence helper).

6. **Insert step 5d — Sign artifacts with cosign keyless**:

   ```yaml
         - name: Sign release artifacts (sigstore keyless)
           working-directory: release-artifacts
           env:
             COSIGN_EXPERIMENTAL: "1"
           run: |
             # Sign every release artifact (excluding SHA256SUMS itself
             # and any pre-existing .sig/.pem files).
             for artifact in *; do
               case "$artifact" in
                 *.sig|*.pem|SHA256SUMS)
                   continue
                   ;;
               esac
               echo "Signing $artifact ..."
               cosign sign-blob \
                 --yes \
                 --output-signature "$artifact.sig" \
                 --output-certificate "$artifact.pem" \
                 "$artifact"
             done
             # Also sign SHA256SUMS itself (so operators can verify the
             # checksum file's authenticity before relying on it)
             cosign sign-blob \
               --yes \
               --output-signature SHA256SUMS.sig \
               --output-certificate SHA256SUMS.pem \
               SHA256SUMS
             ls -la
   ```

   `--yes` skips the interactive Y/N prompt cosign normally requires
   for keyless signing under CI. `COSIGN_EXPERIMENTAL=1` is a
   defensive belt-and-suspenders for older cosign versions; cosign
   v2.2+ does not strictly require it, but inclusion is harmless.

7. **Insert step 5e — Create GitHub release**:

   ```yaml
         - name: Create GitHub release
           env:
             GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
           run: |
             TAG="${GITHUB_REF#refs/tags/v}"
             # Auto-generated release notes (--generate-notes)
             gh release create "v$TAG" \
               --title "v$TAG" \
               --generate-notes \
               release-artifacts/*
   ```

   `secrets.GITHUB_TOKEN` is the default token GitHub Actions provides
   to every workflow; no secret-management ceremony required. The
   `permissions: contents: write` job-level override (step 2) gives it
   the scope needed to create releases.

8. **Append D004 to [`.orchestrator/DECISIONS.md`](../../../../../decisions.md)** — author the row
   following the existing convention. Append:

   ```
   | D004 | M035/P05 | signing-strategy: sigstore keyless | release.yml signs every release artifact with `cosign sign-blob` keyless (OIDC bound to canonical-repo `v*` tag-push); SHA256SUMS published as tooling-free fallback verification path. | keyless eliminates GPG private-key blast radius; SHA256SUMS preserves verifiability for operators without cosign installed. | bound by FR-11 / SC-11 / CON-6 | 2026-05-08 |
   ```

   (Adjust column shape to match the existing DECISIONS.md table at
   append time.)

9. **Author the verifier**
   `tools/verify/m035-p05-release-workflow-signing-shape.sh`. ~80 lines.
   Single-script-file shape, AD-19. The verifier asserts the workflow
   YAML carries the load-bearing tokens. Each assertion is a `grep -q`
   on `.github/workflows/release.yml`:

   1. `permissions:` block at job-level under `npm-publish` includes
      `id-token: write`.
   2. `permissions:` block at job-level under `npm-publish` includes
      `contents: write`.
   3. Step `Setup cosign` uses `sigstore/cosign-installer`.
   4. Cosign release version is pinned (string `cosign-release:` present).
   5. Step `Stage release artifacts` exists (anchor: `release-artifacts`
      directory).
   6. Step `Generate SHA256SUMS` exists (anchor: `SHA256SUMS`).
   7. Step `Sign release artifacts` invokes `cosign sign-blob`.
   8. Cosign sign-blob uses `--output-signature` AND `--output-certificate`.
   9. Step `Create GitHub release` invokes `gh release create`.
   10. SHA256SUMS itself is signed (anchor: `cosign sign-blob` AND
       `SHA256SUMS.sig`).

   Emit `PASS:` / `FAIL:` lines per assertion + `BATTERY: pass=10 fail=0`
   summary.

10. **Author the YAML lint probe** (`/tmp/m035-p05-t03-yaml-validate.sh`,
    staged via `scripts/util/run-probe.sh`). The probe runs:

    ```bash
    #!/usr/bin/env bash
    set -euo pipefail
    python3 -c "
    import yaml, sys
    with open('${REPO_ROOT}/.github/workflows/release.yml') as f:
        doc = yaml.safe_load(f)
    assert 'jobs' in doc, 'missing jobs'
    assert 'npm-publish' in doc['jobs'], 'missing npm-publish'
    job = doc['jobs']['npm-publish']
    assert 'permissions' in job, 'missing job-level permissions'
    assert 'id-token' in job['permissions'], 'missing id-token permission'
    assert job['permissions']['id-token'] == 'write', 'id-token not write'
    print('PASS: workflow YAML shape valid')
    "
    ```

    Invoked from the verifier (step 9) via:

    ```bash
    bash scripts/util/run-probe.sh /tmp/m035-p05-t03-yaml-validate.sh
    ```

    This catches YAML indentation breakage that the grep-based contract
    surface in step 9 would miss. Mirrors the P02 T04 yaml-validate
    convention.

## Must-Haves

- `.github/workflows/release.yml` modified — contains all of:
  `id-token: write`, `cosign sign-blob`, `--output-signature`,
  `--output-certificate`, `SHA256SUMS`, `gh release create`,
  `sigstore/cosign-installer`.
- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) modified — contains `D004` row
  referencing M035/P05 + sigstore + cosign.
- `tools/verify/m035-p05-release-workflow-signing-shape.sh` exists,
  emits `BATTERY: pass=10 fail=0`.
- `/tmp/m035-p05-t03-yaml-validate.sh` (staged probe; transient)
  passes when invoked via `run-probe.sh`.

## Verification

```bash
bash tools/verify/m035-p05-release-workflow-signing-shape.sh
```

```bash
bash tools/verify/m035-p02-release-workflow-shape.sh
```

```bash
bash scripts/util/run-probe.sh /tmp/m035-p05-t03-yaml-validate.sh
```

## Inputs

### From Previous Tasks

None — T03 has no upstream P05 dependencies. It composes against the
P02 release.yml skeleton.

### From Disk (Pre-existing)

- `.github/workflows/release.yml` (P02 T04 — 152 lines) — existing
  two-job split. T03 inserts five new steps into `npm-publish` and
  one job-level `permissions:` block.
- `package.json` — `name: @build-fractal/orchestrator` drives the
  npm tarball filename pattern `build-fractal-orchestrator-<version>.tgz`.
- `tools/verify/m035-p02-release-workflow-shape.sh` (P02 T04) — the
  existing workflow-shape verifier. T03 verifier extends the
  contract surface; both verifiers MUST pass after T03 lands (P02's
  contract surfaces are unchanged by T03's additions).
- `scripts/util/run-probe.sh` — staged-probe wrapper for the YAML
  lint probe in step 10.
- `scripts/lib/errors.sh` — sourceable lib for `emit_result`.

## Constraints

- **AD-19 single-script-file shape** — verifier uses
  `bash tools/verify/...`. The YAML lint probe is staged at `/tmp/`
  per `run-probe.sh` scope and invoked via `run-probe.sh`.
- **CON-3 / AP-009 (compound-chain shape-guard)** — workflow YAML's
  `run:` blocks use the YAML pipe block scalar (`|`) which is
  single-script-shape per AP-009 (P02 T04 precedent). The `for
  artifact in *; do ... done` loop in step 6 is a single shell
  construct, not a compound chain.
- **CON-6 (secrets-scoped to v* tag-push)** — T03 adds NO new secret
  surfaces. `secrets.GITHUB_TOKEN` is the default token, available to
  every workflow run, but the `npm-publish` job's structural
  `if: startsWith(github.ref, 'refs/tags/v')` gate from P02 T04
  ensures it only fires on tag-push events. The PR-validate job's
  CON-6 negative-assertion step (`assert no NPM_TOKEN access`) is
  preserved unchanged. Step 9's verifier asserts both surfaces.
- **D004 binding** — sigstore keyless primary, SHA-256 fallback. T03
  ships both surfaces; T05's signature-verification verifier exercises
  both.
- **Reproducibility** — both `cosign-installer` (action version) and
  cosign itself (release version) are pinned. The `LC_ALL=C sort` in
  step 5 ensures SHA256SUMS line ordering is stable across runs.
- **Plan-Time Discipline Rule 6** —
  `tools/verify/m035-p05-release-workflow-signing-shape.sh` is absent
  at plan-authoring time. New file, milestone-prefixed slug.

## Expected Output

Stdout from `bash tools/verify/m035-p05-release-workflow-signing-shape.sh`:

```
PASS: npm-publish job declares permissions.id-token: write
PASS: npm-publish job declares permissions.contents: write
PASS: workflow uses sigstore/cosign-installer
PASS: cosign release version is pinned
PASS: Stage release artifacts step exists
PASS: Generate SHA256SUMS step exists
PASS: cosign sign-blob invocation present
PASS: cosign sign-blob uses --output-signature and --output-certificate
PASS: gh release create invocation present
PASS: SHA256SUMS itself is signed
BATTERY: pass=10 fail=0
```

Stdout from `bash scripts/util/run-probe.sh /tmp/m035-p05-t03-yaml-validate.sh`:

```
PASS: workflow YAML shape valid
```
