# Proposal: Papercut — `check-boundary-map.sh` brace-glob tokenization false positive

**Captured**: 2026-05-04 during M032/P01 verification.
**Shape**: Single-line fix to one parser script.
**Predecessors**: none (latent defect since the script's introduction).

## Symptom

`scripts/verify/check-boundary-map.sh` emits a false-positive `FAIL: boundary-map P01 produces codex (not found at ./codex)` when a roadmap Produces: line contains a brace-glob like `install-{claude-code,codex,cursor}.sh`.

## Root cause

`scripts/verify/check-boundary-map.sh:83` strips parenthetical commentary (`s/([^)]*)//g`) before splitting the Produces: line on commas at `:85`. Brace-globs are not stripped, so the inner commas are treated as item separators. The parser sees three "items":

- `amended packaging/install/install-{claude-code` — fails the path-shape regex at `:98` (contains whitespace) → silently skipped.
- `codex` — passes the path-shape regex (alnum only) → checked against `./codex` → FAIL.
- `cursor}.sh reading from project_assets...` — fails the path-shape regex (whitespace) → silently skipped.

Confirmed against `.orchestrator/milestones/M032/M032-ROADMAP.md` P01 Produces: line which contains `install-{claude-code,codex,cursor}.sh`.

## Fix shape

One-line addition to `:83`, matching the existing parenthetical-strip pattern:

```bash
# Before
items=$(printf '%s' "$items" | sed 's/([^)]*)//g')

# After
items=$(printf '%s' "$items" | sed 's/([^)]*)//g; s/{[^}]*}//g')
```

The brace-glob strip runs before the comma split, so `install-{claude-code,codex,cursor}.sh` collapses to `install-.sh` (which fails the path-shape regex `:98` and is silently skipped — correct behavior, since the brace-glob expansion is not a single literal file path that can be checked on disk).

## Impact

- **M032 P01**: load-bearing — boundary-map FAIL on `codex` is the false positive blocking P01 verification.
- **Future milestones**: any Produces: cell using brace-glob (a natural shape for "all three installers" / "all four runtimes" / etc.) hits the same false positive.
- **Risk**: low. The fix is a one-line additive sed expression matching the existing parenthetical-strip pattern. It has no effect on Produces lines that don't use brace-globs.

## Test

After the fix, re-run:

```bash
bash scripts/verify/check-boundary-map.sh .orchestrator/milestones/M032/M032-ROADMAP.md P01 --root .
```

Expected: no `produces codex` FAIL line. The `install-{claude-code,codex,cursor}.sh` brace-glob silently collapses; if the operator wants disk-presence verification of all three installers, they should list them explicitly as three comma-separated entries (which is also the existing convention used elsewhere in the codebase).

## Out of scope

- Brace-glob expansion to disk-check each member. The path-shape regex is intentionally narrow ("looks like a single file path"); expanding brace-globs would require a separate "this Produces: cell intends multiple disk paths" parser. The current convention is that operators list each path explicitly when disk-presence verification is desired.
- Curly-brace handling in other parsers. `read-roadmap.sh` and similar use the same parenthetical-strip pattern; adding brace-glob handling there is a separate (smaller) cleanup pass.

## Promotion

Promote to a 1-task milestone (or a P01 follow-up commit) when next touching the boundary-map verifier, or roll into the next papercut sweep.
