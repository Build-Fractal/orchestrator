---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M029"
name: "Invocation-context resolver + SC-1 fixture/script + verifier (AD-1 single-resolve)"
depends_on: ["T01"]
---

## Prerequisites

- T01 has completed: `references/status-headline-shape.md` and `references/status-json-schema.md` exist on disk. Verify with `[ -f references/status-headline-shape.md ]` AND `[ -f references/status-json-schema.md ]`.
- `scripts/state/` exists and holds sibling state scripts (`derive-phase.sh`, `find-active-milestone.sh`, `read-roadmap.sh`, `resolve-root.sh`, `read-config.sh`); verify `[ -d scripts/state ]`.
- No file currently lives at `scripts/state/detect-invocation-context.sh`; verify `[ ! -f scripts/state/detect-invocation-context.sh ]`. Path-collision check passed at plan-authoring time.
- `tests/m029-acceptance/` does not yet exist; this task creates it (mkdir -p).

## Description

T02 ships `scripts/state/detect-invocation-context.sh` — the **AD-1 single-resolve invocation-context resolver**. Every M029 surface (status headline, `--format=json`, where, context, live-tail, preflight) reads this script's emitted env block at command entry; no surface re-derives. Per Principle XI (Single Source of Truth) + AD-1, this is the load-bearing piece that downstream tasks consume.

T02 also ships:
- The SC-1 acceptance script `tests/m029-acceptance/p01-sc1-resolver.sh` that exercises the resolver across the four input combinations documented in the spec (US-1 Acceptance Scenarios).
- The shape verifier `tools/verify/m029-p01-invocation-context-resolver-shape.sh` and the SC-1 wrapper verifier `tools/verify/m029-p01-sc1-shape.sh`.

The resolver's output shape is locked by the M029-CONTEXT.md AD-1 entry: env block on stdout, `key=value` lines, exactly three fields:
- `renderer ∈ {tui, json, plain}`
- `exit_code_scheme ∈ {interactive, governance}`
- `default_provider` (passthrough from existing config; resolved via `scripts/state/read-config.sh`)

Resolution rules (also locked at AD-1):
- TTY=true + no CI vars + no `--format=json` → `renderer=tui exit_code_scheme=interactive`
- TTY=false (any reason: pipe / CI / non-interactive shell) + no `--format=json` → `renderer=plain exit_code_scheme=governance`
- `--format=json` flag present (regardless of TTY) → `renderer=json exit_code_scheme=governance`

The resolver accepts test-injection flags `--tty=<true|false>` and `--ci=<true|false>` so SC-1 can exercise behavior without manipulating real TTY state. Production callers omit these flags and rely on real `[ -t 1 ]` + env-var probing (`GITHUB_ACTIONS`, `CLAUDECODE`, `CI`).

## Steps

1. **Author `scripts/state/detect-invocation-context.sh`** (≥80 lines, executable, bash 3.2 compatible). Required structure (executor implements the full bash script; this plan documents the contract):

   - Shebang `#!/usr/bin/env bash` + `set -u`.
   - Header comment naming AD-1, FR-1, Principle XI, the three output fields, and the resolution rules.
   - Re-source guard following the project convention (`_DETECT_INVOCATION_CONTEXT_SH_SOURCED` scalar; the script is sourceable as a library AND runnable as a CLI).
   - Argument parser for: `--tty=<true|false>` (test injection), `--ci=<true|false>` (test injection), `--format=<tui|json|plain>` (emulates the format flag downstream commands forward), `--help|-h`.
   - Resolution function `_resolve_renderer()` that computes the `renderer` field per the rules above. Order of precedence: explicit `--format=<value>` flag wins; then test-injection `--tty` / `--ci` flags; then real `[ -t 1 ]` and env-var probing (`${GITHUB_ACTIONS:-}`, `${CI:-}`, `${CLAUDECODE:-}`).
   - Resolution function `_resolve_exit_code_scheme()` that maps `renderer=tui` → `exit_code_scheme=interactive`, anything else → `exit_code_scheme=governance`.
   - Resolution function `_resolve_default_provider()` that reads `bash scripts/state/read-config.sh <root> default_provider` (falls back to `claude-code` if the read returns empty — that's the default for M031's `auto_proceed: true` default flip; consult `templates/orchestrator-config-default.yml` for the canonical default).
   - Output emitter: prints exactly three lines to stdout in fixed order:
     ```
     renderer=<value>
     exit_code_scheme=<value>
     default_provider=<value>
     ```
   - Unknown-flag handler: prints `unknown flag: <flag>` to stderr, exits 2.
   - `--help` handler: prints a short usage block, exits 0.
   - Exit 0 on successful resolution.
   - Read-only — no writes anywhere.

2. **Create `tests/m029-acceptance/` directory** (`mkdir -p tests/m029-acceptance`).

3. **Author `tests/m029-acceptance/p01-sc1-resolver.sh`** (≥50 lines, executable). The script:

   - Sets `set -u` and traps cleanup for any temp directories.
   - Runs `bash scripts/state/detect-invocation-context.sh --tty=true --ci=false` and asserts stdout contains the literal lines `renderer=tui` AND `exit_code_scheme=interactive`. (SC-1 case 1.)
   - Runs `bash scripts/state/detect-invocation-context.sh --tty=false --ci=true` and asserts stdout contains the literal line `renderer=plain`. (SC-1 case 2.)
   - Runs `bash scripts/state/detect-invocation-context.sh --tty=false --ci=false --format=json` and asserts stdout contains the literal lines `renderer=json` AND `exit_code_scheme=governance`. (SC-1 case 3 — JSON-format invocation forces `renderer=json` regardless of TTY per AD-1's rules.)
   - Runs `bash scripts/state/detect-invocation-context.sh --tty=true --ci=true` and asserts stdout contains `renderer=plain` (CI=true forces plain even on TTY, per AD-1 rules).
   - Runs `bash scripts/state/detect-invocation-context.sh --bogus-flag` and asserts non-zero exit AND stderr contains `unknown flag`.
   - Tracks `pass` / `fail` counters; emits per-case `PASS:` / `FAIL:` lines + final `SC-1: pass=N fail=M`. Exits 0 iff `fail=0`.

4. **Author `tools/verify/m029-p01-invocation-context-resolver-shape.sh`** (≥35 lines, executable). The verifier:

   - Gates on file existence: `[ -f scripts/state/detect-invocation-context.sh ]`. FAIL if missing.
   - Asserts the script is executable (`[ -x scripts/state/detect-invocation-context.sh ]`).
   - Asserts the script header comment names AD-1 (greps for the literal `AD-1`).
   - Asserts the three required output field names appear in the script body via `grep -F`: `renderer=`, `exit_code_scheme=`, `default_provider=`.
   - Asserts both renderer values appear (`renderer=tui`, `renderer=plain`, `renderer=json`).
   - Asserts both exit_code_scheme values appear (`exit_code_scheme=interactive`, `exit_code_scheme=governance`).
   - Asserts the test-injection flags appear (`--tty=`, `--ci=`).
   - Runs the script with `--tty=true --ci=false` and asserts stdout exactly matches three lines in fixed order (regex per the contract).
   - Runs the script with `--tty=false --ci=true` and asserts stdout matches the plain-renderer pattern.
   - Emits `PASS:` per assertion + final `SUMMARY: m029-p01-invocation-context-resolver-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

5. **Author `tools/verify/m029-p01-sc1-shape.sh`** (≥25 lines, executable). The verifier:

   - Gates on file existence: `[ -f tests/m029-acceptance/p01-sc1-resolver.sh ]`. FAIL if missing.
   - Asserts the SC-1 script is executable.
   - Asserts the SC-1 script's header references SC-1 AND FR-1.
   - Asserts the SC-1 script invokes `scripts/state/detect-invocation-context.sh` (greps for the path).
   - Runs `bash tests/m029-acceptance/p01-sc1-resolver.sh` and asserts exit 0.
   - Emits `PASS:` per assertion + `SUMMARY: m029-p01-sc1-shape.sh pass=N fail=M`. Exit 0 iff `fail=0`.

6. **Run all three verifiers + the SC-1 script** to confirm green: `bash tools/verify/m029-p01-invocation-context-resolver-shape.sh`, `bash tests/m029-acceptance/p01-sc1-resolver.sh`, `bash tools/verify/m029-p01-sc1-shape.sh`.

## Must-Haves

This task addresses these P01 phase truths:
- `scripts/state/detect-invocation-context.sh` exists, is executable, and emits the AD-1 three-field env block.
- The SC-1 acceptance script exists and exits 0.

This task creates these P01 phase artifacts:
- `scripts/state/detect-invocation-context.sh` — the AD-1 single-resolve resolver.
- `tests/m029-acceptance/p01-sc1-resolver.sh` — SC-1 acceptance script.
- `tools/verify/m029-p01-invocation-context-resolver-shape.sh` — resolver shape verifier.
- `tools/verify/m029-p01-sc1-shape.sh` — SC-1 wrapper verifier.

## Verification

```bash
bash tools/verify/m029-p01-invocation-context-resolver-shape.sh
```

```bash
bash tools/verify/m029-p01-sc1-shape.sh
```

## Inputs

### From Previous Tasks

- `references/status-headline-shape.md` (from T01) — names the resolver as the entry point that downstream surfaces consume; T02's resolver header comment cross-references this contract so the link is round-trip auditable.
- `references/status-json-schema.md` (from T01) — names the resolver as the entry point under `renderer=json`; T02's resolver header comment cross-references this contract.

### From Disk (Pre-existing)

- `scripts/state/read-config.sh` — used by `_resolve_default_provider()` to read the `default_provider` config knob. Existing surface; bash-callable via `bash scripts/state/read-config.sh <root> <key>`.
- `templates/orchestrator-config-default.yml` — defines the canonical default for `default_provider` (the resolver falls back to this if config is absent).
- Sibling scripts under `scripts/state/` (`derive-phase.sh`, `find-active-milestone.sh`, `resolve-root.sh`) — pattern reference for the script header, source-guard convention, and `bash 3.2`-compatible style. Mirror their shape.

## Constraints

- AD-1 single-resolve: this script is the SINGLE site that resolves invocation context. T03/T04/T05 (and P02/P03 surfaces) MUST consume this script's emitted env block — they MUST NOT re-implement TTY / CI / runtime detection. The resolver's contract (three fields, fixed order, key=value lines) is the SSOT.
- Bash 3.2 compatibility: no associative arrays, no `${var,,}` case-folding, no process substitution, no `<<<` herestrings. Mirror `scripts/diagnostics/efficiency-footer.sh` (CON-7 declares this for that helper).
- AD-19 single-script-file shape: the resolver itself uses pipes / command substitution internally per the MEM004 emitter-internal carve-out, but the verifiers' Truth `Check:` invocations are single-file `bash <path>` shapes.
- Read-only (CON-1 / FR-14): the resolver never writes to disk. No log emission, no state mutation, no config writes.
- The `--format=json` flag on the resolver emulates the downstream-command flag; production status/where/context callers will probe `--format=json` themselves and forward it to the resolver. The resolver does NOT auto-detect `--format=json` from `$@` of the parent process — that's the parent's responsibility.
- Per the M029 knowledge-layer boundary (CON-7, AD-8): T02 introduces NO new schema additions. The resolver is a read-only consumer of existing config + env vars.

## Expected Output

After T02 completes:
- `scripts/state/detect-invocation-context.sh` exists, is executable, and resolves all four AD-1 cases correctly.
- `tests/m029-acceptance/p01-sc1-resolver.sh` exists, is executable, and exits 0 with `SC-1: pass=N fail=0`.
- `tools/verify/m029-p01-invocation-context-resolver-shape.sh` and `tools/verify/m029-p01-sc1-shape.sh` exist, are executable, and exit 0.
- A summary file at `.orchestrator/milestones/M029/phases/P01/tasks/T02-invocation-context-resolver-SUMMARY.md` documents the deliverables.

## Notes

Expected verifier output for the resolver shape verifier: `PASS:` lines for each of ~10 assertions, ending with `SUMMARY: m029-p01-invocation-context-resolver-shape.sh pass=10 fail=0`. Expected SC-1 acceptance output: per-case `PASS:` lines for the five test cases, ending with `SC-1: pass=5 fail=0`.

The resolver is the load-bearing AD-1 single-resolve site. Every M029 task downstream of T02 consumes the resolver's emitted env block. T03 reads `renderer` to decide whether to ANSI-strip the embedded efficiency footer line; T04 reads `renderer=json` to know the JSON renderer is the active surface; T05 reads `default_provider` for the runtime-profile screen. Any drift in the three-field output shape breaks every downstream surface.
