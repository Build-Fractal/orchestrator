#!/usr/bin/env bash
# scripts/verify/m021-p01-run-probe.sh — Gate for scripts/util/run-probe.sh
# Exits 0 when all assertions hold, 1 otherwise.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WRAPPER="${REPO_ROOT}/scripts/util/run-probe.sh"

fail_count=0

assert_eq() {
  if [ "$2" = "$3" ]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1 (expected=$2 actual=$3)"
    fail_count=$((fail_count + 1))
  fi
}

# Stage a probe under /tmp. macOS BSD mktemp does not expand trailing
# suffixes (only the XXXXXX template itself), so keep the template
# suffix-free to avoid filename collisions across multiple calls.
probe_tmp=$(mktemp /tmp/m021-p01-probe.XXXXXX)
trap 'rm -f "$probe_tmp"' EXIT
printf '#!/usr/bin/env bash\necho hello-from-probe\nexit 0\n' > "$probe_tmp"

# 1. Happy path: probe under /tmp/ runs and emits stdout.
got=$(bash "$WRAPPER" "$probe_tmp")
assert_eq "runs /tmp/-staged probe" "hello-from-probe" "$got"

# 2. Child RC is forwarded.
probe_rc=$(mktemp /tmp/m021-p01-probe.XXXXXX)
printf '#!/usr/bin/env bash\nexit 9\n' > "$probe_rc"
bash "$WRAPPER" "$probe_rc"
rc=$?
rm -f "$probe_rc"
assert_eq "forwards child exit code" "9" "$rc"

# 3. Missing file under approved root: exit 1.
bash "$WRAPPER" /tmp/m021-does-not-exist.sh >/dev/null 2>&1
rc=$?
assert_eq "missing approved-root file exits 1" "1" "$rc"

# 4. Out-of-root path: exit 3.
bash "$WRAPPER" /etc/hosts >/dev/null 2>&1
rc=$?
assert_eq "out-of-root path exits 3" "3" "$rc"

# 5. Usage error (no arg): exit 2.
bash "$WRAPPER" >/dev/null 2>&1
rc=$?
assert_eq "missing arg exits 2" "2" "$rc"

# 6. Empty-string arg: exit 2.
bash "$WRAPPER" "" >/dev/null 2>&1
rc=$?
assert_eq "empty path exits 2" "2" "$rc"

# 7. Project-relative tmp/ root is accepted.
mkdir -p "${REPO_ROOT}/tmp"
probe_proj="${REPO_ROOT}/tmp/m021-p01-probe-proj.sh"
printf '#!/usr/bin/env bash\necho proj-probe\n' > "$probe_proj"
got=$(bash "$WRAPPER" "$probe_proj")
rm -f "$probe_proj"
assert_eq "runs <repo>/tmp/-staged probe" "proj-probe" "$got"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m021-p01-run-probe.sh"
  exit 0
fi
echo "FAIL: m021-p01-run-probe.sh ($fail_count failures)"
exit 1
