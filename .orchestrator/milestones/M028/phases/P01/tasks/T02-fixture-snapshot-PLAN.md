---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P01"
milestone: "M028"
name: "Capture operator M018-close settings.json snapshot as P01 fixture"
depends_on: []
---

## Prerequisites

- The operator's M018-close backup file at `~/.claude/settings.json.bak-m018-cleanup-2026-04-28` is on-disk and readable. Confirm with `bash scripts/util/run-probe.sh ls -la $HOME/.claude/settings.json.bak-m018-cleanup-2026-04-28`. This file is the canonical evidence for the Finding F regression — it contains 5 duplicate `Stop` wrappers and 7 duplicate `PreToolUse` Bash wrappers, none carrying the `_orchestrator_managed: true` flag.
- `tests/fixtures/` directory exists on-disk.
- `jq` is **not** required — fixture sanitization runs through bash + sed only (CON-6: no new runtime deps).

## Description

Capture the operator's M018-close `~/.claude/settings.json.bak-m018-cleanup-2026-04-28` snapshot as the canonical pre-repair fixture for downstream P02 `--repair` testing (FR-7 + SC-7). The captured file must:

1. **Preserve the regression-relevant shape**: the duplicate-entry pattern that demonstrates the Finding F regression (5+ flag-less `Stop` wrappers, 7+ flag-less `PreToolUse` Bash wrappers naming `orchestrator-post-verify` / `orchestrator-before-commit`) must round-trip byte-equivalently into the fixture, with one exception: the `_orchestrator_managed: true` flag must appear at least once somewhere in the file (per the phase artifact must-have) — typically by adjacency to user-authored entries or by the natural shape of a partial-flag file.

2. **Be sanitized of user-specific bytes**: the operator's local username (`brettkellgren`), absolute home directory paths (`/Users/brettkellgren/...`), any API keys or tokens, and any user-specific email addresses must be replaced with stable placeholders. Sanitization is a one-shot transformation — it does not need to reverse, but it must be deterministic so reruns produce byte-identical output.

3. **Land at the canonical path**: `tests/fixtures/m028-pre-repair-snapshot.json`. This path is referenced by P02's `install-roundtrip.sh` and `--repair` verifier as the input fixture.

## Steps

1. Copy the source file to the fixture path:

   ```bash
   bash scripts/util/run-probe.sh cp $HOME/.claude/settings.json.bak-m018-cleanup-2026-04-28 tests/fixtures/m028-pre-repair-snapshot.json.raw
   ```

   The `.raw` suffix marks it as pre-sanitization; T02 deletes the `.raw` file at the end.

2. Author `scripts/verify/m028/p01-fixture-sanitize.sh` (a one-shot transformation script — kept in-tree because P02's `--repair` verifier may need to reproduce the sanitization for control fixtures). Single-script-file shape per AD-19. The script:
   - Reads `tests/fixtures/m028-pre-repair-snapshot.json.raw`.
   - Runs the following deterministic substitutions via `sed`:
     - `/Users/brettkellgren/` → `/Users/<USER>/`
     - `brettkellgren` (standalone token, word-boundary) → `<USER>`
     - Any 32+ character hex/base64 sequence that looks like a token (run a permissive regex; document the choice in a one-line comment) → `<REDACTED-TOKEN>`
     - Any string matching `bkellgren@gmail.com` (the operator's known email) → `<USER>@<DOMAIN>`
   - Writes the result to `tests/fixtures/m028-pre-repair-snapshot.json`.
   - Validates the output is parseable JSON via `python3 -m json.tool` (Python is already a constitution-mandated tool; `jq` is not required). If parse fails, exit 1 with a diagnostic.
   - Verifies the output contains the literal substring `_orchestrator_managed` at least once (anchor that the fixture preserved at least one M025-flagged entry; the operator's snapshot is known to contain at least one).

3. Run the sanitizer:

   ```bash
   bash scripts/util/run-probe.sh scripts/verify/m028/p01-fixture-sanitize.sh
   ```

4. Delete the `.raw` intermediate:

   ```bash
   bash scripts/util/run-probe.sh rm tests/fixtures/m028-pre-repair-snapshot.json.raw
   ```

5. Author `scripts/verify/m028/p01-fixture-sanitized.sh`. Distinct from `p01-fixture-sanitize.sh` — the `-sanitized` script is the **must-have verifier** that runs at phase verification time. The script:
   - Verifies `tests/fixtures/m028-pre-repair-snapshot.json` exists and parses as JSON (call `python3 -m json.tool` against the file; exit 1 on parse fail).
   - Asserts the file contains zero matches for the literal byte sequences `/Users/brettkellgren/`, `brettkellgren` (word-boundary), and `bkellgren@gmail.com`. If any match is found, exit 1 with `FAIL: sanitization leak — found <pattern>`.
   - Asserts the file contains the literal substring `_orchestrator_managed` (at least one M025-flagged entry preserved).
   - On all checks PASS, exit 0 with `PASS: m028-pre-repair-snapshot.json sanitized and shape-valid`.

6. Run the verifier:

   ```bash
   bash scripts/util/run-probe.sh scripts/verify/m028/p01-fixture-sanitized.sh
   ```

   Confirm `PASS`. If FAIL, iterate on the sanitizer (`p01-fixture-sanitize.sh`) — never edit the verifier to make it pass.

## Must-Haves

This task addresses the Truth: "The pre-repair fixture is byte-stable on disk and contains no user-specific path or token strings." It produces the artifact `tests/fixtures/m028-pre-repair-snapshot.json` and the verifier `scripts/verify/m028/p01-fixture-sanitized.sh` referenced by the phase-plan must-haves.

## Verification

```bash
bash scripts/verify/m028/p01-fixture-sanitized.sh
```

## Notes

Expected verifier output is a single line of the form `PASS: m028-pre-repair-snapshot.json sanitized and shape-valid`.

## Inputs

### From Previous Tasks

None.

### From Disk (Pre-existing)

- `~/.claude/settings.json.bak-m018-cleanup-2026-04-28` — the operator's M018-close backup. T02 reads this verbatim and copies it through the sanitizer. The file is known to contain (a) at least one entry carrying `_orchestrator_managed: true`, (b) 12 flag-less duplicate hook entries (5 `Stop` + 7 `PreToolUse` Bash) that demonstrate the Finding F regression, (c) the operator's local paths and possibly user-specific tokens — all of which must be sanitized before the fixture lands in-tree.
- `scripts/util/run-probe.sh` — shape-safe wrapper for invoking the cp / rm / sanitize commands above.
- `python3` — used for JSON shape validation. The `python3 -m json.tool` invocation is bash-shape-safe (no compound chain). Constitution-mandated tool; no new runtime dep.

## Constraints

- **AD-19 single-script-file shape**: both `p01-fixture-sanitize.sh` and `p01-fixture-sanitized.sh` are flat single-file bash scripts. No nested helper dirs, no compound-chain bodies, no plain subshells, no `bash -c '...'` chains.
- **bash 3.2 + POSIX sh (CON-2)**: every line in both scripts runs on bash 3.2.
- **Sanitization is deterministic**: rerunning `p01-fixture-sanitize.sh` against a fresh copy of the source must produce byte-identical output. No timestamps, no per-run identifiers, no environment-leaked values.
- **Regression-shape preservation**: the captured fixture must still contain the duplicate-entry pattern (≥ 5 `Stop` duplicates, ≥ 7 `PreToolUse` Bash duplicates naming `orchestrator-post-verify` or `orchestrator-before-commit`) — this is what makes it the canonical input for P02's `--repair` verifier. Sanitization replaces user-specific bytes; it does not deduplicate or simplify entry shape.
- **No new runtime deps (CON-6)**: the sanitizer uses only `sed` + bash builtins + `python3 -m json.tool`. No `jq`, no `node`, no curl. The orchestrator already mandates Python.
- **CON-10 noisy-fail (carried forward)**: the fixture is permanent in-tree. P02's verifier may extend `p01-fixture-sanitized.sh` with shape-vs-adapter-emission assertions later; T02's verifier does the basic sanity layer only.

## Expected Output

- `tests/fixtures/m028-pre-repair-snapshot.json` — sanitized JSON, ≥ 30 lines, contains `_orchestrator_managed`, parses as valid JSON, contains zero user-specific path/token leaks.
- `scripts/verify/m028/p01-fixture-sanitize.sh` — the deterministic sanitizer transformation script. ≥ 20 lines, flat single-file shape.
- `scripts/verify/m028/p01-fixture-sanitized.sh` — the must-have verifier. ≥ 10 lines, flat single-file shape, references `tests/fixtures/m028-pre-repair-snapshot.json`.
- The intermediate `tests/fixtures/m028-pre-repair-snapshot.json.raw` is deleted at task close.
- Standard task summary at `.orchestrator/milestones/M028/phases/P01/tasks/T02-fixture-snapshot-SUMMARY.md`.
