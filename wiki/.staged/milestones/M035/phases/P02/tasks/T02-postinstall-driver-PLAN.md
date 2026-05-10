---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M035"
name: "packaging/npm/postinstall.sh driver (Unix-delegate, Windows fail-closed, INIT_CWD-aware)"
depends_on: ["T01"]
---

## Prerequisites

- **T01 complete**: `package.json` exists at the repo root with
  `"scripts": {"postinstall": "bash packaging/npm/postinstall.sh"}`
  and `"os": ["darwin", "linux"]`. The postinstall script T02
  authors is the target of that script reference.
- **`packaging/install/install-claude-code.sh` exists** ([M025](../../../../../milestones/M025/index.md)
  surface, on disk since 2026-04-23). T02's driver delegates to
  this script after passing the Unix/Windows guard.
- **`packaging/install/install-codex.sh` and
  `packaging/install/install-cursor.sh` exist** (M025 surface).
  T02's driver detects the active runtime via the convention
  documented below and dispatches to the matching installer.
- **No `packaging/npm/` directory exists yet** (Plan-Time Discipline
  Rule 6 — confirmed at plan-authoring time).

## Description

Author the postinstall driver `packaging/npm/postinstall.sh` that
runs after `npm install -g @build-fractal/orchestrator`. The
postinstall:

1. Refuses on Windows-detected `uname -s` (`MINGW*`/`CYGWIN*`/`MSYS*`/
   `Windows_NT`) with a clear stderr message (#Q-G9 / MIT-9 belt-and-
   suspenders — `package.json os` field is the primary gate, this is
   the secondary).
2. Honors `DRY_RUN=1` env var: emits `would_invoke=...` lines, makes
   no writes (D002 fixture-strategy contract).
3. Resolves the project directory from `INIT_CWD` env var (npm
   convention — npm sets this to the directory the user ran `npm
   install` from). Falls back to `$PWD` if `INIT_CWD` is unset.
4. Detects the active Claude Code runtime by probing for
   `~/.claude/` directory. If present, delegates to `install-claude-
   code.sh --project-dir "$INIT_CWD"`. If absent, emits a
   `runtime_unavailable=true` advisory line (no failure — `bin/
   orchestrator --version` still works) and exits 0 with a stderr
   note explaining how to install Claude Code.
5. Codex CLI / Cursor runtime detection is stubbed at v1: the v1
   postinstall only delegates to claude-code. Multi-runtime postinstall
   is M009 territory (post-launch).

## Steps

1. **Create `packaging/npm/` directory** (if it doesn't exist):

   ```bash
   mkdir -p packaging/npm
   ```

2. **Author `packaging/npm/postinstall.sh`** with shebang
   `#!/usr/bin/env bash` and verbatim body:

   ```bash
   #!/usr/bin/env bash
   # packaging/npm/postinstall.sh -- npm postinstall driver for
   # @build-fractal/orchestrator (M035 P02 T02).
   #
   # Runs automatically after `npm install -g @build-fractal/orchestrator`.
   # Wraps the existing M025 installers (install-claude-code.sh) with:
   #   * Windows fail-closed guard (MIT-9 / D003 belt-and-suspenders)
   #   * DRY_RUN=1 honor (D002 test-fixture contract)
   #   * INIT_CWD-aware project-dir resolution (npm convention)
   #   * Runtime detection: Claude Code at v1; Codex/Cursor stubbed
   #
   # Exit codes:
   #   0 success (or runtime_unavailable advisory — non-blocking)
   #   1 Windows refused, or Unix delegate failed
   #
   # Bash 3.2 compatible. No declare -A, no jq, no python.

   set -u

   # --- 1. Windows fail-closed guard (#Q-G9 / MIT-9) -------------------

   uname_s="$(uname -s 2>/dev/null || echo unknown)"
   case "$uname_s" in
     MINGW*|CYGWIN*|MSYS*|Windows_NT|WindowsNT)
       echo "FAIL: @build-fractal/orchestrator postinstall does not run on Windows." >&2
       echo "      Windows symlink-mode and runtime parity are deferred to" >&2
       echo "      post-launch milestone M009 (multi-runtime parity audit)." >&2
       echo "      The package.json os field should have caught this on npm's" >&2
       echo "      side; if you see this message, please file an issue at" >&2
       echo "      https://github.com/Build-Fractal/orchestrator/issues" >&2
       exit 1
       ;;
   esac

   # --- 2. Resolve REPO_ROOT (where the npm package extracted) -------

   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   # packaging/npm/postinstall.sh -> repo root is 2 levels up
   REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   INSTALLER="$REPO_ROOT/packaging/install/install-claude-code.sh"

   # --- 3. Resolve INIT_CWD (npm convention) -------------------------

   # npm sets INIT_CWD to the directory `npm install` was run from.
   # When `npm install -g` runs without a project context, INIT_CWD
   # may be unset or point at the global npm prefix — in that case
   # the postinstall is a "package present, project not yet chosen"
   # event and we skip skill registration entirely.
   PROJECT_DIR="${INIT_CWD:-${PWD:-}}"

   # If PROJECT_DIR is empty or matches the npm global prefix, treat
   # this as a "global install, no project" event — emit advisory only.
   NPM_PREFIX="$(npm config get prefix 2>/dev/null || echo "")"
   if [ -z "$PROJECT_DIR" ] || [ "$PROJECT_DIR" = "$NPM_PREFIX" ] || \
      [ "$PROJECT_DIR" = "$NPM_PREFIX/lib/node_modules" ]; then
     echo "ADVISORY: @build-fractal/orchestrator installed globally; no project context." >&2
     echo "          Run \`orchestrator --help\` for next steps. Per-project skill" >&2
     echo "          registration happens when you run /orchestrator-init inside a" >&2
     echo "          Claude Code project." >&2
     exit 0
   fi

   # --- 4. Honor DRY_RUN=1 (D002 test-fixture contract) --------------

   DRY_RUN="${DRY_RUN:-0}"
   if [ "$DRY_RUN" = "1" ]; then
     echo "would_invoke=$INSTALLER --project-dir $PROJECT_DIR"
     echo "would_check=~/.claude/ runtime presence"
     echo "would_delegate=install-claude-code.sh"
     exit 0
   fi

   # --- 5. Detect Claude Code runtime --------------------------------

   if [ ! -d "$HOME/.claude" ]; then
     echo "runtime_unavailable=true" >&2
     echo "ADVISORY: @build-fractal/orchestrator installed, but Claude Code is" >&2
     echo "          not detected at \$HOME/.claude. Skill registration deferred." >&2
     echo "          Install Claude Code (https://claude.com/claude-code) and" >&2
     echo "          re-run \`bash $INSTALLER --project-dir <path>\` to register" >&2
     echo "          skills, OR run /orchestrator-init inside any Claude Code" >&2
     echo "          project to register on first use." >&2
     exit 0
   fi

   # --- 6. Delegate to install-claude-code.sh ------------------------

   if [ ! -x "$INSTALLER" ]; then
     echo "FAIL: installer not found or not executable at $INSTALLER" >&2
     exit 1
   fi

   echo "delegating=$INSTALLER --project-dir $PROJECT_DIR"
   "$INSTALLER" --project-dir "$PROJECT_DIR"
   ```

3. **Make the postinstall executable**:

   ```bash
   chmod +x packaging/npm/postinstall.sh
   ```

4. **Author the postinstall-shape verifier** at
   `tools/verify/m035-p02-postinstall-shape.sh` with body:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p02-postinstall-shape.sh
   # Asserts packaging/npm/postinstall.sh exists, is executable, and
   # carries the load-bearing M035 P02 T02 contract surfaces:
   #   * Windows fail-closed guard (uname -s case match)
   #   * DRY_RUN=1 honor (would_invoke= line shape)
   #   * INIT_CWD resolution (npm convention)
   #   * runtime_unavailable advisory path (Claude Code absence)
   #   * delegation to install-claude-code.sh
   set -euo pipefail

   REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
   POSTINSTALL="$REPO/packaging/npm/postinstall.sh"

   pass=0
   fail=0

   if [ ! -f "$POSTINSTALL" ]; then
     echo "FAIL: $POSTINSTALL not found"
     fail=$((fail + 1))
   elif [ ! -x "$POSTINSTALL" ]; then
     echo "FAIL: $POSTINSTALL not executable"
     fail=$((fail + 1))
   else
     echo "PASS: postinstall.sh exists and is executable"
     pass=$((pass + 1))
   fi

   check_grep() {
     local pattern="$1"
     local label="$2"
     if grep -qE "$pattern" "$POSTINSTALL"; then
       echo "PASS: $label"
       pass=$((pass + 1))
     else
       echo "FAIL: $label (pattern: $pattern)"
       fail=$((fail + 1))
     fi
   }

   check_grep 'Windows_NT' "Windows fail-closed guard names Windows_NT (MIT-9)"
   check_grep 'MINGW\*|CYGWIN\*|MSYS\*' "Windows fail-closed guard names MINGW/CYGWIN/MSYS (MIT-9)"
   check_grep 'INIT_CWD' "INIT_CWD resolution (npm convention)"
   check_grep 'DRY_RUN' "DRY_RUN=1 honor (D002 fixture-strategy)"
   check_grep 'would_invoke=' "DRY_RUN=1 emits would_invoke= lines"
   check_grep 'install-claude-code\.sh' "delegates to install-claude-code.sh"
   check_grep 'runtime_unavailable=true' "runtime_unavailable advisory path (Claude Code absence)"

   # Functional smoke test: DRY_RUN=1 invocation emits would_invoke=
   # without making writes. Use a temp project dir to avoid polluting.
   TMPDIR_PROBE="$(mktemp -d 2>/dev/null || mktemp -d -t m035p02t02)"
   if INIT_CWD="$TMPDIR_PROBE" DRY_RUN=1 bash "$POSTINSTALL" 2>&1 \
        | grep -q '^would_invoke='; then
     echo "PASS: DRY_RUN=1 dry-run emits would_invoke= line"
     pass=$((pass + 1))
   else
     echo "FAIL: DRY_RUN=1 dry-run did not emit would_invoke="
     fail=$((fail + 1))
   fi
   rm -rf "$TMPDIR_PROBE" 2>/dev/null || true

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   Make it executable: `chmod +x tools/verify/m035-p02-postinstall-shape.sh`

5. **Self-check**:

   ```bash
   bash tools/verify/m035-p02-postinstall-shape.sh
   ```

   Must emit `BATTERY: pass=N fail=0` (8 PASS lines expected).

6. **Cross-reference verification — confirm `package.json scripts.postinstall` resolves**:

   ```bash
   bash scripts/util/run-probe.sh /tmp/m035-p02-t02-postinstall-resolve.sh
   ```

   Stage probe `/tmp/m035-p02-t02-postinstall-resolve.sh`:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   POSTINSTALL_REF="$(grep -E '"postinstall"[[:space:]]*:' \
     "$REPO_ROOT/package.json" | sed -E 's/.*"postinstall"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
   POSTINSTALL_PATH="$(echo "$POSTINSTALL_REF" | sed -E 's/^bash //')"
   if [ -x "$REPO_ROOT/$POSTINSTALL_PATH" ]; then
     echo "PASS: package.json scripts.postinstall resolves to executable: $POSTINSTALL_PATH"
   else
     echo "FAIL: package.json scripts.postinstall ($POSTINSTALL_PATH) not executable"
     exit 1
   fi
   ```

   Must emit `PASS:`. This is the cross-reference contract between
   T01's `package.json` and T02's postinstall driver.

## Must-Haves

This task addresses the following phase must-haves:

- Truth: `packaging/npm/postinstall.sh` exists, executable, refuses
  Windows, respects `DRY_RUN=1`, delegates to
  `install-claude-code.sh` with `--project-dir "$INIT_CWD"`
- Artifact: `packaging/npm/postinstall.sh` (min 40 lines, contains
  `Windows_NT` AND `INIT_CWD`)
- Key Link: `packaging/npm/postinstall.sh` → `packaging/install/install-claude-code.sh`

## Verification

```bash
bash tools/verify/m035-p02-postinstall-shape.sh
bash scripts/util/run-probe.sh /tmp/m035-p02-t02-postinstall-resolve.sh
```

## Inputs

### From Previous Tasks

- `package.json` (from T01)
  - Key API: contains `"scripts": {"postinstall": "bash
    packaging/npm/postinstall.sh"}` field. T02 authors the file
    that reference points to.
  - Key types: JSON object; npm-conformant `scripts.postinstall`
    is a shell command string.

### From Disk (Pre-existing)

- `packaging/install/install-claude-code.sh` — M025 installer surface.
  T02's driver delegates to it via `"$INSTALLER" --project-dir
  "$PROJECT_DIR"`. Do not modify this file in T02; only invoke.
  Existing flag contract (relevant to T02): `--project-dir PATH`
  (M025) sets the project root; `--dry-run` (M025) is the M025
  dry-run mode but T02's `DRY_RUN=1` is a separate npm-postinstall-
  layer dry-run that exits before invoking the installer at all.
- `scripts/util/run-probe.sh` — staged-probe wrapper for step 6.
  AP-009 / CON-3 honored.

## Constraints

- **AP-009 / CON-3 (compound-chain shape-guard)**: postinstall.sh
  itself is bash 3.2 compatible. The verifier's functional smoke
  test uses a temp dir to avoid filesystem pollution.
- **MIT-9 / D003 (Windows fail-closed belt-and-suspenders)**: the
  postinstall MUST exit non-zero on Windows-detected uname even
  though `package.json os: ["darwin", "linux"]` is the primary
  gate. Defense-in-depth.
- **D002 (DRY_RUN=1 contract)**: when `DRY_RUN=1` env var is set,
  postinstall MUST NOT invoke the installer. Must emit
  `would_invoke=...` lines. T03's byte-equivalence test relies on
  this contract.
- **No-runtime-detected is a soft failure**: if `~/.claude/` is
  absent, postinstall emits the advisory but exits 0. The npm
  install completes; skill registration is deferred to first
  `/orchestrator-init` invocation. Rationale: an `npm install -g`
  on a CI runner without Claude Code is a legitimate use case
  (operator wants the binary on PATH for later integration).
- **No INIT_CWD fallback to interactive prompt**: when `INIT_CWD`
  is unset OR matches the npm prefix, postinstall emits the
  global-install advisory and exits 0. Do not attempt to detect a
  project elsewhere.
- **CON-7 (M025 reversibility-gate preserved)**: postinstall does
  NOT bypass M025's manifest mechanism — it delegates to
  `install-claude-code.sh`, which writes the manifest as it would
  on any other invocation. `npm uninstall -g` does not currently
  cascade through the manifest (npm's npm-side uninstall removes
  the package files but doesn't run a script — there's no
  `preuninstall` hook reliable across npm versions). M035 P06
  extends `commands/update.md --rollback` for the npm uninstall
  cascade story; T02 only authors postinstall.

## Expected Output

Two new files on disk:

- `packaging/npm/postinstall.sh` (~80 lines, executable)
- `tools/verify/m035-p02-postinstall-shape.sh` (~70 lines, executable)
- One staged probe: `/tmp/m035-p02-t02-postinstall-resolve.sh`

`bash tools/verify/m035-p02-postinstall-shape.sh` emits `BATTERY:
pass=8 fail=0` (1 file-shape check + 6 grep checks + 1 functional
DRY_RUN smoke).

## Notes

Expected verifier output: 8 `PASS:` lines + 1 `BATTERY: pass=8
fail=0` line.

The functional DRY_RUN smoke in step 4's verifier is the closest
thing to a real-postinstall test we can run pre-publish. Plan-Time
Discipline Rule 5 (real-DB verification analog): there's no
"real npm registry verification" we can do at plan-execution time
without coupling to the registry. T03's `npm pack`-based byte-
equivalence test is the closest mechanical proxy; T04's CI
workflow is the only place a real `npm publish` runs (and then only
on `v*` tag-push events on the canonical repo).

Idempotency: re-running the postinstall under `DRY_RUN=1` is
side-effect-free. Re-running without DRY_RUN re-invokes the
installer, which is itself idempotent per M025's manifest replay.

Reversibility: removing `packaging/npm/postinstall.sh` and
`packaging/npm/` unwinds the task. T01's `package.json scripts.
postinstall` reference would then be a dangling pointer — `npm
install` would fail. Rollback ordering: T02 deletion must precede
T01 `package.json scripts.postinstall` field removal.
