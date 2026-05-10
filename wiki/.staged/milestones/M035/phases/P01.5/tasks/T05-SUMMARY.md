---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P01.5"
milestone: "M035"
provides:
  - "C2 (title-case Spec-Kit Orchestrator -> Orchestrator) + C3 (lowercase-spaced spec-kit orchestrator / spec kit orchestrator -> orchestrator) prose sweep complete across non-historical *.md files; commands/README.md:3 + .planning/research-prompt-speckit-orchestrator.md:1 rewrites; tools/verify/m035-p015-c2-c3-prose.sh task-grain verifier (single-script AD-19 shape, exit-zero PASS contract) with allowlist mirroring T04/C1 plus M035-ROADMAP.md/M035-CONTEXT.md (Boundary Map preserves rename mappings as literal source tokens)"
requires:
  - "from:M035/P01.5/T04 what:lowercase-hyphenated path/repo-basename sweep complete (zero spec-kit-orchestrator matches in non-historical *.md/*.yml/*.yaml)"
affects:
  - "P01.5/T07 (C4 classification log -- upstream spec-kit framework refs cross-validated against C2/C3 surface); P01.5/T08 (acceptance battery -- m035-p015-c2-c3-prose.sh folds into phase-suite aggregator)"
key_files:
  - "commands/README.md,.planning/research-prompt-speckit-orchestrator.md,tools/verify/m035-p015-c2-c3-prose.sh"
key_decisions:
  - "allowlist-extension-beyond-payload-step-5-regex (mirrors T04 pattern: M035-ROADMAP.md and M035-CONTEXT.md added because the Boundary Map enumerates rename mappings as literal source tokens that must be preserved verbatim to document the rename); upstream-spec-kit-deferred-to-T07 (any prose mentioning the upstream spec-kit framework is C4 territory and out of T05 scope -- T07 will cross-validate); regex-shape-corrected-from-payload-step-5 (payload step 5 verifier text trailed the allowlist alternation with a literal colon which would never match path-prefix entries like .orchestrator/milestones/M035/phases/P01.5/ -- T04 verifier shape (no trailing colon) adopted instead, identical semantics for file:line-prefix matching)"
patterns_established:
  - "allowlist-extension-mirrors-prior-task (C2/C3 prose sweep allowlist deliberately mirrors T04/C1 sweep allowlist plus the same M035-ROADMAP/M035-CONTEXT additions, so future C-category sweeps can copy-paste the allowlist with category-specific regex); meta-mapping-preservation (rename-runbook prose documenting old->new mappings as literal tokens is allowlisted not edited; the rename plan must remain readable post-rename); minimal-touch-prose-edit (only 2 prose edits required outside allowlist scope -- the C2/C3 surface had already been largely cleaned by T04 sweep over markdown files); verifier-grep-shape (git grep -niE pipe grep -vE shell pattern, identical to T04, AD-19 single-script-file Check shape, CON-3-honored no compound chains)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P01.5/tasks/T05-c2-c3-prose-PAYLOAD.md, .orchestrator/milestones/M035/phases/P01.5/tasks/T05-c2-c3-prose-PLAN.md, references/RENAME-PLAN.md (section 3 mapping table + section 5 Commit 4), tools/verify/m035-p015-c2-c3-prose.sh, tools/verify/m035-p015-c1-sweep.sh (T04 sibling allowlist pattern)"
duration: "12m"
verification_result: "pass"
completed_at: "2026-05-08T17:18:28Z"
---

T05 executes the C2 + C3 prose-sweep surface from RENAME-PLAN.md
section 3 mapping table + section 5 Commit 4 as a small, surgical change.
The pre-T05 inventory across *.md files yielded only 2 prose matches
outside the allowlist scope -- the bulk of historical hits were already
captured by T04 (which swept *.md/*.yml/*.yaml for the lowercase-hyphenated
spec-kit-orchestrator basename) or live in narrative-rename-doc paths the
allowlist already excludes.

**Prose edits (2 files, 2 lines):**

- commands/README.md:3 -- "Agent instruction documents for spec-kit
  orchestrator commands. Each file defines one orchestrator:* command..."
  -> "Agent instruction documents for orchestrator commands. Each file
  defines one orchestrator:* command...". C3 lowercase-spaced sentence
  flow preserved by deleting the "spec-kit " segment.

- .planning/research-prompt-speckit-orchestrator.md:1 -- "# Research
  Prompt: Spec-Kit Orchestrator Extension" -> "# Research Prompt:
  Orchestrator Extension". C2 title-case heading. The basename retains
  speckit-orchestrator (single-segment, not the C1 hyphenated pattern);
  basename rename is operator follow-up if/when the .planning/ scratchpad
  re-enters active scope.

**Allowlist (preserved as historical / runbook / narrative):**
references/RENAME-PLAN.md (the runbook documents the old prose forms);
docs/migrating-from-speckit.md (migration guide); .orchestrator/proposals/
papercut-sweep-pre-[M030](../../../../../milestones/M030/index.md).md (historical paper-cut log); .orchestrator/
milestones/M008/archive/ (archived milestone artifacts); .orchestrator/
milestones/M0[0-9][0-9]/M0[0-9][0-9]-{SUMMARY,BODY}.{md,txt} (closed
milestone summaries/bodies preserve historical project name);
CHANGELOG.md (version history headers); [.orchestrator/DECISIONS.md](../../../../../decisions.md)
(historical decisions); .orchestrator/milestones/M035/phases/P01.5/
(narrative plans documenting the rename itself); .orchestrator/
milestones/M035/M035-ROADMAP.md + M035-CONTEXT.md (Boundary Map
enumerates rename mappings as literal source tokens that must remain
verbatim post-rename); [.orchestrator/KNOWLEDGE.md](../../../../../knowledge.md) (consolidated knowledge
preserves historical project name); specs/001-orchestrator/conversus-*
(conversus subspec, separate scope); specs/039-packaging-distribution/
spec.md (live M035 spec preserves rename narrative).

**Upstream spec-kit framework references** (e.g., "originally migrated
from spec-kit", "spec-kits design pattern") were not encountered in the
T05 inventory pass -- these are C4 territory (T07) and will be cross-
validated by the T07 classification log against the broader spec-kit
surface.

**Verifier tools/verify/m035-p015-c2-c3-prose.sh** asserts a single
property: zero matches for "Spec-Kit Orchestrator" / "spec-kit
orchestrator" / "spec kit orchestrator" in *.md outside the allowlist
prefix set. Single-script-file shape per AD-19; no compound chains
(CON-3 / AP-009-shape-guard-honored). git grep + grep -vE pipeline is
exempt under the AP-009 wrapper-allowance for verifier scripts (same
pattern T04/C1 sweep verifier uses).

**Regex-shape note:** the payload step 5 verifier scaffold trailed the
allowlist alternation with ): (colon literal) which would only match
file paths whose final character is /, never matching real entries like
[.orchestrator/milestones/M035/phases/P01.5/tasks/T05-c2-c3-prose-PLAN.md](../../../../../milestones/M035/phases/P01.5/tasks/T05-c2-c3-prose-PLAN.md):
where the alternation prefix is followed by additional path segments
before the line-number colon. T04/C1 sweep verifier authored without
the trailing colon (correct for ^prefix matching against file:line:body
output) and T05 adopts that identical shape for consistency.

**Reversibility:** git revert <T05-commit-sha> reverses both prose edits
in a single operation per CON-4.

Verification (verbatim PASS line):

```
PASS: m035-p015-c2-c3-prose
```
