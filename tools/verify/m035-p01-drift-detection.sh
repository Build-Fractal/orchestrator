#!/usr/bin/env bash
# tools/verify/m035-p01-drift-detection.sh
# M035 P01 T03 must-have (SC-3 path): assert that
# scripts/state/check-orchestrator-drift.sh emits commits_behind=14
# (and versions_behind=N + update_source=git) against a controlled
# fixture consumer + fixture upstream git repo.
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.
# This verifier owns its own fixture upstream-repo creation: it
# stages two mktemp -d trees (consumer + upstream), seeds the
# upstream with a known number of commits past the recorded
# commit_sha, then exercises the helper.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HELPER="$REPO_ROOT/scripts/state/check-orchestrator-drift.sh"
FIXTURE_SRC="$REPO_ROOT/tests/m035-acceptance/fixtures/install-meta-with-sha.txt"

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

# --- Stage fixture consumer ---
mkdir -p "$CONSUMER_TREE/.orchestrator"
cp "$FIXTURE_SRC" "$CONSUMER_TREE/.orchestrator/install-meta.txt"

# --- Stage fixture upstream git repo ---
# Seed: 1 initial commit (this is the recorded commit_sha) + 14 more
# commits past it. After the initial commit we rewrite install-meta.txt
# with the resolved initial-commit SHA so the helper sees a SHA that
# actually exists in the fixture upstream.
cd "$UPSTREAM_TREE"
git init -q .
git config user.email "fixture@example.test"
git config user.name "fixture"
git config commit.gpgsign false
echo "# fixture upstream" > README.md
git add README.md
git -c commit.gpgsign=false commit -q -m "initial"
INITIAL_SHA="$(git rev-parse HEAD)"

# Seed CHANGELOG.md so the helper's versions_behind comparison works.
# Fixture install-meta records version=0.9.0; upstream advertises 0.9.3
# → versions_behind=3.
cat > CHANGELOG.md <<'EOF'
# Changelog

## [0.9.3] — fixture upstream

- forward
EOF
git add CHANGELOG.md
git -c commit.gpgsign=false commit -q -m "changelog"

# 13 more padding commits → 14 commits past INITIAL_SHA total
i=1
while [ "$i" -le 13 ]; do
  echo "$i" > "pad-$i.txt"
  git add "pad-$i.txt"
  git -c commit.gpgsign=false commit -q -m "pad $i"
  i=$((i + 1))
done

# Rewrite the consumer's install-meta.txt commit_sha to point at
# INITIAL_SHA so `rev-list --count INITIAL_SHA..HEAD` resolves to 14.
META="$CONSUMER_TREE/.orchestrator/install-meta.txt"
TMP="$(mktemp)"
awk -v sha="$INITIAL_SHA" -F= '
  /^commit_sha=/ { print "commit_sha=" sha; next }
  { print }
' "$META" > "$TMP"
mv "$TMP" "$META"

# --- Stage consumer config.yml pointing at fixture upstream ---
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

if ! grep -q '^commits_behind=14$' "$OUT_FILE"; then
  echo "FAIL: stdout missing 'commits_behind=14'" >&2
  echo "--- stdout ---" >&2
  cat "$OUT_FILE" >&2
  echo "--- end ---" >&2
  fail=1
fi

if ! grep -q '^versions_behind=' "$OUT_FILE"; then
  echo "FAIL: stdout missing 'versions_behind=' line" >&2
  fail=1
fi

if ! grep -q '^update_source=git$' "$OUT_FILE"; then
  echo "FAIL: stdout missing 'update_source=git'" >&2
  fail=1
fi

if ! grep -q '^upstream_path=' "$OUT_FILE"; then
  echo "FAIL: stdout missing 'upstream_path=' line" >&2
  fail=1
fi

# Cleanup tmp output files.
rm -f "$OUT_FILE" "$ERR_FILE"

if [ "$fail" -eq 0 ]; then
  echo "PASS: m035-p01-drift-detection"
  exit 0
fi
exit 1
