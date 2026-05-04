# Paper-Cut Sweep: GSD 2 Adoption — 2026-05-04

**Captured**: 2026-05-04 from the GSD-2 adoption scan (`gsd-2-adoption-scan-2026-05-04.md`).
**Shape**: Single bundled PR. Six independent paper-cut hotfixes that share the same provenance (GSD v2.79+v2.80 lessons).
**Branch name**: `papercut-gsd2-scan-2026-05-04` (not yet created).
**Sequencing**: **Hold start until M033/P05/T05 closes** to avoid touching shared paths (`scripts/state/`, `scripts/verify/`, `references/`, `tests/`) while the milestone-close is in flight. After M033-VALIDATED is on disk, this PR is unblocked.
**Effort estimate**: ~3 days total — each item is independent and small.

## Why bundled

All six items share the same provenance (one scan), the same shape (paper-cut hotfix), and the same blast radius (defensive hardening, no behavior change for happy-path users). Bundling them gives reviewers one PR to read against one proposal document instead of six PRs each citing the same scan.

Items 6, 7, 13, 14 from the parent scan land elsewhere (M028 follow-up, M034 brief amendment, post-launch deferral, constitution-amendment bundle) and are NOT in this sweep.

## Items in scope

### Item A — `realpath` audit on state resolvers (scan item 5)

**Source**: GSD `GsdWorkspace` work + canonicalize commits (v2.79). The 9 tests cover symlinked-worktree double-locking, canonical-base resolution after chdir, path-cache invalidation on resolve.

**What ships**:
- Audit pass on `scripts/state/resolve-root.sh` and every consumer that caches a resolved path
- Every cached resolved-root must go through `readlink -f` (Linux) / `realpath` (BSD/macOS) before caching
- Lock-file paths in `.orchestrator/locks/` resolved canonically before lock acquisition
- New test `tests/regression/state-root-symlink-canonicalization.sh` — symlinked-worktree fixture that fails before the fix and passes after

**Files touched**:
- `scripts/state/resolve-root.sh` (modify)
- `scripts/state/*` (audit + targeted fixes)
- `tests/regression/state-root-symlink-canonicalization.sh` (new)
- `references/RUNTIME-ASSUMPTIONS.md` (note the canonicalization invariant)

**Verification**: New test fails on a fixture pre-fix, passes post-fix. Existing tests don't regress.

### Item B — Description-as-trigger audit (scan item 4)

**Source**: GSD's `spike-wrap-up` skill explicit guidance: *"DESCRIPTION IS THE DISCOVERABILITY SIGNAL. The `description` field is the primary signal the agent uses to judge relevance — write it as keywords the future agent will plausibly encounter, not a summary."*

**What ships**:
- One-day audit pass on every `commands/*.md` frontmatter `description` field
- Audit checklist + lint script: minimum length (120 chars), trigger keywords present, no summary-prose, examples of when to load
- New `scripts/verify/lint-command-descriptions.sh` mechanical lint
- Re-write any failing description in place

**Files touched**:
- `commands/*.md` (frontmatter only — body untouched)
- `scripts/verify/lint-command-descriptions.sh` (new)
- `references/COMMAND-DESCRIPTION-GUIDELINES.md` (new — captures the trigger-vs-summary discipline)

**Verification**: `lint-command-descriptions.sh` exits 0 on the full surface.

**Note**: M033's command surface lands during P05/T05. Run this audit AFTER M033-VALIDATED lands — otherwise we're auditing a moving target. The post-M033 timing is the right window.

### Item C — Doctor enrichment (scan item 8)

**Source**: GSD v2.79 doctor checks for orphan milestone directories, exhausted run-uat retry counters, DB-backed stale locks.

**What ships**:
- `orchestrator:doctor` adds checks for:
  - Orphan phase dirs (no manifest under `.orchestrator/milestones/<id>/phases/<id>/`)
  - Exhausted retry counters from M019 JSONL stream (configurable threshold)
  - Stale `.orchestrator/locks/*.lease` files (composes with the future lease pattern from item 6 of parent scan; works on existing `.lock` files for now)
  - Drifted `KNOWLEDGE-INDEX.md` vs filesystem (graph entry references missing file, or filesystem MEM has no index entry)
- Doctor emits structured JSONL findings; existing `--fix` mode applies safe remediations only
- Each new check is opt-out via `doctor.skip-checks=<csv>` config

**Files touched**:
- `scripts/diagnostics/run-doctor.sh` (modify)
- `scripts/diagnostics/checks/check-orphan-phase-dirs.sh` (new)
- `scripts/diagnostics/checks/check-exhausted-retries.sh` (new)
- `scripts/diagnostics/checks/check-stale-locks.sh` (new)
- `scripts/diagnostics/checks/check-knowledge-index-drift.sh` (new)
- `tests/diagnostics/*` (new test per check)

**Verification**: Each check has a fixture-based test that produces the finding, then a passing fixture that doesn't.

### Item D — Anthropic prompt-cache regression test (scan item 9)

**Source**: GSD v2.79 fix `pi-coding-agent,gsd: preserve Anthropic prompt cache (#5019)` — explicit fix because something broke the cache breakpoint position. Defensive insurance against the same drift in our M030/M031 efficiency stack.

**What ships**:
- `tests/regression/prompt-cache-breakpoint.sh` — pins the dispatch-payload prefix structure (cache breakpoint position) for Quick / Standard / Full profiles
- Snapshot fixture: known-good payload prefixes per profile, byte-deterministic
- Fires `QUICK_BUDGET_DRIFT` (existing M031 surface) if breakpoint position shifts
- Runs as part of pre-merge CI

**Files touched**:
- `tests/regression/prompt-cache-breakpoint.sh` (new)
- `tests/fixtures/prompt-cache/*` (new — snapshot fixtures per profile)
- `scripts/dispatch/build-context.sh` (no change; the test verifies its current shape)

**Verification**: Test passes against the current build-context.sh output. Fails if a future PR perturbs the cache-prefix position. This is a *guard* test, not a probe.

### Item E — Safety bundle (scan item 11)

**Source**: GSD v2.79 fixes — `refuse project writes when run from $HOME`, `block startup on git index lock`, `sanitize generated commit subjects`, `honor skip git during init`.

**Sub-items**:

**E1 — `$HOME` write guard**:
- New `scripts/util/refuse-home-writes.sh` invoked at the top of every state-mutating command
- Refuses to run if `pwd` resolves to `$HOME` OR no `.orchestrator/` ancestor exists within 5 directory levels
- Exit code 78 (configuration error) with a clear diagnostic

**E2 — Git index lock dispatch precondition**:
- Modify `scripts/dispatch/dispatch-interface.sh` to check for `.git/index.lock` before dispatch
- Abort with diagnostic if present (refuse to compete with another git operation)

**E3 — Commit subject sanitize**:
- New `scripts/verify/commit-subject-sanitize.sh` — mechanical lint on generated commit subjects
- Rules: no markdown syntax in subject, no leaked secret-shaped tokens, length cap 72 chars, single line
- Wired into commit-authoring paths (e.g., M033's potential commit messages, M013 GitHub-sync commit subjects)

**E4 — `orchestrator:init --no-git` verification**:
- M033's greenfield-empty branch likely already covers non-git context
- This sub-item is an *audit only* — read the M033 P01 + P02 outputs after M033 closes, verify `--no-git` flow works end-to-end, file a follow-up hotfix if it doesn't
- Captures finding in this PR's commit if a fix is needed

**Files touched**:
- `scripts/util/refuse-home-writes.sh` (new)
- `scripts/dispatch/dispatch-interface.sh` (modify — E2)
- `scripts/verify/commit-subject-sanitize.sh` (new)
- Wiring edits in commands/scripts that author commits (E3)
- Commands invoking state-mutating operations (E1 — wire `refuse-home-writes.sh` at the top)

**Verification**: Each sub-item has a fixture test. E1 fails when invoked from `$HOME`. E2 fails when `.git/index.lock` is present. E3 lints existing test fixtures with bad subjects.

### Item F — M013 GitHub-sync retry-boundary audit (scan item 12)

**Source**: GSD v2.79 retry-boundary fixes:
- `defer slice prs until completion`
- `keep failed task closure retryable`
- `avoid closing issues before delivery`
- `scope config cache by project`
- `use safe git environment`

**What ships**:
- 30-minute audit pass: read `scripts/integrations/github/*` and `commands/github-*.md` against the GSD fix list
- For each GSD fix, identify whether our M013 implementation has the equivalent boundary or not
- Capture findings in `tests/regression/m013-retry-boundary-audit.md` (audit log, not a test)
- Any actual misses become hotfixes within this PR (small) or are queued as follow-ups (if larger than a paper-cut)

**Files touched**:
- Read-only audit + audit-log file at `tests/regression/m013-retry-boundary-audit.md`
- Conditional fixes to `scripts/integrations/github/*` only if audit surfaces real misses

**Verification**: The audit log itself is the verification — every GSD fix has a row with our verdict (`equivalent boundary present` / `miss — fixed in this PR` / `miss — follow-up filed at <link>`).

## Sequencing within the PR

Suggested commit order (each commit independently revertable):
1. Item D (prompt-cache regression test) — pure addition, lowest risk
2. Item B (description-as-trigger audit) — frontmatter-only edits + new lint
3. Item A (realpath audit) — touches resolve-root.sh; needs careful test coverage
4. Item E (safety bundle) — four sub-items, can be sub-commits
5. Item C (doctor enrichment) — multiple new check scripts
6. Item F (M013 retry-boundary audit) — read-mostly audit pass

Optional: ship A, B, D as commit set 1 (smaller PR) and C, E, F as commit set 2 if reviewer prefers smaller PRs.

## Out of scope (parent scan items NOT in this sweep)

- **Item 1** (Context Mode → `orchestrator:exec`): new milestone candidate, post-launch
- **Item 2** (`--auto-chain` flag): folds into M029
- **Item 3** (project-shape classifier in `discuss`): independent post-M033 amendment
- **Item 6** (lease-based locks): M028 follow-up, larger than paper-cut
- **Item 7** (soft-warning verdict tier): M034 brief amendment, already landed
- **Item 10** (auto rate-limiting + reactive parallelism): defer-until-signal, post-launch
- **Item 13** (spike → durable skill bridge): defer-until-signal, post-launch
- **Item 14** (delegation-policy table): bundles with constitution-amendment, separate PR

## Open questions

1. **Bundle into one PR or split?** Recommendation: one PR with logically-grouped commits. Reviewer can request a split if it's too much to read.
2. **Is M013 audit (Item F) low-stakes enough to land here, or should it route through a separate review?** Recommendation: include here. The audit itself is read-only; any real fixes are small.
3. **Item B (description-as-trigger) is a moving target until M033 closes.** Run B AFTER M033-VALIDATED, not before. Confirmed in the body above.

## Cross-references

- Parent scan: `gsd-2-adoption-scan-2026-05-04.md`
- M034 brief amendment (item 7): `M034-interactive-review-gates.md` (already landed)
- Delegation-policy bundle (item 14): `delegation-policy-table.md` (separate PR window)
- Constitution amendment companion: `constitution-amendment-inclusion-criteria.md`
- M021/M028 hardening track precedent: `M028-autonomous-hardening-v3.md`
