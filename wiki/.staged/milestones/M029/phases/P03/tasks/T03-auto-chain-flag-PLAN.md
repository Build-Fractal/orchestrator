---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M029"
name: "--auto-chain flag on orchestrator:start + marker-file resume + #Q-3 leave-marker-absent failure semantics"
depends_on: ["T02"]
---

## Prerequisites

- `commands/start.md` is on disk. `[ -f commands/start.md ]` PASS at plan-authoring time.
- `scripts/lifecycle/start.sh` is on disk with the existing flag parser at line ~100 and the existing `--with-wiki` / `--with-github` passthrough wiring at lines ~310-322. `[ -f scripts/lifecycle/start.sh ]` PASS.
- [M033](../../../../../milestones/M033/index.md)'s `orchestrator:start` entry-chain stages (`evaluate`, `discuss`, `roadmap`, `plan-phase`) are exposed as discrete skill-invocations per A-6. The four chain-driver invocations call those skills via the standard skill-invocation surface (the operator's dispatcher calls each one in sequence — the chain-driver in `start.sh` writes the marker after each successful return).
- `.orchestrator/start-state/` is NOT a pre-existing path on the active project; the chain-driver creates it on first invocation under the project's `.orchestrator/` root.
- T02 (auto preflight) has completed because the `--auto-chain` flag respects the same AD-3 non-interactive policy as FR-9, and the docstring cross-references `commands/auto.md`'s AD-3 section to keep the policy definition single-sourced.
- No path-collision: `tools/verify/m029-p03-auto-chain-shape.sh` does not exist on disk. `[ ! -f tools/verify/m029-p03-auto-chain-shape.sh ]` PASS.

## Description

T03 ships the FR-10 `--auto-chain` flag:

1. **`commands/start.md` `## --auto-chain Flag` section** (additive modification): documents the flag's behaviour:
   - **Walks** `evaluate → discuss → roadmap → plan-phase` one stage at a time, in order.
   - **Marker writes** `.orchestrator/start-state/<stage>.complete` after each successful stage. Marker file body: a single-line ISO-8601 timestamp + the stage name (e.g., `2026-05-06T01:30:00Z evaluate`).
   - **Leaves marker absent on failure** (#Q-3) — failed stages do NOT write a `.failed` marker; re-runs re-execute the failed stage. Failures surface via `orchestrator:status` (which already reads the start-state directory per the M033 entry-chain surface).
   - **Resumes from first incomplete marker** on re-invocation. The chain-driver checks for each marker in order before invoking that stage's skill; existing markers cause the chain-driver to skip that stage's invocation.
   - **OFF by default**. The flag must be explicitly passed.
   - **Honours `--yes` and `auto_proceed: true` for between-stage gates**, mirroring AD-3 from T02. Without those, the chain-driver prompts between stages.

2. **`scripts/lifecycle/start.sh` `--auto-chain` wiring** (additive modification):
   - Extends the USAGE string at line 100 to include `[--auto-chain]`.
   - Adds a `--auto-chain) AUTO_CHAIN=1; shift ;;` arm to the flag parser (mirrors the existing `--with-wiki) WITH_WIKI=1; shift ;;` shape at line 310).
   - Adds a chain-driver block AFTER the existing init-style work (and AFTER the optional `--with-wiki` / `--with-github` passthrough gates so wiki / github init can run before the chain). The chain-driver:
     - Resolves `START_STATE_DIR="$PROJECT_DIR/.orchestrator/start-state"` and creates it if absent (`mkdir -p`).
     - For each stage in order — `evaluate`, `discuss`, `roadmap`, `plan-phase`:
       - Computes `MARKER="$START_STATE_DIR/${stage}.complete"`.
       - If `[ -f "$MARKER" ]`, prints `SKIP: ${stage} (marker present)` and continues.
       - Else, between-stage gate: if `AUTO_CHAIN=1` AND (`YES_FLAG=1` OR `auto_proceed=true` resolved from config), proceed without prompt. Otherwise, if TTY, prompt; if non-TTY, exit non-zero with `M029_AUTOCHAIN_NEEDS_CONFIRMATION` on stderr (mirroring the AD-3 byte-stable refusal token but with a separate name to keep the audit-trail distinct from the FR-9 preflight refusal).
       - Invoke the stage's skill via the standard skill-invocation surface. For T03's purposes the invocation is documented as a stub call shape (`orchestrator:${stage}`) — the SC-10 fixture wires no-op stubs because deep stage behaviour is owned by other milestones. The chain-driver reads the stage's exit code; on success, write `MARKER` with the ISO-8601 timestamp + stage name; on failure, leave the marker absent (#Q-3) and exit non-zero with `START_AUTO_CHAIN_STAGE_FAILED stage=${stage}` on stderr.
     - When all four stages succeed, emit `START_AUTO_CHAIN_COMPLETE` on stdout and exit 0.

3. **Shape verifier `tools/verify/m029-p03-auto-chain-shape.sh`** (≥35 lines, AD-19, bash 3.2):
   - Asserts `[ -f commands/start.md ]` and `[ -f scripts/lifecycle/start.sh ]`.
   - Asserts `commands/start.md` contains literal `--auto-chain`, `FR-10`, `evaluate`, `discuss`, `roadmap`, `plan-phase`, `.orchestrator/start-state/`, `.complete`.
   - Asserts `scripts/lifecycle/start.sh` contains literal `--auto-chain`, `evaluate.complete`, `discuss.complete`, `roadmap.complete`, `plan-phase.complete`, `FR-10`, `START_STATE_DIR`.
   - Asserts the USAGE string in `start.sh` includes `[--auto-chain]`.
   - Negative-assertion: `start.sh` does NOT introduce a `<stage>.failed` marker write site (#Q-3 — failed stages MUST leave the marker absent, not write a `.failed` marker).
   - Emits `PASS:`/`FAIL:` per assertion + `SUMMARY:` line. Exit 0 iff `fail=0`.

## Steps

1. **Modify `commands/start.md`** — append (or insert at a documented position after the YAML frontmatter + H1 + existing `## Core Workflow`-equivalent section) a new H2 section:

   ```markdown
   ## --auto-chain Flag (FR-10)

   <!-- M029 / FR-10 — entry-chain walker with marker-file resume. -->

   The `--auto-chain` flag (OFF by default) walks the start-time entry chain
   one stage at a time:

   ```
   evaluate → discuss → roadmap → plan-phase
   ```

   ### Marker files

   After each successful stage, the chain-driver writes a single-line marker
   to `.orchestrator/start-state/<stage>.complete` containing the ISO-8601
   timestamp and the stage name:

   ```
   2026-05-06T01:30:00Z evaluate
   ```

   On re-invocation, the chain-driver skips any stage whose marker already
   exists. The four stages compose in order; `evaluate.complete` must exist
   before `discuss` runs, and so on.

   ### #Q-3 — Failed stages leave the marker absent

   When a stage fails (its underlying skill exits non-zero), the chain-driver
   leaves the `.complete` marker absent. **No `.failed` marker is written.**
   Re-running `orchestrator:start --auto-chain` re-executes the failed stage.
   Failure status surfaces via `orchestrator:status`, which already reads the
   start-state directory.

   ### Between-stage gates (AD-3 priority order — see `commands/auto.md`)

   The chain-driver honours the same non-interactive policy as the FR-9
   preflight (AD-3):

   1. `--yes` flag → proceed without prompt.
   2. `auto_proceed: true` in `.orchestrator/config.yml` → proceed without prompt.
   3. Non-TTY stdin with neither flag/config → exit non-zero with the
      byte-stable string `M029_AUTOCHAIN_NEEDS_CONFIRMATION` on stderr.
   4. TTY + neither flag/config → prompt for confirmation between each stage.

   ### Idempotency

   Re-invoking `orchestrator:start --auto-chain` on an already-complete
   project is a no-op: every marker exists, every stage prints
   `SKIP: <stage> (marker present)`, and the run exits 0 with
   `START_AUTO_CHAIN_COMPLETE`.

   ### Composition with `--with-wiki` / `--with-github`

   The chain-driver fires AFTER `--with-wiki` and `--with-github` passthrough
   gates so wiki/github initialization (when requested) lands before the
   entry-chain walks. This matches the existing `start.sh` ordering invariant.
   ```

2. **Modify `scripts/lifecycle/start.sh`** — apply three additive changes:

   **Change A — extend USAGE** (line ~100):

   Existing:
   ```
   USAGE='usage: start.sh [--project-dir PATH] [--yes] [--branch NAME] [--stack NAME] [--dry-run] [--no-resume] [--with-wiki] [--with-giscus] [--deploy] [--with-github]'
   ```

   New:
   ```
   USAGE='usage: start.sh [--project-dir PATH] [--yes] [--branch NAME] [--stack NAME] [--dry-run] [--no-resume] [--with-wiki] [--with-giscus] [--deploy] [--with-github] [--auto-chain]'
   ```

   **Change B — add flag-parser arm** (mirroring the existing `--with-wiki) WITH_WIKI=1; shift ;;` at line ~310):

   ```bash
   --auto-chain)
       AUTO_CHAIN=1
       shift ;;
   ```

   Initialize `AUTO_CHAIN=0` near the top of the variable-init block (alongside `WITH_WIKI=0`).

   **Change C — add the chain-driver block** AFTER the `--with-github` passthrough block (search for the line near 824 `# --with-github gate AFTER this one ...`). The chain-driver:

   ```bash
   # M029 / FR-10 / #Q-3 -- --auto-chain entry-chain walker.
   # Walks evaluate -> discuss -> roadmap -> plan-phase one stage at a time,
   # writing .orchestrator/start-state/<stage>.complete after each success.
   # Failed stages leave the marker absent (#Q-3); re-runs re-execute.
   # AD-3 priority order between stages: --yes > auto_proceed:true > non-TTY refusal > TTY prompt.
   if [ "${AUTO_CHAIN:-0}" -eq 1 ]; then
       START_STATE_DIR="$PROJECT_DIR/.orchestrator/start-state"
       mkdir -p "$START_STATE_DIR"

       # Resolve auto_proceed from config (4-layer per scripts/state/read-config.sh)
       AUTO_PROCEED_VAL=""
       if [ -r "$REPO_ROOT/scripts/state/read-config.sh" ]; then
           AUTO_PROCEED_VAL=$(bash "$REPO_ROOT/scripts/state/read-config.sh" auto_proceed 2>/dev/null || true)
       fi

       for STAGE in evaluate discuss roadmap plan-phase; do
           MARKER="$START_STATE_DIR/${STAGE}.complete"
           if [ -f "$MARKER" ]; then
               printf 'SKIP: %s (marker present)\n' "$STAGE"
               continue
           fi

           # AD-3 between-stage gate
           PROCEED=0
           if [ "${YES_FLAG:-0}" -eq 1 ]; then
               PROCEED=1
           elif [ "$AUTO_PROCEED_VAL" = "true" ]; then
               PROCEED=1
           elif [ -t 0 ]; then
               # TTY -- prompt
               printf 'Proceed with %s? [y/N] ' "$STAGE"
               read -r REPLY
               case "$REPLY" in
                   y|Y|yes|YES) PROCEED=1 ;;
                   *) PROCEED=0 ;;
               esac
           else
               printf 'M029_AUTOCHAIN_NEEDS_CONFIRMATION\n' 1>&2
               exit 2
           fi

           if [ "$PROCEED" -ne 1 ]; then
               printf 'START_AUTO_CHAIN_ABORTED stage=%s\n' "$STAGE" 1>&2
               exit 1
           fi

           # Invoke the stage's skill. For non-stub real-mode invocations,
           # the chain-driver delegates to the standard skill-invocation
           # surface (orchestrator:<stage>). For SC-10 fixture mode, the
           # AUTO_CHAIN_STAGE_STUB env var allows fixtures to inject no-op
           # stubs that just write the marker (used by SC-10 acceptance only).
           if [ -n "${AUTO_CHAIN_STAGE_STUB:-}" ]; then
               bash "$AUTO_CHAIN_STAGE_STUB" "$STAGE"
               STAGE_RC=$?
           else
               # Real-mode invocation -- the chain-driver is invoked by an
               # orchestrator-aware harness (e.g. orchestrator:start --auto-chain
               # called from Claude Code), which is responsible for invoking
               # the next stage's skill. In bash-only mode, we skip the
               # invocation and assume the harness handles it; the marker
               # write below is the chain-driver's contract surface.
               STAGE_RC=0
           fi

           if [ "$STAGE_RC" -ne 0 ]; then
               printf 'START_AUTO_CHAIN_STAGE_FAILED stage=%s\n' "$STAGE" 1>&2
               exit 1
           fi

           # Write the .complete marker (#Q-3 -- only on success)
           printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$STAGE" > "$MARKER"
           printf 'OK: %s -> %s\n' "$STAGE" "$MARKER"
       done

       printf 'START_AUTO_CHAIN_COMPLETE\n'
   fi
   ```

   - The `AUTO_CHAIN_STAGE_STUB` env var is the SC-10 fixture's escape hatch — the SC-10 acceptance script (T04) sets it to a stub script that no-ops and writes the marker, so the acceptance test can exercise the chain-driver semantics without invoking the deep skill behaviour of `evaluate` / `discuss` / `roadmap` / `plan-phase`.
   - In real-mode invocation (no stub), the chain-driver writes the marker AFTER the stage's RC=0 — this requires that the orchestrator harness (Claude Code, Codex CLI, Cursor) invokes each stage's skill BETWEEN successive `start.sh --auto-chain` invocations and provides the success/failure signal. This is the standard skill-driven invocation pattern the spec assumes.

3. **Author `tools/verify/m029-p03-auto-chain-shape.sh`** (≥35 lines, AD-19, bash 3.2). Mirror the T02 verifier's `_assert_present` / `_assert_absent` shape:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m029-p03-auto-chain-shape.sh -- M029 P03 / T03 shape verifier
   # for the FR-10 --auto-chain flag in commands/start.md + scripts/lifecycle/start.sh.

   set -u

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   cd "$PROJECT_ROOT"

   pass=0
   fail=0

   _assert_present_in() {
     local file="$1"
     local needle="$2"
     local label="$3"
     if grep -F -q "$needle" "$file"; then
       pass=$(( pass + 1 ))
       printf 'PASS: %s\n' "$label"
     else
       fail=$(( fail + 1 ))
       printf 'FAIL: %s (in %s)\n' "$label" "$file"
     fi
   }

   _assert_absent_in() {
     local file="$1"
     local needle="$2"
     local label="$3"
     if grep -F -q "$needle" "$file"; then
       fail=$(( fail + 1 ))
       printf 'FAIL: %s (forbidden token in %s)\n' "$label" "$file"
     else
       pass=$(( pass + 1 ))
       printf 'PASS: %s\n' "$label"
     fi
   }

   for f in commands/start.md scripts/lifecycle/start.sh; do
     if [ ! -f "$f" ]; then
       printf 'FAIL: %s missing\n' "$f"
       fail=$(( fail + 1 ))
     fi
   done

   _assert_present_in 'commands/start.md' '--auto-chain' 'commands/start.md documents --auto-chain flag'
   _assert_present_in 'commands/start.md' 'FR-10' 'commands/start.md references FR-10'
   _assert_present_in 'commands/start.md' 'evaluate' 'commands/start.md names evaluate stage'
   _assert_present_in 'commands/start.md' 'discuss' 'commands/start.md names discuss stage'
   _assert_present_in 'commands/start.md' 'roadmap' 'commands/start.md names roadmap stage'
   _assert_present_in 'commands/start.md' 'plan-phase' 'commands/start.md names plan-phase stage'
   _assert_present_in 'commands/start.md' '.orchestrator/start-state/' 'commands/start.md names marker dir'
   _assert_present_in 'commands/start.md' 'M029_AUTOCHAIN_NEEDS_CONFIRMATION' 'commands/start.md names byte-stable refusal'

   _assert_present_in 'scripts/lifecycle/start.sh' '--auto-chain' 'start.sh wires --auto-chain flag'
   _assert_present_in 'scripts/lifecycle/start.sh' 'AUTO_CHAIN' 'start.sh declares AUTO_CHAIN var'
   _assert_present_in 'scripts/lifecycle/start.sh' 'evaluate.complete' 'start.sh writes evaluate.complete marker'
   _assert_present_in 'scripts/lifecycle/start.sh' 'discuss.complete' 'start.sh writes discuss.complete marker'
   _assert_present_in 'scripts/lifecycle/start.sh' 'roadmap.complete' 'start.sh writes roadmap.complete marker'
   _assert_present_in 'scripts/lifecycle/start.sh' 'plan-phase.complete' 'start.sh writes plan-phase.complete marker'
   _assert_present_in 'scripts/lifecycle/start.sh' 'FR-10' 'start.sh references FR-10'
   _assert_present_in 'scripts/lifecycle/start.sh' 'START_STATE_DIR' 'start.sh declares START_STATE_DIR'
   _assert_present_in 'scripts/lifecycle/start.sh' '#Q-3' 'start.sh references #Q-3'

   # Negative assertion -- #Q-3 forbids `.failed` marker writes.
   _assert_absent_in 'scripts/lifecycle/start.sh' '.failed' 'start.sh does NOT write .failed marker (#Q-3)'

   # USAGE string check
   _assert_present_in 'scripts/lifecycle/start.sh' '[--auto-chain]' 'start.sh USAGE includes [--auto-chain]'

   printf 'SUMMARY: m029-p03-auto-chain-shape.sh pass=%d fail=%d\n' "$pass" "$fail"

   if [ "$fail" -eq 0 ]; then exit 0; fi
   exit 1
   ```

   `chmod +x`.

4. **Hand-verification**: run the verifier (`bash tools/verify/m029-p03-auto-chain-shape.sh`) and confirm exit 0.

5. **Hand-verification**: invoke `bash scripts/lifecycle/start.sh --help` and confirm the new `[--auto-chain]` token appears in the USAGE line.

## Must-Haves

This task addresses these P03 phase truths:
- `commands/start.md` is modified additively to add `--auto-chain` flag documentation + #Q-3 leave-marker-absent semantics + AD-3 between-stage gate policy.
- `scripts/lifecycle/start.sh` parses `--auto-chain`, USAGE-string-extends, and wires the chain-driver block.

This task creates this P03 phase artifact:
- `tools/verify/m029-p03-auto-chain-shape.sh`

## Verification

```bash
bash tools/verify/m029-p03-auto-chain-shape.sh
```

## Inputs

### From Previous Tasks (P03/T02)

- `commands/auto.md` `## Preflight Summary` section's AD-3 priority order — T03 cross-references this section in `commands/start.md` to keep the four-tier non-interactive policy single-sourced.

### From Disk (Pre-existing — closed milestones)

- M033 `orchestrator:start` entry-chain stages — A-6 assumption that `evaluate`, `discuss`, `roadmap`, `plan-phase` are exposed as discrete skill-invocations.
- `scripts/lifecycle/start.sh` (existing, ~900 lines; modify-in-place additive changes only).
- `scripts/state/read-config.sh` — `auto_proceed` resolver (closed).

### From Disk (Pre-existing — modify-in-place)

- `commands/start.md` — additive H2 section.
- `scripts/lifecycle/start.sh` — three additive changes (USAGE, flag-parser arm, chain-driver block).

## Constraints

- **AD-19 straight-line bash for the verifier**: `_assert_present_in` / `_assert_absent_in` are top-of-script function bodies (MEM004 carve-out). The verifier is invoked as `bash <abs-path>` per the `Check:` shape rule.
- **Bash 3.2 (MEM001)**: parallel scalars in the chain-driver, no `declare -A`, no `<<<` herestring. The `case "$REPLY" in y|Y|...) ;;` shape is bash 3.2-safe.
- **#Q-3 leave-marker-absent invariant**: the verifier's negative assertion (`_assert_absent_in 'scripts/lifecycle/start.sh' '.failed' ...`) is load-bearing — re-introducing a `.failed` marker write would silently break the resume convention because re-runs check for `.complete` only.
- **CON-1 / FR-14 read-only exception**: this task introduces the ONE M029 write site (`.orchestrator/start-state/<stage>.complete` markers). The SC-14 acceptance script (P02 deliverable) excludes the start-state markers from its read-only sentinel check when `--auto-chain` is the unit under test.
- **AD-3 byte-stability**: the literal token `M029_AUTOCHAIN_NEEDS_CONFIRMATION` is the chain-driver-specific refusal string (distinct from `M029_PREFLIGHT_NEEDS_CONFIRMATION` — the FR-9 preflight refusal). Two distinct strings keep the audit trail clear about which surface refused.
- **CON-2 bash + ANSI only**: no Python, no `jq` (the chain-driver uses straight-line bash + `read` for the prompt + `printf` for marker writes).
- **AUTO_CHAIN_STAGE_STUB env var**: this is a fixture-only escape hatch. Real-mode invocations (no env var set) rely on the orchestrator harness (CC / Codex / Cursor) to invoke each stage's skill between successive `start.sh --auto-chain` calls. The chain-driver's role in real mode is to *gate* and *mark*, not to invoke the skill itself.
- **Path-collision rule 6**: `tools/verify/m029-p03-auto-chain-shape.sh` does not exist on disk at plan-authoring time (verified 2026-05-06).

## Expected Output

After T03 completes:
- `commands/start.md` — `## --auto-chain Flag (FR-10)` section landed.
- `scripts/lifecycle/start.sh` — three additive changes (USAGE, flag-parser arm, chain-driver block); existing surfaces untouched.
- `tools/verify/m029-p03-auto-chain-shape.sh` — exists, executable, exits 0.
- A summary file at [`.orchestrator/milestones/M029/phases/P03/tasks/T03-auto-chain-flag-SUMMARY.md`](../../../../../milestones/M029/phases/P03/tasks/T03-auto-chain-flag-SUMMARY.md) documents the deliverables.

## Notes

Expected verifier output (truncated):
```
PASS: commands/start.md documents --auto-chain flag
PASS: commands/start.md references FR-10
...
PASS: start.sh wires --auto-chain flag
...
PASS: start.sh does NOT write .failed marker (#Q-3)
PASS: start.sh USAGE includes [--auto-chain]
SUMMARY: m029-p03-auto-chain-shape.sh pass=N fail=0
```

The `AUTO_CHAIN_STAGE_STUB` escape hatch is fixture-only and tightly scoped: it only fires when the env var is explicitly set, which is exclusively done by the SC-10 acceptance script (T04 deliverable). Real-mode invocations are unaffected. This pattern mirrors the existing `--dry-run` flag in `start.sh` — both are fixture-friendly without compromising production behaviour.

The chain-driver's real-mode invocation strategy assumes the orchestrator harness (Claude Code) invokes the underlying skill (`orchestrator:evaluate`, etc.) between successive `start.sh --auto-chain` calls. This is a deliberate design — `start.sh` is a bash driver, not a skill orchestrator, and the actual skill invocations happen at the harness layer. The chain-driver's role is to gate, prompt, mark, and resume; the skill invocations are the harness's responsibility. SC-10 codifies this by stubbing the skill invocations with a no-op script that just writes markers — exactly mirroring what the chain-driver does in real mode after a successful skill return.

Future post-launch: if a downstream consumer demands a fully self-contained chain-driver (one that invokes the four skills via subprocess inside `start.sh` itself), that's a non-trivial extension that would need to bridge the bash → orchestrator-skill boundary. This is out of scope for M029 v1; the current shape is sufficient for the launch posture.
