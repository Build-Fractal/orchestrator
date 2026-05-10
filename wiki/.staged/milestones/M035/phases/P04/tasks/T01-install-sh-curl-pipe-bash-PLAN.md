---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M035"
name: "packaging/install/install.sh curl-pipe-bash entry-point + DECISIONS row D009"
depends_on: []
---

## Prerequisites

- `package.json` exists at repo root with `"name": "@build-fractal/orchestrator"`
  (P02 T01 — `ls package.json` confirms).
- `bin/orchestrator` exists, executable, prints version on `--version`
  (P02 T01 — `ls bin/orchestrator` confirms; agent does NOT need to
  read its content).
- `packaging/install/install-claude-code.sh` exists and accepts
  `--project-dir <PATH>` (pre-M035 — `ls packaging/install/install-claude-code.sh`
  confirms; agent does NOT need to read its content beyond the flag
  contract documented in the file's header comment).
- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) exists. Latest decision row is `### D008`
  (per `grep -nE '^### D[0-9]+' [.orchestrator/DECISIONS.md](../../../../../decisions.md)` at
  plan-authoring time, line 528). T01's D009 row appends after the
  D008 block.

## Description

Author `packaging/install/install.sh` — a bash 3.2 / POSIX-sh-safe
runtime-detect + tarball-fetch + dispatch wrapper that lands on the
GitHub release as a signed asset and is the target of `curl -sSL <url>
| bash` (US-8 / FR-10). For v1 this is **CC-only**: presence of
`~/.claude/` triggers dispatch into `install-claude-code.sh`; absence
emits a Codex-CLI/Cursor-deferred-to-M009 advisory and exits non-zero.

Record **D009** (install.sh URL host = GitHub release asset URL,
`https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh`)
in [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) using the literal `### D### —` heading
shape (column 0, no `{ #dr-code-NNN }` anchors — T01's grep verifier
gates on this exact shape).

Author the task-grain verifier `tools/verify/m035-p04-install-sh-shape.sh`.

Test-mode env-var hooks (`M035_P04_LOCAL_TARBALL`, `M035_P04_STAGE_ONLY`,
`M035_P04_STAGE_DIR`) are load-bearing for T03's byte-equivalence test —
they short-circuit the download/SHA-verify/dispatch chain so T03 can
exercise install.sh's real code path without network access. Default
OFF (no production behavior change when unset). Mirrors P05's
`COSIGN_AVAILABLE=1 + M035_P05_LIVE_RELEASE_DIR=path` default-OFF
live-mode pattern.

## Steps

1. **Verify path-collision before authoring.** From repo root:

   ```bash
   ls packaging/install/install.sh 2>&1
   ```

   Expected: `ls: packaging/install/install.sh: No such file or
   directory`. If the file already exists, STOP — escalate to the
   user (a different milestone or branch may have authored it).

2. **Author `packaging/install/install.sh`** with the following exact
   content (bash 3.2 / POSIX-sh-safe, executable). Save the file then
   `chmod +x packaging/install/install.sh`:

   ```bash
   #!/usr/bin/env bash
   # packaging/install/install.sh
   #
   # M035 P04 — curl-pipe-bash one-liner installer for orchestrator.
   #
   # Usage (consumer-facing):
   #   curl -sSL https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh | bash
   #
   # Or pinned to a version:
   #   ORCHESTRATOR_VERSION=v1.0.0 \
   #     curl -sSL https://github.com/Build-Fractal/orchestrator/releases/download/v1.0.0/install.sh | bash
   #
   # D009 (M035 P04 T01): hosted at GitHub release asset URL —
   #   latest:   https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh
   #   pinned:   https://github.com/Build-Fractal/orchestrator/releases/download/v<X.Y.Z>/install.sh
   # Rationale: zero new infrastructure, symmetric with the npm + homebrew
   # release-asset distribution model, versioned + unversioned URLs both
   # ship for free, reversible to a polished short URL post-launch.
   #
   # Test-mode env vars (default OFF, no production behavior change):
   #   M035_P04_LOCAL_TARBALL=<path>  short-circuits download/SHA-verify
   #                                  steps; uses the named tarball as
   #                                  if it had been downloaded from
   #                                  the release.
   #   M035_P04_STAGE_ONLY=1          extracts the tarball into the
   #                                  staging dir and exits 0 with
   #                                  `STAGED_DIR=<path>` on stdout —
   #                                  does NOT invoke install-claude-code.sh
   #                                  or remove the staged dir.
   #   M035_P04_STAGE_DIR=<path>      overrides the default mktemp -d
   #                                  staging dir (used by the byte-
   #                                  equivalence test to control hash
   #                                  scope).
   #
   # Bash 3.2 + POSIX-sh-safe (no associative arrays, no mapfile, no
   # process substitution, no jq, no python). Long-running probes use
   # if/then blocks rather than &&-chains beyond two clauses.
   #
   # Exit codes:
   #   0  success (install dispatched OR STAGE_ONLY mode complete)
   #   1  generic failure (FAIL: line on stderr)
   #   2  unsupported runtime (no Claude Code detected, no fallback)
   #   3  download or SHA-verify failed

   set -eu

   REPO="${ORCHESTRATOR_REPO:-Build-Fractal/orchestrator}"
   VERSION="${ORCHESTRATOR_VERSION:-latest}"
   LOCAL_TARBALL="${M035_P04_LOCAL_TARBALL:-}"
   STAGE_ONLY="${M035_P04_STAGE_ONLY:-0}"
   STAGE_DIR_OVERRIDE="${M035_P04_STAGE_DIR:-}"

   ORIG_PWD="$(pwd)"

   # --- Banner / --help / --version ---
   if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
     cat <<EOF
   orchestrator — curl-pipe-bash installer (M035 P04)

   Usage:
     curl -sSL https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh | bash

   Pinned version:
     ORCHESTRATOR_VERSION=v1.0.0 bash install.sh

   After install, run \`/orchestrator-init\` inside any project to
   register the orchestrator:<cmd> skill cohort.

   See https://github.com/Build-Fractal/orchestrator for source
   and references/installation.md for the full installation matrix.
   EOF
     exit 0
   fi

   if [ "${1:-}" = "--version" ]; then
     echo "orchestrator-install.sh (M035 P04 — see ${REPO})"
     exit 0
   fi

   # --- Resolve staging directory ---
   if [ -n "$STAGE_DIR_OVERRIDE" ]; then
     STAGED_DIR="$STAGE_DIR_OVERRIDE"
     mkdir -p "$STAGED_DIR"
   else
     STAGED_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t orchestrator-install)"
   fi

   # Cleanup trap unless STAGE_ONLY (test-mode preserves the tree).
   if [ "$STAGE_ONLY" != "1" ]; then
     trap 'rm -rf "$STAGED_DIR" 2>/dev/null || true' EXIT
   fi

   # --- Resolve tarball: download from GH release, OR use local override ---
   if [ -n "$LOCAL_TARBALL" ]; then
     # Test-mode: skip download + SHA-verify, use the named tarball.
     if [ ! -f "$LOCAL_TARBALL" ]; then
       echo "FAIL: M035_P04_LOCAL_TARBALL=$LOCAL_TARBALL — file not found" >&2
       exit 1
     fi
     TARBALL_PATH="$LOCAL_TARBALL"
     echo "M035_P04_LOCAL_TARBALL test-mode active — skipping download/SHA-verify"
   else
     # Production path: query GitHub for the release tag, derive
     # tarball URL, download via curl, verify SHA-256.
     if ! command -v curl >/dev/null 2>&1; then
       echo "FAIL: curl not on PATH — install.sh requires curl" >&2
       exit 1
     fi
     if ! command -v shasum >/dev/null 2>&1; then
       echo "FAIL: shasum not on PATH — install.sh requires shasum (or sha256sum)" >&2
       exit 1
     fi

     # Resolve TAG. If VERSION=latest, query GitHub for the latest
     # release tag (jq-free grep+sed parse of the JSON response).
     if [ "$VERSION" = "latest" ]; then
       LATEST_JSON="$(curl -sSL "https://api.github.com/repos/${REPO}/releases/latest")"
       TAG="$(printf '%s\n' "$LATEST_JSON" \
         | grep -E '"tag_name"[[:space:]]*:' \
         | head -1 \
         | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
     else
       TAG="$VERSION"
     fi

     if [ -z "$TAG" ]; then
       echo "FAIL: could not resolve release tag for VERSION=$VERSION" >&2
       exit 3
     fi

     # Strip leading v from TAG to derive the tarball asset name.
     # Asset name pattern: build-fractal-orchestrator-<version>.tgz
     # (npm scope @build-fractal/orchestrator -> file basename
     # build-fractal-orchestrator).
     TAG_NO_V="${TAG#v}"
     ASSET="build-fractal-orchestrator-${TAG_NO_V}.tgz"
     URL="https://github.com/${REPO}/releases/download/${TAG}/${ASSET}"
     SHA_URL="https://github.com/${REPO}/releases/download/${TAG}/SHA256SUMS"

     echo "Downloading $ASSET from $URL ..."
     TARBALL_PATH="$STAGED_DIR/$ASSET"
     if ! curl -sSL -o "$TARBALL_PATH" "$URL"; then
       echo "FAIL: download failed: $URL" >&2
       exit 3
     fi

     # Download SHA256SUMS and verify.
     SHA_PATH="$STAGED_DIR/SHA256SUMS"
     if ! curl -sSL -o "$SHA_PATH" "$SHA_URL"; then
       echo "FAIL: SHA256SUMS download failed: $SHA_URL" >&2
       exit 3
     fi
     ( cd "$STAGED_DIR" && shasum -a 256 -c SHA256SUMS --ignore-missing ) \
       || { echo "FAIL: SHA-256 verification failed for $ASSET" >&2; exit 3; }
     echo "PASS: SHA-256 verification — $ASSET"
   fi

   # --- Extract tarball ---
   # The npm pack tarball wraps content in a top-level package/ dir.
   # Flatten: extract package/* directly into $STAGED_DIR (mirrors
   # the homebrew formula's `prefix.install Dir["package/*"]` shape
   # and the npm-channel `lib/node_modules/<scope>/<name>/` shape —
   # cross-channel byte-equivalence requires identical post-extract
   # tree shape).
   tar -xzf "$TARBALL_PATH" -C "$STAGED_DIR" >/dev/null 2>&1 \
     || { echo "FAIL: tar extract failed for $TARBALL_PATH" >&2; exit 1; }
   if [ -d "$STAGED_DIR/package" ]; then
     # cp -R + rm rather than mv for exotic-FS robustness.
     cp -R "$STAGED_DIR/package/." "$STAGED_DIR/"
     rm -rf "$STAGED_DIR/package"
   fi

   # --- STAGE_ONLY test-mode exit ---
   if [ "$STAGE_ONLY" = "1" ]; then
     echo "STAGED_DIR=$STAGED_DIR"
     echo "PASS: M035_P04_STAGE_ONLY=1 — staging complete, dispatch skipped"
     exit 0
   fi

   # --- Runtime detection (CC-only at v1) ---
   if [ ! -d "$HOME/.claude" ]; then
     echo "FAIL: ~/.claude not found — Claude Code is the only supported runtime at v1." >&2
     echo "  Codex CLI / Cursor support is post-launch (M009 fast-follow);" >&2
     echo "  see references/installation.md for current runtime support." >&2
     exit 2
   fi

   # --- Dispatch ---
   INSTALLER="$STAGED_DIR/packaging/install/install-claude-code.sh"
   if [ ! -x "$INSTALLER" ]; then
     echo "FAIL: $INSTALLER not found or not executable in extracted tarball" >&2
     exit 1
   fi
   echo "Dispatching $INSTALLER --project-dir $ORIG_PWD ..."
   bash "$INSTALLER" --project-dir "$ORIG_PWD"
   echo "PASS: install.sh — orchestrator runtime staged into $ORIG_PWD"
   ```

3. **Make install.sh executable**:

   ```bash
   chmod +x packaging/install/install.sh
   ```

4. **Append D009 to [`.orchestrator/DECISIONS.md`](../../../../../decisions.md).** Use Edit (not Write —
   the file is large and pre-existing). Locate the end of the D008 block
   (around line 528 + body lines) and append a blank line then:

   ```markdown

   ### D009 — Curl-pipe-bash install.sh URL host: GitHub release asset URL

   **Date**: 2026-05-09
   **Phase**: M035 P04 T01
   **Status**: bound

   `install.sh` is hosted as a GitHub release asset, NOT on a separate
   domain (e.g. `orchestrator.dev`), NOT on github.io / fly.io / R2-backed
   CDN, NOT on a sub-path of an existing domain, NOT on the canonical
   repo's `/raw` URL.

   - Latest (unpinned): `https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh`
   - Pinned (versioned): `https://github.com/Build-Fractal/orchestrator/releases/download/v<X.Y.Z>/install.sh`

   **Rationale**:

   1. **No new infrastructure.** Every alternative requires either a
      new domain registration, a new hosting provider, or a stable-mainline-commit-SHA
      strategy — each introduces an external dependency M035 cannot
      reverse cheaply post-launch. The GitHub release `latest/download`
      URL is a stable redirect provided by GitHub itself, automatically
      resolves to the newest release's asset, and has zero new
      infrastructure surface.
   2. **Symmetric with the npm tarball + homebrew formula publication
      paths.** Both already use GitHub releases as the artifact source
      (D007 — homebrew formula's `url` field points at the npm pack
      tarball uploaded to the release; install.sh is one more asset
      on the same release). Adopting a different host for install.sh
      would fork the release-artifact distribution model.
   3. **Versioned + unversioned URLs both ship for free.**
      `latest/download/install.sh` resolves to the newest release;
      `download/v<X.Y.Z>/install.sh` pins to a specific tag.
      Operators pinning to a known-good version (per Constitution
      Principle XVI integrity-first ethos) get a stable URL without
      any redirect indirection.
   4. **Reversible.** If post-launch demand surfaces for a polished
      short URL (e.g., `orchestrator.dev/install.sh`), wiring a
      redirect against the same canonical asset is a one-line DNS
      change with no change to install.sh's content or signing
      surface. Picking the GitHub release URL today does not
      foreclose any future option.

   **Bound to**: FR-10, US-8, SC-14.

   **Cross-references**: `packaging/install/install.sh`,
   `references/installation.md § Installing via curl-pipe-bash`.
   ```

5. **Author `tools/verify/m035-p04-install-sh-shape.sh`.** Verifier asserts
   the install.sh shape via grep -F / grep -E patterns. Save the file
   then `chmod +x tools/verify/m035-p04-install-sh-shape.sh`:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p04-install-sh-shape.sh
   #
   # M035 P04 T01 task-grain verifier. Asserts packaging/install/install.sh
   # shape:
   #   * file exists, executable
   #   * shebang is bash
   #   * declares M035_P04_LOCAL_TARBALL test-mode hook
   #   * declares M035_P04_STAGE_ONLY test-mode hook
   #   * declares M035_P04_STAGE_DIR test-mode hook
   #   * references Build-Fractal/orchestrator (D009)
   #   * references the canonical latest/download URL (D009)
   #   * uses tar -xzf for extraction
   #   * dispatches into install-claude-code.sh
   #   * checks for ~/.claude (CC-only runtime detection)
   #   * uses shasum -a 256 -c for SHA verification
   #   * has --version / --help banner emitting [D-RN-3](../../../../../decisions.md#d-rn-3-command-cohort-prefix-orchestratorcmd-dr-code-031 "Command-cohort prefix `orchestrator:<cmd>` { #dr-code-031 }") cohort prefix string
   # Plus the D009 row in [.orchestrator/DECISIONS.md](../../../../../decisions.md) is grep-asserted.
   #
   # AD-19 single-script-file shape. Bash 3.2 compatible.

   set -u

   REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
   INSTALL_SH="$REPO_ROOT/packaging/install/install.sh"
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

   # 1. File exists and is executable.
   if [ -x "$INSTALL_SH" ]; then check "install.sh exists + executable" 0; else check "install.sh exists + executable" 1; fi

   # 2. Shebang is bash.
   if [ -f "$INSTALL_SH" ] && head -1 "$INSTALL_SH" | grep -q 'bash'; then check "shebang is bash" 0; else check "shebang is bash" 1; fi

   # 3. Declares M035_P04_LOCAL_TARBALL hook.
   if grep -q 'M035_P04_LOCAL_TARBALL' "$INSTALL_SH"; then check "M035_P04_LOCAL_TARBALL hook" 0; else check "M035_P04_LOCAL_TARBALL hook" 1; fi

   # 4. Declares M035_P04_STAGE_ONLY hook.
   if grep -q 'M035_P04_STAGE_ONLY' "$INSTALL_SH"; then check "M035_P04_STAGE_ONLY hook" 0; else check "M035_P04_STAGE_ONLY hook" 1; fi

   # 5. Declares M035_P04_STAGE_DIR hook.
   if grep -q 'M035_P04_STAGE_DIR' "$INSTALL_SH"; then check "M035_P04_STAGE_DIR hook" 0; else check "M035_P04_STAGE_DIR hook" 1; fi

   # 6. References Build-Fractal/orchestrator (D009).
   if grep -q 'Build-Fractal/orchestrator' "$INSTALL_SH"; then check "Build-Fractal/orchestrator reference" 0; else check "Build-Fractal/orchestrator reference" 1; fi

   # 7. References the canonical latest/download URL (D009).
   if grep -F 'releases/latest/download/install.sh' "$INSTALL_SH" >/dev/null; then check "latest/download URL" 0; else check "latest/download URL" 1; fi

   # 8. Uses tar -xzf for extraction.
   if grep -qE 'tar[[:space:]]+-xzf' "$INSTALL_SH"; then check "tar -xzf extraction" 0; else check "tar -xzf extraction" 1; fi

   # 9. Dispatches into install-claude-code.sh.
   if grep -q 'install-claude-code.sh' "$INSTALL_SH"; then check "install-claude-code.sh dispatch" 0; else check "install-claude-code.sh dispatch" 1; fi

   # 10. Checks for ~/.claude (CC-only runtime detection).
   if grep -qE '\$HOME/\.claude|~/\.claude' "$INSTALL_SH"; then check "~/.claude runtime detection" 0; else check "~/.claude runtime detection" 1; fi

   # 11. Uses shasum -a 256 -c for SHA verification.
   if grep -F 'shasum -a 256 -c' "$INSTALL_SH" >/dev/null; then check "shasum -a 256 -c verification" 0; else check "shasum -a 256 -c verification" 1; fi

   # 12. --version / --help banner emits orchestrator:<cmd> cohort prefix string ([D-RN-3](../../../../../decisions.md#d-rn-3-command-cohort-prefix-orchestratorcmd-dr-code-031 "Command-cohort prefix `orchestrator:<cmd>` { #dr-code-031 }")).
   if grep -F 'orchestrator:' "$INSTALL_SH" >/dev/null; then check "orchestrator:<cmd> cohort prefix in banner" 0; else check "orchestrator:<cmd> cohort prefix in banner" 1; fi

   # 13. D009 row recorded in [.orchestrator/DECISIONS.md](../../../../../decisions.md).
   if grep -qE '^### D009 ' "$DECISIONS"; then check "D009 row in DECISIONS.md" 0; else check "D009 row in DECISIONS.md" 1; fi

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

6. **Run the verifier and confirm `BATTERY: pass=13 fail=0`.**

   ```bash
   bash tools/verify/m035-p04-install-sh-shape.sh
   ```

7. **Smoke-test install.sh's STAGE_ONLY mode against the existing npm
   pack tarball.** This is a sanity check that the script's extraction
   path produces the expected package-flat shape — it doesn't replace
   T03's byte-equivalence verifier, but catches gross authoring errors
   (e.g., wrong tarball-extract semantics) before T02/T03 build on this
   surface.

   ```bash
   bash scripts/util/run-probe.sh /tmp/m035-p04-t01-install-sh-stage-only-smoke.sh
   ```

   The probe content: `npm pack --pack-destination "$TMPDIR/np"; TARBALL=$(find $TMPDIR/np -name 'build-fractal-orchestrator-*.tgz' -type f | head -1); M035_P04_LOCAL_TARBALL="$TARBALL" M035_P04_STAGE_ONLY=1 M035_P04_STAGE_DIR="$TMPDIR/staged" bash packaging/install/install.sh; ls "$TMPDIR/staged/package.json" >/dev/null 2>&1 && echo SMOKE_OK || echo SMOKE_FAIL`. Author the probe content via the Write tool to /tmp/m035-p04-t01-install-sh-stage-only-smoke.sh first, then invoke. Expect `SMOKE_OK` on stdout. If `SMOKE_FAIL`: re-read install.sh's extraction logic; the tarball flatten step may have a bug.

8. **Commit the work atomically (single commit per task).**

   ```bash
   git add packaging/install/install.sh tools/verify/m035-p04-install-sh-shape.sh [.orchestrator/DECISIONS.md](../../../../../decisions.md)
   git commit -F /tmp/m035-p04-t01-commit-msg.txt
   ```

   Author the commit message to /tmp/m035-p04-t01-commit-msg.txt via
   Write first, with this content:

   ```
   M035 P04 T01: install.sh curl-pipe-bash entry-point + D009

   - packaging/install/install.sh — bash 3.2 / POSIX-sh-safe runtime-detect
     + tarball-fetch + dispatch wrapper. CC-only at v1 (Codex CLI / Cursor
     post-launch via M009). Test-mode env vars M035_P04_LOCAL_TARBALL +
     M035_P04_STAGE_ONLY + M035_P04_STAGE_DIR for T03 byte-equivalence.
   - [.orchestrator/DECISIONS.md](../../../../../decisions.md) D009 — install.sh hosted at GitHub
     release asset URL (no new infrastructure, symmetric with npm +
     homebrew release-asset distribution model, reversible).
   - tools/verify/m035-p04-install-sh-shape.sh — 13-grep-needle shape
     verifier (BATTERY pass=13 fail=0).
   ```

   Verify the commit landed on `main` and the branch did not detach:

   ```bash
   git status
   ```

   Expected: `On branch main`, `nothing to commit, working tree clean`.
   If detached HEAD or any other branch surfaces: STOP — escalate to
   the user (P05 had three detached-HEAD incidents; do not repeat).
   **Do NOT run `git checkout <sha>` or `git switch` post-commit at
   any point in this task** (per user-prompt session-hygiene).

## Must-Haves

This task addresses these phase must-haves:

- Truth: `packaging/install/install.sh` exists with the documented
  shape (verified by `m035-p04-install-sh-shape.sh`).
- Artifact: `packaging/install/install.sh` (min 120 lines).
- Artifact: [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) D009 row.
- Artifact: `tools/verify/m035-p04-install-sh-shape.sh`.
- Key Link: `packaging/install/install.sh` → `packaging/install/install-claude-code.sh`.

## Verification

```bash
bash tools/verify/m035-p04-install-sh-shape.sh
```

## Inputs

### From Previous Tasks

(none — this is the first task in P04)

### From Disk (Pre-existing)

- `package.json` — referenced indirectly: install.sh's tarball asset
  name is derived from the npm scope `@build-fractal/orchestrator`
  baked into package.json (asset basename = `build-fractal-orchestrator-<version>.tgz`).
  Agent does NOT need to read package.json's content; the asset-name
  pattern is documented in the install.sh script header comment.
- `bin/orchestrator` — install.sh dispatches into install-claude-code.sh
  which writes the `bin/orchestrator` symlink onto PATH at install time;
  install.sh itself does not call bin/orchestrator.
- `packaging/install/install-claude-code.sh` — install.sh's dispatch
  target. Required behavioral contract:
  - Accepts `--project-dir <PATH>` flag (per its file header at line
    21).
  - Stages the bundle into the named project dir.
  - Returns exit 0 on success, non-zero on failure.

  install.sh invokes it as `bash <STAGED_DIR>/packaging/install/install-claude-code.sh
  --project-dir <ORIG_PWD>`. The agent does NOT need to read install-claude-code.sh's
  content beyond confirming the file exists and is executable (the
  flag contract is stable per pre-M035 + M035 P01 conventions).

- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) — agent reads only enough to confirm
  D008 is the latest decision row (`grep -nE '^### D[0-9]+' [.orchestrator/DECISIONS.md](../../../../../decisions.md)
  | tail -1` returns `### D008`). The full file content is not needed.

## Constraints

- **Bash 3.2 / POSIX-sh-safe.** No associative arrays (`declare -A`),
  no `mapfile` / `readarray`, no process substitution (`<()`/`>()`),
  no `set -o pipefail` (interacts surprisingly with `set -e` on bash
  3.2). Long-running probes use `if/then` blocks rather than `&&`-chains
  beyond two clauses (CON-3 / AP-009 single-script-shape constraint).
- **No jq, no python, no node.** install.sh runs on a fresh machine
  before any orchestrator-managed runtime is staged — only POSIX
  shell + standard Unix utilities (curl, tar, shasum, grep, sed, awk,
  mktemp) are guaranteed available.
- **No new CI secrets.** install.sh requires no secret access; sigstore
  signing is handled by the existing P05 cosign-loop in release.yml.
  (T02 verifies no new `secrets.*` references appear in the workflow.)
- **D009 row uses literal `### D### —` heading shape.** Column 0, no
  `{ #dr-code-NNN }` anchors. The plan's grep verifier gates on this
  shape (per user-prompt: "T01 ad-hoc decisions land as `### D### —`
  heading shape"). Do NOT use the M035 P01.5 D-RN-* anchor-shape.
- **Stay on `main` the entire run.** No `git checkout <sha>`, no
  `git switch`, no detached HEAD. P05 had three detached-HEAD
  incidents; commit, run verifier, done. (User-prompt session-hygiene.)
- **Single atomic commit.** All three artifacts (install.sh, D009 row,
  verifier) ship in one commit. RENAME-PLAN convention § 5.

## Expected Output

- `packaging/install/install.sh` exists, executable, ~180 lines (the
  template above is ~145 lines; a few lines of slack for formatting /
  comments preserves the min-120-line phase plan artifact constraint).
- [`.orchestrator/DECISIONS.md`](../../../../../decisions.md) extends with the D009 block at the end
  of the file.
- `tools/verify/m035-p04-install-sh-shape.sh` exists, executable, 13
  grep-needle assertions, emits `BATTERY: pass=13 fail=0`.
- Single git commit on `main` with the documented commit message.
- `git status` clean post-commit.

## Notes

**Why `mktemp -d` for staging.** Production install.sh runs with no
prior orchestrator state; it has no `.orchestrator/` to stage under.
Tarball extraction into a fresh `mktemp -d` is the only safe pattern
for fresh-machine bootstrapping. The cleanup `trap` removes the dir
post-dispatch unless STAGE_ONLY=1.

**Why STAGE_DIR override.** The byte-equivalence test (T03) needs to
hash the staged tree — but the helper `_byte-equivalence-hash.sh` reads
from `$STAGED` env var, which the test sets explicitly to a known path.
If install.sh always used a random `mktemp -d`, the test couldn't
predict the path to hash. STAGE_DIR override gives the test deterministic
control. Default-OFF: production install.sh ignores it (uses mktemp -d).

**Why `--ignore-missing` on shasum -c.** The SHA256SUMS file lists
multiple release artifacts (npm tarball, install.sh, homebrew formula
once P03 publishes its bottle reference, etc.); the operator's local
working dir only contains the one artifact they downloaded. `--ignore-missing`
is the documented pattern for partial-set verification (mirrors P05
T04's `references/installation.md § Verifying integrity` recipe).

**Why grep-F for the latest/download URL check (verifier needle 7).**
The URL contains `/` characters that are regex-significant; grep-F
literal-string match is safer than grep-E. Pattern from P03 T04's
heading verifiers (`grep -q -F --` family).

**install.sh's `set -eu` (not `set -euo pipefail`).** Bash 3.2 does
not handle `set -o pipefail` in combination with `set -e` reliably
across all builtin commands (notably `command -v` returns non-zero
inside pipefail-bound contexts on bash 3.2). install.sh sticks with
`set -eu` and uses explicit `|| { ... }` failure handling for pipes
that need it.
