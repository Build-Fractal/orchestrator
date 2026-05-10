---
schema_version: "1.0"
type: proposal
status: pending
priority: high (PBJ this week)
captured_at: "2026-05-07"
captured_by: "operator wiki-deploy session for PBJ-central round-3 ship"
folds_into: |
  Disposition table at top routes each finding into the right
  pre-launch milestone. M037 P01 absorbs #1, #2, #5, #7
  (wiki-tooling readability + operator-deploy correctness, same
  surface area, PBJ-team-this-week deadline). M035 P00/P01 absorbs
  #3, #4 (installer hygiene + bash 3.2 exit propagation, baseline
  hardening). #6 stays standalone — M028 hook follow-up not tied
  to launch.
---

# Paper-Cut Sweep — wiki-deploy session (2026-05-07, PBJ-central round 3)

## Why a sweep

The 2026-05-07 wiki-deploy session against PBJ-central surfaced 7
findings spread across three surfaces (wiki tooling, installer
internals, bash hooks). Three are operator-facing UX (`#1`, `#5`,
`#7`), one is operator-facing primitive correctness (`#2`,
medium-high — wiki-deploy reports success when GitHub Pages didn't
rebuild), two are installer-internals hygiene (`#3`, `#4` — both
benign today, footguns tomorrow), one is hook-layer ergonomics
(`#6` — fired on the operator ~6× this session).

This sweep doc is the **canonical record**. Per-finding actionable
detail (reproducer, fix shape, severity, acceptance) lives below.
[M037](../milestones/M037/index.md) + [M035](../milestones/M035/index.md) briefs cross-reference this doc rather than duplicating.

## Disposition

| # | Finding | Severity | Disposition |
|---|---|---|---|
| 1 | `wiki-generate-stubs.sh` doesn't route `.orchestrator/feedback/*.md` | medium | M037 P01 (F8 below) |
| 2 | `wiki-deploy.sh` reports OK without verifying Pages rebuilt | medium-high | M037 P01 (F9 below) |
| 3 | `install-meta.txt` should be `.gitignore`d automatically | low (footgun) | M035 P01 (Finding F below) |
| 4 | wiki-collision masking unfixed (bash 3.2 `set -e` + `while read` exit propagation) | medium | M035 P00 (Finding G below) |
| 5 | `wiki-deploy` dry-run dominated by 178 OUT-OF-SCOPE giscus lines | low | M037 P01 (F10 below) |
| 6 | `pre-bash-shape-guard.sh` `compound-chain-gt2` too aggressive for read-only chains | low (friction) | Standalone — [M028](../milestones/M028/index.md) follow-up (below) |
| 7 | GitHub Pages org-level redirect captures repo-level discussions URL | docs-only | M037 P01 (F11 below) |

---

## Finding 1 — `wiki-generate-stubs.sh` doesn't route `.orchestrator/feedback/*.md`

**Surface area:** `scripts/wiki/wiki-generate-stubs.sh` (routing arms
for `top:*`, `proposals:*`, `knowledge-flat`, `extra:*`, `milestone:*`).

**Why it matters:** `KNOWLEDGE.md` cross-links to
`feedback/<file>.md`. The wiki-deploy link-checker (correctly) treats
those as in-scope and FAILs because no stubs exist at
`wiki/docs/feedback/`. Operator had to hand-scaffold two stubs to get
past gate 2 of the deploy.

**Severity:** medium. Bites every project past BG-001-style validation
gates — `.orchestrator/feedback/` is the standard location for
round-by-round SME signoff captures. PBJ-central has the pattern;
LakeLedger and BBT-companion will hit it as their gate cycles mature.

**Fix shape:**
- New routing arm `feedback:<basename>` mirroring `proposals:*`
  (lines ~1056-1071): stubs land at `wiki/docs/feedback/<basename>.md`,
  canonical source at `.orchestrator/feedback/<basename>.md`,
  fragment-only passthrough (`rewrite-relative-urls=false` per B5
  precedent).
- Title-derivation fallback: feedback files don't carry `version:`
  the way reference-corpus chunks do. Derive title from H1 of the
  source file; fall back to humanized basename when H1 absent.
- Section index emission via `register_child` so `wiki-generate-nav.sh`
  surfaces the bucket without manual `nav:` edits.

**Acceptance:**
- Synthetic fixture under `tests/m037-acceptance/` with
  `.orchestrator/feedback/test-feedback.md` produces
  `wiki/docs/feedback/test-feedback.md` stub.
- `mkdocs build --strict` clean against the fixture.
- Title falls back gracefully when source has no `version:` and no H1
  (humanized basename).

---

## Finding 2 — `wiki-deploy.sh` reports OK without verifying Pages rebuilt

**Surface area:** `scripts/wiki/wiki-deploy.sh` (post-push success
reporting).

**Why it matters:** `OK: deployed to gh-pages` is a misleading success
signal. The script's contract today is "pushed to gh-pages branch,"
not "Pages serves the new build." On 2026-05-07 the push succeeded but
the Pages auto-trigger didn't fire — operator confidently shared a
URL serving stale content. The deploy script is the operator-facing
primitive; its success message must mean what operators think it means.

**Severity:** medium-high. Bites every operator on every deploy; the
mismatch is silent and the recovery (manually re-running the
`pages-build-deployment` workflow) is non-obvious.

**Fix shape:**
- After `git push origin gh-pages`, capture the push timestamp.
- Poll `gh api repos/{owner}/{repo}/pages/builds/latest` for ~60s,
  waiting for a `created_at` newer than the push timestamp.
- If a fresh build appears: print
  `OK: deployed to gh-pages and Pages build started at <created_at>`.
- If no fresh build appears within the budget: exit non-zero with
  `WARN: pushed to gh-pages but Pages did not start a build within
   60s — try re-running the last pages-build-deployment workflow at
   <repo>/actions/workflows/pages-build-deployment.yml`.
- Honor `--skip-pages-verify` flag for CI environments where the
  `gh` token can't read Pages build status.
- Pre-flight: check `gh auth status` + `gh api` reachability; skip the
  poll with a `WARN: skipped Pages verification (gh unavailable)` line
  rather than failing if `gh` is missing.

**Acceptance:**
- Successful push + fresh build reported as `OK` with `created_at`
  timestamp.
- Successful push + no fresh build within budget exits non-zero with
  recovery URL.
- `--skip-pages-verify` short-circuits the poll without changing
  exit code.
- `gh` unavailable surfaces a single `WARN` line without changing
  exit code.

---

## Finding 3 — `install-meta.txt` should be `.gitignore`d automatically

**Surface area:** `packaging/install/install-claude-code.sh:462-475`
(and codex/cursor parity at `:271-284` / `:280-293`).

**Why it matters:** The sidecar carries
`source_root=/Users/brettkellgren/...` — an absolute homedir path
that would leak to other contributors if accidentally committed.
Operator hand-added `.env` to `.gitignore` for the same reason during
the giscus paper-cut; both should be installer-managed under the same
managed-marker-block convention.

**Severity:** low (operator vigilance catches it) but a footgun by
design — the moment vigilance lapses, an absolute homedir leaks into
git history.

**Fix shape:**
- After `meta_file` is written, append a managed marker block to
  `<PROJECT_DIR>/.gitignore` if not already present:
  ```
  # >>> orchestrator-managed: gitignore >>>
  .orchestrator/install-meta.txt
  # <<< orchestrator-managed: gitignore <<<
  ```
- Idempotent: on re-run, replace the marker block contents rather
  than appending duplicates.
- Mirror the giscus pattern in `papercut-wiki-deploy-env-loader.md`
  Layer 2 — same managed-block convention, same marker shape.
- Apply to all three installer scripts (claude-code, codex, cursor)
  for parity.

**Acceptance:**
- Fresh install on a project with no `.gitignore` creates one with
  the managed marker block.
- Fresh install on a project with an existing `.gitignore` (no marker
  block) appends the managed block.
- Re-install leaves exactly one managed marker block (no duplication).
- `git status` after install shows no untracked `install-meta.txt`.

---

## Finding 4 — wiki-collision masking unfixed (bash 3.2 exit propagation)

**Surface area:** `packaging/install/install-claude-code.sh` runtime
stage `while read` loop with `if ! ...` exit propagation; collision
detection in `scripts/util/staged-dirs-collision.sh` (or similar).

**Why it matters:** Today's `install-meta.txt` timing fix (commits
`f67efb04` + `253eb748`) moved the sidecar write before the per-asset
loop, which solves the immediate symptom. The underlying issue is
unfixed: the installer prints `staged-dirs-collision: ...` to stderr
and exits 0 when wiki collides. We confirmed `INSTALLER_EXIT=0`
despite the collision-check returning exit 4 and the installer's
`if ! ...; then ... exit "$rc"; fi` block being structurally correct.

Likely root cause: bash 3.2 `set -e` interaction with process
substitution + `while read` — exit status from inside the loop
doesn't propagate up to the surrounding `if !`. macOS ships bash 3.2
by default; CI likely runs bash 4+ where this would behave correctly,
which is why the bug is invisible on the test path but live on
operator machines.

**Severity:** medium. Today the masking is benign (everything
M037 needs lands before the loop); tomorrow it'll mask a real install
failure and the operator won't know until something breaks downstream.

**Fix shape:**
- Reproduce the masking on macOS bash 3.2 with a synthetic collision
  fixture; confirm exit-status propagation is the breakage.
- Replace the `while read` loop with a `for` loop over a temp file
  (`process_substitution_safe.sh` pattern), OR explicitly capture
  the loop's exit status into an outer variable before the `if !`
  check.
- Add a regression test under `tests/installer-acceptance/` that
  forces a collision and asserts non-zero installer exit.
- Tag with `AP-???` in `ANTIPATTERNS.md` if the bash 3.2
  process-substitution + `set -e` interaction is a recurring shape.

**Acceptance:**
- Collision fixture + bash 3.2 produces non-zero installer exit.
- Collision fixture + bash 4+ produces non-zero installer exit
  (regression coverage for both shells).
- Existing successful-install fixtures still produce exit 0.

---

## Finding 5 — `wiki-deploy` dry-run dominated by 178 OUT-OF-SCOPE giscus lines

**Surface area:** `scripts/wiki/wiki-deploy.sh` link-checker output.

**Why it matters:** Every page emits
`OUT-OF-SCOPE: ... -> https://github.com/.../discussions [external]`
for the giscus comment-page link. With 178 pages in PBJ-central, the
real deploy report (in-scope link checks, gate status, projection
counts) is drowned in noise. Operator can't read past the OUT-OF-SCOPE
wall to find actionable signal.

**Severity:** low — output noise, not a correctness issue. But it
compounds with finding #2 (operator misreads success): operator who
can't find the actionable lines is more likely to misread a stale
deploy as fresh.

**Fix shape:**
- Detect repeated OUT-OF-SCOPE patterns (same target URL across many
  source pages) and collapse to a single summary line:
  `OUT-OF-SCOPE: 178 pages -> https://github.com/.../discussions [external giscus]`.
- Keep first 3-5 unique OUT-OF-SCOPE targets as full lines for
  diagnostic context; collapse the rest to `(+N more)`.
- Honor `--verbose` flag to disable collapsing for debugging.

**Acceptance:**
- 178-page fixture emits one OUT-OF-SCOPE summary line for the giscus
  target instead of 178 lines.
- Mixed-target fixture (e.g., 5 unique external targets) shows each
  target individually if instance count is low; collapses to
  summaries above a threshold (e.g., >10 instances of the same target).
- `--verbose` flag restores per-occurrence emission.

---

## Finding 6 — `pre-bash-shape-guard.sh` `compound-chain-gt2` too aggressive for read-only diagnostics

**Surface area:** `scripts/hooks/pre-bash-shape-guard.sh`
(`compound-chain-gt2` heuristic, see `ANTIPATTERNS.md#AP-009`).

**Why it matters:** The reject blocks read-only diagnostic chains
like `ls X 2>&1; echo "---"; ls Y 2>&1`. The hook fired on the
operator ~6 times this session. The intent (push complex flows into
`scripts/util/run-probe.sh`) makes sense for mutating chains; for
read-only `ls` / `grep` / `cat` chains it's pure friction with no
mutation risk to mitigate.

**Severity:** low (friction, not correctness). But agent productivity
matters — every false-positive reject is a wasted dispatch cycle.

**Fix shape:**
- Maintain a known-read-only command allowlist
  (`ls`, `cat`, `grep`, `head`, `tail`, `wc`, `find` without
  `-exec`/`-delete`, `awk`/`sed` without `-i`, `git status`/`log`/
  `diff`/`show`/`branch -v`, `gh api` GET-only paths).
- Relax `compound-chain-gt2` when EVERY command in the chain matches
  the allowlist; reject preserved when ANY command is mutating or
  unknown.
- Add unit tests under `tests/hooks/` covering: pure read-only chain
  passes, mixed read-only + mutating chain rejects, unknown command
  rejects (default-deny preserved for unknowns).

**Disposition:** Standalone paper-cut. M028 closed 2026-04-29 but the
hook layer is its territory; this is a follow-up tightening of the
heuristic, not a new milestone. Ships independently of M037 / M035.

**Acceptance:**
- `ls X 2>&1; echo "---"; ls Y 2>&1` passes the guard.
- `ls X; rm Y` rejects (mixed read-only + mutating).
- `frobulate; bar` rejects (unknown command, default-deny).

---

## Finding 7 — GitHub Pages org-level redirect captures repo-level discussions URL

**Surface area:** `wiki/README.md` first-deploy checklist
(documentation-only).

**Why it matters:** When the org has org-level Discussions enabled,
`https://github.com/<Org>/<Repo>/discussions` can 302 to
`https://github.com/orgs/<Org>/discussions`. The repo's discussions
still work via API and giscus, but the operator UX is confusing —
"create category" UI lives at the org level until the operator
navigates to the repo discussions categories management URL directly.

This is **not orchestrator's bug to fix** (it's GitHub UX), but it's
a documented dead-end the next operator will hit.

**Severity:** docs-only. Two paragraphs in the right doc save the
next operator the same dead-end.

**Fix shape:**
- Add a callout block to `wiki/README.md` § "First-deploy checklist"
  under giscus-setup steps:
  > **Org-level redirect quirk**: if your GitHub org has org-level
  > Discussions enabled, `https://github.com/<Org>/<Repo>/discussions`
  > may redirect to the org-level page. Use the repo's discussions
  > categories management URL directly:
  > `https://github.com/<Org>/<Repo>/discussions/categories`.
  > giscus + the discussions API both still work against the repo;
  > only the web UI redirects.
- Cross-reference in `scripts/diagnostics/giscus-ids-from-gh.sh` if
  the script also fetches discussion-category IDs and could surface
  the same confusion.

**Acceptance:**
- Callout present in `wiki/README.md` first-deploy checklist.
- No code changes required.

---

## Cross-references

- [`.orchestrator/proposals/M037-wiki-team-feedback-ready.md`](../proposals/M037-wiki-team-feedback-ready.md) — absorbs
  findings #1, #2, #5, #7 into P01 scope (F8 / F9 / F10 / F11 below
  the existing F7).
- [`.orchestrator/proposals/M035-packaging-distribution.md`](../proposals/M035-packaging-distribution.md) — absorbs
  findings #3 and #4 into P01 / P00 (Findings F + G appended to the
  existing Findings A-E section).
- [`.orchestrator/proposals/papercut-wiki-deploy-env-loader.md`](../proposals/papercut-wiki-deploy-env-loader.md) —
  precedent for the managed-marker-block pattern finding #3 mirrors.
- [`.orchestrator/proposals/papercut-sweep-m032-pbj-dogfood-round2.md`](../proposals/papercut-sweep-m032-pbj-dogfood-round2.md) —
  precedent for the sweep-doc shape this proposal follows; B5
  fragment-only passthrough is the precedent finding #1's routing-arm
  fix follows.
- `ANTIPATTERNS.md#AP-009` — the heuristic finding #6 proposes
  relaxing.

## What this sweep is NOT

- NOT a new milestone. All actionable findings absorb into existing
  pre-launch milestones (M037, M035) or ship as standalone follow-ups
  (#6).
- NOT a redesign of any of the surfaces touched. Each fix is the
  smallest correct change.
- NOT a `--strict` blocker triage. Round 2 (`papercut-sweep-m032-
  pbj-dogfood-round2.md`) covered build-strict failures; this round
  covers operator-experience-of-deploy failures.
