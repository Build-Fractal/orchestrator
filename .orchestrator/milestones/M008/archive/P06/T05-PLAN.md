---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P06"
milestone: "M008"
name: "Bash 3.2 compat scan + hermetic integration e2e"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01 delivered `packaging/SKILL.md` + 12 skills + `generate-skills.sh`.
- T02 delivered `packaging/bundle/` with manifest, skills, hooks, config, README, and `build-bundle.sh`.
- T03 delivered three installers + three hermetic installer tests + interface check.
- T04 delivered `scripts/lifecycle/check-update.sh` + offline-safe test.
- P05's `scripts/verify/m008-p05-bash32-compat.sh` provides a comment-aware compat-scan template.

## Description

Close out P06 with two gates:

1. **Bash 3.2 compatibility scan** — ensure every new shell script in this phase is free of bash 4+ constructs (`declare -A`, `mapfile`, `readarray`, `${var,,}`, `${var^^}`, `&>`, process substitution as syntax) and AD-19 forbidden shapes. Reuse the comment-aware scan pattern from P05 (`grep -vE '^[[:space:]]*#'`).

2. **Hermetic end-to-end integration test** — simulates the full developer experience. In a single temp directory: regenerate skills, rebuild bundle, run claude-code installer with hermetic HOME, verify all 12 skills land under `$FIXTURE_HOME/.claude/commands/`, verify hooks fragment lands under `$FIXTURE_HOME/.claude/settings.json`, verify the default config lands under the hermetic project state root, then run `check-update.sh` and verify the three required key=value lines. Cleanup on exit.

## Steps

### 1. `scripts/verify/m008-p06-bash32-compat.sh`

Pattern mirrors P05's compat scan. Target file list:

```
packaging/skills/generate-skills.sh
packaging/bundle/build-bundle.sh
packaging/install/install-claude-code.sh
packaging/install/install-codex.sh
packaging/install/install-cursor.sh
scripts/lifecycle/check-update.sh
scripts/verify/m008-p06-*.sh
```

For each file, run a comment-aware grep for forbidden constructs:

```bash
#!/usr/bin/env bash
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

FILES="
$REPO_ROOT/packaging/skills/generate-skills.sh
$REPO_ROOT/packaging/bundle/build-bundle.sh
$REPO_ROOT/packaging/install/install-claude-code.sh
$REPO_ROOT/packaging/install/install-codex.sh
$REPO_ROOT/packaging/install/install-cursor.sh
$REPO_ROOT/scripts/lifecycle/check-update.sh
"

# Also include scripts/verify/m008-p06-*.sh via glob
for f in "$REPO_ROOT/scripts/verify/m008-p06-"*.sh; do
  FILES="$FILES
$f"
done

FAIL=0
for f in $FILES; do
  [ -f "$f" ] || continue

  # Strip comment lines before checking
  stripped="$(grep -vE '^[[:space:]]*#' "$f" || true)"

  for pattern in 'declare -A' 'mapfile' 'readarray' '\$\{[a-zA-Z_][a-zA-Z_0-9]*,,\}' '\$\{[a-zA-Z_][a-zA-Z_0-9]*\^\^\}'; do
    if printf '%s\n' "$stripped" | grep -qE "$pattern"; then
      echo "FAIL: $f uses forbidden bash 4+ construct: $pattern" >&2
      FAIL=1
    fi
  done
done

if [ $FAIL -eq 0 ]; then
  echo "PASS: all P06 shell scripts bash 3.2 compatible"
  exit 0
else
  exit 1
fi
```

Note: avoid the `$(cmd | pipe)` shape in the scan itself. Capture `grep` output via `printf` pipelines that stay outside `$()`, or write results to a temp file and read them back.

### 2. `scripts/verify/m008-p06-integration-e2e.sh`

End-to-end flow:

```bash
#!/usr/bin/env bash
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

FIXTURE_HOME="$(mktemp -d)"
FIXTURE_PROJ="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"' EXIT

# Step 1: regenerate skills (idempotency)
bash "$REPO_ROOT/packaging/skills/generate-skills.sh" > /dev/null || {
  echo "FAIL: generate-skills.sh failed" >&2
  exit 1
}

# Step 2: rebuild bundle (--check confirms layout matches)
bash "$REPO_ROOT/packaging/bundle/build-bundle.sh" --check > /dev/null || {
  echo "FAIL: build-bundle.sh --check failed" >&2
  exit 1
}

# Step 3: hermetic claude-code install (dry-run first, then real)
out="$(mktemp)"
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/packaging/install/install-claude-code.sh" \
  --project-dir "$FIXTURE_PROJ" --dry-run > "$out" 2>&1 || {
  echo "FAIL: installer dry-run exited non-zero" >&2
  cat "$out" >&2
  exit 1
}

grep -q '^would_write=' "$out" || {
  echo "FAIL: dry-run produced no would_write= lines" >&2
  exit 1
}

HOME="$FIXTURE_HOME" bash "$REPO_ROOT/packaging/install/install-claude-code.sh" \
  --project-dir "$FIXTURE_PROJ" > "$out" 2>&1 || {
  echo "FAIL: real install exited non-zero" >&2
  cat "$out" >&2
  exit 1
}

# Step 4: verify 12 skills landed under hermetic HOME
skill_count=0
for f in "$FIXTURE_HOME/.claude/commands/orchestrator-"*.md; do
  [ -f "$f" ] && skill_count=$(( skill_count + 1 ))
done

if [ "$skill_count" -ne 12 ]; then
  echo "FAIL: expected 12 skills under hermetic HOME, found $skill_count" >&2
  exit 1
fi

# Step 5: verify default config landed in project state root
STATE_ROOT="$(ORCHESTRATOR_ROOT='' bash "$REPO_ROOT/scripts/state/resolve-root.sh" --project-dir "$FIXTURE_PROJ" 2>/dev/null || echo "$FIXTURE_PROJ/.orchestrator")"

test -f "$STATE_ROOT/config.yml" || {
  echo "FAIL: default config not staged to $STATE_ROOT/config.yml" >&2
  exit 1
}

# Step 6: check-update runs offline, emits required keys
upd="$(mktemp)"
bash "$REPO_ROOT/scripts/lifecycle/check-update.sh" \
  --remote-url 'https://speckit.example.invalid/none' --timeout 2 > "$upd" 2>&1

grep -q '^installed_version=' "$upd" || { echo "FAIL: no installed_version" >&2; exit 1; }
grep -q '^latest_version=' "$upd" || { echo "FAIL: no latest_version" >&2; exit 1; }
grep -q '^update_available=' "$upd" || { echo "FAIL: no update_available" >&2; exit 1; }

echo "PASS: P06 integration e2e — 12 skills installed, config staged, check-update offline-safe"
```

### 3. Run the full must-haves verification

After the two gate scripts above pass, run the phase-level verifier:

```
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M008/phases/P06
```

Expected: all 11 truth checks + all artifacts + all key links return PASS.

## Must-Haves

Addresses:

- Bash 3.2 compat must-have covering every new P06 shell script.
- Integration e2e must-have covering package → install → config → check-update.

## Verification

```
bash scripts/verify/m008-p06-bash32-compat.sh
bash scripts/verify/m008-p06-integration-e2e.sh
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M008/phases/P06
```

Expected output:

```
PASS: all P06 shell scripts bash 3.2 compatible
PASS: P06 integration e2e — 12 skills installed, config staged, check-update offline-safe
PASS: all phase must-haves verified
```

## Inputs

### From Previous Tasks

- `packaging/skills/generate-skills.sh` (from T01) — re-invoked to confirm idempotent regeneration.
- `packaging/bundle/build-bundle.sh` (from T02) — re-invoked with `--check` to confirm layout.
- `packaging/install/install-claude-code.sh` (from T03):
  - Key API: `--project-dir PATH --dry-run` emits `would_write=` lines; without `--dry-run`, writes under `$HOME/.claude/` and emits `SUMMARY:` line.
- `scripts/lifecycle/check-update.sh` (from T04):
  - Key API: emits `installed_version=`, `latest_version=`, `update_available=` lines on stdout; exits 0 even when remote is unreachable.

### From Disk (Pre-existing)

- `scripts/state/resolve-root.sh` (P04) — used to resolve the hermetic project's state root when asserting config placement.
- `scripts/verify/check-must-haves.sh` — phase-level verifier that consumes `P06-PLAN.md` and runs every `Check:` command.
- `scripts/verify/m008-p05-bash32-compat.sh` — P05's scan, used as a structural template for the P06 scan.

## Constraints

- Compat scan must be comment-aware (strip comment lines before pattern-matching) so that documentation of forbidden constructs does not trigger false positives (MEM004 / P05 lesson).
- E2E test MUST be fully hermetic — zero writes outside `$FIXTURE_HOME` / `$FIXTURE_PROJ`. Trap-based cleanup mandatory.
- Bash 3.2 compat applies to the scan and e2e scripts themselves.
- AD-19 shapes: no `$(cmd | pipe)`, no subshell sourcing, no process substitution. Capture intermediate command output in temp files and read them back with `grep`/`read`.
- No python, no jq.

## Expected Output

- `scripts/verify/m008-p06-bash32-compat.sh` — compat scan (mode 0755).
- `scripts/verify/m008-p06-integration-e2e.sh` — e2e test (mode 0755, 30+ lines).

After this task, `bash scripts/state/derive-phase.sh .specify/orchestrator/milestones/M008` should transition to a state where P06 is marked complete (task summaries present) and the phase is ready for `speckit.orchestrator.verify`.
