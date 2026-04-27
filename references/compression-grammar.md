---
schema_version: "1.0"
type: compression-grammar
version: "1.0.0"
status: "Draft"
last_revised: "2026-04-27"
---

# Compression Grammar

> Versioned tier-by-tier contract for the M018 Context Compression Layer.
> Self-contained — read this document end-to-end to understand exactly what each
> tier may touch, what it must preserve byte-for-byte, what its in-band marker
> grammar looks like, and what additive emitter-schema invariants it must
> respect (CON-5).
>
> Authoring scope: M018/P01/T01. Reviewed by the conversus `--strict` gate
> (T03). Status advances `Draft` → `Reviewed` on PASS verdict.

## Overview

### Purpose

This document is the parse-regression safety contract for the four-tier
compression pipeline introduced in M018 (specs/030-context-compression-layer).
It pins down, per tier:

- **Scope** (`applies-to`): which artifact classes a tier may transform.
- **Preservation invariants** (`preserves`): the byte-pattern vocabulary that
  must survive every tier transformation byte-identical.
- **Savings ceiling**: per-tier 80% confidence interval from the P00 probe,
  so reviewers can dispute the modeling assumptions on paper rather than
  after tier code lands.
- **Failure semantics**: what happens when a tier's preservation self-check
  rejects an output (FR-2 — pass through to next tier; emit JSONL).
- **Marker grammar**: the in-band HTML-comment shape (FR-19, CON-4) that
  downstream tooling reads to detect compression without parsing JSONL.

### Scope

This contract governs the M018 minimal slice plus Tier 2 and Tier 3:

- **filter** (FR-3): zero-LLM, drops superseded/experimental knowledge entries
  pre-payload-assembly.
- **tier1** (FR-5): zero-LLM, deduplicates tool-call records and tool-result
  blocks across the payload.
- **tier2** (FR-6): zero-LLM, head-drops `payload-section-body` content for the
  three highest-token sections (Knowledge, Task Plan, Upstream Context) while
  preserving a configured tail ratio.
- **tier3** (FR-7, FR-8): LLM-call-bearing, summarizes the same three sections
  post-Tier-2 if they still exceed a per-section budget.

### Non-goals

- **NG-1 (Tier 4 deferred)**: A semantic-fact-extraction tier (FR-not-yet) is
  explicitly OUT OF SCOPE for M018. Future T4 work does NOT silently inherit
  this contract — it must produce its own grammar document and re-pass the
  conversus `--strict` gate. The only T4-relevant invariant in this document
  is the marker-grammar reservation `tier-id = "1" | "2" | "3"` (Tier 4 must
  pick a fresh tier-id and document it before lighting up).

- **NG-2 (out-of-payload paths)**: This contract governs payload assembly
  (`scripts/dispatch/build-context.sh`). Other context paths (knowledge index
  rebuild, summary writes, verification reports) are untouched — they are
  not compressed, and are not subject to this contract.

- **NG-3 (parse-regression, not factual review)**: The grammar contract
  defines safety boundaries for byte-pattern preservation. It does NOT define
  when a section is "factually summarized correctly" — that question belongs
  to the conversus gate at design time and to manual review at run time, not
  to a regex.

---

## Marker Grammar

Every tier that modifies a `payload-section-body` MUST emit a single HTML-comment
marker in-band so downstream tooling (eval harness, debug tools, agents) can
detect compression without parsing JSONL (FR-19, CON-4).

### ABNF-style shape

```
marker     = "<!-- compressed:tier" tier-id " " kvpairs " -->"
tier-id    = "1" | "2" | "3"
kvpairs    = kvpair *( " " kvpair )
kvpair     = key "=" value
key        = 1*ALPHA / 1*ALPHA "-" 1*ALPHA
value      = quoted-string / token   ; token excludes whitespace and ">"
```

### Per-tier examples (verbatim shape)

- **tier1**: `<!-- compressed:tier1 cached_bytes=12288 cache_key=sha256:abc...123 -->`
- **tier2**: `<!-- compressed:tier2 head-dropped=4096 protected_tail_ratio=0.3 -->`
- **tier3**: `<!-- compressed:tier3 model=claude-3-5-sonnet input_tokens=8192 output_tokens=1024 -->`

### Filter is special

The filter tier does NOT emit an in-band marker. The filter operates
pre-payload-assembly, so a filtered knowledge entry simply does not appear in
the payload — there is no surviving section body to annotate. Filter savings
are visible exclusively via the additive `payload_filter` JSONL record (new in
M018) and the `filter_dropped_tokens` field on each `payload_breakdown`
record.

### Additive-only invariant

The marker grammar is append-only across versions. Existing kvpairs MUST NOT
be renamed, retyped, or removed across schema_version revisions. New kvpairs
MAY be added to any tier's marker; consumers MUST tolerate unknown keys
(treat as opaque). Tier-id values are reserved: 1, 2, 3 are claimed; 4+ are
reserved for future tiers and require their own grammar contract.

---

## Preserved-Pattern Vocabulary

The following byte patterns MUST survive every tier transformation byte-identical.
This vocabulary is cross-tier — every tier's `preserves:` block inherits it
implicitly. Tier-specific extensions are listed under each tier section below.

| Pattern                      | Regex                                                          | Example bytes                                                                         |
|------------------------------|----------------------------------------------------------------|---------------------------------------------------------------------------------------|
| YAML frontmatter delimiters  | `^---$` ... `^---$`                                            | `---\nschema_version: "1.0"\n---`                                                     |
| Code fences                  | `` ^```[a-zA-Z0-9_-]*$ `` ... `` ^```$ ``                      | `` ```bash\necho hi\n``` ``                                                           |
| Absolute file paths          | `/[A-Za-z0-9_./-]+\.(sh|md|yml|yaml|jsonl?|py|txt)`            | `/Users/x/scripts/dispatch/build-context.sh`                                          |
| Repo-relative script paths   | `scripts/[A-Za-z0-9_./-]+\.sh`                                 | `scripts/util/with-env.sh`                                                            |
| MEM IDs                      | `\bMEM[0-9]{3}\b`                                              | `MEM020`                                                                              |
| Command names                | `orchestrator:[a-z-]+`                                         | `orchestrator:dispatch`                                                               |
| URLs                         | `https?://[^\s)]+`                                             | `https://example.com/path?q=1`                                                        |
| JSONL records                | a complete `{...}` line in any `.jsonl` file                   | `{"record_type":"payload_breakdown","tokens":1234}`                                   |
| Scaffold-placeholder markers | `&lt;TODO:[^&gt;]+&gt;` (rendered: angle-bracket TODO marker)  | `&lt;TODO: derive section budget&gt;`                                                 |
| In-band compression markers  | `<!-- compressed:tier[0-9]+ [^>]*-->`                          | `<!-- compressed:tier2 head-dropped=4096 protected_tail_ratio=0.3 -->`                |

Rationale: each pattern names a load-bearing identifier or structural anchor
that downstream consumers parse mechanically. A tier transformation that
mangles any of these breaks a real consumer (state machine, dispatcher,
knowledge index, eval harness, debug tooling, the conversus adapter's own
`_todo_count` pre-flight check).

---

## Tier: filter

**applies-to:**
- `knowledge-entry` — one item per `MEM*.md` candidate before payload assembly. The filter reads each entry's `status:` field and drops list-matched values (`superseded`, `experimental`, etc., per FR-3 closed enum).

**preserves:**
- All cross-tier vocabulary patterns (frontmatter delimiters, code fences, paths, MEM IDs, command names, URLs, JSONL records, scaffold-placeholder markers, compression markers).
- `^---$` knowledge-entry frontmatter delimiters — `---\nschema_version: "1.0"\n---` (filter never opens an entry; it accepts or drops as a whole).
- The first-heading line of any retained entry — `# MEM020: <title>` (the entry body itself is opaque to the filter).

**savings ceiling (P00 probe, 80% CI):**
- low: 12.55%
- mean: 13.08%
- high: 13.67%
- model assumption: drops ~30% of Knowledge tokens, Beta(2,5) prior on superseded/experimental fraction.

**failure semantics:**
- The filter operates on whole-entry granularity — there is no preserved-pattern self-check at the entry interior (the entry is either retained whole or dropped whole).
- A drop is a no-op write to the payload plus an additive `payload_filter` JSONL record naming the dropped entry IDs and their token counts.
- If the filter cannot read an entry's `status:` field (parse error), the entry is RETAINED (fail-open) and an `entry_status_unparseable` field is set on the `payload_filter` record. The filter never crashes the dispatcher.

---

## Tier: tier1

**applies-to:**
- `tool-result-block` — inline `Read`/`Bash` outputs embedded in the payload's Upstream Context or Task Plan sections.
- `tool-call-record` — deduplicated by `SHA-256(command + input)` so identical tool calls collapse to a single full-fidelity record plus N references.

**preserves:**
- All cross-tier vocabulary patterns.
- The `<file_path>` reference shape `<tool-result file="..." preview-bytes="..."> ... </tool-result>` — tier1 may collapse the body but never the wrapper attributes.
- The first occurrence of every deduplicated tool-call's full record (subsequent occurrences become references via the in-band tier1 marker).

**savings ceiling (P00 probe, 80% CI):**
- low: 6.24%
- mean: 6.31%
- high: 6.40%
- model assumption: drops ~50% of tool-result tokens, conditioned on ~30% prevalence inside Task Plan + Upstream Context.

**failure semantics:**
- Self-check on output: every preserved-pattern regex from the cross-tier vocabulary plus the tier1-specific `<tool-result ...>` wrapper must match the same bytes pre- and post-transform.
- On preserved-pattern self-check failure, pass payload through to next tier unmodified. Emit `{"record_type":"tier_preservation_violation","tier":"tier1","section":"<id>","pattern":"<regex>","timestamp":"<iso8601>"}` to `execution-log.jsonl`.
- Cache-key collisions (different tool-call inputs hashing to the same SHA-256 prefix) MUST NOT occur with full-length SHA-256; if a future implementation truncates the cache key, this contract requires a regression test.

---

## Tier: tier2

**applies-to:**
- `payload-section-body` for the three highest-token sections per the P00 probe: `Knowledge`, `Task Plan`, `Upstream Context`. Other sections are out of scope for tier2.

**preserves:**
- All cross-tier vocabulary patterns.
- The trailing `protected_tail_ratio` of the section, byte-identical, as defined by the operator's config (default 0.3 — the last 30% of section bytes survive verbatim).
- The section's identifier line (the `## <Section>` heading, if present) — head-drop never deletes the heading itself.
- The in-band tier2 marker — once emitted, downstream tier3 may surround it but MUST NOT mutate its kvpairs.

**savings ceiling (P00 probe, 80% CI):**
- low: 25.33%
- mean: 25.49%
- high: 25.68%
- model assumption: head-drops ~40% of EXCESS over the 1500-tok tail threshold on any section that exceeds it (preserves last 1500 tok verbatim).

**failure semantics:**
- Self-check on output: the `protected_tail_ratio` portion of the original section must appear byte-identical at the end of the tier2 output. Every cross-tier preserved-pattern that fell inside the protected tail must match byte-identical pre- and post-transform.
- On preserved-pattern self-check failure, pass payload through to next tier unmodified. Emit `{"record_type":"tier_preservation_violation","tier":"tier2","section":"<id>","pattern":"<regex>","timestamp":"<iso8601>"}` to `execution-log.jsonl`.
- Additionally, on protected-tail breach (rare — should be impossible by construction), emit `tier2_preservation_breach` (a distinct record type from the generic violation, because the protected-tail invariant is the load-bearing safety claim of tier2).

---

## Tier: tier3

**applies-to:**
- `payload-section-body` for `Knowledge`, `Task Plan`, `Upstream Context`, **post-Tier-2**. Tier3 sees the tier2 output (head-dropped + protected tail), not the original section.
- Tier3 only fires on sections that still exceed the per-section budget (default 2000 tokens) after tier2 (FR-7).
- Tier3 only fires when intensity ≥ Standard (the LLM call cost is gated on intensity per CON-3).

**preserves:**
- All cross-tier vocabulary patterns.
- The section's identifier line (the `## <Section>` heading, if present) — the LLM summary replaces body, never the heading.
- The in-band tier2 marker (if tier2 fired on this section) — tier3 wraps but does not mutate.
- The in-band tier3 marker — emitted around the LLM-summary body.

**savings ceiling (P00 probe, 80% CI):**
- low: 12.10%
- mean: 12.22%
- high: 12.36%
- model assumption: summarizes ~40% of EXCESS above the per-section budget (2000 tok) on Knowledge + Task Plan + Upstream Context; Standard+ intensity assumed.

**failure semantics:**
- Self-check on output: every cross-tier preserved-pattern that appeared in the tier3 input MUST appear in the tier3 output byte-identical, AT LEAST ONCE. (Unlike tier2, tier3 is permitted to drop duplicate occurrences — the LLM may reasonably collapse a paragraph that mentions `MEM020` three times into a summary that mentions it once.)
- On preserved-pattern self-check failure, pass payload through to next tier unmodified (in practice, this means the post-Tier-2 output survives untouched). Emit `{"record_type":"tier_preservation_violation","tier":"tier3","section":"<id>","pattern":"<regex>","timestamp":"<iso8601>"}` to `execution-log.jsonl`.
- LLM-call-failure semantics (network error, rate-limit, timeout) are a separate path: emit `tier3_failed` JSONL with `reason` + `error_class`, pass through tier2's output, never crash the dispatcher.
- LLM-call-skip semantics (intensity below Standard, section under budget): emit `tier3_skipped` JSONL with `reason`.
- LLM-call no-savings semantics (the summary is longer than the input): emit `tier3_no_savings` JSONL and discard the summary; pass through tier2's output.

---

## Aggregate Plausibility (SC-9)

### The calibrated floor

Per spec.md SC-9 (as amended at P00 close, 2026-04-27), the success threshold
floor is **34.7% mean payload-token reduction**, derived from
`scripts/diagnostics/m018-section-distribution.sh` aggregate-ceiling 80% CI
lower bound across n=169 historical `payload_breakdown` records (n=172 at
T03-run dispatch time). Probe outputs are durable at
`.orchestrator/scratch/m018-section-distribution-output.{json,txt}`.

### Per-tier 80% CIs (probe output, verbatim)

| tier   | low_pct | mean_pct | high_pct |
|--------|---------|----------|----------|
| filter | 12.55%  | 13.08%   | 13.67%   |
| tier1  | 6.24%   | 6.31%    | 6.40%    |
| tier2  | 25.33%  | 25.49%   | 25.68%   |
| tier3  | 12.10%  | 12.22%   | 12.36%   |

### Aggregate (P00 bootstrap, non-overlap-adjusted)

| stat       | pct    | tokens |
|------------|--------|--------|
| low (p10)  | 34.73% | 5,883  |
| mean       | 35.08% | 5,941  |
| high (p90) | 35.39% | 5,994  |

### Composition argument

If filter, tier1, tier2, and tier3 fire as modeled, the aggregate ceiling
lands at **35.08% mean / 34.73% low / 35.39% high** — clearing the 34.7%
floor at the lower bound of the 80% CI, with margin at the mean.

The aggregate is NOT a simple sum of per-tier ceilings (12.55 + 6.24 + 25.33
+ 12.10 = 56.22% would be naive). Overlap matters — a token saved by the
filter cannot also be saved by tier3 on the same section, and tier3's input
is tier2's output. The probe's `aggregate_ceiling` already accounts for this
via bootstrap resampling against per-record section composition; see
`.model_assumptions` in
`.orchestrator/scratch/m018-section-distribution-output.json` for the model
priors.

### What can break the floor

- **Filter under-fires**: if the prevalence of `superseded`/`experimental`
  knowledge entries is lower than the Beta(2,5) prior assumes, filter savings
  drop below 12.55% and the aggregate floor is at risk. Mitigation: P00 used
  the historical knowledge tree, so the prior is grounded in observed data.
- **Tier2 protected_tail_ratio raised**: if operators raise the default 0.3
  tail ratio system-wide, tier2 head-drops less, savings drop below 25.33%.
  Mitigation: the default is set in code; raising it is a deliberate operator
  choice.
- **Tier3 disabled**: if intensity stays below Standard across the workload,
  tier3 never fires. Aggregate drops to ~22.85% mean (filter+tier1+tier2),
  below the 34.7% floor. Mitigation: SC-9 is reported under Standard+
  intensity; the spec acknowledges Quick-only workloads are out of scope for
  the threshold.

Reviewers (and the conversus gate) are invited to dispute these modeling
assumptions on paper rather than after tier code lands.

---

## Additive Emitter Invariants (CON-5)

### Verbatim CON-5 (from spec.md)

> **CON-5 (back-compat-emitters)**: All M019 schema changes are additive.
> Pre-M018 records remain readable by post-M018 rollups; post-M018 records
> are readable by pre-M018 jq filters (missing fields treated as null).

### New fields on existing record types (FR-10)

- `payload_breakdown` (existing M019 record) adds:
  - `filter_dropped_tokens` — integer; sum of token counts across entries the filter tier dropped for this dispatch. Absent on pre-M018 records (consumers treat as null/0).
  - `tier1_savings_tokens` — integer; total tokens reclaimed by tier1 deduplication on this dispatch.
  - `tier2_savings_tokens` — integer; total tokens reclaimed by tier2 head-drop on this dispatch.
  - `tier3_compression_savings_tokens` — integer; total tokens reclaimed by tier3 LLM summarization on this dispatch.

- `dispatch_usage` (existing M019/M027 record) adds:
  - `tier3_compression_savings_tokens` — integer; tokens saved by tier3 on the payload eventually dispatched. Present only when tier3 fired; absent otherwise.

- `unit_close` (existing M019 record) adds:
  - `tier1_invocations` — integer; count of tier1 firings during the unit's lifetime.
  - `tier3_invocations` — integer; count of tier3 firings during the unit's lifetime.

### New record types (additive)

- `payload_filter` — emitted by the filter tier; names dropped entries plus reason class.
- `tier_preservation_violation` — emitted by tier1/tier2/tier3 on preserved-pattern self-check failure.
- `tier3_skipped` — emitted by tier3 when intensity gate or budget gate prevents firing.
- `tier3_failed` — emitted by tier3 on LLM-call failure (network, rate-limit, timeout).
- `tier3_no_savings` — emitted by tier3 when the LLM summary is longer than the input.
- `tier2_preservation_breach` — emitted by tier2 specifically on protected-tail breach (a distinct, narrower record than the generic `tier_preservation_violation`).

### Back-compat contract

- Every new field is OPTIONAL in the JSON Schema sense.
- Pre-M018 jq filters reading post-M018 records will see missing fields as `null` — this is the documented null-treats-as-zero contract for numeric rollups (cost rollups, anomaly detection, efficiency footer).
- Post-M018 rollups reading pre-M018 records MUST treat absent additive fields as `null` and coalesce to `0` for numeric aggregation. Idiom: `(.filter_dropped_tokens // 0)` in jq.
- No existing field is renamed, retyped, or removed. No record type is renamed. New record types share the existing `record_type` discriminator and append, never collide.

---

## Failure Semantics (FR-2)

### The preservation contract

Every tier's implementation MUST include a self-check that scans the tier's
proposed output for corruption of any preserved-pattern byte (cross-tier
vocabulary plus tier-specific extensions, listed under each tier section).
Self-check failure means the tier produced an output that mangles a
load-bearing pattern.

### What happens on failure

- The tier MUST NOT emit the corrupted output.
- The payload (tier's input) passes through unmodified to the next tier in
  the pipeline.
- The tier emits a `tier_preservation_violation` JSONL record to
  `execution-log.jsonl`.
- The dispatcher proceeds. Compression is best-effort; preservation is
  non-negotiable.

### `tier_preservation_violation` record schema

```json
{
  "record_type": "tier_preservation_violation",
  "tier": "tier1" | "tier2" | "tier3",
  "section": "<section identifier, e.g. 'Knowledge' or 'Task Plan'>",
  "pattern": "<regex string that triggered the violation>",
  "timestamp": "<ISO 8601 UTC, e.g. 2026-04-27T14:23:01Z>"
}
```

### Tier 3 LLM-call failure paths

Tier 3 has additional failure modes distinct from preservation-contract
violations:

- **`tier3_failed`** — LLM call returned an error (network, rate-limit,
  timeout, malformed response). Pass through tier2's output; never crash.
- **`tier3_skipped`** — tier3 declined to fire (intensity below Standard,
  section under per-section budget, dispatcher disabled tier3 via config).
  Pass through tier2's output.
- **`tier3_no_savings`** — LLM summary is longer than input. Discard summary;
  pass through tier2's output.

All three are non-fatal, additive-only signal records. None of them block
dispatch.

---

## Open Questions

No open questions at v1.0.0 author time. Conversus gate findings (if any) are appended below by the operator after T03.

---

## Version History

- **1.0.0** (2026-04-27) — Initial draft authored under M018/P01/T01. Frontmatter `status: Draft`. Conversus gate (T03) advances to `Reviewed` on PASS.
