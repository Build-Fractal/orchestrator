---
schema_version: "1.0"
type: context-draft
milestone: "M035"
status: finalized
created_at: "2026-05-07T00:00:00Z"
finalized_at: "2026-05-07T00:00:00Z"
---

## Architectural Decisions

### AD-1 — Two-layer sequencing (pre-launch dev-ergonomics + launch event)

M035 ships two thematically distinct work layers under one milestone:

- **Layer 1 (P00 + P01)** — pre-launch dev-ergonomics: fresh-machine install audit, bash 3.2 exit-code propagation fix (US-3), installer-managed `.gitignore` (US-4), `--mode=symlink|copy` install option (US-1), `orchestrator:status` version-drift warning (US-2), `speckit.orchestrator.*` → `orchestrator:*` namespace cohort rename (US-5, P01.5).
- **Layer 2 (P02–P06)** — launch event: npm publishing pipeline (US-6, P02), homebrew formula + tap (US-7, P03), curl-pipe-bash one-liner + GH release automation (US-8, P04), install-script integrity (US-9, P05), `orchestrator:update` multi-source dispatch (US-10, P06).

Layer 1 is genuinely self-consistent without Layer 2 — Layer 1 ships pre-launch dogfood velocity dividends regardless of Layer 2's timeline. Layer 2 is the launch event itself; Layer 1 is launch-blocking only because Layer 2 depends on it. This sequencing maps cleanly to the conversus deliberation's surviving "two-layer rationale" finding.

### AD-2 — Cross-channel byte-equivalence as Constitution Principle XVI compliance test

Every install channel (npm tarball, homebrew bottle, curl-pipe-bash) must produce byte-identical runtime layouts (verified by hash comparison). CON-5 declares this an acceptance test, not just an implementation goal. Each phase that introduces a new channel (P02/P03/P04) extends `tests/m035-acceptance/cross-channel-byte-equivalence.sh` with a per-channel install + hash-compare assertion. The CON-5 exclusion list (per-install metadata files: `.orchestrator/install-meta.txt`, `npm package-lock.json`, homebrew receipt files) is enumerated once in CON-5 and referenced by SC-10/SC-12/FR-14 — see Open Question #Q-G2 for the exact enumeration discussion.

### AD-3 — CI secrets hygiene as launch security baseline

Publishing-pipeline workflows (P02/P03/P04 CI configs) run secret-bearing steps **only on tag-push events**, never on PR runs. CON-6 declares this an acceptance test (PR-context dry-run probes that publishing steps are skipped or scoped). This is the mechanism that prevents a fork-PR exfiltration attack against npm/homebrew/sigstore credentials.

### AD-4 — M035 contributes the drift datum, M029 renders

The `orchestrator:status` version-drift warning (US-2) does **not** add new headline-status structure; it adds a single conditional line into M029's already-shipped headline block. M035 owns the datum (commit-SHA / version comparison logic against an upstream source) and the suppress-when-no-upstream-configured behavior. M029 owns the rendering. Cross-milestone composition is reading-only — M035 does not touch M029 code.

### AD-5 — `update_source` is detect-by-install-method-first, config-override-second

`orchestrator:update` dispatch reads `update_source: git|npm|homebrew` from `.orchestrator/config.yml`. When absent (the case for every pre-launch consumer), the source is auto-detected from install metadata (manifest record or `install-meta.txt`) and persisted to config for future runs. Spec recommendation per #Q-6 in spec.md.

### AD-6 — Cohort rename lands before P02 publishes

The `speckit.orchestrator.*` → `orchestrator:*` cohort rename (US-5) is sequenced as P01.5 — explicitly before P02 — because the npm package's first published version determines the canonical command-cohort prefix forever. Renaming after P02 would mean v1's published tarball carries the legacy name baked in. This is a hard sequencing constraint, not a preference.

### AD-7 — Conversus gate verdict BLOCK with mitigations routed as Open Questions

The Pass 3 gate produced verdict BLOCK with 9 surviving disputes. The spec routes:
- **P0 mitigations (MIT-1..MIT-5)** as Open Questions `#Q-G1..#Q-G5` for resolution at this discuss step.
- **P1 mitigations (MIT-6..MIT-8)** as Open Questions `#Q-G6..#Q-G8` for resolution at the relevant plan-phase (P01/P04/P06).
- **P2 mitigation (MIT-9)** as Open Question `#Q-G9` for resolution at P02 plan-phase.

Routing-as-Open-Questions counts as "incorporated" per the spec author's interpretation; the discuss step is the resolution stage for the P0 set.

### AD-8 — Wiki-stub-drift paper-cut folds into M035 pre-launch scope

`papercut-wiki-stub-drift.md` (filed 2026-05-07 from PBJ-central round-5 dogfood, commit `8c7c7da`) ships its Layer 1 fix (`scripts/diagnostics/wiki-stubs-fresh.sh` diagnostic + Pages pre-build gate) inside M035 P00 or P01. Placement decision deferred to roadmap (see Open Question on Layer-1 placement). Layer 2 (Pages-deploy notification visibility) is install-template scope and may stay outside M035 — see Open Question.

## Scope Boundaries

### In scope (per US-1..US-10, FR-1..FR-16, SC-1..SC-16)

- **Pre-launch (P00/P01)**: fresh-machine install audit on macOS bash 3.2; installer exit-code integrity (US-3); installer-managed `.gitignore` block for `install-meta.txt` (US-4); `--mode=symlink|copy` option in all three runtime installers (US-1); `orchestrator:status` drift datum + suppression policy (US-2); `speckit.orchestrator.*` → `orchestrator:*` rename across operational surfaces (US-5).
- **Launch event (P02–P06)**: npm publishing pipeline + `bin/orchestrator` entry point (US-6); homebrew formula + tap repo (US-7); hosted `install.sh` + GH release automation on `v*` tag push (US-8); detached signature + SHA-256 checksum + `--rollback` marker (US-9); `orchestrator:update` multi-source dispatch with `update_source` config + JSONL emission (US-10).
- **Tests**: cross-channel byte-equivalence (`tests/m035-acceptance/cross-channel-byte-equivalence.sh`); CI secrets-hygiene probe; per-channel install fixture; bash 3.2 exit-code regression fixture; rename allow-list enforcement.

### Out of scope (per spec's "this feature does not" paragraph)

- **No installer-internals re-architecture** (M025 territory).
- **No runtime-behavior changes** (every other milestone touches that).
- **No new project-bootstrap UX** (M033 territory).
- **No `orchestrator:status` rendering changes** (M029 territory; M035 contributes the drift datum, M029 renders).
- **No new versioning scheme** (SemVer already in use per `CHANGELOG.md`).
- **No docs-site or marketing-page launch** (separate scope, possibly a one-off project, not a milestone).
- **No Windows support in P02 postinstall** (per FR-8 platform guard, MIT-9 / `#Q-G9`).
- **No Codex CLI / Cursor publishing channels at launch** (CC-only launch posture; M009 covers multi-runtime parity audit post-launch).

### Boundary with M032 / M037

- **M032**: install-template `wiki-deploy.sh` bundled-staging fix (M032 SC-5 deferred-validation acknowledgment) folds into M035 P00 baseline-hardening — recommended at the time of M032 closure. Confirm in roadmap.
- **M037**: wiki-stub-drift paper-cut Layer 1 (filed today) folds into M035 P00 or P01. Confirm placement in roadmap.

### Boundary with M036

M035 makes no changes to the reference-corpus pipeline (M036a-shipped). The pre-pilot live-LLM smoke test for M036a P03 is a parallel pre-launch operational follow-up, not blocking M035.

## Design Constraints

- **CON-1**: Every install channel produces a byte-identical runtime layout (Constitution Principle XVI).
- **CON-2**: Publishing steps run only on `v*` tag-push events; never on PR runs (CI secrets hygiene).
- **CON-3**: Bash 3.2 compatibility for installer scripts — every operator-runnable shell script must work on macOS 12+ stock bash.
- **CON-4**: SemVer alignment — `CHANGELOG.md` top-line version is the source of truth; npm `package.json` version field, GH release tag, and homebrew formula `version` must match.
- **CON-5**: Cross-channel byte-equivalence test surface — exclusion list enumerated in CON-5; consumers reference "files enumerated in CON-5" not duplicate enumerations.
- **CON-6**: Publishing-pipeline secret scoping — secrets bind to tag-push contexts only.
- **CON-7**: Symlink-mode is opt-in via `--mode=symlink`; default remains `--mode=copy` to preserve install determinism for non-dogfooders.
- **External dependencies (P00 discovery)**: GitHub Pages (already in use for M032/M037 wiki); npm registry (publishing requires registered account + access tokens); homebrew tap repo (`homebrew-orchestrator` or chosen name, owned by the rename decision per `#Q-2`); GPG or sigstore signing infrastructure (`#Q-3` / MIT-relevant — choice deferred to P05 plan-phase).
- **Dependency on M033 friendly-tester pass `#Q-11`**: deadline 2026-05-12; protocol at `tests/m033-acceptance/friendly-tester-pass/protocol.md`. Findings on `orchestrator:start` may require P04/P06 documentation adjustments. Allocate contingency buffer.

## Open Questions

> The spec's own Open Questions section (`#Q-1..#Q-11` and `#Q-G1..#Q-G9`) is the authoritative list. The subset below is the **discuss-step resolution scope** — questions whose answers shape the roadmap structure or P00/P01 phase ordering. Questions routed to plan-phase resolution stay in the spec.

### `#Q-G1` (MIT-1, P0) — FR-7/A-8 external rename plan: Option A or Option B?

The spec offers two resolutions:
- **Option A**: Author `.orchestrator/proposals/m035-repo-rename-plan.md` covering the `spec-kit-orchestrator` → `orchestrator` repo rename strategy (timing, GitHub repo rename, README updates, npm scope decision dependency). Co-ship the rename in M035 per FR-7 as currently written. Adds SC-7b (asserts `grep 'spec-kit-orchestrator' CLAUDE.md README.md package.json` returns zero matches post-rename).
- **Option B**: Narrow FR-7 to in-tree namespace sweep only. The repo rename ships as a tracked paper-cut, contingent on a separate plan landing before P01.5. SC-7b is omitted.

**Recommendation**: Option B (narrow scope) unless an operator decision exists to commit to a near-term repo rename. Option A risks bundling repo-rename coordination (notify forks, transfer issues, redirect URLs) into a milestone that already carries publishing-pipeline complexity. Option B's "tracked paper-cut" is honest about the deferral and avoids slipping the rename indefinitely.

**Resolves**: spec amendment to FR-7 + (Option A) authoring of `m035-repo-rename-plan.md` + SC-7b activation. **Decided at**: this discuss step.

### `#Q-G2` (MIT-2, P0) — CON-5 exclusion list enumeration

CON-5/SC-10/SC-12/FR-14 reference "documented per-install metadata files" without defining them. The byte-equivalence test cannot be authored mechanically until the list is concrete.

**Recommended minimum enumeration**:
- `.orchestrator/install-meta.txt` (always, every channel)
- `node_modules/` and lockfile artifacts under npm install path
- Homebrew receipt files (`.brew/*.bottle.tab`)
- Channel-specific compiled-on-install artifacts (TBD per P02/P03 plan-phase)

**Process**: enumerate base list now in CON-5; plan-phase authors extending the list update `references/installation.md § Channel-specific metadata files` first, then reference from CON-5. **Decided at**: this discuss step (base list); plan-phase (extensions).

### `#Q-G3` (MIT-3, P0) — SC-7b activation gating

Depends on `#Q-G1` resolution: Option A activates SC-7b (`grep 'spec-kit-orchestrator' …`); Option B explicitly omits it. **Resolves with `#Q-G1`**. **Decided at**: this discuss step.

### `#Q-G4` (MIT-4, P0) — `--mode=auto` reconciliation: drop or specify

FR-1 enumerates `--mode=symlink|copy` (two values); Edge Cases describes `--mode=auto` fallback behavior. A conforming FR-1 implementation has no `auto` flag.

- **Option A** (recommended): Revise Edge Cases to read "stderr message `'symlink mode unsupported on this filesystem — re-run with --mode=copy'`; exits non-zero. No automatic fallback." Lower spec complexity, consistent with FR-1.
- **Option B**: Amend FR-1 to `--mode=symlink|copy|auto` with specified `auto` behavior + new SC-1b.

**Recommendation**: Option A. The fallback the Edge Case described was operator-friendly but creates a behavioral surface that needs testing on three filesystems (HFS+, APFS, ext4, NTFS-via-WSL) — surface area outweighs convenience. **Decided at**: this discuss step.

### `#Q-G5` (MIT-5, P0) — FR-3 SHA-absent fallback clause

FR-3 reads "consumer's `.orchestrator/install-meta.txt` (commit SHA + version)" — but the three active dogfood projects (lakeledger, pbj-central, bbt-companion) installed pre-M035 lack commit SHAs. US-2 was designed to benefit those exact installs.

**Recommended FR-3 amendment**: SHA-absent installs emit `commits_behind=unknown` + `versions_behind` from semver delta against `CHANGELOG.md` top-line, plus one-time stderr advisory `'commit-SHA not recorded in install-meta.txt — drift detection using version comparison only (pre-M035 install).'` Add SC-3b covering the pre-M035 `install-meta.txt` shape. **Decided at**: this discuss step.

### Wiki-stub-drift paper-cut Layer 1 placement: P00 or P01?

`papercut-wiki-stub-drift.md` Layer 1 (`scripts/diagnostics/wiki-stubs-fresh.sh` diagnostic + install-template `.github/workflows/pages.yml` pre-build gate) folds into M035 pre-launch scope, but P00 vs P01 placement is undecided.

- **P00 candidate**: thematic fit with CI/install-integrity hardening (alongside US-3 bash 3.2 + US-4 installer `.gitignore`). All three are "installer + CI hygiene." This is the recommended placement.
- **P01 candidate**: sequencing fit with operator-facing wiki-deploy-relevant changes (alongside US-1 `--mode=symlink` + US-2 drift warning).

**Recommendation**: **P00**. The diagnostic + pre-build gate are CI-side install-template integrity, not operator-facing UX. Composes naturally with bash 3.2 and `.gitignore` hardening. **Decided at**: this discuss step.

### Wiki-stub-drift Layer 2 ownership: M035 P00/P01 install-template, or peeled-out paper-cut?

Layer 2 (Pages-deploy failure visibility — GHA failure annotation + optional webhook notification) is smaller and arguably out-of-scope-for-orchestrator-runtime — it's GHA notification config in the install-template.

- **Option A**: Fold into M035 P00 install-template hardening alongside Layer 1.
- **Option B**: Peel out as a standalone install-template paper-cut tracked alongside `papercut-handoff-wiki-publishing-robustness-2026-05-07.md`. Ships independently of M035 closure.

**Recommendation**: **Option B (peel out)**. Layer 1 catches drift *before* Pages runs, which is the load-bearing case; Layer 2 is a fallback for the "Pages itself failed for other reasons" case, lower urgency. Bundling delays Layer 1 unnecessarily. **Decided at**: this discuss step.

### Wiki-stub-drift verify integration: fold into `commands/verify.md`?

The Layer 1 diagnostic (`scripts/diagnostics/wiki-stubs-fresh.sh`) could fold into `orchestrator:verify` for milestone-grain assurance — verify fails if the wiki stubs drift between roadmap-stub-generation time and verify time. Or it could stay CI-gate-only.

**Recommendation**: **CI-gate-only initially**. The CI gate is the load-bearing case; verify-time check is redundant if CI catches it on every push. Reconsider if a future workflow ships stubs without going through CI (unlikely under current convention). **Decided at**: this discuss step.

### `#Q-1` — npm package scope: `@spec-kit/orchestrator` vs `@orchestrator/cli` vs unscoped `orchestrator`

The npm package's published name is permanent (after first publish, rename means a new package). Decision interacts with `#Q-G1` (repo rename strategy):
- If `#Q-G1` Option A (rename in M035): `@orchestrator/cli` or `orchestrator` aligns post-rename.
- If `#Q-G1` Option B (narrow rename, defer): `@spec-kit/orchestrator` aligns with current repo name; downstream rename later means npm rename (i.e., new package + deprecation notice on old).

**Recommendation**: **deferred to P02 plan-phase** unless `#Q-G1` resolves Option A here. If Option B, mark `#Q-1` as "decision freezes when repo rename plan lands; `@spec-kit/orchestrator` is the placeholder." **Decided at**: P02 plan-phase (latest).

### `#Q-2` — homebrew tap-vs-cask + tap-org name

Tap implies a tap repo (`homebrew-orchestrator` under chosen org). Cask implies a binary-shipped artifact (over-engineered for a shell+markdown bundle).

**Recommendation**: **tap, not cask**. Tap-org name follows from `#Q-G1` resolution (if Option A: `@orchestrator/homebrew-orchestrator`; if Option B: `@spec-kit/homebrew-orchestrator`). **Decided at**: P03 plan-phase.

### `#Q-11` — M033 friendly-tester pass overlap

M033 friendly-tester pass deadline is 2026-05-12 (per launch-sequencing-amendment Q-1); protocol at `tests/m033-acceptance/friendly-tester-pass/protocol.md`. M035 P00/P01 work overlaps this window. Findings on `orchestrator:start` may require P04/P06 documentation adjustments.

**Recommendation**: allocate documentation contingency buffer in P04 and P06 plan-phases. Block roadmap entry into P04 until friendly-tester pass completes or its findings are reviewed. **Decided at**: at roadmap time (sequencing); at P04 plan-phase (contingency response).

### `#Q-3..#Q-10` (spec-routed)

These remain routed to their named plan-phases per the spec:
- `#Q-3` (signing tool: GPG vs sigstore): P05 plan-phase
- `#Q-4` (rollback marker storage): P05 plan-phase
- `#Q-5` (config schema for `update_source`): P06 plan-phase
- `#Q-6` (detect-by-install-method default): already recommended (AD-5)
- `#Q-7` (CI runner: GitHub Actions vs alternatives): P02 plan-phase
- `#Q-8` (filesystem detection for symlink mode): P01 plan-phase
- `#Q-9` (install-meta.txt schema extension): P01 plan-phase
- `#Q-10` (publishing pipeline test fixture strategy): P02 plan-phase

No discuss-time action required — they ship as planning-stage decisions.
