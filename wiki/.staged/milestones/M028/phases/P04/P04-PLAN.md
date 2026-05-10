---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M028"
goal: "Author four investigation-pattern wrappers under scripts/util/ (grep-files, cleanup-stale-results, node-eval, peek-files) that replace the agent-invented compound shells observed in Screenshots 1, 2, 5, 6 + Finding G; document them in commands/dispatch.md, templates/dispatch-prompt.md, and a new Investigation patterns subsection in ANTIPATTERNS.md; ship per-finding end-to-end verifiers for D, E, and the G wrapper path; and roll up scripts/verify/m028/run-all.sh from 5/7 to 7/7."
demo_sentence: "A developer reads `commands/dispatch.md`'s new 'Investigation patterns' section and sees four canonical wrapper invocations covering grep-across-files / cleanup-stale-results / node-eval / peek-files; each wrapper exists at scripts/util/<name>.sh and runs through bash 3.2 + POSIX sh; bash scripts/verify/anti-pattern-lint.sh exits 0 against the updated dispatch payload + commands/dispatch.md + ANTIPATTERNS.md; bash scripts/verify/m028/run-all.sh reports 'M028: 7/7 findings verified' (no more D/E SKIPs)."
risk: "low"
depends_on: ["P02", "P03"]
---

## Must-Haves

### Truths

<!-- All Truth Check commands invoke project-tree verifiers directly per AD-19 and the
     M028/P02 dogfood finding (run-probe.sh is reserved for staged throwaway probes
     under /tmp, /var/folders, or <repo>/tmp/, NOT a generic invocation harness).
     Every line is single-script-file shape. Every Check verifier is co-authored with
     its task per the CLAUDE.md "Plan-time verifier-availability cross-check" hotfix —
     no cross-task verifier dependency. The classifier verdicts on every proposed
     wrapper invocation and verifier-invocation line were empirically traced through
     `scripts/verify/lib/shape-classifier.sh::classify_command` at plan-authoring time
     and recorded in plan prose. -->

- The four investigation-pattern wrappers exist under `scripts/util/` (grep-files.sh, cleanup-stale-results.sh, node-eval.sh, peek-files.sh), each a flat AD-19 single-script-file shape, each runnable on bash 3.2 + POSIX sh with no jq / node / python dependency beyond what each wrapper's own Description requires (node-eval.sh shells out to `node` only when invoked).
  - Check: `bash scripts/verify/m028/p04-wrappers-present.sh`
- `scripts/util/grep-files.sh <pattern> <file...>` greps each file in turn with a per-file separator and an aggregate exit code; replaces the `grep …; echo "---"; grep …` Screenshot 1 compound shape.
  - Check: `bash scripts/verify/m028/p04-grep-files.sh`
- `scripts/util/cleanup-stale-results.sh <milestone>` removes per-step result files for the named milestone and prints the residual listing; replaces the `/bin/rm -f .../*.txt && ls .../*.txt` Screenshot 2 / Finding D compound shape; refuses paths outside `.orchestrator/milestones/<MID>/` to bound blast radius.
  - Check: `bash scripts/verify/m028/p04-cleanup-stale-results.sh`
- `scripts/util/node-eval.sh <script-path> [args...]` runs `node` against a script file (positional path, not `-e` body); rejects multi-line `-e` bodies; replaces the multiline `node -e "…"` AP-012 shape.
  - Check: `bash scripts/verify/m028/p04-node-eval.sh`
- `scripts/util/peek-files.sh <pattern> [--lines N] [--exclude PATH]` enumerates files matching the glob, prints a per-file separator, and head-N's each file; replaces the Finding G `find | head | xargs -I{} sh -c '…echo;head…'` AP-014 shape.
  - Check: `bash scripts/verify/m028/p04-peek-files.sh`
- `commands/dispatch.md` carries an "Investigation Patterns" section naming all four wrappers with a one-line usage example each plus a cross-reference to its AP-ID (AP-010 → grep-files.sh, AP-012 → node-eval.sh, AP-013 → peek-files.sh, AP-014 → peek-files.sh; cleanup-stale-results.sh is anchored at Finding D / Screenshot 2 with a remediation note in the section); `templates/dispatch-prompt.md` carries a parallel "Investigation Patterns" section pointing at the same wrappers; `ANTIPATTERNS.md` gains an "Investigation patterns" subsection cross-referencing each wrapper to its AP-ID.
  - Check: `bash scripts/verify/m028/p04-investigation-section.sh`
- `bash scripts/verify/anti-pattern-lint.sh` exits 0 against the updated `commands/dispatch.md`, `templates/dispatch-prompt.md`, and `ANTIPATTERNS.md` — the canonical wrapper-invocation examples are themselves shape-clean (no AP-009 compound, no AP-008 heredoc, no AP-006 redirect-cmdsub, no AP-014 sh-c body).
  - Check: `bash scripts/verify/m028/p04-anti-pattern-lint-clean.sh`
- Per-finding end-to-end verifiers exist for Findings D, E, and the G wrapper path: `scripts/verify/m028/finding-D-verifier.sh` (cleanup-stale-results happy path + boundary refusal), `scripts/verify/m028/finding-E-verifier.sh` (grep-files happy path + node-eval happy path; investigation patterns are reachable), `scripts/verify/m028/finding-G-wrapper-verifier.sh` (peek-files exercises the verbatim Finding G use case end-to-end without invoking the AP-014 shape).
  - Check: `bash scripts/verify/m028/p04-finding-verifiers-present.sh`
- `bash scripts/verify/m028/run-all.sh` reports `M028: 7/7 findings verified` (skipped: 0, failed: 0) — the post-P04 state retires the P03-era D/E SKIPs and ships the closing acceptance for SC-4.
  - Check: `bash scripts/verify/m028/p04-run-all-clean.sh`

### Artifacts

- scripts/util/grep-files.sh (min 30 lines, contains "grep-files.sh")
- scripts/util/cleanup-stale-results.sh (min 40 lines, contains "cleanup-stale-results.sh")
- scripts/util/node-eval.sh (min 30 lines, contains "node-eval.sh")
- scripts/util/peek-files.sh (min 50 lines, contains "peek-files.sh")
- commands/dispatch.md (min 200 lines, contains "Investigation Patterns")
- templates/dispatch-prompt.md (min 60 lines, contains "Investigation Patterns")
- ANTIPATTERNS.md (min 340 lines, contains "Investigation patterns")
- scripts/verify/m028/finding-D-verifier.sh (min 60 lines, contains "cleanup-stale-results")
- scripts/verify/m028/finding-E-verifier.sh (min 60 lines, contains "grep-files")
- scripts/verify/m028/finding-G-wrapper-verifier.sh (min 60 lines, contains "peek-files")
- scripts/verify/m028/run-all.sh (min 40 lines, contains "M028: 7/7")
- scripts/verify/m028/p04-wrappers-present.sh (min 30 lines, contains "grep-files.sh")
- scripts/verify/m028/p04-grep-files.sh (min 30 lines, contains "grep-files.sh")
- scripts/verify/m028/p04-cleanup-stale-results.sh (min 40 lines, contains "cleanup-stale-results")
- scripts/verify/m028/p04-node-eval.sh (min 30 lines, contains "node-eval")
- scripts/verify/m028/p04-peek-files.sh (min 40 lines, contains "peek-files")
- scripts/verify/m028/p04-investigation-section.sh (min 40 lines, contains "Investigation Patterns")
- scripts/verify/m028/p04-anti-pattern-lint-clean.sh (min 30 lines, contains "anti-pattern-lint.sh")
- scripts/verify/m028/p04-finding-verifiers-present.sh (min 30 lines, contains "finding-D-verifier.sh")
- scripts/verify/m028/p04-run-all-clean.sh (min 30 lines, contains "M028: 7/7")

### Key Links

- commands/dispatch.md → grep-files.sh (Investigation Patterns section names the wrapper)
- commands/dispatch.md → cleanup-stale-results.sh (Investigation Patterns section names the wrapper)
- commands/dispatch.md → node-eval.sh (Investigation Patterns section names the wrapper)
- commands/dispatch.md → peek-files.sh (Investigation Patterns section names the wrapper)
- templates/dispatch-prompt.md → grep-files.sh (Investigation Patterns section names the wrapper)
- templates/dispatch-prompt.md → peek-files.sh (Investigation Patterns section names the wrapper)
- ANTIPATTERNS.md → grep-files.sh (AP-010 cross-ref + Investigation patterns subsection)
- ANTIPATTERNS.md → node-eval.sh (AP-012 cross-ref + Investigation patterns subsection)
- ANTIPATTERNS.md → peek-files.sh (AP-013 + AP-014 cross-refs + Investigation patterns subsection)
- ANTIPATTERNS.md → cleanup-stale-results.sh (Investigation patterns subsection cross-ref)
- scripts/verify/m028/finding-D-verifier.sh → cleanup-stale-results.sh (verifier exercises the wrapper)
- scripts/verify/m028/finding-E-verifier.sh → grep-files.sh (verifier exercises the wrapper)
- scripts/verify/m028/finding-G-wrapper-verifier.sh → peek-files.sh (verifier exercises the wrapper)
- scripts/verify/m028/run-all.sh → finding-D-verifier.sh (roll-up invokes the new D verifier)
- scripts/verify/m028/run-all.sh → finding-E-verifier.sh (roll-up invokes the new E verifier)

## Tasks

### T01: Investigation Wrappers — grep-files + cleanup-stale-results

See [`.orchestrator/milestones/M028/phases/P04/tasks/T01-investigation-wrappers-A-PLAN.md`](../../../../milestones/M028/phases/P04/tasks/T01-investigation-wrappers-A-PLAN.md).

Authors `scripts/util/grep-files.sh` (FR-14, replaces Screenshot 1 `grep …; echo "---"; grep …` shape) and `scripts/util/cleanup-stale-results.sh` (FR-15, replaces Screenshot 2 / Finding D `/bin/rm -f .../*.txt && ls .../*.txt` shape). Both flat AD-19 single-script-file, bash 3.2 + POSIX-sh-safe, no jq. Co-authors the matching plan-level verifiers `scripts/verify/m028/p04-grep-files.sh` and `scripts/verify/m028/p04-cleanup-stale-results.sh` (CLAUDE.md hotfix "Plan-time verifier-availability cross-check" — co-author at task time).

### T02: Investigation Wrappers — node-eval + peek-files

See [`.orchestrator/milestones/M028/phases/P04/tasks/T02-investigation-wrappers-B-PLAN.md`](../../../../milestones/M028/phases/P04/tasks/T02-investigation-wrappers-B-PLAN.md).

Authors `scripts/util/node-eval.sh` (FR-16, replaces multiline `node -e "…"` AP-012 shape) and `scripts/util/peek-files.sh` (FR-17, replaces Finding G `find | head | xargs sh -c '…'` AP-014 shape). Both flat AD-19 single-script-file, bash 3.2 + POSIX-sh-safe, no jq. peek-files.sh enumerates matches via `find` (no `-exec`-into-`sh -c`), prints per-file separators with a Heredoc-free printf shape, and head-N's each match. Co-authors `scripts/verify/m028/p04-node-eval.sh` and `scripts/verify/m028/p04-peek-files.sh`.

### T03: Investigation Patterns Documentation Section

See [`.orchestrator/milestones/M028/phases/P04/tasks/T03-investigation-section-PLAN.md`](../../../../milestones/M028/phases/P04/tasks/T03-investigation-section-PLAN.md).

Adds a new top-level "Investigation Patterns" section to `commands/dispatch.md` (placed after "Context Construction", before "Dispatch Strategy"); a parallel "Investigation Patterns" section to `templates/dispatch-prompt.md` (placed after "Scope", before "Upstream Context"); and a new "Investigation patterns" subsection to `ANTIPATTERNS.md` (placed after AP-014, before any future entries). Each section names all four wrappers with a one-line usage example and an AP-ID cross-reference. Authoring discipline: the canonical examples must themselves pass `bash scripts/verify/anti-pattern-lint.sh` (no compound shells, no quoted-brace, no backtick-in-grep, no nested cmd-sub). Co-authors `scripts/verify/m028/p04-investigation-section.sh` (asserts each section exists and names each wrapper) and `scripts/verify/m028/p04-anti-pattern-lint-clean.sh` (runs `anti-pattern-lint.sh` and asserts exit 0 against the updated tree).

### T04: Per-Finding Verifiers — D, E, G-wrapper

See [`.orchestrator/milestones/M028/phases/P04/tasks/T04-per-finding-verifiers-PLAN.md`](../../../../milestones/M028/phases/P04/tasks/T04-per-finding-verifiers-PLAN.md).

Authors three per-finding end-to-end verifiers under `scripts/verify/m028/`:

1. `finding-D-verifier.sh` — exercises `cleanup-stale-results.sh` happy path against an isolated tmp tree mirroring `.orchestrator/milestones/<MID>/` and confirms boundary refusal (paths outside the milestone dir → exit non-zero with diagnostic).
2. `finding-E-verifier.sh` — exercises `grep-files.sh` happy path (multi-file pattern grep with per-file separators) and `node-eval.sh` happy path (run a tmp-staged `.js` file emitting a known stdout marker); both wrappers are reachable without inventing compound shells.
3. `finding-G-wrapper-verifier.sh` — exercises `peek-files.sh` against a tmp-staged file tree mirroring the verbatim Finding G use case (recursively find `T*-SUMMARY.md`, head-N each), proves the wrapper produces the operator's intended output without invoking the AP-014 `xargs sh -c '<body>'` shape.

Each verifier is a flat AD-19 single-script-file, bash 3.2 + POSIX-sh-safe, no jq.

### T05: Run-All Roll-Up to 7/7 + Cross-Cutting Verifiers

See [`.orchestrator/milestones/M028/phases/P04/tasks/T05-run-all-rollup-PLAN.md`](../../../../milestones/M028/phases/P04/tasks/T05-run-all-rollup-PLAN.md).

Updates `scripts/verify/m028/run-all.sh` so the previously-SKIPped Findings D and E now invoke `finding-D-verifier.sh` and `finding-E-verifier.sh` (which exist post-T04); the run-all summary line transitions from "M028: 5/7 findings verified" (P03 close state) to "M028: 7/7 findings verified" (P04 close state, SC-4). Authors the cross-cutting plan-level verifiers `scripts/verify/m028/p04-wrappers-present.sh`, `scripts/verify/m028/p04-finding-verifiers-present.sh`, and `scripts/verify/m028/p04-run-all-clean.sh` (the P04 phase's close-out roll-up Truths). Each verifier is flat AD-19, bash 3.2 + POSIX-sh-safe, no jq.

## Task Dependencies

```
T01 (grep-files + cleanup-stale-results) ─┐
                                            ├─→ T03 (docs) ─┐
T02 (node-eval + peek-files) ──────────────┘                ├─→ T04 (per-finding verifiers) ─→ T05 (run-all + cross-cutting)
                                                             │
T01 + T02 ──────────────────────────────────────────────────┘
```

T01 and T02 are parallelizable (independent wrappers + their plan-level verifiers). T03 consumes both wrapper sets to write the canonical examples. T04 consumes T01 + T02 wrappers (and writes verifiers that exercise them) and T03's investigation-pattern section (the verifiers cite the section as part of their evidence). T05 consumes T04 (run-all roll-up requires finding-D + finding-E verifiers to exist).

## Files Likely Touched

- scripts/util/grep-files.sh (create)
- scripts/util/cleanup-stale-results.sh (create)
- scripts/util/node-eval.sh (create)
- scripts/util/peek-files.sh (create)
- commands/dispatch.md (modify)
- templates/dispatch-prompt.md (modify)
- ANTIPATTERNS.md (modify)
- scripts/verify/m028/finding-D-verifier.sh (create)
- scripts/verify/m028/finding-E-verifier.sh (create)
- scripts/verify/m028/finding-G-wrapper-verifier.sh (create)
- scripts/verify/m028/run-all.sh (modify)
- scripts/verify/m028/p04-wrappers-present.sh (create)
- scripts/verify/m028/p04-grep-files.sh (create)
- scripts/verify/m028/p04-cleanup-stale-results.sh (create)
- scripts/verify/m028/p04-node-eval.sh (create)
- scripts/verify/m028/p04-peek-files.sh (create)
- scripts/verify/m028/p04-investigation-section.sh (create)
- scripts/verify/m028/p04-anti-pattern-lint-clean.sh (create)
- scripts/verify/m028/p04-finding-verifiers-present.sh (create)
- scripts/verify/m028/p04-run-all-clean.sh (create)
