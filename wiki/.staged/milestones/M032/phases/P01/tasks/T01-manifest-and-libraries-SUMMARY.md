---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P01"
milestone: "M032"
provides:
  - "project_assets manifest schema; read-project-assets.sh shared reader; install-asset-mode.sh per-mode handler (copy + symlink + windows fail-closed); install-collision-check.sh FR-22 dual-oracle hierarchy (tracking-file + MIT-006 bootstrapping + operator-owned)"
requires:
  - "from:M032/P01 what:pre-M032 manifest.yml schema preserved byte-identically; from:scripts/util what:with-env.sh wrapper for M032_FORCE_WINDOWS env-shape"
affects:
  - "T02 T03 T04"
key_files:
  - "packaging/bundle/manifest.yml,scripts/lifecycle/read-project-assets.sh,scripts/lifecycle/install-asset-mode.sh,scripts/lifecycle/install-collision-check.sh,tools/verify/m032-p01-manifest-schema-shape.sh,tools/verify/m032-p01-reader-emits-tuples.sh,tools/verify/m032-p01-mode-handler-symlink.sh,tools/verify/m032-p01-installed-files-format.sh,tools/verify/m032-p01-collision-oracle.sh"
key_decisions:
  - "FR-1,FR-2,FR-3,FR-22,NG-9,MIT-006,CON-4,AD-19"
patterns_established:
  - "dual-oracle collision-check hierarchy with MIT-006 bootstrapping carve-out; tab-delimited column-1 installed-files.txt FILE FORMAT INVARIANT documented inline at the consumer; per-mode handler dispatches on key=value emit tokens (no mode: colon-literal in path-vicinity); Windows fail-closed via M032_FORCE_WINDOWS=1 OR absent ln"
drill_down_paths:
  - ".orchestrator/milestones/M032/phases/P01/tasks/T01-manifest-and-libraries-PAYLOAD.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-05-04T00:11:26Z"
---

## What Shipped

T01 lands the four additive surfaces M032 P01 needs before T02 + T03 migrate
the three installers. None of `install-claude-code.sh`, `install-codex.sh`, or
`install-cursor.sh` was touched in this task, so pre-M032 install behavior is
byte-identical at T01 close.

The four deliverables, all on the inherited `main` branch:

1. **`packaging/bundle/manifest.yml` `project_assets:` section (FR-1)** —
   appended after `runtime_compatibility:`. Top-level YAML list with exactly
   four entries (`commands/`, `scripts/`, `references/`, `templates/`), each
   declaring `source:`, `target:`, and `mode: copy`. All ten pre-M032
   top-level keys preserved byte-identically (`schema_version`, `type`,
   `name`, `version`, `description`, `skill_spec`, `skills`, `hooks`,
   `config_default`, `runtime_compatibility`).

2. **`scripts/lifecycle/read-project-assets.sh` (FR-2 prep)** — shared reader
   for all three installers. Takes one positional arg (bundle dir, default
   `packaging/bundle/`), reads the manifest, emits one tab-separated
   `source=<src>\ttarget=<tgt>\tmode=<copy|symlink>` line per
   `project_assets:` entry. Pure stdout, no env mutation, no temp files. AWK
   parser walks the section between `^project_assets:$` and the next
   top-level key. Rejects malformed entries with exit 2.

3. **`scripts/lifecycle/install-asset-mode.sh` (FR-3 + NG-9)** — per-mode
   handler. `copy` reproduces today's `cp -R "$src/." "$dst/"` byte-identically
   and emits `staged_mode=copy src=<src> dst=<dst>`. `symlink` resolves the
   runtime root to the highest-versioned subdir under
   `~/.claude/orchestrator-runtime/` (fallback:
   `<PROJECT_DIR>/.orchestrator/runtime-cache/`), idempotently
   `rm -rf "$dst"` then `ln -s`, and emits
   `staged_mode=symlink src=<src> dst=<dst> link_target=<resolved>`.
   Windows fail-closed: `M032_FORCE_WINDOWS=1` OR absent `ln` exits 3 with
   `POSIX-only in v1` on stderr and writes nothing under target.

4. **`scripts/lifecycle/install-collision-check.sh` (FR-22 + MIT-006)** —
   dual-oracle hierarchy. Tracking-file oracle (primary, tab-delimited
   column-1 lookup against `installed-files.txt`); bootstrapping oracle
   (MIT-006, applies when tracking file absent and target is in the
   project-assets list); operator-owned oracle (tertiary, fails closed exit 4
   with literal `staged-dirs-collision: project_assets entry <e> collides
   with operator-owned <p>` diagnostic when the path pre-exists, is not in
   tracking, and is not gitignored). The FILE FORMAT INVARIANT for
   `installed-files.txt` is documented inline so T02's writer is bound to
   tab-delimited column-1 (no `mode:` literal in path-vicinity tokens).

## Five Verifiers (all under `tools/verify/m032-p01-*.sh`)

- `m032-p01-manifest-schema-shape.sh` — 19 PASS / 0 FAIL.
- `m032-p01-reader-emits-tuples.sh` — 11 PASS / 0 FAIL.
- `m032-p01-mode-handler-symlink.sh` — 12 PASS / 0 FAIL (exercises
  copy / symlink+windows / symlink / unknown-mode branches against a
  `mktemp -d` fixture; uses `scripts/util/with-env.sh` for the
  `M032_FORCE_WINDOWS=1` invocation per AP-008).
- `m032-p01-installed-files-format.sh` — 6 PASS / 0 FAIL (asserts inline
  documentation of FILE FORMAT INVARIANT in `install-collision-check.sh`
  + handler emit lines avoid the `mode:` colon-literal).
- `m032-p01-collision-oracle.sh` — 13 PASS / 0 FAIL (exercises all three
  oracle branches + a fourth gitignored-clean sanity branch against a
  `mktemp -d` git-init fixture).

## Exit-Code Contract (for T02 + T03 + T04 to read against)

- `0` = success
- `2` = invalid input (malformed manifest entry, unknown mode)
- `3` = POSIX-only fail-closed (Windows symlink request)
- `4` = FR-22 collision detected

## Constraints Honored

- Installers untouched (CON-4 byte-identical at T01 close — verified via
  `git status --short packaging/install/` returning empty).
- Manifest amendment preserves every pre-existing top-level key
  (CON-4 byte-identical at the manifest layer).
- All five verifiers ship in script-file form per AD-19 path discipline.
- Bash 3.2 compatible (no `declare -A`, parallel indexed arrays where
  needed) per K001 / MEM001.
- Lifecycle helpers use single-script-file shapes — no inline compound bash,
  no command substitution containing pipes.

## Surfaces Not Touched (Out of T01 Scope)

The payload's "Files To Touch" list enumerated the broader P01 surface
(installers, fixtures, acceptance scripts, byte-identical installer
verifiers). Per the T01 plan's Description ("None of the three installers
is touched in this task"), T01 ships only the four deliverables above. T02
and T03 will dispatch the installer migration through these helpers; T04
will record the byte-identical golden and the fixture bootstrap.
