---
schema_version: "1.0"
type: pre-planning-addendum
milestone: "M034"
phase: "P00"
created_at: "2026-06-06"
resolves: ["PC-1", "PC-2", "#Q-1"]
spec_ref: "specs/044-interactive-review-gates/spec.md"
---

# M034 P00 — Pre-Planning Addendum

Resolves the two P0 pre-planning conditions (PC-1, PC-2) and #Q-1 supersede
semantics so P01 starts zero-context-complete. Conditions are quoted from
`specs/044-interactive-review-gates/spec.md` "Pre-Planning Conditions" section;
the deliberation that produced them is `conversus/summary/final.md` +
`conversus/arbiter/resolution.md`.

---

## PC-1 — write-decisions.sh calling convention

**Condition (spec PC-1, P0, MIT-1/RISK-1):** specify the wire format for passing
LLM-generated multi-field decision content to the future `write-decisions.sh`
(FR-2), the milestone-id/output-path argument encoding, and the multi-line-field
escaping contract — such that a second author following only the spec produces an
identical SC-1 fixture.

### Prior-art baseline — write-summary.sh

Inspected `scripts/knowledge/write-summary.sh` (the FR-2 model):

- Positional shape `write-summary.sh <type> <output-file> --<field>=<value> ...`
  (`write-summary.sh:24-25`, `:49-51`). Output to a path or `-` for stdout
  (`:218-225`).
- Fields arrive as `--field=value` flags parsed into bash-3.2 parallel arrays
  (`:76-107`) — no `declare -A` (K001/CON-1).
- **Crucially**, write-summary already solved the multi-line-body problem with a
  `--<field>-file=<path>` convention that reads a field body *from a file* to
  "avoid multiline quoted CLI args for long bodies (AD-19 shape safety)"
  (`write-summary.sh:78-93`).

`write-summary.sh` writes **one** record with a **fixed** field set. The decisions
packet (FR-1) is an **array** of entries, each with seven fields, of which four
(`rationale`, `alternatives_considered`, `concrete_impact`, `summary`) are
free-text passages that can carry newlines, quotes, and shell metacharacters. The
per-field-file trick does not scale to an array (it would need one temp file per
field per entry, with no array framing). RISK-1's named failure mode — a 400-char
`alternatives_considered` passed as a positional/flag argument — is exactly what a
flat `--field=` convention cannot survive.

### Decision (binding) — stdin-fed JSON document

`write-decisions.sh` receives the full FR-1 entry **array** as a single JSON
document **on stdin**. This is the array-native analog of write-summary's
per-field-file (one structured parse instead of N temp files) and is the conversus
arbiter's MIT-1 recommendation.

**Invocation:**

```
write-decisions.sh --milestone=<M> --artifact=<primary-artifact-path> --out=<packet-path>  < entries.json
```

- `--out=-` writes the packet to stdout (mirrors write-summary's `-` sentinel).
- Non-content parameters (`--milestone`, `--artifact`, `--out`) are flag arguments
  that only ever carry ids and filesystem paths — never free text — so they are
  shell-safe as ordinary `--field=value` flags (same parser shape as
  write-summary's `--*=*` branch).

**stdin wire format:**

```json
{
  "decisions": [
    {
      "id": "D-1",
      "summary": "...",
      "picked_value": "...",
      "rationale": "...",
      "alternatives_considered": "...",
      "concrete_impact": "...",
      "severity": "block",
      "type": "decision"
    }
  ]
}
```

- One object per load-bearing decision under the top-level `decisions` key.
- Object keys are **exactly** the FR-1 field names (`id`, `summary`,
  `picked_value`, `rationale`, `alternatives_considered`, `concrete_impact`,
  `severity`, `type`). No aliases.
- `severity ∈ {warn, block}` (default `block`); `type ∈ {decision,
  boundary_translation}` (default `decision`) — per FR-1. The writer applies the
  defaults when a key is absent.

**Escaping contract:** *none required of the emitting agent for field bodies.*
JSON encoding carries newlines, quotes, and shell metacharacters losslessly. The
writer extracts each field with `jq -r` and writes the body into the markdown
template via `printf '%s'` / a quoted variable expansion — it **never**
re-shell-interprets a field body (no `eval`, no unquoted re-expansion). This is
the property RISK-1 demanded.

**Parser dependency:** `write-decisions.sh` uses `jq` to parse the stdin document.
Unlike `write-summary.sh` (pure bash, flat fields), the structured multi-entry
array justifies jq — it is already a declared orchestrator dependency (CLAUDE.md
Active Technologies: "jq (optional, JSON parsing in scripts)"). **P01 packaging
note:** jq moves from optional to *required* for `write-decisions.sh`
specifically; P01 must surface a clear "jq required" error if absent (consistent
with the FR-12 strict-when-declared posture for missing tooling).

**LLM-instruction-template contract:** the emitting agent (the artifact-authoring
task with `decision_packet: true`) MUST produce exactly the `{"decisions": [ ... ]}`
document above — top-level `decisions` array, one object per decision, the eight
FR-1 keys per object, `severity`/`type` from their enums. The P01 instruction
template and the `write-decisions.sh` jq parser are authored against this one
shape so a second author reproduces an identical SC-1 fixture.

**Supersede interaction (see #Q-1):** the writer computes a per-entry
`content_hash` over the field bodies for idempotent re-emit; unchanged entries are
no-ops, changed entries append a superseding entry. The stdin contract is
unchanged by this — supersede is a writer-side concern, not an input-shape concern.

---

## PC-2 — CC renderer execution context (RISK-5)

**Condition (spec PC-2, P0, MIT-2/RISK-5):** inspect the CC dispatch backend +
`dispatch-interface.sh` and resolve **Case A** (renderer runs in the
already-interactive top-level CC session, issues `AskUserQuestion` directly) vs
**Case B** (routes through a spawned `claude -p` subagent). If no CC path surfaces
`AskUserQuestion` interactively, RISK-5 escalates to a standalone P0 blocker and
US2/FR-6 are amended before P01. Also specify the `REVIEW.md` write path.

> **Note on the cited path.** The spec/arbiter named the CC backend
> `scripts/dispatch/adapters/backend/cc.sh`. **That file does not exist** — it was
> a confabulation. The actual Claude Code dispatch backend is
> `scripts/dispatch/adapters/backend/local-agent.sh`. This addendum inspects the
> real file.

### Evidence (file:line)

Inspected `scripts/dispatch/adapters/backend/local-agent.sh` in full:

- **Normal mode spawns no subprocess.** Lines `67-145` validate inputs, extract
  ids from the task-plan frontmatter, and emit a `dispatch-result.md`-conforming
  document via `cat <<EOF` (`local-agent.sh:98-143`), then `exit 0`. There is no
  `claude -p`, no fork, no exec.
- **It is an in-process coordination boundary.** The header (`:2-15`) and the
  emitted Notes section (`:133-143`) state, per MEM018: "the Agent tool cannot be
  invoked directly from a shell script; it is an in-process capability of the
  orchestrating agent runtime." The adapter emits a descriptor whose Notes
  *instruct the orchestrating agent layer to perform the Agent invocation
  in-process.*
- **Probe mode** (`:51-65`) reports `available=true` when `SPECKIT_AGENT_TOOL=1`
  or a `.claude/` directory is present — i.e. when the orchestrating runtime *is*
  Claude Code.

Inspected `scripts/dispatch/dispatch-interface.sh`:

- Backends are **filename-routed** from `ADAPTERS_DIR="${SCRIPT_DIR}/adapters/backend"`
  (`dispatch-interface.sh:34`, doc `:24`). The CC backend resolves to
  `local-agent.sh`.
- `grep -n 'claude -p'` → **no matches** anywhere in `dispatch-interface.sh` or in
  any file under `scripts/dispatch/adapters/backend/`.
- `grep -n 'AskUserQuestion'` → **no matches** in the dispatch layer — bash never
  calls the question primitive (consistent with AD-3's two-layer model).
- Backend roster: `local-agent.sh` (CC), `cursor-agent.sh` (Cursor),
  `local-codex.sh` (Codex), `stub*.sh` (test). The **only** Claude Code backend is
  `local-agent.sh`, and it is in-process.

**Direct runtime corroboration:** this determination was made *from* the top-level
interactive Claude Code session (the orchestrating agent layer), which has
`AskUserQuestion` available as a live tool. The orchestrating layer that
local-agent.sh hands control back to is precisely the interactive context.

### Determination — Case A. RISK-5 CLEARED.

The `interactive_review` lifecycle stage (FR-5) is **not** a spawned task-unit
dispatch. Its CC renderer resolves — through the same in-process coordination
boundary `local-agent.sh` defines — to the **orchestrating agent layer issuing
`AskUserQuestion` directly**. Because there is no `claude -p` in the CC dispatch
path, `AskUserQuestion` executes in the already-interactive top-level session and
reaches the operator's terminal. This is consistent with **AD-3** (two-layer
dispatch: bash selects the runtime context; the agent executing in that context
issues the question primitive).

**RISK-5 does not escalate.** No spec amendment to US2/FR-6 is required. P01 may
proceed on the Case A assumption.

### REVIEW.md write-path contract — agent-writes-directly

Because the CC renderer **is** the orchestrating agent (in-process, Case A), the
agent that issues `AskUserQuestion` **writes `REVIEW.md` directly** (append-only),
co-located with the packet as `<artifact>-REVIEW.md` (#Q-2 defaulted:
decisions-co-located). The split:

- **Interactive CC path:** `interactive-review.sh` selects the renderer context
  (via `dispatch-interface.sh`) and emits a render-descriptor — the same
  coordination-boundary pattern as `local-agent.sh`. The orchestrating agent then
  surfaces each decision via `AskUserQuestion`, appends one `REVIEW.md` block per
  response, and on the terminal block populates `SIGNOFF.md`. No return-marshalling
  layer — the in-process agent has direct file-write capability.
- **Non-interactive paths** (`defer` / `accept-with-audit` / `refuse-entry` /
  headless `QUESTIONS.md`): `interactive-review.sh` (bash) writes `REVIEW.md`
  itself, because in those paths the full content is deterministic and no question
  primitive is issued.

This split is the seam PC-3 (SC-3 simulation harness, P01) injects recorded
operator responses into — at the agent layer for the interactive path.

---

## #Q-1 — packet supersede semantics

**Question (spec #Q-1):** how do packet entries version across re-runs of an
artifact-authoring task — supersede-in-place vs append-with-supersede-chain
(mirroring M036's supersede mechanism)? (On the PC-1 critical path; resolves the
tolerated RISK-7 SC-1-re-run underdetermination.)

### Decision (binding) — append-with-supersede-chain

Packet re-emission **appends** a superseding entry rather than overwriting in
place, mirroring M036's reference-corpus supersede chain.

**Mechanism:**

- The writer computes a per-entry `content_hash` over the field bodies.
- On re-run: an entry whose `content_hash` matches its prior counterpart is an
  **idempotent no-op** (no new record written).
- An entry whose content changed is **appended** carrying `supersedes:
  <prior-entry-id>`; the prior entry is marked `superseded_by: <new-entry-id>`.
  Both remain in the file.

**Rationale:**

- **Auditability (Principle VI — state on disk is truth).** A sign-off review gate
  exists to preserve *what was decided and how it changed*. In-place overwrite
  destroys the record that decision D-3's `picked_value` moved from X to Y between
  runs — the exact history the gate is meant to surface. The prior `REVIEW.md`
  adjudication against the superseded entry is preserved alongside it.
- **Consistency with M036.** The codebase already has one supersede-chain mental
  model (reference-corpus); reusing it avoids a second divergent mechanism
  (CON-4-style SSOT-of-mechanism).
- **Bounded cost.** Only *changed* entries append; unchanged entries are no-ops.

**RISK-7 resolution (SC-1 re-run case):** SC-1's "one typed entry per load-bearing
decision" is read as **one *active* (non-superseded) entry per decision**.
Superseded entries remain in the file marked `superseded_by:` and are excluded from
the FR-4 unreviewed-decision count and from `status`/`doctor` surfacing.

**Tradeoff accepted:** the packet file grows across re-runs and readers must filter
to active entries. This is the correct tradeoff for an audit artifact; the
alternative (smaller, history-free files) defeats the gate's purpose.

---

## P00 close

PC-1 (stdin-JSON convention) and PC-2 (Case A, RISK-5 cleared, agent-writes
REVIEW.md) are both resolved with no spec amendment required; #Q-1 is decided
(append-with-supersede-chain). The representative fixture
(`fixtures/decisions-packet-baseline.md`) and the phase verifier
(`tools/verify/m034-p00-addendum.sh`) accompany this addendum. **P01 is unblocked.**
