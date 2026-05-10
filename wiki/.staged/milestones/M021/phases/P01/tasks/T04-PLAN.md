---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M021"
name: "Create scripts/util/README.md catalog + cross-wrapper Bash-3.2 compat gate"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

T01, T02, T03 must be complete. The following files must exist on disk:

- `scripts/util/with-env.sh` (from T01) — parses `KEY=VALUE ... --` then execs the trailing command. Exits 2 on usage error, otherwise forwards child RC.
- `scripts/util/read-range.sh` (from T02) — emits lines M..N (inclusive, 1-indexed) on stdout. Exits 0 on success, 1 on missing file, 2 on invalid range.
- `scripts/util/run-probe.sh` (from T03) — invokes a staged bash file from an approved root (`/tmp/`, `/var/folders/`, `<repo>/tmp/`). Exits 3 on out-of-root paths, 1 on missing file, 2 on usage error; forwards child RC on success.

Each upstream task has already created its own per-wrapper gate (`scripts/verify/m021-p01-with-env.sh`, `-read-range.sh`, `-run-probe.sh`). Those remain in place and are not modified by T04.

## Description

Two deliverables:

1. `scripts/util/README.md` — a catalog index for the `scripts/util/` directory. Lists each of the three new wrappers with a one-line purpose, a one-line invocation example, and a one-line citation to the M011/P05–P07 screenshot class the wrapper replaces. Establishes this file as the authoritative catalog for Class B probe wrappers (future wrappers append here).
2. `scripts/verify/m021-p01-bash32-compat.sh` — a cross-wrapper Bash-3.2 compatibility gate that runs `bash -n` against all three new wrappers and fails if any fails to parse. Plus a sibling gate `scripts/verify/m021-p01-readme-catalog.sh` that asserts the README names all three wrappers and contains the required sections.

## Steps

### Step 1: Create scripts/util/README.md

Write the catalog at `scripts/util/README.md`:

```markdown
# scripts/util/ — Probe & Invocation Wrapper Catalog

This directory holds small, single-purpose Bash wrappers that replace
recurring probe / range-read / env-inline shapes that trigger Claude
Code's safety heuristics in autonomous mode. Each wrapper is
allow-listed via `bash scripts/util/*` so auto-mode runs stay
prompt-free. See `.orchestrator/milestones/M021/M021-CONTEXT.md` (AD-3)
for the evidence grounding.

## Wrapper Catalog

### with-env.sh — run a command with inline env assignments

- **Purpose**: replace the `VAR=val cmd ...` prefix shape, which
  Claude Code flags as simple-expansion / compound-prefix.
- **Usage**: `bash scripts/util/with-env.sh KEY=VALUE [KEY=VALUE ...] -- command [args ...]`
- **Example**: `bash scripts/util/with-env.sh ORCH_REPO=/tmp/repo -- bash scripts/foo.sh`
- **Replaces**: `ORCH_REPO=/tmp/repo bash scripts/foo.sh` (M011/P05 screenshots).
- **Exit codes**: 2 = usage error; otherwise forwards child RC.

### read-range.sh — emit an inclusive line range on stdout

- **Purpose**: replace the `sed -n 'M,Np' file` shape, which Claude
  Code misclassifies as a write (the `p` inside single quotes) and
  flags as quoted-brace obfuscation.
- **Usage**: `bash scripts/util/read-range.sh <file> <M> <N>`
- **Example**: `bash scripts/util/read-range.sh file.md 686 1050`
- **Replaces**: `sed -n '686,1050p' file.md` (M011/P06 screenshots).
- **Exit codes**: 0 on success, 1 on missing/unreadable file, 2 on
  invalid range (non-integer, M<1, N<M, or N exceeds file length).

### run-probe.sh — invoke a staged bash file from an approved root

- **Purpose**: replace the `cat > /tmp/x.sh <<EOF ... EOF ; bash
  /tmp/x.sh` heredoc-then-execute shape and the bare `bash /tmp/x.sh`
  invocation, which Claude Code flags as heredoc-expansion and
  bare-tmp-invocation respectively.
- **Usage**: `bash scripts/util/run-probe.sh <path-to-staged-probe.sh>`
- **Example**: `bash scripts/util/run-probe.sh /tmp/m021-probe.sh`
- **Replaces**: bare `bash /tmp/m011-p07-dogfood.sh` and
  heredoc+execute chains (M011/P07 screenshots).
- **Approved roots**: `/tmp/`, `/var/folders/`, `<repo>/tmp/`. Paths
  outside these roots are rejected with exit 3.
- **Exit codes**: 1 = missing/unreadable file; 2 = usage error; 3 =
  out-of-root path; otherwise forwards child RC.

## Composition

The wrappers compose: to run `/tmp/probe.sh` with two env vars set,
use

    bash scripts/util/with-env.sh FOO=1 BAR=2 -- bash scripts/util/run-probe.sh /tmp/probe.sh

## Adding a New Wrapper

New wrappers are added only when a fresh `orchestrator:auto` run
surfaces a recurring shape that none of the existing three cover.
Process: (a) file a new `ANTIPATTERNS.md` entry citing the screenshot
evidence; (b) add the wrapper + its `scripts/verify/m0NN-pNN-<name>.sh`
gate; (c) append a new section above. No speculative additions
(constitution XIV).

## Gates

- `scripts/verify/m021-p01-with-env.sh` — exercises with-env.sh.
- `scripts/verify/m021-p01-read-range.sh` — exercises read-range.sh.
- `scripts/verify/m021-p01-run-probe.sh` — exercises run-probe.sh.
- `scripts/verify/m021-p01-bash32-compat.sh` — parses all three
  wrappers under Bash 3.2.
- `scripts/verify/m021-p01-readme-catalog.sh` — asserts this README
  names each wrapper and documents usage.

Run the full suite via:

    bash scripts/verify/run-suite.sh m021 P01
```

### Step 2: Create scripts/verify/m021-p01-bash32-compat.sh

Write the cross-wrapper compat gate at `scripts/verify/m021-p01-bash32-compat.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m021-p01-bash32-compat.sh — Parse-check all P01 wrappers.
# Uses `bash -n` as a syntactic parse check and greps for known
# Bash-4-only constructs. Exits 0 when all three wrappers are clean.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

wrappers="with-env.sh read-range.sh run-probe.sh"
fail_count=0

for w in $wrappers; do
  path="${REPO_ROOT}/scripts/util/${w}"
  if [ ! -f "$path" ]; then
    echo "FAIL: missing $path"
    fail_count=$((fail_count + 1))
    continue
  fi
  if ! bash -n "$path" 2>/dev/null; then
    echo "FAIL: $w — bash -n parse error"
    fail_count=$((fail_count + 1))
    continue
  fi
  # Scan for Bash-4-only constructs. Keep this list conservative.
  if grep -qE 'declare[[:space:]]+-A|mapfile|readarray|\$\{[A-Za-z_][A-Za-z_0-9]*,,\}|\$\{[A-Za-z_][A-Za-z_0-9]*\^\^\}' "$path"; then
    echo "FAIL: $w — contains Bash-4-only construct"
    fail_count=$((fail_count + 1))
    continue
  fi
  echo "PASS: $w bash-3.2 clean"
done

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p01-bash32-compat.sh"
  exit 0
fi
echo "FAIL: m021-p01-bash32-compat.sh ($fail_count failures)"
exit 1
```

### Step 3: Create scripts/verify/m021-p01-readme-catalog.sh

Write the catalog-assertion gate at `scripts/verify/m021-p01-readme-catalog.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/m021-p01-readme-catalog.sh — Asserts scripts/util/README.md
# names each of the three P01 wrappers and documents usage for each.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
README="${REPO_ROOT}/scripts/util/README.md"

fail_count=0

if [ ! -f "$README" ]; then
  echo "FAIL: scripts/util/README.md not found"
  exit 1
fi

for w in with-env.sh read-range.sh run-probe.sh; do
  if grep -q "$w" "$README"; then
    echo "PASS: README names $w"
  else
    echo "FAIL: README missing $w"
    fail_count=$((fail_count + 1))
  fi
done

# Each wrapper section must include a Usage line.
for w in with-env.sh read-range.sh run-probe.sh; do
  if grep -qE "Usage.*${w}|${w}.*Usage" "$README"; then
    echo "PASS: README documents Usage for $w"
  else
    echo "FAIL: README missing Usage for $w"
    fail_count=$((fail_count + 1))
  fi
done

# Catalog header present.
if grep -qE '^## Wrapper Catalog' "$README"; then
  echo "PASS: README has Wrapper Catalog heading"
else
  echo "FAIL: README missing Wrapper Catalog heading"
  fail_count=$((fail_count + 1))
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p01-readme-catalog.sh"
  exit 0
fi
echo "FAIL: m021-p01-readme-catalog.sh ($fail_count failures)"
exit 1
```

## Must-Haves

- `scripts/util/README.md` exists and names each of the three wrappers with a Usage line.
- `scripts/util/README.md` has a `## Wrapper Catalog` heading.
- `scripts/verify/m021-p01-bash32-compat.sh` parses all three wrappers cleanly and scans for Bash-4-only constructs.
- `scripts/verify/m021-p01-readme-catalog.sh` asserts the README invariants above.
- All new files are Bash 3.2 compatible where applicable (README is markdown; gates are Bash 3.2).

## Verification

- `bash scripts/verify/m021-p01-bash32-compat.sh` exits 0 with final line `PASS: m021-p01-bash32-compat.sh`.
- `bash scripts/verify/m021-p01-readme-catalog.sh` exits 0 with final line `PASS: m021-p01-readme-catalog.sh`.
- `bash scripts/verify/run-suite.sh m021 P01` discovers and passes all five gates.

## Inputs

### From Previous Tasks

- `scripts/util/with-env.sh` (from T01)
  - Key API: `bash with-env.sh KEY=VALUE ... -- cmd args`
  - Key types: exit codes 2 (usage) / child RC otherwise.
- `scripts/util/read-range.sh` (from T02)
  - Key API: `bash read-range.sh <file> <M> <N>`
  - Key types: exit codes 0 / 1 (file) / 2 (range).
- `scripts/util/run-probe.sh` (from T03)
  - Key API: `bash run-probe.sh <path>`
  - Key types: exit codes 1 / 2 / 3 / child RC. Approved roots: `/tmp/`, `/var/folders/`, `<repo>/tmp/`.

### From Disk (Pre-existing)

- `scripts/verify/run-suite.sh` — the [M016](../../../../../milestones/M016/index.md) suite runner that will discover the new gates by filename pattern.

## Constraints

- Bash 3.2 compatible.
- README is the single authoritative catalog for `scripts/util/` Class B wrappers. Do not create per-wrapper README files.
- README's `## Wrapper Catalog` heading name is load-bearing: the `m021-p01-readme-catalog.sh` gate asserts it by regex.
- The compat gate scans for a small fixed set of Bash-4-only constructs (`declare -A`, `mapfile`, `readarray`, `${var,,}`, `${var^^}`) — explicitly not an exhaustive list. Rationale: catches the high-frequency regressions without maintaining a parallel AST. Additional constructs may be added as regressions are observed.
- No new wrapper code in T04. Wrappers belong to T01/T02/T03. T04 only adds catalog + cross-wrapper gates.
- Gate scripts use only single-script-file-shape commands (AD-19).

## Expected Output

- `scripts/util/README.md` created.
- `scripts/verify/m021-p01-bash32-compat.sh` created.
- `scripts/verify/m021-p01-readme-catalog.sh` created.
- `bash scripts/verify/run-suite.sh m021 P01` outputs `PASS: 5 / FAIL: 0`.
