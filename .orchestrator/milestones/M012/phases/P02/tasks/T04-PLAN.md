---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M012"
name: "wiki/README.md link-resolution policy + mkdocs build --strict alignment"
depends_on: ["T03"]
---

## Prerequisites

- T01–T03 complete:
  - `wiki/mkdocs.yml` has link-rewriting config (T01).
  - `wiki/docs/knowledge/` stub tree + `Knowledge Entries:` nav subtree exist (T02).
  - `scripts/diagnostics/wiki-link-check.sh` exists, executable, contract verified (T03).
  - `bash scripts/verify/m012-p01-phase-suite.sh` exits 0.
- `wiki/README.md` already exists from P01 and contains an operator preamble (install / preview / generator pipeline). T04 extends it; it does NOT overwrite the P01 content.

## Description

T04 ships the operator-facing documentation that closes the P02 Boundary Map's `wiki/README.md` deliverable: a "Link resolution" section enumerating what the wiki treats as in-scope vs out-of-scope, how out-of-scope targets are handled, how to run the checker locally, and how P04 will wire the checker as a pre-deploy hook. This section is what a new operator reads to understand the `BROKEN:` / `OUT-OF-SCOPE:` output of T03's script.

T04 also aligns with `mkdocs build --strict` behavior: when run with `--strict`, mkdocs fails the build on any reference to a non-existent markdown target, and on any orphaned page (page not listed in nav). Both are real risks given T02's nav extension. T04 documents the alignment and confirms that the current P02 output survives `mkdocs build --strict` when mkdocs is available (if not available, the check is deferred to T05's smoke gate).

### Scope of `wiki/README.md` changes

T04 appends three new sections to `wiki/README.md`:

1. **`## Link resolution`** — the resolution policy (in-scope, out-of-scope, handling).
2. **`## Running the link checker`** — invocation and interpreting output.
3. **`## Pre-deploy integration (P04)`** — how the checker will be wired into deploy, included here so the P02 → P04 contract is documented at the source of truth rather than scattered across milestone summaries.

The preamble section from P01 (install, preview, generator pipeline) is preserved unchanged.

## Steps

1. **Open `wiki/README.md`** and locate its end-of-file. Append a blank line, then the three new sections.

2. **Write the `## Link resolution` section** (literal content — the phrase "Link resolution" is the load-bearing anchor the T05 gate asserts):

   ```markdown

   ## Link resolution

   The dogfood wiki renders orchestrator artifacts from their canonical locations
   under `.orchestrator/` (and the granular knowledge entries from `knowledge/`).
   Internal markdown links inside those canonical files are rewritten at build
   time so clicks on the rendered site land on the rendered target page — not on
   the raw markdown and not on a broken path.

   ### In-scope link targets

   A link is **in-scope** if its resolved destination is one of:

   - Another `.orchestrator/**.md` artifact rendered as a stub under
     `wiki/docs/**` (the full scanner enumeration — see
     `scripts/wiki/wiki-scan-sources.sh`).
   - A `knowledge/**/MEM*.md` entry rendered as a stub under
     `wiki/docs/knowledge/<category>/MEM###.md` (added in M012/P02/T02).
   - An in-page anchor (`#section-id`) on the same rendered page.
   - The consolidated `.orchestrator/KNOWLEDGE.md` page, including anchors of
     the form `#mem-NNNN` — these resolve when the consolidated file happens
     to carry a matching heading. Authors are encouraged to link to the
     granular entry (`knowledge/<cat>/MEM###.md`) by file path rather than to
     the consolidated-file anchor — the granular entry is the canonical cross-
     reference target per AD-1 (D011 criterion (a)).

   The include-markdown plugin's `rewrite_relative_urls: true` option (set in
   `wiki/mkdocs.yml`) handles the rewriting. Relative links inside an included
   body (e.g., a reference to `milestones/M011/M011-SUMMARY.md` inside the
   included `.orchestrator/DECISIONS.md` text) resolve against the stub's
   rendered URL rather than against the canonical source path.

   ### Out-of-scope link targets

   A link is **out-of-scope** if it is:

   - An absolute URL: `http://`, `https://`, `mailto:`, `tel:`, or `ftp:`.
   - A repo-root-relative path that escapes the site tree: `scripts/**`,
     `tests/**`, `commands/**`, `templates/**`, `references/**`, `docs/**`,
     `packaging/**`, or any other path outside `.orchestrator/` and
     `knowledge/`.

   Out-of-scope links are enumerated by the link-checker but do not fail the
   build. They are not rewritten; they render as literal paths. Authors who
   want an external link to resolve on the rendered site should point it at
   the GitHub source URL rather than at a repo-relative path.

   A future enhancement (out of scope for M012) could auto-rewrite repo-root-
   relative out-of-scope paths to `https://github.com/<org>/<repo>/blob/main/<path>`.
   Until that ships, authors are responsible for writing absolute URLs when an
   external link is desired.

   ### Broken link handling

   If an in-scope link does not resolve — the target stub is missing, a
   renamed artifact was not picked up by the generators, an anchor was typed
   incorrectly — the link-checker emits a `BROKEN:` line and exits non-zero.
   See "Running the link checker" below.
   ```

3. **Write the `## Running the link checker` section**:

   ```markdown

   ## Running the link checker

   The link checker is `scripts/diagnostics/wiki-link-check.sh`. It walks an
   already-built MkDocs site directory; it does not invoke mkdocs itself.

   ### Typical local workflow

   From the repo root:

   ```bash
   # 1. Build the site (requires mkdocs + mkdocs-material + include-plugin):
   (cd wiki && mkdocs build)

   # 2. Run the link checker:
   bash scripts/diagnostics/wiki-link-check.sh --site wiki/site
   ```

   Expected output on success:

   ```
   PASS: 0 broken in-scope links (<N> pages, <M> in-scope ok, <K> out-of-scope)
   ```

   Expected output on failure:

   ```
   BROKEN: wiki/site/decisions/index.html -> ../missing-target.html [file missing: …]
   FAIL: 1 broken in-scope link(s) across <N> source pages (<M> ok, <K> out-of-scope)
   ```

   Exit codes:

   - `0` — zero broken in-scope links.
   - `1` — one or more broken in-scope links.
   - `2` — usage error (missing site directory, no HTML files found).

   ### Flags

   - `--site <dir>` — point at an alternative built-site directory (useful
     when using `wiki-serve.sh --probe`, which builds under `/tmp/`).
   - `--root <dir>` — override project root (default: invocation cwd).
   - `--strict` — treat path-escape out-of-scope findings as broken (stricter
     mode for CI; default remains enumerate-only).
   - `--help` — print usage and exit.

   ### Interpreting out-of-scope output

   Every `OUT-OF-SCOPE:` line is informational. A high volume of out-of-scope
   lines is expected — the canonical artifacts routinely reference
   `scripts/**`, `templates/**`, etc. If the count grows unexpectedly, scan
   for new canonical references that ought to be rewritten; most often, the
   fix is to cite a file by its `.orchestrator/` or `knowledge/` path rather
   than by a repo-root-relative path to source code.
   ```

4. **Write the `## Pre-deploy integration (P04)` section**:

   ```markdown

   ## Pre-deploy integration (P04)

   M012/P04 (deploy pipeline) wires two pre-build hooks before `mkdocs
   gh-deploy`:

   1. `scripts/diagnostics/wiki-link-check.sh` — this checker, run against the
      freshly built site. Non-zero exit aborts the deploy.
   2. `scripts/diagnostics/wiki-giscus-smoke.sh` — the Giscus smoke test (P03
      deliverable). Non-zero exit aborts the deploy.

   The hooks are intentionally kept as separate scripts — not a monolithic
   pre-deploy script — so operators can invoke each one independently during
   development. The deploy wrapper P04 ships chains them; the individual
   scripts remain directly callable.

   ### `mkdocs build --strict` alignment

   Running `mkdocs build --strict -f wiki/mkdocs.yml` fails the build on:

   - Pages that are not referenced from the nav.
   - Internal markdown links whose target files are missing.

   Both checks overlap partially with `wiki-link-check.sh`. The distinction:

   - `mkdocs build --strict` operates on markdown source and on nav structure
     — it catches structural misalignments (nav entries pointing at nothing,
     orphaned pages).
   - `wiki-link-check.sh` operates on the generated HTML — it catches
     rendered-output issues (rewritten link targets, anchor resolution, query
     string handling) that the markdown-source check cannot see.

   Both are run in P04. Neither subsumes the other. If the local environment
   has mkdocs installed, running both before every deploy is the documented
   workflow.
   ```

5. **Save `wiki/README.md`**. The file should now be at least 80 lines total (P01 base + three new sections). If it came in shorter, expand the preamble sections rather than padding the new sections (they are already minimal).

6. **Confirm P01 suite still passes**:

   ```bash
   bash scripts/verify/m012-p01-phase-suite.sh
   ```

   Expected: 9/9 gates PASS. T04 only modifies `wiki/README.md`, which P01 gates do not assert on beyond its existence + min-lines floor (which only goes UP).

7. **If mkdocs is installed locally**, run the strict build smoke:

   ```bash
   bash scripts/wiki/wiki-serve.sh --probe
   ```

   The P01 `--probe` mode runs `mkdocs build --strict` into a throwaway dir. If mkdocs is absent, the wiki-serve.sh launcher already emits a SKIP — that is acceptable; T05's smoke gate handles the SKIP-as-PASS semantics for auto mode.

   If mkdocs is available and the probe FAILS with a strict error, interpret:

   - "Doc file contains a link … referenced target missing" → cross-link rewrite miss. Audit T01 settings and T02 stub-generator `canonical_rel` paths.
   - "The following pages exist in the docs directory, but are not included in the 'nav'" → orphaned stubs (T02 did not add them to nav). Fix the nav generator.
   - Unexpected YAML error → `wiki/mkdocs.yml` nav block malformed. Inspect the marker-bounded region.

   The probe does NOT run T03's link-checker — that is a separate diagnostic, covered by T05's link-check smoke gate.

## Must-Haves

- `wiki/README.md` contains the exact heading `## Link resolution` (this is T05's anchor for the policy-docs gate).
- `wiki/README.md` contains the subsection heading `## Running the link checker`.
- `wiki/README.md` contains the subsection heading `## Pre-deploy integration (P04)`.
- `wiki/README.md` mentions `scripts/diagnostics/wiki-link-check.sh` at least once.
- `wiki/README.md` mentions `mkdocs build --strict` at least once.
- `wiki/README.md` enumerates at least one in-scope target type and at least one out-of-scope target type.
- File line count ≥ 80.
- `bash scripts/verify/m012-p01-phase-suite.sh` still exits 0.

## Verification

- `grep -c '^## Link resolution$' wiki/README.md` — must be exactly 1.
- `grep -c '^## Running the link checker$' wiki/README.md` — must be exactly 1.
- `grep -c '^## Pre-deploy integration (P04)$' wiki/README.md` — must be exactly 1.
- `grep -q 'wiki-link-check.sh' wiki/README.md` — must exit 0.
- `grep -q 'mkdocs build --strict' wiki/README.md` — must exit 0.
- `wc -l wiki/README.md` — line count ≥ 80.
- `bash scripts/verify/m012-p01-phase-suite.sh` — exits 0.
- Manual: read the policy section top-to-bottom; it should be comprehensible to a new operator without cross-referencing other docs.

## Inputs

### From Previous Tasks

- `scripts/diagnostics/wiki-link-check.sh` (T03)
  - Key API: `bash scripts/diagnostics/wiki-link-check.sh [--site DIR] [--root DIR] [--strict] [--help]`. Exit 0 on zero broken, 1 on broken, 2 on usage error.
  - Output shape: `BROKEN: <source> -> <href> [<reason>]` and `OUT-OF-SCOPE: <source> -> <href> [<reason>]`; last stdout line is `PASS:` or `FAIL:` summary.
  - `--help` prints a usage block enumerating all flags and the in-scope/out-of-scope rules.
- `wiki/mkdocs.yml` (T01) — contains `rewrite_relative_urls: true`; the README cites this as the load-bearing link-rewrite setting.
- `wiki/docs/knowledge/` stub tree (T02) — the README cites its path shape when explaining granular MEM cross-references.

### From Disk (Pre-existing)

- `wiki/README.md` (P01) — operator preamble: installation, preview via `bash scripts/wiki/wiki-serve.sh`, generator pipeline (scan → stubs → nav). P01 min-lines floor was 30 (contains "mkdocs serve"). T04 extends it to ≥ 80 lines; the P01 floor is unaffected because it only checks a minimum.
- `.orchestrator/milestones/M012/M012-CONTEXT.md` — AD-1 (D011 criteria selection) and AD-3 (SSOT via include plugin) cited by reference in the README's rationale.
- `.orchestrator/DECISIONS.md` D011 — referenced via M020-promotion context in T05's D011-EVALUATION.md artifact (not directly in README).

## Constraints

- **Markdown-only changes** — T04 edits exactly `wiki/README.md`. No other files.
- **Additive to P01 content** — the P01-authored preamble stays. T04 appends sections; it does not rewrite the existing narrative.
- **Exact heading strings** — T05's policy-docs gate asserts literal heading lines (`## Link resolution`, `## Running the link checker`, `## Pre-deploy integration (P04)`). Any variation (missing `##`, different capitalization) fails the gate.
- **Honest scope notes** — the "future enhancement" call-out re: auto-rewrite of repo-root-relative paths to GitHub URLs is explicitly out of M012 scope; do not let the documentation imply it ships here (Constitution XIV, Constitution XV).
- **No canonical content duplicated** — the README explains the policy; it does NOT paste decision text, MEM content, or constitution language. Cite by path (`AD-1`, `D011`, etc.); do not reproduce bodies. AD-3 SSOT.
- **Surgical precision (Constitution XV)** — one file touched.

## Expected Output

After T04 completes:

1. `wiki/README.md` is at least 80 lines.
2. Three new top-level headings appear: `## Link resolution`, `## Running the link checker`, `## Pre-deploy integration (P04)`.
3. The policy section enumerates in-scope rules, out-of-scope rules, and broken-link handling.
4. The invocation section documents `--site`, `--root`, `--strict`, `--help` flags and exit codes.
5. The pre-deploy section names both the link-checker and (anticipating P03) the Giscus smoke script, and contrasts `wiki-link-check.sh` with `mkdocs build --strict`.
6. `bash scripts/verify/m012-p01-phase-suite.sh` exits 0.
7. T05 can now assert on the README content via a dedicated gate.
