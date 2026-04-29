---
schema_version: "1.0"
type: feature-spec
feature_slug: "031-autonomous-hardening-v3"
created_at: "2026-04-28"
status: "Draft"
milestone: "M028"
---

# Feature Specification: Autonomous Hardening v3 — Hook Portability, Adapter+Installer Dedup, Five New Shape Classes, Investigation-Pattern Wrappers

**Feature Branch**: `031-autonomous-hardening-v3`
**Created**: 2026-04-28
**Status**: Draft
**Milestone**: M028
**Input**: User description: "Close the gap between M021's shape-guard infrastructure and the actual autonomous-run experience. Seven findings from a 2026-04-25→2026-04-28 sweep of `orchestrator:auto` interruption screenshots: (A) the shape-guard hook fails-open in consumer projects because its classifier path is project-relative; (B) four new shape classes outside M021's matrix (backtick-in-grep-regex, quoted-arg-newline-hash, multiline-quoted-script, unquoted-brace-glob); (C) compound shapes possibly slipping past the existing classifier; (D) destructive `/bin/rm` always prompts; (E) agents invent compound shells when no canonical investigation example exists; (F) M025 hook-shim regression — adapter emits bare command names not on PATH, merge helper accumulates duplicates on rerun, flag-less orphans defeat the uninstall cascade; (G) shape-guard miss on `find … | head … | xargs -I{} sh -c '…echo;head…'` plus Claude Code's literal-bytes 'don't ask again' rule offer. Findings A and F are siblings (both touch the installer + adapter surface) and fold into one phase. Ship before M024 broadens autonomous mode into arbitrary consumer projects."

## Problem Statement

M021 (autonomous hardening v2) shipped a 10-pattern shape-classifier matrix, a 21-entry replay corpus, a PreToolUse hook, and a payload-fence linter. That work is complete and stable inside this repository. A fresh sweep of seven `orchestrator:auto` interruption screenshots (2026-04-25 to 2026-04-26) plus an operator-reported Stop-hook failure during M018 close (2026-04-28) and a permission-prompt UI screenshot (2026-04-28 22:25) surface a layered gap M021 never addressed: the shape-guard infrastructure is correct but does not actually fire in the autonomous-run conditions M028 ships into.

The residual prompts and broken hooks fall into four orthogonal classes:

1. **The hook isn't portable to consumer projects (Finding A) and the lifecycle adapter emits bare command names not on PATH (Finding F).** `scripts/hooks/pre-bash-shape-guard.sh:39-42` resolves the classifier via `$CLAUDE_PROJECT_DIR`, so when the consumer project is `bbt-companion` (or any other downstream consumer) the path doesn't exist and the hook falls through to passthrough (`exit 0`). Independently, `scripts/dispatch/adapters/runtime/claude-code.sh:170-189` emits `"command": "orchestrator-post-verify"` and `"command": "orchestrator-before-commit"` as bare names — the actual scripts live at `scripts/lifecycle/before-commit.sh` and `scripts/lifecycle/after-verify-sync.sh`, but no shim is installed, so Claude Code's hook runner finds nothing on PATH and emits `command not found` on every Stop event. M025 shipped uninstall-cascade dedup keyed on `_orchestrator_managed: true` but no install-side dedup, so each `install-claude-code.sh` rerun appends another duplicate; the operator's `~/.claude/settings.json` accumulated 5 duplicate `Stop` wrappers and 7 duplicate `PreToolUse` Bash wrappers, none carrying the `_orchestrator_managed` flag, defeating both the cascade and any future `--repair` operation.

2. **The classifier under-matches five new shapes outside M021's matrix (Findings B and G).** Backtick inside a grep regex (`grep '^- \`bash...'`) reads as command-substitution attempt; newline + `#` inside a quoted `--last-action` arg trips the path-validation security heuristic; a multi-line `node -e "…"` body hits the `ansi_c_string` parser fallthrough; raw `{2,3,4,5}` outside quotes triggers brace-expansion heuristics that AP-007 only catches inside quotes; and the load-bearing one — `find … | head … | xargs -I{} sh -c '…echo;head…'` — has three top-level pipes plus an inner `;` chain inside the quoted `sh -c` body, but the classifier counts top-level connectors only and treats `xargs` as a sink, producing a count ≤ 2 that AP-009 (`compound-chain-gt2`) refuses to reject. Each is reproducible from a verbatim screenshot.

3. **Investigation patterns invent compound shells because no canonical example covers them (Findings C, D, E).** M021's payload linter scans `commands/*.md`, `templates/*.md`, and `**/tasks/*-PAYLOAD.md`, but agents performing mid-task investigation have no covering artifact. They reach for `grep …; echo "---"; grep …`, `/bin/rm -f .../*.txt && ls .../*.txt`, inline `node -e "…"`, and the Finding G `find | head | xargs sh -c '…'` pattern because nothing tells them which wrapper to call instead. Even when M021's matrix would catch the result, the agent never gets the rejection because the matrix doesn't know the shape.

4. **Claude Code's "don't ask again" rule is literal-bytes, not shape-pattern (Finding G, partial).** The orchestrator can't fix Claude Code's prompt UI — that's product surface — but the hook must fire *first* so the operator never has the option to accept an under-specified rule that progressively pre-approves shape-unsafe commands at the runtime layer.

Fix all four classes in one milestone, with the load-bearing fixes (Findings A and F — installer + adapter portability) folded into a single phase because they touch the same surface, and a P01 empirical baseline that gates whether the milestone runs full-shape or collapses to two quick PRs.

## User Scenarios & Testing *(mandatory)*

### Minimal Slice (Phase 1 Load-Bearing Scope)

The minimum coherent subset that closes the dogfood loop is **P01 (empirical baseline) + P02 (hook portability + M025 follow-up)**: the seven new corpus entries appended to `tests/fixtures/m021-prompt-corpus.txt` produce known classification verdicts (P01); the installer copies the hook, classifier, reject_lookup, and lifecycle scripts into `~/.claude/orchestrator-hooks/`; the shape-guard hook self-locates via `$0`; the runtime adapter emits absolute `bash <hooks-dir>/<name>.sh` invocations; and the merge helper deduplicates on `(event, matcher, command)` × `_orchestrator_managed: true` (P02). Once that slice ships, every downstream consumer project that runs `orchestrator:auto` benefits from a hook that actually fires and a Stop sequence that actually runs the post-verify lifecycle script. P03–P05 (classifier extension, investigation-pattern wrappers, cross-project replay verifiers) compound on top but are not load-bearing for the M024 unblock — they close the long tail and the agent-invented shape gap respectively.

The collapse condition is part of the contract: if P01 baseline shows that fixing only Finding A resolves 6 of 7 screenshots, M028 collapses to two PRs (PR-1: hook portability; PR-2: the one outlier as a corpus entry + classifier rule) and P03–P05 stand down. P01 evidence — not estimation — gates this.

### User Story 1 — Downstream Consumer-Project Autonomous Run Executes Without Interruption (Priority: P1)

A developer working in `bbt-companion` (or any other project that consumes the orchestrator skill bundle) runs `orchestrator:auto`. Every Bash tool call that would prompt under M021 is caught by a PreToolUse shape-guard hook installed once at `~/.claude/orchestrator-hooks/pre-bash-shape-guard.sh`. The hook resolves its classifier and reject_lookup table relative to its own location (`$0`), not relative to `$CLAUDE_PROJECT_DIR`. Stop and PreToolUse Bash hooks fire successfully because the runtime adapter emitted absolute `bash <hooks-dir>/<name>.sh` paths in `~/.claude/settings.json`, not bare command names.

**Why this priority**: Every M028 finding is moot if the hook doesn't fire in consumer projects, and `command not found` from the Stop hook breaks lifecycle close-out on the orchestrator's own repo today. Findings A and F together unblock M024 (universal intake under autonomous mode) and every milestone after that runs `auto` in a non-orchestrator-repo context.

**Independent Test**: A permanent fixture project at `tests/fixtures/downstream-project/` shaped like a minimal consumer (its own `.claude/settings.json` pointing at the runtime-stable `~/.claude/orchestrator-hooks/` location, no `scripts/hooks/` of its own). A test harness runs an autonomous-loop fixture against it, replaying the seven Finding A/B/G screenshot commands plus a Stop event. Every Bash call resolves to allow / hook-rewrite / hook-reject; the Stop event fires `bash ~/.claude/orchestrator-hooks/after-verify-sync.sh` and exits 0; zero approval prompts surface; zero `command not found` diagnostics surface.

**Acceptance Scenarios**:

1. **Given** the `tests/fixtures/downstream-project/` fixture with its `.claude/settings.json` pointing at `~/.claude/orchestrator-hooks/`, **When** the autonomous-loop fixture replays a verbatim Finding A screenshot command, **Then** the shape-guard hook fires (locating its classifier via `$0`) and emits a `REJECT:` diagnostic naming the appropriate AP-ID and wrapper.
2. **Given** the same fixture, **When** the Stop event fires, **Then** Claude Code resolves the hook command as `bash ~/.claude/orchestrator-hooks/after-verify-sync.sh`, the script executes, and no `command not found` diagnostic surfaces.
3. **Given** a fresh `~/.claude/settings.json` (no prior orchestrator install), **When** `bash packaging/install/install-claude-code.sh` runs once, **Then** the runtime-stable hooks dir contains the shape-guard hook, the classifier library, the reject_lookup table, and both lifecycle scripts; `~/.claude/settings.json` carries the installed entries each tagged `_orchestrator_managed: true`.
4. **Given** a consumer project whose `$CLAUDE_PROJECT_DIR` is not the orchestrator repo, **When** the shape-guard hook fires, **Then** the hook resolves its classifier via `$(dirname "$0")/shape-classifier.sh` and never references `$CLAUDE_PROJECT_DIR`.

---

### User Story 2 — Combined M021 + M028 Corpus Replays Clean With Zero Prompts (Priority: P1)

A developer runs the regression replay against the unified corpus. M021's 21 entries produce their previous verdicts (no regressions). The seven new M028 entries (one per screenshot, plus the operator-reported Stop-hook command and the Finding G `xargs sh -c` body) each resolve to allow / rewrite / reject per the verdict P01 records. Five new antipatterns (AP-010 `cmd-sub-in-pattern`, AP-011 `quoted-arg-newline-hash`, AP-012 `multiline-quoted-script`, AP-013 `unquoted-brace-glob`, AP-014 `xargs-sh-c-compound-body`) ship with corresponding entries in `ANTIPATTERNS.md`, classifier rules, reject_lookup mappings, and corpus lines.

**Why this priority**: This is the closing-the-loop test. The screenshots *are* the regression corpus — if the hardened classifier replays them with the expected verdicts, the autonomy claim is defensible. AP-014's `sh -c '<body>'` body-descent is the most subtle of the five additions and the only one that requires real classifier logic beyond pattern-matching.

**Independent Test**: `bash tests/run-prompt-corpus-replay.sh` against the appended `tests/fixtures/m021-prompt-corpus.txt`. Each line carries an expected-verdict comment annotation; the harness compares actual classifier output to expected and exits 0 only on 100% match. Failure messages name the line, the classifier output, and the expected verdict.

**Acceptance Scenarios**:

1. **Given** the verbatim Finding G screenshot command (`find .orchestrator -name "T*-SUMMARY.md" -not -path "*/M066/*" 2>/dev/null | head -3 | xargs -I{} sh -c 'echo "═══ {} ═══"; head -20 "{}"'`), **When** the classifier runs, **Then** AP-014 fires — the classifier descends into the `sh -c '<body>'` token stream, sums in-body `;`/`&&`/`|` connectors with top-level pipe count, and rejects when the combined count exceeds 2 — and the reject_lookup maps the verdict to `scripts/util/peek-files.sh`.
2. **Given** the verbatim Finding B screenshot commands (backtick-in-grep, quoted-arg-newline-hash, multi-line node-eval, unquoted brace-glob), **When** the classifier runs, **Then** AP-010 / AP-011 / AP-012 / AP-013 fire respectively, each pointing the reject_lookup at the appropriate wrapper or rewrite hint.
3. **Given** all 21 M021 corpus entries, **When** the classifier runs against the M028-extended classifier, **Then** every entry produces the same verdict it produced under M021 (strict superset; zero regressions).
4. **Given** the operator-reported `orchestrator-post-verify: command not found` Stop-hook failure, **When** a fresh-install fixture replays the Stop event after P02 is in place, **Then** the lifecycle script executes successfully and the failure is annotated as resolved-by-finding-F in the corpus comment.

---

### User Story 3 — Installer Is Idempotent Under Repeated Runs (Priority: P1)

A developer reruns `bash packaging/install/install-claude-code.sh` against an already-installed `~/.claude/settings.json`. The merge helper deduplicates on the tuple `(event, matcher, command) × _orchestrator_managed: true`. The second run produces a settings.json byte-identical to the first. A subsequent `bash packaging/install/install-claude-code.sh --uninstall` removes only entries carrying the `_orchestrator_managed` flag, returning the file to its pre-install canonical bytes. A `--repair` flag detects flag-less orphans whose `(event, matcher, command)` tuple matches a known M025 pattern fingerprint and removes them — exactly the manual cleanup performed for the operator during M018 close becomes a one-liner.

**Why this priority**: M028's other findings are useless if installs themselves don't dedup. Each `install-claude-code.sh` rerun today doubles broken-hook noise; each broken-hook entry without the `_orchestrator_managed` flag also defeats the M025 uninstall cascade. The pinned-sha install round-trip gate (per M025/P01's reversibility pattern) is the canonical-bytes proof that this is fixed.

**Independent Test**: `bash scripts/verify/m028/install-roundtrip.sh` snapshots a fresh `~/.claude/settings.json`, runs `install-claude-code.sh` twice, computes a SHA-256 of the resulting file, runs `install-claude-code.sh --uninstall`, and computes a SHA-256 of the result. The first SHA must equal the second-after-second-install SHA (idempotency) and the post-uninstall SHA must equal the pre-install SHA (reversibility). A separate fixture exercises `--repair` against a snapshotted file containing 5 flag-less Stop dupes plus 7 flag-less PreToolUse Bash dupes (mirroring the operator's M018-close state); the post-repair SHA must equal a pre-orphan canonical fixture.

**Acceptance Scenarios**:

1. **Given** a pre-install `~/.claude/settings.json` snapshot, **When** `install-claude-code.sh` runs twice in succession, **Then** the post-second-install file's SHA-256 equals the post-first-install file's SHA-256 (install-side dedup keyed on the M025 invariant).
2. **Given** a post-install state, **When** `install-claude-code.sh --uninstall` runs, **Then** the resulting file's SHA-256 equals the pre-install snapshot's SHA-256 (M025 reversibility extended to M028's expanded entry set).
3. **Given** a fixture containing flag-less orphan entries matching known M025 patterns (the operator's M018-close state), **When** `install-claude-code.sh --repair` runs, **Then** the orphans are removed and user-authored entries that happen to share an `event` or `matcher` but lack the M025 fingerprint are preserved verbatim.
4. **Given** the runtime adapter at `scripts/dispatch/adapters/runtime/claude-code.sh:170-189`, **When** it emits hook entries, **Then** every `command` field is an absolute `bash <hooks-dir>/<name>.sh` invocation, never a bare name, and every entry carries `_orchestrator_managed: true`.

---

### User Story 4 — Investigation-Pattern Wrappers Replace Compound Shells (Priority: P2)

A subagent dispatched to a task needs to (a) grep the same pattern across multiple files, (b) clean up stale per-step result files, (c) evaluate a short Node expression, or (d) peek at the first N lines of files matching a pattern. Instead of constructing a compound shell that trips the shape guard, the subagent calls one of four canonical wrappers in `scripts/util/`. The wrappers are referenced from a new "Investigation Patterns" section in `commands/dispatch.md` and the task-PAYLOAD template, and from the antipattern register's cross-reference index. ANTIPATTERNS.md gains a §"Investigation patterns" subsection.

**Why this priority**: The four screenshots in this class (Screenshots 1, 2, 4, 5, 6, plus Finding G) show agents inventing compound shells because no canonical example covers the shape. M021 proved that documenting the right shape is necessary but not sufficient — the wrapper has to exist and be discoverable. P2 because the classifier extension (US-2) catches the inventive shapes even without the wrappers; the wrappers are the "next time, do this instead" path.

**Independent Test**: Each wrapper has a dedicated gate script under `scripts/verify/m028/` that exercises happy path + at least one failure mode. `scripts/verify/anti-pattern-lint.sh` is run over the updated `commands/dispatch.md` and the task-PAYLOAD template; the lint must pass (the canonical examples must themselves be shape-clean). The wrappers must each appear in the dispatch payload's "Investigation patterns" section with a one-line usage example.

**Acceptance Scenarios**:

1. **Given** an agent needs to grep one pattern across multiple files, **When** `scripts/util/grep-files.sh <pattern> <file...>` is called, **Then** the wrapper grep-runs each file, prefixes per-file separators, and exits with the appropriate aggregate RC — replacing the `grep …; echo "---"; grep …` compound shell from Screenshot 1.
2. **Given** an agent needs to clean up stale per-step result files for milestone M, **When** `scripts/util/cleanup-stale-results.sh <milestone>` is called, **Then** the wrapper performs the rm + ls confirmation internally, captures output to a stable path, and exits 0 — replacing the `/bin/rm -f .../*.txt && ls .../*.txt` shape from Screenshot 2 (Finding D).
3. **Given** an agent needs to evaluate a short Node expression, **When** `scripts/util/node-eval.sh <expression>` is called, **Then** the wrapper invokes node from a stable allow-listed location with the expression as a positional arg, avoiding the `node -e "…"` `ansi_c_string` parser fallthrough — replacing the multiline-quoted-script shape from Screenshot 5 (AP-012).
4. **Given** an agent needs to peek at the first N lines of files matching a glob, **When** `scripts/util/peek-files.sh <pattern> [--lines N] [--exclude PATH]` is called, **Then** the wrapper enumerates matches, prints a per-file separator, and head-N's each file — replacing the Finding G compound `find | head | xargs -I{} sh -c '…echo;head…'` shape (AP-014).
5. **Given** the dispatch payload is built for a subagent, **When** the payload is rendered, **Then** its "Investigation patterns" section names all four wrappers with one-line usage examples and a cross-reference to the matching AP-ID.

---

### User Story 5 — Per-Finding Verifiers and a Real Consumer-Project Loop Fixture (Priority: P2)

A developer running the M028 verifier suite gets a green wall under `scripts/verify/m028/`: one verifier per finding (A, B, C, D, E, F, G), each a single-script-file flat shape per AD-19, each citing its source evidence file paths and the corpus line that exercises it. A second harness runs the autonomous-loop fixture against `tests/fixtures/downstream-project/` end-to-end and exits 0 with zero approval prompts and zero `command not found` diagnostics.

**Why this priority**: The verifiers turn the proposal's source-evidence list into mechanical regression tests; the fixture replay turns the manual-screenshot evidence into a CI-runnable artifact. Both are necessary for the close-out summary; both are P2 because they certify shipped work rather than gate it.

**Independent Test**: `bash scripts/verify/m028/run-all.sh` exits 0; the script enumerates per-finding verifiers and runs each, summarizing pass/fail. The fixture-replay harness `bash tests/run-downstream-fixture.sh` exits 0 on the canonical pass.

**Acceptance Scenarios**:

1. **Given** the M028 verifier suite under `scripts/verify/m028/`, **When** `run-all.sh` executes, **Then** every per-finding verifier runs and exits 0; the summary prints "M028: 7/7 findings verified".
2. **Given** `tests/fixtures/downstream-project/`, **When** the autonomous-loop fixture runs, **Then** every replayed screenshot command resolves to a non-prompt verdict, every Stop event runs its lifecycle script, and the final `unit_close` JSONL records contain zero `would_prompt: true` events.
3. **Given** AD-19's single-script-file shape rule, **When** the verifier suite is read, **Then** every verifier is a flat script under `scripts/verify/m028/` with no nested helper dirs (helpers may be sourced from existing `scripts/<concern>/` only).
4. **Given** AP-009 (no compound chains > 2 in agent-facing bash), **When** the shape-guard hook itself is read, **Then** its body contains no compound chain exceeding 2 connectors — the hook conforms to its own classifier output.

---

## Edge Cases

- **Hook self-location through symlinks**: If `~/.claude/orchestrator-hooks/pre-bash-shape-guard.sh` is symlinked, `$0` may resolve to either the link path or the target path depending on shell. The hook's location resolution must work in both cases — prefer `BASH_SOURCE[0]` over `$0` and resolve symlinks before locating the classifier.
- **AP-014 body-descent recursion bound**: A `sh -c '<body>'` body can itself contain `sh -c '<inner>'`. The classifier's body-descent must be one level deep only (count connectors at the outer body level + top level); deeper nesting is treated as opaque to avoid pathological recursion.
- **`--repair` false-positive risk**: A user-authored hook entry that happens to match an M025 pattern fingerprint but legitimately predates orchestrator install must be preserved. The repair pass requires a *strict* fingerprint match (exact `(event, matcher, command)` tuple) and must never modify entries with non-empty user-provided keys outside the M025-known set.
- **Pre-existing dupes lacking `_orchestrator_managed`**: Pre-install state may contain dupes from older orchestrator versions that never wrote the flag. P01 captures a snapshot of the operator's M018-close `~/.claude/settings.json.bak-m018-cleanup-2026-04-28` as a reproducible fixture; the `--repair` pass operates on this fixture as canonical evidence.
- **Verbatim corpus byte-fidelity**: Backticks, braces, newlines, and `═══` (Unicode box-drawing) bytes in the Finding G screenshot must round-trip through `tests/fixtures/m021-prompt-corpus.txt` without escaping that changes their classification. The corpus loader reads lines as raw bytes; comment annotations use `#` only at line start.
- **Downstream fixture drift**: `tests/fixtures/downstream-project/` is permanent (not generated at test time). If the fixture's `.claude/settings.json` schema falls out of sync with the runtime adapter, the fixture must fail noisily (not silently pass) — the harness asserts the fixture's settings.json matches the current adapter's emission shape before replaying.
- **Shape-guard hook self-conformance edge**: The shape-guard hook itself, written in bash, must contain no compound chain exceeding 2 connectors. Authoring under AP-009 is a self-applied constraint — the verifier `scripts/verify/m028/finding-G-self-conformance.sh` lints the hook against its own classifier output.
- **Concurrent install/uninstall**: Two `install-claude-code.sh` invocations racing on `~/.claude/settings.json` can interleave appends. Out of scope for M028 — a future hardening pass adds file locking; for now, a banner in install output warns against concurrent runs.

---

## Functional Requirements

- **FR-1 (hook-runtime-stable-location)**: `packaging/install/install-claude-code.sh` copies `pre-bash-shape-guard.sh`, `shape-classifier.sh`, the reject_lookup payload, and both lifecycle scripts (`before-commit.sh`, `after-verify-sync.sh`) into `~/.claude/orchestrator-hooks/` (the conversus-precedent dotdir convention). Satisfies User Story 1.
- **FR-2 (hook-self-locate)**: `pre-bash-shape-guard.sh` resolves its classifier and reject_lookup paths via `$(dirname "${BASH_SOURCE[0]}")` (with symlink resolution) — not via `$CLAUDE_PROJECT_DIR`. Satisfies US-1 acceptance scenario 4.
- **FR-3 (adapter-absolute-paths)**: `scripts/dispatch/adapters/runtime/claude-code.sh:170-189` emits `bash <runtime-stable-hooks-dir>/<name>.sh` for every hook command, never a bare name. Carries the `_orchestrator_managed: true` flag on every emission. Satisfies US-1 + US-3.
- **FR-4 (lifecycle-hooks-bundled)**: `before-commit.sh` and `after-verify-sync.sh` ship to the same hooks dir as `pre-bash-shape-guard.sh`. The runtime adapter references them by absolute path. Resolves Finding F's `command not found` symptom.
- **FR-5 (install-side-dedup)**: `scripts/util/settings-merge.sh` gains an install-side dedup pass keyed on `(event, matcher, command) × _orchestrator_managed: true`. Each install-rerun is idempotent. Satisfies US-3 acceptance scenario 1.
- **FR-6 (install-roundtrip-gate)**: `scripts/verify/m028/install-roundtrip.sh` proves install → install → uninstall byte-equality (M025/P01's reversibility pattern, extended to M028's expanded entry set). Satisfies US-3 acceptance scenarios 1 + 2.
- **FR-7 (repair-flag)**: `bash packaging/install/install-claude-code.sh --repair` detects flag-less orphans matching known M025 pattern fingerprints (exact `(event, matcher, command)` match) and removes them. Preserves user-authored entries. Satisfies US-3 acceptance scenario 3.
- **FR-8 (AP-010-cmd-sub-in-pattern)**: `scripts/verify/lib/shape-classifier.sh::classify_command` gains a rule rejecting backtick characters appearing inside a regex argument to `grep`/`sed`/`awk`. `ANTIPATTERNS.md` gains AP-010 entry; reject_lookup maps to a remediation hint pointing at proper regex-escaping or `scripts/util/grep-files.sh`. Satisfies US-2.
- **FR-9 (AP-011-quoted-arg-newline-hash)**: Classifier rejects newline + `#` inside a quoted CLI argument (path-validation security heuristic). AP-011 entry in `ANTIPATTERNS.md`; reject_lookup remediation. Satisfies US-2.
- **FR-10 (AP-012-multiline-quoted-script)**: Classifier rejects multi-line bodies inside `node -e "…"` / `python -c "…"` / similar `<cmd> -e/-c` shapes (the `ansi_c_string` parser fallthrough trigger). AP-012 entry; remediation points at `scripts/util/node-eval.sh`. Satisfies US-2.
- **FR-11 (AP-013-unquoted-brace-glob)**: Classifier rejects raw `{N,M,…}` brace expansion outside quotes (AP-007 only catches *quoted* brace; AP-013 catches the unquoted case). AP-013 entry; remediation hint. Satisfies US-2.
- **FR-12 (AP-014-xargs-sh-c-compound-body)**: Classifier descends into `sh -c '<body>'` token streams (one level deep — see Edge Cases) and sums in-body `;`/`&&`/`|` connectors with top-level pipe count, rejecting when the combined count exceeds 2. AP-014 entry; reject_lookup maps to `scripts/util/peek-files.sh`. Satisfies US-2 acceptance scenario 1.
- **FR-13 (corpus-extension)**: Seven verbatim screenshot commands appended to the single permanent `tests/fixtures/m021-prompt-corpus.txt` (per pre-resolved decision: keep one corpus, regression-data shape, append; do not split into `m028-*`). Each line carries an expected-verdict comment annotation. Satisfies US-2.
- **FR-14 (wrapper-grep-files)**: `scripts/util/grep-files.sh <pattern> <file...>` ships with a gate test. Replaces the `grep …; echo "---"; grep …` compound shape (Screenshot 1). Satisfies US-4.
- **FR-15 (wrapper-cleanup-stale-results)**: `scripts/util/cleanup-stale-results.sh <milestone>` ships with a gate test. Replaces the `/bin/rm -f .../*.txt && ls .../*.txt` shape (Screenshot 2 / Finding D). Satisfies US-4.
- **FR-16 (wrapper-node-eval)**: `scripts/util/node-eval.sh <expression>` ships with a gate test. Replaces the multiline-quoted `node -e "…"` shape (Finding B #3 / AP-012). Satisfies US-4.
- **FR-17 (wrapper-peek-files)**: `scripts/util/peek-files.sh <pattern> [--lines N] [--exclude PATH]` ships with a gate test. Replaces the `find | head | xargs -I{} sh -c '…'` shape (Finding G / AP-014). Satisfies US-4.
- **FR-18 (dispatch-investigation-section)**: `commands/dispatch.md` and the task-PAYLOAD template gain an "Investigation patterns" section naming all four wrappers (FR-14 → FR-17) with one-line usage examples and AP-ID cross-references. `ANTIPATTERNS.md` gains a §"Investigation patterns" subsection. Satisfies US-4.
- **FR-19 (downstream-fixture)**: `tests/fixtures/downstream-project/` is a permanent fixture (per pre-resolved decision: permanent, not generated at test time) shaped like a minimal consumer project — its own `.claude/settings.json` referencing `~/.claude/orchestrator-hooks/`, no internal `scripts/hooks/`. Satisfies US-1 + US-5.
- **FR-20 (per-finding-verifiers)**: Each of the seven findings (A, B, C, D, E, F, G) has a verifier under `scripts/verify/m028/<finding>-verifier.sh`. Each verifier is a single flat script (AD-19); helpers are sourced from existing `scripts/<concern>/` only. `scripts/verify/m028/run-all.sh` invokes all seven and summarizes. Satisfies US-5.
- **FR-21 (shape-guard-self-conformance)**: The shape-guard hook itself (`pre-bash-shape-guard.sh`) is authored under AP-009 — its body contains no compound chain exceeding 2 connectors. The verifier `scripts/verify/m028/finding-G-self-conformance.sh` lints the hook against the M028 classifier output. Satisfies US-5 acceptance scenario 4.
- **FR-22 (corpus-replay-zero-regression)**: The 21 M021 corpus entries produce identical verdicts under the M028 classifier — strict superset, no regressions. The replay harness gates this via per-line expected-verdict comparison. Satisfies US-2 acceptance scenario 3.

## Success Criteria

- **SC-1 (combined-corpus-clean)**: The combined M021 + M028 corpus (28 entries) replays with 100% expected-verdict match against the M028 classifier; `bash tests/run-prompt-corpus-replay.sh` exits 0.
- **SC-2 (install-roundtrip)**: `bash scripts/verify/m028/install-roundtrip.sh` exits 0; pinned-sha gate proves install → install → uninstall produces byte-identical pre-install canonical bytes.
- **SC-3 (downstream-fixture-clean)**: `bash tests/run-downstream-fixture.sh` exits 0; the fixture autonomous-loop completes uninterrupted; final `unit_close` JSONL contains zero `would_prompt: true` events and zero `command not found` diagnostics.
- **SC-4 (per-finding-verifiers)**: `bash scripts/verify/m028/run-all.sh` exits 0; each of A, B, C, D, E, F, G has a passing verifier; the summary line reads "M028: 7/7 findings verified".
- **SC-5 (Stop-hook-success)**: A fresh-install fixture's Stop event resolves `bash ~/.claude/orchestrator-hooks/after-verify-sync.sh`, executes successfully, and emits no `command not found` diagnostic.
- **SC-6 (AP-014-classifier-descent)**: The verbatim Finding G screenshot command rejects under the M028 classifier with `REJECT: xargs-sh-c-compound-body` and the reject_lookup remediation points at `scripts/util/peek-files.sh`.
- **SC-7 (repair-fixture)**: `bash packaging/install/install-claude-code.sh --repair` against the operator's M018-close `~/.claude/settings.json.bak-m018-cleanup-2026-04-28` fixture produces a settings.json byte-identical to a pre-orphan canonical reference fixture; user-authored entries (validated via a control fixture mixing user + orphan entries) are preserved verbatim.
- **SC-8 (no-M021-regression)**: All 21 M021 corpus entries produce their previous verdicts under the M028 classifier (strict superset).
- **SC-9 (shape-guard-self-conformance)**: `bash scripts/verify/m028/finding-G-self-conformance.sh` exits 0; the hook body lints clean against AP-009.
- **SC-10 (collapse-condition-evidence)**: P01 baseline output records, per screenshot, whether Finding A alone resolves it. The decision to proceed-full-milestone vs. collapse-to-2-PRs is recorded in the milestone summary with P01's evidence cited.

## Non-Goals

- **Re-opening M021's matrix** — AP-001 through AP-009 are stable. M028 *adds* AP-010 through AP-014; it does not revise prior entries. Rationale: M021 verification artifacts must remain immutable to defend the regression claim.
- **Solving destructive operations generally** — only `rm`-shaped cleanup (Finding D / FR-15) is in scope. Other destructive verbs (`gh pr close`, force-push, `npm publish`) remain gated by Claude Code's destructive-op policy and don't need orchestrator-side wrappers. Rationale: scope discipline; M028 closes the *observed* gap, not a hypothetical one.
- **A "universal investigation skill"** — four concrete wrappers + a `commands/dispatch.md` Investigation Patterns section is enough. Rationale: rabbit hole risk; future shapes get added under M028's pattern when they reappear in a later run.
- **Changing Claude Code's "don't ask again" rule offer surface** — that's CC product surface, not orchestrator surface. M028 only ensures the hook fires before CC's prompt is reachable. Rationale: out of scope per Finding G's explicit OOS-2 carve-out.
- **Multi-runtime parity audit** — M009 (deferred post-launch) covers Codex CLI / Cursor parity for hook portability. M028 ships CC-only. Rationale: launch posture is CC-only per the 2026-04-28 roadmap revision.
- **Re-numbering AP-IDs** — pre-resolved decision: AP-010 through AP-014 (AP-009 is the last current entry). Rationale: stable IDs are referenced from corpus comments, hook reject_lookup, and screenshot annotations; renumbering would break that web.
- **Splitting findings A and F into separate phases** — they share the installer + adapter surface; the proposal already folds them into one P02 phase, and this spec preserves that fold. Rationale: changing one without the other leaves either bare-name commands pointing at runtime-stable paths (F without A) or hook portability without working lifecycle scripts (A without F) — the integration only gets verified when both ship together.

## Constraints

- **CON-1 (AD-19-single-script-file)**: All M028 verifiers (`scripts/verify/m028/*.sh`), wrappers (`scripts/util/*.sh`), and lifecycle scripts (`scripts/lifecycle/*.sh`) are flat single-file shapes. No nested helper directories under `scripts/verify/m028/` or `scripts/util/`. Helpers may be sourced from existing concern dirs (`scripts/dispatch/`, `scripts/state/`, `scripts/util/`) only.
- **CON-2 (bash-3.2-posix)**: All M028-shipped scripts run on bash 3.2 (constitution principle for macOS default-shell compatibility) and POSIX sh where invoked from `/bin/sh`. No bash 4+ associative arrays, no `mapfile`/`readarray`, no `<<<` here-strings unless guarded.
- **CON-3 (shape-guard-self-conformance)**: `pre-bash-shape-guard.sh` itself is authored under AP-009 — no compound chain exceeding 2 connectors anywhere in its body. The hook conforms to its own classifier output. Verified by FR-21.
- **CON-4 (M025-reversibility)**: Install → install → uninstall byte-equality (M025/P01's reversibility pattern) extends to Finding F's dedup logic. The pinned-sha round-trip gate (SC-2) is the canonical-bytes proof. M025's `_orchestrator_managed: true` tag semantics are stable; M028 extends with install-side dedup keyed on the M025 invariant — no new contract.
- **CON-5 (AP-014-body-descent)**: The classifier descends into `sh -c '<body>'` for connector counting — not just top-level pipe count. One level deep only (see Edge Cases). The combined count = top-level connectors + in-body connectors; reject when > 2.
- **CON-6 (no-new-runtime-deps)**: M028 introduces no new runtime dependencies. The hook + classifier remain pure bash + standard macOS/Linux tools (`grep`, `sed`, `awk`); no `jq`/`node`/`python` requirement beyond what the orchestrator already mandates.
- **CON-7 (no-M021-regression)**: The M028 classifier is a strict superset of M021's. SC-8 gates this; FR-22 enforces.
- **CON-8 (corpus-shape)**: The single permanent `tests/fixtures/m021-prompt-corpus.txt` is appended-to, never split. The file is regression data, not milestone-scoped. Pre-resolved decision: keep single corpus.
- **CON-9 (hook-install-location-stability)**: The runtime-stable hooks dir is `~/.claude/orchestrator-hooks/` (pre-resolved decision; conversus precedent of project-owned dotdir under `~/.claude/`). Not `~/.orchestrator/hooks/` and not `~/.claude/plugins/orchestrator/hooks/`. Stability is a contract: future installer versions may add files but must not move the dir.
- **CON-10 (downstream-fixture-permanence)**: `tests/fixtures/downstream-project/` is permanent in-tree (pre-resolved decision; not generated at test time). The harness fails noisily if the fixture's `.claude/settings.json` schema falls out of sync with the runtime adapter — see Edge Cases.

### Knowledge-Layer Boundary (M028 vs. M025)

M028 owns:
- `ANTIPATTERNS.md` — new entries AP-010 through AP-014
- `scripts/verify/lib/shape-classifier.sh::classify_command` — new pattern-class branches for AP-010 through AP-014, including AP-014's `sh -c '<body>'` descent
- `scripts/hooks/pre-bash-shape-guard.sh::reject_lookup` — new entries mapping AP-010 through AP-014 to wrappers
- `tests/fixtures/m021-prompt-corpus.txt` — appended new entries (file remains M021-named per regression-data convention)
- `scripts/util/{grep-files,cleanup-stale-results,node-eval,peek-files}.sh` — new wrappers
- `scripts/verify/m028/*.sh` — new verifier suite
- `tests/fixtures/downstream-project/` — new permanent fixture
- `commands/dispatch.md` + task-PAYLOAD template — new "Investigation patterns" section
- `~/.claude/orchestrator-hooks/` — new runtime-stable install location (its existence + contents)

M025 owns (M028 consumes, does not modify):
- `scripts/util/settings-merge.sh` — uninstall cascade convention; M028 extends with install-side dedup keyed on the M025 `_orchestrator_managed: true` invariant
- `_orchestrator_managed: true` tag semantics — stable; M028 emits the flag from every adapter-emitted entry (FR-3) but does not redefine its meaning
- `packaging/install/install-claude-code.sh` core flow — M028 adds `--repair` flag, copies additional payload (lifecycle scripts), but does not change the install-vs-uninstall contract

The boundary: M025 defines the install-coexistence invariants; M028 extends them with install-side idempotency and a `--repair` backfill, both keyed on M025's existing tag.

## Assumptions

- **A-1**: M025's `_orchestrator_managed: true` tag semantics are stable and load-bearing for both install-side dedup (new in M028) and uninstall cascade (existing).
- **A-2**: M021's 10-pattern matrix is stable; M028 adds AP-010 through AP-014 and does not revise prior entries.
- **A-3**: AP-009 (Task-PAYLOAD compound-chain) covers the shape-guard hook's own self-conformance. The hook body is verified against this rule via FR-21.
- **A-4**: Operators authorize writing to `~/.claude/orchestrator-hooks/` (conversus precedent of `~/.conversus/` argues for a project-owned dotdir; this is the pre-resolved decision).
- **A-5**: The runtime adapter's hook-emission shape (`scripts/dispatch/adapters/runtime/claude-code.sh:170-189`) is the only place that emits hook commands into `~/.claude/settings.json`. No other path emits hook entries; if one exists, it must be brought under FR-3's contract.
- **A-6**: `tests/fixtures/m021-prompt-corpus.txt` is a permanent regression-data file (not milestone-scoped); appending to it is the canonical extension shape.
- **A-7**: The seven source screenshots and the operator-reported Stop-hook failure are reproducible — their commands round-trip through the corpus without byte-loss. P01 verifies this empirically.

## Constitution Check

Compliance with `.orchestrator/memory/constitution.md` for each principle materially touched:

- **Principle II (Evidence Before Claims)**: Every finding traces to a dated screenshot or operator-reported failure with file paths and line numbers (proposal's Source Evidence section). P01's empirical baseline is the gating evidence for whether the milestone runs full-shape or collapses to 2 PRs — no estimation, screenshots replay verbatim and produce known verdicts.
- **Principle III (Design Before Code)**: This spec defines the contract before any classifier rule lands. The phase shape (P01 → P02 → P03 → P04 → P05) is in the proposal; this spec ratifies it. The collapse condition (Finding A alone resolves 6 of 7 → 2 PRs) is part of the contract, not a mid-flight discovery.
- **Principle VI (State On Disk Is Truth)**: The corpus is permanent regression data on disk; the verifier suite is on disk; the runtime-stable hooks dir is on disk; the install-roundtrip pinned-sha gate is a bytes-on-disk proof. M028's whole verification claim is canonical-bytes auditable.
- **Principle VII (Knowledge Compounds)**: ANTIPATTERNS.md gains five new cross-referenced entries (AP-010 to AP-014) that link hook + classifier + corpus + wrapper. The "Investigation patterns" section in `commands/dispatch.md` and ANTIPATTERNS.md is a new knowledge surface that compounds with M021's. Every wrapper carries its AP-ID cross-reference; every corpus line carries its expected-verdict annotation; future agents inherit all of it.
- **Principle XIV (No Speculative Complexity, if numbered as such in the constitution)**: M028's pattern set is closed on the evidence from seven screenshots + one operator-reported failure + one permission-prompt UI screenshot. Five new APs, four new wrappers, one new fixture — no shape gets added speculatively. The Non-Goals list explicitly carves out future shapes ("re-emerge in a later run").
- **Principle XV (Distribution Surface Integrity, if numbered as such)**: The hook + classifier + reject_lookup + lifecycle scripts ship inside the install bundle, not project-relative. The runtime adapter emits absolute paths. Install idempotency is gated by pinned-sha bytes. M028 directly reinforces the distribution-surface invariant.
- **Principle IX (Bash 3.2 Compatibility, if numbered as such)**: CON-2 enforces; every new script is verified against bash 3.2 + POSIX sh.

(Constitution principle numbers above are best-effort references; the planning agent confirms exact numerals against `.orchestrator/memory/constitution.md` during the discuss/plan-phase pass.)

## Open Questions (defer to planning)

All four open questions named in the proposal's "Open questions for orchestrator:specify" section were pre-resolved by the operator at spec-authoring time and are recorded here for the planning record:

- **#Q-1 (hook-install-location)** — **Resolved**: `~/.claude/orchestrator-hooks/` (conversus precedent of project-owned dotdir under `~/.claude/`). Encoded in CON-9 + FR-1.
- **#Q-2 (cross-project-test-fixture)** — **Resolved**: Permanent in-tree fixture under `tests/fixtures/downstream-project/`. Encoded in CON-10 + FR-19.
- **#Q-3 (corpus-naming)** — **Resolved**: Single permanent `tests/fixtures/m021-prompt-corpus.txt`; append M028 entries. The file is regression data, not milestone-scoped. Encoded in CON-8 + FR-13.
- **#Q-4 (AP-numbering)** — **Resolved**: AP-010 through AP-014 (AP-009 is the last current entry, confirmed via `grep '^## AP-' ANTIPATTERNS.md` 2026-04-28). Encoded in FR-8 → FR-12.

Remaining items for plan-phase:

- **#Q-5 (constitution-principle-numerals)**: The Constitution Check section cites principles by best-effort numeral; the planning agent confirms exact numerals against `.orchestrator/memory/constitution.md` and updates the spec's Constitution Check accordingly. Owner: gsd-planner / orchestrator:plan-phase.
- **#Q-6 (P01-empirical-verdict)**: The collapse condition (Finding A alone resolves 6 of 7 screenshots → collapse to 2 PRs) is gated on P01's actual replay output. Until P01 runs, the milestone retains the full 5-phase shape; if P01 evidence supports collapse, the planning agent rewrites P02–P05 into PR-1 + PR-2 per the proposal's collapse rubric. Owner: P01 verifier output → orchestrator:plan-phase decision.

## Dependencies

- **M016 (autonomous hardening v1)** — predecessor; M021 + M028 build on its 9-pattern matrix.
- **M021 (autonomous hardening v2)** — predecessor; M028 strictly extends its 10-pattern matrix and reuses the corpus + linter + hook infrastructure.
- **M025 (installer coexistence)** — Finding F is M025's follow-up; M028 extends `settings-merge.sh` install-side and adds a `--repair` flag.
- **scripts/specify/specify.sh** + `scripts/util/dual-write-runtime-md.sh` — used by this spec authoring (not load-bearing for M028 implementation).
- **conversus** (`scripts/dispatch/adapters/tool/conversus.sh`) — only invoked by the optional pass-3 gate; M028's implementation has no conversus dependency.

## Downstream Consumers (informational, not binding)

- **M024 (universal intake & routing)** — already closed, but the pattern of M024 broadening autonomous mode into arbitrary consumer projects is what makes Finding A load-bearing; the next milestone running `auto` in a non-orchestrator-repo context will exercise FR-1 through FR-7 in production.
- **M030 (adaptive model selection)** — autonomous-loop reliability is a prerequisite; M028's portability fixes are necessary infrastructure.
- **M031 (right-sized entry)** — same reliance on autonomous-loop correctness.
- **M033 (project onboarding experience)** — fresh-install correctness is critical for first-impression workflows; FR-3 + FR-5 + FR-6 directly underwrite this.
- **M035 (packaging & distribution)** — install-side dedup + reversibility are prerequisites for shipping `install-claude-code.sh` through package managers; M028's install-roundtrip pinned-sha gate is the canonical-bytes proof M035's publishing pipeline can rely on.
- **M009 (multi-runtime parity audit, deferred post-launch)** — inherits M028's `_orchestrator_managed`-tag-keyed dedup invariant when extended to Codex CLI / Cursor adapters.
