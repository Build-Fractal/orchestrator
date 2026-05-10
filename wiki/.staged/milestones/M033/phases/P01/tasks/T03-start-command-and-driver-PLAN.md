---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M033"
name: "commands/start.md + scripts/lifecycle/start.sh skeleton + sub-flow stubs + disambiguation question"
depends_on: ["T01", "T02"]
---

## Prerequisites

- T01 complete: `tests/fixtures/m033-pbj-materials-fixture/` exists with the four PBJ-shape `.md` files (PRODUCT-BRIEF, MVP-PLAN, DECISIONS, MILESTONE-AUDIT) — used as the rule-2 fixture during T03's dev-loop sanity checks (verified by `[ -d tests/fixtures/m033-pbj-materials-fixture ]`).
- T02 complete: `references/branch-detection.md` exists with the four `branch-detection-rule-N` fenced blocks containing the literal pattern strings — verified by `[ -f references/branch-detection.md ]`. T03 reads these patterns and authors them verbatim into start.sh so the parity verifier passes.
- `scripts/lifecycle/init-project.sh` exists (M001/[M015](../../../../../milestones/M015/index.md) closed) and accepts `--project-dir <path>` per existing contract — verified by `[ -f scripts/lifecycle/init-project.sh ]`.
- `commands/init.md` exists (M001) — used as the canonical command-document shape reference per MEM012.
- `commands/start.md` does NOT yet exist — verified by `[ ! -f commands/start.md ]`.
- `scripts/lifecycle/start.sh` does NOT yet exist — verified by `[ ! -f scripts/lifecycle/start.sh ]`.
- `tools/verify/` exists.

## Description

T03 ships the load-bearing P01 deliverables: the `commands/start.md` command document and the `scripts/lifecycle/start.sh` driver. The driver implements FR-1's flag set, FR-2's deterministic branch-detection ordered rules (using the patterns from T02's SSOT), idempotent `init-project.sh` invocation, the four per-branch sub-flow stubs that print `would-execute:` diagnostics, and the US-1 AS-5 + MIT-006 / RISK-006 disambiguation questions. The command document follows the MEM012 canonical shape (frontmatter `description:`; Title; Prerequisites/State Check; Core Workflow; Output; Idempotency; Error Handling; Referenced Scripts).

**Bash 3.2 compatibility (MEM001):** start.sh MUST run on macOS bash 3.2. No associative arrays (`declare -A`); use parallel indexed arrays. No process substitution. No `$(...)` containing pipes. Structured output: PASS/FAIL/SUMMARY prefixed lines to stdout; warnings to stderr.

**Sub-flow stubs are deliberately vacuous in P01.** Each stub is a small bash function (or sourced helper, single-script-file shape):

```bash
ideation_stub() {
  printf 'would-execute: ideation-stub --project-dir %s\n' "$PROJECT_DIR"
  return 0
}
materials_intake_stub() {
  printf 'would-execute: materials-intake-stub --project-dir %s\n' "$PROJECT_DIR"
  return 0
}
ingest_codebase_stub() {
  printf 'would-execute: ingest-codebase-stub --project-dir %s\n' "$PROJECT_DIR"
  return 0
}
migrate_routing_stub() {
  printf 'would-execute: migrate-routing-stub --project-dir %s --from %s\n' "$PROJECT_DIR" "$DETECTED_FROM"
  return 0
}
```

The stubs are dispatched by branch name after init completes. P02–P05 replace them with real sub-flow logic; the FR-1 contract (`branch:` output line + `would-execute:` dispatch line + exit 0) is the surface SC-1 verifies.

## Steps

1. **Author `commands/start.md`** (≥80 lines). Required structure per MEM012:

   ```markdown
   ---
   description: "orchestrator:start — warm conversational front door for any new orchestrator-managed project. Detects which of four starting states a user is in (greenfield-empty / greenfield-with-materials / existing-codebase / migrating), invokes init, and routes to the per-branch sub-flow."
   ---

   # orchestrator:start

   ## Prerequisites

   - The project directory exists and is readable.
   - bash 3.2+ on PATH.

   ## Core Workflow

   1. Parse flags ...
   2. Probe filesystem for branch signals per FR-2 ...
   3. Invoke `bash scripts/lifecycle/init-project.sh --project-dir <path>` exactly once (skip if `<path>/.orchestrator/config.yml` exists) ...
   4. Disambiguate ambiguous signals via grilling-protocol-shaped question per US-1 AS-5 ...
   5. Dispatch to per-branch sub-flow stub ...

   ## Output

   - stdout: `branch: <name>` line, `would-execute: <stub-name> --project-dir <path>` line, exit 0.

   ## Idempotency

   Running `start` twice in a row against the same project dir invokes init exactly once total (per Edge Case `init already ran`), and dispatches the sub-flow stub on each invocation.

   ## Error Handling

   - Unknown flag → exit 2 with usage diagnostic.
   - Branch detection ambiguity under `--yes` → resolves per documented ordering rules (rule-1 wins).
   - Operator-supplied unknown `--branch` value → exit non-zero with the closed enum listed.

   ## Referenced Scripts

   - `scripts/lifecycle/start.sh` — the driver
   - `scripts/lifecycle/init-project.sh` — invoked exactly once
   - `references/branch-detection.md` — SSOT for FR-2 detection rules
   ```

   The body MUST contain the literal tokens `orchestrator:start`, `warm conversational front door`, `scripts/lifecycle/start.sh`, `references/branch-detection.md`, `init-project.sh`. The command document is a documentation artifact — no executable code.

2. **Author `scripts/lifecycle/start.sh`** (≥200 lines, executable, `chmod +x`, bash 3.2 compatible).

   2a. **Header.** Hashbang `#!/usr/bin/env bash`, set `-e -u -o pipefail`, brief comment block naming the script (FR-1 + FR-2), the spec reference (M033 / 036-project-onboarding-experience), and the SSOT cross-reference (`references/branch-detection.md`).

   2b. **Flag parsing.** Accept `--project-dir <path>` (default `pwd`), `--yes` (boolean), `--branch <name>` (validated against the closed enum `greenfield-empty | greenfield-with-materials | existing-codebase | migrating`; unknown values exit non-zero with the enum echoed), `--stack <name>` (forwarded only — sub-flow stubs ignore it in P01), `--dry-run` (boolean). Unknown flags exit 2 with `usage: start.sh [--project-dir PATH] [--yes] [--branch NAME] [--stack NAME] [--dry-run]`.

   2c. **Init invocation (idempotent).** If `[ ! -f "$PROJECT_DIR/.orchestrator/config.yml" ]`, invoke `bash scripts/lifecycle/init-project.sh --project-dir "$PROJECT_DIR"` and capture exit code. Else, print `init already complete, proceeding to branch sub-flow` to stdout. The diagnostic string `init already complete` is the literal token SC-1 greps for. Use a sentinel variable (`INIT_INVOKED=1` or `0`) to drive the SC-1 idempotency assertion.

   2d. **Branch detection** (FR-2 ordered rules). Author the patterns from T02's SSOT verbatim. Implementation sketch:

   ```bash
   detect_branch() {
     local proj="$1"
     # Rule 1: prior-tooling artifacts → migrating
     if [ -d "$proj/.gsd" ] || [ -d "$proj/.gsd2" ] || [ -d "$proj/.specify" ]; then
       DETECTED_FROM=""
       [ -f "$proj/.gsd/v1-roadmap.yml" ] && DETECTED_FROM="gsd-v1"
       [ -f "$proj/.gsd2/state.yml" ] && DETECTED_FROM="gsd-v2"
       [ -d "$proj/.specify/specs" ] && DETECTED_FROM="spec-kit"
       echo "migrating"; return 0
     fi
     # Rule 2: PBJ-shape .md files AND no src/
     if [ ! -d "$proj/src" ]; then
       local pbj_count
       pbj_count=$(find "$proj" -maxdepth 1 -type f -name '*.md' \
         \( -iname '*BRIEF*' -o -iname '*PLAN*' -o -iname '*DECISIONS*' \
            -o -iname '*HANDOFF*' -o -iname '*AUDIT*' \) 2>/dev/null | wc -l | tr -d ' ')
       if [ "$pbj_count" -ge 3 ]; then
         echo "greenfield-with-materials"; return 0
       fi
     fi
     # Rule 3: existing-codebase signals
     local has_src=0 has_many_sources=0 has_git_commits=0
     [ -d "$proj/src" ] && has_src=1
     local src_root_count
     src_root_count=$(find "$proj" -maxdepth 1 -type f \
       \( -name '*.js' -o -name '*.ts' -o -name '*.jsx' -o -name '*.tsx' \
          -o -name '*.py' -o -name '*.rs' -o -name '*.go' -o -name '*.rb' \
          -o -name '*.java' -o -name '*.kt' -o -name '*.swift' -o -name '*.cs' \
          -o -name '*.cpp' -o -name '*.c' -o -name '*.h' \) 2>/dev/null | wc -l | tr -d ' ')
     [ "$src_root_count" -ge 10 ] && has_many_sources=1
     if [ -d "$proj/.git" ]; then
       local commit_count
       commit_count=$(git -C "$proj" rev-list --count HEAD 2>/dev/null || echo 0)
       [ "$commit_count" -ge 1 ] && has_git_commits=1
     fi
     if [ "$has_src" -eq 1 ] || [ "$has_many_sources" -eq 1 ] || [ "$has_git_commits" -eq 1 ]; then
       # MIT-006 / RISK-006 disambiguation eligibility
       MIT006_ELIGIBLE=0
       if [ "$has_git_commits" -eq 1 ] && [ "$has_src" -eq 0 ] && [ "$has_many_sources" -eq 0 ]; then
         local total_sources="$src_root_count"
         if [ "$total_sources" -le 9 ]; then
           MIT006_ELIGIBLE=1
         fi
       fi
       echo "existing-codebase"; return 0
     fi
     # Rule 4: fallback
     echo "greenfield-empty"; return 0
   }
   ```

   The patterns (`*BRIEF*`, source-extension list, `src_root_count >= 10`, `commit_count >= 1`) MUST byte-match T02's SSOT fenced blocks so the parity verifier passes.

   2e. **--branch override.** When `--branch <name>` is supplied, skip detection. If `<name>` is not in the closed enum, exit 2 with the enum echoed. If `<name>` differs from what detection would have produced, emit `branch-override: detected=<X> overridden=<Y>` to stderr.

   2f. **Disambiguation question (US-1 AS-5).** When `--yes` is NOT set AND ambiguity exists, fire the question:

   - Case (i): rule-1 + rule-3 both match (any of `.gsd/`, `.gsd2/`, `.specify/` present AND `src/` present). Recommend `migrating` (rule-1 wins by ordering); ask the operator to confirm. Question text MUST contain the literal substring `disambiguation:` and the literal substring `recommended:`. One-keystroke accept: `Y/y/<enter>` accepts the recommendation, `n/N` picks the alternative, anything else prints `re-invoke with --branch <name>` and exits non-zero.
   - Case (ii) MIT-006 / RISK-006: `MIT006_ELIGIBLE=1` (rule-3 fires solely on `.git/` ≥1 commit, ≤9 source files, no prior-tooling artifacts). Recommend `greenfield-empty`; question MUST contain the literal substrings `git history present but only`, `MIT-006`, and `recommended: greenfield-empty`. Same one-keystroke accept semantics.

   Under `--yes`, case (i) auto-accepts the rule-ordered detection (`migrating`); case (ii) auto-accepts the detected `existing-codebase` (operator must use `--branch greenfield-empty` to override per FR-2's MIT-006 note).

   2g. **Sub-flow stub dispatch.** After detection (and any disambiguation), print `branch: <name>` to stdout, then dispatch to the appropriate stub function (defined inline at the top of the script per the Description's stub block). Each stub prints `would-execute: <stub-name> --project-dir <path>` and returns 0. Migrate routing stub additionally includes `--from <DETECTED_FROM>` when `DETECTED_FROM` is non-empty.

   2h. **Exit.** Exit 0 on success. Non-zero exits already documented above (unknown flag, unknown `--branch` value, disambiguation rejected with non-Y/n).

3. **Author `tools/verify/m033-p01-start-md-shape.sh`** (≥25 lines, executable). Asserts:
   - `commands/start.md` exists.
   - YAML frontmatter contains `description:` line with the literal `orchestrator:start` token.
   - Required content tokens present via `grep -q`: `orchestrator:start`, `warm conversational front door`, `scripts/lifecycle/start.sh`, `references/branch-detection.md`, `init-project.sh`.
   - Standard MEM012 sections present (`## Prerequisites`, `## Core Workflow`, `## Output`, `## Idempotency`, `## Error Handling`, `## Referenced Scripts`).
   - Emits PASS/SUMMARY lines.

4. **Author `tools/verify/m033-p01-start-sh-flags-and-init-invocation.sh`** (≥30 lines, executable). Asserts:
   - `scripts/lifecycle/start.sh` exists and is executable.
   - The flag tokens `--project-dir`, `--yes`, `--branch`, `--stack`, `--dry-run` all appear in the file body.
   - The `init-project.sh` invocation appears (`grep -q 'init-project.sh' scripts/lifecycle/start.sh`).
   - The `init already complete` diagnostic string appears.
   - Emits PASS/SUMMARY lines.

5. **Author `tools/verify/m033-p01-branch-detection-rules.sh`** (≥30 lines, executable). Asserts:
   - The four branch names appear in start.sh: `greenfield-empty`, `greenfield-with-materials`, `existing-codebase`, `migrating`.
   - The four detection-rule pattern signatures appear: prior-tooling globs (`.gsd`, `.gsd2`, `.specify`), the PBJ markdown glob substrings (`*BRIEF*`, `*PLAN*`, `*DECISIONS*`, `*HANDOFF*`, `*AUDIT*`), at least three source-extension tokens from the documented list (`.js`, `.py`, `.rs`), and the `git rev-list --count HEAD` invocation.
   - Optionally exercises the function: source the script in a sandboxed shell and call `detect_branch` against `tests/fixtures/m033-pbj-materials-fixture/` (must echo `greenfield-with-materials`).
   - Emits PASS/SUMMARY lines.

6. **Author `tools/verify/m033-p01-subflow-stubs-shape.sh`** (≥25 lines, executable). Asserts:
   - All four stub names appear in start.sh: `ideation-stub`, `materials-intake-stub`, `ingest-codebase-stub`, `migrate-routing-stub`.
   - The literal `would-execute:` token appears at least 4 times (once per stub).
   - Emits PASS/SUMMARY lines.

7. **Author `tools/verify/m033-p01-disambiguation-question-shape.sh`** (≥25 lines, executable). Asserts:
   - The literal token `disambiguation:` appears in start.sh.
   - The literal token `recommended:` appears.
   - The MIT-006 / RISK-006 markers appear (`MIT-006`, `git history present but only`, `recommended: greenfield-empty`).
   - The literal token `branch-override:` appears (FR-2 override-mismatch diagnostic).
   - Emits PASS/SUMMARY lines.

## Must-Haves

This task addresses these P01 phase truths:
- `commands/start.md` exists in canonical shape.
- `scripts/lifecycle/start.sh` exists, is executable, accepts the documented flags, invokes init exactly once.
- FR-2 deterministic branch-detection ordered rules implemented.
- The four sub-flow stubs print `would-execute:` diagnostics.
- The US-1 AS-5 + MIT-006 / RISK-006 disambiguation question fires.

This task creates these P01 phase artifacts:
- Command spec: `commands/start.md` (orchestrator:start command definition).
- Driver script: `scripts/lifecycle/start.sh` (4 branch-detection rules + sub-flow dispatch).
- Shape verifiers: `tools/verify/m033-p01-start-md-shape.sh`, `tools/verify/m033-p01-start-sh-flags-and-init-invocation.sh`, `tools/verify/m033-p01-branch-detection-rules.sh`, `tools/verify/m033-p01-subflow-stubs-shape.sh`, `tools/verify/m033-p01-disambiguation-question-shape.sh`.

## Verification

```bash
bash tools/verify/m033-p01-start-md-shape.sh
```

```bash
bash tools/verify/m033-p01-start-sh-flags-and-init-invocation.sh
```

```bash
bash tools/verify/m033-p01-branch-detection-rules.sh
```

```bash
bash tools/verify/m033-p01-subflow-stubs-shape.sh
```

```bash
bash tools/verify/m033-p01-disambiguation-question-shape.sh
```

```bash
bash tools/verify/m033-p01-branch-detection-ssot-parity.sh
```

## Inputs

### From Previous Tasks

- `tests/fixtures/m033-pbj-materials-fixture/` (from T01) — used in T03 dev-loop sanity check: `bash scripts/lifecycle/start.sh --project-dir tests/fixtures/m033-pbj-materials-fixture/ --yes --dry-run` should produce `branch: greenfield-with-materials` and `would-execute: materials-intake-stub`.
- `references/branch-detection.md` (from T02) — the SSOT for the regex/glob pattern strings. T03 authors these patterns verbatim into start.sh; the parity verifier (`m033-p01-branch-detection-ssot-parity.sh`, scaffold from T02) cross-checks they match.
  - Key API: pattern fenced blocks `branch-detection-rule-1` through `branch-detection-rule-4`; the literal pattern strings (prior-tooling globs, PBJ markdown glob, source-extension list, source-root min count, git min commits).

### From Disk (Pre-existing)

- `scripts/lifecycle/init-project.sh` — invoked by start.sh exactly once per invocation (skip if config.yml exists). Accepts `--project-dir <path>`.
- `commands/init.md` — the canonical command-document shape reference (MEM012); T03's `commands/start.md` mirrors this structure.

## Constraints

- Bash 3.2 compatibility (MEM001) — no `declare -A`, no process substitution, no `$(...)` containing pipes.
- Detection-rule patterns MUST byte-match T02's SSOT fenced blocks. The parity verifier uses `grep -F` to enforce; deviation fails verification.
- The `init already complete` diagnostic string is load-bearing for SC-1's idempotency assertion. The exact substring must appear verbatim.
- The `branch:` and `would-execute:` line prefixes are load-bearing for SC-1's regex assertions. Use `printf` (not `echo -e`) to avoid platform-specific escape interpretation.
- Sub-flow stubs MUST be vacuous in P01 — they call no other script, write no files, and have no side effects beyond the stdout `would-execute:` line. Non-vacuous stubs in P01 are scope-guard violations (the stubs belong to P02–P05).
- start.sh MUST NOT source `scripts/lifecycle/grilling-shell.sh` (does not exist yet — P02 deliverable). The disambiguation question is implemented inline as a small `read -r` prompt; full grilling-shell integration is P02's responsibility.
- start.sh MUST NOT write to `wiki/glossary.md` (P02 deliverable per FR-18).
- Verifier scripts use single-script-file shape per AD-19 — no `( … )` subshells, no `$(...)` with pipes, no compound chains.

## Expected Output

After T03 completes:
- `commands/start.md` and `scripts/lifecycle/start.sh` exist; start.sh is executable.
- All five new T03 verifiers exist and exit 0.
- T02's parity verifier (`m033-p01-branch-detection-ssot-parity.sh`) now exits 0 with `skip=0` (no longer skipping — start.sh exists).
- A summary file at [`.orchestrator/milestones/M033/phases/P01/tasks/T03-start-command-and-driver-SUMMARY.md`](../../../../../milestones/M033/phases/P01/tasks/T03-start-command-and-driver-SUMMARY.md) documents the deliverables and references the SC-1 acceptance assertions T05 will exercise against this skeleton.

## Notes

Expected verifier output: each new verifier emits PASS lines for each assertion + a `SUMMARY: m033-p01-<name>.sh pass=N fail=0` line. T02's parity verifier transitions from `skip=1` to `skip=0` after start.sh lands.
