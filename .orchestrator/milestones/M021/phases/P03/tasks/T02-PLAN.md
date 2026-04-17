---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M021"
name: "PreToolUse hook (scripts/hooks/pre-bash-shape-guard.sh) wired to Claude Code's hook protocol"
depends_on: ["T01"]
---

## Prerequisites

T01 has shipped `scripts/verify/lib/shape-classifier.sh` with a stable `classify_command <cmd-string>` function. Sourcing the library is side-effect-free.

Claude Code's PreToolUse hook protocol (per AD-1a in `.orchestrator/milestones/M021/M021-CONTEXT.md` and the official Claude Code hook docs at https://code.claude.com/docs/en/hooks):

- **Stdin**: the hook receives a JSON object on stdin. Relevant fields:
  ```json
  {
    "session_id": "…",
    "transcript_path": "…",
    "cwd": "…",
    "hook_event_name": "PreToolUse",
    "tool_name": "Bash",
    "tool_input": { "command": "<bash string>", "description": "…" }
  }
  ```
  (Other tools produce different `tool_input` shapes; the hook must guard against non-`Bash` invocations — return `allow` passthrough — because a future settings entry might widen the hook beyond Bash.)
- **Environment**: `CLAUDE_PROJECT_DIR` is exported. Default timeout 10 minutes.
- **Stdout (allow passthrough)**: empty stdout + exit 0 → Claude Code proceeds with normal permission evaluation.
- **Stdout (rewrite)**: exit 0 + stdout = one JSON object on one line:
  ```json
  {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":{"command":"<rewritten bash>"}}}
  ```
  Claude Code re-runs permission evaluation on the rewritten command.
- **Stderr + exit 2 (reject)**: the hook exits 2 with a one-line stderr diagnostic. Stderr is surfaced to the agent as tool-result feedback; no user prompt fires.

The directory `scripts/hooks/` does not yet exist — T02 creates it.

`scripts/verify/run-suite.sh` does not discover files under `scripts/hooks/` — the hook is not a gate script.

No `jq` dependency. Use pure Bash 3.2 string manipulation to extract `tool_input.command` and to emit the rewrite JSON. A single-field JSON path is tractable with `sed`/`awk` + manual quote handling.

## Description

Author `scripts/hooks/pre-bash-shape-guard.sh` — the PreToolUse hook entry point. The hook:

1. Reads stdin (Claude Code's hook JSON) to completion.
2. Extracts `tool_name` and `tool_input.command` from the JSON.
3. If `tool_name != "Bash"`, exits 0 with empty stdout (pass-through — future-proofing; hook only classifies Bash calls).
4. If the command string is empty, exits 0 with empty stdout.
5. Sources `scripts/verify/lib/shape-classifier.sh` (T01 output) and invokes `classify_command "<cmd>"`.
6. Branches on classifier output:
   - `allow` → exit 0 with empty stdout.
   - `rewrite:<result>` → emit one-line JSON `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":{"command":"<result-escaped>"}}}` and exit 0.
   - `reject:<pattern-class>` → emit stderr line `REJECT: <pattern-class> — use scripts/util/<wrapper>.sh instead. See ANTIPATTERNS.md#AP-00X.` and exit 2. Wrapper and AP-ID come from a fixed lookup table inside the hook (kept local to hook, not in classifier, so the classifier stays purely about shape).

The hook must be robust against malformed stdin: any parse failure degrades to passthrough (exit 0 empty), not hard-reject. Reason: false positives on hook errors halt autonomy; passthrough falls back to normal allow-list evaluation. Log parse failures to stderr for post-hoc debugging — Claude Code collects stderr only when the hook exits non-zero, so a passthrough stderr is invisible to the agent.

## The Reject Lookup Table (local to hook)

```bash
# pattern-class → (wrapper, AP-ID)
reject_lookup() {
  case "$1" in
    nested-cmd-sub)         printf 'run-probe.sh AP-009\n'   ;;
    compound-chain-gt2)     printf 'run-probe.sh AP-009\n'   ;;
    heredoc-with-expansion) printf 'run-probe.sh AP-008\n'   ;;
    quoted-brace)           printf 'read-range.sh AP-007\n'  ;;
    *)                      printf 'run-probe.sh AP-009\n'   ;;  # default for unknown class
  esac
}
```

Diagnostic format (US-4 AS2, exact string):

```
REJECT: <pattern-class> — use scripts/util/<wrapper> instead. See ANTIPATTERNS.md#<AP-id>.
```

Note the em dash `—` (U+2014, not `--`). Single space either side.

## Steps

### Step 1: Create `scripts/hooks/` directory

Directory is new. Creating it is a one-line `mkdir -p`.

### Step 2: Author `scripts/hooks/pre-bash-shape-guard.sh`

Target scaffold:

```bash
#!/usr/bin/env bash
# scripts/hooks/pre-bash-shape-guard.sh — PreToolUse hook for Bash tool calls.
#
# Reads Claude Code's hook JSON from stdin, consults the shape classifier
# library, and either (a) passes through silently, (b) emits a rewritten
# updatedInput, or (c) hard-rejects with a wrapper-pointing diagnostic.
#
# Installed via .claude/settings.json `hooks.PreToolUse` entry:
#   { "matcher": "Bash", "hooks": [{ "type": "command", "command": "bash scripts/hooks/pre-bash-shape-guard.sh" }] }
#
# Protocol: AD-1a in .orchestrator/milestones/M021/M021-CONTEXT.md
# Matrix:   AD-2 (10 patterns, closed on M011/P05-P07 evidence)
# Bash 3.2 compatible.

set -u

# Locate the repo root. CLAUDE_PROJECT_DIR is set by Claude Code; fall back
# to path-relative resolution if the hook is run outside a Claude Code
# session (e.g. during the T04 harness or T05 gate).
REPO_ROOT="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT" ]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

CLASSIFIER="${REPO_ROOT}/scripts/verify/lib/shape-classifier.sh"

# --- Read stdin ---
# Concatenate the full JSON; Claude Code closes stdin after the single
# message. Timeout is protected by Claude Code's 10-min default.
STDIN_JSON="$(cat)"

# --- Extract tool_name and tool_input.command ---
# Pure Bash 3.2 extraction; no jq.
# tool_name: "Bash" or similar.
TOOL_NAME="$(printf '%s' "$STDIN_JSON" \
  | awk -v RS=',' '/\"tool_name\"[[:space:]]*:/' \
  | sed 's/.*"tool_name"[[:space:]]*:[[:space:]]*"//' \
  | sed 's/".*$//' \
  | head -1)"

if [ "$TOOL_NAME" != "Bash" ]; then
  # Not our concern — pass through.
  exit 0
fi

# tool_input.command: we need the raw string exactly as provided.
# Extraction rule: find `"command"` key inside `tool_input` object.
# Since Claude Code's JSON encoding preserves escape sequences, we
# extract the raw escaped string first, then unescape \", \\, \n, \t.
_raw_cmd_json="$(printf '%s' "$STDIN_JSON" \
  | awk '
    BEGIN { depth=0; in_input=0; capture=0; esc=0; out=""; found=0 }
    {
      for (i=1; i<=length($0); i++) {
        c = substr($0, i, 1)
        # Detect tool_input opener
        if (!in_input && $0 ~ /"tool_input"[[:space:]]*:[[:space:]]*\{/ && i==index($0, "{")) {
          in_input=1; depth=1; continue
        }
        # (Full stdin extractor implemented by T02 author; outline only.)
      }
    }')"

# Simpler (and sufficient) extractor for Claude Code's known-shape JSON:
# the `tool_input.command` field is always a top-level-of-tool_input string.
# Use sed with a lazy match across the whole stdin.
RAW_CMD="$(printf '%s' "$STDIN_JSON" \
  | tr '\n' ' ' \
  | sed -n 's/.*"tool_input"[[:space:]]*:[[:space:]]*{[^}]*"command"[[:space:]]*:[[:space:]]*"\(\(\\.\|[^"\\]\)*\)".*/\1/p' \
  | head -1)"

# Unescape JSON string escapes: \\, \", \n, \t, \r, \/.
CMD="$(printf '%s' "$RAW_CMD" \
  | sed -e 's/\\\\/\\/g' \
        -e 's/\\"/"/g' \
        -e 's/\\n/\n/g' \
        -e 's/\\t/\t/g' \
        -e 's/\\r/\r/g' \
        -e 's/\\\//\//g')"

if [ -z "$CMD" ]; then
  # Parse failure or empty command. Passthrough.
  exit 0
fi

# --- Source the classifier ---
if [ ! -f "$CLASSIFIER" ]; then
  # Classifier not present — passthrough (fail-safe).
  echo "pre-bash-shape-guard.sh: classifier library not found at $CLASSIFIER" >&2
  exit 0
fi
# shellcheck disable=SC1090
. "$CLASSIFIER"

# --- Classify ---
CLASS="$(classify_command "$CMD" 2>/dev/null || true)"

case "$CLASS" in
  allow|'')
    exit 0
    ;;
  rewrite:*)
    RESULT="${CLASS#rewrite:}"
    # JSON-escape the result for emission: \ → \\, " → \", newlines → \n.
    ESCAPED="$(printf '%s' "$RESULT" \
      | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
      | awk 'BEGIN{ORS=""} {if (NR>1) print "\\n"; print}')"
    # Emit single-line JSON on stdout. Exit 0.
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":{"command":"%s"}}}\n' "$ESCAPED"
    exit 0
    ;;
  reject:*)
    PATTERN_CLASS="${CLASS#reject:}"
    LOOKUP="$(reject_lookup "$PATTERN_CLASS")"
    WRAPPER="$(printf '%s' "$LOOKUP" | awk '{print $1}')"
    AP_ID="$(printf '%s' "$LOOKUP" | awk '{print $2}')"
    # Use U+2014 em dash, single spaces, final period.
    printf 'REJECT: %s \xe2\x80\x94 use scripts/util/%s instead. See ANTIPATTERNS.md#%s.\n' \
      "$PATTERN_CLASS" "$WRAPPER" "$AP_ID" >&2
    exit 2
    ;;
  *)
    # Unknown classifier output — passthrough defensively.
    echo "pre-bash-shape-guard.sh: unknown classifier output: $CLASS" >&2
    exit 0
    ;;
esac

reject_lookup() {
  case "$1" in
    nested-cmd-sub|compound-chain-gt2) printf 'run-probe.sh AP-009\n' ;;
    heredoc-with-expansion)            printf 'run-probe.sh AP-008\n' ;;
    quoted-brace)                      printf 'read-range.sh AP-007\n' ;;
    *)                                 printf 'run-probe.sh AP-009\n' ;;
  esac
}
```

**Author note.** The sketch above has `reject_lookup` defined at the bottom but called in the `reject:*` branch above. Real implementation must define the function **before** any code that calls it (Bash function definitions are hoisted at parse time within a single script, but for clarity and to match the T01 library style, author defines all helpers near the top).

**Author note.** The stdin extractor shown (with `tr '\n' ' ' | sed -n ...`) works for Claude Code's single-line JSON messages. If Claude Code pretty-prints the JSON across multiple lines, the `tr` flattens newlines first. The `sed` pattern is defensive about embedded escaped quotes via the `\(\\.\|[^"\\]\)*` class.

**Author note.** Em dash bytes `\xe2\x80\x94` are emitted via `printf` — use `printf '%b'` or bare `printf` with the 3-byte sequence in double-quotes. Alternatively, store the em dash as a literal UTF-8 character in the script and use `printf '%s' "REJECT: … — …"` — editor's choice.

### Step 3: Make the hook executable

```
chmod +x scripts/hooks/pre-bash-shape-guard.sh
```

### Step 4: Manual smoke test

```
# Pass-through case
printf '{"tool_name":"Bash","tool_input":{"command":"bash scripts/verify/run-suite.sh m021 P03"}}\n' \
  | bash scripts/hooks/pre-bash-shape-guard.sh
echo "exit=$?"
# Expected: empty stdout, exit=0

# Rewrite case: sed-n-range
printf '{"tool_name":"Bash","tool_input":{"command":"sed -n '\''10,20p'\'' file.md"}}\n' \
  | bash scripts/hooks/pre-bash-shape-guard.sh
echo "exit=$?"
# Expected stdout: {"hookSpecificOutput":...,"updatedInput":{"command":"bash scripts/util/read-range.sh file.md 10 20"}}, exit=0

# Reject case: nested-cmd-sub
printf '{"tool_name":"Bash","tool_input":{"command":"echo $(date $(hostname))"}}\n' \
  | bash scripts/hooks/pre-bash-shape-guard.sh 2>&1 1>/dev/null
echo "exit=$?"
# Expected stderr: REJECT: nested-cmd-sub — use scripts/util/run-probe.sh instead. See ANTIPATTERNS.md#AP-009.
# exit=2
```

Fix any mismatches before writing the T02 summary.

### Step 5: Verify Bash 3.2 compatibility

```
bash -n scripts/hooks/pre-bash-shape-guard.sh
```

Exit 0 required. Additionally, grep the file for the same six forbidden Bash-4 constructs as T01.

## Must-Haves

- File `scripts/hooks/pre-bash-shape-guard.sh` exists, has `#!/usr/bin/env bash` shebang, and is executable (`-rwxr-xr-x` or at least user-executable).
- Hook reads stdin once, extracts `tool_name` and `tool_input.command` via pure Bash 3.2 (no `jq`), and sources the classifier library from `CLAUDE_PROJECT_DIR` (or path-relative fallback).
- On `allow` classification: exit 0, empty stdout.
- On `rewrite:<result>`: exit 0, stdout is a single-line JSON object with keys `hookSpecificOutput.hookEventName="PreToolUse"`, `hookSpecificOutput.permissionDecision="allow"`, `hookSpecificOutput.updatedInput.command=<result-JSON-escaped>`.
- On `reject:<class>`: exit 2, stderr contains the literal string `REJECT: <class> — use scripts/util/<wrapper>.sh instead. See ANTIPATTERNS.md#AP-00X.` on one line (em dash `—` is the U+2014 character).
- Reject lookup table maps all four reject classes to (wrapper, AP-ID) pairs: `nested-cmd-sub`→(`run-probe.sh`, `AP-009`); `compound-chain-gt2`→(`run-probe.sh`, `AP-009`); `heredoc-with-expansion`→(`run-probe.sh`, `AP-008`); `quoted-brace`→(`read-range.sh`, `AP-007`).
- Non-Bash `tool_name` inputs → exit 0, empty stdout (pass-through).
- Empty/malformed stdin → exit 0, empty stdout (fail-safe passthrough; any diagnostic message written to stderr is invisible to the agent on exit 0).
- `bash -n scripts/hooks/pre-bash-shape-guard.sh` exits 0.
- No occurrences of `declare -A`, `mapfile`, `readarray`, `${var,,}`, `${var^^}`, `${!prefix*}`, or `<(` in the hook source.

## Verification

- `bash scripts/verify/m021-p03-hook-integration.sh` asserts each must-have above via driven stdin-JSON cases and exit-code/stderr/stdout comparisons.
- Manual smoke test from Step 4 passes all three probes.

## Inputs

### From Previous Tasks

- `scripts/verify/lib/shape-classifier.sh` (from T01)
  - Key API: `classify_command <cmd-string>` → prints `allow` | `rewrite:<result>` | `reject:<class>`.
  - Sourcing is side-effect-free (AP-003 guard).

### From Disk (Pre-existing)

- `scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh` — rewrite results and reject diagnostics name these by basename. Not invoked by the hook — the hook only emits strings.
- `ANTIPATTERNS.md` AP-005..AP-009 — reject diagnostics cite these anchors; file content is not read at runtime.

## Constraints

- Bash 3.2 compatibility (constitution IX).
- No `jq`, no `python`, no `node` — pure Bash 3.2 + POSIX utilities (`sed`, `awk`, `tr`, `printf`, `cat`).
- Hook latency budget: ≤100ms per call on stock macOS (per spec `## Non-Goals`). Classifier's fall-through path dominates; hook I/O is one stdin read + one stdout/stderr write.
- Single-hook constraint (AD-1a): hook is registered exactly once in `.claude/settings.json`; T03 enforces this.
- Fail-safe on parse errors: passthrough, never reject. User-facing prompts must never increase.
- Diagnostic text is the exact US-4 AS2 shape — any deviation (missing em dash, missing period, wrong spacing, wrong `scripts/util/` prefix) fails the T05 gate.

## Expected Output

- `scripts/hooks/pre-bash-shape-guard.sh` exists and is executable.
- Step-4 smoke tests produce the documented outputs.
- T05 integration gate asserts all three branches (allow, rewrite, reject) via driven stdin and reports PASS.
