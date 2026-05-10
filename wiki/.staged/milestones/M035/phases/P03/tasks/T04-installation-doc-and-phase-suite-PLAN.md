---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M035"
name: "installation.md § Installing/Releasing via Homebrew + commands/update.md note + phase-suite aggregator"
depends_on: ["T03"]
---

## Prerequisites

- T01–T03 complete: formula template, render script, release-workflow
  job, byte-equivalence arm all on disk.
- `tools/verify/m035-p03-formula-template-shape.sh` (T01) on disk.
- `tools/verify/m035-p03-render-formula-shape.sh` (T01) on disk.
- `tools/verify/m035-p03-release-workflow-homebrew-job.sh` (T02) on disk.
- `tools/verify/m035-p03-release-workflow-con6-homebrew.sh` (T02) on disk.
- `tools/verify/m035-p03-byte-equivalence-homebrew-arm.sh` (T03) on disk.
- `references/installation.md` exists with `## Channel-specific
  metadata files` and `## Verifying integrity` sections (P02 + P05).
- `commands/update.md` exists (M035 P00 / pre-M035 interim driver).

## Description

Author the operator-facing documentation surfaces and the phase-suite
aggregator. Three deliverables:

1. **Documentation**:
   - `references/installation.md` extended with `## Installing via
     Homebrew` (consumer-facing) and `## Releasing via Homebrew`
     (operator-facing — MOS-1 / MOS-2 / D008 PAT rotation).
   - `commands/update.md` extended with a one-line
     `update_source: homebrew` note pointing at the install doc.
2. **Verifiers**:
   - `tools/verify/m035-p03-installation-doc-homebrew.sh` (doc-shape).
   - `tools/verify/m035-p03-update-skill-doc-homebrew.sh` (doc-shape).
3. **Phase-suite aggregator**:
   - `tools/verify/m035-p03-phase-suite.sh` chaining all eight
     per-truth verifiers.

## Steps

1. **Append `## Installing via Homebrew`** to
   `references/installation.md`. Insert *after* the existing
   `## Verifying integrity` section (which is the last section in the
   file post-P05). Exact content:

   ```markdown
   ## Installing via Homebrew

   The `build-fractal/orchestrator` Homebrew tap publishes a single
   formula (`orchestrator`) for macOS and Linuxbrew users.

   **Install**:

   ```bash
   brew tap build-fractal/orchestrator
   brew install orchestrator
   ```

   **Verify**:

   ```bash
   orchestrator --version
   # → should match the latest published tap version
   ```

   **Per-project setup**: `brew install orchestrator` stages the
   runtime tree into the Homebrew Cellar and wires `orchestrator` onto
   PATH. Skill registration is per-project — run `/orchestrator-init`
   inside each project directory where you want orchestrator skills
   available. Same model as the npm channel.

   **Uninstall**:

   ```bash
   brew uninstall orchestrator
   brew untap build-fractal/orchestrator
   ```

   `brew uninstall` removes the Cellar files; per-project skill
   registrations cascade away the next time you run
   `/orchestrator-update` or `/orchestrator-init` in a project that
   previously had skills registered, via [M025](../../../../../milestones/M025/index.md)'s manifest mechanism.

   **Cross-channel byte-equivalence**: at any given release tag, the
   runtime layout produced by `brew install orchestrator` is
   byte-identical to the layout produced by `npm install -g
   @build-fractal/orchestrator` and (post-P04) `curl -sSL <install-
   url> | bash`, modulo the per-channel metadata files documented
   above in § Channel-specific metadata files. This is enforced by
   `tests/m035-acceptance/cross-channel-byte-equivalence.sh`
   (Constitution Principle XVI).

   ## Releasing via Homebrew

   This section is operator-only — adopters do not need to follow it.

   The Homebrew formula is published to the
   `Build-Fractal/homebrew-orchestrator` tap repo automatically by the
   `homebrew-publish` job in `.github/workflows/release.yml` on every
   `v*` tag push to the canonical `Build-Fractal/orchestrator` repo.
   The job:

   1. Reads the SHA-256 of the just-published `.tgz` from the
      release's `SHA256SUMS` file.
   2. Renders `Formula/orchestrator.rb` from
      `packaging/homebrew/orchestrator.rb.tmpl` via
      `packaging/homebrew/render-formula.sh`.
   3. Pushes the rendered formula to the tap repo's `main` branch.

   **One-time operator setup** (before the first `v*` tag push that
   should publish a formula):

   1. Create the `Build-Fractal/homebrew-orchestrator` GitHub repo
      (empty or with a stub README pointing back to the canonical
      repo). Default branch `main`. No protection rules required for
      v1.
   2. Generate a Personal Access Token (PAT) scoped to
      `Build-Fractal/homebrew-orchestrator:contents:write` only — no
      other scope, no other repo. Store it as
      `secrets.HOMEBREW_TAP_TOKEN` in the canonical
      `Build-Fractal/orchestrator` repo's Actions secrets.

   **PAT rotation cadence**: rotate before each major release, or
   annually, whichever comes first. PATs default to 90-day expiry; if
   the PAT expires unobserved, the next tap-push fails with a 401 and
   the operator regenerates the PAT and re-runs the workflow against
   the same tag (no artifact corruption, no orphan formula).

   **PAT revocation**: revoke immediately if the canonical repo's
   secrets are rotated for any reason; regenerate after rotation. The
   `homebrew-publish` job is the only consumer of this secret.

   **CON-6 (secrets-scoped-to-tag-push) compliance**: the
   `homebrew-publish` job's `if:` predicate
   (`startsWith(github.ref, 'refs/tags/v') && github.event_name ==
   'push'`) gates secret access. The `pr-validate` job carries an
   explicit negative-assertion step asserting `HOMEBREW_TAP_TOKEN` is
   empty in PR context (SC-14 verified).

   **GitHub App migration**: if PAT rotation friction surfaces, swap
   the PAT for a GitHub App token with `contents:write` scope on the
   tap repo only. The migration is a single-secret rotation; no
   formula or workflow changes are required (the PAT is consumed via
   the standard `x-access-token:<token>@github.com` HTTPS pattern,
   which a GitHub App installation token also satisfies).
   ```

2. **Append a one-line note to `commands/update.md`.** Insert under
   the existing `update_source` documentation (or at the end of the
   skill body if no such section exists yet — the skill is the
   pre-M035 interim driver per `commands/update.md:88`):

   ```markdown
   - **`update_source: homebrew`** — dispatches `brew upgrade
     orchestrator` against the `build-fractal/orchestrator` tap. The
     tap and formula install path are documented in
     `references/installation.md § Installing via Homebrew`. P06
     wires the dispatch into `scripts/lifecycle/run-update.sh`; M035
     P03 records the surface only.
   ```

   The agent MUST place this note adjacent to any existing
   `update_source: git` or `update_source: npm` references for
   readability; if no such block exists, append a new
   `## Update sources` section listing all three.

3. **Author `tools/verify/m035-p03-installation-doc-homebrew.sh`.**

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p03-installation-doc-homebrew.sh
   set -u

   pass=0
   fail=0
   DOC="references/installation.md"

   if [ ! -f "$DOC" ]; then
     echo "FAIL: $DOC missing"
     echo "BATTERY: pass=0 fail=1"
     exit 1
   fi
   pass=$((pass + 1))

   for needle in \
     '## Installing via Homebrew' \
     '## Releasing via Homebrew' \
     'brew tap build-fractal/orchestrator' \
     'brew install orchestrator' \
     'brew uninstall orchestrator' \
     'orchestrator --version' \
     'secrets.HOMEBREW_TAP_TOKEN' \
     'Build-Fractal/homebrew-orchestrator' \
     'PAT rotation cadence' \
     'CON-6'; do
     if grep -qF "$needle" "$DOC"; then
       pass=$((pass + 1))
     else
       echo "FAIL: $DOC missing pattern: $needle"
       fail=$((fail + 1))
     fi
   done

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   Make executable:

   ```bash
   chmod +x tools/verify/m035-p03-installation-doc-homebrew.sh
   ```

4. **Author `tools/verify/m035-p03-update-skill-doc-homebrew.sh`.**

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p03-update-skill-doc-homebrew.sh
   set -u

   pass=0
   fail=0
   DOC="commands/update.md"

   if [ ! -f "$DOC" ]; then
     echo "FAIL: $DOC missing"
     echo "BATTERY: pass=0 fail=1"
     exit 1
   fi
   pass=$((pass + 1))

   for needle in \
     'update_source: homebrew' \
     'brew upgrade'; do
     if grep -qF "$needle" "$DOC"; then
       pass=$((pass + 1))
     else
       echo "FAIL: $DOC missing pattern: $needle"
       fail=$((fail + 1))
     fi
   done

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   Make executable:

   ```bash
   chmod +x tools/verify/m035-p03-update-skill-doc-homebrew.sh
   ```

5. **Author the phase-suite aggregator
   `tools/verify/m035-p03-phase-suite.sh`.** Chains all eight per-truth
   verifiers in the order T01→T02→T03→T04. Emits the canonical
   `BATTERY: pass=N fail=0 skip=K` summary line.

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p03-phase-suite.sh -- M035 P03 phase-suite
   # aggregator. Chains every per-truth verifier in T01–T04 order and
   # emits a single BATTERY summary line.
   set -u

   pass=0
   fail=0
   skip=0

   VERIFIERS=" \
     tools/verify/m035-p03-formula-template-shape.sh \
     tools/verify/m035-p03-render-formula-shape.sh \
     tools/verify/m035-p03-release-workflow-homebrew-job.sh \
     tools/verify/m035-p03-release-workflow-con6-homebrew.sh \
     tools/verify/m035-p03-byte-equivalence-homebrew-arm.sh \
     tools/verify/m035-p03-installation-doc-homebrew.sh \
     tools/verify/m035-p03-update-skill-doc-homebrew.sh \
   "

   for v in $VERIFIERS; do
     if [ ! -x "$v" ]; then
       echo "FAIL: $v missing or not executable"
       fail=$((fail + 1))
       continue
     fi
     # Capture each verifier's output for diagnostic value when the
     # aggregator FAILs in CI.
     out="$(bash "$v" 2>&1)"
     rc=$?
     # Per-verifier BATTERY line: parse pass/fail/skip counts.
     line="$(printf '%s\n' "$out" | grep -E '^BATTERY:' | tail -1)"
     if [ "$rc" -eq 0 ]; then
       pass=$((pass + 1))
       echo "PASS: $v ($line)"
     else
       echo "FAIL: $v exit $rc"
       echo "$out" | sed 's/^/    /'
       fail=$((fail + 1))
     fi
     # Surface skip counts from per-verifier BATTERY lines.
     vskip="$(printf '%s' "$line" | sed -nE 's/.*skip=([0-9]+).*/\1/p')"
     if [ -n "$vskip" ]; then
       skip=$((skip + vskip))
     fi
   done

   echo "BATTERY: pass=$pass fail=$fail skip=$skip"
   [ "$fail" -eq 0 ]
   ```

   Make executable:

   ```bash
   chmod +x tools/verify/m035-p03-phase-suite.sh
   ```

6. **Run the phase-suite aggregator** to confirm green:

   ```bash
   bash tools/verify/m035-p03-phase-suite.sh
   ```

   Expected output: `PASS: tools/verify/m035-p03-formula-template-shape.sh
   (BATTERY: pass=N fail=0)` etc., one PASS per verifier, then
   `BATTERY: pass=7 fail=0 skip=K`.

## Must-Haves

- Truth: `references/installation.md` extended with both
  `## Installing via Homebrew` and `## Releasing via Homebrew`
  (verified by `m035-p03-installation-doc-homebrew.sh`).
- Truth: `commands/update.md` carries `update_source: homebrew` note
  (verified by `m035-p03-update-skill-doc-homebrew.sh`).
- Truth: `tools/verify/m035-p03-phase-suite.sh` exists and aggregates
  all per-truth verifiers (verified by direct invocation in
  Verification block below).
- All seven per-truth verifiers green.

## Verification

```bash
bash tools/verify/m035-p03-installation-doc-homebrew.sh
bash tools/verify/m035-p03-update-skill-doc-homebrew.sh
bash tools/verify/m035-p03-phase-suite.sh
```

## Notes

Expected output: each per-truth verifier emits `BATTERY: pass=N
fail=0`. The phase-suite aggregator emits one `PASS:` line per
verifier plus the rolled-up `BATTERY: pass=7 fail=0 skip=K` line.

The skip count surfaces upward from T03's byte-equivalence verifier
(which SKIPs the end-to-end run when `npm` is absent on the executing
machine). All other verifiers are static-shape and do not SKIP.

## Inputs

### From Previous Tasks

- `packaging/homebrew/orchestrator.rb.tmpl` (from T01) — referenced
  in `## Installing via Homebrew` documentation by name only (no
  inline content quote).
- `.github/workflows/release.yml § homebrew-publish` (from T02) —
  referenced in `## Releasing via Homebrew` by name; the doc
  describes the job's behavior at the operator-runbook level.
- All seven per-truth verifiers from T01–T03 — chained by the
  phase-suite aggregator.

### From Disk (Pre-existing)

- `references/installation.md` — extended additively. `##
  Channel-specific metadata files` and `## Verifying integrity`
  sections are NOT modified.
- `commands/update.md` — extended with a single new bullet or section.

## Constraints

- Bash 3.2 compatible for all four scripts (two doc verifiers + the
  aggregator + any helper).
- Documentation MUST be operator-self-sufficient — no cross-references
  to internal plan artifacts (e.g. `M035-CONTEXT.md`,
  `P03-PLAN.md`). The doc is read by adopters; internal artifacts
  are not on disk in adopter installs.
- The phase-suite aggregator's BATTERY line MUST follow the canonical
  shape `BATTERY: pass=N fail=0 skip=K` so the M035 acceptance battery
  in P06 can grep for it.

## Expected Output

- `references/installation.md` extended with two new sections (≥80
  total new lines).
- `commands/update.md` extended with one new bullet/section.
- `tools/verify/m035-p03-installation-doc-homebrew.sh` (≥25 lines,
  emits `BATTERY: pass=N fail=0`).
- `tools/verify/m035-p03-update-skill-doc-homebrew.sh` (≥20 lines,
  emits `BATTERY: pass=N fail=0`).
- `tools/verify/m035-p03-phase-suite.sh` (≥30 lines, emits canonical
  `BATTERY:` summary).
