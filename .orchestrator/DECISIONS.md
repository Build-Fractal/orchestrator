# Decisions Register

Decision register for the spec-kit-orchestrator project. Each entry is permalink-stable
via the `{ #dr-code-nnn }` anchor convention (see `references/authoring-conventions.md`,
landed in M037/P01/T04, for the heading-shape contract enforced by
`scripts/verify/decisions-shape-lint.sh`).

### Roadmap reassessment after P03 completion — P06 scope additions { #dr-code-001 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-001</span>
{: .code-chip-row }

- **When**: M004/P03
- **Scope**: scope
- **Choice**: P06 scope expanded by three engine-layer workarounds discovered during P03 implementation: (1) literal-audit-marker printf pattern added after SAFETY_WARNING emissions in scripts/engine/run.sh (T03/T04) because events.sh _orch_events_quote does not quote single-word values, breaking must-have greps that expect quoted form; (2) cd $REPO_ROOT subshell wrapper around check-must-haves.sh and record-result.sh calls in scripts/engine/run.sh (T05) working around check-must-haves.sh PROJECT_ROOT walk-up bug that computes PROJECT_ROOT as .specify/orchestrator/milestones/<m> instead of repo root; (3) execution-log.jsonl entries from engine dispatch do not thread ORCH_RUN_ID because record-result.sh does not currently accept/emit run_id. P06 cleanup should: fix check-must-haves.sh PROJECT_ROOT detection, extend events.sh _orch_events_quote to always quote values, extend record-result.sh to thread run_id from env, then remove all three workarounds from run.sh.
- **Revisable**: No

No downstream phases (P05, P07) invalidated — P05 consumes run.sh as an opaque coordinator, not its internal workaround patterns; P07 has no dependency on these items. P06 was already medium-risk cleanup of engine-managed scripts; these additions fit within its original scope boundary. No re-planning required.

---

### Roadmap reassessment after P05 completion — P06 scope additions { #dr-code-002 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-002</span>
{: .code-chip-row }

- **When**: M004/P05
- **Scope**: scope
- **Choice**: P06 scope expanded by five additional items discovered during P05 dispatch refactors: (1) scripts/lib/run-context.sh _orch_run_nonce SIGPIPE under set -o pipefail — causes scripts/engine/run.sh --dry-run to exit 141 when ORCH_RUN_SEED is unset; worked around in T02/T03/T04 with set +o pipefail wrapper around init_run_context (3 replicated call sites to drop after P06 fix). (2) scripts/dispatch/lib/section-handlers.sh handle_phase_summaries has a Bash 3.2 while-read bug with unterminated dep-list temp file — worked around by local _bc_handle_phase_summaries_fixed shim in build-context.sh (to drop after P06 fix). (3) templates/context-recipe.yaml default section order/priority values don't match pre-refactor dispatch-prompt parity — worked around by _bc_display_order/_bc_display_name/_bc_display_priority shim in build-context.sh (to drop after P06 recipe re-authoring). (4) scripts/verify/check-must-haves.sh doesn't discover tasks/TNN-PLAN.md files — all P05 tasks had to verify must-haves manually from payloads rather than via the canonical entrypoint. (5) scripts/dispatch/build-context.sh all emit_event calls are >/dev/null 2>&1
- **Revisable**: true wrapped as byte-for-byte parity artifact — T05 parity harness reports this as XFAIL (queued for P06 event-emission un-silencing after recipe-migration settles).



---

### Remove state_root: from .orchestrator/config.yml in T04 { #dr-code-003 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-003</span>
{: .code-chip-row }

- **When**: M015/P02
- **Scope**: scope
- **Choice**: Spec Truth #4 requires resolver to report source=existing:.orchestrator, but T02 preserved the redundant state_root: declaration in config, causing Rule 2 to win over Rule 3. Removing the declaration aligns config semantics: config is override mechanism, directory existence is canonical.
- **Revisable**: No

Aligns with spec's post-cutover resolver semantics and simplifies config to override-only role.

---

### Order of remaining milestones after M015 { #dr-code-004 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-004</span>
{: .code-chip-row }

- **When**: Roadmap / post-M015
- **Scope**: sequencing
- **Choice**: Revised sequence: M015 → M009 → M011 → M012 → M013 → M014 → M010. M010 (Cloud Dispatch / Managed Agents) moved from directly-after-M009 to the tail of the roadmap.
- **Revisable**: Yes — pull M010 forward if Managed Agents reaches GA before M014 completes.

Anthropic Managed Agents is not yet broadly available, so M010 value is externally gated. Meanwhile M011 (spec ingest), M012 (wiki), M013 (GitHub native integration), and M014 (comment automation) unlock the team's end-to-end spec→review→work loop, which is blocking current usability. M010's only technical prerequisite (M008 P03 dispatch adapter) is already satisfied, so order can be revisited without rework.

---

### Insert M016 + M017 into milestone sequence { #dr-code-005 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-005</span>
{: .code-chip-row }

- **When**: Roadmap / post-M016
- **Scope**: sequencing
- **Choice**: Revised sequence: M016 (active) → M009 → M017 → M011 → M012 → M013 → M014 → M010. M016 (Autonomous Hardening) inserted before M009 to establish zero-prompt auto mode before launch. M017 (Conversus Deliberation Gate) inserted after M009 and before M011.
- **Revisable**: Yes — M017 can be deferred past M011 if Conversus integration proves lower priority than spec management.

M016 is prerequisite for credible launch narrative — autonomous mode must actually work autonomously. M017 adds multi-agent deliberation as an opt-in quality gate, informed by the autoreason paper's generation-evaluation gap findings. Positioned before M011-M014 because spec management milestones involve subjective quality judgments where Conversus provides the most value. M017 is opt-in with no hard dependency from M011, so it can be deferred without rework cost.

---

### Defer M009 (Launch) behind dogfooding milestones M011–M014 { #dr-code-006 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-006</span>
{: .code-chip-row }

- **When**: Roadmap / post-M016
- **Scope**: sequencing
- **Choice**: Revised sequence: M016 (active) → M011 → M012 → M013 → M014 → M017 → M009 → M010. M009 (Launch & Ecosystem) moved from position 2 to position 7. M017 floated after spec management block.
- **Revisable**: Yes — M009 can be pulled forward if external adoption becomes urgent; M017 can float anywhere in the M011–M009 range.

Team needs to dogfood end-to-end spec→wiki→GitHub workflow before producing external-facing launch artifacts. Dogfooding M011–M014 will surface the rough edges that M009 docs/examples need to document. Producing launch materials before internal usage would mean rewriting them after discovering gaps. M017 repositioned after the spec management block since those milestones will reveal whether deliberation adds value at spec-quality judgment points. Supersedes positioning from D004/D005.

---

### Drop M017 as a standalone milestone; weave conversus integration into M011 via a thin reusable adapter { #dr-code-007 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-007</span>
{: .code-chip-row }

- **When**: Roadmap / M011-P07
- **Scope**: scope, sequencing
- **Choice**: (1) Remove M017 (Conversus Deliberation Gate) from the forward milestone sequence. Revised sequence: **M011 → M012 → M013 → M014 → M009 → M010**. (2) Add M011/P07 (Format-Agnostic Intake & Conversus Fidelity Gate) which lands both the LLM-driven normalizer (any markdown → spec-kit shape) and the reusable `scripts/dispatch/adapters/tool/conversus.sh` adapter. (3) The adapter becomes shared infrastructure: later milestones that want deliberation at specific checkpoints (M013 UAT PR gate, M014 ambiguous-comment classification, roadmap phase-decomposition at Full intensity) invoke it from within their own scope, rather than waiting on a dedicated milestone. (4) Intensity engine owns the policy (when gates fire by default); users own opt-in/out via `--review` / `--no-review`.
- **Revisable**: BLOCK \

Inspection of the conversus source (`~/Sites/conversus`) showed that `/conversus gate <phase> <artifact>` already provides the exact CI-shaped primitive orchestrator needs — structured `PASS \

---

### Slot M018 (Context Compression Layer) between M014 and M009 as a sketch { #dr-code-008 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-008</span>
{: .code-chip-row }

- **When**: Roadmap / post-M014
- **Scope**: sequencing, scope
- **Choice**: Revised sequence: **M011 → M012 → M013 → M014 → M019 → M018 → M009 → M010** (M019 inserted by D009). M018 adopts caveman-style (github.com/JuliusBrussee/caveman) token compression as a first-class pipeline stage aligned with Constitution Principle I (Context Minimization). Proposed phase outline (subject to detailed planning closer to kickoff): P01 compression grammar (what's safe to compress per artifact class; preserve frontmatter, code fences, paths, MEM IDs, commands, URLs), P02 dispatch compressor (optional filter in `scripts/dispatch/build-context.sh`, emits `payload.compressed.md` beside original), P03 intensity mapping (Quick→ultra, Standard→full, Full→lite/off via `scripts/engine/intensity-gate.sh`), P04 memory compression (opt-in `CLAUDE.compressed.md` / `KNOWLEDGE.compressed.md` with `.original` siblings), P05 agent output profile (inject terseness directive into payload prefix), P06 eval harness (3-arm port of caveman's evals against orchestrator payloads, gate on accuracy parity), P07 multi-runtime parity (Claude Code / Codex / Cursor). Differentiation vs. installing caveman as-is: roundtrip-safe by policy (Principle VI — originals authoritative, compress only at dispatch/load boundaries), grammar-aware preservation of orchestrator artifact structure, intensity-bound (not always-on), explicit opt-out surfaces (constitution, spec.md, PR descriptions, user-visible docs), and telemetry integrated with existing cost tracking so savings are measurable per dispatch.
- **Revisable**: Yes — M018 can slip after M009 if launch timing becomes urgent, or collapse to a single phase under M010 (where parallel overnight runs make compression savings compound with parallelism). Can also be pulled forward and merged into M011/P07-style "adapter within active milestone" pattern if dogfooding reveals dispatch-payload bloat is already the top bottleneck.

Dogfooding M011–M014 is the prerequisite that surfaces which artifacts actually dominate token spend in steady-state orchestrator use; planning M018 earlier would be speculative (Constitution XIV). Slotting before M009 means launch narrative ships with measured savings from real usage rather than hypothetical numbers. M018 does not gate launch — if compression work balloons or regresses accuracy in P06, shrink scope to dispatch-only (P02+P03+P06) and defer memory/output compression. Main risk: parse-regression in downstream scripts that grep prose — P01 grammar work is where that risk lives.

---

### Insert M019 (Observability & Efficiency Metrics) between M014 and M018 as a tiered sketch { #dr-code-009 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-009</span>
{: .code-chip-row }

- **When**: Roadmap / post-M014
- **Scope**: sequencing, scope
- **Choice**: Revised sequence: **M011 → [M019/Tier 1 emitter] → M012 → M013 → M014 → [M019/Tier 2+3] → M018 → M009 → M010**. Tier 1 ships as a small standalone unit once M011 is closed — avoids mid-milestone scope insertion (Constitution XV — Surgical Precision), gives a clean boundary for instrumentation to start, and still captures M012+M013+M014 (~3 full milestones of dogfooding) before M018 planning needs a baseline. Cost of not backfilling M011 dispatches: ~15–25 unlogged records from M011/P04–P07; acceptable tradeoff. M019 records time, token cost, estimated dollar cost, retries, deviations, verification pass rate, and domain-unit cost (per ingested spec / merged PR / auto-applied comment) at task/phase/milestone/project/all-time granularities. Three-tier framing: **Tier 1 — Just emit** (~1 day: append `payload_breakdown`, `dispatch_usage`, `unit_close` JSONL records to existing `execution-log.jsonl`; no UI; ships first thing after M011 close so M012–M014 dogfooding produces real data); **Tier 2 — Rollup + `orchestrator:cost` command** (~3 days: `scripts/diagnostics/metrics-rollup.sh`, `.orchestrator/metrics/*.jsonl` aggregates, `orchestrator:status` efficiency footer; worth it if we launch); **Tier 3 — Full polished surface** (~7 days: backend-specific `adapters/backend/*/report-usage.sh`, auto-generated `MNNN-METRICS.md` on consolidate, `orchestrator:doctor` anomaly checks, parity evals across runtimes; only if efficiency becomes M009 launch headline). Full M019 phase outline mirrors the tiers: P01 schema + pricing table, P02 dispatch-time emitter (Tier 1 boundary), P03 backend usage adapters, P04 rollup + `orchestrator:cost` command (Tier 2 boundary), P05 milestone close report, P06 status + doctor integration, P07 evals + multi-runtime parity (Tier 3 boundary). Schema must pair cost metrics with **quality metrics** (verification pass rate, deviation rate) from day one to avoid Goodhart failure mode — optimizing cheap over correct. All records labeled `source: "estimate" \
- **Revisable**: Runtime cost of tracking is effectively zero (JSONL append + reuse of existing `estimate_tokens` function; no added LLM tokens — agent does NOT self-report, runtime hooks supply actuals). Build cost is the real decision, hence the tiered framing so M019's final scope is set by what the Tier 1 data reveals rather than up-front speculation. M019 before M018 because compression needs a measured baseline. M019 before M009 because launch narrative differentiates on published receipts ("M011 shipped in N phases, M tasks, $X spend, Y% first-try verification pass") — no other orchestrator tool publishes this. Also surfaces Principle V's fresh-context cost quantitatively, making the Context Minimization claim auditable.

"runtime"` so estimates and ground-truth usage (from Claude Code `SessionEnd`, Codex/Cursor where available) don't silently mix. Pricing table lives at `config/pricing.yml`; stale rates degrade gracefully with last-updated date surfaced in reports.

---

### Reframe M018 core approach from single compression filter to four-tier compaction ladder { #dr-code-010 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-010</span>
{: .code-chip-row }

- **When**: Roadmap / M018 framing (amends D008)
- **Scope**: scope, framing
- **Choice**: Replace the D008 phase outline's "P02 dispatch compressor (optional filter...)" framing with a tier-ladder model informed by Article 3 (Rohit's Claude Code harness teardown) and logged in `.orchestrator/scratch/articles-synthesis-2026-04-17.md`. Every dispatch runs through tiers in order, cheapest first: **Tier 1 microcompact** (reuse cached tool-call results that haven't changed + persist oversized tool results to disk with `file_path + preview` references — absorbs L6 tool-result budgeting; zero LLM cost); **Tier 2 snip** (head-drop with protected tail; no LLM call); **Tier 3 auto-compact** (summarize via LLM call; existing caveman-style territory); **Tier 4 context collapse** (staged multi-phase compression of tool results → reasoning → sections; feature-flagged). Intensity maps to tier ceiling: Quick→T1–T2 only, Standard→through T3, Full→all tiers available. Revised phase outline: P01 tier grammar + per-tier safety boundaries (what's preservable per tier), P02 Tier 1 microcompact + tool-result budgeting, P03 Tier 2 snip with protected-tail semantics, P04 Tier 3 auto-compact (summarization, intensity-gated), P05 Tier 4 collapse (staged; feature-flagged, off by default), P06 eval harness (3-arm parity tests per tier), P07 multi-runtime parity. D008's original scope envelope (roundtrip-safe by policy, grammar-aware preservation, intensity-bound, explicit opt-out surfaces, telemetry-integrated) carries forward unchanged — only the internal staging model is reframed. Fresh `orchestrator:discuss` at M018 kickoff addresses detailed tier design once M019 Tier 1 data reveals which artifacts dominate token spend. **Conversus integration (locked in per D007 reuse pattern)**: M018/P01 tier-grammar + per-tier-safety-boundary work invokes `scripts/dispatch/adapters/tool/conversus.sh` via `role/red-team` + `domain/security` presets at plan-review time. Rationale: grammar decisions carry parse-regression risk across downstream scripts that grep prose (the risk D008 originally flagged), which is exactly the subjective-quality territory the conversus fidelity-gate adapter earns its cost on. A new preset drops under `templates/conversus-presets/` without adapter modification (same pattern M013/M014 use). Gate is intensity-bound by default (Quick=off, Standard=advisory, Full=blocking); `--no-review` escape available.
- **Revisable**: Yes — individual tiers can be dropped if M019 Tier 1 data shows they don't earn their complexity (e.g., if measured tool-result sizes are already small, skip T1 microcompact in favor of direct T2 snip). Tier ladder is the framing; specific tier set is open. If M018 kickoff reveals the ladder itself is overkill for orchestrator's payload profile, collapse back to D008's single-filter model with this amendment noted as a considered-and-rejected alternative.

Single-filter framing would bias planning toward one tier (most likely summarization, the expensive option) and miss the compounding savings of cheaper tiers that handle the majority of cases at zero LLM cost. The four-tier pattern is production-validated in Claude Code's harness. Amendment lands *now* (before M018 planning kicks off) to correct roadmap framing integrity — D008 as written would have anchored discuss-at-kickoff on the wrong mental model. Detailed design questions (per-tier grammar, intensity mapping specifics, parse-regression risk per tier) deferred to M018/P01 discuss once measured data exists.

---

### Log mechanical criteria for M020 (Knowledge Layer Maturation) promote-or-dissolve decision at M012/P02 close { #dr-code-011 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-011</span>
{: .code-chip-row }

- **When**: Roadmap / post-M012 trigger
- **Scope**: sequencing, governance
- **Choice**: Context: `.orchestrator/scratch/articles-synthesis-2026-04-17.md` identified a coherent knowledge-layer theme bundling L7 (wikilinks), L8 (explored state), A1 (preferences layer), A2 (candidate→graduate with required rationale), A3 (review queue in status), A4 (AGENTS.md read-order map), A6 (Jaccard clustering in consolidate). Without a logged trigger, the M020 decision drifts. Evaluation rule at M012/P02 close: assess whether M012's spec-wiki implementation ships **(a)** clickable cross-refs from spec pages to `knowledge/**/MEM*.md` entries via shared ID namespace, **(b)** a review/unreviewed state model on generated pages, **(c)** a query/search surface callable from orchestrator dispatches (wiki-query analog). **Decision rule**: ≥2 of 3 land → M020 dissolves into knowledge-tooling maintenance PRs with no milestone commitment (M012 patterns cover enough of the surface); ≤1 of 3 land → promote M020 as a committed milestone positioned between M014 and M018 (before M019 Tier 2/3, so A5 on_failure flagging can draw on its data). **Minimum-viable subset ships regardless of the M020 decision**: L8 (explored state on auto-generated MEM entries) + A2 minimal guard (`scripts/knowledge/graduate.sh --rationale "..."` flips `status: candidate` → `status: graduated`) bundled into a standalone maintenance PR. Rationale: these are small (~30 lines), address the rubber-stamping failure mode directly, and compound M019 Tier 1's measurement value. The *full* A2 workflow (clustering, staging layer, review queue UI, decision history) waits for the M020 decision. **A4 also ships standalone**, before M019/P00, as an independent concern (session-start file-loading manifest for non-Claude-Code runtimes) — not bundled with P00 because P00's scope discipline is "dispatch-facing payload adaptation only."
- **Revisable**: Yes — criteria can be adjusted if M012 scope shifts significantly before P02. If M013 or M014 scope starts absorbing knowledge-layer work (e.g., comment-automation's classification surface overlaps with clustering), promote the trigger to that milestone's close. If a 4th distinct affordance emerges during M012 planning (e.g., MkDocs + Giscus establishes a graduation workflow), add it to the criteria set.

Subjective triggers ("still feels like flat registry") are non-reproducible and drift. Mechanical criteria tied to M012/P02 deliverables make the decision auditable — anyone can inspect M012's output and apply the rule. The 2-of-3 threshold recognizes M012 is a spec wiki, not a knowledge wiki — it may cover some but not all patterns. Shipping the minimum-viable subset (L8 + A2 minimal guard + A4) independently of the M020 decision means the structural anti-rubber-stamping guard lands early without committing to milestone scaffolding that may prove redundant.

---

### Insert M021 (Autonomous Hardening v2) before M019 and position M019 Tier 1 emitter only after M021 closes { #dr-code-012 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-012</span>
{: .code-chip-row }

- **When**: Roadmap / pre-M019 (M021 reorder)
- **Scope**: sequencing, scope
- **Choice**: Revised sequence: **M011 (closed) → M021 (active) → M019 Tier 1 emitter → M012 → M013 → M014 → M019 Tier 2+3 → M018 → M009 → M010**. M021 closes the residual Class B prompt triggers (12 shape patterns surviving M016's Class A hardening) identified in 20 M011/P05–P07 auto-mode screenshots via three layers: a three-wrapper catalog under `scripts/util/`, linter v2 (AP-005..AP-009 detectors + scope widening to task-PAYLOADs), and a PreToolUse shape-guard hook enforcing a closed 10-pattern rewrite/reject matrix. Ordered before M019 so observability metrics (time/tokens/$/quality) dogfood on a **zero-prompt baseline** rather than mixing cost measurements with interruption overhead — cleaner Tier 1 data from M012–M014 dogfooding, more defensible launch narrative. (ID note: this entry was anticipated as D010 in M021-ROADMAP.md and M021-CONTEXT.md on 2026-04-17; D010/D011 landed first, so this reorder decision is recorded as D012.)
- **Revisable**: No — once the hook is live and the replay corpus is in CI, rolling back is a permission-only change in `.claude/settings.json` (disable the hook entry) but the corpus and AP-005..AP-009 entries stay as knowledge (constitution VII).

Evidence-grounded: 20 M011/P05–P07 screenshots define the closed pattern matrix (AD-2, AD-5); no speculative additions (constitution XIV). M021 itself dogfoods via its own `orchestrator:auto` execution through P01–P04 (AD-8) — SC-7 attestation is produced by `scripts/verify/m021-p04-dogfood-attestation.sh` and the permanent replay corpus at `tests/fixtures/m021-prompt-corpus.txt`. Adding M021 ahead of M019 costs ~1 milestone of sequencing but eliminates the noise floor that would otherwise contaminate every subsequent metrics measurement — principle I (Context Minimization) applied to the measurement apparatus itself.

---

### Resolve D011 M020 promote-or-dissolve decision based on M012 evaluation { #dr-code-013 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-013</span>
{: .code-chip-row }

- **When**: Roadmap / post-M012/P02 trigger (D011 outcome)
- **Scope**: sequencing
- **Choice**: Promote M020 (Knowledge Layer Maturation) as a committed milestone. Revised sequence: M011 (closed) -> M021 (closed) -> M019 Tier 1 (closed) -> M012 (closed) -> M013 -> M014 -> M020 -> M019 Tier 2+3 -> M018 -> M009 -> M010.
- **Revisable**: Yes -- M020 can be deferred past M013/M014 if those milestones absorb knowledge-layer work organically (e.g., M014 comment-automation classification overlaps with A6 Jaccard clustering). M020 position before M019 Tier 2+3 is load-bearing -- Tier 2/3 rollups use M020 data shape; swapping order requires re-planning both.

M012/P02 D011-EVALUATION.md (.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md) records the mechanical outcome: 1 of 3 criteria shipped (cross-refs to knowledge/**/MEM*.md entries via shared ID namespace via the include-markdown pipeline; review/unreviewed state model NOT shipped; query/search surface callable from dispatches NOT shipped). D011's decision rule: <=1 of 3 -> promote as committed milestone, positioned between M014 and M019 Tier 2+3 so A5 on_failure flagging can draw on its data. M012's cross-ref affordance (pathname-keyed wiki stubs with include-markdown) is necessary but not sufficient for the full A1/A2/A3/A6 knowledge-layer workflow; M020 ships the remaining review-state + query-surface + clustering surface. Minimum-viable subset (L8 explored state + A2 minimal graduate.sh guard + A4 session-start manifest) still ships independently before M020 per D011 framing; full A2 workflow and review queue UI wait for M020 kickoff.

---

### Apply conversus red-blue deliberation outcome to M013 spec pre-discuss { #dr-code-014 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-014</span>
{: .code-chip-row }

- **When**: M013 spec / pre-discuss
- **Scope**: scope, governance
- **Choice**: Narrow M013 scope per `specs/023-github-native-integration/conversus/` run: (1) FR-12 handler installation is Claude-Code-only for v1 (CV-3 / RD-2 binding ruling) — Codex CLI + Cursor fall back to `manual` sync at init, non-Claude-Code runtime-adapter work deferred to a future milestone; (2) Minimal Slice (CV-1 / RD-3 binding ruling) pins Phase 1 load-bearing scope to full US-3 + minimal US-1 scaffolding (sidecar config + UAT template install) + US-2 idempotency applied to UAT entries only; (3) M020 sequencing unchanged (RD-1 reclassified) — M013 -> M014 -> M020 per D013; schema authority bounded by MIT-2 narrowing FR-9 to additive-emit-only with chunk-ID pinned to existing `SPEC-*` frontmatter + new Knowledge-Layer Boundary subsection explicitly forbidding review-state / query-surface / clustering; (4) 13 unmitigated P5 risks landed as MIT-1..MIT-13 spec edits (sub-issue fallback Constraint, Constitution Check section, FR-5 three-shape rewrite, FR-6 per-item cache schema, FR-7 sync lock, FR-9 narrowing, FR-12 prose correction + scope, FR-13 `--strict` provenance + 30s timeout + drop intensity-engine coupling, FR-14 re-init via marker search + label-collision preflight, FR-15 dry-run generalized to init+sync, FR-16 rate-limit + auth-expiry detection, FR-17 cost emission, FR-18 cache reconciliation, plus SC-8/SC-9 reconciliation and new SC-12/SC-13 scope + overhead caps); Open Questions #1/#3/#6/#7 closed; new OQ on PAT-vs-App default for M009. Spec status promoted Draft -> Ready-for-discuss.
- **Revisable**: Yes — if Phase 1 discovery shows FR-9 flat-list constraint cannot deliver US-3 autocomplete, that triggers re-sequencing consideration with evidence (not a pre-plan blocker, per RD-1 settlement). If a current consumer for non-Claude-Code `on-transition` emerges before milestone close, FR-12 scope can widen with a new Decision row; otherwise Codex/Cursor registration stays deferred.

Red-blue deliberation with constitution-arbiter binding on three disputes. Spec was pinning scope intentions that had not been converted into Constitution-XIV/XV-bounded commitments; deliberation surfaced 13 concrete unmitigated risks + 3 arbitrated disputes. Arbiter ruled on XIV ("current demonstrable need" governs FR-12 and Minimal Slice) and on XV (narrow FR-9 to minimum schema authority — no sequence re-open). Landing edits pre-discuss means `orchestrator:discuss` operates on the narrowed spec and cannot silently re-expand scope. See `specs/023-github-native-integration/conversus/summary/final.md` + `conversus/arbitration/resolution.md` for full register + rulings.

---

### P02 scope split post-P01: narrow P02 to create path; insert P03 for re-init adoption + GraphQL lint { #dr-code-015 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-015</span>
{: .code-chip-row }

- **When**: M013/P01
- **Scope**: scope
- **Choice**: Original P02 shipped 7 produces (init + common helpers + marker invariant + GraphQL lint + re-adoption + sidecar extensions + doc extensions) in a single risk=high phase. Post-P01 retrospective showed P02 was the highest risk concentration in M013. Split cuts P02 to create-path-only (reuses all primitives from P01 + common helpers authored in P02), leaves a medium-risk P03 for the harder idempotency cases (re-adoption + GraphQL lint), and pushes the sync phase to P04.
- **Revisable**: No

Operator request post-P01 completion; mechanical rather than conversus-gated decision. P01 artifact prose (task summaries + PLAN files) contains forward references to the old P03 numbering — those references now point to what is P04 and are historical. DECISIONS.md is authoritative.

---

### Promote M023 (Design Layer) and M024 (Universal Intake & Routing) as committed milestones { #dr-code-016 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-016</span>
{: .code-chip-row }

- **When**: Roadmap / post-M013/P03 (2026-04-22 strategic planning)
- **Scope**: sequencing, scope, posture
- **Choice**: Revised sequence: **M013 (P04 remaining) → M014 (extended) → M020 → M024 → M019 Tier 2+3 → M018 → M023 → M009 (extended) → M010 (adjusted)**. (1) **M014 scope extension**: port spec-kit's `specify` shape as native `orchestrator:specify` (CC-first, written portably, treating spec-kit template as the I/O contract rather than a verbatim port); add conversus-suggestion logic so complex/controversial specs auto-propose red-blue pressure-test with optional spec-decomposition-before-conversus for very large specs; dual-write `AGENTS.md` alongside `CLAUDE.md` so Codex stays fed without a separate milestone. (2) **M024 Universal Intake** (new): extend `orchestrator:evaluate` to input-agnostic (idea, paragraph, fragment, full spec, or empty + Q&A) and emit a reviewable proposal artifact at `.orchestrator/intake/<id>/proposal.md` covering six axes (input shape, scope tier, decomposition, design gate, conversus gate, intensity); degenerate fast-path auto-proceeds if Tier A + Quick + no conversus + no design, approval-gated otherwise. Positioned after M020 so we dogfood it through remaining milestones. Design gate degrades gracefully pre-M023 ("design walkthrough lands in M023; author DESIGN.md manually or skip"). (3) **M023 Design Layer** (new): `orchestrator:design` command — conversus spawns N design-personality agents in parallel, each produces a DESIGN.md draft + working coded prototype in user's stack; side-by-side comparison; user picks/arbitrates; canonical DESIGN.md lands at repo root and auto-injects into payloads for ui-tagged phases. Renderer adapter interface shaped as MCP clients (runtime-agnostic; Stitch/v0/Figma/etc. consumed as they expose MCP). Stage-1-only scope — high-fidelity stakeholder-mockup expansion (Stitch/Claude-design rendering) deferred until user demand earns it. Positioned pre-M009 because orchestrator has no internal UI to dogfood against — landing earlier buys zero learning. (4) **M009 scope extension**: add runtime-parity audit as pre-launch gate — dogfood every `orchestrator:*` command end-to-end on CC + Codex + Cursor, consuming the `RUNTIME-ASSUMPTIONS.md` registry accumulated during M013–M018, fix parity bugs before external eyes. (5) **M010 posture adjustment**: ship with Managed Agents primary adapter + Codex Cloud **stubbed** adapter (proves abstraction holds without full feature parity); full Codex Cloud as demand-driven fast-follow rather than launch-critical. (6) **Ultraplan/ultrareview stance**: parked, not integrated — Claude-Code-only (requires CC on web + GitHub repo + Anthropic cloud; not available on Bedrock/Vertex/Foundry), forks multi-runtime UX. M013 GitHub integration delivers the same plan-review value universally via PR comments. Re-evaluate only if real CC-only user demand emerges. (7) **`RUNTIME-ASSUMPTIONS.md` discipline** (no milestone cost): a registry file tracking CC-specific shape assumptions as written (`settings.json` hook formats, CLAUDE.md-only writes, `claude` CLI invocation patterns). M009's parity audit consumes it as a punch-list rather than an open-ended investigation. Optional: fold a single Codex smoke-probe telemetry point into M019 T2+3's emitter for drift detection.
- **Revisable**: Yes — (a) M023 can be deferred past M009 if launch timing becomes urgent; (b) M024 can absorb part of its conversus-suggestion logic into M014 scope if that lands ahead of M024 planning; (c) M010's Codex Cloud stub can be promoted to full parity pre-launch if external demand skews Codex; (d) MCP-adapter posture for M023 can be reconsidered if MCP adoption stalls in the renderer tool ecosystem; (e) ultraplan/ultrareview can be revisited as opt-in CC-only adapters if a real user asks.

User is dogfooding CC-exclusively right now; Codex parity is a launch concern, not a dogfood concern. Back-loading Codex validation to M009 is constitutionally cleaner (XIV — don't build Codex plumbing speculatively before CC usage teaches us what needs to be portable) and keeps the current dogfooding loop fast. M023/M024 are the adoption layer — M024 ships where its internal dogfood signal is cheapest (post-M020, exercised on every remaining milestone), M023 ships where its external signal is cheapest (pre-launch, since this repo has no UI to dogfood design against). MCP-as-adapter for design renderers means M023 is runtime-agnostic by construction (CC + Codex + Cursor all support MCP). Extending `evaluate` rather than adding a new `orchestrator:start` command keeps the surface small (XIV). Proposal-as-artifact gates the router on Principle III (Design Before Code). The `RUNTIME-ASSUMPTIONS.md` discipline is a lightweight hygiene practice — a few lines of markdown per observation — preventing "CC-first" from silently becoming "CC-only." Supersedes the forward-sequence framing from D004/D005/D006/D008/D013 where M013→M014→M020→M019 T2+3→M018→M009→M010 was the last committed order.

---

### Apply cooperative conversus deliberation outcome to M014 spec pre-discuss { #dr-code-017 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-017</span>
{: .code-chip-row }

- **When**: M014 spec / pre-discuss (2026-04-22)
- **Scope**: scope, governance
- **Choice**: M014 pressure-tested pre-discuss via cooperative conversus deliberation (Tier 1; 2 agents — `spec-author` + `devils-advocate`; 1 round; no arbiter). 14 MITs applied pre-discuss covering: (P1) Phase Sequencing table as spec-layer subsection after Minimal Slice; SC-2 tightened to mechanical stdout/exit-code/stderr-grep assertions; FR-2b template SSOT (`templates/spec-template.md`) + FR-18 byte-compatibility fixture test (`tests/test-specify-shape.sh`) + SC-17; US-5 promoted to independent P2 user story with scope-boundary sentence ("US-5 is the only path that edits `specs/<NNN>-<slug>/spec.md` from a comment"); Constitution XV retrofit at SC-5 + Constitution Check section → III (primary) + XIV (supporting), with Constitution Check XV paragraph split into "applies to / does NOT apply to" sub-contexts (FR-12 + FR-14 byte-preservation retained; spec-amendment human-gate retargeted); (P2) SC-4 rewritten as two-branch construction (default: measurement + re-planning trigger; upgrade branch: pinned-shape gate with failure-posture clause); FR-14 three-case semantics (all-placeholder / partial / fully-authored) + SC-14 byte-preservation invariant; SC-6a outside-markers `shasum` invariant + `tests/test-dual-write-outside-invariant.sh`; FR-19 `--dry-run` JSONL manifest format pinned M014-local only (M013 retrofit deferred); SC-15 `RUNTIME-ASSUMPTIONS.md` close-out deliverable; SC-16 dogfood-data sizing for FR-9 classifier-shape decision; (P3) FR-7 interim→M024 migration handshake committed as one-line rule; Open Question #C-11 exhaustive CLAUDE.md write-site enumeration at planning time. Spec frontmatter promoted `Status: Draft` → `Status: Ready-for-discuss`; `Last Revised: 2026-04-22` line added matching M013 precedent. P3 Dependencies prose rewrite skipped as subsumed by Phase Sequencing table (P1 #1). Two Phase 4 disputes (SC-4 default branch; Phase Sequencing table layer) resolved via synthesizer-recommended compromises: SC-4 adopts measurement default with upgrade-branch failure-posture; table lands spec-layer.
- **Revisable**: Yes — if planning-phase discovery shows FR-9 classifier shape cannot be pinned mechanically (dogfood data too sparse, or no regex/heuristic floor earns its keep), SC-4 stays on the default branch and the upgrade branch never activates. If M024 planning reshapes the `.orchestrator/intake/` manifest schema, FR-7's migration-handshake commitment may need amendment via a new D-row.

Cooperative-mode precedent (distinct from D014's red-blue precedent on M013). Cooperative mode produced bilateral convergence: both agents' largest structural recommendations (milestone split / US-5 collapse) were withdrawn by their own authors on the merits during revision; 5 explicit bilateral convergences; 2 narrow-compromise disputes. Pressure-testing pre-discuss — as with M013 per D014 — means `orchestrator:discuss` operates on the narrowed spec and cannot silently re-expand scope. Synthesis at `specs/024-spec-management-extended/conversus/summary/final.md` is the audit-trail artifact; the deliberation record is untracked/gitignored per conversus convention.

---

### Defer P03 dispatch; mark Stale: true on roadmap { #dr-code-018 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-018</span>
{: .code-chip-row }

- **When**: M014/auto
- **Scope**: scope
- **Choice**: P03 external preflight not met (M012/P04 DEPLOY-RECORD has 3 pending sentinels + inbox-dogfood data requires ≥1 week real capture). Auto-dispatch redirected to P02/P04 for this run per roadmap guidance; P03 queues until operator completes wiki deploy and seeds inbox data
- **Revisable**: No

Roadmap explicitly predicts P02+P04 closing before P03; preflight is operator-gated and cannot be resolved autonomously

---

### Reshape orchestrator:specify into a three-pass flow (scaffold -> author -> gate) intensity-scaled { #dr-code-019 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-019</span>
{: .code-chip-row }

- **When**: M014/P01 dogfood (2026-04-23, triggered by spec 025 / M020 Knowledge-Layer Maturation)
- **Scope**: scope, contract
- **Choice**: (1) **Three-pass contract** pinned in `commands/specify.md`: Pass 1 (scaffold) always runs — creates file, populates frontmatter + Input, writes Section Contract `<TODO:` placeholders. Pass 2 (author) drafts the body from Input + DECISIONS.md + constitution + neighboring CLAUDE.md/AGENTS.md Recent Changes; Quick = agent-only no review, Standard = agent + self-review checklist warnings, Full = agent + `speckit.clarify` loop (≤5 load-bearing ambiguity questions, operator-answered, agent-revised). Pass 3 (gate) adversarially reviews authored body via `scripts/dispatch/adapters/tool/conversus.sh gate spec-pressure-test`; Quick = skip, Standard = advisory (findings folded into Open Questions, no BLOCK), Full = strict (BLOCK halts with dispute list + "revise then --amend" message). On Full+PASS, spec status promoted `Draft` → `Ready-for-discuss` + `Last Revised:` line added per M013/M014 precedent. (2) **Intensity resolution order**: project default from `.orchestrator/config.yml` → smell-test escalation via `scripts/engine/intensity-analyze.sh --description <prose>` (can only escalate, never de-escalate) → CLI `--intensity` override (trumps both). One `specify_intensity_resolution` JSONL record emitted at run start. (3) **Gate TODO pre-flight invariant** (universal): `scripts/dispatch/adapters/tool/conversus.sh gate` refuses any artifact containing ≥ `CONVERSUS_GATE_TODO_THRESHOLD` (default 1) `<TODO:` markers, with actionable error pointing at the author pass. Bypass: `CONVERSUS_GATE_SKIP_TODO_CHECK=1` (reserved for tests + intentional-stub preset authoring). Protects M013/M014/M023/M024 + any future gate consumer, not just `orchestrator:specify`. Applied to adapter in `scripts/dispatch/adapters/tool/conversus.sh:150-169` + regression test in `tests/test-conversus-adapter-shim.sh` section 1b. (4) **Reuse over rebuild**: all intensity machinery already exists (`intensity-analyze.sh`, `intensity-override.sh`, `intensity-gate.sh`, `spec-complexity-probe.sh`) — D019 wires them into the specify flow rather than adding parallel infrastructure. (5) **Implementation posture**: command contract is the SSOT (landed 2026-04-23 in `commands/specify.md`); shell implementation in `scripts/specify/specify.sh` lands in the next M014 extended phase. Until then, agents invoking the command execute passes 2 and 3 manually per the doc.
- **Revisable**: Yes — (a) if Full-intensity dogfooding reveals clarify's ≤5 question cap is too tight or too loose, adjust in a follow-up D-row without re-opening the three-pass contract. (b) If smell-test false-escalation rate is high, tune `intensity-analyze.sh` keyword weights independently — D019 commits to the resolution order, not the keyword set. (c) `CONVERSUS_GATE_TODO_THRESHOLD` default can be raised (threshold-2 to allow one placeholder) if authoring pass legitimately leaves sections marked as deferred-to-plan. (d) If Full+BLOCK exit-code-2 semantics conflict with `orchestrator:auto` loop handling, harmonize in an auto-specific D-row. (e) Implementation shell in `scripts/specify/specify.sh` can adopt the contract incrementally (Quick intensity first, then Standard, then Full's clarify wiring) without invalidating the contract itself.

Dogfooding M014/P01 on M020 (spec 025) surfaced a silent dead zone: the shipped `orchestrator:specify` scaffolds TODOs but does not author, and the pressure-test gate runs probe-and-prompt against whatever body exists. On a freshly scaffolded spec, the probe reads below-threshold (no FRs, no user stories, just TODOs) and the gate is skipped — so the gate's adversarial value is never exercised on the first draft where it matters most. The pressure-test only earns its cost against authored content; running it against placeholders produces nonsense findings, running it too late means authoring defects propagate into evaluate/discuss/roadmap before anyone catches them. Intensity-scaling the three passes respects the "right tool for the right job" ethos already pervading the orchestrator (Quick trusts the agent + skips the gate for low-risk specs; Standard adds a non-blocking safety net; Full invokes human judgment + strict gate where architecturally load-bearing work earns the cost). Smell-test-only-escalates honors operator intent (user setting Quick isn't silently upgraded to Full unless CLI override forces it) while protecting against accidental under-classification (an architecturally heavy spec at project-default Quick gets recognized and bumped). The gate TODO pre-flight is a universal invariant rather than a specify-only check so every future gate consumer (M013 UAT gate, M023 design gate, M024 routing gate) gets the protection without each one reimplementing it. Spec 025 also surfaced two upstream conversus bugs (claude-code false-fail; anthropic parallel-429) captured separately in `specs/025-knowledge-layer-maturation/conversus/PRESSURE-TEST-FINDINGS.md` + handoff in `CONVERSUS-PR-HANDOFF.md` — orthogonal to D019's contract work.

---

### Capture two specify-flow friction points discovered during the M020 + M026 dogfood { #dr-code-020 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-020</span>
{: .code-chip-row }

- **When**: M014/P01 dogfood (2026-04-23, triggered by spec 025 + spec 026 + spec 027 authoring this session)
- **Scope**: tooling, hygiene
- **Choice**: (1) **spec-metrics.sh spec-scoping bug**: `scripts/state/spec-metrics.sh <orch-root>` reads `spec_chunks_present` globally and, if true, returns the first-ingested specs counts regardless of which spec the caller is evaluating. During Task C of this session (evaluate on spec 025), it returned 3/0/10 (story/req/acceptance) from spec 001s chunks rather than the authored spec 025 counts. Workaround applied: fall back to `metrics_source: raw_spec` counts when the target spec has no chunks. Remediation: either (a) accept a `<spec-path>` argument and filter chunks to that specs ID, OR (b) emit a `chunks_cover_spec=<bool>` flag that `orchestrator:evaluate` reads before trusting `spec_chunks_present`. Landed as a plan-phase task in spec 026 M014 shell work or a dedicated M011/M014 follow-up (operator chooses). (2) **`<TODO:` in backticked code gotcha**: when authoring a spec body that refers to the scaffold-placeholder token by name (e.g. "the TODO pre-flight refuses any artifact containing `<TODO:` markers"), the literal `<TODO:` string inside inline code ticks matches the conversus.sh gate pre-flight pattern and causes a false TODO-filled refusal. This session encountered it 6 times in spec 026 before rewording to "scaffold-placeholder markers". Remediation: add a one-line Gotchas entry to `commands/specify.md` naming the escape practice ("when referring to the scaffold-placeholder token in authored prose, use `scaffold-placeholder marker` or escape the angle bracket so the literal `<TODO:` pattern does not appear"). The Pass 2 author prompt template landed under spec 026 FR-3 should carry the same guidance so automated authoring does not reintroduce the footgun. (3) **Scope bound**: D020 captures friction; it does NOT commit to a specific fix location. Fix #1 lives most naturally in `scripts/state/spec-metrics.sh` + `commands/evaluate.md` (evaluate is the sole caller today); fix #2 lives in `commands/specify.md` Gotchas + the spec-026 author prompt template. Neither warrants its own spec — both are bite-sized cleanups executable inside M014 extended or as consolidate-time follow-ups.
- **Revisable**: Yes — (a) if `orchestrator:ingest` becomes mandatory before `orchestrator:evaluate` as a workflow invariant, fix #1 becomes moot (spec chunks always cover the current spec). (b) if `CONVERSUS_GATE_TODO_THRESHOLD` is raised to 2+ to allow legitimate deferred-to-plan placeholders, fix #2s urgency drops (one accidental match no longer trips refusal). (c) if spec-026s Pass 2 prompt template evolves to post-process authored output for stray TODO patterns, fix #2 becomes a validation-layer concern not an authoring-hygiene concern.

Both frictions surfaced real this session and caused workarounds rather than clean flows. Recording them immediately prevents re-discovery cost in future specify runs. Rule of thumb: if a workaround was needed, a D-row or note lands before the session ends or the lesson evaporates with context.

---

### Out-of-band hotfix batch (2026-04-24, bbt-companion dogfood) { #dr-code-021 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-021</span>
{: .code-chip-row }

- **When**: Out-of-band hotfix batch (2026-04-24, triggered by bbt-companion dogfood)
- **Scope**: tooling, packaging, hygiene
- **Choice**: (1) **Installer staging** (`feat(install)`): `packaging/install/install-{claude-code,codex,cursor}.sh` now stage `scripts/`, `templates/`, and `references/` into the target project root at install time, record every placed file in `.orchestrator/installed-files.txt`, and honor `--uninstall` by replaying the manifest (emits `runtime_removed=N` in the UNINSTALLED summary). `references/installation.md` + `docs/getting-started.md` rewritten to drop the stale "skill bundle" claim and document the real install → project layout including Upgrading and Uninstall sections. `tests/test-installer-stages-runtime.sh` added (24 assertions, green) covering install-exits-0, stage-to-disk, manifest-written, re-install-idempotent, CLAUDE.md-untouched, and uninstall-via-manifest. (2) **State tier fix** (`fix(state)`): `scripts/state/find-active-milestone.sh` prefers `<mid>-EVALUATION.md` as the tier authority (per `commands/evaluate.md`) and falls back to `<mid>-ROADMAP.md`. Previously read tier from roadmap only, which returned `tier=none` for evaluated-but-unroadmapped milestones and caused `orchestrator:auto` to bail with "no active milestone" mid-flow on Tier C projects. Verified against bbt-companion M001 — now returns `M001 planning C`. (3) **Ingest FR-slug fix** (`fix(knowledge)`): `scripts/knowledge/ingest-spec.sh` accepts both `**FR-N**` and `**FR-N (slug-or-anything)**` marker forms (extract numeric ID, treat optional parenthetical as decoration), and aborts loudly with `ERROR:` on any line that looks like an FR marker but yields no numeric ID. Previous behavior silently dropped 36 chunks (19 requirements / 8 constraints / 9 non-goals) from bbt-companion's spec because the slugged markers fell through the narrow regex. Loud-failure turns silent data loss into actionable spec-authoring feedback. (4) **Reinit sentinel-preservation fix** (`fix(lifecycle)`): `scripts/lifecycle/reinit-handler.sh` canonicalizes `--project-dir` via `cd && pwd` so basename extraction is correct for relative paths; snapshots every `# >>> orchestrator:NAME >>>` sentinel block (not just `project-identity`) before the regenerate pass and re-injects each one via `dual-write-runtime-md.sh` post-write; reads `runtime_confidence` from `config.yml` first then from the rendered instruction-file line, and refuses to downgrade a previously-established `high`/`medium`/`low` to `unknown`. (5) **Known limitations parked for follow-up** (four items, do NOT auto-promote to milestone scope): (a) reinit template-regenerate model still loses free-form CLAUDE.md prose outside sentinel + `<!-- BEGIN CUSTOM -->` blocks — redesign needed to either switch to targeted-edit or expand sentinel surface area; (b) installer stage count of 840 files includes `scripts/verify/m*-p*-*` fixtures and `tests/fixtures/**` that a consumer project does not need — a stage-filter could drop to ~300 files (low priority); (c) `scripts/state/check-settings-state.sh` returned `state=ok` while the regen pipeline silently failed during bbt-companion install (observed, not root-caused); (d) manifest does not track upstream deletions — a file removed from spec-kit-orchestrator between installer runs leaves a stale copy in the consumer project (accepted trade-off in handoff §6, worth revisiting).
- **Revisable**: Yes — (a) If reinit free-form-prose loss bites a second user, promote 5a to a dedicated milestone or M014-extended task. (b) Stage bloat 5b can be addressed inside the installer without a D-row (filter in `install-claude-code.sh` Stage 4.5 `find` expression). (c) If `check-settings-state.sh` silent regen failure reproduces, open a spec and a bugfix commit. (d) Upstream-removal 5d can be fixed via manifest-diff in a future install pass. (e) If the four dogfood-bugfix commits should have been a single "fix(dogfood)" squashed commit rather than a 4-commit split, revisit commit-message-style for future hotfix batches — current split prioritizes archaeology readability.

bbt-companion is the first external project the orchestrator has been installed into at scale, and the install surfaced a class of bugs the `test-s*` suite cannot catch because every `test-s*` runs against the development-tree layout where scripts sit beside their callers. Bundle-infrastructure gap was the root (installer wasn't staging the files `commands/*.md` reference via project-relative paths); three downstream bugs (#2, #3, #4) compounded on top because they'd never been exercised against a genuinely-fresh `.orchestrator/` state tree with no prior chunks or milestones. Fixing as out-of-band D-rows (not a new milestone) because each fix is <50 lines of code, scoped to a single script, and orthogonal to M026. Recording as D021 rather than folding into M026 keeps the conversus-OSS migration audit-trail clean. The four parked limitations (5a-d) get a D-row line instead of immediate follow-up work because (a) reinit redesign is architecturally non-trivial (targeted-edit vs sentinel expansion is a real decision); (b) installer stage bloat is cosmetic; (c) check-settings-state is speculative without reproduction; (d) upstream-removal is acknowledged-accepted. Bringing them up explicitly here means they don't get lost to context-expiry between now and when the operator decides to tackle them.

---

### Edition-resolution two-tier detection committed as canonical pattern for runtime edition identification { #dr-code-022 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-022</span>
{: .code-chip-row }

- **When**: M026/P03 (2026-04-24)
- **Scope**: scope, contract, knowledge
- **Choice**: (1) Adapter `_resolve_edition` (M026/P02/T01, `scripts/dispatch/adapters/tool/conversus.sh:132-179`) is the canonical implementation: env-var primary with `oss\
- **Revisable**: The decision is the consolidation point for three load-bearing M026 commitments that downstream milestones (M013, M014, M018, M023, M024) need a single auditable reference for. Rather than scattering the rationale across three MEM entries and the M026-SUMMARY (not yet authored), the D-row anchors the cross-references in the existing DECISIONS audit trail. The two-tier detection pattern is reusable beyond conversus (any pip/pipx-installed Python tool with multi-channel publishing); naming the convention now means the next adapter migration can adopt the shape without re-deliberating env-var naming. The `edition_required:` preset-frontmatter contract was deferred to OQ-3 at spec-027 discuss-finalize and chose the minimum-viable shape (single optional field, no auto-detect of CLI-flag-based paid-only signals per NG-6) — D022 commits the decision in the audit trail so future scope-expansion conversations have the rationale in hand. The `FAIL:`-vs-`ERROR:` prefix uniformity rationale lives here because it is a one-line decision (preserve adapter convention; SC-7 regex accommodates) that does not warrant its own MEM entry.

paid` closed enum (stderr warning + fall-through on bad values), metadata-probe fallback via `pip show conversus` `Home-page:` parsing, short-circuit `edition=unknown reason=stub` under stub mode. Output contract: `edition=` + `reason=` lines on stdout in stable order, warnings on stderr (DC-5). (2) `<TOOL>_EDITION=<value>` env-var name is reserved as the convention for any future OSS-default-with-paid-escape-hatch tool integration in this repo (graduated as MEM030, `knowledge/conventions/MEM030.md`). The paired edition-resolution two-tier-detection pattern is graduated as MEM029 (`knowledge/patterns/MEM029.md`). (3) Preset frontmatter `edition_required: paid` (M026/P03/T01, `scripts/dispatch/adapters/tool/conversus.sh` `_read_preset_edition_required`) refuses paid-only presets on OSS-resolved binaries before any `conversus run` invocation; diagnostic on stderr matches case-insensitive regex `paid-only.*CONVERSUS_EDITION=paid` (SC-7). Diagnostic uses `FAIL:` prefix per the adapter's `_emit_fail` convention rather than the FR-11 literal `ERROR:` opener — body content satisfies the SC-7 regex regardless. (4) CHANGELOG.md records the migration under v0.9.1 heading. (5) Cross-cuts: M013/P04 observability shape unchanged (additive `edition` field per AD-4 adjacency rule); spec-026 M014 shell-impl Pass 3 wiring is the next consumer that may exercise the new resolver under a fresh-install code path.

---

### Retire synthetic P99 placeholder from M014/P03 Depends; convert to explicit Preflight note { #dr-code-023 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-023</span>
{: .code-chip-row }

- **When**: M014/P03 unblock (2026-04-24)
- **Scope**: scope, sequencing, governance
- **Choice**: (1) **Roadmap edit**: `Depends: P01, P99` → `Depends: P01` plus a `Preflight (external, operator-gated — see D023)` block enumerating both external gates with current resolution status. P03 phase-entry gate (CONTEXT OQ-4) at dispatcher level remains the load-bearing enforcement for the wiki preflight; encoding it as a fake phase ID was always belt-and-suspenders and caused a parse-time hard-fail under `read-roadmap.sh`'s P##-token guard (introduced M026/P02 commit 316411e). (2) **Wiki preflight: RESOLVED 2026-04-23** — `M012/P04/DEPLOY-RECORD.md` shows live deploy against `Build-Fractal/spec-kit-orchestrator`, all four gates (giscus-config, mkdocs-build, link-check, giscus-smoke) PASS, site live at `https://Build-Fractal.github.io/spec-kit-orchestrator/`. SC-5 redeploy-persistence is the only remaining sub-check and is non-blocking (validated partially via `mkdocs serve`; full validation lands at the next M012 redeploy event). (3) **SC-16 inbox-dogfood preflight: RELAXED** — original spec called for ≥1 week M012/M013 inbox data captured into `specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md` before plan-phase pins FR-9 classifier shape. Wiki was deployed only 1 day before this decision; waiting ≥6 calendar days delays the M014 close past usable cadence. Plan-phase will pin FR-9 shape on **regex/heuristic v1 baseline** (the lowest-cost option from OQ #C-1) with explicit retune commitment after meaningful comment volume accumulates organically. **Retune trigger**: when `actioned.jsonl` shows ≥30 fetched comments OR when classifier confidence calibration on observed comments diverges from regex/heuristic predictions in ≥20% of samples, open a follow-up D-row that re-pins FR-9 shape (likely escalating to LLM-per-comment or two-pass hybrid per OQ #C-1) and either lands the change inside M014 extended scope or as a dedicated M011/M014 follow-up.
- **Revisable**: Yes — (a) if real comment volume accumulates faster than expected (≥30 in <1 week), the retune trigger fires earlier than this D-row anticipates and FR-9 escalates within the same M014 extended scope. (b) If regex/heuristic v1 produces unacceptable false-positive/false-negative rates on observed comments before the ≥30-sample trigger, raise an early retune via a new D-row. (c) The relaxation does not waive SC-5 (Giscus persistence) — that remains an M012 redeploy concern, orthogonal to M014/P03. (d) If the dispatcher phase-entry gate is later strengthened to also gate on inbox-dogfood data presence (not just DEPLOY-RECORD sentinels), this D-row's relaxation must be re-evaluated — currently the gate covers wiki preflight only.

(a) The user explicitly chose this trade-off after being given options (wait-for-data vs proceed-with-relax vs alternate read on P99): "im open to coming back and retuning as needed once weve used the comments more." (b) D018 created P99 as an audit-trail device, not a dispatcher contract — the dispatcher already enforces preflight via `Phase-entry gate (CONTEXT OQ-4)` at task dispatch time per the M014 spec boundary map. Keeping the artifact parseable while preserving the gate at the load-bearing layer is the cleaner separation. (c) FR-9 classifier shape is the only plan-phase decision genuinely sensitive to dogfood data; pinning regex/heuristic v1 is the conservative baseline (no LLM cost, no calibration burden) and matches the spec's documented v1 floor. Retune-via-follow-up-D-row is consistent with D019(a)/(b)/(c) precedent (commit to the contract, tune the parameters in follow-up rows). (d) The roadmap edit removes the parser-hostile `P99` token without losing audit trail (this D-row + the new Preflight note carry the same information in machine-parseable form).

---

### M020 schema authority and the status: field evolution for knowledge entries { #dr-code-024 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-024</span>
{: .code-chip-row }

- **When**: M020/P01 (2026-04-25)
- **Scope**: scope, contract, knowledge, schema-authority
- **Choice**: Yes — M020 holds exclusive schema authority over knowledge/spec/** and knowledge/**/MEM*.md frontmatter per FR-9. Introduce status: frontmatter field as a closed enum (candidate, graduated, archived); introduce decision_history: as an append-only YAML list of records carrying rationale, timestamp, operator, cluster_id; introduce archived_into: as a single canonical entry-ID back-reference. Pre-M020 entries lacking status: are treated as graduated on first read; the field is written on next touch (FR-10 incremental migration, no retroactive bulk pass). Vocabulary documented in knowledge/conventions/MEM031.md. Consuming milestones (M024 universal intake, M019 Tier 2+3 observability) MAY READ these fields but MUST NOT introduce new fields without a follow-up M020 D-row.
- **Revisable**: Yes — (a) if a fourth state proves necessary (e.g. deprecated distinct from archived), open a follow-up D-row extending the closed enum and updating MEM031. (b) If decision_history: length becomes unwieldy (more than 50 records on one entry), compact via a follow-up D-row defining compaction rules (NG-6 currently defers). (c) If consuming milestones discover a needed field, the handshake is: open M020 D-row -> M020 lands schema change -> consuming milestone uses the field. Never bypass this gate.

Anchors the schema evolution in the audit trail BEFORE code lands (T02-T05 in P01 and downstream phases). The closed enum prevents downstream surfaces from inventing alternate state names (e.g. pending, superseded) that would fragment the query surface (FR-2). Append-only decision_history: keeps a non-destructive review log; compaction is deferred (NG-6). Incremental on-touch migration honors NG-3 (no retroactive bulk migration). Centralizing the schema-authority gate at M020 means future field requests from consumer milestones go through a single review point rather than racing into the frontmatter from multiple directions.

---

### pending_design_authored_manually transient frontmatter key for FR-7 graceful-degradation manual-branch { #dr-code-025 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-025</span>
{: .code-chip-row }

- **When**: M024/P07 (2026-04-26)
- **Scope**: scope, contract, schema
- **Choice**: Add `pending_design_authored_manually` to the intake-proposal frontmatter as a closed-enum `true \
- **Revisable**: M020 holds schema authority over knowledge entries (MEM031 / D024); the intake-proposal frontmatter is M024-owned but uses the same closed-enum discipline. This D-row is the M024 schema-evolution record for the intake proposal and does NOT require an M020 D-row update — intake-proposal frontmatter is not a knowledge entry, it is a transient routing artifact under M024's authority. The flag is tracked separately from `design_authored_manually` because the latter is the terminal/persistent state ("operator authored DESIGN.md, ready for approval") while the transient flag tracks the in-between halt window where the operator might or might not return. Encoding the in-between explicitly avoids a stale-state ambiguity where `design_authored_manually: false` could mean either "never started" or "started and abandoned."

false` flag. Initialized to `false` on every fresh emit (`scripts/intake/proposal-emit.sh`). Mutated only by `scripts/intake/design-gate-degradation.sh --branch manual`: set to `true` between manual-branch first-invoke (halt) and follow-up; set back to `false` once the operator authors `DESIGN.md` at the expected path and the follow-up invoke flips `design_authored_manually: true` + `pending_approval: true`. Never carries semantic value beyond "operator is mid-authoring `DESIGN.md`."

---

### Per-tier cost-estimate exposure in intensity-recommend.sh output { #dr-code-026 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-026</span>
{: .code-chip-row }

- **When**: M027/P01
- **Scope**: convention
- **Choice**: Default --format text appends a per-tier cost annotation block AFTER the existing key=value lines (preserves CON-3 byte-stable text contract via additive-only suffix). --format json (opt-in) emits the existing structured fields PLUS a top-level cost_estimates object keyed by tier name (quick / standard / full); each tier carries cost_usd (number-or-null), input_tokens (int), output_tokens (int), and pricing_warning (string-or-empty). The cost_estimates field is always present when --format json is set; a missing pricing.yml renders cost_usd as null with pricing_warning carrying the FR-24 reason string.
- **Revisable**: Yes — extending the JSON shape with new per-tier fields is additive and back-compat; renaming or removing a tier requires a follow-on D-row.

Closes Q-14. Aligns with M019 char-quartile token-estimate library and pricing.sh degradation contract (FR-24). Keeps existing key=value text contract byte-stable per CON-3 — verifier (FR-15 / SC-17) gates regression. JSON shape mirrors retrospective rollup row structure so M018 / Tier 3 consumers can parse one shape across surfaces. Tier keys (quick/standard/full) match recipes/intensity tier names.

---

### Predictive accuracy disclaimer copy in commands/cost.md { #dr-code-027 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-027</span>
{: .code-chip-row }

- **When**: M027/P01
- **Scope**: convention
- **Choice**: Verbatim disclaimer line: 'Estimates use M019 char-quartile token approximation and pricing.yml rates; actual cost typically lands within +/-20%. Runtime-actuals calibration is Tier 3 (deferred).' Placed under a dedicated 'Accuracy' subsection of commands/cost.md, immediately after the --estimate flag documentation. Same line is referenced (not duplicated) in the predictive-surface footer at orchestrator:cost --estimate output as a one-line trailer: 'estimates +/-~20%; see commands/cost.md#accuracy'.
- **Revisable**: Yes — the +/-20% figure is heuristic and may be tightened or loosened once Tier 3 runtime-actuals lands; copy edits do not require a follow-on D-row.

Closes Q-15. The +/-20% figure carries from M019/P01 token-estimate library design notes (char-quartile tokens differ from BPE tokens by roughly that margin under English-prose recipe templates). Spelling out the disclaimer in commands/cost.md makes it operator-visible without polluting machine-parseable output. Output trailer is one short line so machine consumers (M018, Tier 3) can strip it deterministically.

---

### M018 specify-gate BLOCK resolution on specs/030: skip re-gate, proceed to P00 { #dr-code-028 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-028</span>
{: .code-chip-row }

- **When**: M018/specify (2026-04-27)
- **Scope**: governance, gate-resolution
- **Choice**: **Skip re-gate; proceed to plan P00.** All three required mitigations (P0 MIT-1 emitter coverage, P0 MIT-2 SC-9 empirical calibration, P1 MIT-3 eval-harness timing) were absorbed structurally into the spec via `--amend` before the gate's unit_close: (a) MIT-1 → US-0 / FR-0a / FR-0b as P00 hard prerequisite gating all tier code (spec line 296, A-3); (b) MIT-2 → SC-9 threshold deferred to P00 section-level distribution probe with `--amend` commit before P01 closes (spec lines 241, 295); (c) MIT-3 → US-7 promoted P3→P2, must ship before/alongside Tier 3 (spec lines 162, 222). Section-level probe input data (`Knowledge=45.9%`, `Task Plan=24.0%`, `mean=16,797 tok` over 169 dispatches) already on disk at `.orchestrator/scratch/m018-telemetry-probe-report.txt` — MIT-2's empirical foundation is captured. P00 carries the proof: its mechanical acceptance criteria (≥95% `dispatch_usage` parity over 20-dispatch sample; probe-derived SC-9 threshold landed via `--amend`) demonstrate the mitigations operationally rather than through another advocate exchange.
- **Revisable**: Yes — (a) if P00 acceptance fails (emitter coverage parity < 95% across the 20-dispatch sample OR section-level probe reveals < 10% achievable savings per spec acceptance scenario 4), the milestone re-routes through `orchestrator:discuss` for re-scope before P01 starts, at which point the gate is re-run against the re-scoped spec; (b) if a new risk surfaces during P00 implementation that was not in the gate's RISK-1..7 register, open a follow-up D-row and re-gate before proceeding past P01; (c) if MIT-3's US-7 P2 promotion proves insufficient (e.g. eval harness ships but quality regressions still slip through during the Tier 3 deployment window), elevate to a runtime quality gate via follow-up D-row before any further Tier 3 dispatches.

Re-gating would re-run conversus advocates against an amended spec whose textual surface now answers each landed risk with a structural FR commitment — the most likely outcome is PASS at the cost of additional LLM calls. Skipping it makes P00's mechanical gates the load-bearing proof, which is arguably stronger evidence than another deliberation round (Constitution Principle II — Evidence Before Claims). The original BLOCK was about the spec being incomplete on measurement infrastructure; the amended spec made the missing infrastructure into structural prerequisites, so the spec-completeness concern is resolved by construction.

---

### D-RN-1 — npm package name `@build-fractal/orchestrator` { #dr-code-029 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-029</span>
{: .code-chip-row }

- **When**: M035/P01.5 (pre-rename branch open)
- **Scope**: rename
- **Choice**: npm publish target is `@build-fractal/orchestrator` (scoped). The unscoped `orchestrator` is taken on npm; collision check ran at M035/P00 (recorded in P00 SUMMARY) and confirmed `@build-fractal/orchestrator` available. Determines repo basename, binary name, and CLI command-cohort prefix downstream (D-RN-2 through D-RN-4).
- **Revisable**: No — npm v1 tarball publication in P02 bakes the scope forever; revising would mean a deprecated package + forced rename.

Resolved at M035/P00 collision-check; recorded here at P01.5 plan-phase per RENAME-PLAN.md § 2.

---

### D-RN-2 — GitHub repo basename `Build-Fractal/orchestrator` { #dr-code-030 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-030</span>
{: .code-chip-row }

- **When**: M035/P01.5 (pre-rename branch open)
- **Scope**: rename
- **Choice**: GitHub repository renamed off-tree to `Build-Fractal/orchestrator`. Operator action; GitHub auto-redirect handles the legacy URL surface so existing clones / CI references / outbound docs keep resolving. Timing: AFTER the in-tree rename branch lands, BEFORE merge to main, so post-rename HEAD lines up with the new origin name.
- **Revisable**: Yes (off-tree rename is reversible by renaming back; GitHub redirect persists either direction) until npm publication in P02 bakes the scope.

Off-tree decision; recorded here for archaeology and to anchor the in-tree text references being rewritten in T03.

---

### D-RN-3 — Command-cohort prefix `orchestrator:<cmd>` { #dr-code-031 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-031</span>
{: .code-chip-row }

- **When**: M035/P01.5 (pre-rename branch open)
- **Scope**: rename
- **Choice**: All operator-facing commands use the `orchestrator:<cmd>` cohort prefix (already canonical in `CLAUDE.md` and `commands/*.md`). T06 finishes the 4 remaining operational template surfaces that still carry the legacy `speckit:<cmd>` form. Legacy-form references are preserved verbatim in 5 allowlisted files (`commands/migrate.md`, `docs/migrating-from-speckit.md`, `references/RENAME-PLAN.md`, `scripts/verify/m015-p03-helpers/changelog-historical-snapshot.txt`, `scripts/state/namespace-aliases.sh`) as documented historical reference.
- **Revisable**: No — operator muscle-memory is already `orchestrator:*`; reverting would invalidate every existing user-facing doc and CLAUDE.md instruction.

Cohort-prefix decision is mostly already-shipped; T06 closes the remaining 4 surfaces and SC-7 acceptance verifier consumes the allowlist authored at T01.

---

### D-RN-4 — Homebrew tap `build-fractal/orchestrator` (single-formula) { #dr-code-032 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-032</span>
{: .code-chip-row }

- **When**: M035/P01.5 (pre-rename branch open)
- **Scope**: rename
- **Choice**: Homebrew tap is `build-fractal/orchestrator` as a single-formula tap (one `Formula/orchestrator.rb` per tap). Single-formula simplifies the M035/P03 tap-publishing plan (one tap repo + one formula path); multi-formula taps are deferred until a second build-fractal tool earns the cost.
- **Revisable**: Yes — converting a single-formula tap to multi-formula is mechanical (move `orchestrator.rb` under `Formula/` already, add new formulae alongside); shipping single-formula does not foreclose later expansion.

Recorded at P01.5 to give P03 a stable target name; consumes D-RN-1's `build-fractal` org choice.

---

### D-RN-5 — Local clone path `~/Sites/orchestrator` { #dr-code-033 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-033</span>
{: .code-chip-row }

- **When**: M035/P01.5 (pre-rename branch open)
- **Scope**: rename
- **Choice**: Operator's local clone path is renamed off-tree from `~/Sites/spec-kit-orchestrator` to `~/Sites/orchestrator`. In-tree references to the legacy path are rewritten in T03 (operator-paths). Off-tree filesystem rename is the operator's action; in-tree code/docs that hard-coded the legacy path are the framework's job.
- **Revisable**: Yes — `mv ~/Sites/orchestrator ~/Sites/spec-kit-orchestrator` reverses the off-tree side trivially; in-tree references would need to be rewritten back if reverted.

Drives D-RN-6 (Claude memory dir is derived from this path).

---

### D-RN-6 — Migrate Claude memory dir alongside path rename { #dr-code-034 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-034</span>
{: .code-chip-row }

- **When**: M035/P01.5 (pre-rename branch open)
- **Scope**: rename
- **Choice**: Migrate Claude memory dir from `~/.claude/projects/-Users-brettkellgren-Sites-spec-kit-orchestrator/` to `~/.claude/projects/-Users-brettkellgren-Sites-orchestrator/`. Without the migration, Claude memory entries become orphaned because Claude's project key is derived from the working-dir path; entries written under the legacy key are not visible from the new path.
- **Revisable**: Yes — `mv` the dir back if D-RN-5 is reverted.

Off-tree operator step paired with D-RN-5; recorded so the T08 runbook documents both halves of the path rename.

---

### D-RN-7 — Pre-rename version tag `v0.9.X-final-spec-kit-name` { #dr-code-035 }

<span class="md-tag md-tag-icon md-tag--decision">DR-CODE-035</span>
{: .code-chip-row }

- **When**: M035/P01.5/T01 (pre-rename branch open)
- **Scope**: rename
- **Choice**: Author a local-only git tag `v0.9.X-final-spec-kit-name` at HEAD immediately before the rename branch lands, where `X` is the current `CHANGELOG.md` top-line patch number (resolved via `awk '/^## \[[0-9]/{print; exit}' CHANGELOG.md` per CON-4 — skips `## [Unreleased]`). Captured at T01 execution time as `v0.9.2-final-spec-kit-name`. Tag gives post-rename archaeology a clean cutover marker without polluting the SemVer release stream (no `v` release tag is published — this is not a release).
- **Revisable**: Yes — trivially reversible via `git tag -d v0.9.2-final-spec-kit-name` (local) and `git push --delete origin v0.9.2-final-spec-kit-name` (remote, only if pushed).

Authored at T01 step 5 against CHANGELOG.md top-line `## [0.9.2]`; verifier `m035-p015-pre-rename-tag.sh` asserts a `v0.9.*-final-spec-kit-name` tag exists and resolves to a real commit.

---
| D001 | M035/P02 | convention | CI runner platform for npm publishing pipeline (#Q-7) | ubuntu-latest | npm tarball assembly and publish are shell+node-only; no macOS-only surface in P02. Cross-channel byte-equivalence test will gain macos-latest matrix when P03 (homebrew) lands. ubuntu-latest is fastest, cheapest, and aligned with CON-2 which permits bash 4+ in CI scripts. | No |
| D002 | M035/P02 | convention | Test-fixture strategy for postinstall + bin entry validation (#Q-10) | npm pack to local tarball + install into fixture-local prefix | Avoids polluting public registry and adopter home dirs. npm pack assembles the same tarball npm publish would; npm install -g --prefix=<fixture>/.npm-prefix ./orchestrator-*.tgz exercises postinstall under DRY_RUN=1 by default. Live postinstall is exercised in CI under a containerized fixture only on tag-push events. Avoids the verdaccio service dependency. | No |
| D003 | M035/P02 | convention | Windows postinstall guard binding (MIT-9 / #Q-G9) | package.json engines + os fields + postinstall uname check | package.json declares engines.node >=14 and os: [darwin, linux] (npm refuses install on win32 with EBADPLATFORM). Belt-and-suspenders: postinstall script also exits non-zero with a clear stderr message on uname -s = MINGW*/CYGWIN*/MSYS*/Windows_NT before invoking install-claude-code.sh. Aligned with #Q-8 deferral: Windows symlink-mode is post-launch M009 territory; until then, Windows is fail-closed at install time. | No |
| D004 | M035/P05 | signing-strategy | Release-artifact signing for the npm publishing pipeline (FR-11 / SC-11 / #Q-3 binding) | sigstore (cosign keyless) primary + SHA-256 checksum fallback | Keyless cosign signing in `.github/workflows/release.yml` (`npm-publish` job) binds each release artifact's signature to the workflow's GitHub OIDC identity (canonical-repo `v*` tag-push) and records it in the public Rekor transparency log — eliminates the GPG private-key blast radius (no long-lived signing key to rotate or compromise). `SHA256SUMS` published alongside the signed artifacts gives operators without `cosign` installed a tooling-free verification path (`shasum -a 256 -c SHA256SUMS`). The signing job uses a job-level `permissions: id-token: write` override; the workflow-level `permissions: contents: read` stays unchanged so other jobs (pr-validate) inherit least-privilege. CON-6 secret-scope discipline preserved (no new long-lived secrets; `secrets.GITHUB_TOKEN` is the default token, scoped by GHA). | No |
| D005 | M035/P05 | schema | Rollback-marker schema for `.orchestrator/.previous-version` (FR-12 / SC-12 / #Q-G8 binding) | Five-field structured `key=value` sidecar (`prior_version`, `prior_commit_sha`, `prior_manifest_path`, `prior_install_mode`, `rolled_at`) + byte-for-byte snapshot of prior `installed-files.txt` to `.orchestrator/.rollback/manifest-<prior-version>.txt` | Snapshot-at-upgrade-time decouples rollback from source-repo reachability — the rollback path must succeed even when the source repo is unreachable (e.g. `update_source: npm` upgrades against a published tarball with no local clone). `prior_install_mode` field captures `copy` / `symlink` / `mixed` / `unknown`; T02's `--rollback` driver consults this field to refuse the rollback per #Q-G8 when symlink-mode is anywhere in the prior tree (the more restrictive interpretation: any symlink in the runtime tree makes byte-equivalent revert undefined). T01 records; T02 enforces. | No |
| D006 | M036/P02 | taxonomy | Add `business-doc` reference category for internal business strategy/operational/legal/sales-prep documents (FR-1 binding) | New `business-doc` category in `references/reference-taxonomy.md` + `references/reference-source-types.yaml` + `scripts/knowledge/lib/validate-chunk-frontmatter.sh`; `default_tier: 1` (plain text + operator summary until P03 Tier 2 lands); `topic_tags` carry sub-classification (strategy, go-to-market, outreach, legal, marketing, sales-prep) per FR-2 | The closed four-category taxonomy (cms-rule\|training-material\|glossary\|regulatory-doc) is CMS-regulatory-shaped and rejects internal business material at the validator. Adopter projects need to persist business-strategy/sales/operational docs as queryable references with edge-traceability to spec chunks; bbt-crm (M036/036-project-onboarding-experience downstream) was the surfacing case. Single umbrella with `topic_tags` chosen over 3-4 narrow categories (strategy-doc/legal-doc/marketing-content/sales-asset) to minimize SSOT churn — topic_tags are flexible per-doc and don't require taxonomy changes. Four-consumer lockstep maintained: taxonomy.md + source-types.yaml + validator updated in this commit; `scripts/wiki/build-nav.sh` (P08) gets it for free since it reads taxonomy.md as SSOT. | Yes — removable via reverse-D-row + revert of the 3 SSOT files; would orphan any extant REF-business-doc-* chunks until re-categorized. |

---

### D007 — Homebrew tarball source: re-use the P05-signed `npm pack` tarball

- **Decided at**: M035 P03 plan-phase (2026-05-09).
- **Decision**: The homebrew formula's `url` field points at the
  `build-fractal-orchestrator-<version>.tgz` artifact published on
  the GitHub release by P02's `npm-publish` job + P05's signing
  pass. NO separate brew-tarball is built.
- **Rationale**:
  1. **CON-5 byte-equivalence is structural, not channel-specific.**
     A separate brew-tarball would introduce an independent build
     path whose hash drift versus the npm tarball would mask the
     very divergence CON-5 exists to catch.
  2. **Single signing chain.** P05's cosign + SHA256SUMS pass already
     covers the npm tarball; re-using it means the formula's
     `sha256` is sourced from the same `SHA256SUMS` file, no
     duplicate signing surface.
  3. **CON-6 secret-scoping carries over.** The
     `homebrew-publish` job consumes the published tarball URL +
     SHA-256 — no fresh build, no fresh secrets, just the
     `secrets.HOMEBREW_TAP_TOKEN` PAT for the cross-repo write.
- **Bound to**: FR-9 / FR-14 / SC-9 / SC-10 / CON-5.

### D008 — Tap-push mechanism: `secrets.HOMEBREW_TAP_TOKEN` PAT (contents:write only)

- **Decided at**: M035 P03 plan-phase (2026-05-09).
- **Decision**: The `homebrew-publish` job in
  `.github/workflows/release.yml` writes to
  `Build-Fractal/homebrew-orchestrator` using a Personal Access
  Token stored as `secrets.HOMEBREW_TAP_TOKEN`. The PAT MUST be
  scoped to
  `Build-Fractal/homebrew-orchestrator:contents:write` only — no
  other scope, no other repo.
- **Rationale**:
  1. **Symmetry with `secrets.NPM_TOKEN` precedent** (P02 D001 /
     D002). Operator already manages PATs for the npm channel;
     adding one more under the same review cadence is lower
     friction than introducing GitHub App ownership semantics.
  2. **CON-6 job-condition gating identical to npm.** PAT is only
     visible inside the `homebrew-publish` job, which gates on the
     same `startsWith(github.ref, 'refs/tags/v') &&
     github.event_name == 'push'` predicate as `npm-publish`.
     PR-build exfiltration vector closed by the SC-14 assertion
     shape; `pr-validate` carries an explicit negative-assertion
     step asserting `HOMEBREW_TAP_TOKEN` is empty in PR context.
  3. **GitHub App migration is a clean fast-follow** if rotation
     friction surfaces — `homebrew-orchestrator` is the only repo
     the PAT writes to, so swapping the auth principal is a
     one-secret rotation with no formula changes.
- **Bound to**: FR-9 / CON-6 / SC-14 / MOS-2.

### D009 — Curl-pipe-bash install.sh URL host: GitHub release asset URL

**Date**: 2026-05-09
**Phase**: M035 P04 T01
**Status**: bound

`install.sh` is hosted as a GitHub release asset, NOT on a separate
domain (e.g. `orchestrator.dev`), NOT on github.io / fly.io / R2-backed
CDN, NOT on a sub-path of an existing domain, NOT on the canonical
repo's `/raw` URL.

- Latest (unpinned): `https://github.com/Build-Fractal/orchestrator/releases/latest/download/install.sh`
- Pinned (versioned): `https://github.com/Build-Fractal/orchestrator/releases/download/v<X.Y.Z>/install.sh`

**Rationale**:

1. **No new infrastructure.** Every alternative requires either a
   new domain registration, a new hosting provider, or a stable-mainline-commit-SHA
   strategy — each introduces an external dependency M035 cannot
   reverse cheaply post-launch. The GitHub release `latest/download`
   URL is a stable redirect provided by GitHub itself, automatically
   resolves to the newest release's asset, and has zero new
   infrastructure surface.
2. **Symmetric with the npm tarball + homebrew formula publication
   paths.** Both already use GitHub releases as the artifact source
   (D007 — homebrew formula's `url` field points at the npm pack
   tarball uploaded to the release; install.sh is one more asset
   on the same release). Adopting a different host for install.sh
   would fork the release-artifact distribution model.
3. **Versioned + unversioned URLs both ship for free.**
   `latest/download/install.sh` resolves to the newest release;
   `download/v<X.Y.Z>/install.sh` pins to a specific tag.
   Operators pinning to a known-good version (per Constitution
   Principle XVI integrity-first ethos) get a stable URL without
   any redirect indirection.
4. **Reversible.** If post-launch demand surfaces for a polished
   short URL (e.g., `orchestrator.dev/install.sh`), wiring a
   redirect against the same canonical asset is a one-line DNS
   change with no change to install.sh's content or signing
   surface. Picking the GitHub release URL today does not
   foreclose any future option.

**Bound to**: FR-10, US-8, SC-14.

**Cross-references**: `packaging/install/install.sh`,
`references/installation.md § Installing via curl-pipe-bash`.

### D010 — Release-workflow CI timeout: 20 minutes on ubuntu-latest (CON-8)

**Date**: 2026-05-09
**Phase**: M035 P04 T02
**Status**: bound

`npm-publish` and `homebrew-publish` jobs each carry
`timeout-minutes: 20` at job level in `.github/workflows/release.yml`.

**Rationale**:

1. **Spec recommendation honored.** The spec's `#Q-G6` recommendation
   is "20 minutes on Ubuntu-latest" + new CON-8 escalation clause.
   D010 adopts the recommendation without deviation.
2. **Headroom over typical run.** Current heaviest steps (`npm publish`
   ~30s, `npm pack` ~5s, cosign-keyless sign over ~4 artifacts ~30s
   total, SHA256SUMS ~1s, `gh release create` ~10s, downstream
   `homebrew-publish` ~45s) total ~3min nominal; 20min provides 6×
   headroom for OIDC issuance latency, transient network failures,
   cosign/sigstore log-write retries.
3. **CON-8 escalation clause is the safety net.** If wall-clock
   consistently >15min across three synthetic-tag runs, plan-phase
   author splits the workflow into parallel jobs or documents a
   revised timeout. CON-8 makes the contract explicit so future
   plan-phase authors don't re-litigate the value.
4. **Job-level not workflow-level.** `timeout-minutes` is per-job in
   GitHub Actions. Per-job timeout means a hung `homebrew-publish`
   doesn't block `npm-publish`'s success signal (and vice versa).

**Bound to**: SC-14, CON-8, FR-10.

**Cross-references**: `.github/workflows/release.yml`,
`references/installation.md § Releasing via curl-pipe-bash` (T04
adds the operator-facing note).

### D011 — Release cadence: manual stable releases pre-1.0 (operator-policy)

**Date**: 2026-05-09
**Phase**: M035 P04 T04
**Status**: bound

Pre-1.0 release cadence is **manual operator-driven tag push**. The
operator authors `CHANGELOG.md` for the release, bumps the version
in `package.json` (CON-4 SemVer source of truth), commits, and
pushes a `v*` tag. The release-workflow fires automatically on the
tag push.

**Rationale**:

1. **Spec recommendation honored.** The spec's `#Q-5` recommendation
   is "manual stable releases pre-1.0, automatic post-1.0 with
   conventional-commits-driven version bumping". D011 adopts the
   pre-1.0 portion and defers post-1.0 automation to a post-launch
   fast-follow.
2. **No code surface at v1.** The release-workflow already fires
   on `v*` tag push (operator-driven). No CI cron, no PR-merge
   auto-tagging, no conventional-commits parsing.
3. **Reversible.** Switching to automatic post-1.0 is purely
   additive: a new `.github/workflows/auto-tag.yml` + the
   conventional-commits parser ship as their own plan-phase work.
   D011 declares the v1 posture; future work supersedes via a new
   D### or by amending the documentation block.
4. **Symmetric with operator-driven first-release MOS-4 / MOS-5.**
   The launch is itself an operator-driven tag push; pre-1.0
   cadence inherits the same shape for consistency.

**Bound to**: US-8, FR-10. Operator workflow under MOS-1 / MOS-2 /
MOS-3 / MOS-4 / MOS-5 precedent.

**Cross-references**: `references/installation.md § Releasing via
curl-pipe-bash`, `commands/update.md § Update sources`.

### D012 — `update_source` config schema (M035 P06)

**Date**: 2026-05-09
**Phase**: M035 P06 T01
**Status**: bound

`.orchestrator/config.yml` accepts a top-level scalar key
`update_source: git|npm|homebrew|none`. Default behavior when the
key is absent: AD-5 detect-by-install-method-first (read
`install-meta.txt` provenance + npm/brew/curl signals; first match
wins; persist resolved source back to config). The literal value
`none` is the operator opt-out: when set, both
`orchestrator:update` dispatch and the FR-4 drift-render path
suppress silently — no dispatch, no JSONL emission, no warning.

Curl-pipe-bash users whose install resolved through `install.sh`
are detected as `npm` (because curl-pipe-bash extracts the npm
tarball — D007/D009 single-source-of-truth) and persist as `npm`
for future runs. This narrows the schema enumeration to the
spec-FR-13 literal three-channel contract (plus `none`) without
losing channel coverage.

**Rationale**:

1. **CON-7 / M027 alignment.** `update_source` joins the canonical
   `VALID_KEYS` list at `scripts/state/read-config.sh:17` using
   the existing append discipline (single-line edit, end-of-list
   position) rather than introducing a new schema surface. Every
   downstream consumer (T02 dispatch, T03 JSONL emission, T04
   doc) reads via the existing `read-config.sh` pipeline.
2. **Schema-agnostic on values.** `read-config.sh` validates keys
   only — value-enumeration enforcement (`git|npm|homebrew|none`
   set membership) is T02's `run-update.sh` dispatch
   responsibility. Invalid values surface a stderr advisory at
   dispatch time but do not block the read.
3. **Null-sentinel parity.** When the key is absent, the existing
   M027 P03/T01 null-sentinel pattern returns the literal string
   `null`; T02 treats `null` and empty as "use AD-5 detection"
   uniformly.
4. **FR-16 compliance.** No new suppression knob. The `none`
   value reuses the existing operator-opt-out semantics rather
   than introducing a parallel `update.disabled: true` toggle.

**Bound to**: FR-13, FR-16, SC-13, AD-5, #Q-5.

**Cross-references**: `scripts/state/read-config.sh § VALID_KEYS`,
`commands/update.md § Update sources`,
`tools/verify/m035-p06-config-schema-shape.sh`.

### D013 — `update_run` JSONL emission 5-condition suppression matrix (M035 P06)

**Date**: 2026-05-09
**Phase**: M035 P06 T03
**Status**: bound

The `update_run` JSONL emission for non-rollback dispatch paths
(`git` / `npm` / `homebrew`) honors M027's 5-condition suppression
matrix verbatim:

1. **`--no-emit-jsonl` flag** (`run-update.sh`, T03 introduces) →
   short-circuits emission. Opt-out only; does NOT abort dispatch.
2. **`ORCHESTRATOR_AUTO=1` env var** → short-circuits emission.
   Mirrors M027 auto-loop suppression convention.
3. **`update_source: none`** → no dispatch, no event. Defensive
   guard inside `emit_update_run_event` protects against future
   refactors that might restructure dispatch order; in practice the
   `none)` arm exits 0 before the emission code path is reached.
4. **`compression.efficiency_footer.enabled: false`** → does NOT
   apply (orthogonal surface; that knob gates efficiency-footer
   rendering, not JSONL stream writes). Documented as carve-out so
   future authors don't mistakenly bind it.
5. **Structural carve-out** → emission is bound to a successful
   dispatch decision-point, not to invocation. Pre-dispatch
   validation failures (npm not on PATH, package not installed,
   unknown source) emit nothing; post-dispatch failures (npm/brew
   exit non-zero) emit one event with `result=failure` so the
   observability stream captures the failure-rate signal too.

M035 introduces no new suppression knob beyond `--no-emit-jsonl`
(FR-16: "M035 introduces no new suppression knob; it inherits
M025/M027 conventions"). The flag is documented as inheriting the
M027 opt-out pattern rather than a new knob class.

The event schema (single-line JSON, newline-terminated):

```json
{"event":"update_run","op":"update","source":"<channel>","target_version":"<version-or-unknown>","result":"success","timestamp":"<ISO 8601 UTC>"}
```

`op=update` is T03's contribution; the rollback path (P05 T02)
emits the same shape with `op=rollback` and is unchanged. Emission
failure (`mkdir -p` / `printf >>` non-zero) must NOT abort the
caller — `emit_update_run_event` always returns 0; observability is
best-effort and dispatch success/failure stays authoritative.

**Bound to**: FR-13, FR-15, FR-16, CON-7, SC-13.

**Cross-references**: `scripts/lifecycle/run-update.sh §
emit_update_run_event`, `commands/update.md § Update sources`,
`tools/verify/m035-p06-update-run-jsonl-emission-shape.sh`, D012,
D014.

### D014 — AD-5 detection ordering for orchestrator:update (M035 P06)

**Date**: 2026-05-09
**Phase**: M035 P06 T02
**Status**: bound

When `update_source` is absent from `.orchestrator/config.yml`, the
`scripts/lifecycle/run-update.sh` driver resolves the channel via the
following first-match-wins ordering:

1. `.orchestrator/install-meta.txt` `runtime=` field — if value contains
   the literal substring `npm` / `homebrew` / `brew` / `curl` / `git`
   (case-insensitive). `curl` resolves to `npm` per D012 (curl-pipe-bash
   extracts the npm tarball — D007/D009 single-source-of-truth).
2. npm global presence: `command -v npm` AND
   `[ -d "$(npm root -g)/@build-fractal/orchestrator" ]`.
3. homebrew formula presence: `command -v brew` AND
   `[ -d "$(brew --prefix)/Cellar/orchestrator" ]`.
4. Fallback: `git`.

Detected non-`git` resolutions persist back to
`.orchestrator/config.yml` via in-place sed-replace (when an existing
`update_source:` line is present) or EOF append (when absent). This is
the **single-resolve discipline**: subsequent runs hit the persisted
config and skip detection. `git`-fallback resolutions are NOT persisted
— persisting them would noise up every fresh consumer's config with a
default that's already the implicit behavior.

**Rationale**:

1. **Provenance trumps discovery.** `install-meta.txt` is authored by
   the installer at install time and records the actual channel that
   provisioned this runtime. It is the most reliable signal and is
   checked first.
2. **Curl-pipe-bash collapse to npm.** D007/D009 fix the curl-pipe-bash
   tarball as the npm tarball; AD-5 honors that by mapping the `curl`
   substring to `npm` rather than introducing a fourth update channel.
3. **Detection fallbacks favor presence over PATH.** Steps 2 and 3
   both gate on installed-package presence (`@build-fractal/orchestrator`
   under `npm root -g`, `orchestrator` under `brew --prefix Cellar`),
   not just `command -v` of the package manager — `npm` and `brew`
   on PATH without our package present should not resolve to those
   channels.
4. **Single-resolve via persistence.** Persisting resolved non-git
   sources lets the second run skip `npm root -g` and `brew --prefix`
   spawn cost. Git fallback persistence is intentionally suppressed
   so fresh `.orchestrator/` trees don't accumulate config noise.

**Bound to**: FR-13, AD-5, SC-13.

**Cross-references**: `scripts/lifecycle/run-update.sh § Multi-source
dispatch`, `commands/update.md § Update sources`,
`tools/verify/m035-p06-multi-source-dispatch-shape.sh`, D012.
