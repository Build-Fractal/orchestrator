---
schema_version: "1.0"
type: feature-spec
feature_slug: "042-corpus-exhaustion-gate"
created_at: "2026-05-30"
status: "Draft"
milestone: "M042"
---

# Feature Specification: 042-corpus-exhaustion-gate

**Feature Branch**: `feat/m042-corpus-exhaustion-gate`
**Created**: 2026-05-30
**Status**: Draft
**Milestone**: M042
**Input**: Downstream proposal `/.orchestrator/proposals/corpus-exhaustion-gate.md` (captured 2026-05-30 from the PBJ Analyzer project): make "search everything the orchestrator already stores, and prove the question is genuinely open" a hard, evidence-producing gate before any question reaches a human and before any plan/spec/roadmap finalizes — turning the soft "exhaust the corpus first" habit into structure that cannot be skipped.

## Problem Statement

When an orchestrator command drafts questions for an operator or subject-matter expert (SME) — `discuss`'s grilling protocol, `materials-intake`'s reconciliation conflicts, `comments`'s amendment queue, `specify`'s clarifications, `plan-phase`'s open questions — a large fraction of those questions turn out to be **already answered** somewhere in the project's stored knowledge. A downstream operator estimate puts the rate at ~9 out of 10. The agent only discovers this after the human says "go search the corpus, decisions, and memories first," at which point the agent searches and answers its own question.

Three concrete costs follow: (1) **Wasted human attention** — operator/SME time is the most expensive resource in a validator pilot, spent answering what the project already recorded. (2) **Eroded trust** — asking an SME something they already told you reads as not listening. (3) **Decision re-litigation** — a question that is actually a *locked decision* (a DR) can get re-asked and contradict the record.

Today this is mitigated only by **soft memory** — per-project habits ("exhaust corpus before operator questions") that depend on the agent remembering to apply them. A habit is not a gate; it gets skipped. The minimum surface that fixes all three costs is a **mandatory, evidence-producing corpus-exhaustion gate**: before any question is finalized for a human, a deterministic sweep searches every configured knowledge store, records what it found per question, and the emitting step **cannot finalize without that artifact**. This mirrors enforcement the orchestrator already has — hard build gates (`BG-###`), the conversus PASS|BLOCK gate (`orchestrator:conversus-gate`), and the 4-tier `orchestrator:verify` ladder — and reuses the gate-artifact convention rather than inventing a new one.

This feature explicitly does not author the questions, decide whether a found hit *semantically answers* a question without an LLM (the P03 judge does that), or auto-promote found answers into the decision record by default.

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

US-1 (deterministic sweep + evidence artifact) + US-2 (hard-gate enforcement contract) + FR-1 through FR-9. This slice delivers the load-bearing loop with **zero LLM cost**: given a set of candidate questions and a checkpoint name, a deterministic grep sweep over the configured store manifest produces a per-question evidence artifact (search terms · stores searched · hits · verdict), and the gate adapter exits `2` (BLOCK) when a question has un-dispositioned corpus hits, `0` (PASS) when every question is clean or dispositioned. The reusable skill + adapter + artifact contract are the deliverable; caller wiring (US-3), the doctor bypass-lint (US-4), the LLM judge (US-5), and telemetry (US-6) build on top.

### User Story 1 — Deterministic Corpus Sweep with Evidence Artifact (Priority: P1)

As an agent about to ask a human a set of questions, I want a deterministic sweep that searches every configured knowledge store for each question and records what it found, so that I read the candidate answers before deciding the question is genuinely open — without depending on remembering to do it.

**Why this priority**: The foundation. The hard gate (US-2) and every downstream surface have nothing to enforce against without the evidence artifact.

**Independent Test**: Run `scripts/knowledge/corpus-exhaustion-sweep.sh --questions <file> --checkpoint sme-packet --out <artifact>` in a fixture project whose corpus contains an answer to question A and nothing for question B. Verify exit reflects the gate contract and the artifact contains one verdict row per question: question A → `HITS` with a `store:path:line` citation; question B → `CLEAN`.

**Acceptance Scenarios**:

1. **Given** a questions file and a store manifest pointing at populated stores, **When** the sweep runs, **Then** the artifact contains, per question: the extracted search terms, the list of stores actually searched, the hit citations (`store · path · line`), and a verdict of `HITS` or `CLEAN`.
2. **Given** a question whose key term appears in `DECISIONS.md`, **When** the sweep runs, **Then** that question is marked `HITS` with the `DECISIONS.md` citation, and the gate refuses to pass until the question is dispositioned (read-before-ask).
3. **Given** a configured store that is unreachable or broken (e.g., a missing `knowledge.db`), **When** the sweep runs, **Then** the question is marked `IRREDUCIBLE-WITH-CAVEAT`, the artifact records which store could not be searched, and the sweep never silently skips a store.

---

### User Story 2 — Hard-Gate Enforcement Contract (Priority: P1)

As the orchestrator framework, I want a reusable gate adapter with a PASS|BLOCK exit-code contract identical to the conversus gate, so that any question-emitting step can refuse to finalize until a corpus-exhaustion artifact exists and every question is clean or dispositioned.

**Why this priority**: Co-equal with US-1 — the artifact has no teeth without enforcement. The exit-code contract is what callers wire against.

**Independent Test**: Invoke `scripts/dispatch/adapters/tool/corpus-gate.sh gate <questions> <manifest> <out>`. With an un-dispositioned `HITS` row present, verify exit `2`. With all rows `CLEAN` or dispositioned, verify exit `0`. With the feature disabled in config, verify a `SKIPPED:` line and exit `0`. With a malformed manifest, verify exit `1`.

**Acceptance Scenarios**:

1. **Given** a sweep artifact with at least one un-dispositioned `HITS` row, **When** the gate adapter runs, **Then** it emits `verdict=BLOCK` and exits `2`.
2. **Given** a sweep artifact whose every row is `CLEAN`, `IRREDUCIBLE`, dispositioned (`disposition: dropped|kept`), or `IRREDUCIBLE-WITH-CAVEAT`, **When** the gate adapter runs, **Then** it emits `verdict=PASS` and exits `0`.
3. **Given** `corpus_exhaustion.enabled: false` in config, **When** the gate adapter runs, **Then** it emits `SKIPPED: corpus-exhaustion gate disabled` and exits `0` (graceful degradation; never blocks a project that has not opted in).
4. **Given** an existing artifact, **When** `corpus-gate.sh parse-verdict <artifact>` runs, **Then** it emits `verdict=PASS|BLOCK` from the artifact frontmatter, mirroring `conversus.sh parse-verdict`.

---

### User Story 3 — Caller Pre-Finalize Integration (Priority: P2)

As an operator using `discuss`, `comments`, `materials-intake`, `specify`, `plan-phase`, or `roadmap`, I want those commands to run the corpus-exhaustion gate before finalizing any human-facing question packet or plan, so that only genuinely-open questions reach me.

**Why this priority**: P2 — the gate is fully functional standalone; caller wiring is what makes it ambient. Ships in P02 once the P01 contract is stable.

**Independent Test**: For each wired command, confirm its finalization section documents the pre-finalize gate step and the BLOCK-handling behavior. (Command docs are agent-instruction documents; the test is shape-lint + presence of the gate step, consistent with how detective's cross-command hooks were verified in M041.)

**Acceptance Scenarios**:

1. **Given** `discuss` is about to flip a context draft `status: draft` → `finalized` with embedded open questions, **When** the gate returns BLOCK, **Then** `discuss` surfaces the un-dispositioned hits and does not finalize until they are resolved.
2. **Given** `comments` is about to surface an SME question packet, **When** the gate runs, **Then** `ANSWERED`-class questions are dropped from the packet with their citation recorded (P03 judge required for semantic ANSWERED; in P02 the deterministic `HITS` rows are surfaced for read-before-ask).

---

### User Story 4 — Doctor Bypass Lint (Priority: P2)

As an orchestrator maintainer, I want `orchestrator:doctor` to flag a finalized packet or plan that carries no corpus-exhaustion artifact, so that bypasses of the gate are caught.

**Why this priority**: P2 — defensive visibility. Sibling to the `DOCTOR:KNOWLEDGE_GAP` negative-space check; bundle if both land together.

**Independent Test**: Run `run-doctor.sh` against a fixture with a finalized context draft and no sibling corpus-exhaustion artifact. Verify `DOCTOR:CORPUS_EXHAUSTION status=warn` on stdout.

**Acceptance Scenarios**:

1. **Given** a finalized artifact that should have been gated but has no corpus-exhaustion sidecar, **When** the doctor check runs, **Then** it emits `DOCTOR:CORPUS_EXHAUSTION status=warn missing=<N>`.
2. **Given** every gated artifact has a sidecar, **When** the doctor check runs, **Then** it emits `DOCTOR:CORPUS_EXHAUSTION status=ok`.

---

### User Story 5 — LLM Semantic Judge + Auto-Resolve (Priority: P3, deferred)

As an agent, I want the gate to upgrade deterministic `HITS` into semantic verdicts (`ANSWERED` / `PARTIAL` / `MENTIONS`) via a batched LLM judge and auto-resolve `ANSWERED` questions out of the packet, so that only genuinely-irreducible questions survive without manual disposition.

**Why this priority**: P3 — the deterministic gate already catches the bulk by forcing read-before-ask. The judge is the automation layer; demand-driven, and the absorption-vs-standalone decision with M040 is resolved at queue-entry (see #Q-1).

**Independent Test**: With `corpus_exhaustion.intensity_floor: full` and a stubbed judge, verify a `HITS` row whose cited content answers the question is upgraded to `ANSWERED` and dropped from the surviving-questions output, with the answer + citation recorded in the artifact.

**Acceptance Scenarios**:

1. **Given** a `HITS` row whose cited content fully answers the question, **When** the judge runs, **Then** the verdict becomes `ANSWERED`, the question is dropped from the human packet, and the found answer + citation are recorded.
2. **Given** a `HITS` row whose cited content partially answers the question, **When** the judge runs, **Then** the verdict becomes `PARTIAL` and the question is rewritten to only the residual.

---

### User Story 6 — Gate Telemetry (Priority: P3, deferred)

As a maintainer, I want the gate to emit a telemetry record per run (questions checked, auto-answered, reached-human), so that the value of the gate and the size of the problem are measurable over the M019 JSONL stream.

**Independent Test**: After a gate run, verify a `corpus_exhaustion` JSONL record with counts is appended to the execution-log stream.

**Acceptance Scenarios**:

1. **Given** a completed gate run, **When** telemetry is enabled, **Then** a JSONL record records `checkpoint`, `questions_total`, `hits`, `clean`, `caveat`, and (P03+) `answered`/`partial`/`irreducible`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-1**: A deterministic sweep script reads candidate questions (one per non-blank, non-comment line; an optional leading `[id]` token is preserved as the question ID) and a store manifest, and emits a corpus-exhaustion artifact. *(P01)*
- **FR-2**: Per question, the sweep extracts search terms deterministically: structured IDs (`§N.N`, `DR-N`, `FR-N`, `SC-N`, `US-N`, `AS-N`, generic `[A-Z]{2,}-N`), ISO dates (`YYYY-MM-DD`), quoted phrases, and significant tokens (length ≥ 4, minus a stopword list). *(P01)*
- **FR-3**: The store manifest is project-configurable — never hardcoded. The sweep resolves the manifest path from config (`corpus_exhaustion.store_manifest_path`), falling back to a bundled default manifest that enumerates the standard orchestrator stores. *(P01)*
- **FR-4**: For each question the sweep searches every reachable store with case-insensitive grep, records `store · path · line` citations (capped per store with the cap noted in the artifact — no silent truncation), and assigns a verdict: `CLEAN` (zero hits), `HITS` (≥1 hit), or `IRREDUCIBLE-WITH-CAVEAT` (a configured store was unreachable). *(P01)*
- **FR-5**: The artifact carries YAML frontmatter with a top-level `verdict: PASS|BLOCK` field plus `checkpoint`, `generated_at` (caller-supplied; the script does not call `date` so runs are reproducible under test), and per-question result blocks. *(P01)*
- **FR-6**: A reusable gate adapter at `scripts/dispatch/adapters/tool/corpus-gate.sh` exposes `check` / `gate` / `parse-verdict` subcommands with the exit-code contract `0`=PASS-or-SKIPPED, `2`=BLOCK, `1`=adapter error — identical to `conversus.sh`. *(P01)*
- **FR-7**: The gate verdict is BLOCK iff at least one question row is `HITS` and not dispositioned (`disposition: dropped` or `disposition: kept`); otherwise PASS. Dispositioning forces read-before-ask: the agent reads the cited hits and either drops the answered question or keeps it as irreducible with a recorded reason. *(P01)*
- **FR-8**: Graceful degradation — when `corpus_exhaustion.enabled: false`, or the manifest is absent, the gate emits `SKIPPED:` and exits `0`; it never hard-blocks a project that has not opted in (Principle XI fail-open). A `--strict` flag / `CORPUS_GATE_STRICT=1` flips degradation off for callers that require the gate. *(P01)*
- **FR-9**: Intensity scaling — the sweep reads the active intensity tier; `quick` runs grep-only (no judge even when P03 ships), `standard`/`full` enable the judge in P03. The intensity floor is configurable (`corpus_exhaustion.intensity_floor`). *(P01 wires the read; P03 wires the judge.)*
- **FR-10**: Pre-finalize hooks — `discuss`, `comments`, `materials-intake`, `specify`, `plan-phase`, and `roadmap` document and invoke the gate before finalizing any human-facing question packet or plan, mapping BLOCK to a pause-for-disposition. *(P02)*
- **FR-11**: A `DOCTOR:CORPUS_EXHAUSTION` doctor check surfaces corpus-exhaustion artifacts left in an unresolved `BLOCK` state — a gate ran, found un-dispositioned hits, and the packet/plan was never resolved to PASS (`warn`, not `fail` — operator decides). Zero-noise on projects with no artifacts. *(P02)* — Note: detecting a finalized packet that should have had a sidecar but doesn't requires a "should-be-gated" registry; deferred (the unresolved-`BLOCK` signal is the precise, low-noise mechanical proxy that ships in P02).
- **FR-12**: A batched LLM judge upgrades `HITS` → `ANSWERED`/`PARTIAL`/`MENTIONS` and auto-resolves `ANSWERED` (drop) / `PARTIAL` (rewrite to residual), batching one call per packet (not N sub-agents at `standard`; `full` adds a per-question pass + an adversarial "which store did we NOT search?" pass). *(P03, deferred)*
- **FR-13**: Auto-promotion of an `ANSWERED` finding into a DR/memory is **default-off**; when enabled it routes the suggestion through the `comments` apply queue rather than writing the record directly. *(P03, deferred)*
- **FR-14**: The gate emits a `corpus_exhaustion` telemetry record per run over the M019 JSONL stream. *(P04, deferred)*

### Key Entities

- **Candidate question** — a single question slated for a human, with an optional stable ID. The unit the gate operates on.
- **Store manifest** — a configurable YAML list of knowledge stores (label + glob/path + optional `kind: grep|index|db`). Resolved from config; bundled default enumerates the standard orchestrator stores.
- **Corpus-exhaustion artifact** — the gate output: frontmatter verdict + per-question evidence blocks (terms, stores searched, citations, verdict, disposition). Doubles as packet provenance for the human ("here is why this question is genuinely open").

## Success Criteria *(mandatory)*

- **SC-1**: Running the sweep against a fixture corpus that answers question A and not question B produces an artifact marking A `HITS` (with citation) and B `CLEAN`. *(P01)*
- **SC-2**: The gate adapter exits `2` when an un-dispositioned `HITS` row exists and `0` when all rows are clean or dispositioned. *(P01)*
- **SC-3**: With the feature disabled or the manifest absent, the gate emits `SKIPPED:` and exits `0`; with `--strict` and a missing manifest it exits `1`. *(P01)*
- **SC-4**: An unreachable configured store yields `IRREDUCIBLE-WITH-CAVEAT` with the store named in the artifact — never a silent skip. *(P01)*
- **SC-5**: `parse-verdict` emits `verdict=PASS|BLOCK` from an existing artifact. *(P01)*
- **SC-6**: All P01 scripts are Bash 3.2-compatible and pass the repo shape-guard (no AP-00x forbidden shapes). *(P01)*
- **SC-7**: Each wired command's finalization section documents the pre-finalize gate and its BLOCK handling. *(P02)*
- **SC-8**: The doctor check emits `DOCTOR:CORPUS_EXHAUSTION status=warn` against a fixture containing an unresolved `BLOCK` artifact and `status=ok` when only `PASS` artifacts (or none) are present. *(P02)*
- **SC-9**: With a stubbed judge at `full` intensity, a `HITS` row whose cited content answers the question is upgraded to `ANSWERED` and dropped from the surviving-questions output. *(P03)*

## Constraints

- **CON-1**: Bash 3.2 / POSIX sh compatibility (CON-3 house rule) — no associative arrays, `${var,,}`, `mapfile`, or process substitution.
- **CON-2**: Configurable store manifest — never hardcode store paths; read from config so the gate works on every project regardless of layout.
- **CON-3**: Degrade gracefully when an index is broken — fall back to grep + manifest and **log what could not be searched**; never silently skip a store.
- **CON-4**: No silent truncation — if the gate caps stores, terms, or hits, it says so in the artifact.
- **CON-5**: Cost control — grep is cheap and unconditional; the LLM judge (P03) batches one call per packet, not N sub-agents; intensity-scaled (`quick` = grep-only).
- **CON-6**: Don't deadlock — an unreachable store yields `IRREDUCIBLE-WITH-CAVEAT` surfaced to the human, never a permanent hard-block.
- **CON-7**: Reproducibility under test — the sweep does not call `date`/`$RANDOM`; timestamps are caller-supplied (mirrors the M041 evaluation/roadmap reproducibility discipline).

## Non-Goals

- **NG-1**: Not a replacement for `orchestrator:conversus-gate` — it composes with it (the P03 judge is a cooperative deliberation in the conversus-gate shape), it does not supersede it.
- **NG-2**: Not the LLM judge in P01 — P01 is deterministic grep + read-before-ask enforcement. Semantic `ANSWERED` requires the P03 judge.
- **NG-3**: Not question authoring — the gate filters and provisions evidence; it does not write the questions.
- **NG-4**: Not auto-mutation of the decision record — `ANSWERED`→DR promotion is default-off and human-gated through `comments` when enabled (FR-13).
- **NG-5**: Not a new enforcement primitive — reuses the conversus-gate / `BG-###` / verify-ladder gate-artifact convention.

## Open Questions

- **#Q-1 (M040 absorption)**: P03's batched-judge + PASS|BLOCK + human-gated-apply plumbing overlaps strongly with M040's decision-contradiction gate (two-agent conversus sweep on every `DECISIONS.md` write). Resolve standalone-vs-absorbed at the same time as the M034/M038/M040 decision-packet-family absorption decision. P01/P02 do not depend on the resolution.
- **#Q-2 (artifact format)**: Markdown (human-readable SME provenance) vs JSONL (machine-queryable telemetry) vs both. P01 ships Markdown-with-frontmatter as source-of-truth; P04 may add a JSONL projection. Likely endpoint: JSONL source + rendered Markdown projection (the M019→surface pattern).
- **#Q-3 (judge false-negative)**: A judge that wrongly marks a genuinely-open question `ANSWERED` hides it from the human. Mitigation: the artifact records the cited answer (auditable after the fact); `full` adds the adversarial which-store-not-searched pass; a confidence-threshold knob downgrades low-confidence `ANSWERED` to `PARTIAL` so the residual still reaches the human. Resolve at P03.
