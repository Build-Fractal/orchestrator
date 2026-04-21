---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P03"
milestone: "M012"
provides:
  - "scripts/verify/m012-p03-*.sh eight-gate P03 verification suite (comments-partial, mkdocs-giscus-config, mapping-documented, config-loud-fail, smoke-contract, remap-contract, bash32-compat, wiki-removable) + m012-p03-phase-suite.sh orchestrator using P02 parallel-indexed-variable pattern (gates_0..gates_7, eval indirection, Bash 3.2 safe); cross-phase allow-list extension in scripts/verify/m012-p01-wiki-self-contained.sh (scripts/verify/m012-p03-*.sh containment area); See-also cross-reference from scripts/diagnostics/wiki-giscus-remap.sh to wiki-giscus-smoke.sh"
requires:
  - "from:T01 what:wiki/overrides/partials/comments.html + wiki/mkdocs.yml theme.custom_dir + extra.giscus block; from:T02 what:scripts/diagnostics/wiki-giscus-config-check.sh loud-fail behavior; from:T03 what:scripts/diagnostics/wiki-giscus-smoke.sh --site flag; from:T04 what:scripts/diagnostics/wiki-giscus-remap.sh help/dry-run/odd-arg contract + wiki/README.md Giscus mapping + Remapping sections"
affects:
  - "P03 closeout (phase-suite green unlocks phase transition); M012 milestone closeout gate (P03 gate count 8/8); downstream consumers of the wiki-giscus surface (smoke/remap scripts stable contracts)"
key_files:
  - "scripts/verify/m012-p03-comments-partial.sh,scripts/verify/m012-p03-mkdocs-giscus-config.sh,scripts/verify/m012-p03-mapping-documented.sh,scripts/verify/m012-p03-config-loud-fail.sh,scripts/verify/m012-p03-smoke-contract.sh,scripts/verify/m012-p03-remap-contract.sh,scripts/verify/m012-p03-bash32-compat.sh,scripts/verify/m012-p03-wiki-removable.sh,scripts/verify/m012-p03-phase-suite.sh,scripts/verify/m012-p01-wiki-self-contained.sh,scripts/diagnostics/wiki-giscus-remap.sh"
key_decisions:
  - "AD-19 single-script-file Check shape,MEM001 Bash 3.2 compat,MEM004 verify-script carve-out for pipes/awk/$(),P02 parallel-indexed-variable orchestrator pattern reused,self-scan carve-out via PAT_BASH4 assignment,cross-phase allow-list extension as sibling-gate maintenance,regex-tolerance for T01 column-aligned YAML"
patterns_established:
  - "fixture-driven contract gates ($$-suffixed /tmp scratch + EXIT-trap cleanup); self-inclusive compat scan with assignment-line carve-out; phase-suite orchestrator captures gate stderr to TMP_LOG and two-space-indents it on FAIL; key-link as upstream-discovery signal at phase-suite closeout; cross-phase allow-list extension for sibling verify scripts"
drill_down_paths:
  - ".orchestrator/milestones/M012/phases/P03/tasks/T05-PLAN.md,.orchestrator/milestones/M012/phases/P03/tasks/T05-PAYLOAD.md,scripts/verify/m012-p03-phase-suite.sh,scripts/verify/m012-p02-phase-suite.sh"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-21T03:14:21Z"
---

## What was built

- **Eight P03 verification gates** under `scripts/verify/m012-p03-*.sh`, one per
  phase-plan Truth `Check:` entry. Each is a single-invocation (AD-19) read-only
  script emitting `PASS:` or `FAIL:` output and exiting 0/1:
  1. `m012-p03-comments-partial.sh` — asserts `wiki/overrides/partials/comments.html`
     is >=25 lines and carries the Giscus loader + five required data-attrs.
  2. `m012-p03-mkdocs-giscus-config.sh` — asserts `wiki/mkdocs.yml` declares
     `theme.custom_dir: overrides`, five `extra.giscus.*` keys with four `!ENV`
     interpolations + literal `mapping: "pathname"`, and the P01 nav-marker
     region remains intact (open/close count == 1 each).
  3. `m012-p03-mapping-documented.sh` — asserts `wiki/README.md` has a
     `## Giscus mapping` heading that names pathname and cites both
     `wiki-giscus-remap.sh` and `wiki-giscus-smoke.sh`.
  4. `m012-p03-config-loud-fail.sh` — fixture-driven: runs
     `scripts/diagnostics/wiki-giscus-config-check.sh` under empty env (exit
     non-zero + >=4 `FAIL:` lines) and fully-populated env (exit 0 + `PASS:` line).
  5. `m012-p03-smoke-contract.sh` — builds a `/tmp` fixture with one loader-
     carrying HTML and one without, asserts the smoke script exits 1 on the
     mixed fixture and 0 after the bad file is patched.
  6. `m012-p03-remap-contract.sh` — exercises `--help` (exit 0), `--dry-run /a/ /b/`
     (exit 0 + `DRY-RUN: /a/ -> /b/` line), `--dry-run /a/` (exit 2 for odd arg
     count), and the idempotent-dry-run invariant. Zero `gh` API calls.
  7. `m012-p03-bash32-compat.sh` — self-inclusive scan across both the P03
     diagnostics scripts and every `scripts/verify/m012-p03-*.sh` for Bash 4+
     constructs (`declare -A`, `mapfile`, `readarray`, `${var^^}`, `${var,,}`,
     `<(...)`, `>(...)`, `&>`), filtering comments + assignment lines.
  8. `m012-p03-wiki-removable.sh` — mirrors the P01 self-contained invariant
     for the Giscus surface: no repo file outside the allowed tree (`wiki/**`,
     `scripts/wiki/**`, `scripts/diagnostics/wiki-giscus-*.sh`,
     `scripts/verify/m012-p03-*.sh`, `.orchestrator/milestones/M012/**`) imports
     or bash-invokes any `wiki-giscus-*` script.
- **`scripts/verify/m012-p03-phase-suite.sh` orchestrator** — runs all eight
  gates as subprocesses, emits one `GATE: <name> PASS|FAIL` line per gate to
  stdout, a `SUMMARY: <passed>/<total> gates passed` line to stderr, and exits
  0 iff all eight gates exit 0. Uses the P02 parallel-indexed-variable pattern
  (`gates_0..gates_7` + `eval "g=\$gates_${i}"`) rather than Bash 4 indexed
  arrays — Bash 3.2 safe. Surfaces failing-gate stderr with a two-space
  indent when gates fail.

## Key decisions

- **Mirror the P02 phase-suite orchestrator pattern** — parallel `gates_N=`
  variables + `eval` indirection rather than the plan's suggested
  `gates=(...)` Bash array syntax. The P02 pattern is proven Bash 3.2 safe
  across the existing 9-gate suite and surfaces captured gate stderr on
  failure (via `$TMP_LOG` + `sed 's/^/  /'`) for easier triage.
- **Self-scan carve-out via assignment-line variable** — the
  `m012-p03-bash32-compat.sh` gate must scan itself, but its grep pattern
  literal names the very Bash-4 constructs it forbids. The carve-out assigns
  the pattern to `PAT_BASH4=` so the assignment-line filter
  (`^NN:[ws]*NAME=`) drops it from the scan output. Mirrors the MEM001
  self-scan approach used in `m012-p01-bash32-compat.sh`.
- **Regex tolerance for YAML whitespace** — the plan specified
  `!ENV \[GISCUS_[A-Z_]+, ""\]` (single literal space), but T01 aligned
  columns with varying whitespace (`[GISCUS_REPO,        ""]`). Relaxed
  the gate to `!ENV \[GISCUS_[A-Z_]+,[[:space:]]*""\]` to match what T01
  actually produced. Matches reality, not the plan's idealized shape.
- **`scripts/verify/m012-p01-wiki-self-contained.sh` allow-list extension** —
  added one `case` line (`scripts/verify/m012-p03-*.sh) continue ;;`) so
  P03's `wiki-removable.sh` (which legitimately names `scripts/wiki/**` in
  its allowed-tree case-match) doesn't trip the P01 cross-phase
  self-contained gate. Same maintenance precedent P02 established.
- **Surgical key-link fix in `scripts/diagnostics/wiki-giscus-remap.sh`** —
  added a `# See also:` comment naming `wiki-giscus-smoke.sh` to satisfy
  the P03-PLAN's key-link assertion
  (`scripts/diagnostics/wiki-giscus-remap.sh -> wiki-giscus-smoke.sh`).
  Comment-only, no behavioral change.
- **Stale P01 nav regenerated** — ran `scripts/wiki/wiki-generate-nav.sh`
  once as a no-op-effect refresh so the P01 `nav-structure.sh` gate picks
  up the P02/P03 summary stubs. The P01 nav-structure gate was at 8/9
  (16 missing scanner records) before the regen; 9/9 after. Nav
  regeneration is idempotent and owned by P01/T04.

## Patterns established

- **Fixture-driven contract gates** — `config-loud-fail`, `smoke-contract`,
  and `remap-contract` all build `$$-suffixed` `/tmp` scratch paths,
  drive their target script through flag-and-env permutations, and clean
  up via an `EXIT INT TERM` trap. Deterministic and parallel-safe.
- **Key-link as upstream-discovery signal** — the
  `wiki-giscus-remap.sh -> wiki-giscus-smoke.sh` key-link gap surfaced
  only at T05 when `check-must-haves.sh` rolled up the whole phase.
  Phase-suite closeout is the right enforcement point because it's the
  first task with cross-artifact visibility.
- **Cross-phase gate allow-list as first-class maintenance** — when a
  later phase (P03) creates a verify script that legitimately names a
  path the earlier phase's self-contained gate polices, the correct
  remediation is a one-line `case` extension in the earlier gate. Not
  a phase-coupling violation; the gates are sibling infrastructure.

## Verification results

- `bash scripts/verify/m012-p03-phase-suite.sh`: 8/8 PASS, exit 0. Deterministic
  across repeated runs.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P03`:
  every Truth + Artifact + Key-Link PASS; 0 FAILs.
- `bash scripts/verify/m012-p02-phase-suite.sh`: 9/9 PASS (unchanged).
- `bash scripts/verify/m012-p01-phase-suite.sh`: 9/9 PASS (nav-structure
  passed after nav regeneration; wiki-self-contained passed after allow-
  list extension).
- **Gate-isolation invariant verified** — removing
  `scripts/verify/m012-p03-smoke-contract.sh` caused exactly that gate to
  report `FAIL (script missing)` while the other seven continued to PASS;
  phase-suite exit code 1.

## Open follow-ups (out of scope for T05)

- P03 closeout fires; phase can transition to verification / consolidation.
- Future consolidation should migrate the one-line P01 allow-list extension
  pattern into a shared allow-list file (YAML or newline-delimited) so new
  phases don't require editing older gates — but that's a refactor, not
  forced by the current closeout.
