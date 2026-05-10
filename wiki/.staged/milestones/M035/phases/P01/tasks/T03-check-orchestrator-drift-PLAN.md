---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M035"
name: "scripts/state/check-orchestrator-drift.sh + fixture install-meta.txt shapes"
depends_on: ["T01"]
---

## Prerequisites

Files that MUST exist on disk at task entry (verified at plan-authoring time):

- `tests/m035-acceptance/fixtures/install-meta-with-sha.txt` (authored
  by T01 — the SC-3 fixture)
- `tests/m035-acceptance/fixtures/install-meta-pre-m035.txt` (authored
  by T01 — the SC-3b fallback fixture)
- `CHANGELOG.md` (top-line `## [X.Y.Z]` heading is the SemVer source
  of truth per CON-4)
- `scripts/state/read-config.sh` (existing 4-rule config-resolver helper)
- `scripts/state/resolve-root.sh` (existing state-root resolver)

Pre-existing decisions consumed:

- `#Q-G5` (M035 discuss): SHA-absent fallback emits
  `commits_behind=unknown` + `versions_behind=…` plus a one-time stderr
  advisory.
- AD-5: `update_source` is detect-by-install-method-first,
  config-override-second — but P01 only consumes the config value;
  detect-and-persist is FR-13 / P06 scope.
- FR-15 (read-only-on-render): the helper writes nothing.

## Description

Author the new read-only `scripts/state/check-orchestrator-drift.sh`
script. It reads the consumer's `.orchestrator/install-meta.txt`
(extended in T01 with `commit_sha=` and `version=`), resolves the
configured `update_source` from `.orchestrator/config.yml`, and emits
a structured `key=value` block on stdout. Returns exit 0 always
(consumers branch on the data per FR-15). The SHA-absent fallback
covers the pre-M035 dogfood-install shape: lakeledger, pbj-central,
and bbt-companion installed before T01's schema extension and lack
`commit_sha=`.

For pre-launch (M035 P01) the only supported `update_source` is `git`
— the helper resolves the configured upstream path from
`.orchestrator/config.yml` (default `$HOME/Sites/orchestrator`
per US-2) and runs `git rev-list --count $local_sha..upstream_HEAD`.
Other source types (`npm`, `homebrew`, `none`) are recognised in the
emission shape but the upstream-comparison code is a no-op for them
(P06 will extend); for `none` the helper emits `update_source=none`
+ `commits_behind=0` + `versions_behind=0` and exits 0.

## Description (continued — emission shape)

The exact stdout shape (one key=value pair per line, sorted, no
blank lines):

```
commits_behind=<integer | unknown>
update_source=<git | npm | homebrew | none>
upstream_path=<absolute-path-or-empty>
versions_behind=<semver-delta-or-0>
```

When `commits_behind=unknown` (the SHA-absent fallback path), exactly
one stderr advisory line is emitted:

```
commit-SHA not recorded in install-meta.txt — drift detection using version comparison only (pre-M035 install).
```

The advisory is one-time per invocation, not per-day or persistent —
a follow-up M027-style suppression knob is out of scope for P01.

## Steps

1. **Author `scripts/state/check-orchestrator-drift.sh`**. Bash 3.2
   compatible, no associative arrays, no jq dependency, no `<<<`
   herestrings. Skeleton:

   ```bash
   #!/usr/bin/env bash
   # scripts/state/check-orchestrator-drift.sh — M035 P01 FR-3.
   #
   # Reads consumer's .orchestrator/install-meta.txt and the
   # update_source / upstream-path config from .orchestrator/config.yml,
   # emits a key=value block on stdout: update_source, upstream_path,
   # commits_behind, versions_behind. Exit 0 always (consumers branch
   # on the data, not the exit code) — FR-15 read-only-on-render.
   #
   # SHA-absent fallback (#Q-G5): when install-meta.txt lacks
   # commit_sha=, emit commits_behind=unknown + versions_behind=
   # semver-delta + one-time stderr advisory.
   #
   # Usage:
   #   check-orchestrator-drift.sh --consumer <path>
   #   check-orchestrator-drift.sh                       # defaults to $PWD
   #
   # Bash 3.2 compatible.

   set -u

   CONSUMER="$PWD"
   while [ $# -gt 0 ]; do
     case "$1" in
       --consumer)        shift; CONSUMER="$1"; shift ;;
       --consumer=*)      CONSUMER="${1#--consumer=}"; shift ;;
       -h|--help)         sed -n '2,18p' "$0"; exit 0 ;;
       *)                 echo "FAIL: unknown argument '$1'" >&2; exit 0 ;;  # FR-15: still 0
     esac
   done

   # --- Defaults ---
   update_source="git"
   upstream_path="$HOME/Sites/orchestrator"
   commits_behind=0
   versions_behind=0

   # --- Read install-meta.txt ---
   meta="$CONSUMER/.orchestrator/install-meta.txt"
   commit_sha=""
   version=""
   if [ -f "$meta" ]; then
     commit_sha="$(awk -F= '/^commit_sha=/{print $2}' "$meta")"
     version="$(awk -F= '/^version=/{print $2}'   "$meta")"
   fi

   # --- Read .orchestrator/config.yml (best-effort, no jq) ---
   cfg="$CONSUMER/.orchestrator/config.yml"
   if [ -f "$cfg" ]; then
     # Extract update_source: <value>  (single-line YAML scalar).
     us_val="$(awk '/^update_source:/{sub(/^update_source:[[:space:]]*/, ""); gsub(/^[\"\x27]|[\"\x27]$/, ""); print; exit}' "$cfg")"
     [ -n "$us_val" ] && update_source="$us_val"
     up_val="$(awk '/^update_upstream_path:/{sub(/^update_upstream_path:[[:space:]]*/, ""); gsub(/^[\"\x27]|[\"\x27]$/, ""); print; exit}' "$cfg")"
     [ -n "$up_val" ] && upstream_path="$up_val"
   fi

   # --- update_source=none short-circuit ---
   if [ "$update_source" = "none" ]; then
     printf 'commits_behind=0\nupdate_source=none\nupstream_path=\nversions_behind=0\n'
     exit 0
   fi

   # --- update_source=git: compute drift ---
   if [ "$update_source" = "git" ]; then
     if [ -z "$commit_sha" ]; then
       # SHA-absent fallback (#Q-G5)
       echo "commit-SHA not recorded in install-meta.txt — drift detection using version comparison only (pre-M035 install)." >&2
       commits_behind="unknown"
     else
       if [ -d "$upstream_path/.git" ]; then
         # Resolve upstream HEAD; count commits between local_sha and upstream HEAD.
         upstream_head="$(cd "$upstream_path" && git rev-parse HEAD 2>/dev/null)"
         if [ -n "$upstream_head" ] && [ -n "$commit_sha" ]; then
           # `git rev-list --count A..B` = commits in B not in A. Run inside upstream repo.
           commits_behind="$(cd "$upstream_path" && git rev-list --count "$commit_sha..$upstream_head" 2>/dev/null)"
           [ -z "$commits_behind" ] && commits_behind=0
         fi
       fi
     fi

     # Compute versions_behind from CHANGELOG semver delta (works regardless of SHA).
     if [ -n "$version" ] && [ -f "$upstream_path/CHANGELOG.md" ]; then
       upstream_version="$(awk '/^## \[/{print; exit}' "$upstream_path/CHANGELOG.md" | sed -E 's/^## \[([^]]+)\].*/\1/')"
       if [ -n "$upstream_version" ] && [ "$upstream_version" != "$version" ]; then
         versions_behind="$(printf '%s\n%s\n' "$version" "$upstream_version" | bash "$(dirname "$0")/lib/semver-delta.sh" 2>/dev/null || echo "0")"
         [ -z "$versions_behind" ] && versions_behind=0
       fi
     fi
   fi

   # --- Emit the structured block (sorted, no blanks) ---
   printf 'commits_behind=%s\nupdate_source=%s\nupstream_path=%s\nversions_behind=%s\n' \
     "$commits_behind" "$update_source" "$upstream_path" "$versions_behind"
   exit 0
   ```

   Note on `lib/semver-delta.sh`: a tiny helper that reads two
   `X.Y.Z` lines on stdin and emits the semver-component delta as
   a single-integer (e.g. `0.9.0` → `0.9.3` = 3). For P01, the
   simplest implementation diffs the patch-level when major+minor
   match, else emits 1 (any major-or-minor delta) — exact granularity
   is a P06 polish item. If the helper isn't trivial to author in
   T03 budget, inline the patch-diff in the helper itself and skip
   the separate file; document the delta semantics inline.

   **Inline alternative** (recommended to stay in budget): replace
   the `lib/semver-delta.sh` invocation with an inline awk:

   ```bash
   versions_behind="$(awk -v a="$version" -v b="$upstream_version" '
     BEGIN {
       split(a, A, ".");
       split(b, B, ".");
       if (A[1] != B[1] || A[2] != B[2]) { print 1; exit }
       d = B[3] - A[3];
       if (d < 0) d = 0;
       print d;
     }')"
   ```

2. **Author `tools/verify/m035-p01-drift-detection.sh`** (SC-3 path).
   Stage a fixture project under `mktemp -d`, copy
   `tests/m035-acceptance/fixtures/install-meta-with-sha.txt` to
   `<fixture>/.orchestrator/install-meta.txt`, write a `config.yml`
   pointing `update_upstream_path:` at a controlled-fixture upstream
   git repo (also under `mktemp -d`), then assert:

   - `bash scripts/state/check-orchestrator-drift.sh --consumer <fixture>`
     stdout contains `commits_behind=14` (or whatever value the
     fixture upstream repo's HEAD vs the fixture's recorded SHA
     resolves to — verifier owns the fixture upstream creation).
   - stdout contains `versions_behind=` line.
   - stdout contains `update_source=git`.
   - exit code is 0.

   Single-script-file shape per AD-19. The verifier creates a
   miniature git repo with a known number of commits to make the
   `commits_behind=14` assertion deterministic.

3. **Author `tools/verify/m035-p01-drift-detection-sha-absent.sh`**
   (SC-3b fallback). Stage a fixture using the
   `install-meta-pre-m035.txt` shape (no `commit_sha=`, no `version=`),
   point at a fixture upstream, then assert:

   - stdout contains `commits_behind=unknown`.
   - stderr contains exactly one line matching the documented
     advisory pattern `pre-M035 install`.
   - exit code is 0.
   - `versions_behind=0` (nothing to diff — version absent).

   Single-script-file shape per AD-19.

## Must-Haves

- Helper emits `commits_behind=N` against the SHA-bearing fixture
  - Check: `bash tools/verify/m035-p01-drift-detection.sh`
- Helper emits `commits_behind=unknown` + advisory against pre-M035 fixture
  - Check: `bash tools/verify/m035-p01-drift-detection-sha-absent.sh`

## Verification

```bash
bash tools/verify/m035-p01-drift-detection.sh
bash tools/verify/m035-p01-drift-detection-sha-absent.sh
```

## Inputs

### From Previous Tasks

- `tests/m035-acceptance/fixtures/install-meta-with-sha.txt` (from T01)
  - Format: 5 `key=value` lines including `commit_sha=…` (40-char hex) and `version=X.Y.Z`
- `tests/m035-acceptance/fixtures/install-meta-pre-m035.txt` (from T01)
  - Format: 3 `key=value` lines (`source_root=`, `runtime=`, `installed_at=`); no commit_sha, no version

### From Disk (Pre-existing)

- `CHANGELOG.md` — SemVer top-line; helper uses `awk '/^## \[/{print; exit}'` to extract upstream version.
- `scripts/state/read-config.sh`, `scripts/state/resolve-root.sh` — referenced in design only; T03 reads `.orchestrator/config.yml` directly via awk to keep the helper standalone (read-only and bash-3.2-safe).

## Constraints

- **FR-15 (read-only-on-render)**: the helper writes NOTHING. Stdout
  is the only output channel; stderr carries advisories. No JSONL
  emission (that's FR-13 / P06).
- **CON-2-equivalent (bash-3.2-only)**: no process substitution, no
  associative arrays, no `<<<` herestrings, no jq.
- **Exit 0 always**: per FR-15 / SC-3 design contract. Consumers
  branch on the emitted data, not the exit code. Even on error
  (missing install-meta.txt, missing upstream, etc.) the helper
  emits sane defaults and exits 0.
- **No new suppression knob**: M035 inherits [M027](../../../../../milestones/M027/index.md) / `update_source: none`
  conventions per FR-16.

## Notes

- Expected verifier output: `PASS: m035-p01-drift-detection` and
  `PASS: m035-p01-drift-detection-sha-absent`.
- **Plan-phase verifier-availability cross-check (rule 2)**: both
  verifiers (`m035-p01-drift-detection.sh`,
  `m035-p01-drift-detection-sha-absent.sh`) authored in steps 2-3
  of this task.
- **Plan-phase classifier-shape pre-validation (rule 3)**: every
  proposed `Check:` command is a single-script-file invocation.
  The helper itself uses awk + `cd … && git …` — `cd … && git …` is
  a two-token compound that is below the AP-009 compound-chain-gt2
  threshold (3+); also it executes inside a script body, not as a
  shape-guarded inline `Check:` command, so AD-19 does not apply.
- **Plan-phase real-DB rule (rule 5)**: not applicable.
- The verifier-side fixture upstream git-repo creation is a one-shot
  staging probe — it lives under `mktemp -d`, satisfying
  `run-probe.sh`'s allowed-directory list (rule 4 of plan-time
  discipline). The verifier MAY use `bash scripts/util/run-probe.sh`
  for the per-step `git init`/`git commit` invocations, or invoke
  `git` directly from inside its own bash body — author's choice.

## Expected Output

After T03 completes:

- `scripts/state/check-orchestrator-drift.sh` exists, is executable,
  reads `install-meta.txt` + `config.yml`, and emits the four-key
  block on stdout for both `update_source=git` and `update_source=none`.
- The SHA-absent fallback path emits `commits_behind=unknown` plus
  the documented stderr advisory.
- Two verifiers exist and PASS against the new state.
