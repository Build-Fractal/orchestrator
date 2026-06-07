# Proposal: Knowledge-Activation Reliability

*Consolidated upstream brief — synthesized 2026-06-06 from three independent downstream diagnoses, ground-truthed against upstream bundle source.*

**Status:** draft for `orchestrator:specify` intake · **Candidate placement:** P0 reliability hotfix (proven bugs) + activation milestone folding into M040 (see §8)
**Type:** design-defect class + feature request — affects EVERY project's core value proposition
**Severity:** High — on production projects the knowledge base silently stopped activating for ~1 month / two full milestones, and **nobody was told.**

---

## 0. Provenance of this brief

Two downstream projects, working independently, root-caused the same disease from opposite ends and submitted upstream recommendations:

- **Source 1 — `pbj-central-mono-repo`** (two framings: a proposal + a patch-handoff). Diagnosed the **index/rebuild pipeline** failing silently. Thesis: *silent degradation is the enemy; the index is a cache, the raw corpus is truth, the activation guarantee must run index-free.*
- **Source 2 — a `quick`-intensity project rooted at `~/Sites/archive/`**. Diagnosed the **capture→store→inject round-trip** as broken even when the index works. Thesis: *the store the injector READS is not the store where decisions LAND.* Surfaced three concrete bugs (A/B/C) plus a two-store divergence.

Every claim below was **re-verified against this repo's actual source** before inclusion (file:line citations are live as of 2026-06-06). This is not downstream hearsay — it is a confirmed upstream defect class.

---

## 0.5 Conversus cooperative synthesis — adopted resolutions

This brief was run through a **cooperative conversus deliberation** (2026-06-06) — three agents (`pipeline-reliability` advocating the fail-loud / index-as-cache stance, `activation-loop` advocating the capture→inject round-trip, `framework-steward` advocating constitution + roadmap coherence) across 5 phases / 16 agents. Full record: `.orchestrator/conversus/knowledge-activation/summary/final.md`. It converged unusually hard: **0 recommendations rejected, 0 hard disputes remaining, all 8 design questions resolved.** Three dangerous contradictions surfaced and dissolved cleanly; the adopted resolutions below are now binding on the FR set and supersede the open-question framing in §4 and the phasing in §7.

**Design-question resolutions (DQ-1…DQ-8 — now CLOSED):**

| DQ | Resolution |
|---|---|
| DQ-1 | **Demote the index to a cache.** Every consumer must have an index-free path. Full retrofit is P1; the *burning* consumer (`build-context.sh`) gets it in P0. |
| DQ-2 | **Deterministic-grep floor; embeddings additive-only.** Grep over raw `knowledge/**/*.md` is *the* guarantee and the *sole* input to the corpus-gate evidence artifact. Embeddings, if ever added, never gate and never enter the receipt. Forbid nondeterminism vectors (`LC_ALL=C` sort, no wall-clock in artifact bodies, stable file order). **No longer an open question.** |
| DQ-3 | **Rebuild-then-warn-if-still-bad** on stale; never silent auto-rebuild mid-dispatch. |
| DQ-4 | **Minimal provenance header always in payload + full provenance to stderr/evidence-artifact.** Hard gate only on the highest-stakes path. |
| DQ-5 | **Advisory-default everywhere; dispatch-refusing hard gate only on `comments` spec-amendment.** Each seam ships incrementally with a one-line Principle-XIV justification + mandatory deterministic-grep evidence artifact. |
| DQ-6 | **Reconciles THREE shapes, not two** — producer / consumer-comment / consumer-awk. The round-trip oracle asserts against the *observed awk field indices* (`$5` scope / `$6` when). Canonical winner locked by AC-1; init-header + append script + consumer comment + consumer awk re-aligned in one change set (CI-checked). |
| DQ-7 | **No net-new capture verb.** FR-7 = M040's already-on-disk `/orchestrator-capture` + `/orchestrator-promote`, extended with round-trip-confirmation + local decision-vs-knowledge classification. Command UX is M040-track; the write primitive + confirmation mechanism ship P0. |
| DQ-8 | **`.orchestrator/` is the system of record via graduation; live-runtime-memory-read is cut entirely** (deferred to M009 runtime-memory-adapter work). Enforcement-warning (0-MEM + doctor check) ships P0; graduation mechanism + the SoR documentation land the M040 track. |

**Three resolved contradictions (the load-bearing fusions):**

1. *"A resilient, byte-locked, index-free rebuild over a mis-columned (B-3) or never-written (G-1) store still injects nothing."* → **BUG A + explicit-capture-by-default are pulled into P0 as co-primary.** `pipeline-reliability` conceded this follows directly from its own "index is a cache, raw corpus is truth" principle: a truth-layer failure outranks a cache-layer failure. One fixture corpus locks both capture-format and grep-fallback; neither ships green alone.
2. *"A new capture command duplicates M040's `/orchestrator-capture`."* → **Decouple command-NAME (use M040's design) from ship-TIMING (primitive + mechanism ride P0; discoverable UX lands M040-track).** This also dissolved the reciprocal "does *fold into M040* mean ship or defer?" worry — all three verified M040's formal demand trigger is borderline-**unfired** (§0 supplies one inbox report; trigger #4 needs ≥5), so the P0 primitive ships on a committed timeline regardless of M040's queue position.
3. *"Read runtime agent memory directly."* → **Withdrawn** in favor of graduation into `.orchestrator/`, because a live-read couples dispatch to CC's `MEMORY.md` shape (Principle VI / latent M009 debt) and puts a nondeterministic source on the guarantee path.

**Cross-cutting guardrail (Principle I, both directions):** the fix must not trade a silent *under*-inject for a silent *over*-inject. Every **read-into-payload** path (FR-5 retrieval, FR-6 digest, FR-12/FR-14) routes through the existing **M036a token-budget governor** (SC-3/SC-7) and the index-free regression asserts hits *within budget*. **Capture-write (disk row-append) is free and unbudgeted.**

---

## 1. Thesis

The orchestrator's central promise is: *the agent always acts with the full, stored context — decisions, SME feedback, and learnings are reliably activated when work happens.* In practice that promise is **silently hollow** along the entire pipeline. Two load-bearing principles fix the class:

> **P-A — Silent degradation is the enemy.** Every knowledge-activation path must fail **loud** (visible warning + provenance), never fail **open** (silently under-load) and never fail **closed-silent** (silently abort). An agent that *knows* it is under-informed behaves correctly; one that is silently under-informed produces confident, wrong work.

> **P-B — Index is a cache; the raw corpus is the source of truth; the guarantee runs index-free.** The always-available activation mechanism (today: grep-based corpus-gate) must operate directly on raw files. The index makes activation *fast*; it must never be what makes activation *possible*.

A third principle emerges from Source 2's findings:

> **P-C — One system of record, and the happy path must work.** The store the agent writes to and the store dispatch reads from must not silently diverge. Calling the *official* capture commands must produce entries the injector can actually read. Producer and consumer are one contract, covered by a round-trip test.

---

## 2. Evidence — verified upstream defects

### Pipeline integrity bugs (proven, reproducible, live in this repo)

| # | Defect | Upstream location | Effect |
|---|---|---|---|
| **B-1** | rebuild fails **closed-silent**: description-extraction grep is unguarded under `set -euo pipefail`, while sibling `fm_field()` ends in `\|\| true` | `scripts/knowledge/rebuild-index.sh:11` (`set -euo pipefail`), `:117` (unguarded grep), cf. `:40` (guarded sibling) | One heading-less entry aborts the *entire* rebuild mid-loop, zero output, exit 1. ~146 chunks sat unindexed for ~1 month. |
| **B-2** | consumer fails **open-silent**: empty index → silent "first-5 MEM IDs" fallback, no warning, no provenance | `scripts/dispatch/build-context.sh:198–208` | The command operators use *specifically to guarantee context* injected near-nothing and said nothing. |
| **B-3 (BUG A)** | **producer/consumer format mismatch**: capture command writes a column order the injector can't parse | `append-decision.sh:93` writes `\| ID \| When \| Scope \| Decision \| Choice \| Rationale \| Revisable \|`; `scope-filter.sh` `filter_decisions` *comment* (`:351`) claims `1=ID, 2=Decision, 3=Choice, 4=Scope, 5=When`, but the executing `awk -F'\|'` (`:353-354`) reads `scope_col=$5`, `when_col=$6` — the leading pipe makes `$1` empty and shifts every field by one | The official capture command produces rows the injector mis-reads — `$5`/`$6` land on the producer's Choice/Rationale text, breaking the `M###/P##` scope match. **DQ-6 must reconcile THREE shapes** (producer, consumer-comment, consumer-awk), and the round-trip oracle asserts against the *observed awk indices*. `append-knowledge.sh` ↔ `filter_knowledge` (`## K###` shape) has the parallel mismatch. |
| **B-4 (BUG B)** | **archive skip-glob false-match**: bare `*/archive/*` matches a project's own root path | `resolve-entries.sh:45`, `rebuild-index.sh:74` | Any project rooted under a dir named `archive` (e.g. `~/Sites/archive/`) indexes **0 entries** — index path AND `:do` quick-inject both dead. |
| **B-5 (BUG C)** | **compression filter drops flat knowledge**: `kf_filter_stream` only passes entries with `---` frontmatter | `compression.knowledge_filter` | Every flat `## K###` `KNOWLEDGE.md` entry → "(no qualifying knowledge entries)". The shape the consumer parses and the filter's requirement are mutually inconsistent. |

### Design gaps (the round-trip is broken even with the bugs fixed)

| # | Gap | Upstream location | Effect |
|---|---|---|---|
| **G-1** | Quick intensity **never captures** decisions/knowledge/index | `intensity-knowledge.sh:92` Quick → `write-summary.sh` only | Default-intensity projects NEVER populate the stores the injector reads. |
| **G-2** | Quick-profile inject **drops the Decisions section entirely** | `build-context.sh` (~line 223 per Source 2) | Tiny changes — the most dangerous place to forget a prior decision — get the *least* context. |
| **G-3** | **Two-store divergence**: injector never reads runtime agent memory; decisions land in runtime memory + `execution-log.jsonl` `note` fields, neither of which dispatch reads | `build-context.sh` knowledge/decisions assembly | Two milestones, 50+ locked decisions, every inject resolved to **0 MEMs**, no warning. |
| **G-4** | **No chat-level capture command**: `comments.md` ingests only GitHub/Giscus (needs M013/M012). Primitives exist (`append-*`, `rebuild-index`, `consolidate`) but must be invoked by hand | `commands/comments.md` | "SME said X in chat → durable, re-injected knowledge" has no turnkey path. |
| **G-5** | **Corpus manifest sweeps the wrong things**: lists `MEMORY.md` (a link index, not content) + empty knowledge files; globs are repo-root-relative, can't reach runtime-memory paths | `templates/corpus-store-manifest.yml` | Read-before-ask reads near-nothing. |
| **G-6** | **Thin-metadata fail-open**: post-rebuild, REF chunks index with empty `scope_tags` + bare-ID descriptions (files lack `# <id>:` headings), so scope-match can't surface them — index is "green" but unqueryable | `ingest-reference.sh` / `extract-reference.sh` ingest path | A subtler fail-open: index exists, reports healthy, still effectively empty for that material. |
| **G-7** | **No observability / fail-loud**: no inject-size surface, no 0-MEM warning, no freshness contract, no provenance header | dispatch path, `orchestrator:doctor` | Degradation produces no signal. The root failure mode behind every bug above. |

---

## 3. Proposed changes (unified FR set)

Grouped by theme; each tagged with the principle it serves. The first block (T1–T3) is **P0 hotfix-grade** — these are proven, actively-burning bugs and should ship independent of any milestone sequencing.

### T1 — Producer/consumer contract integrity (P-C)
- **FR-1** — Unify `append-decision.sh` / `append-knowledge.sh` output with `filter_decisions` / `filter_knowledge` expected shapes. One canonical format; the init-time empty `DECISIONS.md` header must match it. **Round-trip test** is the acceptance oracle (fixes B-3). *(Decision needed: which column order wins — see DQ-6.)*
- **FR-2** — Fix `compression.knowledge_filter` (`kf_filter_stream`) to pass flat `## K###` entries, or unify the knowledge shape so frontmatter is not required (fixes B-5).

### T2 — Resilient rebuild (P-A, "resilience over atomicity")
- **FR-3** — `rebuild-index.sh`: per-entry try/skip/warn; never abort the whole rebuild on one bad entry. Guard line 117; **audit the whole script for every other unguarded command under `set -e`/`pipefail`**. Emit per-skip to stderr + final summary `INDEXED: N / SKIPPED: M [ids/paths]`. Exit non-zero only on catastrophic failure (missing `knowledge/`, DB write failure) (fixes B-1).
- **FR-4** — Scope the archive skip to the orchestrator's own subtree (e.g. `.orchestrator/**/archive/`), not a bare `*/archive/*` against absolute paths, in both `resolve-entries.sh` and `rebuild-index.sh` (fixes B-4).

### T3 — Consumers fail loud + index-free fallback (P-A, P-B)
- **FR-5** — `build-context.sh` and every index reader: detect empty/missing/stale index and (a) emit a visible WARNING into the **injected payload** *and* stderr; (b) **prefer a grep-over-raw-files fallback** over a silent first-N; (c) stamp the payload with a **knowledge-provenance header** (`source: index|grep-fallback|degraded`, `index_age`, `entries_considered`) (fixes B-2).
- **FR-6** — Stop omitting the Decisions section from the Quick-profile inject; include at least a compact decisions digest (fixes G-2).

### T4 — Capture by default, regardless of intensity (P-C — the missing loop)
- **FR-7** — Add a turnkey capture command (`orchestrator:note` / `orchestrator:decide`, or a `--decision` / `--feedback` mode on `orchestrator:do`) that in one step: appends to `DECISIONS.md` (+ `KNOWLEDGE.md` for reusable patterns) → runs `rebuild-index.sh` → confirms the entry resolves in an inject. **Single highest-leverage fix** for Source 2 (fixes G-4). *(Decision needed: new command vs `:do` mode — see DQ-7.)*
- **FR-8** — Never drop *explicit* decisions at Quick: either always run `append-decision.sh` for explicit decisions even at Quick, and/or at phase close auto-graduate decision-bearing `execution-log.jsonl` `note` fields into `DECISIONS.md` regardless of intensity (fixes G-1).

### T5 — One system of record (P-C)
- **FR-9** — Resolve the runtime-memory ↔ `.orchestrator/` divergence: either (a) `build-context.sh` / do-entry optionally reads the runtime's agent memory (configurable path), or (b) ship `orchestrator:ingest-memory` (or extend `consolidate`) that pulls runtime-memory decisions into `.orchestrator/`. **Document `.orchestrator/` as the system of record** with runtime memory as a convenience cache. Silent divergence must not be possible by default (fixes G-3). *(Decision needed — see DQ-8.)*

### T6 — Index demoted to cache; freshness contract (P-B)
- **FR-10** — Index freshness check comparing index mtime/content-hash against the newest `knowledge/**/*.md`. Wire into `orchestrator:doctor` (report) and the dispatch path (act). Make "is the index current?" a first-class, checkable invariant (fixes part of G-7). *(Decision needed: auto-rebuild vs warn-only — see DQ-3.)*
- **FR-11** — Canonicalize the index/db path: single `get_index_path` / `get_db_path` resolver everywhere; remove/alias vestigial `.orchestrator/` copies; document the canonical location.

### T7 — Activation-by-default on high-damage paths (P-A, P-B)
- **FR-12** — Bake corpus-exhaustion (the **index-independent grep primitive**) into the entry points that consume feedback or emit human-facing questions/claims:
  - `orchestrator:comments` — before classifying or proposing a spec amendment, sweep the corpus and **surface conflicting prior decisions in the proposal** (today only the triage-question path routes through corpus-gate);
  - `:discuss` / `:specify` / `:plan-phase` / `:materials-intake` — corpus-gate as a pre-gate on every operator-facing question;
  - always emit the corpus-gate **evidence artifact** as the trust receipt (deterministic grep log → a human or agent can *verify* the check ran). *(Decision needed: hard vs advisory — see DQ-5.)*
- **FR-13** — Default corpus manifest sweeps decision/knowledge **content** (not a link-index or empty files) and tolerates runtime-memory locations — or guarantees content is graduated into swept files (fixes G-5).
- **FR-14** — Ingest (`ingest-reference.sh` / `extract-reference.sh`) writes canonical `# <id>: <title>` headings + populates `scope_tags`, so REF chunks are scope-discoverable; AND the activation mechanism **degrades to deterministic content/grep retrieval** when metadata is thin, so quality is not hostage to hand-authored tags (fixes G-6). *(Decision needed: grep vs embeddings for the thin-metadata fallback — see DQ-2.)*

### T8 — Observability + fail-loud (P-A)
- **FR-15** — Surface inject size everywhere (`knowledge: N MEMs / X tokens`) and **WARN when an inject resolves to 0 MEMs on a project that already has milestones/decisions on disk**. Add an `orchestrator:doctor` check: "decisions exist in execution-log/summaries but `DECISIONS.md`/`KNOWLEDGE-INDEX.md` are empty → knowledge not activated" (fixes G-7).

---

## 4. Design questions — RESOLVED by the cooperative synthesis (§0.5)

> **All eight design questions below were resolved in the 2026-06-06 conversus deliberation.** The resolutions are recorded in §0.5 and are binding. The original open framing is preserved here for audit. Do **not** re-open these without new evidence.

- **DQ-1 — Index status.** Formally demote the index to "cache, may be absent" (every consumer must have an index-free path), or keep it as an optimization behind a hard freshness gate? *(Sources lean: demote.)*
- **DQ-2 — Thin-metadata fallback.** Substring/grep (deterministic, free, offline, preserves the reproducible evidence artifact) vs semantic/embeddings (higher recall on paraphrase, but nondeterministic, costs tokens, breaks the deterministic trust receipt)? Or grep-floor + embeddings-boost? *(Source 1 lean: keep the guarantee deterministic; embeddings only additive.)*
- **DQ-3 — Staleness response.** Auto-rebuild on stale (convenient; adds latency + nondeterminism mid-dispatch) vs warn-only (safe; relies on operator) vs rebuild-then-warn-if-still-bad?
- **DQ-4 — How loud is "loud"?** stderr only / payload provenance header / hard gate that refuses to dispatch on a degraded index? *(Source 1 lean: header always + stderr; hard gate only for highest-stakes paths.)*
- **DQ-5 — Gate strength on question/claim paths.** Corpus-exhaustion as a hard gate (blocks until swept — friction, but operators explicitly value not being asked already-answered questions) vs advisory (warns, never blocks)?
- **DQ-6 — Canonical decision format.** Which column order becomes the contract — the producer's (`append-decision.sh`) or the consumer's (`filter_decisions`)? Whichever loses gets rewritten; the round-trip test locks it.
- **DQ-7 — Capture surface.** New first-class command (`orchestrator:note`/`:decide`) vs a `--decision`/`--feedback` mode on `orchestrator:do`?
- **DQ-8 — System of record.** Read runtime memory directly (configurable path) vs ingest-memory graduation step? Trade-off: live-read avoids divergence but couples dispatch to a runtime-specific memory shape; graduation keeps `.orchestrator/` self-contained but can lag.

---

## 5. Acceptance criteria (merged)

1. **Round-trip:** a decision/knowledge entry written by the official capture command is provably resolved by `build-context.sh`'s `filter_decisions`/`filter_knowledge` — producer and consumer formats unified (B-3, B-5).
2. **Resilient rebuild:** a corpus with ≥1 malformed (heading-less, tag-less) entry rebuilds successfully, indexes all valid entries, warns on skips, exits 0 (B-1).
3. **Path-collision:** a project whose root path contains a dir named `archive` builds a non-empty index and a non-zero `:do` quick-inject (B-4).
4. **Fail-loud consumer:** with an empty/stale/missing index, a dispatch still receives relevant context via the index-free path, and the payload visibly states it ran degraded; no consumer can silently inject "first-N" without a provenance flag (B-2).
5. **Capture-by-default:** on a fresh project at ANY intensity, an operator/SME decision captured via the new command appears in `DECISIONS.md`, is indexed, and is provably present in the next dispatch's inject (G-1, G-4).
6. **Quick milestone non-empty:** a `quick`-intensity project that completes a milestone ends with non-empty `DECISIONS.md` + `KNOWLEDGE-INDEX.md` (auto-graduated), next inject > 0 MEMs (G-1).
7. **0-MEM warning:** a 0-MEM inject on a project with prior milestones emits a visible warning (G-7).
8. **Corpus-gate on real content:** `orchestrator:comments` surfaces a planted conflicting prior decision when triaging a contradicting feedback item — without the index present — and the gate sweeps real decision/knowledge content, not an empty index (G-5, FR-12).
9. **Reproducible receipt:** the corpus-gate evidence artifact is emitted and reproducible (same inputs → same log).
10. **System of record documented:** docs state plainly which store is authoritative and how runtime memory relates to it (G-3).

---

## 6. Relationship to existing roadmap

This brief is **not** a net-new concern invented from nothing — it is the reliability spine under three already-queued items, and it gives them a concrete demand signal:

- **`orchestrator-corpus-gate`** (shipped) — FR-12/FR-13/FR-14 harden and default-on the existing primitive. The gate's index-independence is the load-bearing asset; verify and preserve it.
- **M040 (ambient feedback loop)** — FR-7 (capture command) and FR-8 (auto-graduate) ARE M040's "frictionless capture inbox" + "return path." T4/T5 should likely fold into M040 rather than ship standalone. *"A knowledge system without a return path is a graveyard with good folders."*
- **M034 (interactive review gates — the current branch)** — FR-12's "surface conflicting prior decisions in the proposal" composes with the decision-packet shape; M040's contradiction gate emits M034 packet shape.
- **M038 (living documents)** — the freshness contract (FR-10) and provenance (FR-5) are living-doc primitives.
- **`papercut-doctor-knowledge-gap-surface.md`** — FR-15's doctor check overlaps; reconcile.

---

## 7. Phasing — REVISED by the synthesis (P0 expanded)

The proven bugs are actively eroding trust on production projects **today**. The synthesis expanded P0 beyond the original "pipeline bugs only" cut: a hardened rebuild over a **mis-columned (B-3)** or **never-written (G-1)** store still injects nothing, so the capture-format fix and the explicit-decision-capture slice are **co-primary** P0 members. P0 is an **unordered membership set** with an **intra-P0 build sequence** (sequence ≠ priority).

- **P0 — Knowledge-Activation Hotfix (ship now, milestone-independent).** Membership set:
  - `FR-1` (unify producer/consumer format — **BUG A, co-primary**), `FR-2` (compression filter passes flat `## K###`), `FR-3` (**bounded** audit — `rebuild-index.sh` + directly-sourced libs only; fix `:117` + any *reproduced* failure, else justify-and-track), `FR-4` (scope the archive glob; **preserve** the genuine `knowledge/archive/` cold-storage exclusion that `rebuild-index.sh:6` declares — drop only the bare `*/archive/*` false-match at `scripts/knowledge/resolve-entries.sh:45` + `rebuild-index.sh:74`), `FR-5` (fail-loud + index-free grep fallback for the *burning* consumer, **budget-bounded** via M036a), `FR-6` (bounded Decisions digest in Quick inject), `FR-11` (canonical index/db path), `FR-15` (0-MEM warning).
  - **+ the G-1 explicit-decision-capture slice of FR-8** (a one-line `append-decision.sh` row-append at Quick) shipped in the **same change set** as FR-6 so a Quick project never ships a Decisions slot that is empty-forever.
  - **+ the FR-9 enforcement-warning half** (0-MEM-on-mature-project + doctor check for runtime-memory decisions absent from `.orchestrator/`).
  - **Intra-P0 build sequence:** alarm first (FR-15 + FR-5, no dependencies, ship day one) → BUG-A + capture immediately after. The capture-confirm round-trip (AC-1) literally needs an observable inject path, so the alarm is a build *prerequisite*, not a higher *priority*.
- **P1 / M040-track — Activation Build.** FR-7 (= M040's `/orchestrator-capture` + `/orchestrator-promote` slice pulled forward — primitive in P0, **command UX M040-track**), the FR-8 auto-graduate half (`decision:`-tagged notes at phase-close), the FR-9 graduation mechanism + "`.orchestrator/` is system of record" documentation, FR-10 (content-hash freshness contract + rebuild-then-warn policy), FR-12 (corpus-gate **advisory-default**, hard gate only on `comments`), FR-13 (manifest sweeps real content — bound to the FR-9 graduation step), FR-14 (ingest headings/`scope_tags` + thin-metadata grep fallback). All read-into-payload paths budget-governed; the provenance header pinned as a versioned byte-contract with a `resolved-id` surface.
- **Cross-phase hygiene.** Reconcile-or-supersede `papercut-doctor-knowledge-gap-surface.md` into the **single** consolidated 3-symptom doctor check (0-MEM / vestigial-index / runtime-memory-divergence) before intake — no second overlapping doctor surface.

---

## 8. One-paragraph compression (for an agent prompt)

> Harden the orchestrator's knowledge-activation pipeline so it can never silently degrade, and close the capture→store→inject loop. Proven upstream bugs (all verified at file:line): `rebuild-index.sh:117` aborts the whole rebuild on one heading-less entry (unguarded grep under `set -e`/`pipefail`); `build-context.sh:208` then silently injects "first-5" off the empty index; `append-decision.sh:93` writes a column order `scope-filter.sh:343` can't parse (the official capture command produces unreadable rows); the bare `*/archive/*` skip-glob (`resolve-entries.sh:45`, `rebuild-index.sh:74`) zeroes the index for any project rooted under a dir named `archive`; the compression filter drops flat `## K###` knowledge; Quick intensity captures nothing and the Quick inject drops Decisions; and decisions land in runtime memory the injector never reads (two-store divergence → 0-MEM injects with no warning). Fix the class: unify producer/consumer formats with a round-trip test; per-entry skip-and-warn rebuild; scope the archive glob; consumers that fall back to deterministic grep over raw files and stamp a provenance/freshness header; a turnkey capture command that always indexes regardless of intensity; auto-graduate execution-log decision notes at phase close; declare `.orchestrator/` the system of record and bridge runtime memory; corpus-exhaustion default-on for `comments` and operator-facing questions with a reproducible evidence artifact; freshness contract in `doctor` + dispatch; and a 0-MEM-inject warning on mature projects. Guiding principles: silent degradation is the enemy (fail loud, never fail open or closed-silent); the index is a cache, the raw corpus is truth, the guarantee runs index-free; one system of record, and the happy path must work.
