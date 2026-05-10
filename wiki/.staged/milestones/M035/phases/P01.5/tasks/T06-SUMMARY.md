---
schema_version: "1.0"
type: task-summary
id: "T06"
parent: "P01.5"
milestone: "M035"
provides:
  - "C5 cohort-finish across 4 operational template surfaces -- templates/claude-settings.json line 56 Skill(speckit.orchestrator.*) -> Skill(orchestrator:*) + line 64 Bash(bash spec-kit-orchestrator/scripts/*) -> Bash(bash orchestrator/scripts/*); templates/autonomy-defaults.yaml line 91 Skill(speckit.orchestrator.*) -> Skill(orchestrator:*); templates/instruction-schema.md line 140 schema-skeleton heading speckit.orchestrator.<command> -> orchestrator:<command> + appended historical-reference framing paragraph after the code fence; templates/compression-tier3-prompt.md lines 14 and 45 reframe legacy speckit.orchestrator.* namespaced-alias mention as historical/migration-only documentation reference; tools/verify/m035-p015-c5-cohort-finish.sh task-grain verifier (single-script AD-19 shape, exit-zero PASS contract, JSON+YAML validity preserved)"
requires:
  - "from:M035/P01.5/T01 what:legacy-namespace-allowlist.txt + D-RN-1..D-RN-7 decisions block (these 4 templates are NOT on the allowlist; T06 finishes them); from:references/RENAME-PLAN.md section 5 Commit 5 (cohort-finish runbook); from:M035/M035-ROADMAP.md P01.5 Boundary Map lines 33-34 (file enumeration)"
affects:
  - "P01.5/T08"
key_files:
  - "templates/claude-settings.json,templates/autonomy-defaults.yaml,templates/instruction-schema.md,templates/compression-tier3-prompt.md,tools/verify/m035-p015-c5-cohort-finish.sh"
key_decisions:
  - "D-RN-3 cohort prefix is orchestrator:<cmd>; D-RN-5 path-shape spec-kit-orchestrator/* -> orchestrator/*; C5 prose-reframe contract (active form is new identifier; legacy form is named as documented historical reference, NOT as a live registration surface); JSON+YAML validity invariant (each edit confined to within string-value bytes, no quoting/comma/array-syntax mutation); single-Edit-call-per-file shape per CON-3 (AP-009-shape-guard-honored); instruction-schema.md historical-framing landed as a paragraph after the closing code fence rather than inside the schema-skeleton example (preserves clean-example-block contract while satisfying C5 historical-reference framing)"
patterns_established:
  - "dotted-namespace-to-colon-prefix-glob-rename (Skill(speckit.orchestrator.*) -> Skill(orchestrator:*) preserves the surrounding allowed-skills array shape and is byte-localized to the string value); path-shape-rename-inside-bash-permission-glob (Bash(bash spec-kit-orchestrator/scripts/*) -> Bash(bash orchestrator/scripts/*) is the C1+C5 hybrid surface closed in the same template-pass commit); prose-reframe-with-historical-anchor (when a code-fenced example carries the legacy form as the active identifier, replace the active form in-fence and append a post-fence paragraph that names the legacy form as documented historical reference -- preserves clean schema-skeleton example while satisfying SC-7 historical-framing rule); inline-prose-reframe-with-explicit-historical-clause (compression-tier3-prompt.md preserves-list and prose enumeration rewritten so colon/slash forms are the active surface and the namespaced-alias form is bracketed by an explicit 'appears only in pre-M035 historical and migration documentation' clause); verifier-shape-asymmetric-for-operational-vs-prose (operational surfaces assert ZERO speckit.orchestrator matches AND new-form presence; prose surfaces assert only new-form presence -- legacy form may appear inside historical-framing prose, which the verifier intentionally does not enforce-by-content); JSON+YAML-validity-as-implicit-precondition (post-edit python3 -c 'import json/yaml; load(...)' both pass without error)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P01.5/tasks/T06-c5-cohort-finish-PAYLOAD.md, references/RENAME-PLAN.md (section 5 Commit 5), tools/verify/m035-p015-c5-cohort-finish.sh"
duration: "15m"
verification_result: "pass"
completed_at: "2026-05-08T17:22:13Z"
---

T06 closes the C5 cohort-finish surface from RENAME-PLAN.md section 5 Commit 5: the 4 operational template files explicitly enumerated in the M035 P01.5 Boundary Map (lines 33-34) that the prior in-tree rename passes (M008/[M015](../../../../../milestones/M015/index.md) era + T04 C1 sweep + T05 C2/C3 prose sweep) deferred by design. These 4 files are NOT on the legacy-namespace-allowlist authored by T01; T06 finishes them and unblocks the SC-7 cohort gate at T08.

**Operational-surface edits (zero-tolerance, no historical exception):**
templates/claude-settings.json line 56 'Skill(speckit.orchestrator.*)' -> 'Skill(orchestrator:*)'; line 64 'Bash(bash spec-kit-orchestrator/scripts/*)' -> 'Bash(bash orchestrator/scripts/*)'. The first edit changes the cohort-glob shape from dotted-namespace to colon-prefix per [D-RN-3](../../../../../decisions.md#d-rn-3-command-cohort-prefix-orchestratorcmd-dr-code-031 "Command-cohort prefix `orchestrator:<cmd>` { #dr-code-031 }"); the second is a C1+C5 hybrid surface (path token + skill-glob shape) closed in the same template-pass commit. JSON validity preserved: both edits confined to within '"..."' string-value bytes; surrounding array syntax, trailing commas, and quoting are unaffected (python3 -c 'import json; json.load(...)' passes post-edit).

templates/autonomy-defaults.yaml line 91 '- "Skill(speckit.orchestrator.*)"' -> '- "Skill(orchestrator:*)"'. YAML list-element quoting and indentation preserved (python3 -c 'import yaml; yaml.safe_load(...)' passes post-edit).

**Prose-surface reframes (legacy form retained as historical reference per C5 contract):**
templates/instruction-schema.md line 140 (inside the Schema Skeleton fenced markdown example): heading replaced from '# speckit.orchestrator.<command>' to '# orchestrator:<command>'. To carry the historical-reference framing demanded by SC-7, a new paragraph was appended *after* the closing code fence (not inside the example) clarifying that the legacy '# speckit.orchestrator.<command>' shape is preserved in historical and migration documentation only and is NOT a live registration surface post-M035 P01.5. This pattern (in-fence active form + post-fence historical paragraph) preserves the clean-example contract of the Schema Skeleton block while satisfying the C5 framing rule.

templates/compression-tier3-prompt.md lines 14 and 45 rewritten to drop the namespaced-alias from the live-form enumeration and explicitly bracket it with an 'appears only in pre-M035 historical and migration documentation' clause. The compressor still preserves the token verbatim if it appears in such material -- this matters because the preserves-list contract is byte-level and downstream historical-doc payloads may still carry the legacy form.

**Verifier (tools/verify/m035-p015-c5-cohort-finish.sh, single-script AD-19 shape):**
asymmetric contract by file class. Operational files (JSON + YAML): ZERO grep matches for 'speckit\.orchestrator' AND 'Skill(orchestrator:' must be present. Prose files (instruction-schema.md + compression-tier3-prompt.md): only assert the new 'orchestrator:' form is present; legacy mentions inside historical-framing prose are intentionally not enforced by content. Plus the line-64 path-shape check: zero matches for 'Bash(bash spec-kit-orchestrator/scripts/\*)' in claude-settings.json. CON-3 honored: each file edit was a separate Edit tool call, no xargs sed. AP-009 shape-guard not triggered.

**Verification (verbatim PASS line):**

```
PASS: m035-p015-c5-cohort-finish
```

**Reversibility:** `git revert <T06-commit-sha>` reverses all 4 file edits and the new verifier in a single operation per CON-4.
