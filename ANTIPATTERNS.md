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
