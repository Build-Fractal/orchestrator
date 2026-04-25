---
schema_version: "1.0"
task: "T01"
phase: "P03"
milestone: "M026"
name: "Preset-frontmatter `edition_required:` parser + paid-only-on-OSS diagnostic (FR-10, FR-11)"
depends_on: []
---

## Prerequisites

- `scripts/dispatch/adapters/tool/conversus.sh` exists with the P02-shipped resolver helpers `_resolve_binary` (lines ~81-130) and `_resolve_edition` (lines ~132-179), and the `gate` subcommand body (lines ~222-513).
- `tests/fixtures/gate-result-pass.md` and `tests/fixtures/gate-result-block.md` exist (used by the stub-mode shim — MUST NOT be modified).
- Spec 027 §FR-10 (preset-edition_required-field) and §FR-11 (diagnostic-on-paid-only-surface) define the contract. Diagnostic regex per FR-11: `ERROR: preset '<name>' requires paid Conversus \(edition_required: paid\); resolved edition is oss\. Set CONVERSUS_EDITION=paid or install the paid build at \$HOME/Sites/conversus/bin/conversus\.`

## Description

Extend the `gate` subcommand of `scripts/dispatch/adapters/tool/conversus.sh` to:

1. Parse the YAML frontmatter of the resolved preset file (`${_REPO_ROOT}/templates/conversus-presets/${_preset_name}.yml`) for an optional top-level `edition_required:` key. Bash-3.2-compatible parsing — no Python, no yq. Use `awk` or a `sed`-driven scan of lines between the leading `---` and the next `---`.

2. When `edition_required: paid` is present in the preset frontmatter AND the resolved binary's edition (already computed by `_resolve_binary` / `_resolve_edition` and present on the `_probe` stdout as `edition=oss|paid|unknown`) is `oss`, emit the FR-11 diagnostic to stderr and exit 1 BEFORE the `conversus run` invocation. Specifically: before `_conv_tmp` is created (currently around line 354), so no upstream work is triggered.

3. When the preset has no `edition_required:` field, behave identically to today (backward-compatible per FR-10's "Presets without it behave identically").

4. When `edition_required: paid` AND resolved edition is `paid`, proceed normally — no diagnostic.

5. When `edition_required: paid` AND resolved edition is `unknown` (e.g., stub mode, or metadata-probe failed under a real binary), do NOT block: stub mode is edition-agnostic by design (T03 of P02), and a metadata-probe failure under a real binary should not silently translate into a refusal — the existing precedence (`CONVERSUS_EDITION` env var primary, metadata probe fallback) already gives the operator a way to declare the edition. Refusing on `unknown` would create a false-positive class of failures that the operator has no clear remediation for. Document this choice in an inline comment near the diagnostic block.

The diagnostic firing point sits AFTER the existing `_resolve_binary` call (line 303) and AFTER preset/artifact existence checks (lines ~237-245), but BEFORE the TODO pre-flight (lines ~257-266) — placement: right before the `_conv_tmp="$(mktemp ...)"` line at line 354. Stub-mode (line 269) short-circuits the gate entirely, so the diagnostic naturally does not fire in stub mode (which matches point 5 above).

T01 also creates the verifier `scripts/verify/m026-p03-edition-required-diagnostic.sh` which exercises FR-11 end-to-end via a fixture preset and `CONVERSUS_STUB`/`CONVERSUS_EDITION` orchestration.

## Steps

1. **Read the current adapter** at `scripts/dispatch/adapters/tool/conversus.sh` lines 222-380 to confirm the `gate` subcommand structure has not drifted since the spec quote above. In particular, confirm:
   - Line ~237: `_preset_file="${_REPO_ROOT}/templates/conversus-presets/${_preset_name}.yml"` is unchanged.
   - Line ~303: `_probe="$(_resolve_binary)"` produces stdout including `edition=...` (P02/T01 contract).
   - Line ~354: `_conv_tmp="$(mktemp -d ...)"` is the first heavy side-effect.

2. **Insert preset-frontmatter parsing helper** as a new function placed immediately before the `case "$SUBCMD" in` block (around line 215, just after `_REPO_ROOT` is computed). Function signature:

   ```sh
   # _read_preset_edition_required <preset-file-path>
   # Emits the value of the top-level `edition_required:` key in the YAML
   # frontmatter (the block between the leading `---` and the next `---`),
   # or empty string if the key is absent or the file has no frontmatter.
   # Bash 3.2 / awk-only — no python, no yq.
   _read_preset_edition_required() {
     _rper_file="$1"
     [ -f "$_rper_file" ] || { echo ""; return 0; }
     awk '
       /^---[[:space:]]*$/ { fm++; next }
       fm == 1 && /^edition_required:[[:space:]]*/ {
         val = $0
         sub(/^edition_required:[[:space:]]*/, "", val)
         sub(/[[:space:]]*$/, "", val)
         gsub(/"/, "", val)
         gsub(/\x27/, "", val)
         print val
         exit
       }
       fm >= 2 { exit }
     ' "$_rper_file"
   }
   ```

   Placement notes:
   - The `\x27` escape is a single-quote inside the awk string. Bash 3.2 supports `\x27` in single-quoted strings inside awk literals; verify by running `awk 'BEGIN { print "\x27" }'` on the dev machine and confirming a single quote prints.
   - The function MUST be defined before the `case "$SUBCMD" in` block so the `gate` branch can call it.

3. **Insert the diagnostic block** in the `gate` subcommand body. Placement: after line 320 (the `_bin_path` extraction guard) and before line 322 (the "--- Shim" comment block). The block:

   ```sh
   # FR-10 / FR-11: paid-only-preset-on-OSS refusal.
   # If the preset's frontmatter declares edition_required: paid AND the
   # resolved edition (from _resolve_binary stdout above) is oss, refuse
   # to invoke conversus run. The diagnostic points at the escape hatch
   # so the operator has an actionable remediation. We refuse only on
   # the explicit oss case; on edition=unknown (e.g. metadata-probe
   # failure with no CONVERSUS_EDITION declared) we proceed rather than
   # block — refusing on unknown would be a false-positive class with
   # no clear remediation, and the operator can already declare the
   # edition via CONVERSUS_EDITION=paid if they want strict gating.
   _required_edition="$(_read_preset_edition_required "$_preset_file")"
   _resolved_edition="$(printf '%s\n' "$_probe" | grep -E '^edition=' | head -n 1 | sed -E 's/^edition=//')"
   if [ "$_required_edition" = "paid" ] && [ "$_resolved_edition" = "oss" ]; then
     _emit_fail "preset '${_preset_name}' requires paid Conversus (edition_required: paid); resolved edition is oss. Set CONVERSUS_EDITION=paid or install the paid build at \$HOME/Sites/conversus/bin/conversus."
     exit 1
   fi
   ```

   Note: `_emit_fail` (defined at line 77) prefixes its argument with `FAIL:` and writes to stderr. The FR-11 regex requires `ERROR:`, but the existing adapter convention is `FAIL:` for stderr diagnostics — this is a documented prose-vs-regex tension in spec 027. The case-insensitive SC-7 regex `paid-only.*CONVERSUS_EDITION=paid` matches our message body regardless of `FAIL:`/`ERROR:` prefix. The verifier at step 5 below uses the case-insensitive SC-7 regex, not the FR-11 literal `ERROR:` opener. This decision should be cross-referenced in the inline comment AND captured in the T01 summary so T04's DECISIONS.md row can fold it in.

   Update the inline comment to call out the prefix difference:

   ```sh
   # Prefix is FAIL: per the adapter's stderr convention (line 77's
   # _emit_fail), not the FR-11 literal ERROR:. The case-insensitive
   # SC-7 regex `paid-only.*CONVERSUS_EDITION=paid` matches the body,
   # so the contract is preserved. See P03/T04 DECISIONS.md row for
   # the prefix-uniformity rationale.
   ```

   Wait — re-reading the diagnostic message: it says "preset 'X' requires paid Conversus" and "Set CONVERSUS_EDITION=paid". The SC-7 regex is `paid-only.*CONVERSUS_EDITION=paid` (case-insensitive). The substring "paid" appears multiple times but "paid-only" does NOT appear in the message above. The verifier needs to either match the actual message OR the message needs to include "paid-only".

   Resolution: rewrite the diagnostic body to include the literal "paid-only" substring so SC-7's regex matches:

   ```sh
   _emit_fail "preset '${_preset_name}' invokes a paid-only surface (edition_required: paid); resolved edition is oss. Set CONVERSUS_EDITION=paid or install the paid build at \$HOME/Sites/conversus/bin/conversus."
   ```

   This still satisfies FR-11's intent (preset name + edition requirement + escape-hatch pointer) and matches SC-7's regex.

4. **Update the adapter header comment** (lines 30-34, the M026/P02 edition-detection block) to document the new FR-10/FR-11 behavior. Add a short paragraph after the existing edition-detection paragraph:

   ```sh
   # Paid-only-preset refusal (M026/P03): when a preset's YAML frontmatter
   # declares `edition_required: paid` and the resolved edition is `oss`,
   # the gate subcommand emits a FAIL: diagnostic and exits 1 BEFORE any
   # conversus run invocation. Presets with no `edition_required:` key are
   # backward-compatible. Diagnostic message contains the literal
   # "paid-only" + "CONVERSUS_EDITION=paid" so SC-7's case-insensitive
   # regex matches.
   ```

5. **Create `tests/fixtures/preset-edition-required-paid.yml`** as a minimal fixture preset with the new frontmatter field. Content:

   ```yaml
   ---
   edition_required: paid
   ---
   # Test fixture for M026/P03 FR-11 — preset with edition_required: paid.
   # Used by scripts/verify/m026-p03-edition-required-diagnostic.sh to
   # exercise the paid-only-on-OSS refusal path. Not invoked by any real
   # gate; the diagnostic fires before any conversus run subprocess.
   mode: cooperative
   agents:
     - name: noop
       prompt: "noop"
   ```

   The fixture is intentionally invalid as a real conversus preset — it never reaches `conversus run`, so the body shape does not matter. Frontmatter is the only load-bearing surface.

   Place the file at `tests/fixtures/preset-edition-required-paid.yml`. The adapter's preset-resolution logic at line 237 expects presets under `templates/conversus-presets/`, NOT `tests/fixtures/`. The verifier (step 6) handles this by either (a) symlinking/copying the fixture into `templates/conversus-presets/` for the duration of the test then cleaning up, OR (b) setting `_preset_file` indirection via a wrapper invocation. Option (a) is simpler and is what the verifier should do — copy the fixture into `templates/conversus-presets/m026-p03-test-paid.yml` at test setup, exercise the gate, remove the file at test teardown via `trap`.

6. **Create `scripts/verify/m026-p03-edition-required-diagnostic.sh`** (single-script-file shape, AD-19 compliant, Bash 3.2 compatible). The verifier must:

   ```sh
   #!/usr/bin/env bash
   # scripts/verify/m026-p03-edition-required-diagnostic.sh
   # Verifies M026/P03/T01: paid-only-preset-on-OSS refusal (FR-11/SC-7)
   # and backward-compatibility for presets without edition_required.
   set -u

   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   ADAPTER="${REPO_ROOT}/scripts/dispatch/adapters/tool/conversus.sh"
   FIXTURE_SRC="${REPO_ROOT}/tests/fixtures/preset-edition-required-paid.yml"
   PRESET_DIR="${REPO_ROOT}/templates/conversus-presets"
   PRESET_NAME="m026-p03-test-paid"
   PRESET_FILE="${PRESET_DIR}/${PRESET_NAME}.yml"

   pass=0; fail=0
   _pass() { pass=$((pass+1)); echo "PASS: $1"; }
   _fail() { fail=$((fail+1)); echo "FAIL: $1"; }

   # Setup: copy fixture into templates/conversus-presets/, ensure cleanup.
   cp "$FIXTURE_SRC" "$PRESET_FILE"
   trap 'rm -f "$PRESET_FILE"' EXIT

   ARTIFACT="$(mktemp)"
   echo "# minimal artifact for fixture" > "$ARTIFACT"
   OUTPUT="$(mktemp)"

   # Case A: edition_required=paid + resolved=oss → exit 1 + SC-7 regex on stderr.
   STDERR_FILE="$(mktemp)"
   CONVERSUS_STUB=0 CONVERSUS_EDITION=oss CONVERSUS_GATE_SKIP_TODO_CHECK=1 \
     bash "$ADAPTER" gate "$PRESET_NAME" "$ARTIFACT" "$OUTPUT" 2>"$STDERR_FILE"
   rc_a=$?
   if [ "$rc_a" = "1" ]; then _pass "Case A: exit 1 on edition_required=paid + edition=oss"; else _fail "Case A: expected exit 1, got $rc_a"; fi
   if grep -qiE 'paid-only.*CONVERSUS_EDITION=paid' "$STDERR_FILE"; then _pass "Case A: SC-7 regex matched on stderr"; else _fail "Case A: SC-7 regex not matched on stderr (content: $(cat "$STDERR_FILE"))"; fi

   # Case B: edition_required=paid + resolved=paid → no diagnostic, proceeds to stub-mode-or-real-mode path.
   # We use CONVERSUS_STUB=1 to short-circuit before the heavy path. Note: stub mode skips the gate body
   # entirely and uses fixture, so the diagnostic NEVER fires under stub. This case asserts that point.
   STDERR_FILE_B="$(mktemp)"
   CONVERSUS_STUB=1 CONVERSUS_EDITION=paid CONVERSUS_GATE_SKIP_TODO_CHECK=1 \
     bash "$ADAPTER" gate "$PRESET_NAME" "$ARTIFACT" "$OUTPUT" 2>"$STDERR_FILE_B"
   rc_b=$?
   if [ "$rc_b" = "0" ]; then _pass "Case B: stub-mode path unaffected (exit 0)"; else _fail "Case B: expected exit 0 from stub, got $rc_b"; fi
   if ! grep -qiE 'paid-only' "$STDERR_FILE_B"; then _pass "Case B: no diagnostic under stub (edition-agnostic per P02/T03)"; else _fail "Case B: diagnostic fired in stub mode (regression)"; fi

   # Case C: backward-compat — preset without edition_required, edition=oss → no diagnostic.
   # Use the existing normalize-fidelity preset (no edition_required field) via stub mode for hermeticity.
   STDERR_FILE_C="$(mktemp)"
   CONVERSUS_STUB=1 CONVERSUS_EDITION=oss CONVERSUS_GATE_SKIP_TODO_CHECK=1 \
     bash "$ADAPTER" gate normalize-fidelity "$ARTIFACT" "$OUTPUT" 2>"$STDERR_FILE_C"
   rc_c=$?
   if [ "$rc_c" = "0" ]; then _pass "Case C: backward-compat (preset without edition_required)"; else _fail "Case C: backward-compat broke (rc=$rc_c)"; fi
   if ! grep -qiE 'paid-only' "$STDERR_FILE_C"; then _pass "Case C: no diagnostic for preset without edition_required"; else _fail "Case C: spurious diagnostic on edition_required-absent preset"; fi

   echo "----"
   echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   echo "PASS: $(basename "$0")"
   exit 0
   ```

   Notes:
   - Every nested `bash ... 2>file` and `grep` is a single-line invocation. No `( ... )` subshells, no `$(... | pipe)`, no compound chains beyond `&&`/`||` of two commands.
   - `trap 'rm -f "$PRESET_FILE"' EXIT` cleans up the copied fixture on any exit path.
   - The verifier uses `CONVERSUS_GATE_SKIP_TODO_CHECK=1` because the minimal artifact contains no `<TODO:` markers but the bypass is documented as the test path (D019 §3).
   - Case A is the load-bearing assertion — Case B/C document the orthogonal invariants.

7. **Run the verifier locally** to confirm green:

   ```sh
   bash scripts/verify/m026-p03-edition-required-diagnostic.sh
   ```

   Expected final output:
   ```
   ----
   SUMMARY: m026-p03-edition-required-diagnostic.sh pass=6 fail=0
   PASS: m026-p03-edition-required-diagnostic.sh
   ```

8. **Re-run M011/P07 invariant gates** to confirm CON-1..CON-5 are not regressed:

   ```sh
   bash scripts/verify/m011-p07-conversus-adapter-shape.sh
   bash scripts/verify/m011-p07-gate-pass-block.sh
   bash scripts/verify/m011-p07-bash32-compat.sh
   ```

   All three must exit 0.

## Must-Haves

Addresses phase must-haves:
- "Truth: adapter refuses on edition_required=paid + resolved=oss with SC-7 regex on stderr"
- "Truth: adapter does not regress CON-1..CON-5 invariants"
- Artifacts: `scripts/verify/m026-p03-edition-required-diagnostic.sh`, `tests/fixtures/preset-edition-required-paid.yml`, `scripts/dispatch/adapters/tool/conversus.sh` (modified)

## Verification

```
bash scripts/verify/m026-p03-edition-required-diagnostic.sh
bash scripts/verify/m011-p07-conversus-adapter-shape.sh
bash scripts/verify/m011-p07-gate-pass-block.sh
bash scripts/verify/m011-p07-bash32-compat.sh
```

All four must exit 0 with a `PASS:` final line.

## Inputs

### From Previous Tasks

None — T01 is independent within P03. Reads upstream P02 contract (the `_resolve_binary` / `_resolve_edition` shape that emits `edition=` on stdout); P02 already shipped that.

### From Disk (Pre-existing)

- `scripts/dispatch/adapters/tool/conversus.sh` — target file. Public surface preserved: subcommands `check` / `gate` / `parse-verdict`; env vars unchanged; exit codes 0/1/2; `gate-result.md` frontmatter key set; D019 TODO pre-flight unmodified; stub-mode path untouched.
- `templates/conversus-presets/normalize-fidelity.yml` — used as backward-compat baseline (Case C).
- `tests/fixtures/gate-result-pass.md` and `tests/fixtures/gate-result-block.md` — stub-mode fixtures, MUST NOT be modified.
- `scripts/verify/m011-p07-conversus-adapter-shape.sh`, `scripts/verify/m011-p07-gate-pass-block.sh`, `scripts/verify/m011-p07-bash32-compat.sh` — invariant gates, used as regression guards.

## Constraints

- **CON-1..CON-5** (adapter invariants): preserved. Verified by `m011-p07-*` gates above.
- **CON-2** (Bash 3.2): no `declare -A`, no `mapfile`/`readarray`, no process substitution. The awk frontmatter-parser uses only POSIX awk features.
- **AD-7** (revise-in-place): no new adapter files; all changes land inside `scripts/dispatch/adapters/tool/conversus.sh`.
- **AD-19** (single-script-file Check shape): every Check command in the P03 plan is `bash scripts/verify/<script>.sh`. The verifier itself uses no inline compound bash that would trigger the harness heuristic.
- **Stub-mode hermeticity**: the preset-frontmatter parse + diagnostic block fires AFTER the stub-mode short-circuit (line 269). Stub mode is edition-agnostic by P02/T03 contract; this is preserved.
- **No upstream work on refusal**: diagnostic fires BEFORE `_conv_tmp="$(mktemp ...)"` so no temp dir, no synthesizer subprocess, no `conversus run` invocation occurs on refusal. Verified by Case A's exit-1 fast-path.

## Expected Output

- `scripts/dispatch/adapters/tool/conversus.sh` — modified: new `_read_preset_edition_required` helper (~15 lines) defined before the `case "$SUBCMD"` block; new diagnostic block (~10 lines) inserted in the `gate` body before `_conv_tmp` creation; header comment updated. Line-count delta ≤ +35 lines.
- `tests/fixtures/preset-edition-required-paid.yml` — created (~10 lines).
- `scripts/verify/m026-p03-edition-required-diagnostic.sh` — created (~70-90 lines).
- `bash scripts/verify/m026-p03-edition-required-diagnostic.sh` exits 0, prints `SUMMARY: ... pass=6 fail=0` and `PASS: m026-p03-edition-required-diagnostic.sh`.
- All three M011/P07 invariant gates still exit 0.
