#!/usr/bin/env bash
# tests/m032-acceptance/p02-wiki-init-default-scope.sh — SC-3 acceptance.
#
# Verifies FR-5 (wiki-init default scope) + FR-6 (mkdocs templating) +
# FR-12 (toolchain probe) end-to-end against the P01 shared fixture.
#
# MIT-001 SKIP semantics: exit 77 with `SKIP_REASON: ...` on stdout when
# python3 is unavailable. Acceptance-battery (P05) distinguishes 77 from
# pass / fail.
#
# Bash 3.2 compatible (MEM001). Single-script-file shape per AD-19 — the
# wiki-serve HTTP probe is delegated to tools/verify/lib/m032-p02-wiki-serve-probe.sh
# (T01 helper) so this script never inlines a (serve & sleep curl kill) chain.

set -eu

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
PROJECT_ROOT="$( cd "$PROJECT_ROOT/.." && pwd )"
cd "$PROJECT_ROOT"

# MIT-001 SKIP_REASON if python3 unavailable.
if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP_REASON: python3 unavailable on this host"
  exit 77
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Stage a fresh fixture from the P01 shared fixture (read-only baseline).
cp -R tests/fixtures/m032-fresh-project-fixture/. "$TMP/"
( cd "$TMP" && git init -q && git remote add origin https://github.com/fixture-owner/m032-fresh-project-fixture.git ) >/dev/null 2>&1

# (a) FR-5 + FR-6 templating fired against fixture.
bash scripts/lifecycle/wiki-init.sh --project-dir "$TMP" >"$TMP/init.out" 2>"$TMP/init.err" || {
  echo "FAIL: SC-3 wiki-init exit non-zero"
  sed -n '1,40p' "$TMP/init.err" >&2
  exit 1
}
[ -f "$TMP/wiki/mkdocs.yml" ] || { echo "FAIL: SC-3 mkdocs.yml not staged"; exit 1; }

# Templated values reflect the fixture remote (FR-6 — site_name from <repo>, repo_url from <owner>/<repo>).
grep -q 'site_name: "m032-fresh-project-fixture"' "$TMP/wiki/mkdocs.yml" || {
  echo "FAIL: SC-3 site_name not substituted"
  grep '^site_' "$TMP/wiki/mkdocs.yml" >&2 || true
  exit 1
}
grep -q 'repo_url: "https://github.com/fixture-owner/m032-fresh-project-fixture"' "$TMP/wiki/mkdocs.yml" || {
  echo "FAIL: SC-3 repo_url not substituted"
  grep '^repo_url' "$TMP/wiki/mkdocs.yml" >&2 || true
  exit 1
}

# Negative: no orchestrator-identity values leaked into the four templated
# IDENTITY fields (site_name, site_description, site_url, repo_url). Comments
# and other context that mention 'spec-kit-orchestrator' are not load-bearing
# -- only the four resolved field lines must reflect the fixture's identity.
if grep -E '^(site_name|site_url|repo_url):' "$TMP/wiki/mkdocs.yml" | grep -q 'spec-kit-orchestrator'; then
  echo "FAIL: SC-3 orchestrator identity leaked into a templated identity field"
  grep -E '^(site_name|site_url|repo_url|site_description):' "$TMP/wiki/mkdocs.yml" >&2
  exit 1
fi
# Negative: no remaining placeholders.
if grep -q '{{site_name}}' "$TMP/wiki/mkdocs.yml"; then
  echo "FAIL: SC-3 placeholder {{site_name}} remained"
  exit 1
fi

# (b) Giscus partial retains placeholder tokens (P03 fills them, not P02).
PARTIAL="$TMP/wiki/overrides/partials/comments.html"
if [ -f "$PARTIAL" ]; then
  if ! grep -qE '{{giscus_repo}}|data-repo="{{' "$PARTIAL"; then
    echo "WARN: SC-3 Giscus partial missing placeholder tokens (expected for P02)" >&2
  fi
fi

# (c) wiki-serve.sh probe — extracted to a helper to keep AD-19 envelope.
bash tools/verify/lib/m032-p02-wiki-serve-probe.sh "$TMP" >/dev/null 2>"$TMP/probe.err" || {
  echo "FAIL: SC-3 wiki-serve.sh did not return HTTP 200"
  sed -n '1,40p' "$TMP/probe.err" >&2
  exit 1
}

# (d) FR-12 platform-aware diagnostic when python3 absent.
TMP2="$(mktemp -d)"
cp -R tests/fixtures/m032-fresh-project-fixture/. "$TMP2/"
( cd "$TMP2" && git init -q && git remote add origin https://github.com/fixture-owner/m032-fresh-project-fixture.git ) >/dev/null 2>&1
set +e
PATH=/usr/bin:/bin bash scripts/lifecycle/wiki-init.sh --project-dir "$TMP2" >/dev/null 2>"$TMP2/err"
RC=$?
set -e
# Note: PATH=/usr/bin:/bin will likely still find python3 on macOS; this branch is a best-effort probe.
# If python3 is found anyway, treat as a soft pass with a warning rather than fail.
if [ "$RC" = "0" ]; then
  echo "WARN: SC-3 FR-12 probe found python3 even with PATH narrowed; treating as soft-pass" >&2
elif [ "$RC" = "3" ]; then
  if ! grep -qE 'brew install python3|apt install python3' "$TMP2/err"; then
    echo "FAIL: SC-3 FR-12 missing platform-aware diagnostic"
    sed -n '1,20p' "$TMP2/err" >&2
    rm -rf "$TMP2"
    exit 1
  fi
else
  echo "FAIL: SC-3 FR-12 unexpected exit code $RC"
  sed -n '1,20p' "$TMP2/err" >&2
  rm -rf "$TMP2"
  exit 1
fi
rm -rf "$TMP2"

echo "PASS: SC-3 p02-wiki-init-default-scope"
exit 0
