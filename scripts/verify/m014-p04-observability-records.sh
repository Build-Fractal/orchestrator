#!/usr/bin/env bash
# Gate: T07 — observability record shape (FR-16 producer discipline).
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SPECIFY="${PROJECT_ROOT}/scripts/specify/specify.sh"
PROBE="${PROJECT_ROOT}/scripts/knowledge/spec-complexity-probe.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

SCRATCH="$(mktemp -d)"
mkdir -p "${SCRATCH}/.orchestrator"
cp "${PROJECT_ROOT}/.orchestrator/config.yml" "${SCRATCH}/.orchestrator/config.yml"
touch "${SCRATCH}/CLAUDE.md"
LOG="${SCRATCH}/.orchestrator/execution-log.jsonl"

# Hermetic: route probe + specify.sh observability writes to SCRATCH via env override.
export ORCHESTRATOR_PROJECT_ROOT="$SCRATCH"

# 1. Scaffold-path run (writes spec_complexity_probe + unit_close).
cd "$SCRATCH"
bash "$SPECIFY" --description "Small trivial description" --slug obs-test --yes >/dev/null 2>&1

# 2. Probe run on a scratch spec (writes another spec_complexity_probe).
SCRATCH_SPEC="${SCRATCH}/scratch-spec.md"
cat > "$SCRATCH_SPEC" <<'S'
# Feature Specification: Scratch
## Functional Requirements
- FR-1: one
- FR-2: two
S
bash "$PROBE" "$SCRATCH_SPEC" >/dev/null 2>&1 || true

# Inspect scratch log.
if [ ! -f "$LOG" ]; then
  rm -rf "$SCRATCH"
  fail "scratch execution-log.jsonl not created"
fi

# Required record types emitted by runtime.
grep -qF '"type":"unit_close"' "$LOG" || { rm -rf "$SCRATCH"; fail "unit_close record missing in scratch log"; }
grep -qF '"type":"spec_complexity_probe"' "$LOG" || { rm -rf "$SCRATCH"; fail "spec_complexity_probe record missing"; }

# unit_close record extensions.
grep -qF 'conversus_invocations' "$LOG" || { rm -rf "$SCRATCH"; fail "unit_close missing conversus_invocations field"; }
grep -qF 'adapter_verdicts' "$LOG" || { rm -rf "$SCRATCH"; fail "unit_close missing adapter_verdicts field"; }

# JSONL validity: every non-blank line is a balanced JSON object.
while IFS= read -r jline; do
  case "$jline" in
    "") continue ;;
  esac
  case "$jline" in
    '{'*'}') ;;
    *)
      rm -rf "$SCRATCH"
      fail "malformed JSONL line: $jline"
      ;;
  esac
done < "$LOG"

# conversus_gate_invocation emission verified via source grep (end-to-end y-path is
# three-way-prompt gate's job; requires TTY / stub orchestration out of scope here).
# specify.sh emits the record via a printf with escaped quotes, so grep for the
# bare literal (\"type\":\"conversus_gate_invocation\" in source).
grep -qF 'conversus_gate_invocation' "$SPECIFY" \
  || { rm -rf "$SCRATCH"; fail "specify.sh body missing conversus_gate_invocation emission"; }

rm -rf "$SCRATCH"
echo "PASS: observability record shape verified"
exit 0
