---
schema_version: "1.0"
type: acceptance-evidence
milestone: "M037"
generated_at: "2026-05-07T20:30:00Z"
scope: "M037 wiki team-feedback-ready milestone close (P01+P02+P03 all green)"
verdict: "GREEN"
verdict_summary: "All three phases closed. Acceptance battery pass=11/skip=0/fail=0. Validate-milestone 71/71. wiki-strict-build clean. PBJ-central live-dogfood satisfaction signal confirmed after round-5."
git_sha: "c03efcc4"
---

# M037 — Acceptance Evidence Ledger

This document captures the M037 close evidence per the M030/M031/M032
evidence-ledger convention. M037 (wiki team-feedback-ready) closes
2026-05-07 with three phases shipped, full acceptance battery green,
and the load-bearing PBJ-central live-dogfood satisfaction signal
received.

## Phase rollup

| Phase | Closed | Verification |
|-------|--------|--------------|
| P01 (homepage card grid + version: title + DR-### heading shape + nav.tabs/toc_depth/edit_uri + install-template config.yml clobber fix) | 2026-05-06 (commit `b0fe3588`) | phase-suite `pass=9 fail=0` |
| P02 (publishing-robustness paper-cut bundle: F8 feedback routing + F12 workflow Pages publishing + F13 private-repo site_url + F10 OUT-OF-SCOPE collapse + F11 discussions callout) | 2026-05-07 (commit `d395870d`) | phase-suite `pass=5 fail=0`, acceptance battery `pass=10 skip=0 fail=0` |
| P03 (PBJ-feedback polish series: round-3.5 / round-3.5-sync / round-4 / round-5) | 2026-05-07 (commits `79b0f7a9` `6919bdb9` `19be603d` `b81b9334`) | acceptance battery `pass=11 skip=0 fail=0`; wiki-strict-build PASS; PBJ live-dogfood satisfaction signal |

## Close-time verifications (run 2026-05-07T20:00–20:30Z)

### Acceptance battery

```
$ bash tests/m037-acceptance/run-acceptance-battery.sh
...
BATTERY: pass=11 skip=0 fail=0
```

All 11 acceptance tests green. No skips; no fails.

### Cross-phase milestone validation

```
$ bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M037
VALIDATE: P01 summary EXISTS
VALIDATE: P02 summary EXISTS
VALIDATE: P03 summary EXISTS
VALIDATE: P01 boundary PASS
VALIDATE: P02 boundary SKIP (no produce items)
VALIDATE: P03 boundary SKIP (no produce items)

VALIDATE: PASS — 71/71 checks passed
```

P02 + P03 boundary maps emit "no produce items" because both phases
shipped without the formal boundary-map line item structure (P02
absorbed publishing-robustness amendments mid-flight; P03 was de-facto
PBJ-feedback-driven). Surface coverage is captured in the per-phase
SUMMARY `provides:` field instead of in roadmap boundary-map produce
entries. validate-milestone treats the SKIP as informational, not a
blocker.

### Wiki strict build

```
$ bash scripts/verify/wiki-strict-build.sh
PASS: wiki-strict-build (0 errors, 0 warnings)
```

Orchestrator's own wiki tree builds cleanly under mkdocs `--strict`
after the round-5 navigation.sections drop, confirming the bundle
change does not regress the dogfood wiki.

## PBJ-central live-dogfood satisfaction signal

P03's demo sentence is "non-author SME team gives positive wiki signal".
The signal is captured by direct operator confirmation 2026-05-07 after
round-5 (commit `b81b9334`) landed and PBJ-central retested:

> **"pbj is looking good in the wiki now"**

This is the load-bearing acceptance signal for P03 closure under the
de-facto narrowing established at round-3.5 commit time (FR-12..FR-17
deferred to post-launch per
`.orchestrator/proposals/M037-fr-12-17-deferred-scope.md`).

## Deferred scope captured

Formal P03 scope at `M037-ROADMAP.md:32` (FR-12..FR-17 — tag-driven nav
buckets, GitHub source-link rewrite Tier 1 pass, `/knowledge/` card grid,
`mkdocs-redirects` + `mkdocs-git-revision-date-localized-plugin` plugins,
optional Material `social`+`meta`) was de-facto narrowed by the
round-3.5 PBJ-feedback signal. Captured as a post-launch fast-follow
under `.orchestrator/proposals/M037-fr-12-17-deferred-scope.md`. The
parent post-launch proposal (`post-launch-wiki-ux-and-adapters.md`)
absorbs this scope.

## yaml-merge list-element preservation gap (deferred post-launch)

Round-5 surfaced a yaml-merge limitation: list-valued sub-keys of
managed namespaces are operator-wins-byte-identical, so dropping a
list element from the framework default does not propagate to existing
projects. Captured for post-launch follow-up; not blocking M037
closure. Existing PBJ-central operator received manual-edit guidance
in the round-5 re-engagement ping. Surface area:
`scripts/lib/yaml-merge.sh`. Pattern: extend with list-managed-namespace
semantics or ship a `--replace-list-keys` flag.

## Reproducibility

```bash
git checkout c03efcc4
bash tests/m037-acceptance/run-acceptance-battery.sh    # → BATTERY: pass=11 skip=0 fail=0
bash scripts/verify/validate-milestone.sh .orchestrator/milestones/M037   # → VALIDATE: PASS — 71/71
bash scripts/verify/wiki-strict-build.sh                # → PASS (0 errors, 0 warnings)
```

## Cross-references

- `.orchestrator/milestones/M037/M037-ROADMAP.md` — original phase
  decomposition + boundary maps
- `.orchestrator/milestones/M037/M037-SUMMARY.md` — milestone summary
  per the M030/M031/M032 evidence-ledger convention
- `.orchestrator/milestones/M037/phases/P01/P01-SUMMARY.md`
- `.orchestrator/milestones/M037/phases/P02/P02-SUMMARY.md`
- `.orchestrator/milestones/M037/phases/P03/P03-PLAN.md` — retroactive
  plan documenting the round-by-round narrative
- `.orchestrator/milestones/M037/phases/P03/P03-SUMMARY.md`
- `.orchestrator/proposals/M037-fr-12-17-deferred-scope.md` — formal
  scope deferral capture
