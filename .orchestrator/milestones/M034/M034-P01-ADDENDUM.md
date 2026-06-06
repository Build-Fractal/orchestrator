---
schema_version: "1.0"
type: planning-addendum
milestone: "M034"
phase: "P01"
created_at: "2026-06-06"
resolves: ["PC-3", "PC-4", "PC-5"]
verified_in: "P02"
spec_ref: "specs/044-interactive-review-gates/spec.md"
---

# M034 P01 — Forward-Design Addendum (PC-3 / PC-4 / PC-5)

Authored at P01 plan-time (with the full M034 context in hand) so P02 starts
zero-context-complete. These three P1 pre-planning conditions govern P02's
surfaces — the interactive walkthrough, the headless fallback, and the
`defer`→`orchestrator:resume` round-trip — none of which P01 builds. Per the
P01 split decision (`phases/P01/P01-PLAN.md` § Phase Scope), they are
**SPECIFIED here** and **VERIFIED in P02** (SC-3/SC-4/SC-5 are P02 success
criteria). Conditions are quoted from the spec's "Pre-Planning Conditions"
section; the consuming phase is P02.

These build on P00's PC-2 **Case A** determination: the CC renderer runs in the
already-interactive top-level orchestrating agent layer and issues
`AskUserQuestion` directly, and the agent **writes `REVIEW.md` directly** on the
interactive path (`M034-P00-ADDENDUM.md` § PC-2). The harness seams below inject
at that agent layer.

---

## PC-3 — SC-3 simulation harness (synthetic operator responses)

**Condition (spec PC-3, P1, MIT-3/RISK-2):** specify the synthetic-operator-
response harness (option A: recorded-response fixtures injected as prompt
overrides; option B: mock-dispatch intercept as fallback), the fixture format,
the `interactive-review.sh` test-mode flag, and the `REVIEW.md`/`SIGNOFF.md`
assertions — so SC-3 runs deterministically in CI with no human.

### Decision (binding for P02) — option A: recorded-response fixtures

**Primary: recorded-response fixtures injected at the agent layer.** Because
PC-2 resolved Case A (the orchestrating agent issues `AskUserQuestion` and
writes `REVIEW.md` directly), the deterministic seam is a recorded-response
fixture the agent consumes *instead of* prompting. `interactive-review.sh`
carries a test-mode flag; when set, the stage (and the agent-layer renderer it
coordinates) reads operator responses from the fixture rather than issuing the
live question primitive.

**Test-mode flag:** `interactive-review.sh --test-responses=<path>` (env
equivalent `ORCH_REVIEW_RESPONSES=<path>` for entry points that cannot pass
flags). When unset, the stage runs live (real `AskUserQuestion`). When set, it
runs deterministically with no human and no question primitive issued.

**Fixture format** — a JSON array, one object per decision id, consumed in
packet order:

```json
[
  { "id": "D-1", "action": "accept" },
  { "id": "D-2", "action": "override", "value": "<new picked_value>", "rationale": "<why>" },
  { "id": "D-5", "action": "pushback", "rationale": "<concern>" },
  { "id": "D-7", "action": "na", "rationale": "<heuristic false-positive>" }
]
```

- `action ∈ {accept, override, pushback, na}`. `accept` records agreement;
  `override` carries `value` + `rationale` (captured verbatim — the SC-3
  "override captured verbatim" assertion); `pushback` records a concern without
  changing the value; `na` marks a `boundary_translation` false-positive
  acknowledged-not-applicable (FR-13 edge case).
- An id present in the packet but absent from the fixture defaults to `accept`
  with a `defaulted: true` audit marker (so a partial fixture is still
  deterministic).

**Fallback (option B): mock-dispatch intercept.** If option A proves
non-deterministic (e.g. the agent layer cannot be reliably forced to read the
fixture in a given runtime), fall back to a stub renderer registered through
`dispatch-interface.sh`'s renderer-selection seam that returns the recorded
responses without involving the agent's live question primitive. Option B is the
contingency; build option A first.

**Assertions (SC-3, verified in P02):**
1. Driving `interactive-review.sh --test-responses=<fixture>` against a packet
   fixture appends exactly one `REVIEW.md` block per packet decision, in packet
   order, each recording the fixture's `action`.
2. An `override` entry's `value` + `rationale` appear verbatim in its
   `REVIEW.md` block.
3. `SIGNOFF.md` is populated from `REVIEW.md`'s terminal entry (the CON-5/SC-5
   always-write invariant holds — the packet + REVIEW.md are written regardless).
4. The run is hermetic: no human prompt, no network, deterministic across runs.

---

## PC-4 — headless detection mechanism

**Condition (spec PC-4, P1, MIT-4/RISK-4):** specify how `interactive-review.sh`
detects "no interactive primitive available," the states it distinguishes, and
how CI/`auto` entry points set that state for SC-5.

### Decision (binding for P02) — `dispatch-interface.sh` capability probe over a bare `ORCH_HEADLESS=1`

**Mechanism.** `interactive-review.sh` resolves the renderer context through a
`dispatch-interface.sh` capability probe (CON-7 — never a direct primitive
call). The probe returns one of three interactive-surface states; the bare
env override `ORCH_HEADLESS=1` forces the headless state unconditionally
(highest precedence) so CI and `auto` are deterministic.

**States distinguished:**

| State | Detected when | Renderer (P02/P03) |
|-------|---------------|--------------------|
| `interactive-cc` | orchestrating runtime is Claude Code with the Agent tool live (`SPECKIT_AGENT_TOOL=1` or a `.claude/` dir present, per `local-agent.sh:51-65`) AND `ORCH_HEADLESS` unset | CC `AskUserQuestion` (FR-6) |
| `interactive-cursor` | Cursor runtime advertises MCP elicitation (`capabilities.elicitation.form` present) AND `ORCH_HEADLESS` unset | Cursor MCP `elicitation/create` (FR-10, P03) |
| `headless` | `ORCH_HEADLESS=1`, OR a headless `cursor-agent -p` run whose elicitation auto-declines, OR Claude Code with no interactive surface | `QUESTIONS.md` hand-off + declared auto-mode policy (FR-9) |

**Precedence:** `ORCH_HEADLESS=1` > runtime capability probe. Absent the env, the
probe interrogates the active backend via `dispatch-interface.sh` (the same
filename-routed backend roster the dispatch layer already uses:
`local-agent.sh`/`cursor-agent.sh`/`local-codex.sh`).

**How CI / `auto` set the state (SC-5):**
- CI and the SC-5 hermetic harness export `ORCH_HEADLESS=1` → forces `headless`
  → the stage writes `QUESTIONS.md` and applies the declared policy, never
  hangs (the watchdog never fires).
- `orchestrator:auto` exports `ORCH_HEADLESS=1` before entering any gated phase
  (no human in an autonomous loop), so the gate takes the `defer` path (or the
  per-gate `accept-with-audit`/`refuse-entry` override) deterministically.

---

## PC-5 — continue-file schema + `orchestrator:resume` surface

**Condition (spec PC-5, P1, MIT-5/RISK-6):** specify the continue-file schema
(≥ `milestone_id`, `phase_id`, `gate_id`, `last_review_md_block_index`,
`declared_policy`), its location under `.orchestrator/milestones/<M>/`, and the
`orchestrator:resume` (M029) state-scan modification for the `pending-review`
type. SC-4 extends to the full defer→resume round-trip.

### Decision (binding for P02) — continue-file schema

**Location:** `.orchestrator/milestones/<M>/phases/<P>/<gate_id>-CONTINUE.md`
(co-located with the gated phase, mirroring the `<P>-PLAN.md`/`<P>-SUMMARY.md`
convention; one continue-file per pending gate).

**Schema (YAML frontmatter; the five required keys + audit context):**

```yaml
---
schema_version: "1.0"
type: pending-review-continue
milestone_id: "M###"            # required
phase_id: "P##"                 # required
gate_id: "<gate name from review_gates[]>"   # required
last_review_md_block_index: 0   # required — count of REVIEW.md blocks already written
declared_policy: "defer"        # required — defer|accept-with-audit|refuse-entry
created_at: "<iso>"
packet_path: ".orchestrator/milestones/M###/phases/P##/<artifact>-DECISIONS.md"
review_md_path: ".orchestrator/milestones/M###/phases/P##/<artifact>-REVIEW.md"
status: "pending-review"
---
```

- `last_review_md_block_index` is the count of `REVIEW.md` blocks already
  appended at defer time. On resume the walkthrough re-enters at
  `index+1` — re-entry at the recorded position, **not** a restart (the
  "operator answers, then crash before SIGNOFF" edge case + MIT-5).
- Written atomically (tmpfile + `mv`) when the `defer` policy fires, alongside
  the `pending-review` JSONL event on the milestone execution-log.

**`orchestrator:resume` (M029) state-scan modification:** `orchestrator:resume`
already distinguishes a graceful pause (continue file present) from a crash
(stale lock). Extend its state scan to recognize the new `type:
pending-review-continue` continue-file: when found, route recovery to
`interactive-review.sh --resume=<continue-file>`, which reads
`last_review_md_block_index` and resumes the walkthrough at the next unanswered
decision rather than re-prompting answered ones. This is additive to the M029
resume surface — the existing pause/crash branches are unchanged.

**SC-4 extension (verified in P02):** the full round-trip — a `defer`-policy gate
under `ORCH_HEADLESS=1`/`auto` writes the continue-file + `pending-review` JSONL
and exits 0; a subsequent `orchestrator:resume` consumes the continue-file and
re-enters `interactive-review.sh` at `last_review_md_block_index`, completing the
remaining decisions and populating `SIGNOFF.md`. Not just "continue-file written"
— the re-entry-at-recorded-position behavior is asserted.

---

## P01 carry-forward

PC-3 (recorded-response fixture harness + `--test-responses` flag), PC-4
(`dispatch-interface.sh` probe over `ORCH_HEADLESS=1`, three interactive-surface
states), and PC-5 (`<gate_id>-CONTINUE.md` schema + `orchestrator:resume`
`pending-review` state-scan extension) are specified. They are **not** built in
P01 — P01 ships the schema, writer, producer, and surfacing only. P02 consumes
this addendum as its binding entry condition and verifies SC-3 / SC-4 / SC-5
against these decisions.
