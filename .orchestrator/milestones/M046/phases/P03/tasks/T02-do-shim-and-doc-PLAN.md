---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M046"
name: "do-entry.sh forwarding shim + commands/do.md deprecation doc"
depends_on: ["T01"]
---

## Prerequisites

- T01 completed: `scripts/intake/auto-entry.sh` exists and accepts the six do
  flags plus `--ambiguity-mode`.
- `scripts/intake/do-entry.sh` exists (to be rewritten in place as the shim).
- `commands/do.md` exists (to be rewritten as the deprecation-shim doc).

## Description

Turn `scripts/intake/do-entry.sh` into a thin deprecation shim: emit a one-line
deprecation notice to stderr, forward ALL SIX flags plus `--ambiguity-mode prompt`
verbatim to `auto-entry.sh`, and return `auto-entry.sh`'s exit code unchanged
(FR-3). Rewrite `commands/do.md` as the deprecation-shim doc carrying the D021
removal-runway language (FR-3 / #Q-3).

`--ambiguity-mode prompt` is forwarded so the shim preserves `do`'s legacy
interactive low-conf behavior exactly — a below-floor `do` caller still gets the
Tier A vs Tier B prompt (and honors `--no-prompt-mode`), not the auto-native BLOCK.
This is what keeps scripted `do` callers from silently breaking (US2).

## Steps

1. Replace the body of `scripts/intake/do-entry.sh` with a shim. Keep `set -u` and
   the same `usage()` text (so `-h`/`--help` and usage-error exit 64 are
   unchanged). The shim:
   - Parses the same six flags (`--task`, `--yes`, `--config`, `--dispatch-stub`,
     `--scratch-root`, `--no-prompt-mode`) into the same variables, OR — simpler
     and preferred — passes `"$@"` straight through after prepending
     `--ambiguity-mode prompt`, having first emitted the notice. Prefer the
     pass-through form to guarantee identical flag handling.
   - Emits exactly one deprecation-notice line to STDERR before forwarding, e.g.:
     `do-entry: DEPRECATED — 'orchestrator:do' is now 'orchestrator:auto'. This shim forwards to auto-entry.sh and will be removed no earlier than one published release after this deprecation ships (target named in commands/do.md). Migrate to 'orchestrator:auto <task>'.`
   - Forwards to `bash scripts/intake/auto-entry.sh --ambiguity-mode prompt "$@"`
     and exits with that command's exit code. Do NOT use `eval`; a direct
     `bash scripts/intake/auto-entry.sh --ambiguity-mode prompt "$@"` invocation
     preserves argv boundaries and passes the classify-command auto-safety
     classifier.
   - Keep the `ORCH_DO_ENTRY_LOG` env var pass-through (it is read by
     auto-entry.sh's low-conf branch via the environment — no shim action needed
     beyond not clobbering it).

2. Rewrite `commands/do.md` as the deprecation-shim doc. Keep the frontmatter
   `description` field but reword it to state the command is deprecated and
   forwards to `orchestrator:auto`. Body must contain:
   - A prominent DEPRECATED banner naming `orchestrator:auto <task>` as the
     replacement.
   - The D021 removal runway (verbatim intent): "the shim is retained through at
     least the next published minor release; removal no earlier than one published
     release after this deprecation ships; the deprecation notice names the
     concrete target-removal version."
   - A one-line note that all six flags forward with identical effect (FR-3) and a
     pointer to `scripts/intake/do-entry.sh` (the shim) and
     `scripts/intake/auto-entry.sh` (the driver).
   - The FR-5 / D020 `--yes` boundary note: `--yes` keeps its narrow "skip the
     attended confirmation prompt" meaning under the shim exactly as before; it
     does NOT grant any unattended/destructive authority — `--unattended` is that
     gate.

## Must-Haves

- `scripts/intake/do-entry.sh` forwards to `auto-entry.sh`, emits a deprecation
  notice, passes `bash -n`, and preserves the six-flag surface.
- `commands/do.md` contains "deprecat" and the removal-runway language and
  references `scripts/intake/do-entry.sh`.

## Verification

```bash
test -f scripts/intake/do-entry.sh
bash -n scripts/intake/do-entry.sh
grep -q "auto-entry.sh" scripts/intake/do-entry.sh
grep -qi "deprecat" scripts/intake/do-entry.sh
grep -q "ambiguity-mode prompt" scripts/intake/do-entry.sh
grep -qi "deprecat" commands/do.md
grep -q "do-entry.sh" commands/do.md
```

## Inputs

### From Previous Tasks

- `scripts/intake/auto-entry.sh` (from T01)
  - Key API: `bash scripts/intake/auto-entry.sh --ambiguity-mode prompt [--task
    <t>] [--yes] [--config <c>] [--dispatch-stub <s>] [--scratch-root <d>]
    [--no-prompt-mode <A|B|C>]` OR a bare positional description. Reuses the six do
    flags with identical effect. Under `--ambiguity-mode prompt`, the below-floor
    branch runs the legacy interactive low-conf prompt (do behavior).

### From Disk (Pre-existing)

- `scripts/intake/do-entry.sh` — the current 347-line one-shot driver, rewritten
  in place to the shim. Keep `usage()` + exit-64 semantics.
- `commands/do.md` — the current four-branch authoring doc, rewritten as the
  deprecation-shim doc.

## Constraints

- No `eval` in the shim (auto-safety classifier flags `eval` as FORBIDDEN_IN_AUTO).
  Direct `bash scripts/intake/auto-entry.sh ... "$@"` only.
- The shim must not change flag semantics — pure forward + one notice line.
- MEM001 Bash 3.2 compatibility.

## Expected Output

`scripts/intake/do-entry.sh` is a thin shim that prints a deprecation notice and
forwards to `auto-entry.sh`; `commands/do.md` is the deprecation-shim doc with the
D021 runway and the D020 `--yes` boundary note.
