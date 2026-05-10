---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P04"
milestone: "M021"
provides:
  - "scripts/verify/replay-prompt-corpus.sh — M021 SC-1 regression gate that parses tests/fixtures/m021-prompt-corpus.txt (20 entries), sources scripts/verify/lib/shape-classifier.sh and invokes classify_command per INPUT (Layer 1), pipes synthetic Claude-Code stdin JSON through scripts/hooks/pre-bash-shape-guard.sh and asserts rc/stdout/stderr match the classifier decision (Layer 2), counts non-grammar classifier outputs as WOULD_PROMPT leaks, and emits the canonical final lines WOULD_PROMPT=0/20 + PASS: replay-prompt-corpus.sh; exits 0 iff WOULD_PROMPT=0 AND all 40 per-entry assertions pass AND entry count is 20"
requires:
  - "from:P04/T01 what:tests/fixtures/m021-prompt-corpus.txt 20-entry corpus (ID/SCREENSHOT/INPUT/EXPECTED_OUTCOME); from:P03/T01 what:scripts/verify/lib/shape-classifier.sh classify_command API; from:P03/T02 what:scripts/hooks/pre-bash-shape-guard.sh stdin-JSON hook protocol"
affects:
  - "P04/T05"
key_files:
  - "scripts/verify/replay-prompt-corpus.sh"
key_decisions:
  - "AD-19,AD-2"
patterns_established:
  - "Two-layer replay gate (pure classifier assertion + end-to-end hook assertion per entry); awk-to-tempfile corpus parser keeps parallel id/input/expected records addressable in Bash 3.2 without associative arrays; printf %b to decode literal backslash-n from the fixture into real newlines before classification; pure-Bash JSON-string escaping for stdin synthesis (backslash, double-quote, newline only — no jq dependency); rejects-dominate-rewrites precedence preserved downstream from P03 by passing classifier output through unchanged; WOULD_PROMPT=N/M headline metric counts classifier-grammar violations only so a would-prompt leak is distinguishable from a simple expected-mismatch failure"
drill_down_paths:
  - ".orchestrator/milestones/M021/phases/P04/tasks/T02-PLAN.md,.orchestrator/milestones/M021/phases/P04/tasks/T02-PAYLOAD.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-17T21:31:52Z"
---

T02 ships scripts/verify/replay-prompt-corpus.sh — the authoritative SC-1 regression gate for M021. The gate replays all 20 M011/P05-P07 corpus entries against both the shape-classifier library (Layer 1) and the pre-bash-shape-guard hook (Layer 2) and asserts end-to-end coherence.

GATE SHAPE: ~170 lines of Bash 3.2. set -u. Resolves REPO_ROOT via BASH_SOURCE, precondition-checks corpus / classifier / hook presence, sources the classifier, parses the corpus through an awk one-pass into a tab-separated tempfile, then iterates entries via while-read.

LAYER 1 — Classifier: classify_command "$decoded" is invoked on each printf '%b'-decoded INPUT. The output is first validated against the closed three-form grammar (allow|rewrite:*|reject:*); any deviation increments the would_prompt leak counter. Legal outputs are then compared byte-for-byte against EXPECTED_OUTCOME.

LAYER 2 — Hook: Synthetic stdin JSON with tool_name=Bash and tool_input.command=<escaped-input> is built via pure-Bash string escaping (backslash, double-quote, newline only). Piped into the hook script with stdout/stderr captured to tempfiles. The exit code + output shape must match the classifier's decision: allow -> rc=0 + empty stdout; rewrite:X -> rc=0 + X present in stdout JSON; reject:C -> rc=2 + 'REJECT: C' on stderr.

RESULT: 20/20 classifier assertions + 20/20 hook assertions + 1 entry-count assertion = 41 PASS lines. Final output WOULD_PROMPT=0/20 + PASS: replay-prompt-corpus.sh. Exit 0. Runtime ~1.5s (20 classifier calls + 20 hook subprocesses + awk + 2 mktemps per entry).

KEY DECISIONS:
- Filename kept as replay-prompt-corpus.sh (not m021-p04-replay-prompt-corpus.sh) per the roadmap / spec canonical name. T05 phase-suite invokes it explicitly alongside glob discovery of m021-p04-*.sh.
- Gate internals use command-substitution, pipes, awk, mktemp, heredocs freely per AP-004 scope-of-enforcement carve-out + MEM004 — verification-script internals are not agent-facing tool-call sites.
- WOULD_PROMPT counter is scoped to classifier-grammar violations (the would-prompt leak surface), not to expected-mismatch failures. A grammar violation is the only path by which a real prompt could reach a user; mismatches are still fail_count but not counted as prompts. This preserves the headline metric semantics (zero leaks) even under partial regressions.
- Bash 3.2 safe: the pattern-substitution parameter expansion used for JSON escaping is 3.2-compatible (only the case-conversion forms are 4+). No associative arrays, no mapfile / readarray, no process substitution.

PATTERNS ESTABLISHED:
- Two-layer replay gate: classifier (pure) + hook (end-to-end) in one pass. Layer 1 detects classifier regressions; Layer 2 detects hook-protocol regressions even when the classifier is correct.
- awk-to-tempfile corpus parsing replaces Bash 3.2 absent associative-array parallel arrays with a single tab-delimited record file consumed by while-IFS-read.
- Hook reject diagnostic asserted with grep -F on 'REJECT: <class>' prefix — robust to the em-dash (U+2014) byte sequence and to any future diagnostic suffix changes.

DEVIATIONS FROM PLAN: none. The scaffold in T02-PAYLOAD.md was adopted verbatim with one minor cleanup — fail() messages precompute the stdout/stderr contents into local variables before interpolation, to avoid inlining command substitution inside the fail() argument. Cosmetic only, identical semantics.

VERIFICATION: bash scripts/verify/replay-prompt-corpus.sh exits 0 with 40 per-entry PASS + 1 entry-count PASS + WOULD_PROMPT=0/20 + PASS: replay-prompt-corpus.sh. bash -n parses clean. No forbidden Bash-4 constructs.
