---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P00"
milestone: "M043"
name: "Author the P00 structural verifiers + phase-suite aggregator"
depends_on: ["T01"]
---

## Prerequisites

- T01 has run: `.orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md` exists, and `fixture-seeds/` contains the five JSON seeds + README. (The verifiers you author here read those artifacts; they will FAIL until T01's outputs are on disk.)
- `tools/verify/` exists (it does — 500+ project-owned verifiers already live there).

## Description

Author the three project-owned structural verifiers for P00. They mechanically assert the *shape* of T01's research deliverable — the findings note resolves both questions with closed-set Decisions + provenance, and the fixture seeds are present + apex/wildcard-bearing. The findings *content* is Tier 3 (research judgment, possibly doc-derived); a Tier 1 verifier can only prove structure, which is the correct ceiling for a spike.

All three live under `tools/verify/` with the milestone-slug-prefixed naming (`m043-p00-*`) required by the plan-phase naming convention — phase-only slugs (`p00-*`) are forbidden because every milestone has a P00 and the unprefixed form silently clobbers prior milestones' aggregators.

The phase-suite aggregator and the two gates it calls are ALL authored in this single task, so this task's own `## Verification` resolves on disk when it runs (plan-time discipline rule 2 — no cross-task verifier dependency).

## Steps

1. **Author `tools/verify/m043-p00-findings-shape.sh`** — verbatim:

   ```bash
   #!/usr/bin/env bash
   # m043-p00-findings-shape.sh — assert the P00 Cloudflare-API findings note
   # resolves #Q-5-sub (FR-3a probe Decision) and #Q-6 (FR-9 diagnostic Decision)
   # with closed-set values + evidence provenance. Tier 1 structural check only.
   set -u

   NOTE=".orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md"
   fail=0

   check() {
     # $1 = human label, $2 = exit status of a preceding test (0=pass)
     if [ "$2" -eq 0 ]; then
       echo "PASS: $1"
     else
       echo "FAIL: $1"
       fail=1
     fi
   }

   test -f "$NOTE"
   check "findings note exists" $?

   if [ ! -f "$NOTE" ]; then
     echo "SUMMARY: m043-p00-findings-shape.sh pass=0 fail=1"
     exit 1
   fi

   grep -q "#Q-5-sub" "$NOTE"
   check "#Q-5-sub section present" $?

   grep -q "FR-3a Probe Decision" "$NOTE"
   check "FR-3a Probe Decision heading present" $?

   grep -Eq "authenticated-edit-token|authenticated-new-read-scope|unauthenticated-redirect-fallback" "$NOTE"
   check "FR-3a probe Decision is a closed-set value" $?

   grep -q "#Q-6" "$NOTE"
   check "#Q-6 section present" $?

   grep -q "FR-9 Diagnostic Decision" "$NOTE"
   check "FR-9 Diagnostic Decision heading present" $?

   grep -Eq "distinguishable|indistinguishable" "$NOTE"
   check "FR-9 Decision is a closed-set value" $?

   grep -q "Fixture-Seed Inventory" "$NOTE"
   check "Fixture-Seed Inventory section present" $?

   grep -q "Evidence Provenance" "$NOTE"
   check "Evidence Provenance section present" $?

   grep -Eq "live-confirmed|doc-derived" "$NOTE"
   check "evidence provenance tag present" $?

   if [ "$fail" -eq 0 ]; then
     echo "SUMMARY: m043-p00-findings-shape.sh pass=ALL fail=0"
     exit 0
   fi
   echo "SUMMARY: m043-p00-findings-shape.sh pass=SOME fail=1"
   exit 1
   ```

2. **Author `tools/verify/m043-p00-fixture-seeds-present.sh`** — verbatim:

   ```bash
   #!/usr/bin/env bash
   # m043-p00-fixture-seeds-present.sh — assert the P02 fixture seeds captured by
   # P00/T01 are present and the Access-app create payload carries BOTH the apex
   # and a wildcard self_hosted_domain (the SC-3 apex+wildcard seed). Tier 1.
   set -u

   DIR=".orchestrator/milestones/M043/phases/P00/fixture-seeds"
   fail=0

   check() {
     if [ "$2" -eq 0 ]; then
       echo "PASS: $1"
     else
       echo "FAIL: $1"
       fail=1
     fi
   }

   for f in \
     pages-project-create-request.json \
     access-app-create-request.json \
     access-policy-create-request.json \
     zero-trust-not-enabled-response.json \
     missing-scope-response.json \
     README.md
   do
     test -s "$DIR/$f"
     check "seed present and non-empty: $f" $?
   done

   APP="$DIR/access-app-create-request.json"
   if [ -f "$APP" ]; then
     grep -q "self_hosted_domains" "$APP"
     check "access-app seed declares self_hosted_domains" $?

     grep -q "\.pages\.dev" "$APP"
     check "access-app seed contains an apex *.pages.dev domain" $?

     grep -q "\*\." "$APP"
     check "access-app seed contains a wildcard (\\*.) domain" $?
   else
     check "access-app seed contains apex+wildcard domains" 1
   fi

   if [ "$fail" -eq 0 ]; then
     echo "SUMMARY: m043-p00-fixture-seeds-present.sh pass=ALL fail=0"
     exit 0
   fi
   echo "SUMMARY: m043-p00-fixture-seeds-present.sh pass=SOME fail=1"
   exit 1
   ```

3. **Author `tools/verify/m043-p00-phase-suite.sh`** — verbatim:

   ```bash
   #!/usr/bin/env bash
   # m043-p00-phase-suite.sh — P00 phase-suite aggregator. Runs both P00 gates
   # in order, exits 0 iff both pass, emits one SUMMARY line.
   set -u

   ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   cd "$ROOT" || exit 2

   pass=0
   fail=0

   run_gate() {
     # $1 = gate script path (relative to repo root)
     if bash "$1"; then
       pass=$((pass + 1))
     else
       fail=$((fail + 1))
     fi
   }

   run_gate "tools/verify/m043-p00-findings-shape.sh"
   run_gate "tools/verify/m043-p00-fixture-seeds-present.sh"

   echo "SUMMARY: m043-p00-phase-suite.sh pass=$pass fail=$fail"
   if [ "$fail" -eq 0 ]; then
     exit 0
   fi
   exit 1
   ```

4. **Make the three scripts executable** (`chmod +x tools/verify/m043-p00-findings-shape.sh tools/verify/m043-p00-fixture-seeds-present.sh tools/verify/m043-p00-phase-suite.sh`).

5. **Run the suite** to confirm it reports `pass=2 fail=0` against T01's artifacts.

## Must-Haves

This task addresses the phase must-have:
- The phase-suite aggregator runs both gates, exits 0 iff both pass, emits a single `SUMMARY:` line.

It also provides the Check verifiers cited by the other phase must-haves (findings-shape, fixture-seeds-present) — those Truths' `Check:` commands resolve to the scripts authored here.

## Verification

<!-- These verifiers are co-authored in THIS task, so they resolve on disk
     when this task's verification runs (plan-time discipline rule 2). The
     phase-suite reads T01's artifacts, which exist because T02 depends on T01. -->

`test -x tools/verify/m043-p00-findings-shape.sh`

`test -x tools/verify/m043-p00-fixture-seeds-present.sh`

`test -x tools/verify/m043-p00-phase-suite.sh`

`bash tools/verify/m043-p00-findings-shape.sh`

`bash tools/verify/m043-p00-fixture-seeds-present.sh`

`bash tools/verify/m043-p00-phase-suite.sh`

## Inputs

### From Previous Tasks

- `.orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md` (from T01)
  - Shape contract the verifier asserts: contains the literal section markers `#Q-5-sub`, `FR-3a Probe Decision`, `#Q-6`, `FR-9 Diagnostic Decision`, `Fixture-Seed Inventory`, `Evidence Provenance`; the FR-3a Decision matches `authenticated-edit-token|authenticated-new-read-scope|unauthenticated-redirect-fallback`; the FR-9 Decision matches `distinguishable|indistinguishable`; a provenance tag matches `live-confirmed|doc-derived`.
- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/` (from T01)
  - Contract: five non-empty JSON seeds (`pages-project-create-request.json`, `access-app-create-request.json`, `access-policy-create-request.json`, `zero-trust-not-enabled-response.json`, `missing-scope-response.json`) + `README.md`; `access-app-create-request.json` contains `self_hosted_domains`, an apex `*.pages.dev` literal, and a `*.` wildcard literal.

### From Disk (Pre-existing)

- `tools/verify/` — existing project-owned verifier directory; the `m043-p00-*` naming convention follows the M036 `m036-p00-*` precedent.

## Constraints

- **AD-19 single-script-file shape** — the verifiers ARE the script files; their internal logic may use loops/conditionals freely (they run as `bash <file>`, not as inline Check commands). The `## Verification` lines above are all single `bash <file>` / `test` invocations.
- **Bash 3.2 / POSIX-sh** — no `declare -A`, no process substitution, no `mapfile`. (CON-5; the `for f in \ ... ` loop + `$((...))` arithmetic used above are 3.2-safe.)
- **Milestone-slug-prefixed names required** — `m043-p00-*`, never `p00-*` (avoids the cross-milestone aggregator clobber the convention warns about).
- **No emit to `scripts/verify/`** — these are project-owned, slug-bearing per-phase verifiers; they MUST live under `tools/verify/` (M032 Finding A — `scripts/` is bulk-staged + gitignored + clobbered on install in downstream projects).

## Expected Output

Three executable scripts under `tools/verify/`. Running `bash tools/verify/m043-p00-phase-suite.sh` prints the two gate SUMMARY lines followed by `SUMMARY: m043-p00-phase-suite.sh pass=2 fail=0` and exits 0.
