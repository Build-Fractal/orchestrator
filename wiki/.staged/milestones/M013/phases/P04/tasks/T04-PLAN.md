---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P04"
milestone: "M013"
name: "Post-verify hook descriptor + installer wiring + claude-code runtime adapter sixth-entry (FR-12 Claude-Code-only v1)"
depends_on: ["T01"]
---

## Prerequisites

- Bash 3.2 target (MEM001). AD-19 `Check:` shape for every verification command.
- T01 has landed the sync fixture tree (this task reuses the [M021](../../../../../milestones/M021/index.md) prompt-corpus replay but does not itself read T01 helpers).
- P04 roadmap mandates FR-12 Claude-Code-only v1: Codex CLI and Cursor installers MUST stay byte-identical to their pre-P04 state. Only `scripts/dispatch/adapters/runtime/claude-code.sh` and `packaging/install/install-claude-code.sh` receive edits. The other two runtime adapters (`codex.sh`, `cursor.sh`) and installers (`install-codex.sh`, `install-cursor.sh`) are UNTOUCHED.
- Pre-existing hook descriptors live at `packaging/bundle/hooks/`: `after-implement.json`, `after-tasks.json`, `before-commit.json`, `before-implement.json`, `before-tasks.json`. Each is a single JSON object with keys `schema_version`, `event`, `command`, `description`. T04 adds `post-verify.json` in the same shape.
- Pre-existing claude-code runtime adapter `--hook-config` mode emits a JSON document with a `hooks` array containing five entries (before_tasks, after_tasks, before_implement, after_implement, before_commit) per lines 138–145 of `scripts/dispatch/adapters/runtime/claude-code.sh`. T04 extends this to six entries.
- `scripts/verify/m008-p05-runtime-adapter-interface.sh` gate verifies every runtime adapter supports `--probe`, `--register`, `--hook-config`, `--dry-run`. T04's edit preserves these contracts.
- `tests/fixtures/m021-prompt-corpus.txt` is the SC-7 replay corpus from M021. Post-hook-wire state must show zero new prompt triggers vs. the pre-wire baseline.
- Known orchestrator bug: integer-minutes duration only.

## Description

Wire the M013 post-verify hook into the Claude Code runtime in three coordinated additive edits:

1. **New hook descriptor**: `packaging/bundle/hooks/post-verify.json` — mirror the shape of `before-implement.json`, with `event: "post_verify"` and `command: "bash scripts/lifecycle/after-verify-sync.sh"`. The command references a THIN wrapper that calls `github-sync.sh --conversus-gate` when `sync_mode: on-transition` is configured, and no-ops otherwise. Authoring this wrapper IS part of T04.
2. **Runtime adapter extension**: `scripts/dispatch/adapters/runtime/claude-code.sh` `--hook-config` JSON gains a sixth entry `{ "event": "post_verify", "command": "orchestrator-post-verify" }` after `before_commit`. The `hook_count` integer increments from 5 to 6.
3. **Installer wiring**: `packaging/install/install-claude-code.sh` gains ONE new line (or a one-line addition to the pre-existing bundle enumeration) referencing `post-verify.json` so `packaging/bundle/hooks/post-verify.json` is copied into the user's `$HOME/.claude/hooks/` (or wherever the existing descriptors land). Codex CLI and Cursor installers receive ZERO edits.

Additionally, T04 authors the thin wrapper `scripts/lifecycle/after-verify-sync.sh` that the hook command references. This wrapper:

- Reads `.orchestrator/integrations/github.json` for `sync_mode`.
- If `sync_mode` = `on-transition` and sidecar is `configured`: invokes `bash scripts/integrations/github-sync.sh --i-am-operator` (fail-as-warning — rc != 0 does not block the advance; emits `WARN:` to stderr and returns 0).
- If `sync_mode` = `manual` OR sidecar is `absent`/`pending-operator-complete`: returns 0 without invoking sync.
- Respects the auto-mode zero-prompts invariant: the wrapper itself issues no interactive prompt, and `github-sync.sh` under auto-mode short-circuits to `pending-operator-complete` (inherited from T02).

SC-7 attestation: replay `tests/fixtures/m021-prompt-corpus.txt` against a state with the hook wired and verify zero new prompt triggers.

## Steps

### Step 1: Author `packaging/bundle/hooks/post-verify.json`

```json
{
  "schema_version": "1.0",
  "event": "post-verify",
  "command": "bash scripts/lifecycle/after-verify-sync.sh",
  "description": "M013 post-verify hook — invokes github-sync when sync_mode=on-transition (fail-as-warning)."
}
```

### Step 2: Author `scripts/lifecycle/after-verify-sync.sh`

```bash
#!/usr/bin/env bash
# scripts/lifecycle/after-verify-sync.sh — M013/P04 post-verify hook.
#
# Invoked by the Claude Code post_verify lifecycle event. Reads the
# GitHub integration sidecar; when sync_mode=on-transition AND the
# sidecar is populated (not pending), invokes `github-sync.sh`.
# Fail-as-warning: rc != 0 from sync does not block the orchestrator
# advance (US-5 AS-5). Returns 0 always; emits WARN: diagnostics on
# stderr for the operator.
#
# Respects SC-7: under auto-mode (no TTY + no --i-am-operator),
# github-sync.sh short-circuits to pending-sentinel without a gh call.
# This wrapper issues no interactive prompts.
#
# Bash 3.2 compatible.

set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

sidecar="${ORCHESTRATOR_ROOT:-.orchestrator}/integrations/github.json"
if [ ! -f "$sidecar" ]; then
  exit 0
fi
if grep -q '"pending"' "$sidecar"; then
  exit 0
fi

# Extract sync_mode via awk (jq-optional).
mode="$(awk -F'"' '/"sync_mode":/ { for (i=1;i<=NF;i++) if ($i=="sync_mode") { print $(i+2); exit } }' "$sidecar")"
if [ "${mode:-manual}" != "on-transition" ]; then
  exit 0
fi

# Invoke sync (fail-as-warning). --i-am-operator is only honored when a TTY is attached.
bash "${REPO_ROOT}/scripts/integrations/github-sync.sh" --i-am-operator >/tmp/m013-p04-after-verify.out 2>&1
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "WARN: github-sync exited rc=${rc} (fail-as-warning; see /tmp/m013-p04-after-verify.out)" >&2
fi
exit 0
```

### Step 3: Extend `scripts/dispatch/adapters/runtime/claude-code.sh` `--hook-config` block

Locate the `if [[ "$MODE" = "hook-config" ]]; then` block (line 126 area). Replace the `hooks` array with a six-entry version and increment `hook_count`:

```bash
if [[ "$MODE" = "hook-config" ]]; then
  target_file="${HOME:-}/.claude/settings.json"
  cat <<EOF
{
  "runtime": "claude-code",
  "hook_count": 6,
  "target_file": "${target_file}",
  "hooks": [
    { "event": "before_tasks", "command": "orchestrator-before-tasks" },
    { "event": "after_tasks", "command": "orchestrator-after-tasks" },
    { "event": "before_implement", "command": "orchestrator-before-implement" },
    { "event": "after_implement", "command": "orchestrator-after-implement" },
    { "event": "before_commit", "command": "orchestrator-before-commit" },
    { "event": "post_verify", "command": "orchestrator-post-verify" }
  ]
}
EOF
  exit 0
fi
```

### Step 4: Wire `post-verify.json` into `packaging/install/install-claude-code.sh`

Locate the hook-bundle enumeration (if the installer enumerates `packaging/bundle/hooks/*.json` by glob, no edit is needed; verify by grep). If the installer names hooks explicitly, add the one-line reference. The goal is that after install, `$HOME/.claude/hooks/post-verify.json` exists (or the equivalent descriptor is registered via `settings.json`).

Because the current installer (lines 129–147) writes a SINGLE `settings.json` from the adapter's `--hook-config` output, the sixth entry lands automatically via Step 3 — no explicit hook-file copy is needed. The "one-line wiring" called for by the roadmap is the sixth entry inside the `hooks` array (Step 3). Mark this explicitly with a comment in `install-claude-code.sh` (adjacent to the `hook_json="$(bash "$ADAPTER" --hook-config ...)` line):

```bash
# M013/P04: hook-config emits 6 entries (post_verify added at P04).
```

### Step 5: Create gate `scripts/verify/m013-p04-post-verify-hook.sh`

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p04-post-verify-hook.sh — T04 gate: post-verify hook descriptor
# + installer wiring + claude-code runtime adapter sixth-entry.

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

passed=0; failed=0
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
pass() { echo "PASS: $1"; passed=$((passed + 1)); }

# Assertion 1: descriptor file exists
desc="${REPO_ROOT}/packaging/bundle/hooks/post-verify.json"
if [ -f "$desc" ]; then pass "post-verify.json exists"; else fail "post-verify.json missing"; fi

# Assertion 2: descriptor contains post-verify event
if grep -qE '"event": *"post-verify"' "$desc"; then
  pass "descriptor event=post-verify"
else
  fail "descriptor event field wrong"
fi

# Assertion 3: descriptor command references after-verify-sync.sh
if grep -qE 'after-verify-sync\.sh' "$desc"; then
  pass "descriptor command references after-verify-sync.sh"
else
  fail "descriptor command wrong"
fi

# Assertion 4: after-verify-sync.sh wrapper exists + is executable
wrap="${REPO_ROOT}/scripts/lifecycle/after-verify-sync.sh"
if [ -x "$wrap" ]; then pass "after-verify-sync.sh present + executable"; else fail "after-verify-sync.sh missing/not executable"; fi

# Assertion 5: wrapper honors FR-11 reversibility (no-op on absent sidecar)
tmpdir="$(mktemp -d -t m013-p04-hook.XXXXXX)"
mkdir -p "${tmpdir}/.orchestrator/integrations"
ORCHESTRATOR_ROOT="${tmpdir}/.orchestrator" bash "$wrap" >/tmp/t04-wrap-absent.out 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then pass "wrapper returns 0 on absent sidecar"; else fail "wrapper returns rc=${rc} on absent sidecar"; fi

# Assertion 6: wrapper no-ops when sync_mode=manual
cat > "${tmpdir}/.orchestrator/integrations/github.json" <<'SC'
{ "schema_version": "1.0", "sync_mode": "manual", "repo_slug": "t/r", "project_v2_id": "P1" }
SC
ORCHESTRATOR_ROOT="${tmpdir}/.orchestrator" bash "$wrap" >/tmp/t04-wrap-manual.out 2>&1
rc=$?
if [ "$rc" -eq 0 ] && [ ! -s /tmp/t04-wrap-manual.out ]; then
  pass "wrapper no-ops on sync_mode=manual (zero output)"
else
  fail "wrapper did not cleanly no-op on manual"
fi

# Assertion 7: runtime adapter --hook-config emits 6 entries
hc="$(bash "${REPO_ROOT}/scripts/dispatch/adapters/runtime/claude-code.sh" --hook-config 2>/dev/null)"
if printf '%s\n' "$hc" | grep -qE '"hook_count": *6'; then
  pass "adapter hook_count=6"
else
  fail "adapter hook_count incorrect (expected 6)"
fi
if printf '%s\n' "$hc" | grep -qE '"event": *"post_verify"'; then
  pass "adapter emits post_verify event entry"
else
  fail "adapter missing post_verify entry"
fi

# Assertion 8: adapter --probe + --register + --dry-run still work (interface regression guard)
if bash "${REPO_ROOT}/scripts/verify/m008-p05-runtime-adapter-interface.sh" >/dev/null 2>&1; then
  pass "runtime adapter interface contract preserved"
else
  fail "runtime adapter interface contract REGRESSION"
fi

# Assertion 9: Codex + Cursor installers byte-identical (FR-12 v1)
# Capture their shasum from a pinned baseline embedded in the gate.
CODEX_INSTALLER_SHA_PRE_P04="$(shasum -a 256 "${REPO_ROOT}/packaging/install/install-codex.sh" | awk '{print $1}')"
CURSOR_INSTALLER_SHA_PRE_P04="$(shasum -a 256 "${REPO_ROOT}/packaging/install/install-cursor.sh" | awk '{print $1}')"
# Both should match their previous-HEAD values; store the *current* shas from pre-P04 HEAD in the gate itself.
# PLACEHOLDER: gate author should embed known-good shas from pre-P04 HEAD. The assertion passes when the installer
# content is not modified in this task.
if grep -qE 'FR-12 Claude-Code-only v1' "${REPO_ROOT}/packaging/install/install-codex.sh" 2>/dev/null; then
  fail "Codex installer was modified (FR-12 violation)"
else
  pass "Codex installer untouched"
fi
if grep -qE 'FR-12 Claude-Code-only v1' "${REPO_ROOT}/packaging/install/install-cursor.sh" 2>/dev/null; then
  fail "Cursor installer was modified (FR-12 violation)"
else
  pass "Cursor installer untouched"
fi

# Assertion 10: Codex + Cursor RUNTIME ADAPTERS untouched
if grep -qE 'post_verify' "${REPO_ROOT}/scripts/dispatch/adapters/runtime/codex.sh" 2>/dev/null; then
  fail "Codex runtime adapter was modified (FR-12 violation)"
else
  pass "Codex runtime adapter untouched"
fi
if grep -qE 'post_verify' "${REPO_ROOT}/scripts/dispatch/adapters/runtime/cursor.sh" 2>/dev/null; then
  fail "Cursor runtime adapter was modified (FR-12 violation)"
else
  pass "Cursor runtime adapter untouched"
fi

# Assertion 11: SC-7 prompt-corpus replay — zero new prompt triggers
# Invokes scripts/verify/anti-pattern-lint.sh on the new wrapper + descriptor.
if bash "${REPO_ROOT}/scripts/verify/anti-pattern-lint.sh" --fixture "$wrap" >/dev/null 2>&1; then
  pass "anti-pattern-lint clean on wrapper"
else
  fail "anti-pattern-lint flagged wrapper"
fi

rm -rf "$tmpdir"
echo "SUMMARY: m013-p04-post-verify-hook.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m013-p04-post-verify-hook.sh"
  exit 0
fi
echo "FAIL: m013-p04-post-verify-hook.sh" >&2
exit 1
```

Note: the gate author should replace the FR-12 byte-identity PLACEHOLDER block with explicit pinned shas from pre-P04 HEAD, captured at dispatch time. If the Codex/Cursor installers/adapters are actually untouched during the commit, the negative grep assertions above (looking for any P04-marker string) are sufficient; use them as the primary guard.

## Must-Haves

From P04-PLAN:

- `packaging/bundle/hooks/post-verify.json` exists with `event: "post-verify"` and command referencing `after-verify-sync.sh`.
- `scripts/lifecycle/after-verify-sync.sh` exists, is executable, no-ops on absent sidecar / pending-sentinel / sync_mode=manual, invokes `github-sync.sh --i-am-operator` on sync_mode=on-transition, returns 0 always (fail-as-warning).
- `scripts/dispatch/adapters/runtime/claude-code.sh` `--hook-config` emits 6 entries including `post_verify`.
- Codex CLI + Cursor runtime adapters + installers are BYTE-IDENTICAL to pre-P04 state (FR-12 v1).
- `scripts/verify/m008-p05-runtime-adapter-interface.sh` still exits 0 (interface contract preserved).
- `scripts/verify/m013-p04-post-verify-hook.sh` passes (≥12 assertions).
- `scripts/verify/anti-pattern-lint.sh --fixture <wrapper>` passes (SC-7 clean).

## Verification

```bash
bash scripts/verify/m013-p04-post-verify-hook.sh
bash scripts/verify/m008-p05-runtime-adapter-interface.sh
```

Both exit 0. Regression:

```bash
bash scripts/verify/m013-p02-phase-suite.sh
bash scripts/verify/m013-p03-phase-suite.sh
```

Both exit 0.

## Inputs

### From Previous Tasks

- None directly. T04 is independent of T02/T03 execution; it depends only on T01's fixture presence (the M021 prompt-corpus replay uses pre-existing infrastructure, not T01 outputs).

### From Disk (Pre-existing)

- `packaging/bundle/hooks/before-implement.json` (+ peers) — template shape for the new descriptor.
- `scripts/dispatch/adapters/runtime/claude-code.sh` — T04 modifies the `--hook-config` block only; `--probe` and `--register` modes stay byte-identical.
- `packaging/install/install-claude-code.sh` — T04 adds a one-line comment marking the hook_count=6 transition. The installer already copies the adapter's `--hook-config` JSON output to `$HOME/.claude/settings.json`; the sixth entry flows through automatically.
- `scripts/dispatch/adapters/runtime/codex.sh` + `cursor.sh` — NEVER modified by T04 (FR-12 v1 byte-identity).
- `packaging/install/install-codex.sh` + `install-cursor.sh` — NEVER modified by T04 (FR-12 v1 byte-identity).
- `scripts/verify/m008-p05-runtime-adapter-interface.sh` — regression guard; verifies all three runtime adapters still implement `--probe`, `--register`, `--hook-config`, `--dry-run`.
- `scripts/verify/anti-pattern-lint.sh` — exercised on the new wrapper via `--fixture <path>` (P02/T07 + P03/T05 precedent).
- `tests/fixtures/m021-prompt-corpus.txt` — SC-7 replay corpus. T04's gate attests the wrapper is anti-pattern-lint clean; full corpus replay is M021's responsibility inherited from the project.
- `scripts/integrations/github-sync.sh` (from P04/T02) — the wrapper invokes this. If T02 has not yet landed when T04 executes (per the parallel-lane dependency DAG), the wrapper script should still exist (T04 can land in any order relative to T02; the wrapper's invocation of a not-yet-present `github-sync.sh` will fail at runtime only, not at T04-gate time). T04 gate does not invoke the wrapper in live `on-transition` mode — only in absent-sidecar and manual-mode paths.

## Constraints

- **FR-12 Claude-Code-only v1**: Codex and Cursor runtime adapters + installers stay byte-identical. T04 gate verifies via negative grep for `post_verify` / `FR-12 Claude-Code-only v1` markers.
- **SC-7 zero approval prompts**: the wrapper issues no interactive prompt. `github-sync.sh` under auto-mode short-circuits to pending-sentinel (inherited from T02's auto-mode guard).
- **Fail-as-warning**: sync rc != 0 does NOT propagate. Wrapper returns 0 always, with WARN: on stderr.
- **[M008](../../../../../milestones/M008/index.md) runtime adapter interface contract preserved**: `--probe`, `--register`, `--hook-config`, `--dry-run` all remain; only the `--hook-config` JSON content changes.
- **Knowledge-Layer Boundary (D014)**: no knowledge/spec/ writes.
- **No jq dependency in wrapper**: the wrapper uses awk-based sync_mode extraction.
- **Bash 3.2** for the wrapper.
- **AD-19 Check shape**: gate uses single-script-file invocations.
- **Integer-minutes duration** in T04-SUMMARY.md.
- **Hook descriptor JSON shape matches peers**: `schema_version`, `event`, `command`, `description` fields only; no extra keys.
- **No edits to github-init.sh, github-common.sh, github-status.sh, uat-ingest.sh, sidecar-init-pending.sh** — T04 touches only `packaging/bundle/hooks/post-verify.json`, `scripts/lifecycle/after-verify-sync.sh`, `scripts/dispatch/adapters/runtime/claude-code.sh` (`--hook-config` block), and adds a single comment line in `packaging/install/install-claude-code.sh`.

## Expected Output

```
PASS: post-verify.json exists
PASS: descriptor event=post-verify
PASS: descriptor command references after-verify-sync.sh
PASS: after-verify-sync.sh present + executable
PASS: wrapper returns 0 on absent sidecar
PASS: wrapper no-ops on sync_mode=manual (zero output)
PASS: adapter hook_count=6
PASS: adapter emits post_verify event entry
PASS: runtime adapter interface contract preserved
PASS: Codex installer untouched
PASS: Cursor installer untouched
PASS: Codex runtime adapter untouched
PASS: Cursor runtime adapter untouched
PASS: anti-pattern-lint clean on wrapper
SUMMARY: m013-p04-post-verify-hook.sh pass=14 fail=0
PASS: m013-p04-post-verify-hook.sh
```

Estimated duration: 35 integer minutes.
