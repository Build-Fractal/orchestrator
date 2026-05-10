---
schema_version: "1.0"
type: task-summary
id: "T05"
parent: "P03"
milestone: "M014"
provides:
  - "comments: section in .orchestrator/config.yml (auto_apply_threshold per-class scalars, reply_on_apply: false, fetch_schedule: manual)|references/spec-management.md ## Comment Classification & Workflow Routing section (FR-9 v1 ruleset, threshold table, CON-5/SC-5 spec-amendment human-gate language, D023 retune trigger, FR-19 dry-run manifest)|six new verifiers (config-keys, references-section, bash32-and-lint omnibus, zero-prompts, dogfood-capture, phase-suite orchestrator)|CLAUDE.md + AGENTS.md Recent Changes M014/P03 entry via dual-write helper|14-gate phase suite emits 'SUMMARY: m014-p03-phase-suite.sh pass=14 fail=0'"
requires:
  - "from:T01 what:scripts/comments/fetch.sh + actioned.jsonl idempotency log|from:T02 what:scripts/comments/classify.sh single-line verdict + dogfood-data file at specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md|from:T03 what:commands/comments.md + apply/reject/triage primitives + SC-5 human-gate verifier|from:T04 what:scripts/comments/comments.sh master pipeline + pipeline/auto-apply/observability verifiers|from:M014/P01 what:scripts/util/dual-write-runtime-md.sh marker-bounded helper (FR-12 SC-6a outside-bytes invariant)|from:M021 what:tests/fixtures/m021-prompt-corpus.txt prompt-shape regression corpus"
affects:
  - "closes M014/P03 (FR-17 SC-9 SC-11 CON-3 CON-6)|enables phase-verify + phase-transition next|extends references/spec-management.md without violating P04 byte-preservation invariant|adds reusable patterns: (1) bash32+lint omnibus self-exemption via comment-stripping, (2) zero-prompts hermetic-scratch-with-fixture under classify --yes, (3) outside-marker shasum invariant pre/post dual-write, (4) phase-suite orchestrator with IFS-newline gate iteration"
key_files:
  - ".orchestrator/config.yml|references/spec-management.md|scripts/verify/m014-p03-config-keys.sh|scripts/verify/m014-p03-references-section.sh|scripts/verify/m014-p03-bash32-and-lint.sh|scripts/verify/m014-p03-zero-prompts.sh|scripts/verify/m014-p03-dogfood-capture.sh|scripts/verify/m014-p03-phase-suite.sh|CLAUDE.md|AGENTS.md"
key_decisions:
  - "config.yml comments: section appended after specify: section, additive — existing keys byte-preserved (verified via Edit-tool surgical insert)|references/spec-management.md new section appended after final P04 section (--amend Three-Case Semantics SC-14 invariant block) — every prior P04 heading and cross-reference still grep-asserted by m014-p03-references-section.sh as a byte-preservation proxy|bash32+lint omnibus enumerates target scripts dynamically (scripts/comments/*.sh + scripts/verify/m014-p03-*.sh excluding self) rather than via static list — picks up future verifiers automatically without omnibus edit|zero-prompts gate runs the four-class T04 fixture under hermetic ORCHESTRATOR_PROJECT_ROOT + GH_API_STUB to exercise the full classify --yes path including auto-apply + queue + triage routes (not just the entry point) — catches prompt leaks from any sub-script|phase-suite uses IFS-newline gate iteration with explicit IFS reset (precedent: m026-p03-phase-suite.sh) — Bash 3.2 portable replacement for arrays|dual-write --append-entry path leaves outside-marker bytes byte-identical (shasum confirmed pre=post for both CLAUDE.md and AGENTS.md) — uncommitted M026-close entry already in RC region is preserved untouched, only the new M014/P03 line prepends"
patterns_established:
  - "bash32+lint omnibus dynamic enumeration with self-exemption (scans scripts/comments/*.sh + scripts/verify/m014-p03-*.sh dynamically, strips full-line comments before regex scan, skips self by basename match) — reusable verifier shape for any future phase-close|zero-prompts hermetic scratch + fixture replay under --yes (mktemp scratch root + GH_API_STUB pointing at four-class fixture + COMMENTS_ADAPTER pointing at non-existent path → exercises auto-apply, queue, triage paths in one classify invocation, captures stdout+stderr, greps against M021 INPUT corpus + interactive-prompt regex) — pattern for SC-7 retest at any pipeline seam|outside-marker shasum invariant pre/post dual-write (awk-strip marker region → shasum stdin both before and after the helper write → assert equality) — formal verification of the SC-6a outside-bytes guarantee from M014/P01 FR-12|phase-suite orchestrator with IFS-newline iteration + per-gate rc capture + FAILED_GATES diagnostic accumulator (precedent: m014-p04-phase-suite.sh, m026-p03-phase-suite.sh) — Bash 3.2-portable replacement for arrays, emits both per-gate PASS/FAIL line and SUMMARY: ... pass=N fail=M tally"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P03/tasks/T05-phase-close-PAYLOAD.md|.orchestrator/milestones/M014/phases/P03/tasks/T05-phase-close-PLAN.md|.orchestrator/milestones/M014/phases/P03/P03-PLAN.md|scripts/verify/m014-p03-phase-suite.sh|scripts/verify/m014-p03-config-keys.sh|scripts/verify/m014-p03-references-section.sh|scripts/verify/m014-p03-bash32-and-lint.sh|scripts/verify/m014-p03-zero-prompts.sh|scripts/verify/m014-p03-dogfood-capture.sh"
duration: "~25m"
verification_result: "pass"
completed_at: "2026-04-25T03:05:50Z"
---

M014/P03/T05 closes the phase. Six deliverables landed atomically:

1. .orchestrator/config.yml gains a comments: section with three required sub-keys (auto_apply_threshold per-class scalars, reply_on_apply: false, fetch_schedule: manual). Spec-amendment threshold pinned at 1.0 (CON-5/SC-5 invariant — never auto-applies regardless). Existing specify: section + every other top-level key byte-preserved.

2. references/spec-management.md gains a ## Comment Classification & Workflow Routing section appended after the P04 --amend Three-Case Semantics block. Section documents the FR-9 regex/heuristic v1 ruleset (R1-R10 per D023), per-class confidence-score derivation, the auto-apply threshold table, the spec-amendment human-gate invariant, the D023 retune trigger contract (>=30 actioned comments OR >=20% calibration divergence), and the FR-19 dry-run manifest shape. P04 sections remain byte-preserved — m014-p03-references-section.sh asserts every prior heading and key cross-reference (hardening_spec_exception, CALIBRATION-MEMO.md, spec-pressure-test.yml, decomposition-manifest, SC-14) still present.

3. Six new verifiers under scripts/verify/m014-p03-*.sh:
   - config-keys: greps the comments: section + every required sub-key + the CON-5/SC-5 spec-amendment 1.0 pin + reply_on_apply: false + fetch_schedule: manual defaults
   - references-section: heading present, P04 sections byte-preserved, FR-9 v1 + D023 + threshold table rows + spec-amendment human-gate language present
   - bash32-and-lint: omnibus dynamically enumerates scripts/comments/*.sh + scripts/verify/m014-p03-*.sh (excluding self), strips full-line comments, scans for forbidden Bash 4+ tokens, runs anti-pattern-lint.sh against each — clean across 20 scripts
   - zero-prompts: invokes comments.sh classify --yes under hermetic scratch with the four-class T04 fixture and a non-existent COMMENTS_ADAPTER, captures stdout+stderr, asserts zero matches against the [M021](../../../../milestones/M021/index.md) prompt-corpus INPUT lines + an interactive-prompt regex (\(y/n\), \[y/N\], read -p, etc.)
   - dogfood-capture: asserts inbox-dogfood.md exists with the six required sections (Status, Snapshot, Per-class counts, FR-9 shape pinned, Retune trigger, Cross-references), names all four classes, cites D023, names both volume + calibration triggers
   - phase-suite: orchestrator over all 14 P03 gates in declared order — emits SUMMARY: m014-p03-phase-suite.sh pass=14 fail=0 + PASS line on all-green; per-gate FAIL diagnostic + non-zero exit on any failure

4. CLAUDE.md + AGENTS.md Recent Changes regions both gained an M014/P03 entry via scripts/util/dual-write-runtime-md.sh --append-entry. The pre-existing uncommitted M026-close line (added by some prior consolidate) is preserved underneath the new entry. SC-6a outside-marker invariant verified mechanically: shasum of bytes outside the marker region is byte-identical pre/post on both CLAUDE.md and AGENTS.md.

5. Phase suite final output:
   PASS: m014-p03-fetch.sh
   PASS: m014-p03-classify.sh
   PASS: m014-p03-commands-md.sh
   PASS: m014-p03-apply.sh
   PASS: m014-p03-reject-triage.sh
   PASS: m014-p03-spec-amendment-human-gate.sh
   PASS: m014-p03-pipeline.sh
   PASS: m014-p03-auto-apply.sh
   PASS: m014-p03-observability.sh
   PASS: m014-p03-config-keys.sh
   PASS: m014-p03-references-section.sh
   PASS: m014-p03-dogfood-capture.sh
   PASS: m014-p03-bash32-and-lint.sh
   PASS: m014-p03-zero-prompts.sh
   ----
   SUMMARY: m014-p03-phase-suite.sh pass=14 fail=0
   PASS: m014-p03-phase-suite.sh

Constraints honored: Bash 3.2 (no ${var,,}, no mapfile, no declare -A, no &>, no process substitution), AD-19 single-script-file Check shapes, D007 conversus adapter untouched, shasum -a 256 portable, bash32+lint omnibus self-exempts via full-line comment-stripping (precedent: M014/P01/T07, M014/P02/T06, M014/P04/T07), zero-prompts verifier self-exempts its own regex-pattern-line content by virtue of those lines never being read into the captured ALL_OUT subprocess output (no runtime exemption logic needed). Idempotent: re-running T05 against an already-edited config / references / RC region is a no-op (grep-based checks pass; --append-entry prepends but does not duplicate identical lines on second run; outside-marker shasum invariant holds).

Ready for phase verify + phase transition. Operator drives phase-transition.sh next.
