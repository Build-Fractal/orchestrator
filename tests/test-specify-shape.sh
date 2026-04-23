#!/usr/bin/env bash
# tests/test-specify-shape.sh — FR-18 byte-compat fixture test.
# Asserts scripts/specify/specify.sh produces a spec.md whose section-heading
# list byte-matches the derivation from templates/spec-template.md, passes
# spec-shape-lint.sh, and passes detect-spec-shape.sh with shape=speckit.
# Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TEMPLATE="${PROJECT_ROOT}/templates/spec-template.md"
EXPECTED_HEADINGS="${PROJECT_ROOT}/tests/fixtures/m014-p01/expected-section-headings.txt"
FIXTURE_PROSE="${PROJECT_ROOT}/tests/fixtures/m014-p01/specify-fixture-prose.txt"
SPECIFY="${PROJECT_ROOT}/scripts/specify/specify.sh"
SHAPE_LINT="${PROJECT_ROOT}/scripts/verify/spec-shape-lint.sh"
SHAPE_DETECT="${PROJECT_ROOT}/scripts/knowledge/detect-spec-shape.sh"
DUAL_WRITE="${PROJECT_ROOT}/scripts/util/dual-write-runtime-md.sh"
PROBE="${PROJECT_ROOT}/scripts/knowledge/spec-complexity-probe.sh"

for f in "$TEMPLATE" "$EXPECTED_HEADINGS" "$FIXTURE_PROSE" "$SPECIFY" "$SHAPE_LINT" "$SHAPE_DETECT" "$DUAL_WRITE" "$PROBE"; do
  if [ ! -e "$f" ]; then
    echo "FAIL: upstream artifact missing: $f" >&2
    exit 1
  fi
done

# Hermetic scratch project.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

mkdir -p "$SCRATCH/.orchestrator" "$SCRATCH/templates" "$SCRATCH/scripts/util" "$SCRATCH/scripts/specify" "$SCRATCH/scripts/knowledge" "$SCRATCH/scripts/verify" "$SCRATCH/scripts/lifecycle" "$SCRATCH/specs" "$SCRATCH/tests/fixtures/m014-p01"

cp "$TEMPLATE" "$SCRATCH/templates/"
cp "$DUAL_WRITE" "$SCRATCH/scripts/util/"
cp "$SPECIFY" "$SCRATCH/scripts/specify/"
cp "$PROBE" "$SCRATCH/scripts/knowledge/"
cp "$SHAPE_LINT" "$SCRATCH/scripts/verify/"
if [ -f "$PROJECT_ROOT/scripts/lifecycle/lock-manager.sh" ]; then
  cp "$PROJECT_ROOT/scripts/lifecycle/lock-manager.sh" "$SCRATCH/scripts/lifecycle/"
fi
cp "$FIXTURE_PROSE" "$SCRATCH/tests/fixtures/m014-p01/"
cp "$EXPECTED_HEADINGS" "$SCRATCH/tests/fixtures/m014-p01/"

cat > "$SCRATCH/.orchestrator/config.yml" <<'EOF'
schema_version: "1.0"
dual_write_agents: true
EOF

cat > "$SCRATCH/CLAUDE.md" <<'EOF'
# CLAUDE.md fixture
EOF

FIXTURE_TEXT="$(cat "$FIXTURE_PROSE")"

# --- Dry-run exercise ---
DRY_OUT="$(bash "$SCRATCH/scripts/specify/specify.sh" --description "$FIXTURE_TEXT" --slug specify-fixture --yes --dry-run 2>&1)"
DRY_RC=$?
if [ $DRY_RC -ne 0 ]; then
  echo "FAIL: --dry-run exited non-zero (rc=$DRY_RC)" >&2
  echo "$DRY_OUT" >&2
  exit 1
fi
if ! echo "$DRY_OUT" | grep -qE '"action_type":"scaffold-spec"'; then
  echo "FAIL: --dry-run missing scaffold-spec manifest record" >&2
  echo "$DRY_OUT" >&2
  exit 1
fi

# --- Live run ---
cd "$SCRATCH"
WRITTEN="$(bash "$SCRATCH/scripts/specify/specify.sh" --description "$FIXTURE_TEXT" --slug specify-fixture --yes 2>&1 | tail -1)"
cd "$PROJECT_ROOT"

if [ ! -f "$WRITTEN" ]; then
  echo "FAIL: specify.sh live run did not produce spec.md at $WRITTEN" >&2
  exit 1
fi

# --- Section-heading byte-match against expected ---
# Expected headings include the literal `{{feature_title}}` and `<TODO: ...>`
# placeholders. The scaffolder has substituted `{{feature_title}}` with the
# actual slug; so compare after normalizing both streams.
ACTUAL="$(mktemp)"
EXP_NORM="$(mktemp)"
grep -E '^#+[[:space:]]' "$WRITTEN" > "$ACTUAL"
sed -e 's/{{[^}]*}}/__PLACEHOLDER__/g' "$EXPECTED_HEADINGS" > "$EXP_NORM"
# Normalize the scaffolded `# Feature Specification: <title>` line to match
# the placeholder form in the expected fixture. BSD sed (macOS) requires an
# argument after `-i`; GNU sed does not. Use the no-`-i` pattern for portability.
sed -e 's/^# Feature Specification:.*/# Feature Specification: __PLACEHOLDER__/' "$ACTUAL" > "${ACTUAL}.norm"
mv "${ACTUAL}.norm" "$ACTUAL"

if ! diff -q "$EXP_NORM" "$ACTUAL" >/dev/null 2>&1; then
  echo "FAIL: scaffolded section headings diverge from expected" >&2
  diff "$EXP_NORM" "$ACTUAL" >&2 || true
  rm -f "$ACTUAL" "$EXP_NORM"
  exit 1
fi
rm -f "$ACTUAL" "$EXP_NORM"

# --- spec-shape-lint passes ---
if ! bash "$SHAPE_LINT" "$WRITTEN" >/dev/null 2>&1; then
  echo "FAIL: spec-shape-lint.sh failed on scaffolded spec" >&2
  bash "$SHAPE_LINT" "$WRITTEN" >&2 || true
  exit 1
fi

# --- SC-2 I/O-contract: detect-spec-shape reports shape=speckit ---
SHAPE_OUT="$(bash "$SHAPE_DETECT" --spec-path "$WRITTEN" 2>/dev/null)"
if ! echo "$SHAPE_OUT" | grep -qE '^shape=speckit'; then
  echo "FAIL: detect-spec-shape.sh did not report shape=speckit; got: $SHAPE_OUT" >&2
  exit 1
fi

echo "PASS: tests/test-specify-shape.sh"
exit 0
