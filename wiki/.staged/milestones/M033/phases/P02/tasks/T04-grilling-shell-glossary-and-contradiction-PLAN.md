---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M033"
name: "Grilling-shell glossary inline-update writer + MIT-007 contradiction-detection wiring + SC-11 acceptance (FR-17 / FR-18 / MIT-007)"
depends_on: ["T03"]
---

## Prerequisites

- T03 complete: `scripts/lifecycle/grilling-shell.sh` exists with the core `ask_one` API, recommendation-not-interrogation framing, and reserved fenced SSOT block markers (`# >>> contradiction-pairs >>>`, `# >>> glossary-triggers >>>`) plus stub helper functions (`_grilling_check_contradiction`, `_grilling_glossary_update`). Verified by `[ -f scripts/lifecycle/grilling-shell.sh ]` AND `grep -q 'contradiction-pairs' scripts/lifecycle/grilling-shell.sh`.
- `tools/verify/m033-p02-grilling-shell-shape.sh` exists and exits 0 (T03 verifier — T04 must not break it).
- `tests/m033-acceptance/` exists.
- Spec context: FR-18 codifies the inline glossary writer at `<PROJECT_DIR>/wiki/glossary.md` (alphabetized-insert; immediate-not-batched). MIT-007 codifies the live contradiction-detection wiring active whenever `[<context-file>]` is non-empty. SC-11 is the acceptance test exercising both surfaces.

## Description

T04 layers the load-bearing logic onto T03's core grilling-shell module:

1. **MIT-007 contradiction-detection wiring** — replaces T03's `_grilling_check_contradiction` no-op stub with the real implementation. When `ask_one` is invoked with a non-empty `[<context-file>]` argument pointing at a YAML accumulator (e.g., `partial-answers.yml`), the function scans the file for contradictions against the new resolved answer BEFORE returning success. A contradiction is defined by the closed `# >>> contradiction-pairs >>>` table populated in T04. On contradiction detection, the function emits `contradiction:` to stdout naming the conflicting prior answer + the new answer, then re-prompts the operator to reconcile (re-prompt for a new answer, or accept-with-attestation via `! <reason>` shorthand).

2. **FR-18 glossary inline-update writer** — replaces T03's `_grilling_glossary_update` no-op stub with the real implementation. When a question whose key matches the closed `# >>> glossary-triggers >>>` set resolves, the function writes `<term>: <one-line definition>` (with at most a two-line elaboration on continuation lines) to `<PROJECT_DIR>/wiki/glossary.md` immediately. The write is alphabetized-insert (preserves existing entries; never full-file rewrite) and idempotent on identical input (re-writing the same term with the same definition produces no diff).

3. **SC-11 acceptance script** — `tests/m033-acceptance/p07-grilling-shell.sh` exercises the full surface end-to-end against synthetic `mktemp -d` staging.

**Bash 3.2 compatibility (MEM001):** No `declare -A`, no process substitution. Glossary alphabetized-insert uses `awk` (single-pass, no associative arrays). YAML parsing for contradiction detection uses `grep`/`sed` (no jq dependency).

**Closed enums for contradiction-pairs and glossary-triggers.** Both tables are documented inline in the module under fenced SSOT blocks (T04 populates the blocks T03 left empty). The vocabularies are intentionally minimal at v1 (per Constitution-XIV no speculative complexity):

- **`contradiction-pairs`** (v1): a small set of mutually-exclusive value pairs keyed by question-key. Examples documented inline:
  - `target-user`: `consumer` ⟂ `enterprise` ⟂ `internal-tools-only`
  - `deployment-target`: `serverless` ⟂ `self-hosted-vm` ⟂ `kubernetes`
  - `auth-model`: `passwordless` ⟂ `password-required` ⟂ `sso-only`

  v1 ships ~3–5 pairs; future demand-driven expansion adds more. The verifier asserts at least 3 pairs are documented and the parsing logic uses the documented format.

- **`glossary-triggers`** (v1): a small set of question-keys that, when answered, trigger a glossary-entry write. Examples:
  - `domain-term-defined` (any answer)
  - `acronym-resolved` (any answer)
  - `convention-named` (any answer)
  - `framework-chosen` (any answer matching a known framework token)

  v1 ships ~4 triggers; the verifier asserts at least 3 are documented.

## Steps

1. **Populate `# >>> contradiction-pairs >>>` SSOT block** in `scripts/lifecycle/grilling-shell.sh`. Format: bash array of `<question-key>:<value-a>:<value-b>` triples, parseable by `awk -F:`. Example:

   ```bash
   # >>> contradiction-pairs >>>
   # Format: question-key:value-a:value-b — answers a and b are mutually
   # exclusive when both appear under the same question-key in the
   # accumulator. v1 ships the minimal set; expand demand-driven.
   _GRILLING_CONTRADICTION_PAIRS="target-user:consumer:enterprise
   target-user:consumer:internal-tools-only
   target-user:enterprise:internal-tools-only
   deployment-target:serverless:self-hosted-vm
   deployment-target:serverless:kubernetes
   deployment-target:self-hosted-vm:kubernetes
   auth-model:passwordless:password-required
   auth-model:passwordless:sso-only
   auth-model:password-required:sso-only"
   # <<< contradiction-pairs <<<
   ```

   The variable is global (module-level); the parsing function reads it line-by-line via `IFS=$'\n'`.

2. **Populate `# >>> glossary-triggers >>>` SSOT block** in `scripts/lifecycle/grilling-shell.sh`. Format: bash array of question-keys, one per line:

   ```bash
   # >>> glossary-triggers >>>
   # Question-keys that, when answered via ask_one, trigger an
   # immediate write to <PROJECT_DIR>/wiki/glossary.md per FR-18.
   # v1 ships the minimal set; expand demand-driven.
   _GRILLING_GLOSSARY_TRIGGERS="domain-term-defined
   acronym-resolved
   convention-named
   framework-chosen"
   # <<< glossary-triggers <<<
   ```

3. **Replace `_grilling_check_contradiction` stub body** with real implementation:

   ```bash
   _grilling_check_contradiction() {
     local resolved="$1"
     local context_file="$2"

     # No context file → no contradiction check (still a valid call shape)
     if [ -z "$context_file" ] || [ ! -f "$context_file" ]; then
       return 0
     fi

     # Determine the question-key for this resolved answer. Calling
     # commands set _GRILLING_CURRENT_QKEY before invoking ask_one
     # (e.g., _GRILLING_CURRENT_QKEY=target-user; ask_one ...).
     local qkey="${_GRILLING_CURRENT_QKEY:-}"
     if [ -z "$qkey" ]; then
       # No question-key context → cannot check contradictions
       return 0
     fi

     # Scan the accumulator file for prior answers under this qkey
     local prior_answer=""
     prior_answer="$(grep "^${qkey}:" "$context_file" 2>/dev/null | tail -1 | sed -E 's/^[^:]+:[[:space:]]*//')"
     if [ -z "$prior_answer" ]; then
       return 0
     fi

     # Check if (qkey, prior_answer, resolved) matches a contradiction pair
     local found_contradiction=0
     local IFSO="$IFS"
     IFS=$'\n'
     local pair
     for pair in $_GRILLING_CONTRADICTION_PAIRS; do
       local pkey pa pb
       pkey="$(echo "$pair" | cut -d: -f1)"
       pa="$(echo "$pair" | cut -d: -f2)"
       pb="$(echo "$pair" | cut -d: -f3)"
       if [ "$pkey" = "$qkey" ]; then
         if { [ "$pa" = "$prior_answer" ] && [ "$pb" = "$resolved" ]; } || \
            { [ "$pb" = "$prior_answer" ] && [ "$pa" = "$resolved" ]; }; then
           found_contradiction=1
           break
         fi
       fi
     done
     IFS="$IFSO"

     if [ "$found_contradiction" -eq 1 ]; then
       printf 'contradiction: %s prior=%s new=%s\n' "$qkey" "$prior_answer" "$resolved"
       printf 'reconcile [r=re-prompt, !<reason>=accept-with-attestation]: ' >&2
       local reconcile=""
       IFS= read -r reconcile || reconcile="r"
       case "$reconcile" in
         r|R|"") return 2 ;;  # Caller re-prompts
         "!"*) printf 'attestation: %s\n' "${reconcile#!}"; return 0 ;;
         *) printf 'unrecognized reconciliation: %s — re-prompt\n' "$reconcile" >&2; return 2 ;;
       esac
     fi
     return 0
   }
   ```

4. **Replace `_grilling_glossary_update` stub body** with real implementation:

   ```bash
   _grilling_glossary_update() {
     local question="$1"
     local resolved="$2"

     # Question-key extraction: calling commands set _GRILLING_CURRENT_QKEY
     local qkey="${_GRILLING_CURRENT_QKEY:-}"
     if [ -z "$qkey" ]; then
       return 0
     fi

     # Check if this qkey is a glossary trigger
     local triggered=0
     local IFSO="$IFS"
     IFS=$'\n'
     local trigger
     for trigger in $_GRILLING_GLOSSARY_TRIGGERS; do
       if [ "$trigger" = "$qkey" ]; then
         triggered=1
         break
       fi
     done
     IFS="$IFSO"

     if [ "$triggered" -eq 0 ]; then
       return 0
     fi

     # Determine the project dir (caller sets PROJECT_DIR; fall back to PWD)
     local project_dir="${PROJECT_DIR:-$PWD}"
     local glossary_dir="$project_dir/wiki"
     local glossary_path="$glossary_dir/glossary.md"
     mkdir -p "$glossary_dir"

     # Term: derived from the qkey (e.g., 'framework-chosen' → resolved is
     # the framework name; the term is the resolved value itself).
     # Definition: the calling command sets _GRILLING_CURRENT_DEFINITION
     # if it has a definition to attach; otherwise we use the question text
     # as the definition.
     local term="$resolved"
     local definition="${_GRILLING_CURRENT_DEFINITION:-$question}"

     # Idempotent check: if the entry already exists with this exact
     # term + definition, no-op.
     if [ -f "$glossary_path" ]; then
       if grep -qF "${term}: ${definition}" "$glossary_path"; then
         return 0
       fi
     fi

     # Alphabetized-insert via awk single-pass
     local tmp
     tmp="$(mktemp)"
     awk -v term="$term" -v def="$definition" '
       BEGIN { inserted=0 }
       /^[^:]+: / && !inserted {
         # Extract the existing term (everything up to first ":")
         existing_term = $0
         sub(/:.*$/, "", existing_term)
         if (term < existing_term) {
           printf "%s: %s\n", term, def
           inserted=1
         }
       }
       { print }
       END {
         if (!inserted) {
           printf "%s: %s\n", term, def
         }
       }
     ' "$glossary_path" 2>/dev/null > "$tmp" || {
       # File might not exist yet; create with single entry
       printf '%s: %s\n' "$term" "$definition" > "$tmp"
     }
     mv "$tmp" "$glossary_path"
     return 0
   }
   ```

5. **Update the `ask_one` body in T03's module** to:
   - Set `_GRILLING_CURRENT_QKEY` from a documented optional 4th argument (or from the existing-caller-set var). Recommendation: keep the public API at 3 args (`question`, `recommendation`, `[<context-file>]`); calling commands set `_GRILLING_CURRENT_QKEY` directly before invoking `ask_one`. This keeps the FR-17 API signature stable.
   - On `_grilling_check_contradiction` returning non-zero (contradiction with re-prompt requested), re-prompt the operator for an alternative answer and re-run the check (single retry; second contradiction exits non-zero with a `contradiction-unresolved:` diagnostic).
   - Append the resolved answer to the `<context-file>` (if non-empty) AFTER passing contradiction detection, so subsequent `ask_one` invocations under the same accumulator see this answer. Format: `<qkey>: <resolved>` per line.

6. **Author `tests/m033-acceptance/p07-grilling-shell.sh`** (≥100 lines, executable, exits 0 → SC-11).

   6a. **Setup.** `mktemp -d` for staging; trap EXIT for cleanup.

   6b. **Test 1 — recommendation-not-interrogation ordering.** Source the module, set `PROJECT_DIR=<staging>`, invoke `_GRILLING_CURRENT_QKEY=stack ask_one 'What stack?' 'web-saas' ''` against simulated stdin (`printf 'y\n'`). Capture stdout. Assert: `recommendation: web-saas` line appears AND `answer: web-saas` line appears AND `recommendation:` precedes `answer:` (line-number comparison).

   6c. **Test 2 — explicit answer (n/N path).** Invoke same `ask_one 'What stack?' 'web-saas' ''` with stdin `printf 'n\nfastify\n'`. Assert `answer: fastify` appears.

   6d. **Test 3 — contradiction detection fires (MIT-007).** Pre-populate `<staging>/partial-answers.yml` with `target-user: consumer`. Set `_GRILLING_CURRENT_QKEY=target-user`. Invoke `ask_one 'Refine target user?' 'enterprise' '<staging>/partial-answers.yml'` with stdin `printf 'y\nr\n'` (accept the recommendation, then choose re-prompt on contradiction). Then a second `read` for the alternative... actually the contradiction handler re-prompts via stderr; simpler test: stdin `printf 'y\n!still-the-right-call\n'` (accept recommendation, then attestation reconciliation). Assert: `contradiction: target-user prior=consumer new=enterprise` appears on stdout BEFORE `answer: enterprise` appears, AND `attestation: still-the-right-call` appears.

   6e. **Test 4 — glossary trigger writes alphabetized.** Pre-populate `<staging>/wiki/glossary.md` with two entries:

   ```
   alpha: first entry
   gamma: third entry
   ```

   Set `_GRILLING_CURRENT_QKEY=framework-chosen` (a documented trigger). Invoke `ask_one 'Which framework?' 'beta' ''` with stdin `printf 'y\n'`. Assert `<staging>/wiki/glossary.md` now contains:

   ```
   alpha: first entry
   beta: ...
   gamma: third entry
   ```

   (with `beta:` inserted alphabetically between `alpha:` and `gamma:`).

   6f. **Test 5 — glossary idempotent on identical input.** Re-run the same trigger with the same answer; assert the glossary file is unchanged (byte-identical via `cmp` against the saved version after Test 4).

   6g. **Test 6 — non-trigger qkey produces no glossary entry.** Set `_GRILLING_CURRENT_QKEY=stack` (NOT a trigger). Invoke `ask_one 'What stack?' 'web-saas' ''` with `printf 'y\n'`. Assert `<staging>/wiki/glossary.md` is unchanged from Test 5 baseline.

   6h. **Cleanup mandatory.** `rm -rf "$staging"` in EXIT trap.

7. **Author `tools/verify/m033-p02-grilling-shell-contradiction-detection.sh`** (≥30 lines, executable). Asserts:
   - `scripts/lifecycle/grilling-shell.sh` exists.
   - The `# >>> contradiction-pairs >>>` block is populated (at least 3 lines between the markers, each matching `<key>:<a>:<b>` shape).
   - Required tokens appear: `MIT-007`, `contradiction:`, `_grilling_check_contradiction`, `context_file`, `_GRILLING_CURRENT_QKEY`.
   - The MIT-007 wiring path is non-trivial: `_grilling_check_contradiction` is no longer a no-op (assert the function body has more than 5 lines via `awk`/grep on the function definition).
   - **Functional smoke test:** sandboxed source + invoke with a contradicting accumulator; assert `contradiction:` appears on stdout.
   - Emits PASS/SUMMARY lines.

8. **Author `tools/verify/m033-p02-glossary-writer-shape.sh`** (≥30 lines, executable). Asserts:
   - The `# >>> glossary-triggers >>>` block is populated (at least 3 trigger keys).
   - Required tokens appear: `FR-18`, `glossary.md`, `wiki/`, `_grilling_glossary_update`, `alphabetized-insert` or `awk` (insert mechanism).
   - The `_grilling_glossary_update` body is non-trivial (>10 lines).
   - **Functional smoke test:** create staging; source the module; invoke `ask_one` with a glossary trigger; assert `<staging>/wiki/glossary.md` contains the entry. Re-invoke with the same trigger; assert idempotency (file byte-identical).
   - Emits PASS/SUMMARY lines.

9. **Author `tools/verify/m033-p02-acceptance-shape-sc11.sh`** (≥25 lines, executable). Asserts:
   - `tests/m033-acceptance/p07-grilling-shell.sh` exists and is executable.
   - The literal SC-11 + FR-17 + FR-18 tokens appear.
   - The cross-references to `grilling-shell.sh`, `recommendation:`, `answer:`, `contradiction:`, `glossary.md` appear.
   - Emits PASS/SUMMARY lines.

## Must-Haves

This task addresses these P02 phase truths:
- The MIT-007 contradiction-detection wiring is live in `scripts/lifecycle/grilling-shell.sh` whenever `[<context-file>]` is non-empty.
- The FR-18 glossary inline-update writer fires immediately (not batched) when a documented trigger qkey resolves.
- `tests/m033-acceptance/p07-grilling-shell.sh` (SC-11) exits 0 and exercises both surfaces end-to-end.

This task creates these P02 phase artifacts:
- Module extension (replaces T03 stubs in-place): `scripts/lifecycle/grilling-shell.sh` (T04 populates contradiction-pairs + glossary-triggers blocks; replaces `_grilling_check_contradiction` and `_grilling_glossary_update` stub bodies with real logic).
- Acceptance script: `tests/m033-acceptance/p07-grilling-shell.sh` (SC-11).
- Verifiers: `tools/verify/m033-p02-grilling-shell-contradiction-detection.sh`, `tools/verify/m033-p02-glossary-writer-shape.sh`, `tools/verify/m033-p02-acceptance-shape-sc11.sh`.

## Verification

```bash
bash tools/verify/m033-p02-grilling-shell-shape.sh
```

```bash
bash tools/verify/m033-p02-grilling-shell-contradiction-detection.sh
```

```bash
bash tools/verify/m033-p02-glossary-writer-shape.sh
```

```bash
bash tools/verify/m033-p02-acceptance-shape-sc11.sh
```

```bash
bash tests/m033-acceptance/p07-grilling-shell.sh
```

## Inputs

### From Previous Tasks

- T03 deliverable: `scripts/lifecycle/grilling-shell.sh` with the core `ask_one` function, the recommendation-not-interrogation framing, and the empty fenced SSOT blocks (`# >>> contradiction-pairs >>>` and `# >>> glossary-triggers >>>`) plus stub helpers `_grilling_check_contradiction` and `_grilling_glossary_update`. T04 populates the SSOT blocks and replaces the stub bodies in-place. T03's verifier (`m033-p02-grilling-shell-shape.sh`) must continue to exit 0 after T04 (P03/P04/P05 will source the same module — T03's API contract MUST remain stable).

### From Disk (Pre-existing)

- `awk` (POSIX-standard, present on macOS + Linux). Used by the alphabetized-insert in `_grilling_glossary_update`.

## Constraints

- Bash 3.2 compatibility (MEM001) — no `declare -A`, no process substitution, no `$(...)` containing pipes.
- T04 MUST preserve T03's `m033-p02-grilling-shell-shape.sh` verifier passing — T04's edits to `grilling-shell.sh` are additive (populating empty SSOT blocks) and replacement-in-place (stub body → real body); the public API surface (`ask_one` signature) is unchanged.
- The closed contradiction-pairs and glossary-triggers vocabularies are minimal at v1 (3–5 pairs, 3–4 triggers). Expansion is demand-driven via P03/P04/P05 acceptance feedback or post-launch friendly-tester signal.
- The `contradiction:` and `attestation:` line prefixes are load-bearing for SC-11 assertions. Use `printf` (not `echo -e`).
- The glossary write MUST be alphabetized-insert (preserve existing entries) and idempotent on identical input. Full-file rewrite is forbidden (operator edits between writes must survive).
- The accumulator file (`partial-answers.yml`) format is `<qkey>: <resolved>` per line. T04 appends to it; T03's `ask_one` is also extended to append. Calling commands MUST set `_GRILLING_CURRENT_QKEY` before invoking `ask_one`; documented in the SSOT comment block.
- T04 MUST NOT touch `scripts/util/jsonl-event-emitter.sh` (T01 deliverable) or `scripts/util/start-state-markers.sh` (T02 deliverable), or any P03/P04/P05 surface.
- Verifier scripts use single-script-file shape per AD-19.

## Expected Output

After T04 completes:
- `scripts/lifecycle/grilling-shell.sh` carries populated SSOT blocks + real `_grilling_check_contradiction` + real `_grilling_glossary_update`.
- `tests/m033-acceptance/p07-grilling-shell.sh` exists, is executable, exits 0.
- All three new T04 verifiers (`grilling-shell-contradiction-detection`, `glossary-writer-shape`, `acceptance-shape-sc11`) exist, are executable, exit 0.
- T03's `m033-p02-grilling-shell-shape.sh` continues to exit 0 (regression-preserved).
- A summary file at [`.orchestrator/milestones/M033/phases/P02/tasks/T04-grilling-shell-glossary-and-contradiction-SUMMARY.md`](../../../../../milestones/M033/phases/P02/tasks/T04-grilling-shell-glossary-and-contradiction-SUMMARY.md) documents the deliverables.

## Notes

The `_GRILLING_CURRENT_QKEY` and `_GRILLING_CURRENT_DEFINITION` are caller-set bash variables (not `ask_one` arguments), keeping the FR-17 public API at 3 args. P03/P04/P05 calling commands document the convention by setting them before each invocation. This is the established [M021](../../../../../milestones/M021/index.md) pattern for cross-cutting context (env-var-style variables that don't pollute the function signature).

The contradiction-detection fall-through on `_GRILLING_CURRENT_QKEY` empty is intentional: it lets ad-hoc `ask_one` invocations (operator scripts, smoke tests) skip contradiction detection without false positives. The detection only fires when the calling command opts in by setting the qkey.

The glossary write uses `awk` for the alphabetized-insert because bash 3.2 has no clean way to insert into a file at a sorted position without process substitution. `awk` is POSIX-standard; the single-pass insert preserves comments / non-entry lines transparently.

The reconciliation UX (`r` for re-prompt, `!<reason>` for accept-with-attestation) is a minimal v1 surface. If friendly-tester signal surfaces "operators get stuck on contradiction prompts", post-launch can expand to a richer dialog. The two-mode UX is adequate for the launch first-impression promise.
