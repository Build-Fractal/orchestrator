---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P06"
milestone: "M035"
name: "Multi-source dispatch in `run-update.sh` — git/npm/homebrew/none + AD-5 detect-by-install-method-first + persist + D014"
depends_on: ["T01"]
---

## Prerequisites

- **T01 closed** — `scripts/state/read-config.sh` carries `update_source`
  in `VALID_KEYS`. T02's dispatch reads `update_source` via the
  registered key.
- **`scripts/lifecycle/run-update.sh`** exists with the M035 P05 T02
  rollback dispatch block at lines 104–264 (before the source-repo
  validation at line 266). T02 inserts the multi-source dispatch block
  **after** the rollback block (so `--rollback` short-circuits before
  the new branch) and **before** the existing source-repo validation
  (so the existing git-source path becomes one of the four channels
  rather than the only path). At the moment of insertion, the file
  is shape:
  - Lines 1–102: arg parsing
  - Lines 104–264: `if [ "$ROLLBACK" = "1" ]; then ... fi` block
  - Lines 266+: existing source-repo validation + git-source dispatch
  T02 wraps lines 266+ inside a `case "$update_source" in git) ... ;;`
  arm and adds `npm) ... ;;`, `homebrew) ... ;;`, `none) ... ;;`,
  `*) FAIL: unknown update_source ...` arms.
- **`.orchestrator/install-meta.txt`** schema (M035 P01 / FR-9 amendment
  landed at commit 8bcba64). Five fields: `source_root=`, `runtime=`,
  `installed_at=`, `commit_sha=`, `version=`. T02's AD-5 detection helper
  reads `runtime=` looking for the literal substrings `npm` / `homebrew`
  / `curl` / `git` (case-insensitive).
- **`.orchestrator/config.yml`** exists at the repo root. T02's
  persistence write touches this file (single-line append or sed-replace
  for the `update_source:` line).
- **`scripts/lib/errors.sh`** exists and exports `emit_result()`. T02
  verifier sources this.
- No `tools/verify/m035-p06-multi-source-dispatch-shape.sh` exists at
  plan-authoring time (Plan-Time Discipline Rule 6 confirmed absent).

## Description

T02 ships the multi-source dispatch logic in `run-update.sh`. The
dispatch reads `update_source` from `.orchestrator/config.yml` (via
T01's registered key) and routes to one of four channels:

- **`git`** — the existing path (lines 266+ of `run-update.sh`):
  validate source repo, print pre-install summary, invoke
  `bash <source>/packaging/install/install-claude-code.sh --project-dir
  <project> --force`. No regression.
- **`npm`** — invoke `npm update -g @build-fractal/orchestrator`.
  Pre-flight: assert `npm` on PATH; assert the package is globally
  installed via `[ -d "$(npm root -g 2>/dev/null)/@build-fractal/orchestrator" ]`.
  Pass-through `npm update`'s exit code.
- **`homebrew`** — invoke `brew upgrade orchestrator`. Pre-flight:
  assert `brew` on PATH; assert the formula is installed via
  `[ -d "$(brew --prefix 2>/dev/null)/Cellar/orchestrator" ]`.
  Pass-through `brew upgrade`'s exit code.
- **`none`** — explicit no-op. Print `update_source: none — dispatch
  suppressed (operator opt-out)` to stdout; exit 0. No JSONL emission
  (T03 honors this in the suppression matrix).

When `update_source` is absent or empty (the case for every pre-launch
consumer), AD-5 detection runs:

1. Read `.orchestrator/install-meta.txt` `runtime=` value (if file
   exists). If value contains `npm` / `homebrew` / `curl` / `git`
   substring (case-insensitive), use that. (`curl` resolves to `npm`
   per D012 — curl-pipe-bash extracts the npm tarball.)
2. If `runtime=` doesn't disambiguate AND `npm` is on PATH AND
   `[ -d "$(npm root -g)/@build-fractal/orchestrator" ]`, resolve to `npm`.
3. If still unresolved AND `brew` is on PATH AND
   `[ -d "$(brew --prefix)/Cellar/orchestrator" ]`, resolve to `homebrew`.
4. Fallback to `git` (the pre-M035 interim's only-source).

After detection lands on a non-`git` source, **persist** by writing
`update_source: <detected>` as a top-level key into
`.orchestrator/config.yml`. If the key already exists with a different
value, the persistence is a no-op (operator's explicit setting wins).
Persistence semantics: read the file, grep for an existing
`^update_source:` line, sed-replace if present, append `update_source:
<value>` if absent. The persistence write is single-resolve, single-
write — subsequent runs hit the persisted config and skip detection.

`--dry-run` mode short-circuits before any dispatch and emits
`would_invoke=<channel-appropriate command>` lines, mirroring the P05
T05 dry-run convention. The would_invoke string for each channel:

- `git`: `would_invoke=bash <source>/packaging/install/install-claude-code.sh --project-dir <project> --force`
- `npm`: `would_invoke=npm update -g @build-fractal/orchestrator`
- `homebrew`: `would_invoke=brew upgrade orchestrator`
- `none`: `would_invoke=<no-op: update_source=none>`

D014 records the AD-5 detection ordering decision verbatim (read
phase plan).

## Steps

1. **Read `scripts/lifecycle/run-update.sh`** to confirm the exact
   line ranges of the existing arg parsing (lines 1–102), rollback
   block (lines 104–264), and source-repo validation + dispatch
   (lines 266+). T02's insertion happens BETWEEN the rollback block
   and the source-repo validation, so the new dispatch wraps the
   existing git path.

2. **Author the `resolve_update_source` helper** as a shell function
   inside `run-update.sh` (NOT a separate script — keeping it inline
   preserves AD-19 single-script-file shape for the dispatch surface).
   Position: top of file after the arg-parsing block, before the
   rollback dispatch. The function:

   ```bash
   # Resolve update_source via AD-5: config first, then detection.
   # Outputs the resolved value on stdout. Bash 3.2 / POSIX-sh.
   # When detection lands on a non-git value, persists by writing
   # the value into .orchestrator/config.yml.
   resolve_update_source() {
     local proj="$1"
     local cfg="$proj/.orchestrator/config.yml"
     local resolved=""
     local detected=""

     # Path 1: read from config.
     if [ -f "$cfg" ]; then
       resolved="$(grep -E '^update_source:' "$cfg" 2>/dev/null \
         | head -1 | sed -E 's/^update_source:[[:space:]]*//' \
         | tr -d '"' | tr -d "'")"
     fi

     # If config has it, use it (operator wins).
     if [ -n "$resolved" ]; then
       echo "$resolved"
       return 0
     fi

     # Path 2: AD-5 detection ordering (D014).
     # 2a: install-meta.txt runtime= field.
     local meta="$proj/.orchestrator/install-meta.txt"
     if [ -f "$meta" ]; then
       local runtime
       runtime="$(grep -E '^runtime=' "$meta" 2>/dev/null \
         | head -1 | sed -E 's/^runtime=//' \
         | tr '[:upper:]' '[:lower:]')"
       case "$runtime" in
         *npm*)      detected="npm" ;;
         *homebrew*) detected="homebrew" ;;
         *brew*)     detected="homebrew" ;;
         *curl*)     detected="npm" ;;  # D012: curl-pipe-bash → npm
         *git*)      detected="git" ;;
       esac
     fi

     # 2b: npm global presence.
     if [ -z "$detected" ]; then
       if command -v npm >/dev/null 2>&1; then
         local npm_root
         npm_root="$(npm root -g 2>/dev/null)"
         if [ -n "$npm_root" ] && [ -d "$npm_root/@build-fractal/orchestrator" ]; then
           detected="npm"
         fi
       fi
     fi

     # 2c: homebrew formula presence.
     if [ -z "$detected" ]; then
       if command -v brew >/dev/null 2>&1; then
         local brew_prefix
         brew_prefix="$(brew --prefix 2>/dev/null)"
         if [ -n "$brew_prefix" ] && [ -d "$brew_prefix/Cellar/orchestrator" ]; then
           detected="homebrew"
         fi
       fi
     fi

     # 2d: fallback.
     if [ -z "$detected" ]; then
       detected="git"
     fi

     # Persist non-git detections to config (single-resolve discipline).
     # Skip persistence for git fallback (default behavior; persisting
     # would noise up every fresh consumer's config).
     if [ "$detected" != "git" ] && [ -d "$proj/.orchestrator" ]; then
       persist_update_source "$cfg" "$detected"
     fi

     echo "$detected"
   }

   # Append or replace the update_source: line in config.yml.
   # Single-resolve; idempotent on second invocation.
   persist_update_source() {
     local cfg="$1"
     local val="$2"
     # If config doesn't exist, write a minimal one.
     if [ ! -f "$cfg" ]; then
       printf 'schema_version: "1.0"\ntype: orchestrator-config\nupdate_source: %s\n' "$val" > "$cfg"
       return 0
     fi
     # If line exists, sed-replace.
     if grep -qE '^update_source:' "$cfg" 2>/dev/null; then
       local tmp="$cfg.tmp"
       sed -E "s/^update_source:.*/update_source: $val/" "$cfg" > "$tmp"
       mv "$tmp" "$cfg"
     else
       # Append at EOF.
       printf 'update_source: %s\n' "$val" >> "$cfg"
     fi
   }
   ```

3. **Wrap the existing source-repo validation + git dispatch (lines
   266+) inside a `case "$update_source" in git) ... ;;` arm**.
   Insert a new top-level dispatch block BEFORE line 266 (after the
   rollback block at line 264):

   ```bash
   # --- Multi-source dispatch (M035 P06 T02 / FR-13 / AD-5 / D014) ---
   #
   # Resolves update_source: config first (via T01's registered key),
   # then AD-5 detection (install-meta.txt runtime= / npm presence /
   # brew presence / git fallback). Persists detected non-git source
   # to config for future runs. The four channel arms dispatch to
   # the appropriate update command; --dry-run emits the would_invoke
   # line and exits 0.
   #
   # Rollback path above short-circuits before this block; the existing
   # git-source dispatch (formerly the only path) is now the git arm.

   update_source="$(resolve_update_source "$PROJECT_DIR")"

   case "$update_source" in
     git)
       # Existing path — fall through to the source-repo validation
       # and install dispatch below. No additional arming required.
       :
       ;;
     npm)
       if ! command -v npm >/dev/null 2>&1; then
         echo "FAIL: update_source=npm but npm not on PATH" >&2
         exit 1
       fi
       npm_root="$(npm root -g 2>/dev/null)"
       if [ -z "$npm_root" ] || [ ! -d "$npm_root/@build-fractal/orchestrator" ]; then
         echo "FAIL: @build-fractal/orchestrator not installed at npm global root: $npm_root" >&2
         exit 1
       fi
       if [ "$DRY_RUN" -eq 1 ]; then
         echo "would_invoke=npm update -g @build-fractal/orchestrator"
         exit 0
       fi
       echo "running npm update -g @build-fractal/orchestrator..."
       npm update -g @build-fractal/orchestrator
       rc=$?
       # T03 hooks update_run JSONL emission here (success path).
       echo "---"
       if [ "$rc" -eq 0 ]; then
         echo "orchestrator:update OK -- npm channel"
       else
         echo "FAIL: npm update exited $rc" >&2
       fi
       exit "$rc"
       ;;
     homebrew)
       if ! command -v brew >/dev/null 2>&1; then
         echo "FAIL: update_source=homebrew but brew not on PATH" >&2
         exit 1
       fi
       brew_prefix="$(brew --prefix 2>/dev/null)"
       if [ -z "$brew_prefix" ] || [ ! -d "$brew_prefix/Cellar/orchestrator" ]; then
         echo "FAIL: orchestrator not installed via brew at: $brew_prefix" >&2
         exit 1
       fi
       if [ "$DRY_RUN" -eq 1 ]; then
         echo "would_invoke=brew upgrade orchestrator"
         exit 0
       fi
       echo "running brew upgrade orchestrator..."
       brew upgrade orchestrator
       rc=$?
       # T03 hooks update_run JSONL emission here (success path).
       echo "---"
       if [ "$rc" -eq 0 ]; then
         echo "orchestrator:update OK -- homebrew channel"
       else
         echo "FAIL: brew upgrade exited $rc" >&2
       fi
       exit "$rc"
       ;;
     none)
       if [ "$DRY_RUN" -eq 1 ]; then
         echo "would_invoke=<no-op: update_source=none>"
         exit 0
       fi
       echo "update_source: none — dispatch suppressed (operator opt-out)"
       exit 0
       ;;
     *)
       echo "FAIL: unknown update_source=$update_source (expected git|npm|homebrew|none)" >&2
       exit 1
       ;;
   esac

   # Fall-through: update_source=git. The existing source-repo
   # validation + install dispatch below is now the git arm.
   ```

   Note: the `git` arm intentionally `:`'s through and falls into the
   existing dispatch at line 266+. This minimizes the diff and
   preserves the pre-M035-P06 behavior byte-for-byte for git-source
   consumers.

4. **Append D014 to [`.orchestrator/DECISIONS.md`](../../../../../decisions.md)**. Read the file at
   execution time to confirm the prevailing row format. The decision
   body verbatim:

   ```
   D014 — AD-5 detection ordering for orchestrator:update (M035 P06)

   When update_source is absent from config.yml, resolve via this
   ordering (first-match wins):

   1. .orchestrator/install-meta.txt runtime= field — if value contains
      the literal substring `npm` / `homebrew` / `brew` / `curl` / `git`
      (case-insensitive). `curl` resolves to `npm` per D012.
   2. npm global presence: command -v npm AND [ -d "$(npm root -g)/@build-fractal/orchestrator" ].
   3. homebrew formula presence: command -v brew AND [ -d "$(brew --prefix)/Cellar/orchestrator" ].
   4. Fallback: git.

   Detected non-git resolutions persist to .orchestrator/config.yml
   via in-place sed-replace (existing line) or EOF append (absent
   line). Single-resolve discipline: subsequent runs hit the
   persisted config and skip detection. Git-fallback resolutions are
   NOT persisted (default behavior; persisting would noise up every
   fresh consumer's config).

   Bound by FR-13 + AD-5 + SC-13.
   ```

5. **Author the verifier**
   `tools/verify/m035-p06-multi-source-dispatch-shape.sh`.
   Single-script-file shape, AD-19, ~80 lines. Sources
   `scripts/lib/errors.sh`. Asserts:

   1. `scripts/lifecycle/run-update.sh` is readable.
   2. The file contains the literal token `case "$update_source" in`.
   3. The file contains all four arm tokens: `git)`, `npm)`,
      `homebrew)`, `none)`.
   4. The file contains the literal token `resolve_update_source`
      (helper present).
   5. The file contains the literal token `persist_update_source`
      (persistence helper present).
   6. The file contains all four `would_invoke=` strings (one per
      channel).
   7. [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) contains the literal token `D014`.
   8. Stage four temp project fixtures under
      `/tmp/m035-p06-t02-dispatch-fixture-$$/{git,npm,homebrew,none}/`,
      each with a minimal `.orchestrator/config.yml` carrying the
      corresponding `update_source: <value>` line. Invoke
      `bash scripts/lifecycle/run-update.sh --project-dir <fixture>
      --dry-run` against each. Assert stdout contains the expected
      `would_invoke=<channel-command>` substring per fixture.
   9. Stage a fifth fixture with NO `update_source` line and an
      `install-meta.txt` carrying `runtime=npm-postinstall`. Invoke
      `--dry-run` and assert stdout contains
      `would_invoke=npm update -g`. Then assert the fixture's
      `config.yml` was rewritten to contain `update_source: npm`
      (persistence side-effect verified).
   10. Stage a sixth fixture with `update_source: invalid_value`.
       Invoke `--dry-run` and assert exit code is non-zero AND stderr
       contains the literal `FAIL: unknown update_source`.

   Emit `BATTERY: pass=N fail=0` summary. Cleanup fixtures via EXIT
   trap.

   The verifier MUST honor AD-19 — no inline compound chains. Use
   intermediate variables and `if` blocks for compound logic. Output
   capture uses `>$tmpfile 2>$err_log` plain redirection (mirrors P05
   T06 pattern), not process substitution.

## Must-Haves

- `scripts/lifecycle/run-update.sh` modified — contains
  `resolve_update_source`, `persist_update_source`,
  `case "$update_source" in`, all four channel arms, all four
  `would_invoke=` strings.
- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) modified — contains a `D014` row
  referencing M035/P06 + AD-5 detection ordering.
- `tools/verify/m035-p06-multi-source-dispatch-shape.sh` exists,
  executable, ~80+ lines, contains `BATTERY:` and `update_source`,
  runs against staged fixtures, emits `BATTERY: pass=N fail=0`.

## Verification

```bash
bash tools/verify/m035-p06-multi-source-dispatch-shape.sh
```

```bash
bash tools/verify/m035-p06-config-schema-shape.sh
```

## Inputs

### From Previous Tasks

- `scripts/state/read-config.sh` (from T01)
  - Key API: `bash scripts/state/read-config.sh --root <path> update_source`
    returns the resolved value on stdout (or `null`/empty when absent).
  - Key types: scalar string returning one of `git|npm|homebrew|none`
    or any operator-supplied string (T01 explicitly does NOT enforce
    the enumeration; T02's dispatch handles unknown values).

### From Disk (Pre-existing)

- `scripts/lifecycle/run-update.sh` — existing rollback dispatch
  (lines 104–264) and existing source-repo validation + git dispatch
  (lines 266+). T02 inserts the multi-source dispatch BETWEEN the two,
  wrapping the existing git path in a `git)` case arm.
- `.orchestrator/install-meta.txt` schema (M035 P01 / FR-9 amendment) —
  five fields: `source_root=`, `runtime=`, `installed_at=`,
  `commit_sha=`, `version=`. Read by AD-5 step 1.
- `.orchestrator/config.yml` — top-level YAML map. T02's
  `persist_update_source` writes `update_source: <value>` as a
  top-level key.
- `scripts/lib/errors.sh` — sourceable lib exporting `emit_result`.
  Used by the verifier.

## Constraints

- **AD-19 single-script-file shape** — every check command is `bash
  tools/verify/m035-p06-*.sh`. No inline compound chains; no
  `$(... | ...)`; no plain subshells. The dispatch helpers
  (`resolve_update_source`, `persist_update_source`) live INSIDE
  `run-update.sh` — keeping them inline preserves the single-script
  shape for the driver itself.
- **Bash 3.2 + POSIX-sh** — CON-2/CON-7. The dispatch helpers run on
  macOS bash 3.2 unmodified.
- **AD-5 detect-by-install-method-first** — config wins when present;
  detection runs only when config is absent. First-match-wins
  ordering per D014.
- **Single-resolve discipline** — detected non-git source persists to
  config; subsequent runs hit the persisted value and skip detection.
  Git fallback does NOT persist (operator-friendly default).
- **No regression on the git path** — the existing source-repo
  validation + install dispatch (lines 266+) is wrapped in a `git)`
  case arm with `:` fall-through. Behavior is byte-identical for
  git-source consumers.
- **JSONL emission is T03's territory** — T02's dispatch arms include
  comments marking where T03's emission hooks land. T02 itself does
  NOT emit; T03 inserts the emission calls in the next task.
- **Plan-Time Discipline Rule 6 (Path-collision)** — `ls -la`
  performed against `tools/verify/m035-p06-multi-source-dispatch-shape.sh`;
  ABSENT.

## Expected Output

Stdout from `bash tools/verify/m035-p06-multi-source-dispatch-shape.sh`:

```
PASS: run-update.sh contains case "$update_source" in
PASS: run-update.sh contains all four channel arms (git/npm/homebrew/none)
PASS: run-update.sh contains resolve_update_source helper
PASS: run-update.sh contains persist_update_source helper
PASS: run-update.sh contains all four would_invoke= strings
PASS: DECISIONS.md contains D014 anchor
PASS: --dry-run against update_source: git fixture emits would_invoke=bash ... install-claude-code.sh ... --force
PASS: --dry-run against update_source: npm fixture emits would_invoke=npm update -g @build-fractal/orchestrator
PASS: --dry-run against update_source: homebrew fixture emits would_invoke=brew upgrade orchestrator
PASS: --dry-run against update_source: none fixture emits would_invoke=<no-op: update_source=none>
PASS: AD-5 detection resolves to npm via install-meta.txt runtime=npm-postinstall
PASS: AD-5 detection persists detected source to config.yml
PASS: --dry-run against update_source: invalid_value exits non-zero with FAIL: unknown update_source
BATTERY: pass=13 fail=0
```
