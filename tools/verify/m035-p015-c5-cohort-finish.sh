#!/usr/bin/env bash
# tools/verify/m035-p015-c5-cohort-finish.sh
#
# T06 (M035 P01.5) verifier: C5 cohort-finish across 4 operational
# template surfaces.
#
# Operational surfaces (JSON/YAML glob lines): zero
# `speckit.orchestrator.*` matches; `Skill(orchestrator:*)` glob present.
# Prose surfaces (instruction-schema.md, compression-tier3-prompt.md):
# new `orchestrator:<command>` form present; legacy form, where retained,
# is framed as historical reference (verifier does not enforce wording).
# claude-settings.json line-64 path-shape: no
# `Bash(bash spec-kit-orchestrator/scripts/*)` glob.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1
fail=0

# Operational surfaces: zero matches (no exception).
for f in \
  "templates/claude-settings.json" \
  "templates/autonomy-defaults.yaml"; do
  if grep -nE 'speckit\.orchestrator' "$REPO_ROOT/$f" > /dev/null 2>&1; then
    echo "FAIL: $f still has operational speckit.orchestrator reference" >&2
    fail=1
  fi
  # Confirm the new form is present.
  if ! grep -qE 'Skill\(orchestrator:' "$REPO_ROOT/$f"; then
    echo "FAIL: $f missing Skill(orchestrator:*) glob" >&2
    fail=1
  fi
done

# Prose surfaces: legacy form may appear ONLY inside historical-reference
# framing. The verifier's contract is weaker -- it asserts the new form
# is present.
for f in \
  "templates/instruction-schema.md" \
  "templates/compression-tier3-prompt.md"; do
  if ! grep -qE 'orchestrator:' "$REPO_ROOT/$f"; then
    echo "FAIL: $f missing orchestrator:<command> reference" >&2
    fail=1
  fi
done

# claude-settings.json line-64 path-shape check.
if grep -qE 'Bash\(bash spec-kit-orchestrator/scripts/\*\)' "$REPO_ROOT/templates/claude-settings.json"; then
  echo "FAIL: templates/claude-settings.json still has spec-kit-orchestrator path in Bash permission" >&2
  fail=1
fi

if [ "$fail" -eq 0 ]; then echo "PASS: m035-p015-c5-cohort-finish"; exit 0; fi
exit 1
