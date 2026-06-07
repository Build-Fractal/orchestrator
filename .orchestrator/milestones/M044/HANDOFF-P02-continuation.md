# Handoff — continue M044 (knowledge-activation-reliability) from P02

**Created:** 2026-06-07 · **For:** a fresh-context agent · **Assumes zero prior context.**

## One-line task
Continue building the M044 P0 hotfix slice. **P01 (the fail-loud activation floor) is DONE, verified, and committed.** Your job is **P02 → P03 → P04**, then milestone close. The spec is authoritative; the design questions are resolved and binding — **do not re-open them.**

---

## 0. START HERE (read in this order, assume zero prior knowledge)

1. `specs/045-knowledge-activation-reliability/spec.md` — the authoritative spec (10 FRs, 12 SCs, 5 user stories). **CON-1 holds the binding DQ-1…DQ-8 resolutions — DO NOT re-open them.**
2. `.orchestrator/milestones/M044/M044-CONTEXT.md` — finalized context draft: AD-1…AD-11 (the binding architectural decisions), the P0 membership set + intra-P0 build sequence, the knowledge-layer boundary (M044 vs M036a/M040/M009).
3. `.orchestrator/milestones/M044/M044-ROADMAP.md` — the 4-phase DAG + boundary maps. **P01 is checked off.**
4. `.orchestrator/milestones/M044/M044-PLAN-TIME-RESOLUTIONS.md` — #Q-1…#Q-4 resolved with dogfood evidence. **#Q-1 (column order) is the crux of P02 — read it carefully.**
5. `.orchestrator/milestones/M044/phases/P01/P01-SUMMARY.md` — what P01 shipped + the lib/verifier patterns you will reuse.
6. `.orchestrator/proposals/knowledge-activation-reliability.md` — the upstream brief (§2 the file:line bug evidence, §7 phasing). Context, not required.

---

## 1. Branch & environment — READ THIS, there is history

- **Work on branch `m044-knowledge-activation-reliability` (PR #11), in the main working tree** (`/Users/brettkellgren/Sites/orchestrator`). Commit everything here; PR #11 is the full M044 PR (operator decision: commit-on-m044, smoke-test + merge PR #11 and the M034 PR #12 together at the end).
- **History you must know:** this branch was cut mid-M034 and a parallel M034 agent caused a shared-working-tree branch-collision (my early commits first landed on `m034`, were recovered to `m044` via a temp worktree). **That agent is now DONE** and will not switch the tree again. The collision is fully resolved. The stale local `m034-interactive-review-gates` branch still carries 3 duplicate M044 commits but is inert — ignore it.
- **Defensive habit (cheap insurance):** run `git branch --show-current` and confirm `m044-knowledge-activation-reliability` **before every commit**. See memory `feedback_shared_tree_branch_collision`.
- **`find-active-milestone.sh` returns M034 noise** on this tree — always target **M044 explicitly** in plan-phase/dispatch; never rely on auto-resolve.

### Bash environment gotchas (these WILL bite you)
- **Commit form:** `git commit -F <file>` (Write the message file first). The inline-HEREDOC `-m "$(cat <<'EOF'…)"` form is REJECTED by the M021 PreToolUse shape-guard (AP-008). Single-line `-m "…"` is fine.
- **Shape-guard rejects compound chains >2 segments** (`a && b && c`, and even `a; b; c`) and `cd` inside compound commands. Run separate Bash calls, or write a throwaway script and run it. This bites `git add ... && git commit`, `echo ...; cat ...`, etc. — split them.
- **`bash -c '<compound body>'` is rejected** (AP-014). For multi-step probes, Write a small script to `/tmp/foo.sh` and `bash /tmp/foo.sh`.
- All scripts are **bash 3.2** (macOS); no associative arrays, no `mapfile`.

---

## 2. What is DONE (P01 — do not redo)

`m044` HEAD = `735eeb0c`. Commit chain:
```
735eeb0c exec(M044/P01/T05) + close P01
7aed3a4d exec(M044/P01/T04): consolidated DOCTOR:KNOWLEDGE_ACTIVATION
ecff138f exec(M044/P01/T03): inject-size + 0-MEM-on-mature warning
047009bc exec(M044/P01/T02): fail-loud grep fallback + provenance header
d93763ec exec(M044/P01/T01): canonical get_index_path routing
58008b00 plan(M044/P01)
425932ff plan(M044): evaluate + roadmap + context + #Q resolutions
f44773c4 spec(M044)
```

P01 shipped (all verified — `bash tools/verify/m044-p01-phase-suite.sh` → `BATTERY: pass=7 fail=0`; `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M044/phases/P01` all PASS):
- **FR-11**: `scripts/dispatch/build-context.sh` resolves the index via canonical `get_index_path()` (`scripts/knowledge/lib/index-utils.sh`) at both sites; literal joins are guarded fallbacks only.
- **FR-5**: new **`scripts/dispatch/lib/knowledge-provenance.sh`** — `kp_index_state` (missing|empty|stale|present via mtime), `kp_index_age`, `kp_grep_fallback` (deterministic `LC_ALL=C` grep over raw `knowledge/**/*.md`, archive-excluded, budget-bounded via `reference_apply_budget` from `scripts/dispatch/lib/reference-budget.sh`), `kp_is_mature`, `kp_emit_header` (always-on `knowledge_provenance:` block, `provenance_version: 1`). Wired into build-context.sh: degraded index → grep fallback + WARNING (payload+stderr); header stamped always.
- **FR-15 / FR-9-enforcement**: inject-size `knowledge: N MEMs / X tokens`; 0-MEM-on-mature warning; **`scripts/diagnostics/check-knowledge-activation.sh`** (one `DOCTOR:KNOWLEDGE_ACTIVATION status=ok|warn|fail symptoms=…`, registered advisory in `run-doctor.sh`, documented in `commands/doctor.md`). Papercut `papercut-doctor-knowledge-gap-surface.md` annotated "reconciled into M044/FR-15".

> **Live reality you'll observe:** the repo's OWN `KNOWLEDGE-INDEX.md` is genuinely **stale**, so build-context.sh now grep-falls-back loudly on it. That's correct behavior, not a bug. **P03's FR-3 rebuild fix + a `bash scripts/knowledge/rebuild-index.sh` run will clear it.**

---

## 3. Locked decisions — DO NOT re-open (CON-1; DQ-1…DQ-8 + #Q-1…#Q-4)

- **Index = cache, raw corpus = truth, guarantee runs index-free** (grep over raw files). Embeddings never (DQ-2). Determinism on the guarantee path: `LC_ALL=C`, stable order, **no wall-clock in artifact bodies** (CON-3).
- **Principle-I budget guardrail (CON-2):** every **read-into-payload** path routes through the M036a `reference_apply_budget` governor; **capture-write (disk row-append) is free/unbudgeted.**
- **No net-new capture verb** (DQ-7): extend the legacy `append-decision.sh` primitive only. **Live runtime-memory read is CUT** (DQ-8) — P0 ships only the enforcement warning (done in P01).
- **#Q-1 (RESOLVED, the P02 crux): consumer-order wins; rewrite the producer; forward-only.** Details in §4.
- **#Q-2/#Q-3/#Q-4** already resolved AND shipped in P01 (mtime staleness; one doctor surface; `provenance_version: 1`).

---

## 4. P02 — Producer/consumer format unification + round-trip oracle (BUG-A, co-primary)

**Goal:** one canonical decision/knowledge format so the official capture command writes rows the dispatch consumer can actually read. **This is B-3, the highest-value bug in the milestone.** Depends on P01 (done).

### The exact divergence (re-confirm against live source first)
`awk -F'|'` on a row `| A | B | C | D | E | F |` yields `$2=A $3=B $4=C $5=D $6=E $7=F` (leading `$1` is empty).

| Shape | Location | Order | After `awk -F'|'` |
|---|---|---|---|
| **producer** | `scripts/knowledge/append-decision.sh:93` | `ID \| When \| Scope \| Decision \| Choice \| Rationale \| Revisable` | `$5`=Decision, `$6`=Choice ❌ |
| **init header** | `scripts/lifecycle/scaffold.sh:89` | `# \| When \| Scope \| Decision \| Choice \| Rationale \| Revisable?` | (same producer-order) ❌ |
| **consumer comment** | `scripts/dispatch/scope-filter.sh:343` (data-row) + `:351` (col map) | `ID \| Decision \| Choice \| Scope \| When \| Rationale` | `$5`=Scope, `$6`=When ✅ |
| **consumer awk** | `scope-filter.sh:353-354` | reads `scope_col=$5`, `when_col=$6` | — (the fixed reference) |

**Per CON-6/AD-6 the oracle asserts the observed awk indices (`$5`=scope / `$6`=when). The consumer-awk + the `:343` data-row comment already satisfy that. The PRODUCER and the INIT HEADER are the losers → rewrite them to consumer-order. Forward-only (no migration of existing rows — pre-existing producer-order rows already never resolved; that IS the bug).**

### FR-1 change set (one CI-checked commit)
1. `append-decision.sh:93` → `echo "| $next_id | $DECISION | $CHOICE | $SCOPE | $WHEN | $RATIONALE | $REVISABLE |" >> "$DECISIONS_FILE"` (consumer-order; same vars, reordered).
2. `scripts/lifecycle/scaffold.sh:89` init header → `| # | Decision | Choice | Scope | When | Rationale | Revisable? |`.
3. `scope-filter.sh:351` comment → correct it to the awk reality (`$2=ID $3=Decision $4=Choice $5=Scope $6=When $7=Rationale`). The awk at `:353-354` is correct — **leave it.**
4. Parallel knowledge round-trip: confirm `append-knowledge.sh` (`## K###` shape) ↔ `filter_knowledge` (`scope-filter.sh:142`) agree. `filter_knowledge` already parses flat `## K###` — verify, don't rewrite unless it diverges.
5. **Out of scope (flag only, do not touch):** `scripts/migrate/transform/decisions.sh` uses a THIRD order (`ID|Scope|When|Decision|…`) — that's external-tool migration, not the M044 producer/consumer contract.

### FR-2 (`kf_filter_stream` passes flat `## K###`)
`scripts/lib/knowledge-filter.sh::kf_filter_stream` (def at line ~731) splits entries only on `---` frontmatter fences, so flat `## K###` knowledge (no frontmatter) is mishandled (B-5). Fix the entry-boundary detection (or the `decide()` default) to pass flat `## K###` entries. Read the whole function + its `decide()` helper before editing.

### AC-1 / SC-1 — the acceptance oracle (build this)
A **capture→rebuild→grep→byte-assert** round-trip on a **default-intensity (Quick)** fixture, byte-asserting the resolved row:
- **Dynamic lane:** on a fresh fixture, `append-decision.sh` a decision scoped `M044/P01` → run `rebuild-index.sh` (no-op for the append-register but proves it doesn't break) → `filter_decisions` for that scope → **byte-assert** the resolved row's `$5`/`$6` land on Scope/When (not Decision/Choice). Parallel for `append-knowledge.sh` ↔ `filter_knowledge`.
- **Static lane:** frozen byte-equality fixtures (do NOT force a frozen file to contain a runtime-appended row — keep the two lanes separate). Per memory `feedback_fixtures_byte_equality_default`: assert byte-equality, not substrings.
- SC-7: a flat `## K###` entry passes `kf_filter_stream` (no "(no qualifying knowledge entries)").

---

## 5. P03 — Resilient rebuild + scoped archive glob (FR-3/FR-4). Sibling of P02 (both depend only on P01).

Re-confirm anchors against live source first.
- **FR-3 (B-1):** `scripts/knowledge/rebuild-index.sh` runs under `set -euo pipefail` (`:11`); the description grep at **`:117`** is unguarded (sibling `fm_field()` at `:40` ends in `|| true`), so one heading-less entry aborts the whole rebuild. Make it **per-entry try/skip/warn**: guard `:117`, emit per-skip to stderr + a final `INDEXED: N / SKIPPED: M [ids/paths]` summary, exit non-zero only on catastrophic failure (missing `knowledge/`, DB write failure). Do a **bounded** audit of `rebuild-index.sh` + its directly-sourced libs for other silently-failing commands under `set -e`/pipefail — fix `:117` + any *reproduced* failure, else justify-and-track in an audit artifact under `.orchestrator/milestones/M044/gates/`.
- **FR-4 (B-4):** drop the bare `*/archive/*` false-match at `resolve-entries.sh:45` AND `rebuild-index.sh:74`. **PRESERVE the genuine `knowledge/archive/` cold-storage exclusion** the script intentionally declares at `rebuild-index.sh:6` (CON-4). Scope the glob to the orchestrator's own subtree (`.orchestrator/**/archive/` / `knowledge/archive/`), not absolute paths — so a project rooted under a dir literally named `archive` indexes correctly.
- After FR-3 lands, **run `bash scripts/knowledge/rebuild-index.sh`** to clear the repo's own stale index (it will then read `present` again).

## 6. P04 — Capture-by-default at Quick + Decisions digest (FR-6/FR-8 G-1). Depends on P01 + P02.

- **FR-8 (G-1):** `scripts/knowledge/intensity-knowledge.sh:92` — Quick runs only `write-summary.sh`; it never captures decisions. Make **explicit** decisions always run `append-decision.sh` even at Quick (P0 slice only — the auto-graduate-at-phase-close half is P1/M040, NOT now).
- **FR-6 (G-2):** `build-context.sh` omits the Decisions section under the Quick profile (the `if [ "$PROFILE" != "quick" ]` guard around the `## Decisions` block). Add a **bounded, budget-bounded** Decisions digest at Quick. **Ship FR-6 + FR-8 in the SAME change set** so a Quick project never carries an empty-forever Decisions slot.
- SC-8/SC-9: a Quick fixture decision lands in `DECISIONS.md`, is resolved by `filter_decisions`, and appears in the next inject's Decisions digest.

---

## 7. How to work each phase (the orchestrator workflow + the proven P01 pattern)

1. **Plan:** `Skill orchestrator-plan-phase` (or author directly) → `.orchestrator/milestones/M044/phases/P##/P##-PLAN.md` + `tasks/T##-<slug>-PLAN.md`. Honor Plan-Time Discipline (path-collision `ls -la` each `create` path; verifier-availability; truth `Check:` = single-script-file shape only). Verify state derives to `executing` after.
2. **Build each task**, then **co-author its verifier(s)** under `tools/verify/m044-p##-t##-<name>.sh` (milestone-prefixed — NEVER phase-only, it clobbers prior aggregators).
3. **The verifier pattern that worked in P01** (reuse it): **lib-level fixture tests** (build an ephemeral `mktemp -d` corpus, source the lib, assert function behavior deterministically) **+ integration-wiring grep** (assert build-context.sh / the consumer calls the new function) **+ a live assertion** (run the real command, assert the state-robust invariant). This sidesteps the fact that `build-context.sh` hardcodes `PROJECT_ROOT` from its own location (line 48, no override) so you can't point it at a fixture root — but `check-*` scripts that take `--root` CAN be fixture-tested (source framework libs from the script's own tree, resolve data from `--root`; see `check-knowledge-activation.sh` for the LIB_ROOT-vs-PROJECT_ROOT split).
4. **Verifiers emit `PASS:`/`FAIL:`, exit 0/1.** Add a phase-suite aggregator `tools/verify/m044-p##-phase-suite.sh` (copy P01's) → `BATTERY: pass=N fail=0`.
5. **Close the phase:** write `P##-SUMMARY.md`, flip the roadmap checkbox, confirm `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M044/phases/P##` passes all truths/artifacts/key-links.
6. **Commit per task** as `exec(M044/P##/T##): …` (and `plan(M044/P##): …` for the plan). Re-assert branch first.

### Constraints to honor every phase
- CON-2 budget (read-into-payload only; capture-write free), CON-3 determinism (`LC_ALL=C`, no wall-clock in bodies), CON-4 preserve `knowledge/archive/`, CON-5 one doctor surface, CON-6 oracle asserts observed awk indices. Surgical edits (Principle XV) — don't refactor unrelated code.

---

## 8. Milestone close (after P04)

- Run `bash scripts/diagnostics/validate-milestone.sh M044` (expect all PASS) + the acceptance battery against SC-1…SC-12.
- Write `.orchestrator/milestones/M044/M044-SUMMARY.md` + drop the `M044-VALIDATED` marker, mirroring closed milestones (see e.g. M037/M041 summaries for shape).
- `Skill orchestrator-consolidate` for knowledge consolidation at the milestone boundary.
- Leave PR #11 for the operator to smoke-test + merge alongside the M034 PR #12.

## 9. State pointers
- Milestone dir: `.orchestrator/milestones/M044/` (EVALUATION, CONTEXT, ROADMAP, PLAN-TIME-RESOLUTIONS, phases/P01/ complete).
- Memory: `project_m044_knowledge_activation_inflight` (live status), `feedback_shared_tree_branch_collision`, `feedback_fixtures_byte_equality_default`, `project_knowledge_activation_reliability`.
- Active phase: `bash scripts/state/read-roadmap.sh .orchestrator/milestones/M044/M044-ROADMAP.md active-phase` → **P02**.
