#!/usr/bin/env bash
# Gate: T04 — three-way (y/n/d) prompt wiring + conversus adapter invocation.
#
# Hermetic: copies specify.sh + its dependencies into a scratch workdir and
# invokes from there so PROJECT_ROOT resolves inside the scratch. Never mutates
# the live repo's specs/ or .orchestrator/.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

SPECIFY_SRC="${PROJECT_ROOT}/scripts/specify/specify.sh"
PROBE_SRC="${PROJECT_ROOT}/scripts/knowledge/spec-complexity-probe.sh"
DUAL_WRITE_SRC="${PROJECT_ROOT}/scripts/util/dual-write-runtime-md.sh"
TEMPLATE_SRC="${PROJECT_ROOT}/templates/spec-template.md"
ADAPTER_SRC="${PROJECT_ROOT}/scripts/dispatch/adapters/tool/conversus.sh"
PRESET_SRC="${PROJECT_ROOT}/templates/conversus-presets/spec-pressure-test.yml"
LOCK_MGR_SRC="${PROJECT_ROOT}/scripts/lifecycle/lock-manager.sh"
GATE_PASS_SRC="${PROJECT_ROOT}/tests/fixtures/gate-result-pass.md"
GATE_BLOCK_SRC="${PROJECT_ROOT}/tests/fixtures/gate-result-block.md"
CONFIG_SRC="${PROJECT_ROOT}/.orchestrator/config.yml"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -x "$SPECIFY_SRC" ]    || fail "specify.sh not executable"
[ -x "$PROBE_SRC" ]      || fail "spec-complexity-probe.sh not executable"
[ -x "$DUAL_WRITE_SRC" ] || fail "dual-write-runtime-md.sh not executable"
[ -f "$TEMPLATE_SRC" ]   || fail "spec-template.md missing"
[ -x "$ADAPTER_SRC" ]    || fail "conversus.sh adapter missing"

# Scratch project.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

mkdir -p "${SCRATCH}/.orchestrator"
mkdir -p "${SCRATCH}/specs"
mkdir -p "${SCRATCH}/templates"
mkdir -p "${SCRATCH}/templates/conversus-presets"
mkdir -p "${SCRATCH}/scripts/specify"
mkdir -p "${SCRATCH}/scripts/knowledge"
mkdir -p "${SCRATCH}/scripts/util"
mkdir -p "${SCRATCH}/scripts/dispatch/adapters/tool"
mkdir -p "${SCRATCH}/scripts/lifecycle"
mkdir -p "${SCRATCH}/tests/fixtures"

cp "$SPECIFY_SRC"       "${SCRATCH}/scripts/specify/specify.sh"
cp "$PROBE_SRC"         "${SCRATCH}/scripts/knowledge/spec-complexity-probe.sh"
cp "$DUAL_WRITE_SRC"    "${SCRATCH}/scripts/util/dual-write-runtime-md.sh"
cp "$TEMPLATE_SRC"      "${SCRATCH}/templates/spec-template.md"
cp "$ADAPTER_SRC"       "${SCRATCH}/scripts/dispatch/adapters/tool/conversus.sh"
if [ -f "$PRESET_SRC" ]; then
  cp "$PRESET_SRC"      "${SCRATCH}/templates/conversus-presets/spec-pressure-test.yml"
fi
if [ -x "$LOCK_MGR_SRC" ]; then
  cp "$LOCK_MGR_SRC"    "${SCRATCH}/scripts/lifecycle/lock-manager.sh"
fi
if [ -f "$GATE_PASS_SRC" ]; then
  cp "$GATE_PASS_SRC"   "${SCRATCH}/tests/fixtures/gate-result-pass.md"
fi
if [ -f "$GATE_BLOCK_SRC" ]; then
  cp "$GATE_BLOCK_SRC"  "${SCRATCH}/tests/fixtures/gate-result-block.md"
fi

if [ -f "$CONFIG_SRC" ]; then
  cp "$CONFIG_SRC" "${SCRATCH}/.orchestrator/config.yml"
else
  cat > "${SCRATCH}/.orchestrator/config.yml" <<'EOF'
schema_version: "1.0"
dual_write_agents: true
EOF
fi

touch "${SCRATCH}/CLAUDE.md"

SPECIFY="${SCRATCH}/scripts/specify/specify.sh"

# Large contradictory prose to trip above-threshold on fr_count.
PROSE=""
i=1
while [ "$i" -le 20 ]; do
  PROSE="${PROSE}FR-${i} requirement alpha; "
  i=$((i+1))
done
PROSE="${PROSE}The command must prompt interactively and must never prompt interactively."

# --yes auto-selects n → above-threshold but no conversus invocation.
cd "$SCRATCH"
bash "$SPECIFY" --description "$PROSE" --slug yn-test --yes >/dev/null 2>&1
RC=$?
if [ "$RC" -ne 0 ]; then fail "specify --yes failed rc=$RC"; fi
# Expect no conversus/ output dir under --yes (default n).
for d in "${SCRATCH}/specs"/*-yn-test; do
  if [ -d "${d}/conversus" ]; then
    fail "conversus/ dir created under --yes (expected default n, no invocation)"
  fi
done

# --dry-run on above-threshold fires invoke-conversus-gate record.
OUT="$(CONVERSUS_STUB=1 CONVERSUS_STUB_VERDICT=PASS bash "$SPECIFY" --description "$PROSE" --slug dryrun-test --yes --dry-run 2>/dev/null)"
echo "$OUT" | grep -qF 'invoke-conversus-gate' || fail "--dry-run missing invoke-conversus-gate record for above-threshold (or probe shape unexpected)"

# Observability: unit_close record has conversus_invocations field.
LOG="${SCRATCH}/.orchestrator/execution-log.jsonl"
if [ ! -f "$LOG" ]; then fail "execution-log.jsonl not created"; fi
grep -qF 'conversus_invocations' "$LOG" || fail "unit_close record missing conversus_invocations field"

# spec_complexity_probe record emitted at least once.
grep -qF 'spec_complexity_probe' "$LOG" || fail "spec_complexity_probe record missing"

echo "PASS: three-way prompt wiring verified"
exit 0
