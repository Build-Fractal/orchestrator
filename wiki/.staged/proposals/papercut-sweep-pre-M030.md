# Paper-Cut Sweep PR Brief — Pre-[M030](../milestones/M030/index.md)

**Created**: 2026-04-30
**Source**: `CLAUDE.md` "Near-term D021-style hotfixes" section (all items dated 2026-04-28..2026-04-29)
**Goal**: Bundle every CLAUDE.md hotfix-queue item into a single sweep PR before M030 (adaptive model selection) starts.
**Posture**: Standalone PR — not a milestone, not a phase. No `orchestrator:plan-phase` ceremony. Direct execution by a fresh agent against this brief.
**Branch**: `papercut-sweep/pre-M030`

## Why a single PR

All 18 items are independent narrowly-scoped fixes that have already been root-caused with patch shape documented inline in CLAUDE.md. Bundling avoids 18 micro-PRs of churn while keeping each commit logically isolated for `git log` readability. The PR description summarizes each item one-line; commits carry the full context.

## Out of scope (do NOT include)

- Item #4 in CLAUDE.md ("auto-loop `--step=V` eval'd `Expected output:` example fences as commands") — **already fixed** in commit `73effdc`. Logged in CLAUDE.md as documentation of an existing fix; nothing to sweep. Verify `scripts/lifecycle/auto-loop.sh:340-353` carries the verdict-prefix-skip and skip if so.
- [M032](../milestones/M032/index.md) invariant encoding for "project-owned paths must not collide with staged dirs" — text-only amendment deferred until M032 enters planning per CLAUDE.md. Item #19 (planner template `tools/verify/`) still ships in this PR; only the spec-side invariant defers.

## Items and patch shapes

Items grouped by file-touch surface so each commit is reviewable in isolation. Verify the bug shape before patching — CLAUDE.md is dated 2026-04-29 and the orchestrator is its own dogfood, so things may have shifted in the day since. **Patch verification rule**: for each item, run the existing reproduction or write a smoke test that fails pre-patch and passes post-patch, before committing.

---

### Group 1 — Auto-loop / state-derivation readers (slug-suffix asymmetry)

**Item 1 — slug-suffix summary read asymmetry**

Three readers resolve `${task_id}-SUMMARY.md` literally; when planner emits slug-suffixed plan filenames (`T01-input-audit-PLAN.md`), readers look for `T01-input-audit-SUMMARY.md` while `write-summary.sh` writes the bare `T01-SUMMARY.md`. Result: `auto` re-dispatches completed work on iteration 1 of every Tier C run with slug-bearing plans.

**Sites** (verified 2026-04-30):
- `scripts/state/derive-phase.sh:142` — `summary_file="$tasks_dir/${task_id}-SUMMARY.md"`
- `scripts/lifecycle/auto-loop.sh:546` — same
- `scripts/lifecycle/recovery-briefing.sh:119` — same

**Patch shape** (Path A: bilateral tolerance — readers accept either form): symmetric ~10-line patch across all three sites mirroring `4747f086`'s fallback shape. After computing `summary_file`, also try the bare form via `${task_id%%-*}-SUMMARY.md` if the slug-suffixed form misses. Pull verbatim from lakeledger commit `f8335b6a` if the diff lifts cleanly; otherwise replicate the shape inline. **Path B (have `write-summary.sh` emit slug-bearing files) is rejected** per CLAUDE.md.

**Verification**: smoke test — write `tests/test-summary-read-asymmetry.sh` that creates a phase dir with one slug-suffixed `T01-input-audit-PLAN.md` and a bare `T01-SUMMARY.md`, then asserts all three readers return "task complete" for T01. Add to `tests/run-suite.sh`.

**Commit**: `paper-cut(state): bilateral-tolerance for slug-suffix summary lookup`

---

### Group 2 — Read-roadmap parser

**Item 3 — `read-roadmap.sh` Depends: literal-token parsing**

`scripts/state/read-roadmap.sh` parses `Depends:` lines verbatim, so mixed entries like `Depends: P03, BG-002 closure` put `BG-002 closure` into the deps slot. Already produces a "unparseable dependency token" warning at line 277 — but consumers may treat the warning as fatal.

**Site**: `scripts/state/read-roadmap.sh:149-160` (the `Depends:` extraction block).

**Patch shape**: filter extracted tokens to `^P[0-9]+$` (POSIX BRE — no `\d` in BSD grep). Drop non-matching tokens silently if they look like commentary (`Blocked by: BG-002 closure`); warn loudly only on tokens that look like deps but don't match the shape. Document the convention in `templates/roadmap.md` (or whichever roadmap template exists): `Depends:` (phases only) / `Blocked by:` (BG-### gates / external).

**Verification**: smoke test — synthetic roadmap with `Depends: P03, BG-002 closure` should resolve deps to `["P03"]` only with no fatal exit. Add to `tests/test-read-roadmap.sh` (extend if exists; create if not).

**Commit**: `paper-cut(roadmap): filter Depends: tokens to ^P\\d+$ shape`

---

### Group 3 — Conversus adapter defensive guard

**Item 2 — conversus adapter provider-error stub-content guard**

`scripts/dispatch/adapters/tool/conversus.sh::parse_verdict` extracts the verdict from `gate-result.md` without validating that per-agent artifacts contain real deliberation content. Conversus 0.3.0 has a known correctness bug where unreachable model IDs produce stub error-string content that gets synthesized as PASS-by-empty.

**Site**: `scripts/dispatch/adapters/tool/conversus.sh::parse_verdict` (search for `parse_verdict` function).

**Patch shape** (~30 lines): grep `gate-result.md` and per-agent artifacts for the literal `"There's an issue with the selected model"` and a small allow-list of known SDK-error patterns BEFORE parsing the verdict; on match emit `FAIL: conversus produced provider-error stub content` and `exit 1`. Use a bash array `KNOWN_PROVIDER_ERROR_PATTERNS=(...)` for extensibility. Reliability insurance regardless of upstream conversus fix timing.

**Verification**: stage a synthetic `gate-result.md` containing the stub error string in `tests/fixtures/conversus-provider-error/`; assert `parse_verdict` exits 1 with the expected `FAIL:` substring on stderr. Stage a clean `gate-result.md` and assert the function still returns the parsed verdict normally.

**Commit**: `paper-cut(conversus): defensive provider-error stub guard in parse_verdict`

---

### Group 4 — check-must-haves key-link parser (two related items)

**Item 6 — `from_path` resolves only against project root**

`scripts/verify/check-must-haves.sh:240` sets `from_full="$PROJECT_ROOT/$from_path"`. Plan-relative bare filenames in Key Links (e.g. `M066-CATALOG.md → spec.md` written without the `.orchestrator/milestones/<MID>/phases/<PID>/` prefix) report FAIL.

**Site**: `scripts/verify/check-must-haves.sh:240`.

**Patch shape**: try `$PHASE_DIR/$from_path` before `$PROJECT_ROOT/$from_path`. Mirrors `4747f086`'s fallback shape. Use the existing `PHASE_DIR` variable (set earlier in the script — verify).

**Item 7 — `to_path` greps for literal extension**

`scripts/verify/check-must-haves.sh:249` greps for the literal target basename including `.ts`/`.tsx` extension. TS/TSX module specifiers omit extensions (`from '@/lib/health/score'`).

**Site**: `scripts/verify/check-must-haves.sh:249-251` (the `grep -q "$to_basename" "$from_full"` block).

**Patch shape**: when `to_basename` ends in `.ts` or `.tsx`, also try the basename without extension as a secondary grep. Initial scope: just `.ts`/`.tsx` (TypeScript surface). A future scope-up could read a project-extension-list config (`.py`, `.go`, etc.) but defer.

**Verification**: extend `tests/test-check-must-haves.sh` (create if absent) with two cases:
1. Plan with key-link `T01-PLAN.md → spec.md` where `spec.md` lives at the phase dir (not project root) — assert PASS post-patch, FAIL pre-patch.
2. Plan with key-link `StatusBar.test.ts → StatusBar.ts` where the test file imports via `from './StatusBar'` (no extension) — assert PASS post-patch.

**Commit**: `paper-cut(check-must-haves): PHASE_DIR fallback + .ts/.tsx extension stripping for key-links`

---

### Group 5 — Auto-loop verification parser (bare-backtick bullets)

**Item 8 — bare-backtick bullets dropped by `--step=V` parser**

`scripts/lifecycle/auto-loop.sh:352` outside fences only matches `^[[:space:]]*-?[[:space:]]*Check:[[:space:]]*\`[^\`]+\``. Bare-backtick bullet shape `` - `bash scripts/verify/foo.sh` `` is silently dropped; auto-loop reports `AUTO:VERIFY_NO_CHECKS` even though the section has executable content. Error message at the no-checks branch claims bare-backtick bullets are accepted but they aren't.

**Site**: `scripts/lifecycle/auto-loop.sh:352-358` (the `Check:` extraction branch) plus the no-checks-found error message (search for `AUTO:VERIFY_NO_CHECKS`).

**Patch shape** (preferred — matches docstring intent): add a sibling branch matching `^[[:space:]]*-[[:space:]]*\`[^\`]+\`[[:space:]]*$` (bare-backtick bullets — no `Check:` prefix). Extract the backtick contents as the command. Keep the existing fenced-code-block branch and `Check:`-prefix branch unchanged.

**Alternative** (rejected): just update the error message to tell the truth. CLAUDE.md says preferred path is to make the parser match the docstring.

**Verification**: extend `tests/test-auto-loop-verify-extraction.sh` Test 4 with a fixture containing only bare-backtick bullets in `## Verification`; assert the parser extracts them and reports the correct count.

**Commit**: `paper-cut(auto-loop): accept bare-backtick bullets in --step=V parser`

---

### Group 6 — settings-merge uninstall arm

**Item 14 — `uninstall` arm uses leaf-only managed detection**

`scripts/util/settings-merge.sh:338-343` checks `any_managed` at the leaf level only. T04's `repair` subcommand (line 418 `wrapper_is_managed()`) correctly handles wrapper-OR-leaf. Uninstall does not. Pre-T02-installed user running `--uninstall` on a wrapper-flagged settings.json today will leave wrapper-flagged entries behind.

**Site**: `scripts/util/settings-merge.sh:338-343` (the `uninstall` arm `any_managed` block).

**Patch shape** (~10 lines): extend uninstall's `any_managed` check to also accept wrapper-level flags, mirroring the existing `wrapper_is_managed()` helper at line 418. Cleanest form: refactor `uninstall` to call `wrapper_is_managed()` directly rather than duplicating the leaf-only logic. Verify the existing helper is in scope of the uninstall arm (same Python heredoc) — if not, hoist it.

**Verification**: stage two fixtures under `tests/fixtures/m028-uninstall-wrapper-flagged/`:
1. wrapper-level `_orchestrator_managed: true` (no leaf flags) — assert post-uninstall the wrapper is removed.
2. mixed (wrapper-level true, some leaves flagged + some user-authored) — assert post-uninstall wrapper-managed entries removed but user-authored leaves preserved.

Smoke test in `tests/test-settings-merge-uninstall.sh`.

**Commit**: `paper-cut(settings-merge): wrapper-OR-leaf managed detection in uninstall arm`

---

### Group 7 — Stale verifiers (M025/[M013](../milestones/M013/index.md) contract drift)

**Item 15 — `m025-p01-merge-preservation.sh` + `m013-p04-post-verify-hook.sh`**

Both reference M025-baseline bare-name commands (`orchestrator-post-verify`, `orchestrator-before-commit`) that M028/P02/T02 retired in favor of absolute `bash <abs-path>.sh` emission.

- `m013-p04-post-verify-hook.sh` was already failing pre-[M028](../milestones/M028/index.md) (asserts `hook_count=6` and `event: "post_verify"` JSON keys that the [M025](../milestones/M025/index.md) baseline emission has never produced — its schema is `hooks.{Stop,PreToolUse}`-keyed).
- `m025-p01-merge-preservation.sh:80-88` still asserts the bare-name commands as the dedup-collision target.

**Sites**:
- `scripts/verify/m025-p01-merge-preservation.sh:80-88`
- `scripts/verify/m013-p04-post-verify-hook.sh` (full rewrite — schema is wrong end-to-end)

**Patch shape**: same fix shape as `m025-p01-hook-schema.sh` already shipped in M028/P02/T02 — read its diff (`git log --all -p -- scripts/verify/m025-p01-hook-schema.sh` filtered to the M028 commits) and apply the same absolute-path / `_orchestrator_managed` assertion shape to both stale verifiers. For `m013-p04-post-verify-hook.sh`, restructure the assertions to walk the `hooks.{Stop,PreToolUse}` keys; drop the `event: "post_verify"` lookup entirely.

**Verification**: run both verifiers and assert exit 0. Extend `tests/run-suite.sh` if it doesn't already invoke them.

**Commit**: `paper-cut(verify): update m025/m013 stale verifiers to M028 absolute-path contract`

---

### Group 8 — Documentation / planner-rubric updates

This group folds **eight** items into one or two doc-only commits. They're all CLAUDE.md and `commands/plan-phase.md` and adjacent surfaces — no executable code change.

**Item 5 — `write-summary.sh` task-mode usage example shows minimal frontmatter**

`scripts/knowledge/write-summary.sh` task-mode docstring example shows only `task`, `phase`, `milestone`, `outcome`. Dispatched agents copy the example and omit the other 11 frontmatter fields; `phase-transition.sh` then returns empty derivation.

**Site**: top-of-file docstring usage block in `scripts/knowledge/write-summary.sh`.

**Patch**: expand task-mode usage example to show all 15 fields. Mirror the milestone-mode example shape (which appears to be more complete — verify).

---

**Item 9 — planner confabulates "authored N verifier scripts"**

Planner reports list deliverables it claims to have authored when the artifacts are correctly scheduled as executor-task deliverables. Frame as misleading reporting, not actual confabulation.

**Site**: `commands/plan-phase.md` "Reporting back" guidance section.

**Patch**: update guidance to distinguish "planner authored" vs "scheduled for executor" — frame the planner's required reporting as "list deliverables the plan schedules, regardless of authoring agent."

---

**Item 10 — plan-time SQL column drift / mock-only verification false-pass**

Layer-1 fix: `commands/plan-phase.md` verification-authoring rubric must require, when a task introduces new SQL reads, schema migrations, or DB-bound integration code, either (a) a real-DB column-existence verifier, or (b) an explicit `## Notes` "real-app smoke test pending" callout. Mock-only DB integration verification is a known false-pass shape.

(Layer-2 — `boundary_translation` decision-packet — folds into M034 and is out of scope for this sweep per CLAUDE.md.)

**Site**: `commands/plan-phase.md` verification-authoring rubric section.

---

**Item 11 — `run-probe.sh` is not a generic invocation harness**

Specify in `commands/plan-phase.md` Verification-authoring rubric: "for repo-resident verifiers under `scripts/verify/<...>.sh`, invoke directly via `bash scripts/verify/<path>` — `run-probe.sh` is reserved for staged throwaway probes inside `/tmp`/`/var/folders`/`<repo>/tmp/`."

**Site**: `commands/plan-phase.md` Verification-authoring rubric (same section as item 10).

---

**Item 12 — AD-19 helper-function carve-out is undocumented**

Capture in `references/RUNTIME-ASSUMPTIONS.md` under a new "Shape-guard carve-outs" section (or a new `references/SHAPE-GUARD-CARVEOUTS.md` if RUNTIME-ASSUMPTIONS feels cluttered — pick whichever has clearer ownership). Document: bash function bodies are NOT scanned by the M021/M028 inline-shape classifier; multi-step compounds (shasum + awk-extract; mktemp + trap; assert_reject helpers) can be hoisted into top-of-script function bodies. Cross-reference from `commands/plan-phase.md` Steps-section authoring guidance.

**Site**: new section in `references/RUNTIME-ASSUMPTIONS.md` (preferred) + cross-reference in `commands/plan-phase.md`.

---

**Item 13 — CLAUDE.md commit-message-via-HEREDOC guidance is in tension**

System-prompt-staged guidance recommends `git commit -m "$(cat <<'EOF' ... EOF)"` for multi-line messages, but the active [M021](../milestones/M021/index.md) PreToolUse Bash shape-guard rejects this shape under AP-008.

**Site**: `CLAUDE.md` commit-message guidance section (search for `HEREDOC` / `cat <<`).

**Patch**: update CLAUDE.md to recommend `git commit -F <message-file>` as the primary form for multi-line messages; document inline-HEREDOC as guarded against. Note: this is *project* CLAUDE.md, not the system prompt itself — the system prompt change is upstream Anthropic. Project-level CLAUDE.md amendment is what this sweep can do.

---

**Item 16 — Plan-time prerequisite-existence verification gap**

`commands/plan-phase.md` planner-side rubric: when Prerequisites name specific files via paths, the planner MUST run `[ -f <path> ]` against each one and FAIL the plan-authoring step on any miss. Surfaces gaps at plan-authoring time, not execution time. Surfaced in M028/P02/T03 (`before-commit.sh` claimed to exist but did not).

**Site**: `commands/plan-phase.md` Prerequisites-authoring rubric.

---

**Item 17 — Plan-time classifier-shape pre-validation discipline missing**

`commands/plan-phase.md` Verification-authoring rubric: when a task introduces lines subject to the active M021/M028 shape guard, OR when a verifier's contract depends on a specific classifier verdict for a specific input, the planner MUST run the proposed line/input through `scripts/verify/lib/shape-classifier.sh::classify_command` at plan-authoring time and record the verdict in plan prose. Surfaced repeatedly in M028 (T01 reshaped resolution block; T05 swapped test command; P03 verifiers used pinned-INPUT alignment).

**Site**: `commands/plan-phase.md` Verification-authoring rubric (same section as items 10 + 11).

---

**Item 18 — Plan-time verifier-availability cross-check missing**

`commands/plan-phase.md` Verification-authoring rubric: every `## Verification` command MUST resolve to an existing-on-disk script at plan-authoring time. If a verifier doesn't exist yet, plan must either (a) schedule its authorship inside *this* task's `## Steps`, or (b) use a stub-tolerant inline shape-check. Cross-task verifier dependency rejected. Symmetric to item 16 on the verification side. Surfaced in M028/P03 (T01-T04 plans referenced T05-deliverable verifiers).

**Site**: `commands/plan-phase.md` Verification-authoring rubric (same section).

---

**Item 19 — Planner template emits `scripts/verify/...` for project-owned phase verifiers**

`templates/task-plan.md:40`, `templates/phase-plan.md:27,30`, `commands/plan-phase.md:120,134` instruct the planner to emit project-owned per-phase verifiers under `scripts/verify/<phase>-<task>-<name>.sh`. In any downstream project, `scripts/` is a bulk-staged framework dir (gitignored to avoid duplicating 1,157 framework files). Result: project-owned verifiers land gitignored AND vulnerable to silent clobber on next `install-claude-code.sh` run.

**Sites**:
- `templates/task-plan.md:40`
- `templates/phase-plan.md:27,30`
- `commands/plan-phase.md:120,134`

**Patch**: change planner-template default to `tools/verify/<phase>-<task>-<name>.sh` for **project-owned** verifiers (filename embeds phase/task/milestone slug). Framework-owned verifiers (stable names: `check-must-haves.sh`, `check-scope.sh`, `run-suite.sh`, `spec-shape-lint.sh`, `validate-*`, `guards/*`) keep `scripts/verify/...` paths because they ship in the install bundle. Document the discriminator in `commands/plan-phase.md`: any verifier whose filename embeds a phase/task/milestone slug is project-owned.

**Self-dogfood note**: this repo's own `scripts/verify/m0XX-*.sh` per-phase verifiers stay in place (no install-into-itself collision). Only NEW verifiers emit to `tools/verify/`. Existing in-repo `scripts/verify/m028/*.sh` etc. are not relocated.

---

**Verification for doc-only group**: smoke test — write a synthetic plan that follows the new rubrics; assert it does not violate any of the documented constraints when piped through any existing plan-shape lint (`scripts/diagnostics/check-plans.sh` or similar). For Item 19, verify by reading the planner output of a fresh `orchestrator:plan-phase` dispatch (deferred to M030/P01 dogfood — note this in the PR description as the validation surface).

**Commits** (split into two for reviewability):
1. `paper-cut(planner): document plan-time discipline (prereq-existence, classifier-shape, verifier-availability, run-probe scope, real-DB SQL verification)` — items 10, 11, 16, 17, 18
2. `paper-cut(docs): planner reporting + AD-19 carve-out + commit -F + write-summary task example + tools/verify/ for project-owned verifiers` — items 5, 9, 12, 13, 19

---

## Suggested commit order

1. Group 1 (slug-suffix readers) — load-bearing for any future Tier C run with slug-bearing plans; ship first
2. Group 2 (read-roadmap Depends:) — small, self-contained, doesn't depend on others
3. Group 3 (conversus stub guard) — defensive, doesn't depend on others
4. Group 4 (check-must-haves key-link) — lifts verification quality for downstream projects
5. Group 5 (auto-loop bare-backtick parser) — verification UX
6. Group 6 (settings-merge uninstall) — symmetric with M028/P02 repair work
7. Group 7 (stale m025/m013 verifiers) — restores test-suite green
8. Group 8 (docs commit 1 — planner discipline) — five planner-rubric items folded
9. Group 8 (docs commit 2 — misc docs) — five misc-doc items folded

Each commit independently green via `tests/run-suite.sh`. Run the full suite after each commit, not just at the end.

## PR description outline

```
# paper-cut sweep / pre-M030

Bundles 18 of 18 CLAUDE.md hotfix-queue items (the 19th was already
fixed in commit 73effdc and is documentation-only in CLAUDE.md).

## Bug fixes
- bilateral-tolerance for slug-suffix summary lookup (3 readers)
- Depends: token filter to ^P\d+$
- conversus parse_verdict provider-error stub guard
- check-must-haves PHASE_DIR fallback + .ts/.tsx extension stripping
- auto-loop --step=V bare-backtick bullet support
- settings-merge uninstall wrapper-OR-leaf detection
- m025/m013 stale verifiers updated to M028 absolute-path contract

## Doc / rubric updates
- plan-phase.md: prereq-existence + classifier-shape + verifier-availability
  pre-validation + run-probe.sh scope + real-DB SQL verification
- plan-phase.md: planner reporting (authored vs scheduled)
- references/RUNTIME-ASSUMPTIONS.md: AD-19 helper-function carve-out
- CLAUDE.md: commit -F over inline-HEREDOC
- write-summary.sh: full 15-field task-mode usage example
- planner templates: tools/verify/ default for project-owned verifiers

## Test coverage
- new test-summary-read-asymmetry.sh
- new test-settings-merge-uninstall.sh
- extended test-auto-loop-verify-extraction.sh (Test 4: bare backticks)
- extended test-check-must-haves.sh (PHASE_DIR + .ts cases)
- new test-read-roadmap.sh fixture (Depends: with non-P tokens)
- conversus stub fixture under tests/fixtures/conversus-provider-error/

## Out of scope (intentionally deferred)
- M032 spec-side invariant for staged-dirs collision (encoded when M032 plans)
- M034 boundary_translation decision-packet (Layer-2 of SQL drift fix)
- System-prompt commit-message HEREDOC guidance (upstream Anthropic, not us)
```

## What the fresh session does

1. Read this brief ([`.orchestrator/proposals/papercut-sweep-pre-M030.md`](../proposals/papercut-sweep-pre-M030.md)).
2. Read CLAUDE.md hotfix section to confirm context.
3. Create branch `papercut-sweep/pre-M030` from `main`.
4. Execute groups 1-8 in order, one commit per group (group 8 splits into 2 commits).
5. Run `tests/run-suite.sh` after each commit.
6. Open PR with the description above.
7. Update CLAUDE.md "Near-term D021-style hotfixes" section: remove the items shipped, leave the M032 spec-side invariant note + M034 boundary_translation note as deferred. (Or remove the entire section if all items shipped — verify nothing is left.)

**Estimated effort**: 4-6 hours focused execution. Most items have the patch shape spelled out; the bulk of the time is verification fixtures + suite runs.

**No new context needed** beyond this brief + CLAUDE.md + the patch sites already verified above.
