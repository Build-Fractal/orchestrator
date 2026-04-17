---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P03"
milestone: "M021"
provides:
  - "scripts/hooks/pre-bash-shape-guard.sh PreToolUse hook implementing Claude Code hook protocol: allow passthrough, rewrite JSON emission, and reject exit-2 diagnostic with wrapper-pointing remediation text"
requires:
  - "from:T01 what:scripts/verify/lib/shape-classifier.sh classify_command API"
affects:
  - "P03,P04"
key_files:
  - "scripts/hooks/pre-bash-shape-guard.sh"
key_decisions:
  - "AD-1a,AD-2"
patterns_established:
  - "BSD-sed ERE (-E) for JSON string extraction with escaped-quote handling; pure-Bash JSON extract without jq; fail-safe passthrough on malformed stdin; reject-diagnostic em-dash U+2014 byte sequence via printf; in-hook reject_lookup table keeps shape classifier pure"
drill_down_paths:
  - ".orchestrator/milestones/M021/phases/P03/tasks/T02-PLAN.md"
duration: "25m"
verification_result: "pass"
completed_at: "2026-04-17T19:32:47Z"
---

Implemented scripts/hooks/pre-bash-shape-guard.sh per T02 plan.

## What Was Built

PreToolUse hook executable that reads Claude Code's hook JSON from stdin, extracts tool_name and tool_input.command via pure-Bash sed (no jq dependency), sources scripts/verify/lib/shape-classifier.sh (T01 output), invokes classify_command, and emits one of three outcomes:

- **allow** -> exit 0, empty stdout (normal permission evaluation proceeds).
- **rewrite:<X>** -> exit 0, single-line JSON `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":{"command":"<X-JSON-escaped>"}}}` on stdout.
- **reject:<class>** -> exit 2, stderr line `REJECT: <class> — use scripts/util/<wrapper>.sh instead. See ANTIPATTERNS.md#<AP-ID>.` (em dash U+2014 bytes e2 80 94).

Reject lookup table inside the hook maps classifier pattern-classes to (wrapper, AP-ID) pairs per AD-2: nested-cmd-sub/compound-chain-gt2 -> run-probe.sh/AP-009; heredoc-with-expansion -> run-probe.sh/AP-008; quoted-brace -> read-range.sh/AP-007.

## Key Decisions

- **BSD sed -E for JSON extraction.** Plan's BRE pattern `\(\\.\|[^"\\]\)*` uses GNU-sed alternation syntax that BSD sed (macOS default) does not support in BRE. Switched to `sed -E` with ERE alternation `((\\.|[^"\\])*)` — same semantic, works on stock macOS. This is a plan deviation, noted here.
- **reject_lookup defined at top of script** per the plan's author note, not at the bottom of the sketch.
- **Fail-safe passthrough** on empty stdin, malformed JSON, missing classifier, or unknown classifier output. Never hard-rejects on hook-internal errors — honors the US-4 AS2 constraint that user prompts must never increase due to the hook itself.

## Patterns Established

- **Pure-Bash JSON single-field extractor**: `tr '\n' ' ' | sed -E -n 's/.../\1/p' | head -1` pipeline flattens multi-line JSON, then extracts a single named string field with escaped-quote handling. Viable on Bash 3.2 + BSD sed. Used for both tool_name and tool_input.command.
- **Em dash literal via printf 3-byte sequence**: `printf 'REJECT: %s \xe2\x80\x94 use scripts/util/%s...\n'` emits U+2014 exactly. Avoids encoding ambiguity from storing the literal UTF-8 character in the script.
- **Reject-table lives in hook, not classifier**: the classifier stays purely about *shape*; the hook owns the mapping from shape-class to (wrapper, AP-ID, remediation text). T01 classifier remains context-free and reusable.

## Verification Results

Manual smoke test (seven cases) passed:

| Case | Input | Exit | Stdout/Stderr |
|------|-------|------|---------------|
| 1 allow | `bash scripts/verify/run-suite.sh m021 P03` | 0 | empty |
| 2 rewrite sed-n-range | `sed -n '10,20p' file.md` | 0 | JSON w/ updatedInput.command = `bash scripts/util/read-range.sh file.md 10 20` |
| 3 reject nested-cmd-sub | `echo \$(date \$(hostname))` | 2 | stderr `REJECT: nested-cmd-sub — use scripts/util/run-probe.sh instead. See ANTIPATTERNS.md#AP-009.` |
| 4 non-Bash tool | `tool_name=Read` | 0 | empty |
| 5 empty stdin | (nothing) | 0 | empty |
| 6 malformed JSON | `not json` | 0 | empty |
| 7 reject quoted-brace | `echo "{a,b}"` | 2 | stderr `REJECT: quoted-brace — use scripts/util/read-range.sh instead. See ANTIPATTERNS.md#AP-007.` |

Em dash byte-dump confirms `e2 80 94` in reject stderr. `bash -n` parse check exits 0. Grep for forbidden Bash-4 constructs (`declare -A`, `mapfile`, `readarray`, `\${var,,}`, `\${var^^}`, `\${!prefix*}`, `<(`) returns zero matches.

Rewrite JSON validates against python3 json.tool with correct key nesting: hookSpecificOutput.hookEventName="PreToolUse", hookSpecificOutput.permissionDecision="allow", hookSpecificOutput.updatedInput.command=<rewritten>.

## Downstream Impact

T03 wires the hook into `.claude/settings.json` as the single PreToolUse Bash hook (AD-1a single-hook constraint). T04 builds the integration gate (`scripts/verify/m021-p03-hook-integration.sh`) that drives the hook with the full 10-entry matrix. T05 runs the replay corpus against the hook + linter stack.

## Deviations

- Plan's BRE sed pattern replaced with ERE (`sed -E`) for BSD-sed compatibility. Same semantic intent.
- JSON-unescape pipeline uses a sentinel (`__BS__`) to avoid double-unescaping \\ and other escapes. Plan's ordered sed pipeline is equivalent on GNU sed but fragile on BSD sed; the sentinel approach is portable.
