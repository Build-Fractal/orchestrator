#!/usr/bin/env bash
# tools/verify/m035-p06-update-run-jsonl-emission-shape.sh
#
# M035 P06 T03 — Asserts the update_run JSONL emission in run-update.sh:
#   1. emit_update_run_event helper present
#   2. resolve_target_version helper present
#   3. --no-emit-jsonl flag present
#   4. ORCHESTRATOR_AUTO env var referenced
#   5. defensive update_source=none guard inside emission helper
#   6. update_run literal token referenced in >= 3 positions
#   7. JSONL template line carries six required fields
#   8. DECISIONS.md contains D013 anchor
#   9. --dry-run yields no observability/ dir (dry-run short-circuits)
#  10. --no-emit-jsonl yields no observability/ dir (suppression 1)
#  11. ORCHESTRATOR_AUTO=1 yields no observability/ dir (suppression 2)
#  12. clean dispatch yields exactly one update_run event in <today>.jsonl
#
# AD-19 single-script-file shape; runs against staged fixtures under
# /tmp/m035-p06-t03-emission-fixture-$$/. Bash 3.2 + POSIX-sh-safe.

set -u

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
DRIVER="$REPO/scripts/lifecycle/run-update.sh"
DECISIONS="$REPO/.orchestrator/DECISIONS.md"

# shellcheck disable=SC1091
. "$REPO/scripts/lib/errors.sh"

FIXTURE_ROOT="/tmp/m035-p06-t03-emission-fixture-$$"
mkdir -p "$FIXTURE_ROOT"

cleanup() {
  rm -rf "$FIXTURE_ROOT"
}
trap cleanup EXIT

pass=0
fail=0

# --- Assertion 1: emit_update_run_event helper present ---
if grep -qF 'emit_update_run_event' "$DRIVER"; then
  echo "PASS: run-update.sh contains emit_update_run_event helper"
  pass=$((pass + 1))
else
  echo "FAIL: run-update.sh missing emit_update_run_event helper"
  fail=$((fail + 1))
fi

# --- Assertion 2: resolve_target_version helper present ---
if grep -qF 'resolve_target_version' "$DRIVER"; then
  echo "PASS: run-update.sh contains resolve_target_version helper"
  pass=$((pass + 1))
else
  echo "FAIL: run-update.sh missing resolve_target_version helper"
  fail=$((fail + 1))
fi

# --- Assertion 3: --no-emit-jsonl flag present ---
if grep -qF -- '--no-emit-jsonl' "$DRIVER"; then
  echo "PASS: run-update.sh references --no-emit-jsonl flag"
  pass=$((pass + 1))
else
  echo "FAIL: run-update.sh missing --no-emit-jsonl flag"
  fail=$((fail + 1))
fi

# --- Assertion 4: ORCHESTRATOR_AUTO env var referenced ---
if grep -qF 'ORCHESTRATOR_AUTO' "$DRIVER"; then
  echo "PASS: run-update.sh references ORCHESTRATOR_AUTO env var"
  pass=$((pass + 1))
else
  echo "FAIL: run-update.sh missing ORCHESTRATOR_AUTO env var reference"
  fail=$((fail + 1))
fi

# --- Assertion 5: emit_update_run_event carries defensive update_source=none guard ---
# Match the helper's defensive guard pattern: $source_val = "none".
if grep -qF '"$source_val" = "none"' "$DRIVER"; then
  echo "PASS: emit_update_run_event carries defensive update_source=none guard"
  pass=$((pass + 1))
else
  echo "FAIL: emit_update_run_event missing defensive update_source=none guard"
  fail=$((fail + 1))
fi

# --- Assertion 6: update_run literal token in >= 3 positions ---
ur_count=0
ur_count="$(grep -c 'update_run' "$DRIVER")"
if [ "$ur_count" -ge 3 ]; then
  echo "PASS: run-update.sh references update_run in >= 3 positions"
  pass=$((pass + 1))
else
  echo "FAIL: run-update.sh references update_run only $ur_count times (need >= 3)"
  fail=$((fail + 1))
fi

# --- Assertion 7: JSONL template line carries all six required fields ---
template_ok=1
if ! grep -qF '"event":"update_run"' "$DRIVER"; then
  template_ok=0
fi
if ! grep -qF '"op":"update"' "$DRIVER"; then
  template_ok=0
fi
if ! grep -qF '"source":' "$DRIVER"; then
  template_ok=0
fi
if ! grep -qF '"target_version":' "$DRIVER"; then
  template_ok=0
fi
if ! grep -qF '"result":' "$DRIVER"; then
  template_ok=0
fi
if ! grep -qF '"timestamp":' "$DRIVER"; then
  template_ok=0
fi
if [ "$template_ok" -eq 1 ]; then
  echo "PASS: JSONL template line carries all six required fields"
  pass=$((pass + 1))
else
  echo "FAIL: JSONL template line missing one of event/op/source/target_version/result/timestamp"
  fail=$((fail + 1))
fi

# --- Assertion 8: DECISIONS.md contains D013 anchor ---
d013_anchor=""
d013_anchor="$(grep -nE '^### D013( |$)' "$DECISIONS" | head -1)"
if [ -n "$d013_anchor" ]; then
  echo "PASS: DECISIONS.md contains D013 anchor"
  pass=$((pass + 1))
else
  echo "FAIL: DECISIONS.md missing D013 heading-shape anchor"
  fail=$((fail + 1))
fi

# --- Stage a stub source repo so source-repo validation passes for git fixture --
# run-update.sh resolves SOURCE_REPO via ORCHESTRATOR_SOURCE_REPO env var.
# The git arm requires:
#   - $SOURCE_REPO directory exists
#   - $SOURCE_REPO/packaging/install/install-claude-code.sh exists (file)
# It does NOT require $SOURCE_REPO/.git for the non-rollback path.
STUB_SRC="$FIXTURE_ROOT/stub-source"
mkdir -p "$STUB_SRC/packaging/install"
mkdir -p "$STUB_SRC/packaging/bundle"
STUB_INSTALLER="$STUB_SRC/packaging/install/install-claude-code.sh"
{
  printf '#!/usr/bin/env bash\n'
  printf 'exit 0\n'
} > "$STUB_INSTALLER"
chmod +x "$STUB_INSTALLER"
{
  printf 'version: "0.0.0-stub"\n'
} > "$STUB_SRC/packaging/bundle/manifest.yml"

# --- Assertion 9: --dry-run yields no observability/ dir ---
DRY_DIR="$FIXTURE_ROOT/dry"
mkdir -p "$DRY_DIR/.orchestrator"
printf 'update_source: git\n' > "$DRY_DIR/.orchestrator/config.yml"
dry_out="$FIXTURE_ROOT/dry.out"
dry_err="$FIXTURE_ROOT/dry.err"
ORCHESTRATOR_SOURCE_REPO="$STUB_SRC" \
  bash "$DRIVER" --project-dir "$DRY_DIR" --dry-run \
    >"$dry_out" 2>"$dry_err" || true
if [ ! -d "$DRY_DIR/.orchestrator/observability" ]; then
  echo "PASS: --dry-run yields no observability/ dir (dry-run short-circuits)"
  pass=$((pass + 1))
else
  echo "FAIL: --dry-run unexpectedly created observability/ dir"
  fail=$((fail + 1))
fi

# --- Assertion 10: --no-emit-jsonl yields no observability/ dir ---
SUP1_DIR="$FIXTURE_ROOT/sup1"
mkdir -p "$SUP1_DIR/.orchestrator"
printf 'update_source: git\n' > "$SUP1_DIR/.orchestrator/config.yml"
sup1_out="$FIXTURE_ROOT/sup1.out"
sup1_err="$FIXTURE_ROOT/sup1.err"
ORCHESTRATOR_SOURCE_REPO="$STUB_SRC" \
  bash "$DRIVER" --project-dir "$SUP1_DIR" --no-emit-jsonl \
    >"$sup1_out" 2>"$sup1_err" || true
if [ ! -d "$SUP1_DIR/.orchestrator/observability" ]; then
  echo "PASS: --no-emit-jsonl yields no observability/ dir (suppression 1)"
  pass=$((pass + 1))
else
  echo "FAIL: --no-emit-jsonl unexpectedly created observability/ dir"
  fail=$((fail + 1))
fi

# --- Assertion 11: ORCHESTRATOR_AUTO=1 yields no observability/ dir ---
SUP2_DIR="$FIXTURE_ROOT/sup2"
mkdir -p "$SUP2_DIR/.orchestrator"
printf 'update_source: git\n' > "$SUP2_DIR/.orchestrator/config.yml"
sup2_out="$FIXTURE_ROOT/sup2.out"
sup2_err="$FIXTURE_ROOT/sup2.err"
ORCHESTRATOR_SOURCE_REPO="$STUB_SRC" \
  ORCHESTRATOR_AUTO=1 \
  bash "$DRIVER" --project-dir "$SUP2_DIR" \
    >"$sup2_out" 2>"$sup2_err" || true
if [ ! -d "$SUP2_DIR/.orchestrator/observability" ]; then
  echo "PASS: ORCHESTRATOR_AUTO=1 yields no observability/ dir (suppression 2)"
  pass=$((pass + 1))
else
  echo "FAIL: ORCHESTRATOR_AUTO=1 unexpectedly created observability/ dir"
  fail=$((fail + 1))
fi

# --- Assertion 12: clean dispatch yields exactly one update_run event ---
CLEAN_DIR="$FIXTURE_ROOT/clean"
mkdir -p "$CLEAN_DIR/.orchestrator"
printf 'update_source: git\n' > "$CLEAN_DIR/.orchestrator/config.yml"
clean_out="$FIXTURE_ROOT/clean.out"
clean_err="$FIXTURE_ROOT/clean.err"
ORCHESTRATOR_SOURCE_REPO="$STUB_SRC" \
  bash "$DRIVER" --project-dir "$CLEAN_DIR" \
    >"$clean_out" 2>"$clean_err" || true
clean_today=""
clean_today="$(date -u +%Y-%m-%d)"
clean_jsonl="$CLEAN_DIR/.orchestrator/observability/$clean_today.jsonl"
clean_ok=1
if [ ! -f "$clean_jsonl" ]; then
  clean_ok=0
fi
if [ "$clean_ok" -eq 1 ]; then
  ev_count=0
  ev_count="$(grep -c '"event":"update_run"' "$clean_jsonl")"
  if [ "$ev_count" -ne 1 ]; then
    clean_ok=0
  fi
fi
if [ "$clean_ok" -eq 1 ]; then
  if ! grep -qF '"op":"update"' "$clean_jsonl"; then
    clean_ok=0
  fi
fi
if [ "$clean_ok" -eq 1 ]; then
  if ! grep -qF '"source":"git"' "$clean_jsonl"; then
    clean_ok=0
  fi
fi
if [ "$clean_ok" -eq 1 ]; then
  if ! grep -qE '"timestamp":"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"' "$clean_jsonl"; then
    clean_ok=0
  fi
fi
if [ "$clean_ok" -eq 1 ]; then
  echo "PASS: clean dispatch yields exactly one update_run event in <today>.jsonl"
  pass=$((pass + 1))
else
  echo "FAIL: clean dispatch did not yield exactly one well-formed update_run event"
  if [ -f "$clean_jsonl" ]; then
    sed 's/^/  jsonl: /' "$clean_jsonl"
  else
    echo "  jsonl: <missing at $clean_jsonl>"
  fi
  sed 's/^/  out: /' "$clean_out"
  sed 's/^/  err: /' "$clean_err"
  fail=$((fail + 1))
fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
