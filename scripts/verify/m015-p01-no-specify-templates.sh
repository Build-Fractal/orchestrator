#!/usr/bin/env bash
set -eu
test ! -d .specify/templates/commands || { echo "FAIL: .specify/templates/commands still exists"; exit 1; }
for tpl in agent-file-template.md checklist-template.md constitution-template.md plan-template.md spec-template.md tasks-template.md; do
  test ! -e ".specify/templates/$tpl" || { echo "FAIL: .specify/templates/$tpl still exists"; exit 1; }
done
echo "PASS: spec-kit-style templates are absent"
