# Proposal: M026 — Autonomous Hardening v3

**Captured**: 2026-04-27
**Shape**: Milestone (5 phases) — collapsible to 2 quick PRs depending on P01 baseline
**Predecessors**: M016 (autonomous hardening v1, shipped), M021 (autonomous hardening v2, shipped)
**Source**: Fresh sweep of 7 `orchestrator:auto` interruption screenshots (2026-04-25 to 2026-04-26) plus inspection of existing M021 infrastructure

## Goal

Close the gap between the M021 shape-guard infrastructure and the actual autonomous-run experience, with two new findings that didn't exist when M021's corpus was assembled:
1. The hook fails-open in *consumer* projects (e.g., `bbt-companion`) because its script path is project-relative.
2. Four new shape classes have surfaced post-M021 that are not yet in the classifier's matrix.

Plus polish: investigation-pattern wrappers and a destructive-op single-command shape.

## Why M026 (not M021/P05+)

M021 shipped 9 antipatterns, a 21-entry replay corpus, a classifier library, a PreToolUse hook, and a payload linter. That work is *complete and stable*. M026 extends — it doesn't re-open. Naming as a new milestone keeps M021's verification artifacts immutable and lets M026 own its own success criteria.

## Existing infrastructure (do not duplicate)

- `ANTIPATTERNS.md` — AP-001 through AP-009 (M016 + M021)
- `scripts/hooks/pre-bash-shape-guard.sh` — PreToolUse hook (M021/P03)
- `scripts/verify/lib/shape-classifier.sh` — classifier library with 10-pattern matrix (M021/P03)
- `scripts/verify/anti-pattern-lint.sh` — payload-fence linter (M021/P02)
- `tests/fixtures/m021-prompt-corpus.txt` — 21-entry replay corpus (M021/P04)
- `scripts/util/run-probe.sh`, `read-range.sh`, `with-env.sh` — wrapper catalog (M021/P01)

## Findings (root-cause analysis from 7 screenshots)

### Finding A: Hook isn't portable to downstream consumer projects

**Evidence**: Screenshots 4, 5, 6, 7 show paths under `/Users/brettkellgren/Sites/bbt-companion/...` — a *different* project consuming the orchestrator. None show a `REJECT:` diagnostic, indicating the hook never ran.

**Root cause**: `scripts/hooks/pre-bash-shape-guard.sh:39-42` resolves the classifier via `$CLAUDE_PROJECT_DIR/scripts/verify/lib/shape-classifier.sh`. When `$CLAUDE_PROJECT_DIR` is the consumer project (bbt-companion), the path doesn't exist; the hook falls through to `exit 0` (passthrough — `:118-121`).

**Installer path**: `packaging/install/install-claude-code.sh` writes to `$HOME/.claude/settings.json` (user-global), so the hook entry *is* registered globally. But the command points at a path that only resolves inside the orchestrator repo.

**Fix shape**: installer copies the hook + classifier + reject_lookup table into a runtime-stable location (e.g., `~/.claude/orchestrator-hooks/`) and updates settings.json to point there. Hook self-locates via its own `$0` rather than `$CLAUDE_PROJECT_DIR`. This is the load-bearing finding — likely eliminates 4 of 7 screenshots on its own.

**Impact**: blocks every downstream-project autonomous run. M024 (universal intake under auto mode) is the next milestone that will exercise this path.

### Finding B: Four new shape classes outside the M021 matrix

| # | Screenshot | Pattern | Trigger | Proposed AP-ID |
|---|---|---|---|---|
| 1 | 4 | Backtick inside grep regex `'^- \`bash...'` | Parser reads as command substitution attempt | AP-010 `cmd-sub-in-pattern` |
| 2 | 3 | Newline + `#` inside quoted `--last-action` arg | Path-validation security heuristic ("args hidden from validation") | AP-011 `quoted-arg-newline-hash` |
| 3 | 5 | Multi-line `node -e "..."` body | "Contains ansi_c_string" parser fallthrough | AP-012 `multiline-quoted-script` |
| 4 | 6 | Raw `{2,3,4,5}` outside quotes | Brace expansion heuristic; AP-007 only catches *quoted* brace | AP-013 `unquoted-brace-glob` |

Each gets:
- A new entry in `ANTIPATTERNS.md` with cross-refs to hook + classifier + corpus (mirroring AP-005 through AP-009 structure)
- A new pattern-class in `scripts/verify/lib/shape-classifier.sh::classify_command`
- A new entry in `pre-bash-shape-guard.sh::reject_lookup` mapping pattern-class → wrapper + AP-ID
- Verbatim entries in the regression corpus

### Finding C: Compound shapes possibly slipping past existing classifier

**Evidence**: Screenshot 1 (`grep ... ; echo "---"; grep ...`) and Screenshot 7 (full `for…do…done` with command substitution).

**Hypothesis**: either (a) the classifier under-matches when commands are joined with `;` and *also* contain pipes/globs (regex narrowness), or (b) Finding A applies (Screenshot 7 is in bbt-companion).

**Resolution**: P01 replays both verbatim. If the hook is portable (Finding A fixed) and they still pass classification, the classifier needs a regex fix. Empirical, not speculative.

### Finding D: Destructive `/bin/rm` always prompts

**Evidence**: Screenshot 2 — `/bin/rm -f .orchestrator/.../*.txt && ls .orchestrator/.../*.txt 2>&1`.

**Root cause**: Claude Code prompts on `rm` regardless of `Bash(...)` allowlist entries; this is shape-independent. Compound chain (`&&`) makes it worse, but even an isolated `rm -f` would prompt.

**Fix shape**: a single-command wrapper at `scripts/util/cleanup-stale-results.sh <milestone>` that internally does the rm + ls confirmation. Allowlist the wrapper once. Pattern is well-established by M021's wrapper catalog.

**Where it fires today**: per-step result files cleanup in `auto-loop.sh` (or its callers) — needs traced during P01.

### Finding E: Agent-emitted *investigation* patterns, not orchestrator script output

**Evidence**: Screenshots 1, 4, 5, 6 — these are exploratory grep/cat/node-eval that an agent ran mid-task to inspect files. Not orchestrator script output.

**Root cause**: M021's payload linter scans `commands/*.md`, `templates/*.md`, and `**/tasks/*-PAYLOAD.md`. The agent's *ad-hoc* shell habits during execution have no covering artifact. Subagents reproduce what they see in payloads + commands; if there's no canonical example for "how to investigate X," they invent compound shells.

**Fix shape (two-part)**:
1. Three new wrappers under `scripts/util/`:
   - `grep-files.sh <pattern> <file...>` — replaces compound `grep ... ; grep ...` chains
   - `cleanup-stale-results.sh <milestone>` — replaces `rm + ls` (Finding D)
   - `node-eval.sh <expr>` — replaces inline `node -e "..."` (Finding B #3)
2. Update `commands/dispatch.md` and the task-PAYLOAD template with canonical "investigation patterns" examples that route through these wrappers. Add a §"Investigation patterns" section to the antipattern register cross-referencing each wrapper.

## Phase shape

| Phase | Goal | Key artifact | Verifies |
|---|---|---|---|
| P01 | Empirical baseline | 7 new corpus entries (one per screenshot) appended to `tests/fixtures/m021-prompt-corpus.txt`. Replay shows current pass/fail. Decision: collapse to 2 PRs or proceed with full milestone. | Each screenshot has a known classification verdict. |
| P02 | Hook portability | Installer copies hook + classifier into `~/.claude/orchestrator-hooks/`. Hook self-locates via `$0`. End-to-end test: fresh bbt-companion-style fixture, run autonomous loop, all 4 downstream-project screenshots reject. | Cross-project replay passes. |
| P03 | Classifier extension | AP-010, AP-011, AP-012, AP-013 added to register, classifier, reject_lookup, corpus. M021 corpus still passes (no regressions). New corpus entries reject as expected. | Replay corpus 100% expected verdict. |
| P04 | Investigation pattern wrappers + dispatch.md catalog | `grep-files.sh`, `cleanup-stale-results.sh`, `node-eval.sh` ship with tests. `commands/dispatch.md` and PAYLOAD template have "Investigation patterns" examples. ANTIPATTERNS.md has §"Investigation patterns" cross-ref. | Antipattern lint passes against updated dispatch.md + template. |
| P05 | Cross-project replay + verifiers + summary | Verifier suite under `scripts/verify/m026/`. Fresh-fixture autonomous run produces zero prompts on combined M021+M026 corpus. Summary file. | All P01-P04 verifiers pass; downstream replay clean. |

## Collapse condition

If P01 baseline shows that fixing only Finding A (hook portability) resolves 6 of 7 screenshots, M026 collapses to:
- **PR-1**: Hook portability (P02 minus the cross-project test infrastructure)
- **PR-2**: Add the one outlier as a corpus entry + classifier rule

Total ~1 day of work instead of a 5-phase milestone. P01 is the gating data.

## Dependencies & sequencing

**Should land before**: M024 (universal intake under autonomous mode in arbitrary projects), M020 (any further milestone with significant `auto` runtime).

**Independent of**: M014 (extended), M019 Tier 2+3, M018 (currently active), M023, M027.

**Slot recommendation** (per `.orchestrator/proposals/README.md`): after M014 (extended), before M020.

## Out of scope

- Re-opening M021's matrix (10-pattern set is stable; M026 *adds*, doesn't revise).
- Solving destructive ops generally — only `rm`-shaped cleanup is in scope. Other destructive verbs (`gh pr close`, force-push, etc.) are caught upstream by Claude Code's destructive-op policy and don't need orchestrator-side wrappers.
- A "universal investigation skill" — rabbit hole. Three concrete wrappers + dispatch.md examples is enough.

## Open questions for `orchestrator:specify`

1. **Hook installation location**: `~/.claude/orchestrator-hooks/` vs `~/.orchestrator/hooks/` vs `~/.claude/plugins/orchestrator/hooks/`. Conversus uses `~/.conversus/`; precedent argues for the orchestrator getting its own dotdir.
2. **Cross-project test fixture**: maintain a permanent fixture project under `tests/fixtures/downstream-project/` or generate from a template at test time? Permanent is simpler; template avoids stale fixtures.
3. **Corpus naming**: continue using `m021-prompt-corpus.txt` (keeps a single corpus) or split as `m026-prompt-corpus.txt`? **Recommendation**: keep single corpus, append; the file is permanent regression data, not milestone-scoped.
4. **AP numbering**: AP-010 through AP-013 confirmed available? (Last register entry is AP-009.)

## Source evidence (file paths)

- `ANTIPATTERNS.md:84-214` (AP-004 through AP-009 structure to mirror)
- `scripts/hooks/pre-bash-shape-guard.sh:25-33` (reject_lookup table to extend)
- `scripts/hooks/pre-bash-shape-guard.sh:39-42` (path resolution — the portability bug)
- `scripts/verify/lib/shape-classifier.sh::classify_command` (rule additions)
- `tests/fixtures/m021-prompt-corpus.txt` (corpus extension)
- `packaging/install/install-claude-code.sh:213-238` (installer hook-merge — extend to copy script payload)
- `commands/dispatch.md` (add Investigation patterns section)
- 7 source screenshots: 2026-04-25 8:33 PM / 8:50 PM / 10:04 PM, 2026-04-26 12:21 AM / 9:53 AM / 12:22 PM / 2:33 PM (paths in user message, not in repo)
