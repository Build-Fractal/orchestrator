#!/usr/bin/env bash
# tools/verify/m035-p06-update-skill-doc-multi-source-shape.sh
#
# M035 P06 T04 — Asserts the multi-source dispatch documentation
# shipped to commands/update.md:
#   1. ## Update sources H2 heading present
#   2. ### Dispatch table H3 present (new in T04)
#   3. ### AD-5 detection H3 present (new in T04)
#   4. ### `update_run` JSONL emission H3 present (new in T04)
#   5. ### Suppression knobs H3 present (new in T04)
#   6. schema enumeration `git|npm|homebrew|none` literal present
#   7. D012, D013, AND D014 cross-references present
#   8. `npm root -g` AND `brew --prefix` literal references present
#   9. --no-emit-jsonl literal reference present
#  10. ORCHESTRATOR_AUTO literal reference present
#  11. ## Rollback section preserves the symlink-mode advisory verbatim
#      (P05 T02 byte-identical guarantee)
#  12. ## Cross-references contains the new MIT-2 exclusion-list entry
#
# AD-19 single-script-file shape; Bash 3.2 + POSIX-sh-safe.
# BSD-grep-portable: patterns starting with `--` use `grep -qF -- '<pat>'`.

set -u

REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
DOC="$REPO/commands/update.md"

# shellcheck disable=SC1091
. "$REPO/scripts/lib/errors.sh"

pass=0
fail=0

# --- Precondition: doc readable ---
if [ ! -r "$DOC" ]; then
  echo "FAIL: commands/update.md not readable at $DOC"
  echo "BATTERY: pass=0 fail=1"
  exit 1
fi

# --- Assertion 1: ## Update sources heading ---
if grep -qF '## Update sources' "$DOC"; then
  echo "PASS: commands/update.md contains ## Update sources heading"
  pass=$((pass + 1))
else
  echo "FAIL: commands/update.md missing ## Update sources heading"
  fail=$((fail + 1))
fi

# --- Assertion 2: ### Dispatch table heading ---
if grep -qF '### Dispatch table' "$DOC"; then
  echo "PASS: commands/update.md contains ### Dispatch table heading"
  pass=$((pass + 1))
else
  echo "FAIL: commands/update.md missing ### Dispatch table heading"
  fail=$((fail + 1))
fi

# --- Assertion 3: ### AD-5 detection heading ---
if grep -qF '### AD-5 detection' "$DOC"; then
  echo "PASS: commands/update.md contains ### AD-5 detection heading"
  pass=$((pass + 1))
else
  echo "FAIL: commands/update.md missing ### AD-5 detection heading"
  fail=$((fail + 1))
fi

# --- Assertion 4: ### `update_run` JSONL emission heading ---
if grep -qF '### `update_run` JSONL emission' "$DOC"; then
  echo "PASS: commands/update.md contains ### update_run JSONL emission heading"
  pass=$((pass + 1))
else
  echo "FAIL: commands/update.md missing ### update_run JSONL emission heading"
  fail=$((fail + 1))
fi

# --- Assertion 5: ### Suppression knobs heading ---
if grep -qF '### Suppression knobs' "$DOC"; then
  echo "PASS: commands/update.md contains ### Suppression knobs heading"
  pass=$((pass + 1))
else
  echo "FAIL: commands/update.md missing ### Suppression knobs heading"
  fail=$((fail + 1))
fi

# --- Assertion 6: schema enumeration literal ---
if grep -qF 'git|npm|homebrew|none' "$DOC"; then
  echo "PASS: commands/update.md contains schema enumeration \`git|npm|homebrew|none\`"
  pass=$((pass + 1))
else
  echo "FAIL: commands/update.md missing schema enumeration git|npm|homebrew|none"
  fail=$((fail + 1))
fi

# --- Assertion 7: D012, D013, AND D014 cross-references ---
xref_ok=1
if ! grep -qF 'D012' "$DOC"; then
  xref_ok=0
fi
if ! grep -qF 'D013' "$DOC"; then
  xref_ok=0
fi
if ! grep -qF 'D014' "$DOC"; then
  xref_ok=0
fi
if [ "$xref_ok" -eq 1 ]; then
  echo "PASS: commands/update.md cross-references D012, D013, AND D014"
  pass=$((pass + 1))
else
  echo "FAIL: commands/update.md missing one of D012/D013/D014 cross-reference"
  fail=$((fail + 1))
fi

# --- Assertion 8: `npm root -g` AND `brew --prefix` literals ---
preflight_ok=1
if ! grep -qF 'npm root -g' "$DOC"; then
  preflight_ok=0
fi
if ! grep -qF 'brew --prefix' "$DOC"; then
  preflight_ok=0
fi
if [ "$preflight_ok" -eq 1 ]; then
  echo "PASS: commands/update.md references npm root -g AND brew --prefix"
  pass=$((pass + 1))
else
  echo "FAIL: commands/update.md missing one of npm root -g / brew --prefix"
  fail=$((fail + 1))
fi

# --- Assertion 9: --no-emit-jsonl literal (BSD-grep-portable) ---
if grep -qF -- '--no-emit-jsonl' "$DOC"; then
  echo "PASS: commands/update.md references --no-emit-jsonl"
  pass=$((pass + 1))
else
  echo "FAIL: commands/update.md missing --no-emit-jsonl reference"
  fail=$((fail + 1))
fi

# --- Assertion 10: ORCHESTRATOR_AUTO literal ---
if grep -qF 'ORCHESTRATOR_AUTO' "$DOC"; then
  echo "PASS: commands/update.md references ORCHESTRATOR_AUTO"
  pass=$((pass + 1))
else
  echo "FAIL: commands/update.md missing ORCHESTRATOR_AUTO reference"
  fail=$((fail + 1))
fi

# --- Assertion 11: ## Rollback symlink-mode advisory verbatim (P05 T02) ---
if grep -qF 'rollback not available for symlink-mode installs' "$DOC"; then
  echo "PASS: ## Rollback section preserves the symlink-mode advisory verbatim"
  pass=$((pass + 1))
else
  echo "FAIL: ## Rollback symlink-mode advisory missing or modified"
  fail=$((fail + 1))
fi

# --- Assertion 12: ## Cross-references MIT-2 exclusion-list entry ---
if grep -qF 'Channel-specific metadata files' "$DOC"; then
  echo "PASS: ## Cross-references contains MIT-2 exclusion-list entry"
  pass=$((pass + 1))
else
  echo "FAIL: ## Cross-references missing MIT-2 exclusion-list entry"
  fail=$((fail + 1))
fi

echo "BATTERY: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
