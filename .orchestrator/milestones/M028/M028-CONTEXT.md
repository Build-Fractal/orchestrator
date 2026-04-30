---
schema_version: "1.0"
type: context-draft
milestone: "M028"
status: finalized
created_at: "2026-04-29T00:00:00Z"
finalized_at: "2026-04-29T00:00:00Z"
---

## Architectural Decisions

Decisions ratified at the discussion gate before roadmap generation. Most are already pinned in `specs/031-autonomous-hardening-v3/spec.md` (CON-1 through CON-10, FR-1 through FR-22, pre-resolved Q-1 through Q-4); this section records the operator-ratified shape so the planner does not second-guess.

- **Phase shape**: P01 (empirical baseline) → P02 (hook portability + adapter+installer dedup, Findings A + F folded) → P03 (classifier extension, AP-010 through AP-014) → P04 (investigation-pattern wrappers) → P05 (cross-project verifier suite + downstream fixture). Five phases, P01 load-bearing for the collapse decision.
- **Sibling fold non-negotiable**: Findings A and F ship together in P02. The planner has no authority to split them. Splitting creates the integration gap explicitly enumerated in the spec's Non-Goals (`Splitting findings A and F into separate phases`): bare names pointing at runtime-stable paths, or hook portability without lifecycle scripts. Verification only closes when both ship in the same PR.
- **Collapse condition mechanics — Option (a) replan-after-P01**: Planner authors all 5 phases up front. P01 ships; its baseline output is consumed by the next planning pass. If P01 evidence shows Finding A alone resolves 6 of 7 screenshots, the planner enters `replanning` state, marks P02–P05 stale, and rewrites them into PR-1 (hook portability) + PR-2 (the one outlier as a corpus entry + classifier rule). If P01 evidence does not support collapse, P02–P05 stay as-planned. Rationale: matches the spec's wording ("planning agent rewrites P02–P05") and the orchestrator's existing `replanning` state machine path; preserves Tier C roadmap-level visibility from day one.
- **Hook runtime-stable location**: `~/.claude/orchestrator-hooks/` (CON-9). Stability contract: future installer versions may add files but must never move the dir, even if a competing convention emerges (e.g., CC plugin packaging at `~/.claude/plugins/orchestrator/hooks/`).
- **Self-conformance hard-gate from day one**: The shape-guard hook lints clean against its own classifier (AP-009 / no compound chain > 2). FR-21 verifier blocks merge. Not a soft warning — the hook is small enough to author under the constraint, and any allowance for "soft now, hard later" defeats Principle II's evidence-before-claims posture for the autonomy claim.
- **`--repair` ergonomics extension**: FR-7's `install-claude-code.sh --repair` gains a `--dry-run` mode that emits the diff (orphan entries it would remove, plus user-authored entries it would preserve) without mutating `~/.claude/settings.json`. Mirrors how `install-roundtrip.sh` exposes its own state for audit; honors operator's direct M018-close hand-cleanup experience. Spec's Edge Cases already pin the exact-tuple-match safety floor; `--dry-run` is preview-only ergonomics on top of that floor.
- **bash 3.2 / POSIX sh per-task carry**: CON-2 applies to every M028-shipped script. The planner explicitly includes the constraint in each task acceptance criterion for any task that authors or modifies a `.sh` file under `scripts/`, `packaging/`, or `tests/`, so subagent dispatch payloads inherit it into fresh-context dispatch. Without per-task carry, fresh contexts lose the constraint.
- **Knowledge-layer boundary with M025**: M028 owns AP-010 through AP-014, the new classifier branches, the new wrappers, the new fixtures, the runtime-stable hooks dir, and the `--repair` flag. M028 consumes (does not modify) M025's `_orchestrator_managed: true` tag semantics, the `settings-merge.sh` uninstall cascade convention, and the `install-claude-code.sh` install-vs-uninstall contract. Spec section "Knowledge-Layer Boundary (M028 vs. M025)" is the canonical reference; planner respects it verbatim.
- **AP-014 body-descent recursion bound**: One level deep only (CON-5 + Edge Cases). Classifier counts top-level connectors plus in-body connectors inside `sh -c '<body>'`; deeper nesting (`sh -c '… sh -c '<inner>' …'`) is treated as opaque. Avoids pathological recursion; covers the observed shape from Finding G's screenshot.

## Scope Boundaries

**In scope** (ratified):
- Findings A, B, C, D, E, F, G — all seven from the 2026-04-25 → 2026-04-28 sweep.
- Five new antipatterns: AP-010 `cmd-sub-in-pattern`, AP-011 `quoted-arg-newline-hash`, AP-012 `multiline-quoted-script`, AP-013 `unquoted-brace-glob`, AP-014 `xargs-sh-c-compound-body`.
- Four new investigation-pattern wrappers under `scripts/util/`: `grep-files.sh`, `cleanup-stale-results.sh`, `node-eval.sh`, `peek-files.sh`.
- Permanent in-tree downstream-consumer fixture at `tests/fixtures/downstream-project/`.
- Per-finding verifier suite under `scripts/verify/m028/`.
- Installer extension: copy lifecycle scripts into runtime-stable hooks dir; install-side dedup; `--repair` flag with `--dry-run` preview.
- Runtime adapter fix: emit absolute `bash <hooks-dir>/<name>.sh` invocations carrying `_orchestrator_managed: true`.

**Out of scope** (ratified per spec's Non-Goals + extensions):
- Re-opening M021's matrix (AP-001 through AP-009 stay immutable).
- Generalizing destructive-op handling beyond `rm`-shaped cleanup. Other destructive verbs (`gh pr close`, force-push, `npm publish`) remain CC-policy-gated; no orchestrator-side wrappers for them in M028.
- Universal investigation skill. Four wrappers + one Investigation Patterns section is enough; future shapes get added under M028's pattern when they reappear.
- Changing Claude Code's "don't ask again" rule UI surface (CC product surface, not orchestrator).
- Multi-runtime parity audit for hook portability (M009 territory; deferred post-launch).
- Re-numbering AP-IDs (AP-009 is the last current entry; AP-010 → AP-014 are stable references from corpus comments, hook reject_lookup, and screenshot annotations).
- Splitting Findings A and F into separate phases (see Architectural Decisions).
- Concurrent-install file-locking (Edge Cases acknowledges race; banner warns; full lock is a future hardening pass).

## Design Constraints

- **CON-1 (single-script-file)**: Every M028 verifier, wrapper, and lifecycle script is a flat single-file shape. No nested helper dirs under `scripts/verify/m028/` or `scripts/util/`. Helpers source from existing concern dirs only (`scripts/dispatch/`, `scripts/state/`, `scripts/util/`).
- **CON-2 (bash 3.2 + POSIX sh)**: All M028 scripts run on bash 3.2 (macOS default-shell compatibility) and POSIX sh where invoked from `/bin/sh`. No bash 4+ associative arrays, no `mapfile` / `readarray`, no unguarded `<<<` here-strings. Per-task acceptance carry (see Architectural Decisions).
- **CON-3 (shape-guard self-conformance)**: `pre-bash-shape-guard.sh` body contains no compound chain exceeding 2 connectors. Hook conforms to its own classifier output. Hard-gated by FR-21 from day one.
- **CON-4 (M025 reversibility)**: Install → install → uninstall byte-equality. Pinned-sha round-trip gate (SC-2) is the canonical-bytes proof. Extends M025/P01's reversibility pattern to M028's expanded entry set without redefining the M025 contract.
- **CON-5 (AP-014 body-descent depth)**: Classifier descends one level into `sh -c '<body>'` for connector counting. Combined count = top-level connectors + in-body connectors; reject when > 2. Deeper nesting is opaque.
- **CON-6 (no new runtime deps)**: M028 introduces no new runtime dependencies. Hook + classifier remain pure bash + standard macOS/Linux tools (`grep`, `sed`, `awk`).
- **CON-7 (no M021 regression)**: M028 classifier is a strict superset of M021's. SC-8 gates this; FR-22 enforces. All 21 M021 corpus entries produce identical verdicts under M028.
- **CON-8 (single corpus)**: `tests/fixtures/m021-prompt-corpus.txt` is appended-to, never split. File is regression data, not milestone-scoped (file name keeps M021 prefix per pre-resolved decision).
- **CON-9 (hook location stability)**: `~/.claude/orchestrator-hooks/` is the runtime-stable contract. Future installer versions may add files but must never move the dir.
- **CON-10 (downstream fixture permanence)**: `tests/fixtures/downstream-project/` is permanent in-tree (not generated at test time). Harness fails noisily if the fixture's `.claude/settings.json` schema falls out of sync with the runtime adapter.

## Open Questions

Two genuinely deferred to plan-phase per spec; everything else is pre-resolved.

- **#Q-5 (constitution-principle numerals)**: Spec's Constitution Check section cites principles by best-effort numeral (Principle II, III, VI, VII, IX, XIV, XV). Planning agent confirms exact numerals against `.orchestrator/memory/constitution.md` and updates the spec's Constitution Check accordingly. **Owner**: gsd-planner / orchestrator:plan-phase. Mechanical; low-risk.

- **#Q-6 (P01 empirical verdict for collapse)**: The collapse decision (Finding A alone resolves 6 of 7 → collapse to 2 PRs) is gated on P01's actual replay output, not on estimation. **Mechanism (per Architectural Decisions option-a above)**: planner authors all 5 phases; P01 ships; planner consumes P01 evidence; if collapse-supported, planner enters `replanning`, marks P02–P05 stale, and rewrites into PR-1 + PR-2. If collapse-not-supported, P02–P05 stay as-planned. **Owner**: P01 verifier output → orchestrator:plan-phase replanning pass (or no-op if not collapse-supported).

- **No additional questions surfaced at the discussion gate** — the spec's pre-resolution of Q-1 through Q-4 + the discussion-gate ratification of phase shape, sibling fold, collapse mechanics, hook location, self-conformance, and `--repair` `--dry-run` covers the operator-input surface. The remaining work is mechanical planning.
