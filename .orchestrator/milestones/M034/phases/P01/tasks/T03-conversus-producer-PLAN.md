---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M034"
name: "conversus producer — gate-result → packet entries (strict-when-declared)"
depends_on: ["T02"]
---

## Prerequisites

- `scripts/knowledge/write-decisions.sh` exists (T02 deliverable — the producer pipes its mapped JSON into it).
- `scripts/dispatch/adapters/tool/conversus.sh` exists (the gate adapter). Confirmed on disk. Subcommands: `check`, `gate [--strict] [--source <path>]... <preset> <artifact> <output>`, `parse-verdict <gate-result-path>`. Gate exit codes: `0`=PASS, `2`=BLOCK, `1`=adapter error / missing-binary (under `--strict`).
- `tests/fixtures/gate-result-block.md` + `tests/fixtures/gate-result-pass.md` exist (stub gate-result fixtures returned when `CONVERSUS_STUB=1`). Confirmed on disk.

## Description

FR-11/FR-12 + AD-6. Author `scripts/knowledge/decisions-from-conversus.sh`: the optional conversus *producer*. It runs the existing conversus gate adapter over an artifact and maps the resulting `gate-result.md` (verdict, surviving disputes, rationale, deliberation link) into decision-packet entries the walkthrough later surfaces — so the operator adjudicates conversus's findings rather than re-deriving them.

**Strict-when-declared (FR-12 / AD-6, the central invariant):** when a gate declares `producer: conversus` and the conversus binary is absent/unauthed, the producer BLOCKs — exits non-zero with a `pipx install conversus-oss` + `conversus login` pointer — and does NOT mark the gate reviewed. It never silently SKIPs. (Note: the adapter's *default* mode degrades to SKIP+exit-0; this producer MUST pass `--strict` so a missing binary becomes exit 1, then translate that into the block.)

**CON-8 discipline:** a conversus `BLOCK` verdict is operator-overridable *content*, not a hard stop and not the `refuse-entry` policy and not the packet `severity: block` field. The mapping records the verdict as content; it does not halt. Entry text references "conversus verdict" precisely, never collapsing the three "block" senses.

## Steps

1. Resolve the script dir. Parse flags: `--preset=<preset>`, `--artifact=<path>`, `--milestone=<M>`, `--out=<packet-path>`, optional repeatable `--source=<path>`. Validate `--preset`/`--artifact`/`--milestone`/`--out` present.

2. **Missing-binary test seam.** If `DECISIONS_CONV_STUB_MISSING=1`, short-circuit directly to the block path of step 5 (deterministic SC-7 coverage without depending on machine conversus state). Document this as a test-only seam in the header comment (cf. `CONVERSUS_STUB`, `ORCH_M019_EMIT`).

3. Run the gate into a temp gate-result path under `$TMPDIR`/`tmp/`:
   `bash "$CONV_ADAPTER" gate --strict <repeated --source> "$preset" "$artifact" "$gate_out"`; capture its exit code (`gate_rc`).

4. **Branch on `gate_rc`:**
   - `gate_rc == 0` (PASS) or `gate_rc == 2` (BLOCK): proceed to mapping (step 6). Both are *content* outcomes — BLOCK is not an error (edge case: "conversus declared producer returns BLOCK" → BLOCK becomes packet entries the operator adjudicates).
   - `gate_rc == 1` (adapter error / missing binary under strict): go to the block path (step 5).
   - any other non-zero: treat as adapter error → block path (step 5) with the adapter's stderr surfaced.

5. **Block path (FR-12).** Print to stderr a clear, actionable message containing the literal strings `pipx install conversus-oss` and `conversus login` and naming the declared producer gate; do NOT write/modify the packet; exit non-zero (use exit 3 to distinguish from generic error). Example message: `BLOCK: producer: conversus declared but the conversus binary is unavailable. Install it: pipx install conversus-oss && conversus login anthropic. The gate is NOT marked reviewed.`

6. **Mapping (FR-11).** Parse `$gate_out`:
   - `verdict` from frontmatter (or via `conversus.sh parse-verdict "$gate_out"` → `verdict=PASS|BLOCK`).
   - `conversus_output_dir` from frontmatter if present → derive the deliberation link `<dir>/summary/final.md`; else use the gate-result path itself as the link.
   - The `## Rationale` section body (lines after `## Rationale` up to EOF or next `## `).
   - Each `## Disputes` line of shape `- **<advocate>**: <claim>` → one packet entry.
   Build a `{"decisions":[...]}` JSON document with `jq` (NOT string concatenation — jq encodes the free-text bodies safely). For dispute index `n` (1-based):
     - `id`: `CONV-<n>`
     - `summary`: the `<claim>` text
     - `picked_value`: `conversus verdict: <VERDICT>`
     - `rationale`: the `## Rationale` body
     - `alternatives_considered`: `See full deliberation: <link>`
     - `concrete_impact`: `Surviving dispute raised by the <advocate> advocate. The conversus BLOCK/PASS verdict is operator-overridable content (CON-8), not a hard stop; adjudicate at the gate.`
     - `severity`: `block` when `verdict == BLOCK`, else `warn`
     - `type`: `decision`
   If there are zero dispute lines, emit a single summary entry `CONV-1` capturing the verdict + rationale (so a clean PASS still produces an auditable packet entry).

7. Pipe the JSON into the writer:
   `printf '%s' "$json" | bash "$SCRIPT_DIR/write-decisions.sh" --milestone="$milestone" --artifact="$artifact" --out="$out"`. Propagate the writer's exit code. On success print `DECISIONS(conversus): mapped <N> dispute(s) at verdict <VERDICT> into <out>`.

8. Co-author `tools/verify/m034-p01-producer.sh`:
   - (a) `CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=BLOCK` → run the producer against any artifact path; assert the `--out` packet contains two `CONV-` entries (the two disputes in `gate-result-block.md`), each `severity: block`, `picked_value` mentioning `BLOCK`.
   - (b) `CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS` → assert the packet is produced (PASS path) with at least one `CONV-` entry.
   - (c) `DECISIONS_CONV_STUB_MISSING=1` → assert the producer exits non-zero AND its stderr contains `pipx install conversus-oss` AND the `--out` packet was NOT created/modified (strict block, no silent SKIP).
   - Print `PASS: m034-p01 producer` / `FAIL: ...`.

## Must-Haves

- A `producer: conversus` mapping runs `conversus.sh gate --strict` and folds the verdict + surviving disputes + rationale + deliberation link into packet entries (FR-11).
- A missing/unauthed binary BLOCKs (exits non-zero) with a `pipx install conversus-oss` pointer and never silently SKIPs (FR-12, AD-6).
- The mapping preserves CON-8 separation (verdict is content, not the `refuse-entry` policy nor the packet severity semantics).

## Verification

`bash tools/verify/m034-p01-producer.sh`
`grep -q "pipx install conversus-oss" scripts/knowledge/decisions-from-conversus.sh`
`grep -q -- "--strict" scripts/knowledge/decisions-from-conversus.sh`

## Notes

Expected: `bash tools/verify/m034-p01-producer.sh` prints `PASS: m034-p01 producer` and exits 0; the two `grep` commands exit 0. The `--strict` flag is load-bearing: without it the adapter SKIPs (exit 0) on a missing binary, which would violate FR-12. The producer is the strict wrapper that turns SKIP-able degradation into a block.

The `DECISIONS_CONV_STUB_MISSING=1` seam exists because the dev machine has conversus-oss installed at `~/Sites/conversus-oss` (per the standing conversus-OSS prerequisite), so the real missing-binary path cannot be exercised without it. The seam routes through the SAME block code (same message, same exit), so the test asserts the real behavior.

## Inputs

### From Disk (Pre-existing)
- `scripts/knowledge/write-decisions.sh` (T02) — invoked as `write-decisions.sh --milestone=<M> --artifact=<path> --out=<path>` reading `{"decisions":[...]}` on stdin. Keys are the eight FR-1 field names; `severity`/`type` optional (writer defaults them). The writer requires jq and implements the supersede chain — the producer just supplies the JSON.
- `scripts/dispatch/adapters/tool/conversus.sh` — `gate [--strict] [--source <p>]... <preset> <artifact> <output>` writes `gate-result.md` to `<output>` and exits 0/2/1 (PASS/BLOCK/error). `parse-verdict <path>` prints `verdict=PASS|BLOCK`. `CONVERSUS_STUB=1` + `CONVERSUS_STUB_VERDICT=PASS|BLOCK` returns the `tests/fixtures/gate-result-{pass,block}.md` fixture deterministically.
- `tests/fixtures/gate-result-block.md` — frontmatter `verdict: "BLOCK"`; a `## Disputes` section with two `- **<advocate>**: <claim>` lines; a `## Rationale` section. This is the mapping shape your parser must handle.

## Constraints

- Bash 3.2 / POSIX-sh single file (CON-1 / AD-19). jq permitted/required (encoding free-text bodies safely). Pipes/`awk`/`sed`/`$()` permitted inside the script body.
- Build the JSON with jq, NOT string concatenation — dispute/rationale bodies carry arbitrary punctuation.
- FR-12 strict: pass `--strict` to the gate; translate adapter exit 1 into a non-zero block with the install pointer. Never exit 0 on a missing binary.
- Do NOT modify `write-decisions.sh` (T02), `conversus.sh`, or status/doctor.

## Expected Output

`scripts/knowledge/decisions-from-conversus.sh` + `tools/verify/m034-p01-producer.sh` created. Under stub mode the producer maps both verdicts into packet entries; under the missing-binary seam it blocks with the install pointer and leaves the packet untouched.
