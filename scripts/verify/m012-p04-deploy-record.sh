#!/usr/bin/env bash
# scripts/verify/m012-p04-deploy-record.sh — M012/P04 T04 gate.
#
# Asserts .orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md
# carries a YAML frontmatter block with every required field:
#
#   schema_version:  string
#   type:            "deploy-record"
#   milestone:       "M012"
#   phase:           "P04"
#   deployed_url:    http*://... OR "pending" sentinel
#   commit_sha:      string (real SHA or "pending")
#   deployed_at:     string (ISO-8601 or "pending")
#   deployer:        string (GH handle or "pending")
#   gate_giscus_config_result:   pass|fail|skip|pending
#   gate_mkdocs_build_result:    pass|fail|skip|pending
#   gate_link_check_result:      pass|fail|skip|pending
#   gate_giscus_smoke_result:    pass|fail|skip|pending
#
# Body must name the `gh-pages` branch and reference `wiki-deploy.sh`.
# Fixture sentinel `pending` is accepted per the Tier 1 dual-path
# contract (sandbox dispatch has no network / no gh-pages push rights).
#
# Bash 3.2 compatible. Single-script-file shape.

set -u

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEFAULT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
ROOT="${1:-$DEFAULT_ROOT}"

REC="$ROOT/.orchestrator/milestones/M012/phases/P04/DEPLOY-RECORD.md"
if [ ! -f "$REC" ]; then
  printf 'FAIL: %s not found\n' "$REC" >&2
  exit 1
fi

# Frontmatter fields: assert each required key appears with a non-empty value.
# The patterns are line-anchored (`^key:`) so body text that happens to match
# a key name does not false-positive.
for key in \
  'schema_version' \
  'type' \
  'milestone' \
  'phase' \
  'deployed_url' \
  'commit_sha' \
  'deployed_at' \
  'deployer' \
  'gate_giscus_config_result' \
  'gate_mkdocs_build_result' \
  'gate_link_check_result' \
  'gate_giscus_smoke_result'
do
  if ! grep -qE "^${key}:" "$REC"; then
    printf 'FAIL: %s missing frontmatter key `%s:`\n' "$REC" "$key" >&2
    exit 1
  fi
done

# `type` must be "deploy-record".
if ! grep -qE '^type:[[:space:]]*"?deploy-record"?' "$REC"; then
  printf 'FAIL: %s `type` must equal "deploy-record"\n' "$REC" >&2
  exit 1
fi

# `milestone` must be M012; `phase` must be P04.
if ! grep -qE '^milestone:[[:space:]]*"?M012"?' "$REC"; then
  printf 'FAIL: %s `milestone` must equal "M012"\n' "$REC" >&2
  exit 1
fi
if ! grep -qE '^phase:[[:space:]]*"?P04"?' "$REC"; then
  printf 'FAIL: %s `phase` must equal "P04"\n' "$REC" >&2
  exit 1
fi

# `deployed_url` — http*://... or "pending" sentinel.
url_line=$(grep -E '^deployed_url:' "$REC" | head -n 1)
if ! printf '%s' "$url_line" | grep -qE '(https?://|"?pending"?)'; then
  printf 'FAIL: %s `deployed_url` must be http(s)://... or "pending"; got: %s\n' "$REC" "$url_line" >&2
  exit 1
fi

# Four gate_*_result fields — values in {pass,fail,skip,pending}.
for g in \
  'gate_giscus_config_result' \
  'gate_mkdocs_build_result' \
  'gate_link_check_result' \
  'gate_giscus_smoke_result'
do
  line=$(grep -E "^${g}:" "$REC" | head -n 1)
  if ! printf '%s' "$line" | grep -qE ':[[:space:]]*"?(pass|fail|skip|pending)"?[[:space:]]*$'; then
    printf 'FAIL: %s `%s` must be one of pass|fail|skip|pending; got: %s\n' "$REC" "$g" "$line" >&2
    exit 1
  fi
done

# Body references (name the gh-pages branch; reference the wrapper).
if ! grep -qF 'gh-pages' "$REC"; then
  printf 'FAIL: %s body must name the `gh-pages` branch\n' "$REC" >&2
  exit 1
fi
if ! grep -qF 'wiki-deploy.sh' "$REC"; then
  printf 'FAIL: %s body must reference `wiki-deploy.sh`\n' "$REC" >&2
  exit 1
fi

printf 'PASS: DEPLOY-RECORD.md frontmatter schema + gate-result fields + gh-pages/wiki-deploy.sh references\n'
exit 0
