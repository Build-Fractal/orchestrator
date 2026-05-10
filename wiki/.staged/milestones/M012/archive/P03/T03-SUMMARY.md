---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P03"
milestone: "M012"
provides:
  - "scripts/diagnostics/wiki-giscus-smoke.sh (129 lines, 755, Bash 3.2): post-build HTML walker that asserts every *.html under --site contains src="https://giscus.app/client.js"; flags --site/--root/--verbose/--help; exit 0 all-pages-have-it, exit 1 any-missing with one FAIL: <path> per miss + SUMMARY: on stderr, exit 2 usage-error/missing-dir/empty-dir; PASS: on stdout / FAIL:/ERROR:/HINT:/SUMMARY: on stderr; grep -qF literal match; mktemp list-file + while IFS= read -r pattern (no |-while, no process substitution, no declare -A); EXIT trap cleanup; AD-3 SSOT compliant (reads only built HTML, never .orchestrator/**.md)"
requires:
  - "from:T01 what:wiki/overrides/partials/comments.html emits the literal src="https://giscus.app/client.js" needle on every page; from:T02 what:scripts/diagnostics/wiki-giscus-config-check.sh exists as the pre-build companion cross-referenced in this script's header (no runtime coupling); from:disk what:scripts/diagnostics/ directory"
affects:
  - "T04 (remap script lands alongside this walker under scripts/diagnostics/), T05 (m012-p03-smoke-contract.sh gate exercises this walker against fixture sites; m012-p03-bash32-compat.sh scans this script), P04 (deploy wrapper chains config-check -> mkdocs gh-deploy -> this smoke walker)"
key_files:
  - "scripts/diagnostics/wiki-giscus-smoke.sh"
key_decisions:
  - "AD-3 SSOT (reads built HTML only),AD-19 single-script-file Check shape (Truth Checks stay single-invocation; MEM004 carve-out permits pipes/find/grep inside this diagnostic),Constitution XIV/XV (T03 ships the walker only; T04/T05 gates are out of scope),MEM001 stderr-vs-stdout split,MEM001 mktemp list-file + while IFS= read -r replaces |-while to avoid subshell counter loss"
patterns_established:
  - "post-build smoke walker shape: mktemp list file + find -print > list + while IFS= read -r page < list as Bash-3.2-safe replacement for find|while; companion-script header cross-reference without runtime coupling (T02 and T03 point at each other in header comments; P04 deploy wrapper chains both without either sourcing the other); literal-needle grep -qF constant with paired-update note in header (partial URL change requires paired walker update); stderr-carries-the-noise / stdout-carries-the-success convention so callers capturing stdout see only green signal"
drill_down_paths:
  - ".orchestrator/milestones/M012/phases/P03/tasks/T03-PLAN.md,scripts/diagnostics/wiki-giscus-smoke.sh"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-21T02:53:03Z"
---

## Summary

T03 ships `scripts/diagnostics/wiki-giscus-smoke.sh` — a post-build HTML walker that confirms every `*.html` page under a built-site directory carries the Giscus loader tag (`src="https://giscus.app/client.js"`). Companion to T02 (pre-build env-var gate); together they bookend `mkdocs build` and `mkdocs gh-deploy`.

## What was built

- **`scripts/diagnostics/wiki-giscus-smoke.sh`** (129 lines, 755, Bash 3.2 compliant).
  - Flags: `--site <dir>` (default `wiki/site`), `--root <dir>`, `--verbose`, `--help`.
  - Exit 0 when every page has the Giscus loader; exit 1 with one `FAIL: <path>` per miss + `SUMMARY:` line on stderr; exit 2 for usage error, missing site dir, or empty site dir.
  - Uses `mktemp` list file + `while IFS= read -r` pattern (MEM001) — no `|-while` subshell counter loss, no `declare -A`, no `mapfile`, no process substitution.
  - `set -u` / `set -o pipefail`; EXIT trap cleans up the /tmp list file.
  - `grep -qF` literal match against the needle — no regex false positives from Jinja-expanded attributes.
  - AD-3 SSOT compliant: reads only rendered HTML under the built-site directory; does not touch `.orchestrator/**.md`.

## Key decisions

- **Script-only scope** — T03 delivers just the walker. T05 owns the contract gate (`scripts/verify/m012-p03-smoke-contract.sh`) and T04 owns the remap script. Stayed inside XIV/XV surgical precision.
- **Stderr vs stdout split** — `PASS:` on stdout (green-path machine-readable success); `FAIL:` / `ERROR:` / `HINT:` / `SUMMARY:` on stderr (so a caller capturing stdout sees only the success signal).
- **No mkdocs dependency** — operates on pre-built HTML only. Missing site dir exits 2 with a `HINT:` rather than a silent skip, so callers can decide whether to build first or skip entirely.
- **Needle is a literal string constant** — change to the partial URL requires paired update here (documented in the header).

## Patterns established

- **Post-build smoke walker shape** — `mktemp` list file + `find … -print > list` + `while IFS= read -r page; do … done < list` as the Bash-3.2-safe replacement for `find … | while`. Reusable for future per-page assertions (e.g., sitemap, CSP, analytics).
- **Companion-script header cross-reference** — T02 and T03 point at each other in their header comments without runtime coupling; deploy pipeline (P04) chains both without either sourcing the other.

## Verification results

Manual smoke probe (not a Truth Check — ran 7 scenarios):

- `--help` exits 0 with usage on stdout.
- Missing site directory → exit 2 with `ERROR:` + `HINT:`.
- Empty site directory (no `.html` files) → exit 2 with `ERROR:` + `HINT:`.
- All pages carry Giscus → exit 0 with `PASS: N pages have Giscus`.
- One of two pages missing → exit 1 with one `FAIL:` line + `SUMMARY: 1/2`.
- Unknown arg → exit 2 with `ERROR:` + usage.
- Nested subdirectory walk with `--verbose` → exit 0, both pages reported as `OK:`.

Bash 3.2 compat scan (inline grep for `declare -A|mapfile|readarray|&>|<\(|>\(|\$\{…\^\^`) — no matches.

T05 gates (`m012-p03-smoke-contract.sh`, `m012-p03-bash32-compat.sh`) do not yet exist; they are the downstream gate owners that will consume this script.

## Open follow-ups (out of scope for T03)

- T04: `scripts/diagnostics/wiki-giscus-remap.sh` — thread remap script for rename/move recovery.
- T05: `scripts/verify/m012-p03-smoke-contract.sh` — fixture-driven contract gate that exercises this walker against golden passing + failing sites.
- T05: `scripts/verify/m012-p03-bash32-compat.sh` — automated Bash-4-feature scan covering all P03 diagnostics + verify scripts.
