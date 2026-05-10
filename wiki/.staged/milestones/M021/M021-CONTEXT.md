---
schema_version: "1.0"
type: context-draft
milestone: "M021"
status: finalized
created_at: "2026-04-17T00:00:00Z"
finalized_at: "2026-04-17T00:00:00Z"
---

## Architectural Decisions

**AD-1: Pre-Bash hook is the only layer that can neutralize parser-fallthrough prompts.** Claude Code's "Unhandled node type: string" prompt fires during tool-call parsing, *before* the allow-list is consulted. No combination of `Bash(...)` allow entries or `defaultMode: acceptEdits` can suppress it. A hook wired via `.claude/settings.json` (PreToolUse) is the only intercept point. Therefore the hook is load-bearing for SC-1 — we cannot achieve zero prompts with linter + permissions alone. **Confirmed via Claude Code hook docs (https://code.claude.com/docs/en/hooks):** PreToolUse fires before permission-rule evaluation, and rewritten input is re-classified by the safety layer — so a rewrite to a safe shape neutralizes the prompt.

**AD-1a: Hook uses the documented `hookSpecificOutput` JSON protocol.** Hook exits 0 and writes a single JSON object to stdout:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "updatedInput": { "command": "<rewritten bash>" }
  }
}
```
For hard-reject cases: exit 2 with a one-line stderr diagnostic (`REJECT: <pattern-class> — use scripts/util/<wrapper>.sh. See ANTIPATTERNS.md#<AP-id>.`), OR equivalently exit 0 with `permissionDecision: "deny"` + `permissionDecisionReason`. P03 picks exit-2-with-stderr as primary because it matches the "recoverable agent signal" semantics in AD-6 most directly. **Single-hook constraint:** settings.json must declare exactly one PreToolUse hook for Bash — multiple hooks return nondeterministic "last-writer-wins" results on `updatedInput`.

**AD-2: Ten-pattern matrix, closed on observed evidence.** The hook's rewrite/reject table is exactly ten entries: six deterministic rewrites (trailing `; echo RC=$?`, `sed -n 'M,Np' f`, `cat > /tmp/x.sh <<EOF … EOF ; bash /tmp/x.sh`, `cd X && bash Y`, leading `VAR=val bash Z`, `$(cmd)`-in-redirect-target) and four hard-rejects (nested `$(…)`, compound `&&/||/|` with >2 stages, heredoc with `$(…)` inside, braces-inside-double-quotes that aren't literal text). The matrix is grounded in the 20 M011/P05–P07 screenshots. No speculative entries (constitution XIV).

**AD-3: Three-wrapper catalog, capped.** `scripts/util/with-env.sh` (replaces `VAR=val bash …` prefix chains), `scripts/util/read-range.sh` (replaces `sed -n 'M,Np' file`), `scripts/util/run-probe.sh` (replaces bare `bash /tmp/*.sh` and ad-hoc heredoc+execute patterns). Three is enough to absorb the recurring probe shapes observed in the evidence. Additional wrappers get added only if a future auto run surfaces a shape none of these three cover.

**AD-4: Linter v2 is a strict superset of v1.** Extends `scripts/verify/anti-pattern-lint.sh` — does not replace it. [M016](../../milestones/M016/index.md) Class A detectors stay as-is; v2 adds five new pattern detectors (simple-expansion, redirect-cmd-sub, quoted-brace, heredoc-expansion, task-plan-compound) and widens the scan scope to include `.orchestrator/milestones/**/tasks/*-PAYLOAD.md` bash fences and `scripts/dispatch/lib/` dispatch-payload builders. M016 suppression semantics (`ANTIPATTERNS.md` code blocks, FORBIDDEN-region markers) are preserved byte-for-byte.

**AD-5: Replay corpus is the authoritative regression gate for SC-1.** The 20 verbatim tool-call strings from the M011/P05–P07 screenshots are extracted manually (OCR + proofread) into `tests/fixtures/m021-prompt-corpus.txt`. `scripts/verify/replay-prompt-corpus.sh` runs each line through the hook's shape classifier and asserts zero would-prompt cases. This fixture is permanent (per constitution VII — knowledge compounds) and becomes CI gated.

**AD-6: Hook rejection is a recoverable agent signal, not a user prompt.** When the hook hard-rejects, it writes a single-line diagnostic of the form `REJECT: <pattern-class> — use scripts/util/<wrapper>.sh. See ANTIPATTERNS.md#<AP-id>.` to stderr and exits non-zero. The Bash tool call fails with that diagnostic in the tool result. The agent reads the rejection, picks the allowed wrapper, and retries — all inside the autonomous loop. No user prompt fires. This is strictly better than the current behavior where the same shape halts the loop.

**AD-7: Phase ordering is linear — wrappers → linter → hook → corpus.** P01 ships wrappers first because the linter's remediation hints (P02) must name specific wrapper paths. P03 (hook) depends on both P01 (target scripts) and P02 (diagnostic text references). P04 validates the integrated system via corpus replay. No parallel phases — the dependency chain is serial.

**AD-8: Dogfood SC-7 via auto-run closeout.** M021 itself runs in `orchestrator:auto` as the final validation step (same convention M016 established). The M021-SUMMARY.md records the prompt count observed during its own execution. If >0 prompts fire during M021's own auto run, the milestone does not close — fix and re-dogfood.

**AD-9: New AP-### entries for each Class B pattern.** Every pattern the linter or hook catches gets a corresponding AP-### entry in `ANTIPATTERNS.md`. Estimated additions: AP-005 (simple-expansion in inline bash), AP-006 (command-substitution in redirect targets), AP-007 (braces inside quoted strings), AP-008 (heredoc + variable expansion in tool calls), AP-009 (task-PAYLOAD bash fences re-introducing compound chains). Each entry cites specific [M011](../../milestones/M011/index.md) screenshots as evidence (constitution II — evidence before claims).

**AD-10: Hook is installed via project settings only — no per-user setup.** The hook script lives in `scripts/hooks/pre-bash-shape-guard.sh` (checked in) and the `.claude/settings.json` PreToolUse entry references it by repo-relative path. A fresh clone gets the hook automatically on the first `orchestrator:auto` invocation. No installer step, no `~/.claude/` write, no opt-in flag.

## Scope Boundaries

**In scope:**
- The 10-pattern rewrite/reject matrix, grounded in M011/P05–P07 evidence.
- Three wrappers under `scripts/util/`: `with-env.sh`, `read-range.sh`, `run-probe.sh`.
- Linter v2: five new detectors, scope widened to task-PAYLOAD bash fences and dispatch-payload builder sources.
- `.claude/settings.json` widening for safe read-only shapes on `/var/folders/**`, `/tmp/*.sh`, project-relative `tmp/**`, read-only `sed -n`/`head`/`tail`/`stat`.
- Pre-Bash hook at `scripts/hooks/pre-bash-shape-guard.sh`, wired via project settings.
- Permanent regression corpus at `tests/fixtures/m021-prompt-corpus.txt` + replay gate.
- Five new `ANTIPATTERNS.md` entries (AP-005 through AP-009) with M011 screenshot citations.
- Dispatch-payload integration: "Allowed invocation shapes" section lists the three wrappers with usage examples.
- Dogfood validation via M021's own `orchestrator:auto` run (SC-7).

**Out of scope:**
- Retroactively rewriting M001–M016 task plans to use the new wrappers. Only M019-and-later plans consume them.
- Upstream Claude Code changes. This milestone treats the safety layer as a fixed external constraint.
- Interactive (non-auto) mode behavior beyond hook passthrough. Human-at-keyboard workflows keep working; the hook is transparent when it passes a call through.
- Expanding autonomy to legitimately risky operations (credential prompts, destructive git, `gh release`, `npm publish`). These remain in the existing `deny:` list.
- Throughput optimization of the hook. Correctness on the 10-pattern matrix is the bar; ≤100ms latency is acceptable.
- A second wrapper catalog for non-probe patterns (e.g., git wrappers, network wrappers). Out of scope unless a future auto run surfaces a recurring git/net shape.
- Hook configurability per-command or per-user. One global hook, one matrix, no knobs.
- Web search / WebFetch permission changes. Out of scope — no prompts observed there.

## Design Constraints

**Platform:**
- Bash 3.2 compatible (macOS default bash) — wrappers and hook must pass `scripts/verify/m016-p04-bash32-compat.sh` or equivalent.
- No new runtime dependencies: pure bash + standard POSIX utilities + BSD-compatible sed/awk. No jq/node/python beyond what the orchestrator already requires.
- Hook must run inside Claude Code's hook sandbox (no network, no user input).

**Compatibility:**
- Must not regress any M016 behavior. Linter v2 is a strict superset — all M016 test fixtures continue to pass.
- `scripts/verify/run-suite.sh` (M016 P02) continues to work unchanged.
- `write-summary.sh --completed_at=now` sentinel (M016 P01) continues to work unchanged.
- Existing dispatch-payload "Prohibited inline bash patterns" section (M016 P03) is extended, not replaced.

**Process:**
- Must ship before [M019](../../milestones/M019/index.md) (observability metrics) so metrics dogfood lands on zero-prompt baseline. Adds a new entry to [`.orchestrator/DECISIONS.md`](../../decisions.md) (D010) explaining the reorder.
- Scaffolded via existing `scripts/lifecycle/scaffold.sh` — no new scaffolding code.
- Verified via existing verify ladder — wrappers and hook each get a gate script under `scripts/verify/m021-<phase>-<topic>.sh`.

**Governance (constitution):**
- Principle II (Evidence Before Claims): every AP-### entry cites a specific M011 screenshot. The 10-pattern matrix and 3-wrapper catalog are both evidence-closed.
- Principle VII (Knowledge Compounds): the replay corpus is permanent — it becomes part of CI and every future auto run must pass it.
- Principle XIV (No Speculative Complexity): no "just in case" patterns. If it wasn't in the evidence, it isn't in the hook.
- Principle XV (Surgical Precision): no broad refactor of `anti-pattern-lint.sh`. Add new detectors, reuse existing scan infrastructure.

**Rollback:**
- The hook can be disabled by a single line change in `.claude/settings.json` (remove the PreToolUse entry). No code must be reverted to turn autonomy off — useful if the hook has a correctness bug in production.
- Wrappers are additive. Removing them breaks any caller but is a grep-able change.

## Open Questions

All open questions resolved during discussion (2026-04-17). Recorded here for audit trail.

**OQ-1 [RESOLVED]: PreToolUse hook rewrite capability.** Confirmed via official Claude Code hook docs (https://code.claude.com/docs/en/hooks) that PreToolUse hooks:
- Can rewrite tool input by returning `hookSpecificOutput.updatedInput.command` on stdout JSON (exit 0).
- Can hard-reject via exit 2 + stderr (stderr is surfaced to the agent as tool-result feedback), or equivalently exit 0 with `permissionDecision: "deny"` + `permissionDecisionReason`.
- Fire *before* permission-rule evaluation, so the rewritten string is re-classified by the safety layer — a rewrite to a safe shape actually neutralizes the prompt.
- Receive `CLAUDE_PROJECT_DIR` env var; default timeout 10 minutes; stderr routes to the agent on exit 2.
- **Constraint**: settings must declare exactly one PreToolUse hook for Bash. Multiple hooks run in parallel with "last-writer-wins" on `updatedInput`, which is nondeterministic.

All ten matrix entries are viable as originally specified. P03 scope unchanged. AD-1 and AD-6 hold.

**OQ-2 [RESOLVED]: Replay-corpus classifier approach.** Adopted: approximate shape-classifier via empirical regexes derived from the 20 M011/P05–P07 screenshots (observed prompt text → inferred pattern). The classifier lives at `scripts/verify/lib/shape-classifier.sh` and is versioned with the corpus fixture. Best-effort fidelity; the dogfood run (SC-7) is the belt-and-suspenders ground truth. If a future Claude Code update changes the heuristics, SC-7 catches the divergence and the classifier regexes get patched.

**OQ-3 [RESOLVED]: Linter scope.** Adopted: scan `commands/**`, `templates/**`, `scripts/dispatch/lib/**`, and `.orchestrator/milestones/**/tasks/*-PAYLOAD.md` only. `specs/`, `references/`, and `docs/` are excluded by default (they contain illustrative bash for human readers). An explicit `<!-- agent-facing -->` HTML comment in a markdown file opts that file into the scan — same mechanism M016 used for FORBIDDEN-region suppression, inverted.

**OQ-4 [RESOLVED]: No bypass mechanism.** Adopted: the hook has no escape hatch. `ORCH_HOOK_BYPASS` is explicitly rejected. Reason: a bypass becomes a crutch and Class B patterns leak back in. If a specific recurring call needs to run without prompting, the remedy is to add a wrapper under `scripts/util/` and update the allow-list — the same discipline that produces the three P02 wrappers. This keeps the autonomy property monotonically improving.

**OQ-5 [RESOLVED]: Hook is always-on.** Adopted: the hook fires in both autonomous and interactive modes. Rationale: the set of shapes it rejects is unsafe regardless of who typed them; an interactive user sees the same wrapper pointer and learns the idiom. Consistent behavior beats mode-dependent friction.

**OQ-6 [RESOLVED]: Corpus fixture records both sides.** Adopted: each line in `tests/fixtures/m021-prompt-corpus.txt` captures `INPUT: <original call>` and, where applicable, `EXPECTED_REWRITE: <rewritten call>`. The replay gate asserts both (a) the classifier flags INPUT as a would-prompt case, and (b) the hook's output matches EXPECTED_REWRITE (or matches `REJECT: <pattern-class>` for hard-reject entries). This catches rewrite drift — if a future hook change produces a different rewrite, the replay fails and the change is surfaced.
