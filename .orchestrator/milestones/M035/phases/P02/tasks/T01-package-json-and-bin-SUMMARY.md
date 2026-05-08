---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P02"
milestone: "M035"
provides:
  - "package.json npm v1 manifest at repo root with @build-fractal/orchestrator name (D-RN-1) + 0.9.2 version (CON-4 CHANGELOG read) + bin.orchestrator -> bin/orchestrator (FR-8) + scripts.postinstall reference (T02 target) + engines.node>=14 + os: [darwin,linux] (D003/MIT-9 npm-side Windows fail-closed) + files whitelist; bin/orchestrator executable v1 binary entry point with --version (jq-free package.json read) + --help/-h/no-args banner naming orchestrator:<cmd> cohort prefix (D-RN-3) + non-zero exit on unknown invocation (no subcommand dispatch at v1); tools/verify/m035-p02-package-json-shape.sh task-grain verifier (7 grep-based pattern checks AD-19 single-script shape BATTERY: pass=7 fail=0); tools/verify/m035-p02-bin-entry.sh task-grain verifier (3 conditions: file-exists+executable / --version matches package.json / no-args banner contains cohort-prefix string AD-19 single-script shape BATTERY: pass=3 fail=0)"
requires:
  - "from:P01.5 what:D-RN-1 binding @build-fractal/orchestrator npm scope; from:P01.5 what:D-RN-3 cohort prefix orchestrator:<cmd>; from:disk what:CHANGELOG.md top-line version 0.9.2 via awk; from:disk what:scripts/util/run-probe.sh staged-probe wrapper for CON-3/AP-009 honor"
affects:
  - "P02/T02 (postinstall driver consumes scripts.postinstall reference); P02/T03 (cross-channel byte-equivalence will compare against this manifest); P02/T04 (release.yml workflow consumes engines/os fields); P02/T05 (bundle-hygiene filter respects files whitelist)"
key_files:
  - "package.json,bin/orchestrator,tools/verify/m035-p02-package-json-shape.sh,tools/verify/m035-p02-bin-entry.sh"
key_decisions:
  - "D-RN-1 (dr-code-029 binds @build-fractal/orchestrator npm scope); D-RN-3 (dr-code-031 binds orchestrator:<cmd> cohort prefix); D003 (binds engines.node + os fail-closed Windows guard); CON-4 (CHANGELOG SemVer source-of-truth); CON-3 (compound-chain shape-guard via run-probe.sh staged probes); AP-009 (no inline bash -c chains); MIT-9 (Windows fail-closed via npm os array); FR-8 (bin/orchestrator entry point)"
patterns_established:
  - "changelog-as-version-source-of-truth (awk regex skips [Unreleased] reads top-line semver); npm-side-os-allowlist-as-windows-fail-closed (npm rejects EBADPLATFORM when os array excludes win32); minimal-binary-with-skill-redirect (v1 binary surface is --version + banner + non-zero on unknown invocation deferring subcommand dispatch to post-launch); jq-free-version-read-from-package.json (grep -E pipe head -1 pipe sed -E bash 3.2 compatible no toolchain dependency); REPO_ROOT-defensive-fallback-in-staged-probes (run-probe.sh computes but does not export REPO_ROOT; probes use parameter expansion fallback for portability)"
drill_down_paths:
  - ".orchestrator/milestones/M035/phases/P02/tasks/T01-package-json-and-bin-PAYLOAD.md"
duration: "18m"
verification_result: "pass"
completed_at: "2026-05-08T20:01:09Z"
---

T01 authored the load-bearing M035/P02 npm v1 manifest and binary entry point: `package.json` at the repo root declaring `"name": "@build-fractal/orchestrator"` (D-RN-1 / `dr-code-029`), `"version": "0.9.2"` captured from `CHANGELOG.md` top-line at author-time per CON-4 (`awk '/^## \[[0-9]/{...; print $2; exit}'` skips `## [Unreleased]`), `"bin": {"orchestrator": "bin/orchestrator"}` per FR-8, `"engines": {"node": ">=14"}` and `"os": ["darwin", "linux"]` as the npm-side Windows fail-closed guard (D003 / MIT-9), `"scripts": {"postinstall": "bash packaging/npm/postinstall.sh"}` pointing at the T02 driver, and the `"files"` whitelist that defines the npm tarball surface.

`bin/orchestrator` is the v1 binary surface — minimal by design: `--version` prints the package.json version (read via `grep -E ... | head -1 | sed -E ...`, no jq), `--help` / `-h` / no-args prints a banner naming the `orchestrator:<cmd>` cohort prefix (D-RN-3 / `dr-code-031`), and any other invocation exits non-zero with a clear redirect-to-skills message. v1 deliberately ships zero subcommand dispatch — adopters reach orchestrator commands through registered Claude Code skills, and the binary's load-bearing job is to be present on PATH for `which orchestrator` and `orchestrator --version` smoke tests during package-manager publishing.

Two task-grain verifiers landed under `tools/verify/` with the milestone-prefix discipline: `m035-p02-package-json-shape.sh` (7 grep-based pattern checks: name / version SemVer-shape / bin / postinstall / engines.node / os darwin / os linux) and `m035-p02-bin-entry.sh` (3 conditions: file-exists+executable / `--version` matches package.json / no-args banner contains the cohort-prefix string). Both follow the AD-19 single-script Check shape, emit `BATTERY: pass=N fail=N`, and return non-zero on any FAIL.

Verification: `bash tools/verify/m035-p02-package-json-shape.sh` → `BATTERY: pass=7 fail=0`; `bash tools/verify/m035-p02-bin-entry.sh` → `BATTERY: pass=3 fail=0`; `bash scripts/util/run-probe.sh /tmp/m035-p02-t01-json-validate.sh` → `PASS: package.json is valid JSON`. Both new artifacts meet the must-have line-count floors (package.json 49 lines vs. ≥30 required; bin/orchestrator 65 lines vs. ≥20 required) and the must-have content checks (package.json contains `@build-fractal/orchestrator`; bin/orchestrator contains `--version`).

Plan-Time Discipline Rule 6 confirmed at execution: `package.json`, `bin/`, and both verifier paths were absent on disk before the task ran. Bash 3.2 / POSIX honored throughout — no `declare -A`, no jq, no python (the optional JSON-validity probe falls back to node if python3 is unavailable, but python3 was present on this run). CON-3 / AP-009 honored — staged probes via `scripts/util/run-probe.sh` for the two shell-logic blocks (CHANGELOG read, JSON validation), no inline compound chains.

One small payload deviation: the task plan claims `run-probe.sh` exports `REPO_ROOT`, but `scripts/util/run-probe.sh` computes `REPO_ROOT` locally without `export`. The staged probes both defended with `REPO_ROOT="${REPO_ROOT:-/Users/brettkellgren/Sites/spec-kit-orchestrator}"` fallback so the probes work regardless of run-probe.sh's behavior — semantically identical to the payload's intent. Recommended P02-T01 follow-up (out of scope for T01): either export REPO_ROOT in run-probe.sh, or update the in-tree run-probe.sh contract docstring to clarify that probes must compute their own REPO_ROOT.

Patterns established: changelog-as-version-source-of-truth (CON-4 — `awk '/^## \[[0-9]/{...}' CHANGELOG.md` reads the top-line version, skipping `## [Unreleased]`); npm-side-os-allowlist as fail-closed Windows guard (D003 / MIT-9 — npm rejects install on win32 with `EBADPLATFORM` when the `os` array excludes the platform); minimal-binary-with-skill-redirect (v1 binary ships `--version` + banner + non-zero on unknown invocation, deliberately deferring subcommand dispatch to post-launch — adopters reach orchestrator commands through Claude Code skills with the `orchestrator:<cmd>` prefix per D-RN-3); jq-free-version-read-from-package.json (`grep -E '^[[:space:]]*"version"' | head -1 | sed -E 's/.../\1/'` — bash 3.2 compatible, no toolchain dependency for the binary's `--version` surface).

Reversibility: removing `package.json`, `bin/orchestrator`, and the two verifiers unwinds T01 cleanly. The npm publishing pipeline doesn't run until T04, so T01 is a pure authoring task with no external side effects. The two staged `/tmp/m035-p02-t01-*.sh` probes are operator-cleanup-eligible post-verification.
