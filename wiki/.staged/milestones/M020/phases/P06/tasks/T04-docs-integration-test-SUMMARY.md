---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P06"
milestone: "M020"
provides:
  - "references/preferences.md (191-line operator-facing doc covering five keys + types/ranges/defaults table + project>user>default precedence + per-key independent resolution per THREAT-007 + worked partial-overlap example + worked malformed example + closed-enum vocabulary + three runbooks single-operator/multi-operator/no-prefs); tests/test-preferences-resolution.sh (272-line MEM002-conformant integration test) covering SC-5 (project=0.6 wins over user=0.8 -> effective_threshold=0.6 + JSONL threshold_used=0.6 + both files md5 unchanged) + state-filter precedence through query.sh (project=candidate wins over user=graduated -> MEM511 candidate returned MEM510 graduated filtered out + both files md5 unchanged) + malformed-fallback through consolidate-artifacts.sh --cluster (project=not-a-number -> effective_threshold=0.7 + WARN: pref_resolve stderr diagnostic + project file md5 unchanged); scripts/verify/m020-p06-preferences-doc-content.sh contract verifier asserting doc names all five keys + precedence-token-order + per-key-independent phrase + worked malformed example + closed-enum phrase + both file paths"
requires:
  - "T01,T02,T03"
affects:
  - "phase-rollup"
key_files:
  - "references/preferences.md,tests/test-preferences-resolution.sh,scripts/verify/m020-p06-preferences-doc-content.sh,scripts/knowledge/consolidate-artifacts.sh"
key_decisions:
  - "THREAT-007,FR-6,SC-5,US-5,CON-1,FR-8,AD-19"
patterns_established:
  - "awk-staged-token-order assertion (BEGIN stage=0; advance stage on each successive token sighting; END print stage) for project>user>default precedence verification without requiring single-line co-location; portable md5_or_sha helper (md5 -q -> md5sum -> shasum -a 1 fallback chain) reused from P02/P05 verifier convention; HOME-rooted user-prefs fixture isolation (export HOME=/home alongside PROJECT_ROOT/ORCH_ROOT) to exercise _pref_user_path without leaking onto live ~/.orchestrator/; pre/post md5 snapshots on both prefs files at every scenario boundary to enforce CON-1 read-only invariant against the operator-owned preferences surface; spec-required stderr surface preservation correction (T03 line 81 had pref_resolve 2>/dev/null suppressing the malformed-value WARN that US-5 edge case requires; minimal correction removes 2>/dev/null with explanatory comment); plan-implementation-reality drift detection at integration time (T03 wiring suppressed stderr; T04 integration test exposed the suppression and forced the correction); test-internal heredocs/pipes are AD-19-safe because shape-guard inspects directly-invoked Bash tool calls not script internals (P03/P05 carry-forward)"
drill_down_paths:
  - "references/preferences.md, tests/test-preferences-resolution.sh, scripts/verify/m020-p06-preferences-doc-content.sh"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-25T16:48:07Z"
---

T04 ships the documentation + end-to-end integration test for the M020 preferences layer (FR-6 / US-5).

**Doc.** references/preferences.md (191 lines) is operator-facing reference prose modelled after references/state-machine.md and references/file-formats.md. It documents the five closed-enum keys with type/range/default table, both file paths verbatim (~/.orchestrator/preferences.yml and .orchestrator/preferences.yml), the project>user>default precedence chain, the per-key INDEPENDENT resolution rule (THREAT-007 disposition with worked partial-overlap example), the malformed-value fallback semantics with worked example showing similarity_threshold=not-a-number degrading to 0.7 + the WARN: pref_resolve stderr diagnostic + the explicit operator-file-untouched guarantee, the closed-enum vocabulary phrase, and three operator runbooks (single-operator, multi-operator team-wide-overrides + per-operator-opt-in, no-prefs-file).

**Integration test.** tests/test-preferences-resolution.sh (272 lines, 10/10 PASS) exercises three end-to-end scenarios through the production scripts (NOT through preferences.sh in isolation): (A) SC-5 direct — project=0.6 wins over user=0.8, consolidate-artifacts.sh --cluster emits effective_threshold=0.6 on stdout AND threshold_used=0.6 in JSONL execution-log, both prefs files md5 unchanged; (B) state-filter precedence via query.sh — project=candidate, user=graduated, no --state flag, query.sh --topic zeta returns MEM511 (candidate) only, MEM510 (graduated) filtered out, both prefs files md5 unchanged; (C) malformed-value fallback via consolidate-artifacts.sh --cluster — project=not-a-number, no user file, effective_threshold=0.7 stdout + WARN: pref_resolve: malformed value for 'similarity_threshold' stderr + project file byte-identical (md5) before/after. MEM002 conventions throughout: pass()/fail() parallel-scalar pattern (no declare -A), tempdir + trap EXIT rm -rf cleanup, HOME / PROJECT_ROOT / ORCH_ROOT env-override fixture isolation per P03/P05 — live knowledge/** and .orchestrator/execution-log.jsonl never touched.

**Verifier.** scripts/verify/m020-p06-preferences-doc-content.sh (114 lines, 11/11 PASS) asserts the doc names all five keys verbatim, presents project/user/default in token order via an awk staged-state-machine, mentions per-key INDEPENDENTLY resolution, contains the worked malformed example (both 'not-a-number' AND 'WARN: pref_resolve' literals), uses the literal word 'closed' for the closed-enum vocabulary phrase, and names both file paths verbatim.

**Plan-deviation.** Found and corrected one upstream T03 wiring drift at integration time: scripts/knowledge/consolidate-artifacts.sh line 81 had pref_resolve 2>/dev/null which suppressed the malformed-value WARN diagnostic that US-5 edge case requires the operator to see. Removed the stderr suppression with an explanatory NOTE (P06/T04) comment block. This is a corrective edit, not a drive-by enhancement — the spec edge case explicitly mandates the WARN surface. Without the fix, scenario C of the integration test would fail.

**Verification.** bash scripts/verify/m020-p06-preferences-doc-content.sh -> 11/11 PASS. bash tests/test-preferences-resolution.sh -> 10/10 PASS. auto-loop verify -> AUTO:VERIFY_PASS checks_passed=2.
