---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M018"
name: "Tier 2 verifiers, fixtures, fixture-staging helper, P04-SUMMARY + CLAUDE.md/AGENTS.md dual-write"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped `_bc_apply_tier2` and the `compression.tier2.*` config keys + accessors + the additive `tier2_savings_tokens` field on `payload_breakdown`. T02 ships the verifier scripts, fixtures, fixture-staging helper, P04-SUMMARY, and the dual-write of the runtime instruction file's recent-changes block.
- `scripts/verify/_helpers/m018-p03-build-fixture.sh` is the canonical helper-shape T02 mirrors. Read it once for shape (config-override scaffolding, fixture path resolution, capture-file staging) before authoring `m018-p04-build-fixture.sh`.
- `scripts/util/dual-write-runtime-md.sh` is the canonical dual-write helper used by every prior phase that updated `CLAUDE.md` recent-changes (M011/P07, [M013](../../../../../milestones/M013/index.md), [M015](../../../../../milestones/M015/index.md), [M016](../../../../../milestones/M016/index.md), [M019](../../../../../milestones/M019/index.md), [M020](../../../../../milestones/M020/index.md), [M021](../../../../../milestones/M021/index.md), [M025](../../../../../milestones/M025/index.md), [M027](../../../../../milestones/M027/index.md), M018/P02, M018/P03). Invocation pattern: `bash scripts/util/dual-write-runtime-md.sh <orchestrator:recent-changes block content>` — writes the block to both `CLAUDE.md` and `AGENTS.md` between the `# >>> orchestrator:recent-changes >>>` and `# <<< orchestrator:recent-changes <<<` sentinels. The verifier `m018-p04-dual-write-recent.sh` only checks that both files contain "M018/P04" in their recent-changes block — the dual-write helper itself is unchanged.
- AD-19 single-script-file `Check:` contract: every verifier exposes its truth via a single bash invocation. The verifier may shell out to subordinate helpers (e.g., `_helpers/m018-p04-build-fixture.sh`) but the orchestrator's `check-must-haves.sh` invokes ONE bash file per truth.
- AP-009 applies to verifier scripts. No compound chains > 2; no plain subshells; no `$(...|...)`. Verifier scripts use `pass()`/`fail()` per MEM002 and the typical `printf 'PASS:' / printf 'FAIL:'` line-prefix convention.
- The `m018-p03-disable-flag-honored.sh` verifier exists and asserts byte-identity of the P02 golden against the post-P03 build-context.sh under `compression.enabled: false`. T02's `m018-p04-tier2-disable-flag.sh` is the same shape, post-P04.
- Bash 3.2 — verifiers use parallel indexed arrays (no `declare -A`).

## Description

T02 ships seven verifier scripts under `scripts/verify/m018-p04-*.sh`, two fixture directories under `tests/fixtures/m018-p04-*/`, one fixture-staging helper under `scripts/verify/_helpers/`, the P04-SUMMARY, and the CLAUDE.md/AGENTS.md `orchestrator:recent-changes` dual-write. The verifiers exercise T01's production code through fixtures plus shim invocations of `_bc_apply_tier2` (sourcing the function the same way `m018-p03-tier1-paging.sh` source-extracts `_bc_apply_tier1`).

The seven verifiers map 1:1 to the P04 truths:

1. `m018-p04-tier2-head-drop.sh` — section-overflow fixture asserts head-drop fires; the trailing 30% of the pre-snip section is byte-identical at the tail of the post-snip section; the heading line is preserved; the post-snip body-token count is at most `section_budget_tokens + tail_token_count` (boundary inequality, not equality, since boundary retreat may leave more than the budget in place).
2. `m018-p04-tier2-marker.sh` — same fixture asserts the marker `<!-- compressed:tier2 head_dropped=<N> protected_tail_ratio=0.30 -->` appears immediately after the heading line, on its own line, with integer N > 0 and the literal string `protected_tail_ratio=0.30`.
3. `m018-p04-tier2-boundary-refusal.sh` — boundary-refusal fixture asserts that when the over-budget section contains an open 4+-backtick code fence whose start lies above the protected tail and whose end lies inside the protected tail, the snip retreats; if no safe boundary exists, the section passes through unmodified plus a `tier_preservation_violation` (tier=`tier2`) JSONL record names the spanning pattern label.
4. `m018-p04-tier2-emitter-additivity.sh` — exercises the dispatch through the section-overflow fixture and asserts (a) the emitted `payload_breakdown` JSONL line is valid JSON; (b) the `tier2_savings_tokens` field is present with an integer value > 0; (c) a historical pre-P04 `payload_breakdown` record (pulled from a checked-in sample inside the fixture, OR from the existing `tests/fixtures/m018-p02-baseline-payload.golden.txt` if the format permits) parses cleanly via `python3 -c 'import json; [json.loads(l) for l in open(...)]'`.
5. `m018-p04-tier2-disable-flag.sh` — asserts (a) `ORCH_OVERRIDE_COMPRESSION_ENABLED=false` produces a payload byte-identical to `tests/fixtures/m018-p02-baseline-payload.golden.txt`; (b) `compression.tier2.enabled=false` (via a fixture config override) leaves Tier 1 still firing on a tier1-only fixture (e.g., the P03 fixture), proving Tier 2 short-circuited without affecting Tier 1.
6. `m018-p04-tier2-preservation-self-check.sh` — function-stub pattern (per the P03/T03 lesson): override `pres_check_section` to return 1 within the verifier's bash scope, source `_bc_apply_tier2`, and assert (a) the post-call payload is byte-identical to the pre-call payload (passthrough on failure); (b) a `tier_preservation_violation` JSONL record is appended with `tier=tier2`.
7. `m018-p04-dual-write-recent.sh` — asserts both `CLAUDE.md` and `AGENTS.md` contain a `# >>> orchestrator:recent-changes >>>`-delimited block whose body names "M018/P04" or "tier2".

## Steps

### Step 1 — Author `scripts/verify/_helpers/m018-p04-build-fixture.sh`

Mirror the P03 fixture-staging helper. The helper's job:

- `set_fixture <fixture-slug>` — given a slug like `section-overflow` or `boundary-refusal`, point `$PROJECT_ROOT_OVERRIDE` (or whatever env var build-context.sh reads — confirm against the P03 helper) at a transient `$TMPDIR_BUILD/_p04_fixture/<slug>/` tree that contains:
  - `.orchestrator/config.yml` — derived from the canonical config but with the tier1/filter caches pointing at fixture-private temp dirs and (for some test cases) `compression.tier2.section_budget_tokens` overridden small (e.g., 200) so a small fixture can exercise head-drop without needing 1500-token-sized sections.
  - `tests/fixtures/m018-p04-<slug>/dispatch-payload-fixture.md` symlinked or copied in.
  - The execution-log.jsonl path resolved under the fixture's milestone dir.
- Returns 0 on successful staging with stdout printing the staged fixture root path.
- Idempotent (clean staging dir on re-invocation).

The helper exists so each verifier is one-shot from outside (the verifier sources it, calls `set_fixture`, runs build-context.sh, asserts, exits). The helper does not embed assertion logic.

### Step 2 — Author `tests/fixtures/m018-p04-section-overflow/dispatch-payload-fixture.md`

A fixture whose `## Knowledge` section body is over-budget but contains NO multi-line preserved spans. Shape (illustrative — actual fixture authored to whatever budget the helper sets, e.g., 200 tokens for a small fast fixture):

```
---
schema_version: "1.0"
type: planning-prompt
---

# Dispatch Context — TASK_DISPATCH (P04, M018)

## Manifest
| Section | Lines | Est. Tokens | Priority |
|---------|-------|-------------|----------|
| Knowledge | 12-200 | ~180 | filtered |

## Knowledge

<filler text — ~180 tokens of plain prose, no code fences, no frontmatter
delimiters past the document opener, no JSONL records, no MEM IDs that
would interact with the boundary-refusal detector. Multi-paragraph,
multi-line, designed to exceed the 200-token fixture budget but to have
plenty of safe line boundaries.>

## Decisions

(no entries.)
```

Plus `tests/fixtures/m018-p04-section-overflow/README.md` documenting the fixture's shape and which truth it exercises.

### Step 3 — Author `tests/fixtures/m018-p04-boundary-refusal/dispatch-payload-fixture.md`

A fixture whose `## Upstream Context` section body is over-budget AND whose head-drop range contains an open 4-backtick (or 5-backtick) code fence whose closer lives inside the protected-tail range. The fence MUST be the canonical MIT-01 case: 4+ backticks, with no language tag or with a `bash`-style language tag, on its own line at column 0.

Sketch:

```
---
schema_version: "1.0"
type: planning-prompt
---

## Manifest
...

## Upstream Context

<text — ~50 tokens — leading prose>

````bash
<fence body — ~200 tokens — embedded code containing 3-backtick lines
that should NOT close the 4-backtick fence>
```nested-3-tick-fence
print "this is content of the outer 4-tick fence"
```
<more fence body — extends until past the protected-tail boundary>
````

<post-fence prose — ~50 tokens>
```

The fixture must be sized so the naive cut byte (`floor(body_chars * 0.7)` for the default 0.3 ratio) lands INSIDE the fence — so the boundary-refusal detector retreats to BEFORE the fence opener, OR (if the fence opener is itself above the budget cut) refuses to snip at all and emits a violation.

The fixture's README documents the expected behavior under the default 0.3 ratio at `section_budget_tokens=200`: cut retreats to line just above the fence opener; head-drop produces savings smaller than the maximum because the fence forces the cut higher than the naive boundary.

### Step 4 — Author `scripts/verify/m018-p04-tier2-head-drop.sh`

Outline:

```bash
#!/bin/bash
# M018/P04/T02: Verify Tier 2 head-drop produces a paged section whose tail
# is byte-identical to the pre-snip tail and whose token count fits the
# budget (or above-budget by no more than one preserved-span retreat).
set -u
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$PROJECT_ROOT/scripts/verify/_helpers/m018-p04-build-fixture.sh"

pass_n=0; fail_n=0
pass() { pass_n=$((pass_n+1)); printf 'PASS: %s\n' "$1"; }
fail() { fail_n=$((fail_n+1)); printf 'FAIL: %s\n' "$1"; }

# Stage fixture, run build-context.sh, capture output, assert.
fixture_root="$(set_fixture section-overflow)" || { fail "set_fixture"; exit 1; }
out="$fixture_root/_payload_out.txt"
ORCH_PROJECT_ROOT="$fixture_root" \
  bash "$PROJECT_ROOT/scripts/dispatch/build-context.sh" M018 P04 T01-test \
  > "$out" 2>/dev/null

# 1. The marker appears once immediately after `## Knowledge`.
grep -A1 '^## Knowledge' "$out" | grep -qE '<!-- compressed:tier2 head_dropped=[0-9]+ protected_tail_ratio=0\.30 -->' \
  && pass "marker emitted after Knowledge heading" \
  || fail "marker missing"

# 2. The trailing 30% of the pre-snip Knowledge section appears byte-identical
#    at the end of the post-snip Knowledge section.
#    The verifier reads the fixture's pre-snip body, computes the protected
#    tail bytes, and grep -F's the bytes against the post-snip output.
pre_body="$fixture_root/_pre_knowledge_body.txt"
# (helper-supplied: the pre-snip body of the Knowledge section.)
tail_bytes="$(wc -c < "$pre_body")"
tail_keep_bytes=$(( tail_bytes * 30 / 100 ))
tail "-c$tail_keep_bytes" "$pre_body" > "$fixture_root/_pre_tail.txt"
if grep -qF "$(head -c 200 "$fixture_root/_pre_tail.txt")" "$out"; then
  pass "protected tail prefix present in post-snip output"
else
  fail "protected tail prefix missing"
fi

printf 'SUMMARY: pass=%d fail=%d\n' "$pass_n" "$fail_n"
[ "$fail_n" -eq 0 ]
```

(The actual verifier handles `head -c 200` quoting more carefully via a temp file rather than the `$(...|...)` shape that AP-009 forbids — the sketch shows the assertion shape, the implementation uses two-step staging.)

### Step 5 — Author `scripts/verify/m018-p04-tier2-marker.sh`

Same fixture-staging shape. Assertions:

- The post-snip output contains EXACTLY ONE `<!-- compressed:tier2 head_dropped=` line.
- That line matches `<!-- compressed:tier2 head_dropped=[0-9]+ protected_tail_ratio=0\.30 -->` (extended-regex grep).
- The line appears immediately after `^## Knowledge` (line-after-heading invariant — `awk` two-line lookahead).
- The marker matches the cross-tier vocabulary entry verbatim: a final `grep -E '<!-- compressed:tier[0-9]+ [^>]*-->'` on the same line passes.

### Step 6 — Author `scripts/verify/m018-p04-tier2-boundary-refusal.sh`

Stage the boundary-refusal fixture. Assertions:

- The post-call output's `## Upstream Context` section either (a) contains an in-band tier2 marker whose `head_dropped` value is SMALLER than the naive head-drop would produce — proving retreat fired; OR (b) is byte-identical to the pre-call section AND a `tier_preservation_violation` JSONL record is present in the fixture's execution-log.jsonl with `tier=tier2` and `pattern=code-fence`.
- The 4-backtick code fence opener and closer are both present and unaltered in the output (no fence orphaned by the snip).

### Step 7 — Author `scripts/verify/m018-p04-tier2-emitter-additivity.sh`

Stage the section-overflow fixture; run the dispatch; read the most recent `payload_breakdown` line from the fixture's execution-log.jsonl. Assertions:

- The line parses as JSON via `python3 -c 'import json,sys;json.loads(sys.stdin.read())' < line`.
- The parsed object contains `tier2_savings_tokens` with an integer value > 0.
- The parsed object also still contains `tier1_savings_tokens`, `tier1_invocations`, `filter_dropped_tokens` (additivity, not replacement).
- A pre-P04 sample record (e.g., `tests/fixtures/m018-p02-baseline-payload.golden.txt`-style historical record bundled in the fixture's README, OR a standalone `tests/fixtures/m018-p04-pre-p04-payload-breakdown.jsonl` if needed) parses as JSON and lacks `tier2_savings_tokens` — proving the field is additive, not required.

### Step 8 — Author `scripts/verify/m018-p04-tier2-disable-flag.sh`

Two sub-assertions sharing the verifier file:

(a) **Master disable** — `ORCH_OVERRIDE_COMPRESSION_ENABLED=false bash scripts/dispatch/build-context.sh ...` against the P02 baseline fixture produces output byte-identical to `tests/fixtures/m018-p02-baseline-payload.golden.txt`. (Same shape as `m018-p03-disable-flag-honored.sh`.)

(b) **Per-tier disable** — stage a fixture with `compression.tier2.enabled: false` but `compression.enabled: true` and `compression.tier1.enabled: true`. Run the dispatch against an input whose Knowledge section is over-budget AND whose tool-result block is over-tier1-threshold. Assert (i) Tier 1 fired (`tier1_invocations > 0` in payload_breakdown); (ii) Tier 2 did NOT fire (`tier2_savings_tokens == 0` AND no `<!-- compressed:tier2` marker in the output).

### Step 9 — Author `scripts/verify/m018-p04-tier2-preservation-self-check.sh`

Function-stub pattern. The verifier:

1. Sources `scripts/lib/preservation-check.sh` then OVERRIDES `pres_check_section() { return 1; }` (a stub that always fails).
2. Source-extracts `_bc_apply_tier2` from `scripts/dispatch/build-context.sh` via the same awk range pattern P03 used for `_bc_apply_tier1` (`/^_bc_apply_tier2\(\)/,/^}/`).
3. Stages the section-overflow fixture, runs `_bc_apply_tier2 "$capture_file"` directly, and asserts (a) `$capture_file` is byte-identical to its pre-call snapshot; (b) the fixture's execution-log.jsonl contains a new `tier_preservation_violation` line with `tier=tier2`.

### Step 10 — Author `scripts/verify/m018-p04-dual-write-recent.sh`

Pure file-content assertion. Reads both `CLAUDE.md` and `AGENTS.md`, extracts the block between `# >>> orchestrator:recent-changes >>>` and `# <<< orchestrator:recent-changes <<<`, asserts both blocks contain the literal string `M018/P04` (or `tier2` — accept either since the dual-write content is editorial). Exit 0 on both-pass; 1 otherwise.

### Step 11 — Author [`.orchestrator/milestones/M018/phases/P04/P04-SUMMARY.md`](../../../../../milestones/M018/phases/P04/P04-SUMMARY.md)

Mirror the P03-SUMMARY shape. Frontmatter fields (matching MEM013 + the existing P03-SUMMARY frontmatter):

```yaml
schema_version: "1.0"
type: phase-summary
id: P04
parent: M018
milestone: M018
provides: |
  Tier 2 snip live in scripts/dispatch/build-context.sh:_bc_apply_tier2 —
  head-drop of in-scope section bodies (Knowledge, Task Plan, Upstream
  Context) above compression.tier2.section_budget_tokens (default 1500),
  preserving compression.tier2.protected_tail_ratio (default 0.3) of
  pre-snip section bytes byte-identical at the tail; in-band marker
  `<!-- compressed:tier2 head_dropped=N protected_tail_ratio=R -->` named
  immediately after the section heading; line-aligned cut with
  boundary-refusal walker that retreats above multi-line preserved spans
  (frontmatter `^---$` pairs and `^\`{3,}[a-zA-Z0-9_-]*$` code-fence pairs
  by tick-count, MIT-01-aware); pass-through on no-safe-boundary plus a
  `tier_preservation_violation` JSONL record (tier=tier2, pattern=spanning
  cross-tier label); preservation self-check via pres_check_section ...
  tier2 (strict multiplicity); additive integer `tier2_savings_tokens`
  field on payload_breakdown JSONL emit (CON-5); compression.tier2.{enabled,
  section_budget_tokens, protected_tail_ratio} config keys in
  .orchestrator/config.yml + templates/orchestrator-config-default.yml;
  three new kf_get_tier2_* accessors in scripts/lib/knowledge-filter.sh;
  seven P04-private truth verifiers under scripts/verify/m018-p04-*.sh;
  two fixture trees under tests/fixtures/m018-p04-{section-overflow,
  boundary-refusal}/; scripts/verify/_helpers/m018-p04-build-fixture.sh
  fixture-staging helper; CLAUDE.md/AGENTS.md recent-changes refresh.
requires: |
  P03 _bc_apply_tier1 wiring shape (build-context.sh call-site adjacency);
  P02 preservation-check library (pres_check_section + pres_emit_violation
  + PRES_PATTERNS_REGEX cross-tier vocabulary including the MIT-01
  4+-backtick code-fence regex which is load-bearing for boundary
  detection); P02 byte-identity golden (tests/fixtures/m018-p02-baseline-
  payload.golden.txt) for the disable-flag regression contract; P01
  references/compression-grammar.md `## Tier: tier2` rules.
affects: |
  P05 (eval harness reads payload_breakdown.tier2_savings_tokens and
  tier_preservation_violation records with tier=tier2 from execution-
  log.jsonl per the additive-emitter invariants section of the grammar
  contract); P06 (T3 auto-compact runs AGAINST the tier2 output — sees
  head-dropped-plus-protected-tail bytes, not pre-snip bytes; tier3
  must NOT mutate the tier2 in-band marker per the grammar contract;
  tier3 wraps the marker if the section is summarized further);
  M027/M019 cost surfaces consume tier2_savings_tokens via the existing
  payload_breakdown read path.
key_files: |
  scripts/dispatch/build-context.sh;scripts/lib/knowledge-filter.sh;
  .orchestrator/config.yml;templates/orchestrator-config-default.yml;
  tests/fixtures/m018-p04-section-overflow/dispatch-payload-fixture.md;
  tests/fixtures/m018-p04-section-overflow/README.md;
  tests/fixtures/m018-p04-boundary-refusal/dispatch-payload-fixture.md;
  tests/fixtures/m018-p04-boundary-refusal/README.md;
  scripts/verify/_helpers/m018-p04-build-fixture.sh;
  scripts/verify/m018-p04-tier2-head-drop.sh;
  scripts/verify/m018-p04-tier2-marker.sh;
  scripts/verify/m018-p04-tier2-boundary-refusal.sh;
  scripts/verify/m018-p04-tier2-emitter-additivity.sh;
  scripts/verify/m018-p04-tier2-disable-flag.sh;
  scripts/verify/m018-p04-tier2-preservation-self-check.sh;
  scripts/verify/m018-p04-dual-write-recent.sh
key_decisions: |
  Boundary-refusal walker retreats DOWN from the naive cut line toward
  line 1 looking for the first line whose at-line-start unsafe flag is 0
  (the line that OPENS a span is itself safe — cutting above the opener
  is correct because everything from the opener onward falls into the
  protected tail); 4+-backtick fence tracking by tick-count not by line
  count (3-backtick lines do not close 4-backtick fences — MIT-01);
  no-safe-boundary refusal passes the section through verbatim plus a
  tier_preservation_violation JSONL emit (NOT a tier2_preservation_breach
  — that record is reserved for the protected-tail breach path which
  the boundary-refusal detector makes unreachable; the grammar contract
  separates the two record types intentionally); strict-multiplicity
  tier2 self-check shape (mirrors the tier1 strict-multiplicity branch
  in pres_check_section); _bc_apply_tier2 inline in build-context.sh
  (single call site, MEM004 carve-out — no extraction to scripts/lib
  until a second caller emerges); tier2 has NO cache (head-drop is
  destructive on the in-flight payload; originals on disk are untouched
  per Constitution Principle VI; cache-prune utility is reusable but not
  wired in this phase); fixture-staging helper mirrors P03 shape
  one-helper-per-phase under scripts/verify/_helpers/.
patterns_established: |
  Awk single-pass section-aware head-drop with at-line-start unsafe-flag
  recording (T01 — usable shape for P05/P06 if their tiers ever need
  per-line span awareness); function-stub pattern reused from P03/T03
  (override pres_check_section to return 1 to exercise the failure path
  without depending on regex contents); dual-fixture pattern (one fixture
  exercising the happy-path, one exercising the boundary-refusal path —
  reusable for any tier whose safety boundary is the load-bearing claim).
drill_down_paths: |
  .orchestrator/milestones/M018/phases/P04/tasks/T01-tier2-head-drop-SUMMARY.md;
  .orchestrator/milestones/M018/phases/P04/tasks/T02-verifiers-and-summary-SUMMARY.md
duration: ~4h
verification_result: pass
observability_surfaces: |
  execution-log.jsonl: payload_breakdown.tier2_savings_tokens additive
  integer field; tier_preservation_violation record_type
  (tier=tier2 from this phase; same schema as tier1 from P03 and tier3
  from P06).
completed_at: 2026-04-28T00:00:00Z
```

The body documents the phase-close summary, risk-mitigation traceability, and follow-ups for downstream phases — same shape as P03-SUMMARY.

### Step 12 — Dual-write CLAUDE.md / AGENTS.md `orchestrator:recent-changes` block

Compose a one-line recent-changes update naming M018/P04. Example:

```
- 030-context-compression-layer: M018/P04 — Tier 2 snip. Section head-drop with protected tail; in-band tier2 marker; preserved-pattern boundary refusal (MIT-01-aware); additive tier2_savings_tokens.
```

Run:

```
bash scripts/util/dual-write-runtime-md.sh "<the new recent-changes line>"
```

Confirm both files received the update.

### Step 13 — Run all P04 verifiers

```
for v in scripts/verify/m018-p04-*.sh; do bash "$v"; done
bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P04/
```

Both calls should exit 0 with all PASS lines.

## Must-Haves

- All seven verifier scripts exist and exit 0 (one per truth in P04-PLAN.md).
- Two fixture trees exist under `tests/fixtures/m018-p04-*` with README files.
- Fixture-staging helper exists under `scripts/verify/_helpers/m018-p04-build-fixture.sh`.
- P04-SUMMARY.md exists at [`.orchestrator/milestones/M018/phases/P04/P04-SUMMARY.md`](../../../../../milestones/M018/phases/P04/P04-SUMMARY.md) with the frontmatter named in Step 11 and a body documenting closure summary, risk-mitigation traceability, follow-ups for downstream phases, and verification result.
- CLAUDE.md AND AGENTS.md `orchestrator:recent-changes` blocks both name `M018/P04` (or `tier2`).
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P04/` exits 0.

## Verification

- Each of the seven `scripts/verify/m018-p04-*.sh` scripts exits 0 when invoked directly.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P04/` exits 0 with every truth's `Check:` reporting PASS.
- `python3 -c 'import json,sys;[json.loads(l) for l in sys.stdin]'` against the section-overflow fixture's execution-log.jsonl parses cleanly (every line valid JSON; no schema regression).

## Inputs

### From Previous Tasks (within P04)

- T01 has shipped:
  - `scripts/dispatch/build-context.sh` `_bc_apply_tier2` function, the call-site insertion at line ~1724, the `TIER2_*` config reads at line ~193, and the `tier2_savings_tokens` field on `_bc_emit_payload_breakdown`'s printf.
  - `scripts/lib/knowledge-filter.sh` `kf_get_tier2_{enabled,section_budget_tokens,protected_tail_ratio}` accessors.
  - `.orchestrator/config.yml` and `templates/orchestrator-config-default.yml` `compression.tier2.*` block.

### From Disk (Pre-existing)

- `scripts/verify/_helpers/m018-p03-build-fixture.sh` — canonical fixture-staging helper shape T02 mirrors.
- `scripts/verify/m018-p03-tier1-paging.sh` and the other six P03 verifiers — canonical verifier shape (pass/fail counters, fixture staging, single-script invocation per truth).
- `scripts/verify/m018-p03-preservation-self-check.sh` — canonical function-stub-override-and-source-extract pattern T02 reuses for `m018-p04-tier2-preservation-self-check.sh`.
- `scripts/verify/check-must-haves.sh` — the framework that consumes P04-PLAN.md's `Check:` lines.
- `scripts/util/dual-write-runtime-md.sh` — the CLAUDE.md/AGENTS.md dual-write helper.
- `tests/fixtures/m018-p02-baseline-payload.golden.txt` — disable-flag regression contract.
- `tests/fixtures/m018-p03-tool-result/dispatch-payload-fixture.md` — usable as the per-tier-disable fixture (contains an over-tier1-threshold tool-result block; T2 must NOT fire on it when `compression.tier2.enabled=false`).
- `references/compression-grammar.md` `## Tier: tier2` (lines 191–211) — contract.

## Constraints

- **AD-19 (single-script-file Check)**: every truth in P04-PLAN.md has a `Check: bash <one path>.sh` line; the script may be self-contained or it may source helpers, but `check-must-haves.sh` invokes ONE script per truth.
- **AP-009 (Bash shape guard)**: zero compound chains > 2; zero plain subshells; zero `$(...|...)` shell forms in verifier scripts. Use staged temp files instead of pipes-into-substitutions. (The dispatch-internal carve-out applies to `_bc_*` helpers in build-context.sh, NOT to verifier scripts — verifier scripts must stay AP-009-compliant strictly.)
- **Bash 3.2 compatibility**: parallel indexed arrays only; no associative arrays; no `<(...)` process substitution.
- **Constitution Principle VI**: verifier scripts and fixtures live under their canonical directories (`scripts/verify/`, `tests/fixtures/`, `.orchestrator/milestones/M018/phases/P04/`); they do NOT mutate the canonical knowledge tree, spec, plan, or roadmap files.
- **MIT-01**: the boundary-refusal verifier MUST exercise a 4+-backtick code-fence case to assert the regex behavior — a 3-backtick-only fixture would not catch a regression to the 3-backtick regex.

## Expected Output

- `scripts/verify/_helpers/m018-p04-build-fixture.sh` exists, ~80–120 lines, mirrors the P03 helper.
- `tests/fixtures/m018-p04-section-overflow/{dispatch-payload-fixture.md,README.md}` exist.
- `tests/fixtures/m018-p04-boundary-refusal/{dispatch-payload-fixture.md,README.md}` exist.
- `scripts/verify/m018-p04-tier2-head-drop.sh` exists, ~60–100 lines, exits 0.
- `scripts/verify/m018-p04-tier2-marker.sh` exists, ~50–80 lines, exits 0.
- `scripts/verify/m018-p04-tier2-boundary-refusal.sh` exists, ~80–120 lines, exits 0.
- `scripts/verify/m018-p04-tier2-emitter-additivity.sh` exists, ~60–100 lines, exits 0.
- `scripts/verify/m018-p04-tier2-disable-flag.sh` exists, ~80–120 lines, exits 0.
- `scripts/verify/m018-p04-tier2-preservation-self-check.sh` exists, ~60–100 lines, exits 0.
- `scripts/verify/m018-p04-dual-write-recent.sh` exists, ~30–50 lines, exits 0.
- [`.orchestrator/milestones/M018/phases/P04/P04-SUMMARY.md`](../../../../../milestones/M018/phases/P04/P04-SUMMARY.md) exists, ~80–150 lines, contains "tier2_savings_tokens".
- `CLAUDE.md` and `AGENTS.md` recent-changes blocks both name `M018/P04`.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P04/` exits 0.
