# Handoff: M005 P07 planned, `read-roadmap.sh` parser blocks state derivation

**Date**: 2026-04-11
**Working directory**: `/Users/brettkellgren/Sites/lakeledger/orchestrator`
**Branch**: `main` (clean before the P07 plan files were added)

## TL;DR

The previous session planned M005 P07 (Autonomy Permission Generator) — a complete phase plan plus five zero-context task plans are on disk under `.specify/orchestrator/milestones/M005/phases/P07/`. But `bash scripts/state/derive-phase.sh .specify/orchestrator/milestones/M005` still reports `planning` instead of `executing`, because `scripts/state/read-roadmap.sh` has a parser bug that fires on the M005 roadmap's extended `Depends:` text and propagates `set -e` failure. This is a pre-existing bug, not a P07 issue. Fix the parser first, then confirm state derivation recovers, then decide dispatch order.

## What the previous session delivered

Files written under `.specify/orchestrator/milestones/M005/phases/P07/`:

| File | Lines | Purpose |
|------|-------|---------|
| `P07-PLAN.md` | 227 | Phase plan: frontmatter, 30+ truths, 17 artifacts, 10 key links, task decomposition, files-likely-touched |
| `tasks/T01-PLAN.md` | 525 | Autonomy defaults YAML + config schema + 5 verify helpers |
| `tasks/T02-PLAN.md` | 606 | `generate-permissions.sh` + detect-capabilities host markers |
| `tasks/T03-PLAN.md` | 601 | `write-permissions.sh` + `check-permissions.sh` |
| `tasks/T04-PLAN.md` | 379 | `auto.md` pre-flight rewrite + `evaluate.md` init + Known Limitations |
| `tasks/T05-PLAN.md` | 416 | `plan-phase.md` + templates + `installation.md` (parallel track) |

Each task plan embeds exact file paths, verbatim code for shader-like files (autonomy-defaults.yaml), interface specs for the scripts, and upstream API surface summaries so a fresh agent can execute each task with zero additional reading.

**Task dependency graph inside P07:**
```
T01 ─┬─→ T02 → T03 → T04
     └─→ T05   (parallel)
```

**Why P07 and not the auto-selected first phase:** all five M005 independent phases (P01, P02, P03, P04, P07) were eligible, but the last five commits on `main` were all P07 context prep (AD-19 expansion, AD-20/AD-21 baseline allow patterns, harness safety heuristic docs). Planning P07 while that context is fresh in the planner's mind was the right call. The remaining phases (P01/P02/P03/P04) can be planned later without losing ground.

## The parser bug

### Symptom

```bash
$ bash scripts/state/read-roadmap.sh .specify/orchestrator/milestones/M005/M005-ROADMAP.md active-phase; echo "exit=$?"
exit=1
```

Silent exit 1, no output. This cascades: `derive-phase.sh` swallows the failure (`|| true`), `active_phase` becomes empty, Rules 3b/5/6/7 all skip, and the derivation falls through to the final `planning` echo (line 202 of `derive-phase.sh`).

### Root cause

Two issues stacked together in `scripts/state/read-roadmap.sh`:

**1. Depends-line parser does not handle extended commentary.** In `parse_phases()` around line 134:

```bash
# Depends line
if echo "$line" | grep -qiE '^[[:space:]]+-?[[:space:]]*Depends:'; then
  local deps
  deps=$(echo "$line" | sed 's/.*Depends:[[:space:]]*//' | sed 's/[[:space:]]*$//')
  if [[ "$deps" != "none" && -n "$deps" ]]; then
    phase_depends="$deps"
  fi
fi
```

M005's roadmap has two phases with extended `Depends:` text:

- **P03**: `Depends: none (operates on M004 P05 refactored scripts)`
- **P07**: `Depends: none within M005 (parallel track — independent of M005 P01-P04). Cross-milestone: consumes M004 P02 (errors.sh, events.sh) and M004 P04 (recipe-parser.sh) — cannot start until both are committed.`

The parser captures the whole trailing text verbatim. Since `deps != "none"`, `phase_depends` gets set to the full commentary.

**2. `active-phase` dependency loop crashes on no-match grep under `pipefail`.** In the `active-phase` case around line 236:

```bash
IFS=',' read -ra dep_list <<< "$pdepends"
for dep in "${dep_list[@]}"; do
  dep=$(echo "$dep" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
  dep_status=$(echo "$phases_data" | grep "^${dep} " | awk '{print $2}')
  if [[ "$dep_status" != "complete" ]]; then
    deps_satisfied=false
    break
  fi
done
```

The file has `set -euo pipefail` at the top. When `pdepends` is `"none (operates on M004 P05 refactored scripts)"`, comma-split yields a single entry with parentheses. `grep "^none (operates... "` finds no match, returns exit 1, and with `pipefail` the whole `echo | grep | awk` subshell exits non-zero — which `set -e` catches and terminates the script without ever reaching the `deps_satisfied=false` fallback. Hence exit 1 with no output.

### Proposed fix (belt + suspenders)

Make two small, defensive changes in `scripts/state/read-roadmap.sh`:

**Change 1** — strip parenthesized commentary from the `Depends:` line during parsing. Around line 134:

```bash
# Depends line
if echo "$line" | grep -qiE '^[[:space:]]+-?[[:space:]]*Depends:'; then
  local deps
  # Strip leading "Depends:", then any parenthesized commentary, then whitespace.
  # This lets roadmap authors write "Depends: none (operates on M004 P05)" or
  # "Depends: P01, P02 (hash utility)" without confusing the parser.
  deps=$(echo "$line" \
    | sed 's/.*Depends:[[:space:]]*//' \
    | sed 's/([^)]*)//g' \
    | sed 's/\.[[:space:]].*//' \
    | sed 's/[[:space:]]*$//' \
    | sed 's/[[:space:]]*,[[:space:]]*/,/g')
  if [[ "$deps" != "none" && -n "$deps" ]]; then
    phase_depends="$deps"
  fi
fi
```

The three extra `sed` expressions:
- `s/([^)]*)//g` — remove `(...)` parenthesized commentary.
- `s/\.[[:space:]].*//` — truncate at the first `. ` sentence boundary (handles P07's multi-sentence Depends text like `... independent of M005 P01-P04). Cross-milestone: consumes M004 P02 ...`).
- `s/[[:space:]]*,[[:space:]]*/,/g` — normalize spacing around commas so later consumers get clean tokens.

**Change 2** — make the dep-status grep tolerant of no-match so `set -e + pipefail` don't abort the whole script. Around line 237:

```bash
dep_status=$(echo "$phases_data" | grep "^${dep} " | awk '{print $2}' 2>/dev/null || true)
```

The `|| true` is the load-bearing part — it lets the subshell succeed even when `grep` finds nothing. Also defend against malformed `dep` tokens (empty string, non-`P##` pattern):

```bash
if [[ -z "$dep" || ! "$dep" =~ ^P[0-9] ]]; then
  continue
fi
```

Add the skip above the `dep_status=` line inside the `for dep in ... do` loop.

### Verification

After patching, these commands should all succeed:

```bash
# 1. active-phase returns a phase ID instead of exit 1
bash scripts/state/read-roadmap.sh .specify/orchestrator/milestones/M005/M005-ROADMAP.md active-phase
# Expected: P01 (highest-priority incomplete phase with satisfied deps)

# 2. phases query still works
bash scripts/state/read-roadmap.sh .specify/orchestrator/milestones/M005/M005-ROADMAP.md phases
# Expected: 7 lines, one per phase

# 3. derive-phase reports executing (because P07 has a plan + 5 task plans without summaries)
# Wait — this one needs more thought. See "Important wrinkle" below.
bash scripts/state/derive-phase.sh .specify/orchestrator/milestones/M005
```

### Important wrinkle: active-phase selection semantics vs. what was actually planned

The `read-roadmap.sh active-phase` logic picks "highest-risk incomplete phase with satisfied deps" — that's P01 (medium risk, no deps, first encountered). But the session planned **P07** because the human context was all P07 prep. After the parser fix:

- `active-phase` will return `P01` (per current semantics).
- `derive-phase.sh` checks the active phase's plan/task/summary files. P01 has no plan yet → Rule 3b returns `planning`.
- The planned P07 phase is on disk but *not* what the state machine treats as active.

So **fixing the parser alone does not flip the milestone state to `executing`**. The state machine is working as designed — it just can't tell that P07 was planned out-of-order.

Two follow-up options:

**Option A — plan P01 next so the state machine catches up in order.** Run `speckit.orchestrator.plan-phase --phase P01` (or P02, P03, P04) one at a time. Once every M005 leaf phase has a plan, `active-phase` will advance to P05 (which depends on P01+P02) and the state machine stays coherent. This is the most "correct" path but delays P07 execution.

**Option B — dispatch P07 directly via explicit phase/task args**, bypassing `active-phase`. `speckit.orchestrator.dispatch` accepts phase/task arguments (see `commands/dispatch.md`); the auto loop does not — auto mode strictly follows active-phase ordering. P07 tasks are ready for guided dispatch even though auto mode won't pick them.

**Option C — extend `active-phase` to prefer a phase that already has a plan**, so the state machine picks up work the human manually planned ahead. This is a semantic change with broader implications — do not take it on unopinionated; think about whether it changes autonomous mode's notion of "next phase" in ways other callers don't expect. Recommend NOT doing this in the parser fix; file it as a design question for later.

**Recommendation: Option B for P07 execution via guided dispatch, Option A in parallel to keep the milestone's auto-mode story clean.** The P07 task plans are self-contained enough that guided dispatch (one task at a time) works fine; P01–P04 plans can be written at leisure.

## First actions for the fresh agent

1. **Read this handoff file** (you're doing that now).
2. **Read `scripts/state/read-roadmap.sh` in full** to confirm the bug details match. The fix is a ~6-line change in `parse_phases` + `active-phase`.
3. **Patch the parser** using the two changes above. Do **not** skip to "just add `|| true`" — both changes are needed. The parenthesized-commentary strip is the real fix; the `|| true` is defensive.
4. **Run the verification commands** from the Verification subsection above.
5. **Read the "Important wrinkle" section** and pick Option B (guided dispatch for P07 — recommended) or Option A (plan P01 first). Confirm with the user before taking on Option A — it's extra work not explicitly requested.
6. **If Option B**: report back to the user. The user will invoke `speckit.orchestrator.dispatch --phase P07 --task T01` or equivalent. Do **not** auto-dispatch without user confirmation — the previous session stopped at "plans are ready" and explicitly deferred execution.
7. **Commit the parser fix as its own commit.** This is a standalone bugfix and should not be bundled with P07 execution commits. Suggested message:
   ```
   fix(state): read-roadmap.sh parser tolerates extended Depends: commentary

   parse_phases now strips parenthesized commentary and truncates at sentence
   boundaries, and the active-phase dep-status lookup no longer aborts on
   pipefail when grep finds no match. Root-caused from M005 planning session
   where read-roadmap.sh active-phase exited 1 on phases with extended
   dependency descriptions (P03: "none (operates on M004 P05 refactored scripts)",
   P07: "none within M005 (parallel track — ...)").

   Parser change is forward-compatible with existing simple deps ("P01",
   "P01, P02") — the additional seds are no-ops when no parens are present.
   ```

## Critical context not on disk

These are facts the previous session learned but that aren't in any committed file:

- **AD-19 is the load-bearing decision for P07.** It establishes that Claude Code's bash permission system has two layers: the allow list (configurable via settings.json, what P07's generator targets) and the safety heuristic layer (unconfigurable, fires on command shape). P07's generator cannot eliminate the second layer — the remedy is upstream in how task plan `Check:` commands are authored. T05 of P07 locks this convention into `commands/plan-phase.md` and both templates.
- **AD-20 and AD-21 were added to M005-CONTEXT.md in commit `0b71181`** as the direct result of M004/P02–P05 verification failures. System-temp paths (`/tmp/**`, `/var/folders/**`) and `ORCH_*=*` env-prefix patterns must be in the baseline allow list or every dry-run test prompts. The P07 plan encodes both as mandatory baseline in `templates/autonomy-defaults.yaml`.
- **AD-10 forbids GSD runtime patterns.** `Skill(gsd:*)` and `.gsd/` detection are explicitly out of scope. The P07 plan includes a `scripts/verify/p07-no-gsd.sh` check that fails if any GSD marker leaks into the generator. Do not add GSD detection "for completeness" — it would be a regression.
- **M004 P02 delivered `scripts/lib/errors.sh` + `scripts/lib/events.sh`** and M004 P04 delivered `scripts/lib/recipe-parser.sh`. Both are already committed on `main`. P07 scripts source all three. Per AD-14, P07 reuses `recipe-parser.sh` for `autonomy-defaults.yaml` rather than writing a narrower parser.
- **The `.claude/settings.json` in this repo is orchestrator-generated** (has `_generated_by: speckit-orchestrator` marker). Running `generate-permissions.sh | write-permissions.sh` against this repo overwrites it — intentional. Back up with `cp .claude/settings.json /tmp/p07-backup.json` first if you want to preserve the exact bytes for comparison.

## File layout after the parser fix

Nothing else on disk will change from this handoff's actions. The parser fix is a single-file edit. P07 plan files remain exactly as the previous session wrote them:

```
.specify/orchestrator/milestones/M005/phases/P07/
├── P07-PLAN.md
└── tasks/
    ├── T01-PLAN.md
    ├── T02-PLAN.md
    ├── T03-PLAN.md
    ├── T04-PLAN.md
    └── T05-PLAN.md
```

## If anything is ambiguous

Read `.specify/orchestrator/milestones/M005/M005-CONTEXT.md` (architectural decisions) and `.specify/orchestrator/milestones/M005/M005-ROADMAP.md` (phase boundaries) for the full M005 picture. The P07 task plans themselves are zero-context and self-sufficient — you do not need to re-read the context draft to execute them.
