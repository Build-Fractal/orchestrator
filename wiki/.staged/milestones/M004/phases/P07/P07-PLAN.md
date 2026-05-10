---
schema_version: "1.0"
type: phase-plan
phase: "P07"
milestone: "M004"
goal: "Add recipe conformance diagnostic, verify existing event and constitution checks cover M004 requirements, register new check in run-doctor.sh and extension.yml"
demo_sentence: "Running bash scripts/diagnostics/run-doctor.sh produces a Recipe Conformance section that validates context-recipe.yaml structure (sections have required fields, source types are known, priorities are valid), alongside the already-working event emission and constitution coverage checks."
risk: "low"
depends_on: [P02, P03, P04, P05, P06]
---

## Goal

Deliver the recipe conformance diagnostic check (`check-recipe.sh`) that validates context-recipe.yaml structure, register it in `run-doctor.sh` and `extension.yml`, and verify the existing `check-events.sh` and `check-constitution.sh` diagnostics (created in M005/P07) already satisfy M004's P07 requirements for event emission conformance and constitution v2.0 compliance.

The existing diagnostics infrastructure already includes:
- `check-constitution.sh` -- scans phase plans for references to constitution principles I-XIII (already registered in run-doctor.sh)
- `check-events.sh` -- verifies engine-path scripts contain `emit_event` calls (already registered in run-doctor.sh)

Both of these were delivered in M005/P07 and are fully operational. This phase's primary new work is the recipe conformance check, which is the only diagnostic listed in the M004 roadmap that does not yet exist.

## Demo

From repo root, a developer can:

1. Run the new recipe conformance check standalone:
   ```bash
   bash scripts/diagnostics/check-recipe.sh --root .
   # DOCTOR:RECIPE status=ok sections=7 invalid=0
   ```

2. Run the full doctor suite and see the new check alongside existing ones:
   ```bash
   bash scripts/diagnostics/run-doctor.sh --root .
   # ... existing checks ...
   # --- Recipe Conformance ---
   # DOCTOR:RECIPE status=ok sections=7 invalid=0
   # ... remaining checks ...
   ```

3. Verify that existing event and constitution checks already pass:
   ```bash
   bash scripts/diagnostics/check-events.sh --root .
   bash scripts/diagnostics/check-constitution.sh --root .
   ```

## Must-Haves

### Truths

- check-recipe.sh exists and is executable
  - Check: `bash scripts/verify/m004-p07-recipe-exists.sh`
- check-recipe.sh validates all 7 default recipe sections have required fields (source, priority, order, filter, cache_hint)
  - Check: `bash scripts/verify/m004-p07-recipe-fields.sh`
- check-recipe.sh validates source types against known set (computed, file, phase_summaries, phase_plan, task_plan, template, index)
  - Check: `bash scripts/verify/m004-p07-recipe-sources.sh`
- check-recipe.sh validates priorities against known set (required, compressible, optional)
  - Check: `bash scripts/verify/m004-p07-recipe-priorities.sh`
- check-recipe.sh emits DOCTOR:RECIPE structured output
  - Check: `bash scripts/verify/m004-p07-recipe-output.sh`
- run-doctor.sh includes the recipe conformance check
  - Check: `bash scripts/verify/m004-p07-doctor-recipe.sh`
- extension.yml registers check-recipe.sh
  - Check: `bash scripts/verify/m004-p07-extension-recipe.sh`
- check-events.sh already verifies engine-path scripts emit events (pre-existing)
  - Check: `bash scripts/verify/m004-p07-events-existing.sh`
- check-constitution.sh already verifies v2.0 principles in phase plans (pre-existing)
  - Check: `bash scripts/verify/m004-p07-constitution-existing.sh`

### Artifacts

- scripts/diagnostics/check-recipe.sh (min 80 lines, contains "DOCTOR:RECIPE")
- scripts/diagnostics/run-doctor.sh (contains "check-recipe.sh")
- extension.yml (contains "check-recipe.sh")

### Key Links

- scripts/diagnostics/check-recipe.sh -> templates/context-recipe.yaml
- scripts/diagnostics/check-recipe.sh -> scripts/lib/recipe-parser.sh
- scripts/diagnostics/run-doctor.sh -> scripts/diagnostics/check-recipe.sh

## Cross-Cutting Constraints (apply to every task)

Every task in this phase MUST comply with the following:

1. **Bash 3.2** -- no associative arrays (`declare -A`), no `readarray`, no `mapfile`, no process substitution (`<(...)`) as a redirect target in `while read` loops.
2. **No jq** -- all YAML/JSON parsing uses grep/sed/awk or the recipe-parser.sh library.
3. **DOCTOR: output convention** -- diagnostic scripts emit a structured `DOCTOR:<NAME> status=<ok|warn> key=value` line. Status `ok` exits 0, status `warn` exits 1.
4. **Standalone safety** -- check-recipe.sh must work standalone (no ORCH_RUN_ID dependency for core functionality). If ORCH_RUN_ID is set, emit events/results via P02 libraries.
5. **P02 library sourcing pattern** -- `_SCRIPT_DIR / _LIB_DIR` with `../../lib` path from `scripts/diagnostics/`.
6. **Existing checks must not break** -- do not modify check-constitution.sh or check-events.sh (they are already correct).
7. **Artifact paths in plan MUST NOT use backticks** (check-must-haves.sh parser includes them literally).

## Tasks

### T01: Create check-recipe.sh

Create the recipe conformance diagnostic script at `scripts/diagnostics/check-recipe.sh`. It sources `scripts/lib/recipe-parser.sh` to parse `templates/context-recipe.yaml`, validates that each section has the 5 required fields (source, priority, order, filter, cache_hint), validates source types against a known set, and validates priorities against a known set. Emits `DOCTOR:RECIPE` structured output. Follows the same convention as existing check scripts (check-hashes.sh, check-instructions.sh, etc.).

### T02: Register check-recipe.sh in run-doctor.sh and extension.yml

Add a `run_check "Recipe Conformance"` call to `scripts/diagnostics/run-doctor.sh` and register `scripts/diagnostics/check-recipe.sh` in `extension.yml` under `provides.scripts`.

### T03: Verification helper scripts and phase verification

Create all verification helper scripts under `scripts/verify/m004-p07-*.sh` for the truth checks listed in Must-Haves. Run all checks to verify the phase is complete, including confirming the pre-existing `check-events.sh` and `check-constitution.sh` satisfy the M004 roadmap requirements.

## Task Dependencies

```
T01 (check-recipe.sh must exist before it can be registered)
T01 -> T02 (registration depends on the script existing)
T01 + T02 -> T03 (verification runs after all code changes are complete)
```

Sequential execution order: T01 -> T02 -> T03

## Files Likely Touched

- scripts/diagnostics/check-recipe.sh (create -- new recipe conformance check)
- scripts/diagnostics/run-doctor.sh (modify -- add recipe conformance check call)
- extension.yml (modify -- register check-recipe.sh)
- scripts/verify/m004-p07-*.sh (create -- verification helper scripts)

No changes to check-constitution.sh, check-events.sh, or any P02/P05/P06 output scripts.

## Constitution References

- Principle II (Evidence Before Claims) -- diagnostic checks provide evidence of conformance
- Principle IX (Reproducibility Over Convenience) -- recipe validation ensures reproducible context assembly
- Principle X (Templating Over Inference) -- validating recipe structure enforces template-driven configuration
- Principle XI (Single Source of Truth) -- recipe is the single source for context assembly configuration
