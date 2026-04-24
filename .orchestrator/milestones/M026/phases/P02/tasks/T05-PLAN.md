---
schema_version: "1.0"
task: "T05"
phase: "P02"
milestone: "M026"
name: "Phase verification suite orchestrator + Recent Changes dual-write"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01 + T02 + T03 + T04 complete: all verify scripts named in the P02-PLAN Must-Haves exist and individually pass.
- `scripts/util/dual-write-runtime-md.sh` (from M014/P01) exists and is used by M026/P01's `m026-p01-recent-changes.sh` pattern.
- `scripts/verify/m026-p01-phase-suite.sh` exists and is the pattern template for this task.
- `scripts/verify/m011-p07-conversus-adapter-shape.sh`, `scripts/verify/m011-p07-gate-pass-block.sh`, `scripts/verify/m011-p07-bash32-compat.sh`, and `tests/test-conversus-adapter-shim.sh` stub-paths — all four must be green at phase-close per M026-CONTEXT.md DC-2.

## Description

Two deliverables:

1. **Phase verification suite orchestrator** at `scripts/verify/m026-p02-phase-suite.sh` that invokes every P02 verify script in dependency order, tallies pass/fail, and emits a single `SUMMARY: m026-p02-phase-suite.sh pass=N fail=0` line. Pattern mirrors `scripts/verify/m026-p01-phase-suite.sh` (reference implementation). Bash 3.2 compatible; AD-19 single-script-file shape.

2. **Recent Changes dual-write** to `CLAUDE.md` and `AGENTS.md` under the marker-bounded `orchestrator:recent-changes` region, emitted via `scripts/util/dual-write-runtime-md.sh`. The fragment names the M026/P02 deliverables in one or two compact lines. P01's fragment remains in place; P02's fragment appears adjacent (reverse-chronological per convention).

## Steps

1. **Read the P01 phase-suite** at `scripts/verify/m026-p01-phase-suite.sh` (already cited in the P02 plan artifacts section). Copy its overall structure — the `GATES=` newline-list, the `IFS=$'\n'` iteration, the pass/fail tallying, the `SUMMARY:` line, the final `PASS:` / `FAIL:` emission.
2. **Create `scripts/verify/m026-p02-phase-suite.sh`** with the full P02 gate list:
   ```
   GATES="
   m026-p02-edition-detection-contract.sh
   m026-p02-adapter-invariants.sh
   m026-p02-jsonl-edition-field.sh
   m026-p02-dual-edition-test-shape.sh
   m026-p02-gate-verdict-reliability.sh
   m026-p02-recent-changes.sh
   m011-p07-conversus-adapter-shape.sh
   m011-p07-gate-pass-block.sh
   m011-p07-bash32-compat.sh
   "
   ```
   Include the M011/P07 gates per M026-CONTEXT.md DC-2 — they're the cross-milestone adapter invariants guard, re-run at every M026 phase close. Add `tests/test-conversus-adapter-shim.sh` stub-path as a final gate via `bash "${REPO_ROOT}/tests/test-conversus-adapter-shim.sh"` if the P01 suite also includes it (check — if P01 omitted the test-shim, keep parity and omit; if P01 included it, include).
3. **Create `scripts/verify/m026-p02-recent-changes.sh`** (single-script-file shape, AD-19 compliant, Bash 3.2 compatible). Must verify:
   - `CLAUDE.md` contains the M026/P02 fragment under the marker region — grep for `M026/P02` inside the `>>> orchestrator:recent-changes >>>` / `<<< orchestrator:recent-changes <<<` markers.
   - `AGENTS.md` contains the same fragment (dual-write parity — the two fragments must byte-match inside the markers).
   - The P01 fragment is still present (no regression / overwrite).
4. **Author the M026/P02 Recent Changes fragment** and dual-write it. The fragment should be concise — one to three bullet points under an `M026/P02:` prefix heading. Suggested content:
   ```markdown
   - M026/P02: conversus-OSS resolver flip — OSS primary, paid escape hatch via CONVERSUS_EDITION; JSONL edition field; dual-edition regression test with visible-skip annotations; gate-verdict-reliability bundle (verdict-text rationale, arbiter preference, OAuth auto-preflight closes OQ-16 false-PASS).
   ```
   Invocation pattern (consult `scripts/util/dual-write-runtime-md.sh`'s help or `m026-p01-recent-changes.sh`'s usage of it for the exact flag shape):
   ```
   bash scripts/util/dual-write-runtime-md.sh \
     --region orchestrator:recent-changes \
     --entry-prefix "M026/P02:" \
     --entry "<the fragment text>" \
     CLAUDE.md AGENTS.md
   ```
   If the helper's actual CLI surface differs, match it — the important invariant is that CLAUDE.md and AGENTS.md emerge byte-identical inside the marker region.
5. **Smoke-test the suite orchestrator**:
   ```
   bash scripts/verify/m026-p02-phase-suite.sh
   ```
   Expected output: nine (or ten with test-shim) gate invocations, each preceded by `---- <gate-name> ----`, followed by `SUMMARY: m026-p02-phase-suite.sh pass=N fail=0` and `PASS: m026-p02-phase-suite.sh`. Exit 0.

## Must-Haves

Addresses phase must-haves:
- "Truth: phase-suite orchestrator returns pass=N fail=0" (T05 owns)
- "Truth: CLAUDE.md + AGENTS.md dual-write parity for M026/P02 Recent Changes" (T05 owns)
- Artifacts: `scripts/verify/m026-p02-phase-suite.sh`, `scripts/verify/m026-p02-recent-changes.sh`
- Key Links: CLAUDE.md → P02-SUMMARY; AGENTS.md → P02-SUMMARY (summary is authored by `orchestrator:verify` at phase-close; the Recent Changes fragment references the milestone/phase ID that matches the forthcoming summary file)

## Verification

```
bash scripts/verify/m026-p02-phase-suite.sh
```

Must exit 0 and print `SUMMARY: m026-p02-phase-suite.sh pass=N fail=0` followed by `PASS: m026-p02-phase-suite.sh`.

## Inputs

### From Previous Tasks

- `scripts/verify/m026-p02-edition-detection-contract.sh` (T01): verifies edition resolution.
- `scripts/verify/m026-p02-adapter-invariants.sh` (T01): verifies CON-1..CON-3.
- `scripts/verify/m026-p02-jsonl-edition-field.sh` (T02): verifies FR-4.
- `scripts/verify/m026-p02-dual-edition-test-shape.sh` (T03): verifies FR-8 / SC-4 / SC-6.
- `scripts/verify/m026-p02-gate-verdict-reliability.sh` (T04): verifies F1/F2/F3 and OQ-16.

### From Disk (Pre-existing)

- `scripts/verify/m026-p01-phase-suite.sh` — reference pattern.
- `scripts/verify/m011-p07-conversus-adapter-shape.sh`, `scripts/verify/m011-p07-gate-pass-block.sh`, `scripts/verify/m011-p07-bash32-compat.sh` — cross-milestone invariant gates re-run at every M026 phase-close per DC-2.
- `scripts/util/dual-write-runtime-md.sh` — dual-write helper (read-only from T05's POV; invoked with args).
- `CLAUDE.md`, `AGENTS.md` — target files for the Recent Changes fragment.

## Constraints

- **CON-2** (Bash 3.2): suite orchestrator and verify scripts stay Bash 3.2 compatible.
- **CON-6** (dual-write Recent Changes): fragment written via `scripts/util/dual-write-runtime-md.sh`, not inline-edited.
- **AD-19** (single-script-file Check shape): all gates invoked via `bash scripts/verify/<script>.sh`; no inline compound bash.
- **OQ-10** (dual-write parity): CLAUDE.md and AGENTS.md fragments must be byte-identical inside the marker region. Verified by `m026-p02-recent-changes.sh`.
- **Non-overwrite**: the P01 fragment stays in place. `dual-write-runtime-md.sh` is responsible for preserving existing entries; if it defaults to replace-all, use its append-mode flag (consult the helper's documentation).

## Expected Output

- `scripts/verify/m026-p02-phase-suite.sh` — created (~60-80 lines, mirroring the P01 suite's shape).
- `scripts/verify/m026-p02-recent-changes.sh` — created (~30-50 lines).
- `CLAUDE.md` — modified: M026/P02 Recent Changes fragment added.
- `AGENTS.md` — modified: same fragment added (dual-write parity).
- `bash scripts/verify/m026-p02-phase-suite.sh` exits 0 with `pass=N fail=0` summary.

After T05 completes, the phase is ready for `orchestrator:verify` (which produces `P02-SUMMARY.md` at phase-close) and `orchestrator:consolidate` (at milestone-close).
