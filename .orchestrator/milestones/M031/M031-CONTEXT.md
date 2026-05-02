---
schema_version: "1.0"
type: context-draft
milestone: "M031"
status: finalized
created_at: "2026-05-01"
finalized_at: "2026-05-01"
---

## Architectural Decisions

The four architectural decisions Red conceded during the adversarial gate are baseline-locked for M031 and not relitigated here. They are listed first so subsequent decisions can reference them without re-deriving.

**AD-1. Traversal aggressiveness IS the knowledge-scaling dial.** Quick / Standard / Full are distinguished by how aggressively the dispatch payload traverses the knowledge graph (1-hop / 2-hop / full provenance), NOT by whether knowledge ships. Knowledge + M018 compression are unconditional across every dispatch path produced by M031. Reasoning: this resolves the payload-byte vs. total-task-token conflation that motivated the milestone (Constitution Principle I).

**AD-2. M024 is the single routing source.** The universal entry consumes the existing M024 input-shape classifier. M031 extends M024 by adding a `tier_a_plus` verdict value (an additive change to the verdict set, not a new field on existing records). M031 MUST NOT introduce a parallel routing implementation. (Spec CON-3.)

**AD-3. Tier A+ is three sequential dispatches with no new orchestration surface.** The middle flow is implemented as `dispatch --role=research` → `dispatch --role=plan` → `dispatch --role=build`, recorded as JSONL `unit_close` records. No new state machine, no lock file, no roadmap surface. (Spec CON-4 + Principle XIV.)

**AD-4. CON-5 empirical gate is the constitutional safeguard.** The FR-1/2/3 changes (knowledge-unconditional in Quick) MUST NOT merge until the P00 empirical baseline confirms the Quick-with-knowledge-wins hypothesis on a 20-task fixture corpus. Principle II (Evidence Before Claims) is operationalized as a merge blocker, not a process exhortation.

The M031 phase shape is **5 phases** (P00 empirical baseline + P01 knowledge-unconditional + P02 Tier A+ middle flow + P03 universal entry + P04 drift fix + observability), with P00 gating P01 merge per AD-4. The proposal originally suggested 4 phases; the gate's deferred mitigations (sidecar interface, deterministic output paths, FIXTURE-PROVENANCE.md, CORPUS-MANIFEST.md, budget-regression SC, doctor compound-change comms) push verification surface area enough to justify a dedicated P00 + a slightly broader P04. Final phase count is `orchestrator:roadmap`'s call; 5 is the planning starting point.

**AD-5. Quick-profile knowledge token budget default = 800 tokens; P00 may revise.** The proposal recommended 800. P00's 20-task corpus produces the empirical evidence; if P00 data shows 800 is too tight (more than 20% of corpus tasks hit the budget ceiling and snip aggressively) or too loose (median injection is far below 800), P00 amends the default before P01 ships. Knob name: `quick_knowledge_token_budget`. Knob is an advisory ceiling enforced by M018 tier-2 snip — not a hard cap.

**AD-6. Universal entry surface = `orchestrator <task>` if the runtime supports verbless invocation, else `orchestrator:do <task>`.** Detection happens at install time via the runtime adapter's invocation-style capability flag. Claude Code at launch ships `orchestrator:do <task>` (CC slash-commands are verb-prefixed). Codex CLI / Cursor surfaces are M009's call when those runtimes ship; M031 reserves `orchestrator <task>` as the canonical post-runtime-parity form.

**AD-7. Tier A+ approval flow = one prompt before plan dispatch; `--yes` skips.** The research dispatch fires immediately. Operator sees the research findings file path in an approval prompt before plan dispatch fires. After plan, build runs without an additional prompt. Reasoning: medium tasks deserve a sanity check (research findings can be wrong); small Tier A tasks do not (the universal-entry fast-path skips all prompts for high-confidence Tier A degenerate verdicts per FR-12). Composes with M033's onboarding UX trajectory — first-time users see one prompt, not three.

**AD-8. `auto_proceed` default flips from `false` to `true`** per FR-16. Existing projects with explicit `auto_proceed: false` keep the explicit value (A-4). Implicit-default operators see the new behavior on first post-M031 dispatch. AD-8 + AD-9 (compound-change comms) ship together.

**AD-9. Compound-change communication uses `orchestrator:doctor`** (resolves Q-4 / MIT-11). On first run after M031 against a project whose `.orchestrator/config.yml` predates M031 (detectable by absence of `quick_knowledge_token_budget`), `orchestrator:doctor` emits a one-time message naming both behavioral changes (auto-proceed flip + unconditional Quick injection) plus the recovery path (add `auto_proceed: false` to config). The CHANGELOG entry for M031 names the compound effect, not just the flip. Reasoning: the compound change has a single root cause (M031's central design decisions); communicating them together is more useful than two separate notes.

**AD-10. Tier A+ output paths are deterministic** (resolves MIT-03 / RISK-03 + RISK-09 + RISK-11). Path convention: `.orchestrator/tier-a-plus/<task-slug>/research.md` and `.../plan.md`. `<task-slug>` derivation: first 40 characters of the task description, lower-cased, spaces → hyphens, non-alphanumeric-non-hyphen stripped, with a 4-character truncated SHA-1 of the full task description appended on collision. FR-9's approval prompt MUST display the research findings path AND check for an existing `research.md` to offer resume-vs-rerun. Resolves three risks (RISK-03 cosmetic-prompt, RISK-09 concurrent-flow correctness, RISK-11 session-interruption recovery) in one amendment.

**AD-11. `build-context.sh` exposes a `--meta-out <file>` JSON sidecar** (resolves MIT-04 / RISK-04). Minimum schema: `{mem_count, total_tokens, profile, compression_applied, snip_applied}`. FR-12's universal-entry stderr summary line reads N (mem_count) and X (total_tokens) from the sidecar. M029 (`orchestrator:where`) and M036 (reference-corpus ingest) consume the same sidecar without reinventing the interface. The sidecar is the cross-milestone interface contract; specifying it at M031 is the right boundary.

**AD-12. SC-13 redesigns as a git-history check (Option B)** (resolves MIT-02 / RISK-02). New verifier `tests/m031-acceptance/verify-baseline-ordering.sh` asserts that the first commit touching `tests/m031-acceptance/fixtures/empirical-baseline/` predates the first commit touching any of the four FR-1/2/3-related test scripts. If the battery environment cannot access git history at run time (e.g., shallow clone), Option A fallback applies (reclassify SC-13 as a P00 protocol note, drop from SC-14's count, reduce N≥13 → N≥12). Plan-phase P00 picks the active option based on observed CI environment. Reasoning: Option B preserves CON-5's mechanical enforcement; Option A is the honest fallback when mechanism is impossible.

**AD-13. SC-2 amendment grounds enforcement in M018 tier-2 snip** (resolves MIT-01 / RISK-01). Drop the contradictory "within ±20%" clause. New SC-2: a Quick-profile dispatch fixture configured with `compression.tier2.enabled: true` produces (a) a tier-2 snip JSONL record at the budget boundary AND (b) a final Knowledge section ≤ `quick_knowledge_token_budget`. Reasoning: FR-5 already declares the budget an "advisory ceiling" enforced by tier-2; SC-2 must match.

**AD-14. SC-11 explicitly reads stored records from `fixtures/empirical-baseline/`** (resolves MIT-05 / THREAT-001). After FR-4 merges the skip branch is gone; live dual-execution is impossible. The pre-M031 stub is preserved at `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh` for the post-M031 comparison. P00's exit criteria explicitly require capturing both pre-M031 and post-M031 per-task JSONL records simultaneously while both code paths are live — that capture is the only feasible window.

**AD-15. Corpus stratification is normative** (resolves MIT-08 / Q-7 / RISK-08). Q-7 closes as a normative requirement, not an open question. Corpus composition: at least 5 historical-JSONL-derived tasks (stratified 2 high-cost / 2 medium / 1 low by pre-M031 rediscovery cost), at least 5 synthetic edge-case tasks (empty / 1-file / 5-file / 10-file / doc-only), 10 spread across at least 3 categories (bugfix / doc / feature). `tests/m031-acceptance/fixtures/empirical-baseline/CORPUS-MANIFEST.md` declares the composition; the battery verifies its existence. Reasoning: the gate's tautology argument (corpus author = system author) is real even with a constitutional backstop; mechanical stratification is the structural fix.

**AD-16. Tier A+ classifier fixture requires JSONL provenance** (resolves MIT-06 / RISK-05). The Tier A+ heuristic boundary and the SC-5 fixture are co-authored in P02 — without external grounding this verifies internal consistency, not correctness. P02 exit criteria require `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` documenting at least one historical `.orchestrator/` JSONL `unit_close` record the fixture author classified as a Tier A+ candidate, plus the annotator's rationale.

**AD-17. SC-3 prescribes the fixture explicitly** (resolves MIT-07 / RISK-06). Rewrite SC-3 from descriptive ("records appear when payload exceeds thresholds") to prescriptive ("the test fixture MUST construct a payload exceeding M018 tier-1 thresholds"). M018 tier-1 threshold value is documented in `references/RUNTIME-ASSUMPTIONS.md` as a P00 precondition.

**AD-18. New SC verifies absolute budget compliance** (resolves MIT-09 / NEW-001). Add SC-15: median `knowledge_section_tokens` emitted by `build-context.sh --profile=quick` across the 20-task corpus is ≤ `quick_knowledge_token_budget`, independent of the pre-M031 baseline. SC-11 (relative comparison) + SC-2 (per-task budget ceiling) + SC-15 (median absolute compliance) form complementary coverage. Update SC-14's count to N≥14.

**AD-19. M027 efficiency-footer adds budget-drift warning** (resolves MIT-10 / RISK-07). New informational signal: `QUICK_BUDGET_DRIFT` warning when rolling median `knowledge_section_tokens` across the most recent 7 consecutive Quick dispatches exceeds budget × 1.1. Non-blocking; surfaces via the existing M027 efficiency-footer JSONL record. Lands in P04 alongside the doctor compound-change comms (AD-9).

**AD-20. The Tier A+ pre-plan approval prompt is a designed UX surface, not an afterthought.** Confirmed during operator review of OQ-2: the prompt MUST be clearly user-friendly. Concrete requirements that gate FR-9 verification:

- **Plain-language framing** — no JSON dumps, no technical jargon, no scaffold-placeholder-style markers in the prompt body. Read like a colleague handing off, not a CLI status line.
- **Inline research summary** — display the first N lines (default N=8, configurable via `tier_a_plus_prompt_summary_lines`) of `research.md` directly in the prompt, NOT just the file path. The path display from MIT-03 is the "where" — the inline summary is the "what."
- **Clear next-step framing** — the prompt names what happens on yes ("plan against this research"), what happens on no ("re-run research with different framing"), and the cancel exit ("abort this Tier A+ flow"). Three named options, single-keystroke responses (`y`/`n`/`c`), default is no-answer = cancel.
- **Resume-vs-rerun visibility** — when MIT-03's check finds an existing `research.md`, the prompt MUST distinguish between "resume from this research" (existing) and "this is fresh research from this session" (new). The operator should never wonder which they are looking at.
- **`--yes` skip honors the path display** — when `--yes` skips the prompt, a single stderr line MUST still emit the research findings path (`research: <path>`) so the operator has the same audit trail as an interactive session.
- **No surprise output** — the prompt MUST NOT scroll past the research summary; if `research.md` exceeds the inline summary budget, the prompt prints the summary + "(N more lines at <path>)" rather than dumping the whole file.

Reasoning (operator note 2026-05-01): the prompt is the load-bearing UX surface for the entire Tier A+ flow — it is the only operator interaction in the research → plan → build chain. A merely-functional prompt (yes/no with a path) would technically satisfy MIT-03 while undermining the user-experience claim in F3 of the proposal. AD-20 promotes the prompt's UX quality from "implementation detail" to "verifiable design constraint." A new SC (SC-16, see below) gates AD-20 mechanically.

**SC-16 (new, AD-20 verification)**: an integration test fixture (`tests/m031-acceptance/test-tier-a-plus-prompt-ux.sh`) verifies that the captured stdout/stderr from a Tier A+ flow includes (a) plain-language framing strings (no `null`, no JSON braces, no `<TODO:` patterns), (b) the first 8 lines of the fixture `research.md` rendered inline, (c) all three named options visible (`y`/`n`/`c`), (d) the `(N more lines at <path>)` ellipsis when research exceeds budget, AND (e) when `--yes` is passed, the `research: <path>` audit-line appears on stderr. Update SC-14 count to N≥15.

**Cross-references**: AD-20 supersedes AD-7's "one prompt, `--yes` skips" only by extending it; the one-prompt decision and `--yes` behavior remain. AD-20 + AD-10 (deterministic paths) + MIT-03 (path display) compose into a single coherent prompt-design contract for plan-phase P02 to implement against.

## Scope Boundaries

**In scope (M031 changes these):**

- `commands/dispatch.md:21` Quick branch (FR-4) — replace skip with Quick-profile.
- `commands/evaluate.md` (FR-14) — drop pre-M024 Tier A "no orchestrator overhead" section.
- `commands/do.md` (new) or `orchestrator:evaluate` rename — universal entry skill (FR-10..13).
- `references/tier-definitions.md` (FR-15) — match evaluate.md post-fix.
- `references/RUNTIME-ASSUMPTIONS.md` — document M018 tier-1 threshold value (P00 precondition for AD-17).
- `scripts/dispatch/build-context.sh` (FR-2 + AD-11) — `--profile` flag + `--meta-out` sidecar + per-profile scope/traversal/decisions/glossary policy.
- `scripts/intake/paragraph-classify.sh`, `scripts/intake/shape-detect.sh`, `scripts/intake/route-to-dispatch.sh` (FR-6, FR-7, AD-2) — `tier_a_plus` verdict surface + three-dispatch chaining.
- `scripts/lifecycle/doctor.sh` (AD-9) — M031 compound-change one-time message.
- `templates/orchestrator-config-default.yml` (FR-5, FR-11, FR-16, AD-8) — `quick_knowledge_token_budget`, `entry_routing_confidence_floor`, `auto_proceed: true`.
- `templates/dispatch-role-research.md`, `templates/dispatch-role-plan.md`, `templates/dispatch-role-build.md` (FR-8) — three new prescriptive role templates.
- `tests/m031-acceptance/` (new) — full acceptance battery + fixtures + manifest + provenance docs.
- `CHANGELOG.md` (AD-9) — M031 entry naming the compound behavioral change.

**Out of scope (M031 does NOT touch these):**

- `knowledge/**` schema, content, indexer, or traversal logic — M020 (closed).
- `scripts/cost/` — M027 (closed).
- `scripts/dispatch/adapters/router/` — M030 model routing (closed).
- `scripts/auto/loop/` — M028 auto-loop (closed).
- Wiki / GitHub knowledge sync — M012 / M013 (closed); M031 changes how knowledge is *injected*, not how it is *authored*.
- Long-running interactive shell — universal entry stays one-shot per command.
- Auto-tuning of intensity from past task data — premature; static heuristics ship first.
- Codex CLI / Cursor parity — M009 deferred post-launch (CON-6).

**Boundary safeguard:** SC-12 (`scope-guard.sh`) is a strict allow-list verifier; M031's diff fails the battery if it touches any out-of-scope path. The Boundary write-sites table in spec.md lines 172–186 is the normative source.

## Design Constraints

- **DC-1 (Constitution Principle I)**: every M031 design choice is evaluated against `Context_Efficiency = Relevant_Instructions / Total_Instructions_Inherited`. The Quick-skip path is the textbook violation; FR-1+2+3 is the textbook fix.
- **DC-2 (Constitution Principle II)**: P00 empirical baseline is the merge blocker. No "should work" reasoning ships in any FR-1/2/3 PR. Evidence is JSONL records emitted during P00.
- **DC-3 (Constitution Principle VII)**: every dispatch path emits a `payload_breakdown` JSONL record (CON-1 invariant). There is no "skip context" exit — only "scope it tighter."
- **DC-4 (Constitution Principle XIV)**: no new state machines, no new lock files, no auto-loop changes. Tier A+ is three sequential `dispatch` calls.
- **DC-5 (Constitution Principle XV)**: SC-12 scope-guard verifier mechanically enforces surgical-precision against the declared boundary.
- **DC-6 (Backwards-compat)**: existing `.orchestrator/config.yml` files work unchanged after M031. Missing keys fall back to new defaults. Explicit values are preserved (A-4).
- **DC-7 (Runtime parity)**: M031 ships CC-only at launch (CON-6). Acceptance battery is POSIX-bash so M009 can extend without rewrite.
- **DC-8 (D020 hygiene)**: authored prose avoids embedding the literal scaffold-placeholder open-bracket-TODO-colon byte pattern inside backticked inline code. Use "scaffold-placeholder marker" or paraphrase. (Spec CON-7.)
- **DC-9 (Cross-milestone interface)**: `build-context.sh --meta-out` sidecar (AD-11) is a contract M031 + M029 + M036 share. Schema changes are breaking changes; M031 ships the minimum schema and reserves additive extensions for M029 / M036.

## Open Questions

All 19 spec-level open questions (8 architectural + 11 gate-deferred) and 8 operator-review questions (OQ-1..OQ-8) are now resolved. Decisions captured below; the resolved-decisions block is the source of truth that `orchestrator:roadmap` reads.

**Resolved decisions (operator review 2026-05-01):**

- **OQ-1 (universal-entry-naming) → `orchestrator:do <task>` for CC at launch** (operator: agree with recommendation). `orchestrator <task>` reserved for post-M009 runtime parity. AD-6 stands.
- **OQ-2 (Tier A+ approval flow) → one prompt before plan; `--yes` skips; prompt MUST be very user-friendly** (operator: keep prompt + explicit UX requirement). AD-7 stands; AD-20 added to gate prompt UX quality mechanically (SC-16).
- **OQ-3 (auto_proceed flip) → flip `false → true`** (operator: agree). AD-8 stands. AD-9 (doctor compound-change comms) is the mitigation; this is two compound behavior changes shipped together as designed.
- **OQ-4 (entry_routing_confidence_floor) → default 0.7; P00 may calibrate** (operator: agree with recommendation). FR-11 stands.
- **OQ-5 (P00 corpus stratification) → 5 historical (2 high / 2 medium / 1 low) + 5 synthetic edge-case (empty / 1-file / 5-file / 10-file / doc-only) + 10 spread across 3 categories** (operator: agree with recommendation). AD-15 stands.
- **OQ-6 (FR-19 deferral) → defer to M029** (operator: agree with recommendation). M031 emits the JSONL records; M029 renders. NG-7-spirit preserved.
- **OQ-7 (SC-13 Option A vs B) → P00 picks against observed CI environment, B preferred per AD-12** (operator: agree). Not blocking discuss finalization.
- **OQ-8 (universal-entry shape) → new `commands/do.md`** (operator: agree with recommendation). `commands/evaluate.md` stays a tier-classification primitive that `do`'s router calls on `paragraph` shape. M031 grows the command count from 13 to 14; the F3 "too many commands" pain is addressed by `do` being the headline universal entry, not by reducing primitive surface.

**Resolved meta-decisions:**

- **Phase shape → 5 phases** (operator: deferred to me with the framing "do this correctly, not quickly"). Final shape: P00 empirical baseline → P01 knowledge-unconditional → P02 Tier A+ middle flow → P03 universal entry → P04 drift fix + observability + comms. P00 gates P01 merge per CON-5. The drift-fix-+-observability-+-comms bundle (FR-14, FR-15, FR-16, AD-9 doctor comms, AD-19 budget-drift warning, SC-9 doc-drift verifier, the FR-2 `--meta-out` sidecar plumbing for downstream consumers) is load-bearing for closing the gate's mitigation list and gets its own phase rather than being folded into P03's tail. Roadmap may collapse 5 → 4 if the dependency graph supports it; planning starting point is 5.
- **Spec amendment timing → fold AD-1..AD-20 into spec.md AFTER `orchestrator:roadmap` lands** (operator: deferred to me; my recommendation accepted). Rationale: several amendments (AD-13, AD-14, AD-18, AD-20 introduce SC-* renumbering and cross-reference SC-X to phases that don't exist until roadmap. Folding pre-roadmap forces a second amendment pass once phase IDs are pinned. The gate-result.md + this finalized context draft are the durable audit trail; the spec stays internally consistent at any rewrite snapshot. P00 of the roadmap-pinned plan owns the spec-body fold-in as its first task.
- **Discuss intensity → Full** (defaulted fail-safe; not contested by operator). `--intensity-metadata` not present at runtime; defaulting to Full per the discuss command's missing-gate rule.

**Items that DID NOT need operator approval — pre-confirmed by gate verdict + arbiter ruling:**

- All P0 mitigations (AD-10, AD-11, AD-12, AD-13, AD-14).
- All P1 mitigations (AD-15, AD-16, AD-17, AD-18).
- All P2 mitigations (AD-9, AD-19).

**Carry-forward to plan-phase P00 (these are P00 exit criteria, not unresolved questions):**

- Pin `quick_knowledge_token_budget` final default value (proposal: 800; AD-5 says P00 may revise based on corpus data).
- Pin `entry_routing_confidence_floor` final default value (AD: 0.7; P00 may calibrate against M024 existing confidence distribution).
- Pin `tier_a_plus_prompt_summary_lines` final default value (AD-20: 8; tunable based on research-template length empirics).
- Pick SC-13 Option A vs Option B based on the observed CI environment's git-history availability (AD-12).
- Author `tests/m031-acceptance/fixtures/empirical-baseline/CORPUS-MANIFEST.md` (AD-15 normative).
- Document M018 tier-1 threshold value in `references/RUNTIME-ASSUMPTIONS.md` (AD-17 P00 precondition).
- Capture pre-M031 + post-M031 per-task JSONL records simultaneously while both code paths are live (AD-14 single-window requirement).
- Preserve the pre-M031 Quick stub at `tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh` after FR-4 merges (AD-14).

**Carry-forward to plan-phase P02 (these are P02 exit criteria):**

- Author `tests/m031-acceptance/fixtures/FIXTURE-PROVENANCE.md` documenting at least one historical `.orchestrator/` JSONL `unit_close` record classified as Tier A+ candidate, with annotator rationale (AD-16 normative).
- Implement task-slug derivation per AD-10 (first 40 chars, lower-cased, hyphenated, alphanumerics-only, 4-char SHA-1 collision suffix).
- Implement AD-20 prompt UX requirements; SC-16 fixture is the verification gate.

**Roadmap-time decisions (deliberately deferred to `orchestrator:roadmap`):**

- Final phase count (5 starting point; 4 acceptable if dependency analysis supports collapsing P03+P04).
- Phase boundary maps and cross-phase dependency graph.
- Per-phase success criteria mapping (which SC gates which phase's close).
- Whether the spec-body fold-in (AD-1..AD-20 → spec.md) is its own task in P00 or part of a P00 setup task.
