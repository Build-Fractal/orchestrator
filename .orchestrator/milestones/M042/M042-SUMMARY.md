---
schema_version: "1.0"
type: milestone-summary
id: "M042"
parent: "042-corpus-exhaustion-gate"
milestone: "M042"
provides:
  - "orchestrator:corpus-gate — a reusable, deterministic corpus-exhaustion gate that sweeps every configured knowledge store for each candidate operator/SME question before it reaches a human and refuses to finalize while any question has un-dispositioned corpus hits (search-before-ask / read-before-ask). Shipped scope P01+P02: P01 the deterministic engine + adapter + artifact + config + command/skill docs + acceptance battery; P02 pre-finalize wiring into the six question-emitting commands + the DOCTOR:CORPUS_EXHAUSTION bypass lint. P03 (batched LLM semantic judge + auto-resolve) and P04 (telemetry) are DEFERRED to a future demand-driven slice pending the #Q-1 M040 absorption decision."
requires:
  - "scripts/dispatch/adapters/tool/conversus.sh (exit-code contract + adapter shape template); scripts/state/read-config.sh (nested-key resolution — the detective.* block is the template); scripts/engine/intensity-gate.sh (intensity-tier read, P03); .orchestrator/DECISIONS.md + .orchestrator/memory/constitution.md (default-manifest required stores); scripts/diagnostics/run-doctor.sh (run_check registration convention)"
affects:
  - "scripts/state/read-config.sh (corpus_exhaustion.* keys); templates/orchestrator-config-default.yml (corpus_exhaustion block); scripts/diagnostics/run-doctor.sh (Corpus-Exhaustion Gate advisory check); commands/discuss.md + specify.md + roadmap.md + plan-phase.md + materials-intake.md + comments.md (pre-finalize gate steps); CLAUDE.md (recent-changes)"
key_files:
  - "scripts/knowledge/corpus-exhaustion-sweep.sh,scripts/dispatch/adapters/tool/corpus-gate.sh,scripts/diagnostics/check-corpus-exhaustion.sh,scripts/diagnostics/run-doctor.sh,scripts/state/read-config.sh,templates/corpus-store-manifest.yml,templates/corpus-exhaustion-artifact.md,templates/orchestrator-config-default.yml,commands/corpus-gate.md,commands/discuss.md,commands/specify.md,commands/roadmap.md,commands/plan-phase.md,commands/materials-intake.md,commands/comments.md,packaging/skills/orchestrator-corpus-gate.md,specs/042-corpus-exhaustion-gate/spec.md,tests/fixtures/corpus-gate/,tools/verify/m042-p01-acceptance-battery.sh,tools/verify/m042-p02-acceptance-battery.sh,.orchestrator/proposals/corpus-exhaustion-gate.md,.orchestrator/milestones/M042/M042-SUMMARY.md"
key_decisions:
  - "FR-1..FR-11(shipped),FR-12/FR-13/FR-14(deferred-P03/P04),SC-1..SC-8(shipped),CON-1..CON-7,NG-1..NG-5,#Q-1-M040-absorption-deferred-to-queue-entry,#Q-2-artifact-format-md-source-jsonl-later,#Q-3-judge-false-negative-P03,deterministic-grep-pulled-into-P01-foundation(proposal-had-it-in-phase-2),manifest-required-set-is-only-DECISIONS+constitution(knowledge-index-varies-by-project-so-optional-to-avoid-false-caveat),doctor-lint-low-noise-unresolved-BLOCK-not-missing-sidecar(missing-sidecar-needs-should-be-gated-registry-deferred),comments-gets-lighter-pointer(classifies-inbound-not-emits-questions),read-before-ask-disposition-on-question-line-for-reproducible-resweeps"
patterns_established:
  - "Search-before-ask gate: a deterministic grep sweep over a configurable store manifest produces a per-question evidence artifact (terms,stores-searched,citations,verdict) and a PASS|BLOCK that forces the agent to read candidate answers before posting a question to a human. The artifact doubles as packet provenance for the SME,Reuse the conversus gate-artifact convention rather than inventing one: corpus-gate.sh mirrors conversus.sh check/gate/parse-verdict with the identical 0-PASS/SKIP / 2-BLOCK / 1-error exit contract; callers wire against the same shape,Disposition-on-the-question-line: corpus hits are resolved by annotating the question (@disposition=dropped|kept) rather than editing the generated artifact — keeps the sweep a pure function of (questions+corpus) so re-runs are reproducible,Reproducible-under-test engine: no date/$RANDOM in the sweep (caller-supplied --generated-at) so fixtures are byte-stable,CON-3 caveat over silent skip: an unreachable required store yields IRREDUCIBLE-WITH-CAVEAT naming the store, never a silent skip or a permanent deadlock,Low-noise doctor lint: warn only on an unresolved BLOCK artifact (a gate that blocked and was never resolved), zero-noise on projects with no artifacts"
drill_down_paths:
  - "specs/042-corpus-exhaustion-gate/spec.md,.orchestrator/milestones/M042/M042-ROADMAP.md,.orchestrator/milestones/M042/M042-EVALUATION.md,.orchestrator/proposals/corpus-exhaustion-gate.md"
duration: "single-session proposal-capture-to-P02-close (2 phases shipped, direct edits + acceptance batteries)"
verification_result: "pass"
completed_at: "2026-05-30T00:00:00Z"
observability_surfaces:
  - "tools/verify/m042-p01-acceptance-battery.sh BATTERY: pass=8 skip=0 fail=0 (SC-1..SC-6); tools/verify/m042-p02-acceptance-battery.sh BATTERY: pass=10 skip=0 fail=0 (SC-7 x6 + SC-8 x3 + shape); run-doctor.sh emits DOCTOR:CORPUS_EXHAUSTION status=ok artifacts=0 against this repo"
---

M042 (corpus-exhaustion gate) turns the soft "exhaust the corpus first" habit
into a hard, evidence-producing gate. Before any question reaches an
operator/SME — and before a plan/spec/roadmap finalizes — the gate sweeps every
configured knowledge store for each candidate question and refuses to pass while
any question has un-dispositioned corpus hits. It was captured from a downstream
PBJ-Analyzer proposal (operator estimate: ~9 of 10 drafted questions were
already answered somewhere in the project's own knowledge) and built to the
shippable P01+P02 scope in a single session.

**P01 — deterministic engine (zero LLM).** `corpus-exhaustion-sweep.sh` extracts
search terms per question (structured IDs, ISO dates, quoted phrases, significant
tokens minus stopwords), greps every reachable store in a configurable manifest,
and emits a per-question artifact with verdicts (CLEAN / HITS / DROPPED / KEPT /
IRREDUCIBLE-WITH-CAVEAT) and a top-level PASS|BLOCK. `corpus-gate.sh` wraps it
with the conversus exit-code contract (0 PASS/SKIP · 2 BLOCK · 1 error) and owns
the enabled/manifest/strict policy + fail-open degradation. Read-before-ask: a
hit-bearing question BLOCKs until the agent reads the cited locations and
annotates the question line `@disposition=dropped` (answered — recorded + removed
from the packet) or `@disposition=kept` (genuinely open — stays). Dispositions
live on the question line so re-sweeps are reproducible.

**P02 — caller wiring + bypass lint.** The gate is documented as a pre-finalize
step in `discuss` (Finalize Context), `specify` (Pass 3 / Open Questions),
`roadmap` and `plan-phase` (pre-write), and `materials-intake` (conflict-question
branch); `comments` gets a lighter pointer because it classifies inbound comments
rather than drafting questions. `check-corpus-exhaustion.sh` (registered
advisory in `run-doctor.sh`) surfaces artifacts left in an unresolved BLOCK
state — `DOCTOR:CORPUS_EXHAUSTION status=warn` — and is zero-noise on projects
with no artifacts.

**Deferred (future demand-driven slice).** P03 (batched LLM semantic judge that
upgrades HITS into ANSWERED/PARTIAL/MENTIONS and auto-resolves answered
questions) and P04 (gate telemetry over the M019 JSONL stream) are roadmapped but
not built. They carry the #Q-1 absorption decision with M040's decision-
contradiction gate — both are a two-agent conversus sweep with PASS|BLOCK +
human-gated apply — to be resolved at the M034/M038/M040 decision-packet-family
queue-entry. The deterministic P01 gate already catches the reported ~9/10 by
forcing read-before-ask; the judge is the automation layer on top.

Closed at P01+P02 shippable scope. `M042-VALIDATED` marker on disk; P03/P04
forward-pointed in `M042-ROADMAP.md`. See that roadmap for the phase boundaries
and the source brief at `.orchestrator/proposals/corpus-exhaustion-gate.md`.
