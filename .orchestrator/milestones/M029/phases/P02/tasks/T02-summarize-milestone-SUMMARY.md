---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P02"
milestone: "M029"
provides:
  - "AD-4 milestone summary helper at scripts/diagnostics/summarize-milestone.sh emitting fixed-order key=value block (phase_count/phases_complete/tasks_remaining/intensity); paired shape verifier at tools/verify/m029-p02-summarize-milestone-shape.sh (17 assertions) gating downstream drift on the four-key set + line regexes + fixed-order; sourceable+CLI dual-shape mirroring metrics-rollup.sh MEM004 pure-lib precedent; --milestone <M###> + --format=keys|text + -h|--help CLI surface; default-milestone resolution via find-active-milestone.sh first-token; intensity read from M###-EVALUATION.md frontmatter against closed enum quick|standard|full|unknown"
requires:
  - "from:P02/T01 what:design-contract-pairing-pattern (m029-p02-cross-milestone-shape-contract.sh shape precedent — AD-19 straight-line bash + grep -F per-assertion + parallel pass/fail counters + final SUMMARY line + exit 0 iff fail=0)"
affects:
  - "P02-T03,P02-T05,P03"
key_files:
  - "scripts/diagnostics/summarize-milestone.sh,tools/verify/m029-p02-summarize-milestone-shape.sh"
key_decisions:
  - "AD-4 (M029 owns its own milestone summary helper; SC-8 oracle amends from predictive-surface.sh --milestone to summarize-milestone.sh --milestone because M027 is closed under CON-3 knowledge-layer boundary),CON-1/FR-14/Principle XV read-only discipline,MEM004 pure-lib sourceable+CLI dual-shape,MEM001 bash 3.2 compatibility,AD-19 single-script-file straight-line bash for verifier"
patterns_established:
  - "four-key fixed-order output contract as AD-4 SC-8 oracle interface (phase_count/phases_complete/tasks_remaining/intensity); verifier asserts both the literal key strings in script body AND the line-regex shape AND the fixed line order — three independent invariants prevent silent drift; sourceable+CLI dual-shape with _SOURCED re-source guard + _SCRIPT_DIR/_PROJECT_ROOT resolution mirrors metrics-rollup.sh; default-milestone via find-active-milestone.sh first-token (existing convention from check-anomalies.sh / compression-eval.sh); intensity read from EVALUATION frontmatter validated against closed enum with unknown fallback; verifier captures stdout to /tmp/sm-out.$$ trap-cleaned then runs separate grep / case statements against the file (AD-19: no $(cmd | grep))"
drill_down_paths:
  - ".orchestrator/milestones/M029/phases/P02/tasks/T02-summarize-milestone-PLAN.md,scripts/diagnostics/summarize-milestone.sh,tools/verify/m029-p02-summarize-milestone-shape.sh"
duration: "12m"
verification_result: "pass"
completed_at: "2026-05-05T23:52:45Z"
---

T02 ships the AD-4 milestone summary helper at scripts/diagnostics/summarize-milestone.sh — a read-only deterministic helper that emits a fixed-order key=value block (phase_count, phases_complete, tasks_remaining, intensity) describing a milestone's progress. Two consumers: T03 render-position.sh (collapsed inactive-milestone shape per #Q-5: `<glyph> M### <name>  ▓░ X% (k/n phases)`), and P03's SC-8 oracle wrapper (AD-4 amends SC-8's original `predictive-surface.sh --milestone` byte-identity oracle to wrap this helper instead, since M027 is closed under CON-3's knowledge-layer boundary).

Deliverables (both on disk):

- scripts/diagnostics/summarize-milestone.sh (188 lines, executable, bash 3.2 compatible per MEM001). Sourceable+CLI dual-shape mirroring the metrics-rollup.sh / efficiency-footer.sh MEM004 pure-lib precedent: `_SUMMARIZE_MILESTONE_SH_SOURCED` re-source guard, `_SM_SCRIPT_DIR` / `_SM_PROJECT_ROOT` resolution, three-helper-style flag parser (`--milestone <M###>`, `--milestone=...`, `--format keys|text`, `--format=...`, `-h|--help`). Default-milestone resolution invokes `bash scripts/state/find-active-milestone.sh "$PROJECT_ROOT/.orchestrator"` and takes the first whitespace-delimited token of its `M### <state> <tier>` output. Phase enumeration is a simple for-loop over `phases/P*/`; phases with `P##-SUMMARY.md` count as complete; phases without it have their `tasks/T##-*-PLAN.md`-without-paired-SUMMARY count summed into `tasks_remaining`. Intensity is read from `M###-EVALUATION.md` YAML frontmatter (`^intensity:` line, lowercased, validated against the closed enum quick|standard|full else `unknown`). `--format=keys` (default) emits the four keys in fixed order; `--format=text` emits a single human-readable line. Read-only (CON-1 / FR-14 / Principle XV): no writes, no log emission, no state mutation. Exit codes: 0 on success, 2 on usage / unknown flag / no milestone resolvable.

- tools/verify/m029-p02-summarize-milestone-shape.sh (143 lines, executable, AD-19 single-script-file straight-line bash). 17 assertions across 6 categories: file existence + executable bit (2), the four canonical output keys declared in the script body (4), header tokens AD-4 / read-only contract / bash 3.2 (3), CLI flag documentation --milestone + --format (2), behavioral spot-check exits 0 against M029 (1), four behavioral stdout-line regex assertions on `^phase_count=N`, `^phases_complete=N`, `^tasks_remaining=N`, `^intensity=<enum>` (4), and the fixed-order assertion that lines 1-4 are the four keys in canonical order via four sequential `IFS= read -r` calls (1). The verifier captures stdout to `/tmp/sm-out.$$` then runs separate grep / case statements against the file — no `$(cmd | grep)`, no plain subshells.

Verification (single Must-Have): `bash tools/verify/m029-p02-summarize-milestone-shape.sh` — 17/17 PASS, exit 0. Final SUMMARY line: `SUMMARY: m029-p02-summarize-milestone-shape.sh pass=17 fail=0`.

Behavioral validation against the live M029 tree: `--milestone M029 --format=keys` emits `phase_count=2 phases_complete=1 tasks_remaining=4 intensity=unknown` (P01 closed via P01-SUMMARY.md; P02 in-flight with 5 task plans of which T01-cross-milestone-data-model is closed via SUMMARY); `intensity=unknown` is the live value because M029-EVALUATION.md has no `intensity:` field today. `--format=text` emits `M029 — 1/2 phases complete, 4 tasks remaining, intensity=unknown` (M029-ROADMAP.md has no H1 so the milestone-ID fallback path is the live one). Spot-checked against closed M030: `phase_count=8 phases_complete=8 tasks_remaining=0`. `--bogus` exits 2 with stderr usage; `--format=foo` exits 2 with stderr usage; `--help` prints to stdout, exit 0.

CON-7 / AD-8 boundary discipline preserved: T02 introduces NO schema additions to M013 sidecar, M019 JSONL, M020 KNOWLEDGE.md, or M027 surfaces. The two new files (scripts/diagnostics/*.sh + tools/verify/*.sh) are the only artifacts. `summarize-milestone.sh` does NOT extend predictive-surface.sh, metrics-rollup.sh, or efficiency-footer.sh; per AD-4, the wrapper lives in M029's surface as a peer composition layer, not a modification of M027.

Pattern reused from existing dispatch surface: sourceable+CLI dual-shape mirrors metrics-rollup.sh (MEM004 pure-lib pattern); re-source guard pattern + script-dir/project-root resolution mirrors metrics-rollup.sh exactly; verifier shape (grep -F per assertion + parallel pass/fail counters + final SUMMARY line + exit 0 iff fail=0) mirrors m029-p01-headline-shape-contract.sh and m029-p02-cross-milestone-shape-contract.sh from T01.

Pattern established for downstream consumers: the four-key fixed-order output contract IS the AD-4 SC-8 oracle interface. T03 render-position.sh reads phase_count + phases_complete + intensity to compute the inactive-milestone collapsed-shape progress bar (`▓░ X% (k/n phases)`); P03's SC-8 oracle wrapper reads the same four keys for byte-identity comparison. The verifier asserts the four-key set, the four line regexes, AND the fixed line order — so neither consumer can drift silently if a future edit reorders, renames, or drops a key. The verifier code itself (which contains the literal key strings in its assertion array) is not deliverable text — it asserts the helper body contains those keys, mirroring the P01/T01 verifier discipline.

Plan-shape compliance: the task plan listed deliverable bullets in the description-suffixed shape (`- \`path\` — description`), avoiding the auto-loop bare-backtick parser regression that surfaced in P01/T04-T06. No in-flight plan repair needed.
