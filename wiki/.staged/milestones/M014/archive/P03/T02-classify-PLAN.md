---
schema_version: "1.0"
task: "T02"
phase: "P03"
milestone: "M014"
name: "Regex/heuristic v1 classifier + dogfood-data capture (FR-9, D023)"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped — `scripts/comments/fetch.sh` exists and writes `<inbox-dir>/<comment-id>.json` records with `{url, body, source_surface, fetched_at, body_shasum}` fields. T02 reads the same record shape.
- D023 (2026-04-24) pins the FR-9 classifier shape to **regex/heuristic v1 baseline** with explicit retune-trigger language (≥30 actioned comments OR ≥20% calibration divergence). T02 implements this pin and documents it in the dogfood-data capture file.
- `scripts/dispatch/adapters/tool/conversus.sh` (M011/P07) is shipped and supports the `gate <preset> <input> <output>` interface with `--strict`. T02 invokes the adapter for the ambiguous-routing path; T02 does NOT modify the adapter (D007 reuse).

## Description

T02 ships:

1. `scripts/comments/classify.sh <inbox-file>` — pure per-comment classifier. Reads one cached inbox comment JSON, applies regex/heuristic rules to assign one of four FR-9 classes, computes a confidence score (0.0–1.0), and emits a single-line stdout verdict in the shape:
   ```
   class=<class> confidence=<score> reason=<short-id>
   ```
   plus a one-line stderr diagnostic on the rules that fired (informational).

2. The four-class regex/heuristic v1 ruleset (D023 pin). All rules operate on the comment body text:

   - **`uat-bug`**: body matches any of these patterns (case-insensitive):
     - `\bacceptance\s+(criterion|scenario|criteria)\b.*\bfail`
     - `\b(bug|broken|failing|crashes?|errors?\s+out)\b.*\bon\b`
     - YAML frontmatter shape installed by [M013](../../../../milestones/M013/index.md)'s UAT Bug template (line containing `kind:\s*uat-bug` near the top of the body)
     Confidence: 0.9 if YAML shape present (high signal), 0.7 if regex match.

   - **`decision-append`**: body matches any of these patterns (case-insensitive):
     - `^\s*decision:\s+`
     - `\bwe\s+(decided|agreed|chose)\b`
     - `^\s*/append-decision\b` (explicit trigger)
     Confidence: 0.95 if explicit trigger, 0.75 if narrative match.

   - **`spec-amendment`**: body matches any of these patterns (case-insensitive):
     - `\bFR-\d+\s+(should|needs?\s+to|must)\b`
     - `\b(AS|US|SC|CON)-\d+\s+(is\s+wrong|contradicts?|missing)\b`
     - `^\s*(amend|propose\s+amendment)\b`
     Confidence: 0.85 (always queued — never auto-applies regardless).

   - **`ambiguous`**: no rule fires above 0.6 confidence; route through conversus adapter for triage. Emit `class=ambiguous confidence=0.0 reason=no-rule-fired`.

3. The ambiguous-routing path: when classify.sh emits `class=ambiguous`, the master pipeline (T04) invokes `scripts/dispatch/adapters/tool/conversus.sh gate classify-comment <inbox-file> <verdict-output>` with `--strict`. T02 ships a minimal `templates/conversus-presets/classify-comment.yml` preset (cooperative mode, single agent, returns one of the four classes) that the adapter can dispatch without modification. T02 does not write the orchestration code that calls the adapter — that's T04's pipeline.

4. `specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md` — the SC-16 dogfood-data file, captured at the **best-available signal time** per D023. The wiki was deployed 2026-04-23 (one day before this plan), so the file documents the snapshot state, the regex/heuristic v1 baseline pin, and the explicit retune trigger conditions.

5. `scripts/verify/m014-p03-classify.sh` — exercises classify.sh against `tests/fixtures/m014-p03/sample-inbox.jsonl` (split into one file per comment) and asserts exact verdicts per class.

## Steps

1. **Create `scripts/comments/classify.sh`** with the structure:

   ```bash
   #!/usr/bin/env bash
   # scripts/comments/classify.sh
   # FR-9 v1 classifier — regex/heuristic per D023 (2026-04-24).
   # Reads one inbox JSON file; emits class+confidence+reason on stdout.
   # Bash 3.2 compatible. AD-19-clean.
   set -u

   _inbox_file="${1:-}"
   if [ -z "$_inbox_file" ] || [ ! -f "$_inbox_file" ]; then
     printf 'FAIL: classify.sh: inbox file required as $1 (got: %s)\n' "$_inbox_file" >&2
     exit 2
   fi

   # Extract body field via awk (jq optional). Body is JSON-encoded; basic
   # awk extraction handles single-line bodies; multi-line bodies use the
   # \n-escaped form which awk reads as literal.
   _body="$(awk '
     /"body":/ {
       sub(/.*"body":[[:space:]]*"/, "")
       sub(/",[[:space:]]*"[^"]*":.*/, "")
       sub(/"[[:space:]]*}.*/, "")
       print
       exit
     }
   ' "$_inbox_file")"

   # Lowercase for case-insensitive regex (Bash 3.2 — use tr, not ${var,,}).
   _body_lower="$(printf '%s' "$_body" | tr '[:upper:]' '[:lower:]')"

   _class=""
   _conf="0.0"
   _reason="no-rule-fired"

   # Rule R1: uat-bug — YAML frontmatter shape (highest signal).
   if printf '%s' "$_body" | grep -qE '^[[:space:]]*kind:[[:space:]]*uat-bug'; then
     _class="uat-bug"; _conf="0.9"; _reason="yaml-frontmatter"
   # Rule R2: uat-bug — acceptance-criterion-fails pattern.
   elif printf '%s' "$_body_lower" | grep -qE '\bacceptance[[:space:]]+(criterion|scenario|criteria)\b.*\bfail'; then
     _class="uat-bug"; _conf="0.7"; _reason="acceptance-fails"
   # Rule R3: uat-bug — bug-on-platform pattern.
   elif printf '%s' "$_body_lower" | grep -qE '\b(bug|broken|failing|crashes?|errors?[[:space:]]+out)\b.*\bon\b'; then
     _class="uat-bug"; _conf="0.7"; _reason="bug-on-platform"
   # Rule R4: decision-append — explicit trigger.
   elif printf '%s' "$_body_lower" | grep -qE '^[[:space:]]*/append-decision\b'; then
     _class="decision-append"; _conf="0.95"; _reason="explicit-trigger"
   # Rule R5: decision-append — "decision:" prefix.
   elif printf '%s' "$_body_lower" | grep -qE '^[[:space:]]*decision:[[:space:]]+'; then
     _class="decision-append"; _conf="0.85"; _reason="decision-prefix"
   # Rule R6: decision-append — narrative match.
   elif printf '%s' "$_body_lower" | grep -qE '\bwe[[:space:]]+(decided|agreed|chose)\b'; then
     _class="decision-append"; _conf="0.75"; _reason="narrative-decision"
   # Rule R7: spec-amendment — FR/AS/US/SC reference + correction language.
   elif printf '%s' "$_body_lower" | grep -qE '\bfr-[0-9]+[[:space:]]+(should|needs?[[:space:]]+to|must|also[[:space:]]+cover)\b'; then
     _class="spec-amendment"; _conf="0.85"; _reason="fr-amend"
   elif printf '%s' "$_body_lower" | grep -qE '\b(as|us|sc|con)-[0-9]+[[:space:]]+(is[[:space:]]+wrong|contradicts?|missing)\b'; then
     _class="spec-amendment"; _conf="0.85"; _reason="cross-ref-correction"
   elif printf '%s' "$_body_lower" | grep -qE '^[[:space:]]*(amend|propose[[:space:]]+amendment)\b'; then
     _class="spec-amendment"; _conf="0.95"; _reason="explicit-amend"
   else
     _class="ambiguous"; _conf="0.0"; _reason="no-rule-fired"
   fi

   printf 'class=%s confidence=%s reason=%s\n' "$_class" "$_conf" "$_reason"
   printf 'INFO: classified %s as %s (rule=%s)\n' "$(basename "$_inbox_file")" "$_class" "$_reason" >&2
   exit 0
   ```

2. **Create `templates/conversus-presets/classify-comment.yml`** — minimal preset for ambiguous-routing path:

   ```yaml
   ---
   schema_version: "1.0"
   type: conversus-preset
   name: classify-comment
   mode: cooperative
   verdict_contract: "class:uat-bug|decision-append|spec-amendment|ambiguous"
   ---
   # Conversus preset — classify-comment (M014/P03)
   # Used by orchestrator:comments classify when the regex/heuristic v1 baseline
   # routes a comment to ambiguous (no rule fired above 0.6 confidence). The
   # adapter dispatches a single-agent cooperative deliberation that re-classifies
   # the comment into one of the four FR-9 classes; on adapter unavailability
   # under --strict, classify routes the comment to human triage (per M013/FR-13).

   agents:
     - name: comment-classifier
       prompt: |
         You are classifying a single user comment from a wiki Giscus thread or
         a GitHub Issue/PR comment into exactly one of these four classes:
           - uat-bug: comment reports a defect against an acceptance criterion
           - decision-append: comment proposes or records a project decision
           - spec-amendment: comment proposes an edit to a spec FR/AS/US/SC
           - ambiguous: comment does not match any of the above
         Respond with exactly one line: class=<class> confidence=<0.0-1.0> reason=<short>
   ```

3. **Make `scripts/comments/classify.sh` executable**:

   ```bash
   chmod +x scripts/comments/classify.sh
   ```

4. **Author `specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md`** with this content:

   ```markdown
   # Inbox Dogfood Data Capture (M014/P03 SC-16, RELAXED per D023)

   ## Status: best-available signal at plan time (2026-04-24)

   The original SC-16 contract called for ≥1 week of M012/M013 inbox volume
   captured before plan-phase pins the FR-9 classifier shape. **D023
   (2026-04-24) relaxed this preflight** — wiki was deployed 2026-04-23
   (one day before plan-phase); waiting six more calendar days delays M014
   close past usable cadence.

   This file documents the snapshot state, the regex/heuristic v1 baseline
   pin chosen by D023, and the explicit retune-trigger conditions.

   ## Snapshot

   | Surface | Threads observed | Comments observed | Notes |
   |---|---|---|---|
   | Wiki Giscus | 0 | 0 | Wiki deployed 2026-04-23; no organic stakeholder comments yet. |
   | GitHub Issues | (observe at plan time) | (observe at plan time) | Existing M013/M014 dogfood Issues; mostly orchestrator-id-marker self-comments. |
   | GitHub PRs | 0 | 0 | None of the [M026](../../../../milestones/M026/index.md) PRs received external review comments. |

   ## Per-class counts (seeded fixture)

   The `tests/fixtures/m014-p03/sample-inbox.jsonl` fixture seeds 4 synthetic
   comments — 1 per class — exercising the regex/heuristic v1 ruleset. Real-
   inbox calibration accumulates as comments are actioned.

   | Class | Seeded fixture count | Real-inbox count (snapshot) |
   |---|---|---|
   | uat-bug | 1 | 0 |
   | decision-append | 1 | 0 |
   | spec-amendment | 1 | 0 |
   | ambiguous | 1 | 0 |

   ## FR-9 shape pinned: regex/heuristic v1 (D023)

   Rule set captured in `scripts/comments/classify.sh:R1-R10`. Confidence
   assignments are coarse-grained (0.7-0.95 in 0.05-0.10 increments), pinned
   on intuition + the four-class precedent from prior milestones, NOT on
   measured precision/recall.

   ## Retune trigger (D023)

   When EITHER condition holds, open a follow-up D-row that re-pins FR-9 shape:

   1. **Volume trigger**: `.orchestrator/comments/actioned.jsonl` shows ≥30
      fetched comments across the four classes.
   2. **Calibration trigger**: classifier confidence calibration on observed
      comments diverges from regex/heuristic predictions in ≥20% of samples
      (sample = comment whose conversus-triage verdict OR human-triage outcome
      disagrees with the regex/heuristic verdict).

   Either trigger justifies escalating FR-9 to one of the alternative shapes
   from spec OQ #C-1 (embedding-distance, LLM-call-per-comment, two-pass
   hybrid). The escalation lands inside M014 extended scope OR as a dedicated
   M011/M014 follow-up (operator decides at trigger time).

   ## Cross-references

   - [`.orchestrator/DECISIONS.md`](../../../../decisions.md) D023 — original relaxation rationale.
   - `commands/comments.md` — user-facing surface citing this file.
   - `references/spec-management.md` — Comment Classification & Workflow Routing
     section (added by M014/P03/T05).
   ```

5. **Create `scripts/verify/m014-p03-classify.sh`** — exercises classify against per-class fixture comments:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m014-p03-classify.sh
   # Verifies M014/P03/T02: regex/heuristic v1 classifier produces correct
   # class verdicts for the four-class fixture corpus.
   set -u

   REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
   CLASSIFY="${REPO_ROOT}/scripts/comments/classify.sh"

   pass=0; fail=0
   _pass() { pass=$((pass+1)); echo "PASS: $1"; }
   _fail() { fail=$((fail+1)); echo "FAIL: $1"; }

   SCRATCH="$(mktemp -d)"
   trap 'rm -rf "$SCRATCH"' EXIT

   # Build per-class inbox fixtures.
   cat > "$SCRATCH/uat.json" <<'JSON'
   {"url":"https://example/issues/1#issuecomment-1","body":"acceptance criterion 2 fails on macOS 13","source_surface":"github","id":"c1"}
   JSON
   cat > "$SCRATCH/dec.json" <<'JSON'
   {"url":"https://example/issues/2#issuecomment-2","body":"decision: pin Bash 3.2 across all scripts","source_surface":"github","id":"c2"}
   JSON
   cat > "$SCRATCH/amend.json" <<'JSON'
   {"url":"https://example/discussions/3#discussioncomment-3","body":"FR-5 should also cover token-density measurement","source_surface":"giscus","id":"c3"}
   JSON
   cat > "$SCRATCH/amb.json" <<'JSON'
   {"url":"https://example/discussions/4#discussioncomment-4","body":"hmm not sure about this approach","source_surface":"giscus","id":"c4"}
   JSON

   # Case A: uat-bug.
   out_a="$(bash "$CLASSIFY" "$SCRATCH/uat.json" 2>/dev/null)"
   if printf '%s' "$out_a" | grep -q '^class=uat-bug'; then _pass "Case A: uat-bug verdict"; else _fail "Case A: got: $out_a"; fi

   # Case B: decision-append.
   out_b="$(bash "$CLASSIFY" "$SCRATCH/dec.json" 2>/dev/null)"
   if printf '%s' "$out_b" | grep -q '^class=decision-append'; then _pass "Case B: decision-append verdict"; else _fail "Case B: got: $out_b"; fi

   # Case C: spec-amendment.
   out_c="$(bash "$CLASSIFY" "$SCRATCH/amend.json" 2>/dev/null)"
   if printf '%s' "$out_c" | grep -q '^class=spec-amendment'; then _pass "Case C: spec-amendment verdict"; else _fail "Case C: got: $out_c"; fi

   # Case D: ambiguous.
   out_d="$(bash "$CLASSIFY" "$SCRATCH/amb.json" 2>/dev/null)"
   if printf '%s' "$out_d" | grep -q '^class=ambiguous'; then _pass "Case D: ambiguous verdict"; else _fail "Case D: got: $out_d"; fi

   # Case E: confidence field present + parseable as 0.0-1.0.
   if printf '%s' "$out_a" | grep -qE 'confidence=0\.[0-9]'; then _pass "Case E: confidence field shape"; else _fail "Case E: confidence missing/malformed"; fi

   # Case F: classify.sh references "regex/heuristic" (D023 pin docstring).
   if grep -q "regex/heuristic" "$CLASSIFY"; then _pass "Case F: D023 pin docstring present"; else _fail "Case F: classify.sh missing D023 pin docstring"; fi

   # Case G: classify-comment preset exists.
   if [ -f "${REPO_ROOT}/templates/conversus-presets/classify-comment.yml" ]; then _pass "Case G: classify-comment preset shipped"; else _fail "Case G: preset missing"; fi

   # Case H: dogfood-data file exists + cites D023.
   DOGFOOD="${REPO_ROOT}/specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md"
   if [ -f "$DOGFOOD" ] && grep -q "D023" "$DOGFOOD"; then _pass "Case H: dogfood capture cites D023"; else _fail "Case H: dogfood file missing/no-D023"; fi

   echo "----"
   echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
   if [ "$fail" -gt 0 ]; then exit 1; fi
   echo "PASS: $(basename "$0")"
   exit 0
   ```

6. **Run the verifier**:

   ```bash
   bash scripts/verify/m014-p03-classify.sh
   ```

   Expected: `SUMMARY: m014-p03-classify.sh pass=8 fail=0`.

## Must-Haves

Addresses phase must-haves:
- "Truth: classify.sh reads inbox JSON + emits class+confidence+reason for one of four FR-9 classes (regex/heuristic v1 per D023)"
- "Truth: dogfood-data capture lands as best-available signal per D023"
- Artifacts: `scripts/comments/classify.sh`, `templates/conversus-presets/classify-comment.yml`, `specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md`, `scripts/verify/m014-p03-classify.sh`

## Verification

```
bash scripts/verify/m014-p03-classify.sh
```

Must exit 0 with `PASS: m014-p03-classify.sh`.

## Inputs

### From Previous Tasks

- `scripts/comments/fetch.sh` (T01) — emits inbox JSON shape `{url, body, source_surface, fetched_at, body_shasum, id, ...}`. T02 reads `body` field.

### From Disk (Pre-existing)

- [`.orchestrator/DECISIONS.md`](../../../../decisions.md) D023 — pin rationale + retune trigger.
- `scripts/dispatch/adapters/tool/conversus.sh` — interface contract for ambiguous-routing (T04 invokes; T02 just ships the preset).

## Constraints

- **D023 pin**: classifier shape is regex/heuristic v1; no LLM round-trip on the primary classification path. Ambiguous routes through conversus per the spec's CON-4. Retune trigger documented in commands + references + dogfood file (single source of truth: dogfood-data file).
- **CON-6 / MEM001 Bash 3.2**: no `${var,,}` (use `tr`); no `mapfile`; no associative arrays.
- **AD-19**: Verifier uses single-script-file shape; no inline compounds beyond `&&`/`||` of two commands.
- **CON-5 / SC-5**: classifier itself never auto-applies; it's a pure verdict producer. The auto-apply gate lives in T04's master pipeline. Spec-amendment class always queues regardless of confidence.
- **D007 reuse**: T02 ships a NEW preset under `templates/conversus-presets/`; does NOT modify `scripts/dispatch/adapters/tool/conversus.sh`.
- **No new `RUNTIME-ASSUMPTIONS.md` entry**: D023 pinned regex/heuristic (non-LLM) so per the spec ("FR-9 (classifier) is included conditionally — only if planning pins an LLM-based classifier shape"), no entry is required. T05 verifier asserts the registry is unchanged byte-identically by P03.

## Expected Output

- `scripts/comments/classify.sh` created (~80-110 lines).
- `templates/conversus-presets/classify-comment.yml` created (~25-35 lines).
- `specs/024-spec-management-extended/planning-inputs/inbox-dogfood.md` created (~50-80 lines).
- `scripts/verify/m014-p03-classify.sh` created (~80-100 lines).
- `bash scripts/verify/m014-p03-classify.sh` exits 0, prints `SUMMARY: ... pass=8 fail=0`, `PASS: m014-p03-classify.sh`.
