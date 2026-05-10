---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P05"
milestone: "M035"
name: "`references/installation.md § Verifying integrity` operator-facing recipe (FR-11 doc surface)"
depends_on: []
---

## Prerequisites

- **`references/installation.md`** exists with the existing structure:
  Overview, Install, Installation Steps, Upgrading, `## Channel-specific
  metadata files` (added by P02 T03), Uninstall sections. T04 inserts
  a new `## Verifying integrity` section.
- **D004 (sigstore keyless signing)** is bound at T03; T04 documentation
  references the same identity-URL pattern T03's signing pass uses.
  T04 may run concurrently with T03 (they have no interdependency at
  the script level), but the identity URL and verification recipe
  must be consistent. T04 author reads T03's plan (this file) to get
  the verification command shape.
- **`scripts/lib/errors.sh`** exports `emit_result`. Used by the
  verifier.
- No `## Verifying integrity` heading exists in `references/installation.md`
  at plan-authoring time.

## Description

Author the `## Verifying integrity` section in
`references/installation.md`. The section is operator-facing — readers
are evaluators following the README to install and want to know how to
verify what they're about to run. Copy must be self-sufficient (no
"see this other doc" indirection for the verification recipe itself).

Three subsections:

1. **Sigstore keyless verification (recommended)** — full `cosign
   verify-blob` recipe with the canonical-repo identity URL and OIDC
   issuer.
2. **SHA-256 checksum verification (no cosign required)** — `shasum -a
   256 -c SHA256SUMS` recipe; minimal-tooling fallback.
3. **What to do if verification fails** — recovery procedure: do not
   install, file an issue at the repo, link to the public key
   transparency log lookup.

The section is inserted between `## Channel-specific metadata files`
(P02 T03) and `## Uninstall` (existing).

## Steps

1. **Read `references/installation.md` in full** to identify section
   ordering and the existing P02 T03 `## Channel-specific metadata
   files` location. T04 inserts after that section.

2. **Author the `## Verifying integrity` section** with the verbatim
   markdown:

   ```markdown
   ## Verifying integrity

   Every published release ships with cryptographic integrity
   primitives so operators can verify what they're installing. Two
   verification paths are supported.

   ### Path 1: Sigstore keyless verification (recommended)

   Sigstore provides keyless signature verification — the signing
   identity is the GitHub Actions OIDC token bound to the canonical
   release workflow at the moment of signing. No project-managed GPG
   key, no key import ceremony.

   **Prerequisites**: [`cosign`](https://docs.sigstore.dev/cosign/installation)
   installed (typically `brew install cosign` on macOS or download
   from the [GitHub releases page](https://github.com/sigstore/cosign/releases)).

   **Verification**:

   1. Download the release artifact, signature, and certificate:

      ```bash
      VERSION="<X.Y.Z>"  # the release version, e.g. 1.0.0
      ARTIFACT="install.sh"  # or build-fractal-orchestrator-$VERSION.tgz, etc.
      curl -sSL -O "https://github.com/Build-Fractal/orchestrator/releases/download/v$VERSION/$ARTIFACT"
      curl -sSL -O "https://github.com/Build-Fractal/orchestrator/releases/download/v$VERSION/$ARTIFACT.sig"
      curl -sSL -O "https://github.com/Build-Fractal/orchestrator/releases/download/v$VERSION/$ARTIFACT.pem"
      ```

   2. Verify the signature:

      ```bash
      cosign verify-blob \
        --certificate-identity "https://github.com/Build-Fractal/orchestrator/.github/workflows/release.yml@refs/tags/v$VERSION" \
        --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
        --signature "$ARTIFACT.sig" \
        --certificate "$ARTIFACT.pem" \
        "$ARTIFACT"
      ```

      Expected output: `Verified OK`. Exit code: 0.

   The identity URL embeds the canonical repo (`Build-Fractal/orchestrator`),
   the workflow file path (`.github/workflows/release.yml`), and the
   exact tag (`refs/tags/v<VERSION>`) — three load-bearing constraints
   that make a forged signature impossible without a compromise of
   GitHub's OIDC issuer.

   ### Path 2: SHA-256 checksum verification (no cosign required)

   Every release also ships a `SHA256SUMS` file that operators can
   verify with stock `shasum`. This path requires no third-party
   tooling.

   **Verification**:

   1. Download the artifact and `SHA256SUMS`:

      ```bash
      VERSION="<X.Y.Z>"
      curl -sSL -O "https://github.com/Build-Fractal/orchestrator/releases/download/v$VERSION/install.sh"
      curl -sSL -O "https://github.com/Build-Fractal/orchestrator/releases/download/v$VERSION/SHA256SUMS"
      ```

   2. Verify the checksum:

      ```bash
      shasum -a 256 -c SHA256SUMS --ignore-missing
      ```

      Expected output: `install.sh: OK`. Exit code: 0.

   The `--ignore-missing` flag skips checksum lines for artifacts not
   downloaded (e.g. if you downloaded only `install.sh`, the npm tarball
   line is silently skipped).

   **Defense-in-depth**: `SHA256SUMS` itself is signed with cosign —
   `SHA256SUMS.sig` and `SHA256SUMS.pem` are also published. Operators
   who want both paths verified can run Path 1 against `SHA256SUMS`
   first, then Path 2 against the artifacts.

   ### What to do if verification fails

   1. **Do not install.** A failed verification means the artifact you
      downloaded does not match what was published.
   2. **Re-download** in case of a transient corruption — different CDN
      edge, different network — and re-run verification.
   3. **If verification still fails**, file an issue at
      [Build-Fractal/orchestrator/issues](https://github.com/Build-Fractal/orchestrator/issues)
      with the exact `cosign`/`shasum` output. Attach the failing
      artifact's SHA-256 hash so maintainers can compare against the
      published value.
   4. **Audit the Sigstore Rekor transparency log** at
      [search.sigstore.dev](https://search.sigstore.dev/) to confirm
      the published signature was issued by the canonical workflow.
      The release notes for each version include a direct Rekor entry
      link.
   ```

3. **Author the verifier**
   `tools/verify/m035-p05-installation-doc-verifying-integrity.sh`.
   ~40 lines. Single-script-file shape, AD-19. Asserts
   `references/installation.md` contains:

   1. The literal `## Verifying integrity` heading.
   2. Subsection heading `### Path 1: Sigstore keyless verification`.
   3. Subsection heading `### Path 2: SHA-256 checksum verification`.
   4. Subsection heading `### What to do if verification fails`.
   5. Literal token `cosign verify-blob`.
   6. Literal token `shasum -a 256 -c SHA256SUMS`.
   7. The canonical-repo identity URL pattern
      (`https://github.com/Build-Fractal/orchestrator/.github/workflows/release.yml`).
   8. The OIDC issuer URL (`https://token.actions.githubusercontent.com`).
   9. Reference to `search.sigstore.dev` (Rekor transparency log).

   Each assertion is a `grep -q -F` invocation. Emit `PASS:` / `FAIL:`
   lines + `BATTERY: pass=9 fail=0` summary.

## Must-Haves

- `references/installation.md` modified — contains all of:
  `## Verifying integrity`, `### Path 1: Sigstore keyless verification`,
  `### Path 2: SHA-256 checksum verification`,
  `cosign verify-blob`, `shasum -a 256 -c SHA256SUMS`,
  `Build-Fractal/orchestrator/.github/workflows/release.yml`,
  `search.sigstore.dev`.
- `tools/verify/m035-p05-installation-doc-verifying-integrity.sh`
  exists, emits `BATTERY: pass=9 fail=0`.

## Verification

```bash
bash tools/verify/m035-p05-installation-doc-verifying-integrity.sh
```

## Inputs

### From Previous Tasks

None — T04 has no upstream P05 task dependencies. It composes against
T03's signing identity-URL convention by reading T03's plan (this
file) at execution time.

### From Disk (Pre-existing)

- `references/installation.md` (P02 T03 Channel-specific metadata
  files at line range TBD — read at execution time). T04 inserts after
  this section.
- `scripts/lib/errors.sh` — sourceable lib for `emit_result`.

## Constraints

- **AD-19 single-script-file shape** — verifier uses `bash
  tools/verify/...` invocations. All assertions are `grep -q -F`
  on a single file (no compound chains).
- **Self-contained operator copy** — the verification recipe must be
  runnable end-to-end without reading any other doc. Every command
  shows the exact flags, the exact URLs, and the expected output.
- **Identity URL consistency with T03** — the canonical-repo identity
  URL in this doc MUST match the identity cosign actually issues at
  signing time in T03. Both reference the same canonical repo
  (`Build-Fractal/orchestrator`), the same workflow file path
  (`.github/workflows/release.yml`), and a per-release tag
  (`refs/tags/v<VERSION>`).
- **No tooling-required assumption** — Path 2 (shasum) MUST be
  documented as fully sufficient for operators who do not install
  cosign. The doc's framing is: cosign is recommended; shasum is
  acceptable; operators who run both have defense-in-depth.
- **Plan-Time Discipline Rule 6** —
  `tools/verify/m035-p05-installation-doc-verifying-integrity.sh` is
  absent at plan-authoring time. New file, milestone-prefixed slug.

## Expected Output

Stdout from `bash tools/verify/m035-p05-installation-doc-verifying-integrity.sh`:

```
PASS: ## Verifying integrity heading present
PASS: ### Path 1: Sigstore keyless verification heading present
PASS: ### Path 2: SHA-256 checksum verification heading present
PASS: ### What to do if verification fails heading present
PASS: cosign verify-blob recipe present
PASS: shasum -a 256 -c SHA256SUMS recipe present
PASS: canonical-repo identity URL present
PASS: OIDC issuer URL present
PASS: search.sigstore.dev Rekor reference present
BATTERY: pass=9 fail=0
```
