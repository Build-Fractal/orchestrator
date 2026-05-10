---
schema_version: "1.0"
type: phase-plan
phase: "P05"
milestone: "M035"
goal: "Install-script integrity — sigstore (cosign keyless) signatures + SHA-256 checksums in the release pipeline + .orchestrator/.previous-version rollback marker contract + orchestrator:update --rollback dispatch with byte-for-byte revert (copy mode) and symlink-mode refusal advisory (#Q-G8)."
demo_sentence: "`bash tools/verify/m035-p05-signature-verification.sh <fixture-release-dir>` succeeds — `cosign verify-blob --certificate-identity-regexp '.*' --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' --signature install.sh.sig --certificate install.sh.pem install.sh` returns 0 and `shasum -a 256 -c SHA256SUMS` returns 0 (SC-11); `bash tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh` against a copy-mode fixture upgraded N→N+1 then `bash scripts/lifecycle/run-update.sh --rollback` produces a runtime tree whose SHA-256 matches the version-N install byte-for-byte (SC-12); the same script against a symlink-mode fixture exits non-zero with the documented `rollback not available for symlink-mode installs` advisory."
risk: "high"
depends_on: ["P02"]
---

## Plan-Phase-Resolved Open Questions (AD-7)

These resolve at this plan-phase per AD-7 / spec routing. They land as
design constraints in the task plans below.

- **Spec #Q-4 (signing-strategy: sigstore keyless vs project GPG)** →
  **sigstore (cosign keyless) primary; SHA-256 published alongside as a
  tooling-free fallback verification path**. Rationale:
  1. **CON-6 alignment** — keyless signing eliminates the GPG private-key
     management blast-radius (no key rotation, no expiry, no `secrets.GPG_KEY`
     to leak). The signing identity is the GitHub Actions OIDC token,
     scoped to the canonical-repo `v*` tag-push event by the same job-
     condition that already gates `secrets.NPM_TOKEN` (CON-6 defense-in-depth
     pattern carries over).
  2. **Verifiability without project-specific bootstrapping** — operators
     verify with stock `cosign` against the public Sigstore Rekor
     transparency log. No "import this key from this URL" step. Verification
     identity is `https://github.com/Build-Fractal/orchestrator/.github/workflows/release.yml@refs/tags/v<version>`,
     a cryptographic statement of provenance.
  3. **Tooling-free fallback** — every release also publishes a `SHA256SUMS`
     file covering all artifacts. Operators without `cosign` installed can
     verify integrity with stock `shasum -a 256 -c SHA256SUMS`. Both surfaces
     ship together; SC-11 asserts both.
  Recorded as **D004** (`M035/P05 convention`, appended at T03).
  Bound to FR-11 / SC-11.

- **Dispatch-context #Q-4 (rollback marker storage)** →
  **`.orchestrator/.previous-version` is a structured `key=value` sidecar
  recording prior version's metadata; the prior install's
  `installed-files.txt` is snapshotted to
  `.orchestrator/.rollback/manifest-<prior-version>.txt` for replay.**
  Schema:
  ```
  prior_version=<X.Y.Z>
  prior_commit_sha=<short-sha-or-empty>
  prior_manifest_path=.orchestrator/.rollback/manifest-<prior-version>.txt
  prior_install_mode=<copy|symlink>
  rolled_at=<empty until --rollback runs>
  ```
  Rationale: the manifest snapshot is the load-bearing artifact for byte-
  equivalent revert (it carries the per-asset `mode:` field that M035 P01
  added per FR-1/FR-2). Snapshotting the manifest at upgrade time — not
  reconstructing it at rollback time from git history — is constitutionally
  required because the rollback must succeed even when the source repo is
  unreachable (e.g. `update_source: npm` upgrades against a published
  tarball with no local clone). The `prior_install_mode` field bootstraps
  #Q-G8's symlink-mode refusal: `rollback not available for symlink-mode
  installs` fires from a single field check.
  Recorded as **D005** (`M035/P05 convention`, appended at T01).
  Bound to FR-12 / SC-12 / #Q-G8.

- **#Q-G8 (rollback semantics for symlink-mode)** → **symlink-mode rollback
  is unsupported; exits non-zero with the documented advisory** per the
  spec amendment. The `prior_install_mode=symlink` field check in T02 is
  the single point of enforcement. SC-12b acceptance covers the advisory
  path. Bound by spec amendment; no new D-row needed.

## Must-Haves

### Truths

- `.orchestrator/.previous-version` is written by every install/update
  invocation (per the FR-12 contract) before the new manifest is staged.
  The file carries the load-bearing schema fields: `prior_version=`,
  `prior_commit_sha=`, `prior_manifest_path=`, `prior_install_mode=`.
  When `prior_install_mode=symlink`, `prior_manifest_path=` is still
  populated (for completeness) but `--rollback` will refuse before
  consulting it.
  - Check: `bash tools/verify/m035-p05-rollback-marker-shape.sh`

- `.orchestrator/.rollback/manifest-<prior-version>.txt` is a verbatim
  snapshot of the prior install's `.orchestrator/installed-files.txt`,
  written by every install/update transition. Snapshot lifecycle: written
  at install-time before the new install replaces `installed-files.txt`;
  reused on subsequent installs (the M035 install-meta.txt + manifest
  pair drives the snapshot — first install with no `.previous-version`
  writes nothing, second install snapshots first install's manifest, etc.).
  - Check: `bash tools/verify/m035-p05-rollback-snapshot-presence.sh`

- `scripts/lifecycle/run-update.sh --rollback` reads
  `.orchestrator/.previous-version`, validates `prior_install_mode`, and
  replays the snapshotted manifest to revert the runtime tree to the
  prior install's exact byte-state (copy-mode) or refuses with the
  documented advisory and exit non-zero (symlink-mode, #Q-G8). Missing
  marker exits non-zero with "no prior version recorded — rollback
  unavailable" (Edge Cases enumeration).
  - Check: `bash tools/verify/m035-p05-rollback-driver-shape.sh`

- `commands/update.md` documents the `--rollback` flag, the symlink-mode
  refusal, and the missing-marker behavior; the documentation references
  `.orchestrator/.previous-version` and the snapshot path
  `.orchestrator/.rollback/`.
  - Check: `bash tools/verify/m035-p05-update-skill-doc-shape.sh`

- `.github/workflows/release.yml`'s `npm-publish` job is extended with a
  signing pass that runs **after** `npm publish` succeeds and **before**
  `Confirm publish succeeded`: `cosign sign-blob --yes --output-signature
  install.sh.sig --output-certificate install.sh.pem <each-release-artifact>`
  for every artifact slated for upload to the GitHub release. A
  `SHA256SUMS` file is generated covering all release artifacts. Both
  signature artifacts and `SHA256SUMS` are uploaded to the GitHub release
  via `gh release upload`. The signing block carries `permissions: id-token:
  write` (OIDC for keyless cosign) at the job level. CON-6 / D004 binding.
  - Check: `bash tools/verify/m035-p05-release-workflow-signing-shape.sh`

- `tools/verify/m035-p05-signature-verification.sh` runs end-to-end against
  a fixture release directory (`tests/m035-acceptance/fixtures/m035-p05-release-fixture/`)
  containing a hand-signed `install.sh` + `install.sh.sig` + `install.sh.pem`
  + `SHA256SUMS` quartet (or a stub that emulates the cosign verify-blob
  contract under `COSIGN_AVAILABLE=0` mode). When `cosign` is on PATH the
  verifier runs the real `cosign verify-blob` invocation; when absent it
  emits `SKIP: cosign not on PATH — running shape-verification only` and
  validates the artifact set's structural shape (filenames, sizes, SHA-256
  cross-reference). Always validates `shasum -a 256 -c SHA256SUMS` against
  the fixture (no cosign dependency).
  - Check: `bash tools/verify/m035-p05-signature-verification.sh`

- `tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh` exercises
  SC-12 end-to-end against a copy-mode fixture: stage version N, snapshot
  its hash, run `run-update.sh` to upgrade to version N+1, run `run-update.sh
  --rollback`, hash again, assert byte-equality with the version-N hash
  (excluding the documented metadata files per CON-5 / MIT-2). Also covers
  SC-12b: stage a symlink-mode fixture, run `run-update.sh --rollback`,
  assert non-zero exit + advisory message contains `symlink-mode` + the
  documented `git checkout` recovery hint.
  - Check: `bash tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh`

- `references/installation.md` is extended with `## Verifying integrity`
  documenting the cosign verification recipe, the SHA-256 fallback recipe,
  the keyless-signing identity URL pattern, and the recovery procedure
  when verification fails. Operator-facing copy is self-sufficient.
  - Check: `bash tools/verify/m035-p05-installation-doc-verifying-integrity.sh`

- The phase-suite aggregator `tools/verify/m035-p05-phase-suite.sh` exists
  and runs every per-truth verifier above in sequence, emitting `PASS:` /
  `FAIL:` lines plus a `BATTERY: pass=N fail=0 skip=M` summary line
  (matching the [M030](../../../../milestones/M030/index.md) / [M032](../../../../milestones/M032/index.md) / [M029](../../../../milestones/M029/index.md) / [M037](../../../../milestones/M037/index.md) / P02 acceptance-battery line
  shape; `skip` is added because the cosign-availability axis can SKIP).
  - Check: `bash tools/verify/m035-p05-phase-suite.sh`

### Artifacts

- `scripts/lifecycle/write-rollback-marker.sh` (min 50 lines, contains
  `prior_version=` AND `prior_install_mode=`) — new; bash 3.2 + POSIX-sh.
- `packaging/install/install-claude-code.sh` (modified — contains
  `write-rollback-marker.sh`)
- `packaging/install/install-codex.sh` (modified — contains
  `write-rollback-marker.sh`)
- `packaging/install/install-cursor.sh` (modified — contains
  `write-rollback-marker.sh`)
- `scripts/lifecycle/run-update.sh` (modified — contains `--rollback`
  AND `prior_install_mode` AND `symlink-mode`)
- `commands/update.md` (modified — contains `--rollback` AND
  `.previous-version`)
- `.github/workflows/release.yml` (modified — contains `cosign sign-blob`
  AND `id-token: write` AND `SHA256SUMS`)
- `references/installation.md` (modified — contains
  `## Verifying integrity` AND `cosign verify-blob` AND `shasum -a 256 -c`)
- `tools/verify/m035-p05-rollback-marker-shape.sh` (min 30 lines, contains
  `BATTERY:`)
- `tools/verify/m035-p05-rollback-snapshot-presence.sh` (min 25 lines,
  contains `BATTERY:`)
- `tools/verify/m035-p05-rollback-driver-shape.sh` (min 40 lines, contains
  `BATTERY:`)
- `tools/verify/m035-p05-update-skill-doc-shape.sh` (min 25 lines, contains
  `BATTERY:`)
- `tools/verify/m035-p05-release-workflow-signing-shape.sh` (min 40 lines,
  contains `BATTERY:`)
- `tools/verify/m035-p05-signature-verification.sh` (min 60 lines,
  contains `BATTERY:` AND `cosign verify-blob`)
- `tools/verify/m035-p05-installation-doc-verifying-integrity.sh` (min 25
  lines, contains `BATTERY:`)
- `tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh` (min 100
  lines, contains `BATTERY:` AND `symlink-mode`)
- `tests/m035-acceptance/fixtures/m035-p05-release-fixture/install.sh`
  (min 5 lines)
- `tests/m035-acceptance/fixtures/m035-p05-release-fixture/SHA256SUMS`
  (min 1 line)
- `tools/verify/m035-p05-phase-suite.sh` (min 30 lines, contains `BATTERY:`)

### Key Links

- `commands/update.md` → `scripts/lifecycle/run-update.sh` (skill →
  driver dispatch, extended with `--rollback`)
- `scripts/lifecycle/run-update.sh` → `scripts/lifecycle/write-rollback-marker.sh`
  (driver invokes marker writer; AD-19 single-script delegation)
- `packaging/install/install-claude-code.sh` →
  `scripts/lifecycle/write-rollback-marker.sh` (install-time marker write)
- `packaging/install/install-codex.sh` →
  `scripts/lifecycle/write-rollback-marker.sh` (install-time marker write)
- `packaging/install/install-cursor.sh` →
  `scripts/lifecycle/write-rollback-marker.sh` (install-time marker write)
- `references/installation.md` → `cosign` (operator verification recipe)
- `.github/workflows/release.yml` → `cosign` (CI signing step)
- `tools/verify/m035-p05-phase-suite.sh` →
  `tools/verify/m035-p05-rollback-marker-shape.sh` (aggregator → unit)

## Tasks

### T01: Rollback-marker contract — schema + writer + install-script integration

See `tasks/T01-rollback-marker-contract-PLAN.md`.

### T02: `--rollback` dispatch — `run-update.sh` + `commands/update.md`

See `tasks/T02-rollback-dispatch-PLAN.md`.

### T03: Sigstore signing + SHA-256 checksums in release.yml

See `tasks/T03-sigstore-signing-release-workflow-PLAN.md`.

### T04: `references/installation.md § Verifying integrity` operator-facing recipe

See `tasks/T04-installation-doc-verifying-integrity-PLAN.md`.

### T05: SC-11 / SC-12 acceptance tests + verifiers + fixtures

See `tasks/T05-acceptance-tests-and-fixtures-PLAN.md`.

### T06: Phase-suite aggregator

See `tasks/T06-phase-suite-aggregator-PLAN.md`.

## Task Dependencies

```
T01 (marker contract) → T02 (dispatch) ─┐
T01 (marker contract) ─────────────────┤
T03 (signing in release.yml) ──────────┼→ T05 (acceptance + verifiers) → T06 (phase-suite)
T04 (installation.md doc) ─────────────┘
```

T01 and T03 and T04 have no inter-dependencies and can be authored in
parallel. T02 reads the marker contract authored by T01 (must run after).
T05 reads all four upstream surfaces (marker shape from T01, dispatch
shape from T02, workflow signing shape from T03, doc shape from T04). T06
chains every per-truth verifier scheduled across T01–T05.

## Files Likely Touched

- `scripts/lifecycle/write-rollback-marker.sh` (create)
- `scripts/lifecycle/run-update.sh` (modify)
- `packaging/install/install-claude-code.sh` (modify)
- `packaging/install/install-codex.sh` (modify)
- `packaging/install/install-cursor.sh` (modify)
- `commands/update.md` (modify)
- `.github/workflows/release.yml` (modify)
- `references/installation.md` (modify)
- [`.orchestrator/DECISIONS.md`](../../../../decisions.md) (modify — D004 sigstore-keyless, D005 rollback-marker-schema)
- `tools/verify/m035-p05-rollback-marker-shape.sh` (create)
- `tools/verify/m035-p05-rollback-snapshot-presence.sh` (create)
- `tools/verify/m035-p05-rollback-driver-shape.sh` (create)
- `tools/verify/m035-p05-update-skill-doc-shape.sh` (create)
- `tools/verify/m035-p05-release-workflow-signing-shape.sh` (create)
- `tools/verify/m035-p05-signature-verification.sh` (create)
- `tools/verify/m035-p05-installation-doc-verifying-integrity.sh` (create)
- `tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh` (create)
- `tests/m035-acceptance/fixtures/m035-p05-release-fixture/install.sh` (create)
- `tests/m035-acceptance/fixtures/m035-p05-release-fixture/install.sh.sig` (create)
- `tests/m035-acceptance/fixtures/m035-p05-release-fixture/install.sh.pem` (create)
- `tests/m035-acceptance/fixtures/m035-p05-release-fixture/SHA256SUMS` (create)
- `tools/verify/m035-p05-phase-suite.sh` (create)

## Notes

**Plan-Time Discipline checks performed:**

- Rule 1 (Prerequisite-existence): `package.json`, `bin/orchestrator`,
  `packaging/npm/postinstall.sh`, `.github/workflows/release.yml`,
  `tests/m035-acceptance/cross-channel-byte-equivalence.sh`,
  `references/installation.md`, `scripts/lifecycle/run-update.sh`,
  `commands/update.md`, `packaging/install/install-claude-code.sh`,
  `packaging/install/install-codex.sh`,
  `packaging/install/install-cursor.sh` all confirmed present
  on disk at plan-authoring time.
- Rule 2 (Verifier-availability): every `Check:` command in this plan
  references a `tools/verify/m035-p05-*.sh` script that is scheduled as
  a deliverable inside this phase's task plans (T01 through T06). No
  cross-task verifier dependency that would deadlock auto-loop. T05's
  signature-verification verifier and the rollback acceptance test both
  carry `SKIP:` paths for missing-cosign / no-baseline scenarios so the
  verifier shape doesn't depend on environmental tooling.
- Rule 3 (Classifier-shape): all proposed `Check:` commands use the
  single-script-file shape per AD-19 (`bash tools/verify/<...>` /
  `bash tests/m035-acceptance/<...>`). No compound chains, no
  `$(...)` containing pipes, no plain subshells. The `cosign sign-blob`
  block in `.github/workflows/release.yml` runs inside a YAML pipe block
  scalar (single-script-shape per AP-009 / P02 T04 precedent). The
  `cosign verify-blob` invocation in the verifier runs as a plain
  command with whitespace-separated flag arguments (no inline compound).
- Rule 4 (run-probe.sh scope): every verifier scheduled here is a
  repo-resident `tools/verify/m035-p05-*.sh` invoked directly via
  `bash tools/verify/<path>`. `run-probe.sh` is reserved for the
  `/tmp/`-staged fixture-construction probes referenced inside T05.
- Rule 5 (real-DB / real-app smoke): T05's
  `m035-p05-rollback-byte-equivalence.sh` runs an actual install →
  upgrade → rollback cycle against a real fixture project, hashes the
  staged tree, and asserts byte-equality. The signature-verification
  verifier runs a real `cosign verify-blob` invocation when `cosign` is
  on PATH (no mock-only verification). Mock-only is used ONLY for the
  cosign-absent SKIP path (which validates artifact-shape rather than
  cryptographic claim).
- Rule 6 (Path-collision): `ls -la` performed against every `create`
  path enumerated in `## Files Likely Touched`. All `tools/verify/m035-p05-*.sh`
  filenames are absent from disk. `scripts/lifecycle/write-rollback-marker.sh`
  is absent. `tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh`
  is absent. `tests/m035-acceptance/fixtures/m035-p05-release-fixture/`
  is absent. No collisions; all milestone-prefixed slugs.

**Expected verifier output shape:**

Every per-truth verifier emits `BATTERY: pass=N fail=N` (and `skip=M`
where applicable per the acceptance-battery convention). Phase-suite
aggregator chains all per-truth verifiers and emits `BATTERY: pass=8
fail=0 skip=K` summing across the eight per-truth verifiers.

**Risk areas worth flagging at execution time:**

1. **GitHub Actions OIDC permissions block** — adding `permissions:
   id-token: write` at the job level requires the workflow's top-level
   `permissions:` block to either be absent (default-permissive) or
   explicitly enumerate `id-token: write` at the workflow level. P02's
   `release.yml` declares `permissions: contents: read` at the workflow
   level, which suppresses the default `id-token: write`. T03 must
   either elevate at the workflow level OR override at the job level
   (the latter is preferred for least-privilege). T03 verifier asserts
   the override at the job level.
2. **Sigstore Rekor transparency-log retention** — keyless cosign
   signatures are bound to the GitHub Actions OIDC identity at the
   moment of signing. The verification recipe in T04 must use
   `--certificate-identity-regexp` rather than a fixed identity URL
   because the workflow path varies across forks during testing.
   Production verification uses `--certificate-identity` with the
   exact `https://github.com/Build-Fractal/orchestrator/.github/workflows/release.yml@refs/tags/v<version>`.
3. **Rollback marker absence on first install** — T01 writes the marker
   only when `installed-files.txt` already exists at install-start time
   (i.e. this is an upgrade). Greenfield first installs leave
   `.previous-version` absent. T02's `--rollback` returns the documented
   "no prior version recorded" message + non-zero exit. Acceptance test
   covers this branch.
4. **Symlink-mode rollback advisory exact wording** — #Q-G8's spec
   amendment specifies the literal advisory text. T02 emits it
   verbatim; T05 acceptance test pattern-matches against the same
   verbatim string. If the operator-facing copy changes, all three
   must change in lockstep.
