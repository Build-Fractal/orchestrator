#!/usr/bin/env bash
# scripts/lifecycle/before-commit.sh -- Orchestrator pre-commit lifecycle hook.
#
# M008 enrolled the before-commit lifecycle event in
# packaging/bundle/hooks/before-commit.json with command
# "bash scripts/lifecycle/before-commit.sh", but the script itself was
# never authored on disk. M025/P01 + M028/P02/T02 keep the runtime
# adapter emitting an absolute-path hook command pointing at this
# file's runtime-stable copy under ${HOME}/.claude/orchestrator-hooks/
# (T03 stages it there).
#
# Until a real verification-ladder pre-commit gate ships, this hook is
# a permissive no-op: it returns 0 unconditionally so the underlying
# `git commit` invocation proceeds. Wiring genuine pre-commit
# verification is out of scope for M028; this stub exists solely so
# the staged-payload contract has a real on-disk source to copy and
# the post-install hooks dir does not 404 when Claude Code's hook
# runner spawns this command.
#
# M009 FR-5 (2026-06-06): this script is ALSO consumed as a git
# `.git/hooks/pre-commit` gate under the Cursor install path (wired by
# scripts/lifecycle/install-git-pre-commit.sh, which propagates this
# script's exit code). Cursor has no CC-style PreToolUse-on-bash event,
# so the git pre-commit is the runtime-appropriate before-commit gate.
# CONSEQUENCE: if real verification is ever wired in here, it MUST stay
# milestone-aware and fail OPEN (exit 0) outside an active milestone /
# in an ordinary consumer repo — a non-zero exit here will block EVERY
# commit in every Cursor consumer repo via the pre-commit hook.
#
# Bash 3.2 compatible. No assoc-arrays, no array-from-stdin builtins.
# AD-19 single-script-file flat shape. AP-009 clean (no compound
# chains exceeding 2 connectors).

set -u

# Reserved for future verification-ladder integration. The hook reads
# Claude Code's PreToolUse JSON payload from stdin under the Bash
# matcher; until the verification gate ships, we ignore the payload
# and pass the Bash invocation through.
exit 0
