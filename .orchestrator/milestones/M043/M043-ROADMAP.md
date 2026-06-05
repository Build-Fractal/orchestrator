---
schema_version: "1.0"
type: roadmap
milestone: "M043"
feature_ref: "043-wiki-cloudflare-access-deploy-target"
feature_spec: "specs/043-wiki-cloudflare-access-deploy-target/spec.md"
vision: "Make a private orchestrator wiki safe by default — add Cloudflare Pages + Access as a plan-independent deploy target with a steady-state exposure guard, and warn loudly on the GitHub-Pages private-Pages footgun."
tier: "C"
created_at: "2026-06-04"
updated_at: "2026-06-04"
---

## Phases

- [x] **P00**: Cloudflare API characterization spike — "A findings note pins the FR-3a health-check probe mechanism and the FR-9 diagnostic shape from real Cloudflare API behavior."
  - Risk: high
  - Depends: none
  - Boundary Map:
    - Produces: `.orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md` (resolves #Q-5-sub: does the Access "Apps and Policies — Edit" scope grant read access sufficient for an existence check → FR-3a probe = authenticated-with-existing-token vs. unauthenticated-redirect-fallback; resolves #Q-6: HTTP status / error-code / body-field for Zero-Trust-not-enabled vs. token-missing-scope → FR-9 one-vs-combined diagnostic; captures the apex+wildcard create-call payloads + Zero-Trust-not-enabled + missing-scope responses as the seed for P02's recorded-API fixtures)
    - Consumes: none

- [x] **P01**: Target switch + Cloudflare deploy workflow (US-1) — "Setting `wiki.deploy_target: cloudflare-access` makes `wiki-init.sh` emit `wiki-cloudflare.yml` (with a pre-deploy Access health check) instead of `pages.yml`; the `github-pages` path stays byte-identical."
  - Risk: high
  - Depends: P00
  - Boundary Map:
    - Produces: `templates/orchestrator-config-default.yml` (`wiki.deploy_target` enum default `github-pages` + commented `wiki.cloudflare:` sub-block — FR-1); `templates/wiki-cloudflare-deploy.yml.tmpl` (build steps identical to `pages.yml`, FR-3a pre-deploy Access health-check step using the existing Edit-scope token per AD-1, deploy via `npx --yes wrangler@4` — FR-3/FR-3a); `scripts/lifecycle/wiki-init.sh` (`deploy_target` branch in `emit_pages_workflow` + `--deploy` — FR-2/FR-4, CON-3 no-clobber, CON-4 github-pages byte-stable); `scripts/wiki/wiki-deploy.sh` (target-aware workflow-URL print — FR-5); a template lint asserting `npx --yes wrangler@4` / no `cloudflare/wrangler-action` / health-check-precedes-deploy ordering (SC-2/SC-10)
    - Consumes: `cloudflare-api-findings.md` (FR-3a probe mechanism) from P00

- [x] **P02**: Idempotent Cloudflare provisioner (US-2) — "`cloudflare-access-setup.sh` provisions Pages project → Access app (apex+wildcard) → allow policy in that order, is a no-op on re-run, and fails loudly with an actionable diagnostic when Zero Trust is off."
  - Risk: high
  - Depends: P00
  - Boundary Map:
    - Produces: `scripts/wiki/cloudflare-access-setup.sh` (idempotent provisioner, access-before-deploy ordering per CON-6/FR-8, Zero-Trust + scope diagnostics per FR-9, Bash 3.2 — FR-6/FR-7/FR-8/FR-9); recorded-API fixtures under `tests/fixtures/m043-cloudflare/` (clean-account create-order, all-present idempotency, zero-trust-not-enabled, missing-scope — SC-3/SC-4/SC-5)
    - Consumes: `cloudflare-api-findings.md` (FR-9 error-envelope + seed fixture payloads) from P00

- [x] **P03**: Docs + fallback-only footgun warning (US-3) — "`orchestrator:status`/`doctor` warn on every private-repo + `github-pages` config (with an 'ignore if Enterprise' note), and `installation.md` documents both the GitHub-Pages and the symmetric Cloudflare entitlement-lapse failure modes."
  - Risk: medium
  - Depends: P01, P02
  - Boundary Map:
    - Produces: `references/installation.md` (Enterprise-only-private-Pages pitfall + build-green/deploy-422 mode + symmetric Cloudflare-lapse docs + token scopes + Zero-Trust prereq + custom-domain note — FR-11); fallback-only warning in `scripts/diagnostics/run-doctor.sh` + the `orchestrator:status` surface (fire on private + `github-pages`, "ignore if Enterprise Cloud" note, no plan-detection — FR-10/AD-2); FR-10 single-branch fixture matrix (SC-6); giscus unchanged assertion on the Cloudflare build (`overrides/partials/comments.html` byte-stable — FR-12/SC-8)
    - Consumes: `wiki.deploy_target` config key (P01); `cloudflare-access-setup.sh` surface for docs (P02)

- [x] **P04**: Live / friendly-tester validation (US-4) — "A recruited tester provisions a real Cloudflare account end-to-end and records the `302 → cloudflareaccess.com` redirect on the live URL, a green CI run, and a working giscus comment." _(closed at shippable scope 2026-06-05 under the signed deferred-validation note `tests/m043-acceptance/live-deploy/evidence/2026-06-04-deferred-validation.md`; live pass forward-pointed to `tests/m043-acceptance/live-deploy/protocol.md` per FR-13 / SC-9)_
  - Risk: low
  - Depends: P01, P02, P03
  - Boundary Map:
    - Produces: `tests/m043-acceptance/live-deploy/protocol.md` (human-recruitment protocol mirroring the M033/M041 friendly-tester convention) + a signed deferred-validation evidence note (FR-13/SC-9)
    - Consumes: the full deploy path (P01), the provisioner (P02), and the docs (P03)

## Cross-Cutting Concerns

- **CON-6 two-site exposure guard** — P00, P01, P02. P00 establishes the probe mechanism that the steady-state guard relies on; P02 enforces the access-before-deploy ordering at provisioning time; P01 enforces the pre-deploy health check on every CI deploy. Both enforcement sites must ship and neither may be removed without reopening the exposure window.
- **CON-2 wrangler-not-action** — P01 establishes the `npx --yes wrangler@4` form + the template lint that forbids `cloudflare/wrangler-action`; no other phase introduces a deploy invocation.
- **CON-4 github-pages byte-stability** — P01. The `deploy_target` branch must leave the `github-pages` emit + `--deploy` path byte-identical to pre-M043; downstream phases must not regress it.
- **AD-2 fallback-only warning policy** — P03 (sole site). No plan-detection logic anywhere; the warning fires on the (private + github-pages) tuple regardless of plan.
- **Bash 3.2 / POSIX-sh** — P01, P02. All new shell (config branching, provisioner) must avoid `declare -A` / process substitution.
- **CON-7 domain-list reprovision** — P02 (provisioner owns `--update-policy`-style reapplication), P03 (docs state the caveat) — until the M037 yaml-merge list-element gap closes, `allowed_email_domains` edits reprovision rather than rely on config merge.

## Dependency Graph

```
        ┌──→ P01 ──┐
P00 ────┤          ├──→ P03 ──→ P04
        └──→ P02 ──┘
```

P01 and P02 both depend only on P00 and are mutually independent (different files: P01 owns config/template/wiki-init/wiki-deploy; P02 owns the provisioner + fixtures) → they can execute concurrently. P03 depends on both (docs + warning reference the config key from P01 and the provisioner from P02). P04 depends on all build phases.

## Execution Order

1. **P00** — foundation spike, no dependencies; resolves both Cloudflare-API unknowns and seeds P02's fixtures. High-risk-first (FR-043): the external-API unknowns are the milestone's biggest risk, so they run before any build.
2. **P01, P02** — can execute concurrently (both depend only on P00; disjoint file sets). Both high-risk; P01 carries the security-load-bearing FR-3a health check, P02 the access-before-deploy invariant. Together they are the minimal slice (US-1 + US-2).
3. **P03** — depends on P01 + P02 (docs + warning consume the config key and provisioner surface). Medium risk.
4. **P04** — depends on P01 + P02 + P03 (live validation needs the whole feature deployed + the docs to follow). Low risk; human-recruitment task, milestone may close at shippable scope (P00–P03) with P04 forward-pointed under a signed deferred-validation note.

## Validation

- **No conflicting producers**: PASS — each produced artifact has exactly one owning phase (config + template + wiki-init + wiki-deploy + lint = P01; provisioner + fixtures = P02; installation.md + warning + warning-fixtures = P03; protocol + evidence = P04; findings note = P00). No file is produced by two phases.
- **All consumed items have producers**: PASS — P01 consumes P00's findings note; P02 consumes P00's findings note; P03 consumes P01's `wiki.deploy_target` config key + P02's provisioner; P04 consumes P01/P02/P03 outputs. Every Consumes entry maps to an upstream Produces entry.
- **DAG is acyclic**: PASS — P00 → {P01, P02} → P03 → P04. No back-edges; topologically orderable.
- **Demo sentence coverage**: PASS — each phase has a concrete, observable demo sentence (emitted workflow file presence/shape, provisioner create-order + idempotency, warning fire/silence + docs anchors, live 302 redirect).
