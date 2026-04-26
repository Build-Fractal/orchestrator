#!/usr/bin/env bash
# scripts/verify/m024-p01-shape-detector.sh
# Exercises the detector against five canonical cases.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DET="$ROOT/scripts/intake/shape-detect.sh"

if [ ! -x "$DET" ]; then
  echo "FAIL: $DET not executable"
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Case A — spec.
mkdir -p "$tmp/specs/099-x"
cat > "$tmp/specs/099-x/spec.md" <<EOF
---
schema_version: "1.0"
type: feature-spec
EOF
out_a=$(bash "$DET" --spec-path "$tmp/specs/099-x/spec.md")
case "$out_a" in
  *"input_shape=spec"*"shape_classification=high"*) ;;
  *) echo "FAIL: spec case got: $out_a"; exit 1 ;;
esac

# Case B — empty.
out_b=$(bash "$DET")
case "$out_b" in
  *"input_shape=empty"*"shape_classification=high"*) ;;
  *) echo "FAIL: empty case got: $out_b"; exit 1 ;;
esac

# Case C — idea (5 words).
out_c=$(bash "$DET" --input "fix typo in status doc")
case "$out_c" in
  *"input_shape=idea"*) ;;
  *) echo "FAIL: idea case got: $out_c"; exit 1 ;;
esac

# Case D — paragraph (~30 words).
out_d=$(bash "$DET" --input "We should add a last seen timestamp to the status command output and probably cache it for about five seconds so repeated calls do not hammer the filesystem at all")
case "$out_d" in
  *"input_shape=paragraph"*) ;;
  *) echo "FAIL: paragraph case got: $out_d"; exit 1 ;;
esac

# Case E — fragment (Given/When/Then triple).
gwt_input="Given a project state, When the operator types evaluate, Then the proposal is emitted."
out_e=$(bash "$DET" --input "$gwt_input")
case "$out_e" in
  *"input_shape=fragment"*) ;;
  *) echo "FAIL: fragment-gwt case got: $out_e"; exit 1 ;;
esac

# Case F — fragment (## heading).
out_f=$(bash "$DET" --input "## Background
Some context here about the bug.")
case "$out_f" in
  *"input_shape=fragment"*) ;;
  *) echo "FAIL: fragment-heading case got: $out_f"; exit 1 ;;
esac

echo "PASS: shape-detect.sh — spec, empty, idea, paragraph, fragment-gwt, fragment-heading"
exit 0
