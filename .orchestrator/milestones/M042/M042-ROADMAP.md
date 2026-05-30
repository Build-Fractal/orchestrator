---
schema_version: "1.0"
type: roadmap
milestone: "M042"
feature_ref: "042-corpus-exhaustion-gate"
feature_spec: "specs/042-corpus-exhaustion-gate/spec.md"
vision: "A mandatory, evidence-producing corpus-exhaustion gate before any question reaches a human — turning the soft 'exhaust the corpus first' habit into structure that cannot be skipped"
tier: "C"
created_at: "2026-05-30T00:00:00Z"
updated_at: "2026-05-30T00:00:00Z"
---

## Phases

- [x] **P01**: Deterministic gate engine + adapter + artifact contract — "Running `corpus-exhaustion-sweep.sh --questions <file> --checkpoint sme-packet --out <artifact>` against a fixture corpus that answers question A but not B emits an artifact marking A `HITS` (with citation) and B `CLEAN`; `corpus-gate.sh gate` exits `2` with an un-dispositioned HITS row and `0` when all rows are clean/dispositioned; disabled-config emits `SKIPPED:` + exit 0; `--strict` + missing manifest exits 1; the P01 acceptance battery (SC-1..SC-6) passes." — **closed 2026-05-30**, acceptance battery `pass=8 skip=0 fail=0`.
  - Risk: high
  - Depends: none
  - Boundary Map:
    - Produces: `scripts/knowledge/corpus-exhaustion-sweep.sh` (term extraction + grep sweep + artifact emission), `scripts/dispatch/adapters/tool/corpus-gate.sh` (check/gate/parse-verdict, exit-code contract), `templates/corpus-exhaustion-artifact.md` (artifact template), `templates/corpus-store-manifest.yml` (bundled default manifest), `corpus_exhaustion.*` keys in `scripts/state/read-config.sh` + `templates/orchestrator-config-default.yml` block, `commands/corpus-gate.md` (command doc), `packaging/skills/orchestrator-corpus-gate.md` (skill discovery), `tests/fixtures/corpus-gate/**`, `tools/verify/m042-p01-acceptance-battery.sh`
    - Consumes: `scripts/dispatch/adapters/tool/conversus.sh` (exit-code contract + adapter shape template), `scripts/state/read-config.sh` (nested-key resolution pattern — the `detective.*` block is the template), `scripts/engine/intensity-gate.sh` (intensity-tier read), `.orchestrator/DECISIONS.md` + `knowledge/KNOWLEDGE-INDEX.md` + `.orchestrator/memory/constitution.md` (default-manifest stores)

- [x] **P02**: Caller pre-finalize hooks + doctor bypass lint — "Each of `discuss`, `comments`, `materials-intake`, `specify`, `plan-phase`, `roadmap` documents and invokes the gate before finalizing a human-facing question packet/plan; `run-doctor.sh` emits `DOCTOR:CORPUS_EXHAUSTION status=warn` against a fixture with an unresolved BLOCK artifact and `status=ok` otherwise; the P02 suite passes (SC-7, SC-8)." — **closed 2026-05-30**, acceptance battery `pass=10 skip=0 fail=0`.
  - Risk: medium
  - Depends: P01
  - Boundary Map:
    - Produces: pre-finalize gate step in `commands/discuss.md`, `commands/comments.md`, `commands/materials-intake.md` (+ `scripts/lifecycle/materials-intake.sh` seam), `commands/specify.md`, `commands/plan-phase.md`, `commands/roadmap.md`; `scripts/diagnostics/check-corpus-exhaustion.sh` (doctor lint); P02 verifiers + phase suite
    - Consumes: `scripts/dispatch/adapters/tool/corpus-gate.sh` (from P01), the artifact contract (from P01), `scripts/diagnostics/run-doctor.sh` (doctor check auto-discovery convention)

- [ ] **P03**: Batched LLM semantic judge + auto-resolve (deferred; demand-driven) — "With `corpus_exhaustion.intensity_floor: full` and a stubbed judge, a `HITS` row whose cited content answers the question is upgraded to `ANSWERED` and dropped from the surviving-questions output, with the answer + citation recorded; `PARTIAL` rewrites the question to its residual; SC-9 passes."
  - Risk: medium
  - Depends: P02
  - Boundary Map:
    - Produces: `scripts/knowledge/lib/corpus-exhaustion-judge.sh` (batched judge wrapping the Tier-2 LLM call pattern), `templates/corpus-exhaustion-judge-prompt.md`, judge-routing + auto-resolve in the sweep engine (intensity-gated), default-off `ANSWERED`→DR promotion routed through the `comments` apply queue, P03 suite
    - Consumes: `scripts/knowledge/lib/extract-tier-2-llm.sh` (batched-LLM invocation precedent), `scripts/dispatch/adapters/tool/conversus.sh` (cooperative-deliberation shape for the adversarial which-store pass), the artifact contract (from P01)
  - Note: carries the unresolved #Q-1 M040 absorption decision. Do NOT build before the M034/M038/M040 decision-packet-family absorption decision is taken at queue-entry — the two-agent-sweep + human-gated-apply plumbing is shared and likely belongs in a common primitive.

- [ ] **P04**: Gate telemetry (deferred; demand-driven) — "A completed gate run appends a `corpus_exhaustion` JSONL record (checkpoint, questions_total, hits, clean, caveat, and P03 answered/partial/irreducible) to the execution-log stream; a rollup reports auto-answered vs reached-human."
  - Risk: low
  - Depends: P03
  - Boundary Map:
    - Produces: `corpus_exhaustion` event-type emission in the sweep engine, rollup surface, P04 suite
    - Consumes: M019 Tier 1 JSONL emitter, the artifact contract (from P01)

## Cross-Cutting Concerns

- **Graceful degradation (Principle XI fail-open)** — P01, P02. P01 establishes the pattern: disabled config / missing manifest → `SKIPPED:` + exit 0; unreachable store → `IRREDUCIBLE-WITH-CAVEAT`, never a silent skip or deadlock (CON-3/CON-6). P02 caller hooks must map BLOCK to a pause-for-disposition, not a crash.
- **Bash 3.2 compatibility (CON-1/CON-3)** — P01, P02. All new scripts avoid Bash 4+ features. P01 establishes the baseline; P02's doctor check conforms.
- **No silent truncation (CON-4)** — P01. Any cap on stores/terms/hits is recorded in the artifact.
- **Reproducibility under test (CON-7)** — P01, P03. No `date`/`$RANDOM` in the engine; timestamps are caller-supplied so fixtures are byte-stable.
- **Downstream contract stability** — all phases. The store manifest + artifact frontmatter format is consumed by opt-in projects; changes are additive.

## Dependency Graph

```
P01 → P02 → P03 → P04
```

Linear chain. P01 + P02 are the shippable launch scope (deterministic gate + caller wiring + doctor lint). P03 + P04 are demand-driven and gated on the #Q-1 M040 absorption decision.

## Execution Order

1. **P01** — foundation, no dependencies. Highest risk (the artifact + manifest is a versioned downstream contract; the exit-code contract is what every caller wires against). Delivers US-1 + US-2 (the deterministic gate, standalone-valuable).
2. **P02** — depends on P01. Medium risk (six command finalization-flow modifications). Delivers US-3 + US-4 (ambient gate + bypass lint).
3. **P03** — depends on P02. Medium risk (LLM cost + false-negative class #Q-3). Deferred / demand-driven; gated on #Q-1. Delivers US-5.
4. **P04** — depends on P03. Low risk. Deferred. Delivers US-6.

## Validation

- **No conflicting producers**: PASS — each script/template is produced by exactly one phase.
- **All consumed items have producers**: PASS — every `Consumes` entry traces to a `Produces` entry in an upstream phase or a shipped surface (conversus adapter, read-config, intensity-gate, extract-tier-2-llm, M019 emitter).
- **DAG is acyclic**: PASS — linear chain P01 → P02 → P03 → P04.
- **Demo sentence coverage**: PASS — each phase has a concrete, mechanically testable demo sentence.

## P01 Closure (2026-05-30)

P01 shipped the deterministic floor. On disk:

- `scripts/knowledge/corpus-exhaustion-sweep.sh` — term extraction (structured IDs, ISO dates, quoted phrases, significant tokens minus stopwords) + grep sweep over the configured store manifest + per-question artifact emission with verdict (`CLEAN`/`HITS`/`DROPPED`/`KEPT`/`IRREDUCIBLE-WITH-CAVEAT`) and a top-level `verdict: PASS|BLOCK`. Bash 3.2; reproducible (`--generated-at`, no `date`/`$RANDOM`); CON-3 caveat on unreachable required stores; CON-4 per-store hit cap noted in-artifact.
- `scripts/dispatch/adapters/tool/corpus-gate.sh` — `check`/`gate`/`parse-verdict` with the conversus-parallel exit-code contract (`0` PASS/SKIPPED · `2` BLOCK · `1` error); owns enabled/manifest/strict policy + graceful degradation.
- `templates/corpus-store-manifest.yml` (bundled default — only `DECISIONS.md` + `constitution.md` are `required: true`; the knowledge index varies by project so it is optional to avoid false caveats) + `templates/corpus-exhaustion-artifact.md`.
- `corpus_exhaustion.{enabled,store_manifest_path,intensity_floor}` keys in `scripts/state/read-config.sh` (nested-block walker, the `detective.*` template) + `templates/orchestrator-config-default.yml` block.
- `commands/corpus-gate.md` + `packaging/skills/orchestrator-corpus-gate.md`.
- `tests/fixtures/corpus-gate/**` + `tools/verify/m042-p01-acceptance-battery.sh` (SC-1..SC-6, `pass=8 skip=0 fail=0`).

**P02 follow-on (also 2026-05-30)** wired the gate into the six question-emitting commands and added the doctor lint:

- Full pre-finalize gate steps in `commands/discuss.md` (Finalize Context), `commands/specify.md` (Pass 3 → Open Questions), `commands/roadmap.md` (pre-write), `commands/plan-phase.md` (pre-write), `commands/materials-intake.md` (conflict-question branch). Each maps gate exit `2` (BLOCK) to a read-the-citations-then-disposition pause; exit `0` proceeds.
- Lighter pointer in `commands/comments.md` — its question-emission is conditional/rare (it classifies *inbound* comments), so it gets a "route drafted clarifying questions through the gate" note rather than a forced seam.
- `scripts/diagnostics/check-corpus-exhaustion.sh` + a `run_check` registration in `scripts/diagnostics/run-doctor.sh` (advisory). Low-noise design: `DOCTOR:CORPUS_EXHAUSTION status=warn` only when an artifact is left in an unresolved `BLOCK` state; `status=ok` otherwise (zero artifacts → ok). FR-11/SC-8 refined from "missing sidecar" to "unresolved BLOCK" (the precise mechanical proxy; missing-sidecar detection needs a should-be-gated registry, deferred).
- `tools/verify/m042-p02-acceptance-battery.sh` (SC-7 ×6 + SC-8 ×3 + shape): `pass=10 skip=0 fail=0`.

**Shippable scope (P01 + P02) is complete.** A `M042-VALIDATED` marker + `M042-SUMMARY.md` can be written to close the milestone at this scope; P03 (LLM judge) + P04 (telemetry) remain deferred pending the #Q-1 M040 absorption decision.

## Scope Note

P01 + P02 constitute the shippable milestone scope (the deterministic gate that catches the reported ~9/10 by forcing read-before-ask, wired into the question-emitting commands). P03 (LLM judge) + P04 (telemetry) are roadmapped but deferred to a demand-driven slot, and carry the #Q-1 absorption decision with M040. This roadmap intentionally refines the source proposal's phasing: the proposal placed the deterministic grep sweep in "Phase 2 (the automation)"; we pull it forward into the P01 foundation because it is cheap and deterministic, leaving only the LLM judge as the genuinely-deferred automation. See `.orchestrator/proposals/corpus-exhaustion-gate.md` for the source brief and triage.
