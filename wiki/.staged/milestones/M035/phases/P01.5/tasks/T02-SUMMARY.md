---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P01.5"
milestone: "M035"
provides:
  - "specs/001-speckit-orchestrator -> specs/001-orchestrator git-mv-tracked rename with full history preservation; 11-file in-tree content reference sweep (CLAUDE.md + references/file-formats.md + 9 fixture roadmaps); self-reference rewrite inside renamed dir across 12 files (contracts/state-files.md, conversus-plan/conversus.yml + apm/review.md + gh-aw/review.md, conversus-spec/apm review+revision, conversus-spec/gh-aw review, conversus-spec/spec-kit review+revision, conversus-spec/summary/final.md, data-model.md, plan.md, tasks.md); tools/verify/m035-p015-spec-dir-rename.sh task-grain verifier (single-script AD-19 shape, exit-zero PASS contract)"
requires:
  - "from:M035/P01.5/T01 what:D-RN-1..D-RN-7 decisions block + legacy-namespace-allowlist.txt + pre-rename git tag (none directly consumed by T02 verifier; T01 closure is sequencing precondition)"
affects:
  - "P01.5/T03 (operator-paths sweep -- old spec dir already gone); P01.5/T04 (C1 lowercase-hyphenated sweep -- feature_ref 001-speckit-orchestrator frontmatter values still pending); P01.5/T08 (acceptance battery -- m035-p015-spec-dir-rename.sh folds into phase-suite aggregator)"
key_files:
  - "specs/001-orchestrator/,CLAUDE.md,references/file-formats.md,tests/fixtures/roadmap-sample.md,tests/fixtures/state-complete/M001-ROADMAP.md,tests/fixtures/state-completing/M001-ROADMAP.md,tests/fixtures/state-executing/M001-ROADMAP.md,tests/fixtures/state-replanning/M001-ROADMAP.md,tests/fixtures/state-summarizing/M001-ROADMAP.md,tests/fixtures/state-validating/M001-ROADMAP.md,tests/fixtures/state-verifying/M001-ROADMAP.md,tools/verify/m035-p015-spec-dir-rename.sh"
key_decisions:
  - "D-RN-1 informs basename (specs/001-orchestrator matches @build-fractal/orchestrator unscoped name); allowlist-extension-beyond-payload-step-5-regex: P01.5-PLAN.md + T02/T03/T04 PLAN.md files preserved as narrative (analogous to explicitly-excluded P01.5-PLANNING-PAYLOAD.md, all document the rename itself); M015/P04/evidence/clean-clone-shape.txt preserved (archived path snapshot, rewrite would falsify audit); conversus-plan/apm/review.md absolute-path refs swept by substring (specs/... only, /Users/business-daddy/... prefix preserved as historical authoring-context record); verifier-runs-post-commit (git log --follow needs committed new path; pre-commit invocation returns empty)"
patterns_established:
  - "git-mv-then-substring-sweep-as-atomic-unit (rename + content references one commit, reversible via single git revert); pragmatic-allowlist-extension (when payload exclusion regex does not enumerate every narrative-rename-doc, dispatched task may extend allowlist with documented justification rather than mechanically sweeping rename-narrative files); verifier-post-commit-shape (git log --follow on the new path requires the rename to be committed first; verifier runs after the commit, not before); absolute-path-substring-sweep (when refs carry environment prefixes that document historical authoring context, sweep only the specs/<old>->specs/<new> substring and preserve prefix)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P01.5/tasks/T02-spec-dir-rename-PAYLOAD.md, .orchestrator/milestones/M035/phases/P01.5/tasks/T02-spec-dir-rename-PLAN.md, references/RENAME-PLAN.md (section 5 Commit 1 + Commit 6), tools/verify/m035-p015-spec-dir-rename.sh"
duration: "18m"
verification_result: "pass"
completed_at: "2026-05-08T14:24:29Z"
---

T02 executes the C9 spec-directory rename surface from RENAME-PLAN.md
§ 5 Commit 1 + Commit 6 as one atomic change: `git mv
specs/001-speckit-orchestrator specs/001-orchestrator` plus a content
sweep across every in-tree, non-historical reference to the old path.
History is preserved via `git mv` (not `mv` + `git rm` + `git add`) so
`git log --follow specs/001-orchestrator/spec.md` traces continuously
through the rename — verified by the new task-grain verifier.

The rename basename `001-orchestrator` (not `039-packaging-distribution`)
preserves the existing feature-index encoding. `001-` is the index for
the foundational orchestrator feature under M001; the slug update drops
the `speckit-` prefix per [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }") (npm package name
`@build-fractal/orchestrator` informs the unscoped basename).

**Sweep targets (11 non-historical files):** `CLAUDE.md` (1 ref);
`references/file-formats.md` (1 ref, example `feature_spec:` value);
`tests/fixtures/roadmap-sample.md` + 8
`tests/fixtures/state-{complete,completing,executing,replanning,
summarizing,validating,verifying}/M001-ROADMAP.md` fixture roadmaps
(1 ref each, frontmatter `feature_spec:` value).

**Self-references rewritten inside the renamed dir:**
`contracts/state-files.md` (2), `conversus-plan/conversus.yml` (5),
`conversus-plan/apm/review.md` (4 absolute-path refs — the
`/Users/business-daddy/...` prefix is preserved as a historical
authoring-environment record, only the `specs/...` substring is
swapped), `conversus-plan/gh-aw/review.md` (1),
`conversus-spec/{apm,gh-aw,spec-kit}/review.md` + `revision.md` (1
each), `conversus-spec/summary/final.md` (1), `data-model.md` (1),
`plan.md` (2), `tasks.md` (1).

**Allowlist (preserved as historical / runbook / narrative):**
`references/RENAME-PLAN.md` (the runbook itself documents the old
path); [`.orchestrator/milestones/M008/archive/P05/T06-PAYLOAD.md`](../../../../../milestones/M008/archive/P05/T06-PAYLOAD.md) +
`T06-PLAN.md` (archived milestone artifacts); `.orchestrator/
milestones/M015/phases/P04/evidence/clean-clone-shape.txt` ([M015](../../../../../milestones/M015/index.md)
clean-clone evidence — a path snapshot at the time the milestone
closed; rewriting would falsify the audit trail);
[`.orchestrator/milestones/M035/M035-ROADMAP.md`](../../../../../milestones/M035/M035-ROADMAP.md) (narrative documenting
the rename, preserves both old and new forms in prose per T02 step 2);
`.orchestrator/milestones/M035/phases/P01.5/{P01.5-PLAN.md,
tasks/T02-spec-dir-rename-PLAN.md, tasks/T03-operator-paths-PLAN.md,
tasks/T04-c1-lowercase-hyphenated-PLAN.md}` (P01.5 narrative plans
documenting the rename — analogous in nature to the explicitly
excluded `P01.5-PLANNING-PAYLOAD.md` from T02 step 5's exclusion
regex); `.planning/speckit-orchestrator-playbook.md` (operator
playbook, basename and content addressed by T03 / T04).

**Verifier `tools/verify/m035-p015-spec-dir-rename.sh`** asserts five
properties: (1) `specs/001-orchestrator/` exists as a directory; (2)
`specs/001-speckit-orchestrator/` does NOT exist; (3) the sentinel
`specs/001-orchestrator/spec.md` is present; (4) `git log --follow`
on the sentinel returns at least one commit hash (history preservation
through the rename); (5) the 10 swept non-historical files contain
zero matches for `specs/001-speckit-orchestrator`. Single-script-file
shape per AD-19; no compound chains (CON-3 / AP-009).

The verifier is intentionally run *after* the commit. `git log
--follow` requires the new path to exist as a committed entity to
trace pre-rename history; pre-commit invocation returns empty (the
new path is not yet in any tree). T02 commits then verifies.

**Reversibility:** `git revert <T02-commit-sha>` reverses both the
rename and the content sweep in a single operation per CON-4.

Verification (verbatim PASS line):

```
PASS: m035-p015-spec-dir-rename
```
