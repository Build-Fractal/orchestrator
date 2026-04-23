#!/usr/bin/env bash
# Gate: verify init-project.sh dual-writes the project-identity region.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INIT="${PROJECT_ROOT}/scripts/lifecycle/init-project.sh"
HELPER="${PROJECT_ROOT}/scripts/util/dual-write-runtime-md.sh"

if [ ! -x "$INIT" ]; then echo "FAIL: init-project.sh missing" >&2; exit 1; fi
if [ ! -x "$HELPER" ]; then echo "FAIL: dual-write helper missing" >&2; exit 1; fi

# Check the source for the wiring (shape-level).
grep -q 'dual-write-runtime-md.sh'    "$INIT" || { echo "FAIL: init does not reference helper" >&2; exit 1; }
grep -q 'project-identity'            "$INIT" || { echo "FAIL: init does not use project-identity marker" >&2; exit 1; }
grep -q 'dual_writes='                "$INIT" || { echo "FAIL: init does not expose dual_writes in SUMMARY" >&2; exit 1; }

# Hermetic integration: run init against a scratch dir.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# Run init with --runtime claude-code against the scratch project.
bash "$INIT" --project-dir "$SCRATCH" --runtime claude-code --force >/dev/null 2>&1
RC=$?
if [ $RC -ne 0 ]; then
  echo "FAIL: init exited non-zero ($RC) against scratch dir" >&2
  exit 1
fi

# Assert both CLAUDE.md and AGENTS.md got the region.
for f in CLAUDE.md AGENTS.md; do
  if [ ! -f "$SCRATCH/$f" ]; then
    echo "FAIL: $f not created by init" >&2; exit 1
  fi
  if ! grep -qF '# >>> orchestrator:project-identity >>>' "$SCRATCH/$f"; then
    echo "FAIL: $f missing project-identity opening marker" >&2; exit 1
  fi
  if ! grep -qF '# <<< orchestrator:project-identity <<<' "$SCRATCH/$f"; then
    echo "FAIL: $f missing project-identity closing marker" >&2; exit 1
  fi
  if ! grep -qE '^runtime=claude-code' "$SCRATCH/$f"; then
    echo "FAIL: $f missing runtime=claude-code identity line" >&2; exit 1
  fi
done

# Extract region bytes from both files and assert byte-identical (SC-6 peer-match).
extract_region() {
  awk '/^# >>> orchestrator:project-identity >>>/ { in_r=1; next } /^# <<< orchestrator:project-identity <<</ { in_r=0; next } in_r==1 { print }' "$1"
}
C_SHA="$(extract_region "$SCRATCH/CLAUDE.md" | shasum -a 256 | awk '{print $1}')"
A_SHA="$(extract_region "$SCRATCH/AGENTS.md" | shasum -a 256 | awk '{print $1}')"
if [ "$C_SHA" != "$A_SHA" ]; then
  echo "FAIL: project-identity region bytes differ between CLAUDE.md and AGENTS.md" >&2
  echo "  CLAUDE=$C_SHA  AGENTS=$A_SHA" >&2
  exit 1
fi

echo "PASS: init-project.sh dual-writes project-identity region byte-identical"
exit 0
