---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M012"
name: "scripts/wiki/wiki-deploy.sh — chained deploy wrapper"
depends_on: ["T02"]
---

## Prerequisites

- T01 complete: `wiki/docs/index.md` finalized (the deploy wrapper builds the site that this page leads).
- T02 complete: `wiki/README.md` carries `## First-deploy checklist` and `## Running the deploy wrapper` sections — the wrapper's `--help` output points operators at these headings by name.
- P01 complete: `scripts/wiki/wiki-serve.sh` lives under `scripts/wiki/`; `scripts/wiki/wiki-deploy.sh` does not yet exist. The `wiki/mkdocs.yml` base config is in place.
- P02 complete: `scripts/diagnostics/wiki-link-check.sh` exists with `--site`, `--root`, `--help` flags and the 0 / 1 / 2 exit-code contract.
- P03 complete: `scripts/diagnostics/wiki-giscus-config-check.sh` exists (Bash 3.2, exit 0 on all-set, exit 1 on any-unset, `--help` and `--quiet` flags). `scripts/diagnostics/wiki-giscus-smoke.sh` exists with `--site`, `--root`, `--help` flags and the 0 / 1 / 2 exit-code contract.

## Description

Ship the single documented deploy command for the dogfood wiki. The wrapper exists because a bare `mkdocs gh-deploy --force` would silently deploy an empty-Giscus site (no env vars) or a site with broken internal links (build plugin doesn't walk rendered HTML). Chaining gate-shaped diagnostics in front of the deploy catches those classes of failure before they land on `gh-pages`.

Contract: four pre-deploy gates, each a single-script-file invocation, in order. First non-zero exit aborts the wrapper before `mkdocs gh-deploy` runs. The wrapper is Bash 3.2 compliant and the harness-safe shape guard applies — agent-facing (Check:) invocations of the wrapper must be single script-file shape; the wrapper's internals may use pipes, subshells, `$()`-composition (MEM004 carve-out applies to `scripts/wiki/` and `scripts/diagnostics/` internals).

Out of scope for this task: running the actual deploy (T04), shipping the verify gates that assert on this wrapper (T05), modifying any of the upstream diagnostics (P02/P03 owned).

## Steps

1. **Create `scripts/wiki/wiki-deploy.sh`** with exactly this shape — add `chmod +x` via the file creation. Bash 3.2 compliant; parallel indexed arrays; no `declare -A`; no process substitution; no `mapfile`:

   ```bash
   #!/usr/bin/env bash
   # scripts/wiki/wiki-deploy.sh — M012/P04/T03 chained deploy wrapper.
   #
   # Runs the four pre-deploy gates in order:
   #   1. scripts/diagnostics/wiki-giscus-config-check.sh   (env-var loud-fail)
   #   2. mkdocs build -f wiki/mkdocs.yml                   (render to wiki/site/)
   #   3. scripts/diagnostics/wiki-link-check.sh --site     (built-HTML walker)
   #   4. scripts/diagnostics/wiki-giscus-smoke.sh --site   (Giscus presence)
   # Then, on live path: mkdocs gh-deploy --force -f wiki/mkdocs.yml
   # (pushes wiki/site/ to the gh-pages branch).
   #
   # Any non-zero exit from any gate aborts before gh-deploy runs.
   # See wiki/README.md "Running the deploy wrapper" for the full
   # contract + failure-triage table.
   #
   # Flags:
   #   --dry-run       run gates, skip gh-deploy, exit 0 on all PASS
   #   --help          print usage and exit 0
   #   --root <dir>    override project root (default: invocation cwd)
   #   --skip-smoke    skip gate (4) only (not recommended)
   #
   # Exit codes:
   #   0 — all gates PASS and (live path) gh-deploy exit 0
   #   1 — any gate FAIL, build fail, or gh-deploy fail
   #   2 — usage error
   #
   # Bash 3.2 compliant. No declare -A. No process substitution.

   set -u

   # -------- usage / help --------
   usage() {
     cat <<'USAGE'
   Usage: bash scripts/wiki/wiki-deploy.sh [--dry-run] [--help] [--root DIR] [--skip-smoke]

   Chains the four pre-deploy gates in order:
     1. scripts/diagnostics/wiki-giscus-config-check.sh
     2. mkdocs build -f wiki/mkdocs.yml
     3. scripts/diagnostics/wiki-link-check.sh --site wiki/site
     4. scripts/diagnostics/wiki-giscus-smoke.sh --site wiki/site

   Then (live path only): mkdocs gh-deploy --force -f wiki/mkdocs.yml

   Flags:
     --dry-run      Run gates, skip gh-deploy, exit 0 on all PASS.
     --help         Print this usage and exit 0.
     --root DIR     Override project root (default: invocation cwd).
     --skip-smoke   Skip gate (4) only. Not recommended for production.

   See wiki/README.md "First-deploy checklist" and "Running the deploy
   wrapper" sections for the full operator contract.
   USAGE
   }

   # -------- flag parsing (Bash 3.2 safe; no while case across shifts > 1) --------
   DRY_RUN=0
   SKIP_SMOKE=0
   ROOT=""

   while [ $# -gt 0 ]; do
     case "$1" in
       --dry-run)     DRY_RUN=1 ;;
       --skip-smoke)  SKIP_SMOKE=1 ;;
       --help|-h)     usage; exit 0 ;;
       --root)
         if [ $# -lt 2 ]; then
           printf 'ERROR: --root requires a directory argument\n' >&2
           exit 2
         fi
         ROOT="$2"
         shift
         ;;
       *)
         printf 'ERROR: unknown flag: %s\n' "$1" >&2
         usage >&2
         exit 2
         ;;
     esac
     shift
   done

   # -------- resolve root --------
   if [ -z "$ROOT" ]; then
     SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
     ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
   fi
   if [ ! -d "$ROOT" ]; then
     printf 'ERROR: --root %s is not a directory\n' "$ROOT" >&2
     exit 2
   fi

   cd "$ROOT"

   # -------- gate 1: giscus config-check --------
   if bash scripts/diagnostics/wiki-giscus-config-check.sh --quiet; then
     printf 'GATE: giscus-config PASS\n'
   else
     printf 'GATE: giscus-config FAIL\n'
     printf 'FAIL: giscus-config — one or more GISCUS_* env vars unset. See wiki/README.md "First-deploy checklist".\n' >&2
     exit 1
   fi

   # -------- gate 2: mkdocs build --------
   if command -v mkdocs >/dev/null 2>&1; then
     if mkdocs build -f wiki/mkdocs.yml >/dev/null; then
       printf 'BUILD: ok\n'
     else
       printf 'BUILD: fail\n'
       printf 'FAIL: mkdocs build — see mkdocs output above.\n' >&2
       exit 1
     fi
   else
     printf 'BUILD: skip (mkdocs not installed)\n'
     if [ "$DRY_RUN" -eq 0 ]; then
       printf 'FAIL: mkdocs not installed; cannot deploy.\n' >&2
       exit 1
     fi
   fi

   # -------- gate 3: link-check --------
   if [ -d wiki/site ]; then
     if bash scripts/diagnostics/wiki-link-check.sh --site wiki/site; then
       printf 'GATE: link-check PASS\n'
     else
       printf 'GATE: link-check FAIL\n'
       printf 'FAIL: link-check — see BROKEN: lines above.\n' >&2
       exit 1
     fi
   else
     printf 'GATE: link-check SKIP (no wiki/site/)\n'
   fi

   # -------- gate 4: giscus smoke --------
   if [ "$SKIP_SMOKE" -eq 1 ]; then
     printf 'GATE: giscus-smoke SKIP (--skip-smoke)\n'
   elif [ -d wiki/site ]; then
     if bash scripts/diagnostics/wiki-giscus-smoke.sh --site wiki/site; then
       printf 'GATE: giscus-smoke PASS\n'
     else
       printf 'GATE: giscus-smoke FAIL\n'
       printf 'FAIL: giscus-smoke — one or more pages missing the Giscus loader.\n' >&2
       exit 1
     fi
   else
     printf 'GATE: giscus-smoke SKIP (no wiki/site/)\n'
   fi

   # -------- deploy (live path only) --------
   if [ "$DRY_RUN" -eq 1 ]; then
     printf 'DRY-RUN: would deploy\n'
     exit 0
   fi

   printf 'DEPLOY: pushing to gh-pages\n'
   if mkdocs gh-deploy --force -f wiki/mkdocs.yml; then
     printf 'OK: deployed to gh-pages\n'
     exit 0
   else
     printf 'FAIL: mkdocs gh-deploy exited non-zero.\n' >&2
     exit 1
   fi
   ```

2. **`chmod +x scripts/wiki/wiki-deploy.sh`** so the wrapper is directly executable (matching the convention of `scripts/wiki/wiki-serve.sh`).

3. **Verify the wrapper contract manually** (not wired as a Check):

   ```
   bash scripts/wiki/wiki-deploy.sh --help
   ```

   Expect the usage block naming each of the four chained gates and each of the four flags.

   ```
   GISCUS_REPO=x GISCUS_REPO_ID=x GISCUS_CATEGORY=x GISCUS_CATEGORY_ID=x \
     bash scripts/wiki/wiki-deploy.sh --dry-run
   ```

   Expect `GATE: giscus-config PASS`, `BUILD: ...`, `GATE: link-check ...`, `GATE: giscus-smoke ...`, and `DRY-RUN: would deploy` as the terminator. Exit 0.

   ```
   unset GISCUS_REPO_ID
   GISCUS_REPO=x GISCUS_CATEGORY=x GISCUS_CATEGORY_ID=x \
     bash scripts/wiki/wiki-deploy.sh --dry-run
   ```

   Expect `GATE: giscus-config FAIL` and exit 1.

4. **Do not** modify the upstream diagnostics. Do not add a new flag to any P02/P03-owned script. The wrapper consumes them via their existing public contracts.

## Must-Haves

- `scripts/wiki/wiki-deploy.sh` exists, is ≥ 120 lines, is executable (mode `0755`), and contains:
  - The literal string `mkdocs gh-deploy`
  - The literal string `wiki-giscus-config-check.sh`
  - The literal string `wiki-link-check.sh`
  - The literal string `wiki-giscus-smoke.sh`
  - A `usage()` function whose heredoc names each of the four flags (`--dry-run`, `--help`, `--root`, `--skip-smoke`)
  - Exit-code `0`/`1`/`2` paths matching the contract
  - `set -u` enabled (no `set -e` — explicit exit codes per gate are clearer)
- The wrapper does **not** contain:
  - `declare -A`
  - `mapfile` / `readarray`
  - `${var^^}` / `${var,,}`
  - `<(…)` or `>(…)` process substitution
  - `&>` merge redirect (in non-comment code)

## Verification

- Check: `bash scripts/verify/m012-p04-deploy-wrapper-contract.sh`
- Check: `bash scripts/verify/m012-p04-deploy-wrapper-help.sh`
- Check: `bash scripts/verify/m012-p04-deploy-wrapper-dry-run.sh`
- Check: `bash scripts/verify/m012-p04-deploy-wrapper-loud-fail.sh`
- Check: `bash scripts/verify/m012-p04-bash32-compat.sh`
- Check: `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P04`

## Inputs

### From Previous Tasks

- `wiki/README.md` (from T02) — carries the `## First-deploy checklist` and `## Running the deploy wrapper` sections. The wrapper's `--help` heredoc points operators at these headings by literal heading name.

### From Disk (Pre-existing)

- `scripts/diagnostics/wiki-giscus-config-check.sh` (P03) — invoked with `--quiet`. Exit 0 = all-set, exit 1 = any-unset. No stdout noise on success when `--quiet`.
- `scripts/diagnostics/wiki-link-check.sh` (P02) — invoked with `--site wiki/site`. Exit 0 = zero broken in-scope links, exit 1 = one or more broken, exit 2 = usage error.
- `scripts/diagnostics/wiki-giscus-smoke.sh` (P03) — invoked with `--site wiki/site`. Exit 0 = every page carries the loader, exit 1 = any page missing, exit 2 = usage error.
- `wiki/mkdocs.yml` (P01+P02+P03) — the config file `mkdocs build` and `mkdocs gh-deploy` read. The wrapper references it by `-f wiki/mkdocs.yml`.
- MkDocs CLI (external) — `mkdocs build` renders the site under `wiki/site/`. `mkdocs gh-deploy --force` pushes that directory to the `gh-pages` branch. Both read configuration from the `-f` argument. If `mkdocs` is absent, the wrapper's build gate skips gracefully under `--dry-run` but fails the live path.

## Constraints

- **AD-3 SSOT** — the wrapper does not rewrite `.orchestrator/**.md` artifacts. It composes existing diagnostics.
- **AD-19 single-script-file Check shape** — the phase-plan Truth `Check:` commands that invoke the wrapper stay single-invocation; all compound logic lives inside this script file.
- **Constitution VIII (Bash 3.2)** — enforced by `m012-p04-bash32-compat.sh` (T05). No Bash 4+ features anywhere in the wrapper.
- **Constitution XIV (no speculative complexity)** — the wrapper chains exactly four gates. No configuration file, no YAML driver, no plugin system. Flags are the four named above.
- **Constitution XV (surgical precision)** — T03 creates exactly one new file (`scripts/wiki/wiki-deploy.sh`). No upstream diagnostics are modified.
- **Loud failure** — every gate failure prints a `FAIL:` line on stderr naming the gate. No silent aborts.
- **Idempotent helper** — rerunning the wrapper after a successful deploy is safe: the Giscus config-check is read-only, `mkdocs build` is reproducible, link-check is read-only, smoke is read-only, and `mkdocs gh-deploy --force` will force-push the same content if nothing changed. No state lock file needed.

## Expected Output

- `scripts/wiki/wiki-deploy.sh` exists, is executable, is Bash 3.2 compatible, and chains the four P02/P03 diagnostics in order before `mkdocs gh-deploy --force`.
- `bash scripts/wiki/wiki-deploy.sh --help` exits 0 and prints a usage block naming each gate basename and each supported flag.
- `bash scripts/wiki/wiki-deploy.sh --dry-run` under a fixture env with all four `GISCUS_*` vars set to `"x"` exits 0 with the four `GATE: ... PASS` lines (or `SKIP` where mkdocs is absent / wiki/site does not exist) and a `DRY-RUN: would deploy` terminator.
- `bash scripts/wiki/wiki-deploy.sh --dry-run` under a fixture env with `GISCUS_REPO_ID` unset exits 1 with `GATE: giscus-config FAIL`.
- `bash scripts/wiki/wiki-deploy.sh --unknown-flag` exits 2 with a usage-error diagnostic on stderr.
