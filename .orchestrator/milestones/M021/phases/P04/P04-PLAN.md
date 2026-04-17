---
schema_version: "1.0"
phase: "P04"
milestone: "M021"
type: phase-plan
goal: "Ship the permanent replay regression corpus + two phase gates that prove M021's integrated system (P01 wrappers + P02 linter v2 + P03 hook + widened settings) actually closes the 20 M011/P05–P07 prompt triggers, plus the append-only D012 decision entry recording the M021-before-M019 reorder and the ANTIPATTERNS.md AP-IDs cross-reference pass. The replay corpus is permanent (constitution VII — knowledge compounds) and becomes part of the standing verify ladder."
demo_sentence: "A developer runs `bash scripts/verify/replay-prompt-corpus.sh`. The script feeds each of the 20 verbatim tool-call strings from `tests/fixtures/m021-prompt-corpus.txt` through the P03 shape-classifier + hook, prints per-entry `PASS:` lines, and exits 0 with final line `WOULD_PROMPT=0/20`. A developer runs `bash scripts/verify/m021-p04-dogfood-attestation.sh`. The gate inspects `.orchestrator/milestones/M021/auto-loop-result.txt` + `.orchestrator/milestones/M021/execution-log.jsonl`, confirms no `HOOK_REJECT_UNEXPECTED` or `USER_PROMPT` markers exist for M021's own P01–P04 auto execution, and exits 0 with `PASS: m021-p04-dogfood-attestation.sh`. `bash scripts/verify/run-suite.sh m021 P04` reports PASS: 3 / FAIL: 0 across the three P04 gates (replay, dogfood, bash32-compat)."
risk: "medium"
depends_on: ["P01", "P02", "P03"]
---

## Must-Haves

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     All Check: commands use single-invocation script-file shape per AD-19.
     No inline compound bash, no plain subshells, no $(...) with pipes. -->

### Truths

- `tests/fixtures/m021-prompt-corpus.txt` exists, is a plain-text fixture (no YAML frontmatter) with exactly 20 entries separated by `---` lines, and each entry has two labelled fields on dedicated lines — `INPUT: <verbatim Bash tool-call string>` and `EXPECTED_OUTCOME: <allow|rewrite:<result>|reject:<pattern-class>>`. Each `EXPECTED_OUTCOME` value uses the exact pattern-class labels emitted by `scripts/verify/lib/shape-classifier.sh` (`allow`, `rewrite:<canonical-rewrite>`, or one of `reject:trailing-rc-echo`, `reject:sed-n-range`, `reject:cat-heredoc-exec`, `reject:cd-and-bash`, `reject:var-inline-bash`, `reject:redirect-cmd-sub`, `reject:nested-cmd-sub`, `reject:compound-chain-gt2`, `reject:heredoc-with-expansion`, `reject:quoted-brace`). Entries are grounded in the 20 M011/P05–P07 screenshots (AD-5).
  - Check: `bash scripts/verify/m021-p04-corpus-shape.sh`
- `scripts/verify/replay-prompt-corpus.sh` is an executable gate script that parses `tests/fixtures/m021-prompt-corpus.txt`, sources `scripts/verify/lib/shape-classifier.sh`, invokes `classify_command` on each entry's `INPUT:` value, compares the classifier output to the entry's `EXPECTED_OUTCOME:` value, and additionally drives the hook `scripts/hooks/pre-bash-shape-guard.sh` for each entry (feeding synthetic stdin JSON with `tool_name=Bash` and `tool_input.command=<INPUT>`) to confirm the end-to-end hook decision matches. The gate prints one `PASS:` / `FAIL:` line per corpus entry, a final `WOULD_PROMPT=N/20` line where N is the count of entries whose classifier output was NOT `allow|rewrite:*|reject:*` (i.e. hypothetical leak cases), and exits 0 only when N=0 AND every entry's classifier output equals its EXPECTED_OUTCOME.
  - Check: `bash scripts/verify/replay-prompt-corpus.sh`
- `scripts/verify/m021-p04-dogfood-attestation.sh` is an executable gate that asserts M021's own auto-execution of phases P01–P04 produced zero user-prompt events. It reads `.orchestrator/milestones/M021/auto-loop-result.txt` (phase transition marker file — must exist), parses `.orchestrator/milestones/M021/execution-log.jsonl` for any record whose `event` field equals `user_prompt` or `hook_reject_unexpected` (these are absent under clean execution), and inspects `.orchestrator/milestones/M021/phases/P*/P*-SUMMARY.md` for a `verification_result: pass` frontmatter line for each closed phase. Exit 0 with `PASS: m021-p04-dogfood-attestation.sh` when all three checks hold; exit 1 otherwise with `FAIL:` lines naming the failing check.
  - Check: `bash scripts/verify/m021-p04-dogfood-attestation.sh`
- `.orchestrator/DECISIONS.md` contains exactly one new row whose `#` column reads `D012`, whose `Scope` column includes `sequencing`, whose `Decision` column names `M021 before M019` (or equivalent text containing both milestone IDs), and whose `Rationale` column explicitly references "zero-prompt baseline" as the justification. D010 and D011 remain byte-identical — strict-superset append (M016 convention). The file grows by exactly one row.
  - Check: `bash scripts/verify/m021-p04-decisions-d012.sh`
- `ANTIPATTERNS.md` adds a single new "Cross-References" subsection OR extends the existing AP-005..AP-009 entries with a `Cross-Refs:` line naming both `scripts/hooks/pre-bash-shape-guard.sh` (P03 hook enforcement) and `tests/fixtures/m021-prompt-corpus.txt` (P04 regression corpus) per AP ID, so a reader landing on any AP-005..AP-009 entry has one-hop paths to both the prevent layer (linter/hook) and the detect layer (replay corpus). AP-001..AP-004 are not modified. File grows by ≥5 non-blank lines; no existing lines are removed.
  - Check: `bash scripts/verify/m021-p04-antipatterns-crossrefs.sh`
- All five new shell files authored in P04 (`scripts/verify/replay-prompt-corpus.sh`, `scripts/verify/m021-p04-dogfood-attestation.sh`, `scripts/verify/m021-p04-corpus-shape.sh`, `scripts/verify/m021-p04-decisions-d012.sh`, `scripts/verify/m021-p04-antipatterns-crossrefs.sh`, `scripts/verify/m021-p04-bash32-compat.sh`) parse clean with `bash -n` and contain no forbidden Bash-4 constructs (`declare -A`, `mapfile`, `readarray`, `${var,,}`, `${var^^}`, `${!prefix*}`, process substitution `<(`).
  - Check: `bash scripts/verify/m021-p04-bash32-compat.sh`
- `bash scripts/verify/run-suite.sh m021 P04` reports PASS across all P04 gate scripts (replay-prompt-corpus, m021-p04-dogfood-attestation, m021-p04-corpus-shape, m021-p04-decisions-d012, m021-p04-antipatterns-crossrefs, m021-p04-bash32-compat) — discovered via the filename pattern `scripts/verify/m021-p04-*.sh` plus `scripts/verify/replay-prompt-corpus.sh` invoked explicitly from the phase integration gate.
  - Check: `bash scripts/verify/m021-p04-phase-suite.sh`

### Artifacts

- `tests/fixtures/m021-prompt-corpus.txt` (create, min 60 lines, contains `INPUT:`, `EXPECTED_OUTCOME:`, `allow`, `rewrite:`, `reject:`, `---`)
- `scripts/verify/replay-prompt-corpus.sh` (create, min 120 lines, contains `classify_command`, `INPUT:`, `EXPECTED_OUTCOME:`, `WOULD_PROMPT=`, `shape-classifier.sh`, `pre-bash-shape-guard.sh`)
- `scripts/verify/m021-p04-dogfood-attestation.sh` (create, min 80 lines, contains `auto-loop-result.txt`, `execution-log.jsonl`, `verification_result: pass`, `user_prompt`, `hook_reject_unexpected`, `PASS: m021-p04-dogfood-attestation.sh`)
- `scripts/verify/m021-p04-corpus-shape.sh` (create, min 70 lines, contains `INPUT:`, `EXPECTED_OUTCOME:`, `20`, `---`, `m021-prompt-corpus.txt`)
- `scripts/verify/m021-p04-decisions-d012.sh` (create, min 40 lines, contains `D012`, `sequencing`, `M019`, `DECISIONS.md`, `zero-prompt`)
- `scripts/verify/m021-p04-antipatterns-crossrefs.sh` (create, min 40 lines, contains `AP-005`, `AP-006`, `AP-007`, `AP-008`, `AP-009`, `pre-bash-shape-guard.sh`, `m021-prompt-corpus.txt`)
- `scripts/verify/m021-p04-bash32-compat.sh` (create, min 50 lines, contains `bash -n`, `declare -A`, `mapfile`, `readarray`, `<(`, `replay-prompt-corpus.sh`, `m021-p04-dogfood-attestation.sh`)
- `scripts/verify/m021-p04-phase-suite.sh` (create, min 40 lines, contains `run-suite.sh`, `m021`, `P04`, `PASS:`, `FAIL:`)
- `.orchestrator/DECISIONS.md` (modify — append one D012 row; file must still contain `D001` through `D011` verbatim plus new `D012` row; file grows by ≥1 non-blank line)
- `ANTIPATTERNS.md` (modify — add Cross-Refs lines on AP-005..AP-009; file must still contain `AP-001` through `AP-009` headings verbatim plus the new cross-ref text referencing `pre-bash-shape-guard.sh` and `m021-prompt-corpus.txt`)

### Key Links

- `tests/fixtures/m021-prompt-corpus.txt` → M011/P05–P07 screenshots (source of the 20 verbatim strings, per AD-5)
- `scripts/verify/replay-prompt-corpus.sh` → `tests/fixtures/m021-prompt-corpus.txt` (reads fixture)
- `scripts/verify/replay-prompt-corpus.sh` → `scripts/verify/lib/shape-classifier.sh` (sources classifier library)
- `scripts/verify/replay-prompt-corpus.sh` → `scripts/hooks/pre-bash-shape-guard.sh` (drives hook via stdin JSON for end-to-end verification)
- `scripts/verify/m021-p04-dogfood-attestation.sh` → `.orchestrator/milestones/M021/auto-loop-result.txt` (reads auto-loop marker)
- `scripts/verify/m021-p04-dogfood-attestation.sh` → `.orchestrator/milestones/M021/execution-log.jsonl` (scans for prompt/hook-reject events)
- `scripts/verify/m021-p04-corpus-shape.sh` → `tests/fixtures/m021-prompt-corpus.txt` (validates fixture structure)
- `scripts/verify/m021-p04-decisions-d012.sh` → `.orchestrator/DECISIONS.md` (asserts D012 row exists with required substrings)
- `scripts/verify/m021-p04-antipatterns-crossrefs.sh` → `ANTIPATTERNS.md` (asserts AP-005..AP-009 cross-refs added)
- `.orchestrator/DECISIONS.md` → `M019` (D012 rationale text references M019 sequencing)
- `ANTIPATTERNS.md` → `scripts/hooks/pre-bash-shape-guard.sh`, `tests/fixtures/m021-prompt-corpus.txt` (AP-005..AP-009 entries cross-reference both the hook enforcement layer and the replay corpus)

## Tasks

### T01: Replay corpus fixture (`tests/fixtures/m021-prompt-corpus.txt`)

See `tasks/T01-PLAN.md`.

### T02: Replay gate (`scripts/verify/replay-prompt-corpus.sh`)

See `tasks/T02-PLAN.md`.

### T03: Dogfood attestation gate (`scripts/verify/m021-p04-dogfood-attestation.sh`)

See `tasks/T03-PLAN.md`.

### T04: DECISIONS.md D012 + ANTIPATTERNS.md cross-references

See `tasks/T04-PLAN.md`.

### T05: Phase integration gates (`m021-p04-corpus-shape.sh`, `m021-p04-decisions-d012.sh`, `m021-p04-antipatterns-crossrefs.sh`, `m021-p04-bash32-compat.sh`, `m021-p04-phase-suite.sh`)

See `tasks/T05-PLAN.md`.

## Task Dependencies

```
T01 → T02 → T05
T01 → T03 → T05
T01 → T04 → T05
```

T01 ships the permanent regression corpus — the authoritative fixture for SC-1 (AD-5). T02 (replay gate) and T03 (dogfood gate) both consume T01's fixture path but exercise different surfaces: T02 validates the shape-classifier's decisions against EXPECTED_OUTCOME for every corpus entry (and drives the hook end-to-end on each INPUT); T03 validates that M021's own auto execution produced no prompt events. T04 is administrative — appends D012 to DECISIONS.md and adds cross-reference lines to AP-005..AP-009 entries in ANTIPATTERNS.md; independent of T02/T03 outputs but logically follows T01 since the ANTIPATTERNS cross-refs name `m021-prompt-corpus.txt`. T05 is the phase integration gate cluster — five small assertion gates (corpus-shape, decisions-d012, antipatterns-crossrefs, bash32-compat, phase-suite) that each enforce one truth from the must-haves against T01–T04's outputs. T05 runs last because its assertions depend on all prior outputs being in place.

T02 and T03 and T04 are parallel-safe after T01 completes — they touch disjoint artifacts. The orchestrator's serial dispatch discipline (AD-1) means they execute in order T02 → T03 → T04, but any correctness issue in one does not cascade.

## Files Likely Touched

- `tests/fixtures/m021-prompt-corpus.txt` (create)
- `scripts/verify/replay-prompt-corpus.sh` (create)
- `scripts/verify/m021-p04-dogfood-attestation.sh` (create)
- `scripts/verify/m021-p04-corpus-shape.sh` (create)
- `scripts/verify/m021-p04-decisions-d012.sh` (create)
- `scripts/verify/m021-p04-antipatterns-crossrefs.sh` (create)
- `scripts/verify/m021-p04-bash32-compat.sh` (create)
- `scripts/verify/m021-p04-phase-suite.sh` (create)
- `.orchestrator/DECISIONS.md` (modify — append D012 row only)
- `ANTIPATTERNS.md` (modify — add Cross-Refs lines to AP-005..AP-009 only)

## Boundary Assertion

- **Produces exactly**: the 20-entry corpus fixture, five new gate scripts + the phase-suite wrapper + the bash32-compat gate (8 new files total: 1 fixture + 7 shell scripts), plus two additive edits (one D012 row in DECISIONS.md, five Cross-Refs additions in ANTIPATTERNS.md). Nothing else.
- **Does not touch**: `scripts/util/*.sh` (P01 territory — referenced by name only in corpus EXPECTED_OUTCOME rewrite values and from DECISIONS.md rationale text), `scripts/verify/anti-pattern-lint.sh` (P02 territory), `scripts/hooks/pre-bash-shape-guard.sh` + `scripts/verify/lib/shape-classifier.sh` + `.claude/settings.json` (P03 territory — read-only in T02), `scripts/dispatch/lib/section-handlers.sh` (P03 territory). No modifications to any command or template.
- **Consumes**: the three wrappers from P01 by name (corpus rewrite EXPECTED_OUTCOME values reference `scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh` verbatim); the five AP anchors from P02 (AP-005..AP-009) by ID in ANTIPATTERNS cross-refs; the P03 hook + classifier library by path (T02 sources classifier and pipes stdin JSON to hook); `.orchestrator/milestones/M021/auto-loop-result.txt` + `execution-log.jsonl` + each phase's `P*-SUMMARY.md` from prior M021 phase executions.
- **Scope of the corpus**: exactly 20 entries per AD-5, grounded in M011/P05–P07 screenshot evidence. No speculative additions (constitution XIV). Adding a 21st entry requires a new M011 screenshot and a new milestone/phase justification.
- **No SUMMARY**: The M021-SUMMARY.md (with SC-1..SC-7 result table, per roadmap) is produced at milestone close by the standard close workflow, not by any P04 task. P04 ships the inputs the close workflow consumes (replay-corpus PASS, dogfood-attestation PASS, D012 entry, cross-refs) — the summary author composes them into the SC table.
- **D010 → D012**: The roadmap and M021-CONTEXT.md anticipate a `D010` decision entry, authored at the time when `D010` was the next available ID. Between then and P04 execution, `D010` (M018 framing amendment) and `D011` (M020 trigger criteria) landed. P04 logs the M021-before-M019 reorder as **D012** — next available sequential ID — with narrative text explicitly referencing the previously-planned `D010` slot for audit trail. This is a surgical correction (constitution XV), not a semantic change.
- **Scope of enforcement (linter)**: P04 scripts run through the live P03 hook. Gate internals may freely use `$()`, pipes, subshells, heredocs inside verify-script bodies (MEM004 + AP-004 scope-of-enforcement carve-out — enforcement applies to inline tool-call sites, not verification-script internals).
