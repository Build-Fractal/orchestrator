---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M021"
name: ".claude/settings.json PreToolUse registration + allow-list widening + dispatch-payload 'Allowed invocation shapes' section"
depends_on: ["T02"]
---

## Prerequisites

T02 has shipped `scripts/hooks/pre-bash-shape-guard.sh` at the exact path `scripts/hooks/pre-bash-shape-guard.sh` (repo-relative), executable, and with the contract that `.claude/settings.json` will register it.

Current `.claude/settings.json` structure (v-date 2026-04-16T04:20:19Z):
- `_generated_by`, `_generated_at`, `_autonomy_mode`: metadata — do not modify
- `permissions.defaultMode`: `"acceptEdits"` — do not modify
- `permissions.deny`: 35 entries — must remain byte-identical
- `permissions.allow`: 71 entries — T03 adds 9 new entries, existing entries remain

No existing `hooks` key in settings.json. T03 adds a new top-level `hooks.PreToolUse` array.

`scripts/dispatch/lib/section-handlers.sh` exists (614 lines). The `handle_template` function handles the `constraints|Constraints|CONSTRAINTS` section and currently emits:
- `## Constraints` header
- Four `- **…**: …` lines for verification criteria / budgets
- A `### Prohibited inline bash patterns` subsection ([M016](../../../../../milestones/M016/index.md) output)

T03 appends a sibling subsection `### Allowed invocation shapes` immediately after `### Prohibited inline bash patterns`.

`scripts/verify/run-suite.sh` runs the linter after each phase — if T03 breaks JSON validity in `.claude/settings.json`, it will be surfaced immediately.

## Description

Three edits:

1. **Allow-list widening in `.claude/settings.json`** — append these 9 new entries to the `permissions.allow` array (order not significant, but append to preserve chronological authorship):
   - `Read(/var/folders/**)`
   - `Bash(bash /tmp/*.sh)`
   - `Bash(bash /var/folders/**/*.sh)`
   - `Bash(ls tmp/**)`
   - `Bash(cat tmp/**)`
   - `Bash(sed -n *)`
   - `Bash(head *)`
   - `Bash(tail *)`
   - `Bash(stat *)`

2. **PreToolUse hook registration in `.claude/settings.json`** — add a new top-level `hooks` key:
   ```json
   "hooks": {
     "PreToolUse": [
       {
         "matcher": "Bash",
         "hooks": [
           { "type": "command", "command": "bash scripts/hooks/pre-bash-shape-guard.sh" }
         ]
       }
     ]
   }
   ```
   This is the Claude Code–documented structure: `hooks.PreToolUse` is an array of matcher blocks; each matcher block contains a `matcher` string and a `hooks` array of `{type, command}` objects. Exactly one PreToolUse matcher for `Bash` (AD-1a single-hook constraint). The command is a repo-relative path; Claude Code executes it with `cwd = CLAUDE_PROJECT_DIR`.

3. **Dispatch-payload section in `scripts/dispatch/lib/section-handlers.sh`** — extend the `handle_template` function's `constraints` branch to append a `### Allowed invocation shapes` subsection immediately after the existing `### Prohibited inline bash patterns` block. The new subsection lists the three P01 wrappers with one-line usage examples:

   ```
   ### Allowed invocation shapes

   When an inline bash shape would otherwise trigger a safety prompt, use one of
   these canonical wrappers instead:

   - `bash scripts/util/with-env.sh KEY=VALUE [KEY=VALUE ...] -- <command> [args ...]`
     — Replaces `KEY=VALUE bash cmd` inline-assignment prefixes.
   - `bash scripts/util/read-range.sh <file> <M> <N>`
     — Replaces `sed -n 'M,Np' <file>` line-range reads.
   - `bash scripts/util/run-probe.sh <path-to-staged-probe.sh>`
     — Replaces `cat > /tmp/x.sh <<EOF ... EOF ; bash /tmp/x.sh` heredoc-and-execute.

   A pre-Bash hook (`scripts/hooks/pre-bash-shape-guard.sh`) auto-rewrites six
   common deviations from these shapes and hard-rejects four others with a
   wrapper-pointing diagnostic. See ANTIPATTERNS.md AP-005..AP-009.
   ```

## Steps

### Step 1: Validate current `.claude/settings.json` is well-formed JSON

Before editing, confirm the file parses:

```
bash -c 'python3 -c "import json,sys;json.load(open(sys.argv[1]))" .claude/settings.json' || \
  bash -c 'node -e "JSON.parse(require(\"fs\").readFileSync(process.argv[1]))" .claude/settings.json'
```

Either parser confirms validity. If neither is available, rely on `jq` (already allow-listed transitively via `bash` catch-alls):

```
jq . .claude/settings.json > /dev/null
```

If none of python3/node/jq are present, visually inspect the file — it is only 123 lines.

### Step 2: Edit `.claude/settings.json` — append 9 allow entries + add `hooks` key

Use the Edit tool (preferred) or a helper script under `scripts/util/` (no shell one-liner in-tool-call).

Target post-edit shape:

```json
{
  "_generated_by": "speckit-orchestrator",
  "_generated_at": "2026-04-16T04:20:19Z",
  "_autonomy_mode": "full",
  "permissions": {
    "defaultMode": "acceptEdits",
    "deny": [ /* 35 unchanged entries */ ],
    "allow": [
      /* 71 existing entries unchanged, preserved in order */,
      "Read(/var/folders/**)",
      "Bash(bash /tmp/*.sh)",
      "Bash(bash /var/folders/**/*.sh)",
      "Bash(ls tmp/**)",
      "Bash(cat tmp/**)",
      "Bash(sed -n *)",
      "Bash(head *)",
      "Bash(tail *)",
      "Bash(stat *)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash scripts/hooks/pre-bash-shape-guard.sh" }
        ]
      }
    ]
  }
}
```

The `hooks` key is a new top-level sibling of `permissions`.

### Step 3: Re-validate JSON

Same as Step 1. File must parse.

### Step 4: Edit `scripts/dispatch/lib/section-handlers.sh` — extend `handle_template`

Locate the existing `constraints|Constraints|CONSTRAINTS)` branch (around line 181 of section-handlers.sh). The branch currently ends before the `*)` fallback with several `printf` lines.

Insert — immediately after the last existing `printf -- '- **Compound chains**: …'` line and before the closing `;;` — these additional lines:

```bash
      printf '\n### Allowed invocation shapes\n\n'
      printf 'When an inline bash shape would otherwise trigger a safety prompt, use one\n'
      printf 'of these canonical wrappers instead:\n\n'
      printf -- '- `bash scripts/util/with-env.sh KEY=VALUE [KEY=VALUE ...] -- <command> [args ...]`\n'
      printf '  -- Replaces `KEY=VALUE bash cmd` inline-assignment prefixes.\n'
      printf -- '- `bash scripts/util/read-range.sh <file> <M> <N>`\n'
      printf '  -- Replaces `sed -n '"'"'M,Np'"'"' <file>` line-range reads.\n'
      printf -- '- `bash scripts/util/run-probe.sh <path-to-staged-probe.sh>`\n'
      printf '  -- Replaces `cat > /tmp/x.sh <<EOF ... EOF ; bash /tmp/x.sh` heredoc-and-execute.\n\n'
      printf 'A pre-Bash hook (`scripts/hooks/pre-bash-shape-guard.sh`) auto-rewrites six\n'
      printf 'common deviations from these shapes and hard-rejects four others with a\n'
      printf 'wrapper-pointing diagnostic. See ANTIPATTERNS.md AP-005..AP-009.\n'
```

**Author note.** The `printf` lines use `--` after the format to protect against format strings that start with a dash. Quoted single quotes for the `'M,Np'` example are assembled via the `'"'"'` dance — Bash 3.2 safe.

**Author note.** The bullet list uses `--` instead of a literal em dash to keep the source ASCII-safe. The rendered payload is human-readable either way. If the em dash is preferred, use `printf '  \xe2\x80\x94 Replaces ...'` with the UTF-8 byte sequence.

### Step 5: Verify `section-handlers.sh` still parses and emits the new section

```
bash -n scripts/dispatch/lib/section-handlers.sh
```

Exit 0 required.

Manual probe: source the library and invoke `handle_template`:

```
bash -c '. scripts/dispatch/lib/section-handlers.sh && SH_VERIFICATION_CRITERIA="test" handle_template _ _ _ _ constraints'
```

Output must include the line `### Allowed invocation shapes` and all three `scripts/util/*.sh` paths.

### Step 6: Confirm the hook fires on a real Bash invocation

Not tested in T03 (requires running Claude Code) — asserted by T05 via simulated stdin JSON.

## Must-Haves

- `.claude/settings.json` parses as valid JSON.
- `.claude/settings.json` `permissions.allow` contains all 9 new entries verbatim.
- `.claude/settings.json` `permissions.allow` retains all 71 pre-existing entries in their original order (strict superset).
- `.claude/settings.json` `permissions.deny` is byte-identical to the pre-T03 state (35 entries, same order).
- `.claude/settings.json` has a top-level `hooks.PreToolUse` array with exactly one matcher block (`matcher: "Bash"`) and exactly one hook entry inside it (`{type: "command", command: "bash scripts/hooks/pre-bash-shape-guard.sh"}`).
- `scripts/dispatch/lib/section-handlers.sh` retains the M016 `### Prohibited inline bash patterns` subsection AND adds a sibling `### Allowed invocation shapes` subsection listing all three P01 wrapper paths (`scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh`) with one-line usage examples.
- `bash -n scripts/dispatch/lib/section-handlers.sh` exits 0.
- `handle_template _ _ _ _ constraints` (with env vars set) emits both sections in order.
- No unrelated files modified.

## Verification

- `bash scripts/verify/m021-p03-hook-integration.sh` asserts (a) JSON validity of settings.json, (b) presence of all 9 new allow entries, (c) presence of the single PreToolUse hook registration, (d) presence of `### Allowed invocation shapes` in a rendered dispatch payload, (e) the hook file it names exists and is executable.
- `bash scripts/verify/anti-pattern-lint.sh` exits 0 (the linter scans `scripts/dispatch/lib/` — the new `printf` lines must not trip a detector; the single-quote-in-single-quote dance is safe because the linter scans source text and the assembled `'M,Np'` string appears as literal `'M,Np'` inside a quoted argument, which is not an AP-007 quoted-brace violation).

## Inputs

### From Previous Tasks

- `scripts/hooks/pre-bash-shape-guard.sh` (from T02)
  - Referenced by path in `.claude/settings.json` — file must exist at that exact path before T03's settings entry can pass the T05 gate's file-exists assertion.

### From Disk (Pre-existing)

- `.claude/settings.json` — existing 123-line config. T03 appends only.
- `scripts/dispatch/lib/section-handlers.sh` — existing 614-line library. T03 inserts ~15 lines into the `handle_template` constraints branch.
- `scripts/util/with-env.sh`, `scripts/util/read-range.sh`, `scripts/util/run-probe.sh` — P01 outputs, referenced by path in the new dispatch section.

## Constraints

- Preserve existing JSON key order where the editor preserves it (Edit tool string replacement does). The generator comments `_generated_by` / `_generated_at` stay intact.
- Single PreToolUse hook for Bash (AD-1a).
- No modification to `permissions.deny` list (SC-5 — only widen allow).
- Dispatch-payload changes apply only inside the existing `handle_template` constraints branch — do not alter any other handler.
- The `### Allowed invocation shapes` body must not itself contain shape-heuristic triggers. The bullet examples use backticks (inline-code Markdown) not double quotes; the one embedded single-quote pair (`'M,Np'`) is inside backticks, which the linter's quoted-brace detector does not flag (backticks != double quotes).
- Bash 3.2 compatibility for the added `printf` lines (no process substitution, no brace expansion, no `${var^^}`).

## Expected Output

- `.claude/settings.json` post-edit: valid JSON, 9 new allow entries, 1 new `hooks.PreToolUse` registration.
- `scripts/dispatch/lib/section-handlers.sh` post-edit: `### Allowed invocation shapes` subsection rendered by `handle_template`.
- T05 integration gate passes all settings + dispatch assertions.
