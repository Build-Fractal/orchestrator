---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "M024/P02"
milestone: "M024"
provides:
  - "scripts/intake/m014-manifest-read.sh; scripts/verify/m024-p02-m014-manifest-read.sh"
requires:
  - "from:M024/P01/T05 what:tests/fixtures/m014-interim-manifest-keys.txt canonical key order"
affects:
  - "P02/T03,P02/T04"
key_files:
  - "scripts/intake/m014-manifest-read.sh, scripts/verify/m024-p02-m014-manifest-read.sh"
key_decisions:
  - "Use spec 028 (M014-migrated) instead of plan-suggested spec 023 (lacks type:feature-spec frontmatter) — same precedent as T01"
patterns_established:
  - "Invoke-time M014 shipping probe (test -f templates/spec-template.md) with distinct exit-3 stub message — mirrors P03 route-to-specify.sh"
drill_down_paths:
  - ".orchestrator/milestones/M024/phases/P02/tasks/T02-PLAN.md"
duration: "10m"
verification_result: "pass"
completed_at: "2026-04-26T01:57:20Z"
---

T02 ships scripts/intake/m014-manifest-read.sh — the live AD-4 direction `a` reader for the [M014](../../../../milestones/M014/index.md) interim-manifest contract. Given a feature spec path (--spec-path) or specs directory (--specs-dir), runs an invoke-time probe (test -f templates/spec-template.md) and either emits the six canonical M014 manifest keys (schema_version, type, feature_slug, created_at, status, milestone) as key=value lines on stdout in fixture order, or exits 3 with a clearly-marked unshipped-stub message. Missing frontmatter keys emit <key>=null rather than dropping the line — line count is always six (parseability invariant). Distinct exit codes (0/1/2/3) let downstream callers branch. Pure stdout — no disk writes (SB-3). DEVIATION: plan named specs/023-github-native-integration as the in-repo verify fixture, but that spec predates the M014 rollout and lacks the type:feature-spec frontmatter the reader requires. Used specs/028-universal-intake-routing instead — same precedent as T01-SUMMARY. Verification: PASS: m014-manifest-read.sh — six keys in canonical order, --spec-path / --specs-dir parity. Smoke-tested usage error (exit 2), missing spec (exit 1), mutual-exclusion (exit 2), and missing-key=null fallback (exit 0).
