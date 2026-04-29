# Antipattern Register

Append-only register of observed antipatterns from real orchestrator development.
Entries are permanent — they do not decay or expire (see constitution, AD-11).
Each entry references a real incident as evidence.

When adding a new entry: use the next sequential `AP-NNN` ID, reference the
milestone where the antipattern was observed, cite the constitution principle
it violates, and include specific file paths as evidence.

## AP-001: Platform-Specific Bash Syntax in Portable Scripts

**Observed In**: M002, M003 (audit)
**Principle Violated**: IX (Reproducibility Over Convenience)
**Related Constitution Constraint**: Bash 3.2 compatibility (NFR-200)

**Description**: Process substitution used as a redirection target (`done < <(command)`) in two files. This syntax is valid in Bash 4+ but fails silently or with cryptic errors on macOS's default Bash 3.2. The scripts passed all tests on the development machine (which had Bash 5 via Homebrew) but would fail on a clean macOS installation.

**Evidence**:
- `scripts/dispatch/build-context.sh:689` — `done < <(find ...)`
- `scripts/verify/check-scope.sh:102` — `done < <(git diff ...)`
- Discovered during M002+M003 audit (see `.orchestrator/handoff-m002-m003-audit-fixes.md`, CRITICAL 1)

**Remedy**: Use temp-file pattern for feeding command output into while loops:
```
_tmp="$(mktemp)"
command > "$_tmp"
while IFS= read -r line; do ...; done < "$_tmp"
rm -f "$_tmp"
```
Or use a pipe: `command | while IFS= read -r line; do ...; done` (noting that the loop body runs in a subshell and cannot set parent variables).

## AP-002: Platform-Divergent sed In-Place Editing

**Observed In**: M001 (audit)
**Principle Violated**: IX (Reproducibility Over Convenience)
**Related Constitution Constraint**: Bash 3.2 compatibility (NFR-200)

**Description**: Five locations used `sed -i.bak` which creates `.bak` backup files on macOS (BSD sed requires an argument to `-i`). GNU sed treats `.bak` as the backup suffix. The project already had a portable `sed_i` helper in 3 other scripts, but the pattern was not consistently applied. Result: junk `.bak` files accumulating in the working directory on macOS.

**Evidence**:
- `scripts/lifecycle/sync-roadmap.sh:82,91` — `sed -i.bak` calls
- `scripts/lifecycle/lock-manager.sh:189,193,196` — `sed -i.bak` calls
- 3 other scripts already used `sed_i` helper correctly
- Discovered during M002+M003 audit (see `.orchestrator/handoff-m002-m003-audit-fixes.md`, CRITICAL 2)

**Remedy**: Use a portable `sed_i` helper function in every script that needs in-place editing:
```
sed_i() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}
```
Better: extract `sed_i` into a shared utility (`scripts/util/sed-i.sh`) and source it — same pattern as `json_field` extraction (see Knowledge Base, Audit Remediation Patterns).

## AP-003: Missing Double-Sourcing Guards on Library Files

**Observed In**: M002 (audit)
**Principle Violated**: VIII (No Dead Infrastructure) — sourcing a library twice wastes context and can cause re-initialization bugs
**Related Constitution Constraint**: NFR-203 (all libraries with double-sourcing guards)

**Description**: Seven library files created during M002 P01 lacked idempotent sourcing guards. When a script sources library A which also sources library B, and the script independently sources library B, the library B code runs twice. For stateless utilities this is merely wasteful; for libraries that initialize state (counters, temp files), it causes subtle bugs.

**Evidence**:
- `scripts/knowledge/lib/staleness.sh` — no guard
- `scripts/knowledge/lib/index-utils.sh` — no guard
- `scripts/knowledge/lib/graph-utils.sh` — no guard
- `scripts/knowledge/lib/format-utils.sh` — no guard
- `scripts/knowledge/lib/manifest-utils.sh` — no guard
- `scripts/knowledge/lib/telemetry-utils.sh` — no guard
- `scripts/knowledge/lib/routing-utils.sh` — no guard
- Discovered during M002+M003 audit (see `.orchestrator/handoff-m002-m003-audit-fixes.md`, MEDIUM)

**Remedy**: Every sourced library file must include this guard at the very top (after the shebang, before any other code):
```
[ -n "${_LIBNAME_SOURCED:-}" ] && return 0
_LIBNAME_SOURCED=1
```
Where `LIBNAME` is a unique identifier derived from the filename (e.g., `_STALENESS_SOURCED` for `staleness.sh`).

## AP-004: Claude Code Safety-Prompt Triggers in Agent-Facing Content

**Observed In**: M008, M015 (autonomous execution runs)
**Principle Violated**: VII (Knowledge Compounds) — each occurrence forces manual intervention, preventing autonomous completion
**Related Constitution Constraint**: AD-19 (single-script-file shape for harness compatibility)

**Description**: Claude Code's harness includes a safety-heuristic layer that sits above the allow-list and cannot be configured away. It fires on command *shape* detected in Bash tool invocations, regardless of `"defaultMode": "acceptEdits"` or explicit `Bash(...)` allow entries. Three pattern classes trigger it:

1. **Command substitution** — `$(...)` or backtick `` `...` `` anywhere in the Bash tool call string. Most frequent offender: `--completed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)` passed to `write-summary.sh` during task-summary writes. Observed on M015 P02 T01, P04 T01, P04 T05, and multiple earlier milestones.

2. **Brace expansion** — `{...}` in the Bash tool call string. Most frequent offender: `awk '{print $1}'` used to tally verify-suite PASS/FAIL counts. Also triggered by `{a,b,c}` glob expansion. Observed on M015 P02 verification.

3. **Compound bash chains** — `&&`, `||`, `;`, or `|` joining multiple commands in a single Bash tool call. Most frequent offender: chained verify-script invocations like `bash scripts/verify/foo.sh && bash scripts/verify/bar.sh 2>&1 | grep -E '^(PASS|FAIL)' | awk '{print $1}' | sort | uniq -c`. Observed on M015 P02, M008 P03, M003 P08.

These patterns are *idiomatic bash* and appear naturally in scripts. The critical distinction is: they are safe **inside** scripts (Claude Code does not inspect script internals), but unsafe **in the Bash tool call string** (the agent's direct invocation). Agent-facing content — `commands/*.md`, `templates/*.md`, dispatch payloads — must not demonstrate these patterns because subagents reproduce what they see.

**Evidence**:
- M015 P02 T01: "Contains command_substitution" prompt on `--completed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)`
- M015 P02 verification: "Brace expansion" prompt on `awk '{print $1}'` in chained verify pipeline
- M015 P04 T05: "Brace expansion" prompt on write-summary call body containing `{...}`
- M008 P03: "This command requires approval" prompt on `/usr/bin/sed -i '' 's|...|g'` (compound pattern)
- M015 P02 verification: "Do you want to proceed?" on 6-script `&&` chain with pipe to `awk | sort | uniq`

**Remedy**:

| Anti-pattern | Wrapper alternative |
|---|---|
| `--completed_at=$(date -u ...)` | Omit `--completed_at` (write-summary.sh defaults to now) or pass `--completed_at=now` |
| `awk '{print $1}' \| sort \| uniq -c` | `bash scripts/verify/run-suite.sh <milestone> <phase>` (auto-tallies) |
| `bash a.sh && bash b.sh && bash c.sh` | `bash scripts/verify/run-suite.sh <milestone> <phase>` or a single wrapper script |
| `$(bash scripts/state/derive-phase.sh ...)` | Write output to a file via `--output-file`, then read the file |
| Inline `sed -i '' 's|...|g' file` | Extract into a helper script under `scripts/` and invoke as `bash scripts/util/fix-foo.sh` |

**Scope of enforcement**: Agent-facing content only (`commands/*.md`, `templates/*.md`, dispatch payload builders). Script internals (`scripts/*.sh`) are exempt — the harness does not inspect them.

## AP-005: Simple-Expansion `$VAR` / `$?` in Inline Bash Tool Calls

**Observed In**: M011 (P05–P07 autonomous-run screenshots, 2026-04-16/2026-04-17)
**Principle Violated**: VII (Knowledge Compounds) — each occurrence forces manual intervention, preventing autonomous completion
**Related Constitution Constraint**: AD-19 (single-script-file shape for harness compatibility)

**Description**: Claude Code's safety-heuristic layer flags any `$VAR` or `$?` appearing inside a Bash tool-call string with the prompt "Contains simple_expansion." The most common offenders are (a) the `VAR=val cmd ...` inline-assignment prefix and (b) the trailing `; echo "RC=$?"` tail agents append to capture exit codes. Both shapes are idiomatic bash but trigger approval prompts in autonomous mode. The pattern fires even when the underlying command is already allow-listed — the heuristic sits *above* the allow list and cannot be configured away.

**Evidence**:
- M011/P07 autonomous dogfood run: `ORCH_REPO=/tmp/m011-repo bash /tmp/m011-p07-dogfood.sh` fired "Contains simple_expansion." prompt.
- M011/P05 verification step: `bash scripts/verify/run-suite.sh m011 P05 ; echo "RC=$?"` fired the same prompt on the trailing `RC=$?`.
- M011/P06 probe: `LOG=/tmp/a.log bash scripts/foo.sh > "$LOG"` fired "Contains simple_expansion." on the leading `LOG=...` assignment.

**Remedy**: Replace inline env-assignment prefixes with `bash scripts/util/with-env.sh KEY=VALUE [KEY=VALUE ...] -- command [args ...]`. The wrapper parses `KEY=VALUE` as arguments (not shell expansions) and execs the child with them exported. For trailing RC capture, redirect RC to a file from inside the target script rather than appending `; echo "RC=$?"` at the tool-call level. See P01 wrapper catalog at `scripts/util/README.md`.

**Cross-Refs**:
- Enforcement layer: `scripts/hooks/pre-bash-shape-guard.sh` (P03 PreToolUse hook — this AP ID appears in the hook's reject-diagnostic text via `ANTIPATTERNS.md#AP-005` pointer).
- Regression corpus: `tests/fixtures/m021-prompt-corpus.txt` (P04 replay fixture — one or more verbatim screenshot entries exercise this pattern-class via `EXPECTED_OUTCOME: rewrite:trailing-rc-echo` or `rewrite:var-inline-bash`).
- Classifier implementation: `scripts/verify/lib/shape-classifier.sh` (P03 shared shape-classifier library — the `classify_command` function emits the pattern-class label this AP ID documents).

## AP-006: Command Substitution `$(...)` in Redirect Targets

**Observed In**: M011 (P05–P07 autonomous-run screenshots, 2026-04-16/2026-04-17)
**Principle Violated**: VII (Knowledge Compounds)
**Related Constitution Constraint**: AD-19

**Description**: Bash tool-call strings of the form `bash scripts/foo.sh > "$(scripts/util/logpath.sh)" 2>&1` trigger the safety prompt "Redirect target contains $(cmd) output — path is runtime-determined." The heuristic treats any runtime-resolved path as a write to an unknown location, even when the inner command is pure (e.g., a path-emitter). This is distinct from AP-004's general `$(...)` rule because it fires specifically on the redirect-target position and independently of allow-list entries.

**Evidence**:
- M011/P06 verification: `bash scripts/foo.sh > "$(bash scripts/util/logpath.sh)"` fired "Redirect target contains $(cmd) output" — path is runtime-determined.
- M011/P07 dogfood closeout: `scripts/verify/run-suite.sh m011 P07 > "$(mktemp)"` fired the same prompt.

**Remedy**: Compute the path in a prior step and bind it to a fixed value known to the allow-list. Canonical pattern: the child script writes its output to a deterministic path (`.orchestrator/tmp/<run-id>.log`) and the caller reads it back via `bash scripts/util/read-range.sh` or direct `cat`. Never construct the redirect target via `$(...)`. See P01 wrapper catalog.

**Cross-Refs**:
- Enforcement layer: `scripts/hooks/pre-bash-shape-guard.sh` (P03 PreToolUse hook — this AP ID appears in the hook's reject-diagnostic text via `ANTIPATTERNS.md#AP-006` pointer).
- Regression corpus: `tests/fixtures/m021-prompt-corpus.txt` (P04 replay fixture — one or more verbatim screenshot entries exercise this pattern-class via `EXPECTED_OUTCOME: rewrite:redirect-cmd-sub`).
- Classifier implementation: `scripts/verify/lib/shape-classifier.sh` (P03 shared shape-classifier library — the `classify_command` function emits the pattern-class label this AP ID documents).

## AP-007: Braces `{...}` Inside Double-Quoted Strings

**Observed In**: M011 (P05–P07 autonomous-run screenshots, 2026-04-16/2026-04-17)
**Principle Violated**: VII (Knowledge Compounds)
**Related Constitution Constraint**: AD-19

**Description**: Claude Code's safety heuristic flags `{...}` anywhere inside a double-quoted string with the prompt "Contains brace with quote character (expansion obfuscation)." The canonical offender is an awk body embedded in a quoted argument: `awk "BEGIN{print 42}"`. The heuristic does not distinguish between brace-expansion `{a,b}` (AP-004), parameter-expansion `${VAR}` (safe), and literal braces inside a quoted awk/shell body (the AP-007 case). All three paths converge on the same "brace with quote" trigger in the parser.

**Evidence**:
- M011/P05 verification sweep: `awk 'BEGIN{t=0} /PASS/{t++} END{print t}' $LOG` fired "Contains brace with quote character."
- M011/P07 dogfood summary: `jq -r '.results[] | "{status:\\(.status)}"' results.json` fired the same prompt.

**Remedy**: Extract awk/shell/jq bodies with embedded braces into standalone scripts under `scripts/util/` or `scripts/verify/` and invoke the script by path. For line-range reads that would otherwise use `sed -n '10,20p'` (which trips the related quoted-brace parser path when the `p` flag appears in quotes), use `bash scripts/util/read-range.sh file.md 10 20`. See P01 wrapper catalog.

**Cross-Refs**:
- Enforcement layer: `scripts/hooks/pre-bash-shape-guard.sh` (P03 PreToolUse hook — this AP ID appears in the hook's reject-diagnostic text via `ANTIPATTERNS.md#AP-007` pointer).
- Regression corpus: `tests/fixtures/m021-prompt-corpus.txt` (P04 replay fixture — one or more verbatim screenshot entries exercise this pattern-class via `EXPECTED_OUTCOME: reject:quoted-brace` or `rewrite:sed-n-range`).
- Classifier implementation: `scripts/verify/lib/shape-classifier.sh` (P03 shared shape-classifier library — the `classify_command` function emits the pattern-class label this AP ID documents).

## AP-008: Heredoc with `$VAR` / `$(...)` Expansion in Tool-Call-Level Bash

**Observed In**: M011 (P05–P07 autonomous-run screenshots, 2026-04-16/2026-04-17)
**Principle Violated**: VII (Knowledge Compounds)
**Related Constitution Constraint**: AD-19

**Description**: Heredocs containing `$VAR` or `$(...)` expansions in a Bash tool-call string cause Claude Code's parser to emit "Unhandled node type: string" — the parser abandons classification and falls back to asking the user. This fires *before* the allow-list is consulted, so no amount of `Bash(...)` permission widening can suppress it. A quoted heredoc opener (`<<"EOF"` or `<<'EOF'`) with no expansion inside the body is safe; only unquoted heredocs that contain expansions trip the heuristic.

**Evidence**:
- M011/P05 probe staging: `cat > /tmp/probe.sh <<EOF ... $ORCH_REPO ... EOF` fired "Unhandled node type: string."
- M011/P07 dogfood init: `cat > /tmp/m011-p07-init.sh <<EOF ... \$(date) ... EOF` fired the same parser-fallthrough prompt.

**Remedy**: Stage the probe body to a file via a prior Write tool call (which Claude Code handles natively without the parser fallthrough), then invoke via `bash scripts/util/run-probe.sh /tmp/<probe>.sh`. The wrapper's approved-root prefix allow-list covers `/tmp`, `/private/tmp`, `/var/folders`, `/private/var/folders`, and the project `tmp/` directory. See P01 wrapper catalog.

**Cross-Refs**:
- Enforcement layer: `scripts/hooks/pre-bash-shape-guard.sh` (P03 PreToolUse hook — this AP ID appears in the hook's reject-diagnostic text via `ANTIPATTERNS.md#AP-008` pointer).
- Regression corpus: `tests/fixtures/m021-prompt-corpus.txt` (P04 replay fixture — one or more verbatim screenshot entries exercise this pattern-class via `EXPECTED_OUTCOME: reject:heredoc-with-expansion` or `rewrite:cat-heredoc-exec`).
- Classifier implementation: `scripts/verify/lib/shape-classifier.sh` (P03 shared shape-classifier library — the `classify_command` function emits the pattern-class label this AP ID documents).

## AP-009: Task-PAYLOAD Bash Fences Re-Introducing Compound Chains

**Observed In**: M011 (P05–P07 autonomous-run screenshots, 2026-04-16/2026-04-17)
**Principle Violated**: VII (Knowledge Compounds); XIV (No Speculative Complexity)
**Related Constitution Constraint**: AD-19; M016 dispatch-payload prohibited-patterns section

**Description**: M016's anti-pattern linter scans `commands/*.md` and `templates/*.md` but not `.orchestrator/milestones/**/tasks/*-PAYLOAD.md` — the files the dispatcher constructs as per-task payloads for subagents. Task plans re-introduce `for … ; do … ; done`, `if … ; then … ; fi`, `cd X && Y`, and bare `a; b` semicolon chains inside bash fences. Subagents reproduce what they see: when the dispatch payload contains a `for` loop example, the subagent emits a `for` loop, which trips the compound-chain heuristic and halts the autonomous run.

**Evidence**:
- M011/P06 task T02 payload: inline `for f in specs/*.md ; do bash scripts/foo.sh "$f" ; done` fired the compound-chain prompt when the subagent reproduced it.
- M011/P05 task T01 payload: `cd .orchestrator && bash scripts/bar.sh` fired the prompt via the `cd && bash` chain.
- M011/P07 dogfood attempt: `bash a.sh; bash b.sh; bash c.sh` inside a payload fence produced three sequential prompts.

**Remedy**: Extract compound logic into a single script file and invoke via a single `bash scripts/<name>.sh` call. For verify chains use `bash scripts/verify/run-suite.sh <milestone> <phase>` (which auto-tallies). For ad-hoc snippets use `bash scripts/util/run-probe.sh <staged-path>`. The M021 linter v2 (`scripts/verify/anti-pattern-lint.sh`) enforces this rule mechanically on `.orchestrator/milestones/**/tasks/*-PAYLOAD.md` going forward. See P01 wrapper catalog.

**Cross-Refs**:
- Enforcement layer: `scripts/hooks/pre-bash-shape-guard.sh` (P03 PreToolUse hook — this AP ID appears in the hook's reject-diagnostic text via `ANTIPATTERNS.md#AP-009` pointer).
- Regression corpus: `tests/fixtures/m021-prompt-corpus.txt` (P04 replay fixture — one or more verbatim screenshot entries exercise this pattern-class via `EXPECTED_OUTCOME: reject:compound-chain-gt2` or `reject:nested-cmd-sub`).
- Classifier implementation: `scripts/verify/lib/shape-classifier.sh` (P03 shared shape-classifier library — the `classify_command` function emits the pattern-class label this AP ID documents).

## AP-010: Backtick Inside grep / sed / awk Regex Argument

**Observed In**: M028 (Finding B #1, Screenshot 4, 2026-04-26)
**Principle Violated**: II (Evidence Before Claims) — agent invents pattern shapes that look like command substitution to the harness parser
**Related Constitution Constraint**: AD-19 single-script-file shape; M028 FR-8

**Description**: A literal backtick byte (`` ` ``) inside the regex argument to `grep`, `sed`, or `awk` reads as command-substitution attempt by Claude Code's pre-shape parser, which then prompts the operator before the orchestrator's PreToolUse hook sees the call. The operator's intent is a literal backtick search; the parser cannot distinguish that from `` `cmd` `` command substitution because the regex argument shape is opaque to it. Observed verbatim in `grep '^- \`bash scripts/util/' commands/dispatch.md` (Screenshot 4) — search for markdown bullet lines that begin with a backtick-delimited bash invocation.

**Evidence**:
- `commands/dispatch.md` is the search target in the source screenshot; see `.orchestrator/milestones/M028/phases/P01/classifier-audit.md` SE-02 for the verbatim command.
- Corpus fixture: `tests/fixtures/m021-prompt-corpus.txt` ID 21 (lands via M028/P03/T04).
- Original spec narration: `specs/031-autonomous-hardening-v3/spec.md` FR-8.

**Remedy**: Two options:
1. Escape the backtick within the regex: `grep '^- \\\`bash scripts/util/' commands/dispatch.md`.
2. Switch to `grep -F` (fixed string, no regex interpretation): `grep -F '^- \`bash scripts/util/' commands/dispatch.md`.
For the orchestrator's investigation patterns, prefer `scripts/util/grep-files.sh <pattern> <file...>` (M028/P04 deliverable) which handles per-file separation and avoids regex-edge cases.

**Cross-Refs**:
- Enforcement layer: `scripts/hooks/pre-bash-shape-guard.sh` (`reject_lookup` case arm `cmd-sub-in-pattern` → `grep-files.sh AP-010`).
- Regression corpus: `tests/fixtures/m021-prompt-corpus.txt` (entry ID 21 with `EXPECTED_OUTCOME: reject:cmd-sub-in-pattern`).
- Classifier implementation: `scripts/verify/lib/shape-classifier.sh` (`_sc_has_cmd_sub_in_pattern` private detector).

## AP-011: Newline + `#` Inside a Quoted CLI Argument

**Observed In**: M028 (Finding B #2, Screenshot 3, 2026-04-25)
**Principle Violated**: II (Evidence Before Claims)
**Related Constitution Constraint**: AD-19 single-script-file shape; M028 FR-9

**Description**: A literal newline byte followed by `#` inside a double-quoted CLI argument trips Claude Code's path-validation security heuristic — the parser scans quoted arg bytes and treats a `\n#` sequence as a possible command-injection vector regardless of the actual argument's intent. Observed verbatim in `bash scripts/state/auto-state.sh set --last-action "T01 done\n# trailing comment"` (Screenshot 3): the operator's intent is to set a state field whose value contains a comment annotation; the parser cannot distinguish that from a multi-statement injection.

**Evidence**:
- Source command: see `.orchestrator/milestones/M028/phases/P01/classifier-audit.md` SE-03.
- Corpus fixture: `tests/fixtures/m021-prompt-corpus.txt` ID 22 (lands via M028/P03/T04).
- Original spec narration: `specs/031-autonomous-hardening-v3/spec.md` FR-9.

**Remedy**: Use single-line quoted args; if the value genuinely needs a comment annotation, use a separate setter call:

```
bash scripts/state/auto-state.sh set --last-action "T01 done"
bash scripts/state/auto-state.sh annotate --comment "trailing comment"
```

No orchestrator-side wrapper exists for this shape; the AP-011 ANTIPATTERNS.md entry is the operator-facing remediation pointer. The hook's reject_lookup names `read-range.sh` as a placeholder per the established diagnostic format `use scripts/util/<wrapper> instead`, but the actual fix is the operator's command shape, not invoking that wrapper.

**Cross-Refs**:
- Enforcement layer: `scripts/hooks/pre-bash-shape-guard.sh` (`reject_lookup` case arm `quoted-arg-newline-hash` → `read-range.sh AP-011`).
- Regression corpus: `tests/fixtures/m021-prompt-corpus.txt` (entry ID 22 with `EXPECTED_OUTCOME: reject:quoted-arg-newline-hash`).
- Classifier implementation: `scripts/verify/lib/shape-classifier.sh` (`_sc_has_quoted_arg_newline_hash` private detector).

## AP-012: Multi-Line Quoted Body to `node -e` / `python -c` / Similar `-e`/`-c` Shapes

**Observed In**: M028 (Finding B #3, Screenshot 5, 2026-04-26)
**Principle Violated**: II (Evidence Before Claims)
**Related Constitution Constraint**: AD-19 single-script-file shape; M028 FR-10

**Description**: A multi-line body inside `node -e "..."` (or `python -c`, `ruby -e`, `perl -e`, `bash -c`, `sh -c` with multi-line) hits Claude Code's `ansi_c_string` parser fallthrough — the parser sees an unterminated quoted body across newlines and prompts. The operator's intent is to evaluate a short multi-statement script; the right shape is to author the script as a file and invoke it. Observed verbatim in `node -e "const x = 1;\nconsole.log(x);\n"` (Screenshot 5).

**Evidence**:
- Source command: see `.orchestrator/milestones/M028/phases/P01/classifier-audit.md` SE-04.
- Corpus fixture: `tests/fixtures/m021-prompt-corpus.txt` ID 23 (lands via M028/P03/T04).
- Original spec narration: `specs/031-autonomous-hardening-v3/spec.md` FR-10.

**Remedy**: Use `scripts/util/node-eval.sh <script-path>` (M028/P04 deliverable) which takes a script path as a positional arg and runs `node` against it. For a one-liner, fold the body to a single line. For multi-line, write a `.js`/`.py` file and invoke via the language interpreter.

**Cross-Refs**:
- Enforcement layer: `scripts/hooks/pre-bash-shape-guard.sh` (`reject_lookup` case arm `multiline-quoted-script` → `node-eval.sh AP-012`).
- Regression corpus: `tests/fixtures/m021-prompt-corpus.txt` (entry ID 23 with `EXPECTED_OUTCOME: reject:multiline-quoted-script`).
- Classifier implementation: `scripts/verify/lib/shape-classifier.sh` (`_sc_has_multiline_quoted_script` private detector).

## AP-013: Raw `{N,M,...}` Brace Expansion Outside Quotes

**Observed In**: M028 (Finding B #4, Screenshot 6, 2026-04-26)
**Principle Violated**: II (Evidence Before Claims)
**Related Constitution Constraint**: AD-19; AP-007 captures the **quoted** form, AP-013 captures the **unquoted** form

**Description**: Raw `{N,M,...}` brace expansion outside quotes triggers brace-expansion heuristics that AP-007 only catches inside double-quoted strings. The unquoted form is the more common shape (operators rarely quote glob patterns), and the parser flags it as a possible obfuscation pattern even when the brace contents are simple comma-separated tokens. Observed verbatim in `ls .orchestrator/milestones/M0{2,3,4,5}/M*-SUMMARY.md` (Screenshot 6) — the operator's intent is to enumerate four specific milestone IDs; the parser sees raw brace expansion outside quotes and prompts.

**Evidence**:
- Source command: see `.orchestrator/milestones/M028/phases/P01/classifier-audit.md` SE-05.
- Corpus fixture: `tests/fixtures/m021-prompt-corpus.txt` ID 24 (lands via M028/P03/T04).
- Original spec narration: `specs/031-autonomous-hardening-v3/spec.md` FR-11.
- Sibling entry: AP-007 (Braces `{...}` Inside Double-Quoted Strings) — the quoted-brace case the M021 classifier already catches.

**Remedy**: Two options:
1. Enumerate the paths explicitly: `ls .orchestrator/milestones/M002/M*-SUMMARY.md .orchestrator/milestones/M003/M*-SUMMARY.md .orchestrator/milestones/M004/M*-SUMMARY.md .orchestrator/milestones/M005/M*-SUMMARY.md`.
2. Use `scripts/util/peek-files.sh <pattern>` (M028/P04 deliverable) which accepts a glob and handles per-file separation without brace-expansion edge cases.

**Cross-Refs**:
- Enforcement layer: `scripts/hooks/pre-bash-shape-guard.sh` (`reject_lookup` case arm `unquoted-brace-glob` → `peek-files.sh AP-013`).
- Regression corpus: `tests/fixtures/m021-prompt-corpus.txt` (entry ID 24 with `EXPECTED_OUTCOME: reject:unquoted-brace-glob`).
- Classifier implementation: `scripts/verify/lib/shape-classifier.sh` (`_sc_has_unquoted_brace_glob` private detector).
- Sibling: AP-007 (quoted-brace case).

## AP-014: Compound Chain Hidden Inside `xargs … sh -c '<body>'`

**Observed In**: M028 (Finding G, 2026-04-28 22:25 operator screenshot — orchestrator's own repo, not a downstream-portability event)
**Principle Violated**: II (Evidence Before Claims); IX (No Speculative Complexity)
**Related Constitution Constraint**: AD-19; M028 FR-12; M028 CON-5 (one-level-deep body-descent)

**Description**: A `find … | head … | xargs -I{} sh -c '<body>'` shape can hide a compound `;`/`&&`/`||`/`|` chain inside the quoted `<body>` argument to `sh -c`. The M021 classifier counts top-level connectors only and treats `xargs` as a sink, producing a stage count ≤ 2 that AP-009 (`compound-chain-gt2`) refuses to reject if the top-level pipe count alone is at threshold. Worse, Claude Code's "Yes, and don't ask again for:" UI offers the literal byte-segment `xargs -I{} sh -c '...'` as an allowlist target — accepting that rule silently degrades the shape guard for the embedded `<body>` path. Observed verbatim in:

```
find .orchestrator -name "T*-SUMMARY.md" -not -path "*/M066/*" 2>/dev/null | head -3 | xargs -I{} sh -c 'echo "═══ {} ═══"; head -20 "{}"'
```

The classifier must descend into `sh -c '<body>'` (one level deep — see Edge Cases / CON-5 in the M028 spec) and sum in-body `;`/`&&`/`||`/`|` connectors with the top-level pipe count, rejecting when the combined count exceeds 2. Body-descent is bounded to one level: if `<body>` itself contains another `sh -c '<inner>'`, the inner is treated as opaque (CON-5 reversibility against pathological recursion).

**Evidence**:
- Source command: see `.orchestrator/milestones/M028/phases/P01/classifier-audit.md` SE-09.
- Corpus fixture: `tests/fixtures/m021-prompt-corpus.txt` ID 25 (verbatim) and ID 27 (one-level-deep boundary case) — both land via M028/P03/T04.
- Original spec narration: `specs/031-autonomous-hardening-v3/spec.md` FR-12 and CON-5.

**Remedy**: Use `scripts/util/peek-files.sh <pattern> [--lines N] [--exclude PATH]` (M028/P04 deliverable) which enumerates matches, prints per-file separators, and head-N's each file — replacing the entire `find | head | xargs sh -c '...'` construction with a single wrapper invocation.

**Cross-Refs**:
- Enforcement layer: `scripts/hooks/pre-bash-shape-guard.sh` (`reject_lookup` case arm `xargs-sh-c-compound-body` → `peek-files.sh AP-014`).
- Regression corpus: `tests/fixtures/m021-prompt-corpus.txt` (entries ID 25 + ID 27 with `EXPECTED_OUTCOME: reject:xargs-sh-c-compound-body`).
- Classifier implementation: `scripts/verify/lib/shape-classifier.sh` (`_sc_has_xargs_sh_c_compound_body` private detector — ordered before the AP-009 top-level-count check so the more specific verdict takes precedence; CON-5 one-level-deep descent bound).
- Self-conformance: `scripts/verify/m028/finding-G-self-conformance.sh` (lints the shape-guard hook against the M028-extended classifier).
- Sibling: AP-009 (top-level compound-chain case).
