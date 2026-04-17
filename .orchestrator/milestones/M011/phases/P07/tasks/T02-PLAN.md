---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P07"
milestone: "M011"
name: "Conversus tool adapter + commands/conversus-gate.md + normalize-fidelity preset + gate-result template"
depends_on: []
---

## Prerequisites

- The `scripts/dispatch/adapters/` tree exists with `backend/`, `format/`, and `runtime/` subdirectories using filename-routed adapter auto-discovery (MEM008, MEM018). This task adds a new sibling subdirectory `tool/`.
- The `templates/` directory exists with flat `.md` templates (MEM013). This task adds a new subdirectory `templates/conversus-presets/` and one flat template `templates/gate-result.md`.
- `commands/` directory follows MEM012 conventions: YAML frontmatter with `description`, top-level title, Prerequisites, Usage, Workflow, Idempotency, Error Handling, Reference Files sections.
- `.orchestrator/memory/constitution.md` exists at the canonical location (M015 cutover).
- Conversus is an external tool optionally installed at `~/Sites/conversus` or discoverable on `PATH` as `conversus`. When missing, the adapter must gracefully degrade (per roadmap directive).

## Description

Ship the reusable Conversus tool-adapter plus its associated command doc, preset, and gate-result template. This is the "adapter, not one-shot gate" half of P07 — M013 and M014 will invoke the same `scripts/dispatch/adapters/tool/conversus.sh` with their own presets at their own gate points (roadmap explicit). The adapter is strictly an external-tool bridge: it calls the `conversus` binary, parses the `gate-result.md` artifact, and reports a verdict. No agent prompts or deliberation logic live in bash — all two-agent reasoning is authored in the YAML preset and executed by conversus itself.

T02 is independent of T01. Both can run in parallel. T03 consumes both.

## Steps

1. **Create the adapter directory**: `mkdir -p scripts/dispatch/adapters/tool`.

2. **Create `scripts/dispatch/adapters/tool/conversus.sh`** (executable, `#!/usr/bin/env bash`, `set -u`). Support three subcommands:

   **`check`** (no args) — resolve the conversus binary:
   - If `CONVERSUS_STUB=1` is set, emit `available=true` and exit 0.
   - If `command -v conversus` returns 0, emit `available=true` and `conversus_path=$(command -v conversus)` and exit 0.
   - Else if `$CONVERSUS_HOME/bin/conversus` is executable, emit `available=true` and the path, exit 0.
   - Else if `$HOME/Sites/conversus/bin/conversus` is executable, emit `available=true` and the path, exit 0.
   - Else emit `available=false` and `reason=conversus binary not found on PATH, CONVERSUS_HOME, or ~/Sites/conversus`, exit 0 (NOT non-zero — missing is a valid state).

   **`gate <preset-name> <artifact-path> <output-path>`** — invoke the fidelity gate:
   - Resolve the preset file at `templates/conversus-presets/<preset-name>.yml`. If missing, emit `FAIL: preset not found: <path>` to stderr and exit 1.
   - Confirm the artifact-path is readable. If missing, emit `FAIL: artifact not found: <path>` and exit 1.
   - Stub-mode (`CONVERSUS_STUB=1`): look up an env var `CONVERSUS_STUB_VERDICT` (`PASS` or `BLOCK`, default `PASS`); copy the matching fixture (`tests/fixtures/gate-result-pass.md` for PASS, `tests/fixtures/gate-result-block.md` for BLOCK) to `<output-path>`. Then `parse-verdict` on that file and exit 0 on PASS, 2 on BLOCK.
   - Real-mode: resolve the binary via `check`. If `available=false`, emit `SKIPPED: conversus binary not available — fidelity gate bypassed` and exit 0. This is graceful degradation; the pipeline proceeds without a gate (roadmap directive).
   - When available, shell out: `conversus gate --preset <preset-file> --artifact <artifact-path> --output <output-path>`. Pipe stderr through verbatim. On non-zero exit from the conversus binary, emit `FAIL: conversus exited non-zero` and exit 1.
   - After the binary returns, invoke `parse-verdict <output-path>` internally: on `verdict=PASS` exit 0, on `verdict=BLOCK` exit 2, on malformed output exit 1.

   **`parse-verdict <gate-result-path>`** — read the frontmatter of the gate-result artifact and emit `verdict=PASS|BLOCK` to stdout. Use `grep -E '^verdict:' | head -n 1 | sed -E 's/^verdict:[[:space:]]*"?([^"]*)"?.*/\1/'`. On file missing or malformed, emit `FAIL:` to stderr and exit 1.

3. **Create `commands/conversus-gate.md`** (MEM012 structure):
   - Frontmatter: `description: "Use when gating an artifact through a two-agent Conversus cooperative deliberation. The source-advocate vs target-advocate pattern produces a structured PASS|BLOCK verdict that callers use to gate downstream work. Reusable across any orchestrator stage that needs fidelity or quality gating (M011 normalize, M013 issue-sync, M014 comment-apply)."`
   - Title: `# speckit.orchestrator.conversus-gate`
   - Prerequisites: conversus binary optional, name the resolver order; preset file must exist under `templates/conversus-presets/<preset>.yml`; artifact file readable.
   - Usage: `bash scripts/dispatch/adapters/tool/conversus.sh gate <preset-name> <artifact-path> <output-path>`. Document the exit-code contract: 0 = PASS (or SKIPPED when binary missing), 2 = BLOCK, 1 = adapter error. Include the `normalize-fidelity` preset by name as the canonical example, plus an "Adding new presets" extension-point subsection that points future M013/M014 preset authors at `templates/conversus-presets/` and `templates/gate-result.md`.
   - Workflow: numbered steps documenting the two-agent cooperative deliberation protocol — source-advocate argues preservation, target-advocate argues target-shape fitness, arbiter (grounded in `.orchestrator/memory/constitution.md`) emits the verdict.
   - Idempotency: same artifact + same preset + same source-hash → deterministic verdict when the conversus binary is deterministic-seeded. When non-deterministic, re-runs may emit different verdicts; callers that need cached verdicts must compare the `source_hash:` frontmatter field in `gate-result.md` against the current artifact hash.
   - Error Handling: conversus binary missing → `SKIPPED:` + exit 0 (graceful degradation); preset missing → exit 1; artifact missing → exit 1; malformed gate-result → exit 1.
   - Reference Files: `scripts/dispatch/adapters/tool/conversus.sh`, `templates/conversus-presets/normalize-fidelity.yml`, `templates/gate-result.md`, `.orchestrator/memory/constitution.md`.

4. **Create `templates/conversus-presets/normalize-fidelity.yml`**. Frontmatter: `schema_version: "1.0"`, `type: conversus-preset`. Body (YAML):
   - `preset_name: normalize-fidelity`
   - `description: Two-agent cooperative deliberation gating a normalized spec artifact against its source.`
   - `agents:` — two-entry list:
     - `source-advocate` with a `system_prompt` field containing the source-preservation charter: "You argue that the normalized spec preserves every factual claim, requirement, non-goal, constraint, and acceptance criterion present in the source document. You raise a dispute for any claim that was dropped, paraphrased in a way that changes meaning, or silently merged with another claim."
     - `target-advocate` with a `system_prompt` field containing the target-fitness charter: "You argue that the normalized spec fits the spec-kit shape cleanly. You raise a dispute for any requirement that was invented (not derivable from the source), any heading that does not match the spec-kit layout, or any content that violates Constitution Principle I (Context Minimization) by repeating the source verbatim rather than distilling it."
   - `arbiter:` block with `grounding_file: .orchestrator/memory/constitution.md` and `verdict_contract: PASS|BLOCK`.
   - `output:` block with `template: templates/gate-result.md` and `required_fields: [verdict, disputes, rationale, source_hash]`.

5. **Create `templates/gate-result.md`**. Frontmatter:
   ```yaml
   ---
   schema_version: "1.0"
   type: gate-result
   preset: "{{preset}}"
   artifact: "{{artifact_path}}"
   verdict: "{{PASS|BLOCK}}"
   timestamp: "{{iso_8601}}"
   source_hash: "{{hash}}"
   ---
   ```
   Body:
   ```
   # Gate Result: {{preset}}

   ## Verdict

   {{verdict}}

   ## Disputes

   {{#disputes}}
   - **{{agent}}**: {{dispute_text}}
   {{/disputes}}

   ## Rationale

   {{rationale}}
   ```

6. **Create `scripts/verify/m011-p07-conversus-adapter-shape.sh`**. Asserts `scripts/dispatch/adapters/tool/conversus.sh` exists, is executable, and:
   - Supports the three subcommands (`grep -Fq -- 'check)'`, `grep -Fq -- 'gate)'`, `grep -Fq -- 'parse-verdict)'` in a case block).
   - Documents the four resolver locations in a comment or case (`command -v conversus`, `CONVERSUS_HOME`, `~/Sites/conversus`, `CONVERSUS_STUB`).
   - Emits `available=` token (`grep -Fq -- 'available='`).
   - Emits `SKIPPED:` on missing binary (graceful degradation).
   - Returns exit 2 on BLOCK (grep for `exit 2` in the verdict-parse branch).
   - Runs the stub-mode end-to-end: creates a sandbox `TMP=$(mktemp -d)` with trap cleanup, `cp tests/fixtures/gate-result-pass.md $TMP/pass.md; cp tests/fixtures/gate-result-block.md $TMP/block.md`; calls `bash scripts/dispatch/adapters/tool/conversus.sh parse-verdict $TMP/pass.md` and asserts stdout `verdict=PASS`; same for block and asserts `verdict=BLOCK`.
   - Emit `PASS:` / `FAIL:` per assertion.

   Note: this verify script depends on `tests/fixtures/gate-result-pass.md` and `tests/fixtures/gate-result-block.md`. Create both as 10-line stubs within this task: frontmatter with `verdict: "PASS"` / `verdict: "BLOCK"` + a minimal `## Disputes` / `## Rationale` body.

7. **Create `scripts/verify/m011-p07-conversus-doc-structure.sh`**. Asserts `commands/conversus-gate.md`:
   - Exists; ≥ 90 lines.
   - Frontmatter has `description:`.
   - Contains the tokens `source-advocate`, `target-advocate`, `normalize-fidelity`, `PASS`, `BLOCK`.
   - Has the MEM012-required section headings: `## Prerequisites`, `## Usage`, `## Workflow`, `## Idempotency`, `## Error Handling`, `## Reference Files` (or equivalent; assert each via `grep -Eq '^## (Prerequisites|Usage|Workflow|Idempotency|Error Handling|Reference Files)'`).
   - References the three files: `scripts/dispatch/adapters/tool/conversus.sh`, `templates/conversus-presets/normalize-fidelity.yml`, `templates/gate-result.md` (use `grep -Fq --`).
   - Emit `PASS:` / `FAIL:`.

8. **Create `scripts/verify/m011-p07-conversus-preset.sh`**. Asserts `templates/conversus-presets/normalize-fidelity.yml`:
   - Exists; ≥ 40 lines.
   - Frontmatter contains `schema_version:` and `type: conversus-preset`.
   - Body contains both `source-advocate` and `target-advocate` agent entries (`grep -Fq --`).
   - Body references `.orchestrator/memory/constitution.md` as arbiter grounding.
   - Body references `templates/gate-result.md` as output template.
   - Emit `PASS:` / `FAIL:`.

9. **Create `scripts/verify/m011-p07-gate-result-template.sh`**. Asserts `templates/gate-result.md`:
   - Exists; ≥ 25 lines.
   - Frontmatter contains the required fields: `schema_version`, `type: gate-result`, `preset:`, `artifact:`, `verdict:`, `timestamp:`, `source_hash:`.
   - Body contains `## Verdict`, `## Disputes`, `## Rationale` section headings.
   - Body uses the `{{verdict}}` placeholder per MEM013.
   - Emit `PASS:` / `FAIL:`.

10. **Set executable bits** on all new scripts (`chmod +x`).

## Must-Haves

From `P07-PLAN.md` Truths, this task is responsible for:

- `scripts/dispatch/adapters/tool/conversus.sh` adapter shape + graceful degradation + three-subcommand contract (Check: `m011-p07-conversus-adapter-shape.sh`).
- `commands/conversus-gate.md` MEM012-shaped command doc for the reusable two-agent deliberation protocol (Check: `m011-p07-conversus-doc-structure.sh`).
- `templates/conversus-presets/normalize-fidelity.yml` two-agent cooperative preset (Check: `m011-p07-conversus-preset.sh`).
- `templates/gate-result.md` canonical gate-result artifact template (Check: `m011-p07-gate-result-template.sh`).

Artifacts this task creates: the conversus adapter script, conversus-gate command doc, normalize-fidelity preset, gate-result template, two canned stub fixtures, and four per-artifact verify scripts.

## Verification

Run (single-script-file shape per AD-19):

```
bash scripts/verify/m011-p07-conversus-adapter-shape.sh
bash scripts/verify/m011-p07-conversus-doc-structure.sh
bash scripts/verify/m011-p07-conversus-preset.sh
bash scripts/verify/m011-p07-gate-result-template.sh
```

Each must emit `PASS:` on the happy path and exit 0.

## Inputs

### From Previous Tasks
None — T02 is independent of T01. Both can run in parallel.

### From Disk (Pre-existing)
- `scripts/dispatch/adapters/backend/local-agent.sh` — existing filename-routed adapter exemplar. Use its shape (POSIX-style subcommand dispatch) as the stylistic reference for `tool/conversus.sh`. Do NOT modify it.
- `scripts/dispatch/dispatch-interface.sh` — the uniform dispatch entry (consumed by T01's normalize-spec.sh, not by T02).
- `.orchestrator/memory/constitution.md` — arbiter grounding file. Referenced by the preset but not read by this task's scripts.
- `templates/*.md` — existing templates using `{{placeholder}}` syntax (MEM013). Follow the same convention in the new gate-result template.
- `commands/ingest.md` — the sibling command doc whose shape `conversus-gate.md` mirrors (MEM012). Do NOT modify in T02; T03 owns the ingest edits.

## Constraints

- **Bash 3.2 compatible** (MEM001): no `declare -A`, no `mapfile`/`readarray`, no process substitution.
- **Filename-routed adapter auto-discovery** (MEM018): the adapter file name must match the resource type (`conversus.sh` under `tool/` — mirrors `local-agent.sh` under `backend/`).
- **Graceful degradation** (roadmap directive): missing conversus binary must NOT hard-fail; `gate` emits `SKIPPED:` and exit 0 so the calling pipeline can proceed without a gate.
- **No hardcoded HTTP calls**: the adapter shells out to the `conversus` binary only. No `curl`/`wget` in the adapter.
- **Reusable across milestones** (roadmap directive): the adapter must accept ANY preset name, not just `normalize-fidelity`. M013/M014 will add their own presets under `templates/conversus-presets/` without changing the adapter.
- **BSD grep safety** (MEM012): any token beginning with `-` uses `grep -Fq -- "$tok"`.
- **Structured output**: emit `PASS:`, `FAIL:`, `SKIPPED:`, `available=`, `verdict=` prefixes per MEM001.
- **Exit-code contract**: 0 = PASS or SKIPPED (both are "proceed"); 2 = BLOCK (distinct from 1 = error) so callers can distinguish a valid BLOCK verdict from an adapter failure.

## Expected Output

- One new production script: `scripts/dispatch/adapters/tool/conversus.sh` (the adapter directory is also newly created).
- One new command doc: `commands/conversus-gate.md`.
- Two new templates: `templates/conversus-presets/normalize-fidelity.yml`, `templates/gate-result.md`.
- Two new test fixtures: `tests/fixtures/gate-result-pass.md`, `tests/fixtures/gate-result-block.md`.
- Four new verify scripts under `scripts/verify/m011-p07-*.sh`, all emitting `PASS:` and exiting 0.
