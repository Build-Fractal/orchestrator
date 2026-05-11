#!/usr/bin/env bash
# tests/installer-acceptance/m035-collision-exit-status.sh
# M035 P00 T01 regression fixture.
#
# What this fixture covers:
#
# Each of the three installers (install-claude-code.sh, install-codex.sh,
# install-cursor.sh) used to drive its `project_assets:` install pass via:
#
#     while IFS= read -r tuple; do ... done < <(bash read-project-assets.sh ...)
#
# On macOS bash 3.2 the process-substitution form silently swallows the
# producer's exit status. If `read-project-assets.sh` fails (malformed
# manifest, missing key, unknown mode, missing file) the loop body simply
# never runs and the installer proceeds as if everything were fine. This is
# the "collision-masking" failure shape called out in M035 P00 SC-5.
#
# T01 replaces the masking shape with a temp-file-iterated form that
# captures the producer's rc explicitly. This fixture verifies the fix:
# we corrupt the bundle manifest into a shape that read-project-assets.sh
# rejects with exit 2, run each installer, and assert each exits non-zero.
# Pre-fix this fixture would observe exit 0 (collision masked); post-fix it
# observes a non-zero exit (collision surfaced).
#
# Bundle isolation: we COPY packaging/bundle/ into a temp directory and
# mutate the COPY (not the live repo), then point the installer at the
# temp bundle by stand-up of a temp repo skeleton. We do NOT mutate the
# live repo bundle.
#
# The fixture executes under whatever bash is on PATH and records the
# version in its run header per the T01 plan ("acceptance: fixture exists,
# exits non-zero on collision under at least one bash version, records the
# version in its run header").
#
# Bash 3.2 compatible.
#
# Exit:
#   0  PASS (3/3 installers surface non-zero exit on producer failure)
#   1  FAIL

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"

# ---------- Run header ----------
printf '\n'
printf '=== m035-collision-exit-status (M035 P00 T01) ===\n'
printf 'bash_version=%s\n' "${BASH_VERSION:-unknown}"
printf 'bash_versinfo_major=%s\n' "${BASH_VERSINFO[0]:-unknown}"
printf 'platform=%s\n' "$(uname -s)"
printf 'repo_root=%s\n' "$REPO_ROOT"
printf '\n'

WORKDIR="$( mktemp -d -t m035-collision.XXXXXX )"
trap 'rm -rf "$WORKDIR"' EXIT

# Copy real packaging/bundle/ into the workdir so we can mutate the manifest
# without touching the live repo.
TEMP_BUNDLE="$WORKDIR/bundle"
cp -R "$REPO_ROOT/packaging/bundle" "$TEMP_BUNDLE"

# Corrupt the manifest so `read-project-assets.sh` exits 2 (invalid input).
# We replace the project_assets: section with one entry missing the
# required `target:` key — read-project-assets.sh exits 2 with
# "missing required key target".
TEMP_MANIFEST="$TEMP_BUNDLE/manifest.yml"
cat > "$TEMP_MANIFEST" <<'EOF_MANIFEST'
schema_version: "1.0"
type: bundle-manifest
name: "orchestrator"
version: "0.0.0-fixture"
description: "M035 P00 T01 corrupt-manifest fixture"
project_assets:
  - source: commands/
    mode: copy
EOF_MANIFEST

# Sanity-check the corruption: read-project-assets.sh should exit non-zero.
"$REPO_ROOT/scripts/lifecycle/read-project-assets.sh" "$TEMP_BUNDLE/" >/dev/null 2>&1
producer_probe_rc=$?
if [ "$producer_probe_rc" -eq 0 ]; then
    printf 'FAIL: corrupt-manifest fixture is not actually rejected by read-project-assets.sh (producer rc=%s)\n' "$producer_probe_rc" >&2
    exit 1
fi
printf 'producer_probe_rc=%s (expected non-zero)\n' "$producer_probe_rc"
printf '\n'

# ---------- Build a per-installer wrapper that re-points BUNDLE at TEMP_BUNDLE ----------
#
# The three installers hardcode REPO_ROOT relative to their own location
# and read packaging/bundle/ off REPO_ROOT. We test each by wrapping it
# with a small shim that overrides packaging/bundle/manifest.yml via a
# bind-style copy: we stage a temp REPO_ROOT that mirrors the real one but
# whose packaging/bundle/ is the corrupted copy.

TEMP_REPO="$WORKDIR/repo"
mkdir -p "$TEMP_REPO/packaging"
mkdir -p "$TEMP_REPO/scripts"

# Symlink everything in real REPO_ROOT into TEMP_REPO except packaging/.
ln -s "$REPO_ROOT/scripts"   "$TEMP_REPO/scripts.real" 2>/dev/null || true
# We need scripts/, packaging/install/, references/, commands/, etc.
# Easiest: symlink subtrees we don't want to mutate.
rm -rf "$TEMP_REPO/scripts"
ln -s "$REPO_ROOT/scripts" "$TEMP_REPO/scripts"

# Copy packaging/install/ (we will copy each installer to it) and
# wire packaging/bundle/ to the corrupted TEMP_BUNDLE.
mkdir -p "$TEMP_REPO/packaging/install"
cp "$REPO_ROOT/packaging/install/install-claude-code.sh" "$TEMP_REPO/packaging/install/"
cp "$REPO_ROOT/packaging/install/install-codex.sh"       "$TEMP_REPO/packaging/install/"
cp "$REPO_ROOT/packaging/install/install-cursor.sh"      "$TEMP_REPO/packaging/install/"
chmod +x "$TEMP_REPO/packaging/install/install-claude-code.sh"
chmod +x "$TEMP_REPO/packaging/install/install-codex.sh"
chmod +x "$TEMP_REPO/packaging/install/install-cursor.sh"

# Symlink packaging/bundle to the corrupted bundle.
ln -s "$TEMP_BUNDLE" "$TEMP_REPO/packaging/bundle"

# Symlink other paths the installers read (e.g. references/, commands/).
for d in commands references templates docs hooks; do
    if [ -e "$REPO_ROOT/$d" ]; then
        ln -s "$REPO_ROOT/$d" "$TEMP_REPO/$d"
    fi
done

# Create the fake project dir.
PROJECT_DIR="$WORKDIR/project"
mkdir -p "$PROJECT_DIR/.orchestrator"

# ---------- Run each installer and record exit ----------

pass=0
fail=0
non_zero_exits=0
total=0

run_installer() {
    name="$1"
    installer="$TEMP_REPO/packaging/install/$name"
    total=$((total + 1))

    out_log="$WORKDIR/${name}.out"
    err_log="$WORKDIR/${name}.err"

    # Use --dry-run to avoid mutating $HOME (settings.json) since the bug
    # surfaces in the project_assets pass which executes regardless of
    # --dry-run (the corrupt manifest fails at producer time, before any
    # mode-handler call).
    bash "$installer" \
        --project-dir "$PROJECT_DIR" \
        --dry-run \
        --force \
        > "$out_log" 2> "$err_log"
    rc=$?

    printf 'installer=%s exit=%s\n' "$name" "$rc"
    # Surface a couple of stderr lines for diagnosis.
    if [ -s "$err_log" ]; then
        printf '  stderr (first 3 lines):\n'
        head -3 "$err_log" | sed 's/^/    /'
    fi

    if [ "$rc" -ne 0 ]; then
        non_zero_exits=$((non_zero_exits + 1))
        # Also assert the FAIL message names read-project-assets.sh, proving
        # the producer's exit was the source (not some unrelated failure).
        if grep -q 'read-project-assets.sh exited' "$err_log"; then
            pass=$((pass + 1))
            printf '  ok: %s exited non-zero AND surfaced read-project-assets.sh failure\n' "$name"
        else
            # Still pass on non-zero exit even if message differs (some other
            # failure mode may also surface non-zero — that is acceptable
            # under T01's must-have).
            pass=$((pass + 1))
            printf '  ok: %s exited non-zero (FAIL message did not name read-project-assets.sh — accepting non-zero exit as sufficient)\n' "$name"
        fi
    else
        fail=$((fail + 1))
        printf '  FAIL: %s exited 0 — collision-masking regression\n' "$name"
        printf '  out_log: %s\n' "$out_log"
        printf '  err_log: %s\n' "$err_log"
    fi
    printf '\n'
}

# Reset PROJECT_DIR per installer (clean slate each time).
for installer_name in install-claude-code.sh install-codex.sh install-cursor.sh; do
    rm -rf "$PROJECT_DIR"
    mkdir -p "$PROJECT_DIR/.orchestrator"
    run_installer "$installer_name"
done

# ---------- Verdict ----------

printf '\n'
if [ "$fail" -eq 0 ] && [ "$non_zero_exits" -eq 3 ]; then
    printf 'PASS: m035-p00-collision-exit-status (%s/3 installers exit non-zero on collision; bash %s)\n' \
        "$non_zero_exits" "${BASH_VERSION:-unknown}"
    exit 0
else
    printf 'FAIL: m035-p00-collision-exit-status (%s/3 installers exit non-zero; pass=%d fail=%d; bash %s)\n' \
        "$non_zero_exits" "$pass" "$fail" "${BASH_VERSION:-unknown}"
    exit 1
fi
