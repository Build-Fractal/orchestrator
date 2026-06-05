---
schema_version: "1.0"
id: "M043"
parent: null
milestone: "M043"
provides:
  - "Cloudflare Pages + Cloudflare Access as a first-class wiki-deploy target: wiki.deploy_target enum (github-pages default | cloudflare-access) with byte-identical github-pages path, the cloudflare-access deploy workflow (wiki-cloudflare.yml) with an FR-3a pre-deploy Access health check, an idempotent Cloudflare provisioner (Pages project -> Access app apex+wildcard -> allow policy), a fallback-only private-Pages footgun warning on both doctor and status surfaces, wiki-deploy-target documentation, and the US-4 live/friendly-tester validation infrastructure (protocol + recruitment kit + mechanical SC-9 evidence gate) closed at shippable scope under a signed deferred-validation note"
requires:
  - from: "M041"
    what: "scripts/wiki/ framework-owned carve-out (provisioner + setup scripts live under scripts/wiki/)"
  - from: "M037"
    what: "giscus wiki-comments partial (unchanged across deploy targets per FR-12; byte-stability asserted)"
affects:
  - "wiki-ux-deep + external-tool-adapters (future demand-driven wiki milestone)"
key_files:
  - "templates/orchestrator-config-default.yml,scripts/wiki/resolve-deploy-target.sh,templates/wiki-cloudflare-deploy.yml.tmpl,scripts/lifecycle/wiki-init.sh,scripts/wiki/wiki-deploy.sh,scripts/wiki/cloudflare-access-setup.sh,scripts/diagnostics/check-wiki-pages-exposure.sh,scripts/diagnostics/run-doctor.sh,commands/status.md,references/installation.md,tests/fixtures/m043-cloudflare/,tests/fixtures/m043-p01/,tests/fixtures/m043-p03/,tests/m043-acceptance/live-deploy/,.orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md"
key_decisions:
  - "AD-1 FR-3a probe = authenticated-edit-token (reuse the existing Access: Apps and Policies — Edit repo-secret token for the health-check GET; no new operator scope), with unauthenticated-redirect-fallback (302 -> cloudflareaccess.com) as the sanctioned P04 fallback if Edit does not grant read — both inside AD-1's set so neither re-litigates the spec"
  - "FR-9 diagnostic = distinguishable: Zero-Trust-not-enabled (HTTP 4xx, access.api.error.* e.g. code 12130) vs token-missing-scope (HTTP 403, code 9109/10000) diverge on (HTTP status, errors[0].code); provisioner branches on that tuple, with a one-line collapse-to-combined-diagnostic contingency built into P02"
  - "AD-2 fallback-only footgun warning: fires on the (private repo + github-pages) tuple regardless of plan, carries an 'ignore if GitHub Enterprise Cloud' note, NO gh-api plan probe; advisory classification never flips doctor health"
  - "CON-6 two-site exposure guard preserved end-to-end: provisioning-time access-before-deploy ordering (P02) + every-CI-deploy pre-deploy health check (P01) are both load-bearing and neither was weakened"
  - "SC-9 'or' semantics encoded in the per-note evidence gate: a signed deferred-validation note is a first-class valid closing artifact (distinct from M033 where the override lived in validate-milestone.sh), so M043 closes at shippable scope (US-1..US-3) with the US-4 live pass honestly forward-pointed"
patterns_established:
  - "Mode-B doc-derived API spike cross-checked against a live downstream consumer (pbj-central's working wiki-deploy.yml) with every unconfirmable field labeled [unconfirmed-P04] and forward-pointed to a live pass — evidence discipline under Principle II when no live credentials exist at spike time"
  - "fixture-replay provisioner: cf_api <METHOD> <ENDPOINT_KEY> replays recorded-API JSON (envelope + _http_status), making the whole Cloudflare provisioner verifiable offline with no live account"
  - "markdown-only human-recruitment protocol + one-page recruitment kit + machine-checkable capture form + Bash-3.2 awk-frontmatter per-note SC-9 gate, mirroring the M033 friendly-tester-pass house convention; signed deferred-validation note as the SC-9 'or' closing artifact under house precedent (M032/M033/M036)"
  - "shared framework warning emitter with --mode doctor|status (doctor emits body + trailing DOCTOR: line for run_check; status emits body only); resolver script located via SCRIPT_DIR while the diagnosed-project config root is the argument"
drill_down_paths:
  - ".orchestrator/milestones/M043/phases/P00/P00-SUMMARY.md, .orchestrator/milestones/M043/phases/P01/P01-SUMMARY.md, .orchestrator/milestones/M043/phases/P02/P02-SUMMARY.md, .orchestrator/milestones/M043/phases/P03/P03-SUMMARY.md, .orchestrator/milestones/M043/phases/P04/P04-SUMMARY.md, .orchestrator/milestones/M043/archive/"
duration: "5 phases (P00-P04)"
verification_result: "pass"
completed_at: "2026-06-05T03:30:00Z"
observability_surfaces:
  - "tools/verify/m043-p00-phase-suite.sh (pass=2 fail=0), m043-p01-phase-suite.sh (pass=4 fail=0), m043-p02-phase-suite.sh (pass=5 fail=0), m043-p03-phase-suite.sh (pass=4 fail=0), m043-p04-phase-suite.sh (pass=3 fail=0); validate-milestone.sh M043 PASS 62/62"
---

M043 adds **Cloudflare Pages + Cloudflare Access as a first-class wiki-deploy
target**, fixing the private-Pages footgun that a live pbj-central incident
(2026-06-04) surfaced: a private GitHub-Pages wiki builds green but serves
ungated, and a post-provisioning Zero-Trust/Access lapse can silently reopen the
exposure window. Closed verify-pass at shippable scope (US-1..US-3) with the US-4
live pass forward-pointed under a signed deferred-validation note per FR-13 / SC-9.

## Milestone Rollup

Five phases, executed P00 → {P01, P02} → P03 → P04. The whole Cloudflare path was
built and verified **offline against recorded-API fixtures** (P00 ran Mode B —
doc-derived, no live credentials at spike time — cross-checked against
pbj-central's working `wiki-deploy.yml`); the single remaining live-only
confirmation (the real `302 → cloudflareaccess.com` gate, a green CI run, a
working giscus comment, and the two `[unconfirmed-P04]` API assumptions) is the
US-4 human-recruitment pass, forward-pointed under the signed note rather than run.

`validate-milestone.sh .orchestrator/milestones/M043` → **PASS 62/62**. All five
phase-suites green (P00 2/0, P01 4/0, P02 5/0, P03 4/0, P04 3/0). CON-6 (the
load-bearing two-site exposure guard) is intact: the provisioning-time
access-before-deploy ordering (P02) and the every-CI-deploy pre-deploy Access
health check (P01) both shipped and neither was weakened. CON-4 github-pages
byte-stability is preserved (the `deploy_target` branch leaves the github-pages
emit + `--deploy` path byte-identical to pre-M043).

## Phase Summaries

- **P00 — Cloudflare API characterization spike** (verify-pass; Tier 1 35/0).
  Mode-B doc-derived findings note pinning the FR-3a probe mechanism
  (`authenticated-edit-token`) and the FR-9 diagnostic shape (`distinguishable`),
  plus 5 fixture seeds. Cross-checked against pbj-central's real green CI run,
  which confirmed CON-1/CON-2 live and that its working workflow has **no**
  pre-deploy Access health check — the exact exposure window FR-3a closes. Three
  `[unconfirmed-P04]` items forward-pointed.
- **P01 — Target switch + Cloudflare deploy workflow (US-1)** (verify-pass; 4
  tasks). `wiki.deploy_target` enum + `resolve-deploy-target.sh` shared resolver;
  `wiki-cloudflare-deploy.yml.tmpl` (build steps identical to `pages.yml`, FR-3a
  fail-closed pre-deploy health check, `npx --yes wrangler@4` deploy per CON-2);
  `wiki-init.sh` branches at emit + `--deploy`; `wiki-deploy.sh` target-aware
  workflow-URL branch. CON-4 byte-stability proven by golden diff. Two issues
  caught + fixed (plan self-contradiction in the lint-forbidden comment; a latent
  `$REPO_ROOT` unbound-variable bug under `set -u`).
- **P02 — Idempotent Cloudflare provisioner (US-2)** (verify-pass; 5 gates).
  `cloudflare-access-setup.sh` provisions Pages project → Access app
  (apex+wildcard) → allow policy in order, no-ops on re-run (SC-4), and fails
  loudly with the FR-9 actionable diagnostic when Zero Trust is off (SC-5). Five
  P00 seeds promoted to the `tests/fixtures/m043-cloudflare/` recorded-API
  fixture tree under a `cf_api` fixture-replay contract.
- **P03 — Docs + fallback-only footgun warning (US-3)** (verify-pass; 4 gates).
  `check-wiki-pages-exposure.sh` framework-owned warning (AD-2: fires on
  private+github-pages regardless of plan, Enterprise-Cloud note, no plan probe)
  wired into both `doctor` and `status`; `installation.md` Wiki Deploy Targets
  section (token scopes, Zero Trust prereq, symmetric Cloudflare entitlement-lapse
  mode); SC-8 giscus byte-stability golden.
- **P04 — Live / friendly-tester validation (US-4)** (verify-pass; 3 gates).
  Markdown-only `protocol.md` + `RECRUITMENT-KIT.md`, the `evidence-template.md` +
  Bash-3.2 `validate-evidence.sh` SC-9 gate (triad-all-yes OR signed-deferred;
  fail-closed on a missing note), two fixtures, the signed
  `2026-06-04-deferred-validation.md` note, and four `m043-p04-*` verifiers +
  phase-suite. Closes the milestone at shippable scope with the live pass honestly
  forward-pointed.

## Key Decisions

See the `key_decisions` frontmatter: AD-1 (`authenticated-edit-token` probe with
redirect fallback), FR-9 (`distinguishable` diagnostic on `(status, code)`), AD-2
(fallback-only warning), CON-6 (two-site exposure guard preserved), and the SC-9
deferred-note-as-first-class-closing-artifact semantics. The two `#Q-5` /
`#Q-6` API assumptions remain doc-derived until the US-4 live pass confirms or
corrects them; both sit inside AD-1's / FR-9's sanctioned fallback sets, so
neither blocks shippable-scope closure.

## Patterns Established

See the `patterns_established` frontmatter: Mode-B-spike-cross-checked-against-a-
live-consumer, the `cf_api` fixture-replay provisioner, the markdown-protocol +
awk-frontmatter SC-9 gate + signed-deferred-note close convention, and the shared
`--mode doctor|status` warning emitter.

## Knowledge Captured

No new MEM entries were promoted at close (consolidation found no overlapping
entries and the milestone's patterns are recorded inline above). The
deferred-validation closing pattern reinforces existing house precedent
(M032 SC-5 / M033 / M036 P03). The live-pass protocol remains on disk at
`tests/m043-acceptance/live-deploy/` for whenever a Cloudflare-equipped tester
runs it; their filled evidence note will land beside the deferred note and
`validate-evidence.sh` will confirm the completed-pass path.
