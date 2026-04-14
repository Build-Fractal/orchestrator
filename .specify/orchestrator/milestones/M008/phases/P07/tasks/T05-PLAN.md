---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P07"
milestone: "M008"
name: "Bash 3.2 compat + hermetic integration e2e"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01 produced `scripts/lifecycle/detect-project.sh`.
- T02 produced `templates/project-instruction.md` + `commands/init.md`.
- T03 produced `scripts/lifecycle/init-project.sh`.
- T04 produced `scripts/lifecycle/reinit-handler.sh`.
- P05 established the comment-aware Bash 3.2 compat scan pattern (`grep -vE '^[[:space:]]*#'` excludes comment lines before searching for forbidden constructs).
- P06 established the `m008-p06-bash32-compat.sh` reference implementation.

## Description

Create the final two gates for P07:

1. **`scripts/verify/m008-p07-bash32-compat.sh`** — comment-aware compat scan across all P07 shell scripts. Mirrors the P05/P06 pattern.
2. **`scripts/verify/m008-p07-integration-e2e.sh`** — end-to-end hermetic integration test covering the full onboarding story: fresh init → reinit preserves context → `--force` resets → wall-clock under 120s.
3. **`scripts/verify/m008-p07-hermetic-only.sh`** — static check that every P07 verification script uses `mktemp -d` fixtures (no real-HOME writes).

## Steps

### 1. `scripts/verify/m008-p07-bash32-compat.sh`

Mirror the P06 pattern. Scan the new scripts; exclude comment lines before matching forbidden constructs.

```bash
#!/usr/bin/env bash
# scripts/verify/m008-p07-bash32-compat.sh
# Comment-aware Bash 3.2 compatibility scan for P07 shell scripts.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

FILES="
scripts/lifecycle/detect-project.sh
scripts/lifecycle/init-project.sh
scripts/lifecycle/reinit-handler.sh
"

# Forbidden Bash 4+ constructs. These are ERE patterns.
FORBIDDEN="declare -A|readarray|mapfile|\\\$\\{[A-Za-z_][A-Za-z_0-9]*,,\\}|\\\$\\{[A-Za-z_][A-Za-z_0-9]*\\^\\^\\}"

failed=0
for rel in $FILES; do
  f="$REPO_ROOT/$rel"
  if [ ! -f "$f" ]; then
    echo "FAIL: missing file $rel" >&2
    failed=1
    continue
  fi
  # Strip comment lines (whole-line) before scanning.
  stripped="$(grep -vE '^[[:space:]]*#' "$f" || true)"
  if echo "$stripped" | grep -qE "$FORBIDDEN"; then
    echo "FAIL: $rel contains a forbidden Bash 4+ construct" >&2
    echo "$stripped" | grep -nE "$FORBIDDEN" >&2
    failed=1
  fi
done

if [ $failed -eq 0 ]; then
  echo "PASS: all P07 shell scripts are Bash 3.2 compatible"
  exit 0
fi
exit 1
```

### 2. `scripts/verify/m008-p07-hermetic-only.sh`

Static scan: every P07 verification script that invokes `init-project.sh` or `reinit-handler.sh` must also mention `mktemp -d` and must NOT reference `$HOME/` as a write target without first setting `HOME=`.

```bash
#!/usr/bin/env bash
# scripts/verify/m008-p07-hermetic-only.sh
# Static scan: every P07 verification script that exercises init must use hermetic fixtures.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERIFY_DIR="$REPO_ROOT/scripts/verify"

failed=0
for f in "$VERIFY_DIR"/m008-p07-*.sh; do
  base="$(basename "$f")"
  # Exempt static-only checks (no init/reinit invocation).
  case "$base" in
    m008-p07-bash32-compat.sh|\
    m008-p07-hermetic-only.sh|\
    m008-p07-detect-project-contract.sh|\
    m008-p07-detect-project-matrix.sh|\
    m008-p07-project-instruction-template.sh|\
    m008-p07-init-command-doc.sh|\
    m008-p07-init-interface.sh)
      continue ;;
  esac

  # Must use mktemp -d.
  if ! grep -q 'mktemp -d' "$f"; then
    echo "FAIL: $base does not use mktemp -d fixtures" >&2
    failed=1
  fi

  # Must set HOME= before invoking init-project.sh (if it invokes init).
  if grep -q 'init-project.sh' "$f"; then
    if ! grep -q 'HOME="\?\$FIXTURE_HOME' "$f" && ! grep -q 'HOME=\$FIXTURE_HOME' "$f" && ! grep -q 'HOME="\?\$(mktemp' "$f"; then
      echo "FAIL: $base invokes init-project.sh without setting HOME= to a fixture" >&2
      failed=1
    fi
  fi
done

if [ $failed -eq 0 ]; then
  echo "PASS: all P07 integration tests are hermetic"
  exit 0
fi
exit 1
```

### 3. `scripts/verify/m008-p07-integration-e2e.sh`

Full onboarding flow with wall-clock budget. This is the canonical demo-sentence check: fresh project → init → reinit preserves → --force resets, all under 120s.

```bash
#!/usr/bin/env bash
# scripts/verify/m008-p07-integration-e2e.sh
# Full P07 onboarding e2e: fresh init → reinit preserves custom → --force resets.
# Hermetic HOME + project. Target wall-clock under 120s.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_HOME="$(mktemp -d)"
FIXTURE_PROJ="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_HOME" "$FIXTURE_PROJ"' EXIT

START_TS="$(date +%s)"

# Fixture: a minimal Node project with GitHub Actions.
echo '{"name":"e2e-fixture"}' > "$FIXTURE_PROJ/package.json"
mkdir -p "$FIXTURE_PROJ/.github/workflows"
touch "$FIXTURE_PROJ/.github/workflows/ci.yml"

# --- 1. Fresh init ---
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
  --project-dir "$FIXTURE_PROJ" --runtime claude-code > /tmp/p07-e2e.1.out 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "FAIL: fresh init exited $rc" >&2
  cat /tmp/p07-e2e.1.out >&2
  exit 1
fi

test -f "$FIXTURE_PROJ/CLAUDE.md" || { echo "FAIL: CLAUDE.md missing after fresh init" >&2; exit 1; }
test -f "$FIXTURE_PROJ/.orchestrator/config.yml" || { echo "FAIL: config.yml missing after fresh init" >&2; exit 1; }
test -d "$FIXTURE_HOME/.claude/commands" || { echo "FAIL: skills not registered under hermetic HOME" >&2; exit 1; }

grep -q '{{' "$FIXTURE_PROJ/CLAUDE.md" && { echo "FAIL: unrendered {{placeholders}} in CLAUDE.md" >&2; exit 1; }
grep -q 'node' "$FIXTURE_PROJ/CLAUDE.md" || { echo "FAIL: detected language not rendered into CLAUDE.md" >&2; exit 1; }
grep -q 'github-actions' "$FIXTURE_PROJ/CLAUDE.md" || { echo "FAIL: detected ci_system not rendered" >&2; exit 1; }

# --- 2. Inject custom content + user-edited config field ---
awk '
  /^<!-- BEGIN CUSTOM -->$/ { print; print "E2E_USER_BLOCK: this must survive update."; next }
  { print }
' "$FIXTURE_PROJ/CLAUDE.md" > "$FIXTURE_PROJ/CLAUDE.md.new" && mv "$FIXTURE_PROJ/CLAUDE.md.new" "$FIXTURE_PROJ/CLAUDE.md"

grep -q 'E2E_USER_BLOCK' "$FIXTURE_PROJ/CLAUDE.md" || { echo "FAIL: could not inject E2E_USER_BLOCK" >&2; exit 1; }

echo 'user_custom_field: "e2e-must-survive"' >> "$FIXTURE_PROJ/.orchestrator/config.yml"

# --- 3. Reinit without --force: must exit 4 with REINIT: ---
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
  --project-dir "$FIXTURE_PROJ" --runtime claude-code > /tmp/p07-e2e.2.out 2>&1
rc=$?
if [ $rc -ne 4 ]; then
  echo "FAIL: second init without --force should exit 4, got $rc" >&2
  cat /tmp/p07-e2e.2.out >&2
  exit 1
fi
grep -q '^REINIT:' /tmp/p07-e2e.2.out || { echo "FAIL: no REINIT: line on second init" >&2; exit 1; }

# --- 4. Reinit update mode: preserves custom + user config field ---
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/reinit-handler.sh" \
  --project-dir "$FIXTURE_PROJ" --state-root "$FIXTURE_PROJ/.orchestrator" \
  --runtime claude-code --mode update > /tmp/p07-e2e.3.out 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "FAIL: reinit update exited $rc" >&2
  cat /tmp/p07-e2e.3.out >&2
  exit 1
fi

grep -q 'E2E_USER_BLOCK' "$FIXTURE_PROJ/CLAUDE.md" || { echo "FAIL: custom block lost after update" >&2; exit 1; }
grep -q 'user_custom_field: "e2e-must-survive"' "$FIXTURE_PROJ/.orchestrator/config.yml" || {
  echo "FAIL: user_custom_field lost after update" >&2
  cat "$FIXTURE_PROJ/.orchestrator/config.yml" >&2
  exit 1
}

# --- 5. --force resets both files ---
HOME="$FIXTURE_HOME" bash "$REPO_ROOT/scripts/lifecycle/init-project.sh" \
  --project-dir "$FIXTURE_PROJ" --runtime claude-code --force > /tmp/p07-e2e.4.out 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "FAIL: --force init exited $rc" >&2
  cat /tmp/p07-e2e.4.out >&2
  exit 1
fi

grep -q 'E2E_USER_BLOCK' "$FIXTURE_PROJ/CLAUDE.md" && {
  echo "FAIL: --force did not reset the custom block (E2E_USER_BLOCK still present)" >&2
  exit 1
}
grep -q '^SUMMARY:' /tmp/p07-e2e.4.out || { echo "FAIL: no SUMMARY line from --force init" >&2; exit 1; }

# --- 6. Wall-clock budget ---
END_TS="$(date +%s)"
ELAPSED=$((END_TS - START_TS))
if [ "$ELAPSED" -gt 120 ]; then
  echo "FAIL: e2e took ${ELAPSED}s (budget: 120s)" >&2
  exit 1
fi

echo "PASS: P07 onboarding e2e (elapsed=${ELAPSED}s, budget=120s)"
exit 0
```

### 4. Orchestrator registration note (advisory, no code change required)

This is a "final gate" pass; the M008 milestone rollup will wire `commands/init.md` into `extension.yml` and propagate it through `packaging/skills/` via the P06 generator. T05 does NOT update `extension.yml` or `packaging/` — that's milestone-level integration work after M008's final merge. T05 only verifies the P07 scripts and docs.

## Must-Haves

Addresses:

- All P07 shell scripts are Bash 3.2 compatible (comment-aware scan).
- Every integration test uses hermetic `mktemp -d` fixtures; no real-HOME writes during P07 execution.
- End-to-end onboarding story passes: fresh init → reinit preserves → `--force` resets.
- Wall-clock under 120s (SC-005 proxy — full SC-005 "5 minute first task" timing is measured at M008 rollup).

## Verification

```
bash scripts/verify/m008-p07-bash32-compat.sh
bash scripts/verify/m008-p07-hermetic-only.sh
bash scripts/verify/m008-p07-integration-e2e.sh
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M008/phases/P07
```

All must emit `PASS:` and exit 0. The must-haves check runs all per-truth `Check:` commands and aggregates.

## Inputs

### From Previous Tasks

- `scripts/lifecycle/detect-project.sh` (T01) — scanned by compat gate.
- `scripts/lifecycle/init-project.sh` (T03) — exercised by integration e2e.
- `scripts/lifecycle/reinit-handler.sh` (T04) — exercised by integration e2e.
- `templates/project-instruction.md` (T02) — rendered during e2e; assertions check rendered content.
- `commands/init.md` (T02) — doc-level checks (done in T02's own verifiers; T05 does not re-check).

### From Disk (Pre-existing)

- `scripts/verify/m008-p06-bash32-compat.sh` (P06) — reference implementation for comment-aware Bash 3.2 scan.
- `scripts/verify/m008-p05-bash32-compat.sh` (P05) — same pattern, originator.
- `scripts/verify/check-must-haves.sh` — aggregate verifier invoked after individual truth checks pass.

## Constraints

- Bash 3.2 only (for the verify scripts themselves — meta-correct).
- Hermetic only. No real-HOME writes anywhere in the e2e. Trap cleans up fixtures on exit (even on failure).
- Wall-clock budget is 120s — the e2e must complete well under that on CI hardware. If it doesn't, the init pipeline is too slow and needs profiling before M008 rollup.
- The compat scan must strip comment lines before matching forbidden constructs (comment-aware pattern from P05).
- The hermetic-only scan must be maintained — adding a new P07 verifier that exercises init without `mktemp -d` must fail this gate.

## Expected Output

- `scripts/verify/m008-p07-bash32-compat.sh` (mode 0755)
- `scripts/verify/m008-p07-hermetic-only.sh` (mode 0755)
- `scripts/verify/m008-p07-integration-e2e.sh` (40+ lines, contains `SUMMARY:`, mode 0755)

After this task completes: `bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M008/phases/P07` must emit `PASS:` for every truth in `P07-PLAN.md`.
