---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M018"
name: "Lint script + RUNTIME-ASSUMPTIONS entry + dual-write recent-changes"
depends_on: ["T01"]
---

## Prerequisites

T01 has landed `references/compression-grammar.md` v1.0.0 with frontmatter `status: Draft`, four `## Tier:` sections (filter, tier1, tier2, tier3), each with `**applies-to:**` and `**preserves:**` blocks; a `## Marker Grammar` section; a `## Aggregate Plausibility (SC-9)` section that cites the 34.7% floor; an `## Additive Emitter Invariants (CON-5)` section; and a `## Failure Semantics (FR-2)` section. The document has zero `<TODO:` markers.

## Description

Build the verifier set this phase needs and append the M018/P01 row to `RUNTIME-ASSUMPTIONS.md`. Refresh the `orchestrator:recent-changes` block in `CLAUDE.md` (which the dual-write helper mirrors to `AGENTS.md` — never edit `AGENTS.md` directly per CLAUDE.md guidance + commands/plan-phase.md AGENTS.md dual-write convention).

There are two classes of script in this task:

1. **`scripts/verify/compression-grammar-lint.sh`** — the load-bearing public lint gate named in FR-1 / SC-1. Parses `references/compression-grammar.md`, asserts every `## Tier:` section carries both `**applies-to:**` and `**preserves:**` blocks, emits one `PASS:` line per (tier, artifact-class, preserved-pattern) triple, exits 0 on success / 1 on contract-shape failure with `FAIL:` diagnostics naming the missing block.

2. **Phase-private verifiers** under `scripts/verify/m018-p01-*.sh` — the truth checks the phase plan references. Each is a single-script-file invocation per AD-19; each is bash 3.2 compatible.

## Steps

1. **Author `scripts/verify/compression-grammar-lint.sh`** — the public lint gate (FR-1 / SC-1):

   - Shebang `#!/usr/bin/env bash`, `set -eu`. Bash 3.2 compatible (no `declare -A`, no `[[ ... =~ ... ]]` requiring extended regex flags beyond what 3.2 ships).
   - Argument: optional `<grammar-file>` (default `references/compression-grammar.md`). Exit 1 with `FAIL: file not found: <path>` if absent.
   - Read the file once (`grammar=$(cat "$grammar_file")` is a single command — fine; no pipe inside the substitution, AD-19 safe).
   - Emit one `PASS:` line per assertion that holds; emit `FAIL:` lines on failures; exit 1 if any FAIL emitted.
   - **Required assertions** (each maps to a phase-truth):
     a. Frontmatter present and non-empty (`schema_version`, `type: compression-grammar`, `version`, `status`, `last_revised` all present).
     b. Title `# Compression Grammar` present at top.
     c. Section `## Marker Grammar` present and contains the literal substring `compressed:tier`.
     d. Section `## Preserved-Pattern Vocabulary` present.
     e. Exactly four `## Tier:` headings (`filter`, `tier1`, `tier2`, `tier3`) — verify each name is present.
     f. For each tier section: `**applies-to:**` block present AND `**preserves:**` block present (each contains at least one bullet). Emit `FAIL: tier <name> missing <block>` otherwise.
     g. Section `## Aggregate Plausibility (SC-9)` present and contains the literal `34.7`.
     h. Section `## Additive Emitter Invariants (CON-5)` present.
     i. Section `## Failure Semantics (FR-2)` present and contains `tier_preservation_violation`.
     j. No `<TODO:` markers in the document (count == 0).
     k. For each (tier, artifact-class, preserved-pattern) triple actually present in the document, emit one `PASS: <tier> applies-to:<class> preserves:<pattern>` line — this is the line shape SC-1 / FR-1 calls "one row per triple". The implementation: for each tier section, parse the `**applies-to:**` bullets (lines starting `- ` after `**applies-to:**` until the next blank line) and the `**preserves:**` bullets similarly; cross-product within the tier and emit triples.
   - **Shape constraints** (AD-19 + AP-009):
     - No compound `cmd1 && cmd2 && cmd3` chains. Use sequential statements.
     - No `$(... | ...)` command substitution containing pipes. Capture intermediate values with `>` redirection to temp files instead, or use bash 3.2 `<<<` with `read`.
     - No process substitution `<(...)`, no `<file` redirection nested inside `$(...)`.
     - Inline `for` loops over a fixed set are OK if the loop body is one statement. If the body needs multiple statements, extract a helper function.
     - Tip: use `grep -n` + `awk` to extract block boundaries; pipe to a temp file; read the temp file with a `while read` loop. Pipes between two commands in a top-level position are fine; the AP-009 ban is on compound chains > 2 and on $(...|...) substitution.
   - Length target: ~80–150 lines including comments. Exit codes: 0 PASS, 1 FAIL (file not found, contract-shape failure, or any structural assertion fails).

2. **Author `scripts/verify/m018-p01-grammar-shape.sh`** — phase-truth verifier for "grammar contract has the expected shape":
   - Calls `bash scripts/verify/compression-grammar-lint.sh references/compression-grammar.md` once and propagates its exit code.
   - Adds two extra checks beyond the lint:
     - Frontmatter `version` field matches `^[0-9]+\.[0-9]+\.[0-9]+$` (semver shape).
     - Marker grammar section names all three tier markers (`compressed:tier1`, `compressed:tier2`, `compressed:tier3` — filter does NOT emit a marker per the spec).
   - Single-script-file shape; ~30 lines.

3. **Author `scripts/verify/m018-p01-lint-clean.sh`** — phase-truth verifier for "lint reports clean":
   - Invokes `bash scripts/verify/compression-grammar-lint.sh` and asserts exit 0 + at least one `PASS:` line in stdout.
   - ~20 lines.

4. **Author `scripts/verify/m018-p01-sc9-traceability.sh`** — phase-truth verifier for "grammar defends against the SC-9 34.7% floor":
   - Greps `references/compression-grammar.md` for the literal `34.7` (the calibrated floor) and for each per-tier CI low-bound number (`12.55`, `6.24`, `25.33`, `12.10`).
   - All five literals must be present.
   - ~20 lines.

5. **Author `scripts/verify/m018-p01-runtime-assumptions.sh`** — phase-truth verifier for "RUNTIME-ASSUMPTIONS carries the M018/P01 row":
   - Asserts `RUNTIME-ASSUMPTIONS.md` (at repo root) contains a heading matching `^### M018/P01:` (the entry-schema convention used by existing entries like `### FR-3:`, `### FR-5:` — but the M018 entry is keyed by milestone/phase since this phase introduces a runtime expectation, not a single FR).
   - Asserts the entry has all four required subsections by literal substring: `**Claude Code assumption**`, `**Codex/Cursor fallback**`, `**Milestone / phase**`, `**M009 obligation**`.
   - ~20 lines.

6. **Author `scripts/verify/m018-p01-dual-write-recent.sh`** — phase-truth verifier for "CLAUDE.md and AGENTS.md `recent-changes` block both name M018/P01":
   - Asserts both files contain the literal `M018/P01` inside the `orchestrator:recent-changes` block (between the markers `# >>> orchestrator:recent-changes >>>` and `# <<< orchestrator:recent-changes <<<`).
   - ~20 lines.

7. **Append the M018/P01 entry to `RUNTIME-ASSUMPTIONS.md`** (at repo root). The entry name is `### M018/P01: compression-grammar runtime expectations`. Body (verbatim shape, four required subsections):

   ```markdown
   ### M018/P01: compression-grammar runtime expectations

   - **Claude Code assumption**: Tier 3 auto-compact (FR-8) routes summarization through `scripts/dispatch/dispatch-interface.sh` invoking the runtime's native model. Under Claude Code, this is Anthropic's API via the orchestrator's existing dispatch path; quality of the summary is gated by the eval harness (US-7 / FR-12) before Tier 3 dispatches advance `unit_close`. Filter, Tier 1, and Tier 2 are zero-LLM and runtime-agnostic.
   - **Codex/Cursor fallback**: zero-LLM tiers (filter / Tier 1 / Tier 2) are byte-identical across all three runtimes (FR-13). Tier 3 routes through the same `dispatch-interface.sh` and calls the runtime's native model; the in-band marker `<!-- compressed:tier3 model=<model> ... -->` carries the runtime-specific model name verbatim, and `dispatch_usage` records carry the runtime-specific pricing. Behavior diverges only in the model identity and pricing — the contract (preservation, marker, additive emitter fields) is identical.
   - **Milestone / phase**: M018/P01 (grammar contract authored). Tier code lands across M018/P02–P05; multi-runtime parity audit (US-8) lands in M018/P07 and feeds M009.
   - **M009 obligation**: confirm zero-LLM tier outputs diff-clean across CC / Codex CLI / Cursor on a fixture milestone; confirm Tier 3 outputs differ only in model identity and pricing (in-band marker schema unchanged); accept multi-runtime Tier 3 model divergence as permanent (each runtime calls its own native model — this is correct behavior, not a parity bug).
   ```

   Use `Edit` (single insertion) to append after the last existing `### FR-` entry; do not modify any existing entries. Update the file's `last_updated:` frontmatter to `"2026-04-27"`.

8. **Refresh CLAUDE.md `orchestrator:recent-changes` block**. The current block (read CLAUDE.md to see exact form) ends with:

   ```
   # >>> orchestrator:recent-changes >>>
   - 030-context-compression-layer: M018 — Context Compression Layer. Caveman-style token compression as a pipeline
   # <<< orchestrator:recent-changes <<<
   ```

   Replace with a refreshed entry naming P01:

   ```
   # >>> orchestrator:recent-changes >>>
   - M018/P01 (2026-04-27): Compression Grammar Contract authored at references/compression-grammar.md (v1.0.0); per-tier preservation contract, marker grammar `<!-- compressed:tierN ... -->`, additive emitter invariants (CON-5); SC-9 floor (34.7%) defended via P00 probe CIs; conversus --strict gate PASS archived under .orchestrator/milestones/M018/phases/P01/conversus/.
   # <<< orchestrator:recent-changes <<<
   ```

   Use `Edit` with the literal old block as `old_string` and the new block as `new_string`. The dual-write helper (next step) will mirror this to AGENTS.md.

9. **Run the dual-write helper** to mirror CLAUDE.md to AGENTS.md:

   ```
   bash scripts/util/dual-write-runtime-md.sh
   ```

   Per phase plan rules + commands/plan-phase.md guidance: NEVER edit `AGENTS.md` directly. The helper handles AGENTS.md atomically. If the helper fails, fix the underlying CLAUDE.md issue and re-run; do not fall back to manual AGENTS.md edits.

10. **Self-check the dual-write succeeded** by running the verifier from step 6:

    ```
    bash scripts/verify/m018-p01-dual-write-recent.sh
    ```

    Expected output: `PASS: M018/P01 named in CLAUDE.md recent-changes` and `PASS: M018/P01 named in AGENTS.md recent-changes`.

11. **Run all phase-truth verifiers locally** to confirm the must-haves hold:

    ```
    bash scripts/verify/compression-grammar-lint.sh
    bash scripts/verify/m018-p01-grammar-shape.sh
    bash scripts/verify/m018-p01-lint-clean.sh
    bash scripts/verify/m018-p01-sc9-traceability.sh
    bash scripts/verify/m018-p01-runtime-assumptions.sh
    bash scripts/verify/m018-p01-dual-write-recent.sh
    ```

    All six must exit 0. The conversus-pass verifier (`m018-p01-conversus-pass.sh`) lands in T03; do not author it here.

## Must-Haves

This task addresses the phase must-haves:

- Truth: "lint script reports clean" — implemented by step 1 + verified by step 3.
- Truth: "grammar defends SC-9 34.7% floor by naming per-tier modeling assumptions" — verified by step 4 (numbers planted in T01; shape verifier here).
- Truth: "RUNTIME-ASSUMPTIONS.md carries an M018/P01 entry with the four required subsections" — implemented by step 7 + verified by step 5.
- Truth: "CLAUDE.md and AGENTS.md `recent-changes` block both name M018/P01" — implemented by steps 8–9 + verified by step 6.
- Artifacts (created): all five `m018-p01-*.sh` verifiers + the public `compression-grammar-lint.sh`.
- Artifact (modified): `RUNTIME-ASSUMPTIONS.md`, `CLAUDE.md`, `AGENTS.md` (via dual-write).

## Verification

- `bash scripts/verify/compression-grammar-lint.sh` — exits 0 (FR-1 / SC-1).
- `bash scripts/verify/m018-p01-grammar-shape.sh` — exits 0.
- `bash scripts/verify/m018-p01-lint-clean.sh` — exits 0.
- `bash scripts/verify/m018-p01-sc9-traceability.sh` — exits 0.
- `bash scripts/verify/m018-p01-runtime-assumptions.sh` — exits 0.
- `bash scripts/verify/m018-p01-dual-write-recent.sh` — exits 0.
- `bash scripts/hooks/pre-bash-shape-guard.sh` (or equivalent shape lint, if present) — does not flag the new scripts.

## Inputs

### From Previous Tasks

- `references/compression-grammar.md` (from T01) — the contract document this task lints. Key shape: YAML frontmatter; `# Compression Grammar` title; `## Marker Grammar`, `## Preserved-Pattern Vocabulary`, four `## Tier:` sections (each with `**applies-to:**` and `**preserves:**` blocks), `## Aggregate Plausibility (SC-9)`, `## Additive Emitter Invariants (CON-5)`, `## Failure Semantics (FR-2)`. No `<TODO:` markers.

### From Disk (Pre-existing)

- `RUNTIME-ASSUMPTIONS.md` (at repo root, NOT under `references/` despite the roadmap note — confirmed via filesystem inspection 2026-04-27). Schema documented in its own header: `### <key>:` heading + four required subsections in bold (`**Claude Code assumption**`, `**Codex/Cursor fallback**`, `**Milestone / phase**`, `**M009 obligation**`). Append-only — never modify existing rows.
- `CLAUDE.md` — project instruction file at repo root. Contains an `orchestrator:recent-changes` block delimited by `# >>> orchestrator:recent-changes >>>` / `# <<< orchestrator:recent-changes <<<`. The block is the dual-write source-of-truth.
- `AGENTS.md` — Codex-runtime mirror of CLAUDE.md. NEVER edit directly. The dual-write helper (`scripts/util/dual-write-runtime-md.sh`) mirrors recent-changes block + recent edits.
- `scripts/util/dual-write-runtime-md.sh` — the helper. Behavioral contract: reads CLAUDE.md, writes AGENTS.md to match. Idempotent; re-running produces no diff if already in sync.
- `scripts/verify/m020-p01-mem031-vocabulary.sh` — example single-script-file verifier; mirror its shape (shebang, set -eu, sequential PASS/FAIL emissions, no compound chains).
- `scripts/verify/m018-p00-emitter-parity.sh` — recent example (P00 sibling) of an M018 verifier; mirror its argument parsing + exit-code conventions.

## Constraints

- **Bash 3.2+ / POSIX sh** (NFR-200, MEM001) — no Bash 4 features in any new script.
- **AD-19 (script-file shape)** — every new script is a single-file invocation. Internal logic respects: no compound `&&` chains > 2; no `$(... | ...)` command substitution containing pipes; no plain subshells; no process substitution `<(...)`.
- **AP-009 (compound-chain-gt2)** — pre-bash-shape-guard hook (see error reports in environment) blocks compound chains. Test new scripts BEFORE committing; the hook fires on commit and on bash invocation.
- **MEM001 (Shell Script Conventions)** — structured stdout (`PASS:`, `FAIL:`); errors to stderr; exit 0/1.
- **CON-1 (read-mostly)** — this task creates verifiers + appends one row to RUNTIME-ASSUMPTIONS.md + edits one block in CLAUDE.md + lets the helper edit AGENTS.md. No edits to spec/plan/roadmap/knowledge files.
- **CON-5 (additive-emitter-back-compat)** — verifiers may reference the new emitter fields named in the grammar contract but must not assume they exist on pre-M018 records.
- **AGENTS.md dual-write rule** (project policy + plan-phase command guidance) — never edit AGENTS.md directly; always go through the helper.

## Expected Output

```
$ bash scripts/verify/compression-grammar-lint.sh
PASS: frontmatter present (schema_version, type, version, status, last_revised)
PASS: marker grammar section present
PASS: preserved-pattern vocabulary section present
PASS: tier filter applies-to:knowledge-entry preserves:^---$ (frontmatter delimiter)
PASS: tier filter applies-to:knowledge-entry preserves:^```$ (code fence)
... (one PASS per (tier, artifact-class, preserved-pattern) triple)
PASS: SC-9 plausibility section names 34.7 floor
PASS: additive emitter invariants section present (CON-5)
PASS: failure semantics section names tier_preservation_violation

$ bash scripts/verify/m018-p01-grammar-shape.sh
PASS: compression-grammar-lint clean
PASS: version semver shape
PASS: marker grammar names tier1, tier2, tier3 (filter omitted by design)

$ bash scripts/verify/m018-p01-runtime-assumptions.sh
PASS: M018/P01 entry present in RUNTIME-ASSUMPTIONS.md
PASS: Claude Code assumption subsection present
PASS: Codex/Cursor fallback subsection present
PASS: Milestone / phase subsection present
PASS: M009 obligation subsection present

$ bash scripts/verify/m018-p01-dual-write-recent.sh
PASS: M018/P01 named in CLAUDE.md recent-changes
PASS: M018/P01 named in AGENTS.md recent-changes
```

T03 (conversus gate) consumes the now-clean `references/compression-grammar.md`.
