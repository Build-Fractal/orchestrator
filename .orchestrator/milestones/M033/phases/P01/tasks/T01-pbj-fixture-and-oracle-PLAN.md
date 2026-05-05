---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M033"
name: "PBJ acceptance fixture + ground-truth README oracle"
depends_on: []
---

## Prerequisites

- The `tests/fixtures/` directory exists (verified: many existing fixture dirs siblings under it).
- The `tools/verify/` directory exists (verified: M030/M031/M032 verifiers under it).
- No file currently lives at `tests/fixtures/m033-pbj-materials-fixture/` (verified: `ls tests/fixtures/ | grep m033` returns empty). T01 creates this directory.
- The CON-4 / FR-23 spec requirements (exactly 5 inconsistencies, ≥1 per detection category) are documented in the M033 spec body under FR-23 and CON-4 — this task plan re-states the requirement inline so executors do not need to re-read the spec.
- The named PBJ-shape document set is `PRODUCT-BRIEF.md`, `MVP-PLAN.md`, `DECISIONS.md`, `MILESTONE-AUDIT.md` — anchored in the spec's User Story 4 problem statement. The fixture names these four files exactly so the FR-2 rule-2 detection (≥3 PBJ-shape `.md` files) fires cleanly when `start.sh` probes against this fixture (after copying it into a probe target with `src/` absent).

## Description

T01 ships the synthetic-PBJ-shape fixture that powers SC-4 (P04 materials-intake test) AND that exercises FR-2's rule-2 (`greenfield-with-materials`) branch detection in P01's SC-1. The fixture is curatorial work — its value is in the *exact* 5 inconsistencies documented in the README oracle, which P04's deterministic drift detector compares its output against. Frontloading this in P01 (rather than P04) is mandated by FR-23: the fixture must exist before P04's `p04-materials-intake.sh` can run, and authoring the inconsistencies in P01 means P02–P04 implementations have a stable target to develop against.

**Deterministic-output guarantee (FR-23):** the fixture content is text-only, with no timestamps, no machine-name embeddings, no platform-specific paths. Same fixture + same operator answers produces same detector output across any platform and operator identity.

**Inconsistency design.** The 5 inconsistencies cover the three CON-4 detection categories with ≥1 instance each, plus 2 additional instances chosen to stress the deterministic detector:

1. **id-misalignment** (PRODUCT-BRIEF.md ↔ MVP-PLAN.md): `PRODUCT-BRIEF.md` references `US-3` in its scope statement, but `MVP-PLAN.md` defines only `US-1` and `US-2` in its User Stories section. The detector should surface the orphan `US-3` reference.
2. **scheme-contradiction** (DECISIONS.md ↔ MVP-PLAN.md): `DECISIONS.md` records `DR-002: Deploy via Vercel` while `MVP-PLAN.md` lists "Cloudflare Workers" as the deployment target. Conflicting authoritative scheme.
3. **orphan-reference** (MILESTONE-AUDIT.md): `MILESTONE-AUDIT.md` mentions a milestone `M-3 (Authentication)` that no other document defines or scopes. Forward reference to a non-existent target.
4. **id-misalignment, second instance** (PRODUCT-BRIEF.md ↔ DECISIONS.md): `PRODUCT-BRIEF.md` says decisions `DR-001` and `DR-002` cover the architecture; `DECISIONS.md` defines `DR-001`, `DR-002`, AND `DR-003` — but `DR-003` is referenced nowhere upstream (orphan-on-the-other-side variant — defined but never cited).
5. **scheme-contradiction, second instance** (PRODUCT-BRIEF.md ↔ MVP-PLAN.md): `PRODUCT-BRIEF.md` says "MVP timeline: 4 weeks"; `MVP-PLAN.md` says "MVP timeline: 6 weeks". Numeric scheme mismatch.

The README oracle enumerates these 5 by name, category, and document pair so P04's verifier can compare detector output against the oracle line-by-line.

## Steps

1. **Create the fixture directory:** `mkdir -p tests/fixtures/m033-pbj-materials-fixture`.

2. **Author `tests/fixtures/m033-pbj-materials-fixture/PRODUCT-BRIEF.md`** (≥25 lines). Required content tokens (verifier asserts presence): `## Problem`, `## Target User`, `US-` (the literal token, used by US-1 and US-3 references), the literal phrase `MVP timeline: 4 weeks` (inconsistency #5 left side), references to `DR-001` and `DR-002` (inconsistency #4 left side), and a scope statement that names `US-3` explicitly (inconsistency #1 left side). Body sections: Problem (3–4 lines), Target User (2–3 lines), Scope (4–5 lines including the `US-1 / US-2 / US-3` enumeration), Architecture Decisions (3 lines naming `DR-001` and `DR-002`), Timeline (1 line: `MVP timeline: 4 weeks`).

3. **Author `tests/fixtures/m033-pbj-materials-fixture/MVP-PLAN.md`** (≥25 lines). Required tokens: `## User Stories`, `US-` (used for US-1 and US-2 — note the deliberate absence of US-3), the literal phrase `MVP timeline: 6 weeks` (inconsistency #5 right side), the literal phrase `Cloudflare Workers` (inconsistency #2 right side). Body sections: Goals (3–4 lines), User Stories (5–6 lines defining `US-1` and `US-2` only — `US-3` deliberately absent), Deployment Target (1–2 lines naming Cloudflare Workers), Timeline (1 line: `MVP timeline: 6 weeks`), Risks (3 lines).

4. **Author `tests/fixtures/m033-pbj-materials-fixture/DECISIONS.md`** (≥20 lines). Required tokens: `DR-` (the literal token; used for DR-001, DR-002, DR-003), the literal phrase `Deploy via Vercel` (inconsistency #2 left side). Body: a lightweight decision register with three entries (`DR-001 Pick framework`, `DR-002 Deploy via Vercel`, `DR-003 Database choice` — note `DR-003` is defined but never cited by upstream docs, this is inconsistency #4's right side). Each DR is 4–5 lines: title + rationale + status.

5. **Author `tests/fixtures/m033-pbj-materials-fixture/MILESTONE-AUDIT.md`** (≥20 lines). Required tokens: `M-` (the literal token; used by `M-1`, `M-2`, `M-3`). Body: an audit table of three milestones — `M-1 Discovery`, `M-2 Foundation`, `M-3 Authentication` — where `M-3` is the orphan reference (inconsistency #3): no scope appears in any other document. Each milestone entry is 4–5 lines.

6. **Author `tests/fixtures/m033-pbj-materials-fixture/README.md`** (≥60 lines). This is the SC-4 ground-truth oracle. The file MUST contain a numbered list of exactly 5 entries (markdown numbered list, lines starting `1.`, `2.`, `3.`, `4.`, `5.`). Each entry names: (a) the CON-4 category from the closed enum `id-misalignment | scheme-contradiction | orphan-reference`, (b) the affected document pair (e.g., `PRODUCT-BRIEF.md ↔ MVP-PLAN.md`), (c) one to two sentences describing the inconsistency.

   Required README sections (the verifier asserts each):
   - `# m033 PBJ Materials Fixture` (H1 title)
   - `## Purpose` — names FR-23 / SC-4 / P04 as consumers; explains the fixture is the deterministic input for P04's drift detector
   - `## Inconsistencies (Ground-Truth Oracle)` — the numbered 5-item list (the load-bearing section)
   - `## Determinism Guarantee` — names FR-23's "same fixture + same operator answers → same detection output across platforms and operator identities" clause
   - `## Consumers` — lists the consuming phases (`P01 SC-1` for branch-detection rule-2, `P04 SC-4` for materials-intake)

   Sample numbered-list shape (executor MUST author all 5 entries in this exact form for the oracle parser):

   ```markdown
   1. **id-misalignment** — `PRODUCT-BRIEF.md ↔ MVP-PLAN.md`. PRODUCT-BRIEF references `US-3` in its scope statement, but MVP-PLAN defines only `US-1` and `US-2`.
   2. **scheme-contradiction** — `DECISIONS.md ↔ MVP-PLAN.md`. DECISIONS records `DR-002: Deploy via Vercel`; MVP-PLAN names `Cloudflare Workers` as deployment target.
   3. **orphan-reference** — `MILESTONE-AUDIT.md`. Mentions milestone `M-3 (Authentication)` which no other document defines or scopes.
   4. **id-misalignment** — `PRODUCT-BRIEF.md ↔ DECISIONS.md`. DECISIONS defines `DR-003` but no upstream document cites it.
   5. **scheme-contradiction** — `PRODUCT-BRIEF.md ↔ MVP-PLAN.md`. PRODUCT-BRIEF says `MVP timeline: 4 weeks`; MVP-PLAN says `MVP timeline: 6 weeks`.
   ```

7. **Author `tools/verify/m033-p01-pbj-fixture-shape.sh`** (≥25 lines, executable, `chmod +x`). The verifier asserts:
   - The four required documents (`PRODUCT-BRIEF.md`, `MVP-PLAN.md`, `DECISIONS.md`, `MILESTONE-AUDIT.md`) exist under `tests/fixtures/m033-pbj-materials-fixture/`.
   - No `src/` directory and no `.git/` directory under the fixture (the fixture is materials-only — required for FR-2 rule-2 to fire cleanly when copied into a probe target).
   - Each document meets its minimum line count from the artifacts list.
   - Required content tokens are present in each document via `grep -q`.
   - Emits `PASS:` lines for each assertion and a final `SUMMARY: m033-p01-pbj-fixture-shape.sh pass=N fail=M` line. Exit 0 iff all PASS.

8. **Author `tools/verify/m033-p01-pbj-fixture-readme-oracle.sh`** (≥25 lines, executable). The verifier asserts:
   - The README exists.
   - The five numbered list entries (lines matching `^[1-5]\. ` at the start) are present.
   - Each numbered entry contains exactly one of the three CON-4 category tokens (`id-misalignment`, `scheme-contradiction`, `orphan-reference`).
   - Across the 5 entries, each of the three categories appears at least once (≥1 per category per FR-23).
   - The required README section headers (`## Purpose`, `## Inconsistencies (Ground-Truth Oracle)`, `## Determinism Guarantee`, `## Consumers`) are present.
   - Emits PASS lines and a SUMMARY line. Exit 0 iff all PASS.

## Must-Haves

This task addresses these P01 phase truths:
- `tests/fixtures/m033-pbj-materials-fixture/` exists with the four PBJ-shape documents and the 5 inconsistencies.
- `tests/fixtures/m033-pbj-materials-fixture/README.md` is the SC-4 ground-truth oracle.

This task creates these P01 phase artifacts:
- Fixture documents: `tests/fixtures/m033-pbj-materials-fixture/PRODUCT-BRIEF.md`, `tests/fixtures/m033-pbj-materials-fixture/MVP-PLAN.md`, `tests/fixtures/m033-pbj-materials-fixture/DECISIONS.md`, `tests/fixtures/m033-pbj-materials-fixture/MILESTONE-AUDIT.md`, `tests/fixtures/m033-pbj-materials-fixture/README.md` (SC-4 ground-truth oracle).
- Shape verifier: `tools/verify/m033-p01-pbj-fixture-shape.sh` (asserts 4 PBJ docs + minimum line counts + required content tokens).
- Oracle verifier: `tools/verify/m033-p01-pbj-fixture-readme-oracle.sh` (asserts 5 numbered entries + ≥1 per CON-4 category).

## Verification

```bash
bash tools/verify/m033-p01-pbj-fixture-shape.sh
```

```bash
bash tools/verify/m033-p01-pbj-fixture-readme-oracle.sh
```

## Inputs

### From Previous Tasks

None — T01 has no upstream task dependencies.

### From Disk (Pre-existing)

- `tests/fixtures/` — directory must exist; T01 creates `m033-pbj-materials-fixture/` under it.
- `tools/verify/` — directory must exist; T01 creates two new verifier scripts under it.
- The M033 spec body under FR-23 and CON-4 (already on disk at the planning payload location) — re-read only if the inline restatement in this task plan's Description is insufficient.

## Constraints

- The fixture MUST contain exactly 5 inconsistencies — not 4, not 6. SC-4's mechanical assertion is "exactly 5 conflicts surfaced", and the README oracle is the ground truth. Adding a 6th inconsistency silently breaks SC-4.
- The fixture MUST contain NO `src/` directory and NO `.git/` directory. Adding either changes FR-2's branch-detection result for the fixture (rule-3 would fire instead of rule-2).
- The fixture MUST be deterministic — no timestamps, no machine-name embeddings, no `$(date)`, no random tokens. Re-creating the fixture from scratch on a different machine MUST produce byte-identical content.
- The README's numbered-list shape (lines starting `1.`, `2.`, `3.`, `4.`, `5.`) is the parser-load-bearing format. P04's verifier reads this list with a line-prefix regex; deviating from the markdown numbered-list shape silently breaks downstream verification.
- This task creates no `scripts/lifecycle/` files, no `commands/` files, and no `references/` files — the scope is fixture-only. Anything else is out of scope per scope-guard.

## Expected Output

After T01 completes:
- `tests/fixtures/m033-pbj-materials-fixture/` contains 5 files (4 PBJ-shape docs + README).
- `tools/verify/m033-p01-pbj-fixture-shape.sh` and `tools/verify/m033-p01-pbj-fixture-readme-oracle.sh` exist and are executable.
- Both verifiers exit 0 against the authored fixture.
- A summary file at `.orchestrator/milestones/M033/phases/P01/tasks/T01-pbj-fixture-and-oracle-SUMMARY.md` documents the deliverables and the 5-inconsistency enumeration (mirrored from the README oracle for cross-reference auditability).

## Notes

Expected verifier output for `m033-p01-pbj-fixture-shape.sh`: a sequence of `PASS:` lines (one per asserted file/token) followed by `SUMMARY: m033-p01-pbj-fixture-shape.sh pass=N fail=0` where N is the assertion count. Same shape for `m033-p01-pbj-fixture-readme-oracle.sh`.
