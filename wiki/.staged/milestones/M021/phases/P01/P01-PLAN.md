---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M021"
goal: "Ship three canonical Bash-3.2 wrapper scripts under scripts/util/ (with-env.sh, read-range.sh, run-probe.sh) that replace the recurring probe/range-read/env-inline shapes observed in M011/P05–P07 auto-mode screenshots, each with a dedicated gate script and a catalog README."
demo_sentence: "A developer invokes bash scripts/util/with-env.sh ORCH_REPO=/path -- bash /tmp/x.sh, bash scripts/util/read-range.sh file.md 10 20, and bash scripts/util/run-probe.sh /tmp/probe.sh; each wrapper executes successfully, and bash scripts/verify/run-suite.sh m021 P01 reports PASS for all four gate scripts."
risk: "low"
depends_on: []
---

## Must-Haves

### Truths

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     All Check: commands below use single-invocation script-file shape.
     No inline compound bash, no plain subshells, no $() with pipes. -->

- `scripts/util/with-env.sh` accepts `KEY=VALUE` pairs before a `--` separator, execs the trailing command with those variables exported, and exits with the child's return code.
  - Check: `bash scripts/verify/m021-p01-with-env.sh`
- `scripts/util/with-env.sh` exits non-zero with a usage message when the `--` separator is missing or no command follows.
  - Check: `bash scripts/verify/m021-p01-with-env.sh`
- `scripts/util/read-range.sh` emits lines M through N of a target file on stdout (inclusive, 1-indexed), exits 0 on a valid range, exits 2 when M>N or either bound falls outside the file, and exits 1 when the file does not exist.
  - Check: `bash scripts/verify/m021-p01-read-range.sh`
- `scripts/util/run-probe.sh` accepts a single path argument to a staged bash file, invokes it via `bash <path>`, and forwards the child's exit code. It refuses (non-zero + diagnostic) any path that is not under `/tmp/`, `/var/folders/`, or the project `tmp/` fixture root.
  - Check: `bash scripts/verify/m021-p01-run-probe.sh`
- All three wrappers parse-clean under Bash 3.2 (no `declare -A`, no `mapfile`, no `${var,,}`, no process substitution).
  - Check: `bash scripts/verify/m021-p01-bash32-compat.sh`
- `scripts/util/README.md` lists each wrapper with a one-line purpose, a one-line usage example, and links to the [M011](../../../../milestones/M011/index.md) screenshot class it replaces.
  - Check: `bash scripts/verify/m021-p01-readme-catalog.sh`

### Artifacts

- `scripts/util/with-env.sh` (min 25 lines, contains "KEY=VALUE")
- `scripts/util/read-range.sh` (min 25 lines, contains "M N")
- `scripts/util/run-probe.sh` (min 25 lines, contains "staged")
- `scripts/util/README.md` (min 30 lines, contains "with-env.sh")
- `scripts/verify/m021-p01-with-env.sh` (min 15 lines, contains "PASS")
- `scripts/verify/m021-p01-read-range.sh` (min 15 lines, contains "PASS")
- `scripts/verify/m021-p01-run-probe.sh` (min 15 lines, contains "PASS")
- `scripts/verify/m021-p01-bash32-compat.sh` (min 10 lines, contains "PASS")
- `scripts/verify/m021-p01-readme-catalog.sh` (min 10 lines, contains "PASS")

### Key Links

- `scripts/util/README.md` → `scripts/util/with-env.sh` (catalog entry names the script)
- `scripts/util/README.md` → `scripts/util/read-range.sh` (catalog entry names the script)
- `scripts/util/README.md` → `scripts/util/run-probe.sh` (catalog entry names the script)

## Tasks

### T01: Create scripts/util/with-env.sh + gate

See `tasks/T01-PLAN.md`.

### T02: Create scripts/util/read-range.sh + gate

See `tasks/T02-PLAN.md`.

### T03: Create scripts/util/run-probe.sh + gate

See `tasks/T03-PLAN.md`.

### T04: Create scripts/util/README.md catalog + Bash-3.2 compat gate

See `tasks/T04-PLAN.md`.

## Task Dependencies

```
T01 → T04
T02 → T04
T03 → T04
```

T01, T02, T03 are mutually independent (each wrapper is self-contained). T04 aggregates them: it writes the catalog README (which names all three wrappers) and the cross-wrapper Bash-3.2 compat gate (which parses all three). Dispatch may execute T01/T02/T03 in any order; T04 must run last.

## Files Likely Touched

- `scripts/util/with-env.sh` (create)
- `scripts/util/read-range.sh` (create)
- `scripts/util/run-probe.sh` (create)
- `scripts/util/README.md` (create)
- `scripts/verify/m021-p01-with-env.sh` (create)
- `scripts/verify/m021-p01-read-range.sh` (create)
- `scripts/verify/m021-p01-run-probe.sh` (create)
- `scripts/verify/m021-p01-bash32-compat.sh` (create)
- `scripts/verify/m021-p01-readme-catalog.sh` (create)
