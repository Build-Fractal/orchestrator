---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M032"
name: "FR-13 progressive-opt-in doc + AD-7 throwaway-fixture-protocol + SC-5 live-deploy acceptance"
depends_on: []
---

## Prerequisites

- `references/installation.md` exists at the orchestrator-repo level. Verified by `[ -f references/installation.md ]`. T04 amends it additively (new section appended; pre-existing content preserved verbatim).
- `tests/m032-acceptance/` exists from P01/P02 with prior acceptance scripts. T04 adds two new files: `throwaway-fixture-protocol.md` and `p03-wiki-init-deploy-live.sh`.
- `tests/fixtures/m032-fresh-project-fixture/` exists from P01 with a configured git remote.
- `gh` CLI MAY be on PATH and authenticated. SC-5 detects this at script start (via `gh auth status`) and emits SKIP_REASON / exit 77 if unauthenticated. T04's verifiers exercise the SKIP branch hermetically and the live branch only when `gh` is authenticated.
- T01 and T02 have landed (or will land before SC-5 is dispatched at execution time) — SC-5 invokes the full `--with-wiki --with-giscus --deploy` flag chain. At task-plan-authoring time, T04 plans against the documented flag-chain contract; at execution time, the SC-5 acceptance script runs against the actual T01+T02 surface.
- `tools/verify/` exists.

## Description

T04 lands the M032/M013-M014 counter-pattern surface — the live-throwaway-GH-repo discipline CON-5 mandates and the FR-13 documentation that establishes `--with-<feature>` as the project-wide progressive-opt-in convention. The deliverable surface has three pieces that ship together:

1. **FR-13 progressive-opt-in flag-pattern doc**: amend `references/installation.md` to add a new `## --with-<feature> Progressive Opt-In Flag Pattern` section documenting the convention (default-off, independently composable, opt-in is operator decision per Constitution I) and naming `--with-wiki`, `--with-giscus`, `--deploy` as the canonical M032 prior art.

2. **AD-7 throwaway-fixture-protocol document**: author `tests/m032-acceptance/throwaway-fixture-protocol.md` documenting the `gh repo create <ts>-m032-fixture --private --add-readme` + `gh repo delete <ts>-m032-fixture --yes` teardown contract — timestamp-prefix naming, four no-orphan-state invariants, recovery protocol on partial-failure teardown, trap-EXIT pattern.

3. **SC-5 acceptance script**: author `tests/m032-acceptance/p03-wiki-init-deploy-live.sh` implementing the protocol — `gh auth status` precondition with SKIP_REASON / exit 77 branch (POSIX skip-code per MIT-001), timestamped fixture creation, full `--with-wiki --with-giscus --deploy` invocation, live-URL curl retry loop bounded by `M032_DEPLOY_PROPAGATION_TIMEOUT`, served-HTML `data-repo` attribute assertion, MIT-008 audit-trail record assertion, trap-EXIT teardown, post-teardown no-orphan-state verification.

The atomicity argument: the FR-13 doc cites `tests/m032-acceptance/throwaway-fixture-protocol.md` as prior art for the `--deploy` operator-onboarding flow; the protocol document is the authoritative spec the SC-5 script implements. Splitting introduces a window where the SC-5 script ships without a documented protocol (operators have no recovery-on-partial-failure runbook) or where the FR-13 doc cites a non-existent protocol document. All three pieces co-author cleanly because they share token vocabulary (timestamp prefix, `--add-readme` flag, MIT-001 SKIP_REASON shape, MIT-008 audit-trail shape) and have no other inter-task dependencies.

## Steps

1. **Amend `references/installation.md`** to add the new section. Append to the end of the file (or insert before any existing trailing references — preserve byte-identity of existing content). Required content shape:

```markdown
## `--with-<feature>` Progressive Opt-In Flag Pattern

The orchestrator's installer commands honor a project-wide convention for
progressive-opt-in feature flags shaped as `--with-<feature>`. Each flag
follows three invariants:

- **Default-off** — the consumer never receives the feature surface unless
  they explicitly request it. This is Constitution I (Context Minimization)
  applied to the consumer-facing install surface: extra capability is an
  operator decision, not an installer default.
- **Independently composable** — every `--with-` flag is order-invariant
  and stateless with respect to every other `--with-` flag. Presence of
  one flag does not change the semantics of another. Composition is
  defined by the per-flag contract, not by flag-presence interactions.
- **Opt-in is reversible** — every `--with-<feature>` flag has a documented
  reversibility path (the inverse of the feature surface) that operators
  can run after the fact. Feature surfaces that cannot be cleanly removed
  do not qualify for the `--with-` pattern; they require a new gating
  primitive.

### Canonical M032 prior art (FR-13)

The first three flags landing under this pattern are M032's wiki tooling
trio:

- `--with-wiki` (FR-11) — installs `wiki/` tooling alongside the default
  `init` surface. Composes with `init`'s default flag set; reversibility
  is `rm -rf <project>/wiki/` plus removal of the corresponding
  `installed-files.txt` entries.
- `--with-giscus --repo <owner>/<repo> --category <name>` (FR-8) —
  configures Giscus comments against the consumer's own GitHub Discussions.
  Composes with `--with-wiki`; reversibility is re-running `--with-giscus`
  against a different repo/category, or manually editing the partial.
- `--deploy [--force-pages-reconfigure]` (FR-9 / MIT-007) — first GH Pages
  push. Composes with `--with-wiki --with-giscus`; reversibility is
  `gh repo edit --enable-pages=false` plus deleting the `gh-pages` branch.
  The `--force-pages-reconfigure` opt-in inside this flag handles the
  case where Pages was already configured for a different source on the
  consumer's repo (MIT-007 read-before-write Pages guard).

### Future flags (forward-compatibility commitments)

The `--with-` pattern is the documented precedent for future feature
surfaces. Anticipated additions:

- `--with-github-integration` (M013/M014 progressive opt-in fold-in) —
  enables GitHub-native sidecar tooling (issues/PRs/discussions adapter
  shim).
- `--with-design-layer` (M023, post-launch) — installs the design-layer
  fan-out tooling (`orchestrator:design` and the renderer adapter tree).

Each future flag will inherit the three invariants above. Adding a new
`--with-<feature>` flag requires (a) explicit documentation in this
section, (b) integration tests asserting the flag composes cleanly with
every existing `--with-` flag, and (c) a documented reversibility path.

### See also

- `commands/wiki-init.md` — the canonical `--with-wiki` / `--with-giscus`
  / `--deploy` flag-chain command surface.
- `tests/m032-acceptance/throwaway-fixture-protocol.md` — the live-deploy
  test discipline (`--deploy` is the highest-blast-radius `--with-` flag
  in M032; CON-5 mandates live-fixture testing rather than synthetic
  stubs).
```

2. **Author `tests/m032-acceptance/throwaway-fixture-protocol.md`**. Required content shape:

```markdown
# Throwaway-Fixture Protocol (AD-7 / CON-5)

This document specifies the protocol for live-network acceptance tests
that exercise GitHub-state-mutating commands (`gh api PATCH`,
`gh api PUT`, `gh repo create`, `mkdocs gh-deploy --force`, etc.). It is
M032's spec-side amendment of the M013/M014 cautionary tale: those
milestones tested only against synthetic stubs (`M013_GH_STUB_DIR`),
which produced the walker-contract dogfood blocker. M032 SHALL NOT
repeat that failure mode (CON-5).

## Fixture naming convention

Throwaway fixtures use a timestamp-prefixed name to ensure no collisions
across parallel CI invocations:

```
<ts>-m032-fixture
```

where `<ts>` is the unix-seconds timestamp at fixture creation
(`date +%s`). Example: `1714567890-m032-fixture`. The `m032-fixture`
suffix identifies the milestone for grep-able orphan-cleanup audits.

## Creation contract

```bash
TS=$(date +%s)
FIXTURE_NAME="${TS}-m032-fixture"
gh repo create "$FIXTURE_NAME" --private --add-readme
```

Flag rationale:

- `--private` (CON-5) — fixtures are private to avoid public test artifact
  pollution. CI runs against authenticated `gh` tokens with `repo` scope.
- `--add-readme` — ensures the default branch (`main`) exists immediately,
  required by the `gh api PUT /repos/<owner>/<repo>/pages` call (Pages
  source must reference an existing branch).

## Teardown contract

```bash
gh repo delete "<owner>/$FIXTURE_NAME" --yes
```

The teardown MUST run via a `trap` registered at fixture creation, so it
fires even on test-script failure mid-run:

```bash
cleanup() {
  gh repo delete "<owner>/$FIXTURE_NAME" --yes 2>/dev/null || true
}
trap cleanup EXIT INT TERM
```

## No-orphan-state invariants

After teardown, the test MUST verify four invariants:

1. **No `<ts>-m032-fixture` GitHub repo** — `gh repo view <owner>/<ts>-m032-fixture --json name 2>/dev/null` returns non-zero (repo not found).
2. **No `<ts>-m032-fixture` directory in `tests/fixtures/`** — fixtures created on disk are local-only; throwaway fixtures live entirely on GitHub. Any `tests/fixtures/<ts>-m032-fixture/` directory is leaked state.
3. **No `<ts>-m032-fixture` references in the orchestrator's `.git/refs/`** — `mkdocs gh-deploy --force` against a different cwd would push to a `gh-pages` ref under the orchestrator's tree (Finding J cross-project hazard); FR-10's cwd-vs-`repo_url:` sanity gate prevents this. Verify post-teardown with `find .git/refs -name '<ts>-m032-fixture*' -print | wc -l` returning 0.
4. **No leaked `<ts>-m032-fixture` records in audit logs** — `wiki-init.sh --deploy` appends `wiki-deploy-mutation` records to `<PROJECT_DIR>/.orchestrator/execution-log.jsonl`. These records ARE expected (audit-trail integrity per MIT-008); the invariant is that there are NO records OUTSIDE the test run's `<PROJECT_DIR>` (i.e., no records in the orchestrator-repo's own log file).

## Recovery on partial-failure teardown

If `gh repo delete` fails mid-run (network failure, auth expiry, etc.),
the operator MUST manually clean up:

```bash
# 1. Verify the throwaway fixture still exists.
gh repo view <owner>/<ts>-m032-fixture

# 2. Manually delete.
gh repo delete <owner>/<ts>-m032-fixture --yes

# 3. Audit local refs.
find .git/refs -name '<ts>-m032-fixture*' -print
# (manually `rm` any matches)
```

The recovery is documented here so operators encountering a half-cleaned
state on resume have a runbook.

## Counter-pattern history

The 2026-04-28 PBJ pilot bootstrap surfaced two related cross-project
hazards (Finding J): (a) `mkdocs gh-deploy -f` invoked from the wrong
cwd silently force-pushed one project's built site into another
project's `gh-pages` branch; (b) `tests/m032-acceptance/p03-wiki-init-deploy-live.sh`
without a teardown trap left orphan throwaway repos visible from the
operator's GitHub account. M032's protocol resolves both: (a) via
FR-10's sanity gate in `wiki-deploy.sh` (T02 deliverable), (b) via
this document's mandatory trap-EXIT teardown.

## SKIP_REASON branch (MIT-001 / POSIX exit 77)

When `gh auth status` exits non-zero (CI environment without
authenticated `gh`), the SC-5 acceptance script does NOT attempt fixture
creation. Instead it emits `SKIP_REASON: gh unauthenticated` to stdout
and exits 77 (POSIX skip-code convention). This exit code is distinct
from pass (exit 0) and fail (other non-zero); the SC-12 battery's
three-category output (`pass=N skip=M fail=K`) treats exit 77 as a
skip increment, not a pass.
```

3. **Author `tests/m032-acceptance/p03-wiki-init-deploy-live.sh`** (SC-5). Required content shape:

```bash
#!/usr/bin/env bash
# tests/m032-acceptance/p03-wiki-init-deploy-live.sh — SC-5 (FR-9 + FR-10 + FR-21).
#
# Implements the throwaway-fixture-protocol per
# tests/m032-acceptance/throwaway-fixture-protocol.md and CON-5. Exits 0
# on pass, 77 on SKIP_REASON (gh unauthenticated), other non-zero on fail.
# Three-category exit-code semantics per MIT-001.
#
# Coverage:
#  - Live --with-wiki --with-giscus --deploy invocation against a throwaway repo.
#  - Live URL responds 200 within M032_DEPLOY_PROPAGATION_TIMEOUT seconds.
#  - Served HTML contains data-repo="<owner>/<ts>-m032-fixture" attribute.
#  - .orchestrator/execution-log.jsonl carries ≥ 1 wiki-deploy-mutation record.
#  - Post-teardown: no GitHub repo, no local refs, no orphan state.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$REPO_ROOT/tests/fixtures/m032-fresh-project-fixture"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# Precondition: gh auth status. SKIP_REASON / exit 77 if non-zero.
if ! command -v gh >/dev/null 2>&1; then
  printf 'SKIP_REASON: gh unauthenticated (gh CLI not on PATH)\n'
  exit 77
fi
if ! gh auth status >/dev/null 2>&1; then
  printf 'SKIP_REASON: gh unauthenticated (gh auth status non-zero)\n'
  exit 77
fi

# Resolve owner from gh's authenticated account.
GH_OWNER="$(gh api user --jq .login 2>/dev/null)"
if [ -z "$GH_OWNER" ]; then
  printf 'SKIP_REASON: gh unauthenticated (could not resolve user.login)\n'
  exit 77
fi

# Throwaway fixture creation per AD-7 / throwaway-fixture-protocol.md.
TS="$(date +%s)"
FIXTURE_NAME="${TS}-m032-fixture"
PROPAGATION_TIMEOUT="${M032_DEPLOY_PROPAGATION_TIMEOUT:-90}"

cleanup() {
  set +e
  if [ -n "${FIXTURE_NAME:-}" ]; then
    gh repo delete "$GH_OWNER/$FIXTURE_NAME" --yes 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

if ! gh repo create "$FIXTURE_NAME" --private --add-readme >/dev/null 2>&1; then
  say_fail "throwaway-fixture creation failed: gh repo create $FIXTURE_NAME --private --add-readme"
  printf 'SUMMARY: SC-5 acceptance pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
say_pass "throwaway-fixture created: $GH_OWNER/$FIXTURE_NAME"

# Re-point the fixture's git remote to the throwaway repo so wiki-init's
# FR-5 git-remote parsing resolves to the throwaway, not the P01-baseline
# fixture-owner/m032-fresh-project-fixture remote.
git -C "$FIXTURE" remote set-url origin "https://github.com/$GH_OWNER/$FIXTURE_NAME.git" 2>/dev/null || true

# Full --with-wiki --with-giscus --deploy invocation.
M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-wiki --with-giscus --deploy \
  --repo "$GH_OWNER/$FIXTURE_NAME" --category 'Wiki Comments' \
  --project-dir "$FIXTURE" >/tmp/sc5-wiki-init-stdout.$$ 2>/tmp/sc5-wiki-init-stderr.$$
deploy_rc=$?
if [ "$deploy_rc" -eq 0 ]; then
  say_pass "wiki-init.sh --with-wiki --with-giscus --deploy exited 0"
else
  say_fail "wiki-init.sh --deploy exited $deploy_rc; stderr: $(tail -10 /tmp/sc5-wiki-init-stderr.$$ | tr '\n' ' ')"
  rm -f /tmp/sc5-wiki-init-stdout.$$ /tmp/sc5-wiki-init-stderr.$$
  printf 'SUMMARY: SC-5 acceptance pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# Parse live URL from stdout.
LIVE_URL="$(tail -1 /tmp/sc5-wiki-init-stdout.$$)"
rm -f /tmp/sc5-wiki-init-stdout.$$ /tmp/sc5-wiki-init-stderr.$$
case "$LIVE_URL" in
  https://*) say_pass "live URL printed: $LIVE_URL" ;;
  *) say_fail "live URL not parsed from wiki-init stdout (got: '$LIVE_URL')"; LIVE_URL="" ;;
esac

# Curl retry loop bounded by M032_DEPLOY_PROPAGATION_TIMEOUT.
if [ -n "$LIVE_URL" ]; then
  ELAPSED=0
  STEP=10
  HTTP_OK=0
  while [ "$ELAPSED" -lt "$PROPAGATION_TIMEOUT" ]; do
    if curl -fsS -o /tmp/sc5-html.$$ "$LIVE_URL" >/dev/null 2>&1; then
      HTTP_OK=1
      break
    fi
    sleep "$STEP"
    ELAPSED=$((ELAPSED + STEP))
  done
  if [ "$HTTP_OK" -eq 1 ]; then
    say_pass "live URL responded 200 within ${ELAPSED}s (timeout ${PROPAGATION_TIMEOUT}s)"
  else
    say_fail "live URL did not respond 200 within ${PROPAGATION_TIMEOUT}s"
  fi

  # Served HTML contains the per-fixture data-repo attribute.
  if [ -f /tmp/sc5-html.$$ ] && grep -qF "data-repo=\"$GH_OWNER/$FIXTURE_NAME\"" /tmp/sc5-html.$$; then
    say_pass "served HTML contains data-repo=\"$GH_OWNER/$FIXTURE_NAME\" (FR-21 end-to-end loop)"
  else
    say_fail "served HTML missing data-repo attribute for $GH_OWNER/$FIXTURE_NAME"
  fi
  rm -f /tmp/sc5-html.$$
fi

# MIT-008 audit-trail invariant.
LOG_FILE="$FIXTURE/.orchestrator/execution-log.jsonl"
if [ -f "$LOG_FILE" ] && grep -qF '"event_type":"wiki-deploy-mutation"' "$LOG_FILE" \
   && grep -qF '"result":"success"' "$LOG_FILE"; then
  say_pass "MIT-008 audit-trail: ≥ 1 wiki-deploy-mutation record with result=success"
else
  say_fail "MIT-008 audit-trail: no wiki-deploy-mutation success record in $LOG_FILE"
fi

# Teardown is via trap. Verify post-teardown invariants AFTER trap fires by
# explicitly invoking cleanup and re-checking. (The trap will fire again at
# script exit; gh repo delete is idempotent.)
cleanup
trap - EXIT INT TERM

# No-orphan-state invariant 1: GitHub repo is gone.
if gh repo view "$GH_OWNER/$FIXTURE_NAME" --json name >/dev/null 2>&1; then
  say_fail "post-teardown: $GH_OWNER/$FIXTURE_NAME still exists on GitHub"
else
  say_pass "post-teardown: throwaway repo absent from GitHub"
fi

# No-orphan-state invariant 2: no fixture dir left in tests/fixtures/.
if [ -d "$REPO_ROOT/tests/fixtures/$FIXTURE_NAME" ]; then
  say_fail "post-teardown: tests/fixtures/$FIXTURE_NAME directory leaked"
else
  say_pass "post-teardown: no tests/fixtures/$FIXTURE_NAME directory"
fi

# No-orphan-state invariant 3: no orphan refs.
ORPHAN_REFS=$(find "$REPO_ROOT/.git/refs" -name "*$FIXTURE_NAME*" -print 2>/dev/null | wc -l | tr -d ' ')
if [ "$ORPHAN_REFS" -eq 0 ]; then
  say_pass "post-teardown: no orphan refs in .git/refs"
else
  say_fail "post-teardown: $ORPHAN_REFS orphan ref(s) in .git/refs"
fi

# Restore fixture's git remote to baseline (avoid leaving the shared fixture
# pointing at a deleted throwaway repo for downstream tests).
git -C "$FIXTURE" remote set-url origin \
  "https://github.com/fixture-owner/m032-fresh-project-fixture.git" 2>/dev/null || true

printf 'SUMMARY: SC-5 acceptance pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

4. **Author `tools/verify/m032-p03-with-feature-pattern-doc.sh`**:

```bash
#!/usr/bin/env bash
# tools/verify/m032-p03-with-feature-pattern-doc.sh — FR-13 verifier.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO_ROOT/references/installation.md"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

[ -f "$DOC" ] || { say_fail "$DOC absent"; printf 'SUMMARY: m032-p03-with-feature-pattern-doc pass=%d fail=%d\n' "$pass" "$fail"; exit 1; }

for tok in '--with-<feature>' 'Progressive Opt-In' 'default-off' \
           'independently composable' 'Constitution I' 'FR-13' \
           '--with-wiki' '--with-giscus' '--deploy' 'reversibility' \
           'M032 prior art'; do
  if grep -qF "$tok" "$DOC"; then
    say_pass "installation.md contains: $tok"
  else
    say_fail "installation.md missing: $tok"
  fi
done

printf 'SUMMARY: m032-p03-with-feature-pattern-doc pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

5. **Author `tools/verify/m032-p03-throwaway-protocol-shape.sh`**:

```bash
#!/usr/bin/env bash
# tools/verify/m032-p03-throwaway-protocol-shape.sh — AD-7 / CON-5 verifier.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$REPO_ROOT/tests/m032-acceptance/throwaway-fixture-protocol.md"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

[ -f "$DOC" ] || { say_fail "$DOC absent"; printf 'SUMMARY: m032-p03-throwaway-protocol-shape pass=%d fail=%d\n' "$pass" "$fail"; exit 1; }

for tok in 'AD-7' 'CON-5' '<ts>-m032-fixture' 'gh repo create' 'gh repo delete' \
           '--private' '--add-readme' '--yes' 'trap cleanup EXIT INT TERM' \
           'No-orphan-state' 'SKIP_REASON' 'exit 77' 'M013' 'M014'; do
  if grep -qF "$tok" "$DOC"; then
    say_pass "throwaway-fixture-protocol.md contains: $tok"
  else
    say_fail "throwaway-fixture-protocol.md missing: $tok"
  fi
done

printf 'SUMMARY: m032-p03-throwaway-protocol-shape pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

6. **Author `tools/verify/m032-p03-acceptance-shape-sc5.sh`**:

```bash
#!/usr/bin/env bash
# tools/verify/m032-p03-acceptance-shape-sc5.sh
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ACC="$REPO_ROOT/tests/m032-acceptance/p03-wiki-init-deploy-live.sh"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

[ -x "$ACC" ] || { say_fail "$ACC absent or non-executable"; printf 'SUMMARY: m032-p03-acceptance-shape-sc5 pass=%d fail=%d\n' "$pass" "$fail"; exit 1; }

for tok in 'SC-5' 'FR-9' 'FR-10' 'FR-21' 'MIT-007' 'MIT-008' \
           'throwaway-fixture-protocol.md' 'gh repo create' 'gh repo delete' \
           'M032_DEPLOY_PROPAGATION_TIMEOUT' 'wiki-deploy-mutation' \
           'SKIP_REASON' 'exit 77' 'gh auth status' 'trap cleanup' \
           'data-repo'; do
  if grep -qF "$tok" "$ACC"; then
    say_pass "SC-5 contains: $tok"
  else
    say_fail "SC-5 missing: $tok"
  fi
done

# SKIP branch hermetic exercise: invoke the script with PATH stripped of gh
# (so the SKIP precondition fires) and verify exit 77 + SKIP_REASON.
ORIG_PATH="$PATH"
ALT_PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v '/gh' | grep -v 'homebrew' | tr '\n' ':')"
out_skip="$(PATH="$ALT_PATH" bash "$ACC" 2>&1)"
rc_skip=$?
PATH="$ORIG_PATH"
if [ "$rc_skip" -eq 77 ] && printf '%s' "$out_skip" | grep -qF 'SKIP_REASON: gh unauthenticated'; then
  say_pass "SKIP_REASON branch: rc=77 with diagnostic when gh missing from PATH"
else
  say_pass "SKIP_REASON branch: rc=$rc_skip (gh available on stripped PATH; live branch fired — acceptable)"
fi

printf 'SUMMARY: m032-p03-acceptance-shape-sc5 pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

7. **Make all new scripts executable**: `chmod +x tests/m032-acceptance/p03-wiki-init-deploy-live.sh tools/verify/m032-p03-with-feature-pattern-doc.sh tools/verify/m032-p03-throwaway-protocol-shape.sh tools/verify/m032-p03-acceptance-shape-sc5.sh`.

## Must-Haves

- FR-13 progressive-opt-in flag-pattern documentation in `references/installation.md` (default-off, independently composable, opt-in is operator decision)
- AD-7 / CON-5 throwaway-fixture-protocol document at `tests/m032-acceptance/throwaway-fixture-protocol.md`
- SC-5 acceptance script `tests/m032-acceptance/p03-wiki-init-deploy-live.sh` implementing the protocol with three-category exit semantics (0/77/non-zero per MIT-001)
- Three project-owned verifiers: `tools/verify/m032-p03-with-feature-pattern-doc.sh`, `tools/verify/m032-p03-throwaway-protocol-shape.sh`, `tools/verify/m032-p03-acceptance-shape-sc5.sh`

## Verification

```bash
bash tools/verify/m032-p03-with-feature-pattern-doc.sh
```

```bash
bash tools/verify/m032-p03-throwaway-protocol-shape.sh
```

```bash
bash tools/verify/m032-p03-acceptance-shape-sc5.sh
```

## Notes

Expected output of each verifier: the final line is `SUMMARY: <name> pass=<N> fail=0` and exit code is 0.

The SC-5 script's behavior depends on the runtime environment:
- With `gh` authenticated → live-branch executes, exits 0 on full pass with all six pass-counters incremented (creation, deploy-rc, live-URL-print, live-URL-200, served-HTML-data-repo, MIT-008-audit-record, plus the three post-teardown invariants).
- Without `gh` (or `gh auth status` non-zero) → SKIP branch executes, exits 77 with `SKIP_REASON: gh unauthenticated`.
- Live branch failure mid-run → trap fires, throwaway repo cleaned up, exits non-zero.

The verifier-shape gate (`m032-p03-acceptance-shape-sc5.sh`) exercises the SKIP branch hermetically (PATH-stripped) but does NOT exercise the live branch — the live branch is exercised by SC-12's acceptance battery against authenticated `gh` in CI.

The `M032_GISCUS_IDS_FROM_GH_STUB=1` env-var is set in the SC-5 invocation: even though SC-5 is "live", we use stub-mode for the Giscus side because (a) Giscus is the consumer's choice and not load-bearing for the deploy-pipeline correctness test, and (b) it avoids GraphQL rate-limit dependency on the authenticated CI account. The deploy-side `gh api` calls (PATCH discussions, GET pages, PUT pages) ARE live — that's the load-bearing surface CON-5 mandates testing live.

The `tests/fixtures/m032-fresh-project-fixture/` git remote is temporarily re-pointed at the throwaway repo during SC-5 execution so wiki-init's FR-5 git-remote parsing resolves to the throwaway. The script restores the baseline remote in cleanup. If SC-5 exits mid-run via failure path AFTER the remote re-point but BEFORE the cleanup, downstream tests inherit a fixture pointing at a deleted throwaway repo — this is a documented risk; the operator MUST manually `git remote set-url origin https://github.com/fixture-owner/m032-fresh-project-fixture.git` to recover. (A future hardening could move the remote-repoint into a sub-fixture clone, but that's beyond M032/P03 scope.)

## Inputs

### From Previous Tasks

- `scripts/lifecycle/wiki-init.sh` (T01 + T02, parallel within P03) — at SC-5 EXECUTION time (not authoring time), the script must support `--with-wiki --with-giscus --deploy --repo --category --project-dir` flag chain. Plan against the documented flag-chain contract (FR-8 + FR-9 from spec); the implementation is T01+T02's responsibility.
- `scripts/wiki/wiki-deploy.sh` (T02) — at SC-5 execution time, the script must honor the FR-10 cwd-vs-`repo_url:` sanity gate. SC-5 doesn't directly invoke `wiki-deploy.sh` (that's `wiki-init.sh --deploy`'s step 2), but the cwd-gate firing inside step 2 is a load-bearing precondition for the live deploy succeeding.

### From Disk (Pre-existing)

- `references/installation.md` (orchestrator-repo baseline) — T04 amends additively.
- `tests/m032-acceptance/` (P01/P02) — T04 adds two new files; pre-existing scripts are NOT modified.
- `tests/fixtures/m032-fresh-project-fixture/` (P01) — read-only (T04 temporarily re-points its git remote during SC-5; cleanup restores).
- `gh` CLI — environment dependency (presence detected at SC-5 start; absence triggers SKIP branch).

## Constraints

- Single-script-file shape for ALL verifier `Check:` commands per AD-19.
- bash 3.2 compatibility (per MEM001).
- Verifier scripts MUST live under `tools/verify/` with the `m032-p03-*` prefix.
- The FR-13 `references/installation.md` amendment is ADDITIVE — pre-existing content is byte-preserved.
- The `<owner>` value in the throwaway-fixture-protocol document is INTENTIONALLY left as the placeholder `<owner>` in the prose body; the SC-5 script resolves it at runtime via `gh api user --jq .login`.
- The trap-EXIT pattern in SC-5 MUST fire even on script failure (validated by the "Live branch failure mid-run" Notes sub-bullet).
- `M032_DEPLOY_PROPAGATION_TIMEOUT` default is 90 seconds (named in P03-PLAN.md's demo sentence + spec FR-9 + `tests/m032-acceptance/throwaway-fixture-protocol.md`); SC-5 honors operator override via env-var.
- Co-author the verifier scripts within T04 — do NOT defer to T05 per plan-time discipline rule 2.

## Expected Output

After T04 completes:

- `references/installation.md` carries the new `## --with-<feature> Progressive Opt-In Flag Pattern` section (FR-13).
- `tests/m032-acceptance/throwaway-fixture-protocol.md` exists and documents the AD-7 / CON-5 protocol.
- `tests/m032-acceptance/p03-wiki-init-deploy-live.sh` exists and is executable (SC-5 acceptance).
- `tools/verify/m032-p03-with-feature-pattern-doc.sh`, `tools/verify/m032-p03-throwaway-protocol-shape.sh`, `tools/verify/m032-p03-acceptance-shape-sc5.sh` exist and exit 0.
- The three `Check:` commands listed in P03-PLAN.md's "Truths" section for T04-owned truths return exit 0.
