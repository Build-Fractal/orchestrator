---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M035"
name: "Documentation (installation.md § Installing/Releasing via curl-pipe-bash, commands/update.md row) + DECISIONS row D011 + phase-suite aggregator + remaining verifiers"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

- T01 has shipped `packaging/install/install.sh` + D009.
- T02 has shipped `.github/workflows/release.yml` install.sh staging +
  `timeout-minutes: 20` + D010.
- T03 has shipped the curl-pipe-bash arm in
  `tests/m035-acceptance/cross-channel-byte-equivalence.sh`.
- `references/installation.md` exists with `## Installing via Homebrew`
  + `## Releasing via Homebrew` + `## Verifying integrity` sections
  already present (P03 T04 + P05 T04 cumulative).
- `commands/update.md` exists with `## Update sources` H2 enumerating
  git/npm/homebrew (P03 T04 — verify: `grep -nF '## Update sources' commands/update.md`
  returns one match).
- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) exists with D009 + D010 recorded.

## Description

Land the operator-facing and consumer-facing documentation for the
curl-pipe-bash channel, plus the phase-suite aggregator that chains
all six per-truth verifiers in T01→T04 order.

Documentation deliverables:

- `references/installation.md § Installing via curl-pipe-bash`
  (consumer-facing — `curl … | bash` recipe + `orchestrator --version`
  smoke + per-project `/orchestrator-init` setup + version-pinning
  via `ORCHESTRATOR_VERSION=v<X.Y.Z>` + uninstall recipe).
- `references/installation.md § Releasing via curl-pipe-bash`
  (operator-facing — D009 GitHub-release-asset-URL contract + D010 /
  CON-8 20-minute timeout + D011 manual-stable-releases-pre-1.0
  cadence + MOS-4 / MOS-5 first-release smoke procedure).
- `commands/update.md` — append `update_source: curl-pipe-bash` row
  to the `## Update sources` H2 (P06 wires the actual dispatch; P04
  records the surface symmetric with P03's homebrew row).

Decision deliverable:

- D011 row in [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) (release cadence: manual
  stable releases pre-1.0, operator-policy-only, no code surface).

Verifier deliverables:

- `tools/verify/m035-p04-installation-doc-curl.sh` — installation.md
  shape check.
- `tools/verify/m035-p04-update-skill-doc-curl.sh` — commands/update.md
  shape check.
- `tools/verify/m035-p04-phase-suite.sh` — chains the six per-truth
  verifiers (T01 install-sh-shape, T02 release-workflow-curl-arm,
  T03 byte-equivalence-curl-arm, T04 installation-doc-curl, T04
  update-skill-doc-curl, T04 self-reference).

## Steps

1. **Verify path-collisions before authoring.**

   ```bash
   ls tools/verify/m035-p04-installation-doc-curl.sh 2>&1
   ```

   ```bash
   ls tools/verify/m035-p04-update-skill-doc-curl.sh 2>&1
   ```

   ```bash
   ls tools/verify/m035-p04-phase-suite.sh 2>&1
   ```

   Expected: each returns "No such file or directory".

2. **Locate the insertion point in `references/installation.md`.**

   ```bash
   grep -nE '^## ' references/installation.md
   ```

   Identify the EOF section (per P03 T04's "insertion-point-drift-judgment-call"
   pattern: append at actual EOF rather than splitting an existing
   block). Record the last `## ` heading line number for use in step 3.

3. **Append `## Installing via curl-pipe-bash` + `## Releasing via curl-pipe-bash`
   sections to `references/installation.md`.** Use Edit, with `old_string`
   matching the LAST line of the file (use `tail -3 references/installation.md`
   to capture the exact terminal lines), and `new_string` = the
   captured terminal lines + the new section content. Sample new
   content:

   ```markdown

   ## Installing via curl-pipe-bash

   The simplest way to bootstrap orchestrator on a fresh machine is the
   curl-pipe-bash one-liner — no clone, no package manager, just
   `install.sh` from the GitHub release.

   **Latest release**:

   ```bash
   curl -sSL https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh | bash
   ```

   **Pinned to a specific version**:

   ```bash
   ORCHESTRATOR_VERSION=v1.0.0 \
     curl -sSL https://github.com/Build-Fractal/orchestrator/releases/download/v1.0.0/install.sh | bash
   ```

   `install.sh` downloads the npm tarball asset from the GitHub release
   (D007 single source of truth — same tarball as `npm install -g
   @build-fractal/orchestrator` consumes), verifies its SHA-256 against
   the published `SHA256SUMS` file, extracts it into a temporary
   staging directory, and dispatches into `packaging/install/install-claude-code.sh`
   with the current working directory as the project root.

   **Smoke test post-install**:

   ```bash
   orchestrator --version
   # → matches the latest published release version
   ```

   **Per-project setup** (run once per project after install):

   ```bash
   /orchestrator-init
   ```

   Registers the orchestrator skills under `~/.claude/skills/` so the
   `orchestrator:<cmd>` cohort is discoverable in any Claude Code
   session in that project.

   **Uninstall**:

   ```bash
   bash packaging/install/install-claude-code.sh --uninstall
   ```

   The uninstall reads `.orchestrator/installed-files.txt` and removes
   exactly the files staged at install time, mirroring the npm and
   homebrew uninstall paths.

   **Runtime support at v1**: Claude Code only. `install.sh` detects
   `~/.claude/` presence; absence triggers a Codex-CLI-/Cursor-deferred-to-M009
   advisory and exits non-zero. Post-launch M009 (multi-runtime parity
   audit) extends to Codex CLI and Cursor.

   **Verifying integrity before install** (optional, recommended for
   production deployments): see `## Verifying integrity` above for the
   sigstore keyless cosign-verify-blob recipe + SHA256SUMS-shasum-c
   fallback. The same verification applies to install.sh as to the npm
   tarball — both are signed by the same workflow at the same release
   tag (P05 D004).

   ## Releasing via curl-pipe-bash

   `install.sh` is published as a release asset on the canonical repo
   `Build-Fractal/orchestrator` GitHub release for every `v*` tag push.
   Three load-bearing decisions govern the release procedure:

   ### D009 — install.sh URL host: GitHub release asset URL

   `install.sh` is hosted at `https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh`
   (latest, unpinned) and `https://github.com/Build-Fractal/orchestrator/releases/download/v<X.Y.Z>/install.sh`
   (version-pinned). Rationale: zero new infrastructure, symmetric with
   the npm + homebrew release-asset distribution model, reversible to
   a polished short URL post-launch. See [`.orchestrator/DECISIONS.md`](../../../../../decisions.md)
   D009 for the full decision record.

   ### D010 / CON-8 — Release-workflow CI timeout: 20 minutes on ubuntu-latest

   Both `npm-publish` and `homebrew-publish` jobs in `.github/workflows/release.yml`
   carry `timeout-minutes: 20` at job level. Nominal wall-clock is ~3min;
   the 20min budget provides 6× headroom for OIDC issuance latency,
   transient network failures, and cosign/sigstore log-write retries.

   **CON-8 escalation clause**: if measured wall-clock consistently
   exceeds 15 minutes across three synthetic-tag runs, the next
   plan-phase author either splits the workflow into parallel jobs or
   documents a revised timeout. CON-8 is documentation-only at v1 (no
   automation enforces the watermark); future work could add a CI-side
   measurement-and-alert step.

   ### D011 — Release cadence: manual stable releases pre-1.0

   Pre-1.0, releases are operator-driven: the operator authors
   `CHANGELOG.md` for the release, bumps the version in `package.json`
   (CON-4 SemVer source of truth), commits, and pushes a `v*` tag. The
   release-workflow fires automatically on the tag push.

   Post-1.0, the spec recommends conventional-commits-driven version
   bumping with PR-merge auto-tagging — that is post-launch fast-follow
   scope (no code surface at v1).

   See [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) D011 for the full decision record.

   ### MOS-4 (operator) — One-time `curl … | bash` smoke against the first published release

   On first publication of a `v*` tag (e.g., the v1.0.0 launch), the
   operator validates end-to-end:

   ```bash
   # Fresh machine (or container with bash + curl + tar + shasum):
   curl -sSL https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh | bash
   orchestrator --version
   # → matches v1.0.0
   ```

   Asserts the GitHub `latest/download` URL resolves, install.sh is
   signed (sigstore + SHA-256 fallback per P05 D004), the dispatched
   install-claude-code.sh runs to completion. SC-14 is satisfied by
   this manual smoke.

   ### MOS-5 (operator) — Synthetic `v0.0.0-test` tag push against a fork

   Before the v1.0.0 launch, exercise SC-14 end-to-end via a synthetic
   tag push against a personal fork of `Build-Fractal/orchestrator`:

   ```bash
   git tag v0.0.0-test
   git push origin v0.0.0-test
   ```

   Observe the release workflow runs to completion within the CON-8
   20-minute timeout, the resulting GitHub release contains the four
   required artifacts (npm tarball, homebrew bottle, signed install.sh,
   SHA256SUMS file). Same workflow on a PR build does NOT run
   secret-bearing steps (verified by the existing CON-6 negative-assertions
   in `pr-validate`). After verification, delete the synthetic release
   and tag from the fork.
   ```

   **Authoring tip**: the multi-line markdown block above contains
   nested ` ```bash ` fenced code blocks. The Edit tool's `new_string`
   handles nested backticks correctly when the outer string is bound
   to a Python-/JSON-style multi-line literal. If indentation drift
   surfaces, use Read + Write rather than Edit (the entire file is
   ~625 lines + this section is ~140 lines new = ~765 lines total —
   still within Write tool's reasonable bound).

4. **Extend `commands/update.md ## Update sources` with the curl-pipe-bash
   row.** First locate the existing section:

   ```bash
   grep -nA 30 '## Update sources' commands/update.md
   ```

   The existing section enumerates git/npm/homebrew rows (P03 T04).
   Append a fourth row for `update_source: curl-pipe-bash`. Use Edit
   to append after the existing homebrew row. Sample addition:

   ```markdown

   ### `update_source: curl-pipe-bash`

   Re-runs `install.sh` from the latest release URL:

   ```bash
   curl -sSL https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh | bash
   ```

   The curl-pipe-bash channel re-bootstraps the runtime tree from the
   newest published `v*` tag. P06 wires the actual `orchestrator:update`
   dispatch under `scripts/lifecycle/run-update.sh`; P04 records the
   surface here for symmetry with the homebrew row above.

   See `references/installation.md § Installing via curl-pipe-bash`
   for the consumer-facing recipe and `references/installation.md
   § Releasing via curl-pipe-bash` for the operator-facing release
   procedure.
   ```

   **Insertion-point judgment** (per P03 T04 caveat): if the existing
   `## Update sources` section's homebrew block is followed by other
   structural content (e.g., a `## Rollback` H2 from P05 T02), append
   the curl-pipe-bash row immediately after the homebrew block and
   before the next H2 — preserves operator readability over plan-letter
   literalism.

5. **Append D011 to [`.orchestrator/DECISIONS.md`](../../../../../decisions.md).** Use Edit. Locate
   the end of the D010 block (just appended in T02) and append a
   blank line then:

   ```markdown

   ### D011 — Release cadence: manual stable releases pre-1.0 (operator-policy)

   **Date**: 2026-05-09
   **Phase**: M035 P04 T04
   **Status**: bound

   Pre-1.0 release cadence is **manual operator-driven tag push**. The
   operator authors `CHANGELOG.md` for the release, bumps the version
   in `package.json` (CON-4 SemVer source of truth), commits, and
   pushes a `v*` tag. The release-workflow fires automatically on the
   tag push.

   **Rationale**:

   1. **Spec recommendation honored.** The spec's `#Q-5` recommendation
      is "manual stable releases pre-1.0, automatic post-1.0 with
      conventional-commits-driven version bumping". D011 adopts the
      pre-1.0 portion and defers post-1.0 automation to a post-launch
      fast-follow.
   2. **No code surface at v1.** The release-workflow already fires
      on `v*` tag push (operator-driven). No CI cron, no PR-merge
      auto-tagging, no conventional-commits parsing.
   3. **Reversible.** Switching to automatic post-1.0 is purely
      additive: a new `.github/workflows/auto-tag.yml` + the
      conventional-commits parser ship as their own plan-phase work.
      D011 declares the v1 posture; future work supersedes via a new
      D### or by amending the documentation block.
   4. **Symmetric with operator-driven first-release MOS-4 / MOS-5.**
      The launch is itself an operator-driven tag push; pre-1.0
      cadence inherits the same shape for consistency.

   **Bound to**: US-8, FR-10. Operator workflow under MOS-1 / MOS-2 /
   MOS-3 / MOS-4 / MOS-5 precedent.

   **Cross-references**: `references/installation.md § Releasing via
   curl-pipe-bash`, `commands/update.md § Update sources`.
   ```

6. **Author `tools/verify/m035-p04-installation-doc-curl.sh`.**

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p04-installation-doc-curl.sh
   #
   # M035 P04 T04 task-grain verifier. Asserts references/installation.md
   # contains the curl-pipe-bash sections after T04 edits.
   #
   # AD-19 single-script-file shape. Bash 3.2 compatible.

   set -u

   REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
   DOC="$REPO_ROOT/references/installation.md"

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

   if [ -f "$DOC" ]; then check "installation.md exists" 0; else check "installation.md exists" 1; fi

   # Consumer-facing § Installing via curl-pipe-bash.
   if grep -qF '## Installing via curl-pipe-bash' "$DOC"; then check "## Installing via curl-pipe-bash heading" 0; else check "## Installing via curl-pipe-bash heading" 1; fi
   if grep -qF 'releases/latest/download/install.sh' "$DOC"; then check "latest/download URL recipe" 0; else check "latest/download URL recipe" 1; fi
   if grep -qF 'ORCHESTRATOR_VERSION=' "$DOC"; then check "ORCHESTRATOR_VERSION pinning recipe" 0; else check "ORCHESTRATOR_VERSION pinning recipe" 1; fi
   if grep -qF '/orchestrator-init' "$DOC"; then check "per-project /orchestrator-init step" 0; else check "per-project /orchestrator-init step" 1; fi
   if grep -qF '--uninstall' "$DOC"; then check "uninstall recipe" 0; else check "uninstall recipe" 1; fi

   # Operator-facing § Releasing via curl-pipe-bash.
   if grep -qF '## Releasing via curl-pipe-bash' "$DOC"; then check "## Releasing via curl-pipe-bash heading" 0; else check "## Releasing via curl-pipe-bash heading" 1; fi
   if grep -qF 'D009' "$DOC"; then check "D009 cross-reference" 0; else check "D009 cross-reference" 1; fi
   if grep -qF 'CON-8' "$DOC"; then check "CON-8 timeout reference" 0; else check "CON-8 timeout reference" 1; fi
   if grep -qF 'D010' "$DOC"; then check "D010 cross-reference" 0; else check "D010 cross-reference" 1; fi
   if grep -qF 'D011' "$DOC"; then check "D011 cross-reference" 0; else check "D011 cross-reference" 1; fi
   if grep -qF 'MOS-4' "$DOC"; then check "MOS-4 first-release smoke" 0; else check "MOS-4 first-release smoke" 1; fi
   if grep -qF 'MOS-5' "$DOC"; then check "MOS-5 synthetic tag push" 0; else check "MOS-5 synthetic tag push" 1; fi

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   `chmod +x tools/verify/m035-p04-installation-doc-curl.sh`.

7. **Author `tools/verify/m035-p04-update-skill-doc-curl.sh`.**

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p04-update-skill-doc-curl.sh
   #
   # M035 P04 T04 task-grain verifier. Asserts commands/update.md
   # contains the curl-pipe-bash row in ## Update sources.
   #
   # AD-19 single-script-file shape. Bash 3.2 compatible.

   set -u

   REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
   DOC="$REPO_ROOT/commands/update.md"

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

   if [ -f "$DOC" ]; then check "commands/update.md exists" 0; else check "commands/update.md exists" 1; fi

   if grep -qF '## Update sources' "$DOC"; then check "## Update sources heading" 0; else check "## Update sources heading" 1; fi
   if grep -qF 'update_source: curl-pipe-bash' "$DOC"; then check "update_source: curl-pipe-bash row" 0; else check "update_source: curl-pipe-bash row" 1; fi
   if grep -qF 'releases/latest/download/install.sh' "$DOC"; then check "latest/download URL in update doc" 0; else check "latest/download URL in update doc" 1; fi

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   `chmod +x tools/verify/m035-p04-update-skill-doc-curl.sh`.

8. **Author `tools/verify/m035-p04-phase-suite.sh`.** Aggregator — chains
   the six per-truth verifiers in T01→T04 order.

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p04-phase-suite.sh
   #
   # M035 P04 phase-suite aggregator. Chains every per-truth verifier
   # in T01→T04 order, parses each verifier's BATTERY line, sums
   # pass/fail/skip into a consolidated rollup, emits per-verifier
   # PASS/FAIL decisions plus a final BATTERY: pass=N fail=0 [skip=K]
   # summary line. Exit 0 iff total_fail=0.
   #
   # AD-19 single-script-file shape. Bash 3.2 compatible.
   # Mirrors P03's chain-the-children form (verifier-unit counting:
   # "pass" = number of children that exited 0).

   set -u

   REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"

   verifiers=(
     "$REPO_ROOT/tools/verify/m035-p04-install-sh-shape.sh"
     "$REPO_ROOT/tools/verify/m035-p04-release-workflow-curl-arm.sh"
     "$REPO_ROOT/tools/verify/m035-p04-byte-equivalence-curl-arm.sh"
     "$REPO_ROOT/tools/verify/m035-p04-installation-doc-curl.sh"
     "$REPO_ROOT/tools/verify/m035-p04-update-skill-doc-curl.sh"
   )

   pass=0
   fail=0

   for v in "${verifiers[@]}"; do
     if [ ! -x "$v" ]; then
       echo "FAIL: verifier missing or not executable: $v"
       fail=$((fail + 1))
       continue
     fi
     out_log="$(mktemp 2>/dev/null || mktemp -t m035p04phase)"
     err_log="$(mktemp 2>/dev/null || mktemp -t m035p04phase-err)"
     if bash "$v" >"$out_log" 2>"$err_log"; then
       echo "PASS: $(basename "$v")"
       pass=$((pass + 1))
     else
       echo "FAIL: $(basename "$v")"
       cat "$err_log" >&2 || true
       cat "$out_log" >&2 || true
       fail=$((fail + 1))
     fi
     rm -f "$out_log" "$err_log"
   done

   # Self-reference: count this aggregator as a 6th passing verifier
   # if all 5 children passed (mirrors P03's pattern of including the
   # aggregator in its own count).
   if [ "$fail" -eq 0 ]; then
     pass=$((pass + 1))
     echo "PASS: m035-p04-phase-suite.sh (self)"
   else
     echo "FAIL: m035-p04-phase-suite.sh (self) — children failed"
   fi

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   `chmod +x tools/verify/m035-p04-phase-suite.sh`.

9. **Run all four T04 verifiers individually** to confirm each is green:

   ```bash
   bash tools/verify/m035-p04-installation-doc-curl.sh
   ```

   Expected: `BATTERY: pass=12 fail=0`.

   ```bash
   bash tools/verify/m035-p04-update-skill-doc-curl.sh
   ```

   Expected: `BATTERY: pass=4 fail=0`.

   ```bash
   bash tools/verify/m035-p04-phase-suite.sh
   ```

   Expected: `BATTERY: pass=6 fail=0`.

10. **Run upstream P03 / P05 doc verifiers** to confirm T04's edits did
    not regress them:

    ```bash
    bash tools/verify/m035-p03-installation-doc-homebrew.sh
    ```

    ```bash
    bash tools/verify/m035-p03-update-skill-doc-homebrew.sh
    ```

    ```bash
    bash tools/verify/m035-p05-installation-doc-verifying-integrity.sh
    ```

    All three remain green.

11. **Commit atomically.**

    ```bash
    git add references/installation.md commands/update.md [.orchestrator/DECISIONS.md](../../../../../decisions.md) tools/verify/m035-p04-installation-doc-curl.sh tools/verify/m035-p04-update-skill-doc-curl.sh tools/verify/m035-p04-phase-suite.sh
    git commit -F /tmp/m035-p04-t04-commit-msg.txt
    ```

    Author commit message via Write to /tmp/m035-p04-t04-commit-msg.txt:

    ```
    M035 P04 T04: curl-pipe-bash docs + D011 + phase-suite aggregator

    - references/installation.md: ## Installing via curl-pipe-bash
      (consumer-facing recipe with version-pinning + uninstall) +
      ## Releasing via curl-pipe-bash (D009 / D010 / CON-8 / D011 +
      MOS-4 / MOS-5 operator procedures).
    - commands/update.md: append update_source: curl-pipe-bash row to
      ## Update sources H2 (P06 wires the actual dispatch).
    - [.orchestrator/DECISIONS.md](../../../../../decisions.md) D011 — manual stable releases pre-1.0
      (operator-policy, no code surface at v1; reversible to automatic
      post-1.0 conventional-commits-driven cadence).
    - tools/verify/m035-p04-installation-doc-curl.sh (BATTERY pass=12).
    - tools/verify/m035-p04-update-skill-doc-curl.sh (BATTERY pass=4).
    - tools/verify/m035-p04-phase-suite.sh — chains all six P04 per-
      truth verifiers (BATTERY pass=6 fail=0 self-reference inclusive).
    ```

    Verify clean status; **stay on `main`**.

## Must-Haves

This task addresses these phase must-haves:

- Truth: installation.md contains curl-pipe-bash sections.
- Truth: commands/update.md contains curl-pipe-bash row.
- Truth: phase-suite aggregator emits BATTERY pass=6 fail=0.
- Artifact: `references/installation.md` modified.
- Artifact: `commands/update.md` modified.
- Artifact: [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) D011 row.
- Artifact: `tools/verify/m035-p04-installation-doc-curl.sh`.
- Artifact: `tools/verify/m035-p04-update-skill-doc-curl.sh`.
- Artifact: `tools/verify/m035-p04-phase-suite.sh`.
- Key Link: installation.md → packaging/install/install.sh.
- Key Link: installation.md → Build-Fractal/orchestrator releases.
- Key Link: commands/update.md → references/installation.md.
- Key Link: phase-suite → individual per-truth verifiers.

## Verification

```bash
bash tools/verify/m035-p04-installation-doc-curl.sh
```

```bash
bash tools/verify/m035-p04-update-skill-doc-curl.sh
```

```bash
bash tools/verify/m035-p04-phase-suite.sh
```

```bash
bash tools/verify/m035-p03-installation-doc-homebrew.sh
```

```bash
bash tools/verify/m035-p03-update-skill-doc-homebrew.sh
```

```bash
bash tools/verify/m035-p05-installation-doc-verifying-integrity.sh
```

## Inputs

### From Previous Tasks

- `packaging/install/install.sh` (from T01) — referenced in installation.md
  prose (consumer-facing recipe describes its behavior) and indirectly
  via D009 cross-reference. T04 does NOT modify the script.

- `.github/workflows/release.yml` (from T02) — referenced in installation.md
  prose (operator-facing § Releasing via curl-pipe-bash describes the
  CON-8 timeout binding). T04 does NOT modify the workflow.

- `tests/m035-acceptance/cross-channel-byte-equivalence.sh` (from T03) —
  referenced indirectly via the FR-14 / SC-10 cross-channel-byte-equivalence
  contract documented in installation.md prose.

- D009 (T01) and D010 (T02) DECISIONS.md rows — T04 cross-references
  both in the new § Releasing via curl-pipe-bash section. T04 does NOT
  modify the existing D009/D010 blocks; only appends D011.

### From Disk (Pre-existing)

- `references/installation.md` — agent reads enough to locate the EOF
  insertion point (per P03 T04 "insertion-point-drift-judgment-call"
  pattern). Existing § Installing via Homebrew + § Releasing via
  Homebrew + § Verifying integrity sections inform the shape of the
  new sections (parallel structure for symmetry).

- `commands/update.md` — agent reads enough to locate the existing
  `## Update sources` H2 block and the boundary between the homebrew
  row and the next H2 section. The full file content not needed.

- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) — agent reads enough to confirm D010 is
  the latest decision row (just appended by T02). Append D011 after
  the D010 block.

- The six P04 per-truth verifier paths (for the aggregator's
  enumeration). The agent does NOT need to read the verifiers'
  internals; the aggregator just invokes them by path.

## Constraints

- **No regressions to upstream doc verifiers.** Step 10 re-runs the
  P03 + P05 doc verifiers explicitly. If any regress, re-read the
  installation.md insertion point and fix.
- **D011 row uses literal `### D### —` heading shape.** Same convention
  as D007/D008/D009/D010.
- **Phase-suite uses verifier-unit-counting form (pass=N where N=number
  of green children + 1 for self).** Mirrors P03's pattern, NOT P05's
  sum-the-counters form. P04 has no skip-able children at v1; the
  T03 byte-equivalence verifier handles its own internal SKIP path
  for the npm-absent case, surfacing as a 0-or-1 pass/fail at the
  aggregator level.
- **Insertion-point judgment.** If the actual EOF of installation.md
  has drifted (e.g., a post-P03 / post-P05 section appended that's
  not yet on disk at plan-authoring time), T04 appends new sections
  at the actual EOF — preserves operator readability over plan-letter
  literalism. Captured as the P03 T04 caveat pattern.
- **Stay on `main`.** No detached HEAD.
- **Single atomic commit.** All six changes (installation.md,
  update.md, D011, three verifiers) ship in one commit. RENAME-PLAN
  convention § 5.

## Expected Output

- `references/installation.md` modified: § Installing via curl-pipe-bash
  + § Releasing via curl-pipe-bash sections appended.
- `commands/update.md` modified: `update_source: curl-pipe-bash` row
  appended to `## Update sources` H2.
- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) D011 row appended.
- `tools/verify/m035-p04-installation-doc-curl.sh` exists, BATTERY
  pass=12 fail=0.
- `tools/verify/m035-p04-update-skill-doc-curl.sh` exists, BATTERY
  pass=4 fail=0.
- `tools/verify/m035-p04-phase-suite.sh` exists, BATTERY pass=6 fail=0.
- All upstream P03 + P05 doc verifiers remain green.
- Single git commit on `main`. Clean `git status`.

## Notes

**Why D011 is operator-policy not code surface.** The release-workflow
already fires on `v*` tag push — that's the existing P02/P03/P05
mechanism. D011 doesn't change behavior; it documents the v1 cadence
posture so future plan-phase authors don't re-litigate the value when
the post-1.0 automatic-cadence work lands. Mirrors P03's D008 documenting
the PAT-vs-GitHub-App posture for v1 with explicit reversibility.

**Why the phase-suite includes self-reference.** P03's phase-suite
emits `BATTERY: pass=7 fail=0` with 7 = 6 children + 1 self-reference.
P05's phase-suite uses sum-the-counters form (pass=50 = sum of every
child's BATTERY pass count). The P03 form is appropriate for P04
because P04's children all use the BATTERY-line shape but their counts
are independent (T01's pass=13, T03's pass=9, T04 children's pass=4
+ pass=12) — summing them would double-count via the aggregator's
own pass count. Verifier-unit counting (pass = number of green
children + self) is the cleaner shape.

**Why the operator-facing section duplicates D009/D010/D011 rationale
in prose.** Operators reading installation.md should not need to
context-switch to [.orchestrator/DECISIONS.md](../../../../../decisions.md) to understand the
release procedure. The DECISIONS.md rows are the canonical record;
the installation.md prose is the operator-facing exposition. Drift
between the two is a known risk; both verifiers grep for the literal
strings (`D009`, `CON-8`, `D010`, `D011`, `MOS-4`, `MOS-5`) so the
linkage is structurally enforced.

**Why no extension to the `## Channel-specific metadata files` table.**
The curl-pipe-bash channel produces the same staged tree as the
homebrew arm (both extract the npm tarball into a flat dir). At v1,
no curl-specific metadata files exist — the table's `all` rows cover
the curl arm. Future plan-phase authors discovering curl-specific
files extend the table per the existing convention documented in the
`## Channel-specific metadata files` section.

**Phase-close hand-off.** After T04 commits, P04 is structurally
complete on-disk: `P04-PLAN.md` + four task plans + (post-execution)
four task summaries + `P04-SUMMARY.md`. Execution itself blocks on
the [M033](../../../../../milestones/M033/index.md) friendly-tester pass deadline (≤ 2026-05-12 per
launch-sequencing-amendment Q-1). MOS-4 (first-release smoke) and
MOS-5 (synthetic tag push) are operator-side events that fire at
launch-rehearsal time, not at P04 closure. P04 closure is on-disk
artifact shape; operator smoke is the second milestone past closure.
