# Handoff — Paper-Cut Sweep Post-[M035](../milestones/M035/index.md) (Mid-Sweep)

**Date**: 2026-05-10
**Branch**: `papercut-sweep-post-M035` (8 commits ahead of `main`)
**Status**: WS1 5/7 paper-cuts done; WS1 PC-5 + PC-7 + WS2 + WS3 remaining.

## What's done (8 commits on branch)

```
68c619b8 paper-cut(rollback-test): trap-EXIT recovery for detached HEAD (Option A)        # PC-6
57bee626 paper-cut(byte-equivalence): BSD-portable EXCLUSION_LIST + spec fix              # PC-3
50ba0be9 paper-cut(decisions): dual-shape highest-id scanner in append-decision.sh        # PC-2
7c85827c paper-cut(verify): extend P01.5 allowlists to exclude wiki/                      # PC-4 follow-up
428fd5b4 paper-cut(verify): chmod +x on three M035 P00 verifiers                          # PC-4
85c023e8 wiki: regen stubs + decorate-build + nav after M035 close                        # PC-4 unmask fix
c3508444 paper-cut(probe): export REPO_ROOT in run-probe.sh + docstring update            # PC-1
41b6edcf paper-cut sweep: author post-M035 sweep brief                                    # proposal
```

**Battery state**: `BATTERY: pass=179 fail=0 skip=1` (P05 cosign-live skip is expected; gated by COSIGN_AVAILABLE + M035_P05_LIVE_RELEASE_DIR env vars).

**Notable side-discovery**: PC-4's chmod unmasked stale wiki state (decorate-build never run since [M037](../milestones/M037/index.md)). Fixed inline as the `wiki: regen stubs + decorate-build + nav` commit (`85c023e8`). PC-3's regex fix unmasked a real spec bug — `package.json` was marked `npm`-only in references/installation.md but it's present in all three channel staged trees (D007 single-source-of-truth tarball). Fixed inline by promoting `package.json`/`package-lock.json`/`node_modules/` to `all`-channel exclusion.

**Two operator-WIP files still untouched** as required: `templates/phase-plan.md`, `.orchestrator/direct-mode-execution-log.jsonl`.

## What remains

### WS1 PC-5 — wiki-init.sh --deploy bundle-stage wiki-deploy.sh
[M032](../milestones/M032/index.md) SC-5 carryover. `scripts/lifecycle/wiki-init.sh --deploy` step 2 expects `wiki-deploy.sh` in `$PROJECT_DIR` but fresh-project fixtures don't ship it. Patch shape: bundle-stage from `$REPO_ROOT/scripts/lifecycle/wiki-deploy.sh` if absent. Re-run `tests/m032-acceptance/run-acceptance-battery.sh`; SC-5 should flip from SKIP → PASS. Update [`.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md`](../milestones/M032/M032-ACCEPTANCE-EVIDENCE.md) Deferred-Validation Acknowledgment block. Full patch shape in [`.orchestrator/proposals/papercut-sweep-post-M035.md`](../proposals/papercut-sweep-post-M035.md) § PC-5.

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
