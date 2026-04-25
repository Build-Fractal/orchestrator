---
schema_version: "1.0"
type: roadmap
milestone: "M014"
feature_ref: "024-spec-management-extended"
feature_spec: "specs/024-spec-management-extended/spec.md"
vision: "Ship native orchestrator:specify + AGENTS.md dual-write parity + comment→workflow classifier with human-gated review queue + conversus auto-propose for risky drafts — closing the M015 bootstrapping loop so every future milestone's spec is orchestrator-authored."
tier: "C"
created_at: "2026-04-22T16:30:00Z"
updated_at: "2026-04-22T16:30:00Z"
---

## Phases

- [x] **P01**: Native `orchestrator:specify` create-path + minimal dual-write — "A maintainer runs `orchestrator:specify --description '<prose>' --slug <slug>` on a clean project; a new `specs/<NNN>-<slug>/spec.md` lands passing `spec-shape-lint.sh`, and `AGENTS.md` gets a marker-bounded Recent Changes region byte-equivalent to `CLAUDE.md`'s."
  - Risk: high
  - Depends: none
  - Boundary Map:
    - Produces:
      - `commands/specify.md` (command definition with `specify`, `--amend`, `split` subcommand surface; `split` stub lands here, full decomposition flow in P04)
      - `templates/spec-template.md` — Section Contract SSOT (FR-2b)
      - `templates/spec-scaffolder-prompt.md` — CC LLM round-trip prompt (FR-3)
      - `scripts/verify/spec-shape-lint.sh` — FR-4 verifier consumed by `orchestrator:discuss` preflight
      - `scripts/util/dual-write-runtime-md.sh` — FR-12 marker-bounded dual-write helper (full helper surface ships here; P02 extends invocation sites only)
      - `scripts/knowledge/spec-complexity-probe.sh` — FR-5 stub emitting `probe=below-threshold` unconditionally (full probe logic in P04); consumed by `orchestrator:specify` end-of-scaffold so the prompt wiring ships but no-ops until P04
      - `tests/test-specify-shape.sh` — FR-18 byte-compat fixture against `templates/spec-template.md`
      - `tests/test-dual-write-outside-invariant.sh` — SC-6a outside-markers shasum invariant
      - `.orchestrator/config.yml` — new `specify:` section + top-level `dual_write_agents:` key (FR-17, partial)
      - `AGENTS.md` — marker-bounded `orchestrator:recent-changes` region populated by `orchestrator:specify` write-site only
      - `RUNTIME-ASSUMPTIONS.md` — entries for FR-3 (LLM scaffolder) and FR-5 contradiction-signal (stubbed under CC only)
      - `references/spec-management.md` — Section Contract + dual-write marker convention (partial; P04 completes with pressure-test + decomposition sections)
      - `execution-log.jsonl` events — `unit_close` records with `{specs_scaffolded, dual_writes, elapsed_ms}` per FR-16
    - Consumes:
      - `scripts/knowledge/detect-spec-shape.sh` (M011) — SC-2 `shape=speckit` I/O-contract assertion
      - `scripts/knowledge/ingest-spec.sh` (M011) — SC-2 fast-path verification
      - `scripts/lifecycle/lock-manager.sh` (existing) — spec-number race mitigation per Edge Case
      - `scripts/dispatch/dispatch-interface.sh` (existing) — CC LLM round-trip for FR-3 scaffolder
      - `scripts/verify/anti-pattern-lint.sh` (existing) — CON-6 / SC-9 gate
      - `.orchestrator/execution-log.jsonl` (M019 Tier 1 emitter, shipped) — FR-16 append path

- [x] **P02**: Dual-write discipline extended to all `CLAUDE.md` write-sites + drift detector — "A maintainer runs `orchestrator:init` and `orchestrator:consolidate` on a fresh project; both commands dual-write to `CLAUDE.md` and `AGENTS.md` via the FR-12 helper, and `scripts/verify/check-docs.sh` reports zero drift between the two surfaces across every enumerated write-site."
  - Risk: medium
  - Depends: P01
  - Boundary Map:
    - Produces:
      - Dual-write invocations patched into `commands/init.md`, `commands/consolidate.md`, and knowledge-update Recent Changes appenders (OQ/#C-11 exhaustive write-site enumeration runs at plan time and commits the list to the phase plan as a must-have checklist)
      - `scripts/verify/check-docs.sh` extended with `runtime_instruction_drift` detection pass (FR-13) — detects missing region in one file, byte-divergence within matching regions, markers present in one file only
      - `orchestrator:doctor` — new `runtime_instruction_drift` output section surfacing FR-13 findings
      - `AGENTS.md` — marker-bounded regions populated at every enumerated write-site (init, consolidate, knowledge Recent Changes)
      - `execution-log.jsonl` events — `unit_close` records with `{dual_writes, drift_findings}` per FR-16
      - (Conditional, planning-decided per OQ/#C-5) A documented transform function in `scripts/util/dual-write-runtime-md.sh` if planning picks transform-based over byte-identical dual-write
    - Consumes:
      - `scripts/util/dual-write-runtime-md.sh` (P01)
      - `templates/spec-template.md` (P01 — only insofar as recent-changes region references specify-authored specs)
      - `commands/init.md`, `commands/consolidate.md` (existing, patched)
      - `scripts/verify/check-docs.sh` (existing M006 docs diagnostic, extended)

- [x] **P03**: Comment→workflow classifier + human-gated spec-amendment apply path — "A maintainer runs `orchestrator:comments classify`; the command fetches unactioned Giscus + GitHub Issue/PR comments, classifies each into one of `{uat-bug, decision-append, spec-amendment, ambiguous}`, auto-applies the two trivial classes above threshold, queues spec-amendments for human sign-off, and routes ambiguous comments through the M011/P07 conversus adapter — running `orchestrator:comments apply <id>` on an approved queue item edits the target spec atomically."
  - Risk: high
  - Depends: P01
  - Preflight (external, operator-gated — see D023):
    - M012/P04 wiki DEPLOY-RECORD: **RESOLVED 2026-04-23** (all four gates PASS, site live at `https://Build-Fractal.github.io/spec-kit-orchestrator/`).
    - `specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md`: **RELAXED per D023** — original SC-16 ≥1 week organic inbox data target deferred. FR-9 classifier shape pins on best-available signal at plan time (regex/heuristic v1 baseline) with explicit retune commitment after meaningful comment volume accumulates.
  - Phase-entry gate (CONTEXT OQ-4): dispatcher refuses P03 task dispatch on stubbed DEPLOY-RECORD sentinels with a clear error; this gate remains the load-bearing enforcement for the wiki preflight.
  - Boundary Map:
    - Produces:
      - `commands/comments.md` — user-facing surface with `classify`, `status`, `apply`, `reject`, `triage`, `reclassify` subcommands
      - `scripts/comments/fetch.sh` (FR-8) — Giscus + GitHub Issue/PR unactioned-comment fetcher with URL+shasum idempotency key
      - `scripts/comments/classify.sh` (FR-9) — classifier whose shape is pinned at plan-phase per OQ #C-1 (regex/heuristic, embedding-distance, LLM-call-per-comment, or two-pass hybrid)
      - `scripts/comments/apply.sh`, `scripts/comments/reject.sh`, `scripts/comments/triage.sh` — action surfaces (US-5 spec-amendment apply path is the single spec-mutation gate)
      - `.orchestrator/comments/inbox/<comment-id>.json` — fetched-comment cache convention
      - `.orchestrator/comments/review-queue/<queue-id>.md` — queued-item convention per FR-11 (frontmatter: `comment_url`, `class`, `confidence`, `proposed_action`, `queued_at`, `queue_id`)
      - `.orchestrator/comments/actioned.jsonl` — append-only idempotency log
      - `.orchestrator/config.yml` — new `comments:` section (`auto_apply_threshold:` per-class, `reply_on_apply:`, `fetch_schedule:` per OQ #C-2)
      - `specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md` — ≥1 week M012/M013 inbox dogfood-data table (SC-16); captured before plan-phase pins FR-9 classifier shape
      - `RUNTIME-ASSUMPTIONS.md` — FR-9 entry (conditional — populated only if planning pins an LLM-based classifier shape)
      - `execution-log.jsonl` events — `comment_actioned` records with `{comment_url, class, confidence, action_taken, source_surface}` per FR-10
    - Consumes:
      - `scripts/wiki/wiki-giscus-remap.sh` (M012) — Giscus Discussion → spec-chunk pathname-keyed thread mapping
      - `scripts/integrations/github-common.sh` (M013/P04, closed) — GitHub Issue/PR comment surface + orchestrator-id marker convention
      - `scripts/dispatch/adapters/tool/conversus.sh` (M011/P07, shipped) — ambiguous-comment triage with `--strict` per M013/FR-13
      - `knowledge/spec/defect/SPEC-DEFECT-NNN.md` schema (M013/FR-10 UAT ingestion path) — auto-apply target for `uat-bug` class
      - `scripts/knowledge/rebuild-index.sh` (M011) — chunk re-version trigger on US-5 spec-amendment apply
      - `.orchestrator/DECISIONS.md` append format (existing; M020 forward-compat per Knowledge-Layer Boundary)
      - **Preflight gate**: `.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md` with all `pending` sentinels resolved (M012 wiki first-deploy complete). Phase-entry gate blocks dispatch on stubbed DEPLOY-RECORD sentinels with a clear error (per CONTEXT OQ-4).

- [x] **P04**: Conversus auto-propose + complexity probe + spec-pressure-test preset — "A maintainer runs `orchestrator:specify --description '<contradictory prose>'` on a draft whose FR-5 probe fires `above-threshold`; the command prints the three-way `y/n/d` prompt; on `y`, the M011/P07 conversus adapter runs `spec-pressure-test` and lands `conversus/summary/final.md`; on `d`, `orchestrator:specify split` produces a decomposition manifest; on `n`, the scaffold exits zero unmodified."
  - Risk: medium
  - Depends: P01
  - Boundary Map:
    - Produces:
      - `scripts/knowledge/spec-complexity-probe.sh` — full FR-5 probe (replaces P01 stub): FR count, user-story count, raw token count, `<TODO>` placeholder density, contradiction-signal count (LLM-derived under CC runtime, zero under Codex/Cursor per CON-2); emits single-line verdict + structured fields
      - `templates/conversus-presets/spec-pressure-test.yml` — FR-6 preset consumed by `scripts/dispatch/adapters/tool/conversus.sh` without adapter modification (D007 reuse discipline)
      - `orchestrator:specify` three-way prompt wiring (US-3 `y/n/d`) — `y` invokes adapter with `--strict`, `d` invokes splitter, `n` exits clean
      - `orchestrator:specify split` subcommand — LLM-assisted splitter (CC only v1) producing 2–N sub-spec manifest
      - `.orchestrator/specify/decomposition/<source-id>/manifest.md` — interim path per FR-7 (migrates to `.orchestrator/intake/<id>/decomposition.md` when M024 lands; schema write-forward-compatible)
      - `RUNTIME-ASSUMPTIONS.md` — entries for FR-5 contradiction-signal LLM pass (replaces P01 stub entry) + FR-7 splitter
      - `references/spec-management.md` — pressure-test + decomposition sections (completes SC-11)
      - `execution-log.jsonl` events — `spec_complexity_probe` + `conversus_gate_invocation` records with `{gate_id: "spec-pressure-test", adapter_version, verdict, llm_calls, elapsed_ms, estimated_cost_usd}` per FR-16
      - Pinned complexity-probe thresholds in `.orchestrator/config.yml` (`specify.complexity_thresholds:`) informed by the CONTEXT calibration corpus (M011/M013/M016/M021 retrospective labels) + FR-count/story ratio + hardening-spec special criterion
    - Consumes:
      - `scripts/dispatch/adapters/tool/conversus.sh` (M011/P07, shipped) — `gate spec-pressure-test <spec> <output>` with `--strict`
      - `commands/specify.md` (P01) — prompt integration point
      - `scripts/knowledge/spec-complexity-probe.sh` (P01 stub — replaced with full implementation)
      - `scripts/dispatch/dispatch-interface.sh` (existing) — CC LLM round-trip for FR-7 splitter

## Cross-Cutting Concerns

- **Observability (FR-16) — M019 Tier 1 producer discipline** — touches P01, P02, P03, P04. P01 establishes the per-command `unit_close` emission pattern (command name, per-run counters, `elapsed_ms`, `source: "runtime"`); P02/P03/P04 conform. P04 adds `conversus_gate_invocation` records matching M013/FR-17 shape. M019 owns schema evolution; every phase is a producer only.

- **Idempotency (CON-8)** — touches P01, P02, P03, P04. P01 establishes: slug-collision-errors-loudly + atomic temp-file-then-rename + `shasum` byte-preservation outside markers (pattern inherited from M012/P04 `mkdocs.yml` splice). P02 extends marker-bounded writes to every enumerated write-site. P03 honors URL+shasum idempotency key on `actioned.jsonl` (mirror of M013/FR-4). P04 preserves deliberation state on `--amend` re-probe.

- **Bash 3.2 / anti-pattern lint (CON-6 + DC-2 + MEM001 compat scan)** — touches P01, P02, P03, P04. Every new shell script passes `scripts/verify/anti-pattern-lint.sh` and runs under Bash 3.2 (no associative arrays, no `${var,,}`, no `mapfile`). SC-9 is the milestone-close gate. No phase may introduce a bash 4+ dependency.

- **Zero approval prompts in auto mode (CON-3 + FR-15)** — touches P01, P02, P03, P04. Every new command supports `--dry-run` (FR-19 JSONL manifest shape) and `--yes` auto-resolution for interactive prompts. SC-7 verified against the M021 prompt-corpus fixture at milestone close.

- **CC-first runtime posture + `RUNTIME-ASSUMPTIONS.md` registry (CON-2 + DC-6)** — touches P01 (FR-3 scaffolder, FR-5 stub), P03 (FR-9 classifier if LLM-based), P04 (FR-5 full contradiction signal, FR-7 splitter). Every CC-only path lands a registry entry for M009 runtime-parity-audit consumption. Codex/Cursor runtimes fall back to non-LLM mode (skeleton scaffold, heuristic-only classifier, zero contradiction-signal count) — never silently degraded.

- **Human-gated spec mutation (CON-5 + DC-5 + Principle III+XIV)** — primary on P03 (US-5 apply path is the single spec-mutation gate; `spec-amendment` class is never auto-applied regardless of confidence score; SC-5 verifies zero auto-apply in `actioned.jsonl`). P04 adds the AS-7 discipline (`--amend` preserves prior deliberation; no re-probe on unchanged sections).

- **Marker-bounded shasum byte-preservation (Constitution XV)** — touches P01 (dual-write helper ships with invariant enforced at the `recent-changes` region), P02 (extension to every enumerated write-site inherits the invariant). SC-6a is the mechanical expression; `tests/test-dual-write-outside-invariant.sh` (P01 deliverable) is the enforcer. Outside-markers bytes cannot drift regardless of write being made.

- **Conversus adapter integration (DC-3 + CON-4 + Principle XII)** — touches P03 (ambiguous-comment triage with `classify-comment` preset), P04 (spec pressure-test with `spec-pressure-test` preset). Both invoke `scripts/dispatch/adapters/tool/conversus.sh --strict` only; no direct `/conversus` CLI calls; no adapter modifications. Adapter absence under strict mode fails loudly per M013/FR-13 precedent (exit 0 PASS → proceed; 0 SKIPPED → warn + proceed; 2 BLOCK → record + surface; 1 ERROR → halt).

- **Knowledge-Layer Boundary (M014 vs. M020)** — touches P03 only. M014 writes to knowledge at exactly one new point: `decision-append` auto-apply (FR-10) → `.orchestrator/DECISIONS.md` append. `uat-bug` auto-apply routes through M013/FR-10's existing UAT-ingestion → `knowledge/spec/defect/SPEC-DEFECT-NNN.md` (consumer, not author). Spec-amendment re-versions chunks via M011 ingest path (consumer). No new chunk-ID format. M020 retains authority over `knowledge/spec/**` schema evolution.

## Dependency Graph

```
            ┌─→ P02 (dual-write full + drift detector)
            │
  P01 ──────┼─→ P03 (comment classifier + US-5 apply)    [+ ext preflight: M012 wiki deploy]
            │
            └─→ P04 (conversus auto-propose + probe + preset)

Legend: P02, P03, P04 are parallelizable once P01 ships.
        P03 carries an additional external preflight gate
        (M012/P04 DEPLOY-RECORD sentinels resolved) checked
        at phase-entry dispatch time.
```

## Execution Order

1. **P01** — foundation, no dependencies. Ships the Section Contract template, the `orchestrator:specify` create-path, the FR-12 dual-write helper, the FR-4 shape linter, the FR-18 byte-compat fixture, and the FR-5 probe stub. Load-bearing for every subsequent orchestrator-authored spec (SC-13 dogfood gate). **High risk** — every downstream phase of this milestone and every future milestone's spec depends on P01's shape contract being correct first time.
2. **P02, P03, P04 — can execute concurrently** once P01 ships. All three depend only on P01 (P02 extends the helper's call sites; P03 consumes P01's command surface indirectly — the classifier itself operates on any spec, hand-authored or scaffolded; P04 extends the probe stub and wires the conversus prompt into `orchestrator:specify`). No cross-dependencies among P02/P03/P04.
   - **P03 has an additional external preflight**: M012 wiki first-deploy must complete (DEPLOY-RECORD sentinels resolved) before P03 dispatches its first task. Operator completes the M012 checklist in parallel with P01/P02/P04 per CONTEXT §M012 Wiki Deploy Posture.
   - For Tier C autonomous dispatch: once P01 is green, the dispatcher may start P02 + P04 immediately; P03 queues until M012 DEPLOY-RECORD preflight passes. In practice, this means P02 + P04 will likely close before P03 — acceptable because none of them blocks each other.

## Validation

- **No conflicting producers**: **PASS**
  - `scripts/util/dual-write-runtime-md.sh` is authored entirely by P01 (full helper surface); P02 only adds invocation sites at pre-existing commands — not a second producer of the script itself.
  - `scripts/knowledge/spec-complexity-probe.sh` ships as a stub in P01 (returns `probe=below-threshold` unconditionally) and is replaced with the full implementation in P04. The stub→full transition is intentional and declared; no two phases claim the same shape at the same time.
  - `RUNTIME-ASSUMPTIONS.md` is append-only across phases: P01 adds FR-3 + FR-5-stub entries, P03 conditionally adds FR-9, P04 adds FR-5-full (replacing the P01 stub entry) + FR-7. Append-only registries are not conflicting producers.
  - `references/spec-management.md` is partial in P01 (Section Contract + dual-write marker convention) and completed in P04 (pressure-test + decomposition sections). SC-11 is a milestone-close gate, not a phase-local one.
  - `.orchestrator/config.yml` new keys are additive across phases (P01: `specify:` + `dual_write_agents:`; P03: `comments:`). Different sections, no conflict.
  - No two phases produce the same artifact at the same stage.

- **All consumed items have producers**: **PASS**
  - P02 `scripts/util/dual-write-runtime-md.sh` ← P01 ✓
  - P03 M012 wiki-giscus-remap + M013 github-common + M011/P07 conversus adapter — all external milestones shipped/closed per CONTEXT ✓
  - P03 M012 DEPLOY-RECORD preflight — external operator gate, declared explicitly in CONTEXT §M012 Wiki Deploy Posture ✓
  - P04 M011/P07 conversus adapter (shipped) + P01 commands/specify.md (P04 wires prompt into the command) + P01 probe stub (P04 replaces) ✓
  - All M011/M012/M013/M019/M016/M021 dependencies declared in spec §Dependencies and confirmed shipped in CONTEXT ✓
  - No unresolved `Consumes` entries.

- **DAG is acyclic**: **PASS**
  - P01 has no in-edges.
  - P02, P03, P04 each have exactly one in-edge (from P01).
  - No back-edges; no edges among P02/P03/P04.
  - Trivially a directed acyclic graph (3-leaf fan-out from P01).

- **Demo sentence coverage**: **PASS**
  - P01 demo: concrete command invocation (`orchestrator:specify --description ... --slug ...`), concrete artifact (`specs/<NNN>-<slug>/spec.md`), concrete verifier (`spec-shape-lint.sh`), concrete invariant (AGENTS.md marker-bounded region byte-equivalent to CLAUDE.md's). Testable end-to-end.
  - P02 demo: concrete commands (`orchestrator:init`, `orchestrator:consolidate`), concrete invariant (zero drift via `check-docs.sh`). Testable end-to-end.
  - P03 demo: concrete command (`orchestrator:comments classify`), concrete classifier shape (four classes), concrete trivial-class auto-apply boundary, concrete spec-amendment human-gate, concrete conversus-adapter triage path, concrete apply flow on approved queue item. Testable end-to-end.
  - P04 demo: concrete probe verdict (`above-threshold`), concrete three-way prompt (`y/n/d`), concrete artifact per path (`conversus/summary/final.md` on `y`; decomposition manifest on `d`; clean exit on `n`). Testable end-to-end.
  - All four demos name observable artifacts or verifiable state — none are vague "feature works" descriptions.
