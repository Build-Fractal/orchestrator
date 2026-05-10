# Handoff — Paper-Cut Sweep Post-[M035](../milestones/M035/index.md) (Mid-Sweep)

**Date**: 2026-05-10 (initial author) / 2026-05-10 PM (re-handoff after baseline-recovery)
**Branch**: `papercut-sweep-post-M035` (10 commits ahead of `main`)
**Status**: WS1 5/7 paper-cuts done + 2 baseline-recovery commits; WS1 PC-5 + PC-7 + WS2 + WS3 remaining.

## What's done (10 commits on branch)

```
10a0ead8 paper-cut(c1-sweep): allowlist papercut-sweep-post-M035-HANDOFF.md               # baseline-recovery
feb1c337 paper-cut(wiki): regen for handoff doc nav entry                                 # baseline-recovery
84b601a4 paper-cut sweep: handoff doc for fresh session                                   # this doc
68c619b8 paper-cut(rollback-test): trap-EXIT recovery for detached HEAD (Option A)        # PC-6
57bee626 paper-cut(byte-equivalence): BSD-portable EXCLUSION_LIST + spec fix              # PC-3
50ba0be9 paper-cut(decisions): dual-shape highest-id scanner in append-decision.sh        # PC-2
7c85827c paper-cut(verify): extend P01.5 allowlists to exclude wiki/                      # PC-4 follow-up
428fd5b4 paper-cut(verify): chmod +x on three M035 P00 verifiers                          # PC-4
85c023e8 wiki: regen stubs + decorate-build + nav after M035 close                        # PC-4 unmask fix
c3508444 paper-cut(probe): export REPO_ROOT in run-probe.sh + docstring update            # PC-1
41b6edcf paper-cut sweep: author post-M035 sweep brief                                    # proposal
```

**Battery state (logical, not measured this session)**: expected `BATTERY: pass=179 fail=0 skip=1`. Direct measurement deferred — see "Baseline-recovery" section below.

**Notable side-discovery**: PC-4's chmod unmasked stale wiki state (decorate-build never run since [M037](../milestones/M037/index.md)). Fixed inline as the `wiki: regen stubs + decorate-build + nav` commit (`85c023e8`). PC-3's regex fix unmasked a real spec bug — `package.json` was marked `npm`-only in references/installation.md but it's present in all three channel staged trees (D007 single-source-of-truth tarball). Fixed inline by promoting `package.json`/`package-lock.json`/`node_modules/` to `all`-channel exclusion.

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

### WS1 PC-5 — [M032](../milestones/M032/index.md) SC-5 SKIP→PASS + evidence doc reconciliation

**Discovery this session — runtime fix is already shipped.** M035 P00 T04 (commit `1aba20e7`) wired the bundle-stage block in `scripts/lifecycle/wiki-init.sh:1146` already. `tools/verify/m035-p00-wiki-deploy-stage.sh` confirms: 8/8 PASS (anchor comment present, staging block precedes wiki-deploy.sh invocation, fixture-with-no-scripts/ test stages from `$REPO_ROOT` correctly). PC-5's runtime patch shape in proposal § PC-5 is therefore obsolete.

**Remaining PC-5 work is purely test + doc reconciliation**:

1. **Test patch** at `tests/m032-acceptance/p03-wiki-init-deploy-live.sh:47-60`: remove the `if [ ! -f "$FIXTURE/scripts/wiki/wiki-deploy.sh" ]; then ... exit 77; fi` precondition block. Replace with a comment referencing the M035 P00 T04 anchor in `wiki-init.sh`. Patch was prepared this session and verified; reverted before handoff to avoid mid-flight working-tree state.

2. **Live M032 acceptance battery run** — `bash tests/m032-acceptance/run-acceptance-battery.sh` after the test patch lands. SC-5 should flip from SKIP → PASS, and the battery should report `pass=11 skip=0 fail=0` (was `pass=10 skip=1 fail=0`). **Heavyweight live test** (~3-5 min): creates+pushes+deletes a private GitHub repo named `<timestamp>-m032-fixture` under the operator's account; configures GitHub Pages; deploys mkdocs site; curl-retries until 200; verifies served HTML; tears down. Operator approval recommended before pulling the trigger — the proposal authorizes it but it's a third-party action with side effects. `gh auth status` was confirmed authenticated this session (account `bkellgren`).

3. **Evidence doc patch** at [`.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md`](../milestones/M032/M032-ACCEPTANCE-EVIDENCE.md) (~10 touchpoints):
   - Line 7: `sc12_outcome: "skip=1 (SC-5 fixture-completeness precondition)"` → `sc12_outcome: "pass=11 skip=0 fail=0"`
   - Line 19: `BATTERY: pass=10 skip=1 fail=0` → `BATTERY: pass=11 skip=0 fail=0`
   - Lines 22-28: replace skip-reason explanation with PASS reference
   - Line 38 (SC-5 row in roll-up table): `SKIP` → `PASS` with note (live deploy passing post M035 P00 T04 staging fix; PC-5 commit SHA cross-ref)
   - Line 45 (SC-12 row): `pass=10 skip=1 fail=0` → `pass=11 skip=0 fail=0`
   - Line 53: `(10 pass + 1 skip)` → `(11 pass)`
   - Line 99: `(10 pass + 1 skip + 0 fail)` → `(11 pass + 0 skip + 0 fail)`
   - Line 101: SC-12 outcome mirror update
   - Lines 103-109: **also reconcile a separate stale claim** — these lines say "M032-VALIDATED marker: NOT WRITTEN" but the marker file IS present (empty, 0 bytes, written at milestone-close commit `1afeadba`). Update the note to reflect actual state.
   - Lines 111-133: replace "Notes — SC-5 Fixture-Completeness Deferred Ship-Shape Gap" section with a closure note pointing at M035 P00 T04 commit `1aba20e7` + this PC-5 commit SHA.

4. **Single PC-5 commit** bundling test patch + evidence doc patch. Recommended message: `paper-cut(M032/SC-5): retire fixture-completeness precondition + flip evidence to PASS (M035 P00 T04 closure)`. The proposal's old commit message (`paper-cut(wiki-init): bundle-stage wiki-deploy.sh from REPO_ROOT (M032 SC-5 fix)`) describes the runtime fix that already shipped under M035 P00 T04 — don't reuse.

Acceptance per proposal § "Acceptance & exit criteria": `M032 acceptance battery → BATTERY: pass=10 skip=0 fail=0 after PC-5 (SC-5 flipped to PASS)` (proposal note: actual will be `pass=11` not `pass=10` because SC-5 contributes a +1 PASS).

### WS1 PC-7 — yaml-merge --replace-list-keys opt-in flag
M037 round-5 carryover. `scripts/lib/yaml-merge.sh` preserves operator's list values byte-identically — framework-side list-element changes don't propagate. Patch shape: add `--replace-list-keys=key1,key2` flag for opt-in list replacement. Default behavior unchanged (back-compat). Regression sweep: `git grep -ln 'yaml-merge.sh' scripts/ commands/ packaging/` — every call site must be re-tested. Full patch shape in proposal § PC-7.

### WS2 — Rename audit + verdict matrix
Run the 9 audit greps in the original briefing (covered in `commands.md`-style; reproduced below). For each match, classify into 5 buckets (`LEGITIMATE-HISTORICAL`, `RENAME-INSTRUCTION`, `MISSED-RENAME`, `EXTERNAL-URL`, `OPERATOR-OWNED-WIP`). Append to the proposal's "Rename audit verdict matrix" section. Single commit `rename audit: close residue from M035 P01.5 sweep` for `MISSED-RENAME` + `EXTERNAL-URL` rows.

Audit commands (run all):
```bash
# 1 — any spec-kit-orchestrator residue (with documented exclusions)
git grep -niE 'spec-kit[- ]orchestrator' \
  | grep -vF tests/m035-acceptance/legacy-namespace-allowlist.txt \
  | grep -vF .orchestrator/proposals/M035 \
  | grep -vF .orchestrator/milestones/M035 \
  | grep -vF specs/039-packaging-distribution \
  | grep -vF .orchestrator/DECISIONS.md \
  | grep -vF CLAUDE.md \
  | grep -vF tests/fixtures \
  | grep -vF M035-VALIDATED

# 2 — old GitHub URLs
git grep -nE 'github.com[/:]Build-Fractal/spec-kit-orchestrator'

# 3 — old raw URLs
git grep -nE 'raw.githubusercontent.com/Build-Fractal/spec-kit-orchestrator'

# 4 — old npm scope
git grep -nE '@spec-kit/orchestrator'

# 5 — CHANGELOG (intentional historical, do NOT change)
git grep -nE 'spec-kit-orchestrator' CHANGELOG.md

# 6 — git internals
grep -rE 'spec-kit-orchestrator' .git/config .git/hooks/ 2>/dev/null

# 7 — wiki/
git grep -nE 'spec-kit-orchestrator' wiki/

# 8 — .github/
git grep -nE 'spec-kit-orchestrator' .github/

# 9 — package.json + bin/
git grep -nE 'spec-kit-orchestrator' package.json package-lock.json bin/

# GH-side surfaces (don't show in git grep)
gh repo view Build-Fractal/spec-kit-orchestrator --json description,homepageUrl,topics
git grep site_url wiki/
```

The shape-guard rejects compound-chain greps. Either run each line in isolation or use `scripts/util/grep-files.sh` if it suits. (Grep with single pipe is permitted — only chain-gt-2 is blocked.)

### WS3 — Rename execution

Sequence (decided 2026-05-09):
1. **Push pending commits to main** first (`git push origin main`) so the upstream is in sync. There are 37+ pending commits + the 8 papercut-sweep-post-M035 commits. **Recommend merging the papercut branch to main BEFORE the rename push**, so the rename audit + paper-cut fixes are part of the pre-rename push. Or push papercut as a separate branch / PR — operator's call.
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
5. **Post-rename verification** (operator runs in renamed dir):
   ```bash
   git remote -v
   gh repo view Build-Fractal/orchestrator --json name,url,description
   gh secret list --repo Build-Fractal/orchestrator
   ls ~/.claude/projects/ | grep orchestrator
   bash tests/m035-acceptance/run-acceptance-battery.sh
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

## Estimated remaining time

- WS1 PC-5: ~30-45 min (small-medium; M032 acceptance battery re-run).
- WS1 PC-7: ~1.5-2 h (regression sweep over every yaml-merge call site is load-bearing).
- WS2: ~45 min (audit + verdict matrix + single commit for fixes).
- WS3: ~30 min orchestrator-side + ~5 min operator-side mvs.

**Total**: ~3.5-4 hours of focused work + operator's 5 min at the end.
