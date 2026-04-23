---
schema_version: "1.0"
type: context-draft
milestone: "M026"
status: draft
created_at: "2026-04-23"
finalized_at: null
---

## Architectural Decisions

<!-- Key architectural choices for this milestone.
     Each item is an agent-default answer grounded in spec 027 + the D-row history
     in .orchestrator/DECISIONS.md + the parity scratch at
     .orchestrator/scratch/conversus-oss-migration-parity.md. Operator review required. -->

### AD-1. Edition-knob shape: env-var (CONVERSUS_EDITION) inside the existing adapter

**Agent-default answer** `[agent-default — operator review required]`: adopt the env-var
approach **inside** `scripts/dispatch/adapters/tool/conversus.sh` (not a new adapter
file). Four options were considered in the parity scratch (env-var toggle, per-invocation
flag, layered adapter, symlink-at-install); the env-var approach satisfies the "keep the
abstraction boundary" ask from D007 (M011/P07 reusable adapter) with the smallest code
change and does not multiply the adapter-file surface. The layered-adapter option is
rejected because it doubles the maintenance burden and splits the `conversus` filename
auto-discovery pattern (MEM008/MEM018) across two files. Symlink-at-install is rejected
because it cannot coexist with dual-edition debugging. The per-invocation `--edition`
flag is rejected because it requires every caller (`specify.sh`, `github-conversus-gate.sh`,
`ingest.sh`) to thread the decision — the env-var approach lets the operator set
edition once per session or per CI job.

### AD-2. Binary-resolution precedence order

**Agent-default answer** `[agent-default — operator review required]`: the final
precedence order is `CONVERSUS_STUB=1 → CONVERSUS_HOME → command -v conversus → user-local probe (edition-aware)`.
The user-local probe tries `~/Sites/conversus-oss/bin/conversus` first when
`CONVERSUS_EDITION=oss` (default) or unset; and `~/Sites/conversus/bin/conversus` first
when `CONVERSUS_EDITION=paid`. If the preferred user-local probe fails, the other is
tried as fallback (with an `edition=... reason=fallback` diagnostic so the operator sees
the fallback). `command -v conversus` preceding the edition-aware user-local probe is
load-bearing: CI environments and custom `PATH` entries win over the convention, which
preserves M011/P07's existing behavior on integration-test hosts.

### AD-3. Paid-only detection mechanism: preset frontmatter field

**Agent-default answer** `[agent-default — operator review required]`: ship **only**
the preset-frontmatter `edition_required: paid` detection (FR-10 minimum-viable rule).
Defer provider-value detection (`CONVERSUS_PROVIDER=claude-code before PR #28`),
mode-value detection, and any other runtime rule until a real caller needs one. This is
Constitution XIV applied: the detection surface earns its cost only when someone writes
a paid-dependent preset, which won't happen until M018 plans red-team + domain/security
gates. If that cost shows up differently than expected, the plan-phase for the
consuming milestone re-opens FR-10 via a new D-row.

### AD-4. JSONL `edition` field is additive, placement follows M019 precedent

**Agent-default answer** `[agent-default — operator review required]`: add
`"edition": "oss|paid|unknown"` as a new field in every `conversus_gate_invocation`
JSONL record emitted by `emit_conversus_gate_record` (in `scripts/integrations/github-common.sh`)
and by inline emissions (`scripts/specify/specify.sh:532`). Place the field adjacent to
`adapter_version` so M019 Tier 2+3 rollups that key on provenance fields find
edition alongside them. Existing consumers (none that read `edition` today; M019 Tier 1
doesn't reference it) are unaffected because JSONL is additive-tolerant.

### AD-5. Preset-extension field: optional, no retroactive application

**Agent-default answer** `[agent-default — operator review required]`: the
`edition_required:` field is optional in `templates/conversus-presets/*.yml`
frontmatter. None of the three existing presets (`normalize-fidelity.yml`,
`m013-uat-defect-merge.yml`, `spec-pressure-test.yml`) gain the field during this
migration — they all work on both editions today (the parity matrix verifies this, or
surfaces the gap at plan-phase). The field is reserved for future preset authors who
know they depend on paid-only upstream work.

### AD-6. Regression-test posture: dual-edition run gated on CONVERSUS_INTEGRATION=1

**Agent-default answer** `[agent-default — operator review required]`: extend
`tests/test-conversus-adapter-shim.sh` so the existing `CONVERSUS_INTEGRATION=1` block
runs twice — once per edition when both builds are installed, else a clean `SKIP:` on
the absent edition. Stub-mode path (sections 1, 1b, 2 of the test) unchanged. Rationale:
the test is already opt-in via `CONVERSUS_INTEGRATION=1`; adding a second edition is a
light extension rather than restructuring. CI without either binary still passes on the
stub + synth-direct paths.

### AD-7. Documentation-surface update shape: revise-in-place, no new docs

**Agent-default answer** `[agent-default — operator review required]`: update the six
named doc surfaces in place; do NOT add a new `docs/conversus-oss-migration.md` or
similar. Rationale: operators discover resolver-order prose at the reading paths they
already use (`commands/conversus-gate.md`, `docs/ingesting-arbitrary-specs.md`,
`references/github-integration.md`). A net-new doc fragments discovery and duplicates
the authoritative prose. The Recent Changes entry in CLAUDE.md + AGENTS.md already
signals the migration exists; the six updated surfaces are the authoritative narrative.

### AD-8. Knowledge-layer graduation scope for this milestone

**Agent-default answer** `[agent-default — operator review required]`: graduate **two**
`knowledge/decisions/MEM*.md` entries at consolidate — one for the
edition-resolution precedence pattern (for future tool-adapter work on other paid/OSS
splits), one for the paid-escape-hatch env-var convention (for future adapter
extensions). Do NOT graduate entries into `knowledge/spec/**` — that's M020's schema
authority per D013/D016 Knowledge-Layer Boundary. If a lesson surfaces that belongs in
knowledge/spec, it's handed off to M020's Open Questions, not landed in M026.

---

## Scope Boundaries

### SB-1. In-scope: six named work items (minimal slice + layer-ons)

**Agent-default answer** `[agent-default — operator review required]`:

In-scope for M026:
1. Resolver-order flip in `conversus.sh` (FR-1) — ~15 lines of bash.
2. `CONVERSUS_EDITION` env var wiring (FR-2) — ~10 lines of bash.
3. `edition=` diagnostic line in `check` output + JSONL records (FR-3, FR-4) — ~8 lines.
4. Parity audit artifact `.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md` (FR-9) — multi-hundred-line markdown table with `Verified:` column populated by actual fs-inspection of both trees.
5. Dual-edition regression test extension (FR-8) — ~40 lines in `tests/test-conversus-adapter-shim.sh`.
6. Preset frontmatter `edition_required:` field + diagnostic on OSS binary (FR-10, FR-11) — ~20 lines of bash.
7. Doc updates across six surfaces (FR-12) — text-substantive but mechanically-shaped revisions.

### SB-2. Out-of-scope — hard excluded

**Agent-default answer** `[agent-default — operator review required]`:

Explicitly out of scope:
1. Any modification of `~/Sites/conversus` or `~/Sites/conversus-oss`. Bugs surfaced by
   the parity audit become upstream handoffs (pattern: spec 025's
   `CONVERSUS-PR-HANDOFF.md`).
2. Reopening the 0/1/2 exit-code contract, `--strict` semantics, preset YAML shape, or
   `gate-result.md` frontmatter fields. CON-1 in the spec is binding.
3. Reopening spec 025 (M020 knowledge-layer) scope. Spec 025 stays at
   `Ready-for-discuss-gate-deferred` regardless of this migration's landing.
4. Reopening spec 026 (M014 three-pass shell impl) scope. Its adapter-invocation
   contract stays pinned; this migration preserves it.
5. MCP-renderer escape hatch for M023 Design Layer — M023's scope per D016.
6. Runtime paid-feature detection beyond preset frontmatter. Mechanical detection of
   CLI-flag values / mode values / provider values is NG-6.
7. A one-shot install helper for operators. Dual-edition coexistence is the design.

### SB-3. Relationship to the D016 forward roadmap

**Agent-default answer** `[agent-default — operator review required]`: M026 was not
named in D016. The spec proposes slotting M026 BEFORE M014's next extended phase
(specifically, before spec 026's shell-impl phase lands) to avoid rewriting spec 026's
tests against the post-migration adapter after the fact (Option A in spec's #OQ-2). The
alternative (Option B, slot AFTER spec 026 shell-impl) costs one round of test rewrite.
Operator decision at discuss-finalize.

### SB-4. In-flight specs cross-cuts (read-only)

**Agent-default answer** `[agent-default — operator review required]`:

- Spec 025 (M020): no body modification; cross-cut captured in spec 027's #OQ-1. If
  OSS ships with PRs #28 + #29 merged by M026 close, the spec 025 gate re-run happens
  on OSS; otherwise it happens on paid via escape hatch. Either way, the re-run
  consumes the post-migration adapter.
- Spec 026 (M014 three-pass shell): no body modification; its adapter-invocation
  contract is preserved verbatim by M026's CON-1. Spec 026's implementation-phase
  tests naturally re-run green under the post-migration resolver order.
- Knowledge-layer schema authority stays with M020 per D013/D016.

---

## Design Constraints

### DC-1. Adapter invariants that CANNOT change

**Agent-default answer** `[agent-default — operator review required]`: the following
invariants are binding (CON-1..CON-5 in spec 027):

- Exit codes 0 (PASS / SKIPPED), 1 (adapter error), 2 (BLOCK).
- `--strict` flag semantics: missing binary → FAIL + exit 1 under strict; → SKIPPED + exit 0 otherwise.
- D019 universal TODO pre-flight + `CONVERSUS_GATE_TODO_THRESHOLD` / `CONVERSUS_GATE_SKIP_TODO_CHECK`.
- Stub-mode fixture paths + `CONVERSUS_STUB` / `CONVERSUS_STUB_VERDICT` env vars.
- All existing env vars: `CONVERSUS_HOME`, `CONVERSUS_PROVIDER`, `CONVERSUS_RUN_OUTPUT_DIR`, `CONVERSUS_STRICT`, `CONVERSUS_INTEGRATION`.
- `gate-result.md` frontmatter fields: `verdict`, `disputes`, `rationale`, `source_hash`, `preset`, `artifact`, `conversus_output_dir`, `conversus_config`.
- `conversus.yml` synthesis shape (mode / target / output / iterations / agents / arbiter).
- Bash 3.2 compat (MEM001 posture).
- Filename-routed adapter auto-discovery pattern (MEM008/MEM018).

### DC-2. Verification discipline

**Agent-default answer** `[agent-default — operator review required]`:

At every phase close:
- `bash scripts/verify/m011-p07-conversus-adapter-shape.sh` — asserts adapter shape invariants (FR-1..FR-4 / CON-1..CON-3).
- `bash scripts/verify/m011-p07-gate-pass-block.sh` — asserts 0/2 exit-code decision arms.
- `bash scripts/verify/m011-p07-bash32-compat.sh` — Bash 3.2 compat check (CON-2).
- `bash tests/test-conversus-adapter-shim.sh` — stub-path + dual-edition integration (FR-8 / SC-4 / SC-6).
- `bash scripts/verify/spec-shape-lint.sh specs/027-conversus-oss-migration/spec.md` — spec-shape (already green: 10/10 at scaffold close).

At milestone close:
- Parity matrix artifact (FR-9 / SC-9) inspected by operator for `Verified:` completion.
- Dual-write invariant (CLAUDE.md + AGENTS.md markers) maintained.
- New D-row in `.orchestrator/DECISIONS.md` naming the edition-resolution pattern (likely D020).

### DC-3. Sequencing constraint vs. spec 026

**Agent-default answer** `[agent-default — operator review required]`: M026 should
close its Minimal Slice (US-1+US-2+US-3) **before** spec 026's shell-impl phase reaches
Pass-3 wiring — this is the cheapest-rework path. If spec 026's Pass-3 wiring lands
first, plan-phase for M026 gains an additional phase for retroactive test updates (~half
a day's work; not prohibitive but unnecessary). Operator decides at discuss-finalize;
this is the load-bearing sequencing call for the overall D016 roadmap.

### DC-4. Testing constraint on non-deterministic upstream

**Agent-default answer** `[agent-default — operator review required]`: the dual-edition
integration test (FR-8) must tolerate the upstream's non-determinism — verdict values
(PASS vs BLOCK) can differ across runs and editions because conversus is stochastic per
`commands/conversus-gate.md` Idempotency section. The test asserts **shape** (exit codes,
frontmatter key set, key types) not **value** (specific verdicts). Mechanically: a
sorted-key diff with zero lines is the pass signal (SC-6).

### DC-5. Diagnostic-emission posture

**Agent-default answer** `[agent-default — operator review required]`: diagnostics fire
to stderr (not stdout) so they don't corrupt the adapter's `verdict=PASS|BLOCK` stdout
contract. The new `edition=` line in `check` output is an exception — `check` already
emits structured stdout and `edition=` joins that namespace. All other diagnostics
(US-4 paid-only preset refusal, US-1 fallback reason) are stderr-only.

---

## Open Questions

### OQ-1. Sequencing vs. spec 026 (M014 three-pass shell impl)

**Agent-default answer** `[agent-default — operator review required]`: Option A — land
M026 Minimal Slice BEFORE spec 026 shell-impl. Rationale: spec 026 bakes
`conversus.sh gate --strict` invocation into `scripts/specify/specify.sh`; if M026
lands second, spec 026's tests get one round of churn (not catastrophic, but
preventable). Option B (M026 after spec 026 shell-impl) is the defensible alternative
if the operator judges the three-pass shell more urgent than the edition flip.
Load-bearing decision — affects the D016 forward roadmap's interpretation.

### OQ-2. OSS parity confidence level — what if fs-inspection surfaces gaps

**Agent-default answer** `[agent-default — operator review required]`: if plan-phase's
fs-inspection of `~/Sites/conversus-oss` surfaces ≥3 divergences from paid in the
consumption surface (e.g., `linter.output_contract` schema drift, `conversus run`
provider-set difference, pipx venv path), narrow M026's scope to resolver-flip
+ escape-hatch only (FR-1 + FR-2 + FR-3). Defer FR-4 JSONL field, FR-10/FR-11
paid-only diagnostic, FR-8 dual-edition regression test to a follow-up milestone. The
default-flip product ask still lands; the polish items wait. If divergences are 0–2,
the full scope holds.

### OQ-3. Pipx venv path lookup under dual-edition installs

**Agent-default answer** `[agent-default — operator review required]`: make the
integration test's venv-python lookup edition-aware — probe
`~/.local/pipx/venvs/conversus-oss/bin/python` first under `CONVERSUS_EDITION=oss`
(default), else `~/.local/pipx/venvs/conversus/bin/python`. If neither exists, fall
back to the first python3 on PATH with PyYAML importable. The current lookup
(`tests/test-conversus-adapter-shim.sh:119-124`) already does a fallback chain; extend
it to try both venv paths.

### OQ-4. Upstream PR #28 / #29 merge status in OSS

**Agent-default answer** `[agent-default — operator review required]`: treat this as an
**external** dependency the operator resolves outside the orchestrator. At discuss-
finalize, the operator indicates whether OSS has either/both fixes. Three scenarios:
- Both fixes in OSS → M026 lands fully; spec 025 gate re-run targets OSS.
- Neither in OSS → M026 lands with paid-escape-hatch documented as the path for specs
  that need the fixes; spec 025 gate re-run targets paid.
- One of two in OSS → mixed guidance per-caller.

M026's adapter doesn't need to know the status — the `edition=` diagnostic surfaces the
choice to the operator and the escape hatch reaches paid when needed.

### OQ-5. `CONVERSUS_EDITION` naming

**Agent-default answer** `[agent-default — operator review required]`: keep
`CONVERSUS_EDITION`. Alternatives considered: `CONVERSUS_BUILD` (conflates with
build-system terminology), `CONVERSUS_TIER` (conflates with orchestrator tier A/B/C),
`CONVERSUS_VARIANT` (too generic). "Edition" matches common open-source vs.
paid-enterprise vocabulary (community edition / enterprise edition).

### OQ-6. Knowledge-layer MEM graduation count ceiling

**Agent-default answer** `[agent-default — operator review required]`: cap at 2 MEM
entries (edition-resolution precedence, paid-escape-hatch env-var convention). A third
lesson (if it surfaces) goes into scratch or becomes a handoff. The cap is a
Constitution I + XIV posture — don't proliferate knowledge entries that no downstream
caller reads.

### OQ-7. M023 MCP-renderer cross-cut

**Agent-default answer** `[agent-default — operator review required]`: defer entirely
to M023. M026's `CONVERSUS_EDITION` env var gives M023 a surface to pin edition
per-invocation if MCP-enabled renderers end up paid-only. No M026 work needed for this
cross-cut today.

### OQ-8. What if the operator wants to keep paid as default?

**Agent-default answer** `[agent-default — operator review required]`: the product ask
explicitly says "Default: orchestrator uses ~/Sites/conversus-oss" — so OSS default is
load-bearing. If the operator changes this preference at discuss-finalize (e.g., "paid
default, OSS as escape"), it's a one-line flip in FR-1 (swap the probe order in
`_resolve_binary()`) and a doc update. No other scope changes. Flagged here because it
would invalidate the spec's wording in ~8 places; edit before planning if the
operator wants this.

### OQ-9. Who authors the parity matrix's `Verified:` column

**Agent-default answer** `[agent-default — operator review required]`: plan-phase task
for M026/P01 — one task is "fs-inspect ~/Sites/conversus-oss and ~/Sites/conversus for
each surface in the scratch parity matrix; populate the `Verified:` column". The agent
performs the inspection (not the operator) — but the operator reviews the matrix at
milestone-close before it enters `knowledge/decisions/`. This is the single task that
unblocks OQ-2's scope decision.

### OQ-10. Dual-write requirement: AGENTS.md parity

**Agent-default answer** `[agent-default — operator review required]`: every doc
update that mentions `CONVERSUS_EDITION` or the new resolver order must follow the
CLAUDE.md / AGENTS.md dual-write pattern for Recent Changes (already applied at spec
027 scaffolding). Recent Changes entries for each phase-close should be emitted via
`scripts/util/dual-write-runtime-md.sh`, not inline-edited, to maintain marker-bounded
region invariants.

### OQ-11. Session fs-access constraint

**Agent-default answer** `[agent-default — operator review required]`: the session
that scaffolded this spec (2026-04-23) could not fs-inspect either conversus tree
(sandbox). The parity matrix at `.orchestrator/scratch/conversus-oss-migration-parity.md`
is therefore grounded in this repo's own code + docs only, with `VERIFY` markers on
every row that requires external-tree inspection. Plan-phase runs with a session
configured to read both trees; that session authors `M026-CONVERSUS-PARITY.md`. This
OQ documents the known gap so the operator doesn't assume parity is verified today.

**UPDATE 2026-04-23 (same-session)**: a follow-up dogfood smoke test ran OSS 0.3.0
against spec 027 with fs-access, partly retiring this gap. See the
"Updates from OSS smoke test" section below.

## Updates from OSS smoke test (2026-04-23)

After the agent-defaults above were drafted, a follow-up dogfood smoke test invoked
the freshly-installed `conversus` (OSS 0.3.0, `Build-Fractal/conversus-oss` via pipx)
directly against `specs/027-conversus-oss-migration/spec.md`. Two invocations ran
without touching the orchestrator adapter: `conversus run ... --provider mock`
(pipeline-health) and `conversus run ... --provider anthropic` (real-signal attempt).
Full commentary lives at `specs/027-conversus-oss-migration/conversus/oss-early-review.md`.
Seven concrete Open Questions (OQ-9..OQ-15) were folded into spec 027's
`## Open Questions` section.

Key items that **should inform discuss-finalize** and may revise agent-defaults above:

### Evidence that validates prior agent-defaults

- **Mock pipeline works end-to-end on OSS 0.3.0** (0.71s, 5 phases, zero tokens).
  OSS's red-blue mode is wired and runnable out of the box. This validates the
  load-bearing premise behind AD-1/AD-2 (resolver-order swap is feasible) and
  SB-1's "migration is primarily an adapter-layer concern, not a conversus-rewrite".
- **Upstream PR #29 (parallel-429) reproduces on OSS on first contact** (2 agents,
  no concurrent traffic, subscription auth present). Confirms #29 is an OSS-side
  issue too, not just a paid-build quirk.

### Evidence that surfaces new risk

- **OSS's top-level YAML contract rejects frontmatter.** Orchestrator presets lead
  with `---\nschema_version: "1.0"\n---`; OSS's `validate` refuses them
  (`ComposerError: expected a single document in the stream`). The preset is NOT
  directly portable. **Operator review item**: confirm at discuss-finalize that
  `conversus-synth.py` strips frontmatter before synthesis (tracked as OQ-9 in
  spec 027). If it doesn't, call that out as a plan-phase task, not an Open Question.
- **The `arbiter:` ↔ `synthesis` phase boundary is the real parity crux**, not
  resolver order. FR-5/FR-7/SC-6 in spec 027 all assume "gate-result.md frontmatter
  fields unchanged". OSS's red-blue pipeline ends at `synthesis`, not `arbitration`;
  whether `linter.output_contract` (or equivalent) ships in the OSS venv and produces
  those fields is **untested**. Spec 027 OQ-13 names this as the parity crux.
  **Suggestion for operator**: add a **DC-6 (synthesis-crux-verification-required)**
  constraint to this draft during review, pinning a pre-implementation spike to
  confirm OQ-13 has an answer before resolver order flips.

### Open Questions that gain priority

- **OQ-1 (sequencing vs. spec 026)** — smoke test strengthens the case for Option A
  (M026 first). Spec 026's Pass 3 gate will land on whatever adapter the orchestrator
  ships; landing M026 first avoids spec 026's shell tests being written against a
  paid-only surface that then gets rehomed.
- **OQ-3 (ollama fallback for FR-8 OSS branch)** — implied by OQ-14. If PR #29 is
  unresolved at plan-phase, FR-8's dual-edition integration test needs either ollama,
  a skip-on-429 mode, or a version-gate. Operator should flag preference at
  discuss-finalize.

### Parity matrix status

`.orchestrator/scratch/conversus-oss-migration-parity.md` remains VERIFY-everywhere
in its authored form, but four rows have been partly retired by evidence:

1. CLI shape (`conversus run <config.yml> --provider ...`): **confirmed identical** on OSS.
2. Exit codes (0 ok, 1 error, 2 block): **confirmed** (mock exit 0, anthropic exit 1 on 429).
3. Top-level YAML contract: **confirmed drifted** (frontmatter rejected).
4. Preset field shape: **confirmed drifted** (`prompt` vs. `system_prompt`, `role:` required, `output:` semantic collision).

Plan-phase should fold these four rows into `M026-CONVERSUS-PARITY.md` as
"confirmed 2026-04-23" rather than re-running the smoke invocations.
