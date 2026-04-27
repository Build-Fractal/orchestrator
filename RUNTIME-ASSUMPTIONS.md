---
schema_version: "1.0"
type: runtime-assumptions-registry
created_at: "2026-04-22"
last_updated: "2026-04-27"
---

# Runtime Assumptions Registry

Per Decision D016, this file logs every CC-only (Claude-Code-only) path introduced by the orchestrator. M009's runtime-parity audit consumes this file as a punch-list: each entry names the Claude-Code-specific assumption, the Codex CLI / Cursor fallback shipped in v1, and the runtime-parity obligation for future work.

Every new entry is **append-only**: register CC-only paths as they are introduced; remove an entry only when runtime parity is achieved and verified.

## Entry Schema

Each entry lives under a `## FR-N: <short-name>` heading with four required subsections:

- **Claude Code assumption** — what the CC-only path does (LLM round-trip, specific API, etc.).
- **Codex/Cursor fallback** — the non-LLM path shipped in v1 that these runtimes fall through to. Must be fully functional, never silently degraded.
- **Milestone / phase** — `M###/P##` that introduced the assumption.
- **M009 obligation** — what the runtime-parity audit needs to do to close this entry (re-implement under Codex/Cursor, accept CC-only as permanent, etc.).

## Entries

### FR-3: LLM-assisted scaffold-fill depth (`orchestrator:specify`)

- **Claude Code assumption**: under CC runtime, `scripts/specify/specify.sh` will invoke an LLM round-trip via `scripts/dispatch/dispatch-interface.sh` using `templates/spec-scaffolder-prompt.md` to populate first-pass prose for Problem Statement and at least one User Story stub when `--description` exceeds 80 words.
- **Codex/Cursor fallback**: skeleton-only scaffold (all sections present, all content `<TODO: ...>` placeholder). Fully functional — the maintainer fills every section by hand, exactly as the M013 and M014 specs were hand-authored.
- **Milestone / phase**: M014/P01 surface; M014/P04 (or later) invocation.

  In P01, the LLM invocation is **not yet wired** — the template and the runtime-dispatch surface ship, but `scripts/specify/specify.sh` is skeleton-only across all runtimes. The CC-only invocation is deferred to a later M014 phase per Phase Sequencing table (spec.md §Phase Sequencing).
- **M009 obligation**: re-implement LLM-assisted fill under Codex CLI (via Codex's API or external LLM round-trip) and Cursor. Until then, document CC-only as the canonical scaffold path.

### FR-5: Complexity probe contradiction-signal count (`scripts/knowledge/spec-complexity-probe.sh`)

- **Claude Code assumption**: under CC runtime, `scripts/knowledge/spec-complexity-probe.sh` invokes an LLM round-trip via `scripts/dispatch/dispatch-interface.sh` using `templates/spec-complexity-contradiction-prompt.md` to count contradiction signals (mutually-exclusive requirements, "should support both X and its opposite" patterns, constraints violating success criteria) in the draft spec prose. The returned count feeds the above-threshold verdict when `contradiction_signal_count >= 1` per `.orchestrator/config.yml specify.complexity_thresholds.contradiction_signal_count`. The LLM pass is defensive: any dispatch failure silently yields zero signals (probe never fails because of LLM flakiness).
- **Codex/Cursor fallback**: the contradiction-signal LLM pass is skipped entirely (gated on `CLAUDE_CODE_RUNTIME=1` + `scripts/lifecycle/detect-capabilities.sh --runtime` = `claude-code`). The probe emits `contradiction_signals=0` in its structured stderr output and relies exclusively on the runtime-agnostic heuristic dimensions (FR count, user-story count, raw token count, TODO density) to reach a verdict. Fully functional — Codex/Cursor users still get useful above-threshold firings on large specs; they simply lose the contradiction-detection signal.
- **Milestone / phase**: M014/P04 introduction (full body replaces the M014/P01 scaffold). Caller contract (single-line stdout verdict + four-key stderr fields + exit code) is unchanged from P01 — callers invoke the probe identically pre- and post-T02.
- **M009 obligation**: re-implement the contradiction-signal LLM pass under Codex CLI (via Codex's API or an external LLM round-trip) and Cursor. Until runtime-parity ships, CC-only contradiction detection is the canonical path; Codex/Cursor users can still dogfood the orchestrator without the signal.

## Cross-References

- `commands/specify.md` — FR-3 scaffolder surface
- `scripts/specify/specify.sh` — FR-3 invocation site (invocation deferred per P01 boundary map)
- `scripts/knowledge/spec-complexity-probe.sh` — FR-5 stub (P01) → full (P04)
- `templates/spec-scaffolder-prompt.md` — FR-3 CC LLM prompt body
- `.orchestrator/DECISIONS.md` D016 — origin of the `RUNTIME-ASSUMPTIONS.md` discipline

### FR-7: LLM-assisted spec decomposition (`orchestrator:specify split`)

- **Claude Code assumption**: under CC runtime, `scripts/specify/specify.sh split <path>` invokes an LLM round-trip via `scripts/dispatch/dispatch-interface.sh` using `templates/spec-splitter-prompt.md` to propose a 2–N-way decomposition manifest for large specs that cross the FR-5 probe's above-threshold verdict and elect the `d` path in the US-3 three-way prompt.
- **Codex/Cursor fallback**: `split` exits 3 with a clear diagnostic naming CC-only status and pointing to manual spec decomposition. The operator authors N new specs by hand using `orchestrator:specify --description ...` and manages the decomposition manually. No silent degradation.
- **Milestone / phase**: M014/P04 introduction.

  The splitter caps proposed decompositions at 4 sub-specs (prompt-enforced); the manifest lands at `.orchestrator/specify/decomposition/<source-id>/manifest.md` (interim path — M024 Universal Intake milestone migrates to `.orchestrator/intake/<id>/decomposition.md` when shipped; manifest schema is write-forward-compatible).
- **M009 obligation**: re-implement the LLM-assisted splitter under Codex CLI (via Codex's API or external LLM round-trip) and Cursor, or document CC-only as permanent fallback if the LLM round-trip value under those runtimes proves low for the engineering cost.

### M018/P01: compression-grammar runtime expectations

- **Claude Code assumption**: Tier 3 auto-compact (FR-8) routes summarization through `scripts/dispatch/dispatch-interface.sh` invoking the runtime's native model. Under Claude Code, this is Anthropic's API via the orchestrator's existing dispatch path; quality of the summary is gated by the eval harness (US-7 / FR-12) before Tier 3 dispatches advance `unit_close`. Filter, Tier 1, and Tier 2 are zero-LLM and runtime-agnostic.
- **Codex/Cursor fallback**: zero-LLM tiers (filter / Tier 1 / Tier 2) are byte-identical across all three runtimes (FR-13). Tier 3 routes through the same `dispatch-interface.sh` and calls the runtime's native model; the in-band marker `<!-- compressed:tier3 model=<model> ... -->` carries the runtime-specific model name verbatim, and `dispatch_usage` records carry the runtime-specific pricing. Behavior diverges only in the model identity and pricing — the contract (preservation, marker, additive emitter fields) is identical.
- **Milestone / phase**: M018/P01 (grammar contract authored). Tier code lands across M018/P02–P05; multi-runtime parity audit (US-8) lands in M018/P07 and feeds M009.
- **M009 obligation**: confirm zero-LLM tier outputs diff-clean across CC / Codex CLI / Cursor on a fixture milestone; confirm Tier 3 outputs differ only in model identity and pricing (in-band marker schema unchanged); accept multi-runtime Tier 3 model divergence as permanent (each runtime calls its own native model — this is correct behavior, not a parity bug).

<!-- Future entries land below this line as new CC-only paths are introduced.
     Append-only per D016. Do not reorder or delete existing entries. -->
