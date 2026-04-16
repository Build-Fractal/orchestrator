---
schema_version: "1.0"
type: attestation
milestone: "M016"
subject: "zero-prompts-dogfood"
prompt_count: 0
attested_at: "2026-04-16"
---

# Zero-Prompts Attestation — M016 Dogfood Evidence

M016 (Autonomous Hardening) was itself executed autonomously with zero approval
prompts across phases P01 through P03. This milestone is its own dogfood: the
anti-patterns it catalogs and the mitigations it applies were validated by the
fact that its own execution ran prompt-free.

## Execution Evidence

| Phase | Tasks | Duration | Verification | Prompts |
|-------|-------|----------|--------------|---------|
| P01   | 3     | 22m      | pass         | 0       |
| P02   | 2     | 14m      | pass         | 0       |
| P03   | 4     | 20m      | pass         | 0       |

## What Was Validated

- **P01**: `write-summary.sh` `--completed_at` made optional (eliminating `$(date ...)` command substitution), AP-004 antipattern catalog entry created, `auto.md` examples cleaned.
- **P02**: `run-suite.sh` wrapper created (eliminating chained `&&` bash invocations and awk pipes).
- **P03**: Anti-pattern linter created and applied to all agent-facing files, dispatch payload prohibited-patterns section added.

## How Prompt-Free Execution Was Achieved

1. All `$(...)` command substitutions removed from agent-facing code-block examples.
2. Brace expansions (`{a,b}`) replaced with explicit alternatives.
3. Compound bash chains replaced with wrapper scripts.
4. `.claude/settings.json` allow-list includes Unix tool wildcards (sed, awk, grep, etc.) so harness does not prompt for common operations.
