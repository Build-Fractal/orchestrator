---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M021"
name: "Shape-classifier library (scripts/verify/lib/shape-classifier.sh) — the 10-pattern matrix as a pure sourceable function"
depends_on: []
---

## Prerequisites

The three P01 wrappers exist on disk and have stable usage signatures (verified via [`.orchestrator/milestones/M021/phases/P01/P01-SUMMARY.md`](../../../../../milestones/M021/phases/P01/P01-SUMMARY.md)):

- `scripts/util/with-env.sh KEY=VALUE [KEY=VALUE ...] -- command [args ...]`
- `scripts/util/read-range.sh <file> <M> <N>`
- `scripts/util/run-probe.sh <path-to-staged-probe.sh>`

The five P02 antipattern IDs exist in `ANTIPATTERNS.md` (AP-005 simple-expansion, AP-006 redirect-cmd-sub, AP-007 quoted-brace, AP-008 heredoc-expansion, AP-009 task-plan-compound) — verified via [`.orchestrator/milestones/M021/phases/P02/P02-SUMMARY.md`](../../../../../milestones/M021/phases/P02/P02-SUMMARY.md).

`scripts/verify/lib/` does not yet exist. This task creates it.

`scripts/verify/run-suite.sh` discovers gate scripts by filename pattern `m<milestone>-p<phase>-*.sh` (lowercase) — this library is under `scripts/verify/lib/` and is NOT a gate script; it is only sourced by T02 hook + T05 gate.

The planning context — specifically AD-2 in [`.orchestrator/milestones/M021/M021-CONTEXT.md`](../../../../../milestones/M021/M021-CONTEXT.md) — defines the exact ten-entry matrix and forbids speculative additions (constitution XIV).

## Description

Author a pure Bash 3.2–compatible library at `scripts/verify/lib/shape-classifier.sh` that exposes a single public function `classify_command <cmd-string>`. The function inspects the command string and prints exactly one line to stdout:

- `allow` — the call is not covered by the matrix; hook passes it through.
- `rewrite:<result-command>` — the call matches one of the six fixable shapes; the hook will return the rewritten command via `hookSpecificOutput.updatedInput.command`.
- `reject:<pattern-class>` — the call matches one of the four unfixable shapes; the hook will emit a `REJECT:` diagnostic on stderr and exit 2.

No file I/O. No subshell forks on the pass-through path. No network. No prompts. Pure text pattern matching via Bash 3.2 `case`, `[[ =~ ]]`, and parameter expansion.

Because Class B detection runs on every Bash tool call, the happy path (fall-through to `allow`) must be cheap: a linear sequence of inexpensive case/regex checks, each short-circuiting on first match. Rough budget: ~30 pattern checks, all in-shell, ≤2ms per call on stock macOS bash.

The library is sourceable without side effects. It must not execute any code at source time other than setting the double-sourcing guard and declaring functions (AP-003 compliance).

## The 10-Pattern Matrix

The function classifies by pattern-class label. The label strings are contractually stable — T02 hook, T04 test harness, and T05 gate all reference them verbatim.

### Rewrites (6)

| # | pattern-class       | Input shape (illustrative)                                 | Output `rewrite:<result>`                                    |
|---|---------------------|------------------------------------------------------------|--------------------------------------------------------------|
| 1 | `trailing-rc-echo`  | `<cmd> ; echo "RC=$?"` or `<cmd>; echo RC=$?`              | `rewrite:<cmd>` (strip the trailing echo-rc clause)         |
| 2 | `sed-n-range`       | `sed -n 'M,Np' <file>`                                     | `rewrite:bash scripts/util/read-range.sh <file> M N`         |
| 3 | `cat-heredoc-exec`  | `cat > /tmp/x.sh <<EOF ... EOF ; bash /tmp/x.sh`           | `rewrite:bash scripts/util/run-probe.sh /tmp/x.sh`           |
| 4 | `cd-and-bash`       | `cd X && bash Y` (or `cd X && bash Y args...`)             | `rewrite:bash Y args...` (assumes Y is already a repo path) |
| 5 | `var-inline-bash`   | `K1=v1 K2=v2 bash Z args...`                               | `rewrite:bash scripts/util/with-env.sh K1=v1 K2=v2 -- bash Z args...` |
| 6 | `redirect-cmd-sub`  | `<cmd> > "$(inner)"` or `<cmd> >> "$(inner)"` or `2>&1>"$(inner)"` | `rewrite:bash scripts/util/read-range.sh ...` — **see note** |

**Rewrite #6 note.** The redirect-cmd-sub rewrite is less mechanical than the other five: no syntactic transformation produces an equivalent command because the redirect target is runtime-determined. The classifier emits `rewrite:bash scripts/util/read-range.sh` with a fixed placeholder — the intent is to force the agent down the deterministic-path branch. **Decision point for T01 author (record in T01-SUMMARY.md):** either (a) emit rewrite with a fixed placeholder and accept that the rewrite is semantically approximate, or (b) classify redirect-cmd-sub as a `reject:` pattern-class pointing at `read-range.sh` via diagnostic. Per AD-2's pattern-class enumeration, (a) is the documented behavior — the rewrite result is "the agent will see an allow-listed `read-range.sh` invocation in updatedInput; if semantics don't match the agent's actual intent, the script's exit 2 invalid-range surfaces as a tool error and the agent retries." T01 implements (a); if dogfood runs surface the semantic mismatch, P04 adds an evidence-backed promotion to `reject:`.

### Rejects (4)

| # | pattern-class             | Input shape (illustrative)                              | AP-ID  | Wrapper hint in diagnostic     |
|---|---------------------------|---------------------------------------------------------|--------|--------------------------------|
| 1 | `nested-cmd-sub`          | `$(outer $(inner))` — any `$(…$(…)…)` nesting           | AP-009 | `scripts/util/run-probe.sh`    |
| 2 | `compound-chain-gt2`      | Three or more stages joined by `&&`, `\|\|`, `\|`, `;` | AP-009 | `scripts/util/run-probe.sh`    |
| 3 | `heredoc-with-expansion`  | `<<EOF ... $VAR ... EOF` or `<<EOF ... $(…) ... EOF` (unquoted heredoc opener) | AP-008 | `scripts/util/run-probe.sh` |
| 4 | `quoted-brace`            | `{` inside `"…"` that is not a `${VAR}` parameter expansion | AP-007 | `scripts/util/read-range.sh` |

**Reject #2 note.** `compound-chain-gt2` triggers when the command has **three or more** pipeline/chain stages joined by `&&`, `||`, `|`, or `;` at the top level (inside a single tool call). Two-stage chains (one `&&` between two scripts) remain covered by [M016](../../../../../milestones/M016/index.md)'s `AP-004` linter but are not rejected by the hook — empirical evidence (M016 dogfood) shows Claude Code's safety layer does not prompt on 2-stage chains. Count stages by splitting on any of the four operators at top-level depth (not inside quotes, not inside `$(…)`). Bash 3.2 safe implementation: iterate character-by-character tracking quote state and paren depth.

## Steps

### Step 1: Create `scripts/verify/lib/` directory

Create the directory via a single `mkdir -p` invocation in the T01 execution. Do not create any other file there.

### Step 2: Author `scripts/verify/lib/shape-classifier.sh`

Target structure:

```bash
#!/usr/bin/env bash
# scripts/verify/lib/shape-classifier.sh — Shape classifier for the
# M021 10-pattern rewrite/reject matrix. Sourced by
# scripts/hooks/pre-bash-shape-guard.sh and
# scripts/verify/m021-p03-hook-integration.sh.
#
# Public API:
#   classify_command <cmd-string>
#     Prints exactly one line:
#       allow
#       rewrite:<result-command>
#       reject:<pattern-class>
#
# The 10-entry matrix is closed on M011/P05-P07 evidence (AD-2).
# No speculative additions (constitution XIV).
#
# Bash 3.2 compatible. No process substitution. No associative arrays.
# No bash-4 parameter expansions (${var,,}, ${var^^}, ${!prefix*}).

[ -n "${_SHAPE_CLASSIFIER_SOURCED:-}" ] && return 0
_SHAPE_CLASSIFIER_SOURCED=1

# --- Private helpers (prefix `_sc_`) ---
# _sc_count_top_level_stages <cmd> → prints integer (≥1)
# _sc_has_nested_cmd_sub <cmd>     → exit 0 if nested $(… $(…) …) present
# _sc_has_unquoted_heredoc_expansion <cmd> → exit 0 if `<<EOF` (not `<<'EOF'` or `<<"EOF"`) and body has $VAR or $(…)
# _sc_has_quoted_brace <cmd>       → exit 0 if `{` appears inside "…" and is not ${...}
# _sc_extract_sed_n_args <cmd>     → prints "<file>\t<M>\t<N>" for `sed -n 'M,Np' <file>` shape
# _sc_strip_trailing_rc_echo <cmd> → prints cmd with `; echo "RC=$?"` / `; echo RC=$?` removed; exit 0 if stripped, 1 otherwise
# _sc_extract_var_inline_bash <cmd> → prints "K1=v1 K2=v2 -- bash Z args..." if leading assignments + `bash ...` found
# _sc_extract_cd_and_bash <cmd>    → prints "bash Y args..." if `cd X && bash Y args...` found
# _sc_extract_cat_heredoc_exec <cmd> → prints "<tmp-path>" if `cat > <tmp-path> <<EOF ... EOF ; bash <tmp-path>` shape found

# --- Public API ---
classify_command() {
  local cmd="$1"

  # Reject pattern-class checks run FIRST — rejects dominate over rewrites
  # when a command matches both (e.g. a compound chain with a nested $(…)
  # is rejected, not rewritten).

  if _sc_has_nested_cmd_sub "$cmd"; then
    printf '%s\n' 'reject:nested-cmd-sub'
    return 0
  fi

  local stages
  stages="$(_sc_count_top_level_stages "$cmd")"
  if [ "${stages:-1}" -gt 2 ]; then
    printf '%s\n' 'reject:compound-chain-gt2'
    return 0
  fi

  if _sc_has_unquoted_heredoc_expansion "$cmd"; then
    printf '%s\n' 'reject:heredoc-with-expansion'
    return 0
  fi

  if _sc_has_quoted_brace "$cmd"; then
    printf '%s\n' 'reject:quoted-brace'
    return 0
  fi

  # --- Rewrite pattern-class checks ---

  # 3: cat-heredoc-exec (must run before compound-chain detection short-circuits
  #    since it uses `;` internally — but we already passed the >2-stage check,
  #    so any `cat > ... <<EOF ... EOF ; bash ...` with exactly 2 stages is OK)
  local heredoc_tmp
  if heredoc_tmp="$(_sc_extract_cat_heredoc_exec "$cmd")"; then
    printf 'rewrite:bash scripts/util/run-probe.sh %s\n' "$heredoc_tmp"
    return 0
  fi

  # 1: trailing-rc-echo
  local stripped
  if stripped="$(_sc_strip_trailing_rc_echo "$cmd")"; then
    printf 'rewrite:%s\n' "$stripped"
    return 0
  fi

  # 2: sed-n-range
  local sed_args
  if sed_args="$(_sc_extract_sed_n_args "$cmd")"; then
    # sed_args format: "<file>\t<M>\t<N>"
    local _f _m _n
    _f="$(printf '%s' "$sed_args" | awk -F'\t' '{print $1}')"
    _m="$(printf '%s' "$sed_args" | awk -F'\t' '{print $2}')"
    _n="$(printf '%s' "$sed_args" | awk -F'\t' '{print $3}')"
    printf 'rewrite:bash scripts/util/read-range.sh %s %s %s\n' "$_f" "$_m" "$_n"
    return 0
  fi

  # 4: cd-and-bash
  local cd_rewrite
  if cd_rewrite="$(_sc_extract_cd_and_bash "$cmd")"; then
    printf 'rewrite:%s\n' "$cd_rewrite"
    return 0
  fi

  # 5: var-inline-bash
  local var_rewrite
  if var_rewrite="$(_sc_extract_var_inline_bash "$cmd")"; then
    printf 'rewrite:bash scripts/util/with-env.sh %s\n' "$var_rewrite"
    return 0
  fi

  # 6: redirect-cmd-sub (see note in the task plan header re: approximate rewrite)
  if [[ "$cmd" =~ (\>|\>\>|2\>\&1\>)[[:space:]]*\"?\$\( ]]; then
    printf '%s\n' 'rewrite:bash scripts/util/read-range.sh'
    return 0
  fi

  # Fall-through: allow
  printf '%s\n' 'allow'
}
```

Flesh out every private `_sc_*` helper. Each is pure (no forks, no file I/O). Use Bash 3.2 patterns (`case`, `[[ =~ ]]`, parameter expansion) — do not use `declare -A`, `mapfile`, `readarray`, `${var,,}`, `${var^^}`, `${!prefix*}`, or process substitution `<(…)`. When regex-matching strings that might contain quotes, assemble the ERE via variable concatenation (pattern proven in P02 T01 for the heredoc-opener detector).

### Step 3: Author unit coverage inline in T05 (not here)

T05's integration gate (`scripts/verify/m021-p03-hook-integration.sh`) will source `shape-classifier.sh` directly and invoke `classify_command` with 20+ inputs (≥2 per rewrite, ≥2 per reject, ≥4 pass-through). That is the classifier's unit gate. T01 authors only the library — do not add a separate unit harness here.

### Step 4: Verify Bash 3.2 compatibility

Run locally during T01 execution:

```
bash -n scripts/verify/lib/shape-classifier.sh
```

Exit 0 indicates the file parses cleanly. Additionally, grep the file for the six forbidden Bash-4 constructs listed in P01's compat gate (`declare -A`, `mapfile`, `readarray`, `${var,,}`, `${var^^}`, `${!prefix*}`) and confirm zero hits. The T05 integration gate will repeat both checks.

### Step 5: Self-verify classifier behavior

Run these probes after authoring:

```
# All must print `allow`
bash -c '. scripts/verify/lib/shape-classifier.sh && classify_command "bash scripts/verify/run-suite.sh m021 P03"'
bash -c '. scripts/verify/lib/shape-classifier.sh && classify_command "ls scripts/"'

# Must print `rewrite:bash scripts/util/read-range.sh file.md 10 20`
bash -c ". scripts/verify/lib/shape-classifier.sh && classify_command \"sed -n '10,20p' file.md\""

# Must print `reject:nested-cmd-sub`
bash -c '. scripts/verify/lib/shape-classifier.sh && classify_command "echo \$(date \$(hostname))"'
```

Fix any mismatches before writing the T01 summary.

## Must-Haves

- File `scripts/verify/lib/shape-classifier.sh` exists, is a regular file (not a symlink), has `#!/usr/bin/env bash` shebang, starts with a double-sourcing guard `[ -n "${_SHAPE_CLASSIFIER_SOURCED:-}" ] && return 0 ; _SHAPE_CLASSIFIER_SOURCED=1`.
- The file defines a function named `classify_command` callable as `classify_command <cmd-string>`.
- `classify_command` prints exactly one line per invocation — `allow`, `rewrite:<result-command>`, or `reject:<pattern-class>`.
- All ten pattern-class labels from AD-2 appear verbatim in the source: `trailing-rc-echo`, `sed-n-range`, `cat-heredoc-exec`, `cd-and-bash`, `var-inline-bash`, `redirect-cmd-sub`, `nested-cmd-sub`, `compound-chain-gt2`, `heredoc-with-expansion`, `quoted-brace`.
- The file is Bash 3.2 compatible: `bash -n` exits 0 and grep shows zero occurrences of `declare -A`, `mapfile`, `readarray`, `${var,,}`, `${var^^}`, `${!prefix*}`, and `<(`.
- Sourcing the file has no side effects beyond setting the guard variable and defining functions — no `echo`, no `printf`, no subshells, no file operations at source time.
- The file length is ≥160 lines (enforces explicit helpers per pattern-class — single monolithic function indicates insufficient decomposition).

## Verification

- `bash scripts/verify/m021-p03-hook-integration.sh` (T05 gate) invokes this library and must pass its `classify_command` assertion suite. During T01 execution, T05 does not yet exist — re-run this gate after T05 completes.
- `bash -n scripts/verify/lib/shape-classifier.sh` exits 0.

## Inputs

### From Previous Tasks

None (T01 is the first P03 task).

### From Disk (Pre-existing)

- `scripts/util/with-env.sh` — rewrite #5 target; usage signature `KEY=VALUE [KEY=VALUE ...] -- command [args ...]`.
- `scripts/util/read-range.sh` — rewrite #2 and #6 target; usage signature `<file> <M> <N>`.
- `scripts/util/run-probe.sh` — rewrite #3 target; usage signature `<path-to-staged-probe.sh>`.
- `ANTIPATTERNS.md` — read-only; pattern-class labels in reject cases must map to AP-IDs consistently (T02 hook cites them).
- [`.orchestrator/milestones/M021/M021-CONTEXT.md`](../../../../../milestones/M021/M021-CONTEXT.md) — AD-2 defines the exact matrix; AD-1a defines the hook protocol T02 consumes.

## Constraints

- Bash 3.2 compatibility (constitution IX).
- No file I/O, no subshell forks on the allow path — happy path must be a linear regex fall-through.
- Exactly ten pattern-class entries (constitution XIV — no speculative additions).
- Double-sourcing guard (AP-003 compliance).
- Self-contained — sourcing the library defines functions and returns; does not import any other library file.
- No stdout or stderr output at source time.
- Reject checks run before rewrite checks (rejects dominate overlapping matches).

## Expected Output

- `scripts/verify/lib/shape-classifier.sh` exists with `classify_command` function.
- Manual probes from Step 5 all produce the expected output strings.
- Grep finds all ten pattern-class labels in the file source.
- T05 gate's classifier assertion suite passes against this library.
