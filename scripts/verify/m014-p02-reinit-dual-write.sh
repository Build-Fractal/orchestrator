#!/usr/bin/env bash
# Gate: verify reinit-handler.sh dual-writes the project-identity region.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INIT="${PROJECT_ROOT}/scripts/lifecycle/init-project.sh"
REINIT="${PROJECT_ROOT}/scripts/lifecycle/reinit-handler.sh"
HELPER="${PROJECT_ROOT}/scripts/util/dual-write-runtime-md.sh"

if [ ! -x "$REINIT" ]; then echo "FAIL: reinit-handler.sh missing" >&2; exit 1; fi
if [ ! -x "$HELPER" ]; then echo "FAIL: dual-write helper missing" >&2; exit 1; fi

grep -q 'dual-write-runtime-md.sh' "$REINIT" || { echo "FAIL: reinit does not reference helper" >&2; exit 1; }
grep -q 'project-identity'         "$REINIT" || { echo "FAIL: reinit does not use project-identity marker" >&2; exit 1; }
grep -q 'dual_writes='             "$REINIT" || { echo "FAIL: reinit does not expose dual_writes in SUMMARY" >&2; exit 1; }

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# First init to set up the scratch project.
bash "$INIT" --project-dir "$SCRATCH" --runtime claude-code --force >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then echo "FAIL: initial init non-zero" >&2; exit 1; fi

# Run reinit-handler in update mode directly (init delegates without --mode
# which exits 4 by design — the direct invocation exercises the update path
# that the dual-write block lives on). Reinit legitimately refreshes the
# rendered template body, so outside-markers bytes across init→reinit will
# differ for reasons unrelated to the dual-write splice (project detection,
# timestamp refresh, etc.).
STATE_ROOT="$SCRATCH/.orchestrator"
bash "$REINIT" --project-dir "$SCRATCH" --state-root "$STATE_ROOT" --runtime claude-code --mode update >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then echo "FAIL: reinit-handler update mode non-zero ($RC)" >&2; exit 1; fi

# Assert region still present in both files after reinit.
for f in CLAUDE.md AGENTS.md; do
  grep -qF '# >>> orchestrator:project-identity >>>' "$SCRATCH/$f" || { echo "FAIL: $f missing region after reinit" >&2; exit 1; }
done

# SC-6a invariant on reinit-produced CLAUDE.md: invoking the dual-write
# helper again on the same input must preserve outside-markers bytes
# byte-identically. This isolates the invariant to the helper's splice,
# orthogonal to reinit's legitimate rendered-template refresh.
outside_bytes() {
  awk '/^# >>> orchestrator:/ { in_r=1; next } /^# <<< orchestrator:/ { in_r=0; next } in_r != 1 { print }' "$1"
}
REF_SHA="$(outside_bytes "$SCRATCH/CLAUDE.md" | shasum -a 256 | awk '{print $1}')"

# Re-invoke helper with an identical fragment payload.
FRAG="$(mktemp)"
awk '/^# >>> orchestrator:project-identity >>>/ { in_r=1; next } /^# <<< orchestrator:project-identity <<</ { in_r=0; next } in_r==1 { print }' "$SCRATCH/CLAUDE.md" > "$FRAG"
bash "$HELPER" --marker project-identity --content "$FRAG" --root "$SCRATCH" --file CLAUDE.md >/dev/null 2>&1
RC=$?
rm -f "$FRAG"
if [ $RC -ne 0 ]; then echo "FAIL: helper re-invocation non-zero ($RC)" >&2; exit 1; fi

POST_SHA="$(outside_bytes "$SCRATCH/CLAUDE.md" | shasum -a 256 | awk '{print $1}')"
if [ "$REF_SHA" != "$POST_SHA" ]; then
  echo "FAIL: outside-markers bytes diverged on helper re-invocation" >&2; exit 1
fi

echo "PASS: reinit-handler.sh dual-writes project-identity region; outside-markers bytes preserved"
exit 0
