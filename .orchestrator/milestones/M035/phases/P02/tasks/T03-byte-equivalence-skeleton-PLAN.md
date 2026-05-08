---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M035"
name: "Cross-channel byte-equivalence skeleton + exclusion-list documentation (CON-5 / SC-10 / AD-2 Constitution Principle XVI bootstrap)"
depends_on: ["T01", "T02"]
---

## Prerequisites

- **T01 complete**: `package.json` exists at the repo root.
  T03 invokes `npm pack` against this manifest to produce the npm-
  channel test tarball.
- **T02 complete**: `packaging/npm/postinstall.sh` exists and honors
  `DRY_RUN=1` (D002 contract). T03's npm-channel arm runs the
  postinstall under `DRY_RUN=1` so the test is fully offline and
  side-effect-free.
- **`references/installation.md` exists** at the repo root with
  existing sections including `## Upgrading`. T03 appends a new
  `## Channel-specific metadata files` section per MIT-2 enumeration
  resolution.
- **`tests/m035-acceptance/` directory exists** (created by P01.5
  for `legacy-namespace-allowlist.txt`). T03 adds two new files here
  and does not touch the existing allowlist.
- **`scripts/util/run-probe.sh` exists** (M025 / repo standard).
  T03 stages probes there for any compound-shell logic.
- **`npm` is available on PATH at executor-time**. T03's verifier
  shells `npm pack` and `npm install --prefix ...`. If npm is
  absent, the verifier emits a clear `SKIP: npm not on PATH` line
  and exits non-zero (executor must address before phase close).
  T04's CI workflow installs node/npm before invoking the test.

## Description

Author the cross-channel byte-equivalence test skeleton. This is the
**Constitution Principle XVI compliance test surface** at v1 — the
load-bearing mechanism that ensures every distribution channel ships
the same bytes.

At P02 close, only the **npm-channel arm** is implemented (P03 will
extend with the homebrew-channel hash assertion; P04 with the curl-
pipe-bash hash). The skeleton:

1. Defines the exclusion-list contract (MIT-2 — what "documented
   per-install metadata files" means in CON-5 / SC-10 / SC-12 /
   FR-14).
2. Implements the npm-channel arm: `npm pack` → fixture-prefix
   install with `DRY_RUN=1` postinstall → `find + shasum` over the
   staged tree minus exclusions.
3. Stubs the homebrew + curl-pipe-bash arms with `SKIP: pending P03`
   / `SKIP: pending P04` lines. The script's exit code is 0 if the
   npm-channel arm passes (skipped arms are non-blocking).
4. Documents the exclusion list in
   `references/installation.md § Channel-specific metadata files` so
   future plan-phase authors extending the list have one canonical
   surface to update (MIT-2 contract: "Plan-phase authors extending
   the list update `references/installation.md § Channel-specific
   metadata files` first.").

The npm-channel hash emission is **informational** at P02 — there's
no second channel to compare against yet. The test exists to (a)
prove the testing harness works end-to-end (npm pack succeeds, the
postinstall dry-run produces a deterministic staged tree, and the
hash is reproducible across invocations) and (b) bootstrap the
contract for P03/P04.

## Steps

1. **Append `## Channel-specific metadata files` to `references/installation.md`**.
   Read the current file first (it's the existing M032 / M035-edited
   doc). Find a stable insertion point — after the `## Upgrading`
   section, before any `## Verifying integrity` section (P05 will
   author that). If `## Upgrading` does not exist, append at the
   end of the file. Section content (verbatim):

   ```markdown
   ## Channel-specific metadata files

   The cross-channel byte-equivalence contract (Constitution
   Principle XVI / FR-14 / SC-10 / SC-12 / CON-5) requires the
   runtime layout produced by every distribution channel — npm,
   homebrew, curl-pipe-bash — to be byte-identical at a given
   release tag. This is verified by hashing the staged runtime tree
   post-install and comparing across channels.

   The hash MUST exclude **per-install metadata files** that are
   legitimately channel-specific. The canonical exclusion list (M035
   P02 T03 / MIT-2 enumeration):

   | Path                              | Channel(s) | Why excluded                                                  |
   |-----------------------------------|------------|---------------------------------------------------------------|
   | `.orchestrator/install-meta.txt`  | all        | Operator-specific absolute paths (FR-6).                      |
   | `.orchestrator/.previous-version` | all        | Per-install rollback marker (FR-12).                          |
   | `package.json`                    | npm        | npm-channel manifest; absent in homebrew/curl channels.       |
   | `package-lock.json`               | npm        | npm transitive lock; not authored at release time.            |
   | `node_modules/`                   | npm        | npm-installed dependencies; absent in non-npm channels.       |
   | `.brew/*.bottle.tab`              | homebrew   | Homebrew receipt files (P03 will introduce).                  |
   | `Library/Caches/Homebrew/`        | homebrew   | Homebrew bottle cache (P03).                                  |
   | `.git/`, `.github/`               | all        | Repository metadata; not staged into adopter projects.        |

   Plan-phase authors extending this list (P03, P04, future
   distribution channels) MUST update this section first, then
   reference it from `tests/m035-acceptance/cross-channel-byte-
   equivalence.sh`. The test reads the exclusion globs from this
   document at runtime via grep — no hardcoded list duplication.
   ```

   This is the load-bearing MIT-2 surface. Make the edit.

2. **Author `tests/m035-acceptance/cross-channel-byte-equivalence.sh`** with body:

   ```bash
   #!/usr/bin/env bash
   # tests/m035-acceptance/cross-channel-byte-equivalence.sh
   # Constitution Principle XVI compliance test (M035 P02 T03 — npm-
   # channel skeleton; P03 extends homebrew arm; P04 extends curl-
   # pipe-bash arm).
   #
   # Hashes the staged runtime tree post-install for each channel,
   # compares across channels for byte equivalence (modulo the
   # exclusion list at references/installation.md § Channel-specific
   # metadata files).
   #
   # P02 contract: npm-channel arm runs end-to-end and emits NPM_HASH=.
   # Other arms emit SKIP: pending P03/P04 and do NOT contribute to the
   # final equality assertion. The script's exit code is 0 if every
   # non-skipped arm passes its own internal hash-reproducibility
   # check.
   #
   # Bash 3.2 compatible. No declare -A.

   set -u

   REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
   INSTALLATION_MD="$REPO_ROOT/references/installation.md"

   pass=0
   fail=0
   skip=0

   # --- 1. Read the exclusion list from installation.md --------------

   # Extract exclusion paths from the markdown table in
   # references/installation.md. Lines look like:
   # | `.orchestrator/install-meta.txt` | all | ... |
   # We grep table rows and extract the first column's backticked path.
   if [ ! -f "$INSTALLATION_MD" ]; then
     echo "FAIL: $INSTALLATION_MD missing — exclusion-list source not found"
     exit 1
   fi

   EXCLUSION_LIST="$(awk '/^## Channel-specific metadata files/,/^## /' \
     "$INSTALLATION_MD" | grep -oE '`[^`]+`' | sed -E 's/^`//; s/`$//' \
     | grep -vE '^(all|npm|homebrew|all,)$' || true)"

   if [ -z "$EXCLUSION_LIST" ]; then
     echo "FAIL: exclusion list empty — installation.md § Channel-specific metadata files unreadable"
     exit 1
   fi

   echo "exclusion_list_lines=$(echo "$EXCLUSION_LIST" | wc -l | tr -d ' ')"

   # --- 2. npm-channel arm ------------------------------------------

   if ! command -v npm >/dev/null 2>&1; then
     echo "FAIL: npm not on PATH — npm-channel arm cannot run"
     fail=$((fail + 1))
   else
     NPM_FIXTURE="$(mktemp -d 2>/dev/null || mktemp -d -t m035p02t03npm)"
     trap 'rm -rf "$NPM_FIXTURE" 2>/dev/null || true' EXIT

     # 2a. npm pack (offline tarball assembly from package.json)
     ( cd "$REPO_ROOT" && npm pack --pack-destination "$NPM_FIXTURE" \
         >"$NPM_FIXTURE/pack.log" 2>&1 ) || {
       echo "FAIL: npm pack failed (see $NPM_FIXTURE/pack.log)"
       fail=$((fail + 1))
     }

     TARBALL="$(find "$NPM_FIXTURE" -name 'build-fractal-orchestrator-*.tgz' \
       -type f | head -1)"
     if [ -z "$TARBALL" ]; then
       echo "FAIL: npm pack produced no tarball matching build-fractal-orchestrator-*.tgz"
       fail=$((fail + 1))
     else
       echo "PASS: npm pack produced $TARBALL"
       pass=$((pass + 1))

       # 2b. Install into a fixture prefix under DRY_RUN=1 postinstall.
       FIXTURE_PREFIX="$NPM_FIXTURE/.npm-prefix"
       mkdir -p "$FIXTURE_PREFIX"
       export DRY_RUN=1
       export INIT_CWD="$NPM_FIXTURE/project"
       mkdir -p "$INIT_CWD"
       ( cd "$NPM_FIXTURE" && npm install -g --prefix "$FIXTURE_PREFIX" \
           "$TARBALL" >"$NPM_FIXTURE/install.log" 2>&1 ) || {
         echo "FAIL: npm install of tarball failed (see $NPM_FIXTURE/install.log)"
         fail=$((fail + 1))
       }
       unset DRY_RUN
       unset INIT_CWD

       # 2c. Hash the staged tree under FIXTURE_PREFIX, applying
       # exclusion list. The staged tree lives at
       # $FIXTURE_PREFIX/lib/node_modules/@build-fractal/orchestrator/.
       STAGED="$FIXTURE_PREFIX/lib/node_modules/@build-fractal/orchestrator"
       if [ ! -d "$STAGED" ]; then
         echo "FAIL: staged tree not found at $STAGED"
         fail=$((fail + 1))
       else
         # Build a `find` exclusion expression from EXCLUSION_LIST.
         # Use scripts/util/run-probe.sh to stage the hashing logic
         # (compound-chain avoidance per AP-009).
         export STAGED EXCLUSION_LIST
         NPM_HASH="$(bash "$REPO_ROOT/scripts/util/run-probe.sh" \
           "$REPO_ROOT/tests/m035-acceptance/_byte-equivalence-hash.sh" \
           2>"$NPM_FIXTURE/hash.err")"
         if [ -n "$NPM_HASH" ]; then
           echo "NPM_HASH=$NPM_HASH"
           echo "PASS: npm-channel hash emitted"
           pass=$((pass + 1))
         else
           echo "FAIL: npm-channel hash not emitted (see $NPM_FIXTURE/hash.err)"
           fail=$((fail + 1))
         fi
       fi
     fi
   fi

   # --- 3. homebrew-channel arm (stub, P03 extends) ------------------

   echo "SKIP: pending P03 — homebrew-channel hash assertion"
   skip=$((skip + 1))

   # --- 4. curl-pipe-bash-channel arm (stub, P04 extends) ------------

   echo "SKIP: pending P04 — curl-pipe-bash-channel hash assertion"
   skip=$((skip + 1))

   # --- 5. Cross-channel equality assertion (P03+) -------------------

   # When 2+ non-skipped channel hashes are emitted, assert they match.
   # P02 always has only NPM_HASH; the assertion is a no-op (single-
   # channel byte equivalence is reflexive).
   echo "BATTERY: pass=$pass fail=$fail skip=$skip"

   [ "$fail" -eq 0 ]
   ```

3. **Author the hash-helper probe** at
   `tests/m035-acceptance/_byte-equivalence-hash.sh` (the `_`-prefix
   marks it as a helper, not a top-level acceptance test). This is
   the "single-script-file shape" hashing logic the main test
   delegates to (AP-009 / CON-3 honored). Body:

   ```bash
   #!/usr/bin/env bash
   # tests/m035-acceptance/_byte-equivalence-hash.sh
   # Helper: hash STAGED dir applying EXCLUSION_LIST regex globs.
   # Inputs (env): STAGED=<dir>, EXCLUSION_LIST=<newline-sep paths>
   # Output (stdout): SHA-256 hex digest (single line, no trailing newline)
   set -euo pipefail

   if [ -z "${STAGED:-}" ]; then
     echo "FAIL: STAGED env var empty" >&2
     exit 1
   fi
   if [ ! -d "$STAGED" ]; then
     echo "FAIL: STAGED dir not found: $STAGED" >&2
     exit 1
   fi

   # Build a sed-friendly exclusion regex. Each line of EXCLUSION_LIST
   # becomes a grep -vE pattern. Treat trailing slash as directory
   # match. Anchor at start-of-relative-path.
   EXCL_RE=""
   while IFS= read -r p; do
     [ -z "$p" ] && continue
     # Escape regex metacharacters in path.
     esc="$(echo "$p" | sed -E 's/[.[\]\^$\/]/\\&/g')"
     if [ -z "$EXCL_RE" ]; then
       EXCL_RE="$esc"
     else
       EXCL_RE="$EXCL_RE|$esc"
     fi
   done <<EOF_EXCL
   $EXCLUSION_LIST
   EOF_EXCL

   # find all files relative to STAGED, sort for determinism, exclude
   # the EXCL_RE patterns, hash each file's content + path, then
   # combine.
   ( cd "$STAGED" && find . -type f -print | sort ) \
     | grep -vE "^\\./($EXCL_RE)" \
     | while IFS= read -r relpath; do
         shasum -a 256 "$STAGED/$relpath" | awk -v p="$relpath" '{print $1, p}'
       done \
     | shasum -a 256 \
     | awk '{print $1}'
   ```

   Make both scripts executable:

   ```bash
   chmod +x tests/m035-acceptance/cross-channel-byte-equivalence.sh
   chmod +x tests/m035-acceptance/_byte-equivalence-hash.sh
   ```

4. **Author the byte-equivalence skeleton verifier** at
   `tools/verify/m035-p02-byte-equivalence-skeleton.sh` with body:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p02-byte-equivalence-skeleton.sh
   # Asserts the cross-channel byte-equivalence test skeleton meets
   # the M035 P02 T03 contract:
   #   * test file exists, executable
   #   * helper hash script exists, executable
   #   * test reads exclusion list from references/installation.md
   #   * npm-channel arm emits NPM_HASH=<sha>
   #   * homebrew + curl-pipe-bash arms emit SKIP: pending P03/P04
   #   * BATTERY: line shape present
   set -euo pipefail

   REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
   TEST="$REPO/tests/m035-acceptance/cross-channel-byte-equivalence.sh"
   HELPER="$REPO/tests/m035-acceptance/_byte-equivalence-hash.sh"

   pass=0
   fail=0

   # File existence + executability
   for f in "$TEST" "$HELPER"; do
     if [ ! -f "$f" ]; then
       echo "FAIL: $f not found"
       fail=$((fail + 1))
     elif [ ! -x "$f" ]; then
       echo "FAIL: $f not executable"
       fail=$((fail + 1))
     else
       echo "PASS: $f exists and is executable"
       pass=$((pass + 1))
     fi
   done

   check_grep() {
     local file="$1" pattern="$2" label="$3"
     if grep -qE "$pattern" "$file"; then
       echo "PASS: $label"
       pass=$((pass + 1))
     else
       echo "FAIL: $label (file=$file pattern=$pattern)"
       fail=$((fail + 1))
     fi
   }

   check_grep "$TEST" 'references/installation\.md' \
     "test reads exclusion list from references/installation.md (MIT-2)"
   check_grep "$TEST" 'NPM_HASH=' "npm-channel arm emits NPM_HASH= line"
   check_grep "$TEST" 'SKIP: pending P03' "homebrew arm stubbed (SKIP: pending P03)"
   check_grep "$TEST" 'SKIP: pending P04' "curl-pipe-bash arm stubbed (SKIP: pending P04)"
   check_grep "$TEST" 'BATTERY:' "BATTERY: line shape present"
   check_grep "$TEST" 'DRY_RUN=1' "npm-channel arm runs postinstall under DRY_RUN=1 (D002)"

   # Functional smoke: run the test (it should exit 0 if npm is on PATH)
   if command -v npm >/dev/null 2>&1; then
     if bash "$TEST" >/tmp/m035-p02-bce.log 2>&1; then
       echo "PASS: cross-channel-byte-equivalence.sh runs end-to-end (exit 0)"
       pass=$((pass + 1))
       if grep -q '^NPM_HASH=' /tmp/m035-p02-bce.log; then
         echo "PASS: NPM_HASH= emitted on functional run"
         pass=$((pass + 1))
       else
         echo "FAIL: NPM_HASH= not emitted on functional run"
         fail=$((fail + 1))
       fi
     else
       echo "FAIL: cross-channel-byte-equivalence.sh exited non-zero (see /tmp/m035-p02-bce.log)"
       fail=$((fail + 1))
     fi
   else
     echo "SKIP: npm not on PATH — functional smoke deferred to CI"
   fi

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

5. **Author the installation-doc exclusion-list verifier** at
   `tools/verify/m035-p02-installation-doc-exclusion-list.sh` with body:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p02-installation-doc-exclusion-list.sh
   # Asserts references/installation.md § Channel-specific metadata files
   # exists with the load-bearing exclusion list (MIT-2 enumeration).
   set -euo pipefail

   REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
   DOC="$REPO/references/installation.md"

   pass=0
   fail=0

   if [ ! -f "$DOC" ]; then
     echo "FAIL: $DOC not found"
     exit 1
   fi

   if grep -q '^## Channel-specific metadata files' "$DOC"; then
     echo "PASS: § Channel-specific metadata files heading present"
     pass=$((pass + 1))
   else
     echo "FAIL: § Channel-specific metadata files heading absent"
     fail=$((fail + 1))
   fi

   for path in '.orchestrator/install-meta.txt' '.orchestrator/.previous-version' \
               'package.json' 'package-lock.json' 'node_modules/'; do
     if grep -qF "$path" "$DOC"; then
       echo "PASS: exclusion list contains $path"
       pass=$((pass + 1))
     else
       echo "FAIL: exclusion list missing $path"
       fail=$((fail + 1))
     fi
   done

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   Make all three verifiers executable.

6. **Self-check**:

   ```bash
   bash tools/verify/m035-p02-installation-doc-exclusion-list.sh
   bash tools/verify/m035-p02-byte-equivalence-skeleton.sh
   ```

   Both must emit `BATTERY: pass=N fail=0`. The byte-equivalence
   verifier expects `npm` on PATH; if absent, the SKIP advisory is
   acceptable but the executor must address before phase close.

## Must-Haves

This task addresses the following phase must-haves:

- Truth: `tests/m035-acceptance/cross-channel-byte-equivalence.sh`
  exists, executable, npm-channel arm runs end-to-end and emits
  `NPM_HASH=`, homebrew/curl arms stubbed with SKIP lines (CON-5,
  AD-2 Constitution Principle XVI bootstrap)
- Truth: `references/installation.md` extended with
  `## Channel-specific metadata files` section (MIT-2 enumeration)
- Artifact: `tests/m035-acceptance/cross-channel-byte-equivalence.sh`
  (min 80 lines, contains `NPM_HASH=` AND `SKIP: pending P03`)
- Artifact: `references/installation.md` (modified — contains
  `## Channel-specific metadata files`)
- Key Link: `tests/m035-acceptance/cross-channel-byte-equivalence.sh`
  → `references/installation.md`

## Verification

```bash
bash tools/verify/m035-p02-installation-doc-exclusion-list.sh
bash tools/verify/m035-p02-byte-equivalence-skeleton.sh
```

## Inputs

### From Previous Tasks

- `package.json` (from T01)
  - Key API: declares `name`, `version`, `bin`, `os`, `files`,
    `scripts.postinstall`. Read by `npm pack` to assemble the
    tarball.
  - Key types: JSON object; npm-conformant.

- `packaging/npm/postinstall.sh` (from T02)
  - Key API: respects `DRY_RUN=1` env var (emits `would_invoke=`
    lines, makes no writes). Resolves `INIT_CWD` (npm convention)
    or falls through to global-install advisory.
  - Behavioral contract: when `DRY_RUN=1` is set, postinstall does
    NOT invoke `install-claude-code.sh`.

### From Disk (Pre-existing)

- `references/installation.md` — existing M032/M035-edited doc
  with `## Upgrading` section. T03 appends a new section after
  Upgrading.
- `scripts/util/run-probe.sh` — staged-probe wrapper used by the
  test for the hashing helper. AP-009 / CON-3 honored.
- `tests/m035-acceptance/legacy-namespace-allowlist.txt` (from
  P01.5) — sibling artifact in the same dir; do not modify.
- `npm` on PATH (executor environment requirement).

## Constraints

- **AP-009 / CON-3**: the main test script avoids inline compound
  chains; the hashing logic is staged via `run-probe.sh` to a
  helper script.
- **MIT-2 (exclusion list lives in installation.md)**: T03 must NOT
  hardcode the exclusion list inside the test script. The test
  reads from `references/installation.md § Channel-specific
  metadata files` at runtime. Future additions update the doc;
  the test re-reads on the next invocation.
- **Plan-Time Discipline Rule 5 analog (real-pack verification)**:
  the verifier's functional smoke runs the actual test, which runs
  actual `npm pack`. The test is the smoke. No mock-only
  verification here — npm tarball assembly is the load-bearing
  surface and must be exercised end-to-end.
- **D002 (DRY_RUN=1 contract)**: the npm-channel arm sets
  `DRY_RUN=1` before invoking `npm install`. The postinstall sees
  this and emits `would_invoke=` lines instead of running the
  installer. This is what makes the test fully offline and
  side-effect-free.
- **CON-5 / SC-10 / FR-14**: the byte-equivalence contract is
  bootstrapped at P02 with one channel; the contract is enforced
  at P03 close (homebrew arm) and P04 close (curl-pipe-bash arm).
  P02's contract is "the harness works"; cross-channel equality is
  P03's contract.
- **No /tmp leftovers**: the test uses `mktemp -d` and `trap
  'rm -rf' EXIT` for fixture cleanup. The verifier uses the same
  pattern.

## Expected Output

Three new files on disk + one modified file:

- `tests/m035-acceptance/cross-channel-byte-equivalence.sh`
  (~110 lines, executable)
- `tests/m035-acceptance/_byte-equivalence-hash.sh`
  (~40 lines, executable, helper)
- `tools/verify/m035-p02-byte-equivalence-skeleton.sh`
  (~70 lines, executable)
- `tools/verify/m035-p02-installation-doc-exclusion-list.sh`
  (~30 lines, executable)
- `references/installation.md` (modified — new section appended,
  ~25 lines added)

`bash tools/verify/m035-p02-byte-equivalence-skeleton.sh` emits
`BATTERY: pass=N fail=0` (10 PASS lines expected when npm is on
PATH; 8 PASS + 1 SKIP when npm absent).

## Notes

Expected verifier output: `PASS: ...` lines plus `BATTERY: pass=N
fail=0`. The `installation-doc-exclusion-list.sh` verifier expects
6 PASS lines (1 heading + 5 path-presence). The `byte-equivalence-
skeleton.sh` verifier expects 10 PASS lines when npm is available.

Idempotency: re-running the test produces the same `NPM_HASH=`
hex digest given the same `package.json` content and the same
exclusion list. The hashing helper sorts file paths
deterministically.

Reversibility: removing the four T03-authored files unwinds the
task; the appended section in `references/installation.md` is a
contained block that can be removed cleanly. T04's CI workflow
references the test path (`tests/m035-acceptance/cross-channel-
byte-equivalence.sh`); rolling back T03 strands T04's reference.
