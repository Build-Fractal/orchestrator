---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P06"
milestone: "M020"
provides:
  - "scripts/knowledge/query.sh extended in place with deferred state-filter resolution: sources scripts/knowledge/lib/preferences.sh adjacent to existing index-utils.sh + frontmatter.sh source lines; replaces the eager state_filter=graduated initial value with empty-string sentinel + state_filter_seen_on_cli=0 sentinel; --state arm sets the CLI-seen sentinel to 1; AFTER argument-parse loop and BEFORE the existing closed-enum validation block, a deferred-resolution block calls pref_resolve default_state_filter when CLI flag absent (preserves stderr WARN diagnostics from pref_resolve), falling back to the closed-enum-safe built-in default graduated on empty/non-zero return. Net precedence: CLI > project preferences > user preferences > built-in default graduated. Existing closed-enum validation block runs against the resolved value as belt-and-suspenders defence. Two new verifiers: scripts/verify/m020-p06-query-state-from-pref.sh (5 precedence cases A-E end-to-end through query.sh — no-pref/user-only/project-overrides-user/CLI-overrides-both/project-malformed-falls-through-to-user with stderr WARN assertion) and scripts/verify/m020-p06-query-pref-side-effect-free.sh (FR-8/CON-1 read-only invariant via md5 snapshot of project preferences file + user preferences file + per-file md5 of every entry in knowledge tree, across an 8-invocation battery covering matched/unmatched topic times default-state/explicit-state times ids/json formats — strictly stronger than git status per P02/T02 lesson). CON-4 byte-equivalence preserved: tests/test-knowledge-query.sh (P02 9-case integration test) remains green because the fixture environment declares no preferences file (HOME and PROJECT_ROOT temp dirs lack .orchestrator/preferences.yml), so resolved state_filter falls through to built-in default graduated, matching P02 expectations."
requires:
  - "from:P06/T01 what:scripts/knowledge/lib/preferences.sh sourceable helper exposing pref_resolve key with project>user>built-in-default precedence per-key (THREAT-007); from:P02 what:scripts/knowledge/query.sh existing FR-2 contract (CLI flags, output shape, exit codes, read-only invariant) — CON-4 surface preservation; from:P02 what:tests/test-knowledge-query.sh as the CON-4 byte-equivalence regression gate; from:P02/T02 what:md5/mtime snapshot diff pattern for read-only proofs (strictly stronger than git status — catches in-place rewrites that round-trip byte-for-byte)"
affects:
  - "P06/T03,P06/T04"
key_files:
  - "scripts/knowledge/query.sh,scripts/verify/m020-p06-query-state-from-pref.sh,scripts/verify/m020-p06-query-pref-side-effect-free.sh"
key_decisions:
  - "none-new,FR-6,FR-8,CON-1,CON-4,THREAT-007"
patterns_established:
  - "Deferred-resolution sentinel pattern: empty-string state_filter + state_filter_seen_on_cli=0 sentinel — CLI-arm sets sentinel to 1 — post-argparse block resolves via pref_resolve when sentinel==0. Closed-enum validation block UNCHANGED so it runs against the resolved value as belt-and-suspenders defence (catches future preference-helper bug or vocabulary drift without modifying validation). Stderr-preservation pattern: pref_resolve stderr is NOT redirected to /dev/null in query.sh, so malformed-value WARN diagnostics propagate to operator. CON-4 byte-equivalence preservation via additive in-place edit: existing CLI surface, output shape, exit codes, and side-effect-free invariant all unchanged; new behavior only activates when --state is absent AND a preferences file declares default_state_filter. Verifier convention reused from P06/T01: HOME and PROJECT_ROOT env-var prefix on a wrapped run_query function for tempdir fixture isolation; knowledge tree fixture written under PROJECT_ROOT/knowledge/conventions/ with three entries on the same topic (one per closed-enum status) so each precedence case resolves to a deterministic single ID. md5/md5sum portability fallback (md5sum on linux, md5 -q on macOS) reused from P02/T02. 8-invocation read-only battery extends the P02/T02 7-invocation pattern with one additional axis (with-pref-fallback vs explicit-state) to cover the new pref-resolution code path."
drill_down_paths:
  - ".orchestrator/milestones/M020/phases/P06/tasks/T02-query-integration-PAYLOAD.md"
duration: "30m"
verification_result: "pass"
completed_at: "2026-04-25T16:35:01Z"
---

Extended scripts/knowledge/query.sh in place with deferred state-filter resolution. Four edits: (1) added . SCRIPT_DIR/lib/preferences.sh source line adjacent to existing index-utils.sh + frontmatter.sh sources; (2) replaced eager state_filter=graduated with empty-string sentinel + state_filter_seen_on_cli=0; (3) --state arm of argument-parse loop sets state_filter_seen_on_cli=1 when consumed; (4) inserted deferred-resolution block AFTER argparse loop and BEFORE the existing closed-enum validation block — calls pref_resolve default_state_filter when sentinel==0, falls back to graduated on empty/non-zero return. Existing closed-enum validation block runs against resolved value (belt-and-suspenders).

Net precedence: CLI > project preferences > user preferences > built-in default graduated. CLI flag, when present, ALWAYS wins.

Two verifiers shipped under scripts/verify/, both PASS:
- m020-p06-query-state-from-pref.sh (6/6): end-to-end precedence cascade through query.sh. Case A no-pref no-CLI -> graduated only. Case B user-only=candidate -> candidate only. Case C project=archived overrides user=candidate -> archived only. Case D CLI=graduated overrides project=archived + user=candidate -> graduated only. Case E project=zombie (malformed) + user=candidate -> falls through to user candidate; stderr emits WARN: pref_resolve line for default_state_filter.
- m020-p06-query-pref-side-effect-free.sh (3/3): 8-invocation battery (matched/unmatched topic times default-state/explicit-state times ids/json formats with both pref files declared) leaves project preferences md5 unchanged, user preferences md5 unchanged, and per-file knowledge tree md5 manifest unchanged.

CON-4 byte-equivalence regression: bash tests/test-knowledge-query.sh exits 0 with PASS: 9/9 cases | tests/test-knowledge-query.sh (SC-1 + SC-7). P02 fixture declares no preferences file, so resolved state_filter falls through to graduated matching P02 expectations.

Auto-loop verify: bash scripts/lifecycle/auto-loop.sh .orchestrator/milestones/M020 --step=V --phase=P06 --task=T02-query-integration writes AUTO:VERIFY_PASS phase=P06 task=T02-query-integration checks_passed=3 to .orchestrator/milestones/M020/verify-result.txt.

CON-1 / FR-8 read-only invariant: query.sh introduces no writes — pref_resolve is read-only and the deferred-resolution block produces no file output. Verifier m020-p06-query-pref-side-effect-free.sh enforces with md5 snapshot of both prefs files + per-file knowledge tree md5 across the 8-invocation battery (strictly stronger than git status per P02/T02 lesson). AD-19 single-script-invocation shape: each verifier and the regression test is a single bash <script> command. MEM001 bash 3.2 compliance: no declare -A; sentinel + case dispatch pattern. MEM002 test conventions: pass()/fail() with parallel scalars; tempdir + trap cleanup; HOME and PROJECT_ROOT tempdir fixture isolation — no live ~/.orchestrator/ or repo-root .orchestrator/ access in any verifier.

Plan-deviation invariant (P04): this task's Verification section names ONLY verifiers authored by this task plus the P02 test (which already exists). No future-task verifiers referenced.

Downstream consumers: T03 (consolidate-artifacts.sh integration with effective_threshold) and T04 (docs + integration test) inherit the deferred-resolution sentinel pattern as the canonical idiom for additive in-place preference integration.
