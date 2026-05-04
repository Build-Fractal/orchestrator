#!/usr/bin/env bash
# tests/m032-acceptance/p01-staged-dirs-collision.sh -- M032 P01 SC-10.
#
# Exercises all three FR-22 install-collision-check.sh oracle branches
# end-to-end (each against a separate staged fixture):
#
#   1. No-collision (clean) case:
#      Fresh staged fixture, no installed-files.txt, no pre-existing target
#      paths. The bootstrapping oracle short-circuits the check on first
#      install. Installer exits 0; .orchestrator/installed-files.txt is
#      written.
#
#   2. Bootstrapping (MIT-006) branch:
#      Fresh staged fixture, no installed-files.txt, but the four target
#      paths ARE pre-populated (cp from REPO_ROOT). The bootstrapping
#      oracle accepts these as framework-installed bootstrap. Installer
#      exits 0 with stdout containing
#      `oracle=bootstrapping result=framework-installed`. installed-files.txt
#      is written reflecting the bootstrapped state.
#
#   3. Operator-owned collision branch:
#      Fresh staged fixture, BUT the .gitignore is amended to deny-all-then-
#      allow `commands/operator-file.md` so the operator file is plausibly
#      operator-owned (not gitignored). An installed-files.txt from a prior
#      install is ALSO written so the bootstrapping oracle does not apply.
#      The operator-owned file at commands/operator-file.md is NOT in that
#      tracking file. The oracle hierarchy falls through to the
#      operator-owned branch and exits 4.
#
# Output:
#   RESULT: ok p01-staged-dirs-collision.sh
#   RESULT: fail p01-staged-dirs-collision.sh reason=<reason>
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
REPO_ROOT="$( cd "$REPO_ROOT/.." && pwd )"
FIXTURE="$REPO_ROOT/tests/fixtures/m032-fresh-project-fixture"
INSTALLER="$REPO_ROOT/packaging/install/install-claude-code.sh"
COLLISION="$REPO_ROOT/scripts/lifecycle/install-collision-check.sh"

emit_fail() {
    printf 'RESULT: fail p01-staged-dirs-collision.sh reason=%s\n' "$1"
}

if [ ! -d "$FIXTURE" ]; then
    emit_fail "fixture-missing"
    exit 1
fi
if [ ! -f "$COLLISION" ]; then
    emit_fail "install-collision-check-missing"
    exit 1
fi

TMP_BASE="$(mktemp -d)"
TMP_HOME="$TMP_BASE/home-$$"
TMP_FIX_A="$TMP_BASE/sc10a-$$"   # No-collision branch
TMP_FIX_B="$TMP_BASE/sc10b-$$"   # Bootstrapping branch (MIT-006)
TMP_FIX_C="$TMP_BASE/sc10c-$$"   # Operator-owned collision branch
mkdir -p "$TMP_HOME/.claude" "$TMP_FIX_A" "$TMP_FIX_B" "$TMP_FIX_C"

cleanup() {
    rm -rf "$TMP_BASE"
}
trap cleanup EXIT

stage_fixture() {
    local target="$1"
    cp -R "$FIXTURE/." "$target/"
    ( cd "$target" && git init -q && \
      git remote add origin https://github.com/fixture-owner/m032-fresh-project-fixture.git )
}

# ---------- Branch A: No-collision (clean) case ----------
stage_fixture "$TMP_FIX_A"
HOME="$TMP_HOME" bash "$INSTALLER" --project-dir "$TMP_FIX_A" > "$TMP_BASE/run-a.log" 2>&1
rc_a=$?
if [ "$rc_a" -ne 0 ]; then
    emit_fail "branch-A:no-collision-install-exit=$rc_a"
    cat "$TMP_BASE/run-a.log" >&2
    exit 1
fi
if [ ! -f "$TMP_FIX_A/.orchestrator/installed-files.txt" ]; then
    emit_fail "branch-A:installed-files-not-written"
    exit 1
fi

# ---------- Branch B: Bootstrapping (MIT-006) branch ----------
# Per the plan, the bootstrapping branch runs the install against a fixture
# whose four runtime dirs are pre-populated (cp from REPO_ROOT) BUT no
# installed-files.txt yet. This is exactly what happens on a clean
# greenfield install whose `commands/` etc. are pre-staged by some external
# operator action and the orchestrator is being adopted. The oracle's
# project_assets-target-list match accepts these as framework-installed
# bootstrap.
stage_fixture "$TMP_FIX_B"
# Pre-populate the four target dirs.
for d in commands scripts references templates; do
    cp -R "$REPO_ROOT/$d" "$TMP_FIX_B/$d"
done

# Use install-collision-check.sh directly to exercise the bootstrapping
# branch and capture the `oracle=bootstrapping` stdout (the installer
# bypasses the collision check via the bootstrapping oracle but does not
# print that line on stdout because the call is inlined; we exercise the
# oracle directly here, then validate the installer also accepts it).
project_assets_list="$(printf 'commands/\nscripts/\nreferences/\ntemplates/\n')"
oracle_out_b="$( bash "$COLLISION" "$TMP_FIX_B/commands" "$TMP_FIX_B" "$project_assets_list" 2>&1 )"
oracle_rc_b=$?
if [ "$oracle_rc_b" -ne 0 ]; then
    emit_fail "branch-B:oracle-exit=$oracle_rc_b out=$oracle_out_b"
    exit 1
fi
if ! printf '%s\n' "$oracle_out_b" | grep -q 'oracle=bootstrapping result=framework-installed'; then
    emit_fail "branch-B:oracle-output-missing-bootstrapping-line"
    printf '%s\n' "$oracle_out_b" >&2
    exit 1
fi
if ! printf '%s\n' "$oracle_out_b" | grep -q 'mit=MIT-006'; then
    emit_fail "branch-B:oracle-output-missing-mit=MIT-006"
    printf '%s\n' "$oracle_out_b" >&2
    exit 1
fi

# Now run the installer end-to-end against the same fixture; should exit 0
# and write installed-files.txt.
HOME="$TMP_HOME" bash "$INSTALLER" --project-dir "$TMP_FIX_B" > "$TMP_BASE/run-b.log" 2>&1
rc_b=$?
if [ "$rc_b" -ne 0 ]; then
    emit_fail "branch-B:installer-exit=$rc_b"
    cat "$TMP_BASE/run-b.log" >&2
    exit 1
fi
if [ ! -f "$TMP_FIX_B/.orchestrator/installed-files.txt" ]; then
    emit_fail "branch-B:installed-files-not-written"
    exit 1
fi

# ---------- Branch C: Operator-owned collision branch ----------
stage_fixture "$TMP_FIX_C"
# Pre-write a shim installed-files.txt so the bootstrapping oracle does NOT
# apply (oracle hierarchy: tracking-file -> bootstrapping -> operator-owned).
mkdir -p "$TMP_FIX_C/.orchestrator"
# Tracking file lists some other path but NOT commands/operator-file.md.
printf 'placeholder-prior-install.txt\tmode:copy\n' > "$TMP_FIX_C/.orchestrator/installed-files.txt"

# Amend the .gitignore so commands/ remains gitignored generally BUT
# commands/operator-file.md is NOT gitignored. Oracle 3 fires only when
# the path is non-gitignored; so we use deny-all-then-allow-one form.
# We REPLACE the original five-line gitignore (ok per spec note in step 4
# of the plan: "deny-all-then-allow-one").
cat > "$TMP_FIX_C/.gitignore" <<'EOF'
commands/*
!commands/operator-file.md
scripts/
references/
templates/
.orchestrator/
EOF

# Place the operator-owned file BEFORE running the installer.
mkdir -p "$TMP_FIX_C/commands"
echo "operator-owned content" > "$TMP_FIX_C/commands/operator-file.md"

# Now exercise the oracle directly: target=commands/operator-file.md is
# the operator-owned file, but the installer does dir-shaped target
# checks (target=commands/ as a whole). The installer's collision check
# probes `commands/` itself; because `commands/` exists and isn't
# gitignored (the deny-all-then-allow gives a non-empty gitignore for
# the dir-without-slash form... actually `commands/*` ignores files
# inside, but `commands` itself is not directly gitignored).
#
# A more direct exercise: run the oracle against the operator file path
# itself.
oracle_out_c="$( bash "$COLLISION" "$TMP_FIX_C/commands/operator-file.md" "$TMP_FIX_C" "$project_assets_list" 2>&1 )"
oracle_rc_c=$?
if [ "$oracle_rc_c" -ne 4 ]; then
    emit_fail "branch-C:oracle-exit=$oracle_rc_c (expected 4)"
    printf '%s\n' "$oracle_out_c" >&2
    exit 1
fi
if ! printf '%s\n' "$oracle_out_c" | grep -q 'staged-dirs-collision: project_assets entry'; then
    emit_fail "branch-C:missing-staged-dirs-collision-line"
    printf '%s\n' "$oracle_out_c" >&2
    exit 1
fi
if ! printf '%s\n' "$oracle_out_c" | grep -q 'oracle=operator-owned'; then
    emit_fail "branch-C:missing-oracle=operator-owned"
    printf '%s\n' "$oracle_out_c" >&2
    exit 1
fi

printf 'RESULT: ok p01-staged-dirs-collision.sh\n'
exit 0
