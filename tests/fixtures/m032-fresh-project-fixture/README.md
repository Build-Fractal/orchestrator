# m032-fresh-project-fixture

Minimal-but-valid consumer-shape fixture for M032 P01..P04 acceptance tests.

## Purpose

Acts as a "fresh project" target into which the orchestrator runtime payload
(`commands/`, `scripts/`, `references/`, `templates/`) is staged via the
project-assets-driven install path introduced by M032 P01. The fixture is
deliberately empty of any orchestrator-staged content so installer runs can
demonstrate the byte-identical-at-`mode: copy` invariant (CON-4) and the FR-3
symbolic-link mode against a clean slate.

The committed fixture omits the `.git/` directory; acceptance scripts
materialize one at test time via the bootstrap procedure below so the
committed fixture remains a tiny three-file artifact (no checked-in git
objects).

## Bootstrap procedure

Acceptance scripts that need a populated `.git/` (e.g. SC-2 `git status`
checks, SC-10 `git check-ignore` oracle queries) run this on a `mktemp -d`
staged copy:

```bash
tmp_fix="$(mktemp -d)/m032-acceptance-$$"
mkdir -p "$tmp_fix"
cp -R tests/fixtures/m032-fresh-project-fixture/. "$tmp_fix"/
( cd "$tmp_fix" && git init -q && \
  git remote add origin https://github.com/fixture-owner/m032-fresh-project-fixture.git )
```

The git remote URL is recorded in `.git-init-marker` so future P02 wiki-init
default-scope tests can parse it deterministically. The committed fixture is
NEVER mutated by acceptance scripts; the staging dir is the only mutation
target and is torn down via `rm -rf "$tmp_fix"` on every exit path.

## Consumers

- **P01 SC-1** (`tests/m032-acceptance/p01-managed-bundle-shape.sh`):
  asserts FR-1 / FR-2 / FR-4 + idempotency by running the claude-code
  installer twice against a staged copy and comparing per-runtime-dir
  sha256 sums.
- **P01 SC-2** (`tests/m032-acceptance/p01-symlink-mode.sh`):
  asserts FR-3 POSIX symlink + Windows fail-closed by running with
  `--asset-mode-override symlink` and `M032_FORCE_WINDOWS=1`. Each of the
  four runtime dirs (`commands/`, `scripts/`, `references/`, `templates/`)
  must be a symbolic link, and the `.gitignore` excludes them so
  `git status --short` reports zero lines.
- **P01 SC-10** (`tests/m032-acceptance/p01-staged-dirs-collision.sh`):
  exercises all three FR-22 oracle branches: clean / bootstrapping
  (MIT-006) / operator-owned.
- **P02 wiki-init default-scope**: parses the `.git-init-marker` for the
  origin remote.
- **P03 deploy fixture**: same staging pattern.
- **P04 SC-11 doctor check**: runs `run-doctor.sh` against a staged copy.

## Files

- `.gitignore` — excludes the four runtime dirs (`commands/`, `scripts/`,
  `references/`, `templates/`) plus `.orchestrator/` from git tracking.
  This is required for FR-3 (a symlink under `commands/` must not show up
  as an untracked file in the consumer project's `git status`).
- `.git-init-marker` — one-line `git_remote=<url>` record consumed by the
  bootstrap procedure and by P02 default-scope inference.
- `README.md` — this file.

## Invariants

- The committed fixture is read-only at test time. Acceptance scripts cp it
  into `mktemp -d` before any mutation.
- Teardown `rm -rf` of the staging dir is mandatory on every exit path
  (success, fail, SKIP). Dangling `/tmp/m032-sc*` dirs are a CI-hygiene
  regression.
- The `.gitignore` excludes the four runtime dirs so post-install
  `git status --short` is clean for both `mode: copy` and `mode: symlink`.
