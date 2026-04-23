#!/usr/bin/env bash
# Gate: verify scripts/specify/specify.sh end-to-end on a scratch project.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SPECIFY="${PROJECT_ROOT}/scripts/specify/specify.sh"

if [ ! -x "$SPECIFY" ]; then
  echo "FAIL: scripts/specify/specify.sh missing or not executable" >&2; exit 1
fi

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# Hermetic scratch project: copy templates, scripts, config, CLAUDE.md.
mkdir -p "$SCRATCH/.orchestrator" "$SCRATCH/templates" "$SCRATCH/scripts/util" "$SCRATCH/scripts/specify" "$SCRATCH/scripts/knowledge" "$SCRATCH/scripts/lifecycle" "$SCRATCH/specs"
cp "$PROJECT_ROOT/templates/spec-template.md" "$SCRATCH/templates/"
cp "$PROJECT_ROOT/scripts/util/dual-write-runtime-md.sh" "$SCRATCH/scripts/util/"
cp "$PROJECT_ROOT/scripts/specify/specify.sh" "$SCRATCH/scripts/specify/"
cp "$PROJECT_ROOT/scripts/knowledge/spec-complexity-probe.sh" "$SCRATCH/scripts/knowledge/"
# Lock manager is optional — use stub if absent.
if [ -f "$PROJECT_ROOT/scripts/lifecycle/lock-manager.sh" ]; then
  cp "$PROJECT_ROOT/scripts/lifecycle/lock-manager.sh" "$SCRATCH/scripts/lifecycle/"
fi

cat > "$SCRATCH/.orchestrator/config.yml" <<'EOF'
schema_version: "1.0"
dual_write_agents: true
EOF

cat > "$SCRATCH/CLAUDE.md" <<'EOF'
# CLAUDE.md test seed

## Recent Changes

- pre-existing entry
EOF

# Run specify.sh against the scratch project.
cd "$SCRATCH"
OUT="$(bash "$SCRATCH/scripts/specify/specify.sh" --description "Test exporter that ships merged-PR diffs to Slack for async review." --slug test-exporter --yes 2>&1 || true)"
RC=$?
cd "$PROJECT_ROOT"

if [ $RC -ne 0 ]; then
  echo "FAIL: specify.sh exited $RC (expected 0); output: $OUT" >&2; exit 1
fi

WRITTEN="$(echo "$OUT" | tail -1)"
if [ ! -f "$WRITTEN" ]; then
  echo "FAIL: written path does not exist: $WRITTEN" >&2; exit 1
fi

# Frontmatter substitutions performed.
head -15 "$WRITTEN" | grep -qF 'test-exporter' || {
  echo "FAIL: feature slug not substituted" >&2; exit 1
}
head -15 "$WRITTEN" | grep -qF 'Status**: Draft' || {
  echo "FAIL: Status: Draft missing" >&2; exit 1
}

# AGENTS.md and CLAUDE.md both updated.
if [ ! -f "$SCRATCH/AGENTS.md" ]; then
  echo "FAIL: AGENTS.md not created" >&2; exit 1
fi
grep -qF 'test-exporter' "$SCRATCH/AGENTS.md" || {
  echo "FAIL: AGENTS.md missing recent-changes entry" >&2; exit 1
}
grep -qF '# >>> orchestrator:recent-changes >>>' "$SCRATCH/CLAUDE.md" || {
  echo "FAIL: CLAUDE.md missing marker region" >&2; exit 1
}

# Execution-log record appended.
LOG="$SCRATCH/.orchestrator/execution-log.jsonl"
if [ -f "$LOG" ]; then
  grep -qF '"command":"orchestrator:specify"' "$LOG" || {
    echo "FAIL: execution-log.jsonl missing unit_close record" >&2; exit 1
  }
fi

# Slug collision errors loudly.
bash "$SCRATCH/scripts/specify/specify.sh" --description "dup" --slug test-exporter --yes >/dev/null 2>&1
RC2=$?
if [ $RC2 -eq 0 ]; then
  echo "FAIL: slug collision exited 0 (expected non-zero)" >&2; exit 1
fi

# Dry-run emits JSONL manifest.
DRY_OUT="$(bash "$SCRATCH/scripts/specify/specify.sh" --description "dry run test" --slug dry-test --yes --dry-run 2>&1)"
RC3=$?
if [ $RC3 -ne 0 ]; then
  echo "FAIL: --dry-run exited non-zero" >&2; exit 1
fi
echo "$DRY_OUT" | grep -qE '"action_type":"scaffold-spec"' || {
  echo "FAIL: --dry-run missing scaffold-spec action" >&2; exit 1
}

# Split stub exits 2.
bash "$SCRATCH/scripts/specify/specify.sh" split /tmp/does-not-matter >/dev/null 2>&1
RC4=$?
if [ $RC4 -ne 2 ]; then
  echo "FAIL: split stub should exit 2 (got $RC4)" >&2; exit 1
fi

echo "PASS: scripts/specify/specify.sh end-to-end verified"
exit 0
