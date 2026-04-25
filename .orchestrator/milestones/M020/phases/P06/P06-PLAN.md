---
schema_version: "1.0"
type: phase-plan
phase: "P06"
milestone: "M020"
goal: "Ship the FR-6 / US-5 preferences layer: a sourceable `scripts/knowledge/lib/preferences.sh` helper that resolves the five M020 preference keys (`default_state_filter`, `similarity_threshold`, `staleness_threshold`, `preferred_cluster_size`, `operator_identifier`) with project>user>built-in-default precedence per-key (THREAT-007 disposition), wire `scripts/knowledge/query.sh` to consume `default_state_filter` when `--state` is unspecified (preserving FR-8/CON-1 read-only invariant), wire `scripts/knowledge/consolidate-artifacts.sh --cluster` to consume `similarity_threshold` when no positional threshold is supplied (and emit `effective_threshold=<N>` on stdout per SC-5), document the layer at `references/preferences.md` (precedence rules + per-key partial-overlap behavior + malformed-fallback semantics), and ship `tests/test-preferences-resolution.sh` covering SC-5 end-to-end."
demo_sentence: "Setting `similarity_threshold: 0.6` in `.orchestrator/preferences.yml` (project) and `0.8` in `~/.orchestrator/preferences.yml` (user) and then running `bash scripts/knowledge/consolidate-artifacts.sh --cluster .orchestrator MTEST` (no positional threshold) emits `effective_threshold=0.6` on stdout (project wins per FR-6); changing the project file's threshold to a malformed scalar (`similarity_threshold: not-a-number`) and re-running emits `effective_threshold=0.7` on stdout, plus a single-line stderr diagnostic naming the offending key, and never rewrites the preferences file."
risk: "low"
depends_on: ["P02", "P05"]
---

## Must-Haves

### Truths

<!-- Each truth is a behavioral statement + a single-script-file Check.
     Per AD-19, Truth Check commands MUST use single-invocation script-file
     shape — no inline compound bash, no plain subshells, no $() containing
     pipes, no process substitution. Verifier scripts referenced here are
     produced by the listed task; the phase-level Verification Commands
     block at the bottom is the rollup. Plan-deviation invariant from
     P04: every verifier referenced in a task's Verification section MUST
     be authored by THAT task. -->

- `scripts/knowledge/lib/preferences.sh` exists, is sourceable, and exposes `pref_resolve <key>` returning the effective scalar value for any of the five M020 keys (`default_state_filter`, `similarity_threshold`, `staleness_threshold`, `preferred_cluster_size`, `operator_identifier`) on stdout, with built-in defaults baked in (`graduated`, `0.7`, `14`, `8`, `unknown@local`).
  - Check: `bash scripts/verify/m020-p06-preferences-helper-contract.sh`
- `scripts/knowledge/lib/preferences.sh::pref_resolve` honors project>user>built-in-default precedence per-key (THREAT-007 disposition): when both files declare the same key, the project file wins; when only the user file declares it, the user value wins; when neither declares it, the built-in default is returned.
  - Check: `bash scripts/verify/m020-p06-preferences-precedence.sh`
- `scripts/knowledge/lib/preferences.sh::pref_resolve` falls back to the built-in default when a preference value is malformed (non-numeric for numeric keys, out-of-range for bounded keys, value outside the closed enum for `default_state_filter`), emits a single-line stderr diagnostic naming the offending key + offending value + selected fallback, and NEVER mutates the preferences file (operator-owned).
  - Check: `bash scripts/verify/m020-p06-preferences-malformed-fallback.sh`
- `scripts/knowledge/lib/preferences.sh::pref_resolve` rejects unknown keys (closed-enum key vocabulary, matching the schema-authority pattern of MEM031): an unknown key emits `FAIL: pref_resolve: unknown key '<key>'` on stderr and returns non-zero exit, with no stdout output.
  - Check: `bash scripts/verify/m020-p06-preferences-key-vocabulary.sh`
- `scripts/knowledge/query.sh`, when invoked without an explicit `--state` flag, resolves the effective state filter via `pref_resolve default_state_filter` (project>user>built-in `graduated`); when invoked WITH an explicit `--state <S>` flag, the CLI value wins over any preference declaration (CLI > project > user > default).
  - Check: `bash scripts/verify/m020-p06-query-state-from-pref.sh`
- `scripts/knowledge/query.sh` preferences-resolution path is read-only (FR-8 / CON-1): a battery of query invocations against fixture preference files leaves both the preference files AND the knowledge tree byte-identical (md5 snapshot diff before/after).
  - Check: `bash scripts/verify/m020-p06-query-pref-side-effect-free.sh`
- `scripts/knowledge/consolidate-artifacts.sh --cluster`, when invoked without a positional threshold, resolves the effective threshold via `pref_resolve similarity_threshold` (project>user>built-in `0.7`) and emits a single `effective_threshold=<N>` line on stdout BEFORE the per-cluster output blocks; when invoked WITH a positional threshold, the CLI value wins over any preference declaration (CLI > project > user > default).
  - Check: `bash scripts/verify/m020-p06-consolidate-effective-threshold.sh`
- `scripts/knowledge/consolidate-artifacts.sh --cluster` legacy invocation shape (no preferences file, explicit positional threshold) preserves byte-equivalent observable behavior (CON-4): no `effective_threshold=` line is emitted to stdout when the CLI passes an explicit threshold AND no preferences file exists, OR the emitted `effective_threshold=` value matches the CLI argument exactly.
  - Check: `bash scripts/verify/m020-p06-consolidate-cli-precedence.sh`
- `references/preferences.md` documents the five preference keys with their built-in defaults, the project>user>default precedence rule, the per-key partial-overlap behavior (THREAT-007 — each key resolves independently; partial overlap is not a conflict), the malformed-value fallback semantics with a worked example, and the closed-enum key vocabulary.
  - Check: `bash scripts/verify/m020-p06-preferences-doc-content.sh`
- `tests/test-preferences-resolution.sh` exists, is executable, and exits 0 covering SC-5 (project=0.6, user=0.8 → effective=0.6 propagates through `consolidate-artifacts.sh --cluster`), per-key precedence (state-filter through `query.sh`), and malformed-value fallback (project file with `similarity_threshold: not-a-number` → effective=0.7 + stderr diagnostic).
  - Check: `bash tests/test-preferences-resolution.sh`

### Artifacts

- `scripts/knowledge/lib/preferences.sh` (min 100 lines, contains "pref_resolve")
- `scripts/knowledge/query.sh` (min 110 lines, contains "default_state_filter")
- `scripts/knowledge/consolidate-artifacts.sh` (min 290 lines, contains "effective_threshold=")
- `references/preferences.md` (min 80 lines, contains "similarity_threshold")
- `tests/test-preferences-resolution.sh` (min 150 lines, contains "effective_threshold=")
- `scripts/verify/m020-p06-preferences-helper-contract.sh` (min 50 lines, contains "pref_resolve")
- `scripts/verify/m020-p06-preferences-precedence.sh` (min 50 lines, contains "project")
- `scripts/verify/m020-p06-preferences-malformed-fallback.sh` (min 50 lines, contains "malformed")
- `scripts/verify/m020-p06-preferences-key-vocabulary.sh` (min 40 lines, contains "unknown key")
- `scripts/verify/m020-p06-query-state-from-pref.sh` (min 50 lines, contains "default_state_filter")
- `scripts/verify/m020-p06-query-pref-side-effect-free.sh` (min 60 lines, contains "md5")
- `scripts/verify/m020-p06-consolidate-effective-threshold.sh` (min 60 lines, contains "effective_threshold=")
- `scripts/verify/m020-p06-consolidate-cli-precedence.sh` (min 50 lines, contains "CLI")
- `scripts/verify/m020-p06-preferences-doc-content.sh` (min 40 lines, contains "preferences.md")

### Key Links

- `scripts/knowledge/query.sh` → `scripts/knowledge/lib/preferences.sh` (query.sh sources preferences.sh and calls `pref_resolve default_state_filter` when no `--state` is supplied; comment in query.sh names the file)
- `scripts/knowledge/consolidate-artifacts.sh` → `scripts/knowledge/lib/preferences.sh` (consolidate sources preferences.sh from inside the `--cluster` short-circuit and calls `pref_resolve similarity_threshold` when no positional threshold is supplied; comment in consolidate header names the file)
- `tests/test-preferences-resolution.sh` → `scripts/knowledge/lib/preferences.sh` (test sources preferences.sh and exercises pref_resolve directly + indirectly through query.sh and consolidate-artifacts.sh)
- `references/preferences.md` → `scripts/knowledge/lib/preferences.sh` (doc names the helper file path and the five keys verbatim)

## Tasks

### T01: Preferences helper (`scripts/knowledge/lib/preferences.sh`)

See `tasks/T01-preferences-helper-PLAN.md`.

Lands the FR-6 / AD-5 sourceable helper. One callable surface: `pref_resolve <key>` echoes the effective scalar value of the named preference on stdout, applying project>user>built-in-default precedence per-key. Closed-enum key vocabulary: `default_state_filter`, `similarity_threshold`, `staleness_threshold`, `preferred_cluster_size`, `operator_identifier`. Built-in defaults: `graduated`, `0.7`, `14`, `8`, `unknown@local`. Scalar-only YAML parsing via grep+sed (AD-5 — no full YAML parser dependency). Malformed values fall back to default with a single-line stderr diagnostic; the preferences file is never mutated. Path resolution honors `HOME` and `PROJECT_ROOT` env vars for fixture isolation (matching the P01–P05 verifier convention). T01 ships four contract verifiers (helper-contract, precedence, malformed-fallback, key-vocabulary). Pure read-only helper — no writes anywhere. Bash 3.2 safe.

### T02: Wire `query.sh` to preferences

See `tasks/T02-query-integration-PLAN.md`.

Extends `scripts/knowledge/query.sh` IN PLACE (CON-4 byte-equivalent surface preservation for the existing `--topic` / `--state` / `--format` invocation shape). Sources `lib/preferences.sh` early; replaces the hard-coded `state_filter="graduated"` initial value with a deferred resolution: when the argument loop completes WITHOUT having seen a `--state` flag, call `pref_resolve default_state_filter` and use that value. When the argument loop DID see a `--state` flag, the CLI wins (matches existing behavior + P02's read-only invariant). FR-8 / CON-1 preserved: preferences.sh is read-only; `pref_resolve` writes nothing. T02 ships two verifiers: state-from-pref (precedence: CLI > project > user > default) and pref-side-effect-free (md5 snapshot battery — both knowledge tree AND fixture preference files unchanged across N invocations).

### T03: Wire `consolidate-artifacts.sh --cluster` to preferences + emit `effective_threshold=`

See `tasks/T03-consolidate-integration-PLAN.md`.

Extends `scripts/knowledge/consolidate-artifacts.sh` IN PLACE inside the existing `--cluster` short-circuit block (CON-4: legacy two-positional invocation shape and the existing `--cluster <orch-root> <milestone-id> [<knowledge-root>] [<threshold>]` shape both preserved byte-equivalent). Sources `lib/preferences.sh` from inside the `--cluster` arm. When the positional threshold is unset, resolve it via `pref_resolve similarity_threshold`. When it is set on the CLI, use the CLI value. EITHER WAY emit a single `effective_threshold=<N>` line on stdout BEFORE the per-cluster output block (this is what SC-5 asserts and what makes operator runs auditable). Plumb the resolved threshold through to `cluster_compute` exactly as the existing code does. JSONL `threshold_used=` field already populated from the same variable — no JSONL shape change. T03 ships two verifiers: consolidate-effective-threshold (preference resolution + stdout line ordering) and consolidate-cli-precedence (CLI > preference > default; legacy byte-equivalent behavior preserved when the CLI supplies an explicit threshold).

### T04: Documentation + integration test (`references/preferences.md` + `tests/test-preferences-resolution.sh`)

See `tasks/T04-docs-integration-test-PLAN.md`.

Documentation deliverable: `references/preferences.md` describes the five keys, their built-in defaults, the project>user>default precedence rule, the per-key partial-overlap behavior (THREAT-007 disposition: each key resolves independently — declaring `similarity_threshold` at project and `staleness_threshold` at user means project wins for the first and user wins for the second), the malformed-value fallback semantics with a worked example showing the stderr diagnostic, the closed-enum key vocabulary, and three operator-runbook scenarios (single-operator project, multi-operator project, project with no preferences file at all). Integration test deliverable: `tests/test-preferences-resolution.sh` exercises SC-5 end-to-end through the production scripts: (a) project=0.6 + user=0.8 → `consolidate-artifacts.sh --cluster` emits `effective_threshold=0.6`; (b) state-filter precedence through `query.sh` (project=`candidate` overrides user=`graduated`); (c) malformed-value fallback (project file with `similarity_threshold: not-a-number` → `effective_threshold=0.7` + stderr diagnostic). Bash 3.2 + tempdir + `HOME` / `PROJECT_ROOT` / `ORCH_ROOT` env-override fixture isolation per the P03/P04/P05 pattern. T04 ships one verifier: preferences-doc-content (asserts the doc names the five keys, the precedence rule, and a worked malformed example).

## Task Dependencies

```
T01 ──► T02 ──┐
          │   │
          ▼   ▼
       T03 ──► T04
```

- **T01 (preferences-helper)** is a fresh sourceable helper with no dependencies on other P06 tasks. Consumes only stable upstream contracts: standard `HOME` env var resolution, `PROJECT_ROOT` env var convention from P01/P02 verifier patterns, and the closed-enum vocabulary established in this plan. Ships the `pref_resolve` callable.
- **T02 (query-integration)** depends on T01 (`pref_resolve default_state_filter`). Modifies `query.sh` in place; preserves the existing `--state` CLI flag's precedence over preferences (CLI > pref > default).
- **T03 (consolidate-integration)** depends on T01 (`pref_resolve similarity_threshold`). Modifies `consolidate-artifacts.sh` in place inside the `--cluster` short-circuit; preserves the existing positional-threshold's precedence over preferences (CLI > pref > default). Independent of T02.
- **T04 (docs + integration test)** depends on T01 (helper exists), T02 (query.sh wired), and T03 (consolidate wired). Lands documentation + the SC-5 end-to-end integration test that asserts the full preferences cascade through both production consumers.

Auto-loop dispatch order: T01 first; T02 and T03 in either order (or in parallel) once T01 ships; T04 last.

## Verification Commands

<!-- Cross-task invariants and phase-level rollups. Per-task verifiers
     live under each task's own ## Verification block; the commands here
     are the phase-completion gate that runs after T04 ships. Per the
     P01–P05 retrospective lesson: NEVER reference verifier scripts
     created by future tasks from inside a task's own verification
     block. Cross-task assertions belong here. -->

```bash
# Phase rollup — runs every must-have Check: command above.
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M020/phases/P06

# Integration test — exercises SC-5 end-to-end through both production consumers.
bash tests/test-preferences-resolution.sh

# Sanity: confirm CON-4 byte-equivalent surface preservation for query.sh
# (P02 test still green after T02's in-place edit).
bash tests/test-knowledge-query.sh

# Sanity: confirm CON-4 byte-equivalent surface preservation for
# consolidate-artifacts.sh --cluster (P05 test still green after T03's
# in-place edit).
bash tests/test-jaccard-clustering.sh
```

Phase passes when all must-have `Check:` commands exit 0, the integration test exits 0, and both upstream tests (P02 + P05) remain green proving CON-4 byte-equivalent observable behavior was preserved across the in-place edits.

## Files Likely Touched

- `scripts/knowledge/lib/preferences.sh` (create)
- `scripts/knowledge/query.sh` (modify — source preferences.sh + deferred state-filter resolution)
- `scripts/knowledge/consolidate-artifacts.sh` (modify — source preferences.sh inside `--cluster` arm + emit `effective_threshold=` line + threshold resolution)
- `references/preferences.md` (create)
- `tests/test-preferences-resolution.sh` (create)
- `scripts/verify/m020-p06-preferences-helper-contract.sh` (create)
- `scripts/verify/m020-p06-preferences-precedence.sh` (create)
- `scripts/verify/m020-p06-preferences-malformed-fallback.sh` (create)
- `scripts/verify/m020-p06-preferences-key-vocabulary.sh` (create)
- `scripts/verify/m020-p06-query-state-from-pref.sh` (create)
- `scripts/verify/m020-p06-query-pref-side-effect-free.sh` (create)
- `scripts/verify/m020-p06-consolidate-effective-threshold.sh` (create)
- `scripts/verify/m020-p06-consolidate-cli-precedence.sh` (create)
- `scripts/verify/m020-p06-preferences-doc-content.sh` (create)
