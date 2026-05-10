---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P07"
milestone: "M011"
name: "Shape detection + normalizer wrapper + prompt template + per-artifact verify scripts"
depends_on: []
---

## Prerequisites

- P06 is complete. `commands/ingest.md` exists at roughly 140 lines documenting the P06 thin-wrapper semantics (`--spec-path`, `--slug`, `--milestone`, re-ingest contract, CREATED/SKIPPED/SUPERSEDED/REMOVED stdout prefixes).
- `scripts/knowledge/ingest-spec.sh` from P02/P03 exists and is the downstream chunker this phase wraps. Do NOT modify it.
- `scripts/dispatch/dispatch-interface.sh` exists and resolves the active runtime (Claude Code / Codex / Cursor) via backend-agnostic filename routing (MEM018).
- The `specs/` directory tree at the orchestrator root is writable.
- Bash 3.2 compatibility (MEM001) is mandatory for every new script.

## Description

Create the two new bash scripts and the prompt template that let `orchestrator:ingest` accept arbitrary-shaped markdown. `detect-spec-shape.sh` is a fast, agent-free probe that returns `shape=speckit` or `shape=foreign`. `normalize-spec.sh` is a thin wrapper that (when invoked on a foreign-shaped file) dispatches an agent call through the uniform dispatch interface, using `templates/spec-normalizer-prompt.md` as the prompt body, and writes the agent's normalized markdown output to `specs/<slug>/spec.md` via a temp-file-then-rename so readers never observe a half-written artifact. All agent I/O flows through the existing dispatch interface — no hardcoded LLM HTTP calls (MEM018).

This task also ships the five per-artifact verify scripts that guard the shape of the new files: `m011-p07-shape-detect.sh`, `m011-p07-normalize-wrapper-shape.sh`, `m011-p07-normalizer-template.sh`, and `m011-p07-normalize-idempotent.sh`. (The intensity-policy, conversus-adapter, ingest-doc, e2e, evidence-present, preserve-references, and bash32-compat verify scripts belong to T02/T03/T04.)

## Steps

1. **Create `scripts/knowledge/detect-spec-shape.sh`** (executable, `#!/usr/bin/env bash`, `set -u`). Accept `--spec-path <path>` (required). On missing/unreadable input, emit an error to stderr and exit 1. Otherwise run a set of heading-pattern probes against the file using `grep -Eq` (case-insensitive) for:
   - `^##+[[:space:]]+User[[:space:]]+Stor(y|ies)\b`
   - `^##+[[:space:]]+Functional[[:space:]]+Requirements\b`
   - `^##+[[:space:]]+Acceptance[[:space:]]+(Scenarios|Criteria)\b`
   - `^##+[[:space:]]+(Non-Goals|Constraints|Success[[:space:]]+Criteria)\b`
   - `\b(FR|US|AC|NFR)-[0-9]+\b`
   - `^[[:space:]]*(Given|When|Then)[[:space:]]`
   - `As[[:space:]]+a[[:space:]]+.*,[[:space:]]+I[[:space:]]+want[[:space:]]+`
   Count how many probe families match. If ≥ 3 probe families match, emit `shape=speckit` and `reasons=<csv-of-matched-family-names>`; otherwise emit `shape=foreign` and `reasons=<csv-of-matched-family-names>`. Exit 0 on both outcomes (both are valid). Use parallel indexed arrays (`probe_name_0`, `probe_re_0`) per MEM001 — NO `declare -A`. Emit `PASS:` or `FAIL:` prefixes to stdout per MEM001 structured-output convention.

2. **Create `templates/spec-normalizer-prompt.md`**. Frontmatter: `schema_version: "1.0"`, `type: normalizer-prompt`. Body is the agent prompt itself, using `{{placeholder}}` syntax for `{{source_markdown}}` and `{{slug}}`. The prompt body must instruct the agent to:
   - Read the provided `{{source_markdown}}` in full.
   - Preserve every factual claim, requirement, non-goal, constraint, and acceptance criterion from the source verbatim where the source already states it in a well-formed way.
   - Emit the normalized output as a complete markdown file using the section layout `commands/ingest.md` already expects: `# Feature Specification: ...`, `## Problem Statement`, `## User Scenarios & Testing`, `## Functional Requirements`, `## Acceptance Scenarios`, `## Constraints`, `## Non-Goals`, `## Success Criteria`.
   - Do NOT introduce new requirements that are not derivable from the source.
   - Preserve verbatim source quotes when the source already contains a well-formed requirement sentence.
   - Emit ONLY the normalized markdown body — no commentary, no explanation, no leading/trailing fences.

3. **Create `scripts/knowledge/normalize-spec.sh`** (executable, `#!/usr/bin/env bash`, `set -u`). Accept `--spec-path <source-path>` (required), `--slug <slug>` (required), `--force` (optional, bypass hash check), `--output-dir <dir>` (optional, default `specs`). Behavior:
   - Compute the SHA-256 (or MD5 fallback — `shasum -a 256` on macOS, `sha256sum` on Linux, `md5` as last resort) of the source file and store as `SOURCE_HASH`.
   - Determine output path: `<output-dir>/<slug>/spec.md`.
   - Idempotency check: if the output path exists and contains a `source_hash: "<SOURCE_HASH>"` line in its frontmatter (or a `# Source hash: <SOURCE_HASH>` HTML-comment line if the agent doesn't populate frontmatter), and `--force` was NOT passed, emit `SKIPPED: specs/<slug>/spec.md (source unchanged)` and exit 0 WITHOUT dispatching to the agent.
   - Otherwise, build the prompt by reading `templates/spec-normalizer-prompt.md` and substituting `{{slug}}` with the slug and `{{source_markdown}}` with the source file contents.
   - Dispatch the prompt through `scripts/dispatch/dispatch-interface.sh` (passing the prompt body via stdin or a temp file, per that interface's contract). If the dispatch interface emits a non-zero exit, surface the error and exit 1.
   - Write the agent's stdout response to a temp file at `<output-dir>/<slug>/.spec.normalized.$$.tmp`.
   - Prepend (or update) a comment marker `<!-- source_hash: <SOURCE_HASH> -->` at the top of the temp file so subsequent idempotency checks can detect unchanged input.
   - Rename the temp file to `<output-dir>/<slug>/spec.md` atomically.
   - Emit `NORMALIZED: specs/<slug>/spec.md (source_hash=<SOURCE_HASH>)` to stdout.
   - Exit 0 on success, 1 on any failure (dispatch error, disk-write error, missing source).
   - Stub-mode escape: if the environment variable `NORMALIZER_STUB=1` is set, skip the dispatch-interface call entirely and copy `tests/fixtures/normalized-stub.md` (if it exists) to the output path verbatim (still with the hash marker prepended). This keeps the T04 regression e2e deterministic in CI.

4. **Create `scripts/verify/m011-p07-shape-detect.sh`** (executable). Constructs a throwaway `TMP=$(mktemp -d)` with `trap 'rm -rf "$TMP"' EXIT`. Writes two fixture files: `$TMP/speckit.md` (containing `## User Stories`, `## Functional Requirements`, `FR-001`, `Given/When/Then`) and `$TMP/foreign.md` (containing `# Product PRD`, `Problem`, `Proposal`, no FR-/US-/AC- IDs, no Given/When/Then). Invokes `bash scripts/knowledge/detect-spec-shape.sh --spec-path $TMP/speckit.md` and asserts stdout contains `shape=speckit`. Invokes the same against `$TMP/foreign.md` and asserts stdout contains `shape=foreign`. Emits `PASS: ...` on both assertions passing, `FAIL: ...` otherwise. Exit 0/1 per MEM002. Use `grep -Fq -- "$tok"` for tokens.

5. **Create `scripts/verify/m011-p07-normalize-wrapper-shape.sh`** (executable). Asserts structural properties of `scripts/knowledge/normalize-spec.sh` WITHOUT running it end-to-end (the real dispatch lives in T04's e2e):
   - File exists, is executable.
   - `grep -Fq -- '--spec-path'`, `grep -Fq -- '--slug'`, `grep -Fq -- '--force'` all succeed.
   - `grep -Fq -- 'dispatch-interface.sh'` succeeds (confirming the script routes through the uniform dispatch interface, not a hardcoded LLM call).
   - `grep -Fq -- 'NORMALIZED:'` and `grep -Fq -- 'SKIPPED:'` both succeed (structured output convention).
   - `grep -Fq -- 'NORMALIZER_STUB'` succeeds (stub-mode escape hatch for CI).
   - A no-HTTP-call scan: assert `grep -Eq '(curl|wget)[[:space:]]' scripts/knowledge/normalize-spec.sh` returns false (exit 1). No hardcoded LLM HTTP calls.
   - Emit `PASS: ...` or `FAIL: ...` per check.

6. **Create `scripts/verify/m011-p07-normalizer-template.sh`** (executable). Asserts:
   - `templates/spec-normalizer-prompt.md` exists.
   - Frontmatter contains `schema_version:` and `type: normalizer-prompt`.
   - Body contains the placeholders `{{source_markdown}}` and `{{slug}}`.
   - Body contains a heading-layout instruction mentioning `## Functional Requirements` and `## User Scenarios` (assert via `grep -Fq --`).
   - Body explicitly instructs the agent NOT to introduce new requirements — assert `grep -Eiq -- 'do not introduce' templates/spec-normalizer-prompt.md` or an equivalent phrase is present (the verify script can accept any of: `do not introduce`, `must not add`, `no new requirements`).
   - Emit `PASS: ...` / `FAIL: ...`.

7. **Create `scripts/verify/m011-p07-normalize-idempotent.sh`** (executable). End-to-end idempotency test using the stub path:
   - Construct `TMP=$(mktemp -d)` with trap cleanup.
   - Set `PROJECT_ROOT=$TMP`, `cd $TMP`, `mkdir -p specs tests/fixtures scripts/knowledge scripts/dispatch`.
   - Copy the real `scripts/knowledge/normalize-spec.sh` into the sandbox, mark executable.
   - Write a minimal `tests/fixtures/normalized-stub.md` into the sandbox (5-line skeleton).
   - Write a minimal foreign `$TMP/source.md` (5 lines).
   - Run the normalizer once with `NORMALIZER_STUB=1 bash scripts/knowledge/normalize-spec.sh --spec-path source.md --slug 019-foo` — assert stdout contains `NORMALIZED:` and the file `specs/019-foo/spec.md` exists.
   - Run it a second time unchanged — assert stdout contains `SKIPPED:` and the file's mtime is unchanged (or its content is byte-identical to the first run).
   - Run it a third time with `--force` — assert stdout contains `NORMALIZED:` (force bypasses the hash check).
   - Emit `PASS: ...` / `FAIL: ...` per assertion.

8. **Set executable bits** on all four new scripts via `chmod +x`.

## Must-Haves

From `P07-PLAN.md` Truths, this task is responsible for:

- `scripts/knowledge/detect-spec-shape.sh` exists and emits `shape=speckit|foreign` (Check: `m011-p07-shape-detect.sh`).
- `scripts/knowledge/normalize-spec.sh` exists and routes through the uniform dispatch interface with no hardcoded LLM calls (Check: `m011-p07-normalize-wrapper-shape.sh`).
- `templates/spec-normalizer-prompt.md` exists with the required placeholders and non-introduction directive (Check: `m011-p07-normalizer-template.sh`).
- `scripts/knowledge/normalize-spec.sh` is idempotent against unchanged source (Check: `m011-p07-normalize-idempotent.sh`).

Artifacts this task creates: `detect-spec-shape.sh`, `normalize-spec.sh`, `spec-normalizer-prompt.md`, and the four verify scripts above.

## Verification

Run (single-script-file shape per AD-19):

```
bash scripts/verify/m011-p07-shape-detect.sh
bash scripts/verify/m011-p07-normalize-wrapper-shape.sh
bash scripts/verify/m011-p07-normalizer-template.sh
bash scripts/verify/m011-p07-normalize-idempotent.sh
```

Each must emit `PASS:` on the happy path and exit 0. `FAIL:` on any assertion and exit 1.

## Inputs

### From Previous Tasks
None — T01 has no upstream dependencies within P07.

### From Disk (Pre-existing)
- `scripts/knowledge/ingest-spec.sh` — downstream chunker (read-only; NOT modified in this task). Emits `CREATED:|SKIPPED:|SUPERSEDED:|REMOVED:|REVIEW:` prefixes on stdout.
- `scripts/dispatch/dispatch-interface.sh` — uniform backend-agnostic dispatch entry point. Resolves the active runtime (Claude Code / Codex / Cursor) by filename routing (MEM018). Call shape: accepts a prompt body (via stdin or argv) and emits the agent's response to stdout. `normalize-spec.sh` delegates to it — no hardcoded HTTP calls.
- `templates/` — existing template directory with flat `.md` files using `{{placeholder}}` syntax (MEM013).
- `tests/fixtures/` — existing fixture directory.

## Constraints

- **Bash 3.2 compatible** (MEM001): no `declare -A`, no `mapfile`/`readarray`, no `<(...)` process substitution in assignments. Use parallel indexed arrays for probe name↔regex pairs.
- **BSD grep safety** (MEM012, extended in P06): any grep token that may begin with `-` must use `grep -Fq -- "$tok"` to avoid BSD grep treating it as a flag.
- **No hardcoded LLM HTTP calls** (roadmap directive): `normalize-spec.sh` must dispatch through `scripts/dispatch/dispatch-interface.sh`. The verify script in Step 5 asserts absence of `curl`/`wget`.
- **Atomic file writes** (MEM008): the normalizer writes to `.spec.normalized.$$.tmp` then renames — never to the final path directly.
- **Idempotent on unchanged source** (FR-066): re-running with the same source must emit `SKIPPED:` without re-dispatching.
- **Stub-mode escape hatch**: `NORMALIZER_STUB=1` env var short-circuits the agent call. Required for T04's regression e2e to run deterministically in CI.
- **NO P02/P03 changes**: Do not modify `scripts/knowledge/ingest-spec.sh` or `rebuild-index.sh`. This task is pure-additive.

## Expected Output

- Two new production scripts: `scripts/knowledge/detect-spec-shape.sh`, `scripts/knowledge/normalize-spec.sh`.
- One new template: `templates/spec-normalizer-prompt.md`.
- Four new verify scripts under `scripts/verify/m011-p07-*.sh` as enumerated above.
- All four verify scripts emit `PASS:` and exit 0 when run against the artifacts created in this task.
