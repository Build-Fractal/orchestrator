---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "M035/P00"
milestone: "M035"
provides:
  - "bash-3.2 exit-status capture for project_assets install loops in all 3 installers; regression fixture + shape verifier for the masking pattern"
requires:
  - "from:M035/P00 what:install-claude-code.sh+install-codex.sh+install-cursor.sh + scripts/lifecycle/read-project-assets.sh"
affects:
  - "M035/P00 SC-5 (collision-masking regression test); future P02-P06 publishing pipelines (any pre-publish smoke install must surface producer failures)"
key_files:
  - "packaging/install/install-claude-code.sh,packaging/install/install-codex.sh,packaging/install/install-cursor.sh,tools/verify/m035-p00-bash32-collision.sh,tests/installer-acceptance/m035-collision-exit-status.sh"
key_decisions:
  - "temp-file iteration over lastpipe (preserves bash 3.2 portability); explicit _producer_rc capture + early-exit gate; per-pass distinct temp file names (_collect_tmp/_dispatch_tmp/_manifest_tmp)"
patterns_established:
  - "process-substitution-fed-while-read masking is a bash-3.2 footgun; canonical replacement is mktemp + redirect + rc=$? + done < temp_file + rm -f"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P00/"
duration: "45m"
verification_result: "pass"
completed_at: "2026-05-08T05:17:16Z"
---

Replaced 9 process-substitution-fed while-read loops (3 per installer) with temp-file iteration. Each loop now writes producer stdout to a uniquely named mktemp file, captures _producer_rc=$? immediately after, exits 1 with a 'FAIL: read-project-assets.sh exited <rc>' diagnostic if the producer failed, then iterates the temp file via 'done < $_..._tmp'. The dispatch (second) pass also tracks _inner_rc and surfaces a separate 'FAIL: dispatch pass had inner failure rc=<rc>' diagnostic. Authored shape verifier tools/verify/m035-p00-bash32-collision.sh (17 checks PASS) and regression fixture tests/installer-acceptance/m035-collision-exit-status.sh which corrupts a temp bundle manifest and confirms all 3 installers exit non-zero (verified under bash 3.2.57 on Darwin). Happy-path smoke confirmed install-claude-code dry-run still produces SUMMARY: runtime=claude-code runtime_staged=23427. install-cursor exits 3 in current env (cursor not available probe) but still surfaces non-zero on collision — fixture accepts non-zero exit as the must-have under T01. Concerns: (1) install-asset-mode.sh under cp -R will overwrite existing target files in mode=copy without erroring, so the spec's stated 'inner copy/symlink step fails on a name-collision' branch is effectively unreachable under the current FR-22 --on-operator-owned=skip default; the producer-rc path is the live load-bearing branch and that is what the fixture exercises. (2) bash 4+ matrix wiring is deferred to P05/P02 per task plan — this fixture records BASH_VERSINFO[0] in its run header (currently bash 3 on the dev machine).
