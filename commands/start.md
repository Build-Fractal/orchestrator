---
description: "orchestrator:start — warm conversational front door for any new orchestrator-managed project. Detects which of four starting states a user is in (greenfield-empty / greenfield-with-materials / existing-codebase / migrating), invokes init, and routes to the per-branch sub-flow."
---

# orchestrator:start

`orchestrator:start` is the warm conversational front door for any new
orchestrator-managed project. It is the friendly first contact a user has
with the orchestrator: it probes the project directory, classifies the
user's posture into one of four branches, invokes the underlying
`init-project.sh` exactly once, and dispatches to the appropriate
per-branch sub-flow.

The four branches are a closed enum:

- `greenfield-empty` — fresh project, no code, no curatorial materials.
- `greenfield-with-materials` — curatorial materials (briefs, plans,
  decisions, handoffs, audits) but no source code.
- `existing-codebase` — project with source code already present.
- `migrating` — project carries sibling-tool artifacts (`.gsd/`,
  `.gsd2/`, `.specify/`).

Branch detection follows deterministic ordered rules documented in
`references/branch-detection.md` (the SSOT). Detection order is
non-negotiable — `migrating` always wins over `existing-codebase` per
US-1 AS-4.

## Prerequisites

- The project directory exists and is readable.
- `bash` 3.2+ on PATH.
- `scripts/lifecycle/init-project.sh` exists in the orchestrator bundle.
- `references/branch-detection.md` exists (consulted at runtime as
  documentation; pattern strings are also embedded in the driver).

## State Check

`orchestrator:start` is a launch-pad command. It runs without any prior
orchestrator state — its job is to bring a project from "no orchestrator
state" to "branch-routed sub-flow ready to run". The driver tolerates
re-invocation: if `<project-dir>/.orchestrator/config.yml` already
exists, init is skipped and a `init already complete, proceeding to
branch sub-flow` diagnostic is emitted before the branch sub-flow
dispatch.

## Core Workflow

The driver is `scripts/lifecycle/start.sh`. The five-step pipeline:

1. **Parse flags.** Accept `--project-dir <path>` (default `pwd`),
   `--yes` (auto-accept defaults / suppress disambiguation prompts),
   `--branch <name>` (operator override of detection — closed enum
   `greenfield-empty | greenfield-with-materials | existing-codebase |
   migrating`), `--stack <name>` (forwarded only — sub-flow stubs ignore
   it in P01; the recommendation is derived at sub-flow time per FR-1 /
   MIT-004), and `--dry-run` (boolean; forwarded to sub-flows). Unknown
   flags exit non-zero with a usage diagnostic naming the unknown flag.

2. **Probe filesystem for branch signals per FR-2.** The driver
   implements the four ordered detection rules from
   `references/branch-detection.md`. The rules fire in order — first
   match wins:

   1. `migrating` — any of `<project-dir>/.gsd/`, `.gsd2/`, or
      `.specify/` directories present.
   2. `greenfield-with-materials` — three or more `*BRIEF*.md`,
      `*PLAN*.md`, `*DECISIONS*.md`, `*HANDOFF*.md`, `*AUDIT*.md` files
      at project root AND no `src/` directory.
   3. `existing-codebase` — `src/` exists OR ten or more source files at
      project root (extensions `.js .ts .jsx .tsx .py .rs .go .rb .java
      .kt .swift .cs .cpp .c .h`) OR `.git/` with at least one commit.
   4. `greenfield-empty` — fallback when none of rules 1–3 fire.

3. **Invoke `bash scripts/lifecycle/init-project.sh --project-dir
   <path>` exactly once.** If `<path>/.orchestrator/config.yml` already
   exists, init invocation is skipped and `init already complete,
   proceeding to branch sub-flow` is printed to stdout (idempotency per
   Edge Case `init already ran`).

4. **Disambiguate ambiguous signals via grilling-protocol-shaped
   question per US-1 AS-5.** Two ambiguity cases fire the prompt when
   `--yes` is not set:

   - **Case A** (rule 1 + rule 3 both match): a sibling-tool artifact
     directory and source code coexist. Recommendation `migrating`
     (rule-1 wins by ordering); operator may override to
     `existing-codebase` if the sibling-tool artifacts are stale.
   - **Case B** (MIT-006 / RISK-006): rule 3 fires solely because
     `.git/` has at least one commit, but the project has at most nine
     source files at root and no prior-tooling artifacts (typically a
     fresh `git init` with a `README.md` commit). Recommendation
     `greenfield-empty`; operator may override to `existing-codebase`.

   The prompt embeds the literal tokens `disambiguation:`,
   `recommended:`, and (for Case B) `MIT-006`. One-keystroke accept:
   `Y/y/<enter>` accepts the recommendation, `n/N` picks the
   alternative, anything else prints `re-invoke with --branch <name>`
   and exits non-zero.

5. **Dispatch to per-branch sub-flow stub.** P01 ships deliberately
   vacuous stubs. Each stub prints a single `would-execute: <stub-name>
   --project-dir <path>` line to stdout and exits 0. The four stubs:

   - `ideation-stub` — for `greenfield-empty`.
   - `materials-intake-stub` — for `greenfield-with-materials`.
   - `ingest-codebase-stub` — for `existing-codebase`.
   - `migrate-routing-stub` — for `migrating` (also includes `--from
     <DETECTED_FROM>` when the prior-tool flavor is identifiable).

   P02–P05 replace these stubs with real sub-flow logic. The FR-1
   contract (a `branch:` line followed by a `would-execute:` line and
   exit 0) is the surface SC-1 verifies.

## Output

- stdout: `branch: <name>` line, then `would-execute: <stub-name>
  --project-dir <path>` line, exit 0.
- stderr (informational): `branch-override: detected=<X>
  overridden=<Y>` if `--branch` differs from detection;
  `init already complete, proceeding to branch sub-flow` if init was
  skipped (this also lands on stdout per the load-bearing token
  contract).

## Idempotency

Running `orchestrator:start` twice in a row against the same project
directory invokes init exactly once total (the second invocation finds
`<path>/.orchestrator/config.yml` and emits `init already complete,
proceeding to branch sub-flow`). The branch sub-flow stub dispatches on
each invocation — the idempotency contract is on init, not on the stub
dispatch.

## Error Handling

- Unknown flag → exit 2 with `usage: start.sh [--project-dir PATH]
  [--yes] [--branch NAME] [--stack NAME] [--dry-run]`.
- Operator-supplied unknown `--branch` value → exit non-zero with the
  closed enum echoed to stderr.
- Branch detection ambiguity under `--yes` → resolves per documented
  ordering rules (rule-1 wins for Case A; detected `existing-codebase`
  is preserved for Case B — operator must use `--branch greenfield-empty`
  to override).
- Disambiguation prompt rejected with non-`Y/n` input → exit non-zero
  with `re-invoke with --branch <name>` diagnostic.

## --auto-chain Flag (FR-10)

<!-- M029 / FR-10 — entry-chain walker with marker-file resume. -->

The `--auto-chain` flag (OFF by default) walks the start-time entry
chain one stage at a time, in this fixed order:

    evaluate -> discuss -> roadmap -> plan-phase

### Marker files

After each successful stage, the chain-driver writes a single-line
marker to `.orchestrator/start-state/<stage>.complete` containing the
ISO-8601 timestamp and the stage name. Example marker contents:

    2026-05-06T01:30:00Z evaluate

On re-invocation, the chain-driver skips any stage whose marker
already exists. The four stages compose in order; `evaluate.complete`
must exist before `discuss` runs, and so on.

### #Q-3 — Failed stages leave the marker absent

When a stage fails (its underlying skill exits non-zero), the
chain-driver leaves the `.complete` marker absent. **No `.failed`
marker is written.** Re-running `orchestrator:start --auto-chain`
re-executes the failed stage. Failure status surfaces via
`orchestrator:status`, which already reads the start-state directory.

### Between-stage gates (AD-3 priority order — see `commands/auto.md`)

The chain-driver honours the same non-interactive policy as the FR-9
preflight (AD-3):

1. `--yes` flag → proceed without prompt.
2. `auto_proceed: true` in `.orchestrator/config.yml` → proceed
   without prompt.
3. Non-TTY stdin with neither flag/config → exit non-zero with the
   byte-stable string `M029_AUTOCHAIN_NEEDS_CONFIRMATION` on stderr.
4. TTY + neither flag/config → prompt for confirmation between each
   stage.

### Idempotency

Re-invoking `orchestrator:start --auto-chain` on an already-complete
project is a no-op: every marker exists, every stage prints
`SKIP: <stage> (marker present)`, and the run exits 0 with
`START_AUTO_CHAIN_COMPLETE`.

### Composition with `--with-wiki` / `--with-github`

The chain-driver fires AFTER `--with-wiki` and `--with-github`
passthrough gates so wiki/github initialization (when requested)
lands before the entry-chain walks. This matches the existing
`start.sh` ordering invariant.

## Referenced Scripts

- `scripts/lifecycle/start.sh` — the driver implementing flags,
  detection rules, init invocation, disambiguation, and stub dispatch.
- `scripts/lifecycle/init-project.sh` — invoked exactly once per
  `orchestrator:start` run (skipped if config.yml already exists).
- `references/branch-detection.md` — the canonical SSOT for FR-2's
  branch-detection rules. The driver's pattern strings byte-match this
  document; the parity verifier
  `tools/verify/m033-p01-branch-detection-ssot-parity.sh` enforces the
  match.
