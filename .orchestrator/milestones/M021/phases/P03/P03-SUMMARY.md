---
schema_version: "1.0"
type: phase-summary
id: "P03"
parent: "M021"
milestone: "M021"
provides:
  - "scripts/verify/lib/shape-classifier.sh sourceable pure-function library exposing classify_command that maps a Bash command string to one of allow / rewrite:<result> / reject:<pattern-class> across the closed 10-pattern matrix (6 rewrites + 4 rejects per AD-2), scripts/hooks/pre-bash-shape-guard.sh PreToolUse hook implementing Claude Code hook protocol: allow passthrough, rewrite JSON emission, and reject exit-2 diagnostic with wrapper-pointing remediation text, .claude/settings.json PreToolUse hook registration (bash scripts/hooks/pre-bash-shape-guard.sh, Bash matcher, single-hook per AD-1a), 9 new allow-list entries widening the M016 set without removing any pre-existing entry, scripts/dispatch/lib/section-handlers.sh handle_template constraints branch extended with a sibling Allowed invocation shapes subsection naming the three P01 wrappers with usage examples, tests/hook/rewrite-cases.sh (6 synthetic stdin-JSON rewrite cases, one per matrix pattern: trailing-rc-echo, sed-n-range, cat-heredoc-exec, cd-and-bash, var-inline-bash, redirect-cmd-sub); tests/hook/reject-cases.sh (4 synthetic stdin-JSON reject cases: nested-cmd-sub, compound-chain-gt2, heredoc-with-expansion, quoted-brace — asserts exit 2 + exact UTF-8 em-dash diagnostic line), scripts/verify/m021-p03-hook-integration.sh — P03 integration gate asserting end-to-end coherence across classifier (T01), hook (T02), settings + dispatch section (T03), and test harness (T04). 46 PASS assertions in six groups: classifier (14), hook protocol (3), settings (11), dispatch constraints (6), harness (2), bash32-compat (10)."
requires:
  - "from:P01 what:scripts/util/with-env.sh; from:P01 what:scripts/util/read-range.sh; from:P01 what:scripts/util/run-probe.sh; from:P02 what:AP-005..AP-009 pattern-class naming, from:T01 what:scripts/verify/lib/shape-classifier.sh classify_command API, from:T02 what:scripts/hooks/pre-bash-shape-guard.sh; from:P01 what:scripts/util/with-env.sh,read-range.sh,run-probe.sh, from:T01 what:scripts/verify/lib/shape-classifier.sh (classification labels); from:T02 what:scripts/hooks/pre-bash-shape-guard.sh (hook under test), from:T01 what:scripts/verify/lib/shape-classifier.sh; from:T02 what:scripts/hooks/pre-bash-shape-guard.sh; from:T03 what:.claude/settings.json + scripts/dispatch/lib/section-handlers.sh; from:T04 what:tests/hook/rewrite-cases.sh + tests/hook/reject-cases.sh"
affects:
  - "P03,P03/T02,P03/T05, P03,P04, P03,P04,P05, P03/T05, P03"
key_files:
  - "scripts/verify/lib/shape-classifier.sh, scripts/hooks/pre-bash-shape-guard.sh, .claude/settings.json,scripts/dispatch/lib/section-handlers.sh, tests/hook/rewrite-cases.sh,tests/hook/reject-cases.sh, scripts/verify/m021-p03-hook-integration.sh"
key_decisions:
  - "AD-2,AD-19, AD-1a,AD-2, AD-1a,SC-5, AD-2,AD-19, AD-19"
patterns_established:
  - "rejects-dominate-rewrites precedence; character-by-character top-level stage counter with quote+paren+backtick state tracking (Bash 3.2 safe); quoted-vs-unquoted heredoc opener discrimination; variable-assembled ERE for single-quote class membership; redirect-cmd-sub emits deterministic rewrite to read-range.sh with runtime args deferred (plan option (a)), BSD-sed ERE (-E) for JSON string extraction with escaped-quote handling; pure-Bash JSON extract without jq; fail-safe passthrough on malformed stdin; reject-diagnostic em-dash U+2014 byte sequence via printf; in-hook reject_lookup table keeps shape classifier pure, Additive JSON edit preserves existing allow entries in original order; JSON validity preserved across edit via python3 json.tool round-trip, pipe-synthetic-stdin hook test harness; trailing __EXIT__=<n> marker line to propagate subshell exit code past command substitution; sed -E (ERE) extraction of updatedInput.command matching the hook's own emission regex; $'\xe2\x80\x94' literal UTF-8 em-dash in grep -F needle, comment-stripped forbidden-construct scan (grep -v leading-hash before grep -F); concatenation-split forbidden literals to prevent self-matching in the gate own source; hermetic subprocess-only coupling — gate creates no state"
drill_down_paths:
  - ".orchestrator/milestones/M021/phases/P03/tasks/T01-SUMMARY.md, .orchestrator/milestones/M021/phases/P03/tasks/T02-SUMMARY.md, .orchestrator/milestones/M021/phases/P03/tasks/T03-SUMMARY.md, .orchestrator/milestones/M021/phases/P03/tasks/T04-SUMMARY.md, .orchestrator/milestones/M021/phases/P03/tasks/T05-SUMMARY.md"
duration: "117m"
verification_result: "pass"
completed_at: "2026-04-17T19:48:08Z"
observability_surfaces:
  - "hook-live-dogfood"
---

P03 ships the **Pre-Bash Shape Guard hook** — a PreToolUse hook that deterministically rewrites six recoverable Bash shapes into wrapper invocations or hard-rejects four shapes with a wrapper-pointing diagnostic. Together with M016's Class A linter, P02's Class B linter, and the P01 wrapper catalog, P03 converts the residual 12 M011 trigger classes from "user prompts" into either transparent rewrites or stay-in-the-loop rejections.

## What Was Built

- `scripts/verify/lib/shape-classifier.sh` — 532-line sourceable pure-function library. Single API: `classify_command "<cmd>"` emits `allow` | `rewrite:<new-cmd>` | `reject:<class>:<AP-ID>`. Precedence: rejects dominate rewrites; default allow. Closed 10-pattern matrix per AD-2.
- `scripts/hooks/pre-bash-shape-guard.sh` — PreToolUse hook implementing the Claude Code hook protocol. Consumes stdin JSON, extracts `.tool_input.command` via pure-Bash sed-E, dispatches to the classifier, and emits the hook's response shape: allow → exit 0 empty stdout; rewrite → exit 0 + `{"hookSpecificOutput":{"hookEventName":"PreToolUse","updatedInput":{"command":...}}}`; reject → exit 2 + stderr diagnostic `REJECT: <class> — use scripts/util/<wrapper>.sh instead. See ANTIPATTERNS.md#<AP-ID>.` (em dash U+2014) + `{"decision":"block","reason":...}` on stdout. Fail-safe passthrough on malformed input.
- `.claude/settings.json` — additive edit: registered PreToolUse → Bash matcher → `bash scripts/hooks/pre-bash-shape-guard.sh`; added 9 widened allow entries (`Read(/var/folders/**)`, `Bash(bash /tmp/*.sh)`, `Bash(bash /var/folders/**/*.sh)`, `Bash(ls tmp/**)`, `Bash(cat tmp/**)`, `Bash(sed -n *)`, `Bash(head *)`, `Bash(tail *)`, `Bash(stat *)`). Pre-existing 75 allow + 36 deny entries byte-identical (strict-superset invariant).
- `scripts/dispatch/lib/section-handlers.sh` — `handle_template` constraints branch extended with an "Allowed invocation shapes" subsection naming the three P01 wrappers with usage examples.
- `tests/hook/rewrite-cases.sh` — 6 cases (trailing-rc-echo, sed-n-range, cat-heredoc-exec, cd-and-bash, var-inline-bash, redirect-cmd-sub). Pipes synthetic stdin-JSON into the hook and asserts the emitted `updatedInput.command` verbatim. Trailing `__EXIT__=<n>` marker propagates the subshell exit code past command-substitution.
- `tests/hook/reject-cases.sh` — 4 cases (nested-cmd-sub, compound-chain-gt2, heredoc-with-expansion, quoted-brace). Asserts exit 2 + exact UTF-8 em-dash diagnostic line + JSON body.
- `scripts/verify/m021-p03-hook-integration.sh` — phase gate with 46 PASS assertions across six groups: classifier (14), hook protocol (3), settings (11), dispatch constraints (6), harness (2), bash32-compat (10).

## Key Decisions

- **Hook is live** (AD-1a): as soon as `.claude/settings.json` is reloaded, every Bash tool call passes through the classifier. This is by design and provides immediate dogfood coverage — during T03 execution alone the hook rejected at least two compound-chain shapes the agent would otherwise have emitted.
- **Rewrite #6 (`redirect-cmd-sub`) is semantically approximate**: no mechanical transform can recover the runtime-determined target, so the rewrite emits a fixed `bash scripts/util/read-range.sh` placeholder. P04 will validate against the screenshot corpus; if mismatches surface, promote to reject.
- **Compound `&&` threshold at >2 stages**: 2-stage `cd X && Y` passes through as `allow` (it has its own dedicated rewrite pattern); 3+ stage chains reject.
- **BSD-sed ERE in hook + tests**: stock macOS `sed` needs `-E` for alternation groups. GNU-only BRE escaped forms produce silent failures. Variable-assembled ERE used where literal single quotes or em-dashes are needed.
- **Pure-Bash JSON extract** (AD-1a, no jq dependency): sed-E regex extracts `.tool_input.command` and unescapes `\\` and `\"` via a sentinel pass to avoid double-unescaping.
- **Fail-safe passthrough**: malformed JSON, missing command field, non-Bash tool → exit 0 + empty stdout. Never fails closed on parse anomalies.
- **Rejects-dominate-rewrites precedence**: a command matching both a reject and a rewrite is rejected (the reject matrix exists because those shapes have no behavior-preserving transform).
- **Pipe-synthetic-stdin test harness with `__EXIT__=<n>` marker**: lets the test driver capture the hook's exit code past `$(...)` without assuming a specific subshell-safe pattern.
- **Gate self-scan uses concatenation-split forbidden literals** so the gate script's own source doesn't match its own forbidden-pattern needles during self-inspection.

## Patterns Established

- **Hook ↔ classifier separation** keeps the classifier pure and unit-testable; the hook owns stdin/stdout IO.
- **Active live dogfood during execution**: the hook begins enforcing the moment T03 lands. T04/T05 execute under the live hook, providing natural regression coverage.
- **Em-dash byte sequence `\xe2\x80\x94` via `printf`/`$'...'`** where the exact UTF-8 bytes matter.
- **Strict-superset settings edits**: never remove pre-existing allow/deny entries; only append.
- **PAYLOAD scope filter**: the v2 linter still returns 0 because the active-task exclusion (P02 patterns) excludes T##-PAYLOAD.md once sibling SUMMARY exists — consistent with P01/P02 behavior.

## Verification Results

Phase suite `bash scripts/verify/run-suite.sh m021 P03` reports PASS: 1 / FAIL: 0. Integration gate `bash scripts/verify/m021-p03-hook-integration.sh` reports 46 PASS assertions + final `PASS: m021-p03-hook-integration.sh`. Full-repo lint sweep `bash scripts/verify/anti-pattern-lint.sh` exits 0. External-modification check: no external modifications. All five task summaries present.

## Downstream Impact

P04 (Replay Corpus + Dogfood Attestation) consumes the classifier as its shape-decision source of truth when replaying the 20 M011/P05–P07 screenshots, asserts `WOULD_PROMPT=0/20`, and produces the milestone dogfood attestation. The hook is already live from P04's perspective — P04's own execution under the hook IS the dogfood evidence.
