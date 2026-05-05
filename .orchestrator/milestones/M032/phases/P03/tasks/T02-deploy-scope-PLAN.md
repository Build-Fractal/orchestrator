---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M032"
name: "FR-9 + MIT-007 + MIT-008 --deploy scope on wiki-init.sh + FR-10 cwd sanity gate on wiki-deploy.sh"
depends_on: []
---

## Prerequisites

- `scripts/lifecycle/wiki-init.sh` exists and is executable from P02/T01. T02 modifies it independently of T01's `--with-giscus` amendments. T01 and T02 modify NON-OVERLAPPING sections of the script (T01 adds the `--with-giscus` block AFTER the FR-12 toolchain probe; T02 adds the `--deploy` block AFTER T01's `--with-giscus` block). If T01 and T02 are dispatched in parallel and a merge conflict surfaces, resolve by ordering: `--with-giscus` block first, `--deploy` block second.
- `scripts/wiki/wiki-deploy.sh` exists and is executable from M012 baseline. Verified by `[ -x scripts/wiki/wiki-deploy.sh ]`. Behavioral contract: bash 3.2; `set -u`; runs the four pre-deploy gates (giscus-config-check, mkdocs build, link-check, giscus-smoke); runs `mkdocs gh-deploy --force` on the live path; honors `--dry-run`, `--root`, `--skip-smoke`, `--help` flags.
- `wiki/mkdocs.yml` exists with a parsable `repo_url:` field (from P02/T01's FR-6 templating amendment). Verified by `grep -q '^repo_url:' wiki/mkdocs.yml`.
- `gh` CLI MAY be on PATH (T02's live-path code reaches the network; the `M032_DEPLOY_GH_API_STUB=1` env-var shortcuts past it for hermetic verifier coverage). Live-path verification is reserved for SC-5 (T04 deliverable).
- `tests/fixtures/m032-fresh-project-fixture/` exists from P01 with a configured git remote. The verifier scripts in this task use ephemeral tmpdir fixtures and do NOT modify the shared fixture.
- `.orchestrator/execution-log.jsonl` may or may not exist at task start; `wiki-init.sh --deploy` creates it on first append per the JSONL append-only convention.

## Description

T02 lands the highest-blast-radius surface in M032: the `--deploy` scope on `wiki-init.sh` plus the FR-10 cwd-vs-`repo_url:` sanity gate on `wiki-deploy.sh`. The deliverable surface has three pieces that ship together:

1. **FR-10 cwd sanity gate** on `scripts/wiki/wiki-deploy.sh` — a hard precondition that fires BEFORE the existing pre-deploy gates, parsing `repo_url:` from `<PROJECT_ROOT>/wiki/mkdocs.yml` and `git -C $PROJECT_ROOT remote get-url origin`, normalizing both to `<owner>/<repo>` form, and exiting non-zero on mismatch with the `cross-project hazard` diagnostic. This is the Finding J counter-pattern.

2. **FR-9 + MIT-007 + MIT-008 `--deploy` scope** on `scripts/lifecycle/wiki-init.sh` — the four-step ordered sequence (`gh api PATCH /repos/.../discussions=true` → `wiki-deploy.sh` → MIT-007 read-before-write Pages guard → `gh api PUT /repos/.../pages`) followed by the MIT-008 audit-trail JSONL append AFTER step 4 / BEFORE the live URL print. Failure modes append a `result: "failure"` audit record and exit non-zero before printing the URL.

3. **Two verifiers**: `tools/verify/m032-p03-deploy-scope.sh` exercises the workflow end-to-end via `M032_DEPLOY_GH_API_STUB=1` against a tmpdir fixture (no live network); `tools/verify/m032-p03-wiki-deploy-cwd-gate.sh` exercises FR-10 happy-path (matching cwd / remote / repo_url) and mismatch-fails-closed branches.

The atomicity argument for landing all three pieces together: the `--deploy` scope CALLS `wiki-deploy.sh` (which T02 amends with the FR-10 gate); splitting into separate tasks introduces a window where `wiki-init.sh --deploy` invokes a `wiki-deploy.sh` without the FR-10 gate, replicating exactly the cross-project-cwd-hazard the gate was added to prevent. The verifier set must co-author per plan-time discipline rule 2 (no cross-task verifier dependencies).

## Steps

1. **Amend `scripts/wiki/wiki-deploy.sh` with the FR-10 cwd-vs-`repo_url:` sanity gate**. Insert the gate as the FIRST gate (before the existing "gate 1: giscus config-check" block at line ~94). The gate is conditional on `M032_WIKI_DEPLOY_BYPASS_CWD_GATE` env-var: unset/empty/0 → gate fires; `=1` → gate skipped (test-only override for hermetic verifier coverage where the fixture has no real git remote).

Required code block to insert at line ~93 (immediately after the `cd "$ROOT"` line at line 92, before the `# -------- gate 1: giscus config-check --------` comment header):

```bash
# -------- gate 0: FR-10 cwd-vs-repo_url sanity gate (Finding J counter-pattern) --------
# Compares repo_url: parsed from <ROOT>/wiki/mkdocs.yml against
# git -C $ROOT remote get-url origin. Normalizes both to canonical
# <owner>/<repo> form (case-lowered owner, case-preserved repo;
# strip .git suffix; strip https://github.com/ or git@github.com:
# prefixes). Exits non-zero with cross-project-hazard diagnostic on
# mismatch — protects against the silent cross-project force-push
# class of bug observed in the 2026-04-28 PBJ pilot session.
#
# Test-only override: M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1 skips the gate.
# Used ONLY by tools/verify/m032-p03-* verifiers and by the SC-5/SC-6
# acceptance scripts when their fixture has no real GH remote. The
# operator-facing surface never honors this env-var unset path.
if [ "${M032_WIKI_DEPLOY_BYPASS_CWD_GATE:-0}" != "1" ]; then
  if [ ! -f "$ROOT/wiki/mkdocs.yml" ]; then
    printf 'FAIL: wiki-deploy: FR-10 cwd-gate: %s/wiki/mkdocs.yml missing; cannot run cwd-vs-repo_url sanity gate\n' "$ROOT" >&2
    exit 1
  fi
  REPO_URL_LINE=$(grep -E '^repo_url:' "$ROOT/wiki/mkdocs.yml" | head -n 1)
  REPO_URL_VAL=$(printf '%s' "$REPO_URL_LINE" | sed -E 's/^repo_url:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')
  if [ -z "$REPO_URL_VAL" ]; then
    printf 'FAIL: wiki-deploy: FR-10 cwd-gate: cannot parse repo_url: from %s/wiki/mkdocs.yml\n' "$ROOT" >&2
    exit 1
  fi
  GIT_REMOTE_VAL=$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)
  if [ -z "$GIT_REMOTE_VAL" ]; then
    printf 'FAIL: wiki-deploy: FR-10 cwd-gate: no git remote at origin in %s\n' "$ROOT" >&2
    exit 1
  fi
  # Normalize both to <owner>/<repo> form. Strip .git, strip protocol/host prefixes.
  norm_repo() {
    printf '%s' "$1" | sed -E 's#^https?://github\.com/##; s#^git@github\.com:##; s#\.git$##; s#/$##'
  }
  REPO_URL_NORM=$(norm_repo "$REPO_URL_VAL")
  GIT_REMOTE_NORM=$(norm_repo "$GIT_REMOTE_VAL")
  # Owner-lower-case, repo-case-preserved (matches wiki-init.sh's P02 convention).
  REPO_URL_OWNER=$(printf '%s' "$REPO_URL_NORM" | awk -F/ '{print tolower($1)"/"$2}')
  GIT_REMOTE_OWNER=$(printf '%s' "$GIT_REMOTE_NORM" | awk -F/ '{print tolower($1)"/"$2}')
  if [ "$REPO_URL_OWNER" != "$GIT_REMOTE_OWNER" ]; then
    printf 'FAIL: wiki-deploy: cross-project hazard — mkdocs.yml repo_url=%s does not match git remote origin=%s; aborting before gh-deploy. cwd: %s\n' "$REPO_URL_VAL" "$GIT_REMOTE_VAL" "$ROOT" >&2
    exit 1
  fi
  printf 'GATE: cwd-vs-repo_url PASS (%s)\n' "$REPO_URL_OWNER"
fi
```

2. **Amend `scripts/lifecycle/wiki-init.sh`** to recognize `--deploy` and replace the P02-baseline reject-stub. After T01's `--with-giscus` block (or in parallel with T01 — see Description), add the `--deploy` workflow block AFTER T01's `--with-giscus` block and BEFORE the script's existing FR-15 glossary-stub authoring section. Required `--deploy` flag-parsing additions to the flag-parse loop (preserve T01's `--repo`, `--category` arms; add `--force-pages-reconfigure`):

```bash
FORCE_PAGES_RECONFIG=0
# (inside the existing while [ $# -gt 0 ]; do case "$1" in ... esac done loop, add new arm:)
    --force-pages-reconfigure)
      FORCE_PAGES_RECONFIG=1; shift ;;
```

Required `--deploy` workflow block (insert after T01's `--with-giscus` block; the block does NOT depend on `--with-giscus` having run — `--deploy` composes with the default scope OR with `--with-giscus`):

```bash
# FR-9 + MIT-007 + MIT-008 --deploy scope: four-step ordered sequence with
# read-before-write Pages guard and structured JSONL audit-trail.
if [ "$WITH_DEPLOY" = "1" ]; then
  # Parse owner/repo from the project's git remote (re-using the FR-5 logic
  # already executed earlier in this script — ORIGIN_URL / OWNER / REPO are
  # in scope). If --with-wiki was not on the command line, ORIGIN_URL is
  # already populated by the FR-5 block.

  # JSONL log path: <PROJECT_DIR>/.orchestrator/execution-log.jsonl
  # (initialized via mkdir -p .orchestrator/ if absent).
  LOG_DIR="$PROJECT_DIR/.orchestrator"
  LOG_FILE="$LOG_DIR/execution-log.jsonl"
  mkdir -p "$LOG_DIR"

  # Track which mutations actually fire so the audit-trail mutations array
  # reflects the truth on disk. Bash 3.2 — use parallel indexed strings, not
  # arrays of objects.
  MUT_DISCUSSIONS=0
  MUT_GH_PAGES_BRANCH=0
  MUT_PAGES_CONFIGURED=0

  iso_ts() {
    date -u +%Y-%m-%dT%H:%M:%SZ
  }

  # Step 1: enable Discussions via PATCH /repos/<owner>/<repo>.
  step1_rc=0
  case "${M032_DEPLOY_GH_API_STUB:-}" in
    1)
      # Stub mode — read fixture state from M032_DEPLOY_GH_API_STUB_DIR.
      step1_rc=0
      MUT_DISCUSSIONS=1
      ;;
    *)
      set +e
      gh api --method PATCH "/repos/$OWNER/$REPO" -f has_discussions=true >/dev/null 2>&1
      step1_rc=$?
      set -e
      if [ "$step1_rc" -eq 0 ]; then
        MUT_DISCUSSIONS=1
      fi
      ;;
  esac
  if [ "$step1_rc" -ne 0 ]; then
    audit_failure "discussions_enable" "$step1_rc"
    echo "FAIL: wiki-init: --deploy step 1: gh api PATCH /repos/$OWNER/$REPO has_discussions=true exited $step1_rc" >&2
    exit 10
  fi

  # Step 2: invoke wiki-deploy.sh (it runs the FR-10 cwd-gate + the four
  # P02-baseline gates + mkdocs gh-deploy --force).
  step2_rc=0
  case "${M032_DEPLOY_GH_API_STUB:-}" in
    1)
      # Stub mode — skip the deploy invocation entirely (no mkdocs install
      # required for hermetic verifier coverage).
      step2_rc=0
      MUT_GH_PAGES_BRANCH=1
      ;;
    *)
      set +e
      bash "$PROJECT_DIR/scripts/wiki/wiki-deploy.sh" --root "$PROJECT_DIR"
      step2_rc=$?
      set -e
      if [ "$step2_rc" -eq 0 ]; then
        MUT_GH_PAGES_BRANCH=1
      fi
      ;;
  esac
  if [ "$step2_rc" -ne 0 ]; then
    audit_failure "wiki_deploy" "$step2_rc"
    echo "FAIL: wiki-init: --deploy step 2: wiki-deploy.sh exited $step2_rc" >&2
    exit 11
  fi

  # Step 3: MIT-007 read-before-write Pages guard.
  # gh api GET /repos/<owner>/<repo>/pages — inspect .source.branch and .source.path.
  PAGES_RESP=""
  pages_get_rc=0
  case "${M032_DEPLOY_GH_API_STUB:-}" in
    1)
      # Stub mode — read fixture state from $M032_DEPLOY_GH_API_STUB_DIR/pages-get.json
      # (or default to "404 / no Pages configured" if file absent).
      if [ -n "${M032_DEPLOY_GH_API_STUB_DIR:-}" ] && [ -f "$M032_DEPLOY_GH_API_STUB_DIR/pages-get.json" ]; then
        PAGES_RESP="$(cat "$M032_DEPLOY_GH_API_STUB_DIR/pages-get.json")"
        pages_get_rc=0
      else
        PAGES_RESP=""
        pages_get_rc=1  # simulates 404 Not Found
      fi
      ;;
    *)
      set +e
      PAGES_RESP="$(gh api "/repos/$OWNER/$REPO/pages" 2>/dev/null)"
      pages_get_rc=$?
      set -e
      ;;
  esac

  PAGES_PUT_NEEDED=1
  if [ "$pages_get_rc" -eq 0 ] && [ -n "$PAGES_RESP" ]; then
    # Pages exist — inspect source.
    EXISTING_BRANCH=$(printf '%s' "$PAGES_RESP" | sed -n 's/.*"source":{[^}]*"branch":"\([^"]*\)".*/\1/p')
    EXISTING_PATH=$(printf '%s' "$PAGES_RESP" | sed -n 's/.*"source":{[^}]*"path":"\([^"]*\)".*/\1/p')
    if [ "$EXISTING_BRANCH" = "gh-pages" ] && [ "$EXISTING_PATH" = "/" ]; then
      # No-op: already configured for our target source.
      PAGES_PUT_NEEDED=0
      echo "wiki-init: --deploy step 3: pages-already-configured (gh-pages root) — skipping PUT"
    else
      # Incompatible source.
      if [ "$FORCE_PAGES_RECONFIG" -eq 1 ]; then
        echo "wiki-init: --deploy step 3: WARNING — overwriting existing Pages source ($EXISTING_BRANCH $EXISTING_PATH) per --force-pages-reconfigure" >&2
      else
        audit_failure "pages_guard" "$pages_get_rc"
        echo "FAIL: wiki-init: Repository has an existing Pages deployment from a different source ($EXISTING_BRANCH $EXISTING_PATH). This source will be overwritten. Pass --force-pages-reconfigure to proceed, or reconfigure Pages manually before running --deploy." >&2
        exit 12
      fi
    fi
  fi

  # Step 4: PUT /repos/<owner>/<repo>/pages (only if PAGES_PUT_NEEDED).
  if [ "$PAGES_PUT_NEEDED" -eq 1 ]; then
    step4_rc=0
    case "${M032_DEPLOY_GH_API_STUB:-}" in
      1)
        step4_rc=0
        MUT_PAGES_CONFIGURED=1
        ;;
      *)
        set +e
        gh api --method PUT "/repos/$OWNER/$REPO/pages" -f 'source[branch]=gh-pages' -f 'source[path]=/' >/dev/null 2>&1
        step4_rc=$?
        set -e
        if [ "$step4_rc" -eq 0 ]; then
          MUT_PAGES_CONFIGURED=1
        fi
        ;;
    esac
    if [ "$step4_rc" -ne 0 ]; then
      audit_failure "pages_put" "$step4_rc"
      echo "FAIL: wiki-init: --deploy step 4: gh api PUT /repos/$OWNER/$REPO/pages exited $step4_rc" >&2
      exit 13
    fi
  fi

  # Step 5: MIT-008 audit-trail append BEFORE live URL print.
  # NDJSON shape — one line, newline-terminated.
  TS="$(iso_ts)"
  MUTATIONS=""
  if [ "$MUT_DISCUSSIONS" -eq 1 ]; then
    MUTATIONS='{"type":"discussions_enabled"}'
  fi
  if [ "$MUT_GH_PAGES_BRANCH" -eq 1 ]; then
    MUTATIONS="${MUTATIONS:+$MUTATIONS,}"'{"type":"gh_pages_branch_created","ref":"gh-pages"}'
  fi
  if [ "$MUT_PAGES_CONFIGURED" -eq 1 ]; then
    MUTATIONS="${MUTATIONS:+$MUTATIONS,}"'{"type":"pages_source_configured","source":{"branch":"gh-pages","path":"/"}}'
  fi
  printf '{"event_type":"wiki-deploy-mutation","timestamp":"%s","repo":"%s/%s","mutations":[%s],"result":"success"}\n' \
    "$TS" "$OWNER" "$REPO" "$MUTATIONS" >> "$LOG_FILE"

  # Step 6: print live URL.
  OWNER_LOWER_DEPLOY="$(printf '%s' "$OWNER" | tr '[:upper:]' '[:lower:]')"
  printf 'https://%s.github.io/%s/\n' "$OWNER_LOWER_DEPLOY" "$REPO"
fi
```

The `audit_failure` helper (define earlier in the script, near other helpers):

```bash
audit_failure() {
  _step="$1"
  _rc="$2"
  _ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  _muts=""
  if [ "${MUT_DISCUSSIONS:-0}" -eq 1 ]; then
    _muts='{"type":"discussions_enabled"}'
  fi
  if [ "${MUT_GH_PAGES_BRANCH:-0}" -eq 1 ]; then
    _muts="${_muts:+$_muts,}"'{"type":"gh_pages_branch_created","ref":"gh-pages"}'
  fi
  if [ "${MUT_PAGES_CONFIGURED:-0}" -eq 1 ]; then
    _muts="${_muts:+$_muts,}"'{"type":"pages_source_configured","source":{"branch":"gh-pages","path":"/"}}'
  fi
  printf '{"event_type":"wiki-deploy-mutation","timestamp":"%s","repo":"%s/%s","mutations":[%s],"result":"failure","error":"%s: rc=%s"}\n' \
    "$_ts" "${OWNER:-unknown}" "${REPO:-unknown}" "$_muts" "$_step" "$_rc" >> "${LOG_FILE:-/dev/null}"
}
```

Update the file-header exit-code comment block to include the new exit codes 10–13:

```
#  10 — --deploy step 1 (gh api PATCH discussions=true) failed.
#  11 — --deploy step 2 (wiki-deploy.sh) failed.
#  12 — --deploy step 3 (MIT-007 Pages guard rejected incompatible source).
#  13 — --deploy step 4 (gh api PUT /pages) failed.
```

3. **Author `tools/verify/m032-p03-deploy-scope.sh`**. Hermetic stub-mode coverage of the FR-9 / MIT-007 / MIT-008 workflow against a tmpdir fixture. Three coverage branches: (a) happy path with no existing Pages → all three mutations recorded; (b) Pages already configured for `gh-pages` root → discussions + branch entries only (no `pages_source_configured` mutation, true no-op skip), audit record reflects truth; (c) Pages configured for incompatible source without `--force-pages-reconfigure` → exit 12 with diagnostic, partial-failure audit record present.

```bash
#!/usr/bin/env bash
# tools/verify/m032-p03-deploy-scope.sh — FR-9 + MIT-007 + MIT-008 verifier.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WI="$REPO_ROOT/scripts/lifecycle/wiki-init.sh"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# Static text checks for the FR-9 + MIT-007 + MIT-008 surface.
for tok in '--deploy' '--force-pages-reconfigure' 'M032_DEPLOY_GH_API_STUB' \
           'M032_DEPLOY_GH_API_STUB_DIR' 'wiki-deploy-mutation' \
           'discussions_enabled' 'gh_pages_branch_created' 'pages_source_configured' \
           'pages-already-configured' 'has_discussions=true' \
           'audit_failure' 'execution-log.jsonl' 'MIT-007' 'MIT-008' 'FR-9'; do
  if grep -qF "$tok" "$WI"; then
    say_pass "wiki-init.sh contains: $tok"
  else
    say_fail "wiki-init.sh missing: $tok"
  fi
done

# Hermetic stub-mode: happy path (no existing Pages).
TMPDIR_F=$(mktemp -d -t m032-p03-deploy.XXXXXX)
trap 'rm -rf "$TMPDIR_F"' EXIT
mkdir -p "$TMPDIR_F/.orchestrator"
(cd "$TMPDIR_F" && git init -q && git remote add origin https://github.com/fixture-owner/m032-p03-deploy.git)

M032_DEPLOY_GH_API_STUB=1 bash "$WI" --deploy --project-dir "$TMPDIR_F" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ] && [ -f "$TMPDIR_F/.orchestrator/execution-log.jsonl" ] && \
   grep -qF '"event_type":"wiki-deploy-mutation"' "$TMPDIR_F/.orchestrator/execution-log.jsonl" && \
   grep -qF '"result":"success"' "$TMPDIR_F/.orchestrator/execution-log.jsonl" && \
   grep -qF '"discussions_enabled"' "$TMPDIR_F/.orchestrator/execution-log.jsonl" && \
   grep -qF '"pages_source_configured"' "$TMPDIR_F/.orchestrator/execution-log.jsonl"; then
  say_pass "stub happy path: rc=0, audit record present with all three mutations"
else
  say_fail "stub happy path: rc=$rc; audit record absent or missing mutations"
fi

# Hermetic stub-mode: Pages already configured for gh-pages root → no-op skip-PUT.
STUB_DIR=$(mktemp -d -t m032-p03-deploy-stub.XXXXXX)
printf '{"source":{"branch":"gh-pages","path":"/"},"html_url":"https://example.github.io/x/"}' \
  > "$STUB_DIR/pages-get.json"
rm -f "$TMPDIR_F/.orchestrator/execution-log.jsonl"
M032_DEPLOY_GH_API_STUB=1 M032_DEPLOY_GH_API_STUB_DIR="$STUB_DIR" bash "$WI" --deploy --project-dir "$TMPDIR_F" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -qF '"discussions_enabled"' "$TMPDIR_F/.orchestrator/execution-log.jsonl" && \
   grep -qF '"gh_pages_branch_created"' "$TMPDIR_F/.orchestrator/execution-log.jsonl" && \
   ! grep -qF '"pages_source_configured"' "$TMPDIR_F/.orchestrator/execution-log.jsonl"; then
  say_pass "stub MIT-007 no-op: rc=0, audit record omits pages_source_configured (true no-op skip-PUT)"
else
  say_fail "stub MIT-007 no-op: rc=$rc; audit record shape unexpected"
fi
rm -rf "$STUB_DIR"

# Hermetic stub-mode: Pages incompatible source without --force-pages-reconfigure → exit 12.
STUB_DIR=$(mktemp -d -t m032-p03-deploy-incompat.XXXXXX)
printf '{"source":{"branch":"main","path":"/docs"},"html_url":"https://example.github.io/x/"}' \
  > "$STUB_DIR/pages-get.json"
rm -f "$TMPDIR_F/.orchestrator/execution-log.jsonl"
err_out="$(M032_DEPLOY_GH_API_STUB=1 M032_DEPLOY_GH_API_STUB_DIR="$STUB_DIR" bash "$WI" --deploy --project-dir "$TMPDIR_F" 2>&1)"
rc=$?
if [ "$rc" -eq 12 ] && \
   printf '%s' "$err_out" | grep -qF 'existing Pages deployment from a different source' && \
   grep -qF '"result":"failure"' "$TMPDIR_F/.orchestrator/execution-log.jsonl"; then
  say_pass "stub MIT-007 incompatible: rc=12, diagnostic emitted, failure audit record appended"
else
  say_fail "stub MIT-007 incompatible: rc=$rc; expected exit 12 + diagnostic + failure record"
fi
rm -rf "$STUB_DIR"

printf 'SUMMARY: m032-p03-deploy-scope pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

4. **Author `tools/verify/m032-p03-wiki-deploy-cwd-gate.sh`**. Two coverage branches: (a) gate fires on cwd / repo_url mismatch (`cross-project hazard` diagnostic + non-zero exit); (b) gate skipped under `M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1`.

```bash
#!/usr/bin/env bash
# tools/verify/m032-p03-wiki-deploy-cwd-gate.sh — FR-10 verifier.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WD="$REPO_ROOT/scripts/wiki/wiki-deploy.sh"
pass=0; fail=0
say_pass() { pass=$((pass + 1)); printf 'PASS: %s\n' "$1"; }
say_fail() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1" >&2; }

for tok in 'FR-10' 'cross-project hazard' 'cwd-vs-repo_url' 'repo_url' \
           'M032_WIKI_DEPLOY_BYPASS_CWD_GATE' 'GATE: cwd-vs-repo_url'; do
  if grep -qF "$tok" "$WD"; then
    say_pass "wiki-deploy.sh contains: $tok"
  else
    say_fail "wiki-deploy.sh missing: $tok"
  fi
done

# Hermetic mismatch fixture.
TMPDIR_F=$(mktemp -d -t m032-p03-cwd-gate.XXXXXX)
trap 'rm -rf "$TMPDIR_F"' EXIT
mkdir -p "$TMPDIR_F/wiki"
printf 'site_name: "fixture"\nrepo_url: "https://github.com/owner-A/repo-A"\n' > "$TMPDIR_F/wiki/mkdocs.yml"
(cd "$TMPDIR_F" && git init -q && git remote add origin https://github.com/owner-B/repo-B.git)

err_out="$(bash "$WD" --root "$TMPDIR_F" --dry-run 2>&1)"
rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$err_out" | grep -qF 'cross-project hazard'; then
  say_pass "FR-10 mismatch: rc=$rc with cross-project hazard diagnostic"
else
  say_fail "FR-10 mismatch: rc=$rc; expected non-zero with diagnostic"
fi

# Bypass override.
M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1 bash "$WD" --root "$TMPDIR_F" --dry-run >/dev/null 2>&1
rc_bypass=$?
# rc_bypass may still be non-zero (mkdocs not installed in the tmpdir), but
# it should NOT be a FR-10 cwd-gate failure. Distinguish by checking stderr:
err_out="$(M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1 bash "$WD" --root "$TMPDIR_F" --dry-run 2>&1 || true)"
if printf '%s' "$err_out" | grep -qF 'cross-project hazard'; then
  say_fail "FR-10 bypass: cross-project-hazard fired despite M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1"
else
  say_pass "FR-10 bypass: cross-project-hazard skipped under M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1"
fi

printf 'SUMMARY: m032-p03-wiki-deploy-cwd-gate pass=%d fail=%d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
```

5. **Make verifier scripts executable**: `chmod +x tools/verify/m032-p03-deploy-scope.sh tools/verify/m032-p03-wiki-deploy-cwd-gate.sh`.

## Must-Haves

- FR-10 cwd-vs-`repo_url:` sanity gate on `wiki-deploy.sh` with `cross-project hazard` diagnostic and `M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1` test-only bypass
- FR-9 + MIT-007 + MIT-008 `--deploy` scope on `wiki-init.sh` (four-step ordered sequence; read-before-write Pages guard with `--force-pages-reconfigure` escape hatch; structured `wiki-deploy-mutation` JSONL audit-trail record append BEFORE live URL print, with mutations-array reflecting actual fired steps and a failure-mode `result: "failure"` record + named error step)
- Two project-owned verifiers: `tools/verify/m032-p03-deploy-scope.sh`, `tools/verify/m032-p03-wiki-deploy-cwd-gate.sh`

## Verification

```bash
bash tools/verify/m032-p03-deploy-scope.sh
```

```bash
bash tools/verify/m032-p03-wiki-deploy-cwd-gate.sh
```

## Notes

Expected output of each verifier: the final line is `SUMMARY: <name> pass=<N> fail=0` and exit code is 0.

The live `--deploy` workflow is exercised end-to-end ONLY by SC-5 (T04 deliverable) against a throwaway GH repo per CON-5 / `tests/m032-acceptance/throwaway-fixture-protocol.md`. T02's verifiers cover stub-mode hermetic branches; the full live-network coverage is T04's job.

The `M032_DEPLOY_GH_API_STUB` env-var follows the M026/MEM030 `<TOOL>_*` env-var convention. The operator-facing surface MUST NOT honor this var unset path implicitly; it is test-only. The `M032_DEPLOY_GH_API_STUB_DIR` companion env-var lets verifiers parameterize the stubbed `gh api GET /pages` response to exercise MIT-007 branches (404, gh-pages-root, incompatible-source).

The audit-trail JSONL append is INTENTIONAL even on partial failure (a `result: "failure"` record is appended with the failed step name and stderr-tail). This makes operator-visible the difference between "deploy never started" (no record) and "deploy started and failed at step X" (failure record). Constitution VI (State On Disk Is Truth) — remote-state mutations have an on-disk audit trail.

Bash 3.2 gotcha for the JSONL emit: the `mutations` array is built as a literal-string concatenation rather than a structured JSON-array-builder because bash 3.2 lacks `declare -A` and structured serialization libraries. The `${MUTATIONS:+$MUTATIONS,}` expansion is a parameter-expansion-safe way to elide the leading comma when the prior mutation set is empty.

## Inputs

### From Previous Tasks

(none from within P03 — T02 is independent of T01/T03/T04; depends only on P02 artifacts; T01 and T02 modify non-overlapping sections of `wiki-init.sh`)

### From Disk (Pre-existing)

- `scripts/lifecycle/wiki-init.sh` (P02/T01) — bash 3.2 default-scope script. T02 amends it to add `--deploy` handling and the `audit_failure` helper. T01 (in parallel) adds `--with-giscus` handling. The two amendments live at non-overlapping line ranges.
- `scripts/wiki/wiki-deploy.sh` (M012 baseline) — chained deploy wrapper. T02 inserts the FR-10 gate-0 block at line ~93 (after the `cd "$ROOT"` line, before "gate 1"). The existing four gates are NOT modified.
- `wiki/mkdocs.yml` (P02/T01) — carries `repo_url:` field that the FR-10 gate parses.
- `scripts/diagnostics/giscus-ids-from-gh.sh`, `scripts/diagnostics/wiki-giscus-config-check.sh` — read-only references; T02 does NOT modify either (T01's domain).
- `tests/fixtures/m032-fresh-project-fixture/` (P01) — referenced for context only; T02's verifiers use ephemeral tmpdir fixtures.

## Constraints

- Single-script-file shape for ALL verifier `Check:` commands per AD-19.
- bash 3.2 compatibility (per MEM001) — NDJSON shape built via `printf` literal-string concatenation; no `declare -A`; no process substitution; no command substitution containing pipes (use `sed -n` chains and intermediate variables).
- Verifier scripts MUST live under `tools/verify/` with the `m032-p03-*` prefix per AD-19 path discipline.
- No modifications to P02-owned files (`commands/init.md`, `scripts/lifecycle/init-project.sh`, `wiki/glossary.md`, `scripts/wiki/wiki-scan-sources.sh`, `scripts/knowledge/lookup-mems.sh`, the paired-launch seam scripts) or P01-owned files (`packaging/install/install-*.sh`, `packaging/bundle/manifest.yml`, `tests/fixtures/m032-fresh-project-fixture/.gitignore`).
- The `audit_failure` helper MUST be defined ONCE in `wiki-init.sh` (early, near other helpers); failure-paths in step 1, step 2, step 3, step 4 ALL invoke it.
- The MIT-008 audit-trail JSONL append is the LAST action before printing the live URL on success — order is load-bearing per the spec ("MUST be appended before the live URL is printed to stdout"). The verifier MUST exercise this ordering invariant (the verifier's grep for the audit record runs AFTER `wiki-init.sh` has exited, so any URL-print-before-record race would surface as a missing record).
- Co-author the two verifier scripts within T02 — do NOT defer them to T05 per plan-time discipline rule 2. T05 only authors the phase-suite + scope-guard.

## Expected Output

After T02 completes:

- `scripts/wiki/wiki-deploy.sh` carries the FR-10 gate-0 block, fires on cwd / repo_url mismatch, can be bypassed under `M032_WIKI_DEPLOY_BYPASS_CWD_GATE=1`.
- `scripts/lifecycle/wiki-init.sh` recognizes `--deploy --force-pages-reconfigure` and implements the four-step FR-9 / MIT-007 / MIT-008 sequence with audit-trail append.
- `tools/verify/m032-p03-deploy-scope.sh` and `tools/verify/m032-p03-wiki-deploy-cwd-gate.sh` exist and exit 0.
- The three `Check:` commands listed in P03-PLAN.md's "Truths" section for T02-owned truths return exit 0.
