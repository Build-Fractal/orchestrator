---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M033"
goal: "Land the M033 cross-phase shared infrastructure that P03/P04/P05 calling commands inherit — `scripts/lifecycle/grilling-shell.sh` (FR-17 uniform `ask_one <question> <recommendation> [<context-file>]` API; sequential-never-batched per CON-5; recommendation-not-interrogation framing; code-first speculation cap; MIT-007 live contradiction-detection wiring activated whenever `[<context-file>]` is passed, NOT only on resume-from-interruption); the glossary inline-update writer (FR-18 — alphabetized-insert; immediate-not-batched; one-line definition + at most two-line elaboration; M033 is the primary writer per Knowledge-Layer Boundary, M032/spec 035 owns the path convention but M033/P02 ships against a fixture-local glossary path under the paired-stub-mode escape valve documented in the P02 roadmap entry's Blocked-by clause); the JSONL observability emitter library at `scripts/util/jsonl-event-emitter.sh` (FR-22 — 11 documented event types, schema version 1.0, schema-conformance verifier); the partial-state markers convention at `scripts/util/start-state-markers.sh` (FR-20 — `.orchestrator/start-state/<sub-flow-name>.complete` marker write/read primitives plus `start.sh` extension to detect markers and resume from the last completed sub-flow rather than re-running US-1 from scratch per CON-6); the FR-21 dual-write Recent Changes inheritance via `scripts/util/dual-write-runtime-md.sh` invocations from M033 commands (P02 establishes the calling convention; P03/P04/P05 commands actually fire it); SC-11 + SC-12 + SC-13 acceptance scripts; and the `m033-p02-*` phase-suite + scope-guard verifiers."
demo_sentence: "An operator runs `source scripts/lifecycle/grilling-shell.sh && PROJECT_DIR=/tmp/m033p02-demo ask_one 'What stack are you using?' 'web-saas' '/tmp/m033p02-demo/.orchestrator/intake/partial-answers.yml'` and observes (a) the recommendation `web-saas` named first, (b) the question text presented sequentially (no batched bullet list of next questions), (c) the prompt awaiting one keystroke (`Y/y/<enter>` accepts the recommendation; `n/N` requests an alternative; any other key requests an explicit answer); when the operator's answer resolves a domain term, observes the term + one-line definition appended alphabetized to `/tmp/m033p02-demo/wiki/glossary.md` immediately (not batched); when `[<context-file>]` already contains a contradicting prior answer, observes the contradiction surfaced live before `ask_one` returns success per MIT-007; runs `bash scripts/util/jsonl-event-emitter.sh emit ideation_completed '{\"project_dir\":\"/tmp/x\"}'` and observes a single JSONL record appended to `.orchestrator/execution-log.jsonl` with schema version 1.0 and the canonical event-type set (validated by `tools/verify/m033-p02-jsonl-event-schema.sh`); runs `bash scripts/util/start-state-markers.sh write ideation /tmp/m033p02-demo` and observes `/tmp/m033p02-demo/.orchestrator/start-state/ideation.complete` written; re-runs `bash scripts/lifecycle/start.sh --project-dir /tmp/m033p02-demo --yes` after the marker is in place and observes the partial-state-resume diagnostic `start-state: resuming from <next sub-flow>` rather than re-running ideation from scratch; runs `bash tests/m033-acceptance/p07-grilling-shell.sh` (SC-11), `bash tests/m033-acceptance/p07-resume-on-partial-state.sh` (SC-12), `bash tests/m033-acceptance/p07-observability-records.sh` (SC-13), and observes exit 0 from each; runs `bash tools/verify/m033-p02-phase-suite.sh` and observes `SUMMARY: m033-p02-phase-suite.sh pass=N fail=0`."
risk: "high"
depends_on: ["P01"]
---

## Must-Haves

<!-- All Check commands use single-script-file shape per AD-19.
     Project-owned slug-bearing verifiers live under tools/verify/.
     Verifier scripts are co-authored alongside their corresponding
     artifact within the SAME task (plan-time discipline rule 2).
     Namespacing: `m033-p02-*` prefix avoids collision with M030/M031/M032
     and with M033/P01's `m033-p01-*` namespace.

     Per the P01 plan-shape finding (P01-SUMMARY.md "Plan-shape finding"):
     artifact-list bullets in `## Must-Haves` MUST NOT use the bare-backtick
     shape — the auto-loop --step=V parser eval's bare-backtick bullets as
     commands. Each Truths bullet is labeled as a sentence with backticks
     embedded; each Artifacts bullet uses the `path (constraints) — create`
     shape. Verification commands use fenced bash blocks. -->

### Truths

- `scripts/lifecycle/grilling-shell.sh` exists and is sourceable by other bash scripts. It exposes a single uniform public function `ask_one <question> <recommendation> [<context-file>]` per FR-17. The function presents one question at a time (sequential never batched per CON-5), names the recommendation first (recommendation-not-interrogation framing per the brief's Adopted External Pattern rule 4), accepts `Y/y/<enter>` as a one-keystroke recommendation accept, accepts `n/N` to request an alternative answer (read via `read -r`), and accepts any other input as an explicit operator-supplied answer. The resolved answer is echoed to stdout on a single line prefixed `answer:` (the load-bearing token for downstream tests). The module MUST run on bash 3.2 (MEM001 — no `declare -A`, no process substitution, no `$(...)` containing pipes). The module MUST NOT batch questions — calling commands invoking `ask_one` in a loop without awaiting answers is a CON-5 violation.
  - Check: `bash tools/verify/m033-p02-grilling-shell-shape.sh`

- `scripts/lifecycle/grilling-shell.sh` implements the MIT-007 live contradiction-detection wiring per FR-10's amendment. When `ask_one` is invoked with a non-empty `[<context-file>]` argument pointing at a YAML accumulator (e.g., a `partial-answers.yml` file with `<question-key>: <answer>` records), the function MUST scan the file for contradictions against the new question's resolved answer BEFORE returning success. A contradiction is defined as the resolved answer containing a token that is in a closed contradiction-table opposite to a token in any prior recorded answer (e.g., `target-user: enterprise` answered after `target-user: consumer` in the same file; the table is documented inline in the shell module under a fenced `# >>> contradiction-pairs >>>` block for SSOT discoverability). On contradiction detection, the function emits `contradiction:` to stdout naming the conflicting prior answer + the new answer, asks the operator to reconcile (re-prompt or accept-with-attestation), and only returns success after reconciliation. **The contradiction-detection path is the load-bearing seam between FR-10 and FR-17 (MIT-007); calling commands inherit this wiring by passing the accumulator path on every `ask_one` invocation, NOT only on resume-from-interruption.**
  - Check: `bash tools/verify/m033-p02-grilling-shell-contradiction-detection.sh`

- `scripts/lifecycle/grilling-shell.sh` implements the FR-18 glossary inline-update writer as a private helper invoked from `ask_one` whenever the resolved answer matches the documented domain-term-resolution shape (operator answers a question whose key appears in a closed `glossary-trigger` set documented inline in the shell module under a fenced `# >>> glossary-triggers >>>` block). When triggered, the helper writes `<term>: <one-line definition>` (with at most a two-line elaboration on continuation lines per spec 035 US-6 / spec 035 CON-6 format invariant) immediately to `<PROJECT_DIR>/wiki/glossary.md` (alphabetized-insert; preserves existing entries; never full-file rewrite). The path `<PROJECT_DIR>/wiki/glossary.md` is the M032/spec 035 FR-15 SSOT path under the paired-stub-mode escape valve: in M033/P02..P04 (before M032/P02 closes), the writer creates the `wiki/` directory and `glossary.md` file as needed (fixture-local path); in M033/P05 (after M032/P02 closes) the same path is the real M032-owned surface (no code change required, only environmental availability of the surrounding mkdocs scaffolding). The write MUST be idempotent on identical input (re-resolving the same term to the same definition produces no diff) and immediate-not-batched (writes happen inside the `ask_one` invocation, not at session end).
  - Check: `bash tools/verify/m033-p02-glossary-writer-shape.sh`

- `scripts/util/jsonl-event-emitter.sh` exists, is executable, and exposes a single primary entry point `bash scripts/util/jsonl-event-emitter.sh emit <event_type> <payload_json>` per FR-22. The valid `<event_type>` values are exactly the 11 documented event types: `start_branch_detected`, `start_init_invoked`, `constitution_authored`, `ingest_codebase_completed`, `materials_intake_completed`, `ideation_completed`, `migrate_routed`, `customblock_drafted`, `wiki_init_invoked`, `github_init_invoked`, `friendly_tester_report_validated`. Unknown event types exit non-zero with the closed enum echoed to stderr. Each emitted record is a single line of valid JSON appended to `<PROJECT_DIR>/.orchestrator/execution-log.jsonl` (created if absent) containing at minimum: `schema_version: "1.0"`, `event_type: <documented type>`, `timestamp: <ISO 8601 UTC per MEM008>`, `payload: <pass-through of payload_json>`. The JSONL append is atomic (single `>>` redirect of a single pre-formatted line; no partial-record possibility on Ctrl+C mid-write per Constitution VI State On Disk Is Truth). Schema version 1.0 is fixed at this milestone; a follow-up milestone D-row is required to bump the version (M020 D024 reversibility-clause precedent).
  - Check: `bash tools/verify/m033-p02-jsonl-event-schema.sh`

- `scripts/util/start-state-markers.sh` exists, is executable, and exposes the marker-file primitives per FR-20 / CON-6: `bash scripts/util/start-state-markers.sh write <sub-flow-name> <project-dir>` (writes `<project-dir>/.orchestrator/start-state/<sub-flow-name>.complete` containing the ISO 8601 UTC timestamp of marker write); `bash scripts/util/start-state-markers.sh read <project-dir>` (lists all completed sub-flow names, one per line, sorted by completion order via embedded timestamp); `bash scripts/util/start-state-markers.sh next <project-dir>` (prints the next sub-flow to run given the documented sub-flow-execution-order — `init-invoked, ideation, materials-intake, ingest-codebase, migrate-routed, constitution-authored, customblock-drafted` — or empty string if all sub-flows are marked complete); `bash scripts/util/start-state-markers.sh clear <sub-flow-name> <project-dir>` (removes a single marker, used by tests to reset state). The closed sub-flow-name enum is documented inline in the script under a fenced `# >>> subflow-names >>>` block (SSOT). Unknown sub-flow names exit non-zero with the closed enum echoed.
  - Check: `bash tools/verify/m033-p02-start-state-markers-shape.sh`

- `scripts/lifecycle/start.sh` is extended (additive — preserves all P01 behavior) to detect partial-state markers via `scripts/util/start-state-markers.sh read <project-dir>` after init invocation but before sub-flow dispatch, and to skip-and-emit-diagnostic when a marker for the dispatched sub-flow is already present. The diagnostic line `start-state: resuming from <next sub-flow>` is the load-bearing token SC-12 greps for. The detection is gated by a `--no-resume` flag that operators can pass to force re-execution of completed sub-flows (escape valve; default behavior is resume-on-partial-state per CON-6). The P01 sub-flow stubs themselves do not yet write markers (the marker-write happens in P03/P04/P05 when sub-flow real implementations land); P02's start.sh extension is the read-side of the marker contract, ensuring the framing is in place when the write-side lands.
  - Check: `bash tools/verify/m033-p02-start-sh-resume-extension.sh`

- The FR-21 dual-write Recent Changes inheritance is exercised by P02's deliverable scripts. `scripts/lifecycle/grilling-shell.sh`, `scripts/util/jsonl-event-emitter.sh`, and `scripts/util/start-state-markers.sh` are NOT calling commands themselves (they are sourced/invoked libraries). The dual-write contract (`scripts/util/dual-write-runtime-md.sh`) is invoked by command-shaped surfaces (FR-3 / FR-7 / FR-9 / FR-10 / FR-13 — those commands are P03/P04/P05 deliverables). P02's contribution to FR-21 is therefore the **convention documentation**: a fenced `# >>> fr-21-dual-write-callsites >>>` block in `references/m033-fr21-dual-write-convention.md` (SSOT for P03/P04/P05) listing the call-site shape (`bash scripts/util/dual-write-runtime-md.sh append <one-line-fragment>`), the per-command fragment templates (one per command from FR-3 / FR-7 / FR-9 / FR-10 / FR-13), and the `dual_write_agents: false` config-respecting precedent. The convention MUST be discoverable by P03/P04/P05 dispatched agents via grep-friendly tokens (`fr-21-dual-write-callsites`, `dual-write-runtime-md.sh`, `dual_write_agents`). The verifier asserts the convention reference exists with the documented tokens.
  - Check: `bash tools/verify/m033-p02-fr21-convention-shape.sh`

- `tests/m033-acceptance/p07-grilling-shell.sh` exists, is executable, and exits 0 (SC-11). The script: (a) sources `scripts/lifecycle/grilling-shell.sh` in a sandboxed shell; (b) invokes `ask_one 'What stack?' 'web-saas' /tmp/<staging>/partial-answers.yml` against simulated stdin (`printf 'y\n'`) and asserts the `answer:` line appears with the recommendation token AND the `recommendation:` line preceded the `answer:` line (recommendation-not-interrogation ordering); (c) invokes `ask_one` with a `[<context-file>]` containing a contradiction (`target-user: consumer` pre-recorded; new question resolves to `target-user: enterprise`) and asserts the `contradiction:` token appears on stdout BEFORE `answer:` is emitted; (d) invokes `ask_one` with a glossary-triggering question (e.g., `What is the project's primary deployment target?` answered `Cloudflare Workers`) and asserts `<staging>/wiki/glossary.md` is created and contains the alphabetized-inserted entry; (e) re-invokes the same glossary-triggering call with the same answer and asserts no duplicate entry is written (idempotent on identical input). Cleanup of staging directories is mandatory.
  - Check: `bash tools/verify/m033-p02-acceptance-shape-sc11.sh`

- `tests/m033-acceptance/p07-resume-on-partial-state.sh` exists, is executable, and exits 0 (SC-12). The script: (a) creates a staging project under `mktemp -d`; (b) writes a synthetic `init-invoked.complete` marker via `bash scripts/util/start-state-markers.sh write init-invoked <staging>`; (c) writes an `ideation.complete` marker via the same primitive; (d) runs `bash scripts/lifecycle/start.sh --project-dir <staging> --yes` and asserts the `start-state: resuming from <next sub-flow>` diagnostic appears AND the next sub-flow name printed matches the documented next-sub-flow ordering (`materials-intake` after `ideation`); (e) runs the same command with `--no-resume` and asserts the resume diagnostic does NOT fire AND the per-branch sub-flow stub fires from US-1 as in P01 baseline behavior; (f) clears markers and re-runs to assert default no-marker behavior matches P01 baseline (no resume diagnostic, full sub-flow dispatch). Cleanup mandatory.
  - Check: `bash tools/verify/m033-p02-acceptance-shape-sc12.sh`

- `tests/m033-acceptance/p07-observability-records.sh` exists, is executable, and exits 0 (SC-13). The script: (a) creates a staging project under `mktemp -d`; (b) for each of the 11 documented event types, invokes `bash scripts/util/jsonl-event-emitter.sh emit <event_type> '{"project_dir":"<staging>","test":"sc13"}'` and asserts a single JSONL line is appended to `<staging>/.orchestrator/execution-log.jsonl`; (c) parses every appended line and asserts the JSON contains `schema_version: "1.0"`, `event_type` matching the dispatched type, `timestamp` matching the ISO 8601 UTC pattern (`YYYY-MM-DDTHH:MM:SSZ`), and `payload` containing the pass-through fields; (d) asserts an unknown event type (e.g., `wiki_published`) exits non-zero with the closed enum echoed to stderr; (e) asserts the schema version literal `"1.0"` appears in the emitter source as a fixed token (catches accidental schema-version drift via grep). Cleanup mandatory.
  - Check: `bash tools/verify/m033-p02-acceptance-shape-sc13.sh`

- `tools/verify/m033-p02-phase-suite.sh` exists, is executable, invokes every P02 verifier in dependency order, exits 0 iff every sub-gate passes, and emits a single line `SUMMARY: m033-p02-phase-suite.sh pass=N fail=M` before exit. The suite chains, in order: `m033-p02-grilling-shell-shape.sh`, `m033-p02-grilling-shell-contradiction-detection.sh`, `m033-p02-glossary-writer-shape.sh`, `m033-p02-jsonl-event-schema.sh`, `m033-p02-start-state-markers-shape.sh`, `m033-p02-start-sh-resume-extension.sh`, `m033-p02-fr21-convention-shape.sh`, `m033-p02-acceptance-shape-sc11.sh`, `m033-p02-acceptance-shape-sc12.sh`, `m033-p02-acceptance-shape-sc13.sh`. Ten sub-gates plus the suite line.
  - Check: `bash tools/verify/m033-p02-phase-suite.sh`

- The SC-13 / scope-guard invariant holds for the P02 diff: P02 modifies/creates only files declared in this phase's "Files Likely Touched" list. None of `scripts/lifecycle/constitution-author.sh`, `scripts/lifecycle/ingest-codebase.sh`, `scripts/lifecycle/materials-intake.sh`, `scripts/lifecycle/ideation.sh`, `scripts/lifecycle/customblock-draft.sh`, `templates/constitution-starters/**`, `commands/constitution.md`, `commands/ingest-codebase.md`, `commands/materials-intake.md`, `commands/ideation.md`, `commands/customblock-draft.md`, `references/constitution-starter-format.md`, `references/customblock-format.md` is touched (those belong to P03–P05). The `wiki/` writes are confined to fixture-local staging directories under `mktemp -d` in tests; the M033 repo's own `wiki/` is NOT modified.
  - Check: `bash tools/verify/m033-p02-scope-guard.sh`

### Artifacts

- Module: `scripts/lifecycle/grilling-shell.sh` (min 200 lines, contains "ask_one", contains "sequential", contains "recommendation:", contains "answer:", contains "contradiction:", contains "context-file", contains "MIT-007", contains "CON-5", contains "glossary-triggers", contains "contradiction-pairs", contains "wiki/glossary.md", bash 3.2 compatible) — create
- Library: `scripts/util/jsonl-event-emitter.sh` (min 80 lines, contains "schema_version", contains "1.0", contains "emit", contains "start_branch_detected", contains "start_init_invoked", contains "constitution_authored", contains "ingest_codebase_completed", contains "materials_intake_completed", contains "ideation_completed", contains "migrate_routed", contains "customblock_drafted", contains "wiki_init_invoked", contains "github_init_invoked", contains "friendly_tester_report_validated", contains "execution-log.jsonl") — create
- Library: `scripts/util/start-state-markers.sh` (min 80 lines, contains "write", contains "read", contains "next", contains "clear", contains "subflow-names", contains "start-state", contains ".complete", contains "init-invoked", contains "ideation", contains "materials-intake", contains "ingest-codebase", contains "migrate-routed", contains "constitution-authored", contains "customblock-drafted") — create
- Reference: `references/m033-fr21-dual-write-convention.md` (min 60 lines, contains "fr-21-dual-write-callsites", contains "dual-write-runtime-md.sh", contains "dual_write_agents", contains "constitution-authored", contains "ingest-codebase", contains "materials-intake", contains "ideation", contains "customblock-draft", contains "Recent Changes") — create
- Driver extension: `scripts/lifecycle/start.sh` (extend in place — adds resume-on-partial-state read of `.orchestrator/start-state/`, `--no-resume` flag, `start-state: resuming from` diagnostic; preserves all P01 behavior; min 250 lines after extension, contains "start-state:", contains "--no-resume", contains "resuming from", contains "start-state-markers.sh") — modify
- Acceptance script: `tests/m033-acceptance/p07-grilling-shell.sh` (min 100 lines, contains "SC-11", contains "FR-17", contains "FR-18", contains "ask_one", contains "recommendation:", contains "answer:", contains "contradiction:", contains "glossary.md") — create
- Acceptance script: `tests/m033-acceptance/p07-resume-on-partial-state.sh` (min 80 lines, contains "SC-12", contains "FR-20", contains "start-state-markers.sh", contains "resuming from", contains "--no-resume", contains "init-invoked.complete", contains "ideation.complete") — create
- Acceptance script: `tests/m033-acceptance/p07-observability-records.sh` (min 100 lines, contains "SC-13", contains "FR-22", contains "schema_version", contains "1.0", contains "execution-log.jsonl", contains "start_branch_detected", contains "ideation_completed", contains "friendly_tester_report_validated") — create
- Verifier: `tools/verify/m033-p02-grilling-shell-shape.sh` (min 30 lines, contains "scripts/lifecycle/grilling-shell.sh", contains "ask_one", contains "recommendation:", contains "answer:", contains "CON-5") — create
- Verifier: `tools/verify/m033-p02-grilling-shell-contradiction-detection.sh` (min 30 lines, contains "scripts/lifecycle/grilling-shell.sh", contains "MIT-007", contains "contradiction:", contains "context-file") — create
- Verifier: `tools/verify/m033-p02-glossary-writer-shape.sh` (min 30 lines, contains "scripts/lifecycle/grilling-shell.sh", contains "glossary.md", contains "alphabetized", contains "FR-18") — create
- Verifier: `tools/verify/m033-p02-jsonl-event-schema.sh` (min 30 lines, contains "scripts/util/jsonl-event-emitter.sh", contains "schema_version", contains "1.0", contains "start_branch_detected", contains "friendly_tester_report_validated") — create
- Verifier: `tools/verify/m033-p02-start-state-markers-shape.sh` (min 30 lines, contains "scripts/util/start-state-markers.sh", contains "write", contains "read", contains "next", contains "clear", contains "subflow-names") — create
- Verifier: `tools/verify/m033-p02-start-sh-resume-extension.sh` (min 30 lines, contains "scripts/lifecycle/start.sh", contains "start-state:", contains "resuming from", contains "--no-resume") — create
- Verifier: `tools/verify/m033-p02-fr21-convention-shape.sh` (min 25 lines, contains "references/m033-fr21-dual-write-convention.md", contains "fr-21-dual-write-callsites", contains "dual_write_agents") — create
- Verifier: `tools/verify/m033-p02-acceptance-shape-sc11.sh` (min 25 lines, contains "p07-grilling-shell.sh", contains "SC-11") — create
- Verifier: `tools/verify/m033-p02-acceptance-shape-sc12.sh` (min 25 lines, contains "p07-resume-on-partial-state.sh", contains "SC-12") — create
- Verifier: `tools/verify/m033-p02-acceptance-shape-sc13.sh` (min 25 lines, contains "p07-observability-records.sh", contains "SC-13") — create
- Verifier: `tools/verify/m033-p02-phase-suite.sh` (min 50 lines, contains "SUMMARY:", contains "m033-p02-grilling-shell-shape", contains "m033-p02-jsonl-event-schema", contains "m033-p02-start-state-markers-shape", contains "m033-p02-acceptance-shape-sc11", contains "m033-p02-acceptance-shape-sc12", contains "m033-p02-acceptance-shape-sc13", contains "m033-p02-phase-suite") — create
- Verifier: `tools/verify/m033-p02-scope-guard.sh` (min 35 lines, contains "scripts/lifecycle/constitution-author.sh", contains "scripts/lifecycle/ingest-codebase.sh", contains "scripts/lifecycle/materials-intake.sh", contains "scripts/lifecycle/ideation.sh", contains "scripts/lifecycle/customblock-draft.sh", contains "templates/constitution-starters", contains "SC-13") — create

### Key Links

- `scripts/lifecycle/grilling-shell.sh` → `scripts/util/jsonl-event-emitter.sh` (the shell may emit observability records during contradiction-detection or glossary-update events; documented call-site convention)
- `scripts/lifecycle/grilling-shell.sh` → `<PROJECT_DIR>/wiki/glossary.md` (FR-18 inline-update writer target — fixture-local under stub-mode, M032-owned in real-mode)
- `scripts/util/jsonl-event-emitter.sh` → `<PROJECT_DIR>/.orchestrator/execution-log.jsonl` (FR-22 append target)
- `scripts/util/start-state-markers.sh` → `<PROJECT_DIR>/.orchestrator/start-state/<sub-flow>.complete` (FR-20 marker file convention)
- `scripts/lifecycle/start.sh` → `scripts/util/start-state-markers.sh` (start.sh extension reads markers via the `read` and `next` primitives to determine resume point)
- `references/m033-fr21-dual-write-convention.md` → `scripts/util/dual-write-runtime-md.sh` (P03/P04/P05 calling commands invoke the dual-write helper per the documented call-site shape)
- `tests/m033-acceptance/p07-grilling-shell.sh` → `scripts/lifecycle/grilling-shell.sh` (SC-11 sources and exercises the module)
- `tests/m033-acceptance/p07-resume-on-partial-state.sh` → `scripts/util/start-state-markers.sh` (SC-12 writes markers via the primitive then exercises start.sh resume)
- `tests/m033-acceptance/p07-resume-on-partial-state.sh` → `scripts/lifecycle/start.sh` (SC-12 invokes start.sh with markers in place)
- `tests/m033-acceptance/p07-observability-records.sh` → `scripts/util/jsonl-event-emitter.sh` (SC-13 emits all 11 event types and validates schema)
- `tools/verify/m033-p02-phase-suite.sh` → `tools/verify/m033-p02-acceptance-shape-sc11.sh` (suite chains the SC-11 wrapper)
- `tools/verify/m033-p02-phase-suite.sh` → `tools/verify/m033-p02-acceptance-shape-sc12.sh` (suite chains the SC-12 wrapper)
- `tools/verify/m033-p02-phase-suite.sh` → `tools/verify/m033-p02-acceptance-shape-sc13.sh` (suite chains the SC-13 wrapper)

## Tasks

### T01: `scripts/util/jsonl-event-emitter.sh` + schema verifier (FR-22)

See `tasks/T01-jsonl-event-emitter.md`.

### T02: `scripts/util/start-state-markers.sh` + start.sh resume-extension + SC-12 acceptance (FR-20 / CON-6)

See `tasks/T02-start-state-markers-and-resume.md`.

### T03: `scripts/lifecycle/grilling-shell.sh` core module — `ask_one` API + recommendation-not-interrogation (FR-17 / CON-5)

See `tasks/T03-grilling-shell-core.md`.

### T04: Grilling-shell glossary inline-update writer + MIT-007 contradiction-detection wiring + SC-11 acceptance (FR-17 / FR-18 / MIT-007)

See `tasks/T04-grilling-shell-glossary-and-contradiction.md`.

### T05: FR-21 dual-write convention reference + SC-13 acceptance + `m033-p02-*` phase-suite + scope-guard

See `tasks/T05-fr21-convention-and-phase-suite.md`.

## Task Dependencies

```
T01 ──┐
T02 ──┼──► T04 ──► T05
T03 ──┘
```

T01 (`jsonl-event-emitter.sh`) and T02 (`start-state-markers.sh` + start.sh resume-extension) and T03 (`grilling-shell.sh` core) have no inter-task dependencies and can run in parallel — each ships an independent library/extension and its shape verifiers. T04 (grilling-shell glossary writer + MIT-007 contradiction-detection wiring + SC-11 acceptance) depends on T03 (extends the grilling-shell module) and may transitively depend on T01 (the glossary-update-event observability emit may use the FR-22 emitter — documented as a call-site, not a hard dep). T05 (FR-21 convention reference + SC-13 acceptance script + phase-suite + scope-guard) depends on T01 (SC-13 exercises the FR-22 emitter), T02 (scope-guard checks resume-extension boundaries), T03 + T04 (phase-suite chains all earlier verifiers). The phase-suite is last by construction.

## Files Likely Touched

- `scripts/lifecycle/grilling-shell.sh` (create, T03 + T04)
- `scripts/util/jsonl-event-emitter.sh` (create, T01)
- `scripts/util/start-state-markers.sh` (create, T02)
- `scripts/lifecycle/start.sh` (modify in place — additive resume-extension, T02)
- `references/m033-fr21-dual-write-convention.md` (create, T05)
- `tests/m033-acceptance/p07-grilling-shell.sh` (create, T04)
- `tests/m033-acceptance/p07-resume-on-partial-state.sh` (create, T02)
- `tests/m033-acceptance/p07-observability-records.sh` (create, T05)
- `tools/verify/m033-p02-grilling-shell-shape.sh` (create, T03)
- `tools/verify/m033-p02-grilling-shell-contradiction-detection.sh` (create, T04)
- `tools/verify/m033-p02-glossary-writer-shape.sh` (create, T04)
- `tools/verify/m033-p02-jsonl-event-schema.sh` (create, T01)
- `tools/verify/m033-p02-start-state-markers-shape.sh` (create, T02)
- `tools/verify/m033-p02-start-sh-resume-extension.sh` (create, T02)
- `tools/verify/m033-p02-fr21-convention-shape.sh` (create, T05)
- `tools/verify/m033-p02-acceptance-shape-sc11.sh` (create, T04)
- `tools/verify/m033-p02-acceptance-shape-sc12.sh` (create, T02)
- `tools/verify/m033-p02-acceptance-shape-sc13.sh` (create, T05)
- `tools/verify/m033-p02-phase-suite.sh` (create, T05)
- `tools/verify/m033-p02-scope-guard.sh` (create, T05)
