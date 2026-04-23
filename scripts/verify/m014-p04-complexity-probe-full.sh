#!/usr/bin/env bash
# Gate: T02 — full FR-5 complexity probe body.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROBE="${PROJECT_ROOT}/scripts/knowledge/spec-complexity-probe.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -x "$PROBE" ] || fail "probe not executable"

# 1. Hardening-spec → below-threshold.
HS_SPEC="${PROJECT_ROOT}/specs/016-autonomous-hardening/spec.md"
if [ -f "$HS_SPEC" ]; then
  OUT="$(CLAUDE_CODE_RUNTIME=0 SPEC_COMPLEXITY_PROBE_LLM=0 bash "$PROBE" "$HS_SPEC" 2>/dev/null)"
  echo "$OUT" | grep -qE '^probe=below-threshold' || fail "M016 expected below-threshold, got: $OUT"
fi

# 2. Large spec → above-threshold on heuristic.
BIG_SPEC="${PROJECT_ROOT}/specs/024-spec-management-extended/spec.md"
if [ -f "$BIG_SPEC" ]; then
  OUT="$(CLAUDE_CODE_RUNTIME=0 SPEC_COMPLEXITY_PROBE_LLM=0 bash "$PROBE" "$BIG_SPEC" 2>/dev/null)"
  echo "$OUT" | grep -qE '^probe=above-threshold reason=' || fail "M024 expected above-threshold, got: $OUT"
fi

# 3. Structured fields on stderr.
STDERR_FILE="$(mktemp)"
CLAUDE_CODE_RUNTIME=0 SPEC_COMPLEXITY_PROBE_LLM=0 bash "$PROBE" "$BIG_SPEC" >/dev/null 2> "$STDERR_FILE"
grep -qE '^fr_count=[0-9]+' "$STDERR_FILE"              || { rm -f "$STDERR_FILE"; fail "stderr missing fr_count"; }
grep -qE '^user_story_count=[0-9]+' "$STDERR_FILE"      || { rm -f "$STDERR_FILE"; fail "stderr missing user_story_count"; }
grep -qE '^todo_count=[0-9]+' "$STDERR_FILE"            || { rm -f "$STDERR_FILE"; fail "stderr missing todo_count"; }
grep -qE '^contradiction_signals=0' "$STDERR_FILE"      || { rm -f "$STDERR_FILE"; fail "stderr contradiction_signals!=0 under non-CC"; }
rm -f "$STDERR_FILE"

# 4. Trivial scratch spec → below-threshold.
SCRATCH="$(mktemp -d)"
TRIV="${SCRATCH}/trivial.md"
cat > "$TRIV" <<'SPEC'
# Feature Specification: Trivial
## Problem Statement
A tiny spec.
## Functional Requirements
- **FR-1 (solo)**: One requirement.
## Success Criteria
- SC-1: Works.
SPEC
OUT="$(CLAUDE_CODE_RUNTIME=0 SPEC_COMPLEXITY_PROBE_LLM=0 bash "$PROBE" "$TRIV" 2>/dev/null)"
echo "$OUT" | grep -qE '^probe=below-threshold' || { rm -rf "$SCRATCH"; fail "trivial expected below-threshold, got: $OUT"; }
rm -rf "$SCRATCH"

# 5. Missing-arg case.
bash "$PROBE" >/dev/null 2>&1
if [ $? -eq 0 ]; then fail "probe with no args exited 0 (expected non-zero)"; fi

# 6. Missing-path case.
bash "$PROBE" /tmp/does-not-exist-p04.md >/dev/null 2>&1
if [ $? -eq 0 ]; then fail "probe missing path exited 0"; fi

# 7. P01 stub language removed (the exact P01 stub line was "echo \"probe=below-threshold\"" as the unconditional emit; the full body must contain "above-threshold" as a literal string).
grep -qF 'above-threshold' "$PROBE" || fail "probe body missing above-threshold literal — P01 stub not fully replaced"
grep -qF 'contradiction_signals=' "$PROBE" || fail "probe body missing contradiction_signals= emission"

echo "PASS: complexity-probe full body verified"
exit 0
