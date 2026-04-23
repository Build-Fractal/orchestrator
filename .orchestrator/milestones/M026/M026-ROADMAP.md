---
schema_version: "1.0"
type: roadmap
milestone: "M026"
feature_ref: "027-conversus-oss-migration"
feature_spec: "specs/027-conversus-oss-migration/spec.md"
vision: "Flip the orchestrator's default Conversus binary to the OSS build while preserving a first-class paid escape hatch and byte-identical adapter invariants, with a pre-flight synthesis-crux spike that prevents the resolver flip from landing against an unverified output contract."
tier: "C"
created_at: "2026-04-23"
updated_at: "2026-04-23"
---

## Phases

- [ ] **P01**: Parity audit + synthesis-crux spike-gate — "Operator reads `M026-CONVERSUS-PARITY.md` with the `Verified:` column fully populated from fs-inspection of both conversus trees, and the DC-6 synthesis-crux spike produces a committed go/no-go note on whether OSS's `synthesis` phase yields content parseable into the four `linter.output_contract` fields (`verdict`, `disputes`, `rationale`, `source_hash`)."
  - Risk: high — the DC-6 spike can block the milestone if OSS lacks a `linter.output_contract` analogue; resolving OQ-2 (parity-gap count) also happens here and feeds scope decisions for P02/P03.
  - Depends: none
  - Boundary Map:
    - Produces: `.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md` with `Verified:` column populated (FR-9 / SC-9); synthesis-crux spike note (pass → proceed to P02; block → surface to operator and halt); pipx venv path reconciliation findings consumed by P02's FR-8 test design (OQ-5 resolution); OSS-YAML-single-document-contract confirmation or mitigation path per spec 027 OQ-9; preset-field-drift inventory per spec 027 OQ-10/OQ-11/OQ-12 (folds the four smoke-test-confirmed drift rows into the parity matrix rather than re-running the smoke invocations); ollama-availability probe result on the operator machine (plan-phase validates OQ-3 resolution of the discuss-draft; falls back to skip-on-429 with `known-upstream-429` annotation only if ollama absent).
    - Consumes: `.orchestrator/scratch/conversus-oss-migration-parity.md` (seed parity matrix authored at spec 027 scaffolding, `VERIFY:` markers on every row); `specs/027-conversus-oss-migration/conversus/oss-early-review.md` (OSS 0.3.0 dogfood smoke-test commentary, gitignored local-only audit trail); `~/Sites/conversus-oss` and `~/Sites/conversus` trees as read-only reference.

- [ ] **P02**: Minimal Slice — resolver flip, edition env var, paid escape hatch, JSONL edition field, dual-edition regression test — "A fresh install with both conversus binaries present resolves the OSS build by default; `CONVERSUS_EDITION=paid` escapes to the paid build; `check` stdout reports `edition=oss|paid`; every `conversus_gate_invocation` JSONL record carries `edition`; and `CONVERSUS_INTEGRATION=1 bash tests/test-conversus-adapter-shim.sh` passes on both editions (OSS branch running ollama per the discuss-draft OQ-3 resolution)."
  - Risk: medium — the code surface is narrow (~30 lines of bash + ~40 lines of test extension), but it lands against five cross-milestone invariants (CON-1..CON-5) with zero tolerance for drift.
  - Depends: P01 (spike-gate must pass before the resolver flip lands; P02 does not begin until DC-6's go/no-go returns "go").
  - Boundary Map:
    - Produces: patched `scripts/dispatch/adapters/tool/conversus.sh` with new user-local-probe order (OSS first under `CONVERSUS_EDITION=oss|unset`, paid first under `CONVERSUS_EDITION=paid`) per AD-2 (FR-1, FR-2); `CONVERSUS_EDITION` env-var handling and cross-edition fallback diagnostic (FR-2, FR-3); `edition=oss|paid` line in `check` stdout (FR-3); `edition` field additively added to every `conversus_gate_invocation` JSONL record emitted by `scripts/integrations/github-common.sh::emit_conversus_gate_record` and inline at `scripts/specify/specify.sh:532` (FR-4, AD-4); extended `tests/test-conversus-adapter-shim.sh` with `CONVERSUS_INTEGRATION=1` dual-edition block running ollama on the OSS branch and the paid binary on the paid branch (FR-8, SC-4, SC-6); edition-aware pipx venv-python lookup extension to the existing fallback chain at `tests/test-conversus-adapter-shim.sh:119-124` (OQ-5 resolution).
    - Consumes: P01's parity matrix (`Verified:` column populated) + synthesis-crux spike pass verdict + ollama-availability probe result.

- [ ] **P03**: Layer-on — paid-only detection via preset frontmatter, OSS-binary diagnostic, six-surface doc updates, knowledge graduation — "An operator authoring a preset with `edition_required: paid` frontmatter and running it on an OSS install sees an actionable refusal diagnostic that names `CONVERSUS_EDITION=paid` as the escape; six doc surfaces describe the new resolver order and escape-hatch shape at the reading paths operators already use; consolidate graduates two `knowledge/decisions/MEM*.md` entries; `CHANGELOG.md` records the migration; and CLAUDE.md + AGENTS.md Recent Changes are dual-written for each phase-close."
  - Risk: low — purely additive, no invariant changes; posture is revise-in-place per AD-7.
  - Depends: P02
  - Boundary Map:
    - Produces: `edition_required:` preset-frontmatter field handling in `scripts/dispatch/adapters/tool/conversus.sh` (FR-10, AD-3, AD-5); paid-only-preset-on-OSS diagnostic with actionable `CONVERSUS_EDITION=paid` pointer (FR-11); in-place updates to `commands/conversus-gate.md`, `commands/ingest.md`, `commands/specify.md`, `docs/ingesting-arbitrary-specs.md`, `references/github-integration.md`, `references/spec-management.md` (FR-12, AD-7); two `knowledge/decisions/MEM*.md` entries — one for the edition-resolution precedence pattern, one for the paid-escape-hatch env-var convention (AD-8, OQ-6); `CHANGELOG.md` entry under the current version heading; dual-write Recent Changes to CLAUDE.md + AGENTS.md via `scripts/util/dual-write-runtime-md.sh` (OQ-10); new D-row in `.orchestrator/DECISIONS.md` naming the edition-resolution pattern (DC-2).
    - Consumes: P02's edition-aware adapter (the `edition_required:` handling reads off the same resolver code path); `scripts/util/dual-write-runtime-md.sh` (M014/P01, already shipped).

## Cross-Cutting Concerns

- **Adapter invariants CON-1..CON-5** — P01, P02, P03. Every phase preserves: 0/1/2 exit codes, `--strict` semantics, D019 universal TODO pre-flight + `CONVERSUS_GATE_TODO_THRESHOLD` / `CONVERSUS_GATE_SKIP_TODO_CHECK`, stub-mode fixture paths, the full env-var set (`CONVERSUS_HOME`, `CONVERSUS_PROVIDER`, `CONVERSUS_RUN_OUTPUT_DIR`, `CONVERSUS_STRICT`, `CONVERSUS_INTEGRATION`, `CONVERSUS_STUB`, `CONVERSUS_STUB_VERDICT`), `gate-result.md` frontmatter keys, `conversus.yml` synthesis shape, Bash 3.2 compat, and the filename-routed adapter auto-discovery pattern (MEM008/MEM018). Verified at every phase close via `scripts/verify/m011-p07-conversus-adapter-shape.sh`, `scripts/verify/m011-p07-gate-pass-block.sh`, `scripts/verify/m011-p07-bash32-compat.sh`, and `tests/test-conversus-adapter-shim.sh` stub-path sections (1, 1b, 2).

- **DC-6 synthesis-crux spike-gate** — P01 authors the spike as its first task and either clears or blocks P02. P02 does not begin resolver code changes until the spike returns "go". If the spike returns "block", M026 pauses at P01 and the operator decides whether to narrow scope (per OQ-2 → FR-1/FR-2 only), escalate a new D-row capturing the rehomed `linter.output_contract`-equivalent decision, or hand off to an OSS-upstream PR.

- **SB-5 Option A sequencing** — the whole milestone lands before spec 026's M014 shell-impl Pass-3 wiring. If spec 026 begins its shell-impl phase before M026 P02 closes, M026 adds a retroactive-test-update task to the affected phase (~half a day per DC-3).

- **Dual-write CLAUDE.md + AGENTS.md Recent Changes** — P01, P02, P03. Every phase close emits a Recent Changes entry via `scripts/util/dual-write-runtime-md.sh`, not inline-edited, to maintain marker-bounded region invariants (OQ-10).

- **Cross-repo read-only guard** — P01, P02, P03. No phase modifies `~/Sites/conversus` or `~/Sites/conversus-oss`. Bugs surfaced by the parity matrix become upstream handoffs per the spec 025 `CONVERSUS-PR-HANDOFF.md` pattern (SB-2 item 1).

- **Verification ladder** — each phase close runs the five-check battery (adapter shape, gate pass/block, bash32 compat, adapter-shim stub-path, spec-shape-lint on spec 027). Milestone close additionally inspects `M026-CONVERSUS-PARITY.md` for `Verified:` completion and authors the new D-row (DC-2).

## Dependency Graph

```
P01 (parity audit + DC-6 spike-gate)
 │
 ▼
P02 (Minimal Slice: resolver flip + env var + JSONL + dual-edition test)
 │
 ▼
P03 (Layer-on: paid-only detection + docs + MEM graduation)
```

Linear chain — no intra-milestone parallelism. The serialization is load-bearing:
- P01 → P02 because DC-6 requires the synthesis-crux spike to pass before the resolver flip lands against a possibly-unverified output contract.
- P02 → P03 because the preset-frontmatter handling in P03 reads the same resolver code path P02 mutates.

## Execution Order

1. **P01** — foundation. No intra-milestone dependencies. Executes as Tier C manual dispatch: `orchestrator:plan-phase M026 P01` → per-task `orchestrator:dispatch` → `orchestrator:verify`. First task is the DC-6 synthesis-crux spike; the parity-audit tasks run alongside or after, whichever plan-phase judges cheaper. If the spike returns "block", P01 halts at the spike-gate and the operator is notified before parity-audit tasks continue.
2. **P02** — unblocked only after P01 closes with the spike returning "go" and the parity matrix complete. Runs the Minimal Slice (US-1 + US-2 + US-3 from spec 027) as a single phase so resolver flip + env var + escape hatch + JSONL + dual-edition test land atomically.
3. **P03** — unblocked after P02 closes green. Purely additive layer-on; no invariant risk. Consolidate happens at P03 close and graduates the two MEM entries (AD-8).

## Validation

- **No conflicting producers**: PASS — P01 produces the parity matrix + spike verdict; P02 produces the adapter patches + regression-test extension + JSONL wiring; P03 produces the preset-frontmatter handling + doc updates + MEM entries. No overlap; each phase writes to distinct files or distinct code regions within `conversus.sh`.
- **All consumed items have producers**: PASS — P02 consumes P01's parity matrix + spike verdict + ollama probe. P03 consumes P02's edition-aware adapter. External consumes (`scripts/util/dual-write-runtime-md.sh`, the two conversus trees, the seed parity scratch) are already in-tree or read-only upstream.
- **DAG is acyclic**: PASS — trivially, a linear three-node chain (P01 → P02 → P03).
- **Demo sentence coverage**: PASS — each phase's demo sentence names a concrete, testable observable: P01 = parity-matrix `Verified:` column + spike go/no-go note; P02 = resolver default flip + escape-hatch behavior + dual-edition test pass; P03 = preset refusal diagnostic + six-surface doc updates + MEM graduation.
