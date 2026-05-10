---
schema_version: "1.0"
type: context-draft
milestone: "M014"
status: finalized
created_at: "2026-04-22T15:50:38Z"
finalized_at: "2026-04-22T16:16:34Z"
---

## Architectural Decisions

- **AD-1 Phase shape pinned by spec Phase Sequencing table** — spec-layer commits to four phases (P1 US-2+minimal US-4, P2 full US-4+FR-13 drift, P3 US-1+US-5 comment classifier, P4 US-3 conversus auto-propose). Planning may extend columns but may not contract. P3 gated on M013/P04 closure (met).
- **AD-2 `orchestrator:specify` treats spec-kit `spec-template.md` as I/O contract, not verbatim port** — FR-2 Section Contract is the authority; template-literal fidelity is not required. Rationale: [M015](../../milestones/M015/index.md) already removed the spec-kit toolchain; re-introducing template files would re-open the standalone-cutover seam.
- **AD-3 CC-first v1 for `orchestrator:specify`; Codex/Cursor parity is fast-follow via M009 runtime-parity audit** — inherits M013/FR-12 stance (Constitution X+XII). Dual-write `AGENTS.md` surface (US-4) ships CC→Codex written projection, not a separate Codex-native authoring path.
- **AD-4 Comment classifier consumes [M012](../../milestones/M012/index.md) wiki-giscus-remap + [M013](../../milestones/M013/index.md) UAT ingestion path as read surfaces** — no new comment-fetch infrastructure. Wiki comments routed through Giscus Discussion API via `gh api`; GitHub Issue/PR comments via `gh api repos/.../comments`. Hard reuse of existing surfaces (Constitution XIV).
- **AD-5 Spec-amendment is always human-gated** — FR/US for spec mutation routes to `.orchestrator/comments/review-queue/` with approve/reject commands. Never auto-applied even at max confidence (Constitution XV).
- **AD-6 Conversus auto-propose is prompt-only, not auto-execute** — FR-5 complexity probe emits a structured signal, FR-6 offers a y/n/d three-way prompt ("run now / skip / decompose-first"); the user always owns the decision to invoke `/conversus run`.
- **AD-7 FR-6 prompt is `y/n/d` three-way, not binary+flag** — decomposition is a first-class path exposed directly at the prompt, not hidden behind `--decompose-first`. Rationale: faithful restatement of US-3 AS-2 (spec.md:104) and conversus synthesis (`conversus/summary/final.md` P1 #1); the auto-propose moment is exactly when the user doesn't yet know whether the spec is decomposition-worthy, so burying the path costs discoverability at the friction point. Matches the M013 conversus preset block/pass/escalate arbitration vocabulary.
- **AD-8 `orchestrator:specify` is scoped to create-path only for M014; clarify/plan/tasks are non-goals for M014 and revisit-gated on post-M014 dogfood** — closes the P5 seam for the current milestone without foreclosing the future. Rationale: Constitution XIV (No Speculative Complexity) — clarify-loop value is unproven without dogfood data from native specify; adding it would inflate P1 beyond its load-bearing scaffold role. **[M024](../../milestones/M024/index.md) collision flag for planner**: M024 Universal Intake (D016) already covers "empty + Q&A" as an input shape; P-authors must map the M014↔M024 boundary before any clarify-adjacent work is re-scoped into M014. If dogfood of the first few orchestrator-authored specs surfaces clarify demand, the answer is either a follow-up milestone or re-scoping into M024 — not a retrofit P5 of M014.

## Scope Boundaries

**In scope**:

- Native `orchestrator:specify --description --slug [--force]` create-path (FR-2, FR-3, FR-4) + `spec-shape-lint.sh` verifier.
- `AGENTS.md` dual-write at every current `CLAUDE.md` write-site: `orchestrator:init`, `orchestrator:consolidate`, knowledge-update recent-changes appends, `orchestrator:specify` recent-changes write.
- `orchestrator:doctor runtime_instruction_drift` detector (FR-13) covering the dual-write invariant.
- Complexity probe (FR-5) + conversus-suggestion prompt (FR-6) + `templates/conversus-presets/spec-pressure-test.yml` preset.
- `orchestrator:comments classify|status|apply|reject|triage|reclassify` with four classes: `uat-bug`, `decision-append`, `spec-amendment`, `triage`.
- Idempotency via `.orchestrator/comments/actioned.jsonl` (mirror of M013/FR-4 marker invariant).
- Review queue at `.orchestrator/comments/review-queue/<comment-id>.md` for non-trivial actions.

**Out of scope**:

- Bi-directional spec↔GitHub sync beyond the narrow UAT-read-back M013 owns.
- Spec versioning beyond git.
- Standalone spec linting/validation command (defer to [M020](../../milestones/M020/index.md)).
- Auto-apply on any spec-amendment classification (human-gated always).
- Codex-native `orchestrator:specify` (fast-follow via M009).
- Backfill of hand-authored specs into `orchestrator:specify` shape — forward-only, next spec (M020 or M024) is first dogfood.
- Clarify/plan/tasks native commands (still shelled out to spec-kit equivalents if needed; M014 ships only `specify`).

## Design Constraints

- **DC-1 Constitution compliance** — X (Single-Hands-On Runtime; CC-first), XII (Bounded External Dep; conversus via M011/P07 adapter only), XIV (No Speculative Complexity; dogfood-data sizes classifier scope), XV (Surgical Precision; human-gated spec mutation).
- **DC-2 Bash 3.2 / macOS compat** — MEM001 compat scan gates all new scripts. No associative arrays, no `${var,,}` case expansion, no `mapfile`.
- **DC-3 M011/P07 conversus adapter is the only integration point** — no direct `/conversus` CLI calls; all invocation via `scripts/dispatch/adapters/tool/conversus.sh --strict` with CONVERSUS_STUB contract honored.
- **DC-4 `AGENTS.md` dual-write uses marker-bounded region** — mirrors M013/FR-4 byte-identity marker pattern; idempotent updates; `git diff` shows exact write-site.
- **DC-5 Phase P3 external dependency** — consumes `scripts/integrations/github-common.sh` (12+helpers) and UAT comment surface from M013/P04 (closed 2026-04-22). No new GitHub infra.
- **DC-6 `RUNTIME-ASSUMPTIONS.md` registry write** — every CC-only assumption introduced by this milestone must land a registry entry for M009 consumption (e.g., `orchestrator:specify` shells to `claude` CLI for clarify loop if that's the design).

## Open Questions

- **OQ-1 FR-5 complexity probe signal set** — which signals trigger auto-propose of conversus pressure-test? Candidates: spec LOC > N, FR count > N, acceptance-scenario count > N, cross-milestone dependency count > N, "contradicts"/"but"/"however" cue-word density, scope-bleed indicators (out-of-scope section shorter than in-scope by 3×). Need a threshold table with defensible defaults + override knobs. **Answerable by: planning (reading M013 spec + this spec as calibration corpus).**
- **OQ-2 FR-9 classifier class boundary** — confidence thresholds for auto-apply (`uat-bug`, `decision-append`) vs review queue (all others). What signal defines confidence? Regex-match specificity? Multi-class disambiguation via conversus? Dogfood-data (M012/M013 comment backlog) is the sizing input per AD/spec note — **answerable by: planning P3 kickoff after backlog snapshot**.
- **OQ-3 Dual-write backfill scope** — spec says forward-only. Should `orchestrator:doctor` offer a one-shot `--backfill-agents-md` repair when drift is detected against historical surfaces? **Answerable by: planning P2 (cheap addition if the drift detector has already parsed the write-sites).**
- **OQ-4 P3 defect-surface sizing for conversus ambiguous-comment triage** — expected volume of ambiguous comments per week? If <5, synchronous triage is fine; if >50, need batch mode. **Answerable by: planning P3 (measure actual M012/M013 backlog).** **Precondition flagged**: M012 wiki first-deploy is still pending (see [`.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md`](../../milestones/M012/phases/P04/DEPLOY-RECORD.md) — `deployed_url: pending`, all four gates `skip`). P3 cannot dogfood until wiki is live; roadmap must treat M012 first-deploy as a P3 prerequisite.
- **OQ-5 Dual-write shape (spec #C-5)** — `AGENTS.md`'s marker-bounded region: byte-identical to `CLAUDE.md`, or semantically equivalent via a documented transform (e.g., `Claude Code` → `Codex CLI` in the runtime-identification header mentioned at spec.md:143)? The spec explicitly defers this to planning (spec.md:138, SC-6 at spec.md:247, Open Question #C-5 at spec.md:404). **Discussion must not pre-close this.** Planning decides after examining whether the runtime-identification header would be incorrect-by-construction under a mirror. FR-13 drift-detector implementation follows the decision (trivial `diff` if mirror; transform-aware comparison if not).

_Resolved during discussion (promoted to AD-7, AD-8 — revised after independent red-team review). Per red-team finding: spec Open Question #C-5 is planning-owned and cannot be resolved in discuss; former AD-9 restored as OQ-5 above._

## Planning Inputs (gathered during discussion)

### FR-5 Complexity Probe — Calibration Corpus (strawman, confirmed 2026-04-22)

Retrospective conversus-would-have-fired labels on past milestone specs. This is a strawman calibration input for planning P4 (FR-5 probe threshold selection). Planning must treat these as empirical anchors, not authoritative — re-tune as dogfood data accumulates.

| spec | milestone | label | rationale anchor |
|------|-----------|-------|------------------|
| 011 | [M011](../../milestones/M011/index.md) | yes | D007 surfaced reusable-adapter architecture pattern mid-P07; pre-discuss conversus would have caught the abstraction at design-time. |
| 015 | M015 | no | Spec sound, execution matched scope. D003 was minor config cleanup, not scope correction. |
| 016 | [M016](../../milestones/M016/index.md) | yes | D012 evidence: M016 closed Class A prompt triggers but left ~12 Class B residuals requiring [M021](../../milestones/M021/index.md) insertion. Spec missed the adequacy question. |
| 021 | M021 | yes | Built reactively to close M016's residuals (D012). Would have benefited from pre-discuss review of M016's shell-heuristic adequacy. |
| 022 | M012 | no | All 4 phases shipped as specified. D011/D013 M020 promotion was mechanical evaluation, not scope correction. |
| 019 | [M019](../../milestones/M019/index.md) Tier 1 | borderline | Spec sound; D009 Tier 1 positioning post-M011 cost ~15–25 unlogged records — intentional tradeoff, not late correction. |
| 023 | M013 | yes (anchor) | Red-blue conversus fired pre-discuss, caught FR-12 runtime stance + FR-9 knowledge-layer boundary (D014). |
| 024 | M014 | yes (anchor) | Tier 1 cooperative fired, surfaced 14 MITs (D017). |

**Candidate probe signals** (ranked by agent findings):

1. **Post-merge binding-decision volume** (strongest signal) — count of DECISIONS.md D-rows targeting the spec's milestone with scope-narrowing or architecture-reframing verdicts. M011/M016/M021 all had ≥1 such D-row post-merge.
2. **FR-per-story ratio + cross-milestone integration flag** (compound signal) — M011 had FR/story=3.2 AND cross-milestone integration (spec-ingest wired into M013/M014 gates). Threshold candidate: FR/story > 3 AND integration-flag = true.
3. **Hardening-spec special criterion** — hardening specs (M016, M021) carry zero FRs. For these, signal is "residual defect discovery in prior auto-mode runs" (e.g., Class B pattern screenshot count).
4. **Weak signals (use only as tiebreakers)** — raw line count, raw user-story count, raw FR count. M015 (196 LOC, 19 FR, 5 US) shipped clean; M011 (162 LOC, 16 FR, 5 US) needed conversus. Size alone doesn't discriminate.

Planner action: pin initial thresholds at plan-phase P4, emit them as structured fields in the probe output so they're re-tunable without code changes.

### M012 Wiki Deploy Posture — Parallel During P1/P2 (confirmed 2026-04-22)

M012 first-deploy (`DEPLOY-RECORD.md` at `.orchestrator/milestones/M012/phases/P04/`) is pending operator completion — 5-step checklist requires human credentials (`GISCUS_*` env, `gh-pages` push rights, test-comment round-trip). Deploy posture for M014:

- **M014 P1 and P2 execute independently of wiki deploy** — `orchestrator:specify` create-path and `AGENTS.md` dual-write have no wiki dependency. P1/P2 can ship without blocking on deploy.
- **M012 deploy runs in parallel with P1/P2** — operator (user) completes the 5-step checklist during the P1/P2 window; target-complete-by: P3 kickoff.
- **P3 precondition enforced at dispatch time** — when P3 first-task dispatches, roadmap must pre-flight-check `DEPLOY-RECORD.md` has all `pending` sentinels replaced. If sentinels remain, P3 blocks with a clear error pointing at the checklist. No silent proceed on stubbed backlog.

Roadmap action: encode the P3 `deploy-record-complete` pre-flight as an explicit phase-entry gate with a link to [`.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md`](../../milestones/M012/phases/P04/DEPLOY-RECORD.md) lines 71–91.
