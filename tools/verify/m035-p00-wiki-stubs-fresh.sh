#!/usr/bin/env bash
# tools/verify/m035-p00-wiki-stubs-fresh.sh -- M035 P00 T03 shape verifier.
#
# Asserts the wiki-stubs-fresh diagnostic + pages.yml HEREDOC gate ship per
# the dispatch must-haves:
#
#   1. scripts/diagnostics/wiki-stubs-fresh.sh exists; references both
#      wiki-generate-stubs.sh and wiki-generate-nav.sh.
#   2. The diagnostic returns PASS (exit 0) against the orchestrator repo
#      (which is fresh-by-construction at verifier-run time).
#   3. The diagnostic returns DRIFT (exit 2) and emits a regen instruction
#      against a tmp-staged minimal wiki skeleton with one stub removed.
#   4. scripts/lifecycle/wiki-init.sh emit_pages_workflow() HEREDOC contains
#      `bash scripts/diagnostics/wiki-stubs-fresh.sh` AND the gate line
#      precedes the `mkdocs build` line in the HEREDOC body.
#
# Bash 3.2 compatible. AP-009 friendly (no compound chains > 2 in command
# shape — assertions run sequentially via if/then blocks).
#
# Exit:
#   0  PASS  (all assertions pass)
#   1  FAIL  (any assertion fails)

set -u

SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
REPO_ROOT=$( cd "$SCRIPT_DIR/../.." && pwd )

DIAG="$REPO_ROOT/scripts/diagnostics/wiki-stubs-fresh.sh"
WIKI_INIT="$REPO_ROOT/scripts/lifecycle/wiki-init.sh"

pass=0
fail=0
failures=""

ok() {
  pass=$((pass + 1))
  printf '  ok: %s\n' "$1"
}
ng() {
  fail=$((fail + 1))
  failures="${failures}    - ${1}"$'\n'
  printf '  FAIL: %s\n' "$1"
}

# ---- Assertion 1: diagnostic exists + references both generators -----------
printf 'check 1: diagnostic file present + references generators\n'
if [ -f "$DIAG" ]; then
  ok "scripts/diagnostics/wiki-stubs-fresh.sh exists"
else
  ng "scripts/diagnostics/wiki-stubs-fresh.sh missing"
fi

if [ -f "$DIAG" ] && grep -qF 'wiki-generate-stubs.sh' "$DIAG"; then
  ok "diagnostic references wiki-generate-stubs.sh"
else
  ng "diagnostic does not reference wiki-generate-stubs.sh"
fi

if [ -f "$DIAG" ] && grep -qF 'wiki-generate-nav.sh' "$DIAG"; then
  ok "diagnostic references wiki-generate-nav.sh"
else
  ng "diagnostic does not reference wiki-generate-nav.sh"
fi

# ---- Assertion 2: green-on-clean (orchestrator repo is fresh) --------------
printf 'check 2: green-on-clean against orchestrator repo\n'
if [ -f "$DIAG" ]; then
  GREEN_OUT=$(mktemp)
  GREEN_ERR=$(mktemp)
  if bash "$DIAG" --root "$REPO_ROOT" >"$GREEN_OUT" 2>"$GREEN_ERR"; then
    GREEN_RC=0
  else
    GREEN_RC=$?
  fi
  if [ "$GREEN_RC" -eq 0 ]; then
    ok "diagnostic exits 0 on clean repo"
  else
    ng "diagnostic exit=$GREEN_RC on clean repo (expected 0); stderr below"
    cat "$GREEN_ERR" >&2
  fi
  if grep -qF 'PASS: wiki-stubs-fresh' "$GREEN_OUT"; then
    ok "stdout contains 'PASS: wiki-stubs-fresh'"
  else
    ng "stdout missing 'PASS: wiki-stubs-fresh' marker"
    cat "$GREEN_OUT" >&2
  fi
  rm -f "$GREEN_OUT" "$GREEN_ERR"
else
  ng "skipped check 2 (diagnostic missing)"
fi

# ---- Assertion 3: red-on-drift (tmp fixture with one stub removed) --------
printf 'check 3: red-on-drift against tmp fixture\n'
if [ -f "$DIAG" ]; then
  FIXTURE=$(mktemp -d)
  # Stage a copy of the orchestrator repo into FIXTURE/. cp -R the directories
  # the diagnostic stages internally (which mirrors what the live repo's wiki
  # was generated from). To keep the verifier fast, only stage the dirs the
  # generators consume + wiki/ + a few sibling files.
  STAGE_OK=1
  for _dir in ".orchestrator" "knowledge" "scripts" "templates" "wiki"; do
    if [ -d "$REPO_ROOT/$_dir" ]; then
      if ! cp -R "$REPO_ROOT/$_dir" "$FIXTURE/$_dir" 2>/dev/null; then
        STAGE_OK=0
        break
      fi
    fi
  done
  for _f in "CHANGELOG.md" "README.md" "constitution.md"; do
    if [ -f "$REPO_ROOT/$_f" ]; then
      cp "$REPO_ROOT/$_f" "$FIXTURE/$_f" 2>/dev/null || true
    fi
  done

  if [ "$STAGE_OK" -ne 1 ]; then
    ng "could not stage tmp fixture for drift assertion"
  else
    # Pick a known auto-generated stub and remove it. constitution.md is
    # always emitted by the stub gen and lives at the top level of wiki/docs/,
    # so it's a stable target across the verifier's lifetime.
    VICTIM="$FIXTURE/wiki/docs/constitution.md"
    if [ ! -f "$VICTIM" ]; then
      ng "expected stub $VICTIM not present in fixture (cannot induce drift)"
    else
      rm -f "$VICTIM"
      DRIFT_OUT=$(mktemp)
      DRIFT_ERR=$(mktemp)
      if bash "$DIAG" --root "$FIXTURE" >"$DRIFT_OUT" 2>"$DRIFT_ERR"; then
        DRIFT_RC=0
      else
        DRIFT_RC=$?
      fi
      if [ "$DRIFT_RC" -eq 2 ]; then
        ok "diagnostic exits 2 on drifted fixture"
      else
        ng "diagnostic exit=$DRIFT_RC on drifted fixture (expected 2)"
        cat "$DRIFT_OUT" >&2
        cat "$DRIFT_ERR" >&2
      fi
      if grep -qF 'regen' "$DRIFT_ERR"; then
        ok "stderr contains 'regen' regen-command hint"
      else
        ng "stderr missing 'regen' hint"
        cat "$DRIFT_ERR" >&2
      fi
      rm -f "$DRIFT_OUT" "$DRIFT_ERR"
    fi
  fi
  rm -rf "$FIXTURE"
else
  ng "skipped check 3 (diagnostic missing)"
fi

# ---- Assertion 4: pages.yml HEREDOC ordering ------------------------------
printf 'check 4: pages.yml HEREDOC contains gate before mkdocs build\n'
if [ -f "$WIKI_INIT" ]; then
  if grep -qF 'bash scripts/diagnostics/wiki-stubs-fresh.sh' "$WIKI_INIT"; then
    ok "wiki-init.sh references wiki-stubs-fresh.sh"
  else
    ng "wiki-init.sh missing wiki-stubs-fresh.sh reference"
  fi

  # Extract the HEREDOC body between PAGES_WORKFLOW_EOF markers and assert
  # that the wiki-stubs-fresh.sh line appears BEFORE the `mkdocs build` line.
  # awk tracks an in-heredoc state across the two PAGES_WORKFLOW_EOF tokens.
  HEREDOC_BODY=$(awk '
    /<<.PAGES_WORKFLOW_EOF./ { in_hd = 1; next }
    /^PAGES_WORKFLOW_EOF$/   { in_hd = 0; next }
    in_hd == 1 { print }
  ' "$WIKI_INIT")

  GATE_LINE=$(printf '%s\n' "$HEREDOC_BODY" | grep -nF 'wiki-stubs-fresh.sh' | head -1 | cut -d: -f1)
  BUILD_LINE=$(printf '%s\n' "$HEREDOC_BODY" | grep -nF 'mkdocs build' | head -1 | cut -d: -f1)

  if [ -z "$GATE_LINE" ]; then
    ng "HEREDOC body missing wiki-stubs-fresh.sh gate"
  elif [ -z "$BUILD_LINE" ]; then
    ng "HEREDOC body missing 'mkdocs build' line"
  else
    if [ "$GATE_LINE" -lt "$BUILD_LINE" ]; then
      ok "HEREDOC ordering: gate (line $GATE_LINE) precedes mkdocs build (line $BUILD_LINE)"
    else
      ng "HEREDOC ordering wrong: gate at $GATE_LINE, mkdocs build at $BUILD_LINE"
    fi
  fi
else
  ng "scripts/lifecycle/wiki-init.sh missing"
fi

# ---- Verdict ---------------------------------------------------------------
printf '\n'
if [ "$fail" -gt 0 ]; then
  printf 'FAIL: m035-p00-wiki-stubs-fresh -- %s assertion(s) failed (%s passed)\n' "$fail" "$pass" >&2
  printf '%s' "$failures" >&2
  exit 1
fi

printf 'PASS: m035-p00-wiki-stubs-fresh (diagnostic operates green-on-clean and red-on-drift; pages.yml HEREDOC includes pre-build gate)\n'
printf '  assertions: %s pass, %s fail\n' "$pass" "$fail"
exit 0
