---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M046"
goal: "Unify orchestrator:do into a classify-first orchestrator:auto entry (Tier A/A+/B one-shot | Tier C loop | BLOCK) and turn orchestrator:do into a byte-parity deprecation shim."
demo_sentence: "orchestrator:auto with a Tier-A description, a Tier-C milestone dir, and an ambiguous arg routes to one-shot dispatch, loop entry, and AUTO:BLOCK_AMBIGUITY respectively; orchestrator:do prints a one-line deprecation notice and produces byte-identical artifacts through the shim for all six forwarded flags."
risk: "medium"
depends_on: []
---

## Context (read first)

This phase is authoring/entry-layer only. It reuses the M024 classifier and the
existing downstream routers **byte-unchanged** (FR-2 / CON-2) and MUST NOT touch
`auto-loop.sh`. The unification collapses two front doors — `orchestrator:do`
(Tier A/A+/B one-shot, backed by `scripts/intake/do-entry.sh`) and
`orchestrator:auto` (Tier C loop) — into one classify-first `orchestrator:auto`.

**On-disk path facts (verified at plan-authoring time — the roadmap Boundary Map
has a path drift):**

- The M024 classifier is `scripts/intake/shape-detect.sh` (two-line contract:
  `input_shape=<idea|paragraph|tier_a_plus|fragment|spec|empty>` +
  `shape_classification=<high|low>`).
- The Tier A+ router is **`scripts/intake/route-to-dispatch.sh`** (NOT
  `scripts/dispatch/route-to-dispatch.sh` as the roadmap Boundary Map states —
  the roadmap path is wrong; use the intake path).
- The Quick-profile direct-mode driver is `scripts/dispatch/build-context.sh`.
- `scripts/intake/auto-entry.sh` does NOT exist yet — it is created in T01 as the
  generalization of the existing `scripts/intake/do-entry.sh` (M031/P03/T01).

**#Q-2 resolved as D020 (arch):** `--yes` keeps its existing NARROW meaning
(skip the single attended confirmation prompt — the Tier-A+ P02 approval prompt on
the one-shot path, or the M029 preflight confirm on the Tier-C loop path). It does
NOT broaden. `--unattended` (shipped P04) is the sole explicit gate for the
unattended/destructive-approval envelope, governed by the FR-13 driver-level
fail-closed caps. FR-5's broadening branch is therefore NOT triggered — no
alias/longer-window/notice is needed beyond documenting the boundary in
`commands/auto.md` and `commands/do.md`.

**#Q-3 resolved as D021 (scope):** the `orchestrator:do` shim ships as a
deprecation shim in the M046 release and is retained through AT LEAST the next
published minor release; removal is gated NO EARLIER than one published release
after the deprecation ships. The one-line deprecation notice names the concrete
target-removal version. Removal is a separate future change, not part of M046.

**FR-4 finding (verified at plan-authoring time):** `orchestrator-do.md` is NOT
in `packaging/bundle/manifest.yml` skills list, NOT in `packaging/bundle/skills/`,
and NOT in `packaging/bundle/build-bundle.sh`'s `EXPECTED_SKILL_NAMES`
(`EXPECTED_SKILLS=13`). `orchestrator:do` was never shipped as a consumer skill.
To make FR-4 / US2-AS-2 real and testable ("the update re-stage path re-installs
the shim; a non-updated consumer gets the deprecation notice not a missing-command
error"), T04 ADDS `orchestrator-do.md` as a deprecation-shim skill to the bundle
(source + manifest + build-bundle expected list, count 13→14). This is the honest,
spec-literal resolution; the alternative (do was never externally shipped, so no
external migration is owed and the shim serves only this repo's dogfood + scripted
`do-entry.sh` callers) is documented in T04 for operator veto during execution.

**auto-entry.sh stdout routing contract (defined here, implemented in T01):**

- Tier C (arg is an existing directory, OR arg empty → find-active-milestone):
  emit `AUTO:ROUTE tier=c mode=loop target=<milestone-dir-or-active>` and exit 0.
  auto-entry does NOT run the loop itself — the `commands/auto.md` loop flow
  (unchanged) drives it. This preserves M045 legacy parity (FR-17).
- Tier A/A+/B (arg is a task description): run `shape-detect.sh`, then execute the
  former `do` one-shot routing verbatim (the four branches: tier_a_plus handoff,
  tier_a_degenerate fast-path, tier_bc passthrough, low-conf). Emit
  `AUTO:ROUTE tier=<a|a_plus|b> mode=one-shot` before the branch action.
- Below the confidence floor, auto-native default (`--ambiguity-mode block`):
  emit `AUTO:BLOCK_AMBIGUITY verdict=<v> conf=<c>` and exit 0 without dispatching
  (AS-3 / SC-1).
- Below the confidence floor, do-compat (`--ambiguity-mode prompt`, passed by the
  do-shim): run the legacy interactive low-conf prompt EXACTLY as `do-entry.sh`
  did today (honoring `--no-prompt-mode`, writing the JSONL `unit_close` record to
  `ORCH_DO_ENTRY_LOG`), so scripted `do` callers do not silently break.

The high-confidence one-shot code path is shared identically between the auto-native
and do-compat modes — that is what makes SC-2 byte-parity structural rather than
coincidental. `--ambiguity-mode` defaults to `block`; only the below-floor branch
reads it, so it is inert for the Tier-A fixture SC-2 uses.

## Must-Haves

### Truths

- `orchestrator:auto` routes a Tier-A description to one-shot dispatch, a Tier-C
  milestone dir to loop entry, and an ambiguous (below-floor) arg to
  `AUTO:BLOCK_AMBIGUITY` — all three exit 0 (SC-1 / FR-1).
  - Check: `bash tools/verify/m046-p03-routing-fixture.sh`
- A `do`-shim invocation and the equivalent `auto` invocation produce
  BYTE-IDENTICAL artifacts on a fixed Tier-A degenerate fixture, and the
  deprecation notice is present on the `do`-shim path and absent on the `auto`
  path (SC-2 — byte-equality, not substring).
  - Check: `bash tools/verify/m046-p03-shim-parity.sh`
- The `do`-shim forwards ALL SIX `do-entry.sh` flags (`--task`, `--yes`,
  `--config`, `--dispatch-stub`, `--scratch-root`, `--no-prompt-mode`) to
  `auto-entry.sh` with identical effect (FR-3).
  - Check: `bash tools/verify/m046-p03-shim-forward.sh`
- The `orchestrator-do` deprecation-shim skill is wired into the bundle so the
  `orchestrator:update` re-stage path re-installs it: it appears in the manifest
  skills list, in `build-bundle.sh`'s expected-skill set, and as a source skill
  (FR-4).
  - Check: `bash tools/verify/m046-p03-update-restage.sh`
- The unified entry reuses the three consumed scripts by their canonical on-disk
  paths and P03 makes no change to `auto-loop.sh` (FR-2 / CON-2 reuse-not-
  reimplement; the phase-suite also runs the four fixtures above).
  - Check: `bash tools/verify/m046-p03-phase-suite.sh`

### Artifacts

- scripts/intake/auto-entry.sh (min 180 lines, contains "AUTO:BLOCK_AMBIGUITY")
- scripts/intake/do-entry.sh (min 25 lines, contains "auto-entry.sh")
- commands/auto.md (min 400 lines, contains "AUTO:BLOCK_AMBIGUITY")
- commands/do.md (min 40 lines, contains "deprecat")
- packaging/skills/orchestrator-do.md (min 15 lines, contains "deprecat")
- packaging/bundle/manifest.yml (min 30 lines, contains "orchestrator-do.md")
- tools/verify/m046-p03-routing-fixture.sh (min 30 lines, contains "AUTO:BLOCK_AMBIGUITY")
- tools/verify/m046-p03-shim-parity.sh (min 30 lines, contains "diff")
- tools/verify/m046-p03-shim-forward.sh (min 20 lines, contains "no-prompt-mode")
- tools/verify/m046-p03-update-restage.sh (min 15 lines, contains "orchestrator-do.md")
- tools/verify/m046-p03-phase-suite.sh (min 15 lines, contains "m046-p03-routing-fixture.sh")

### Key Links

- scripts/intake/do-entry.sh → scripts/intake/auto-entry.sh
- scripts/intake/auto-entry.sh → scripts/intake/shape-detect.sh
- scripts/intake/auto-entry.sh → scripts/intake/route-to-dispatch.sh
- scripts/intake/auto-entry.sh → scripts/dispatch/build-context.sh
- commands/auto.md → scripts/intake/auto-entry.sh
- commands/do.md → scripts/intake/do-entry.sh
- packaging/bundle/manifest.yml → orchestrator-do.md

## Tasks

### T01: auto-entry.sh unified classify-first entry driver

See `tasks/T01-auto-entry-driver-PLAN.md`. Creates `scripts/intake/auto-entry.sh`
by generalizing `do-entry.sh`: adds the Tier-C dir/empty front-route (emits
`AUTO:ROUTE tier=c mode=loop`), absorbs the four-branch one-shot routing verbatim
(all six flags), adds the `--ambiguity-mode block|prompt` split (auto-native BLOCK
vs do-compat prompt), and reuses `shape-detect.sh` / `route-to-dispatch.sh` /
`build-context.sh` by path (byte-unchanged). Does NOT touch `auto-loop.sh`.

### T02: do-entry.sh forwarding shim + commands/do.md deprecation doc

See `tasks/T02-do-shim-and-doc-PLAN.md`. Rewrites `scripts/intake/do-entry.sh` to
a thin forwarding shim: emit one deprecation-notice line to stderr, then forward
all six flags plus `--ambiguity-mode prompt` to `auto-entry.sh`, returning its exit
code unchanged. Rewrites `commands/do.md` as the deprecation-shim doc carrying the
D021 removal-runway language.

### T03: commands/auto.md unified classify-first entry authoring

See `tasks/T03-auto-md-authoring-PLAN.md`. Prepends a "Unified tier-sized entry"
section documenting `orchestrator:auto <arg>` tier routing, the `AUTO:ROUTE` /
`AUTO:BLOCK_AMBIGUITY` contract, the `auto-entry.sh` driver reference, and the
FR-5 `--yes` narrow-semantics boundary (D020: `--yes` = skip attended confirm;
`--unattended` = the destructive-approval gate). Leaves the existing Tier-C loop /
P04 unattended-envelope sections intact.

### T04: FR-4 orchestrator-do bundle-skill migration wiring

See `tasks/T04-fr4-bundle-restage-PLAN.md`. Adds `packaging/skills/orchestrator-do.md`
(deprecation-shim skill source), adds `orchestrator-do.md` to
`packaging/bundle/manifest.yml` skills list, bumps `build-bundle.sh`
`EXPECTED_SKILLS` 13→14 and adds the name to `EXPECTED_SKILL_NAMES`, and
regenerates `packaging/bundle/skills/orchestrator-do.md` via `build-bundle.sh`.

### T05: SC-1 / SC-2 / FR-3 / FR-4 verifiers + phase-suite aggregator

See `tasks/T05-verifiers-PLAN.md`. Authors the five `tools/verify/m046-p03-*.sh`
verifiers named in the Must-Haves and wires the phase-suite aggregator.

## Task Dependencies

```
T01 ─┬─→ T02 ──┐
     │         ├─→ T05
     ├─→ T03 ──┤
     └→ T04 ───┘
```

T01 first (the driver everything else references). T02 (shim → auto-entry), T03
(auto.md documents auto-entry), and T04 (bundle skill for the shim) all depend on
T01; T04 also depends on T02 (the shim skill wraps the do command). T05 authors
the verifiers that exercise T01–T04 and runs last.

## Files Likely Touched

- scripts/intake/auto-entry.sh (create)
- scripts/intake/do-entry.sh (modify)
- commands/auto.md (modify)
- commands/do.md (modify)
- packaging/skills/orchestrator-do.md (create)
- packaging/bundle/skills/orchestrator-do.md (create — build-bundle.sh output)
- packaging/bundle/manifest.yml (modify)
- packaging/bundle/build-bundle.sh (modify)
- tools/verify/m046-p03-routing-fixture.sh (create)
- tools/verify/m046-p03-shim-parity.sh (create)
- tools/verify/m046-p03-shim-forward.sh (create)
- tools/verify/m046-p03-update-restage.sh (create)
- tools/verify/m046-p03-phase-suite.sh (create)

## Notes

- **Byte-unchanged (FR-2 / CON-2):** `scripts/intake/shape-detect.sh`,
  `scripts/intake/route-to-dispatch.sh`, `scripts/dispatch/build-context.sh`, and
  `scripts/lifecycle/auto-loop.sh` are deliberately ABSENT from Files Likely
  Touched — no task edits them. auto-entry.sh invokes them by path only.
- **SC-2 honest byte-equality:** the parity harness (T05) runs a fixed Tier-A
  **degenerate** description (high-confidence idea/short-paragraph) through both
  `do-entry.sh` (shim) and `auto-entry.sh` with `--dispatch-stub` pointed at a
  capture stub that copies the produced payload + AD-11 sidecar to two fixed
  scratch locations. It then byte-`diff`s the two captured artifact sets and
  asserts they are identical. The Tier-A degenerate path writes NO timestamped
  JSONL record (that only fires on the low-conf branch), so the artifacts are
  deterministic and byte-equality is genuine, not timestamp-masked. Separately it
  asserts the deprecation notice appears on the `do`-shim stderr and NOT on the
  `auto` stderr. Byte-equality is on the disk artifacts; the notice divergence is
  on stderr.
- **Classifier-shape pre-validation (plan-time discipline rule 3):** every phase
  Truth `Check:` command was run through `scripts/util/classify-command.sh` at
  plan-authoring time. All five verifiers classify `AUTO_SAFE`. Finding: the
  originally-intended name `m046-p03-do-parity.sh` classified `APPROVAL_REQUIRED
  reason=inline_loop_or_conditional` because the classifier's `\bdo\b` regex
  matches the `do` token inside the filename; the verifier was renamed to
  `m046-p03-shim-parity.sh` (AUTO_SAFE) to avoid a standalone `do` token in any
  auto-mode command line.
- **Path-collision (plan-time discipline rule 6):** every `create` path above was
  `ls`-checked at plan-authoring time — none exist on disk. No collision.
- **Expected verifier output:** `bash tools/verify/m046-p03-phase-suite.sh` prints
  `PASS:` lines per sub-check and a `SUMMARY: pass=<n> fail=0` line, exit 0.
