---
schema_version: "1.0"
type: context-draft
milestone: "M024"
status: finalized
created_at: "2026-04-25"
finalized_at: "2026-04-25T17:26:30Z"
---

## Architectural Decisions

**AD-1 (auto-proceed-config-scope)** — The auto-proceed kill-switch is a project-config knob only: `evaluate.auto_proceed: true|false` in `.orchestrator/config.yml`, default `true`. No `--no-auto-proceed` CLI flag in M024. Single durable knob keeps the surface small (Constitution XIV) and makes audit trivial: a project that disables auto-proceed does so once, in a single inspectable place. Resolves spec #Q-7. (Q1)

**AD-2 (intake-id-counter-allocation)** — When no spec exists, `<id>` is allocated as a zero-padded counter mirroring the `specs/NNN-…` convention: `intake/001-<short-slug>`, `intake/002-<short-slug>`, etc. Counter is computed by enumerating existing `.orchestrator/intake/` entries and taking max+1. Content-hash allocation is rejected — readability + symmetry with `specs/` convention wins, and multi-operator concurrency is not a current concern. Resolves spec #Q-2. (Q2)

**AD-3 (schema-version-aligned-with-spec-frontmatter)** — Proposal artifact frontmatter pins `schema_version: "1.0"` in the same key that spec frontmatter uses. No separate `intake_schema_version` field. D017's FR-7/FR-15 handshake requires M014's interim manifest to be a strict subset of this proposal artifact, and M014 ships `schema_version: "1.0"` already; aligning the version key minimizes cognitive load and lets the same JSON-superset assertion (SC-8) read both shapes uniformly. Resolves spec #Q-5. (Q3)

**AD-4 (m014-handshake-both-directions-in-m024)** — Both directions of the M014 ↔ M024 handshake land inside M024: (a) M014 → M024, where an `orchestrator:specify` interim manifest is read by M024 as an `input_shape=spec` proposal, and (b) M024 → M014, where M024 routes a non-trivial paragraph/idea/fragment to `orchestrator:specify` for body authoring. Staging the second direction to a fast-follow is rejected — closing the loop in one milestone is what FR-15 commits to and what the dogfood posture requires. (Q6)

**AD-5 (conversus-gate-recommendation-inherits-m014-logic)** — The conversus-gate axis decision rule reuses M014/extended's conversus-suggestion logic: the gate is recommended when the spec metrics + keyword smell-test classify the content as complex or controversial. Universal-gate-on-every-Tier-C is rejected (too aggressive for routine work). Operator-opt-in-only is rejected (loses adversarial value where it matters). M024 invokes the M014/extended decision function read-only — no parallel implementation. Bridges to spec FR-8 reuse-over-rebuild. (Q7)

## Scope Boundaries

**SB-1 (m020-hard-block-on-discuss-finalize)** — M024 discuss-finalize is hard-gated on M020 having shipped a stable, green query surface. The remote-review notification at evaluate-time flagged that `scripts/knowledge/lib/query.sh` and five sibling files landed without bodies; until those are committed and a smoke probe passes (e.g., `bash scripts/knowledge/query.sh --topic <test>` exits 0), M024 plan-phase does not begin. Soft-degradation (FR-13 falls back to operator-supplied evidence) is rejected — that path is already specced as the empty-input honest-fallback for FR-13, not as a substitute for a working M020 surface. This boundary respects D016's explicit "M020 → M024" sequencing. (Q4)

**SB-2 (m013-uat-bug-not-a-distinct-intake-shape)** — M013 UAT-bug intake is **out of scope** as a sixth intake shape. M024 detects exactly five shapes (FR-1: idea / paragraph / fragment / spec / empty). When M013 dispatches a UAT bug into M024, the bug payload is treated as a `paragraph`-shaped input; the originating spec-chunk binding is preserved by M013's existing `spec/defect` knowledge entry, not by M024's input-shape detector. This keeps M024's surface bounded and avoids tight M013 coupling. Native UAT-bug detection can be promoted in a future M024.x if dogfooding signals it. (Q5)

**SB-3 (no-spec-authoring-no-design-rendering-no-knowledge-writes)** — Reaffirms spec NG-3 / NG-4 / NG-5: M024 does not author specs (M014 owns), does not render designs (M023 owns), and does not write to `knowledge/` (M020 owns). M024's only writes are to `.orchestrator/intake/<id>/`. Plan-phase must verify no inadvertent boundary crossings.

**SB-4 (no-tier-threshold-changes)** — Reaffirms spec NG-1: M024 does not re-tune tier-classification thresholds. The current `evaluate` logic plus M020's mature knowledge surface are consumed read-only. Any tier-threshold changes are an M020.x or new-D-row concern, not M024's.

## Design Constraints

**DC-1 (runtime-portability-posix-plus-bash-3-2)** — Implementation lands portably across CC + Codex CLI + Cursor (POSIX sh where possible, bash 3.2+ where shell features earn their cost). Any CC-specific assumption is logged in `RUNTIME-ASSUMPTIONS.md` per D016 (7). Bash 4+ features (associative arrays, `${var,,}`) are rejected unless plan-phase can demonstrate no portable alternative — current convention across `scripts/` holds. (Q8)

**DC-2 (m011-p07-conversus-adapter-untouched)** — Reaffirms spec CON-4: the conversus adapter at `scripts/dispatch/adapters/tool/conversus.sh` is consumed read-only. M024 adds a caller, not a new code path inside the adapter. Inherits the M026/D022 OSS-edition diagnostic shape and the 0/1/2 exit-code contract.

**DC-3 (d019-todo-preflight-respected)** — Reaffirms spec CON-5: any conversus-gate invocation M024 makes inherits the D019 universal TODO pre-flight invariant. The proposal artifact MUST NOT contain `<TODO:` markers when handed to the gate; section text must be authored, not scaffolded.

**DC-4 (constitution-iii-design-before-code-is-load-bearing)** — Reaffirms spec CON-1: the proposal-as-artifact gates dispatch on Constitution III. No downstream command runs without either (a) the four-condition auto-proceed path or (b) recorded operator approval. Plan-phase must encode this as a verification check, not a convention.

**DC-5 (six-axis-frontmatter-strict-superset-of-m014-manifest)** — Per D017 FR-15 + AD-3 above, the proposal artifact's frontmatter is a strict superset of M014's interim manifest keys. Plan-phase must enumerate the M014 manifest keys explicitly and write a containment assertion (SC-8). Drift on either side breaks the handshake.

## Open Questions

The 7 spec Open Questions (#Q-1 through #Q-7) carry forward to plan-phase. Three of them (#Q-2, #Q-5, #Q-7) are now resolved by AD-2 / AD-3 / AD-1 above. The remaining four are still open at plan-phase entry:

**#Q-1 (input-shape-heuristics)** — Exact length thresholds and structural markers that distinguish `idea` / `paragraph` / `fragment`. Candidates: word-count buckets (≤10 / 11–80 / 81+), presence of section headers, presence of a Given/When/Then skeleton. Plan-phase decides the mechanical rule. *Answered by*: plan-phase, informed by a small dogfood corpus (real intake samples from this repo's history if available).

**#Q-3 (qa-question-source)** — For empty-input Q&A: static template, conversus-loop, or knowledge-driven? Plan-phase decides. D019 reuse-over-rebuild posture argues for static template if it earns its keep on dogfood; conversus-loop is the costly upgrade if static fails. *Answered by*: plan-phase + a Phase-2 dogfood evaluation gate.

**#Q-4 (decomposition-recommendation-depth)** — Flat 4-value enum (FR-10: single-task / single-phase / milestone-with-phases / multi-milestone) or richer DAG? Flat first per FR-10; DAG can land in M024.x if dogfood signal demands. *Answered by*: plan-phase commits to flat; revisit deferred.

**#Q-6 (revision-mutates-vs-clones)** — `revise` re-emits the same `<id>` (preserving prior versions in-place per FR-12) or allocates a new `<id>`? FR-12 commits to in-place with `proposal-v<N>.md` suffixes; plan-phase confirms the version-suffix scheme and decides what counts as "axis change significant enough to bump version" (any axis change? any rationale change? any frontmatter change?). *Answered by*: plan-phase.

**Discuss-stage open questions added during this session:**

**#DQ-1 (m020-readiness-verification-rule)** — What is the exact mechanical check that gates M024 plan-phase entry on M020 readiness (per SB-1)? Candidates: (a) all six missing files present + non-empty; (b) `bash scripts/knowledge/query.sh --topic test` exits 0; (c) M020's own verification harness reports green. *Answered by*: plan-phase, before Phase-1 dispatch.

**#DQ-2 (m014-extended-shipping-status-at-m024-plan-phase-entry)** — Per AD-4, both directions of the handshake land in M024. Plan-phase entry must verify M014/extended has shipped (`commands/specify.md` three-pass contract live + `scripts/specify/specify.sh` shell impl present per D019 (5)). If M014/extended has NOT shipped at plan-phase entry, M024 either (a) blocks until M014 ships, or (b) ships M024 → M014 direction with a clearly-marked "M014 not yet shipped — handshake will activate when it does" stub on the M014 → M024 direction. *Answered by*: plan-phase + actual M014 shipping status check.
