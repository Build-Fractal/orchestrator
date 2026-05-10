---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P06"
milestone: "M035"
provides:
  - "commands/update.md ## Update sources H2 expanded with: per-channel dispatch table (4 columns: update_source / dispatched command / pre-flight check / notes; covers git/npm/homebrew/none) + ### AD-5 detection H3 (D014 four-step ordering with persistence semantics) + ### `update_run` JSONL emission H3 (verbatim event template) + ### Suppression knobs H3 (5-condition matrix per D013 verbatim); ## Cross-references extended with one new MIT-2 exclusion-list entry pointing at references/installation.md § Channel-specific metadata files; every other section verbatim-preserved (including P05 T02's byte-identical symlink-mode rollback advisory) + task-grain verifier (m035-p06-update-skill-doc-multi-source-shape.sh BATTERY pass=12)"
requires:
  - "from:M035/P06-T01 what:D012-and-update_source-schema-enumeration-cited-in-H2-prose-intro from:M035/P06-T02 what:D014-AD-5-detection-ordering-cited-verbatim-in-AD-5-detection-H3 from:M035/P06-T03 what:D013-5-condition-suppression-matrix-cited-verbatim-in-Suppression-knobs-H3 from:M035/P05-T02 what:Rollback-section-symlink-mode-advisory-byte-identical-anchor"
affects:
  - "P06/T05 (consumes the documented surface contract for acceptance-battery cross-condition coverage),P06/T06 (phase-grain rollup absorbs the 12-assertion verifier into the suite)"
key_files:
  - "commands/update.md,tools/verify/m035-p06-update-skill-doc-multi-source-shape.sh"
key_decisions:
  - "D012 (cited in H2 prose for schema enumeration),D013 (cited verbatim in Suppression knobs H3),D014 (cited verbatim in AD-5 detection H3)"
patterns_established:
  - "section-preservation-discipline-with-verbatim-byte-anchor,per-channel-dispatch-table-mirrors-failure-modes-table-shape,AD-5-detection-enumerates-D014-ordering-verbatim,BSD-grep-flag-portability-grep-qF-double-dash,self-contained-operator-recipe-no-cross-doc-indirection"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P06/tasks/T04-update-skill-doc-multi-source-PLAN.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-05-09T23:50:53Z"
---

T04 ships the operator-facing documentation for the multi-source dispatch contract in commands/update.md. The existing four-bullet `## Update sources` H2 (P03 T04 + P04 T04 attach) is replaced with a richer body: a per-channel dispatch table (update_source / dispatched command / pre-flight check / notes columns) covering git/npm/homebrew/none, an AD-5 detection H3 enumerating D014's four-step ordering with the persistence semantics that hits config.yml on first non-git invocation, an `### \`update_run\` JSONL emission` H3 with the verbatim event template, and a `### Suppression knobs` H3 carrying the 5-condition matrix per D013 verbatim.

The H2 prose intro restates the schema enumeration (git|npm|homebrew|none) per FR-13 / D012 and the curl-pipe-bash → npm collapse per D007/D009. The dispatch table mirrors the existing `## Failure Modes` table shape (4-column markdown table) so operators see one consistent visual idiom across the doc.

`## Cross-references` is extended with one new entry pointing at `references/installation.md § Channel-specific metadata files` (the MIT-2 canonical exclusion list referenced by the cross-channel byte-equivalence test under CON-5). Every existing cross-ref entry preserved verbatim.

Section preservation discipline honored: `## When to Use`, `## What It Does`, `## Invocation`, `## Rollback` (P05 T02 — including the byte-identical `rollback not available for symlink-mode installs` advisory), `## Output`, `## Failure Modes`, and `## Read-Mostly Discipline` are all unchanged. The verifier asserts the rollback advisory is byte-identical (assertion 11) so any future drift would surface immediately.

The 12-assertion verifier uses the AD-19 single-script-file shape, sources scripts/lib/errors.sh, and runs flat (no compound chains, no inline subshells, no caller-level pipelines). The five new H3 headings (Dispatch table / AD-5 detection / `update_run` JSONL emission / Suppression knobs) are matched with `grep -qF`. The literal --no-emit-jsonl is matched via `grep -qF -- '--no-emit-jsonl'` (BSD-grep flag-portability per the P04 T04 finding).

T01 + T02 + T03 regressions all green (BATTERY: pass=7/13/12 fail=0 respectively). Two pre-existing unstaged operator-owned files (templates/phase-plan.md, .orchestrator/direct-mode-execution-log.jsonl) were left untouched per dispatch instructions.

## Patterns established

- Section-preservation discipline with verbatim byte-anchor assertion — when modifying a doc that has a load-bearing section preserved from a prior task (P05 T02's symlink-mode rollback advisory), the verifier MUST grep for the literal advisory string. This catches accidental edit-spillover during the H2 body replacement.
- Per-channel dispatch table mirrors `## Failure Modes` table shape — operators read these surfaces side-by-side; using the same 4-column markdown idiom keeps cognitive load down.
- AD-5 detection paragraph enumerates D014's ordering verbatim — the doc IS the operator-facing contract; if D014 changes, this paragraph changes in lockstep.
- BSD-grep flag-portability for `--no-emit-jsonl` — `grep -qF -- '--no-emit-jsonl'` is the portable form (the leading `--` would otherwise be parsed as flag terminator on some BSD-grep variants). Mirrors P04 T04 precedent.
- Self-contained operator recipe — every recipe in the new doc body is runnable end-to-end without other-doc indirection. The dispatch table shows literal commands; the AD-5 paragraph enumerates the four steps; the JSONL H3 shows the literal event template. Operators do not have to chase cross-refs to understand the surface.

## Verification

- bash tools/verify/m035-p06-update-skill-doc-multi-source-shape.sh → BATTERY: pass=12 fail=0
- All 12 PASS lines match the plan's Expected Output verbatim.
- T03 regression: bash tools/verify/m035-p06-update-run-jsonl-emission-shape.sh → BATTERY: pass=12 fail=0 (no regression).
- T02 regression: bash tools/verify/m035-p06-multi-source-dispatch-shape.sh → BATTERY: pass=13 fail=0 (no regression).
- T01 regression: bash tools/verify/m035-p06-config-schema-shape.sh → BATTERY: pass=7 fail=0 (no regression).

## Caveats

- T04 is documentation-only — no script changes, no DECISIONS.md changes. The decisions D012/D013/D014 are referenced verbatim from the doc body, but their canonical authority lives in [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) (T01/T02/T03's responsibility).
- The H2 body intro states curl-pipe-bash users "are auto-detected as npm because the curl-pipe-bash installer extracts the npm tarball — D007/D009 single-source-of-truth". This is a forward-looking statement: the curl-pipe-bash installer doesn't ship until M035 P04 T04 (already closed). The runtime detection logic in run-update.sh's resolve_update_source (T02) does the install-meta.txt `runtime=` substring match that absorbs `curl` → `npm` per D012.
- Two unrelated unstaged files (templates/phase-plan.md, .orchestrator/direct-mode-execution-log.jsonl) were left untouched per the dispatch instructions — they are operator-owned WIP.

## Out-of-scope-found

- T05 territory (acceptance battery cross-condition coverage) — T04 documents the surface; T05 will exercise the 5-condition suppression matrix end-to-end against real fixtures.
- T06 territory (phase + milestone close) — the new verifier joins the suite when T06 rolls up the phase-grain BATTERY count.
