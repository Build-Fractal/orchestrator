---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M035"
name: "Extend cross-channel-byte-equivalence.sh with homebrew-channel arm + cross-channel equality assertion"
depends_on: ["T02"]
---

## Prerequisites

- `packaging/homebrew/orchestrator.rb.tmpl` exists (T01).
- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` exists with
  npm-channel arm end-to-end + `SKIP: pending P03` stub for homebrew
  (P02 T03).
- `tests/m035-acceptance/_byte-equivalence-hash.sh` exists, accepts
  `STAGED` + `EXCLUSION_LIST` env vars, emits SHA-256 (P02 T03).
- `references/installation.md § Channel-specific metadata files` is
  on disk and includes the homebrew rows (`.brew/*.bottle.tab`,
  `Library/Caches/Homebrew/`) plus the npm-only `package.json` /
  `package-lock.json` / `node_modules/` rows (P02 T03).
- `npm` is on PATH on the executing agent's machine (inherited
  precondition from P02 T03; the npm-channel arm currently SKIPs when
  npm is absent).

## Description

Replace the homebrew-channel `SKIP: pending P03` stub in
`tests/m035-acceptance/cross-channel-byte-equivalence.sh` with a real
arm that:

1. Re-uses the npm-channel `npm pack` tarball (D007 / single
   source-of-truth for cross-channel byte-equivalence).
2. Extracts it into a fixture Cellar layout.
3. Hashes the staged tree via `_byte-equivalence-hash.sh` with the
   homebrew-channel exclusion list applied.
4. Emits `HOMEBREW_HASH=<sha>`.

Then add the **cross-channel equality assertion**: after both arms
emit hashes, assert `[ "$NPM_HASH" = "$HOMEBREW_HASH" ]` (CON-5
load-bearing Constitution Principle XVI test). On mismatch: increment
`fail`, emit a diagnostic line.

Also resolve the per-channel exclusion-filter question flagged in the
P03-PLAN risk list: extend `_byte-equivalence-hash.sh` to honor a
new `CHANNEL=` env var, OR pre-compute the per-channel exclusion
union before invoking the helper. **Decision (this task): pre-compute
the per-channel exclusion union in the caller** (the byte-equivalence
test itself). Rationale: leaves the helper's contract unchanged
(P02's existing helper consumers don't need to learn a new env var)
and the caller already has the channel context.

## Steps

1. **Read the current
   `tests/m035-acceptance/cross-channel-byte-equivalence.sh`** to map
   the exact insertion points (the `--- 3. homebrew-channel arm` block
   and the `--- 5. Cross-channel equality assertion` block).

2. **Extend the exclusion-list extraction** (in the existing block 1)
   to capture the per-channel column. Currently the script extracts
   only the path column. The replacement extracts both the path and
   the channel column from the markdown table and assembles two
   newline-separated lists: `EXCLUSION_LIST_NPM` and
   `EXCLUSION_LIST_HOMEBREW`. Each list is the union of paths whose
   `Channel(s)` column reads `all` OR matches the channel.

   Replace the existing block 1 awk pipeline with a single helper
   invocation and two list-build loops. The agent MUST author this as
   a *separate helper* under
   `tests/m035-acceptance/_exclusion-list-by-channel.sh` (single-
   script-file shape per AD-19 — keeps the main test free of
   compound shell shapes), invoked twice (once per channel).

3. **Author
   `tests/m035-acceptance/_exclusion-list-by-channel.sh`.** Bash 3.2.
   Inputs (env): `INSTALLATION_MD=<path>`, `CHANNEL=<npm|homebrew|curl-pipe-bash>`.
   Output (stdout): newline-separated paths whose `Channel(s)` column
   matches `all` or the requested channel.

   ```bash
   #!/usr/bin/env bash
   # tests/m035-acceptance/_exclusion-list-by-channel.sh
   # Extract per-channel exclusion paths from references/installation.md
   # § Channel-specific metadata files. Bash 3.2.
   set -u

   if [ -z "${INSTALLATION_MD:-}" ]; then
     echo "FAIL: INSTALLATION_MD env var empty" >&2
     exit 1
   fi
   if [ -z "${CHANNEL:-}" ]; then
     echo "FAIL: CHANNEL env var empty" >&2
     exit 1
   fi
   if [ ! -f "$INSTALLATION_MD" ]; then
     echo "FAIL: $INSTALLATION_MD missing" >&2
     exit 1
   fi

   # Awk:
   #   - flag=1 once we hit the section header
   #   - flag=0 on the next ## heading
   #   - inside the block, parse pipe-table rows where column 1 is a
   #     backticked path and column 2 is `all` / `npm` / `homebrew` /
   #     a comma-separated subset.
   awk -v ch="$CHANNEL" '
     /^## Channel-specific metadata files/ { flag=1; next }
     flag && /^## / { flag=0 }
     flag && /^\| `/ {
       # row layout: | `<path>` | <channel-list> | <why> |
       # split on pipe; field 2 is the path-column with backticks,
       # field 3 is the channel column.
       n = split($0, f, /[|]/)
       if (n < 4) next
       path = f[2]
       chans = f[3]
       gsub(/^[ \t]+|[ \t]+$/, "", path)
       gsub(/^[ \t]+|[ \t]+$/, "", chans)
       gsub(/`/, "", path)
       # match channel: "all" matches every channel; otherwise
       # comma-separated list of channel names.
       matched = 0
       if (chans == "all") {
         matched = 1
       } else {
         m = split(chans, c, /[, ]+/)
         for (i = 1; i <= m; i++) {
           if (c[i] == ch) { matched = 1; break }
         }
       }
       if (matched) print path
     }
   ' "$INSTALLATION_MD"
   ```

   Make executable:

   ```bash
   chmod +x tests/m035-acceptance/_exclusion-list-by-channel.sh
   ```

4. **Modify
   `tests/m035-acceptance/cross-channel-byte-equivalence.sh`** as
   follows.

   **(4a)** Replace the existing `--- 1. Read the exclusion list from
   installation.md` block with the per-channel version:

   ```bash
   # --- 1. Read per-channel exclusion lists from installation.md ----

   if [ ! -f "$INSTALLATION_MD" ]; then
     echo "FAIL: $INSTALLATION_MD missing -- exclusion-list source not found"
     exit 1
   fi

   export INSTALLATION_MD
   CHANNEL=npm
   export CHANNEL
   EXCLUSION_LIST_NPM="$(bash "$REPO_ROOT/tests/m035-acceptance/_exclusion-list-by-channel.sh")"
   CHANNEL=homebrew
   export CHANNEL
   EXCLUSION_LIST_HOMEBREW="$(bash "$REPO_ROOT/tests/m035-acceptance/_exclusion-list-by-channel.sh")"
   unset CHANNEL

   if [ -z "$EXCLUSION_LIST_NPM" ] || [ -z "$EXCLUSION_LIST_HOMEBREW" ]; then
     echo "FAIL: per-channel exclusion list empty -- installation.md table unreadable"
     exit 1
   fi

   npm_excl_lines="$(printf '%s\n' "$EXCLUSION_LIST_NPM" | wc -l | tr -d ' ')"
   brew_excl_lines="$(printf '%s\n' "$EXCLUSION_LIST_HOMEBREW" | wc -l | tr -d ' ')"
   echo "exclusion_list_npm_lines=$npm_excl_lines"
   echo "exclusion_list_homebrew_lines=$brew_excl_lines"
   ```

   Update the npm-channel arm (block 2) to set `EXCLUSION_LIST="$EXCLUSION_LIST_NPM"`
   immediately before the existing `bash "$REPO_ROOT/tests/m035-acceptance/_byte-equivalence-hash.sh"`
   invocation (the helper's contract is unchanged; the caller now picks
   the per-channel list).

   **(4b)** Replace the existing `--- 3. homebrew-channel arm (stub,
   P03 extends)` block with:

   ```bash
   # --- 3. homebrew-channel arm (D007 + T03) ------------------------

   HOMEBREW_HASH=""
   if [ -z "${TARBALL:-}" ] || [ ! -f "$TARBALL" ]; then
     echo "SKIP: homebrew-channel arm requires npm-channel tarball — npm-channel did not produce one"
     skip=$((skip + 1))
   else
     BREW_FIXTURE="$(mktemp -d 2>/dev/null || mktemp -d -t m035p03t03brew)"
     trap 'rm -rf "$NPM_FIXTURE" "$BREW_FIXTURE" 2>/dev/null || true' EXIT

     # Extract the npm-channel tarball into a fixture Cellar layout
     # mirroring brew's /opt/homebrew/Cellar/orchestrator/<version>/
     # structure. The npm pack tarball extracts into a top-level
     # "package/" dir per npm convention; the formula's def install
     # block (T01) does `prefix.install Dir["package/*"]` to flatten,
     # so the staged Cellar layout puts package/* contents directly
     # under <Cellar>/<version>/.
     PKG_VERSION="$(grep -E '^\s*"version"\s*:' "$REPO_ROOT/package.json" \
       | head -1 \
       | sed -E 's/.*"version"\s*:\s*"([^"]+)".*/\1/')"
     CELLAR="$BREW_FIXTURE/Cellar/orchestrator/$PKG_VERSION"
     mkdir -p "$CELLAR"
     tar -xzf "$TARBALL" -C "$BREW_FIXTURE" >/dev/null 2>&1
     # mv package/* into Cellar/<version>/ (flatten — matches def install)
     if [ -d "$BREW_FIXTURE/package" ]; then
       # Use cp -R + rm rather than mv so it works across exotic FS.
       cp -R "$BREW_FIXTURE/package/." "$CELLAR/"
       rm -rf "$BREW_FIXTURE/package"
       echo "PASS: homebrew-channel staged into $CELLAR"
       pass=$((pass + 1))
     else
       echo "FAIL: tarball did not extract into expected package/ dir"
       fail=$((fail + 1))
     fi

     # Hash the staged tree with homebrew-channel exclusion list.
     STAGED="$CELLAR"
     EXCLUSION_LIST="$EXCLUSION_LIST_HOMEBREW"
     export STAGED EXCLUSION_LIST
     HOMEBREW_HASH="$(bash "$REPO_ROOT/tests/m035-acceptance/_byte-equivalence-hash.sh" \
       2>"$BREW_FIXTURE/hash.err")"
     if [ -n "$HOMEBREW_HASH" ]; then
       echo "HOMEBREW_HASH=$HOMEBREW_HASH"
       echo "PASS: homebrew-channel hash emitted"
       pass=$((pass + 1))
     else
       echo "FAIL: homebrew-channel hash not emitted (see $BREW_FIXTURE/hash.err)"
       fail=$((fail + 1))
     fi
   fi
   ```

   **(4c)** Replace the existing `--- 5. Cross-channel equality
   assertion (P03+)` block with:

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

   echo "BATTERY: pass=$pass fail=$fail skip=$skip"
   [ "$fail" -eq 0 ]
   ```

   Note: the npm-channel arm currently uses a local var `TARBALL` —
   that variable is already in scope at the homebrew-arm point (block
   2 sets it). The per-channel `EXCLUSION_LIST` swap pattern follows
   the same shape used in block 2.

5. **Author
   `tools/verify/m035-p03-byte-equivalence-homebrew-arm.sh`.**
   Verifier exercises the full byte-equivalence test end-to-end and
   asserts both `HOMEBREW_HASH=` is emitted and the cross-channel
   equality `PASS:` line fires:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p03-byte-equivalence-homebrew-arm.sh
   set -u

   pass=0
   fail=0
   TEST="tests/m035-acceptance/cross-channel-byte-equivalence.sh"

   if [ ! -x "$TEST" ]; then
     echo "FAIL: $TEST not executable"
     echo "BATTERY: pass=0 fail=1"
     exit 1
   fi
   pass=$((pass + 1))

   # Static-shape checks.
   for needle in 'HOMEBREW_HASH=' \
     'EXCLUSION_LIST_HOMEBREW' \
     'cross-channel byte-equivalence' \
     '_exclusion-list-by-channel.sh'; do
     if grep -qF "$needle" "$TEST"; then
       pass=$((pass + 1))
     else
       echo "FAIL: $TEST missing pattern: $needle"
       fail=$((fail + 1))
     fi
   done

   # Anti-pattern: the SKIP: pending P03 stub MUST be gone.
   if grep -qF 'SKIP: pending P03' "$TEST"; then
     echo "FAIL: $TEST still contains 'SKIP: pending P03' stub"
     fail=$((fail + 1))
   else
     pass=$((pass + 1))
   fi

   # End-to-end: run the test. Requires npm on PATH.
   if ! command -v npm >/dev/null 2>&1; then
     echo "SKIP: npm not on PATH — end-to-end byte-equivalence skipped"
     echo "BATTERY: pass=$pass fail=$fail skip=1"
     [ "$fail" -eq 0 ]
     exit $?
   fi

   PROBE_LOG="/tmp/m035-p03-byte-equivalence-probe.log"
   if bash "$TEST" >"$PROBE_LOG" 2>&1; then
     pass=$((pass + 1))
   else
     echo "FAIL: $TEST exited non-zero (see $PROBE_LOG)"
     fail=$((fail + 1))
   fi

   if grep -qE '^HOMEBREW_HASH=[0-9a-f]{64}$' "$PROBE_LOG"; then
     pass=$((pass + 1))
   else
     echo "FAIL: HOMEBREW_HASH not emitted as 64-hex-char digest"
     fail=$((fail + 1))
   fi

   if grep -qF 'PASS: cross-channel byte-equivalence' "$PROBE_LOG"; then
     pass=$((pass + 1))
   else
     echo "FAIL: cross-channel equality assertion did not PASS"
     # Don't delete the log on failure — operator needs to inspect.
     echo "  see $PROBE_LOG"
     fail=$((fail + 1))
   fi

   if [ "$fail" -eq 0 ]; then
     rm -f "$PROBE_LOG"
   fi

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   Make executable:

   ```bash
   chmod +x tools/verify/m035-p03-byte-equivalence-homebrew-arm.sh
   ```

6. **Run all six verifiers** (T01's two + T02's two + T03's one + the
   end-to-end byte-equivalence test) locally to confirm green.

## Must-Haves

- Truth: byte-equivalence test contains a real homebrew-channel arm
  emitting `HOMEBREW_HASH=`, no longer contains `SKIP: pending P03`,
  and asserts `NPM_HASH = HOMEBREW_HASH` (verified by
  `m035-p03-byte-equivalence-homebrew-arm.sh`).
- Artifact: `tests/m035-acceptance/cross-channel-byte-equivalence.sh`
  modified.
- Artifact: `tests/m035-acceptance/_exclusion-list-by-channel.sh`
  created.
- Key Link: byte-equivalence test → `_exclusion-list-by-channel.sh`.

## Verification

```bash
bash tools/verify/m035-p03-byte-equivalence-homebrew-arm.sh
```

## Notes

Expected output: verifier emits `BATTERY: pass=N fail=0` (or `skip=1`
if `npm` is absent on the executing machine). The byte-equivalence
test itself emits `BATTERY: pass=N fail=0 skip=K` with `pass`
including both per-channel hashes + the cross-channel equality assertion.

If the executing agent's machine has `npm` absent, the static-shape
checks still pass and the end-to-end run is SKIP'd. CI exercises the
full path on every PR via `pr-validate`.

## Inputs

### From Previous Tasks

- `packaging/homebrew/orchestrator.rb.tmpl` (from T01)
  - Key behavior: the formula's `def install` block does
    `prefix.install Dir["package/*"]` — this is the layout T03's
    homebrew arm mirrors when it `cp -R "$BREW_FIXTURE/package/."
    "$CELLAR/"`. Any divergence between formula's def install
    and T03's fixture layout means the byte-equivalence test
    misrepresents what `brew install` would stage.
- `.github/workflows/release.yml` `homebrew-publish` job (from T02)
  - Key behavior: the job's "Render formula" step invokes
    `render-formula.sh` against the published `.tgz`. T03's fixture
    extraction mirrors what brew would extract from that same `.tgz`.

### From Disk (Pre-existing)

- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` — extended
  in place. The npm-channel arm and exclusion-list extraction block
  are modified; the homebrew-channel SKIP stub is replaced.
- `tests/m035-acceptance/_byte-equivalence-hash.sh` — invoked, NOT
  modified. The helper's contract (consumes `STAGED` + `EXCLUSION_LIST`
  env vars, emits SHA-256 digest) is unchanged.
- `references/installation.md § Channel-specific metadata files` —
  read by `_exclusion-list-by-channel.sh` at runtime. P03 does NOT
  modify the list (the homebrew rows + npm rows are already present
  per P02 T03).

## Constraints

- Bash 3.2 compatible for the test script and both helpers.
- No `<(...)` process substitution, no plain subshells in command
  position. Per AD-19 / AP-009.
- `_byte-equivalence-hash.sh` contract is unchanged — extending it
  would break P02 T03's verifier expectations and is unnecessary
  given the per-channel union is computed in the caller.
- The cross-channel equality assertion fires ONLY when both arms
  emit hashes; if either arm SKIPs (e.g. npm absent), the assertion
  itself SKIPs rather than spuriously failing.

## Expected Output

- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` (≥160
  lines, contains `HOMEBREW_HASH=`, `EXCLUSION_LIST_HOMEBREW`,
  `cross-channel byte-equivalence`, no longer contains
  `SKIP: pending P03`).
- `tests/m035-acceptance/_exclusion-list-by-channel.sh` (≥30 lines,
  executable).
- `tools/verify/m035-p03-byte-equivalence-homebrew-arm.sh` (≥50 lines,
  emits `BATTERY: pass=N fail=0`).
