---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P05"
milestone: "M035"
provides:
  - "sigstore-keyless-signing + SHA-256-fallback in .github/workflows/release.yml npm-publish job (5 new steps: Setup cosign + Stage release artifacts + Generate SHA256SUMS + Sign release artifacts + Create GitHub release) + job-level permissions override (id-token: write, contents: write) + D004 row in DECISIONS.md + tools/verify/m035-p05-release-workflow-signing-shape.sh task-grain verifier (BATTERY pass=10 fail=0) + /tmp/m035-p05-t03-yaml-validate.sh staged YAML structural-shape probe"
requires:
  - "from:P02/T04 what:.github/workflows/release.yml two-job skeleton,from:P02/T01 what:package.json @build-fractal/orchestrator name driving npm pack tarball pattern,from:M035-spec what:Q-3 D004 binding sigstore-primary + SHA-256-fallback,from:scripts/util/run-probe.sh what:approved-roots /tmp wrapper for staged YAML probe"
affects:
  - "P05/T04 (verify-installation operator-doc mirrors the canonical cosign verify-blob identity-URL pattern T03 declares),P05/T05 (signature-verification acceptance test exercises both sigstore + SHA-256 surfaces),P05/T06 (phase-suite aggregator chains the new signing-shape verifier),P03 (homebrew bottle drops into release-artifacts/ no edit to signing loop needed),P04 (curl-pipe-bash install.sh drops into release-artifacts/ same pattern)"
key_files:
  - ".github/workflows/release.yml,.orchestrator/DECISIONS.md,tools/verify/m035-p05-release-workflow-signing-shape.sh,/tmp/m035-p05-t03-yaml-validate.sh"
key_decisions:
  - "D004 (authored: sigstore keyless primary + SHA-256 fallback resolves spec Q-3),FR-11 (release artifacts signed at publish time),SC-11 (both cosign-verify-blob AND shasum-verify surfaces succeed),CON-6 (no new long-lived secrets),CON-3/AP-009 (workflow YAML run blocks use pipe-block-scalar single-script-shape),AD-19 (verifier ships single-script Check shape with BATTERY-line output),Constitution-Principle-XVI (cosign-installer action AND cosign release version both pinned for dependency immutability)"
patterns_established:
  - "job-level-permissions-override-preserves-workflow-level-least-privilege,release-artifacts-glob-loop-with-case-continue-skip,sigstore-keyless-OIDC-primary-plus-shasum-fallback,sign-the-checksum-file-itself,pinned-cosign-action-AND-pinned-cosign-release,npm-pack-after-publish-as-byte-identical-tarball-recreation,LC_ALL=C-sort-for-locale-independent-SHA256SUMS,python3-yaml-safe-load-staged-probe-mirrors-P02-T04,REPO_ROOT-defensive-fallback-in-staged-probes-continued,--yes-flag-required-for-cosign-keyless-under-CI"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P05/tasks/T03-sigstore-signing-release-workflow-PAYLOAD.md,.orchestrator/milestones/M035/phases/P05/tasks/T03-sigstore-signing-release-workflow-PLAN.md"
duration: "18m"
verification_result: "pass"
completed_at: "2026-05-09T01:09:16Z"
---

## What was built

T03 — sigstore signing + release-workflow extension — adds the launch-readiness signing pipeline to `.github/workflows/release.yml` resolving spec #Q-3 to D004 (sigstore keyless primary + SHA-256 fallback). Three artifacts touched:

1. **`.github/workflows/release.yml` extension** — adds a job-level `permissions:` override under `npm-publish` (`contents: write` + `id-token: write`) and inserts five new steps between `npm publish` (step 5) and `Confirm publish succeeded` (step 6):
   - **5a. Setup cosign** — `sigstore/cosign-installer@v3.5.0` action pinned, `cosign-release: 'v2.2.4'` binary pinned (Constitution Principle XVI).
   - **5b. Stage release artifacts** — `npm pack` re-creates the tarball locally (byte-identical to what `npm publish` just uploaded), moves to `release-artifacts/`. Comments mark P03 + P04 hooks for homebrew + curl-pipe-bash drop-points.
   - **5c. Generate SHA256SUMS** — `find -exec shasum -a 256 | LC_ALL=C sort -k 2 > SHA256SUMS` produces a deterministic, locale-independent checksum file (mirrors P02 T03 byte-equivalence helper convention).
   - **5d. Sign release artifacts (sigstore keyless)** — `for artifact in *; do case skip *.sig|*.pem|SHA256SUMS; cosign sign-blob --yes --output-signature $artifact.sig --output-certificate $artifact.pem $artifact; done` plus a separate `cosign sign-blob` of `SHA256SUMS` itself (so operators can verify the checksum file's authenticity before relying on it).
   - **5e. Create GitHub release** — `gh release create v$TAG --title v$TAG --generate-notes release-artifacts/*` using `secrets.GITHUB_TOKEN` (default GHA token, scope granted by job-level `contents: write`).
2. **[`.orchestrator/DECISIONS.md`](../../../../../decisions.md) D004 row** — appended in the existing 7-column table format alongside D001/D002/D003/D005, documenting the sigstore-keyless + SHA-256-fallback choice, the OIDC-binding rationale (eliminates GPG private-key blast radius), the SHA256SUMS rationale (tooling-free fallback for operators without cosign installed), and the CON-6 secret-scope discipline (no new long-lived secrets — `secrets.GITHUB_TOKEN` is the default token, `secrets.NPM_TOKEN` scope unchanged from P02 T04).
3. **`tools/verify/m035-p05-release-workflow-signing-shape.sh`** — ~110 lines, AD-19 single-script-file shape, `BATTERY: pass=10 fail=0` matching the plan's prescribed Expected Output line-for-line. Ten named contract assertions: id-token: write + contents: write + sigstore/cosign-installer + pinned cosign-release + Stage release artifacts step + Generate SHA256SUMS step + cosign sign-blob invocation + --output-signature AND --output-certificate (single combined PASS line) + gh release create + SHA256SUMS.sig (the checksum-file-self-signing anchor).
4. **`/tmp/m035-p05-t03-yaml-validate.sh` staged probe** — invoked via `scripts/util/run-probe.sh`. `python3 yaml.safe_load` parses the workflow doc and asserts the structural invariants T03 introduces: `jobs.npm-publish.permissions` is a mapping (not a string short-hand), `id-token == 'write'`, `contents == 'write'`, and all five required step names are present in `steps[]`. Catches indentation breakage that the grep-based contract surface would miss. Mirrors the P02 T04 yaml-validate convention.

## Plan-phase Open Questions resolved

- **#Q-3 → D004**: signing strategy = sigstore (cosign keyless) primary + SHA-256 fallback. Authored in DECISIONS.md table format alongside D001/D002/D003/D005.

## Verification

- `bash tools/verify/m035-p05-release-workflow-signing-shape.sh` → `BATTERY: pass=10 fail=0` (matches plan's prescribed Expected Output line-for-line).
- `bash tools/verify/m035-p02-release-workflow-shape.sh` → `BATTERY: pass=10 fail=0` (regression: P02 contract surfaces unchanged by T03 additions).
- `bash scripts/util/run-probe.sh /tmp/m035-p05-t03-yaml-validate.sh` → `PASS: workflow YAML shape valid` (structural-shape probe).
- Regression: `bash tools/verify/m035-p05-rollback-marker-shape.sh` → `BATTERY: pass=6 fail=0` (T01, unchanged).
- Regression: `bash tools/verify/m035-p05-rollback-driver-shape.sh` → `BATTERY: pass=4 fail=0` (T02, unchanged).

## Patterns established

- **Job-level permissions override preserves workflow-level least-privilege** — workflow-level `permissions: contents: read` from P02 T04 stays unchanged; `npm-publish` opts into `id-token: write` + `contents: write` at the job level only. Other jobs (`pr-validate`) inherit the workflow-level read-only permission and gain neither scope. The override block lives between the `if:` job-condition and the `steps:` list.
- **Release-artifacts glob loop with case+continue skip** — `for artifact in *; do case skip *.sig|*.pem|SHA256SUMS; cosign sign-blob $artifact; done` handles every artifact in `release-artifacts/` via glob so P03 (homebrew bottle) + P04 (curl-pipe-bash install.sh) extend by dropping their artifact into the staging dir — no edit to the loop needed.
- **Sign the checksum file itself** — `cosign sign-blob` is also run against `SHA256SUMS` producing `SHA256SUMS.sig` + `SHA256SUMS.pem` so operators can verify the checksum file's authenticity before relying on it for individual-artifact integrity. SHA256SUMS without its own signature would be a hash-collision-resistant integrity check but not an authenticity check.
- **Pinned cosign-installer action AND pinned cosign release** — Constitution Principle XVI dependency immutability requires both layers. Action version pinned at `sigstore/cosign-installer@v3.5.0`; cosign binary pinned at `cosign-release: 'v2.2.4'`. Either alone is insufficient: action-only pinning leaves the binary version floating; binary-only pinning leaves the GHA wrapper floating.
- **npm pack after publish as byte-identical tarball recreation** — `npm pack` invoked locally after `npm publish` recreates the same tarball npm publish just uploaded. Faster than re-downloading from the registry, byte-identical to the published artifact, no race against registry propagation delay.
- **LC_ALL=C sort for locale-independent SHA256SUMS** — same convention as P02 T03 byte-equivalence helper. Locale-independent line ordering means SHA256SUMS is byte-identical across runners (ubuntu-latest CI vs. macOS dev box).
- **python3 yaml.safe_load staged probe** — mirrors P02 T04 yaml-validate convention. Catches indentation breakage that grep-based contract surface misses. Asserts both structural shape (`permissions` is a mapping, not a `read-all` string short-hand) and required-step-name presence in `steps[]`.

## Cross-phase caveat for T04

The canonical cosign verify-blob identity-URL pattern T03 ships is:

```
https://github.com/<canonical-repo>/.github/workflows/release.yml@refs/tags/v<version>
```

For `Build-Fractal/orchestrator` that resolves to `https://github.com/Build-Fractal/orchestrator/.github/workflows/release.yml@refs/tags/v<version>`. T04 (verify-installation operator doc) MUST mirror this pattern byte-identical when documenting the `cosign verify-blob --certificate-identity ...` invocation operators run to verify a downloaded `install.sh`. The identity-URL is bound to the workflow file path (`.github/workflows/release.yml`) AND the tag ref pattern (`refs/tags/v<version>`). Any drift between T03's signing identity and T04's verification identity makes verification fail end-to-end.

## Caveats

- **Signing block is currently scoped to the npm tarball** — P02 produces only the npm tarball at v0.9.2. The for-loop iterates over `release-artifacts/*` so P03 (homebrew bottle), P04 (curl-pipe-bash `install.sh`), and any future channel artifacts extend by dropping their artifact into the staging dir. T03 ships the signing block in a glob shape so future phases need NOT modify the loop.
- **Real OIDC issuance is not exercised by T03 verifier** — the verifier is grep-based static analysis of the workflow YAML. Real OIDC issuance (cosign sign-blob actually contacting Fulcio + Rekor under the GHA OIDC identity) only fires when the canonical repo (`Build-Fractal/orchestrator`) sees a v* tag-push event. T05 acceptance test exercises the cosign verify-blob path against a fixture install.sh + .sig + .pem + SHA256SUMS quartet under default-OFF live mode ([M030](../../../../../milestones/M030/index.md) P03 live-LLM precedent — verifier passes via `SKIP:` for the cosign live-verify path unless the operator opts in via env var).
- **REPO_ROOT not exported by run-probe.sh** — same paper-cut P02 T01/T02/T05 hit. T03 staged probe applies the same parameter-expansion-fallback workaround. Recommended follow-up: either export REPO_ROOT in `scripts/util/run-probe.sh` or update its docstring to make the contract explicit. Captured here to keep the paper-cut visible until resolved.
- **secrets.GITHUB_TOKEN is the default GHA token** — no secret-management ceremony required, and it is scoped per-job by GHA's permissions model. The job-level `permissions: contents: write` override grants the scope `gh release create` needs; `pr-validate` inherits workflow-level `contents: read` and cannot create releases even if it tried. CON-6 negative-assertion step in pr-validate (asserts no NPM_TOKEN access) is unchanged by T03 — that step lives in pr-validate's body, T03 only modifies npm-publish.
- **Out-of-scope-found**: none. T04 (verify-installation operator doc), T05 (acceptance battery + fixture quartet), T06 (phase-suite aggregator) are sibling tasks; T03 stays within its declared scope (workflow YAML extension + D004 + signing-shape verifier + YAML-validate probe).
