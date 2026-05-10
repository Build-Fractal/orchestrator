---
schema_version: "1.0"
task: "T05"
phase: "P03"
milestone: "M014"
name: "Phase close — config + references + lint + zero-prompts + phase suite + Recent Changes (FR-17, SC-9, SC-11, CON-3, CON-6)"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01–T04 have shipped: every per-truth verifier under `scripts/verify/m014-p03-*.sh` is green individually.
- `scripts/util/dual-write-runtime-md.sh` (M014/P01/T03) is shipped — used for the Recent Changes dual-write at phase close.
- `tests/fixtures/m021-prompt-corpus.txt` exists ([M021](../../../../milestones/M021/index.md) zero-prompt baseline) — consumed by the zero-prompts verifier.
- `scripts/verify/anti-pattern-lint.sh` exists — consumed by the bash32+lint omnibus.

## Description

T05 closes the phase by adding the config keys, references documentation, omnibus lint+zero-prompts gates, the phase suite orchestrator, and the Recent Changes dual-write. Six discrete deliverables:

1. `.orchestrator/config.yml` gains a `comments:` section with `auto_apply_threshold:` (per-class scalars), `reply_on_apply:` (boolean default false), and `fetch_schedule:` (default `manual` per OQ #C-2). Additive — existing config bytes are preserved outside the new section.

2. `references/spec-management.md` gains a `## Comment Classification & Workflow Routing` section documenting the FR-9 regex/heuristic v1 shape, per-class confidence-score derivation, auto-apply thresholds + how to tune them, the spec-amendment human-gate invariant (CON-5/SC-5), and the D023 retune-trigger contract. Existing P04-completed sections (pressure-test, decomposition, dual-write marker convention, FR-19 dry-run manifest shape) are byte-preserved.

3. `scripts/verify/m014-p03-config-keys.sh` — assert the comments: section exists in config.yml with the three required sub-keys.

4. `scripts/verify/m014-p03-references-section.sh` — assert references/spec-management.md gains the new section AND the existing pressure-test / decomposition / dual-write / FR-19 sections are byte-preserved (shasum of the lines outside the new section is unchanged from pre-T05 state — captured via a snapshot file).

5. `scripts/verify/m014-p03-bash32-and-lint.sh` (omnibus) — runs `scripts/verify/anti-pattern-lint.sh` against every script T01–T04 introduced under `scripts/comments/` + `scripts/verify/m014-p03-*.sh`, and runs a Bash 3.2 pattern scan (no `declare -A`, no `mapfile`, no `${var,,}`, no process substitution, no `&>`).

6. `scripts/verify/m014-p03-zero-prompts.sh` — asserts the M021 prompt-corpus regex finds zero approval-prompt-shaped strings on the primary `comments.sh classify --yes` path. Self-exempts diagnostic strings the verifier itself emits.

7. `scripts/verify/m014-p03-phase-suite.sh` — orchestrator that runs every M014/P03 verifier in declared order, captures pass/fail per gate, emits `SUMMARY: m014-p03-phase-suite.sh pass=N fail=0` and exits 0 only if every gate is green.

8. CLAUDE.md + AGENTS.md `>>> orchestrator:recent-changes >>>` regions get a fresh M014/P03 entry written via `scripts/util/dual-write-runtime-md.sh`. Existing entries are preserved (append, not overwrite).

## Steps

1. **Capture a pre-edit snapshot of `references/spec-management.md`** for the byte-preservation gate:

   ```bash
   shasum -a 256 references/spec-management.md > /tmp/m014-p03-spec-mgmt-pre.shasum
   ```

   (The verifier in step 4 below uses a more robust approach — extracting lines outside the new section via `awk` and shasum-ing those — rather than relying on this temp file. The temp file is for operator inspection during T05 dispatch.)

2. **Edit `.orchestrator/config.yml`** to add the `comments:` section. Append after existing sections:

   ```yaml
   comments:
     # FR-17 (M014/P03): per-class auto-apply confidence thresholds.
     # Pinned conservatively; D023 retune trigger documented in
     # specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md.
     auto_apply_threshold:
       uat-bug: 0.8
       decision-append: 0.8
       spec-amendment: 1.0  # CON-5/SC-5 — never auto-applies regardless.
       ambiguous: 1.0       # always routes through conversus.
     reply_on_apply: false  # OQ #C-8 v1 conservative pin.
     fetch_schedule: manual # OQ #C-2 v1 conservative pin (alternatives: post-verify, cron).
   ```

3. **Append the new section to `references/spec-management.md`**:

   ```markdown
   ## Comment Classification & Workflow Routing

   *Added by M014/P03 (2026-04-24). See [`.orchestrator/DECISIONS.md`](../../../../decisions.md) D023 for
   the regex/heuristic v1 baseline pin and retune trigger.*

   ### Pipeline (orchestrator:comments classify)

   1. `scripts/comments/fetch.sh` enumerates unactioned Giscus + GitHub Issue/PR
      comments, caches each to `.orchestrator/comments/inbox/<comment-id>.json`,
      skips entries already in `.orchestrator/comments/actioned.jsonl`.
   2. `scripts/comments/classify.sh <inbox-file>` emits per-comment verdict
      `class=<class> confidence=<score> reason=<rule-id>` for one of four FR-9
      classes: `uat-bug`, `decision-append`, `spec-amendment`, `ambiguous`.
   3. `scripts/comments/comments.sh` master pipeline routes per class:
      - `uat-bug` ≥ threshold → M013/FR-10 UAT ingestion path (auto-apply).
      - `decision-append` ≥ threshold → templated block appended to `DECISIONS.md`.
      - `spec-amendment` (any confidence) → review-queue (NEVER auto-applies).
      - `ambiguous` → `scripts/dispatch/adapters/tool/conversus.sh gate
        classify-comment` (--strict); on PASS-with-reclassification, route to
        new class; on BLOCK / low-confidence / adapter unavailable, route to
        human triage bucket.

   ### Regex/heuristic v1 ruleset (D023)

   See `scripts/comments/classify.sh` rules R1-R10 inline. Confidence values
   are coarse (0.7–0.95 in 0.05–0.10 steps) pinned on intuition + four-class
   precedent, NOT on measured precision/recall. Retune trigger documented below.

   ### Auto-apply thresholds

   `.orchestrator/config.yml` `comments.auto_apply_threshold:` — per-class:

   | Class | Default | Behavior at/above threshold |
   |---|---|---|
   | `uat-bug` | 0.8 | Route through M013/FR-10 UAT ingestion. |
   | `decision-append` | 0.8 | Append templated block to `DECISIONS.md`. |
   | `spec-amendment` | 1.0 | NEVER auto-applies (CON-5/SC-5 invariant). |
   | `ambiguous` | 1.0 | Always conversus-triage. |

   Operators tune by editing `.orchestrator/config.yml`. SC-4 measures precision
   on dogfood data; SC-5 forbids auto-apply regardless of `spec-amendment` threshold.

   ### Spec-amendment human-gate (CON-5/SC-5/Constitution III + XIV)

   The `apply <queue-id>` subcommand is the SINGLE path for spec mutation from
   comments. No script under `scripts/comments/` auto-applies a spec-amendment
   regardless of confidence score. `scripts/verify/m014-p03-spec-amendment-human-gate.sh`
   asserts this invariant mechanically.

   ### D023 retune trigger

   The regex/heuristic v1 baseline is provisional. Open a follow-up D-row to
   re-pin FR-9 shape when EITHER condition holds:

   1. `actioned.jsonl` shows ≥30 fetched comments across the four classes.
   2. Classifier confidence calibration on observed comments diverges from
      regex/heuristic predictions in ≥20% of samples (sample = comment whose
      conversus-triage verdict OR human-triage outcome disagrees with the
      regex/heuristic verdict).

   Either trigger justifies escalating to one of the alternative shapes from
   spec OQ #C-1 (embedding-distance, LLM-call-per-comment, two-pass hybrid).

   ### FR-19 dry-run manifest shape

   `comments classify --dry-run` emits JSONL action records to stdout:

   ```
   {"command":"comments classify","action_type":"<action>","target_path":"<path>","source_ref":"<url>","description":"<text>"}
   ```

   `action_type` values: `cache-comment`, `classify-comment`, `auto-apply-uat-bug`,
   `auto-apply-decision-append`, `queue-spec-amendment`, `route-ambiguous-to-conversus`,
   `apply-amendment`, `reject-queue-item`.
   ```

4. **Create the four verifiers** at `scripts/verify/m014-p03-config-keys.sh`,
   `scripts/verify/m014-p03-references-section.sh`,
   `scripts/verify/m014-p03-bash32-and-lint.sh`,
   `scripts/verify/m014-p03-zero-prompts.sh`:

   - **config-keys**: greps `.orchestrator/config.yml` for the three required
     sub-keys (`auto_apply_threshold`, `reply_on_apply`, `fetch_schedule`)
     under a `comments:` parent.

   - **references-section**: asserts `## Comment Classification & Workflow Routing`
     heading exists, asserts the existing P04-completed section headings are
     still present (`## Pressure-test`, `## Decomposition`, `## Dual-write
     marker convention`, `## FR-19 dry-run manifest shape` — exact headings
     are byte-checked to whatever P04 left). Asserts the FR-9 v1 ruleset name
     and the D023 retune trigger language are present.

   - **bash32-and-lint omnibus**: iterates every `scripts/comments/*.sh` and
     every `scripts/verify/m014-p03-*.sh` (excluding self), runs
     `bash scripts/verify/anti-pattern-lint.sh "$f"` against each, scans for
     Bash 4+ patterns. Self-exempts the diagnostic-string-bearing verifier
     itself (M014/P01 + M014/P02 + M026/P03 precedent).

   - **zero-prompts**: invokes `bash scripts/comments/comments.sh classify --yes`
     under hermetic scratch with `GH_API_STUB` set to a minimal fixture; greps
     stdout+stderr against `tests/fixtures/m021-prompt-corpus.txt` patterns;
     expects zero matches. Self-exempts diagnostic strings the verifier itself
     emits (e.g., the literal regex pattern lines).

5. **Create `scripts/verify/m014-p03-phase-suite.sh`** (~80 lines) that orchestrates every M014/P03 verifier in this order:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m014-p03-phase-suite.sh
   # M014/P03 phase suite — runs every per-truth verifier and emits a single PASS/FAIL line.
   set -u

   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

   GATES=(
     "m014-p03-fetch.sh"
     "m014-p03-classify.sh"
     "m014-p03-commands-md.sh"
     "m014-p03-apply.sh"
     "m014-p03-reject-triage.sh"
     "m014-p03-spec-amendment-human-gate.sh"
     "m014-p03-pipeline.sh"
     "m014-p03-auto-apply.sh"
     "m014-p03-observability.sh"
     "m014-p03-config-keys.sh"
     "m014-p03-references-section.sh"
     "m014-p03-dogfood-capture.sh"
     "m014-p03-bash32-and-lint.sh"
     "m014-p03-zero-prompts.sh"
   )

   pass=0; fail=0
   for g in "${GATES[@]}"; do
     gpath="${REPO_ROOT}/scripts/verify/${g}"
     if [ ! -x "$gpath" ] && [ ! -f "$gpath" ]; then
       printf 'FAIL: gate missing %s\n' "$g"
       fail=$((fail+1))
       continue
     fi
     if bash "$gpath" >/dev/null 2>&1; then
       pass=$((pass+1))
       printf 'PASS: %s\n' "$g"
     else
       fail=$((fail+1))
       printf 'FAIL: %s\n' "$g"
     fi
   done

   echo "----"
   echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   echo "PASS: $(basename "$0")"
   exit 0
   ```

6. **Create the dogfood-capture verifier** `scripts/verify/m014-p03-dogfood-capture.sh` (~30 lines) — referenced by the phase suite, asserts the file from T02 exists with required sections (Status, Snapshot, Per-class counts, FR-9 shape pinned, Retune trigger, Cross-references) and cites D023.

7. **Run the phase suite** to confirm everything is green:

   ```bash
   bash scripts/verify/m014-p03-phase-suite.sh
   ```

   Expected:
   ```
   PASS: m014-p03-fetch.sh
   PASS: m014-p03-classify.sh
   PASS: m014-p03-commands-md.sh
   ...
   PASS: m014-p03-zero-prompts.sh
   ----
   SUMMARY: m014-p03-phase-suite.sh pass=14 fail=0
   PASS: m014-p03-phase-suite.sh
   ```

8. **Append a Recent Changes entry to CLAUDE.md + AGENTS.md** via the dual-write helper:

   ```bash
   _content="$(mktemp)"
   echo "- M014/P03: comment→workflow classifier (regex/heuristic v1 per D023) + spec-amendment human-gated apply path; consumes [M012](../../../../milestones/M012/index.md) wiki + [M013](../../../../milestones/M013/index.md) GitHub comment surfaces; conversus-triage on ambiguous; FR-19 dry-run + FR-16 observability; phase suite 14 gates green." > "$_content"
   bash scripts/util/dual-write-runtime-md.sh --marker recent-changes --content "$_content" --append-entry
   rm -f "$_content"
   ```

   Verify both files have the new entry:

   ```bash
   grep -q "M014/P03:" CLAUDE.md && grep -q "M014/P03:" AGENTS.md
   ```

## Must-Haves

Addresses phase must-haves:
- "Truth: config.yml comments: section additive"
- "Truth: references/spec-management.md gains classifier section, P04 sections byte-preserved"
- "Truth: bash32+lint omnibus green"
- "Truth: zero-prompts under --yes"
- "Truth: dogfood-data file exists + cites D023"
- "Truth: phase suite emits SUMMARY: pass=N fail=0"
- "Truth: CLAUDE.md + AGENTS.md RC dual-write"

## Verification

```
bash scripts/verify/m014-p03-config-keys.sh
bash scripts/verify/m014-p03-references-section.sh
bash scripts/verify/m014-p03-bash32-and-lint.sh
bash scripts/verify/m014-p03-zero-prompts.sh
bash scripts/verify/m014-p03-dogfood-capture.sh
bash scripts/verify/m014-p03-phase-suite.sh
```

The phase suite gates the others — exit 0 from `m014-p03-phase-suite.sh` is the
load-bearing assertion. Independent runs of the others are diagnostic.

## Inputs

### From Previous Tasks

- All T01–T04 verifiers — phase-suite invokes them.
- `scripts/comments/comments.sh` (T04) — invoked under `--yes` by the zero-prompts gate.
- `specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md` (T02) — checked by the dogfood-capture verifier.

### From Disk (Pre-existing)

- `scripts/util/dual-write-runtime-md.sh` (M014/P01) — RC append.
- `scripts/verify/anti-pattern-lint.sh` — invoked by the bash32+lint omnibus.
- `tests/fixtures/m021-prompt-corpus.txt` — consumed by the zero-prompts gate.
- `references/spec-management.md` (P01 partial + P04 complete) — appended to.
- `.orchestrator/config.yml` (P01 specify: section + P04 thresholds) — appended to.

## Constraints

- **CON-3 / SC-7**: zero-prompts gate is the mechanical SC-7 assertion.
- **CON-6 / SC-9**: bash32+lint omnibus is the mechanical SC-9 assertion.
- **SC-11**: references/spec-management.md gains the comment-classification section. SC-11 was already PASS as of P04; T05 extends without violating P04's section preservation.
- **AD-19**: every Check is `bash scripts/verify/m014-p03-<name>.sh`.
- **CON-8 idempotency**: re-running T05 against an already-edited config / references is idempotent — verifiers detect already-present state and pass; `dual-write-runtime-md.sh --append-entry` is reverse-chronological prepend (does not duplicate the same line).
- **D007 reuse**: T05 does not modify `scripts/dispatch/adapters/tool/conversus.sh`.

## Expected Output

- `.orchestrator/config.yml` modified — `comments:` section added.
- `references/spec-management.md` modified — `## Comment Classification & Workflow Routing` section appended.
- Six verifiers under `scripts/verify/m014-p03-{config-keys,references-section,bash32-and-lint,zero-prompts,dogfood-capture,phase-suite}.sh` (~30-100 lines each).
- CLAUDE.md + AGENTS.md `>>> orchestrator:recent-changes >>>` regions both gain a fresh M014/P03 entry.
- `bash scripts/verify/m014-p03-phase-suite.sh` exits 0 with `SUMMARY: m014-p03-phase-suite.sh pass=14 fail=0` and `PASS: m014-p03-phase-suite.sh`.
