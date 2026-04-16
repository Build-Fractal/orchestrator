# Handoff: M002 + M003 Audit Fixes

**Date**: 2026-04-09
**Context**: Full audit of M002 (Knowledge Architecture, 7 phases) and M003 (Migration Tool, 6 phases) found issues to fix before deployment.
**Working directory**: /Users/brettkellgren/Sites/lakeledger/spec-kit-orchestrator

## Status

Both milestones are feature-complete (13 phases, ~50+ scripts). All functionality verified against real lakeledger GSD2 data. The audit found 2 critical and several medium issues.

## Fixes Required

### CRITICAL 1: Process Substitution `< <(...)` — Breaks on Bash 3.2

Two files use `done < <(command)` which is NOT supported as a redirection target in Bash 3.2 (macOS default).

**File 1: `scripts/dispatch/build-context.sh:689`**
```bash
# CURRENT (broken on Bash 3.2):
done < <(find "$MILESTONE_DIR" -type f -name "*.md" -o -name "*.yml" -o -name "*.yaml" -o -name "*.sh" 2>/dev/null)

# FIX: Use a temp file approach:
_tmp_filelist="$(mktemp)"
find "$MILESTONE_DIR" -type f \( -name "*.md" -o -name "*.yml" -o -name "*.yaml" -o -name "*.sh" \) 2>/dev/null > "$_tmp_filelist"
while IFS= read -r f; do
  ...
done < "$_tmp_filelist"
rm -f "$_tmp_filelist"
```

**File 2: `scripts/verify/check-scope.sh:102`**
```bash
# CURRENT (broken on Bash 3.2):
done < <(git diff --name-only HEAD 2>/dev/null || true)

# FIX: Same temp file pattern
```

NOTE: `scripts/verify/check-scope.sh` is a pre-existing M001 file, not from this session. Fix it anyway since it's in scope.

### CRITICAL 2: `sed -i.bak` Without BSD Cleanup — Creates Junk Files on macOS

Five locations use `sed -i.bak` which creates `.bak` backup files on macOS. The project already has a portable `sed_i` helper in 3 other scripts — these files should use the same pattern.

**File 1: `scripts/lifecycle/sync-roadmap.sh` (lines 82, 91)**
```bash
# CURRENT:
sed -i.bak "s/- \[x\] \*\*${pid}\*\*/- [ ] **${pid}**/" "$ROADMAP_FILE"
sed -i.bak "s/- \[ \] \*\*${pid}\*\*/- [x] **${pid}**/" "$ROADMAP_FILE"

# FIX: Add sed_i helper at top of file, use it:
sed_i() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}
# Then replace sed -i.bak with sed_i
# Also rm -f "${ROADMAP_FILE}.bak" lines if they exist
```

**File 2: `scripts/lifecycle/lock-manager.sh` (lines 189, 193, 196)**
```bash
# Same fix: add sed_i helper, replace all 3 sed -i.bak calls
```

NOTE: Both are pre-existing M001 files. Fix them anyway.

### MEDIUM: Add Double-Sourcing Guards to 7 Library Files

These sourced library files lack idempotent sourcing guards. Add this pattern at the top of each:

```bash
[ -n "${_LIBNAME_SOURCED:-}" ] && return 0
_LIBNAME_SOURCED=1
```

Files to update:
1. `scripts/knowledge/lib/staleness.sh` — guard var: `_STALENESS_SOURCED`
2. `scripts/migrate/lib/category-mapper.sh` — guard var: `_CATEGORY_MAPPER_SOURCED`
3. `scripts/migrate/lib/category-inferrer.sh` — guard var: `_CATEGORY_INFERRER_SOURCED`
4. `scripts/migrate/lib/scope-tag.sh` — guard var: `_SCOPE_TAG_SOURCED`
5. `scripts/migrate/lib/supersession-chain.sh` — guard var: `_SUPERSESSION_CHAIN_SOURCED`
6. `scripts/migrate/lib/decision-numbering.sh` — guard var: `_DECISION_NUMBERING_SOURCED`
7. `scripts/migrate/lib/error-handler.sh` — guard var: `_ERROR_HANDLER_SOURCED`

Insert the guard AFTER the shebang and BEFORE any function definitions. For example in `staleness.sh`, insert after line 1 (`#!/usr/bin/env bash`) and before the comment block.

Note: `scripts/knowledge/lib/index-utils.sh` does NOT need a guard — it only defines functions and sets a variable, no side effects.

## What NOT to Fix

These were flagged as LOW and should be left alone:
- Library files missing `set -euo pipefail` — correct behavior, they inherit from the sourcing script
- Subshell variable scoping in `command | while` pipelines — current code is safe because it only does file I/O inside the subshell, not variable assignments that need to propagate

## Verification After Fixes

```bash
cd /Users/brettkellgren/Sites/lakeledger/spec-kit-orchestrator

# 1. Confirm no process substitution redirection remains
! grep -rn 'done < <(' scripts/ && echo "PASS: No process substitution"

# 2. Confirm no sed -i.bak remains
! grep -rn 'sed -i\.bak' scripts/ && echo "PASS: No sed -i.bak"

# 3. Confirm sourcing guards exist
for f in scripts/knowledge/lib/staleness.sh scripts/migrate/lib/category-mapper.sh scripts/migrate/lib/category-inferrer.sh scripts/migrate/lib/scope-tag.sh scripts/migrate/lib/supersession-chain.sh scripts/migrate/lib/decision-numbering.sh scripts/migrate/lib/error-handler.sh; do
  grep -q '_SOURCED' "$f" && echo "PASS: $f has guard" || echo "FAIL: $f missing guard"
done

# 4. Bash 3.2 compat sweep
! grep -rn 'declare -A\|readarray\|mapfile' scripts/ && echo "PASS: No Bash 4+ features"

# 5. Test knowledge scripts still work
export PROJECT_ROOT="$(pwd)"
bash scripts/knowledge/create-entry.sh --id MEM999 --category convention --confidence 0.90 --scope-tags "[project]" --source-unit "test" --description "Audit test" --body "Test body"
bash scripts/knowledge/compute-staleness.sh
bash scripts/knowledge/rebuild-index.sh
bash scripts/diagnostics/run-doctor.sh
rm -f knowledge/convention/MEM999.md
bash scripts/knowledge/rebuild-index.sh
rm -f .specify/orchestrator/doctor-history.jsonl

# 6. Test migration still works end-to-end
TARGET=$(mktemp -d)
bash scripts/migrate/migrate.sh --path /Users/brettkellgren/Sites/lakeledger/.gsd --source gsd2 --output "$TARGET" --force
test -f "$TARGET/MIGRATION-REPORT.md" && echo "PASS: Migration report generated"
rm -rf "$TARGET"

echo "All verification complete."
```

## File Inventory (for reference)

### M002 Scripts (Knowledge Architecture)
```
scripts/knowledge/lib/staleness.sh
scripts/knowledge/lib/index-utils.sh
scripts/knowledge/create-entry.sh
scripts/knowledge/update-entry.sh
scripts/knowledge/supersede-entry.sh
scripts/knowledge/archive-entry.sh
scripts/knowledge/promote-entry.sh
scripts/knowledge/rebuild-index.sh
scripts/knowledge/compute-staleness.sh
scripts/knowledge/detect-overlap.sh
scripts/knowledge/increment-hits.sh
scripts/knowledge/update-confidence.sh
scripts/knowledge/traverse-graph.sh
scripts/knowledge/resolve-entries.sh
scripts/dispatch/scope-filter.sh (modified)
scripts/dispatch/build-context.sh (rewritten)
scripts/dispatch/compress-payload.sh
scripts/dispatch/classify-complexity.sh
scripts/dispatch/select-model.sh
scripts/telemetry/record-telemetry.sh
scripts/telemetry/aggregate-metrics.sh
scripts/lifecycle/record-result.sh (extended)
scripts/diagnostics/run-doctor.sh
scripts/diagnostics/check-orphaned.sh
scripts/diagnostics/check-stale.sh
scripts/diagnostics/check-scope.sh
scripts/diagnostics/check-cost-spikes.sh
commands/doctor.md
templates/routing.yaml
```

### M003 Scripts (Migration Tool)
```
scripts/migrate/adapter-interface.sh (extended)
scripts/migrate/lib/sqlite-reader.sh (extended)
scripts/migrate/lib/json-fallback.sh (extended)
scripts/migrate/lib/detect-source.sh
scripts/migrate/lib/category-mapper.sh
scripts/migrate/lib/category-inferrer.sh
scripts/migrate/lib/scope-tag.sh
scripts/migrate/lib/supersession-chain.sh
scripts/migrate/lib/decision-numbering.sh
scripts/migrate/lib/idempotency.sh
scripts/migrate/lib/error-handler.sh
scripts/migrate/adapters/gsd2.sh
scripts/migrate/adapters/gsd1.sh
scripts/migrate/adapters/speckit.sh
scripts/migrate/transform/knowledge.sh
scripts/migrate/transform/knowledge-index.sh
scripts/migrate/transform/decisions.sh
scripts/migrate/transform/requirements.sh
scripts/migrate/transform/milestone-tiering.sh
scripts/migrate/transform/active-milestone.sh
scripts/migrate/transform/milestone-rollup.sh
scripts/migrate/transform/telemetry-aggregator.sh
scripts/migrate/transform/report.sh
scripts/migrate/migrate.sh (extended)
commands/migrate.md
extension.yml (updated)
```
