---
schema_version: "1.0"
type: phase-plan
phase: "P06"
milestone: "M024"
goal: "Revision flow — replace P03's surface-only `revise` verb with a real full-re-emit path that applies axis overrides, re-derives dependent axes, preserves the prior proposal as `proposal-v<N>.md`, and re-prompts the operator for approval."
demo_sentence: "An operator who reads a proposal that landed at Tier B and types `orchestrator:evaluate revise --proposal <path> --axis scope_tier --value C` sees the prior `.orchestrator/intake/<id>/proposal.md` archived as `proposal-v1.md`, a freshly emitted `proposal.md` with `scope_tier: \"C\"` plus dependent axes (`decomposition`, `recommended_command`) re-derived, and `pending_approval: true` so the operator must re-approve before any downstream command runs."
risk: "low"
depends_on: ["P01", "P03"]
---

## Resolution Of #Q-6 (revision-mutates-vs-clones)

Per the planning-payload tasking and FR-12's commitment, P06 ships **in-place mutation** with version-suffix preservation. The existing `<id>` is preserved; the prior `proposal.md` is renamed to `proposal-v<N>.md` (where `<N>` is the next free integer in the same intake directory), and the new `proposal.md` is the latest. Allocating a new `<id>` per revision is explicitly rejected — it would orphan the original Q&A transcript, [M014](../../../../milestones/M014/index.md) handshake feature_slug, and any operator-affixed evidence pointers, all of which need to remain reachable from one canonical directory for audit. Version cloning (e.g. `proposal-v2.md` is the new file and the prior `proposal.md` stays unchanged) is also rejected — operators reading "the proposal" should always see the latest at the un-suffixed path so cross-tool links don't go stale on every revision.

Numbering rule: the first revision archives `proposal.md` to `proposal-v1.md` and writes the new content to `proposal.md`. The second revision archives the then-current `proposal.md` to `proposal-v2.md` (NOT `proposal-v1.md` — the v1 already exists). The allocator probes `proposal-v*.md` for the highest existing `<N>` and uses `<N>+1`. This makes the version sequence a strict append-only history that mirrors the [M020](../../../../milestones/M020/index.md) `decision_history:` append-only invariant (MEM031).

## Resolution Of #Q-7 Adjacency

The auto-proceed config scope (#Q-7, FR-3) is project-wide per P04's existing wiring. P06's revision flow inherits that disposition unchanged: a revised proposal that *re-classifies* into the four-condition fast-path will auto-proceed only if `evaluate.auto_proceed: true` (default); the operator's prior approval state on `proposal-v<N>.md` is not carried forward to the new `proposal.md`, which always lands with `pending_approval: true` (or auto-proceeds via P04 if eligible — never silently approves on the operator's behalf).

## Boundary

- **Produces**:
  - `scripts/intake/revise.sh` — the user-facing revision driver. Accepts `--proposal <path>` plus one or more `--axis <name> --value <value>` pairs, archives the prior proposal as `proposal-v<N>.md`, and re-invokes the emitter with axis overrides applied. Pure orchestration over T02 + the existing emitter; writes only inside `.orchestrator/intake/<id>/`.
  - `scripts/intake/axis-rederive.sh` — pure decision emitter that, given a primary-axis override (`scope_tier=C`), emits the recomputed dependent-axis values (`decomposition`, `recommended_command`, and where applicable `intensity`) per the same rules the paragraph and spec deep classifiers apply at first emission. Stdout-only; no file writes.
  - `scripts/intake/proposal-emit.sh` (modify) — extended with a `--axes-from <file>` flag that loads pre-decided axis values from a key=value file and stamps them into the proposal frontmatter, bypassing the deep-classifier branches when present (so a revision can pin overrides + their re-derived companions without re-running paragraph/spec/qa classification). A new `REVISE_AXES_DONE=1` flag mirrors P02's `SPEC_AXES_DONE`, P03's `PARA_AXES_DONE`, P04's `FAST_PATH_AXES_DONE`, and P05's `QA_AXES_DONE` so the rationale loop skips the overridden axes (preserving FR-13 honesty — the rationale slot for an overridden axis cites "operator revision via revise.sh" + the prior version's rationale, not a fabricated stub).
  - `scripts/intake/approval-gate.sh` (modify) — `revise` verb is upgraded from P03's surface-only stdout pass-through to a real wired call into `scripts/intake/revise.sh`. Stdout contract changes from `revision_pending=true axis=<a> value=<v>` to `revised_to=<new-proposal-path>` (FR-12 — body lands in P06). The P03 stdout shape stays as a backward-compat alias when `--no-apply` is passed (test-only flag for unit assertions over the verb's argument parsing).
  - `tests/test-revision-flow.sh` — end-to-end: emit a paragraph proposal at Tier B → `revise --axis scope_tier --value C` → assert prior is archived as `proposal-v1.md`, current `proposal.md` has `scope_tier: "C"`, dependent axes re-derived, `pending_approval: true`, transcript / Q&A sections (if present) preserved verbatim across the version snapshot.
  - `tests/test-revision-version-preservation.sh` — exercises the version-suffix scheme across two consecutive revisions: assert `proposal-v1.md` and `proposal-v2.md` both exist after the second revise; assert `proposal.md` is the latest content; assert `proposal-v1.md` is byte-identical to the first emit.
  - `scripts/verify/m024-p06-axis-rederive.sh`, `scripts/verify/m024-p06-revise-script.sh`, `scripts/verify/m024-p06-version-suffix.sh`, `scripts/verify/m024-p06-axes-from-flag.sh`, `scripts/verify/m024-p06-approval-gate-revise-wired.sh`, `scripts/verify/m024-p06-rederive-rationale.sh`, `scripts/verify/m024-p06-write-confinement.sh`, `scripts/verify/m024-p06-evaluate-md.sh`, `scripts/verify/m024-p06-suite.sh` — eight per-claim verifies plus the suite runner.
  - One-line update in `commands/evaluate.md` — the `revise` verb description shifts from "P03 surface-only — full re-emit lands in P06" to "wired in P06 — full re-emit with version-suffix preservation".
- **Consumes**:
  - P01 proposal schema (`templates/intake-proposal.md` 25-key frontmatter — `pending_approval`, `approved_at`, `cancelled_at` reset semantics live here).
  - P01 `scripts/intake/proposal-emit.sh` (revise.sh re-invokes the emitter with `--axes-from <file>`; axis-rederive.sh outputs feed that file).
  - P03 `scripts/intake/approval-gate.sh` `revise` verb argument parser (preserved; only the post-parse handler is upgraded).
  - P03 `scripts/intake/paragraph-classify.sh` decomposition + recommended_command rules (axis-rederive.sh re-applies the same rules — does NOT re-author them; the rules live in one place per D019).
  - P02 `scripts/intake/spec-shape-classify.sh` for the same reason (spec-shape revisions of `scope_tier` → re-derive `decomposition` + `recommended_command` per the spec rules).
  - Spec FR-12, FR-14 (idempotency: revising with the same axis=value pair on the same proposal twice is a no-op — second revise exits 0 with `revised=false reason=identical-axes`), #Q-6 (resolved above), edge case "Re-running `evaluate` on the same input" (the version-suffix invariant + `pending_approval: true` reset honor it).

## M024/P06 → P07 Forward Wiring (informational)

- **P07 (design-gate degradation)**: when an operator revises `design_gate` from `none` to `walkthrough` on a pre-M023 checkout, the proposal must surface the FR-7 graceful-degradation message ("design walkthrough lands in M023; author DESIGN.md manually or skip"). P06 produces the substrate (revised proposal carrying `design_gate: "walkthrough"`); P07 owns the post-revision degradation message. P06 must therefore allow the `design_gate` axis as a valid revision target without enforcing M023 readiness — the `manual` / `skip` branch is P07's responsibility.

## Must-Haves

### Truths

- `scripts/intake/axis-rederive.sh` is executable, accepts `--axis <name> --value <value> --proposal <path>` (the proposal supplies the input_shape so the right rule table is consulted), and emits stdout key=value lines for every dependent axis recomputed (`decomposition=<v>`, `recommended_command=<v>`, optionally `intensity=<v>`). For overrides on independent axes (e.g., `conversus_gate=tdd-prone`) it emits no rederive lines and exits 0 with a stderr note `note=axis is independent — no dependents`.
  - Check: `bash scripts/verify/m024-p06-axis-rederive.sh`
- `scripts/intake/revise.sh` is executable, accepts `--proposal <path>` plus one or more `--axis <name> --value <value>` pairs (repeatable), archives the prior `proposal.md` to `proposal-v<N>.md` (next-free-N in the same directory), invokes `scripts/intake/proposal-emit.sh --axes-from <tmp>` with both the operator overrides and the rederive-script outputs merged into `<tmp>`, and emits `revised_to=<new-proposal-path>` to stdout on success.
  - Check: `bash scripts/verify/m024-p06-revise-script.sh`
- `scripts/intake/revise.sh` honors the version-suffix scheme: the first revise produces `proposal-v1.md` (archived prior content) + `proposal.md` (new content); the second revise produces `proposal-v2.md` + `proposal.md`; the existing `proposal-v1.md` is never touched. The allocator scans `proposal-v*.md` for the highest existing N and emits `<N>+1`.
  - Check: `bash scripts/verify/m024-p06-version-suffix.sh`
- `scripts/intake/proposal-emit.sh` accepts a new `--axes-from <file>` flag whose file is one `key=value` pair per line covering any subset of `{scope_tier, decomposition, design_gate, conversus_gate, intensity, recommended_command}`; values from the file overwrite both the P01 stub axes and any deep-classifier output; the rationale-loop sees a `REVISE_AXES_DONE=1` flag for every axis present in the file and skips the corresponding rationale slot (the slot is filled by revise.sh post-emit instead).
  - Check: `bash scripts/verify/m024-p06-axes-from-flag.sh`
- `scripts/intake/approval-gate.sh`'s `revise` verb is wired to call `scripts/intake/revise.sh` and emit `revised_to=<new-proposal-path>` to stdout (replacing the P03 surface-only `revision_pending=true ...` line). The legacy P03 stdout shape is preserved under a `--no-apply` test-only flag so the P03 tests stay green.
  - Check: `bash scripts/verify/m024-p06-approval-gate-revise-wired.sh`
- The rationale slots for axes touched by a revision cite "operator revision (revise.sh) — see proposal-v<N>.md for prior rationale" — never a fabricated stub. Independent axes not touched by the revision retain their prior rationale verbatim from `proposal-v<N>.md` so the operator can read what the original classifier said.
  - Check: `bash scripts/verify/m024-p06-rederive-rationale.sh`
- All P06-introduced shell scripts respect SB-3 write-confinement: writes target only `.orchestrator/intake/<id>/` (proposal + version-suffix archives + body mutations) and `/tmp` (test scratch + axes-from scratch). The axis-rederive.sh script writes nothing.
  - Check: `bash scripts/verify/m024-p06-write-confinement.sh`
- `commands/evaluate.md` `revise` verb description names the wired full-re-emit behavior — the literal string "wired in P06" appears in the verb table or its surrounding paragraph; the FR-12 commitment is described in one sentence pointing at `scripts/intake/revise.sh`.
  - Check: `bash scripts/verify/m024-p06-evaluate-md.sh`
- The P06 phase suite (the two phase-level tests + every per-task verify) exits 0 on a clean checkout.
  - Check: `bash scripts/verify/m024-p06-suite.sh`

### Artifacts

- scripts/intake/axis-rederive.sh (min 60 lines, contains "decomposition")
- scripts/intake/revise.sh (min 90 lines, contains "proposal-v")
- scripts/intake/proposal-emit.sh (min 400 lines, contains "axes-from")
- scripts/intake/approval-gate.sh (min 170 lines, contains "revised_to")
- commands/evaluate.md (min 200 lines, contains "wired in P06")
- tests/test-revision-flow.sh (min 60 lines, contains "scope_tier")
- tests/test-revision-version-preservation.sh (min 50 lines, contains "proposal-v2")
- scripts/verify/m024-p06-axis-rederive.sh (min 30 lines, contains "decomposition")
- scripts/verify/m024-p06-revise-script.sh (min 30 lines, contains "revised_to")
- scripts/verify/m024-p06-version-suffix.sh (min 30 lines, contains "proposal-v2")
- scripts/verify/m024-p06-axes-from-flag.sh (min 30 lines, contains "axes-from")
- scripts/verify/m024-p06-approval-gate-revise-wired.sh (min 30 lines, contains "revised_to")
- scripts/verify/m024-p06-rederive-rationale.sh (min 30 lines, contains "operator revision")
- scripts/verify/m024-p06-write-confinement.sh (min 20 lines, contains "intake")
- scripts/verify/m024-p06-evaluate-md.sh (min 20 lines, contains "wired in P06")
- scripts/verify/m024-p06-suite.sh (min 15 lines, contains "test-revision-flow")

### Key Links

- scripts/intake/revise.sh → scripts/intake/axis-rederive.sh (revise.sh invokes axis-rederive.sh once per operator-supplied override to recompute dependent axes)
- scripts/intake/revise.sh → scripts/intake/proposal-emit.sh (revise.sh re-invokes the emitter with `--axes-from <tmp>` carrying merged overrides + rederives)
- scripts/intake/approval-gate.sh → scripts/intake/revise.sh (the `revise` verb post-parse handler invokes revise.sh and forwards its stdout)
- scripts/intake/proposal-emit.sh → templates/intake-proposal.md (emitter renders the same 25-key template; `--axes-from` does not change the template)
- tests/test-revision-flow.sh → scripts/intake/revise.sh (end-to-end test exercises the full revise flow)
- tests/test-revision-version-preservation.sh → scripts/intake/revise.sh (test exercises two consecutive revises)
- commands/evaluate.md → scripts/intake/revise.sh (verb description points at the wired script)

## Tasks

### T01: `scripts/intake/axis-rederive.sh` — pure dependent-axis emitter

See `tasks/T01-PLAN.md`. Authors `scripts/intake/axis-rederive.sh` — a pure decision emitter with no file writes that, given a primary axis override + the parent proposal path (so `input_shape` is readable), emits the recomputed dependent-axis values per the same rule tables that paragraph-classify.sh and spec-shape-classify.sh apply at first emission. Rule reuse is by re-implementation (the rule logic is small enough that re-encoding it is cheaper than refactoring three scripts to share a lib in P06; the lib extraction can ride a future cleanup phase if a third call site appears). Rule table:

| Override                    | Re-derives                                                            |
|-----------------------------|-----------------------------------------------------------------------|
| `scope_tier=A`              | `decomposition=single-task`, `recommended_command=orchestrator:dispatch` |
| `scope_tier=B`              | `decomposition=single-phase`, `recommended_command=orchestrator:specify` |
| `scope_tier=C`              | `decomposition=milestone-with-phases`, `recommended_command=orchestrator:specify` |
| `decomposition=multi-milestone` | `recommended_command=orchestrator:roadmap` (escalation hint)      |
| `design_gate=walkthrough`   | (no rederives in P06; P07 owns the manual/skip branch)                |
| `conversus_gate=*`          | (independent — emit no rederive lines)                                |
| `intensity=*`               | (independent — emit no rederive lines)                                |

Authors `scripts/verify/m024-p06-axis-rederive.sh` — exercises every row of the rule table on a fresh paragraph proposal. AD-19 single-script-file shape; bash 3.2 portable.

### T02: `scripts/intake/revise.sh` + `--axes-from` extension to `proposal-emit.sh`

See `tasks/T02-PLAN.md`. Authors `scripts/intake/revise.sh` — the user-facing driver. Steps:

1. Parse `--proposal <path>` plus one or more `--axis <name> --value <value>` pairs. Validate axis names against the FR-12 closed enum (the same six axes approval-gate.sh already validates).
2. Confirm the proposal is not already finalized (`pending_approval: false` AND `approved_at:` present means the operator approved before revising — emit a stderr advisory but proceed; this is the operator's call).
3. For each operator override, invoke `bash scripts/intake/axis-rederive.sh --axis <a> --value <v> --proposal <path>` and merge stdout into a tmp axes-from file, with operator overrides written *after* the rederives so operator overrides win on conflict (an operator who overrides both `scope_tier=C` *and* `decomposition=single-task` keeps `single-task` even though the rederive would suggest `milestone-with-phases`).
4. Idempotency check (FR-14): if the merged axes-from values are byte-identical to the current proposal's frontmatter values for those keys, exit 0 with `revised=false reason=identical-axes` to stdout — do NOT archive or re-emit.
5. Allocate the next version suffix: scan the proposal's directory for `proposal-v*.md`, find the highest existing N (default 0), and use N+1.
6. Archive the current `proposal.md` to `proposal-v<N+1>.md` (mv).
7. Re-derive the emitter inputs from the archived version (`--input` from the original input echo, `--spec-path` from the original feature_slug if set, `--qa-answers-from` from the embedded `## Q&A` section — synthesized into a tmp answers file if present).
8. Invoke `bash scripts/intake/proposal-emit.sh --axes-from <tmp> [<other emitter inputs>]` to write the new `proposal.md`.
9. Emit `revised_to=<new-proposal-path>` to stdout. Exit 0.

Also extends `scripts/intake/proposal-emit.sh` with the `--axes-from <file>` flag (line-mode `key=value` reader; populates `scope_tier_override` / `decomposition_override` / `recommended_command_override` / `design_gate_override` / `conversus_gate_override` / `intensity_override` shell vars; sets `REVISE_AXES_DONE=1` so the rationale loop skips the affected slots, which revise.sh fills post-emit). The `--axes-from` flag is independent of `--input` / `--spec-path` / `--qa-answers-from` — it composes with all of them.

Authors `scripts/verify/m024-p06-revise-script.sh` and `scripts/verify/m024-p06-axes-from-flag.sh`. AD-19 single-script-file shape.

### T03: Wire `revise` verb in `approval-gate.sh` + version-suffix verify + rationale slot

See `tasks/T03-PLAN.md`. Upgrades `scripts/intake/approval-gate.sh`'s `revise` verb post-parse handler from the P03 surface-only stdout pass-through to a real wired call into `scripts/intake/revise.sh`. The new handler:

1. Parses the same `--axis <name> --value <value>` arguments the P03 implementation already accepts (no breaking change).
2. Invokes `bash scripts/intake/revise.sh --proposal "$PROPOSAL" --axis "$AXIS" --value "$VALUE"`.
3. Forwards `revise.sh`'s stdout (`revised_to=<path>`) to its own stdout.
4. Exits 0 on success, 1 on revise.sh failure, 2 on axis validation failure (existing P03 behavior preserved).

A new `--no-apply` test-only flag preserves the legacy P03 stdout shape (`revision_pending=true axis=<a> value=<v>`) so existing P03 tests stay green without modification — `--no-apply` short-circuits the call into revise.sh and only echoes the parsed axis/value pair. This satisfies the M024 "do not break green phases" invariant.

Also authors `scripts/verify/m024-p06-version-suffix.sh` (asserts the v1+v2 sequence after two consecutive revises) and `scripts/verify/m024-p06-rederive-rationale.sh` (asserts the rationale slots for revised axes contain "operator revision" + a pointer to the prior version, and untouched axes retain their prior rationale verbatim). Authors `scripts/verify/m024-p06-approval-gate-revise-wired.sh`.

### T04: Phase tests + suite + write-confinement + evaluate.md row update

See `tasks/T04-PLAN.md`. Authors two phase-level tests:

- `tests/test-revision-flow.sh` — end-to-end happy path: emit a paragraph proposal at Tier B → `revise --axis scope_tier --value C` → assert `proposal-v1.md` is the prior content byte-for-byte, `proposal.md` has `scope_tier: "C"`, `decomposition: "milestone-with-phases"` (rederived), `recommended_command: "orchestrator:specify"` (rederived), `pending_approval: true`, `approved_at: null`, `cancelled_at: null`. If the proposal was Q&A-derived, assert the `## Q&A` body section is preserved verbatim across the snapshot.
- `tests/test-revision-version-preservation.sh` — exercises two consecutive revises: assert v1 + v2 both exist after the second revise, v1 byte-identical to the first emit, v2 byte-identical to the post-first-revise content, and `proposal.md` is the latest. Asserts the idempotency guard (FR-14): a third revise with the same axis values as the current proposal exits 0 with `revised=false reason=identical-axes` and produces no new version file.

Also authors `scripts/verify/m024-p06-write-confinement.sh` (writes-only-to-intake-dir-or-tmp assertion across revise.sh, axis-rederive.sh, the new emitter flag, and the upgraded approval-gate verb) and `scripts/verify/m024-p06-evaluate-md.sh` (asserts `commands/evaluate.md`'s revise verb row contains the literal string "wired in P06" and references `scripts/intake/revise.sh`). Authors the suite runner `scripts/verify/m024-p06-suite.sh` (MEM002 parallel-array tracker; structured PASS:/FAIL: summary; runs the two phase tests + every per-task verify). Updates the one-line `revise` verb description in `commands/evaluate.md`.

## Task Dependencies

```
T01 → T02         (revise.sh invokes axis-rederive.sh)
T02 → T03         (approval-gate.sh's revise verb calls revise.sh)
T01 + T02 + T03 → T04
```

T01 (axis-rederive) is pure decision emitter — no file writes, no upstream behavior change. T02 is the load-bearing wiring (revise.sh + the `--axes-from` emitter flag); revise.sh is independently testable on a hand-emitted proposal, so T02 can verify before T03 wires the approval-gate. T03 upgrades the approval-gate revise verb (preserves P03 surface via `--no-apply`). T04 exercises the full end-to-end path including version preservation, idempotency, and the operator-facing doc update.

## Files Likely Touched

- scripts/intake/axis-rederive.sh (create)
- scripts/intake/revise.sh (create)
- scripts/intake/proposal-emit.sh (modify — add --axes-from flag + REVISE_AXES_DONE branch)
- scripts/intake/approval-gate.sh (modify — wire revise verb to revise.sh; preserve P03 surface via --no-apply)
- commands/evaluate.md (modify — update revise verb description to "wired in P06")
- tests/test-revision-flow.sh (create)
- tests/test-revision-version-preservation.sh (create)
- scripts/verify/m024-p06-axis-rederive.sh (create)
- scripts/verify/m024-p06-revise-script.sh (create)
- scripts/verify/m024-p06-version-suffix.sh (create)
- scripts/verify/m024-p06-axes-from-flag.sh (create)
- scripts/verify/m024-p06-approval-gate-revise-wired.sh (create)
- scripts/verify/m024-p06-rederive-rationale.sh (create)
- scripts/verify/m024-p06-write-confinement.sh (create)
- scripts/verify/m024-p06-evaluate-md.sh (create)
- scripts/verify/m024-p06-suite.sh (create)
