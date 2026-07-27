# Proposal: Silent Instruments — the write / gate / read triad

**Captured**: 2026-07-27
**Shape**: Not a milestone. A **defect class** spanning three subsystems, plus the
feature work that becomes worth doing once the class is retired.
**Source**: Three independent article analyses (Microsoft GraphRAG / "graph
engineering"; Osmani-lineage "loop engineering"; Cerebras "how we built our
knowledge base"), each grounded against this codebase by a separate agent. The
articles are the prompt, not the evidence — every claim below that carries a
`file:line` was checked against the tree.
**First slice shipped**: `c8616680` — read-path repairs (see Part A).

## TL;DR

Three agents analysing three unrelated articles landed on the same structural
failure in three different subsystems:

| Subsystem | Silent failure |
|---|---|
| **Write** | Knowledge writes have stopped. 0 MEMs across 11 closed milestones; `knowledge/archive/` holds only `.gitkeep`; clustering shipped and is provably inert. |
| **Gate** | Verification can report `pass` while checking nothing. |
| **Read** | Retrieval degraded silently — 71% corpus loss on a fresh clone, ordering destroyed by a stray `sort -u`. |

Write, gate, read. **None of them fails loudly.** The orchestrator's entire value
proposition is "mechanical verification beats confident summaries" — and its own
instruments have been producing confident summaries.

That is the finding. Everything below is consequence.

## The reframe worth keeping

The graph-engineering literature's headline claim is *"the right graph beats the
bigger model"* (Stanford, arXiv:2505.16276 — 26 models on KG-engineering tasks:
larger model + bad graph loses to smaller model + good graph).

That result is normally cited here to defend M030's shadow-default posture. Read
honestly against this tree it cuts the **other way**: the orchestrator currently
*has* a bad graph — three months stale, one live edge type, zero clusters, empty
archive. Marginal spend on model-tier routing buys less right now than marginal
spend on corpus freshness would.

**The binding constraint is write-path throughput, not retrieval sophistication.**
Part A was worth doing because it was cheap and the bugs were real. Part B is
where the compounding is.

---

## Part A — Read path (first slice SHIPPED in `c8616680`)

Verified and fixed:

1. **Multi-tag scope match.** The scope rule lived in two divergent copies
   (`_sf_tag_includes` for flat `KNOWLEDGE.md`; an inline block in
   `filter_knowledge_index` for the dispatch path). Both compared the whole
   field-2 string against one tag, so `[project], [milestone:M005]` — the shape
   `rebuild-index.sh` actually writes — matched no branch. 22 of 31 MEMs carry
   that shape; `knowledge.db` is gitignored (`.gitignore:45`), so every fresh
   clone silently lost 71% of the corpus. `9 → 31 MEMs`.
2. **`sort -u`** in `handle_knowledge` re-ordered the payload lexicographically
   by MEM ID, discarding three upstream `ORDER BY confidence` clauses. Replaced
   with first-appearance dedupe so seeds precede graph-expanded neighbours.
3. **Quick profile never intersected touched files.** The branch *documented* an
   intersection and never performed one — the touched set was a boolean. Scoped
   arm injected the entire corpus; unscoped arm took the five oldest MEMs by
   allocation order. This is `orchestrator:do`'s default path.
   `31 → 10 MEMs, 12253 → 7282 tokens`.

Regression test `tests/test-scope-filter-multitag.sh` ships with a **proven
negative control**: with the fix stashed it fails 4/11 and exits 1 while its
exclusion assertions keep passing. A filter that includes everything is the same
defect wearing a different hat, and the test rejects both.

### Part A remainder (not yet done)

Ranked, all pure shell/awk, no infrastructure:

| # | Change | Touches |
|---|---|---|
| A4 | Lexical scorer over MEM bodies — the missing exact-token retriever. Reuse `corpus-exhaustion-sweep.sh:186 _extract_terms` + `grep -rIinF` | new `lib/mem-lexical.sh` |
| A5 | RRF fusion over {lexical, scope-specificity, decayed-confidence, recency}, `w/(60+rank)` | new `lib/rrf.sh`, ~25 lines awk |
| A6 | Wire age decay into **ranking**. `compute_effective_confidence()` already exists (`lib/staleness.sh:67`) and **no dispatch caller passes `--use-effective-confidence`** | `scope-filter.sh`, both call sites |
| A7 | Rank-ordered greedy first-fit instead of byte head-drop — port the existing `reference_apply_budget` | `build-context.sh`, `lib/reference-budget.sh` |
| A8 | Neighbour expansion *after* ranking, on winners only, global cap | `lib/section-handlers.sh` |
| A9 | IDF / document-frequency column at rebuild time (177 docs — trivial in awk) | `rebuild-index.sh` |

**Honest scale caveat.** At 31 MEMs the system already injects nearly everything,
so *selection* ranking buys little today. The wins are **ordering** (Lost-in-the-
Middle applies even when you inject all) and the **degradation bugs**. A4–A9
become load-bearing as the corpus grows — which is Part B's job to make happen.
Do not sequence A4–A9 ahead of Part B.

Also live and unfixed: **`query.sh` ranks on `topic:` / `tags[]` and zero MEMs
carry either field** (`query.sh --topic bash` → `no-matches=true`). The only real
ranker in the tree is dead and off the dispatch path.

---

## Part B — Write path (the actual constraint)

### B1. Graph-maintenance classifier as a write gate

The article's fifth prompt, adapted: classify every proposed knowledge write as
`new | duplicate | contradiction | update | uncertain` against the existing
corpus. Deterministic Jaccard pre-filter; LLM only in the ambiguous band.

This is what makes **auto-capture safe**, and auto-capture is what fixes
zero-MEMs-per-milestone. Today `create-entry.sh` validates argument presence and
path collision only; `detect-overlap.sh` always exits 0, is advisory, and is
never called on the write path.

Belongs in **M040's contradiction-gate slice** — same `PASS/FLAG/BLOCK` shape,
same conversus adapter, same human-gated `commands/comments.md` queue — but
widened from `DECISIONS.md`-only to the MEM write path, because that is where the
throughput problem lives.

### B2. Community reports — the missing half of an already-shipped feature

`consolidate-artifacts.sh --cluster` routes into `lib/cluster.sh`, emits
`cluster_id=` / `member=` blocks, detects `conflict: reason=divergent-decision-history`,
and appends `consolidate_cluster` JSONL. It is referenced **nowhere** in
`commands/` or `docs/`.

Clusters emit member IDs and no summary, and nothing consumes a cluster at
retrieval time. Add `--report` → `knowledge/themes/THEME-###.md` + `derived_from`
edges to members. This is a compression tier *above* MEM, serving Principle I
directly, and it reuses machinery that already exists.

### B3. Structure-aware similarity — a recommendation already written in the tree

`lib/jaccard.sh:234` contains its own autopsy: *"the live tree produces zero pairs
at or above A-5's 0.7 default … operationally identical to disabling
clustering,"* and recommends extending the vector with `relates_to[]` edges and
`source_unit` co-occurrence. Nobody has done it. **B2 cannot work until this
does** — clustering currently yields zero clusters.

### B4. Admission gate on writes

Cerebras gates every "burst" against a weighted threshold before it reaches the
store (IDF ≥ 4.0, ≥ 200 chars, has-reactions). The *chunking* does not transfer —
MEMs are already section-shaped — but the **threshold** does. There is currently
no admission gate of any kind on a knowledge write.

### B5. A searchable question field

Cerebras's strongest empirical claim: accuracy rose significantly when a raw
thread was normalised into `{one-line question an engineer would search for,
summary, resolution, systems referenced}` *before* embedding — the raw transcript
is never embedded.

Map onto this tree: a MEM's entire discoverability surface is an **80-char
mid-word slice of its H1**. There is no `question:` field, no `summary:` field,
and no MEM template file at all. Add `question:` + `summary:` to frontmatter and
index `question` as the description column. ~1 day plus a 31-MEM backfill. This
is the single highest-value write-side change and it is independent of B1–B4.

### B6. Derive typed edges instead of hand-authoring them

`sqlite3 knowledge.db "SELECT edge_type, COUNT(*) FROM edges GROUP BY edge_type"`
→ `relates_to|49`. That is the whole graph. `traverse-graph.sh:261-334` ships
typed N-hop traversal over `supersedes` / `cites` / `derived_from` /
`applies_to_field` — all four dark. No step ever *derives* an edge.

Relatedly: `templates/extraction-prompts/tier-2-structured-md.md` requests
normalised frontmatter and typed tag lines; the live shell prompt
(`extract-tier-2-llm.sh:92-106`) asks for none of it. The contract requests graph
edges and the code does not.

---

## Part C — Gate integrity

Confirmed by direct observation during this session, twice, in M031's own
acceptance battery:

```
RESULT: SC-15 pass median=0 budget=800
COMPARE: pre_median_tokens=3500 post_median_tokens=10185
         pre_pass_rate=1.0000 post_pass_rate=1.0000 verdict=wins
```

`SC-15` computes a median over quick-profile JSONL records and passes trivially
against an 800-token budget when there are none. `COMPARE` reports `verdict=wins`
while `post_median_tokens` nearly **tripled**, because the verdict keys only on
pass-rate, which was already 1.0 and cannot move.

Both lines are **byte-identical before and after** a change that cut Quick-profile
injection from 31 MEMs / 12253 tokens to 10 / 7282. Neither gate measured it in
either direction. Of M031's 15 checks, 13 genuinely passed and 2 abstained — and
M031 closed on that battery.

Three further sites were reported by agent analysis and have now been
**independently verified against the tree**. One was overstated; the correction
is recorded here rather than propagated.

**CONFIRMED — `check-must-haves.sh` (Tier 1) passes green having checked nothing.**
A top-level truth sets `PENDING_TRUTH`; only a following `- Check:` sub-item
emits PASS/FAIL or touches the counter. A truth with no sub-item is overwritten
by the next truth — no PASS, no FAIL, no warning, no count. Proven on fixtures:

```
# 4 truths declared, 2 with checks
PASS: truth 'This truth has a real check that PASSES'
FAIL: truth 'This truth has a real check that would FAIL if run'
EXIT=1                          # the 2 uncheckable truths vanished silently

# 3 truths declared, none with checks
EXIT=0                          # zero output; nothing was checked
```

The second fixture declared "The authentication layer is fully implemented and
secure", "All payment flows are correct and audited", and "No data is lost on
concurrent writes". Tier 1 reported success.

**CONFIRMED — `run-commands.sh:67-70` exits 0 `SKIP` on empty
`verification_commands`, and `init-project.sh` never writes the key** (`grep -c`
→ **0** occurrences). The template ships `verification_commands: []`
(`templates/orchestrator-config-default.yml:6`), so every freshly-initialised
project has an empty list and the Tier-2 command runner skips with a
pass-shaped exit.

**CORRECTED — `auto-loop.sh` was overstated.** The guard at `:441-453` *does*
fire: when `total_checks == 0` it counts non-empty, non-header lines in the
verify section and, if any exist, emits `AUTO:VERIFY_NO_CHECKS` and **exits 1**.
The parser-missed-everything case is genuinely covered. The residual gap is
narrower than reported: a task plan declaring **no Verification section at all**
(`section_body_lines == 0`) falls through to `AUTO:VERIFY_PASS checks_passed=0`
and exits 0. The inline comment calls that a "legitimate skip" — so this is a
deliberate design choice, not a bug, and the open question is whether the choice
is still right given the framework's thesis. Treat it as a policy question for
C1, not a defect.

### C1. Vacuity gate

Fail loud on a zero-check verification. A gate that measured nothing must be
distinguishable from a gate that measured something and passed.

### C2. Gate-rot audit

M046/P05 proves a child **cannot tamper** with its gates. Nothing proves a gate
was ever **capable of failing**. There are 3 hand-rolled negative-control
verifiers across ~1,100 (`m016-p03-lint-detects-{backtick,brace,subst}.sh`,
`m013-p03-graphql-call-shape-selftest.sh`) — the repo invented the pattern three
times and never generalised it.

Proposal: a negative-control convention for milestone-blocking verifiers, plus a
`run-doctor.sh` section listing gates with no paired "must fail on seeded defect"
control. `tests/test-scope-filter-multitag.sh` is the reference shape.

### C3. Verification-capability probe (adoptability)

`evaluate.md` counts requirements → Tier C → `autonomy-defaults.yaml` maps
`C: "full"` → the unattended loop unlocks. **Nothing anywhere asks whether the
project can mechanically prove a task is done.** `detect-project.sh:190-192`
already computes a `has_tests` boolean and it is inert — it only interpolates a
cosmetic line into the generated instruction file.

The loop-engineering literature's 4-condition test is precisely the missing gate,
and one of its four ingredients is already on disk. Probe for
package.json scripts / Makefile / cargo / pytest / CI steps at init, populate
`verification_commands`, emit `verification_capability: none|partial|full`, and
gate Tier-C autonomy on it. Add a "When NOT to use this" section to README and
`docs/why-this-exists.md`.

This is simultaneously the highest-leverage **safety** change and the highest-
leverage **adoptability** change, because it stops the framework from promising
autonomous verification to projects that cannot supply it.

---

## Sequencing

1. **Part C verification** (immediate) — confirm or refute the three reported
   sites before designing around them.
2. **C1 vacuity gate** — small, self-contained, unblocks trust in everything else.
3. **B5 question field** + **B3 similarity vector** — independent, cheap, and B3
   unblocks B2.
4. **B1 write gate** — into M040's contradiction slice, widened to MEM writes.
5. **B2 community reports** — into `commands/consolidate.md` Step 2, not a new command.
6. **C3 capability probe** — needs its own design pass; changes onboarding.
7. **A4–A9 ranking** — last. Do not sequence ahead of Part B.

**C2 gate-rot** rides along with whatever milestone next touches `tools/verify/`.

## Explicitly declined

All three agents independently declined the same imports, each citing an existing
decision rather than taste:

- **Neo4j / Cypher / NL→query translation** — recursive CTEs over SQLite already
  do typed N-hop at 31–200 entries. A graph DB is pure adoption tax.
- **Embeddings / vector search / a reranker model** — M044 DQ-2 already settled
  this: deterministic grep is the gate input, embeddings additive-only, never
  gating. At 177 documents the recall problem is bugs and ordering, not semantics.
  The `entries.vector BLOB` stub (`graph-db.sh:74`) should stay unwritten.
- **Postgres / single embeddings table** — contradicts Principle VI. `knowledge.db`
  being gitignored is *already* the cause of the 71% loss; more binary-index
  dependency makes it worse. Correct direction is the opposite: make the flat path
  correct so the DB stays a cache.
- **An LLM planning pass over a source catalogue** — one project, one corpus, ~10
  store globs. Choosing among them costs more than reading all of them.
- **MCP retrieval primitives** — right idea, wrong time. Under CC-only posture,
  skills already are the transport. Revisit at M009 Tier-B when a non-CC consumer
  needs LLM-free retrieval tools.
- **The vendor benchmark numbers** ("18% accuracy / 85% token reduction /
  $0.004") — marketing, and they do not belong in a spec.

## Open questions

1. **M040 / M038 collision** — both define a `feedback/brief` node type
   (M038 §9.8). Whichever ships first owns it.
2. **Does B1 belong to M040, or does the MEM write path deserve its own gate?**
   M040's contradiction gate is `DECISIONS.md`-scoped by design; widening may
   distort its shape.
3. **C3 changes onboarding** — does gating Tier-C autonomy on verification
   capability contradict M033's cold-start promise, or fulfil it?
4. **Should SC-15 be repaired retroactively?** It is M031's closed contract.
   Repairing it may invalidate M031's closure evidence.

## Incidental drift spotted

- `docs/why-this-exists.md:73` still recommends `/orchestrator-do`, which M046/P03
  deprecates. Confirm it is inside the FR-7 migration sweep.
- `tests/test-s07-integration.sh` fails on two script paths referenced in commands
  but absent from disk: `scripts/diagnostics/grep-references.sh`,
  `scripts/knowledge/promote-to-knowledge.sh`. Pre-existing at HEAD.
