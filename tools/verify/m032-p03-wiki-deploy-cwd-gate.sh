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
