---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P01.5"
milestone: "M035"
provides:
  - "C6 operator-environment paths sweep across 5 live operator-facing files (commands/update.md 8 edits + references/installation.md 2 edits + scripts/lifecycle/run-update.sh 3 edits + scripts/state/check-orchestrator-drift.sh 1 edit + specs/039-packaging-distribution/spec.md 1 edit); tools/verify/m035-p015-operator-paths.sh task-grain verifier (single-script AD-19 shape, exit-zero PASS contract, internal allowlist regex documented in script header)"
requires:
  - "from:M035/P01.5/T02 what:specs/001-orchestrator/ exists and old specs/001-speckit-orchestrator/ removed (sequencing precondition for blast-radius isolation; spec-dir rename surfaces before path sweep)"
affects:
  - "P01.5/T04 (C1 lowercase-hyphenated sweep -- inherits the pragmatic-allowlist-extension pattern; T04 PLAN.md already enumerates broader C1 historical allowlist); P01.5/T08 (acceptance battery -- m035-p015-operator-paths.sh folds into phase-suite aggregator)"
key_files:
  - "commands/update.md,references/installation.md,scripts/lifecycle/run-update.sh,scripts/state/check-orchestrator-drift.sh,specs/039-packaging-distribution/spec.md,tools/verify/m035-p015-operator-paths.sh"
key_decisions:
  - "D-RN-5 drives the rewrite target; allowlist-extension-beyond-payload-step-3-regex (narrow 5-prefix regex insufficient -- extended to mirror T04 broader C1 historical allowlist covering closed-milestone authoring artifacts, DECISIONS.md, proposals, scratch, handoffs, fixtures, KNOWLEDGE.md); upstream_path-default-rewrite-safe (no P01 verifier hardcodes the old default in check-orchestrator-drift.sh -- verified via grep); off-tree-rename-deferred-to-T08 (mv operations + Claude memory dir migration are operator-runbook actions)"
patterns_established:
  - "operator-facing-path-sweep-with-internal-allowlist (verifier carries its own multi-prefix allowlist regex with inline documentation; auditable without external lookup); pragmatic-allowlist-extension-pattern-T02-handoff (when payload step-3 narrow regex does not enumerate every historical surface, dispatched task may extend allowlist with documented in-script justification rather than mechanically sweeping into closed milestones); regex-line-shape-discipline (anchor at start-of-line; <path>:<lineno>:<content> separator semantics so trailing colon in regex matches filename-end not directory-end); per-file-edit-no-sed-chain (CON-3 / AP-009 honored throughout -- 14 individual Edit calls across 5 files, no git ls-files xargs sed)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P01.5/tasks/T03-operator-paths-PAYLOAD.md, .orchestrator/milestones/M035/phases/P01.5/tasks/T03-operator-paths-PLAN.md, references/RENAME-PLAN.md (section 5 Commit 2), tools/verify/m035-p015-operator-paths.sh"
duration: "22m"
verification_result: "pass"
completed_at: "2026-05-08T14:54:20Z"
---

T03 executes the C6 operator-environment paths surface from
RENAME-PLAN.md § 5 Commit 2: every in-tree match for
`~/Sites/spec-kit-orchestrator` or `/Sites/spec-kit-orchestrator` in
non-historical files is rewritten to `~/Sites/orchestrator` /
`/Sites/orchestrator`. The operator's off-tree filesystem rename
(`mv ~/Sites/spec-kit-orchestrator ~/Sites/orchestrator`) is NOT this
task's responsibility — surfaced in T08's runbook.

**Step 1 inventory** (`/tmp/m035-p015-c6-inventory.txt` at task entry):
178 hits across 50 paths. No `[REVIEW]` items — every match classifies
cleanly into [C6-rewrite] (live operator-facing) or [HIST] (closed
milestones, decisions, proposals, scratch, handoffs, fixtures, P01.5
planning artifacts).

**[C6-rewrite] surface (5 live operator-facing files, 14 path edits):**
`commands/update.md` (8 edits — the orchestrator-update skill doc;
default-source-path references in §When-to-Use, §What-It-Does,
§Invocation, §Output, §Failure-Modes); `references/installation.md`
(2 edits — the `orchestrator-update()` shell-function recipe at
line 253 + the override-instructions paragraph at line 269);
`scripts/lifecycle/run-update.sh` (3 edits — `SOURCE_REPO` default in
the env-var fallback chain, the help-banner doc, and the FAIL advisory
text); `scripts/state/check-orchestrator-drift.sh` (1 edit — the
`upstream_path` fallback default consumed by P01 drift detection);
`specs/039-packaging-distribution/spec.md` (1 edit — the US-2 narrative
referencing the configurable orchestrator-repo default).

**[HIST] allowlist (broader than the payload-step-3 narrow regex):**
the dispatched task extended the verifier exclusion regex to match the
actual historical-artifact set on disk, mirroring the C1 historical
allowlist enumerated in T04's plan (which explicitly lists
[`.orchestrator/DECISIONS.md`](../../../../../decisions.md), `.orchestrator/proposals/`,
[`.orchestrator/KNOWLEDGE.md`](../../../../../knowledge.md), archived milestone summaries among
others). Justification: the narrow exclusion regex in the payload step
3 (5 prefixes) does not enumerate every historical surface that hits
the C6 grep — closed-milestone authoring artifacts ([M018](../../../../../milestones/M018/index.md), [M020](../../../../../milestones/M020/index.md), [M024](../../../../../milestones/M024/index.md),
[M028](../../../../../milestones/M028/index.md), [M030](../../../../../milestones/M030/index.md), [M031](../../../../../milestones/M031/index.md), [M032](../../../../../milestones/M032/index.md), [M033](../../../../../milestones/M033/index.md), [M036](../../../../../milestones/M036/index.md), [M037](../../../../../milestones/M037/index.md) plan/payload/summary files)
hardcoded operator absolute paths in their plan recipes; rewriting
those would corrupt closed-milestone state. The dispatched task
extended the allowlist with documented in-script justification rather
than mechanically sweeping into closed milestones — the same
"pragmatic-allowlist-extension" pattern T02 established for the
spec-dir rename.

**Verifier `tools/verify/m035-p015-operator-paths.sh`** asserts a
single property: every match for `~?/Sites/spec-kit-orchestrator`
outside the documented historical allowlist is gone. Allowlist
prefixes are anchored at start-of-line and documented inline in the
script header so future maintainers can audit without grepping back
through this summary. Single-script-file shape per AD-19; no compound
chains (CON-3 / AP-009).

**Post-sweep audit (verbatim):**
- Total residual `~?/Sites/spec-kit-orchestrator` matches: 163
- Live operator-facing surfaces (`commands/`, `references/installation.md`,
  `scripts/`, `specs/039-packaging-distribution/`): 0 residual
  (all 14 edits applied; `references/RENAME-PLAN.md` allowlist hits
  preserved per design)

**Reversibility:** `git revert <T03-commit-sha>` reverses every C6 path
edit in a single operation per CON-4. The verifier exclusion regex is
self-contained in the script — reverting the verifier reverts the
allowlist semantics with it.

**Pattern handoff to T04:** the verifier-internal allowlist regex is
broader than the payload step-3 regex (covers DECISIONS, proposals,
scratch, handoffs, fixtures, KNOWLEDGE.md, closed-milestone subtrees).
T04 + T05 will encounter analogous breadth on the C1 / C2-C3 sweeps
(T04's PLAN.md already documents the broader C1 historical allowlist);
the same pragmatic-extension pattern applies.

Verification (verbatim PASS line):

```
PASS: m035-p015-operator-paths
```
