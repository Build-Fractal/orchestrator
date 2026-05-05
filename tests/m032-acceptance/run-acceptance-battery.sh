#!/usr/bin/env bash
# tests/m032-acceptance/run-acceptance-battery.sh
# M032/P04/T04 — SC-12 acceptance battery runner.
#
# Invokes every M032 SC verifier in literal sequence per AD-19
# single-script-file shape (each verifier invoked as `bash <path>`
# with rc captured per-call; no compound chains, no loops over the
# invocations, no eval). Mirrors the M030/M031 lineage at
# tests/m030-acceptance/run-acceptance-battery.sh and
# tests/m031-acceptance/run-acceptance-battery.sh and extends with
# the MIT-001 three-category exit-code semantics:
#
#   rc == 0   → pass++   (BATTERY-PASS line)
#   rc == 77  → skip++   (BATTERY-SKIP line; POSIX skip-code per MIT-001)
#   other     → fail++   (BATTERY-FAIL line)
#
# Final stdout line: `BATTERY: pass=N skip=M fail=K`.
# Exits 0 iff fail==0; non-zero if fail>0.
#
# The skip=1 case (SC-5 unauthenticated CI) is acceptable for
# milestone close ONLY with the M032-SUMMARY.md signed-attestation
# block (that gate enforced by T05's milestone-close-ceremony
# verifier, not by this script).
#
# Sub-gate inventory (11 entries):
#   SC-1, SC-2, SC-3, SC-4, SC-5, SC-6, SC-7, SC-8, SC-9, SC-10, SC-11
#
# Test-only env-var:
#   M032_ACCEPTANCE_BATTERY_DRY=1 — bypasses real SC invocations and
#   emits a synthetic BATTERY-SKIP per slot so shape verification can
#   exercise the eleven-count without exercising every real SC.
#
# Bash 3.2 compatible (parallel scalars, `local` inside the helper, no
# associative arrays, no process substitution). The runner only
# INVOKES existing P01..P04 SC scripts — zero modifications to upstream
# deliverables.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass=0
skip=0
fail=0

run_sc() {
  # $1 SC label  $2 verifier path  $3 (optional) trailing flags
  local label="$1"
  local path="$2"
  local extra="${3:-}"

  # Test-only dry-mode escape hatch: when M032_ACCEPTANCE_BATTERY_DRY=1,
  # emit a synthetic skip without invoking the verifier (used by
  # m032-p04-acceptance-battery-shape.sh for shape verification
  # without exercising every real SC).
  if [ -n "${M032_ACCEPTANCE_BATTERY_DRY:-}" ]; then
    skip=$((skip + 1))
    printf 'BATTERY-SKIP: %s (%s) SKIP_REASON: dry-mode\n' "$label" "$path"
    return
  fi

  if [ ! -x "$path" ]; then
    fail=$((fail + 1))
    printf 'BATTERY-FAIL: %s (%s) verifier missing or non-executable\n' "$label" "$path"
    return
  fi

  if [ -n "$extra" ]; then
    bash "$path" $extra
  else
    bash "$path"
  fi
  local rc=$?

  if [ "$rc" -eq 0 ]; then
    pass=$((pass + 1))
    printf 'BATTERY-PASS: %s (%s)\n' "$label" "$path"
  elif [ "$rc" -eq 77 ]; then
    skip=$((skip + 1))
    printf 'BATTERY-SKIP: %s (%s) SKIP_REASON: exit 77\n' "$label" "$path"
  else
    fail=$((fail + 1))
    printf 'BATTERY-FAIL: %s (%s) exited %d\n' "$label" "$path" "$rc"
  fi
}

# ---------- P01 SCs (managed bundle + symlink + staged-dirs collision) ----------
run_sc "SC-1"  "$PROJECT_ROOT/tests/m032-acceptance/p01-managed-bundle-shape.sh"
run_sc "SC-2"  "$PROJECT_ROOT/tests/m032-acceptance/p01-symlink-mode.sh"
run_sc "SC-10" "$PROJECT_ROOT/tests/m032-acceptance/p01-staged-dirs-collision.sh"

# ---------- P02 SCs (wiki-init default scope + glossary surface) ----------
run_sc "SC-3"  "$PROJECT_ROOT/tests/m032-acceptance/p02-wiki-init-default-scope.sh"
run_sc "SC-7"  "$PROJECT_ROOT/tests/m032-acceptance/p02-glossary-surface.sh"

# ---------- P03 SCs (giscus + deploy-live + custom-nav region) ----------
# SC-4/SC-6 acceptance scripts retain the spec-text `p02-` prefix even
# though they were authored in P03 (per the M032 roadmap continuity
# note). The battery references the on-disk paths verbatim.
run_sc "SC-4"  "$PROJECT_ROOT/tests/m032-acceptance/p02-wiki-init-with-giscus.sh"
run_sc "SC-5"  "$PROJECT_ROOT/tests/m032-acceptance/p03-wiki-init-deploy-live.sh"
run_sc "SC-6"  "$PROJECT_ROOT/tests/m032-acceptance/p02-wiki-generate-nav-custom-region.sh"

# ---------- P04 SCs (scanner extensions + code decorator + doctor-no-warnings) ----------
run_sc "SC-8"  "$PROJECT_ROOT/tests/m032-acceptance/p0X-scanner-extensions.sh"
run_sc "SC-9"  "$PROJECT_ROOT/tests/m032-acceptance/p0X-code-decorator.sh"
run_sc "SC-11" "$PROJECT_ROOT/tests/m032-acceptance/sc11-doctor-no-warnings.sh"

# ---------- Aggregate ----------
printf 'BATTERY: pass=%s skip=%s fail=%s\n' "$pass" "$skip" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
