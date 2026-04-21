---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P03"
milestone: "M012"
provides:
  - "scripts/diagnostics/wiki-giscus-remap.sh (Bash 3.2 idempotent remap: --dry-run, --help, --repo, --category, fail-closed ambiguity, DRY-RUN/OK/NOOP/FAIL per-pair emit, exit codes 0/1/2); wiki/README.md 'Giscus mapping' + 'Remapping threads after consolidation' sections (pathname strategy + tradeoffs + workflow + exit-code table)"
requires:
  - "from:T01 what:mapping=pathname in wiki/mkdocs.yml; from:T02 what:wiki-giscus-config-check.sh basename reference; from:T03 what:wiki-giscus-smoke.sh basename reference"
affects:
  - "T05 (m012-p03-remap-contract.sh + m012-p03-mapping-documented.sh + m012-p03-bash32-compat.sh assert on surfaces established here); P04 (operator-invoked remap step in consolidation runbook)"
key_files:
  - "scripts/diagnostics/wiki-giscus-remap.sh,wiki/README.md"
key_decisions:
  - "AD-3 SSOT (remap targets GitHub Discussions only, not disk artifacts),AD-5 mapping tradeoffs surface,MEM001 Bash 3.2,MEM020 write-summary discipline"
patterns_established:
  - "pair-loop arg consumption with shift 2 + parity check on dollar-hash mod 2; fixed-verb output enum (DRY-RUN/OK/NOOP/FAIL) for per-pair verdicts; dry-run decoupled from external tool presence (gh only required in live path); no-jq-hard-dep via gh api graphql --jq + pure-text parsing (grep -o + sed -n with field-order fallback); fail-closed on ambiguous title match; README append-only (Constitution XV blast-radius discipline); staged-probe smoke battery via scripts/util/run-probe.sh to satisfy pre-bash shape guard"
drill_down_paths:
  - ".orchestrator/milestones/M012/phases/P03/tasks/T04-PLAN.md,scripts/diagnostics/wiki-giscus-remap.sh,wiki/README.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-21T02:57:30Z"
---

## Summary

Shipped the Giscus Discussion remap utility plus `wiki/README.md` mapping
documentation — the AD-5 mapping-tradeoffs surface required by SC-7 / US5.
Under `mapping: pathname`, each rendered page keys to a Discussion whose
title equals the page URL. When artifacts move (e.g., consolidation under
`.orchestrator/archive/`), the remap script relabels the old Discussion's
title to the new pathname so Giscus' pathname-matcher reconnects the
thread on next page load.

## What was built

- **`scripts/diagnostics/wiki-giscus-remap.sh`** (150 lines, executable,
  Bash 3.2). Two-phase arg parse: flags (`--dry-run`, `--repo`,
  `--category`, `--help`/`-h`, `--`) then `<old> <new>` positional pairs.
  Non-dry-run requires `gh` on PATH plus non-empty `REPO` + `CATEGORY`
  (defaulting from `GISCUS_REPO` / `GISCUS_CATEGORY`). Pair loop emits
  exactly one of `DRY-RUN:`, `OK:`, `NOOP:`, `FAIL:` per pair — no quiet
  success. Ambiguous-match safety: title match count > 1 fails closed on
  that pair (exit 1) without attempting a rename. Idempotent: a second
  invocation after a successful remap emits `NOOP: ... (no match)` for
  every pair because the old title no longer exists. Exit codes: 0 all
  resolved, 1 ≥1 pair failed, 2 usage error.
- **`wiki/README.md` extension** — appended two top-level sections after
  the P02 "Pre-deploy integration" content: "Giscus mapping" (strategy +
  tradeoffs for rename / archive / content edits / theme changes,
  cross-references the P02 smoke script) and "Remapping threads after
  consolidation" (usage, dry-run, multi-pair invocation, env-var
  defaults, post-remap rebuild + smoke workflow, pre-build env-var
  check reference, exit-code table). P01/P02 content above is
  untouched.

## Key decisions

- **AD-3 SSOT preserved**: the remap script targets GitHub Discussions
  only. It does not edit `wiki/docs/**`, `.orchestrator/**.md`, or
  `wiki/mkdocs.yml` — comment state lives in GitHub, artifact state
  lives on disk.
- **Dry-run decoupled from `gh`**: `--dry-run` emits planned operations
  with zero external calls, so developers can reason about planned
  changes on a machine without `gh` auth. `gh` presence is checked only
  in the live path.
- **No jq hard-dep**: the script uses `gh api graphql --jq` for the
  fetch (gh bundles jq internally) and pure-text parsing (`grep -o`,
  `sed -n`) on the returned JSON for title-match counting and id
  extraction. Tolerant sed with a field-order fallback handles minor
  shape variations in the GraphQL response.
- **Fail-closed on ambiguity**: a title with multiple matches never
  auto-renames; the operator is told the match count and exits
  non-zero so human judgment arbitrates. Prevents accidental cross-
  thread merges.
- **README append-only**: the new sections sit below the P01/P02
  content; no P01/P02 prose was modified. This keeps T04's blast
  radius inside its stated scope (Constitution XV).

## Patterns established

- **Pair-loop arg-consumption with `shift 2`** — the canonical Bash 3.2
  idiom for `<old> <new>` iteration. Parity check `$# % 2` rejects odd
  positional counts at parse time so the loop is always safe.
- **Output-line verb enum** — every pair emits exactly one of a fixed
  set of prefixes (`DRY-RUN:` / `OK:` / `NOOP:` / `FAIL:`). Trivial to
  grep, trivial for T05 to assert on, and forces the script to be
  explicit about its per-pair verdict.
- **Staged-probe smoke battery via `scripts/util/run-probe.sh`** —
  the pre-bash shape guard rejects compound chains, so T04's 13-check
  smoke battery was staged as a single probe script. Single invocation
  verifies exit codes, stdout content, flag handling, README content,
  line count, Bash 3.2 compatibility, and syntax in one pass.

## Verification results

All 13 smoke-verify assertions PASS (`/tmp/m012-p03-t04-smoke.sh`):

- `--help` exits 0 with usage on stdout.
- `--dry-run /old/ /new/` exits 0 and prints `DRY-RUN: /old/ -> /new/`.
- `--dry-run` with 3 positional args exits 2 (odd count).
- Single positional arg exits 2.
- Unknown flag (`--bogus`) exits 2.
- Multi-pair `--dry-run /a/ /b/ /c/ /d/` emits 2 `DRY-RUN:` lines, exit 0.
- `wiki/README.md` contains `## Giscus mapping` heading.
- `wiki/README.md` references `wiki-giscus-remap.sh` (3 occurrences).
- `wiki/README.md` references `wiki-giscus-smoke.sh` (3 occurrences).
- Remap script executable, 150 lines, contains literal `pathname`.
- Remap script has no `declare -A` / `readarray` / `mapfile` (Bash 3.2 ok).
- Remap script passes `bash -n` syntax check.
- Remap script supports `--dry-run`, `--help`, `--repo`, `--category`.

T05 gates (`m012-p03-remap-contract.sh`, `m012-p03-mapping-documented.sh`,
`m012-p03-bash32-compat.sh`) are intentionally deferred to T05 per the
plan's scope fence.

## Open follow-ups (out of scope for T04)

- T05 owns the verify gates + phase-suite orchestrator and will assert
  on the surfaces this task established.
- P04 owns deploy-pipeline wiring. The remap script is invoked
  manually by an operator after a consolidation; no automated trigger
  is wired here (deliberately — human-in-the-loop for title mutations).
- A future enhancement could pre-populate `pairs` from
  `.orchestrator/` path diffs across consolidation commits; that would
  make remap zero-args in the common case. Out of scope until there is
  a consolidation event to measure against.
