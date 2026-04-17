---
schema_version: "1.0"
type: milestone-summary
id: "M021"
parent: "021-autonomous-hardening-v2"
milestone: "M021"
provides:
  - "Zero-prompt autonomous execution on default project settings — three-layer defense (wrapper catalog + linter v2 + pre-Bash hook) plus a permanent 20-entry regression corpus and self-validating dogfood attestation. Delivers: scripts/util/with-env.sh+read-range.sh+run-probe.sh (P01 wrapper catalog); scripts/verify/anti-pattern-lint.sh v2 with 5 Class B detectors + PAYLOAD scope (P02); scripts/hooks/pre-bash-shape-guard.sh 10-pattern rewrite/reject hook + scripts/verify/lib/shape-classifier.sh + widened .claude/settings.json (P03); tests/fixtures/m021-prompt-corpus.txt + scripts/verify/replay-prompt-corpus.sh + scripts/verify/m021-p04-dogfood-attestation.sh + AP-005..AP-009 Cross-Refs + D012 (P04)"
requires:
  - "M016 Class A hardening baseline (constitution IX Bash 3.2 compat; anti-pattern-lint.sh v1); 20 M011/P05-P07 auto-mode screenshots as the evidence corpus"
affects:
  - "M019 Tier 1 metrics emitter (now lands on a true zero-prompt baseline); all subsequent auto-mode milestones (M012-M014, M019, M018, M009) inherit the hook + wrapper catalog; orchestrator:auto workflow (dispatch payload now documents Allowed invocation shapes)"
key_files:
  - "scripts/util/with-env.sh+scripts/util/read-range.sh+scripts/util/run-probe.sh+scripts/util/README.md, scripts/verify/anti-pattern-lint.sh+ANTIPATTERNS.md, scripts/hooks/pre-bash-shape-guard.sh+scripts/verify/lib/shape-classifier.sh+.claude/settings.json+scripts/dispatch/lib/section-handlers.sh, tests/fixtures/m021-prompt-corpus.txt+scripts/verify/replay-prompt-corpus.sh+scripts/verify/m021-p04-dogfood-attestation.sh+.orchestrator/DECISIONS.md+scripts/verify/m021-p04-phase-suite.sh"
key_decisions:
  - "AD-2 rejects-dominate-rewrites precedence, AD-5 locked corpus size (20 entries), AD-6 hook_reject_recovered is the success signal not a failure, AD-8 dogfood-attestation pattern (continues M016), AD-11 append-only discipline for DECISIONS+ANTIPATTERNS, AD-19 single-script-file invocation shape for agent-facing commands, D012 M021-before-M019 sequencing, MEM004 gate-internals carve-out, constitution IX Bash 3.2 compat, constitution XIV no speculative complexity (locked entry count), constitution XV surgical precision (D012 row normalization)"
patterns_established:
  - "Shape-classifier as single source of truth consumed by both hook enforcement and replay regression; permanent fixture corpus with verbatim screenshot provenance and literal backslash-n multi-line encoding; two-layer replay gate (pure classifier + end-to-end hook stdin-JSON); WOULD_PROMPT=N/M headline metric distinguishes leaks from expected-mismatch; dogfood attestation from state-on-disk landmarks (auto-loop marker + execution-log.jsonl + phase summaries) with zero mutation; concatenation-split forbidden literals prevent linter self-match; self-recursion guard via env flag for scripts discovered by their own glob; awk-to-tempfile corpus parser addressable in Bash 3.2 without associative arrays; pure-Bash JSON-string escaping for stdin synthesis without jq dependency; MEM004 gate-internals carve-out separates agent-facing invocation shape from verification-script INTERNALS"
drill_down_paths:
  - ".orchestrator/milestones/M021/phases/P01/P01-SUMMARY.md,.orchestrator/milestones/M021/phases/P02/P02-SUMMARY.md,.orchestrator/milestones/M021/phases/P03/P03-SUMMARY.md,.orchestrator/milestones/M021/phases/P04/P04-SUMMARY.md"
duration: "99m"
verification_result: "pass"
completed_at: "2026-04-17T21:59:14Z"
observability_surfaces:
  - "execution-log.jsonl prompt-event fields (user_prompt, safety_prompt, hook_reject_unexpected, hook_reject_recovered); WOULD_PROMPT=N/M metric from replay-prompt-corpus.sh; auto-loop-result.txt marker per phase"
---

## What was built

M021 closed every residual Claude Code safety-prompt trigger that survived M016, so orchestrator:auto now runs multi-task phases to completion under project-default settings with zero user approvals. Four phases delivered a three-layer defense:

**P01 — Wrapper Catalog** (`scripts/util/with-env.sh`, `read-range.sh`, `run-probe.sh`). Three single-purpose wrappers that replace the three recurring shape-unsafe inline-bash patterns observed across M011/P05–P07 auto runs. Bash 3.2-compatible, each with its own gate script.

**P02 — Linter v2 + Shape Detectors**. `scripts/verify/anti-pattern-lint.sh` extended with five Class B detectors (simple-expansion, redirect-cmd-sub, quoted-brace, heredoc-expansion, task-plan-compound) and widened scope to scan `.orchestrator/milestones/**/tasks/*-PAYLOAD.md`. AP-005..AP-009 authored in `ANTIPATTERNS.md` with M011 screenshot citations.

**P03 — Pre-Bash Hook + Permission Widening**. `scripts/hooks/pre-bash-shape-guard.sh` implements a 10-pattern rewrite/reject matrix (6 deterministic rewrites, 4 hard rejects) via a shared classifier library `scripts/verify/lib/shape-classifier.sh`. `.claude/settings.json` registers the hook as PreToolUse and widens the allow-list for safe read-only shapes (`/var/folders/**`, `bash /tmp/*.sh`, project-relative `tmp/**`, `sed -n`, `head`, `tail`, `stat`). Dispatch payload gained an "Allowed invocation shapes" section via `scripts/dispatch/lib/section-handlers.sh`.

**P04 — Replay Corpus + Dogfood Attestation**. `tests/fixtures/m021-prompt-corpus.txt` locks the 20 M011/P05–P07 screenshot tool-call strings as a permanent regression corpus. `scripts/verify/replay-prompt-corpus.sh` runs a two-layer assertion (pure classifier + end-to-end hook via synthetic stdin JSON) emitting `WOULD_PROMPT=0/20` on success. `scripts/verify/m021-p04-dogfood-attestation.sh` reads state-on-disk landmarks (auto-loop marker, execution-log.jsonl, phase summaries) to attest that M021's own execution observed zero prompts. `.orchestrator/DECISIONS.md` gained D012 (M021-before-M019 reorder; originally-anticipated D010 slot was occupied, D012 is next free). AP-005..AP-009 gained Cross-Refs blocks citing the enforcement layer, regression corpus, and classifier.

## Success criteria

| SC  | Requirement | Result |
|-----|-------------|--------|
| SC-1 | 20-line replay corpus → zero would-prompt cases | PASS — `WOULD_PROMPT=0/20` via `scripts/verify/replay-prompt-corpus.sh` |
| SC-2 | Anti-pattern linter detects Class A + Class B across `commands/`, `templates/`, `scripts/dispatch/lib/`, `tasks/*-PAYLOAD.md` | PASS — `scripts/verify/m021-p02-linter-v2.sh` + `m021-p02-linter-scope.sh` |
| SC-3 | Three wrappers shipped, gate-tested, referenced from dispatch + linter hints | PASS — P01 gates + `scripts/util/README.md` catalog |
| SC-4 | Pre-Bash hook rewrites 6 shapes, hard-rejects 4 | PASS — `scripts/verify/m021-p03-hook-integration.sh` (46 assertions) |
| SC-5 | `.claude/settings.json` covers `/var/folders/**`, `bash /tmp/*.sh`, project-relative `tmp/**`, read-only `sed -n`/`head`/`tail`/`stat` | PASS — settings committed, drift scan clean |
| SC-6 | Fresh ≥4-task phase produces zero prompts under default settings | PASS — P04 itself (5 tasks) executed prompt-free |
| SC-7 | M021 closes itself with zero prompts (dogfood) | PASS — `scripts/verify/m021-p04-dogfood-attestation.sh` |

## Cross-cutting patterns

- **Shape-classifier as single source of truth** — library at `scripts/verify/lib/shape-classifier.sh`, consumed by both the hook (enforcement) and the replay gate (regression). Classifier drift is detected the moment the corpus diverges.
- **MEM004 / AP-004 gate-internals carve-out** — AD-19 single-script-file shape applies to agent-facing invocations; verification-script INTERNALS remain free to use pipes, `$()`, awk etc.
- **Concatenation-split forbidden literals** — compat gates and linter patterns split their needle strings so the gate source doesn't self-match during its own scan. Established P03, continued P04.
- **Rejects-dominate-rewrites precedence** — hook consults the reject table first, then the rewrite table; preserved byte-for-byte through the replay gate.
- **Permanent corpus with verbatim provenance** — 20 entries, locked count (AD-5 / constitution XIV). Future triggers earn a new milestone.
- **Dogfood attestation from state on disk** — no mutation; reads auto-loop marker + execution-log.jsonl + phase summaries; tolerant of `hook_reject_recovered` (AD-6 success signal).

## Verification

M021 closed with 4/4 phases complete, 19/19 tasks (1 P04/T planning + 5 per phase), 48/48 milestone validation checks PASS. P04 phase-suite PASS with `WOULD_PROMPT=0/20` and three dogfood checks green. Repo-wide `scripts/verify/anti-pattern-lint.sh` exits 0.

## Impact on forward roadmap

With M021 closed, orchestrator:auto runs on a true zero-prompt baseline — M019 Tier 1 metrics emitter can now dogfood without prompt overhead distorting duration/token measurements. Roadmap sequence post-M021: M019 Tier 1 → M012 → M013 → M014 → M019 Tier 2/3 → M018 → M009 → M010.
