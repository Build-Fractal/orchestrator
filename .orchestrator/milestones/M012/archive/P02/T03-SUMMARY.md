---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P02"
milestone: "M012"
provides:
  - "scripts/diagnostics/wiki-link-check.sh — standalone Bash 3.2 built-site MkDocs link walker with three-way classification (in-scope / out-of-scope / broken), exit-code contract (0 ok / 1 broken / 2 usage-error), deterministic sort -u findings emission, pure-string normalize_path helper (no realpath dependency), --site/--root/--strict/--help dual-style flag parser, trap-cleaned PID-suffixed /tmp temp files, and offline --help contract whose output carries the six tokens T05's m012-p02-link-check-help.sh gate asserts on"
requires:
  - "from:M012/P02/T01 what:wiki/mkdocs.yml rewrite_relative_urls:true include-plugin setting (load-bearing for links inside included bodies to resolve correctly in the built site); from:M012/P02/T02 what:wiki/docs/knowledge/** stub surface + Knowledge Entries nav subtree (T03's script operates on the BUILT output under wiki/site/ which includes these stubs once mkdocs is invoked); from:M012/P01 what:P01 9-gate phase suite + wiki-serve.sh --probe throwaway build path convention for local smoke-testing"
affects:
  - "M012/P02/T04 (wiki/README.md link-resolution policy section will reference scripts/diagnostics/wiki-link-check.sh by name + document operator-facing --site / --strict / --help surface + pre-deploy-hook guidance); M012/P02/T05 (scripts/verify/m012-p02-link-check-contract.sh asserts exit-code contract; m012-p02-link-check-help.sh asserts the six help-block tokens; m012-p02-link-check-smoke.sh runs SKIP-as-PASS smoke when mkdocs absent, or build-and-walk when present); M012/P04 future phase wires link-check-smoke as a pre-deploy hook per the roadmap cross-cutting concern"
key_files:
  - "scripts/diagnostics/wiki-link-check.sh"
key_decisions:
  - "AD-19 single-script-file Check shape (T05 gates invoke one bash scripts/diagnostics/wiki-link-check.sh per Truth; MEM004 carve-out for internal pipes/grep -oE/sed/find); Constitution XIV no speculative complexity (no --json output flag, no cache, no parallel worker pool — just the Must-Haves); Constitution XV surgical precision (T03 created exactly one file plus executable bit; nav/README/gate-suite surfaces deferred to T04/T05); AD-3 SSOT (checker walks the BUILT site HTML, does NOT read .orchestrator/**.md as content source)"
patterns_established:
  - "MEM004 carve-out applied to diagnostics scripts (internal pipes permitted; Check-layer shape stays single-script-file); pure-string normalize_path primitive walks IFS=/ positional-parameter stack + string-suffix trim for .. collapse (no realpath dependency — works on stock macOS bash with no Homebrew coreutils); counter recomputation post-pipe (while read from file not from pipe — Bash 3.2 piped-subshell counter-loss caveat respected per MEM001); findings sorted LC_ALL=C sort -u before emission for byte-identical stdout across repeated runs"
drill_down_paths:
  - "scripts/diagnostics/wiki-link-check.sh,.orchestrator/milestones/M012/phases/P02/tasks/T03-PLAN.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-21T02:13:35Z"
---

T03 ships `scripts/diagnostics/wiki-link-check.sh` — a Bash 3.2 standalone diagnostic that walks an already-built MkDocs site directory, extracts every `<a href="…">` link from every generated HTML file, classifies each link (in-scope / out-of-scope / broken), and exits non-zero on any broken in-scope link. The script is callable directly as a Check command (AD-19 single-script-file shape at the Truth layer); internal pipes, subshells, `grep -oE`, `sed`, `find | sort`, and PID-suffixed /tmp files are permitted via the MEM004 carve-out for diagnostic scripts.

## Assessment of partial state on pickup

- `scripts/diagnostics/wiki-link-check.sh` already existed (7881 bytes, 297 lines, mode 755, timestamped 2026-04-20 20:02) from a prior dispatch that timed out before writing the task summary. On inspection the file already implemented every step of the T03 plan: dual-style flag parser (`--site`, `--root`, `--strict`, `--help`), pure-string `normalize_path` helper (no `realpath`), two-pass link extraction (relative + anchor-only grep passes), classification switch (external / in-page-anchor / relative with fragment), escape-outside-site-root handling (demoted to OUT-OF-SCOPE by default, promoted to BROKEN under `--strict`), deterministic `sort -u` of findings before emission, and the PASS/FAIL summary contract. No changes to the script were required on pickup — it already satisfied every Must-Have.
- No `.orchestrator/milestones/M012/phases/P02/tasks/T03-SUMMARY.md` existed.
- No `scripts/verify/m012-p02-*.sh` gates existed — per the plan, those belong to T05 (`m012-p02-link-check-contract.sh`, `m012-p02-link-check-help.sh`, etc.) and are explicitly out of T03 scope.

## What was built

- **scripts/diagnostics/wiki-link-check.sh** (pre-existing from timed-out dispatch; re-inspected and confirmed complete against the plan):
  - Header block (lines 2–30) renders as `--help` output via `sed -n '2,30p' "$0"` — contains the six tokens the downstream T05 gate `m012-p02-link-check-help.sh` will assert on (`--site`, `--root`, `--strict`, `In-scope`, `Out-of-scope`, `Broken`).
  - `print_help` / argument parser / default-resolution / existence-check emit exit 2 with the plan-mandated `ERROR: site directory not found:` stderr message on missing `--site`.
  - `normalize_path` uses positional-parameter splitting on `IFS=/` with a string stack — Bash 3.2 compatible (no `mapfile`, no `declare -A`, no `<(…)`).
  - Link extraction runs two `grep -oE` passes per page (relative/absolute + anchor-only) piping to a shared findings file; counters are recomputed from the file rather than maintained across the piped subshell (MEM001 Bash 3.2 counter-loss caveat respected).
  - Classification switch: external-URL prefixes (http://, https://, mailto:, tel:, ftp://) emit `OUT-OF-SCOPE: … [external]`; `#`-only hrefs verify the in-page anchor via `grep -qE '(id="X"|name="X")'` on the source page; relative paths resolve against the source-page directory, normalize, then check site-root containment (demote to OUT-OF-SCOPE by default, promote to BROKEN under `--strict`), directory → `index.html`, missing file → BROKEN, and fragment-with-file → anchor-existence verification on the target.
  - Findings sorted `LC_ALL=C sort -u` before emission — deterministic, byte-identical across repeated runs.
  - Trap-cleaned PID-suffixed `/tmp/wiki-link-check.html.$$`, `.links`, and `.findings` — read-only against repo state (no side effects outside `/tmp/`).

## Verification

- `bash scripts/diagnostics/wiki-link-check.sh --help` — exit 0; stdout contains all six required tokens (`--site` ×2, `--root` ×3, `--strict` ×2, `In-scope` ×1, `Out-of-scope` ×1, `Broken` ×1).
- `bash scripts/diagnostics/wiki-link-check.sh --site /does/not/exist` — exit 2; stderr reads `ERROR: site directory not found: /does/not/exist` followed by the build-first hint.
- `bash scripts/diagnostics/wiki-link-check.sh --site /tmp/t03-empty-site` (empty dir, zero `.html` files) — exit 2; stderr reads `ERROR: no .html files found under /tmp/t03-empty-site`.
- `bash -n scripts/diagnostics/wiki-link-check.sh` — exit 0 (syntax clean).
- Bash 3.2 feature scan (grep for `declare -[aA]`, `mapfile`, `readarray`, `&>`, `<(`, `>(`) — zero matches.
- Line count: 297 lines (plan expected ≥ 180). File mode: `-rwxr-xr-x`.
- Mkdocs smoke: not executed — mkdocs availability probing and the smoke contract itself belong to T05's `m012-p02-link-check-smoke.sh` gate (plan step 9 is explicitly optional and gated on local mkdocs availability; plan step 10 permits skip).

## Deviation from plan

- **Plan verification bullet 4** — `bash scripts/verify/m012-p01-phase-suite.sh` currently reports `8/9 gates passed` (FAIL on `m012-p01-nav-structure.sh`). The failure is NOT caused by T03's deliverable (which sits entirely under `scripts/diagnostics/`, outside the P01 scanner surface). It is caused by the dispatch mechanism writing new `.orchestrator/milestones/M012/phases/P02/tasks/T03-PAYLOAD.md` (and other task-level artifacts) which the P01 scanner picks up but which were not present when the nav was last regenerated. This is a scanner/nav-generator policy question (whether task-level `*-PAYLOAD.md` belongs in the wiki nav surface at all) and belongs under T01/P01 scope, not T03. Per the plan's Constraints section ("T03 creates exactly one file plus its executable bit — no other files touched") and per Constitution XV (surgical precision), I did not modify nav, scanner, or P01 gate surfaces to paper over this. T05's P02 phase-suite and the M012 phase-close gate are the correct layers to re-run the nav regenerator (or to scope task-level files out of the scanner surface) if the regression persists when P02 closes.

## Patterns established

- **MEM004 carve-out applied correctly for diagnostics** — the script uses `grep -oE`, piped subshells, `sed`, `find | sort`, and PID-suffixed `/tmp` temp files inside its implementation, while the Check-layer shape it delivers is a single-script-file invocation consumable by T05's gates (one `bash scripts/diagnostics/wiki-link-check.sh` per phase-suite gate).
- **Pure-string path normalization as a realpath-free primitive** — `normalize_path` walks segments split on `IFS=/` into a positional-parameter stack, collapsing `.` and `..` via string-suffix trimming (`out="${out%/*}"`). No coreutils dependency — works on stock macOS bash with no Homebrew. The same primitive is reusable by any future diagnostic that needs to resolve paths without a filesystem.
- **Counter recomputation post-pipe** — counters (`BROKEN`, `OUT_OF_SCOPE`, `OK_LINKS`) are incremented inside a `while IFS='|' read -r page href` loop that reads from a file, NOT from a pipe — preserving increments across Bash 3.2's piped-subshell boundary. Findings lines are independently written to a file and sorted `-u` for deterministic emission.

## Deferred to downstream tasks

- **T04** — `wiki/README.md` "Link resolution" section + "Running the link checker" subsection + "Pre-deploy hook" guidance. T03 ships the diagnostic; T04 documents its operator-facing surface.
- **T05** — `scripts/verify/m012-p02-link-check-contract.sh`, `m012-p02-link-check-help.sh`, `m012-p02-link-check-smoke.sh` and the rest of the P02 gate suite. T05 asserts T03's contract mechanically (help tokens, missing-dir exit code, no-html-files exit code, optional mkdocs-gated smoke).
- **P04 (future phase)** — wiring `scripts/diagnostics/wiki-link-check.sh` as a pre-deploy hook per the roadmap cross-cutting concern. Not in T03, T04, or T05 scope; belongs to the deploy-pipeline phase.
