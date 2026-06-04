# Releasing the orchestrator

How a maintainer cuts a public release. The publishing pipeline (npm + Homebrew
+ curl-pipe-bash + signed GitHub release) is fully automated in
`.github/workflows/release.yml` and fires on a `v*` tag push. This runbook
covers the **one-time setup**, the **per-release steps**, and the
**first-release smoke tests** (M035 MOS-3/MOS-4/MOS-5).

> TL;DR for a routine release once setup is done:
> ```bash
> bash scripts/util/bump-version.sh X.Y.Z      # sync VERSION + package.json + manifest
> # edit CHANGELOG.md, commit
> git tag vX.Y.Z && git push origin vX.Y.Z      # <-- triggers the release workflow
> ```

---

## One-time operator setup

These require accounts/credentials and can only be done by a human with owner
access. They are M035 MOS-1 / MOS-2 (deferred to first release).

### 1. npm scope + automation token (`NPM_TOKEN`)

1. Ensure the `@build-fractal` npm org/scope exists and your npm account can
   publish to it (`npm org ls build-fractal`). Create the scope if needed.
2. Create an **automation** token (CI-friendly; bypasses 2FA for publish):
   `npm token create --read-only=false` — or via npmjs.com → Access Tokens →
   Generate → "Automation".
3. Add it to the GitHub repo as an Actions secret named **`NPM_TOKEN`**:
   `gh secret set NPM_TOKEN` (paste the token), or repo Settings → Secrets and
   variables → Actions → New repository secret.

### 2. Homebrew tap repo + push token (`HOMEBREW_TAP_TOKEN`)

1. Create the tap repo **`Build-Fractal/homebrew-orchestrator`** on GitHub
   (public, with a one-line README). Homebrew taps are just GitHub repos named
   `homebrew-<name>`; the formula lands at `Formula/orchestrator.rb`.
   ```bash
   gh repo create Build-Fractal/homebrew-orchestrator --public \
     --description "Homebrew tap for the orchestrator" --add-readme
   ```
2. Create a **fine-grained PAT** scoped to *only* that repo with
   **Contents: Read and write** (no other permissions) — this is the minimal
   scope the `homebrew-publish` job needs to push the rendered formula (M035 D008).
3. Add it to the **main orchestrator repo** as an Actions secret named
   **`HOMEBREW_TAP_TOKEN`**.

### 3. (Recommended) validate the workflow against a fork — MOS-5

Before the first real tag, push a throwaway tag against a fork to exercise the
whole pipeline without touching the real registries:

```bash
# in a fork with its own (test) NPM_TOKEN/HOMEBREW_TAP_TOKEN secrets
git tag v0.0.0-test && git push origin v0.0.0-test
```

Watch the run, confirm npm publish + GH release + formula push all succeed, then
`npm unpublish @build-fractal/orchestrator@0.0.0-test` and delete the test tag.

---

## Per-release steps

### 1. Pre-flight

- Working tree clean, on `main` (or the release branch), all intended work merged.
- Acceptance suites green for anything new in the release (e.g. milestone batteries).
- Confirm version sources agree *or* are about to be bumped together:
  ```bash
  bash scripts/util/bump-version.sh --check
  ```

### 2. Bump the version

The version lives in three machine-read places that MUST agree (the workflow
verifies the git tag matches `package.json`; the bundle ships `manifest.yml`).
`bump-version.sh` syncs all three plus the canonical `VERSION` file:

```bash
bash scripts/util/bump-version.sh X.Y.Z
bash scripts/util/bump-version.sh --check   # confirms PASS
```

Update the README version badge if you keep one. Pre-1.0 releases are cut
manually and deliberately (M035 D011).

### 3. Changelog

Add a top entry to `CHANGELOG.md` for `X.Y.Z` summarizing user-visible changes.
Commit the bump + changelog together:

```bash
git add VERSION package.json packaging/bundle/manifest.yml CHANGELOG.md
git commit -m "release: vX.Y.Z"
```

### 4. Tag and push — this triggers the release

```bash
git tag vX.Y.Z
git push origin main          # push the commit first
git push origin vX.Y.Z        # the tag push fires .github/workflows/release.yml
```

### 5. Watch the workflow

```bash
gh run watch
```

On a `v*` tag push, `release.yml` runs three jobs (M035 P02–P05):

1. **`npm-publish`** — verifies the tag matches `package.json`, runs the
   pre-publish shape gates, `npm publish --access public`, then signs every
   release artifact with cosign (keyless OIDC), generates `SHA256SUMS`, and
   creates the GitHub release uploading: the npm tarball, `install.sh`,
   `SHA256SUMS`, and per-artifact `.sig`/`.pem`.
2. **`homebrew-publish`** (`needs: npm-publish`) — downloads `SHA256SUMS`,
   renders `Formula/orchestrator.rb` from the template, and pushes it to the tap.

Secrets are structurally scoped to the tag-triggered jobs only; the PR-validation
job asserts they are absent (M035 CON-6).

### 6. Post-release dev bump (version-distinguishability convention)

Immediately after the release workflow goes green, bump `main` to the **next
patch with a `-dev` suffix** so the local working tree always reads *ahead* of
the last published tag. Without this, `VERSION` stays at the just-released
`X.Y.Z` while `main` accumulates unreleased commits — making a local checkout
indistinguishable from the registry build by version string alone (you'd have
to compare git SHAs to tell them apart, which has bitten dogfood updates).

```bash
bash scripts/util/bump-version.sh X.Y.(Z+1)-dev   # e.g. after v0.9.6 -> 0.9.7-dev
git add VERSION package.json packaging/bundle/manifest.yml
git commit -F <msg-file>                            # "chore: bump to X.Y.(Z+1)-dev post-release"
git push origin main
```

The `-dev` build is never published (no tag is cut for it); the next real
release re-bumps to a clean `X.Y.(Z+1)` in step 2. `bump-version.sh` accepts the
prerelease suffix and keeps all three version sources in sync.

---

## First-release smoke tests (MOS-3 / MOS-4)

Run these once the workflow is green to confirm each public channel actually works:

```bash
# npm (MOS-2 path)
npm install -g @build-fractal/orchestrator && orchestrator --version

# Homebrew (MOS-3)
brew tap build-fractal/orchestrator
brew install orchestrator && orchestrator --version

# curl | bash (MOS-4)
curl -fsSL https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh | bash
```

Then verify a consumer can update (see `commands/update.md` dispatch table):
`npm update -g @build-fractal/orchestrator`, `brew upgrade orchestrator`, or
`/orchestrator-update` from inside a project.

Integrity verification (signatures + checksums) is documented for end users in
`references/installation.md § Verifying integrity`.

---

## If something goes wrong

- **Tag/version mismatch** → the `npm-publish` job fails fast at the verify step.
  Fix `package.json` (re-run `bump-version.sh`), delete the bad tag
  (`git push --delete origin vX.Y.Z`), re-tag.
- **npm publish failed after partial success** → npm versions are immutable; you
  cannot republish the same version. Bump to `X.Y.Z+1` and re-tag. (Unpublish is
  only viable within 72h and is discouraged.)
- **Homebrew job failed but npm succeeded** → the formula push is idempotent and
  re-runnable; re-run the failed job (`gh run rerun <id> --failed`) once the tap
  repo / `HOMEBREW_TAP_TOKEN` is fixed. npm consumers are unaffected.
- **Consumer rollback** → `orchestrator:update --rollback` (copy-mode installs);
  see `commands/update.md § Rollback` for symlink-mode and source-specific behavior.

---

## References

- `.github/workflows/release.yml` — the automation this runbook drives.
- `scripts/util/bump-version.sh` — version-sync SOP (+ `--check` drift guard).
- `commands/update.md` — consumer-side update + the `git|npm|homebrew|none` dispatch table.
- `references/installation.md` — end-user install + integrity verification.
- `packaging/homebrew/{orchestrator.rb.tmpl,render-formula.sh}` — formula template + renderer.
- `packaging/install/install.sh` — the curl-pipe-bash installer hosted on each release.
- `.orchestrator/milestones/M035/M035-SUMMARY.md` — full design + decisions (D001–D014, MOS-1..MOS-5).
