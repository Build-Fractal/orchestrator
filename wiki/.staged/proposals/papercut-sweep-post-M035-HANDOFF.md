# Handoff — Paper-Cut Sweep Post-[M035](../milestones/M035/index.md) (Mid-Sweep)

**Date**: 2026-05-10 (initial author) / 2026-05-10 PM (re-handoff after baseline-recovery) / 2026-05-10 evening (post-WS2 close)
**Branch**: `papercut-sweep-post-M035` (15 commits ahead of `main`)
**Status**: WS1 6/7 paper-cuts done + PC-8 added + WS2 done + 2 baseline-recovery commits; WS1 PC-7 + WS3 remaining. PC-5 deferred (new finding — see proposal § "PC-5 status").

## What's done (15 commits on branch)

```
5c3f61d3 rename audit: close residue from M035 P01.5 sweep                                # WS2
213d65ca papercut-sweep(docs): PC-5 deferred + new finding; WS2 verdict matrix authored   # PC-5 deferred + WS2 doc
8922aec9 paper-cut(m032/golden): refresh per-dir-count golden post M033/M035/m040 churn   # PC-8 (new this session)
1ed5a5ba paper-cut sweep: handoff doc update for fresh session (mid-session 2026-05-10 PM)
10a0ead8 paper-cut(c1-sweep): allowlist papercut-sweep-post-M035-HANDOFF.md               # baseline-recovery
feb1c337 paper-cut(wiki): regen for handoff doc nav entry                                 # baseline-recovery
84b601a4 paper-cut sweep: handoff doc for fresh session                                   # earlier handoff
68c619b8 paper-cut(rollback-test): trap-EXIT recovery for detached HEAD (Option A)        # PC-6
57bee626 paper-cut(byte-equivalence): BSD-portable EXCLUSION_LIST + spec fix              # PC-3
50ba0be9 paper-cut(decisions): dual-shape highest-id scanner in append-decision.sh        # PC-2
7c85827c paper-cut(verify): extend P01.5 allowlists to exclude wiki/                      # PC-4 follow-up
428fd5b4 paper-cut(verify): chmod +x on three M035 P00 verifiers                          # PC-4
85c023e8 wiki: regen stubs + decorate-build + nav after M035 close                        # PC-4 unmask fix
c3508444 paper-cut(probe): export REPO_ROOT in run-probe.sh + docstring update            # PC-1
41b6edcf paper-cut sweep: author post-M035 sweep brief                                    # proposal
```

**Battery state**: M035 acceptance battery `BATTERY: pass=179 fail=0 skip=1` confirmed at session start (took ~33 min — the rollback-byte-equivalence test is slow but green). Not re-run after this session's commits. PC-8 + WS2 only touch fixture content + comments + user-facing text + external-URL strings; logical confidence is high that the next battery run reports the same.

[M032](../milestones/M032/index.md) acceptance battery NOT re-run after PC-8. The pre-existing SC-1 golden drift was confirmed as the only failure before PC-8 landed (`actual=1178 expected=1173`); PC-8 refresh now expects `1178` and SC-1 alone re-ran PASS. The other 9 SC-1..SC-11 + SC-12 + SC-13 verifiers are unchanged by today's commits.

**Notable side-discoveries this session**:

- **Pre-existing M032 SC-1 golden drift unblocked PC-5 attempt**. `tools/verify/fixtures/m032-pre-m032-golden.txt` was last refreshed 2026-05-07 ([M037](../milestones/M037/index.md) P03 round-4) but six framework files were added + one removed under `scripts/` between then and HEAD (PBJ-2026-05-07 surgical fixes, M035 P00, M035 P05 T01, M035 P01 T03, M035 P02, m040 backport) plus one added under `templates/` (M035 P02 npm packaging). Refreshed per the golden's documented "Refresh policy" — net `+5` scripts (1173 → 1178), `+1` templates (52 → 53), `+6` total (1298 → 1304). Not caused by this branch.
- **PC-5 retire-the-precondition approach is premature**. M035 P00 T04 (commit `1aba20e7`, `scripts/lifecycle/wiki-init.sh:1146-1159`) only stages `wiki-deploy.sh`; the deploy chain ALSO requires `scripts/wiki/wiki-scan-sources.sh` + `scripts/diagnostics/wiki-giscus-config-check.sh` (and possibly more — full chain audit not performed). Live SC-5 attempt failed at the `wiki-deploy.sh` pre-deploy giscus-config-check gate. Full closure requires either extending the M035 P00 T04 staging block to bundle the full helper chain, or post-install fixture bootstrap. Captured as PC-5 status: DEFERRED in the proposal with the new finding documented inline.
- **Two co-discovered SC-5 test side issues** (each a separate paper-cut candidate, neither addressed):
  1. SC-5 `cleanup()` trap silently absorbs `gh repo delete` 403s when token lacks `delete_repo` scope. Throwaway repo leaks. The cleanup() should fail loudly so the operator can recover.
  2. Fixture-remote restore lives AFTER `cleanup()` in linear flow; on `wiki-init.sh` failure the fixture remote is left pointing at the throwaway. Restore should be wrapped in the EXIT trap.
- **Throwaway repo NOT deleted by today's SC-5 attempt**: `bkellgren/1778456834-m032-fixture` (private) persists on GitHub. Operator action needed: `! gh auth refresh -h github.com -s delete_repo`, then `gh repo delete bkellgren/1778456834-m032-fixture --yes`. Fixture remote at `tests/fixtures/m032-fresh-project-fixture/` was manually reset to baseline in this session.

**Earlier-session side-discoveries (preserved verbatim)**: PC-4's chmod unmasked stale wiki state (decorate-build never run since M037). Fixed inline as the `wiki: regen stubs + decorate-build + nav` commit (`85c023e8`). PC-3's regex fix unmasked a real spec bug — `package.json` was marked `npm`-only in references/installation.md but it's present in all three channel staged trees (D007 single-source-of-truth tarball). Fixed inline by promoting `package.json`/`package-lock.json`/`node_modules/` to `all`-channel exclusion.

## Baseline-recovery (mid-session 2026-05-10 PM)

The previous handoff claimed `pass=179 fail=0 skip=1` but the fresh session's first battery run reported `pass=177 fail=2 skip=1`. Both regressions were caused by the handoff commit (`84b601a4`) itself — the fresh-session author hadn't anticipated that committing the doc would trip the battery.

**Failure 1** — P01.5 C1 sweep flagged the new HANDOFF.md as residual non-historical `spec-kit-orchestrator` matches (12 literal occurrences across the audit-grep examples + rename mv commands). The doc's path was not in the C1 sweep allowlist. **Fix**: extend `tools/verify/m035-p015-c1-sweep.sh:23` allowlist regex to include `\.orchestrator/proposals/papercut-sweep-post-M035-HANDOFF\.md` (precedent: `papercut-sweep-pre-[M030](../milestones/M030/index.md)\.md` already in the allowlist for the same reason). Commit `10a0ead8`. Verified via `bash tools/verify/m035-p015-c1-sweep.sh` → `PASS: m035-p015-c1-sweep`.

**Failure 2** — P00 wiki-stubs-fresh diagnostic detected drift: the handoff doc was committed without running the wiki 3-step regen, so the proposals nav entry + section index were missing. **Fix**: run the diagnostic's own internal flow:
```
bash scripts/wiki/wiki-generate-stubs.sh
python3 scripts/wiki/wiki-decorate-build.py --root . --force
bash scripts/wiki/wiki-generate-nav.sh
```
Output is one new stub + one new staged source + one nav entry + one section index update (4 files total). Commit `feb1c337`. Verified via `bash scripts/diagnostics/wiki-stubs-fresh.sh --root .` → `PASS: wiki-stubs-fresh (no drift; 2392 stubs + nav verified against committed state)`.

**WARNING — easy to repeat**: any future commit that adds a file under `.orchestrator/proposals/` (or `.orchestrator/milestones/`, `knowledge/`, etc.) MUST be paired with the wiki 3-step regen before commit, or P00 wiki-stubs-fresh will flag drift. The decorate-build step is load-bearing — running only `stubs + nav` (without decorate) corrupts ~2354 wiki/ files because decorate rewrites every stub's `include-markdown` directive from canonical `.orchestrator/...` form to `.staged/...` form (the form mkdocs build resolves at deploy time). Confirmed during this session — initial revert + 3-step replay was needed.

**Battery direct measurement**: re-running `tests/m035-acceptance/run-acceptance-battery.sh` after the two baseline-recovery commits hung past 18 minutes (P05 rollback-byte-equivalence test was still running on the third channel; possibly resource contention with browser/other processes — first run completed in ~5 min). Battery was killed for clean fresh-context handoff. **Both individual failing verifiers were re-verified independently to PASS**:
- `bash tools/verify/m035-p015-c1-sweep.sh` → PASS
- `bash scripts/diagnostics/wiki-stubs-fresh.sh --root .` → PASS

Other verifiers were unchanged by this session's commits (confirmed: they were green in the original `pass=177 fail=2` run, and the two new commits only touch `tools/verify/m035-p015-c1-sweep.sh` + `wiki/`). Logical confidence is high that the next battery run will report `pass=179 fail=0 skip=1`. The fresh session should re-run the battery first to confirm before continuing with PC-5.

**Two operator-WIP files still untouched** as required: `templates/phase-plan.md`, `.orchestrator/direct-mode-execution-log.jsonl`.

## What remains

### WS1 PC-5 — DEFERRED (new finding 2026-05-10 evening)

**Status**: deferred. The PM-session handoff identified the runtime fix as
already shipped under M035 P00 T04 (commit `1aba20e7`,
`scripts/lifecycle/wiki-init.sh:1146-1159`). A live SC-5 attempt this
session showed the closure is **partial**: M035 P00 T04 stages
`wiki-deploy.sh` but the deploy chain ALSO requires
`scripts/wiki/wiki-scan-sources.sh` + `scripts/diagnostics/
wiki-giscus-config-check.sh` (and possibly more — full chain audit
not performed). Full closure requires either extending the M035 P00
T04 staging block to bundle the full helper chain (deeper change to
`wiki-init.sh` plus a chain audit), or post-install fixture
bootstrap. Neither path is paper-cut-shaped — this is a real
follow-on milestone-grain fix.

What landed this session: PC-8 (golden refresh) only — see § "What's
done" first row block. PC-5 test + evidence patches were prepared,
verified failing for the new reason, and reverted to HEAD.

Full finding documented in [`.orchestrator/proposals/papercut-sweep-post-M035.md`](../proposals/papercut-sweep-post-M035.md) § "PC-5 status — DEFERRED + new finding (2026-05-10 papercut-sweep)".

**Operator action needed before any future SC-5 attempt**:
`! gh auth refresh -h github.com -s delete_repo` (the SC-5 cleanup()
trap silently absorbs 403s when the token lacks `delete_repo` scope,
leaking the throwaway repo). Then `gh repo delete bkellgren/1778456834-m032-fixture --yes` to clean up the leftover from this session's attempt.

**Two side issues to fold into the future closure work** (each a separate paper-cut candidate, neither addressed here):

1. SC-5 `cleanup()` trap silently absorbs `gh repo delete` 403s; should `say_fail` loudly so operator can recover.
2. Fixture-remote restore lives AFTER `cleanup()` in linear flow; on `wiki-init.sh` failure the restore is skipped. Should be wrapped into the EXIT trap.

### WS1 PC-7 — yaml-merge --replace-list-keys opt-in flag (still open)

M037 round-5 carryover. `scripts/lib/yaml-merge.sh` preserves operator's list values byte-identically — framework-side list-element changes don't propagate. Patch shape: add `--replace-list-keys=key1,key2` flag for opt-in list replacement. Default behavior unchanged (back-compat). Regression sweep: `git grep -ln 'yaml-merge.sh' scripts/ commands/ packaging/` — every call site must be re-tested. Full patch shape in proposal § PC-7. **Estimate**: ~1.5-2 h with regression sweep — recommend dedicated session.

### WS2 — Rename audit + verdict matrix (DONE)

WS2 done at commit `5c3f61d3` ("rename audit: close residue from M035 P01.5 sweep"). 11 audit sections classified into 5 buckets in [`.orchestrator/proposals/papercut-sweep-post-M035.md`](../proposals/papercut-sweep-post-M035.md) § "Rename audit verdict matrix". Final delta:

- 6 MISSED-RENAME (fixed in WS2 commit): `scripts/lifecycle/wiki-init.sh:172-173`, `scripts/lifecycle/run-update.sh:568`, `scripts/dispatch/adapters/runtime/codex.sh:142`, `scripts/migrate/migrate.sh:47`, `tests/installer-acceptance/m035-collision-exit-status.sh:71`, `specs/040-wiki-readability-decorator/spec.md:182`.
- 2 EXTERNAL-URL (fixed in WS2 commit): `scripts/verify/m014-p03-fetch.sh:73`, `tests/fixtures/m014-p03/sample-inbox.jsonl` (4 URLs).
- **2 DEFER-TO-WS3 (must update post-rename in lock-step with `git remote set-url`)**: `tests/m032-acceptance/p02-wiki-init-default-scope.sh:57+59` (defensive grep target for orchestrator's current name); `tools/verify/m032-p02-mkdocs-templating-and-self-application.sh` (multiple lines — self-application verifier asserts current `wiki/mkdocs.yml` resolves to `spec-kit-orchestrator`). Both flip to `orchestrator` after WS3 lands and `wiki/mkdocs.yml` re-templates from the renamed remote. **WS3 must include these two file updates as part of the rename execution.**
- N LEGITIMATE-HISTORICAL / RENAME-INSTRUCTION / OPERATOR-OWNED-WIP — documented in matrix; do not touch.
- N EXTERNAL-GH-side (`.git/config`, `gh repo` metadata) — handled by WS3.

### WS3 — Rename execution

Sequence (decided 2026-05-09; updated 2026-05-10 evening for WS2-done state):
1. **Push pending commits to main** first (`git push origin main`) so the upstream is in sync. There are 37+ pending commits + the 15 papercut-sweep-post-M035 commits. **Recommend merging the papercut branch to main BEFORE the rename push**, so the rename audit + paper-cut fixes are part of the pre-rename push. Or push papercut as a separate branch / PR — operator's call.
2. **Push the safety tag**: `git push origin v0.9.2-final-spec-kit-name`. Operator approved this in the original briefing (Option A — accept red X from `release.yml`'s npm-publish job failing at the `Verify tag matches package.json version` step). The npm-publish job is gated on `package.json` `version` matching the tag's stripped suffix; mismatch → exit 1, no publish. **Confirm GH secrets survived first**: `gh secret list --repo Build-Fractal/spec-kit-orchestrator` (expect NPM_TOKEN, HOMEBREW_TAP_TOKEN).
3. **Rename via gh CLI**: operator approved CLI-driven once green: `gh repo rename --repo Build-Fractal/spec-kit-orchestrator orchestrator`.
4. **Output operator-side mv commands** (do NOT execute — these invalidate CWD mid-session):
   ```bash
   cd ~/Sites
   mv spec-kit-orchestrator orchestrator
   cd orchestrator
   git remote set-url origin git@github.com:Build-Fractal/orchestrator.git
   git remote -v
   git pull --ff-only

   mv ~/.claude/projects/-Users-brettkellgren-Sites-spec-kit-orchestrator \
      ~/.claude/projects/-Users-brettkellgren-Sites-orchestrator
   ```
5. **Apply the WS2 DEFER-TO-WS3 file updates** (after `git remote set-url` lands so wiki regen templates against the new remote):
   ```bash
   # In renamed dir:
   bash scripts/wiki/wiki-generate-stubs.sh
   python3 scripts/wiki/wiki-decorate-build.py --root . --force
   bash scripts/wiki/wiki-generate-nav.sh
   # The 3-step regen re-templates wiki/mkdocs.yml from the new git remote.
   ```
   Then sed-edit (or hand-edit) these two files to match the new orchestrator identity:
   - `tests/m032-acceptance/p02-wiki-init-default-scope.sh:57+59` — change defensive grep target from `'spec-kit-orchestrator'` to `'orchestrator'` (the orchestrator's identity is now `orchestrator`, and the test's leak-check target must match).
   - `tools/verify/m032-p02-mkdocs-templating-and-self-application.sh` — flip all `spec-kit-orchestrator` → `orchestrator` AND `https://build-fractal.github.io/spec-kit-orchestrator/` → `https://build-fractal.github.io/orchestrator/` AND `https://github.com/Build-Fractal/spec-kit-orchestrator` → `https://github.com/Build-Fractal/orchestrator` AND the comment block on lines 10-11.

   Single commit: `rename(WS3 follow-up): flip M032 self-application verifier + p02 leak-check to new identity`.

6. **Post-rename verification** (operator runs in renamed dir):
   ```bash
   git remote -v
   gh repo view Build-Fractal/orchestrator --json name,url,description
   gh secret list --repo Build-Fractal/orchestrator
   ls ~/.claude/projects/ | grep orchestrator
   bash tests/m035-acceptance/run-acceptance-battery.sh
   bash tests/m032-acceptance/run-acceptance-battery.sh    # confirms SC-3 + p02 + m032-p02 self-app verifier all green post-flip
   bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M035
   ```

## Hard constraints (still apply)

1. **End on `main`** post-rename. Final state must be `git rev-parse --abbrev-ref HEAD == main`.
2. **Atomic commits per logical unit** via `git commit -F <message-file>` ([M021](../milestones/M021/index.md) PreToolUse Bash shape-guard rejects inline-HEREDOC under AP-008).
3. **Bash 3.2 / POSIX-sh-safe**, AD-19 single-script-file shape — no caller-side `$(... | ...)`, no plain subshells, no compound `&&` chains, no inline heredocs in command substitution. **In-function pipelines permitted**.
4. **NEVER write under `scripts/verify/`** — that's bulk-staged framework dir. Verifiers ship to `tools/verify/`.
5. **BSD portability**: `grep -qF -- '--flag'` for patterns starting with `--`; POSIX `[[:space:]]` not `\s`.
6. **Investigation patterns** under `scripts/util/`: `run-probe.sh`, `peek-files.sh`, `grep-files.sh`.
7. **Two operator-owned WIP files MUST NOT be touched**: `templates/phase-plan.md`, `.orchestrator/direct-mode-execution-log.jsonl`. Verify with `git diff main...papercut-sweep-post-M035 -- templates/phase-plan.md .orchestrator/direct-mode-execution-log.jsonl` → empty.

## Detached-HEAD workaround now obsolete (PC-6)

Pre-PC-6: every battery run detached HEAD; manual `git checkout main` (or `git checkout papercut-sweep-post-M035`) required afterward. **Post-PC-6 (commit `68c619b8`)**: the rollback test traps EXIT, detects detached HEAD, and re-checks-out the original branch automatically. Verified via `tools/verify/papercut-rollback-no-detach.sh` → `BATTERY: pass=3 fail=0`. The fresh session should not have to manually re-attach after running the battery.

## Files / commits to read first in fresh session

1. [`.orchestrator/proposals/papercut-sweep-post-M035.md`](../proposals/papercut-sweep-post-M035.md) — full sweep brief with PC-5, PC-7, and "Rename audit verdict matrix" placeholder.
2. [`.orchestrator/proposals/papercut-sweep-post-M035-HANDOFF.md`](../proposals/papercut-sweep-post-M035-HANDOFF.md) — this file.
3. [`.orchestrator/milestones/M035/M035-SUMMARY.md`](../milestones/M035/M035-SUMMARY.md) § "Caveats and follow-ups" — original 7-paper-cut catalog.
4. `git log --oneline papercut-sweep-post-M035 ^main` — what landed.
5. `bash tests/m035-acceptance/run-acceptance-battery.sh` — confirm green baseline before continuing.

## Estimated remaining time (post-2026-05-10 evening)

- WS1 PC-5: DEFERRED (full closure is milestone-grain, not paper-cut). See proposal § "PC-5 status — DEFERRED + new finding".
- WS1 PC-7: ~1.5-2 h (regression sweep over every `yaml-merge.sh` call site is load-bearing). Recommend dedicated session.
- WS2: DONE (commit `5c3f61d3`).
- WS3: ~30 min orchestrator-side (pre-rename push, safety tag, gh repo rename, WS3 follow-up commit for the two DEFER-TO-WS3 files) + ~5 min operator-side mvs.

**Total remaining**: ~2-2.5 h focused work + ~5-10 min operator side.

## Operator quick-reference — actions needed before next session

1. **Throwaway repo cleanup** (from this session's failed SC-5 attempt):
   ```bash
   ! gh auth refresh -h github.com -s delete_repo
   gh repo delete bkellgren/1778456834-m032-fixture --yes
   ```
   The gh auth refresh is a one-time scope grant; future SC-5 attempts will then auto-clean their throwaways.

2. **WS3 timing**: WS3 may proceed any time after PC-7 lands (or in parallel if PC-7 is deferred — they're independent). PC-5 is no longer a WS3 prerequisite.
