---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P03"
milestone: "M014"
provides:
  - "scripts/comments/comments.sh (master pipeline — classify/status/apply/reject/triage/reclassify subcommands, threshold-gated auto-apply for uat-bug+decision-append, human-queue for spec-amendment, conversus-strict ambiguous routing with adapter-missing→triage fallback)|scripts/verify/m014-p03-pipeline.sh (13 assertions — hermetic 4-comment fixture exercising every routing class + idempotency + deterministic shasum filenames + FR-16 unit_close + FR-10 comment_actioned)|scripts/verify/m014-p03-auto-apply.sh (4 cases — high-conf uat-bug auto-apply via stubbed M013 ingest, high-conf decision-append DECISIONS.md row, low-conf uat-bug below-threshold queue, high-conf spec-amendment SC-5 always-queue invariant)|scripts/verify/m014-p03-observability.sh (8 assertions — every FR-16 unit_close field present + integer-shaped + counter sanity, every FR-10 comment_actioned field present)"
requires:
  - "from:T01 what:scripts/comments/fetch.sh stub-aware fetcher (GH_API_STUB/GH_GRAPHQL_STUB) + actioned.jsonl idempotency log|from:T02 what:scripts/comments/classify.sh single-line verdict shape (class=<...> confidence=<0.0-1.0> reason=<short-id>) + ambiguous fallthrough at R10|from:T03 what:scripts/comments/{apply,reject,triage}.sh delegated sub-actions + review-queue/triage filename convention + actioned.jsonl action_taken field|from:M011 what:scripts/dispatch/adapters/tool/conversus.sh gate <preset> <input> <output> --strict interface (D007 reuse — adapter not modified)|from:M013 what:scripts/integrations/uat-ingest.sh best-effort entry-point (tolerated absent under hermetic test via COMMENTS_UAT_INGEST stub override)"
affects:
  - "T05 phase close (consumes the three T04 verifiers + the T03 SC-5 human-gate verifier in the phase suite)|M014 invariant SC-5/CON-5 (mechanically retested at the pipeline seam in m014-p03-pipeline.sh and m014-p03-auto-apply.sh case D, in addition to the source-level scan in m014-p03-spec-amendment-human-gate.sh)|orchestrator:comments user-facing surface — comments.sh is now the dispatch entry-point that the documented commands/comments.md describes"
key_files:
  - "scripts/comments/comments.sh|scripts/verify/m014-p03-pipeline.sh|scripts/verify/m014-p03-auto-apply.sh|scripts/verify/m014-p03-observability.sh"
key_decisions:
  - "env-overridable sub-script paths (COMMENTS_FETCH/COMMENTS_CLASSIFY/COMMENTS_ADAPTER/COMMENTS_UAT_INGEST/COMMENTS_APPLY/COMMENTS_REJECT/COMMENTS_TRIAGE) extends the T01-T03 ORCHESTRATOR_PROJECT_ROOT hermetic-test pattern to every fan-out point — lets verifiers stub the conversus adapter and the M013 UAT-ingest entry-point without modifying the real binaries (D007 reuse preservation)|adapter-missing as a routing verdict (not a failure) — non-executable COMMENTS_ADAPTER path lands ambiguous comments in human triage with conversus_verdict=adapter-missing diagnostic, mirroring the M013/FR-13 graceful-degradation contract at the comments seam|deterministic queue/triage filenames keyed on shasum-256(url)[:8] — lets idempotent re-runs overwrite-in-place rather than accumulate duplicates, asserted at the verifier seam by capturing pre/post filename sets across two runs|threshold default 0.8 read from comments.auto_apply_threshold.<class> in config.yml via awk YAML scalar walker (Bash 3.2 — no yq dependency); falls back to 0.8 default when key absent|spec-amendment auto-apply event scan added at the pipeline seam (belt-and-suspenders to the source-level scan in spec-amendment-human-gate.sh) — pipeline verifier asserts no comment_actioned row with class=spec-amendment AND action_taken=auto-apply-* ever lands in execution-log.jsonl, catching the runtime symptom even if the source scan ever drifts"
patterns_established:
  - "env-overridable sub-script-path hermetic-test pattern (COMMENTS_* env vars) extends ORCHESTRATOR_PROJECT_ROOT to fan-out targets — reusable for any future master-pipeline script that delegates to multiple sub-scripts|non-executable adapter as a triage routing verdict — pattern for testing graceful-degradation paths without stubbing the real adapter binary (D007 reuse)|deterministic content-addressed filenames (shasum-256[:8] of canonical input) for idempotent queue/triage entries — pattern for any append-mostly workflow that needs to be replayable|two-tier SC-5 invariant verification (source-level grep in spec-amendment-human-gate.sh + runtime-event-shape assertion in pipeline+auto-apply verifiers) — defense-in-depth pattern for must-not-happen invariants"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P03/tasks/T04-pipeline-PAYLOAD.md|.orchestrator/milestones/M014/phases/P03/tasks/T04-pipeline-PLAN.md|scripts/comments/comments.sh|scripts/verify/m014-p03-pipeline.sh|scripts/verify/m014-p03-auto-apply.sh|scripts/verify/m014-p03-observability.sh|scripts/verify/m014-p03-spec-amendment-human-gate.sh"
duration: "~30m (resumed session — two prior attempts hit API 529 mid-implementation; partial scripts/comments/comments.sh from attempt 2 was 408 lines and audit-passed plan-faithful, so resumption focused on building the three verifiers + SC-5 retest + summary)"
verification_result: "pass"
completed_at: "2026-04-25T02:50:05Z"
---

M014/P03/T04 wires the three T01–T03 primitives (fetch, classify, apply/reject/triage) into a single user-visible orchestrator:comments subcommand surface: scripts/comments/comments.sh.

The pipeline routes per-class with auto-apply gates ONLY on the trivial classes (uat-bug, decision-append) above the configured threshold (default 0.8 from comments.auto_apply_threshold.<class>). spec-amendment ALWAYS queues regardless of confidence (CON-5 / SC-5 — invariant retested mechanically at three seams: source scan in spec-amendment-human-gate.sh, runtime event-shape assertion in pipeline.sh, isolated R9 high-confidence test case in auto-apply.sh case D). ambiguous routes through the conversus adapter with --strict; adapter unavailability or BLOCK / low-confidence verdict drops the comment in the human-triage bucket with a recorded conversus_verdict diagnostic (M013/FR-13 graceful-degradation inheritance).

## Audit of partial state from prior attempt

The 408-line scripts/comments/comments.sh on disk from attempt-2 was a faithful superset of the plan reference body:
- Plan-mandated routing (per-class case + threshold gate + always-queue spec-amendment + adapter-fallback triage): present and correct.
- FR-10 comment_actioned event: present, AND extended with confidence + timestamp fields beyond the plan reference body (improves observability without breaking anything).
- FR-16 unit_close event: present with all six required fields.
- env-overridable sub-script paths (COMMENTS_FETCH/COMMENTS_ADAPTER/COMMENTS_UAT_INGEST/etc.): present — necessary for hermetic verifier testing, not in the plan reference body but a constructive extension.
- SC-5 hard-gate scan: clean (no auto[_-]?apply.*spec[_-]?amendment pattern).
- Bash 3.2 compliance: clean (no ${var,,}, no mapfile, no declare -A, no process substitution, no &> outside docstring comments).

Audit verdict: keep as-is. This task resumed by building the three T04 verifiers + retesting the T03 SC-5 human-gate verifier.

## Verification Results

All four verifiers exit 0:

- scripts/verify/m014-p03-pipeline.sh: 13 PASS / 0 FAIL — hermetic 4-comment fixture; classified=4; decision-append auto-apply (R5 @ 0.85 above 0.8); uat-bug below-threshold queue (R2 @ 0.7); spec-amendment always queues (R7 @ 0.85); ambiguous adapter-missing→triage; FR-16 unit_close all fields; idempotency: stable filenames + single actioned.jsonl row across two classify runs.
- scripts/verify/m014-p03-auto-apply.sh: 4 PASS / 0 FAIL — case A high-conf R1 uat-bug auto-applied + M013 stub invoked; case B high-conf R4 decision-append DECISIONS.md row + event; case C low-conf R2 uat-bug queued without auto-apply; case D high-conf R9 spec-amendment ALWAYS queues (SC-5 retest).
- scripts/verify/m014-p03-observability.sh: 8 PASS / 0 FAIL — unit_close present with every FR-16 field + integer-shaped counters + sanity-checked values; comment_actioned present with every FR-10 field.
- scripts/verify/m014-p03-spec-amendment-human-gate.sh (T03): 4 PASS / 0 FAIL — re-run as the SC-5 hard gate per task directive. Source scan still clean.

Total: 29 PASS / 0 FAIL across the four verifiers.

## Deviations from plan body

1. **comments.sh adds env-overridable sub-script paths.** Plan reference body hardcoded $PROJECT_ROOT-relative paths for FETCH/CLASSIFY/APPLY/REJECT/TRIAGE/ADAPTER. The on-disk implementation parameterizes each via COMMENTS_FETCH/COMMENTS_CLASSIFY/COMMENTS_ADAPTER/COMMENTS_UAT_INGEST/COMMENTS_APPLY/COMMENTS_REJECT/COMMENTS_TRIAGE env vars, defaulting to the plan-mandated paths. Necessary extension to support hermetic verifier testing (notably the adapter-missing→triage path test, which would otherwise require modifying the real adapter — a D007 violation). No caller-visible contract change for the production path.

2. **comment_actioned event carries confidence and timestamp fields.** Plan reference body listed only {comment_url, class, action_taken, source_surface}. On-disk implementation adds confidence (the verdict that drove the auto-apply decision — useful for FR-16 observability and future calibration analysis) and timestamp (ISO-8601 UTC). Additive only; no breakage.

3. **DECISIONS.md append guarded on file existence.** If .orchestrator/DECISIONS.md is missing, decision-append auto-apply still emits the comment_actioned event but skips the row append (avoids creating a malformed DECISIONS.md from scratch). Defensive behavior beyond the plan reference; no observable difference in environments where DECISIONS.md exists.

None of these change cross-task contracts or break the SC-5/CON-5 invariant.

## Contracts handed off to T05 (phase close)

- **Three T04 verifiers ready for the phase suite**: m014-p03-{pipeline,auto-apply,observability}.sh. Each is single-script-shape (AD-19), Bash 3.2 (CON-6), self-contained (creates its own scratch root + fixture stubs), exits 0/1.
- **comments.sh subcommand surface** — six subcommands (classify/status/apply/reject/triage/reclassify) wired and exercised. The FR-16/FR-10 event shape is now the canonical comments-pipeline observability contract for any consumer (orchestrator:auto status pulls, downstream knowledge-ingest, future calibration retune).
- **SC-5 invariant — three-seam retest**: T05 phase suite runs all four verifiers; if any future change wires an auto-apply branch for spec-amendment, multiple verifiers fail simultaneously (defense-in-depth).
- **adapter-missing routing diagnostic** — comment landing in triage with conversus_verdict=adapter-missing is the documented signal that the conversus adapter was not executable at runtime (vs conversus-block-or-low-conf, which means the adapter ran but did not reclassify out of ambiguous). T05 phase summary should note this as the M013/FR-13 graceful-degradation seam at the M014 layer.
- **Idempotency contract** — re-running classify on a clean repo produces identical queue + triage filenames (deterministic shasum) and a single actioned.jsonl row per auto-applied comment. Mechanically asserted; T05 can cite this without re-testing.

## Files touched

- scripts/comments/comments.sh (existing 408-line file from attempt-2 partial state — audit-passed, kept as-is, not modified by this resumed session)
- scripts/verify/m014-p03-pipeline.sh (NEW, ~190 lines, executable)
- scripts/verify/m014-p03-auto-apply.sh (NEW, ~165 lines, executable)
- scripts/verify/m014-p03-observability.sh (NEW, ~125 lines, executable)
- .orchestrator/milestones/M014/phases/P03/tasks/T04-pipeline-SUMMARY.md (this file, NEW)

D007 reuse honored — scripts/dispatch/adapters/tool/conversus.sh not modified. M013 scripts/integrations/uat-ingest.sh not modified (verifier stubs the entry-point via COMMENTS_UAT_INGEST override).
