---
type: paper-cut
status: open
created: 2026-05-01
source: M031 dogfood — observed `.orchestrar/M031/post-dispatch-result.txt` orphan artifact created at 12:43:31 during M031/P00/T03 auto-loop run
investigate-by: post-launch hardening sweep, or fold into next M028-style autonomous-hardening tail
---

# Paper-Cut: `auto-loop.sh --output-file` template substitution is fragile

## Symptom

`.orchestrar/M031/post-dispatch-result.txt` (note typo'd `.orchestrar`, missing `to`) appeared as an untracked artifact during an M031 auto run. Contents: `AUTO:RECORDED milestone=M031 phase=P00 task=T03`. The canonical `.orchestrator/milestones/M031/post-dispatch-result.txt` was correctly written for subsequent tasks, so the agent self-corrected — but the orphan directory persisted.

## Root cause

`commands/auto.md:260` documents the post-dispatch invocation as:

```bash
bash scripts/lifecycle/auto-loop.sh <milestone-dir> --step=G --task=T## ... --output-file=<milestone-dir>/post-dispatch-result.txt
```

`<milestone-dir>` appears **twice** — once as the positional first arg, once embedded in the `--output-file=` value. The agent must substitute the same path in both places. The M031 agent at 12:43 substituted them inconsistently — the positional arg landed at `.orchestrator/milestones/M031/`, but the `--output-file` value was typo'd to `.orchestrar/M031/post-dispatch-result.txt`.

`auto-loop.sh:148` runs `mkdir -p "$(dirname "$OUTPUT_FILE")"` with no validation against `MILESTONE_DIR`, so it happily creates the typo'd directory. Sibling `commands/auto.md:263` then reads from the same typo'd path (because the agent uses the same wrong substitution), so the wrong-path read succeeds and the loop continues without surfacing an error.

The typo `orchestrator` → `orchestrar` is exactly the substring `to` removed (`orchesTRATOR` → `orchesTRAR`) — a plausible single-character LLM substitution slip.

## Bug class

**Same-value substituted twice in a documented template** is a known fragility. Any caller (LLM or human) typing the path in two places can drift. The script has all the information needed to derive `--output-file` from `MILESTONE_DIR` itself, eliminating the duplication.

Related family: `papercut-milestone-dir-routing.md` (M030 dogfood — agent inferred wrong `<milestone-dir>` from spec slug). Same theme: milestone-dir path drift between caller and writer.

## Fix shape

**Option 1 — Default `--output-file` from `MILESTONE_DIR`** (preferred):

In `auto-loop.sh` after arg parsing:

```bash
[[ -z "$OUTPUT_FILE" ]] && OUTPUT_FILE="$MILESTONE_DIR/post-dispatch-result.txt"
```

Update `commands/auto.md:260` to drop the `--output-file=...` flag from the documented invocation. Single substitution point, typo class eliminated.

**Caveat**: callers without `--output-file` today get stdout output (per `_auto_output` else-branch). Defaulting `OUTPUT_FILE` would silently flip those callers to file-output. Mitigate by making the default opt-in via a separate `--default-output-file` flag, OR by auditing existing call sites for stdout dependence (likely none — `--output-file` exists *because* command substitution trips harness safety heuristics).

**Option 2 — Path-prefix validation**:

```bash
if [[ -n "$OUTPUT_FILE" ]] && [[ "$OUTPUT_FILE" != "$MILESTONE_DIR"/* ]]; then
  echo "auto-loop.sh: --output-file ($OUTPUT_FILE) must be under MILESTONE_DIR ($MILESTONE_DIR)" >&2
  exit 1
fi
```

Catches the typo with a loud failure instead of silent corruption. Pure addition — won't break correctly-behaving callers. Safe to land mid-flight (next typo'd run rejects loudly; correctly-typed runs pass through unchanged). Lower-impact than Option 1 but easier to ship.

## Cleanup

The orphan `.orchestrar/M031/` directory is harmless — the canonical execution-log already records T03, and `post-dispatch-result.txt` is overwritten on each call (`>` not `>>` in `auto-loop.sh:149`). `rm -rf .orchestrar/` restores clean state. Already cleaned 2026-05-01 during paper-cut investigation.

## Why deferred

The M031 auto agent was mid-flight (verifying T04) when this paper-cut surfaced. Modifying `auto-loop.sh` or `commands/auto.md` while the agent reads them on its next iteration could trigger an untested edge case. The orphan directory is benign; the fix is small but better landed during a calm window or as part of the next autonomous-hardening sweep.
