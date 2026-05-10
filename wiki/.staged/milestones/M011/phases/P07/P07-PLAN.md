---
schema_version: "1.0"
type: phase-plan
phase: "P07"
milestone: "M011"
goal: "Make orchestrator:ingest format-agnostic: detect whether the input markdown is already spec-kit-shaped, LLM-normalize it when it is not, and gate the normalized artifact at Standard+ intensity through a reusable two-agent Conversus fidelity deliberation before the P02/P03 deterministic chunker runs."
demo_sentence: "A developer runs `orchestrator:ingest --spec-path ~/Downloads/random-prd.md --slug 019-foo` on a non-spec-kit-shaped markdown file; the command detects the shape mismatch, invokes an agent-driven normalizer that writes a spec-kit-shaped `specs/019-foo/spec.md`, then at Standard+ (or with `--review`) runs the Conversus fidelity gate (`/conversus gate normalize specs/019-foo/spec.md`, source-advocate vs target-advocate) which emits `gate-result.md` with a `PASS | BLOCK` verdict — only PASS (or `--force`) lets the deterministic chunker from P02/P03 run."
risk: "medium"
depends_on: [P06]
---

## Must-Haves

<!-- Every Truth Check: is a single-script-file invocation per AD-19.
     The verify scripts themselves may use whatever internal bash they
     need; the single-script-file constraint only applies to the
     Check: lines below. -->

### Truths

- `scripts/knowledge/detect-spec-shape.sh` exists and emits `shape=speckit|foreign` plus `reasons=<csv>` to stdout for any markdown file passed via `--spec-path`, using heading-pattern probes (`## User Stories`, `## Functional Requirements`, `FR-NNN`, `US-NNN`, `Given/When/Then`, `## Acceptance Criteria`) that match the P02 classifier's recognition vocabulary. Exits 0 on `shape=speckit` and 0 on `shape=foreign` (both are valid outcomes); exits 1 only on missing/unreadable input.
  - Check: `bash scripts/verify/m011-p07-shape-detect.sh`
- `scripts/knowledge/normalize-spec.sh` exists and is a thin bash wrapper that resolves the active runtime (via `scripts/state/resolve-runtime.sh` or equivalent), dispatches the normalizer to the configured agent using `templates/spec-normalizer-prompt.md` as the prompt body, and writes the agent's normalized markdown to `specs/<slug>/spec.md` via a deterministic temp-file-then-rename (`.normalized.$$.tmp` → `specs/<slug>/spec.md`) so readers never observe a half-written file. The script itself contains no hardcoded LLM HTTP calls — all agent I/O is through the runtime adapter dispatch interface (`scripts/dispatch/dispatch-interface.sh`).
  - Check: `bash scripts/verify/m011-p07-normalize-wrapper-shape.sh`
- `templates/spec-normalizer-prompt.md` exists as a full prompt template with `schema_version: "1.0"` + `type: normalizer-prompt` frontmatter. The body instructs the agent: (a) preserve every factual claim, requirement, non-goal, constraint, and acceptance criterion from the source document verbatim where possible; (b) emit the normalized output in the same section layout `commands/ingest.md` already expects (`## User Stories`, `## Functional Requirements`, `## Acceptance Scenarios`, `## Constraints`, `## Non-Goals`, `## Success Criteria`); (c) introduce no new requirements that are not derivable from the source; (d) preserve source quotes verbatim when the source already states a requirement in a well-formed way.
  - Check: `bash scripts/verify/m011-p07-normalizer-template.sh`
- `scripts/knowledge/normalize-spec.sh` is idempotent: running it twice on the same unchanged source markdown with the same `--slug` either (a) detects the existing normalized artifact under `specs/<slug>/spec.md` and exits with a `SKIPPED:` line without re-dispatching to the agent, or (b) detects a content-hash match between the existing normalized artifact's `source_hash:` frontmatter field and the current source hash and exits with `SKIPPED:`. Re-run with `--force` bypasses the hash check and re-dispatches.
  - Check: `bash scripts/verify/m011-p07-normalize-idempotent.sh`
- `scripts/dispatch/adapters/tool/conversus.sh` exists as a reusable tool-adapter following the filename-routed adapter auto-discovery pattern (MEM008, MEM018) under `scripts/dispatch/adapters/tool/`. It exposes three operations: `check` (prints `available=true|false` based on whether the `conversus` binary is resolvable on `PATH` or at `CONVERSUS_HOME` / `~/Sites/conversus`), `gate <preset> <artifact-path> <output-path>` (invokes `/conversus gate <preset> <artifact>` via CLI and writes `gate-result.md` to `<output-path>`, returning exit 0 on PASS / 2 on BLOCK / 1 on adapter error), and `parse-verdict <gate-result-path>` (emits `verdict=PASS|BLOCK` to stdout). When `available=false`, `gate` prints a `SKIPPED:` line explaining the missing dependency and exits 0 — callers interpret this as graceful degradation, not a hard failure (roadmap explicit: external dependency, not a hard blocker).
  - Check: `bash scripts/verify/m011-p07-conversus-adapter-shape.sh`
- `commands/conversus-gate.md` exists and documents the reusable two-agent cooperative deliberation protocol (source-advocate vs target-advocate, with a neutral arbiter grounded in `.orchestrator/memory/constitution.md`). The command doc follows MEM012 conventions: YAML frontmatter with `description`, a top-level title, a Prerequisites section naming `scripts/dispatch/adapters/tool/conversus.sh`, a Usage section naming the `normalize-fidelity` preset and the arbitrary-preset extension point (M013/[M014](../../../../milestones/M014/index.md) will invoke this same adapter with their own presets), a Workflow section with numbered steps, an Idempotency section (same artifact + same preset → same verdict cached in `gate-result.md`), an Error Handling section (conversus binary missing, preset missing, timeout), and a Reference Files section pointing at the tool adapter, the preset template, and the gate-result template.
  - Check: `bash scripts/verify/m011-p07-conversus-doc-structure.sh`
- `templates/conversus-presets/normalize-fidelity.yml` exists as a YAML preset declaring the two-agent cooperative deliberation: `source-advocate` (system prompt focused on "does the normalized spec preserve every factual claim, requirement, AC, constraint, and non-goal from the source?"), `target-advocate` (system prompt focused on "does the normalized spec fit the spec-kit shape cleanly, without introducing new requirements?"), a neutral arbiter grounded in `.orchestrator/memory/constitution.md`, and a verdict-emission contract pointing at `templates/gate-result.md`. The preset file must have `schema_version:` and `type: conversus-preset` frontmatter.
  - Check: `bash scripts/verify/m011-p07-conversus-preset.sh`
- `templates/gate-result.md` exists as the canonical gate-result artifact shape: YAML frontmatter with `schema_version: "1.0"`, `type: gate-result`, `preset: "{{preset}}"`, `artifact: "{{artifact_path}}"`, `verdict: "{{PASS|BLOCK}}"`, `timestamp: "{{iso_8601}}"`, `source_hash: "{{hash}}"`, and a body with a `## Disputes` section (markdown list of structured dispute entries) plus a `## Rationale` section.
  - Check: `bash scripts/verify/m011-p07-gate-result-template.sh`
- `scripts/engine/intensity-gate.sh` registers an `ingest` stage with the substep vocabulary `normalize | fidelity-gate | force-chunker` and the policy matrix: Quick → `execute="normalize"` / `skip="fidelity-gate"`; Standard → `execute="normalize,fidelity-gate"` / `skip="none"`; Full → `execute="normalize,fidelity-gate"` / `skip="none"`. A `--review` flag on `orchestrator:ingest` forces `fidelity-gate` into `execute_substeps` regardless of resolved intensity; a `--no-review` flag forces it into `skip_substeps`.
  - Check: `bash scripts/verify/m011-p07-intensity-ingest-stage.sh`
- `commands/ingest.md` (updated from P06) documents the new pre-chunker pipeline: `detect-shape → normalize-if-foreign → fidelity-gate-if-enabled → chunker`. New flags documented: `--review` (force fidelity gate on regardless of intensity), `--no-review` (force off), `--force` (bypass a BLOCK verdict and run the chunker anyway, recorded in the ingest log). The document explicitly states that when the gate returns BLOCK the chunker does NOT run unless `--force` is passed, and that the normalized artifact is always written to `specs/<slug>/spec.md` for human review before chunker invocation so the developer can audit the normalization output even on BLOCK. All prior P06 Reference File bullets are preserved.
  - Check: `bash scripts/verify/m011-p07-ingest-doc-updates.sh`
- `scripts/verify/m011-p07-e2e-arbitrary-spec.sh` runs the full format-agnostic pipeline against a sandbox fixture of a *foreign-shaped* markdown PRD (one that does NOT match spec-kit heading patterns): stands up a throwaway `PROJECT_ROOT=$(mktemp -d)` with EXIT-trap cleanup, copies the foreign-PRD fixture into `~/Downloads/random-prd.md`-style path, invokes `orchestrator:ingest` (via `ingest-spec.sh` equivalent) with `--spec-path <fixture> --slug 019-foo --no-review` (to skip the gate in the CI-style run) and asserts: (a) `detect-spec-shape.sh` emits `shape=foreign`; (b) `normalize-spec.sh` writes a spec-kit-shaped artifact to `specs/019-foo/spec.md`; (c) the downstream chunker produces non-zero `spec/*` chunks; (d) the run completes in under 120 seconds (higher than P06's 60s because the normalize step involves agent dispatch). When the CI environment has no runtime capable of agent dispatch, the script MUST accept a `NORMALIZER_STUB=1` env var that bypasses the live agent call and uses a canned normalized-output fixture, so the e2e gate runs deterministically in regression mode. Exits 0 on success.
  - Check: `bash scripts/verify/m011-p07-e2e-arbitrary-spec.sh`
- `scripts/verify/m011-p07-gate-pass-block.sh` exercises the Conversus adapter in both PASS and BLOCK modes using a `CONVERSUS_STUB=1` env var that short-circuits the real conversus binary with two canned `gate-result.md` fixtures (one with `verdict: "PASS"`, one with `verdict: "BLOCK"`). Asserts: (a) PASS fixture → adapter exits 0 and `orchestrator:ingest` proceeds to chunker; (b) BLOCK fixture → adapter exits 2 and `orchestrator:ingest` skips the chunker unless `--force` is passed; (c) `--force` after BLOCK runs the chunker and records a `FORCE:` line in the ingest log.
  - Check: `bash scripts/verify/m011-p07-gate-pass-block.sh`
- `scripts/verify/m011-p07-intensity-policy.sh` asserts the ingest-stage policy matrix: calls `intensity-gate.sh --stage ingest --intensity Quick`, asserts `execute_substeps=normalize` and `skip_substeps=fidelity-gate`; asserts Standard emits `execute_substeps=normalize,fidelity-gate`; asserts Full emits the same as Standard. Also asserts the `--review` override promotes `fidelity-gate` to `execute_substeps` when the resolved intensity is Quick (the override is documented in `commands/ingest.md`; this script verifies the documented override is reachable, not that `intensity-gate.sh` itself reads `--review` — the flag is resolved by `commands/ingest.md`).
  - Check: `bash scripts/verify/m011-p07-intensity-policy.sh`
- All new P07 scripts pass `bash -n` under Bash 3.2 and do not use `declare -A`, `mapfile`, `readarray`, or `<(...)` process substitution. BSD grep safety: any token that may begin with `-` is matched via `grep -Fq -- "$tok"` (MEM012 pattern, extended in P06).
  - Check: `bash scripts/verify/m011-p07-bash32-compat.sh`
- `.orchestrator/milestones/M011/phases/P07/evidence/` contains the dogfood transcript from running the format-agnostic pipeline on a fixture foreign-shaped PRD (committed under `tests/fixtures/arbitrary-prd.md`), including: `detect-shape.txt` (shape=foreign + reasons), `normalize-transcript.txt` (at least one `NORMALIZED:` or `SKIPPED:` line), `gate-result.md` (full PASS artifact with disputes + rationale), `chunker-transcript.txt` (at least one `CREATED:` line from the downstream ingest-spec.sh run), and `timing.txt` (a single integer `elapsed_seconds=<N>` line where N < 120).
  - Check: `bash scripts/verify/m011-p07-evidence-present.sh`
- `commands/ingest.md`, `commands/evaluate.md`, and `commands/roadmap.md` preserve every previously-listed Reference File bullet from P06 — P07 edits to `commands/ingest.md` (adding `--review`, `--no-review`, `--force`-after-BLOCK semantics, and the tool-adapter + preset reference) must not delete any prior bullet.
  - Check: `bash scripts/verify/m011-p07-commands-preserve-references.sh`

### Artifacts

- `scripts/knowledge/detect-spec-shape.sh` (min 50 lines, contains "shape=")
- `scripts/knowledge/normalize-spec.sh` (min 80 lines, contains "NORMALIZED:")
- `templates/spec-normalizer-prompt.md` (min 60 lines, contains "normalizer-prompt")
- `scripts/dispatch/adapters/tool/conversus.sh` (min 80 lines, contains "available=")
- `commands/conversus-gate.md` (min 90 lines, contains "source-advocate")
- `templates/conversus-presets/normalize-fidelity.yml` (min 40 lines, contains "target-advocate")
- `templates/gate-result.md` (min 25 lines, contains "verdict:")
- `commands/ingest.md` (min 140 lines, contains "--review")
- `scripts/engine/intensity-gate.sh` (min 150 lines, contains "ingest)")
- `tests/fixtures/arbitrary-prd.md` (min 30 lines, contains "Problem")
- `.orchestrator/milestones/M011/phases/P07/evidence/detect-shape.txt` (min 1 line, contains "shape=foreign")
- `.orchestrator/milestones/M011/phases/P07/evidence/normalize-transcript.txt` (min 1 line, contains "NORMALIZED:")
- [`.orchestrator/milestones/M011/phases/P07/evidence/gate-result.md`](../../../../milestones/M011/phases/P07/evidence/gate-result.md) (min 10 lines, contains "verdict:")
- `.orchestrator/milestones/M011/phases/P07/evidence/chunker-transcript.txt` (min 1 line, contains "CREATED:")
- `.orchestrator/milestones/M011/phases/P07/evidence/timing.txt` (min 1 line, contains "elapsed_seconds=")
- `scripts/verify/m011-p07-shape-detect.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p07-normalize-wrapper-shape.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p07-normalizer-template.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p07-normalize-idempotent.sh` (min 25 lines, contains "PASS")
- `scripts/verify/m011-p07-conversus-adapter-shape.sh` (min 25 lines, contains "PASS")
- `scripts/verify/m011-p07-conversus-doc-structure.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p07-conversus-preset.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p07-gate-result-template.sh` (min 20 lines, contains "PASS")
- `scripts/verify/m011-p07-intensity-ingest-stage.sh` (min 25 lines, contains "PASS")
- `scripts/verify/m011-p07-ingest-doc-updates.sh` (min 25 lines, contains "PASS")
- `scripts/verify/m011-p07-e2e-arbitrary-spec.sh` (min 70 lines, contains "PASS")
- `scripts/verify/m011-p07-gate-pass-block.sh` (min 45 lines, contains "PASS")
- `scripts/verify/m011-p07-intensity-policy.sh` (min 30 lines, contains "PASS")
- `scripts/verify/m011-p07-bash32-compat.sh` (min 15 lines, contains "PASS")
- `scripts/verify/m011-p07-evidence-present.sh` (min 30 lines, contains "PASS")
- `scripts/verify/m011-p07-commands-preserve-references.sh` (min 25 lines, contains "PASS")
- `docs/ingesting-arbitrary-specs.md` (min 80 lines, contains "BLOCK")

### Key Links

- `commands/ingest.md` → `scripts/knowledge/detect-spec-shape.sh` (ingest.md documents the pre-chunker shape probe)
- `commands/ingest.md` → `scripts/knowledge/normalize-spec.sh` (ingest.md documents the normalize step for foreign-shaped input)
- `commands/ingest.md` → `scripts/dispatch/adapters/tool/conversus.sh` (ingest.md references the reusable fidelity-gate adapter)
- `commands/ingest.md` → `commands/conversus-gate.md` (ingest.md cross-links the reusable conversus-gate command doc)
- `commands/ingest.md` → `scripts/engine/intensity-gate.sh` (ingest.md cites the ingest-stage policy registered in the intensity gate)
- `commands/conversus-gate.md` → `scripts/dispatch/adapters/tool/conversus.sh` (conversus-gate.md references the tool adapter as its execution primitive)
- `commands/conversus-gate.md` → `templates/conversus-presets/normalize-fidelity.yml` (conversus-gate.md cites the canonical normalize preset)
- `commands/conversus-gate.md` → `templates/gate-result.md` (conversus-gate.md cites the gate-result artifact shape)
- `scripts/knowledge/normalize-spec.sh` → `templates/spec-normalizer-prompt.md` (normalize-spec.sh sources its prompt body from the template)
- `scripts/knowledge/normalize-spec.sh` → `scripts/dispatch/dispatch-interface.sh` (normalize-spec.sh dispatches the agent call through the uniform dispatch interface)
- `docs/ingesting-arbitrary-specs.md` → `commands/ingest.md` (the user guide points at the command doc as the authoritative reference)
- `scripts/verify/m011-p07-e2e-arbitrary-spec.sh` → `scripts/knowledge/detect-spec-shape.sh` (e2e exercises shape detection)
- `scripts/verify/m011-p07-e2e-arbitrary-spec.sh` → `scripts/knowledge/normalize-spec.sh` (e2e exercises normalize)
- `scripts/verify/m011-p07-e2e-arbitrary-spec.sh` → `scripts/knowledge/ingest-spec.sh` (e2e still exercises the P02/P03 chunker as the final stage)

## Tasks

### T01: Shape detection + normalizer wrapper + prompt template + per-artifact verify scripts

See `tasks/T01-PLAN.md`.

### T02: Conversus tool adapter + command doc + preset + gate-result template + per-artifact verify scripts

See `tasks/T02-PLAN.md`.

### T03: Ingest command re-wire + intensity-gate `ingest` stage + per-artifact verify scripts

See `tasks/T03-PLAN.md`.

### T04: Dogfood evidence (foreign PRD fixture) + E2E gate + Bash 3.2 compat + regression guards + user guide

See `tasks/T04-PLAN.md`.

## Task Dependencies

```
T01 ──┐
T02 ──┼──→ T03 ──→ T04
```

T01 and T02 are independent and can run in parallel. T01 delivers the shape probe, normalize-spec.sh wrapper, and normalizer prompt template (with their per-artifact verify scripts). T02 delivers the reusable Conversus tool-adapter, the `commands/conversus-gate.md` command doc, the normalize-fidelity preset, and the gate-result template (with their per-artifact verify scripts). T03 depends on both: it re-wires `commands/ingest.md` with the new `detect-shape → normalize → fidelity-gate → chunker` pipeline, adds the `--review` / `--no-review` / `--force`-after-BLOCK flags, and registers the `ingest` stage in `scripts/engine/intensity-gate.sh`. T04 depends on T03 because it captures the end-to-end dogfood evidence against a foreign-shaped PRD fixture, runs the regression guards (Bash 3.2 compat across all new scripts, command-reference preservation against P06), and ships the `docs/ingesting-arbitrary-specs.md` user guide.

## Files Likely Touched

- `scripts/knowledge/detect-spec-shape.sh` (create)
- `scripts/knowledge/normalize-spec.sh` (create)
- `scripts/dispatch/adapters/tool/conversus.sh` (create; also creates `scripts/dispatch/adapters/tool/` directory)
- `scripts/engine/intensity-gate.sh` (modify — add `ingest` stage case)
- `commands/ingest.md` (modify — add shape-detect / normalize / fidelity-gate pipeline; `--review`, `--no-review`, `--force`-after-BLOCK flags)
- `commands/conversus-gate.md` (create)
- `templates/spec-normalizer-prompt.md` (create)
- `templates/conversus-presets/normalize-fidelity.yml` (create; also creates `templates/conversus-presets/` directory)
- `templates/gate-result.md` (create)
- `tests/fixtures/arbitrary-prd.md` (create — foreign-shaped PRD fixture)
- `tests/fixtures/normalized-stub.md` (create — canned normalizer output for `NORMALIZER_STUB=1` regression path)
- `tests/fixtures/gate-result-pass.md` (create — canned PASS verdict for `CONVERSUS_STUB=1`)
- `tests/fixtures/gate-result-block.md` (create — canned BLOCK verdict for `CONVERSUS_STUB=1`)
- `docs/ingesting-arbitrary-specs.md` (create)
- `.orchestrator/milestones/M011/phases/P07/evidence/detect-shape.txt` (create)
- `.orchestrator/milestones/M011/phases/P07/evidence/normalize-transcript.txt` (create)
- [`.orchestrator/milestones/M011/phases/P07/evidence/gate-result.md`](../../../../milestones/M011/phases/P07/evidence/gate-result.md) (create)
- `.orchestrator/milestones/M011/phases/P07/evidence/chunker-transcript.txt` (create)
- `.orchestrator/milestones/M011/phases/P07/evidence/timing.txt` (create)
- `scripts/verify/m011-p07-shape-detect.sh` (create)
- `scripts/verify/m011-p07-normalize-wrapper-shape.sh` (create)
- `scripts/verify/m011-p07-normalizer-template.sh` (create)
- `scripts/verify/m011-p07-normalize-idempotent.sh` (create)
- `scripts/verify/m011-p07-conversus-adapter-shape.sh` (create)
- `scripts/verify/m011-p07-conversus-doc-structure.sh` (create)
- `scripts/verify/m011-p07-conversus-preset.sh` (create)
- `scripts/verify/m011-p07-gate-result-template.sh` (create)
- `scripts/verify/m011-p07-intensity-ingest-stage.sh` (create)
- `scripts/verify/m011-p07-ingest-doc-updates.sh` (create)
- `scripts/verify/m011-p07-e2e-arbitrary-spec.sh` (create)
- `scripts/verify/m011-p07-gate-pass-block.sh` (create)
- `scripts/verify/m011-p07-intensity-policy.sh` (create)
- `scripts/verify/m011-p07-bash32-compat.sh` (create)
- `scripts/verify/m011-p07-evidence-present.sh` (create)
- `scripts/verify/m011-p07-commands-preserve-references.sh` (create)

## Open Questions / Risks

- **External conversus dependency**: The roadmap explicitly calls for graceful degradation when the `conversus` binary is missing. The T02 adapter emits `available=false` and `SKIPPED:` without hard-failing. Risk: in CI without conversus, the fidelity-gate step becomes a no-op and the pipeline behaves as if `--no-review` was passed. This is documented in `docs/ingesting-arbitrary-specs.md` and exercised in T04 via `CONVERSUS_STUB=1`.
- **Runtime-adapter dispatch dependency**: `normalize-spec.sh` delegates agent I/O through `scripts/dispatch/dispatch-interface.sh`. The dispatch interface already resolves Claude Code / Codex / Cursor runtimes (MEM018), so no new runtime glue is needed — but a broken runtime resolver would cascade into normalize failures. The T01 verify scripts test the wrapper's shape and the `NORMALIZER_STUB=1` short-circuit; they do not test live agent calls (those are deferred to T04's dogfood run, intentionally). Live-agent quality variance is the medium-risk call-out in the roadmap — mitigated by (a) the reviewable normalized artifact landing in `specs/<slug>/spec.md` before the chunker, and (b) the Standard+ fidelity gate catching divergence.
- **`--force`-after-BLOCK escape hatch audit trail**: T03 documents the flag in `commands/ingest.md` but the chunker itself (from P02/P03) has no awareness of the gate. The T03 plan records the `FORCE:` line in the ingest log via the command doc's workflow instruction (no P02/P03 script changes). Risk: a future agent could forget to emit the FORCE record — mitigated by the T04 regression guard that asserts FORCE presence when the gate-pass-block test runs in BLOCK + `--force` mode.
- **Preset directory naming**: `templates/conversus-presets/` is a new subdirectory under `templates/`. The existing templates are flat files; the subdirectory is justified because M013/M014 will add more presets under the same parent. T02 verify scripts check for the exact path.
