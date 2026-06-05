---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M043"
name: "wiki-deploy.sh target-aware URL (FR-5) + phase-suite aggregator"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- `scripts/wiki/wiki-deploy.sh` exists with the FR-20 post-gate URL-print tail (~lines 271–279): `printf 'OK: pre-deploy gates PASS. Push to main...'` → `git push origin main` → an OWNER/REPO-conditional `actions/workflows/pages.yml` URL print → `exit 0`. `OWNER`/`REPO` are resolved just above (~242–264); `ROOT` is the project root. NOTE: wiki-deploy.sh does NOT define `REPO_ROOT` (only `ROOT`, and `SCRIPT_DIR` inside one branch), and it runs under `set -u` — so reference the sibling resolver via `"$(dirname "$0")/resolve-deploy-target.sh"` (the same idiom used at line ~96), NOT `$REPO_ROOT/...` which would be an unbound-variable fatal under set -u.
- `scripts/wiki/resolve-deploy-target.sh` exists (T01).
- The three other P01 verifiers exist (T01/T02/T03) — the phase-suite references them.

## Description

Make wiki-deploy.sh print the target-appropriate workflow URL (FR-5): for `cloudflare-access`, print the `wiki-cloudflare.yml` URL plus a "gates identical across targets" line (US-1 acceptance scenario 4); for `github-pages`, keep the post-gate output **byte-identical** to pre-M043 (CON-4). The four pre-deploy gates already run identically for both targets — this task only branches the final URL print. Then author the phase-suite aggregator that runs all four P01 gates.

## Steps

1. **Branch the URL-print tail in `scripts/wiki/wiki-deploy.sh`.** Use the Edit tool. Insert the cloudflare branch BEFORE the existing github-pages print block, leaving that block verbatim:

   - `old_string`:
     ```
     printf 'OK: pre-deploy gates PASS. Push to main to trigger workflow deploy:\n'
     printf '    git push origin main\n'
     printf '\n'
     if [ -n "${OWNER:-}" ] && [ -n "${REPO:-}" ]; then
       printf 'Workflow run: https://github.com/%s/%s/actions/workflows/pages.yml\n' "$OWNER" "$REPO"
     else
       printf 'Workflow run: https://github.com/<owner>/<repo>/actions/workflows/pages.yml (set OWNER/REPO env vars for repo-specific URL)\n'
     fi
     exit 0
     ```
   - `new_string`:
     ```
     # M043 FR-5 — target-aware workflow URL. The four pre-deploy gates above run
     # identically for both targets; only the printed workflow file differs.
     M043_DEPLOY_TARGET="$(bash "$(dirname "$0")/resolve-deploy-target.sh" "$ROOT" 2>/dev/null || echo github-pages)"
     if [ "$M043_DEPLOY_TARGET" = "cloudflare-access" ]; then
       printf 'OK: pre-deploy gates PASS (identical across targets). Push to main to trigger workflow deploy:\n'
       printf '    git push origin main\n'
       printf '\n'
       if [ -n "${OWNER:-}" ] && [ -n "${REPO:-}" ]; then
         printf 'Workflow run: https://github.com/%s/%s/actions/workflows/wiki-cloudflare.yml\n' "$OWNER" "$REPO"
       else
         printf 'Workflow run: https://github.com/<owner>/<repo>/actions/workflows/wiki-cloudflare.yml (set OWNER/REPO env vars for repo-specific URL)\n'
       fi
       exit 0
     fi
     printf 'OK: pre-deploy gates PASS. Push to main to trigger workflow deploy:\n'
     printf '    git push origin main\n'
     printf '\n'
     if [ -n "${OWNER:-}" ] && [ -n "${REPO:-}" ]; then
       printf 'Workflow run: https://github.com/%s/%s/actions/workflows/pages.yml\n' "$OWNER" "$REPO"
     else
       printf 'Workflow run: https://github.com/<owner>/<repo>/actions/workflows/pages.yml (set OWNER/REPO env vars for repo-specific URL)\n'
     fi
     exit 0
     ```

   (`ROOT` and `REPO_ROOT` must be in scope at this point — they are, per the file's header. If the resolver path differs in a consumer staging, the `|| echo github-pages` fallback keeps the github-pages default safe.)

2. **Create `tools/verify/m043-p01-wiki-deploy-url.sh`** — verbatim:

   ```bash
   #!/usr/bin/env bash
   # m043-p01-wiki-deploy-url.sh — FR-5 target-aware URL + CON-4 github-pages
   # output byte-stability (string-presence proxy).
   set -u

   WD="scripts/wiki/wiki-deploy.sh"
   fail=0
   check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

   test -f "$WD"; check "wiki-deploy.sh present" $?

   grep -q "resolve-deploy-target.sh" "$WD"; check "FR-5: resolves deploy_target" $?
   grep -q "actions/workflows/wiki-cloudflare.yml" "$WD"; check "FR-5: prints wiki-cloudflare.yml URL for cloudflare-access" $?
   grep -q "identical across targets" "$WD"; check "FR-5: states gates identical across targets" $?

   # CON-4: the github-pages output lines are preserved verbatim.
   grep -q "OK: pre-deploy gates PASS. Push to main to trigger workflow deploy:" "$WD"; check "CON-4: github-pages OK line preserved" $?
   grep -q "actions/workflows/pages.yml" "$WD"; check "CON-4: github-pages pages.yml URL preserved" $?

   if [ "$fail" -eq 0 ]; then echo "SUMMARY: m043-p01-wiki-deploy-url.sh pass=ALL fail=0"; exit 0; fi
   echo "SUMMARY: m043-p01-wiki-deploy-url.sh pass=SOME fail=1"; exit 1
   ```

3. **Create `tools/verify/m043-p01-phase-suite.sh`** — verbatim:

   ```bash
   #!/usr/bin/env bash
   # m043-p01-phase-suite.sh — P01 phase-suite aggregator. Runs all four P01
   # gates in order, exits 0 iff all pass, emits one SUMMARY line.
   set -u

   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   cd "$ROOT" || exit 2

   pass=0
   fail=0
   run_gate() {
     if bash "$1"; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
   }

   run_gate "tools/verify/m043-p01-config-and-resolver.sh"
   run_gate "tools/verify/m043-p01-wrangler-lint.sh"
   run_gate "tools/verify/m043-p01-wiki-init-branch.sh"
   run_gate "tools/verify/m043-p01-wiki-deploy-url.sh"

   echo "SUMMARY: m043-p01-phase-suite.sh pass=$pass fail=$fail"
   if [ "$fail" -eq 0 ]; then exit 0; fi
   exit 1
   ```

4. **`chmod +x tools/verify/m043-p01-wiki-deploy-url.sh tools/verify/m043-p01-phase-suite.sh`** (single command, no `&&`).

5. Run the verification block; confirm all exit 0 and the suite reports `pass=4 fail=0`.

## Must-Haves

- FR-5: wiki-deploy.sh prints wiki-cloudflare.yml URL for cloudflare-access; github-pages output byte-stable (CON-4).
- Phase-suite aggregator runs all four P01 gates, single SUMMARY line.

## Verification

- `bash tools/verify/m043-p01-wiki-deploy-url.sh`
- `bash -n scripts/wiki/wiki-deploy.sh`
- `bash tools/verify/m043-p01-phase-suite.sh`

## Notes

`bash -n` confirms the edited wiki-deploy.sh still parses. Expected: `m043-p01-wiki-deploy-url.sh` ends `SUMMARY: ... pass=ALL fail=0`; the phase suite ends `SUMMARY: m043-p01-phase-suite.sh pass=4 fail=0` (exit 0) once T01–T03 gates are all green. The CON-4 github-pages byte-stability here is a string-presence proxy (the original print lines are preserved verbatim in the new_string); the stronger heredoc byte-diff lives in T03's golden check. End-to-end run of wiki-deploy.sh against a live remote is exercised in P04.

## Inputs

### From Previous Tasks

- (T01) `scripts/wiki/resolve-deploy-target.sh` — `resolve-deploy-target.sh <project-root>` → `github-pages | cloudflare-access`; wiki-deploy calls it with `"$ROOT"`.
- (T01) `tools/verify/m043-p01-config-and-resolver.sh`, (T02) `tools/verify/m043-p01-wrangler-lint.sh`, (T03) `tools/verify/m043-p01-wiki-init-branch.sh` — the gates the phase suite invokes.

### From Disk (Pre-existing)

- `scripts/wiki/wiki-deploy.sh` — the FR-20 URL-print tail (anchor on the exact `printf 'OK: pre-deploy gates PASS...'` block). `OWNER`, `REPO`, `ROOT`, `REPO_ROOT` are in scope at the tail.

## Constraints

- **CON-4 byte-stability**: the github-pages print block must remain byte-identical — preserve those `printf` lines verbatim after the cloudflare branch. Do not alter the four pre-deploy gates.
- **FR-5**: cloudflare-access prints the `wiki-cloudflare.yml` URL + "identical across targets"; github-pages prints the unchanged `pages.yml` URL.
- **Bash 3.2 / POSIX-sh** (CON-5).
- **Project-owned verifiers under `tools/verify/`**, milestone-slug-prefixed.
- Bash shape-guard (AP-009): single commands at the shell.

## Expected Output

wiki-deploy.sh branches the URL print on deploy_target; `bash -n` passes; both new verifiers + the phase suite are executable and green; `bash tools/verify/m043-p01-phase-suite.sh` ends `SUMMARY: m043-p01-phase-suite.sh pass=4 fail=0` exit 0.
