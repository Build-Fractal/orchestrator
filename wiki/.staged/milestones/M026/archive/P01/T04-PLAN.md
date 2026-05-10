---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P01"
milestone: "M026"
name: "Phase-close gate suite + dual-write Recent Changes"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 complete: [`.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md`](../../../../milestones/M026/M026-CONVERSUS-PARITY.md) exists with full `Verified:` column; phase-local pointer [`.orchestrator/milestones/M026/phases/P01/P01-CONVERSUS-PARITY-MATRIX.md`](../../../../milestones/M026/phases/P01/P01-CONVERSUS-PARITY-MATRIX.md) exists.
- T02 complete: `SPIKE-SYNTHESIS-CRUX.md` + `P01-SPIKE-GATE.md` under `.orchestrator/milestones/M026/phases/P01/`. Spike verdict is captured regardless of GO vs NO-GO — the suite asserts shape, not value.
- T03 complete: `OLLAMA-PROBE.md` under same phase dir with both ollama + pipx inventory blocks.
- `scripts/util/dual-write-runtime-md.sh` present (M014/P01 shipped artifact; read-only dependency).
- Pattern references: M025/P01 gate suite at `scripts/verify/m025-p01-*.sh` (reuse gate-script skeleton + SUMMARY line convention).

## Description

Author all nine P01 verifier scripts, the phase-suite orchestrator, run the full suite green, and fire the dual-write Recent Changes fragment. This is the phase-close task: no new data artifacts land in T04, only gate scripts + dual-write + (at `orchestrator:verify` time later) the P01-SUMMARY.md.

Every gate script follows this skeleton (lift from `scripts/verify/m025-p01-phase-suite.sh`):

```bash
#!/usr/bin/env bash
# scripts/verify/m026-p01-<name>.sh — <one-line description>

set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }

# <gate body: one or more invariants asserted via grep/test/python3>

echo "SUMMARY: m026-p01-<name>.sh pass=$PASS fail=$FAIL"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
exit 0
```

All scripts are bash 3.2 compatible (no `declare -A`, no `mapfile`/`readarray`, no process substitution, no `&>`, no `${var^^}`/`${var,,}`) per CON-2.

## Steps

1. **Author `scripts/verify/m026-p01-parity-matrix-shape.sh`** (min 40 lines). Asserts:
   - [`.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md`](../../../../milestones/M026/M026-CONVERSUS-PARITY.md) exists.
   - File line count ≥ 80.
   - Frontmatter contains `type: parity-matrix`, `milestone: "M026"`, `phase: "P01"`, `status: final`.
   - Markdown body contains the four required column headers (`Surface`, `OSS`, `Paid`, `Verified`) on the same table-header line (grep `| Surface | OSS | Paid | Verified |` or equivalent with leading `|`).
   - Every data row (line matching `^\|` that isn't the header or separator) has a non-empty `Verified:` cell drawn from the fixed vocabulary `{verified-identical, verified-drifted, verified-absent, verified-moot}`. Use a python3 one-liner invoked via a separate `.py` helper OR a plain awk script — NOT a bash-inline compound. Preferred: a short helper script `scripts/verify/lib/m026-p01-parity-row-check.sh` that reads the matrix file and exits 0 if every data row's Verified cell is in the vocabulary, 1 otherwise.
   - File contains zero occurrences of the literal string `VERIFY` (the scratch-matrix placeholder) in any data row.

2. **Author `scripts/verify/m026-p01-parity-matrix-coverage.sh`** (min 40 lines). Asserts:
   - Matrix file has ≥ 16 data rows (12 scratch-matrix rows + 4 smoke-confirmed drift rows).
   - Each of the four smoke-confirmed drift rows has `confirmed 2026-04-23` in its Notes cell. Concretely: `grep -c 'confirmed 2026-04-23' <matrix>` returns a count ≥ 4.
   - Matrix contains a `## Summary` section with `verified-identical`, `verified-drifted`, `verified-absent`, `verified-moot` counts.
   - Matrix contains a `## OQ-2 Decision Input` section naming the narrow-vs-full-scope call.

3. **Author `scripts/verify/m026-p01-spike-note-shape.sh`** (min 30 lines). Asserts:
   - `SPIKE-SYNTHESIS-CRUX.md` exists at `.orchestrator/milestones/M026/phases/P01/`.
   - File line count ≥ 50.
   - Frontmatter contains `type: spike-report`, `phase: "P01"`, `task: "T02"`, `status: final`.
   - Body contains headings `## Method`, `## Findings`, `## Verdict`, `## Rationale`.
   - Body contains exactly one line matching the regex `^Verdict: (GO|NO-GO)$` (use `grep -c`; assert count == 1).

4. **Author `scripts/verify/m026-p01-spike-gate-file.sh`** (min 20 lines). Asserts:
   - `P01-SPIKE-GATE.md` exists at `.orchestrator/milestones/M026/phases/P01/`.
   - File contains a single line matching regex `^gate=(GO|NO-GO)$`.
   - File contains a `spike_report=` line pointing at `SPIKE-SYNTHESIS-CRUX.md`.
   - If `gate=NO-GO`, file additionally contains a `## Halt` section. This branch is checked but not required to fire: the gate passes whether value is GO or NO-GO.

5. **Author `scripts/verify/m026-p01-ollama-probe.sh`** (min 25 lines). Asserts:
   - `OLLAMA-PROBE.md` exists at `.orchestrator/milestones/M026/phases/P01/`.
   - Frontmatter contains `type: probe-report`.
   - Body contains a line matching `^result=(available|absent|skipped-operator-choice)$`.
   - Body contains `ollama_path=`, `ollama_version=`, `models_present=` lines (values allowed to be `N/A` when `result=absent`).
   - Body contains both `oss_venv_path=` and `paid_venv_path=` lines.
   - Body contains a `## P02 Fallback Posture` section.

6. **Author `scripts/verify/m026-p01-pipx-venv-inventory.sh`** (min 25 lines). Asserts:
   - `OLLAMA-PROBE.md` body contains the four boolean `_present=(true|false)` lines (`oss_venv_python_present`, `oss_venv_conversus_binary_present`, `paid_venv_python_present`, `paid_venv_conversus_binary_present`).
   - Matrix file (`M026-CONVERSUS-PARITY.md`) contains a data row whose Surface cell mentions `pipx venv` and whose Verified cell is one of the fixed vocabulary values.

7. **Author `scripts/verify/m026-p01-upstream-readonly.sh`** (min 30 lines). Asserts:
   - `git -C ~/Sites/conversus status --porcelain 2>/dev/null` produces no output (or the directory does not exist — both acceptable: the gate is "we did not modify it", not "it must exist").
   - `git -C ~/Sites/conversus-oss status --porcelain 2>/dev/null` produces no output.
   - No files in this repo under `.orchestrator/milestones/M026/phases/P01/` reference paths that indicate a write (e.g., grep for `mv ~/Sites/conversus` or `> ~/Sites/conversus` patterns — advisory check).
   - Invoke each git-status command via a short helper `scripts/verify/lib/m026-p01-git-readonly-probe.sh` to preserve AD-19 single-script-file shape (no `$(...)`-with-pipes in the gate body).

8. **Author `scripts/verify/m026-p01-bash32-compat.sh`** (min 40 lines). Reuse the M025/P01/T06 pattern — scans all `scripts/verify/m026-p01-*.sh` files for bash 3.2 violations. Self-excludes its own violation-pattern enumeration via case-branch + comment-discipline synonyms (the pattern text lives in case branches that the scanner's grep excludes).

9. **Author `scripts/verify/m026-p01-summary-shape-when-present.sh`** (min 25 lines). Asserts (only when `P01-SUMMARY.md` exists; passes trivially when absent):
   - If [`.orchestrator/milestones/M026/phases/P01/P01-SUMMARY.md`](../../../../milestones/M026/phases/P01/P01-SUMMARY.md) exists, it contains the exact line `Verdict: GO` OR `Verdict: NO-GO` (copied verbatim from the spike note).
   - If present, it contains a reference to `M026-CONVERSUS-PARITY.md` (string match).
   - This gate is advisory during T04 (P01-SUMMARY.md is authored by `orchestrator:verify` at phase close, not by T04 itself). The gate script returns pass when the file is absent.

10. **Author `scripts/verify/m026-p01-recent-changes.sh`** (min 20 lines). Asserts:
    - `CLAUDE.md` `# >>> orchestrator:recent-changes >>>` region contains a line mentioning `M026` and either `parity` or `spike` (the T04 Recent Changes fragment).
    - `AGENTS.md` same region contains the same line.
    - Use a helper `scripts/verify/lib/m026-p01-recent-changes-region.sh` to extract the marker-bounded region if inline bash would trigger AD-19 heuristic.

11. **Author the phase-suite orchestrator** `scripts/verify/m026-p01-phase-suite.sh` (min 40 lines). Invokes each of the nine gate scripts in this order:
    1. `m026-p01-parity-matrix-shape.sh`
    2. `m026-p01-parity-matrix-coverage.sh`
    3. `m026-p01-spike-note-shape.sh`
    4. `m026-p01-spike-gate-file.sh`
    5. `m026-p01-ollama-probe.sh`
    6. `m026-p01-pipx-venv-inventory.sh`
    7. `m026-p01-upstream-readonly.sh`
    8. `m026-p01-bash32-compat.sh`
    9. `m026-p01-recent-changes.sh`
    (`m026-p01-summary-shape-when-present.sh` is invoked by `orchestrator:verify` at phase-close, not by the T04 suite run — it's advisory.)

    Tally pass/fail from each sub-gate's exit code, print `SUMMARY: m026-p01-phase-suite.sh pass=<N> fail=<M>`, exit 0 iff `fail=0`.

12. **Run the phase suite to confirm green.** Invoke `bash scripts/verify/m026-p01-phase-suite.sh` and confirm exit 0 + `fail=0` in SUMMARY. Iterate on any gate that fails until all nine are green.

13. **Fire dual-write Recent Changes.** Invoke:
    ```
    bash scripts/util/dual-write-runtime-md.sh --marker recent-changes \
      --content "- M026/P01: conversus-OSS migration — parity matrix + DC-6 synthesis-crux spike verdict + ollama/pipx env probe" \
      --file CLAUDE.md --file AGENTS.md
    ```
    Confirm both files' `# >>> orchestrator:recent-changes >>>` regions now contain the fragment.

## Must-Haves

This task satisfies the phase truths:
- "every new .sh file passes bash 3.2 compatibility" (bash32-compat truth).
- "CLAUDE.md + AGENTS.md Recent Changes region updated via dual-write helper" (recent-changes truth).
- "phase-suite invokes all nine gates and exits 0 on green" (phase-suite truth).
- "P01-SUMMARY.md shape-when-present gate exists and is discoverable by `orchestrator:verify`" (summary-shape-when-present truth; file authored by `orchestrator:verify`).

## Verification

```
bash scripts/verify/m026-p01-phase-suite.sh
bash scripts/verify/m026-p01-bash32-compat.sh
bash scripts/verify/m026-p01-recent-changes.sh
```

All three must exit 0 with `fail=0`.

## Inputs

### From Previous Tasks
- [`.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md`](../../../../milestones/M026/M026-CONVERSUS-PARITY.md) (from T01)
  - Key fields: frontmatter `type: parity-matrix`; table columns `Surface|OSS|Paid|Verified`; Verified vocabulary `{verified-identical, verified-drifted, verified-absent, verified-moot}`.
- [`.orchestrator/milestones/M026/phases/P01/SPIKE-SYNTHESIS-CRUX.md`](../../../../milestones/M026/phases/P01/SPIKE-SYNTHESIS-CRUX.md) (from T02)
  - Key fields: frontmatter `type: spike-report`; sections `## Method`, `## Findings`, `## Verdict`, `## Rationale`; exactly one line matching `^Verdict: (GO|NO-GO)$`.
- [`.orchestrator/milestones/M026/phases/P01/P01-SPIKE-GATE.md`](../../../../milestones/M026/phases/P01/P01-SPIKE-GATE.md) (from T02)
  - Key fields: a line matching `^gate=(GO|NO-GO)$`; `spike_report=` pointer line.
- [`.orchestrator/milestones/M026/phases/P01/OLLAMA-PROBE.md`](../../../../milestones/M026/phases/P01/OLLAMA-PROBE.md) (from T03)
  - Key fields: frontmatter `type: probe-report`; `result=` line; four `_present=(true|false)` lines; `## P02 Fallback Posture` section.

### From Disk (Pre-existing)
- `scripts/util/dual-write-runtime-md.sh` — dual-write helper (M014/P01 shipped).
- `scripts/verify/m025-p01-phase-suite.sh` + sibling `m025-p01-*.sh` scripts — pattern reference.
- `scripts/verify/m013-p04-bash32-compat.sh` (or `m025-p01-bash32-compat.sh`) — pattern reference for the bash32-compat gate.
- `CLAUDE.md`, `AGENTS.md` — dual-write targets (read before, modify via helper).

## Constraints

- **CON-2 Bash 3.2 compat**: every new `.sh` file is 3.2-clean. The bash32-compat gate self-excludes its violation-pattern list via case-branch discipline.
- **AD-19 single-script-file shape**: no Verification or Truth `Check:` command uses inline compound bash, plain subshells, `$(...)`-with-pipes, or process substitution. Helpers under `scripts/verify/lib/` absorb complexity.
- **OQ-10 dual-write invariant**: Recent Changes is written via `dual-write-runtime-md.sh`, not inline-edited. Inline edits violate the marker-bounded region invariant.
- **Scope**: T04 ships ONLY gate scripts + dual-write. No data artifact changes (the matrix, spike note, probe are T01/T02/T03's outputs). No adapter code changes (those are P02).

## Expected Output

- 10 new `.sh` files under `scripts/verify/` (9 gate scripts + 1 phase-suite orchestrator).
- 0-3 helper scripts under `scripts/verify/lib/` (as needed to satisfy AD-19).
- `CLAUDE.md` + `AGENTS.md` Recent Changes regions updated.
- `bash scripts/verify/m026-p01-phase-suite.sh` exits 0 with `SUMMARY: m026-p01-phase-suite.sh pass=9 fail=0` (or higher pass count if helper gates count separately).
