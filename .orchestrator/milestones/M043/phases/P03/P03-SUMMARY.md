---
schema_version: "1.0"
type: phase-summary
id: "P03"
parent: "M043"
milestone: "M043"
provides:
  - "scripts/diagnostics/check-wiki-pages-exposure.sh framework-owned fallback-only footgun warning emitter (FR-10/AD-2: fires only on private+github-pages regardless of plan, 'ignore if you are on GitHub Enterprise Cloud' note, NO plan-detection; --mode doctor|status; gh repo view visibility + ORCH_WIKI_REPO_VISIBILITY test seam; unknown-visibility degrades silent),run-doctor.sh advisory registration + commands/status.md status-surface section (both FR-10 surfaces wired),references/installation.md Wiki Deploy Targets section (FR-11/SC-7: Enterprise-only pitfall + build-green/deploy-422 mode + Cloudflare recipe + token scopes Pages-Edit/Access-Edit/Account-Settings-Read no-extra-Read + Zero Trust prereq + symmetric Cloudflare entitlement-lapse THREAT-7 + custom-domain self_hosted_domains THREAT-11 + CON-7 domain-list reprovision + giscus read-but-not-comment caveat),tests/fixtures/m043-p03/ SC-6 single-branch fixture matrix (5 configs) + giscus golden,five tools/verify/m043-p03-*.sh verifiers (warning-matrix SC-6,doctor-wiring FR-10+AD-2,installation-anchors SC-7,giscus-bytestable SC-8) + m043-p03-phase-suite.sh aggregator (pass=4 fail=0)"
requires:
  - "P01,P02"
affects:
  - "P04"
key_files:
  - "scripts/diagnostics/check-wiki-pages-exposure.sh,scripts/diagnostics/run-doctor.sh,commands/status.md,references/installation.md,tests/fixtures/m043-p03/private-github-pages/.orchestrator/config.yml,tests/fixtures/m043-p03/private-cloudflare/.orchestrator/config.yml,tests/fixtures/m043-p03/public-github-pages/.orchestrator/config.yml,tests/fixtures/m043-p03/public-cloudflare/.orchestrator/config.yml,tests/fixtures/m043-p03/private-default/.orchestrator/config.yml,tests/fixtures/m043-p03/giscus-comments.golden.html,tools/verify/m043-p03-warning-matrix.sh,tools/verify/m043-p03-doctor-wiring.sh,tools/verify/m043-p03-installation-anchors.sh,tools/verify/m043-p03-giscus-bytestable.sh,tools/verify/m043-p03-phase-suite.sh"
key_decisions:
  - "AD-2 fallback-only committed: warning fires on (private+github-pages) regardless of plan with Enterprise-Cloud note; NO gh-api plan probe (doctor-wiring verifier mechanically asserts the absence in executable lines); reliable-detection and both-branch variants stay dropped from M043 scope,emitter is a single framework-owned doctor sub-check shared by both surfaces (doctor via run_check advisory flag; status via --mode status clean-output); advisory classification means a fired warning increments advisory_warnings but never flips doctor health to NEEDS_ATTENTION,unknown repo visibility (no gh / not authed / not a gh repo) degrades to SILENT — never false-alarm on a repo we cannot confirm private; visibility detection (gh repo view --json visibility) is distinct from the dropped plan detection,SC-8 giscus byte-stability is an M043-scoped golden-diff (proves M043 changed no giscus file; a future milestone that legitimately changes the partial re-baselines the golden)"
patterns_established:
  - "shared framework warning emitter with --mode doctor|status: doctor mode emits warning body + trailing DOCTOR: line for run_check parsing,status mode emits only the warning body when firing,resolver SCRIPT located via $SCRIPT_DIR while config-root passed as the resolver argument (the two roots differ for a diagnosed project vs the framework install),SC-6 fixture matrix as placeholder-only config dirs with visibility injected via env seam (no live gh in tests),m043-p03 phase-suite mirrors P02 run_gate aggregator + SUMMARY pass=N fail=N line"
drill_down_paths:
  - ".orchestrator/milestones/M043/phases/P03/tasks/T01-warning-and-surfaces-SUMMARY.md, .orchestrator/milestones/M043/phases/P03/tasks/T02-installation-docs-SUMMARY.md, .orchestrator/milestones/M043/phases/P03/tasks/T03-giscus-and-suite-SUMMARY.md"
duration: "10m"
verification_result: "pass"
completed_at: "2026-06-05T03:00:18Z"
observability_surfaces:
  - "tools/verify/m043-p03-phase-suite.sh (pass=4 fail=0)"
---

P03 delivers the fallback-only GitHub-Pages footgun warning (both `doctor` and
`status` surfaces) plus the FR-11 wiki-deploy documentation and the FR-12 giscus
byte-stability assertion. Closed verify-pass at Full intensity under subagent
dispatch (3 tasks, T01 → T02 → T03; scope: P03-only per operator, halting before
P04).

Shipped (3 tasks):
- **T01** — `scripts/diagnostics/check-wiki-pages-exposure.sh`, the framework-owned
  fallback-only warning emitter (AD-2: fires on the (private repo + `github-pages`)
  tuple **regardless of plan**, carries the "ignore if you are on GitHub Enterprise
  Cloud" note, silent on every other (visibility × target) combination, NO
  plan-detection). Wired into both FR-10 surfaces: an advisory `run_check` line in
  `run-doctor.sh` (never flips health) and a status-surface section in
  `commands/status.md`. SC-6 single-branch fixture matrix (5 configs incl. an
  absent-key default-resolves-to-github-pages row) + the `warning-matrix.sh`
  (SC-6) and `doctor-wiring.sh` (FR-10 wiring + AD-2 no-plan-probe) verifiers.
- **T02** — the `references/installation.md` **Wiki Deploy Targets** section
  (FR-11/SC-7): the Enterprise-only-private-Pages pitfall, the build-green/
  deploy-422 lapsed-entitlement mode, the Cloudflare Pages + Access recipe, the
  token-scope table (Pages — Edit + Access: Apps and Policies — Edit + Account
  Settings — Read, **no extra Read scope** — the FR-3a probe reuses the Edit token
  per P00 #Q-5-sub), the Zero Trust prerequisite, the **symmetric** Cloudflare
  entitlement-lapse failure mode (THREAT-7: trial→free / 50-user free-tier limit,
  with the FR-3a health-check failure as the observable signal), the custom-domain
  / `self_hosted_domains` note (THREAT-11), the CON-7 domain-list reprovision
  caveat, and the giscus read-but-not-comment caveat. `installation-anchors.sh`
  grep-asserts all 15 anchors.
- **T03** — the giscus byte-stability golden + `giscus-bytestable.sh` (SC-8: the
  partial diffs byte-identical; M043 introduces no giscus change) and
  `m043-p03-phase-suite.sh` aggregating all four P03 gates (pass=4 fail=0).

Three issues caught and resolved during the run (all reported by the dispatched
agents, none silently absorbed):
1. **T01 emitter** — the plan's verbatim emitter resolved the P01 resolver under
   `$ROOT` (the config-root), which for a diagnosed project / fixture dir lacks
   `scripts/wiki/`, so `target` always degraded to `unknown` and every FIRE row
   went silent. Fixed to locate the resolver **script** via `$SCRIPT_DIR` while
   still passing `$ROOT` as the resolver's config-root argument — correct for both
   the fixture matrix and production. Caught by the `warning-matrix.sh` gate.
2. **T02 docs** — a line-wrap split the co-authored anchor `FR-3a pre-deploy
   health-check` across two lines, failing the line-oriented grep. Reflowed so the
   anchor stays intact; anchor string unchanged.
3. **Phase plan (planner-authored)** — the `check-wiki-pages-exposure.sh` artifact
   must-have asserted `contains "ignore if Enterprise Cloud"`, but the emitter's
   actual AD-2 note reads "ignore if you are on GitHub Enterprise Cloud". Pattern
   retargeted to the actual text during Tier 1 verification; behavior never
   weakened (the `warning-matrix.sh` Enterprise-note assertion was green
   throughout). Re-run: 53 PASS / 0 FAIL.

CON-6 (the milestone's load-bearing two-site exposure guard) is **untouched** —
P03 added no deploy invocation and modified neither the FR-3a pre-deploy health
check (P01) nor the provisioner (P02). CON-4 github-pages byte-stability is
preserved (P03 touched no emit path). The warning hardens the *default*
github-pages path against the pbj-central silent-exposure / silent-422-freeze
modes; the two structural enforcement sites remain the load-bearing defense.

Verification: Tier 1 must-haves 53/0 (after the one planner-pattern retarget);
boundary-map SKIP (prose-form Produces, as P01/P02); Tier 2 framework SKIP (no
configured commands) with the project phase-suite green (pass=4 fail=0); Tier 3
behavioral confirmed FR-10 fire/silence + both-surfaces wiring + AD-2 no-plan
boundary + SC-8 giscus byte-stability; Tier 4 n/a (no human-gated item in P03).
Report at phases/P03/P03-VERIFICATION.md (overall_result: pass).

Carried forward: P03 has no deferred-validation item of its own — the warning is
deterministic and the docs are anchor-verified. With P01–P03 closed, M043 is at
shippable scope (US-1..US-3); P04 (US-4 live / friendly-tester validation:
real Cloudflare account end-to-end, the `302 → cloudflareaccess.com` redirect, a
green CI run, a working giscus comment) is the sole remaining phase — a
human-recruitment task per spec FR-13 / SC-9, which the milestone may forward-point
under a signed deferred-validation note per house precedent.
