---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P03"
milestone: "M012"
provides:
  - "scripts/diagnostics/wiki-giscus-config-check.sh loud-fail pre-build gate; exits 1 with per-var FAIL lines + HINT when any of GISCUS_REPO, GISCUS_REPO_ID, GISCUS_CATEGORY, GISCUS_CATEGORY_ID is unset or empty; exits 0 with PASS on all-set; Bash 3.2 compatible; supports --help and --quiet; exit-code contract 0/1/2 for pass/missing/usage-error"
requires:
  - "from:T01 what:wiki/mkdocs.yml extra.giscus block expects four GISCUS_* env vars via !ENV NAME,'' interpolation (empty-string default is the silent-failure mode this gate closes)"
affects:
  - "P03/T05 (m012-p03-config-loud-fail.sh will wrap this diagnostic under fully-set and fully-unset env fixtures); P04 (deploy wrapper will invoke this gate before mkdocs gh-deploy)"
key_files:
  - "scripts/diagnostics/wiki-giscus-config-check.sh"
key_decisions:
  - "AD-19 single-script-file Check shape,MEM001 Bash 3.2 / stdout-stderr discipline,Constitution XV surgical precision (env-var-only scope; mkdocs.yml parsing deferred to T05)"
patterns_established:
  - "read-only diagnostic (no repo writes, no tmp files, no network); eval-based indirect expansion for Bash 3.2 portability over Bash 4 ${!name}; exit-code triad 0/1/2 (pass/missing/usage) for machine-readable distinction; PASS-only-on-stdout contract so capture/grep pipelines stay clean; probe-via-run-probe smoke harness for multi-case testing under pre-bash shape guard"
drill_down_paths:
  - ".orchestrator/milestones/M012/phases/P03/tasks/T02-PLAN.md,scripts/diagnostics/wiki-giscus-config-check.sh"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-21T02:49:45Z"
---

## Summary

T02 ships `scripts/diagnostics/wiki-giscus-config-check.sh`, the loud-fail
pre-build gate that verifies the four required Giscus environment variables
(`GISCUS_REPO`, `GISCUS_REPO_ID`, `GISCUS_CATEGORY`, `GISCUS_CATEGORY_ID`) are
set and non-empty before `mkdocs build` / `mkdocs gh-deploy` runs. This
short-circuits the silently-empty-string failure mode that T01 introduced
when it wired `!ENV NAME,` ` interpolation into `wiki/mkdocs.yml` — a
missing env var would otherwise flow through as an empty attribute on the
rendered Giscus `<script>` tag and produce a broken site without any
non-zero exit from the build.

## What was built

- **`scripts/diagnostics/wiki-giscus-config-check.sh`** — 93-line Bash 3.2
  diagnostic. Exits 0 with `PASS: all 4 GISCUS_* env vars set` on stdout
  when every required var is non-empty; exits 1 with one
  `FAIL: GISCUS_<NAME> unset or empty` line per missing var on stderr,
  plus a final `FAIL: <N>/4 required vars missing` summary and a
  `HINT: ... https://giscus.app ...` pointer. Supports `--help`/`-h`
  (usage to stdout, exit 0), `--quiet`/`-q` (silences PASS; failures still
  print), and exits 2 on unknown argument.

## Key decisions

- **Env-var-only scope** — did not parse `mkdocs.yml` `extra.giscus` block
  in T02 despite the dispatch prompt suggesting it. The plan pins T02 to
  env-var presence checking; Constitution XV (Surgical Precision) and the
  plans `Out-of-scope` note keep me from absorbing T03/T04/T05 concerns.
  `scripts/verify/m012-p03-mkdocs-giscus-config.sh` (T05) is the right
  home for mkdocs.yml static assertions.
- **`eval "value=\${$name:-}"` for indirect expansion** — Bash 4s
  `${!name}` is not safe across exotic Bash 3.2 installs; `eval` of the
  default-empty form is the portable contract (MEM001). Comment cites
  the tradeoff so future readers dont regress to `${!name}`.
- **Stdout/stderr discipline** — PASS is the only thing on stdout so
  consumers can `grep PASS`/capture via `$(...)` safely; FAIL, HINT, and
  ERROR all go to stderr so the build pipeline sees a clean success
  channel (MEM001 structured output convention).
- **Exit code triad** — 0 pass, 1 missing, 2 usage error. The T05 loud-fail
  gate can distinguish "correctly reported missing" (1) from "argument
  mistake" (2) without scraping text.

## Patterns established / reinforced

- **Read-only diagnostic** — no repo writes, no tmp files, no network. The
  gate runs safely under `env -i`, parallel, or dry-run contexts.
- **Self-documenting usage** — `--help` output enumerates each required
  var with a concrete-shape example (`R_kgDO...`, `DIC_kwDO...`) so
  operators can spot the ID prefix drift (DIC vs R_kgDO) without leaving
  the terminal.
- **Probe-via-run-probe** for multi-case smoke testing under the pre-bash
  shape guard — staged probe at `/tmp/m012-p03-t02-smoke.sh` ran 10
  scenarios, 13 assertions pass=13 fail=0. This keeps the plans
  "do not embed as a Check" smoke cases runnable without violating
  AP-009 compound-chain-gt2.

## Verification results

- **Manual smoke harness (/tmp/m012-p03-t02-smoke.sh, 10 cases, 13 asserts)**:
  pass=13 fail=0. Covered: all-unset (exit 1, 4 FAILs, summary, HINT),
  all-set (exit 0, PASS on stdout), one-empty (exit 1, 1/4 summary),
  three-unset (exit 1, correct per-var FAIL lines), unknown arg (exit 2),
  --help with env cleared (exit 0), --quiet silences stdout,
  single-var-unset (REPO_ID) reports exact diagnostic.
- **Must-Haves check** (`bash scripts/verify/check-must-haves.sh
  .orchestrator/milestones/M012/phases/P03`) — T02s artifact assertions
  PASS: `scripts/diagnostics/wiki-giscus-config-check.sh exists`,
  `has 93 lines (min 40)`, `contains GISCUS_REPO_ID`. Remaining FAILs are
  T01 README (missing "Giscus mapping" section, owned by T04) and the
  T03/T04/T05 artifacts that this task correctly does not ship.
- **Bash 3.2 compat (manual grep)** — no `declare -A`, `mapfile`,
  `${var^^}`, `<(...)`, `>(...)`, `&>`, or `${!name}` in non-comment
  code. Three matches are all on comment lines describing what is
  avoided.
- **AD-19 single-script-file Check shape** — satisfied: this diagnostic is
  a single-invocation script-file with all logic internal. The T05-owned
  `scripts/verify/m012-p03-config-loud-fail.sh` will wrap it as the Check.

## Open follow-ups (out of scope for T02)

- T03 ships `wiki-giscus-smoke.sh` (built-site HTML walker).
- T04 ships `wiki-giscus-remap.sh` and extends `wiki/README.md` with the
  Giscus mapping section — this is what the P03 must-have
  "wiki/README.md contains Giscus mapping" depends on.
- T05 ships the 8 verify gates plus the phase-suite orchestrator. The
  `m012-p03-config-loud-fail.sh` gate will invoke this diagnostic under
  both fully-set and fully-unset env fixtures and assert the expected
  exit codes and FAIL-line presence.
