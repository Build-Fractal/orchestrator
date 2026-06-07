# Handoff — kick off `orchestrator:specify` for Knowledge-Activation Reliability

**Created:** 2026-06-06 · **For:** a fresh-context agent · **Assumes zero prior context.**

## One-line task
Author a feature spec from the conversus-validated brief, then promote toward a P0 hotfix milestone. The brief is review-ready; the deliberation is done — **do not re-open resolved questions.**

## Inputs (read these first, in order)
1. **Authoritative brief:** `.orchestrator/proposals/knowledge-activation-reliability.md` — this is the `orchestrator:specify` input. §0.5 holds the binding resolutions; §7 holds the revised phasing.
2. **Deliberation record (context, not required reading):** `.orchestrator/conversus/knowledge-activation/summary/final.md` — the cooperative-synthesis output (16 agents, 0 rejections, all 8 DQs resolved). Read its "Actionable Spec Changes" if you need the full rationale behind any decision.
3. Three downstream source submissions (provenance): `/tmp/upstream-knowledge-activation-proposal-2026-06-06.md`, `~/Sites/pbj-central-mono-repo/.orchestrator/knowledge/UPSTREAM-PATCH-HANDOFF-knowledge-activation-reliability-2026-06-06.md`, `~/Sites/archive/.orchestrator/upstream/knowledge-activation-gap.md`.

## How to start
Run the **`orchestrator-specify`** skill with the brief as input. The brief is already gate-shaped (FRs, ACs, NFRs-as-principles, non-goals). Scope the spec to the **P0 hotfix slice first** — that is the part eroding trust on production projects today. Leave the P1 / M040-track items as forward-pointed scope.

## P0 scope to spec (the membership set — unordered set, with an intra-P0 build sequence)
- `FR-1` unify producer/consumer decision+knowledge format (**BUG A**, co-primary)
- `FR-2` compression filter passes flat `## K###` entries
- `FR-3` **bounded** unguarded-pipeline audit (`rebuild-index.sh` + directly-sourced libs only; fix `:117` + any *reproduced* failure, else justify-and-track)
- `FR-4` scope the archive glob — **preserve** the genuine `knowledge/archive/` cold-storage exclusion (`rebuild-index.sh:6` declares it); drop only the bare `*/archive/*` false-match at `scripts/knowledge/resolve-entries.sh:45` + `rebuild-index.sh:74`
- `FR-5` fail-loud + index-free grep fallback for the burning consumer (`build-context.sh`), **budget-bounded** via the M036a governor
- `FR-6` bounded Decisions digest in the Quick-profile inject
- `FR-11` canonical index/db path (single resolver)
- `FR-15` 0-MEM-inject warning on a mature project
- **+ G-1 explicit-decision-capture slice** of FR-8 (one-line `append-decision.sh` row-append at Quick) — ship in the **same change set** as FR-6 so a Quick project never ships an empty-forever Decisions slot
- **+ FR-9 enforcement-warning half** (0-MEM + doctor check for runtime-memory decisions absent from `.orchestrator/`)

**Intra-P0 build sequence:** alarm first (`FR-15` + `FR-5`, no deps) → BUG-A + capture immediately after. Sequence ≠ priority; capture is co-primary, not a fast-follow.

## Locked decisions — DO NOT re-open in the spec (DQ-1…DQ-8, resolved)
- **Index = cache**, raw corpus = truth, guarantee runs **index-free** (grep over raw `knowledge/**/*.md`).
- **DQ-2:** deterministic-grep floor; embeddings additive-only, never gate, never enter the evidence artifact. Forbid nondeterminism (`LC_ALL=C` sort, no wall-clock in artifact bodies, stable file order).
- **DQ-6:** reconcile **three** shapes — producer / consumer-comment / consumer-awk. Round-trip oracle (AC-1) asserts against **observed awk indices `$5` scope / `$6` when**, not the documented column order.
- **DQ-7:** **no net-new capture verb.** FR-7 = M040's on-disk `/orchestrator-capture` + `/orchestrator-promote`, extended with round-trip-confirm + local decision-vs-knowledge classification. Command UX = M040-track; write primitive + confirm mechanism = P0.
- **DQ-8:** `.orchestrator/` is system of record via **graduation**; **live-runtime-memory-read is CUT** (deferred to M009). Enforcement-warning P0; graduation mechanism + SoR docs = M040-track.
- **DQ-5:** corpus-gate **advisory-default**; dispatch-refusing hard gate only on `comments` spec-amendment; per-seam Principle-XIV justification + mandatory deterministic-grep evidence artifact.
- **Principle-I guardrail:** every **read-into-payload** path (FR-5/6/12/14) routes through the M036a token governor; index-free regression asserts hits *within budget*. **Capture-write (disk) is free, unbudgeted.**

## Acceptance oracle to bake into the spec
**AC-1:** capture→rebuild→grep→assert round-trip over the **legacy documented** `append-decision.sh`/`append-knowledge.sh` primitives on a **default-intensity (Quick)** fixture project, **byte-asserting** the resolved row (per [[feedback_fixtures_byte_equality_default]] — byte-equality, not substring). Split the **dynamic** round-trip lane from the **static** byte-equality fixtures (don't force a frozen file to contain a runtime-appended row). Other ACs: heading-less entry → rebuild indexes the rest + warns + exits 0; `archive/`-rooted project → non-empty index + non-zero `:do` quick-inject; empty/stale index → visible degradation warning + grep fallback; 0-MEM-on-mature-project → warning.

## Gotchas / environment
- **Commit form:** use `git commit -F <file>` (Write the message file first). The inline-HEREDOC `-m "$(cat <<'EOF'…)"` form is REJECTED by the M021 PreToolUse shape-guard (AP-008). Single-line `-m "…"` is fine.
- **Bash shape-guard:** no `cd` in compound commands; no `>2`-link compound chains (`a && b && c`) — run separate calls or use `scripts/util/run-probe.sh`.
- **Conversus provider** (if the specify gate invokes conversus): `CONVERSUS_PROVIDER=claude-code` on OAuth — see [[feedback_conversus_provider_claude_code]].
- **Cross-phase hygiene:** reconcile-or-supersede `papercut-doctor-knowledge-gap-surface.md` into ONE consolidated 3-symptom doctor check (0-MEM / vestigial-index / runtime-memory-divergence) — don't create a second overlapping doctor surface.
- **Roadmap note:** this is a demand signal toward M040, but M040's formal trigger is borderline-**unfired** (needs ≥5 inbox reports; this supplies one). The P0 primitive ships **milestone-independent** — do not block it on M040 entering the queue. Optional roadmap-hygiene P3: annotate `M040-ambient-feedback-loop.md` that trigger conditions #2 + #3 (not #4) are met.

## Verified upstream anchors (all re-confirmed against live source 2026-06-06)
`rebuild-index.sh:11` (`set -euo pipefail`), `:40` (guarded sibling `|| true`), `:117` (unguarded grep — B-1), `:74` (archive glob) · `build-context.sh:198-208` (silent `head -5` — B-2), `~:223` (Quick drops Decisions) · `append-decision.sh:93` (producer row) · `scope-filter.sh:351` (comment) / `:353-354` (awk `$5`/`$6` — B-3) · `resolve-entries.sh:45` (archive glob) · `intensity-knowledge.sh:92` (Quick captures nothing — G-1).

## State
Branch `m034-interactive-review-gates`. Brief + synthesis + this handoff are uncommitted on disk. Nothing has been committed for this work yet — the next agent may want to commit the proposal artifacts before/after specify.
