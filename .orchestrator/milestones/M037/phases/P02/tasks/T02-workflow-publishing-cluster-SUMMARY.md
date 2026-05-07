---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P02"
milestone: "M037"
provides:
  - "emit_pages_workflow + flip_pages_build_type functions in scripts/lifecycle/wiki-init.sh emitting .github/workflows/pages.yml verbatim from handoff doc + gh api -X PUT build_type=workflow with manual-fallback diagnostic on gh missing or unauthenticated; CON-3 no-clobber on pre-existing workflow file. wiki-deploy.sh demote: legacy mkdocs gh-deploy --force live path replaced with OWNER/REPO resolver + post-gate report printing OK pre-deploy gates PASS, git push origin main, and workflow URL. wiki/README.md First-deploy checklist + Running the deploy wrapper sections rewritten to git-push-triggers-workflow flow (M032 cross-milestone touch owned by M037). tests/test-wiki-init-workflow-mode.sh verbatim from handoff (FR-19/FR-20 SC-14 acceptance). tools/verify/m037-p02-workflow-pages-publishing.sh aggregator (15 gates)."
requires:
  - "from:T01 ordering only (sequential commit history); from:wiki-init.sh OWNER/REPO/PROJECT_DIR/REPO_ROOT env vars resolved earlier; from:.orchestrator/proposals/papercut-handoff-wiki-publishing-robustness-2026-05-07.md verbatim YAML reference impl + verbatim test scaffold"
affects:
  - "M037 P02 phase suite — T05 will register tools/verify/m037-p02-workflow-pages-publishing.sh; M032 wiki/README.md (cross-milestone touch owned by M037; M032 stays closed); operator workflow shifts from local mkdocs gh-deploy live path to git-push-triggers-workflow path; M036b post-launch wiki projection inherits the workflow-based deploy assumption"
key_files:
  - ".orchestrator/milestones/M037/phases/P02/tasks/T02-workflow-publishing-cluster-PLAN.md,scripts/lifecycle/wiki-init.sh,scripts/wiki/wiki-deploy.sh,wiki/README.md,tests/test-wiki-init-workflow-mode.sh,tools/verify/m037-p02-workflow-pages-publishing.sh"
key_decisions:
  - "FR-19,FR-20,US-11,SC-14,CON-3,CON-4,F12,F9-superseded,AD-19"
patterns_established:
  - "Single-quoted heredoc delimiter PAGES_WORKFLOW_EOF preserves GitHub Actions environment-output interpolation byte-identical (would otherwise undergo shell expansion); whole-file managed CON-3 emit pattern: pre-existence check returns 0 with diagnostic before any write attempt — clobber is structurally impossible. OWNER/REPO resolver pattern in wiki-deploy.sh mirrors scripts/lifecycle/wiki-init.sh's git-remote URL parser case statement (git@github.com vs https://github.com/) — matching shapes keeps maintenance cost low. Post-gate report shape: print OK pre-deploy gates PASS Push to main to trigger workflow deploy plus indented git command plus blank line plus workflow URL — readable; 5-line awk sliding-window adjacency check in verifier catches doc drift where the legacy pattern 'bash wiki-deploy.sh' is followed within 5 lines by 'mkdocs gh-deploy' (would indicate live-deploy still documented as active). gh availability + auth gating with verbatim manual-fallback command: skip-with-diagnostic on either missing condition keeps init non-blocking when gh is unavailable while surfacing the operator-runnable command for later."
drill_down_paths:
  - ".orchestrator/milestones/M037/phases/P02/tasks/T02-workflow-publishing-cluster-PLAN.md,.orchestrator/proposals/papercut-handoff-wiki-publishing-robustness-2026-05-07.md"
duration: "1h"
verification_result: "pass"
completed_at: "2026-05-07T15:42:58Z"
---

T02 lands FR-19 + FR-20 per US-11 / SC-14 as a single tightly-coupled task cluster. Source: papercut-handoff-wiki-publishing-robustness-2026-05-07.md Gap 1 (PBJ-central wedged 7 days on a stuck pages-build-deployment run, irrecoverable via documented APIs; legacy mkdocs gh-deploy --force live path superseded).

Implementation:

1. scripts/lifecycle/wiki-init.sh — added emit_pages_workflow (heredoc emit of .github/workflows/pages.yml byte-identical to the handoff verbatim shape) + flip_pages_build_type (gh api -X PUT repos/OWNER/REPO/pages -f build_type=workflow, gated on gh availability + auth, manual-fallback diagnostic on either skip path). Wired AFTER the mkdocs.yml field-line rewrite + yaml-merge block and BEFORE the FR-15 glossary stub. Single-quoted heredoc delimiter PAGES_WORKFLOW_EOF preserves the literal GitHub Actions environment-output interpolation byte-identical (steps.deployment.outputs.page_url under the double-brace expression form). CON-3 honored via early-return diagnostic on pre-existing PAGES_WF_TARGET.

2. scripts/wiki/wiki-deploy.sh — replaced the live-deploy block (legacy mkdocs gh-deploy --force invocation) with the FR-20 post-gate report block. Added OWNER/REPO resolver block that parses git config remote.origin.url for the git@github.com and https://github.com/ shapes; mirrors wiki-init.sh's parser. Output shape: 'OK: pre-deploy gates PASS. Push to main to trigger workflow deploy:' + 'git push origin main' + 'Workflow run: https://github.com/OWNER/REPO/actions/workflows/pages.yml' (or fallback URL with placeholder when OWNER/REPO unset). Header comment + usage block + exit-codes table updated to drop 'live path' language and reflect the gates-then-push-instruction flow. mkdocs gh-deploy now appears only inside comments (historical context) — no live-path invocation remains.

3. wiki/README.md — three-section rewrite (M032 cross-milestone touch owned by M037 per FR-20 done-definition):
   - 'First-deploy checklist' step 3 'Run the pre-deploy gates and push to main' with new explanation paragraph + 'Why workflow-based publishing?' callout citing the 7-day PBJ-central incident + the handoff doc.
   - Manual-recovery details block step 4 + step 6 rewritten: gh-pages-branch language replaced with build_type: workflow + GitHub Actions Source; step 6 becomes 'Run wiki-deploy.sh; on PASS, git push origin main'.
   - 'Running the deploy wrapper' Pipeline + Output lines + Exit codes subsections rewritten to drop mkdocs-gh-deploy-force references and reflect the new post-gate report shape (DRY-RUN gates PASS would print push instruction / OK pre-deploy gates PASS Push to main to trigger workflow deploy / 0 — every gate PASS).
   - Pre-existing operator content byte-preserved (Private-repo callout, giscus install/setup language, non-deploy sections).

4. tests/test-wiki-init-workflow-mode.sh — verbatim from handoff doc lines 240-269. set -euo pipefail; mktemp temp dir + git init + git remote add origin git@github.com:Test-Org/test-repo.git; runs install-claude-code.sh --force then wiki-init.sh --project-dir .; asserts .github/workflows/pages.yml exists and contains actions/deploy-pages + actions/upload-pages-artifact; conditional check that wiki-deploy.sh either contains no 'mkdocs gh-deploy' OR has a DRY_RUN/--dry-run/local-only guard. Path adjustment: ROOT resolves to repo root (parent of tests/) which the handoff source already had correctly.

5. tools/verify/m037-p02-workflow-pages-publishing.sh — 15-gate AD-19-compliant aggregator. Greps wiki-init.sh for actions/deploy-pages, build_type=workflow, cache-dependency-path: wiki/requirements.txt, cancel-in-progress: false. Greps wiki-deploy.sh for absence of 'mkdocs gh-deploy --force' outside comments + presence of 'git push origin main' + 'actions/workflows/pages.yml'. Greps wiki/README.md for 'git push origin main' + (build_type|GitHub Actions) + 5-line awk sliding-window adjacency check that 'bash scripts/wiki/wiki-deploy.sh' is NOT followed within 5 lines by 'mkdocs gh-deploy'. Invokes test-wiki-init-workflow-mode.sh and propagates exit. Emits SUMMARY: m037-p02-workflow-pages-publishing pass=N fail=M.

Verification:
- bash tools/verify/m037-p02-workflow-pages-publishing.sh — SUMMARY: m037-p02-workflow-pages-publishing pass=15 fail=0
- bash tests/test-wiki-init-workflow-mode.sh — PASS: wiki-init scaffolds workflow-based publishing
- bash tools/verify/m037-p01-phase-suite.sh — SUMMARY: m037-p01-phase-suite.sh pass=9 fail=0 (no P01 regression)
- bash tools/verify/m037-p02-feedback-routing.sh — SUMMARY: m037-p02-feedback-routing pass=8 fail=0 (no T01 regression)
- Manual probe — fresh-fixture render: workflow YAML matches the handoff verbatim shape including the GitHub-Actions environment-output interpolation preserved byte-identical.
- Manual probe — CON-3 no-clobber: pre-authored .github/workflows/pages.yml byte-preserved across wiki-init re-run; diagnostic 'preserving operator-authored workflow (CON-3)' surfaces.

CON-4 hard-codes branches: [main] per the handoff verbatim contract — non-main consumers flagged as P03 follow-up. F9 supersession: F12 absorbs F9's operator-confidence intent via Actions observability (cancel/rerun/logs); no truth or test asset corresponds to F9 in this task. Bash 3.2 + POSIX sh shape preserved throughout. SC-14 manual end-to-end live-LLM smoke deferred to M037-ACCEPTANCE-EVIDENCE.md per phase plan (operator-recorded outside the automated battery).
