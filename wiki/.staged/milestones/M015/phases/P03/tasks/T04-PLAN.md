---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M015"
name: "Tighten ALLOW_P03_DOCS allow-list and run full P03 verify suite"
depends_on: [T03]
---

## Prerequisites

- T03 is complete. Five of six P03 verify scripts PASS. The 13 wider docs are swept clean of legacy path references. `docs/migrating-from-speckit.md` exists. `scripts/verify/m015-p02-no-stale-state-refs.sh` is untouched — its `ALLOW_P03_DOCS` regex still holds the full 17-token baseline even though the docs in that allow-list no longer need the tolerance.
- T02 is complete. Primary docs reframed, CHANGELOG.md has the M015 entry.
- T01 is complete. All six P03 verify scripts and the snapshot helper exist.
- The only remaining P03 verify script that still FAILs is `m015-p03-allow-list-tightened.sh`.

## Description

Finalize P03 by pruning the `ALLOW_P03_DOCS` regex in `scripts/verify/m015-p02-no-stale-state-refs.sh` down to the minimum justifiable subset — ideally empty. After T02 and T03, every file listed in the allow-list has been swept clean of legacy references, so the allow-list is dead weight. Reducing it to empty tightens the P02 sweep's gate: any future accidental reintroduction of `.specify/orchestrator/` in any of these files will now surface as a real FAIL instead of being silently tolerated.

If some files cannot be safely pruned (e.g., a file T03 missed, a file where the sweep introduced intentional historical-callout content referencing `.specify/orchestrator/`), keep those specific files in the allow-list and document why in an inline comment above the regex.

This task also runs the full P03 verification suite end-to-end and runs the P02 sweep to confirm no regression. If any FAIL emerges, surface it — do not suppress it.

## Steps

1. Inspect the current `ALLOW_P03_DOCS` regex in `scripts/verify/m015-p02-no-stale-state-refs.sh`. Read the file; note the line with `ALLOW_P03_DOCS=` and its 17 pipe-separated tokens.

2. For each token in `ALLOW_P03_DOCS`, run a targeted grep to confirm the file has zero remaining legacy references:

   ```
   for f in README.md CLAUDE.md references/architecture.md references/installation.md references/constitution-walkthrough.md references/engine.md references/events.md references/errors.md references/recipes.md references/file-formats.md references/state-machine.md references/tier-definitions.md docs/getting-started.md docs/knowledge-management.md docs/hook-development.md docs/recipe-authoring.md scripts/AGENTS.md; do
     echo "--- $f ---"
     grep -c -E '\.specify/orchestrator|\.specify/memory/constitution' "$f"
   done
   ```

   (Run this as a plain terminal command — NOT as a verify script.)

   Expected: every file shows `0`. If any file shows `> 0`, either T02 or T03 missed an occurrence — fix it in-place before proceeding.

3. Update `scripts/verify/m015-p02-no-stale-state-refs.sh`: reduce `ALLOW_P03_DOCS` to empty. The preferred representation is a sentinel that can never match any file path:

   Change the line from:
   ```
   ALLOW_P03_DOCS='README\.md|CLAUDE\.md|references/architecture\.md|references/installation\.md|references/constitution-walkthrough\.md|references/engine\.md|references/events\.md|references/errors\.md|references/recipes\.md|references/file-formats\.md|references/state-machine\.md|references/tier-definitions\.md|docs/getting-started\.md|docs/knowledge-management\.md|docs/hook-development\.md|docs/recipe-authoring\.md|scripts/AGENTS\.md'
   ```

   To:
   ```
   # P03 complete (M015): all previously tolerated docs swept clean of
   # legacy .specify/orchestrator and .specify/memory/constitution
   # references. Allow-list is empty — any re-introduction of a legacy
   # path in these files will now correctly FAIL this sweep.
   ALLOW_P03_DOCS='__P03_COMPLETE_NEVER_MATCH__'
   ```

   The sentinel `__P03_COMPLETE_NEVER_MATCH__` is guaranteed to never appear as a real file path (leading and trailing underscores, uppercase, path-token-invalid), so the `grep -Ev "^\./($ALLOW_P03_DOCS)$"` negation in the sweep script remains syntactically valid but matches nothing — effectively disabling the allow-list.

   Update the "ALLOW_P03_DOCS: reframed by P03 (tolerated here)" comment block at the top of the file to note that P03 is complete and the allow-list is sealed.

4. Parse-check the modified script:

   ```
   bash -n scripts/verify/m015-p02-no-stale-state-refs.sh
   ```

   Must exit 0.

5. Run the P02 sweep to confirm the modification did not break anything:

   ```
   bash scripts/verify/m015-p02-no-stale-state-refs.sh
   ```

   Must exit 0 with `PASS: no stale state-path references in non-exempt runtime files`. If it FAILs, either (a) a file T02/T03 was supposed to sweep still has a legacy reference — fix it; or (b) a runtime file outside the P03-reserved set has a new legacy reference — investigate whether it was just introduced by T02/T03 accidentally, fix it.

6. Run the allow-list-tightened verifier:

   ```
   bash scripts/verify/m015-p03-allow-list-tightened.sh
   ```

   Must exit 0 with `PASS: ALLOW_P03_DOCS reduced to 1 token(s)` (the sentinel counts as one token; the verifier as written in T01 accepts any token count < 17).

   Alternatively, if you truly pruned to empty body `ALLOW_P03_DOCS=''`, the verifier will output `PASS: ALLOW_P03_DOCS is empty`. Either form is acceptable.

7. Run the full P03 verify suite one more time:

   ```
   bash scripts/verify/m015-p03-standalone-framing.sh
   bash scripts/verify/m015-p03-no-legacy-install.sh
   bash scripts/verify/m015-p03-changelog-has-m015.sh
   bash scripts/verify/m015-p03-migration-doc.sh
   bash scripts/verify/m015-p03-wider-docs-sweep.sh
   bash scripts/verify/m015-p03-allow-list-tightened.sh
   ```

   All six must exit 0 with `PASS:`.

8. Run the P02 verify suite to confirm P02's gates still hold after P03's doc work:

   ```
   bash scripts/verify/m015-p02-state-tree-migrated.sh
   bash scripts/verify/m015-p02-constitution-moved.sh
   bash scripts/verify/m015-p02-resolver-no-bridge.sh
   bash scripts/verify/m015-p02-resolver-resolves-new.sh
   bash scripts/verify/m015-p02-no-stale-state-refs.sh
   bash scripts/verify/m015-p02-doctor-clean.sh
   ```

   All six must still PASS. (They should — P03 did not touch state, resolver, or migration adapters.)

9. Run the phase-level must-haves check:

   ```
   bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M015/phases/P03
   ```

   Expect all truths (6), all artifacts (8), and all key links (2) to PASS. Total: 16/16 PASS.

10. If step 9 FAILs on an artifact check (e.g., "CHANGELOG.md (min 300 lines, contains 'M015')"), inspect the specific failure and fix. Likely cause: line-count threshold not met (CHANGELOG.md may be under 300 lines if T02's M015 entry is compact). Adjust either the entry or the artifact threshold — if adjusting the threshold, do it in the P03-PLAN.md (not retroactively — note it as a documented plan adjustment in the T04 summary).

## Must-Haves

This task addresses:

- Truth 6 (allow-list-tightened): `ALLOW_P03_DOCS` in `m015-p02-no-stale-state-refs.sh` reduced to empty or minimal.

It also ratifies the phase-level completeness by running the full P03 verify suite end-to-end.

## Verification

```
bash scripts/verify/m015-p02-no-stale-state-refs.sh
bash scripts/verify/m015-p03-standalone-framing.sh
bash scripts/verify/m015-p03-no-legacy-install.sh
bash scripts/verify/m015-p03-changelog-has-m015.sh
bash scripts/verify/m015-p03-migration-doc.sh
bash scripts/verify/m015-p03-wider-docs-sweep.sh
bash scripts/verify/m015-p03-allow-list-tightened.sh
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M015/phases/P03
```

All eight must exit 0 with PASS output. Additionally, the six P02 verify scripts must still PASS (regression check).

## Inputs

- `scripts/verify/m015-p02-no-stale-state-refs.sh` — the file being modified. The `ALLOW_P03_DOCS` line is the surgical edit target.
- All 13 wider docs plus the 5 primary docs (18 total) — read-only check that they have zero legacy references before tightening the allow-list.
- `scripts/verify/check-must-haves.sh` — the phase-level gate. Its behavior: reads the P03-PLAN.md must-haves section, runs each truth Check, tests each artifact's existence/line-count/pattern, tests each key-link's source-to-target reference.

## Constraints

- ONLY modify `scripts/verify/m015-p02-no-stale-state-refs.sh`. No other file edits in this task.
- Do NOT weaken the P02 sweep by broadening `ALLOW_MIGRATION` or `ALLOW_SELF_REFERENCE`. Those regexes are load-bearing in a different way and are out of P03's scope.
- Do NOT modify any P02 verify script's logic beyond the single `ALLOW_P03_DOCS=` line and its comment block.
- Do NOT modify files under `.orchestrator/` (historical artifacts).
- If the full-suite check reveals a missed legacy reference in a wider doc, fix the wider doc — do NOT add it back to `ALLOW_P03_DOCS`. The allow-list is a P02 tolerance mechanism; P03's job is to make it unnecessary.
- Single-script-file shape applies to any re-verification runs. All commands in this plan are plain `bash <script>` invocations.
- Path literalism (MEM023).

## Expected Output

After T04 completes:

1. `scripts/verify/m015-p02-no-stale-state-refs.sh` has a reduced `ALLOW_P03_DOCS` line — either empty body or the sentinel `__P03_COMPLETE_NEVER_MATCH__`. Comment block updated to note P03 completion.
2. All six P03 verify scripts PASS.
3. `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M015/phases/P03` reports all truths, artifacts, and key-links PASS.
4. All six P02 verify scripts still PASS (no regression).
5. The phase is ready for mark-complete / summary.
