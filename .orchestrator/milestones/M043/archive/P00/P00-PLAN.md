---
schema_version: "1.0"
type: phase-plan
phase: "P00"
milestone: "M043"
goal: "Characterize the two external-Cloudflare-API unknowns from real (or documented) API behavior and pin them into a findings note: the FR-3a health-check probe mechanism (#Q-5-sub) and the FR-9 one-vs-combined diagnostic shape (#Q-6), plus capture the apex+wildcard create-call payloads and the Zero-Trust-not-enabled / missing-scope error responses as seeds for P02's recorded-API fixtures."
demo_sentence: "An operator runs `bash tools/verify/m043-p00-phase-suite.sh` and sees `SUMMARY: m043-p00-phase-suite.sh pass=N fail=0` (exit 0); opens `.orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md` and reads an explicit FR-3a probe Decision (#Q-5-sub) drawn from {authenticated-edit-token | authenticated-new-read-scope | unauthenticated-redirect-fallback} and an explicit FR-9 Decision (#Q-6) of `distinguishable` or `indistinguishable`, each tagged `live-confirmed` or `doc-derived`; and finds the apex+wildcard Access-app create payload, the Zero-Trust-not-enabled response, and the missing-scope response captured under `fixture-seeds/` as the seed for P02's recorded-API fixtures."
risk: "high"
depends_on: []
---

## Boundary Map

**Produces** (consumed by P01 and P02):

- `.orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md` — the spike's single canonical deliverable. Resolves **#Q-5-sub** (does the Cloudflare Access "Apps and Policies — Edit" scope grant read access sufficient for an existence check) into a committed **FR-3a probe Decision**, and **#Q-6** (HTTP status / error-code / body-field for "Zero Trust not enabled" vs. "token missing scope") into a committed **FR-9 one-vs-combined diagnostic Decision**. Every finding carries an explicit evidence-provenance tag (`live-confirmed` if obtained from a real API call, `doc-derived` if obtained from Cloudflare API documentation pending live confirmation). Read by: **P01** (FR-3a probe shape → the pre-deploy health-check step in `templates/wiki-cloudflare-deploy.yml.tmpl`; the token-scope table for FR-11 cross-ref), **P02** (FR-9 error-envelope → `cloudflare-access-setup.sh` diagnostics).
- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/` — captured request/response payloads that seed P02's recorded-API fixtures (`tests/fixtures/m043-cloudflare/`, produced by P02, NOT by P00 — P00 owns only the raw seeds under the P00 dir). Files: `pages-project-create-request.json`, `access-app-create-request.json` (apex `<name>.pages.dev` **and** wildcard `*.<name>.pages.dev` in `self_hosted_domains`), `access-policy-create-request.json`, `zero-trust-not-enabled-response.json`, `missing-scope-response.json`, and `README.md` (per-seed provenance + the P02 → `tests/fixtures/m043-cloudflare/` promotion note). Read by: **P02** (SC-3 create-order + apex/wildcard assertion; SC-5 Zero-Trust / missing-scope diagnostics).
- `tools/verify/m043-p00-findings-shape.sh`, `tools/verify/m043-p00-fixture-seeds-present.sh`, `tools/verify/m043-p00-phase-suite.sh` — project-owned structural verifiers (milestone-slug-prefixed per the naming convention) that mechanically assert the findings note resolves both questions and the seed payloads are present + provenance-tagged. The findings *content* is Tier 3 (research judgment, possibly doc-derived); the verifiers assert only its *shape*, which is all a Tier 1 check can prove for a spike.

**Consumes**: none. P00 is dependency-free and the head of the M043 critical path (high-risk-first per the roadmap Execution Order). Its only external input is the Cloudflare API itself (see the credentials prerequisite below) plus the spec's `#Q-5`/`#Q-6` open questions and the AD-1 fallback chain in `M043-CONTEXT.md`.

### ⚠️ Execution prerequisite — Cloudflare credentials (gate before dispatch)

**P00 is a real spike against external reality, not a code-only task** (per `M043-HANDOFF.md` gotcha #1). Two execution modes are sanctioned; the executor MUST pick one and record which in the findings note's `## Evidence Provenance` section:

- **Mode A — live (preferred, authoritative).** The operator has supplied a Cloudflare account id + a scoped API token (`Access: Apps and Policies — Edit`, `Pages — Edit`, `Account Settings — Read`) and, ideally, access to an account *without* Zero Trust enabled (to capture the real FR-9 error envelope). The executor makes real API calls, captures real response bodies, and tags every finding `live-confirmed`.
- **Mode B — doc-derived fallback (sanctioned, provisional).** No live credentials are available at dispatch time. The executor characterizes the API from Cloudflare's published API schema + Access / token-scope docs (via WebFetch), commits the Decisions on the documented evidence, tags every finding `doc-derived`, constructs the fixture seeds from the documented request/response schemas (labeled synthetic-from-docs in the seed README), and **forward-points live confirmation to P04** (the friendly-tester live-deploy pass — house precedent: M033/M041 deferred-validation, SC-9). This is never wrong in the dangerous direction: P01/P02 build on the documented Decision, and P04 confirms the live envelope before the milestone's live-validation pass closes.

Confirm which mode applies (i.e. whether the operator has provisioned credentials) **before** dispatching P00 execution. Either mode produces a closeable phase; the difference is the provenance tag and whether a P04 forward-pointer is attached.

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19. Verifiers
     live under tools/verify/ (project-owned, milestone-slug-prefixed).
     The three verifiers are T02 deliverables; T01 self-verifies with
     inline existence/grep shape-checks (plan-time discipline rule 2). -->

### Truths

- The findings note resolves **#Q-5-sub** with an explicit FR-3a probe Decision drawn from the closed set `{authenticated-edit-token, authenticated-new-read-scope, unauthenticated-redirect-fallback}`, tagged with an evidence-provenance marker (`live-confirmed` or `doc-derived`).
  - Check: `bash tools/verify/m043-p00-findings-shape.sh`
- The findings note resolves **#Q-6** with an explicit FR-9 diagnostic Decision — `distinguishable` (two diagnostics) or `indistinguishable` (one combined diagnostic + an SC-5-revision note) — tagged with an evidence-provenance marker.
  - Check: `bash tools/verify/m043-p00-findings-shape.sh`
- The findings note records, per finding, whether it is `live-confirmed` or `doc-derived`, and any `doc-derived` finding carries a `P04` live-confirmation forward-pointer (Principle II — no claim asserted beyond its evidence).
  - Check: `bash tools/verify/m043-p00-findings-shape.sh`
- The apex+wildcard Access-app create payload, the Zero-Trust-not-enabled response, and the missing-scope response are captured as fixture seeds; the Access-app create payload's `self_hosted_domains` contains both an apex form and a `*.`-prefixed wildcard form.
  - Check: `bash tools/verify/m043-p00-fixture-seeds-present.sh`
- The phase-suite aggregator runs both gates in order, exits 0 iff both pass, and emits a single `SUMMARY: m043-p00-phase-suite.sh pass=N fail=M` line.
  - Check: `bash tools/verify/m043-p00-phase-suite.sh`

### Artifacts

- `.orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md` (min 70 lines, contains "#Q-5-sub", contains "FR-3a Probe Decision", contains "Decision:", contains "#Q-6", contains "FR-9 Diagnostic Decision", contains "Fixture-Seed Inventory", contains "Evidence Provenance") — create
- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/pages-project-create-request.json` (min 3 lines) — create
- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/access-app-create-request.json` (min 3 lines, contains "self_hosted_domains", contains ".pages.dev", contains "*.") — create
- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/access-policy-create-request.json` (min 3 lines) — create
- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/zero-trust-not-enabled-response.json` (min 3 lines) — create
- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/missing-scope-response.json` (min 3 lines) — create
- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/README.md` (min 15 lines, contains "provenance", contains "tests/fixtures/m043-cloudflare") — create
- `tools/verify/m043-p00-findings-shape.sh` (min 25 lines, contains "#Q-5-sub", contains "FR-3a Probe Decision", contains "#Q-6", contains "FR-9 Diagnostic Decision", contains "Evidence Provenance") — create
- `tools/verify/m043-p00-fixture-seeds-present.sh` (min 25 lines, contains "access-app-create-request.json", contains "zero-trust-not-enabled-response.json", contains "missing-scope-response.json", contains "self_hosted_domains") — create
- `tools/verify/m043-p00-phase-suite.sh` (min 25 lines, contains "SUMMARY:", contains "m043-p00-findings-shape", contains "m043-p00-fixture-seeds-present") — create

### Key Links

- `.orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md` → `specs/043-wiki-cloudflare-access-deploy-target/spec.md` (resolves the spec's `#Q-5`/`#Q-6` open questions)
- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/README.md` → `cloudflare-api-findings.md` (seeds are evidence backing the findings)
- `tools/verify/m043-p00-phase-suite.sh` → `tools/verify/m043-p00-findings-shape.sh` (suite invokes the findings-shape gate)
- `tools/verify/m043-p00-phase-suite.sh` → `tools/verify/m043-p00-fixture-seeds-present.sh` (suite invokes the seeds-present gate)

## Tasks

### T01: Conduct the Cloudflare API characterization spike + author the findings note + capture fixture seeds

See `tasks/T01-cloudflare-api-spike-PLAN.md`.

### T02: Author the P00 structural verifiers + phase-suite aggregator

See `tasks/T02-findings-verifiers-PLAN.md`.

## Task Dependencies

```
T01 ──▶ T02
```

Linear chain. T01 conducts the spike and lands the research deliverable (the findings note + the fixture seeds); it self-verifies with inline `test -f` / `grep -q` shape-checks so it has no dependency on an unwritten verifier (plan-time discipline rule 2). T02 then authors the three structural verifiers and the phase-suite aggregator, which read T01's artifacts — so T02's verification cannot pass until T01's note + seeds exist. The phase-suite aggregator and the two gates it calls are all co-authored within T02, so T02's own `## Verification` resolves on disk when it runs.

## Files Likely Touched

- `.orchestrator/milestones/M043/phases/P00/cloudflare-api-findings.md` (create) — T01
- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/pages-project-create-request.json` (create) — T01
- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/access-app-create-request.json` (create) — T01
- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/access-policy-create-request.json` (create) — T01
- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/zero-trust-not-enabled-response.json` (create) — T01
- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/missing-scope-response.json` (create) — T01
- `.orchestrator/milestones/M043/phases/P00/fixture-seeds/README.md` (create) — T01
- `tools/verify/m043-p00-findings-shape.sh` (create) — T02
- `tools/verify/m043-p00-fixture-seeds-present.sh` (create) — T02
- `tools/verify/m043-p00-phase-suite.sh` (create) — T02

<!-- The phase plan + task plan files themselves are written by the planner,
     not the executor; they are not listed above. -->
