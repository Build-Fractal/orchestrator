#!/usr/bin/env bash
# scripts/verify/m013-p02-github-init-command.sh — gate for the
# commands/github-init.md markdown file (MEM012 structure + T04 must-haves).
#
# Emits 6 top-level PASS lines per the T04 plan contract:
#   1. file present, >=50 lines, contains 'github-init.sh'
#   2. MEM012 structure — all required sections present
#   3. all 4 Referenced Scripts paths resolve on disk
#   4. 1 Referenced Templates path resolves
#   5. description field starts with 'Use when'
#   6. auto-mode pending-sentinel contract (SC-7) documented under Prerequisites
#
# Single-script-file (AD-19) shape.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CMD="${REPO_ROOT}/commands/github-init.md"

fail_count=0

#
# Assertion 1: file present, >=50 lines, contains 'github-init.sh'
#
a1_ok=1
if [ ! -f "$CMD" ]; then
  a1_ok=0
  echo "DIAG: commands/github-init.md missing"
else
  lc=$(wc -l < "$CMD" | tr -d ' ')
  if [ "$lc" -lt 50 ]; then
    a1_ok=0
    echo "DIAG: commands/github-init.md has only $lc lines (<50)"
  fi
  if ! grep -q 'github-init\.sh' "$CMD"; then
    a1_ok=0
    echo "DIAG: commands/github-init.md does not contain 'github-init.sh'"
  fi
fi
if [ "$a1_ok" -eq 1 ]; then
  echo "PASS: commands/github-init.md present, >=50 lines, contains 'github-init.sh'"
else
  echo "FAIL: commands/github-init.md present, >=50 lines, contains 'github-init.sh'"
  fail_count=$((fail_count + 1))
fi

#
# Assertion 2: MEM012 structure — frontmatter, Title, Prerequisites,
# Core Workflow, Output, Idempotency, Error Handling, Referenced Scripts
#
a2_ok=1
if [ -f "$CMD" ]; then
  # Frontmatter opener on line 1
  if ! head -1 "$CMD" | grep -q '^---$'; then
    a2_ok=0
    echo "DIAG: missing YAML frontmatter opener on line 1"
  fi
  # Title line
  if ! grep -q '^# speckit\.orchestrator\.github-init' "$CMD"; then
    a2_ok=0
    echo "DIAG: missing Title heading '# speckit.orchestrator.github-init'"
  fi
  # Required section headers
  for section in \
    '^## Prerequisites / State Check' \
    '^## Core Workflow' \
    '^## Output' \
    '^## Idempotency' \
    '^## Error Handling' \
    '^## Referenced Scripts' \
    '^## Referenced Templates' ; do
    if ! grep -q "$section" "$CMD"; then
      a2_ok=0
      echo "DIAG: missing section '$section'"
    fi
  done
  # Core Workflow must contain numbered items (at least '1.' + '2.')
  if ! grep -q '^1\. ' "$CMD"; then
    a2_ok=0
    echo "DIAG: Core Workflow missing numbered item '1.'"
  fi
  if ! grep -q '^2\. ' "$CMD"; then
    a2_ok=0
    echo "DIAG: Core Workflow missing numbered item '2.'"
  fi
else
  a2_ok=0
fi
if [ "$a2_ok" -eq 1 ]; then
  echo "PASS: MEM012 structure — frontmatter, Title, Prerequisites, Core Workflow, Output, Idempotency, Error Handling, Referenced Scripts"
else
  echo "FAIL: MEM012 structure — frontmatter, Title, Prerequisites, Core Workflow, Output, Idempotency, Error Handling, Referenced Scripts"
  fail_count=$((fail_count + 1))
fi

#
# Assertion 3: all 4 Referenced Scripts paths resolve on disk
#
a3_ok=1
found_scripts=0
for script in \
  scripts/integrations/github-init.sh \
  scripts/integrations/github-common.sh \
  scripts/integrations/sidecar-init-pending.sh \
  scripts/integrations/github-status.sh ; do
  if [ -f "$CMD" ] && grep -q "$script" "$CMD"; then
    found_scripts=$((found_scripts + 1))
    if [ ! -f "${REPO_ROOT}/${script}" ]; then
      a3_ok=0
      echo "DIAG: referenced script '$script' not found on disk"
    fi
  else
    a3_ok=0
    echo "DIAG: expected Referenced Script '$script' not mentioned in doc"
  fi
done
if [ "$found_scripts" -ne 4 ]; then
  a3_ok=0
  echo "DIAG: expected 4 Referenced Scripts mentioned, found $found_scripts"
fi
if [ "$a3_ok" -eq 1 ]; then
  echo "PASS: all 4 Referenced Scripts paths resolve to existing files"
else
  echo "FAIL: all 4 Referenced Scripts paths resolve to existing files"
  fail_count=$((fail_count + 1))
fi

#
# Assertion 4: 1 Referenced Templates path resolves
#
a4_ok=1
tpl="templates/github-integration-sidecar.json"
if [ -f "$CMD" ] && grep -q "$tpl" "$CMD"; then
  if [ ! -f "${REPO_ROOT}/${tpl}" ]; then
    a4_ok=0
    echo "DIAG: referenced template '$tpl' not found on disk"
  fi
else
  a4_ok=0
  echo "DIAG: expected Referenced Template '$tpl' not mentioned in doc"
fi
if [ "$a4_ok" -eq 1 ]; then
  echo "PASS: 1 Referenced Template path resolves"
else
  echo "FAIL: 1 Referenced Template path resolves"
  fail_count=$((fail_count + 1))
fi

#
# Assertion 5: description field starts with 'Use when'
#
a5_ok=1
if [ -f "$CMD" ]; then
  # Grab the description line; allow `description: "Use when ..."` form.
  desc_line=$(grep -m1 '^description:' "$CMD" || true)
  if [ -z "$desc_line" ]; then
    a5_ok=0
    echo "DIAG: no 'description:' line found in frontmatter"
  else
    # Strip leading 'description:' then optional whitespace + optional quote.
    rest=$(printf '%s' "$desc_line" | sed -E 's/^description:[[:space:]]*"?//')
    case "$rest" in
      'Use when'*) : ;;
      *)
        a5_ok=0
        echo "DIAG: description does not start with 'Use when' — got: $desc_line"
        ;;
    esac
  fi
else
  a5_ok=0
fi
if [ "$a5_ok" -eq 1 ]; then
  echo "PASS: description field starts with 'Use when'"
else
  echo "FAIL: description field starts with 'Use when'"
  fail_count=$((fail_count + 1))
fi

#
# Assertion 6: auto-mode pending-sentinel contract (SC-7) documented
# under Prerequisites / State Check
#
a6_ok=1
if [ -f "$CMD" ]; then
  # The entire doc must name the SC-7 contract with all three tokens.
  if ! grep -q 'SC-7' "$CMD"; then
    a6_ok=0
    echo "DIAG: SC-7 token not present"
  fi
  if ! grep -q 'pending-operator-complete' "$CMD"; then
    a6_ok=0
    echo "DIAG: 'pending-operator-complete' outcome not named"
  fi
  if ! grep -q 'i-am-operator' "$CMD"; then
    a6_ok=0
    echo "DIAG: '--i-am-operator' flag not named"
  fi
  # Localise to Prerequisites section: require SC-7 to appear between
  # '## Prerequisites' and the next '## ' header.
  awk '
    /^## Prerequisites/ { in_prereq = 1; next }
    in_prereq && /^## / { exit }
    in_prereq { print }
  ' "$CMD" | grep -q 'SC-7'
  if [ $? -ne 0 ]; then
    a6_ok=0
    echo "DIAG: SC-7 contract not documented under Prerequisites section"
  fi
else
  a6_ok=0
fi
if [ "$a6_ok" -eq 1 ]; then
  echo "PASS: auto-mode pending-sentinel contract documented"
else
  echo "FAIL: auto-mode pending-sentinel contract documented"
  fail_count=$((fail_count + 1))
fi

if [ "$fail_count" -eq 0 ]; then
  echo "SUMMARY: m013-p02-github-init-command.sh 6/6 PASS"
  exit 0
fi
echo "SUMMARY: m013-p02-github-init-command.sh $fail_count failure(s)"
exit 1
