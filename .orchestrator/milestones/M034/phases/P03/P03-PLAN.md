---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M034"
goal: "Ship the Cursor MCP review-gate renderer behind the same dispatch-interface.sh renderer seam P02 established: an orchestrator-owned stdio MCP server exposing review gates via elicitation/create (accept -> REVIEW.md; headless decline -> auto-mode policy), non-clobbering .cursor/mcp.json registration, RUNTIME-ASSUMPTIONS interactive-review rows, and a byte-parity audit under ORCH_BACKEND=cursor."
demo_sentence: "An interactive Cursor session at a gate renders a native elicitation form whose accept captures the operator's responses to REVIEW.md byte-identically to the CC path; a headless cursor-agent run gets the deterministic decline mapped onto the declared auto-mode policy with no hang; and the server is registered in .cursor/mcp.json without clobbering operator MCP config."
risk: "medium"
depends_on: ["P02"]
---

## Phase Scope

P03 is the LAST phase of M034 (US4, FR-10/FR-14/FR-15). It adds the **third
renderer** behind the CON-7 seam P02 established (CC `AskUserQuestion` + headless
`QUESTIONS.md` already shipped; this phase ships the Cursor MCP renderer). It
consolidates the M009 Cursor work that is really *this* feature's Cursor renderer:
M009 FR-6 → M034 FR-10 (the MCP review-gate server) and M009 FR-8 → M034 FR-15
(the byte-parity audit). M009 FR-7 (Cursor cost rate-card) stays DEFERRED — out
of P03 scope.

P03 ships:

- **FR-10** — an orchestrator-owned **stdio MCP review-gate server**
  (`scripts/lifecycle/review-gate-mcp-server.sh`, bash 3.2 + jq) that exposes
  review gates via JSON-RPC `elicitation/create`. Interactive Cursor renders a
  form (`action:accept` with content → captured to REVIEW.md); the same server in
  a headless `cursor-agent` run receives `action:decline` mapped onto the declared
  auto-mode policy (FR-8 `defer`/`accept-with-audit`/`refuse-entry`). The server is
  **pure transport + a response→fixture bridge**: it delegates ALL writes to the
  P02 `interactive-review.sh` stage (single producer, AD-1), so CON-5/SC-5
  always-write and the byte-parity goal are inherited for free.
- **FR-10 registration** — non-clobbering **merge** into `.cursor/mcp.json` via
  the Cursor install path (`cursor.sh --mcp-config` + `merge-mcp-config.sh` +
  `install-cursor.sh` stage). MERGE, not overwrite — preserves operator MCP
  entries (CON-6, mirrors the M009 hooks.json discipline but *merges* rather than
  preserve-with-WARN, because the spec requires our entry to coexist with operator
  servers).
- **FR-14** — `references/RUNTIME-ASSUMPTIONS.md` interactive-review primitive
  rows (CC `AskUserQuestion` / Cursor MCP `elicitation/create` / headless
  `QUESTIONS.md` hand-off) + parity fixtures per `dispatch-interface.sh`
  convention; the `references/interactive-review-renderer.md` walkthrough doc
  extended with the Cursor-MCP path.
- **FR-15** — a **byte-parity audit fixture** that runs the zero-LLM
  review-gate paths under `ORCH_BACKEND=cursor` and asserts SHA-256 equality with
  the CC paths where the path is deterministic (the consolidated M009 FR-8).
- **Edge case** — Cursor MCP server present but elicitation capability absent
  (older Cursor): the server degrades to the `QUESTIONS.md` hand-off (does NOT
  error).

P03 **resolves at plan-time** (this document's "Binding Plan-Time Decisions"
section) the last two pre-planning conditions — mirroring how P00 resolved
PC-1/PC-2 and P01 forward-specified PC-3/4/5:

- **PC-6 (P2, blocks P03)** — the stub `elicitation/create` JSON-RPC shape, the
  accept/decline injection mechanism, and the stub session lifecycle (resolved in
  D-P03-1 + D-P03-2; the M009 `probe-harness/mcp-elicit-server.py` is the
  reference).
- **#Q-5 (mcp-server-lifecycle)** — how the server is launched/process-managed
  and how it authenticates to orchestrator state (resolved in D-P03-3).

These are P03's verification targets: **SC-6** (PC-6) and **SC-9** (FR-14/FR-15).

## Binding Plan-Time Decisions (recorded per Plan-Time Discipline)

These are load-bearing interpretations the executors must NOT re-decide. They
resolve PC-6 + #Q-5 and the only open design seams P03 carries.

- **D-P03-1 — the MCP server is bash 3.2 + jq, NOT Python (PC-6 / CON-1 /
  Principle XVI).** The M009 reference (`mcp-elicit-server.py`) is Python, but
  P03 ports its *logic*, not its runtime. Rationale: (a) CON-1 keeps every new
  orchestrator script bash 3.2 / POSIX-sh single-file; (b) the MCP elicitation
  protocol here is **strictly sequential** request/response on one stdio pair
  (handshake → tools/call → server→client elicitation/create → read response →
  tools/call result — exactly the linear loop the probe harness runs), which
  `read -r line` + `printf` + `jq` handle without concurrent I/O; (c) Principle
  XVI (Distribution Surface Integrity) — `interactive-review.sh` already
  hard-requires `jq`, so a bash+jq server adds NO new runtime dependency, whereas
  shipping a Python server would force Python onto every Cursor operator's
  machine through the bundle + installers. **Fallback (contingency, like P01
  stdin-JSON / P02 option-B):** if the bash+jq server proves inadequate against
  *live* Cursor during dogfooding (e.g. framing edge cases), port to Python —
  the protocol contract and the delegate-to-interactive-review.sh seam are
  language-agnostic, so the fallback is a drop-in. Recorded so the contingency
  is on disk, not improvised.

- **D-P03-2 — the server is pure transport; ALL writes delegate to
  `interactive-review.sh` (AD-1 single producer; the FR-15 byte-parity lever).**
  The server NEVER writes REVIEW.md/SIGNOFF.md/QUESTIONS.md/continue-file itself.
  Three response classes, three delegations:
  - **accept** (interactive form returned `action:accept` with content per
    decision): the server collects one `{id, action, value?, rationale?}` object
    per decision into the **exact PC-3 recorded-response fixture shape** (JSON
    array, packet order) `interactive-review.sh --test-responses` already
    consumes, writes it to a tempfile, and invokes
    `interactive-review.sh --test-responses=<tmp> --packet=… --milestone=… --phase=… --gate-id=… --review-out=… --signoff-out=…`.
    Because this is the SAME deterministic writer the CC test-responses path runs,
    the Cursor accept output is **byte-identical** to the CC path (FR-15 holds by
    construction, not by coincidence).
  - **decline / cancel / read-timeout** (headless `cursor-agent -p` auto-declines;
    MCP `action ∈ {decline, cancel}`; or no response within the bounded read): the
    server invokes the headless policy path
    `ORCH_HEADLESS=1 interactive-review.sh --packet=… --policy=<declared> …` —
    `decline` maps onto the declared auto-mode policy (FR-8), no hang.
  - **elicitation capability absent** (older Cursor — the `initialize` handshake's
    client `capabilities` lack `elicitation`): the server takes the SAME headless
    delegation as decline (which writes the `QUESTIONS.md` hand-off under `defer`)
    — degrade, do NOT error (the spec edge case).

- **D-P03-3 — #Q-5 resolved: per-session spawn, Cursor-managed lifecycle,
  filesystem-scoped state.** The server is a **stdio server spawned per Cursor
  session** (registered in `.cursor/mcp.json`; Cursor spawns the process at
  session start, talks over stdin/stdout, and the server exits on stdin EOF —
  exactly the probe-harness lifecycle). The orchestrator runs **no long-lived
  daemon**; the server is stateless between requests beyond the on-disk
  packet/REVIEW.md, so per-session spawn carries zero warm-state penalty.
  **State authentication is filesystem-scoped:** the server resolves the
  orchestrator root via `scripts/state/resolve-root.sh` relative to the workspace
  dir Cursor launches it in, and reads packets / writes review artifacts directly
  on disk through `interactive-review.sh`. No network, no tokens — the trust
  boundary is the filesystem, identical to every other orchestrator script.

- **D-P03-4 — registration MERGES into `.cursor/mcp.json` (CON-6, FR-10).**
  Unlike hooks.json (preserve-with-WARN when operator-owned), the spec requires
  our review-gate server to **coexist** with operator MCP servers. The merge
  helper `scripts/lifecycle/merge-mcp-config.sh` (bash + jq) sets
  `.mcpServers["orchestrator-review-gate"] = <entry>` while preserving every other
  key byte-for-byte. Non-clobbering + idempotent: re-running rewrites only our
  entry; operator entries survive; an absent file is created with just our entry;
  a **malformed** existing `.cursor/mcp.json` fails closed (exit non-zero, no
  write) rather than clobbering. `cursor.sh --mcp-config` emits the entry fragment
  (mirroring `--hook-config`); `install-cursor.sh` calls the adapter + the merge
  helper in a new stage.

- **D-P03-5 — FR-15 byte-parity needs a frozen timestamp seam.**
  `interactive-review.sh::_iso_now` uses `date -u`, so two otherwise-identical
  runs differ only in `reviewed_at`/`signed_at`/`created_at`. Per the
  byte-equality-default discipline (substring-asserts are asymptotic-not-
  convergent), P03 adds a **test-only** `ORCH_REVIEW_FIXED_TS` env override to
  `_iso_now` (when set, emit the literal value; else `date -u` as today). This is
  the ONLY edit to the P02 `interactive-review.sh` deliverable and it is purely
  additive/test-scoped. With the timestamp frozen, the CC `--test-responses`
  output and the Cursor accept-path output are **truly byte-equal** (SHA-256),
  not equal-modulo-stripping.

- **D-P03-6 — no operator-facing open questions; corpus-gate is a no-op.** PC-6
  and #Q-5 are plan-phase design questions resolved in this document (D-P03-1..3),
  not questions destined for an operator/SME. Per the M042 disposition recorded in
  `M034-ROADMAP.md` § Open Questions, no new operator-facing questions are
  introduced, so the plan-phase corpus-exhaustion gate (`corpus-gate.sh`) is a
  no-op and is skipped (the roadmap gate run already covered the inherited #Q-5).

## Must-Haves

### Truths

- The orchestrator MCP review-gate server (`scripts/lifecycle/review-gate-mcp-server.sh`) completes the MCP stdio handshake (`initialize` → `notifications/initialized` → `tools/list` → `tools/call`) and, on a `tools/call` of its `review_gate` tool with elicitation available, issues one server→client `elicitation/create` request per active packet decision — the PC-6 stub JSON-RPC shape (bash 3.2 + jq, D-P03-1).
  - Check: `bash tools/verify/m034-p03-mcp-stub.sh`
- Driven over a stubbed transport with injected `action:accept` elicitation responses, the server captures one REVIEW.md block per active decision (delegating to `interactive-review.sh --test-responses`) and populates SIGNOFF.md — SC-6 accept half (D-P03-2).
  - Check: `bash tools/verify/m034-p03-mcp-stub.sh`
- Driven with an injected `action:decline` (the headless auto-decline), the server maps the decline onto the declared auto-mode policy (`defer` → continue-file + `pending_review` JSONL, exit 0) without hanging — SC-6 decline half (D-P03-2 / FR-8).
  - Check: `bash tools/verify/m034-p03-mcp-stub.sh`
- When the `initialize` handshake's client capabilities lack `elicitation` (older Cursor), the server degrades to the `QUESTIONS.md` hand-off via the headless delegation rather than erroring — the spec edge case (D-P03-2).
  - Check: `bash tools/verify/m034-p03-mcp-stub.sh`
- `merge-mcp-config.sh` registers the `orchestrator-review-gate` server in a `.cursor/mcp.json` non-clobbering: a pre-existing operator server entry survives the merge byte-for-byte, the merge is idempotent (a second run leaves exactly one orchestrator entry), an absent file is created with only our entry, and a malformed existing file fails closed without writing — FR-10/CON-6 (D-P03-4).
  - Check: `bash tools/verify/m034-p03-registration.sh`
- `cursor.sh --mcp-config` emits a `.cursor/mcp.json` server-entry JSON fragment naming the review-gate server, and `install-cursor.sh` wires registration through `merge-mcp-config.sh` (the Cursor install path, CON-6).
  - Check: `bash tools/verify/m034-p03-registration.sh`
- `references/RUNTIME-ASSUMPTIONS.md` carries the three interactive-review primitive rows (CC `AskUserQuestion` / Cursor MCP `elicitation/create` / headless `QUESTIONS.md` hand-off) with an `M009 Audit Row` column entry each — FR-14 (SC-9 rows half).
  - Check: `bash tools/verify/m034-p03-runtime-assumptions.sh`
- `references/interactive-review-renderer.md` documents the Cursor-MCP renderer path (the `interactive-cursor` branch the P02 descriptor already emits), naming `elicitation/create` and the accept→REVIEW.md / decline→policy mapping — FR-10/FR-14.
  - Check: `bash tools/verify/m034-p03-runtime-assumptions.sh`
- The byte-parity audit (`m034-p03-byte-parity.sh`) runs the deterministic `interactive-review.sh --test-responses` review-gate path under `ORCH_BACKEND=cursor` AND under the CC default with `ORCH_REVIEW_FIXED_TS` frozen, and asserts SHA-256 byte-equality of both REVIEW.md and SIGNOFF.md; it additionally asserts the MCP-server accept-path output equals the CC `--test-responses` output — FR-15 (SC-9 parity half).
  - Check: `bash tools/verify/m034-p03-byte-parity.sh`
- `interactive-review.sh::_iso_now` honors `ORCH_REVIEW_FIXED_TS` (test-only frozen timestamp seam) while defaulting to `date -u` when unset — the FR-15 byte-equality lever (D-P03-5).
  - Check: `bash tools/verify/m034-p03-byte-parity.sh`
- The phase-suite aggregator runs all four P03 slice verifiers in order and is green only when every slice passes.
  - Check: `bash tools/verify/m034-p03-phase-suite.sh`

### Artifacts

- scripts/lifecycle/review-gate-mcp-server.sh (min 120 lines, contains "elicitation/create")
- scripts/lifecycle/merge-mcp-config.sh (min 40 lines, contains "mcpServers")
- scripts/dispatch/adapters/runtime/cursor.sh (min 200 lines, contains "mcp-config")
- packaging/install/install-cursor.sh (min 200 lines, contains "merge-mcp-config.sh")
- scripts/lifecycle/interactive-review.sh (min 150 lines, contains "ORCH_REVIEW_FIXED_TS")
- references/RUNTIME-ASSUMPTIONS.md (min 80 lines, contains "elicitation/create")
- references/interactive-review-renderer.md (min 30 lines, contains "elicitation/create")
- tools/verify/m034-p03-mcp-stub.sh (min 40 lines, contains "elicitation/create")
- tools/verify/m034-p03-registration.sh (min 30 lines, contains "mcpServers")
- tools/verify/m034-p03-runtime-assumptions.sh (min 20 lines, contains "interactive-review")
- tools/verify/m034-p03-byte-parity.sh (min 30 lines, contains "ORCH_BACKEND")
- tools/verify/m034-p03-phase-suite.sh (min 15 lines, contains "m034-p03")

### Key Links

- scripts/lifecycle/review-gate-mcp-server.sh → scripts/lifecycle/interactive-review.sh (the server delegates ALL writes to the P02 stage — D-P03-2)
- scripts/lifecycle/review-gate-mcp-server.sh → scripts/state/resolve-root.sh (filesystem-scoped state resolution — D-P03-3)
- scripts/lifecycle/review-gate-mcp-server.sh → scripts/knowledge/read-decisions.sh (active-ids in packet order to drive the elicitation loop)
- scripts/dispatch/adapters/runtime/cursor.sh → scripts/lifecycle/review-gate-mcp-server.sh (the --mcp-config entry points at the server)
- packaging/install/install-cursor.sh → scripts/lifecycle/merge-mcp-config.sh (the CON-6 non-clobbering registration stage)
- references/interactive-review-renderer.md → scripts/lifecycle/review-gate-mcp-server.sh (the Cursor-MCP walkthrough path)

## Boundary Map

- **Produces**:
  - `scripts/lifecycle/review-gate-mcp-server.sh` — the orchestrator-owned stdio MCP review-gate server (FR-10): MCP handshake, `review_gate` tool, `elicitation/create` transport, accept→responses-fixture→`interactive-review.sh --test-responses`, decline/cancel/timeout/capability-absent→headless policy delegation (PC-6 / #Q-5 / D-P03-1..3).
  - `scripts/lifecycle/merge-mcp-config.sh` — the CON-6 non-clobbering `.cursor/mcp.json` jq merge (FR-10 / D-P03-4).
  - `--mcp-config` mode on `scripts/dispatch/adapters/runtime/cursor.sh` — emits the `.cursor/mcp.json` server-entry fragment (mirrors `--hook-config`).
  - a registration stage in `packaging/install/install-cursor.sh` — calls the adapter + merge helper (the Cursor install path, CON-6).
  - the `ORCH_REVIEW_FIXED_TS` test-only frozen-timestamp seam in `scripts/lifecycle/interactive-review.sh::_iso_now` (FR-15 byte-equality lever, D-P03-5 — the ONLY P02-deliverable edit).
  - `references/RUNTIME-ASSUMPTIONS.md` interactive-review primitive rows (FR-14) + `references/interactive-review-renderer.md` Cursor-MCP path extension.
  - byte-parity audit fixture + `tools/verify/m034-p03-*.sh` (four slice verifiers + the phase-suite aggregator).
- **Consumes**:
  - P02 `scripts/lifecycle/interactive-review.sh` — `--test-responses` deterministic writer (the accept-path delegate), the headless `--policy` paths (the decline-path delegate), `--review-out`/`--signoff-out` overrides, the PC-3 recorded-response fixture JSON-array shape.
  - P02 `scripts/dispatch/dispatch-interface.sh --probe-renderer` — already returns `interactive-cursor` when `cursor-agent` advertises elicitation AND `ORCH_HEADLESS` unset (the seam the server fronts; no edit needed).
  - P01 `scripts/knowledge/read-decisions.sh active-ids` (packet order for the elicitation loop) + `scripts/knowledge/lib/decisions-constants.sh` (action/policy enums — the server emits only valid enum values into the fixture).
  - M009 Tier-A `.orchestrator/milestones/M009/probe-harness/mcp-elicit-server.py` (PC-6 reference: the message sequence + `{"action":"decline"}` headless auto-decline finding, Addendum (b)); the `.cursor/` install path + the hooks.json non-clobbering discipline (CON-6 model); `scripts/dispatch/adapters/runtime/cursor.sh` `--hook-config` (the `--mcp-config` structural model).
  - `scripts/state/resolve-root.sh` (4-rule state-root resolver — filesystem-scoped state auth, D-P03-3).
  - `.orchestrator/milestones/M034/fixtures/decisions-packet-baseline.md` (the 8-decision packet fixture the stub + byte-parity verifiers drive).

## Tasks

### T01: MCP review-gate server + stub harness (PC-6 / #Q-5 / SC-6) + FIXED_TS seam

Author `scripts/lifecycle/review-gate-mcp-server.sh` (bash 3.2 + jq, D-P03-1): the
MCP stdio handshake, the `review_gate` tool, the `elicitation/create` transport
loop over `read-decisions.sh active-ids`, and the three delegations to
`interactive-review.sh` (accept→`--test-responses` fixture; decline/cancel/timeout
→ headless `--policy`; elicitation-capability-absent→headless QUESTIONS.md
degrade) — D-P03-2/D-P03-3. Add the `ORCH_REVIEW_FIXED_TS` frozen-timestamp seam
to `interactive-review.sh::_iso_now` (D-P03-5). Co-author
`tools/verify/m034-p03-mcp-stub.sh` (SC-6: stubbed-transport accept, decline, and
capability-absent paths; no hang). Full plan: `tasks/T01-mcp-server-and-stub-PLAN.md`.

### T02: Non-clobbering .cursor/mcp.json registration (FR-10 / CON-6)

Author `scripts/lifecycle/merge-mcp-config.sh` (bash + jq, D-P03-4): the
non-clobbering idempotent merge of the `orchestrator-review-gate` entry into
`.cursor/mcp.json` (operator entries preserved; absent-file create; malformed-file
fail-closed). Add the `--mcp-config` mode to
`scripts/dispatch/adapters/runtime/cursor.sh` (emits the server-entry fragment,
mirroring `--hook-config`). Add a registration stage to
`packaging/install/install-cursor.sh` that calls the adapter + merge helper.
Co-author `tools/verify/m034-p03-registration.sh` (FR-10/CON-6: preserve /
idempotent / create / fail-closed + the install-cursor.sh wiring assertion). Full
plan: `tasks/T02-mcp-registration-PLAN.md`.

### T03: RUNTIME-ASSUMPTIONS rows + renderer-doc Cursor path + byte-parity audit (FR-14 / FR-15 / SC-9)

Add the three interactive-review primitive rows to
`references/RUNTIME-ASSUMPTIONS.md` (CC AskUserQuestion / Cursor MCP
elicitation/create / headless QUESTIONS.md, each with an M009 audit-row id) and
extend `references/interactive-review-renderer.md` with the Cursor-MCP renderer
path (FR-14). Author the byte-parity audit verifier
`tools/verify/m034-p03-byte-parity.sh` (FR-15): run the deterministic
`interactive-review.sh --test-responses` path under `ORCH_BACKEND=cursor` and
under the CC default with `ORCH_REVIEW_FIXED_TS` frozen, assert SHA-256 equality
of REVIEW.md + SIGNOFF.md, and assert the MCP-server accept output equals the CC
`--test-responses` output. Co-author `tools/verify/m034-p03-runtime-assumptions.sh`
(FR-14 rows + renderer-doc tokens). Full plan:
`tasks/T03-runtime-assumptions-and-byte-parity-PLAN.md`.

### T04: Phase-suite aggregator (m034-p03-phase-suite.sh)

Author `tools/verify/m034-p03-phase-suite.sh` — the single entry point
`orchestrator:verify P03` resolves to. It runs the four P03 slice verifiers
(`mcp-stub`, `registration`, `runtime-assumptions`, `byte-parity`) in order
(`bash <path>`, never run-probe — plan-time discipline rule 4), prints each one's
output, and is green only when every slice exits 0. Mirrors the P02 T06 suite
shape. Full plan: `tasks/T04-phase-suite-PLAN.md`.

## Task Dependencies

```
T01 ─▶ T02
  │
  ├─▶ T03
  │
T01..T03 ─▶ T04
```

T01 ships the server + the FIXED_TS seam every later task builds on. T02
(registration) references the server path but is otherwise independent of its
internals. T03 (byte-parity) drives the server's accept path (T01) + the
FIXED_TS seam (T01). T04 aggregates all three slice verifiers, so it is last.

## Files Likely Touched

- scripts/lifecycle/review-gate-mcp-server.sh (create)
- scripts/lifecycle/merge-mcp-config.sh (create)
- scripts/lifecycle/interactive-review.sh (modify — add ORCH_REVIEW_FIXED_TS seam to _iso_now)
- scripts/dispatch/adapters/runtime/cursor.sh (modify — add --mcp-config mode)
- packaging/install/install-cursor.sh (modify — add MCP registration stage)
- references/RUNTIME-ASSUMPTIONS.md (modify — add interactive-review primitive rows)
- references/interactive-review-renderer.md (modify — add Cursor-MCP renderer path)
- tools/verify/m034-p03-mcp-stub.sh (create)
- tools/verify/m034-p03-registration.sh (create)
- tools/verify/m034-p03-runtime-assumptions.sh (create)
- tools/verify/m034-p03-byte-parity.sh (create)
- tools/verify/m034-p03-phase-suite.sh (create)
