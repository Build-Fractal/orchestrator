---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P03"
milestone: "M032"
provides:
  - "FR-9 + MIT-007 + MIT-008 --deploy scope on wiki-init.sh (four-step ordered sequence: gh api PATCH discussions=true | wiki-deploy.sh | MIT-007 read-before-write Pages guard | gh api PUT /pages); FR-10 cwd-vs-repo_url sanity gate on wiki-deploy.sh as gate-0 (Finding J counter-pattern); structured wiki-deploy-mutation JSONL audit-trail with success and failure record shapes appended to .orchestrator/execution-log.jsonl BEFORE live URL print; --force-pages-reconfigure escape hatch; M032_DEPLOY_GH_API_STUB and M032_DEPLOY_GH_API_STUB_DIR test-only env-var stub envelope per M026/MEM030; M032_WIKI_DEPLOY_BYPASS_CWD_GATE test-only bypass; new exit codes 10-13; tools/verify/m032-p03-deploy-scope.sh (18/18 PASS) + tools/verify/m032-p03-wiki-deploy-cwd-gate.sh (8/8 PASS); in-flight repair to m032-p02-wiki-init-default-scope.sh check 11 (reject-stub assertion replaced with stub-mode workflow assertion)"
requires:
  - "P02,P03/T01"
affects:
  - "P03/T04,P03/T05,M033/P05"
key_files:
  - "scripts/lifecycle/wiki-init.sh,scripts/wiki/wiki-deploy.sh,tools/verify/m032-p03-deploy-scope.sh,tools/verify/m032-p03-wiki-deploy-cwd-gate.sh,tools/verify/m032-p02-wiki-init-default-scope.sh"
key_decisions:
  - "FR-9,FR-10,MIT-007,MIT-008,AD-19,MEM001,MEM030,M026,Finding-J,CON-6"
patterns_established:
  - "four-step ordered remote-state mutation with read-before-write guard + structured JSONL audit-trail BEFORE side-effect-print (Constitution VI applied to remote-state mutations); per-step parallel-scalar mutation flags as bash 3.2 substitute for declare -A object arrays; literal-string JSON array concatenation via parameter-expansion-safe leading-comma elision pattern ${MUT:+$MUT,}; audit_failure helper defined ONCE near other helpers consumed by every failure path; gate-0 cwd-vs-canonical-source sanity gate as Finding J counter-pattern (validates invocation cwd matches mkdocs.yml repo_url before any remote mutation fires); test-only TOOL_HELPER_STUB and TOOL_HELPER_STUB_DIR pair (M026/MEM030 envelope) for hermetic verifier coverage of multi-branch state-machine without network; grep -F -e for leading-dash text-grep tokens on BSD grep (mirror of T01); in-flight repair convention extended to a P02-owned verifier whose check became structurally obsolete on T02 landing (reject-stub for deferred surface replaced by workflow assertion when the deferred surface lands)"
drill_down_paths:
  - ".orchestrator/milestones/M032/phases/P03/tasks/T02-deploy-scope-PAYLOAD.md"
duration: "180m"
verification_result: "pass"
completed_at: "2026-05-04T23:20:31Z"
---

## What Shipped

T02 lands the highest-blast-radius surface in M032: the `--deploy` scope
on `scripts/lifecycle/wiki-init.sh` plus the FR-10 cwd-vs-`repo_url:`
sanity gate on `scripts/wiki/wiki-deploy.sh`. The three pieces ship
together as a single atomic unit — splitting them would introduce a
window where `wiki-init.sh --deploy` invokes `wiki-deploy.sh` without
the FR-10 gate, replicating exactly the cross-project-cwd hazard the
gate was added to prevent.

### Deliverables

1. **FR-10 cwd-vs-`repo_url:` sanity gate** on `scripts/wiki/wiki-deploy.sh`
   as a new gate-0 (Finding J counter-pattern). Inserted immediately after
   the `cd "$ROOT"` line and before the existing "gate 1: giscus
   config-check" header. Parses `repo_url:` from `<ROOT>/wiki/mkdocs.yml`,
   compares against `git -C $ROOT remote get-url origin`, normalizes both
   to canonical `<owner>/<repo>` form (case-lowered owner, case-preserved
   repo; `.git` and protocol/host prefixes stripped). Mismatch fails closed
   with the `cross-project hazard` diagnostic before any gh-deploy fires.
   `M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1` is the test-only bypass for
   hermetic verifier coverage where the fixture has no real GH remote;
   the operator-facing surface never honors the unset path implicitly.

2. **FR-9 + MIT-007 + MIT-008 `--deploy` scope** on
   `scripts/lifecycle/wiki-init.sh`. Replaces the P02-baseline reject-stub
   at exit 5 with the four-step ordered sequence:
   - Step 1: `gh api PATCH /repos/<owner>/<repo>` with `has_discussions=true`.
   - Step 2: invoke `bash scripts/wiki/wiki-deploy.sh --root "$PROJECT_DIR"`
     (which itself runs the new FR-10 gate plus the four P02-baseline gates
     plus `mkdocs gh-deploy --force`).
   - Step 3: MIT-007 read-before-write Pages guard via
     `gh api GET /repos/<owner>/<repo>/pages` — three branches: 404 →
     proceed; gh-pages root already → no-op skip-PUT; incompatible source
     → exit 12 unless `--force-pages-reconfigure` is set.
   - Step 4: `gh api PUT /repos/<owner>/<repo>/pages` with
     `source[branch]=gh-pages` `source[path]=/` (only when needed).

   MIT-008 audit-trail JSONL append is the LAST action before the live
   URL print on success. Failure paths in steps 1/2/3/4 invoke the
   `audit_failure` helper (defined once near other helpers, consumes the
   parallel-scalar mutation flags MUT_DISCUSSIONS / MUT_GH_PAGES_BRANCH /
   MUT_PAGES_CONFIGURED) and append a `result: "failure"` record before
   exiting non-zero. New exit codes 10–13 documented in the file-header
   exit-code block.

3. **Two project-owned verifiers** under `tools/verify/m032-p03-*`:
   - `tools/verify/m032-p03-deploy-scope.sh` (18/18 PASS) — 15 static-text
     checks plus three hermetic stub-mode coverage branches: (a) happy
     path with no existing Pages → all three mutations recorded, success
     audit record; (b) Pages already configured for gh-pages root → no-op
     skip-PUT, audit record omits `pages_source_configured`; (c) Pages
     configured for incompatible source without `--force-pages-reconfigure`
     → exit 12, diagnostic on stderr, failure audit record on disk.
   - `tools/verify/m032-p03-wiki-deploy-cwd-gate.sh` (8/8 PASS) — 6
     static-text checks plus two FR-10 branches: (a) cwd / repo_url
     mismatch fires `cross-project hazard` diagnostic with non-zero exit;
     (b) bypass under `M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1` skips the gate
     cleanly.

### In-flight Repair

`tools/verify/m032-p02-wiki-init-default-scope.sh` check 11 was authored
during P02 as a placeholder asserting the `WITH_DEPLOY=1` reject-stub
behavior (exit 5 with "P03 deliverable" diagnostic). T02 lands the actual
P03 deliverable, replacing the reject-stub with the FR-9 workflow.
The check became structurally obsolete the moment T02's `wiki-init.sh`
amendment landed — the assertion `[ "$rc_deploy" -eq 5 ]` flipped from
green to red because `--deploy` now exits 0 (under stub mode) or 10
(without stub mode, real `gh api PATCH` failure on a fixture with no
credentials) instead of 5.

The minimal-touch repair: amend check 11 to set
`M032_DEPLOY_GH_API_STUB=1` and assert exit 0 (workflow ran end-to-end
hermetically). Check renamed to "wiki-init.sh --deploy under
M032_DEPLOY_GH_API_STUB=1 exits 0 (P03/T02 workflow lands)".

This mirrors T01's in-flight-repair convention against P02 verifier
check 10 (commit `8bd3dc7f`) and the P01-verifier in-flight repair from
P02/T02 (commit `4dedb92a`). The convention: when a downstream task
lands the surface a placeholder upstream check was guarding, the same
task is responsible for flipping the placeholder check from
deferred-state assertion to live-surface assertion. Tracking this in
the SUMMARY's `key_files` so the cross-phase regression battery
inherits visibility.

## Verification Results

| Verifier | Result |
|----------|--------|
| `tools/verify/m032-p03-deploy-scope.sh` | 18/18 PASS |
| `tools/verify/m032-p03-wiki-deploy-cwd-gate.sh` | 8/8 PASS |
| `tools/verify/m032-p02-wiki-init-default-scope.sh` (post-repair) | 19/19 PASS |
| `tools/verify/m032-p02-phase-suite.sh` | 12/12 PASS (no regression) |
| `tools/verify/m032-p03-giscus-templating.sh` (T01 deliverable) | 9/9 PASS (no regression) |
| `tools/verify/m032-p03-with-giscus-scope.sh` (T01 deliverable) | 13/13 PASS (no regression) |
| `tools/verify/m032-p03-acceptance-shape-sc4.sh` (T01 deliverable) | 11/11 PASS (no regression) |

## Key Decisions

- **FR-9 four-step ordering is load-bearing**: PATCH discussions → wiki-deploy
  (which carries gh-pages branch as a side-effect) → read-before-write
  Pages guard → PUT pages source. Reordering would either (a) configure
  Pages before the gh-pages branch exists (Pages 404), or (b) skip the
  read-before-write guard and force-overwrite an unrelated Pages source
  the operator may have configured manually. The four-step sequence is
  the safe-default contract.
- **MIT-007 read-before-write Pages guard with `--force-pages-reconfigure`
  escape hatch**: never silently overwrite an existing Pages source from a
  different branch/path. The escape hatch lives at the flag layer (not
  env-var) because it is operator-facing — the operator who owns the
  destination repo must opt into the destructive action explicitly.
- **MIT-008 audit-trail BEFORE live URL print**: the JSONL append is the
  LAST action before the URL print on success. This means the verifier's
  grep-for-record runs AFTER `wiki-init.sh` exits and would surface any
  URL-print-before-record race as a missing record. Constitution VI
  (State On Disk Is Truth) extended to remote-state mutations.
- **Failure-mode audit records**: a `result: "failure"` record is
  appended on every failure path (not just success). The mutations array
  reflects the truth on disk — it lists every step that successfully
  fired BEFORE the failed step. This makes operator-visible the
  distinction between "deploy never started" (no record) and "deploy
  started and failed at step X" (failure record with named step + rc).
- **FR-10 gate-0 placement on `wiki-deploy.sh` (not `wiki-init.sh`)**:
  the gate lives on the inner-loop script because `wiki-deploy.sh` is
  also called directly by operators outside the `wiki-init --deploy`
  envelope. Putting the gate at the inner script protects the
  direct-invocation path too. The outer `wiki-init.sh --deploy` step 2
  invokes `wiki-deploy.sh`, so the gate fires there as well — defense
  in depth.
- **Test-only env-var stub envelope follows M026/MEM030**:
  `M032_DEPLOY_GH_API_STUB=1` is the binary toggle;
  `M032_DEPLOY_GH_API_STUB_DIR` is the parameterized fixture-state seam.
  Mirrors T01's `M032_GISCUS_IDS_FROM_GH_STUB=1|fail` envelope. The
  operator-facing surface never honors the env-var-unset path implicitly.

## Patterns Established

- **Four-step ordered remote-state mutation with read-before-write guard**:
  read existing remote state via GET; branch on existing-state; only
  PUT/POST when state is incompatible; structured audit-trail append
  before any side-effect-print. Replicable for any milestone touching
  remote state across multiple endpoints.
- **Per-step parallel-scalar mutation flags** (`MUT_DISCUSSIONS`,
  `MUT_GH_PAGES_BRANCH`, `MUT_PAGES_CONFIGURED`) as bash 3.2 substitute
  for `declare -A` object arrays. Combined with `${MUT:+$MUT,}`
  parameter-expansion-safe leading-comma elision for literal-string
  JSON array concatenation. MEM001-compliant — no associative arrays,
  no process substitution.
- **`audit_failure` helper defined ONCE near other helpers**, consumed
  by every failure path. Keeps audit-record shape consistent across
  step 1/2/3/4 failures and avoids the cut-and-paste-drift class of bug
  that arises when multi-step scripts inline the audit emit per failure
  branch.
- **Gate-0 cwd-vs-canonical-source sanity gate** as Finding J counter-pattern:
  before any side-effect fires, validate that the invocation cwd matches
  the canonical-source declaration (in this case `mkdocs.yml repo_url`).
  Mismatch indicates the operator is running the script in the wrong
  project directory — fail closed, do not silently mutate the wrong
  remote.
- **Test-only `<TOOL>_<HELPER>_STUB` and `<TOOL>_<HELPER>_STUB_DIR` pair**
  (M026/MEM030 envelope) for hermetic verifier coverage of multi-branch
  state-machines without network access. The DIR companion provides a
  parameterized fixture-state seam for branch coverage; the binary
  toggle controls the stub-vs-live decision.
- **`grep -F -e <token>` for leading-dash text-grep tokens** on BSD
  grep — `grep -qF '--deploy' file` is interpreted as a flag by macOS
  grep; `grep -qF -e '--deploy' file` works on both BSD and GNU grep.
  Mirror of T01's identical learning.
- **In-flight repair convention extended to P02-owned verifiers**: when
  a downstream task lands the surface that a placeholder upstream check
  was guarding, the same task amends the upstream check from
  deferred-state assertion to live-surface assertion. Mirrors T01's
  P02 check 10 repair and P02/T02's P01-verifier repair (commit
  `4dedb92a`).

## Affects Downstream

- **P03/T04 (throwaway-fixture + SC-5 + SC-6 acceptance)** — picks up
  the live-network coverage of the FR-9 / MIT-007 / MIT-008 workflow
  against a throwaway GH repo per CON-5 / `tests/m032-acceptance/throwaway-fixture-protocol.md`.
  T02's verifiers cover stub-mode hermetic branches; T04 owns the
  full live-network end-to-end coverage.
- **P03/T05 (phase-suite + scope-guard)** — adds
  `m032-p03-deploy-scope.sh` and `m032-p03-wiki-deploy-cwd-gate.sh` to
  the phase-suite aggregator and includes the two new file paths in
  the scope-guard in-scope set. Baseline ref capture by T05 follows
  the P01/P02 convention.
- **M033/P05** — the paired-launch contract (M033/P05/T02 invokes
  `wiki-init --with-wiki --deploy` end-to-end). T02's `--deploy` scope
  is the load-bearing surface; M033/P05/T02's friendly-tester pass
  exercises the four-step workflow + audit-trail in the
  greenfield-empty / greenfield-with-materials / existing-codebase /
  migrating branches.
