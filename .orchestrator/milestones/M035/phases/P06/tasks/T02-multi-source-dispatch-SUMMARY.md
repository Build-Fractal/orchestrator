---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P06"
milestone: "M035"
provides:
  - "multi-source-dispatch (scripts/lifecycle/run-update.sh four-arm case for git/npm/homebrew/none + resolve_update_source helper + persist_update_source helper + AD-5 detection ordering with install-meta.txt runtime= probe + npm root -g presence + brew --prefix Cellar presence + git fallback + single-resolve persistence) + D014 decision (AD-5 detection ordering for orchestrator:update) + task-grain verifier (m035-p06-multi-source-dispatch-shape.sh BATTERY pass=13)"
requires:
  - "from:M035/P06-T01 what:update_source-VALID_KEYS-registration-D012-heading-shape-precedent from:M035/P05-T02 what:rollback-block-end-anchor-and-source-repo-validation-insertion-point"
affects:
  - "P06/T03 (consumes the four-arm dispatch + T03-hook comment markers in npm/homebrew arms for update_run JSONL emission),P06/T04 (consumes D014 + the four-channel command surface for commands/update.md doc),P06/T05 (consumes the dispatch matrix for acceptance-battery cross-channel coverage)"
key_files:
  - "scripts/lifecycle/run-update.sh,.orchestrator/DECISIONS.md,tools/verify/m035-p06-multi-source-dispatch-shape.sh"
key_decisions:
  - "D014 (AD-5 detection ordering for orchestrator:update: install-meta.txt runtime= first, then npm global presence, then brew formula presence, then git fallback; non-git resolutions persist to config.yml via sed-replace-or-append; git fallback intentionally does NOT persist)"
patterns_established:
  - "inline-helpers-preserve-AD-19-single-script-shape,colon-fall-through-arm-preserves-byte-equivalence-on-existing-path,first-match-wins-detection-with-presence-not-PATH,single-resolve-via-persistence-with-git-fallback-suppression,verifier-PATH-shim-pattern-for-package-manager-presence-tests"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P06/tasks/T02-multi-source-dispatch-PLAN.md"
duration: "35m"
verification_result: "pass"
completed_at: "2026-05-09T23:30:54Z"
---

T02 ships the multi-source dispatch logic in scripts/lifecycle/run-update.sh: orchestrator:update now reads update_source from .orchestrator/config.yml (via T01's registered key) and routes to one of four channels — git (the existing path, byte-identical for git-source consumers via : fall-through), npm (npm update -g @build-fractal/orchestrator), homebrew (brew upgrade orchestrator), or none (operator opt-out, exit 0 silently). When update_source is absent, AD-5 detection resolves the channel via install-meta.txt runtime= field first, then npm global presence, then brew formula presence, then git fallback. Detected non-git resolutions persist back to config.yml via sed-replace-or-append for single-resolve discipline; git fallback is intentionally NOT persisted to keep fresh consumer configs noise-free.

The two helpers (resolve_update_source + persist_update_source) live INSIDE run-update.sh rather than as separate scripts to preserve AD-19 single-script-file shape for the dispatch surface. The git arm uses a colon-fall-through (case body :) so the existing source-repo validation + install dispatch (formerly the only path) stays byte-identical for git-source consumers — wrapped, not rewritten. The pre-existing dry-run output was extended with a canonical would_invoke=bash <installer> --project-dir <project> --force line so all four arms emit the unified P05-T05 would_invoke= convention.

D014 records the AD-5 detection ordering decision verbatim with rationale (provenance trumps discovery; curl-pipe-bash collapses to npm per D007/D009 single-source-of-truth; detection gates on installed-package presence not just package-manager PATH; single-resolve persistence with git-fallback suppression). D014 mirrors D012's heading-shape (T01 just landed in that shape so the cohort stays consistent).

The verifier (~290 lines, AD-19 single-script-file shape, sources scripts/lib/errors.sh) covers 13 assertions: structural shape (case + four arms + two helpers + four would_invoke= strings + D014 anchor), four channel-fixture --dry-run round-trips against explicit update_source: values, AD-5 detection resolution + persistence side-effect verification, and unknown-value FAIL branch. The npm and homebrew arms use PATH-shim pattern with fake npm/brew binaries that respond only to the specific subcommands the dispatch invokes (npm root -g, brew --prefix), with fake roots/prefixes pointing at temp dirs carrying the expected package directories. This makes the verifier deterministic across environments regardless of whether real npm or brew is installed.

JSONL emission is T03's territory; T02 leaves T03-hook comment markers in the npm and homebrew arms (success path, post-rc capture). T02 itself does NOT emit. The git arm's emission lives in the existing post-installer success path which T03 will hook into.

## Patterns established

- Inline-helpers preserve AD-19 — resolve_update_source and persist_update_source are shell functions inside run-update.sh, not separate scripts. Keeps the single-script-file dispatch surface intact while letting helpers be unit-tested via verifier fixtures.
- Colon fall-through arm — the git arm's body is just : (no-op) so control falls through into the existing dispatch below. Diff stays minimal; existing path is byte-equivalent for git-source consumers.
- First-match-wins with presence not PATH — AD-5 step 2 (npm) requires both command -v npm AND a directory probe at npm root -g for the @build-fractal/orchestrator package; step 3 (homebrew) requires both command -v brew AND a directory probe at brew --prefix Cellar/orchestrator. Having the package manager on PATH without our package present should NOT resolve to that channel.
- Single-resolve persistence with git-fallback suppression — detected non-git sources persist to config.yml so subsequent runs skip detection spawn cost; git fallback is the implicit default and persisting it would noise up every fresh consumer's config.
- Verifier PATH-shim pattern — fake npm/brew binaries in fixture-controlled PATH directories let the verifier exercise the npm and homebrew presence checks deterministically. The shims respond only to the specific subcommands the dispatch invokes; everything else exits 1 with a descriptive stderr message.

## Verification

- bash tools/verify/m035-p06-multi-source-dispatch-shape.sh → BATTERY: pass=13 fail=0
- All 13 PASS lines match the plan's Expected Output verbatim.
- T01 regression: bash tools/verify/m035-p06-config-schema-shape.sh → BATTERY: pass=7 fail=0 (no regression).

## Caveats

- The git-arm dry-run output now emits an additional would_invoke=bash <installer> --project-dir <project> --force line on top of the pre-existing two-line DRY RUN block. Functional consumers running real updates see no change; --dry-run consumers see one extra line. Trade-off accepted to satisfy the plan's Must-Have item that all four would_invoke= strings be present in run-update.sh under the unified P05-T05 convention.
- A duplicate project-dir-existence check is now performed: once at the start of the multi-source dispatch (so resolve_update_source has a real path to read config from) and once in the existing source-repo-validation block (line ~297). Cost is negligible; the check is idempotent. Trade-off accepted to keep the existing source-repo-validation block byte-identical.
- Two unrelated unstaged files (templates/phase-plan.md, .orchestrator/direct-mode-execution-log.jsonl) were left untouched per the dispatch instructions — they are operator-owned WIP.

## Out-of-scope-found

- T03 territory (update_run JSONL emission) — T03-hook comment markers are present in the npm and homebrew arms; T03 inserts the actual emission calls. The git arm's emission point is the existing post-installer success path (line ~354).
- T04 territory (commands/update.md doc) — D014 cross-references commands/update.md, but the doc itself is T04's responsibility.
- T05 territory (acceptance battery cross-channel coverage) — T02 verifies dispatch shape; T05 will exercise the actual npm/homebrew binaries in CI.
