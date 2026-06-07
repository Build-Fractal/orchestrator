---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M034"
name: "RUNTIME-ASSUMPTIONS rows + renderer-doc Cursor path + byte-parity audit (FR-14 / FR-15 / SC-9)"
depends_on: ["T01"]
---

## Prerequisites

- `references/RUNTIME-ASSUMPTIONS.md` exists with the M009 Cursor section + a `| ID | Surface | Divergence | Rationale | M009 Audit Row |` table (rows RA-M009-CURSOR-01..03 at ~line 76) — verified on disk.
- `references/interactive-review-renderer.md` exists (P02; documents the interactive-cc Case-A path) — verified on disk.
- `scripts/lifecycle/review-gate-mcp-server.sh` exists (T01) with the accept→`--test-responses` delegation.
- `scripts/lifecycle/interactive-review.sh` exists with the `ORCH_REVIEW_FIXED_TS` seam (T01) + `--test-responses`.
- `.orchestrator/milestones/M034/fixtures/decisions-packet-baseline.md` exists (8-decision fixture).
- `shasum` (or `sha256sum`) on PATH for byte-parity.

## Description

Close FR-14 + FR-15 (both → SC-9). FR-14: document the interactive-review
question primitive per runtime in `RUNTIME-ASSUMPTIONS.md` (CC AskUserQuestion /
Cursor MCP elicitation / headless QUESTIONS.md) and extend the renderer
walkthrough doc with the Cursor-MCP path. FR-15: a byte-parity audit proving the
deterministic review-gate paths are byte-identical under `ORCH_BACKEND=cursor` vs
the CC default (the consolidated M009 FR-8).

## Steps

### 1. Add the interactive-review primitive rows to `references/RUNTIME-ASSUMPTIONS.md`

Add a new subsection AFTER the M009 Cursor "M009 audit handoff" block (~line 86),
BEFORE the "## Shape-Guard Carve-Outs" section. Use the SAME 5-column table shape
the file already uses so the FR-14 rows are uniform with the existing M009 rows:

```markdown
## Interactive review primitive (M034)

The interactive review gate (M034) abstracts one runtime question primitive per
runtime behind the `dispatch-interface.sh --probe-renderer` seam (CON-7). The
renderer is selected uniformly; the agent in that runtime context issues the
primitive (AD-3 two-layer dispatch). The deterministic, zero-LLM paths
(`--test-responses` writer + headless auto-mode policy) are runtime-AGNOSTIC and
byte-identical across backends — asserted by the FR-15 byte-parity audit
(`tools/verify/m034-p03-byte-parity.sh`).

### Divergences

| ID | Surface | Divergence | Rationale | M009 Audit Row |
|----|---------|------------|-----------|-----------------|
| RA-M034-REVIEW-01 | CC interactive-review primitive | Claude Code surfaces each decision via the in-process `AskUserQuestion` tool (Case A — the already-interactive top-level session, not a `claude -p` subagent); the agent writes `REVIEW.md` directly. | `AskUserQuestion` is a live CC tool reaching the operator's terminal; resolved at P00 PC-2 (`M034-P00-ADDENDUM.md`). | M009-RP-M034-01 (cc-askuserquestion) |
| RA-M034-REVIEW-02 | Cursor interactive-review primitive | Interactive Cursor surfaces each decision via the orchestrator-owned stdio MCP server's `elicitation/create` request; `action:accept` content is captured to `REVIEW.md`. The server delegates ALL writes to `interactive-review.sh` (single producer). | Cursor advertises `capabilities.elicitation.form` (M009 Q1, findings Addendum (b)); FR-10 server is the renderer. Registered non-clobbering in `.cursor/mcp.json` (CON-6). | M009-RP-M034-02 (cursor-mcp-elicitation) |
| RA-M034-REVIEW-03 | Headless interactive-review primitive | Headless CC / headless `cursor-agent -p` have no interactive surface; the gate writes a `QUESTIONS.md` hand-off and applies the declared auto-mode policy (`defer`/`accept-with-audit`/`refuse-entry`). Headless Cursor elicitation auto-returns `action:decline`, which maps onto the same policy. | No TTY/form surface in headless (M009 Addendum (b): decline is instant, deterministic, no hang); FR-9 fallback + FR-8 policy. | M009-RP-M034-03 (headless-questions-handoff) |

### M034 parity-fixture handoff

These rows use placeholder audit IDs (`M009-RP-M034-01..03`); the M009 Tier-B
parity audit assigns real IDs. The FR-15 byte-parity fixture
(`tools/verify/m034-p03-byte-parity.sh`) runs the deterministic review-gate paths
under `ORCH_BACKEND=cursor` and asserts SHA-256 equality with the CC paths — the
`dispatch-interface.sh` parity-fixture convention applied to the review stage.
```

### 2. Extend `references/interactive-review-renderer.md` with the Cursor-MCP path

Add a new section (after the "## How to record" section, before the
"## boundary_translation heuristic" section) documenting the `interactive-cursor`
renderer path — the descriptor `interactive-review.sh` ALREADY emits for
`interactive-cursor` (P02), now backed by the real server:

```markdown
## Cursor-MCP renderer path (interactive-cursor, FR-10)

When `dispatch-interface.sh --probe-renderer` resolves `renderer=interactive-cursor`
(cursor-agent advertises `capabilities.elicitation.form` AND `ORCH_HEADLESS`
unset), `interactive-review.sh` emits the same render-descriptor it emits for
interactive-cc, naming `interactive-cursor`. The orchestrating agent in the Cursor
context (cursor-agent) renders the walkthrough by calling the orchestrator-owned
MCP review-gate server (`scripts/lifecycle/review-gate-mcp-server.sh`), registered
in `.cursor/mcp.json`:

1. The agent calls the server's `review_gate` tool with the descriptor's
   `gate_id` / `packet` / `milestone` / `phase` (+ optional `policy`).
2. For each active decision (packet order, via `read-decisions.sh active-ids`) the
   server issues a server→client `elicitation/create` request carrying the
   decision's concrete-impact framing; interactive Cursor renders a native form.
3. On `action:accept` (per decision) the server collects the responses into the
   recorded-response fixture shape and delegates to
   `interactive-review.sh --test-responses` — so the Cursor accept path writes
   REVIEW.md / SIGNOFF.md **byte-identically** to the CC path.
4. On `action:decline` / `cancel` (headless Cursor auto-declines, M009 Addendum
   (b)) or no response within the bounded read, the server maps onto the declared
   auto-mode policy via the headless `interactive-review.sh` path — no hang.
5. If the client's `initialize` capabilities lack `elicitation` (older Cursor),
   the server degrades to the `QUESTIONS.md` hand-off rather than erroring.

The server is PURE transport: it issues elicitation and bridges responses, but
NEVER writes review artifacts itself (AD-1 single producer — `interactive-review.sh`).
```

### 3. Author `tools/verify/m034-p03-byte-parity.sh` (FR-15 / SC-9)

The byte-parity audit. In an isolated scratch dir (copy the baseline packet in),
with a FROZEN timestamp (`ORCH_REVIEW_FIXED_TS=2026-06-06T00:00:00Z`) and a fixed
reviewer (`ORCH_REVIEWER=audit`) and scratch `ORCH_EVENT_LOG`:

1. **Backend parity (the headline FR-15 assertion).** Run
   `interactive-review.sh --test-responses=<fixture> --packet=<scratch-A> …` once
   with `ORCH_BACKEND=cursor` and once with the CC default (unset / `claude-code`),
   each writing to a SEPARATE scratch packet copy so REVIEW/SIGNOFF land in
   distinct dirs. Compute SHA-256 of each run's `*-REVIEW.md` and `*-SIGNOFF.md`.
   Assert `sha(cursor REVIEW) == sha(cc REVIEW)` AND `sha(cursor SIGNOFF) == sha(cc SIGNOFF)`.
   (The deterministic writer has no backend branch, so equality holds — the audit
   PROVES it rather than assuming it.)
2. **MCP-accept ↔ CC parity.** Drive the T01 MCP server's accept path over a
   stubbed transport (initialize-with-elicitation → tools/call → one
   `{"id":"elicit-N","result":{"action":"accept"}}` per active id) against a third
   scratch packet copy, with the SAME `ORCH_REVIEW_FIXED_TS`/`ORCH_REVIEWER`.
   Assert the server-produced `*-REVIEW.md` SHA-256 equals the CC
   `--test-responses` `*-REVIEW.md` SHA-256 from step 1 — proving the Cursor
   renderer (FR-10) is byte-parity with the CC renderer (FR-6) on the
   deterministic accept path.

Use a use-the-same-responses-fixture for steps 1 and 2 (all accepts is simplest;
or accept+one-override to exercise verbatim capture). Compute SHA via a helper
function (AD-19 carve-out) — e.g. `_sha() { shasum -a 256 "$1" | awk '{print $1}'; }`
with a `sha256sum` fallback. Print `PASS: m034-p03 byte-parity` /
`FAIL: m034-p03 byte-parity — <reason>`.

### 4. Co-author `tools/verify/m034-p03-runtime-assumptions.sh` (FR-14 / SC-9)

Static verifier asserting the FR-14 documentation surface:
1. `references/RUNTIME-ASSUMPTIONS.md` contains the three rows `RA-M034-REVIEW-01`,
   `RA-M034-REVIEW-02`, `RA-M034-REVIEW-03` and the tokens `AskUserQuestion`,
   `elicitation/create`, and `QUESTIONS.md`.
2. `references/interactive-review-renderer.md` contains a Cursor-MCP section
   naming `elicitation/create`, `review-gate-mcp-server.sh`, and `interactive-cursor`.

Print `PASS: m034-p03 runtime-assumptions` / `FAIL: m034-p03 runtime-assumptions — <reason>`.

## Must-Haves

- `references/RUNTIME-ASSUMPTIONS.md` carries the three RA-M034-REVIEW-* interactive-review primitive rows (CC AskUserQuestion / Cursor MCP elicitation / headless QUESTIONS.md) with M009 audit-row entries.
- `references/interactive-review-renderer.md` documents the Cursor-MCP renderer path (elicitation/create + accept→REVIEW.md / decline→policy + the byte-parity-by-delegation note).
- The byte-parity audit asserts SHA-256 equality of REVIEW.md + SIGNOFF.md under `ORCH_BACKEND=cursor` vs CC, AND the MCP-accept output equals the CC `--test-responses` output, with `ORCH_REVIEW_FIXED_TS` frozen.

## Verification

```bash
bash tools/verify/m034-p03-runtime-assumptions.sh
bash tools/verify/m034-p03-byte-parity.sh
```

## Inputs

### From Disk (Pre-existing)
- `references/RUNTIME-ASSUMPTIONS.md` — existing 5-column divergence tables; the M009 Cursor section (~line 61) + its "M009 audit handoff" block (~line 80) are the structural model; insert the new section before "## Shape-Guard Carve-Outs" (~line 88).
- `references/interactive-review-renderer.md` — the P02 interactive-cc walkthrough doc; has "## How to record" + "## boundary_translation heuristic" sections to insert between.
- `scripts/lifecycle/interactive-review.sh` — `--test-responses=<json-array>` writes REVIEW.md/SIGNOFF.md deterministically; honors `ORCH_REVIEW_FIXED_TS` (T01), `ORCH_REVIEWER`, `ORCH_EVENT_LOG`. The deterministic writer has NO backend branch (so ORCH_BACKEND is a no-op on output — that's the parity property).
- `scripts/lifecycle/review-gate-mcp-server.sh` (T01) — accept path delegates to `--test-responses`; drive over stdin with a recorded JSON-RPC stream (initialize-with-elicitation, tools/call, per-id accept responses). Honors `ORCH_MCP_ELICIT_TIMEOUT`.
- `.orchestrator/milestones/M034/fixtures/decisions-packet-baseline.md` — 8 active ids D-1..D-8; copy per scratch run.

## Constraints

- CON-1: bash 3.2 / POSIX-sh single file. SHA + multi-step pipes live in verifier function bodies (AD-19 carve-out), never inline `Check:` commands.
- FR-15 byte-equality (not substring): assert SHA-256 string equality of whole files, with timestamps frozen via `ORCH_REVIEW_FIXED_TS` (the default-to-byte-equality discipline). Do NOT strip-then-compare.
- RUNTIME-ASSUMPTIONS edits are ADDITIVE (a new section); do not alter the M018 or M009 rows.
- Documentation only for steps 1-2 — no runtime code changes (T01 already shipped the seam + server).

## Expected Output

See `## Notes`.

## Notes

`bash tools/verify/m034-p03-runtime-assumptions.sh` prints `PASS: m034-p03
runtime-assumptions` when the three rows + the renderer-doc Cursor section are
present. `bash tools/verify/m034-p03-byte-parity.sh` prints `PASS: m034-p03
byte-parity` when the cursor-vs-CC REVIEW/SIGNOFF SHA-256s match AND the MCP-accept
REVIEW SHA-256 matches the CC `--test-responses` REVIEW SHA-256. Each prints
`FAIL: m034-p03 <slice> — <reason>` + exit 1 on a miss.
