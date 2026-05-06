---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M029"
name: "JSON renderer + --format=json wiring + SC-3 fixture/script + verifier (FR-3, AD-2, AD-7)"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 has completed: `references/status-json-schema.md` exists and documents the schema_version, top-level keys, the AD-2 unconditional ANSI-strip rule, the degraded-state edge case, and the AD-7 versioning policy. Verify with `[ -f references/status-json-schema.md ]` AND `bash tools/verify/m029-p01-json-schema-contract.sh` exits 0.
- T02 has completed: `scripts/state/detect-invocation-context.sh` exists and emits `renderer=json` under `--format=json`.
- T03 has completed: `commands/status.md` carries the headline block + the resolver-eval at command entry. Verify with `bash tools/verify/m029-p01-status-headline-shape.sh` exits 0.
- `scripts/diagnostics/` exists; sibling helpers (`efficiency-footer.sh`, `metrics-rollup.sh`) follow the source-guard + bash-3.2 + read-only convention.
- No file currently lives at `scripts/diagnostics/render-status-json.sh`; verify `[ ! -f scripts/diagnostics/render-status-json.sh ]`. Path-collision check passed at plan-authoring time.
- `jq` is available on the runtime host (verify with `command -v jq` exits 0). The renderer uses `jq -n` for safe JSON construction.

## Description

T04 implements **FR-3 (`--format=json`)** plus the **AD-2 unconditional ANSI-strip rule** plus the **AD-7 schema_version: "1.0" from day 1** policy.

T04 ships:
- `scripts/diagnostics/render-status-json.sh` — the JSON renderer; the SINGLE ANSI-strip site per AD-2; emits a JSON object validating against `references/status-json-schema.md`.
- A modification to `commands/status.md` adding `--format=json` flag wiring: when `renderer=json` (per the resolver), the headline+flat-sections markdown path is SKIPPED and the JSON renderer's stdout becomes the command's stdout.
- The fixture milestone trees at `tests/m029-acceptance/fixtures/status-json-executing.fixture/` (the SC-3 happy path) and `tests/m029-acceptance/fixtures/status-json-degraded.fixture/` (the corrupt-JSONL edge case from the spec's Edge Cases section).
- The SC-3 acceptance script `tests/m029-acceptance/p01-sc3-format-json.sh` covering the schema_version assertion, every required key via `jq -e`, the ANSI-strip invariant, and the degraded-state path.
- Two shape verifiers (`tools/verify/m029-p01-render-status-json-shape.sh` for the renderer; `tools/verify/m029-p01-status-format-json-wiring.sh` for the commands/status.md wiring; `tools/verify/m029-p01-sc3-shape.sh` for the SC-3 wrapper).

The renderer reads the resolver's env block at entry — but in production, the resolver is invoked WITH the `--format=json` flag set on the parent (status command), so `renderer=json` is already resolved. The renderer's job is to construct the JSON payload, ANSI-strip every section's rendered string unconditionally per AD-2, and emit valid JSON.

## Steps

1. **Author `scripts/diagnostics/render-status-json.sh`** (≥100 lines, executable, bash 3.2 compatible). Required structure:

   - Shebang `#!/usr/bin/env bash` + `set -u`.
   - Header comment naming FR-3, AD-2, AD-7, the single-strip-site invariant, and the schema SSOT (`references/status-json-schema.md`).
   - Re-source guard following the project convention (`_RENDER_STATUS_JSON_SH_SOURCED` scalar).
   - Constant `_M029_SCHEMA_VERSION="1.0"` declared once at the top — single source of truth in the script for the schema_version field. The verifier asserts this constant exists.
   - Argument parser for: `--milestone <Mxxx>` (optional; falls back to `find-active-milestone.sh` when omitted), `--orchestrator-root <path>` (optional; falls back to `scripts/state/resolve-root.sh`), `--help|-h`.
   - Function `_collect_headline_fields()` that reads:
     - milestone ID + name (via `find-active-milestone.sh` + roadmap parse)
     - phase index + count + percent complete (via `read-roadmap.sh` + summary count)
     - lock state (via lock-manager state file read; mirrors the existing pattern in `commands/status.md`'s `### Stale Lock File` section)
     - last-dispatch recency (via JSONL parse; computes `Nh ago` / `Nm ago` / `Ns ago` / `none`)
     - last-verify result (via most-recent `P##-VERIFICATION.md` lookup in active phase)
   - Function `_collect_sections()` that captures the rendered string of each existing flat section. Implementation hint: invoke the existing markdown-rendering scripts/skills (or replicate their logic minimally) and capture stdout; ANSI-strip is applied at the next step. Each section is keyed by a stable lowercase-snake-case name: `progress`, `blockers`, `execution_history`, `telemetry_metrics`, `efficiency_footer`, `next_action`. (Match the section list in `references/status-json-schema.md`.)
   - Function `_ansi_strip()` that takes stdin and emits ANSI-stripped stdout. Primitive: `sed 's/\x1b\[[0-9;]*[mGKHF]//g'`. This is the SINGLE strip site per AD-2.
   - Function `_emit_json()` that builds the JSON object via `jq -n --arg ...` style argument injection (NOT raw printf string concatenation) so quote escaping is mechanically correct. The payload includes:
     - `schema_version: $_M029_SCHEMA_VERSION` (`"1.0"`)
     - `milestone_id`, `milestone_name`, `phase_index`, `phase_count`, `phase_percent_complete`, `lock_state`, `last_dispatch_recency`, `last_verify_result`
     - `sections: { progress, blockers, execution_history, telemetry_metrics, efficiency_footer, next_action }` — every value ANSI-stripped via `_ansi_strip`
   - Degraded-state branch: when JSONL parsing fails (detected via try-parse + capture parse-errors), `_emit_json()` adds `state: "degraded"` and `parse_errors: [...]` to the top level. Other fields populate to whatever extent the partial parse permits. Implementation hint: wrap the JSONL probe in a `jq -c '.' execution-log.jsonl 2>&1 >/dev/null` style check and capture the diagnostic lines; emit them as the `parse_errors` array.
   - Exit 0 on success; exit non-zero only on catastrophic failure (e.g., orchestrator-root resolution fails). Note: corrupt JSONL is NOT a failure — it produces the `state: "degraded"` shape and exits 0.
   - Read-only — never writes to disk.

2. **Modify `commands/status.md` additively** to add `--format=json` flag wiring. Add a new `## Format Flag` section between `## Headline Block` (added in T03) and `## State Derivation`. Required prose:

   > **FR-3 / SC-3 / AD-2 / AD-7.** The `--format=<format>` flag selects the rendering mode. Valid values: `tui` (default; the headline+flat-sections markdown path), `json` (the FR-3 JSON object), `plain` (markdown without ANSI; auto-selected by the resolver under non-TTY).
   >
   > **Resolution.** When `--format=json` is present, the resolver returns `renderer=json`; the headline+flat-sections markdown path is SKIPPED and `bash scripts/diagnostics/render-status-json.sh` is invoked. Its stdout becomes the command's stdout.
   >
   > **Schema.** The JSON output validates against `references/status-json-schema.md`. The top-level `schema_version` field is `"1.0"` per AD-7.
   >
   > **ANSI-strip rule (AD-2).** Every string under `sections` is ANSI-stripped unconditionally regardless of TTY. This applies even on interactive TTYs where `--format=json` is invoked manually — the JSON contract is for downstream tooling (`jq`, CI, `external-tool-adapters`), and stripping ANSI universally avoids contract migrations later.
   >
   > **Degraded state.** When `execution-log.jsonl` parses with errors, the JSON output includes `state: "degraded"` and a `parse_errors` array. The renderer never crashes on a corrupt JSONL stream.

   - Update the `## Reference Files` section to confirm `scripts/diagnostics/render-status-json.sh` and `references/status-json-schema.md` are listed (T03 may already have added these; verify presence and add if absent).

3. **Create the SC-3 happy-path fixture** at `tests/m029-acceptance/fixtures/status-json-executing.fixture/`. Same shape as the SC-2 fixture from T03 (M999 milestone, P01 complete + P02 in-flight, populated execution log with a valid `dispatch_usage` record). Implementation: copy the SC-2 fixture as a starting point, change the milestone slug if needed for fixture isolation, ensure all 3 deliverable files (`M999-ROADMAP.md`, `phases/P01/P01-SUMMARY.md`, `execution-log.jsonl`) carry valid content.

4. **Create the SC-3 degraded-state fixture** at `tests/m029-acceptance/fixtures/status-json-degraded.fixture/`. Same shape as the happy-path fixture, but `execution-log.jsonl` deliberately contains 1–2 invalid lines (e.g., truncated JSON, missing required field, garbage text on its own line). Mix valid and invalid lines so the renderer can both extract partial data AND emit `parse_errors`. Add a comment at the top of the file (a `#` line — illegal in strict JSONL but used here as a fixture-author note that the renderer should tolerate) explaining which lines are deliberately corrupt.

5. **Author `tests/m029-acceptance/p01-sc3-format-json.sh`** (≥80 lines, executable). The script:

   - Sets `set -u` and traps cleanup.
   - Creates a working temp dir; copies the happy-path fixture into it.
   - Runs `orchestrator:status --format=json` against the happy-path fixture; captures stdout to `<tmpdir>/sc3-json.out`.
   - Asserts stdout is parseable JSON: `jq empty <tmpdir>/sc3-json.out` exits 0.
   - Asserts `jq -e '.schema_version == "1.0"' <tmpdir>/sc3-json.out` exits 0.
   - For each required top-level key, runs `jq -e '.<key>' <tmpdir>/sc3-json.out` and asserts exit 0:
     - `.schema_version`, `.milestone_id`, `.milestone_name`, `.phase_index`, `.phase_count`, `.phase_percent_complete`, `.lock_state`, `.last_dispatch_recency`, `.last_verify_result`, `.sections`
   - For each required section key, runs `jq -e '.sections.<section>' <tmpdir>/sc3-json.out` and asserts exit 0:
     - `.sections.progress`, `.sections.blockers`, `.sections.execution_history`, `.sections.telemetry_metrics`, `.sections.efficiency_footer`, `.sections.next_action`
   - Asserts the AD-2 unconditional-strip invariant: `jq -r '.sections | values[]' <tmpdir>/sc3-json.out | grep -c $'\x1b\\[' || true` returns 0 (no ANSI escape sequences anywhere in any section value).
   - Re-runs `orchestrator:status --format=json` against the degraded-state fixture; captures to `<tmpdir>/sc3-degraded.out`.
   - Asserts `jq -e '.state == "degraded"' <tmpdir>/sc3-degraded.out` exits 0.
   - Asserts `jq -e '.parse_errors | length > 0' <tmpdir>/sc3-degraded.out` exits 0.
   - Asserts `jq -e '.schema_version == "1.0"' <tmpdir>/sc3-degraded.out` exits 0 (degraded-state still carries schema_version).
   - Cleanup `rm -rf <tmpdir>` on exit.
   - Tracks pass/fail; emits per-assertion `PASS:` / `FAIL:` lines + final `SC-3: pass=N fail=M`. Exits 0 iff `fail=0`.

6. **Author `tools/verify/m029-p01-render-status-json-shape.sh`** (≥30 lines, executable). The verifier:

   - Gates on file existence: `[ -f scripts/diagnostics/render-status-json.sh ]`. FAIL if missing.
   - Asserts the script is executable.
   - Asserts header comment names FR-3, AD-2, AD-7.
   - Asserts the `_M029_SCHEMA_VERSION="1.0"` constant appears (single source of truth).
   - Asserts the script invokes `jq -n` (the safe-JSON-construction primitive).
   - Asserts the ANSI-strip primitive `\x1b\[[0-9;]*[mGKHF]` appears (the AD-2 single strip site).
   - Asserts the script names the resolver (`scripts/state/detect-invocation-context.sh`).
   - Asserts the degraded-state shape appears: `state` and `parse_errors` literal tokens.
   - Asserts the section names appear: `progress`, `blockers`, `execution_history`, `telemetry_metrics`, `efficiency_footer`, `next_action`.
   - Emits `PASS:` per assertion + `SUMMARY: m029-p01-render-status-json-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

7. **Author `tools/verify/m029-p01-status-format-json-wiring.sh`** (≥25 lines, executable). The verifier:

   - Gates on `[ -f commands/status.md ]`.
   - Asserts `commands/status.md` contains `## Format Flag` (the new T04 section).
   - Asserts `commands/status.md` contains `--format=json` AND `FR-3` AND `AD-2` AND `AD-7`.
   - Asserts `commands/status.md` contains `scripts/diagnostics/render-status-json.sh`.
   - Asserts the Reference Files section names both `references/status-json-schema.md` and `scripts/diagnostics/render-status-json.sh`.
   - Emits `PASS:` per assertion + `SUMMARY: m029-p01-status-format-json-wiring.sh pass=N fail=M`. Exit 0 iff `fail=0`.

8. **Author `tools/verify/m029-p01-sc3-shape.sh`** (≥25 lines, executable). The verifier:

   - Gates on `[ -f tests/m029-acceptance/p01-sc3-format-json.sh ]` AND both fixture dirs exist.
   - Asserts the SC-3 script is executable.
   - Asserts the SC-3 script's header references SC-3 AND FR-3.
   - Asserts the script greps for `schema_version`, `1.0`, `jq -e`, AND `ANSI`.
   - Asserts the degraded fixture's `execution-log.jsonl` contains intentionally-malformed content (greps for at least one line that is NOT a complete JSON object — implementation hint: assert the file contains a line not matching `^\\s*\\{.*\\}\\s*$`).
   - Runs `bash tests/m029-acceptance/p01-sc3-format-json.sh` and asserts exit 0.
   - Emits `PASS:` per assertion + `SUMMARY: m029-p01-sc3-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

9. **Run all verifiers + the SC-3 script** to confirm green.

## Must-Haves

This task addresses these P01 phase truths:
- `scripts/diagnostics/render-status-json.sh` exists and is the AD-2 single ANSI-strip site.
- `commands/status.md` carries `--format=json` flag wiring.
- The SC-3 acceptance script exits 0 (schema_version=1.0, all required keys present via `jq -e`, AD-2 strip invariant holds, degraded state path works).

This task creates these P01 phase artifacts:
- `scripts/diagnostics/render-status-json.sh` — AD-2 single ANSI-strip JSON renderer.
- `commands/status.md` modifications (FR-3 wiring + Reference Files updates).
- `tests/m029-acceptance/fixtures/status-json-executing.fixture/` — fixture milestone tree exercising the executing-state JSON path.
- `tests/m029-acceptance/fixtures/status-json-degraded.fixture/` — fixture milestone tree exercising the degraded-state JSON path (corrupt JSONL).
- `tests/m029-acceptance/p01-sc3-format-json.sh` — SC-3 acceptance script.
- `tools/verify/m029-p01-render-status-json-shape.sh` — renderer shape verifier.
- `tools/verify/m029-p01-status-format-json-wiring.sh` — commands/status.md wiring verifier.
- `tools/verify/m029-p01-sc3-shape.sh` — SC-3 wrapper verifier.

## Verification

```bash
bash tools/verify/m029-p01-render-status-json-shape.sh
```

```bash
bash tools/verify/m029-p01-status-format-json-wiring.sh
```

```bash
bash tools/verify/m029-p01-sc3-shape.sh
```

## Inputs

### From Previous Tasks

- `references/status-json-schema.md` (from T01) — the schema SSOT. T04's renderer reads: top-level keys, canonical shape, AD-2 unconditional ANSI-strip rule, degraded-state shape.
  - Key API: documented top-level keys (10 fields + optional `state` + `parse_errors`), section names (6 sections), AD-2 strip rule (every section value stripped regardless of TTY), AD-7 stability policy.
- `references/status-headline-shape.md` (from T01) — the headline shape contract. T04's renderer reuses the five headline fields as top-level JSON keys (`milestone_id` + `milestone_name`, `phase_index` + `phase_count` + `phase_percent_complete`, `lock_state`, `last_dispatch_recency`, `last_verify_result`).
- `scripts/state/detect-invocation-context.sh` (from T02) — the AD-1 resolver. T04's renderer reads the resolver's env block at entry. In production, status command calls the resolver before deciding whether to invoke T04's renderer; T04's renderer is invoked only under `renderer=json`.
  - Key API: `bash scripts/state/detect-invocation-context.sh` emits 3 lines to stdout; eval'able.
- `commands/status.md` headline-block additions (from T03) — T04 modifies the same file additively to add `## Format Flag` and Reference Files. Both T03 and T04 land additive content in commands/status.md; T04 runs strictly after T03 in the serial executor pipeline to avoid concurrent-edit conflict.

### From Disk (Pre-existing)

- `scripts/state/find-active-milestone.sh` — used to identify the active milestone for headline-field collection.
- `scripts/state/derive-phase.sh`, `scripts/state/read-roadmap.sh` — used for phase index + count.
- `scripts/state/resolve-root.sh` — used to resolve the orchestrator root when `--orchestrator-root` is omitted.
- `scripts/state/read-config.sh` — used to read config knobs (e.g., `efficiency_footer` to know whether to render that section).
- The lock-manager state file (path mirrors `commands/status.md`'s existing `### Stale Lock File` lookup).
- The most recent `P##-VERIFICATION.md` lookup mirrors `commands/status.md`'s existing `### Failed Verification` section.
- `jq` — required runtime dependency; the renderer uses `jq -n --arg` for safe JSON construction. Verify availability at script entry and exit non-zero with a clear diagnostic if missing.

## Constraints

- AD-2 single strip site: `_ansi_strip()` in `render-status-json.sh` is the ONLY ANSI-strip site for JSON output. The legacy markdown flat-section path retains ANSI emission unchanged. Per the spec's #Q-G3 resolution at AD-2: TTY split was rejected for complexity-vs-benefit reasons; unconditional strip is the locked-in invariant.
- AD-7 schema_version: `"1.0"` is locked at day 1. The constant `_M029_SCHEMA_VERSION="1.0"` is the single source of truth in the renderer; the schema doc is the SSOT for the contract; both must agree. Future field additions follow semver-style minor bumps; field removals or type changes require a major bump + deprecation cycle.
- Safe JSON construction: use `jq -n --arg key value` style argument injection; do NOT use raw printf string concatenation. This is mechanically correct (handles quotes, special chars, unicode) and is the project convention for JSON emission.
- Degraded-state behavior: corrupt JSONL is NOT a fatal error. The renderer captures parse errors, emits `state: "degraded"` + `parse_errors: [...]`, populates other fields to the extent partial parsing permits, and exits 0. This is documented in the spec's Edge Cases section.
- Bash 3.2 compatibility (CON-7 carry-forward from `efficiency-footer.sh`): no associative arrays, no case-folding parameter expansion, no process substitution, no herestrings. Mirror the M027 helpers' style.
- Read-only (CON-1 / FR-14): the renderer never writes to `.orchestrator/`, never modifies `execution-log.jsonl`, never invokes external HTTP APIs.
- Per the M029 knowledge-layer boundary (CON-7, AD-8): T04 modifies only `commands/status.md` (additive); creates only the renderer + fixtures + acceptance + verifiers. NO modification to M013/M019/M020/M027 surfaces. NO new schema additions outside `references/status-json-schema.md` (which T01 owns).

## Expected Output

After T04 completes:
- `scripts/diagnostics/render-status-json.sh` exists, is executable, and emits valid JSON validating against `references/status-json-schema.md`.
- `commands/status.md` carries `## Format Flag` section + updated Reference Files.
- Both fixture milestone trees exist (`status-json-executing.fixture/`, `status-json-degraded.fixture/`).
- `tests/m029-acceptance/p01-sc3-format-json.sh` exists, is executable, and exits 0 with `SC-3: pass=N fail=0`.
- All three verifiers (`m029-p01-render-status-json-shape.sh`, `m029-p01-status-format-json-wiring.sh`, `m029-p01-sc3-shape.sh`) exist, are executable, and exit 0.
- A summary file at `.orchestrator/milestones/M029/phases/P01/tasks/T04-status-json-format-SUMMARY.md` documents the deliverables.

## Notes

Expected verifier output: `PASS:` lines for each assertion, ending with `SUMMARY: m029-p01-render-status-json-shape.sh pass=10 fail=0` (and similar for the other two verifiers). Expected SC-3 acceptance output: per-key `PASS:` lines + ANSI invariant + degraded-state assertions, ending with `SC-3: pass=N fail=0`.

The schema_version: "1.0" lock is the load-bearing public-contract decision. M035 packaging consumes the schema as a post-install verification surface; post-launch `external-tool-adapters` consume it for GitHub Projects / Trello / Notion / Linear adapters. Any drift between the schema doc constant ("1.0") and the renderer constant (`_M029_SCHEMA_VERSION`) is a contract violation; the verifiers cross-check both literally.
