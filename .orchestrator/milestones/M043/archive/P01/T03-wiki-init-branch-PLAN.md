---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M043"
name: "wiki-init.sh emit + --deploy branching (FR-2/FR-4) + byte-stability golden"
depends_on: ["T01", "T02"]
---

## Prerequisites

- `scripts/lifecycle/wiki-init.sh` exists with: `emit_pages_workflow()` (def line ~531, heredoc body ~538–620, closing `}` ~622), `flip_pages_build_type()` (def ~629, closes ~648), the emit call site `emit_pages_workflow` / `flip_pages_build_type` (~655–656), and the `if [ "$WITH_DEPLOY" = "1" ]; then` block (~1105). Verified present at plan time. (Line numbers are guidance; anchor on the literal strings below.)
- `scripts/wiki/resolve-deploy-target.sh` exists (T01).
- `templates/wiki-cloudflare-deploy.yml.tmpl` exists (T02).
- `REPO_ROOT` and `PROJECT_DIR` are defined earlier in wiki-init.sh (used at lines ~1151 / ~532 respectively).

## Description

Branch wiki-init.sh on `deploy_target` at two sites — workflow-emit (FR-2) and `--deploy` (FR-4) — WITHOUT altering the existing github-pages code paths (CON-4 byte-stability). For `cloudflare-access`: emit `wiki-cloudflare.yml` from the T02 template (CON-3 no-clobber) and route `--deploy` to the P02 provisioner (with a not-found guard, since `cloudflare-access-setup.sh` is P02's concurrent deliverable). Capture a byte-stability golden of the pristine `pages.yml` heredoc so the verifier can prove the github-pages emit is unchanged.

## Steps

1. **Capture the byte-stability golden BEFORE editing.** Create the fixtures dir and extract the `emit_pages_workflow` heredoc body verbatim (run each as a single command):

   `mkdir -p tests/fixtures/m043-p01`

   `awk '/<<.PAGES_WORKFLOW_EOF.$/{f=1;next} /^PAGES_WORKFLOW_EOF$/{f=0} f' scripts/lifecycle/wiki-init.sh > tests/fixtures/m043-p01/pages-workflow.golden.yml`

   (The golden is the workflow body between the `<<'PAGES_WORKFLOW_EOF'` and `PAGES_WORKFLOW_EOF` markers. T03 never edits this body, so the verifier's later diff must match exactly.)

2. **Define `emit_cloudflare_workflow`** in wiki-init.sh. Use the Edit tool anchoring on the `emit_pages_workflow` closing line (the FR-19 echo + its `}`). Insert the new function AFTER that `}`:

   - `old_string`:
     ```
       echo "wiki-init: emitted $PAGES_WF_TARGET (build_type=workflow scaffold per FR-19)"
     }
     ```
   - `new_string`:
     ```
       echo "wiki-init: emitted $PAGES_WF_TARGET (build_type=workflow scaffold per FR-19)"
     }

     # M043 FR-2/FR-3 — emit the Cloudflare Pages + Access deploy workflow from
     # templates/wiki-cloudflare-deploy.yml.tmpl when deploy_target=cloudflare-access.
     # CON-3 no-clobber on a pre-existing operator workflow. __PROJECT_NAME__ is
     # substituted from wiki.cloudflare.project_name (fallback: repo name).
     emit_cloudflare_workflow() {
       CF_WF_TARGET="$PROJECT_DIR/.github/workflows/wiki-cloudflare.yml"
       if [ -f "$CF_WF_TARGET" ]; then
         echo "wiki-init: .github/workflows/wiki-cloudflare.yml already present at $CF_WF_TARGET — preserving operator-authored workflow (CON-3)" >&2
         return 0
       fi
       CF_TMPL="$REPO_ROOT/templates/wiki-cloudflare-deploy.yml.tmpl"
       if [ ! -f "$CF_TMPL" ]; then
         echo "FAIL: wiki-init: deploy_target=cloudflare-access but template missing: $CF_TMPL" >&2
         return 1
       fi
       CF_PROJECT="$(awk '
         BEGIN{w=0;c=0}
         /^wiki:[[:space:]]*$/ {w=1;next}
         w && /^[^[:space:]]/ {exit}
         w && /^[[:space:]][[:space:]]cloudflare:[[:space:]]*$/ {c=1;next}
         w && c && /^[[:space:]][[:space:]][^[:space:]]/ {c=0}
         w && c && /^[[:space:]][[:space:]][[:space:]][[:space:]]project_name:/ {
           line=$0; sub(/^[[:space:]]*project_name:[[:space:]]*/,"",line); sub(/[[:space:]]*#.*$/,"",line); gsub(/"/,"",line); gsub(/[[:space:]]/,"",line); print line; exit
         }
       ' "$PROJECT_DIR/.orchestrator/config.yml" 2>/dev/null || true)"
       [ -n "$CF_PROJECT" ] || CF_PROJECT="${REPO:-wiki}"
       mkdir -p "$(dirname "$CF_WF_TARGET")"
       sed "s/__PROJECT_NAME__/$CF_PROJECT/g" "$CF_TMPL" > "$CF_WF_TARGET"
       echo "wiki-init: emitted $CF_WF_TARGET (deploy_target=cloudflare-access, project_name=$CF_PROJECT)"
     }
     ```

3. **Branch the emit call site (FR-2).** Edit the two-line call:

   - `old_string`:
     ```
     emit_pages_workflow
     flip_pages_build_type
     ```
   - `new_string`:
     ```
     M043_DEPLOY_TARGET="$(bash "$REPO_ROOT/scripts/wiki/resolve-deploy-target.sh" "$PROJECT_DIR" 2>/dev/null || echo github-pages)"
     if [ "$M043_DEPLOY_TARGET" = "cloudflare-access" ]; then
       emit_cloudflare_workflow
     else
       emit_pages_workflow
       flip_pages_build_type
     fi
     ```

   (The github-pages branch calls BOTH `emit_pages_workflow` and `flip_pages_build_type` exactly as before — byte-for-byte behavior preserved. The cloudflare branch skips `flip_pages_build_type` because it configures GitHub Pages, which is irrelevant to Cloudflare.)

4. **Branch the `--deploy` block (FR-4).** Edit the block opener to insert the cloudflare branch + early-exit, leaving the existing four-step github-pages sequence untouched as the fallthrough:

   - `old_string`:
     ```
     if [ "$WITH_DEPLOY" = "1" ]; then
       # JSONL log path: <PROJECT_DIR>/.orchestrator/execution-log.jsonl
     ```
   - `new_string`:
     ```
     if [ "$WITH_DEPLOY" = "1" ]; then
       # M043 FR-4 — deploy_target branch. cloudflare-access provisions Cloudflare
       # (Pages project + Access app + allow policy) via cloudflare-access-setup.sh
       # IN PLACE OF the four-step GitHub-Pages config sequence below. The setup
       # script is the M043 P02 deliverable (concurrent phase); guard on absence.
       M043_DEPLOY_TARGET="$(bash "$REPO_ROOT/scripts/wiki/resolve-deploy-target.sh" "$PROJECT_DIR" 2>/dev/null || echo github-pages)"
       if [ "$M043_DEPLOY_TARGET" = "cloudflare-access" ]; then
         CF_SETUP="$PROJECT_DIR/scripts/wiki/cloudflare-access-setup.sh"
         [ -f "$CF_SETUP" ] || CF_SETUP="$REPO_ROOT/scripts/wiki/cloudflare-access-setup.sh"
         if [ ! -f "$CF_SETUP" ]; then
           echo "FAIL: wiki-init: --deploy cloudflare-access: cloudflare-access-setup.sh not found (M043 P02 deliverable). Install the provisioner or provision Cloudflare manually, then re-run." >&2
           exit 14
         fi
         set +e
         bash "$CF_SETUP" --project-dir "$PROJECT_DIR"
         cf_rc=$?
         set -e
         if [ "$cf_rc" -ne 0 ]; then
           echo "FAIL: wiki-init: --deploy cloudflare-access: cloudflare-access-setup.sh exited $cf_rc" >&2
           exit 14
         fi
         echo "wiki-init: --deploy cloudflare-access: provisioning complete. Push to main to trigger .github/workflows/wiki-cloudflare.yml"
         exit 0
       fi
       # JSONL log path: <PROJECT_DIR>/.orchestrator/execution-log.jsonl
     ```

   Exit code 14 is the M043 cloudflare-deploy failure code (existing 10–13 are the github-pages steps). Note: if the script uses `set -e`, the `set +e`/`set -e` guard around the setup invocation matches the existing step-2 pattern (lines ~1172–1175).

5. **Create `tools/verify/m043-p01-wiki-init-branch.sh`** — verbatim:

   ```bash
   #!/usr/bin/env bash
   # m043-p01-wiki-init-branch.sh — FR-2/FR-4 branching + CON-4 byte-stability.
   set -u

   WI="scripts/lifecycle/wiki-init.sh"
   GOLDEN="tests/fixtures/m043-p01/pages-workflow.golden.yml"
   fail=0
   check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

   test -f "$WI"; check "wiki-init.sh present" $?

   grep -q "emit_cloudflare_workflow()" "$WI"; check "FR-2: emit_cloudflare_workflow defined" $?
   grep -q "emit_cloudflare_workflow" "$WI";   check "FR-2: emit branch calls emit_cloudflare_workflow" $?
   grep -q "resolve-deploy-target.sh" "$WI";   check "resolves deploy_target via resolver" $?
   grep -q "wiki-cloudflare.yml" "$WI";        check "FR-2: emits wiki-cloudflare.yml" $?
   grep -q "cloudflare-access-setup.sh" "$WI"; check "FR-4: --deploy references cloudflare-access-setup.sh" $?

   # github-pages four-step sequence preserved (markers from the existing block).
   grep -q "has_discussions=true" "$WI";       check "CON-4: github-pages step 1 (has_discussions) preserved" $?
   grep -q "/repos/\$OWNER/\$REPO/pages" "$WI"; check "CON-4: github-pages step 4 (PUT pages) preserved" $?

   # CON-4 / SC-1: the pages.yml heredoc body is byte-identical to the golden.
   test -f "$GOLDEN"; check "byte-stability golden present" $?
   TMP="$(mktemp -d)"
   awk '/<<.PAGES_WORKFLOW_EOF.$/{f=1;next} /^PAGES_WORKFLOW_EOF$/{f=0} f' "$WI" > "$TMP/current.yml"
   if [ -f "$GOLDEN" ] && diff -q "$TMP/current.yml" "$GOLDEN" >/dev/null 2>&1; then
     check "CON-4/SC-1: pages.yml heredoc byte-identical to golden" 0
   else
     check "CON-4/SC-1: pages.yml heredoc byte-identical to golden" 1
   fi
   rm -rf "$TMP"

   if [ "$fail" -eq 0 ]; then echo "SUMMARY: m043-p01-wiki-init-branch.sh pass=ALL fail=0"; exit 0; fi
   echo "SUMMARY: m043-p01-wiki-init-branch.sh pass=SOME fail=1"; exit 1
   ```

6. **`chmod +x tools/verify/m043-p01-wiki-init-branch.sh`** (single command).

7. Run the verification block; confirm all exit 0.

## Must-Haves

- FR-2 emit branch (emit_cloudflare_workflow → wiki-cloudflare.yml, CON-3 no-clobber).
- FR-4 --deploy branch (cloudflare-access-setup.sh invocation + not-found guard).
- CON-4 byte-stability: pages.yml heredoc byte-identical to golden; four-step sequence preserved.

## Verification

- `bash tools/verify/m043-p01-wiki-init-branch.sh`
- `bash -n scripts/lifecycle/wiki-init.sh`
- `grep -q "emit_cloudflare_workflow" scripts/lifecycle/wiki-init.sh`

## Notes

`bash -n` is a syntax-only parse of the edited wiki-init.sh — it confirms the inserted branches didn't break the script's syntax without executing it (wiki-init has side effects). Expected verifier output: `SUMMARY: m043-p01-wiki-init-branch.sh pass=ALL fail=0`. The byte-stability golden is the load-bearing CON-4 proof — it diffs the live `emit_pages_workflow` heredoc body against the pristine capture from step 1; since the edits only ADD a sibling function + wrap the call site, the body is untouched and the diff is empty.

## Inputs

### From Previous Tasks

- (T01) `scripts/wiki/resolve-deploy-target.sh` — `resolve-deploy-target.sh <project-root>` → `github-pages | cloudflare-access` on stdout (exit 2 on unknown). wiki-init calls it with `"$PROJECT_DIR"`.
- (T02) `templates/wiki-cloudflare-deploy.yml.tmpl` — the Cloudflare workflow with a `__PROJECT_NAME__` placeholder that `emit_cloudflare_workflow` substitutes via `sed`.

### From Disk (Pre-existing)

- `scripts/lifecycle/wiki-init.sh` — anchors: `emit_pages_workflow` def + heredoc + closing `}`; the `emit_pages_workflow` / `flip_pages_build_type` call site; the `if [ "$WITH_DEPLOY" = "1" ]; then` block opener. `REPO_ROOT`, `PROJECT_DIR`, `OWNER`, `REPO` are in scope.

## Constraints

- **CON-4 byte-stability (load-bearing)**: do NOT modify the `emit_pages_workflow` function body, `flip_pages_build_type`, or the existing four-step `--deploy` sequence. Only ADD the cloudflare branches around them. The golden diff proves this.
- **CON-3 no-clobber**: `emit_cloudflare_workflow` must preserve a pre-existing `wiki-cloudflare.yml` with a diagnostic, never overwrite.
- **FR-4 not-found guard**: `cloudflare-access-setup.sh` is the P02 deliverable; the branch must reference it AND guard on its absence (exit 14 with an actionable message), not assume it exists.
- **Bash 3.2 / POSIX-sh** (CON-5).
- Bash shape-guard (AP-009): single commands at the shell. The `awk`/`sed`/`mktemp` inside the verifier script-file are fine.

## Expected Output

wiki-init.sh branches on deploy_target at both emit + --deploy; `bash -n` passes; the golden is captured; `bash tools/verify/m043-p01-wiki-init-branch.sh` ends `SUMMARY: ... pass=ALL fail=0` exit 0.
