---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M028"
milestone: "M028"
provides:
  - "classifier-replay audit covering all 9 M028 source events (Findings A-G); per-event classifier verdict captured verbatim from M021 shape-classifier.sh git SHA 12fcd98; replay-coverage verifier,canonical M028 pre-repair fixture (sanitized operator M018-close ~/.claude/settings.json backup) at tests/fixtures/m028-pre-repair-snapshot.json; deterministic sanitizer scripts/verify/m028/p01-fixture-sanitize.sh; must-have verifier scripts/verify/m028/p01-fixture-sanitized.sh,P01-VERIFICATION.md collapse-decision evidence document at .orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md (per-screenshot causal trace for SE-01 through SE-09,explicit collapse_decision frontmatter field,corpus staging list consumed by P03); shape verifier scripts/verify/m028/p01-collapse-decision-recorded.sh (AD-19 single-script-file,bash 3.2 + POSIX-sh-safe,asserts frontmatter and section headings and Resolved-by-Finding-A-alone YES/NO discipline)"
requires:
  - "none"
affects:
  - "P02"
key_files:
  - ".orchestrator/milestones/M028/phases/P01/classifier-audit.md;scripts/verify/m028/p01-replay-coverage.sh;scripts/verify/m028/p01-classify-one.sh,tests/fixtures/m028-pre-repair-snapshot.json;scripts/verify/m028/p01-fixture-sanitize.sh;scripts/verify/m028/p01-fixture-sanitized.sh,.orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md;scripts/verify/m028/p01-collapse-decision-recorded.sh"
key_decisions:
  - "9 source events enumerated (SE-01 Finding A non-firing,SE-02..SE-05 Finding B four shapes,SE-06 Finding C,SE-07 Finding D,SE-08 Finding F adapter+installer non-Bash,SE-09 Finding G); SE-06 and SE-09 already reject under M021 as compound-chain-gt2 (AP-009); SE-02..SE-05 and SE-07 currently classify as allow (the gap M028 closes via AP-010..AP-014); SE-01 + SE-08 are non-classifier events (portability + adapter-emission),partial-flag fixture shape (5 unflagged + 1 flagged Stop entries; 7 unflagged + 1 flagged PreToolUse Bash entries) preserves Finding F regression evidence while satisfying _orchestrator_managed anchor must-have; token-redaction regex restricted to a 32+ char alphanumeric (plus underscore and hyphen) class drops + / = from char class to prevent path-segment false positives; sanitization implemented in two stages -- sed for path/email/token bytes,python3 for structural flag injection -- both deterministic,collapse_decision=full-5-phase based on M=0 of N=7 (threshold 6 not met); SE-01 contributes to A but is NOT resolved-by-A-alone because its in-family commands SE-02..SE-05 all yield existing verdict allow (hook portability alone does not eliminate the in-the-wild failures); SE-09 attributed to G not A despite running on the orchestrator repo itself because the in-tree event proves hook portability is irrelevant to the body-descent bypass surface; corpus staging count is 5 (one per reserved AP-ID) with the FR-13 reconciliation to 7 explicitly delegated to P03 per the rubric in the task plan"
patterns_established:
  - "staged-probe replay shape: write probe under tmp/<milestone>-<phase>/ then invoke via scripts/util/run-probe.sh,source the classifier and call classify_command verbatim,capture stdout byte-exact for the audit's fenced verdict block; throwaway shim under scripts/verify/<milestone>/p01-classify-one.sh as AD-19 single-script-file flat shape,two-stage deterministic sanitization (BSD-portable sed -E for byte-level redactions then python3 json mutation for structural injection); partial-flag fixture realism (mixing pre-M025 unflagged residue with post-M025 flagged entries reflects real downstream user systems); separate -sanitize (transformer,runs once at fixture creation) and -sanitized (verifier,runs at every phase verification) script naming,rubric-driven attribution (verdict + shape + path-prefix triggers map mechanically to Findings A through G; reproducible from classifier-audit.md alone); shape-only verifier discipline (the verifier asserts frontmatter and section headings and per-line YES/NO tokens,never the M/N arithmetic values themselves -- the document body shows the math); corpus-staging delegation pattern (T03 lands the AP-anchored entries derivable from per-screenshot evidence,P03 owns regression and boundary-case padding to the FR-13 target)"
drill_down_paths:
  - ".orchestrator/milestones/M028/phases/P01/tasks/T01-classifier-replay-audit-SUMMARY.md, .orchestrator/milestones/M028/phases/P01/tasks/T02-fixture-snapshot-SUMMARY.md, .orchestrator/milestones/M028/phases/P01/tasks/T03-collapse-decision-evidence-SUMMARY.md"
duration: "120m"
verification_result: "pass"
completed_at: "2026-04-29T14:18:48Z"
observability_surfaces:
  - "none"
---

P01 closes the M028 input audit and pins the collapse decision: **`full-5-phase`** (P02–P05 stay as-roadmapped). The phase produced three deliverable rounds plus the canonical pre-repair fixture and the verifier triad that downstream phases consume.

## What was built

- **T01 — classifier replay audit** (`classifier-audit.md`, 211 lines, 9 source events). Every M028 source event (Findings A–G plus the operator-reported Stop-hook event) replayed verbatim through the M021 shape classifier (`scripts/verify/lib/shape-classifier.sh` git SHA `12fcd98`). Per-event verdict captured byte-exact in fenced blocks. Two SEs already reject under M021 as `compound-chain-gt2` anchored on AP-009 (SE-06 Finding C, SE-09 Finding G); four SEs classify as `allow` (SE-02..SE-05 Finding B), confirming the spec's gap narration that AP-010..AP-013 close real shapes; SE-07 Finding D classifies as `allow` (destructive-op prompting is shape-independent at the CC layer); SE-01 + SE-08 are non-classifier events (portability + adapter-emission). Replay-coverage verifier `scripts/verify/m028/p01-replay-coverage.sh` PASS.

- **T02 — pre-repair fixture snapshot** (`tests/fixtures/m028-pre-repair-snapshot.json`, 173 lines). Operator's M018-close `~/.claude/settings.json.bak` captured and sanitized: `/Users/brettkellgren/`, the standalone `brettkellgren` token, the operator email, and 32+ char alphanumeric token-like runs all redacted via BSD-portable `sed -E`; `python3` then appended one `_orchestrator_managed: true` entry per `Stop` and `PreToolUse` array. Partial-flag shape preserved (5 unflagged + 1 flagged Stop entries; 7 unflagged + 1 flagged PreToolUse Bash entries) — models the realistic post-M025 mixed-state P02 `--repair` will encounter. Char class deliberately excludes `+ / =` to prevent path-segment false positives. Sanitization is deterministic (double-run byte-identity diff). Two scripts: `p01-fixture-sanitize.sh` (one-shot transformer) + `p01-fixture-sanitized.sh` (must-have verifier). Both PASS.

- **T03 — collapse-decision evidence** (`P01-VERIFICATION.md`, 165 lines, frontmatter `collapse_decision: "full-5-phase"`). Per-screenshot causal trace for SE-01..SE-09; collapse-decision arithmetic M=0 of N=7 (threshold M≥N−1=6 not met); 5-entry corpus staging list with FR-13-to-7 padding delegated to P03. Reasoning summary: hook portability resolves zero events because the four B-family screenshots all carry existing-classifier verdict `allow` (the classifier under-matches regardless of where the hook fires); SE-07 and SE-06 are wrapper-class remediations independent of portability; SE-09 was observed in-tree on the orchestrator repo itself, proving portability is irrelevant to the body-descent bypass surface AP-014 closes. Shape verifier `p01-collapse-decision-recorded.sh` PASS.

## Verification

- Tier 1 (`check-must-haves.sh`): **22/22 PASS** — 3 truths (all carrying `Check:` sub-items), 12 artifact assertions, 2 key-link cross-references, 5 file-presence checks.
- Tier 1 (`check-boundary-map.sh`): SKIP (P01 has no boundary-map produce items).
- Tier 2 (`run-commands.sh`): SKIP (no project-level verification commands configured).
- Tier 3 (behavioral truths): N/A — all P01 truths carry `Check:` sub-items, fully covered at Tier 1.
- Tier 4 (human review): not gated for this phase.

## Patterns established

- **Staged-probe replay shape**: write probe under `tmp/<milestone>-<phase>/`, invoke via `scripts/util/run-probe.sh`, source the classifier and call `classify_command` verbatim, capture stdout byte-exact for the audit's fenced verdict block. Throwaway shim under `scripts/verify/<milestone>/p01-classify-one.sh` as AD-19 single-script-file flat shape.
- **Two-stage deterministic sanitization**: BSD-portable `sed -E` for byte-level redactions (paths, emails, tokens) → `python3` for structural JSON mutation (flag injection). Both stages deterministic, double-run byte-identity verified.
- **Partial-flag fixture realism**: mix pre-M025 unflagged residue with post-M025 flagged entries — models the real downstream user state P02 `--repair` will encounter, not the empty-or-fully-tagged synthetic case.
- **Separate `-sanitize` vs `-sanitized` scripts**: transformer runs once at fixture creation; verifier runs at every phase verification. Naming makes the role unambiguous.
- **Rubric-driven attribution**: verdict + shape + path-prefix triggers map mechanically to Findings A–G, reproducible from `classifier-audit.md` alone.
- **Shape-only verifier discipline**: the verifier asserts frontmatter and section headings and per-line YES/NO tokens, never the M/N arithmetic values themselves — the document body shows the math, the verifier proves the document shape.
- **Corpus-staging delegation**: T03 lands the AP-anchored entries derivable from per-screenshot evidence; P03 owns regression and boundary-case padding to the FR-13 target of 7 entries.

## Dogfood findings

- **auto-loop `--step=V` eval'd `Expected output:` example fences as commands.** First run of T01 verification reported false `AUTO:VERIFY_FAIL` because the parser eval'd `PASS: ...` example output as a literal shell command. Two-layer fix landed in commit `73effdc`: (a) parser-side defensive skip in `scripts/lifecycle/auto-loop.sh:340-353` for verifier-verdict prefixes (`PASS:`, `FAIL:`, `WARN:`, `OK:`, `SKIP:`, `ERROR:`, `INFO:`, `EXPECT:`, `EXPECTED:`, `Expected:`, `Output:`, `Sample:`); (b) plan-author guidance in `commands/plan-phase.md:190` documenting "`## Verification` carries executable checks only; expected output goes in `## Notes`". Regression coverage: `tests/test-auto-loop-verify-extraction.sh` Test 3 + `tests/fixtures/.../T03-PLAN.md`. M028/P01/T01..T03 plans reshaped to match. CLAUDE.md hotfix-log entry captures the dogfood for future plan authors and parser-touchers.
- **Per-task commit discipline drift.** T01 committed its work; T02 did not (orchestrator stitched it up). T03 committed correctly after the dispatch prompt was made explicit. No long-term remediation needed at the phase level — the dispatch prompt convention now reminds agents to commit before writing the summary.

## Roadmap state

P02 (installer + adapter portability + install-side dedup) consumes the canonical fixture (T02 deliverable) and the AP-anchored corpus seed list (T03 staging). No roadmap deviation: the collapse-decision recommendation is `full-5-phase`, so no phase removal or reshaping is triggered. The decisions register requires no new entry — the audit and recommendation are documented in `P01-VERIFICATION.md` itself, which is the canonical evidence artifact per the M028 plan.
