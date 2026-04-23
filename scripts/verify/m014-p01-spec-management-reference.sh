#!/usr/bin/env bash
# Gate: verify references/spec-management.md shape.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOC="${PROJECT_ROOT}/references/spec-management.md"
IDX="${PROJECT_ROOT}/references/README.md"

if [ ! -f "$DOC" ]; then
  echo "FAIL: references/spec-management.md missing" >&2
  exit 1
fi

if ! grep -qE '^# Spec Management Reference' "$DOC"; then
  echo "FAIL: top-level heading missing" >&2
  exit 1
fi
if ! grep -qE '^## Section Contract' "$DOC"; then
  echo "FAIL: Section Contract section missing" >&2
  exit 1
fi
if ! grep -qE '^## Dual-Write Marker Convention' "$DOC"; then
  echo "FAIL: Dual-Write Marker Convention section missing" >&2
  exit 1
fi
if ! grep -qF 'orchestrator:<region-name>' "$DOC"; then
  echo "FAIL: marker convention literal absent" >&2
  exit 1
fi
if ! grep -qE '^## `--dry-run` Manifest Shape' "$DOC"; then
  echo "FAIL: --dry-run Manifest Shape section missing" >&2
  exit 1
fi
if ! grep -qF 'partial: P04' "$DOC"; then
  echo "FAIL: partial-completion sentinel absent (expected HTML comment referencing P04)" >&2
  exit 1
fi

# references/README.md references the new doc.
if [ -f "$IDX" ]; then
  if ! grep -qF 'spec-management.md' "$IDX"; then
    echo "FAIL: references/README.md missing entry for spec-management.md" >&2
    exit 1
  fi
fi

echo "PASS: references/spec-management.md shape verified"
exit 0
