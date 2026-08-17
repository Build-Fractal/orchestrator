---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P03"
milestone: "M046"
name: "SC-1 / SC-2 / FR-3 / FR-4 verifiers + phase-suite aggregator"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01: `scripts/intake/auto-entry.sh` (unified driver, `AUTO:ROUTE` /
  `AUTO:BLOCK_AMBIGUITY` contract, six flags + `--ambiguity-mode`).
- T02: `scripts/intake/do-entry.sh` (forwarding shim + deprecation notice);
  `commands/do.md` (deprecation doc).
- T03: `commands/auto.md` (unified entry authoring).
- T04: `orchestrator-do.md` wired into the bundle.

## Description

Author the five `tools/verify/m046-p03-*.sh` verifiers named in the phase
Must-Haves. These are project-owned, milestone-slug-prefixed, and live under
`tools/verify/` (path discipline — NOT `scripts/verify/`). Each emits `PASS:` /
`FAIL:` lines and exits 0 on all-pass, 1 on any fail. Bash 3.2 compatible.

## Steps

Create each verifier below. Use `mktemp -d` scratch dirs for fixtures; invoke the
entry drivers via `bash scripts/intake/<driver>.sh` directly (NOT via
`run-probe.sh` — plan-time discipline rule 4).

### 1. `tools/verify/m046-p03-routing-fixture.sh` (SC-1 / FR-1)

Three routing sub-cases, each asserting the driver's directive line and exit 0:

- **Tier-A one-shot**: run
  `bash scripts/intake/auto-entry.sh --task "fix the typo" --dispatch-stub <noop-stub> --scratch-root <tmp>`
  (a 3-word idea → `idea`/`high` → above floor 0.7). Assert stderr contains
  `AUTO:ROUTE tier=a mode=one-shot` and does NOT contain `AUTO:BLOCK_AMBIGUITY`.
  (The `<noop-stub>` is a scratch script that `exit 0`s so the degenerate path
  completes deterministically.)
- **Tier-C loop**: create `mktemp -d` as `<fixdir>`, run
  `bash scripts/intake/auto-entry.sh "<fixdir>"`. Assert output contains
  `AUTO:ROUTE tier=c mode=loop` and exit 0.
- **Ambiguous BLOCK**: run
  `bash scripts/intake/auto-entry.sh "alpha beta gamma delta epsilon zeta eta theta"`
  (8-word idea → `idea`/`low` → below floor 0.7; default `--ambiguity-mode block`).
  Assert stderr contains `AUTO:BLOCK_AMBIGUITY` and exit 0.

Verified at plan time via `shape-detect.sh`: 3 words → idea/high (above floor);
8 words → idea/low (below floor). If the executor finds either fixture reclassified,
pick a replacement with the same above/below-floor property and note it.

### 2. `tools/verify/m046-p03-shim-parity.sh` (SC-2 — byte-equality)

Prove a `do`-shim invocation and the equivalent `auto` invocation produce
byte-identical artifacts on a fixed Tier-A degenerate fixture:

- Create a capture stub `<cap>` (scratch script) receiving positional
  `(branch, task, payload, sidecar)`; it copies `$3` (payload) and `$4` (sidecar)
  to a per-run dest dir passed via an env var (e.g. `ORCH_CAP_DEST`).
- Fixture task: a fixed short idea, e.g. `TASK="refactor the helper"` (3 words →
  idea/high → tier_a_degenerate; deterministic; NO JSONL record on this branch).
- Run via the shim, capturing stderr and artifacts:
  `ORCH_CAP_DEST=<do_art> bash scripts/intake/do-entry.sh --task "$TASK" --dispatch-stub <cap> --scratch-root <tmp1> 2> <do_stderr>`
- Run via auto directly:
  `ORCH_CAP_DEST=<auto_art> bash scripts/intake/auto-entry.sh --task "$TASK" --dispatch-stub <cap> --scratch-root <tmp2> 2> <auto_stderr>`
- Assert the captured payloads are byte-identical: `diff <do_art>/payload
  <auto_art>/payload` exit 0; same for the sidecar. **Honesty note**: FIRST
  confirm `build-context.sh --profile=quick` output is byte-deterministic across
  two immediate runs of the same input (it assembles a fixed task-plan + scope-
  filtered knowledge and — verify — writes no wall-clock line). If a single
  generation-timestamp line exists, normalize ONLY that line symmetrically on both
  sides with a documented `sed` before `diff`, and record the normalization in the
  verifier header; the load-bearing knowledge/payload body is still compared
  byte-for-byte. Do NOT weaken to substring matching.
- Assert the deprecation notice is present on `<do_stderr>` (`grep -qi deprecat`)
  and ABSENT on `<auto_stderr>` (`grep -qi deprecat` must fail).

### 3. `tools/verify/m046-p03-shim-forward.sh` (FR-3 — six-flag forward)

- Structural: assert `scripts/intake/do-entry.sh` forwards to
  `scripts/intake/auto-entry.sh` with `--ambiguity-mode prompt` and passes `"$@"`
  through (the pass-through covers all six flags by construction).
- Functional spot-check `--task`: run the shim with `--task "fix typo"` →
  assert stderr `AUTO:ROUTE tier=a mode=one-shot`.
- Functional spot-check `--no-prompt-mode` on the low-conf path: run the shim with
  an 8-word below-floor idea + `--no-prompt-mode B` → assert it does NOT hang and
  takes branch B (stderr contains `route=tier_bc`), proving the shim forwards
  `--no-prompt-mode` AND preserves the legacy do prompt path (`--ambiguity-mode
  prompt`), NOT the auto-native BLOCK.
- Assert the header documents that `--yes`, `--config`, `--dispatch-stub`,
  `--scratch-root` ride the same `"$@"` pass-through (structural).

### 4. `tools/verify/m046-p03-update-restage.sh` (FR-4)

- Assert `packaging/bundle/manifest.yml` skills list contains `orchestrator-do.md`.
- Assert `packaging/skills/orchestrator-do.md` exists and contains "deprecat".
- Assert `packaging/bundle/build-bundle.sh` contains `orchestrator-do.md` and
  `EXPECTED_SKILLS=14`.
- Assert `bash packaging/bundle/build-bundle.sh --check` exits 0 (manifest /
  expected-set / staged `skills/` are mutually consistent — the update re-stage
  path re-installs the shim skill from this consistent source of truth).
- OPTIONAL stronger proof (implementer may add, with restore): remove
  `packaging/bundle/skills/orchestrator-do.md`, run `build-bundle.sh`, assert the
  file is re-created (literal "re-stage re-installs the shim").

### 5. `tools/verify/m046-p03-phase-suite.sh` (aggregator + CON-2)

- Run the four verifiers above; count PASS/FAIL.
- CON-2 / FR-2 reuse assertion: assert `scripts/intake/auto-entry.sh` references
  `shape-detect.sh`, `route-to-dispatch.sh`, and `build-context.sh` by path, and
  does NOT contain any edit/re-implementation of `auto-loop.sh` (grep the token
  `auto-loop.sh` yields at most an inert reference, never a write). Keep this a
  simple presence/absence grep.
- Emit `SUMMARY: pass=<n> fail=<m>`; exit 0 iff all pass.

## Must-Haves

- All five verifiers exist under `tools/verify/`, are executable, pass `bash -n`,
  and are milestone-slug-prefixed (`m046-p03-*`).
- `bash tools/verify/m046-p03-phase-suite.sh` exits 0 with `SUMMARY: ... fail=0`.

## Verification

```bash
bash tools/verify/m046-p03-phase-suite.sh
```

## Inputs

### From Previous Tasks

- `scripts/intake/auto-entry.sh` (T01) — `AUTO:ROUTE tier=<c|a|a_plus|b> mode=...`
  + `AUTO:BLOCK_AMBIGUITY`; six flags + `--ambiguity-mode block|prompt` (default
  block). Dir/empty arg → `tier=c mode=loop`; description → one-shot; below floor →
  BLOCK (block) or legacy prompt (prompt).
- `scripts/intake/do-entry.sh` (T02) — shim: prints deprecation notice, forwards
  `--ambiguity-mode prompt "$@"` to auto-entry.
- `packaging/bundle/manifest.yml`, `packaging/skills/orchestrator-do.md`,
  `packaging/bundle/build-bundle.sh` (T04) — bundle wiring + `--check` gate.

### From Disk (Pre-existing)

- `scripts/intake/shape-detect.sh` — classifier used to justify the fixture
  choices (3-word → high; 8-word → low).
- `scripts/dispatch/build-context.sh` — the degenerate-path payload producer whose
  determinism the parity harness relies on.

## Constraints

- Verifiers are project-owned → `tools/verify/`, slug `m046-p03-*` (path + naming
  discipline). Never `scripts/verify/`.
- Invoke drivers directly via `bash scripts/intake/...`; do NOT wrap repo-resident
  paths in `run-probe.sh` (rule 4).
- SC-2 must assert byte-equality (diff), never substring.
- Bash 3.2; each `Check:`/`Verification` line is a single-script invocation
  (AUTO_SAFE — pre-validated via `scripts/util/classify-command.sh`).

## Expected Output

Five verifiers on disk; `m046-p03-phase-suite.sh` prints per-check `PASS:` lines +
`SUMMARY: pass=<n> fail=0` and exits 0.
