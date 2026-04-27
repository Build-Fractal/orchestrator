---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M018"
name: "Author the compression-grammar contract"
depends_on: []
---

## Prerequisites

P00 closed (2026-04-27) and amended `specs/030-context-compression-layer/spec.md` SC-9 to a 34.7% calibrated mean payload-token reduction floor. The probe outputs are durable on disk:

- `.orchestrator/scratch/m018-section-distribution-output.json` — the source-of-truth probe output (per-tier and aggregate CIs, model assumptions verbatim under `.model_assumptions`).
- `.orchestrator/scratch/m018-section-distribution-output.txt` — text summary of the same.

These files are READ-ONLY for this task. T01 cites their numbers verbatim in the grammar document so reviewers (and the conversus gate) can dispute the modeling assumptions on paper rather than after tier code lands.

## Description

Create `references/compression-grammar.md`, a versioned tier-by-tier contract that pins down exactly what each compression tier (filter, tier1, tier2, tier3) may touch, what it must preserve byte-for-byte, what its in-band marker grammar looks like, and what additive emitter-schema invariants it must respect (CON-5).

The contract is the artifact the conversus `--strict` gate (T03) reviews. Reviewers must be able to read this document end-to-end and identify: (a) safety boundaries — what each tier may NOT cross; (b) discoverability — how downstream consumers (eval harness, debug tools, agents) detect that a section was compressed; (c) plausibility against SC-9 — the document names per-tier savings ceilings from P00's probe and shows how their composition can clear the 34.7% floor; (d) failure semantics — what happens when a tier's self-check rejects an output (FR-2 preservation contract: pass through to next tier; emit `tier_preservation_violation` JSONL).

Tier 4 is OUT OF SCOPE per NG-1; the document calls this out explicitly so future T4 work does not silently inherit the M018 contract.

## Steps

1. **Read source material end-to-end** before writing a single line:
   - `specs/030-context-compression-layer/spec.md` — the full feature spec (FR-1, FR-2, FR-19 are the load-bearing requirements; CON-1, CON-3, CON-4, CON-5, CON-6 are the constraints; SC-9 is the calibrated target).
   - `.orchestrator/milestones/M018/phases/P00/P00-SUMMARY.md` — the probe-derived per-tier CIs and model assumptions verbatim. Cite these numbers in the grammar document; do not re-derive them.
   - `.orchestrator/scratch/m018-section-distribution-output.json` — the probe output. The `.model_assumptions` block is your source of truth for what each tier is *modeled* to remove; the grammar document tells reviewers whether the safety boundaries permit those removals.
   - `references/file-formats.md` — existing reference style (header, frontmatter, section conventions) to match house style.

2. **Plan the document structure** before writing. The lint verifier (T02) parses for required blocks. Use exactly these headings so the lint regex is stable:
   - YAML frontmatter (schema_version, type, version, status, last_revised).
   - `# Compression Grammar` title.
   - `## Overview` — purpose, scope, non-goals (T4 deferred).
   - `## Marker Grammar` — `<!-- compressed:tierN ... -->` shape, what each tier emits, additive-only invariant.
   - `## Preserved-Pattern Vocabulary` — the cross-tier pattern catalogue (frontmatter, code fences, paths, MEM IDs, command names, URLs, JSONL records, scaffold-placeholder markers); each pattern has a regex and an example.
   - `## Tier: filter` — `applies-to:` block + `preserves:` block + `savings ceiling` block + failure semantics.
   - `## Tier: tier1` — same four blocks.
   - `## Tier: tier2` — same four blocks.
   - `## Tier: tier3` — same four blocks.
   - `## Aggregate Plausibility (SC-9)` — quote the 34.7% floor + per-tier P00 CIs verbatim, show the composition argument.
   - `## Additive Emitter Invariants (CON-5)` — every new field is back-compat; pre-M018 records remain valid; post-M018 records readable by pre-M018 jq filters with missing fields treated null. Enumerate the new emitter fields M018 will add (from FR-10): `filter_dropped_tokens`, `tier1_savings_tokens`, `tier2_savings_tokens`, `tier3_compression_savings_tokens`, `tier1_invocations`, `tier3_invocations`.
   - `## Failure Semantics (FR-2)` — preservation-contract self-check; pass-through-to-next-tier on violation; `tier_preservation_violation` JSONL record schema.
   - `## Open Questions` — start empty (no TODO placeholders); the conversus gate will surface disputes here if BLOCK.
   - `## Version History` — version 1.0.0 (P01 close).

3. **Write the YAML frontmatter** verbatim:

   ```yaml
   ---
   schema_version: "1.0"
   type: compression-grammar
   version: "1.0.0"
   status: "Draft"
   last_revised: "2026-04-27"
   ---
   ```

   Status starts at `Draft`. T03 (conversus gate) advances it to `Reviewed` on PASS verdict (per spec.md acceptance scenario 3).

4. **Author each `## Tier:` section** with these mandatory blocks (lint depends on the literal token shapes):

   ```markdown
   ## Tier: <name>

   **applies-to:**
   - <artifact-class-1> (e.g., "knowledge-entry")
   - <artifact-class-2>
   - ...

   **preserves:**
   - `<regex-pattern-1>` — <human description> (example: `<example-bytes>`)
   - `<regex-pattern-2>` — ...
   - ...

   **savings ceiling (P00 probe, 80% CI):**
   - low: <X>%
   - mean: <Y>%
   - high: <Z>%
   - model assumption: <verbatim from `.model_assumptions.<tier>` in probe JSON>

   **failure semantics:**
   - On preserved-pattern self-check failure, pass payload through to next tier unmodified.
   - Emit `{"record_type":"tier_preservation_violation","tier":"<name>","section":"<id>","pattern":"<regex>","timestamp":"<iso8601>"}` to `execution-log.jsonl`.
   ```

   The verbatim per-tier numbers from P00 (cite these EXACTLY, do not round further):
   - filter:  low 12.55% / mean 13.08% / high 13.67%; model: "drops ~30% of Knowledge tokens, Beta(2,5) prior on superseded/experimental fraction".
   - tier1:   low 6.24%  / mean 6.31%  / high 6.40%;  model: "drops ~50% of tool-result tokens, conditioned on ~30% prevalence inside Task Plan + Upstream Context".
   - tier2:   low 25.33% / mean 25.49% / high 25.68%; model: "head-drops ~40% of EXCESS over the 1500-tok tail threshold on any section that exceeds it (preserves last 1500 tok verbatim)".
   - tier3:   low 12.10% / mean 12.22% / high 12.36%; model: "summarizes ~40% of EXCESS above the per-section budget (2000 tok) on Knowledge + Task Plan + Upstream Context; Standard+ intensity assumed".

   Aggregate (per P00):  low 34.73% / mean 35.08% / high 35.39%.

5. **Per-tier `applies-to:` content** (derive from spec FR-3, FR-5, FR-7, FR-8):
   - filter: applies to `knowledge-entry` (one item per `MEM*.md` candidate). Reads `status:` field; drops list-matched.
   - tier1: applies to `tool-result-block` (inline `Read`/`Bash` outputs) and `tool-call-record` (deduplication via SHA-256(command+input)).
   - tier2: applies to `payload-section-body` for sections `Knowledge`, `Task Plan`, `Upstream Context` (the three highest-token sections per the P00 probe).
   - tier3: applies to `payload-section-body` for the same three sections, post-Tier-2.

6. **Per-tier `preserves:` content** — the cross-tier vocabulary applies to every tier; additionally each tier names tier-specific preservations:
   - Universal (every tier): YAML frontmatter delimiters (`^---$` ... `^---$`), code fences (`^```` ... `^```$`), absolute paths (`/[A-Za-z0-9_./-]+\\.(sh|md|yml|yaml|jsonl?|py|txt)`), repo-relative script paths (`scripts/[A-Za-z0-9_./-]+\\.sh`), MEM IDs (`\\bMEM[0-9]{3}\\b`), command names (`orchestrator:[a-z-]+`), URLs (`https?://[^\\s)]+`), JSONL records (a complete `{...}` line in any `.jsonl` file), scaffold-placeholder markers (`<TODO:[^>]+>`), in-band compression markers (`<!-- compressed:tier[0-9]+ [^>]*-->`).
   - filter-specific: knowledge-entry frontmatter delimiters and the entry body's first heading.
   - tier1-specific: the `<file_path>` reference shape `<tool-result file="..." preview-bytes="..."> ... </tool-result>`.
   - tier2-specific: the trailing `protected_tail_ratio` of the section, byte-identical, as defined by the operator's config (default 0.3).
   - tier3-specific: the section's identifier line (the `## Section: <name>` line, if present); the in-band marker.

7. **Marker Grammar section** — exact ABNF-style shape:

   ```
   marker     = "<!-- compressed:tier" tier-id " " kvpairs " -->"
   tier-id    = "1" | "2" | "3"
   kvpairs    = kvpair *( " " kvpair )
   kvpair     = key "=" value
   key        = 1*ALPHA / 1*ALPHA "-" 1*ALPHA
   value      = quoted-string / token   ; token excludes whitespace and ">"
   ```

   Examples (each tier, verbatim):
   - tier1: `<!-- compressed:tier1 cached_bytes=12288 cache_key=sha256:abc...123 -->`
   - tier2: `<!-- compressed:tier2 head-dropped=4096 protected_tail_ratio=0.3 -->`
   - tier3: `<!-- compressed:tier3 model=claude-3-5-sonnet input_tokens=8192 output_tokens=1024 -->`

   Filter is special: it does NOT emit an in-band marker (the entry simply does not appear). Filter savings are visible only via the `payload_filter` JSONL record + the `filter_dropped_tokens` field on `payload_breakdown`.

8. **Additive Emitter Invariants section** — quote CON-5 verbatim. Then enumerate the FR-10 new fields and their record-type membership:
   - `payload_breakdown` adds: `filter_dropped_tokens`, `tier1_savings_tokens`, `tier2_savings_tokens`, `tier3_compression_savings_tokens`.
   - `dispatch_usage` adds: `tier3_compression_savings_tokens` (when Tier 3 fired).
   - `unit_close` adds: `tier1_invocations`, `tier3_invocations`.
   - New record types (additive): `payload_filter`, `tier_preservation_violation`, `tier3_skipped`, `tier3_failed`, `tier3_no_savings`, `tier2_preservation_breach`.
   - State the contract: every field is optional in the JSON Schema sense; missing field reads as null/zero in pre-M018 jq filters.

9. **SC-9 plausibility argument** — cite the P00 aggregate floor (34.7%) and walk through composition: if filter, tier1, tier2, tier3 fire as modeled, the aggregate ceiling lands at 35.08% mean / 34.73% low / 35.39% high. Note that overlap (a token saved by filter cannot also be saved by tier3 on the same section) keeps the realized aggregate slightly below the simple sum; the probe's `aggregate_ceiling` already accounts for this via bootstrap resampling (see model_assumptions in the probe JSON).

10. **Failure semantics section** — restate FR-2 + FR-9: tier self-check on output for preserved-pattern corruption; on failure, do not emit the compressed output, pass through to next tier, emit `tier_preservation_violation` JSONL. Tier 3 LLM-call failures are a separate path: emit `tier3_failed`, pass through Tier 2's output, never crash.

11. **Open Questions section** — leave as a single line:

    ```markdown
    No open questions at v1.0.0 author time. Conversus gate findings (if any) are appended below by the operator after T03.
    ```

    Crucial: do NOT include `<TODO:` markers; the conversus adapter refuses to gate artifacts containing them (see scripts/dispatch/adapters/tool/conversus.sh `_todo_count` check).

12. **Version History section**:

    ```markdown
    - **1.0.0** (2026-04-27) — Initial draft authored under M018/P01/T01. Frontmatter `status: Draft`. Conversus gate (T03) advances to `Reviewed` on PASS.
    ```

13. **Final word count gate** — the lint verifier (T02) checks `min 200 lines, contains "preserves:"`. The document as specified above will easily clear 200 lines; do not pad with prose. Density beats verbosity.

## Must-Haves

This task addresses the phase must-haves:

- Truth: "`references/compression-grammar.md` exists with a versioned per-tier contract..." — implemented by steps 1–12.
- Truth: "...defends against the SC-9 calibrated 34.7% floor by naming...the per-tier modeling assumptions..." — implemented by steps 4 + 9.
- Artifact: `references/compression-grammar.md` (min 200 lines, contains "preserves:").

## Verification

- File exists: `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P01/` will check line count + substring after T02 lands the verifier scaffolding; intermediate self-check is `wc -l references/compression-grammar.md` ≥ 200.
- No `<TODO:` markers anywhere in the file (conversus adapter pre-flight at T03 will refuse otherwise). Self-check: `grep -c "<TODO:" references/compression-grammar.md` returns 0.
- All four `## Tier:` sections present with both `applies-to:` and `preserves:` blocks. Self-check: `grep -c "^## Tier:" references/compression-grammar.md` returns 4.

## Inputs

### From Previous Tasks

None — first task in P01.

### From Disk (Pre-existing)

- `specs/030-context-compression-layer/spec.md` — feature spec. Sections to draw from: User Story 1 (US-1, FR-1, FR-2), Functional Requirements FR-3/5/7/8 (per-tier scope), FR-10 (additive emitter fields), FR-19 (in-band markers), CON-1/3/4/5/6, SC-9 (calibrated floor at line ~241).
- `.orchestrator/milestones/M018/phases/P00/P00-SUMMARY.md` — verbatim per-tier 80% CIs and model assumptions. Cite numbers EXACTLY as written there.
- `.orchestrator/scratch/m018-section-distribution-output.json` — probe output (the `.model_assumptions` block is the load-bearing source for the per-tier model strings).
- `.orchestrator/scratch/m018-section-distribution-output.txt` — text summary; useful as a reading aid.
- `references/file-formats.md` — house-style reference for headers/frontmatter.
- `templates/conversus-presets/spec-pressure-test.yml` — example of an existing red-blue preset; informs T03's preset shape but T01 does not touch this.

## Constraints

- **Bash 3.2+ / POSIX sh** does not apply (no script written this task), but lint shape (T02) is bash 3.2.
- **AD-19 (script-file shape)** does not apply directly (no scripts written), but every Check command in this plan and downstream is single-script-file.
- **AP-009 (compound-chain-gt2)** — the pre-bash-shape-guard hook will reject compound chains > 2 in any helper script; T01 writes prose only.
- **Constitution Principle III (Design Before Code)** — this task IS the design artifact for tiers P02–P05. Tier code does not start until P01 closes (and conversus gate passes).
- **Constitution Principle II (Evidence Before Claims)** — every per-tier savings claim cites the P00 probe by file path + numeric value. No narrative-only claims.
- **CON-1 (read-mostly)** — T01 creates exactly one new file under `references/`. No edits to spec/plan/roadmap/knowledge files.
- **CON-6 (conversus-gate non-negotiable)** — the document MUST be authored such that the red advocate has substantive material to argue against (preserves blocks, applies-to blocks, modeling assumptions) and the blue advocate has substantive material to defend. A skeleton document that punts every decision to "answered at planning" will block the gate.
- **No `<TODO:` markers** — conversus adapter `_todo_count` check refuses unauthored drafts (see scripts/dispatch/adapters/tool/conversus.sh ~line 280).

## Expected Output

```
$ wc -l references/compression-grammar.md
     <N>  references/compression-grammar.md           # N >= 200
$ grep -c "<TODO:" references/compression-grammar.md
0
$ grep -c "^## Tier:" references/compression-grammar.md
4
$ grep -c "^**applies-to:**" references/compression-grammar.md
4
$ grep -c "^**preserves:**" references/compression-grammar.md
4
```

The file is ready for T02's lint script to consume and for T03's conversus gate to deliberate against.
