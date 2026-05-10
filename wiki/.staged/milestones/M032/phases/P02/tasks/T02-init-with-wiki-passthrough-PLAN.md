---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M032"
name: "init --with-wiki [--with-giscus] [--deploy] passthrough with FR-11 / MIT-011 sequential-atomicity contract"
depends_on: ["T01"]
---

## Prerequisites

- T01 has landed `scripts/lifecycle/wiki-init.sh` as an executable file. Verified by `[ -x scripts/lifecycle/wiki-init.sh ]`. Behavioral contract: `bash scripts/lifecycle/wiki-init.sh --project-dir <dir>` runs the FR-5 default scope; exit codes are 0 (success), 2 (argument error), 3 (toolchain missing), 4 (git remote missing), 5 (`--with-giscus` / `--deploy` reserved for P03), 6 (bundle staging failure).
- `commands/init.md` exists at the orchestrator-repo root as the canonical `orchestrator:init` command document (pre-M032). Verified by `[ -f commands/init.md ]` and `grep -q '^# orchestrator:init' commands/init.md`.
- `scripts/lifecycle/init-project.sh` exists, is executable, and implements the `orchestrator:init` flow. Verified by `[ -x scripts/lifecycle/init-project.sh ]`.
- The pre-M032 `init-project.sh` accepts `--project-dir` (or equivalent positional/flag mode) and writes `<PROJECT_DIR>/.orchestrator/`, `<PROJECT_DIR>/CLAUDE.md` (or runtime-equivalent), and other init artifacts. T02 amends this script additively — pre-M032 invocations without `--with-wiki` MUST behave byte-identically.
- T02 entry: `scripts/lifecycle/wiki-init.sh` exists (T01 deliverable). `commands/init.md` and `scripts/lifecycle/init-project.sh` carry NO `--with-wiki` reference yet.

## Description

T02 lands the M033/P05 integration contract per CON-3. The contract has three load-bearing parts per FR-11 and MIT-011:

1. **Flag chain recognition**: `init --with-wiki [--with-giscus] [--deploy]` is recognized by both `commands/init.md` (operator-facing documentation) and `scripts/lifecycle/init-project.sh` (the implementation).

2. **Sequential atomicity**: `init-project.sh` writes its outputs FIRST. ONLY after `init-project.sh`'s outputs are on disk does `wiki-init.sh` run as a SECOND step. The two scripts run sequentially, not atomically — the `init --with-wiki` compound command is NOT a single transaction.

3. **Failure propagation**: If `wiki-init.sh` exits non-zero, the init outputs are PRESERVED on disk, the compound command exit code is the LITERAL exit code of `wiki-init.sh` (NOT 0, NOT 1 unless wiki-init exited with 1), and the diagnostic on stderr names `init-complete, wiki-pending` as the partial state. Callers (M033/P05) can re-run `wiki-init.sh` independently without re-running `init-project.sh`.

The atomicity model is sequential-not-atomic per MIT-011 because (a) atomic rollback of `init-project.sh`'s outputs on `wiki-init` failure would conflict with the operator's expectation that `.orchestrator/` is durable across re-runs, and (b) re-running `init-project.sh` against an already-init'd project is the more dangerous shape (forgetting flags, overwriting custom configs) than leaving the project in `init-complete, wiki-pending` and letting the operator re-run `wiki-init.sh` directly.

The `--with-giscus` and `--deploy` flags are pass-through plumbing in P02 — they are forwarded to `wiki-init.sh` verbatim, but `wiki-init.sh` itself rejects them with exit code 5 in P02 (P03 implements those scopes). T02 still wires the pass-through so M033/P05 can plan against the stable surface; the pass-through is verified by Seam-B (T05) which exercises the failure path with `M032_WIKI_INIT_FORCE_EXIT=7` injection.

## Steps

1. **Read the pre-M032 `commands/init.md`** to identify the section headers and the existing flag-documentation block. Confirm the MEM012 structure (frontmatter, Title, Prerequisites, Core Workflow, Output, Idempotency, Error Handling, Referenced Scripts).

2. **Amend `commands/init.md`** by adding a `--with-wiki` flag-documentation block to the Core Workflow section. Required additions (verbatim text — agents MUST NOT paraphrase):

```markdown
### Wiki integration via `--with-wiki [--with-giscus] [--deploy]` (FR-11 / MIT-011)

`orchestrator:init --with-wiki` runs the default `init` flow first, then invokes
`scripts/lifecycle/wiki-init.sh` as a second sequential step against the same
`--project-dir`. The two scripts run sequentially, not atomically — the
`init --with-wiki` compound command is NOT a single transaction.

**Sequential-atomicity contract (MIT-011)**:

- `init-project.sh` writes its outputs first (`.orchestrator/`, `CLAUDE.md`, etc.).
- `wiki-init.sh` runs second ONLY if `init-project.sh` exits 0.
- If `wiki-init.sh` exits non-zero:
  - The init outputs are PRESERVED on disk.
  - The compound `init --with-wiki` exit code is the LITERAL exit code of
    `wiki-init.sh` (NOT 0, NOT 1 unless wiki-init exited 1).
  - The stderr diagnostic names the partial state explicitly: `init-complete, wiki-pending`.
- Callers (including M033/P05 per CON-3) MAY re-run `wiki-init.sh` independently
  without re-running `init-project.sh` to complete initialization.

**Pass-through flags**:

- `--with-giscus` — recognized by `init-project.sh` and forwarded verbatim to
  `wiki-init.sh`. P02 surface: `wiki-init.sh` rejects with exit code 5
  (`not yet implemented in P02; reserved for P03`). P03 implements the scope.
- `--deploy` — recognized by `init-project.sh` and forwarded verbatim to
  `wiki-init.sh`. Same P02-rejects / P03-implements pattern.

The flag chain is independently composable: `--with-wiki` may appear without
`--with-giscus` or `--deploy`; `--with-giscus` REQUIRES `--with-wiki` (rejected
otherwise); `--deploy` REQUIRES `--with-wiki` (rejected otherwise).
```

Also append to the Referenced Scripts section: `- scripts/lifecycle/wiki-init.sh — wiki-init flow invoked under --with-wiki (FR-11).`

3. **Read the pre-M032 `scripts/lifecycle/init-project.sh`** to identify (a) the argument-parsing loop, (b) the point where init outputs are confirmed on disk, (c) the script's exit point. Locate the canonical "post-init success" point — typically the final `echo "init: done"` or equivalent — and plan the `--with-wiki` invocation immediately before that final exit.

4. **Amend `scripts/lifecycle/init-project.sh`** to recognize the three flags and dispatch `wiki-init.sh` as a second sequential step. Insert the following structure (adapt to the existing argument-parsing style — bash 3.2 compatible per MEM001):

```bash
# In the argument-parsing block, add:
WITH_WIKI=0
WITH_GISCUS=0
WITH_DEPLOY=0

# In the case statement, add:
    --with-wiki) WITH_WIKI=1; shift ;;
    --with-giscus) WITH_GISCUS=1; shift ;;
    --deploy) WITH_DEPLOY=1; shift ;;

# Validate flag composition:
if [ "$WITH_GISCUS" = "1" ] && [ "$WITH_WIKI" != "1" ]; then
  echo "FAIL: init: --with-giscus requires --with-wiki" >&2
  exit 2
fi
if [ "$WITH_DEPLOY" = "1" ] && [ "$WITH_WIKI" != "1" ]; then
  echo "FAIL: init: --deploy requires --with-wiki" >&2
  exit 2
fi

# AT THE END of the script, AFTER all init-project.sh outputs are on disk
# AND AFTER the canonical "init: done" success message, BEFORE the final exit:
if [ "$WITH_WIKI" = "1" ]; then
  WIKI_INIT_ARGS="--project-dir $PROJECT_DIR"
  if [ "$WITH_GISCUS" = "1" ]; then WIKI_INIT_ARGS="$WIKI_INIT_ARGS --with-giscus"; fi
  if [ "$WITH_DEPLOY" = "1" ]; then WIKI_INIT_ARGS="$WIKI_INIT_ARGS --deploy"; fi
  # Run wiki-init.sh as a second sequential step.
  # FR-11 / MIT-011 sequential-atomicity contract:
  #   - init outputs are already on disk above this line.
  #   - if wiki-init.sh exits non-zero we preserve those outputs and propagate
  #     wiki-init.sh's exit code as our exit code with init-complete, wiki-pending
  #     diagnostic on stderr.
  set +e
  bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" $WIKI_INIT_ARGS
  WIKI_INIT_RC=$?
  set -e
  if [ "$WIKI_INIT_RC" != "0" ]; then
    echo "FAIL: init: wiki-init.sh exited $WIKI_INIT_RC; partial state: init-complete, wiki-pending" >&2
    echo "      re-run wiki-init independently: bash scripts/lifecycle/wiki-init.sh --project-dir $PROJECT_DIR" >&2
    exit "$WIKI_INIT_RC"
  fi
fi

exit 0
```

The exact insertion points depend on the pre-M032 `init-project.sh` body — adapt around the existing structure WITHOUT removing or restructuring pre-existing init logic. The `--with-wiki` block MUST be the LAST step before the final `exit 0`.

5. **Test the M032_WIKI_INIT_FORCE_EXIT failure-injection seam** (Seam-B groundwork; the seam itself is T05). Add a test-only escape hatch to `wiki-init.sh` (T01 deliverable) — but since T01 may not have included it, T02 needs to verify whether the hatch exists and either (a) confirm T01 already added it OR (b) amend `wiki-init.sh` minimally to add it as a co-deliverable of T02. The hatch:

```bash
# At the top of wiki-init.sh, after argument parsing, BEFORE the toolchain probe:
if [ -n "${M032_WIKI_INIT_FORCE_EXIT:-}" ]; then
  echo "FAIL: wiki-init: M032_WIKI_INIT_FORCE_EXIT=$M032_WIKI_INIT_FORCE_EXIT (test-only failure injection)" >&2
  exit "$M032_WIKI_INIT_FORCE_EXIT"
fi
```

If T01's `wiki-init.sh` already contains this hatch, T02 leaves it alone. Otherwise T02 adds it as a minimal test-only co-deliverable (the hatch is necessary for Seam-B in T05; landing it in T01 vs T02 is implementation choice — RECOMMENDED to land in T01 so T02 has no `wiki-init.sh` modifications).

6. **Author the T02 verifier** at `tools/verify/m032-p02-init-with-wiki-passthrough.sh`. The verifier exercises:
   - **Default-passthrough success path**: stage a fresh fixture via `mktemp -d` + the P01 fresh-project-fixture pattern (init the .git + remote); run `bash scripts/lifecycle/init-project.sh --with-wiki --project-dir <tmp>`; assert exit 0; assert `<tmp>/.orchestrator/` exists (init outputs present); assert `<tmp>/wiki/mkdocs.yml` exists (wiki-init outputs present).
   - **Failure-propagation path**: stage another fresh fixture; run `M032_WIKI_INIT_FORCE_EXIT=7 bash scripts/lifecycle/init-project.sh --with-wiki --project-dir <tmp>`; assert exit code 7 (literal); assert `<tmp>/.orchestrator/` exists (init outputs preserved); assert stderr contains `init-complete, wiki-pending`; assert `<tmp>/wiki/mkdocs.yml` does NOT exist (wiki-init aborted).
   - **Composition-error path**: run `bash scripts/lifecycle/init-project.sh --with-giscus --project-dir <tmp>` (without `--with-wiki`); assert exit code 2; assert stderr contains `--with-giscus requires --with-wiki`.
   - **Pre-M032 byte-identical path**: run `bash scripts/lifecycle/init-project.sh --project-dir <tmp>` (no `--with-` flags); assert exit 0; assert `<tmp>/wiki/` does NOT exist (wiki-init not invoked).

   Single-script-file shape per AD-19 — no inline `bash -c '...' && bash -c '...'` chains, no `$()` containing pipes. Skeleton:

```bash
#!/usr/bin/env bash
set -eu
TMPROOT="$(mktemp -d)"
trap 'rm -rf "$TMPROOT"' EXIT

# helper: bootstrap a fresh fixture into a given tmp directory
bootstrap_fixture() {
  local dir="$1"
  cp -R tests/fixtures/m032-fresh-project-fixture/ "$dir/"
  ( cd "$dir" && git init -q && git remote add origin https://github.com/fixture-owner/m032-fresh-project-fixture.git ) >/dev/null 2>&1 || true
}
# Note: the subshell above with the pipe-free chain is permissible because it is
# inside a function body the Verifier runs once; AD-19 forbids inline bash -c
# compound chains in the parent's Check command, NOT subshells inside helper
# function bodies that do not contain pipes within $().

# Test 1: default passthrough success
TMP1="$TMPROOT/test1"
bootstrap_fixture "$TMP1"
if ! bash scripts/lifecycle/init-project.sh --with-wiki --project-dir "$TMP1" >/dev/null 2>&1; then
  echo "FAIL: init --with-wiki exited non-zero on default passthrough"; exit 1
fi
[ -d "$TMP1/.orchestrator" ] || { echo "FAIL: init outputs missing"; exit 1; }
[ -f "$TMP1/wiki/mkdocs.yml" ] || { echo "FAIL: wiki-init outputs missing"; exit 1; }

# Test 2: failure propagation
TMP2="$TMPROOT/test2"
bootstrap_fixture "$TMP2"
M032_WIKI_INIT_FORCE_EXIT=7 bash scripts/lifecycle/init-project.sh --with-wiki --project-dir "$TMP2" >/dev/null 2>"$TMPROOT/test2.err"
RC=$?
[ "$RC" = "7" ] || { echo "FAIL: failure-propagation expected rc=7 got rc=$RC"; exit 1; }
[ -d "$TMP2/.orchestrator" ] || { echo "FAIL: init outputs not preserved on wiki-init failure"; exit 1; }
grep -q 'init-complete, wiki-pending' "$TMPROOT/test2.err" || { echo "FAIL: missing init-complete, wiki-pending diagnostic"; exit 1; }
[ ! -f "$TMP2/wiki/mkdocs.yml" ] || { echo "FAIL: wiki-init outputs present despite forced failure"; exit 1; }

# Test 3: composition error
TMP3="$TMPROOT/test3"
bootstrap_fixture "$TMP3"
set +e
bash scripts/lifecycle/init-project.sh --with-giscus --project-dir "$TMP3" >/dev/null 2>"$TMPROOT/test3.err"
RC=$?
set -e
[ "$RC" = "2" ] || { echo "FAIL: composition error expected rc=2 got rc=$RC"; exit 1; }
grep -q 'requires --with-wiki' "$TMPROOT/test3.err" || { echo "FAIL: missing composition-error diagnostic"; exit 1; }

# Test 4: pre-M032 byte-identical
TMP4="$TMPROOT/test4"
bootstrap_fixture "$TMP4"
bash scripts/lifecycle/init-project.sh --project-dir "$TMP4" >/dev/null 2>&1 || { echo "FAIL: pre-M032 init invocation failed"; exit 1; }
[ ! -d "$TMP4/wiki" ] || { echo "FAIL: wiki/ directory present despite no --with-wiki"; exit 1; }

echo "PASS: m032-p02-init-with-wiki-passthrough"
```

7. **Run the T02 verifier locally** to confirm exit 0.

## Must-Haves

- `commands/init.md` carries the `--with-wiki [--with-giscus] [--deploy]` flag-chain documentation block per step 2 with the FR-11 / MIT-011 sequential-atomicity contract documented verbatim.
- `scripts/lifecycle/init-project.sh` recognizes the three flags, validates the composition rule (`--with-giscus` and `--deploy` REQUIRE `--with-wiki`), invokes `wiki-init.sh` as a second sequential step ONLY when `--with-wiki` is present, preserves init outputs on `wiki-init` failure, propagates `wiki-init.sh`'s literal exit code as the compound exit code, and emits the `init-complete, wiki-pending` diagnostic on stderr on `wiki-init` failure.
- Pre-M032 invocations of `init-project.sh` (no `--with-` flags) behave byte-identically to the pre-T02 state.
- The T02 verifier at `tools/verify/m032-p02-init-with-wiki-passthrough.sh` exists, is executable, and exits 0 against the T02-landed surface (default-passthrough, failure-propagation, composition-error, pre-M032-byte-identical).

## Verification

```bash
bash tools/verify/m032-p02-init-with-wiki-passthrough.sh
```

## Inputs

### From Previous Tasks

- `scripts/lifecycle/wiki-init.sh` (from T01) — invoked as a second sequential step under `--with-wiki`. Key API: `bash wiki-init.sh --project-dir <dir> [--with-giscus] [--deploy] [--site-name <name>] [--site-description <desc>] [--auto-pip] [--force]`. Exit codes: 0 (success or no-changes idempotency), 2 (argument error), 3 (toolchain missing), 4 (git remote missing), 5 (P03 flag passed in P02), 6 (bundle staging failure). Test-only escape: `M032_WIKI_INIT_FORCE_EXIT=<n>` exits `<n>` immediately (used by Seam-B in T05).

### From Disk (Pre-existing)

- `commands/init.md` — pre-M032 `orchestrator:init` command document. Carries the seven MEM012 sections; T02 amends Core Workflow + Referenced Scripts only.
- `scripts/lifecycle/init-project.sh` — pre-M032 init implementation. Carries the existing argument-parsing loop and init-output-writing logic; T02 amends the argument loop with three new flags and appends the `--with-wiki` dispatch block at the end of the script.
- `tests/fixtures/m032-fresh-project-fixture/` — P01 shared fixture used by T02's verifier.

## Constraints

- T02 MUST NOT modify the pre-M032 `init-project.sh` core flow — pre-T02 invocations without `--with-wiki` MUST behave byte-identically. Any pre-existing argument parsing, init-output-writing, or exit logic MUST be preserved.
- T02 MUST NOT remove any pre-M032 sections from `commands/init.md` — the amendment is purely additive.
- The `wiki-init.sh` invocation MUST run AFTER `init-project.sh`'s outputs are confirmed on disk per FR-11 / MIT-011 sequential-atomicity. If T02's amendment places the dispatch block too early (before init outputs are written) the failure-propagation verifier (test 2) fails because the `.orchestrator/` directory check fails after `M032_WIKI_INIT_FORCE_EXIT=7` injection.
- Bash 3.2 compatibility per MEM001 — no `local` outside functions, no `mapfile`, no `declare -A`, no process substitution.
- Single-script-file shape per AD-19 in the T02 verifier — helper functions are fine, but `Check:` invocations and inline compound bash chains with pipes MUST be avoided.
- T02's amendment to `wiki-init.sh` (the `M032_WIKI_INIT_FORCE_EXIT` test-only escape) is the ONLY allowed modification to `wiki-init.sh` — if T01 already landed the escape, T02 adds nothing.
- The `--with-giscus` / `--deploy` validation MUST reject the flag-without-`--with-wiki` shape with exit code 2 — NOT exit 5 (5 is reserved for P03 reject within `wiki-init.sh` itself; the composition-error within `init-project.sh` is a different failure shape).

## Expected Output

After T02 completes:

- `commands/init.md` carries the new `--with-wiki [--with-giscus] [--deploy]` flag-chain documentation block.
- `scripts/lifecycle/init-project.sh` recognizes the three flags, validates composition, dispatches `wiki-init.sh` as a second sequential step, and propagates failure correctly.
- `tools/verify/m032-p02-init-with-wiki-passthrough.sh` exists, is executable, and exits 0 against four test scenarios (default-passthrough, failure-propagation, composition-error, pre-M032-byte-identical).
- M033/P05 has the stable `--with-wiki` surface to plan against per CON-3.

## Notes

- Expected verifier output: `PASS: m032-p02-init-with-wiki-passthrough` to stdout on exit 0.
- Plan-time discipline rule 2 (verifier-availability cross-check): the single verifier cited in `## Verification` is co-authored within this task in step 6.
- Plan-time discipline rule 6 (path-collision check): `tools/verify/m032-p02-init-with-wiki-passthrough.sh` does NOT exist on disk at plan-authoring time (verified). `commands/init.md` and `scripts/lifecycle/init-project.sh` are explicitly modified, not created.
- The `M032_WIKI_INIT_FORCE_EXIT` test-only escape is the seam Seam-B (T05) exercises to validate the FR-11 / MIT-011 contract under failure injection. The escape MUST NOT be exposed in operator UX (no flag, no positional arg) — env-var-only access keeps it out of the operator-facing surface per the M026/MEM030 `<TOOL>_EDITION=<value>` env-var convention pattern.
- Seam-B (T05) imports the same failure-propagation contract; T02's verifier is a tighter unit-test of the same surface.
