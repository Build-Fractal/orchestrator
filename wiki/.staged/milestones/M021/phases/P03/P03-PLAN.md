---
schema_version: "1.0"
phase: "P03"
milestone: "M021"
type: phase-plan
goal: "Ship the PreToolUse shape-guard hook that intercepts every Bash tool call, consults a shared shape-classifier library, deterministically rewrites six fixable shapes to wrapper invocations, and hard-rejects four unfixable shapes with a wrapper-pointing diagnostic — plus widen .claude/settings.json's allow-list for read-only shapes and surface the wrapper catalog in the dispatch payload's 'Allowed invocation shapes' section. The ten-pattern matrix is closed on M011/P05–P07 evidence (AD-2, constitution XIV). No regression on the 95% pass-through path."
demo_sentence: "A Bash tool call `sed -n '10,20p' file.md` fires the PreToolUse hook; stdout JSON returns `hookSpecificOutput.updatedInput.command = \"bash scripts/util/read-range.sh file.md 10 20\"` and no user prompt fires. A Bash tool call `bash a.sh > \"$(mktemp)\"` triggers reject pattern `redirect-cmd-sub`; the hook exits 2 with stderr line `REJECT: redirect-cmd-sub — use scripts/util/read-range.sh instead. See ANTIPATTERNS.md#AP-006.`. Running `bash scripts/verify/m021-p03-hook-integration.sh` reports PASS."
risk: "high"
depends_on: ["P01", "P02"]
---

## Must-Haves

<!-- Each truth is a behavioral statement + a single-script-file Check (AD-19).
     All Check: commands use single-invocation script-file shape.
     No inline compound bash, no plain subshells, no $(...) with pipes. -->

### Truths

- `scripts/verify/lib/shape-classifier.sh` is a sourceable library whose `classify_command <cmd-string>` function prints exactly one of `allow`, `rewrite:<result-command>`, or `reject:<pattern-class>` to stdout for every input. All ten matrix entries — six rewrites (trailing-rc-echo, sed-n-range, cat-heredoc-exec, cd-and-bash, var-inline-bash, redirect-cmd-sub) and four rejects (nested-cmd-sub, compound-chain-gt2, heredoc-with-expansion, quoted-brace) — resolve to their documented classifications.
  - Check: `bash scripts/verify/m021-p03-hook-integration.sh`
- `scripts/hooks/pre-bash-shape-guard.sh` is a PreToolUse hook executable that reads Claude Code's stdin JSON (`{"tool_name":"Bash","tool_input":{"command":"..."}}` and related fields), sources the classifier library, and emits the documented hook protocol: on `allow`, exit 0 with empty stdout; on `rewrite:<X>`, exit 0 with stdout JSON `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":{"command":"<X>"}}}`; on `reject:<class>`, exit 2 with stderr line `REJECT: <class> — use scripts/util/<wrapper>.sh instead. See ANTIPATTERNS.md#AP-00X.` exactly.
  - Check: `bash scripts/verify/m021-p03-hook-integration.sh`
- `.claude/settings.json` registers `scripts/hooks/pre-bash-shape-guard.sh` as a single `PreToolUse` hook for the `Bash` tool (single-hook constraint per AD-1a) and adds exactly these new allow-list entries: `Read(/var/folders/**)`, `Bash(bash /tmp/*.sh)`, `Bash(bash /var/folders/**/*.sh)`, `Bash(ls tmp/**)`, `Bash(cat tmp/**)`, `Bash(sed -n *)`, `Bash(head *)`, `Bash(tail *)`, `Bash(stat *)`. All M016-era allow entries and the full `deny:` list remain byte-identical (strict superset, no regression).
  - Check: `bash scripts/verify/m021-p03-hook-integration.sh`
- `tests/hook/rewrite-cases.sh` drives the hook with six synthetic stdin-JSON payloads (one per rewrite pattern), asserts exit 0, and asserts `updatedInput.command` equals the expected rewritten string verbatim. `tests/hook/reject-cases.sh` drives four synthetic stdin payloads (one per reject pattern), asserts exit 2, and asserts stderr contains the exact `REJECT: <class> — use scripts/util/<wrapper>.sh instead. See ANTIPATTERNS.md#AP-00X.` line — AP-ID values come from P02's entries (simple-expansion→AP-005, redirect-cmd-sub→AP-006, quoted-brace→AP-007, heredoc-expansion→AP-008, task-plan-compound→AP-009; nested-cmd-sub and compound-chain-gt2 both cite AP-009, heredoc-with-expansion cites AP-008, quoted-brace cites AP-007).
  - Check: `bash scripts/verify/m021-p03-hook-integration.sh`
- The hook passes through non-matching calls silently — a stdin payload with command `bash scripts/verify/run-suite.sh m021 P03` produces exit 0 with empty stdout (no `hookSpecificOutput`), allowing Claude Code to proceed to normal permission evaluation. The pass-through overhead is a single-line fall-through in the classifier (no subshell fork per call on the happy path).
  - Check: `bash scripts/verify/m021-p03-hook-integration.sh`
- The dispatch payload rendered via `bash scripts/dispatch/build-context.sh` contains a section named `### Allowed invocation shapes` listing the three P01 wrappers (`scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh`) with one-line usage examples each. Section is emitted by `scripts/dispatch/lib/section-handlers.sh`'s `handle_template "$@" constraints` and is adjacent to (not replacing) the existing `### Prohibited inline bash patterns` block.
  - Check: `bash scripts/verify/m021-p03-hook-integration.sh`
- All new shell files (`scripts/hooks/pre-bash-shape-guard.sh`, `scripts/verify/lib/shape-classifier.sh`, `tests/hook/rewrite-cases.sh`, `tests/hook/reject-cases.sh`, `scripts/verify/m021-p03-hook-integration.sh`) pass a Bash 3.2 compatibility scan — `bash -n` parses clean and no forbidden constructs (`declare -A`, `mapfile`, `readarray`, `${var,,}`, `${var^^}`, `${!prefix*}`, process substitution `<(…)`) appear.
  - Check: `bash scripts/verify/m021-p03-hook-integration.sh`

### Artifacts

- `scripts/verify/lib/shape-classifier.sh` (create, min 160 lines, contains `classify_command`, `allow`, `rewrite:`, `reject:`, `trailing-rc-echo`, `sed-n-range`, `cat-heredoc-exec`, `cd-and-bash`, `var-inline-bash`, `redirect-cmd-sub`, `nested-cmd-sub`, `compound-chain-gt2`, `heredoc-with-expansion`, `quoted-brace`)
- `scripts/hooks/pre-bash-shape-guard.sh` (create, min 90 lines, contains `hookSpecificOutput`, `updatedInput`, `permissionDecision`, `PreToolUse`, `REJECT:`, `ANTIPATTERNS.md#AP-`, `classify_command`)
- `.claude/settings.json` (modify, must contain `"PreToolUse"`, `"scripts/hooks/pre-bash-shape-guard.sh"`, `"Bash(bash /tmp/*.sh)"`, `"Bash(bash /var/folders/**/*.sh)"`, `"Read(/var/folders/**)"`, `"Bash(sed -n *)"`, `"Bash(head *)"`, `"Bash(tail *)"`, `"Bash(stat *)"`, `"Bash(ls tmp/**)"`, `"Bash(cat tmp/**)"`)
- `tests/hook/rewrite-cases.sh` (create, min 120 lines, contains six case labels matching the six rewrite pattern-classes and six expected `updatedInput.command` strings)
- `tests/hook/reject-cases.sh` (create, min 80 lines, contains four case labels and the literal `REJECT: ` diagnostic strings for each of the four reject pattern-classes)
- `scripts/verify/m021-p03-hook-integration.sh` (create, min 100 lines, contains `PASS:`, `classify_command`, `pre-bash-shape-guard.sh`, `rewrite-cases.sh`, `reject-cases.sh`, `PreToolUse`, `Allowed invocation shapes`, `bash32`)
- `scripts/dispatch/lib/section-handlers.sh` (modify — extend `handle_template` "constraints" branch to append `### Allowed invocation shapes` block listing the three P01 wrappers; min 640 lines total after edit, contains `Allowed invocation shapes`, `scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh`)

### Key Links

- `scripts/hooks/pre-bash-shape-guard.sh` → `scripts/verify/lib/shape-classifier.sh` (hook sources the library via absolute repo-relative path)
- `scripts/verify/m021-p03-hook-integration.sh` → `scripts/hooks/pre-bash-shape-guard.sh`, `scripts/verify/lib/shape-classifier.sh`, `tests/hook/rewrite-cases.sh`, `tests/hook/reject-cases.sh`, `.claude/settings.json`, `scripts/dispatch/lib/section-handlers.sh` (integration gate exercises each)
- `tests/hook/rewrite-cases.sh` → `scripts/hooks/pre-bash-shape-guard.sh` (drives via stdin JSON)
- `tests/hook/reject-cases.sh` → `scripts/hooks/pre-bash-shape-guard.sh` (drives via stdin JSON)
- `.claude/settings.json` → `scripts/hooks/pre-bash-shape-guard.sh` (PreToolUse registration uses relative path `scripts/hooks/pre-bash-shape-guard.sh`)
- `scripts/verify/lib/shape-classifier.sh` → `scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh` (rewrite results name these paths verbatim)
- `scripts/verify/lib/shape-classifier.sh` → `ANTIPATTERNS.md` (reject pattern-classes map to AP-005..AP-009 anchors cited in diagnostic text)
- `scripts/dispatch/lib/section-handlers.sh` → `scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh` (dispatch payload's "Allowed invocation shapes" names these paths)

## Tasks

### T01: Shape-classifier library (`scripts/verify/lib/shape-classifier.sh`)

See `tasks/T01-PLAN.md`.

### T02: PreToolUse hook (`scripts/hooks/pre-bash-shape-guard.sh`)

See `tasks/T02-PLAN.md`.

### T03: `.claude/settings.json` update + dispatch-payload "Allowed invocation shapes" section

See `tasks/T03-PLAN.md`.

### T04: Hook test harness — `tests/hook/rewrite-cases.sh` + `tests/hook/reject-cases.sh`

See `tasks/T04-PLAN.md`.

### T05: Phase integration gate (`scripts/verify/m021-p03-hook-integration.sh`)

See `tasks/T05-PLAN.md`.

## Task Dependencies

```
T01 → T02 → T03 → T04 → T05
```

T01 ships the pure classifier library, isolated and unit-testable via direct function invocation. T02 wires the hook to Claude Code's stdin/stdout protocol and depends on the classifier's stable API. T03 registers the hook in `.claude/settings.json` and adds the dispatch-payload section — depends on T02 because the settings entry references the hook path authored there. T04 exercises the hook end-to-end via synthetic stdin JSON and depends on T02 (hook binary) and indirectly on T01 (classifier semantics). T05 is the phase integration gate that asserts cohesion across T01–T04: classifier lib API, hook protocol, settings registration, dispatch-payload section, and test-harness results.

Linear serial order — T02 cannot be written without the classifier's API surface frozen, T03's settings entry cannot pass CI until the hook file exists at the declared path, T04's harness needs the hook binary to invoke, and T05 consumes all four upstream artifacts.

## Files Likely Touched

- `scripts/verify/lib/shape-classifier.sh` (create)
- `scripts/hooks/pre-bash-shape-guard.sh` (create)
- `.claude/settings.json` (modify — append allow entries + add `hooks.PreToolUse` section)
- `scripts/dispatch/lib/section-handlers.sh` (modify — extend `handle_template` constraints branch)
- `tests/hook/rewrite-cases.sh` (create — new `tests/hook/` subdirectory)
- `tests/hook/reject-cases.sh` (create)
- `scripts/verify/m021-p03-hook-integration.sh` (create)

## Boundary Assertion

- **Produces exactly**: the classifier library, the hook executable, the two test harness scripts, the phase integration gate, plus (modifications-only) the `.claude/settings.json` hook registration + allow-list widening and the `scripts/dispatch/lib/section-handlers.sh` dispatch-payload section addition. Nothing else.
- **Does not touch**: `scripts/util/*.sh` (P01 territory — referenced by path only from classifier rewrite targets and dispatch section), `scripts/verify/anti-pattern-lint.sh` (P02 territory), `ANTIPATTERNS.md` (P02 territory — read-only anchor citations), `tests/fixtures/m021-prompt-corpus.txt` and `scripts/verify/replay-prompt-corpus.sh` (P04 territory).
- **Consumes**: the three wrappers from P01 by path (classifier rewrite results name them verbatim), the five AP anchors from P02 (AP-005..AP-009) by ID in reject diagnostics. No runtime dependency on P01/P02 code beyond path-string references.
- **Scope of the matrix**: exactly ten entries per AD-2, grounded in M011/P05–P07 screenshot evidence. No speculative additions (constitution XIV). Adding an eleventh pattern requires a new phase or milestone justified by new evidence.
- **Pass-through path**: 95% of Bash tool calls do not match any matrix entry and must pass through the hook with exit 0 + empty stdout, with no perceivable latency. The classifier's happy path is a linear fall-through with no subshell forks per call.
- **Single-hook constraint**: `.claude/settings.json` declares exactly one `PreToolUse` hook for the `Bash` tool. Adding a second hook causes nondeterministic last-writer-wins on `updatedInput` (AD-1a).
