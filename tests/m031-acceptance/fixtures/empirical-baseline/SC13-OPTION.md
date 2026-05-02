# SC-13 Option Selection

AD-12 specifies two options for SC-13 (baseline-ordering enforcement):

- **Option B (preferred)**: `verify-baseline-ordering.sh` asserts via `git log`
  that the first commit touching `tests/m031-acceptance/fixtures/empirical-baseline/`
  predates the first commit touching `scripts/dispatch/build-context.sh` and
  `commands/dispatch.md`. SC-13 stays in SC-14's count; `N ≥ 15`.

- **Option A (fallback)**: when `git log` is unavailable (shallow clone,
  uncommitted corpus, etc.), SC-13 reclassifies as a P00 protocol note.
  Drops from SC-14's count; `N ≥ 14`.

## Selected: Option A

At T03 execution time, `git log -- tests/m031-acceptance/fixtures/empirical-baseline/`
returns empty stdout because the corpus directory is created and populated
during T02 / T03 within this same uncommitted working tree — there is no
committed git history covering the corpus path yet, so Option B's
`corpus_first_commit_ct < protected_first_commit_ct` assertion has no
defined left-hand side. The verifier therefore takes the Option A
fallback path and emits `ORDERING: option=A verdict=protocol-note`.

The single-window discipline of AD-14 is preserved by procedure rather than
by automated assertion: the `pre-m031-baseline.jsonl` capture committed at
T03 close happens BEFORE any P01 first-commit modification of
`commands/dispatch.md:21` or `scripts/dispatch/build-context.sh`, and that
ordering is observable in git history once both T03 and the P01 first task
have landed. Operators can re-run `verify-baseline-ordering.sh` after both
commits exist; under that condition Option B will succeed and SC-14's count
recovers `N ≥ 15`. P04's acceptance battery aggregator may re-evaluate this
file against the post-P01 git history and upgrade the selected option if
desired — the file is the authoritative record of which floor SC-14 uses
at evaluation time.

## Effective N for SC-14: 14
