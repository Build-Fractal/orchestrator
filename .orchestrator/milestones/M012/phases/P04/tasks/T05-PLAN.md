---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P04"
milestone: "M012"
name: "Phase verification suite — eleven gates + phase-suite orchestrator"
depends_on: ["T04"]
---

## Prerequisites

- T01 complete: `wiki/docs/index.md` finalized.
- T02 complete: `wiki/README.md` first-deploy checklist + deploy-wrapper section.
- T03 complete: `scripts/wiki/wiki-deploy.sh` exists.
- T04 complete: `.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md` exists (live or fixture-shaped).
- No `scripts/verify/m012-p04-*.sh` files exist yet.

## Description

Ship the full P04 verification suite — one gate script per phase-plan Truth `Check:`, plus a phase-suite orchestrator. Each gate is single-invocation (AD-19 compliant) so auto-mode never prompts. Most gates are read-only static checks; the three `deploy-wrapper-*` gates invoke the wrapper under fixture environments and inspect its stdout.

Eleven gates:

1. `m012-p04-index-finalized.sh` — `wiki/docs/index.md` carries the four required headings, the five required stub-route links, does not contain `placeholder`, and stays ≤ 120 lines.
2. `m012-p04-index-ssot.sh` — scans upstream `.orchestrator/**.md` bodies; trips if any ≥ 40-char contiguous non-blank paragraph from an upstream file appears verbatim on `wiki/docs/index.md`. MEM004 carve-out applies to internals (this gate uses `find`, `grep -F`, internal pipes).
3. `m012-p04-readme-first-deploy.sh` — `wiki/README.md` contains `## First-deploy checklist`, `## Running the deploy wrapper`, every `GISCUS_*` env-var name, `gh-pages`, `mkdocs gh-deploy`, `Discussions`, `discussions category`, and `wiki-deploy.sh`.
4. `m012-p04-deploy-wrapper-contract.sh` — `scripts/wiki/wiki-deploy.sh` exists, is executable, references each of the four chained diagnostic basenames, contains `mkdocs gh-deploy`, has a `usage()` function, and sets `set -u`.
5. `m012-p04-deploy-wrapper-help.sh` — runs `bash scripts/wiki/wiki-deploy.sh --help`, asserts exit 0, asserts stdout contains each of `--dry-run`, `--help`, `--root`, `--skip-smoke`, `wiki-giscus-config-check.sh`, `wiki-link-check.sh`, `wiki-giscus-smoke.sh`, `mkdocs gh-deploy`.
6. `m012-p04-deploy-wrapper-dry-run.sh` — runs the wrapper with every `GISCUS_*` set to `"x"` and `--dry-run`, asserts exit 0, asserts stdout contains `GATE: giscus-config PASS` and `DRY-RUN: would deploy`. Tolerates `BUILD: skip` when mkdocs is absent.
7. `m012-p04-deploy-wrapper-loud-fail.sh` — runs the wrapper with `GISCUS_REPO_ID` unset (others set to `"x"`) and `--dry-run`, asserts exit 1, asserts stdout contains `GATE: giscus-config FAIL`.
8. `m012-p04-deploy-record.sh` — asserts `.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md` exists with the seven required frontmatter fields (`schema_version`, `type: deploy-record`, `milestone: "M012"`, `phase: "P04"`, `deployed_url`, `commit_sha`, `deployed_at`, `deployer`) plus four `gate_*_result` fields with allowed values (`pass`, `fail`, `skip`, `pending`), and that `deployed_url` is either `http*` or `pending`.
9. `m012-p04-bash32-compat.sh` — every `.sh` file under `scripts/wiki/wiki-deploy.sh` and `scripts/verify/m012-p04-*.sh` is free of `declare -A`, `mapfile`, `readarray`, `${var^^}`, `${var,,}`, `<(...)`, `>(...)`, `&>` in non-comment code. Self-inclusive with assignment-line carve-out.
10. `m012-p04-wiki-removable.sh` — outside of `wiki/`, `scripts/wiki/`, `scripts/diagnostics/wiki-*.sh`, `scripts/verify/m012-p0[1-4]-*.sh`, and `.orchestrator/milestones/M012/`, no repo file `source`s / imports / `bash`-invokes a P04-created script. Extends the P01/P03 self-contained pattern. Includes extending the existing `scripts/verify/m012-p01-wiki-self-contained.sh` allow-list to cover `m012-p04-*.sh` and `wiki-deploy.sh` (the allow-list edit is Done in T05's setup, then the gate asserts the state).
11. `m012-p04-summary-walkthrough.sh` — when `P04-SUMMARY.md` exists, asserts it names each of `US1`, `US2`, `US3`, `US4`, `US5` (or the literal "User Story 1".."User Story 5" forms) and lists each of `SC-1`..`SC-11` with a verdict token (`pass`, `fail`, or `skip`) on the same line. Emits `SKIP: P04-SUMMARY.md not yet written` and exits 0 when the file is absent (the summary is written at phase close, not during task execution). The accept-on-absent behavior is explicit and logged.

Plus the orchestrator:

12. `m012-p04-phase-suite.sh` — invokes all eleven gates, emits one `GATE: <name> PASS|FAIL` line per gate to stdout, a `SUMMARY: <passed>/<total>` line to stderr, and exits 0 only when every gate exits 0. Mirrors the P03 parallel-indexed-variable pattern.

## Steps

1. **Create `scripts/verify/m012-p04-index-finalized.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p04-index-finalized.sh — M012/P04 T01 gate.
   #
   # Asserts wiki/docs/index.md carries the finalized home page:
   # four section headings, five stub-route links, no "placeholder",
   # ≤ 120 lines.

   set -u
   SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
   DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
   ROOT="${1:-$DEFAULT_ROOT}"

   IDX="$ROOT/wiki/docs/index.md"
   if [ ! -f "$IDX" ]; then
     printf 'FAIL: %s not found\n' "$IDX" >&2; exit 1
   fi

   if grep -qiF 'placeholder' "$IDX"; then
     printf 'FAIL: %s still contains "placeholder"\n' "$IDX" >&2; exit 1
   fi

   lines=$(wc -l < "$IDX" | tr -d '[:space:]')
   if [ "$lines" -lt 40 ] || [ "$lines" -gt 120 ]; then
     printf 'FAIL: %s line count %d out of range [40,120]\n' "$IDX" "$lines" >&2; exit 1
   fi

   for heading in 'What this site is' 'How to navigate' 'Where to comment' 'Audience scope'; do
     if ! grep -qF "$heading" "$IDX"; then
       printf 'FAIL: %s missing heading "%s"\n' "$IDX" "$heading" >&2; exit 1
     fi
   done

   for link in 'constitution' 'decisions' 'knowledge' 'milestones'; do
     if ! grep -qF "$link" "$IDX"; then
       printf 'FAIL: %s missing link target "%s"\n' "$IDX" "$link" >&2; exit 1
     fi
   done

   printf 'PASS: index finalized (%d lines, 4 headings, 5 links)\n' "$lines"
   exit 0
   ```

2. **Create `scripts/verify/m012-p04-index-ssot.sh`** — the home-page SSOT guard. Internals may use `find`, pipes, `grep -F` per MEM004. Single-script-file shape at the Check layer:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p04-index-ssot.sh — M012/P04 T01 SSOT guard.
   #
   # Asserts wiki/docs/index.md contains zero paragraph-length blocks
   # (≥ 40 contiguous non-blank characters) that appear verbatim in any
   # .orchestrator/**.md artifact. Prevents home-page body-copy creep.
   #
   # MEM004 carve-out: internal pipes/find/grep permitted inside this
   # script. Single-script-file shape honored at the Check layer.

   set -u
   SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
   DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
   ROOT="${1:-$DEFAULT_ROOT}"

   IDX="$ROOT/wiki/docs/index.md"
   if [ ! -f "$IDX" ]; then
     printf 'FAIL: %s not found\n' "$IDX" >&2; exit 1
   fi

   # Extract candidate paragraph lines from the home page (≥40 chars,
   # non-heading, non-blank). These are the strings we forbid from
   # appearing verbatim in upstream canonical artifacts.
   SCRATCH="/tmp/m012-p04-index-ssot-$$.txt"
   # shellcheck disable=SC2064
   trap "rm -f '$SCRATCH'" EXIT INT TERM

   grep -v '^[[:space:]]*#' "$IDX" \
     | grep -v '^[[:space:]]*$' \
     | awk 'length >= 40' \
     > "$SCRATCH"

   # Scan .orchestrator/**.md for verbatim matches of any candidate.
   HITS=0
   while IFS= read -r line; do
     [ -z "$line" ] && continue
     # grep -rF — fixed-string recursive; excludes binary; treats quotes literally.
     if grep -rlF -- "$line" "$ROOT/.orchestrator" >/dev/null 2>&1; then
       printf 'SSOT FAIL: verbatim match in .orchestrator/: %s\n' "$line" >&2
       HITS=$((HITS + 1))
     fi
   done < "$SCRATCH"

   if [ "$HITS" -gt 0 ]; then
     printf 'FAIL: %d home-page paragraph(s) duplicate .orchestrator/ body text\n' "$HITS" >&2
     exit 1
   fi

   printf 'PASS: index SSOT clean (no body-copy from .orchestrator/)\n'
   exit 0
   ```

3. **Create `scripts/verify/m012-p04-readme-first-deploy.sh`** — asserts heading + env-var names + wrapper reference.

4. **Create `scripts/verify/m012-p04-deploy-wrapper-contract.sh`** — static assertions on `scripts/wiki/wiki-deploy.sh` structure: four gate basenames, `mkdocs gh-deploy`, `usage()`, `set -u`, executable bit, ≥ 120 lines.

5. **Create `scripts/verify/m012-p04-deploy-wrapper-help.sh`** — invokes `bash scripts/wiki/wiki-deploy.sh --help`, captures stdout to a tmp file, greps for each required token.

6. **Create `scripts/verify/m012-p04-deploy-wrapper-dry-run.sh`** — exports all four `GISCUS_*` to `"x"`, invokes `bash scripts/wiki/wiki-deploy.sh --dry-run`, captures stdout, asserts exit 0, asserts `GATE: giscus-config PASS`, asserts one of (`DRY-RUN: would deploy` | `SKIP: `) terminator patterns.

7. **Create `scripts/verify/m012-p04-deploy-wrapper-loud-fail.sh`** — same as above but with `unset GISCUS_REPO_ID`; asserts exit 1 and `GATE: giscus-config FAIL`.

8. **Create `scripts/verify/m012-p04-deploy-record.sh`** — parses DEPLOY-RECORD.md frontmatter via `grep -E`, asserts each required field + allowed-value set. Accepts `pending` sentinels per the dual-path contract.

9. **Create `scripts/verify/m012-p04-bash32-compat.sh`** — mirrors `m012-p03-bash32-compat.sh` with target globs `scripts/wiki/wiki-deploy.sh` + `scripts/verify/m012-p04-*.sh`. Self-inclusive; assignment-line carve-out.

10. **Extend `scripts/verify/m012-p01-wiki-self-contained.sh`** — add `scripts/verify/m012-p04-*.sh` and `scripts/wiki/wiki-deploy.sh` to the allow-list (mirrors the P02/P03 extension pattern).

11. **Create `scripts/verify/m012-p04-wiki-removable.sh`** — asserts no file outside the wiki blast radius references a P04 script. Conceptually identical to `m012-p03-wiki-removable.sh`; targets the P04 surface.

12. **Create `scripts/verify/m012-p04-summary-walkthrough.sh`** — accept-on-absent for `P04-SUMMARY.md`:

    ```bash
    #!/usr/bin/env bash
    # scripts/verify/m012-p04-summary-walkthrough.sh — M012/P04 phase-close gate.
    #
    # When P04-SUMMARY.md exists, asserts it walks US1..US5 and lists
    # SC-1..SC-11 each with a verdict token. When absent, SKIP-as-PASS
    # (the summary is written at phase close, not during task execution).

    set -u
    SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
    DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
    ROOT="${1:-$DEFAULT_ROOT}"

    SUMMARY="$ROOT/.orchestrator/milestones/M012/phases/P04/P04-SUMMARY.md"
    if [ ! -f "$SUMMARY" ]; then
      printf 'SKIP: %s not yet written (phase-close artifact)\n' "$SUMMARY"
      exit 0
    fi

    for us in US1 US2 US3 US4 US5; do
      if ! grep -qF "$us" "$SUMMARY"; then
        printf 'FAIL: %s missing %s\n' "$SUMMARY" "$us" >&2; exit 1
      fi
    done

    for i in 1 2 3 4 5 6 7 8 9 10 11; do
      if ! grep -qE "SC-${i}[^0-9]" "$SUMMARY"; then
        printf 'FAIL: %s missing SC-%d\n' "$SUMMARY" "$i" >&2; exit 1
      fi
    done

    printf 'PASS: summary walks US1..US5 and SC-1..SC-11\n'
    exit 0
    ```

13. **Create `scripts/verify/m012-p04-phase-suite.sh`** — orchestrator modeled on `scripts/verify/m012-p03-phase-suite.sh`:

    ```bash
    #!/usr/bin/env bash
    # scripts/verify/m012-p04-phase-suite.sh — orchestrates all eleven M012/P04 gates.
    #
    # Runs each gate script as a subprocess, aggregates results, emits one
    # `GATE: <name> PASS|FAIL` line per gate to stdout, and prints a
    # `SUMMARY: <passed>/<total> gates passed` line to stderr.
    # Exit 0 iff all eleven gates exit 0.
    # Bash 3.2 compatible. Parallel indexed variables (mirrors P02/P03 pattern).

    set -u
    SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
    DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
    ROOT="${1:-$DEFAULT_ROOT}"

    TMP_LOG="/tmp/m012-p04-phase-suite-$$.log"
    # shellcheck disable=SC2064
    trap "rm -f '$TMP_LOG'" EXIT INT TERM

    gates_0="m012-p04-index-finalized.sh"
    gates_1="m012-p04-index-ssot.sh"
    gates_2="m012-p04-readme-first-deploy.sh"
    gates_3="m012-p04-deploy-wrapper-contract.sh"
    gates_4="m012-p04-deploy-wrapper-help.sh"
    gates_5="m012-p04-deploy-wrapper-dry-run.sh"
    gates_6="m012-p04-deploy-wrapper-loud-fail.sh"
    gates_7="m012-p04-deploy-record.sh"
    gates_8="m012-p04-bash32-compat.sh"
    gates_9="m012-p04-wiki-removable.sh"
    gates_10="m012-p04-summary-walkthrough.sh"
    TOTAL=11

    PASSED=0
    i=0
    while [ "$i" -lt "$TOTAL" ]; do
      eval "g=\$gates_${i}"
      gate_path="$ROOT/scripts/verify/$g"
      if [ ! -f "$gate_path" ]; then
        printf 'GATE: %s FAIL (script missing)\n' "$g"
        i=$((i + 1))
        continue
      fi
      if bash "$gate_path" "$ROOT" > "$TMP_LOG" 2>&1; then
        printf 'GATE: %s PASS\n' "$g"
        PASSED=$((PASSED + 1))
      else
        printf 'GATE: %s FAIL\n' "$g"
        sed 's/^/  /' "$TMP_LOG" >&2
      fi
      i=$((i + 1))
    done

    printf 'SUMMARY: %d/%d gates passed\n' "$PASSED" "$TOTAL" >&2

    if [ "$PASSED" -eq "$TOTAL" ]; then
      exit 0
    fi
    exit 1
    ```

14. **Chmod all new gate scripts to `0755`** so the orchestrator can bash-invoke them without an explicit `bash` prefix (matches P01/P02/P03 convention).

15. **Re-run each gate manually** (not wired as a Check) to confirm they pass before writing the T05 summary.

## Must-Haves

- Every script named in the Artifacts list of `P04-PLAN.md` exists, is executable, and contains the listed pattern at the listed line-count floor.
- `scripts/verify/m012-p04-phase-suite.sh` orchestrates eleven gates and exits 0 when every gate exits 0.
- `scripts/verify/m012-p01-wiki-self-contained.sh` allow-list includes `m012-p04-*.sh` and `wiki-deploy.sh` (verified by running `bash scripts/verify/m012-p01-wiki-self-contained.sh` — should still exit 0 after P04 artifacts land).
- `bash scripts/verify/m012-p04-phase-suite.sh` exits 0 at T05 close. If `P04-SUMMARY.md` is not yet written, gate 11 emits `SKIP:` and still counts as PASS.
- Every P04 verify script is Bash 3.2 compatible.

## Verification

- Check: `bash scripts/verify/m012-p04-phase-suite.sh`
- Check: `bash scripts/verify/m012-p03-phase-suite.sh` (regression — adding P04 artifacts must not break P03)
- Check: `bash scripts/verify/m012-p02-phase-suite.sh` (regression)
- Check: `bash scripts/verify/m012-p01-phase-suite.sh` (regression — the self-contained gate is extended in T05)
- Check: `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P04`

## Inputs

### From Previous Tasks

- `wiki/docs/index.md` (from T01) — scanned by the index-finalized + index-ssot gates.
- `wiki/README.md` (from T02) — scanned by the readme-first-deploy gate.
- `scripts/wiki/wiki-deploy.sh` (from T03) — scanned by the deploy-wrapper-contract + deploy-wrapper-help + deploy-wrapper-dry-run + deploy-wrapper-loud-fail + bash32-compat gates.
- `.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md` (from T04) — scanned by the deploy-record gate.

### From Disk (Pre-existing)

- `scripts/verify/m012-p01-wiki-self-contained.sh` (P01) — allow-list extended in this task. The P02 + P03 extensions are already in place; T05 adds the P04 entries.
- `scripts/verify/m012-p03-phase-suite.sh` (P03) — structural template for the P04 phase-suite orchestrator.
- `scripts/verify/m012-p03-bash32-compat.sh` (P03) — structural template for the P04 Bash 3.2 compat gate.
- `scripts/verify/m012-p03-wiki-removable.sh` (P03) — structural template for the P04 wiki-removable gate.
- Upstream P02 + P03 diagnostics (`wiki-giscus-config-check.sh`, `wiki-link-check.sh`, `wiki-giscus-smoke.sh`) — invoked transitively by T03's wrapper; not directly invoked by T05 gates.

## Constraints

- **AD-19 single-script-file Check shape** — every Truth Check in the phase plan resolves to exactly one `bash scripts/verify/m012-p04-*.sh` invocation.
- **MEM004 carve-out** — internal gate logic may use pipes, subshells, `$()`, `find`, `awk`. The carve-out stops at the Check boundary: Truth Check lines remain single-script-file shape.
- **Constitution VIII (Bash 3.2)** — self-inclusive compat scan.
- **Constitution XIV** — no gate has a configuration file, no gate has a plugin hook, no gate has a `--json` output flag. Each gate does one thing, emits `PASS:` / `FAIL:` / `SKIP:`, and exits 0 / 1.
- **Constitution XV** — T05 creates exactly twelve new files (eleven gates + phase-suite orchestrator) and modifies exactly one existing file (`scripts/verify/m012-p01-wiki-self-contained.sh` allow-list).
- **Self-contained** — the T05 allow-list extension preserves the P01 containment property: removing the `wiki/` blast radius does not break the orchestrator core.
- **Idempotent** — rerunning the phase suite produces byte-identical stdout/stderr.
- **Fixture safety** — the deploy-wrapper gates run the wrapper in `--dry-run` mode with synthetic env vars; they never push to `gh-pages` and never make `gh` API calls.

## Expected Output

- Twelve new files under `scripts/verify/m012-p04-*.sh` + one modification to the P01 self-contained allow-list.
- `bash scripts/verify/m012-p04-phase-suite.sh` exits 0 and prints eleven `GATE: ... PASS` lines (gate 11 may be `SKIP:` until P04-SUMMARY.md lands; the orchestrator counts a gate-exit-0 as PASS regardless of its stdout terminator).
- `bash scripts/verify/m012-p0{1,2,3}-phase-suite.sh` — still green after T05 changes (regression budget).
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P04` — every Truth, Artifact, and Key Link entry passes.
