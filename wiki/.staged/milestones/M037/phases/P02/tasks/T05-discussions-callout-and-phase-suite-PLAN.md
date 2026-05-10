---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P02"
milestone: "M037"
name: "Discussions-redirect README callout + acceptance battery extension + phase-suite aggregator"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01..T04 have shipped (verifiers exist on disk: `tools/verify/m037-p02-feedback-routing.sh`, `tools/verify/m037-p02-workflow-pages-publishing.sh`, `tools/verify/m037-p02-private-site-url.sh`, `tools/verify/m037-p02-out-of-scope-collapse.sh`). T05's phase-suite aggregator references them; if any is missing, T05's verifier-availability cross-check fails.
- T02 has updated `wiki/README.md` "First-deploy checklist" + "Running the deploy wrapper" sections (the cross-milestone docs update). T05 adds a callout on top of T02's restructured layout.
- `tests/m037-acceptance/run-acceptance-battery.sh` exists (verified at plan-authoring time, P01/T06 deliverable; iterates `tests/m037-acceptance/p01-*.sh` and emits `BATTERY: pass=N skip=M fail=K`).
- `tools/verify/m037-p01-phase-suite.sh` exists (verified at plan-authoring time, P01/T06 deliverable; AD-19 straight-line aggregator shape — used as the structural template for T05's m037-p02-phase-suite.sh).

## Description

Lands FR-22b per US-14 and SC-17, plus the phase-close gate aggregator and acceptance battery extension. Three deliverables ship together because they are small and share the "phase-close hygiene" theme:

1. **FR-22b README callout** — `wiki/README.md` § "First-deploy checklist" gains an org-level-discussions-redirect callout naming both the symptom (`<Org>/<Repo>/discussions` 302s to `orgs/<Org>/discussions`) AND the recovery path (`<Org>/<Repo>/discussions/categories` direct URL). PBJ-central operator hit this dead-end on 2026-05-07. Source: `papercut-sweep-wiki-deploy-2026-05-07.md` finding #7.

2. **Acceptance battery extension** — `tests/m037-acceptance/run-acceptance-battery.sh` extended to invoke the two top-level handoff-doc scaffolds (`tests/test-wiki-init-workflow-mode.sh`, `tests/test-wiki-init-private-site-url.sh`) IN ADDITION to the existing `p01-*.sh` glob. Target: `BATTERY: pass=10 skip=0 fail=0` (5 P01 + 3 new p01-*.sh + 2 top-level scaffolds = 10).

3. **Phase-suite aggregator** — `tools/verify/m037-p02-phase-suite.sh` straight-line aggregator per AD-19. Aggregates the five P02 verifiers (T01-T05 minus T05's own verifier — T05's verifier IS the phase-suite aggregator itself + a sibling discussions-callout verifier).

## Steps

1. **Author `tools/verify/m037-p02-discussions-callout.sh`**:
   - Greps `wiki/README.md` for: `discussions/categories` (the recovery URL pattern) AND a literal mention of the symptom (e.g., `302` or `redirect` near the callout).
   - Greps `wiki/README.md` for the literal string `First-deploy checklist` (the callout MUST land in that section).
   - Asserts the section preserves byte-identically the pre-existing checklist items by checking for: `Install the giscus GitHub App` (step 1 anchor), `wiki-init --with-giscus` (step 2 anchor), `Smoke-test the deployed URL` (step 4-or-similar anchor).
   - Emits `SUMMARY: m037-p02-discussions-callout pass=N fail=M` on completion.

2. **Add the callout to `wiki/README.md`**. Insert AFTER step 1 (giscus app install, line 294-302) and BEFORE step 2 (wiki-init --with-giscus run, line 304+), or at a position chosen at execute time that flows naturally with the post-T02 restructure. Recommended shape:

   ```markdown
   > **Org-level redirect quirk**: if your GitHub org has org-level
   > Discussions enabled, `https://github.com/<Org>/<Repo>/discussions`
   > may 302-redirect to the org-level page (`https://github.com/orgs/<Org>/discussions`).
   > The repo's discussions still work via API and giscus, but the
   > "create category" UI lives at the org level until you navigate
   > directly to:
   >
   > ```
   > https://github.com/<Org>/<Repo>/discussions/categories
   > ```
   >
   > Use that URL to manage repo-scoped discussion categories. giscus
   > and the discussions API both still work against the repo; only
   > the web UI redirects.
   ```

   Pre-existing checklist items + the giscus.app private-repo callout (lines 286-292) byte-preserved; only the new callout is added. The placement (after step 1, before step 2) puts the callout adjacent to the discussions-enable step where operators will encounter the redirect.

3. **Extend `tests/m037-acceptance/run-acceptance-battery.sh`** to invoke the two top-level handoff-doc scaffolds AFTER the existing p01-*.sh glob loop:

   ```bash
   # M037/P02/T05 — explicit invocation of verbatim handoff-doc test scaffolds.
   # These tests live at the test-tree root (not under tests/m037-acceptance/)
   # so they are not picked up by the p01-*.sh glob; invoke explicitly to
   # include in the battery total.
   for explicit_test in \
     "$PROJECT_ROOT/tests/test-wiki-init-workflow-mode.sh" \
     "$PROJECT_ROOT/tests/test-wiki-init-private-site-url.sh"; do
     test_name="$(basename "$explicit_test")"
     if [ ! -f "$explicit_test" ]; then
       printf 'SKIP: %s (not present)\n' "$test_name"
       skip=$((skip + 1))
       continue
     fi
     printf -- '--- %s ---\n' "$test_name"
     set +e
     bash "$explicit_test"
     rc=$?
     set -e
     if [ "$rc" -eq 0 ]; then
       printf 'OK: %s (rc=0)\n\n' "$test_name"
       pass=$((pass + 1))
     else
       printf 'FAIL: %s (rc=%d)\n\n' "$test_name" "$rc"
       fail=$((fail + 1))
     fi
   done
   ```

   Insert this block IMMEDIATELY BEFORE the final `printf 'BATTERY: pass=%d skip=%d fail=%d\n' ...` line. The aggregate counts include the explicit invocations.

4. **Author `tools/verify/m037-p02-phase-suite.sh`** mirroring `tools/verify/m037-p01-phase-suite.sh` shape (straight-line invocations per AD-19, no loops, no compound chains, no eval):

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m037-p02-phase-suite.sh — M037 P02 phase-close gate suite.
   #
   # Aggregates every P02 verifier from T01..T05 of the publishing-robustness
   # paper-cut bundle and emits a single aggregate SUMMARY line. Canonical
   # "P02 is done" gate.
   #
   # Sub-gates (in task order — upstream task gates surface BEFORE downstream
   # consumers, so an upstream failure short-circuits diagnostics):
   #
   #   T01 — feedback routing arm:
   #     1. m037-p02-feedback-routing.sh
   #
   #   T02 — F12 publishing cluster:
   #     2. m037-p02-workflow-pages-publishing.sh
   #
   #   T03 — private site_url visibility branch:
   #     3. m037-p02-private-site-url.sh
   #
   #   T04 — OUT-OF-SCOPE collapse:
   #     4. m037-p02-out-of-scope-collapse.sh
   #
   #   T05 — discussions callout:
   #     5. m037-p02-discussions-callout.sh
   #
   # Each sub-gate's own SUMMARY line is preserved on stdout for diagnostics;
   # the suite emits a single aggregate SUMMARY line at end.
   #
   # Bash 3.2 compatible. Straight-line invocation per AD-19 — no loops over
   # arrays, no compound chains, no eval. Mirrors tools/verify/m037-p01-phase-suite.sh.

   set -u

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

   cd "$PROJECT_ROOT"

   pass=0
   fail=0

   emit_gate_result() {
       rc="$1"
       name="$2"
       if [ "$rc" -eq 0 ]; then
           pass=$(( pass + 1 ))
           printf 'OK: %s\n' "$name"
       else
           fail=$(( fail + 1 ))
           printf 'FAIL: %s\n' "$name"
       fi
   }

   # ---------- T01 Gate 1: feedback-routing ----------

   bash tools/verify/m037-p02-feedback-routing.sh
   rc=$?
   emit_gate_result "$rc" "m037-p02-feedback-routing.sh"

   # ---------- T02 Gate 2: workflow-pages-publishing ----------

   bash tools/verify/m037-p02-workflow-pages-publishing.sh
   rc=$?
   emit_gate_result "$rc" "m037-p02-workflow-pages-publishing.sh"

   # ---------- T03 Gate 3: private-site-url ----------

   bash tools/verify/m037-p02-private-site-url.sh
   rc=$?
   emit_gate_result "$rc" "m037-p02-private-site-url.sh"

   # ---------- T04 Gate 4: out-of-scope-collapse ----------

   bash tools/verify/m037-p02-out-of-scope-collapse.sh
   rc=$?
   emit_gate_result "$rc" "m037-p02-out-of-scope-collapse.sh"

   # ---------- T05 Gate 5: discussions-callout ----------

   bash tools/verify/m037-p02-discussions-callout.sh
   rc=$?
   emit_gate_result "$rc" "m037-p02-discussions-callout.sh"

   # ---------- Aggregate summary ----------

   printf 'SUMMARY: m037-p02-phase-suite.sh pass=%d fail=%d\n' "$pass" "$fail"

   if [ "$fail" -eq 0 ]; then
       exit 0
   fi
   exit 1
   ```

5. **Author `tests/m037-acceptance/p01-discussions-callout.sh`** (SC-17):
   - Greps `wiki/README.md` for `discussions/categories` (recovery URL pattern present).
   - Asserts the callout is inside the "First-deploy checklist" section by checking that the pattern appears between the section heading and the next `## ` heading (use awk to extract the section content; assert the URL pattern is present in the extracted text).
   - Asserts pre-existing checklist items survive: `giscus GitHub App`, `wiki-init.sh`, `Smoke-test`.
   - Emits `PASS: m037-p02-discussions-callout` on success.

   Note: SC-17 ALSO requires that "[M032](../../../../../milestones/M032/index.md) wiki-deploy quickstart docs" no longer reference `bash scripts/wiki/wiki-deploy.sh` as the live-deploy path. That assertion lives in T02's `tools/verify/m037-p02-workflow-pages-publishing.sh` (wiki/README.md grep), NOT in T05's discussions-callout test — separation of concerns.

6. **Verify the acceptance battery rolls up correctly**. With T01-T05 all shipped:
   - Existing P01 tests (5): `p01-card-grid-homepage.sh`, `p01-version-to-nav-title.sh`, `p01-dr-heading-shape.sh`, `p01-mkdocs-polish-bundle.sh`, `p01-config-clobber-fix.sh`.
   - New P02 tests glob-matched as `p01-*.sh` (3): `p01-feedback-routing.sh`, `p01-out-of-scope-collapse.sh`, `p01-discussions-callout.sh`.
   - New P02 explicit-invocation tests (2): `tests/test-wiki-init-workflow-mode.sh`, `tests/test-wiki-init-private-site-url.sh`.
   - Total: 10. Target output: `BATTERY: pass=10 skip=0 fail=0`.

   Note: the spec/roadmap names the new P02 tests with `p01-` prefix because that's how they were declared in the spec at SC-13/SC-16/SC-17. The naming convention is "the test exercises the live behavior reachable from `M037 P01`+P02 wiki" rather than "the test ships in P01." The prefix is preserved for spec-fidelity.

## Must-Haves

- T13 (FR-22b README discussions callout) — phase plan.
- T14 (battery aggregator extension) — phase plan.
- T15 (phase-suite aggregator AD-19 straight-line) — phase plan.

## Verification

```bash
bash tools/verify/m037-p02-phase-suite.sh
```

```bash
bash tests/m037-acceptance/run-acceptance-battery.sh
```

```bash
bash tools/verify/m037-p02-discussions-callout.sh
```

## Inputs

### From Previous Tasks

- T01 produces `tools/verify/m037-p02-feedback-routing.sh` — invoked by phase-suite Gate 1.
- T02 produces `tools/verify/m037-p02-workflow-pages-publishing.sh` — invoked by phase-suite Gate 2. T02 also owns the M032 wiki/README.md restructure that T05 lands the callout on top of.
- T03 produces `tools/verify/m037-p02-private-site-url.sh` — invoked by phase-suite Gate 3.
- T04 produces `tools/verify/m037-p02-out-of-scope-collapse.sh` — invoked by phase-suite Gate 4.

### From Disk (Pre-existing)

- `tools/verify/m037-p01-phase-suite.sh` — structural template for T05's phase-suite aggregator. AD-19 straight-line shape; no loops, no compound chains.
- `tests/m037-acceptance/run-acceptance-battery.sh` — extended in step 3.
- `wiki/README.md` — modified in step 2 (callout addition); pre-existing content byte-preserved.

## Constraints

- AD-19: all `Check:` commands single-script-file shape; phase-suite aggregator MUST use straight-line invocations (no loops over arrays, no `for v in $(...)`, no compound chains).
- Bash 3.2 + POSIX sh in script additions.
- The README callout MUST be additive — pre-existing checklist items byte-preserved. Use `diff`-checking at executor time to confirm: `git diff wiki/README.md` should show ONLY the callout addition (modulo line-number context shifts), no other content modifications.
- The acceptance battery extension MUST preserve the existing glob behavior for `p01-*.sh` — the explicit-invocation block is ADDITIVE, inserted before the final `printf BATTERY:` line. Existing skip/fail/pass counters are reused.
- `BATTERY: pass=10 skip=0 fail=0` is the SUCCESS target. If any P02 verifier or fixture is unbuilt at executor time, the battery surfaces the gap as `fail` rather than `skip` — only "test file not present" maps to `skip`. (T05 verifier-availability cross-check at plan-authoring time confirms all five verifiers will exist before T05 dispatches.)

## Expected Output

After T05 ships:
- `bash tools/verify/m037-p02-phase-suite.sh` exits 0 with `SUMMARY: m037-p02-phase-suite.sh pass=5 fail=0`.
- `bash tests/m037-acceptance/run-acceptance-battery.sh` exits 0 with `BATTERY: pass=10 skip=0 fail=0`.
- `wiki/README.md` § "First-deploy checklist" carries the org-level-discussions-redirect callout between steps 1 and 2; pre-existing items unchanged.

## Notes

- **Why `p01-` prefix on new P02 tests**: spec-fidelity. The spec at SC-13/SC-16/SC-17 names them with `p01-` prefix and the roadmap preserves the names. Renaming would force spec/roadmap edits and is not load-bearing — the glob `p01-*.sh` picks them up regardless of which phase implements them.

- **The phase-suite aggregator does NOT include `m037-p01-phase-suite.sh`** — P01 is closed and its phase-suite ran at P01 close. P02's phase-suite gates only the surface area added by P02. Milestone-close gating (the eventual `tools/verify/m037-milestone-suite.sh` or equivalent) would aggregate both.

- **The acceptance battery's `BATTERY: pass=10 fail=0` line** is the canonical "P02 is done" external-facing signal. Phase-close runs both `m037-p02-phase-suite.sh` (pass=5 fail=0) and the acceptance battery (pass=10 skip=0 fail=0). Both must be green before P02 closes.

- **No real-DB verification (rule 5)**: NOT APPLICABLE. T05 is documentation + test plumbing only.

- **Verifier-availability cross-check passed at plan-authoring time**: T01-T04 all schedule their verifier authorship inside their own task plan's `## Steps`. T05's phase-suite aggregator references those verifiers; they will exist on disk before T05 dispatches under sequential `orchestrator:auto` ordering (T01 → T02 → T03 → T04 → T05).
