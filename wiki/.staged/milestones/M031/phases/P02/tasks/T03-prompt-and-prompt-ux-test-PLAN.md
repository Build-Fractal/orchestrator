---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M031"
name: "Tier A+ approval prompt (AD-7 + AD-20) + SC-16 prompt UX integration test"
depends_on: ["T02"]
---

## Prerequisites

- T01 complete: classifier extension + AD-16 fixture-provenance + SC-5 test on disk.
- T02 complete: `scripts/intake/lib/task-slug.sh` sourceable + three `templates/dispatch-role-*.md` templates on disk (verified by `bash tools/verify/m031-p02-task-slug-shape.sh` and `bash tools/verify/m031-p02-role-templates-shape.sh`).
- `templates/orchestrator-config-default.yml` declares `tier_a_plus_prompt_summary_lines: 8` (P00 pinned default).
- A way to read `tier_a_plus_prompt_summary_lines` from active config: `scripts/state/read-config.sh` (already used by build-context.sh per the P01/T01 plan) is the canonical config-reader. Verify its presence + invocation contract before authoring the prompt helper.

## Description

T03 ships the AD-7 + AD-20 Tier A+ approval prompt — the single load-bearing UX surface for the entire Tier A+ flow per AD-20 reasoning. The prompt fires once between the research dispatch and the plan dispatch (AD-7 one-prompt convention). Under `--yes` mode the prompt is skipped but a single `research: <path>` audit line MUST emit on stderr.

The prompt protocol (AD-20 mechanical contract):

1. **Plain-language framing** — no `null`, no `{` or `}` JSON-brace tokens, no scaffold-placeholder marker bracket-TODO byte pattern. Reads like a colleague handing off, not a CLI status line.
2. **Inline research summary** — first N lines of `research.md` rendered directly in the prompt body, where N = `tier_a_plus_prompt_summary_lines` from active config (P00 default 8).
3. **Three named single-keystroke options**:
   - `(y) plan against this research` — operator approves; the router proceeds to the plan dispatch.
   - `(n) re-run research with different framing` — operator rejects this research; the router exits non-zero with a `unit_close` record for the research dispatch carrying `aborted: true` (no plan or build dispatch fires).
   - `(c) abort this Tier A+ flow` — operator cancels entirely; exit shape identical to `(n)` but with a different cancel reason recorded.
   - **Default-on-no-answer = `c`** (timeout / EOF / empty-line response treated as cancel).
4. **`(N more lines at <path>)` ellipsis** when `research.md` exceeds the inline summary budget. The literal numeric N MUST equal `(total_lines − inline_lines)` exactly.
5. **Resume-vs-rerun marker** — when the prompt is invoked against a `<task-slug>/research.md` that already existed on disk before this Tier A+ session began (detected via the directory mtime predating the session start, OR via a session-id sidecar T03 may write on first session entry), the prompt prefix MUST include a marker like `[resume from prior research]` or `[fresh research from this session]` so the operator never wonders which they are looking at.
6. **`--yes` skip** — when the helper is invoked with `--yes`, no interactive prompt fires; instead a single line `research: <path>` emits to stderr (the audit trail) and the helper exits 0 to signal "proceed to plan dispatch."
7. **Path emission discipline** — the research findings path emits regardless of mode: in interactive mode embedded in the prompt body and in the `(N more lines at <path>)` ellipsis (when applicable); in `--yes` mode on the dedicated stderr audit line.

T03 ships:

1. `scripts/intake/lib/tier-a-plus-prompt.sh` — the prompt-helper library, sourceable + directly invokable.
2. `tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh` — SC-16 / AD-20 integration test asserting the seven UX contract clauses.
3. `tools/verify/m031-p02-prompt-shape.sh` — shape verifier for the helper.
4. `tools/verify/m031-p02-test-tier-a-plus-prompt-ux-shape.sh` — shape verifier for the SC-16 test.

T03 does NOT amend `scripts/intake/route-to-dispatch.sh` — the router edit is T04's job. T03's helper is the dependency T04 invokes between the research and plan dispatches.

## Steps

1. **Author `scripts/intake/lib/tier-a-plus-prompt.sh`** (executable, bash 3.2-compatible). Suggested CLI surface:

   ```bash
   bash scripts/intake/lib/tier-a-plus-prompt.sh \
       --research-path .orchestrator/tier-a-plus/<slug>/research.md \
       --task-slug <slug> \
       [--yes] \
       [--session-id <id>]
   ```

   Exit codes:
   - 0 = proceed to plan dispatch (operator pressed `y`, OR `--yes` was passed).
   - 1 = re-run research (operator pressed `n`).
   - 2 = abort flow (operator pressed `c` OR timeout/EOF/empty-line; default).

   Required behavior:
   - Read `tier_a_plus_prompt_summary_lines` from active config via `scripts/state/read-config.sh` (or equivalent). Default to 8 if missing.
   - Read first N lines of `--research-path`. Compute remaining lines = `total_lines − N`.
   - If `--yes`: emit `research: <path>` to stderr, exit 0. Do NOT prompt.
   - Else: emit the prompt body to stdout (or stderr — pick the convention that lets the SC-16 test capture it; stdout is conventional for prompt body, stderr for the audit line). Body shape:

     ```
     [<resume-or-fresh marker>]
     Tier A+ research findings: <path>

     <first N lines of research.md>
     (M more lines at <path>)        # only if M > 0

     What now?
       (y) plan against this research
       (n) re-run research with different framing
       (c) abort this Tier A+ flow
     >
     ```

   - Read one character via `read -r -n 1 -t 60 ans` (60-second timeout; 0 chars treated as cancel). Bash 3.2 supports `read -t`.
   - Map `y` → exit 0, `n` → exit 1, `c` or empty/timeout/EOF → exit 2.
   - Resume-vs-rerun marker derivation: if a `<dir>/.session-id` sidecar exists and matches the current `--session-id`, the marker is `[fresh research from this session]`. Otherwise `[resume from prior research]`. T03 ships the helper; T04's router writes the sidecar on its first invocation per session.

   The body MUST NOT contain `null`, MUST NOT contain `{` or `}` characters in the prompt prose, MUST NOT contain the scaffold-placeholder marker bracket-TODO byte pattern.

2. **Author `tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh`** (executable, bash 3.2). SC-16 contract — assert the seven UX-protocol clauses from AD-20:
   - Build a fixture `research.md` under a temp `.orchestrator/tier-a-plus/<test-slug>/` directory containing exactly 20 lines (8 inline + 12 overflow given the P00 default).
   - Invoke the prompt helper with `--yes` mode. Capture stderr. Assert stderr contains exactly one `research: <path>` line. Assert helper exit 0.
   - Invoke the prompt helper interactively, piping `y\n` on stdin. Capture stdout (or whichever stream the helper writes the prompt body to). Assert:
     - Captured output contains the first 8 lines of the fixture verbatim (inline summary).
     - Captured output contains the literal substring `(12 more lines at` followed by the fixture path (ellipsis + path).
     - Captured output contains all three named option labels `(y) plan against this research`, `(n) re-run research with different framing`, `(c) abort this Tier A+ flow`.
     - Captured output contains either `[resume from prior research]` or `[fresh research from this session]` (marker presence).
     - Captured output contains the literal string `null` ZERO times.
     - Captured output contains a `{` character ZERO times AND a `}` character ZERO times.
     - Captured output does NOT contain the literal scaffold-placeholder marker bracket-TODO byte pattern (paraphrase as the seven-character string starting with `[`, `T`, `O`, `D`, `O`, `:`, ` ` per CON-7; the test asserts `grep -F` returns no match for that exact byte sequence).
   - Output: `RESULT: SC-16 pass` on success or `RESULT: SC-16 fail` + diagnostic on failure. Exit 0 iff pass.

3. **Author `tools/verify/m031-p02-prompt-shape.sh`** (executable, bash 3.2). Contract:
   - Assert `scripts/intake/lib/tier-a-plus-prompt.sh` exists, executable, ≥ 100 lines.
   - Assert the file contains the literal substrings `tier_a_plus_prompt_summary_lines`, `research:`, `(y) plan against this research`, `(n) re-run research with different framing`, `(c) abort this Tier A+ flow`, `--yes`, and `more lines at`.
   - Assert the file does NOT contain the byte sequences `null`, `{`, `}` inside the prompt body region (use grep against the file's prompt-printing block — bracket the assertion to lines emitting prompt prose, not lines containing helper-internal logic).
   - Assert the file does NOT contain the scaffold-placeholder marker bracket-TODO byte pattern (per CON-7).
   - Output: a single final stdout line `SUMMARY: m031-p02-prompt-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

4. **Author `tools/verify/m031-p02-test-tier-a-plus-prompt-ux-shape.sh`** (executable, bash 3.2). Contract:
   - Assert `tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh` exists, executable, ≥ 60 lines.
   - Assert the file contains the literal substrings `SC-16`, `AD-20`, `tier_a_plus_prompt_summary_lines`, `(N more lines at`, `--yes`, `(y) plan`, `(n) re-run`, `(c) abort`, and `research:`.
   - Output: a single final stdout line `SUMMARY: m031-p02-test-tier-a-plus-prompt-ux-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

5. **Run both new shape verifiers locally + the SC-16 acceptance test** to confirm exit 0:

   ```bash
   bash tools/verify/m031-p02-prompt-shape.sh
   ```

   ```bash
   bash tools/verify/m031-p02-test-tier-a-plus-prompt-ux-shape.sh
   ```

   ```bash
   bash tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh
   ```

6. **Confirm `scripts/intake/route-to-dispatch.sh` UNCHANGED.** Run `git diff --stat scripts/intake/route-to-dispatch.sh` and confirm zero output. T03 has no business amending the router; that is T04's job.

## Must-Haves

This task addresses the following Must-Haves from `P02-PLAN.md`:
- "scripts/intake/lib/tier-a-plus-prompt.sh exists and implements the AD-7 + AD-20 prompt protocol" (Truth #6; Check via `m031-p02-prompt-shape.sh`)
- "tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh (SC-16 per AD-20) exists, executable, exits 0" (Truth #10; Check via `m031-p02-test-tier-a-plus-prompt-ux-shape.sh`)

## Verification

```bash
bash tools/verify/m031-p02-prompt-shape.sh
```

```bash
bash tools/verify/m031-p02-test-tier-a-plus-prompt-ux-shape.sh
```

```bash
bash tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh
```

## Notes

- Each shape verifier emits `SUMMARY: <script-name> pass=N fail=M`; the SC-16 acceptance script emits `RESULT: SC-16 pass` / `RESULT: SC-16 fail`. Two distinct envelope conventions; both AD-19 compliant.
- Plain-language framing is mechanical, not aesthetic — the SC-16 test asserts ZERO occurrences of `null`, `{`, `}`, and the scaffold-placeholder marker bracket-TODO byte pattern. The contract is verifiable, not subjective.
- Resume-vs-rerun visibility uses a session-id sidecar (`.session-id` file under `<task-slug>/`). T03 ships the helper that reads the sidecar; T04's router writes the sidecar on its first invocation per session. Until T04 lands, the helper falls through to the `[resume from prior research]` marker for any pre-existing `research.md` (correct default — no session was active when the file was written).
- Bash `read -t 60` for the 60-second timeout: bash 3.2 supports the `-t` flag. If the test environment cannot drive interactive `read` reliably, fall back to a `--no-prompt-mode <y|n|c>` test-only flag the SC-16 test passes to bypass `read` while still exercising every other UX clause.
- D020 token hygiene (CON-7): comments and prose in the new files MUST NOT embed the literal scaffold-placeholder open-bracket-TODO-colon byte pattern inside backticked inline code; paraphrase or escape.

## Inputs

### From Previous Tasks

- `scripts/intake/lib/task-slug.sh` (created by T02) — sourceable; exposes `derive_task_slug <description>` returning `<40-char-lower-hyphen-alnum>[-<sha1-4>]`. T03's prompt helper uses the `<task-slug>` derivation indirectly (the helper accepts a `--task-slug` flag from the eventual T04 caller; the helper itself does not derive the slug).
- `templates/dispatch-role-research.md` (created by T02) — declares the `.orchestrator/tier-a-plus/<task-slug>/research.md` output-path convention. T03's helper reads from this path (the path lands as the `--research-path` flag value).

### From Disk (Pre-existing)

- `templates/orchestrator-config-default.yml` — declares `tier_a_plus_prompt_summary_lines: 8`. T03's helper reads this knob via `scripts/state/read-config.sh` (or equivalent).
- `scripts/state/read-config.sh` — canonical config-reader (already used by build-context.sh per P01/T01 plan). Key API: invoked with a key path and returns the value on stdout. Verify the exact invocation form by inspection during authoring.

## Constraints

- **Bash 3.2 compatibility** (MEM001): no `declare -A`, no process substitution, no `$()` containing pipes inside conditionals.
- **No edits to `scripts/intake/route-to-dispatch.sh`** in T03 (T04's job).
- **No edits to `scripts/intake/shape-detect.sh` / `paragraph-classify.sh` / `lib/task-slug.sh`** in T03 (T01 + T02 own those edits).
- **No edits to `templates/dispatch-role-*.md`** in T03 (T02 owns those files).
- **No edits to `templates/orchestrator-config-default.yml`** in T03.
- **SC-12 scope-guard**: T03 MUST NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`.
- **No new state machines / lock files** (CON-4 / DC-4): T03's `.session-id` sidecar is a per-flow scratch file under `.orchestrator/tier-a-plus/<task-slug>/`, NOT a state-machine artifact. The scope-guard treats `.orchestrator/tier-a-plus/` as a permissive prefix.
- **D020 token hygiene** (CON-7): the prompt body MUST NOT embed the scaffold-placeholder marker bracket-TODO byte pattern; the SC-16 test asserts this mechanically.
- **Verifier path discipline** (AD-19 + [M032](../../../../../milestones/M032/index.md) Finding A): project-owned slug-bearing verifiers live under `tools/verify/`, NOT `scripts/verify/`.

## Expected Output

After T03 completes:

1. `scripts/intake/lib/tier-a-plus-prompt.sh` exists, executable, ≥ 100 lines, implements the seven AD-20 UX-protocol clauses.
2. `tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh` exists, executable, exits 0 (`RESULT: SC-16 pass`).
3. `tools/verify/m031-p02-prompt-shape.sh` exists, executable, exits 0.
4. `tools/verify/m031-p02-test-tier-a-plus-prompt-ux-shape.sh` exists, executable, exits 0.
5. `scripts/intake/route-to-dispatch.sh` byte-identical to its pre-T03 state.

T03 leaves the prompt helper on disk + a green SC-16 test. T04 builds on T03 by amending the router to invoke the helper between the research and plan dispatches and to write the `.session-id` sidecar on first session entry per `<task-slug>`.
