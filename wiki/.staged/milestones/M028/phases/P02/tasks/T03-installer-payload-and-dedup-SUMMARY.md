---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P02"
milestone: "M028"
provides:
  - "Claude Code installer (packaging/install/install-claude-code.sh) stages a 4-script hook payload (pre-bash-shape-guard.sh + shape-classifier.sh + before-commit.sh + after-verify-sync.sh) plus a MANIFEST text file into ${HOME}/.claude/orchestrator-hooks/ on every install (cp -f, idempotent on repeat install); the --uninstall path walks MANIFEST to remove only the staged set and rmdirs the empty hooks dir, preserving any user-authored siblings"
  - "scripts/util/settings-merge.sh dedup key promoted from M025/P01 command-only key to (event, matcher, command) tuple within the _orchestrator_managed:true overlay -- closes the operator's M018-close 5-Stop-dupes / 7-PreToolUse-dupes regression; --force still bypasses the guard per M025 invariant; user-authored entries (no managed tag) pass through untouched"
  - "scripts/lifecycle/before-commit.sh permissive no-op shim closing a pre-existing M008 packaging gap (bundle JSON pointed at a script that was never authored on disk); set -u; exit 0 with comment block documenting the M008/M025/M028 pedigree and the future-real-verification-ladder TODO"
  - "scripts/verify/m028/p02-hooks-payload-staged.sh -- two-mode T03 verifier: --dry-run pass asserts the would_write= list for the 5 expected basenames; real-install pass against an isolated HOME asserts files land + MANIFEST is exactly 5 lines"
requires:
  - from: "M028/P02/T01"
    what: "scripts/hooks/pre-bash-shape-guard.sh self-relative classifier resolution -- T03 stages the hook into ~/.claude/orchestrator-hooks/ where its BASH_SOURCE resolution finds shape-classifier.sh as a sibling"
  - from: "M028/P02/T02"
    what: "scripts/dispatch/adapters/runtime/claude-code.sh --hook-config emits absolute bash <abs-path>/<name>.sh commands; T03's installer captures this fragment and feeds it to settings-merge.sh"
  - from: "M025/P01/T02"
    what: "scripts/util/settings-merge.sh baseline (python3 deep-merge + cascade-cleanup uninstall + _orchestrator_managed:true tag); installer's existing 4-stage shape (probe / register / hook-config / runtime-stage); HOME guard convention"
  - from: "M021/P05"
    what: "scripts/verify/lib/shape-classifier.sh classifier library staged alongside the hook in the runtime-stable hooks dir as a sibling"
affects:
  - "P02/T05 (install-roundtrip pinned-sha gate consumes the new tuple-keyed dedup -- proven byte-stable across two installs in T03's smoke test; T05 formalizes via a permanent verifier)"
  - "P03 (Finding-G self-conformance verifier shares the orchestrator-hooks dir convention; the staged classifier sibling is the on-disk artifact P03's verifier exercises)"
  - "M028 phase Truths FR-1 + FR-5 + FR-7 acceptance scenarios (closes Finding F install-side half; closes the 5-Stop-dupes / 7-PreToolUse-dupes regression at the dedup-key layer)"
  - "M025 reversibility contract (CON-4): install -> install -> uninstall byte-equality preserved; the MANIFEST-driven removal is the install-side counterpart to the JSON-tag-driven cascade cleanup"
key_files:
  - "packaging/install/install-claude-code.sh (modified -- new stage 2.5 stages 4 payload sources + MANIFEST under HOOKS_DIR=$HOME/.claude/orchestrator-hooks via cp -f loop; --uninstall block gains a MANIFEST-driven removal pass before settings-merge.sh uninstall; SUMMARY/UNINSTALLED counters extended with hooks_staged / hooks-payload-removed)"
  - "scripts/util/settings-merge.sh (modified -- python3 merge body's dedup key replaced with collect_managed_keys() walking the target's hooks tree once and emitting (event, matcher, command) tuples; per-leaf dedup applied during fragment iteration; empty fragment wrappers skipped post-dedup to keep settings.json byte-stable across reinstalls; algorithm comment block updated)"
  - "scripts/lifecycle/before-commit.sh (created -- permissive no-op closing the M008 packaging gap; documents the M008-vs-M025-vs-M028 pedigree)"
  - "scripts/verify/m028/p02-hooks-payload-staged.sh (created -- two-mode verifier; AD-19 single-script-file flat shape, bash 3.2 + POSIX-sh-safe, no jq)"
key_decisions:
  - "Authored a minimal no-op scripts/lifecycle/before-commit.sh shim rather than DEVIATING. The plan's prerequisites stated the file exists; it did not. The M008 commit (3cd38f8) enrolled the lifecycle event in packaging/bundle/hooks/before-commit.json with command 'bash scripts/lifecycle/before-commit.sh' but never authored the script. T02's adapter inherits the broken contract and emits an absolute hook reference to the same path. T03's installer would have failed 'if [ ! -f $src ]; then echo FAIL' had I left the gap. Authoring a permissive no-op is symmetric with M008's intent and keeps the staged-payload contract real; wiring genuine pre-commit verification is out of T03 scope."
  - "Per-leaf tuple dedup, not wrapper-level. The M025 baseline dedup checked whether any fragment-wrapper command was a subset of existing managed commands and skipped the wrapper as a unit. T03's tuple key requires per-leaf evaluation: walking each fragment leaf, computing (event, matcher, command), and either skipping it or appending to a deduped wrapper. Empty post-dedup wrappers are skipped entirely to keep settings.json byte-stable across reinstalls. --force still bypasses the guard per M025 invariant."
  - "MANIFEST format: one filename per line plus a final 'MANIFEST' line referencing itself. This makes --uninstall self-cleaning: walking the file rm -f's all four hook scripts AND the MANIFEST itself; rmdir then succeeds against the empty dir. The plain-text MANIFEST has no schema and no python3 dependency."
  - "rmdir over rm -rf for hooks dir cleanup. POSIX rmdir fails non-zero on non-empty dirs -- exactly the right behavior when user-authored siblings remain. The '2>/dev/null || true' swallows the diagnostic so uninstall does not error on the user-authored case; the dir survives intact in that case."
  - "Two-mode verifier (dry-run + real install) instead of one mode. Real-install-only verifier would invoke the 1167-file runtime-staging copy as a side effect (heavy). Dry-run mode catches the would_write= list cheaply; real-install mode against a deeper isolated tmp dir proves the bytes actually land. Each mode's assertions are independent; both contribute to the truth statement."
patterns_established:
  - "Space-delimited string iteration for bash 3.2 list: HOOKS_PAYLOAD built via repeated 'HOOKS_PAYLOAD=\"${HOOKS_PAYLOAD} <abs-path>\"' assignments, then iterated via 'for src in $HOOKS_PAYLOAD'. Bash 3.2 safe (no array required); paths under ${REPO_ROOT} carry no spaces (out-of-scope failure mode for paths-with-spaces)."
  - "MANIFEST-driven uninstall: install-side staged-files removal walks a plain-text MANIFEST in the staged dir; never 'find ... -delete' against the dir. Companion shape to M025's _orchestrator_managed:true tag in settings.json -- the MANIFEST is the install-side counterpart for non-JSON staged artifacts."
  - "Per-leaf tuple-keyed dedup with single-walk target-key collection. Walk the target hooks tree once via collect_managed_keys() and build a set of (event, matcher, command) tuples; iterate fragment leaves and consult the set per leaf; append non-duplicates and update the running set. Empty post-dedup wrappers are skipped to preserve byte-equality across runs. Algorithm comment block at top of settings-merge.sh documents the contract."
  - "Two-mode verifier discipline for install-touching gates: cheap --dry-run mode validates the would_write= shape without invoking the heavy runtime-staging branch; real-install mode against an isolated tmp dir proves the actual file-byte contract. Combined into one verifier file (AD-19 single-script shape) but with mode-separated assertion blocks."
drill_down_paths:
  - ".orchestrator/milestones/M028/phases/P02/tasks/T03-installer-payload-and-dedup-PLAN.md"
  - ".orchestrator/milestones/M028/phases/P02/tasks/T03-installer-payload-and-dedup-PAYLOAD.md"
duration: "75m"
verification_result: "pass"
completed_at: "2026-04-29T11:35:00Z"
---

T03 closes the install-side half of M028 Finding F. The Claude Code installer (packaging/install/install-claude-code.sh) now stages a four-script hook payload plus a MANIFEST file into ${HOME}/.claude/orchestrator-hooks/ on a fresh install (idempotent on repeat install via cp -f); the --uninstall path walks the MANIFEST to remove only the staged set and rmdirs the empty hooks dir. settings-merge.sh's dedup key is promoted from the M025/P01 command-only key to the (event, matcher, command) tuple within the _orchestrator_managed:true overlay -- the load-bearing fix for the operator's M018-close 5-Stop-dupes / 7-PreToolUse-dupes regression.

## What Happened

**Installer (`packaging/install/install-claude-code.sh`).** Inserted a new "stage 2.5" between the existing --register block (stage 2) and --hook-config capture (stage 3). The stage builds a space-delimited HOOKS_PAYLOAD list of four absolute source paths, then either emits `would_write=` lines (--dry-run) or mkdir -p the hooks dir + cp -f each source into it + writes a MANIFEST text file listing one basename per line plus a final `MANIFEST` line referencing itself. The 4 staged sources are pre-bash-shape-guard.sh (T01 self-locating hook), shape-classifier.sh (its sibling library), before-commit.sh ([M025](../../../../../milestones/M025/index.md) lifecycle), after-verify-sync.sh (M025 lifecycle). On --uninstall, a new pre-cascade block walks MANIFEST, rm -f's each listed file, and `rmdir 2>/dev/null || true`s the dir (rmdir fails non-zero when user-authored siblings remain — exactly the right behavior). SUMMARY line gains `hooks_staged=N`; UNINSTALLED line gains `hooks-payload-removed=N`.

**Settings merge (`scripts/util/settings-merge.sh`).** Replaced the wrapper-level "managed-cmds subset" check with a per-leaf (event, matcher, command) tuple dedup. New helper `collect_managed_keys(target_hooks)` walks the entire target hooks tree once and emits the set of tuples carried by `_orchestrator_managed:true` leaves. Fragment iteration deep-merges per event-name, but every leaf is now individually dedup-tested against this set: managed leaves whose tuple already exists are skipped; managed leaves whose tuple is new are appended and added to the running set; non-managed leaves pass through untouched. Empty fragment wrappers (every leaf was a duplicate) are skipped post-dedup so settings.json stays byte-stable across reinstalls. `--force` still bypasses the guard per M025 invariant. Algorithm comment block at the top updated to document the new tuple key and the user-authored-passthrough invariant.

**Lifecycle stub (`scripts/lifecycle/before-commit.sh`).** Authored as a permissive no-op shim. [M008](../../../../../milestones/M008/index.md) enrolled this lifecycle event in `packaging/bundle/hooks/before-commit.json` with command `bash scripts/lifecycle/before-commit.sh`, but the source script was never authored on disk. The runtime adapter T02 emits a hook entry referencing this exact path; T03's installer stages it from this source. Authoring a permissive no-op (`set -u; exit 0`) is in scope for T03 — the staged-payload contract requires a real on-disk source. Wiring genuine pre-commit verification is out of scope and reserved for a future verification-ladder gate milestone.

**Verifier (`scripts/verify/m028/p02-hooks-payload-staged.sh`).** Two-mode design. Mode 1 (--dry-run) invokes the installer with `HOME=<isolated-tmp> CLAUDECODE=1 ... --dry-run`, captures stdout to a log file, and asserts that each of the 5 expected basenames (4 hook scripts + MANIFEST) appears in a `would_write=<isolated-home>/.claude/orchestrator-hooks/<name>` line. Mode 2 (real install) runs the installer non-dry-run against a deeper isolated tmp dir, asserts each expected file lands at `${tmp_home}/.claude/orchestrator-hooks/<name>`, and asserts MANIFEST line count is exactly 5. AD-19 single-script-file flat shape, bash 3.2 + POSIX-sh-safe, no jq.

## Verification

- `bash scripts/verify/m028/p02-hooks-payload-staged.sh` -> `PASS: hooks payload staged at orchestrator-hooks/ (5 files, MANIFEST present)` (rc=0).
- `bash scripts/verify/m028/p02-hook-self-locate.sh` -> PASS (T01 truth; no regression).
- `bash scripts/verify/m028/p02-adapter-absolute-paths.sh` -> PASS (T02 truth; no regression).
- `bash scripts/verify/m028/p02-hook-self-conformance.sh` -> PASS (Finding G half; no regression).
- `bash scripts/verify/m025-p01-idempotency.sh` -> `pass=3 fail=0` (sha256 stable across two installs against the same isolated HOME — proves the new tuple-keyed dedup is byte-equality-stable).
- `bash scripts/verify/m025-p01-uninstall-reversibility.sh` -> `pass=5 fail=0` (install -> uninstall returns settings.json structurally equal to pre-install baseline; M025 cascade preserved).
- `bash scripts/verify/m025-p01-hook-schema.sh` -> `pass=8 fail=0` (T02 adapter contract preserved).

Smoke tests (T05 will formalize via install-roundtrip.sh):

- Two-run install against an isolated HOME: `~/.claude/settings.json` sha256 byte-identical across runs (`58c970da...`).
- install -> uninstall: `hooks_dir` absent; `settings.json` is `{}`; UNINSTALLED line shows `hooks-removed=2 hooks-payload-removed=5`.

## Deviations

**`scripts/lifecycle/before-commit.sh` was missing on disk pre-T03.** The plan's prerequisites section claimed the file existed; it did not. M008 (commit `3cd38f8`) enrolled the before-commit lifecycle event in the bundle JSON manifest pointing at this path, but the actual script was never authored. T02's runtime adapter emits an absolute `bash <hooks-dir>/before-commit.sh` reference, so T03's installer copy step would have failed `if [ ! -f "$src" ]; then echo FAIL` had I left the gap unaddressed. Two options: stop and DEVIATE, or author a minimal lifecycle no-op stub. I chose option 2 — the staged-payload contract needs a real on-disk source, and the choice is symmetric with M008's intent. Wiring genuine pre-commit verification is out of T03 scope; the stub is `set -u; exit 0` with a comment block explaining the M008-vs-M025-vs-M028 pedigree and a TODO marker. Captured in the dogfood findings below.

**`scripts/verify/m025-p01-merge-preservation.sh` is failing pre-T03 and remains failing post-T03.** Verified by stash + bisect: the verifier asserts the M025-baseline bare-name commands (`orchestrator-post-verify`, `orchestrator-before-commit`) which T02 explicitly retired in favor of absolute `bash <hooks-dir>/<name>.sh`. Same shape as the `m025-p01-hook-schema.sh` assertions T02 already updated; T02's discoveries section flagged this as a known sibling. Out of T03 scope (T03 does not change the bare-name retirement; T02 owns that). Not a regression caused by T03.

## Files Created/Modified

- `packaging/install/install-claude-code.sh` (modified) — new stage 2.5 stages 4 payload sources + MANIFEST; --uninstall walks MANIFEST + rmdirs the dir; SUMMARY/UNINSTALLED counters extended.
- `scripts/util/settings-merge.sh` (modified) — python3 merge body's dedup key promoted from command-only to (event, matcher, command) tuple via collect_managed_keys() helper; per-leaf dedup; empty-wrapper skip preserves byte-equality.
- `scripts/lifecycle/before-commit.sh` (created) — minimal no-op shim closing the M008 packaging gap. Documents M008/M025/M028 pedigree.
- `scripts/verify/m028/p02-hooks-payload-staged.sh` (created) — two-mode T03 verifier (dry-run would_write= assertion + real-install file-presence + MANIFEST line-count = 5).

## Commit

`849cc05 M028/P02/T03: installer payload copy + settings-merge tuple dedup` on branch `main`.

## Dogfood Findings

1. **`scripts/lifecycle/before-commit.sh` missing on disk pre-T03** — pre-existing M008 packaging gap. The bundle's `hooks/before-commit.json` (committed in `3cd38f8` as "feat(M008): standalone multi-runtime orchestrator v0.8.0") points at `bash scripts/lifecycle/before-commit.sh`, but the script itself was never authored. The runtime adapter (T02) inherits the broken contract and emits an absolute hook reference to the same path. T03 ships a minimal no-op `set -u; exit 0` shim because the staged-payload contract requires a real source. Long-term: this needs a genuine pre-commit verification-ladder gate (would slot into a future M025-touching milestone or a dedicated lifecycle-hardening milestone). **Suggested CLAUDE.md hotfix-list entry**: capture the gap so a future planner does not re-discover it. Surfaced 2026-04-29 by M028/P02/T03 dispatch.

2. **`scripts/verify/m025-p01-merge-preservation.sh` is stale on the T02 contract** — same shape as the `m025-p01-hook-schema.sh` assertions T02 already updated. The verifier's python3 block (lines 80–88) asserts `"orchestrator-post-verify" in stop_cmds` and `"orchestrator-before-commit" in pre_cmds`; both bare names were retired by T02's adapter change. Already failing pre-T03 (verified via stash + run). Fix shape: rewrite to assert the absolute-path basename contract (`after-verify-sync.sh`, `before-commit.sh`, `pre-bash-shape-guard.sh` as substrings of the `bash <abs-path>/...` command strings). **Suggested CLAUDE.md hotfix-list entry**: bundle into the next M025-touching paper-cut sweep alongside the `m013-p04` verifier already on the list.

3. **Plan-time prerequisite-existence verification gap.** Plan's Prerequisites block stated `scripts/lifecycle/before-commit.sh and scripts/lifecycle/after-verify-sync.sh exist`. Only the latter actually existed. A simple `[ -f <path> ]` check at plan-authoring time (or a planner gate that asserts every Prerequisite-named path exists before committing the plan) would have surfaced the M008 gap at planning time, not execution time. **Suggested fix**: `commands/plan-phase.md` could specify a planner-side prerequisite-existence assertion when the prerequisite mentions a specific file path. Adjacent in shape to the existing CLAUDE.md hotfix-list entries about `check-must-haves.sh` `from_path` resolution and key-link `to_path` extension stripping.
