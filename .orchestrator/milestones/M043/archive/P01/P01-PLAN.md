---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M043"
goal: "Make `wiki.deploy_target: cloudflare-access` switch wiki-init.sh to emit `wiki-cloudflare.yml` (with the FR-3a pre-deploy Access health check) instead of `pages.yml`, route `--deploy` to the Cloudflare provisioner, and make wiki-deploy.sh print the target-appropriate workflow URL — while the `github-pages` path stays byte-identical to pre-M043."
demo_sentence: "An operator runs `bash tools/verify/m043-p01-phase-suite.sh` and sees `SUMMARY: m043-p01-phase-suite.sh pass=N fail=0`; sets `wiki.deploy_target: cloudflare-access` and (conceptually) runs wiki-init → `.github/workflows/wiki-cloudflare.yml` is emitted from the template (deploy via `npx --yes wrangler@4`, with a `Verify Cloudflare Access gate` step BEFORE the deploy step), `pages.yml` is not; with `github-pages` (or the key absent) the emitted pages.yml heredoc is byte-identical to the pre-M043 golden and wiki-deploy.sh's github-pages output is unchanged; an unknown enum value makes `resolve-deploy-target.sh` exit 2 with a two-value error."
risk: "high"
depends_on: ["P00"]
---

## Boundary Map

**Produces** (consumed by P03 docs/warning + P04 live validation):

- `templates/orchestrator-config-default.yml` (modify) — FR-1: `wiki.deploy_target` enum (`github-pages | cloudflare-access`, default `github-pages`) + a commented `wiki.cloudflare:` sub-block (`project_name`, account-id-source note, `allowed_email_domains`) with the CON-7 list-reprovision caveat inline.
- `scripts/wiki/resolve-deploy-target.sh` (create) — framework-owned shared resolver: reads `<root>/.orchestrator/config.yml`, returns `github-pages` when the key/block/file is absent (FR-1 default), the value when it is a valid enum member, and **exits 2 with a two-value error when the value is present but unrecognized** (spec Edge Case "unknown value fails fast"). Bash 3.2. Consumed by wiki-init.sh + wiki-deploy.sh.
- `templates/wiki-cloudflare-deploy.yml.tmpl` (create) — FR-3 + FR-3a: build steps identical to `pages.yml` (checkout → setup-python → pip → stubs-fresh → materialize `wiki/.staged/` → `mkdocs build`), then the **FR-3a pre-deploy Access health-check step** (authenticated `GET /accounts/{id}/access/apps` reusing `CLOUDFLARE_API_TOKEN` per the P00 `authenticated-edit-token` Decision, asserting the Access app + allow policy for `__PROJECT_NAME__.pages.dev` exist), then deploy via `npx --yes wrangler@4 pages deploy`. The health-check step is positioned **before** the deploy step (SC-10).
- `scripts/lifecycle/wiki-init.sh` (modify) — FR-2: workflow-emit branches on `deploy_target` (`cloudflare-access` → new `emit_cloudflare_workflow` from the template with CON-3 no-clobber + `__PROJECT_NAME__` substitution; `github-pages` → existing `emit_pages_workflow` + `flip_pages_build_type` UNCHANGED). FR-4: `--deploy` branches on `deploy_target` (`cloudflare-access` → invoke `scripts/wiki/cloudflare-access-setup.sh` with a not-found guard naming it the P02 deliverable; `github-pages` → existing four-step sequence UNCHANGED).
- `scripts/wiki/wiki-deploy.sh` (modify) — FR-5: resolve `deploy_target`, print the `wiki-cloudflare.yml` workflow URL + a "gates identical across targets" line for `cloudflare-access`; keep the `github-pages` post-gate output byte-identical to pre-M043 (CON-4).
- Verifiers + golden (create): `tools/verify/m043-p01-config-and-resolver.sh`, `tools/verify/m043-p01-wrangler-lint.sh` (SC-2/SC-10), `tools/verify/m043-p01-wiki-init-branch.sh` (incl. CON-4 byte-stability via golden diff + SC-1), `tools/verify/m043-p01-wiki-deploy-url.sh`, `tools/verify/m043-p01-phase-suite.sh`; `tests/fixtures/m043-p01/pages-workflow.golden.yml` (captured from the pristine `emit_pages_workflow` heredoc).

**Consumes**:

- `.orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md` (P00) — the FR-3a probe Decision `authenticated-edit-token` (authenticated `GET /accounts/{account_id}/access/apps` reusing the Edit-scope token, no new scope) drives the health-check step shape; the token-scope implication (no extra Read scope) is what FR-11/P03 documents.
- Pre-existing (read for exact integration anchors): `scripts/lifecycle/wiki-init.sh` (`emit_pages_workflow` heredoc lines 538–620; emit call site lines 655–656; `--deploy` block start line 1105), `scripts/wiki/wiki-deploy.sh` (URL-print tail lines 242–279), `templates/orchestrator-config-default.yml` (`wiki:` block lines 209–229).

### CON-6 note (the soul of M043 — do not weaken)

FR-3a in `templates/wiki-cloudflare-deploy.yml.tmpl` is the **every-CI-deploy** enforcement site of the two-site exposure guard (CON-6). It is NOT redundant with P02's provisioning-time ordering — it catches a *post-provisioning* Zero-Trust lapse / Access-app deletion / policy removal and fails the deploy loudly instead of shipping an ungated wiki on a green run (the `pbj-central` exposure shape, confirmed by P00 against pbj-central's working-but-unguarded workflow). Removing the health-check step reopens the exposure window. A reviewer MUST NOT "simplify" it away believing provisioning-time enforcement suffices.

## Must-Haves

<!-- All Check commands use single-script-file shape (AD-19), under tools/verify/
     (project-owned, milestone-slug-prefixed). Each verifier is co-authored
     alongside its deliverable within the same task (plan-time discipline rule 2);
     the phase-suite is T04's deliverable and references every gate. -->

### Truths

- `templates/orchestrator-config-default.yml` declares `deploy_target: github-pages` (uncommented default) under `wiki:`, plus a commented `cloudflare:` sub-block naming `project_name` + `allowed_email_domains` with the CON-7 reprovision caveat.
  - Check: `bash tools/verify/m043-p01-config-and-resolver.sh`
- `scripts/wiki/resolve-deploy-target.sh` returns `github-pages` when `deploy_target` is absent, echoes the value when it is `github-pages` or `cloudflare-access`, and exits 2 (two-value error to stderr) when the value is present but unrecognized.
  - Check: `bash tools/verify/m043-p01-config-and-resolver.sh`
- `templates/wiki-cloudflare-deploy.yml.tmpl` deploys via `npx --yes wrangler@4`, contains no `cloudflare/wrangler-action` substring (SC-2), and places the FR-3a `Verify Cloudflare Access gate` health-check step on an earlier line than the `wrangler pages deploy` step (SC-10).
  - Check: `bash tools/verify/m043-p01-wrangler-lint.sh`
- `scripts/lifecycle/wiki-init.sh` branches workflow-emit on `deploy_target` (an `emit_cloudflare_workflow` path emitting `wiki-cloudflare.yml` with CON-3 no-clobber) AND the `emit_pages_workflow` heredoc body is byte-identical to `tests/fixtures/m043-p01/pages-workflow.golden.yml` (CON-4 / SC-1).
  - Check: `bash tools/verify/m043-p01-wiki-init-branch.sh`
- `scripts/lifecycle/wiki-init.sh` `--deploy` references `scripts/wiki/cloudflare-access-setup.sh` under the `cloudflare-access` branch with a not-found guard, and the github-pages four-step sequence (`has_discussions`, `wiki-deploy.sh`, Pages guard, `PUT .../pages`) is preserved.
  - Check: `bash tools/verify/m043-p01-wiki-init-branch.sh`
- `scripts/wiki/wiki-deploy.sh` prints `actions/workflows/wiki-cloudflare.yml` under the `cloudflare-access` branch, and the `github-pages` post-gate output lines (`OK: pre-deploy gates PASS.` + `actions/workflows/pages.yml`) are preserved byte-for-byte (CON-4).
  - Check: `bash tools/verify/m043-p01-wiki-deploy-url.sh`
- The phase-suite aggregator runs all four P01 gates in order, exits 0 iff all pass, and emits a single `SUMMARY: m043-p01-phase-suite.sh pass=N fail=M` line.
  - Check: `bash tools/verify/m043-p01-phase-suite.sh`

### Artifacts

- `templates/orchestrator-config-default.yml` (min 1 added block, contains "deploy_target: github-pages", contains "allowed_email_domains") — modify
- `scripts/wiki/resolve-deploy-target.sh` (min 25 lines, contains "deploy_target", contains "cloudflare-access", contains "github-pages") — create
- `templates/wiki-cloudflare-deploy.yml.tmpl` (min 50 lines, contains "npx --yes wrangler@4", contains "Verify Cloudflare Access gate", contains "__PROJECT_NAME__", contains "access/apps") — create
- `scripts/lifecycle/wiki-init.sh` (contains "emit_cloudflare_workflow", contains "resolve-deploy-target.sh", contains "cloudflare-access-setup.sh", contains "wiki-cloudflare.yml") — modify
- `scripts/wiki/wiki-deploy.sh` (contains "resolve-deploy-target.sh", contains "wiki-cloudflare.yml") — modify
- `tests/fixtures/m043-p01/pages-workflow.golden.yml` (min 50 lines, contains "actions/deploy-pages@v4", contains "Deploy wiki to Pages") — create
- `tools/verify/m043-p01-config-and-resolver.sh` (min 30 lines, contains "deploy_target", contains "cloudflare-access") — create
- `tools/verify/m043-p01-wrangler-lint.sh` (min 25 lines, contains "wrangler-action", contains "npx --yes wrangler@4", contains "Verify Cloudflare Access gate") — create
- `tools/verify/m043-p01-wiki-init-branch.sh` (min 30 lines, contains "emit_cloudflare_workflow", contains "pages-workflow.golden.yml", contains "cloudflare-access-setup.sh") — create
- `tools/verify/m043-p01-wiki-deploy-url.sh` (min 20 lines, contains "wiki-cloudflare.yml", contains "pages.yml") — create
- `tools/verify/m043-p01-phase-suite.sh` (min 20 lines, contains "SUMMARY:", contains "m043-p01-config-and-resolver", contains "m043-p01-wrangler-lint", contains "m043-p01-wiki-init-branch", contains "m043-p01-wiki-deploy-url") — create

### Key Links

- `scripts/lifecycle/wiki-init.sh` → `templates/wiki-cloudflare-deploy.yml.tmpl` (emit_cloudflare_workflow reads the template)
- `scripts/lifecycle/wiki-init.sh` → `scripts/wiki/resolve-deploy-target.sh` (resolves deploy_target)
- `scripts/lifecycle/wiki-init.sh` → `scripts/wiki/cloudflare-access-setup.sh` (FR-4 --deploy invocation; the P02 deliverable)
- `scripts/wiki/wiki-deploy.sh` → `scripts/wiki/resolve-deploy-target.sh` (resolves deploy_target)
- `tools/verify/m043-p01-wiki-init-branch.sh` → `tests/fixtures/m043-p01/pages-workflow.golden.yml` (byte-stability diff target)
- `tools/verify/m043-p01-phase-suite.sh` → `tools/verify/m043-p01-wrangler-lint.sh` (suite invokes the lint)

## Tasks

### T01: Config schema (FR-1) + shared deploy_target resolver

See `tasks/T01-config-and-resolver-PLAN.md`.

### T02: Cloudflare workflow template (FR-3/FR-3a) + wrangler/health-check lint

See `tasks/T02-cloudflare-template-and-lint-PLAN.md`.

### T03: wiki-init.sh emit + --deploy branching (FR-2/FR-4) + byte-stability golden

See `tasks/T03-wiki-init-branch-PLAN.md`.

### T04: wiki-deploy.sh target-aware URL (FR-5) + phase-suite aggregator

See `tasks/T04-wiki-deploy-url-and-suite-PLAN.md`.

## Task Dependencies

```
T01 ──▶ T02 ──▶ T03 ──▶ T04
```

Linear. T01 lands the config switch + the resolver both downstream scripts call. T02 lands the workflow template (which T03 emits from) + its standalone lint. T03 branches wiki-init.sh (emit reads T02's template; both branches resolve via T01's resolver) and captures the byte-stability golden. T04 branches wiki-deploy.sh and authors the phase-suite aggregator referencing all four gates (so it runs after the other three verifiers exist). T02 is technically independent of T01 (the template reads no config), but the linear order keeps dispatch simple and the golden/suite ordering correct.

## Files Likely Touched

- `templates/orchestrator-config-default.yml` (modify) — T01
- `scripts/wiki/resolve-deploy-target.sh` (create) — T01
- `templates/wiki-cloudflare-deploy.yml.tmpl` (create) — T02
- `scripts/lifecycle/wiki-init.sh` (modify) — T03
- `tests/fixtures/m043-p01/pages-workflow.golden.yml` (create) — T03
- `scripts/wiki/wiki-deploy.sh` (modify) — T04
- `tools/verify/m043-p01-config-and-resolver.sh` (create) — T01
- `tools/verify/m043-p01-wrangler-lint.sh` (create) — T02
- `tools/verify/m043-p01-wiki-init-branch.sh` (create) — T03
- `tools/verify/m043-p01-wiki-deploy-url.sh` (create) — T04
- `tools/verify/m043-p01-phase-suite.sh` (create) — T04

<!-- read-config.sh is deliberately NOT modified: its nested-key handlers hardcode
     the resolution root to the framework repo, which would read the wrong config
     for a consumer-project PROJECT_DIR. The dedicated resolve-deploy-target.sh
     helper takes an explicit project root and is correct in both cases. -->
