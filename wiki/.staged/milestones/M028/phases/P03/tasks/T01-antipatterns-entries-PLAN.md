---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M028"
name: "ANTIPATTERNS Entries (AP-010 through AP-014)"
depends_on: []
---

## Prerequisites

- `ANTIPATTERNS.md` exists at the repo root (verified: `[ -f /Users/brettkellgren/Sites/orchestrator/ANTIPATTERNS.md ]` returns exit 0; current line count 214).
- `.orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md` exists with the per-screenshot causal trace for SE-02..SE-05 + SE-09 (the five canonical evidence sources for AP-010..AP-014).
- The M028 spec at `specs/031-autonomous-hardening-v3/spec.md` defines FR-8 through FR-12 (one FR per new AP) and Edge Cases (CON-5 body-descent depth bound for AP-014).

## Description

Append five new entries (AP-010 through AP-014) to `ANTIPATTERNS.md` following the established AP-001..AP-009 entry shape. The register is append-only per its file header ("Entries are permanent — they do not decay or expire"); existing AP-001..AP-009 entries are NOT modified.

Each new entry must have:
- A level-2 heading: `## AP-NNN: <Title Case Description>`
- An `**Observed In**:` line citing M028 + the screenshot date or the Finding letter.
- A `**Principle Violated**:` line citing the constitution principle (existing entries reference Roman numerals; principle numerals captured per #Q-5 — see Notes).
- A `**Related Constitution Constraint**:` line.
- A `**Description**:` paragraph explaining the shape and why it trips the heuristic.
- An `**Evidence**:` bulleted list citing M028 source-event paths AND corpus IDs (corpus IDs land in T04; cite them by ID number even though the corpus lines do not yet exist — the corpus is the canonical evidence target).
- A `**Remedy**:` paragraph naming the wrapper or escape hint.
- A `**Cross-Refs**:` section listing: enforcement layer (the hook), regression corpus (the fixture), classifier implementation (the lib), and where applicable the P04 wrapper.

## Steps

1. **Read the existing AP-009 entry** at `ANTIPATTERNS.md` lines 196..214 as the canonical shape template. Each new entry mirrors this shape exactly.

2. **Append AP-010 (cmd-sub-in-pattern)** to the end of `ANTIPATTERNS.md`:

```markdown
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
```

3. **Append AP-011 (quoted-arg-newline-hash)** with the same shape:

```markdown
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
```

4. **Append AP-012 (multiline-quoted-script)**:

```markdown
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
```

5. **Append AP-013 (unquoted-brace-glob)**:

```markdown
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
```

6. **Append AP-014 (xargs-sh-c-compound-body)**:

```markdown
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
```

7. **Verify the file's overall shape** stays consistent: header preserved (line 1: `# Antipattern Register`), entry order preserved (AP-001..AP-009 unchanged, AP-010..AP-014 appended in numerical order), no spurious whitespace or formatting drift.

## Must-Haves

This task addresses the phase Truth: "ANTIPATTERNS.md carries the five new entries AP-010 through AP-014, each with a Description, Evidence, Remedy, and Cross-Refs section."

The plan-level verifier `scripts/verify/m028/p03-antipatterns-entries.sh` (created in T05) asserts:
- The 5 level-2 headings exist verbatim (`## AP-010:`, `## AP-011:`, `## AP-012:`, `## AP-013:`, `## AP-014:`).
- Each entry has the four required sub-sections (`**Description**:`, `**Evidence**:`, `**Remedy**:`, `**Cross-Refs**:`).
- Each entry's Cross-Refs section names the corresponding pattern-class label (cmd-sub-in-pattern, quoted-arg-newline-hash, multiline-quoted-script, unquoted-brace-glob, xargs-sh-c-compound-body) — so the document remains a navigable register from any AP-ID to the matching classifier label.
- AP-001 through AP-009 headings are still present unchanged (append-only invariant).

## Verification

```bash
bash scripts/verify/m028/p03-antipatterns-entries.sh
```

## Notes

`scripts/verify/check-must-haves.sh .orchestrator/milestones/M028/phases/P03` is a phase-level check; it runs at phase close, not per-task. Per-task `## Verification` invokes only task-scoped verifiers (matches P02 convention).

## Inputs

### From Previous Tasks

- None (T01 has no upstream task in P03).

### From Disk (Pre-existing)

- `ANTIPATTERNS.md` — the existing 9-entry register (AP-001..AP-009). T01 appends entries AP-010..AP-014.
- `.orchestrator/milestones/M028/phases/P01/P01-VERIFICATION.md` — per-screenshot causal trace SE-02..SE-05, SE-09 (the canonical evidence cited in the new entries).
- `specs/031-autonomous-hardening-v3/spec.md` — FR-8 through FR-12 (one FR per AP); CON-5 (AP-014 body-descent depth bound).
- `.orchestrator/memory/constitution.md` — for Principle II / IX numerals (#Q-5; planner confirmed best-effort at spec-authoring time; T01 author re-confirms exact numerals at append time).

## Constraints

- **CON-1 (AD-19 single-script-file)**: This task is documentation-only; no scripts are authored. No constraint impact.
- **CON-7 (no-M021-regression)**: AP-001..AP-009 entries are NOT modified. The register is append-only per its file header.
- **Closed pattern set**: T01 ships exactly five entries (AP-010..AP-014). Do not add AP-015 or beyond — the M028 spec is closed on the seven-screenshot evidence (Non-Goals: "Re-numbering AP-IDs", "Pattern set closed on the evidence").
- **Cross-ref forward-compatibility**: T01 entries cite corpus IDs 21..25, 27 (which T04 will create) and the P04 wrappers (`grep-files.sh`, `node-eval.sh`, `peek-files.sh`) which P04 will create. The cross-references are evergreen pointers; they do not break the register if the target lands later.

## Expected Output

After running `bash scripts/verify/m028/p03-antipatterns-entries.sh`:

```
PASS: AP-010 heading present
PASS: AP-011 heading present
PASS: AP-012 heading present
PASS: AP-013 heading present
PASS: AP-014 heading present
PASS: AP-010 has Description / Evidence / Remedy / Cross-Refs sub-sections
PASS: AP-011 has Description / Evidence / Remedy / Cross-Refs sub-sections
PASS: AP-012 has Description / Evidence / Remedy / Cross-Refs sub-sections
PASS: AP-013 has Description / Evidence / Remedy / Cross-Refs sub-sections
PASS: AP-014 has Description / Evidence / Remedy / Cross-Refs sub-sections
PASS: AP-001..AP-009 headings preserved
PASS: AP-014 cites CON-5 body-descent
PASS: p03-antipatterns-entries.sh
```

(Verifier itself ships in T05; T01's truth-Check passes once T05 lands. T01 may be authored before T05; the truth-Check enters the green wall during T05's verification pass.)

After running `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M028/phases/P03`:

```
PASS: ANTIPATTERNS.md (min 280 lines, contains "AP-014: xargs sh -c Compound Body")
```

(Other phase-level must-haves remain RED until T02..T05 land.)
