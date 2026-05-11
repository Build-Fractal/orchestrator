# Paper-Cut Sweep PR Brief — Post-M035

**Created**: 2026-05-09
**Source**: `.orchestrator/milestones/M035/M035-SUMMARY.md` § "Caveats and follow-ups" (M035 closed 2026-05-10)
**Goal**: Bundle the 7 deferred paper-cuts surfaced during M035 + close residue from the M035 P01.5 rename sweep, before the launch event (M035 v* tag-push).
**Posture**: Standalone branch + PR — not a milestone, not a phase. No `orchestrator:plan-phase` ceremony. Direct execution against this brief.
**Branch**: `papercut-sweep-post-M035`

## Why a single PR

All 7 paper-cuts are independent narrowly-scoped fixes that have already been root-caused with patch shape documented inline in `M035-SUMMARY.md` § "Caveats and follow-ups". Bundling avoids 7 micro-PRs of churn while keeping each commit logically isolated for `git log` readability. The rename audit (Workstream 2) lands as one additional commit at the end of the sweep so the launch event runs against a single audited, single-renamed surface.

## Out of scope (do NOT include)

- **MOS-3 / MOS-4 / MOS-5** — Live-channel evidence is deferred to first-release time per spec; exercised on the first published `v*` tag through `release.yml`. Not paper-cut scope; not pre-launch scope.
- **`commands/update.md ## Update sources` H2 expansion broader than per-channel plan directives** — captured in the summary as an executing-agent judgment call; verifier passes against the broader shape; no fix needed.
- **Pre-T06 reconciliation history** — narrative-only commentary in the summary; nothing to sweep.

## Patch verification rule

For each item: run the existing reproduction or write a smoke test that fails pre-patch and passes post-patch, before committing. Run `tests/m035-acceptance/run-acceptance-battery.sh` after each commit to confirm no regression.

---

## PC-1 — `scripts/util/run-probe.sh` doesn't export `REPO_ROOT`

**Diagnosis**: Every staged probe in M035 (P02 T01/T02/T05, P05 T03) needed a defensive `REPO_ROOT="${REPO_ROOT:-...}"` fallback because `run-probe.sh` computes but doesn't export `REPO_ROOT`. The contract is implicit; staged probes hit it repeatedly.

**Site**: `scripts/util/run-probe.sh:42` (the `REPO_ROOT="$(cd ...)"` assignment block).

**Patch shape**: Add `export REPO_ROOT` immediately after the assignment. Update the docstring header (lines 1-22) to document the export contract: "Exports REPO_ROOT to the child probe's environment."

**Verification**: Author `tools/verify/papercut-run-probe-repo-root.sh` asserting:
1. `grep -q '^export REPO_ROOT' scripts/util/run-probe.sh` (export line present).
2. `grep -q 'Exports REPO_ROOT' scripts/util/run-probe.sh` (docstring updated).
3. End-to-end test: stage a probe under `/tmp/` that asserts `[ -n "${REPO_ROOT:-}" ]`; invoke via `run-probe.sh`; assert exit 0.

**Commit**: `paper-cut(probe): export REPO_ROOT in run-probe.sh + docstring update`

---

## PC-2 — Anchor-shape vs heading-shape divergence in DECISIONS.md

**Diagnosis**: `D-RN-1..D-RN-7` rows use `### D-RN-N — title { #dr-code-NNN }` anchor-shape (markdown TOC-extractor friendly). `D004..D014` use literal `### D### — title` heading-shape (no anchor). `scripts/knowledge/append-decision.sh:61` parses table-row shape (`^\|[[:space:]]*D[0-9]+`) — which **NEITHER** of the new shapes matches. The script silently misses every recent decision and would assign `D001` as the next ID if invoked today.

**Sites** (verified 2026-05-09):
- `scripts/knowledge/append-decision.sh:60-67` — table-row scanner (the highest-id-finder).

**Patch shape** (~20 lines): extend the highest-id scanner to recognize three shapes simultaneously:
1. Existing table-row shape: `^\|[[:space:]]*D[0-9]+`.
2. New heading-shape: `^### D[0-9]+[[:space:]]+—`.
3. New anchor-shape: `^### D[0-9]+[[:space:]]+—.*\{ #dr-code-[0-9]+ \}`.

The `D-RN-N` anchor-cohort is intentionally separate from the numeric `D###` sequence — `append-decision.sh` should NOT treat `D-RN-N` as part of the numeric sequence (it would clash with `D029..D035` which the cohort already shadows via `dr-code-029..dr-code-035`).

**Patch verification rule** (per pre-M030 sweep): write a test that creates a synthetic DECISIONS.md containing only the new heading-shape with highest D014; assert append-decision.sh assigns D015 next. Repeat with anchor-shape only; assert same. Repeat with mixed table + heading; assert correct max.

**Verification**: Author `tools/verify/papercut-decisions-dual-shape.sh`:
1. Stage `/tmp/test-decisions-heading-only.md` containing `### D014 — foo`; invoke `append-decision.sh`; assert next ID is `D015`.
2. Stage `/tmp/test-decisions-anchor-only.md` containing `### D-RN-3 — foo { #dr-code-031 }`; invoke; assert it's NOT counted as part of the D### sequence.
3. Stage `/tmp/test-decisions-mixed.md` containing all three shapes; assert correct max.

**Commit**: `paper-cut(decisions): dual-shape support in append-decision.sh highest-id scanner`

---

## PC-3 — BSD-sed bracket-class regex in `_byte-equivalence-hash.sh`

**Diagnosis**: `tests/m035-acceptance/_byte-equivalence-hash.sh:29` uses `sed -E 's/[][.^$*+?(){}|\\]/\\&/g'` to escape regex metachars in `EXCLUSION_LIST` paths. BSD sed's bracket-class parser silently no-ops on the leading `]` (which BSD interprets as the close of an empty bracket class). The `EXCLUSION_LIST` mechanism is therefore a no-op locally on macOS.

Tests pass today because all three channel arms hash flat tarball-extracts identically — the exclusion list is "applied" to nothing on each side and they still match — but this masks a real cross-channel divergence that would surface on Linux CI where GNU sed honors the regex correctly. **Pre-launch concern**: `release.yml` runs on `ubuntu-latest`; CI exclusion behavior diverges from local behavior. Risk: a real per-channel divergence introduced post-launch that local dogfood-runs don't catch.

**Site**: `tests/m035-acceptance/_byte-equivalence-hash.sh:29`.

**Patch shape**: Replace the `sed -E` regex-escape pass with a BSD-and-GNU-portable form. Two options:
- **Option A (preferred)**: Use a per-character escape via `awk` (BSD/GNU compatible) or a fixed-string approach via `printf '%s\n'` + `grep -F` for literal-substring exclusion (drops regex-metachar support but is simpler and matches what the EXCLUSION_LIST is actually used for — file paths).
- **Option B**: Keep sed but use POSIX character classes + explicit alternation. Brittle on the `]` corner.

Recommend Option A: rewrite to `grep -vF` over each EXCLUSION_LIST line as a literal substring filter. The exclusion list contains file paths only; literal-substring matching is the correct semantics.

**Verification**: Author `tools/verify/papercut-byte-equivalence-hash-bsd.sh` AND a new `tests/m035-acceptance/exclusion-list-regression.sh`:
1. Stage two synthetic STAGED dirs with one excluded path each.
2. Invoke `_byte-equivalence-hash.sh` with `EXCLUSION_LIST=<excluded-path>`.
3. Assert hash output excludes the path on both BSD (macOS local) and GNU (skip-on-Linux via `uname -s`).
4. Assert the same hash is produced when the excluded path differs between dirs.

**Commit**: `paper-cut(byte-equivalence): BSD-portable EXCLUSION_LIST via grep -vF`

---

## PC-4 — M035 P00 phase-suite SKIP root cause: missing executable bit

**Diagnosis (revised 2026-05-09 after baseline battery run)**: The file `tools/verify/m035-p00-phase-suite.sh` exists at the expected path, but the battery's `run_one()` helper (line 47) uses `[ ! -x "$cmd" ]` as its existence gate. **Three** M035 P00 verifiers are missing the executable bit (mode `0644` instead of `0755`):

- `tools/verify/m035-p00-phase-suite.sh`
- `tools/verify/m035-p00-npm-collision-evidence.sh`
- `tools/verify/m035-p00-wiki-deploy-stage.sh`

The other three P00 verifiers (`bash32-collision`, `managed-gitignore`, `wiki-stubs-fresh`) are correctly `0755`. Baseline battery output: `SKIP: P00 phase-suite (SC-5/SC-6) — verifier not found at tools/verify/m035-p00-phase-suite.sh` plus `BATTERY: pass=174 fail=0 skip=2` (the second skip is the P05 cosign-live gate, expected).

**Site**: file modes only — no source change.

**Patch shape**: `chmod +x` on the three files. Stage with `git update-index --chmod=+x` so the mode change lands in the commit (otherwise local-only).

**Verification**: Author `tools/verify/papercut-m035-p00-exec-bit.sh`:
1. Assert all six `tools/verify/m035-p00-*.sh` files are executable via `[ -x ]`.
2. Re-run `tests/m035-acceptance/run-acceptance-battery.sh`; assert SKIP for P00 disappears (skip count drops by 1; pass count rises by P00's contribution).

**Commit**: `paper-cut(verify): chmod +x on three M035 P00 verifiers (battery SKIP fix)`

---

## PC-5 — `wiki-init.sh --deploy` bundle-staging (M032 SC-5 carryover)

**Diagnosis**: M032 SC-5 fixture-completeness skip carried through M035. `wiki-init.sh --deploy` step 2 expects `wiki-deploy.sh` in `$PROJECT_DIR` but fresh-project fixtures don't ship it. M032's Deferred-Validation Acknowledgment recommended fix-during-M035 closure but it slipped.

**Site**: `scripts/lifecycle/wiki-init.sh` — locate the `--deploy` arm step 2 (the `wiki-deploy.sh` invocation).

**Patch shape**: Before invoking `wiki-deploy.sh`, check if it exists in `$PROJECT_DIR/scripts/lifecycle/wiki-deploy.sh`. If not, copy from `$REPO_ROOT/scripts/lifecycle/wiki-deploy.sh` (bundle-stage). Emit a stderr advisory: `"INFO: bundle-staging wiki-deploy.sh from $REPO_ROOT (consumer project lacks it)"`. The bundle-stage path mirrors how `init-project.sh` already stages other lifecycle scripts.

**Verification**:
1. Re-run `tests/m032-acceptance/run-acceptance-battery.sh`; assert SC-5 flips from SKIP → PASS.
2. Update `.orchestrator/milestones/M032/M032-ACCEPTANCE-EVIDENCE.md` Deferred-Validation Acknowledgment block: replace SKIP with PASS evidence + cross-reference this paper-cut commit SHA.

**Commit**: `paper-cut(wiki-init): bundle-stage wiki-deploy.sh from REPO_ROOT (M032 SC-5 fix)`

### PC-5 status — DEFERRED + new finding (2026-05-10 papercut-sweep)

The PM session's handoff identified the runtime fix as *already shipped*
under M035 P00 T04 (commit `1aba20e7`,
`scripts/lifecycle/wiki-init.sh:1146-1159`), so PC-5 was reduced to test +
evidence reconciliation. A live SC-5 run on `papercut-sweep-post-M035`
showed the closure is **partial**: M035 P00 T04 stages `wiki-deploy.sh`
but the deploy chain ALSO requires:

- `scripts/wiki/wiki-scan-sources.sh` (invoked by `wiki-init.sh` pre-deploy)
- `scripts/diagnostics/wiki-giscus-config-check.sh` (invoked by `wiki-deploy.sh` pre-deploy gate)

…and probably any other helpers transitively invoked from the four
pre-deploy gates inside `wiki-deploy.sh` (a full chain audit was not
performed). The current `--deploy` chain therefore still hits `rc=1`
on the giscus-config-check step before reaching the actual mkdocs
gh-deploy.

**PC-5 scope outgrew paper-cut**: full closure requires either (a)
extending the M035 P00 T04 staging block to bundle-stage the entire
deploy helper chain (deeper change to `wiki-init.sh`, plus a chain
audit), or (b) bootstrapping the test fixture post-install so
`scripts/` is materially present before SC-5 runs. Either path is a
real follow-on milestone-grain fix, not a paper-cut.

**What landed on this branch**:

- PC-8 (golden refresh) only — `tools/verify/fixtures/m032-pre-m032-golden.txt` updated to track post-M033/M035/m040 churn so M032 SC-1 stays green. M032 battery without PC-5 attempt still reports `pass=10 skip=1 fail=0` (unchanged from M032 close).

**What was reverted**:

- Test patch retiring the SKIP_REASON precondition (restored to HEAD).
- Evidence doc `M032-ACCEPTANCE-EVIDENCE.md` reconciliation (restored to HEAD; the doc's existing "Deferred-Validation Acknowledgment" remains accurate).

**Two co-discovered side issues** (each a separate paper-cut candidate, not addressed here):

1. The SC-5 test's `cleanup()` trap calls `gh repo delete --yes` and silently absorbs the 403 returned when the gh token lacks `delete_repo` scope. The throwaway repo is left on GitHub. The trap should distinguish "delete succeeded" from "delete failed because of missing scope" and emit a loud `say_fail` for the latter so the operator can recover before next run.
2. The SC-5 test's fixture-remote restore line (`git -C "$FIXTURE" remote set-url origin ...`) lives AFTER the cleanup() invocation and downstream invariants. When `wiki-init.sh --deploy` exits non-zero (which it currently does), the script returns at line 99 and the fixture remote is left pointing at the throwaway repo. Restore should be wrapped into the EXIT trap, not the linear flow.

Operator follow-up: re-run gh auth refresh with `delete_repo` scope (`gh auth refresh -h github.com -s delete_repo`) before any future SC-5 attempt.

---

## PC-6 — Rollback test detaches host-repo HEAD

**Diagnosis**: `tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh` invokes the rollback driver against the host repo. `scripts/lifecycle/run-update.sh:~172` runs `git checkout <prior-sha>` which is a content no-op when prior-SHA equals current-HEAD but **leaves HEAD detached**. Cost 2 manual recoveries during T06 alone; will keep biting every battery run.

**Site**: `tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh` (test-side recovery).

**Patch shape (Option A — preferred per WS plan)**: At test start, capture `_orig_branch="$(git rev-parse --abbrev-ref HEAD)"` and `_orig_sha="$(git rev-parse HEAD)"`. Install a `trap` on EXIT that:
1. Detects detached HEAD via `git rev-parse --abbrev-ref HEAD` returning `HEAD`.
2. If detached, runs `git checkout "$_orig_branch"`.
3. If post-checkout SHA is behind `_orig_sha` (shouldn't happen with content-no-op but defense-in-depth), runs `git merge --ff-only "$_orig_sha"`.
4. Logs the recovery to stderr so future operators see the trap fired.

**Why not Option B (driver fix)**: Touches the rollback driver's contract. The driver is correct in the general case (the operator who runs `--rollback` from copy-mode WANTS HEAD to move). The test is the wrong consumer; fix at the consumer.

**Why not Option C (clone fixture)**: Larger surface, more test infrastructure, cross-channel byte-equivalence guarantees become harder to defend.

**Verification**: Author `tools/verify/papercut-rollback-no-detach.sh`:
1. Capture pre-test branch.
2. Invoke `m035-p05-rollback-byte-equivalence.sh`.
3. Assert post-test `git rev-parse --abbrev-ref HEAD` returns the captured branch (not `HEAD`).

**Commit**: `paper-cut(rollback-test): trap-EXIT recovery for detached HEAD (Option A)`

---

## PC-7 — yaml-merge list-element preservation gap

**Diagnosis**: M037 round-5 surfaced this and explicitly deferred. When a managed top-level key has a sub-key whose value is a YAML list, `yaml-merge` preserves the target's list byte-identically (operator-wins-byte-identical at the sub-key level). Dropping a list element from the framework default does NOT propagate to existing projects.

**Site**: `scripts/lib/yaml-merge.sh` — the merge-recursion site that handles list-valued sub-keys.

**Patch shape (Option B — preferred per WS plan)**: Add a `--replace-list-keys=key1,key2` flag for opt-in list replacement. Callers (`wiki-init.sh`, etc.) pass the flag for keys they want to manage. Default behavior unchanged (operator-wins for unmanaged list keys; back-compat preserved).

**Why not Option A (always-replace for managed keys)**: Risk of stomping operator customizations in lists they thought were operator-owned.

**Regression sweep** (load-bearing — touches a primitive):
1. `git grep -ln 'yaml-merge.sh' scripts/ commands/ packaging/` — every call site.
2. For each call site, exercise the existing test fixtures + run with the new flag absent (back-compat); assert byte-identical merge output.
3. For at least one call site (recommend `wiki-init.sh` for `mkdocs.yml` `nav.tabs`), exercise the new flag positively; assert framework-list propagates.

**Verification**: Author `tools/verify/papercut-yaml-merge-list-replace.sh`:
1. Stage target `/tmp/test-yaml-target.yml` with managed top-level key + list sub-key containing operator items.
2. Stage source `/tmp/test-yaml-source.yml` with the same managed key + a different list.
3. Invoke `yaml-merge.sh` without `--replace-list-keys`; assert target list preserved (back-compat).
4. Invoke `yaml-merge.sh` with `--replace-list-keys=managed_key`; assert source list replaces target.

Plus regression sweep over every existing `yaml-merge.sh` call site with the new code path back-compat-only.

**Commit**: `paper-cut(yaml-merge): --replace-list-keys opt-in flag for managed-list keys`

---

## Rename audit verdict matrix (Workstream 2)

Audit driver: `/tmp/ws2-audit-driver.sh` (11 sections; 9 git-grep audits per the
original briefing + GH-side metadata + wiki `site_url` cross-check). All
matches classified into the 5 buckets below. `wiki/.staged/*` paths are
transitive (include-markdown copies of `.orchestrator/...` originals) and
fold under the bucket of their source file; they are not re-listed.

### MISSED-RENAME (must fix)

| File | Line(s) | Match shape | Why MISSED-RENAME |
|------|---------|-------------|-------------------|
| `scripts/lifecycle/wiki-init.sh` | 172-173 | Comment example URLs `Build-Fractal/spec-kit-orchestrator(.git)` for the remote-URL parser | Comment-as-documentation; the parser handles old + new shapes via GH redirect, but the example should reflect the new name. |
| `scripts/lifecycle/run-update.sh` | 568 | Live error: "does not look like a spec-kit-orchestrator source tree" | User-facing error message; should match the renamed source tree. |
| `scripts/dispatch/adapters/runtime/codex.sh` | 142 | Comment: "spec-kit orchestrator lifecycle hooks" | Descriptor text; should be "orchestrator lifecycle hooks". |
| `scripts/migrate/migrate.sh` | 47 | Usage text: "the spec-kit-orchestrator intermediate format" | User-facing CLI help; should be "the orchestrator intermediate format". |
| `tests/installer-acceptance/m035-collision-exit-status.sh` | 71 | Fixture manifest: `name: "spec-kit-orchestrator"` | The bundle manifest at `packaging/bundle/manifest.yml:23` now reads `name: "orchestrator"`; fixture should mirror. |
| `tests/m032-acceptance/p02-wiki-init-default-scope.sh` | 57, 59 | Defensive grep: assert orchestrator-identity (`spec-kit-orchestrator`) does NOT leak into consumer mkdocs.yml | Orchestrator's own name is now `orchestrator`; the leak-check should grep for the new name. |
| `tools/verify/m032-p02-mkdocs-templating-and-self-application.sh` | 10-11, 58, 59, 61, 65, 66, 71-73 (multiple) | Self-application verifier: asserts mkdocs.yml resolves to `site_name: "spec-kit-orchestrator"`, `site_url: "https://build-fractal.github.io/spec-kit-orchestrator/"`, `repo_url: "https://github.com/Build-Fractal/spec-kit-orchestrator"` | After rename, mkdocs.yml resolves to the new name; verifier expectations must match. |
| `specs/040-wiki-readability-decorator/spec.md` | 182 | Spec body: `https://raw.githubusercontent.com/<org>/spec-kit-orchestrator/<tag>/...` | Live spec content; should reflect the new repo name. |

### EXTERNAL-URL (fix; GH redirect makes them work either way, but freshness is preferred)

| File | Line(s) | Match shape | Notes |
|------|---------|-------------|-------|
| `scripts/verify/m014-p03-fetch.sh` | 73 | Fixture write: `"comment_url":"https://github.com/Build-Fractal/spec-kit-orchestrator/issues/1#issuecomment-1"` | Fixture data; GH redirect handles old form, but inline-fixture should reflect current repo. |
| `tests/fixtures/m014-p03/sample-inbox.jsonl` | 1-4 | Four `Build-Fractal/spec-kit-orchestrator` issue/discussion URLs | Same rationale; freshness only. |

### LEGITIMATE-HISTORICAL (do not touch)

Captures audit-trail content frozen at a point in time. Touching these would
falsify history.

- `.orchestrator/milestones/M005/phases/P07/tasks/T05-PLAN.md` — M005 archive (P07 plan body).
- `.orchestrator/milestones/M008/M008-SUMMARY.md` + `.orchestrator/milestones/M008/archive/P06/T02-PAYLOAD.md` + `.orchestrator/milestones/M008/archive/P06/T02-PLAN.md` + `.orchestrator/milestones/M008/archive/P07/P07-PLAN.md` — M008 archive.
- `.orchestrator/milestones/M015/phases/P04/evidence/doctor-report.txt` — captured doctor evidence.
- `.orchestrator/scratch/m018-p00-fixture-test.sh` + `.orchestrator/scratch/m018-p02-t03-{disabled,e2e,smoke}.sh` — one-off debug scripts (operator-only, baked-in absolute path to old project dir).
- `.orchestrator/milestones/M035/M035-CONTEXT.md` + `.orchestrator/milestones/M035/phases/P01.5/{P01.5-PLAN.md,P01.5-SUMMARY.md,operator-runbook.md,c4-classification.txt,phase-body.txt,tasks/T04-c1-lowercase-hyphenated-PLAN.md,tasks/T07-SUMMARY.md,tasks/T08-acceptance-and-runbook-PLAN.md}` — M035 P01.5 audit trail (the rename phase itself).
- `.orchestrator/proposals/M035-packaging-distribution.md` + `.orchestrator/proposals/README.md` + `specs/039-packaging-distribution/spec.md` — packaging proposal/spec referencing the OLD npm scope `@spec-kit/orchestrator` as the predecessor.
- `CHANGELOG.md` — intentional historical preservation per audit 5 in the briefing.
- `packaging/bundle/D-RN-1-evidence.txt` — D-RN evidence trail.
- `tests/m035-acceptance/fixtures/install-meta-pre-m035.txt` + `tests/m035-acceptance/fixtures/install-meta-with-sha.txt` — fixtures named "pre-m035" that intentionally encode the pre-rename source_root path.
- `tools/verify/m035-p015-{c1-sweep,c2-c3-prose,c4-classification,c5-cohort-finish,operator-paths,sc7b}.sh` — the C1 sweep verifiers themselves; they intentionally search FOR the legacy name to enforce its absence elsewhere.

### RENAME-INSTRUCTION (do not touch — these document the rename)

- `references/RENAME-PLAN.md` — the rename plan; its body is *about* the legacy name.
- `.orchestrator/proposals/papercut-sweep-post-M035.md` (this file) + `.orchestrator/proposals/papercut-sweep-post-M035-HANDOFF.md` — sweep proposal + handoff doc; quotes the audit-grep examples literally so the legacy name appears in code blocks.

### EXTERNAL (GH-side, handled by WS3 rename)

- `.git/config` — `url = git@github.com:Build-Fractal/spec-kit-orchestrator.git` (audit 6). Updated by operator-side `git remote set-url` after `gh repo rename`. Defer to WS3.
- `gh repo view Build-Fractal/spec-kit-orchestrator` JSON metadata — `description`, `homepageUrl`. WS3 reconciles after rename. (Audit 10 returned a `gh` field-name error for `topics` — use `repositoryTopics` if needed; not load-bearing for the matrix.)

### OPERATOR-OWNED-WIP (must not touch)

- `templates/phase-plan.md` and `.orchestrator/direct-mode-execution-log.jsonl` were not surfaced by any audit grep (no legacy-name residue in them).

### No-finding sections

- Audit 8 (`.github/`) — only wiki transitive (post-exclusion: zero matches in actual `.github/` content).
- Audit 9 (`package.json`/`bin/`) — `git grep` reports `package-lock.json` not in working tree; `package.json` itself already uses `@build-fractal/orchestrator` and `homepage: "https://github.com/Build-Fractal/orchestrator"`; `bin/orchestrator` clean. Zero residue.

**Commit**: `rename audit: close residue from M035 P01.5 sweep`

---

## Acceptance & exit criteria

- M035 acceptance battery → `BATTERY: pass=N fail=0 skip=M` after every paper-cut commit.
- M032 acceptance battery → `BATTERY: pass=10 skip=0 fail=0` after PC-5 (SC-5 flipped to PASS).
- `validate-milestone.sh M035` → PASS unchanged.
- `validate-milestone.sh M032` → PASS unchanged.
- `git diff main...papercut-sweep-post-M035 -- templates/phase-plan.md .orchestrator/direct-mode-execution-log.jsonl` → empty (operator-owned WIP files untouched).
- Branch ends on `main` after merge (no detached HEAD; no leftover branch).

## Branch landing

Single PR titled `Paper-cut sweep post-M035 + rename audit`. Commits in the order above (proposal → PC-1 → PC-4 → PC-2 → PC-3 → PC-6 → PC-5 → PC-7 → rename-audit). Direct fast-forward merge to `main` since this branch only adds commits to a green main.
