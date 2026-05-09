---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M035"
name: "Extend .github/workflows/release.yml with install.sh staging + timeout-minutes: 20 (CON-8) + DECISIONS row D010"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped `packaging/install/install.sh` (executable, on disk).
  Verify: `ls -l packaging/install/install.sh` returns a `-rwxr-xr-x`
  permission listing.
- `.github/workflows/release.yml` exists at the documented shape (P02
  T04 + P03 T02 + P05 T03 cumulative): `name: release`, `on: pull_request
  + push`, `permissions: contents: read`, three jobs (`pr-validate`,
  `npm-publish`, `homebrew-publish`).
- `.orchestrator/DECISIONS.md` exists with D009 recorded (T01 just
  appended it).

## Description

Extend `.github/workflows/release.yml` so the existing `npm-publish`
job stages `packaging/install/install.sh` into `release-artifacts/`
alongside the npm tarball. The downstream P05 cosign-sign loop
(`for artifact in *`) signs install.sh automatically; the SHA256SUMS
generation step computes a digest for install.sh automatically; the
`gh release create release-artifacts/*` glob uploads install.sh as a
release asset automatically. **No edit to those steps is required** —
install.sh is just one more file in `release-artifacts/`.

Bind **D010** (CON-8 timeout: 20 minutes on ubuntu-latest) by adding
`timeout-minutes: 20` at job level on `npm-publish` and `homebrew-publish`.

Author the task-grain verifier
`tools/verify/m035-p04-release-workflow-curl-arm.sh`.

**No new secrets surface.** install.sh has no curl-channel-specific
secret; the existing CON-6 negative-assertions in pr-validate (no
NPM_TOKEN, no HOMEBREW_TAP_TOKEN) remain sufficient. The verifier
explicitly asserts that no new `secrets.*` references appear in the
workflow (regression guard).

## Steps

1. **Verify path-collision before authoring the verifier.**

   ```bash
   ls tools/verify/m035-p04-release-workflow-curl-arm.sh 2>&1
   ```

   Expected: `ls: tools/verify/m035-p04-release-workflow-curl-arm.sh:
   No such file or directory`.

2. **Edit `.github/workflows/release.yml` — install.sh staging.**
   Use the Edit tool. The existing `Stage release artifacts` step
   currently reads (around line 184):

   ```yaml
         - name: Stage release artifacts
           run: |
             mkdir -p release-artifacts
             # npm tarball: re-pack locally rather than re-downloading
             # from the registry. The npm-pack output is byte-identical
             # to what `npm publish` just uploaded a moment ago.
             TAG="${GITHUB_REF#refs/tags/v}"
             # @build-fractal/orchestrator -> build-fractal-orchestrator
             # npm pack produces build-fractal-orchestrator-<version>.tgz
             npm pack
             mv build-fractal-orchestrator-"$TAG".tgz release-artifacts/
             # P03 hook: homebrew bottle would land here.
             # P04 hook: install.sh would land here.
             ls -la release-artifacts/
   ```

   Replace the `# P04 hook: install.sh would land here.` line with:

   ```yaml
             # P04 (T02): stage install.sh into release-artifacts/.
             # The downstream cosign-sign loop signs install.sh
             # automatically (for artifact in *); SHA256SUMS step
             # computes its digest automatically; gh release create
             # uploads it via release-artifacts/* glob. No edit to
             # those steps required.
             cp packaging/install/install.sh release-artifacts/
   ```

   Use Edit with `old_string` matching the literal `# P04 hook: install.sh would land here.`
   line (single-occurrence in the workflow). After Edit, sanity-check
   with `grep -nF 'cp packaging/install/install.sh release-artifacts/' .github/workflows/release.yml`
   — expect exactly one match.

3. **Edit `.github/workflows/release.yml` — `timeout-minutes: 20` on
   `npm-publish` job.** Locate the `npm-publish:` job header (line
   106). The current shape is:

   ```yaml
     npm-publish:
       name: npm-publish (tag-push only)
       runs-on: ubuntu-latest
       # CON-6: this job runs ONLY on v* tag push events ...
       if: ${{ startsWith(github.ref, 'refs/tags/v') && github.event_name == 'push' }}
       # M035 P05 T03 — job-level permissions override.
       ...
       permissions:
         contents: write
         id-token: write
   ```

   Add `timeout-minutes: 20` immediately after `runs-on: ubuntu-latest`
   (and before the `if:` line). Use Edit with `old_string` matching
   the literal:

   ```
     npm-publish:
       name: npm-publish (tag-push only)
       runs-on: ubuntu-latest
   ```

   Replace with:

   ```
     npm-publish:
       name: npm-publish (tag-push only)
       runs-on: ubuntu-latest
       # CON-8 (M035 P04 T02 / D010): 20-minute timeout on ubuntu-latest.
       # Escalation: if measured wall-clock consistently >15min across
       # three synthetic-tag runs, split into parallel jobs or document
       # a revised timeout.
       timeout-minutes: 20
   ```

4. **Edit `.github/workflows/release.yml` — `timeout-minutes: 20` on
   `homebrew-publish` job.** Locate the `homebrew-publish:` job header
   (line 274). The current shape is:

   ```yaml
     homebrew-publish:
       name: homebrew-publish (tag-push only)
       runs-on: ubuntu-latest
       needs: npm-publish
   ```

   Add `timeout-minutes: 20` immediately after `runs-on: ubuntu-latest`
   (and before the `needs:` line). Use Edit with `old_string` matching
   the literal:

   ```
     homebrew-publish:
       name: homebrew-publish (tag-push only)
       runs-on: ubuntu-latest
       needs: npm-publish
   ```

   Replace with:

   ```
     homebrew-publish:
       name: homebrew-publish (tag-push only)
       runs-on: ubuntu-latest
       needs: npm-publish
       # CON-8 (M035 P04 T02 / D010): 20-minute timeout on ubuntu-latest.
       # Same shape as npm-publish; per-job timeout means a hung
       # homebrew-publish doesn't block npm-publish's success signal.
       timeout-minutes: 20
   ```

5. **Validate the modified YAML structurally** via the staged probe
   pattern P02 T04 / P05 T03 used. Author the probe content via Write
   to `/tmp/m035-p04-t02-yaml-validate.sh` first:

   ```bash
   #!/usr/bin/env bash
   # /tmp/m035-p04-t02-yaml-validate.sh
   # Structural shape-guard for .github/workflows/release.yml after
   # T02 edits. Uses python yaml.safe_load to catch indentation
   # breakage; mirrors P02 T04 + P05 T03 staged-probe pattern.
   set -u
   REPO_ROOT="${REPO_ROOT:-$HOME/Sites/spec-kit-orchestrator}"
   if [ ! -f "$REPO_ROOT/.github/workflows/release.yml" ]; then
     echo "FAIL: release.yml missing at $REPO_ROOT/.github/workflows/release.yml" >&2
     exit 1
   fi
   python3 -c "import yaml,sys; yaml.safe_load(open('$REPO_ROOT/.github/workflows/release.yml'))" \
     || { echo "FAIL: release.yml YAML parse failed" >&2; exit 1; }
   echo "PASS: release.yml YAML parses"
   ```

   Then invoke:

   ```bash
   bash scripts/util/run-probe.sh /tmp/m035-p04-t02-yaml-validate.sh
   ```

   Expect: `PASS: release.yml YAML parses`. If FAIL, re-read the
   workflow at the edit points and inspect for indentation drift.

6. **Append D010 to `.orchestrator/DECISIONS.md`.** Use Edit. Locate
   the end of the D009 block (just appended in T01) and append a
   blank line then:

   ```markdown

   ### D010 — Release-workflow CI timeout: 20 minutes on ubuntu-latest (CON-8)

   **Date**: 2026-05-09
   **Phase**: M035 P04 T02
   **Status**: bound

   `npm-publish` and `homebrew-publish` jobs each carry
   `timeout-minutes: 20` at job level in `.github/workflows/release.yml`.

   **Rationale**:

   1. **Spec recommendation honored.** The spec's `#Q-G6` recommendation
      is "20 minutes on Ubuntu-latest" + new CON-8 escalation clause.
      D010 adopts the recommendation without deviation.
   2. **Headroom over typical run.** Current heaviest steps (`npm publish`
      ~30s, `npm pack` ~5s, cosign-keyless sign over ~4 artifacts ~30s
      total, SHA256SUMS ~1s, `gh release create` ~10s, downstream
      `homebrew-publish` ~45s) total ~3min nominal; 20min provides 6×
      headroom for OIDC issuance latency, transient network failures,
      cosign/sigstore log-write retries.
   3. **CON-8 escalation clause is the safety net.** If wall-clock
      consistently >15min across three synthetic-tag runs, plan-phase
      author splits the workflow into parallel jobs or documents a
      revised timeout. CON-8 makes the contract explicit so future
      plan-phase authors don't re-litigate the value.
   4. **Job-level not workflow-level.** `timeout-minutes` is per-job in
      GitHub Actions. Per-job timeout means a hung `homebrew-publish`
      doesn't block `npm-publish`'s success signal (and vice versa).

   **Bound to**: SC-14, CON-8, FR-10.

   **Cross-references**: `.github/workflows/release.yml`,
   `references/installation.md § Releasing via curl-pipe-bash` (T04
   adds the operator-facing note).
   ```

7. **Author `tools/verify/m035-p04-release-workflow-curl-arm.sh`.**
   Save the file then `chmod +x`:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p04-release-workflow-curl-arm.sh
   #
   # M035 P04 T02 task-grain verifier. Asserts release.yml shape after
   # T02 edits:
   #   * file exists
   #   * Stage release artifacts step contains
   #     `cp packaging/install/install.sh release-artifacts/`
   #   * npm-publish job has timeout-minutes: 20 (CON-8 / D010)
   #   * homebrew-publish job has timeout-minutes: 20 (CON-8 / D010)
   #   * No new secrets.* references introduced (only NPM_TOKEN,
   #     HOMEBREW_TAP_TOKEN, GITHUB_TOKEN — pre-existing P02/P03/P05)
   #   * D010 row recorded in .orchestrator/DECISIONS.md
   #
   # AD-19 single-script-file shape. Bash 3.2 compatible.

   set -u

   REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
   WORKFLOW="$REPO_ROOT/.github/workflows/release.yml"
   DECISIONS="$REPO_ROOT/.orchestrator/DECISIONS.md"

   pass=0
   fail=0

   check() {
     local name="$1"
     local result="$2"
     if [ "$result" = "0" ]; then
       echo "PASS: $name"
       pass=$((pass + 1))
     else
       echo "FAIL: $name"
       fail=$((fail + 1))
     fi
   }

   # 1. Workflow file exists.
   if [ -f "$WORKFLOW" ]; then check "release.yml exists" 0; else check "release.yml exists" 1; fi

   # 2. Stage release artifacts step copies install.sh.
   if grep -F 'cp packaging/install/install.sh release-artifacts/' "$WORKFLOW" >/dev/null; then check "install.sh staging line" 0; else check "install.sh staging line" 1; fi

   # 3. npm-publish job has timeout-minutes: 20.
   #    Asserted by counting timeout-minutes occurrences (must be >=2:
   #    one for npm-publish, one for homebrew-publish).
   timeout_count=$(grep -cE '^[[:space:]]+timeout-minutes:[[:space:]]+20$' "$WORKFLOW")
   if [ "$timeout_count" -ge 2 ]; then check "timeout-minutes: 20 occurs >=2 times (npm-publish + homebrew-publish)" 0; else check "timeout-minutes: 20 occurs >=2 times (got $timeout_count)" 1; fi

   # 4. CON-8 reference in workflow (cross-link to DECISIONS).
   if grep -q 'CON-8' "$WORKFLOW"; then check "CON-8 reference in workflow" 0; else check "CON-8 reference in workflow" 1; fi

   # 5. No new secrets.* references — should match pre-T02 set:
   #    NPM_TOKEN (P02), HOMEBREW_TAP_TOKEN (P03), GITHUB_TOKEN (P02 + P03).
   #    Curl arm introduces NO new secret. The verifier asserts the
   #    workflow contains exactly these three secret references and
   #    no curl-named secret (regression guard against a future plan-
   #    phase author accidentally adding one).
   if grep -qE 'secrets\.(CURL|INSTALL_SH|PIPE_BASH)' "$WORKFLOW"; then
     check "no curl-channel-specific secret introduced (regression guard)" 1
   else
     check "no curl-channel-specific secret introduced (regression guard)" 0
   fi

   # 6. D010 row recorded in .orchestrator/DECISIONS.md.
   if grep -qE '^### D010 ' "$DECISIONS"; then check "D010 row in DECISIONS.md" 0; else check "D010 row in DECISIONS.md" 1; fi

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

8. **Run the verifier and confirm `BATTERY: pass=6 fail=0`.**

   ```bash
   bash tools/verify/m035-p04-release-workflow-curl-arm.sh
   ```

9. **Run release.yml's existing P02/P03/P05 verifiers** to confirm
   T02's edits did not regress upstream contracts:

   ```bash
   bash tools/verify/m035-p02-release-workflow-shape.sh
   ```

   ```bash
   bash tools/verify/m035-p03-release-workflow-homebrew-job.sh
   ```

   ```bash
   bash tools/verify/m035-p05-release-workflow-signing-shape.sh
   ```

   All three must remain green (`BATTERY: pass=N fail=0`). If any
   regress: re-read the diff and locate which T02 edit broke the
   matching grep needle. Restore via Edit; do NOT skip the regression
   verifier.

10. **Commit atomically.**

    ```bash
    git add .github/workflows/release.yml tools/verify/m035-p04-release-workflow-curl-arm.sh .orchestrator/DECISIONS.md
    git commit -F /tmp/m035-p04-t02-commit-msg.txt
    ```

    Author commit message via Write to /tmp/m035-p04-t02-commit-msg.txt:

    ```
    M035 P04 T02: release.yml install.sh staging + timeout-minutes: 20 (D010)

    - .github/workflows/release.yml: cp packaging/install/install.sh into
      release-artifacts/ (P05 cosign-loop signs it, SHA256SUMS computes
      digest, gh release create uploads it — all automatic via existing
      glob iteration). timeout-minutes: 20 on npm-publish + homebrew-publish
      (CON-8 / D010, 6× headroom over nominal ~3min wall-clock).
    - .orchestrator/DECISIONS.md D010 — CON-8 release-workflow timeout:
      20 minutes on ubuntu-latest, with escalation clause for >15min
      observed wall-clock.
    - tools/verify/m035-p04-release-workflow-curl-arm.sh — 6-needle
      shape verifier (BATTERY pass=6 fail=0).
    ```

    Verify clean status:

    ```bash
    git status
    ```

    Expected: `On branch main`, clean tree. **Do NOT detach HEAD.**

## Must-Haves

This task addresses these phase must-haves:

- Truth: release.yml stages install.sh + has timeout-minutes: 20.
- Artifact: `.github/workflows/release.yml` modified.
- Artifact: `.orchestrator/DECISIONS.md` D010 row.
- Artifact: `tools/verify/m035-p04-release-workflow-curl-arm.sh`.
- Key Link: `.github/workflows/release.yml` → `packaging/install/install.sh`.

## Verification

```bash
bash tools/verify/m035-p04-release-workflow-curl-arm.sh
```

```bash
bash tools/verify/m035-p02-release-workflow-shape.sh
```

```bash
bash tools/verify/m035-p03-release-workflow-homebrew-job.sh
```

```bash
bash tools/verify/m035-p05-release-workflow-signing-shape.sh
```

```bash
bash scripts/util/run-probe.sh /tmp/m035-p04-t02-yaml-validate.sh
```

## Inputs

### From Previous Tasks

- `packaging/install/install.sh` (from T01) — the file that release.yml's
  `Stage release artifacts` step now copies into `release-artifacts/`.
  Required behavioral contract: file exists, executable, content
  irrelevant to T02 (T02 just `cp`s the file; install.sh's content is
  T01's responsibility).

### From Disk (Pre-existing)

- `.github/workflows/release.yml` — agent reads enough to locate the
  three edit points (Stage release artifacts step at line ~184,
  npm-publish job header at line 106, homebrew-publish job header at
  line 274). The full file content is not needed for editing.

- `.orchestrator/DECISIONS.md` — agent reads enough to confirm D009
  is the latest decision row (just appended by T01). Append D010 after
  the D009 block.

## Constraints

- **Existing P02/P03/P05 verifiers remain green.** T02's edits are
  additive (one `cp` line, two `timeout-minutes:` lines) — they MUST
  NOT regress any pre-existing release.yml shape contract. Step 9
  re-runs all three upstream verifiers to confirm.
- **YAML shape preserved.** The structural shape-guard in step 5
  catches indentation breakage. If the probe FAILs: re-read the
  modified workflow and fix the indentation drift before committing.
- **D010 row uses literal `### D### —` heading shape.** Same convention
  as D009 (T01) and D007/D008 (P03).
- **Stay on `main`.** No detached HEAD, no branch switching.
- **Single atomic commit.** All three changes (workflow, D010, verifier)
  ship in one commit.

## Expected Output

- `.github/workflows/release.yml` modified: install.sh staged into
  `release-artifacts/`, both publishing jobs carry `timeout-minutes: 20`.
- `.orchestrator/DECISIONS.md` D010 row appended.
- `tools/verify/m035-p04-release-workflow-curl-arm.sh` exists, BATTERY
  pass=6 fail=0.
- `m035-p02-release-workflow-shape.sh`, `m035-p03-release-workflow-homebrew-job.sh`,
  `m035-p05-release-workflow-signing-shape.sh` all remain green.
- Single git commit on `main`. Clean `git status`.

## Notes

**Why no edit to the cosign-sign step.** The existing P05 cosign loop
iterates `for artifact in *` and skips `*.sig`/`*.pem`/`SHA256SUMS`. It
signs every other file in `release-artifacts/`. Since install.sh is
just another file dropped into that dir, the loop signs it
automatically. Adding install.sh-specific sign logic would be redundant
and would risk drift between channels.

**Why no edit to the `gh release create` step.** The existing step
uploads `release-artifacts/*` as a glob. Same reasoning: install.sh
is just another file. Cleaner to rely on the glob than to enumerate
artifacts by name.

**Why timeout-minutes at job level not workflow level.** GitHub Actions
supports `jobs.<job>.timeout-minutes` but does NOT support a
workflow-level timeout-minutes. Per-job timeout means a hung
`homebrew-publish` doesn't block `npm-publish`'s success signal —
which matters because npm-publish runs FIRST in the release-workflow
DAG, and its success is the gate for the homebrew tarball reference.
A workflow-level timeout (if one existed) would conflate the two
risks.

**Why CON-8 reference in the workflow comment.** Future plan-phase
authors reading release.yml see "CON-8 (M035 P04 T02 / D010)" and
can immediately locate the rationale. Without the cross-reference,
the timeout value reads as an arbitrary 20.

**Why no negative-assertion for CURL_PIPE_BASH_TOKEN.** There is no
such secret. The regression-guard pattern (verifier needle 5) catches
the *future* shape where someone introduces one — at that future
plan-phase, they can choose to add a positive negative-assertion to
match the NPM_TOKEN / HOMEBREW_TAP_TOKEN pattern. Today the absence
is sufficient.
