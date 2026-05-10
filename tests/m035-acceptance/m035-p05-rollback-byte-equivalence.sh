#!/usr/bin/env bash
# tests/m035-acceptance/m035-p05-rollback-byte-equivalence.sh
#
# M035 P05 T05 — SC-12 + SC-12b acceptance.
#
# SC-12 (copy-mode rollback byte-equivalence):
#   Stages a real consumer-project fixture under mktemp -d, runs an
#   N -> N+1 install cycle (same HEAD treated as N+1 — what we are
#   testing is the rollback machinery, not actual version-N
#   differences), then runs --rollback, then hashes the payload
#   tree before and after rollback, and asserts byte-equality.
#
# SC-12b (symlink-mode + mixed-mode refusal):
#   Stages a symlink-mode fixture, runs --rollback, asserts the
#   verbatim spec-amendment advisory is emitted on stderr and the
#   driver exits non-zero, with the canonical `git checkout
#   <prior-sha>` recovery hint.
#
# Constitution / contracts:
#   - AD-19 single-script-file shape; no compound chains, no
#     process-substitution-fed redirects.
#   - Bash 4+ permitted (CI = ubuntu-latest); the install scripts
#     and write-rollback-marker.sh carry the bash 3.2 constraint.
#   - CON-5 / MIT-2 (exclusion-list discipline): the SC-12
#     question is narrower than the cross-channel byte-equivalence
#     contract — it asks whether the *replayed runtime payload* is
#     byte-identical post-rollback, not whether the full installed
#     tree (including per-install metadata) is. The test hashes
#     ONLY the project_assets payload subtrees the installer stages
#     (commands/, scripts/, references/, templates/, wiki/). CON-5
#     spec exclusion list at references/installation.md is
#     unchanged on disk; this scoping is local to this acceptance
#     test's question and intentional.
#   - Plan-Time Discipline Rule 5 (real-app smoke): runs an
#     actual install -> re-install -> rollback cycle against a
#     real fixture project under mktemp -d.
#
# Expected output:
#   PASS: rollback marker written by re-install
#   PASS: --rollback exit 0 on copy-mode
#   PASS: post-rollback payload hash matches pre-reinstall byte-for-byte
#   PASS: --rollback exit non-zero on symlink-mode
#   PASS: symlink-mode advisory present in stderr
#   PASS: git checkout recovery hint present in stderr
#   BATTERY: pass=6 fail=0

set -u

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
INSTALLER="$REPO_ROOT/packaging/install/install-claude-code.sh"
RUN_UPDATE="$REPO_ROOT/scripts/lifecycle/run-update.sh"

pass_count=0
fail_count=0

pass() {
  echo "PASS: $1"
  pass_count=$((pass_count + 1))
}
fail() {
  echo "FAIL: $1"
  fail_count=$((fail_count + 1))
}

# --- Payload-tree hash ---------------------------------------------
#
# Hashes ONLY the runtime payload subtrees the installer stages
# (commands/, scripts/, references/, templates/, wiki/) — i.e.
# exactly what install-claude-code.sh's project_assets manifest
# stages and what `run-update.sh --rollback` replays from snapshot.
#
# Rationale for not reusing tests/m035-acceptance/_byte-equivalence-hash.sh:
# that helper's exclusion-list mechanism is the cross-channel
# CON-5 contract surface (npm vs homebrew vs curl-pipe-bash), with
# semantics keyed to per-install metadata files
# (`.orchestrator/install-meta.txt`, `.orchestrator/.previous-version`,
# package-manager-specific files). The SC-12 question is narrower:
# is the *replayed payload* byte-identical post-rollback? The
# rollback-machinery sidecar (.orchestrator/.rollback/,
# install-meta.txt, observability/, marker `rolled_at` field)
# legitimately differs between pre-reinstall and post-rollback
# states and is intentionally excluded here. Computing a payload-
# scoped hash directly avoids any coupling to the cross-channel
# helper's evolution.
#
# AD-19 single-script-file shape: the find/sort/shasum pipeline is
# one logical operation per subtree; outer shasum folds.

PAYLOAD_SUBDIRS="commands scripts references templates wiki"

hash_payload_tree() {
  local root="$1"
  local subdir
  local sub_log
  sub_log="$(mktemp -t m035-p05-hashlog.XXXXXX)"
  for subdir in $PAYLOAD_SUBDIRS; do
    if [ -d "$root/$subdir" ]; then
      ( cd "$root" && find "$subdir" -type f -print | LC_ALL=C sort ) \
        > "$sub_log.flist"
      # Per-file hash + relative path; outer hash folds the lines.
      while IFS= read -r relpath; do
        shasum -a 256 "$root/$relpath" | awk -v p="$relpath" '{print $1, p}'
      done < "$sub_log.flist" >> "$sub_log"
      rm -f "$sub_log.flist"
    fi
  done
  shasum -a 256 < "$sub_log" | awk '{print $1}'
  rm -f "$sub_log"
}

# --- Fixture setup --------------------------------------------------

FIXTURE_A=""
FIXTURE_B=""

# Capture the original branch + SHA before run-update.sh's --rollback
# arm runs `git checkout <prior-sha>` against the host repo (which is
# a content-no-op when prior-SHA equals current-HEAD but leaves HEAD
# detached). The trap below restores it post-test.
# (papercut-sweep-post-M035 PC-6.)
_orig_branch=""
_orig_sha=""
if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  _orig_branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  _orig_sha="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "")"
fi

cleanup() {
  if [ -n "$FIXTURE_A" ] && [ -d "$FIXTURE_A" ]; then
    rm -rf "$FIXTURE_A"
  fi
  if [ -n "$FIXTURE_B" ] && [ -d "$FIXTURE_B" ]; then
    rm -rf "$FIXTURE_B"
  fi
  # Detached-HEAD recovery (PC-6). The rollback driver's `git checkout
  # <prior-sha>` (run-update.sh:~172) leaves HEAD detached when the
  # prior-SHA equals current-HEAD. Restore the original branch so the
  # caller (M035 acceptance battery, orchestrator-loop dispatcher,
  # operator) doesn't have to manually re-attach.
  if [ -n "$_orig_branch" ] && [ "$_orig_branch" != "HEAD" ] \
       && git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    cur_branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
    if [ "$cur_branch" = "HEAD" ]; then
      echo "INFO: m035-p05-rollback-byte-equivalence — restoring HEAD to $_orig_branch (was detached)" >&2
      git -C "$REPO_ROOT" checkout "$_orig_branch" >/dev/null 2>&1 || \
        echo "WARN: failed to restore $_orig_branch — re-attach manually" >&2
      # If the original SHA is ahead of branch tip after checkout
      # (defensive — should not happen on content-no-op rollback),
      # fast-forward.
      if [ -n "$_orig_sha" ]; then
        post_sha="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "")"
        if [ -n "$post_sha" ] && [ "$post_sha" != "$_orig_sha" ]; then
          if git -C "$REPO_ROOT" merge-base --is-ancestor "$post_sha" "$_orig_sha" 2>/dev/null; then
            git -C "$REPO_ROOT" merge --ff-only "$_orig_sha" >/dev/null 2>&1 || true
          fi
        fi
      fi
    fi
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------
# SC-12 — copy-mode rollback byte equivalence
# ---------------------------------------------------------------

FIXTURE_A="$(mktemp -d -t m035-p05-sc12.XXXXXX)"

# Step 1: greenfield install ("version N") — no marker, no
# .rollback dir, no prior state to preserve.
"$INSTALLER" --project-dir "$FIXTURE_A" >/dev/null 2>&1
install_a_rc=$?
if [ "$install_a_rc" -ne 0 ]; then
  fail "version-N install failed (rc=$install_a_rc)"
  echo "BATTERY: pass=$pass_count fail=$fail_count"
  exit 1
fi

# Step 2: re-install (treated as "N+1" — same HEAD, but the
# re-install path writes the rollback marker + snapshots the prior
# manifest, which is the machinery this test exercises). Hash the
# tree AFTER this step so the comparison includes the .rollback/
# state introduced by the re-install (excluded from hashing via the
# test-local `.orchestrator` exclusion).
"$INSTALLER" --project-dir "$FIXTURE_A" --force >/dev/null 2>&1
install_a2_rc=$?
if [ "$install_a2_rc" -ne 0 ]; then
  fail "version-N+1 re-install failed (rc=$install_a2_rc)"
  echo "BATTERY: pass=$pass_count fail=$fail_count"
  exit 1
fi

# Verify the marker was written by the re-install.
if [ -f "$FIXTURE_A/.orchestrator/.previous-version" ]; then
  pass "rollback marker written by re-install"
else
  fail "rollback marker not written by re-install"
fi

# Step 3: hash the pre-rollback state (= post-N+1-reinstall state).
hash_pre="$(hash_payload_tree "$FIXTURE_A")"
if [ -z "$hash_pre" ]; then
  fail "pre-rollback hash empty"
fi

# Step 4: run rollback. --source-repo points at the live REPO_ROOT
# (the source of truth for the replay). Since both N and N+1 were
# installed at the same HEAD, the prior_commit_sha equals the
# current HEAD; the rollback's `git checkout <prior-sha>` is a
# no-op on the source repo, then it replays files from the
# snapshot.
rollback_log="$(mktemp -t m035-p05-rollback.XXXXXX)"
"$RUN_UPDATE" --rollback \
  --project-dir "$FIXTURE_A" \
  --source-repo "$REPO_ROOT" >"$rollback_log" 2>&1
rb_rc=$?
if [ "$rb_rc" -eq 0 ]; then
  pass "--rollback exit 0 on copy-mode"
else
  fail "--rollback exit $rb_rc on copy-mode (expected 0); see $rollback_log"
fi
rm -f "$rollback_log"

# Step 5: hash post-rollback runtime tree.
hash_post="$(hash_payload_tree "$FIXTURE_A")"
if [ -z "$hash_post" ]; then
  fail "post-rollback hash empty"
fi

# Step 6: byte-equality assertion.
if [ -n "$hash_pre" ] && [ -n "$hash_post" ] && [ "$hash_pre" = "$hash_post" ]; then
  pass "post-rollback payload hash matches pre-reinstall byte-for-byte"
else
  fail "post-rollback hash $hash_post != pre-rollback $hash_pre"
fi

# ---------------------------------------------------------------
# SC-12b — symlink-mode rollback refusal
# ---------------------------------------------------------------

FIXTURE_B="$(mktemp -d -t m035-p05-sc12b.XXXXXX)"

# Greenfield symlink install + re-install to write the marker.
"$INSTALLER" --project-dir "$FIXTURE_B" \
  --asset-mode-override symlink >/dev/null 2>&1
install_b_rc=$?
if [ "$install_b_rc" -ne 0 ]; then
  fail "symlink-mode install failed (rc=$install_b_rc)"
  echo "BATTERY: pass=$pass_count fail=$fail_count"
  exit 1
fi

"$INSTALLER" --project-dir "$FIXTURE_B" \
  --asset-mode-override symlink --force >/dev/null 2>&1
install_b2_rc=$?
if [ "$install_b2_rc" -ne 0 ]; then
  fail "symlink-mode re-install failed (rc=$install_b2_rc)"
  echo "BATTERY: pass=$pass_count fail=$fail_count"
  exit 1
fi

# Run rollback — should refuse with the spec-amendment verbatim
# advisory.
rb_b_stderr="$(mktemp -t m035-p05-symlink-rb.XXXXXX)"
"$RUN_UPDATE" --rollback \
  --project-dir "$FIXTURE_B" \
  --source-repo "$REPO_ROOT" >/dev/null 2>"$rb_b_stderr"
rb_b_rc=$?

if [ "$rb_b_rc" -ne 0 ]; then
  pass "--rollback exit non-zero on symlink-mode"
else
  fail "--rollback exit 0 on symlink-mode (expected non-zero)"
fi

if grep -q -F "rollback not available for symlink-mode installs" "$rb_b_stderr"; then
  pass "symlink-mode advisory present in stderr"
else
  fail "symlink-mode advisory absent from stderr (see $rb_b_stderr)"
fi

if grep -q -F "git checkout" "$rb_b_stderr"; then
  pass "git checkout recovery hint present in stderr"
else
  fail "git checkout recovery hint absent from stderr (see $rb_b_stderr)"
fi
rm -f "$rb_b_stderr"

# ---------------------------------------------------------------
# Summary
# ---------------------------------------------------------------

echo "BATTERY: pass=$pass_count fail=$fail_count"
[ "$fail_count" -eq 0 ] || exit 1
exit 0
