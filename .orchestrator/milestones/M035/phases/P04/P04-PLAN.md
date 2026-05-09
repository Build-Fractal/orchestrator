---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M035"
goal: "Curl-pipe-bash one-liner + GH release automation — author `packaging/install/install.sh` (the bash 3.2 / POSIX-sh-safe runtime-detect + tarball-fetch + dispatch wrapper that lands on the GitHub release as a signed asset and is the target of `curl -sSL <url> | bash`), extend `.github/workflows/release.yml` so the existing `npm-publish` job stages `install.sh` into `release-artifacts/` (the P05 sigstore-sign loop's `for artifact in *` glob signs it automatically and the `gh release create release-artifacts/*` glob uploads it; CON-8 20-minute `timeout-minutes` bound at job level), extend `tests/m035-acceptance/cross-channel-byte-equivalence.sh` with the curl-pipe-bash arm replacing the `SKIP: pending P04` stub (re-uses the npm pack tarball per D007 single-source-of-truth, exercises `install.sh` end-to-end via `M035_P04_LOCAL_TARBALL=<path>` + `M035_P04_STAGE_ONLY=1` test-mode env vars mirroring P05's `M035_P05_LIVE_RELEASE_DIR` precedent, hashes the staged extracted tree, and lifts the 2-way `NPM_HASH = HOMEBREW_HASH` assertion to a 3-way `NPM_HASH = HOMEBREW_HASH = CURL_HASH` cross-channel equality assertion — the third channel arm of the load-bearing CON-5 / Constitution Principle XVI test), and document the `curl … | install.sh | bash` recipe in `references/installation.md` (consumer-facing § Installing via curl-pipe-bash + operator-facing § Releasing via curl-pipe-bash with the CON-8 timeout note + § Channel-specific metadata files extension as needed)."
demo_sentence: "After execution, on a fresh machine with no orchestrator clone, `curl -sSL https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh | bash` exits 0 and `~/.claude/skills/` contains the orchestrator surface (US-8 SC-14, exercised against the first published `v*` tag at operator-side smoke time per MOS-3 precedent); `bash tests/m035-acceptance/cross-channel-byte-equivalence.sh` runs end-to-end with all three arms emitting hashes (`NPM_HASH=`, `HOMEBREW_HASH=`, `CURL_HASH=`) and the 3-way equality assertion `[ \"$NPM_HASH\" = \"$HOMEBREW_HASH\" ] && [ \"$HOMEBREW_HASH\" = \"$CURL_HASH\" ]` PASSes (SC-10 / CON-5 third-channel coverage); `bash tools/verify/m035-p04-phase-suite.sh` emits `BATTERY: pass=6 fail=0`."
risk: "high"
depends_on: ["P02", "P03", "P05"]
---

## Plan-Phase-Resolved Open Questions (AD-7)

The roadmap routes `#Q-3` (install.sh URL host), `#Q-G6` (CI timeout
binding), and `#Q-5` (release cadence) to P04 plan-phase. They resolve
here per AD-7 and bind the task plans below.

- **#Q-3 (install.sh URL host)** → **GitHub release `latest/download`**
  asset URL: **`https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh`**
  for the unpinned-latest case, **`https://github.com/Build-Fractal/orchestrator/releases/download/v<X.Y.Z>/install.sh`**
  for the version-pinned case. Recorded as **D009** at T01. Rationale:
  1. **No new infrastructure.** Every alternative (`orchestrator.dev`
     short-URL alias, github.io page, fly.io / R2-backed CDN, canonical
     repo `/raw` URL) requires either a new domain registration, a new
     hosting provider, or a stable-mainline-commit-SHA strategy — each
     introduces an external dependency M035 cannot reverse cheaply
     post-launch. The GitHub release `latest/download` URL is a stable
     redirect provided by GitHub itself, automatically resolves to the
     newest release's asset, and has zero new infrastructure surface.
  2. **Symmetric with the npm tarball + homebrew formula publication
     paths.** Both already use GitHub releases as the artifact source
     (D007 — homebrew formula's `url` field points at the npm pack
     tarball uploaded to the release; install.sh is one more asset on
     the same release). Adopting a different host for install.sh would
     fork the release-artifact distribution model.
  3. **Versioned + unversioned URLs both ship for free.** `latest/download/install.sh`
     resolves to the newest release; `download/v<X.Y.Z>/install.sh`
     pins to a specific tag. Operators pinning to a known-good version
     (per Constitution Principle XVI integrity-first ethos) get a
     stable URL without any redirect indirection.
  4. **Reversible.** If post-launch demand surfaces for a polished
     short URL (e.g., `orchestrator.dev/install.sh`), wiring a redirect
     against the same canonical asset is a one-line DNS change with no
     change to install.sh's content or signing surface. Picking the
     GitHub release URL today does not foreclose any future option.

  Bound to **FR-10** (curl-pipe-bash and release automation), **US-8**
  (curl one-liner install path), **SC-14** (synthetic-tag-push CI
  exercises the URL surface).

- **#Q-G6 (SC-14 timeout undefined)** → **20 minutes on ubuntu-latest**,
  bound as `timeout-minutes: 20` on each release-workflow job (`npm-publish`
  and `homebrew-publish`). Recorded as **D010** at T02 + new **CON-8**
  (escalation clause: if measured duration consistently >15 min across
  three synthetic-tag runs, plan-phase author splits the workflow into
  parallel jobs or documents a revised timeout). Rationale:
  1. **Spec recommendation honored.** The spec's `#Q-G6` recommendation
     is "20 minutes on Ubuntu-latest"; this plan-phase resolution
     adopts it without deviation.
  2. **Headroom over typical run.** The current P03 + P05 release
     workflow's heaviest steps are `npm publish` (~30s), `npm pack`
     (~5s), cosign-keyless sign over ~4 artifacts (~30s total),
     SHA256SUMS generation (~1s), `gh release create` (~10s), and the
     downstream `homebrew-publish` job's `gh release download` +
     render + tap-clone + push (~45s). Total wall-clock budget ~3min
     under nominal conditions; 20min provides 6× headroom for OIDC
     issuance latency, transient network failures, and cosign/sigstore
     log-write retries.
  3. **CON-8 escalation clause is the safety net.** If the workflow
     consistently runs >15min, the spec mandates parallel-job split or
     revised-timeout documentation. CON-8 makes the contract explicit
     so future plan-phase authors don't re-litigate the value.
  4. **Job-level not workflow-level.** `timeout-minutes` is a per-job
     attribute in GitHub Actions — applying it to each publishing job
     individually means a hung `homebrew-publish` doesn't block the
     `npm-publish` job's success signal (and vice versa).

  Bound to **SC-14** (synthetic-tag-push CI completes within documented
  timeout), **CON-8** (escalation clause), **FR-10** (release automation).

- **#Q-5 (release cadence)** → **manual stable releases pre-1.0**,
  documented in `references/installation.md § Releasing via curl-pipe-bash`
  as operator policy without a code surface. Recorded as **D011** at T04.
  Rationale:
  1. **Spec recommendation honored.** "Manual stable releases pre-1.0,
     automatic post-1.0 with conventional-commits-driven version
     bumping" — this plan-phase resolution adopts the pre-1.0 portion
     and defers the post-1.0 automation to a post-launch fast-follow
     when conventional-commits adoption is operator-validated.
  2. **No code surface required at v1.** The release workflow already
     fires on `v*` tag push (operator-driven). Pre-1.0 means the
     operator pushes the tag manually after authoring `CHANGELOG.md`
     for the release. No CI cron, no PR-merge auto-tagging, no
     conventional-commits parsing — all of which are post-launch
     fast-follow scope.
  3. **Reversible.** Switching to automatic post-1.0 is purely
     additive: a new `.github/workflows/auto-tag.yml` + the conventional-commits
     parser ship as their own plan-phase work. D011 declares the v1
     posture; future work supersedes via a new D### or by amending
     the documentation block.

  Bound to **US-8** (curl-pipe-bash install path consumer-facing
  documentation), **FR-10** (release automation), and operator
  workflow under MOS-1 / MOS-2 / MOS-3 precedent.

## Manual Operator Steps (one-time, not agent-dispatched)

These are operator-executed off-tree before T02's release workflow can
publish a curl-pipe-bash artifact end-to-end. The plan schedules them
but does NOT assign them to a sub-agent (per phase-scope constraint:
GitHub release smoke + first-tag-push is operator work, not agent work).

- **MOS-4 (P04): One-time `curl -sSL <release>/install.sh | bash` smoke
  against the first published release.** Operator-only validation that
  the GitHub `latest/download` URL resolves, install.sh is signed
  (sigstore + SHA-256 fallback per P05 D004), and the dispatched
  install-claude-code.sh runs to completion against a fresh fixture
  HOME. SC-14 is satisfied by this manual smoke; M035 P06 acceptance
  battery references this step as a checked-by-operator entry rather
  than an agent-runnable check (the GitHub Actions runner can curl-pipe-bash
  itself, but exercising the full FRESH-MACHINE-NO-CLAUDE-CODE flow
  requires a real workstation with an interactive `~/.claude/`
  directory — same MOS-3 / homebrew-side reasoning).

- **MOS-5 (P04): Synthetic `v0.0.0-test` tag push against a fork** to
  exercise SC-14 end-to-end (publishing workflow completes within the
  20-minute CON-8 timeout, GitHub release contains the four required
  artifacts: npm tarball, homebrew bottle, signed install.sh, SHA256SUMS).
  Operator-only because the synthetic tag must come from a real
  operator-authenticated git push (canonical-repo CI cannot self-tag;
  the npm-publish job's CON-6 condition `github.event_name == 'push'`
  rejects fork-PR-events). Documented in `references/installation.md
  § Releasing via curl-pipe-bash` as part of the v1.0.0 release
  rehearsal procedure. Tracked as a **launch-rehearsal** prerequisite,
  not an M035 P04 closure prerequisite — closure is on-disk artifact
  shape; live-tag exercise is the second milestone past closure.

## Must-Haves

### Truths

- `packaging/install/install.sh` exists at the repo root, is executable,
  and is bash 3.2 / POSIX-sh-safe. Its content includes:
  (a) shebang `#!/usr/bin/env bash` + `set -eu` (no `set -o pipefail`
  per bash-3.2 portability over `set -e` interaction);
  (b) `REPO="${ORCHESTRATOR_REPO:-Build-Fractal/orchestrator}"` +
  `VERSION="${ORCHESTRATOR_VERSION:-latest}"` env-overridable
  resolution variables;
  (c) test-only `M035_P04_LOCAL_TARBALL` + `M035_P04_STAGE_ONLY`
  env-var hooks (mirrors P05's `M035_P05_LIVE_RELEASE_DIR` test-gating
  precedent — default OFF, no production behavior change);
  (d) GitHub-release tarball URL resolution via either the explicit
  `download/v<TAG>/build-fractal-orchestrator-<VERSION>.tgz` form
  or the `latest/download/<asset>` redirect form (D009);
  (e) SHA-256 verification step downloading `SHA256SUMS` from the
  same release and asserting `shasum -a 256 -c SHA256SUMS --ignore-missing`
  succeeds against the downloaded tarball (consumes P05 SHA256SUMS
  publication);
  (f) extraction step using `tar -xzf` into a `mktemp -d`-staged
  directory with the npm-tarball convention `package/*` flatten
  (matches D007 single-source-of-truth + the homebrew-channel
  staging shape from P03);
  (g) runtime detection: presence of `~/.claude/` → dispatch
  `bash <staged-dir>/packaging/install/install-claude-code.sh
  --project-dir "$(pwd)"`; absence → emit a "Codex CLI / Cursor
  support is post-launch (M009 fast-follow); see references/installation.md"
  advisory and exit non-zero (CC-only launch posture honored);
  (h) cleanup `trap 'rm -rf "$STAGED_DIR" 2>/dev/null || true' EXIT`
  unless `M035_P04_STAGE_ONLY=1` (test-mode preserves the staged
  tree for byte-equivalence hashing);
  (i) `--version` / `--help` / banner messages naming the
  `orchestrator:<cmd>` cohort prefix (D-RN-3) and the canonical
  repo URL (D009).
  - Check: `bash tools/verify/m035-p04-install-sh-shape.sh`

- `.github/workflows/release.yml`'s `npm-publish` job's "Stage release
  artifacts" step contains a `cp packaging/install/install.sh release-artifacts/`
  line replacing the existing `# P04 hook: install.sh would land here.`
  comment, AND the `npm-publish` and `homebrew-publish` jobs each
  carry `timeout-minutes: 20` at job level (CON-8 / D010). The
  existing P05 cosign-sign loop (`for artifact in *`) signs install.sh
  automatically (no edit needed); the SHA256SUMS step generates a
  digest for install.sh automatically (no edit needed); the `gh release
  create release-artifacts/*` glob uploads install.sh as a release
  asset automatically (no edit needed). No new secrets are added by
  this step (CON-6 not extended; the existing pr-validate negative-assertions
  for NPM_TOKEN + HOMEBREW_TAP_TOKEN remain sufficient — install.sh
  has no curl-channel-specific secret).
  - Check: `bash tools/verify/m035-p04-release-workflow-curl-arm.sh`

- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` is extended
  with a third arm replacing the `SKIP: pending P04 -- curl-pipe-bash-channel
  hash assertion` line. The arm: (a) requires `$TARBALL` from the
  npm-channel arm (D007 single-source-of-truth, same pattern as P03's
  homebrew arm); (b) sets up a fixture `mktemp -d` staging dir; (c)
  invokes `bash packaging/install/install.sh` with
  `M035_P04_LOCAL_TARBALL=$TARBALL` + `M035_P04_STAGE_ONLY=1` +
  `M035_P04_STAGE_DIR=<fixture>` env vars to short-circuit the
  download/SHA-verify/dispatch chain and just stage the package
  contents; (d) hashes the staged tree via the existing
  `tests/m035-acceptance/_byte-equivalence-hash.sh` helper with
  `EXCLUSION_LIST="$EXCLUSION_LIST_CURL_BASH"` (extracted via the
  existing `_exclusion-list-by-channel.sh` helper with `CHANNEL=curl-pipe-bash`);
  (e) emits `CURL_HASH=<sha>` on stdout. After all three arms emit
  hashes, the script lifts the existing 2-way assertion to a 3-way:
  `[ "$NPM_HASH" = "$HOMEBREW_HASH" ] && [ "$HOMEBREW_HASH" = "$CURL_HASH" ]`
  with a triplet-mismatch FAIL message naming all three hashes (CON-5
  cross-channel equality — the load-bearing Constitution Principle XVI
  test, third channel coverage).
  - Check: `bash tools/verify/m035-p04-byte-equivalence-curl-arm.sh`

- `references/installation.md` is extended with `## Installing via curl-pipe-bash`
  documenting the consumer-facing recipe (`curl -sSL https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh
  | bash` + `orchestrator --version` smoke + per-project `/orchestrator-init`
  setup parallel to npm/homebrew + version-pinning recipe via
  `ORCHESTRATOR_VERSION=v<X.Y.Z>` env override + uninstall recipe
  pointing at `bash packaging/install/install-claude-code.sh --uninstall`),
  AND `## Releasing via curl-pipe-bash` documenting MOS-4 / MOS-5 + the
  D009 GitHub-release-asset-URL contract + the D010 / CON-8 20-minute
  timeout + the D011 manual-stable-releases-pre-1.0 cadence note. The
  `## Channel-specific metadata files` exclusion table is NOT extended
  in P04 (the curl arm extracts the same npm tarball as the homebrew
  arm and produces the same staged tree shape; no curl-specific noise
  files exist for v1).
  - Check: `bash tools/verify/m035-p04-installation-doc-curl.sh`

- `commands/update.md` `## Update sources` H2 is extended with a
  fourth row enumerating `update_source: curl-pipe-bash` → `curl -sSL
  https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh
  | bash` (P06 wires the actual dispatch under `scripts/lifecycle/run-update.sh`;
  P04 records the surface symmetric with P03's homebrew row addition).
  The note references `references/installation.md § Installing via curl-pipe-bash`
  for the install path and explicitly flags that the curl-pipe-bash
  channel re-runs install.sh from the latest release URL on update.
  - Check: `bash tools/verify/m035-p04-update-skill-doc-curl.sh`

- The phase-suite aggregator `tools/verify/m035-p04-phase-suite.sh`
  exists, runs every per-truth verifier above in T01→T04 order,
  parses each verifier's BATTERY line and sums pass/fail/skip into a
  consolidated rollup, emits per-verifier `PASS:` / `FAIL:` decisions
  plus a final `BATTERY: pass=N fail=0 skip=K` summary line (matching
  P03's chain-the-children form rather than P05's sum-the-counters
  form — P04 has no skip-able child verifiers so the simpler chain
  form is appropriate; `skip=0` expected at v1).
  - Check: `bash tools/verify/m035-p04-phase-suite.sh`

### Artifacts

- `packaging/install/install.sh` (min 120 lines, contains
  `M035_P04_LOCAL_TARBALL` AND `Build-Fractal/orchestrator` AND
  `tar -xzf` AND `install-claude-code.sh` AND `~/.claude` AND
  `shasum -a 256 -c`)
- `.github/workflows/release.yml` (modified — contains
  `cp packaging/install/install.sh release-artifacts/` AND
  `timeout-minutes: 20`)
- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` (modified
  — contains `CURL_HASH=` AND no longer contains
  `SKIP: pending P04` AND contains the 3-way equality assertion
  `"$NPM_HASH" = "$HOMEBREW_HASH"` AND `"$HOMEBREW_HASH" = "$CURL_HASH"`)
- `references/installation.md` (modified — contains
  `## Installing via curl-pipe-bash` AND
  `releases/latest/download/install.sh` AND
  `## Releasing via curl-pipe-bash` AND
  `timeout-minutes: 20` AND `CON-8`)
- `commands/update.md` (modified — contains `update_source: curl-pipe-bash`
  AND `releases/latest/download/install.sh`)
- `.orchestrator/DECISIONS.md` (modified — contains `### D009 —` AND
  `### D010 —` AND `### D011 —`)
- `tools/verify/m035-p04-install-sh-shape.sh` (min 50 lines, contains
  `BATTERY:`)
- `tools/verify/m035-p04-release-workflow-curl-arm.sh` (min 30 lines,
  contains `BATTERY:` AND `timeout-minutes`)
- `tools/verify/m035-p04-byte-equivalence-curl-arm.sh` (min 60 lines,
  contains `BATTERY:` AND `CURL_HASH`)
- `tools/verify/m035-p04-installation-doc-curl.sh` (min 30 lines,
  contains `BATTERY:`)
- `tools/verify/m035-p04-update-skill-doc-curl.sh` (min 20 lines,
  contains `BATTERY:`)
- `tools/verify/m035-p04-phase-suite.sh` (min 30 lines, contains
  `BATTERY:`)

### Key Links

- `packaging/install/install.sh` →
  `packaging/install/install-claude-code.sh` (dispatches into the
  existing CC installer after extracting the tarball)
- `.github/workflows/release.yml` →
  `packaging/install/install.sh` (`Stage release artifacts` step
  copies install.sh into `release-artifacts/`)
- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` →
  `packaging/install/install.sh` (curl arm invokes install.sh in
  test-mode via `M035_P04_LOCAL_TARBALL` + `M035_P04_STAGE_ONLY`)
- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` →
  `tests/m035-acceptance/_byte-equivalence-hash.sh` (curl arm
  re-uses the P02 helper, same pattern as homebrew arm)
- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` →
  `tests/m035-acceptance/_exclusion-list-by-channel.sh` (curl arm
  invokes with `CHANNEL=curl-pipe-bash` to extract per-channel
  exclusions; existing helper supports the channel name without edit)
- `references/installation.md` →
  `packaging/install/install.sh` (consumer-facing recipe references
  the script's behavior + env-var override surface)
- `references/installation.md` →
  `Build-Fractal/orchestrator` GitHub releases (operator-facing URL
  for the release-asset host; D009)
- `commands/update.md` → `references/installation.md`
  (`§ Installing via curl-pipe-bash` cross-reference for
  `update_source: curl-pipe-bash` consumers)
- `tools/verify/m035-p04-phase-suite.sh` →
  `tools/verify/m035-p04-install-sh-shape.sh` (aggregator → unit)

## Tasks

### T01: `packaging/install/install.sh` curl-pipe-bash entry-point + DECISIONS row D009

See `tasks/T01-install-sh-curl-pipe-bash-PLAN.md`.

### T02: Extend `.github/workflows/release.yml` with `install.sh` staging + `timeout-minutes: 20` (CON-8) + DECISIONS row D010

See `tasks/T02-release-workflow-curl-arm-PLAN.md`.

### T03: Extend `cross-channel-byte-equivalence.sh` with curl-pipe-bash arm + 3-way cross-channel equality assertion

See `tasks/T03-byte-equivalence-curl-arm-PLAN.md`.

### T04: Documentation (`installation.md` § Installing/Releasing via curl-pipe-bash, `commands/update.md` row) + DECISIONS row D011 + phase-suite aggregator + remaining verifiers

See `tasks/T04-installation-doc-and-phase-suite-PLAN.md`.

## Task Dependencies

```
T01 ──► T02 ──► T03 ──► T04
```

Strictly sequential (one commit per task per RENAME-PLAN convention §
5 inherited from P01.5 / P02 / P03 / P05). Sequencing rationale:

- **T01 first** because every downstream artifact reads `install.sh`:
  T02's release.yml change copies the file from disk into `release-artifacts/`
  (the file must exist before the workflow references it); T03's
  byte-equivalence arm invokes install.sh in test-mode via
  `M035_P04_LOCAL_TARBALL` + `M035_P04_STAGE_ONLY`; T04's installation.md
  `## Installing via curl-pipe-bash` section mirrors the script's
  user-facing surface (the env-var override list, the release-asset
  URL pattern, the runtime-detection contract) and the verifier in
  T04 greps both the doc and the script for matching phrases.

- **T02 before T03** because T03's curl arm asserts byte-equivalence
  between the npm-extracted-tarball and the install.sh-extracted-tarball;
  the install.sh extraction shape is what the workflow stages at
  release time, so T02's job design (which artifacts are staged
  alongside install.sh) constrains the fixture-staging shape T03
  builds. Concretely: T02 binds the **release-artifacts/**-layout
  contract (`build-fractal-orchestrator-<TAG>.tgz` + `install.sh` +
  `SHA256SUMS` co-located), and T03's `M035_P04_LOCAL_TARBALL`
  test-mode reads from that same shape.

- **T03 before T04** because T04's phase-suite aggregator chains
  every per-truth verifier scheduled across T01–T03 plus T04's own
  doc-shape verifiers; T04 cannot author the aggregator until T01–T03
  have determined which verifiers exist on disk. T04 also adds the
  D011 release-cadence DECISIONS row, which is documentation-only and
  doesn't gate any earlier task.

Plan-Time Discipline Rule 2 (verifier-availability cross-check): every
task plan below schedules its task-grain verifier authorship inside
its own `## Steps`. T04 schedules the phase-suite aggregator
authorship inside its own steps. No cross-task verifier dependencies.

## Files Likely Touched

- `packaging/install/install.sh` (create) — T01
- `.orchestrator/DECISIONS.md` (modify — append D009 row) — T01
- `.github/workflows/release.yml` (modify — `Stage release artifacts`
  step + `timeout-minutes: 20` on `npm-publish` and `homebrew-publish`
  jobs) — T02
- `.orchestrator/DECISIONS.md` (modify — append D010 row) — T02
- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` (modify —
  replace `SKIP: pending P04` arm + lift 2-way assertion to 3-way) — T03
- `references/installation.md` (modify — append
  `## Installing via curl-pipe-bash` + `## Releasing via curl-pipe-bash`)
  — T04
- `commands/update.md` (modify — `update_source: curl-pipe-bash` row in
  `## Update sources` H2) — T04
- `.orchestrator/DECISIONS.md` (modify — append D011 row) — T04
- `tools/verify/m035-p04-install-sh-shape.sh` (create) — T01
- `tools/verify/m035-p04-release-workflow-curl-arm.sh` (create) — T02
- `tools/verify/m035-p04-byte-equivalence-curl-arm.sh` (create) — T03
- `tools/verify/m035-p04-installation-doc-curl.sh` (create) — T04
- `tools/verify/m035-p04-update-skill-doc-curl.sh` (create) — T04
- `tools/verify/m035-p04-phase-suite.sh` (create) — T04

## Notes

**Plan-Time Discipline checks performed:**

- **Rule 1 (Prerequisite-existence)**: `package.json` (P02 T01),
  `bin/orchestrator` (P02 T01), `packaging/install/install-claude-code.sh`
  (pre-M035), `tests/m035-acceptance/cross-channel-byte-equivalence.sh`
  (P02 T03 + P03 T03), `tests/m035-acceptance/_byte-equivalence-hash.sh`
  (P02 T03), `tests/m035-acceptance/_exclusion-list-by-channel.sh` (P03
  T03 — confirmed supports `CHANNEL=curl-pipe-bash` without edit per
  the existing awk's comma-separated channel-list parsing), `references/installation.md`
  (with `## Channel-specific metadata files` + `## Installing via Homebrew`
  + `## Releasing via Homebrew` + `## Verifying integrity` sections
  already present), `.github/workflows/release.yml` (P02 + P03 + P05
  final shape), `commands/update.md` (with `## Update sources` H2
  enumerating git/npm/homebrew per P03 T04), `.orchestrator/DECISIONS.md`
  (with D007 + D008 already recorded — D009/D010/D011 will append in
  numeric order) all confirmed present on disk at plan-authoring time.

- **Rule 2 (Verifier-availability)**: every `Check:` command in this
  plan references a `tools/verify/m035-p04-*.sh` script that is
  scheduled as a deliverable inside this phase's task plans (T01
  through T04). T04's phase-suite aggregator is authored inside T04
  itself, after T01–T03's per-truth verifiers exist on disk. No
  cross-task verifier dependency that would deadlock auto-loop. T03's
  byte-equivalence-curl-arm verifier carries graceful-skip handling
  for the `npm` precondition inherited from P02's byte-equivalence
  skeleton (if `npm` is absent on PATH, the curl arm's prerequisite
  TARBALL is unavailable and the arm SKIPs), so the verifier shape
  doesn't depend on environmental tooling.

- **Rule 3 (Classifier-shape)**: all proposed `Check:` commands use
  the single-script-file shape per AD-19 (`bash tools/verify/<...>`).
  No compound chains, no `$(...)` containing pipes, no plain
  subshells. The release.yml extension at T02 inserts a single `cp`
  line + a `timeout-minutes:` YAML attribute (single declarative
  edit, no compound shell logic). install.sh itself is bash 3.2 /
  POSIX-sh-safe per the user-prompt session-hygiene constraint —
  long-running probes inside install.sh use `if/then` blocks (no
  `&&`-chains beyond two), shasum-verify is invoked as a single
  command (`shasum -a 256 -c SHA256SUMS --ignore-missing` is one
  command, not a compound chain).

- **Rule 4 (run-probe.sh scope)**: every verifier scheduled here is a
  repo-resident `tools/verify/m035-p04-*.sh` invoked directly via
  `bash tools/verify/<path>`. `run-probe.sh` is reserved for the
  `/tmp/`-staged fixture-construction probes referenced inside T03
  (the `mktemp -d` directories used by the curl arm, identical to
  the P02 + P03 helper pattern). install.sh itself uses `mktemp -d`
  for its staging dir at runtime — that path is operator-machine-staged,
  not project-tree-staged, and is unrelated to `run-probe.sh`'s
  approved-roots filter.

- **Rule 5 (real-DB / real-app smoke)**: T03's curl-pipe-bash arm
  exercises a real `bash packaging/install/install.sh` invocation in
  test-mode (no mocks): real tarball-extract → real fixture staging
  → real `_byte-equivalence-hash.sh` cycle. install.sh's runtime
  detection / SHA-verify / dispatch chain is partially exercised
  (the LOCAL_TARBALL test-mode short-circuits the download +
  SHA-verify steps, since the fixture provides a known-good local
  tarball; the dispatch step is also short-circuited under
  STAGE_ONLY=1 to avoid invoking install-claude-code.sh inside
  the test). The full end-to-end flow is operator-exercised at
  MOS-4 first-release smoke (synthetic `v0.0.0-test` tag push per
  MOS-5). No SQL surface in P04; Rule 5's DB-bound clause is
  non-applicable. Rule 5's "real-app smoke pending" callout is
  documented in `references/installation.md § Releasing via curl-pipe-bash`
  as the MOS-4 / MOS-5 prerequisite.

- **Rule 6 (Path-collision check)**: `ls -la` performed against every
  `create` path enumerated in `## Files Likely Touched`.
  `packaging/install/install.sh` absent from disk (verified — only
  `install-claude-code.sh`, `install-codex.sh`, `install-cursor.sh`
  are present in `packaging/install/`). All `tools/verify/m035-p04-*.sh`
  filenames absent from disk (verified — `ls tools/verify/ | grep
  '^m035-p04'` returns no output; the milestone-prefixed slug
  convention from CLAUDE.md is followed). No collisions with any
  existing milestone's verifiers.

**Expected verifier output shape:**

Every per-truth verifier emits `BATTERY: pass=N fail=N` (and `skip=M`
where applicable per the acceptance-battery convention). Phase-suite
aggregator chains the six per-truth verifiers in T01→T04 order and
emits `BATTERY: pass=6 fail=0 skip=0` (no skip-able children at v1
since install.sh's runtime-detection skip path is internal to T01's
verifier, not a separate child).

**Risk areas worth flagging at execution time:**

1. **install.sh's `M035_P04_LOCAL_TARBALL` test-mode contract is
   load-bearing for T03.** The test-mode env-var hooks
   (`M035_P04_LOCAL_TARBALL`, `M035_P04_STAGE_ONLY`, `M035_P04_STAGE_DIR`)
   are the seam by which T03's byte-equivalence test exercises the
   real install.sh code path without requiring network access or
   real GitHub release artifacts. The hooks must be default-OFF (no
   production behavior change when env vars are unset) — mirrors
   P05's `COSIGN_AVAILABLE=1 + M035_P05_LIVE_RELEASE_DIR=path`
   default-OFF live-mode pattern. T01's install-sh-shape verifier
   asserts the env-var hooks exist via `grep -F` on the literal
   variable names; T03's byte-equivalence verifier asserts the test
   actually exercises them by checking `CURL_HASH` is non-empty
   after invocation.

2. **3-way cross-channel equality assertion supersedes the existing
   2-way assertion.** The current `cross-channel-byte-equivalence.sh`
   contains a 2-way `[ "$NPM_HASH" = "$HOMEBREW_HASH" ]` block at
   lines 187-204 (P03 T03). T03 replaces this block with a 3-way
   assertion that fires when ALL three hashes are emitted, and the
   2-way fallback fires when only two arms produced hashes. The
   FAIL-message shape must include all three hash values when the
   3-way fires and mismatches; the verifier asserts the message
   shape via `grep -F` on the literal `CURL_HASH=` and equality-operator
   substrings. Care needed: do not regress the 2-way fallback path
   (when `npm` is absent on PATH, both homebrew and curl arms SKIP
   per their `[ -z "${TARBALL:-}" ]` guards — the 3-way assertion
   skips cleanly rather than failing on missing operands).

3. **CON-5 cross-channel byte-equivalence on `package.json` /
   `_byte-equivalence-hash.sh` BSD-sed paper-cut is inherited.** Per
   P05-SUMMARY caveats, the existing `_byte-equivalence-hash.sh`
   uses a `sed -E '[][.^$*+?(){}|\\]'` bracket class that errors on
   macOS BSD sed, silently degrading EXCLUSION_LIST to a no-op
   locally. P03's NPM_HASH = HOMEBREW_HASH equality holds today
   "by accident" (single tarball, identical extract semantics, no
   real per-channel exclusion ever applied). P04's curl arm reuses
   the same tarball with the same extract semantics, so CURL_HASH
   = NPM_HASH = HOMEBREW_HASH holds under the same accidental-pass
   shape. **This is NOT fixed in P04** (out of scope per the
   user-prompt's "two paper-cuts surfaced this week, neither blocks
   P04 plan-phase" guidance). The fix is post-launch cross-channel
   hardening; P04 inherits the paper-cut and notes it explicitly in
   T03's plan.

4. **No new secrets surface introduced by P04.** install.sh does not
   require any new CI secrets (sigstore-keyless OIDC + GH release
   upload + SHA256SUMS publication are all P05 surfaces; install.sh
   is just another release asset that gets signed by the same
   cosign-loop and uploaded by the same `gh release create` glob).
   Therefore the existing CON-6 negative-assertions in pr-validate
   (no NPM_TOKEN, no HOMEBREW_TAP_TOKEN) remain sufficient — there
   is no `CURL_PIPE_BASH_TOKEN` or equivalent to negative-assert. T02's
   verifier explicitly checks no new `secrets.*` references appear
   in the workflow (regression guard: catches a future plan-phase
   author accidentally introducing a curl-channel secret).

5. **D009 GitHub-release-asset URL is operator-visible in install.sh
   `--help` output and in `references/installation.md`.** Both surfaces
   must reference the literal URL string identically; T04's verifier
   greps both files for the canonical `https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh`
   substring. Drift between install.sh's banner and installation.md
   would produce confusing operator-facing copy. Mitigation:
   T01's install-sh-shape verifier asserts the banner contains the
   URL; T04's installation-doc verifier asserts the doc contains
   the URL; both reference the same literal string. If a future
   plan-phase author renames the canonical repo, both surfaces must
   change in lockstep.

6. **CON-8 escalation clause is documentation-only at v1.** D010
   binds 20 minutes as the timeout; CON-8 declares the escalation
   procedure (split into parallel jobs or document a revised
   timeout if measured wall-clock consistently >15min across three
   synthetic-tag runs). At v1 this is documentation-only — no
   automation enforces the 15min watermark. Future plan-phase work
   could add a CI-side measurement-and-alert step, but is post-launch
   fast-follow scope.
