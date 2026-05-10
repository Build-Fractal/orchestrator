---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P01"
milestone: "M035"
provides:
  - "drift-line render path wired into both TUI (commands/status.md doc-step) and JSON (render-status-json.sh top-level `drift` object); FR-4/FR-16 suppression matrix implementation; § Drift Line (M035 P01) addendum on status-headline-shape.md + § drift (M035 P01) addendum on status-json-schema.md; m035-p01-drift-line-in-status.sh (SC-4 primary) + m035-p01-drift-line-suppressed.sh (3 sub-cases) + m035-p01-phase-suite.sh AD-19-prefixed P01 aggregator"
requires:
  - "from:P01/T03 what:scripts/state/check-orchestrator-drift.sh four-line key=value stdout block (commits_behind/update_source/upstream_path/versions_behind); from:P01/T01 what:tests/m035-acceptance/fixtures/install-meta-with-sha.txt; from:M029/P01 what:references/status-headline-shape.md + references/status-json-schema.md design contracts + scripts/diagnostics/render-status-json.sh JSON renderer with _M029_SCHEMA_VERSION=1.0 constant"
affects:
  - "P01 (phase summary surface), M035 launch readiness (SC-4 closed), downstream M035 P05 (rollback markers consumed by .previous-version codepath)"
key_files:
  - "scripts/diagnostics/render-status-json.sh,commands/status.md,references/status-headline-shape.md,references/status-json-schema.md,tools/verify/m035-p01-drift-line-in-status.sh,tools/verify/m035-p01-drift-line-suppressed.sh,tools/verify/m035-p01-phase-suite.sh"
key_decisions:
  - "additive `drift` top-level object does NOT bump _M029_SCHEMA_VERSION (AD-7 stability policy honored — inline comment in renderer captures intent; M029 SC-3 acceptance re-run 26/26 green); commits_behind encoded as JSON string (accommodates both numeric and unknown-fallback shapes without parser brittleness); drift object key set is STABLE across availability states (deviation from sections-side suppression-by-omission convention — downstream consumers need stable shape regardless of helper availability); _rsj_collect_drift_block strips trailing /.orchestrator from _RSJ_ORCH_ROOT to compute consumer project root for the helper invocation; verifier sub-case (c) tests render-side suppression matrix with update_source=none rather than helper-unavailable path (the latter is owned by T03 graceful-degrade tests)"
patterns_established:
  - "render-side reuse of T03 helper four-line key=value stdout block via grep+sed parse (no jq dependency on helper invocation; jq used only for envelope assembly); JSON envelope key-set stability under suppression — empty string for rendered_line + zero/none defaults for the rest, NOT key omission (downstream-consumer ergonomics); AD-19 phase-suite aggregator filename mirrors P00 shape (m035-p<NN>-phase-suite.sh) for cross-phase grep discovery; verifier scaffold for render-side drift fixtures = T03 upstream-fixture pattern (mktemp -d + git init + N seeded commits + INITIAL_SHA rewrite of consumer install-meta) + M029 milestone-fixture overlay (cp -R from tests/m029-acceptance/fixtures/status-json-executing.fixture/milestones)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P01/tasks/T04-drift-line-in-status-PAYLOAD.md, .orchestrator/milestones/M035/phases/P01/tasks/T04-drift-line-in-status-PLAN.md"
duration: "70m"
verification_result: "pass"
completed_at: "2026-05-08T13:42:36Z"
---

T04 wires the M035 P01 / T03 drift helper into both render paths
(`commands/status.md` TUI + `scripts/diagnostics/render-status-json.sh`
JSON), appends the § Drift Line (M035 P01) addendum to the [M029](../../../../../milestones/M029/index.md) design
contract, and authors the M035 P01 phase-suite aggregator per AD-19
path discipline.

## Render-side surface

`scripts/diagnostics/render-status-json.sh` gains:

- `_rsj_collect_drift_block()` — invokes
  `scripts/state/check-orchestrator-drift.sh --consumer <project-root>`
  with the project root computed by stripping the trailing
  `.orchestrator` segment from `_RSJ_ORCH_ROOT`. The helper exits 0
  always (FR-15); when missing or unparseable the renderer falls back
  to the `update_source=none`-shaped object so the JSON envelope key
  set is stable across availability states.
- `_rsj_drift_rendered_line()` — implements the FR-4/FR-16 suppression
  matrix: empty string under `update_source=none`, both counts zero,
  or empty data; otherwise the byte-stable line
  `STALE: orchestrator runtime is <N> commits behind upstream — run \`orchestrator:update\``
  with `<N>` being either the integer count or the literal token
  `unknown` (#Q-G5 SHA-absent fallback).
- New top-level `drift` JSON object wired into both jq emission
  branches (happy-path + degraded-state). Keys: `commits_behind`,
  `update_source`, `upstream_path`, `versions_behind`, `rendered_line`.

`commands/status.md` gains a new "Drift line (M035 P01 / FR-4 / SC-4)"
documentation block between the embedded efficiency-footer block and
the flat-sections-invariant block. The block documents the drift-helper
invocation, the four-line `key=value` parse shape, the suppression
matrix, and the byte-stable rendered line. The Reference Files section
now lists `scripts/state/check-orchestrator-drift.sh` and notes the
`render-status-json.sh` extension.

## Schema-version policy (AD-7)

The addition of the top-level `drift` field is an ADDITIVE schema
change. Per AD-7 stability policy at `references/status-json-schema.md`
§ Versioning Policy, additive top-level fields do NOT bump
`_M029_SCHEMA_VERSION`. The constant stays at `"1.0"`. The M029 SC-3
acceptance battery (`tests/m029-acceptance/p01-sc3-format-json.sh`) is
re-run after the change and reports `pass=26 fail=0` — the
`schema_version == "1.0"` byte-for-byte assertion stays green.

A policy comment is inlined in `render-status-json.sh` next to the
drift-collection helpers so future readers see the intent.

## Contract documentation

`references/status-headline-shape.md` gains a new § Drift Line
(M035 P01) section after § CON-5 Suppression Matrix. The section
documents:

- Render conditions (`update_source != none` AND any drift count > 0
  AND helper exited 0 with parseable stdout).
- Byte-stable line shape with U+2014 em-dash + literal backticks.
- The JSON-side `drift` object shape mirrored from the schema doc.
- M029 contract preservation explicit clause (lines 1-3 regex
  unchanged).
- The drift-line POSIX-extended regex
  `^STALE: orchestrator runtime is ([0-9]+|unknown) commits behind upstream — run \`orchestrator:update\`$`.
- AD-7 schema-version policy restated (additive field, no bump).

`references/status-json-schema.md` gains a new § drift (M035 P01)
section before § Versioning Policy documenting the per-key types,
suppression matrix, default-shape under suppression, and the source
binding to `scripts/state/check-orchestrator-drift.sh`.

The two contract files stay paired byte-for-byte on the drift field
shape — both document the five-key object the same way.

## Verifiers

Three new single-script-file verifiers under `tools/verify/`
(AD-19 path discipline; all three filenames embed `m035-p01-`
milestone+phase prefix):

- `m035-p01-drift-line-in-status.sh` (SC-4 primary path) — stages
  a fixture orchestrator-root + fixture upstream git repo (mirrors
  T03's pattern), wires install-meta to the fixture upstream's
  `INITIAL_SHA`, runs `render-status-json.sh`, asserts
  `.drift.update_source == "git"`, `.drift.commits_behind` numeric
  and > 0, `.drift.rendered_line` matches the SC-4 regex, and the
  M029 SC-2 contract (top-level headline keys) is preserved.

- `m035-p01-drift-line-suppressed.sh` (SC-4 suppression paths) —
  three sub-cases. (a) `update_source: none` → empty
  `rendered_line`. (b) `commit_sha == upstream HEAD` AND
  `version == upstream version` → empty `rendered_line` and
  `.drift.commits_behind == "0"`. (c) install-meta absent + config
  set to `update_source: none` → empty `rendered_line` AND the
  `.drift` object retains all five required keys (graceful-degrade
  contract). Each sub-case re-asserts M029 contract preservation.

- `m035-p01-phase-suite.sh` (AD-19-prefixed phase aggregator) —
  mirrors the M035 P00 aggregator filename + body shape; runs all
  seven P01 task-grain verifiers and emits
  `BATTERY: pass=<N> fail=<M>`. Exit 0 iff fail=0.

## Verification

```
$ bash tools/verify/m035-p01-drift-line-in-status.sh
PASS: m035-p01-drift-line-in-status

$ bash tools/verify/m035-p01-drift-line-suppressed.sh
PASS: m035-p01-drift-line-suppressed

$ bash tools/verify/m035-p01-phase-suite.sh
=== m035-p01-phase-suite (M035/P01 aggregator) ===
bash_version=3.2.57(1)-release

PASS: m035-p01-mode-flag.sh
PASS: m035-p01-symlink-source-target.sh
PASS: m035-p01-mode-aware-uninstall.sh
PASS: m035-p01-drift-detection.sh
PASS: m035-p01-drift-detection-sha-absent.sh
PASS: m035-p01-drift-line-in-status.sh
PASS: m035-p01-drift-line-suppressed.sh

BATTERY: pass=7 fail=0
```

All seven P01 task-grain verifiers green. M029 SC-3 acceptance battery
re-run reports `pass=26 fail=0` — schema_version stability and ANSI
strip invariant both preserved.

## Scope-adjacent fixups

None. The drift field is purely additive on the JSON side and the TUI
markdown is documentation only (the live render is performed by the
LLM consuming `commands/status.md`). No existing M029 verifiers,
references, or scrapers required updates beyond the two paired contract
files.

## Constraints honored

- M029 SC-2 preservation: lines 1-3 regex unchanged; verified via
  re-run of `tests/m029-acceptance/p01-sc3-format-json.sh` (26/26).
- AD-7 schema-version policy: `_M029_SCHEMA_VERSION="1.0"` unchanged;
  inline policy comment captures the intent.
- FR-15 (read-only): both render paths only read; helper exits 0
  always.
- FR-16 (suppression): empty `rendered_line` under all three
  suppression branches; verified by `m035-p01-drift-line-suppressed.sh`.
- AD-19 (path discipline): all three new verifiers carry the
  `m035-p01-` prefix.
- Bash 3.2 + shape-guard: no associative arrays, no process
  substitution, no `<<<` herestrings, no jq dependency in the
  helper-collection path. Verifier bodies use `case` and two-token
  `[ ... ] && [ ... ]` pairs (below the AP-009 compound-chain-gt2
  threshold).
