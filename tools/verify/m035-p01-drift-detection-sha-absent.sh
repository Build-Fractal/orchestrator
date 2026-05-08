#!/usr/bin/env bash
# tools/verify/m035-p01-drift-detection-sha-absent.sh
# M035 P01 T03 must-have (SC-3b fallback): assert that
# scripts/state/check-orchestrator-drift.sh emits commits_behind=unknown
# + the documented stderr advisory + versions_behind=0 against the
# pre-M035 install-meta.txt fixture (no commit_sha, no version).
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="$REPO_ROOT/scripts/state/check-orchestrator-drift.sh"
FIXTURE_SRC="$REPO_ROOT/tests/m035-acceptance/fixtures/install-meta-pre-m035.txt"

if [ ! -f "$HELPER" ]; then
  echo "FAIL: helper not found at $HELPER" >&2
  exit 1
fi
if [ ! -f "$FIXTURE_SRC" ]; then
  echo "FAIL: fixture not found at $FIXTURE_SRC" >&2
  exit 1
fi

CONSUMER_TREE="$(mktemp -d)"
UPSTREAM_TREE="$(mktemp -d)"
cleanup() {
  rm -rf "$CONSUMER_TREE" "$UPSTREAM_TREE"
}
trap cleanup EXIT

# --- Stage fixture consumer with the pre-M035 install-meta shape ---
mkdir -p "$CONSUMER_TREE/.orchestrator"
cp "$FIXTURE_SRC" "$CONSUMER_TREE/.orchestrator/install-meta.txt"

# --- Stage a minimal fixture upstream (just to give the helper a path
#     it can stat). The helper still falls into the SHA-absent branch
#     before doing any rev-list math, so an empty git repo suffices. ---
cd "$UPSTREAM_TREE"
git init -q .
git config user.email "fixture@example.test"
git config user.name "fixture"
git config commit.gpgsign false
echo "# fixture upstream" > README.md
git add README.md
git -c commit.gpgsign=false commit -q -m "initial"

# A CHANGELOG with a real semver — but install-meta has no version=
# so the helper's versions_behind diff branch should not run, leaving
# versions_behind=0.
cat > CHANGELOG.md <<'EOF'
# Changelog

## [0.9.3] — fixture upstream
EOF

cat > "$CONSUMER_TREE/.orchestrator/config.yml" <<EOF
update_source: git
update_upstream_path: $UPSTREAM_TREE
EOF

# --- Run the helper ---
OUT_FILE="$(mktemp)"
ERR_FILE="$(mktemp)"
bash "$HELPER" --consumer "$CONSUMER_TREE" >"$OUT_FILE" 2>"$ERR_FILE"
RC=$?

fail=0

if [ "$RC" -ne 0 ]; then
  echo "FAIL: helper exit code $RC (expected 0)" >&2
  fail=1
fi

if ! grep -q '^commits_behind=unknown$' "$OUT_FILE"; then
  echo "FAIL: stdout missing 'commits_behind=unknown'" >&2
  echo "--- stdout ---" >&2
  cat "$OUT_FILE" >&2
  echo "--- end ---" >&2
  fail=1
fi

if ! grep -q '^versions_behind=0$' "$OUT_FILE"; then
  echo "FAIL: stdout missing 'versions_behind=0'" >&2
  fail=1
fi

# Stderr advisory: exactly one line, matching the documented pattern.
advisory_lines="$(grep -c 'pre-M035 install' "$ERR_FILE" || true)"
if [ "$advisory_lines" != "1" ]; then
  echo "FAIL: stderr advisory count expected 1, got $advisory_lines" >&2
  echo "--- stderr ---" >&2
  cat "$ERR_FILE" >&2
  echo "--- end ---" >&2
  fail=1
fi

rm -f "$OUT_FILE" "$ERR_FILE"

if [ "$fail" -eq 0 ]; then
  echo "PASS: m035-p01-drift-detection-sha-absent"
  exit 0
fi
exit 1
