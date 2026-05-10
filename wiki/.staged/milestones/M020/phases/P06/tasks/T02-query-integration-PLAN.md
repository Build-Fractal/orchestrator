---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P06"
milestone: "M020"
name: "Wire query.sh to preferences (default_state_filter)"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped: `scripts/knowledge/lib/preferences.sh` is sourceable and exposes `pref_resolve default_state_filter` returning the effective state filter (project>user>built-in `graduated`).
- P02 has shipped: `scripts/knowledge/query.sh` exists with the FR-2 contract (case-insensitive topic + tags[] match, two-tier ranking, `--state <S>` flag, `--format ids|json`, default state filter `graduated`, read-only invariant FR-8 / CON-1). The P02 contract's external surface (CLI flags, output shape, exit codes) MUST be preserved byte-equivalent (CON-4).
- M020 cross-cutting concern (FR-8 / CON-1): `query.sh` is read-only. Sourcing `preferences.sh` and calling `pref_resolve` adds a read-only step; no writes are introduced.
- AD-19: every verifier's external invocation is a single `bash <script>` call. Internal shell constructs are unrestricted.
- P02 retrospective lesson #1 (Carry-Forward): plan must-haves with literal-string sentinels can drift from implementation reality. This task's verifier asserts BEHAVIOR (effective state-filter resolved correctly), not implementation incidentals.
- M020 ROADMAP P06 dependency edge: `P02 → P06` (query surface honors default_state_filter from preferences).

## Description

Extend `scripts/knowledge/query.sh` IN PLACE with a deferred-resolution pattern for the state filter:

- Source `lib/preferences.sh` once, near the existing `lib/index-utils.sh` and `lib/frontmatter.sh` source lines.
- Replace the line `state_filter="graduated"` (currently the eager initial value) with the empty-string sentinel `state_filter=""`.
- Add a sentinel `state_filter_seen_on_cli=0` initialized to `0`. In the `--state` arm of the argument-parse loop, set it to `1` when the flag is consumed.
- AFTER the argument-parse loop completes (and BEFORE the existing closed-enum validation block at line 91), insert a deferred-resolution block:
  - If `state_filter_seen_on_cli` is 0 AND `state_filter` is empty, call `state_filter="$(pref_resolve default_state_filter)"`. If `pref_resolve` exits non-zero (which it should not for the closed-enum key), fall back to `graduated`.
- The existing closed-enum validation (`case "$state_filter" in candidate|graduated|archived) ;; ...`) then runs against the resolved value, providing belt-and-suspenders defence against a future preference-helper bug or an unexpected vocabulary drift.
- Net behavior: precedence is CLI (`--state <S>`) > project preferences > user preferences > built-in default `graduated`. The CLI-supplied value, when present, ALWAYS wins.

CON-4 byte-equivalence preservation: the existing P02 test suite (`tests/test-knowledge-query.sh`, 9 cases) MUST remain green after this in-place edit. The fixture environment in that test does not declare a preferences file (because T01's verifiers established the fixture-isolation convention with no preferences file present), so the resolved `state_filter` falls through to the built-in default `graduated`, matching the P02 test's expectation. The dispatch-wrapper `scripts/dispatch/dispatch-interface.sh --query` (P02/T03) byte-equivalence is preserved because the wrapper `exec`s `query.sh` — internal `query.sh` changes are transparent to the wrapper.

## Steps

### Step 1: Edit `scripts/knowledge/query.sh` in place

Path: `/Users/brettkellgren/Sites/orchestrator/scripts/knowledge/query.sh`

Edit 1 — add the source line near the existing source lines (around line 33-35):

OLD:

```bash
# shellcheck source=lib/index-utils.sh
. "$SCRIPT_DIR/lib/index-utils.sh"
# shellcheck source=lib/frontmatter.sh
. "$SCRIPT_DIR/lib/frontmatter.sh"
```

NEW:

```bash
# shellcheck source=lib/index-utils.sh
. "$SCRIPT_DIR/lib/index-utils.sh"
# shellcheck source=lib/frontmatter.sh
. "$SCRIPT_DIR/lib/frontmatter.sh"
# shellcheck source=lib/preferences.sh
. "$SCRIPT_DIR/lib/preferences.sh"
```

Edit 2 — replace the eager initial value of `state_filter`:

OLD:

```bash
topic=""
state_filter="graduated"
format="ids"
```

NEW:

```bash
topic=""
state_filter=""
state_filter_seen_on_cli=0
format="ids"
```

Edit 3 — set the CLI-seen sentinel inside the `--state` arm of the argument-parse loop. Locate the existing block:

```bash
    --state)
      [ $# -lt 2 ] && usage
      state_filter="$2"
      shift 2
      ;;
```

Replace with:

```bash
    --state)
      [ $# -lt 2 ] && usage
      state_filter="$2"
      state_filter_seen_on_cli=1
      shift 2
      ;;
```

Edit 4 — insert the deferred-resolution block AFTER the argument-parse `while` loop ends and BEFORE the existing topic-required check + closed-enum validation block. The existing flow currently looks like:

```bash
[ -z "$topic" ] && { echo "FAIL: --topic <X> is required" >&2; usage; }

case "$state_filter" in
  candidate|graduated|archived) ;;
  *)
    echo "FAIL: --state must be one of {candidate, graduated, archived}, got: $state_filter" >&2
    ...
```

Insert between the topic-required check and the case statement:

```bash
[ -z "$topic" ] && { echo "FAIL: --topic <X> is required" >&2; usage; }

# FR-6 / P06: deferred state-filter resolution. CLI > project > user > default.
if [ "$state_filter_seen_on_cli" = "0" ]; then
  resolved_state="$(pref_resolve default_state_filter 2>/dev/null || true)"
  if [ -n "$resolved_state" ]; then
    state_filter="$resolved_state"
  else
    state_filter="graduated"
  fi
fi

case "$state_filter" in
  candidate|graduated|archived) ;;
  ...
```

The closed-enum validation that already exists in `query.sh` then runs against the resolved value, catching the (currently unreachable) corner case where `pref_resolve` returns an unexpected value.

### Step 2: Create `scripts/verify/m020-p06-query-state-from-pref.sh`

Verifier asserts CLI > project > user > default precedence end-to-end through `query.sh`:

- Set up tempdir fixtures: tempdir for `HOME`, tempdir for `PROJECT_ROOT`, tempdir for the knowledge tree.
- Populate the knowledge tree with:
  - One graduated entry on topic X (`status: graduated`, `topic: X`).
  - One candidate entry on topic X (`status: candidate`, `topic: X`).
  - One archived entry on topic X (`status: archived`, `topic: X`).
- Case A: no preferences file anywhere. Run `bash scripts/knowledge/query.sh --topic X` (no `--state`). Assert stdout contains the graduated entry's ID and ONLY that ID (default `graduated`).
- Case B: write `<user-tempdir>/.orchestrator/preferences.yml` with `default_state_filter: candidate`. Run query without `--state`. Assert stdout contains the candidate entry's ID only (user wins over built-in default).
- Case C: write `<project-tempdir>/.orchestrator/preferences.yml` with `default_state_filter: archived`. (User file still says `candidate`.) Run query without `--state`. Assert stdout contains the archived entry's ID only (project wins over user).
- Case D: while project=`archived` and user=`candidate`, run `bash scripts/knowledge/query.sh --topic X --state graduated`. Assert stdout contains the graduated entry's ID only (CLI wins over both).
- Case E: write project file with `default_state_filter: zombie` (malformed — outside closed enum). Keep user=`candidate`. Run query without `--state`. Assert stdout contains the candidate entry's ID (project malformed → fall through to user); stderr contains a `WARN: pref_resolve` line for `default_state_filter`.

Each case asserts exit code 0 and the precise stdout content via grep. Use `pass()`/`fail()` parallel-scalar pattern (MEM002).

### Step 3: Create `scripts/verify/m020-p06-query-pref-side-effect-free.sh`

Verifier asserts FR-8 / CON-1 read-only invariant for the preferences-resolution path:

- Set up tempdir fixtures (HOME, PROJECT_ROOT, knowledge tree) with both project and user preferences files declared.
- Compute md5 hashes of: project preferences file, user preferences file, and a recursive listing of the knowledge tree (file path + md5 per file).
- Run a battery of N=8 query invocations: matched/unmatched topic × default-state/explicit-state × ids/json formats × with-pref-fallback/without.
- Re-compute md5 hashes after the battery.
- Assert: every hash is byte-identical before vs. after. No file mutated. (Strictly stronger than `git status` per the P02/T02 lesson.)
- This proves preferences resolution introduces no writes, even when `pref_resolve` falls through multiple sources.

## Must-Haves

This task addresses the following P06 must-haves:

- Truth: `query.sh` resolves state filter from preferences when no `--state` flag (Check: `m020-p06-query-state-from-pref.sh`).
- Truth: `query.sh` preferences-resolution path is read-only (Check: `m020-p06-query-pref-side-effect-free.sh`).
- Artifact: `scripts/knowledge/query.sh` (min 110 lines, contains `default_state_filter`).
- Artifact: `scripts/verify/m020-p06-query-state-from-pref.sh`.
- Artifact: `scripts/verify/m020-p06-query-pref-side-effect-free.sh`.
- Key Link: `query.sh → lib/preferences.sh` (source line + named comment).

## Verification

```bash
bash scripts/verify/m020-p06-query-state-from-pref.sh
bash scripts/verify/m020-p06-query-pref-side-effect-free.sh
bash tests/test-knowledge-query.sh
```

The third command is the CON-4 byte-equivalence regression gate: P02's existing 9-case integration test must remain green after this in-place edit. Each script exits 0. AD-19 compliant: each is a single `bash <script>` invocation.

## Inputs

### From Previous Tasks

- `scripts/knowledge/lib/preferences.sh` (from T01 of this phase)
  - Key API: `pref_resolve <key>` echoes the effective scalar value of `<key>` on stdout, applying project>user>built-in-default precedence. For `default_state_filter`, returns one of `{candidate, graduated, archived}`.
  - Key types: pure shell helper, sourceable, double-source-guarded with `_PREFERENCES_HELPER_SOURCED` sentinel.
  - Behavioral contract: read-only — never writes to any file. Honors `PROJECT_ROOT` and `HOME` env vars for fixture isolation. Falls back to built-in default with stderr diagnostic on malformed values; built-in default for `default_state_filter` is `graduated`. Closed-enum validation: returns one of `{candidate, graduated, archived}` for `default_state_filter`.

### From Disk (Pre-existing)

- `scripts/knowledge/query.sh` (P02) — the file being edited in place. Existing contract: `--topic <X> [--state <S>] [--format ids|json]`. Default state filter (eager) is `graduated`. Default format is `ids`. Read-only.
- `scripts/knowledge/lib/index-utils.sh`, `scripts/knowledge/lib/frontmatter.sh` (P01) — already sourced by `query.sh`; preferences.sh source line is added adjacent to these.
- `tests/test-knowledge-query.sh` (P02) — the regression gate that proves CON-4 surface preservation after the in-place edit.

## Constraints

- **CON-4 (byte-equivalent surface preservation)**: every existing CLI flag, output shape, exit code, and side-effect-free invariant of `query.sh` MUST remain unchanged. The fixture environment in `tests/test-knowledge-query.sh` does not declare a preferences file; the resolved `state_filter` falls through to `graduated`, matching the P02 test's expectations.
- **CON-1 / FR-8 (read-only)**: `query.sh` MUST NOT introduce any writes. `pref_resolve` itself is read-only; nothing else in this task's edit produces output to disk.
- **AD-19 (single-script-invocation shape)**: each verifier is invoked externally as `bash <script>`. Internal constructs are unrestricted.
- **MEM002 (test conventions)**: verifiers use tempdir + trap cleanup; `HOME` and `PROJECT_ROOT` set to fresh tempdirs (no live filesystem access).
- **MEM001 (Bash 3.2)**: no `declare -A` in any new code.
- **Plan-deviation invariant (P04)**: this task's Verification section names ONLY verifiers authored by this task plus the P02 test (which already exists). No future-task verifiers referenced.

## Expected Output

```
$ bash scripts/verify/m020-p06-query-state-from-pref.sh
PASS: case A no-pref no-CLI -> graduated only
PASS: case B user-only -> candidate only
PASS: case C project-overrides-user -> archived only
PASS: case D CLI-overrides-both -> graduated only
PASS: case E project-malformed -> falls through to user candidate
PASS: case E stderr emits WARN for malformed default_state_filter
RESULT: 6/6 PASS
exit 0

$ bash scripts/verify/m020-p06-query-pref-side-effect-free.sh
PASS: 8-invocation battery — knowledge tree md5 unchanged
PASS: 8-invocation battery — project preferences file md5 unchanged
PASS: 8-invocation battery — user preferences file md5 unchanged
RESULT: 3/3 PASS
exit 0

$ bash tests/test-knowledge-query.sh
... (existing P02 assertions, all pass)
RESULT: 9/9 PASS
exit 0
```
