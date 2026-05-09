---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M035"
name: "Homebrew formula template + render script + DECISIONS row D007"
depends_on: []
---

## Prerequisites

- `package.json` exists at repo root with `"name":
  "@build-fractal/orchestrator"` (P02 T01).
- `bin/orchestrator` exists, executable, prints version on
  `--version` (P02 T01).
- `.orchestrator/DECISIONS.md` exists (D001–D005 already recorded).

## Description

Author the homebrew formula template under `packaging/homebrew/` and a
bash 3.2 render script that substitutes per-release values
(`__VERSION__`, `__URL__`, `__SHA256__`) into the template. Record
**D007** (homebrew tarball source: re-use the P05-signed `npm pack`
tarball) in `.orchestrator/DECISIONS.md`. Author the two task-grain
verifiers (`m035-p03-formula-template-shape.sh`,
`m035-p03-render-formula-shape.sh`).

The formula has NO formula-specific install logic per FR-9. `def
install` does only filesystem staging (extract tarball, install into
`prefix`, symlink `bin/orchestrator` onto PATH). Per-project skill
registration via M025's manifest happens later when the consumer runs
`/orchestrator-init` inside a project — same model as the npm channel
where `packaging/npm/postinstall.sh` advisories on `npm install -g`
without auto-registering globally.

## Steps

1. **Create `packaging/homebrew/` directory.**

   ```bash
   mkdir -p packaging/homebrew
   ```

2. **Author `packaging/homebrew/orchestrator.rb.tmpl`** with the
   following exact content (Ruby DSL, Homebrew formula format):

   ```ruby
   # packaging/homebrew/orchestrator.rb.tmpl
   #
   # Homebrew formula template for @build-fractal/orchestrator.
   # Rendered by packaging/homebrew/render-formula.sh at release time
   # via .github/workflows/release.yml § homebrew-publish.
   #
   # Substitution tokens (replaced verbatim by render-formula.sh):
   #   __VERSION__   -- semver string, e.g. 1.0.0
   #   __URL__       -- https URL of the npm pack tarball published
   #                    on the GitHub release (D007: re-use the P05-
   #                    signed @build-fractal/orchestrator tarball
   #                    rather than a separate brew-tarball; single
   #                    source-of-truth for cross-channel byte-
   #                    equivalence per CON-5).
   #   __SHA256__    -- 64-hex-char SHA-256 of the tarball, sourced
   #                    from the SHA256SUMS file in the GitHub release
   #                    (P05 T03 publishes this).
   #
   # FR-9: no formula-specific install logic. def install does
   # filesystem staging only; per-project skill registration via
   # M025's manifest is deferred to /orchestrator-init.

   class Orchestrator < Formula
     desc "Autonomous multi-phase software-engineering orchestrator"
     homepage "https://github.com/Build-Fractal/orchestrator"
     url "__URL__"
     version "__VERSION__"
     sha256 "__SHA256__"
     license "MIT"

     def install
       # The npm pack tarball extracts into a top-level "package/"
       # directory per npm's tarball convention. Stage its contents
       # (NOT the wrapping "package/" dir) into the formula prefix.
       prefix.install Dir["package/*"]

       # Wire bin/orchestrator onto PATH via Homebrew's bin symlink.
       bin.install_symlink prefix/"bin/orchestrator"
     end

     test do
       # Acceptance: formula installs, binary is on PATH, --version
       # matches the formula's version field. SC-9 smoke.
       assert_match version.to_s, shell_output("#{bin}/orchestrator --version")
     end
   end
   ```

   Notes for the executing agent:
   - Do NOT add `depends_on "node"` or `depends_on "python@3"`.
     The runtime exercised by `bin/orchestrator` and the scripts it
     dispatches assumes node + python3 are available; macOS ships
     python3 stock and node is operator-installed (or via brew
     itself). Adding hard `depends_on` declarations forces brew to
     install dependencies that may already be present, causing
     install friction without value.
   - Do NOT add an `on_macos` / `on_linux` block. The formula is
     identical across both platforms because the runtime is shell +
     markdown.
   - The `test do` block is a Homebrew-conventional smoke; SC-9 is
     satisfied by `brew install` succeeding + `orchestrator --version`
     matching, which `assert_match` covers.

3. **Author `packaging/homebrew/render-formula.sh`** as an executable
   bash 3.2-compatible script. Exact content:

   ```bash
   #!/usr/bin/env bash
   # packaging/homebrew/render-formula.sh -- render orchestrator.rb
   # from orchestrator.rb.tmpl by substituting __VERSION__ / __URL__ /
   # __SHA256__ tokens.
   #
   # Usage:
   #   bash packaging/homebrew/render-formula.sh \
   #     --version <X.Y.Z> \
   #     --url <https://...tgz> \
   #     --sha256 <64-hex-char-digest>
   #
   # Output (stdout): the rendered formula. No in-place writes;
   # callers redirect to the desired path (e.g. tap-clone/Formula/
   # orchestrator.rb).
   #
   # Bash 3.2 compatible. No declare -A, no <(...), no
   # command-substitution-with-pipes.

   set -u

   VERSION=""
   URL=""
   SHA256=""

   while [ $# -gt 0 ]; do
     case "$1" in
       --version)
         VERSION="${2:-}"
         shift 2
         ;;
       --url)
         URL="${2:-}"
         shift 2
         ;;
       --sha256)
         SHA256="${2:-}"
         shift 2
         ;;
       *)
         echo "FAIL: unknown flag: $1" >&2
         exit 1
         ;;
     esac
   done

   if [ -z "$VERSION" ]; then
     echo "FAIL: --version required" >&2
     exit 1
   fi
   if [ -z "$URL" ]; then
     echo "FAIL: --url required" >&2
     exit 1
   fi
   if [ -z "$SHA256" ]; then
     echo "FAIL: --sha256 required" >&2
     exit 1
   fi

   # Validate sha256 shape: exactly 64 hex chars, lowercase.
   if ! printf '%s' "$SHA256" | grep -qE '^[0-9a-f]{64}$'; then
     echo "FAIL: --sha256 must be 64 lowercase hex chars (got: $SHA256)" >&2
     exit 1
   fi

   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   TMPL="$SCRIPT_DIR/orchestrator.rb.tmpl"

   if [ ! -f "$TMPL" ]; then
     echo "FAIL: template not found: $TMPL" >&2
     exit 1
   fi

   # Substitute tokens. Use sed with | as delimiter because the URL
   # contains forward slashes. Escape | in URL defensively (URLs
   # almost never contain | but the sed delimiter must not appear in
   # the replacement).
   url_escaped="$(printf '%s' "$URL" | sed -E 's/[|]/\\|/g')"

   sed \
     -e "s|__VERSION__|$VERSION|g" \
     -e "s|__URL__|$url_escaped|g" \
     -e "s|__SHA256__|$SHA256|g" \
     "$TMPL"
   ```

   Make the script executable:

   ```bash
   chmod +x packaging/homebrew/render-formula.sh
   ```

4. **Append D007 to `.orchestrator/DECISIONS.md`.** Exact insertion
   (append at end of file before any trailing whitespace):

   ```markdown
   ### D007 — Homebrew tarball source: re-use the P05-signed `npm pack` tarball

   - **Decided at**: M035 P03 plan-phase (2026-05-09).
   - **Decision**: The homebrew formula's `url` field points at the
     `build-fractal-orchestrator-<version>.tgz` artifact published on
     the GitHub release by P02's `npm-publish` job + P05's signing
     pass. NO separate brew-tarball is built.
   - **Rationale**:
     1. **CON-5 byte-equivalence is structural, not channel-specific.**
        A separate brew-tarball would introduce an independent build
        path whose hash drift versus the npm tarball would mask the
        very divergence CON-5 exists to catch.
     2. **Single signing chain.** P05's cosign + SHA256SUMS pass already
        covers the npm tarball; re-using it means the formula's
        `sha256` is sourced from the same `SHA256SUMS` file, no
        duplicate signing surface.
     3. **CON-6 secret-scoping carries over.** The
        `homebrew-publish` job consumes the published tarball URL +
        SHA-256 — no fresh build, no fresh secrets, just the
        `secrets.HOMEBREW_TAP_TOKEN` PAT for the cross-repo write.
   - **Bound to**: FR-9 / FR-14 / SC-9 / SC-10 / CON-5.
   ```

5. **Author `tools/verify/m035-p03-formula-template-shape.sh`.**
   Verifier asserts the template's structural properties:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p03-formula-template-shape.sh
   set -u

   pass=0
   fail=0
   TMPL="packaging/homebrew/orchestrator.rb.tmpl"

   if [ ! -f "$TMPL" ]; then
     echo "FAIL: $TMPL missing"
     fail=$((fail + 1))
   else
     pass=$((pass + 1))
     for needle in 'class Orchestrator < Formula' '__VERSION__' \
       '__URL__' '__SHA256__' 'bin.install_symlink' 'license "MIT"' \
       'def install' 'prefix.install'; do
       if grep -qF "$needle" "$TMPL"; then
         pass=$((pass + 1))
       else
         echo "FAIL: $TMPL missing pattern: $needle"
         fail=$((fail + 1))
       fi
     done
   fi

   # Anti-pattern: formula MUST NOT declare hard dependencies.
   for anti in 'depends_on "node"' 'depends_on "python@3"'; do
     if grep -qF "$anti" "$TMPL"; then
       echo "FAIL: $TMPL contains anti-pattern: $anti (FR-9 — no formula-specific install logic)"
       fail=$((fail + 1))
     else
       pass=$((pass + 1))
     fi
   done

   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   Make executable:

   ```bash
   chmod +x tools/verify/m035-p03-formula-template-shape.sh
   ```

6. **Author `tools/verify/m035-p03-render-formula-shape.sh`.** Verifier
   exercises the render script's flag-parsing + token-substitution
   behavior end-to-end against a /tmp probe:

   ```bash
   #!/usr/bin/env bash
   # tools/verify/m035-p03-render-formula-shape.sh
   set -u

   pass=0
   fail=0
   RENDER="packaging/homebrew/render-formula.sh"

   if [ ! -x "$RENDER" ]; then
     echo "FAIL: $RENDER not executable"
     echo "BATTERY: pass=0 fail=1"
     exit 1
   fi

   # 1. Missing-flag rejection.
   if bash "$RENDER" --version 1.0.0 --url https://x.test/a.tgz \
     >/dev/null 2>&1; then
     echo "FAIL: render-formula did not reject missing --sha256"
     fail=$((fail + 1))
   else
     pass=$((pass + 1))
   fi

   # 2. Malformed sha256 rejection (too short).
   if bash "$RENDER" --version 1.0.0 --url https://x.test/a.tgz \
     --sha256 deadbeef >/dev/null 2>&1; then
     echo "FAIL: render-formula did not reject short --sha256"
     fail=$((fail + 1))
   else
     pass=$((pass + 1))
   fi

   # 3. Successful render with valid args. SHA-256 of the empty
   # string (e3b0c44...b855) is a stable 64-hex-char fixture.
   PROBE_OUT="/tmp/m035-p03-render-probe.out"
   bash "$RENDER" \
     --version "1.0.0" \
     --url "https://github.com/Build-Fractal/orchestrator/releases/download/v1.0.0/build-fractal-orchestrator-1.0.0.tgz" \
     --sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" \
     > "$PROBE_OUT" 2>/dev/null
   rc=$?
   if [ "$rc" -ne 0 ]; then
     echo "FAIL: render-formula exit $rc on valid args"
     fail=$((fail + 1))
   else
     pass=$((pass + 1))
   fi

   for needle in '1.0.0' \
     'build-fractal-orchestrator-1.0.0.tgz' \
     'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' \
     'class Orchestrator < Formula'; do
     if grep -qF "$needle" "$PROBE_OUT"; then
       pass=$((pass + 1))
     else
       echo "FAIL: rendered formula missing: $needle"
       fail=$((fail + 1))
     fi
   done

   if grep -qF '__VERSION__' "$PROBE_OUT"; then
     echo "FAIL: rendered formula still contains __VERSION__"
     fail=$((fail + 1))
   else
     pass=$((pass + 1))
   fi

   rm -f "$PROBE_OUT"
   echo "BATTERY: pass=$pass fail=$fail"
   [ "$fail" -eq 0 ]
   ```

   Make executable:

   ```bash
   chmod +x tools/verify/m035-p03-render-formula-shape.sh
   ```

7. **Run both verifiers locally** to confirm green. See `## Verification`.

## Must-Haves

- Truth: `packaging/homebrew/orchestrator.rb.tmpl` exists with
  load-bearing structural properties (verified by
  `m035-p03-formula-template-shape.sh`).
- Truth: `packaging/homebrew/render-formula.sh` correctly substitutes
  tokens and rejects malformed inputs (verified by
  `m035-p03-render-formula-shape.sh`).
- Artifact: `.orchestrator/DECISIONS.md` contains D007.
- Key Link: `render-formula.sh` references `orchestrator.rb.tmpl` via
  the `$SCRIPT_DIR/orchestrator.rb.tmpl` resolution.

## Verification

```bash
bash tools/verify/m035-p03-formula-template-shape.sh
bash tools/verify/m035-p03-render-formula-shape.sh
grep -qE '^### D007' .orchestrator/DECISIONS.md
```

## Notes

Expected output: each verifier emits `BATTERY: pass=N fail=0` on
success. The `grep` returns silently with exit 0 if D007 is appended.

## Inputs

### From Previous Tasks

None — T01 is the first task in P03.

### From Disk (Pre-existing)

- `package.json` — for context only; the formula doesn't read it at
  runtime, but the agent reads it to confirm the package name
  `@build-fractal/orchestrator` matches the formula's homepage URL
  and the URL pattern in render-formula's verifier fixture.
- `.orchestrator/DECISIONS.md` — D007 is appended; existing rows
  (D001–D005) are preserved.

## Constraints

- Bash 3.2 compatible for `render-formula.sh` and both verifiers.
- No `<(...)` process substitution, no `$(...)` containing pipes, no
  plain subshells in command position. Per AD-19.
- Formula must NOT declare `depends_on "node"` or `depends_on
  "python@3"` (FR-9 / `m035-p03-formula-template-shape.sh` anti-pattern
  assertion).
- D007 row format MUST match the `### DXXX — <decision>` shape used by
  D001–D005 in `.orchestrator/DECISIONS.md` (the rebuild-index reads
  this shape).

## Expected Output

- `packaging/homebrew/orchestrator.rb.tmpl` (≥30 lines, contains all
  required patterns).
- `packaging/homebrew/render-formula.sh` (≥50 lines, executable,
  rejects malformed input, substitutes tokens correctly).
- `.orchestrator/DECISIONS.md` extended with the D007 row.
- `tools/verify/m035-p03-formula-template-shape.sh` (≥30 lines, emits
  `BATTERY: pass=N fail=0`).
- `tools/verify/m035-p03-render-formula-shape.sh` (≥30 lines, emits
  `BATTERY: pass=N fail=0`).
