---
schema_version: "1.0"
type: phase-summary
id: "P00"
parent: "M035"
milestone: "M035"
provides:
  - "bash-3.2 exit-status capture for project_assets install loops in all 3 installers; regression fixture + shape verifier for the masking pattern,managed .gitignore block emitter (FR-6/SC-6) for installer-owned sidecars; idempotent in-place block replacement; defensive duplicate-block collapse,wiki-stub freshness diagnostic (scripts/diagnostics/wiki-stubs-fresh.sh) + pages.yml pre-build gate; tmp-staged regen + diff approach (no live-tree mutation),M032 SC-5 fixture-completeness fallback wired into wiki-init.sh --deploy step 2; D-RN-1 npm-name collision-check evidence captured at packaging/bundle/D-RN-1-evidence.txt; M035 P00 phase-suite aggregator (m035-p00-phase-suite.sh) authored per AD-19"
requires:
  - "none"
affects:
  - "P01"
key_files:
  - "packaging/install/install-claude-code.sh,packaging/install/install-codex.sh,packaging/install/install-cursor.sh,tools/verify/m035-p00-bash32-collision.sh,tests/installer-acceptance/m035-collision-exit-status.sh,scripts/lifecycle/emit-managed-gitignore.sh,tools/verify/m035-p00-managed-gitignore.sh,scripts/diagnostics/wiki-stubs-fresh.sh,scripts/lifecycle/wiki-init.sh,tools/verify/m035-p00-wiki-stubs-fresh.sh,packaging/bundle/D-RN-1-evidence.txt,tools/verify/m035-p00-wiki-deploy-stage.sh,tools/verify/m035-p00-npm-collision-evidence.sh,tools/verify/m035-p00-phase-suite.sh"
key_decisions:
  - "temp-file iteration over lastpipe (preserves bash 3.2 portability); explicit _producer_rc capture + early-exit gate; per-pass distinct temp file names (_collect_tmp/_dispatch_tmp/_manifest_tmp),opener/closer marker shape '# >>> orchestrator-managed: gitignore >>>' / '# <<< ... <<<' (mirrors CLAUDE.md orchestrator:recent-changes pattern); single-pass awk rewrite with state machine (in_block / seen_block / last_emitted_blank); separator policy = single blank line iff last emitted line was non-blank; helper-direct behaviour-layer fixtures + grep-based wiring layer (CI-portable across runtimes whose probes may fail),exit-code contract 0=fresh / 1=env-fail / 2=drift (per dispatch payload,redefining the prior in-tree script which used 1=drift / 2=env-fail); diagnostic operates against tmp-staged copy via cp -R (.orchestrator/,knowledge/,scripts/,templates/,wiki/) + run generators with --root <tmp> rather than mutating live wiki; mkdocs build --strict gate folded back into the diagnostic's PASS path was dropped — kept the diagnostic single-purpose (drift only) and let pages.yml run mkdocs build separately; existing-workflow CON-3 advisory message extension surfaces the gate in stderr without changing behavior,D-RN-1=@build-fractal/orchestrator (unscoped 'orchestrator' on npm is TAKEN by orchestrator@0.3.8; @build-fractal scope AVAILABLE)"
patterns_established:
  - "process-substitution-fed-while-read masking is a bash-3.2 footgun; canonical replacement is mktemp + redirect + rc=$? + done < temp_file + rm -f,marker-delimited block primitive: opener + closer + body content; single helper script invoked identically from all 3 installers (mirrors install-meta.txt sidecar pattern); awk getline file pulls block body from temp file (avoids embedding multi-line strings in awk source); behaviour-layer testing via direct helper invocation when full installer run requires unavailable runtimes,tmp-staged regen-and-diff (cp -R sources,run generators with --root <tmp>,diff -ruN against committed tree) — reusable for any other freshness-gate diagnostic where the producer would otherwise mutate the live tree; printf '%s\n' '----- header -----' to side-step macOS bash printf interpreting leading hyphens as flags,missing-only stage-from-REPO_ROOT fallback for installer scripts where source-repo dirs may not have been bundled into PROJECT_DIR; phase-suite aggregator filename embeds milestone+phase prefix per AD-19 (m035-p00-phase-suite.sh)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P00/tasks/T01-SUMMARY.md, .orchestrator/milestones/M035/phases/P00/tasks/T02-SUMMARY.md, .orchestrator/milestones/M035/phases/P00/tasks/T03-SUMMARY.md, .orchestrator/milestones/M035/phases/P00/tasks/T04-SUMMARY.md"
duration: "145m"
verification_result: "pass"
completed_at: "2026-05-08T12:28:10Z"
observability_surfaces:
  - "none"
---

P00 closes the pre-launch dev-ergonomics surface for M035: it hardens the
three installers against silent failure modes that would otherwise blow up
during the real publish event in P02–P06, and clears two [M032](../../../../milestones/M032/index.md) carryovers
(SC-5 fixture-completeness gap, wiki-stub drift) that would have surfaced
as papercuts on the first multi-consumer dogfood run.

Four tasks landed:

- T01 replaced nine process-substitution-fed `while read` loops (3 per
  installer × 3 installers) with the temp-file iteration form. The bash
  3.2 footgun: `done < <(bash producer.sh)` does not propagate the
  producer's exit status to the outer installer, so a malformed manifest
  or missing project-asset key was silently swallowed and the installer
  reported success. The replacement captures `_producer_rc=$?` after a
  `> $tmp` redirect and exits non-zero on any failure. A regression
  fixture (`tests/installer-acceptance/m035-collision-exit-status.sh`)
  exercises the producer-failure path against all three installers and
  records `BASH_VERSION` in its run header — the bash 3.2 vs bash 4+
  matrix wiring lands at P05/P02 when the publishing CI exists.

- T02 introduced a marker-delimited managed `.gitignore` block primitive
  (FR-6 / SC-6). Each installer now invokes
  `scripts/lifecycle/emit-managed-gitignore.sh` after the
  `install-meta.txt` write step. The helper uses a single-pass awk
  rewrite (state machine: in_block / seen_block / last_emitted_blank) to
  guarantee idempotency: re-runs replace the block contents in place,
  duplicate blocks collapse to one, and content outside the markers is
  preserved byte-for-byte. Future M035 P05 rollback markers
  (`.previous-version` per FR-12) extend this block via the helper's
  `--block-content` hook.

- T03 shipped the wiki-stubs-fresh diagnostic
  (`scripts/diagnostics/wiki-stubs-fresh.sh`) and wired it into
  `wiki-init.sh emit_pages_workflow()`'s pages.yml HEREDOC as a pre-build
  gate. The diagnostic stages `.orchestrator/`, `knowledge/`, `scripts/`,
  `templates/`, and `wiki/` under `mktemp -d`, runs the stub and nav
  generators with `--root <tmp>`, then diffs against the committed wiki
  tree. Exit codes: `0=fresh`, `1=env failure`, `2=drift`. The CON-3
  existing-workflow preservation branch in `wiki-init.sh:483-486` is
  untouched — operators with an authored `pages.yml` keep ownership and
  see a stderr advisory recommending the gate. The diagnostic immediately
  earned its keep during T04 itself: writing T04-SUMMARY.md drifted the
  committed wiki, the gate fired loud, and the regen + re-verify cycle
  closed the loop. This is the new normal — every task that authors a
  spec/state file under `.orchestrator/` will require a wiki regen before
  the phase-suite goes green.

- T04 closed three loose ends in one task: (a) the M032 SC-5
  deferred-validation gap — `wiki-init.sh --deploy` step 2 now stages
  `wiki-deploy.sh` from `$REPO_ROOT` when the project copy is missing,
  removing the operator-side install precondition for the deploy path;
  (b) [D-RN-1](../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }") npm-name collision-check evidence captured at
  `packaging/bundle/D-RN-1-evidence.txt` (npm view confirmed unscoped
  `orchestrator` is TAKEN by `orchestrator@0.3.8` and
  `@build-fractal/orchestrator` is AVAILABLE — resolution
  `[D-RN-1](../../../../decisions.md#d-rn-1-npm-package-name-build-fractalorchestrator-dr-code-029 "npm package name `@build-fractal/orchestrator` { #dr-code-029 }"): @build-fractal/orchestrator` per RENAME-PLAN.md fallback);
  (c) the M035 P00 phase-suite aggregator
  (`tools/verify/m035-p00-phase-suite.sh`) — filename embeds the
  `m035-p00-` milestone+phase prefix per AD-19 path discipline (the
  unprefixed `p00-phase-suite.sh` shape silently clobbered [M030](../../../../milestones/M030/index.md)'s
  aggregator with [M031](../../../../milestones/M031/index.md)'s, and M031's with [M036](../../../../milestones/M036/index.md)'s; this filename never
  collides).

Verification: phase-suite battery `pass=5 fail=0` on all 5 task-grain
verifiers. Lock held throughout; no blockers, budget under at 4 tasks /
145m duration.

P01 (orchestrator:status version-drift warning) inherits an installer
tree that propagates exit status, a `.gitignore` block primitive ready
for `.previous-version` rollback markers, and a wiki tooling chain that
will surface drift loud rather than silently break `mkdocs build`.
P02–P06 (the publishing pipelines) inherit installer hardening that
prevents the "first user runs `npm install -g … && orchestrator init`
and the symlink loop swallows a manifest error" failure mode.
