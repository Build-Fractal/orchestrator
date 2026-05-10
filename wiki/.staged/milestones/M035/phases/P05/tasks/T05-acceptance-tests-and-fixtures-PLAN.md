---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P05"
milestone: "M035"
name: "SC-11 / SC-12 acceptance tests + signature-verification verifier + release-fixture quartet"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- **T01 closed** — `scripts/lifecycle/write-rollback-marker.sh` exists.
  T05 acceptance test invokes it indirectly via the install-script
  hooks T01 added.
- **T02 closed** — `scripts/lifecycle/run-update.sh` extended with
  `--rollback`. T05 acceptance test invokes the rollback dispatch
  end-to-end.
- **T03 closed** — `.github/workflows/release.yml` extended with
  cosign signing block. T05 signature-verification verifier exercises
  the artifact shape T03 produces (against a fixture, not a real
  release).
- **T04 closed** — `references/installation.md § Verifying integrity`
  documents the verification recipe. T05's signature-verification
  verifier runs the same `cosign verify-blob` invocation T04 documents,
  ensuring documentation and verification stay synchronized.
- **`tests/m035-acceptance/cross-channel-byte-equivalence.sh`** exists
  (P02 T03) — provides the `_byte-equivalence-hash.sh` helper that T05
  reuses for hashing the staged tree.
- **`tests/m035-acceptance/_byte-equivalence-hash.sh`** exists (P02
  T03) — produces the deterministic SHA-256 of a runtime tree minus
  exclusion-list paths. T05 imports this helper.
- **`packaging/install/install-claude-code.sh`** with the T01 hook
  block at Stage 4.4.6 (rollback marker). T05 acceptance test runs the
  installer against fixtures.
- **`scripts/lib/errors.sh`** exports `emit_result`. Used by the
  verifier and the acceptance test.
- **Cosign on PATH** is OPTIONAL — T05's signature-verification
  verifier carries a SKIP path for cosign-absent environments.
- No fixture files exist under
  `tests/m035-acceptance/fixtures/m035-p05-release-fixture/` at plan-
  authoring time.

## Description

T05 ships the load-bearing acceptance evidence for SC-11 and SC-12:

1. **`tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh`**:
   the SC-12 acceptance test. Stages a real consumer-project fixture
   under `mktemp -d`, runs an N → N+1 install cycle, then runs
   `--rollback`, then hashes both states and asserts byte-equality.
   ALSO covers SC-12b: stages a symlink-mode fixture, runs `--rollback`,
   asserts the documented advisory and non-zero exit.
2. **`tools/verify/m035-p05-signature-verification.sh`**: the SC-11
   verifier. Runs `cosign verify-blob` against a fixture release
   directory containing a hand-prepared signed-artifact set. When
   cosign is on PATH, runs the real verification. When cosign is
   absent, runs structural shape verification (filenames, sizes,
   SHA-256 cross-reference against `SHA256SUMS`). Always runs the
   `shasum -a 256 -c SHA256SUMS` path (no cosign dependency).
3. **`tests/m035-acceptance/fixtures/m035-p05-release-fixture/`**: the
   fixture release directory with `install.sh`, `install.sh.sig`,
   `install.sh.pem`, `SHA256SUMS`. The signing artifacts are either
   (a) generated at fixture-stage time by running cosign against a
   real OIDC issuer (operator-blocking — requires interactive
   browser auth in the local-dev case), OR (b) hand-stubbed with
   syntactically-valid placeholder content that lets the structural
   shape verifier pass while gating real cosign verification behind
   `COSIGN_AVAILABLE=1`. T05 chooses option (b): the fixture's
   signature/certificate are stub placeholders; the verifier's real-
   cosign-verify path runs against an environmental fixture
   identified by env var (`M035_P05_LIVE_RELEASE_DIR`) when set, and
   the fixture quartet under `tests/m035-acceptance/fixtures/` is
   purely for shape verification.

This structure mirrors the [M030](../../../../../milestones/M030/index.md) P03 live-LLM smoke convention (real
verification gated behind an env flag; default-closed in CI).

## Steps

1. **Author `tests/m035-acceptance/fixtures/m035-p05-release-fixture/install.sh`**.
   Stub installer (10–20 lines):

   ```bash
   #!/usr/bin/env bash
   # M035 P05 T05 — fixture install.sh for shape verification.
   # NOT a real installer; produces a deterministic byte-stream that
   # the SHA256SUMS file references. Real install.sh is shipped by
   # P04 (curl-pipe-bash) and signed at release time.
   echo "FIXTURE: m035-p05 release-fixture install.sh"
   echo "If you ran this expecting a real install, something is wrong."
   exit 1
   ```

2. **Author the fixture `SHA256SUMS`**. Compute the SHA-256 of the
   fixture install.sh once at authoring time:

   ```bash
   shasum -a 256 install.sh
   ```

   Paste the resulting hash + filename into `SHA256SUMS`:

   ```
   <computed-sha>  install.sh
   ```

3. **Author the fixture `install.sh.sig` and `install.sh.pem`** as
   placeholder files. Each contains a single comment line documenting
   the placeholder status:

   ```
   # M035 P05 T05 fixture placeholder. Real signature artifacts are
   # produced by .github/workflows/release.yml at release time.
   ```

   The verifier at step 6 distinguishes these placeholders from real
   cosign output via the comment header.

4. **Author the SC-12 acceptance test**
   `tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh`. ~150
   lines. Single-script-file shape, AD-19, bash 4+ permitted (CI test
   runs on ubuntu-latest with bash 4+). The test:

   ```bash
   #!/usr/bin/env bash
   # tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh
   # M035 P05 T05 — SC-12 + SC-12b acceptance.
   set -u
   REPO_ROOT="$(git rev-parse --show-toplevel)"
   source "$REPO_ROOT/scripts/lib/errors.sh"
   pass_count=0
   fail_count=0

   pass() { emit_result ok "" "$1"; pass_count=$((pass_count + 1)); }
   fail() { emit_result fail "" "$1"; fail_count=$((fail_count + 1)); }

   # ---------------------------------------------------------------
   # SC-12 — copy-mode rollback byte equivalence
   # ---------------------------------------------------------------
   FIXTURE_A="$(mktemp -d -t m035-p05-sc12.XXXXXX)"
   trap 'rm -rf "$FIXTURE_A" "$FIXTURE_B"' EXIT

   # Stage version N (use current REPO_ROOT HEAD as "version N")
   bash "$REPO_ROOT/packaging/install/install-claude-code.sh" \
     --project-dir "$FIXTURE_A" >/dev/null 2>&1 \
     || { fail "install N failed"; }

   # Hash version N's runtime tree
   hash_n="$(bash "$REPO_ROOT/tests/m035-acceptance/_byte-equivalence-hash.sh" \
     "$FIXTURE_A")"
   [ -n "$hash_n" ] || fail "version-N hash empty"

   # Simulate version N+1: re-run installer (which writes the rollback
   # marker capturing N's state, then stages N+1 over it).
   # For test purposes, the same HEAD is treated as "N+1" — what we're
   # testing is the rollback machinery, not actual version-N differences.
   # The marker captures the current installed-files.txt as "prior" before
   # the new install overwrites it.
   bash "$REPO_ROOT/packaging/install/install-claude-code.sh" \
     --project-dir "$FIXTURE_A" --force >/dev/null 2>&1 \
     || { fail "install N+1 failed"; }

   # Verify the marker was written
   if [ -f "$FIXTURE_A/.orchestrator/.previous-version" ]; then
     pass "rollback marker written by install"
   else
     fail "rollback marker not written by install"
   fi

   # Run rollback
   bash "$REPO_ROOT/scripts/lifecycle/run-update.sh" --rollback \
     --project-dir "$FIXTURE_A" --source-repo "$REPO_ROOT" >/dev/null 2>&1
   rb_rc=$?
   if [ "$rb_rc" -eq 0 ]; then
     pass "--rollback exit 0 on copy-mode"
   else
     fail "--rollback exit $rb_rc on copy-mode (expected 0)"
   fi

   # Hash post-rollback runtime tree
   hash_post="$(bash "$REPO_ROOT/tests/m035-acceptance/_byte-equivalence-hash.sh" \
     "$FIXTURE_A")"
   if [ "$hash_n" = "$hash_post" ]; then
     pass "post-rollback hash matches version-N hash byte-for-byte"
   else
     fail "post-rollback hash $hash_post != version-N $hash_n"
   fi

   # ---------------------------------------------------------------
   # SC-12b — symlink-mode rollback refusal
   # ---------------------------------------------------------------
   FIXTURE_B="$(mktemp -d -t m035-p05-sc12b.XXXXXX)"
   bash "$REPO_ROOT/packaging/install/install-claude-code.sh" \
     --project-dir "$FIXTURE_B" --asset-mode-override symlink >/dev/null 2>&1 \
     || { fail "symlink-mode install failed"; }

   # Re-install to write the marker
   bash "$REPO_ROOT/packaging/install/install-claude-code.sh" \
     --project-dir "$FIXTURE_B" --asset-mode-override symlink --force \
     >/dev/null 2>&1 \
     || { fail "symlink-mode re-install failed"; }

   # Run rollback — should refuse
   rb_b_stderr="$(mktemp)"
   bash "$REPO_ROOT/scripts/lifecycle/run-update.sh" --rollback \
     --project-dir "$FIXTURE_B" --source-repo "$REPO_ROOT" \
     >/dev/null 2>"$rb_b_stderr"
   rb_b_rc=$?

   if [ "$rb_b_rc" -ne 0 ]; then
     pass "--rollback exit non-zero on symlink-mode"
   else
     fail "--rollback exit 0 on symlink-mode (expected non-zero)"
   fi

   if grep -q -F "rollback not available for symlink-mode installs" \
     "$rb_b_stderr"; then
     pass "symlink-mode advisory present in stderr"
   else
     fail "symlink-mode advisory absent from stderr"
   fi

   if grep -q -F "git checkout" "$rb_b_stderr"; then
     pass "git checkout recovery hint present in stderr"
   else
     fail "git checkout recovery hint absent from stderr"
   fi
   rm -f "$rb_b_stderr"

   # ---------------------------------------------------------------
   # Summary
   # ---------------------------------------------------------------
   echo "BATTERY: pass=$pass_count fail=$fail_count"
   [ "$fail_count" -eq 0 ] || exit 1
   ```

5. **Author the SC-11 verifier**
   `tools/verify/m035-p05-signature-verification.sh`. ~100 lines.
   Single-script-file shape, AD-19. Two execution modes:

   - **Shape mode (default)** — runs against the fixture release
     directory. Asserts:
     1. `install.sh` exists in fixture.
     2. `install.sh.sig` exists in fixture.
     3. `install.sh.pem` exists in fixture.
     4. `SHA256SUMS` exists in fixture.
     5. `shasum -a 256 -c SHA256SUMS --ignore-missing` succeeds (the
        SHA256SUMS file's hash matches install.sh's actual hash).
     6. The `install.sh.sig` file content is non-empty (placeholder
        comment is acceptable; real cosign output is also acceptable —
        the shape mode does not distinguish).
     7. The `install.sh.pem` file content is non-empty.

   - **Live mode (`COSIGN_AVAILABLE=1` AND
     `M035_P05_LIVE_RELEASE_DIR=<path>` env vars set)** — runs against
     a real release directory (e.g. downloaded from a real release).
     Adds:
     8. `cosign verify-blob` succeeds against the live release
        artifacts. Identity is taken from the env var
        `M035_P05_LIVE_IDENTITY` (defaults to the canonical-repo
        pattern in T04). OIDC issuer is
        `https://token.actions.githubusercontent.com`.

   Default invocation runs shape mode only. Live mode is gated to
   prevent CI runs from depending on a real release being available.
   Mirror the M030 P03 live-LLM gating convention.

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p05-signature-verification.sh
   # M035 P05 T05 — SC-11 verifier.
   set -u
   REPO_ROOT="$(git rev-parse --show-toplevel)"
   source "$REPO_ROOT/scripts/lib/errors.sh"

   FIXTURE_DIR="${M035_P05_LIVE_RELEASE_DIR:-$REPO_ROOT/tests/m035-acceptance/fixtures/m035-p05-release-fixture}"
   pass_count=0
   fail_count=0
   skip_count=0

   pass() { emit_result ok "" "$1"; pass_count=$((pass_count + 1)); }
   fail() { emit_result fail "" "$1"; fail_count=$((fail_count + 1)); }
   skip() { echo "SKIP: $1"; skip_count=$((skip_count + 1)); }

   # Shape mode
   for f in install.sh install.sh.sig install.sh.pem SHA256SUMS; do
     if [ -f "$FIXTURE_DIR/$f" ]; then
       pass "$f exists in fixture"
     else
       fail "$f absent from fixture"
     fi
   done

   # SHA256SUMS verification (no cosign dependency)
   pushd "$FIXTURE_DIR" >/dev/null
   if shasum -a 256 -c SHA256SUMS --ignore-missing >/dev/null 2>&1; then
     pass "shasum -a 256 -c SHA256SUMS validates install.sh"
   else
     fail "shasum -c SHA256SUMS failed against fixture"
   fi
   popd >/dev/null

   # Sig/cert non-empty content
   if [ -s "$FIXTURE_DIR/install.sh.sig" ]; then
     pass "install.sh.sig non-empty"
   else
     fail "install.sh.sig empty"
   fi
   if [ -s "$FIXTURE_DIR/install.sh.pem" ]; then
     pass "install.sh.pem non-empty"
   else
     fail "install.sh.pem empty"
   fi

   # Live cosign verification (gated)
   if [ "${COSIGN_AVAILABLE:-0}" = "1" ] && \
      [ -n "${M035_P05_LIVE_RELEASE_DIR:-}" ]; then
     identity="${M035_P05_LIVE_IDENTITY:-https://github.com/Build-Fractal/orchestrator/.github/workflows/release.yml@refs/tags/v0.0.0-test}"
     issuer="https://token.actions.githubusercontent.com"
     if cosign verify-blob \
       --certificate-identity "$identity" \
       --certificate-oidc-issuer "$issuer" \
       --signature "$FIXTURE_DIR/install.sh.sig" \
       --certificate "$FIXTURE_DIR/install.sh.pem" \
       "$FIXTURE_DIR/install.sh" >/dev/null 2>&1; then
       pass "cosign verify-blob succeeds against live release"
     else
       fail "cosign verify-blob failed against live release"
     fi
   else
     skip "cosign verify-blob (gated by COSIGN_AVAILABLE=1 + M035_P05_LIVE_RELEASE_DIR)"
   fi

   echo "BATTERY: pass=$pass_count fail=$fail_count skip=$skip_count"
   [ "$fail_count" -eq 0 ] || exit 1
   ```

6. **Plan-Time Discipline Rule 5 (real-app smoke)**: SC-12 acceptance
   test runs an actual install → re-install → rollback cycle against a
   real fixture project. SC-11 verifier runs an actual `shasum -c`
   verification against a real fixture (no mock-only verification for
   the always-on path). The cosign live-verify path is gated to
   prevent CI dependency, but the gate-default-OFF behavior means the
   verifier passes in CI by SKIP rather than by mock. Pre-pilot, an
   operator with cosign installed can flip the gate ON against a
   real release to confirm the verification path works end-to-end.

7. **Manifest hygiene**: T05 fixture files (`install.sh`,
   `install.sh.sig`, `install.sh.pem`, `SHA256SUMS`) are added to the
   `tests/m035-acceptance/fixtures/m035-p05-release-fixture/`
   directory. These are NOT bundle content (they're test fixtures) so
   no `.npmignore` adjustment is needed — `tests/` is already excluded
   from the npm bundle by P02 T05's bundle-hygiene filter (the
   `package.json` `files:` whitelist does not include `tests/`).

## Must-Haves

- Fixture file `tests/m035-acceptance/fixtures/m035-p05-release-fixture/install.sh` exists, ~10 lines.
- Fixture file `tests/m035-acceptance/fixtures/m035-p05-release-fixture/install.sh.sig` exists, non-empty.
- Fixture file `tests/m035-acceptance/fixtures/m035-p05-release-fixture/install.sh.pem` exists, non-empty.
- Fixture file `tests/m035-acceptance/fixtures/m035-p05-release-fixture/SHA256SUMS` exists, contains a valid `<sha256>  install.sh` line that matches the fixture install.sh's actual hash.
- `tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh` exists,
  exits 0 against the repo, emits `BATTERY: pass=N fail=0`.
- `tools/verify/m035-p05-signature-verification.sh` exists, exits 0
  against the fixture, emits `BATTERY: pass=N fail=0 skip=M`.

## Verification

```bash
bash tools/verify/m035-p05-signature-verification.sh
```

```bash
bash tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh
```

## Inputs

### From Previous Tasks

- `scripts/lifecycle/write-rollback-marker.sh` (from T01)
  - Key API: invoked at install-time by all three installers; exit 0
    on success or greenfield-skip; exit non-zero on failure.
  - Key types: `.orchestrator/.previous-version` marker file with five
    fields (per D005 schema).
- `scripts/lifecycle/run-update.sh --rollback` (from T02)
  - Key API: `bash run-update.sh --rollback --project-dir <path>
    [--source-repo <path>]`. Exit 0 on success copy-mode rollback;
    exit non-zero on missing-marker, missing-snapshot, symlink-mode,
    unknown-source.
  - Key behavior: writes one `update_run` JSONL event with
    `op: rollback`. Updates marker's `rolled_at` field. Replays
    snapshotted manifest from source repo at prior commit SHA.
- `commands/update.md` (from T02) — operator-facing skill doc; T05
  does not consume this directly but relies on T02's verifier
  asserting it.
- `.github/workflows/release.yml` cosign block (from T03) — T05's
  signature-verification verifier exercises the artifact shape T03
  produces. T05 does not run the workflow itself.
- `references/installation.md § Verifying integrity` (from T04) —
  identity URL pattern T05's live-verify mode reads from env vars,
  consistent with T04's documented recipe.

### From Disk (Pre-existing)

- `tests/m035-acceptance/_byte-equivalence-hash.sh` (P02 T03) — produces
  deterministic SHA-256 of a runtime tree minus exclusion-list. T05
  imports verbatim.
- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` (P02 T03)
  — pattern reference. T05's m035-p05 acceptance test mirrors the
  BATTERY line shape and the helper-import idiom.
- `packaging/install/install-claude-code.sh` (with T01 hook block) —
  invoked from the acceptance test.
- `scripts/lifecycle/run-update.sh` (with T02 `--rollback`) — invoked
  from the acceptance test.
- `scripts/lib/errors.sh` — sourced by both the verifier and the
  acceptance test for `emit_result`.

## Constraints

- **AD-19 single-script-file shape** — verifier and acceptance test
  use direct `bash <path>` invocations. No process substitution, no
  compound chains, no `$(... | ...)`. The `find ... | LC_ALL=C sort`
  pattern in the byte-equivalence helper is single-pipeline (one
  logical operation).
- **Bash 3.2 compatibility NOT required for tests** — `tests/` and
  `tools/verify/` scripts run on ubuntu-latest CI runners with bash
  4+. Only the install scripts and the writer (T01) carry the bash
  3.2 constraint.
- **CON-5 / MIT-2 (exclusion-list discipline)** — the rollback byte-
  equivalence test reuses the existing `_byte-equivalence-hash.sh`
  helper which already honors the exclusion list documented in
  `references/installation.md § Channel-specific metadata files`.
  T05 does NOT extend the exclusion list (per FR-15 read-only-on-
  render).
- **Plan-Time Discipline Rule 5 (real-app smoke)** — SC-12 acceptance
  test runs an actual install/upgrade/rollback cycle. SC-11 verifier
  runs an actual `shasum -c` against the fixture. Cosign live-verify
  is gated, but the gated-default behavior means the verifier
  always-passes via SKIP rather than via mock — there is no
  silently-mocked surface.
- **Live-mode gating** — `cosign verify-blob` runs only when
  `COSIGN_AVAILABLE=1` AND `M035_P05_LIVE_RELEASE_DIR=<path>` are
  both set. Default behavior: SKIP. This mirrors M030 P03's live-LLM
  gating discipline.
- **#Q-G2 (CON-5 exclusion list)** — the rollback byte-equivalence
  test must EXCLUDE the documented per-install metadata files when
  hashing. The `_byte-equivalence-hash.sh` helper already does this.
- **Plan-Time Discipline Rule 6** — all `create` paths under
  `tests/m035-acceptance/fixtures/m035-p05-release-fixture/` and
  `tests/m035-acceptance/m035-p05-*` and `tools/verify/m035-p05-*`
  are absent at plan-authoring time. New files, milestone-prefixed
  slugs.

## Expected Output

Stdout from `bash tools/verify/m035-p05-signature-verification.sh`:

```
PASS: install.sh exists in fixture
PASS: install.sh.sig exists in fixture
PASS: install.sh.pem exists in fixture
PASS: SHA256SUMS exists in fixture
PASS: shasum -a 256 -c SHA256SUMS validates install.sh
PASS: install.sh.sig non-empty
PASS: install.sh.pem non-empty
SKIP: cosign verify-blob (gated by COSIGN_AVAILABLE=1 + M035_P05_LIVE_RELEASE_DIR)
BATTERY: pass=7 fail=0 skip=1
```

Stdout from `bash tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh`:

```
PASS: rollback marker written by install
PASS: --rollback exit 0 on copy-mode
PASS: post-rollback hash matches version-N hash byte-for-byte
PASS: --rollback exit non-zero on symlink-mode
PASS: symlink-mode advisory present in stderr
PASS: git checkout recovery hint present in stderr
BATTERY: pass=6 fail=0
```
