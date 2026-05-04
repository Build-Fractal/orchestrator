---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P03"
milestone: "M032"
provides:
  - "FR-7 partial templating; FR-8 --with-giscus scope on wiki-init.sh; SC-4 acceptance; three P03 verifiers; in-flight repair to P02 verifier check 10"
requires:
  - "P02"
affects:
  - "P03/T02,P03/T05"
key_files:
  - "wiki/overrides/partials/comments.html,scripts/lifecycle/wiki-init.sh,tests/m032-acceptance/p02-wiki-init-with-giscus.sh,tools/verify/m032-p03-giscus-templating.sh,tools/verify/m032-p03-with-giscus-scope.sh,tools/verify/m032-p03-acceptance-shape-sc4.sh,tools/verify/m032-p02-wiki-init-default-scope.sh"
key_decisions:
  - "FR-7,FR-8,SC-4,US-3-AS-3,AD-19,MEM001,MEM030,M026"
patterns_established:
  - "dual-template interpolation surface; TOOL_HELPER_STUB test envelope extending M026 stub convention to opt-in failure-mode injection; grep -F -e for leading-dash text-grep tokens on BSD grep; compose-don't-replace EXIT traps; in-flight repair convention mirroring P01 precedent"
drill_down_paths:
  - ".orchestrator/milestones/M032/phases/P03/tasks/T01-with-giscus-scope-PAYLOAD.md"
duration: "180m"
verification_result: "pass"
completed_at: "2026-05-04T21:03:31Z"
---

## What Shipped

T01 lands the first composable scope on top of P02's default-scope
`wiki-init.sh`: FR-7 (Giscus partial templating), FR-8 (`--with-giscus`
scope on `wiki-init.sh`), and the SC-4 acceptance script that exercises
both surfaces end-to-end. The three sub-deliverables ship together
because partial templating without the script that substitutes against
it would leave any consumer running `init` between landings with a
placeholder partial they have no recourse to resolve.

### Deliverables

1. **FR-7 partial templating** — `wiki/overrides/partials/comments.html`
   carries the four `{{giscus_*}}` M032-spec placeholder tokens
   interleaved with the existing `{{ config.extra.giscus.* }}` Jinja
   interpolations. Concatenation shape (`data-repo="{{giscus_repo}}{{ config.extra.giscus.repo }}"`)
   is load-bearing — bundle-staged copies carry both unrendered, so
   `wiki-init.sh --with-giscus` substitutes the M032 placeholder at
   install time and `mkdocs build` then resolves the Jinja form (which
   may be empty for projects driving Giscus IDs entirely through the
   M032 path). The orchestrator-repo-local copy uses the Jinja+!ENV path
   directly (no `--with-giscus` run against the orchestrator itself);
   the M032 placeholders resolve to the empty string at `mkdocs build`.
   Coexistence model documented in the partial via a `{# ... #}` Jinja
   comment block keyed on `M032/P03/T01 — FR-7`.

2. **FR-8 `--with-giscus` scope** — `scripts/lifecycle/wiki-init.sh`
   recognizes `--with-giscus --repo <owner>/<repo> --category <name>`
   and executes the four-step workflow: invoke `giscus-ids-from-gh.sh`
   (with `M032_GISCUS_IDS_FROM_GH_STUB=1|fail` test-only stub envelope),
   parse four `export GISCUS_*` lines from stdout, sed-substitute the
   four placeholders in the staged partial, invoke
   `wiki-giscus-config-check.sh` as the post-step verifier (with the
   four `GISCUS_*` env vars exported from the substituted values).
   New exit codes 7 / 8 / 9 added; exit 5 narrowed to `--deploy`-only
   (T02 replaces it). The new trap composes `TMP_PARTIAL` cleanup with
   the upstream `TUPLES_FILE` trap so the cleanup envelope is preserved
   across both blocks.

3. **SC-4 acceptance** — `tests/m032-acceptance/p02-wiki-init-with-giscus.sh`
   stages a `mktemp -d` copy of the P01 fresh-project fixture (SC-3
   convention preserves the read-only fixture invariant) and exercises
   six branches: FR-7 placeholder presence, FR-8 happy path (stub mode 1),
   post-step verifier, failure injection (stub mode `fail`), re-run
   idempotency (sha-256 stable across two same-flag invocations), and
   the overwrite branch (US-3 AS-3, different `--repo` / `--category`
   re-substitutes). Final line is `SUMMARY: SC-4 acceptance pass=6 fail=0`.

### Verifiers (project-owned, AD-19 single-script-file shape)

- `tools/verify/m032-p03-giscus-templating.sh` — 9/9 PASS — FR-7 four
  placeholder tokens + Jinja coexistence + FR-7 comment block marker.
- `tools/verify/m032-p03-with-giscus-scope.sh` — 13/13 PASS — text-grep
  on the script body for the eleven load-bearing tokens, plus a
  hermetic stub-mode happy-path and failure-injection branch against a
  tmpdir fixture (NOT the shared P01 fixture — the SC-4 acceptance
  script exercises the shared fixture). Used `grep -F -e "$tok"` to
  handle leading-dash tokens (`--with-giscus`, `--repo`, `--category`)
  on BSD grep.
- `tools/verify/m032-p03-acceptance-shape-sc4.sh` — 11/11 PASS — text-grep
  on the SC-4 script for the eleven load-bearing tokens that prove it
  exercises all six branches.

## In-flight Repair

`tools/verify/m032-p02-wiki-init-default-scope.sh` check 10 was relaxed
from `exits 5 / reserved for P03` to `exits 2 / requires both --repo`
to reflect the new T01 contract — bare `--with-giscus` (no `--repo` /
`--category`) returns exit 2 with the missing-required-arg diagnostic.
Mirrors the P01 in-flight repair at commit `4dedb92a` where P01
verifiers were relaxed once P02 added the `wiki/` `project_assets`
entry. P02 phase suite recovered to 12/12 PASS post-repair (was
11/11 + 1 FAIL in the broken-by-T01 transition state).

## Verification Results

- `tools/verify/m032-p03-giscus-templating.sh`: 9/9 PASS
- `tools/verify/m032-p03-with-giscus-scope.sh`: 13/13 PASS
- `tools/verify/m032-p03-acceptance-shape-sc4.sh`: 11/11 PASS
- `tests/m032-acceptance/p02-wiki-init-with-giscus.sh`: 6/6 PASS
- `tools/verify/m032-p02-phase-suite.sh`: 12/12 PASS post-repair

## Key Decisions

- **Coexistence model (FR-7)**: the four `data-*` lines carry BOTH the
  M032 `{{giscus_*}}` placeholder AND the existing
  `{{ config.extra.giscus.* }}` Jinja interpolation. Concatenated with
  no separator. The two interpolation paths are runtime-disjoint:
  the M032 path runs at install time (sed-substitution); the Jinja
  path runs at `mkdocs build` time. Either can be the sole source of
  truth, depending on the consumer's chosen path.
- **`wiki-giscus-config-check.sh` invocation contract** — the plan
  prerequisite text described a `--project-dir <dir>` flag the
  current script doesn't accept. Rather than mutate the prerequisite
  helper (out-of-scope), `wiki-init.sh` exports the four
  `GISCUS_*` env vars from the substituted values directly into the
  child process and invokes the verifier with `--quiet` only. This
  satisfies the load-bearing contract (verifier exits 0 when the env
  vars are populated) without modifying the prerequisite.
- **Compose-with-existing-trap pattern** — the new `TMP_PARTIAL` trap
  composes with the upstream `TUPLES_FILE` cleanup trap rather than
  replacing it, then restores the upstream-only trap after the giscus
  block exits. Avoids the `trap - EXIT`-clears-everything failure mode
  in compound-cleanup paths.
- **SC-4 fixture-staging convention** — the SC-4 script stages a
  `mktemp -d` copy of the P01 fresh-project fixture rather than
  mutating the committed read-only fixture. Mirrors SC-3's pattern in
  `p02-wiki-init-default-scope.sh` and preserves the fixture's
  read-only invariant documented in its README.

## Patterns Established

- **Dual-template interpolation surface for opt-in install-time
  substitution** — when an asset has both an install-time substitution
  path and a build-time interpolation path that share a target line,
  concatenate the two interpolation forms (no separator) on the same
  line. Bundle-staged copies carry both unrendered; whichever path the
  consumer chooses, the other resolves to the empty string. The
  `{{giscus_repo}}{{ config.extra.giscus.repo }}` shape is a
  replicable pattern for future opt-in install-time scopes.
- **`<TOOL>_<HELPER>_STUB=<1|fail>` test envelope** — extends the
  M026/MEM030 `<TOOL>_<NAME>` env-var convention to opt-in
  failure-mode injection alongside happy-path stubbing. `1` returns
  deterministic fixture output; `fail` exits non-zero with the
  load-bearing failure-mode diagnostic. Operator-facing surface MUST
  NOT honor the unset path implicitly — the env-var-only access keeps
  it test-only.
- **`grep -F -e "$tok"` for leading-dash tokens on BSD grep** — when
  text-grepping for tokens that may start with `-` (e.g.,
  `--with-giscus`), wrap the token with `-e` so BSD grep doesn't
  treat the leading dash as a flag attempt. The `-F` (literal) flag
  alone isn't sufficient.
- **Compose-don't-replace traps** — when adding a new EXIT trap that
  cleans up a temp file inside a function block, compose with the
  upstream trap (`trap 'rm -f "$NEW" "$OLD"' EXIT`) rather than
  replacing it; restore the upstream-only trap after the block exits.
- **In-flight repair convention** — when a downstream task lands a
  surface that invalidates an upstream verifier's hardcoded
  contract-text assertion, relax the assertion in the same
  task/commit and document the repair in the task summary. Mirrors
  P01's `4dedb92a` in-flight repair pattern.

## Affects Downstream

- **T02 (`--deploy` scope)** — picks up the now-narrowed exit-5 reject
  branch (deploy-only) and replaces it with the real `--deploy`
  workflow. The `WITH_DEPLOY=1` reject text is the load-bearing seam.
- **T03 (custom-nav region)** — independent of T01.
- **T04 (with-feature-pattern doc + throwaway fixture)** — the
  `<TOOL>_<HELPER>_STUB=<1|fail>` envelope is a candidate
  documentation point for the FR-13 `## --with-<feature> Progressive
  Opt-In Flag Pattern` section.
- **T05 (acceptance + phase-suite + scope-guard)** — the SC-4
  acceptance script + the three T01-owned verifiers are inputs to
  `tools/verify/m032-p03-phase-suite.sh`. The P03 scope-guard
  allowlist must include `tools/verify/m032-p03-*.sh`,
  `tests/m032-acceptance/p02-wiki-init-with-giscus.sh`,
  `wiki/overrides/partials/comments.html`,
  `scripts/lifecycle/wiki-init.sh`, and the P02 verifier modified by
  the in-flight repair.
- **M033 paired-launch seams** — unaffected; T01 does not touch the
  `tests/paired-m032-m033/` surface.
