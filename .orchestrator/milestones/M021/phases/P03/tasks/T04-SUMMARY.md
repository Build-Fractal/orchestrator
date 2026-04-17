---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P03"
milestone: "M021"
provides:
  - "tests/hook/rewrite-cases.sh (6 synthetic stdin-JSON rewrite cases, one per matrix pattern: trailing-rc-echo, sed-n-range, cat-heredoc-exec, cd-and-bash, var-inline-bash, redirect-cmd-sub); tests/hook/reject-cases.sh (4 synthetic stdin-JSON reject cases: nested-cmd-sub, compound-chain-gt2, heredoc-with-expansion, quoted-brace — asserts exit 2 + exact UTF-8 em-dash diagnostic line)"
requires:
  - "from:T01 what:scripts/verify/lib/shape-classifier.sh (classification labels); from:T02 what:scripts/hooks/pre-bash-shape-guard.sh (hook under test)"
affects:
  - "P03/T05"
key_files:
  - "tests/hook/rewrite-cases.sh,tests/hook/reject-cases.sh"
key_decisions:
  - "AD-2,AD-19"
patterns_established:
  - "pipe-synthetic-stdin hook test harness; trailing __EXIT__=<n> marker line to propagate subshell exit code past command substitution; sed -E (ERE) extraction of updatedInput.command matching the hook's own emission regex; $'\xe2\x80\x94' literal UTF-8 em-dash in grep -F needle"
drill_down_paths:
  - ".orchestrator/milestones/M021/phases/P03/tasks/T04-PLAN.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-17T19:41:31Z"
---

Authored two Bash 3.2 test harness scripts that drive scripts/hooks/pre-bash-shape-guard.sh via stdin-piped synthetic JSON payloads, one per matrix entry from AD-2 (6 rewrites + 4 rejects).

Implementation notes / plan deviations:

1. **Exit-code propagation via trailing marker.** The plan scaffold's `HOOK_EXIT=$?` pattern inside drive_hook / drive_hook_stderr runs in a command-substitution subshell — the assignment never propagates to the parent assert_* function, so every reject case saw HOOK_EXIT=0 (the initial value) and failed with 'hook exited 0 (expected 2)'. Replaced with a `__EXIT__=<n>` sentinel line appended to the substitution's stdout; each assert_* parses this line via awk and then strips it before shape comparison. Same fix applied to rewrite harness for symmetry — the scaffold was passing there only because initial HOOK_EXIT=0 happens to match the expected rewrite exit code.

2. **Extractor regex BSD-portability.** The plan's extract_updated_command used BRE with `\( \| \)` alternation — BSD sed silently fails to match. Switched to `sed -E` (ERE) mirroring the hook's own emission regex in pre-bash-shape-guard.sh:80. Added `tr '\n' ' '` pre-flatten so the regex works even on multi-line hook output (hook currently emits single-line, but the flatten is defensive).

3. **Unescape ordering.** sed unescape passes run in order `\" \n \t \\\\` (backslash last, via a uniqueness-preserving sequence) to avoid double-unescaping. No case in the 6-entry rewrite matrix actually contains backslash round-trips, but the ordering preserves correctness for any future additions.

AP-ID mapping matches the hook's reject_lookup table verbatim: nested-cmd-sub→AP-009, compound-chain-gt2→AP-009, heredoc-with-expansion→AP-008, quoted-brace→AP-007. Wrapper mapping: run-probe.sh for the first three, read-range.sh for quoted-brace.

Verification: `bash tests/hook/rewrite-cases.sh` prints 6 PASS lines + final `PASS: rewrite-cases.sh`, exit 0. `bash tests/hook/reject-cases.sh` prints 4 PASS lines + final `PASS: reject-cases.sh`, exit 0. `bash -n` passes on both. Grep for declare -A, mapfile, readarray, ${var,,}, ${var^^}, ${!prefix*}, <( returns no matches.

Hermetic: both scripts read only their own stdin pipe; no file I/O other than sourcing the hook executable. No fixture files needed — all inputs and expected outputs are inline string literals. Ten cases total — exactly the closed AD-2 matrix, no speculative additions (constitution XIV).
