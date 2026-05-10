---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M012"
name: "wiki-giscus-smoke.sh — built-site HTML walker asserting Giscus script tag on every page"
depends_on: ["T02"]
---

## Prerequisites

- T01 complete: `wiki/overrides/partials/comments.html` renders a `<script src="https://giscus.app/client.js" ...>` tag on every page.
- T02 complete: `scripts/diagnostics/wiki-giscus-config-check.sh` exists; wiki-giscus-smoke.sh's README block cross-references it as the pre-build companion.
- `scripts/diagnostics/` directory exists.

## Description

Ship `scripts/diagnostics/wiki-giscus-smoke.sh` — walks every `*.html` file under a built-site directory and confirms each page contains the Giscus script loader (`src="https://giscus.app/client.js"`). Emits structured output (`PASS:` / `FAIL:` / `SUMMARY:`) and exits 0 iff every page passes. This is the SC-2 verification script and the P04 deploy-pipeline gate.

The smoke script does **not** invoke `mkdocs build` itself. It operates on an already-built site directory — the caller (P04's deploy wrapper, a CI runner, or a developer running `mkdocs build` locally) is responsible for producing the input. This keeps the script fast (walks HTML only), side-effect-free, and invokable from any context including hermetic tests against fixture sites.

Out-of-scope for this task: pre-build env check (T02 — done), remap script (T04), verify gates (T05), deploy wiring (P04).

## Steps

1. **Create `scripts/diagnostics/wiki-giscus-smoke.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/diagnostics/wiki-giscus-smoke.sh — M012/P03 SC-2 smoke test.
   #
   # Walks every *.html under --site <dir> (default wiki/site) and asserts
   # each page contains `src="https://giscus.app/client.js"`. Emits one
   # FAIL: <path> line per offending page plus a PASS/FAIL summary. Bash 3.2.
   #
   # Contract:
   #   --site <dir>      path to the built site (default wiki/site)
   #   --root <dir>      project root (default invocation cwd)
   #   --verbose         emit one OK: <path> per passing page
   #   --help            print usage; exit 0
   #
   # Exit codes:
   #   0  every page carries the Giscus loader tag
   #   1  one or more pages missing the tag
   #   2  usage error / empty site / site directory missing
   #
   # Companion: scripts/diagnostics/wiki-giscus-config-check.sh (pre-build).
   #   — the config-check gates env-var presence BEFORE the build; this
   #     script gates the rendered output AFTER the build. P04 chains both
   #     around `mkdocs gh-deploy`.

   set -u
   set -o pipefail

   PROJECT_ROOT="${PWD}"
   SITE_DIR=""
   verbose=0

   usage() {
     cat <<'USAGE'
   Usage: wiki-giscus-smoke.sh [--site <dir>] [--root <dir>] [--verbose] [--help]

   Walks every *.html under <site> (default wiki/site) and confirms each
   page carries the Giscus loader tag. Intended to run AFTER mkdocs build.
   USAGE
   }

   while [ $# -gt 0 ]; do
     case "$1" in
       --site)    SITE_DIR="$2"; shift 2 ;;
       --root)    PROJECT_ROOT="$2"; shift 2 ;;
       --verbose) verbose=1; shift ;;
       --help|-h) usage; exit 0 ;;
       *) printf 'ERROR: unknown arg: %s\n' "$1" >&2; usage >&2; exit 2 ;;
     esac
   done

   if [ -z "$SITE_DIR" ]; then
     SITE_DIR="$PROJECT_ROOT/wiki/site"
   fi

   if [ ! -d "$SITE_DIR" ]; then
     printf 'ERROR: site directory not found: %s\n' "$SITE_DIR" >&2
     printf 'HINT: run (cd wiki && mkdocs build) first, or pass --site <dir>\n' >&2
     exit 2
   fi

   # Collect pages into a /tmp list file — avoids $() with pipe and
   # avoids |-while (subshell counter loss on some bashes). Bash 3.2 safe.
   list_file="$(mktemp -t wiki-giscus-smoke.XXXXXX)"
   # shellcheck disable=SC2064
   trap "rm -f '$list_file'" EXIT

   find "$SITE_DIR" -type f -name '*.html' -print > "$list_file"

   total=0
   missing=0
   needle='src="https://giscus.app/client.js"'

   while IFS= read -r page; do
     total=$((total + 1))
     if grep -qF "$needle" "$page"; then
       if [ "$verbose" -eq 1 ]; then
         printf 'OK: %s\n' "$page"
       fi
     else
       printf 'FAIL: %s\n' "$page" >&2
       missing=$((missing + 1))
     fi
   done < "$list_file"

   if [ "$total" -eq 0 ]; then
     printf 'ERROR: no .html files under %s\n' "$SITE_DIR" >&2
     exit 2
   fi

   if [ "$missing" -gt 0 ]; then
     printf 'SUMMARY: %d/%d pages missing Giscus loader\n' "$missing" "$total" >&2
     printf 'FAIL: Giscus smoke — %d missing of %d pages (site=%s)\n' "$missing" "$total" "$SITE_DIR" >&2
     exit 1
   fi

   printf 'PASS: %d pages have Giscus (site=%s)\n' "$total" "$SITE_DIR"
   exit 0
   ```

2. **Make it executable**: `chmod 755 scripts/diagnostics/wiki-giscus-smoke.sh`.

3. **Smoke-verify manually** (not wired as a Check):

   - Create a fixture site at `/tmp/fake-site/` with two HTML files, one containing the Giscus loader and one not. Run `bash scripts/diagnostics/wiki-giscus-smoke.sh --site /tmp/fake-site` → exit 1, one `FAIL:` line, `SUMMARY: 1/2`.
   - Replace the second file with a Giscus-carrying page. Rerun → exit 0, `PASS: 2 pages have Giscus`.
   - Run against a non-existent directory → exit 2, `ERROR: site directory not found`.
   - Run against an empty directory → exit 2, `ERROR: no .html files`.

## Must-Haves

- `scripts/diagnostics/wiki-giscus-smoke.sh` exists, executable, ≥ 50 lines, contains the literal `giscus.app/client.js`.
- Script exits 0 when every HTML page under `--site` contains `src="https://giscus.app/client.js"`.
- Script exits 1 when any HTML page is missing the tag, emits one `FAIL: <path>` line per miss on stderr, plus a `SUMMARY:` line.
- Script exits 2 on usage error, missing site directory, or empty site directory.
- Script is Bash 3.2 compatible (no `declare -A`, no `mapfile`, no `<(...)`, no `&>`, no `${var^^}`).
- Script never modifies repo state.
- `--help` exits 0 with usage text on stdout.

## Verification

- `bash scripts/verify/m012-p03-smoke-contract.sh` — PASS (T05 gate; exercises the script against a tmp fixture with both passing and failing pages).
- `bash scripts/verify/m012-p03-bash32-compat.sh` — PASS.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P03` — artifact pattern + line-count pass.

Manual smoke run during this task (do NOT embed as a Check):

1. `tmp=$(mktemp -d); printf '<script src="https://giscus.app/client.js"></script>' > "$tmp/a.html"; bash scripts/diagnostics/wiki-giscus-smoke.sh --site "$tmp"` — expect exit 0. (This shell is a developer action, not a Truth Check.)
2. `printf 'hello' > "$tmp/b.html"; bash scripts/diagnostics/wiki-giscus-smoke.sh --site "$tmp"` — expect exit 1.

## Inputs

### From Previous Tasks

- **T01**: the Giscus partial at `wiki/overrides/partials/comments.html` emits the exact needle `src="https://giscus.app/client.js"` in every rendered page's HTML. This is the string the smoke script greps for — a change to the partial's `src` URL would require a paired update to the smoke script's `needle=` line.
- **T02**: `scripts/diagnostics/wiki-giscus-config-check.sh` — documented as the pre-build companion in this script's header comment. Not sourced; no runtime dependency.

### From Disk (Pre-existing)

- `scripts/diagnostics/` directory.
- A built MkDocs site under `wiki/site/` (produced by `mkdocs build` — not created by this task). If absent, the script exits 2 with a `HINT:` pointing at the build command.

## Constraints

- **Bash 3.2** — MEM001. No associative arrays; a /tmp list file + `while IFS= read -r` replaces any |-while pipeline (subshell counter loss).
- **Read-only** — walks HTML and greps; no edits.
- **MEM004 carve-out** — pipes, `grep -qF`, `find` are permitted inside the diagnostic. Truth Checks that invoke it stay single-script-file (AD-19).
- **No dependency on mkdocs being installed** — the smoke script works on any pre-built HTML tree; skip behavior happens upstream (if no site exists, exit 2 with a HINT).
- **grep -qF literal match** — avoid regex false positives from `?`/`+` in Jinja-expanded attributes.
- **Trap cleanup** — the /tmp list file is removed on EXIT regardless of exit code.
- **Stderr vs stdout** — `PASS:` on stdout; `FAIL:` / `ERROR:` / `HINT:` / `SUMMARY:` on stderr. Matches MEM001.

## Expected Output

- `scripts/diagnostics/wiki-giscus-smoke.sh` exists, executable, ≥ 50 lines, Bash 3.2 compliant.
- `bash scripts/diagnostics/wiki-giscus-smoke.sh --help` — exit 0, usage on stdout.
- Against a built site with Giscus on every page: exit 0, `PASS: N pages have Giscus` on stdout.
- Against a site with any missing page: exit 1, one `FAIL: <path>` per miss + `SUMMARY:` on stderr.
- Against a missing / empty site dir: exit 2 with `ERROR:` + `HINT:` on stderr.
