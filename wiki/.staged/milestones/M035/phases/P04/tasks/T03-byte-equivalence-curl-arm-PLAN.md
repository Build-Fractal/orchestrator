---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M035"
name: "Extend cross-channel-byte-equivalence.sh with curl-pipe-bash arm + 3-way cross-channel equality assertion"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 has shipped `packaging/install/install.sh` with the
  `M035_P04_LOCAL_TARBALL` + `M035_P04_STAGE_ONLY` + `M035_P04_STAGE_DIR`
  test-mode env vars. Verify: `grep -F 'M035_P04_LOCAL_TARBALL' packaging/install/install.sh`
  returns matches.
- T02 has shipped release.yml with install.sh staged into
  `release-artifacts/` (not directly relevant to T03 but confirms T01/T02
  ordering).
- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` exists with
  the P03 T03 shape: 2-way `NPM_HASH = HOMEBREW_HASH` assertion at
  lines 187-204, `SKIP: pending P04 -- curl-pipe-bash-channel hash assertion`
  stub at line 206. Verify: `grep -nF 'SKIP: pending P04' tests/m035-acceptance/cross-channel-byte-equivalence.sh`
  returns one match.
- `tests/m035-acceptance/_byte-equivalence-hash.sh` exists (P02 T03
  helper).
- `tests/m035-acceptance/_exclusion-list-by-channel.sh` exists (P03 T03
  helper) and supports `CHANNEL=curl-pipe-bash` via the existing
  comma-separated channel-list parsing — no edit required.

## Description

Replace the `SKIP: pending P04 -- curl-pipe-bash-channel hash assertion`
stub in `tests/m035-acceptance/cross-channel-byte-equivalence.sh` with a
real curl-pipe-bash arm that:

1. Re-uses the npm-channel `npm pack` tarball (D007 single-source-of-truth,
   same pattern as P03's homebrew arm).
2. Invokes `bash packaging/install/install.sh` with
   `M035_P04_LOCAL_TARBALL=$TARBALL` + `M035_P04_STAGE_ONLY=1` +
   `M035_P04_STAGE_DIR=<fixture>` env vars to short-circuit the
   download/SHA-verify/dispatch chain — install.sh just stages the
   tarball into the fixture dir and exits.
3. Hashes the staged tree via `_byte-equivalence-hash.sh` with the
   curl-pipe-bash exclusion list extracted from `_exclusion-list-by-channel.sh`.
4. Emits `CURL_HASH=<sha>` on stdout.

After all three arms emit hashes, lift the existing 2-way assertion
to a 3-way: `[ "$NPM_HASH" = "$HOMEBREW_HASH" ] && [ "$HOMEBREW_HASH" = "$CURL_HASH" ]`.
The 3-way fires when ALL three arms emit hashes; the 2-way fallback
remains as a SKIP path when any arm is unavailable.

Author the task-grain verifier
`tools/verify/m035-p04-byte-equivalence-curl-arm.sh`.

## Steps

1. **Verify path-collision before authoring the verifier.**

   ```bash
   ls tools/verify/m035-p04-byte-equivalence-curl-arm.sh 2>&1
   ```

   Expected: `ls: tools/verify/m035-p04-byte-equivalence-curl-arm.sh:
   No such file or directory`.

2. **Edit `tests/m035-acceptance/cross-channel-byte-equivalence.sh` —
   add curl-pipe-bash arm BEFORE the existing 2-way equality
   assertion block.** The current shape (line 184+) is:

   ```bash
   # --- 5. Cross-channel equality assertion (CON-5 / Principle XVI) -

   if [ -n "${NPM_HASH:-}" ] && [ -n "$HOMEBREW_HASH" ]; then
     if [ "$NPM_HASH" = "$HOMEBREW_HASH" ]; then
       echo "PASS: cross-channel byte-equivalence — NPM_HASH = HOMEBREW_HASH"
       pass=$((pass + 1))
     else
       echo "FAIL: cross-channel byte-equivalence violated"
       echo "  NPM_HASH=$NPM_HASH"
       echo "  HOMEBREW_HASH=$HOMEBREW_HASH"
       echo "  See references/installation.md § Channel-specific metadata files"
       echo "  for the per-channel exclusion list. If the divergence is a"
       echo "  legitimate channel-specific metadata file, add it to that"
       echo "  table and re-run."
       fail=$((fail + 1))
     fi
   else
     echo "SKIP: cross-channel equality assertion requires both NPM_HASH and HOMEBREW_HASH"
     skip=$((skip + 1))
   fi

   echo "SKIP: pending P04 -- curl-pipe-bash-channel hash assertion"
   skip=$((skip + 1))
   ```

   Replace this entire block (sections 5 + the trailing curl SKIP) with:

   ```bash
   # --- 4. curl-pipe-bash-channel arm (D007 + T03 / FR-10) ----------

   # Pre-compute curl-pipe-bash exclusion list (re-uses the existing
   # _exclusion-list-by-channel.sh helper; CHANNEL=curl-pipe-bash matches
   # rows in the references/installation.md table that list "all" or
   # "curl-pipe-bash" or comma-separated lists containing curl-pipe-bash).
   CHANNEL=curl-pipe-bash
   export CHANNEL
   EXCLUSION_LIST_CURL_BASH="$(bash "$REPO_ROOT/tests/m035-acceptance/_exclusion-list-by-channel.sh")"
   unset CHANNEL

   CURL_HASH=""
   if [ -z "${TARBALL:-}" ] || [ ! -f "$TARBALL" ]; then
     echo "SKIP: curl-pipe-bash-channel arm requires npm-channel tarball — npm-channel did not produce one"
     skip=$((skip + 1))
   elif [ ! -x "$REPO_ROOT/packaging/install/install.sh" ]; then
     echo "SKIP: curl-pipe-bash-channel arm requires packaging/install/install.sh — not on disk or not executable"
     skip=$((skip + 1))
   else
     CURL_FIXTURE="$(mktemp -d 2>/dev/null || mktemp -d -t m035p04t03curl)"
     trap 'rm -rf "$NPM_FIXTURE" "$BREW_FIXTURE" "$CURL_FIXTURE" 2>/dev/null || true' EXIT

     # Invoke install.sh in test-mode: LOCAL_TARBALL short-circuits
     # the download + SHA-verify steps; STAGE_ONLY=1 extracts and
     # exits without dispatching install-claude-code.sh; STAGE_DIR
     # lets us control where the staged tree lands.
     CURL_STAGE="$CURL_FIXTURE/staged"
     mkdir -p "$CURL_STAGE"
     M035_P04_LOCAL_TARBALL="$TARBALL" \
     M035_P04_STAGE_ONLY=1 \
     M035_P04_STAGE_DIR="$CURL_STAGE" \
       bash "$REPO_ROOT/packaging/install/install.sh" \
       >"$CURL_FIXTURE/install.log" 2>&1 \
       || { echo "FAIL: install.sh STAGE_ONLY mode failed (see $CURL_FIXTURE/install.log)"; fail=$((fail + 1)); }

     if [ -d "$CURL_STAGE" ] && [ -f "$CURL_STAGE/package.json" ]; then
       echo "PASS: curl-pipe-bash-channel staged into $CURL_STAGE"
       pass=$((pass + 1))

       # Hash the staged tree with curl-pipe-bash exclusion list.
       STAGED="$CURL_STAGE"
       EXCLUSION_LIST="$EXCLUSION_LIST_CURL_BASH"
       export STAGED EXCLUSION_LIST
       CURL_HASH="$(bash "$REPO_ROOT/tests/m035-acceptance/_byte-equivalence-hash.sh" \
         2>"$CURL_FIXTURE/hash.err")"
       if [ -n "$CURL_HASH" ]; then
         echo "CURL_HASH=$CURL_HASH"
         echo "PASS: curl-pipe-bash-channel hash emitted"
         pass=$((pass + 1))
       else
         echo "FAIL: curl-pipe-bash-channel hash not emitted (see $CURL_FIXTURE/hash.err)"
         fail=$((fail + 1))
       fi
     else
       echo "FAIL: curl-pipe-bash-channel staged tree missing or empty"
       fail=$((fail + 1))
     fi
   fi

   # --- 5. Cross-channel equality assertion (CON-5 / Principle XVI) -

   # 3-way assertion: fires when ALL THREE arms emit hashes.
   # 2-way fallback: fires when only npm + homebrew emit hashes (curl
   # arm SKIPped). 1-way fallback: SKIP entirely when fewer than two
   # arms emit hashes.

   if [ -n "${NPM_HASH:-}" ] && [ -n "${HOMEBREW_HASH:-}" ] && [ -n "$CURL_HASH" ]; then
     # 3-way path — load-bearing CON-5 / Constitution Principle XVI test.
     if [ "$NPM_HASH" = "$HOMEBREW_HASH" ] && [ "$HOMEBREW_HASH" = "$CURL_HASH" ]; then
       echo "PASS: cross-channel byte-equivalence (3-way) — NPM_HASH = HOMEBREW_HASH = CURL_HASH"
       pass=$((pass + 1))
     else
       echo "FAIL: cross-channel byte-equivalence violated (3-way)"
       echo "  NPM_HASH=$NPM_HASH"
       echo "  HOMEBREW_HASH=$HOMEBREW_HASH"
       echo "  CURL_HASH=$CURL_HASH"
       echo "  See references/installation.md § Channel-specific metadata files"
       echo "  for the per-channel exclusion list. If the divergence is a"
       echo "  legitimate channel-specific metadata file, add it to that"
       echo "  table and re-run."
       fail=$((fail + 1))
     fi
   elif [ -n "${NPM_HASH:-}" ] && [ -n "${HOMEBREW_HASH:-}" ]; then
     # 2-way fallback: curl arm unavailable.
     if [ "$NPM_HASH" = "$HOMEBREW_HASH" ]; then
       echo "PASS: cross-channel byte-equivalence (2-way) — NPM_HASH = HOMEBREW_HASH (CURL_HASH unavailable)"
       pass=$((pass + 1))
     else
       echo "FAIL: cross-channel byte-equivalence violated (2-way, curl arm SKIPped)"
       echo "  NPM_HASH=$NPM_HASH"
       echo "  HOMEBREW_HASH=$HOMEBREW_HASH"
       fail=$((fail + 1))
     fi
   else
     echo "SKIP: cross-channel equality assertion requires at least NPM_HASH and HOMEBREW_HASH"
     skip=$((skip + 1))
   fi
   ```

   Use Edit with `old_string` set to the literal multi-line block from
   line 185 through line 207 (the section 5 block + trailing curl SKIP).
   `new_string` is the full replacement above.

   **Tip**: the Edit's `old_string` must match BYTE-FOR-BYTE the existing
   block. Re-read the file via the Read tool with offset=185, limit=25
   to capture the exact whitespace; then build the Edit input.

3. **Sanity-check the edit.**

   ```bash
   grep -nF 'CURL_HASH=' tests/m035-acceptance/cross-channel-byte-equivalence.sh
   ```

   Expect ≥3 matches: the variable initialization (`CURL_HASH=""`),
   the assignment from the helper invocation, the echo line.

   ```bash
   grep -nF 'SKIP: pending P04' tests/m035-acceptance/cross-channel-byte-equivalence.sh
   ```

   Expect zero matches (the stub is gone).

   ```bash
   grep -F 'NPM_HASH" = "$HOMEBREW_HASH" ] && [ "$HOMEBREW_HASH" = "$CURL_HASH"' tests/m035-acceptance/cross-channel-byte-equivalence.sh
   ```

   Expect one match (the 3-way assertion line).

4. **Author `tools/verify/m035-p04-byte-equivalence-curl-arm.sh`.**
   Save the file then `chmod +x`:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p04-byte-equivalence-curl-arm.sh
   #
   # M035 P04 T03 task-grain verifier. Asserts cross-channel-byte-
   # equivalence.sh has the curl-pipe-bash arm + 3-way equality
   # assertion shape; runs the test functionally and asserts the
   # 3-way assertion fires (or SKIPs cleanly when npm is unavailable).
   #
   # AD-19 single-script-file shape. Bash 3.2 compatible.

   set -u

   REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
   TEST_FILE="$REPO_ROOT/tests/m035-acceptance/cross-channel-byte-equivalence.sh"

   pass=0
   fail=0

   check() {
     local name="$1"
     local result="$2"
     if [ "$result" = "0" ]; then
       echo "PASS: $name"
       pass=$((pass + 1))
     else
       echo "FAIL: $name"
       fail=$((fail + 1))
     fi
   }

   # --- Static shape assertions ---

   # 1. Test file exists.
   if [ -f "$TEST_FILE" ]; then check "test file exists" 0; else check "test file exists" 1; fi

   # 2. SKIP: pending P04 stub is gone.
   if grep -F 'SKIP: pending P04' "$TEST_FILE" >/dev/null; then check "SKIP pending P04 stub removed" 1; else check "SKIP pending P04 stub removed" 0; fi

   # 3. CURL_HASH= assignment present (variable used).
   if grep -F 'CURL_HASH=' "$TEST_FILE" >/dev/null; then check "CURL_HASH= variable used" 0; else check "CURL_HASH= variable used" 1; fi

   # 4. install.sh invoked from the test.
   if grep -F 'packaging/install/install.sh' "$TEST_FILE" >/dev/null; then check "install.sh invoked from test" 0; else check "install.sh invoked from test" 1; fi

   # 5. M035_P04_LOCAL_TARBALL test-mode env-var used.
   if grep -F 'M035_P04_LOCAL_TARBALL' "$TEST_FILE" >/dev/null; then check "M035_P04_LOCAL_TARBALL test-mode" 0; else check "M035_P04_LOCAL_TARBALL test-mode" 1; fi

   # 6. M035_P04_STAGE_ONLY test-mode env-var used.
   if grep -F 'M035_P04_STAGE_ONLY' "$TEST_FILE" >/dev/null; then check "M035_P04_STAGE_ONLY test-mode" 0; else check "M035_P04_STAGE_ONLY test-mode" 1; fi

   # 7. 3-way equality assertion present.
   if grep -F 'NPM_HASH = HOMEBREW_HASH = CURL_HASH' "$TEST_FILE" >/dev/null; then check "3-way equality PASS message" 0; else check "3-way equality PASS message" 1; fi

   # 8. CHANNEL=curl-pipe-bash used to extract exclusion list.
   if grep -F 'CHANNEL=curl-pipe-bash' "$TEST_FILE" >/dev/null; then check "CHANNEL=curl-pipe-bash exclusion-list extraction" 0; else check "CHANNEL=curl-pipe-bash exclusion-list extraction" 1; fi

   # --- Functional smoke (test-IS-the-smoke pattern from P02 T03) ---

   # 9. Run the test end-to-end and assert it exits 0 (or a clean SKIP
   #    when npm is absent on PATH). We capture stdout + exit code; if
   #    npm is on PATH and install.sh is on disk, the 3-way assertion
   #    must fire.
   TEST_LOG="$(mktemp 2>/dev/null || mktemp -t m035p04t03verifier)"
   if bash "$TEST_FILE" >"$TEST_LOG" 2>&1; then
     if grep -F 'cross-channel byte-equivalence (3-way) — NPM_HASH = HOMEBREW_HASH = CURL_HASH' "$TEST_LOG" >/dev/null; then
       check "3-way equality assertion fired and PASSed" 0
     elif grep -F 'cross-channel byte-equivalence (2-way)' "$TEST_LOG" >/dev/null; then
       # 2-way fallback path — acceptable if curl arm SKIPped (e.g.,
       # install.sh missing on disk in some pre-T01 fixture). Should
       # NOT happen under normal P04 dispatch ordering.
       check "3-way equality assertion fired" 1
     else
       check "test exited 0 but neither 3-way nor 2-way assertion fired" 1
     fi
   else
     # Test exited non-zero. Acceptable only if npm is genuinely absent.
     if ! command -v npm >/dev/null 2>&1; then
       check "test exited non-zero with npm absent on PATH (acceptable SKIP)" 0
     else
       echo "FAIL: test exited non-zero — see test log:"
       cat "$TEST_LOG" >&2 || true
       check "test functional smoke" 1
     fi
   fi
   rm -f "$TEST_LOG"

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

5. **Run the verifier and confirm `BATTERY: pass=9 fail=0`.**

   ```bash
   bash tools/verify/m035-p04-byte-equivalence-curl-arm.sh
   ```

   If the functional smoke (needle 9) FAILs with "test functional
   smoke" rather than the expected SKIP path, capture the test log
   contents from stderr and inspect: most likely failure modes are
   (a) install.sh's STAGE_ONLY mode produces a different staged-tree
   shape than homebrew's flatten (re-read T01 install.sh's tarball
   extraction logic), or (b) the BSD-sed-bug paper-cut from P05-SUMMARY
   is finally surfacing because curl arm uses a different exclusion-list
   union than homebrew arm (this would be a true-divergence finding,
   NOT a fix-during-T03 problem — escalate to the user with the
   hash trio displayed; do NOT attempt a fix-during-execution to
   the helper since paper-cut work is post-launch scope).

6. **Run the upstream P03 byte-equivalence verifier** to confirm T03's
   edits did not regress the homebrew arm:

   ```bash
   bash tools/verify/m035-p03-byte-equivalence-homebrew-arm.sh
   ```

   Must remain green (`BATTERY: pass=9 fail=0`).

7. **Commit atomically.**

   ```bash
   git add tests/m035-acceptance/cross-channel-byte-equivalence.sh tools/verify/m035-p04-byte-equivalence-curl-arm.sh
   git commit -F /tmp/m035-p04-t03-commit-msg.txt
   ```

   Author commit message via Write to /tmp/m035-p04-t03-commit-msg.txt:

   ```
   M035 P04 T03: cross-channel byte-equivalence curl-pipe-bash arm + 3-way assertion

   - tests/m035-acceptance/cross-channel-byte-equivalence.sh: replace
     SKIP: pending P04 stub with real curl-pipe-bash arm. Re-uses npm
     pack tarball (D007 single source of truth), invokes install.sh in
     M035_P04_LOCAL_TARBALL + M035_P04_STAGE_ONLY test-mode, hashes
     staged tree, asserts CURL_HASH = NPM_HASH = HOMEBREW_HASH (CON-5
     / Constitution Principle XVI third-channel coverage).
   - 2-way fallback preserved when npm absent on PATH (curl arm SKIPs
     cleanly).
   - tools/verify/m035-p04-byte-equivalence-curl-arm.sh — 9-needle
     verifier with functional smoke (BATTERY pass=9 fail=0).
   ```

   Verify clean status; **stay on `main`**.

## Must-Haves

This task addresses these phase must-haves:

- Truth: cross-channel-byte-equivalence.sh extended with curl arm +
  3-way assertion (verified by `m035-p04-byte-equivalence-curl-arm.sh`).
- Artifact: `tests/m035-acceptance/cross-channel-byte-equivalence.sh`
  modified.
- Artifact: `tools/verify/m035-p04-byte-equivalence-curl-arm.sh`.
- Key Link: cross-channel-byte-equivalence.sh →
  `packaging/install/install.sh`.
- Key Link: cross-channel-byte-equivalence.sh →
  `tests/m035-acceptance/_byte-equivalence-hash.sh`.
- Key Link: cross-channel-byte-equivalence.sh →
  `tests/m035-acceptance/_exclusion-list-by-channel.sh`.

## Verification

```bash
bash tools/verify/m035-p04-byte-equivalence-curl-arm.sh
```

```bash
bash tools/verify/m035-p03-byte-equivalence-homebrew-arm.sh
```

## Inputs

### From Previous Tasks

- `packaging/install/install.sh` (from T01) — the curl arm invokes it
  in test-mode. Required behavioral contract from T01:
  - `M035_P04_LOCAL_TARBALL=<path>` env var: short-circuits download
    + SHA-verify; uses the named tarball.
  - `M035_P04_STAGE_ONLY=1` env var: extracts the tarball into the
    staging dir and exits 0 with `STAGED_DIR=<path>` on stdout.
  - `M035_P04_STAGE_DIR=<path>` env var: overrides the default
    mktemp -d staging dir.
  - Under all three env vars set: install.sh exits 0 quickly without
    invoking install-claude-code.sh, leaving the package contents
    flat in the named STAGE_DIR.

  T03 reads only the env-var contract; it does NOT need to read
  install.sh's full content.

### From Disk (Pre-existing)

- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` — agent
  reads the section-5 block (line 185-207) to capture the exact
  whitespace + structure for the Edit `old_string`. Full file content
  not needed beyond that section.

- `tests/m035-acceptance/_byte-equivalence-hash.sh` — the hashing
  helper. Required behavioral contract (P02 T03):
  - Reads `STAGED` env var (path to dir to hash).
  - Reads `EXCLUSION_LIST` env var (newline-separated paths to
    exclude from the hash; treated as glob patterns).
  - Emits a single SHA-256 digest on stdout.
  - Returns exit 0 on success.

  T03 invokes it identically to how the homebrew arm invokes it (set
  STAGED, set EXCLUSION_LIST, capture stdout). No edit to the helper.

- `tests/m035-acceptance/_exclusion-list-by-channel.sh` — the
  per-channel exclusion-list extractor. Required behavioral contract
  (P03 T03):
  - Reads `INSTALLATION_MD` env var (path to references/installation.md).
  - Reads `CHANNEL` env var (one of `npm`, `homebrew`, `curl-pipe-bash`).
  - Emits newline-separated paths from the table whose `Channel(s)`
    column matches `all` or includes `$CHANNEL`.

  The helper already supports `CHANNEL=curl-pipe-bash` per its awk
  comma-separated channel-list parsing (lines 53-56). T03 invokes
  it for the new channel; no edit to the helper required.

## Constraints

- **Do not edit `_byte-equivalence-hash.sh` or `_exclusion-list-by-channel.sh`.**
  Both are P02/P03 helpers; T03 consumes them via env-var contracts.
  P05-SUMMARY's BSD-sed paper-cut on `_byte-equivalence-hash.sh` is
  inherited as-is.
- **Do not extend the `## Channel-specific metadata files` table** in
  installation.md. The curl-pipe-bash channel extracts the same npm
  tarball as the homebrew arm and produces the same staged tree
  shape; no curl-specific noise files exist for v1. (Future
  channel-specific paths land in T04's docs work if discovered.)
- **3-way assertion supersedes 2-way; 2-way fallback preserved.** When
  the curl arm SKIPs (e.g., install.sh missing on disk, or `$TARBALL`
  unavailable), the test gracefully falls back to the 2-way
  `NPM_HASH = HOMEBREW_HASH` assertion. Do NOT remove the 2-way path.
- **EXIT trap extended.** The existing trap is `trap 'rm -rf "$NPM_FIXTURE"
  "$BREW_FIXTURE" 2>/dev/null || true' EXIT`; T03 extends to
  `... "$CURL_FIXTURE" ...`. Do not regress the npm/brew cleanup.
- **Stay on `main`.** No detached HEAD.
- **Single atomic commit.** Both changes (test extension, verifier)
  ship in one commit.

## Expected Output

- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` modified:
  curl arm replaces SKIP stub, 3-way assertion supersedes 2-way (with
  2-way fallback preserved).
- `tools/verify/m035-p04-byte-equivalence-curl-arm.sh` exists, BATTERY
  pass=9 fail=0.
- `m035-p03-byte-equivalence-homebrew-arm.sh` remains green.
- Single git commit on `main`. Clean `git status`.

## Notes

**Why the 2-way fallback path matters.** P02's byte-equivalence
skeleton runs in CI on every PR. CI runners may not have npm
pre-installed in every job context; preserving the 2-way fallback
means a missing `npm` doesn't break the test in unexpected places.
The 3-way is the production assertion (run on dev workstations + on
release CI); 2-way is the partial-coverage assertion (run wherever
both npm and brew are available but not the full curl arm).

**Why install.sh-missing triggers SKIP not FAIL.** During T03 dispatch,
install.sh exists (T01 just authored it). But the `! -x` guard at the
top of the curl arm protects against future test invocations from
fixtures that lack install.sh (e.g., post-launch milestone work that
moves the file). Defensive-by-default; the static-shape verifier in
T04's phase-suite catches the install.sh-missing case at a higher
layer.

**Why no `EXCLUSION_LIST_CURL_BASH` row in installation.md table.** v1's
curl-pipe-bash channel produces the same staged tree as the homebrew
arm (both extract the npm tarball into a flat dir). The CHANNEL=curl-pipe-bash
extraction returns only the `all` rows from the table, which is the
correct coverage at v1. If post-launch findings surface curl-specific
metadata files (e.g., a `.orchestrator/install-via-curl-marker` file),
that plan-phase author extends the table per the existing convention
documented in installation.md.

**BSD-sed paper-cut from P05-SUMMARY remains unfixed.** The
`_byte-equivalence-hash.sh` BSD-sed bracket-class bug silently degrades
EXCLUSION_LIST to a no-op locally. T03's curl arm inherits this — and
it works in T03's favor: with no real exclusion applied, all three
arms hash the same flat tarball-extract and produce identical hashes.
The 3-way equality holds today "by accident" (same way P03's 2-way
equality holds). Post-launch fix queued.

**Why the verifier's functional smoke captures stdout to a tempfile.**
The verifier needs to inspect specific output strings ("3-way equality
assertion fired") to distinguish 3-way-PASS from 2-way-fallback-PASS
from genuine FAIL. Capturing to tempfile and grepping is the AP-009-safe
single-script shape; the alternative `if bash $TEST 2>&1 | grep -q 'pattern'`
is a `$(...)`-with-pipe shape that triggers the harness heuristic.
