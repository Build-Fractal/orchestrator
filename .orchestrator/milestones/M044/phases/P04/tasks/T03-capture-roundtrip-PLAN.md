---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P04"
milestone: "M044"
---

# T03 — Capture-by-default round-trip fixture + phase suite (SC-8/SC-9)

## Zero-context summary

The end-to-end proof that the capture→inject loop is closed at Quick: an explicit
decision captured at Quick lands in the system-of-record `DECISIONS.md`, survives a
rebuild, and shows up in the next Quick inject's Decisions digest. Composes T01
(capture) + T02 (digest) + P02 (consumer-order format).

## Steps

1. `tools/verify/m044-p04-t03-capture-roundtrip.sh`:
   - `mktemp -d` fixture: `.orchestrator/` with a consumer-order `DECISIONS.md`
     header (mirrors `scaffold.sh`), a minimal `knowledge/` dir, a task-plan file.
   - Capture: `intensity-knowledge.sh --intensity Quick --decision-arg
     <root>/.orchestrator/DECISIONS.md --decision-arg M044/P04 --decision-arg arch
     --decision-arg "<question>" --decision-arg "<choice>" --decision-arg "<why>"`.
   - Assert the row is in `.orchestrator/DECISIONS.md`.
   - `rebuild-index.sh --root <root>` (no-op-safe for the append register; proves it
     doesn't break).
   - `build-context.sh <root> ... --profile=quick --out <payload>` (direct mode).
   - Assert the captured decision's text appears under `## Decisions` in the payload.
2. `tools/verify/m044-p04-phase-suite.sh` — copy `m044-p01-phase-suite.sh`, retarget
   `tools/verify/m044-p04-*.sh`. Emits `BATTERY: pass=N fail=0`.

## Determinism / budget (CON-2/CON-3)

The digest read routes through the M036a governor; the round-trip asserts presence
within budget. No wall-clock in the asserted decision row body.

## Done when

- `bash tools/verify/m044-p04-t03-capture-roundtrip.sh` → `PASS:`
- `bash tools/verify/m044-p04-phase-suite.sh` → `BATTERY: pass=N fail=0`
