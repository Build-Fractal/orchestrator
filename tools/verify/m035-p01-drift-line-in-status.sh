#!/usr/bin/env bash
# tools/verify/m035-p01-drift-line-in-status.sh
# M035 P01 T04 must-have (SC-4 primary path): assert that
# scripts/diagnostics/render-status-json.sh emits a `drift` top-level
# object whose `rendered_line` matches the byte-stable drift-line shape
# documented at references/status-headline-shape.md § Drift Line
# (M035 P01).
#
# Stages a fixture orchestrator-root + fixture upstream git repo
# (mirrors tools/verify/m035-p01-drift-detection.sh's pattern), copies
# the SC-3 SHA-bearing install-meta.txt, writes config.yml pointing at
# the fixture upstream, then runs the JSON renderer with
# --orchestrator-root pointed at the fixture's .orchestrator/ tree.
#
# Asserts:
#   - JSON envelope is parseable and schema_version == "1.0".
#   - `.drift.update_source == "git"`.
#   - `.drift.commits_behind` is numeric (not "unknown") and > 0.
#   - `.drift.rendered_line` matches the SC-4 drift-line regex
#     `^STALE: orchestrator runtime is .+$`.
#   - The three byte-stable headline fields (milestone_id,
#     phase_index, lock_state) are present (M029 SC-2 contract
#     preservation).
#
# Single-script-file shape per AD-19. Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RENDER="$REPO_ROOT/scripts/diagnostics/render-status-json.sh"
HELPER="$REPO_ROOT/scripts/state/check-orchestrator-drift.sh"
FIXTURE_SRC="$REPO_ROOT/tests/m035-acceptance/fixtures/install-meta-with-sha.txt"
M029_FIXTURE_SRC="$REPO_ROOT/tests/m029-acceptance/fixtures/status-json-executing.fixture"

if [ ! -f "$RENDER" ]; then
  echo "FAIL: renderer not found at $RENDER" >&2
  exit 1
fi
if [ ! -f "$HELPER" ]; then
  echo "FAIL: drift helper not found at $HELPER" >&2
  exit 1
fi
if [ ! -f "$FIXTURE_SRC" ]; then
  echo "FAIL: install-meta fixture not found at $FIXTURE_SRC" >&2
  exit 1
fi
if [ ! -d "$M029_FIXTURE_SRC" ]; then
  echo "FAIL: M029 milestone fixture not found at $M029_FIXTURE_SRC" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: jq not on PATH" >&2
  exit 1
fi

CONSUMER_TREE="$(mktemp -d)"
UPSTREAM_TREE="$(mktemp -d)"
cleanup() {
  rm -rf "$CONSUMER_TREE" "$UPSTREAM_TREE"
}
trap cleanup EXIT

# --- Stage fixture consumer = M029 milestone fixture + .orchestrator/ ---
# render-status-json.sh roots its drift helper at the orchestrator-root's
# parent (the project root that owns .orchestrator/). We stage:
#   $CONSUMER_TREE/.orchestrator/install-meta.txt
#   $CONSUMER_TREE/.orchestrator/config.yml
#   $CONSUMER_TREE/.orchestrator/milestones/...   (from the M029 fixture)
mkdir -p "$CONSUMER_TREE/.orchestrator"
cp "$FIXTURE_SRC" "$CONSUMER_TREE/.orchestrator/install-meta.txt"

# Copy the M029 fixture's milestones tree into the consumer's
# .orchestrator/milestones/ so the renderer has a milestone to render.
cp -R "$M029_FIXTURE_SRC/milestones" "$CONSUMER_TREE/.orchestrator/milestones"

# --- Stage fixture upstream git repo ---
cd "$UPSTREAM_TREE"
git init -q .
git config user.email "fixture@example.test"
git config user.name "fixture"
git config commit.gpgsign false
echo "# fixture upstream" > README.md
git add README.md
git -c commit.gpgsign=false commit -q -m "initial"
INITIAL_SHA="$(git rev-parse HEAD)"

cat > CHANGELOG.md <<'EOF'
# Changelog

## [0.9.3] — fixture upstream

- forward
EOF
git add CHANGELOG.md
git -c commit.gpgsign=false commit -q -m "changelog"

i=1
while [ "$i" -le 13 ]; do
  echo "$i" > "pad-$i.txt"
  git add "pad-$i.txt"
  git -c commit.gpgsign=false commit -q -m "pad $i"
  i=$((i + 1))
done

# Rewrite consumer's install-meta.txt commit_sha to fixture INITIAL_SHA.
META="$CONSUMER_TREE/.orchestrator/install-meta.txt"
TMP_META="$(mktemp)"
awk -v sha="$INITIAL_SHA" -F= '
  /^commit_sha=/ { print "commit_sha=" sha; next }
  { print }
' "$META" > "$TMP_META"
mv "$TMP_META" "$META"

# --- Stage consumer config.yml pointing at fixture upstream ---
cat > "$CONSUMER_TREE/.orchestrator/config.yml" <<EOF
update_source: git
update_upstream_path: $UPSTREAM_TREE
EOF

# --- Run the JSON renderer ---
OUT_FILE="$(mktemp)"
ERR_FILE="$(mktemp)"
bash "$RENDER" --orchestrator-root "$CONSUMER_TREE/.orchestrator" --milestone M999 \
    >"$OUT_FILE" 2>"$ERR_FILE"
RC=$?

fail=0

if [ "$RC" -ne 0 ]; then
  echo "FAIL: renderer exit code $RC (expected 0)" >&2
  echo "--- stderr ---" >&2
  cat "$ERR_FILE" >&2
  echo "--- end ---" >&2
  fail=1
fi

# Parseable JSON.
if ! jq empty "$OUT_FILE" >/dev/null 2>&1; then
  echo "FAIL: stdout is not parseable JSON" >&2
  echo "--- stdout ---" >&2
  cat "$OUT_FILE" >&2
  echo "--- end ---" >&2
  fail=1
fi

# schema_version stable.
if ! jq -e '.schema_version == "1.0"' "$OUT_FILE" >/dev/null 2>&1; then
  echo "FAIL: schema_version is not \"1.0\" (AD-7 stability violation)" >&2
  fail=1
fi

# .drift.update_source == git.
if ! jq -e '.drift.update_source == "git"' "$OUT_FILE" >/dev/null 2>&1; then
  echo "FAIL: .drift.update_source != \"git\"" >&2
  fail=1
fi

# .drift.commits_behind is numeric and > 0.
if ! jq -e '(.drift.commits_behind | tonumber? // -1) > 0' "$OUT_FILE" >/dev/null 2>&1; then
  echo "FAIL: .drift.commits_behind not numeric or not > 0" >&2
  echo "  observed: $(jq -r '.drift.commits_behind' "$OUT_FILE")" >&2
  fail=1
fi

# .drift.rendered_line matches the byte-stable drift-line regex.
if ! jq -e '.drift.rendered_line | test("^STALE: orchestrator runtime is [0-9]+ commits behind upstream — run `orchestrator:update`$")' "$OUT_FILE" >/dev/null 2>&1; then
  echo "FAIL: .drift.rendered_line does not match drift-line regex" >&2
  echo "  observed: $(jq -r '.drift.rendered_line' "$OUT_FILE")" >&2
  fail=1
fi

# M029 SC-2 contract preservation: headline fields still present.
for key in milestone_id milestone_name phase_index phase_count lock_state ; do
  if ! jq -e --arg k "$key" '. | has($k)' "$OUT_FILE" >/dev/null 2>&1; then
    echo "FAIL: M029 contract violation -- missing top-level key .$key" >&2
    fail=1
  fi
done

rm -f "$OUT_FILE" "$ERR_FILE"

if [ "$fail" -eq 0 ]; then
  echo "PASS: m035-p01-drift-line-in-status"
  exit 0
fi
exit 1
