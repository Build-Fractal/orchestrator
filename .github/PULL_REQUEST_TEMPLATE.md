<!--
Thanks for contributing! Keep PRs small and focused. See CONTRIBUTING.md for
conventions (Bash 3.2, the shape-guard, `git commit -F`, the SDD workflow).
-->

## What & why

<!-- One or two sentences: what this changes and the problem it solves. -->

Closes #<!-- issue number, if any -->

## Changes

<!-- Bullet the notable changes. -->
-

## Testing

<!-- Which suites did you run? Paste the BATTERY: lines. -->

```
# e.g. bash tools/verify/mNNN-pNN-acceptance-battery.sh
# BATTERY: pass=N skip=0 fail=0
```

- [ ] Ran the relevant `tests/` suites and/or `tools/verify/` batteries
- [ ] `bash scripts/diagnostics/run-doctor.sh` is clean (or new warnings explained)

## Checklist

- [ ] Bash 3.2 compatible (no `declare -A`, `mapfile`, `${v,,}`, process substitution)
- [ ] No forbidden command shapes (see `ANTIPATTERNS.md`); helpers don't long-chain
- [ ] New behavior has a fixture-backed test (byte-equality preferred)
- [ ] `CHANGELOG.md` updated under `## [Unreleased]` for user-visible changes
- [ ] Docs updated if behavior/usage changed
- [ ] Incidental churn reverted (PR is feature-only)
