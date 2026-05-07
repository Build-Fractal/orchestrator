---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P02"
milestone: "M037"
provides:
  - "feedback:* routing arm in scripts/wiki/wiki-generate-stubs.sh + feedback enumeration block in scripts/wiki/wiki-scan-sources.sh + reserved-top-level collision guard for 'feedback' + tests/m037-acceptance/p01-feedback-routing.sh acceptance + tests/fixtures/m037-feedback-routing/ corpus + tools/verify/m037-p02-feedback-routing.sh wrapper. Operator-edited feedback stubs declaring auto_generated: false survive byte-identical via existing_stub_is_protected() helper consumed (NOT forked) from P01/T02."
requires:
  - "from:P01/T02 what:existing_stub_is_protected() helper, write_stub() signature, register_child() helper, build_canonical() helper"
affects:
  - "M037/P02 phase suite (T05 will register tools/verify/m037-p02-feedback-routing.sh in m037-p02-phase-suite.sh aggregator), tests/m037-acceptance/run-acceptance-battery.sh (auto-globbed p01-*.sh; battery now reports pass=6 up from pass=5 on T06 close)"
key_files:
  - "scripts/wiki/wiki-scan-sources.sh,scripts/wiki/wiki-generate-stubs.sh,tests/m037-acceptance/p01-feedback-routing.sh,tests/fixtures/m037-feedback-routing/round-3-sme-feedback.md,tests/fixtures/m037-feedback-routing/round-4-no-h1.md,tests/fixtures/m037-feedback-routing/will-be-removed.md,tests/fixtures/m037-feedback-routing/preexisting-stub.md,tools/verify/m037-p02-feedback-routing.sh"
key_decisions:
  - "FR-18,US-10,SC-13,MIT-01,MIT-02,B5,AD-19,CON-2"
patterns_established:
  - "Routing-arm mirror pattern: new feedback:* arm tracks proposals:* arm shape exactly (case dispatch on CAT prefix; build_canonical for .orchestrator/-rooted source; write_stub fifth-arg 'false' for B5 fragment-only passthrough; register_child for nav surfacing; continue to short-circuit subsequent arms). Differs only in path prefix and the explicit pre-write existing_stub_is_protected() short-circuit guarding register_child for protected stubs. INCLUDE_FEEDBACK env override (no CLI flag) — feedback is always-in-scope by design unless explicitly suppressed; mirrors INCLUDE_PROPOSALS but with a deliberately narrower opt-out surface. Reserved-top-level collision guard extension: appending tokens to the constitution|decisions|knowledge|... pipe-list at line 567 of wiki-scan-sources.sh fails-loud when wiki.extra_dirs declares the same name as a built-in routing target. MIT-01/02 helper-consumption pattern: routing arm calls existing_stub_is_protected() directly before write_stub even though write_stub also gates on it — direct call short-circuits register_child re-derivation while preserving nav presence; matches phase-plan §1110 'CONSUME the helper, NOT FORK it' instruction."
drill_down_paths:
  - ".orchestrator/milestones/M037/phases/P02/tasks/T01-feedback-routing-arm-PLAN.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-05-07T15:30:41Z"
---

T01 lands FR-18 (feedback/ routing arm) per US-10 / SC-13. Source: papercut-sweep-wiki-deploy-2026-05-07.md finding #1 — PBJ-central operator hand-scaffolded two stubs to get past wiki-deploy gate 2 because KNOWLEDGE.md cross-links feedback/<file>.md and the link-checker (correctly) treats them as in-scope.

Implementation:

1. scripts/wiki/wiki-scan-sources.sh — added feedback enumeration block (immediately after the proposals block, before extra_dirs). Default-on; opt out via INCLUDE_FEEDBACK=0 env override (no CLI flag — feedback is always-in-scope by design unless explicitly suppressed). Records emit at category prefix feedback:<basename>; per-record relative path is feedback/<basename>.md. Also extended the reserved-top-level-collision guard at line 567 to include the 'feedback' token, preventing operator-declared wiki.extra_dirs: [feedback] from colliding with the new routing.

2. scripts/wiki/wiki-generate-stubs.sh — added feedback:* routing arm immediately after the proposals:* arm. Mirror of the proposals shape: build_canonical (prepends .orchestrator/), write_stub fifth-arg 'false' for B5 fragment-only passthrough, register_child for nav surfacing. Differs only in path prefix and the explicit pre-write existing_stub_is_protected() short-circuit (skips write but still calls register_child so nav references the protected stub).

3. tests/fixtures/m037-feedback-routing/ — four flat fixture .md files (round-3-sme-feedback.md exercises H1-derived title, round-4-no-h1.md exercises humanized-basename fallback, will-be-removed.md exercises idempotent removal, preexisting-stub.md exercises MIT-01/02 escape hatch). Tests stage these into a temp project root via mktemp -d + symlinks to the project's scripts/wiki/.

4. tests/m037-acceptance/p01-feedback-routing.sh — 11-assertion acceptance: scanner emits all three feedback:<basename> records; stubs.sh emits H1-derived + humanized-basename + idempotent-removal stubs across two runs; protected stub survives byte-identical. The 'p01-' prefix is intentional — the run-acceptance-battery.sh aggregator auto-globs p01-*.sh.

5. tools/verify/m037-p02-feedback-routing.sh — 8-gate AD-19-compliant wrapper: greps the live scripts for the literal markers (feedback:, INCLUDE_FEEDBACK, feedback:*), existing_stub_is_protected) and invokes the acceptance test via bash. Both required Check: targets in the phase plan resolve to this verifier.

Verification:
- bash tools/verify/m037-p02-feedback-routing.sh — SUMMARY: m037-p02-feedback-routing pass=8 fail=0
- bash tests/m037-acceptance/p01-feedback-routing.sh — SUMMARY: p01-feedback-routing pass=11 fail=0
- bash tests/m037-acceptance/run-acceptance-battery.sh — BATTERY: pass=6 skip=0 fail=0 (was pass=5 on T06 close; auto-glob picked up the new p01-feedback-routing.sh)
- bash tools/verify/m037-p01-phase-suite.sh — SUMMARY: m037-p01-phase-suite.sh pass=9 fail=0 (no regression to P01 surface)

No source-file mutation (CON-2 honored — .orchestrator/feedback/*.md zero in this repo today; routing exercised via temp-staging fixtures only). No knowledge-graph mutations. Bash 3.2 + POSIX sh shape preserved throughout.
