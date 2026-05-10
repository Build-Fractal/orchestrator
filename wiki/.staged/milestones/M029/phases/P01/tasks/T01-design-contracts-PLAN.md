---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M029"
name: "Design contracts: status-headline-shape.md + status-json-schema.md (Principle III gate)"
depends_on: []
---

## Prerequisites

- The `references/` directory exists and holds sibling design docs (`installation.md`, `state-machine.md`, `engine.md`, etc.); verify `[ -d references ]` at task entry.
- No file currently lives at `references/status-headline-shape.md` or `references/status-json-schema.md`; verify both `[ ! -f references/status-headline-shape.md ]` and `[ ! -f references/status-json-schema.md ]`. Path-collision rule (plan-time discipline rule 6) was checked at plan-authoring time — both paths are clean.
- `tools/verify/` exists and is the canonical project-owned verifier directory.
- The M029 spec body (`specs/037-roadmap-visibility-cli-ux/spec.md`) and context draft ([`.orchestrator/milestones/M029/M029-CONTEXT.md`](../../../../../milestones/M029/M029-CONTEXT.md)) document the load-bearing FR-2/FR-3/AD-1/AD-2/AD-7 + SC-2/SC-3 design-contract clauses; this task plan re-states the load-bearing pieces inline so executors do not need to re-read those documents.

## Description

T01 ships the two **Principle III design contracts** that gate every other P01 task:

1. `references/status-headline-shape.md` — the canonical FR-2 design contract for the `orchestrator:status` headline block. SC-2 of the spec explicitly states this file MUST be on disk before any FR-2 implementation task begins (arbiter ruling 2026-05-05, RISK-7 / MIT-10). T03 (headline block) and T04 (JSON renderer, which reuses headline fields as top-level JSON keys) BOTH consume this contract.

2. `references/status-json-schema.md` — the canonical FR-3 design contract for the `orchestrator:status --format=json` output. SC-3 of the spec explicitly states this file MUST be on disk before any FR-3 implementation task begins (same arbiter ruling). Per AD-7, `schema_version: "1.0"` is declared from day 1; the schema is a public contract for [M035](../../../../../milestones/M035/index.md) packaging post-install verification + post-launch `external-tool-adapters`.

T01 also ships the two **gate verifiers** that enforce those contracts mechanically (`tools/verify/m029-p01-headline-shape-contract.sh`, `tools/verify/m029-p01-json-schema-contract.sh`). The verifiers are not just file-existence checks — they assert each documented field, regex, and required key actually appears in the contract, so that downstream tasks (T03/T04) reading the contract cannot drift from it without breaking the verifier first.

Why ship contracts before code: M029's two highest-priority surfaces (FR-2/SC-2 status headline; FR-3/SC-3 `--format=json`) live behind public-contract surfaces — the headline regex is what every CI scraper greps; the JSON schema is what M035 ships to post-install verifiers and what `external-tool-adapters` consumes. Inverting the order (writing code first, deriving contract later) would lock arbitrary implementation choices into the contract retroactively. Per Principle III + the SC-2/SC-3 explicit clauses, the contract is upstream of code.

## Steps

1. **Create `references/status-headline-shape.md`** (≥60 lines). Required sections (gate verifier asserts each H2 header):

   - `# Status Headline Shape` (H1)
   - `## Purpose` — one paragraph naming FR-2 / SC-2 / `commands/status.md` as consumers and explaining that this contract is the SSOT for the headline shape (every CI scraper that greps the headline reads regex from this file; every implementation reads field order from this file).
   - `## Field Set` — a numbered list documenting the five headline fields in fixed order:
     1. **Milestone ID + name** — `M### <name>` (e.g., `M029 Roadmap Visibility & CLI UX`)
     2. **Phase index + percent complete** — `phase X/N (P_active, K%)` (e.g., `phase 1/3 (P01, 0%)`)
     3. **Lock state** — `lock: <state>` where state ∈ {`free`, `held by PID <pid> since <timestamp>`}
     4. **Last-dispatch recency** — `last_dispatch: <Nh ago | Nm ago | Ns ago | none>`
     5. **Last-verify result** — `last_verify: <pass | fail | none>`
   - `## Line Packing` — documents that the five fields are packed into exactly three non-blank lines:
     - Line 1: field 1 (milestone ID + name)
     - Line 2: fields 2 + 3 separated by `  |  ` (e.g., `phase 1/3 (P01, 0%)  |  lock: free`)
     - Line 3: fields 4 + 5 separated by `  |  ` (e.g., `last_dispatch: 12m ago  |  last_verify: pass`)
   - `## Embedded Footer` — documents that the [M027](../../../../../milestones/M027/index.md) `scripts/diagnostics/efficiency-footer.sh --milestone <active-milestone-id>` line follows the three-line headline block verbatim under `efficiency_footer: true`. Under `efficiency_footer: false` (or `--quiet`), the footer line disappears with no other side effect (CON-5 suppression-matrix inheritance from M027). The footer is governed by M027's resolution chain (env `ORCH_EFFICIENCY_FOOTER` → local config → project config → defaults; default `true`).
   - `## Regex` — the canonical SC-2 regex that asserts the headline shape. Provide it as a fenced block named `headline-regex`:

     ```
     # headline-regex (POSIX extended; tested against the first three non-blank lines of stdout)
     line1: ^M[0-9]{3} .+$
     line2: ^phase [0-9]+/[0-9]+ \(P[0-9]{2}, [0-9]+%\)  \|  lock: (free|held by PID [0-9]+ since .+)$
     line3: ^last_dispatch: ([0-9]+[smhd] ago|none)  \|  last_verify: (pass|fail|none)$
     ```

     The regex strings here are the ground truth that SC-2 (`tests/m029-acceptance/p01-sc2-headline.sh`) greps against the renderer's stdout. T03's headline implementation MUST emit lines that match these regexes byte-for-byte.
   - `## CON-5 Suppression Matrix` — documents that M029 inherits M027's suppression knobs transparently: when `efficiency_footer: false`, the footer line disappears; when other M027 knobs gate sub-surfaces of the footer, those gates propagate. M029 introduces NO new suppression knobs in P01 (AD-5's `display_thresholds.compression_savings_pct` is a P03 deliverable).
   - `## Cross-References` — names `references/status-json-schema.md` (companion contract; the JSON renderer reuses the same five headline fields as top-level JSON keys), `commands/status.md` (consumer), `scripts/diagnostics/efficiency-footer.sh` (M027 footer helper), and the spec entries (FR-2, SC-2, AD-1, CON-5).

2. **Create `references/status-json-schema.md`** (≥70 lines). Required sections (gate verifier asserts each H2 header):

   - `# Status JSON Schema` (H1)
   - `## schema_version` — declares `1.0` as the day-1 value per AD-7. Required prose: "`schema_version` is `\"1.0\"` from day 1. Future field additions are non-breaking under semver-style minor bumps. Field removals or type changes require a major bump and a deprecation cycle. M035 packaging consumes this schema as a public surface; post-launch `external-tool-adapters` consumes it for GitHub Projects / Trello / Notion / Linear adapters."
   - `## Top-Level Keys` — the required keys, each with type and description. Document as a fenced JSON block illustrating the canonical shape:

     ```json
     {
       "schema_version": "1.0",
       "milestone_id": "M029",
       "milestone_name": "Roadmap Visibility & CLI UX",
       "phase_index": 1,
       "phase_count": 3,
       "phase_percent_complete": 0,
       "lock_state": "free",
       "last_dispatch_recency": "12m ago",
       "last_verify_result": "pass",
       "sections": {
         "progress": "Milestone: 0/3 phases complete (0%)\n...",
         "blockers": "...",
         "execution_history": "...",
         "telemetry_metrics": "...",
         "efficiency_footer": "Efficiency (Tier 1 rollup)\n...",
         "next_action": "Run speckit.orchestrator.dispatch to execute the next task."
       }
     }
     ```

     Below the canonical shape, document each top-level key's type (`schema_version: string`, `milestone_id: string`, `milestone_name: string`, `phase_index: integer`, `phase_count: integer`, `phase_percent_complete: integer`, `lock_state: string`, `last_dispatch_recency: string`, `last_verify_result: string`, `sections: object`) and its semantic mapping to the headline fields documented in `references/status-headline-shape.md`.
   - `## sections` — documents the AD-2 unconditional ANSI-strip rule. Required prose: "Every string value under `sections` is ANSI-stripped unconditionally regardless of TTY. The TTY split (auto-strip on pipe/CI, retain on TTY) applies to the legacy markdown flat-section path; under `--format=json`, ANSI is stripped from every section's rendered string before JSON serialization. The strip primitive is `sed 's/\\x1b\\[[0-9;]*[mGKHF]//g'` or equivalent; `scripts/diagnostics/render-status-json.sh` is the single strip site."
   - `## Edge Cases` — documents the corrupt-JSONL-stream → `state: "degraded"` shape:

     ```json
     {
       "schema_version": "1.0",
       "state": "degraded",
       "parse_errors": [
         "line 42: invalid JSON token at column 17",
         "line 88: missing required field 'task_id'"
       ],
       "milestone_id": "M029",
       ...
     }
     ```

     Required prose: "When `execution-log.jsonl` parses with errors, the renderer emits a JSON object with `state: \"degraded\"` and a `parse_errors` array of one human-readable string per invalid line. The renderer never crashes on a corrupt JSONL stream; the operator sees a degraded-but-valid response instead. All other top-level keys remain populated to whatever extent the partial parse permits."
   - `## ANSI Strip Primitive` — documents the exact strip primitive (regex `\x1b\[[0-9;]*[mGKHF]`) so renderer implementations and downstream consumers agree on what an "ANSI-stripped string" means.
   - `## Versioning Policy` — restates AD-7's stability policy (non-breaking minor bumps for field additions; major bumps for removals or type changes; deprecation cycle required) and names the M035 + `external-tool-adapters` downstream consumers.
   - `## Cross-References` — names `references/status-headline-shape.md` (companion contract — the five headline fields are the same), `commands/status.md` (consumer), `scripts/diagnostics/render-status-json.sh` (the single ANSI-strip site), `scripts/state/detect-invocation-context.sh` (resolver feeds the JSON renderer), the spec entries (FR-3, SC-3, AD-1, AD-2, AD-7), and downstream consumers (M035 packaging, post-launch `external-tool-adapters`).

3. **Author `tools/verify/m029-p01-headline-shape-contract.sh`** (≥25 lines, executable). The verifier:

   - First gates on file existence: `[ ! -f references/status-headline-shape.md ]` → FAIL with `references/status-headline-shape.md missing`.
   - Asserts every required H1/H2 header exists via `grep -F`:
     - `# Status Headline Shape`
     - `## Purpose`
     - `## Field Set`
     - `## Line Packing`
     - `## Embedded Footer`
     - `## Regex`
     - `## CON-5 Suppression Matrix`
     - `## Cross-References`
   - Asserts the headline-regex fenced block is present (greps for the literal token `headline-regex`).
   - Asserts the five field names appear (`milestone`, `phase_index`, `lock_state`, `last_dispatch`, `last_verify`).
   - Asserts the FR-2 / SC-2 / CON-5 spec references appear.
   - Emits `PASS:` per assertion + final `SUMMARY: m029-p01-headline-shape-contract.sh pass=N fail=M` line. Exit 0 iff `fail=0`.

4. **Author `tools/verify/m029-p01-json-schema-contract.sh`** (≥25 lines, executable). The verifier:

   - First gates on file existence: `[ ! -f references/status-json-schema.md ]` → FAIL with `references/status-json-schema.md missing`.
   - Asserts every required H1/H2 header exists via `grep -F`:
     - `# Status JSON Schema`
     - `## schema_version`
     - `## Top-Level Keys`
     - `## sections`
     - `## Edge Cases`
     - `## ANSI Strip Primitive`
     - `## Versioning Policy`
     - `## Cross-References`
   - Asserts `schema_version` is declared as `"1.0"` (greps for the literal `"1.0"` AND `schema_version`).
   - Asserts every required top-level key name appears literally (`schema_version`, `milestone_id`, `milestone_name`, `phase_index`, `phase_count`, `phase_percent_complete`, `lock_state`, `last_dispatch_recency`, `last_verify_result`, `sections`).
   - Asserts `state` and `parse_errors` (the AD-2 degraded-state keys) appear.
   - Asserts AD-7 + AD-2 + FR-3 + SC-3 spec references appear.
   - Emits `PASS:` per assertion + final `SUMMARY: m029-p01-json-schema-contract.sh pass=N fail=M` line. Exit 0 iff `fail=0`.

5. **Run both verifiers** — they should exit 0 with `fail=0` after T01 completes. They run again in T06's phase-suite as gate 1 + gate 2.

## Must-Haves

This task addresses these P01 phase truths:
- `references/status-headline-shape.md` exists and is the canonical FR-2 design contract.
- `references/status-json-schema.md` exists and carries `schema_version: "1.0"` from day 1 per AD-7.

This task creates these P01 phase artifacts:
- Headline shape contract: `references/status-headline-shape.md`
- JSON schema contract: `references/status-json-schema.md`
- Headline contract gate verifier: `tools/verify/m029-p01-headline-shape-contract.sh`
- JSON schema contract gate verifier: `tools/verify/m029-p01-json-schema-contract.sh`

## Verification

```bash
bash tools/verify/m029-p01-headline-shape-contract.sh
```

```bash
bash tools/verify/m029-p01-json-schema-contract.sh
```

## Inputs

### From Previous Tasks

None. T01 is the entry point; depends_on is empty.

### From Disk (Pre-existing)

- `references/` — sibling reference docs (`installation.md`, `state-machine.md`, `engine.md`, `file-formats.md`, `events.md`) follow the H1 + `## Purpose` + section-header convention. T01 mirrors that shape.
- `scripts/diagnostics/efficiency-footer.sh` — M027 helper that the FR-2 headline embeds. The headline contract documents the footer's role (verbatim embedding under `efficiency_footer: true`); the contract does not duplicate the footer's internal shape (that's M027's surface).
- `commands/status.md` — current shape (without headline; FR-2/FR-3 wiring lands in T03/T04). The shape contract documents the eventual prepended-headline rendering convention; T03 implements it.
- The M029 spec body and `M029-CONTEXT.md` AD-1/AD-2/AD-7 entries — restated inline above.

## Constraints

- The two contracts MUST NOT contain executable code, only documentation. Implementation lives in T03 (`commands/status.md` + headline render path) and T04 (`scripts/diagnostics/render-status-json.sh` + `--format=json` wiring). Per Principle III + the explicit SC-2/SC-3 design-contract clauses, contracts are upstream of code.
- The headline regex documented in `references/status-headline-shape.md` is the byte-stable ground truth. T03's renderer MUST emit lines matching these regexes byte-for-byte; SC-2 fails on any drift.
- The JSON schema's `schema_version: "1.0"` is locked at day 1 per AD-7. Future post-launch field additions follow semver-style minor bumps; field removals or type changes require a major bump + deprecation cycle.
- The two contracts are paired: the five headline fields documented in `status-headline-shape.md` appear as the corresponding top-level JSON keys in `status-json-schema.md` (`milestone_id` + `milestone_name` ↔ field 1, `phase_index` + `phase_count` + `phase_percent_complete` ↔ field 2, `lock_state` ↔ field 3, `last_dispatch_recency` ↔ field 4, `last_verify_result` ↔ field 5). Drift between the two files is a contract violation; the gate verifiers cross-check the field presence in both directions.
- Per the M029 knowledge-layer boundary (CON-7, AD-8): T01 introduces NO new schema additions to [M013](../../../../../milestones/M013/index.md) sidecar, [M019](../../../../../milestones/M019/index.md) JSONL, [M020](../../../../../milestones/M020/index.md) KNOWLEDGE.md, or M027 surfaces. The two new `references/*.md` files and the two new `tools/verify/*.sh` files are the only artifacts.

## Expected Output

After T01 completes:
- `references/status-headline-shape.md` exists with all eight required sections + the headline-regex fenced block.
- `references/status-json-schema.md` exists with all eight required sections + the canonical JSON shape fenced block + the degraded-state shape fenced block.
- `tools/verify/m029-p01-headline-shape-contract.sh` exists, is executable, and exits 0 when run from project root.
- `tools/verify/m029-p01-json-schema-contract.sh` exists, is executable, and exits 0 when run from project root.
- A summary file at [`.orchestrator/milestones/M029/phases/P01/tasks/T01-design-contracts-SUMMARY.md`](../../../../../milestones/M029/phases/P01/tasks/T01-design-contracts-SUMMARY.md) documents the deliverables.

## Notes

Expected verifier output (per verifier): `PASS:` lines for each assertion, ending with `SUMMARY: m029-p01-<verifier-name>.sh pass=N fail=0` where N is the number of asserted properties (≈10–14 per verifier). The phase-suite aggregator (T06) chains both verifiers as gate 1 and gate 2.

Why these are the load-bearing first task: every later P01 task reads at least one of these contracts. T03's headline implementation reads the field order, line-packing, and regex from `status-headline-shape.md`. T04's JSON renderer reads the top-level keys, the canonical shape, and the AD-2 strip rule from `status-json-schema.md`. T05's context skill cross-references both contracts in its body. T06's phase-suite chains both gate verifiers as the entry gates. Shipping contracts first keeps every implementation honest.
