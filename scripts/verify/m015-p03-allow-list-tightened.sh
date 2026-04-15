#!/usr/bin/env bash
set -eu
# Verify: ALLOW_P03_DOCS in scripts/verify/m015-p02-no-stale-state-refs.sh
# has been reduced from its initial 16-entry tolerance set. After P03,
# the expected state is EMPTY or minimal — no P03-reserved doc should
# still appear in the allow-list because every reframed doc has been
# swept clean of legacy references.
#
# Baseline: P02 landed with 16 entries in ALLOW_P03_DOCS (README.md,
# CLAUDE.md, references/architecture.md, references/installation.md,
# references/constitution-walkthrough.md, references/engine.md,
# references/events.md, references/errors.md, references/recipes.md,
# references/file-formats.md, references/state-machine.md,
# references/tier-definitions.md, docs/getting-started.md,
# docs/knowledge-management.md, docs/hook-development.md,
# docs/recipe-authoring.md, scripts/AGENTS.md = 17 pipe-separated tokens).
# Count the pipe-separated tokens in the ALLOW_P03_DOCS line.
SCRIPT=scripts/verify/m015-p02-no-stale-state-refs.sh
test -f "$SCRIPT" || { echo "FAIL: $SCRIPT missing"; exit 1; }
LINE=$(grep "^ALLOW_P03_DOCS=" "$SCRIPT" || true)
test -n "$LINE" || { echo "FAIL: ALLOW_P03_DOCS declaration not found in $SCRIPT"; exit 1; }
# Extract the quoted body after `=`.
BODY=$(echo "$LINE" | sed -e "s/^ALLOW_P03_DOCS='//" -e "s/'$//")
# An empty allow list is the ideal post-P03 state. Represent empty
# as ALLOW_P03_DOCS='(?!x)x' or ALLOW_P03_DOCS='__empty__' or
# ALLOW_P03_DOCS='' — any of these is acceptable. If non-empty,
# count pipe-separated tokens.
if [ -z "$BODY" ] || [ "$BODY" = "__empty__" ] || [ "$BODY" = "(?!x)x" ]; then
  echo "PASS: ALLOW_P03_DOCS is empty — all P03-reserved docs reframed"
  exit 0
fi
# Count tokens: count pipes + 1.
pipe_count=$(echo "$BODY" | tr -cd '|' | wc -c | tr -d ' ')
token_count=$((pipe_count + 1))
# Reject growth. Baseline was 17 tokens.
if [ "$token_count" -ge 17 ]; then
  echo "FAIL: ALLOW_P03_DOCS still has $token_count tokens (baseline=17); P03 must reduce it"
  exit 1
fi
echo "PASS: ALLOW_P03_DOCS reduced to $token_count token(s)"
