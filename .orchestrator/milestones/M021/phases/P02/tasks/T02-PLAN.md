---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M021"
name: "Append AP-005..AP-009 to ANTIPATTERNS.md with M011 evidence + P01 wrapper remedies"
depends_on: []
---

## Prerequisites

No upstream P02 task dependencies — T02 runs independently of T01 (the linter gains anchor *references* that T02 creates; the anchors and linter can be authored in either order, and T03 verifies both are consistent).

`ANTIPATTERNS.md` exists at the project root (117 lines, 4 entries AP-001..AP-004). It is append-only (constitution AD-11). The existing AP-004 entry documents M015/M008 Class A patterns and already lists a remedy table. AP-005..AP-009 are new entries appended after AP-004.

The three P01 wrappers (`scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh`) exist and have gate tests. Each AP-00X remedy section names the appropriate wrapper.

The M011/P05–P07 screenshot evidence is the authoritative basis for the Class B pattern catalog (see `.orchestrator/milestones/M021/M021-CONTEXT.md` AD-2 and AD-9). The feature spec `specs/021-autonomous-hardening-v2/spec.md` enumerates the specific trigger types per category.

## Description

Append five new entries (AP-005 through AP-009) to `ANTIPATTERNS.md`. Each entry follows the existing AP-001..AP-004 structure exactly:

1. Heading: `## AP-00X: <Short Title>`
2. `**Observed In**:` — `M011 (P05–P07 autonomous-run screenshots, 2026-04-16/2026-04-17)`
3. `**Principle Violated**:` — principle number + short name
4. `**Related Constitution Constraint**:` — AD reference or NFR
5. `**Description**:` — 2–5 sentence explanation of the shape, why Claude Code's safety layer fires on it, and what the agent sees (the observed prompt text from the screenshots).
6. `**Evidence**:` — bullet list with at least one concrete M011/P05–P07 trigger instance. Cite the specific trigger text where available (e.g., `"echo \"RC=$?\""` on M011/P07 dogfood attempt).
7. `**Remedy**:` — concrete fix naming one or more of the P01 wrappers by path, or a pattern substitution table in the AP-004 style.

The five entries are deliberately ordered to match the linter's detector ordering and the M021 roadmap Boundary Map:

- **AP-005**: Simple-expansion `$VAR` / `$?` in inline Bash tool calls. Remedy: `bash scripts/util/with-env.sh` for env-inline; avoid trailing `; echo RC=$?` by letting the child write its own RC to a file.
- **AP-006**: Command substitution `$(...)` in redirect targets. Remedy: write the command output to a fixed path first; read via `bash scripts/util/read-range.sh` or direct `cat`.
- **AP-007**: Braces `{...}` inside double-quoted strings. Remedy: extract awk/shell bodies into standalone scripts; use `bash scripts/util/read-range.sh` for line-range reads.
- **AP-008**: Heredoc with `$VAR` or `$(...)` expansion in tool-call-level bash. Remedy: stage the probe body to a file and invoke via `bash scripts/util/run-probe.sh`.
- **AP-009**: Task-PAYLOAD bash fences re-introducing compound chains (`for...do`, `if...then`, `cd X && Y`, `a; b`). Remedy: extract into a script file or call `bash scripts/util/run-probe.sh`; for verify chains use `bash scripts/verify/run-suite.sh`.

Do not modify AP-001..AP-004. Append-only discipline (AD-11).

## Steps

### Step 1: Read the existing ANTIPATTERNS.md tail

Read `ANTIPATTERNS.md` starting at line 80. Confirm AP-004 ends at line 117 with the Scope of enforcement paragraph. The new entries append immediately after, starting with `## AP-005:` at a new top-level heading. Preserve one blank line between entries (consistent with AP-003 → AP-004 transition).

### Step 2: Append AP-005 — Simple-Expansion in Inline Bash Tool Calls

Append the following block to `ANTIPATTERNS.md`:

```
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
```

### Step 3: Append AP-006 — Command Substitution in Redirect Targets

Append:

```
## AP-006: Command Substitution `$(...)` in Redirect Targets

**Observed In**: M011 (P05–P07 autonomous-run screenshots, 2026-04-16/2026-04-17)
**Principle Violated**: VII (Knowledge Compounds)
**Related Constitution Constraint**: AD-19

**Description**: Bash tool-call strings of the form `bash scripts/foo.sh > "$(scripts/util/logpath.sh)" 2>&1` trigger the safety prompt "Redirect target contains $(cmd) output — path is runtime-determined." The heuristic treats any runtime-resolved path as a write to an unknown location, even when the inner command is pure (e.g., a path-emitter). This is distinct from AP-004's general `$(...)` rule because it fires specifically on the redirect-target position and independently of allow-list entries.

**Evidence**:
- M011/P06 verification: `bash scripts/foo.sh > "$(bash scripts/util/logpath.sh)"` fired "Redirect target contains $(cmd) output" — path is runtime-determined.
- M011/P07 dogfood closeout: `scripts/verify/run-suite.sh m011 P07 > "$(mktemp)"` fired the same prompt.

**Remedy**: Compute the path in a prior step and bind it to a fixed value known to the allow-list. Canonical pattern: the child script writes its output to a deterministic path (`.orchestrator/tmp/<run-id>.log`) and the caller reads it back via `bash scripts/util/read-range.sh` or direct `cat`. Never construct the redirect target via `$(...)`. See P01 wrapper catalog.
```

### Step 4: Append AP-007 — Braces Inside Double-Quoted Strings

Append:

```
## AP-007: Braces `{...}` Inside Double-Quoted Strings

**Observed In**: M011 (P05–P07 autonomous-run screenshots, 2026-04-16/2026-04-17)
**Principle Violated**: VII (Knowledge Compounds)
**Related Constitution Constraint**: AD-19

**Description**: Claude Code's safety heuristic flags `{...}` anywhere inside a double-quoted string with the prompt "Contains brace with quote character (expansion obfuscation)." The canonical offender is an awk body embedded in a quoted argument: `awk "BEGIN{print 42}"`. The heuristic does not distinguish between brace-expansion `{a,b}` (AP-004), parameter-expansion `${VAR}` (safe), and literal braces inside a quoted awk/shell body (the AP-007 case). All three paths converge on the same "brace with quote" trigger in the parser.

**Evidence**:
- M011/P05 verification sweep: `awk 'BEGIN{t=0} /PASS/{t++} END{print t}' $LOG` fired "Contains brace with quote character."
- M011/P07 dogfood summary: `jq -r '.results[] | "{status:\\(.status)}"' results.json` fired the same prompt.

**Remedy**: Extract awk/shell/jq bodies with embedded braces into standalone scripts under `scripts/util/` or `scripts/verify/` and invoke the script by path. For line-range reads that would otherwise use `sed -n '10,20p'` (which trips the related quoted-brace parser path when the `p` flag appears in quotes), use `bash scripts/util/read-range.sh file.md 10 20`. See P01 wrapper catalog.
```

### Step 5: Append AP-008 — Heredoc with Expansion in Tool-Call-Level Bash

Append:

```
## AP-008: Heredoc with `$VAR` / `$(...)` Expansion in Tool-Call-Level Bash

**Observed In**: M011 (P05–P07 autonomous-run screenshots, 2026-04-16/2026-04-17)
**Principle Violated**: VII (Knowledge Compounds)
**Related Constitution Constraint**: AD-19

**Description**: Heredocs containing `$VAR` or `$(...)` expansions in a Bash tool-call string cause Claude Code's parser to emit "Unhandled node type: string" — the parser abandons classification and falls back to asking the user. This fires *before* the allow-list is consulted, so no amount of `Bash(...)` permission widening can suppress it. A quoted heredoc opener (`<<"EOF"` or `<<'EOF'`) with no expansion inside the body is safe; only unquoted heredocs that contain expansions trip the heuristic.

**Evidence**:
- M011/P05 probe staging: `cat > /tmp/probe.sh <<EOF ... $ORCH_REPO ... EOF` fired "Unhandled node type: string."
- M011/P07 dogfood init: `cat > /tmp/m011-p07-init.sh <<EOF ... \$(date) ... EOF` fired the same parser-fallthrough prompt.

**Remedy**: Stage the probe body to a file via a prior Write tool call (which Claude Code handles natively without the parser fallthrough), then invoke via `bash scripts/util/run-probe.sh /tmp/<probe>.sh`. The wrapper's approved-root prefix allow-list covers `/tmp`, `/private/tmp`, `/var/folders`, `/private/var/folders`, and the project `tmp/` directory. See P01 wrapper catalog.
```

### Step 6: Append AP-009 — Task-PAYLOAD Bash Fences Re-Introducing Compound Chains

Append:

```
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
```

### Step 7: Validate structure

After appending all five entries, read the file tail and confirm:
- Headings are exactly `## AP-005:`, `## AP-006:`, `## AP-007:`, `## AP-008:`, `## AP-009:` (one colon, one space, title).
- Each entry has the six standard bold-field labels (`**Observed In**`, `**Principle Violated**`, `**Related Constitution Constraint**`, `**Description**`, `**Evidence**`, `**Remedy**`).
- Each entry names at least one path under `scripts/util/` or `scripts/verify/`.
- Each entry cites M011/P05–P07.
- No AP-001..AP-004 content was modified.

## Must-Haves

- Five new entries appended to `ANTIPATTERNS.md`: AP-005, AP-006, AP-007, AP-008, AP-009 — in that order.
- Each entry cites M011/P05–P07 as the observed-in milestone.
- Each entry names a specific P01 wrapper path (`scripts/util/with-env.sh`, `scripts/util/read-range.sh`, or `scripts/util/run-probe.sh`) in its Remedy section.
- Each entry has at least one concrete M011 evidence bullet.
- Entries follow the exact structural convention established by AP-001..AP-004.
- AP-001..AP-004 remain untouched (append-only discipline, AD-11).

## Verification

- `bash scripts/verify/m021-p02-linter-v2.sh` (from T03) asserts that `ANTIPATTERNS.md` contains each of AP-005..AP-009 and that each entry names a P01 wrapper path.

## Inputs

### From Disk (Pre-existing)

- `ANTIPATTERNS.md` — current 4-entry file; append-only target.
- `scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh` — P01 wrappers referenced by path in the remedy sections.
- `.orchestrator/milestones/M021/M021-CONTEXT.md` — AD-2 and AD-9 document the M021 pattern catalog; evidence bullets align with the decisions recorded there.
- `specs/021-autonomous-hardening-v2/spec.md` — feature spec enumerating the observed trigger types per category (Problem Statement section).

## Constraints

- Append-only — do not modify AP-001 through AP-004.
- Evidence grounded in M011/P05–P07 screenshot observations (constitution II). No speculative patterns (constitution XIV).
- Surgical precision (constitution XV) — exactly five entries, exactly the five patterns the linter detects. No bonus entries.
- Follow the existing ANTIPATTERNS.md structural convention byte-for-byte (section order, bold-field labels, blank-line spacing).
- `ANTIPATTERNS.md` itself is excluded from linter scanning, so the forbidden-pattern text INSIDE the entries does not need suppression markers.

## Expected Output

- `ANTIPATTERNS.md` grows from 4 entries to 9 entries (AP-001..AP-009).
- `grep -c '^## AP-' ANTIPATTERNS.md` returns 9.
- Each new entry names at least one path beginning with `scripts/util/`.
- Each new entry contains the substring `M011`.
