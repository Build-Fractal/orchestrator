# orchestrator — Conformance Declaration

**Product:** orchestrator (autonomous multi-phase orchestrator)
**Sister project:** [conversus-oss](https://github.com/Build-Fractal/conversus-oss) — multi-agent deliberation engine. Same build-fractal namespace, same Tier 1 inheritance, no hard runtime dependency in either direction. The orchestrator invokes conversus through a graceful-degradation adapter for spec-fidelity and artifact-review gates; conversus operates standalone.
**Governance shape:** single-product (no Tier 2 suite tier)
**Inherits from:**
- `https://github.com/clariti-care/payer-index-mono/blob/main/build-fractal/CONSTITUTION.md` (Tier 1 — Universal, v1.0.0 ratified 2026-05-07 with v4.0.0)

**Component constitution:** [`.orchestrator/memory/constitution.md`](./.orchestrator/memory/constitution.md) — currently v2.1.0 with 15 active principles. The Tier-1-framework-shaped component-tier declarations are not yet authored at the repo root; see "Component-tier declarations" below.

**Admission deliberation:** none — orchestrator joined the build-fractal namespace via the orchestrator-combine PR (clariti-care/payer-index-mono#6, 2026-05-10) under the single-product governance shape. Formal admission deliberation deferred until a sibling orchestrator joins and the suite shape becomes warranted (see `https://github.com/clariti-care/payer-index-mono/blob/main/build-fractal/conversus/COMPLIANCE.md` for the suite admission pathway).

**Status:** Implicit-Provisional — admitted via combine PR; 4 open audits before status flips to Compliant-Provisional or Compliant.

**Last re-audit:** 2026-05-10 (initial declaration).

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

## Component-tier declarations

**Not yet declared in the Tier 1 framework.** orchestrator inherits Tier 1 directly without a separate Tier-1-framework-shaped component constitution at the repo root. However, the orchestrator does carry 15 active component-tier principles in [`.orchestrator/memory/constitution.md`](./.orchestrator/memory/constitution.md) (v2.1.0). Three of those map to conversus's Tier 2 principles and are candidates for relocation if/when build-fractal adds a Tier 2 layer shared between this project and conversus:

| Orchestrator principle | Conversus Tier 2 analogue | Relocation candidate? |
|---|---|---|
| VI (State On Disk Is Truth) | None — orchestrator-specific identity | No — define-the-product |
| XII (Hook Isolation) | XV (Plugin Isolation) | Yes — same shape, different vocabulary |
| (pending XVI — Distribution Surface Integrity, see [proposal](./.orchestrator/proposals/constitution-amendment-inclusion-criteria.md)) | XXII (Distribution Surface Integrity) | Yes — inherit Tier 2 XXII directly rather than duplicate at component tier |
| (capability shipped — dead-infrastructure linter at `scripts/diagnostics/check-dead-infra.sh` + `tests/test-dead-infra-knobs.sh`, ported from conversus `linter/dead_infra.py` per the 2026-05-11 alignment sweep) | XII (No Dead Infrastructure) | Yes — but inheritance is **not yet declared**. The constitution-amendment proposal currently ratifies XXII (Distribution Surface Integrity), not XII. Inheriting XII is a separate follow-on amendment whose evidence (this linter + test) is already on disk. Surface during the three-deliberation ratification of the pending amendment. |

The other 12 principles (I Context Minimization, II Evidence Before Claims, III Design Before Code, IV Plans Assume Zero Context, V Fresh Context Per Unit, VII Knowledge Compounds, VIII Pattern-Driven Execution, IX Telemetry Through Events, X Configuration Over Code, XI Single Source of Truth, XIII Agent Instruction Schema, XIV No Speculative Complexity, XV Surgical Precision) are orchestrator-specific or already covered by Tier 1 inheritance (XI maps to Tier 1 XI; XIV maps to Tier 1 XXVIII via test-fix-boundary phrasing).

Promotion path: when a sibling orchestrator-shaped product joins build-fractal, decide whether to lift these component-tier principles into a shared Tier 2 constitution at that point. Until then, the Tier 1 inheritance + component-tier `.orchestrator/memory/constitution.md` is the canonical pair.

---

## Provisional remediation plan

| Principle | Gap | Remediation | Deadline | Tracking |
|---|---|---|---|---|
| II (Stable Interfaces) | No formal stable-interfaces enumeration | Add `STABLE-INTERFACES.md` enumerating commands + script entry-points + their stability tier | 2026-08-01 | TBD spec |
| VII (Reproducibility) | Tool-version pinning audit not formalized | Audit Bash scripts for unpinned tool invocations; document the runtime-dependency surface | 2026-08-01 | TBD spec |
| IX (Functional Programming) | Tree-wide audit not done | Confirm no class-based service patterns in `scripts/`, `tools/`, helper Python | 2026-08-01 | TBD spec |
| XIV (Spec-Implementation Parity) | No CI parity check | Decide spec-status convention; port the conversus `spec_parity.py` linter pattern to this repo | 2026-08-01 | TBD spec |
| XXVIII (Test-Fix Boundary Preservation) | No mechanical lint | Port the conversus-oss `lint-test-fixes.yml` advisory pattern; calibrate before blocking | 2026-09-01 | TBD spec |

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
