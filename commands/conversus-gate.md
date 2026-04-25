---
description: "Use when gating an artifact through a two-agent Conversus cooperative deliberation. The source-advocate vs target-advocate pattern produces a structured PASS|BLOCK verdict that callers use to gate downstream work. Reusable across any orchestrator stage that needs fidelity or quality gating (M011 normalize, M013 issue-sync, M014 comment-apply)."
---

# orchestrator:conversus-gate

A thin, reusable command wrapping the Conversus cooperative-deliberation
tool adapter. Given a preset name and an artifact, it runs the two-agent
source-advocate vs target-advocate deliberation under a constitution-
grounded arbiter and emits a PASS | BLOCK verdict. Callers use the
verdict to gate downstream work: PASS proceeds, BLOCK pauses the
pipeline for human review.

This command is intentionally preset-agnostic. M011 uses the
`normalize-fidelity` preset to gate a normalized spec against its
source. M013 will use its own preset to gate an issue-sync operation,
and M014 will use a third preset to gate comment-apply operations. Each
milestone authors a YAML preset under `templates/conversus-presets/`
without changing the adapter.

## Prerequisites

- **Conversus binary is OPTIONAL.** The adapter resolves it in this
  order (M026/P02 — OSS is now the user-local default, paid is an
  escape hatch):
  1. `CONVERSUS_STUB=1` — stub mode (test-only, uses canned fixtures).
  2. `command -v conversus` — PATH.
  3. `$CONVERSUS_HOME/bin/conversus` — explicit absolute override.
  4. `$HOME/Sites/conversus-oss/bin/conversus` — user-local OSS default
     (M026/P02).
  5. `$HOME/Sites/conversus/bin/conversus` — user-local paid escape
     hatch.

  Edition is reported on `check` stdout as
  `edition=<oss|paid|unknown>`. Operator declares the edition via
  `CONVERSUS_EDITION=oss|paid` (primary); fallback is
  `python -m pip show conversus` metadata-probe against the resolved
  venv's `Home-page:` line. Stub mode is edition-agnostic
  (`edition=unknown reason=stub`). See `references/architecture.md`
  "Conversus Adapter — Operator Notes" for the operator runbook.

  **Paid-only-preset refusal (M026/P03)**: a preset whose YAML
  frontmatter declares `edition_required: paid` invoked on an
  OSS-resolved binary will be refused before any `conversus run`
  invocation. The diagnostic on stderr names the preset, the edition
  requirement, and `CONVERSUS_EDITION=paid` as the escape. Presets
  without `edition_required:` behave identically to today.

  When the binary is missing, `gate` emits a `SKIPPED:` line and exits 0
  (graceful degradation — the calling pipeline proceeds without a gate).
- The preset file must exist at
  `templates/conversus-presets/<preset>.yml`.
- The artifact file must be readable at the path passed to `gate`.
- The arbiter grounding file `.orchestrator/memory/constitution.md` must
  be present at the canonical location (M015 cutover).

## Usage

```
bash scripts/dispatch/adapters/tool/conversus.sh gate <preset-name> <artifact-path> <output-path>
```

Example invocation (canonical M011 normalize-fidelity example):

```
bash scripts/dispatch/adapters/tool/conversus.sh \
  gate normalize-fidelity \
  specs/007-example/spec.md \
  .orchestrator/milestones/M011/gates/normalize-fidelity-007.md
```

**Exit-code contract:**

- `0` — PASS verdict, OR SKIPPED (binary missing). Both mean "proceed".
- `2` — BLOCK verdict. Distinct from `1` so callers can distinguish a
  valid BLOCK verdict from an adapter failure.
- `1` — adapter error (missing preset, missing artifact, malformed
  gate-result).

### Subcommands

- `check` — probe for the conversus binary; emits `available=true|false`.
- `gate <preset> <artifact> <output>` — run the fidelity gate, write
  `gate-result.md` to `<output>`.
- `parse-verdict <gate-result-path>` — emit `verdict=PASS|BLOCK` from an
  existing `gate-result.md`.

### Adding new presets

Future milestones (M013 issue-sync, M014 comment-apply) will reuse this
same adapter with their own presets. To add a preset:

1. Author a new YAML file at
   `templates/conversus-presets/<your-preset>.yml` following the shape of
   `templates/conversus-presets/normalize-fidelity.yml` — a two-entry
   `agents:` list (source-advocate and target-advocate equivalents), an
   `arbiter:` block with `grounding_file` pointing at the constitution,
   and an `output:` block pointing at `templates/gate-result.md`.
2. Invoke this same command with your preset name; the adapter requires
   no changes.

## Workflow

The Conversus gate runs a two-agent cooperative deliberation protocol:

1. **Source-advocate** reads the source artifact and the candidate (the
   artifact under gate). Its charter is preservation: raise a dispute for
   any factual claim, requirement, non-goal, constraint, or acceptance
   criterion that was dropped, paraphrased in a way that changes
   meaning, or silently merged with another claim.
2. **Target-advocate** reads the candidate against the target-shape
   charter encoded in the preset. For `normalize-fidelity`, the target
   shape is the spec-kit layout — the target-advocate raises a dispute
   for any invented requirement (not derivable from source), any heading
   that deviates from the spec-kit layout, or any content that violates
   Constitution Principle I (Context Minimization).
3. **Arbiter** reads both advocates' disputes, weighs them against the
   orchestrator constitution at `.orchestrator/memory/constitution.md`
   (Principle I Context Minimization, Principle II Evidence Before
   Claims), and emits a `PASS` or `BLOCK` verdict.
4. **Adapter** parses the verdict from the written `gate-result.md` and
   exits 0 (PASS) or 2 (BLOCK). Callers map the exit code to their
   pipeline state.

## Idempotency

Same artifact + same preset + same `source_hash` → deterministic verdict
when the conversus binary is seeded deterministically. The adapter
itself is stateless — every `gate` invocation re-runs the deliberation.
Callers that need cached verdicts compare the `source_hash:` frontmatter
field in an existing `gate-result.md` against the current artifact hash
and skip re-running when they match.

When the conversus binary is non-deterministic, re-runs may emit
different verdicts. This is expected; the gate reflects the stochastic
behavior of the underlying deliberation model.

## Error Handling

- **Conversus binary missing** — `gate` emits `SKIPPED: conversus binary
  not available — fidelity gate bypassed` and exits 0. This is graceful
  degradation per the roadmap directive: Conversus is an optional
  external tool, not a hard blocker.
- **Preset file missing** — `FAIL: preset not found: <path>` to stderr,
  exit 1.
- **Artifact file missing** — `FAIL: artifact not found: <path>` to
  stderr, exit 1.
- **Malformed gate-result** — `FAIL:` line describing the parse failure,
  exit 1.
- **Conversus binary non-zero exit** — `FAIL: conversus exited non-zero
  (rc=<n>)`, exit 1.

## Reference Files

- `scripts/dispatch/adapters/tool/conversus.sh` — the tool adapter.
- `templates/conversus-presets/normalize-fidelity.yml` — the M011
  normalize-fidelity preset (canonical example).
- `templates/gate-result.md` — canonical gate-result artifact template.
- `.orchestrator/memory/constitution.md` — arbiter grounding file.
