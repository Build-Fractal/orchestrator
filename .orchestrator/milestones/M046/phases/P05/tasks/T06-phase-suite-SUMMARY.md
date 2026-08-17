---
schema_version: "1.0"
type: task-summary
id: "T06"
parent: "P05"
milestone: "M046"
provides:
  - "tools/verify/m046-p05-phase-suite.sh: P05 phase-close aggregator running all five P05 verifiers straight-line (AD-19) in dependency order (scope-guard-deny, install-wiring, driver-policy, sc5-write-tool-scope, sc15-verification-immutability), emitting one SUITE: line per member + final SUMMARY: pass=5 fail=0, exit 0 iff 5/5; a green run proves the scope-guard hook, install wiring, driver policy composition, and both NON-STUBBED milestone-blocking safety criteria (SC-5, SC-15) end to end via real unattended children through the LIVE installed hook in per-member isolated scratch HOMEs"
requires:
  - "the five tools/verify/m046-p05-*.sh members (T01-T05); modeled on tools/verify/m046-p04-phase-suite.sh"
affects:
  - "P05 close"
key_files:
  - "tools/verify/m046-p05-phase-suite.sh"
key_decisions:
  - "Five members only (no FR-17 attended-parity wrapper -- that was P04-specific; P05's task plan lists exactly the five members); never sets/overrides HOME globally -- transitively inherits each member's own scratch-HOME isolation; POSIX sh + set -u + cd REPO_ROOT header matching the p04 template verbatim"
patterns_established:
  - "P05 aggregator follows the m046-p02/p04-phase-suite convention verbatim: emit_suite_result helper + straight-line literal bash <path> per member + SUMMARY: pass/fail + exit 0-iff-all-green; milestone-prefixed name per P00-clobber lesson"
drill_down_paths:
  - ".orchestrator/milestones/M046/phases/P05/"
duration: "260s"
verification_result: "pass"
completed_at: "2026-07-13T21:11:35Z"
---

Authored tools/verify/m046-p05-phase-suite.sh, the P05 phase-close gate, modeled verbatim on m046-p04-phase-suite.sh: POSIX sh, set -u, cd REPO_ROOT, an emit_suite_result helper, and five straight-line bash <path> member invocations (AD-19, no loop-over-array) in dependency order -- scope-guard-deny, install-wiring, driver-policy, sc5-write-tool-scope, sc15-verification-immutability -- then a SUMMARY: pass=N fail=N line and exit 0 iff fail==0. The suite never touches HOME globally; members T04/T05 each self-isolate to scratch HOMEs and run the real installer + a real unattended child through the LIVE hook, so the suite inherits that isolation transitively. Run result: five SUITE: ... PASS lines + SUMMARY: pass=5 fail=0, exit 0. check-must-haves: all three T06 must-haves PASS (Truth 5/5-aggregation, Artifact 60 lines contains SUMMARY:, Key-Link -> m046-p05-scope-guard-deny.sh); one unrelated phase-plan key-link FAILs (envelope->manifest) owing to a T03 design choice that parameterized the envelope and placed the literal manifest reference in the driver instead -- out of T06 scope and forbidden to modify.
