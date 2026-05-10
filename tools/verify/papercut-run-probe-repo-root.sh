#!/usr/bin/env bash
# tools/verify/papercut-run-probe-repo-root.sh — papercut-sweep-post-M035 PC-1
#
# Asserts scripts/util/run-probe.sh exports REPO_ROOT to its child
# probe's environment, and the contract is documented in the docstring.
#
# Bash 3.2 / AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

pass=0
fail=0

probe_script="scripts/util/run-probe.sh"

# Check 1 — export line present.
if grep -qE '^export REPO_ROOT$' "$probe_script"; then
  printf 'PASS: export REPO_ROOT present in %s\n' "$probe_script"
  pass=$((pass + 1))
else
  printf 'FAIL: export REPO_ROOT missing from %s\n' "$probe_script"
  fail=$((fail + 1))
fi

# Check 2 — docstring documents the export contract.
if grep -qF 'Exports REPO_ROOT to the child probe' "$probe_script"; then
  printf 'PASS: docstring documents REPO_ROOT export contract\n'
  pass=$((pass + 1))
else
  printf 'FAIL: docstring missing REPO_ROOT export contract description\n'
  fail=$((fail + 1))
fi

# Check 3 — end-to-end: a staged probe sees REPO_ROOT in its environment.
probe_path="/tmp/papercut-pc1-probe-$$.sh"
cat > "$probe_path" <<'PROBE_EOF'
#!/usr/bin/env bash
if [ -z "${REPO_ROOT:-}" ]; then
  echo "child probe: REPO_ROOT empty" >&2
  exit 1
fi
if [ ! -d "$REPO_ROOT/scripts/util" ]; then
  echo "child probe: REPO_ROOT does not point at orchestrator repo: $REPO_ROOT" >&2
  exit 1
fi
echo "child probe: REPO_ROOT=$REPO_ROOT"
PROBE_EOF
chmod +x "$probe_path"

if bash "$probe_script" "$probe_path" >/tmp/papercut-pc1-out-$$.log 2>&1; then
  if grep -q "child probe: REPO_ROOT=" /tmp/papercut-pc1-out-$$.log; then
    printf 'PASS: end-to-end run-probe.sh exports REPO_ROOT to child\n'
    pass=$((pass + 1))
  else
    printf 'FAIL: child probe ran but did not echo REPO_ROOT\n'
    cat /tmp/papercut-pc1-out-$$.log >&2
    fail=$((fail + 1))
  fi
else
  printf 'FAIL: run-probe.sh invocation failed (rc=%d)\n' $?
  cat /tmp/papercut-pc1-out-$$.log >&2
  fail=$((fail + 1))
fi
rm -f "$probe_path" /tmp/papercut-pc1-out-$$.log

printf 'BATTERY: pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
else
  exit 1
fi
