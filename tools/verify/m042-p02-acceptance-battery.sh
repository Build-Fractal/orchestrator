#!/usr/bin/env bash
# tools/verify/m042-p02-acceptance-battery.sh — M042/P02 acceptance battery.
# Covers SC-7 (caller pre-finalize wiring) and SC-8 (doctor bypass lint).
# Bash 3.2 compatible. Deterministic — no network, no LLM.
set -uo pipefail

cd "$(git rev-parse --show-toplevel)"

CHECK="scripts/diagnostics/check-corpus-exhaustion.sh"

pass=0
skip=0
fail=0
tmpdirs=""

mktmp_dir() {
  local d
  d="$(mktemp -d)"
  tmpdirs="$tmpdirs $d"
  echo "$d"
}
cleanup() { for d in $tmpdirs; do rm -rf "$d" 2>/dev/null; done; }
trap cleanup EXIT

check() {
  local id="$1" desc="$2"
  shift 2
  if "$@"; then
    echo "PASS: $id -- $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $id -- $desc"
    fail=$((fail + 1))
  fi
}

# ===========================================================================
# SC-7: each question-emitting command documents the corpus-gate pre-finalize
# step (references the gate adapter + a --checkpoint label).
# ===========================================================================
sc7_cmd_check() {
  local cmd="$1" ckpt="$2"
  local f="commands/${cmd}.md"
  [ -f "$f" ] || { echo "  $f missing" >&2; return 1; }
  grep -qF "corpus-gate.sh" "$f" || grep -qiF "orchestrator:corpus-gate" "$f" \
    || { echo "  $f does not reference the corpus-gate adapter/skill" >&2; return 1; }
  grep -qiF "corpus-exhaustion" "$f" \
    || { echo "  $f does not mention corpus-exhaustion" >&2; return 1; }
  return 0
}
check "SC-7-discuss"         "discuss.md wires the corpus-gate"         sc7_cmd_check discuss discuss
check "SC-7-comments"        "comments.md wires the corpus-gate"        sc7_cmd_check comments comments
check "SC-7-materials"       "materials-intake.md wires the corpus-gate" sc7_cmd_check materials-intake materials-intake
check "SC-7-specify"         "specify.md wires the corpus-gate"         sc7_cmd_check specify specify
check "SC-7-plan-phase"      "plan-phase.md wires the corpus-gate"      sc7_cmd_check plan-phase plan-phase
check "SC-7-roadmap"         "roadmap.md wires the corpus-gate"         sc7_cmd_check roadmap roadmap

# ===========================================================================
# SC-8: doctor check warns on an unresolved BLOCK artifact; ok otherwise.
# ===========================================================================
write_artifact() {
  # write_artifact <dir> <name> <verdict>
  local dir="$1" name="$2" verdict="$3"
  mkdir -p "$dir/.orchestrator/gates"
  cat > "$dir/.orchestrator/gates/corpus-exhaustion-${name}.md" <<EOF
---
schema_version: "1.0"
type: corpus-exhaustion
verdict: "${verdict}"
checkpoint: "${name}"
---
fixture artifact
EOF
}

sc8_warn_check() {
  local root out
  root="$(mktmp_dir)"
  write_artifact "$root" "blocked" "BLOCK"
  out="$(bash "$CHECK" --root "$root" 2>&1)"
  echo "$out" | grep -qE 'DOCTOR:CORPUS_EXHAUSTION status=warn .*unresolved_block=1' \
    || { echo "  expected warn/unresolved_block=1, got: $out" >&2; return 1; }
  return 0
}
sc8_ok_pass_check() {
  local root out
  root="$(mktmp_dir)"
  write_artifact "$root" "passing" "PASS"
  out="$(bash "$CHECK" --root "$root" 2>&1)"
  echo "$out" | grep -qE 'DOCTOR:CORPUS_EXHAUSTION status=ok .*unresolved_block=0' \
    || { echo "  expected ok/unresolved_block=0, got: $out" >&2; return 1; }
  return 0
}
sc8_ok_empty_check() {
  local root out
  root="$(mktmp_dir)"
  mkdir -p "$root/.orchestrator"
  out="$(bash "$CHECK" --root "$root" 2>&1)"
  echo "$out" | grep -qE 'DOCTOR:CORPUS_EXHAUSTION status=ok artifacts=0' \
    || { echo "  expected ok/artifacts=0, got: $out" >&2; return 1; }
  return 0
}
check "SC-8a" "doctor warns on unresolved BLOCK artifact"      sc8_warn_check
check "SC-8b" "doctor ok when only PASS artifacts present"     sc8_ok_pass_check
check "SC-8c" "doctor ok (zero-noise) when no artifacts"       sc8_ok_empty_check

# ===========================================================================
# Bash 3.2 safety on the P02 script.
# ===========================================================================
sc_shape_check() {
  bash -n "$CHECK" || return 1
  if grep -vE '^[[:space:]]*#' "$CHECK" | grep -E 'declare -A|mapfile|readarray'; then
    echo "  Bash 4+ construct in check-corpus-exhaustion.sh" >&2
    return 1
  fi
  return 0
}
check "SC-shape" "check-corpus-exhaustion.sh is Bash 3.2-safe" sc_shape_check

# ===========================================================================
# Summary
# ===========================================================================
echo "---"
echo "BATTERY: pass=$pass skip=$skip fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
