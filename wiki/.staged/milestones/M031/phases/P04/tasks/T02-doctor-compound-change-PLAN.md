---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M031"
name: "run-doctor.sh compound-change comms (AD-9) + AD-9 acceptance test"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: `templates/orchestrator-config-default.yml` carries both `auto_proceed: true` and `quick_knowledge_token_budget` literals; `CHANGELOG.md` carries the M031 entry naming the compound flip; the SC-9 + SC-10 verifiers exist and pass.
- `scripts/diagnostics/run-doctor.sh` exists at the project root (currently 196 lines per the planner's plan-time inspection).
- `tests/m031-acceptance/` directory exists.
- `tools/verify/` directory exists.
- The shape verifier helper convention (`check_present` / `check_absent` with `grep -qF -- "$needle" "$file"`) is documented in `tools/verify/m031-p03-do-md-shape.sh` — read as the canonical template.

## Description

T02 implements the **active surface** for the AD-9 compound-change comms. The CHANGELOG bullet (T01) is a passive surface — operators only see it if they go looking. The doctor message (T02) is an active surface — `orchestrator:doctor` runs as part of normal lifecycle health checks and emits a one-time message to operators upgrading from a pre-M031 project.

**Detection logic**: an operator's project is "pre-M031" when their active `.orchestrator/config.yml` does NOT contain the literal substring `quick_knowledge_token_budget`. The knob was added in P01; any config initialized post-P01 carries the knob; any config initialized pre-M031 lacks it. Detection by knob-absence is the simplest invariant — no version field, no migration timestamp.

**Message content** (shown when detection fires):

```
M031 (right-sized entry) is active. Two behavioral changes since the last
init of this project's .orchestrator/config.yml:

  1. auto_proceed default flipped from false to true. Dispatch loops now
     auto-proceed past green gates without operator confirmation.
  2. Quick-profile dispatches now inject knowledge + compression
     unconditionally (the pre-M031 'skip context for Quick' shortcut is
     gone). Total task tokens drop because agents no longer rediscover
     context the knowledge graph already holds.

If you prefer the pre-M031 auto-proceed behavior, add this line to
.orchestrator/config.yml:

    auto_proceed: false

The Quick-profile knowledge injection is unconditional; there is no opt-out
short of skipping the orchestrator entirely. To tune the knowledge ceiling,
adjust quick_knowledge_token_budget in your config (default 800 tokens).

This message will not appear again once you re-init or once your
.orchestrator/config.yml carries quick_knowledge_token_budget explicitly.
```

**Test-only seam**: T02 stages an `ORCH_DOCTOR_CONFIG_PATH` env override into the doctor script so the SC test can point doctor at a fixture config under tmp scratch. Production callers do NOT set the env var; the doctor falls back to its existing config-resolution path (typically `.orchestrator/config.yml`).

## Steps

1. **Read `scripts/diagnostics/run-doctor.sh`** with the `Read` tool. Identify:
   - The current config-path resolution (what variable holds the path, where it is computed).
   - The function or section that emits health-check output (where to insert the new compound-change message function).
   - Whether the script already uses `set -u` / `set -e` (preserve existing strictness).

2. **Add the `ORCH_DOCTOR_CONFIG_PATH` env override** at the config-resolution site. Pseudo-shape:

   ```bash
   # M031/P04/T02: test-only env override for fixture-driven AD-9 testing.
   if [ -n "${ORCH_DOCTOR_CONFIG_PATH:-}" ]; then
     CONFIG_PATH="$ORCH_DOCTOR_CONFIG_PATH"
   else
     CONFIG_PATH="$(<existing resolution logic>)"
   fi
   ```

   Place the override AT THE TOP of the existing resolution so the env var beats every fallback. Preserve the existing fallback behavior unchanged.

3. **Add the compound-change comms function** near the bottom of the script (after existing health checks, before the final exit). Insert a new function `m031_compound_change_check` with this exact body shape (executor authors verbatim — verifiers grep for literal substrings):

   ```bash
   # M031/P04/T02: AD-9 compound-change comms. Emits a one-time message
   # when the active config lacks quick_knowledge_token_budget (i.e. the
   # config predates M031). Detection by knob-absence is the simplest
   # invariant — no version field, no migration timestamp.
   m031_compound_change_check() {
     # $1 config_path
     local cfg="$1"
     if [ ! -f "$cfg" ]; then
       return 0
     fi
     if grep -q -F -- "quick_knowledge_token_budget" "$cfg"; then
       return 0
     fi
     printf '\n'
     printf 'M031 (right-sized entry) is active. Two behavioral changes since the\n'
     printf 'last init of this project'\''s .orchestrator/config.yml:\n'
     printf '\n'
     printf '  1. auto_proceed default flipped from false to true. Dispatch loops\n'
     printf '     now auto-proceed past green gates without operator confirmation.\n'
     printf '  2. Quick-profile dispatches now inject knowledge + compression\n'
     printf '     unconditionally (the pre-M031 skip-context-for-Quick shortcut is\n'
     printf '     gone). Total task tokens drop because agents no longer rediscover\n'
     printf '     context the knowledge graph already holds.\n'
     printf '\n'
     printf 'If you prefer the pre-M031 auto_proceed behavior, add this line to\n'
     printf '.orchestrator/config.yml:\n'
     printf '\n'
     printf '    auto_proceed: false\n'
     printf '\n'
     printf 'To tune the knowledge ceiling, adjust quick_knowledge_token_budget\n'
     printf 'in your config (default 800 tokens).\n'
     printf '\n'
     printf 'This message will not appear again once your .orchestrator/config.yml\n'
     printf 'carries quick_knowledge_token_budget explicitly.\n'
     printf '\n'
     return 0
   }
   ```

   Then call the function in the doctor's main flow:

   ```bash
   m031_compound_change_check "$CONFIG_PATH"
   ```

   Place the call at a stable point in the existing health-check sequence (e.g. after config-existence checks but before lock-file checks).

4. **Confirm the doctor script post-edit shape**:
   - The literal substring `M031` appears at least 4 times (function comment + function name + at least 2 message-body lines).
   - The literal substring `quick_knowledge_token_budget` appears at least 2 times (the absence-check `grep` and the message body).
   - The literal substring `auto_proceed` appears at least 2 times (the message body recovery instructions).
   - The script remains bash 3.2 compatible (no `declare -A`, no process substitution, no `$(...)` containing pipes inside conditionals).
   - The script's existing exit-code contract is preserved (T02 does NOT change exit codes).

5. **Author `tests/m031-acceptance/test-doctor-compound-change.sh`** (≥ 50 lines, executable). Body shape:

   ```bash
   #!/usr/bin/env bash
   # tests/m031-acceptance/test-doctor-compound-change.sh
   # M031/P04/T02 — AD-9 doctor compound-change acceptance test.
   #
   # Exercises both the absent-knob and present-knob branches of the
   # m031_compound_change_check function in scripts/diagnostics/run-doctor.sh.
   #
   # Emits RESULT: AD-9 pass (exit 0) or RESULT: AD-9 fail (exit 1).

   set -u
   PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   DOCTOR="$PROJECT_ROOT/scripts/diagnostics/run-doctor.sh"

   work=$(mktemp -d)
   trap 'rm -rf "$work"' EXIT

   absent_cfg="$work/absent.yml"
   present_cfg="$work/present.yml"

   # Fixture absent-knob config (pre-M031 shape — lacks quick_knowledge_token_budget)
   printf 'auto_proceed: false\n' >"$absent_cfg"

   # Fixture present-knob config (post-M031 shape)
   printf 'auto_proceed: true\nquick_knowledge_token_budget: 800\n' >"$present_cfg"

   pass=0
   fail=0

   # Absent-knob run: doctor MUST emit the compound-change message
   absent_out=$(ORCH_DOCTOR_CONFIG_PATH="$absent_cfg" bash "$DOCTOR" 2>&1 || true)
   if printf '%s\n' "$absent_out" | grep -qF -- "M031"; then
     printf 'PASS: absent-knob fixture emits M031 message\n'
     pass=$((pass + 1))
   else
     printf 'FAIL: absent-knob fixture missing M031 message\n'
     fail=$((fail + 1))
   fi
   if printf '%s\n' "$absent_out" | grep -qF -- "auto_proceed"; then
     printf 'PASS: absent-knob fixture names auto_proceed\n'
     pass=$((pass + 1))
   else
     printf 'FAIL: absent-knob fixture missing auto_proceed\n'
     fail=$((fail + 1))
   fi
   if printf '%s\n' "$absent_out" | grep -qF -- "quick_knowledge_token_budget"; then
     printf 'PASS: absent-knob fixture names quick_knowledge_token_budget\n'
     pass=$((pass + 1))
   else
     printf 'FAIL: absent-knob fixture missing quick_knowledge_token_budget\n'
     fail=$((fail + 1))
   fi

   # Present-knob run: doctor MUST NOT emit the compound-change message
   present_out=$(ORCH_DOCTOR_CONFIG_PATH="$present_cfg" bash "$DOCTOR" 2>&1 || true)
   if printf '%s\n' "$present_out" | grep -qF -- "M031 (right-sized entry) is active"; then
     printf 'FAIL: present-knob fixture unexpectedly emits M031 message\n'
     fail=$((fail + 1))
   else
     printf 'PASS: present-knob fixture suppresses M031 message\n'
     pass=$((pass + 1))
   fi

   printf 'AD-9 totals: pass=%d fail=%d\n' "$pass" "$fail"
   if [ "$fail" -eq 0 ]; then
     printf 'RESULT: AD-9 pass\n'
     exit 0
   fi
   printf 'RESULT: AD-9 fail\n'
   exit 1
   ```

   `chmod +x tests/m031-acceptance/test-doctor-compound-change.sh`.

   Note: the test uses `2>&1` to capture stdout and stderr together because the doctor script may emit health-check output to either stream. The `|| true` after the doctor invocation guards against the doctor exiting non-zero for unrelated reasons (T02 does not change doctor exit codes; the test only inspects the captured output).

6. **Author `tools/verify/m031-p04-doctor-compound-change-shape.sh`** (≥ 25 lines, executable). Asserts the doctor script post-edit contains the required literals:
   - `check_present scripts/diagnostics/run-doctor.sh "M031"`
   - `check_present scripts/diagnostics/run-doctor.sh "quick_knowledge_token_budget"`
   - `check_present scripts/diagnostics/run-doctor.sh "auto_proceed"`
   - `check_present scripts/diagnostics/run-doctor.sh "m031_compound_change_check"`
   - `check_present scripts/diagnostics/run-doctor.sh "ORCH_DOCTOR_CONFIG_PATH"`

   AD-19 single-script-file shape; emits `SUMMARY: m031-p04-doctor-compound-change-shape.sh pass=N fail=M`; exits 0 iff `fail == 0`.

7. **Author `tools/verify/m031-p04-test-doctor-compound-change-shape.sh`** (≥ 20 lines, executable). Asserts the SC test exists, executable, and references the right artifacts:
   - `check_present tests/m031-acceptance/test-doctor-compound-change.sh "AD-9"`
   - `check_present tests/m031-acceptance/test-doctor-compound-change.sh "run-doctor.sh"`
   - `check_present tests/m031-acceptance/test-doctor-compound-change.sh "ORCH_DOCTOR_CONFIG_PATH"`
   - `check_present tests/m031-acceptance/test-doctor-compound-change.sh "quick_knowledge_token_budget"`

   AD-19 single-script-file shape; emits `SUMMARY: m031-p04-test-doctor-compound-change-shape.sh pass=N fail=M`; exits 0 iff `fail == 0`.

8. **Run each verifier locally to confirm exit 0**:

   ```bash
   bash tests/m031-acceptance/test-doctor-compound-change.sh
   ```

   ```bash
   bash tools/verify/m031-p04-doctor-compound-change-shape.sh
   ```

   ```bash
   bash tools/verify/m031-p04-test-doctor-compound-change-shape.sh
   ```

9. **Commit T02 deliverables** via `git commit -F <message-file>` (NOT inline HEREDOC). Suggested commit subject: `M031/P04/T02: run-doctor.sh AD-9 compound-change comms + acceptance test`.

## Must-Haves

This task addresses the following Must-Haves from `P04-PLAN.md`:
- "`scripts/diagnostics/run-doctor.sh` post-amend emits a one-time M031 compound-change message when invoked against a project whose `.orchestrator/config.yml` lacks `quick_knowledge_token_budget` (AD-9)" (Truth #5; Check via `m031-p04-doctor-compound-change-shape.sh`)
- "`tests/m031-acceptance/test-doctor-compound-change.sh` (AD-9) exists, is executable, and exits 0" (Truth #9; Check via `m031-p04-test-doctor-compound-change-shape.sh`)

## Verification

```bash
bash tests/m031-acceptance/test-doctor-compound-change.sh
```

```bash
bash tools/verify/m031-p04-doctor-compound-change-shape.sh
```

```bash
bash tools/verify/m031-p04-test-doctor-compound-change-shape.sh
```

## Notes

- The compound-change message is intentionally verbose (≈ 18 lines of prose). Operators upgrading from a pre-M031 project see the message exactly once per project (until they re-init or their config grows the `quick_knowledge_token_budget` knob). After that, the message stays silent forever.
- The test uses `mktemp -d` for a hermetic scratch root and `trap rm -rf EXIT` for cleanup — same hermetic-tmp pattern as the P03 SC-7 / SC-8 tests.
- The doctor's existing exit-code contract is preserved by T02. The new `m031_compound_change_check` function ALWAYS returns 0 (it's an informational comm, not a gate). The caller does not need to test rc.
- The test captures `2>&1` because the doctor's output stream choice for the new message is implementation-defined (stdout makes sense for an operator-facing comm; stderr is also reasonable). The test grep is stream-agnostic.
- The fixture configs use `printf '%s'` (POSIX-portable) rather than `echo -e` (non-portable).
- **Real-app smoke test pending** (plan-time discipline rule 5): the test exercises the function via env-override fixture configs. Production confirmation that an operator running `orchestrator:doctor` against a real pre-M031 project sees the message is the [M033](../../../../../milestones/M033/index.md) onboarding milestone's job; T02's gates confirm the contract surface.
- **Section discipline** (per the plan-phase rubric M028/P01 finding): the `## Verification` section above contains ONLY executable check commands inside fenced ` ```bash ` blocks. The expected-output prose ("RESULT: AD-9 pass") is documented in this `## Notes` section, NOT inside a Verification fenced block — fenced lines under `## Verification` are eval'd by `auto-loop.sh --step=V`.

## Inputs

### From Previous Tasks

- **T01: `templates/orchestrator-config-default.yml`** carries the `quick_knowledge_token_budget` literal (T01 confirmed/added it). T02's doctor amendment uses the absence of this literal in an active config as the pre-M031 detector.
- **T01: `CHANGELOG.md`** carries the M031 compound-flip entry. T02's doctor message names the same compound change so an operator who reads either surface sees the same vocabulary.

### From Previous Phases

- **P01 (FR-5 `quick_knowledge_token_budget` config knob)** — P01 added the knob to `templates/orchestrator-config-default.yml`. T02 grep-detects the knob's absence as the M031 trigger.
- **P03 (`scripts/intake/do-entry.sh` config-knob resolution pattern)** — P03 used direct YAML grep for `entry_routing_confidence_floor` resolution. T02 reuses the same pattern (direct YAML grep) for the absence detection — no `read-config.sh` `VALID_KEYS` extension required.

### From Disk (Pre-existing)

- `scripts/diagnostics/run-doctor.sh` — read for the existing config-resolution logic + health-check function structure.
- `tools/verify/m031-p03-do-md-shape.sh` — read as the canonical shape-verifier template (header + helpers + `printf 'SUMMARY: ...'`).

## Constraints

- **Bash 3.2 compatibility** (MEM001) for both the doctor amendment and the test.
- **AD-19 single-script-file shape** for the Truth `Check:` invocations and verifier internals. The doctor script itself MAY use existing compound shapes that pre-date AD-19 — T02 does NOT refactor the doctor's existing code, only ADDS new function + call.
- **No edits to T01 deliverables** in T02. Specifically: `commands/evaluate.md`, `references/tier-definitions.md`, `templates/orchestrator-config-default.yml`, `CHANGELOG.md`, `tests/m031-acceptance/doc-drift-verifier.sh`, `tests/m031-acceptance/test-auto-proceed-default.sh`, and the six T01 shape verifiers are byte-frozen post-T01.
- **No edits to `scripts/intake/`, `scripts/dispatch/`, or `commands/`** in T02. T02 touches only `scripts/diagnostics/run-doctor.sh`, the new SC test, and the two new shape verifiers.
- **CON-7 / D020**: no scaffold-placeholder marker bracket-TODO byte pattern in any new file.
- **SC-12 scope-guard**: T02 must NOT touch `knowledge/**`, `scripts/cost/`, `scripts/dispatch/adapters/router/`, or `scripts/auto/loop/`.
- **CON-1 invariant** (knowledge-unconditional): T02's doctor amendment is a passive observation surface — it does NOT change dispatch behavior. CON-1 is unaffected.
- **Commit shape**: multi-line messages MUST use `git commit -F <message-file>`. The AP-008 shape-guard rejects the inline HEREDOC form per CLAUDE.md.

## Expected Output

After T02 completes:

1. `scripts/diagnostics/run-doctor.sh` modified — contains `m031_compound_change_check` function + call site + `ORCH_DOCTOR_CONFIG_PATH` env override + `M031` + `quick_knowledge_token_budget` + `auto_proceed` literal substrings.
2. `tests/m031-acceptance/test-doctor-compound-change.sh` (≥ 50 lines, executable) — exits 0 with `RESULT: AD-9 pass` against fixture absent-knob and present-knob configs.
3. `tools/verify/m031-p04-doctor-compound-change-shape.sh` (≥ 25 lines, executable) — exits 0 with `SUMMARY: m031-p04-doctor-compound-change-shape.sh pass=N fail=0`.
4. `tools/verify/m031-p04-test-doctor-compound-change-shape.sh` (≥ 20 lines, executable) — exits 0 with `SUMMARY: m031-p04-test-doctor-compound-change-shape.sh pass=N fail=0`.

T02 leaves the active comms surface for the AD-9 compound change in place. T03 picks up with the AD-19 budget-drift warning on the [M027](../../../../../milestones/M027/index.md) efficiency-footer.
