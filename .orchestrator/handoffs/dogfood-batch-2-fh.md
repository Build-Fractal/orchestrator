# Handoff — bbt-companion dogfood batch 2, bugs F + H

E and G shipped to `main` (commits `316411e`, `bdcf6fa`). F and H remain.
This file is self-contained — pick up cold without re-reading the original
bug report.

## Branch posture

E and G are already on `main`. Recommend a single new branch
`dogfood-hotfix-fh` for both remaining fixes, two commits, then merge to
main when both green.

## Bug F (P1) — phase summary field-derivation: dedup + roadmap-derived requires/affects

**Symptom (verbatim from bbt-companion P00-SUMMARY.md frontmatter):**

```
requires=T01, T01, T02,T03
affects=T02,T03,T04, T04, T04, P01
```

Two problems, one commit:

1. **Cosmetic dups** in concatenated fields — fix with a `_dedup_csv()` helper
   applied to `provides`, `key_files`, `key_decisions`, `patterns_established`.
2. **Layer violation** — `requires`/`affects` should describe phase-to-phase
   graph position, not internal task IDs. Override the task-summary concat
   for these two fields with roadmap-derived values.

**Files**

- `scripts/lifecycle/phase-transition.sh` — field-derivation block at lines
  139–239. Both `_pt_output` (lines 234–239) and the `write-summary.sh` call
  (lines 267–272) consume the accumulated lists.
- `scripts/state/read-roadmap.sh` — needs a new query `affects <P##>` that
  returns CSV of phase IDs whose `Depends:` contains the argument. Existing
  `phase <P##>` query already returns Depends as the 4th token.

**Suggested implementation sketch**

In `phase-transition.sh`, near the top:

```bash
_dedup_csv() {
  tr ',' '\n' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    | grep -v '^$' \
    | awk '!seen[$0]++' \
    | paste -sd, -
}
```

After the task-summary accumulation loop, before the `_pt_output` block:

```bash
provides_list=$(echo "$provides_list" | _dedup_csv)
key_files_list=$(echo "$key_files_list" | _dedup_csv)
key_decisions_list=$(echo "$key_decisions_list" | _dedup_csv)
patterns_list=$(echo "$patterns_list" | _dedup_csv)

# requires = this phase's Depends: from the roadmap (graph position, not task IDs).
phase_line=$(bash "$READ_ROADMAP" "$ROADMAP_FILE" phase "$PHASE_ID" 2>/dev/null || true)
requires_list=$(echo "$phase_line" | awk '{print $4}')
[[ -z "$requires_list" || "$requires_list" = "none" ]] && requires_list="none"

# affects = phases whose Depends: contains this phase.
affects_list=$(bash "$READ_ROADMAP" "$ROADMAP_FILE" affects "$PHASE_ID" 2>/dev/null || echo "none")
```

Need to verify `$READ_ROADMAP` and `$ROADMAP_FILE` are already in scope —
check the existing script. If not, derive them at the top.

In `read-roadmap.sh`, add to the `case "$QUERY"` block:

```bash
affects)
  if [[ -z "$QUERY_ARG" ]]; then
    echo "read-roadmap.sh: 'affects' query requires a phase ID argument" >&2; exit 1
  fi
  result=$(parse_phases | awk -v p="$QUERY_ARG" '
    {
      n = split($4, deps, ",")
      for (i=1;i<=n;i++) if (deps[i]==p) { print $1; next }
    }' | paste -sd, -)
  echo "${result:-none}"
  ;;
```

Also add `affects` to the valid-queries list in the error case at line 302
and to the docstring comment at lines 6–13.

**Tests** — new `tests/test-phase-transition-frontmatter.sh`. Pattern after
`tests/test-roadmap-dep-safety.sh` (committed in `316411e`):

1. Build a small fixture milestone with a roadmap where P00 has `Depends:
   none`, and P01/P03/P06 each declare `Depends: P00, ...`. Hand-write task
   summaries under `phases/P00/tasks/` with intentionally-duplicated
   `provides:` and `affects:` fields. Run `phase-transition.sh M999 P00`
   and assert the emitted output / written summary frontmatter has:
   - `requires=none` (P00 has no upstream deps)
   - `affects=P01,P03,P06` (roadmap-derived, alphabetical or roadmap-order)
   - `provides=` (deduped — no doubled tokens)
2. Negative: fixture where the phase Depends on `P02, P03` — assert
   `requires=P02,P03`.
3. Regression: re-run any existing M001/M002 phase-transition test if one
   exists. Search: `grep -l phase-transition tests/`.

**Read-roadmap regression**: tests/test-s02-state-machine.sh (29 checks)
exercises `read-roadmap.sh`. Adding the `affects` query is additive and
shouldn't break existing behavior. Run after the change.

## Bug H (P2) — task plan filename convention drift

**Symptom:** `orchestrator-plan-phase` skill writes task plans as
`T##-<slug>.md`, but `scripts/util/check-plan-exists.sh:30` globs
`T*-PLAN.md`. The two never meet → `check-plan-exists.sh` reports
`task_plans=0` despite N files present.

**Decision (per original bug report):** rename planner output to
`T##-<slug>-PLAN.md`. Sibling-symmetry with `T##-<slug>-PAYLOAD.md` makes
the relationship readable on `ls`. Don't loosen the check-plan-exists glob.

**Files to update**

Start with broad discovery — this rename has the widest blast radius of
the four bugs and grep-hunting eats context fast:

```bash
grep -rln "T##-<slug>" /Users/brettkellgren/Sites/spec-kit-orchestrator/skills /Users/brettkellgren/Sites/spec-kit-orchestrator/commands /Users/brettkellgren/Sites/spec-kit-orchestrator/templates /Users/brettkellgren/Sites/spec-kit-orchestrator/scripts /Users/brettkellgren/Sites/spec-kit-orchestrator/references
grep -rln "T##" /Users/brettkellgren/Sites/spec-kit-orchestrator/skills/orchestrator-plan-phase /Users/brettkellgren/Sites/spec-kit-orchestrator/commands/plan-phase.md
grep -rln "tasks/T" /Users/brettkellgren/Sites/spec-kit-orchestrator/scripts /Users/brettkellgren/Sites/spec-kit-orchestrator/skills
```

Likely-affected paths (verify each):

- `skills/orchestrator-plan-phase/SKILL.md` (or sibling files) — the planner
  output convention
- `commands/plan-phase.md` — the agent instructions for plan-phase
- `templates/` — any task-plan template that hardcodes the filename
- `scripts/dispatch/build-context.sh` — `TASK_PAYLOAD` mode reads task plans
- `scripts/lifecycle/auto-loop.sh:252` — already reads `${TASK}-PLAN.md`;
  no change if `--task=T##-<slug>` is passed in full. Confirm callers.
- `scripts/util/check-plan-exists.sh:30` — already globs `T*-PLAN.md`. No
  change.

**Migration posture**

Don't auto-rename historical `T##-<slug>.md` files in completed milestones.
Those phases are done; the count doesn't gate anything for them. New
milestones from this point forward use the new convention. Add a one-line
note to `CHANGELOG.md`.

**Tests**

1. New fixture under `tests/fixtures/check-plan-exists-rename/`: a phase
   directory with three `T##-<slug>-PLAN.md` files. Assert
   `check-plan-exists.sh` returns `PLAN_EXISTS task_plans=3`.
2. Update or extend any existing test that hardcodes the old filename
   convention (find via `grep -rln "T01-PLAN\|T01-.*\.md" tests/`).
3. End-to-end smoke: scaffold a throwaway Tier C milestone, dispatch the
   planner, verify the emitted files match `T*-PLAN.md` and
   `check-plan-exists.sh` reports the correct count.

## Sequencing

F first, H second — F changes phase-summary output format and may surface
issues consolidate-artifacts cares about; H is filename-only and won't
interact. Both are independently revertable.

## Pre-merge verification

- New tests green
- `tests/test-s02-state-machine.sh` (29 checks)
- `tests/test-s05-autonomous-mode.sh` (100 checks)
- `tests/test-s08-auto-safety.sh` (35 checks)
- Manual: scaffold throwaway milestone, dispatch planner, run
  phase-transition on a hand-built phase, inspect summary frontmatter for
  dedup'd lists and roadmap-derived requires/affects

## Context the new session won't have

- E and G are already shipped (commits `316411e`, `bdcf6fa` on main).
  bbt-companion is unblocked at the active-phase level and the verifier
  level. The remaining bugs are quality-of-output, not gate-correctness.
- The `dogfood-hotfix-efgh` branch is gone; everything is on main.
- The user's preference (from session that handed this off): one branch,
  one commit per bug, no destructive operations without confirmation.
