---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M035"
goal: "Homebrew formula + tap (`build-fractal/orchestrator`) — author the formula template + render script under `packaging/homebrew/`, extend `.github/workflows/release.yml` with a tag-push-only homebrew-bottle + tap-push job (CON-6 secret-scoped), extend `tests/m035-acceptance/cross-channel-byte-equivalence.sh` with the homebrew-channel arm + cross-channel equality assertion (CON-5 / Constitution Principle XVI), and document the `brew tap … && brew install …` recipe in `references/installation.md`. The formula registers skills via M025's manifest mechanism (FR-9, no formula-specific install logic, uninstall cascades through M025)."
demo_sentence: "On a fresh brew-equipped macOS, `brew tap build-fractal/orchestrator && brew install orchestrator` exits 0 and `orchestrator --version` matches the latest published tap version (SC-9); `bash tests/m035-acceptance/cross-channel-byte-equivalence.sh` runs end-to-end against P02's npm-channel skeleton plus the new homebrew-channel arm, emits `NPM_HASH=` and `HOMEBREW_HASH=` to stdout, and the cross-channel equality assertion fires (`pass` increments) when both arms produce the same SHA-256 (CON-5)."
risk: "medium"
depends_on: ["P02"]
---

## Plan-Phase-Resolved Open Questions (AD-7)

The roadmap's `#Q-` budget for P03 was empty, but two questions surfaced
during planning. They resolve here per AD-7 and bind the task plans below.

- **#Q-P03-1 (homebrew tarball source: re-use `npm pack` tarball or
  generate a separate brew-tarball)** → **re-use the P05-signed
  `npm pack` tarball** (`build-fractal-orchestrator-<version>.tgz`).
  Rationale:
  1. **CON-5 byte-equivalence is structural, not channel-specific.** A
     separate brew-tarball would introduce an independent build path
     whose hash drift versus the npm tarball would mask the very
     divergence CON-5 exists to catch. Re-using the npm tarball means
     the homebrew channel reads the same bits, hashes the same staged
     tree (modulo `.brew/*.bottle.tab` per the installation.md
     exclusion list), and any drift is a real regression rather than
     a build-pipeline accident.
  2. **CON-6 secret-scoping carries over unchanged.** P02 already
     scopes `secrets.NPM_TOKEN` to `v*` tag-push events on the
     canonical repo via the job-condition `if: startsWith(github.ref,
     'refs/tags/v') && github.event_name == 'push'`. The homebrew job
     adds `secrets.HOMEBREW_TAP_TOKEN` under the same condition.
  3. **P05 signing already covers it.** The cosign-signed `.tgz` +
     SHA256SUMS produced by P05's `npm-publish` job satisfies the
     formula's `sha256` field directly. No extra signing surface.
  Recorded as **D007** (`M035/P03 convention`, appended at T01).
  Bound to FR-9 / FR-14 / SC-9 / SC-10.

- **#Q-P03-2 (tap-push mechanism: PAT vs GitHub App token)** →
  **`secrets.HOMEBREW_TAP_TOKEN` PAT, scoped to
  `Build-Fractal/homebrew-orchestrator:contents:write` only**. Rationale:
  1. **Symmetry with `secrets.NPM_TOKEN` precedent** (P02 D001 / D002).
     Operator already manages PATs for the npm channel; adding one more
     under the same review cadence is lower friction than introducing
     GitHub App ownership semantics.
  2. **CON-6 job-condition gating identical to npm.** PAT is only
     visible inside the `homebrew-publish` job, which gates on the same
     `startsWith(github.ref, 'refs/tags/v') && github.event_name ==
     'push'` predicate as `npm-publish`. PR-build exfiltration vector
     closed by the same SC-14 assertion shape.
  3. **GitHub App migration is a clean fast-follow** if rotation
     friction surfaces — `homebrew-orchestrator` is the only repo the
     PAT writes to, so swapping the auth principal is a one-secret
     rotation with no formula changes.
  Recorded as **D008** (`M035/P03 convention`, appended at T02).
  Bound to FR-9 / CON-6 / SC-14.

## Manual Operator Steps (one-time, not agent-dispatched)

These are operator-executed off-tree before T02's release workflow can
publish a formula. The plan schedules them but does NOT assign them to a
sub-agent (per phase-scope constraint: tap repo creation is operator
work, not agent work).

- **MOS-1: Create `Build-Fractal/homebrew-orchestrator` GitHub repo.**
  Empty repo (or with a stub README pointing at the canonical
  `Build-Fractal/orchestrator` repo). Default branch `main`. No
  protection rules required for v1. Required *before* the first `v*`
  tag push exercises T02's tap-push step — until the repo exists, the
  push fails non-fatally and the workflow logs the missing-repo
  advisory.
- **MOS-2: Generate `HOMEBREW_TAP_TOKEN` PAT (D008) and add to
  `Build-Fractal/orchestrator` repo secrets.** Scope:
  `Build-Fractal/homebrew-orchestrator:contents:write` only. Document
  the rotation cadence and revocation procedure in
  `references/installation.md § Releasing` (T04 task plan).
- **MOS-3: One-time `brew tap build-fractal/orchestrator` smoke against
  the first published formula.** Operator-only validation that the tap
  resolves and `brew install orchestrator` exits 0 against the tap. SC-9
  is satisfied by this manual smoke; M035 P06 acceptance battery
  references this step as a checked-by-operator entry rather than an
  agent-runnable check (the GitHub Actions runner has no `brew`
  installed without a `setup-homebrew` action, and adding one for a
  one-time SC-9 smoke is overhead).

## Must-Haves

### Truths

- `packaging/homebrew/orchestrator.rb.tmpl` exists at the repo root,
  declares `class Orchestrator < Formula`, has placeholder tokens
  `__VERSION__` / `__URL__` / `__SHA256__` for runtime substitution,
  declares `homepage`, `desc`, `license "MIT"`, no `depends_on`
  beyond `:macos` / `:linux` (the runtime is shell + node + python3
  all of which are pre-installed on macOS or available via brew
  itself), and has a `def install` block that extracts the tarball
  and stages `bin/orchestrator` + the runtime tree into
  `prefix` via `prefix.install`, then `bin.install_symlink prefix /
  "bin" / "orchestrator"`. The block contains NO formula-specific
  install logic beyond filesystem staging — per-project skill
  registration is deferred to `orchestrator:init` inside a project
  (FR-9: "no formula-specific install logic"; uninstall cascades via
  `brew uninstall` + M025's manifest mechanism removing skills the
  next time the consumer runs `orchestrator:update` or
  `orchestrator:init`).
  - Check: `bash tools/verify/m035-p03-formula-template-shape.sh`

- `packaging/homebrew/render-formula.sh` exists, is executable, takes
  `--version <X.Y.Z>` `--url <https-url>` `--sha256 <hex>` flags, and
  prints the rendered formula on stdout (template substitution, no
  in-place writes). Bash 3.2 compatible. Exits non-zero on any missing
  flag or on a malformed `--sha256` argument (must be 64 hex chars).
  - Check: `bash tools/verify/m035-p03-render-formula-shape.sh`

- `.github/workflows/release.yml`'s top-level `jobs:` block contains a
  third job `homebrew-publish`, conditioned on `if: startsWith(github
  .ref, 'refs/tags/v') && github.event_name == 'push'` (CON-6 / SC-14
  identical predicate to `npm-publish`), that runs *after*
  `npm-publish` (`needs: npm-publish`) and: (a) downloads the
  cosign-signed `.tgz` + SHA256SUMS from the just-created GitHub
  release; (b) extracts the artifact's SHA-256 from `SHA256SUMS`;
  (c) invokes `bash packaging/homebrew/render-formula.sh` to render
  the formula; (d) clones `Build-Fractal/homebrew-orchestrator` using
  `secrets.HOMEBREW_TAP_TOKEN`; (e) writes the rendered formula to
  `Formula/orchestrator.rb` in the tap clone; (f) commits and pushes
  to the tap's `main` branch with a commit message of the form
  `formula: bump to v<X.Y.Z>`. The job has its own `permissions:`
  block declaring `contents: read` (the workflow-level default), and
  uses the PAT for cross-repo write rather than `GITHUB_TOKEN` (which
  cannot write to the tap repo).
  - Check: `bash tools/verify/m035-p03-release-workflow-homebrew-job.sh`

- `.github/workflows/release.yml`'s `pr-validate` job MUST NOT have
  `secrets.HOMEBREW_TAP_TOKEN` in env. CON-6 negative-assertion (same
  shape as P02's `CON-6 — assert no NPM_TOKEN access` step), guarding
  the PAT against PR-build exfiltration.
  - Check: `bash tools/verify/m035-p03-release-workflow-con6-homebrew.sh`

- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` is extended
  with the homebrew-channel arm replacing the `SKIP: pending P03`
  stub. The arm: (a) re-uses the npm-channel `npm pack` tarball
  (D007 / single source-of-truth) staged at `$NPM_FIXTURE/build-
  fractal-orchestrator-<version>.tgz`; (b) extracts it into a fixture
  Cellar layout under `$BREW_FIXTURE/Cellar/orchestrator/<version>/`;
  (c) hashes the staged tree via the existing
  `tests/m035-acceptance/_byte-equivalence-hash.sh` helper with the
  homebrew-extended `EXCLUSION_LIST` (adds `.brew/*.bottle.tab`,
  `Library/Caches/Homebrew/` per installation.md table); (d) emits
  `HOMEBREW_HASH=<sha>` on stdout. After both arms have emitted hashes,
  the script asserts `[ "$NPM_HASH" = "$HOMEBREW_HASH" ]` (CON-5
  cross-channel equality, the load-bearing Constitution Principle XVI
  test). On mismatch, emits `FAIL: cross-channel byte-equivalence —
  NPM_HASH=<…> HOMEBREW_HASH=<…>` and increments `fail`.
  - Check: `bash tools/verify/m035-p03-byte-equivalence-homebrew-arm.sh`

- `references/installation.md` is extended with `## Installing via
  Homebrew` documenting `brew tap build-fractal/orchestrator && brew
  install orchestrator`, the operator-facing per-project init step
  (`orchestrator:init` inside a project after `brew install`), the
  uninstall recipe (`brew uninstall orchestrator`), and a `## Releasing
  via Homebrew` section documenting MOS-1/MOS-2 plus the
  `secrets.HOMEBREW_TAP_TOKEN` rotation cadence (D008). Operator-facing
  copy is self-sufficient — no cross-references to internal plan
  artifacts.
  - Check: `bash tools/verify/m035-p03-installation-doc-homebrew.sh`

- `commands/update.md` is extended with a one-line note that
  `update_source: homebrew` dispatches `brew upgrade orchestrator` via
  the tap (P06 wires the dispatch; P03 records the surface). The note
  references `references/installation.md § Installing via Homebrew`
  for the install path.
  - Check: `bash tools/verify/m035-p03-update-skill-doc-homebrew.sh`

- The phase-suite aggregator `tools/verify/m035-p03-phase-suite.sh`
  exists and runs every per-truth verifier above in sequence, emitting
  `PASS:` / `FAIL:` lines plus a `BATTERY: pass=N fail=0 skip=K`
  summary line (matching the M030 / M032 / M029 / M037 / P02 / P05
  acceptance-battery line shape; `skip` covers the npm-binary-absence
  axis inherited from P02's byte-equivalence skeleton).
  - Check: `bash tools/verify/m035-p03-phase-suite.sh`

### Artifacts

- `packaging/homebrew/orchestrator.rb.tmpl` (min 30 lines, contains
  `class Orchestrator < Formula` AND `__VERSION__` AND `__SHA256__`
  AND `bin.install_symlink`)
- `packaging/homebrew/render-formula.sh` (min 50 lines, contains
  `--version` AND `--url` AND `--sha256`)
- `.github/workflows/release.yml` (modified — contains
  `homebrew-publish` AND `secrets.HOMEBREW_TAP_TOKEN` AND
  `Build-Fractal/homebrew-orchestrator` AND `needs: npm-publish`)
- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` (modified
  — contains `HOMEBREW_HASH=` AND no longer contains
  `SKIP: pending P03`; ALSO contains the cross-channel equality
  assertion `"$NPM_HASH" = "$HOMEBREW_HASH"`)
- `references/installation.md` (modified — contains
  `## Installing via Homebrew` AND `brew tap build-fractal/orchestrator`
  AND `## Releasing via Homebrew`)
- `commands/update.md` (modified — contains `update_source: homebrew`
  AND `brew upgrade`)
- `.orchestrator/DECISIONS.md` (modified — contains `D007` AND
  `D008`)
- `tools/verify/m035-p03-formula-template-shape.sh` (min 30 lines,
  contains `BATTERY:`)
- `tools/verify/m035-p03-render-formula-shape.sh` (min 30 lines,
  contains `BATTERY:`)
- `tools/verify/m035-p03-release-workflow-homebrew-job.sh` (min 35
  lines, contains `BATTERY:`)
- `tools/verify/m035-p03-release-workflow-con6-homebrew.sh` (min 25
  lines, contains `BATTERY:`)
- `tools/verify/m035-p03-byte-equivalence-homebrew-arm.sh` (min 50
  lines, contains `BATTERY:` AND `HOMEBREW_HASH`)
- `tools/verify/m035-p03-installation-doc-homebrew.sh` (min 25 lines,
  contains `BATTERY:`)
- `tools/verify/m035-p03-update-skill-doc-homebrew.sh` (min 20 lines,
  contains `BATTERY:`)
- `tools/verify/m035-p03-phase-suite.sh` (min 30 lines, contains
  `BATTERY:`)

### Key Links

- `packaging/homebrew/render-formula.sh` →
  `packaging/homebrew/orchestrator.rb.tmpl` (renderer reads template)
- `.github/workflows/release.yml` → `packaging/homebrew/render-formula.sh`
  (`homebrew-publish` job invokes the renderer)
- `.github/workflows/release.yml` →
  `Build-Fractal/homebrew-orchestrator` (tap-push target — referenced
  in the clone URL)
- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` →
  `tests/m035-acceptance/_byte-equivalence-hash.sh` (homebrew arm
  re-uses the P02 helper)
- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` →
  `references/installation.md` (consults the
  `## Channel-specific metadata files` exclusion list — homebrew rows
  already present, P03 doesn't extend the list)
- `references/installation.md` →
  `Build-Fractal/homebrew-orchestrator` (operator-facing tap URL)
- `commands/update.md` → `references/installation.md`
  (`§ Installing via Homebrew` cross-reference for `update_source:
  homebrew` consumers)
- `tools/verify/m035-p03-phase-suite.sh` →
  `tools/verify/m035-p03-formula-template-shape.sh` (aggregator → unit)

## Tasks

### T01: Homebrew formula template + render script + DECISIONS row D007

See `tasks/T01-formula-template-and-render-PLAN.md`.

### T02: Extend `.github/workflows/release.yml` with `homebrew-publish` job (CON-6 secret-scoped) + DECISIONS row D008

See `tasks/T02-release-workflow-homebrew-job-PLAN.md`.

### T03: Extend `cross-channel-byte-equivalence.sh` with homebrew-channel arm + cross-channel equality assertion

See `tasks/T03-byte-equivalence-homebrew-arm-PLAN.md`.

### T04: Documentation (`installation.md` § Installing via Homebrew + § Releasing via Homebrew, `commands/update.md` note) + phase-suite aggregator + remaining verifiers

See `tasks/T04-installation-doc-and-phase-suite-PLAN.md`.

## Task Dependencies

```
T01 ──► T02 ──► T03 ──► T04
```

Strictly sequential (one commit per task per RENAME-PLAN convention §
5 inherited from P01.5 / P02 / P05). Sequencing rationale:

- **T01 first** because every downstream artifact reads the formula
  template: T02's `homebrew-publish` job invokes `render-formula.sh`
  which reads the template; T03's byte-equivalence arm extracts the
  same tarball the formula's `url` points at (so the formula's `def
  install` block defines the staged-tree shape that T03 hashes); T04's
  installation.md `## Installing via Homebrew` section mirrors the
  formula's user-facing surface.

- **T02 before T03** because T03's homebrew arm asserts the
  byte-equivalence between npm-extracted-tarball and brew-extracted-
  tarball; the assertion shape matches what the `homebrew-publish`
  job stages at release time, so T02's job design constrains the
  fixture-Cellar layout T03 builds.

- **T03 before T04** because T04's phase-suite aggregator chains every
  per-truth verifier scheduled across T01–T03 plus T04's own
  doc-shape verifiers; T04 cannot author the aggregator until T01–T03
  have determined which verifiers exist.

Plan-Time Discipline Rule 2 (verifier-availability cross-check): every
task plan below schedules its task-grain verifier authorship inside
its own `## Steps`. T04 schedules the phase-suite aggregator
authorship inside its own steps. No cross-task verifier dependencies.

## Files Likely Touched

- `packaging/homebrew/` (new directory) — T01
- `packaging/homebrew/orchestrator.rb.tmpl` (create) — T01
- `packaging/homebrew/render-formula.sh` (create) — T01
- `.github/workflows/release.yml` (modify — append `homebrew-publish`
  job + `pr-validate` CON-6 negative-assertion step) — T02
- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` (modify —
  replace `SKIP: pending P03` arm + add cross-channel equality
  assertion) — T03
- `references/installation.md` (modify — append
  `## Installing via Homebrew` + `## Releasing via Homebrew`) — T04
- `commands/update.md` (modify — `update_source: homebrew` note) — T04
- `.orchestrator/DECISIONS.md` (modify — append D007 row) — T01
- `.orchestrator/DECISIONS.md` (modify — append D008 row) — T02
- `tools/verify/m035-p03-formula-template-shape.sh` (create) — T01
- `tools/verify/m035-p03-render-formula-shape.sh` (create) — T01
- `tools/verify/m035-p03-release-workflow-homebrew-job.sh` (create) — T02
- `tools/verify/m035-p03-release-workflow-con6-homebrew.sh` (create) — T02
- `tools/verify/m035-p03-byte-equivalence-homebrew-arm.sh` (create) — T03
- `tools/verify/m035-p03-installation-doc-homebrew.sh` (create) — T04
- `tools/verify/m035-p03-update-skill-doc-homebrew.sh` (create) — T04
- `tools/verify/m035-p03-phase-suite.sh` (create) — T04

## Notes

**Plan-Time Discipline checks performed:**

- **Rule 1 (Prerequisite-existence)**: `package.json`,
  `bin/orchestrator`, `tests/m035-acceptance/cross-channel-byte-
  equivalence.sh`, `tests/m035-acceptance/_byte-equivalence-hash.sh`,
  `references/installation.md` (with `## Channel-specific metadata
  files` section already containing the homebrew exclusion rows),
  `.github/workflows/release.yml` (P02 + P05 final shape),
  `commands/update.md`, `.orchestrator/DECISIONS.md` all confirmed
  present on disk at plan-authoring time.
- **Rule 2 (Verifier-availability)**: every `Check:` command in this
  plan references a `tools/verify/m035-p03-*.sh` script that is
  scheduled as a deliverable inside this phase's task plans (T01
  through T04). T04's phase-suite aggregator is authored inside T04
  itself, after T01–T03's per-truth verifiers exist on disk. No
  cross-task verifier dependency that would deadlock auto-loop.
  T03's byte-equivalence-arm verifier carries a `SKIP:` path when
  `npm` is absent on PATH (inherited from P02's `npm` precondition),
  so the verifier shape doesn't depend on environmental tooling.
- **Rule 3 (Classifier-shape)**: all proposed `Check:` commands use
  the single-script-file shape per AD-19 (`bash tools/verify/<...>`).
  No compound chains, no `$(...)` containing pipes, no plain
  subshells. The `homebrew-publish` job in `.github/workflows/release
  .yml` runs each step inside a YAML pipe block scalar
  (single-script-shape per AP-009 / P02 T04 / P05 T03 precedent).
  The byte-equivalence helper invocation (`bash tests/m035-acceptance
  /_byte-equivalence-hash.sh`) is a single-command direct invocation.
- **Rule 4 (run-probe.sh scope)**: every verifier scheduled here is a
  repo-resident `tools/verify/m035-p03-*.sh` invoked directly via
  `bash tools/verify/<path>`. `run-probe.sh` is reserved for the
  `/tmp/`-staged fixture-construction probes referenced inside T03
  (the `$NPM_FIXTURE` and `$BREW_FIXTURE` `mktemp -d` directories,
  identical to the P02 T03 helper pattern).
- **Rule 5 (real-DB / real-app smoke)**: T03's homebrew-channel arm
  exercises a real tarball-extract → fixture-Cellar layout → hash
  cycle (no mocks). The `homebrew-publish` job's tap-push step is
  exercised end-to-end by SC-14 dry-run-tag CI invocation (P04
  acceptance-battery scope, but the `## Releasing via Homebrew`
  doc in T04 also documents the operator's manual SC-9 smoke per
  MOS-3). No mock-only DB-style verification surface in P03 (no SQL).
- **Rule 6 (Path-collision check)**: `ls -la` performed against every
  `create` path enumerated in `## Files Likely Touched`. All
  `tools/verify/m035-p03-*.sh` filenames absent from disk.
  `packaging/homebrew/` directory absent (verified `ls packaging/`
  returns only `agents bundle install npm SKILL.md skills`).
  `packaging/homebrew/orchestrator.rb.tmpl` and `render-formula.sh`
  absent. No collisions; all milestone-prefixed slugs follow CLAUDE.md
  naming convention.

**Expected verifier output shape:**

Every per-truth verifier emits `BATTERY: pass=N fail=N` (and `skip=M`
where applicable per the acceptance-battery convention). Phase-suite
aggregator chains all per-truth verifiers and emits `BATTERY: pass=8
fail=0 skip=K` summing across the eight per-truth verifiers.

**Risk areas worth flagging at execution time:**

1. **`Build-Fractal/homebrew-orchestrator` tap repo not yet created.**
   T02's `homebrew-publish` job will fail non-fatally (clone error)
   on first tag push if MOS-1 hasn't been completed. The job logs a
   `MISSING_TAP_REPO: Build-Fractal/homebrew-orchestrator does not
   exist — see references/installation.md § Releasing via Homebrew`
   advisory and exits non-zero. The advisory tells the operator
   exactly what to do; the failure does not corrupt the npm-channel
   release (because `homebrew-publish` runs `needs: npm-publish` so
   the npm artifact has already shipped). Acceptance-battery treats
   first-tag-push as expected-fail-on-tap-repo-missing and the
   operator clears MOS-1 + MOS-2 before the SECOND tag push.
2. **`secrets.HOMEBREW_TAP_TOKEN` rotation.** PATs expire (default 90
   days). T04 documents the rotation cadence in
   `references/installation.md § Releasing via Homebrew`; the
   recommended cadence is "rotate before each major release" or
   "annually, whichever comes first." If the PAT expires
   unobserved, the next tap-push fails with a 401; the operator
   regenerates the PAT and re-runs the workflow against the same
   tag. No artifact corruption.
3. **Formula's `def install` block portability.** The block runs on
   the user's machine via `brew install`, which installs into
   `/opt/homebrew/Cellar/orchestrator/<version>/` (Apple Silicon)
   or `/usr/local/Cellar/orchestrator/<version>/` (Intel macOS) or
   `/home/linuxbrew/.linuxbrew/Cellar/orchestrator/<version>/`
   (Linuxbrew). The block uses `prefix.install` (a Homebrew DSL
   helper) which is path-agnostic, so no hardcoded paths leak. The
   `bin.install_symlink` call wires the binary into the Cellar's
   per-version `bin/` and Homebrew links it onto PATH.
4. **Cross-channel byte-equivalence on `package.json`.** Per the
   exclusion list at `references/installation.md § Channel-specific
   metadata files`, `package.json` is excluded from the npm-channel
   hash but NOT from the homebrew-channel hash (because the homebrew
   tarball is the same `npm pack` tarball — `package.json` IS in
   the staged tree under both channels). The exclusion list lookup
   in `_byte-equivalence-hash.sh` reads the `Channel(s)` column from
   the markdown table; for `package.json` the column reads `npm`,
   meaning the path is excluded only when the channel matches. T03's
   homebrew arm sets `CHANNEL=homebrew` in the env before invoking
   the helper; the helper's regex must respect the per-channel
   filter. **T03's verifier asserts this end-to-end** by hashing
   the same tarball under both channels and asserting equality —
   any per-channel-exclusion bug surfaces as a `FAIL: cross-channel`
   line. (P02's `_byte-equivalence-hash.sh` does NOT currently do
   per-channel filtering — it treats the EXCLUSION_LIST as a single
   union. T03 will EITHER extend the helper to honor `CHANNEL=` OR
   pre-compute the per-channel exclusion union before invoking the
   helper. Decision is a T03 implementation detail; the byte-
   equivalence assertion is the load-bearing contract.)
