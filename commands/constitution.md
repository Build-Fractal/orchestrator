---
description: "Use when authoring the project's constitution from a stack-aware starter via interactive grilling-protocol flow. Lands at .orchestrator/memory/constitution.md."
---

# orchestrator:constitution

FR-3 deliverable for M033 (036-project-onboarding-experience). The
orchestrator-native constitution-authoring front door — replaces any
upstream-framework `*.constitution` content-authoring path. Loads a
stack-aware starter from the closed v1 list, runs a 5–8-question
grilling-protocol pass, substitutes the closed `{{...}}` placeholder
vocabulary, hands the draft to `$EDITOR`, gates on the FR-5 shape lint,
and writes the resolved constitution to
`<project-dir>/.orchestrator/memory/constitution.md`.

The driver is `scripts/lifecycle/constitution-author.sh`. The lint
gate is `scripts/verify/constitution-shape-lint.sh`. The
distribution-surface gate (Principle XVI) is
`scripts/verify/standalone-gate.sh constitution`.

## Prerequisites / State Check

- `orchestrator:init` has run for the target project (either same
  invocation context or upstream sub-flow); at minimum the project
  directory exists. The driver creates `<project-dir>/.orchestrator/`
  and `<project-dir>/.orchestrator/memory/` on demand if absent.
- The closed v1 stack list is `web-saas`, `cli-tool`, `library`. Stacks
  outside this list are rejected with a `#Q-2` expansion-path pointer
  echoed to stderr.

## Core Workflow

The driver runs a fixed pipeline. Each step is observable and
restartable; the lint gate at step 6 is the only step that can halt
the write.

### 1. Stack selection (closed v1 enum)

The operator passes `--stack <web-saas|cli-tool|library>` (or accepts
the recommended stack derived from manifest probing — see FR-1's
`--stack` recommendation convention). Unknown stack exits non-zero
with the v1 list and a `#Q-2` pointer to the
`references/constitution-starter-format.md` expansion section.

### 2. Starter load

Reads `templates/constitution-starters/<stack>.md` into a per-run
temp directory under `mktemp -d`. The starter ships with frontmatter
(`schema_version: "1.0"`, `type: constitution-starter`, `stack`), a
`## Constitution Check` anchor, six baseline `### Principle` sub-headers
(Roman numerals I–VI), and two stack-specific sub-headers (VII–VIII).

### 3. Grilling-protocol flow (5–8 questions)

The driver sources `scripts/lifecycle/grilling-shell.sh` and invokes
`ask_one <question> <recommendation> <accumulator>` sequentially per
CON-5 (never batched). The accumulator path
`<project-dir>/.orchestrator/intake/<timestamp>/partial-answers.yml` is
passed on every call so MIT-007 contradiction-detection fires during
normal sessions, not only on resume.

The 3 universal questions resolve the closed placeholder vocabulary:

- `{{project_type}}` — the project's identity in one short clause.
- `{{primary_constraint}}` — the dominant operating constraint.
- `{{target_user}}` — the user the project serves.

Each stack adds 2–3 stack-specific follow-ups documented in the driver:

- `web-saas`: deployment_target, auth_model, data_residency.
- `cli-tool`: primary_subcommand_pattern, distribution_channel.
- `library`: language_or_runtime, distribution_channel.

The total question count lands at 5–8 (3 + 2 or 3) per FR-3.

### 4. Placeholder substitution

The driver replaces every `{{<placeholder-key>}}` token in the temp
copy of the starter via `sed -i.bak` (POSIX-portable form; the `.bak`
sidecar is removed afterward). Bash 3.2 compatibility (MEM001) — no
associative arrays; parallel indexed arrays only.

### 5. Editor hand-off

The driver invokes `"$EDITOR" "<temp-file>"` so the operator reviews
the substituted draft. Tests bypass via `EDITOR=cat`. The `--yes`
flag also bypasses (useful for CI / autonomous flows).

### 6. Lint gate (FR-5)

The driver invokes `bash scripts/verify/constitution-shape-lint.sh
<temp-file>`. On non-zero exit, the lint stderr is propagated, a
`FAIL: lint rejected — re-invoke and re-edit; no partial write`
diagnostic is emitted to stderr, and the driver exits non-zero. NO
partial file is written to the project (US-2 AS-5).

### 7. Write

On lint pass, the driver `cp`s the temp file to
`<project-dir>/.orchestrator/memory/constitution.md` and removes the
temp dir.

### 8. Marker write (FR-20)

The driver invokes `bash scripts/util/start-state-markers.sh write
constitution-authored "<project-dir>"`. The marker file at
`<project-dir>/.orchestrator/start-state/constitution-authored.complete`
contains the ISO 8601 UTC timestamp of the first write (idempotent).

### 9. Event emission (FR-22)

The driver invokes `PROJECT_DIR=<project-dir> bash
scripts/util/jsonl-event-emitter.sh emit constitution_authored
'{"stack":"<stack>","force":<true|false>}'`. Exactly one
`constitution_authored` JSONL record per successful run.

### 10. Recent-changes fragment (FR-21)

The driver invokes `bash scripts/util/dual-write-runtime-md.sh
--marker recent-changes --append-entry "M033/<stack>: constitution
authored from <stack> starter"`. The helper writes to CLAUDE.md and
(per `dual_write_agents` config) AGENTS.md.

## Output

- `<project-dir>/.orchestrator/memory/constitution.md` — the resolved
  constitution.
- `<project-dir>/.orchestrator/start-state/constitution-authored.complete`
  — partial-state marker.
- One `constitution_authored` JSONL record appended to
  `<project-dir>/.orchestrator/execution-log.jsonl`.
- One one-line fragment appended to the
  `# >>> orchestrator:recent-changes >>>` region of CLAUDE.md (and
  AGENTS.md unless `dual_write_agents: false`).

## Idempotency

- Re-running without `--force` when the constitution already exists
  is byte-identical: the file on disk is preserved, `no changes` is
  echoed to stdout, a `constitution_authored` event with
  `payload.action="no-changes"` is emitted, and the driver exits 0.
- Re-running with `--force` regenerates the constitution from the
  starter; a `WARN: --force discards prior operator edits` line is
  emitted to stderr before the lint+write step.

## Flags

| Flag | Description |
|---|---|
| `--stack NAME` | One of `web-saas`, `cli-tool`, `library` (closed v1 enum). |
| `--project-dir PATH` | Project root (default: `$PWD`). |
| `--force` | Regenerate even if a constitution is already present. |
| `--yes` | Skip the `$EDITOR` review pass (for CI / autonomous flows). |

## Error Handling

- Unknown `--stack` → exit non-zero; stderr names the v1 list and the
  `#Q-2` expansion-path pointer (US-2 AS-4).
- Lint failure → exit non-zero; stderr names the missing or malformed
  item; no partial write to the project (US-2 AS-5).
- Missing starter file (corrupt install) → exit non-zero with a
  diagnostic naming `templates/constitution-starters/<stack>.md`.

## Standalone Posture (CON-3 / Principle XVI)

This command and its driver `scripts/lifecycle/constitution-author.sh`
ship free of upstream-framework references. The mechanical compliance
test is `bash scripts/verify/standalone-gate.sh constitution`, which
scans the closed surface (this command, the driver, the three
starters, the format reference, and the lint) for any case-insensitive
trigger substring. Zero matches required. M033/P03 verifiers re-run
the gate as a dogfood smoke after every land.

The principle names mirrored from the orchestrator's own canonical
baseline (Context Minimization, Evidence Before Claims, Design Before
Code, Plans Assume Zero Context, State On Disk Is Truth, Knowledge
Compounds) appear in every starter under Roman numerals I–VI; the
stack-specific principles (`Idempotent Deploys` for `web-saas`,
`Composable Default Exit Codes` for `cli-tool`, `Stable API Surface`
for `library`) appear under VII.

## Referenced Scripts

- `scripts/lifecycle/constitution-author.sh` — the FR-3 driver invoked
  by this command. Owns argument parsing, stack validation, starter
  load, grilling-protocol flow, placeholder substitution, editor
  hand-off, lint gating, write, marker, JSONL event, and dual-write
  fragment.
- `scripts/verify/constitution-shape-lint.sh` — the FR-5 4-assertion
  shape lint applied at step 6.
- `scripts/verify/standalone-gate.sh` — the FR-6 / Principle XVI
  distribution-surface gate (subcommand-dispatched; `constitution`
  is the v1 surface).
- `scripts/lifecycle/grilling-shell.sh` — sourced at step 3; exposes
  `ask_one <question> <recommendation> [<context-file>]` (CON-5
  sequential; recommendation-not-interrogation framing).
- `scripts/util/jsonl-event-emitter.sh` — invoked at step 9 to emit
  one `constitution_authored` record (FR-22 closed enum).
- `scripts/util/start-state-markers.sh` — invoked at step 8 to write
  the `constitution-authored` marker (FR-20 / CON-6).
- `scripts/util/dual-write-runtime-md.sh` — invoked at step 10 to
  append the recent-changes fragment (FR-21 inheritance from M014).

## Referenced Templates

- `templates/constitution-starters/web-saas.md`
- `templates/constitution-starters/cli-tool.md`
- `templates/constitution-starters/library.md`

## References

- `references/constitution-starter-format.md` — the v1 starter format
  contract, the closed stack list, and the `#Q-2` expansion criterion.
- `references/m033-fr21-dual-write-convention.md` — the FR-21
  call-site SSOT consumed at step 10.
