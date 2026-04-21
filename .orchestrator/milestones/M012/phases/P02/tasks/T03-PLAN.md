---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M012"
name: "scripts/diagnostics/wiki-link-check.sh — built-site link walker"
depends_on: ["T02"]
---

## Prerequisites

- T01 + T02 complete:
  - `wiki/mkdocs.yml` has link-rewriting config and the extended nav block.
  - `wiki/docs/` is fully populated (P01 `.orchestrator/` stubs + T02 `knowledge/` stubs + all section indexes).
  - `bash scripts/verify/m012-p01-phase-suite.sh` exits 0.
- A working understanding of where MkDocs writes its built site:
  - Default: `wiki/site/` (produced by `mkdocs build` run from the `wiki/` directory).
  - `wiki-serve.sh --probe` produces a throwaway build in `/tmp/wiki-probe.<pid>/site/` (P01 pattern).
  - Operators may pass `--site <dir>` to point the checker at any built directory.
- `mkdocs` may or may not be installed on the current host. T03's script MUST NOT require mkdocs — it operates on an already-built site directory. Smoke-testing (which requires an actual build) is T05's concern and SKIPs when mkdocs is absent.

## Description

Ship `scripts/diagnostics/wiki-link-check.sh` — a standalone Bash 3.2 utility that walks an already-built MkDocs site directory, extracts every internal `<a href="…">` link from every generated HTML file, classifies each link as in-scope / out-of-scope / broken, and exits non-zero when any in-scope link is broken. This is the tool that P04 will wire as a pre-deploy hook (per the roadmap cross-cutting concern) and that T05's suite calls in smoke mode.

### Classification rules

For each `<a href="VALUE">` occurrence inside every `.html` file under `<site-root>/`:

1. **Strip the `VALUE`**. Discard query strings (`?foo=bar`) and fragments (`#anchor`) for the *resolution* step (but retain the fragment for a second, in-page anchor check once the page resolves).
2. **External URL** — `VALUE` begins with `http://`, `https://`, `mailto:`, `tel:`, or `ftp://`. Classification: **out-of-scope** (external). Emit one `OUT-OF-SCOPE: <source-page> -> <href>` line to stdout. Does not fail the check.
3. **In-page anchor only** — `VALUE` begins with `#`. Classification: **in-scope, anchor-only**. Resolve against the source HTML file: grep for `id="<anchor>"` or `name="<anchor>"`. Missing anchor → **broken**. Present → **ok**.
4. **Relative path** — any other value. Resolve against the source HTML file's directory using pure-string path normalization (no `realpath`; macOS default `realpath` is absent):
   - Join `<source-dir>/<VALUE>` into a raw path.
   - Collapse `./` and `../` segments by simple string manipulation (walk segments into a stack, pop on `..`).
   - If the resolved path is OUTSIDE the site root (i.e., `..` segments escape it), classification: **out-of-scope** (escape). Emit `OUT-OF-SCOPE: <source> -> <href> (escapes site root)`.
   - If the resolved path points INSIDE the site root, check file existence:
     - Directory → append `index.html` (MkDocs default directory-url rendering). Re-check existence.
     - `.html` file missing → **broken**.
     - File present → **ok** (and, if a fragment was present, perform the in-page anchor check against that file; missing anchor → broken).
5. **Classification outcomes**:
   - **ok** — silent (not emitted unless verbose mode requested).
   - **broken** — emitted as `BROKEN: <source-page> -> <href>` to stdout.
   - **out-of-scope** — emitted as `OUT-OF-SCOPE: <source-page> -> <href> [<reason>]` to stdout.

### Exit codes

- **0** — zero broken in-scope links (ok). Out-of-scope links enumerated but do not affect exit.
- **1** — at least one broken in-scope link. Last line of stdout reads `FAIL: N broken in-scope link(s) across M source pages`.
- **2** — usage error (missing `--site` directory, unreadable path, no `.html` files found). Diagnostic to stderr.

### Structured output contract

- One line per non-ok finding.
- Last line of stdout is a summary: `PASS: 0 broken in-scope links (<scanned_pages> pages, <ok_links> in-scope ok, <ext_count> out-of-scope)` or `FAIL: …`.
- All diagnostics to stderr; stdout is pure structured output for downstream grep/pipe.

## Steps

1. **Create `scripts/diagnostics/wiki-link-check.sh`** with the following header and structure:

   ```bash
   #!/usr/bin/env bash
   # scripts/diagnostics/wiki-link-check.sh — M012/P02 built-site link walker.
   #
   # Walks an already-built MkDocs site directory, extracts every <a href="…">
   # link from every .html file, classifies each link as in-scope / out-of-scope /
   # broken, and exits non-zero on any broken in-scope link.
   #
   # Usage:
   #   bash scripts/diagnostics/wiki-link-check.sh [--site <dir>] [--root <dir>]
   #                                               [--strict] [--help]
   #
   #   --site <dir>  Built site directory. Default: "wiki/site" relative to --root.
   #   --root <dir>  Project root. Default: invocation working directory.
   #   --strict      Treat out-of-scope escape as broken (stricter than default).
   #   --help        Print this usage block and exit 0.
   #
   # Exit codes:
   #   0  — zero broken in-scope links.
   #   1  — one or more broken in-scope links.
   #   2  — usage error (no site dir, no .html files, unreadable path).
   #
   # In-scope: any relative link that resolves to an existing file inside the
   #           site tree, plus in-page anchor-only links (#foo) whose anchor
   #           exists in the source page.
   # Out-of-scope: http(s), mailto, tel, ftp; paths that escape the site root.
   # Broken: relative link whose resolved path is missing, or anchor link whose
   #         target id/name is absent from the target page.
   #
   # Bash 3.2 compatible. MEM004 carve-out: internal pipes/awk/sed permitted.
   # Single-script-file shape (AD-19) — callable directly as the Check command.

   set -u
   ```

2. **Argument parsing** — dual-style per MEM001 (long flags only for this script; positional not needed):

   ```bash
   SITE_DIR=""
   ROOT_DIR=""
   STRICT=0

   print_help() {
     sed -n '2,30p' "$0"
   }

   while [ $# -gt 0 ]; do
     case "$1" in
       --site) shift; SITE_DIR="${1:-}" ;;
       --root) shift; ROOT_DIR="${1:-}" ;;
       --strict) STRICT=1 ;;
       --help|-h) print_help; exit 0 ;;
       *) printf 'ERROR: unknown flag: %s\n' "$1" >&2; exit 2 ;;
     esac
     [ $# -eq 0 ] || shift
   done

   [ -n "$ROOT_DIR" ] || ROOT_DIR="$(pwd)"
   [ -n "$SITE_DIR" ] || SITE_DIR="$ROOT_DIR/wiki/site"

   if [ ! -d "$SITE_DIR" ]; then
     printf 'ERROR: site directory not found: %s\n' "$SITE_DIR" >&2
     printf '       Build the site first: (cd wiki && mkdocs build)\n' >&2
     exit 2
   fi
   ```

   NOTE: the usage block is rendered by `sed -n '2,30p' "$0"` — the header lines 2–30 of the script itself. Keep the header at the exact line range above for `--help` to work. (The line range is flexible; tune to match the actual header length.)

3. **Enumerate HTML files**:

   ```bash
   HTML_LIST="/tmp/wiki-link-check.html.$$"
   trap 'rm -f "$HTML_LIST" "$HTML_LIST.links" "$HTML_LIST.findings" 2>/dev/null' EXIT
   find "$SITE_DIR" -type f -name '*.html' | LC_ALL=C sort > "$HTML_LIST"

   PAGE_COUNT=0
   while IFS= read -r _pg; do
     [ -n "$_pg" ] || continue
     PAGE_COUNT=$((PAGE_COUNT + 1))
   done < "$HTML_LIST"

   if [ "$PAGE_COUNT" -eq 0 ]; then
     printf 'ERROR: no .html files found under %s\n' "$SITE_DIR" >&2
     exit 2
   fi
   ```

4. **Extract links per page**. Use `grep -oE` with a conservative href regex. HTML attribute quoting is not fully regex-safe, but MkDocs emits consistent `href="…"` form:

   ```bash
   # Emit "<page-path>|<href>" per link.
   : > "$HTML_LIST.links"
   while IFS= read -r page; do
     [ -n "$page" ] || continue
     # grep -oE returns one match per line.
     # Regex: href="([^"]+)" — captures the value between quotes.
     grep -oE 'href="[^"#?][^"]*"' "$page" 2>/dev/null \
       | sed -e 's/^href="//' -e 's/"$//' \
       | while IFS= read -r href; do
           [ -n "$href" ] || continue
           printf '%s|%s\n' "$page" "$href" >> "$HTML_LIST.links"
         done
     # Also capture anchor-only (#foo) and empty-start-with-# hrefs separately
     # because the above regex excludes leading # and ? (query-only).
     grep -oE 'href="#[^"]+"' "$page" 2>/dev/null \
       | sed -e 's/^href="//' -e 's/"$//' \
       | while IFS= read -r href; do
           printf '%s|%s\n' "$page" "$href" >> "$HTML_LIST.links"
         done
   done < "$HTML_LIST"
   ```

   Bash 3.2 caveat: the `while | while` piped subshell won't lose data because we're writing to a file, not updating a counter variable. Counters are recomputed from the file below.

5. **Classify each link**. Iterate `$HTML_LIST.links`:

   ```bash
   : > "$HTML_LIST.findings"
   BROKEN=0
   OUT_OF_SCOPE=0
   OK_LINKS=0

   while IFS='|' read -r page href; do
     [ -n "$page" ] || continue
     [ -n "$href" ] || continue

     # External URL?
     case "$href" in
       http://*|https://*|mailto:*|tel:*|ftp://*)
         printf 'OUT-OF-SCOPE: %s -> %s [external]\n' "$page" "$href" \
           >> "$HTML_LIST.findings"
         OUT_OF_SCOPE=$((OUT_OF_SCOPE + 1))
         continue
         ;;
     esac

     # In-page anchor only?
     case "$href" in
       '#'*)
         anchor="${href#\#}"
         if grep -qE "(id=\"${anchor}\"|name=\"${anchor}\")" "$page"; then
           OK_LINKS=$((OK_LINKS + 1))
         else
           printf 'BROKEN: %s -> %s [in-page anchor missing]\n' "$page" "$href" \
             >> "$HTML_LIST.findings"
           BROKEN=$((BROKEN + 1))
         fi
         continue
         ;;
     esac

     # Relative path (strip fragment for resolution; keep for anchor check).
     path_only="${href%%\#*}"
     frag=""
     case "$href" in
       *'#'*) frag="${href#*\#}" ;;
     esac
     # Strip query string.
     path_only="${path_only%%\?*}"

     # Resolve against the source page's directory.
     src_dir=$(dirname "$page")
     raw="$src_dir/$path_only"

     # Pure-string path normalization (no realpath).
     resolved=$(normalize_path "$raw")

     # Escape check — must stay under SITE_DIR.
     site_prefix="${SITE_DIR%/}/"
     case "$resolved" in
       "$SITE_DIR"|"$site_prefix"*) ;;  # inside site — ok to continue
       *)
         reason="escapes site root"
         if [ "$STRICT" -eq 1 ]; then
           printf 'BROKEN: %s -> %s [%s]\n' "$page" "$href" "$reason" \
             >> "$HTML_LIST.findings"
           BROKEN=$((BROKEN + 1))
         else
           printf 'OUT-OF-SCOPE: %s -> %s [%s]\n' "$page" "$href" "$reason" \
             >> "$HTML_LIST.findings"
           OUT_OF_SCOPE=$((OUT_OF_SCOPE + 1))
         fi
         continue
         ;;
     esac

     # Directory → index.html.
     if [ -d "$resolved" ]; then
       resolved="${resolved%/}/index.html"
     fi

     if [ ! -f "$resolved" ]; then
       printf 'BROKEN: %s -> %s [file missing: %s]\n' "$page" "$href" "$resolved" \
         >> "$HTML_LIST.findings"
       BROKEN=$((BROKEN + 1))
       continue
     fi

     # If we have a fragment, verify anchor exists in the target page.
     if [ -n "$frag" ]; then
       if ! grep -qE "(id=\"${frag}\"|name=\"${frag}\")" "$resolved"; then
         printf 'BROKEN: %s -> %s [target anchor missing: #%s]\n' \
           "$page" "$href" "$frag" >> "$HTML_LIST.findings"
         BROKEN=$((BROKEN + 1))
         continue
       fi
     fi

     OK_LINKS=$((OK_LINKS + 1))
   done < "$HTML_LIST.links"
   ```

6. **Implement `normalize_path`** — pure string path normalization, Bash 3.2 safe:

   ```bash
   normalize_path() {
     # Collapse "./" and "../" against a raw path string. No realpath.
     # Split on "/", walk into a positional-parameter stack.
     local raw="$1"
     local IFS=/
     set -- $raw
     local out=""
     local seg
     for seg in "$@"; do
       case "$seg" in
         ''|'.') continue ;;
         '..')
           # Pop one segment from out.
           out="${out%/*}"
           ;;
         *)
           if [ -z "$out" ]; then
             out="$seg"
           else
             out="$out/$seg"
           fi
           ;;
       esac
     done
     # Preserve leading slash if raw started with /.
     case "$raw" in
       /*) printf '/%s\n' "$out" ;;
       *)  printf '%s\n' "$out" ;;
     esac
   }
   ```

   Bash 3.2 compatible — uses `local`, positional parameters, and string parameter expansion. No `mapfile`, no `declare -A`, no `<(…)`.

7. **Emit findings and summary**:

   ```bash
   # Print findings (sorted for determinism).
   if [ -s "$HTML_LIST.findings" ]; then
     LC_ALL=C sort -u "$HTML_LIST.findings"
   fi

   if [ "$BROKEN" -gt 0 ]; then
     printf 'FAIL: %d broken in-scope link(s) across %d source pages (%d ok, %d out-of-scope)\n' \
       "$BROKEN" "$PAGE_COUNT" "$OK_LINKS" "$OUT_OF_SCOPE"
     exit 1
   fi

   printf 'PASS: 0 broken in-scope links (%d pages, %d in-scope ok, %d out-of-scope)\n' \
     "$PAGE_COUNT" "$OK_LINKS" "$OUT_OF_SCOPE"
   exit 0
   ```

8. **Make the script executable**:

   ```bash
   chmod 755 scripts/diagnostics/wiki-link-check.sh
   ```

9. **Smoke test locally if `mkdocs` is available**:

   ```bash
   bash scripts/wiki/wiki-serve.sh --probe
   ```

   This produces a throwaway site under `/tmp/wiki-probe.<pid>/site/`. Record that path and run:

   ```bash
   bash scripts/diagnostics/wiki-link-check.sh --site /tmp/wiki-probe.<pid>/site
   ```

   Expect `PASS: 0 broken in-scope links (…)` on stdout, exit 0. If broken links are reported, the most likely causes are:
   - Missing include-plugin `rewrite_relative_urls: true` (T01 setting).
   - Scanner missed a canonical file (T01 extension incomplete).
   - Stub generator's `canonical_rel` path calculation is wrong (T02 `../` count).
   - A legitimate broken link in canonical content (an actual bug to report).

   Address the first three before blaming the fourth; log genuine content issues to the phase notes but do NOT fix canonical content in T03 — that is either a separate task or a defect report.

10. **If `mkdocs` is not installed**, skip the smoke; T05's `m012-p02-link-check-smoke.sh` gate handles the SKIP-as-PASS semantics. T03's deliverable is the script itself plus its offline contract (executable, `--help` prints usage, missing `--site` exits 2, etc.), all of which are verifiable without mkdocs.

## Must-Haves

- `scripts/diagnostics/wiki-link-check.sh` exists, is executable, Bash 3.2 compatible.
- `bash scripts/diagnostics/wiki-link-check.sh --help` prints usage block and exits 0.
- Invoked with no args: defaults `--site` to `wiki/site/` relative to invocation cwd; if that directory does not exist, exits 2 with a diagnostic.
- Invoked with `--site <missing-dir>`: exits 2.
- Invoked with `--site <dir-containing-zero-html-files>`: exits 2.
- Invoked against a valid built-site directory: walks `.html` files, classifies links, emits `BROKEN:` / `OUT-OF-SCOPE:` lines, ends with `PASS:` or `FAIL:` summary line, exits 0/1 accordingly.
- Output is deterministic — running the script twice against the same site directory produces byte-identical stdout (modulo sort stability).
- No side effects — script does not modify any file outside `/tmp/`.

## Verification

- `bash scripts/diagnostics/wiki-link-check.sh --help` — exits 0; stdout contains "--site", "--root", "--strict", "In-scope", "Out-of-scope", "Broken" (used by T05's `m012-p02-link-check-help.sh` gate).
- `bash scripts/diagnostics/wiki-link-check.sh --site /does/not/exist` — exits 2; stderr mentions "site directory not found".
- `bash scripts/diagnostics/wiki-link-check.sh` (no flags, from repo root, with no `wiki/site/` built) — exits 2.
- `bash scripts/verify/m012-p01-phase-suite.sh` — still exits 0 (T03 adds one new script; does not modify P01 surfaces).
- Manual smoke (if mkdocs installed): build via `wiki-serve.sh --probe`, run link-check against `/tmp/wiki-probe.<pid>/site`, expect PASS with 0 broken.

## Inputs

### From Previous Tasks

- `wiki/mkdocs.yml` (T01)
  - Key API: `rewrite_relative_urls: true` on include-markdown — load-bearing for links inside included bodies to resolve correctly in the built site.
- `wiki/docs/**` (T02 + P01)
  - Full stub surface for both `.orchestrator/**.md` and `knowledge/**/MEM*.md`. T03's script consumes the BUILT output (HTML under `wiki/site/`), not the stubs directly, so its contract is defined against `site/` rather than `docs/`.

### From Disk (Pre-existing)

- `wiki/site/` — built by `mkdocs build` when mkdocs is installed. NOT checked into the repo (excluded by `wiki/.gitignore` from P01). The link-checker operates on this directory.
- `.orchestrator/memory/constitution.md` — Principle VIII (Bash 3.2) applies.
- `scripts/wiki/wiki-serve.sh` (P01) — operators use `--probe` to produce a throwaway build for local smoke-testing T03's script.

## Constraints

- **Bash 3.2** — the script must work on stock macOS bash. MEM001.
- **MEM004 carve-out applies** — this is a diagnostic script, not agent-facing content. Pipes, subshells, `grep -oE`, `awk`, `sed`, `find | sort`, PID-suffixed /tmp files are permitted inside the script. The AD-19 shape constraint applies to Truth `Check:` commands (which invoke `scripts/verify/m012-p02-*.sh` one level up); it does NOT constrain internal implementation.
- **No `realpath` dependency** — macOS `realpath` is not in POSIX; this script may run without coreutils. Implement path normalization via pure string manipulation (step 6).
- **No external dependencies** — no `jq`, no `python3`, no Node. Pure shell utilities (`grep`, `sed`, `find`, `sort`) are the budget.
- **Read-only against repo state** — the script only writes to `/tmp/` (temp files cleaned on exit via `trap`).
- **Deterministic output** — findings are `sort -u`-d before emission so repeated runs are byte-identical. Counters are recomputed from the findings file, not maintained across a piped subshell (MEM001 Bash 3.2 counter-loss caveat).
- **Surgical precision (Constitution XV)** — T03 creates exactly one file (`scripts/diagnostics/wiki-link-check.sh`) plus its executable bit. No other files touched.

## Expected Output

After T03 completes:

1. `scripts/diagnostics/wiki-link-check.sh` exists, is executable (`ls -l` shows `-rwxr-xr-x`), is ≥ 180 lines including header and helpers.
2. `--help` output enumerates `--site`, `--root`, `--strict` flags plus classification rules.
3. Against a missing site dir, exits 2 with a clear diagnostic.
4. Against a built site, exits 0 with `PASS: 0 broken in-scope links (…)` (when all in-scope links resolve).
5. Emits one `BROKEN:`/`OUT-OF-SCOPE:` line per problematic link; summary line last.
6. P01 suite still green.
7. T04 can reference this script by name in `wiki/README.md`; T05 can assert its contract via gates.
