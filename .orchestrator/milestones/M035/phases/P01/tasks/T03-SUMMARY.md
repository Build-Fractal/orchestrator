---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P01"
milestone: "M035"
provides:
  - "scripts/state/check-orchestrator-drift.sh (read-only drift helper, FR-3 / FR-15); SHA-absent fallback per #Q-G5; tools/verify/m035-p01-drift-detection.sh (SC-3 SHA-bearing path); tools/verify/m035-p01-drift-detection-sha-absent.sh (SC-3b pre-M035 fallback path)"
requires:
  - "from:P01/T01 what:tests/m035-acceptance/fixtures/install-meta-with-sha.txt + install-meta-pre-m035.txt; from:CHANGELOG.md what:## [X.Y.Z] semver line for upstream version extraction"
affects:
  - "P01/T04 (status-line render-side consumes the helper's stdout key=value block)"
key_files:
  - "scripts/state/check-orchestrator-drift.sh,tools/verify/m035-p01-drift-detection.sh,tools/verify/m035-p01-drift-detection-sha-absent.sh"
key_decisions:
  - "inline awk semver-delta (no separate lib/semver-delta.sh — patch-diff when major+minor match, else 1); CHANGELOG awk pattern restricted to ^## \[[0-9] to skip past ## [Unreleased]; verifier owns fixture upstream creation under mktemp -d with git config commit.gpgsign false guard against operator gpg configs"
patterns_established:
  - "read-only drift helper exits 0 always (FR-15 — consumers branch on data not exit code); SHA-absent fallback emits commits_behind=unknown + one-time stderr advisory; verifier owns its fixture upstream-repo (mktemp -d + git init + N seeded commits + rewrite consumer commit_sha to fixture INITIAL_SHA) for deterministic commits_behind=N assertions"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P01/tasks/T03-check-orchestrator-drift-PAYLOAD.md"
duration: "35m"
verification_result: "pass"
completed_at: "2026-05-08T13:24:00Z"
---

T03 authors the read-only drift-detection helper
`scripts/state/check-orchestrator-drift.sh` and the two verifiers that
exercise it (SC-3 SHA-bearing path + SC-3b pre-M035 fallback).

## Helper shape

`scripts/state/check-orchestrator-drift.sh --consumer <path>` (defaults
to `$PWD`) reads the consumer's `.orchestrator/install-meta.txt`
(`commit_sha=`, `version=`) and `.orchestrator/config.yml`
(`update_source:`, `update_upstream_path:`), then emits a four-line
sorted `key=value` block on stdout:

```
commits_behind=<integer | unknown>
update_source=<git | npm | homebrew | none>
upstream_path=<absolute-path-or-empty>
versions_behind=<semver-delta-or-0>
```

Exits 0 always (FR-15: consumers branch on the data, not the exit code).
Bash 3.2 compatible — no process substitution, no associative arrays,
no `<<<` herestrings, no jq.

For `update_source=git` (the only fully-implemented path in P01) the
helper runs `cd "$upstream_path" && git rev-list --count "$commit_sha..$upstream_head"`
when `$upstream_path/.git` exists. `npm` and `homebrew` are recognised
in the emission shape but the upstream-comparison code is a no-op for
them (P06 will extend); `none` short-circuits with all-zero output.

## SHA-absent fallback (#Q-G5)

When `commit_sha=` is absent (pre-M035 dogfood-installs at lakeledger /
pbj-central / bbt-companion), the helper emits `commits_behind=unknown`
plus exactly one stderr advisory line:

```
commit-SHA not recorded in install-meta.txt — drift detection using version comparison only (pre-M035 install).
```

When `version=` is also absent (the pre-M035 fixture shape), the
versions_behind diff branch is skipped and `versions_behind=0` is
emitted.

## Versions-behind delta

Computed from CHANGELOG semver delta — works regardless of whether
`commit_sha=` is present, as long as `version=` is set. The delta
math is inlined as awk (avoiding the optional `lib/semver-delta.sh`
helper called out in the payload):

- Major or minor mismatch → `1`.
- Same major+minor → patch-level diff (`max(B[3]-A[3], 0)`).

The CHANGELOG awk pattern is `^## \[[0-9]` rather than `^## \[` to
skip past `## [Unreleased]` (the live spec-kit-orchestrator CHANGELOG
opens with `## [Unreleased]`); the verifier's fixture upstream still
matches the pattern because the fixture writes `## [0.9.3]` first.

## Verifiers

Both verifiers stage two `mktemp -d` trees (consumer + upstream),
seed a real fixture upstream git repo with a known number of commits,
then exercise the helper:

- `tools/verify/m035-p01-drift-detection.sh` — copies the SC-3 fixture
  (`install-meta-with-sha.txt`), seeds an upstream with 1 initial
  commit + 1 CHANGELOG commit + 13 padding commits = 14 commits past
  `INITIAL_SHA`, rewrites the consumer's `commit_sha=` to point at
  `INITIAL_SHA`, then asserts stdout contains
  `commits_behind=14`, `update_source=git`, and a `versions_behind=`
  line. Exit 0.
- `tools/verify/m035-p01-drift-detection-sha-absent.sh` — copies the
  SC-3b fixture (`install-meta-pre-m035.txt`), seeds a minimal upstream,
  asserts stdout contains `commits_behind=unknown` + `versions_behind=0`,
  asserts stderr contains exactly one `pre-M035 install` advisory line,
  asserts exit 0.

The verifiers use `cd "$UPSTREAM_TREE" && git init …` directly inside
their bodies (allowed per AP-009 — the compound is in a script body,
not in a shape-guarded inline `Check:` command). `git config commit.gpgsign false`
+ `git -c commit.gpgsign=false commit` defends against operator gpg
configs that would otherwise block fixture commits.

## Verification

```
$ bash tools/verify/m035-p01-drift-detection.sh
PASS: m035-p01-drift-detection
$ bash tools/verify/m035-p01-drift-detection-sha-absent.sh
PASS: m035-p01-drift-detection-sha-absent
```

Both green. No scope-adjacent fixups required — the helper is new code
and the verifiers are self-contained against `mktemp -d` fixtures.
