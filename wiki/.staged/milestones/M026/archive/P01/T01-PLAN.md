---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M026"
name: "Parity matrix fs-inspection + authoritative artifact"
depends_on: []
---

## Prerequisites

- Both conversus trees readable on disk at:
  - `~/Sites/conversus-oss/` (OSS build source tree)
  - `~/Sites/conversus/` (paid build source tree)
- Seed parity scratch at `.orchestrator/scratch/conversus-oss-migration-parity.md` (read-only input; the `VERIFY`-everywhere version authored at spec-027 scaffolding).
- Smoke-test commentary at `specs/027-conversus-oss-migration/conversus/oss-early-review.md` (read-only input; confirms 4 drift rows 2026-04-23).
- This repo's adapter source at `scripts/dispatch/adapters/tool/conversus.sh` and synth helper at `scripts/dispatch/adapters/tool/conversus-synth.py` (read-only; authoritative statement of which OSS surfaces the orchestrator actually consumes).

## Description

Author the authoritative parity matrix [`.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md`](../../../../milestones/M026/M026-CONVERSUS-PARITY.md) by fs-inspecting both conversus trees row-by-row. Every row in the final matrix must have a non-empty `Verified:` cell drawn from the fixed vocabulary `{verified-identical, verified-drifted, verified-absent, verified-moot}`. The task ships ONLY the data artifact — no adapter code changes land in T01. CON-5 read-only-on-conversus-trees applies: do not modify either tree.

The task retires the 12 scratch-matrix rows by direct fs-inspection AND folds in the 4 smoke-test-confirmed drift rows by reference (tagging them `confirmed 2026-04-23` rather than re-running the conversus invocations). Total row count in the authoritative matrix: 16 minimum.

## Steps

1. **Read the seed matrix and smoke-test inputs.** Read `.orchestrator/scratch/conversus-oss-migration-parity.md` in full (the 12 rows of Section 2). Read `specs/027-conversus-oss-migration/conversus/oss-early-review.md` in full (the 4 smoke-confirmed drift observations: YAML single-doc contract, `agents[].role` requirement, `prompt` vs `system_prompt`, top-level `output:` semantic collision).

2. **fs-inspect the OSS tree row-by-row.** For each scratch-matrix row that requires fs inspection, read the relevant OSS-tree file:

   | Scratch row | OSS files to inspect |
   |---|---|
   | `conversus run <config.yml> --provider ...` | `~/Sites/conversus-oss/conversus/cli.py` (or equivalent entry), `~/Sites/conversus-oss/engine/pipeline.py` |
   | `linter.output_contract` module | `~/Sites/conversus-oss/linter/__init__.py`, `~/Sites/conversus-oss/linter/output_contract.py`, `~/Sites/conversus-oss/linter/models.py` |
   | Config schema (mode/target/output/iterations/agents/arbiter) | `~/Sites/conversus-oss/engine/config.py`, any `schema/*.py` or `conversus.example.yml` |
   | Deliberation modes (red-blue, cooperative) | `~/Sites/conversus-oss/engine/pipeline.py`, `~/Sites/conversus-oss/presets/` |
   | `conversus login anthropic` OAuth path | `~/Sites/conversus-oss/conversus/auth.py` or equivalent + `conversus/cli.py` login subcommand |
   | pipx venv path | `ls ~/.local/pipx/venvs/` — record which of `conversus`, `conversus-oss` (or other names) exist |
   | Upstream PR #28 (claude-code provider) status in OSS | `git log --oneline` in `~/Sites/conversus-oss` (read-only `git log`, no writes); grep for PR-28 subject/SHA |
   | Upstream PR #29 (anthropic parallel-429) status in OSS | same — `git log --oneline` + grep |
   | 26 prebuilt role presets | `ls ~/Sites/conversus-oss/presets/` |
   | Token/cost accounting | `~/Sites/conversus-oss/engine/pipeline.py` + any `usage.py` / cost-tracking module |
   | MCP adapter interface | `ls ~/Sites/conversus-oss/mcp_server.py` presence + contents |

   For each row, capture: (a) the exact file path(s) inspected, (b) the observed shape on OSS, (c) the observed shape on paid (inspect `~/Sites/conversus/` symmetrically for the same rows), (d) the `Verified:` verdict from the fixed vocabulary.

3. **fs-inspect the paid tree symmetrically.** For every OSS row, inspect the same file(s) in `~/Sites/conversus/`. The Paid column records that tree's shape at the time of inspection.

4. **Fold in the 4 smoke-confirmed drift rows by reference.** For these rows, inspect only where needed to capture the Paid-side shape (the OSS-side shape is already stated in oss-early-review.md):

   | Smoke-confirmed row | Notes cell |
   |---|---|
   | Top-level YAML contract (frontmatter rejection) | `confirmed 2026-04-23 via oss-early-review.md` |
   | `agents[].role` required under red-blue on OSS | `confirmed 2026-04-23 via oss-early-review.md` |
   | `agents[].prompt:` (OSS) vs `agents[].system_prompt:` (paid) | `confirmed 2026-04-23 via oss-early-review.md` |
   | Top-level `output:` object (paid) vs string (OSS) | `confirmed 2026-04-23 via oss-early-review.md` |

5. **Write the authoritative matrix** to [`.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md`](../../../../milestones/M026/M026-CONVERSUS-PARITY.md). Required structure:

   ```markdown
   ---
   schema_version: "1.0"
   type: parity-matrix
   milestone: "M026"
   phase: "P01"
   created_at: "2026-04-23"
   status: final
   ---

   # Conversus OSS vs Paid Parity Matrix (M026-authoritative)

   **Reading posture**: every row's `Verified:` cell is populated by fs-inspection
   on 2026-04-23 against `~/Sites/conversus-oss` and `~/Sites/conversus` as they
   exist on the operator's machine today. Verdict vocabulary:
   `verified-identical` (same shape both editions, adapter consumption is safe),
   `verified-drifted` (different shape, adapter or callers must adapt — covered
   in P02 scope or deferred), `verified-absent` (OSS-side surface does not exist;
   escape hatch required), `verified-moot` (surface not consumed by the adapter;
   parity concern is moot).

   ## Consumption Surface

   | Surface | OSS | Paid | Verified | Notes |
   |---|---|---|---|---|
   | `conversus run <config.yml> --provider <p>` CLI | ... | ... | verified-identical | confirmed 2026-04-23 via oss-early-review.md + fs inspect |
   | `linter.output_contract` module importable | ... | ... | verified-... | ... |
   | ... (one row per scratch-matrix row + 4 smoke-confirmed drift rows) ... |

   ## Summary

   - Rows marked `verified-identical`: <count>
   - Rows marked `verified-drifted`: <count>
   - Rows marked `verified-absent`: <count>
   - Rows marked `verified-moot`: <count>

   ## OQ-2 Decision Input

   Per M026-CONTEXT.md OQ-2: if `verified-drifted` + `verified-absent`
   together exceed 3 rows (across the orchestrator consumption surface, not
   counting `verified-moot`), M026's P02 scope narrows per the narrow-scope
   rule. <This section records the count and the narrow-vs-full-scope call.>
   ```

6. **Write the phase-local pointer** to [`.orchestrator/milestones/M026/phases/P01/P01-CONVERSUS-PARITY-MATRIX.md`](../../../../milestones/M026/phases/P01/P01-CONVERSUS-PARITY-MATRIX.md) — a short pointer file so `orchestrator:verify` finds the artifact via the phase-directory convention. Body: a single `See [.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md](../../../../milestones/M026/M026-CONVERSUS-PARITY.md)` line plus a front-matter block (`schema_version: "1.0"`, `type: pointer`).

## Must-Haves

This task satisfies the phase truths:
- "parity matrix exists with required frontmatter + required columns" (matrix-shape truth).
- "parity matrix body covers 12+4 rows with confirmed-2026-04-23 tags" (matrix-coverage truth).
- "pipx venv path for both editions inspected" (pipx-venv-inventory truth — the matrix row captures the inventory; T03 also emits a standalone probe report).

## Verification

```
bash scripts/verify/m026-p01-parity-matrix-shape.sh
bash scripts/verify/m026-p01-parity-matrix-coverage.sh
bash scripts/verify/m026-p01-upstream-readonly.sh
```

Each verifier uses single-script-file shape per AD-19 — no inline compound bash.

Expected output per script: `SUMMARY: pass=N fail=0` and exit 0.

## Inputs

### From Previous Tasks
- None (T01 is the head of the T01/T02/T03 parallel fan).

### From Disk (Pre-existing)
- `.orchestrator/scratch/conversus-oss-migration-parity.md` — 12-row seed matrix (read).
- `specs/027-conversus-oss-migration/conversus/oss-early-review.md` — 4 smoke-confirmed drift rows + pipeline commentary (read).
- `scripts/dispatch/adapters/tool/conversus.sh` — authoritative statement of adapter consumption surface (read; in particular, `_resolve_binary` at lines 52-82, `_parse_verdict` at lines 84-108, and the `python -m linter.output_contract` invocation around line 298).
- `scripts/dispatch/adapters/tool/conversus-synth.py` — consumes the conversus.yml schema (read for config-shape row).
- `tests/test-conversus-adapter-shim.sh` — documents pipx venv-path assumption at lines 119-124 (read).
- `~/Sites/conversus-oss/**` — OSS tree (read-only per CON-5).
- `~/Sites/conversus/**` — paid tree (read-only per CON-5).

## Constraints

- **CON-5 read-only on conversus trees**: no writes, no `git commit`, no `mv`, no `rm` under `~/Sites/conversus*`. Only `cat`/`Read`/`grep`/`ls`/`git log` against those trees.
- **CON-6 dual-write invariant**: Recent Changes dual-write is T04's concern, not T01's. T01 writes only to `.orchestrator/milestones/M026/**`.
- **Matrix vocabulary is fixed**: every `Verified:` cell must be one of `{verified-identical, verified-drifted, verified-absent, verified-moot}`. Free-form verdicts fail the shape gate.
- **Coverage minimum**: 12 scratch-matrix rows + 4 smoke-confirmed drift rows = 16 rows minimum. Adding rows is allowed (e.g., additional surfaces the agent discovers); removing rows is not.

## Expected Output

- [`.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md`](../../../../milestones/M026/M026-CONVERSUS-PARITY.md) — authoritative artifact (80+ lines).
- [`.orchestrator/milestones/M026/phases/P01/P01-CONVERSUS-PARITY-MATRIX.md`](../../../../milestones/M026/phases/P01/P01-CONVERSUS-PARITY-MATRIX.md) — phase-local pointer (5-10 lines).
- Every row's `Verified:` cell non-empty and drawn from the fixed vocabulary.
- OQ-2 Decision Input section naming whether the count of `verified-drifted` + `verified-absent` rows triggers the narrow-scope rule.
