---
schema_version: "1.0"
type: task-summary
id: "T07"
parent: "P01.5"
milestone: "M035"
provides:
  - "C4 per-line judgment classification across the standalone spec-kit residue surface (982 lines after exclusions); .orchestrator/milestones/M035/phases/P01.5/c4-classification.txt classification log with file:line:verdict:rationale shape (1 C4-rename, 981 UPSTREAM, 0 REVIEW); references/installation.md:271 npm-scope rewrite from @spec-kit/orchestrator (placeholder) to @build-fractal/orchestrator (per D-RN-1 binding resolution); tools/verify/m035-p015-c4-classification.sh task-grain verifier (single-script AD-19 shape, asserts log existence + zero REVIEW + every C4-rename verdict has had its standalone spec-kit token rewritten)"
requires:
  - "from:M035/P01.5/T01 what:legacy-namespace-allowlist.txt + D-RN-1..D-RN-7 decisions block (T07 inventory excludes the allowlist; T07 honors D-RN-1 npm scope choice in the rewrite); from:M035/P01.5/T02..T06 what:cumulative compound-form rename state (T07 surface is the standalone residue after compound forms cleaned); from:references/RENAME-PLAN.md sections 3-4 (C4 mapping table line 52 + classification protocol)"
affects:
  - "P01.5/T08"
key_files:
  - ".orchestrator/milestones/M035/phases/P01.5/c4-classification.txt,references/installation.md,tools/verify/m035-p015-c4-classification.sh"
key_decisions:
  - "D-RN-1 npm scope @build-fractal/orchestrator (DECISIONS.md DR-CODE-029) is the binding resolution that supersedes M035-CONTEXT.md OQ #Q-1 placeholder @spec-kit/orchestrator; default-UPSTREAM verdict for the C4 surface is the correct posture (T01..T06 already rewrote every short-form reference that meant *this* project; the residue overwhelmingly references the upstream framework as migration source / format contract / historical context per RENAME-PLAN line 52); pre-decision authoring docs (M035-CONTEXT.md and .orchestrator/proposals/M035-packaging-distribution.md) retain @spec-kit/orchestrator as historical record of the pre-decision OQ state -- DECISIONS.md is the authoritative record of the resolution per project proposal-lifecycle convention; BSD-grep \\b boundary-anchor adjustment from the payload-suggested pattern (BSD/macOS grep -E does NOT honor \\b inside character class boundaries with hyphen; replaced \\bspec-kit\\b|\\bspec kit\\b with bare spec-kit|spec kit and relied on compound-form exclusions to filter the project-bound references); conversus path exclusion regex fix (payload had ^(...|specs/001-orchestrator/conversus-): which matched only paths ending exactly conversus-:, missing the deliberation tree; rebuilt as a separate path-prefix grep -vE branch)"
patterns_established:
  - "per-line-judgment-classification-with-default-verdict-by-rationale-bucket (when the surface is large and the rationale is one-of-N categorical buckets, classify by file-cohort with a default verdict and enumerate explicit exceptions; emit one log line per match for audit-trail completeness; the per-line discipline is the safety mechanism but the verdict assignment can be by-cohort); BSD-grep-boundary-anchor-replacement (BSD grep -E does not honor \\b in many contexts; rebuild patterns to use compound-form exclusions instead of \\bword\\b anchors); decision-supersedes-placeholder pattern (when DECISIONS.md resolves an OQ that earlier authoring docs cited as placeholder, rewrite live operator-facing docs to the resolved value; preserve pre-decision proposal docs as historical record); REVIEW-as-HALT-escape-hatch (T07 ships zero REVIEW verdicts; the HALT discipline is the operator escape hatch for ambiguous cases but is not exercised when the surface decomposes cleanly); classification-log-as-load-bearing-artifact (the .txt log is the consolidate-time audit trail; the verifier asserts log shape and post-rewrite state, both via grep)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P01.5/tasks/T07-c4-classification-PAYLOAD.md, .orchestrator/milestones/M035/phases/P01.5/c4-classification.txt, references/RENAME-PLAN.md (sections 3-4), tools/verify/m035-p015-c4-classification.sh, .orchestrator/DECISIONS.md (D-RN-1 DR-CODE-029)"
duration: "35m"
verification_result: "pass"
completed_at: "2026-05-08T17:29:32Z"
---

T07 closes the C4 per-line judgment surface from RENAME-PLAN.md sections 3-4: the standalone spec-kit residue that survived T01..T06 compound-form sweeps. The cumulative state at task entry was that every match for spec-kit-orchestrator, Spec-Kit Orchestrator, spec-kit orchestrator, and speckit.orchestrator had been resolved across the operational surfaces; T07 picks up the bare spec-kit token and judges each occurrence as either C4-rename (refers to *this* project under the old name; rewrite to orchestrator), UPSTREAM (refers to the upstream spec-kit framework that this project migrated FROM; preserve), or REVIEW (context unclear; HALT for operator).

**Inventory shape (BSD-grep correction):**
The payload-supplied pattern \\bspec-kit\\b|\\bspec kit\\b returned 0 matches under BSD/macOS grep -E (which does not honor \\b in many contexts when the surrounding character is a hyphen). Rebuilt as bare spec-kit|spec kit with reliance on compound-form grep -vE exclusions. Also fixed the conversus-tree path exclusion (payload regex ^(...|specs/001-orchestrator/conversus-): only matched paths ending exactly conversus-:, missing the deliberation tree -- moved to a separate path-prefix exclusion branch). After exclusions (compound forms, legacy-namespace allowlist, [M008](../../../../../milestones/M008/index.md) archive, conversus-deliberation tree, M0##-SUMMARY/M0##-BODY historical milestone records, RENAME-PLAN/DECISIONS/KNOWLEDGE/CHANGELOG, this phase own files), the C4 surface is 982 lines across approximately 80 files.

**Classification verdicts:**
- 1 C4-rename: references/installation.md:271 -- live operator-facing doc that read "npm install -g @spec-kit/orchestrator" as a forward-looking placeholder. [D-RN-1](../../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }") (DECISIONS.md DR-CODE-029, recorded at this same phase by T01) settled the npm scope as @build-fractal/orchestrator. The user-facing doc must align with the resolution. Rewrite applied via single Edit per CON-3.
- 981 UPSTREAM: the residue overwhelmingly references the upstream spec-kit framework as migration source (scripts/migrate/adapters/speckit.sh, scripts/dispatch/adapters/format/speckit.sh, tests/fixtures/m015-p04-speckit-migration/), format contract (specs/024-spec-management-extended/spec.md describes spec-kit /speckit.specify shape as the I/O contract), historical context (.orchestrator/milestones/M0##/, .orchestrator/archive/handoffs/, .planning/research/), or open-questions placeholder (M035-CONTEXT.md OQ #Q-1, [.orchestrator/proposals/M035-packaging-distribution.md](../../../../../proposals/M035-packaging-distribution.md)). Per the project proposal-lifecycle convention, proposal docs accumulate findings; DECISIONS.md is the authoritative record of resolutions. Pre-decision authoring docs preserve their original placeholder text (e.g., @spec-kit/orchestrator) as historical audit trail.
- 0 REVIEW: the surface decomposes cleanly into the two cohorts above. The HALT escape hatch was available but not required.

**Verifier (tools/verify/m035-p015-c4-classification.sh, single-script AD-19 shape):**
Asserts (1) c4-classification.txt exists, (2) zero REVIEW verdicts (operator resolved them all -- in this case, the resolution was zero-from-the-start), (3) every C4-rename verdict line corresponds to a no-longer-present standalone spec-kit token in its named file (i.e., the rewrite was applied; checked by reading the recorded line, stripping compound forms, and asserting no residual spec-kit token remains). PASS contract is the verbatim string PASS: m035-p015-c4-classification.

**Verification (verbatim PASS line):**

```
PASS: m035-p015-c4-classification
```

**Reversibility:** git revert <T07-commit-sha> reverses the references/installation.md:271 rewrite and the new classification log + verifier in a single operation per CON-4. The classification log is preserved on disk as a permanent audit artifact; T08 acceptance battery and the M035 P01.5 phase summary reference it.
