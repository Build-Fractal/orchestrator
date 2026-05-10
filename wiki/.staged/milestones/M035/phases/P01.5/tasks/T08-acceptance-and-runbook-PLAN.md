---
schema_version: "1.0"
type: task-plan
task: "T08"
phase: "P01.5"
milestone: "M035"
name: "SC-7 + SC-7b acceptance verifiers + phase-suite aggregator + operator off-tree runbook"
depends_on: ["T07"]
---

## Prerequisites

Files that MUST exist on disk at task entry:

- T01..T07 outputs all landed:
  - T01: `[D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }")..[D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }")` block in [`.orchestrator/DECISIONS.md`](../../../../../decisions.md),
    legacy-namespace allowlist file, pre-rename tag.
  - T02: `specs/001-orchestrator/` rename + content sweep.
  - T03: operator-environment paths swept.
  - T04: C1 lowercase-hyphenated sweep.
  - T05: C2 + C3 prose sweep.
  - T06: C5 cohort finish (4 templates).
  - T07: C4 classification log + rename pass.
- Per-task verifiers under `tools/verify/m035-p015-*`:
  - `m035-p015-allowlist-shape.sh` (T01)
  - `m035-p015-decisions-block.sh` (T01)
  - `m035-p015-pre-rename-tag.sh` (T01)
  - `m035-p015-spec-dir-rename.sh` (T02)
  - `m035-p015-operator-paths.sh` (T03)
  - `m035-p015-c1-sweep.sh` (T04)
  - `m035-p015-c2-c3-prose.sh` (T05)
  - `m035-p015-c5-cohort-finish.sh` (T06)
  - `m035-p015-c4-classification.sh` (T07)

Pre-existing decisions consumed:

- M035 spec SC-7 wording: `grep -rE 'speckit\.orchestrator\.[a-z]'
  commands/ scripts/ templates/ references/ docs/ | grep -v -F -f
  tests/m035-acceptance/legacy-namespace-allowlist.txt` returns zero
  matches.
- M035 roadmap line 91 (`#Q-G3` activation): SC-7b is **active under
  #Q-G1 Option A** — `grep 'spec-kit-orchestrator' CLAUDE.md README.md
  package.json` returns zero matches.
- The off-tree operator runbook ([D-RN-2](../../../../../decisions.md#d-rn-2-github-repo-basename-build-fractalorchestrator-dr-code-030 "GitHub repo basename `Build-Fractal/orchestrator` { #dr-code-030 }") GitHub remote rename, [D-RN-5](../../../../../decisions.md#d-rn-5-local-clone-path-sitesorchestrator-dr-code-033 "Local clone path `~/Sites/orchestrator` { #dr-code-033 }")
  local clone path rename, [D-RN-6](../../../../../decisions.md#d-rn-6-migrate-claude-memory-dir-alongside-path-rename-dr-code-034 "Migrate Claude memory dir alongside path rename { #dr-code-034 }") Claude memory project-key migration)
  must be surfaced as PAUSE conditions in the operator-facing runbook.

## Description

Two responsibilities:

1. **Author the phase-grain SC-7 + SC-7b acceptance verifiers** that
   the M035 acceptance battery (P06) inherits, plus the AD-19-prefixed
   phase-suite aggregator that runs every per-task verifier in
   sequence and emits the `BATTERY: pass=N fail=0` summary.

2. **Surface the off-tree operator runbook** for [D-RN-2](../../../../../decisions.md#d-rn-2-github-repo-basename-build-fractalorchestrator-dr-code-030 "GitHub repo basename `Build-Fractal/orchestrator` { #dr-code-030 }") / [D-RN-5](../../../../../decisions.md#d-rn-5-local-clone-path-sitesorchestrator-dr-code-033 "Local clone path `~/Sites/orchestrator` { #dr-code-033 }") /
   [D-RN-6](../../../../../decisions.md#d-rn-6-migrate-claude-memory-dir-alongside-path-rename-dr-code-034 "Migrate Claude memory dir alongside path rename { #dr-code-034 }") in a structured location the consolidate-time SUMMARY can
   reference. The auto-loop CANNOT execute these steps; this task
   produces the operator-facing runbook artifact and emits PAUSE
   advisories so the operator knows precisely what to do AFTER the
   in-tree rename branch merges.

## Steps

1. **Author `tools/verify/m035-p015-sc7.sh`** — the SC-7 grep-zero-match
   verifier:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p015-sc7.sh — SC-7 cohort grep-zero-match assertion.
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   cd "$REPO_ROOT" || exit 1
   ALLOWLIST="$REPO_ROOT/tests/m035-acceptance/legacy-namespace-allowlist.txt"
   if [ ! -f "$ALLOWLIST" ]; then
     echo "FAIL: SC-7 allowlist file missing at $ALLOWLIST" >&2
     exit 1
   fi
   # The SC-7 grep is restricted to the operational subtrees per the
   # spec (commands/ scripts/ templates/ references/ docs/).
   residue=$(grep -rE 'speckit\.orchestrator\.[a-z]' \
     commands/ scripts/ templates/ references/ docs/ 2>/dev/null \
     | grep -v -F -f "$ALLOWLIST" || true)
   if [ -n "$residue" ]; then
     echo "FAIL: SC-7 residual speckit.orchestrator.* matches:" >&2
     echo "$residue" >&2
     exit 1
   fi
   echo "PASS: m035-p015-sc7"
   exit 0
   ```

2. **Author `tools/verify/m035-p015-sc7b.sh`** — the SC-7b
   grep-zero-match verifier:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p015-sc7b.sh — SC-7b spec-kit-orchestrator grep-zero-match assertion.
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   cd "$REPO_ROOT" || exit 1
   fail=0
   for f in "CLAUDE.md" "README.md"; do
     if [ -f "$REPO_ROOT/$f" ]; then
       if grep -qE 'spec-kit-orchestrator' "$REPO_ROOT/$f"; then
         echo "FAIL: SC-7b — $f still references spec-kit-orchestrator" >&2
         fail=1
       fi
     fi
   done
   # package.json optional — only check if exists (P02 authors it).
   if [ -f "$REPO_ROOT/package.json" ]; then
     if grep -qE 'spec-kit-orchestrator' "$REPO_ROOT/package.json"; then
       echo "FAIL: SC-7b — package.json still references spec-kit-orchestrator" >&2
       fail=1
     fi
   fi
   if [ "$fail" -eq 0 ]; then echo "PASS: m035-p015-sc7b"; exit 0; fi
   exit 1
   ```

3. **Author `tools/verify/m035-p015-phase-suite.sh`** — the AD-19-prefixed
   phase-suite aggregator. Naming mirrors the M035/P00 +
   `tools/verify/m035-p01-phase-suite.sh` convention from P01:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p015-phase-suite.sh — M035 P01.5 phase-grain aggregator.
   set -u
   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   pass=0
   fail=0
   for v in \
     "m035-p015-allowlist-shape.sh" \
     "m035-p015-decisions-block.sh" \
     "m035-p015-pre-rename-tag.sh" \
     "m035-p015-spec-dir-rename.sh" \
     "m035-p015-operator-paths.sh" \
     "m035-p015-c1-sweep.sh" \
     "m035-p015-c2-c3-prose.sh" \
     "m035-p015-c5-cohort-finish.sh" \
     "m035-p015-c4-classification.sh" \
     "m035-p015-sc7.sh" \
     "m035-p015-sc7b.sh"; do
     if [ ! -x "$REPO_ROOT/tools/verify/$v" ]; then
       if [ -f "$REPO_ROOT/tools/verify/$v" ]; then
         chmod +x "$REPO_ROOT/tools/verify/$v"
       else
         echo "FAIL: missing verifier $v" >&2
         fail=$((fail + 1))
         continue
       fi
     fi
     if bash "$REPO_ROOT/tools/verify/$v"; then
       pass=$((pass + 1))
     else
       fail=$((fail + 1))
     fi
   done
   echo "BATTERY: pass=$pass fail=$fail"
   if [ "$fail" -eq 0 ]; then exit 0; fi
   exit 1
   ```

   The `BATTERY: pass=N fail=N` line shape mirrors the
   `tests/m030-acceptance/run-acceptance-battery.sh` and
   `tests/m032-acceptance/run-acceptance-battery.sh` conventions
   already established in the repo.

4. **Surface the off-tree operator runbook**. Author the runbook as
   a section appended to the M035 P01.5 phase summary inputs. The
   consolidate-time SUMMARY (P01.5-SUMMARY.md, written at consolidate
   time, NOT in this task) will lift this content into a top-level
   "Operator Runbook" section.

   The interim location for the runbook is
   [`.orchestrator/milestones/M035/phases/P01.5/operator-runbook.md`](../../../../../milestones/M035/phases/P01.5/operator-runbook.md)
   (this task creates it). Content shape:

   ```markdown
   # M035 P01.5 — Operator Off-Tree Runbook

   The in-tree rename (T01..T07) ships via the rename branch. After
   the branch merges to main, three off-tree steps complete the
   project rename. They are NOT autonomous-executable.

   ## Step 1 — GitHub remote rename ([D-RN-2](../../../../../decisions.md#d-rn-2-github-repo-basename-build-fractalorchestrator-dr-code-030 "GitHub repo basename `Build-Fractal/orchestrator` { #dr-code-030 }"))

   - In the GitHub web UI, navigate to
     https://github.com/Build-Fractal/spec-kit-orchestrator/settings.
   - Rename the repository to `orchestrator`. The new URL becomes
     `https://github.com/Build-Fractal/orchestrator`.
   - GitHub auto-redirects the old URL; existing clones continue to
     fetch/push correctly via the redirect.
   - **Reversibility**: rename back via the same Settings page.
   - **Recommended timing**: after the rename branch merges to main.

   ## Step 2 — Local working-dir rename ([D-RN-5](../../../../../decisions.md#d-rn-5-local-clone-path-sitesorchestrator-dr-code-033 "Local clone path `~/Sites/orchestrator` { #dr-code-033 }"))

   ```bash
   cd ~/Sites
   mv spec-kit-orchestrator orchestrator
   cd orchestrator
   git remote set-url origin git@github.com:Build-Fractal/orchestrator.git
   git remote -v
   git pull --ff-only
   ```

   - **Reversibility**: `mv orchestrator spec-kit-orchestrator` and
     re-run `git remote set-url origin
     git@github.com:Build-Fractal/spec-kit-orchestrator.git`.
   - **Recommended timing**: immediately after Step 1.

   ## Step 3 — Claude memory project-key migration ([D-RN-6](../../../../../decisions.md#d-rn-6-migrate-claude-memory-dir-alongside-path-rename-dr-code-034 "Migrate Claude memory dir alongside path rename { #dr-code-034 }"))

   ```bash
   mv ~/.claude/projects/-Users-brettkellgren-Sites-spec-kit-orchestrator \
      ~/.claude/projects/-Users-brettkellgren-Sites-orchestrator
   ```

   - Without this rename, Claude memory entries become orphaned
     because Claude's project key is derived from the working-dir
     path.
   - **Reversibility**: `mv` the directory back to its old basename.
   - **Recommended timing**: after Step 2 (so the new working-dir path
     resolves before Claude looks it up).

   ## Verification After Off-Tree Steps

   - `git remote -v` shows
     `origin git@github.com:Build-Fractal/orchestrator.git`.
   - `ls ~/.claude/projects/` lists
     `-Users-brettkellgren-Sites-orchestrator` and NOT the old key.
   - Re-opening the Claude session in the renamed working-dir resolves
     the new project key.

   ## Pre-Rename Tag ([D-RN-7](../../../../../decisions.md#d-rn-7-pre-rename-version-tag-v09x-final-spec-kit-name-dr-code-035 "Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }")) Reversibility

   The pre-rename tag `v0.9.X-final-spec-kit-name` is in local refs
   (T01 step 5). To remove it:

   ```bash
   git tag -d v0.9.X-final-spec-kit-name
   ```

   Or to publish to remote:

   ```bash
   git push origin v0.9.X-final-spec-kit-name
   ```

   The tag is operator-personal until pushed; it does not affect any
   automated pipeline.
   ```

5. **Verify the runbook is on disk**: `[ -f [.orchestrator/milestones/M035/phases/P01.5/operator-runbook.md](../../../../../milestones/M035/phases/P01.5/operator-runbook.md) ]`.
   The verification check is bundled into the phase-suite via a small
   addition (not a separate verifier script) — the phase-suite test
   in step 3 includes a check before the loop:

   ```bash
   if [ ! -f "$REPO_ROOT/.orchestrator/milestones/M035/phases/P01.5/operator-runbook.md" ]; then
     echo "FAIL: operator-runbook.md missing — T08 step 4 incomplete" >&2
     fail=$((fail + 1))
   fi
   ```

   (This addition lands in step 3's authored script.)

6. **Run the full phase-suite once at task close**:

   ```bash
   bash tools/verify/m035-p015-phase-suite.sh
   ```

   Expected output: `BATTERY: pass=11 fail=0` (the 11 verifiers named
   in step 3's loop). If `fail > 0`, T08 is incomplete and dispatched
   agent must surface the failing verifier name.

## Must-Haves

- `tools/verify/m035-p015-sc7.sh` exists and emits PASS against the
  cumulative state of T01..T07
  - Check: `bash tools/verify/m035-p015-sc7.sh`
- `tools/verify/m035-p015-sc7b.sh` exists and emits PASS against
  CLAUDE.md + README.md (+ optional package.json)
  - Check: `bash tools/verify/m035-p015-sc7b.sh`
- `tools/verify/m035-p015-phase-suite.sh` aggregates all 11 P01.5
  verifiers and emits `BATTERY: pass=11 fail=0`
  - Check: `bash tools/verify/m035-p015-phase-suite.sh`
- Operator runbook exists on disk surfacing [D-RN-2](../../../../../decisions.md#d-rn-2-github-repo-basename-build-fractalorchestrator-dr-code-030 "GitHub repo basename `Build-Fractal/orchestrator` { #dr-code-030 }") / [D-RN-5](../../../../../decisions.md#d-rn-5-local-clone-path-sitesorchestrator-dr-code-033 "Local clone path `~/Sites/orchestrator` { #dr-code-033 }") / [D-RN-6](../../../../../decisions.md#d-rn-6-migrate-claude-memory-dir-alongside-path-rename-dr-code-034 "Migrate Claude memory dir alongside path rename { #dr-code-034 }") off-tree steps
  - Check: `[ -f [.orchestrator/milestones/M035/phases/P01.5/operator-runbook.md](../../../../../milestones/M035/phases/P01.5/operator-runbook.md) ]`
    (folded into the phase-suite per step 5)

## Verification

```bash
bash tools/verify/m035-p015-sc7.sh
bash tools/verify/m035-p015-sc7b.sh
bash tools/verify/m035-p015-phase-suite.sh
```

## Inputs

### From Previous Tasks

- T01..T07: cumulative rename state. Every truth from the phase plan's
  Must-Haves block has its per-task verifier on disk.

### From Disk (Pre-existing)

- M035 spec SC-7 wording (specs/039-packaging-distribution/spec.md
  line 713 of the planning payload).
- M035 roadmap line 91 (#Q-G1 / #Q-G3 activation).
- `tests/m030-acceptance/run-acceptance-battery.sh` and
  `tests/m032-acceptance/run-acceptance-battery.sh` — convention
  reference for the `BATTERY: pass=N fail=N` line shape.
- The 9 per-task verifiers authored in T01..T07.

## Constraints

- **CON-3 (AP-009-shape-guard-honored)**: phase-suite aggregator
  iterates over verifier names with a simple `for` loop; each
  invocation is a single-script-file `bash` call. No compound chains.
- **AD-19 (single-script-file Check shape)**: every Check is one
  script.
- **No off-tree mutations**: T08 produces the runbook artifact only;
  the actual GitHub rename / local mv / memory-dir mv steps are
  operator-executed AFTER the M035 P01.5 close. The auto-loop's lock
  is held until T08 completes; the off-tree steps happen post-close
  per the runbook's recommended timing.
- **`package.json` may not exist yet**: SC-7b verifier checks
  conditionally — `package.json` is P02's territory. Pre-P02, the
  check is a no-op for that file.

## Notes

- **Plan-phase verifier-availability cross-check (rule 2)**: T08
  authors all 3 of its own verifiers (sc7, sc7b, phase-suite) in
  steps 1–3.
- **Plan-phase classifier-shape pre-validation (rule 3)**: pure grep
  shapes; no classifier.
- **Plan-phase real-DB rule (rule 5)**: not applicable.
- **Phase-suite verifier-count expectation**: 11 = 9 per-task + 2
  acceptance (sc7, sc7b). If T07 produces multiple verifiers (the
  current plan has 1) the phase-suite count adjusts.
- **The SC-7 spec wording in spec.md line 713 names paths
  `commands/ scripts/ templates/ references/ docs/`** — the SC-7
  verifier (step 1) restricts the grep to those 5 subtrees per the
  spec. Any future sub-tree additions update the verifier in lockstep.
- **The SC-7b spec wording in roadmap line 91** activates SC-7b
  under #Q-G1 Option A. Spec body amendment is consolidate-time
  territory (M035-SUMMARY records it); T08 produces the verifier
  enforcing the assertion.

## Expected Output

After T08 completes:

- `tools/verify/m035-p015-sc7.sh` exists; PASSes against the
  cumulative T01..T07 state.
- `tools/verify/m035-p015-sc7b.sh` exists; PASSes against CLAUDE.md
  + README.md.
- `tools/verify/m035-p015-phase-suite.sh` exists; emits
  `BATTERY: pass=11 fail=0` (or appropriate count if T07 author chose
  multiple verifiers).
- [`.orchestrator/milestones/M035/phases/P01.5/operator-runbook.md`](../../../../../milestones/M035/phases/P01.5/operator-runbook.md)
  exists with the three off-tree operator steps documented.
- The phase-grain Must-Haves block in P01.5-PLAN.md has every truth
  satisfied by an on-disk verifier emitting PASS.
