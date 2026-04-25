---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P03"
milestone: "M014"
provides:
  - "commands/comments.md (six-subcommand surface: classify/status/apply/reject/triage/reclassify)"
  - "scripts/comments/apply.sh (FR-1+US-5 human-gated spec-amendment apply, stale-diff + in-flight conversus refusal, rebuild-index hook, actioned.jsonl row, comment_actioned event)"
  - "scripts/comments/reject.sh (FR-1 queue rejection with --reason; appends applied:false row)"
  - "scripts/comments/triage.sh (FR-1 human-triage bucket lister; tab-separated rows + SUMMARY count)"
  - "tests/fixtures/m014-p03/queued-amendment.md (Q001 hermetic fixture for apply.sh end-to-end)"
  - "scripts/verify/m014-p03-commands-md.sh (6 cases — surface shape + D023 + FR-19 + human-gate + dogfood SSOT)"
  - "scripts/verify/m014-p03-apply.sh (5 cases — happy path + stale-diff + in-flight conversus + wrong-class + missing queue-id)"
  - "scripts/verify/m014-p03-reject-triage.sh (5 cases — reject record + arg-required + missing-queue + empty-triage + listing-with-verdict)"
  - "scripts/verify/m014-p03-spec-amendment-human-gate.sh (4 assertions — apply-gate + no-auto-apply scan + doc invariant + classify-docstring)"
requires:
  - "from:T01 what:scripts/comments/fetch.sh actioned.jsonl shape {comment_url, actioned_at, class, applied, queue_id?, reason?, action_taken?}"
  - "from:T02 what:scripts/comments/classify.sh class verdicts {uat-bug, decision-append, spec-amendment, ambiguous} + classify-comment.yml preset + planning-inputs/inbox-dogfood.md SSOT"
  - "from:M011 what:scripts/knowledge/rebuild-index.sh (post-amendment chunk re-versioning)"
  - "from:disk what:scripts/dispatch/adapters/tool/conversus.sh (D007 — referenced from doc, NOT modified)"
  - "from:disk what:patch (POSIX util) — stale-diff probe via patch -N --dry-run"
affects:
  - "T04 pipeline (consumes apply.sh/reject.sh/triage.sh as sub-action invocations)"
  - "T05 phase close (phase-suite verifier orchestrates the four T03 verifiers)"
  - "M014 invariant SC-5/CON-5 (mechanically asserted by m014-p03-spec-amendment-human-gate.sh)"
key_files:
  - "commands/comments.md"
  - "scripts/comments/apply.sh"
  - "scripts/comments/reject.sh"
  - "scripts/comments/triage.sh"
  - "tests/fixtures/m014-p03/queued-amendment.md"
  - "scripts/verify/m014-p03-commands-md.sh"
  - "scripts/verify/m014-p03-apply.sh"
  - "scripts/verify/m014-p03-reject-triage.sh"
  - "scripts/verify/m014-p03-spec-amendment-human-gate.sh"
key_decisions:
  - "patch -N (forward-only) is the stale-diff probe, not vanilla --dry-run; vanilla --dry-run silently auto-reverses on a previously-applied diff (rc=0) and would mask staleness"
  - "review-queue diff extraction targets the FIRST ```diff fenced block in the queue file body (deterministic against fixture shape)"
  - "in-flight conversus = conversus/ directory exists AND conversus/summary/final.md absent (US-5 AS-4)"
  - "triage.sh treats absent .orchestrator/comments/triage/ as entries=0 and exits 0 (no-op-on-empty pattern)"
  - "human-gate verifier scans scripts/comments/*.sh excluding apply.sh itself (apply.sh IS the manual gate, so its class=spec-amendment string is legitimate not a violation)"
patterns_established:
  - "patch -N forward-only stale-diff probe (replaces naive --dry-run that auto-reverses)"
  - "ORCHESTRATOR_PROJECT_ROOT hermetic test hook reused across apply/reject/triage (T01/T02 precedent extended to T03)"
  - "verifier self-exemption via path-scope (this verifier under scripts/verify/, scans scripts/comments/) — alternative to in-line literal-rewriting"
  - "queue-file frontmatter extraction via awk with gsub strip of surrounding double-quotes (matches T01/T02 awk patterns)"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P03/tasks/T03-action-surfaces-PAYLOAD.md"
  - "commands/comments.md"
  - "scripts/comments/apply.sh"
  - "scripts/verify/m014-p03-spec-amendment-human-gate.sh"
duration: "~45m"
verification_result: "pass"
completed_at: "2026-04-24T00:00:00Z"
---

# T03: Command surface + apply / reject / triage + human-gate invariant

## What Was Built

T03 ships the operator-facing surface for M014's comment workflow:

- **`commands/comments.md`** — user-facing command doc. Six subcommands documented (`classify`, `status`, `apply`, `reject`, `triage`, `reclassify`). Cites D023 retune-trigger pin with `specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md` as SSOT (per T02 handoff). Documents FR-19 dry-run JSONL manifest shape. Asserts the spec-amendment human-gate invariant prominently (CON-5 / SC-5 / "NEVER auto-applied").
- **`scripts/comments/apply.sh`** — the ONLY path for spec mutation from a comment-class verdict of `spec-amendment`. Reads `.orchestrator/comments/review-queue/<queue-id>.md`, extracts proposed diff from a ```diff fenced block, refuses on (a) wrong class, (b) in-flight conversus deliberation, (c) stale diff via `patch -N --dry-run`. On success applies via `patch -N -p1`, invokes `scripts/knowledge/rebuild-index.sh` best-effort, appends actioned.jsonl row `{applied:true, queue_id, action_taken:apply-amendment}`, emits `comment_actioned` event to execution-log.jsonl.
- **`scripts/comments/reject.sh`** — `<queue-id> --reason "<prose>"` records `applied:false` row in actioned.jsonl with reason. No spec mutation.
- **`scripts/comments/triage.sh`** — lists `.orchestrator/comments/triage/*.md` entries (id, comment_url, conversus_verdict) tab-separated; emits SUMMARY count line. No-op on absent triage dir (entries=0).
- **`tests/fixtures/m014-p03/queued-amendment.md`** — Q001 hermetic fixture: spec-amendment class, target `specs/m014-p03-test/spec.md`, ```diff body adding one line under `@@ -1,2 +1,3 @@`.
- **Four T03 verifiers** — see "Verification" below.

## Critical SC-5 Invariant — Mechanically Asserted

`m014-p03-spec-amendment-human-gate.sh` enforces SC-5 / CON-5 on every run via four assertions:

1. `apply.sh` carries the `class != "spec-amendment"` refusal guard.
2. No script under `scripts/comments/` (excluding `apply.sh` itself, which IS the legitimate manual gate) contains an auto-apply pattern keyed to spec-amendment.
3. `commands/comments.md` documents the human-gate invariant.
4. `classify.sh` docstring asserts spec-amendment always queues regardless of confidence.

If T04 ever wires an auto-apply branch for spec-amendment, this verifier breaks the build immediately.

## Key Decisions

- **`patch -N` forward-only is the stale-diff probe.** Vanilla `patch --dry-run` auto-reverses on a previously-applied diff and returns rc=0, which would silently mask staleness. `-N` makes patch refuse a reverse-apply and exit non-zero with `Ignoring previously applied (or reversed) patch.` — exactly the operative signal for US-5 AS-2. Caught at first verifier run (Case B initially failed with rc=0; root cause analysis surfaced the auto-reverse behavior).
- **In-flight conversus = directory exists AND `summary/final.md` absent.** Empty `conversus/` blocks apply; finalized deliberation (final.md present) does not. Aligns with US-5 AS-4 ("no interleaving authorship + amendment").
- **Triage no-op on empty.** `triage.sh` exits 0 with `SUMMARY: triage entries=0` when the directory is missing. Avoids spurious failures on fresh repos.
- **Human-gate verifier path-scope self-exemption.** Verifier lives under `scripts/verify/` and scans `scripts/comments/*.sh` only, so its diagnostic strings (which embed the literal patterns it scans for) don't trip its own scanner. Alternative pattern to M016/P03's literal-rewriting self-exemption.

## Deviations from Plan Body

1. **Stale-diff probe gained `-N` flag.** Plan body specified `patch --dry-run` (no `-N`). Initial verifier run exposed that vanilla `patch --dry-run` returns rc=0 on already-applied diffs (auto-reverse default). Switched to `patch -N --dry-run` and applied the same `-N` to the real-apply call for race safety. No caller-visible contract change — the diagnostic still says "stale-diff" and exit code is still 2.
2. **Fixture diff hunk header narrowed.** Plan body specified `@@ -1,3 +1,4 @@` with a blank trailing context line. Simplified to `@@ -1,2 +1,3 @@` (no trailing blank context) so the fixture target spec is a clean two-line file. No semantic change; same +1 net line addition.
3. **`actioned.jsonl` rows now carry `action_taken` field.** T01 contract listed it as optional (`action_taken?`). T03 populates it for every apply/reject row (`apply-amendment` / `reject-queue-item`) so `triage.sh` and downstream T04 can distinguish apply vs reject without re-parsing reason text. Backward compatible (additive field).

None of these deviations change cross-task contracts.

## Verification Results

All four T03 verifiers exit 0:

```
$ bash scripts/verify/m014-p03-commands-md.sh
PASS: Case A: commands/comments.md exists
PASS: Case B: all six subcommands documented
PASS: Case C: D023 retune-trigger pin referenced
PASS: Case D: FR-19 dry-run manifest shape documented
PASS: Case E: spec-amendment human-gate invariant documented
PASS: Case F: planning-inputs/inbox-dogfood.md cited as SSOT
SUMMARY: pass=6 fail=0 -> exit 0

$ bash scripts/verify/m014-p03-apply.sh
PASS: Case A: happy path applies, actioned, event-logged
PASS: Case B: stale-diff refused, no actioned.jsonl row appended
PASS: Case C: in-flight conversus refused
PASS: Case D: wrong-class refused (uat-bug rejected by manual-apply path)
PASS: Case E: missing queue-id refused
SUMMARY: pass=5 fail=0 -> exit 0

$ bash scripts/verify/m014-p03-reject-triage.sh
PASS: Case A: reject records applied:false + reason in actioned.jsonl
PASS: Case B: missing --reason refused with exit 2
PASS: Case C: missing queue-id refused with exit 2
PASS: Case D: empty triage prints entries=0
PASS: Case E: triage lists entry with conversus_verdict + count
SUMMARY: pass=5 fail=0 -> exit 0

$ bash scripts/verify/m014-p03-spec-amendment-human-gate.sh
PASS: apply.sh enforces class=spec-amendment manual gate
PASS: no auto-apply-spec-amendment pattern in scripts/comments/
PASS: commands/comments.md documents human-gate invariant
PASS: classify.sh docstring asserts spec-amendment always queues
SUMMARY: pass=4 fail=0 -> exit 0
```

Plus anti-pattern lint clean on `commands/comments.md`. Bash 3.2 compat verified — no `${var,,}`, no `mapfile`, no `declare -A`, no process substitution, no `&>` outside docstring comments.

## Contracts Handed Off to T04

- **`scripts/comments/apply.sh <queue-id>`** — invocable from T04's master `comments.sh` `apply` subcommand. Honors `ORCHESTRATOR_PROJECT_ROOT`. Exit 0 on success, 2 on user error (wrong class, missing queue, stale, in-flight), 1 on internal error (patch failed after dry-run succeeded).
- **`scripts/comments/reject.sh <queue-id> --reason "<prose>"`** — invocable from T04 `reject` subcommand. Exit 0/2.
- **`scripts/comments/triage.sh`** — invocable from T04 `triage` subcommand. Exit 0 always (read-only).
- **Review-queue convention** — `.orchestrator/comments/review-queue/<queue-id>.md` with frontmatter `{comment_url, class, confidence, proposed_action, queued_at, queue_id, target_spec_path, target_chunk_id}` and a ```diff fenced block in the body. T04's classify pipeline writes these files when `class==spec-amendment`.
- **Triage convention** — `.orchestrator/comments/triage/<id>.md` with frontmatter `{comment_url, conversus_verdict, reason}`. T04's classify pipeline writes these when ambiguous + low-confidence conversus verdict.
- **`actioned.jsonl` `action_taken` field** — additive optional field populated by apply/reject. T04 can rely on it to distinguish row types.
- **SC-5 invariant guard** — T04 must NOT add an auto-apply branch for spec-amendment in `comments.sh` or any other script under `scripts/comments/`. The human-gate verifier will fail the build.

## Files Touched (Created Only — No Modifications to Existing Files)

- `commands/comments.md` (new, ~120 lines)
- `scripts/comments/apply.sh` (new, ~125 lines, executable)
- `scripts/comments/reject.sh` (new, ~75 lines, executable)
- `scripts/comments/triage.sh` (new, ~45 lines, executable)
- `tests/fixtures/m014-p03/queued-amendment.md` (new, ~25 lines)
- `scripts/verify/m014-p03-commands-md.sh` (new, ~85 lines, executable)
- `scripts/verify/m014-p03-apply.sh` (new, ~155 lines, executable)
- `scripts/verify/m014-p03-reject-triage.sh` (new, ~140 lines, executable)
- `scripts/verify/m014-p03-spec-amendment-human-gate.sh` (new, ~100 lines, executable)

D007 reuse honored — `scripts/dispatch/adapters/tool/conversus.sh` not modified.
