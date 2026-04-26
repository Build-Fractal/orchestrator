#!/usr/bin/env bash
# scripts/verify/m024-p07-write-confinement.sh
# Asserts P07 scripts write only to .orchestrator/intake/<id>/ or /tmp.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

violation=0

# Pure decision emitters must not redirect to any path outside /tmp.
# Allowed targets: stderr (>&2), stdout (>&1), /dev/null, and mktemp-derived body_file in /tmp.
for pure in "$ROOT/scripts/intake/design-gate-classify.sh"; do
  if grep -nE '^[^#]*[[:space:]]>[[:space:]]+[^&]' "$pure" \
     | grep -vE '>&[12]' | grep -vE '>/dev/null' | grep -vE '>[[:space:]]*"\$body_file"'; then
    echo "FAIL: $pure has unexpected file redirect — pure decision emitter must not write outside /tmp"
    violation=1
  fi
done

# Degradation script writes only to the --proposal path supplied by caller (sed -i.bak idiom).
deg="$ROOT/scripts/intake/design-gate-degradation.sh"
if grep -nE '^[^#]*sed -i\.bak' "$deg" | grep -v 'PROPOSAL'; then
  echo "FAIL: $deg has a sed -i.bak that does not target \$PROPOSAL — write-confinement violated"
  violation=1
fi

# proposal-emit.sh modifications must keep writes inside out_dir / out_path / tmp_render.
emit="$ROOT/scripts/intake/proposal-emit.sh"
if grep -nE '^[^#]*sed -i\.bak' "$emit" | grep -vE 'tmp_render|PROPOSAL|"\$proposal"|out_path'; then
  echo "FAIL: $emit has a sed -i.bak that escapes the tmp/intake confinement"
  violation=1
fi

if [ "$violation" -eq 0 ]; then
  echo "PASS: write-confinement — P07 scripts confine writes to intake dir + tmp"
  exit 0
fi
exit 1
