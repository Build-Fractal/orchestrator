# Proposal: M028 — Autonomous Hardening v3

> **ID note**: originally drafted as M026; renumbered to M028 after discovering M026 ("Conversus-OSS Migration", closed 2026-04-25) and M027 ("Cost+Quality Observability Surfaces", closed 2026-04-27) had already taken those IDs. No scope conflict — only the number changed.

**Captured**: 2026-04-27 (renumbered 2026-04-28; Finding F appended 2026-04-28 during M018 close)
**Shape**: Milestone (5 phases) — collapsible to 2 quick PRs depending on P01 baseline
**Predecessors**: M016 (autonomous hardening v1, shipped), M021 (autonomous hardening v2, shipped), M025 (installer coexistence — Finding F is its follow-up)
**Source**: Fresh sweep of 7 `orchestrator:auto` interruption screenshots (2026-04-25 to 2026-04-26) plus inspection of existing M021 infrastructure; Finding F surfaced post-M018 close (operator-reported `orchestrator-post-verify: command not found` Stop-hook failure)

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
| 5 | G (2026-04-28) | `find … \| head … \| xargs -I{} sh -c '…;…'` | Compound chain hidden inside `xargs … sh -c` body — top-level pipe count + inner `;` chain together exceed AP-009's gt2 limit, yet the hook didn't fire | AP-014 `xargs-sh-c-compound-body` |

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

### Finding F: M025 hook-shim regression — bare command names + dedup leak

**Captured**: 2026-04-28 during M018 close (operator: "non-blocking but worth investigating after mark-complete.sh lands"). Sibling-class to Finding A; both are M025 hook-coexistence work that didn't carry far enough.

**Evidence**: Stop-hook fires `orchestrator-post-verify: command not found` at session end on the orchestrator's *own* repo. `~/.claude/settings.json` contains 5 duplicate `Stop` wrappers and 7 duplicate `PreToolUse` Bash wrappers naming `orchestrator-post-verify` / `orchestrator-before-commit` — neither on PATH; neither carries the `_orchestrator_managed: true` flag the M025 merge helper expects for its uninstall cascade.

**Root causes** (three distinct bugs, one symptom):

1. **Adapter emits bare command names not on PATH**. `scripts/dispatch/adapters/runtime/claude-code.sh:170-189` emits `"command": "orchestrator-post-verify"` and `"command": "orchestrator-before-commit"` as bare names. The actual scripts live at `scripts/lifecycle/before-commit.sh` and `scripts/lifecycle/after-verify-sync.sh` (per `packaging/bundle/hooks/{post,before}-*.json`), but no shim is installed and the adapter doesn't reference these paths. Claude Code's hook runner resolves the bare name via the user's `PATH` and finds nothing.
2. **Merge helper accumulates duplicates on repeated install**. `scripts/util/settings-merge.sh` has uninstall-cascade logic (line 270+) but no install-side dedup keyed on the `_orchestrator_managed` tag. Each `install-claude-code.sh` rerun appends another wrapper.
3. **`_orchestrator_managed: true` flag does not survive the merge for some pre-existing dupes.** All 12 dupes in the operator's `~/.claude/settings.json` lack the flag, so even M025's uninstall path can't differentiate them from user-authored hooks. Either an older merge helper stripped the flag, or the flag was never written for those entries — to be confirmed via P01 replay against a snapshotted pre-install fixture.

**Fix shape** (folds into Finding A's P02 scope cleanly because both touch the same installer + adapter surface):

- **Adapter**: emit absolute bash invocations (`"command": "bash <runtime-stable-hooks-dir>/before-commit.sh"`) targeting the same `~/.claude/orchestrator-hooks/` location Finding A specifies. The adapter stops being a source of bare names; the script payload travels with the install.
- **Installer**: copy `scripts/lifecycle/{before-commit,after-verify-sync}.sh` into the runtime-stable hooks dir alongside the M021 shape-guard hook (Finding A). One copy operation, one settings.json write, both classes of hooks land at once.
- **Merge helper**: add an install-side dedup pass keyed on `(event, matcher, command)` × `_orchestrator_managed: true`. Each install run is now idempotent — second run is a no-op, not an append. Pinned-sha round-trip gate (per M025/P01's reversibility pattern) extends to the `install → install → uninstall` triple to prove idempotency at the canonical-bytes level.
- **Backfill**: a `packaging/install/repair-claude-code.sh` (or `install-claude-code.sh --repair`) command that detects flag-less orphaned entries matching known M025 patterns and removes them. The operator-side cleanup I did manually for M018 close becomes a one-liner: `bash packaging/install/install-claude-code.sh --repair`.

**Cross-reference**: M025/P01 explicitly named M009 as the downstream consumer for the "orchestrator owns only its own hook entries under `_orchestrator_managed` tag" invariant. Per the 2026-04-28 reordering (M009 deferred post-launch), M028 is the new home — same invariant, earlier shipping.

**Impact**: every `install-claude-code.sh` rerun today doubles broken-hook noise. M028's other findings are useless if installs themselves don't dedup.

### Finding G: Shape-guard miss + literal-bytes "don't ask again" allowlist offer

**Captured**: 2026-04-28 — operator screenshot of Claude Code's native permission-prompt UI on the orchestrator's own repo (so Finding A's downstream-portability gap is *not* the explanation here).

**Evidence (verbatim from screenshot)**: command `find .orchestrator -name "T*-SUMMARY.md" -not -path "*/M066/*" 2>/dev/null | head -3 | xargs -I{} sh -c 'echo "═══ {} ═══"; head -20 "{}"'` triggered Claude Code's "Do you want to proceed?" prompt. The "Yes, and don't ask again for:" rule offered was the literal segment `xargs -I{} sh -c 'echo "═══ {} ═══"; head -20 "{}"'` — i.e., bytes including the `{}` placeholder and the specific `head -20` body.

**Two distinct bugs, one symptom**:

1. **Shape-guard didn't reject**. Three pipes (`find | head | xargs`) plus an inner `;` chain inside `sh -c '…echo;head…'` is exactly the compound-chain shape AP-009 (`compound-chain-gt2`) is supposed to catch. It didn't. Hypothesis: the classifier counts top-level `|`/`;`/`&&` connectors but doesn't descend into `sh -c '<body>'` to count connectors *inside* the quoted body, *and* it terminates pipe-counting at `xargs` (treating it as a sink). Either yields a count ≤ 2 for this shape. Sibling-class to Finding C ("compound shapes possibly slipping past existing classifier") — same root, fresh evidence.

2. **CC's "don't ask again" rule is literal-bytes, not shape-pattern**. Even if the operator accepts the offered rule, it whitelists the exact byte-sequence — same xargs invocation with `head -30` instead of `head -20` would re-prompt, as would a different placeholder name. Worse: accumulating accepted rules progressively pre-approves at the CC layer commands the orchestrator's PreToolUse hook would reject if it had fired, silently degrading the shape guard's effectiveness over time. The orchestrator can't fix CC's prompt UI, but it *can* ensure the hook fires *first* so the operator never has the option to accept an under-specified rule.

**Fix shape (two-part, mirrors Finding B + Finding E)**:

1. **Classifier**: add AP-014 `xargs-sh-c-compound-body` to `scripts/verify/lib/shape-classifier.sh::classify_command` — descends into `sh -c '<body>'` token streams and counts `;`/`&&`/`|` connectors *within* the body alongside top-level pipe count. Reject when combined count exceeds 2. Verbatim screenshot command added to `tests/fixtures/m021-prompt-corpus.txt`.
2. **Investigation-pattern wrapper**: a 4th wrapper in Finding E's catalog — `scripts/util/peek-files.sh <pattern> [--lines N] [--exclude PATH]` — replaces the `find | head | xargs sh -c 'echo HEADER; head -N FILE'` shape that the screenshot uses for "show first N lines of files matching pattern, with separators". Allowlist the wrapper once; canonical investigation example lives in `commands/dispatch.md` per Finding E's part-2 fix.

**Cross-reference**:
- **Finding C**: same hypothesis class (classifier under-matches embedded compound shapes). G replaces C's "possibly slipping" hypothesis with confirmed evidence; C's screenshots become G's regression-corpus companions.
- **Finding E**: the wrapper part of G's fix is the 4th entry in E's investigation-pattern wrapper catalog. AP-014 closes the loop on E's "agents invent compound shells when no canonical example exists" by making the inventive shape unambiguously rejected.
- **Out of scope for M028**: changing CC's "don't ask again" rule offer to shape-based instead of literal-bytes — that's CC product surface, not orchestrator surface. M028 only ensures the hook fires before CC's prompt is reachable.

**Impact**: every operator-driven investigation that compounds `find | head | xargs sh -c '…'` re-incurs the prompt; accepting the offered rule degrades the allowlist without preventing recurrence. Same severity class as Finding B (shape-guard miss), with the added concern of accumulating CC-layer pre-approvals.

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
| P02 | Hook portability + M025 follow-up | Installer copies hook + classifier + lifecycle hooks (`before-commit.sh`, `after-verify-sync.sh`) into `~/.claude/orchestrator-hooks/`. Shape-guard hook self-locates via `$0`. Adapter emits absolute `bash <hooks-dir>/<name>.sh` instead of bare command names (Finding F). Merge helper gains install-side dedup keyed on `(event, matcher, command)` × `_orchestrator_managed`. `--repair` flag added to clean flag-less M025-pattern orphans. End-to-end test: fresh bbt-companion-style fixture, run autonomous loop, all 4 downstream-project screenshots reject; Stop hook fires successfully (post-verify runs); install run twice produces byte-identical settings.json. | Cross-project replay passes; install idempotency pinned-sha gate; `--repair` round-trips a flag-less-orphan fixture. |
| P03 | Classifier extension | AP-010, AP-011, AP-012, AP-013, **AP-014** (xargs-sh-c-compound-body, Finding G) added to register, classifier, reject_lookup, corpus. Classifier gains `sh -c '<body>'` body-descent for connector counting. M021 corpus still passes (no regressions). New corpus entries reject as expected. | Replay corpus 100% expected verdict; Finding G screenshot rejects on replay. |
| P04 | Investigation pattern wrappers + dispatch.md catalog | `grep-files.sh`, `cleanup-stale-results.sh`, `node-eval.sh`, **`peek-files.sh`** (Finding G — `<pattern> [--lines N] [--exclude PATH]`) ship with tests. `commands/dispatch.md` and PAYLOAD template have "Investigation patterns" examples. ANTIPATTERNS.md has §"Investigation patterns" cross-ref. | Antipattern lint passes against updated dispatch.md + template. |
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

## Post-close follow-ups identified after milestone shipped

(Added 2026-05-04. M028 closed 2026-04-29. These follow-ups did not exist when M028 was scoped; if a future autonomous-hardening milestone (M028 v4 / similar) is opened, these are pre-identified inputs.)

- **Lease-based locks for `orchestrator:auto`** — adopted from GSD v2.79+v2.80 DB-authoritative migration (the *lease* pattern, not the DB migration itself; Principle VI conflict precludes the latter). Replace file-based `auto.lock` with `.orchestrator/locks/auto.lease` carrying `{owner_pid, owner_started_at, heartbeat_ts, ttl_seconds}`. Heartbeat update every N seconds. Lock acquisition: read TTL → if `now - heartbeat_ts > ttl + grace`, claim is stale → break-and-claim (with recovery briefing per `orchestrator:resume`). Replaces existing stale-lock detection in `orchestrator:resume`. Source: `gsd-2-adoption-scan-2026-05-04.md` §6. Effort: ~1–2 days. Captured here (not in a separate proposal) because it's natural autonomous-hardening territory and the closed M028 brief is the right archaeological pointer when the next hardening milestone plans.

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
- **Finding G sources** (added 2026-04-28 during proposal-update session):
  - Operator screenshot 2026-04-28 22:25 — Claude Code permission-prompt UI showing `find … | head … | xargs -I{} sh -c '…echo;head…'` and the literal-bytes "don't ask again" rule offer
  - `scripts/verify/lib/shape-classifier.sh::classify_command` — needs `sh -c '<body>'` body-descent for AP-014
  - `scripts/hooks/pre-bash-shape-guard.sh::reject_lookup` — new entry for AP-014 → `peek-files.sh`
  - Composes with Finding C (same root cause class — classifier under-matches embedded compound shapes; G is confirmed evidence for C's hypothesis)
- **Finding F sources** (added 2026-04-28 during M018 close):
  - `scripts/dispatch/adapters/runtime/claude-code.sh:170-189` (bare-command-name emission — the M025 follow-up bug)
  - `scripts/util/settings-merge.sh:270-310` (uninstall cascade exists; install-side dedup missing)
  - `packaging/bundle/hooks/before-commit.json`, `packaging/bundle/hooks/post-verify.json` (the actual hook commands the adapter should be referencing)
  - `scripts/lifecycle/before-commit.sh`, `scripts/lifecycle/after-verify-sync.sh` (the lifecycle scripts that need to be copied alongside `pre-bash-shape-guard.sh`)
  - `~/.claude/settings.json.bak-m018-cleanup-2026-04-28` (operator-side backup capturing the duplicated-orphan state for P01 replay; lives outside the repo)
  - `.orchestrator/milestones/M025/M025-SUMMARY.md` `affects:` field — explicitly names this carve-out as a future-milestone concern
