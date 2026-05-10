---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P03"
milestone: "M012"
name: "Phase verification suite — eight gates + phase-suite orchestrator"
depends_on: ["T04"]
---

## Prerequisites

- T01 complete: `wiki/overrides/partials/comments.html` + `wiki/mkdocs.yml` Giscus wiring.
- T02 complete: `scripts/diagnostics/wiki-giscus-config-check.sh`.
- T03 complete: `scripts/diagnostics/wiki-giscus-smoke.sh`.
- T04 complete: `scripts/diagnostics/wiki-giscus-remap.sh` + `wiki/README.md` Giscus-mapping sections.
- No `scripts/verify/m012-p03-*.sh` files exist yet.

## Description

Ship the full P03 verification suite. One script per phase-plan Truth `Check:` entry, plus a phase-suite orchestrator that runs them all. Each gate is single-invocation (AD-19 compliant) so auto-mode never prompts. Every gate is read-only except the phase-suite orchestrator, which writes per-run summary state into a `/tmp` scratch location.

Eight gates:

1. `m012-p03-comments-partial.sh` — `wiki/overrides/partials/comments.html` exists, is ≥ 25 lines, contains `giscus.app/client.js`, contains at least one `data-repo-id=` attribute, and references at least three of the five Giscus data-attrs (`data-repo`, `data-category`, `data-mapping`).
2. `m012-p03-mkdocs-giscus-config.sh` — `wiki/mkdocs.yml` contains exactly one `custom_dir: overrides` line under `theme:`, an `extra:` block with five `giscus.*` keys, four of which use `!ENV` interpolation, and `mapping: "pathname"` literal. Also asserts the P01 nav marker region is syntactically intact (`# >>> M012-P01 nav` and `# <<< M012-P01 nav end` each appear exactly once).
3. `m012-p03-mapping-documented.sh` — `wiki/README.md` contains a `## Giscus mapping` heading, the word `pathname` in the section, a reference to `wiki-giscus-remap.sh`, and a reference to `wiki-giscus-smoke.sh`.
4. `m012-p03-config-loud-fail.sh` — runs `scripts/diagnostics/wiki-giscus-config-check.sh` under two fixtures: (a) all env vars unset → exit 1 + at least 4 `FAIL:` lines; (b) all env vars set to `"x"` → exit 0 + `PASS:` line.
5. `m012-p03-smoke-contract.sh` — builds a tmp fixture site with one HTML file carrying the Giscus loader and one without; runs the smoke script; asserts exit 1 + one `FAIL:` line. Then replaces the bad file with a loader-carrying page; rerun asserts exit 0.
6. `m012-p03-remap-contract.sh` — exercises the remap script in three modes: `--help` (exit 0), `--dry-run /a/ /b/` (exit 0 + `DRY-RUN:` line), `/a/` (exit 2 for odd arg count). Does not make any `gh` API calls.
7. `m012-p03-bash32-compat.sh` — every `.sh` file under `scripts/diagnostics/wiki-giscus-*.sh` and `scripts/verify/m012-p03-*.sh` is free of `declare -A`, `mapfile`, `readarray`, `${var^^}`, `${var,,}`, `<(...)`, `>(...)`, `&>` in non-comment code. Self-inclusive.
8. `m012-p03-wiki-removable.sh` — outside of `wiki/`, `scripts/wiki/`, `scripts/diagnostics/wiki-giscus-*.sh`, `scripts/verify/m012-p03-*.sh`, and `.orchestrator/milestones/M012/`, no repo file `source`s / imports / `bash`-invokes a `wiki-giscus-*` script. Mirrors the P01 self-contained gate for the P03 surface.

Plus the orchestrator:

9. `m012-p03-phase-suite.sh` — invokes all eight gates, emits one `GATE: <name> PASS|FAIL` line per gate to stdout, a `SUMMARY: <passed>/<total>` to stderr, and exits 0 only when all eight pass.

## Steps

1. **Create `scripts/verify/m012-p03-comments-partial.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p03-comments-partial.sh — M012/P03 T01 gate.
   #
   # Asserts wiki/overrides/partials/comments.html exists and carries the
   # Giscus loader script with the required data-attrs.

   set -u
   PARTIAL="wiki/overrides/partials/comments.html"

   if [ ! -f "$PARTIAL" ]; then
     printf 'FAIL: %s not found\n' "$PARTIAL" >&2; exit 1
   fi

   lines="$(wc -l < "$PARTIAL" | tr -d '[:space:]')"
   if [ "$lines" -lt 25 ]; then
     printf 'FAIL: %s too short: %d < 25 lines\n' "$PARTIAL" "$lines" >&2; exit 1
   fi

   for needle in 'giscus.app/client.js' 'data-repo=' 'data-repo-id=' 'data-category=' 'data-mapping='; do
     if ! grep -qF "$needle" "$PARTIAL"; then
       printf 'FAIL: %s missing %s\n' "$PARTIAL" "$needle" >&2; exit 1
     fi
   done

   printf 'PASS: comments partial looks well-formed (%d lines)\n' "$lines"
   exit 0
   ```

2. **Create `scripts/verify/m012-p03-mkdocs-giscus-config.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p03-mkdocs-giscus-config.sh — M012/P03 T01 gate.
   #
   # Asserts wiki/mkdocs.yml declares theme.custom_dir + extra.giscus.*
   # without breaking P01's nav-marker invariant.

   set -u
   CFG="wiki/mkdocs.yml"

   if ! grep -qE '^[[:space:]]+custom_dir:[[:space:]]+overrides' "$CFG"; then
     printf 'FAIL: %s missing "custom_dir: overrides" under theme:\n' "$CFG" >&2; exit 1
   fi

   for key in 'repo:' 'repo_id:' 'category:' 'category_id:' 'mapping:'; do
     if ! grep -qE "^[[:space:]]+${key}" "$CFG"; then
       printf 'FAIL: %s missing extra.giscus.%s\n' "$CFG" "$key" >&2; exit 1
     fi
   done

   env_count="$(grep -cE '!ENV \[GISCUS_[A-Z_]+, ""\]' "$CFG" | tr -d '[:space:]')"
   if [ "$env_count" -lt 4 ]; then
     printf 'FAIL: expected 4 !ENV interpolations, found %d\n' "$env_count" >&2; exit 1
   fi

   if ! grep -qE 'mapping:[[:space:]]*"pathname"' "$CFG"; then
     printf 'FAIL: %s mapping not set to "pathname"\n' "$CFG" >&2; exit 1
   fi

   # P01 nav markers byte-stable presence check.
   open_count="$(grep -cF '# >>> M012-P01 nav' "$CFG" | tr -d '[:space:]')"
   close_count="$(grep -cF '# <<< M012-P01 nav end' "$CFG" | tr -d '[:space:]')"
   if [ "$open_count" -ne 1 ] || [ "$close_count" -ne 1 ]; then
     printf 'FAIL: P01 nav markers corrupted (open=%d, close=%d)\n' "$open_count" "$close_count" >&2; exit 1
   fi

   printf 'PASS: mkdocs.yml Giscus config looks well-formed\n'
   exit 0
   ```

3. **Create `scripts/verify/m012-p03-mapping-documented.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p03-mapping-documented.sh — M012/P03 T04 gate.
   #
   # Asserts wiki/README.md carries the Giscus mapping + remap sections.

   set -u
   README="wiki/README.md"

   if ! grep -qE '^## Giscus mapping' "$README"; then
     printf 'FAIL: %s missing "## Giscus mapping" heading\n' "$README" >&2; exit 1
   fi
   if ! grep -qF 'pathname' "$README"; then
     printf 'FAIL: %s missing "pathname" discussion\n' "$README" >&2; exit 1
   fi
   if ! grep -qF 'wiki-giscus-remap.sh' "$README"; then
     printf 'FAIL: %s missing wiki-giscus-remap.sh reference\n' "$README" >&2; exit 1
   fi
   if ! grep -qF 'wiki-giscus-smoke.sh' "$README"; then
     printf 'FAIL: %s missing wiki-giscus-smoke.sh reference\n' "$README" >&2; exit 1
   fi

   printf 'PASS: README Giscus mapping section well-documented\n'
   exit 0
   ```

4. **Create `scripts/verify/m012-p03-config-loud-fail.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p03-config-loud-fail.sh — M012/P03 T02 gate.
   #
   # Exercises the config-check script under empty + populated env fixtures.

   set -u
   GATE="scripts/diagnostics/wiki-giscus-config-check.sh"
   if [ ! -x "$GATE" ]; then
     printf 'FAIL: %s not executable\n' "$GATE" >&2; exit 1
   fi

   # Fixture A: all empty → expect exit 1.
   rc=0
   env -i PATH="$PATH" bash "$GATE" --quiet >/dev/null 2>/tmp/giscus-empty.err || rc=$?
   if [ "$rc" -eq 0 ]; then
     printf 'FAIL: expected exit 1 with no env vars; got 0\n' >&2; exit 1
   fi
   fails="$(grep -c '^FAIL:' /tmp/giscus-empty.err | tr -d '[:space:]')"
   if [ "$fails" -lt 4 ]; then
     printf 'FAIL: expected >=4 FAIL: lines on empty env; got %d\n' "$fails" >&2; exit 1
   fi

   # Fixture B: all populated → expect exit 0.
   rc=0
   env -i PATH="$PATH" GISCUS_REPO=a GISCUS_REPO_ID=b GISCUS_CATEGORY=c GISCUS_CATEGORY_ID=d \
     bash "$GATE" >/tmp/giscus-full.out 2>/dev/null || rc=$?
   if [ "$rc" -ne 0 ]; then
     printf 'FAIL: expected exit 0 with all env vars set; got %d\n' "$rc" >&2; exit 1
   fi
   if ! grep -q '^PASS:' /tmp/giscus-full.out; then
     printf 'FAIL: expected PASS: line on populated env\n' >&2; exit 1
   fi

   printf 'PASS: config-check loud-fails on empty env, passes on populated env\n'
   rm -f /tmp/giscus-empty.err /tmp/giscus-full.out
   exit 0
   ```

5. **Create `scripts/verify/m012-p03-smoke-contract.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p03-smoke-contract.sh — M012/P03 T03 gate.
   #
   # Fixture-driven: builds a tmp HTML tree and asserts smoke script outcomes.

   set -u
   GATE="scripts/diagnostics/wiki-giscus-smoke.sh"
   if [ ! -x "$GATE" ]; then
     printf 'FAIL: %s not executable\n' "$GATE" >&2; exit 1
   fi

   FIX="$(mktemp -d -t m012-p03-smoke.XXXXXX)"
   # shellcheck disable=SC2064
   trap "rm -rf '$FIX'" EXIT

   printf '<html><body><script src="https://giscus.app/client.js"></script></body></html>\n' > "$FIX/good.html"
   printf '<html><body>hello no giscus</body></html>\n' > "$FIX/bad.html"

   rc=0
   bash "$GATE" --site "$FIX" >/tmp/giscus-mixed.out 2>/tmp/giscus-mixed.err || rc=$?
   if [ "$rc" -ne 1 ]; then
     printf 'FAIL: expected exit 1 on mixed fixture; got %d\n' "$rc" >&2; exit 1
   fi
   if ! grep -qF 'FAIL:' /tmp/giscus-mixed.err; then
     printf 'FAIL: expected FAIL: line on stderr for mixed fixture\n' >&2; exit 1
   fi

   # Fix the bad file; rerun.
   printf '<html><body><script src="https://giscus.app/client.js"></script></body></html>\n' > "$FIX/bad.html"
   rc=0
   bash "$GATE" --site "$FIX" >/tmp/giscus-good.out 2>/tmp/giscus-good.err || rc=$?
   if [ "$rc" -ne 0 ]; then
     printf 'FAIL: expected exit 0 on all-good fixture; got %d\n' "$rc" >&2; exit 1
   fi
   if ! grep -q '^PASS:' /tmp/giscus-good.out; then
     printf 'FAIL: expected PASS: line on stdout for all-good fixture\n' >&2; exit 1
   fi

   printf 'PASS: smoke script contract (mixed→FAIL, all-good→PASS)\n'
   rm -f /tmp/giscus-mixed.out /tmp/giscus-mixed.err /tmp/giscus-good.out /tmp/giscus-good.err
   exit 0
   ```

6. **Create `scripts/verify/m012-p03-remap-contract.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p03-remap-contract.sh — M012/P03 T04 gate.
   #
   # Exercises help, dry-run, and odd-arg-count paths. No gh API calls.

   set -u
   GATE="scripts/diagnostics/wiki-giscus-remap.sh"
   if [ ! -x "$GATE" ]; then
     printf 'FAIL: %s not executable\n' "$GATE" >&2; exit 1
   fi

   # --help → exit 0.
   rc=0
   bash "$GATE" --help >/tmp/giscus-help.out 2>&1 || rc=$?
   if [ "$rc" -ne 0 ]; then
     printf 'FAIL: --help exit %d != 0\n' "$rc" >&2; exit 1
   fi

   # --dry-run valid pair → exit 0 + DRY-RUN: line.
   rc=0
   bash "$GATE" --dry-run /a/ /b/ >/tmp/giscus-dry.out 2>/tmp/giscus-dry.err || rc=$?
   if [ "$rc" -ne 0 ]; then
     printf 'FAIL: --dry-run exit %d != 0\n' "$rc" >&2; exit 1
   fi
   if ! grep -qF 'DRY-RUN: /a/ -> /b/' /tmp/giscus-dry.out; then
     printf 'FAIL: --dry-run missing DRY-RUN: line\n' >&2; exit 1
   fi

   # Odd positional count → exit 2.
   rc=0
   bash "$GATE" --dry-run /a/ >/tmp/giscus-odd.out 2>/tmp/giscus-odd.err || rc=$?
   if [ "$rc" -ne 2 ]; then
     printf 'FAIL: odd-arg exit %d != 2\n' "$rc" >&2; exit 1
   fi

   # Idempotency surface: two back-to-back dry-runs on same pair → both exit 0.
   bash "$GATE" --dry-run /a/ /b/ >/dev/null 2>&1 || { printf 'FAIL: first dry-run failed\n' >&2; exit 1; }
   bash "$GATE" --dry-run /a/ /b/ >/dev/null 2>&1 || { printf 'FAIL: second dry-run failed\n' >&2; exit 1; }

   printf 'PASS: remap script contract (help, dry-run, odd-arg, idempotent dry-run)\n'
   rm -f /tmp/giscus-help.out /tmp/giscus-dry.out /tmp/giscus-dry.err /tmp/giscus-odd.out /tmp/giscus-odd.err
   exit 0
   ```

7. **Create `scripts/verify/m012-p03-bash32-compat.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p03-bash32-compat.sh — M012/P03 compat scan.
   #
   # Forbidden patterns (non-comment, non-string):
   #   declare -A, mapfile, readarray, ${var^^}, ${var,,}, <(...), >(...), &>

   set -u

   targets="scripts/diagnostics/wiki-giscus-config-check.sh
   scripts/diagnostics/wiki-giscus-smoke.sh
   scripts/diagnostics/wiki-giscus-remap.sh"

   # Add every m012-p03-*.sh under scripts/verify.
   for f in scripts/verify/m012-p03-*.sh; do
     targets="$targets
   $f"
   done

   # Each pattern grep'd against each file, with leading-# lines filtered.
   # Naming the patterns in plain strings and skipping assignment lines via
   # the ^[[:space:]]*name= regex carve-out (mirrors the M012/P01 approach).

   hits=0
   for f in $targets; do
     [ -f "$f" ] || { printf 'FAIL: target missing: %s\n' "$f" >&2; hits=$((hits+1)); continue; }
     grep -nE 'declare -A|mapfile|readarray|\$\{[a-zA-Z_][a-zA-Z0-9_]*\^\^\}|\$\{[a-zA-Z_][a-zA-Z0-9_]*,,\}|<\(|>\(|&>' "$f" \
       | grep -v '^[[:digit:]]\+:[[:space:]]*#' \
       | grep -v '^[[:digit:]]\+:[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*=' \
       > /tmp/m012-p03-compat-scan.tmp || true
     if [ -s /tmp/m012-p03-compat-scan.tmp ]; then
       while IFS= read -r line; do
         printf 'FAIL: %s %s\n' "$f" "$line" >&2
         hits=$((hits + 1))
       done < /tmp/m012-p03-compat-scan.tmp
     fi
   done
   rm -f /tmp/m012-p03-compat-scan.tmp

   if [ "$hits" -gt 0 ]; then
     printf 'FAIL: %d bash-3.2-incompatible constructs\n' "$hits" >&2
     exit 1
   fi
   printf 'PASS: bash 3.2 compat clean\n'
   exit 0
   ```

8. **Create `scripts/verify/m012-p03-wiki-removable.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p03-wiki-removable.sh — M012/P03 SC-10 gate (surface slice).
   #
   # Asserts no repo file OUTSIDE the allowed tree imports or bash-invokes
   # any wiki-giscus-* script. Allowed tree:
   #   wiki/**
   #   scripts/wiki/**
   #   scripts/diagnostics/wiki-giscus-*.sh
   #   scripts/verify/m012-p03-*.sh
   #   .orchestrator/milestones/M012/**

   set -u

   # grep all lines mentioning wiki-giscus-*.sh anywhere under the repo.
   grep -rln 'wiki-giscus-\(config-check\|smoke\|remap\)\.sh' . \
     --include='*.sh' --include='*.md' --include='*.yml' --include='*.yaml' \
     --include='*.json' --include='*.txt' 2>/dev/null > /tmp/m012-p03-rem-scan.tmp || true

   bad=0
   while IFS= read -r f; do
     [ -n "$f" ] || continue
     case "$f" in
       ./wiki/*|./scripts/wiki/*|./scripts/diagnostics/wiki-giscus-*|./scripts/verify/m012-p03-*|./.orchestrator/milestones/M012/*) ;;
       *) printf 'FAIL: unexpected import of wiki-giscus script from %s\n' "$f" >&2; bad=$((bad+1)) ;;
     esac
   done < /tmp/m012-p03-rem-scan.tmp
   rm -f /tmp/m012-p03-rem-scan.tmp

   if [ "$bad" -gt 0 ]; then
     printf 'FAIL: %d unexpected references\n' "$bad" >&2
     exit 1
   fi
   printf 'PASS: wiki-giscus surface contained in allowed tree\n'
   exit 0
   ```

9. **Create `scripts/verify/m012-p03-phase-suite.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p03-phase-suite.sh — M012/P03 orchestrator.
   #
   # Runs each P03 gate as a subprocess, aggregates pass/fail counts.

   set -u

   PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"
   cd "$PROJECT_ROOT"

   gates=(
     "m012-p03-comments-partial.sh"
     "m012-p03-mkdocs-giscus-config.sh"
     "m012-p03-mapping-documented.sh"
     "m012-p03-config-loud-fail.sh"
     "m012-p03-smoke-contract.sh"
     "m012-p03-remap-contract.sh"
     "m012-p03-bash32-compat.sh"
     "m012-p03-wiki-removable.sh"
   )
   passed=0
   total=${#gates[@]}
   for g in "${gates[@]}"; do
     if bash "scripts/verify/$g" >/dev/null 2>&1; then
       printf 'GATE: %s PASS\n' "$g"
       passed=$((passed + 1))
     else
       printf 'GATE: %s FAIL\n' "$g"
     fi
   done
   printf 'SUMMARY: %d/%d gates passed\n' "$passed" "$total" >&2
   [ "$passed" -eq "$total" ]
   ```

10. **Make every verify script executable** (`chmod 755 scripts/verify/m012-p03-*.sh`).

11. **Smoke-run the phase-suite** (manual; do NOT embed as a Check): `bash scripts/verify/m012-p03-phase-suite.sh` — expect 8/8 green. If any gate fails, debug the T01–T04 output.

## Must-Haves

- All eight gate scripts exist under `scripts/verify/m012-p03-*.sh` and are executable.
- `scripts/verify/m012-p03-phase-suite.sh` exists, is executable, orchestrates all eight gates.
- Every gate is a single-invocation Bash 3.2 script — no compound bash, no subshell compound commands, no `$()`-containing-pipes in Check command form (internal script logic may use those per MEM004).
- Running `bash scripts/verify/m012-p03-phase-suite.sh` against T01–T04 output exits 0.
- Every gate emits a `PASS: <name> ...` line on success and a `FAIL: ...` line with a pointer on failure.
- Removing any single gate script causes the phase-suite to FAIL on that gate without affecting the others.

## Verification

- `bash scripts/verify/m012-p03-phase-suite.sh` — suite exit code is the phase exit code.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P03` — every artifact + key-link pattern satisfied.
- Self-test: run the phase-suite twice in a row; exit code identical (no hidden state).

Manual smoke checks during this task (run once; do NOT embed as Checks):

1. `bash scripts/verify/m012-p03-phase-suite.sh` — expect 8/8 green.
2. Temporarily remove `custom_dir: overrides` from `wiki/mkdocs.yml`; rerun — expect `m012-p03-mkdocs-giscus-config.sh` to FAIL. Restore.
3. Temporarily shorten `wiki/overrides/partials/comments.html` to 10 lines; rerun — expect `m012-p03-comments-partial.sh` to FAIL. Restore.
4. Temporarily rename `wiki-giscus-smoke.sh` references out of `wiki/README.md`; rerun — expect `m012-p03-mapping-documented.sh` to FAIL. Restore.

## Inputs

### From Previous Tasks

- **T01**: `wiki/overrides/partials/comments.html` (≥ 25 lines, contains Giscus loader + data-attrs); `wiki/mkdocs.yml` with `theme.custom_dir: overrides` and `extra.giscus.*` block including four `!ENV` interpolations + literal `mapping: "pathname"`.
- **T02**: `scripts/diagnostics/wiki-giscus-config-check.sh` exiting 0 on populated env, 1 on empty env, 2 on bad flags.
- **T03**: `scripts/diagnostics/wiki-giscus-smoke.sh` exiting 0 when every HTML has the Giscus loader, 1 otherwise, 2 on missing/empty site dir.
- **T04**: `scripts/diagnostics/wiki-giscus-remap.sh` supporting `--help`, `--dry-run`, odd-arg rejection; `wiki/README.md` containing `## Giscus mapping` section with pathname + remap + smoke references.

### From Disk (Pre-existing)

- [`.orchestrator/milestones/M012/M012-ROADMAP.md`](../../../../milestones/M012/M012-ROADMAP.md) — ground truth for P03 Boundary Map.
- `.orchestrator/memory/constitution.md` — Principle VI (SSOT) + Principle VIII (Bash 3.2).
- Prior milestone verify suites (`scripts/verify/m012-p01-*.sh`, `scripts/verify/m012-p02-*.sh`) — shape and conventions to mirror; do not edit.

## Constraints

- **Bash 3.2** — every gate + the orchestrator. MEM001.
- **MEM004 carve-out** — gates are verification scripts, not agent-facing content; pipes, `$()`, `awk`, `grep -E` are allowed inside the scripts.
- **Single-script-file `Check:` shape (AD-19)** — every Truth `Check:` in `P03-PLAN.md` invokes one `bash scripts/verify/m012-p03-*.sh`. The compound logic lives inside the gate.
- **Read-only repo state** — gates never modify repo files. Writes go only to `/tmp` and are cleaned on EXIT.
- **Fixture-driven** — smoke + config-loud-fail + remap contract gates all create and tear down `/tmp` fixtures.
- **Deterministic** — same T01–T04 output → same exit code across repeated runs.
- **No global state between gates** — each gate is independently invokable. The orchestrator is optional scaffolding.
- **No external network calls** — remap-contract gate exercises only `--help`, `--dry-run`, and odd-arg paths; never calls `gh`.

## Expected Output

- Nine `.sh` files under `scripts/verify/` with `m012-p03-*` prefix, all executable, all Bash 3.2 compliant (including the phase-suite orchestrator).
- `bash scripts/verify/m012-p03-phase-suite.sh` exits 0 against clean T01–T04 output, prints eight `GATE: <name> PASS` lines + `SUMMARY: 8/8 gates passed`.
- Each gate, run individually, emits `PASS:` or `FAIL:` output and exits 0/1 deterministically.
- Removing any single verify script causes the phase-suite to FAIL on that gate without side effects on the other seven.
