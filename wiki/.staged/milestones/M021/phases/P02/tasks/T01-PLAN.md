---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M021"
name: "Extend anti-pattern-lint.sh with five Class B detectors + scope widening + marker opt-in"
depends_on: []
---

## Prerequisites

No upstream P02 task dependencies. P01 is complete and has shipped `scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh`. These paths are referenced by name in the new remediation-hint text but are not sourced or executed by the linter.

The existing linter lives at `scripts/verify/anti-pattern-lint.sh` ([M016](../../../../../milestones/M016/index.md) artifact, ~202 lines). It already implements:
- Per-line scanning inside fenced code blocks only.
- Three Class A checks: `$(...)` command substitution, backtick command substitution, `{word,word}` brace expansion.
- Suppression via `# FORBIDDEN` regions and `# lint-ignore` trailing comments.
- Self-exclusion of the linter source and `ANTIPATTERNS.md`.
- `--fixture <file>` flag to scan only one file.
- Bash 3.2 compatible (constitution IX).

T01 extends this file in place. It does NOT rewrite it — M016's Class A behavior must remain byte-for-byte equivalent on unchanged inputs.

## Description

Add five new Class B shape detectors to `scripts/verify/anti-pattern-lint.sh`, widen its default file discovery to include `scripts/dispatch/lib/**/*.sh` and `.orchestrator/milestones/**/tasks/*-PAYLOAD.md`, and add an `<!-- agent-facing -->` marker opt-in for files under `specs/`, `references/`, and `docs/`. Class B patterns are the residual Claude Code safety-prompt triggers catalogued in M011/P05–P07 screenshots that M016 did not cover. The remediation text for each new pattern class names one of the three P01 wrappers and the matching `ANTIPATTERNS.md#AP-00X` anchor.

The five detectors:

1. **simple-expansion** — flags `$VAR` or `$?` inside a bash-fenced line that also contains a tool-call-shape marker (e.g., leading `echo`, `bash`, `cat`, or a trailing `; echo RC=$?`). Hint: use `scripts/util/with-env.sh` for env-inline patterns; `scripts/util/run-probe.sh` for probe patterns. Anchor: `AP-005`.
2. **redirect-cmd-sub** — flags `$(...)` appearing inside a redirect target (after `>`, `>>`, `<`, `2>`, `&>`, or inside `"$(...)"` used as a filename). Hint: write the command output to a fixed file via a wrapper script. Anchor: `AP-006`.
3. **quoted-brace** — flags `{...}` inside a double-quoted string whose inner content is not a recognized parameter expansion (i.e., not `${VAR}` / `${VAR:-default}` / `${#VAR}` / `${VAR##pat}` etc.). The canonical offender is an awk body like `"BEGIN{…}"` passed as a quoted argument. Hint: call `scripts/util/read-range.sh` for line-range reads; extract awk into a standalone script. Anchor: `AP-007`.
4. **heredoc-expansion** — flags a heredoc opener (`<<EOF`, `<<-EOF`, `<<"EOF"` handled specially) whose body lines contain `$VAR` or `$(...)`. A quoted heredoc (`<<"EOF"` or `<<'EOF'`) with no expansion inside is NOT flagged — those are safe. Hint: use `scripts/util/run-probe.sh` to stage a probe file then invoke it. Anchor: `AP-008`.
5. **task-plan-compound** — flags inline `for …; do …; done`, `if …; then …; fi`, `while …; do …; done`, `cd X && …`, or bare `a; b` semicolon chains appearing inside bash fences of files matched by `.orchestrator/milestones/**/tasks/*-PAYLOAD.md`. (For non-task-PAYLOAD files, the existing M016 detectors already cover `&&`/`||`/`|`/`;` compound chains; this rule exists specifically to extend that enforcement into the task-PAYLOAD surface that M016 didn't scan.) Hint: replace with a single script file invocation; use `scripts/verify/run-suite.sh` for verify chains; use `scripts/util/run-probe.sh` for ad-hoc snippets. Anchor: `AP-009`.

Scope widening: the default file list expands from `commands/*.md` + `templates/*.md` to also include `scripts/dispatch/lib/**/*.sh` and `.orchestrator/milestones/**/tasks/*-PAYLOAD.md`. Under `specs/`, `references/`, and `docs/`, a file is scanned only if it contains a literal `<!-- agent-facing -->` HTML-comment line somewhere before the first fenced code block.

## Steps

### Step 1: Read the current linter source

Read `scripts/verify/anti-pattern-lint.sh` in full. Confirm the structure (argument parsing, file-list build, per-file scan loop with fenced-code-block tracking and suppression, final report). The modifications in the following steps are additive: they layer new logic onto the existing structure without changing Class A behavior.

### Step 2: Widen default file discovery

Locate the `# --- Build file list ---` section (currently lines 44–54). When `FIXTURE_FILE` is empty, the existing code runs two `find` invocations for `commands/` and `templates/`. Add two more:

- `find "$PROJECT_ROOT/scripts/dispatch/lib" -name '*.sh' -type f 2>/dev/null >> "$_file_list" || true`
- `find "$PROJECT_ROOT/.orchestrator/milestones" -path '*/tasks/*-PAYLOAD.md' -type f 2>/dev/null >> "$_file_list" || true`

Then append a third, marker-gated pass. Use a helper Bash-3.2-safe grep to decide whether each candidate file opts in:

```
for _opt_root in specs references docs; do
  _root_abs="$PROJECT_ROOT/$_opt_root"
  [ -d "$_root_abs" ] || continue
  # Candidate files: any .md under the root.
  find "$_root_abs" -name '*.md' -type f 2>/dev/null | while IFS= read -r _cand; do
    # Opt-in check: literal HTML comment marker appearing anywhere in the file.
    if grep -q '<!-- agent-facing -->' "$_cand" 2>/dev/null; then
      printf '%s\n' "$_cand"
    fi
  done >> "$_file_list"
done
```

This block uses a pipe into `while` read but runs inside the linter script's own implementation — Class A rules constrain *agent-facing content* (markdown tool-call lines), not script internals (MEM004, AP-004 "Scope of enforcement" note). The linter is a script, not agent-facing content.

### Step 3: Introduce the Class B detectors in the per-line scan loop

Inside the `while IFS= read -r line; do` body (the existing per-line loop at ~line 87), *after* the three existing Class A checks and *before* the `done < "$file"` line, add the five new detectors as independent `if` blocks. Each block emits its own distinct violation message tagged `[AP-00X]` with a one-line remediation hint. The detectors operate on the already-filtered `$line` variable (already known to be inside a fenced code block and not inside a suppressed region).

Helper: introduce a once-per-file scope flag that marks whether the current file path matches `*/tasks/*-PAYLOAD.md`. Compute it right after the per-file-scope guard:

```
case "$real_file" in
  *"/tasks/"*"-PAYLOAD.md") is_task_payload=1 ;;
  *) is_task_payload=0 ;;
esac
```

Detector 1 — **simple-expansion**:

```
# Flag $VAR or $? when the line looks like a tool-call-shape invocation
# (leads with a command word) OR carries a trailing `; echo RC=$?` tail.
# Parameter-expansion forms ${VAR}, ${VAR:-x}, etc. are handled by being
# masked before the simple-expansion match runs (same trick as Class A
# brace check — strip ${...} first so we only see bare $VAR).
_sline="$(printf '%s\n' "$line" | sed 's/\$[{]/__PEXP__/g')"
if printf '%s\n' "$_sline" | grep -qE '(^|[^_A-Za-z0-9])\$([A-Za-z_][A-Za-z_0-9]*|\?)' 2>/dev/null; then
  violation_count=$((violation_count + 1))
  printf '%s:%d: simple-expansion $VAR or $? in tool-call line  [AP-005]\n' "$short_file" "$line_num" >> "$_violation_out"
  printf '  Hint: Replace inline env prefix with bash scripts/util/with-env.sh. See AP-005 in ANTIPATTERNS.md.\n' >> "$_violation_out"
fi
```

Detector 2 — **redirect-cmd-sub**:

```
# Flag $(...) or "$(...)" appearing after a redirection operator.
# Match: (>|>>|<|2>|&>)[[:space:]]*"?\\$\\(
if printf '%s\n' "$line" | grep -qE '(>|>>|2>|&>)[[:space:]]*"?\$\(' 2>/dev/null; then
  violation_count=$((violation_count + 1))
  printf '%s:%d: redirect-cmd-sub $(...) in redirect target  [AP-006]\n' "$short_file" "$line_num" >> "$_violation_out"
  printf '  Hint: Write to a fixed file path; use bash scripts/util/read-range.sh to read it back. See AP-006 in ANTIPATTERNS.md.\n' >> "$_violation_out"
fi
```

Detector 3 — **quoted-brace**:

```
# Flag {...} inside double quotes that is NOT ${VAR} parameter expansion.
# Strategy: strip ${...} first, then look for a double-quoted span that
# contains { (literal brace inside quotes).
_qline="$(printf '%s\n' "$line" | sed 's/\$[{][^}]*[}]//g')"
if printf '%s\n' "$_qline" | grep -qE '"[^"]*\{[^"]*"' 2>/dev/null; then
  violation_count=$((violation_count + 1))
  printf '%s:%d: quoted-brace {...} inside double-quoted string  [AP-007]\n' "$short_file" "$line_num" >> "$_violation_out"
  printf '  Hint: Extract awk/shell into a standalone script; use bash scripts/util/read-range.sh for line ranges. See AP-007 in ANTIPATTERNS.md.\n' >> "$_violation_out"
fi
```

Detector 4 — **heredoc-expansion**:

This is a multi-line construct, so a pure per-line detector cannot see the whole body. Track heredoc state across lines using two additional flags initialized before the per-line loop starts:

```
in_heredoc=0
heredoc_quoted=0
heredoc_terminator=""
```

Inside the per-line loop, BEFORE the existing Class A checks, add heredoc-state tracking:

```
# Heredoc opener detection: <<EOF, <<-EOF, <<"EOF", <<'EOF'
if [ "$in_heredoc" -eq 0 ]; then
  # Strip indent-leading '-' variant; capture the terminator token.
  _hd_match="$(printf '%s\n' "$line" | grep -oE '<<-?("[A-Za-z_][A-Za-z_0-9]*"|'\''[A-Za-z_][A-Za-z_0-9]*'\''|[A-Za-z_][A-Za-z_0-9]*)' 2>/dev/null | head -n 1)"
  if [ -n "$_hd_match" ]; then
    # Derive terminator (strip <<, <<-, and surrounding quotes).
    _term="$(printf '%s' "$_hd_match" | sed -e 's/^<<-*//' -e 's/^["'\'']//' -e 's/["'\'']$//')"
    heredoc_terminator="$_term"
    in_heredoc=1
    case "$_hd_match" in
      *'"'*|*\'*) heredoc_quoted=1 ;;
      *) heredoc_quoted=0 ;;
    esac
  fi
else
  # Inside heredoc body.
  if [ "$line" = "$heredoc_terminator" ] || [ "$line" = "	$heredoc_terminator" ]; then
    in_heredoc=0
    heredoc_quoted=0
    heredoc_terminator=""
  else
    # Flag $VAR or $(...) inside an UNQUOTED heredoc body.
    if [ "$heredoc_quoted" -eq 0 ]; then
      if printf '%s\n' "$line" | grep -qE '\$\(|\$[A-Za-z_?]' 2>/dev/null; then
        violation_count=$((violation_count + 1))
        printf '%s:%d: heredoc-expansion $VAR or $(...) inside unquoted heredoc body  [AP-008]\n' "$short_file" "$line_num" >> "$_violation_out"
        printf '  Hint: Stage the probe body to a file and invoke via bash scripts/util/run-probe.sh. See AP-008 in ANTIPATTERNS.md.\n' >> "$_violation_out"
      fi
    fi
    # Skip other detectors on heredoc body lines — they would double-flag.
    continue
  fi
fi
```

Important: heredoc state must reset on code-fence-boundary lines and at end-of-file. Add a reset at the `` ``` `` toggle branch (existing lines 93–102) so a code block that opens a heredoc but never closes it doesn't leak state across fences. And reset before the outer `while IFS= read -r file; do` loop's per-file scan begins.

Detector 5 — **task-plan-compound**:

Only fires when `is_task_payload=1`. Uses four independent grep patterns:

```
if [ "$is_task_payload" -eq 1 ]; then
  # Pattern a: inline for-loop.
  if printf '%s\n' "$line" | grep -qE '(^|[^A-Za-z0-9_])for[[:space:]].*;[[:space:]]*do[[:space:]]' 2>/dev/null; then
    violation_count=$((violation_count + 1))
    printf '%s:%d: task-plan-compound inline for ... do loop  [AP-009]\n' "$short_file" "$line_num" >> "$_violation_out"
    printf '  Hint: Extract into a script file; or call bash scripts/util/run-probe.sh <staged>. See AP-009 in ANTIPATTERNS.md.\n' >> "$_violation_out"
  fi
  # Pattern b: inline if-then one-liner.
  if printf '%s\n' "$line" | grep -qE '(^|[^A-Za-z0-9_])if[[:space:]].*;[[:space:]]*then[[:space:]]' 2>/dev/null; then
    violation_count=$((violation_count + 1))
    printf '%s:%d: task-plan-compound inline if ... then one-liner  [AP-009]\n' "$short_file" "$line_num" >> "$_violation_out"
    printf '  Hint: Extract into a script file. See AP-009 in ANTIPATTERNS.md.\n' >> "$_violation_out"
  fi
  # Pattern c: cd X && Y
  if printf '%s\n' "$line" | grep -qE '(^|[^A-Za-z0-9_])cd[[:space:]][^&]+&&' 2>/dev/null; then
    violation_count=$((violation_count + 1))
    printf '%s:%d: task-plan-compound cd X && Y chain  [AP-009]\n' "$short_file" "$line_num" >> "$_violation_out"
    printf '  Hint: Invoke the target script with an absolute path. See AP-009 in ANTIPATTERNS.md.\n' >> "$_violation_out"
  fi
  # Pattern d: semicolon chain at top level (a; b).
  # Match a non-trailing ; followed by more command text.
  if printf '%s\n' "$line" | grep -qE '[^;[:space:]];[[:space:]]*[A-Za-z_]' 2>/dev/null; then
    violation_count=$((violation_count + 1))
    printf '%s:%d: task-plan-compound semicolon chain a; b  [AP-009]\n' "$short_file" "$line_num" >> "$_violation_out"
    printf '  Hint: Split into separate bash fences or call bash scripts/util/run-probe.sh. See AP-009 in ANTIPATTERNS.md.\n' >> "$_violation_out"
  fi
fi
```

### Step 4: Update the final summary text

Change the success-path banner from `LINT PASS: no Class A anti-patterns found in agent-facing content` to `LINT PASS: no Class A or Class B anti-patterns found in agent-facing content`, and the failure-path trailer from `See AP-004 in ANTIPATTERNS.md ...` to `See AP-004..AP-009 in ANTIPATTERNS.md for the full Class A + Class B pattern catalog.`

### Step 5: Smoke-run against the live tree

After edits, run `bash scripts/verify/anti-pattern-lint.sh` against the repo. The current tree must still pass — no new violations may appear in `commands/`, `templates/`, `scripts/dispatch/lib/`, or `.orchestrator/milestones/**/tasks/*-PAYLOAD.md` on the existing codebase. If a real file trips a new detector, audit whether it is a legitimate finding (fix the file in a follow-up) or a false positive (tune the regex with a minimal adjustment documented in the commit message).

## Must-Haves

- All three M016 Class A detectors (`$(...)`, backtick, `{a,b}`) remain present and behave identically on unchanged inputs.
- Five new Class B detectors are implemented, each emitting a distinct `[AP-00X]` tagged violation line with a remediation hint that names a specific `scripts/util/*.sh` wrapper.
- Default file discovery includes `commands/**/*.md`, `templates/**/*.md`, `scripts/dispatch/lib/**/*.sh`, and `.orchestrator/milestones/**/tasks/*-PAYLOAD.md`.
- Files under `specs/`, `references/`, `docs/` are scanned only when they contain `<!-- agent-facing -->`.
- M016 suppression semantics (`# FORBIDDEN`, `# lint-ignore`, ANTIPATTERNS.md self-exclusion, linter self-exclusion) are preserved.
- Script remains Bash 3.2 compatible: no `declare -A`, no `mapfile`, no `${var,,}`, no process substitution `<(...)`, no `[[ =~ ]]` where `case` suffices.
- Linter passes against the current repo with zero violations (baseline preservation).

## Verification

- `bash scripts/verify/anti-pattern-lint.sh` exits 0 against the current repository tree.
- Downstream: `bash scripts/verify/m021-p02-linter-v2.sh` (shipped by T03) passes after T01 + T02 complete.
- Downstream: `bash scripts/verify/m021-p02-linter-scope.sh` (shipped by T04) passes after T01 completes.

## Inputs

### From Disk (Pre-existing)

- `scripts/verify/anti-pattern-lint.sh` — the M016 linter. Modified in place.
- `scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh` — P01 wrappers named in remediation hint text (paths only; not invoked).
- `ANTIPATTERNS.md` — self-excluded. Remediation hints reference `AP-00X` anchors added by T02.

## Constraints

- Bash 3.2 compatible (constitution IX). Keep using `case` for pattern matching where possible; `grep -qE` for BRE/ERE; `sed` for substitution. No `[[ =~ ]]` chains.
- No new runtime dependencies. Pure bash + POSIX utilities + BSD-compatible `find`/`grep`/`sed`/`awk`.
- Strict superset of M016 behavior. Any existing M016 fixture (or the live repo tree) must produce byte-identical violations with v2 — new detectors only ADD lines to the violation list, never REMOVE.
- Surgical precision (constitution XV). No refactor of existing structure. New detectors slot into the existing per-line loop.
- No speculative complexity (constitution XIV). Only the five patterns enumerated. No "while I'm here" additions.
- The linter script is NOT agent-facing content. Its internals may use compound bash, pipes, and `$(...)` freely — AD-19 / AP-004 Scope of enforcement applies only to markdown + dispatch-payload content.

## Expected Output

- `scripts/verify/anti-pattern-lint.sh` modified in place (diff shows five new detector blocks, widened file discovery, marker opt-in, updated summary text).
- `bash scripts/verify/anti-pattern-lint.sh` exits 0 on the current repo.
- Class A behavior unchanged on M016 fixtures.
- Class B patterns trigger distinct violation messages tagged `[AP-005]` through `[AP-009]` with remediation hints naming P01 wrappers.
