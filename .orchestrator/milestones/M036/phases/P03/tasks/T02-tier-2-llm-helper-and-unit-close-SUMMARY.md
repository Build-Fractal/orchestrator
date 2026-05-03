---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P03"
milestone: "M036"
provides:
  - "scripts/knowledge/lib/extract-tier-2-llm.sh (~80-line pure helper lib; MEM004 args-in/stdout+exit-out/no top-level I/O; exposes extract_tier_2_dispatch mockable via EXTRACT_TIER_2_DISPATCH=stub:pass|stub:block|live with live as deferred-stub-error per CON-3 + extract_tier_2_emit_unit_close which appends one well-formed M030-shape unit_close JSONL record with task_type=extraction + model + tokens_in + tokens_out + cost_usd + quality_score + cite_id + timestamp + source=runtime to $ORCHESTRATOR_ROOT/.orchestrator/execution-log.jsonl); 3 single-script-file shape verifiers under tools/verify/m036-p03-* (m036-p03-tier-2-llm-helper-shape.sh — 7 checks: existence+executable + 6 token-presence on extract_tier_2_dispatch()/extract_tier_2_emit_unit_close()/EXTRACT_TIER_2_DISPATCH/stub:pass/stub:block/task_type; m036-p03-unit-close-extraction-shape.sh — 8 checks: drives extract_tier_2_emit_unit_close in mktemp -d workspace + asserts log file created + 7 JSONL field-shape checks (event/task_type/model/cite_id/cost_usd/tokens_in/tokens_out); m036-p03-driver-tier-2-shape.sh — 6 token-presence checks against scripts/knowledge/extract-reference.sh authored at T02 alongside the helper-it-tests but observational at T02-close because driver edits land in T03 — cross-task ordering pattern carried from M036/P02)"
requires:
  - "from:T01 what:templates/conversus-presets/tier-2-fidelity.yml + tests/fixtures/m036-p03-tier-2/extract-manifest.yaml + sample.md (closed PASS); from:disk what:scripts/knowledge/extract-reference.sh (P02 driver — read-only at T02; T03 modifies it) + scripts/dispatch/select-model.sh (M030 P01 — referenced by live-path comments; not exercised) + scripts/knowledge/lib/extract-binary-preservation.sh (preservation_sha256 — referenced by live-path; not exercised in CI)"
affects:
  - "T03 (gate helper + driver auto-branch consume the extract_tier_2_dispatch + extract_tier_2_emit_unit_close functions; driver must source extract-tier-2-llm.sh + call dispatch under tier=2 + summary_mode=auto and call emit_unit_close after gate verdict); T04 (acceptance harness drives the helper via EXTRACT_TIER_2_DISPATCH=stub:pass|stub:block; consumes the canned-structured*.md fixtures referenced by stub modes)"
key_files:
  - "scripts/knowledge/lib/extract-tier-2-llm.sh,tools/verify/m036-p03-tier-2-llm-helper-shape.sh,tools/verify/m036-p03-unit-close-extraction-shape.sh,tools/verify/m036-p03-driver-tier-2-shape.sh"
key_decisions:
  - "none"
patterns_established:
  - "P03 carries forward M036 verifier conventions intact: milestone-prefixed slug (m036-p03-*), AD-19 single-script-file shape, grep -qF -e token-loop body for leading-dash safety, structured PASS:/FAIL:/SUMMARY: stdout, set -eu strict, ROOT resolution via ${ORCHESTRATOR_ROOT:-$(pwd)}; pure-lib MEM004 pattern carried into Tier 2 surface (extract-tier-2-llm.sh has only function definitions — extract_tier_2_dispatch + extract_tier_2_emit_unit_close — no top-level execution; safe to source from any context); mockable LLM dispatch seam pattern (EXTRACT_TIER_2_DISPATCH env var with three modes: live = deferred-stub-error per CON-3 with stderr message naming the env-var contract; stub:pass = cp canned-structured.md; stub:block = cp canned-structured-low-fidelity.md; unknown mode = error 1 — gives CI a deterministic exit-code path while preserving the live-path implementation seam for M036b post-launch); stub-emits-metadata-on-stderr pattern (NAME=VALUE one-pair-per-line on stderr — MODEL/TOKENS_IN/TOKENS_OUT/COST_USD/QUALITY_SCORE — so the driver can parse stub model/token/cost values back into the unit_close record without needing a separate file or a parallel return-value channel; matches the structured-stderr conventions established by MEM001); M030 unit_close JSONL shape extension (additive — extends the existing emit_tier1_record convention from scripts/integrations/github-common.sh with task_type=extraction + cite_id + model + tokens_in + tokens_out + cost_usd + quality_score; preserves the base contract event/source/timestamp; CON-3 model-ID-not-hardcoded preserved because the model field is populated at runtime from select-model.sh output — never written into the helper itself outside the stub-mode metadata strings which are test fixtures); cross-task-ordering pattern carried from M036/P02 (T02 authors driver-tier-2-shape.sh alongside the helper it tests but lists it in T03's verification block — T02 close goes through with the verifier observational; auto-loop's first-fail-retry handles the green-up at T03 close); single-line printf '%s' field substitution for safe JSONL emission (avoids heredoc complexity + jq dependency; explicit %s for string fields and bare %s for numeric fields gives bash the freedom to interpolate without quoting issues — works under Bash 3.2)"
drill_down_paths:
  - ".orchestrator/milestones/M036/phases/P03/tasks/T02-tier-2-llm-helper-and-unit-close-PAYLOAD.md"
duration: "10m"
verification_result: "pass"
completed_at: "2026-05-02T16:51:26Z"
---

T02 lands the synchronous Tier 2 LLM dispatch + unit_close emitter for the M036 P03 reference-corpus extraction pipeline as a pure helper lib (MEM004) with three single-script-file shape verifiers gating the artifact contracts.

**What was built**:

- `scripts/knowledge/lib/extract-tier-2-llm.sh` — ~80-line pure helper lib (Bash 3.2 / POSIX-sh per CON-2; sourced by the P03 driver which T03 wires up). Exposes two pure functions:
  - `extract_tier_2_dispatch <input> <out> <category> <cite_id>` — dispatches Tier 2 LLM extraction. Honors the `EXTRACT_TIER_2_DISPATCH` env var with three modes: `live` (default — returns 1 with deferred-stub-error message per CON-3 — live LLM not exercised in CI; the M036b post-launch surface), `stub:pass` (copies `tests/fixtures/m036-p03-tier-2/canned-structured.md` to the out path + emits MODEL/TOKENS_IN/TOKENS_OUT/COST_USD/QUALITY_SCORE on stderr in NAME=VALUE form for driver parse-back), `stub:block` (same but copies `canned-structured-low-fidelity.md` with lower QUALITY_SCORE=0.61 fixture values), and an unknown-mode error path that exits 1 with a diagnostic naming the three accepted modes.
  - `extract_tier_2_emit_unit_close <cite_id> <model> <tokens_in> <tokens_out> <cost_usd> <quality_score>` — appends one well-formed M030-shape `unit_close` JSONL record to `${ORCHESTRATOR_ROOT}/.orchestrator/execution-log.jsonl` carrying `event=unit_close`, `task_type=extraction`, plus the six caller-supplied fields, an ISO-8601 UTC timestamp, and `source=runtime`. Idempotent mkdir -p of the parent dir; single printf with positional %s fields; no jq dependency.

- 3 verifiers under `tools/verify/m036-p03-*`:
  - `m036-p03-tier-2-llm-helper-shape.sh` — 7 checks: existence+executable + 6 token-presence (`extract_tier_2_dispatch()`, `extract_tier_2_emit_unit_close()`, `EXTRACT_TIER_2_DISPATCH`, `stub:pass`, `stub:block`, `task_type`).
  - `m036-p03-unit-close-extraction-shape.sh` — 8 checks: drives `extract_tier_2_emit_unit_close` in a mktemp -d workspace + asserts log file created + 7 JSONL field-shape checks against the freshly-emitted record.
  - `m036-p03-driver-tier-2-shape.sh` — 6 token-presence checks against `scripts/knowledge/extract-reference.sh` (driver). Authored at T02 alongside the helper-it-tests but **observational at T02-close** because the driver edits the verifier checks for (sourcing both helpers + invoking dispatch + emitting BLOCKED:) land in T03. Cross-task ordering pattern carried from M036/P02.

**Verification at T02-close**:

- `bash tools/verify/m036-p03-tier-2-llm-helper-shape.sh` → exit 0; `SUMMARY: m036-p03-tier-2-llm-helper-shape.sh fail=0` (7 PASS lines).
- `bash tools/verify/m036-p03-unit-close-extraction-shape.sh` → exit 0; `SUMMARY: m036-p03-unit-close-extraction-shape.sh fail=0` (8 PASS lines including the JSONL field-shape checks against an actual mktemp-emitted record).
- `bash tools/verify/m036-p03-driver-tier-2-shape.sh` → exit 1 at T02-close (FAILs with all 6 token-presence checks missing because the driver does not yet source the helpers; the task plan lists this verifier in T03's verification block, NOT T02's, exactly so the auto-loop's first-fail-retry does not pause T02 incorrectly). Classification: **observational, expected**, will go green at T03-close per the cross-task-ordering pattern.

**Mid-task corrections**: none. Both T02-required verifiers PASSed first try.

**Forward notes**:

- T03 sources `extract-tier-2-llm.sh` from `scripts/knowledge/extract-reference.sh` and calls `extract_tier_2_dispatch` under the `tier==2 && summary_mode==auto` branch + parses the NAME=VALUE stderr emission back into the `extract_tier_2_emit_unit_close` call. T03 also lands `scripts/knowledge/lib/extract-tier-2-gate.sh` whose `extract_tier_2_invoke_gate` consumes the dispatched structured-md output and produces a PASS|BLOCK verdict. The `m036-p03-driver-tier-2-shape.sh` verifier authored here goes green retroactively at T03-close via the auto-loop's first-fail-retry — same ordering as M036/P02's `size-cap-external-pointer.sh` cross-task pattern.
- T04 acceptance harness drives the helper end-to-end via `EXTRACT_TIER_2_DISPATCH=stub:pass` and `stub:block`. T04 also lands the two canned-structured fixtures the stub modes reference (`canned-structured.md` + `canned-structured-low-fidelity.md`) — at T02-close those fixtures do not yet exist, but the stub-mode dispatch only attempts to read them when invoked (no top-level I/O — MEM004), so the helper sources cleanly even pre-T04.
- The `live` branch is intentionally a stub-error per CON-3 (no live LLM in CI) — implementation seam for M036b post-launch, captured in the plan body rather than `.orchestrator/DECISIONS.md` because it's an implementation seam not an architectural commitment.
