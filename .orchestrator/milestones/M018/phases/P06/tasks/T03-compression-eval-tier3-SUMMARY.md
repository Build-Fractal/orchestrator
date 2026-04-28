---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P06"
milestone: "M018"
provides:
  - "scripts/diagnostics/compression-eval.sh --tier 3 real cohort logic against tier3_compression_savings_tokens (replaces P05 reservation stub); cohort split + Wilson 95% CI for pass-rate + pooled-SE for retry/deviation; below-floor 'insufficient sample'; sourceable + CLI shape preserved (FR-12 always-exit-0; AD-19 single-script-file Check shape)"
requires:
  - "P06/T01 _bc_apply_tier3 helper + tier3 prompt template; P06/T02 tier3_compression_savings_tokens additive field on payload_breakdown; P05/T03 compression-eval.sh canonical shape (cohort-build awk pass + Wilson/pooled-SE arithmetic + always-exit-0 contract)"
affects:
  - "P06/T04 ships canonical truth verifier m018-p06-compression-eval-tier3.sh + fixture trees + P06-SUMMARY + dual-write"
key_files:
  - "scripts/diagnostics/compression-eval.sh"
key_decisions:
  - "P05/T03 cohort-build awk pass and Wilson/pooled-SE arithmetic are correct as-is for tier3 — only the JSONL field name driving the cohort split changes; defensive else-zero arm in awk preserved against awk uninitialized-variable warnings; P05 compression-eval verifier 'tier 3 missing P06-reservation stub' assertion intentionally inverted by T03 — T04 replaces that assertion with the tier3 cohort-block assertion"
patterns_established:
  - "MEM004 emitter-internal carve-out applies inside compression-eval body; tier-N case fall-through pattern widens cleanly when a new tier joins the cohort-segmentation diagnostic without touching CI/SEM math; T03 single-file surgical pattern — production code modification only, with canonical truth verifier shipped in T04 per P03/P04/P05 phase shape"
drill_down_paths:
  - ".orchestrator/milestones/M018/phases/P06/tasks/T03-compression-eval-tier3-PLAN.md;.orchestrator/milestones/M018/phases/P06/tasks/T03-compression-eval-tier3-PAYLOAD.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-28T14:23:42Z"
---

T03 surgically modifies scripts/diagnostics/compression-eval.sh in two places to replace the P05 --tier 3 reservation stub with real cohort logic.

Step 1: the case-arm `case "$tier" in 1|2) ;; 3) printf 'tier 3 reserved for P06...'; return 0 ;; esac` is collapsed to `case "$tier" in 1|2|3) ;; esac`. Tier 3 now falls through to the same cohort-build / Wilson-CI / pooled-SE pipeline that tier 1 and tier 2 use.

Step 2: the if/else inside the awk pass that picks the savings field is widened from a 1/2 binary to a 1/2/3 chain. Tier 3 reads tier3_compression_savings_tokens (full key, no abbreviation, matching the T02 emitter and the FR-10 spec field name). A defensive `else (v = 0)` arm is added for paranoia — the bash-level case statement already rejects unknown tiers, so this arm should never fire, but it ensures v is always defined under stricter awk implementations.

Header comment + --help text updated: "Required. 1, 2, or 3." (was "Required. 1 or 2 in P05; 3 reserved for P06.").

Self-checks: `bash -n` PASS; `--help` exits 0 with updated text; `--milestone M018 --tier 3 --sample-floor 1` against the live log emits "insufficient sample (compressed=0 uncompressed=22 floor=1)" and exits 0 (correct — no tier3 dispatches have fired yet, so the compressed cohort is empty; FR-12 always-exit-0 contract preserved).

Known intentional break: `scripts/verify/m018-p05-compression-eval.sh` assertion 3 ("tier 3 emits P06-reservation stub") now FAILs by design. The P05 verifier predates T03 and asserts the stub behavior. T04 ships `m018-p06-compression-eval-tier3.sh` which asserts the inverse (cohort block emitted on a tier3-fired fixture; insufficient sample on a high floor; no "tier 3 reserved" literal in any output). The P05 verifier should not be re-run after T03 lands; the canonical post-T03 verifier is the P06 one.

T03 ships nothing else: no helper, no prompt template, no schema extensions, no verifiers, no fixtures, no SUMMARY beyond this one, no dual-write — those are T01 (helper + prompt; already shipped), T02 (schema extensions; already shipped), and T04 (verifiers + fixtures + P06-SUMMARY + dual-write; not yet shipped).

CON-5: additive only — only behavior change is the tier=3 case-arm in the diagnostic. CLI surface unchanged. JSONL surface unchanged. Pre-P06 records remain valid (the diagnostic reads the additive field and treats absent-as-zero via the field_num helper's match-fallback-to-0 path). FR-12 always-exit-0 preserved. AD-19: T03's task-local extractable Check is `bash -n scripts/diagnostics/compression-eval.sh` (single-script-file shape). MEM001: bash 3.2 — awk only, closed-form arithmetic, no python/jq.
