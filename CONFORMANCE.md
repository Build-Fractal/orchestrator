# orchestrator — Conformance Declaration

**Product:** orchestrator (autonomous multi-phase orchestrator)
**Sister project:** [conversus-oss](https://github.com/Build-Fractal/conversus-oss) — multi-agent deliberation engine. Same build-fractal namespace, same Tier 1 inheritance, no hard runtime dependency in either direction. The orchestrator invokes conversus through a graceful-degradation adapter for spec-fidelity and artifact-review gates; conversus operates standalone.
**Governance shape:** single-product (no Tier 2 suite tier)
**Inherits from:**
- `https://github.com/clariti-care/payer-index-mono/blob/main/build-fractal/CONSTITUTION.md` (Tier 1 — Universal, v1.0.0 ratified 2026-05-07 with v4.0.0)

**Component constitution:** [`.orchestrator/memory/constitution.md`](./.orchestrator/memory/constitution.md) — currently v2.2.0 with 15 active principles + two Tier 2 inheritance declarations (XXII Distribution Surface Integrity; conversus Tier 2 XII No Dead Infrastructure, ratified 2026-05-11). The Tier-1-framework-shaped component-tier declarations are not yet authored at the repo root; see "Component-tier declarations" below.

**Admission deliberation:** none — orchestrator joined the build-fractal namespace via the orchestrator-combine PR (clariti-care/payer-index-mono#6, 2026-05-10) under the single-product governance shape. Formal admission deliberation deferred until a sibling orchestrator joins and the suite shape becomes warranted (see `https://github.com/clariti-care/payer-index-mono/blob/main/build-fractal/conversus/COMPLIANCE.md` for the suite admission pathway).

**Status:** Implicit-Provisional — admitted via combine PR; 5 open audits before Tier 1 status flips to Compliant-Provisional or Compliant. **Tier 2 XXII + conversus Tier 2 XII inheritance ratified 2026-05-11** under Path 1 of the operator-routed decision packet (`.orchestrator/comments/review-queue/2026-05-11-XXII-XII-blind-substantive-findings.md`); the blind-deliberation criterion (i) check passed. The inheritance rows now carry status per the three-bucket structure (Satisfied / Provisional / Extended) — see "Component-tier declarations" below. Substantive blind findings (Candidate A distinctness against Principles XI / X; Candidate B Principle VIII PATCH prerequisite; PENDING/ACTIVE tier for the three `scripts/verify/*.sh` stubs) are **deferred to a follow-on amendment** per Path 1.

**Last re-audit:** 2026-05-11 (Tier 2 XXII + conversus Tier 2 XII inheritance ratified under Path 1 — constitution bumped to v2.2.0; CONFORMANCE.md inheritance-row caveats dropped per ratification path).

---

## Tier 1 declarations

| # | Principle | Status | Evidence / Rationale |
|---|---|---|---|
| I | Spec-Driven Development | Satisfied | `specs/` directory with 26+ numbered specs (001-orchestrator through 026-specify-three-pass-impl). Every behavioral change has a spec; spec-first is the explicit discipline this product is built around. |
| II | Stable Interfaces | Provisional | 13 commands + script entry-points form the stable surface. No formal stable-interfaces enumeration document yet. **Audit:** enumerate command + script API stability tier in a `STABLE-INTERFACES.md` (deadline: 2026-08-01). |
| III | Backward-Compatible Extension | Satisfied | `CHANGELOG.md` follows Keep-a-Changelog 1.1.0; semantic versioning declared; current version 0.9.0 with `[Unreleased]` accumulating ahead of next release. PR-shape entries with Added/Changed/Deprecated/Removed/Fixed sections. |
| IV | Documentation Is the Product | Satisfied | `README.md`, `AGENTS.md`, `CLAUDE.md`, `ANTIPATTERNS.md`, `KNOWLEDGE-INDEX.md`, `RUNTIME-ASSUMPTIONS.md`, `competitive-landscape.md`, plus 5 user guides + 15 reference docs (per README). Documentation is co-evolved with code. |
| VII | Reproducibility | Provisional | No package lockfile (Bash-first project; no pyproject.toml/package.json). Reproducibility hinges on the Python wiki-decorator's `requirements.txt` (committed) plus declarative templates. **Audit:** confirm `wiki/requirements.txt` is the only runtime-dependency surface, and that all Bash scripts pin tool versions where they invoke external binaries (deadline: 2026-08-01). |
| VIII | Templating Engines | Satisfied | `templates/` directory with 24+ templates (the literal product surface). Variable contracts declared in template heads; orchestrator dispatches against templates as the canonical source of truth. |
| IX | Functional Programming | Provisional | Bash-first project; functions are the primary unit (`scripts/wiki/wiki-milestone-titles.sh::strip_title`, etc.). Python helpers are function-first (no class-based services observed in `scripts/wiki/wiki-decorate-build.py`). **Audit:** confirm no class-based service patterns slipped in across the broader script tree (deadline: 2026-08-01). |
| XI | Single Source of Truth | Satisfied | Templates are canonical for command outputs; `KNOWLEDGE-INDEX.md` is the canonical knowledge map; `RUNTIME-ASSUMPTIONS.md` is the canonical runtime contract; specs are canonical for behavior. Cross-references over duplication is the explicit pattern. |
| XIV | Spec-Implementation Parity | Provisional | Specs in `specs/{ID}-{slug}/` directories; no `specs/done/` segregation observed (different convention from conversus). No CI parity check yet — same gap conversus closed via `linter/spec_parity.py` (clariti-care/payer-index-mono PR #4). **Audit:** decide on done/active partition convention OR adopt status-header check; add a CI parity linter analogous to conversus's (deadline: 2026-08-01). |
| XXVIII | Test-Fix Boundary Preservation | Provisional | Test infrastructure present (`tests/test-*.sh`). No XXVIII-style mechanical lint for test-fix discipline yet (the conversus-oss `lint-test-fixes.yml` workflow is the reference pattern). **Audit:** add an advisory lint for test-fix discipline; calibrate before promoting to blocking (deadline: 2026-09-01). |

---

## Tier 2 Inheritance Basis

This section authors the three-paragraph principle-specific independence argument required by the originating-deliberation arbiter (`.orchestrator/ratification/2026-05-11-XXII-XII/arbiter/resolution.md`, Dispute 3 ruling) for the Tier 2 XXII + XII inheritance declarations. Added 2026-05-11.

**Paragraph 1 — SOURCE B Purpose clause acknowledgment**. The build-fractal suite constitution (`github.com/clariti-care/payer-index-mono/blob/main/build-fractal/conversus/CONSTITUTION.md`, hereafter SOURCE B) declares three Purpose-clause structural prerequisites for Tier 2 governance: (a) **multi-agent deliberation substrate** — the project ships a runtime that dispatches deliberations across multiple agents under a shared mode/phase contract; (b) **plugin entry-point boundary shape** — the project exposes a plugin/skill registration surface with an explicit isolation boundary; (c) **free/paid partition** — the project ships under a free-tier-vs-paid-tier license boundary with feature-gating between editions. We acknowledge that none of these three is self-evidently present in orchestrator at the architectural layer SOURCE B describes: orchestrator does NOT ship a deliberation substrate (it consumes one via the conversus adapter), does NOT carry a plugin-entry-point boundary at the conversus-Tier-2-XV shape (its skill/command registration is runtime-adapter-shaped, not entry-point-shaped), and does NOT carry a free/paid partition (this is a single-edition product per the Status & Provenance section above).

**Paragraph 2 — Principle-specific scope argument**. Despite the absence of all three Purpose-clause prerequisites at the architectural-layer level, XXII (Distribution Surface Integrity) and XII (No Dead Infrastructure) govern domains orchestrator unambiguously occupies. XXII's three invariants — single-source versioning, force-include discipline, end-to-end install testing — govern the domain of **installable artifact distribution** and apply to any project that ships installable artifacts. Orchestrator ships installable artifacts via `packaging/install/install-claude-code.sh`, `packaging/install/install-codex.sh`, `packaging/install/install-cursor.sh`, plus the curl-pipe-bash entry point at `packaging/install/install.sh`, independently of its deliberation substrate, plugin entry-point structure, or revenue model. XII's normative body — config-knob, schema-variable, and documented-consumer dead-infrastructure detection — governs the domain of **configurable infrastructure registration** and applies to any project that registers configurable infrastructure via templates or config files. Orchestrator registers configurable infrastructure via `templates/orchestrator-config-default.yml` (41 leaves; `scripts/diagnostics/check-dead-infra.sh` baseline 0 dead), independently of the same three prerequisites. Both principles govern domains orchestrator unambiguously occupies; their normative scope is independent of SOURCE B's three Purpose-clause architectural prerequisites.

**Paragraph 3 — Disposition of the three prerequisites**. For each of SOURCE B's three Purpose prerequisites we state explicitly why it is **not load-bearing** for XXII and XII specifically:
- **(a) multi-agent deliberation substrate** — XXII's single-source-versioning, force-include, and install-test invariants have no dependency on deliberation architecture: an installer that lacks a stable version source is broken whether the project's runtime dispatches deliberations or not. XII's dead-infrastructure detection applies to config surfaces regardless of whether those surfaces feed into a deliberation system: a config knob declared in `templates/orchestrator-config-default.yml` and never read is dead infrastructure independently of whether the orchestrator dispatches deliberations downstream.
- **(b) plugin entry-point boundaries** — XXII governs distribution surface integrity at the **installer layer**, not at the plugin boundary layer; orchestrator's installer manifests are the load-bearing surface, and the absence of conversus-Tier-2-XV plugin-entry-point structure does not affect that. XII's config-knob detection scope is defined by **template coverage**, not by plugin entry structure; `templates/orchestrator-config-default.yml` is the canonical scope and is plugin-entry-point-agnostic.
- **(c) free/paid partition** — neither XXII nor XII contain provisions referencing revenue model, commercial tier, or access control that would make this prerequisite load-bearing. The principles' normative bodies are revenue-model-agnostic.

The Tier 2 XXII + XII inheritance declarations therefore stand on the principle-specific independence argument above, **not** on a path (a) feature-mapping-with-Relief-invocation (which would misapply Part VI Relief to a membership-eligibility question) or a path (b) role-assertion (which would substitute role for structure). The blind deliberation's criterion (i) check (`.orchestrator/ratification/2026-05-11-XXII-XII/blind-evidence/blind-gate-result.md`, criterion (i): "Does the declaration grant implicit relief outside the formal Relief pathway?") **passed 2026-05-11** with headline PASS / 0 surviving disputes. The Path 1 ratification decision packet (`.orchestrator/comments/review-queue/2026-05-11-XXII-XII-blind-substantive-findings.md`) accepted the headline verdicts and deferred the blind's substantive distinctness findings (Candidate A Invariants 1+2 potentially subsumed by Principles XI / X; Candidate B's Principle VIII PATCH prerequisite; PENDING/ACTIVE tier for the three `scripts/verify/*.sh` stubs) to a follow-on amendment.

**Tracking policy**. Tier 2 XXII and XII strengthenings take effect at orchestrator's next MAJOR version per SOURCE B Amendment Process (L1181 of the build-fractal suite constitution); on Tier 2 amendment publication, CONFORMANCE.md XXII and XII inheritance rows shift to **Provisional-pending-review** pending compliance verification, and a follow-on amendment authors the full tracking policy text (deferred at ratification per the originating-deliberation Dispute 2 ruling to avoid premature scope specification before the membership basis is settled).

**Source Provisional independence note**. Orchestrator's Tier 1 status remains **Implicit-Provisional** with 5 open audits (II, VII, IX, XIV, XXVIII — see the Tier 1 declarations table above). This Provisional status on Tier-1-tier principles does **not** block the Tier 2 XXII + XII inheritance declarations: the inherited principles operate in the build-fractal-namespace Tier-2 tier, not in the Tier-1 tier, and the principle-specific scope arguments in Paragraphs 2-3 above are independent of orchestrator's Tier-1 audit progress.

---

## Component-tier declarations

Orchestrator inherits Tier 1 directly without a separate Tier-1-framework-shaped component constitution at the repo root. The orchestrator carries 15 active component-tier principles in [`.orchestrator/memory/constitution.md`](./.orchestrator/memory/constitution.md) (currently v2.1.0; XXII + XII Tier 2 inheritance amendment in ratification). Three of those map to conversus's Tier 2 principles; two are formally declared as inherited via the 2026-05-11 amendment (XXII Distribution Surface Integrity; XII No Dead Infrastructure — see "Tier 2 Inheritance Basis" above):

| Orchestrator principle | Conversus Tier 2 analogue | Status | Notes |
|---|---|---|---|
| VI (State On Disk Is Truth) | None — orchestrator-specific identity | Component-tier only | No — define-the-product. Not a relocation candidate. |
| XII (Hook Isolation) | XV (Plugin Isolation) | Component-tier only | Relocation candidate — same shape, different vocabulary. Deferred; not in current amendment. |
| Inherited — Tier 2 XXII (Distribution Surface Integrity) | XXII (Distribution Surface Integrity) | **Provisional** (criterion (i) PASS 2026-05-11; stub-implementation deferred per Path 1) | Tier 2 inheritance ratified 2026-05-11 by the constitution v2.2.0 amendment ([`proposal`](./.orchestrator/proposals/constitution-amendment-inclusion-criteria.md); decision packet at `.orchestrator/comments/review-queue/2026-05-11-XXII-XII-blind-substantive-findings.md`). **Canonical version source**: `CHANGELOG.md` top-line `## [X.Y.Z]` heading (consumed by `packaging/install/install-{claude-code,cursor,codex}.sh` per `install-claude-code.sh:524`). **Evidence**: stub scripts at `scripts/verify/version-source-of-truth.sh`, `scripts/verify/manifest-coverage.sh`, `scripts/verify/installer-smoke.sh` (path-existence discharges Criterion 1 feasibility; full implementations are post-ratification work, deferred to follow-on amendment per Path 1 + blind finding #9 PENDING/ACTIVE tier). |
| Inherited — conversus Tier 2 XII (No Dead Infrastructure) | XII (No Dead Infrastructure) | **Per three-bucket structure below** (Satisfied / Provisional / Extended; criterion (i) PASS 2026-05-11) | Tier 2 inheritance ratified 2026-05-11 by the constitution v2.2.0 amendment ([`proposal`](./.orchestrator/proposals/constitution-amendment-inclusion-criteria.md); decision packet at `.orchestrator/comments/review-queue/2026-05-11-XXII-XII-blind-substantive-findings.md`). **VIII disposition**: path (b) — scope boundary declared (see `.orchestrator/memory/constitution.md` § VIII "Tier 2 alignment" paragraph, restored to the constitution at v2.2.0 ratification). VIII governs file-system-level infrastructure reachability (`run-doctor.sh` evidence); inherited conversus Tier 2 XII governs config-knob / schema-variable / documented-consumer surfaces (`check-dead-infra.sh` evidence). **Three-bucket structure**: see below. Blind finding #5 (Principle VIII PATCH prerequisite) deferred per Path 1; VIII text restored as-is. |

The other 12 principles (I Context Minimization, II Evidence Before Claims, III Design Before Code, IV Plans Assume Zero Context, V Fresh Context Per Unit, VII Knowledge Compounds, VIII Pattern-Driven Execution scope boundary, IX Telemetry Through Events, X Configuration Over Code, XI Single Source of Truth, XIII Agent Instruction Schema, XIV No Speculative Complexity, XV Surgical Precision) are orchestrator-specific or already covered by Tier 1 inheritance (XI maps to Tier 1 XI; XIV maps to Tier 1 XXVIII via test-fix-boundary phrasing).

### Tier 2 XII — Three-bucket structure (path b)

Per the originating-deliberation synthesis P1-6 (Phase 4 convergence, S-5 modified ∩ T-4 modified), the XII inheritance row is decomposed into three explicitly-labeled buckets so that future auditors can distinguish inherited-and-satisfied surfaces from inherited-but-not-yet-verified surfaces from orchestrator-specific extensions:

| Bucket | Scope | Status | Evidence |
|---|---|---|---|
| **Satisfied (Inherited scope)** | Config-knob class — SOURCE B XII's schema-variable-to-template normative clause as it applies to orchestrator's config surface | Satisfied | `scripts/diagnostics/check-dead-infra.sh` + `tests/test-dead-infra-knobs.sh` against `templates/orchestrator-config-default.yml` (41 leaves; baseline 0 dead, 2026-05-11 alignment-sweep port from conversus `linter/dead_infra.py`) |
| **Provisional (Inherited scope)** | SOURCE B XII normative clauses not yet covered by the current linter: Pydantic-field equivalent (orchestrator has no Pydantic — analog declaration pending); SKILL.md-equivalent config options (frontmatter-shaped, scope not yet drawn); documented-consumer future-proofing (cross-reference coverage not yet linted) | Provisional | Each clause's evidence is contingent on the clause-mapping scaffold below being populated in a follow-on commit. |
| **Extended (Orchestrator-specific)** | Helper-script callers and reference-scaffolding inbound-link coverage — orchestrator additions beyond SOURCE B XII's normative body, declared as extensions under XII's governing principle rather than constituting a new principle | Extended | Per VIII path-(b) scope boundary, file-system-level reachability of helper scripts and reference docs falls under orchestrator Principle VIII (`run-doctor.sh`), not under inherited Tier 2 XII. The Extended bucket records this scope decision so future auditors don't mis-attribute the coverage. |

### Tier 2 XII — Clause-mapping scaffold

Per the originating-deliberation arbiter Dispute 1 ruling, the XII normative body's four clauses are mapped to orchestrator analogs in a scaffold table below. **Every content cell is labeled PENDING** because the cell content depends on follow-on amendment work that populates each row in a single commit alongside its declaration. **This scaffold is NOT a Criterion 1 feasibility claim**; Criterion 1 feasibility for each clause will be demonstrated when content cells are populated.

| SOURCE B XII clause | Orchestrator analog | Verification path | Status |
|---|---|---|---|
| Schema variables → templates | PENDING — populate when the linter's template-coverage rule lands as a post-ratification follow-on | PENDING — derive from `scripts/diagnostics/check-dead-infra.sh` post-ratification extension | PENDING |
| Pydantic-field equivalent → orchestrator population | PENDING — orchestrator has no Pydantic; analog declaration deferred to follow-on amendment | PENDING — derive from analog declaration | PENDING |
| SKILL.md config options → execution logic | PENDING — scope not yet drawn (frontmatter-shaped vs body-shaped) | PENDING — derive from scope decision | PENDING |
| Documented-consumer future-proofing | PENDING — cross-reference coverage not yet linted | PENDING — derive from linter extension | PENDING |

Promotion path: when a sibling orchestrator-shaped product joins build-fractal, decide whether to lift the remaining component-tier principles into a shared Tier 2 constitution at that point. Until then, the Tier 1 inheritance + component-tier `.orchestrator/memory/constitution.md` + Tier 2 XXII + XII inheritance declarations above are the canonical triple.

---

## Provisional remediation plan

| Principle | Gap | Remediation | Deadline | Tracking |
|---|---|---|---|---|
| II (Stable Interfaces) | No formal stable-interfaces enumeration | Add `STABLE-INTERFACES.md` enumerating commands + script entry-points + their stability tier | 2026-08-01 | TBD spec |
| VII (Reproducibility) | Tool-version pinning audit not formalized | Audit Bash scripts for unpinned tool invocations; document the runtime-dependency surface | 2026-08-01 | TBD spec |
| IX (Functional Programming) | Tree-wide audit not done | Confirm no class-based service patterns in `scripts/`, `tools/`, helper Python | 2026-08-01 | TBD spec |
| XIV (Spec-Implementation Parity) | No CI parity check | Decide spec-status convention; port the conversus `spec_parity.py` linter pattern to this repo | 2026-08-01 | TBD spec |
| XXVIII (Test-Fix Boundary Preservation) | No mechanical lint | Port the conversus-oss `lint-test-fixes.yml` advisory pattern; calibrate before blocking | 2026-09-01 | TBD spec |
| Tier 2 XXII + XII (Distribution Surface Integrity + No Dead Infrastructure) | Full Tier 2 tracking policy text not yet authored; placeholder declared above (see "Tracking policy" under "Tier 2 Inheritance Basis"). Required post-ratification action per the originating-deliberation Dispute 2 ruling. Full policy to be authored after the Tier 2 membership basis is ratified (i.e., after the blind deliberation's criterion (i) check passes). | Author the full Tier 2 tracking policy text once the membership basis is ratified: name the scope (which inheritance rows the policy governs), define "next MAJOR" for orchestrator (couple to `CHANGELOG.md` `## [X.Y.Z]` headings), and specify the review-cadence triggers when SOURCE B publishes a Tier 2 amendment to XXII or XII. Source: SOURCE B Amendment Process, L1181. | Coupled to next MAJOR (no calendar deadline; event-driven) | `.orchestrator/proposals/constitution-amendment-inclusion-criteria.md` + `.orchestrator/ratification/2026-05-11-XXII-XII/` (follow-on amendment) |

---

## Relief claims

*None.* All Provisional entries are open audits with concrete remediation plans, not relief requests.

---

## Re-audit cadence

This declaration is re-audited:
- Annually (next: 2027-05-10).
- On any structural change to this repo (e.g., adding a Python package distribution would shift VII evidence from "Bash + requirements.txt" to "lockfile-pinned").
- On any Tier 1 amendment that changes the principles orchestrator inherits.
- On promotion to suite shape (if/when sibling orchestrators join under `build-fractal/orchestrator-suite/` or similar).

---

## Status & Provenance

This declaration was created 2026-05-10 alongside the orchestrator-combine PR (clariti-care/payer-index-mono#6) that physically moved orchestrator into `build-fractal/orchestrator/`. It uses the **single-product governance shape** documented in `https://github.com/clariti-care/payer-index-mono/blob/main/build-fractal/README.md` — Tier 1 inheritance only, no Tier 2 suite tier, no separate suite-level governance docs.

Promotion path to suite shape: when a sibling orchestrator product joins the build-fractal namespace (e.g., a vertical-specific orchestrator), promote the layout to `build-fractal/{suite-name}/orchestrator/` and add Tier 2 governance (CONSTITUTION.md, COMPLIANCE.md, GOVERNANCE.md) at the suite directory. The Tier 2 governance pattern is documented in `https://github.com/clariti-care/payer-index-mono/blob/main/build-fractal/conversus/COMPLIANCE.md`.

See `https://github.com/clariti-care/payer-index-mono/blob/main/build-fractal/README.md` for the build-fractal namespace overview and governance-shape documentation.
