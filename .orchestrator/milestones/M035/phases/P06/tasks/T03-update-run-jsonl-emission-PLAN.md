---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P06"
milestone: "M035"
name: "`update_run` JSONL emission for non-rollback dispatch path + 5-condition suppression matrix + D013"
depends_on: ["T01", "T02"]
---

## Prerequisites

- **T01 closed** — `scripts/state/read-config.sh` carries `update_source`
  in `VALID_KEYS`. T03 reads the resolved channel from the dispatch
  surface (T02), not from config directly.
- **T02 closed** — `scripts/lifecycle/run-update.sh` contains the
  multi-source dispatch block with all four channel arms (`git` /
  `npm` / `homebrew` / `none`) and the `resolve_update_source` helper.
  T03 inserts JSONL emission calls inside the success branches of
  the `git` / `npm` / `homebrew` arms (NOT `none` — `none` is the
  opt-out and emits nothing per D013 condition (c)). The `git` arm
  emission lands at the very end of the file (after the existing
  `orchestrator:update OK` line at line ~354), since `git)` falls
  through to the existing dispatch.
- **`scripts/lifecycle/run-update.sh`** rollback path (lines 254–263)
  already emits `update_run` with `op=rollback` on the rollback
  success path. T03 mirrors that emission shape for the non-rollback
  paths with `op=update`. The shared idiom (mkdir -p obs_dir / printf
  JSONL line / append to date-stamped file) is already in the rollback
  block — T03 reuses the pattern but does NOT factor it into a helper
  function (keeping the emission inline at each dispatch arm preserves
  AD-19 single-script-file shape and matches the rollback path's
  in-place idiom).
- **No `.orchestrator/observability/` directory in the repo** — the
  emission target is per-project, created at first-emission time via
  `mkdir -p`. T03's verifier stages mktemp project fixtures with no
  observability dir and asserts the dir is created on emission.
- **`scripts/lib/errors.sh`** exists. T03 verifier sources this.
- No `tools/verify/m035-p06-update-run-jsonl-emission-shape.sh` exists
  at plan-authoring time (Plan-Time Discipline Rule 6 confirmed
  absent).

## Description

T03 ships the `update_run` JSONL event emission for the non-rollback
dispatch paths (`git` / `npm` / `homebrew`). The rollback path already
emits via P05 T02; T03 does not modify that path. The event is
appended to `.orchestrator/observability/<YYYY-MM-DD>.jsonl` per
M027/FR-15 conventions.

The event schema (single-line JSON, newline-terminated):

```json
{"event":"update_run","op":"update","source":"<channel>","target_version":"<version-or-unknown>","result":"success","timestamp":"<ISO 8601 UTC>"}
```

Field semantics:

- `event`: literal `update_run`.
- `op`: literal `update` (T03's contribution); `rollback` is the
  rollback path's value (P05 T02, unchanged).
- `source`: resolved channel (`git` / `npm` / `homebrew`). Never
  `none` — the `none` arm short-circuits before emission per D013
  condition (c).
- `target_version`: post-dispatch version of the orchestrator runtime.
  For the `git` arm, this is the `bundle_version` already computed by
  `run-update.sh` at line 310. For `npm`/`homebrew`, this is the
  output of `npm view @build-fractal/orchestrator version` /
  `brew info --json orchestrator | grep version` if available; otherwise
  the literal string `unknown` (failure to resolve a version is NOT
  a hard error — emission proceeds with `unknown`).
- `result`: literal `success` if the underlying dispatch returned
  exit 0, else `failure`. T03 emits exactly one event per dispatch
  attempt (success OR failure) so observability captures the
  failure-rate signal too.
- `timestamp`: ISO 8601 UTC, e.g. `2026-05-09T18:42:00Z`. Use
  `date -u +%Y-%m-%dT%H:%M:%SZ` (matches the rollback path's idiom).

## 5-condition suppression matrix (D013)

T03's emission honors M027's 5-condition matrix verbatim:

1. **`--no-emit-jsonl` flag** (T03 introduces) — short-circuits
   emission. The flag is purely opt-out; it does NOT abort the
   dispatch itself, only the JSONL write.
2. **`ORCHESTRATOR_AUTO=1` env var** — auto-loop runs are not
   metering events the operator cares to see; emission short-
   circuits. Mirrors M027's existing auto-loop suppression
   convention.
3. **`update_source: none`** — no dispatch → no event. Already
   short-circuited by T02's `none)` arm before reaching T03's
   emission point. T03's contribution is a defensive guard:
   `if [ "$update_source" = "none" ]; then return; fi` at the top of
   the emission code path. This guard would never fire in practice
   (the `none` arm exits 0 before the emission code executes) but
   protects against future refactors that might restructure the
   dispatch order.
4. **`compression.efficiency_footer.enabled: false`** — does NOT
   apply (orthogonal surface, gates rendering not stream writes).
   T03 explicitly does NOT read this knob; documented as a carve-out
   in D013 so future authors don't mistakenly bind it.
5. **Structural carve-out** — emission is bound to a successful
   dispatch decision-point, not to invocation. Validation failures
   (npm not on PATH; package not installed; unknown source) emit
   nothing. The `result=failure` event fires for dispatch failures
   that succeed at validation (e.g. `npm update -g` exits non-zero
   for transient registry issues), but NOT for pre-dispatch
   validation failures.

D013 records the matrix mapping verbatim (read phase plan).

## Steps

1. **Read `scripts/lifecycle/run-update.sh`** (post-T02) to confirm
   the exact line ranges for each channel arm. T03's emission
   insertion points:
   - `npm)` arm: immediately after `rc=$?` (after `npm update -g`),
     before the `echo "---"` line.
   - `homebrew)` arm: immediately after `rc=$?` (after `brew upgrade`),
     before the `echo "---"` line.
   - `git)` arm fall-through: at the very end of the file, after the
     existing `orchestrator:update OK ...` echo (line ~354) and
     immediately before the final `exit "$rc"` (line ~358).

2. **Add a `--no-emit-jsonl` flag** to the existing arg parser in
   `run-update.sh`. Insert after the `--rollback)` case at line 91:

   ```bash
       --no-emit-jsonl)
         NO_EMIT_JSONL=1; shift ;;
   ```

   And initialize `NO_EMIT_JSONL=0` at the top of the file (with the
   other defaults at lines 50–56, after `ROLLBACK=0`).

3. **Author the emission helper** as a shell function in
   `run-update.sh`. Position: before the multi-source dispatch
   block but after the helper functions from T02. The function:

   ```bash
   # Emit one update_run JSONL event for non-rollback dispatch.
   # Honors the 5-condition suppression matrix (D013):
   #   1. --no-emit-jsonl flag
   #   2. ORCHESTRATOR_AUTO=1 env var
   #   3. update_source=none (defensive; never reached in practice)
   #   4. compression.efficiency_footer.enabled=false (does NOT apply)
   #   5. structural: only fires after a successful dispatch decision-
   #      point (post-validation, post-resolution).
   #
   # Args: $1=source $2=target_version $3=result (success|failure).
   # Side effect: appends one line to .orchestrator/observability/<date>.jsonl.
   # Exit: always 0 (emission failure must NOT abort the caller).
   emit_update_run_event() {
     local source_val="$1"
     local target_version="$2"
     local result_val="$3"

     # Condition 1: --no-emit-jsonl flag.
     if [ "${NO_EMIT_JSONL:-0}" = "1" ]; then
       return 0
     fi
     # Condition 2: ORCHESTRATOR_AUTO env var.
     if [ "${ORCHESTRATOR_AUTO:-0}" = "1" ]; then
       return 0
     fi
     # Condition 3: defensive guard against update_source=none.
     if [ "$source_val" = "none" ]; then
       return 0
     fi

     local obs_dir="$PROJECT_DIR/.orchestrator/observability"
     mkdir -p "$obs_dir" 2>/dev/null || return 0
     local today
     today="$(date -u +%Y-%m-%d)"
     local jsonl="$obs_dir/$today.jsonl"
     local ts
     ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
     # Single-line JSON; printf escapes for safety.
     printf '{"event":"update_run","op":"update","source":"%s","target_version":"%s","result":"%s","timestamp":"%s"}\n' \
       "$source_val" "$target_version" "$result_val" "$ts" >> "$jsonl"
   }

   # Best-effort post-dispatch version resolution. Returns "unknown"
   # when the channel-appropriate version probe fails. Bash 3.2.
   resolve_target_version() {
     local source_val="$1"
     case "$source_val" in
       git)
         # Use bundle_version already computed at line ~310 of run-update.sh.
         # If not yet computed (defensive), fall back to unknown.
         if [ -n "${bundle_version:-}" ]; then
           echo "$bundle_version"
         else
           echo "unknown"
         fi
         ;;
       npm)
         local v
         v="$(npm view @build-fractal/orchestrator version 2>/dev/null \
           | head -1 | tr -d '"' | tr -d "'")"
         if [ -n "$v" ]; then
           echo "$v"
         else
           echo "unknown"
         fi
         ;;
       homebrew)
         # brew info --json output is verbose; grep + sed for the version.
         local v
         v="$(brew info --json=v2 orchestrator 2>/dev/null \
           | grep -E '"versions"' | head -1 \
           | sed -E 's/.*"stable":"([^"]+)".*/\1/')"
         if [ -n "$v" ]; then
           echo "$v"
         else
           echo "unknown"
         fi
         ;;
       *)
         echo "unknown"
         ;;
     esac
   }
   ```

4. **Insert emission calls in each non-rollback arm** of the
   multi-source dispatch block:

   In the `npm)` arm, after `rc=$?`:

   ```bash
       # T03: update_run JSONL emission.
       _tv="$(resolve_target_version npm)"
       _rv="success"
       if [ "$rc" -ne 0 ]; then _rv="failure"; fi
       emit_update_run_event "npm" "$_tv" "$_rv"
   ```

   In the `homebrew)` arm, after `rc=$?`:

   ```bash
       # T03: update_run JSONL emission.
       _tv="$(resolve_target_version homebrew)"
       _rv="success"
       if [ "$rc" -ne 0 ]; then _rv="failure"; fi
       emit_update_run_event "homebrew" "$_tv" "$_rv"
   ```

   In the `git)` fall-through path (at line ~354, after the
   `orchestrator:update OK ...` echo, before `exit "$rc"`):

   ```bash
   # T03: update_run JSONL emission (git arm fall-through).
   _tv="$(resolve_target_version git)"
   _rv="success"
   if [ "$rc" -ne 0 ]; then _rv="failure"; fi
   emit_update_run_event "git" "$_tv" "$_rv"
   ```

5. **Append D013 to `.orchestrator/DECISIONS.md`**. Read the file at
   execution time to confirm the prevailing row format. The decision
   body verbatim:

   ```
   D013 — update_run JSONL emission 5-condition suppression matrix (M035 P06)

   The update_run JSONL emission for non-rollback dispatch paths
   (git/npm/homebrew) honors M027's 5-condition suppression matrix
   verbatim:

   1. --no-emit-jsonl flag (run-update.sh, T03 introduces) →
      short-circuits emission. Opt-out only; does NOT abort dispatch.
   2. ORCHESTRATOR_AUTO=1 env var → short-circuits emission. Mirrors
      M027 auto-loop suppression convention.
   3. update_source: none → no dispatch, no event. Defensive guard
      in emit_update_run_event protects against future refactors.
   4. compression.efficiency_footer.enabled: false → does NOT apply
      (orthogonal surface; that knob gates efficiency-footer rendering,
      not JSONL stream writes). Documented as carve-out so future
      authors don't mistakenly bind it.
   5. Structural carve-out → emission is bound to a successful
      dispatch decision-point. Pre-dispatch validation failures (npm
      not on PATH, package not installed, unknown source) emit
      nothing; post-dispatch failures (npm/brew exit non-zero) emit
      one event with result=failure.

   M035 introduces no new suppression knob beyond --no-emit-jsonl
   (FR-16: "M035 introduces no new suppression knob; it inherits
   M025/M027 conventions"). The flag is documented as inheriting the
   M027 opt-out pattern rather than a new knob class.

   Bound by FR-13 + FR-16 + CON-7.
   ```

6. **Author the verifier**
   `tools/verify/m035-p06-update-run-jsonl-emission-shape.sh`.
   Single-script-file shape, AD-19, ~80 lines. Sources
   `scripts/lib/errors.sh`. Asserts:

   1. `scripts/lifecycle/run-update.sh` is readable.
   2. The file contains the literal token `emit_update_run_event`
      (helper present).
   3. The file contains the literal token `resolve_target_version`
      (helper present).
   4. The file contains all 5 suppression-matrix references:
      `--no-emit-jsonl`, `ORCHESTRATOR_AUTO`, defensive-guard for
      `update_source = none`, NO reference to
      `efficiency_footer.enabled` inside the emission helper, AND
      the structural carve-out (emission INSIDE each channel arm
      after `rc=$?`, NOT before the validation check).
   5. The file contains the literal token `update_run` in three
      distinct positions (rollback path P05 T02 + git emission +
      npm/homebrew shared via the helper) — verified via
      `grep -c update_run >= 3`.
   6. The JSONL event template line contains all five required
      fields (`event`, `op`, `source`, `target_version`, `result`,
      `timestamp`).
   7. `.orchestrator/DECISIONS.md` contains the literal token `D013`.
   8. Stage a temp project fixture under
      `/tmp/m035-p06-t03-emission-fixture-$$/` (mktemp), with a
      minimal `.orchestrator/config.yml` carrying `update_source:
      git` and a stub source repo at the location resolved by the
      driver. Invoke `bash scripts/lifecycle/run-update.sh
      --project-dir <fixture> --dry-run`. Note: dry-run does NOT
      emit (the existing dry-run path exits before the emission
      hook). Assert no `.orchestrator/observability/` directory
      exists post-run (dry-run + suppression both yield no emission).
   9. Same fixture without `--dry-run` BUT with `--no-emit-jsonl`.
      Stage a no-op installer that exits 0. Invoke. Assert no
      `.orchestrator/observability/` dir exists post-run (suppression
      condition 1 honored).
   10. Same fixture without `--no-emit-jsonl` BUT with
       `ORCHESTRATOR_AUTO=1` env var. Invoke. Assert no
       observability dir exists post-run (suppression condition 2).
   11. Same fixture WITHOUT any suppression. Invoke. Assert
       `.orchestrator/observability/<today>.jsonl` exists with
       exactly one line containing `"event":"update_run"`,
       `"op":"update"`, `"source":"git"`, and a valid
       `"timestamp":"YYYY-MM-DDTHH:MM:SSZ"` field.

   Emit `BATTERY: pass=N fail=0` summary. Cleanup fixtures via EXIT
   trap.

   The verifier MUST honor AD-19 — no inline compound chains. The
   stub installer fixture is a one-line bash script that `exit 0`s;
   stage it with the right path so `run-update.sh`'s source-repo
   validation passes.

## Must-Haves

- `scripts/lifecycle/run-update.sh` modified — contains
  `emit_update_run_event`, `resolve_target_version`, `--no-emit-jsonl`
  flag, emission calls inserted in `npm)`/`homebrew)`/git-fall-through
  paths.
- `.orchestrator/DECISIONS.md` modified — contains a `D013` row
  referencing M035/P06 + 5-condition suppression matrix.
- `tools/verify/m035-p06-update-run-jsonl-emission-shape.sh` exists,
  executable, ~80+ lines, contains `BATTERY:` and `update_run`,
  runs against staged fixtures, emits `BATTERY: pass=N fail=0`.

## Verification

```bash
bash tools/verify/m035-p06-update-run-jsonl-emission-shape.sh
```

```bash
bash tools/verify/m035-p06-multi-source-dispatch-shape.sh
```

## Inputs

### From Previous Tasks

- `scripts/lifecycle/run-update.sh` (post-T02)
  - Key API: multi-source dispatch with `case "$update_source" in
    git) ... ;; npm) ... ;; homebrew) ... ;; none) ... ;; *) ... ;;`.
  - Key types: T03 inserts emission calls inside the success
    branches of the `git`/`npm`/`homebrew` arms; the `none` arm is
    untouched (defensive guard inside the helper protects further).
  - Behavioral contract: each non-rollback success path now emits
    exactly one `update_run` JSONL event after the dispatch returns.

### From Disk (Pre-existing)

- `scripts/lifecycle/run-update.sh` rollback path (lines 254–263) —
  existing `printf ... >> "$jsonl"` idiom T03 mirrors for
  non-rollback paths.
- `.orchestrator/observability/` directory convention (M027 P00) —
  date-stamped `<YYYY-MM-DD>.jsonl` files, line-delimited JSON,
  append-only.
- `scripts/lib/errors.sh` — sourceable lib exporting `emit_result`.
  Used by the verifier.

## Constraints

- **AD-19 single-script-file shape** — every check command is `bash
  tools/verify/m035-p06-*.sh`. No inline compound chains in either
  the verifier or the emission helpers themselves. The
  `resolve_target_version` `npm view ... | head -1 | tr -d ...`
  pipeline lives inside a function body, which is AP-009-permitted
  for in-function pipelines (the AP-009 guard fires on caller-side
  inline compound shapes, not on function-body composition; mirrors
  P05 T02 rollback-path conventions).
- **Bash 3.2 + POSIX-sh** — CON-2/CON-7. The emission helpers run on
  macOS bash 3.2 unmodified.
- **FR-16 (no new suppression knob)** — `--no-emit-jsonl` is
  documented as inheriting the M027 opt-out pattern rather than a
  new knob class. D013 records this explicitly.
- **CON-7 / M027 alignment** — the 5-condition suppression matrix
  maps verbatim onto M027's existing matrix shape. Surface (a/b/e)
  carry over directly; (c) is the new dispatch-suppression case;
  (d) is explicitly carved out as orthogonal.
- **Emission failure must NOT abort the caller** — the helper
  function returns 0 even when `mkdir -p` or `printf >>` fail.
  Observability is best-effort; dispatch success/failure stays
  authoritative.
- **Plan-Time Discipline Rule 6 (Path-collision)** — `ls -la`
  performed against
  `tools/verify/m035-p06-update-run-jsonl-emission-shape.sh`;
  ABSENT.

## Expected Output

Stdout from `bash tools/verify/m035-p06-update-run-jsonl-emission-shape.sh`:

```
PASS: run-update.sh contains emit_update_run_event helper
PASS: run-update.sh contains resolve_target_version helper
PASS: run-update.sh references --no-emit-jsonl flag
PASS: run-update.sh references ORCHESTRATOR_AUTO env var
PASS: emit_update_run_event carries defensive update_source=none guard
PASS: run-update.sh references update_run in >= 3 positions
PASS: JSONL template line carries all six required fields
PASS: DECISIONS.md contains D013 anchor
PASS: --dry-run yields no observability/ dir (dry-run short-circuits)
PASS: --no-emit-jsonl yields no observability/ dir (suppression 1)
PASS: ORCHESTRATOR_AUTO=1 yields no observability/ dir (suppression 2)
PASS: clean dispatch yields exactly one update_run event in <today>.jsonl
BATTERY: pass=12 fail=0
```
