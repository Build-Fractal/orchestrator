---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M012"
name: "wiki-giscus-config-check.sh — loud-fail pre-build gate for missing Giscus env vars"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `wiki/mkdocs.yml` contains `extra.giscus` with four `!ENV`-interpolated keys (`GISCUS_REPO`, `GISCUS_REPO_ID`, `GISCUS_CATEGORY`, `GISCUS_CATEGORY_ID`) defaulting to the empty string, plus `mapping: "pathname"`.
- `scripts/diagnostics/` directory exists in the repo (peer of `scripts/verify/`, `scripts/wiki/`).

## Description

Ship `scripts/diagnostics/wiki-giscus-config-check.sh` — a pre-build diagnostic that reads the four Giscus env vars from the caller's environment and exits non-zero with a clear human-readable diagnostic whenever any one is empty/unset. This is the "fail loudly" side of US2 AS-5 and SC-9: the deploy wrapper that lands in P04 will invoke this gate before `mkdocs gh-deploy`; running it standalone surfaces the issue before an incomplete build reaches production. The gate does **not** modify anything; it emits `PASS:` / `FAIL:` lines and exits 0/1.

Out-of-scope for this task: smoke-test of rendered HTML (T03), remap script (T04), verify gates / phase-suite (T05).

## Steps

1. **Create `scripts/diagnostics/wiki-giscus-config-check.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/diagnostics/wiki-giscus-config-check.sh — M012/P03 loud-fail gate.
   #
   # Purpose: verify the four Giscus environment variables are set and
   # non-empty before a wiki build runs. Fail loudly (non-zero exit + clear
   # diagnostic on stderr) when any is missing so the deploy wrapper in
   # M012/P04 can abort before mkdocs emits a silently-broken site.
   #
   # Contract:
   #   - Reads $GISCUS_REPO, $GISCUS_REPO_ID, $GISCUS_CATEGORY,
   #     $GISCUS_CATEGORY_ID from the environment.
   #   - Exits 0 and emits `PASS: all 4 GISCUS_* env vars set` on success.
   #   - Exits 1 and emits `FAIL: GISCUS_<NAME> unset or empty` for each
   #     missing var, then a final `FAIL: <N>/4 required vars missing`.
   #   - Supports `--help` and `--quiet` (silences PASS line; failures still print).
   #
   # Bash 3.2 compatible. No associative arrays, no mapfile, no process substitution.

   set -u
   set -o pipefail

   usage() {
     cat <<'USAGE'
   Usage: wiki-giscus-config-check.sh [--quiet] [--help]

   Verifies the four Giscus env vars are set before a wiki build:
     GISCUS_REPO          e.g. "myorg/myrepo"
     GISCUS_REPO_ID       e.g. "R_kgDO..."  (from https://giscus.app)
     GISCUS_CATEGORY      e.g. "Announcements"
     GISCUS_CATEGORY_ID   e.g. "DIC_kwDO..."

   Exits 0 iff all four are set and non-empty.
   USAGE
   }

   quiet=0
   while [ $# -gt 0 ]; do
     case "$1" in
       --help|-h) usage; exit 0 ;;
       --quiet|-q) quiet=1; shift ;;
       *) printf 'ERROR: unknown arg: %s\n' "$1" >&2; usage >&2; exit 2 ;;
     esac
   done

   required="GISCUS_REPO GISCUS_REPO_ID GISCUS_CATEGORY GISCUS_CATEGORY_ID"
   missing=0
   for name in $required; do
     # Bash 3.2 indirect expansion: eval is safest across 3.2 quirks.
     eval "value=\${$name:-}"
     if [ -z "${value}" ]; then
       printf 'FAIL: %s unset or empty\n' "$name" >&2
       missing=$((missing + 1))
     fi
   done

   if [ "$missing" -gt 0 ]; then
     printf 'FAIL: %d/4 required Giscus env vars missing — aborting before build\n' "$missing" >&2
     printf 'HINT: set them from https://giscus.app configurator before running mkdocs build or mkdocs gh-deploy\n' >&2
     exit 1
   fi

   if [ "$quiet" -eq 0 ]; then
     printf 'PASS: all 4 GISCUS_* env vars set\n'
   fi
   exit 0
   ```

2. **Make it executable**: `chmod 755 scripts/diagnostics/wiki-giscus-config-check.sh`.

3. **Smoke-verify manually** (not wired as a Check):

   - Unset all four env vars, run the script → exit 1, four `FAIL:` lines, final summary line.
   - Set all four (any non-empty values), run → exit 0, one `PASS:` line on stdout.
   - Set three, leave one unset → exit 1, one `FAIL: GISCUS_<NAME>` line, summary `1/4 required`.

## Must-Haves

- `scripts/diagnostics/wiki-giscus-config-check.sh` exists, is executable (`-rwxr-xr-x` or equivalent), is ≥ 40 lines, and contains the literal `GISCUS_REPO_ID`.
- When invoked with all four env vars set to non-empty strings, the script exits 0.
- When invoked with one or more env vars unset or empty, the script exits 1 with a `FAIL:` diagnostic identifying each missing var by name.
- `--help` exits 0 without reading env vars.
- Script is Bash 3.2 compatible: no `declare -A`, no `mapfile`, no `${var^^}`, no `<(...)`, no `&>`, no Bash 4-only syntax in non-comment code.

## Verification

- `bash scripts/verify/m012-p03-config-loud-fail.sh` — PASS (T05 gate; it runs the script under both fully-set and fully-unset env fixtures).
- `bash scripts/verify/m012-p03-bash32-compat.sh` — PASS (script passes the compat scanner).
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P03` — artifact pattern + line-count pass for `scripts/diagnostics/wiki-giscus-config-check.sh`.

Manual smoke run during this task (do NOT embed as a Check):

1. `env -i bash scripts/diagnostics/wiki-giscus-config-check.sh` — expect exit 1, four `FAIL:` lines.
2. `env GISCUS_REPO=a GISCUS_REPO_ID=b GISCUS_CATEGORY=c GISCUS_CATEGORY_ID=d bash scripts/diagnostics/wiki-giscus-config-check.sh` — expect exit 0, one `PASS:` line.

## Inputs

### From Previous Tasks

- **T01**: `wiki/mkdocs.yml` now expects four env vars at build time (`GISCUS_REPO`, `GISCUS_REPO_ID`, `GISCUS_CATEGORY`, `GISCUS_CATEGORY_ID`), all defaulting to `""` via `!ENV`. This script enforces their presence before the build, short-circuiting the silently-empty-string failure mode.

### From Disk (Pre-existing)

- `scripts/diagnostics/` directory (from earlier milestones). Peer of `scripts/verify/` and `scripts/wiki/`. Contains read-only / diagnostic scripts.

## Constraints

- **Bash 3.2** — MEM001. Indirect expansion via `eval "value=\${$name:-}"` is the portable form; Bash 4's `${!name}` is acceptable but `eval` is safer across exotic PATH bashes.
- **Single-script-file Check shape (AD-19)** — this script will be invoked as the Check for M012/P03's "loud fail" Truth via the T05-owned gate wrapper (`scripts/verify/m012-p03-config-loud-fail.sh`). The Check layer invokes the gate; the gate invokes this diagnostic; compound logic stays inside the diagnostic (MEM004 carve-out).
- **Read-only** — the diagnostic never writes repo state. No tmp files, no logs.
- **No external network calls** — env var presence check only. Does not call `gh`, does not hit giscus.app.
- **Exit codes** — `0` on pass, `1` on any missing var, `2` on usage error.
- **Stdout vs stderr** — `PASS:` on stdout; `FAIL:` / `HINT:` / `ERROR:` on stderr. Matches MEM001 structured output convention.

## Expected Output

- `scripts/diagnostics/wiki-giscus-config-check.sh` exists, executable, Bash 3.2 compliant, ≥ 40 lines.
- Running with all four env vars set: exit 0, `PASS: all 4 GISCUS_* env vars set` on stdout.
- Running with any missing: exit 1, one `FAIL: GISCUS_<NAME> unset or empty` per missing var on stderr, plus a summary line and the `HINT:` follow-up.
- `--help` exits 0 with usage text on stdout.
