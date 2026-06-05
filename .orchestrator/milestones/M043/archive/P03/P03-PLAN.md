---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M043"
goal: "Docs + fallback-only github-pages footgun warning (US-3): orchestrator:status / doctor warn on every (private repo + github-pages) config with an 'ignore if Enterprise Cloud' note and no plan-detection; references/installation.md documents the GitHub-Pages and the symmetric Cloudflare entitlement-lapse failure modes; giscus is asserted byte-stable on the Cloudflare build."
demo_sentence: "Running the wiki-exposure check against a (private + github-pages) fixture prints the public-exposure / 422-freeze warning with the 'ignore if Enterprise Cloud' note and a pointer to the Cloudflare target; against (cloudflare-access) or (public) it is silent; references/installation.md grep-asserts all FR-11 section anchors; and wiki/overrides/partials/comments.html diffs byte-identical to its golden (SC-8)."
risk: "medium"
depends_on: ["P01", "P02"]
---

## Must-Haves

<!-- Project-owned, slug-bearing verifiers under tools/verify/ (AD-19
     single-script-file shape; m043-p03-* milestone-prefixed naming). Each is
     co-authored by the task named in parentheses (Plan-Time Discipline rule 2:
     verifiers either pre-exist or are authored in the task whose deliverable
     they check). The one framework deliverable that ships + runs in consumers
     (the warning emitter) lives under scripts/diagnostics/ alongside its
     sibling doctor sub-checks; the test harness that asserts its behavior lives
     under tools/verify/. -->

### Truths

- The fallback-only footgun warning fires on exactly the (private repo + `github-pages`) tuple and is silent on every other (visibility × deploy_target) combination, regardless of plan, and the fired text carries the "ignore if Enterprise Cloud" note (AD-2 / SC-6 fallback branch / FR-10). (T01)
  - Check: `bash tools/verify/m043-p03-warning-matrix.sh`
- The warning is wired into BOTH surfaces: `scripts/diagnostics/run-doctor.sh` registers the emitter as an advisory sub-check that prints a `DOCTOR:` line, and `commands/status.md` references the emitter for the status surface; the emitter contains no plan-detection logic (no `gh api` plan probe), reading only `deploy_target` (via `resolve-deploy-target.sh`) and repo visibility (FR-10 / AD-2). (T01)
  - Check: `bash tools/verify/m043-p03-doctor-wiring.sh`
- `references/installation.md` documents, post-phase, the Enterprise-only-private-Pages pitfall, the build-green/deploy-422 lapsed-entitlement mode, the Cloudflare Pages + Access recipe, the required token scopes (Pages — Edit + Access: Apps and Policies — Edit + Account Settings — Read, with no extra Read scope), the Zero Trust prerequisite, the symmetric Cloudflare entitlement-lapse failure mode (THREAT-7), the custom-domain / `self_hosted_domains`-extension note (THREAT-11), the CON-7 domain-list reprovision caveat, and the giscus read-but-not-comment caveat (FR-11 / SC-7 / FR-12). (T02)
  - Check: `bash tools/verify/m043-p03-installation-anchors.sh`
- `wiki/overrides/partials/comments.html` is byte-identical to its captured golden — M043 introduces no giscus change on either deploy target (FR-12 / SC-8). (T03)
  - Check: `bash tools/verify/m043-p03-giscus-bytestable.sh`
- The P03 phase suite aggregates all four P03 gates and reports `pass=N fail=0`. (T03)
  - Check: `bash tools/verify/m043-p03-phase-suite.sh`

### Artifacts

- scripts/diagnostics/check-wiki-pages-exposure.sh (min 60 lines, contains "ignore if you are on GitHub Enterprise Cloud")
- tests/fixtures/m043-p03/private-github-pages/.orchestrator/config.yml (min 2 lines, contains "github-pages")
- tests/fixtures/m043-p03/private-cloudflare/.orchestrator/config.yml (min 2 lines, contains "cloudflare-access")
- tests/fixtures/m043-p03/public-github-pages/.orchestrator/config.yml (min 2 lines, contains "github-pages")
- tests/fixtures/m043-p03/public-cloudflare/.orchestrator/config.yml (min 2 lines, contains "cloudflare-access")
- tests/fixtures/m043-p03/private-default/.orchestrator/config.yml (min 1 lines, contains "wiki")
- tools/verify/m043-p03-warning-matrix.sh (min 30 lines, contains "Enterprise")
- tools/verify/m043-p03-doctor-wiring.sh (min 20 lines, contains "check-wiki-pages-exposure")
- tools/verify/m043-p03-installation-anchors.sh (min 20 lines, contains "deploy-422")
- tests/fixtures/m043-p03/giscus-comments.golden.html (min 30 lines, contains "giscus")
- tools/verify/m043-p03-giscus-bytestable.sh (min 15 lines, contains "comments.html")
- tools/verify/m043-p03-phase-suite.sh (min 15 lines, contains "SUMMARY")
- references/installation.md (min 754 lines, contains "Cloudflare Access")
- commands/status.md (min 258 lines, contains "check-wiki-pages-exposure")

### Key Links

- scripts/diagnostics/run-doctor.sh → scripts/diagnostics/check-wiki-pages-exposure.sh (run-doctor registers the emitter as an advisory sub-check)
- commands/status.md → scripts/diagnostics/check-wiki-pages-exposure.sh (the status surface invokes the emitter in status mode)
- scripts/diagnostics/check-wiki-pages-exposure.sh → scripts/wiki/resolve-deploy-target.sh (the emitter resolves deploy_target via the P01 resolver)
- tools/verify/m043-p03-warning-matrix.sh → scripts/diagnostics/check-wiki-pages-exposure.sh (the matrix verifier drives the emitter)
- tools/verify/m043-p03-giscus-bytestable.sh → wiki/overrides/partials/comments.html (the giscus verifier diffs the partial)
- tools/verify/m043-p03-phase-suite.sh → tools/verify/m043-p03-installation-anchors.sh (the aggregator runs the anchors gate)

## Tasks

### T01: Fallback-only footgun warning emitter + both surfaces + fixture matrix

Author the shared, framework-owned warning emitter
`scripts/diagnostics/check-wiki-pages-exposure.sh` (fallback-only per AD-2: fires
on the (private + `github-pages`) tuple regardless of plan, with the "ignore if
Enterprise Cloud" note; silent on every other combination; NO plan-detection
logic). Wire it into both surfaces: register it as an advisory sub-check in
`scripts/diagnostics/run-doctor.sh` and reference it from `commands/status.md`
for the `orchestrator:status` surface. Build the SC-6 single-branch fixture
matrix under `tests/fixtures/m043-p03/` (private/public × github-pages/cloudflare
+ a private-default absent-key row) and co-author the two verifiers
`m043-p03-warning-matrix.sh` (SC-6 fire/silence + Enterprise note) and
`m043-p03-doctor-wiring.sh` (both surfaces wired, no plan probe). See
`tasks/T01-warning-and-surfaces-PLAN.md`.

### T02: references/installation.md wiki-deploy footgun + symmetric Cloudflare docs

Add the FR-11 wiki-deploy documentation to `references/installation.md` — the
Enterprise-only-private-Pages pitfall, the build-green/deploy-422 lapsed-
entitlement mode, the Cloudflare Pages + Access recipe, the token-scope table
(Pages — Edit + Access: Apps and Policies — Edit + Account Settings — Read, no
extra Read scope per P00 #Q-5-sub), the Zero Trust prerequisite, the symmetric
Cloudflare entitlement-lapse failure mode (THREAT-7), the custom-domain /
`self_hosted_domains`-extension note (THREAT-11), the CON-7 domain-list
reprovision caveat, and the giscus read-but-not-comment caveat (FR-12). Co-author
the grep-anchor verifier `m043-p03-installation-anchors.sh`. See
`tasks/T02-installation-docs-PLAN.md`.

### T03: giscus byte-stability assertion + phase-suite aggregator

Capture the byte-exact golden of `wiki/overrides/partials/comments.html` and
author `m043-p03-giscus-bytestable.sh` (SC-8: diff the partial against the golden,
exit 0). Author `m043-p03-phase-suite.sh` aggregating all four P03 gates (the two
T01 verifiers, the T02 anchors verifier, and the giscus verifier). See
`tasks/T03-giscus-and-suite-PLAN.md`.

## Task Dependencies

```
T01 ─┐
T02 ─┼─→ T03
     │
(T01, T02 independent)
```

T01 (warning emitter + both surfaces + matrix) and T02 (installation.md docs)
touch disjoint files and are mutually independent. T03 captures the giscus golden
and authors the phase-suite aggregator, which runs the T01 and T02 verifiers — so
T03 runs last (its aggregator references the prior tasks' on-disk verifiers per
Plan-Time Discipline rule 2). Within autonomous dispatch the tasks run in the
linear order T01 → T02 → T03.

## Files Likely Touched

- scripts/diagnostics/check-wiki-pages-exposure.sh (create)
- scripts/diagnostics/run-doctor.sh (modify)
- commands/status.md (modify)
- references/installation.md (modify)
- tests/fixtures/m043-p03/private-github-pages/.orchestrator/config.yml (create)
- tests/fixtures/m043-p03/private-cloudflare/.orchestrator/config.yml (create)
- tests/fixtures/m043-p03/public-github-pages/.orchestrator/config.yml (create)
- tests/fixtures/m043-p03/public-cloudflare/.orchestrator/config.yml (create)
- tests/fixtures/m043-p03/private-default/.orchestrator/config.yml (create)
- tests/fixtures/m043-p03/giscus-comments.golden.html (create)
- tools/verify/m043-p03-warning-matrix.sh (create)
- tools/verify/m043-p03-doctor-wiring.sh (create)
- tools/verify/m043-p03-installation-anchors.sh (create)
- tools/verify/m043-p03-giscus-bytestable.sh (create)
- tools/verify/m043-p03-phase-suite.sh (create)

## Notes

- **Corpus-exhaustion gate (M042): not applicable.** P03 embeds no operator/SME
  open questions — the milestone's two genuinely-open items (#Q-5-sub, #Q-6) were
  research prerequisites resolved in P00's findings note; AD-2/AD-3 bound the
  warning policy at CONTEXT-finalization. The plan carries no question destined
  for a human, so the gate has nothing to filter.

- **AD-2 commitment (explicit).** SC-6 is satisfied by the **fallback branch
  ONLY**: the warning fires on all (private, github-pages) tuples regardless of
  plan, carries an "ignore if Enterprise Cloud" note, and is silent on every
  other target/visibility combination. The reliable-detection and both-branch
  variants are dropped from M043 scope (CONTEXT AD-2). The FR-10 fixture matrix
  (T01) is built around this single branch — there is no plan dimension and no
  `gh api` plan probe anywhere in the emitter. The `m043-p03-doctor-wiring.sh`
  verifier asserts the absence of plan-detection logic so the AD-2 boundary is
  mechanically enforced, not just documented.

- **Repo-visibility detection + graceful degradation.** The emitter resolves
  repo visibility from `gh repo view --json visibility -q .visibility` (run from
  the project root), with a test-only `ORCH_WIKI_REPO_VISIBILITY` env seam the
  fixture matrix uses to inject `private`/`public` without a live `gh`. When
  visibility cannot be determined (no `gh`, not authenticated, not a GitHub
  repo) the emitter stays **silent** — it never false-alarms on a repo it cannot
  confirm is private. This is the conservative-quiet choice for an advisory
  surface; the structural defense remains the two CON-6 enforcement sites (P01
  FR-3a health check + P02 provisioner). Visibility detection is distinct from
  the dropped plan detection: AD-2 removed the *plan* probe, not the
  *visibility* read.

- **Why advisory, not a health failure.** The emitter is registered with
  `run-doctor.sh`'s advisory flag (the `1` argument to `run_check`), so a fired
  warning increments `advisory_warnings` but does NOT add to `checks_total` or
  flip the health report to `NEEDS_ATTENTION`. The footgun warning is a config
  recommendation that can be a false positive on Enterprise Cloud (hence the
  note); advisory is the correct classification and matches the `check-plans.sh`
  / `check-anomalies.sh` advisory precedent.

- **Expected verifier output (prose, not a Verification command).** Each
  `tools/verify/m043-p03-*.sh` prints `PASS:` lines per assertion and a final
  `SUMMARY: <name> ... fail=0` (mirroring the P02 verifiers); the phase suite
  prints `SUMMARY: m043-p03-phase-suite.sh pass=4 fail=0`. These are documented
  here, NOT inside any task's `## Verification` fence, per the M028/P01 finding
  that `auto-loop.sh --step=V` eval's every line under `## Verification`.

- **Plan-Time Discipline checks performed at authoring.** (1) Prerequisite
  existence — `scripts/wiki/resolve-deploy-target.sh`, `scripts/diagnostics/run-doctor.sh`,
  `commands/status.md`, `references/installation.md`, and
  `wiki/overrides/partials/comments.html` all confirmed present on disk. (2)
  Verifier availability — every `## Verification` command is a verifier
  co-authored inside the same task. (3) Classifier shape — every `Check:` /
  `## Verification` command is a single-script-file `bash tools/verify/...`
  invocation; none trip the AD-19 / AP-009 shape-guard. (4) run-probe scope —
  verifiers are invoked directly via `bash tools/verify/...`, never through
  `run-probe.sh`. (6) Path-collision — `ls`-checked: none of the six declared
  `create` paths (`check-wiki-pages-exposure.sh`, `tests/fixtures/m043-p03/`,
  the five `m043-p03-*` verifiers, the golden) exists on disk.
