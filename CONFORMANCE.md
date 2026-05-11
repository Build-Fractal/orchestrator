# spec-kit-orchestrator — Conformance Declaration

**Product:** spec-kit-orc (autonomous multi-phase orchestrator)
**Governance shape:** single-product (no Tier 2 suite tier)
**Inherits from:**
- `https://github.com/clariti-care/payer-index-mono/blob/main/build-fractal/CONSTITUTION.md` (Tier 1 — Universal, v1.0.0 ratified 2026-05-07 with v4.0.0)

**Component constitution:** none yet (component-tier principles not yet declared for spec-kit-orc).

**Admission deliberation:** none — spec-kit-orc joined the build-fractal namespace via the orchestrator-combine PR (clariti-care/payer-index-mono#6, 2026-05-10) under the single-product governance shape. Formal admission deliberation deferred until a sibling orchestrator joins and the suite shape becomes warranted (see `https://github.com/clariti-care/payer-index-mono/blob/main/build-fractal/conversus/COMPLIANCE.md` for the suite admission pathway).

**Status:** Implicit-Provisional — admitted via combine PR; 4 open audits before status flips to Compliant-Provisional or Compliant.

**Last re-audit:** 2026-05-10 (initial declaration).

---

## Tier 1 declarations

| # | Principle | Status | Evidence / Rationale |
|---|---|---|---|
| I | Spec-Driven Development | Satisfied | `specs/` directory with 26+ numbered specs (001-orchestrator through 026-specify-three-pass-impl). Every behavioral change has a spec; spec-first is the explicit discipline (the product literally is named "spec-kit-orchestrator"). |
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

*None yet.* spec-kit-orc inherits Tier 1 directly without adding component-tier principles. If component-tier discipline is needed (e.g., orchestrator-specific rules around phase autonomy, resume safety, or knowledge compounding), a component `CONSTITUTION.md` may be added at this repo's root via the standard pathway taxonomy.

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
- On any Tier 1 amendment that changes the principles spec-kit-orc inherits.
- On promotion to suite shape (if/when sibling orchestrators join under `build-fractal/spec-kit-orc-suite/` or similar).

---

## Status & Provenance

This declaration was created 2026-05-10 alongside the orchestrator-combine PR (clariti-care/payer-index-mono#6) that physically moved spec-kit-orc into `build-fractal/spec-kit-orc/`. It uses the **single-product governance shape** documented in `https://github.com/clariti-care/payer-index-mono/blob/main/build-fractal/README.md` — Tier 1 inheritance only, no Tier 2 suite tier, no separate suite-level governance docs.

Promotion path to suite shape: when a sibling orchestrator product joins the build-fractal namespace (e.g., a vertical-specific orchestrator), promote the layout to `build-fractal/{suite-name}/spec-kit-orc/` and add Tier 2 governance (CONSTITUTION.md, COMPLIANCE.md, GOVERNANCE.md) at the suite directory. The Tier 2 governance pattern is documented in `https://github.com/clariti-care/payer-index-mono/blob/main/build-fractal/conversus/COMPLIANCE.md`.

See `https://github.com/clariti-care/payer-index-mono/blob/main/build-fractal/README.md` for the build-fractal namespace overview and governance-shape documentation.
