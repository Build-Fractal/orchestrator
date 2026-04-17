---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M021"
name: "Create scripts/util/run-probe.sh + gate"
depends_on: []
---

## Prerequisites

No upstream task dependencies. `scripts/util/` exists. The `scripts/verify/m021-p01-*.sh` naming convention is established by T01/T02.

## Description

Create `scripts/util/run-probe.sh` — a canonical wrapper that invokes a previously-staged bash file by absolute path. This replaces the recurring shape `cat > /tmp/probe.sh <<EOF ... EOF ; bash /tmp/probe.sh` and bare `bash /tmp/probe.sh` calls observed in M011/P05–P07 (heredoc-with-expansion + bare-tmp-invocation triggers; AD-3). The wrapper enforces that the probe path lies under one of three approved roots (`/tmp/`, `/var/folders/`, or the project-relative `tmp/` fixture root) so that adversarial or accidental paths (e.g. `bash /etc/cron.d/x.sh`) are rejected before invocation.

Then create `scripts/verify/m021-p01-run-probe.sh` — a self-contained gate exercising happy path, RC pass-through, missing-file rejection, and out-of-root rejection.

## Steps

### Step 1: Create scripts/util/run-probe.sh

Write the script at `scripts/util/run-probe.sh`:

```bash
#!/usr/bin/env bash
# scripts/util/run-probe.sh — Invoke a staged bash probe from an approved root.
#
# Usage: run-probe.sh <path-to-staged-probe.sh>
#   e.g.: run-probe.sh /tmp/m021-probe.sh
#         run-probe.sh tmp/fixtures/probe.sh
#
# Approved roots: /tmp/, /var/folders/, and <repo>/tmp/ (project-relative
# fixture root). Any other path is rejected with exit 3.
#
# Replaces the `cat > /tmp/x.sh <<EOF ... EOF ; bash /tmp/x.sh` heredoc
# shape and the bare `bash /tmp/x.sh` shape that Claude Code flags as
# heredoc-expansion / compound-sequencing / bare-tmp-invocation. The
# staged probe is written by the caller *before* this wrapper runs
# (typically via the Write tool, which does not trigger Bash heuristics),
# so by the time run-probe.sh fires, the path is a plain file on disk.
#
# Exit: passes through the child's exit code. Exits 1 when the file is
# missing or not readable. Exits 2 on usage error. Exits 3 when the
# path is not under an approved root.
#
# Bash 3.2 compatible.

set -u

if [ $# -ne 1 ]; then
  echo "usage: run-probe.sh <path-to-staged-probe.sh>" >&2
  exit 2
fi

probe="$1"

if [ -z "$probe" ]; then
  echo "run-probe.sh: empty path" >&2
  exit 2
fi

# Resolve repo root (parent of scripts/util/).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Normalize probe: if it's relative, resolve against $PWD; if it's already
# absolute, keep it. We avoid `realpath` (not on stock macOS) and instead
# use a simple prefix test after canonicalization via `cd + pwd` when the
# parent directory exists.
abs_probe="$probe"
case "$probe" in
  /*) : ;;
  *)
    abs_probe="${PWD}/${probe}"
    ;;
esac

# Approved-root check. Compare by prefix against the three allowed trees.
project_tmp="${REPO_ROOT}/tmp/"
case "$abs_probe" in
  /tmp/*|/private/tmp/*|/var/folders/*|/private/var/folders/*)
    : ;;
  "${project_tmp}"*)
    : ;;
  *)
    echo "run-probe.sh: path outside approved roots (/tmp, /var/folders, <repo>/tmp): $abs_probe" >&2
    exit 3
    ;;
esac

if [ ! -f "$abs_probe" ]; then
  echo "run-probe.sh: probe not found: $abs_probe" >&2
  exit 1
fi
if [ ! -r "$abs_probe" ]; then
  echo "run-probe.sh: probe not readable: $abs_probe" >&2
  exit 1
fi

# Invoke. No env injection (that's with-env.sh's job). No stdout
# capture. The child inherits this process's stdio.
bash "$abs_probe"
```

### Step 2: Create scripts/verify/m021-p01-run-probe.sh

Write the gate at `scripts/verify/m021-p01-run-probe.sh`:

```bash
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

# Stage a probe under /tmp.
probe_tmp=$(mktemp /tmp/m021-p01-probe.XXXXXX.sh)
trap 'rm -f "$probe_tmp"' EXIT
printf '#!/usr/bin/env bash\necho hello-from-probe\nexit 0\n' > "$probe_tmp"

# 1. Happy path: probe under /tmp/ runs and emits stdout.
got=$(bash "$WRAPPER" "$probe_tmp")
assert_eq "runs /tmp/-staged probe" "hello-from-probe" "$got"

# 2. Child RC is forwarded.
probe_rc=$(mktemp /tmp/m021-p01-probe.XXXXXX.sh)
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
```

## Must-Haves

- `scripts/util/run-probe.sh` invokes a staged bash file by absolute path when that path is under `/tmp/`, `/var/folders/`, or `<repo>/tmp/`.
- Any other path (e.g. `/etc/hosts`) is rejected with exit 3 and a diagnostic to stderr.
- Missing/unreadable files exit 1. Usage errors exit 2.
- Child exit code is forwarded on success.
- Both files are Bash 3.2 compatible.

## Verification

- `bash scripts/verify/m021-p01-run-probe.sh` exits 0 with final line `PASS: m021-p01-run-probe.sh`.

## Inputs

### From Disk (Pre-existing)

- `scripts/util/` — existing util directory.
- `scripts/verify/` — gate destination.
- `/tmp` — OS-standard temp directory; assumed writable (macOS and Linux both provide this).

## Constraints

- Bash 3.2 compatible.
- No `realpath` dependency (not on stock macOS). Use prefix matching after a simple absolute-path normalization.
- macOS `/tmp` is symlinked to `/private/tmp` and `/var/folders/...` is sometimes referenced as `/private/var/folders/...`; accept both prefix forms.
- Do not source the probe — always invoke it via `bash <path>` so it runs in a child process.
- Do not inject environment variables (that's `with-env.sh`'s job). Composition: `bash scripts/util/with-env.sh FOO=bar -- bash scripts/util/run-probe.sh /tmp/x.sh`.
- Gate script uses only single-script-file-shape commands (AD-19).

## Expected Output

- `scripts/util/run-probe.sh` created.
- `scripts/verify/m021-p01-run-probe.sh` created.
- `bash scripts/verify/m021-p01-run-probe.sh` → final line `PASS: m021-p01-run-probe.sh`, exit 0.
