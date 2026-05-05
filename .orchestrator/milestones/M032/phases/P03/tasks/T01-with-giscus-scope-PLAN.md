---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M032"
name: "FR-7 Giscus partial templating + FR-8 --with-giscus scope on wiki-init.sh + SC-4 acceptance"
depends_on: []
---

## Prerequisites

- `scripts/lifecycle/wiki-init.sh` exists and is executable from P02/T01. Verified by `[ -x scripts/lifecycle/wiki-init.sh ]`. Behavioral contract: bash 3.2; `set -eu`; recognizes `--project-dir`, `--site-name`, `--site-description`, `--auto-pip`, `--force` flags; honors `--with-giscus` and `--deploy` flags by REJECTING with exit 5 + `not yet implemented in P02; reserved for P03` (the current P02 reject-stub that this task amends to the real implementation); honors `M032_WIKI_INIT_FORCE_EXIT=<n>` env-var test-only failure injection.
- `scripts/diagnostics/giscus-ids-from-gh.sh` exists and is executable. Verified by `[ -x scripts/diagnostics/giscus-ids-from-gh.sh ]`. Behavioral contract: takes `--repo <owner>/<repo>` and `--category <name>` flags; on success emits four `export GISCUS_REPO="<value>"`, `export GISCUS_REPO_ID="<value>"`, `export GISCUS_CATEGORY="<value>"`, `export GISCUS_CATEGORY_ID="<value>"` lines on stdout (in that order, line-by-line, no leading/trailing blank lines); on failure exits non-zero with `ERROR: <reason>` on stderr; requires `gh` on PATH and authenticated.
- `scripts/diagnostics/wiki-giscus-config-check.sh` exists and is executable. Verified by `[ -x scripts/diagnostics/wiki-giscus-config-check.sh ]`. Behavioral contract: takes `--quiet` and `--project-dir <dir>` flags; on success exits 0; on failure exits non-zero with diagnostic on stderr naming any unset `GISCUS_*` env vars or any missing `data-*` attributes in the partial.
- `wiki/overrides/partials/comments.html` exists at the orchestrator repo with the existing `{{ config.extra.giscus.* }}` Jinja interpolations on lines 25–28 (M012/P03/T01-baseline). Verified by `[ -f wiki/overrides/partials/comments.html ]` and `grep -q 'config.extra.giscus.repo' wiki/overrides/partials/comments.html`.
- `tests/fixtures/m032-fresh-project-fixture/` exists from P01 with the fixture's git remote at `https://github.com/fixture-owner/m032-fresh-project-fixture.git`. After P02/T01 ran, `<fixture>/wiki/overrides/partials/comments.html` should already exist as a bundle-staged copy (T01 verifies this precondition and re-stages if absent).
- `tools/verify/` exists as the canonical home for project-owned slug-bearing verifiers per AD-19.
- `tests/m032-acceptance/` exists from P01/P02 with prior acceptance scripts (`p01-managed-bundle-shape.sh`, `p02-wiki-init-default-scope.sh`, etc.).

## Description

T01 lands the first composable scope on top of P02's default-scope `wiki-init.sh`. The deliverable surface has three pieces that ship together:

1. **FR-7 partial templating**: amend `wiki/overrides/partials/comments.html` to interleave the four `{{giscus_repo}}` / `{{giscus_repo_id}}` / `{{giscus_category}}` / `{{giscus_category_id}}` placeholder tokens with the existing Jinja interpolations. The two interpolation paths coexist by design — see "Coexistence model" in step 1 below.

2. **FR-8 `--with-giscus` scope**: amend `scripts/lifecycle/wiki-init.sh` to recognize `--with-giscus --repo <owner>/<repo> --category <name>` and execute the four-step `--with-giscus` workflow: invoke `giscus-ids-from-gh.sh` (with stub-mode envelope), parse four `export GISCUS_*` lines from stdout, sed-substitute the four placeholders in the staged partial, invoke `wiki-giscus-config-check.sh` as post-step verifier.

3. **SC-4 acceptance script**: author `tests/m032-acceptance/p02-wiki-init-with-giscus.sh` exercising happy-path / failure / re-run-idempotency / overwrite branches against the P01 shared fixture using `M032_GISCUS_IDS_FROM_GH_STUB` envelopes for deterministic CI behavior.

The atomicity argument for landing all three sub-deliverables in a single task: the partial templating (FR-7) is meaningless without the script (FR-8) that substitutes against it, and the script's correctness is uninspectable without the acceptance script (SC-4). Splitting introduces test windows where the bundle-staged partial carries placeholder tokens but no script writes against them, which fails the FR-22 collision invariant on next install (any consumer running `init` between landing-FR-7 and landing-FR-8 would inherit the placeholder partial and have no recourse).

## Steps

1. **Amend `wiki/overrides/partials/comments.html`** to add the four placeholder tokens. Coexistence model: the four `data-*` attribute lines (currently lines 25–28) carry BOTH the existing Jinja `{{ config.extra.giscus.* }}` interpolation (which mkdocs resolves at `mkdocs build` time from `extra.giscus.*` `!ENV [GISCUS_*, ""]` block in mkdocs.yml) AND the new M032-spec placeholder tokens that `wiki-init.sh --with-giscus` rewrites at install time. Required line shape (replace existing lines 25–28 with the new lines below; preserve the surrounding `<script ...>` opening tag on line 23–24 and the rest of the file unchanged):

```html
    data-repo="{{giscus_repo}}{{ config.extra.giscus.repo }}"
    data-repo-id="{{giscus_repo_id}}{{ config.extra.giscus.repo_id }}"
    data-category="{{giscus_category}}{{ config.extra.giscus.category }}"
    data-category-id="{{giscus_category_id}}{{ config.extra.giscus.category_id }}"
```

The concatenation shape (`{{giscus_repo}}` immediately followed by `{{ config.extra.giscus.repo }}`) is load-bearing: in the bundle-staged surface (where `mkdocs build` has not yet run) the literal `{{giscus_repo}}` token is what `wiki-init.sh --with-giscus` sed-substitutes against; in the orchestrator-local surface (where `--with-giscus` has not been run because the orchestrator uses `!ENV` Jinja interpolation directly), the literal `{{giscus_repo}}` token resolves at `mkdocs build` time to the empty string (Jinja's default for an undefined variable in a strict-mode-disabled config — verify `wiki/mkdocs.yml`'s `strict: false` baseline) leaving `{{ config.extra.giscus.repo }}` alone to be Jinja-interpolated. After `--with-giscus` runs against a consumer, the literal `{{giscus_repo}}` is replaced with the resolved repo slug AND `{{ config.extra.giscus.repo }}` remains in place (mkdocs build time will resolve THAT to whatever the consumer has in `mkdocs.yml`'s `extra.giscus.repo` — which the consumer can set to a static string in their mkdocs.yml fork OR leave empty for the placeholder-substitution path to be the sole source of truth).

Add a comment block between the existing `{# ... #}` Jinja comment (lines 1–16) and the `{% if ... %}` block (line 17) explaining the coexistence model:

```html
{#
  M032/P03/T01 — FR-7: dual-template interpolation surface.

  Each data-* attribute carries TWO interpolation forms:

    {{giscus_repo}}                  — M032 placeholder, sed-substituted by
                                       wiki-init.sh --with-giscus from the
                                       output of giscus-ids-from-gh.sh.
    {{ config.extra.giscus.repo }}   — Jinja+!ENV interpolation, resolved at
                                       mkdocs build time from mkdocs.yml's
                                       extra.giscus.* !ENV [GISCUS_*, ""] block.

  Bundle-staged copies carry both unrendered. wiki-init.sh --with-giscus
  rewrites the M032 placeholder; mkdocs build then resolves the Jinja form
  (which may be empty for projects that drive Giscus IDs entirely through
  the M032 path). The orchestrator-repo-local copy uses the Jinja+!ENV path
  (no --with-giscus run against the orchestrator itself) — the M032
  placeholders resolve to the empty string at mkdocs build.
#}
```

2. **Stage the amended partial in the bundle source**. The bundle source for the wiki/ project_assets entry is `<repo>/wiki/` (per P02/T01's manifest amendment). Since the orchestrator-repo's `wiki/overrides/partials/comments.html` is now the bundle source AND the orchestrator's own active partial, the amendment lands once and serves both consumers and the orchestrator-itself. Confirm this by inspecting `packaging/bundle/manifest.yml` for the `source: wiki/` entry under `project_assets:`.

3. **Amend `scripts/lifecycle/wiki-init.sh` to recognize `--with-giscus`** and replace the existing P02 reject-stub (which currently exits 5 with `not yet implemented in P02; reserved for P03`). Replace the block at lines 69–73 of P02-baseline `wiki-init.sh` (the `if [ "$WITH_GISCUS" = "1" ] || [ "$WITH_DEPLOY" = "1" ]; then ... reserved for P03 ... fi` block) with a conditional that branches on which scope is set: if `WITH_GISCUS=1` AND `WITH_DEPLOY=0`, dispatch to the new `--with-giscus` workflow (added below); if `WITH_DEPLOY=1`, dispatch to the new `--deploy` workflow (added by T02 — for T01's purpose, leave a placeholder reject for `WITH_DEPLOY=1` only, which T02 replaces).

Required `--with-giscus` flag-parsing additions to the flag-parse block (preserve existing `--project-dir`, `--site-name`, `--site-description`, `--auto-pip`, `--force` flags; add `--repo` and `--category` flags as below):

```bash
GISCUS_REPO_FLAG=""
GISCUS_CATEGORY_FLAG=""

# (inside the existing while [ $# -gt 0 ]; do case "$1" in ... esac done loop, add new arms:)
    --repo)
      shift
      if [ $# -eq 0 ]; then
        echo "FAIL: wiki-init: --repo requires an <owner>/<repo> argument" >&2
        exit 2
      fi
      GISCUS_REPO_FLAG="$1"; shift ;;
    --category)
      shift
      if [ $# -eq 0 ]; then
        echo "FAIL: wiki-init: --category requires a category-name argument" >&2
        exit 2
      fi
      GISCUS_CATEGORY_FLAG="$1"; shift ;;
```

Required `--with-giscus` workflow block (insert AFTER the FR-12 python toolchain probe and BEFORE the FR-5 git-remote-parsing block — `--with-giscus` is composable with `--with-wiki`; if `--with-giscus` is the first scope passed, the default-scope mkdocs templating MUST have already run on a prior `--with-wiki` invocation per the documented composition order. If the default-scope artifacts are absent at `--with-giscus` invocation, the script exits non-zero with `wiki-init: --with-giscus requires --with-wiki to have been run first; missing <fixture>/wiki/overrides/partials/comments.html`):

```bash
# FR-8 --with-giscus scope: substitute the four {{giscus_*}} placeholder tokens
# in <PROJECT_DIR>/wiki/overrides/partials/comments.html against IDs fetched
# from giscus-ids-from-gh.sh (or M032_GISCUS_IDS_FROM_GH_STUB stub mode).
if [ "$WITH_GISCUS" = "1" ]; then
  if [ -z "$GISCUS_REPO_FLAG" ] || [ -z "$GISCUS_CATEGORY_FLAG" ]; then
    echo "FAIL: wiki-init: --with-giscus requires both --repo <owner>/<repo> and --category <name>" >&2
    exit 2
  fi
  PARTIAL="$PROJECT_DIR/wiki/overrides/partials/comments.html"
  if [ ! -f "$PARTIAL" ]; then
    echo "FAIL: wiki-init: --with-giscus requires --with-wiki to have been run first; missing $PARTIAL" >&2
    exit 7
  fi

  # Test-only stub mode envelope per the M026/MEM030 <TOOL>_<NAME> env-var convention.
  IDS_OUT=""
  case "${M032_GISCUS_IDS_FROM_GH_STUB:-}" in
    1)
      # Deterministic fixture IDs — do not reach the network.
      IDS_OUT=$(printf 'export GISCUS_REPO="%s"\nexport GISCUS_REPO_ID="R_kgDOFixture"\nexport GISCUS_CATEGORY="%s"\nexport GISCUS_CATEGORY_ID="DIC_kwDOFixture"\n' "$GISCUS_REPO_FLAG" "$GISCUS_CATEGORY_FLAG")
      ids_rc=0
      ;;
    fail)
      echo "FAIL: wiki-init: integration-giscus-config-failed: M032_GISCUS_IDS_FROM_GH_STUB=fail (forced failure injection)" >&2
      exit 8
      ;;
    *)
      # Live path — invoke the real helper.
      set +e
      IDS_OUT="$(bash "$REPO_ROOT/scripts/diagnostics/giscus-ids-from-gh.sh" --repo "$GISCUS_REPO_FLAG" --category "$GISCUS_CATEGORY_FLAG" 2>&1)"
      ids_rc=$?
      set -e
      if [ "$ids_rc" -ne 0 ]; then
        echo "FAIL: wiki-init: integration-giscus-config-failed: giscus-ids-from-gh.sh exited $ids_rc — $IDS_OUT" >&2
        exit 8
      fi
      ;;
  esac

  # Parse the four export lines into shell variables.
  GISCUS_REPO_VAL=$(printf '%s' "$IDS_OUT" | sed -n 's/^export GISCUS_REPO="\(.*\)"$/\1/p')
  GISCUS_REPO_ID_VAL=$(printf '%s' "$IDS_OUT" | sed -n 's/^export GISCUS_REPO_ID="\(.*\)"$/\1/p')
  GISCUS_CATEGORY_VAL=$(printf '%s' "$IDS_OUT" | sed -n 's/^export GISCUS_CATEGORY="\(.*\)"$/\1/p')
  GISCUS_CATEGORY_ID_VAL=$(printf '%s' "$IDS_OUT" | sed -n 's/^export GISCUS_CATEGORY_ID="\(.*\)"$/\1/p')
  if [ -z "$GISCUS_REPO_VAL" ] || [ -z "$GISCUS_REPO_ID_VAL" ] || [ -z "$GISCUS_CATEGORY_VAL" ] || [ -z "$GISCUS_CATEGORY_ID_VAL" ]; then
    echo "FAIL: wiki-init: integration-giscus-config-failed: could not parse all four GISCUS_* exports from helper output" >&2
    exit 8
  fi

  # Sed-substitute the four {{giscus_*}} placeholders. Use | as the sed
  # delimiter (none of the values contain |); escape & in values for
  # sed-replacement-safety. Bash 3.2 sed-in-place: BSD sed requires `-i ''`,
  # GNU sed accepts `-i`. Use a temp-file rename pattern to avoid the difference.
  TMP_PARTIAL="$(mktemp -t comments.html.XXXXXX)"
  trap 'rm -f "$TMP_PARTIAL"' EXIT
  sed_escape() { printf '%s' "$1" | sed -e 's|[\\&|]|\\&|g'; }
  GR_E=$(sed_escape "$GISCUS_REPO_VAL")
  GRI_E=$(sed_escape "$GISCUS_REPO_ID_VAL")
  GC_E=$(sed_escape "$GISCUS_CATEGORY_VAL")
  GCI_E=$(sed_escape "$GISCUS_CATEGORY_ID_VAL")
  sed \
    -e "s|{{giscus_repo}}|$GR_E|g" \
    -e "s|{{giscus_repo_id}}|$GRI_E|g" \
    -e "s|{{giscus_category}}|$GC_E|g" \
    -e "s|{{giscus_category_id}}|$GCI_E|g" \
    "$PARTIAL" > "$TMP_PARTIAL"
  cp "$TMP_PARTIAL" "$PARTIAL"
  rm -f "$TMP_PARTIAL"
  trap - EXIT

  # FR-8 post-step verifier.
  set +e
  bash "$REPO_ROOT/scripts/diagnostics/wiki-giscus-config-check.sh" --project-dir "$PROJECT_DIR" --quiet
  check_rc=$?
  set -e
  if [ "$check_rc" -ne 0 ]; then
    echo "FAIL: wiki-init: integration-giscus-config-check-failed: wiki-giscus-config-check.sh exited $check_rc against $PROJECT_DIR" >&2
    exit 9
  fi

  echo "wiki-init: --with-giscus done — substituted four giscus IDs in $PARTIAL"
fi
```

Update the file-header exit-code comment block to reflect the new exit codes:

```
# Exit codes:
#   0 — success.
#   2 — argument error.
#   3 — toolchain missing.
#   4 — git remote missing or unparseable.
#   5 — --deploy passed but not implemented (P03/T02 replaces this).
#   6 — bundle staging failure.
#   7 — --with-giscus invoked without --with-wiki (no <fixture>/wiki/overrides/partials/comments.html).
#   8 — integration-giscus-config-failed (giscus-ids-from-gh.sh upstream failure).
#   9 — integration-giscus-config-check-failed (wiki-giscus-config-check.sh post-step failure).
```

4. **Author `tests/m032-acceptance/p02-wiki-init-with-giscus.sh` (SC-4)**. The test runs against the P01 shared fixture at `tests/fixtures/m032-fresh-project-fixture/`. It MUST first run a default `wiki-init.sh --project-dir <fixture>` to ensure the partial is staged in the fixture (idempotent — preserves prior state). Then exercise four branches: happy-path (stub mode 1), failure mode (stub mode `fail`), re-run idempotency, overwrite branch.

```bash
#!/usr/bin/env bash
# tests/m032-acceptance/p02-wiki-init-with-giscus.sh — SC-4 (FR-7 + FR-8).
#
# Verifies: wiki/overrides/partials/comments.html bundle-staged copy carries
# the four {{giscus_*}} placeholder tokens; wiki-init.sh --with-giscus
# substitutes them with deterministic fixture IDs under
# M032_GISCUS_IDS_FROM_GH_STUB=1; the post-step wiki-giscus-config-check.sh
# verifier exits 0; failure injection (M032_GISCUS_IDS_FROM_GH_STUB=fail)
# leaves the partial in placeholder state with `integration-giscus-config-failed`
# diagnostic; re-run with same flags is idempotent; re-run with different
# flags overwrites with new IDs (US-3 AS-3).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$REPO_ROOT/tests/fixtures/m032-fresh-project-fixture"
PARTIAL="$FIXTURE/wiki/overrides/partials/comments.html"

pass=0
fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# Pre-1: wiki-init default scope to stage the partial in the fixture.
if ! bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" --project-dir "$FIXTURE" >/dev/null 2>&1; then
  say_fail "default-scope wiki-init failed against fixture (SC-4 precondition)"
  printf 'SUMMARY: SC-4 acceptance pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# 1. Bundle-staged partial carries the four placeholder tokens.
if grep -qF '{{giscus_repo}}' "$PARTIAL" && \
   grep -qF '{{giscus_repo_id}}' "$PARTIAL" && \
   grep -qF '{{giscus_category}}' "$PARTIAL" && \
   grep -qF '{{giscus_category_id}}' "$PARTIAL"; then
  say_pass "FR-7: four {{giscus_*}} placeholder tokens present in staged partial"
else
  say_fail "FR-7: one or more {{giscus_*}} placeholder tokens missing from $PARTIAL"
fi

# 2. Happy path with stub mode 1.
M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-giscus --repo fixture-owner/fixture-repo --category 'Wiki Comments' \
  --project-dir "$FIXTURE" >/dev/null 2>&1
giscus_rc=$?
if [ "$giscus_rc" -eq 0 ] && \
   grep -qF 'fixture-owner/fixture-repo' "$PARTIAL" && \
   grep -qF 'R_kgDOFixture' "$PARTIAL" && \
   grep -qF 'Wiki Comments' "$PARTIAL" && \
   grep -qF 'DIC_kwDOFixture' "$PARTIAL" && \
   ! grep -qF '{{giscus_repo}}' "$PARTIAL"; then
  say_pass "FR-8 happy path: four IDs substituted, no {{giscus_repo}} placeholder remains"
else
  say_fail "FR-8 happy path: rc=$giscus_rc; partial does not carry expected fixture IDs (or placeholder remains)"
fi

# 3. Post-step verifier exits 0.
bash "$REPO_ROOT/scripts/diagnostics/wiki-giscus-config-check.sh" --project-dir "$FIXTURE" --quiet
check_rc=$?
if [ "$check_rc" -eq 0 ]; then
  say_pass "FR-8 post-step: wiki-giscus-config-check.sh exits 0 after substitution"
else
  say_fail "FR-8 post-step: wiki-giscus-config-check.sh rc=$check_rc"
fi

# 4. Failure injection branch — re-stage the partial first to reset placeholder state.
bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" --project-dir "$FIXTURE" --force >/dev/null 2>&1
err_out="$(M032_GISCUS_IDS_FROM_GH_STUB=fail bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-giscus --repo fixture-owner/fixture-repo --category 'Wiki Comments' \
  --project-dir "$FIXTURE" 2>&1)"
inject_rc=$?
if [ "$inject_rc" -ne 0 ] && \
   printf '%s' "$err_out" | grep -qF 'integration-giscus-config-failed' && \
   grep -qF '{{giscus_repo}}' "$PARTIAL"; then
  say_pass "FR-8 failure injection: rc=$inject_rc, integration-giscus-config-failed diagnostic, partial in placeholder state"
else
  say_fail "FR-8 failure injection: rc=$inject_rc; expected non-zero with diagnostic and placeholders preserved"
fi

# 5. Re-run idempotency (same flags twice).
bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" --project-dir "$FIXTURE" --force >/dev/null 2>&1
M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-giscus --repo fixture-owner/fixture-repo --category 'Wiki Comments' \
  --project-dir "$FIXTURE" >/dev/null 2>&1
SHA_FIRST=$(shasum -a 256 "$PARTIAL" | awk '{print $1}')
M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-giscus --repo fixture-owner/fixture-repo --category 'Wiki Comments' \
  --project-dir "$FIXTURE" >/dev/null 2>&1
SHA_SECOND=$(shasum -a 256 "$PARTIAL" | awk '{print $1}')
if [ "$SHA_FIRST" = "$SHA_SECOND" ]; then
  say_pass "FR-8 re-run idempotency: partial sha-256 stable across two same-flag invocations"
else
  say_fail "FR-8 re-run idempotency: partial sha-256 changed: $SHA_FIRST -> $SHA_SECOND"
fi

# 6. Overwrite branch (US-3 AS-3) — different --repo / --category re-substitutes.
M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" \
  --with-giscus --repo fixture-owner-2/fixture-repo-2 --category 'Different Category' \
  --project-dir "$FIXTURE" >/dev/null 2>&1
overwrite_rc=$?
if [ "$overwrite_rc" -eq 0 ] && \
   grep -qF 'fixture-owner-2/fixture-repo-2' "$PARTIAL" && \
   grep -qF 'Different Category' "$PARTIAL" && \
   ! grep -qF 'fixture-owner/fixture-repo' "$PARTIAL"; then
  say_pass "FR-8 overwrite branch (US-3 AS-3): new IDs replace prior IDs"
else
  say_fail "FR-8 overwrite branch: rc=$overwrite_rc; new IDs absent or prior IDs not displaced"
fi

# Restore placeholder state (clean teardown).
bash "$REPO_ROOT/scripts/lifecycle/wiki-init.sh" --project-dir "$FIXTURE" --force >/dev/null 2>&1 || true

printf 'SUMMARY: SC-4 acceptance pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

Make executable: `chmod +x tests/m032-acceptance/p02-wiki-init-with-giscus.sh`.

5. **Author `tools/verify/m032-p03-giscus-templating.sh`** (FR-7 verifier). Asserts the four placeholder tokens are present at the expected line shapes in `wiki/overrides/partials/comments.html`. Single-script-file shape per AD-19. Required content shape:

```bash
#!/usr/bin/env bash
# tools/verify/m032-p03-giscus-templating.sh — FR-7 verifier.
# Asserts the four M032 {{giscus_*}} placeholder tokens are interleaved
# with the existing Jinja {{ config.extra.giscus.* }} interpolations in
# the bundle-staged Giscus partial.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PARTIAL="$REPO_ROOT/wiki/overrides/partials/comments.html"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

[ -f "$PARTIAL" ] || { say_fail "missing $PARTIAL"; printf 'SUMMARY: m032-p03-giscus-templating pass=%d fail=%d\n' "$pass" "$fail"; exit 1; }

for tok in '{{giscus_repo}}' '{{giscus_repo_id}}' '{{giscus_category}}' '{{giscus_category_id}}'; do
  if grep -qF "$tok" "$PARTIAL"; then
    say_pass "placeholder token present: $tok"
  else
    say_fail "placeholder token absent: $tok"
  fi
done

# Coexistence: the existing Jinja interpolations must STILL be present.
for jinja in 'config.extra.giscus.repo' 'config.extra.giscus.repo_id' 'config.extra.giscus.category' 'config.extra.giscus.category_id'; do
  if grep -qF "$jinja" "$PARTIAL"; then
    say_pass "jinja interpolation preserved: $jinja"
  else
    say_fail "jinja interpolation missing: $jinja (FR-7 coexistence model violated)"
  fi
done

# FR-7 documentation comment block.
if grep -qF 'M032/P03/T01 — FR-7' "$PARTIAL"; then
  say_pass "FR-7 comment block present"
else
  say_fail "FR-7 comment block missing (expected 'M032/P03/T01 — FR-7' marker)"
fi

printf 'SUMMARY: m032-p03-giscus-templating pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

6. **Author `tools/verify/m032-p03-with-giscus-scope.sh`** (FR-8 verifier). Asserts the wiki-init.sh `--with-giscus` workflow code path is present (text-grep checks against the script body) and exercises stub-mode happy-path and failure-injection branches against a tmpdir fixture (NOT the shared P01 fixture — keep this verifier hermetic; the SC-4 acceptance script exercises the shared fixture). Single-script-file shape. Required content sketch:

```bash
#!/usr/bin/env bash
# tools/verify/m032-p03-with-giscus-scope.sh — FR-8 verifier.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WI="$REPO_ROOT/scripts/lifecycle/wiki-init.sh"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# Static text checks on wiki-init.sh source.
for tok in '--with-giscus' '--repo' '--category' 'M032_GISCUS_IDS_FROM_GH_STUB' \
           'wiki-giscus-config-check.sh' 'integration-giscus-config-failed' \
           'integration-giscus-config-check-failed' 'GISCUS_REPO_VAL' \
           'GISCUS_REPO_ID_VAL' 'GISCUS_CATEGORY_VAL' 'GISCUS_CATEGORY_ID_VAL'; do
  if grep -qF "$tok" "$WI"; then
    say_pass "wiki-init.sh contains: $tok"
  else
    say_fail "wiki-init.sh missing: $tok"
  fi
done

# Hermetic stub-mode happy path against a tmpdir fixture.
TMPDIR_F=$(mktemp -d -t m032-p03-with-giscus.XXXXXX)
trap 'rm -rf "$TMPDIR_F"' EXIT
mkdir -p "$TMPDIR_F/wiki/overrides/partials"
cp "$REPO_ROOT/wiki/overrides/partials/comments.html" "$TMPDIR_F/wiki/overrides/partials/comments.html"
# Set up a minimal git remote so wiki-init's FR-5 path doesn't bail.
(cd "$TMPDIR_F" && git init -q && git remote add origin https://github.com/fixture-owner/m032-p03-tmp.git)

M032_GISCUS_IDS_FROM_GH_STUB=1 bash "$WI" \
  --with-giscus --repo fixture-owner/m032-p03-tmp --category 'Wiki Comments' \
  --project-dir "$TMPDIR_F" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -qF 'fixture-owner/m032-p03-tmp' "$TMPDIR_F/wiki/overrides/partials/comments.html"; then
  say_pass "stub-mode happy path substitutes IDs in tmpdir fixture (rc=0)"
else
  say_fail "stub-mode happy path: rc=$rc; substitution did not fire"
fi

# Hermetic failure injection.
cp "$REPO_ROOT/wiki/overrides/partials/comments.html" "$TMPDIR_F/wiki/overrides/partials/comments.html"
M032_GISCUS_IDS_FROM_GH_STUB=fail bash "$WI" \
  --with-giscus --repo fixture-owner/m032-p03-tmp --category 'Wiki Comments' \
  --project-dir "$TMPDIR_F" 2>/dev/null
rc=$?
if [ "$rc" -ne 0 ] && grep -qF '{{giscus_repo}}' "$TMPDIR_F/wiki/overrides/partials/comments.html"; then
  say_pass "stub-mode fail injection: rc=$rc, partial preserved in placeholder state"
else
  say_fail "stub-mode fail injection: rc=$rc; partial not preserved"
fi

printf 'SUMMARY: m032-p03-with-giscus-scope pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

7. **Author `tools/verify/m032-p03-acceptance-shape-sc4.sh`** (acceptance-shape verifier). Single-script-file shape; asserts the SC-4 acceptance script exists, is executable, and contains the load-bearing tokens that prove it exercises all six SC-4 branches (precondition default-scope, FR-7 placeholder-presence, FR-8 happy-path, post-step verifier, failure injection, re-run idempotency, overwrite). Required content sketch:

```bash
#!/usr/bin/env bash
# tools/verify/m032-p03-acceptance-shape-sc4.sh
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ACC="$REPO_ROOT/tests/m032-acceptance/p02-wiki-init-with-giscus.sh"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

[ -x "$ACC" ] || { say_fail "$ACC absent or non-executable"; printf 'SUMMARY: m032-p03-acceptance-shape-sc4 pass=%d fail=%d\n' "$pass" "$fail"; exit 1; }

for tok in 'SC-4' 'FR-7' 'FR-8' 'M032_GISCUS_IDS_FROM_GH_STUB=1' 'M032_GISCUS_IDS_FROM_GH_STUB=fail' \
           'fixture-owner/fixture-repo' 'R_kgDOFixture' 'wiki-giscus-config-check.sh' \
           'integration-giscus-config-failed' '{{giscus_repo}}' 'fixture-owner-2'; do
  if grep -qF "$tok" "$ACC"; then
    say_pass "SC-4 contains: $tok"
  else
    say_fail "SC-4 missing: $tok"
  fi
done

printf 'SUMMARY: m032-p03-acceptance-shape-sc4 pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

8. **Make all three new verifier scripts executable**: `chmod +x tools/verify/m032-p03-giscus-templating.sh tools/verify/m032-p03-with-giscus-scope.sh tools/verify/m032-p03-acceptance-shape-sc4.sh`.

## Must-Haves

- FR-7 partial templating (the four `{{giscus_*}}` placeholder tokens interleaved with the existing Jinja interpolations in `wiki/overrides/partials/comments.html`)
- FR-8 `--with-giscus` scope on `wiki-init.sh` (helper invocation, parse, sed-substitute, post-step verifier, exit-code mapping including `M032_GISCUS_IDS_FROM_GH_STUB=1|fail` envelope)
- SC-4 acceptance script (`tests/m032-acceptance/p02-wiki-init-with-giscus.sh`)
- Three project-owned verifiers: `tools/verify/m032-p03-giscus-templating.sh`, `tools/verify/m032-p03-with-giscus-scope.sh`, `tools/verify/m032-p03-acceptance-shape-sc4.sh`

## Verification

```bash
bash tools/verify/m032-p03-giscus-templating.sh
```

```bash
bash tools/verify/m032-p03-with-giscus-scope.sh
```

```bash
bash tools/verify/m032-p03-acceptance-shape-sc4.sh
```

```bash
bash tests/m032-acceptance/p02-wiki-init-with-giscus.sh
```

## Notes

Expected output of each verifier: the final line is `SUMMARY: <name> pass=<N> fail=0` and exit code is 0. The SC-4 acceptance script's final line is `SUMMARY: SC-4 acceptance pass=6 fail=0` and exit code is 0 (six branches: FR-7 placeholder presence, happy path, post-step verifier, failure injection, re-run idempotency, overwrite branch).

Coexistence-model gotcha: in the bundle-staged surface, the literal `{{giscus_repo}}` token sits IMMEDIATELY before `{{ config.extra.giscus.repo }}` with no separator (`data-repo="{{giscus_repo}}{{ config.extra.giscus.repo }}"`). The sed-substitution pattern `{{giscus_repo}}` is unique enough that it will not accidentally match the Jinja form (Jinja's form has spaces inside the braces and a dotted path). Verify this empirically with the SC-4 acceptance test's branch 1 assertion (`! grep -qF '{{giscus_repo}}' "$PARTIAL"` after substitution AND `grep -qF '{{ config.extra.giscus.repo }}' "$PARTIAL"` should still pass — the Jinja interpolation is NOT touched by the sed pass).

The dual-template approach is intentional: it gives consumers two equally valid Giscus-config paths (M032 placeholder-substitution at install time OR mkdocs `extra.giscus.*` `!ENV` at build time) without forcing a choice. Documentation lives in the `{# ... #}` comment block in step 1 and in `commands/wiki-init.md`'s `--with-giscus` section.

## Inputs

### From Previous Tasks

(none — T01 is independent of T02–T04 within P03; depends only on P02 artifacts)

### From Disk (Pre-existing)

- `scripts/lifecycle/wiki-init.sh` (P02/T01) — bash 3.2 default-scope script. T01 amends it to add `--with-giscus` handling. Read `scripts/lifecycle/wiki-init.sh:69-73` for the existing reject-stub block to replace.
- `wiki/overrides/partials/comments.html` (M012/P03/T01 baseline) — current Jinja-interpolation-based Giscus partial. T01 amends lines 25-28 to add the four `{{giscus_*}}` placeholder tokens alongside the existing Jinja interpolations.
- `scripts/diagnostics/giscus-ids-from-gh.sh` (M012/P02 baseline) — `--repo`/`--category` GraphQL helper. Read `scripts/diagnostics/giscus-ids-from-gh.sh:149-152` for the four `export GISCUS_*` output line shape.
- `scripts/diagnostics/wiki-giscus-config-check.sh` (M012 baseline) — post-step verifier. T01 invokes it via `bash <path> --project-dir <dir> --quiet`.
- `tests/fixtures/m032-fresh-project-fixture/` (P01) — shared fixture used by the SC-4 acceptance script.

## Constraints

- Single-script-file shape for ALL verifier `Check:` commands per AD-19.
- bash 3.2 compatibility (per MEM001) — no `declare -A`, no process substitution, no command substitution containing pipes (use `sed -n`/`grep -F` chains, not `wc -l < <(...)`-style constructs).
- Verifier scripts MUST live under `tools/verify/` with the `m032-p03-*` prefix per AD-19 path discipline.
- No modifications to `commands/init.md`, `scripts/lifecycle/init-project.sh`, `packaging/bundle/manifest.yml`, `wiki/glossary.md`, or `scripts/wiki/wiki-scan-sources.sh` — those are P02-owned (scope-guard enforcement).
- Co-author the three verifier scripts within T01 — do NOT defer them to T05 per plan-time discipline rule 2 (verifier-availability cross-check). T05 only authors the phase-suite + scope-guard.
- The `M032_GISCUS_IDS_FROM_GH_STUB` env-var shape follows the M026/MEM030 `<TOOL>_*` env-var convention — operator-facing surface MUST NOT honor this var unset path implicitly; it is test-only.

## Expected Output

After T01 completes:

- `wiki/overrides/partials/comments.html` carries the four `{{giscus_*}}` placeholder tokens AND the existing Jinja interpolations (FR-7 dual-template surface).
- `scripts/lifecycle/wiki-init.sh` recognizes `--with-giscus --repo <owner>/<repo> --category <name>` and implements the four-step workflow.
- `tests/m032-acceptance/p02-wiki-init-with-giscus.sh` exists and exits 0 (SC-4 PASS).
- `tools/verify/m032-p03-giscus-templating.sh`, `tools/verify/m032-p03-with-giscus-scope.sh`, `tools/verify/m032-p03-acceptance-shape-sc4.sh` exist and exit 0.
- The four `Check:` commands listed in P03-PLAN.md's "Truths" section for T01-owned truths return exit 0.
