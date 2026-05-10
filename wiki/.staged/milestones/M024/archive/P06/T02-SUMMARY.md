---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P06"
milestone: "M024"
provides:
  - "scripts/intake/revise.sh (full re-emit revision driver with version-suffix archive + FR-14 idempotency); scripts/intake/proposal-emit.sh --axes-from <file> flag + REVISE_AXES_DONE rationale-skip branch + revise_* override namespace; scripts/verify/m024-p06-revise-script.sh; scripts/verify/m024-p06-axes-from-flag.sh"
requires:
  - "P06/T01 (scripts/intake/axis-rederive.sh — invoked once per operator override to build the --axes-from payload); P01 (templates/intake-proposal.md, scripts/intake/proposal-emit.sh, scripts/intake/intake-id-allocate.sh); P03 (closed-enum axis names from approval-gate.sh — same enum reused)"
affects:
  - "P06/T03 (approval-gate.sh revise verb wiring will call scripts/intake/revise.sh and emit revised_to=<path>); P06/T04 (write-confinement + suite scripts will assert SB-3 for revise.sh + the new --axes-from path); P07 (design_gate axis revisions land via the same revise.sh path once P07 deep classifier ships)"
key_files:
  - "scripts/intake/revise.sh, scripts/intake/proposal-emit.sh, scripts/verify/m024-p06-revise-script.sh, scripts/verify/m024-p06-axes-from-flag.sh"
key_decisions:
  - "Revise-namespace override precedence: --axes-from values land in scope_tier_revise / decomposition_revise / etc. and are applied AFTER paragraph + spec deep classifiers, so operator revisions beat deep-classifier output (the original payload sketch wrote into <axis>_override and was overwritten by the paragraph branch — this rename fixes that)"
  - "Stable-intake-id preservation (#Q-6) implemented inside revise.sh: the emitter's id-allocator counter-allocates a fresh <NNN>-slug because the original directory is non-empty, so revise.sh moves the emitted proposal back to the original PROPOSAL path and prunes the empty sibling dir — keeps intake_id stable across revisions without modifying id-allocate.sh"
  - "FR-14 idempotency check uses a tmp marker file (mktemp + grep DIFF) instead of a subshell variable to survive the bash 3.2 here-doc loop scope; emit revised=false reason=identical-axes and exit 0 without archiving"
  - "Body re-derivation reads from the CURRENT proposal BEFORE archiving (extracts ## Original Input first line, ## Q&A answers via awk, feature_slug → specs/<slug>/spec.md) so the archive→re-emit path can replay the original input contract"
  - "Proposal-emit failure recovery: if the emitter fails, mv proposal-v<N>.md back to proposal.md so the operator's state is not corrupted (FR-12 contract — never half-revised)"
patterns_established:
  - "Revise-namespace + apply-last pattern for axes-from operator overrides (operator-driven > deep-classifier > P01 stub precedence)"
  - "Stable-id preservation via emit-then-relocate (intake_id stays sticky across revisions even though id-allocate is counter-driven)"
  - "Tmp-marker file pattern for boolean signaling out of bash 3.2 here-doc loop scopes (subshell variable assignment lost otherwise)"
  - "Pre-archive body extraction (read ## Original Input + ## Q&A from the live proposal BEFORE mv → archive_path so awk can scan the original)"
  - "Archive-restore-on-emit-failure pattern (mv archive back to proposal.md before exit 1 — protects operator state)"
drill_down_paths:
  - ".orchestrator/milestones/M024/phases/P06/tasks/T02-PAYLOAD.md, .orchestrator/milestones/M024/phases/P06/tasks/T02-PLAN.md"
duration: "12m"
verification_result: "pass"
completed_at: "2026-04-25T04:20:00Z"
---

## Summary

T02 ships the user-facing revision driver `scripts/intake/revise.sh` plus the `--axes-from <file>` extension to `scripts/intake/proposal-emit.sh` they compose with. Together they implement FR-12 (full re-emit on operator revision, version-suffix archive of the prior proposal) and FR-14 (idempotent no-op when overrides match current values). Both T02-owned verify scripts pass; all P01–P05 suites still pass after the proposal-emit edit.

## What was built

- **`scripts/intake/revise.sh`** (new, executable) — accepts `--proposal <path>` plus one or more `--axis <name> --value <value>` pairs (repeatable). Steps:
  1. Validates axis names against the FR-12 closed enum (`scope_tier | decomposition | design_gate | conversus_gate | intensity`); rejects `input_shape` with exit 2 (structural change requires fresh `orchestrator:evaluate`).
  2. Reads current frontmatter values; if every override is byte-identical, emits `revised=false reason=identical-axes` and exits 0 without archiving (FR-14).
  3. Emits a stderr `WARN:` if the proposal was already approved (operator approval will be reset).
  4. For each operator override, invokes `scripts/intake/axis-rederive.sh` to compute dependent-axis recomputations; appends the rederive lines to a tmp `axes-from` file FIRST.
  5. Appends operator overrides to the same tmp file SECOND so operator overrides win on conflict.
  6. Allocates the next free `proposal-v<N>.md` suffix by scanning the proposal's directory (max existing N + 1, default N=1).
  7. Re-derives emitter inputs from the CURRENT proposal BEFORE archiving (`## Original Input` first line, `## Q&A` answers via awk, `feature_slug` → spec path).
  8. Archives the current `proposal.md` to `proposal-v<N>.md`.
  9. Invokes `proposal-emit.sh --axes-from <tmp> [--input | --spec-path | --qa-answers-from] --intake-root <parent>`.
  10. If the emitter lands at a sibling dir (id-allocate counter-allocated a fresh slug because the original dir was non-empty), moves the new proposal back to the original `PROPOSAL` path and prunes the empty sibling — keeps intake_id stable across revisions per #Q-6.
  11. Post-processes the new proposal: `sed -i.bak` replaces the placeholder rationale (`Operator revision via revise.sh — see prior version for original rationale.`) and the placeholder evidence (`see proposal-v<N>.md (revise.sh post-processes this slot)`) with version-pointer text citing the actual `proposal-v<N>.md` archive.
  12. Cleans up tmp files and emits `revised_to=<path>` to stdout.
  - Failure recovery: if the emitter fails, moves `proposal-v<N>.md` back to `proposal.md` so the operator's state is not corrupted; forwards the emitter's stderr.

- **`scripts/intake/proposal-emit.sh`** (modified) — three coordinated edits:
  - **Argument parser**: new `--axes-from <file>` flag (alongside existing `--qa-answers-from`).
  - **Axes-from parser block** (top of script after arg-parse): reads one `key=value` per line; ignores `#` comments and blanks; rejects unknown keys with exit 2 + actionable error naming the supported set; populates a `revise_*` namespace (e.g., `scope_tier_revise`); builds `REVISE_AXES_KEYS` newline-list of axes touched; sets `REVISE_AXES_DONE=1`.
  - **Revise override application** (after paragraph + spec deep classifiers): `[ -n "${scope_tier_revise:-}" ] && scope_tier="$scope_tier_revise"` for all six axes — operator revisions beat deep-classifier output.
  - **Rationale loop**: new `REVISE_AXES_DONE` branch — for each axis whose key appeared in the axes-from file, swap `rationale_<axis>` to a placeholder and `evidence_<axis>` to a `proposal-v<N>.md` reference placeholder; `revise.sh` post-processes both placeholders to version-pointer text after the emitter returns.

- **`scripts/verify/m024-p06-revise-script.sh`** (new, executable) — end-to-end revision flow:
  - Generates a Tier-B paragraph proposal.
  - Revises `scope_tier=B → C`; asserts `revised_to=` stdout, dependent axes rederived (`decomposition=milestone-with-phases`, `recommended_command=orchestrator:specify`), approval state reset (`pending_approval: true`, `approved_at: null`, `cancelled_at: null`), and `proposal-v1.md` archive carries the prior `scope_tier: "B"`.
  - Asserts FR-14 idempotency: revising with the same `scope_tier=C` emits `revised=false reason=identical-axes` and produces no `proposal-v2.md`.
  - Asserts `input_shape` revision is rejected (exit non-zero).
  - Asserts unknown axis names are rejected (exit non-zero).

- **`scripts/verify/m024-p06-axes-from-flag.sh`** (new, executable) — `--axes-from` flag isolation:
  - Builds an axes-from file with `scope_tier=C` + `decomposition=milestone-with-phases` + `recommended_command=orchestrator:specify` + `intensity=Full`; asserts every override appears in the rendered proposal.
  - Asserts the `REVISE_AXES_DONE` rationale placeholder is present on overridden axes.
  - Asserts unknown keys are rejected (exit non-zero).
  - Asserts comments and blank lines are ignored.

## Key decisions

- **Revise-namespace + apply-last precedence** — the original payload sketch wrote axes-from values into the existing `<axis>_override` shell vars, but the paragraph and spec deep classifiers also write into `_override` and run AFTER the axes-from parser, silently overwriting operator revisions. Renaming the axes-from sink to a `_revise` namespace and applying it AFTER the deep classifiers fixes this without restructuring proposal-emit's classifier order.

- **Stable-id preservation inside revise.sh** — `intake-id-allocate.sh` counter-allocates the next free `<NNN>-slug` whenever the parent directory is non-empty, which it always is after archiving `proposal.md` to `proposal-v<N>.md`. Rather than introducing a new `--intake-id` flag to the emitter (schema change — D024 / MEM031 schema authority handshake), revise.sh detects the post-emit dir mismatch, mv's the new proposal back to the original path, and rmdir's the empty sibling. Intake_id is sticky across revisions per #Q-6.

- **Tmp-marker file for FR-14 diff signaling** — the natural `while read; do ...; done <<EOF ... EOF` pattern is a subshell in bash 3.2 (here-doc redirection forks), so a `diff_found=1` assignment inside the loop is lost on exit. Using `echo DIFF >> "$diff_marker"` + `grep -q DIFF` survives the subshell boundary and is bash-3.2 portable.

- **Pre-archive body extraction** — re-emit needs the original input + Q&A transcript, but archiving moves the file out of the well-known `proposal.md` path. revise.sh extracts `## Original Input` (first non-empty line) and `## Q&A` (each `### Q<N>` answer) BEFORE the `mv` so the awk reads land on the live proposal.

- **Archive-restore-on-emit-failure** — if `proposal-emit.sh` exits non-zero, revise.sh `mv "$archive_path" "$PROPOSAL"` first, then exits 1. The operator never sees a half-revised state where `proposal.md` is gone but no new content landed.

## Files changed

- `scripts/intake/revise.sh` — created (executable).
- `scripts/intake/proposal-emit.sh` — modified: `--axes-from` flag in arg parser, axes-from parser block populating `revise_*` namespace + `REVISE_AXES_KEYS`, revise-override application after deep classifiers, rationale-loop `REVISE_AXES_DONE` branch.
- `scripts/verify/m024-p06-revise-script.sh` — created (executable).
- `scripts/verify/m024-p06-axes-from-flag.sh` — created (executable).

## Verification

T02-owned verify commands (both PASS):

- `bash scripts/verify/m024-p06-revise-script.sh` — `PASS: revise.sh — archives v1, re-emits with overrides + rederives, resets approval, idempotent on no-op`
- `bash scripts/verify/m024-p06-axes-from-flag.sh` — `PASS: --axes-from flag applies overrides + REVISE_AXES_DONE rationale skip; unknown keys rejected`

Sibling-task regression check (all PASS — proposal-emit edit did not break any P01–P05 suite):

- `bash scripts/verify/m024-p01-suite.sh` — PASS (proposal-shape + manifest-superset).
- `bash scripts/verify/m024-p02-suite.sh` — PASS (backcompat + manifest-read + fixture-vs-live + rationale + confinement).
- `bash scripts/verify/m024-p03-suite.sh` — PASS (paragraph + approval-gate + route + evaluate-md).
- `bash scripts/verify/m024-p04-suite.sh` — PASS (fast-path + config + condition-violation + write-confinement).
- `bash scripts/verify/m024-p05-suite.sh` — 9/9 verifies green.

T01-owned verify (still PASS — no axis-rederive.sh edits):

- `bash scripts/verify/m024-p06-axis-rederive.sh` — PASS.

## Concerns

None. The two T02-owned must-haves and Check commands pass; the sibling-must-haves listed in the broader phase scope (`m024-p06-version-suffix.sh`, `m024-p06-approval-gate-revise-wired.sh`, `m024-p06-rederive-rationale.sh`, `m024-p06-write-confinement.sh`, `m024-p06-evaluate-md.sh`, `m024-p06-suite.sh`) are owned by T03 / T04 per the phase decomposition — T02's payload Check block lists only the two scripts shipped here.
