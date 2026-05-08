---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M035"
name: "package.json + bin/orchestrator entry point (FR-8 minimum surface, MIT-9 platform guards)"
depends_on: []
---

## Prerequisites

- **P01.5 closed** with `D-RN-1` (`@build-fractal/orchestrator`) recorded
  in `.orchestrator/DECISIONS.md` (anchor `dr-code-029`). This task
  binds `package.json` `name` to that decision.
- **`CHANGELOG.md`** exists at the repo root with a `## [<version>]`
  top-line entry (skipping `## [Unreleased]`). The `awk` recipe used at
  P01.5/T01 is: `awk '/^## \[[0-9]/{gsub(/[\[\]]/, "", $2); print $2;
  exit}' CHANGELOG.md`. Author-time read at T01 step 1 captures the
  literal version string; if `CHANGELOG.md` top-line is `## [0.9.3]`,
  the captured string is `0.9.3` and `package.json` `version` becomes
  `"0.9.3"`.
- No `package.json` or `bin/` exists at the repo root yet
  (Plan-Time Discipline Rule 6 — path-collision check ran at
  plan-authoring time and confirmed both paths absent).
- `D001` (CI runner) and `D003` (Windows guard binding) are recorded
  in `.orchestrator/DECISIONS.md` as 7-column-table rows; this task
  references them but does not extend them.

## Description

Author the npm v1 manifest (`package.json`) and the binary entry point
(`bin/orchestrator`). This is the load-bearing first surface the npm
tarball ships — it bakes the package name, the cohort prefix, and the
platform guards forever. Belt-and-suspenders Windows fail-closed via
`engines`/`os` (npm-side) plus `bin/orchestrator` runtime guard.

The `bin/orchestrator` script is intentionally minimal at v1: it
prints version on `--version`, prints a usage banner naming the
`orchestrator:<cmd>` cohort prefix on `--help` or no-args, and exits
non-zero with a clear message on any other invocation. v1 does NOT
implement subcommand dispatch — adopters reach orchestrator commands
through the registered Claude Code skills, not through the binary.
The binary's job is to be present on `PATH` (so `which orchestrator`
returns 0) and to survive `--version` checks; the post-v1 vision of a
binary CLI is post-launch territory.

## Steps

1. **Capture the version string from CHANGELOG.md top-line**:

   ```bash
   bash scripts/util/run-probe.sh /tmp/m035-p02-t01-changelog-read.sh
   ```

   Stage the probe script (Write tool) at
   `/tmp/m035-p02-t01-changelog-read.sh` with body:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   awk '/^## \[[0-9]/{gsub(/[\[\]]/, "", $2); print $2; exit}' \
     "$REPO_ROOT/CHANGELOG.md"
   ```

   `REPO_ROOT` is the env var run-probe.sh exports. The script emits
   the bare version string (e.g. `0.9.3`) on stdout. Capture into a
   shell variable for use in step 2. If empty, FAIL with
   "CHANGELOG.md top-line not parseable".

2. **Author `package.json`** at the repo root with the following
   verbatim fields (using the captured version string in step 1 —
   the `<VERSION>` placeholder below is substituted in):

   ```json
   {
     "name": "@build-fractal/orchestrator",
     "version": "<VERSION>",
     "description": "Autonomous multi-phase orchestration skills for Claude Code, Codex, and Cursor",
     "homepage": "https://github.com/Build-Fractal/orchestrator",
     "repository": {
       "type": "git",
       "url": "git+https://github.com/Build-Fractal/orchestrator.git"
     },
     "license": "MIT",
     "author": "Build-Fractal",
     "bin": {
       "orchestrator": "bin/orchestrator"
     },
     "scripts": {
       "postinstall": "bash packaging/npm/postinstall.sh"
     },
     "engines": {
       "node": ">=14"
     },
     "os": [
       "darwin",
       "linux"
     ],
     "files": [
       "bin/",
       "commands/",
       "scripts/",
       "templates/",
       "references/",
       "packaging/install/",
       "packaging/bundle/",
       "packaging/npm/",
       "packaging/SKILL.md",
       "CHANGELOG.md",
       "CLAUDE.md",
       "LICENSE",
       "README.md"
     ],
     "keywords": [
       "orchestrator",
       "claude-code",
       "codex",
       "cursor",
       "ai-coding",
       "autonomous-agents",
       "spec-driven-development"
     ]
   }
   ```

   Notes:
   - The `files` array is the npm whitelist; `node_modules`,
     `.orchestrator`, `specs/`, `tests/`, `tools/`, `docs/`,
     `wiki/`, `.git/`, `.github/`, `.planning/`, `.claude/`,
     `m[0-9]*-p[0-9]*-*` verifiers under whitelisted dirs are NOT
     reachable. T05's bundle-hygiene filter handles intra-directory
     dogfood exclusion.
   - The `os` array is the load-bearing #Q-G9 / MIT-9 npm-side guard.
     npm itself rejects install on win32 with `EBADPLATFORM` when
     this field is present and excludes the platform.
   - The `engines.node >=14` constraint is the postinstall driver's
     prerequisite (postinstall script is bash but uses `INIT_CWD`
     env var which npm sets only on supported node versions).

3. **Author `bin/orchestrator`** at the repo root with shebang `#!/usr/bin/env bash`,
   verbatim body:

   ```bash
   #!/usr/bin/env bash
   # bin/orchestrator -- v1 binary entry point for @build-fractal/orchestrator.
   #
   # v1 surface: --version, --help, no-args banner. No subcommand dispatch.
   # Adopters reach orchestrator commands through registered Claude Code
   # skills (orchestrator:<cmd> prefix per D-RN-3 / dr-code-031), not
   # through this binary. The binary's load-bearing v1 job is to be
   # present on PATH so `which orchestrator` returns 0 and so package-
   # manager smoke tests survive `orchestrator --version`.
   #
   # Bash 3.2 compatible. No declare -A, no jq, no python.

   set -u

   # Resolve the package.json beside the bin directory.
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   PKG_JSON="$SCRIPT_DIR/../package.json"

   read_version() {
     # Bash 3.2 + grep + sed only — no jq dependency.
     # package.json "version" line shape: "version": "X.Y.Z",
     if [ ! -f "$PKG_JSON" ]; then
       echo "FAIL: package.json not found at $PKG_JSON" >&2
       return 1
     fi
     grep -E '^[[:space:]]*"version"[[:space:]]*:' "$PKG_JSON" \
       | head -1 \
       | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
   }

   print_banner() {
     local v
     v="$(read_version)" || return 1
     cat <<EOF
   @build-fractal/orchestrator v${v}

   Autonomous multi-phase orchestration skills for Claude Code, Codex,
   and Cursor. Adopter commands ship as registered skills with the
   prefix orchestrator:<cmd> — see installed CLAUDE.md or
   references/installation.md for the command surface.

   Quick start:
     orchestrator --version          # this binary's version
     /orchestrator-init               # (in Claude Code) bootstrap a project
     /orchestrator-status             # (in Claude Code) headline status

   Documentation: https://github.com/Build-Fractal/orchestrator
   EOF
   }

   case "${1:-}" in
     --version|-v)
       read_version
       ;;
     --help|-h|"")
       print_banner
       ;;
     *)
       echo "FAIL: unknown invocation '$1'. The orchestrator binary surface is" >&2
       echo "      --version, --help, or no-args. Adopter commands ship as" >&2
       echo "      registered skills with the prefix 'orchestrator:<cmd>' —" >&2
       echo "      run them inside Claude Code via /orchestrator-<cmd>." >&2
       exit 1
       ;;
   esac
   ```

4. **Make the bin script executable**:

   ```bash
   chmod +x bin/orchestrator
   ```

5. **Author the package.json shape verifier** at
   `tools/verify/m035-p02-package-json-shape.sh` with body:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p02-package-json-shape.sh
   # Asserts package.json declares the load-bearing M035/P02 fields:
   # name, bin.orchestrator, engines.node, os: [darwin, linux],
   # scripts.postinstall, version (non-empty).
   set -euo pipefail

   PKG="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}/package.json"

   if [ ! -f "$PKG" ]; then
     echo "FAIL: $PKG not found"
     exit 1
   fi

   pass=0
   fail=0

   check_grep() {
     local pattern="$1"
     local label="$2"
     if grep -qE "$pattern" "$PKG"; then
       echo "PASS: $label"
       pass=$((pass + 1))
     else
       echo "FAIL: $label (pattern: $pattern)"
       fail=$((fail + 1))
     fi
   }

   check_grep '"name"[[:space:]]*:[[:space:]]*"@build-fractal/orchestrator"' \
     "name=@build-fractal/orchestrator (D-RN-1)"
   check_grep '"version"[[:space:]]*:[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+' \
     "version is SemVer-shape (CON-4)"
   check_grep '"orchestrator"[[:space:]]*:[[:space:]]*"bin/orchestrator"' \
     "bin.orchestrator -> bin/orchestrator"
   check_grep '"postinstall"[[:space:]]*:[[:space:]]*"bash packaging/npm/postinstall.sh"' \
     "scripts.postinstall -> packaging/npm/postinstall.sh"
   check_grep '"node"[[:space:]]*:[[:space:]]*">=14"' \
     "engines.node >=14 (D003 / MIT-9)"
   check_grep '"darwin"' \
     "os contains darwin (D003 / MIT-9)"
   check_grep '"linux"' \
     "os contains linux (D003 / MIT-9)"

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   Make it executable: `chmod +x tools/verify/m035-p02-package-json-shape.sh`

6. **Author the bin-entry verifier** at
   `tools/verify/m035-p02-bin-entry.sh` with body:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p02-bin-entry.sh
   # Asserts bin/orchestrator exists, is executable, --version emits the
   # package.json version, and the no-args banner names the cohort prefix.
   set -euo pipefail

   REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
   BIN="$REPO/bin/orchestrator"

   pass=0
   fail=0

   if [ ! -f "$BIN" ]; then
     echo "FAIL: $BIN not found"
     fail=$((fail + 1))
   elif [ ! -x "$BIN" ]; then
     echo "FAIL: $BIN not executable"
     fail=$((fail + 1))
   else
     echo "PASS: bin/orchestrator exists and is executable"
     pass=$((pass + 1))
   fi

   # Compare bin --version output to package.json version field.
   PKG_VERSION="$(grep -E '^[[:space:]]*"version"[[:space:]]*:' "$REPO/package.json" \
     | head -1 \
     | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"

   BIN_VERSION="$(bash "$BIN" --version 2>/dev/null || true)"

   if [ "$BIN_VERSION" = "$PKG_VERSION" ] && [ -n "$BIN_VERSION" ]; then
     echo "PASS: bin --version matches package.json version ($BIN_VERSION)"
     pass=$((pass + 1))
   else
     echo "FAIL: bin --version='$BIN_VERSION' != package.json version='$PKG_VERSION'"
     fail=$((fail + 1))
   fi

   # No-args banner names the cohort prefix.
   if bash "$BIN" 2>&1 | grep -q 'orchestrator:<cmd>'; then
     echo "PASS: no-args banner names orchestrator:<cmd> cohort prefix (D-RN-3)"
     pass=$((pass + 1))
   else
     echo "FAIL: no-args banner missing 'orchestrator:<cmd>' cohort reference"
     fail=$((fail + 1))
   fi

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   Make it executable.

7. **Self-check by running the two verifiers**:

   ```bash
   bash tools/verify/m035-p02-package-json-shape.sh
   bash tools/verify/m035-p02-bin-entry.sh
   ```

   Both must emit `BATTERY: pass=N fail=0`. If either fails, fix the
   underlying artifact (do not weaken the verifier).

8. **Validate JSON validity**:

   ```bash
   bash scripts/util/run-probe.sh /tmp/m035-p02-t01-json-validate.sh
   ```

   Stage probe `/tmp/m035-p02-t01-json-validate.sh`:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   python3 -c "import json; json.load(open('$REPO_ROOT/package.json'))"
   echo "PASS: package.json is valid JSON"
   ```

   Must emit `PASS:`. If python3 unavailable, fall back to
   `node -e "JSON.parse(require('fs').readFileSync('$REPO_ROOT/package.json'))"`.

## Must-Haves

This task addresses the following phase must-haves:

- Truth: `package.json` exists with the load-bearing fields
  (D-RN-1, D003, CON-4)
- Truth: `bin/orchestrator` exists, is executable, `--version`
  emits the package.json version, banner names the cohort prefix
- Artifact: `package.json` (min 30 lines, contains
  `@build-fractal/orchestrator`)
- Artifact: `bin/orchestrator` (min 20 lines, contains `--version`)
- Key Link: `package.json` → `bin/orchestrator`
- Key Link: `package.json` → `packaging/npm/postinstall.sh`
  (postinstall reference; T02 authors the actual file)

## Verification

```bash
bash tools/verify/m035-p02-package-json-shape.sh
bash tools/verify/m035-p02-bin-entry.sh
bash scripts/util/run-probe.sh /tmp/m035-p02-t01-json-validate.sh
```

## Inputs

### From Previous Tasks

None. This is the first task in the phase.

### From Disk (Pre-existing)

- `CHANGELOG.md` — top-line `## [<version>]` entry is the version
  source-of-truth (CON-4 / A-7). T01 step 1 reads it via awk; the
  `## [Unreleased]` placeholder line is skipped by the
  `/^## \[[0-9]/` regex.
- `.orchestrator/DECISIONS.md` — `D-RN-1` (anchor `dr-code-029`)
  binds the npm package name; `D003` binds the Windows guard.
  Read for documentation cross-reference; not modified.
- `scripts/util/run-probe.sh` — staged-probe wrapper for the bulk
  shell logic in steps 1 and 8. AP-009 / CON-3 honored.

## Constraints

- **AP-009 / CON-3 (compound-chain shape-guard)**: this task uses
  the staged-probe-via-run-probe.sh wrapper for any shell logic
  that exceeds two compound statements. No inline `bash -c '...'
  && bash -c '...'` chains.
- **JSON validity invariant**: every edit to `package.json` must
  preserve well-formed JSON. Validated in step 8.
- **CON-4 (CHANGELOG SemVer source-of-truth)**: `package.json`
  `version` is read from `CHANGELOG.md` top-line at author-time;
  no hardcoded version string in the plan.
- **MIT-9 / D003 (Windows fail-closed)**: `package.json` `os` field
  is npm-side guard; `bin/orchestrator` does NOT carry a Windows
  runtime guard (the binary is platform-agnostic — it's the
  postinstall script that requires Unix). T02 authors the
  postinstall guard.
- **No bin subcommand dispatch at v1**: `bin/orchestrator` exits
  non-zero on any unrecognized argument. v1 surface is
  `--version`, `--help`, no-args. Subcommand dispatch is
  post-launch territory.

## Expected Output

Five new files on disk:

- `package.json` (~80 lines)
- `bin/orchestrator` (~50 lines, executable)
- `tools/verify/m035-p02-package-json-shape.sh` (~40 lines, executable)
- `tools/verify/m035-p02-bin-entry.sh` (~50 lines, executable)
- `/tmp/m035-p02-t01-changelog-read.sh` and
  `/tmp/m035-p02-t01-json-validate.sh` (staged probes — these may
  be cleaned up post-verification)

All four `bash tools/verify/m035-p02-*` invocations emit
`BATTERY: pass=N fail=0`.

## Notes

Expected verifier output: `PASS: ...` lines plus a single
`BATTERY: pass=<N> fail=0` line for each verifier. T01's
`m035-p02-package-json-shape.sh` checks 7 patterns (pass=7);
`m035-p02-bin-entry.sh` checks 3 conditions (pass=3).

Idempotency: re-running step 2 (re-author `package.json`) is
safe because step 8's JSON validity check rejects malformed
output. Re-running step 3 overwrites `bin/orchestrator` with the
same byte-for-byte content. The verifiers are stateless.

Reversibility: removing `package.json` and `bin/orchestrator`
unwinds the task. The npm publishing pipeline doesn't run until
T04; T01 is a pure authoring task with no external side effects.
