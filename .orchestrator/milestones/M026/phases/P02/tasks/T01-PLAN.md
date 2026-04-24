---
schema_version: "1.0"
task: "T01"
phase: "P02"
milestone: "M026"
name: "Adapter edition-detection resolver — single-venv reality (env-var primary + metadata-probe fallback)"
depends_on: []
---

## Prerequisites

- `scripts/dispatch/adapters/tool/conversus.sh` exists with `_resolve_binary` function at lines ~68-98 (reference: post-M026/P01 state, commit `32ab6ea`).
- P01 parity matrix post-verify addendum at `.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md` (lines 98-146, section "Addendum: 2026-04-23 post-verification install reality") is authoritative for the single-venv reality: both OSS and paid publish to the same `conversus` PyPI package name and install to the same pipx venv `~/.local/pipx/venvs/conversus/`. Path-based edition detection (e.g., `~/Sites/conversus-oss/bin/conversus` vs `~/Sites/conversus/bin/conversus`) is INFEASIBLE and not what this task implements.
- P01 operator state per `.orchestrator/milestones/M026/phases/P01/OLLAMA-PROBE.md`: OSS is installed (`Home-page: https://github.com/Build-Fractal/conversus-oss`), paid is currently uninstalled, single venv at `~/.local/pipx/venvs/conversus/`.
- `references/architecture.md` "Conversus Adapter — Operator Notes" section exists (shipped in commit `32ab6ea`).

## Description

Extend the adapter's `check` subcommand and resolver output to declare the active Conversus **edition** (`oss` | `paid` | `unknown`) using a two-tier detection strategy that matches the single-venv reality:

1. **Primary**: `CONVERSUS_EDITION=oss|paid` env var. Operator declares the active edition; adapter trusts the declaration. Emits `edition=<value> reason=env-override`. Any other value (e.g., `CONVERSUS_EDITION=foo`) emits a single-line stderr warning and falls through to the metadata probe.
2. **Fallback**: `python -m pip show conversus` metadata probe against the resolved venv's Python. Parses the `Home-page:` line — `github.com/Build-Fractal/conversus-oss` ⇒ `oss`, anything else ⇒ `paid` (paid's Home-page not confirmed post-uninstall, but the OSS indicator is positive and anchors the negative). Emits `edition=<value> reason=metadata-probe`. If the probe subprocess fails (venv Python missing, `pip show` returns non-zero, `Home-page` line absent), emits `edition=unknown reason=metadata-probe-failed`.
3. **Short-circuit**: when the binary is resolved via `CONVERSUS_STUB=1`, emit `edition=unknown reason=stub` (stub mode is edition-agnostic by design). When resolved via `CONVERSUS_HOME`, probe the metadata at that venv if possible else emit `edition=unknown reason=home`. When resolved via `command -v conversus` (PATH), probe metadata if possible else emit `edition=unknown reason=command-v`.

All existing `_resolve_binary` contracts are preserved: `available=<bool>` and `conversus_path=<path>` remain the first two lines of `check` stdout in the same order; the new `edition=` and `reason=` lines are appended. No env vars, exit codes, or subcommand surfaces change beyond these additive lines.

The resolver's edition output is also consumed by T02 (JSONL emission) and T03 (dual-edition test gating) via a new helper function `_resolve_edition` that callers can invoke programmatically.

## Steps

1. **Read the current adapter** at `scripts/dispatch/adapters/tool/conversus.sh` lines 60-140 to confirm the `_resolve_binary` structure hasn't drifted since the spec quote above.
2. **Add a new `_resolve_edition` helper function** immediately after `_resolve_binary` (around line 99). Signature:
   ```sh
   # _resolve_edition <venv-python-path> <resolved-via-tag>
   # Emits two lines to stdout: `edition=<oss|paid|unknown>` and `reason=<tag>`.
   # <resolved-via-tag> is one of: env-override|metadata-probe|stub|home|command-v|fallback.
   # Bash 3.2 compatible. No process substitution, no command-substitution-containing-pipes.
   ```
   Implementation outline:
   ```sh
   _resolve_edition() {
     _ve_venv_py="$1"
     _ve_via="$2"

     # 1. Env-var primary.
     case "${CONVERSUS_EDITION:-}" in
       oss|paid)
         echo "edition=${CONVERSUS_EDITION}"
         echo "reason=env-override"
         return 0
         ;;
       "")
         : # fall through
         ;;
       *)
         echo "warn: CONVERSUS_EDITION=${CONVERSUS_EDITION} is not oss|paid; falling through to metadata probe" >&2
         ;;
     esac

     # 2. Stub short-circuit (stub mode is edition-agnostic).
     if [ "${CONVERSUS_STUB:-0}" = "1" ] || [ "$_ve_via" = "stub" ]; then
       echo "edition=unknown"
       echo "reason=stub"
       return 0
     fi

     # 3. Metadata probe via pip show.
     if [ -n "$_ve_venv_py" ] && [ -x "$_ve_venv_py" ]; then
       _ve_home="$("$_ve_venv_py" -m pip show conversus 2>/dev/null | grep -E '^Home-page:' | head -n 1 | sed -E 's/^Home-page:[[:space:]]*//;s/[[:space:]]*$//')"
       if [ -n "$_ve_home" ]; then
         case "$_ve_home" in
           *conversus-oss*)
             echo "edition=oss"
             echo "reason=metadata-probe"
             return 0
             ;;
           *)
             echo "edition=paid"
             echo "reason=metadata-probe"
             return 0
             ;;
         esac
       fi
       echo "edition=unknown"
       echo "reason=metadata-probe-failed"
       return 0
     fi

     # 4. No venv Python resolvable — emit unknown with caller's via tag.
     echo "edition=unknown"
     echo "reason=${_ve_via}"
     return 0
   }
   ```
3. **Modify `_resolve_binary`** to extract the venv-python path from each resolution branch and call `_resolve_edition` after emitting `available=`/`conversus_path=`. Each branch passes its own via-tag:
   - `CONVERSUS_STUB=1` branch: `_resolve_edition "" stub`
   - `command -v conversus` branch: derive venv-python from the shebang of the resolved binary (same `head -n 1 | sed -E 's|^#!([^[:space:]]+).*|\1|'` pattern used at line 252 in the `gate` subcommand), then `_resolve_edition "$venv_py" command-v`.
   - `CONVERSUS_HOME` branch: likewise, `_resolve_edition "$venv_py" home`.
   - `$HOME/Sites/conversus/bin/conversus` branch (existing last fallback): rename to `$HOME/Sites/conversus-oss/bin/conversus` tried FIRST, then `$HOME/Sites/conversus/bin/conversus`. Per the single-venv reality both paths often resolve to the same editable install, but this preserves the user-local-probe behavior for operators running ad-hoc from a source tree. Tag each resolution `fallback`. Emit the metadata probe result regardless.
4. **Preserve exact line ordering**: `available=` line first, then `conversus_path=` (or `reason=not-found` for the available=false case), then `edition=`, then `reason=`. This ordering is what T01's truth-check scripts parse.
5. **Update the adapter's top header comment block** (lines ~1-60) to document the new `CONVERSUS_EDITION` env var and the metadata-probe fallback. Add a `See references/architecture.md "Conversus Adapter — Operator Notes" for the operator runbook.` line if not already present (that line was added in commit 32ab6ea; verify it's still there, update only if drifted).
6. **Write `scripts/verify/m026-p02-edition-detection-contract.sh`** (single-script-file shape, AD-19 compliant, Bash 3.2 compatible). Must verify:
   - `check` stdout contains an `edition=` line AND a `reason=` line in every resolution branch (exercise via `CONVERSUS_STUB=1`, via a temp `CONVERSUS_HOME` pointing at a fixture binary, and via the user-local fallback if `~/.local/pipx/venvs/conversus/` is present on the test machine).
   - With `CONVERSUS_EDITION=oss` set, `edition=oss reason=env-override` appears (use `CONVERSUS_STUB=1` to avoid requiring a real venv).
   - With `CONVERSUS_EDITION=foo` set, a stderr warning is emitted AND the probe falls through.
   - With the real OSS venv resolvable, `edition=oss reason=metadata-probe` appears.
   - The ordering of `available=` / `conversus_path=` / `edition=` / `reason=` is stable.
7. **Write `scripts/verify/m026-p02-adapter-invariants.sh`** (single-script-file shape, AD-19 compliant, Bash 3.2 compatible). Must verify:
   - `scripts/dispatch/adapters/tool/conversus.sh` does not introduce `declare -A`, `mapfile`, `readarray`, or process substitution `<(...)`/`>(...)` (grep, not syntax-parse).
   - The 0/1/2 exit-code contract is preserved: `gate [--strict] <preset> <artifact> <output>` with a missing preset still exits 1; stub-mode PASS still exits 0; stub-mode BLOCK still exits 2.
   - `gate-result.md` frontmatter key set (`verdict`, `disputes`, `rationale`, `source_hash`, `preset`, `artifact`, `conversus_output_dir`, `conversus_config`) is still emitted verbatim (use stub-mode PASS invocation to produce a sample and diff key set against a fixed expectation list).
   - The D019 TODO pre-flight block (lines ~166-185 of the adapter, guarded by `CONVERSUS_GATE_SKIP_TODO_CHECK`) is unmodified (grep for the unique error-message substring `artifact contains` and `<TODO: marker(s); gate refuses unauthored drafts`).
   - All env-var references (`CONVERSUS_STUB`, `CONVERSUS_STUB_VERDICT`, `CONVERSUS_HOME`, `CONVERSUS_STRICT`, `CONVERSUS_PROVIDER`, `CONVERSUS_RUN_OUTPUT_DIR`, `CONVERSUS_GATE_TODO_THRESHOLD`, `CONVERSUS_GATE_SKIP_TODO_CHECK`, `CONVERSUS_INTEGRATION`) are still present (grep `${CONVERSUS_*:-`).

## Must-Haves

Addresses phase must-haves:
- "Truth: adapter emits edition= / reason= on check stdout" (T01 owns)
- "Truth: adapter preserves CON-1..CON-3 invariants" (T01 owns)
- Artifacts: `scripts/verify/m026-p02-edition-detection-contract.sh`, `scripts/verify/m026-p02-adapter-invariants.sh`
- Key Link: `scripts/dispatch/adapters/tool/conversus.sh` → `references/architecture.md`

## Verification

```
bash scripts/verify/m026-p02-edition-detection-contract.sh
bash scripts/verify/m026-p02-adapter-invariants.sh
```

Both scripts must print `PASS: <script-basename>` on the final line and exit 0.

Additionally, the unchanged stub-path of the existing integration shim must still pass:

```
bash tests/test-conversus-adapter-shim.sh
```

Expected exit 0, with the stub-path sections passing as before.

## Inputs

### From Previous Tasks

None — T01 is the head of the chain.

### From Disk (Pre-existing)

- `scripts/dispatch/adapters/tool/conversus.sh` — target file to modify. Public surface preserved: subcommands `check` and `gate`; env vars listed above; exit codes 0/1/2; frontmatter key set.
- `tests/fixtures/gate-result-pass.md` and `tests/fixtures/gate-result-block.md` — stub-mode fixtures; MUST NOT be modified.
- `.orchestrator/milestones/M026/M026-CONVERSUS-PARITY.md` — authoritative single-venv reality.
- `.orchestrator/milestones/M026/phases/P01/OLLAMA-PROBE.md` — operator venv inventory.
- `references/architecture.md` "Conversus Adapter — Operator Notes" section — linked from adapter header.

## Constraints

- **CON-1** (adapter invariants): see `m026-p02-adapter-invariants.sh` checks above.
- **CON-2** (Bash 3.2): no `declare -A`, no `mapfile`/`readarray`, no process substitution, no command substitution containing pipes, no plain subshells used as one-liners (per AD-19). Verified by `m026-p02-adapter-invariants.sh` + `scripts/verify/m011-p07-bash32-compat.sh` at phase-close.
- **CON-3** (filename-routed adapter): no new adapter files; all changes land inside `scripts/dispatch/adapters/tool/conversus.sh`.
- **CON-5** (no-conversus-modification): no writes to `~/Sites/conversus` or `~/Sites/conversus-oss` (both read-only from the adapter's POV — metadata probe is a read-only `pip show` against the pipx venv).
- **AD-19** (single-script-file Check shape): every Check command in the P02 plan is `bash scripts/verify/<script>.sh`. Verify scripts themselves use no inline compound bash that would trigger the harness heuristic (no `( … )`, no `$(… | pipe)`, no `cmd <file` inside `$(…)`). When a verification step would naturally require a compound, extract a helper under `scripts/verify/` or use `scripts/util/run-probe.sh`.
- **Stderr vs stdout discipline** (DC-5): the `edition=` and `reason=` lines go to stdout (they join `check`'s structured stdout namespace). Warnings (e.g., `CONVERSUS_EDITION=foo` fallthrough) go to stderr. Do not cross-contaminate.

## Expected Output

- `scripts/dispatch/adapters/tool/conversus.sh` — modified: new `_resolve_edition` helper, `_resolve_binary` updated to emit edition/reason, header comment updated to document `CONVERSUS_EDITION`. Line count delta ≤ +80 lines. No pre-existing blocks renamed or reordered.
- `scripts/verify/m026-p02-edition-detection-contract.sh` — created (~50-80 lines).
- `scripts/verify/m026-p02-adapter-invariants.sh` — created (~60-100 lines).
- `bash scripts/verify/m026-p02-edition-detection-contract.sh` exits 0, prints `PASS: m026-p02-edition-detection-contract.sh`.
- `bash scripts/verify/m026-p02-adapter-invariants.sh` exits 0, prints `PASS: m026-p02-adapter-invariants.sh`.
- `bash tests/test-conversus-adapter-shim.sh` still exits 0 on stub paths (no regression).
