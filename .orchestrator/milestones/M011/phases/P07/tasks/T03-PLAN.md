---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P07"
milestone: "M011"
name: "Ingest command re-wire (detect-shape → normalize → fidelity-gate → chunker) + intensity-gate `ingest` stage"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 is complete: `scripts/knowledge/detect-spec-shape.sh` and `scripts/knowledge/normalize-spec.sh` exist and emit the documented structured-output prefixes.
- T02 is complete: `scripts/dispatch/adapters/tool/conversus.sh` exists with the three-subcommand contract (`check`, `gate`, `parse-verdict`), `commands/conversus-gate.md` documents the reusable protocol, `templates/conversus-presets/normalize-fidelity.yml` and `templates/gate-result.md` exist.
- `scripts/engine/intensity-gate.sh` from M008 exists with seven registered stages: `discuss`, `research`, `plan-phase`, `dispatch`, `verify`, `knowledge`, `auto`, `roadmap`. This task adds an eighth: `ingest`.
- `commands/ingest.md` exists from P06 at ~140 lines with the P06 thin-wrapper semantics.
- `commands/evaluate.md` and `commands/roadmap.md` exist with P05/P06 Reference File bullets — these must not be disturbed.

## Description

Re-wire `commands/ingest.md` so the pipeline becomes `detect-shape → normalize-if-foreign → fidelity-gate-if-enabled → chunker`. Add three new user-facing flags: `--review` (force fidelity gate on regardless of intensity), `--no-review` (force off), and `--force` (bypass a BLOCK verdict and run the chunker anyway, recorded as a `FORCE:` line in the ingest log). Register a new `ingest` stage in `scripts/engine/intensity-gate.sh` with the substep vocabulary `normalize | fidelity-gate | force-chunker` and the policy matrix Quick→normalize, Standard→normalize+fidelity-gate, Full→normalize+fidelity-gate.

This task produces the two per-artifact verify scripts that guard the new doc sections and the intensity-stage registration: `m011-p07-ingest-doc-updates.sh` and `m011-p07-intensity-ingest-stage.sh`. The intensity-policy assertion covering the `--review` override is in T04 (it depends on the end-to-end wire from this task).

## Steps

1. **Edit `scripts/engine/intensity-gate.sh`**: Inside the big `case "$STAGE" in ... esac`, add a new `ingest)` branch BEFORE the catch-all `*)`. Vocabulary comment + body:

   ```
     ingest)
       # Substep vocabulary:
       #   normalize | fidelity-gate | force-chunker
       # Policy: Quick skips the fidelity gate (fast path);
       # Standard+ runs both normalize and fidelity-gate.
       # The --review flag on orchestrator:ingest promotes fidelity-gate
       # into execute_substeps regardless of resolved intensity; --no-review
       # forces it into skip_substeps. Those overrides are applied by the
       # calling command (commands/ingest.md), not by this gate.
       case "$INTENSITY" in
         Quick)    execute="normalize";               skip="fidelity-gate" ;;
         Standard) execute="normalize,fidelity-gate"; skip="none" ;;
         Full)     execute="normalize,fidelity-gate"; skip="none" ;;
       esac
       ;;
   ```

   Also update the final catch-all error message to include `ingest` in the expected-stage list:

   ```
       echo "ERROR: unknown stage '$STAGE' (expected discuss|research|plan-phase|dispatch|verify|knowledge|auto|roadmap|ingest)" >&2
   ```

2. **Edit `commands/ingest.md`**: This is a surgical modification (MEM001 idempotent, MEM013 preserve prior content). Required additions:

   a. **New workflow step inserted between the current Step 1 (Validate spec-path) and current Step 2 (Invoke `ingest-spec.sh`)**: a "Step 2. Detect spec shape" paragraph that instructs the agent to invoke `bash scripts/knowledge/detect-spec-shape.sh --spec-path <path>` and parse the `shape=speckit|foreign` output. On `shape=speckit`, skip directly to the chunker (current Step 2). On `shape=foreign`, proceed to Step 3.

   b. **"Step 3. Normalize foreign-shaped input"** paragraph: invoke `bash scripts/knowledge/normalize-spec.sh --spec-path <source> --slug <slug>` which dispatches the agent through `scripts/dispatch/dispatch-interface.sh` using `templates/spec-normalizer-prompt.md`. Normalized output lands at `specs/<slug>/spec.md`. Explicitly note: "the normalized artifact is written BEFORE the fidelity gate so the developer can audit the normalization output even when the gate returns BLOCK."

   c. **"Step 4. Resolve ingest-stage policy"** paragraph: invoke `bash scripts/engine/intensity-gate.sh --stage ingest --intensity-metadata <metadata-path>` to determine whether `fidelity-gate` is in `execute_substeps`. Document the `--review` / `--no-review` override: if `--review` was passed on the command line, force `fidelity-gate` into `execute_substeps` regardless; if `--no-review` was passed, force it into `skip_substeps`.

   d. **"Step 5. Run fidelity gate (conditional)"** paragraph: when `fidelity-gate` is in `execute_substeps`, invoke `bash scripts/dispatch/adapters/tool/conversus.sh gate normalize-fidelity specs/<slug>/spec.md .orchestrator/milestones/<M>/<P>/gate-result.md`. Interpret exit codes: 0 = PASS → proceed to chunker; 0 + `SKIPPED:` (conversus missing) → proceed to chunker with a warning; 2 = BLOCK → stop unless `--force` was passed; 1 = adapter error → stop. When BLOCK + `--force`, record a `FORCE: gate BLOCK bypassed by --force at <iso-8601>` line in `<milestone-dir>/.ingest-log.jsonl` (or the nearest milestone directory) before proceeding.

   e. **Update Step 2 (now Step 6) "Invoke `ingest-spec.sh`"**: unchanged content, renumbered.

   f. **Add to the Usage section**: three new flag lines — `--review` (force fidelity gate on), `--no-review` (force fidelity gate off), `--force` (bypass a BLOCK verdict and run the chunker; distinct from the existing `--force` for re-ingest confirmation). Clarify in the doc that `--force` now has two semantically-separate effects: (i) the original P06 re-ingest confirmation bypass, (ii) the new P07 BLOCK-verdict bypass. Both are subsumed under the same flag.

   g. **Add to the Reference Files section** (without deleting any existing bullet):
      - `scripts/knowledge/detect-spec-shape.sh` — shape probe for format-agnostic intake
      - `scripts/knowledge/normalize-spec.sh` — LLM-driven normalizer for foreign-shaped input
      - `scripts/dispatch/adapters/tool/conversus.sh` — reusable Conversus fidelity-gate adapter
      - `commands/conversus-gate.md` — the reusable command doc for arbitrary-preset conversus gating
      - `scripts/engine/intensity-gate.sh` — the intensity gate with the new `ingest` stage
      - `templates/spec-normalizer-prompt.md` — normalizer prompt body
      - `templates/conversus-presets/normalize-fidelity.yml` — canonical fidelity-gate preset
      - `templates/gate-result.md` — gate-result artifact shape

3. **Create `scripts/verify/m011-p07-intensity-ingest-stage.sh`** (executable). Asserts:
   - `scripts/engine/intensity-gate.sh` exists.
   - `grep -Fq -- 'ingest)' scripts/engine/intensity-gate.sh` succeeds.
   - Runs the gate three times and parses output:
     - `bash scripts/engine/intensity-gate.sh --stage ingest --intensity Quick` → stdout contains `execute_substeps=normalize` (exact match, not prefix) and `skip_substeps=fidelity-gate`.
     - `--intensity Standard` → `execute_substeps=normalize,fidelity-gate` and `skip_substeps=none`.
     - `--intensity Full` → `execute_substeps=normalize,fidelity-gate` and `skip_substeps=none`.
   - `bash scripts/engine/intensity-gate.sh --stage ingest --intensity Bogus` exits non-zero (invalid intensity rejected).
   - Emit `PASS:` / `FAIL:` per assertion.

4. **Create `scripts/verify/m011-p07-ingest-doc-updates.sh`** (executable). Asserts `commands/ingest.md`:
   - Exists; ≥ 140 lines.
   - Contains `--review` token (`grep -Fq -- '--review'`).
   - Contains `--no-review` token (`grep -Fq -- '--no-review'`).
   - Contains `--force` token (preserved from P06).
   - Contains both `detect-spec-shape.sh` and `normalize-spec.sh` references (`grep -Fq --`).
   - Contains `adapters/tool/conversus.sh` reference.
   - Contains `intensity-gate.sh --stage ingest` invocation literal.
   - Contains the `FORCE:` token (the `--force`-after-BLOCK audit-trail marker).
   - Contains the literal phrase `the normalized artifact is written BEFORE the fidelity gate` (or a close variant — the verify script accepts `normalized artifact` + `BEFORE` + `fidelity gate` appearing within three consecutive lines, tested via `grep -B 2 -A 2 -- 'normalized artifact'`).
   - Preserves ALL the prior P06 Reference File bullets: `scripts/knowledge/ingest-spec.sh`, `scripts/knowledge/rebuild-index.sh`, `scripts/state/spec-metrics.sh`, `scripts/dispatch/scope-filter.sh`, `knowledge/spec/`, `templates/evaluation.md` — each token must still be present via `grep -Fq --`.
   - Emit `PASS:` / `FAIL:` per assertion.

5. **Set executable bits** on both new verify scripts (`chmod +x`).

## Must-Haves

From `P07-PLAN.md` Truths, this task is responsible for:

- `scripts/engine/intensity-gate.sh` registers the `ingest` stage with the documented policy matrix (Check: `m011-p07-intensity-ingest-stage.sh`).
- `commands/ingest.md` documents the new pre-chunker pipeline plus `--review` / `--no-review` / `--force`-after-BLOCK flags, preserving every P06 Reference File bullet (Check: `m011-p07-ingest-doc-updates.sh`).

This task does NOT address: the conversus-adapter shape (T02), the normalize-spec wrapper shape (T01), the E2E dogfood flow (T04), the Bash 3.2 compat scan (T04), the preserved-references regression across evaluate.md/roadmap.md (T04).

## Verification

Run (single-script-file shape per AD-19):

```
bash scripts/verify/m011-p07-intensity-ingest-stage.sh
bash scripts/verify/m011-p07-ingest-doc-updates.sh
```

Each must emit `PASS:` on the happy path and exit 0.

## Inputs

### From Previous Tasks

- `scripts/knowledge/detect-spec-shape.sh` (from T01)
  - Key API: `bash detect-spec-shape.sh --spec-path <path>` emits `shape=speckit|foreign` and `reasons=<csv>` to stdout. Exit 0 on both outcomes; exit 1 only on missing input.
  - Key types: single CLI flag, stdout key=value pairs.

- `scripts/knowledge/normalize-spec.sh` (from T01)
  - Key API: `bash normalize-spec.sh --spec-path <source> --slug <slug> [--force]` dispatches the normalizer agent through `scripts/dispatch/dispatch-interface.sh` and writes `specs/<slug>/spec.md`. Emits `NORMALIZED:` or `SKIPPED:` to stdout. Exit 0/1.
  - Key types: CLI flags, atomic temp-file-then-rename write, hash-based idempotency check, `NORMALIZER_STUB=1` env-var escape for CI.

- `scripts/dispatch/adapters/tool/conversus.sh` (from T02)
  - Key API: three subcommands.
    - `check` → emits `available=true|false`, exit 0.
    - `gate <preset-name> <artifact-path> <output-path>` → exit 0 on PASS (or SKIPPED when binary missing), 2 on BLOCK, 1 on adapter error.
    - `parse-verdict <gate-result-path>` → emits `verdict=PASS|BLOCK` to stdout.
  - Key types: subcommand dispatch, tri-state exit codes (0/1/2), `CONVERSUS_STUB=1` env-var escape.

- `templates/spec-normalizer-prompt.md` (from T01) — consumed by `normalize-spec.sh`; this task only references it in `commands/ingest.md`'s Reference Files.
- `templates/conversus-presets/normalize-fidelity.yml` (from T02) — consumed by the conversus adapter; referenced in `commands/ingest.md`.
- `templates/gate-result.md` (from T02) — the output artifact shape; referenced in `commands/ingest.md`.

### From Disk (Pre-existing)

- `scripts/engine/intensity-gate.sh` (M008) — 144 lines. Has seven registered stages. Add an eighth: `ingest`. The matrix is hardcoded; NO config file edits required.
- `commands/ingest.md` (P06) — ~140 lines documenting the P06 thin-wrapper semantics. This task EDITS it; does not overwrite.
- `scripts/dispatch/dispatch-interface.sh` — the uniform dispatch entry. Referenced only in `commands/ingest.md`; not invoked by any new script in this task.

## Constraints

- **Preserve all P06 content in `commands/ingest.md`**: do not delete any existing Reference File bullet, Usage flag, or section heading. The T04 preserved-references regression will fail if any prior bullet is lost.
- **Additive intensity-gate edit**: add the `ingest)` case and update the error message; do NOT reshuffle the existing stage order.
- **Bash 3.2 compatible** (MEM001) for the two new verify scripts.
- **BSD grep safety** (MEM012): `grep -Fq -- "$tok"` for any token beginning with `-`.
- **Single-script-file Check shape** (AD-19): both verify scripts are invokable as `bash scripts/verify/<name>.sh` with zero CLI arguments.
- **No P02/P03 script changes**: do NOT modify `scripts/knowledge/ingest-spec.sh` or `rebuild-index.sh`. The `FORCE:` audit-trail line is emitted by the command's workflow instruction into `.ingest-log.jsonl`, not by the chunker.
- **No T01/T02 artifact changes**: do NOT modify `detect-spec-shape.sh`, `normalize-spec.sh`, `spec-normalizer-prompt.md`, the conversus adapter, `conversus-gate.md`, the preset, or the gate-result template. This task only wires them into `commands/ingest.md` and registers the intensity stage.

## Expected Output

- `scripts/engine/intensity-gate.sh` modified: one new `ingest)` case block added and the catch-all error message updated to list the new stage.
- `commands/ingest.md` modified: workflow re-numbered to 6 steps (detect-shape, normalize-if-foreign, resolve-policy, fidelity-gate-conditional, chunker, rebuild+report), Usage section gains three flags, Reference Files section gains eight new bullets (all P06 bullets preserved).
- Two new verify scripts: `scripts/verify/m011-p07-intensity-ingest-stage.sh`, `scripts/verify/m011-p07-ingest-doc-updates.sh`.
- Both verify scripts emit `PASS:` and exit 0 when run.
