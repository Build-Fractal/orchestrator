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
